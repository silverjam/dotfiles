#!/bin/sh
#
# Let Chromium-based browsers (google-chrome, vivaldi) open hidraw devices, so
# usevia.app can configure keyboards over WebHID without
# `sudo chmod a+rw /dev/hidraw*` after every replug.
#
#   scripts/install-via-udev.sh
#
# TAG+="uaccess" makes logind grant an ACL to whoever owns the active local
# seat, rather than opening the device to every user like chmod a+rw does.
# Matching all hidraw nodes instead of per-vendor IDs is deliberate: VIA
# keyboards span hundreds of vendor IDs, and FIDO keys already get the same
# treatment from systemd's own rules.
#
# The file must sort before 73-seat-late.rules, which is where logind turns
# the uaccess tag into ACLs.
#
# Native .deb installs only. Snap/flatpak builds also need their sandbox's
# raw-usb / device permissions, which a udev rule can't grant.
#
set -eu

RULES_FILE=/etc/udev/rules.d/70-via-hidraw.rules

sudo tee "$RULES_FILE" >/dev/null <<'RULES'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"
RULES

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --action=change

echo "installed $RULES_FILE; reload usevia.app and re-authorize the keyboard"
