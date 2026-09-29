#!/usr/bin/env python3
"""Normalise content JSON style (owner: content): 2-space indent, UTF-8, containers kept on one line when
they fit in 116 columns. The data is unchanged (the round trip is asserted before writing).

Usage: python3 tools/content/fmt_json.py [--check] [files...]
       (no files = every content-owned file under game/data: items, pranks, activities, reactions,
        residues, barks, episodes/*, solutions/*.json)
--check exits 1 if any file would change.
"""
import glob
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WIDTH = 116


def _inline(v):
    return json.dumps(v, ensure_ascii=False, separators=(", ", ": "))


def dumps(v, depth=0, lead=0):
    s = _inline(v)
    if not isinstance(v, (dict, list)) or len(v) == 0 or depth * 2 + lead + len(s) <= WIDTH:
        return s
    pad = "  " * (depth + 1)
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            kk = json.dumps(k, ensure_ascii=False) + ": "
            parts.append(pad + kk + dumps(x, depth + 1, len(kk)))
        return "{\n" + ",\n".join(parts) + "\n" + "  " * depth + "}"
    return "[\n" + ",\n".join(pad + dumps(x, depth + 1, 0) for x in v) + "\n" + "  " * depth + "]"


def content_files():
    d = os.path.join(ROOT, "game", "data")
    out = [os.path.join(d, f) for f in ("items.json", "pranks.json", "activities.json", "reactions.json",
                                        "residues.json", "barks.json")]
    out += sorted(glob.glob(os.path.join(d, "episodes", "*.json")))
    out += sorted(glob.glob(os.path.join(d, "solutions", "*.json")))
    return [p for p in out if os.path.exists(p)]


def main(argv):
    check = "--check" in argv
    files = [a for a in argv if not a.startswith("--")] or content_files()
    changed = []
    for p in files:
        with open(p, encoding="utf-8") as f:
            old = f.read()
        data = json.loads(old)
        new = dumps(data) + "\n"
        assert json.loads(new) == data, p
        if new != old:
            changed.append(p)
            if not check:
                with open(p, "w", encoding="utf-8") as f:
                    f.write(new)
    for p in changed:
        print("[fmt_json] %s %s" % ("would change" if check else "formatted", os.path.relpath(p, ROOT)))
    print("[fmt_json] %d file(s), %d %s" % (len(files), len(changed), "to format" if check else "formatted"))
    return 1 if (check and changed) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
