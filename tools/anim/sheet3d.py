#!/usr/bin/env python3
"""Compose the 3D animation review sheets (TECH §11 in 3D, r3d-rig §4.4) from the raw frames that
game/tools/anim3d/sheet3d.gd rendered with the game's own RigPlayer3D.

usage: python3 tools/anim/sheet3d.py clip <raw_dir> <out_dir>      # contact, onion, curves json, sil64, phone strip
       python3 tools/anim/sheet3d.py turntable <raw_dir> <out_png> [--title=T]
       python3 tools/anim/sheet3d.py faces <raw_dir> <out_png> [--title=T]

clip mode writes <clip>_contact.png (a cell every 3 f + every beat boundary, beats outlined: anticipation blue,
accent red, hold grey, settle teal; events under their cell), <clip>_onion.png (one panel per beat: its frames
tinted blue → red, spacing dots on head top, hands and pelvis), <clip>_curves.json (for tools/anim/curves.py),
<clip>_sil64.png (black 64 px silhouettes at the beat boundaries, via tools/art3d/review/sil64.py) and
<clip>_phone.jpg (the 1200×540 game framing, every 3 f, via tools/art3d/review/strip.py). Pillow + numpy only.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REVIEW = os.path.join(ROOT, "tools", "art3d", "review")
BG = (250, 248, 242)
INK = (27, 35, 64)
BEAT_COL = {"anticipation": (46, 111, 216), "accent": (214, 40, 57), "hold": (140, 140, 150), "settle": (47, 163, 154)}
CELL_BG = (236, 232, 222)


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def beat_of(beats, f):
    """The beat a frame belongs to (the last beat whose range holds it; boundaries belong to the later beat)."""
    hit = None
    for name, (b0, b1) in beats.items():
        if b0 <= f < b1 or (f == b1 and name == "settle"):
            hit = name
    return hit


def events_by_cell(cells, events):
    """Events grouped under the first cell at or after their frame."""
    out = {c: [] for c in cells}
    prev = -1
    for c in cells:
        for e in events:
            if prev < e["f"] <= c or (c == cells[0] and e["f"] == c):
                out[c].append(e)
        prev = c
    return out


def label_of(e):
    t = e.get("type", "")
    ident = e.get("id") or e.get("prop") or ""
    return "%s %s" % (t, ident) if ident else t


def contact(man, raw, out_png, cell=200, cols=10):
    cells = man["cells"]
    beats = man.get("beats", {})
    evs = events_by_cell(cells, man.get("events", []))
    f_small, f_mid, f_big = font(12), font(14), font(20)
    ev_lines = max([min(3, len(v)) for v in evs.values()] + [0])
    ch = cell + 20 + 14 * ev_lines + 6
    rows = (len(cells) + cols - 1) // cols
    W = cols * (cell + 8) + 16
    H = 60 + rows * (ch + 8) + 30
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    title = "%s — %d f%s  tier %s%s   cells every 3 f + beat boundaries" % (
        man["clip"], man["length"], " loop" if man.get("loop") else "", man.get("tier", 1),
        " suppressed" if man.get("suppressed") else "")
    d.text((14, 12), title, fill=INK, font=f_big)
    x = 14
    for name, col in BEAT_COL.items():
        if name in beats:
            b0, b1 = beats[name]
            d.rectangle([x, 40, x + 14, 52], fill=col)
            d.text((x + 18, 38), "%s %d–%d" % (name, b0, b1), fill=INK, font=f_small)
            x += 150
    for i, f in enumerate(cells):
        r, c = divmod(i, cols)
        x0 = 8 + c * (cell + 8)
        y0 = 60 + r * (ch + 8)
        d.rectangle([x0, y0, x0 + cell, y0 + cell], fill=CELL_BG)
        p = os.path.join(raw, "side_%04d.png" % f)
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA").resize((cell, cell), Image.LANCZOS)
            img.paste(im, (x0, y0), im)
        b = beat_of(beats, f)
        edge = BEAT_COL.get(b)
        if edge:
            d.rectangle([x0 - 2, y0 - 2, x0 + cell + 2, y0 + cell + 2], outline=edge, width=4 if b == "accent" else 3)
        d.text((x0 + 4, y0 + 3), "f %d" % f, fill=INK, font=f_mid)
        for k, e in enumerate(evs.get(f, [])[:3]):
            d.text((x0 + 2, y0 + cell + 4 + 14 * k), "%d %s" % (e["f"], label_of(e))[:30], fill=INK, font=f_small)
        more = len(evs.get(f, [])) - 3
        if more > 0:
            d.text((x0 + cell - 30, y0 + cell + 4), "+%d" % more, fill=INK, font=f_small)
    img.save(out_png)
    return out_png


def onion(man, raw, out_png, panel=360):
    beats = man.get("beats", {})
    cells = man["cells"]
    dots = {d["f"]: d for d in man.get("dots", [])}
    order = [b for b in ("anticipation", "accent", "hold", "settle") if b in beats]
    if not order:
        order = ["all"]
        beats = dict(beats)
        beats["all"] = [0, man["length"]]
    cellpx = man.get("cell_px", 420)
    k = panel / float(cellpx)
    f_mid, f_big = font(14), font(18)
    W = len(order) * (panel + 12) + 12
    H = panel + 70
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    for i, name in enumerate(order):
        b0, b1 = beats[name]
        fr = [f for f in cells if b0 <= f <= b1]
        x0 = 12 + i * (panel + 12)
        y0 = 40
        canvas = Image.new("RGBA", (panel, panel), CELL_BG + (255,))
        n = max(1, len(fr) - 1)
        for j, f in enumerate(fr):
            p = os.path.join(raw, "side_%04d.png" % f)
            if not os.path.exists(p):
                continue
            t = j / n
            tint = (int(46 + (214 - 46) * t), int(111 + (40 - 111) * t), int(216 + (57 - 216) * t))
            im = Image.open(p).convert("RGBA").resize((panel, panel), Image.LANCZOS)
            a = im.split()[3].point(lambda v: int(v * (0.28 if j < len(fr) - 1 else 0.85)))
            flat = Image.new("RGBA", (panel, panel), tint + (0,))
            flat.putalpha(a)
            canvas = Image.alpha_composite(canvas, flat)
        dd = ImageDraw.Draw(canvas)
        span = [f for f in range(b0, b1 + 1) if f in dots]
        m = max(1, len(span) - 1)
        for j, f in enumerate(span):
            t = j / m
            col = (int(46 + (214 - 46) * t), int(111 + (40 - 111) * t), int(216 + (57 - 216) * t), 255)
            for role in ("top", "hand_l", "hand_r", "pelvis"):
                px = dots[f].get(role)
                if not px:
                    continue
                cx, cy = px[0] * k, px[1] * k
                dd.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=col)
        img.paste(canvas.convert("RGB"), (x0, y0))
        d.rectangle([x0 - 2, y0 - 2, x0 + panel + 2, y0 + panel + 2], outline=BEAT_COL.get(name, INK), width=3)
        d.text((x0, 14), "%s  f %d–%d  (%d cells)" % (name, b0, b1, len(fr)), fill=INK, font=f_mid)
    d.text((12, H - 22), "%s — blue = beat start, red = beat end; dots every frame: head top, hands, pelvis" % man["clip"],
           fill=INK, font=f_mid)
    img.save(out_png)
    return out_png


def curves_json(man, out_json):
    doc = {"clip": man["clip"], "length": man["length"], "loop": man.get("loop", False), "tier": man.get("tier", 1),
           "suppressed": man.get("suppressed", False), "beats": man.get("beats", {}), "events": man.get("events", []),
           "keys": [{"f": e["f"], "ease": e.get("preset", "")} for e in man.get("face", [])],
           "channels": {}}
    for name, vals in man.get("channels", {}).items():
        if vals:
            label = name.replace(".speed", " °/f") if name.endswith(".speed") else name + " °"
            doc["channels"][label] = vals
    json.dump(doc, open(out_json, "w"), indent=1)
    return out_json


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("[sheet3d] %s failed: %s" % (" ".join(cmd[:3]), (r.stderr or r.stdout).strip()[-400:]), file=sys.stderr)
    return r.returncode == 0


def sil64(man, raw, out_png, work):
    beats = man.get("beats", {})
    picks = []
    for name in ("anticipation", "accent", "hold", "settle"):
        if name in beats:
            picks.append((beats[name][0], name))
    if not picks:
        picks = [(f, "f%d" % f) for f in man["cells"][:: max(1, len(man["cells"]) // 6)]]
    picks.append((man["length"], "end"))
    d = os.path.join(work, "sil")
    os.makedirs(d, exist_ok=True)
    for f, name in picks:
        cell = min(man["cells"], key=lambda c: abs(c - f))
        src = os.path.join(raw, "side_%04d.png" % cell)
        if os.path.exists(src):
            shutil.copy(src, os.path.join(d, "f%03d_%s.png" % (cell, name)))
    return run([sys.executable, os.path.join(REVIEW, "sil64.py"), "masks", d, "--out=" + out_png,
                "--json=" + os.path.join(work, "sil64.json")])


def phone(man, raw, out_jpg, work):
    if not man.get("phone"):
        return False
    d = os.path.join(work, "phone")
    os.makedirs(d, exist_ok=True)
    crop = man.get("phone_crop") or None
    for f in man["phone"]:
        src = os.path.join(raw, "game_%04d.png" % f)
        if os.path.exists(src):
            im = Image.open(src)
            if crop and crop[2] > crop[0] and crop[3] > crop[1]:
                im = im.crop(tuple(crop))   # true phone scale: a crop of the 1200×540 frame, never scaled
            im.convert("RGB").save(os.path.join(d, "f%04d.png" % f))
    marks = {}
    for name, (b0, _b1) in man.get("beats", {}).items():
        marks[str(b0 - b0 % 3)] = name
    for name, f in man.get("marks", {}).items():
        marks[str(int(f) - int(f) % 3)] = name
    mp = os.path.join(work, "marks.json")
    json.dump(marks, open(mp, "w"))
    w = (crop[2] - crop[0]) if crop else 1200
    cols = max(2, min(12, 2400 // max(1, w)))
    return run([sys.executable, os.path.join(REVIEW, "strip.py"), d, out_jpg, "--cols=%d" % cols, "--marks=" + mp,
                "--label-frames"])


def board(raw, prefix, names, labels, out_png, title, cols, cell=None):
    cells = [os.path.join(raw, "%s%s.png" % (prefix, n)) for n in names]
    cells = [c for c in cells if os.path.exists(c)]
    return run([sys.executable, os.path.join(REVIEW, "boards.py"), "grid", out_png, "--cells=" + ",".join(cells),
                "--labels=" + "|".join(labels[: len(cells)]), "--sep=|", "--cols=%d" % cols, "--title=" + title]
               + (["--cell=" + cell] if cell else []))


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    mode, raw, out = argv[1], argv[2], argv[3]
    title = ""
    for a in argv[4:]:
        if a.startswith("--title="):
            title = a[8:]
    if mode == "clip":
        man = json.load(open(os.path.join(raw, "manifest.json")))
        os.makedirs(out, exist_ok=True)
        base = man["clip"].split("/")[-1]
        suffix = ("_t%d" % man["tier"]) if man.get("tier", 1) > 1 else ""
        suffix += "_sup" if man.get("suppressed") else ""
        stem = os.path.join(out, base + suffix)
        work = tempfile.mkdtemp(prefix="sheet3d_")
        try:
            made = [contact(man, raw, stem + "_contact.png"), onion(man, raw, stem + "_onion.png"),
                    curves_json(man, stem + "_curves.json")]
            if sil64(man, raw, stem + "_sil64.png", work):
                made.append(stem + "_sil64.png")
            if phone(man, raw, stem + "_phone.jpg", work):
                made.append(stem + "_phone.jpg")
        finally:
            shutil.rmtree(work, ignore_errors=True)
        print("[sheet3d] " + ", ".join(os.path.basename(m) for m in made))
        return 0
    if mode == "turntable":
        views = ["front", "q34", "side", "back"]
        ok = board(raw, "turn_", views, ["front", "3/4", "side", "back"], out, title or "turntable", 2)
        return 0 if ok else 1
    if mode == "faces":
        meta = json.load(open(os.path.join(raw, "faces.json")))
        names = meta["presets"]
        ok = board(raw, "face_", names, names, out, title or ("%s — every face preset (3×)" % meta["rig"]), 9, "360x360")
        return 0 if ok else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
