#!/bin/bash
# Build standalone GRUB with theme + preview.cfg, boot in QEMU/OVMF, screenshot to shot.png
S=$(dirname "$(realpath "$0")"); T=$S/boot-terminal
"$S/build-fonts.sh" "$T"
pkill -f "fat:rw:$S/esp" 2>/dev/null; sleep 1
args=("boot/grub/grub.cfg=$S/preview.cfg")
for f in $(cd $T && find . -type f); do args+=("boot/grub/themes/boot-terminal/${f#./}=$T/${f#./}"); done
mkdir -p $S/esp/EFI/BOOT
grub-mkstandalone -O x86_64-efi -o $S/esp/EFI/BOOT/BOOTX64.EFI "${args[@]}" || exit 1
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd $S/vars.fd; rm -f $S/mon.sock
qemu-system-x86_64 -m 1024 -display none -vga none -device VGA,xres=1920,yres=1080 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=$S/vars.fd -drive file=fat:rw:$S/esp,format=raw \
  -monitor unix:$S/mon.sock,server,nowait -daemonize
python3 - "$S" "${1:-}" <<'PY'
import socket, sys, time
s, keys = sys.argv[1], sys.argv[2]
time.sleep(15)
c = socket.socket(socket.AF_UNIX); c.connect(f"{s}/mon.sock")
for k in keys.split():
    c.sendall(f"sendkey {k}\n".encode()); time.sleep(1)
c.sendall(f"screendump {s}/shot.ppm\n".encode()); time.sleep(2)
c.sendall(b"quit\n")
PY
magick $S/shot.ppm $S/shot.png
