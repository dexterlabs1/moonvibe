import QtQuick 2.9
import QtQuick.Controls 2.5

// A quiet secondary button in the Moonvibe vocabulary: a capsule that stays
// transparent until focused or hovered, with a lineHi outline that goes accent
// on focus. Factored from the hand-styled "Use Default" button in SettingsView
// so the profile bar's actions share one treatment.
Button {
    id: control

    implicitHeight: Theme.controlHeight
    leftPadding: Theme.sp4
    rightPadding: Theme.sp4

    font.family: Theme.fontBody
    font.pixelSize: Theme.fsLabel
    font.weight: Font.ExtraBold

    background: Rectangle {
        radius: Theme.capsuleRadius
        color: (control.enabled && (control.activeFocus || control.hovered)) ? Theme.panelHi : "transparent"
        border.width: 1
        border.color: !control.enabled ? Theme.line
                    : control.activeFocus ? Theme.accent
                    : Theme.lineHi
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? Theme.textColor : Theme.textDisabled
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // The gamepad sends Space here in UI navigation mode (handled by Button
    // itself) and Return in rail/arrow mode; Return is for keyboard users too.
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onEnterPressed: if (enabled) clicked()
}
