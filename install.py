#!/usr/bin/env python3
"""Install the Tickerline theme on top of illogical-impulse (end-4's dots-hyprland).

  python3 install.py               check requirements, install, restart the shell
  python3 install.py --no-restart  same, but leave Quickshell running

The theme files go to ~/.local/share/tickerline. Every config file this script
changes is first copied to <file>.pre-tickerline (only once), which uninstall.py restores.
After every dots-hyprland update, run ~/.local/share/tickerline/apply-palette.py
again: updates overwrite the files it patches.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path

HOME = Path.home()
CONF = HOME / ".config"
REPO = Path(__file__).resolve().parent
DEST = HOME / ".local/share/tickerline"
WALLPAPER = HOME / ".local/share/backgrounds/tickerline.png"

UI, MONO, DISPLAY = "IBM Plex Sans", "BlexMono Nerd Font", "Chakra Petch"
CURSOR, ICONS = "Bibata-Original-Classic", "Papirus-Dark"
CHAKRA_URL = "https://github.com/google/fonts/raw/main/ofl/chakrapetch/"
CURSOR_URL = f"https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/{CURSOR}.tar.xz"


def say(*a):
    print("::", *a)


def backup(path):
    b = path.with_name(path.name + ".pre-tickerline")
    if path.exists() and not b.exists():
        shutil.copy2(path, b)


def write(path, text):
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    backup(path)
    path.write_text(text)
    say("wrote", path)


def run(*cmd):
    """Best effort: a missing tool (no KDE, no session) shouldn't stop the install."""
    try:
        subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        pass


# ---------- checks ----------

def check():
    problems, pkgs = [], []
    if not (CONF / "quickshell/ii/shell.qml").exists():
        problems.append("illogical-impulse isn't installed (no ~/.config/quickshell/ii). Install it first: "
                        "https://github.com/end-4/dots-hyprland")
    if not (CONF / "hypr/hyprland.lua").exists():
        problems.append("Hyprland isn't using the Lua config (~/.config/hypr/hyprland.lua). "
                        "Update Hyprland and dots-hyprland first.")
    for cmd, pkg in (("hyprctl", "hyprland"), ("kitty", "kitty"), ("fuzzel", "fuzzel"),
                     ("hyprlock", "hyprlock"), ("fc-list", "fontconfig")):
        if not shutil.which(cmd):
            pkgs.append(pkg)
    fonts = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True).stdout \
        if shutil.which("fc-list") else ""
    for family, pkg in ((UI, "ttf-ibm-plex"), (MONO, "ttf-ibmplex-mono-nerd"),
                        ("Symbols Nerd Font Mono", "ttf-nerd-fonts-symbols-mono")):
        if family not in fonts:
            pkgs.append(pkg)
    if not Path(f"/usr/share/icons/{ICONS}").exists():
        pkgs.append("papirus-icon-theme")
    if pkgs:
        problems.append("Missing packages. Install them with:\n     sudo pacman -S --needed " + " ".join(pkgs))
    if problems:
        print("Can't install yet:\n" + "\n".join(f"  - {p}" for p in problems))
        sys.exit(1)


# ---------- downloads (skipped when already there) ----------

def fetch(url, path):
    say("downloading", url)
    path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=60) as r:
        path.write_bytes(r.read())


def downloads():
    chakra = HOME / ".local/share/fonts/ChakraPetch"
    for name in ("Regular", "Medium", "SemiBold", "Bold"):
        f = chakra / f"ChakraPetch-{name}.ttf"
        if not f.exists():
            fetch(CHAKRA_URL + f.name, f)
    if not (chakra / "OFL.txt").exists():
        fetch(CHAKRA_URL + "OFL.txt", chakra / "OFL.txt")
    run("fc-cache", "-f")

    icons = HOME / ".local/share/icons"
    if not (icons / CURSOR).exists():
        archive = icons / f"{CURSOR}.tar.xz"
        fetch(CURSOR_URL, archive)
        with tarfile.open(archive) as t:
            t.extractall(icons, filter="data")
        archive.unlink()


# ---------- config edits ----------

def set_kitty(text, key, value):
    """kitty.conf: 'key value' lines. Replace the first active one, else append."""
    line = f"{key} {value}"
    pat = re.compile(rf"^{re.escape(key)}\s.*$", re.M)
    return pat.sub(line, text, count=1) if pat.search(text) else text.rstrip("\n") + f"\n{line}\n"


def set_ini(text, section, key, value):
    """fuzzel.ini: section None is the top (main) part before the first [header]."""
    lines, out, cur, done = text.splitlines(), [], None, False

    def flush():
        nonlocal done
        if cur == section and not done:
            while out and out[-1] == "":
                out.pop()
            out.append(f"{key}={value}")
            out.append("")
            done = True

    for l in lines:
        m = re.match(r"\[(.+)\]", l.strip())
        if m:
            flush()
            cur = m.group(1)
        elif cur == section and re.match(rf"{re.escape(key)}\s*=", l) and not done:
            out.append(f"{key}={value}")
            done = True
            continue
        out.append(l)
    flush()
    if not done:
        out += ["", f"[{section}]", f"{key}={value}"]
    return "\n".join(out) + "\n"


def edit_configs():
    # Hyprland: our file in custom/, loaded from custom/general.lua (which ii loads)
    custom = CONF / "hypr/custom"
    write(custom / "tickerline.lua", (DEST / "hypr/tickerline.lua").read_text())
    general = custom / "general.lua"
    text = general.read_text() if general.exists() else ""
    if 'require("custom.tickerline")' not in text:
        write(general, text.rstrip("\n") + '\n\nrequire("custom.tickerline") -- Tickerline\n')

    # kitty: no outer margin, 16 px padding (kitty counts in pt: 12 pt = 16 px)
    kitty = CONF / "kitty/kitty.conf"
    if kitty.exists():
        t = kitty.read_text()
        for k, v in (("font_family", MONO), ("window_margin_width", "0"), ("window_padding_width", "12")):
            t = set_kitty(t, k, v)
        write(kitty, t)

    # fuzzel: about 610 px wide, 8 rows of 40 px, square 2 px border
    fuzzel = CONF / "fuzzel/fuzzel.ini"
    if fuzzel.exists():
        t = fuzzel.read_text()
        for k, v in (("font", f"{MONO}:size=12"), ("prompt", '"> "'), ("dpi-aware", "no"),
                     ("icon-theme", ICONS), ("width", "56"), ("lines", "8"), ("line-height", "40px"),
                     ("horizontal-pad", "24"), ("vertical-pad", "16"), ("inner-pad", "8")):
            t = set_ini(t, None, k, v)
        for k, v in (("radius", "0"), ("width", "2")):
            t = set_ini(t, "border", k, v)
        write(fuzzel, t)

    # ii: matugen off (the palette is fixed), fonts, flat bar, hyprlock, wallpaper
    cfg_path = CONF / "illogical-impulse/config.json"
    cfg = json.loads(cfg_path.read_text())
    a = cfg.setdefault("appearance", {})
    a.setdefault("wallpaperTheming", {}).update(enableAppsAndShell=False, enableQtApps=False, enableTerminal=False)
    a.setdefault("fonts", {}).update(main=UI, title=UI, reading=UI, numbers=MONO, monospace=MONO,
                                     iconNerd=MONO, expressive=DISPLAY)
    a.setdefault("transparency", {}).update(enable=True, automatic=False,
                                            backgroundTransparency=0.08, contentTransparency=0.08)
    a["fakeScreenRounding"] = 0
    bar = cfg.setdefault("bar", {})
    bar.update(cornerStyle=2, floatStyleShadow=False)
    bar.setdefault("workspaces", {}).update(showAppIcons=False, alwaysShowNumbers=True)
    cfg.setdefault("lock", {})["useHyprlock"] = True
    cfg.setdefault("background", {}).update(wallpaperPath=str(WALLPAPER), thumbnailPath=str(WALLPAPER))
    # ii's Dark Mode toggle becomes the Matte toggle (apply-palette.py), so make sure it's shown
    toggles = cfg.get("sidebar", {}).get("quickToggles", {}).get("android", {}).get("toggles")
    if isinstance(toggles, list) and not any(t.get("type") == "darkMode" for t in toggles):
        toggles.append({"size": 2, "type": "darkMode"})
    write(cfg_path, json.dumps(cfg, indent=2) + "\n")

    # fontconfig: UI and mono families first, Nerd symbols as fallback
    fc = CONF / "fontconfig/fonts.conf"
    t = fc.read_text() if fc.exists() else \
        '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n</fontconfig>\n'
    if "Tickerline" not in t:
        block = "".join(
            f"    <alias>\n        <family>{generic}</family>\n"
            f"        <prefer><family>{fam}</family><family>Symbols Nerd Font Mono</family></prefer>\n"
            f"    </alias>\n" for generic, fam in (("sans-serif", UI), ("monospace", MONO)))
        t = t.replace("</fontconfig>", "    <!-- Tickerline: UI and mono families -->\n"
                      + block + "</fontconfig>", 1)
        write(fc, t)

    # GTK and KDE: fonts, icons, cursor
    for key, value in (("font-name", f"{UI} 10"), ("monospace-font-name", f"{MONO} 10"),
                       ("icon-theme", ICONS), ("cursor-theme", CURSOR), ("cursor-size", "24")):
        run("gsettings", "set", "org.gnome.desktop.interface", key, value)
    kw = shutil.which("kwriteconfig6") or shutil.which("kwriteconfig5")
    if kw:
        qfont = lambda fam, size: f"{fam},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
        for key, value in (("font", qfont(UI, 10)), ("menuFont", qfont(UI, 10)), ("toolBarFont", qfont(UI, 10)),
                           ("smallestReadableFont", qfont(UI, 8)), ("fixed", qfont(MONO, 10))):
            run(kw, "--file", "kdeglobals", "--group", "General", "--key", key, value)
        run(kw, "--file", "kdeglobals", "--group", "Icons", "--key", "Theme", ICONS)
        run(kw, "--file", "kcminputrc", "--group", "Mouse", "--key", "cursorTheme", CURSOR)
        run(kw, "--file", "kcminputrc", "--group", "Mouse", "--key", "cursorSize", "24")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-restart", action="store_true", help="don't restart Quickshell")
    args = ap.parse_args()

    check()
    say("copying the theme to", DEST)
    shutil.copytree(REPO / "desktop", DEST, dirs_exist_ok=True)
    shutil.copy2(REPO / "uninstall.py", DEST)
    WALLPAPER.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(DEST / "wallpaper.png", WALLPAPER)
    downloads()
    edit_configs()
    say("applying the palette")
    subprocess.run([sys.executable, str(DEST / "apply-palette.py")], check=True)

    # New QML files (the bar's token singleton) only load on a full restart
    if not args.no_restart and os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        say("restarting Quickshell")
        run("pkill", "-x", "qs")
        run("hyprctl", "dispatch", 'hl.dsp.exec_cmd("qs -c ii")')

    print("""
Done. Optional, needs root:
  sudo papirus-folders -C cyan --theme Papirus-Dark   cyan folder icons (package: papirus-folders)
  sudo grub/install.sh                                the GRUB boot theme
GTK apps pick up the new colors after a restart. After every dots-hyprland update run:
  python3 ~/.local/share/tickerline/apply-palette.py""")


if __name__ == "__main__":
    main()
