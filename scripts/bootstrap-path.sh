#!/bin/sh
#
# Ensure ~/.local/bin is on PATH for bash, zsh and fish.
#
#   scripts/bootstrap-path.sh
#
# Idempotent, and a no-op for any shell that already handles it (Ubuntu's stock
# ~/.profile and ~/.bashrc usually do). Writes a marker-delimited block so a
# re-run updates in place rather than appending a second copy.
#
# Plain POSIX sh: this runs before nix, just or anything else exists.
#
set -eu

BIN_DIR="$HOME/.local/bin"
BEGIN='# >>> dotfiles: ~/.local/bin on PATH >>>'
END='# <<< dotfiles: ~/.local/bin on PATH <<<'

info() { printf '    %s\n' "$*"; }

mkdir -p "$BIN_DIR"

# --- POSIX shells (bash, zsh) ----------------------------------------------
# Guarded so repeated sourcing cannot stack duplicate entries.
posix_snippet() {
    cat <<'SNIPPET'
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
SNIPPET
}

install_posix() {
    file="$1"
    name="$2"

    if [ -f "$file" ] && grep -q "$BEGIN" "$file"; then
        info "$name: already managed ($file)"
        return
    fi

    # Ubuntu's stock ~/.profile and ~/.bashrc already do this. Don't add a
    # second mechanism just to own it.
    if [ -f "$file" ] && grep -q '\.local/bin' "$file"; then
        info "$name: already handled by $file, leaving alone"
        return
    fi

    [ -f "$file" ] || : > "$file"
    {
        printf '\n%s\n' "$BEGIN"
        posix_snippet
        printf '%s\n' "$END"
    } >> "$file"
    info "$name: added block to $file"
}

install_posix "$HOME/.bashrc" bash
install_posix "$HOME/.zshrc"  zsh

# --- fish -------------------------------------------------------------------
# conf.d is fish's own extension point and is sourced before config.fish, so
# anything config.fish prepends later still wins. A plain file here is safe
# alongside home-manager, which only cleans up links it created itself.
fish_conf="$HOME/.config/fish/conf.d/00-local-bin.fish"
mkdir -p "$(dirname "$fish_conf")"
cat > "$fish_conf" <<'SNIPPET'
# Managed by dotfiles/scripts/bootstrap-path.sh
if test -d $HOME/.local/bin
    if not contains $HOME/.local/bin $PATH
        set -gx PATH $HOME/.local/bin $PATH
    end
end
SNIPPET
info "fish: wrote $fish_conf"

info "open a new shell, or add $BIN_DIR to PATH by hand for this one"
