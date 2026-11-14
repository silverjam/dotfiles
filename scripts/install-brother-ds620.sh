#!/usr/bin/env bash
#
# setup-brother-ds620.sh -- install Brother's libsane-dsseries driver for the
# DS-620 (and sibling DS-series) sheet-fed scanners on modern Debian/Ubuntu.
#
# Why a repack is needed
# ----------------------
# Brother's prebuilt libsane-dsseries_1.0.5-1_amd64.deb dates from 2013 and
# declares `Depends: libsane (>= 1.0.17)`.  Debian renamed libsane to
# libsane1 in 2017 and nothing Provides: libsane any more, so dpkg refuses
# to configure it:
#
#     libsane-dsseries depends on libsane (>= 1.0.17); however:
#       Package libsane is not installed.
#
# The driver itself is fine.  libsane-dsseries.so.1.0.17 is a plain SANE
# module (SONAME libsane.so.1) whose only NEEDED entries are libc, libm,
# libpthread and libdl, and it talks to the scanner through /dev/sgN rather
# than the raw USB node.  So the fix is purely to correct the metadata.
#
# What this does
# --------------
#   1. extracts the .deb and rewrites the dependency to libsane1
#   2. builds a version-bumped copy (e.g. 1.0.5-1ubuntu1) so dpkg upgrades
#      and configures any half-installed copy left by the failed dpkg -i
#   3. installs it, reloads udev, and verifies SANE detection
#
# Usage
# -----
#   setup-brother-ds620.sh [path/to/libsane-dsseries_*_amd64.deb]
#
# With no argument the newest ~/Downloads/libsane-dsseries_*.deb is used.
# Obtain the package from support.brother.com -> DS-620 -> Downloads ->
# "Linux (deb)".  The packaged udev rule (50-Brother_DSScanner.rules) sets
# the matching /dev/sgN node to mode 0666, group users.
#
# Tested on Pop!_OS (COSMIC) with SANE 1.2.1, kernel 7.x.

set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}
log() { printf '==> %s\n' "$*"; }

DEB=${1:-}
if [[ -z $DEB ]]; then
	# shellcheck disable=SC2012  # glob of one known filename pattern
	DEB=$(ls -t "$HOME"/Downloads/libsane-dsseries_*_amd64.deb 2>/dev/null | head -n1 || true)
fi
[[ -n $DEB && -f $DEB ]] || die "no package found; pass the path to libsane-dsseries_*_amd64.deb"

command -v dpkg-deb >/dev/null || die "dpkg-deb not found (is this Debian/Ubuntu?)"
command -v scanimage >/dev/null || die "scanimage not found; install sane-utils first"

package=$(dpkg-deb -f "$DEB" Package)
[[ $package == libsane-dsseries ]] || die "$DEB is a '$package' package, expected libsane-dsseries"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

log "extracting $DEB"
dpkg-deb -R "$DEB" "$work/pkg"

old_version=$(dpkg-deb -f "$DEB" Version)
new_version=$old_version
[[ $new_version == *ubuntu* ]] || new_version="${new_version%-*}-1ubuntu1"
arch=$(dpkg-deb -f "$DEB" Architecture)

log "patching control: libsane -> libsane1, version $old_version -> $new_version"
sed -i \
	-e 's/^Depends:.*/Depends: libsane1 (>= 1.0.17)/' \
	-e "s/^Version:.*/Version: $new_version/" \
	"$work/pkg/DEBIAN/control"

out="$work/libsane-dsseries_${new_version}_${arch}.deb"
log "building $out"
dpkg-deb --build --root-owner-group "$work/pkg" "$out" >/dev/null

log "installing via dpkg (sudo)"
sudo dpkg -i "$out"

log "reloading udev rules"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=scsi_generic

grep -qx dsseries /etc/sane.d/dll.conf 2>/dev/null ||
	die "/etc/sane.d/dll.conf has no 'dsseries' entry -- did the postinst run?"

log "probing SANE backends"
if result=$(scanimage -L 2>&1) && grep -qi 'ds-620' <<<"$result"; then
	log "success:"
	printf '%s\n' "$result"
else
	printf '%s\n' "$result" >&2
	cat >&2 <<'EOF'

The scanner was not detected.  Check, in order:

  ls -l /dev/sg*                 # DS-620 should be a mode-0666 Brother sg node
  grep -x dsseries /etc/sane.d/dll.conf
  SANE_DEBUG_DLL=1 scanimage -L # look for "couldn't find backend `dsseries'"

If the sg node is root-only, unplug/replug the scanner or re-run
`sudo udevadm trigger --subsystem-match=scsi_generic`.  If the backend is
simply missing, the postinst did not run: `sudo dpkg --configure libsane-dsseries`.
EOF
	exit 1
fi
