import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

ToolButton {
    id: control

    property string iconSource

    activeFocusOnTab: true

    icon.source: iconSource
    icon.width: Theme.iconSize
    icon.height: Theme.iconSize

    implicitWidth: Theme.controlHeight
    Layout.preferredHeight: parent.height

    // The Material background IS the ripple, and a ripple is a mouse idiom: it
    // answers a click that already happened. On a Deck the question is "where
    // am I", so the button draws focus and press instead, in Theme colours.
    background: Rectangle {
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: Theme.controlHeight
            height: Theme.controlHeight
            radius: Theme.capsuleRadius
            color: control.down ? Theme.panelHi
                 : control.activeFocus ? Theme.panel
                 : "transparent"
            border.width: control.activeFocus ? 2 : 0
            border.color: Theme.accent
        }
    }

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }
}
