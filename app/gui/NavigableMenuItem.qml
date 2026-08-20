import QtQuick 2.9
import QtQuick.Controls 2.5

MenuItem {
    id: control

    // Ensure focus can't be given to an invisible item
    enabled: visible
    focusPolicy: visible ? Qt.TabFocus : Qt.NoFocus

    implicitHeight: visible ? Theme.rowHeight : 0
    leftPadding: Theme.sp4
    rightPadding: Theme.sp4
    spacing: Theme.sp3

    // Focus and hover are the same visual state deliberately: on a handheld the
    // controller drives focus and there is no cursor, so a separate hover
    // treatment would only ever be seen with a mouse plugged in.
    background: Rectangle {
        radius: 10
        color: control.activeFocus || control.hovered ? Theme.panelHi : "transparent"

        Rectangle {
            // A left bar rather than a full border: reads as "you are here"
            // without boxing every row.
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

    contentItem: Text {
        leftPadding: control.checkable ? Theme.sp5 + Theme.sp2 : 0
        text: control.text
        color: !control.enabled ? Theme.textFaint
             : control.activeFocus ? Theme.textColor
             : Theme.textMuted
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsBody
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        visible: control.checkable
        implicitWidth: Theme.sp5
        implicitHeight: Theme.sp5
        x: control.leftPadding
        y: (control.height - height) / 2

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 6
            color: control.checked ? Theme.accent : "transparent"
            border.color: control.checked ? Theme.accent : Theme.lineHi
            border.width: 1.5

            // Drawn rather than a glyph so it scales and recolours with the
            // rest of the design.
            Canvas {
                anchors.fill: parent
                visible: control.checked
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Theme.bg
                    ctx.lineWidth = 2.6
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
    }

    onTriggered: {
        // We must close the context menu first or
        // it can steal focus from any dialogs that
        // onTriggered may spawn.
        menu.close()
    }

    Keys.onReturnPressed: {
        triggered()
    }

    Keys.onEnterPressed: {
        triggered()
    }

    Keys.onEscapePressed: {
        menu.close()
    }
}
