#!/usr/bin/env python3
"""swap_clip — point one timeline beat at another baked clip, without disturbing the file's formatting.

    python3 tools/stage/swap_clip.py act4 10.6 hush tinker tinker_console

Finds the `clip` event at time `t` for `who` currently playing `old` and renames it to `new`; also
renames a `move` event's `clip` at that time if it names `old`. Timelines round-trip byte-for-byte through
json.dumps(indent=1, ensure_ascii=False), so the diff is exactly that one name.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main() -> int:
    act, t, who, old, new = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
    path = os.path.join(ROOT, "game", "proto", act, f"{act}.json")
    raw = open(path, encoding="utf-8").read()
    d = json.loads(raw)
    hits = 0
    for e in d["events"]:
        if abs(float(e.get("t", -1)) - t) < 1e-6 and e.get("who") == who:
            if e.get("do") == "clip" and e.get("name") == old:
                e["name"] = new
                hits += 1
            elif e.get("do") == "move" and e.get("clip") == old:
                e["clip"] = new
                hits += 1
    if hits == 0:
        print(f"[swap_clip] {act} @ {t}s: no {who} beat playing '{old}'")
        return 1
    out = json.dumps(d, indent=1, ensure_ascii=False)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(out + ("\n" if raw.endswith("\n") else ""))
    print(f"[swap_clip] {act} @ {t}s: {who} {old} -> {new}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
