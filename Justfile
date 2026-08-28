# dotfiles — install and manage config files
#
# Fresh machine:  ./scripts/bootstrap.sh   (installs nix + home-manager, then runs `just install`)
# Everything:     just install             (the standard set)
# Pick and mix:   just --list              (optional extras are individually invokable)
# Check:          just doctor
# Tooling:        just machine             (docker, terraform, codex, ...)

set shell := ["bash", "-euo", "pipefail", "-c"]

dots := justfile_directory()

# Developer tooling installers — `just machine` to list, `just machine install-docker` to run
mod machine 'machine-setup.just'

default:
    @just --list

# ---------------------------------------------------------------------------
# The standard set — what a machine gets by default
# ---------------------------------------------------------------------------

# Install the standard set of config files
install: install-nix-config install-home-manager install-git install-nvim install-obsidian
    @echo ""
    @echo "Done. 'just doctor' to verify, 'just --list' for optional extras."

# Link the global nixpkgs config (must be valid, or every nix eval fails)
install-nix-config:
    @echo "nixpkgs config:"
    @just _link "{{dots}}/nix/nixpkgs-config.nix" "$HOME/.config/nixpkgs/config.nix"
    @nix-instantiate --parse "$HOME/.config/nixpkgs/config.nix" >/dev/null \
        && echo "  ✓ parses cleanly"

# Link home.nix and rebuild the home-manager generation
install-home-manager: install-nix-config
    @echo "home-manager:"
    @just _link "{{dots}}/home.nix" "$HOME/.config/home-manager/home.nix"
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

# Point ~/.gitconfig at the shared gitconfig; identity stays machine-local
install-git name="" email="":
    #!/usr/bin/env bash
    set -euo pipefail
    # Usage: just install-git "Jason Mobarak" me@example.com
    echo "git:"

    # ~/.gitconfig is deliberately a real file, never a symlink: it holds
    # per-machine identity (work vs personal email). We only ensure it
    # *includes* the shared config.
    inc="{{dots}}/dotfiles/gitconfig"
    # git stores include.path verbatim and only expands ~ when reading, so a
    # literal string compare would add a duplicate alongside a "~/..." entry.
    found=0
    while IFS= read -r existing; do
        [[ -z "$existing" ]] && continue
        resolved="${existing/#\~\//$HOME/}"
        if [[ "$resolved" == "$inc" ]] \
           || { [[ -e "$resolved" && -e "$inc" ]] \
                && [[ "$(readlink -f "$resolved")" == "$(readlink -f "$inc")" ]]; }; then
            found=1
            echo "  = include.path $existing"
            break
        fi
    done < <(git config --global --get-all include.path 2>/dev/null || true)
    if [[ $found -eq 0 ]]; then
        git config --global --add include.path "$inc"
        echo "  + include.path $inc"
    fi

    # Explicit args win; otherwise only fill in what is not already set.
    [[ -n "{{name}}"  ]] && git config --global user.name  "{{name}}"
    [[ -n "{{email}}" ]] && git config --global user.email "{{email}}"

    for field in user.name user.email; do
        if git config --global --get "$field" >/dev/null 2>&1; then
            echo "  = $field $(git config --global --get "$field")"
        elif [[ -t 0 ]]; then
            read -rp "  $field: " value
            [[ -n "$value" ]] && git config --global "$field" "$value"
        else
            echo "  ! $field unset — run: just install-git \"Your Name\" you@example.com" >&2
        fi
    done

    if ! git config --global --get init.defaultBranch >/dev/null 2>&1; then
        git config --global init.defaultBranch main
        echo "  + init.defaultBranch main"
    fi

# Install the LazyVim starter (if absent) and link the tracked config files
install-nvim:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "nvim:"
    nvim_dir="$HOME/.config/nvim"
    if [[ ! -d "$nvim_dir" ]]; then
        echo "  cloning LazyVim starter"
        git clone --quiet --depth 1 https://github.com/LazyVim/starter "$nvim_dir"
        # Drop the starter's history: this checkout is ours now, and the bits
        # we care about are symlinked back into this repo below.
        rm -rf "$nvim_dir/.git"
    fi
    just _link "{{dots}}/lazyvim/lazyvim.json"            "$nvim_dir/lazyvim.json"
    just _link "{{dots}}/lazyvim/lua/plugins/lazyvim.lua" "$nvim_dir/lua/plugins/lazyvim.lua"

# Install the Obsidian launcher and icons
install-obsidian:
    @echo "obsidian:"
    @just _install-desktop obsidian

# ---------------------------------------------------------------------------
# Optional extras — not run by `just install`, invoke individually
# ---------------------------------------------------------------------------

# Link the zellij config, default layout and zjstatus plugin
install-zellij:
    @echo "zellij:"
    @just _link "{{dots}}/dotfiles/zellij.kdl"            "$HOME/.config/zellij/config.kdl"
    @just _link "{{dots}}/zellij-layouts/default.kdl"     "$HOME/.config/zellij/layouts/default.kdl"
    @just _link "{{dots}}/zjstatus.wasm"                  "$HOME/.config/zellij/zjstatus.wasm"

# Link the tmux config
install-tmux:
    @echo "tmux:"
    @just _link "{{dots}}/dotfiles/tmux.conf" "$HOME/.tmux.conf"

# Link the bundled Nerd Fonts and rebuild the font cache
install-fonts:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "fonts:"
    for font in "{{dots}}"/fonts/*.ttf; do
        just _link "$font" "$HOME/.local/share/fonts/$(basename "$font")"
    done
    fc-cache -f >/dev/null 2>&1 && echo "  ✓ font cache rebuilt" || echo "  ! fc-cache unavailable"

# Link shell completions
install-completions:
    @echo "completions:"
    @just _link "{{dots}}/just.fish" "$HOME/.config/fish/completions/just.fish"

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
        0) bad "include.path missing — run: just install-git" ;;
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
        bad "~/.config/nvim missing — run: just install-nvim"
    fi

    echo "vscode (via home-manager):"
    check_link "{{dots}}/dotfiles/vscode-settings.json" "$HOME/.config/Code/User/settings.json"

    echo "obsidian:"
    check_link "{{dots}}/obsidian.desktop" "$HOME/.local/share/applications/obsidian.desktop"

    echo "optional extras:"
    for pair in \
        "{{dots}}/dotfiles/zellij.kdl:$HOME/.config/zellij/config.kdl:just install-zellij" \
        "{{dots}}/dotfiles/tmux.conf:$HOME/.tmux.conf:just install-tmux" \
        "{{dots}}/just.fish:$HOME/.config/fish/completions/just.fish:just install-completions"; do
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

# Remove the symlinks this Justfile manages (home-manager's own are not touched)
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    for dst in \
        "$HOME/.config/nvim/lazyvim.json" \
        "$HOME/.config/nvim/lua/plugins/lazyvim.lua" \
        "$HOME/.local/share/applications/obsidian.desktop" \
        "$HOME/.config/zellij/config.kdl" \
        "$HOME/.config/zellij/layouts/default.kdl" \
        "$HOME/.config/zellij/zjstatus.wasm" \
        "$HOME/.tmux.conf" \
        "$HOME/.config/fish/completions/just.fish"; do
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "{{dots}}"/* ]]; then
            rm -f "$dst"
            echo "  - $dst"
        fi
    done
    for icon in "$HOME"/.local/share/icons/hicolor/*/apps/obsidian.png; do
        [[ -L "$icon" ]] && rm -f "$icon" && echo "  - $icon"
    done
    for font in "$HOME"/.local/share/fonts/*.ttf; do
        if [[ -L "$font" && "$(readlink -f "$font")" == "{{dots}}"/* ]]; then
            rm -f "$font"
            echo "  - $font"
        fi
    done
    echo ""
    echo "Left alone: ~/.gitconfig (machine-local), ~/.config/nixpkgs/config.nix,"
    echo "~/.config/home-manager/home.nix, and anything home-manager owns."
    echo "To undo home-manager itself: home-manager generations / home-manager remove-generations"

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Idempotently symlink src -> dst, backing up anything real already there
_link src dst:
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{src}}"
    dst="{{dst}}"

    [[ -e "$src" ]] || { echo "  ✗ missing source: $src" >&2; exit 1; }

    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        echo "  = $dst"
        exit 0
    fi

    mkdir -p "$(dirname "$dst")"

    if [[ -e "$dst" || -L "$dst" ]]; then
        backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dst" "$backup"
        echo "  ~ backed up $dst -> $(basename "$backup")"
    fi

    ln -sfn "$src" "$dst"
    echo "  + $dst"

# Install NAME.desktop (and icons/NAME/*.png if present) into the XDG user dirs
_install-desktop name:
    #!/usr/bin/env bash
    set -euo pipefail
    name="{{name}}"
    src="{{dots}}/$name.desktop"
    apps="$HOME/.local/share/applications"

    [[ -f "$src" ]] || { echo "  ✗ no such desktop file: $src" >&2; exit 1; }

    mkdir -p "$apps"
    if grep -q '@DOTFILES@' "$src"; then
        # Contains repo-relative paths, so it has to be generated rather than
        # linked. Re-run this recipe after editing the source file.
        sed "s|@DOTFILES@|{{dots}}|g" "$src" > "$apps/$name.desktop"
        echo "  + $apps/$name.desktop (generated)"
    else
        just _link "$src" "$apps/$name.desktop"
    fi

    if [[ -d "{{dots}}/icons/$name" ]]; then
        for png in "{{dots}}/icons/$name"/*.png; do
            [[ -e "$png" ]] || continue
            size=$(basename "$png" .png)
            just _link "$png" \
                "$HOME/.local/share/icons/hicolor/${size}x${size}/apps/$name.png"
        done
    fi

    update-desktop-database "$apps" 2>/dev/null || true
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
