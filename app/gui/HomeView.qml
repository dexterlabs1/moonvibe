import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import HomeModel 1.0
import ComputerModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

// The home screen, and deliberately not a host list.
//
// A PC is a property of a game here, not a place you navigate to first. Whatever
// stands between you and playing -- a sleeping machine, an unpaired one -- is
// absorbed into the primary action rather than being its own screen: the button
// changes its words, and once the obstacle clears the launch continues on its
// own.
FocusScope {
    id: root
    focus: true
    objectName: qsTr("Home")

    property HomeModel homeModel: createHomeModel()
    property ComputerModel computerModel: createComputerModel()

    property var entries: []
    readonly property var primary: entries.length > 0 ? entries[0] : null
    readonly property var shelf: entries.length > 1 ? entries.slice(1) : []

    // Set when the user asked to play something that was not ready yet, so the
    // launch can continue once the host wakes or finishes pairing.
    property int pendingComputerIndex: -1
    property int pendingAppId: 0
    property string pendingReason: ""

    property var navHints: primary
        ? [ { b: "A", t: primaryActionShort },
            { b: "Y", t: qsTr("Another PC") },
            { b: "X", t: qsTr("Settings") },
            { b: "B", t: qsTr("Quit") } ]
        : [ { b: "A", t: qsTr("Set up") },
            { b: "X", t: qsTr("Settings") },
            { b: "B", t: qsTr("Quit") } ]

    readonly property string hostState: primary ? primary.hostState : "checking"

    readonly property string primaryAction:
          !primary ? qsTr("SET UP A PC")
        : hostState === "checking" ? qsTr("CHECKING…")
        : hostState === "asleep" ? qsTr("WAKE %1 & PLAY").arg(primary.hostName.toUpperCase())
        : hostState === "offline" ? qsTr("%1 IS UNREACHABLE").arg(primary.hostName.toUpperCase())
        : hostState === "unpaired" ? qsTr("PAIR & PLAY")
        : primary.running ? qsTr("RESUME STREAM")
        : qsTr("PLAY")

    readonly property string primaryActionShort:
          hostState === "asleep" ? qsTr("Wake & play")
        : hostState === "unpaired" ? qsTr("Pair & play")
        : primary && primary.running ? qsTr("Resume")
        : qsTr("Play")

    readonly property bool primaryEnabled:
        primary !== null && hostState !== "checking" && hostState !== "offline"

    function createHomeModel() {
        var m = Qt.createQmlObject('import HomeModel 1.0; HomeModel {}', root, '')
        m.initialize(ComputerManager)
        return m
    }

    function createComputerModel() {
        var m = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', root, '')
        m.initialize(ComputerManager)
        m.pairingCompleted.connect(pairingComplete)
        return m
    }

    function refresh() {
        entries = homeModel.recents(7)

        // Continue a launch that was waiting on the host.
        if (pendingAppId !== 0) {
            for (var i = 0; i < entries.length; i++) {
                var e = entries[i]
                if (e.computerIndex === pendingComputerIndex && e.appId === pendingAppId) {
                    if (e.hostState === "ready") {
                        var appId = pendingAppId
                        var idx = pendingComputerIndex
                        clearPending()
                        launch(idx, appId, e.appName, e.running)
                    }
                    return
                }
            }
        }
    }

    function clearPending() {
        pendingComputerIndex = -1
        pendingAppId = 0
        pendingReason = ""
    }

    function launch(computerIndex, appId, appName, isResume) {
        var session = homeModel.createSessionFor(computerIndex, appId)
        if (session === null) {
            return
        }

        var component = Qt.createComponent("StreamSegue.qml")
        stackView.push(component.createObject(stackView, {
                                                  "appName": appName,
                                                  "session": session,
                                                  "isResume": isResume
                                              }))
    }

    // One entry point for "play this", whatever state its host is in.
    function activate(entry) {
        if (!entry) {
            return
        }

        if (entry.hostState === "ready") {
            launch(entry.computerIndex, entry.appId, entry.appName, entry.running)
        }
        else if (entry.hostState === "asleep") {
            pendingComputerIndex = entry.computerIndex
            pendingAppId = entry.appId
            pendingReason = qsTr("Waking %1…").arg(entry.hostName)
            computerModel.wakeComputer(entry.computerIndex)
        }
        else if (entry.hostState === "unpaired") {
            pendingComputerIndex = entry.computerIndex
            pendingAppId = entry.appId
            pendingReason = qsTr("Pairing with %1…").arg(entry.hostName)

            var pin = computerModel.generatePinString()
            computerModel.pairComputer(entry.computerIndex, pin)
            pairDialog.pin = pin
            pairDialog.hostName = entry.hostName
            pairDialog.webUiUrl = computerModel.getHostWebUiUrl(entry.computerIndex)
            pairDialog.open()
        }
    }

    function pairingComplete(error) {
        pairDialog.close()

        if (error !== undefined) {
            clearPending()
            errorDialog.text = error
            errorDialog.open()
        }
        // On success the host's state change triggers refresh(), which
        // continues the pending launch.
    }

    Component.onCompleted: refresh()
    StackView.onActivated: refresh()

    Connections {
        target: homeModel
        function onHomeChanged() { root.refresh() }
    }

    Keys.onReturnPressed: if (primaryEnabled) activate(primary)
    Keys.onEnterPressed: if (primaryEnabled) activate(primary)

    Keys.onPressed: {
        // Y opens the PC list, which is now a secondary screen rather than the
        // way in. SdlGamepadKeyNavigation maps Y to Hangup.
        if (event.key === Qt.Key_Hangup || event.key === Qt.Key_F1) {
            stackView.push("qrc:/gui/PcView.qml")
            event.accepted = true
        }
    }

    // ---- Artwork bleeding in from the right ----
    Item {
        anchors.fill: parent
        clip: true
        visible: root.primary !== null

        Image {
            id: heroArt
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width * 0.56
            height: parent.height * 0.94
            source: root.primary ? root.primary.boxart : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.85
        }

        Rectangle {
            anchors.fill: heroArt
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0044507f" }
                GradientStop { position: 1.0; color: "#00080a10" }
            }
        }

        // Fade the art into the page from the left and the bottom, so the
        // headline never sits on top of busy pixels.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                // Fully opaque past the artwork's left edge (it starts at
                // 44%), then a long fade, so the image has no visible seam.
                GradientStop { position: 0.0; color: Theme.bg }
                GradientStop { position: 0.46; color: Theme.bg }
                GradientStop { position: 0.72; color: Qt.rgba(0.051, 0.055, 0.082, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.58
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.62; color: Theme.bg }
                GradientStop { position: 1.0; color: Theme.bg }
            }
        }
    }

    // ---- The one decision ----
    Column {
        id: hero
        visible: root.primary !== null
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 56
        anchors.topMargin: 44
        width: Math.min(660, parent.width - 112)
        spacing: 0

        Text {
            text: root.pendingReason ? root.pendingReason.toUpperCase()
                : root.primary && root.primary.running ? qsTr("STILL RUNNING")
                : qsTr("CONTINUE WHERE YOU LEFT OFF")
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 2.2
        }

        Text {
            width: parent.width
            topPadding: 14
            text: root.primary ? root.primary.appName.toUpperCase() : ""
            color: Theme.textColor
            font.family: Theme.fontDisplay
            font.pixelSize: 58
            font.weight: Font.Bold
            lineHeight: 1.02
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Item { width: 1; height: 18 }

        Row {
            spacing: 10

            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: root.hostState === "ready" ? Theme.ok
                     : root.hostState === "unpaired" ? Theme.warn
                     : Theme.textFaint
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.primary ? ""
                    : root.hostState === "checking" ? qsTr("Checking whether %1 is awake").arg(root.primary.hostName)
                    : root.hostState === "asleep" ? qsTr("%1 is asleep · waking takes about 20 seconds").arg(root.primary.hostName)
                    : root.hostState === "offline" ? qsTr("%1 is not reachable on this network").arg(root.primary.hostName)
                    : root.hostState === "unpaired" ? qsTr("%1 needs pairing · a PIN appears on both screens").arg(root.primary.hostName)
                    : root.primary.running ? qsTr("Running on %1").arg(root.primary.hostName)
                    : qsTr("On %1 · %2").arg(root.primary.hostName).arg(Theme.relativeTime(root.primary.lastPlayed))
                color: root.hostState === "ready" && root.primary && root.primary.running ? Theme.ok
                     : root.hostState === "unpaired" ? Theme.warn
                     : Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }

        // The primary action. Its words carry whatever the host needs.
        Item { width: 1; height: 34 }

        Rectangle {
            id: primaryButton

            width: primaryRow.width + 52
            height: 58
            radius: 14
            color: root.primaryEnabled ? Theme.accent : Theme.panelHi
            opacity: root.pendingReason ? 0.75 : 1.0

            Row {
                id: primaryRow
                anchors.centerIn: parent
                spacing: 13

                Rectangle {
                    width: 26; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.primaryEnabled ? Theme.bg : Theme.line
                    visible: !root.pendingReason

                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: Theme.textColor
                        font.family: Theme.fontBody
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                    }
                }

                BusyIndicator {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.pendingReason !== ""
                    running: visible
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pendingReason ? root.pendingReason : root.primaryAction
                    color: root.primaryEnabled ? Theme.bg : Theme.textMuted
                    font.family: Theme.fontBody
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.5
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: if (root.primaryEnabled) root.activate(root.primary)
            }
        }
    }

    // ---- First run: no host, or nothing played yet ----
    Column {
        visible: root.primary === null
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 112)
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: homeModel.hasHosts() ? qsTr("PICK SOMETHING TO PLAY") : qsTr("LET'S FIND YOUR PC")
            color: Theme.textColor
            font.family: Theme.fontDisplay
            font.pixelSize: 38
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: homeModel.hasHosts()
                  ? qsTr("Once you have played something it appears here, ready to pick straight back up.")
                  : qsTr("Make sure Sunshine, Apollo or Vibepollo is running on your PC and it will turn up on its own.")
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: setupRow.width + 46
            height: 52
            radius: 13
            color: Theme.accent

            Row {
                id: setupRow
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    width: 24; height: 24; radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bg

                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: Theme.textColor
                        font.family: Theme.fontBody
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: homeModel.hasHosts() ? qsTr("OPEN YOUR LIBRARY") : qsTr("FIND MY PC")
                    color: Theme.bg
                    font.family: Theme.fontBody
                    font.pixelSize: 15
                    font.weight: Font.ExtraBold
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: stackView.push("qrc:/gui/PcView.qml")
            }
        }
    }

    // ---- The library, as a shelf rather than a second screen ----
    Column {
        id: shelfSection
        visible: root.primary !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56
        anchors.rightMargin: 28
        anchors.bottomMargin: 22
        spacing: 12

        Text {
            text: qsTr("YOUR LIBRARY")
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 2.2
        }

        ListView {
            id: shelfRow

            width: parent.width
            height: 174
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            model: root.shelf
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true

            footer: Item {
                width: 132
                height: 174

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    width: 118
                    height: 174
                    radius: Theme.capsuleRadius
                    color: "transparent"
                    border.color: Theme.lineHi
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("ALL\nGAMES")
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textFaint
                        font.family: Theme.fontBody
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1.2
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openLibrary()
                    }
                }
            }

            delegate: Item {
                width: 118
                height: 174

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Theme.capsuleRadius + 4
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 4
                    opacity: shelfRow.activeFocus && shelfRow.currentIndex === index ? 0.2 : 0
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius
                    color: Theme.pill
                    border.color: shelfRow.activeFocus && shelfRow.currentIndex === index
                                  ? Theme.accent : Theme.line
                    border.width: shelfRow.activeFocus && shelfRow.currentIndex === index ? 2 : 1
                    clip: true

                    Image {
                        id: shelfArt
                        anchors.fill: parent
                        anchors.margins: 1
                        source: modelData.boxart
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        height: shelfTitle.height + 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#00080a0e" }
                            GradientStop { position: 1.0; color: "#F0080a0e" }
                        }

                        Text {
                            id: shelfTitle
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: modelData.appName.toUpperCase()
                            color: Theme.textColor
                            font.family: Theme.fontBody
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // A second PC only earns a mention when there is one.
                    Rectangle {
                        visible: root.primary && modelData.hostName !== root.primary.hostName
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 7
                        height: 18
                        width: hostTag.width + 14
                        radius: 9
                        color: "#C0080a10"

                        Text {
                            id: hostTag
                            anchors.centerIn: parent
                            text: modelData.hostName.toUpperCase()
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pixelSize: 8
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 0.5
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        shelfRow.currentIndex = index
                        root.activate(modelData)
                    }
                }
            }

            Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < root.shelf.length) root.activate(root.shelf[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0 && currentIndex < root.shelf.length) root.activate(root.shelf[currentIndex])

            Keys.onUpPressed: {
                root.forceActiveFocus()
                event.accepted = true
            }
        }
    }

    function openLibrary() {
        if (!primary) {
            return
        }
        var component = Qt.createComponent("AppView.qml")
        stackView.push(component.createObject(stackView, {
                                                  "computerIndex": primary.computerIndex,
                                                  "objectName": primary.hostName
                                              }))
    }

    Keys.onDownPressed: {
        if (shelfSection.visible && root.shelf.length > 0) {
            shelfRow.forceActiveFocus()
            event.accepted = true
        }
    }

    PairingDialog {
        id: pairDialog
        onRejected: root.clearPending()
    }

    ErrorMessageDialog {
        id: errorDialog
        onClosed: root.clearPending()
    }
}
