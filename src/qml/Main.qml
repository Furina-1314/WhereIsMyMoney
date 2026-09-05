import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1180
    height: 760
    minimumWidth: 960
    minimumHeight: 620
    visible: true
    title: qsTr("WhereIsMyMoney 记账")

    color: "#F3F3F3"

    // 临时占位内容，Phase 3 将替换为 Fluent 布局
    Label {
        anchors.centerIn: parent
        text: qsTr("WhereIsMyMoney")
        font.pixelSize: 28
        font.weight: Font.DemiBold
        color: "#333333"
    }
}
