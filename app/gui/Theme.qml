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
    readonly property color textFaint: "#4b5069"
    readonly property color accent: "#8fa6ff"
    readonly property color accentDeep: "#5f79e8"
    readonly property color ok: "#5bd58c"
    readonly property color warn: "#f0b35c"
    readonly property color danger: "#ef7373"

    // Pill and chip surfaces from the mockups
    readonly property color pill: "#171a29"
    readonly property color glyphBg: "#262b40"
    readonly property color topGlow: "#171a2c"

    // Bundled typefaces, registered in main.cpp before QML loads.
    // Manrope carries the UI text; Space Grotesk is the display face used for
    // app titles and the wordmark, always uppercase with wide tracking.
    readonly property string fontBody: "Manrope"
    readonly property string fontDisplay: "Space Grotesk"

    // Surfaces that float above the page: menus, dialogs, drawers.
    readonly property color floatBg: "#191c2b"
    readonly property color scrim: "#C004050A"

    // Spacing scale. Everything spatial picks from this rather than inventing
    // a number, which is what keeps unrelated screens feeling related.
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 24
    readonly property int sp6: 32
    readonly property int sp7: 56

    // Type ramp. Display is Space Grotesk and always uppercase with tracking;
    // body is Manrope.
    readonly property int fsDisplay: 40
    readonly property int fsTitle: 22
    readonly property int fsBody: 15
    readonly property int fsLabel: 13
    readonly property int fsMicro: 11

    // Anything a thumb has to hit. The Deck is held at arm's length, so this
    // is a floor, not a target.
    readonly property int rowHeight: 52
    readonly property int controlHeight: 44

    readonly property int durFast: 110
    readonly property int durBase: 180

    readonly property int cardRadius: 12
    readonly property int capsuleRadius: 10

    // Library capsule geometry: 2:3, the Steam capsule aspect.
    readonly property int capsuleWidth: 152
    readonly property int capsuleHeight: 224

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

    // "3h ago" / "yesterday" — short enough for a card, vague enough to stay
    // true without a timer refreshing it every minute.
    function relativeTime(msSinceEpoch) {
        if (!msSinceEpoch) {
            return qsTr("Never played")
        }

        var mins = Math.floor((Date.now() - msSinceEpoch) / 60000)
        if (mins < 2)    return qsTr("Just now")
        if (mins < 60)   return qsTr("%1 min ago").arg(mins)

        var hours = Math.floor(mins / 60)
        if (hours < 24)  return qsTr("%1h ago").arg(hours)

        var days = Math.floor(hours / 24)
        if (days === 1)  return qsTr("Yesterday")
        if (days < 30)   return qsTr("%1 days ago").arg(days)

        var months = Math.floor(days / 30)
        if (months < 12) return qsTr("%1 mo ago").arg(months)

        return qsTr("Over a year ago")
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
