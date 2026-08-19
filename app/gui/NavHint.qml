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
        color: Theme.lineHi
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: glyph
            color: Theme.textColor
            font.pixelSize: 12
            font.bold: true
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: label
        color: Theme.textMuted
        font.pixelSize: 13
        font.bold: true
    }
}
