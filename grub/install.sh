#!/bin/bash
# Install the Boot Terminal GRUB theme. Run as root: sudo grub/install.sh
# Needs: grub (grub-mkfont, grub-mkconfig) and ttf-ibm-plex.
# /etc/default/grub is copied to /etc/default/grub.pre-asd first (only once).
set -euo pipefail
SRC="$(dirname "$(realpath "$0")")"

[ "$(id -u)" = 0 ] || { echo "Run as root: sudo $0"; exit 1; }

# GRUB's folder: wherever grub.cfg lives (/boot/grub on most Arch installs)
GRUB_DIR=""
for d in /boot/grub /efi/grub /boot/efi/grub; do
    [ -f "$d/grub.cfg" ] && { GRUB_DIR=$d; break; }
done
[ -n "$GRUB_DIR" ] || { echo "No grub.cfg found in /boot/grub, /efi/grub or /boot/efi/grub."; exit 1; }

THEME="$GRUB_DIR/themes/boot-terminal"
rm -rf "$THEME"
mkdir -p "$GRUB_DIR/themes"
cp -r "$SRC/boot-terminal" "$THEME"
"$SRC/build-fonts.sh" "$THEME"

CFG=/etc/default/grub
[ -f "$CFG.pre-asd" ] || cp "$CFG" "$CFG.pre-asd"
set_key() {  # replace KEY=..., or append it
    if grep -q "^#\?$1=" "$CFG"; then sed -i "s|^#\?$1=.*|$1=$2|" "$CFG"; else echo "$1=$2" >> "$CFG"; fi
}
set_key GRUB_THEME "\"$THEME/theme.txt\""
set_key GRUB_GFXMODE "1920x1080,auto"   # the background is drawn for exactly 1920x1080
set_key GRUB_GFXPAYLOAD_LINUX "keep"
set_key GRUB_TIMEOUT_STYLE "menu"

grub-mkconfig -o "$GRUB_DIR/grub.cfg"
echo "Installed to $THEME. Undo: cp $CFG.pre-asd $CFG && grub-mkconfig -o $GRUB_DIR/grub.cfg"
