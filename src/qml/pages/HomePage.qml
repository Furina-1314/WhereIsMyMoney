import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 记账页：左侧日历（选日期/翻月）+ 右侧当日账目列表
Page {
    id: page

    property date today: {
        var t = new Date()
        return new Date(t.getFullYear(), t.getMonth(), t.getDate())
    }
    property date selectedDate: today
    property date viewMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    property int dataRevision: 0 // 数据变更后自增以刷新查询绑定
    property var editingTx: null // null = 新增；否则为编辑中的账目

    // 生成月历格子：0 表示空位，其余为日期数字
    function monthCells(d) {
        const y = d.getFullYear(), m = d.getMonth()
        const firstOffset = (new Date(y, m, 1).getDay() + 6) % 7 // 周一起始
        const days = new Date(y, m + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < firstOffset; i++) cells.push(0)
        for (let day = 1; day <= days; day++) cells.push(day)
        while (cells.length % 7 !== 0) cells.push(0)
        return cells
    }

    function dateOfCell(day) {
        return new Date(viewMonth.getFullYear(), viewMonth.getMonth(), day)
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
                && a.getMonth() === b.getMonth()
                && a.getDate() === b.getDate()
    }

    readonly property var weekNames: [qsTr("周日"), qsTr("周一"), qsTr("周二"),
                                      qsTr("周三"), qsTr("周四"), qsTr("周五"), qsTr("周六")]

    // 当日数据查询（依赖 dataRevision / selectedDate 触发刷新）
    readonly property var daySummary: {
        page.dataRevision
        return DB.rangeSummary(page.selectedDate, page.selectedDate)
    }
    readonly property var dayTxList: {
        page.dataRevision
        return DB.transactionsForDate(page.selectedDate)
    }

    background: Rectangle { color: Theme.bg }

    Component.onCompleted: {
        // 测试辅助：启动即打开指定对话框（截图验收用）
        const which = (typeof initialOpenDialog !== "undefined") ? initialOpenDialog : ""
        if (which === "tx") {
            editingTx = null
            txDialog.open()
        }
    }

    // 月历翻月小按钮
    component MonthNavButton: Rectangle {
        id: navBtn

        property string icon: ""
        signal activated()

        width: 26
        height: 26
        radius: Theme.radiusControl
        color: navMouse.hovered ? Theme.itemBgHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: navBtn.icon
            font.family: Theme.iconFontFamily
            font.pixelSize: 10
            color: navMouse.hovered ? Theme.textPrimary : Theme.textSecondary
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.activated()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingLarge

        // ===== 日历卡片 =====
        Rectangle {
            Layout.preferredWidth: 312
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: Theme.radiusPanel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingSmall

                // 月份标题 + 翻月 + 今天
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: viewMonth.getFullYear() + qsTr("年")
                              + (viewMonth.getMonth() + 1) + qsTr("月")
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    MonthNavButton {
                        icon: "\uE76B" // ChevronLeft
                        onActivated: viewMonth = new Date(viewMonth.getFullYear(),
                                                          viewMonth.getMonth() - 1, 1)
                    }
                    MonthNavButton {
                        icon: "\uE76C" // ChevronRight
                        onActivated: viewMonth = new Date(viewMonth.getFullYear(),
                                                          viewMonth.getMonth() + 1, 1)
                    }
                    FluentButton {
                        text: qsTr("今天")
                        implicitHeight: 26
                        font.pixelSize: 12
                        leftPadding: 10
                        rightPadding: 10
                        onClicked: {
                            selectedDate = today
                            viewMonth = new Date(today.getFullYear(), today.getMonth(), 1)
                        }
                    }
                }

                // 星期表头（周一起始）
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Repeater {
                        model: [qsTr("一"), qsTr("二"), qsTr("三"), qsTr("四"),
                                qsTr("五"), qsTr("六"), qsTr("日")]
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                    }
                }

                // 日期网格
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Repeater {
                        model: page.monthCells(page.viewMonth)
                        Item {
                            id: cell
                            required property var modelData

                            readonly property date cellDate: modelData > 0
                                ? dateOfCell(modelData) : page.selectedDate
                            readonly property bool isToday: modelData > 0 && sameDay(cellDate, today)
                            readonly property bool isSelected: modelData > 0 && sameDay(cellDate, selectedDate)

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 8
                                height: width
                                radius: height / 2
                                color: isSelected ? Theme.accent
                                       : cellMouse.hovered ? Theme.itemBgHover : "transparent"
                                border.width: isToday && !isSelected ? 2 : 0
                                border.color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: cell.modelData > 0 ? cell.modelData : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: cell.isSelected ? "#FFFFFF"
                                           : cell.isToday ? Theme.accent
                                           : cell.modelData > 0 ? Theme.textPrimary : "transparent"
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: cell.modelData > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (cell.modelData > 0)
                                        page.selectedDate = cell.cellDate
                                }
                            }
                        }
                    }
                }

                // 日历底部当日小结
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("支出")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "¥" + Theme.money(daySummary.expenseCents ? daySummary.expenseCents : 0)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.colorExpense
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("收入")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "¥" + Theme.money(daySummary.incomeCents ? daySummary.incomeCents : 0)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.colorIncome
                        }
                    }
                }
            }
        }

        // ===== 右侧内容区 =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: Theme.radiusPanel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: 0

                // 日期标题行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: (selectedDate.getMonth() + 1) + qsTr("月")
                                  + selectedDate.getDate() + qsTr("日")
                            font.family: Theme.fontFamily
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        Text {
                            text: weekNames[selectedDate.getDay()] + " · "
                                  + selectedDate.getFullYear() + qsTr("年")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textSecondary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            Text {
                                text: qsTr("支出 ")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                            Text {
                                text: "¥" + Theme.money(daySummary.expenseCents ? daySummary.expenseCents : 0)
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: Theme.colorExpense
                            }
                        }
                        RowLayout {
                            Text {
                                text: qsTr("收入 ")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                            Text {
                                text: "¥" + Theme.money(daySummary.incomeCents ? daySummary.incomeCents : 0)
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: Theme.colorIncome
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingMedium
                    Layout.bottomMargin: Theme.spacingSmall
                    height: 1
                    color: Theme.stroke
                }

                // 操作工具栏
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacingSmall
                    spacing: Theme.spacingSmall

                    FluentButton {
                        text: qsTr("＋ 新增账目")
                        primary: true
                        onClicked: {
                            page.editingTx = null
                            txDialog.open()
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: txList.count > 0
                        text: qsTr("点击账目可编辑")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDisabled
                    }
                }

                // 账目列表
                ListView {
                    id: txList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: page.dayTxList
                    spacing: 2
                    ScrollBar.vertical: FluentScrollBar {
                        policy: txList.contentHeight > txList.height
                                ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    // 空状态
                    Text {
                        anchors.centerIn: parent
                        visible: txList.count === 0
                        text: qsTr("这一天还没有账目")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.textDisabled
                    }

                    delegate: Rectangle {
                        id: txItem

                        required property var modelData

                        readonly property bool isIncome: modelData.type === 1

                        width: txList.width
                        height: 66
                        radius: Theme.radiusControl
                        color: itemMouse.hovered ? Theme.itemBg : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 16
                            spacing: Theme.spacingMedium

                            // 类别色点
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: txItem.modelData.categoryColor
                                        ? txItem.modelData.categoryColor : Theme.accent
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: txItem.modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: text !== ""
                                    text: txItem.modelData.note
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: (txItem.isIncome ? "+" : "-")
                                          + Theme.money(txItem.modelData.amountCents)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    color: txItem.isIncome ? Theme.colorIncome : Theme.colorExpense
                                }
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: txItem.modelData.categoryName + " · "
                                          + txItem.modelData.accountName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.editingTx = txItem.modelData
                                txDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== 对话框 =====
    Connections {
        target: DB
        function onDataChanged() {
            page.dataRevision++
            txDialog.revision++
        }
    }

    TransactionDialog {
        id: txDialog
        txDate: page.selectedDate
        editData: page.editingTx
    }

    // ----- 应用内自测（WIMM_AUTOTEST=1 时由 main.cpp 调用） -----
    function runSelfTest() {
        let pass = 0, fail = 0
        function check(cond, msg) {
            if (cond) { pass++ }
            else { fail++; console.warn("SELFTEST FAIL:", msg) }
        }

        // --- 新增支出 ---
        const before = dayTxList.length
        const expenseBefore = daySummary.expenseCents
        editingTx = null
        txDialog.open()
        txDialog.fill({ type: 0, title: "自测-午饭", amount: "23.45",
                        category: "餐饮", account: "现金", note: "selftest" })
        txDialog.save()
        check(!txDialog.opened, "保存成功后对话框关闭（opened=false）")
        check(dayTxList.length === before + 1, "新增后当日列表 +1")
        check(daySummary.expenseCents === expenseBefore + 2345, "当日支出汇总 +23.45")

        const mine = dayTxList.find(t => t.title === "自测-午饭")
        check(mine !== undefined, "列表中找到新账目")
        check(mine && mine.amountCents === 2345, "金额以分存储(2345)")

        // --- 编辑金额 ---
        editingTx = mine
        txDialog.open()
        txDialog.fill({ type: 0, title: "自测-午饭", amount: "99.99",
                        category: "餐饮", account: "现金", note: "selftest" })
        txDialog.save()
        check(daySummary.expenseCents === expenseBefore + 9999, "编辑后支出汇总 +99.99")

        // --- 删除账目（恢复现场） ---
        editingTx = dayTxList.find(t => t.title === "自测-午饭")
        txDialog.open()
        txDialog.deleteForTest()
        check(dayTxList.length === before, "删除账目后恢复原数量")
        check(daySummary.expenseCents === expenseBefore, "删除后支出汇总恢复")

        // --- 类型联动 ---
        txDialog.open()
        txDialog.fill({ type: 1, title: "x", amount: "1", category: "工资", account: "现金" })
        check(txDialog.txType === 1, "切换到收入类型")
        const incomeCats = DB.categories(1)
        check(incomeCats.length > 0 && incomeCats[0].name === "工资", "收入类别下拉取收入类别")
        txDialog.close()

        console.info("SELFTEST RESULT pass=" + pass + " fail=" + fail)
        return fail === 0
    }
}
