#!/bin/bash
# Convert IBM Plex Mono (package ttf-ibm-plex) to GRUB's .pf2 format in the given folder.
# The SemiBold file needs an explicit family name: grub-mkfont only knows Regular and Bold,
# so without -n it would be named exactly like the Regular file and never be used.
set -euo pipefail
OUT="${1:?usage: build-fonts.sh <theme folder>}"
TTF=/usr/share/fonts/TTF
for f in IBMPlexMono-Regular.ttf IBMPlexMono-SemiBold.ttf; do
    [ -f "$TTF/$f" ] || { echo "Missing $TTF/$f. Install it with: sudo pacman -S ttf-ibm-plex"; exit 1; }
done
# grub-mkfont warns once per OpenType feature it skips; those are harmless
mkfont() { grub-mkfont "$@" 2> >(grep -v "unsupported font feature" >&2); }
mkfont -s 22 -o "$OUT/plexmono-regular-22.pf2" "$TTF/IBMPlexMono-Regular.ttf"
mkfont -s 16 -o "$OUT/plexmono-regular-16.pf2" "$TTF/IBMPlexMono-Regular.ttf"
mkfont -n "IBM Plex Mono SemiBold" -s 22 -o "$OUT/plexmono-semibold-22.pf2" "$TTF/IBMPlexMono-SemiBold.ttf"
