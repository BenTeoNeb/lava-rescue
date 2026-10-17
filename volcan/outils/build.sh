#!/bin/sh
# Build "Lava Rescue!" for sharing:
#   dist/lava-rescue.love        the game itself (needs LÖVE 11.5)
#   dist/LavaRescue-linux.tar.gz  Linux / Bazzite / Steam Deck, nothing to install
#   dist/LavaRescue-windows.zip   Windows, double-click LavaRescue.exe
#   dist/LavaRescue-mac.zip       Mac, double-click the app (made from the LÖVE
#                                      app installed in /Applications, if there is one)
#
# Run from anywhere:  sh volcan/outils/build.sh
# The official LÖVE 11.5 builds are downloaded once into .cache/love/.
set -e

HERE="$(cd "$(dirname "$0")/../.." && pwd)"     # the "games" folder
GAME="$HERE/volcan"
DIST="$HERE/dist"
CACHE="$HERE/.cache/love"
NAME="LavaRescue"
LOVE_URL="https://github.com/love2d/love/releases/download/11.5"

mkdir -p "$DIST" "$CACHE"
for f in love-11.5-x86_64.AppImage love-11.5-win64.zip; do
    [ -f "$CACHE/$f" ] || curl -sSL -o "$CACHE/$f" "$LOVE_URL/$f"
done

# 1) the .love: only what the game needs (code + images)
rm -f "$DIST/lava-rescue.love"
# (journal.lua is left out: the game log is for us, not for the players;
#  without it the game simply logs nothing)
(cd "$GAME" && zip -q -9 -r "$DIST/lava-rescue.love" ./*.lua images -x "images/_*" "*.DS_Store" "./journal.lua")
zip -q -j "$DIST/lava-rescue.love" "$HERE/LICENSE"      # the license travels with the game
echo "OK  dist/lava-rescue.love ($(du -h "$DIST/lava-rescue.love" | cut -f1))"

# 2) Linux: the LÖVE AppImage + the game + a launcher script
L="$DIST/$NAME-linux"
rm -rf "$L" && mkdir -p "$L"
cp "$CACHE/love-11.5-x86_64.AppImage" "$L/love.AppImage"
cp "$DIST/lava-rescue.love" "$HERE/LICENSE" "$L/"
cat > "$L/$NAME.sh" <<'SH'
#!/bin/sh
# Launch "Lava Rescue!". In Steam: Add a Non-Steam Game -> this file.
cd "$(dirname "$0")"
# extract-and-run: works even where AppImages can't be mounted (no FUSE)
APPIMAGE_EXTRACT_AND_RUN=1 exec ./love.AppImage lava-rescue.love "$@"
SH
cp "$GAME/images/icone.png" "$L/lava-rescue.png"
cat > "$L/install.sh" <<'SH'
#!/bin/sh
# Install "Lava Rescue!" for this user (Bazzite, Steam Deck desktop mode, any
# Linux): the game goes to ~/.local/share/lava-rescue and appears in the app
# menu. Then in Steam: Games -> Add a Non-Steam Game -> Lava Rescue!
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/lava-rescue"
mkdir -p "$DEST" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
cp "$SRC/love.AppImage" "$SRC/lava-rescue.love" "$SRC/LavaRescue.sh" "$SRC/LICENSE" "$DEST/"
cp "$SRC/lava-rescue.png" "$HOME/.local/share/icons/hicolor/256x256/apps/lava-rescue.png"
chmod +x "$DEST/LavaRescue.sh" "$DEST/love.AppImage"
cat > "$HOME/.local/share/applications/lava-rescue.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Lava Rescue!
Name[fr]=Sauve les Animaux !
Comment=Save the animals from the lava (1 or 2 players)
Exec="$DEST/LavaRescue.sh"
Path=$DEST
Icon=lava-rescue
Terminal=false
Categories=Game;KidsGame;
DESKTOP
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo "Lava Rescue! is installed: it is in the app menu (Games)."
echo "To play from Steam / Game Mode: Steam -> Games -> Add a Non-Steam Game -> Lava Rescue!"
SH
cat > "$L/uninstall.sh" <<'SH'
#!/bin/sh
# Remove "Lava Rescue!" installed by install.sh.
rm -rf "$HOME/.local/share/lava-rescue"
rm -f "$HOME/.local/share/applications/lava-rescue.desktop" "$HOME/.local/share/icons/hicolor/256x256/apps/lava-rescue.png"
echo "Lava Rescue! is removed."
SH
chmod +x "$L/$NAME.sh" "$L/love.AppImage" "$L/install.sh" "$L/uninstall.sh"
(cd "$DIST" && rm -f "$NAME-linux.tar.gz" && tar -czf "$NAME-linux.tar.gz" "$NAME-linux")
echo "OK  dist/$NAME-linux.tar.gz ($(du -h "$DIST/$NAME-linux.tar.gz" | cut -f1))"

# 3) Windows: love.exe with the game glued at the end = one .exe, plus its DLLs
W="$DIST/$NAME-windows"
rm -rf "$W" "$DIST/love-11.5-win64" && mkdir -p "$W"
unzip -q -o "$CACHE/love-11.5-win64.zip" -d "$DIST"
cp "$DIST"/love-11.5-win64/*.dll "$DIST/love-11.5-win64/license.txt" "$W/"
cp "$HERE/LICENSE" "$W/LICENSE-Lava-Rescue.txt"   # (not LICENSE.txt: it would replace LÖVE's license.txt)
cat "$DIST/love-11.5-win64/love.exe" "$DIST/lava-rescue.love" > "$W/$NAME.exe"
rm -rf "$DIST/love-11.5-win64"
(cd "$DIST" && rm -f "$NAME-windows.zip" && zip -q -r "$NAME-windows.zip" "$NAME-windows")
echo "OK  dist/$NAME-windows.zip ($(du -h "$DIST/$NAME-windows.zip" | cut -f1))"

# 4) Mac: a copy of the LÖVE app with the game inside, renamed
if [ -d /Applications/love.app ]; then
    M="$DIST/$NAME-mac"
    APP="$M/Lava Rescue.app"
    rm -rf "$M" && mkdir -p "$M"
    cp -R /Applications/love.app "$APP"
    cp "$DIST/lava-rescue.love" "$APP/Contents/Resources/game.love"
    cp "$HERE/LICENSE" "$APP/Contents/Resources/LICENSE"
    PL="$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Lava Rescue" "$PL"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier fr.famille.lava-rescue" "$PL"
    /usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations" "$PL" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$PL" 2>/dev/null || true
    xattr -cr "$APP" 2>/dev/null || true
    codesign --force --deep --sign - "$APP" 2>/dev/null || true      # ad-hoc signature
    (cd "$M" && rm -f "../$NAME-mac.zip" && ditto -c -k --sequesterRsrc --keepParent "Lava Rescue.app" "../$NAME-mac.zip")
    echo "OK  dist/$NAME-mac.zip ($(du -h "$DIST/$NAME-mac.zip" | cut -f1))"
fi
