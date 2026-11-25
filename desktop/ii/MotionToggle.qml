// SPDX-License-Identifier: GPL-3.0-only (builds on end-4/dots-hyprland, see LICENSE)
// Tickerline: the one switch that stops all motion (QWD principle 12): Hyprland, hyprlock, the shell, GTK and KDE.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.bar

QuickToggleModel {
    readonly property bool still: TickerTokens.t._still ?? false

    name: "Motion"
    statusText: still ? "Off" : "On"

    toggled: !still
    icon: "animation"

    mainAction: () => {
        Quickshell.execDetached(["python3", "@@SCRIPT@@", "--motion", "toggle"]);
    }

    tooltipText: "Animations | Off stops all motion"
}
