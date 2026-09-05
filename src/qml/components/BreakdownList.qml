import QtQuick
import QtQuick.Layouts
import WhereIsMyMoney

// 分布列表：名称 + 金额 + 占比条（类别用类别色，付款方式用强调色）
ColumnLayout {
    id: list

    property string title: ""
    property var model: []              // [{name,totalCents,count,color?}]
    property bool useEntryColor: false  // true 时条用条目自带颜色

    readonly property real totalSum: {
        let s = 0
        for (let i = 0; i < model.length; i++)
            s += model[i].totalCents
        return s
    }

    spacing: Theme.spacingSmall

    Text {
        text: list.title
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Theme.textPrimary
    }

    Text {
        visible: list.model.length === 0
        text: qsTr("区间内暂无数据")
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: Theme.textDisabled
    }

    Repeater {
        model: list.model

        delegate: ColumnLayout {
            id: entry

            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    width: 10
                    height: 10
                    radius: 2
                    color: list.useEntryColor && entry.modelData.color
                           ? entry.modelData.color : Theme.accent
                }
                Text {
                    text: entry.modelData.name
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: entry.modelData.count + qsTr(" 笔")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDisabled
                }
                Text {
                    text: "¥" + Theme.money(entry.modelData.totalCents)
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    text: list.totalSum > 0
                          ? Math.round(entry.modelData.totalCents * 100 / list.totalSum) + "%" : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textSecondary
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }
            }

            // 占比条
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Theme.itemBg

                Rectangle {
                    width: list.totalSum > 0
                           ? parent.width * entry.modelData.totalCents / list.totalSum : 0
                    height: parent.height
                    radius: 2
                    color: list.useEntryColor && entry.modelData.color
                           ? entry.modelData.color : Theme.accent
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }
    }
}
