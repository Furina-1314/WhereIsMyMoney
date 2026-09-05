import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 统计页：周/月/自定义区间 + 类型/类别/付款方式/关键词筛选，
// 汇总卡片、逐日趋势、支出分布（类别/付款方式）、明细列表
Page {
    id: page

    readonly property date today: {
        var t = new Date()
        return new Date(t.getFullYear(), t.getMonth(), t.getDate())
    }

    property int rangeMode: 1        // 0=本周 1=本月 2=自定义
    property string fromText: ""
    property string toText: ""
    property int typeFilter: -1      // -1 全部 0 支出 1 收入
    property int catFilter: -1       // -1 全部
    property int accFilter: -1       // -1 全部
    property string keyword: ""
    property int revision: 0
    property string rangeError: ""

    // ----- 日期工具 -----
    function weekStartOf(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7)
    }
    function weekEndOf(d) {
        const s = weekStartOf(d)
        return new Date(s.getFullYear(), s.getMonth(), s.getDate() + 6)
    }
    function monthStartOf(d) { return new Date(d.getFullYear(), d.getMonth(), 1) }
    function monthEndOf(d) { return new Date(d.getFullYear(), d.getMonth() + 1, 0) }
    function iso(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    function parseIso(s) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec((s || "").trim())
        if (!m)
            return null
        const d = new Date(+m[1], +m[2] - 1, +m[3])
        return d.getFullYear() === +m[1] && d.getMonth() === +m[2] - 1 && d.getDate() === +m[3]
                ? d : null
    }

    // ----- 区间计算 -----
    readonly property date fromD: {
        if (rangeMode === 0)
            return weekStartOf(today)
        if (rangeMode === 1)
            return monthStartOf(today)
        const d = parseIso(fromText)
        return d ? d : monthStartOf(today)
    }
    readonly property date toD: {
        if (rangeMode === 0)
            return weekEndOf(today)
        if (rangeMode === 1)
            return monthEndOf(today)
        const d = parseIso(toText)
        return d ? d : monthEndOf(today)
    }
    onFromDChanged: rangeError = toD < fromD ? qsTr("结束日期不能早于开始日期") : ""
    onToDChanged: rangeError = toD < fromD ? qsTr("结束日期不能早于开始日期") : ""

    // ----- 数据 -----
    readonly property var txs: {
        revision
        return DB.transactionsInRange(fromD, toD, typeFilter, catFilter, accFilter, keyword)
    }
    readonly property var rangeSummaryData: {
        revision
        return DB.rangeSummary(fromD, toD)
    }
    readonly property var catBd: {
        revision
        return DB.categoryBreakdown(fromD, toD, 0)
    }
    readonly property var accBd: {
        revision
        return DB.accountBreakdown(fromD, toD, 0)
    }
    readonly property var daily: {
        revision
        return DB.dailyTotals(fromD, toD)
    }

    // 筛选后明细的收支合计（与明细列表口径一致）
    readonly property var filteredTotals: {
        let e = 0, i = 0
        const arr = txs
        for (let k = 0; k < arr.length; k++) {
            if (arr[k].type === 0)
                e += arr[k].amountCents
            else
                i += arr[k].amountCents
        }
        return { expense: e, income: i }
    }

    Connections {
        target: DB
        function onDataChanged() { page.revision++ }
    }

    background: Rectangle { color: Theme.bg }

    // 汇总卡片
    component StatCard: Rectangle {
        property string label: ""
        property string value: ""
        property color valueColor: Theme.textPrimary

        radius: Theme.radiusPanel
        color: Theme.panelBg
        Layout.fillWidth: true
        implicitHeight: 84

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: parent.parent.valueColor
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + Theme.spacingLarge
        clip: true
        ScrollBar.vertical: FluentScrollBar {}

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingMedium

            // ===== 筛选栏 =====
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusPanel
                color: Theme.panelBg
                implicitHeight: filterCol.implicitHeight + Theme.spacingMedium * 2

                ColumnLayout {
                    id: filterCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        // 区间类型
                        FluentSegmented {
                            id: rangeSwitch
                            Layout.preferredWidth: 260
                            labelA: qsTr("本周")
                            labelB: qsTr("本月")
                            tintB: false
                            value: page.rangeMode === 2 ? -1 : page.rangeMode
                            onEdited: function(newValue) { page.rangeMode = newValue }
                        }

                        // 第三段：自定义（独立按钮，选中态显示）
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 34
                            radius: Theme.radiusControl
                            color: page.rangeMode === 2 ? Theme.accent
                                   : customMouse.hovered ? Theme.itemBgHover : Theme.itemBg
                            border.width: 1
                            border.color: page.rangeMode === 2 ? Theme.accent : Theme.stroke
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("自定义")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: page.rangeMode === 2 ? Font.DemiBold : Font.Normal
                                color: page.rangeMode === 2 ? "#FFFFFF" : Theme.textSecondary
                            }

                            MouseArea {
                                id: customMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (page.rangeMode !== 2) {
                                        page.rangeMode = 2
                                        page.fromText = iso(page.fromD)
                                        page.toText = iso(page.toD)
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // 类型筛选
                        FluentComboBox {
                            id: typeCombo
                            Layout.preferredWidth: 110
                            textRole: "label"
                            valueRole: "v"
                            font.pixelSize: 13
                            model: [{ label: qsTr("全部类型"), v: -1 },
                                    { label: qsTr("仅支出"), v: 0 },
                                    { label: qsTr("仅收入"), v: 1 }]
                            onActivated: page.typeFilter = currentValue
                        }

                        // 类别筛选
                        FluentComboBox {
                            id: catCombo
                            Layout.preferredWidth: 130
                            textRole: "name"
                            valueRole: "id"
                            font.pixelSize: 13
                            model: {
                                page.revision
                                const all = [{ id: -1, name: qsTr("全部类别") }]
                                return all.concat(DB.categories(-1))
                            }
                            onActivated: page.catFilter = currentValue
                        }

                        // 付款方式筛选
                        FluentComboBox {
                            id: accCombo
                            Layout.preferredWidth: 130
                            textRole: "name"
                            valueRole: "id"
                            font.pixelSize: 13
                            model: {
                                page.revision
                                const all = [{ id: -1, name: qsTr("全部付款方式") }]
                                return all.concat(DB.accounts())
                            }
                            onActivated: page.accFilter = currentValue
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        // 自定义起止日期
                        RowLayout {
                            visible: page.rangeMode === 2
                            spacing: Theme.spacingSmall

                            Text {
                                text: qsTr("从")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                            FluentTextField {
                                Layout.preferredWidth: 120
                                font.pixelSize: 13
                                placeholderText: "2026-09-01"
                                text: page.fromText
                                validator: RegularExpressionValidator {
                                    regularExpression: /[0-9]{4}-[0-9]{2}-[0-9]{2}/
                                }
                                onTextEdited: page.fromText = text
                            }
                            Text {
                                text: qsTr("到")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                            FluentTextField {
                                Layout.preferredWidth: 120
                                font.pixelSize: 13
                                placeholderText: "2026-09-30"
                                text: page.toText
                                validator: RegularExpressionValidator {
                                    regularExpression: /[0-9]{4}-[0-9]{2}-[0-9]{2}/
                                }
                                onTextEdited: page.toText = text
                            }
                        }

                        // 关键词
                        Text {
                            text: qsTr("关键词")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textSecondary
                        }
                        FluentTextField {
                            id: keywordField
                            Layout.preferredWidth: 160
                            font.pixelSize: 13
                            placeholderText: qsTr("搜索名称/明细")
                            onTextEdited: page.keyword = text
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: page.rangeError !== ""
                            text: page.rangeError
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.colorExpense
                        }
                        Text {
                            text: iso(fromD) + " ~ " + iso(toD)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            // ===== 汇总卡片 =====
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                StatCard {
                    label: qsTr("支出（筛选后）")
                    value: "¥" + Theme.money(filteredTotals.expense)
                    valueColor: Theme.colorExpense
                }
                StatCard {
                    label: qsTr("收入（筛选后）")
                    value: "¥" + Theme.money(filteredTotals.income)
                    valueColor: Theme.colorIncome
                }
                StatCard {
                    label: qsTr("区间结余")
                    value: "¥" + Theme.money(rangeSummaryData.incomeCents - rangeSummaryData.expenseCents)
                }
                StatCard {
                    label: qsTr("区间笔数")
                    value: (rangeSummaryData.count ? rangeSummaryData.count : 0) + ""
                }
            }

            // ===== 趋势与分布 =====
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                // 逐日趋势
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    radius: Theme.radiusPanel
                    color: Theme.panelBg

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("逐日收支")
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 4
                                Rectangle { width: 8; height: 8; radius: 2; color: Theme.colorExpense }
                                Text { text: qsTr("支出"); font.pixelSize: 11; font.family: Theme.fontFamily; color: Theme.textSecondary }
                                Rectangle { width: 8; height: 8; radius: 2; color: Theme.colorIncome }
                                Text { text: qsTr("收入"); font.pixelSize: 11; font.family: Theme.fontFamily; color: Theme.textSecondary }
                                Rectangle { width: 8; height: 8; radius: 2; color: Theme.accent }
                                Text { text: qsTr("今天"); font.pixelSize: 11; font.family: Theme.fontFamily; color: Theme.textSecondary }
                            }
                        }

                        DailyBars {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fromD: page.fromD
                            toD: page.toD
                            daily: page.daily
                        }
                    }
                }

                // 支出类别分布
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    radius: Theme.radiusPanel
                    color: Theme.panelBg

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        contentWidth: width
                        contentHeight: catListCol.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: catListCol
                            width: parent.width

                            BreakdownList {
                                Layout.fillWidth: true
                                title: qsTr("支出类别分布")
                                useEntryColor: true
                                model: page.catBd
                            }
                        }
                    }
                }
            }

            // ===== 付款方式分布 + 明细 =====
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                // 付款方式分布
                Rectangle {
                    Layout.preferredWidth: 380
                    Layout.fillHeight: true
                    Layout.preferredHeight: 240
                    radius: Theme.radiusPanel
                    color: Theme.panelBg

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        contentWidth: width
                        contentHeight: accListCol.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: accListCol
                            width: parent.width

                            BreakdownList {
                                Layout.fillWidth: true
                                title: qsTr("支出付款方式分布")
                                useEntryColor: false
                                model: page.accBd
                            }
                        }
                    }
                }

                // 明细列表
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    radius: Theme.radiusPanel
                    color: Theme.panelBg

                    ListView {
                        id: txListView
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        clip: true
                        spacing: 2
                        model: page.txs
                        ScrollBar.vertical: FluentScrollBar {
                            policy: txListView.contentHeight > txListView.height
                                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: txListView.count === 0
                            text: qsTr("没有符合条件的账目")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDisabled
                        }

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            readonly property bool isIncome: modelData.type === 1

                            width: txListView.width
                            height: 44
                            radius: Theme.radiusControl
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: Theme.spacingSmall

                                Text {
                                    text: row.modelData.date
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                    Layout.preferredWidth: 84
                                }
                                Text {
                                    text: row.modelData.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: row.modelData.categoryName + " · " + row.modelData.accountName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDisabled
                                }
                                Text {
                                    text: (row.isIncome ? "+" : "-") + Theme.money(row.modelData.amountCents)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: row.isIncome ? Theme.colorIncome : Theme.colorExpense
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ----- 应用内自测 -----
    function runSelfTest() {
        let pass = 0, fail = 0
        function check(cond, msg) {
            if (cond) { pass++ }
            else { fail++; console.warn("STATS SELFTEST FAIL:", msg) }
        }

        // 一致性：JS 过滤合计 与 DB 汇总 一致（未加筛选时）
        typeFilter = -1; catFilter = -1; accFilter = -1; keyword = ""
        revision++
        check(filteredTotals.expense === rangeSummaryData.expenseCents,
              "支出合计：明细求和 == 区间汇总")
        check(filteredTotals.income === rangeSummaryData.incomeCents,
              "收入合计：明细求和 == 区间汇总")

        // 分布总和 == 区间支出
        let bdSum = 0
        for (let i = 0; i < catBd.length; i++)
            bdSum += catBd[i].totalCents
        check(bdSum === rangeSummaryData.expenseCents, "类别分布合计 == 区间支出")

        // 逐日合计 == 区间汇总
        let de = 0, di = 0
        for (let j = 0; j < daily.length; j++) {
            de += daily[j].expenseCents
            di += daily[j].incomeCents
        }
        check(de === rangeSummaryData.expenseCents && di === rangeSummaryData.incomeCents,
              "逐日合计 == 区间汇总")

        // 筛选：仅收入
        typeFilter = 1
        revision++
        let allIncome = true
        for (let k = 0; k < txs.length; k++)
            if (txs[k].type !== 1) { allIncome = false; break }
        check(allIncome && txs.length > 0, "仅收入筛选生效且非空")
        typeFilter = -1

        // 筛选：类别=餐饮（取当前月）
        const cats = DB.categories(0)
        const food = cats.find(c => c.name === "餐饮")
        catFilter = food ? food.id : -1
        revision++
        let allFood = true
        for (let k = 0; k < txs.length; k++)
            if (txs[k].categoryName !== "餐饮") { allFood = false; break }
        check(catFilter > 0 && allFood, "类别筛选生效")
        catFilter = -1

        // 筛选：关键词
        keyword = "午饭"
        revision++
        check(txs.length >= 1 && txs[0].title.indexOf("午饭") >= 0, "关键词筛选命中")
        keyword = ""
        revision++

        // 自定义区间：本周
        rangeMode = 2
        fromText = iso(weekStartOf(today))
        toText = iso(weekEndOf(today))
        revision++
        const weekTxs = txs
        rangeMode = 0
        revision++
        check(weekTxs.length === txs.length, "自定义本周 与 本周统计 一致")

        console.info("STATS SELFTEST RESULT pass=" + pass + " fail=" + fail)
        return fail === 0
    }
}
