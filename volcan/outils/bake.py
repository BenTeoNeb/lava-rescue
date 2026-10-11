#!/usr/bin/env python3
"""Prepare the images for every screen up to 4K, with outlines of the same
thickness everywhere.

For each image, the game shows it at a known size. This tool:
  1. resizes the full-resolution cut-out to 3x that size (= 4K; smaller screens
     use smaller versions automatically, LÖVE "mipmaps");
  2. measures the dark outline and thickens it where it got too thin from
     shrinking, so all images look drawn with the same pencil (it never makes
     an outline thinner: that damages the drawing).

    python3 volcan/outils/bake.py SOURCE_DIR OUT_DIR name:size [name:size ...]

size: "h70" = shown 70 px high, "w270" = shown 270 px wide (in the game's
1280x720 units). Add --mesure to only print the outline thickness.
"""

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

SCALE = 3            # 4K = 3x the game's 1280x720
TARGET = 0.9         # outline thickness on screen, in the game's 1280x720 units
                     # (the characters' outline: kids 0.7, animals 0.8-0.9)
DARK = 80            # an outline pixel is darker than this (0-255)


def outline_mask(rgba):
    """The dark LINES of the drawing (not dark areas like hair or rock):
    dark pixels, minus what survives an "opening" (which erases thin lines and
    keeps big patches)."""
    rgb, alpha = rgba[..., :3].astype(np.float32), rgba[..., 3]
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    dark = ((alpha > 128) & (lum < DARK)).astype(np.uint8)
    k = max(7, int(0.035 * max(rgba.shape[:2])) | 1)
    patches = cv2.morphologyEx(dark, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    patches = cv2.dilate(patches, np.ones((3, 3), np.uint8))
    return dark.astype(bool) & ~patches.astype(bool)


def thickness(mask):
    """Average thickness of the strokes in a mask: 2 x area / perimeter."""
    m = mask.astype(np.uint8)
    contours, _ = cv2.findContours(m, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    perimeter = sum(cv2.arcLength(c, True) for c in contours)
    return 2 * m.sum() / perimeter if perimeter else 0


def display_scale(size, im):
    """How much the image is shrunk on a 1280x720 screen."""
    kind, n = size[0], float(size[1:])
    return n / (im.height if kind == "h" else im.width)


def resize_to(im, size, factor):
    s = display_scale(size, im) * factor
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def thicken(rgba, target_px):
    """Make the dark outline at least target_px thick (never thinner: thinning
    damages the drawing). Done on a 2x bigger copy, then shrunk back, so the
    new edges are smooth. Returns (image, thickness before)."""
    mask = outline_mask(rgba)
    t = thickness(mask)
    if t == 0 or t >= target_px:
        return rgba, t
    big = np.asarray(Image.fromarray(rgba, "RGBA").resize((rgba.shape[1] * 2, rgba.shape[0] * 2), Image.LANCZOS)).copy()
    bmask = outline_mask(big)
    k = int(round((target_px - t)))      # in the 2x copy: half on each side
    if k <= 0:
        return rgba, t
    dark = np.median(big[bmask][:, :3], axis=0)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * k + 1, 2 * k + 1))
    grown = cv2.dilate(bmask.astype(np.uint8), kernel).astype(bool)
    big[grown, :3] = dark
    big[grown, 3] = 255
    out = Image.fromarray(big, "RGBA").resize((rgba.shape[1], rgba.shape[0]), Image.LANCZOS)
    return np.asarray(out), t


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_measure = "--mesure" in sys.argv
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    src, dst = Path(args[0]), Path(args[1])
    dst.mkdir(parents=True, exist_ok=True)
    print(f"{'image':16} {'source':>11} {'4K':>11}  trait à l'écran (1280x720)")
    for spec in args[2:]:
        name, size = spec.split(":")
        im = Image.open(src / f"{name}.png").convert("RGBA")
        # outline thickness as seen on screen today
        seen = thickness(outline_mask(np.asarray(im))) * display_scale(size, im)
        big = resize_to(im, size, SCALE)
        enough = "" if big.width <= im.width else "  (source trop petite pour la 4K)"
        if only_measure:
            print(f"{name:16} {im.width:>5}x{im.height:<5} {big.width:>5}x{big.height:<5}  {seen:.2f}{enough}")
            continue
        fixed, t = thicken(np.asarray(big), TARGET * SCALE)
        after = thickness(outline_mask(fixed)) / SCALE
        Image.fromarray(fixed, "RGBA").save(dst / f"{name}.png")
        print(f"{name:16} {im.width:>5}x{im.height:<5} {big.width:>5}x{big.height:<5}  {seen:.2f} -> {after:.2f}{enough}")


if __name__ == "__main__":
    main()
