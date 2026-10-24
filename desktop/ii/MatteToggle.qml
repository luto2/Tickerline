// SPDX-License-Identifier: GPL-3.0-only (builds on end-4/dots-hyprland, see LICENSE)
// Tickerline: replaces ii's Dark Mode toggle (dark only here) with the Matte palette.
// Night Light forces matte too, so the status says why it's on.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.bar

QuickToggleModel {
    readonly property bool night: TickerTokens.t._night ?? false

    name: "Matte"
    statusText: (TickerTokens.t._matte ?? false) ? "On" : night ? "On with Night Light" : "Off"

    toggled: TickerTokens.t._matte ?? false
    icon: "contrast"

    mainAction: () => {
        Quickshell.execDetached(["python3", "@@SCRIPT@@", "--matte", "toggle"]);
    }

    tooltipText: "Matte palette | Night Light turns it on too"
}
