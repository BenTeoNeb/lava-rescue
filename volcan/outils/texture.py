#!/usr/bin/env python3
"""Make a perfectly seamless ground tile from a drawing of little things
(grass tufts, flowers...) on a flat background.

    python3 volcan/outils/texture.py volcan/planches/sol_tuile.jpg herbe

Every little element is cut out of the drawing (skipping the ones touching the
border or a seam), then scattered at random on a new square tile of the same
background color. Elements that cross an edge come back on the other side, so
the tile repeats with no visible seam. -> images/herbe.png

Options: --taille=1024 (tile size in pixels), --densite=1.4 (more or fewer
elements than in the drawing), --graine=1 (another random arrangement).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from detourage import label  # noqa: E402

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "images"


def seams(gray, axis):
    """Rows (axis=0) or columns (axis=1) where the drawing changes abruptly."""
    d = np.abs(np.diff(gray, axis=axis)).mean(axis=1 - axis)
    return set(np.nonzero(d > 2.5 * np.median(d))[0].tolist())


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    src, name = Path(args[0]), args[1]
    size = int(opts.get("taille", 1024))
    density = float(opts.get("densite", 1.4))
    rng = np.random.default_rng(int(opts.get("graine", 1)))

    rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w = rgb.shape[:2]
    bg = np.median(rgb.reshape(-1, 3), axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    mask = dist > 22
    # join the strokes of one tuft together
    grown = mask.copy()
    for _ in range(3):
        g = grown.copy()
        g[1:] |= grown[:-1]; g[:-1] |= grown[1:]
        g[:, 1:] |= grown[:, :-1]; g[:, :-1] |= grown[:, 1:]
        grown = g
    labels, count = label(grown)
    gray = rgb.mean(axis=2)
    bad_rows, bad_cols = seams(gray, 0), seams(gray, 1)
    print(f"Fond : RGB{tuple(int(c) for c in bg)} — {count} éléments, "
          f"coutures : lignes {sorted(bad_rows)[:6]}…, colonnes {sorted(bad_cols)[:6]}…")

    # cut out each good element as a small RGBA sprite
    sprites = []
    objs = [None] * (count + 1)
    ys, xs = np.nonzero(labels)
    order = np.argsort(labels[ys, xs])
    ys, xs, ls = ys[order], xs[order], labels[ys, xs][order]
    bounds = np.searchsorted(ls, np.arange(1, count + 2))
    n_all = 0
    for i in range(1, count + 1):
        a, b = bounds[i - 1], bounds[i]
        if b - a < 30:
            continue
        n_all += 1
        y0, y1, x0, x1 = ys[a:b].min(), ys[a:b].max() + 1, xs[a:b].min(), xs[a:b].max() + 1
        if y0 <= 2 or x0 <= 2 or y1 >= h - 2 or x1 >= w - 2:
            continue
        if any(r in bad_rows for r in range(y0 - 3, y1 + 3)) or any(c in bad_cols for c in range(x0 - 3, x1 + 3)):
            continue
        piece = labels[y0:y1, x0:x1] == i
        alpha = np.clip((dist[y0:y1, x0:x1] - 8) / 30, 0, 1) * piece
        sprites.append(np.dstack([rgb[y0:y1, x0:x1], alpha]))
    print(f"{len(sprites)} éléments gardés")

    # scatter them on a new tile, wrapping around the edges
    tile = np.zeros((size, size, 3), np.float32) + bg
    taken = np.zeros((size, size), bool)
    # as many elements per area as in the drawing (counting the ones skipped too)
    wanted = int(density * n_all * size * size / (w * h))
    # pick them first, then place the biggest first (small ones fill the gaps)
    picks = [sprites[i] for i in rng.integers(len(sprites), size=wanted)]
    picks.sort(key=lambda s: -s.shape[0] * s.shape[1])
    placed = 0
    for s in picks:
        if rng.random() < 0.5:
            s = s[:, ::-1]
        sh, sw = s.shape[:2]
        for _ in range(80):
            x, y = rng.integers(size), rng.integers(size)
            yy = (np.arange(y, y + sh) % size)[:, None]
            xx = (np.arange(x, x + sw) % size)[None, :]
            if not taken[yy, xx].any():
                a = s[..., 3:4]
                tile[yy, xx] = tile[yy, xx] * (1 - a) + s[..., :3] * a
                taken[yy, xx] |= s[..., 3] > 0.05
                placed += 1
                break
    OUT.mkdir(exist_ok=True)
    Image.fromarray(np.clip(tile, 0, 255).astype(np.uint8)).save(OUT / f"{name}.png")
    print(f"{placed} éléments posés -> images/{name}.png ({size}x{size})")


if __name__ == "__main__":
    main()
