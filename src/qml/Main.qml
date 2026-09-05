import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

ApplicationWindow {
    id: root

    readonly property var pages: [
        { title: qsTr("记账"), icon: "\uE787", source: "qrc:/qt/qml/WhereIsMyMoney/src/qml/pages/HomePage.qml" },
        { title: qsTr("统计"), icon: "\uE9D2", source: "qrc:/qt/qml/WhereIsMyMoney/src/qml/pages/StatsPage.qml" },
        { title: qsTr("预算"), icon: "\uE825", source: "qrc:/qt/qml/WhereIsMyMoney/src/qml/pages/BudgetPage.qml" }
    ]
    property int currentPage: 0

    width: 1280
    height: 800
    minimumWidth: 1080
    minimumHeight: 660
    visible: true
    title: qsTr("WhereIsMyMoney 记账")
    color: Theme.bg
    font.family: Theme.fontFamily

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ===== 左侧导航栏（Groove 风格） =====
        Rectangle {
            Layout.preferredWidth: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.sidebarBg

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingSmall

                // 应用标题区
                Text {
                    Layout.topMargin: 30
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 26
                    text: "WhereIsMyMoney"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }

                Repeater {
                    model: root.pages

                    // UWP 侧栏导航按钮：悬停高亮，选中带强调色指示条
                    delegate: Rectangle {
                        id: navItem
                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentPage === index

                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: active ? "#1A1A1A"
                               : navMouse.hovered ? Theme.itemBgHover : "transparent"

                        // 选中指示条
                        Rectangle {
                            visible: navItem.active
                            width: 3
                            height: parent.height - 12
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            spacing: 12

                            Text {
                                text: navItem.modelData.icon
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 15
                                color: navItem.active ? Theme.textPrimary : Theme.textSecondary
                            }
                            Text {
                                text: navItem.modelData.title
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                color: navItem.active ? Theme.textPrimary : Theme.textSecondary
                            }
                            Item { Layout.fillWidth: true }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = navItem.index
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 14
                    text: "v" + Qt.application.version
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDisabled
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.stroke
        }

        // ===== 右侧内容区 =====
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // UWP 页面标题（Segoe UI Light）
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 92

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingHuge
                    anchors.baseline: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pages[root.currentPage].title
                    font.family: Theme.fontFamily
                    font.weight: Font.Light
                    font.pixelSize: 34
                    color: Theme.textPrimary
                }
            }

            // 页面内容
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                HomePage {}
                StatsPage {}
                BudgetPage {}
            }
        }
    }
}
