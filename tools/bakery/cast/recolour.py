#!/usr/bin/env python3
"""Recolour a KayKit gradient atlas into the Mischief Next Door palette.

usage: python3 tools/art3d/cast/recolour.py <who> <in_atlas.png> <out_atlas.png>

KayKit textures every character with ONE 1024x1024 atlas of 8x8 vertical-gradient cells. A mesh
face does not get a UV island; it samples the middle of a cell, so the atlas is a palette and
re-dressing a character is repainting cells -- no re-unwrap, no per-character texture work.

Which cell each body part samples was measured off the .glb UVs (that histogram lives in
docs/review/cast3d/redress.md). The maps below name every cell a character actually uses; a cell
that is not listed is left as it was, so a part we have not thought about keeps a sane colour
rather than turning magenta.

Cells are shared BETWEEN parts of the same character, which constrains the design: on the
Barbarian the bear hat and the coat both sample [7,1], so the hat cannot be silver while the coat
is plum. Both re-dresses therefore delete the mesh that causes the clash (Rogue cape, Barbarian
bear hat) and rebuild that silhouette as an accessory in redress.py, where it is ours anyway.

Each cell keeps its vertical gradient: the replacement colour is applied as a hue/level shift about
the cell's own mid-tone, so the baked shading that makes these characters read in 3D survives.
"""
import sys

import numpy as np
from PIL import Image

GRID = 8

# cell (col, row) -> target hex. Source colours are noted for readability only.
HUSH = {
    # A mime reads in high contrast: near-black navy against a true off-white, not two mid tones.
    # Every cell the Rogue's meshes sample is listed, so no leftover adventurer leather shows.
    (0, 3): "#232C57",   # 0A4C47 tunic
    (1, 2): "#FFFFFF",   # 009958 tunic light -> stripe
    (1, 3): "#19204A",   # 006E4F tunic shadow
    (0, 2): "#232C57",   # 077860 sleeve
    (5, 1): "#232C57",   # A3624A bracer
    (7, 5): "#19204A",   # 884835
    (7, 4): "#232C57",   # A9684D forearm
    (5, 0): "#FFFFFF",   # C07D5A hand -> white glove
    (6, 1): "#232C57",   # 884835 bracer strap
    (5, 3): "#19204A",
    (6, 3): "#19204A",
    (6, 2): "#232C57",
    (3, 0): "#E23B4E",   # 9BA7AD buckle -> cherry (the beret and braces sample this too)
    (3, 1): "#FFFFFF",   # 687075 trim -> collar
    # head: white face paint, dark bob
    (0, 1): "#FFF6EA",   # F3B189 skin -> paint
    (0, 0): "#FFFFFF",   # F7C7A5 skin light
    (1, 1): "#2E1B28",   # 884835 hair dark
    (1, 0): "#3E2433",   # A9684D hair light
    (6, 0): "#3E2433",   # A9684D hair tie
    (2, 0): "#1A1420",   # 1F292C eyes/ink
    # legs: black trousers and shoes, so the silhouette ends in a clean dark block
    (3, 4): "#1A1620",   # A9684D boot light -> trouser
    (3, 5): "#0E0B12",   # 884835 boot dark -> shoe
    (7, 3): "#0E0B12",
    (7, 2): "#3A3442",   # sole
}

MAPS = {"hush": HUSH}


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def recolour(src, mapping):
    """Repaint each named cell, preserving its own vertical gradient as a brightness ramp."""
    a = np.asarray(src.convert("RGB"), dtype=np.float32).copy()
    H, W, _ = a.shape
    ch, cw = H // GRID, W // GRID
    for (cx, cy), hexcol in mapping.items():
        y0, y1 = cy * ch, (cy + 1) * ch
        x0, x1 = cx * cw, (cx + 1) * cw
        cell = a[y0:y1, x0:x1]
        # The cell's own luminance ramp, normalised about its mid-tone, becomes a multiplier on the
        # new colour: the shading that sells the shape survives the swap.
        lum = cell @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        mid = float(np.median(lum))
        if mid < 1.0:
            mid = 1.0
        ramp = np.clip(lum / mid, 0.55, 1.45)[..., None]
        a[y0:y1, x0:x1] = np.clip(hex_rgb(hexcol)[None, None, :] * ramp, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    who, src_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    if who not in MAPS:
        raise SystemExit("[recolour] unknown character '%s' (have %s)" % (who, ", ".join(MAPS)))
    src = Image.open(src_path)
    out = recolour(src, MAPS[who])
    out.save(out_path)
    print("[recolour] %s: %d cells -> %s" % (who, len(MAPS[who]), out_path))


if __name__ == "__main__":
    main()
