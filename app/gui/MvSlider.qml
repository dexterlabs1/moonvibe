import QtQuick 2.9
import QtQuick.Controls 2.5

// Slider in the Moonvibe vocabulary, matching the in-stream drawer's bitrate
// control: a thick panelHi groove, an accent fill for the travelled part, and
// an 18px knob big enough to find with a thumbstick.
Slider {
    id: control

    implicitHeight: Theme.controlHeight
    padding: Theme.sp2

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 200
        width: control.availableWidth
        height: 8
        radius: 4
        color: Theme.panelHi

        Rectangle {
            width: control.position * parent.width
            height: parent.height
            radius: 4
            color: control.enabled ? Theme.accent : Theme.lineHi
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 18
        implicitHeight: 18
        radius: 9
        color: !control.enabled ? Theme.lineHi
             : control.pressed ? Qt.lighter(Theme.accent, 1.15)
             : Theme.textColor
        border.width: 2
        border.color: control.enabled ? (control.activeFocus ? Theme.accent : Theme.accentDeep)
                                      : Theme.line

        // Focus glow, the same treatment the host cards and capsules use.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 14
            height: parent.height + 14
            radius: width / 2
            color: "transparent"
            border.color: Theme.accent
            border.width: 4
            opacity: control.activeFocus ? 0.24 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }
}
