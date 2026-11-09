#!/usr/bin/env python3
"""run — bake the cast: every character's clips, packed, validated and indexed.

    python3 tools/bakery/run.py [tools/bakery/clips.json] [--who hush,bellows] [--only walk,throw]
                                [--contact] [--jobs 3]

This is the whole loop an agent drives: edit a line in clips.json, run this, read the verdict. It
never opens Blender's UI and exits non-zero if any clip fails its checks.

Output: <out>/<who>/<clip>.png + .json, <out>/<who>/_contact.png, and one <out>/index.json for the
cast. Raw frames stay in /tmp/bakery_frames/<who>/<clip> so a partial re-bake can still measure
`follows` chains and rebuild the contact sheet.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(ROOT, "tools", "bakery")
BAKE = os.path.join(TOOLS, "bake.py")
SHEET = os.path.join(TOOLS, "sheet.py")
PRUNE = os.path.join(TOOLS, "prune.py")
VALIDATE = os.path.join(TOOLS, "validate.py")
# Raw frames keyed by THIS checkout: parallel sessions in other worktrees each get their own tree,
# or they silently rmtree each other's clips mid-bake (seen as validate reading half a clip).
TMP_ROOT = os.path.join("/tmp", "bakery_frames_" + hashlib.md5(ROOT.encode()).hexdigest()[:8])
INDEX_KEYS = ("sheet", "frame_w", "frame_h", "count", "accent", "loop", "clip", "amount", "anchor",
              "durations", "duration", "faces", "ground_speed_px", "ppm", "cols")


def _length(info: dict) -> float:
    return float(sum(info.get("durations", [0.0])))


def body_x(frames_dir: str, first: bool) -> float:
    """Horizontal centre of the body's opaque pixels in the first/last frame, relative to the anchor."""
    from PIL import Image
    meta = json.load(open(os.path.join(frames_dir, "meta.json")))
    names = sorted(f for f in os.listdir(frames_dir) if f.startswith("f") and f.endswith(".png"))
    al = Image.open(os.path.join(frames_dir, names[0 if first else -1])).getchannel("A")
    box = al.point(lambda v: 255 if v > 96 else 0).getbbox()
    return (box[0] + box[2]) * 0.5 - float(meta["anchor"][0])


def lib_path(lib_dir: str, lib: str) -> str:
    """'General' = KayKit Rig_Medium_General in lib_dir; 'Large_General' = the Large-body library
    in tools/bakery/cast/src. Both share bone names, so either drives either body."""
    if lib.startswith("Large_"):
        return os.path.join(TOOLS, "cast", "src", f"Rig_{lib}.glb")
    return os.path.join(lib_dir, f"Rig_Medium_{lib}.glb")


def opt(c: dict, d: dict, key: str, default):
    return c.get(key, d.get(key, default))


def bake_one(who: str, char: str, lib_dir: str, out_dir: str, c: dict, d: dict) -> tuple[str, bool, str, dict | None]:
    """Bake, prune, pack and validate one clip. Returns (name, ok, log, sheet info)."""
    name = c["name"]
    frames_dir = os.path.join(TMP_ROOT, who, name)
    shutil.rmtree(frames_dir, ignore_errors=True)
    base, recipe = c, {}
    if "pose" in c:
        # a statue strikes FROM the character's stance (its `rest`, unless the clip names its own)
        base = {**d.get("rest", {}), **{k: c[k] for k in ("lib", "clip") if k in c}}
        recipe["pose"] = {**c["pose"], "lib": lib_path(lib_dir, c["pose"]["lib"])}
        recipe.update({"from_at": c.get("from_at", base.get("at", 0.0)),
                       "secs": c.get("secs", 0.2), "hold": c.get("hold", 0.6)})
    if "layer" in c:
        recipe["layer"] = {**c["layer"], "lib": lib_path(lib_dir, c["layer"]["lib"])}
    if "tweak" in c:
        recipe["tweak"] = c["tweak"]
    if "repeat" in c:
        recipe["repeat"] = c["repeat"]
    if "face" in c:
        recipe["face"] = c["face"]
    # props: what this clip holds, plus what the character always wears (Clarence in Hush's braces)
    # unless the clip says "wear": false; scaled so an item is the same size on stage in any hand
    held = list(c.get("props", [])) + (list(d.get("wear", [])) if c.get("wear", True) else [])
    if held:
        recipe["props"] = held
        recipe["prop_scale"] = float(d.get("cast_ppm") or d.get("ppm") or 1) / float(d.get("ppm") or 1)
    cmd = [
        "blender", "-b", "--factory-startup", "--python-exit-code", "1", "-P", BAKE, "--",
        "--char", char, "--lib", lib_path(lib_dir, base["lib"]),
        "--clip", base["clip"], "--out", frames_dir, "--recipe", json.dumps(recipe),
        "--amount", str(opt(c, d, "amount", 0.0)), "--sigma", str(opt(c, d, "sigma", 2.5)),
        "--fps", str(opt(c, d, "fps", 15)), "--angle", str(opt(c, d, "angle", 50)),
        "--res", str(opt(c, d, "res", 256)), "--ppm", str(opt(c, d, "ppm", 0)),
        "--max_deg", str(opt(c, d, "max_deg", 28)),
        "--loop", "true" if c.get("loop") else "false",
        "--locomotion", "true" if c.get("locomotion") else "false",
        "--plant", "true" if c.get("plant", True) else "false",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return name, False, f"[run] {who}/{name}: BAKE FAILED\n{r.stdout[-1500:]}\n{r.stderr[-800:]}", None
    log = []
    min_change = str(opt(c, d, "min_change", 0.004))
    pr = subprocess.run([sys.executable, PRUNE, frames_dir, "--min-change", min_change],
                        capture_output=True, text=True)
    if pr.stdout.strip():
        log.append(pr.stdout.rstrip())
    sheet_png = os.path.join(out_dir, f"{name}.png")
    s = subprocess.run([sys.executable, SHEET, frames_dir, "--out", sheet_png, "--ink", str(opt(c, d, "ink", 2))],
                       capture_output=True, text=True)
    if s.returncode != 0:
        return name, False, f"[run] {who}/{name}: SHEET FAILED\n{s.stderr[-600:]}", None
    v = subprocess.run([sys.executable, VALIDATE, frames_dir,
                        "--min-span", str(opt(c, d, "min_span", 0.05)), "--min-change", min_change,
                        "--floor-tol", "4" if c.get("grounded", True) else "-1"],
                       capture_output=True, text=True)
    log.append(v.stdout.rstrip().replace("[validate] ", f"[validate] {who}/{name}: "))
    info = json.load(open(os.path.splitext(sheet_png)[0] + ".json"))
    info["sheet"] = f"{who}/{info['sheet']}"
    return name, v.returncode == 0, "\n".join(log), info


def label(c: dict, d: dict, info: dict) -> str:
    amt = float(opt(c, d, "amount", 0.0))
    src = c.get("clip", "")
    if "pose" in c:
        src = f"statue: {c['pose']['clip']} @ {c['pose']['at']:g}s, held"
    elif "layer" in c:
        src += f" + {c['layer']['clip']} on {'/'.join(c['layer']['bones'])}"
    if "tweak" in c:
        src += " + tweak " + "/".join(c["tweak"])
    return (f"{c['name']}  ({src}, {_length(info):.2f}s, {info['count']} frames"
            f"{', cartoon ' + str(amt) if amt else ''}"
            f"{', %.0f px/s' % info['ground_speed_px'] if info.get('ground_speed_px') else ''})")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest", nargs="?", default=os.path.join(TOOLS, "clips.json"))
    ap.add_argument("--who", default="", help="comma list of cast members (default: all)")
    ap.add_argument("--only", default="", help="comma list of clip names (default: all)")
    ap.add_argument("--contact", action="store_true", help="also write each character's contact sheet")
    ap.add_argument("--jobs", type=int, default=3, help="Blender processes at once")
    a = ap.parse_args()

    man = json.load(open(a.manifest))
    d = man.get("defaults", {})
    out_root = os.path.join(ROOT, man["out"])
    lib_dir = os.path.join(ROOT, man["lib_dir"])
    who_wanted = set(x for x in a.who.split(",") if x)
    clip_wanted = set(x for x in a.only.split(",") if x)
    index_path = os.path.join(out_root, "index.json")
    index = {"ppm": d.get("ppm"), "angle": d.get("angle"), "cast": {}}
    if (who_wanted or clip_wanted) and os.path.exists(index_path):
        index["cast"] = json.load(open(index_path)).get("cast", {})   # partial re-bake keeps the rest
    fails: list[str] = []
    t0 = time.time()
    n_baked = 0

    for who, spec in man["cast"].items():
        if who_wanted and who not in who_wanted:
            continue
        char = os.path.join(ROOT, spec["character"])
        if not os.path.exists(char):
            # the cast models are build output (tools/bakery/cast/build.sh, ~2 s each), not checked in
            print(f"[run] {who}: building {spec['character']}")
            subprocess.run([os.path.join(TOOLS, "cast", "build.sh"), who], check=False)
        if not os.path.exists(char):
            print(f"[run] {who}: {spec['character']} missing and the cast build failed")
            fails.append(who)
            continue
        out_dir = os.path.join(out_root, who)
        os.makedirs(out_dir, exist_ok=True)
        entry = index["cast"].get(who, {}) if (who_wanted or clip_wanted) else {}
        entry.update({"character": spec["character"], "label": spec.get("label", who)})
        clips = entry.setdefault("clips", {})
        todo = [c for c in spec["clips"] if not clip_wanted or c["name"] in clip_wanted]
        # a character may override cast defaults: its own pixels-per-metre (relative height on
        # stage) and camera angle (KayKit bodies do not all face the same way at rest)
        dd = {**d, **spec.get("defaults", {}), "cast_ppm": d.get("ppm"), "wear": spec.get("wear", [])}
        entry["ppm"] = dd.get("ppm")
        with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
            results = list(pool.map(lambda c: bake_one(who, char, lib_dir, out_dir, c, dd), todo))
        for name, ok, log, info in results:
            print(log)
            if not ok:
                fails.append(f"{who}/{name}")
            if info is not None:
                clips[name] = {k: info[k] for k in INDEX_KEYS if k in info}
                n_baked += 1

        # Chained clips: each library clip has its own idea of where the root ends up (knocked ->
        # getup jumped 34 px). Store how far the body moves at the switch; the runtime applies it.
        for c in spec["clips"]:
            prev, name = c.get("follows"), c["name"]
            a_dir, b_dir = os.path.join(TMP_ROOT, who, prev or "-"), os.path.join(TMP_ROOT, who, name)
            if not prev or name not in clips or not (os.path.isdir(a_dir) and os.path.isdir(b_dir)):
                continue
            dx = body_x(b_dir, first=True) - body_x(a_dir, first=False)
            clips[name]["follows"], clips[name]["enter_dx"] = prev, round(dx, 1)
            print(f"[run] {who}/{name} follows {prev}: body offset {dx:+.1f}px (enter_dx)")

        # one native facing per character: the camera angle decides it, not the clip
        loco = [clips[c["name"]]["faces"] for c in spec["clips"] if c.get("locomotion") and c["name"] in clips]
        if loco:
            entry["faces"] = loco[0]
        index["cast"][who] = entry

        if a.contact:
            dirs, labels = [], []
            for c in spec["clips"]:
                fd = os.path.join(TMP_ROOT, who, c["name"])
                if c["name"] in clips and os.path.exists(os.path.join(fd, "meta.json")):
                    dirs.append(fd)
                    labels.append(label(c, dd, clips[c["name"]]))
            subprocess.run([sys.executable, SHEET, "--compare", *dirs, "--labels", *labels,
                            "--out", os.path.join(out_dir, "_contact.png"), "--ink", "2", "--scale", "0.5",
                            "--title", f"{spec.get('label', who)} — library motion at its own speed, one scale, feet on the floor"])

    with open(index_path, "w") as fh:
        json.dump(index, fh, indent=1)
    print(f"\n[run] {n_baked} clip(s) baked in {time.time() - t0:.1f}s -> {man['out']}"
          f"{'' if not fails else '   FAILED: ' + ', '.join(fails)}")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
