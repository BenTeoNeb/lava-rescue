#!/bin/bash
# Test the Linux / Bazzite package in a Fedora x86_64 container: install.sh
# (as a normal user, no FUSE), the menu entry, the game running 12 s on a
# virtual 1280x800 screen (screenshot in /out, after WAIT s: 12 by default,
# more for a game that loads big images under emulation), and the uninstall.
#
# From the game's folder, after sh outils/build.sh:
#   docker run --rm --platform linux/amd64 -v "$PWD/dist:/dist:ro" \
#     -v "$PWD/dist/out:/out" -v "$PWD/outils/linux:/t:ro" fedora:41 bash /t/test-fedora.sh
# On an Apple Silicon Mac: Colima with Rosetta (colima start --vz-rosetta).
# Under Rosetta, the AppImage can't run itself (its magic bytes, /proc/self/exe):
# install.sh's plan B (unsquashfs) is what gets tested; a real x86_64 PC runs it as is.
set -e
dnf -y -q install xorg-x11-server-Xvfb xorg-x11-xauth mesa-dri-drivers mesa-libGL libglvnd-glx \
    tar gzip squashfs-tools desktop-file-utils procps-ng which util-linux xwd ImageMagick >/dev/null 2>&1
echo "== packages installed"
useradd -m kid
su - kid -c 'WAIT='"${WAIT:-12}"'

set -e
tar xzf /dist/LavaRescue-linux.tar.gz -C ~
cd ~/LavaRescue-linux
# TEST ONLY: x86_64 emulation (Rosetta) refuses the AppImage magic bytes
# ("AI\x02" at offset 8 of the ELF header); a real x86_64 PC runs it as is
printf "\000\000\000" | dd of=love.AppImage bs=1 seek=8 count=3 conv=notrunc 2>/dev/null
echo "== install.sh"
sh install.sh
echo "== installed files"; ls ~/.local/share/lava-rescue
echo "== LÖVE unpacked:"; ls ~/.local/share/lava-rescue/love | head -5
echo "== desktop entry"; cat ~/.local/share/applications/lava-rescue.desktop
desktop-file-validate ~/.local/share/applications/lava-rescue.desktop && echo "desktop entry valid"
echo "== run the installed game 15 s (virtual 1280x800 screen)"
export SDL_AUDIODRIVER=dummy
Xvfb :9 -screen 0 1280x800x24 >/dev/null 2>&1 &
XV=$!
sleep 2
export DISPLAY=:9
~/.local/share/lava-rescue/LavaRescue.sh > ~/run1.log 2>&1 &
G=$!
sleep "$WAIT"
xwd -root -silent | convert xwd:- /tmp/shot1.png 2>/dev/null && cp /tmp/shot1.png /out/linux_shot1.png || echo "(no screenshot)"
if kill -0 $G 2>/dev/null; then echo "game still running after $WAIT s: OK"; kill $G; else echo "GAME EXITED"; fi
echo "-- game output:"; cat ~/run1.log | head -20
echo "== run from the unpacked folder, without install (AppImage self-extract: cannot work under Rosetta, expected to fail here)"
rm -rf ~/.local/share/lava-rescue/love
cd ~/LavaRescue-linux && ./LavaRescue.sh > ~/run2.log 2>&1 &
G=$!
sleep 12
if kill -0 $G 2>/dev/null; then echo "uninstalled-run still running after 12 s: OK"; kill $G; else echo "GAME EXITED"; fi
echo "-- game output:"; head -20 ~/run2.log
kill $XV
echo "== uninstall"
sh ~/.local/share/lava-rescue/install.sh --uninstall
ls ~/.local/share/lava-rescue 2>/dev/null || echo "folder removed"
ls ~/.local/share/applications/lava-rescue.desktop 2>/dev/null || echo "menu entry removed"
'
