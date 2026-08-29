#!/bin/sh
#
# Install the `just` standalone binary from GitHub, so the Justfile recipes can
# run before nix and home-manager exist.
#
#   scripts/bootstrap-just.sh            # install if not already present
#   scripts/bootstrap-just.sh --force    # reinstall even if present
#
# Linux x86_64 only, by design: this is a bootstrap shim, not a general
# installer. Once home-manager is in place, nix provides just and this copy
# should go away -- scripts/bootstrap.sh removes it automatically.
#
# Deliberately avoids jq: on a bare machine nothing is installed yet. Needs
# only curl, tar and sha256sum. The release is checksum-verified against the
# published SHA256SUMS; nothing is piped into a shell.
#
set -eu

REPO='casey/just'
TARGET='x86_64-unknown-linux-musl'
BIN_DIR="${JUST_BIN_DIR:-$HOME/.local/bin}"
HERE=$(cd "$(dirname "$0")" && pwd)

force=0
[ "${1:-}" = '--force' ] && force=1

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗ \033[0m%s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
say "PATH"

# Pointless to drop a binary in ~/.local/bin if the shell cannot find it.
"$HERE/bootstrap-path.sh"

# --------------------------------------------------------------------------
say "just"

[ "$(uname -s)" = 'Linux' ] || die "Linux only (found $(uname -s))"
[ "$(uname -m)" = 'x86_64' ] || die "x86_64 only (found $(uname -m))"

if [ "$force" -eq 0 ] && command -v just >/dev/null 2>&1; then
    info "already on PATH: $(command -v just) ($(just --version))"
    info "re-run with --force to install the standalone binary anyway"
    exit 0
fi

for cmd in curl tar sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
done

# Resolve the latest tag by following the /releases/latest redirect, rather
# than parsing the API with jq.
latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest") \
    || die "could not reach GitHub to resolve the latest release"
tag=${latest_url##*/}
[ -n "$tag" ] && [ "$tag" != 'latest' ] || die "could not resolve the latest release tag"
info "latest release is $tag"

asset="just-${tag}-${TARGET}.tar.gz"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

info "downloading $asset"
curl -fsSL -o "$workdir/$asset" \
    "https://github.com/$REPO/releases/download/$tag/$asset" \
    || die "download failed"
curl -fsSL -o "$workdir/SHA256SUMS" \
    "https://github.com/$REPO/releases/download/$tag/SHA256SUMS" \
    || die "could not fetch SHA256SUMS"

# --ignore-missing so the one asset we pulled is checked and the rest of the
# manifest is skipped, rather than failing on every file we did not download.
( cd "$workdir" && sha256sum --ignore-missing -c SHA256SUMS >/dev/null 2>&1 ) \
    || die "checksum mismatch for $asset"
info "verified sha256: $(sha256sum "$workdir/$asset" | awk '{print $1}')"

tar -xzf "$workdir/$asset" -C "$workdir" just
install -Dm755 "$workdir/just" "$BIN_DIR/just"

say "Done"
info "installed $("$BIN_DIR/just" --version) to $BIN_DIR/just"
