#!/usr/bin/env bash
# Run Tickerline in a nested Hyprland window with its own home folder (local/dev-home),
# so your real config is never touched. Every start installs the repo's current state first.
#   dev/nested.sh          install + start
#   dev/nested.sh --reset  wipe the dev home and start from a fresh dots-hyprland copy
# Needs a running Wayland session (the nested Hyprland opens as a window) and a
# dots-hyprland checkout ($DOTS, default ~/dots-hyprland).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEV=$REPO/local/dev-home
DOTS=${DOTS:-$HOME/dots-hyprland}

[ "${1:-}" = --reset ] && rm -rf "$DEV"
if [ ! -e "$DEV/.config/quickshell/ii/shell.qml" ]; then
    mkdir -p "$DEV/.config" "$DEV/.local/share" "$DEV/.local/state" "$DEV/.cache"
    cp -r "$DOTS/dots/.config/." "$DEV/.config/"
    # reuse your fonts and cursors instead of downloading them again
    for d in fonts icons; do [ -d "$HOME/.local/share/$d" ] && ln -sfn "$HOME/.local/share/$d" "$DEV/.local/share/$d"; done
fi

# no-op stand-ins, so the install can't reload your real Hyprland, kitty or KDE colors
STUB=$DEV/.stub
mkdir -p "$STUB"
for c in hyprctl pkill plasma-apply-colorscheme; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done

export HOME=$DEV XDG_CONFIG_HOME=$DEV/.config XDG_DATA_HOME=$DEV/.local/share \
       XDG_STATE_HOME=$DEV/.local/state XDG_CACHE_HOME=$DEV/.cache
unset HYPRLAND_INSTANCE_SIGNATURE
# own session bus: gsettings, notifications and the tray stay out of your real session
PATH=$STUB:$PATH dbus-run-session python3 "$REPO/install.py" --no-restart
exec dbus-run-session Hyprland
