import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 记账页：左侧日历 + 右侧当日账目（Phase 4 接入数据与交互）
Page {
    id: page

    readonly property date today: new Date()

    // 生成当前月历格子：0 表示空位，其余为日期数字
    function monthCells(d) {
        const y = d.getFullYear(), m = d.getMonth()
        const firstOffset = (new Date(y, m, 1).getDay() + 6) % 7 // 周一起始
        const days = new Date(y, m + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < firstOffset; i++) cells.push(0)
        for (let day = 1; day <= days; day++) cells.push(day)
        while (cells.length % 7 !== 0) cells.push(0)
        return cells
    }

    background: Rectangle { color: Theme.bg }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingLarge

        // ----- 日历卡片 -----
        Rectangle {
            Layout.preferredWidth: 312
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: Theme.radiusPanel

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingSmall

                // 月份标题（翻月按钮在 Phase 4 接入交互）
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: page.today.getFullYear() + qsTr("年")
                              + (page.today.getMonth() + 1) + qsTr("月")
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                // 星期表头（周一起始）
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Repeater {
                        model: [qsTr("一"), qsTr("二"), qsTr("三"), qsTr("四"),
                                qsTr("五"), qsTr("六"), qsTr("日")]
                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                    }
                }

                // 日期网格（静态展示；今天高亮）
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Repeater {
                        model: page.monthCells(page.today)
                        Item {
                            required property var modelData
                            readonly property bool isToday: modelData === page.today.getDate()
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 6
                                height: width
                                radius: height / 2
                                color: isToday ? Theme.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData > 0 ? modelData : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: isToday ? "#FFFFFF"
                                                   : modelData > 0 ? Theme.textPrimary : "transparent"
                                }
                            }
                        }
                    }
                }

                // 日历底部小结（Phase 4 接入数据）
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("点击日期记录当天账目（Phase 4 启用）")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDisabled
                }
            }
        }

        // ----- 右侧内容区 -----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: Theme.radiusPanel

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingMedium

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\uE9D5" // CheckList
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 44
                    color: Theme.textDisabled
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("选中日期的账目将显示在这里")
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.textSecondary
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Phase 4 接入数据后可新增 / 编辑 / 删除账目")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textDisabled
                }
            }
        }
    }
}
