import QtQuick 2.9
import QtQuick.Templates 2.5 as T

T.CheckBox {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Theme.rowHeight,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: Theme.sp2
    spacing: Theme.sp3

    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        width: 24
        height: 24
        radius: 7
        color: control.checked ? Theme.accent : "transparent"
        border.color: !control.enabled ? Theme.line
                    : control.checked ? Theme.accent
                    : control.activeFocus ? Theme.accent
                    : Theme.lineHi
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        // Drawn rather than a glyph, so it scales and recolours with the design.
        Canvas {
            anchors.fill: parent
            visible: control.checked
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Theme.bg
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(width * 0.26, height * 0.52)
                ctx.lineTo(width * 0.44, height * 0.71)
                ctx.lineTo(width * 0.76, height * 0.30)
                ctx.stroke()
            }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? Theme.textColor : Theme.textFaint
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsBody
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 10
        color: control.activeFocus ? Theme.panelHi : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height * 0.5
            radius: 1.5
            color: Theme.accent
            visible: control.activeFocus
        }
    }
}
