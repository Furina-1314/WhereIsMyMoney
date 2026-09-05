import QtQuick
import QtQuick.Layouts
import WhereIsMyMoney

// 类别/付款方式管理对话框（记账页工具栏入口；设置页直接内嵌 EntityManagePanel）
FluentDialog {
    id: control

    property bool manageCategories: true

    signal changed()

    dialogTitle: manageCategories ? qsTr("类别管理") : qsTr("付款方式管理")
    width: 460
    primaryText: ""
    secondaryText: qsTr("关闭")

    onAboutToShow: panel.reset()

    body: EntityManagePanel {
        id: panel
        Layout.fillWidth: true
        manageCategories: control.manageCategories
        onChanged: control.changed()
    }

    // ----- 测试辅助（转发到面板） -----
    function addForTest(name) { panel.addForTest(name) }
    function renameForTest(index, newName) { panel.renameForTest(index, newName) }
    function deleteForTest(index) { panel.deleteForTest(index) }
    function entityList() { return panel.entityList }
    function errorState() { return panel.errorText }
}
