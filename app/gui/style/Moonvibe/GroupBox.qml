import QtQuick 2.9
import QtQuick.Templates 2.5 as T

// Settings sections. A card with the title outside it reads as a section of a
// designed page, where the stock framed box reads as a desktop form.
T.GroupBox {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    topPadding: Theme.sp5 + (implicitLabelHeight > 0 ? implicitLabelHeight + Theme.sp3 : 0)
    bottomPadding: Theme.sp5
    leftPadding: Theme.sp5
    rightPadding: Theme.sp5
    spacing: Theme.sp3

    label: Text {
        x: control.leftPadding
        width: control.availableWidth

        // The title arrives wrapped in markup from the stock view; strip it so
        // the section headings match the rest of the app.
        text: control.title.replace(/<[^>]*>/g, "").toUpperCase()
        color: Theme.textMuted
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsMicro
        font.weight: Font.ExtraBold
        font.letterSpacing: 1.9
        elide: Text.ElideRight
    }

    background: Rectangle {
        y: control.topPadding - control.bottomPadding
        width: parent.width
        height: parent.height - control.topPadding + control.bottomPadding
        radius: Theme.cardRadius + 2
        color: Theme.panel
        border.color: Theme.line
        border.width: 1
    }
}
