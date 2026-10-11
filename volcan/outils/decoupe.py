#!/usr/bin/env python3
"""Cut a Gemini "sheet" (several drawings in a row on a flat magenta
background) into separate transparent PNGs for the game.

    python3 outils/decoupe.py planches/animaux.png renard poule ecureuil marcassin herisson

The names are given in reading order: row by row, left to right
(a single column is read top to bottom). Each drawing is saved as images/<name>.png.
Use --apercu to only save a preview of what was detected (images/_apercu.png).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from detourage import background_color, cut_out, label

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "images"
MAX_HEIGHT = 512        # bigger is useless in the game


def grow(mask, n):
    """Make a mask n pixels fatter."""
    out = mask.copy()
    for _ in range(n):
        m = out.copy()
        m[1:] |= out[:-1]
        m[:-1] |= out[1:]
        m[:, 1:] |= out[:, :-1]
        m[:, :-1] |= out[:, 1:]
        out = m
    return out


def find_drawings(solid, wanted):
    """Masks of the `wanted` biggest drawings, left to right."""
    # work on a smaller copy: much faster, and joins tiny gaps inside a drawing
    k = max(1, max(solid.shape) // 500)
    small = solid[::k, ::k]
    small = grow(small, 2)
    labels, count = label(small)
    sizes = [(labels == i).sum() for i in range(1, count + 1)]
    best = sorted(range(1, count + 1), key=lambda i: sizes[i - 1], reverse=True)[:wanted]
    # reading order: row by row (top to bottom), left to right in each row.
    # Works for a single row, a single column, or a grid.
    info = {}
    for i in best:
        ys, xs = np.nonzero(labels == i)
        info[i] = (ys.mean(), xs.mean(), ys.max() - ys.min())
    by_y = sorted(best, key=lambda i: info[i][0])
    rows = []
    for i in by_y:
        if rows and info[i][0] - info[rows[-1][0]][0] < 0.5 * np.median([v[2] for v in info.values()]):
            rows[-1].append(i)
        else:
            rows.append([i])
    best = [i for row in rows for i in sorted(row, key=lambda i: info[i][1])]
    masks = []
    for i in best:
        m = np.repeat(np.repeat(labels == i, k, axis=0), k, axis=1)
        m = m[:solid.shape[0], :solid.shape[1]]
        pad = np.zeros_like(solid)
        pad[:m.shape[0], :m.shape[1]] = m
        masks.append(grow(pad, k + 2))
    return masks


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    preview = "--apercu" in sys.argv
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    sheet, names = Path(args[0]), args[1:]

    rgb = np.asarray(Image.open(sheet).convert("RGB")).astype(np.float32)
    bg = background_color(rgb)
    clean, alpha = cut_out(rgb, bg)
    solid = alpha > 0.5

    drawings = find_drawings(solid, len(names))

    print(f"Fond détecté : RGB{tuple(int(c) for c in bg)} — {len(drawings)} dessin(s) trouvé(s)")
    if len(drawings) < len(names):
        print(f"Attention : {len(names)} noms mais seulement {len(drawings)} dessins.")

    if preview:
        img = Image.open(sheet).convert("RGB")
        d = ImageDraw.Draw(img)
        for m, name in zip(drawings, names):
            ys, xs = np.nonzero(m & solid)
            d.rectangle([xs.min(), ys.min(), xs.max(), ys.max()], outline=(0, 200, 0), width=4)
            d.text((xs.min() + 8, ys.min() + 8), name, fill=(0, 0, 0))
        img.save(OUT / "_apercu.png")
        print("Aperçu :", OUT / "_apercu.png")
        return

    OUT.mkdir(exist_ok=True)
    for m, name in zip(drawings, names):
        ys, xs = np.nonzero(m & solid)
        pad = 4
        y0, x0 = max(0, ys.min() - pad), max(0, xs.min() - pad)
        y1, x1 = min(rgb.shape[0], ys.max() + 1 + pad), min(rgb.shape[1], xs.max() + 1 + pad)
        a = alpha[y0:y1, x0:x1] * m[y0:y1, x0:x1]   # hide bits of the neighbours
        rgba = np.dstack([clean[y0:y1, x0:x1], a * 255]).astype(np.uint8)
        piece = Image.fromarray(rgba, "RGBA")
        if piece.height > MAX_HEIGHT:
            w = round(piece.width * MAX_HEIGHT / piece.height)
            piece = piece.resize((w, MAX_HEIGHT), Image.LANCZOS)
        piece.save(OUT / f"{name}.png")
        print(f"  {name}.png  ({piece.width}x{piece.height})")


if __name__ == "__main__":
    main()
