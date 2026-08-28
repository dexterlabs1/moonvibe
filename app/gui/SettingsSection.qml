import QtQuick 2.9

// A titled block of settings. Replaces GroupBox, whose title sits on the
// border in the Material palette and drags the whole page back to stock Qt.
//
// The controls sit directly on the settings pane rather than inside a bordered
// card: a card here nests a framed box inside the pane, which is itself inside
// the window -- a "window within a window". A small-caps heading and the
// whitespace between sections carry the grouping instead, the same way the host
// and library screens read.
//
//   SettingsSection {
//       width: ...
//       title: qsTr("Audio Settings")
//       MvCheckBox { ... }
//   }
Column {
    id: section

    property string title

    // Rhythm between the rows. A section that is a plain list of checkboxes
    // wants less than one mixing labels, controls and captions.
    property int contentSpacing: Theme.sp2

    default property alias content: body.data

    spacing: Theme.sp4

    // Redefining the default property redirects EVERY child declared with
    // brace syntax into it, including the two below. Assigning `data` explicitly
    // is how they stay put.
    data: [
        Text {
            id: heading
            text: section.title.toUpperCase()
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.9
        },

        Column {
            id: body
            width: section.width
            spacing: section.contentSpacing
        }
    ]
}
