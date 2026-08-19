pragma Singleton
import QtQuick 2.9

// Moonvibe design tokens — dark, OLED-first. See docs/PRODUCT.md §3.1.
QtObject {
    readonly property color bg: "#0d0e15"
    readonly property color bgRaised: "#12131d"
    readonly property color panel: "#161826"
    readonly property color panelHi: "#1d2032"
    readonly property color line: "#23273a"
    readonly property color lineHi: "#2a2e45"
    readonly property color textColor: "#eceef8"
    readonly property color textMuted: "#8b91ad"
    readonly property color textFaint: "#6b7190"
    readonly property color accent: "#8fa6ff"
    readonly property color accentDeep: "#5f79e8"
    readonly property color ok: "#5bd58c"
    readonly property color warn: "#f0b35c"
    readonly property color danger: "#ef7373"

    readonly property int cardRadius: 12

    // Deterministic hue per app name for monogram placeholder tiles
    function hueFor(name) {
        var h = 0
        for (var i = 0; i < name.length; i++) {
            h = (h * 31 + name.charCodeAt(i)) % 360
        }
        return h / 360
    }

    function monogramTop(name) {
        return Qt.hsla(hueFor(name), 0.32, 0.30, 1.0)
    }

    function monogramBottom(name) {
        return Qt.hsla(hueFor(name), 0.38, 0.11, 1.0)
    }

    function initialsFor(name) {
        var words = name.trim().split(/\s+/)
        var initials = ""
        for (var i = 0; i < words.length && initials.length < 2; i++) {
            var ch = words[i].charAt(0).toUpperCase()
            if (ch >= "A" && ch <= "Z" || ch >= "0" && ch <= "9") {
                initials += ch
            }
        }
        return initials.length > 0 ? initials : name.charAt(0).toUpperCase()
    }
}
