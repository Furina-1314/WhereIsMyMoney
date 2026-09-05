pragma Singleton
import QtQuick

// Win10 UWP / Groove Music 风格深色主题
QtObject {
    id: theme

    // 背景与面板
    readonly property color bg: "#121212"            // 主背景（近黑）
    readonly property color sidebarBg: "#0B0B0B"     // 导航侧栏
    readonly property color panelBg: "#1D1D1D"       // 卡片/面板
    readonly property color panelBgAlt: "#242424"    // 面板内分层
    readonly property color itemBg: "#2A2A2A"        // 输入框/按钮底色
    readonly property color itemBgHover: "#333333"
    readonly property color itemBgPressed: "#3D3D3D"
    readonly property color stroke: "#383838"        // 描边

    // 文字
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#A6A6A6"
    readonly property color textDisabled: "#656565"

    // 强调色与状态色（Win10 系统色）
    readonly property color accent: "#0078D7"
    readonly property color accentHover: "#1B93E0"
    readonly property color accentPressed: "#005A9E"
    readonly property color colorIncome: "#10893E"   // 收入（Win10 绿）
    readonly property color colorExpense: "#E81123"  // 支出（Win10 红）

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

    // 金额显示：分 -> 元字符串
    function money(cents, withSign) {
        const negative = cents < 0
        const abs = Math.abs(cents)
        const yuan = Math.floor(abs / 100)
        const fen = abs % 100
        const s = yuan.toLocaleString(Qt.locale("zh_CN"))
                  + "." + (fen < 10 ? "0" : "") + fen
        if (negative)
            return "-" + s
        if (withSign)
            return "+" + s
        return s
    }
}
