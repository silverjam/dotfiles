#!/bin/sh
#
# Bootstrap a fresh machine from nothing to a fully configured one.
#
#   git clone <this repo> ~/dev/dotfiles && ~/dev/dotfiles/scripts/bootstrap.sh
#
# Plain POSIX sh with no dependencies: this has to run before nix, just, fish
# or anything else from home-manager exists. Every stage is idempotent and
# guarded, so a partial run can simply be re-run.
#
# Reproduces the setup this repo expects:
#   - upstream nix, multi-user (daemon) mode
#   - root channel:  nixpkgs-unstable
#   - user channel:  home-manager master   (master pairs with unstable nixpkgs)
#   - standalone home-manager driven by ./home.nix
#
set -eu

DOTFILES=$(cd "$(dirname "$0")/.." && pwd)
HM_CHANNEL='https://github.com/nix-community/home-manager/archive/master.tar.gz'
NIXPKGS_CHANNEL='https://nixos.org/channels/nixpkgs-unstable'
NIX_PROFILE_SCRIPT='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m%s\n' "$*" >&2; }
die()  { printf '\033[1;31m  ✗ \033[0m%s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- stage 1 ---
say "Preflight"

[ -d "$DOTFILES/.git" ] || warn "$DOTFILES does not look like a git checkout"
info "dotfiles: $DOTFILES"

if [ "$(uname -s)" != "Linux" ]; then
    die "this bootstrap only targets Linux (found $(uname -s))"
fi

# The nix installer needs curl and xz; the rest of the setup needs git.
missing=''
for cmd in curl xz git; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done

if [ -n "$missing" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        info "installing:$missing"
        sudo apt-get update -qq
        sudo apt-get install -y curl xz-utils git
    else
        die "missing required commands:$missing (install them and re-run)"
    fi
else
    info "curl, xz, git present"
fi

# ---------------------------------------------------------------- stage 2 ---
say "Nix"

if [ -e /nix/var/nix/profiles/default ]; then
    info "already installed, skipping"
else
    info "installing upstream nix in multi-user (daemon) mode"
    info "this needs sudo and will create /nix, 32 nixbld users and a systemd unit"
    # --daemon is the multi-user install. It also writes the shell integration
    # snippets (/etc/profile.d/nix.sh, /etc/fish/conf.d/nix.fish) that put nix
    # on PATH for future shells.
    curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh
    sh /tmp/nix-install.sh --daemon
    rm -f /tmp/nix-install.sh
fi

# ---------------------------------------------------------------- stage 3 ---
# The shell that ran the installer does not have nix on PATH -- the installer
# only writes the integration snippets for *future* shells. Source it here so
# the remaining stages can call nix-channel and home-manager.
#
# (This does not set NIX_PATH, and does not need to: nix has a compiled-in
# default nix-path covering ~/.nix-defexpr/channels and root's channels, which
# is what makes <nixpkgs> resolve in stage 6.)
say "Loading nix into this shell"

if [ -e "$NIX_PROFILE_SCRIPT" ]; then
    # shellcheck disable=SC1090
    . "$NIX_PROFILE_SCRIPT"
else
    die "$NIX_PROFILE_SCRIPT not found -- did the nix install fail?"
fi

command -v nix-channel >/dev/null 2>&1 || die "nix-channel not on PATH after sourcing profile"
info "nix $(nix --version | awk '{print $3}') on PATH"

# ---------------------------------------------------------------- stage 4 ---
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

# ---------------------------------------------------------------- stage 5 ---
# Must happen before any home-manager evaluation: nixpkgs reads this file every
# time, and an invalid one fails the whole build.
say "nixpkgs config"

mkdir -p "$HOME/.config/nixpkgs"
target="$HOME/.config/nixpkgs/config.nix"
if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    info "backed up pre-existing config.nix"
fi
ln -sfn "$DOTFILES/nix/nixpkgs-config.nix" "$target"
info "linked $target"

if ! nix-instantiate --parse "$target" >/dev/null 2>&1; then
    die "$target does not parse -- fix it before continuing"
fi
info "parses cleanly"

# ---------------------------------------------------------------- stage 6 ---
say "home-manager"

mkdir -p "$HOME/.config/home-manager"
target="$HOME/.config/home-manager/home.nix"
if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    info "backed up pre-existing home.nix"
fi
ln -sfn "$DOTFILES/home.nix" "$target"
info "linked $target"

if command -v home-manager >/dev/null 2>&1; then
    info "already installed"
else
    info "installing"
    nix-shell '<home-manager>' -A install
fi

info "switching"
# -b bak so pre-existing unmanaged files are backed up instead of failing the
# whole activation.
home-manager switch -b bak

# ---------------------------------------------------------------- stage 7 ---
say "Config files"

if command -v just >/dev/null 2>&1; then
    exec just --justfile "$DOTFILES/Justfile" --working-directory "$DOTFILES" install
else
    warn "just not on PATH after home-manager switch"
    warn "open a new shell and run: cd $DOTFILES && just install"
fi
