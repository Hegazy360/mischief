"""Shared Toy Box character palette: 8x8 cells of 16 px (128x128 PNG). Alpha encodes shader flags:
255 = plain, 153 (0.6) = skin (temper tint applies), 77 (0.3) = nose (tints twice as hard)."""
import json, os, sys
COLORS = [
    # name, hex, flag
    ("ink", "#2A2036", ""),
    # Hush
    ("paint", "#FFF6EA", "skin"),      # white face paint (GDD)
    ("hair", "#4A2C3C", ""),
    ("hair_hi", "#6A4254", ""),
    ("navy", "#2B3566", ""),           # Breton stripes (GDD)
    ("stripe", "#F6F1E6", ""),
    ("beret", "#E23B4E", ""),          # cherry red (GDD)
    ("beret_dk", "#B82B3E", ""),
    ("braces", "#E23B4E", ""),
    ("trouser", "#2C2A44", ""),
    ("shoe", "#26202E", ""),
    ("sole", "#4A4050", ""),
    ("glove", "#FFFFFF", ""),
    ("glove_sh", "#E9E6F0", ""),
    ("cheek", "#FF9AA2", "skin"),
    # Bellows
    ("peach", "#F4C9A8", "skin"),      # face (GDD) -> beetroot with temper
    ("nose", "#F2A38E", "nose"),
    ("plum", "#7B3F8C", ""),           # jacket (GDD)
    ("plum_dk", "#5B2D6B", ""),
    ("plum_lt", "#955AA6", ""),
    ("cravat", "#E8B33A", ""),         # gold cravat (GDD)
    ("cravat_dk", "#C99422", ""),
    ("bouffant", "#D9DCE6", ""),       # silver (GDD)
    ("bouffant_dk", "#B4B8C8", ""),
    ("vest", "#F3E4C4", ""),
    ("button", "#D9A93F", ""),
    ("trouser_b", "#4B2A58", ""),
    ("slipper", "#8E2E4A", ""),
    ("buckle", "#E8C25A", ""),
    ("cuff", "#FBF6EC", ""),
    ("specs", "#D2A33C", ""),
    ("lens", "#DCEBF2", ""),
    # props
    ("pepper", "#3B3B44", ""),
    ("shaker", "#E9EEF2", ""),
    ("shaker_cap", "#A9B2BC", ""),
    ("honey", "#F2A92E", ""),
    ("honey_jar", "#F7C95A", ""),
    ("jar_lid", "#C0583A", ""),
    ("cup", "#FDF8F0", ""),
    ("cup_band", "#5E7FC2", ""),
    ("tea", "#9A5A2E", ""),
    ("wood", "#A86B3C", ""),
    ("white", "#FFFFFF", ""),
    ("black", "#141018", ""),
    ("red", "#D8344A", ""),
    ("mouth", "#7A2336", ""),
    ("chicken", "#FFD23F", ""),        # Clarence (GDD)
    ("nose_h", "#FFC9C6", "skin"),
    ("comb", "#E23B4E", ""),
]
IDX = {c[0]: i for i, c in enumerate(COLORS)}
GRID, CELL = 8, 16
FLAG_A = {"": 255, "skin": 153, "nose": 77}


def cell_uv(i):
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def write_png(path):
    from PIL import Image
    im = Image.new("RGBA", (GRID * CELL, GRID * CELL), (255, 0, 255, 255))
    for i, (n, hx, fl) in enumerate(COLORS):
        r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
        cx, cy = i % GRID, i // GRID
        for y in range(cy * CELL, cy * CELL + CELL):
            for x in range(cx * CELL, cx * CELL + CELL):
                im.putpixel((x, y), (r, g, b, FLAG_A[fl]))
    im.save(path)


if __name__ == "__main__":
    write_png(sys.argv[1])
    print("PALETTE", len(COLORS), sys.argv[1])
