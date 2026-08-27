import QtQuick 2.9

// A "Continue" card for the library hero row. Landscape and large, because
// these are about picking one thing up again rather than browsing a shelf.
// Geometry and type follow the home/library mockup.
Item {
    id: card

    property string appName: ""
    property url boxart: ""
    property bool running: false
    property double lastPlayed: 0
    property bool highlighted: activeFocus
    property string actionText: qsTr("Play")

    signal activated()
    signal optionsRequested()

    width: 396
    height: 206
    activeFocusOnTab: true

    // Focus glow. QML has no box-shadow, so this is a soft accent wash bled
    // outside the card bounds; it reads the same at a glance and costs nothing.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: Theme.cardRadius + 6
        color: "transparent"
        border.color: Theme.accent
        border.width: 6
        opacity: card.highlighted ? 0.18 : 0
        Behavior on opacity { NumberAnimation { duration: 110 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.panel
        border.color: card.highlighted ? Theme.accent : Theme.line
        border.width: card.highlighted ? 2 : 1
        clip: true

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
                // The placeholder dimensions the capsule grid also keys off:
                // GFE 2.0, GFE 3.0, and our own no_app_image.png.
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
            color: Theme.panel
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.monogramTop(card.appName) }
                GradientStop { position: 1.0; color: Theme.monogramBottom(card.appName) }
            }
        }

        // Host artwork is often a bright logo on a light plate with the game
        // name already printed on it. A flat knock-back keeps our own title
        // readable and stops the two sets of text competing.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "#59080a10"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 110
            color: Theme.bg
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
            anchors.margins: 16
            spacing: 6

            Text {
                width: parent.width
                text: card.appName.toUpperCase()
                color: Theme.textColor
                font.family: Theme.fontDisplay
                font.pixelSize: card.highlighted ? 24 : 20
                font.weight: Font.Bold
                font.letterSpacing: 0.9
                elide: Text.ElideRight

                Behavior on font.pixelSize { NumberAnimation { duration: 110 } }
            }

            // Focused card spells out what A does; the others just say when
            // they were last played.
            Row {
                spacing: 8
                visible: card.highlighted

                Rectangle {
                    width: 20; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: Theme.bg
                        font.family: Theme.fontBody
                        font.pixelSize: 11
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.running ? qsTr("Resume stream") : card.actionText
                    color: "#cdd5f5"
                    font.family: Theme.fontBody
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                }
            }

            Text {
                visible: !card.highlighted
                text: card.running ? qsTr("Running now")
                                   : Theme.relativeTime(card.lastPlayed)
                color: card.running ? Theme.ok : Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        // RUNNING pill, so a live session is obvious at a glance
        Rectangle {
            visible: card.running
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            width: resumeRow.width + 22
            height: 26
            radius: 13
            color: "#B8080a10"
            border.color: Qt.rgba(0.36, 0.84, 0.55, 0.5)
            border.width: 1

            Row {
                id: resumeRow
                anchors.centerIn: parent
                spacing: 7

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.ok
                }

                Text {
                    text: qsTr("RUNNING")
                    color: "#7fe3a8"
                    font.family: Theme.fontBody
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.7
                }
            }
        }
    }

    // Rectangle.clip is a bounding-box clip, so a rounded Rectangle does not
    // round its children. Painting a ring in the page background colour over
    // the corners restores the radius without pulling in a graphical-effects
    // module purely for a mask. Inset so it never covers the focus border.
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
