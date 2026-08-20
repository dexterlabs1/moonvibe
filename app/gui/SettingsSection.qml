import QtQuick 2.9

// A titled block of settings. Replaces GroupBox, whose title sits on the
// border in the Material palette and drags the whole page back to stock Qt.
// Here the heading lives outside the card, tracked out in small caps the same
// way section headers read on the host and library screens.
//
// Children are placed directly inside the card:
//
//   SettingsSection {
//       width: ...
//       title: qsTr("Audio Settings")
//       MvCheckBox { ... }
//   }
Column {
    id: section

    property string title

    // Rhythm between the rows inside the card. A section that is a plain list
    // of checkboxes wants less than one mixing labels, controls and captions.
    property int contentSpacing: Theme.sp2

    default property alias content: body.data

    spacing: Theme.sp3

    // Redefining the default property redirects EVERY child declared with
    // brace syntax into it, including the two below, which would put the card
    // inside itself. Assigning `data` explicitly is how they stay put.
    data: [
        Text {
            id: heading
            leftPadding: Theme.sp1
            text: section.title.toUpperCase()
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.9
        },

        Rectangle {
            id: card

            // The section is always given an explicit width by its parent
            // column, so this cannot feed back into the Column's implicit width.
            width: section.width
            height: body.height + Theme.sp5 * 2

            radius: Theme.cardRadius + 2
            color: Theme.panel
            border.color: Theme.line
            border.width: 1

            Column {
                id: body
                x: Theme.sp5
                y: Theme.sp5
                width: card.width - Theme.sp5 * 2
                spacing: section.contentSpacing
            }
        }
    ]
}
