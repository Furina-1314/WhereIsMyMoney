pragma Singleton
import QtQuick
import QtCore

// Win10 UWP / Groove Music 风格主题（深色/浅色可切换，选择持久化）
QtObject {
    id: theme

    // 持久化外观选择（QtObject 无默认 children 属性，Settings 挂到显式属性）
    property Settings _store: Settings {
        category: "Appearance"
        property bool dark: true
    }

    // 外观模式：默认读持久化设置；测试可用 WIMM_THEME=light/dark 强制
    property bool dark: initialTheme === "light" ? false
                        : initialTheme === "dark" ? true
                        : _store.dark
    property bool _booted: false
    Component.onCompleted: _booted = true
    onDarkChanged: if (_booted) _store.dark = dark // 启动加载不写回

    // 背景与面板
    readonly property color bg: dark ? "#121212" : "#EDEDED"            // 主背景
    readonly property color sidebarBg: dark ? "#0B0B0B" : "#F5F5F5"      // 导航侧栏
    readonly property color panelBg: dark ? "#1D1D1D" : "#FAFAFA"        // 卡片/面板
    readonly property color panelBgAlt: dark ? "#242424" : "#FFFFFF"     // 面板内分层/对话框
    readonly property color itemBg: dark ? "#2A2A2A" : "#F4F4F4"         // 输入框/按钮底色
    readonly property color itemBgHover: dark ? "#333333" : "#EAEAEA"
    readonly property color itemBgPressed: dark ? "#3D3D3D" : "#DEDEDE"
    readonly property color itemBgFocus: dark ? "#2F2F2F" : "#E6E6E6"    // 输入控件悬停/聚焦底色
    readonly property color stroke: dark ? "#383838" : "#D8D8D8"         // 描边
    readonly property color strokeHover: dark ? "#4A4A4A" : "#B8B8B8"    // 悬停描边
    readonly property color navActiveBg: dark ? "#1A1A1A" : "#E1E1E1"    // 导航选中底色

    // 文字
    readonly property color textPrimary: dark ? "#FFFFFF" : "#1B1B1B"
    readonly property color textSecondary: dark ? "#A6A6A6" : "#5F5F5F"
    readonly property color textDisabled: dark ? "#656565" : "#9C9C9C"

    // 强调色与状态色（Win10 系统色，深浅色通用）
    readonly property color accent: "#0078D7"
    readonly property color accentHover: "#1B93E0"
    readonly property color accentPressed: "#005A9E"
    readonly property color colorIncome: "#10893E"   // 收入（Win10 绿）
    readonly property color colorExpense: "#E81123"  // 支出（Win10 红）

    // 滚动条
    readonly property color scrollBar: dark ? "#4A4A4A" : "#C2C2C2"
    readonly property color scrollBarHover: dark ? "#6A6A6A" : "#A0A0A0"

    // 字体
    readonly property string fontFamily: "Segoe UI"
    readonly property string iconFontFamily: "Segoe MDL2 Assets"

    // 圆角（UWP 小圆角）
    readonly property int radiusControl: 3
    readonly property int radiusPanel: 5

    // 间距
    readonly property int spacingSmall: 6
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 20
    readonly property int spacingHuge: 32

    // 尺寸
    readonly property int controlHeight: 32
    readonly property int sidebarWidth: 216

    // 手动千分位分组：1234567 -> "1,234,567"（不依赖系统 locale）
    function groupDigits(n) {
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    // 金额显示：分 -> 元字符串，固定两位小数、整数部分逗号分组
    function money(cents, withSign) {
        const negative = cents < 0
        const abs = Math.abs(cents)
        const yuan = Math.floor(abs / 100)
        const fen = abs % 100
        const s = groupDigits(yuan) + "." + (fen < 10 ? "0" : "") + fen
        if (negative)
            return "-" + s
        if (withSign)
            return "+" + s
        return s
    }

    // 输入框回填用：无千分位逗号（配合金额校验正则）
    function moneyPlain(cents) {
        const abs = Math.abs(cents)
        const yuan = Math.floor(abs / 100)
        const fen = abs % 100
        return (cents < 0 ? "-" : "") + yuan + "." + (fen < 10 ? "0" : "") + fen
    }
}
