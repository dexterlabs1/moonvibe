import QtQuick 2.9
import QtQuick.Controls 2.5

// Checkbox in the Moonvibe vocabulary. Same API as CheckBox — text, checked,
// enabled, the ToolTip attached properties — so it drops in wherever the stock
// control was used.
//
// The row is a thumb target rather than a text-height control, and focus is
// drawn the way menu rows draw it: a panelHi fill with an accent bar on the
// left edge, so a gamepad user can see where they are from arm's length.
CheckBox {
    id: control

    hoverEnabled: true

    leftPadding: Theme.sp3
    rightPadding: Theme.sp3
    topPadding: Theme.sp2
    bottomPadding: Theme.sp2
    spacing: Theme.sp3

    font.family: Theme.fontBody
    font.pixelSize: Theme.fsBody
    font.weight: Font.DemiBold

    // A long label wraps rather than eliding — these are sentences, and half of
    // one tells the user nothing. The row grows to hold the second line; past
    // two lines the label is too long to be a checkbox and elides.
    implicitHeight: Math.max(Theme.rowHeight,
                             implicitContentHeight + topPadding + bottomPadding)

    // Focus and hover are deliberately the same state: the Deck has no cursor,
    // so a separate hover treatment would only ever be seen with a mouse.
    background: Rectangle {
        radius: Theme.capsuleRadius
        color: control.activeFocus || control.hovered ? Theme.panelHi : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 2
            width: 3
            height: parent.height * 0.55
            radius: 1.5
            color: Theme.accent
            visible: control.activeFocus
        }
    }

    indicator: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.controlRadius

        color: !control.checked ? "transparent"
             : control.enabled ? Theme.accent
             : Theme.line
        border.width: 1.5
        border.color: !control.enabled ? Theme.line
                    : control.checked ? Theme.accent
                    : control.activeFocus ? Theme.accent
                    : Theme.lineHi

        // Drawn rather than a glyph so it scales and recolours with the rest of
        // the design instead of depending on a font.
        Canvas {
            id: checkCanvas
            anchors.fill: parent
            visible: control.checked

            property color mark: control.enabled ? Theme.bg : Theme.textDisabled
            onMarkChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = mark
                ctx.lineWidth = 2.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(width * 0.26, height * 0.52)
                ctx.lineTo(width * 0.44, height * 0.70)
                ctx.lineTo(width * 0.76, height * 0.31)
                ctx.stroke()
            }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator ? control.indicator.width + control.spacing : 0
        text: control.text
        color: control.enabled ? Theme.textColor : Theme.textDisabled
        font: control.font
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
