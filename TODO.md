# TODO

Open items. Remove an item when it is done. How the theme fits together is in `NOTES.md`.

1. **Run `apply-palette.py` once on the real desktop.** Since the move to Quantum Works Design (phase 7,
   2026-11-14), `desktop/palette.json`, `desktop/palette-matte.json` and the colour lines of
   `grub/boot-terminal/theme.txt` are synced copies of `design/qwd/dist/tickerline/`. Their content is the
   same as before, but the script has not been run against them: run `python3 desktop/apply-palette.py`,
   switch to matte and back, and check the bar, kitty and hyprlock.
2. **A switch that stops all motion.** Quantum Works Design requires one in every product (principle 12,
   revised 2026-11-14): tool surfaces get short, functional motion only, and the switch turns all of it
   off. Every `hl.animation` in `desktop/hypr/tickerline.lua` is `enabled = true` with no way to turn them
   off, and the QML transitions have none either.
   Brand surfaces (GRUB, lock, session) may keep richer motion, but the switch stops that too. If the
   design rules need to change, file a QWD request (`qwd request new --product tickerline`).
3. **Use the core token names (QWD plan phase 9; later, not urgent).** `apply-palette.py` and the QML
   still read tickerline's old names (14 aliases in `design/qwd/projects/tickerline/aliases.yaml`, such as
   `surface-base`, `divider`, `outline`, `text-primary`, `text-secondary`). `text-muted` is a legacy name: it
   means the core's `text-faint`, and the core's `text-muted` is tickerline's `text-secondary`, so rename
   `text-muted` → `text-faint` first, then `text-secondary` → `text-muted`. Then tell QWD: a major QWD version
   drops the aliases once all three products have moved.
