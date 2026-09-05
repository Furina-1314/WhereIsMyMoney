import QtQuick
import QtQuick.Controls.Basic
import WhereIsMyMoney

// UWP 风格输入框：深底、聚焦时边框转为强调色
TextField {
    id: control

    implicitHeight: Theme.controlHeight
    leftPadding: 10
    rightPadding: 10
    font.family: Theme.fontFamily
    font.pixelSize: 14
    color: Theme.textPrimary
    placeholderTextColor: Theme.textSecondary
    placeholderText: qsTr("请输入")
    selectByMouse: true
    selectionColor: Theme.accent
    selectedTextColor: "#FFFFFF"
    opacity: enabled ? 1.0 : 0.4

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.hovered || control.activeFocus ? "#2F2F2F" : Theme.itemBg
        border.width: 1
        border.color: control.activeFocus ? Theme.accent
                    : control.hovered ? "#4A4A4A" : Theme.stroke
    }
}
