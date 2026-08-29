#!/bin/sh
#
# Install nix on top of an existing Linux system, in multi-user (daemon) mode,
# and add the channels this repo expects.
#
#   scripts/install-nix.sh
#
# Plain POSIX sh with no dependencies beyond curl and xz, because this runs
# before anything nix provides exists. Idempotent: safe to re-run.
#
# Shared by scripts/bootstrap.sh and `just machine install-nix`, so there is
# one implementation rather than two that drift.
#
# Needs sudo: a multi-user install creates /nix, 32 nixbld users, a systemd
# unit and the shell integration snippets in /etc.
#
set -eu

NIXPKGS_CHANNEL='https://nixos.org/channels/nixpkgs-unstable'
HM_CHANNEL='https://github.com/nix-community/home-manager/archive/master.tar.gz'
NIX_PROFILE_SCRIPT='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗ \033[0m%s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "this installer only targets Linux (found $(uname -s))"

# --------------------------------------------------------------------------
say "Dependencies"

missing=''
for cmd in curl xz; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done

if [ -n "$missing" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        info "installing:$missing"
        sudo apt-get update -qq
        sudo apt-get install -y curl xz-utils
    else
        die "missing required commands:$missing (install them and re-run)"
    fi
else
    info "curl and xz present"
fi

# --------------------------------------------------------------------------
say "Nix"

if [ -e /nix/var/nix/profiles/default ]; then
    info "already installed, skipping"
else
    info "installing upstream nix in multi-user (daemon) mode"
    info "this needs sudo and will create /nix, 32 nixbld users and a systemd unit"
    curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh
    sh /tmp/nix-install.sh --daemon
    rm -f /tmp/nix-install.sh
fi

# The shell that ran the installer does not have nix on PATH -- the installer
# only writes the integration snippets for *future* shells.
[ -e "$NIX_PROFILE_SCRIPT" ] || die "$NIX_PROFILE_SCRIPT not found -- did the install fail?"
# shellcheck disable=SC1090
. "$NIX_PROFILE_SCRIPT"

command -v nix-channel >/dev/null 2>&1 || die "nix-channel not on PATH after sourcing profile"
info "nix $(nix --version | awk '{print $3}') on PATH"

# --------------------------------------------------------------------------
say "Channels"

# <nixpkgs> resolves through *root's* channel, not the user's. home-manager
# master tracks nixpkgs unstable, so pin that pairing explicitly rather than
# trusting whatever default the installer picked.
if sudo nix-channel --list | grep -q '^nixpkgs '; then
    info "root: nixpkgs already present"
else
    info "root: adding nixpkgs-unstable"
    sudo nix-channel --add "$NIXPKGS_CHANNEL" nixpkgs
fi
info "root: updating"
sudo nix-channel --update

if nix-channel --list | grep -q '^home-manager '; then
    info "user: home-manager already present"
else
    info "user: adding home-manager master"
    nix-channel --add "$HM_CHANNEL" home-manager
fi
info "user: updating"
nix-channel --update

say "Done"
info "open a new shell, or source $NIX_PROFILE_SCRIPT, to get nix on PATH"
