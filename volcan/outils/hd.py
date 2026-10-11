#!/usr/bin/env python3
"""Rebuild every image of the game for screens up to 4K, from the original
Gemini sheets (planches/), with even outlines (see bake.py).

    python3 volcan/outils/hd.py                 -> rebuilds images/
    python3 volcan/outils/hd.py --vers=DIR      -> into DIR instead (to compare)

The sizes below are how big each image is shown in the game (1280x720 units,
the biggest use). Change them here if you change them in the game.
"""

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402

HERE = Path(__file__).resolve().parent.parent          # volcan/
CACHE = HERE.parent / ".cache" / "hd"                  # full-resolution cut-outs

TREES = {"baobab": 130, "erable": 125, "fruitier": 120, "palmier": 140, "cerisier": 115, "sapin": 140,
         "saule": 130, "bouleau": 145, "epicea": 150, "chene": 135, "peuplier": 155, "pommier": 110}


def tree_sizes(names):
    return {n: f"h{round(TREES[n] * 1.1)}" for n in names} | \
           {n + "_brule": f"h{round(TREES[n] * 1.1)}" for n in names}


# sheet -> (names in reading order, {name: shown size})
SHEETS = {
    "animaux.jpg": (["renard", "poule", "ecureuil", "marcassin", "herisson"],
                    {"renard": "h55", "poule": "h51", "ecureuil": "h55", "marcassin": "h46", "herisson": "h41"}),
    "objets.jpg": (["champignon", "fleurs", "rocher", "buisson", "buche", "glands", "fougere", "feuille",
                    "pomme_de_pin", "branche"],
                   {"champignon": "h26", "fleurs": "h30", "rocher": "h26", "buisson": "h37", "buche": "h28",
                    "glands": "h21", "fougere": "h37", "feuille": "h15", "pomme_de_pin": "h19", "branche": "h19"}),
    "maisons.jpg": (["maison_rouge", "maison_bleue", "maison_jaune"], None),
    "cabanes1.jpg": (["cabane_souche", "cabane_coquillage", "cabane_pomme_de_pin"], None),
    "cabanes2.jpg": (["cabane_rondins", "cabane_champignon", "maison_bocaux"], None),
    "volcans.jpg": (["volcan_calme", "volcan_surpris", "volcan_fume", "volcan_erupt"], "w260"),
    "mares.jpg": (["mare", "mare_seche"], "w270"),
    "poissons1.jpg": ([f"poisson{i}" for i in range(1, 6)], "h24"),
    "poissons2.jpg": ([f"poisson{i}" for i in range(6, 11)], "h24"),
    "bocaux.jpeg": ([f"bocal{i}" for i in range(1, 7)], "h40"),
    "pierres.jpeg": ([f"pierre{i}" for i in range(1, 9)], "w40"),
    "epuisettes.jpg": (["epuisette", "epuisette_basse", "epuisette2", "epuisette_pleine"], "w75"),
    "_barriere_face.png": (["barriere_face"], "h30"),
    "_poteau.png": (["poteau"], "h32"),
    "_portillon.png": (["portillon"], "h44"),
}
for i, names in enumerate([["baobab", "erable", "fruitier"], ["palmier", "cerisier", "sapin"],
                           ["saule", "bouleau", "epicea"], ["chene", "peuplier", "pommier"]], 1):
    sizes = tree_sizes(names)
    SHEETS[f"arbres{i}.jpg"] = (names, sizes)
    SHEETS[f"arbres{i}_brules.jpg"] = ([n + "_brule" for n in names], sizes)
HUT = "h80"


def size_of(sizes, name):
    if sizes is None:
        return HUT
    return sizes if isinstance(sizes, str) else sizes[name]


def main():
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    dest = Path(opts.get("vers", HERE / "images"))
    dest.mkdir(parents=True, exist_ok=True)
    cutter = HERE / "outils" / "decoupe.py"
    low = []
    for sheet, (names, sizes) in SHEETS.items():
        # 1) cut the sheet again, at full resolution
        subprocess.run([sys.executable, str(cutter), str(HERE / "planches" / sheet), *names,
                        "--max=0", f"--sortie={CACHE}"], check=True, stdout=subprocess.DEVNULL)
        # 2) resize for 4K and even out the outline
        for name in names:
            size = size_of(sizes, name)
            im = Image.open(CACHE / f"{name}.png").convert("RGBA")
            big = bake.resize_to(im, size, bake.SCALE)
            if big.width > im.width:          # not enough detail: keep the original size
                big = im
                low.append(name)
            fixed, t = bake.thicken(np.asarray(big), bake.TARGET * bake.SCALE)
            Image.fromarray(np.ascontiguousarray(fixed), "RGBA").save(dest / f"{name}.png")
        print(f"  {sheet}: {', '.join(names)}")
    if low:
        print("Pas assez de détail pour la 4K (gardées à leur taille d'origine) :", ", ".join(low))


if __name__ == "__main__":
    main()
