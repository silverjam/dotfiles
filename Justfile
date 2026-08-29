# dotfiles — install and manage config files
#
# Fresh machine:  ./scripts/bootstrap.sh   (installs nix + home-manager, then runs `just install`)
# Everything:     just install             (nix, home-manager and the config files)
# Check:          just doctor
#
# Two modules underneath:
#   just dotfiles   link this repo's config files (git, nvim, zellij, fonts, ...)
#   just machine    install developer tooling (docker, terraform, apt bundles, ...)

set shell := ["bash", "-euo", "pipefail", "-c"]

dots := justfile_directory()
link := justfile_directory() / "scripts/link.sh"

# Link this repo's config files — `just dotfiles` to list
mod dotfiles 'dotfiles.just'

# Install developer tooling — `just machine` to list
mod machine 'machine.just'

default:
    @just --list

help: default

# ---------------------------------------------------------------------------
# Provisioning. These live here rather than in a module because `install`
# depends on them, and just cannot express dependencies across modules.
# ---------------------------------------------------------------------------

# Install everything: nix config, home-manager, then the config files
install: install-nix-config install-home-manager
    @just dotfiles install
    @echo ""
    @echo "Done. 'just doctor' to verify."
    @echo "Optional extras: just dotfiles    Developer tooling: just machine"

# Link the global nixpkgs config (must be valid, or every nix eval fails)
install-nix-config:
    @echo "nixpkgs config:"
    @{{link}} "{{dots}}/nix/nixpkgs-config.nix" "$HOME/.config/nixpkgs/config.nix"
    @nix-instantiate --parse "$HOME/.config/nixpkgs/config.nix" >/dev/null \
        && echo "  ✓ parses cleanly"

# Link home.nix and rebuild the home-manager generation
install-home-manager: install-nix-config
    @echo "home-manager:"
    @{{link}} "{{dots}}/home.nix" "$HOME/.config/home-manager/home.nix"
    @just switch

# Rebuild the home-manager generation
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    # A non-login shell may not have nix on PATH or a usable NIX_PATH.
    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    # -b bak: back up pre-existing unmanaged files rather than failing activation.
    home-manager switch -b bak

# Remove the symlinks the dotfiles module manages
uninstall:
    @just dotfiles uninstall

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

# Check that everything is installed and pointing where it should
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0

    if [[ -t 1 ]]; then
        R=$'\033[1;31m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; D=$'\033[0;90m'; N=$'\033[0m'
    else
        R=''; G=''; Y=''; D=''; N=''
    fi

    check_link() {
        local src="$1" dst="$2"
        if [[ ! -e "$dst" && ! -L "$dst" ]]; then
            printf '  %s✗%s %-46s missing\n' "$R" "$N" "$dst"; fail=1
        elif [[ ! -L "$dst" ]]; then
            printf '  %s⚠%s %-46s real file, not a link\n' "$Y" "$N" "$dst"; fail=1
        elif [[ "$(readlink -f "$dst")" != "$(readlink -f "$src")" ]]; then
            printf '  %s⚠%s %-46s -> %s\n' "$Y" "$N" "$dst" "$(readlink "$dst")"; fail=1
        else
            printf '  %s✓%s %-46s\n' "$G" "$N" "$dst"
        fi
    }

    ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
    bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$1"; fail=1; }
    note() { printf '  %s⚠%s %s\n' "$Y" "$N" "$1"; }

    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi

    echo "nix:"
    command -v nix >/dev/null && ok "nix $(nix --version | awk '{print $3}')" || bad "nix not on PATH"
    systemctl is-active --quiet nix-daemon.service \
        && ok "nix-daemon running" || note "nix-daemon not active"
    # NIX_PATH being empty is fine: nix has a compiled-in default nix-path that
    # covers ~/.nix-defexpr/channels and root's channels. Only resolution matters.
    if nix-instantiate --eval -E '<nixpkgs>' >/dev/null 2>&1; then
        ok "<nixpkgs> resolves"
    else
        bad "<nixpkgs> does not resolve — check channels"
    fi

    echo "channels:"
    sudo -n nix-channel --list 2>/dev/null | grep -q '^nixpkgs ' \
        && ok "root: nixpkgs" || note "root: nixpkgs unverified (needs sudo)"
    nix-channel --list 2>/dev/null | grep -q '^home-manager ' \
        && ok "user: home-manager" || bad "user: home-manager channel missing"

    echo "nixpkgs config:"
    check_link "{{dots}}/nix/nixpkgs-config.nix" "$HOME/.config/nixpkgs/config.nix"
    if [[ -e "$HOME/.config/nixpkgs/config.nix" ]]; then
        nix-instantiate --parse "$HOME/.config/nixpkgs/config.nix" >/dev/null 2>&1 \
            && ok "config.nix parses" || bad "config.nix does NOT parse — breaks every nix eval"
    fi

    echo "home-manager:"
    check_link "{{dots}}/home.nix" "$HOME/.config/home-manager/home.nix"
    command -v home-manager >/dev/null && ok "home-manager installed" || bad "home-manager not on PATH"

    echo "git:"
    inc="{{dots}}/dotfiles/gitconfig"
    matches=0
    while IFS= read -r existing; do
        [[ -z "$existing" ]] && continue
        resolved="${existing/#\~\//$HOME/}"
        if [[ "$resolved" == "$inc" ]] \
           || { [[ -e "$resolved" && -e "$inc" ]] \
                && [[ "$(readlink -f "$resolved")" == "$(readlink -f "$inc")" ]]; }; then
            matches=$((matches + 1))
        fi
    done < <(git config --global --get-all include.path 2>/dev/null || true)
    case $matches in
        0) bad "include.path missing — run: just dotfiles install-git" ;;
        1) ok "include.path set" ;;
        *) note "include.path listed $matches times — remove the duplicates" ;;
    esac
    for field in user.name user.email; do
        value=$(git config --global --get "$field" 2>/dev/null || true)
        [[ -n "$value" ]] && ok "$field $value" || bad "$field unset"
    done

    echo "nvim:"
    if [[ -d "$HOME/.config/nvim" ]]; then
        check_link "{{dots}}/lazyvim/lazyvim.json"            "$HOME/.config/nvim/lazyvim.json"
        check_link "{{dots}}/lazyvim/lua/plugins/lazyvim.lua" "$HOME/.config/nvim/lua/plugins/lazyvim.lua"
    else
        bad "~/.config/nvim missing — run: just dotfiles install-nvim"
    fi

    echo "vscode (via home-manager):"
    check_link "{{dots}}/dotfiles/vscode-settings.json" "$HOME/.config/Code/User/settings.json"

    echo "obsidian:"
    check_link "{{dots}}/obsidian.desktop" "$HOME/.local/share/applications/obsidian.desktop"

    echo "optional extras:"
    for pair in \
        "{{dots}}/dotfiles/zellij.kdl:$HOME/.config/zellij/config.kdl:just dotfiles install-zellij" \
        "{{dots}}/dotfiles/tmux.conf:$HOME/.tmux.conf:just dotfiles install-tmux" \
        "{{dots}}/just.fish:$HOME/.config/fish/completions/just.fish:just dotfiles install-completions"; do
        IFS=: read -r src dst recipe <<<"$pair"
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            printf '  %s✓%s %-46s\n' "$G" "$N" "$dst"
        else
            printf '  %s·%s %-46s not installed (%s)\n' "$D" "$N" "$dst" "$recipe"
        fi
    done

    echo ""
    if [[ $fail -eq 0 ]]; then
        printf '%sAll good.%s\n' "$G" "$N"
    else
        printf '%sProblems found.%s See above.\n' "$R" "$N"
    fi
    exit $fail
