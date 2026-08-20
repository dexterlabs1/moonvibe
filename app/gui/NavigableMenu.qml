import QtQuick 2.9
import QtQuick.Controls 2.5

// Every context menu in the app. Styled here rather than at the call sites, so
// app options, PC options and anything added later match without being told to.
Menu {
    id: control

    property var initiator

    implicitWidth: 320
    padding: Theme.sp2
    margins: Theme.sp4

    background: Rectangle {
        implicitWidth: 320
        color: Theme.floatBg
        radius: Theme.cardRadius + 2
        border.color: Theme.lineHi
        border.width: 1
    }

    // Menus float over content that is often bright artwork; without a scrim
    // the panel edge disappears into a capsule behind it.
    Overlay.modal: Rectangle {
        color: Theme.scrim
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.durFast }
        NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: Theme.durFast }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Theme.durFast }
    }

    onOpened: {
        // If the initiating object currently has keyboard focus,
        // give focus to the first visible and enabled menu item
        if (initiator.focus) {
            for (var i = 0; i < count; i++) {
                var item = itemAt(i)
                if (item.visible && item.enabled) {
                    item.forceActiveFocus(Qt.TabFocusReason)
                    break
                }
            }
        }
    }
}
