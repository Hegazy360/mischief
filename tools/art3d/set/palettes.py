"""Room and prop palettes of the 3D sets (look A, REDESIGN_3D §3.7 value hierarchy).

One palette texture per room set (256 x 256 = 16 x 16 cells of 16 px) -> one material per room; one palette for
every live prop. Alpha < 128 marks a practical (window pane, lamp bulb, fire): emissive in set_toon / prop_toon.
The builders (build.py, under Blender) import this module for the NAMES -> cell index; `python3 palettes.py <out_root>`
writes the PNGs (Pillow) — Blender's Python has no Pillow, so build.sh runs this step first.

Values (CIELAB, measured on renders with tools/art3d/review/lab.py): lit walls L* 71-73 C* <= 24, wainscots ~9 L*
darker, floors L* 45/48, dressing C* <= 30 and |dL*| <= 15 vs its wall; live props saturated (C* >= 45) or haloed.
"""
import os
import sys

GRID = 16
CELL = 16

# name -> (hex, emissive)
STAGE = {
    "lip": ("#C9A24A", False), "apron": ("#2A2236", False), "proscenium": ("#1D1728", False),
    "flat": ("#E9DCC4", False), "flat_skirt": ("#6E5A4E", False), "end_flat": ("#3A2F45", False),
    "door_leaf": ("#6B7466", False), "rope": ("#B8324B", False), "post": ("#C9A24A", False),
}

KITCHEN = {
    "wall": ("#C5B187", False), "wainscot": ("#A5926C", False), "rail": ("#9D8C6F", False),
    "floor_a": ("#926647", False), "floor_b": ("#8A6043", False), "skirt": ("#8C7A5E", False),
    "counter": ("#A89A78", False), "counter_dk": ("#968867", False), "worktop": ("#CFC4A6", False),
    "basin": ("#DCDCD2", False), "basin_in": ("#B9BAB2", False), "rack": ("#A08B68", False), "shelf": ("#96805F", False),
    "handle": ("#7E6E56", False), "window_frame": ("#CFC3A6", False), "pane": ("#A9C6D2", True),
    "lamp_shade": ("#EDE4CC", False), "lamp_glow": ("#FFF4D8", True), "cord": ("#5A4E60", False),
    "pan": ("#A48A64", False), "pan_dk": ("#8C7654", False), "pan_rail": ("#8A7A60", False),
    "stool": ("#9C7A5A", False), "stool_dk": ("#86684C", False),
    "door": ("#8F8466", False), "door_frame": ("#A89A78", False),
}

PARLOUR = {
    "wall": ("#C9A6A2", False), "wainscot": ("#A48783", False), "rail": ("#9D8380", False),
    "floor_a": ("#926647", False), "floor_b": ("#8A6043", False), "skirt": ("#8A7270", False),
    "stone": ("#B7A9A5", False), "stone_dk": ("#9E918D", False), "mantel": ("#A08A86", False),
    "firebox": ("#2A2230", False), "ember": ("#E8743A", True), "flame": ("#FFB44A", True),
    "window_frame": ("#CEBDB9", False), "pane": ("#A9C6D2", True),
    "frame_gold": ("#B49A7E", False), "canvas": ("#A58E86", False), "canvas_face": ("#C4A89C", False),
    "vase": ("#3F6FB8", False), "vase_band": ("#EFEAE0", False), "basket": ("#A1886C", False), "log": ("#8C7458", False),
    "chandelier": ("#C2A56A", False), "candle": ("#EFE6D6", False),
    # r3d-fix-gags (Q-G3 / Q-G4): the Prologue's two cue pieces read at phone size — the vase is blue-and-white china,
    # the falling picture a gilt frame round a dark oil portrait (both carry the live props' ink, house3d "ink": true)
    "pic_gilt": ("#D9A63A", False), "pic_canvas": ("#3C3A5C", False), "pic_face": ("#E8C9A6", False),
}

HALL = {
    "wall": ("#A5B298", False), "wainscot": ("#86917A", False), "rail": ("#838C78", False),
    "floor_a": ("#926647", False), "floor_b": ("#8A6043", False), "skirt": ("#7A8270", False),
    "stair": ("#8E9580", False), "stair_dk": ("#7C836F", False), "stair_void": ("#1A1522", False),
    "door": ("#6A8E6E", False), "door_frame": ("#D9D2BE", False), "knocker": ("#C9A24A", False),
    "window_frame": ("#BEC3B3", False), "pane": ("#A9C6D2", True),
    "coat_stand": ("#838A73", False), "hat_a": ("#8F9A82", False), "hat_b": ("#9CA38E", False),
    "table": ("#8C8570", False), "table_dk": ("#777160", False),
}

PORCH = {
    "wall": ("#8FC3D9", False), "wainscot": ("#7CA1B1", False), "rail": ("#7CA1B1", False),
    "floor_a": ("#767066", False), "floor_b": ("#6E695F", False), "skirt": ("#77706A", False),
    "hedge": ("#7E9C74", False), "hedge_dk": ("#6C8A63", False), "step": ("#9A9286", False),
    "no9_door": ("#6E6A7A", False), "no9_frame": ("#8A8594", False), "cloud": ("#A7D2E3", False),
}

# Live props: saturated, outlined, haloed (REDESIGN §3.6 families). Shared by every live prop (one texture).
PROPS = {
    "honey": ("#F2A51F", False), "honey_dk": ("#D98A12", False), "honey_lid": ("#E23B4E", False), "honey_label": ("#FFF1C9", False),
    "pepper": ("#F4F1EA", False), "pepper_cap": ("#2A2D36", False), "pepper_grain": ("#2A2D36", False),
    "copper": ("#C8662E", False), "copper_dk": ("#A34E20", False), "kettle_knob": ("#3A2A22", False), "squeaker": ("#FFD23F", False),
    "pickle": ("#5FAE5B", False), "pickle_dk": ("#3F8A44", False), "gold_lid": ("#E8B33A", False), "onion": ("#F3F0E2", False),
    "spanner": ("#9AA3AD", False),
    "chrome": ("#AEBCCB", False), "chrome_dk": ("#8594A6", False), "tap_knob": ("#3D7BD9", False), "spray": ("#3D7BD9", False),
    "fridge": ("#8FC9C0", False), "fridge_dk": ("#6FAFA6", False), "fridge_bar": ("#D8DEE4", False), "sausage": ("#D0685A", False),
    "curtain": ("#C9912A", False), "curtain_dk": ("#A87820", False), "alcove": ("#1D1826", False), "jamb": ("#8C7657", False),
    "shelf_dark": ("#3A3040", False), "tin_a": ("#B0503A", False), "tin_b": ("#4A7AA8", False),
    "horn": ("#E0A93A", False), "horn_dk": ("#B98524", False), "cabinet": ("#8A5236", False), "cabinet_dk": ("#6E3E28", False),
    "lever": ("#2E2226", False), "knob_red": ("#E23B4E", False), "record": ("#1E1A22", False), "label": ("#E23B4E", False),
    "sticker": ("#E23B4E", False),
    "piano": ("#2B2530", False), "piano_hi": ("#3E3646", False), "keys": ("#EDE6D2", False), "keys_blk": ("#141018", False),
    "recliner": ("#B4413A", False), "recliner_dk": ("#8E3029", False), "brass": ("#D9B45A", False), "spring": ("#C8CED6", False),
    "paper": ("#EDE6D2", False), "print": ("#8C8578", False), "magnifier": ("#6B4A2E", False),
    "crate": ("#C9A46A", False), "crate_dk": ("#A8844E", False), "band": ("#D23A3A", False), "stencil": ("#FFF1C9", False),
    "phone": ("#2E3A46", False), "phone_hi": ("#4A5866", False), "kipper": ("#C9B06A", False),
    "mirror_gold": ("#C9A24A", False), "mirror_dk": ("#A5832E", False), "glass": ("#CFE3EA", False), "footprint": ("#2A2D36", False),
    "clock": ("#8A4B2E", False), "clock_dk": ("#6C3820", False), "clock_face": ("#F2E8CF", False), "clock_hand": ("#2A2D36", False),
    "wardrobe": ("#3F6FB0", False), "wardrobe_dk": ("#2F5690", False), "gap_dark": ("#100C16", False),
    "chandelier": ("#D9B45A", False), "candle": ("#F4EBD8", False),
    "tag": ("#E23B4E", False), "string": ("#FFF6EA", False),
    "white": ("#FFFFFF", False), "black": ("#141018", False),
}

PALETTES = {"stage": STAGE, "kitchen": KITCHEN, "parlour": PARLOUR, "hall": HALL, "porch": PORCH, "props": PROPS}


def names(pal: str):
    return list(PALETTES[pal].keys())


def index(pal: str, name: str) -> int:
    return names(pal).index(name)


def cell_uv(i: int):
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def rel_path(pal: str) -> str:
    return "props/palette_props.png" if pal == "props" else "set/palette_%s.png" % pal


def write_all(out_root: str) -> None:
    from PIL import Image
    for pal, table in PALETTES.items():
        im = Image.new("RGBA", (GRID * CELL, GRID * CELL), (255, 0, 255, 255))
        for i, (name, (hx, emis)) in enumerate(table.items()):
            r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
            x, y = (i % GRID) * CELL, (i // GRID) * CELL
            im.paste((r, g, b, 64 if emis else 255), (x, y, x + CELL, y + CELL))
        path = os.path.join(out_root, rel_path(pal))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        print("[palettes] %s (%d colours)" % (path, len(table)))
    # the cell names per palette (SetPreview3D's ID pass maps cells -> regions: wall / wainscot / floor / other)
    import json
    names_path = os.path.join(out_root, "set", "palettes.json")
    with open(names_path, "w") as f:
        json.dump({"grid": GRID, "cell_px": CELL, "palettes": {k: list(v.keys()) for k, v in PALETTES.items()}}, f, indent=1)
    print("[palettes] %s" % names_path)


if __name__ == "__main__":
    write_all(sys.argv[1] if len(sys.argv) > 1 else "game/art3d")
