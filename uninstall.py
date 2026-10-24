#!/usr/bin/env python3
"""Remove the Arch System Design theme and restore the files it changed.

Every changed file has a <file>.pre-asd copy from before the first install; this puts
those back and deletes the files the theme added. Fonts, the cursor and GTK/KDE font
settings stay (they're harmless on their own). The GRUB theme is separate: see grub/.

If you updated dots-hyprland after installing, the .pre-asd copies of ii's QML files
are older than your ii version. Run dots-hyprland's update again afterwards so it
rewrites them.
"""
import re
import shutil
import subprocess
from pathlib import Path

HOME = Path.home()
CONF = HOME / ".config"

restored = 0
for root in (CONF, HOME / ".local/state/quickshell", HOME / ".local/share/color-schemes"):
    for b in root.rglob("*.pre-asd"):
        shutil.move(b, b.with_name(b.name.removesuffix(".pre-asd")))
        restored += 1
print(f":: restored {restored} files")

added = [
    CONF / "hypr/custom/arch-system-design.lua",
    CONF / "quickshell/ii/modules/ii/bar/AsdTokens.qml",
    HOME / ".local/state/quickshell/user/generated/asd-tokens.json",
    HOME / ".local/share/color-schemes/ArchSystemDesign.colors",
    HOME / ".local/share/color-schemes/ArchSystemDesignMatte.colors",
    HOME / ".local/share/backgrounds/arch-system-design.png",
]
for f in added:
    f.unlink(missing_ok=True)
# gtk.css had no backup if it didn't exist before; still ours if it carries the pins
for gtk in ("gtk-3.0", "gtk-4.0"):
    css = CONF / gtk / "gtk.css"
    if css.exists() and "arch-system-design pins" in css.read_text():
        css.unlink()
for d in (HOME / ".local/share/arch-system-design", HOME / ".local/state/arch-system-design"):
    shutil.rmtree(d, ignore_errors=True)

# custom/general.lua had no backup if install.py created it; drop just our line
general = CONF / "hypr/custom/general.lua"
if general.exists():
    t = re.sub(r'\n*require\("custom\.arch-system-design"\).*\n', "\n", general.read_text())
    general.write_text(t)

subprocess.run(["hyprctl", "reload"], check=False, capture_output=True)
print("""
Done. Restart Quickshell (log out and back in, or: pkill -x qs; then start "qs -c ii").
To get wallpaper-based colors back, pick a wallpaper in ii so matugen regenerates them.""")
