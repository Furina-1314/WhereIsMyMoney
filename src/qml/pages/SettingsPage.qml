import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 设置页：外观（浅色/深色模式）
Page {
    background: Rectangle { color: Theme.bg }

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingHuge
        spacing: Theme.spacingMedium

        // ----- 外观 -----
        Text {
            text: qsTr("外观")
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.textPrimary
        }
        Text {
            Layout.topMargin: -Theme.spacingSmall
            text: qsTr("选择应用的颜色模式")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textSecondary
        }

        RowLayout {
            Layout.topMargin: Theme.spacingSmall
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

        Item { Layout.fillHeight: true }
    }
}
