"""Shared background removal for the image and video tools.

A pixel counts as background when its color leans toward the background color
(even darker or lighter, like a cast shadow) AND it is connected to the edge
of the image. Thanks to the thick outlines, the inside of a character is never
touched, even a pink sweater on a magenta background.
"""

import numpy as np

LOW, HIGH = 0.30, 0.60   # "keyness": opaque below LOW, transparent above HIGH
# Holes enclosed by the drawing (between curls of hair, between the legs) are
# only removed when they are clearly pure background color.
HOLE_LOW, HOLE_HIGH = 0.55, 0.75


def background_color(rgb):
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    return np.median(border, axis=0)


def keyness(rgb, bg):
    """How much each pixel's color leans toward the background color
    (1 = same hue as the background, 0 = unrelated), ignoring brightness."""
    bg_chroma = bg - bg.mean()
    chroma = rgb - rgb.mean(axis=2, keepdims=True)
    return (chroma * bg_chroma).sum(axis=2) / (bg_chroma ** 2).sum()


def label(mask):
    """Connected blobs of True pixels (4-neighbours). Returns (labels, count)."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    count = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0]:
            continue
        count += 1
        stack = [(y0, x0)]
        while stack:
            y, x = stack.pop()
            if labels[y, x]:
                continue
            # fill the whole horizontal run at once
            l = x
            while l > 0 and mask[y, l - 1] and not labels[y, l - 1]:
                l -= 1
            r = x
            while r < w - 1 and mask[y, r + 1] and not labels[y, r + 1]:
                r += 1
            labels[y, l:r + 1] = count
            for ny in (y - 1, y + 1):
                if 0 <= ny < h:
                    row = mask[ny, l:r + 1] & (labels[ny, l:r + 1] == 0)
                    for nx in np.nonzero(row)[0]:
                        stack.append((ny, l + nx))
    return labels, count


def outside(mask):
    """Pixels of `mask` that are connected to the image border."""
    labels, _ = label(mask)
    ids = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    ids.discard(0)
    return np.isin(labels, list(ids))


def cut_out(rgb, bg=None):
    """Returns (clean_rgb, alpha) as float arrays."""
    rgb = rgb.astype(np.float32)
    if bg is None:
        bg = background_color(rgb)
    k = keyness(rgb, bg)
    out = outside(k > LOW)
    alpha = np.where(out, 1 - np.clip((k - LOW) / (HIGH - LOW), 0, 1),
                     1 - np.clip((k - HOLE_LOW) / (HOLE_HIGH - HOLE_LOW), 0, 1))
    # remove the background tint left on soft edges
    a = np.maximum(alpha, 1e-3)[..., None]
    clean = np.clip((rgb - (1 - a) * bg) / a, 0, 255)
    return clean, alpha
