#!/usr/bin/env python3
"""The R15 lean dead-air table (`docs/review/r3d-content/d1_lean.md`) from a `solve.sh --report` JSON.

For every route: the D1 gate as the sim credits it (PiP beats visible) next to the `d1_lean` recount (adjacency-only
PiP beats visible only with an emote, as edge beats inside the ≤ ⅓ cap), and the verdict against the persona's
thresholds (ideal ≤ 20 %, required ≤ 25 %, slow ≤ 30 %; worst gap ≤ 12 s; edge share ≤ ⅓). Scenario routes are info.

  python3 tools/content/d1_lean_md.py report.json > d1_lean.md
"""
import json
import sys


def main():
    rep = json.load(open(sys.argv[1]))
    runs = rep.get("runs", [])
    print("# d1_lean — the D1 gate if the Bellows window stayed closed on adjacency-only ticks (R15)\n")
    print("Source: `%s` (solve.sh --report). `lean` counts a PiP micro-gag whose `pip_reason` is `adjacent` as visible "
          "only when it has an emote (the HUD edge badge plays it: an edge beat); heading / rigging / room beats are "
          "unchanged. Thresholds: ideal ≤ 20 %%, required ≤ 25 %%, slow ≤ 30 %%, worst gap ≤ 12 s, edge share ≤ ⅓.\n" % sys.argv[1])
    print("| episode | route | persona | gate ⏩ dead air | gate gap | lean ⏩ dead air | lean gap | lean edge share | adjacency-only PiP beats | lean verdict |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    all_ok = True
    for r in runs:
        ln = r.get("d1_lean", {})
        persona = r.get("persona", "")
        gated = persona in ("ideal", "required", "slow")
        ok = bool(ln.get("ok", False))
        if gated and not ok:
            all_ok = False
        verdict = ("OK" if ok else "**FAIL** (%s)" % "; ".join(ln.get("fail", []))) if gated else "info"
        print("| %s | %s | %s | %.1f %% | %.1f s | %.1f %% | %.1f s | %.2f | %d of %d | %s |" % (
            r.get("episode"), r.get("route"), persona, r.get("dead_air_ff_pct", 0.0), r.get("max_gap_ff_s", 0.0),
            ln.get("dead_air_ff_pct", 0.0), ln.get("max_gap_ff_s", 0.0), ln.get("edge_share", 0.0),
            ln.get("beats", {}).get("adjacent_pip", 0), r.get("beats", {}).get("pip", 0), verdict))
    print("\n**Verdict:** d1_lean %s on every gated route." % ("passes D1" if all_ok else "does NOT pass D1"))


if __name__ == "__main__":
    main()
