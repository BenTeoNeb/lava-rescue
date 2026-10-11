#!/usr/bin/env python3
"""Generate one image with a Gemini image model ("Nano Banana"), through the
Gemini API (REST, no extra library needed).

    python3 genimage.py OUT.png "prompt..." [--ref=style.png --ref=other.png]
                        [--ratio=16:9] [--size=2K] [--model=...]

Environment:
    GEMINI_API_KEY      required
    ART_IMAGE_MODEL     default: gemini-3-pro-image

--ratio: 1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9      (imageConfig.aspectRatio)
--size:  1K 2K 4K                                         (imageConfig.imageSize)
Budget: every call is estimated first and refused if it would go over the cap
(art.json "budget", or ART_BUDGET_CAP); a call costing more than
confirm_above_usd needs --oui. See budget.py.
Reference images (--ref) are sent with the prompt: use them for the style
reference and for "the same character as in the attached image".

The API changes over time: if a call fails, check the field names in
https://ai.google.dev/gemini-api/docs/image-generation and adjust build_body().
The returned size is printed: some versions ignore imageSize when reference
images are attached, so always check it.
"""

import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from budget import Budget  # noqa: E402

API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


def build_body(prompt, refs, ratio, size):
    parts = [{"text": prompt}]
    for ref in refs:
        mime = mimetypes.guess_type(ref)[0] or "image/png"
        parts.append({"inline_data": {"mime_type": mime,
                                      "data": base64.b64encode(Path(ref).read_bytes()).decode()}})
    config = {"responseModalities": ["IMAGE"], "imageConfig": {}}
    if ratio:
        config["imageConfig"]["aspectRatio"] = ratio
    if size:
        config["imageConfig"]["imageSize"] = size
    return {"contents": [{"parts": parts}], "generationConfig": config}


def generate(out, prompt, refs=(), ratio=None, size=None, model=None, yes=False, what=None, root=None):
    model = model or os.environ.get("ART_IMAGE_MODEL", "gemini-3-pro-image")
    # the budget first: estimate, refuse if over the cap or too expensive without --oui
    budget = Budget(root)
    cost = budget.image_cost(model, size)
    what = what or f"image {Path(out).stem}"
    budget.authorize(cost, what, yes)
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY n'est pas défini.")
    req = urllib.request.Request(
        API.format(model=model), method="POST",
        data=json.dumps(build_body(prompt, refs, ratio, size)).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"Erreur API {e.code} : {e.read().decode()[:800]}")
    for cand in data.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            blob = part.get("inlineData") or part.get("inline_data")
            if blob:
                Path(out).parent.mkdir(parents=True, exist_ok=True)
                Path(out).write_bytes(base64.b64decode(blob["data"]))
                budget.record(cost, what, model, out)
                try:
                    from PIL import Image
                    w, h = Image.open(out).size
                    print(f"OK {out} ({w}x{h})")
                except ImportError:
                    print(f"OK {out}")
                return out
    sys.exit("Pas d'image dans la réponse : " + json.dumps(data)[:800])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = {}
    refs = []
    for a in sys.argv[1:]:
        if a.startswith("--ref="):
            refs.append(a[6:])
        elif a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    generate(args[0], args[1], refs, opts.get("ratio"), opts.get("size"), opts.get("model"),
             yes="--oui" in sys.argv)


if __name__ == "__main__":
    main()
