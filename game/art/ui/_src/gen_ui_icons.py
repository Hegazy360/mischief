#!/usr/bin/env python3
"""Generates every HUD / verb / glyph / badge / stamp icon in game/art/ui/ (Mischief Next Door).

Style (matches game/art/STYLE.md intent): flat fills + ONE darker shade, a navy #1B2340 outline
(6 px at a 128 canvas, 4 px on 56-px badges), round joins/caps, a cream highlight at most. Only
features ThorVG (Godot's SVG rasteriser) renders reliably: paths, circles, ellipses, rects,
strokes, groups with transforms. No filters, masks, text or gradients.

Run:  python3 game/art/ui/_src/gen_ui_icons.py      (writes ../*.svg, then a contact sheet
      to $1 if given:  python3 gen_ui_icons.py /tmp/sheet.png)
"""
import os
import subprocess
import sys

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))

NAVY = "#1B2340"
CREAM = "#FFF4E0"
CREAM_S = "#E9D6B4"
CHERRY = "#E23B4E"
CHERRY_S = "#B3243A"
BRASS = "#D9A441"
BRASS_S = "#A8792A"
GOLD = "#E8B33A"
GOLD_S = "#C08A1E"
GOLD_L = "#FFE08A"
CURTAIN = "#B3122E"
CURTAIN_S = "#7E0B20"
YELLOW = "#FFD23F"
YELLOW_S = "#E0A91A"
ORANGE = "#FF8A1F"
GREEN = "#5CC94B"
GREEN_S = "#3E9E36"
LEAF = "#4FA64A"
LEAF_S = "#2F7A33"
STONE = "#E4DFEC"
STONE_S = "#B3AAC4"
BLUE = "#3A7BD5"
BLUE_S = "#2659A8"
GREY = "#C9C6D6"
GREY_S = "#9C98AE"
PEACH = "#F4C9A8"
PEACH_S = "#DDA27E"
SILVER = "#D9DCE6"
SILVER_S = "#A9AEC0"
PLUM = "#7B3F8C"
HOOD = "#3A3050"
HOOD_S = "#272036"
PINK = "#FF9AA2"
WHITE = "#FFFFFF"
DARK = "#2A1E3A"
TOMATO = "#E8412F"
TOMATO_S = "#B52A1E"


def svg(body, w=128, h=128):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
            % (w, h, w, h, "\n".join(body)))


def P(d, fill, stroke=NAVY, sw=6, extra=""):
    s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, sw) if stroke else ""
    return '<path d="%s" fill="%s"%s%s/>' % (d, fill, s, extra)


def C(cx, cy, r, fill, stroke=NAVY, sw=6, extra=""):
    s = ' stroke="%s" stroke-width="%s"' % (stroke, sw) if stroke else ""
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s%s/>' % (cx, cy, r, fill, s, extra)


def E(cx, cy, rx, ry, fill, stroke=NAVY, sw=6, rot=None):
    s = ' stroke="%s" stroke-width="%s"' % (stroke, sw) if stroke else ""
    t = ' transform="rotate(%s %s %s)"' % (rot, cx, cy) if rot is not None else ""
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s%s/>' % (cx, cy, rx, ry, fill, s, t)


def R(x, y, w, h, rx, fill, stroke=NAVY, sw=6):
    s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (stroke, sw) if stroke else ""
    return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s/>' % (x, y, w, h, rx, fill, s)


def L(d, color, width, cap="round"):
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="%s" stroke-linejoin="round"/>'
            % (d, color, width, cap))


def DS(d, color, width, outline=6):
    """A thick stroke with a navy outline (drawn as two strokes)."""
    return L(d, NAVY, width + 2 * outline) + "\n" + L(d, color, width)


def star_path(cx, cy, r_out, r_in, n=5, rot=-90.0):
    import math
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / n)
        pts.append("%.1f %.1f" % (cx + r * math.cos(a), cy + r * math.sin(a)))
    return "M" + " L".join(pts) + " Z"


def G(inner, transform):
    return '<g transform="%s">%s</g>' % (transform, "\n".join(inner))


ICONS = {}


def icon(name, w=128, h=128):
    def deco(fn):
        ICONS[name] = (fn, w, h)
        return fn
    return deco


# --- verbs ---------------------------------------------------------------------------------

@icon("verb_freeze")
def verb_freeze():
    # A mime statue on a plinth, one arm flung up, one on the hip.
    b = []
    b.append(R(30, 94, 68, 10, 3, STONE_S))                              # plinth cap
    b.append(R(36, 102, 56, 18, 3, STONE))
    b.append(P("M36 112 L92 112 L92 120 L36 120 Z", STONE_S, stroke=None))
    b.append(R(36, 102, 56, 18, 3, "none"))
    b.append(DS("M59 78 L55 95", STONE, 10))                             # legs
    b.append(DS("M69 78 L76 95", STONE, 10))
    b.append(DS("M52 49 L40 61 L53 70", STONE, 9))                       # arm on hip
    b.append(DS("M76 48 L90 35 L95 14", STONE, 9))                       # arm up
    b.append(C(96, 12, 7, WHITE, sw=5))                                  # glove
    b.append(P("M49 45 Q64 39 79 45 L73 80 L55 80 Z", STONE))            # torso
    b.append(P("M64 42 Q72 42 79 45 L73 80 L64 80 Z", STONE_S, stroke=None))
    b.append(P("M49 45 Q64 39 79 45 L73 80 L55 80 Z", "none"))
    b.append(L("M53 56 L75 56 M54 66 L74 66", STONE_S, 4))              # stripes (carved)
    b.append(C(63, 28, 13, STONE))                                       # head
    b.append(E(58, 16, 13, 6, STONE_S, rot=-18))                          # beret
    b.append(L("M58 27 L58 28 M68 27 L68 28", NAVY, 4))                  # closed eyes
    b.append(L("M59 34 Q63 37 67 34", NAVY, 3))
    return b


@icon("verb_pop_out")
def verb_pop_out():
    b = []
    b.append(R(18, 26, 56, 86, 10, DARK))                                # dark gap
    b.append(P("M18 36 Q30 70 22 110 L18 110 Z", CURTAIN, stroke=None))  # curtain edge
    b.append(R(18, 26, 56, 86, 10, "none"))
    b.append(E(38, 60, 5, 7, WHITE, stroke=None))                        # eyes in the dark
    b.append(E(54, 60, 5, 7, WHITE, stroke=None))
    b.append(C(40, 62, 2.5, NAVY, stroke=None))
    b.append(C(56, 62, 2.5, NAVY, stroke=None))
    b.append(DS("M56 86 Q86 88 98 58", CHERRY, 12))                       # swoosh out
    b.append(P("M86 52 L112 46 L104 72 Z", CHERRY, sw=6))                # arrow head
    return b


@icon("pin")
def pin():
    b = []
    b.append(E(64, 112, 20, 7, NAVY, stroke=None, rot=None))
    b.append(P("M64 110 C40 78 30 64 30 46 A34 34 0 0 1 98 46 C98 64 88 78 64 110 Z", CHERRY))
    b.append(P("M64 18 A28 28 0 0 1 92 46 C92 58 86 70 72 88 C80 70 84 58 82 46 A20 20 0 0 0 64 24 Z",
               CHERRY_S, stroke=None))
    b.append(C(64, 46, 13, CREAM, sw=5))
    return b


@icon("play")
def play():
    return [P("M40 22 L104 64 L40 106 Z", CREAM, sw=7),
            P("M40 70 L104 64 L40 106 Z", CREAM_S, stroke=None),
            P("M40 22 L104 64 L40 106 Z", "none", sw=7)]


@icon("hand_rig")
def hand_rig():
    # Hush's white glove, fingers wiggling, with tinker sparkles (a free prank).
    b = []
    b.append(P("M34 112 L40 78 L78 78 L86 112 Z", CHERRY))                # cuff / sleeve
    b.append(P("M30 84 Q28 58 36 46 L44 30 Q50 24 54 32 L52 50 L58 22 Q64 14 70 22 L68 48 "
               "L76 26 Q82 20 88 28 L82 52 L92 40 Q100 38 98 48 L86 80 Q70 92 50 90 Q36 90 30 84 Z", WHITE))
    b.append(L("M44 62 Q58 70 80 64", "#DDE0EE", 5))
    b.append(P(star_path(104, 22, 12, 4), YELLOW, sw=4))
    b.append(P(star_path(20, 30, 8, 3), YELLOW, sw=3))
    return b


@icon("ff")
def ff():
    return [P("M20 30 L64 64 L20 98 Z", CREAM, sw=7),
            P("M62 30 L106 64 L62 98 Z", CREAM, sw=7),
            P("M20 70 L64 64 L20 98 Z", CREAM_S, stroke=None),
            P("M62 70 L106 64 L62 98 Z", CREAM_S, stroke=None),
            P("M20 30 L64 64 L20 98 Z", "none", sw=7),
            P("M62 30 L106 64 L62 98 Z", "none", sw=7)]


@icon("clarence")
def clarence():
    # The rubber chicken: limp body, long neck, red comb.
    b = []
    b.append(DS("M74 100 L70 118 M86 98 L90 116", ORANGE, 6, outline=5))   # legs
    b.append(E(78, 86, 34, 22, YELLOW, rot=-18))                         # body
    b.append(P("M50 96 Q78 110 108 84 Q104 100 80 106 Q62 108 50 96 Z", YELLOW_S, stroke=None))
    b.append(E(78, 86, 34, 22, "none", rot=-18))
    b.append(P("M92 72 Q106 66 110 76 Q104 84 92 82 Z", YELLOW_S, sw=5))  # tail/wing
    b.append(DS("M56 80 Q40 64 42 40", YELLOW, 16))                       # neck
    b.append(P("M30 22 Q34 10 40 18 Q44 6 50 16 Q56 8 58 22 Z", CHERRY, sw=5))   # comb
    b.append(C(44, 32, 15, YELLOW))                                      # head
    b.append(P("M30 30 L12 36 L30 42 Z", ORANGE, sw=5))                  # beak
    b.append(P("M28 44 Q24 58 32 56 Q36 50 34 44 Z", CHERRY, sw=4))      # wattle
    b.append(L("M42 27 L50 33 M50 27 L42 33", NAVY, 4))                  # X eye (rubber)
    return b


@icon("pause")
def pause():
    return [R(34, 26, 22, 76, 8, CREAM, sw=7), R(72, 26, 22, 76, 8, CREAM, sw=7)]


@icon("overview")
def overview():
    # A little house with four outward arrows = "see the whole house".
    b = []
    b.append(P("M40 62 L64 42 L88 62 L88 90 L40 90 Z", CREAM, sw=6))
    b.append(R(58, 72, 12, 18, 2, BRASS, sw=4))
    b.append(P("M34 62 L64 36 L94 62", "none", sw=7))
    for tx, ty, rot in ((18, 18, 0), (110, 18, 90), (110, 110, 180), (18, 110, 270)):
        b.append(G([P("M0 0 L22 0 L15 7 L28 20 L20 28 L7 15 L0 22 Z", CREAM, sw=5)],
                   "translate(%d %d) rotate(%d)" % (tx, ty, rot)))
    return b


@icon("overview_back")
def overview_back():
    b = []
    b.append(DS("M80 80 L108 108", BRASS, 14))
    b.append(C(56, 56, 34, CREAM, sw=7))
    b.append(L("M56 40 L56 72 M40 56 L72 56", NAVY, 9))
    return b


@icon("figgis_chip")
def figgis_chip():
    # Old Figgis in his hooded prompt box: tiny head, huge ears, specs on his nose.
    b = []
    b.append(P("M14 124 Q10 60 26 36 Q44 8 64 8 Q84 8 102 36 Q118 60 114 124 Z", HOOD))
    b.append(P("M64 8 Q84 8 102 36 Q118 60 114 124 L96 124 Q100 60 84 34 Q74 20 64 18 Z", HOOD_S, stroke=None))
    b.append(P("M14 124 Q10 60 26 36 Q44 8 64 8 Q84 8 102 36 Q118 60 114 124 Z", "none"))
    b.append(E(30, 70, 16, 24, PEACH, rot=-12))                           # ears
    b.append(E(30, 70, 7, 13, PINK, stroke=None, rot=-12))
    b.append(E(98, 70, 16, 24, PEACH, rot=12))
    b.append(E(98, 70, 7, 13, PINK, stroke=None, rot=12))
    b.append(C(64, 76, 26, PEACH))                                        # face
    b.append(P("M64 102 A26 26 0 0 0 90 76 Q84 94 64 96 Z", PEACH_S, stroke=None))
    b.append(C(64, 76, 26, "none"))
    b.append(P("M44 62 Q52 56 58 62 M70 62 Q76 56 84 62", "none", sw=4))  # brows
    b.append(C(54, 74, 8, "#DDEBFF", sw=4))                               # specs
    b.append(C(74, 74, 8, "#DDEBFF", sw=4))
    b.append(L("M62 74 L66 74", NAVY, 4))
    b.append(C(54, 75, 2.5, NAVY, stroke=None))
    b.append(C(74, 75, 2.5, NAVY, stroke=None))
    b.append(E(64, 86, 7, 5, PEACH_S, sw=4))                              # nose
    b.append(E(64, 96, 4, 3, NAVY, stroke=None))                          # "psst" mouth
    return b


@icon("script")
def script():
    b = []
    b.append(R(26, 18, 76, 94, 8, CREAM))
    b.append(P("M26 96 L102 96 L102 104 Q102 112 94 112 L34 112 Q26 112 26 104 Z", CREAM_S, stroke=None))
    b.append(R(26, 18, 76, 94, 8, "none"))
    b.append(L("M40 42 L88 42 M40 60 L88 60 M40 78 L74 78", NAVY, 6))
    b.append(P("M80 10 L96 10 L96 40 L88 33 L80 40 Z", CHERRY, sw=5))     # ribbon
    return b


@icon("tomato")
def tomato():
    b = []
    b.append(E(64, 72, 46, 40, TOMATO))
    b.append(P("M64 112 Q106 112 110 72 Q104 98 72 104 Q64 106 64 112 Z", TOMATO_S, stroke=None))
    b.append(E(64, 72, 46, 40, "none"))
    b.append(E(42, 56, 10, 6, "#FF9A84", stroke=None, rot=-30))
    b.append(P(star_path(64, 36, 22, 8, 5), LEAF, sw=5))
    b.append(DS("M64 30 L66 16", LEAF_S, 5, outline=4))
    return b


@icon("tomato_splat")
def tomato_splat():
    b = []
    b.append(P("M20 64 Q14 48 30 44 Q28 26 46 32 Q52 14 66 26 Q82 12 88 32 Q108 28 102 48 Q118 58 104 70 "
               "Q116 88 96 88 Q98 108 80 98 Q70 116 58 100 Q40 112 38 94 Q18 98 24 80 Q10 74 20 64 Z", TOMATO))
    b.append(P("M58 100 Q70 116 80 98 Q98 108 96 88 Q116 88 104 70 Q96 84 84 84 Q72 96 58 100 Z",
               TOMATO_S, stroke=None))
    b.append(C(52, 58, 7, "#FF9A84", stroke=None))
    b.append(C(78, 50, 4, "#FF9A84", stroke=None))
    b.append(C(66, 70, 4, "#FFD9C9", stroke=None))
    return b


@icon("star")
def star():
    return [P(star_path(64, 68, 54, 24), GOLD, sw=7),
            P(star_path(64, 68, 54, 24, rot=-90.0) + " ", "none", stroke=None),
            P("M64 14 L64 68 L115 51 L80 76 L96 112 L64 68 Z", GOLD_S, stroke=None),
            P(star_path(64, 68, 54, 24), "none", sw=7),
            E(50, 50, 8, 5, GOLD_L, stroke=None, rot=-30)]


@icon("star_empty")
def star_empty():
    return [P(star_path(64, 68, 54, 24), "#4A4466", sw=7),
            P(star_path(64, 68, 30, 13), "#3A3456", stroke=None)]


@icon("rose")
def rose():
    b = []
    b.append(DS("M64 70 Q60 96 66 122", LEAF, 7, outline=4))
    b.append(P("M64 100 Q84 86 100 96 Q86 110 64 100 Z", LEAF, sw=4))
    b.append(C(64, 48, 32, CURTAIN))
    b.append(P("M40 62 Q64 90 90 60 Q82 80 64 80 Q48 80 40 62 Z", CURTAIN_S, stroke=None))
    b.append(C(64, 48, 32, "none"))
    b.append(P("M64 30 Q84 34 78 52 Q70 66 54 56 Q44 44 58 38 Q68 36 66 46", "none", stroke=CURTAIN_S, sw=5))
    b.append(P("M64 30 Q84 34 78 52 Q70 66 54 56 Q44 44 58 38 Q68 36 66 46", "none", sw=3))
    return b


@icon("candle")
def candle():
    b = []
    b.append(P("M64 8 Q80 30 70 44 Q64 50 58 44 Q48 30 64 8 Z", ORANGE, sw=5))
    b.append(P("M64 22 Q72 34 67 42 Q64 45 61 42 Q56 34 64 22 Z", YELLOW, stroke=None))
    b.append(R(50, 50, 28, 52, 4, CREAM))
    b.append(P("M66 50 L78 50 L78 102 L66 102 Z", CREAM_S, stroke=None))
    b.append(R(50, 50, 28, 52, 4, "none"))
    b.append(L("M64 50 L64 44", NAVY, 4))
    b.append(E(64, 106, 38, 12, BRASS))
    b.append(P("M26 106 Q64 126 102 106 Q96 116 64 118 Q32 116 26 106 Z", BRASS_S, stroke=None))
    return b


@icon("ribbon")
def ribbon():
    return [P("M40 8 L88 8 L88 118 L64 96 L40 118 Z", CURTAIN, sw=6),
            P("M70 8 L88 8 L88 118 L70 102 Z", CURTAIN_S, stroke=None),
            P("M40 8 L88 8 L88 118 L64 96 L40 118 Z", "none", sw=6),
            L("M48 22 L80 22", GOLD, 4)]


@icon("wax_seal")
def wax_seal():
    b = []
    b.append(P("M64 8 Q76 14 86 12 Q94 20 104 24 Q106 36 116 44 Q112 56 118 66 Q110 76 112 88 Q100 94 96 106 "
               "Q84 106 74 116 Q64 110 52 116 Q44 106 32 106 Q28 94 16 88 Q18 76 10 66 Q16 56 12 44 Q22 36 24 24 "
               "Q34 20 42 12 Q52 14 64 8 Z", CURTAIN))
    b.append(C(64, 62, 34, CURTAIN_S, stroke=CURTAIN_S, sw=2))
    b.append(C(64, 62, 34, "none", stroke="#D8506A", sw=3))
    b.append(P(star_path(64, 63, 22, 9), "#D8506A", stroke=None))
    return b


@icon("stamp_beret")
def stamp_beret():
    b = []
    b.append(G([E(64, 70, 50, 26, CHERRY, sw=6),
                P("M16 74 Q64 100 112 74 Q106 96 64 98 Q22 96 16 74 Z", CHERRY_S, stroke=None),
                E(64, 70, 50, 26, "none", sw=6),
                P("M58 44 Q64 30 72 44 Z", CHERRY, sw=5),
                E(46, 60, 12, 5, "#FF7A88", stroke=None, rot=-12)], "rotate(-14 64 64)"))
    return b


@icon("stamp_tick")
def stamp_tick():
    return [C(64, 64, 52, "none", stroke=GREEN_S, sw=8),
            C(64, 64, 42, "none", stroke=GREEN_S, sw=3),
            L("M40 66 L58 84 L90 44", GREEN_S, 14)]


@icon("arrow")
def arrow():
    return [P("M14 50 L70 50 L70 26 L116 64 L70 102 L70 78 L14 78 Z", CREAM, sw=7),
            P("M14 66 L116 64 L70 102 L70 78 L14 78 Z", CREAM_S, stroke=None),
            P("M14 50 L70 50 L70 26 L116 64 L70 102 L70 78 L14 78 Z", "none", sw=7)]


@icon("ghost_finger")
def ghost_finger():
    # A white glove, index finger pointing down (the "tap here" ghost finger).
    b = []
    b.append(P("M50 8 L78 8 L80 30 L48 30 Z", CHERRY, sw=5))
    b.append(P("M44 30 L86 30 Q98 40 96 60 L92 78 L78 80 L74 120 Q64 128 56 120 L54 80 Q40 78 36 64 Q32 44 44 30 Z",
               WHITE, sw=6))
    b.append(L("M58 60 L60 76 M72 58 L72 76 M84 58 L84 74", "#C9CCDC", 4))
    return b


@icon("tray")
def tray():
    b = []
    b.append(R(8, 40, 112, 56, 12, BRASS))
    b.append(P("M8 80 L120 80 L120 84 Q120 96 108 96 L20 96 Q8 96 8 84 Z", BRASS_S, stroke=None))
    b.append(R(8, 40, 112, 56, 12, "none"))
    for i in range(4):
        b.append(R(16 + i * 26, 50, 20, 30, 5, DARK, sw=3))
    b.append(C(26, 62, 6, CHERRY, sw=3))
    b.append(R(44, 56, 12, 16, 3, YELLOW, sw=3))
    return b


@icon("gear")
def gear():
    import math
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5)
        r = 52 if i % 2 == 0 else 40
        a2 = math.radians(i * 22.5 + (8 if i % 2 == 0 else -8))
        pts.append("%.1f %.1f" % (64 + r * math.cos(a - 0.12), 64 + r * math.sin(a - 0.12)))
        pts.append("%.1f %.1f" % (64 + r * math.cos(a + 0.12), 64 + r * math.sin(a + 0.12)))
    return [P("M" + " L".join(pts) + " Z", CREAM, sw=6), C(64, 64, 16, BRASS, sw=6)]


@icon("retry")
def retry():
    return [DS("M96 54 A34 34 0 1 0 90 86", CREAM, 14),
            P("M80 30 L112 38 L96 66 Z", CREAM, sw=6)]


@icon("lock")
def lock():
    return [L("M44 58 L44 42 A20 20 0 0 1 84 42 L84 58", NAVY, 16), L("M44 58 L44 42 A20 20 0 0 1 84 42 L84 58", GREY, 8),
            R(30, 56, 68, 56, 10, BRASS), C(64, 80, 8, NAVY, stroke=None), R(60, 82, 8, 16, 3, NAVY, stroke=None)]


@icon("item_fallback")
def item_fallback():
    return [R(22, 30, 84, 76, 14, GREY), P("M22 84 L106 84 L106 92 Q106 106 92 106 L36 106 Q22 106 22 92 Z", GREY_S,
            stroke=None), R(22, 30, 84, 76, 14, "none"),
            L("M52 56 Q52 44 64 44 Q76 44 76 54 Q76 62 64 66 L64 72", NAVY, 8), C(64, 88, 5, NAVY, stroke=None)]


@icon("bellows_face")
def bellows_face():
    # Horace Bellows as an edge-bubble face: silver bouffant cloud, mutton chops, specs on a chain.
    b = []
    b.append(P("M20 58 Q10 36 30 30 Q30 12 50 16 Q60 2 76 14 Q96 8 100 28 Q120 34 108 58 Z", SILVER))   # bouffant
    b.append(P("M76 14 Q96 8 100 28 Q120 34 108 58 L96 58 Q104 36 88 30 Q84 18 76 14 Z", SILVER_S, stroke=None))
    b.append(P("M20 58 Q10 36 30 30 Q30 12 50 16 Q60 2 76 14 Q96 8 100 28 Q120 34 108 58 Z", "none"))
    b.append(E(64, 74, 36, 38, PEACH))                                     # face
    b.append(P("M64 112 Q100 110 100 74 Q96 100 70 104 Z", PEACH_S, stroke=None))
    b.append(E(64, 74, 36, 38, "none"))
    b.append(P("M28 62 Q14 80 22 100 Q34 110 42 96 Q38 84 40 70 Z", SILVER))   # mutton chops
    b.append(P("M100 62 Q114 80 106 100 Q94 110 86 96 Q90 84 88 70 Z", SILVER))
    b.append(P("M42 58 L58 64 M86 58 L70 64", "none", sw=6))               # cross brows
    b.append(C(52, 72, 4.5, NAVY, stroke=None))
    b.append(C(76, 72, 4.5, NAVY, stroke=None))
    b.append(E(64, 86, 10, 8, "#EDA98A", sw=5))                            # nose
    b.append(L("M50 102 Q64 94 78 102", NAVY, 5))                          # frown
    b.append(L("M40 110 Q64 124 88 110", GOLD, 4))                        # specs chain
    return b


# --- awareness glyphs (drawn at 48 px) -------------------------------------------------------

@icon("glyph_specs_off")
def glyph_specs_off():
    # Spectacles dangling on their chain (specs off: he only spots what moves).
    b = []
    b.append(L("M10 12 Q30 70 58 64", GOLD, 5))
    b.append(L("M118 12 Q98 70 70 64", GOLD, 5))
    b.append(G([C(46, 88, 20, "#DDEBFF", sw=7), C(84, 88, 20, "#DDEBFF", sw=7), L("M62 84 Q65 78 68 84", NAVY, 6)],
               "rotate(18 64 88)"))
    return b


@icon("glyph_specs_on")
def glyph_specs_on():
    # Eyes wide behind specs, with a glint (specs on: get out of sight).
    b = []
    b.append(C(40, 64, 26, "#FFF0B8", sw=7))
    b.append(C(88, 64, 26, "#FFF0B8", sw=7))
    b.append(L("M64 60 Q64 54 64 60", NAVY, 8))
    b.append(L("M60 58 L68 58", NAVY, 7))
    b.append(C(44, 66, 9, NAVY, stroke=None))
    b.append(C(92, 66, 9, NAVY, stroke=None))
    b.append(C(47, 62, 3, WHITE, stroke=None))
    b.append(C(95, 62, 3, WHITE, stroke=None))
    b.append(L("M104 22 L114 12 M110 34 L124 32 M92 16 L94 4", YELLOW, 6))
    b.append(L("M28 42 L38 52", WHITE, 5))
    return b


@icon("glyph_blinded")
def glyph_blinded():
    b = []
    b.append(C(40, 66, 24, WHITE, sw=7))
    b.append(C(88, 66, 24, WHITE, sw=7))
    b.append(P("M14 52 Q30 34 50 46 Q66 30 84 46 Q104 34 116 52 Q124 70 108 78 Q96 92 78 82 Q64 94 48 82 "
               "Q30 92 20 78 Q6 68 14 52 Z", "#FFE27A", sw=6))                 # butter / flour splat
    b.append(C(44, 58, 5, WHITE, stroke=None))
    b.append(C(92, 60, 4, WHITE, stroke=None))
    return b


@icon("glyph_asleep")
def glyph_asleep():
    return [DS("M16 64 L50 64 L16 104 L50 104", CREAM, 9, outline=5),
            DS("M62 20 L110 20 L62 76 L110 76", CREAM, 12, outline=6)]


@icon("glyph_stars")
def glyph_stars():
    return [L("M14 70 Q64 104 114 70", "#9C98AE", 5),
            L("M14 70 Q64 36 114 70", "#9C98AE", 5),
            P(star_path(26, 72, 18, 8), YELLOW, sw=5),
            P(star_path(66, 44, 22, 9), YELLOW, sw=5),
            P(star_path(104, 84, 18, 8), YELLOW, sw=5)]


# --- hotspot badges (drawn at 56 px) ---------------------------------------------------------

def _disc(fill, shade):
    return [C(64, 64, 54, fill, sw=8), P("M64 118 A54 54 0 0 0 118 64 Q112 104 64 108 Q30 108 14 84 A54 54 0 0 0 64 118 Z",
                                         shade, stroke=None), C(64, 64, 54, "none", sw=8)]


@icon("badge_gold")
def badge_gold():
    return _disc(GOLD, GOLD_S) + [P(star_path(64, 62, 34, 14), CREAM, sw=6)]


@icon("badge_hide")
def badge_hide():
    return _disc(BLUE, BLUE_S) + [L("M28 58 Q64 88 100 58", CREAM, 10),
                                  L("M40 72 L32 86 M56 78 L52 94 M72 78 L76 94 M88 72 L96 86", CREAM, 7)]


@icon("badge_in_use")
def badge_in_use():
    return _disc(CHERRY, CHERRY_S) + [L("M26 54 Q60 82 92 54", CREAM, 9),
                                      L("M36 66 L28 80 M52 72 L48 86 M70 72 L74 86", CREAM, 6),
                                      R(96, 20, 14, 44, 7, CREAM, sw=5), C(103, 80, 8, CREAM, sw=5)]


@icon("badge_needs")
def badge_needs():
    return [C(22, 116, 7, GREY, sw=5), C(36, 100, 10, GREY, sw=5),
            P("M30 76 Q12 70 18 52 Q14 32 36 30 Q42 10 64 16 Q84 6 94 24 Q116 22 114 44 Q126 58 112 72 "
              "Q112 90 92 88 Q80 100 62 92 Q44 98 30 76 Z", GREY, sw=6),
            P("M62 92 Q80 100 92 88 Q112 90 112 72 Q104 82 92 80 Q80 90 62 84 Q44 90 34 80 Q44 98 62 92 Z", GREY_S,
              stroke=None)]

# --- Stage 2: edge-bubble emotes (GDD §3.7, D1) ----------------------------------------------
# Bellows' 112 px edge-bubble face playing an off-screen micro-gag. Each must read in half a
# second at 112 px: the face changes where it counts (eyes, mouth) and a separate pictogram
# puff (notes, steam, a teacup …; no words) rises beside the bubble (puff_<emote>.svg).

def _bellows(eyes, mouth, brows="M42 58 L58 64 M86 58 L70 64", face=PEACH, face_s=PEACH_S, nose=None,
             extra=None, chops=SILVER):
    b = []
    b.append(P("M20 58 Q10 36 30 30 Q30 12 50 16 Q60 2 76 14 Q96 8 100 28 Q120 34 108 58 Z", SILVER))
    b.append(P("M76 14 Q96 8 100 28 Q120 34 108 58 L96 58 Q104 36 88 30 Q84 18 76 14 Z", SILVER_S, stroke=None))
    b.append(P("M20 58 Q10 36 30 30 Q30 12 50 16 Q60 2 76 14 Q96 8 100 28 Q120 34 108 58 Z", "none"))
    b.append(E(64, 74, 36, 38, face))
    b.append(P("M64 112 Q100 110 100 74 Q96 100 70 104 Z", face_s, stroke=None))
    b.append(E(64, 74, 36, 38, "none"))
    b.append(P("M28 62 Q14 80 22 100 Q34 110 42 96 Q38 84 40 70 Z", chops))
    b.append(P("M100 62 Q114 80 106 100 Q94 110 86 96 Q90 84 88 70 Z", chops))
    if brows:
        b.append(P(brows, "none", sw=6))
    b.extend(eyes)
    b.append(nose if nose is not None else E(64, 86, 10, 8, "#EDA98A", sw=5))
    b.extend(mouth)
    if extra:
        b.extend(extra)
    return b


def _note(x, y, s=1.0, fill=CREAM):
    # an eighth note: head + stem + flag (pictogram, no text)
    return G([E(0, 0, 11, 8, fill, sw=5, rot=-20), L("M9 -2 L9 -38", NAVY, 11), L("M9 -2 L9 -38", fill, 5),
              P("M9 -38 Q26 -30 24 -14 Q20 -26 9 -28 Z", fill, sw=4)],
             "translate(%s %s) scale(%s)" % (x, y, s))


@icon("emote_sing")
def emote_sing():
    # "MI-MI-MIII": eyes shut in rapture, brows up, mouth a big round O
    eyes = [L("M44 72 Q52 64 60 72", NAVY, 6), L("M68 72 Q76 64 84 72", NAVY, 6)]
    mouth = [E(64, 102, 12, 14, "#7A1E2C", sw=6), E(64, 108, 7, 5, PINK, stroke=None)]
    return _bellows(eyes, mouth, brows="M40 56 Q50 46 60 54 M68 54 Q78 46 88 56")


@icon("emote_hum")
def emote_hum():
    # humming to himself: content closed eyes, lips pressed in a little smile
    eyes = [L("M44 72 Q52 76 60 72", NAVY, 6), L("M68 72 Q76 76 84 72", NAVY, 6)]
    mouth = [L("M52 101 Q58 106 64 101 Q70 106 76 101", NAVY, 6)]
    return _bellows(eyes, mouth, brows="M42 60 Q50 56 58 60 M70 60 Q78 56 86 60",
                    extra=[E(40, 90, 7, 4, "#F29A8A", stroke=None), E(88, 90, 7, 4, "#F29A8A", stroke=None)])


@icon("emote_smug")
def emote_smug():
    # pleased with himself: heavy half lids, one brow cocked, a lopsided smirk
    eyes = [E(52, 74, 8, 7, WHITE, sw=5), E(76, 74, 8, 7, WHITE, sw=5),
            C(54, 76, 3.5, NAVY, stroke=None), C(78, 76, 3.5, NAVY, stroke=None),
            P("M43 73 Q52 64 61 73 L61 70 Q52 62 43 70 Z", face_lid(), sw=4),
            P("M67 73 Q76 64 85 73 L85 70 Q76 62 67 70 Z", face_lid(), sw=4)]
    mouth = [L("M50 102 Q66 106 80 94", NAVY, 6)]
    return _bellows(eyes, mouth, brows="M42 62 L58 62 M68 54 Q78 46 88 54")


def face_lid():
    return PEACH_S


@icon("emote_laugh")
def emote_laugh():
    # a belly laugh at his own joke: eyes squeezed to chevrons, a huge open grin, tears
    eyes = [L("M44 66 L56 72 L44 78", NAVY, 6), L("M84 66 L72 72 L84 78", NAVY, 6)]
    mouth = [P("M44 96 Q64 92 84 96 Q82 118 64 118 Q46 118 44 96 Z", "#7A1E2C", sw=6),
             P("M48 97 Q64 94 80 97 L79 102 Q64 100 49 102 Z", WHITE, stroke=None),
             E(64, 112, 9, 4, PINK, stroke=None)]
    extra = [P("M34 80 Q30 90 34 94 Q40 90 34 80 Z", "#9FD3FF", sw=3),
             P("M94 80 Q90 90 94 94 Q100 90 94 80 Z", "#9FD3FF", sw=3)]
    return _bellows(eyes, mouth, brows="M40 56 Q50 50 58 58 M70 58 Q78 50 88 56", extra=extra)


@icon("emote_tut")
def emote_tut():
    # "tsk tsk": eyes narrowed sideways, brows down, lips pursed tight to one side
    eyes = [R(44, 70, 16, 7, 3, WHITE, sw=4), R(68, 70, 16, 7, 3, WHITE, sw=4),
            C(46, 73.5, 3.5, NAVY, stroke=None), C(70, 73.5, 3.5, NAVY, stroke=None)]
    mouth = [E(56, 102, 6, 5, "#7A1E2C", sw=5)]
    return _bellows(eyes, mouth, brows="M40 60 L60 66 M68 66 L88 60")


@icon("emote_sniff")
def emote_sniff():
    # sniffing the air: eyes shut, chin up, a big pink nose with flared nostrils
    eyes = [L("M44 70 Q52 66 60 70", NAVY, 6), L("M68 70 Q76 66 84 70", NAVY, 6)]
    nose = G([E(64, 84, 15, 12, "#F29A8A", sw=5), E(58, 88, 3, 2.5, NAVY, stroke=None),
              E(70, 88, 3, 2.5, NAVY, stroke=None)], "")
    mouth = [L("M54 106 L74 106", NAVY, 6)]
    return _bellows(eyes, mouth, brows="M42 58 Q50 52 58 58 M70 58 Q78 52 86 58", nose=nose)


@icon("emote_yum")
def emote_yum():
    # "mmm, tea": happy eyes, a wide smile with the tongue licking the corner
    eyes = [L("M44 74 Q52 66 60 74", NAVY, 6), L("M68 74 Q76 66 84 74", NAVY, 6)]
    mouth = [P("M46 98 Q64 112 82 98", "none", sw=6), P("M72 103 Q80 104 80 112 Q74 116 70 108 Z", "#F07A8A", sw=4)]
    extra = [E(40, 90, 7, 4, "#F29A8A", stroke=None), E(88, 90, 7, 4, "#F29A8A", stroke=None)]
    return _bellows(eyes, mouth, brows="M42 60 Q50 56 58 60 M70 60 Q78 56 86 60", extra=extra)


@icon("emote_yawn")
def emote_yawn():
    # a jaw-cracking yawn: eyes screwed shut with a tear, mouth a tall dark oval
    eyes = [L("M44 70 Q52 74 60 70", NAVY, 6), L("M68 70 Q76 74 84 70", NAVY, 6)]
    mouth = [E(64, 104, 11, 16, "#5A1522", sw=6), E(64, 112, 6, 5, PINK, stroke=None)]
    extra = [P("M88 74 Q84 82 88 86 Q94 82 88 74 Z", "#9FD3FF", sw=3)]
    return _bellows(eyes, mouth, brows="M42 60 Q50 64 58 60 M70 60 Q78 64 86 60",
                    nose=E(64, 86, 10, 7, "#EDA98A", sw=5), extra=extra)


# the puffs (drawn ~64–72 px beside the bubble, rising)

@icon("puff_sing")
def puff_sing():
    return [_note(40, 96, 1.25, YELLOW), _note(84, 64, 1.05, CREAM)]


@icon("puff_hum")
def puff_hum():
    return [DS("M16 80 Q30 64 44 80 Q58 96 72 80", CREAM, 7, outline=5), _note(94, 70, 1.0, CREAM)]


@icon("puff_smug")
def puff_smug():
    return [P(star_path(60, 64, 40, 12, n=4, rot=-90), YELLOW, sw=6), P(star_path(100, 30, 16, 5, n=4), CREAM, sw=4),
            P(star_path(24, 104, 12, 4, n=4), CREAM, sw=4)]


@icon("puff_laugh")
def puff_laugh():
    # shaking-with-laughter burst: radiating dashes + two bouncing tear drops
    b = []
    for d in ("M64 14 L64 36", "M100 28 L86 46", "M114 64 L92 64", "M28 28 L42 46", "M14 64 L36 64"):
        b.append(DS(d, YELLOW, 8, outline=5))
    b.append(P("M50 76 Q40 96 50 104 Q62 96 50 76 Z", "#9FD3FF", sw=5))
    b.append(P("M82 82 Q74 98 82 106 Q92 98 82 82 Z", "#9FD3FF", sw=5))
    return b


@icon("puff_tut")
def puff_tut():
    # a wagging index finger with motion arcs
    b = []
    b.append(L("M24 40 Q18 64 24 88", CREAM, 6))
    b.append(L("M104 40 Q110 64 104 88", CREAM, 6))
    b.append(G([P("M-10 0 L-10 -44 Q-10 -54 0 -54 Q10 -54 10 -44 L10 -6 Q30 -8 30 12 Q30 34 6 36 L-8 36 Q-24 34 -24 16 "
                  "Q-24 2 -10 0 Z", PEACH, sw=6),
                L("M-12 14 L14 14", PEACH_S, 4)], "translate(64 80) rotate(-14)"))
    return b


@icon("puff_sniff")
def puff_sniff():
    # a scent swirl drifting up
    return [DS("M30 110 Q16 90 34 76 Q52 62 36 44 Q24 30 40 18", CREAM, 7, outline=5),
            DS("M64 112 Q50 92 68 78 Q86 64 70 46 Q58 32 74 20", PINK, 7, outline=5),
            DS("M98 108 Q84 90 100 78 Q116 66 102 50", CREAM, 7, outline=5)]


@icon("puff_yum")
def puff_yum():
    # a steaming teacup
    b = []
    b.append(DS("M44 44 Q36 32 44 22 Q52 12 44 4", CREAM, 5, outline=4))
    b.append(DS("M66 44 Q58 32 66 22 Q74 12 66 4", CREAM, 5, outline=4))
    b.append(L("M92 72 Q114 72 110 88 Q106 100 88 96", NAVY, 14))
    b.append(L("M92 72 Q114 72 110 88 Q106 100 88 96", WHITE, 6))
    b.append(P("M24 58 L98 58 Q96 96 72 104 L50 104 Q26 96 24 58 Z", WHITE))
    b.append(P("M28 72 L94 72 Q90 96 72 102 L50 102 Q30 96 28 72 Z", "#C9CCDC", stroke=None))
    b.append(P("M24 58 L98 58 Q96 96 72 104 L50 104 Q26 96 24 58 Z", "none"))
    b.append(E(61, 60, 34, 7, "#B5703A", sw=5))
    b.append(E(61, 112, 44, 8, WHITE, sw=5))
    b.append(P(star_path(104, 30, 12, 5, n=4), YELLOW, sw=4))
    return b


@icon("puff_yawn")
def puff_yawn():
    return [DS("M60 54 L90 54 L60 88 L90 88", CREAM, 8, outline=5),
            DS("M20 82 L40 82 L20 104 L40 104", CREAM, 6, outline=4),
            DS("M98 18 L116 18 L98 38 L116 38", CREAM, 5, outline=4)]


# --- Stage 2: card icons ----------------------------------------------------------------------

@icon("bellows_livid")
def bellows_livid():
    # MELTDOWN: beetroot face, steam out of his ears, gritted teeth
    eyes = [C(52, 72, 7, WHITE, sw=4), C(76, 72, 7, WHITE, sw=4), C(52, 73, 3, NAVY, stroke=None),
            C(76, 73, 3, NAVY, stroke=None)]
    mouth = [R(46, 96, 36, 14, 5, WHITE, sw=5), L("M55 97 L55 109 M64 97 L64 109 M73 97 L73 109", NAVY, 3)]
    extra = [DS("M10 64 Q2 54 10 44 Q18 34 10 24", CREAM, 6, outline=4),
             DS("M118 64 Q126 54 118 44 Q110 34 118 24", CREAM, 6, outline=4)]
    return _bellows(eyes, mouth, brows="M40 56 L60 68 M88 56 L68 68", face="#E0605A", face_s="#B5403E",
                    nose=E(64, 86, 10, 8, "#C84A48", sw=5), extra=extra)


@icon("behind_you")
def behind_you():
    # PANTO: an audience head shouting, arm flung out pointing BEHIND (a curved arrow back)
    b = []
    b.append(DS("M92 30 Q124 44 110 78", CREAM, 8, outline=5))
    b.append(P("M100 74 L112 90 L122 70 Z", CREAM, sw=5))
    b.append(DS("M60 88 L96 60", PEACH, 12, outline=5))
    b.append(C(98, 58, 9, PEACH, sw=5))
    b.append(C(48, 70, 34, "#F2D3A6"))
    b.append(P("M48 104 Q82 102 82 70 Q78 94 54 98 Z", "#D9B27E", stroke=None))
    b.append(C(48, 70, 34, "none"))
    b.append(P("M20 52 Q24 32 48 34 Q70 34 76 50 Q62 42 48 44 Q30 44 20 52 Z", "#6A4A3A", sw=5))
    b.append(C(38, 64, 6, WHITE, sw=4))
    b.append(C(58, 64, 6, WHITE, sw=4))
    b.append(C(39, 65, 2.5, NAVY, stroke=None))
    b.append(C(59, 65, 2.5, NAVY, stroke=None))
    b.append(E(48, 86, 10, 11, "#7A1E2C", sw=5))
    b.append(R(4, 6, 12, 34, 6, YELLOW, sw=5))
    b.append(C(10, 50, 6, YELLOW, sw=5))
    return b


@icon("clarence_hold")
def clarence_hold():
    # Clarence squeezed flat in a fist, a yellow hold-ring filling round him (hold = ⏩)
    b = []
    b.append(L("M64 8 A56 56 0 1 1 8 64", NAVY, 16))
    b.append(L("M64 8 A56 56 0 1 1 8 64", YELLOW, 8))
    b.append(L("M8 64 A56 56 0 0 1 64 8", "#8C87A3", 6))
    b.append(G([E(0, 0, 36, 14, YELLOW, rot=0), P("M-34 4 Q0 20 34 4 Q30 14 0 16 Q-28 14 -34 4 Z", YELLOW_S, stroke=None),
                E(0, 0, 36, 14, "none"),
                P("M-40 -6 Q-48 -18 -40 -22 Q-34 -26 -30 -14 Z", CHERRY, sw=4),
                C(-34, -4, 9, YELLOW, sw=5), P("M-44 -6 L-56 -2 L-44 2 Z", ORANGE, sw=4),
                L("M-37 -7 L-31 -1 M-31 -7 L-37 -1", NAVY, 3)], "translate(66 60)"))
    b.append(P("M40 70 Q40 96 60 100 L84 100 Q98 96 98 78 L98 66 Q90 60 82 66 Q76 58 68 64 Q60 58 54 66 Q46 60 40 70 Z",
               WHITE, sw=6))
    b.append(L("M56 70 L56 84 M68 68 L68 84 M82 70 L82 84", "#C9CCDC", 4))
    b.append(P("M60 100 L84 100 L84 116 L60 116 Z", CHERRY, sw=5))
    return b


@icon("clock_fast")
def clock_fast():
    # a clock whose hands are a blur: speed arcs, ghost hands and a little ⏩
    import math
    b = []
    b.append(L("M18 34 Q6 64 18 94", CREAM, 6))
    b.append(L("M8 46 Q2 64 8 82", CREAM, 4))
    b.append(C(66, 60, 44, CREAM, sw=7))
    b.append(P("M66 104 A44 44 0 0 0 110 60 Q104 94 66 98 Q40 98 26 80 A44 44 0 0 0 66 104 Z", CREAM_S, stroke=None))
    b.append(C(66, 60, 44, "none", sw=7))
    for i in range(12):
        a = math.radians(i * 30)
        b.append(L("M%.1f %.1f L%.1f %.1f" % (66 + 34 * math.cos(a), 60 + 34 * math.sin(a),
                                               66 + 39 * math.cos(a), 60 + 39 * math.sin(a)), NAVY, 3))
    for k, alpha in ((50, "0.25"), (25, "0.5")):
        a = math.radians(-90 + k)
        b.append('<path d="M66 60 L%.1f %.1f" stroke="%s" stroke-width="7" stroke-linecap="round" '
                 'stroke-opacity="%s" fill="none"/>' % (66 + 30 * math.cos(a), 60 + 30 * math.sin(a), NAVY, alpha))
    b.append(L("M66 60 L66 30", NAVY, 7))
    b.append(L("M66 60 L86 70", NAVY, 7))
    b.append(C(66, 60, 5, CHERRY, sw=3))
    b.append(P("M84 96 L104 110 L84 124 Z", YELLOW, sw=5))
    b.append(P("M102 96 L122 110 L102 124 Z", YELLOW, sw=5))
    return b



def main():
    for name, (fn, w, h) in sorted(ICONS.items()):
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg(fn(), w, h))
    print("wrote %d icons to %s" % (len(ICONS), OUT))
    if len(sys.argv) > 1:
        contact(sys.argv[1])


def contact(out_png):
    from PIL import Image, ImageDraw
    names = sorted(ICONS)
    cell = 150
    cols = 8
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 60)), (58, 52, 80, 255))
    d = ImageDraw.Draw(sheet)
    tmp = "/tmp/_ui_icon.png"
    for i, n in enumerate(names):
        x = (i % cols) * cell
        y = (i // cols) * (cell + 60)
        for size, ox in ((128, 11), (48, 96)):
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), os.path.join(OUT, n + ".svg"), "-o", tmp],
                           check=True)
            im = Image.open(tmp).convert("RGBA")
            if size == 128:
                sheet.alpha_composite(im, (x + ox, y + 6))
            else:
                sheet.alpha_composite(im, (x + ox, y + cell - 10))
        d.text((x + 6, y + cell + 42), n, fill=(255, 244, 224, 255))
    sheet.save(out_png)
    print("contact sheet", out_png)


if __name__ == "__main__":
    main()
