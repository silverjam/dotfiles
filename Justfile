default:
    @just --list

# Symlink the Obsidian .desktop launcher and icon into the standard XDG user dirs
install-obsidian:
    mkdir -p ~/.local/share/applications
    ln -sf {{justfile_directory()}}/obsidian.desktop ~/.local/share/applications/obsidian.desktop
    for size in 16 24 32 48 64 128 256 512; do \
        mkdir -p ~/.local/share/icons/hicolor/$size"x"$size/apps; \
        ln -sf {{justfile_directory()}}/icons/obsidian/$size.png ~/.local/share/icons/hicolor/$size"x"$size/apps/obsidian.png; \
    done
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null || true
    @echo "Obsidian launcher installed — it should now appear in your application menu."
