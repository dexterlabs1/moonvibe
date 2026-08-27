import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property ComputerModel computerModel : createModel()

    id: pcGrid
    focus: true
    activeFocusOnTab: true
    topMargin: Theme.sp4
    bottomMargin: Theme.sp5

    // Host cards are the whole screen on a Deck, so they take the whole screen:
    // three across the 1280 frame, tall enough that a row of them fills the
    // space between the toolbar and the footer instead of hugging the top.
    cellWidth: 420; cellHeight: 540;
    objectName: qsTr("Hosts")

    property var navHints: [
        { b: "A", t: qsTr("Connect") },
        { b: "X", t: qsTr("Options") },
        { b: "Y", t: qsTr("Settings") },
        { b: "B", t: qsTr("Quit") }
    ]

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        // Setup signals on CM
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    Column {
        anchors.centerIn: parent
        spacing: 18
        visible: pcGrid.count === 0

        BusyIndicator {
            id: searchSpinner
            anchors.horizontalCenter: parent.horizontalCenter
            width: 42
            height: 42
            visible: StreamingPreferences.enableMdns
            running: visible
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: StreamingPreferences.enableMdns ? qsTr("Looking for hosts on your network…")
                                                  : qsTr("Automatic discovery is disabled. Add your host manually.")
            color: Theme.textColor
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsTitle
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Make sure Sunshine, Apollo, or Vibepollo is running on your PC")
            color: Theme.textFaint
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsBody
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    header: Item {
        width: pcGrid.width
        height: 40

        Row {
            anchors.left: parent.left
            anchors.leftMargin: pcGrid.horizontalMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: qsTr("YOUR PCS")
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.ExtraBold
                font.letterSpacing: 1.9
            }

            Text {
                text: pcGrid.count
                color: Theme.textFaint
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
            }
        }
    }

    model: computerModel

    delegate: NavigableItemDelegate {
        id: pcCard

        width: 400; height: 520;
        padding: 0
        grid: pcGrid

        property alias pcContextMenu : pcContextMenuLoader.item

        readonly property bool isBusy: model.statusUnknown
        readonly property bool needsPairing: model.online && !model.paired
        readonly property bool canWake: !model.online && !model.statusUnknown && model.wakeable

        // Drawn below, so no delegate chrome of its own.
        background: Item {}

        // Focus glow, matching the library capsules.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            radius: Theme.cardRadius + 5
            color: "transparent"
            border.color: Theme.accent
            border.width: 5
            opacity: pcCard.highlighted ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 110 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cardRadius
            color: Theme.panel
            border.color: pcCard.highlighted ? Theme.accent : Theme.line
            border.width: pcCard.highlighted ? 2 : 1
            clip: true

            // A wash of the status colour, so state reads before any text does.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: Theme.panel
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: pcCard.isBusy ? "#141726"
                             : !model.online ? "#12131d"
                             : pcCard.needsPairing ? "#241f14"
                             : "#12211a"
                    }
                    GradientStop { position: 1.0; color: Theme.panel }
                }
            }

            // Status chip
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.sp5
                height: 28
                width: statusRow.width + Theme.sp5
                radius: 14
                color: "#B8080a10"
                border.width: 1
                border.color: pcCard.isBusy ? Theme.lineHi
                            : !model.online ? Theme.lineHi
                            : pcCard.needsPairing ? Theme.warn
                            : Theme.ok

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: pcCard.isBusy ? Theme.textFaint
                             : !model.online ? Theme.textFaint
                             : pcCard.needsPairing ? Theme.warn
                             : Theme.ok
                    }

                    Text {
                        text: pcCard.isBusy ? qsTr("CHECKING")
                            : !model.online ? qsTr("OFFLINE")
                            : pcCard.needsPairing ? qsTr("NEEDS PAIRING")
                            : qsTr("READY")
                        color: pcCard.isBusy ? Theme.textMuted
                             : !model.online ? Theme.textMuted
                             : pcCard.needsPairing ? Theme.warn
                             : Theme.ok
                        font.family: Theme.fontBody
                        font.pixelSize: Theme.fsMicro
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 0.8
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.sp5
                spacing: Theme.sp3

                Text {
                    width: parent.width
                    text: model.name.toUpperCase()
                    color: Theme.textColor
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fsDisplay
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    elide: Text.ElideRight
                }

                // What this machine is actually doing, rather than a repeat of
                // the status chip.
                Text {
                    width: parent.width
                    text: model.runningApp ? qsTr("%1 is running").arg(model.runningApp)
                        : pcCard.needsPairing ? qsTr("Select to pair with this PC")
                        : pcCard.canWake ? qsTr("Asleep - press X to wake")
                        : !model.online ? qsTr("Not reachable on this network")
                        : pcCard.isBusy ? qsTr("Checking if it is awake")
                        : model.appCount > 0 ? qsTr("%1 games").arg(model.appCount)
                        : qsTr("Ready to stream")
                    color: model.runningApp ? Theme.ok
                         : pcCard.needsPairing ? Theme.warn
                         : Theme.textMuted
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: model.addressLabel
                          ? model.addressLabel + "  ·  " + model.serverLabel
                          : model.serverLabel
                    color: Theme.textFaint
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            BusyIndicator {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.sp5
                width: 28
                height: 28
                visible: pcCard.isBusy
                running: visible
            }
        }

        // Rectangle.clip does not round its children; paint a ring in the page
        // background colour over the corners. Inset to keep the focus border.
        Rectangle {
            anchors.fill: parent
            anchors.margins: pcCard.highlighted ? 2 : 1
            radius: Theme.cardRadius
            color: "transparent"
            border.color: Theme.bg
            border.width: 3
        }


        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                NavigableMenuItem {
                    text: qsTr("View All Apps")
                    onTriggered: {
                        var component = Qt.createComponent("AppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                        stackView.push(appView)
                    }
                    visible: model.online && model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Wake PC")
                    onTriggered: computerModel.wakeComputer(index)
                    visible: !model.online && model.wakeable
                }
                NavigableMenuItem {
                    text: qsTr("Test Network")
                    onTriggered: {
                        computerModel.testConnectionForComputer(index)
                        testConnectionDialog.open()
                    }
                }

                NavigableMenuItem {
                    text: qsTr("Rename PC")
                    onTriggered: {
                        renamePcDialog.pcIndex = index
                        renamePcDialog.originalName = model.name
                        renamePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Delete PC")
                    onTriggered: {
                        deletePcDialog.pcIndex = index
                        deletePcDialog.pcName = model.name
                        deletePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("View Details")
                    onTriggered: {
                        showPcDetailsDialog.pcDetails = model.details
                        showPcDetailsDialog.open()
                    }
                }
            }
        }

        onClicked: {
            if (model.online) {
                if (!model.serverSupported) {
                    errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                    errorDialog.helpText = ""
                    errorDialog.open()
                }
                else if (model.paired) {
                    // go to game view
                    var component = Qt.createComponent("AppView.qml")
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                    stackView.push(appView)
                }
                else {
                    var pin = computerModel.generatePinString()

                    // Kick off pairing in the background
                    computerModel.pairComputer(index, pin)

                    // Display the pairing dialog
                    pairDialog.pin = pin
                    pairDialog.hostName = model.name
                    pairDialog.webUiUrl = computerModel.getHostWebUiUrl(index)
                    pairDialog.open()
                }
            } else if (!model.online) {
                // Using open() here because it may be activated by keyboard
                pcContextMenu.open()
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (pcContextMenu.popup) {
                pcContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                pcContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onMenuPressed: {
            // We must use open() here so the menu is positioned on
            // the ItemDelegate and not where the mouse cursor is
            pcContextMenu.open()
        }

        Keys.onDeletePressed: {
            deletePcDialog.pcIndex = index
            deletePcDialog.pcName = model.name
            deletePcDialog.open()
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    PairingDialog {
        id: pairDialog
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    ScrollBar.vertical: MvScrollBar {}
}
