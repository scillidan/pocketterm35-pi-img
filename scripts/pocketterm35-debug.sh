#!/bin/bash
# PocketTerm35 debug dump: appends hardware/input diagnostics to
# /boot/firmware/pocketterm35-debug.txt on the FAT boot partition, so the log
# can be read from any PC by plugging in the SD card. Also logs to the journal.

set -uo pipefail

readonly OUT="/boot/firmware/pocketterm35-debug.txt"
readonly LOG_TAG="pocketterm35-debug"
readonly MAX_BYTES=262144

section() {
	echo
	echo "===== $* ====="
}

{
	section "pocketterm35-debug $(date -Is)"
	echo "kernel: $(uname -a)"
	echo "model: $(tr -d '\0' </proc/device-tree/model 2>/dev/null)"
	echo "cmdline: $(cat /boot/firmware/cmdline.txt 2>/dev/null)"

	section "config.txt"
	cat /boot/firmware/config.txt 2>&1

	section "overlays on boot partition (waveshare)"
	ls -l /boot/firmware/overlays/ 2>&1 | grep -iE 'waveshare|^total' || true

	section "baked overlays (rootfs)"
	ls -l /usr/lib/pocketterm35/overlays/ 2>&1 || true

	section "input devices (/proc/bus/input/devices)"
	cat /proc/bus/input/devices 2>&1

	section "/dev/input"
	ls -l /dev/input/ 2>&1 || true

	section "usb devices"
	lsusb 2>&1 || true

	section "loaded modules (hid/input/touch/i2c/spi/usb)"
	lsmod 2>&1 | grep -iE 'hid|input|touch|i2c|spi|usb|ads|xpt|goodix|ft6|edt' || true

	section "dmesg (input/touch/hid/usb/i2c/spi/overlay)"
	dmesg 2>&1 | grep -iE 'input|touch|hid|i2c|spi|usb|overlay|waveshare|ads|xpt|goodix|ft6|edt|dtbo' || true

	section "firstboot service"
	systemctl status pocketterm35-firstboot.service --no-pager 2>&1 || true
	journalctl -u pocketterm35-firstboot.service --no-pager -n 60 2>&1 || true
} >>"$OUT" 2>&1

# Cap the log so many boots cannot fill the FAT partition.
if [ "$(stat -c%s "$OUT" 2>/dev/null || echo 0)" -gt "$MAX_BYTES" ]; then
	tail -c "$MAX_BYTES" "$OUT" >"$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi

logger -t "$LOG_TAG" "debug info appended to $OUT"
