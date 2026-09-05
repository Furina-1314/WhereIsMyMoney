import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 类别/付款方式管理面板：设置页内嵌使用，ManageEntitiesDialog 复用
Item {
    id: panel

    property bool manageCategories: true // false = 付款方式
    property int catType: 0              // 当前管理的类别类型（支出/收入）
    property int revision: 0
    property string errorText: ""
    property int editingId: -1
    property string renameText: ""       // 改名输入（delegate 内 TextField 同步到此）

    signal changed()

    implicitHeight: contentCol.implicitHeight

    onManageCategoriesChanged: editingId = -1

    readonly property var entityList: {
        revision
        return manageCategories ? DB.categories(catType) : DB.accounts()
    }

    // 任何入口的数据变更都刷新面板
    Connections {
        target: DB
        function onDataChanged() { panel.revision++ }
    }

    function reset() {
        errorText = ""
        editingId = -1
        newNameField.text = ""
    }

    ColumnLayout {
        id: contentCol
        width: parent.width
        spacing: Theme.spacingSmall

        // 类别：支出/收入分页
        FluentSegmented {
            visible: panel.manageCategories
            Layout.fillWidth: true
            labelA: qsTr("支出类别")
            labelB: qsTr("收入类别")
            value: panel.catType
            onEdited: function(newValue) {
                panel.catType = newValue
                panel.editingId = -1
                panel.revision++
            }
        }

        // 实体列表
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: Theme.radiusControl
            color: Theme.itemBg
            border.width: 1
            border.color: Theme.stroke

            ListView {
                id: entityView
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                spacing: 2
                model: panel.entityList
                ScrollBar.vertical: FluentScrollBar {
                    policy: entityView.contentHeight > entityView.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                Text {
                    anchors.centerIn: parent
                    visible: entityView.count === 0
                    text: qsTr("暂无内容")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textDisabled
                }

                delegate: Rectangle {
                    id: entityRow

                    required property var modelData

                    width: entityView.width
                    height: 40
                    radius: Theme.radiusControl
                    color: rowArea.hovered ? Theme.itemBgHover : "transparent"

                    // 常态：色点 + 名称 + 操作按钮
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: Theme.spacingSmall
                        visible: panel.editingId !== entityRow.modelData.id

                        Rectangle {
                            visible: panel.manageCategories
                            Layout.leftMargin: 4
                            width: 10
                            height: 10
                            radius: 5
                            color: entityRow.modelData.color
                                     ? entityRow.modelData.color : Theme.accent
                        }
                        Text {
                            text: entityRow.modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        FluentButton {
                            text: qsTr("编辑")
                            implicitHeight: 26
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            onClicked: {
                                panel.editingId = entityRow.modelData.id
                                panel.renameText = entityRow.modelData.name
                            }
                        }
                        FluentButton {
                            text: qsTr("删除")
                            implicitHeight: 26
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            onClicked: panel.doDelete(entityRow.modelData.id)
                        }
                    }

                    // 编辑态：改名输入 + 确定/取消
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: Theme.spacingSmall
                        visible: panel.editingId === entityRow.modelData.id

                        FluentTextField {
                            Layout.fillWidth: true
                            font.pixelSize: 13
                            text: panel.renameText
                            onTextEdited: panel.renameText = text
                        }
                        FluentButton {
                            text: qsTr("确定")
                            implicitHeight: 26
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            onClicked: panel.doRename()
                        }
                        FluentButton {
                            text: qsTr("取消")
                            implicitHeight: 26
                            font.pixelSize: 12
                            leftPadding: 10
                            rightPadding: 10
                            onClicked: panel.editingId = -1
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        // 新建行
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            FluentTextField {
                id: newNameField
                Layout.fillWidth: true
                placeholderText: panel.manageCategories
                                 ? qsTr("新类别名称") : qsTr("新付款方式名称")
                onAccepted: panel.addEntity()
            }
            FluentButton {
                text: qsTr("添加")
                onClicked: panel.addEntity()
            }
        }

        Text {
            visible: panel.errorText !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: panel.errorText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.colorExpense
        }
    }

    // ----- 操作 -----
    function addEntity() {
        errorText = ""
        const name = newNameField.text.trim()
        if (name === "") {
            errorText = qsTr("名称不能为空")
            return
        }
        const ok = manageCategories
                ? DB.addCategory(name, catType) > 0
                : DB.addAccount(name) > 0
        if (ok) {
            newNameField.text = ""
            revision++
            changed()
        } else {
            errorText = DB.lastError()
        }
    }

    function doRename() {
        errorText = ""
        const entity = entityList.find(e => e.id === editingId)
        if (!entity)
            return
        const ok = manageCategories
                ? DB.renameCategory(editingId, renameText)
                : DB.updateAccount(editingId, renameText, entity.note ? entity.note : "")
        if (ok) {
            editingId = -1
            revision++
            changed()
        } else {
            errorText = DB.lastError()
        }
    }

    function doDelete(id) {
        errorText = ""
        const ok = manageCategories ? DB.deleteCategory(id) : DB.deleteAccount(id)
        if (ok) {
            revision++
            changed()
        } else {
            errorText = DB.lastError()
        }
    }

    // ----- 测试辅助 -----
    function addForTest(name) {
        newNameField.text = name
        addEntity()
    }

    function renameForTest(index, newName) {
        const entity = entityList[index]
        if (!entity)
            return
        editingId = entity.id
        renameText = newName
        doRename()
    }

    function deleteForTest(index) {
        const entity = entityList[index]
        if (!entity)
            return
        doDelete(entity.id)
    }
}
