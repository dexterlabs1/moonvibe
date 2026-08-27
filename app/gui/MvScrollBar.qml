import QtQuick 2.9
import QtQuick.Controls 2.5

// Scroll bar in the Moonvibe vocabulary. The Material one paints a black wash
// behind a translucent white handle, neither of which is a Theme colour, and
// both of which read as a desktop widget on a handheld.
//
// This is a position indicator, not a control: the Deck is driven with a stick
// and a thumb, so the bar's job is to say how far down the page you are and
// then get out of the way. It stays interactive so a mouse still works on the
// desktop, but nothing about the layout invites you to grab it.
ScrollBar {
    id: control

    padding: Theme.sp1
    implicitWidth: Theme.sp4

    background: Rectangle {
        radius: width / 2
        color: Theme.line
        opacity: control.active ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
    }

    contentItem: Rectangle {
        implicitWidth: Theme.sp2
        implicitHeight: Theme.sp2
        radius: width / 2
        color: control.pressed ? Theme.accent : Theme.textDisabled
        opacity: control.policy === ScrollBar.AlwaysOn || control.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
    }
}
