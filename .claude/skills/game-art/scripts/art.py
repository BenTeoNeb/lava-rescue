#!/usr/bin/env python3
"""Game art pipeline, driven by an art.json file in the game folder.

    python3 art.py plan                  what to generate, at what size (no API call)
    python3 art.py prompt SHEET          print the prompt (to use by hand in Gemini)
    python3 art.py gen SHEET             generate the sheet image (image API)
    python3 art.py animate SHEET         generate a character's video (video API)
    python3 art.py cut SHEET             cut the sheet / video into full-resolution pieces
    python3 art.py bake [SHEET ...]      size every piece for 4K, even out the outlines -> images/
    python3 art.py build SHEET           gen + cut + bake (+ animate for a character with --anim)
    python3 art.py report                resolution and outline of every baked image
    python3 art.py budget                spending so far, cap, what is left

Every API call is estimated first and refused over the budget cap (art.json
"budget"). A call costing more than confirm_above_usd needs --oui: ask the
user first. "plan" shows what a full build would cost.

Run it from the game folder (where art.json is), or pass --projet=DIR.
See SKILL.md for the art.json format and the method.
"""

import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import bake  # noqa: E402
from budget import Budget  # noqa: E402
import os  # noqa: E402

IMAGE_MODEL = os.environ.get("ART_IMAGE_MODEL", "gemini-3-pro-image")
VIDEO_MODEL = os.environ.get("ART_VIDEO_MODEL", "veo-3.1-generate-preview")
VIDEO_RES, VIDEO_SECONDS = "1080p", 8

LONG_SIDE = {"1K": 1024, "2K": 2048, "4K": 4096}
# What the image models really return: about the same NUMBER of pixels for every
# ratio (a 16:9 "2K" image is 2752x1536, not 2048 wide), measured on Gemini 3 Pro.
AREA = {"1K": 1024 * 1024, "2K": 2048 * 2048, "4K": 4096 * 4096}
RATIOS = {"1:1": 1, "4:3": 4 / 3, "3:2": 1.5, "16:9": 16 / 9, "21:9": 21 / 9, "3:4": 0.75, "2:3": 2 / 3, "9:16": 9 / 16}
FILL = 0.65          # how much of its cell a drawing fills, roughly (margins, gaps)
MAGENTA = ("BACKGROUND: perfectly flat, uniform pure magenta (#FF00FF) filling the whole image. "
           "No floor, no horizon, no cast shadow, no vignette, no gradient, no text. "
           "Every item is fully visible with an empty margin around it, nothing cropped, "
           "and items never touch each other.")
GREEN = ("Flat solid green screen background (#00FF00), even lighting, no shadow, no smoke, "
         "no effects, no other objects.")


# ---------------------------------------------------------------- the project

class Project:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.cfg = json.loads((self.root / "art.json").read_text())
        g = self.cfg.get("game", {})
        self.scale = g.get("max_scale", 3)          # 3 = 4K for a 1280x720 game
        self.outline = g.get("outline", 0.9)        # target outline, in game units
        self.fps = g.get("fps", 24)
        p = self.cfg.get("paths", {})
        self.sheets = self.root / p.get("sheets", "planches")
        self.videos = self.root / p.get("videos", "videos")
        self.images = self.root / p.get("images", "images")
        self.cache = self.root / p.get("cache", ".cache/art")
        self.style = self.cfg["style"]["text"]
        ref = self.cfg["style"].get("reference")
        self.reference = (self.root / ref) if ref else None

    def asset(self, sheet):
        for a in self.cfg["assets"]:
            if a["sheet"] == sheet:
                return a
        sys.exit(f"Pas d'asset « {sheet} » dans art.json.")

    def sheet_file(self, sheet):
        for ext in (".png", ".jpg", ".jpeg", ".webp"):
            f = self.sheets / f"{sheet}{ext}"
            if f.exists():
                return f
        return self.sheets / f"{sheet}.png"


def run(script, *args, cwd=None):
    subprocess.run([sys.executable, str(SCRIPTS / script), *map(str, args)], check=True, cwd=cwd)


def size_px(size, scale):
    """'h55' -> ('h', 55*scale) pixels needed on the biggest screen."""
    return size[0], float(size[1:]) * scale


# ---------------------------------------------------------------- planning

def layout(n):
    """Columns and rows for n items (one row up to 5, then a grid)."""
    if n <= 5:
        return n, 1
    cols = math.ceil(math.sqrt(n * 1.6))
    return cols, math.ceil(n / cols)


def plan_sheet(project, a):
    """Choose the image ratio and size so every item gets enough pixels."""
    items = a.get("items", [])
    if a["kind"] == "tile":
        need = a["tile"] * project.scale
        size = next((s for s, px in LONG_SIDE.items() if px * 0.5 >= need), "4K")
        return {"ratio": "1:1", "size": size, "cols": 1, "rows": 1, "need": need,
                "cell": LONG_SIDE[size] * 0.5, "ok": LONG_SIDE[size] * 0.5 >= need}
    if a["kind"] == "style":            # not shown in the game: just a good-sized lineup
        return {"ratio": "16:9", "size": "2K", "cols": 4, "rows": 1, "need": 0, "cell": 0, "ok": True}
    if a["kind"] == "character":
        items = [a]
    # The smallest image size that gives every item enough pixels, trying every
    # layout (one row, then grids). Big image sizes cost more and tend to
    # produce artifacts (doubled drawings): only go up when no layout fits.
    n = len(items)
    need = max(size_px(i["size"], project.scale)[1] for i in items)
    # shape of one drawing (width / height): animals and objects seen from the
    # side are wider than tall ("aspect" in art.json to change it)
    aspect = a.get("aspect", 1.3 if items[0]["size"][0] == "h" else 0.8)
    best = None                          # biggest cell seen (if nothing fits)
    choice = None
    for size, long_side in LONG_SIDE.items():
        fitting = []
        forced = a.get("grid")                # art.json can impose a layout: [cols, rows]
        for cols in ([forced[0]] if forced else range(n, 0, -1)):
            rows = forced[1] if forced else math.ceil(n / cols)
            if not forced and cols * rows - n >= cols:   # a whole empty row: skip
                continue
            want = cols * aspect / rows
            ratio = min(RATIOS, key=lambda r: abs(math.log(RATIOS[r] / want)))
            w = math.sqrt(AREA[size] * RATIOS[ratio])
            h = w / RATIOS[ratio]
            # room for one drawing, measured on the side the size is given on
            hh = min(w / cols / aspect, h / rows)
            cell = (hh if items[0]["size"][0] == "h" else hh * aspect) * FILL
            layout_ = (size, cols, rows, ratio, cell)
            if best is None or cell > best[4]:
                best = layout_
            if cell >= need:
                # fewest empty cells, then a landscape image (what the models
                # draw best, closest to 16:9), then the most room
                fitting.append((cols * rows - n, abs(math.log(RATIOS[ratio] / (16 / 9))), -cell, layout_))
        if fitting:
            choice = min(fitting, key=lambda f: f[:3])[3]
            break
    best = choice or best
    size, cols, rows, ratio, cell = best
    sizes = [float(i["size"][1:]) for i in items]
    spread = max(sizes) / min(sizes) if sizes else 1
    return {"ratio": ratio, "size": size, "cols": cols, "rows": rows, "need": need, "cell": cell,
            "ok": cell >= need, "spread": spread}


def best_size(budget, size):
    """Same price, more pixels: if a bigger image size costs the same (1K and 2K
    often do), ask for the bigger one."""
    price = budget.image_cost(IMAGE_MODEL, size)
    bigger = [s for s in LONG_SIDE if LONG_SIDE[s] > LONG_SIDE[size]
              and abs(budget.image_cost(IMAGE_MODEL, s) - price) < 1e-9]
    return bigger[-1] if bigger else size


def sheet_cost(budget, a, p):
    """What generating this sheet once costs (plus the video for a character)."""
    cost = budget.image_cost(IMAGE_MODEL, p["size"])
    if a["kind"] == "character" and a.get("actions"):
        cost += budget.video_cost(VIDEO_MODEL, VIDEO_RES, VIDEO_SECONDS)
    return cost


def cmd_plan(project):
    print(f"Écran le plus grand : x{project.scale} (4K pour un jeu en 1280x720), trait visé {project.outline}\n")
    budget = Budget(project.root)
    print(f"{'planche':14} {'type':10} {'n':>2} {'grille':>6} {'ratio':>5} {'taille':>6} {'px requis':>9} "
          f"{'px dispo':>8} {'coût':>7}")
    total = 0
    for a in project.cfg["assets"]:
        p = plan_sheet(project, a)
        cost = sheet_cost(budget, a, p)
        total += cost
        n = len(a.get("items", [])) or 1
        flag = "" if p["ok"] else "  <- trop petit : découper en plusieurs planches"
        if p.get("spread", 1) > 2:
            flag += f"  <- tailles très différentes (x{p['spread']:.1f}) : traits inégaux, séparer"
        print(f"{a['sheet']:14} {a['kind']:10} {n:>2} {p['cols']}x{p['rows']:<4} {p['ratio']:>5} {p['size']:>6} "
              f"{p['need']:>9.0f} {p['cell']:>8.0f} {'$%.2f' % cost:>7}{flag}")
    print(f"\nTout générer une fois : ${total:.2f} (images {IMAGE_MODEL}, vidéos {VIDEO_MODEL} "
          f"{VIDEO_SECONDS} s {VIDEO_RES}). Comptez des essais en plus : souvent 2 à 3 par planche.")
    budget.report()


# ---------------------------------------------------------------- prompts

def relative_sizes(items):
    """'Draw them to scale' sentence, so outlines stay even after resizing."""
    hs = [(i["name"], float(i["size"][1:]), i["size"][0]) for i in items]
    if len(hs) < 2 or max(h for _, h, _ in hs) / min(h for _, h, _ in hs) < 1.25:
        return "All items are about the same size."
    tallest = max(hs, key=lambda t: t[1])
    parts = [f"{i + 1} is about {round(100 * h / tallest[1])}% of the biggest" for i, (n, h, _) in enumerate(hs)]
    return ("Draw them TO SCALE relative to each other, with the same line thickness everywhere: "
            + "; ".join(parts) + ".")


def build_prompt(project, a):
    kind = a["kind"]
    ref = ("Use the attached image as the strict style reference: same outline thickness, same colors, "
           "same shading, same eye style.\n\n") if project.reference and project.reference.exists() else ""
    if a.get("refs"):
        ref += ("The other attached image(s) show the current design of these items: keep the same design, "
                "colors and details.\n\n")
    if kind == "style":
        return (f"A style reference lineup for a children's video game, in one single horizontal row with "
                f"big empty gaps between them: {a['desc']}. Wide 16:9 image.\n{project.style}\n{MAGENTA}")
    if kind == "tile":
        return (f"{ref}A SEAMLESS TILEABLE TEXTURE seen straight from above (top-down, orthographic, no "
                f"perspective), for a 2D video game. Square image. {a['desc']} Everything is small and "
                f"evenly spread over the whole image, no big objects, no empty areas, no cluster in the middle. "
                f"Perfectly uniform lighting and color, no vignette, no light spot, no gradient. The left edge "
                f"continues seamlessly into the right edge, the top edge into the bottom edge.\n{project.style}")
    if kind == "character":
        return (f"{ref}One {a['desc']}, full body, side view facing RIGHT, standing calmly, feet flat on an "
                f"invisible ground line at the bottom, neutral pose with legs slightly apart.\n"
                f"{project.style}\n{MAGENTA}")
    items = a["items"]
    p = plan_sheet(project, a)
    where = ("in one single horizontal row" if p["rows"] == 1
             else f"in a grid of {p['rows']} rows and {p['cols']} columns")
    listing = "\n".join(f"{n + 1}. {i['desc']}" for n, i in enumerate(items))
    view = a.get("view", "side view, facing RIGHT, standing on its base")
    return (f"{ref}A sheet of {len(items)} separate items for a children's video game, {where}, with big "
            f"empty gaps between them, in this reading order (left to right, top to bottom), {view}:\n"
            f"{listing}\n{relative_sizes(items)}\n{a.get('note', '')}\n{project.style}\n{MAGENTA}")


def video_prompt(project, a):
    actions = a.get("actions", {})
    per = 8 / max(1, len(actions))
    lines = [f"[00:{round(i * per):02d}-00:{round((i + 1) * per):02d}] {text}"
             for i, text in enumerate(actions.values())]
    return ("Animate the character from the image as a game sprite reference. Static camera, side view "
            "facing right. The character stays centered in the same spot the whole time, like on a "
            "treadmill: never moves across the frame. The character is small in the frame, with lots of "
            f"empty space above its head so it never leaves the frame when jumping. {GREEN} Keep the exact "
            "same character, clothes, colors and drawing style in every frame. Each action starts and ends "
            "in the same neutral standing pose.\n" + "\n".join(lines))


def cmd_prompt(project, sheet):
    a = project.asset(sheet)
    print(build_prompt(project, a))
    if a["kind"] == "character" and a.get("actions"):
        print("\n--- vidéo (Veo, à partir de l'image du personnage) ---\n" + video_prompt(project, a))


# ---------------------------------------------------------------- API calls

def cmd_gen(project, sheet, yes=False):
    import genimage
    a = project.asset(sheet)
    if a["kind"] == "style" and project.reference and project.reference.exists() and not yes:
        sys.exit(f"Il y a déjà une référence de style ({project.reference}) : on ne la remplace pas. "
                 f"Si l'utilisateur veut vraiment un nouveau style, relancez avec --oui.")
    p = plan_sheet(project, a)
    if not p["ok"]:
        print(f"Attention : {p['cell']:.0f} px par dessin, {p['need']:.0f} requis pour la 4K.")
    refs = [str(project.reference)] if project.reference and project.reference.exists() and a["kind"] != "style" else []
    # extra references for this sheet (e.g. the current image when regenerating it)
    refs += [str(project.root / r) for r in a.get("refs", []) if (project.root / r).exists()]
    out = project.sheets / f"{sheet}.png"
    size = best_size(Budget(project.root), p["size"])
    genimage.generate(str(out), build_prompt(project, a), refs, p["ratio"], size, IMAGE_MODEL,
                      yes=yes, what=f"{sheet} (planche)", root=project.root)
    print("Vérifiez l'image avant de continuer :", out)


def cmd_animate(project, sheet, yes=False):
    import genvideo
    a = project.asset(sheet)
    still = project.cache / f"{a['name'] if 'name' in a else sheet}.png"
    if not still.exists():
        cmd_cut(project, sheet, still_only=True)
    # Veo starts from a picture on green: put the cut-out on a green background
    im = Image.open(still).convert("RGBA")
    W, H = 1920, 1080
    s = H * 0.6 / im.height
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    bg = Image.new("RGBA", (W, H), (0, 255, 0, 255))
    bg.alpha_composite(im, ((W - im.width) // 2, round(H * 0.82) - im.height))
    start = project.cache / f"{sheet}_depart.png"
    bg.convert("RGB").save(start)
    out = project.videos / f"{sheet}.mp4"
    genvideo.generate(str(out), str(start), video_prompt(project, a), "16:9", VIDEO_RES, VIDEO_SECONDS,
                      VIDEO_MODEL, yes=yes, what=f"{sheet} (vidéo)", root=project.root)
    run("video.py", out, "--planche", cwd=project.root)
    print("Regardez la planche des images pour vérifier où sont les actions.")


# ---------------------------------------------------------------- cutting and baking

def names_of(a, sheet):
    if a["kind"] in ("character", "style", "tile"):
        return [a.get("name", sheet)]
    return [i["name"] for i in a["items"]]


def cmd_cut(project, sheet, still_only=False):
    a = project.asset(sheet)
    if a["kind"] == "tile":
        run("texture.py", project.sheet_file(sheet), a.get("name", sheet),
            f"--taille={round(a['tile'] * project.scale)}", f"--sortie={project.images}")
        return
    if project.sheet_file(sheet).exists():
        run("decoupe.py", project.sheet_file(sheet), *names_of(a, sheet), "--max=0", f"--sortie={project.cache}")
    elif a["kind"] != "character":
        sys.exit(f"Pas de planche {project.sheet_file(sheet)} : lancez d'abord « art.py gen {sheet} ».")
    if a["kind"] == "character" and not still_only:
        video = project.videos / f"{sheet}.mp4"
        if video.exists() and a.get("actions"):
            cmd_cut_video(project, sheet, a, video)


def cmd_cut_video(project, sheet, a, video):
    """Video -> one animation per action, at the game's frame rate and at the
    resolution needed on the biggest screen."""
    ranges = a.get("ranges")
    if not ranges:
        # by default: the timeline of the prompt (each action has the same length)
        n = len(a["actions"])
        per = 8 * 24 / n
        ranges = {act: f"{round(i * per + 6)}-{round((i + 1) * per - 4)}" for i, act in enumerate(a["actions"])}
    need = size_px(a["size"], project.scale)[1]
    frame_h = math.ceil(need / 0.9 / 8) * 8       # the character fills ~90% of the frame height
    run("video.py", video, a.get("name", sheet), *[f"{k}={v}" for k, v in ranges.items()],
        f"--fps={project.fps}", f"--hauteur={frame_h}", f"--sortie={project.images}", cwd=project.root)


def bake_one(project, name, size):
    src = project.cache / f"{name}.png"
    if not src.exists():
        print(f"  {name}: pas encore découpé ({src})")
        return
    im = Image.open(src).convert("RGBA")
    big = bake.resize_to(im, size, project.scale)
    low = big.width > im.width
    if low:
        big = im
    bake.TARGET, bake.SCALE = project.outline, project.scale
    fixed, t = bake.thicken(np.asarray(big), project.outline * project.scale)
    project.images.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.ascontiguousarray(fixed), "RGBA").save(project.images / f"{name}.png")
    print(f"  {name}: {big.width}x{big.height}" + ("  (source trop petite pour la 4K)" if low else ""))


def cmd_bake(project, sheets):
    for a in project.cfg["assets"]:
        if sheets and a["sheet"] not in sheets:
            continue
        if a["kind"] == "objects":
            for i in a["items"]:
                bake_one(project, i["name"], i["size"])
        elif a["kind"] == "character" and not (project.images / f"{a.get('name', a['sheet'])}.lua").exists():
            bake_one(project, a.get("name", a["sheet"]), a["size"])   # still image (no animation yet)


def cmd_report(project):
    print(f"{'image':20} {'taille':>11}  trait à l'écran (visé {project.outline})")
    for a in project.cfg["assets"]:
        if a["kind"] != "objects":
            continue
        for i in a["items"]:
            f = project.images / f"{i['name']}.png"
            if not f.exists():
                continue
            im = Image.open(f).convert("RGBA")
            t = bake.thickness(bake.outline_mask(np.asarray(im))) * bake.display_scale(i["size"], im)
            need = size_px(i["size"], project.scale)[1]
            have = im.height if i["size"][0] == "h" else im.width
            flag = ("  <- trait fin" if t < project.outline * 0.75 else "") + \
                   ("  <- trait épais" if t > project.outline * 2 else "") + \
                   ("  <- résolution faible" if have < need * 0.95 else "")
            print(f"{i['name']:20} {im.width:>5}x{im.height:<5}  {t:.2f}{flag}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) if "=" in a else (a[2:], True) for a in sys.argv[1:] if a.startswith("--"))
    if not args:
        print(__doc__)
        sys.exit(1)
    project = Project(opts.get("projet", "."))
    cmd, rest = args[0], args[1:]
    if cmd == "plan":
        cmd_plan(project)
    elif cmd == "prompt":
        cmd_prompt(project, rest[0])
    elif cmd == "gen":
        cmd_gen(project, rest[0], yes=bool(opts.get("oui")))
    elif cmd == "animate":
        cmd_animate(project, rest[0], yes=bool(opts.get("oui")))
    elif cmd == "budget":
        Budget(project.root).report()
    elif cmd == "cut":
        cmd_cut(project, rest[0])
    elif cmd == "bake":
        cmd_bake(project, rest)
    elif cmd == "build":
        cmd_gen(project, rest[0], yes=bool(opts.get("oui")))
        if opts.get("anim"):
            cmd_animate(project, rest[0], yes=bool(opts.get("oui")))
        cmd_cut(project, rest[0])
        cmd_bake(project, rest[:1])
    elif cmd == "report":
        cmd_report(project)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
