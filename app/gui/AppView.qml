import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3

import AppModel 1.0
import ComputerManager 1.0
import ComputerModel 1.0
import StreamingPreferences 1.0
import SdlGamepadKeyNavigation 1.0

// The library: a "Continue" hero row of recently played apps above the capsule
// grid. Geometry, type and section headers follow the home/library mockup.
FocusScope {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames

    // Entries from AppModel::getRecentApps(), newest first
    property var recentApps: []

    // The header's host pill claims to show whether this machine is reachable.
    // AppModel knows nothing about it, and ComputerModel's roles are the only
    // place the state is exposed to QML, so the view republishes its own host's
    // for main.qml to bind to.
    property ComputerModel hostModel: createHostModel()
    property bool hostOnline: false
    property bool hostStatusUnknown: false

    id: root
    focus: true

    // The footer is the primary affordance, so it describes the item that
    // actually has focus rather than the grid's usual case.
    property var navHints: {
        var hints = []
        var heroFocused = heroSection.visible && heroRow.activeFocus
        var item = heroFocused ? heroRow.currentItem : appGrid.currentItem

        hints.push({ b: "A", t: item && item.running ? qsTr("Resume") : qsTr("Play") })

        // X on the Continue row only moves focus down into the grid; it opens
        // nothing, so it doesn't claim to.
        if (!heroFocused) {
            hints.push({ b: "X", t: qsTr("App options") })
        }

        hints.push({ b: "B", t: qsTr("Back") })
        return hints
    }

    function computerLost()
    {
        // Go back to the PC view on PC loss
        stackView.pop()
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', parent, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    function createHostModel()
    {
        // initialize() must run before anything reads the model, which rules
        // out declaring it inline and initializing in Component.onCompleted.
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        return model
    }

    function refreshRecents()
    {
        root.recentApps = appModel.getRecentApps(3)
    }

    // Shared by the hero row and the capsule grid so both behave identically
    // when something else is already running on the host.
    function launchApp(index, appName, appId, quitExistingApp)
    {
        var runningId = appModel.getRunningAppId()
        if (runningId !== 0 && runningId !== appId) {
            if (quitExistingApp) {
                quitAppDialog.appName = appModel.getRunningAppName()
                quitAppDialog.segueToStream = true
                quitAppDialog.nextAppName = appName
                quitAppDialog.nextAppIndex = index
                quitAppDialog.open()
            }

            return
        }

        var component = Qt.createComponent("StreamSegue.qml")
        var segue = component.createObject(stackView, {
                                               "appName": appName,
                                               "session": appModel.createSessionForApp(index),
                                               "isResume": runningId === appId
                                           })
        stackView.push(segue)
    }

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        appGrid.currentIndex = -1
        refreshRecents()
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true
        refreshRecents()

        if (appGrid.currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            appGrid.currentIndex = 0
        }

        if (!showGames && !showHiddenGames) {
            var directLaunchAppIndex = appModel.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                appGrid.currentIndex = directLaunchAppIndex
                appGrid.currentItem.launchOrResumeSelectedApp(false)
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    // A model role can only be read from inside a delegate, so this is the
    // delegate: nothing to look at, just the two bindings the header pill needs.
    Repeater {
        model: root.hostModel

        delegate: Item {
            visible: false

            Binding {
                target: root
                property: "hostOnline"
                value: model.online
                when: index === root.computerIndex
            }

            Binding {
                target: root
                property: "hostStatusUnknown"
                value: model.statusUnknown
                when: index === root.computerIndex
            }
        }
    }

    Component.onDestruction: {
        if (hostModel) {
            hostModel.destroy()
        }
    }

    // The recents list is derived data, so it has to be rebuilt whenever the
    // underlying app list or the running app changes.
    Connections {
        target: appModel
        function onRecentAppsChanged() { root.refreshRecents() }
        function onDataChanged() { root.refreshRecents() }
        function onRowsInserted() { root.refreshRecents() }
        function onRowsRemoved() { root.refreshRecents() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Continue ----
        ColumnLayout {
            id: heroSection

            visible: root.recentApps.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 6
            spacing: 10

            Text {
                text: qsTr("CONTINUE")
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.ExtraBold
                font.letterSpacing: 1.9
            }

            ListView {
                id: heroRow

                Layout.fillWidth: true
                Layout.preferredHeight: 206
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                model: root.recentApps
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true
                highlightMoveDuration: 120

                delegate: HeroCard {
                    appName: modelData.name
                    boxart: modelData.boxart
                    running: modelData.running
                    lastPlayed: modelData.lastPlayed
                    highlighted: heroRow.activeFocus && heroRow.currentIndex === index

                    onActivated: {
                        heroRow.currentIndex = index
                        root.launchApp(modelData.index, modelData.name, modelData.appid, true)
                    }

                    onOptionsRequested: {
                        // Options live on the capsule; jump there rather than
                        // maintaining a second context menu.
                        appGrid.currentIndex = modelData.index
                        appGrid.positionViewAtIndex(modelData.index, GridView.Contain)
                        appGrid.forceActiveFocus()
                    }
                }

                Keys.onDownPressed: {
                    if (appGrid.count > 0) {
                        if (appGrid.currentIndex === -1) {
                            appGrid.currentIndex = 0
                        }
                        appGrid.forceActiveFocus()
                    }
                }

                Keys.onReturnPressed: { if (currentItem) currentItem.activated() }
                Keys.onEnterPressed: { if (currentItem) currentItem.activated() }
            }
        }

        // ---- All games ----
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 18
            Layout.bottomMargin: 10
            spacing: 12

            Text {
                text: qsTr("ALL GAMES")
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.ExtraBold
                font.letterSpacing: 1.9
            }

            Text {
                text: appGrid.count
                color: Theme.textFaint
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            // Where the artwork is coming from. Quietly answers "why does this
            // look different from Steam" without a settings trip.
            Rectangle {
                visible: StreamingPreferences.steamGridDbApiKey !== ""
                implicitHeight: 24
                implicitWidth: artChipText.width + 20
                radius: 12
                color: Theme.bgRaised
                border.color: Theme.lineHi
                border.width: 1

                Text {
                    id: artChipText
                    anchors.centerIn: parent
                    text: qsTr("Art: SteamGridDB")
                    color: "#b8bdd4"
                    font.family: Theme.fontBody
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
        }

        CenteredGridView {
            id: appGrid

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 28 - minMargin
            Layout.rightMargin: 28 - minMargin

            focus: true
            activeFocusOnTab: true
            topMargin: 0
            bottomMargin: 8
            // capsule + the mockup's 16px gutter
            cellWidth: Theme.capsuleWidth + 16
            cellHeight: Theme.capsuleHeight + 16
            model: appModel

            // Leaving the top row of the grid goes up into the Continue row
            // rather than dead-ending, which is the whole point of having it.
            Keys.onUpPressed: {
                // currentIndex is -1 until something is selected (no gamepad
                // attached), and that state has to reach the hero row too.
                if (heroSection.visible && currentIndex < itemsPerRow) {
                    if (heroRow.currentIndex < 0) {
                        heroRow.currentIndex = 0
                    }
                    heroRow.forceActiveFocus()
                    event.accepted = true
                }
                else {
                    event.accepted = false
                }
            }

            delegate: NavigableItemDelegate {
                id: capsule

                width: Theme.capsuleWidth
                height: Theme.capsuleHeight
                padding: 0
                grid: appGrid

                property alias appContextMenu: appContextMenuLoader.item

                // Named to match HeroCard's, so the footer can ask either one.
                readonly property bool running: model.running

                // Dim the app if it's hidden
                opacity: model.hidden ? 0.4 : 1.0

                // No card chrome: in the mockup the artwork *is* the tile.
                background: Item {}

                // Focus glow, matching the hero cards.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: Theme.capsuleRadius + 5
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 5
                    opacity: capsule.highlighted ? 0.18 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius
                    color: Theme.pill
                    border.color: capsule.highlighted ? Theme.accent : Theme.line
                    border.width: capsule.highlighted ? 2 : 1
                    clip: true

                    Image {
                        property bool isPlaceholder: false

                        id: appIcon
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: !isPlaceholder && status === Image.Ready
                        source: model.boxart
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true

                        onSourceSizeChanged: {
                            // Nearly all of Nvidia's official box art does not match the dimensions of
                            // placeholder images, however the one known exception is Overcooked. So the
                            // size checks only run when this is not an app collector game.
                            isPlaceholder = !model.isAppCollectorGame &&
                                    ((sourceSize.width === 130 && sourceSize.height === 180) ||
                                     (sourceSize.width === 628 && sourceSize.height === 888) ||
                                     (sourceSize.width === 200 && sourceSize.height === 266))
                        }
                    }

                    // Monogram tile shown when the host serves no real box art
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: appIcon.isPlaceholder || appIcon.status !== Image.Ready
                        color: Theme.pill

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -14
                            text: Theme.initialsFor(model.name)
                            color: "#3a4060"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 44
                            font.weight: Font.Bold
                        }
                    }

                    // Title strip over a scrim, so the name is legible on any art
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        height: titleText.height + 18
                        color: Theme.bg
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#00080a0e" }
                            GradientStop { position: 1.0; color: "#EB080a0e" }
                        }

                        Text {
                            id: titleText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.bottomMargin: 8
                            text: model.name.toUpperCase()
                            color: Theme.textColor
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.letterSpacing: 0.25
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // Running badge
                    Rectangle {
                        visible: model.running
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        width: runningRow.width + 16
                        height: 22
                        radius: 11
                        color: "#B8080a10"
                        border.color: Qt.rgba(0.36, 0.84, 0.55, 0.5)
                        border.width: 1

                        Row {
                            id: runningRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.ok
                            }

                            Text {
                                text: qsTr("RUNNING")
                                color: "#7fe3a8"
                                font.family: Theme.fontBody
                                font.pixelSize: 9
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.6
                            }
                        }
                    }

                    // Resume / quit controls for a running app
                    Loader {
                        active: model.running
                        asynchronous: true
                        anchors.centerIn: parent

                        sourceComponent: Row {
                            spacing: 10

                            RoundButton {
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 54
                                implicitHeight: 54
                                icon.source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                                icon.width: 44
                                icon.height: 44
                                onClicked: capsule.launchOrResumeSelectedApp(true)
                                Material.background: "#D0808080"

                                ToolTip.text: qsTr("Resume Game")
                                ToolTip.delay: 1000
                                ToolTip.timeout: 3000
                                ToolTip.visible: hovered
                            }

                            RoundButton {
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 54
                                implicitHeight: 54
                                icon.source: "qrc:/res/stop_FILL1_wght700_GRAD200_opsz48.svg"
                                icon.width: 44
                                icon.height: 44
                                onClicked: capsule.doQuitGame()
                                Material.background: "#D0808080"

                                ToolTip.text: qsTr("Quit Game")
                                ToolTip.delay: 1000
                                ToolTip.timeout: 3000
                                ToolTip.visible: hovered
                            }
                        }
                    }
                }

                // Rectangle.clip is a bounding-box clip and does not round its
                // children, so paint a ring in the page background colour over
                // the corners. Inset so the focus border stays visible.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: capsule.highlighted ? 2 : 1
                    radius: Theme.capsuleRadius
                    color: "transparent"
                    border.color: Theme.bg
                    border.width: 3
                }

                function launchOrResumeSelectedApp(quitExistingApp)
                {
                    root.launchApp(index, model.name, model.appid, quitExistingApp)
                }

                function doQuitGame() {
                    quitAppDialog.appName = appModel.getRunningAppName()
                    quitAppDialog.segueToStream = false
                    quitAppDialog.open()
                }

                onClicked: {
                    // Only allow clicking on the box art for non-running games.
                    // For running games the resume/quit buttons handle it.
                    if (!model.running) {
                        launchOrResumeSelectedApp(true)
                    }
                }

                onPressAndHold: {
                    if (appContextMenu.popup) {
                        appContextMenu.popup()
                    }
                    else {
                        appContextMenu.open()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton;
                    onClicked: {
                        parent.pressAndHold()
                    }
                }

                Keys.onReturnPressed: {
                    // For running games open the menu; otherwise onClicked launches.
                    if (model.running) {
                        appContextMenu.open()
                    }
                }

                Keys.onEnterPressed: {
                    if (model.running) {
                        appContextMenu.open()
                    }
                }

                Keys.onMenuPressed: {
                    appContextMenu.open()
                }

                ToolTip.text: model.name
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: (hovered || highlighted) && titleText.truncated

                Loader {
                    id: appContextMenuLoader
                    asynchronous: true
                    sourceComponent: NavigableMenu {
                        id: appContextMenu
                        initiator: appContextMenuLoader.parent
                        NavigableMenuItem {
                            text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                            onTriggered: capsule.launchOrResumeSelectedApp(true)
                        }
                        NavigableMenuItem {
                            text: qsTr("Quit Game")
                            onTriggered: capsule.doQuitGame()
                            visible: model.running
                        }
                        NavigableMenuItem {
                            checkable: true
                            checked: model.directLaunch
                            text: qsTr("Direct Launch")
                            onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                            enabled: !model.hidden

                            ToolTip.text: qsTr("Launch this app immediately when the host is selected, bypassing the app selection grid.")
                            ToolTip.delay: 1000
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered
                        }
                        NavigableMenuItem {
                            checkable: true
                            checked: model.hidden
                            text: qsTr("Hide Game")
                            onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                            enabled: model.hidden || (!model.running && !model.directLaunch)

                            ToolTip.text: qsTr("Hide this game from the app grid. To access hidden games, right-click on the host and choose %1.").arg(qsTr("View All Apps"))
                            ToolTip.delay: 1000
                            ToolTip.timeout: 5000
                            ToolTip.visible: hovered
                        }
                    }
                }
            }

            ScrollBar.vertical: MvScrollBar {}
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: appGrid.count === 0

        Label {
            text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
            font.pointSize: 20
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text:qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }
}
