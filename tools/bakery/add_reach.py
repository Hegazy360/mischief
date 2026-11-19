#!/usr/bin/env python3
"""add_reach — add or replace targeted reach clips in clips.json without disturbing its formatting.

    python3 tools/bakery/add_reach.py <spec.json>

spec: {"<who>": [{"name": "tinker_console", "from": "tinker", "reach": {...}, ...overrides}, ...]}
Each entry copies the clip named in `from` (its library clip, props, loop, face…), renames it, applies
the overrides and its `reach` block (docs/research/animation.md), and inserts it right after its source
(or replaces an existing entry of the same name). clips.json round-trips byte-for-byte through
json.dumps(indent=2), so the diff is exactly the added entries.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "clips.json")


def main() -> int:
    spec = json.load(open(sys.argv[1]))
    man = json.load(open(PATH))
    for who, entries in spec.items():
        clips = man["cast"][who]["clips"]
        for e in entries:
            src = next((c for c in clips if c["name"] == e["from"]), None)
            if src is None:
                print(f"[add_reach] {who}: no clip '{e['from']}'")
                return 1
            new = {k: v for k, v in src.items() if k != "name"}
            new = {"name": e["name"], **new, **{k: v for k, v in e.items() if k not in ("name", "from")}}
            old = next((i for i, c in enumerate(clips) if c["name"] == e["name"]), None)
            if old is not None:
                clips[old] = new
            else:
                clips.insert(clips.index(src) + 1, new)
            print(f"[add_reach] {who}/{e['name']} (from {e['from']})")
    with open(PATH, "w") as fh:
        fh.write(json.dumps(man, indent=2, ensure_ascii=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
