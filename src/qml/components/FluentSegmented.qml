import QtQuick
import QtQuick.Layouts
import WhereIsMyMoney

// UWP 分段切换（两段式：如 支出/收入）
Item {
    id: control

    property string labelA: qsTr("支出")
    property string labelB: qsTr("收入")
    property int value: 0          // 0 = A, 1 = B
    property bool tintB: true      // B 段选中时是否用第二强调色（如收入绿）

    signal edited(int newValue)

    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.itemBg
        border.width: 1
        border.color: Theme.stroke
    }

    RowLayout {
        id: segRow
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        component SegPiece: Rectangle {
            id: piece

            property bool selected: false
            property color selectedColor: Theme.accent
            property string text: ""

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusControl - 1
            color: selected ? selectedColor : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: piece.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: piece.selected ? Font.DemiBold : Font.Normal
                color: piece.selected ? "#FFFFFF" : Theme.textSecondary
            }
        }

        SegPiece {
            text: control.labelA
            selected: control.value === 0
            selectedColor: Theme.accent
            TapHandler { onTapped: { control.value = 0; control.edited(0) } }
        }
        SegPiece {
            text: control.labelB
            selected: control.value === 1
            selectedColor: control.tintB ? Theme.colorIncome : Theme.accent
            TapHandler { onTapped: { control.value = 1; control.edited(1) } }
        }
    }
}
