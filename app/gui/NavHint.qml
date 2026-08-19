import QtQuick 2.9

// One controller-glyph hint chip for the footer bar, e.g. (A) Select
Row {
    property string glyph: "A"
    property string label: ""

    spacing: 8

    Rectangle {
        width: 22
        height: 22
        radius: 11
        color: Theme.glyphBg
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: glyph
            color: Theme.textColor
            font.family: Theme.fontBody
            font.pixelSize: 12
            font.weight: Font.ExtraBold
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: label
        color: Theme.textMuted
        font.family: Theme.fontBody
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
}
