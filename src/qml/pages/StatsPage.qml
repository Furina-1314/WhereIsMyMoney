import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 统计页（Phase 5 实现：周/月/自定义区间统计与图表）
Page {
    background: Rectangle { color: Theme.bg }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingMedium

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\uE9D2" // 柱状图
            font.family: Theme.iconFontFamily
            font.pixelSize: 44
            color: Theme.textDisabled
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("查询与统计")
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.textSecondary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Phase 5 提供周统计、月统计与自定义区间图表")
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.textDisabled
        }
    }
}
