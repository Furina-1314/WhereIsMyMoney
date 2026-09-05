import QtQuick
import QtQuick.Layouts
import WhereIsMyMoney

// 逐日收支柱状图：每日两根细柱（支出红 / 收入绿），补齐无账目日期
Item {
    id: chart

    property date fromD: new Date()
    property date toD: new Date()
    property var daily: []          // DB.dailyTotals 结果 [{date,expenseCents,incomeCents}]
    readonly property int barGap: 3

    // 组装逐日序列（含空日）
    readonly property var series: {
        const map = {}
        for (let i = 0; i < daily.length; i++)
            map[daily[i].date] = daily[i]
        const arr = []
        const d = new Date(fromD.getFullYear(), fromD.getMonth(), fromD.getDate())
        const end = new Date(toD.getFullYear(), toD.getMonth(), toD.getDate())
        let max = 0
        while (d.getTime() <= end.getTime()) {
            const key = Qt.formatDate(d, "yyyy-MM-dd")
            const item = map[key] || { date: key, expenseCents: 0, incomeCents: 0 }
            max = Math.max(max, item.expenseCents, item.incomeCents)
            arr.push(item)
            d.setDate(d.getDate() + 1)
        }
        chart._max = max
        return arr
    }
    property real _max: 1 // 避免 0 除

    implicitHeight: 160

    Row {
        id: barsRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: axisLine.top
        spacing: chart.barGap

        Repeater {
            model: chart.series

            delegate: Item {
                id: barCol

                required property var modelData
                required property int index

                width: (barsRow.width - chart.barGap * (chart.series.length - 1))
                       / Math.max(1, chart.series.length)
                height: parent.height

                // 支出 / 收入 双柱
                Row {
                    anchors.bottom: parent.bottom
                    x: (parent.width - width) / 2
                    spacing: 2

                    Rectangle {
                        width: Math.max(3, parent.width / 2 - 1)
                        height: barCol.height * (barCol.modelData.expenseCents / chart._max)
                        color: Theme.colorExpense
                        radius: 1
                    }
                    Rectangle {
                        width: Math.max(3, parent.width / 2 - 1)
                        height: barCol.height * (barCol.modelData.incomeCents / chart._max)
                        color: Theme.colorIncome
                        radius: 1
                    }
                }

                // 今天标识
                Rectangle {
                    visible: barCol.index === chart.todayIndex
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: Theme.accent
                }

                // 日期标签（首/末/每 7 天）
                Text {
                    visible: barCol.index % 7 === 0
                             || barCol.index === chart.series.length - 1
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -14
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(barCol.modelData.date + "T00:00:00"), "M/d")
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textDisabled
                }
            }
        }
    }

    // 基线
    Rectangle {
        id: axisLine
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width
        height: 1
        color: Theme.stroke
    }

    readonly property int todayIndex: {
        const key = Qt.formatDate(new Date(), "yyyy-MM-dd")
        for (let i = 0; i < series.length; i++)
            if (series[i].date === key)
                return i
        return -1
    }
}
