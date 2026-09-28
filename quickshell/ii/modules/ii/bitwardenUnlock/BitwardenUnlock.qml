pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    Loader {
        active: BitwardenVault.unlockPromptOpen
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:bitwardenUnlock"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                BitwardenUnlockContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
