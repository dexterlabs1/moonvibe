import QtQuick 2.9
import QtQuick.Controls 2.5

// Base for every dialog. Styling lives here so error, confirmation, pairing and
// anything added later share one surface treatment.
Dialog {
    id: control

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.sp5

    background: Rectangle {
        color: Theme.floatBg
        radius: Theme.cardRadius + 4
        border.color: Theme.lineHi
        border.width: 1
    }

    // Dark scrim. The Material default dims with a light gray, which over a
    // near-black UI reads as a white wash rather than a dimming.
    Overlay.modal: Rectangle {
        color: Theme.scrim
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.durBase }
        NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: Theme.durBase; easing.type: Easing.OutCubic }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Theme.durFast }
    }

    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
