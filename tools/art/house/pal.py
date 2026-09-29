"""Palette for the house, props, icons and stage (GDD §9.1; game/art/STYLE.md §3).

Room colours are the GDD hexes. Props (interactables) use the clean, brighter MATERIALS below so
they read over the 20-30 % desaturated rooms; characters keep the strongest saturation
(Bellows plum #7B3F8C, Hush cherry #E23B4E / navy #2B3566 are reserved for them: props never
use large areas of those).
"""
from svgk import mul, mix, lift, desat

INK = "#1B2340"
ARCH = "#3A3050"
WHITE = "#FFFFFF"
PAPER = "#FFF8EE"

# Line weights by layer (GDD §9.1)
LW_CHAR, LW_CHAR_D = 6.0, 3.5
LW_PROP, LW_PROP_D = 5.0, 3.0
LW_SET, LW_SET_D = 4.0, 2.5
LW_ARCH = 3.0
ARCH_OP = 0.8

# Rooms (GDD §9.1)
ROOM = {
    "hall": "#A9B79A",
    "parlour": "#D9A7A0",
    "kitchen": "#F2DFA6",
    "conservatory": "#CDE7E1",
    "landing": "#C9A27A",
    "bathroom": "#BFE3D5",
    "bedroom": "#B8C7E6",
    "dressing": "#6FA3A8",
    "garden": "#8ACB6A",
    "porch": "#9FD6F0",
}
LAWN = "#8ACB6A"
HEDGE = "#4E9A4A"
SKY = "#9FD6F0"
OAK = "#C98B55"
OAK_SH = "#A96C3C"

# Slab / architecture
PLASTER = "#EFE6DA"       # ceiling plaster, cut wall faces
PLASTER_SH = "#D8CCBE"
JOIST = "#7A5A4E"
JOIST_SH = "#5E463F"
BRICK = "#C0735A"
BRICK_SH = "#A25E4A"
STONE = "#C9C3B8"
STONE_SH = "#A9A297"

# Stage (GDD §9.1)
VELVET = "#B3122E"
VELVET_SH = "#8A0D24"
VELVET_DEEP = "#650A1B"
VELVET_LT = "#D2304A"
GOLD = "#E8B33A"
GOLD_SH = "#C28E1E"
GOLD_LT = "#FFE08A"
STAGE_DARK = "#1F1A2E"    # backstage (matches the project clear colour family)
STAGE_DARK2 = "#2A2340"
STAGE_BOARD = "#6B4A3A"
STAGE_BOARD_SH = "#52382D"

# Interactable materials: (base, shade, light)
def mat(base, k=0.8, warm=True, lt=0.45):
    return (base, mul(base, k, warm), lift(base, lt))


WALNUT = mat("#9A5B3A", 0.78)
MAHOGANY = mat("#8E4636", 0.78)
LIGHTWOOD = mat("#D9A066", 0.82)
BRASS = ("#E8B33A", "#C28E1E", "#FFE08A")
COPPER = mat("#D07A45", 0.8)
CREAM = ("#FFF4DC", "#EAD9B4", "#FFFFFF")
PORCELAIN = ("#F7F4EE", "#D9D6E4", "#FFFFFF")
CHROME = ("#DCE3EE", "#AEB9CC", "#FFFFFF")
GLASS = ("#CFEFF7", "#9FD2E3", "#FFFFFF")
ENAMEL_MINT = ("#CFF0E0", "#9FD4BE", "#F4FFF9")
TEAL = mat("#2F9C95", 0.78, warm=False)
MUSTARD = mat("#E6B640", 0.82)
TOMATO = mat("#EE6A45", 0.82)
PINK = mat("#F59AC0", 0.84)
COBALT = mat("#3E73D6", 0.8, warm=False)
GRASS = mat("#6BBF59", 0.8)
HONEY = ("#F6B93B", "#D8921C", "#FFE39A")
CARDBOARD = ("#D9A86C", "#B98548", "#F2CFA0")
STAMP_RED = "#D8323C"
PEPPER = "#3A3340"
SOOT = "#4A4155"
FLOUR = "#FFFFFF"
GREEN_GLASS = mat("#8CC7A0", 0.82)

# Hush's hidden eyes (warm: big pupils, glint) and gloves
EYE_W = "#FFFFFF"
GLOVE = "#FFFFFF"
GLOVE_SH = "#DDE3EE"
DARK_GAP = "#241D33"      # the dark inside a hiding spot
BERET = "#E23B4E"         # Hush's beret (tiny accents only)


def room_tones(room):
    """(wall, wall_light, wall_shade, pattern, wainscot, wainscot_shade) for a room."""
    w = ROOM[room]
    return {
        "wall": w,
        "wall_lt": lift(w, 0.18),
        "wall_sh": mul(w, 0.9),
        "pattern": lift(w, 0.1),
        "pattern_dk": mul(w, 0.95),
        "wains": mul(w, 0.84),
        "wains_sh": mul(w, 0.74),
        "wains_lt": mul(w, 0.92),
        "trim": lift(w, 0.55),
        "trim_sh": mix(lift(w, 0.55), w, 0.45),
        "grey": desat(mul(w, 0.8), 0.6),
        "grey_sh": desat(mul(w, 0.7), 0.6),
        "grey_lt": desat(mul(w, 0.9), 0.6),
    }
