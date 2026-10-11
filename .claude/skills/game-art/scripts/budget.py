#!/usr/bin/env python3
"""Budget for the image / video APIs: estimate every call before it is sent,
refuse it if it would go over the cap, and keep a ledger of what was spent.

Settings, in the game's art.json:
    "budget": { "cap_usd": 20, "confirm_above_usd": 1.0,
                "prices": { "my-model": { "1K": 0.05 } } }      (optional, overrides)
  cap_usd            hard limit for all spending recorded in the ledger
  confirm_above_usd  a single call costing more needs --oui (ask the user first)
Without art.json (scripts used alone): ART_BUDGET_CAP=20 in the environment.
No cap = no call.

Ledger: art_depenses.json next to art.json (one line per call actually made).

    python3 budget.py            spent, remaining, details

PRICES: Gemini API standard tier, USD, from public pricing in October 2026.
They change: check https://ai.google.dev/pricing and override them in art.json.
"""

import json
import os
import sys
import time
from pathlib import Path

PRICES = {
    # images: per image, by imageSize
    "gemini-3-pro-image": {"1K": 0.134, "2K": 0.134, "4K": 0.24},
    "gemini-2.5-flash-image": {"1K": 0.039, "2K": 0.039, "4K": 0.039},
    # videos: per second, by resolution
    "veo-3.1-generate": {"720p": 0.40, "1080p": 0.40, "4k": 0.60},
    "veo-3.1-fast-generate": {"720p": 0.10, "1080p": 0.12, "4k": 0.30},
    "veo-3.1-lite-generate": {"720p": 0.05, "1080p": 0.08},
}


class BudgetError(SystemExit):
    pass


class Budget:
    def __init__(self, root=None):
        self.root = Path(root or Path.cwd()).resolve()
        cfg_file = self.root / "art.json"
        cfg = json.loads(cfg_file.read_text()).get("budget", {}) if cfg_file.exists() else {}
        cap = cfg.get("cap_usd", os.environ.get("ART_BUDGET_CAP"))
        self.cap = float(cap) if cap is not None else None
        self.confirm_above = float(cfg.get("confirm_above_usd", 1.0))
        self.prices = {**PRICES, **cfg.get("prices", {})}
        self.ledger_file = self.root / "art_depenses.json"
        self.ledger = json.loads(self.ledger_file.read_text()) if self.ledger_file.exists() else []

    # -------------------------------------------------------------- prices

    def _table(self, model):
        # "gemini-3-pro-image-preview" -> "gemini-3-pro-image" (longest known prefix)
        for name in sorted(self.prices, key=len, reverse=True):
            if model.startswith(name):
                return self.prices[name]
        raise BudgetError(f"Prix inconnu pour le modèle « {model} » : ajoutez-le dans art.json "
                          f"(budget.prices) avant de l'utiliser.")

    def image_cost(self, model, size="1K", count=1):
        table = self._table(model)
        return table.get(size or "1K", max(table.values())) * count

    def video_cost(self, model, resolution="720p", seconds=8):
        table = self._table(model)
        return table.get((resolution or "720p").lower(), max(table.values())) * float(seconds)

    # -------------------------------------------------------------- the cap

    def spent(self):
        return sum(e["usd"] for e in self.ledger)

    def authorize(self, cost, what, yes=False):
        """Refuse (exit) if this call is not allowed. Prints the estimate."""
        if self.cap is None:
            raise BudgetError("Pas de plafond de budget : ajoutez \"budget\": {\"cap_usd\": ...} dans art.json "
                              "(ou ART_BUDGET_CAP). Aucun appel n'est fait sans plafond.")
        spent = self.spent()
        print(f"Coût estimé : ${cost:.2f} ({what}) — dépensé ${spent:.2f} / plafond ${self.cap:.2f}")
        if spent + cost > self.cap + 1e-9:
            raise BudgetError(f"Refusé : ${spent + cost:.2f} dépasserait le plafond de ${self.cap:.2f}. "
                              f"Il reste ${self.cap - spent:.2f}. Augmentez budget.cap_usd dans art.json si "
                              f"l'utilisateur le décide.")
        if cost > self.confirm_above and not yes:
            raise BudgetError(f"Cet appel coûte ${cost:.2f} (plus de ${self.confirm_above:.2f}) : demandez "
                              f"d'abord l'accord de l'utilisateur, puis relancez avec --oui.")

    def record(self, cost, what, model, file=None):
        self.ledger.append({"date": time.strftime("%Y-%m-%d %H:%M"), "what": what, "model": model,
                            "usd": round(cost, 4), "file": str(file) if file else None})
        self.ledger_file.write_text(json.dumps(self.ledger, indent=1, ensure_ascii=False) + "\n")

    # -------------------------------------------------------------- report

    def report(self):
        spent = self.spent()
        cap = f"${self.cap:.2f}" if self.cap is not None else "aucun (aucun appel possible)"
        print(f"Plafond : {cap}   dépensé : ${spent:.2f}" +
              (f"   reste : ${self.cap - spent:.2f}" if self.cap is not None else ""))
        if not self.ledger:
            print("Aucune dépense enregistrée.")
            return
        by = {}
        for e in self.ledger:
            key = e["what"].split(" ")[0]
            by.setdefault(key, [0, 0.0])
            by[key][0] += 1
            by[key][1] += e["usd"]
        print(f"\n{'quoi':24} {'appels':>6} {'coût':>8}")
        for key, (n, usd) in sorted(by.items(), key=lambda kv: -kv[1][1]):
            print(f"{key:24} {n:>6} {'$%.2f' % usd:>8}")
        print("\nDerniers appels :")
        for e in self.ledger[-8:]:
            print(f"  {e['date']}  ${e['usd']:.2f}  {e['what']}")


if __name__ == "__main__":
    Budget(sys.argv[1] if len(sys.argv) > 1 else None).report()
