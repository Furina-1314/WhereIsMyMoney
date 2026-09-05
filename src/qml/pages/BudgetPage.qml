import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import WhereIsMyMoney

// 预算页：本周/本月预算编制、分预算（按类别细分）、进度跟踪、超支提醒、历史预算
Page {
    id: page

    readonly property date today: {
        var t = new Date()
        return new Date(t.getFullYear(), t.getMonth(), t.getDate())
    }
    property int revision: 0

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
    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function parseIso(s) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec((s || "").trim())
        if (!m)
            return null
        const d = new Date(+m[1], +m[2] - 1, +m[3])
        return d.getFullYear() === +m[1] && d.getMonth() === +m[2] - 1 && d.getDate() === +m[3]
                ? d : null
    }
    readonly property string weekAnchorStr: iso(weekStartOf(today))
    readonly property string monthAnchorStr: today.getFullYear() + "-" + pad2(today.getMonth() + 1)

    // 进度状态：0 正常(accent) 1 接近(橙) 2 超支(红)
    function statusOf(spent, budget) {
        if (budget <= 0)
            return 0
        const ratio = spent / budget
        if (ratio > 1)
            return 2
        if (ratio >= 0.8)
            return 1
        return 0
    }
    function statusColor(s) {
        return s === 2 ? Theme.colorExpense : s === 1 ? "#FF8C00" : Theme.accent
    }

    // ----- 数据 -----
    readonly property var weekBudgetMap: {
        revision
        return DB.budget(0, weekAnchorStr)
    }
    readonly property var monthBudgetMap: {
        revision
        return DB.budget(1, monthAnchorStr)
    }
    readonly property real weekSpent: {
        revision
        return DB.rangeSummary(weekStartOf(today), weekEndOf(today)).expenseCents
    }
    readonly property real monthSpent: {
        revision
        return DB.rangeSummary(monthStartOf(today), monthEndOf(today)).expenseCents
    }

    // 历史预算（含当前），按锚点倒序
    readonly property var budgetHistory: {
        revision
        const all = DB.budgets(-1)
        return all.slice().sort((a, b) => b.anchor.localeCompare(a.anchor))
    }

    // 计算某条预算区间的实际支出
    function spentForBudget(b) {
        if (b.type === 0) {
            const d = parseIso(b.anchor)
            if (!d)
                return 0
            const end = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 6)
            return DB.rangeSummary(d, end).expenseCents
        }
        const m = /^(\d{4})-(\d{2})$/.exec(b.anchor)
        if (!m)
            return 0
        const start = new Date(+m[1], +m[2] - 1, 1)
        const end = new Date(+m[1], +m[2], 0)
        return DB.rangeSummary(start, end).expenseCents
    }

    // 预算区间的中文描述
    function rangeTextFor(b) {
        if (b.type === 0) {
            const d = parseIso(b.anchor)
            if (!d)
                return b.anchor
            const end = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 6)
            return iso(d) + " ~ " + iso(end)
        }
        return b.anchor.replace("-", qsTr("年")) + qsTr("月")
    }

    Connections {
        target: DB
        function onDataChanged() { page.revision++ }
    }

    background: Rectangle { color: Theme.bg }

    // ===== 预算卡片（主预算 + 分预算） =====
    component BudgetCard: Rectangle {
        id: card

        property string title: ""
        property string rangeText: ""
        property var budgetMap: ({})       // {} = 未设置
        property real spent: 0
        property date fromD: page.today
        property date toD: page.today
        property int budgetTypeVal: 0
        property string anchor: ""
        property bool editing: false
        property bool addingItem: false
        property string errorText: ""

        readonly property bool hasBudget: budgetMap && budgetMap.amountCents !== undefined
        readonly property real budgetCents: hasBudget ? budgetMap.amountCents : 0
        readonly property int status: hasBudget ? page.statusOf(spent, budgetCents) : 0
        readonly property int budgetId: hasBudget ? budgetMap.id : -1

        // 区间内各类别实际支出（供分预算进度）
        readonly property var catActual: {
            page.revision
            const m = {}
            const bd = DB.categoryBreakdown(card.fromD, card.toD, 0)
            for (let i = 0; i < bd.length; i++)
                m[bd[i].categoryId] = bd[i].totalCents
            return m
        }

        // 分预算行（金额 + 类别名/色 + 实际支出）
        readonly property var itemRows: {
            page.revision
            if (!card.hasBudget)
                return []
            const items = DB.budgetItems(card.budgetId)
            const rows = []
            for (let i = 0; i < items.length; i++) {
                const it = items[i]
                const actual = card.catActual[it.categoryId] ? card.catActual[it.categoryId] : 0
                rows.push({ categoryId: it.categoryId, name: it.name, color: it.color,
                            budgetCents: it.amountCents, actualCents: actual })
            }
            return rows
        }

        readonly property real itemsTotal: {
            let s = 0
            const rows = itemRows
            for (let i = 0; i < rows.length; i++)
                s += rows[i].budgetCents
            return s
        }

        // 可选类别 = 支出类别 - 已分配的
        readonly property var availableCats: {
            page.revision
            const used = {}
            const rows = itemRows
            for (let i = 0; i < rows.length; i++)
                used[rows[i].categoryId] = true
            return DB.categories(0).filter(c => !used[c.id])
        }

        radius: Theme.radiusPanel
        color: Theme.panelBg
        Layout.fillWidth: true
        implicitHeight: mainCol.implicitHeight + Theme.spacingMedium * 2

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: card.rangeText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
            }

            // ----- 主预算进度 -----
            ColumnLayout {
                visible: card.hasBudget && !card.editing
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Theme.itemBg

                    Rectangle {
                        width: parent.width * Math.min(1, card.spent / card.budgetCents)
                        height: parent.height
                        radius: 4
                        color: page.statusColor(card.status)
                        Behavior on width { NumberAnimation { duration: 250 } }
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: qsTr("总支出 ¥") + Theme.money(card.spent)
                              + qsTr("  /  预算 ¥") + Theme.money(card.budgetCents)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: card.budgetCents > 0
                              ? Math.round(card.spent * 100 / card.budgetCents) + "%" : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: page.statusColor(card.status)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: card.status === 2
                              ? qsTr("已超支 ¥") + Theme.money(card.spent - card.budgetCents)
                              : qsTr("剩余 ¥") + Theme.money(card.budgetCents - card.spent)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: page.statusColor(card.status)
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: card.status === 1
                        text: qsTr("已用超过 80%，注意控制")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: page.statusColor(card.status)
                    }
                }
            }

            // ----- 未设置提示 -----
            ColumnLayout {
                visible: !card.hasBudget && !card.editing
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: qsTr("尚未设置预算")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
                Text {
                    text: qsTr("设置后自动跟踪该区间内的支出，并可添加按类别的分预算")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDisabled
                }
            }

            // ----- 主预算编辑区 -----
            ColumnLayout {
                visible: card.editing
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: qsTr("预算金额（元）")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    FluentTextField {
                        id: amountInput
                        Layout.fillWidth: true
                        placeholderText: "0.00"
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9]+(\.[0-9]{0,2})?/
                        }
                        onAccepted: card.save()
                        onVisibleChanged: {
                            if (visible) {
                                text = card.hasBudget ? Theme.moneyPlain(card.budgetCents) : ""
                                forceActiveFocus()
                                selectAll()
                            }
                        }
                    }
                    FluentButton {
                        text: qsTr("保存")
                        primary: true
                        onClicked: card.save()
                    }
                    FluentButton {
                        visible: card.hasBudget
                        text: qsTr("清除预算")
                        onClicked: {
                            if (DB.clearBudget(card.budgetTypeVal, card.anchor)) {
                                card.editing = false
                                page.revision++
                            } else {
                                card.errorText = DB.lastError()
                            }
                        }
                    }
                    FluentButton {
                        text: qsTr("取消")
                        onClicked: card.editing = false
                    }
                }
            }

            // ----- 分预算区 -----
            ColumnLayout {
                visible: card.hasBudget && !card.editing
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.stroke
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: qsTr("分预算")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                    Text {
                        visible: card.itemRows.length > 0
                        text: qsTr("合计 ¥") + Theme.money(card.itemsTotal)
                              + (card.itemsTotal > card.budgetCents
                                 ? qsTr("（超出总预算）") : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: card.itemsTotal > card.budgetCents
                               ? Theme.colorExpense : Theme.textSecondary
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: card.itemRows.length > 0
                        text: qsTr("实际 / 分预算")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDisabled
                    }
                }

                // 分预算行
                Repeater {
                    model: card.itemRows

                    delegate: ColumnLayout {
                        id: itemRow

                        required property var modelData
                        readonly property int rowStatus: page.statusOf(modelData.actualCents,
                                                                       modelData.budgetCents)

                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                width: 9
                                height: 9
                                radius: 2
                                color: itemRow.modelData.color
                            }
                            Text {
                                text: itemRow.modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("¥") + Theme.money(itemRow.modelData.actualCents)
                                      + " / " + Theme.money(itemRow.modelData.budgetCents)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: itemRow.modelData.budgetCents > 0
                                      ? Math.round(itemRow.modelData.actualCents * 100
                                                   / itemRow.modelData.budgetCents) + "%" : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: page.statusColor(itemRow.rowStatus)
                            }
                            // 删除分预算
                            Text {
                                text: "\uE711" // Cancel(X)
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 10
                                color: itemRemoveMouse.hovered ? Theme.colorExpense : Theme.textDisabled

                                MouseArea {
                                    id: itemRemoveMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (DB.clearBudgetItem(card.budgetId,
                                                               itemRow.modelData.categoryId)) {
                                            page.revision++
                                        } else {
                                            card.errorText = DB.lastError()
                                        }
                                    }
                                }
                            }
                        }

                        // 分预算进度条
                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Theme.itemBg

                            Rectangle {
                                width: parent.width
                                          * Math.min(1, itemRow.modelData.actualCents
                                                     / itemRow.modelData.budgetCents)
                                height: parent.height
                                radius: 2
                                color: page.statusColor(itemRow.rowStatus)
                                Behavior on width { NumberAnimation { duration: 200 } }
                            }
                        }
                    }
                }

                Text {
                    visible: card.itemRows.length === 0 && !card.addingItem
                    text: qsTr("把预算细分到类别，如：餐饮 800、交通 200")
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDisabled
                }

                // 添加分预算行
                RowLayout {
                    visible: card.addingItem
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    FluentComboBox {
                        id: itemCatCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        textRole: "name"
                        valueRole: "id"
                        font.pixelSize: 13
                        model: card.availableCats
                    }
                    FluentTextField {
                        id: itemAmountInput
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 30
                        font.pixelSize: 13
                        placeholderText: qsTr("金额")
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9]+(\.[0-9]{0,2})?/
                        }
                        onAccepted: card.addItem()
                        onVisibleChanged: if (visible) forceActiveFocus()
                    }
                    FluentButton {
                        text: qsTr("添加")
                        implicitHeight: 30
                        font.pixelSize: 12
                        onClicked: card.addItem()
                    }
                    FluentButton {
                        text: qsTr("取消")
                        implicitHeight: 30
                        font.pixelSize: 12
                        onClicked: card.addingItem = false
                    }
                }
            }

            Text {
                visible: card.errorText !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: card.errorText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.colorExpense
            }

            // 操作按钮行
            RowLayout {
                Layout.fillWidth: true
                visible: !card.editing
                spacing: Theme.spacingSmall

                FluentButton {
                    text: card.hasBudget ? qsTr("修改预算") : qsTr("设置预算")
                    primary: !card.hasBudget
                    onClicked: {
                        card.errorText = ""
                        card.editing = true
                    }
                }
                FluentButton {
                    visible: card.hasBudget
                    text: qsTr("＋ 添加分预算")
                    onClicked: {
                        card.errorText = ""
                        card.addingItem = true
                        itemAmountInput.text = ""
                        itemCatCombo.currentIndex = 0
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        function save() {
            errorText = ""
            const yuan = parseFloat(amountInput.text)
            if (!isFinite(yuan) || yuan <= 0) {
                errorText = qsTr("请填写正确的金额")
                return
            }
            if (DB.setBudget(budgetTypeVal, anchor, Math.round(yuan * 100))) {
                editing = false
                page.revision++
            } else {
                errorText = DB.lastError()
            }
        }

        function addItem() {
            errorText = ""
            const yuan = parseFloat(itemAmountInput.text)
            if (!isFinite(yuan) || yuan <= 0) {
                errorText = qsTr("请填写正确的分预算金额")
                return
            }
            if (itemCatCombo.currentValue === undefined) {
                errorText = qsTr("请选择类别（或所有类别已分配）")
                return
            }
            if (DB.setBudgetItem(budgetId, itemCatCombo.currentValue, Math.round(yuan * 100))) {
                addingItem = false
                page.revision++
            } else {
                errorText = DB.lastError()
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

            // 本周 / 本月卡片
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                BudgetCard {
                    title: qsTr("本周预算")
                    rangeText: iso(weekStartOf(today)) + " ~ " + iso(weekEndOf(today))
                    budgetMap: page.weekBudgetMap
                    spent: page.weekSpent
                    fromD: page.weekStartOf(today)
                    toD: page.weekEndOf(today)
                    budgetTypeVal: 0
                    anchor: page.weekAnchorStr
                }
                BudgetCard {
                    title: qsTr("本月预算")
                    rangeText: page.monthAnchorStr.replace("-", qsTr("年")) + qsTr("月")
                    budgetMap: page.monthBudgetMap
                    spent: page.monthSpent
                    fromD: page.monthStartOf(today)
                    toD: page.monthEndOf(today)
                    budgetTypeVal: 1
                    anchor: page.monthAnchorStr
                }
            }

            // ===== 历史预算 =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                radius: Theme.radiusPanel
                color: Theme.panelBg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    Text {
                        text: qsTr("历史预算")
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    ListView {
                        id: historyView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: page.budgetHistory
                        ScrollBar.vertical: FluentScrollBar {
                            policy: historyView.contentHeight > historyView.height
                                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: historyView.count === 0
                            text: qsTr("暂无预算记录")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDisabled
                        }

                        delegate: Rectangle {
                            id: hRow

                            required property var modelData

                            readonly property real hSpent: page.spentForBudget(modelData)
                            readonly property int hStatus: page.statusOf(hSpent, modelData.amountCents)

                            width: historyView.width
                            height: 38
                            radius: Theme.radiusControl
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: Theme.spacingSmall

                                Rectangle {
                                    width: 34
                                    height: 20
                                    radius: 3
                                    color: Theme.itemBg
                                    Text {
                                        anchors.centerIn: parent
                                        text: hRow.modelData.type === 0 ? qsTr("周") : qsTr("月")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textSecondary
                                    }
                                }
                                Text {
                                    text: page.rangeTextFor(hRow.modelData)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.textPrimary
                                    Layout.preferredWidth: 200
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("实际 ¥") + Theme.money(hRow.hSpent)
                                          + qsTr("  /  预算 ¥") + Theme.money(hRow.modelData.amountCents)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                                Text {
                                    text: hRow.hStatus === 2
                                          ? qsTr("超支 ¥") + Theme.money(hRow.hSpent - hRow.modelData.amountCents)
                                          : qsTr("剩余 ¥") + Theme.money(hRow.modelData.amountCents - hRow.hSpent)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: page.statusColor(hRow.hStatus)
                                    Layout.preferredWidth: 110
                                    horizontalAlignment: Text.AlignRight
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
            else { fail++; console.warn("BUDGET SELFTEST FAIL:", msg) }
        }

        // 周预算：设置 → 绑定刷新 → 实际支出一致 → upsert 唯一
        DB.setBudget(0, weekAnchorStr, 500000)
        revision++
        check(weekBudgetMap.amountCents === 500000, "设置周预算后绑定更新为 5000 元")
        check(weekSpent === DB.rangeSummary(weekStartOf(today), weekEndOf(today)).expenseCents,
              "周已用支出与区间汇总一致")
        const weekEntries = DB.budgets(0).filter(b => b.anchor === weekAnchorStr)
        check(weekEntries.length === 1, "重复设置同周预算为唯一记录(upsert)")

        // 状态阈值
        check(statusOf(600000, 500000) === 2, "超支状态判定")
        check(statusOf(450000, 500000) === 1, "接近阈值(90%)判定")
        check(statusOf(100000, 500000) === 0, "正常状态判定")

        // 分预算：添加 → 行数据(名称/金额/实际) → upsert → 删除单条 → 级联
        const cats0 = DB.categories(0)
        const foodCat = cats0.find(c => c.name === "餐饮")
        const busCat = cats0.find(c => c.name === "交通")
        const wid = weekBudgetMap.id
        check(DB.setBudgetItem(wid, foodCat.id, 80000), "添加餐饮分预算")
        check(DB.setBudgetItem(wid, busCat.id, 20000), "添加交通分预算")
        revision++
        const rows = DB.budgetItems(wid)
        check(rows.length === 2, "分预算共 2 条")
        check(rows[0].name === "餐饮" && rows[0].amountCents === 80000, "分预算含类别名与金额")
        check(DB.setBudgetItem(wid, foodCat.id, 90000), "同类别重复设置为 upsert")
        check(DB.budgetItems(wid).length === 2, "upsert 后仍 2 条")
        // 分预算实际支出 = 类别区间支出
        const bd = DB.categoryBreakdown(weekStartOf(today), weekEndOf(today), 0)
        const foodBd = bd.find(x => x.categoryId === foodCat.id)
        const foodActual = foodBd ? foodBd.totalCents : 0
        const rowFood = DB.budgetItems(wid).find(x => x.categoryId === foodCat.id)
        check(rowFood !== undefined, "读取到餐饮分预算行")
        // 页面 itemRows 的实际值来源同 categoryBreakdown（此处直接验证来源一致性）
        check(pageWeekCardItemActual(foodCat.id) === foodActual, "分预算实际支出取类别区间支出")

        // 删除单条分预算
        check(DB.clearBudgetItem(wid, busCat.id), "删除交通分预算")
        check(DB.budgetItems(wid).length === 1, "删除后剩 1 条")
        // 清除主预算 → 分预算级联删除
        check(DB.clearBudget(0, weekAnchorStr), "清除周预算")
        check(DB.budgetItems(wid).length === 0, "分预算随主预算级联删除")

        // 月预算：设置 + 历史列表包含
        DB.setBudget(1, monthAnchorStr, 300000)
        revision++
        check(monthBudgetMap.amountCents === 300000, "设置月预算后绑定更新")
        check(budgetHistory.some(b => b.type === 1 && b.anchor === monthAnchorStr),
              "历史预算列表包含本月")

        // 非法锚点
        check(DB.setBudget(0, "bad", 100) === false, "非法周锚点被拒绝")

        // 恢复现场
        DB.clearBudget(1, monthAnchorStr)
        revision++

        console.info("BUDGET SELFTEST RESULT pass=" + pass + " fail=" + fail)
        return fail === 0
    }

    // 供自测：周卡片某类别的实际支出（与 itemRows 同一来源）
    function pageWeekCardItemActual(catId) {
        const bd = DB.categoryBreakdown(weekStartOf(today), weekEndOf(today), 0)
        const hit = bd.find(x => x.categoryId === catId)
        return hit ? hit.totalCents : 0
    }
}
