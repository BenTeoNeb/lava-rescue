---
name: game-art
description: Create all the art of a 2D game with image and video generation APIs (Gemini image / "Nano Banana", Veo) in one consistent style, sized for screens up to 4K - style reference, decor, objects, seamless ground tiles, characters and their animations (walk, run, jump...). Use when the user wants to make, regenerate or add sprites, sheets, tiles, characters or animations for a game, or asks for image/video prompts for game art.
---

# Game art: consistent style, right sizes, 4K, smooth animations

This is the method behind "Lava Rescue!" (volcan/), turned into tools.
Everything is driven by an `art.json` file in the game folder (format below)
and `scripts/art.py`. Run the commands **from the game folder**.

Needs Python 3 with `numpy`, `Pillow` and `opencv-python` (use the Python
that has them: `python3 -c "import numpy, PIL, cv2"`).

API keys (environment): `GEMINI_API_KEY`. Models: `ART_IMAGE_MODEL`
(default `gemini-3-pro-image`), `ART_VIDEO_MODEL` (default
`veo-3.1-generate-preview`). These APIs change often: on the first call, check
the request against the official docs (links in `scripts/genimage.py` and
`scripts/genvideo.py`), and check the size of what comes back.
Without API keys everything still works by hand: `art.py prompt SHEET` prints
the prompt to paste in Gemini, then save the result in `planches/` and go on
with `cut` and `bake`.

## Budget (read before any API call)

Every image / video call costs money and **is checked by the scripts**:
estimated before it is sent, refused if it would go over the cap
(`art.json` → `"budget": {"cap_usd": 20, "confirm_above_usd": 1.0}`), and
recorded in `art_depenses.json` when it succeeds. No cap = no call.

Rules for Claude:
- Before generating, run `art.py plan` and **tell the user what it will cost**
  (one sheet ≈ $0.13–0.24, one character video ≈ $3.20 at the default prices;
  count 2–3 tries per sheet).
- A call above `confirm_above_usd` stops and asks for `--oui`: **ask the user
  first**, never add `--oui` on your own.
- **Never raise `cap_usd`** without the user saying so. When the budget runs
  out, say what is left to do and what it would cost.
- Prefer cheap retries: fix a sheet with a follow-up prompt rather than many
  blind regenerations; test a new prompt on one item before a whole sheet.
- `art.py budget` shows spent / left / last calls; tell the user after a batch.
- Prices are in `scripts/budget.py` (October 2026, standard tier) and can be
  overridden in `art.json` → `budget.prices`. An unknown model is refused until
  it has a price. When 1K and 2K cost the same, 2K is requested (free pixels).

## Quality: what made our API results worse than the user's (avoid it)

- **Regenerating an existing item: attach its current image** (`refs` in
  art.json) and keep its original, detailed description. A short description
  ("a cute volcano") lets the model invent a new design.
- **Never contradict the style block** in a note (e.g. "thin outline" when the
  style says "thick outline"): the model compromises and both get worse.
- **Few constraints per image.** Fewer items, ordinary landscape format.
- **The user picks.** One API call = one try; in the Gemini app the user
  iterates and keeps the best. Show every result, offer a retry or 2-3
  variants for important images, and never cut/install without approval. For
  hero images, the user's own app workflow may simply be better: then use the
  skill for sizes, cutting, 4K and outlines.

## The rules that matter (learned the hard way)

1. **One style, fixed first — use the user's own reference image.** If the
   user already made the art (e.g. in the Gemini app), ASK for the style
   reference image they used and put it in `style.reference`: a real
   generated image is a far better model than a collage of cut-outs. Never
   generate a new one then. `gen` refuses to replace an existing reference.
   Otherwise: Write the style block once (art.json
   `style.text`), generate a **style reference** lineup (kind `style`), let the
   user approve it, save it as `style.reference`. Every later generation
   attaches it ("Use the attached image as the strict style reference").
2. **Know the on-screen size of everything** (`size`: `h55` = shown 55 units
   high, `w270` = 270 wide, in the game's own coordinates, e.g. 1280x720). The
   biggest screen is `max_scale` times that (3 = 4K for a 1280x720 game). An
   image needs **size x max_scale pixels**; more is wasted, less is blurry.
   `art.py plan` checks this for every sheet before any generation.
3. **Outlines: the shrink factor decides the line thickness.** A drawing
   shrunk 14x gets a hair-thin outline, one shrunk 2x keeps a thick one.
   So: put **items of similar on-screen size on the same sheet** (plan warns
   when sizes differ more than 2x), ask Gemini to draw them **to scale**
   (the prompt does it), and let `bake` **thicken** outlines that are still too
   thin. It never thins an outline (that damages the drawing): if one is far
   too thick, regenerate it ("thinner outline").
4. **Flat magenta background (#FF00FF)** for everything cut out; green
   (#00FF00) for videos. The keying only removes background connected to the
   image border, so a pink dress inside a dark outline is safe.
5. **Big, separated items.** "big empty gaps between them, never touch"; one
   row up to 5 items, a grid beyond (cut in reading order). Gemini often
   ignores the exact layout: check with `decoupe.py ... --apercu`.
6. **Animations = one Veo video per character**, 8 s, walking/running/
   jumping... in place, on green, with a timestamped prompt, starting from the
   character's still image. Veo films at **24 fps: keep every frame** (12 fps
   looks choppy next to smooth movement). Frame height = on-screen height x
   max_scale / 0.9. Loops are found automatically (with a minimum length, so
   a single step is not mistaken for a full cycle). Veo rarely respects the
   timestamps: always look at the contact sheet and set `ranges` if needed.
7. **Seamless tiles**: Gemini's "seamless" textures usually repeat inside and
   have seams. `texture.py` rebuilds a truly seamless tile from the little
   elements of the drawing (cut, skip damaged ones, scatter with wrap-around).
8. **In the game**: load images with mipmaps (smaller screens use smaller
   versions), make fonts for the real screen size (`love.graphics.newFont(size,
   "normal", scale)`), no MSAA on 4K/5K screens (it cost ~25% speed), load all
   images at launch (no stutter mid-game), animation frames in a grid no wider
   than 4096 px.

## Workflow

```
art.py plan                     # check sizes and sheets
art.py essai SHEET              # a 1K trial first: show it, the user validates the style
art.py upscale SHEET            # then the SAME picture at full resolution (a new "gen"
                                # would be a new random draw, not the approved one)
art.py gen style                # 1. the style reference -> user approves -> art.json style.reference
art.py build animals            # 2. each sheet: generate, cut, bake
art.py gen zina                 # 3. a character: still image first...
art.py animate zina             #    ...then its video (look at videos/zina_planche.png)
art.py cut zina && art.py bake zina
art.py cut ground               # 4. a tile
art.py report                   # resolution + outline of everything
art.py budget                   # what was spent, what is left
```
Always show the user each generated sheet before cutting, and the before /
after when replacing images in a game.

## art.json

```json
{
  "game": { "max_scale": 3, "outline": 0.9, "fps": 24 },
  "budget": { "cap_usd": 20, "confirm_above_usd": 1.0 },
  "style": { "text": "ART STYLE: ...", "reference": "planches/reference.png" },
  "paths": { "sheets": "planches", "videos": "videos", "images": "images", "cache": "../.cache/art" },
  "assets": [
    { "sheet": "style", "kind": "style", "desc": "a small boy..., a red fox, a white hen, a round tree" },
    { "sheet": "animals", "kind": "objects", "items": [
        { "name": "fox", "desc": "a cute baby red fox...", "size": "h55" },
        { "name": "hen", "desc": "a cute plump white hen...", "size": "h51" } ] },
    { "sheet": "trees", "kind": "objects", "view": "side view, full tree with trunk", "items": [...] },
    { "sheet": "ground", "kind": "tile", "desc": "short green grass with small tufts...", "tile": 380 },
    { "sheet": "zina", "kind": "character", "name": "zina", "size": "h126",
      "desc": "cute girl about 7 years old, dark curly hair, pink sweater, jeans",
      "actions": { "marche": "Walks in place: two smooth, regular walk cycles.",
                   "course": "Runs in place, fast: two regular run cycles.",
                   "saut": "Jumps straight up in place and lands, twice.",
                   "aie": "Hops up in surprise, hands on the bottom, funny ouch face." },
      "ranges": { "marche": "6-45", "course": "48-83" } }
  ]
}
```
- `kind`: `style`, `objects` (decor, props, huts, trees, items: any sheet of
  separate drawings), `tile`, `character`.
- `grid` (optional): force a layout, e.g. `[2, 2]` (avoid very wide 4K
  sheets: they tend to come back with doubled, ghosted drawings).
- `note` (optional): an extra sentence for this sheet's prompt (never one
  that contradicts the style block).
- `refs` (optional): extra reference images for this sheet, e.g. the current
  sheet when regenerating it, so the design is kept.
- `aspect` (optional): width / height of one drawing (default 1.3 for things
  seen from the side, use ~0.8 for trees, volcanoes, jars).
- `size`: the biggest on-screen size of the item (if it is shown at several
  sizes, the biggest).
- `ranges` (optional): video frames of each action (24 per second), when the
  default timeline is wrong. Output: `images/<name>_<action>.png` (frames in a
  grid) + `images/<name>.lua` (frame size, count, columns, fps, loops).

Known limit: the outline measure is unreliable on tiny drawings (a pebble
can read 0): check them by eye.

A full example: `volcan/art.json` (every sheet of "Lava Rescue!").

## Files

- `scripts/art.py`: the pipeline (above).
- `scripts/genimage.py`, `scripts/genvideo.py`: the API calls (`--dry-run`
  for the video request and its cost).
- `scripts/budget.py`: prices, cap, ledger (`python3 budget.py` = report).
- `scripts/decoupe.py` (cut a sheet), `scripts/detourage.py` (keying),
  `scripts/bake.py` (4K size + outline), `scripts/texture.py` (seamless tile),
  `scripts/video.py` (video -> animation frames).
- `reference/prompts.md`: all the prompt templates, and fixes when Gemini /
  Veo get it wrong.
