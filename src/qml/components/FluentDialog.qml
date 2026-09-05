import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// UWP ContentDialog：居中模态卡片，底部等宽按钮排
Popup {
    id: control

    property string dialogTitle: ""
    property alias body: bodyColumn.data
    property string primaryText: qsTr("确定")
    property string secondaryText: qsTr("取消")
    property bool closeOnPrimary: true
    property bool closeOnSecondary: true

    signal accepted()
    signal rejected()

    modal: true
    closePolicy: Popup.NoAutoClose
    parent: Overlay.overlay
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2 - 40
    width: Math.min(460, parent.width - 48)

    Overlay.modeless: Rectangle { color: "#80000000" }

    // Esc 触发次按钮（取消）语义，与 UWP ContentDialog 一致
    Shortcut {
        sequence: "Esc"
        enabled: control.visible && control.secondaryText !== ""
        context: Qt.WindowShortcut
        onActivated: {
            control.rejected()
            if (control.closeOnSecondary)
                control.close()
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120 }
    }

    background: Rectangle {
        color: Theme.panelBgAlt
        radius: Theme.radiusPanel
        border.color: Theme.stroke
    }

    contentItem: ColumnLayout {
        id: dialogColumn
        spacing: Theme.spacingMedium

        Text {
            text: control.dialogTitle
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: Theme.textPrimary
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            id: bodyColumn
            spacing: Theme.spacingMedium
            Layout.fillWidth: true
        }

        RowLayout {
            visible: control.secondaryText !== "" || control.primaryText !== ""
            spacing: 1
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingSmall

            FluentButton {
                Layout.fillWidth: true
                text: control.secondaryText
                visible: control.secondaryText !== ""
                onClicked: {
                    control.rejected()
                    if (control.closeOnSecondary)
                        control.close()
                }
            }
            FluentButton {
                Layout.fillWidth: true
                text: control.primaryText
                primary: true
                visible: control.primaryText !== ""
                onClicked: {
                    control.accepted()
                    if (control.closeOnPrimary)
                        control.close()
                }
            }
        }
    }
}
