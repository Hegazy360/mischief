"""Horace Bellows' palette (look A "Toy Box" colours with the board's fixes): 8x8 cells of 32 px = 256x256 PNG.

UV0 of every face points at a cell centre. The shader masks come from vertex colours, not from the palette alpha
(index §7.3 `vertex_color`): R = skin tint (temper), G = stone keep, B = rim damp, A = outline scale. The palette alpha is
kept at 255 except the legacy look-A flags (skin 153, nose 77) so the look-A `toy.gdshader` still renders it.

Values (REDESIGN §3.7, measured on a flat-lit render): bouffant L* ~91, face ~81, jacket ~35; >= 20 % of the silhouette
at L* >= 85 (bouffant, shirt, gloves, spats) and >= 20 % at L* <= 40 (plum coat, striped trousers).
"""
import sys

# name, hex, legacy flag, vertex-colour masks (skin, stone_keep, rim_damp)
COLORS = [
    ("ink", "#2A2036", "", (0, 0, 0)),
    ("peach", "#F0C2A0", "skin", (1, 0, 0)),         # face (GDD #F4C9A8, darkened to L* ~81) -> beetroot with temper
    ("peach_dk", "#E2AC8C", "skin", (1, 0, 0)),      # ears' inner / under the nose
    ("nose", "#F09A88", "nose", (1, 0, 0)),          # the bulbous rosy nose (tints hardest)
    ("lip", "#C9716C", "skin", (1, 0, 0)),
    ("plum", "#7B3F8C", "", (0, 0, 1)),              # jacket (GDD)
    ("plum_dk", "#5E2C6E", "", (0, 0, 1)),
    ("plum_lt", "#9458A6", "", (0, 0, 1)),           # lapel roll / piping
    ("cravat", "#E8B33A", "", (0, 0, 0)),            # gold spotted cravat (GDD)
    ("cravat_dk", "#C99422", "", (0, 0, 0)),
    ("cravat_dot", "#FFF1C2", "", (0, 0, 0)),
    ("bouffant", "#E6E8F1", "", (0, 0, 0)),          # silver dandelion clock, L* ~92
    ("bouffant_dk", "#D3D6E2", "", (0, 0, 0)),       # the combed grooves (thin, soft)
    ("brow", "#D5D9E4", "", (0, 0, 0)),
    ("shirt", "#FBF7EE", "", (0, 0, 0)),             # white shirt V
    ("button", "#D9A93F", "", (0, 0, 0)),
    ("trouser", "#3A2A48", "", (0, 0, 1)),           # striped trousers (dark)
    ("trouser_st", "#5A4A6C", "", (0, 0, 1)),        # the stripe
    ("shoe", "#2A2030", "", (0, 0, 0)),
    ("shoe_hi", "#4A3E52", "", (0, 0, 0)),
    ("spat", "#F2EEE6", "", (0, 0, 0)),              # white spats
    ("glove", "#FFFFFF", "", (0, 0, 0)),             # white opera gloves
    ("glove_sh", "#E8E6EF", "", (0, 0, 0)),
    ("cuff", "#FBF6EC", "", (0, 0, 0)),
    ("specs", "#D2A33C", "", (0, 0, 0)),             # gold specs + chain
    ("lens", "#DCEBF2", "", (0, 0, 0)),
    # held props (x1.5-1.8, R5)
    ("cup", "#EEF4FC", "", (0, 0, 0)),               # teacup + saucer: bone china (a cool white, apart from the gloves)
    ("cup_band", "#E0A21E", "", (0, 0, 0)),          # the gold band, C* >= 45
    ("tea", "#8E4E26", "", (0, 0, 0)),
    ("honey", "#F2A92E", "", (0, 0, 0)),
    ("spoon", "#C9CED8", "", (0, 0, 0)),
    ("comb", "#D8344A", "", (0, 0, 0)),              # a red comb (reads against the silver bouffant)
    ("baton", "#FBF7EE", "", (0, 0, 0)),
    ("baton_grip", "#7A4A2A", "", (0, 0, 0)),
    # FX (vinyl)
    ("puff", "#FFFFFF", "", (0, 0, 0)),              # the CHOO puff: glossy-matte white
    ("puff_sh", "#E4ECF6", "", (0, 0, 0)),
    ("drop", "#9ED8F2", "", (0, 0, 0)),
    ("star", "#FFD23F", "", (0, 0, 0)),              # dazed stars: chunky yellow vinyl
    ("star_dk", "#F0A81C", "", (0, 0, 0)),
    ("note", "#2B3566", "", (0, 0, 0)),              # orbiting notes: navy
    ("note_hi", "#5C9EFF", "", (0, 0, 0)),
    # residue variants
    ("wet", "#C9D6E6", "", (0, 0, 0)),               # soaked bouffant (spaniel ears)
    ("wet_dk", "#9FB2CA", "", (0, 0, 0)),
    ("flour", "#FAF8F2", "", (0, 0, 0)),
    ("frazzle", "#EEF0F6", "", (0, 0, 0)),
    ("frazzle_dk", "#B6BBCC", "", (0, 0, 0)),
    ("singe", "#6A5A5A", "", (0, 0, 0)),
    ("white", "#FFFFFF", "", (0, 0, 0)),
    ("black", "#141018", "", (0, 0, 0)),
]
IDX = {c[0]: i for i, c in enumerate(COLORS)}
GRID, CELL = 8, 32
FLAG_A = {"": 255, "skin": 153, "nose": 77}
assert len(COLORS) <= GRID * GRID


def cell_uv(i):
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def masks(i):
    """(skin, stone_keep, rim_damp) of palette entry i."""
    return COLORS[i][3]


def hex_rgb(hx):
    return int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)


def write_png(path):
    from PIL import Image
    im = Image.new("RGBA", (GRID * CELL, GRID * CELL), (255, 0, 255, 255))
    px = im.load()
    for i, (n, hx, fl, _m) in enumerate(COLORS):
        r, g, b = hex_rgb(hx)
        cx, cy = i % GRID, i // GRID
        for y in range(cy * CELL, cy * CELL + CELL):
            for x in range(cx * CELL, cx * CELL + CELL):
                px[x, y] = (r, g, b, FLAG_A[fl])
    im.save(path)


if __name__ == "__main__":
    write_png(sys.argv[1])
    print("PALETTE", len(COLORS), sys.argv[1])
