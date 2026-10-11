#!/usr/bin/env python3
"""Generate a short video with Veo, through the Gemini API (REST), starting
from an image (image-to-video): used to animate a character.

    python3 genvideo.py OUT.mp4 START.png "prompt..." [--resolution=1080p]
                        [--seconds=8] [--ratio=16:9] [--model=...]

Environment:
    GEMINI_API_KEY      required
    ART_VIDEO_MODEL     default: veo-3.1-generate-preview

How it works: a long-running request (predictLongRunning), then the
operation is polled every 10 s until it is done, then the video is downloaded.

The API changes over time (models are renamed or replaced): if a call fails,
check https://ai.google.dev/gemini-api/docs/video and adjust build_body() or
the path to the video in video_uri(). --dry-run prints the request and its
cost instead. Budget: estimated first, refused over the cap (art.json
"budget" or ART_BUDGET_CAP); above confirm_above_usd it needs --oui.
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from budget import Budget  # noqa: E402

BASE = "https://generativelanguage.googleapis.com/v1beta"


def build_body(prompt, image, ratio, resolution, seconds):
    instance = {"prompt": prompt}
    if image:
        instance["image"] = {"bytesBase64Encoded": base64.b64encode(Path(image).read_bytes()).decode(),
                             "mimeType": "image/png" if image.endswith(".png") else "image/jpeg"}
    params = {"aspectRatio": ratio}
    if resolution:
        params["resolution"] = resolution
    if seconds:
        params["durationSeconds"] = int(seconds)
    return {"instances": [instance], "parameters": params}


def video_uri(op):
    """Where the finished operation puts the video (the shape has changed over
    versions: try the known ones)."""
    resp = op.get("response", {})
    for path in (("generateVideoResponse", "generatedSamples"), ("generatedVideos",), ("videos",)):
        node = resp
        for key in path:
            node = node.get(key, {}) if isinstance(node, dict) else {}
        if isinstance(node, list) and node:
            v = node[0].get("video", node[0])
            return v.get("uri") or v.get("gcsUri"), v.get("bytesBase64Encoded")
    return None, None


def call(url, key, body=None):
    req = urllib.request.Request(url, method="POST" if body else "GET",
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"Erreur API {e.code} : {e.read().decode()[:800]}")


def generate(out, image, prompt, ratio="16:9", resolution="1080p", seconds=8, model=None, dry=False,
             yes=False, what=None, root=None):
    model = model or os.environ.get("ART_VIDEO_MODEL", "veo-3.1-generate-preview")
    body = build_body(prompt, image, ratio, resolution, seconds)
    budget = Budget(root)
    cost = budget.video_cost(model, resolution, seconds)
    what = what or f"vidéo {Path(out).stem}"
    if dry:
        print(f"Coût estimé : ${cost:.2f} ({seconds} s en {resolution}, {model})")
        shown = json.loads(json.dumps(body))
        if image:
            shown["instances"][0]["image"]["bytesBase64Encoded"] = "<...>"
        print(f"POST {BASE}/models/{model}:predictLongRunning\n" + json.dumps(shown, indent=2))
        return
    budget.authorize(cost, what, yes)
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY n'est pas défini.")
    op = call(f"{BASE}/models/{model}:predictLongRunning", key, body)
    name = op["name"]
    print("Vidéo en cours de génération", end="", flush=True)
    while not op.get("done"):
        time.sleep(10)
        print(".", end="", flush=True)
        op = call(f"{BASE}/{name}", key)
    print()
    if "error" in op:
        sys.exit("Erreur : " + json.dumps(op["error"])[:800])
    uri, inline = video_uri(op)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    if inline:
        Path(out).write_bytes(base64.b64decode(inline))
    elif uri:
        req = urllib.request.Request(uri, headers={"x-goog-api-key": key})
        with urllib.request.urlopen(req, timeout=600) as r:
            Path(out).write_bytes(r.read())
    else:
        sys.exit("Pas de vidéo dans la réponse : " + json.dumps(op)[:800])
    budget.record(cost, what, model, out)
    print("OK", out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    generate(args[0], args[1], args[2], opts.get("ratio", "16:9"), opts.get("resolution", "1080p"),
             opts.get("seconds", 8), opts.get("model"), "--dry-run" in sys.argv, yes="--oui" in sys.argv)


if __name__ == "__main__":
    main()
