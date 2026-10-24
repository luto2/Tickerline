pragma Singleton

// SPDX-License-Identifier: GPL-3.0-only (builds on end-4/dots-hyprland, see LICENSE)

// Tickerline tokens for the bar and the Matte toggle. apply-palette.py writes
// ticker-tokens.json; this reloads it live, so a palette switch needs no QML rewrite.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var t: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/ticker-tokens.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.t = JSON.parse(text());
            } catch (e) {
                // half-written file during a switch; the next change event reloads it
            }
        }
    }
}
