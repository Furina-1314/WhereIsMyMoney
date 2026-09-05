import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 设置页：外观（浅色/深色）、类别管理、付款方式管理
Page {
    background: Rectangle { color: Theme.bg }

    // 区块标题
    component SectionHeader: ColumnLayout {
        property string title: ""
        property string subtitle: ""

        spacing: 2
        Text {
            text: parent.title
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.textPrimary
        }
        Text {
            visible: text !== ""
            text: parent.subtitle
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textSecondary
        }
    }

    // UWP 设置项样式的外观选择按钮
    component ThemeOptionButton: Rectangle {
        id: opt

        property string label: ""
        property string icon: ""
        property bool checked: false
        signal chosen()

        implicitWidth: 180
        implicitHeight: 76
        radius: Theme.radiusPanel
        color: opt.checked ? Theme.panelBgAlt
               : optMouse.hovered ? Theme.itemBgHover : Theme.itemBg
        border.width: opt.checked ? 2 : 1
        border.color: opt.checked ? Theme.accent
                      : optMouse.hovered ? Theme.strokeHover : Theme.stroke
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingMedium

            Text {
                text: opt.icon
                font.family: Theme.iconFontFamily
                font.pixelSize: 18
                color: opt.checked ? Theme.accent : Theme.textSecondary
            }
            Text {
                text: opt.label
                font.family: Theme.fontFamily
                font.pixelSize: 15
                color: opt.checked ? Theme.textPrimary : Theme.textSecondary
            }
            // 选中勾
            Text {
                visible: opt.checked
                text: "\uE73E" // CheckMark
                font.family: Theme.iconFontFamily
                font.pixelSize: 14
                color: Theme.accent
            }
        }

        MouseArea {
            id: optMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: opt.chosen()
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsCol.implicitHeight + Theme.spacingHuge * 2
        clip: true
        ScrollBar.vertical: FluentScrollBar {}

        ColumnLayout {
            id: settingsCol
            x: Theme.spacingHuge
            y: Theme.spacingLarge
            width: parent.width - Theme.spacingHuge * 2
            spacing: Theme.spacingLarge

            // ===== 外观 =====
            SectionHeader {
                title: qsTr("外观")
                subtitle: qsTr("选择应用的颜色模式")
            }

            RowLayout {
                spacing: Theme.spacingMedium

                ThemeOptionButton {
                    label: qsTr("浅色模式")
                    icon: "\uE706" // Brightness
                    checked: !Theme.dark
                    onChosen: Theme.dark = false
                }
                ThemeOptionButton {
                    label: qsTr("深色模式")
                    icon: "\uE708" // QuietHours
                    checked: Theme.dark
                    onChosen: Theme.dark = true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.stroke
            }

            // ===== 类别管理 =====
            SectionHeader {
                title: qsTr("类别管理")
                subtitle: qsTr("维护支出与收入类别，新建后可在记账时选择")
            }

            EntityManagePanel {
                id: catPanel
                Layout.fillWidth: true
                manageCategories: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.stroke
            }

            // ===== 付款方式管理 =====
            SectionHeader {
                title: qsTr("付款方式管理")
                subtitle: qsTr("维护支出来源 / 收入流向（如某银行卡、微信零钱）")
            }

            EntityManagePanel {
                id: accPanel
                Layout.fillWidth: true
                manageCategories: false
            }
        }
    }

    // ----- 应用内自测（设置页内嵌管理流程） -----
    function runSelfTest() {
        let pass = 0, fail = 0
        function check(cond, msg) {
            if (cond) { pass++ }
            else { fail++; console.warn("SETTINGS SELFTEST FAIL:", msg) }
        }

        // 类别：增、重名拒绝、改、删
        const catCount = catPanel.entityList.length
        catPanel.addForTest("设置页类别")
        check(catPanel.entityList.length === catCount + 1, "设置页新建类别成功")
        catPanel.addForTest("设置页类别")
        check(catPanel.entityList.length === catCount + 1, "设置页重复类别被拒绝")
        const lastCat = catPanel.entityList.length - 1
        catPanel.renameForTest(lastCat, "设置页类别改")
        check(catPanel.entityList[lastCat].name === "设置页类别改", "设置页类别改名成功")
        catPanel.deleteForTest(lastCat)
        check(catPanel.entityList.length === catCount, "设置页删除未使用类别成功")

        // 类别分页切换
        catPanel.catType = 1
        catPanel.revision++
        check(catPanel.entityList.length > 0, "收入类别分页有数据")
        const incomeCount = catPanel.entityList.length
        catPanel.addForTest("设置页收入类别")
        check(catPanel.entityList.length === incomeCount + 1, "设置页新建收入类别成功")
        catPanel.deleteForTest(catPanel.entityList.length - 1)
        catPanel.catType = 0
        catPanel.revision++

        // 付款方式：增、改、删
        const accCount = accPanel.entityList.length
        accPanel.addForTest("设置页钱包")
        check(accPanel.entityList.length === accCount + 1, "设置页新建付款方式成功")
        const lastAcc = accPanel.entityList.length - 1
        accPanel.renameForTest(lastAcc, "设置页钱包改")
        check(accPanel.entityList[lastAcc].name === "设置页钱包改", "设置页付款方式改名成功")
        accPanel.deleteForTest(lastAcc)
        check(accPanel.entityList.length === accCount, "设置页删除未使用付款方式成功")

        console.info("SETTINGS SELFTEST RESULT pass=" + pass + " fail=" + fail)
        return fail === 0
    }
}
