#!/usr/bin/env python3
"""Content catalogue exporter + GDD diff (owner: content).

Reads game/data/{pranks,items,activities,residues}.json and game/data/episodes/*.json and writes
docs/review/content/catalogue.md: one table of all 32 pranks (id, caption, size, rig point, needs, prep,
trigger, residue, nights) and one table per episode (loop, lines, req, Big Number).

It then diffs the data against docs/GDD.md by parsing the GDD text:
  * §5.7 catalogue: every `#n `id` CAPTION** (size)` entry -> caption, size and Nights must match pranks.json;
  * §7.2 episodes: the backticked activities of each Night's "Loop" bullet must equal the episode loop, and
    every Script line text must appear as a quoted string in that Night's GDD block.
Any mismatch is printed and the exit code is 1 — except the documented D1 deviations in `DEVIATIONS` below
(`docs/review/s2-content/d1_changes.md`): a listed field is accepted only when the data equals the documented
value exactly (anything else still fails), and an entry the GDD has caught up with is reported as stale.

Usage: python3 tools/content/catalogue.py [--no-write] [--out docs/review/content/catalogue.md]
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "game", "data")
GDD = os.path.join(ROOT, "docs", "GDD.md")
EP_ORDER = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy", "n03_singing_in_the_bath", "n04_the_big_sulk",
            "n05_enter_beryl", "n06_behind_you", "n07_kidding_around", "n08_companys_coming", "n09_tutu_much",
            "n10_it_takes_two", "gala_the_comeback"]
NIGHT_TOKEN = {"P": "p00_curtain_up", "G": "gala_the_comeback"}
for i, e in enumerate(EP_ORDER[1:11], start=1):
    NIGHT_TOKEN[str(i)] = e
SHORT = {v: k for k, v in NIGHT_TOKEN.items()}
PREP = {"Q": "Q 0.8 s", "S": "S 1.5 s", "B": "B 2.5 s"}
# Documented GDD deviations (Stage 2, lead decision D1): {episode: {field: (exact data value, reason)}}.
# The orchestrator folds them into GDD §7.2; once the GDD text matches, the entry is reported stale.
DEVIATIONS = {
    "n01_throat_tea": {
        "loop": (["warmup", "tea", "pickles", "rinse", "tea", "paper"],
                 "D1: two kettle windows per loop and a 58.7 s loop (d1_changes.md N01-1)"),
    },
    "n02_something_fishy": {
        "loop": (["paper", "fire", "snack", "mirror", "phone", "clock"],
                 "D1: the same cycle rotated to start kitchen-side, first prank 19.4 s (d1_changes.md N02-1)"),
    },
}


def load(rel):
    with open(os.path.join(DATA, rel), encoding="utf-8") as f:
        return json.load(f)


def load_episodes():
    eps = {}
    for p in sorted(glob.glob(os.path.join(DATA, "episodes", "*.json"))):
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        eps[d["id"]] = d
    return eps


# ---------------------------------------------------------------- GDD parsing
def gdd_catalogue(text):
    """{id: {"n", "caption", "size", "nights": [episode ids], "bn": [episode ids]}} from GDD §5.7."""
    start = text.index("### 5.7")
    end = text.index("### 5.8")
    sec = text[start:end]
    entries = re.split(r"\n- \*\*#", sec)[1:]
    out = {}
    night_re = re.compile(r"^\s*((?:P|G|\d+)(?:\s*\(BN\))?(?:\s*,\s*(?:P|G|\d+)(?:\s*\(BN\))?)*)\s*\.")
    for ent in entries:
        ent = " ".join(line.strip() for line in ent.splitlines())
        m = re.match(r"(\d+) `([a-z_]+)` (.+?)\*\* \(([^)]*)\)", ent)
        if not m:
            continue
        n, pid, caption, size_txt = m.group(1), m.group(2), m.group(3).strip(), m.group(4)
        size = size_txt.split(",")[0].strip()
        size = "SIG" if size == "★" else size
        nights, bn = [], []
        for seg in reversed(ent.split(" · ")):
            nm = night_re.match(seg)
            if nm:
                for tok in nm.group(1).split(","):
                    tok = tok.strip()
                    key = tok.split("(")[0].strip()
                    nights.append(NIGHT_TOKEN[key])
                    if "(BN)" in tok:
                        bn.append(NIGHT_TOKEN[key])
                break
        out[pid] = {"n": int(n), "caption": caption, "size": size, "nights": nights, "bn": bn}
    return out


def gdd_nights(text):
    """{episode id: block text} for every Night in GDD §7.2."""
    start = text.index("### 7.2")
    end = text.index("### 7.3")
    sec = text[start:end]
    heads = list(re.finditer(r"^\*\*(PROLOGUE|Night (\d+)|GALA NIGHT)[^\n]*\*\*[^\n]*$", sec, re.M))
    out = {}
    for i, h in enumerate(heads):
        body = sec[h.start(): heads[i + 1].start() if i + 1 < len(heads) else len(sec)]
        if h.group(1) == "PROLOGUE":
            eid = "p00_curtain_up"
        elif h.group(1) == "GALA NIGHT":
            eid = "gala_the_comeback"
        else:
            eid = NIGHT_TOKEN[h.group(2)]
        out[eid] = body
    return out


def gdd_loop(block):
    """Backticked activity ids of the block's Loop bullet, in order."""
    m = re.search(r"Loop[^:]*:(.*?)(?:\n- |\n\n|$)", block, re.S)
    if not m:
        return []
    loop_txt = m.group(1)
    loop_txt = re.split(r"\.\s+(?:Beryl|Delphine|Script)", loop_txt)[0]
    return re.findall(r"`([a-z_]+)`", loop_txt)


# ---------------------------------------------------------------- export
def fmt_trigger(t):
    ty = t["type"]
    if ty == "use":
        s = "USE `%s` @%g s" % (t["activity"], t["mark_s"])
        if t.get("resume"):
            s += " (resume)"
        if t.get("fixup_kinds"):
            s += " + %s fix-ups" % "/".join(t["fixup_kinds"])
        return s
    if ty == "third_party":
        return "3RD PARTY %s:%s in `%s` @%g s" % (t["actor"], t["event"], t["activity"], t["mark_s"])
    if ty == "step":
        at = t["at"] if isinstance(t["at"], str) else "+".join(t["at"])
        return "STEP %s (%s%s)" % (at, t.get("dir", "any"), ", chase" if t.get("chase") else "")
    if ty == "quake":
        return "QUAKE in %s" % t["room"]
    return ty


def fmt_residue(p):
    parts = []
    for r in p.get("residue", []):
        s = r["kind"]
        if r.get("look"):
            s += " (%s)" % r["look"]
        if r.get("blind"):
            s += " blind"
        parts.append(s)
    if p.get("blind_s"):
        parts.append("BLINDED %d s" % p["blind_s"])
    if p.get("residue_clear"):
        parts.append("clears " + "/".join(p["residue_clear"]))
    return ", ".join(parts) or "—"


def export(pranks, das, items, eps, out_path):
    L = ["# Content catalogue", "",
         "Generated by `python3 tools/content/catalogue.py` from `game/data/**` — do not edit by hand.", "",
         "## Pranks (32)", "",
         "| # | id | caption | size | rig point | needs | prep | trigger | knock-on | residue | Nights |",
         "|---|---|---|---|---|---|---|---|---|---|---|"]
    for i, (pid, p) in enumerate(pranks.items(), start=1):
        needs = ", ".join(sorted({s["needs"] for s in p["steps"] if s.get("needs")})) or "free"
        if p["steps"][0].get("setup"):
            needs += " (lead %s with %s)" % (p["steps"][0]["setup"]["lead"], p["steps"][0]["setup"]["item"])
        prep = " + ".join(s["prep"] for s in p["steps"])
        ko = p.get("knock_on")
        kos = "—" if not ko else ("headbutt @%d" % ko["frame"] if ko.get("headbutt") else "%s @%d" % (ko["prank"], ko["frame"]))
        nights = ", ".join(SHORT[n] for n in p["nights"])
        L.append("| %d | `%s` | %s | %s | `%s` | %s | %s | %s | %s | %s | %s |" % (
            i, pid, p["caption"], p["size"], p["rig_point"], needs, prep, fmt_trigger(p["trigger"]), kos,
            fmt_residue(p), nights))
    L += ["", "## Double Acts (6)", "", "| id | A → B | caption | Nights |", "|---|---|---|---|"]
    for did, d in das.items():
        L.append("| `%s` | %s → %s | %s | %s |" % (did, d["a"], d["b"] or "Beryl headbutt", d["caption"],
                                                 ", ".join(SHORT[n] for n in d["nights"])))
    L += ["", "## Items (16)", "", "| item | container | pranks | uses |", "|---|---|---|---|"]
    for iid, it in items.items():
        L.append("| `%s` | `%s` | %s | %d |" % (iid, it["source"], ", ".join(it["pranks"]), it["count"]))
    L += ["", "## Episodes (12)", ""]
    for eid in EP_ORDER:
        ep = eps.get(eid)
        if not ep:
            continue
        loop = " → ".join(
            e["a"] + (" (gate: %s)" % e["gate"]["until"] if e.get("gate") else "") +
            (" @%s" % e["station"] if e.get("station") else "") + (" (1st loop)" if e.get("first_loop_only") else "")
            for e in ep["bellows"]["loop"])
        card = ep["card"]["text"] if ep.get("card") else "— (no loading card)"
        L += ["### %s — %s (`%s`, %s)" % (SHORT[eid], ep["title"], eid, ep["status"]), "",
              "- Rooms: %s%s · entry `%s` · '?' %.1f s · tomatoes %s%s" % (
                  ", ".join(ep["rooms"]), (" (backstage: %s)" % ", ".join(ep["backstage"])) if ep.get("backstage") else "",
                  ep["entry"], ep["rules"]["spot_fill_s"],
                  "∞" if ep["rules"]["tomatoes"] < 0 else ep["rules"]["tomatoes"],
                  " · nerves" if ep["rules"].get("nerves") else ""),
              "- New rule `%s`: %s" % (ep["new_rule"], card),
              "- Loop: %s" % loop]
        if ep.get("fixup_overrides"):
            L.append("- Fix-up overrides: %s" % ", ".join("%s → %s" % kv for kv in ep["fixup_overrides"].items()))
        L += ["", "| line | kind | ref | req | BN | text |", "|---|---|---|---|---|---|"]
        for ln in ep["script"]:
            ref = ln.get("prank") or ln.get("double_act") or ln.get("combo") or ""
            if ln.get("count"):
                ref = "×%d" % ln["count"]
            if ln.get("link"):
                ref = "link %d" % ln["link"]
            L.append("| `%s` | %s | %s | %s | %s | %s |" % (ln["id"], ln["kind"], ref, "R" if ln.get("req") else "",
                                                          "BN" if ln.get("big_number") else "", ln["text"]))
        L.append("")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


# ---------------------------------------------------------------- diff
def diff(pranks, das, eps, text, notes=None):
    errs = []
    notes = notes if notes is not None else []
    cat = gdd_catalogue(text)
    if len(cat) != 32:
        errs.append("GDD §5.7 parse found %d entries (expected 32)" % len(cat))
    for pid in sorted(set(cat) | set(pranks)):
        if pid not in pranks:
            errs.append("%s: in GDD §5.7 but not in pranks.json" % pid)
            continue
        if pid not in cat:
            errs.append("%s: in pranks.json but not in GDD §5.7" % pid)
            continue
        g, p = cat[pid], pranks[pid]
        if g["caption"] != p["caption"]:
            errs.append("%s: caption GDD %r vs data %r" % (pid, g["caption"], p["caption"]))
        if g["size"] != p["size"]:
            errs.append("%s: size GDD %s vs data %s" % (pid, g["size"], p["size"]))
        if sorted(g["nights"]) != sorted(p["nights"]):
            errs.append("%s: nights GDD %s vs data %s" % (pid, g["nights"], p["nights"]))
        for n in g["bn"]:
            ep = eps.get(n)
            # a Big Number line may be the prank itself or a Double Act that contains it (CURTAIN CALL)
            if ep and not any(ln.get("big_number") and (ln.get("prank") == pid or pid in (
                    das.get(ln.get("double_act"), {}).get("a"), das.get(ln.get("double_act"), {}).get("b")))
                    for ln in ep["script"]):
                errs.append("%s: GDD marks it the Big Number of %s but the episode doesn't" % (pid, n))
    blocks = gdd_nights(text)
    for eid in EP_ORDER:
        if eid not in eps:
            errs.append("%s: episode file missing" % eid)
            continue
        if eid not in blocks:
            errs.append("%s: no GDD §7.2 block found" % eid)
            continue
        want = gdd_loop(blocks[eid])
        have = [e["a"] for e in eps[eid]["bellows"]["loop"]]
        dev = DEVIATIONS.get(eid, {}).get("loop")
        if want != have:
            if dev is not None and have == dev[0]:
                notes.append("ACCEPTED %s: loop GDD %s vs data %s — %s" % (eid, want, have, dev[1]))
            else:
                errs.append("%s: loop GDD %s vs data %s" % (eid, want, have))
        elif dev is not None:
            notes.append("STALE %s: the GDD loop now matches the data; drop the DEVIATIONS entry" % eid)
        quoted = set(re.findall(r'"([^"]+)"', " ".join(blocks[eid].split())))
        for ln in eps[eid]["script"]:
            if ln["text"] not in quoted:
                errs.append("%s: line %s text %r is not a GDD §7.2 Script quote" % (eid, ln["id"], ln["text"]))
    return errs


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--no-write", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "review", "content", "catalogue.md"))
    a = ap.parse_args()
    pj = load("pranks.json")
    pranks, das = pj["pranks"], pj["double_acts"]
    items = load("items.json")["items"]
    eps = load_episodes()
    with open(GDD, encoding="utf-8") as f:
        text = f.read()
    if not a.no_write:
        export(pranks, das, items, eps, a.out)
        print("[catalogue] wrote %s" % os.path.relpath(a.out, ROOT))
    notes = []
    errs = diff(pranks, das, eps, text, notes)
    for n in notes:
        print("[catalogue] " + n)
    for e in errs:
        print("[catalogue] MISMATCH " + e)
    print("[catalogue] %d pranks, %d episodes, %d mismatches vs GDD" % (len(pranks), len(eps), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
