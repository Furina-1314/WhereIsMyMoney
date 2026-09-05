import QtQuick
import QtQuick.Controls.Basic
import WhereIsMyMoney

// UWP 纤细滚动条：平时隐藏，悬停区域时淡入
ScrollBar {
    id: control

    implicitWidth: hovered || pressed ? 10 : 4
    contentItem: Rectangle {
        radius: width / 2
        color: control.pressed ? Theme.textSecondary
               : control.hovered ? "#6A6A6A" : "#4A4A4A"
    }

    background: null

    Behavior on implicitWidth {
        NumberAnimation { duration: 120 }
    }
}
