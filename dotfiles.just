# Dotfiles: linking this repo's config files into place.
#
# Loaded as a module, so these are invoked with a `dotfiles` prefix:
#
#     just dotfiles                 # list them
#     just dotfiles install-nvim    # run one
#
# (`just --list dotfiles` also works; `just dotfiles --list` does not.)
#
# The nix and home-manager recipes deliberately live in the top-level Justfile
# instead: `just install` depends on them, and just cannot express dependencies
# across modules.

set shell := ["bash", "-euo", "pipefail", "-c"]

dots := justfile_directory()
link := justfile_directory() / "scripts/link.sh"

# List the dotfiles recipes
default:
    @just --list dotfiles

# Install the standard set of config files
install: install-git install-nvim install-obsidian

# Point ~/.gitconfig at the shared gitconfig; identity stays machine-local
install-git name="" email="":
    #!/usr/bin/env bash
    set -euo pipefail
    # Usage: just dotfiles install-git "Jason Mobarak" me@example.com
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
            echo "  ! $field unset — run: just dotfiles install-git \"Your Name\" you@example.com" >&2
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
    {{link}} "{{dots}}/lazyvim/lazyvim.json"            "$nvim_dir/lazyvim.json"
    {{link}} "{{dots}}/lazyvim/lua/plugins/lazyvim.lua" "$nvim_dir/lua/plugins/lazyvim.lua"

# Install the Obsidian launcher and icons
install-obsidian:
    @echo "obsidian:"
    @just dotfiles _install_desktop obsidian

# ---------------------------------------------------------------------------
# Optional extras — not run by `just dotfiles install`, invoke individually
# ---------------------------------------------------------------------------

# Link the zellij config, default layout and zjstatus plugin
install-zellij:
    @echo "zellij:"
    @{{link}} "{{dots}}/dotfiles/zellij.kdl"        "$HOME/.config/zellij/config.kdl"
    @{{link}} "{{dots}}/zellij-layouts/default.kdl" "$HOME/.config/zellij/layouts/default.kdl"
    @{{link}} "{{dots}}/zjstatus.wasm"              "$HOME/.config/zellij/zjstatus.wasm"

# Updates the vendored zjstatus.wasm in place. ~/.config/zellij/zjstatus.wasm
# is a symlink to it, so there is nothing to re-link afterwards — but a running
# zellij needs restarting to pick the new plugin up.

# Download the latest zjstatus plugin into this repo
update-zjstatus force="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "zjstatus:"

    repo="dj95/zjstatus"
    asset="zjstatus.wasm"
    dest="{{dots}}/zjstatus.wasm"
    version_file="{{dots}}/zjstatus.version"

    command -v jq >/dev/null 2>&1 || { sudo apt-get update && sudo apt-get install -y jq; }

    release="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")" \
        || { echo "  ✗ could not reach GitHub" >&2; exit 1; }

    tag="$(jq -r '.tag_name' <<<"$release")"
    [[ -n "$tag" && "$tag" != "null" ]] || { echo "  ✗ could not resolve latest tag" >&2; exit 1; }

    # The API publishes a digest per asset, so there is no separate checksum
    # file to fetch — same approach as the machine module's release installers.
    expected="$(jq -r --arg n "$asset" \
        '.assets[] | select(.name == $n) | .digest' <<<"$release" | sed 's/^sha256://')"
    [[ -n "$expected" ]] || { echo "  ✗ no digest published for $asset" >&2; exit 1; }

    current="$(cat "$version_file" 2>/dev/null || echo unknown)"
    if [[ -z "{{force}}" && -f "$dest" ]]; then
        # Trust the file itself over the version marker: the marker can be
        # missing or stale, the hash cannot.
        if [[ "$(sha256sum "$dest" | awk '{print $1}')" == "$expected" ]]; then
            echo "  = already at $tag"
            printf '%s\n' "$tag" > "$version_file"
            exit 0
        fi
    fi

    echo "  current: $current, latest: $tag"

    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    curl -fsSL -o "$workdir/$asset" \
        "https://github.com/$repo/releases/download/$tag/$asset" \
        || { echo "  ✗ download failed" >&2; exit 1; }

    actual="$(sha256sum "$workdir/$asset" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        echo "  ✗ checksum mismatch for $asset" >&2
        echo "      expected: $expected" >&2
        echo "      actual:   $actual" >&2
        exit 1
    fi
    echo "  ✓ verified sha256: $actual"

    mv "$workdir/$asset" "$dest"
    printf '%s\n' "$tag" > "$version_file"
    echo "  + updated to $tag ($(du -h "$dest" | cut -f1))"
    echo "  restart zellij to pick up the new plugin"

# Link the tmux config
install-tmux:
    @echo "tmux:"
    @{{link}} "{{dots}}/dotfiles/tmux.conf" "$HOME/.tmux.conf"

# Link the bundled Nerd Fonts and rebuild the font cache
install-fonts:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "fonts:"
    for font in "{{dots}}"/fonts/*.ttf; do
        {{link}} "$font" "$HOME/.local/share/fonts/$(basename "$font")"
    done
    fc-cache -f >/dev/null 2>&1 && echo "  ✓ font cache rebuilt" || echo "  ! fc-cache unavailable"

# Link shell completions
install-completions:
    @echo "completions:"
    @{{link}} "{{dots}}/just.fish" "$HOME/.config/fish/completions/just.fish"

# Remove the symlinks this module manages (home-manager's own are not touched)
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

# Install NAME.desktop (and icons/NAME/*.png if present) into the XDG user dirs
[private]
_install_desktop name:
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
        {{link}} "$src" "$apps/$name.desktop"
    fi

    if [[ -d "{{dots}}/icons/$name" ]]; then
        for png in "{{dots}}/icons/$name"/*.png; do
            [[ -e "$png" ]] || continue
            size=$(basename "$png" .png)
            {{link}} "$png" \
                "$HOME/.local/share/icons/hicolor/${size}x${size}/apps/$name.png"
        done
    fi

    update-desktop-database "$apps" 2>/dev/null || true
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
