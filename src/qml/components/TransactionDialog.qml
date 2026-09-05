import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 账目对话框：新增 / 编辑 / 删除（日期取当前选中日）
FluentDialog {
    id: control

    property date txDate: new Date()
    property var editData: null   // null = 新增；否则为账目 QVariantMap

    signal saved()
    signal deleted()

    // ------- 表单状态 -------
    property int txType: 0
    property int revision: 0     // 类别/账户变更后手动刷新下拉
    property string errorText: ""

    dialogTitle: editData ? qsTr("编辑账目") : qsTr("新增账目")
    width: 440
    primaryText: ""
    secondaryText: ""

    // 任何入口的数据变更（如设置页新增类别）都刷新下拉模型
    Connections {
        target: DB
        function onDataChanged() { control.revision++ }
    }

    onAboutToShow: {
        errorText = ""
        revision++ // 确保下拉模型每次打开都取最新
        if (editData) {
            txType = editData.type
            titleField.text = editData.title
            amountField.text = Theme.money(editData.amountCents)
            noteField.text = editData.note
            categoryCombo.currentIndex = categoryCombo.indexOfValue(editData.categoryId)
            accountCombo.currentIndex = accountCombo.indexOfValue(editData.accountId)
        } else {
            txType = 0
            titleField.text = ""
            amountField.text = ""
            noteField.text = ""
            categoryCombo.currentIndex = 0
            accountCombo.currentIndex = 0
        }
    }

    // 删除确认
    FluentDialog {
        id: deleteConfirm
        dialogTitle: qsTr("删除账目")
        primaryText: qsTr("删除")
        secondaryText: qsTr("取消")
        onAccepted: {
            if (DB.deleteTransaction(control.editData.id)) {
                control.deleted()
            } else {
                control.errorText = DB.lastError()
            }
        }
    }

    body: [
        FluentSegmented {
            id: typeSwitch
            Layout.fillWidth: true
            labelA: qsTr("支出")
            labelB: qsTr("收入")
            value: control.txType
            onEdited: function(newValue) {
                control.txType = newValue
                control.revision++
                categoryCombo.currentIndex = 0
            }
        },

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            Text {
                text: qsTr("账目名称")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            FluentTextField {
                id: titleField
                Layout.fillWidth: true
                placeholderText: qsTr("例如：午饭")
            }
        },

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                Text {
                    text: qsTr("金额（元）")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
                FluentTextField {
                    id: amountField
                    Layout.fillWidth: true
                    placeholderText: "0.00"
                    validator: RegularExpressionValidator {
                        regularExpression: /[0-9]+(\.[0-9]{0,2})?/
                    }
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.preferredWidth: 150
                Text {
                    text: qsTr("类别")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
                FluentComboBox {
                    id: categoryCombo
                    Layout.fillWidth: true
                    textRole: "name"
                    valueRole: "id"
                    font.pixelSize: 13
                    model: {
                        control.revision
                        return DB.categories(control.txType)
                    }
                }
            }
        },

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            Text {
                text: qsTr("付款方式")  // 支出来源 / 收入流向
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            FluentComboBox {
                id: accountCombo
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                font.pixelSize: 13
                model: {
                    control.revision
                    return DB.accounts()
                }
            }
        },

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            Text {
                text: qsTr("详细内容")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            FluentTextField {
                id: noteField
                Layout.fillWidth: true
                placeholderText: qsTr("备注（可选）")
            }
        },

        Text {
            visible: control.errorText !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: control.errorText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.colorExpense
        },

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            FluentButton {
                visible: control.editData !== null
                text: qsTr("删除")
                onClicked: deleteConfirm.open()
            }
            Item { Layout.fillWidth: true }
            FluentButton {
                text: qsTr("取消")
                onClicked: control.close()
            }
            FluentButton {
                text: qsTr("保存")
                primary: true
                onClicked: control.save()
        }
        }
    ]

    // 测试/程序化填充：t = {type, title, amount, category, account, note}
    function fill(t) {
        txType = t.type !== undefined ? t.type : 0
        revision++
        titleField.text = t.title || ""
        amountField.text = t.amount || ""
        noteField.text = t.note || ""
        const cats = DB.categories(txType)
        categoryCombo.currentIndex = Math.max(0, cats.findIndex(c => c.name === t.category))
        const accs = DB.accounts()
        accountCombo.currentIndex = Math.max(0, accs.findIndex(a => a.name === t.account))
        errorText = ""
    }

    // 测试辅助：跳过确认直接删除当前编辑账目
    function deleteForTest() {
        if (editData && DB.deleteTransaction(editData.id)) {
            deleted()
            close()
            return true
        }
        return false
    }

    function save() {
        errorText = ""

        const title = titleField.text.trim()
        if (title === "") {
            errorText = qsTr("请填写账目名称")
            return
        }
        const yuan = parseFloat(amountField.text)
        if (!isFinite(yuan) || yuan <= 0) {
            errorText = qsTr("请填写正确的金额")
            return
        }
        const cents = Math.round(yuan * 100)
        const categoryId = categoryCombo.currentValue
        const accountId = accountCombo.currentValue
        if (categoryId === undefined || accountId === undefined) {
            errorText = qsTr("请先创建类别与付款方式")
            return
        }

        let ok
        if (editData) {
            ok = DB.updateTransaction(editData.id, txDate, txType, cents, title,
                                      noteField.text.trim(), categoryId, accountId)
        } else {
            ok = DB.addTransaction(txDate, txType, cents, title,
                                   noteField.text.trim(), categoryId, accountId) > 0
        }
        if (ok) {
            saved()
            close()
        } else {
            errorText = DB.lastError()
        }
    }
}
