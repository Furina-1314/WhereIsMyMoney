import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 预算页（Phase 6 实现：周/月预算编制与进度）
Page {
    background: Rectangle { color: Theme.bg }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingMedium

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\uE825" // Bank
            font.family: Theme.iconFontFamily
            font.pixelSize: 44
            color: Theme.textDisabled
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("预算")
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.textSecondary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Phase 6 提供周预算 / 月预算编制与超支提醒")
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.textDisabled
        }
    }
}
