#!/usr/bin/env python3
"""Turn a Veo video (one character on a green screen) into game animations.

1) Look at the video first, to find where each action is:
       python3 volcan/outils/video.py volcan/videos/zina.mp4 --planche
   -> videos/zina_planche.png: every other frame, with its number.

2) Cut it, giving the frame range of each action:
       python3 volcan/outils/video.py volcan/videos/zina.mp4 zina marche=12-49 course=50-83 saut=98-121 aie=146-171
   -> images/zina_marche.png, images/zina_course.png, ... (one strip of frames each)
      images/zina_repos.png (the calmest frame, used when standing still)
      images/zina.lua (sizes and frame counts, read by the game)

"marche" and "course" become loops: the script finds, inside the range you
gave, the stretch that loops back most smoothly. Other actions play once.
Options: --repos=200 to choose the standing frame yourself, --fps=12,
--boucle-marche=24 to force a longer walk loop (same for --boucle-course).
"""

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from detourage import background_color, cut_out  # noqa: E402

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "images"
LOOPS = {"marche", "course"}
OUT_HEIGHT = 320        # height of each frame in the strips
# Shortest loop allowed, in video frames (at 24 images/s). In a side view the
# left and right steps look alike, so without this the script could pick a
# single step instead of a full cycle, and the legs would jump at the loop.
MIN_LOOP = {"marche": 20, "course": 14}


def read_frames(path):
    cap = cv2.VideoCapture(str(path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 24
    frames = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(f, cv2.COLOR_BGR2RGB))
    return frames, fps


def contact_sheet(frames, path):
    h, w = frames[0].shape[:2]
    tw = 200
    th = int(h * tw / w)
    picks = list(range(0, len(frames), 2))
    cols = 12
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * (th + 16)), "white")
    d = ImageDraw.Draw(sheet)
    for i, fi in enumerate(picks):
        x, y = (i % cols) * tw, (i // cols) * (th + 16)
        sheet.paste(Image.fromarray(frames[fi]).resize((tw, th)), (x, y + 16))
        d.text((x + 4, y + 2), str(fi), fill="black")
    sheet.save(path)
    print("Planche :", path)


def best_loop(small, a, b, min_len):
    """Frames [i, j) inside [a, b] whose last frame flows best into the first."""
    best = None
    for i in range(a, b + 1):
        for j in range(i + min_len, b + 2):
            if j > len(small) - 1:
                break
            diff = np.abs(small[i] - small[j]).mean()
            if best is None or diff < best[0]:
                best = (diff, i, j)
    return best[1], best[2]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) if "=" in a else (a[2:], True) for a in sys.argv[1:] if a.startswith("--"))
    if not args:
        print(__doc__)
        sys.exit(1)
    video = Path(args[0])
    frames, video_fps = read_frames(video)
    print(f"{len(frames)} images, {video_fps:.0f} images/s, {len(frames) / video_fps:.1f} s")

    if opts.get("planche"):
        contact_sheet(frames, video.with_name(video.stem + "_planche.png"))
        return

    name = args[1]
    ranges = {}
    for spec in args[2:]:
        anim, span = spec.split("=")
        a, b = (int(v) for v in span.split("-"))
        ranges[anim] = (a, b)
    step = max(1, round(video_fps / int(opts.get("fps", 12))))

    # small blurred copies to compare frames quickly
    small = [cv2.GaussianBlur(cv2.resize(f, (f.shape[1] // 8, f.shape[0] // 8)), (3, 3), 0).astype(np.float32)
             for f in frames]

    picks = {}
    for anim, (a, b) in ranges.items():
        if anim in LOOPS:
            i, j = best_loop(small, a, b, int(opts.get("boucle-" + anim, MIN_LOOP[anim])))
            picks[anim] = list(range(i, j, step))
            print(f"  {anim}: boucle {i}-{j - 1} ({j - i} images)")
        else:
            picks[anim] = list(range(a, b + 1, step))
            print(f"  {anim}: {a}-{b}")

    # standing frame: the one that changes least from its neighbours
    main_bg = background_color(frames[min(a for a, _ in ranges.values())].astype(np.float32))
    if "repos" in opts:
        rest = int(opts["repos"])
    else:
        calm = [(np.abs(small[i] - small[i - 1]).mean() + np.abs(small[i] - small[i + 1]).mean(), i)
                for i in range(1, len(frames) - 1)
                if np.abs(background_color(frames[i].astype(np.float32)) - main_bg).max() < 30]
        rest = min(calm)[1]
    picks["repos"] = [rest]
    print(f"  repos: image {rest}")

    # cut every needed frame out of the green screen
    needed = sorted({i for p in picks.values() for i in p})
    cut = {}
    for i in needed:
        clean, alpha = cut_out(frames[i])
        cut[i] = (clean, alpha)

    # one crop for everything, so the character never jitters between frames
    boxes = []
    for clean, alpha in cut.values():
        ys, xs = np.nonzero(alpha > 0.5)
        boxes.append((ys.min(), ys.max(), xs.min(), xs.max()))
    top = max(0, min(b[0] for b in boxes) - 6)
    bottom = min(frames[0].shape[0], max(b[1] for b in boxes) + 6)
    left = max(0, min(b[2] for b in boxes) - 6)
    right = min(frames[0].shape[1], max(b[3] for b in boxes) + 6)
    if min(b[0] for b in boxes) <= 1:
        print("Attention : le personnage touche le haut de la vidéo (tête coupée pendant un saut ?)")
    scale = OUT_HEIGHT / (bottom - top)
    fw, fh = round((right - left) * scale), OUT_HEIGHT

    # where the feet are and how tall the character is, measured on the standing frame
    ys, _ = np.nonzero(cut[rest][1] > 0.5)
    baseline = round((ys.max() - top) * scale)
    height = round((ys.max() - ys.min()) * scale)

    OUT.mkdir(exist_ok=True)
    lua = [f"-- made by outils/video.py from {video.name}", "return {",
           f"    frameW = {fw}, frameH = {fh}, baseline = {baseline}, height = {height},",
           f"    fps = {video_fps / step:g},", "    anims = {"]
    for anim, idxs in picks.items():
        strip = Image.new("RGBA", (fw * len(idxs), fh), (0, 0, 0, 0))
        for n, i in enumerate(idxs):
            clean, alpha = cut[i]
            rgba = np.dstack([clean, alpha * 255])[top:bottom, left:right].astype(np.uint8)
            strip.paste(Image.fromarray(rgba, "RGBA").resize((fw, fh), Image.LANCZOS), (n * fw, 0))
        strip.save(OUT / f"{name}_{anim}.png")
        loop = "true" if anim in LOOPS else "false"
        lua.append(f"        {anim} = {{ frames = {len(idxs)}, loop = {loop} }},")
        print(f"  -> images/{name}_{anim}.png ({len(idxs)} images)")
    lua += ["    },", "}"]
    (OUT / f"{name}.lua").write_text("\n".join(lua) + "\n")
    print(f"  -> images/{name}.lua")


if __name__ == "__main__":
    main()
