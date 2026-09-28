import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property var activeClient: activeWindow?.HyprlandToplevel?.address ? HyprlandData.windowByAddress[`0x${activeWindow.HyprlandToplevel.address}`] : null
    property var biggestWindow: HyprlandData.windowList.reduce((maxWin, win) => {
        const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
        const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
        return winArea > maxArea ? win : maxWin;
    }, null)

    implicitWidth: colLayout.implicitWidth

    ColumnLayout {
        id: colLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.activeClient?.class ?? root.activeWindow?.appId ?? (root.biggestWindow?.class ?? Translation.tr("Desktop"))
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.activeClient?.title ?? root.activeWindow?.title ?? (root.biggestWindow?.title ?? `${Translation.tr("Workspace")} ${monitor?.activeWorkspace?.id ?? 1}`)
        }
    }
}
