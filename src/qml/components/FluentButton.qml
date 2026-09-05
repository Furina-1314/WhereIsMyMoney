import QtQuick
import QtQuick.Controls.Basic
import WhereIsMyMoney

// UWP 风格按钮：小圆角、悬停高亮；primary=true 时使用强调色底
Button {
    id: control

    property bool primary: false

    implicitHeight: Theme.controlHeight
    implicitWidth: Math.max(90, contentText.implicitWidth + leftPadding + rightPadding)
    leftPadding: 16
    rightPadding: 16
    font.family: Theme.fontFamily
    font.pixelSize: 14
    opacity: enabled ? 1.0 : 0.4

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.primary
              ? (control.pressed ? Theme.accentPressed
                 : control.hovered ? Theme.accentHover : Theme.accent)
              : (control.pressed ? Theme.itemBgPressed
                 : control.hovered ? Theme.itemBgHover : Theme.itemBg)
        border.width: control.primary ? 0 : 1
        border.color: control.hovered && !control.primary ? "#454545" : Theme.stroke
    }

    contentItem: Text {
        id: contentText
        text: control.text
        font: control.font
        color: control.primary ? "#FFFFFF" : Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
