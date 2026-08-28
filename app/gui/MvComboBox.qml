import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Window 2.2

// Combo box in the Moonvibe vocabulary. Every part the Material style owns is
// replaced explicitly — background, contentItem, indicator, popup and delegate
// — because the app runs on the Material style and anything left alone keeps
// its Material look.
//
// The closed control is a panel chip; the open list is a floating panel whose
// rows use the same focus treatment as the context menus.
ComboBox {
    id: control

    // An optional wrapped sublabel under the chip. Same reasoning as MvCheckBox:
    // a hover-only ToolTip is invisible on a handheld, so the explanation goes
    // on screen. The chip keeps its height; the control grows to hold the text.
    property string description: ""

    implicitHeight: Theme.controlHeight
                    + (description.length > 0 ? descriptionLabel.implicitHeight + Theme.sp1 : 0)

    // Carve the description strip out of the control's content box so the chip's
    // text and chevron stay centred in the top controlHeight rather than drifting
    // down into the sublabel.
    bottomPadding: description.length > 0 ? descriptionLabel.implicitHeight + Theme.sp1 : 0

    // rightPadding leaves the chevron its own lane. AutoResizingComboBox sizes
    // itself from leftPadding + textWidth + indicator.width + rightPadding, so
    // counting the indicator here buys the text a little slack rather than
    // costing it an ellipsis.
    leftPadding: Theme.sp4
    rightPadding: Theme.sp4 + (indicator ? indicator.width : 0)

    font.family: Theme.fontBody
    font.pixelSize: Theme.fsBody
    font.weight: Font.DemiBold

    background: Item {
        Rectangle {
            id: chip
            width: parent.width
            height: Theme.controlHeight
            radius: Theme.capsuleRadius
            color: control.enabled ? Theme.panel : Theme.bgRaised
            border.width: control.activeFocus ? 2 : 1
            border.color: !control.enabled ? Theme.line
                        : control.activeFocus ? Theme.accent
                        : control.hovered || control.down ? Theme.lineHi
                        : Theme.line
        }

        Text {
            id: descriptionLabel
            visible: control.description.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chip.bottom
            anchors.topMargin: Theme.sp1
            text: control.description
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsLabel
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }
    }

    contentItem: Text {
        text: control.displayText
        color: control.enabled ? Theme.textColor : Theme.textDisabled
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        implicitWidth: 16
        implicitHeight: 16
        x: control.width - width - Theme.sp4
        y: control.topPadding + (control.availableHeight - height) / 2

        // Drawn, not a glyph: no icon font to ship and no emoji to render
        // differently on every machine.
        Canvas {
            anchors.fill: parent

            property color stroke: !control.enabled ? Theme.textDisabled
                                 : control.activeFocus ? Theme.accent
                                 : Theme.textMuted
            onStrokeChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = stroke
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(width * 0.22, height * 0.40)
                ctx.lineTo(width * 0.50, height * 0.66)
                ctx.lineTo(width * 0.78, height * 0.40)
                ctx.stroke()
            }
        }
    }

    delegate: ItemDelegate {
        id: comboItem

        width: ListView.view.width
        height: Theme.rowHeight
        padding: 0
        hoverEnabled: control.hoverEnabled

        readonly property bool isCurrent: control.currentIndex === index

        highlighted: control.highlightedIndex === index

        background: Rectangle {
            radius: Theme.capsuleRadius
            color: comboItem.highlighted || comboItem.hovered ? Theme.panelHi : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 2
                width: 3
                height: parent.height * 0.55
                radius: 1.5
                color: Theme.accent
                visible: comboItem.highlighted
            }
        }

        contentItem: Text {
            leftPadding: Theme.sp4
            rightPadding: Theme.sp4
            text: control.textRole
                  ? (Array.isArray(control.model) ? modelData[control.textRole]
                                                  : model[control.textRole])
                  : modelData
            color: comboItem.highlighted ? Theme.textColor
                 : comboItem.isCurrent ? Theme.accent
                 : Theme.textMuted
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    popup: Popup {
        y: control.height + Theme.sp1
        width: control.width
        // The language list is long enough to run off the screen; clamp it to
        // the window and let the list scroll.
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         control.Window.height - topMargin - bottomMargin)
        topMargin: Theme.sp5
        bottomMargin: Theme.sp5
        padding: Theme.sp2
        font: control.font

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.durFast }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Theme.durFast }
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0

            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            color: Theme.floatBg
            radius: Theme.cardRadius
            border.color: Theme.lineHi
            border.width: 1
        }
    }
}
