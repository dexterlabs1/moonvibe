import QtQuick 2.9

// A "Continue" card for the library hero row. Landscape rather than a capsule,
// because these are about picking up where you left off, not browsing.
Item {
    id: card

    property string appName: ""
    property url boxart: ""
    property bool running: false
    property double lastPlayed: 0
    property bool highlighted: activeFocus

    signal activated()
    signal optionsRequested()

    width: 296
    height: 166
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.panel
        border.color: card.highlighted ? Theme.accent : Theme.line
        border.width: card.highlighted ? 2 : 1
        clip: true

        // Box art, cropped to the landscape card. Portrait capsule art fills the
        // width and centres vertically, which reads better than letterboxing it.
        Image {
            id: art
            property bool isPlaceholder: false

            anchors.fill: parent
            anchors.margins: 1
            visible: !isPlaceholder && status === Image.Ready
            source: card.boxart
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            onSourceSizeChanged: {
                // Same placeholder dimensions the capsule grid keys off: GFE 2.0,
                // GFE 3.0, and our own no_app_image.png.
                isPlaceholder = (sourceSize.width === 130 && sourceSize.height === 180) ||
                                (sourceSize.width === 628 && sourceSize.height === 888) ||
                                (sourceSize.width === 200 && sourceSize.height === 266)
            }
        }

        // Monogram fallback when the host serves no real art
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            visible: art.isPlaceholder || art.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.monogramTop(card.appName) }
                GradientStop { position: 1.0; color: Theme.monogramBottom(card.appName) }
            }

            Text {
                anchors.centerIn: parent
                text: Theme.initialsFor(card.appName)
                color: Qt.rgba(1, 1, 1, 0.30)
                font.pointSize: 40
                font.bold: true
            }
        }

        // Host artwork is often a bright logo on a light plate, with the game
        // name already baked into the image. A flat knock-back over the whole
        // card keeps our own title readable and stops the two sets of text
        // competing.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "#59080a10"
        }

        // Scrim so the title stays legible over any artwork
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 96
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00080a10" }
                GradientStop { position: 0.45; color: "#B3080a10" }
                GradientStop { position: 1.0; color: "#FA080a10" }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 3

            Text {
                width: parent.width
                text: card.appName
                color: Theme.textColor
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: card.running ? qsTr("Running now")
                                   : Theme.relativeTime(card.lastPlayed)
                color: card.running ? Theme.ok : Theme.textMuted
                font.pixelSize: 13
                font.bold: true
            }
        }

        // RESUME pill, so a live session is obvious at a glance
        Rectangle {
            visible: card.running
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            width: resumeRow.width + 18
            height: 24
            radius: 12
            color: "#D0080a10"
            border.color: Theme.ok
            border.width: 1

            Row {
                id: resumeRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.ok
                }

                Text {
                    text: qsTr("RESUME")
                    color: Theme.ok
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }
    }

    // Sits inside the focus border so it never covers it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: card.highlighted ? 2 : 1
        radius: Theme.cardRadius
        color: "transparent"
        border.color: Theme.bg
        border.width: 3
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Explicit signal parameter: the injected `mouse` variable is
        // deprecated in Qt 6 and qmllint flags it.
        onClicked: function(mouse) {
            card.forceActiveFocus()
            if (mouse.button === Qt.RightButton) {
                card.optionsRequested()
            }
            else {
                card.activated()
            }
        }
    }

    Keys.onReturnPressed: card.activated()
    Keys.onEnterPressed: card.activated()
    Keys.onMenuPressed: card.optionsRequested()
}
