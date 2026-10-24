# Boot Terminal: GRUB theme handover

A trading-terminal style GRUB theme for a dual-boot PC (Arch Linux + Windows 11). Cyan on deep navy, a faint grid, one dim price chart, a framed center panel. Target resolution **1920×1080**. Everything is static: no countdown, no animation.

Look at `mockups/mockup_main.png` first. It is the target, and everything below describes how to reproduce it in GRUB.

## What's in this folder

```
boot-terminal/
├── theme.txt              starting theme file (see "Things to verify")
├── background.png         1920×1080, 8-bit RGB, panel frame and decoration baked in
├── select_nw.png … select_se.png   9-slice selection highlight, 8×8 RGBA each
├── icons/
│   ├── arch.png           40×40 RGBA
│   └── windows.png        40×40 RGBA
├── mockups/
│   ├── mockup_main.png      main menu, Arch Linux selected
│   └── mockup_advanced.png  Advanced options submenu at its 5-row maximum
└── HANDOVER.md
```

Not included: the font files. Download **IBM Plex Mono** (Regular and SemiBold) from Google Fonts (https://fonts.google.com/specimen/IBM+Plex+Mono) and convert them as described below.

## What GRUB draws vs. what is baked in

| Layer | Drawn by | Contents |
| --- | --- | --- |
| `background.png` | baked | Gradient, grid, price chart, top bar ("BOOT//TERMINAL", "NODE 01 · UEFI x86_64 · READY"), bottom bar, the **whole panel frame** with its "SELECT BOOT TARGET" header, corner brackets, dotted guides between row slots |
| `boot_menu` | GRUB | Entry labels, icons, selection highlight |
| `label` | GRUB | `Enter: boot    e: edit entry    c: console` |

The panel frame is part of the background, so `menu_pixmap_style` is **not** used. Don't add one.

## Spec (px on 1920×1080)

### Menu region (`boot_menu`)

| Property | Value |
| --- | --- |
| left / top | **544 / 360** |
| width / height | **832 / 352** (fits exactly 5 rows) |
| row height (`item_height`) | **64** |
| gap between rows (`item_spacing`) | **8** |
| highlight outer edge → icon | **20** |
| icon size | **40 × 40** |
| icon → label (`item_icon_space`) | **16** (label starts 76 px from the row's left edge) |
| scrollbar | off |

Row *n* (0-based) has its top at `360 + n × 72`. The baked dotted guides sit in the gaps at y = 427, 499, 571 and 643. If the rows don't land between them, the spacing is off.

Baked panel, for reference: x 520–1400, y 288–728. Header bar at y 288–344.

### Selection highlight: `select_*.png`

- 9 slices, **corner size 8 px**, each slice 8×8 RGBA. Edges and center stretch.
- Center: `#22D3EE` at 10% alpha.
- Top, bottom and right border: 1 px `#22D3EE` at 35% alpha.
- Left edge: 3 px solid `#22D3EE` accent bar, full height.
- Right corners: an 8 px L-bracket in solid `#22D3EE`.
- When drawn, the highlight's **outer edge** should cover x 544–1376 and the full 64 px row height.

### Fonts

| Use | Family | Weight | Size |
| --- | --- | --- | --- |
| Normal entry | IBM Plex Mono | Regular | 22 px |
| Selected entry | IBM Plex Mono | SemiBold | 22 px |
| Hint line | IBM Plex Mono | Regular | 16 px |

Chakra Petch (titles) and the 14 px status text appear only inside `background.png`, so they don't need converting.

### Colors

| Role | Hex |
| --- | --- |
| Normal entry text | `#8FA6C4` |
| Selected entry text | `#EAFBFF` |
| Hint text | `#7D95B5` |
| Accent | `#22D3EE` |
| Background fallback (`desktop-color`) | `#0A1628` |

Contrast: normal 7.2:1 on the panel, selected 13.8:1 on the highlight, hint 5.1:1 on the background.

### Hint line (`label`)

Top at **y = 760**, height 24, full width, **centered**.

## Install steps (Arch)

1. **Convert the fonts** into the theme folder:
   ```sh
   grub-mkfont -s 22 -o boot-terminal/plexmono-regular-22.pf2  IBMPlexMono-Regular.ttf
   grub-mkfont -s 22 -o boot-terminal/plexmono-semibold-22.pf2 IBMPlexMono-SemiBold.ttf
   grub-mkfont -s 16 -o boot-terminal/plexmono-regular-16.pf2  IBMPlexMono-Regular.ttf
   ```
2. **Copy the theme:** `sudo cp -r boot-terminal /boot/grub/themes/`
3. **Point GRUB at it** in `/etc/default/grub`:
   ```
   GRUB_THEME="/boot/grub/themes/boot-terminal/theme.txt"
   GRUB_GFXMODE=1920x1080,auto
   GRUB_TIMEOUT_STYLE=menu
   GRUB_TIMEOUT=-1
   ```
   `GRUB_TIMEOUT=-1` makes the menu wait indefinitely, which matches the "no countdown" design.
4. **Regenerate:** `sudo grub-mkconfig -o /boot/grub/grub.cfg`. With `GRUB_THEME` set, the generated config loads every `.pf2` in the theme folder.

## Things to verify (the design can't guarantee these)

1. **Font names.** `theme.txt` refers to fonts as `"IBM Plex Mono Regular 22"` and `"IBM Plex Mono SemiBold 22"`. Use whatever name `grub-mkfont` actually wrote. If a name doesn't match, GRUB silently falls back to its default font, so check the result on screen.
2. **Highlight offset.** GRUB draws the highlight's border slices *outside* the item's content box. Compare with the mockup: the highlight's outer edge should land on x 544–1376, and the icon should sit 20 px inside it. If it's off, shift `left`/`width` by the 8 px corner and tune `item_padding` (starts at 12).
3. **Icons map by entry class.** `icons/arch.png` is used for entries with `--class arch`, and `icons/windows.png` for `--class windows`. If your `grub.cfg` (or os-prober) uses other classes, rename or duplicate the files to match. "Advanced options" should have no icon, and its label should still line up with the others.
4. **Resolution.** The background is built for exactly 1920×1080. At any other `GRUB_GFXMODE`, the baked panel and the live menu won't line up.
5. **Submenu length.** The panel fits 5 rows. If you add more kernels, the list will scroll inside the panel, and the scrollbar is turned off.

## Design rules (if you touch the art)

- One accent hue. Cyan means "selected" or "the frame". Green appears only once, on READY. No red.
- Square edges everywhere. Corners are marked with brackets, never rounded.
- Never apply shadow, glow or transparency to live text. Any glow belongs in the background image.
- All PNGs must stay 8-bit RGB/RGBA, never indexed or palette.
