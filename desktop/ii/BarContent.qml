// SPDX-License-Identifier: GPL-3.0-only (builds on end-4/dots-hyprland, see LICENSE)
// Tickerline bar (spec: Desktop §7 "Bar"). Replaces ii's BarContent.qml.
// Double-brace token placeholders are filled from palette.json by apply-palette.py; edit this
// copy, not the one inside ~/.config/quickshell.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar

Item {
    id: root

    property var screen: root.QsWindow.window?.screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool windowOnThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name && (activeWindow?.activated ?? false)

    readonly property string sans: Appearance.font.family.main
    readonly property string mono: Appearance.font.family.monospace

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 20
        color: "{{divider}}"
    }
    component Label: Text {
        renderType: Text.NativeRendering
        verticalAlignment: Text.AlignVCenter
    }
    component Icon: MaterialSymbol {
        fill: 1
        iconSize: 16
        color: "{{text-secondary}}"
    }
    component Bracket: Item { // 6 px x 1 px cyan corner; flip with xs/ys
        property int xs: 1
        property int ys: 1
        width: 6
        height: 6
        Rectangle { width: 6; height: 1; color: "{{accent}}"; y: parent.ys > 0 ? 0 : 5 }
        Rectangle { width: 1; height: 6; color: "{{accent}}"; x: parent.xs > 0 ? 0 : 5 }
    }

    // Background: surface-base at 0.92, 1 px divider along the bottom with 48 px ticks
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("{{surface-base}}", 0.92)
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: "{{divider}}"
    }
    Repeater {
        model: Math.ceil(root.width / 48)
        Rectangle {
            required property int index
            x: index * 48
            anchors.bottom: parent.bottom
            width: 1
            height: 4
            color: "{{divider}}"
        }
    }

    // Left: sidebar button, window class, window title. Scroll = brightness
    FocusedScrollMouseArea {
        id: leftArea
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: workspaces.left }
        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 8

            Rectangle {
                implicitWidth: 12
                implicitHeight: 12
                color: GlobalStates.sidebarLeftOpen || leftArea.hovered ? "{{accent-hover}}" : "{{accent}}"
                Layout.rightMargin: 8
            }
            Label {
                text: root.windowOnThisMonitor ? (root.activeWindow?.appId ?? "") : "desktop"
                font { family: root.sans; pointSize: 8 }
                color: "{{text-muted}}"
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.windowOnThisMonitor ? (root.activeWindow?.title ?? "") : `Workspace ${root.monitor?.activeWorkspace?.id ?? 1}`
                font { family: root.sans; pointSize: 10 }
                color: "{{text-primary}}"
            }
        }
    }

    // Center: workspaces 1-10 in a bracket frame. Click = focus, scroll = next/prev, right click = overview
    MouseArea {
        id: workspaces
        anchors.centerIn: parent
        implicitWidth: wsRow.implicitWidth + 24
        implicitHeight: 32
        acceptedButtons: Qt.RightButton
        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        onWheel: wheel => Hyprland.dispatch(`hl.dsp.focus({workspace = "${wheel.angleDelta.y > 0 ? "r-1" : "r+1"}"})`)

        Bracket { anchors { left: parent.left; top: parent.top } }
        Bracket { anchors { left: parent.left; bottom: parent.bottom } ys: -1 }
        Bracket { anchors { right: parent.right; top: parent.top } xs: -1 }
        Bracket { anchors { right: parent.right; bottom: parent.bottom } xs: -1; ys: -1 }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: Config.options.bar.workspaces.shown
                MouseArea {
                    id: cell
                    required property int index
                    readonly property int wsId: Math.floor(((root.monitor?.activeWorkspace?.id ?? 1) - 1) / Config.options.bar.workspaces.shown) * Config.options.bar.workspaces.shown + index + 1
                    readonly property bool active: root.monitor?.activeWorkspace?.id === wsId
                    readonly property bool occupied: HyprlandData.windowList.some(w => w.workspace.id === wsId)
                    readonly property bool urgent: Hyprland.workspaces.values.find(w => w.id === wsId)?.urgent ?? false
                    readonly property var mainWindow: HyprlandData.biggestWindowForWorkspace(wsId)
                    width: 24
                    height: 24
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace = ${wsId}})`)

                    Rectangle {
                        anchors.fill: parent
                        color: cell.active ? "{{accent}}" : cell.occupied ? "{{surface-highest}}" : cell.containsMouse ? "{{surface-hover}}" : "transparent"
                        border.width: !cell.active && (cell.urgent || cell.occupied) ? 1 : 0
                        border.color: cell.urgent ? "{{warning}}" : "{{border-inactive}}"
                    }
                    // Occupied: icon of the biggest window, like ii's own workspaces. Empty: the number
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        visible: !!cell.mainWindow
                        source: Quickshell.iconPath(AppSearch.guessIcon(cell.mainWindow?.class), "image-missing")
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !cell.mainWindow
                        text: cell.wsId % 10
                        font { family: root.mono; pointSize: 9; weight: cell.active ? Font.DemiBold : Font.Normal }
                        color: cell.active ? "{{on-accent}}" : cell.urgent ? "{{warning}}" : cell.occupied ? "{{text-secondary}}" : "{{text-disabled}}"
                    }
                }
            }
        }
    }

    // Right: tray, CPU/MEM ticker | notifications, network, volume, battery | clock, date.
    // Click = right sidebar, scroll = volume
    FocusedScrollMouseArea {
        id: rightArea
        anchors { top: parent.top; bottom: parent.bottom; left: workspaces.right; right: parent.right }
        onScrollDown: Audio.decrementVolume()
        onScrollUp: Audio.incrementVolume()
        onMovedAway: GlobalStates.osdVolumeOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 24 }
            spacing: 16

            Item { Layout.fillWidth: true }

            SysTray {
                Layout.fillHeight: true
                invertSide: Config?.options.bar.bottom
            }

            Row {
                spacing: 6
                Label { text: "CPU"; font { family: root.mono; pointSize: 9 } color: "{{text-muted}}"; height: 40 }
                Label { text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`; font { family: root.mono; pointSize: 10 } color: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold ? "{{warning}}" : "{{text-primary}}"; height: 40 }
                Item { width: 10; height: 1 }
                Label { text: "MEM"; font { family: root.mono; pointSize: 9 } color: "{{text-muted}}"; height: 40 }
                Label { text: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)}G`; font { family: root.mono; pointSize: 10 } color: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold ? "{{warning}}" : "{{text-primary}}"; height: 40 }
            }

            Divider {}

            Icon {
                text: Notifications.silent ? "notifications_off" : Notifications.unread > 0 ? "notifications_unread" : "notifications"
                color: Notifications.unread > 0 ? "{{accent}}" : "{{text-secondary}}"
            }
            Icon { text: Network.materialSymbol }
            Icon { text: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up" }
            Item {
                visible: Battery.available
                implicitWidth: batteryRow.implicitWidth
                implicitHeight: 40
                Row {
                id: batteryRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                readonly property color tone: Battery.isCriticalAndNotCharging ? "{{error}}" : Battery.isLowAndNotCharging ? "{{warning}}" : Battery.isFullAndCharging ? "{{success}}" : "{{text-secondary}}"
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.isCharging ? "battery_charging_full" : "battery_full"
                    rotation: 90 // lying flat, terminal right, as in the mockup
                    color: parent.tone
                }
                Label {
                    height: 40
                    text: `${Math.round(Battery.percentage * 100)}%`
                    font { family: root.mono; pointSize: 10 }
                    color: parent.tone
                }
                }
                MouseArea {
                    id: batteryHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    BatteryPopup { hoverTarget: batteryHover }
                }
            }

            Divider {}

            Item {
                implicitWidth: clockRow.implicitWidth
                implicitHeight: 40
                Row {
                id: clockRow
                spacing: 10
                Label { height: 40; text: DateTime.time; font { family: root.mono; pointSize: 10; weight: Font.DemiBold } color: "{{text-primary}}" }
                Label { height: 40; text: Qt.locale("en_US").toString(DateTime.clock.date, "ddd d MMM").toUpperCase(); font { family: root.mono; pointSize: 9 } color: "{{text-muted}}" }
                }
                MouseArea {
                    id: clockHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    ClockWidgetPopup { hoverTarget: clockHover }
                }
            }
        }
    }
}
