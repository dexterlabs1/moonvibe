import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2
import QtQuick.Layouts 1.3

import AppModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0

// The library: a "Continue" hero row of recently played apps above the full
// capsule grid. See docs/PRODUCT.md 3.2 screen 1.
FocusScope {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames

    // Entries from AppModel::getRecentApps(), newest first
    property var recentApps: []

    id: root
    focus: true

    property var navHints: [
        { b: "A", t: qsTr("Play") },
        { b: "X", t: qsTr("App options") },
        { b: "B", t: qsTr("Back") }
    ]

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

    function refreshRecents()
    {
        root.recentApps = appModel.getRecentApps(6)
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
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        appGrid.currentIndex = -1
        refreshRecents()
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true
        refreshRecents()

        // Highlight the first item if a gamepad is connected
        if (appGrid.currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            appGrid.currentIndex = 0
        }

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = appModel.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                // Start the direct launch app if nothing else is running
                appGrid.currentIndex = directLaunchAppIndex
                appGrid.currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
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

        ColumnLayout {
            id: heroSection

            visible: root.recentApps.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 18
            spacing: 10

            Text {
                text: qsTr("Continue")
                color: Theme.textColor
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 2
            }

            ListView {
                id: heroRow

                Layout.fillWidth: true
                Layout.preferredHeight: 166
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

                Keys.onReturnPressed: {
                    if (currentItem) {
                        currentItem.activated()
                    }
                }

                Keys.onEnterPressed: {
                    if (currentItem) {
                        currentItem.activated()
                    }
                }
            }
        }

        CenteredGridView {
            id: appGrid

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            activeFocusOnTab: true
            topMargin: 24
            bottomMargin: 5
            cellWidth: 230; cellHeight: 307;
            model: appModel

            // Leaving the top row of the grid goes up into the Continue row
            // rather than dead-ending, which is the whole point of having it.
            Keys.onUpPressed: {
                // currentIndex is -1 until something is selected (no gamepad
                // attached), and that state has to reach the hero row too --
                // requiring >= 0 here made Up a no-op on a freshly opened
                // library, which is exactly when it is most likely pressed.
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
                width: 220; height: 297;
                grid: appGrid

                property alias appContextMenu: appContextMenuLoader.item
                property alias appNameText: appNameTextLoader.item

                // Dim the app if it's hidden
                opacity: model.hidden ? 0.4 : 1.0

                background: Rectangle {
                    radius: Theme.cardRadius
                    color: highlighted ? Theme.panelHi : Theme.panel
                    border.color: highlighted ? Theme.accent : Theme.line
                    border.width: highlighted ? 2 : 1
                }

                Image {
                    property bool isPlaceholder: false

                    id: appIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    visible: !isPlaceholder
                    source: model.boxart

                    onSourceSizeChanged: {
                        // Nearly all of Nvidia's official box art does not match the dimensions of placeholder
                        // images, however the one known exception is Overcooked. Therefore, we only execute
                        // the image size checks if this is not an app collector game. We know the officially
                        // supported games all have box art, so this check is not required.
                        if (!model.isAppCollectorGame &&
                            ((sourceSize.width === 130 && sourceSize.height === 180) || // GFE 2.0 placeholder image
                             (sourceSize.width === 628 && sourceSize.height === 888) || // GFE 3.0 placeholder image
                             (sourceSize.width === 200 && sourceSize.height === 266)))  // Our no_app_image.png
                        {
                            isPlaceholder = true
                        }
                        else
                        {
                            isPlaceholder = false
                        }

                        width = 200
                        height = 267
                    }

                    // Display a tooltip with the full name if it's truncated
                    ToolTip.text: model.name
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: (parent.hovered || parent.highlighted) && (!appNameText || appNameText.truncated)
                }

                Loader {
                    active: model.running
                    asynchronous: true
                    anchors.fill: appIcon

                    sourceComponent: Item {
                        RoundButton {
                            // Don't steal focus from the toolbar buttons
                            focusPolicy: Qt.NoFocus

                            anchors.horizontalCenterOffset: appIcon.isPlaceholder ? -47 : 0
                            anchors.verticalCenterOffset: appIcon.isPlaceholder ? -75 : -60
                            anchors.centerIn: parent
                            implicitWidth: 85
                            implicitHeight: 85

                            icon.source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                            icon.width: 75
                            icon.height: 75

                            onClicked: {
                                launchOrResumeSelectedApp(true)
                            }

                            ToolTip.text: qsTr("Resume Game")
                            ToolTip.delay: 1000
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered

                            Material.background: "#D0808080"
                        }

                        RoundButton {
                            // Don't steal focus from the toolbar buttons
                            focusPolicy: Qt.NoFocus

                            anchors.horizontalCenterOffset: appIcon.isPlaceholder ? 47 : 0
                            anchors.verticalCenterOffset: appIcon.isPlaceholder ? -75 : 60
                            anchors.centerIn: parent
                            implicitWidth: 85
                            implicitHeight: 85

                            icon.source: "qrc:/res/stop_FILL1_wght700_GRAD200_opsz48.svg"
                            icon.width: 75
                            icon.height: 75

                            onClicked: {
                                doQuitGame()
                            }

                            ToolTip.text: qsTr("Quit Game")
                            ToolTip.delay: 1000
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered

                            Material.background: "#D0808080"
                        }
                    }
                }

                // Monogram tile shown when the host serves no real box art
                Loader {
                    id: appNameTextLoader
                    active: appIcon.isPlaceholder

                    // This loader is not asynchronous to avoid noticeable differences
                    // in the time in which the text loads for each game.

                    anchors.fill: appIcon

                    sourceComponent: Rectangle {
                        property bool truncated: nameLabel.truncated

                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.monogramTop(model.name) }
                            GradientStop { position: 1.0; color: Theme.monogramBottom(model.name) }
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -20
                            text: Theme.initialsFor(model.name)
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: 46
                            font.bold: true
                        }

                        Label {
                            id: nameLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 12
                            text: model.name
                            color: Theme.textColor
                            font.pointSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                // Running badge
                Rectangle {
                    visible: model.running
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: 16
                    anchors.leftMargin: 16
                    width: runningRow.width + 18
                    height: 24
                    radius: 12
                    color: "#D0080a10"
                    border.color: Theme.ok
                    border.width: 1

                    Row {
                        id: runningRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.ok
                        }

                        Text {
                            text: qsTr("RUNNING")
                            color: Theme.ok
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

                function launchOrResumeSelectedApp(quitExistingApp)
                {
                    root.launchApp(index, model.name, model.appid, quitExistingApp)
                }

                onClicked: {
                    // Only allow clicking on the box art for non-running games.
                    // For running games, buttons will appear to resume or quit which
                    // will handle starting the game and clicks on the box art will
                    // be ignored.
                    if (!model.running) {
                        launchOrResumeSelectedApp(true)
                    }
                }

                onPressAndHold: {
                    // popup() ensures the menu appears under the mouse cursor
                    if (appContextMenu.popup) {
                        appContextMenu.popup()
                    }
                    else {
                        // Qt 5.9 doesn't have popup()
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
                    // Open the app context menu if activated via the gamepad or keyboard
                    // for running games. If the game isn't running, the above onClicked
                    // method will handle the launch.
                    if (model.running) {
                        // This will be keyboard/gamepad driven so use
                        // open() instead of popup()
                        appContextMenu.open()
                    }
                }

                Keys.onEnterPressed: {
                    // Open the app context menu if activated via the gamepad or keyboard
                    // for running games. If the game isn't running, the above onClicked
                    // method will handle the launch.
                    if (model.running) {
                        // This will be keyboard/gamepad driven so use
                        // open() instead of popup()
                        appContextMenu.open()
                    }
                }

                Keys.onMenuPressed: {
                    // This will be keyboard/gamepad driven so use open() instead of popup()
                    appContextMenu.open()
                }

                function doQuitGame() {
                    quitAppDialog.appName = appModel.getRunningAppName()
                    quitAppDialog.segueToStream = false
                    quitAppDialog.open()
                }

                Loader {
                    id: appContextMenuLoader
                    asynchronous: true
                    sourceComponent: NavigableMenu {
                        id: appContextMenu
                        initiator: appContextMenuLoader.parent
                        NavigableMenuItem {
                            text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                            onTriggered: launchOrResumeSelectedApp(true)
                        }
                        NavigableMenuItem {
                            text: qsTr("Quit Game")
                            onTriggered: doQuitGame()
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

            ScrollBar.vertical: ScrollBar {}
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
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
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
