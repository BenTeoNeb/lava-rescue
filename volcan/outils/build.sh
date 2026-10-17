#!/bin/sh
# Build "Lava Rescue!" for sharing:
#   dist/lava-rescue.love        the game itself (needs LÖVE 11.5)
#   dist/LavaRescue-linux.tar.gz  Linux / Bazzite / Steam Deck: unpack, then
#                                  install.sh adds it to the menu (and Steam)
#   dist/LavaRescue-windows.zip   Windows, double-click LavaRescue.exe
#   dist/LavaRescue-mac.zip       Mac, double-click the app (made from the LÖVE
#                                      app installed in /Applications, if there is one)
#
# Run from anywhere:  sh volcan/outils/build.sh
# The official LÖVE 11.5 builds are downloaded once into .cache/love/ (in a
# git worktree, the main checkout's .cache/love/ is used if it has them).
set -e

HERE="$(cd "$(dirname "$0")/../.." && pwd)"     # the "games" folder
GAME="$HERE/volcan"
DIST="$HERE/dist"
CACHE="$HERE/.cache/love"
if [ ! -f "$CACHE/love-11.5-x86_64.AppImage" ]; then
    COMMON="$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    MAIN="$(dirname "$COMMON")/.cache/love"
    if [ -n "$COMMON" ] && [ -f "$MAIN/love-11.5-x86_64.AppImage" ]; then CACHE="$MAIN"; fi
fi
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
(cd "$GAME" && zip -q -9 -r "$DIST/lava-rescue.love" ./*.lua icone.png images -x "images/_*" "*.DS_Store" "./journal.lua")
zip -q -j "$DIST/lava-rescue.love" "$HERE/LICENSE"      # the license travels with the game
echo "OK  dist/lava-rescue.love ($(du -h "$DIST/lava-rescue.love" | cut -f1))"

# 2) Linux / Bazzite / Steam Deck: the LÖVE AppImage + the game + a launcher,
#    an installer (menu entry, icon) and the instructions
L="$DIST/$NAME-linux"
rm -rf "$L" && mkdir -p "$L"
cp "$CACHE/love-11.5-x86_64.AppImage" "$L/love.AppImage"
cp "$DIST/lava-rescue.love" "$HERE/LICENSE" "$GAME/icone.png" "$L/"
cp "$GAME/outils/linux/install.sh" "$GAME/outils/linux/LISEZ-MOI-BAZZITE.txt" "$L/"
cat > "$L/$NAME.sh" <<'SH'
#!/bin/sh
# Launch "Lava Rescue!". In Steam: Add a Non-Steam Game -> this file.
cd "$(dirname "$0")"
# install.sh unpacks LÖVE once (fast start, no FUSE needed); otherwise the
# AppImage unpacks itself at each start (works even without FUSE)
if [ -x love/AppRun ]; then exec ./love/AppRun "$PWD/lava-rescue.love" "$@"; fi
APPIMAGE_EXTRACT_AND_RUN=1 exec ./love.AppImage "$PWD/lava-rescue.love" "$@"
SH
chmod +x "$L/$NAME.sh" "$L/love.AppImage" "$L/install.sh"
# (without macOS's extended attributes: Linux's tar would warn about them)
(cd "$DIST" && rm -f "$NAME-linux.tar.gz" && COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf "$NAME-linux.tar.gz" "$NAME-linux" 2>/dev/null \
    || COPYFILE_DISABLE=1 tar -czf "$NAME-linux.tar.gz" "$NAME-linux")
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
