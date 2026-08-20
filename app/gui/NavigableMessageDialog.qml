import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

NavigableDialog {
    id: dialog

    property alias text: dialogLabel.dialogText
    property alias showSpinner: dialogSpinner.visible
    property alias imageSrc: dialogImage.source

    property string helpText
    property string helpUrl : "https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"
    property string helpTextSeparator : " "

    // A question and a failure are different events and should not look the
    // same; the accent tints the whole treatment rather than only the icon.
    readonly property bool isQuestion: (standardButtons & Dialog.Yes) !== 0
    readonly property color toneColor: isQuestion ? Theme.accent : Theme.danger

    onOpened: {
        // Force keyboard focus on the label so keyboard navigation works
        if (dialogButtonBox.count > 0) {
            dialogButtonBox.itemAt(dialogButtonBox.count - 1).forceActiveFocus(Qt.TabFocus)
        }
    }

    RowLayout {
        spacing: Theme.sp4

        BusyIndicator {
            id: dialogSpinner
            visible: false
            running: visible
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
        }

        Rectangle {
            visible: !showSpinner
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop
            radius: 12
            color: Qt.rgba(dialog.toneColor.r, dialog.toneColor.g, dialog.toneColor.b, 0.12)
            border.color: Qt.rgba(dialog.toneColor.r, dialog.toneColor.g, dialog.toneColor.b, 0.4)
            border.width: 1

            Image {
                id: dialogImage
                anchors.centerIn: parent
                source: dialog.isQuestion ?
                            "qrc:/res/baseline-help_outline-24px.svg" :
                            "qrc:/res/baseline-error_outline-24px.svg"
                sourceSize { width: 24; height: 24 }
            }
        }

        Label {
            property string dialogText

            id: dialogLabel
            text: dialogText + ((helpText && (standardButtons & Dialog.Help)) ? (helpTextSeparator + helpText) : "")
            color: Theme.textColor
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsBody
            font.weight: Font.DemiBold
            lineHeight: 1.35
            wrapMode: Text.Wrap
            Layout.maximumWidth: 460
            Layout.alignment: Qt.AlignVCenter
        }
    }

    footer: DialogButtonBox {
        id: dialogButtonBox
        standardButtons: dialog.standardButtons
        alignment: Qt.AlignRight
        spacing: Theme.sp2
        padding: Theme.sp5
        topPadding: Theme.sp4

        background: Item {}

        delegate: Button {
            id: dialogButton

            // The affirmative answer is the one being offered, so it carries the
            // weight; everything else stays quiet.
            readonly property bool isPrimary:
                DialogButtonBox.buttonRole === DialogButtonBox.AcceptRole ||
                DialogButtonBox.buttonRole === DialogButtonBox.YesRole

            implicitHeight: Theme.controlHeight
            leftPadding: Theme.sp5
            rightPadding: Theme.sp5

            background: Rectangle {
                radius: 11
                color: dialogButton.isPrimary
                       ? (dialogButton.activeFocus ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                       : (dialogButton.activeFocus ? Theme.panelHi : "transparent")
                border.color: dialogButton.isPrimary ? "transparent"
                            : dialogButton.activeFocus ? Theme.accent : Theme.lineHi
                border.width: dialogButton.isPrimary ? 0 : 1
            }

            contentItem: Text {
                text: dialogButton.text
                color: dialogButton.isPrimary ? Theme.bg : Theme.textColor
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsLabel
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }

        onHelpRequested: {
            Qt.openUrlExternally(helpUrl)
            close()
        }
    }
}
