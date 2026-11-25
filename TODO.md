# TODO

Open items. Remove an item when it is done. How the theme fits together is in `NOTES.md`.

1. **Use the core token names (QWD plan phase 9; later, not urgent).** `apply-palette.py` and the QML
   still read tickerline's old names (14 aliases in `design/qwd/projects/tickerline/aliases.yaml`, such as
   `surface-base`, `divider`, `outline`, `text-primary`, `text-secondary`). `text-muted` is a legacy name: it
   means the core's `text-faint`, and the core's `text-muted` is tickerline's `text-secondary`, so rename
   `text-muted` → `text-faint` first, then `text-secondary` → `text-muted`. Then tell QWD: a major QWD version
   drops the aliases once all three products have moved.
