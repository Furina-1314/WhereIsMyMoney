import QtQuick
import QtQuick.Controls.Basic
import WhereIsMyMoney

// UWP 风格下拉框（textRole 指定显示字段，model 用 QVariantList）
ComboBox {
    id: control

    implicitHeight: Theme.controlHeight
    leftPadding: 10
    rightPadding: 36
    font.family: Theme.fontFamily
    font.pixelSize: 14
    opacity: enabled ? 1.0 : 0.4

    background: Rectangle {
        radius: Theme.radiusControl
        color: control.hovered || control.popup.visible ? Theme.itemBgFocus : Theme.itemBg
        border.width: 1
        border.color: control.popup.visible ? Theme.accent
                    : control.hovered ? Theme.strokeHover : Theme.stroke
    }

    contentItem: Text {
        leftPadding: 0
        rightPadding: 0
        text: control.displayText
        font: control.font
        color: Theme.textPrimary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Segoe MDL2 Assets 下箭头
    indicator: Text {
        x: control.width - width - 10
        y: (control.height - height) / 2
        text: "\uE70D"
        font.family: Theme.iconFontFamily
        font.pixelSize: 10
        color: Theme.textSecondary
    }

    delegate: ItemDelegate {
        id: item
        required property var model
        required property int index
        width: control.width
        height: Theme.controlHeight
        highlighted: control.highlightedIndex === index

        background: Rectangle {
            color: item.highlighted ? Theme.itemBgHover : "transparent"
        }

        contentItem: Text {
            leftPadding: 8
            text: control.textRole ? item.model[control.textRole] : item.model
            font: control.font
            color: control.currentIndex === index ? Theme.textPrimary : Theme.textSecondary
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        padding: 4

        background: Rectangle {
            color: Theme.panelBgAlt
            radius: Theme.radiusControl
            border.color: Theme.stroke
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
    }
}
