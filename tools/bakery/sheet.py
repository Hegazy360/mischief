#!/usr/bin/env python3
"""sheet — turn baked PNG frames into a game-ready sprite strip, and into a contact sheet to look at.

The ink outline is added here, not in Blender: dilate the alpha, fill the ring with ink, composite the
render on top. One number controls it, it is identical every run, and it needs no shader.

    python3 tools/bakery/sheet.py /tmp/bake/hit_1 --out docs/.../hit.png --ink 3
    python3 tools/bakery/sheet.py --compare /tmp/bake/hit_0 /tmp/bake/hit_1 --labels flat cartoon \
        --out /tmp/compare.png
"""
from __future__ import annotations

import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

INK = (26, 26, 38, 255)
PAPER = (247, 242, 232, 255)
PANEL = (20, 26, 48, 255)
MAX_TEX = 4096   # the largest texture every phone we target is guaranteed to load


def load_frames(d: str) -> tuple[list[Image.Image], dict]:
    meta = {}
    mp = os.path.join(d, "meta.json")
    if os.path.exists(mp):
        meta = json.load(open(mp))
    names = sorted(f for f in os.listdir(d) if f.startswith("f") and f.endswith(".png"))
    return [Image.open(os.path.join(d, n)).convert("RGBA") for n in names], meta


def outline(img: Image.Image, thickness: int, ink=INK) -> Image.Image:
    """Ink ring from the alpha channel: dilate, subtract, fill, composite."""
    if thickness <= 0:
        return img
    a = img.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(thickness * 2 + 1))
    ring = Image.fromarray(np.maximum(np.array(grown, dtype=np.int16) - np.array(a, dtype=np.int16), 0).astype(np.uint8))
    out = Image.new("RGBA", img.size, (ink[0], ink[1], ink[2], 0))
    out.putalpha(Image.fromarray(np.maximum(np.array(ring), np.array(a)).astype(np.uint8)))
    flat = Image.new("RGBA", img.size, ink)
    flat.putalpha(out.getchannel("A"))
    flat.alpha_composite(img)
    return flat


def common_box(frames: list[Image.Image], pad: int) -> tuple[int, int, int, int]:
    """One crop box for every frame, so the character never jitters between cells."""
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    if not boxes:
        return (0, 0, frames[0].width, frames[0].height)
    l = max(0, min(b[0] for b in boxes) - pad)
    t = max(0, min(b[1] for b in boxes) - pad)
    r = min(frames[0].width, max(b[2] for b in boxes) + pad)
    b_ = min(frames[0].height, max(b[3] for b in boxes) + pad)
    return (l, t, r, b_)


def _font(size: int):
    for p in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                pass
    return ImageFont.load_default()


def strip(d: str, out_path: str, ink: int) -> dict:
    frames, meta = load_frames(d)
    if not frames:
        raise SystemExit(f"no frames in {d}")
    frames = [outline(f, ink) for f in frames]
    box = common_box(frames, pad=ink + 2)
    cells = [f.crop(box) for f in frames]
    w, h = cells[0].size
    # wrap into a grid no wider than MAX_TEX: many phone GPUs refuse textures past 4096 px, and a
    # long clip as one strip reached 11,648 px (the sprite would simply not draw on those phones)
    cols = max(1, min(len(cells), MAX_TEX // w))
    rows = (len(cells) + cols - 1) // cols
    if rows * h > MAX_TEX:
        raise SystemExit(f"{len(cells)} frames of {w}x{h} do not fit a {MAX_TEX}px texture — lower fps or res")
    sheet = Image.new("RGBA", (w * cols, h * rows), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % cols) * w, (i // cols) * h))
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    sheet.save(out_path)
    info = dict(meta)
    info.update({"sheet": os.path.basename(out_path), "frame_w": w, "frame_h": h,
                 "count": len(cells), "ink": ink, "cols": cols})
    if "anchor" in meta:
        # the root-on-the-floor pixel, moved into the cropped cell: the runtime pins THIS to the
        # character's position, so every clip lands with its feet in the same place
        info["anchor"] = [round(meta["anchor"][0] - box[0], 2), round(meta["anchor"][1] - box[1], 2)]
    with open(os.path.splitext(out_path)[0] + ".json", "w") as fh:
        json.dump(info, fh, indent=2)
    return info


def contact(dirs: list[str], labels: list[str], out_path: str, ink: int, scale: float,
            title: str = "") -> None:
    """One labelled row per bake. Every row is drawn at the SAME scale with the character's feet on a
    shared floor line, so size and grounding can be judged across clips, not just within one."""
    rows = []
    for d in dirs:
        frames, meta = load_frames(d)
        frames = [outline(f, ink) for f in frames]
        box = common_box(frames, pad=ink + 2)
        anc = meta.get("anchor", [frames[0].width / 2, frames[0].height])
        rows.append((frames, meta, box, (anc[0] - box[0], anc[1] - box[1])))
    above = max(a[1] for *_, a in rows)
    below = max((b[3] - b[1]) - a[1] for _, _, b, a in rows)
    lab_h, pad, head = 22, 8, 34 if title else 6
    row_h = int((above + below) * scale) + lab_h + pad
    widths = [int(sum(b[2] - b[0] + pad for _ in f) * scale) for f, _, b, _ in rows]
    W = max(widths) + pad * 2
    H = head + len(rows) * row_h + pad
    img = Image.new("RGBA", (W, H), PANEL)
    dr = ImageDraw.Draw(img)
    f_small, f_head = _font(15), _font(20)
    if title:
        dr.text((pad, 8), title, font=f_head, fill=(255, 220, 140, 255))
    y = head
    for (frames, meta, box, anc), label in zip(rows, labels):
        dr.text((pad, y), label, font=f_small, fill=(255, 201, 60, 255))
        floor = y + lab_h + int(above * scale)
        dr.line([(pad, floor), (W - pad, floor)], fill=(60, 70, 110, 255), width=1)
        cw, ch = int((box[2] - box[0]) * scale), int((box[3] - box[1]) * scale)
        durs = meta.get("durations", [])
        for i, fr in enumerate(frames):
            cell = fr.crop(box).resize((max(1, cw), max(1, ch)), Image.LANCZOS)
            x = pad + i * (cw + int(pad * scale))
            top = floor - int(anc[1] * scale)
            img.alpha_composite(cell, (x, top))
            tag = str(i) + (f" {int(round(durs[i] * 1000))}ms" if i < len(durs) else "")
            if int(meta.get("accent", -1)) == i and not meta.get("loop"):
                tag += " *"
                dr.rectangle([x - 2, top - 2, x + cw + 1, top + ch + 1], outline=(255, 201, 60, 255), width=2)
            dr.text((x + 2, floor + 2), tag, font=_font(11), fill=(160, 170, 205, 255))
        y += row_h
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    img.convert("RGB").save(out_path)
    print(f"[sheet] contact {out_path}  {len(rows)} row(s)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--compare", nargs="+", default=None)
    ap.add_argument("--labels", nargs="+", default=None)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ink", type=int, default=3)
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--title", default="")
    a = ap.parse_args()
    if a.compare:
        labels = a.labels or [os.path.basename(d) for d in a.compare]
        contact(a.compare, labels, a.out, a.ink, a.scale, a.title)
    else:
        info = strip(a.dirs[0], a.out, a.ink)
        print(f"[sheet] {info['count']} frames of {info['frame_w']}x{info['frame_h']} -> {a.out}")


if __name__ == "__main__":
    main()
