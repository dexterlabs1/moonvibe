import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

import SystemProperties 1.0

// Pairing step of the setup flow: the client generates the PIN, the host has to
// be told it. See docs/PRODUCT.md 3.2 screen 5.
//
// The stock dialog buried a four-digit code inside a paragraph of text. On a
// Deck held at arm's length while you walk to the host PC, the code is the only
// thing that matters, so it gets the whole dialog.
NavigableDialog {
    id: pairingDialog

    property string pin: "0000"
    property string hostName: ""

    // https://<host>:47990, or empty for GeForce Experience hosts (no web UI)
    property string webUiUrl: ""

    closePolicy: Popup.CloseOnEscape

    onOpened: {
        if (openWebUiButton.visible) {
            openWebUiButton.forceActiveFocus(Qt.TabFocus)
        }
        else {
            cancelButton.forceActiveFocus(Qt.TabFocus)
        }
    }

    ColumnLayout {
        spacing: 18

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: pairingDialog.hostName ? qsTr("Pair with %1").arg(pairingDialog.hostName)
                                         : qsTr("Pair with host")
            color: Theme.textColor
            font.pointSize: 15
            font.bold: true
        }

        // The PIN, one digit per tile. Big enough to read across a room.
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Repeater {
                model: pairingDialog.pin.length

                Rectangle {
                    width: 64
                    height: 84
                    radius: Theme.cardRadius
                    color: Theme.panelHi
                    border.color: Theme.accent
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: pairingDialog.pin.charAt(index)
                        color: Theme.textColor
                        font.pointSize: 34
                        font.bold: true
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 460
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.pointSize: 11
            text: pairingDialog.webUiUrl
                  ? qsTr("Enter this PIN in the host's web interface to finish pairing.")
                  : qsTr("Enter this PIN on the host PC to finish pairing.")
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: pairingDialog.webUiUrl !== ""
            text: pairingDialog.webUiUrl
            color: Theme.textFaint
            font.pointSize: 10
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            BusyIndicator {
                implicitWidth: 22
                implicitHeight: 22
                running: pairingDialog.opened
            }

            Label {
                text: qsTr("Waiting for the host…")
                color: Theme.textMuted
                font.pointSize: 11
            }
        }
    }

    footer: DialogButtonBox {
        alignment: Qt.AlignHCenter

        Button {
            id: openWebUiButton
            flat: true
            text: qsTr("Open host web UI")
            // No browser to open, or a GeForce Experience host with no web UI
            visible: SystemProperties.hasBrowser && pairingDialog.webUiUrl !== ""

            onClicked: Qt.openUrlExternally(pairingDialog.webUiUrl)

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }

        Button {
            id: cancelButton
            flat: true
            text: qsTr("Cancel")

            onClicked: pairingDialog.close()

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }
}
