import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    function submit() {
        if (inputField.text.length === 0)
            return;
        const typed = inputField.text;
        // Clear the field before handing the value over, so the only remaining copy is
        // the argument in flight to the unlock process.
        inputField.text = "";
        BitwardenVault.submitUnlockPassword(typed);
    }

    function cancel() {
        inputField.text = "";
        BitwardenVault.cancelUnlockPrompt();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel();
        }
    }

    Component.onCompleted: inputField.forceActiveFocus()

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0
        Component.onCompleted: {
            opacity = 1;
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    WindowDialog {
        anchors.centerIn: parent
        backgroundWidth: 450
        show: false
        Component.onCompleted: {
            show = true;
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            iconSize: 26
            text: "lock"
            color: Appearance.colors.colSecondary
        }

        WindowDialogTitle {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Unlock Bitwarden")
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: BitwardenVault.lastError.length > 0 ? BitwardenVault.lastError : Translation.tr("Enter your master password to unlock the vault for this session.")
        }

        MaterialTextField {
            id: inputField
            Layout.fillWidth: true
            focus: true
            placeholderText: Translation.tr("Master password")
            echoMode: TextInput.Password
            onAccepted: root.submit()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                }
            }
        }

        WindowDialogButtonRow {
            Layout.bottomMargin: 10
            Item {
                Layout.fillWidth: true
            }
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: root.cancel()
            }
            DialogButton {
                buttonText: Translation.tr("Unlock")
                onClicked: root.submit()
            }
        }
    }
}
