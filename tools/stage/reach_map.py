#!/usr/bin/env python3
"""reach_map — an Act's set in TRUE stage coordinates (no camera), for picking reach targets.

    python3 tools/stage/reach_map.py act4 out.png [--stand hush:509,hush:1277] [--crop x0,y0,x1,y1] [--grid 50]

Composites the set's bg and every prop / sequence frame-0 layer at its layout position on the 2400x1080
stage, draws a labelled grid, the named marks and pivots, the floor line, and a vertical line at each
`--stand who:x` (where an actor stands for a beat). Reach targets in tools/bakery/clips.json
(`reach.stage.at`) are read straight off this picture.
"""
import argparse
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("act")
    ap.add_argument("out")
    ap.add_argument("--stand", default="")
    ap.add_argument("--crop", default="")
    ap.add_argument("--grid", type=int, default=50)
    a = ap.parse_args()
    art = os.path.join(ROOT, "game", "proto", a.act, "art")
    lay = json.load(open(os.path.join(art, "layout.json")))
    W, H = lay["size"]
    im = Image.new("RGBA", (W, H), (30, 26, 40, 255))
    layers = lay["layers"]
    order = ["bg"] + sorted(k for k in layers if k.startswith("prop_") or (k.startswith("seq_") and k.endswith("_00")
                                                                             and not k.startswith("seq_curtain")))
    for name in order:
        L = layers[name]
        p = os.path.join(art, L["png"])
        if os.path.exists(p):
            im.alpha_composite(Image.open(p).convert("RGBA"), tuple(int(v) for v in L.get("pos", (0, 0))))
    d = ImageDraw.Draw(im)
    g = a.grid
    for x in range(0, W, g):
        d.line((x, 0, x, H), fill=(255, 255, 255, 60 if x % (g * 2) else 110), width=1)
        if x % (g * 2) == 0:
            d.text((x + 2, 2), str(x), fill=(255, 255, 0, 255))
    for y in range(0, H, g):
        d.line((0, y, W, y), fill=(255, 255, 255, 60 if y % (g * 2) else 110), width=1)
        if y % (g * 2) == 0:
            d.text((2, y + 2), str(y), fill=(255, 255, 0, 255))
    fy = float(lay["floor_px"])
    d.line((0, fy, W, fy), fill=(0, 255, 120, 255), width=2)
    for k, v in list(lay.get("marks", {}).items()) + list(lay.get("pivots", {}).items()):
        if isinstance(v, list) and len(v) == 2:
            x, y = v
            d.ellipse((x - 6, y - 6, x + 6, y + 6), outline=(255, 40, 40, 255), width=3)
            d.text((x + 8, y - 6), k, fill=(255, 60, 60, 255))
    for s in filter(None, a.stand.split(",")):
        who, x = s.split(":")
        x = float(x)
        d.line((x, 0, x, fy), fill=(80, 170, 255, 255), width=3)
        d.text((x + 4, fy - 30), f"{who} {int(x)}", fill=(80, 170, 255, 255))
    if a.crop:
        im = im.crop(tuple(int(v) for v in a.crop.split(",")))
    im.convert("RGB").save(a.out)
    print(f"[reach_map] {a.act} -> {a.out} ({im.size[0]}x{im.size[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
