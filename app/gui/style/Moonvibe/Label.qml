import QtQuick 2.9
import QtQuick.Templates 2.5 as T

T.Label {
    color: Theme.textColor
    font.family: Theme.fontBody
    // Deliberately no size here: most call sites set pointSize, and setting
    // both on one font makes Qt warn and pick one.
    font.weight: Font.DemiBold
    linkColor: Theme.accent
    verticalAlignment: Text.AlignVCenter
}
