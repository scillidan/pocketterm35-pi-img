#!/bin/bash
# PocketTerm35 first-boot setup: display overlay, filesystem expansion,
# user groups. Runs once, then reboots.
# Retro emulation is installed separately (see the pi-esde-scripts repo).

set -euo pipefail

readonly SENTINEL="/var/lib/pocketterm35/firstboot-done"
readonly LOG_TAG="pocketterm35-firstboot"

log() {
	logger -t "$LOG_TAG" "$*"
	echo "[$LOG_TAG] $*" >&2
}

if [[ -f "$SENTINEL" ]]; then
	log "First-boot sentinel already exists; nothing to do."
	exit 0
fi
mkdir -p "$(dirname "$SENTINEL")"

log "Detecting Raspberry Pi model for the display overlay..."
MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
case "$MODEL" in
*"Raspberry Pi 5"*) POCKET_OVERLAY="waveshare-35dpi-5b" ;;
*"Raspberry Pi 4"*) POCKET_OVERLAY="waveshare-35dpi-4b" ;;
*)
	log "WARNING: unrecognized model '$MODEL'; skipping display overlay."
	POCKET_OVERLAY=""
	;;
esac

if [ -n "$POCKET_OVERLAY" ]; then
	CONFIG=/boot/firmware/config.txt
	if [ ! -f "$CONFIG" ]; then
		log "ERROR: $CONFIG not found; cannot apply the display overlay."
		exit 1
	fi
	# Copy the DTBOs baked into the rootfs onto the real boot partition (the
	# FAT partition that mounts over /boot/firmware at runtime).
	mkdir -p /boot/firmware/overlays
	if [ -d /usr/lib/pocketterm35/overlays ]; then
		install -m 0644 /usr/lib/pocketterm35/overlays/*.dtbo /boot/firmware/overlays/ ||
			log "WARNING: could not install display overlays onto the boot partition."
	fi

	if grep -q 'PocketTerm35 display configuration' "$CONFIG"; then
		log "Display configuration already present in $CONFIG (baked at build time); skipping."
	elif [ ! -f "/boot/firmware/overlays/$POCKET_OVERLAY.dtbo" ]; then
		log "WARNING: overlay '$POCKET_OVERLAY' not present; continuing without display config."
	else
		log "Applying PocketTerm35 overlay '$POCKET_OVERLAY'..."
		printf "\n# PocketTerm35 display configuration\n" >>"$CONFIG"
		printf "dtparam=i2c_arm=on\n" >>"$CONFIG"
		printf "dtoverlay=%s\n" "$POCKET_OVERLAY" >>"$CONFIG"
		printf "dtoverlay=dwc2,dr_mode=host\n" >>"$CONFIG"
	fi
fi

log "Expanding root filesystem..."
raspi-config nonint do_expand_rootfs

PRIMARY_USER=""
if command -v getent >/dev/null; then
	PRIMARY_USER="$(getent passwd 1000 | cut -d: -f1 || true)"
fi
if [[ -z "$PRIMARY_USER" ]]; then
	log "ERROR: could not detect primary user (UID 1000). Aborting."
	exit 1
fi
log "Primary user detected: $PRIMARY_USER"
usermod -a -G input,audio,video,gpio,spi,i2c,plugdev "$PRIMARY_USER" || true

date >"$SENTINEL"
log "First-boot setup complete. Rebooting..."
systemctl disable pocketterm35-firstboot.service || true
systemctl reboot
