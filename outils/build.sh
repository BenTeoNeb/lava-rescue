#!/bin/sh
# Build "Sauve les Animaux !" for sharing:
#   dist/sauve-les-animaux.love        the game itself (needs LÖVE 11.5)
#   dist/SauveLesAnimaux-linux.tar.gz  Linux / Bazzite / Steam Deck, nothing to install
#   dist/SauveLesAnimaux-windows.zip   Windows, double-click SauveLesAnimaux.exe
#
# Run from anywhere:  sh volcan/outils/build.sh
# The official LÖVE 11.5 builds are downloaded once into .cache/love/.
set -e

HERE="$(cd "$(dirname "$0")/../.." && pwd)"     # the "games" folder
GAME="$HERE/volcan"
DIST="$HERE/dist"
CACHE="$HERE/.cache/love"
NAME="SauveLesAnimaux"
LOVE_URL="https://github.com/love2d/love/releases/download/11.5"

mkdir -p "$DIST" "$CACHE"
for f in love-11.5-x86_64.AppImage love-11.5-win64.zip; do
    [ -f "$CACHE/$f" ] || curl -sSL -o "$CACHE/$f" "$LOVE_URL/$f"
done

# 1) the .love: only what the game needs (code + images)
rm -f "$DIST/sauve-les-animaux.love"
# (journal.lua is left out: the game log is for us, not for the players;
#  without it the game simply logs nothing)
(cd "$GAME" && zip -q -9 -r "$DIST/sauve-les-animaux.love" ./*.lua images -x "images/_*" "*.DS_Store" "./journal.lua")
echo "OK  dist/sauve-les-animaux.love ($(du -h "$DIST/sauve-les-animaux.love" | cut -f1))"

# 2) Linux: the LÖVE AppImage + the game + a launcher script
L="$DIST/$NAME-linux"
rm -rf "$L" && mkdir -p "$L"
cp "$CACHE/love-11.5-x86_64.AppImage" "$L/love.AppImage"
cp "$DIST/sauve-les-animaux.love" "$L/"
cat > "$L/$NAME.sh" <<'SH'
#!/bin/sh
# Launch "Sauve les Animaux !". In Steam: Add a Non-Steam Game -> this file.
cd "$(dirname "$0")"
# extract-and-run: works even where AppImages can't be mounted (no FUSE)
APPIMAGE_EXTRACT_AND_RUN=1 exec ./love.AppImage sauve-les-animaux.love "$@"
SH
chmod +x "$L/$NAME.sh" "$L/love.AppImage"
(cd "$DIST" && rm -f "$NAME-linux.tar.gz" && tar -czf "$NAME-linux.tar.gz" "$NAME-linux")
echo "OK  dist/$NAME-linux.tar.gz ($(du -h "$DIST/$NAME-linux.tar.gz" | cut -f1))"

# 3) Windows: love.exe with the game glued at the end = one .exe, plus its DLLs
W="$DIST/$NAME-windows"
rm -rf "$W" "$DIST/love-11.5-win64" && mkdir -p "$W"
unzip -q -o "$CACHE/love-11.5-win64.zip" -d "$DIST"
cp "$DIST"/love-11.5-win64/*.dll "$DIST/love-11.5-win64/license.txt" "$W/"
cat "$DIST/love-11.5-win64/love.exe" "$DIST/sauve-les-animaux.love" > "$W/$NAME.exe"
rm -rf "$DIST/love-11.5-win64"
(cd "$DIST" && rm -f "$NAME-windows.zip" && zip -q -r "$NAME-windows.zip" "$NAME-windows")
echo "OK  dist/$NAME-windows.zip ($(du -h "$DIST/$NAME-windows.zip" | cut -f1))"
