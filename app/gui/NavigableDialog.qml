import QtQuick 2.0
import QtQuick.Controls 2.5

Dialog {
    modal: true
    anchors.centerIn: Overlay.overlay

    // Dark scrim (the Material default dims with light gray)
    Overlay.modal: Rectangle {
        color: "#B004050A"
    }

    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
