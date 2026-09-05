import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

ApplicationWindow {
    id: root

    readonly property var pages: [
        { title: qsTr("记账"), icon: "\uE787" },       // Calendar
        { title: qsTr("统计"), icon: "\uE9D2" },       // AreaChart
        { title: qsTr("预算"), icon: "\uE825" },       // Bank
        { title: qsTr("设置"), icon: "\uE713" }        // Settings
    ]
    property int currentPage: (typeof initialPage !== "undefined" && initialPage >= 0
                               && initialPage < pages.length) ? initialPage : 0

    width: 1280
    height: 800
    minimumWidth: 1080
    minimumHeight: 660
    visible: true
    title: qsTr("WhereIsMyMoney 记账")
    color: Theme.bg
    font.family: Theme.fontFamily

    // 应用内自测入口（WIMM_AUTOTEST=1 时由 main.cpp 调用）
    function runSelfTest() {
        return homePage.runSelfTest()
    }

    // ===== 页面切换动画（UWP 入场：淡入 + 轻微上滑） =====
    SequentialAnimation {
        id: pageEnter
        PropertyAction { target: pageStack; property: "opacity"; value: 0 }
        PropertyAction { target: pageStack; property: "x"; value: 36 }
        PropertyAction { target: pageTitle; property: "opacity"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: pageStack; property: "opacity"; to: 1; duration: 200; easing.type: Easing.InOutQuad }
            NumberAnimation { target: pageStack; property: "x"; to: 0; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: pageTitle; property: "opacity"; to: 1; duration: 220 }
        }
    }

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

                // 上部三个主导航项
                Repeater {
                    model: 3

                    // UWP 侧栏导航按钮：悬停高亮，选中带强调色指示条
                    delegate: Rectangle {
                        id: navItem
                        required property int index
                        readonly property bool active: root.currentPage === index
                        readonly property var meta: root.pages[index]

                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: active ? Theme.navActiveBg
                               : navMouse.hovered ? Theme.itemBgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // 选中指示条
                        Rectangle {
                            visible: navItem.active
                            width: 3
                            height: parent.height - 12
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            spacing: 12

                            Text {
                                text: navItem.meta.icon
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 15
                                color: navItem.active ? Theme.textPrimary : Theme.textSecondary
                            }
                            Text {
                                text: navItem.meta.title
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

                // 设置项固定在左下角
                Rectangle {
                    id: settingsItem
                    readonly property bool active: root.currentPage === 3

                    Layout.fillWidth: true
                    implicitHeight: 42
                    color: active ? Theme.navActiveBg
                           : settingsMouse.hovered ? Theme.itemBgHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        visible: settingsItem.active
                        width: 3
                        height: parent.height - 12
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        spacing: 12

                        Text {
                            text: root.pages[3].icon
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 15
                            color: settingsItem.active ? Theme.textPrimary : Theme.textSecondary
                        }
                        Text {
                            text: root.pages[3].title
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: settingsItem.active ? Theme.textPrimary : Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = 3
                    }
                }

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
                    id: pageTitle
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingHuge
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pages[root.currentPage].title
                    font.family: Theme.fontFamily
                    font.weight: Font.Light
                    font.pixelSize: 34
                    color: Theme.textPrimary
                }
            }

            // 页面内容（切换时入场动画）
            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage
                onCurrentIndexChanged: pageEnter.restart()

                HomePage { id: homePage }
                StatsPage {}
                BudgetPage {}
                SettingsPage {}
            }
        }
    }
}
