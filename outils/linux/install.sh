#!/bin/sh
# Install "Lava Rescue!" (Sauve les Animaux !) for this user, on
# Bazzite, SteamOS or any Linux: no root needed, nothing outside your home.
#
#   sh install.sh               install (or update), add to the menu (and Steam)
#   sh install.sh --uninstall   remove it (your records are kept)
#   sh install.sh --steam-art   give Steam the game's pictures again (after
#                               adding it to Steam by hand)
#
# Installs into ~/.local/share/lava-rescue, unpacks LÖVE there once (fast
# start, no FUSE needed), and adds "Lava Rescue!" to the applications menu.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/lava-rescue"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP="$APPS/lava-rescue.desktop"
SAVES="${XDG_DATA_HOME:-$HOME/.local/share}/love/sauve-les-animaux"
ICON="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps/lava-rescue.png"

# Steam's library pictures (cover, banner, logo): Steam must know the game
steam_art() {
    if ! command -v python3 >/dev/null 2>&1; then return; fi
    python3 "$DEST/steam-art.py" "$DEST/steam" "LavaRescue.sh" "Lava Rescue" && \
        echo "    (redémarrez Steam pour les voir / restart Steam to see them)" && return
    echo "Steam : quand le jeu est ajouté à Steam, relancez / once the game is in Steam, run:"
    echo "        sh \"$DEST/install.sh\" --steam-art   (puis redémarrez Steam / then restart Steam)"
}
if [ "$1" = "--steam-art" ]; then steam_art; exit 0; fi

if [ "$1" = "--uninstall" ]; then
    rm -rf "$DEST" "$DESKTOP" "$ICON"
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
    echo "Lava Rescue! est désinstallé / is uninstalled."
    echo "Les records restent ici / your records are kept here: $SAVES"
    echo "(Dans Steam, supprimez le raccourci à la main / in Steam, remove the shortcut by hand.)"
    exit 0
fi

# 1) the files
mkdir -p "$DEST"
if [ "$HERE" != "$DEST" ]; then
    for f in LavaRescue.sh lava-rescue.love love.AppImage icone.png LICENSE install.sh steam-art.py LISEZ-MOI-BAZZITE.txt; do
        [ -f "$HERE/$f" ] && cp "$HERE/$f" "$DEST/"
    done
    [ -d "$HERE/steam" ] && rm -rf "$DEST/steam" && cp -R "$HERE/steam" "$DEST/steam"
fi
chmod +x "$DEST/LavaRescue.sh" "$DEST/love.AppImage" "$DEST/install.sh"

# 2) unpack LÖVE once: the game then starts fast and doesn't need FUSE
#    (if this fails, the launcher still works: the AppImage unpacks itself)
#    plan B: unsquashfs on the AppImage's filesystem, which starts right
#    after its small runtime (an ELF file: the end of its section headers,
#    computed like the AppImage runtime does)
rm -rf "$DEST/love" "$DEST/squashfs-root"
if (cd "$DEST" && ./love.AppImage --appimage-extract >/dev/null 2>&1) && [ -x "$DEST/squashfs-root/AppRun" ]; then
    mv "$DEST/squashfs-root" "$DEST/love"
    echo "OK  LÖVE"
else
    rm -rf "$DEST/squashfs-root"
    F="$DEST/love.AppImage"
    SHOFF=$(od -An -t u8 -j 40 -N 8 "$F" 2>/dev/null | tr -d ' ')
    SHENT=$(od -An -t u2 -j 58 -N 2 "$F" 2>/dev/null | tr -d ' ')
    SHNUM=$(od -An -t u2 -j 60 -N 2 "$F" 2>/dev/null | tr -d ' ')
    OFFSET=""
    [ -n "$SHOFF" ] && [ -n "$SHENT" ] && [ -n "$SHNUM" ] && OFFSET=$((SHOFF + SHENT * SHNUM))
    if [ -n "$OFFSET" ] && command -v unsquashfs >/dev/null 2>&1 \
        && unsquashfs -q -n -o "$OFFSET" -d "$DEST/love" "$DEST/love.AppImage" >/dev/null 2>&1 \
        && [ -x "$DEST/love/AppRun" ]; then
        echo "OK  LÖVE (unsquashfs)"
    else
        rm -rf "$DEST/love"
        echo "(LÖVE n'a pas pu être décompressé : le jeu le fera à chaque lancement / LÖVE will unpack at each start)"
    fi
fi

# 3) the menu entry, with the icon (in the icon theme: every menu and launcher
#    finds it there, also Steam when the game is added from the menu)
mkdir -p "$APPS" "$(dirname "$ICON")"
cp "$DEST/icone.png" "$ICON"
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -q -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" >/dev/null 2>&1 || true
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Lava Rescue!
Name[fr]=Sauve les Animaux !
Comment=The volcano wakes up: save the forest animals! 1 or 2 players, with game controllers.
Comment[fr]=Le volcan se réveille : sauve les animaux de la forêt ! 1 ou 2 joueurs, avec des manettes.
Exec="$DEST/LavaRescue.sh"
Path=$DEST
Icon=lava-rescue
Terminal=false
Categories=Game;ArcadeGame;KidsGame;
StartupNotify=false
EOF
chmod +x "$DESKTOP"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "OK  menu: Lava Rescue!"

# 4) Steam: on SteamOS (and Bazzite, if it has it) the game can be added to
#    Steam directly (Steam must be running, in desktop mode)
if command -v steamos-add-to-steam >/dev/null 2>&1; then
    if steamos-add-to-steam "$DESKTOP" >/dev/null 2>&1; then
        echo "OK  Steam (redémarrez Steam si le jeu n'apparaît pas / restart Steam if it doesn't show)"
    else
        echo "Steam : ajoutez le jeu à la main (voir LISEZ-MOI) / add it by hand (see LISEZ-MOI)"
    fi
else
    echo "Steam : Ajouter un jeu > Ajouter un jeu non-Steam > Lava Rescue!"
    echo "        Add a Game > Add a Non-Steam Game > Lava Rescue!"
fi
steam_art
echo "Installé dans / installed in: $DEST"
