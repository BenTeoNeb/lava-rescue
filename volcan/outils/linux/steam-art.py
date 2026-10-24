#!/usr/bin/env python3
"""Give a non-Steam game its library artwork in Steam (cover, wide capsule,
hero banner, logo), for every Steam user on this computer.

    python3 steam-art.py ART_DIR LAUNCHER NAME

ART_DIR has steam_cover.png, steam_wide.png, steam_hero.png, steam_logo.png.
The game's shortcut is found in Steam's shortcuts.vdf (a small binary file)
by its launcher (e.g. WeedZapper.sh) or its name, and its id gives the file
names in userdata/<user>/config/grid/. Steam reads them when it starts.
Exit code: 0 done, 2 the game is not in Steam yet, 1 no Steam found.
"""
import glob, os, shutil, struct, sys, zlib

ROOTS = ["~/.local/share/Steam", "~/.steam/steam", "~/.steam/root",
         "~/.var/app/com.valvesoftware.Steam/.local/share/Steam"]
ART = {"steam_cover.png": "{}p.png", "steam_wide.png": "{}.png",
       "steam_hero.png": "{}_hero.png", "steam_logo.png": "{}_logo.png"}


def read_vdf(data):
    """Binary KeyValues: 0x00 map, 0x01 string, 0x02 int32, 0x08 end."""
    pos = 0

    def cstr():
        nonlocal pos
        end = data.index(b"\0", pos)
        s = data[pos:end].decode("utf-8", "replace")
        pos = end + 1
        return s

    def node():
        nonlocal pos
        out = {}
        while pos < len(data):
            t = data[pos]
            pos += 1
            if t == 0x08:
                return out
            key = cstr()
            if t == 0x00:
                out[key] = node()
            elif t == 0x01:
                out[key] = cstr()
            elif t == 0x02:
                out[key] = struct.unpack_from("<i", data, pos)[0]
                pos += 4
            elif t == 0x07:
                out[key] = struct.unpack_from("<Q", data, pos)[0]
                pos += 8
            else:
                raise ValueError("unknown type %d" % t)
        return out

    return node()


def shortcut_ids(vdf_path, launcher, name):
    with open(vdf_path, "rb") as f:
        tree = read_vdf(f.read())
    ids = []
    for sc in tree.get("shortcuts", {}).values():
        sc = {k.lower(): v for k, v in sc.items()}
        exe, app = sc.get("exe", ""), sc.get("appname", "")
        if launcher in exe or app.strip().lower().startswith(name.lower()):
            appid = sc.get("appid")
            if appid is None:   # (old Steam: the id came from the exe and name)
                appid = zlib.crc32((exe + app).encode()) | 0x80000000
            ids.append(appid & 0xFFFFFFFF)
    return ids


def main():
    art_dir, launcher, name = sys.argv[1:4]
    found_steam, done = False, 0
    seen = set()
    for root in ROOTS:
        root = os.path.realpath(os.path.expanduser(root))
        if root in seen or not os.path.isdir(root):
            continue
        seen.add(root)
        found_steam = True
        for vdf in glob.glob(os.path.join(root, "userdata", "*", "config", "shortcuts.vdf")):
            try:
                ids = shortcut_ids(vdf, launcher, name)
            except Exception as e:     # never break the install for this
                print("  (shortcuts.vdf illisible / unreadable: %s)" % e)
                continue
            grid = os.path.join(os.path.dirname(vdf), "grid")
            for appid in ids:
                os.makedirs(grid, exist_ok=True)
                for src, dst in ART.items():
                    p = os.path.join(art_dir, src)
                    if os.path.isfile(p):
                        shutil.copyfile(p, os.path.join(grid, dst.format(appid)))
                done += 1
    if done:
        print("OK  Steam : images du jeu / game artwork (%d)" % done)
        return 0
    return 2 if found_steam else 1


if __name__ == "__main__":
    sys.exit(main())
