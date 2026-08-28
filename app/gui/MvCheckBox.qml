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

    // An optional wrapped sublabel under the label. On a handheld there is no
    // hover, so a control that explains itself only through a ToolTip explains
    // itself to nobody — the description says the same thing on screen.
    property string description: ""

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

    // The label line height, used to sit the indicator on the first line when a
    // description makes the content taller than a single row.
    FontMetrics {
        id: labelMetrics
        font: control.font
    }

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
        // Centre in the row as before when it's just a label; with a
        // description the content is taller, so pin the box to the first line.
        y: control.description.length > 0
           ? control.topPadding + Math.max(0, (labelMetrics.height - height) / 2)
           : control.topPadding + (control.availableHeight - height) / 2
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

    contentItem: Column {
        leftPadding: control.indicator ? control.indicator.width + control.spacing : 0
        spacing: Theme.sp1

        Text {
            id: labelText
            width: parent.width - parent.leftPadding
            // With no description this fills the row so the single line centres
            // vertically exactly as it did before; with one it hugs its text so
            // the sublabel sits directly beneath.
            height: control.description.length > 0
                    ? implicitHeight
                    : Math.max(implicitHeight, control.availableHeight)
            text: control.text
            color: control.enabled ? Theme.textColor : Theme.textDisabled
            font: control.font
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: descriptionText
            visible: control.description.length > 0
            width: parent.width - parent.leftPadding
            text: control.description
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsLabel
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }
    }
}
