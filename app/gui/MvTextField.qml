import QtQuick 2.9
import QtQuick.Controls 2.5

// Text field in the Moonvibe vocabulary: a panel chip with a lineHi border
// that goes accent while it is being edited.
//
// `activateToEdit` exists for the Steam Deck. Landing on a live text input is
// what summons the on-screen keyboard, and on the settings page the D-pad walks
// the whole tab chain — so merely passing over a field would throw the OSK over
// the screen. With activateToEdit set, the field is read-only until the user
// deliberately opens it (A / Return / click) and closes again on B / Return, so
// the keyboard only ever appears when someone actually asked to type.
TextField {
    id: control

    property bool activateToEdit: false
    property bool editing: false

    readOnly: activateToEdit && !editing

    implicitHeight: Theme.controlHeight
    leftPadding: Theme.sp4
    rightPadding: Theme.sp4 + (editHint.visible ? editHint.width + Theme.sp2 : 0)
    topPadding: 0
    bottomPadding: 0

    font.family: Theme.fontBody
    font.pixelSize: Theme.fsBody
    font.weight: Font.DemiBold

    color: Theme.textColor
    selectionColor: Theme.accent
    selectedTextColor: Theme.bg
    verticalAlignment: TextInput.AlignVCenter

    // Material floats its own placeholder up out of the field when focused,
    // which reads as a bug against a hand-drawn background. Hide theirs and
    // draw one that stays put.
    placeholderTextColor: "transparent"

    background: Rectangle {
        radius: Theme.capsuleRadius
        color: control.enabled ? Theme.panel : Theme.bgRaised
        border.width: control.activeFocus ? 2 : 1
        border.color: !control.enabled ? Theme.line
                    : control.editing ? Theme.accent
                    : control.activeFocus ? Theme.accentDeep
                    : Theme.lineHi
    }

    Text {
        id: placeholderLabel
        anchors.fill: parent
        anchors.leftMargin: control.leftPadding
        anchors.rightMargin: control.rightPadding
        visible: !control.length && !control.preeditText && control.placeholderText
        text: control.placeholderText
        color: Theme.textFaint
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Without this the field looks live but swallows every keystroke. It says
    // what the field wants rather than naming a key, since the same field is
    // driven by a gamepad, a keyboard and a touchscreen.
    Rectangle {
        id: editHint
        visible: control.activateToEdit && (control.activeFocus || control.editing)
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        width: editHintLabel.width + Theme.sp3
        radius: 11
        color: control.editing ? Theme.accent : Theme.glyphBg

        Text {
            id: editHintLabel
            anchors.centerIn: parent
            text: control.editing ? qsTr("EDITING") : qsTr("EDIT")
            color: control.editing ? Theme.bg : Theme.textMuted
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.2
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.activateToEdit && !control.editing
        onClicked: control.beginEditing()
    }

    function beginEditing() {
        forceActiveFocus()
        editing = true
        Qt.inputMethod.show()
    }

    function endEditing() {
        editing = false
        Qt.inputMethod.hide()
    }

    onActiveFocusChanged: {
        if (!activeFocus) {
            editing = false
        }
    }

    // Deliberately Keys.onPressed rather than the per-key handlers: callers
    // (the custom resolution and frame rate dialogs) bind Keys.onReturnPressed
    // themselves, and a handler declared there would replace one declared here.
    // In UI navigation mode the gamepad's A button arrives as Space, not Return.
    Keys.onPressed: function(event) {
        if (!control.activateToEdit) {
            return
        }

        if (!control.editing) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                control.beginEditing()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control.endEditing()
            event.accepted = true
        }
    }
}
