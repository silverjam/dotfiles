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
#   - upstream nix, multi-user (daemon) mode      ) both via
#   - root channel:  nixpkgs-unstable             ) scripts/install-nix.sh,
#   - user channel:  home-manager master          ) shared with `just machine
#                    (master pairs with unstable nixpkgs)   install-nix`
#   - standalone home-manager driven by ./home.nix
#
set -eu

DOTFILES=$(cd "$(dirname "$0")/.." && pwd)
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

if ! command -v git >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        info "installing git"
        sudo apt-get update -qq
        sudo apt-get install -y git
    else
        die "git not found (install it and re-run)"
    fi
fi

# ---------------------------------------------------------------- stage 2 ---
# Nix itself plus the channels, shared with `just machine install-nix` so the
# two cannot drift. Handles its own curl/xz dependencies and is idempotent.
say "Nix and channels"

"$DOTFILES/scripts/install-nix.sh"

# ---------------------------------------------------------------- stage 3 ---
# install-nix.sh sourced the profile in its own shell, not ours. Do it again
# here so the remaining stages can call nix-instantiate and home-manager.
#
# (This does not set NIX_PATH, and does not need to: nix has a compiled-in
# default nix-path covering ~/.nix-defexpr/channels and root's channels, which
# is what makes <nixpkgs> resolve in stage 5.)
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

# ---------------------------------------------------------------- stage 5 ---
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

# ---------------------------------------------------------------- stage 6 ---
say "Config files"

if command -v just >/dev/null 2>&1; then
    exec just --justfile "$DOTFILES/Justfile" --working-directory "$DOTFILES" install
else
    warn "just not on PATH after home-manager switch"
    warn "open a new shell and run: cd $DOTFILES && just install"
fi
