#!/usr/bin/env python3
"""Summary of the logged games (journal.lua), to improve the gameplay.

    python3 volcan/outils/parties.py            all games
    python3 volcan/outils/parties.py --detail   + one line per game

Reads the game's save folder (macOS: ~/Library/Application Support/LOVE/
sauve-les-animaux/parties/, Linux: ~/.local/share/love/sauve-les-animaux/parties/),
or the folder given with --dossier=...
"""

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

FOLDERS = [Path.home() / "Library/Application Support/LOVE/sauve-les-animaux/parties",
           Path.home() / ".local/share/love/sauve-les-animaux/parties"]


def load(folder):
    games = []
    for f in sorted(folder.glob("*.jsonl")):
        lines = [json.loads(l) for l in f.read_text().splitlines() if l.strip()]
        if lines:
            games.append((f.name, lines))
    return games


def pct(a, b):
    return f"{100 * a / b:.0f}%" if b else "-"


def main():
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    folder = Path(opts["dossier"]) if "dossier" in opts else next((f for f in FOLDERS if f.exists()), FOLDERS[0])
    games = load(folder)
    if not games:
        print(f"Aucune partie enregistrée dans {folder}")
        return
    ends = Counter()
    by_mode = defaultdict(list)
    by_kid = defaultdict(list)
    events = Counter()
    lost_kinds, saved_kinds = Counter(), Counter()
    burns = []
    full_per_game = []
    fox_conflicts = 0
    for name, lines in games:
        start, end = lines[0], lines[-1]
        if end.get("e") != "fin":
            end = {"comment": "interrompu", "score": None}
        ends[end["comment"]] += 1
        mode = f"{start.get('mode')} {start.get('joueurs')}J"
        for e in lines:
            events[e["e"]] += 1
            if e["e"] == "aie":
                burns.append((e.get("x"), e.get("y")))
            if e["e"] == "renard":
                fox_conflicts += 1
        full_per_game.append(sum(1 for e in lines if e["e"] == "plein"))
        if end["comment"] == "fin":
            by_mode[mode].append(end)
            for k in start.get("enfants", []):
                by_kid[k].append(end["score"] / end["total"])
            saved_kinds.update(end.get("sauves", {}))
            lost_kinds.update(end.get("pas_sauves", {}))
        if "--detail" in sys.argv:
            print(f"{name}  {mode:10} {'+'.join(start.get('enfants', [])):14} "
                  f"{end['comment']:9} score {end.get('score')}/{end.get('total')} "
                  f"étoiles {end.get('etoiles')} durée {end.get('duree')} s")

    print(f"\n{len(games)} parties ({folder})")
    print("Fin :", ", ".join(f"{k} {v} ({pct(v, len(games))})" for k, v in ends.items()))
    print("\nPar mode (parties finies) :")
    for mode, ends_ in sorted(by_mode.items()):
        scores = [e["score"] / e["total"] for e in ends_]
        stars = Counter(e["etoiles"] for e in ends_)
        print(f"  {mode:10} {len(ends_):3} parties  score moyen {100 * sum(scores) / len(scores):.0f}%  "
              f"étoiles {dict(sorted(stars.items()))}  durée moyenne {sum(e['duree'] for e in ends_) / len(ends_):.0f} s")
    print("\nPar personnage (score moyen) :")
    for k, s in sorted(by_kid.items()):
        print(f"  {k:6} {100 * sum(s) / len(s):.0f}%  ({len(s)} parties)")
    print("\nAnimaux : sauvés / perdus")
    for k in sorted(set(saved_kinds) | set(lost_kinds)):
        print(f"  {k:10} {saved_kinds[k]:4} / {lost_kinds[k]:4}   ({pct(saved_kinds[k], saved_kinds[k] + lost_kinds[k])} sauvés)")
    print("\nÉvénements (total) :", ", ".join(f"{k} {v}" for k, v in events.most_common() if k not in ("positions", "debut", "fin")))
    print(f"Conflits renard : {fox_conflicts}   brûlures d'enfants : {len(burns)}   "
          f"« plein » par partie : {sum(full_per_game) / len(full_per_game):.1f}")


if __name__ == "__main__":
    main()
