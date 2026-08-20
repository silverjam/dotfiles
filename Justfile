default:
    @just --list

# Symlink the Obsidian .desktop launcher and icon into the standard XDG user dirs
install-obsidian:
    mkdir -p ~/.local/share/applications
    mkdir -p ~/.local/share/icons/hicolor/scalable/apps
    ln -sf {{justfile_directory()}}/obsidian.desktop ~/.local/share/applications/obsidian.desktop
    ln -sf {{justfile_directory()}}/obsidian.svg ~/.local/share/icons/hicolor/scalable/apps/obsidian.svg
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null || true
    @echo "Obsidian launcher installed — it should now appear in your application menu."
