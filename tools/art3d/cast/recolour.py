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
    # torso + sleeves: Breton navy, with the light green cell becoming the cream of her collar
    (0, 3): "#2B3566",   # 0A4C47 tunic dark
    (1, 2): "#F6F1E6",   # 009958 tunic light -> cream
    (1, 3): "#1F2A52",   # 006E4F
    (0, 2): "#2B3566",   # 077860 sleeve
    (5, 1): "#2B3566",   # A3624A bracer
    (7, 5): "#1F2A52",   # 884835
    (5, 0): "#FFFFFF",   # C07D5A hand -> white glove
    (6, 1): "#2B3566",   # 884835 bracer strap
    (5, 3): "#1F2A52",   # A3624A
    (6, 3): "#1F2A52",   # 884835
    (6, 2): "#2B3566",   # A9684D
    (6, 0): "#4A2C3C",   # A9684D hair tie
    (3, 0): "#E23B4E",   # 9BA7AD buckle -> red braces
    # head: white face paint, dark bob
    (0, 1): "#FFF6EA",   # F3B189 skin -> paint
    (0, 0): "#FFFFFF",   # F7C7A5 skin light
    (1, 1): "#3A2230",   # 884835 hair dark
    (1, 0): "#4A2C3C",   # A9684D hair light
    (2, 0): "#2A2036",   # 1F292C eyes/ink
    # legs: trousers and black shoes
    (3, 4): "#2C2A44",   # A9684D boot light -> trouser
    (3, 5): "#26202E",   # 884835 boot dark -> shoe
    (7, 3): "#26202E",
    (7, 2): "#4A4050",   # sole
}

BELLOWS = {
    # Base: the Mage. Its robe is the closest thing in the pack to a frock coat, and its hat and
    # cape are dropped in redress.py so none of their cells constrain the palette.
    (0, 2): "#7B3F8C",   # 605B8C robe
    (0, 3): "#5B2D6B",   # 2E2B4E robe shadow
    (3, 0): "#F3E4C4",   # 9BA7AD trim -> cream waistcoat
    (4, 0): "#E8C25A",   # 9BA7AD -> gold buttons
    (4, 1): "#C99422",   # 687075 -> gold shadow
    (5, 1): "#5B2D6B",   # 944221 leather
    (7, 5): "#F4C9A8",   # F3B189 skin on the arms
    (2, 0): "#2A2036",   # ink
    # head: ruddy peach under silver hair
    (0, 1): "#F4C9A8",   # F3B189 skin
    (0, 0): "#FBE0C8",   # F7C7A5 skin light
    (1, 0): "#D9DCE6",   # 2D292C hair -> silver
    (1, 1): "#B4B8C8",   # 0A090A hair shadow
    # legs: dark plum trousers, burgundy slippers
    (3, 4): "#4B2A58",   # A9684D
    (3, 5): "#3A2045",   # 884835
    (7, 3): "#8E2E4A",   # 1F1D3B -> slipper
    (7, 2): "#6E2038",   # 38355C -> sole
}

MAPS = {"hush": HUSH, "bellows": BELLOWS}


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
