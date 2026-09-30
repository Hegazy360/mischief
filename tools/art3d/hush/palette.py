"""palette -- Hush's R3D palette (look A's Toy Box values), 8 x 8 cells of 32 px = palette_hush.png (256 x 256 RGBA).

A face's UV0 points at its cell centre; `char_toon` reads the albedo from it. Alpha is 255 everywhere (the masks live in
the vertex colours, index §7.6: R skin tint, G stone keep, B rim damp, A outline scale).

    python3 tools/art3d/hush/palette.py <out.png>
"""
import sys

COLORS = [
    # name, hex -- look A's values (GDD 1.2: face paint #FFF6EA, stripes navy #2B3566, beret + braces #E23B4E,
    # cheeks #FF9AA2, Clarence #FFD23F / comb #E23B4E)
    ("ink", "#2A2036"),
    ("paint", "#FFF6EA"),        # white face paint
    ("hair", "#4A2C3C"),         # the dark bob
    ("hair_hi", "#6A4254"),
    ("navy", "#2B3566"),         # Breton stripes
    ("stripe", "#F6F1E6"),
    ("beret", "#E23B4E"),        # cherry red
    ("beret_dk", "#B82B3E"),
    ("braces", "#E23B4E"),
    ("clip", "#D9DCE6"),         # brace clips (silver)
    ("trouser", "#2C2A44"),
    ("shoe", "#26202E"),
    ("sole", "#4A4050"),
    ("glove", "#FFFFFF"),
    ("glove_sh", "#E9E6F0"),     # the rolled cuff
    ("nose_h", "#FFD9D2"),       # the button nose, a touch pink
    ("chicken", "#FFD23F"),      # Clarence
    ("chicken_dk", "#E8B92A"),
    ("comb", "#E23B4E"),
    ("beak", "#F29A2E"),
    ("black", "#141018"),
    ("pot", "#F3EDE2"),          # the oversized pepper pot
    ("pot_cap", "#D8344A"),      # red cap (brief 4.2)
    ("pot_band", "#2B3566"),
    ("white", "#FFFFFF"),
    ("stone", "#E8E6E1"),        # the freeze plinth / marble
    ("stone_dk", "#CFCBC3"),
    ("string", "#3A3050"),
    ("mouth", "#7A2336"),
]
IDX = {c[0]: i for i, c in enumerate(COLORS)}
GRID, CELL = 8, 32


def hexrgb(hx: str):
    return int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)


def cell_uv(i: int):
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def write_png(path: str) -> None:
    from PIL import Image
    im = Image.new("RGBA", (GRID * CELL, GRID * CELL), (255, 0, 255, 255))
    px = im.load()
    for i, (_n, hx) in enumerate(COLORS):
        r, g, b = hexrgb(hx)
        cx, cy = i % GRID, i // GRID
        for y in range(cy * CELL, cy * CELL + CELL):
            for x in range(cx * CELL, cx * CELL + CELL):
                px[x, y] = (r, g, b, 255)
    im.save(path)


if __name__ == "__main__":
    write_png(sys.argv[1])
    print("PALETTE", len(COLORS), sys.argv[1])
