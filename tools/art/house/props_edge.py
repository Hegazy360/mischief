"""props_edge - final hotspot props for the rooms every slice shot also shows (s2-art §4.2.2): the upper floor above
the slice (landing, bathroom, bedroom, dressing room - their lower band sits in every ground-floor frame) and the
conservatory (its first 600 px are in every kitchen frame). They replace the Stage-1 greybox blocks at the same
paths, hit boxes and eye points; the view shows them dimmed as the unlit set while their rooms are locked, so they
must still read as designed furniture.

Same rules as the slice props (STYLE.md §2-§6): 5 px ink, detail 3 px, one flat shade tone, a top-left highlight,
clean materials, every rigged state a visible physical tell + a gold glint, `occupied` = a dark gap (#241D33) with
Hush's glove fingertips and NO baked eyes (the view animates her eyes at `eyes`).
Coordinates: world px, x absolute, y relative to the room's floor line.
"""
import math

import pal
from draw import blob, box, glove_fingers, knob, oval, shadow, shape, sparkle
from props_base import Prop, emit
from svgk import INK, PB, circle, ellipse, group, lift, mix, mul, path, rect

W = pal.LW_PROP      # 5
D = pal.LW_PROP_D    # 3

PAINT = ("#F3EBDD", "#D9CCB6", "#FFFFFF")       # painted cupboard wood (cream)
WICKER = ("#D9A86C", "#B98548", "#F2CFA0")
LINEN = ("#FFFFFF", "#DDE3EE", "#FFFFFF")
DUVET = ("#9FB8E8", "#7F98CC", "#CFDCF6")
ROSE = ("#F2B8C8", "#D993A8", "#FFE0EA")
ZINC = ("#B9C4D4", "#94A0B4", "#E4EAF2")
TREACLE = ("#6B3A1E", "#4E2812", "#A8683A")
SQUEAK = ("#EE6A45", "#C95736", "#FFB08A")
BUTTER = ("#FFE36B", "#E8C25E", "#FFF6C0")
GREEN_BAL = ("#6CC06A", "#4E9E52", "#B5E8B0")
GOAT = ("#F3EAD6", "#DCCFB4", "#FFFFFF")
TUTU = ("#F59AC0", "#D97AA2", "#FFD3E6")
CLOAK = ("#6E5AA0", "#56458A", "#9A8AC8")
TERRACOTTA = ("#C86A4A", "#A8553A", "#E2906E")
TOMATO_SOFT = ("#E86A7A", "#C9505F", "#F6A8B2")
PORC_SH = "#D9D6E4"

#: hotspot ids this module draws (props_grey skips them)
PROVIDES = (
    "stairs_head", "landing_airing_cupboard", "landing_boiler_valve",
    "bathroom_basin_spray", "bathroom_cabinet", "bathroom_bath_taps", "bathroom_duck", "bathroom_bath",
    "bathroom_laundry_basket",
    "bedroom_wardrobe", "bedroom_bed", "bedroom_pillow", "bedroom_under_bed", "bedroom_bedside",
    "dressing_costume_trunk", "dressing_costume_rail", "dressing_trophy_shelf", "dressing_dummy",
    "conservatory_feed_bin", "conservatory_hamper", "conservatory_potting_bench",
)


def ink(pb, sw=W, sil=True):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=sil)


def det(pb, sw=D):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=False)


def dark(pb):
    return path(pb, fill=pal.DARK_GAP, sil=False)


def hi_line(x, y, w):
    return rect(x, y, w, 5, 2.5, fill="#FFFFFF", fop=0.55, sil=False)


def make(reg, hid, name, room, states, eyes=None, tell=None, eyes_scale=None):
    """states: {state: items}; `tell` adds the rigged-state gold glint."""
    p = Prop(name, room)
    for s, items in states.items():
        p.add(s, items)
        if s == "rigged" and tell:
            p.add(s, sparkle(tell[0], tell[1], 13))
    if eyes:
        p.extra["eyes"] = list(eyes)
    if eyes_scale:
        p.extra["eyes_scale"] = eyes_scale
    emit(reg, hid, p)


def panel_door(x, y, w, h, m, r=6, panels=2):
    out = box(x, y, w, h, r, m, W, hi=True)
    ph = (h - 28 - (panels - 1) * 14) / panels
    for i in range(panels):
        py = y + 14 + i * (ph + 14)
        out.append(rect(x + 14, py, w - 28, ph, 4, fill=m[1], fop=0.5, sil=False))
        out.append(det(PB().rrect(x + 14, py, w - 28, ph, 4), 2.5))
    return out


# =============================================================================== landing
def landing(reg):
    # stair head newel: turned walnut post, brass cap
    wal = pal.WALNUT
    post = [shadow(1109, -4, 26, 4)]
    post += box(1098, -236, 22, 236, 4, wal, W, hi=False)
    post += box(1092, -250, 34, 22, 6, wal, W, hi=False)
    post += [circle(1109, -266, 14, fill=pal.BRASS[1]), circle(1106, -269, 10, fill=pal.BRASS[0], sil=False),
             circle(1103, -273, 3.5, fill="#FFFFFF", fop=0.7, sil=False), circle(1109, -266, 14, fill="none", sw=W, stroke=INK)]
    post.append(det(PB().M(1098, -120).L(1120, -120).M(1098, -60).L(1120, -60), 2.5))
    make(reg, "stairs_head", "stair_head", "landing", {"idle": post})

    # airing cupboard: cream painted double door with louvres, brass knob; the boiler valve sits above it
    x0, x1, top, bot = 1182, 1320, -330, -18

    def cupboard(peek):
        out = [shadow((x0 + x1) / 2, -8, 78, 6)]
        out += box(x0, top, x1 - x0, bot - top, 6, PAINT, W, hi=True)
        mid = (x0 + x1) / 2
        louv = PB()
        for xa, xb in ((x0 + 14, mid - 8), (mid + 8, x1 - 14)):
            for k in range(7):
                y = top + 26 + k * 20
                louv.M(xa, y).L(xb, y + 6)
        if peek:
            # right door swung wide open (its leaf out past the frame), the dark airing space behind
            out.append(dark(PB().rrect(mid + 2, top + 10, x1 - mid - 12, bot - top - 20, 4)))
            leaf = PB().M(x1 - 2, top + 8).L(x1 + 30, top + 24).L(x1 + 30, bot - 18).L(x1 - 2, bot - 8).Z()
            out += [path(leaf, fill=PAINT[1]), ink(leaf, D + 1)]
            louv2 = PB()
            for k in range(7):
                y = top + 26 + k * 20
                louv2.M(x0 + 14, y).L(mid - 8, y + 6)
            out.append(det(louv2, 2.5))
            out.append(det(PB().M(mid, top + 8).L(mid, bot - 8)))
            out += glove_fingers(mid + 4, -236, -1, 0.85, 3)
        else:
            out.append(det(louv, 2.5))
            out.append(det(PB().M(mid, top + 8).L(mid, bot - 8)))
            out += knob(mid - 12, -170, 6) + knob(mid + 12, -170, 6)
        # folded towels peeking over the top (it IS an airing cupboard)
        out += box(x0 + 18, top - 22, 50, 22, 6, ROSE, D, hi=False) + box(x0 + 70, top - 16, 44, 16, 6, pal.ENAMEL_MINT, D, hi=False)
        return out
    make(reg, "landing_airing_cupboard", "airing_cupboard", "landing", {"idle": cupboard(False), "occupied": cupboard(True)}, eyes=(1282, -210),
         eyes_scale=0.8)

    # boiler valve: a copper tank with a pressure gauge and a red wheel valve
    def valve(rigged):
        cx = 1250
        out = box(1196, -478, 110, 120, 28, pal.COPPER, W, hi=True)
        out.append(det(PB().M(1200, -440).L(1302, -440).M(1200, -398).L(1302, -398), 2.5))
        out += box(1242, -360, 16, 26, 3, pal.COPPER, D, hi=False)
        out += [circle(1280, -418, 14, fill="#FFFFFF", sw=D, stroke=INK)]
        ang = math.radians(-140 if not rigged else 30)
        out.append(path(PB().M(1280, -418).L(1280 + 10 * math.cos(ang), -418 + 10 * math.sin(ang)), fill="none", sw=2.5, stroke="#D8323C" if rigged else INK,
                        sil=False))
        out.append(path(PB().M(1270, -412).Q(1280, -404, 1290, -412), fill="none", sw=2.5, stroke="#D8323C", sil=False))
        rot = 0 if not rigged else 50
        wheel = [circle(cx, -500, 20, fill="none", sw=10, stroke=INK), circle(cx, -500, 20, fill="none", sw=5, stroke=pal.TOMATO[0], sil=False)]
        spokes = PB().M(cx - 20, -500).L(cx + 20, -500).M(cx, -520).L(cx, -480)
        wheel += [path(spokes, fill="none", sw=4, stroke=INK, sil=False), circle(cx, -500, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False)]
        out.append(group(wheel, rot=rot, cx=cx, cy=-500))
        out += box(cx - 6, -482, 12, 8, 2, pal.BRASS, D, hi=False)
        if rigged:
            # cranked all the way: steam wisps hissing from the joint
            st = PB().M(1300, -470).C(1316, -484, 1300, -496, 1318, -510).M(1306, -454).C(1326, -462, 1316, -478, 1334, -486)
            out += [path(st, fill="none", sw=8, stroke=INK, sil=False), path(st, fill="none", sw=4, stroke="#FFFFFF", sil=False)]
        return out
    make(reg, "landing_boiler_valve", "boiler_valve", "landing", {"idle": valve(False), "rigged": valve(True)}, tell=(1334, -530))


# =============================================================================== bathroom
def bathroom(reg):
    # throat spray on the basin ledge
    def spray(rigged):
        out = box(1914, -268, 30, 58, 9, pal.PINK, W, hi=False)
        out.append(hi_line(1919, -260, 8))
        out += box(1920, -288, 18, 22, 4, LINEN, D + 1, hi=False)
        out.append(path(PB().M(1938, -284).L(1956, -290).L(1956, -282).L(1938, -278).Z(), fill="#FFFFFF", sw=D, stroke=INK))
        out.append(rect(1916, -244, 26, 12, 3, fill="#FFFFFF", fop=0.8, sil=False))
        if rigged:
            # the balloon knotted over the nozzle (helium for the throat spray)
            out.append(path(PB().M(1958, -288).Q(1966, -300, 1964, -312), fill="none", sw=D, stroke=INK, sil=False))
            out += blob([(1964, -312), (1984, -330), (1982, -356), (1964, -366), (1946, -356), (1944, -330)], GREEN_BAL, W, k=0.82, hi=True)
        return out
    make(reg, "bathroom_basin_spray", "basin_spray", "bathroom", {"idle": spray(False), "rigged": spray(True)}, tell=(1996, -338))

    # mirror cabinet over the basin
    def cabinet(open_):
        x0, y0, w, h = 2046, -528, 128, 156
        out = box(x0, y0, w, h, 8, LINEN, W, hi=False)
        if open_:
            out.append(dark(PB().rrect(x0 + 10, y0 + 10, w - 20, h - 20, 4)))
            out.append(rect(x0 + 12, y0 + 70, w - 24, 6, 2, fill=PAINT[1], sil=False))
            out += box(x0 + 20, y0 + 30, 22, 40, 6, ROSE, D, hi=False) + box(x0 + 50, y0 + 20, 20, 50, 6, pal.COBALT, D, hi=False)
            out += box(x0 + 80, y0 + 40, 26, 30, 6, BUTTER, D, hi=False)
            out += box(x0 + 24, y0 + 92, 30, 44, 8, pal.PINK, D, hi=False) + box(x0 + 64, y0 + 100, 40, 36, 8, pal.ENAMEL_MINT, D, hi=False)
            # the door swung out on its left hinge: a thin mirrored leaf
            out.append(path(PB().M(x0 + 2, y0 + 4).L(x0 - 26, y0 + 16).L(x0 - 26, y0 + h - 16).L(x0 + 2, y0 + h - 4).Z(), fill=pal.GLASS[1], sw=W, stroke=INK))
        else:
            out += box(x0 + 12, y0 + 12, w - 24, h - 24, 4, pal.GLASS, D + 1, hi=False)
            out.append(path(PB().M(x0 + 24, y0 + 22).L(x0 + 50, y0 + 22).L(x0 + 30, y0 + 100).L(x0 + 18, y0 + 100).Z(), fill="#FFFFFF", fop=0.6, sil=False))
            out += knob(x0 + w - 22, y0 + h / 2, 5)
        return out
    make(reg, "bathroom_cabinet", "bathroom_cabinet", "bathroom", {"idle": cabinet(False), "open": cabinet(True)})

    # bath mixer taps
    def taps(rigged):
        out = box(2340, -300, 16, 110, 6, pal.CHROME, W, hi=False)
        spout = PB().M(2332, -300).L(2380, -300).Q(2398, -300, 2398, -280).L(2386, -276).Q(2386, -288, 2376, -288).L(2332, -288).Z()
        out += [path(spout, fill=pal.CHROME[0]), path(PB().M(2336, -297).L(2376, -297), fill="none", sw=3, stroke="#FFFFFF", sil=False), ink(spout)]
        for hx in (2334, 2370):
            out += [circle(hx, -314, 11, fill=pal.CHROME[1]), circle(hx - 2, -316, 8, fill=pal.CHROME[0], sil=False), circle(hx, -314, 11, fill="none", sw=W, stroke=INK)]
            out.append(det(PB().M(hx - 7, -314).L(hx + 7, -314), 2.5))
        if rigged:
            # bubble bath upended into the tap, a sherbet tube taped to it, foam frothing out of the spout
            out.append(group(box(2360, -372, 30, 50, 8, pal.PINK, W, hi=False) + box(2366, -386, 18, 16, 4, LINEN, D, hi=False), rot=160, cx=2375, cy=-340))
            out += box(2320, -360, 22, 40, 6, BUTTER, W, hi=False)
            for fx, fy, r in ((2396, -268, 10), (2408, -258, 8), (2390, -254, 7)):
                out.append(circle(fx, fy, r, fill="#FFFFFF", sw=D, stroke=INK))
        return out
    make(reg, "bathroom_bath_taps", "bath_taps", "bathroom", {"idle": taps(False), "rigged": taps(True)}, tell=(2426, -352))

    # the rubber duck on the bath rim
    def duck(rigged):
        out = []
        if rigged:
            # the wind-up croc tucked behind the duck: its toothy snout + the wind-up key
            snout = [(2508, -206), (2464, -214), (2458, -200), (2508, -196)]
            out += shape(snout, pal.GRASS[0], W)
            out.append(path(PB().M(2466, -207).L(2471, -200).L(2476, -207).L(2481, -200).L(2486, -207).L(2491, -200), fill="#FFFFFF", sw=2, stroke=INK,
                            sil=False))
            out.append(circle(2500, -216, 3, fill=INK, sil=False))
            out += [circle(2548, -270, 9, fill=pal.BRASS[0], sw=D, stroke=INK), path(PB().M(2548, -261).L(2548, -248), fill="none", sw=4, stroke=INK)]
        body = PB().M(2520, -200).Q(2520, -236, 2550, -238).Q(2556, -262, 2576, -262).Q(2600, -262, 2598, -238).L(2612, -232).L(2598, -224)
        body.Q(2600, -200, 2570, -198).Z()
        out += [path(body, fill="#E8B830"), path(PB().M(2522, -206).Q(2524, -232, 2552, -234).Q(2558, -256, 2576, -258).Q(2594, -258, 2592, -236)
                                                  .Q(2560, -214, 2522, -206).Z(), fill="#FFD23F", sil=False)]
        out.append(path(PB().M(2598, -238).L(2616, -232).L(2598, -224).Z(), fill=pal.TOMATO[0], sw=D, stroke=INK))
        out.append(path(PB().M(2532, -222).Q(2548, -212, 2566, -222), fill="none", sw=D, stroke=INK, sil=False))
        out.append(circle(2582, -248, 4, fill=INK, sil=False))
        out.append(circle(2562, -252, 3, fill="#FFFFFF", fop=0.7, sil=False))
        out.append(ink(body))
        return out
    make(reg, "bathroom_duck", "rubber_duck", "bathroom", {"idle": duck(False), "rigged": duck(True)}, tell=(2620, -278))

    # the roll-top bath on brass claw feet
    def bath(peek):
        out = [shadow(2458, -6, 156, 8)]
        for fx in (2352, 2560):
            foot = PB().M(fx - 14, -52).L(fx + 14, -52).Q(fx + 16, -30, fx + 22, -16).Q(fx + 8, -10, fx, -16).Q(fx - 8, -10, fx - 22, -16).Q(fx - 16, -30, fx - 14, -52).Z()
            out += [path(foot, fill=pal.BRASS[0]), path(PB().M(fx - 8, -46).Q(fx - 10, -30, fx - 14, -20), fill="none", sw=3, stroke=pal.BRASS[2], sil=False),
                    ink(foot)]
        tub = PB().M(2310, -196).L(2606, -196).Q(2600, -60, 2540, -46).L(2376, -46).Q(2316, -60, 2310, -196).Z()
        out.append(path(tub, fill=PORC_SH))
        out.append(path(PB().M(2316, -192).L(2570, -192).Q(2560, -80, 2520, -60).L(2380, -60).Q(2322, -72, 2316, -192).Z(), fill="#FFFFFF", sil=False))
        out.append(rect(2336, -176, 90, 7, 3.5, fill=pal.GLASS[0], fop=0.8, sil=False))
        out.append(ink(tub))
        out += box(2298, -208, 320, 18, 9, LINEN, W, hi=False)
        if peek:
            # a heap of foam on the rim with a dark slot where she lies low
            gap = PB().M(2396, -208).Q(2458, -270, 2520, -208).Z()
            out.append(dark(gap))
            for fx, fy, r in ((2394, -216, 18), (2374, -230, 12), (2522, -216, 18), (2542, -228, 12), (2458, -250, 11), (2426, -240, 10), (2490, -240, 10)):
                out.append(circle(fx, fy, r, fill="#FFFFFF", sw=D, stroke=INK))
            out += glove_fingers(2514, -222, -1, 0.7, 2)
        return out
    make(reg, "bathroom_bath", "bath", "bathroom", {"idle": bath(False), "occupied": bath(True)}, eyes=(2458, -218), eyes_scale=0.8)

    # wicker laundry basket with a lid, a pink towel sleeve hanging out
    x0, x1 = 2646, 2762

    def basket(peek):
        out = [shadow(2704, -6, 66, 6)]
        body = PB().M(x0, -200).L(x1, -200).L(x1 - 14, -24).L(x0 + 14, -24).Z()
        out.append(path(body, fill=WICKER[1]))
        out.append(path(PB().M(x0 + 4, -196).L(x1 - 22, -196).L(x1 - 34, -30).L(x0 + 16, -30).Z(), fill=WICKER[0], sil=False))
        weave = PB()
        for row, y in enumerate(range(-186, -30, 16)):
            off = 0 if row % 2 == 0 else 10
            for x in range(x0 + 10 + off, x1 - 10, 20):
                weave.M(x, y).Q(x + 5, y + 5, x + 10, y)
        out.append(path(weave, fill="none", sw=2.5, stroke=WICKER[1], sil=False))
        out.append(det(PB().M(x0 + 6, -150).L(x1 - 6, -150).M(x0 + 10, -90).L(x1 - 10, -90), 2.5))
        out.append(ink(body))
        if peek:
            out.append(dark(PB().poly([(x0 + 6, -200), (x1 - 6, -200), (x1 - 6, -226), (x0 + 6, -254)])))
            lid = PB().poly([(x0 - 8, -256), (x1 + 8, -226), (x1 + 10, -210), (x0 - 6, -240)])
            out += [path(lid, fill=WICKER[0]), ink(lid)]
            out += glove_fingers(x0 + 22, -212, -1, 0.75, 2)
        else:
            out += box(x0 - 6, -214, x1 - x0 + 12, 18, 8, WICKER, W, hi=False)
            out += [circle(2704, -222, 8, fill=WICKER[1], sw=D, stroke=INK)]
            sleeve = PB().M(2690, -212).Q(2700, -250, 2730, -236).Q(2740, -210, 2716, -200).Z()
            out += [path(sleeve, fill=ROSE[0]), ink(sleeve, D)]
        return out
    make(reg, "bathroom_laundry_basket", "laundry_basket", "bathroom", {"idle": basket(False), "occupied": basket(True)}, eyes=(2708, -222),
         eyes_scale=0.8)



# =============================================================================== bedroom
def bedroom(reg):
    wal = pal.WALNUT
    x0, x1, top = 2842, 2978, -500

    def wardrobe(peek):
        out = [shadow(2910, -8, 80, 6)]
        out += box(x0, top, x1 - x0, 480, 6, wal, W, hi=True)
        # carved crest + cornice
        crest = PB().M(x0 - 8, top - 12).L(x1 + 8, top - 12).L(x1 + 8, top + 8).L(x0 - 8, top + 8).Z()
        out += [path(crest, fill=wal[1]), ink(crest)]
        arc = PB().M(2880, top - 12).Q(2910, top - 44, 2940, top - 12).Z()
        out += [path(arc, fill=wal[0]), ink(arc, D + 1), circle(2910, top - 24, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False)]
        # feet
        for fx in (x0 + 10, x1 - 22):
            out += box(fx, -26, 12, 18, 3, wal, D, hi=False)
        mid = 2910
        if peek:
            out.append(dark(PB().rrect(mid + 2, top + 12, x1 - mid - 12, 450, 4)))
            leaf = PB().M(x1 - 2, top + 10).L(x1 + 34, top + 30).L(x1 + 34, -40).L(x1 - 2, -24).Z()
            out += [path(leaf, fill=wal[1]), ink(leaf, D + 1)]
            out += panel_door(x0 + 10, top + 12, mid - x0 - 12, 450, wal, panels=2)
            out += glove_fingers(mid + 4, -336, -1, 0.85, 3)
        else:
            out += panel_door(x0 + 10, top + 12, mid - x0 - 12, 450, wal, panels=2)
            out += panel_door(mid + 2, top + 12, x1 - mid - 12, 450, wal, panels=2)
            out += knob(mid - 10, -270, 6) + knob(mid + 10, -270, 6)
        return out
    make(reg, "bedroom_wardrobe", "wardrobe", "bedroom", {"idle": wardrobe(False), "occupied": wardrobe(True)}, eyes=(2939, -310), eyes_scale=0.8)

    # brass bedstead: headboard, footboard, mattress + duvet (the pillow and the valance are their own hotspots)
    def bed(rigged):
        out = []
        br = pal.BRASS
        for bx, h in ((3014, 330), (3300, 230)):
            w = 30 if bx == 3014 else 24
            out += box(bx, -h, w, h - 30, 8, br, W, hi=False)
            out += [circle(bx + w / 2, -h - 8, 12, fill=br[0], sw=W, stroke=INK), circle(bx + w / 2 - 4, -h - 12, 3.5, fill="#FFFFFF", fop=0.7, sil=False)]
        out.append(rect(3040, -300, 10, 100, 4, fill=br[1], sil=False))
        out += box(3040, -200, 268, 44, 12, LINEN, W, hi=False)
        duvet = PB().M(3120, -214).L(3300, -214).L(3304, -150).L(3116, -150).Q(3100, -182, 3120, -214).Z()
        out.append(path(duvet, fill=DUVET[0]))
        out.append(path(PB().M(3240, -214).L(3300, -214).L(3304, -150).L(3250, -150).Z(), fill=DUVET[1], sil=False))
        dots = PB()
        for dx in range(3140, 3290, 30):
            for dy in (-196, -170):
                dots.circle(dx + (10 if dy == -170 else 0), dy, 4)
        out.append(path(dots, fill=DUVET[2], sil=False))
        out.append(path(PB().M(3120, -214).L(3300, -214).L(3300, -204).L(3118, -204).Z(), fill="#FFFFFF", sil=False))
        out.append(ink(duvet))
        if rigged:
            # a goat-shaped lump tucked in, one ear and the pink collar bell out
            lump = PB().M(3180, -212).Q(3200, -276, 3284, -214).Z()
            out += [path(lump, fill=DUVET[0]), ink(lump)]
            ear = [(3262, -238), (3290, -262), (3284, -232)]
            out += shape(ear, GOAT[0], W)
            out.append(circle(3270, -222, 7, fill="#FF7FB0", sw=D, stroke=INK))
        return out
    make(reg, "bedroom_bed", "bed", "bedroom", {"idle": bed(False), "rigged": bed(True)}, tell=(3300, -296))

    def pillow(rigged):
        out = []
        if rigged:
            out += blob([(3096, -228), (3118, -250), (3132, -236), (3120, -214)], SQUEAK, W, k=0.8)
            out.append(circle(3124, -246, 4, fill=INK, sil=False))
        pb = PB().M(3050, -206).Q(3044, -248, 3090, -246).Q(3134, -248, 3128, -206).Q(3090, -198, 3050, -206).Z()
        out += [path(pb, fill=LINEN[1]), path(PB().M(3054, -208).Q(3050, -242, 3090, -242).Q(3122, -242, 3118, -214).Q(3086, -206, 3054, -208).Z(),
                                                 fill="#FFFFFF", sil=False)]
        out.append(det(PB().M(3068, -226).Q(3090, -218, 3110, -228), 2.5))
        out.append(ink(pb))
        if rigged:
            out.append(path(PB().M(3110, -236).Q(3122, -250, 3136, -250), fill="none", sw=W, stroke=INK, sil=False))
        return out
    make(reg, "bedroom_pillow", "pillow", "bedroom", {"idle": pillow(False), "rigged": pillow(True)}, tell=(3140, -272))

    # the frilled valance under the mattress; occupied = hem lifted on a dark gap
    def under(peek):
        out = [shadow(3172, -6, 150, 6)]
        sk = PB().M(3040, -156).L(3304, -156).L(3304, -40)
        for i in range(10):
            xa = 3304 - (i + 0.5) * 26.4
            xb = 3304 - (i + 1) * 26.4
            sk.Q(xa, -26, xb, -40)
        sk.Z()
        out.append(path(sk, fill=ROSE[0]))
        pleats = PB()
        for x in range(3066, 3300, 26):
            pleats.M(x, -150).L(x, -44)
        out.append(path(pleats, fill="none", sw=3, stroke=ROSE[1], sil=False))
        out.append(rect(3040, -156, 264, 14, 4, fill=ROSE[2], sil=False))
        if peek:
            gap = PB().M(3120, -38).Q(3124, -104, 3168, -108).Q(3212, -104, 3216, -38).Z()
            out.append(dark(gap))
            out.append(det(PB().M(3116, -36).Q(3120, -110, 3168, -114).Q(3216, -110, 3220, -36), W - 1))
            out += glove_fingers(3212, -78, -1, 0.75, 2)
        out.append(ink(sk))
        return out
    make(reg, "bedroom_under_bed", "under_bed", "bedroom", {"idle": under(False), "occupied": under(True)}, eyes=(3168, -70), eyes_scale=0.8)

    # bedside table, a lamp, his specs folded for the nap
    def bedside(rigged):
        out = [shadow(3420, -6, 54, 5)]
        out += box(3378, -150, 84, 124, 6, wal, W, hi=True)
        out += box(3370, -162, 100, 16, 6, wal, W, hi=False)
        out.append(det(PB().M(3378, -100).L(3462, -100)))
        out += knob(3420, -122, 5)
        for fx in (3384, 3448):
            out += box(fx, -28, 8, 20, 2, wal, D, hi=False)
        out += box(3441, -230, 10, 70, 3, pal.BRASS, D + 1, hi=False)
        shade_ = PB().M(3420, -230).L(3470, -230).L(3460, -268).L(3430, -268).Z()
        out += [path(shade_, fill="#FFE59A"), path(PB().M(3448, -230).L(3470, -230).L(3460, -268).L(3452, -268).Z(), fill="#F2C86A", sil=False), ink(shade_, D + 1)]
        lens = "#FFFFFF" if not rigged else BUTTER[0]
        specs = PB().circle(3394, -176, 10).circle(3418, -176, 10)
        out += [path(specs, fill=lens, fop=0.9), path(PB().M(3404, -178).Q(3406, -184, 3408, -178), fill="none", sw=2.5, stroke=INK, sil=False),
                path(specs, fill="none", sw=3.5, stroke=INK)]
        if rigged:
            # butter smeared on the lenses + the pat of butter and the knife left beside them
            out.append(path(PB().M(3388, -182).Q(3398, -170, 3402, -180).M(3412, -182).Q(3422, -168, 3426, -178), fill="none", sw=3, stroke=BUTTER[1], sil=False))
            out += box(3434, -176, 22, 12, 3, BUTTER, D, hi=False)
            out.append(path(PB().M(3360, -168).L(3392, -164), fill="none", sw=4, stroke=INK, sil=False))
        return out
    make(reg, "bedroom_bedside", "bedside", "bedroom", {"idle": bedside(False), "rigged": bedside(True)}, tell=(3404, -212))


# =============================================================================== dressing room
def dressing(reg):
    mah = pal.MAHOGANY

    def trunk(open_):
        x0, x1, top, bot = 3734, 3866, -150, -24
        out = [shadow(3800, -6, 72, 6)]
        if open_:
            lid = PB().M(x0, top).L(x1, top).L(x1 + 10, top - 66).L(x0 + 10, top - 74).Z()
            out += [path(lid, fill=mah[1]), path(PB().M(x0 + 14, top - 8).L(x1 - 12, top - 8).L(x1 - 4, top - 60).L(x0 + 20, top - 66).Z(), fill=pal.DARK_GAP,
                                                 sil=False), ink(lid)]
            frill = PB().M(x0 + 16, top + 2)
            for i in range(8):
                frill.Q(x0 + 16 + (i + 0.5) * 13, top - 30 - (i % 2) * 10, x0 + 16 + (i + 1) * 13, top + 2)
            out += [path(frill, fill=TUTU[0]), ink(frill, D + 1)]
            out += box(x1 - 44, top - 40, 30, 36, 6, pal.BRASS, D, hi=False)
        else:
            lid = PB().M(x0 - 4, top).Q(3800, top - 40, x1 + 4, top).Z()
            out += [path(lid, fill=mah[0]), ink(lid)]
        out += box(x0, top, x1 - x0, bot - top, 10, mah, W, hi=True)
        for sx in (x0 + 26, x1 - 34):
            out.append(rect(sx, top + 2, 8, bot - top - 4, 2, fill="#5E3A2A", sil=False))
        for cx_, cy_ in ((x0 + 6, top + 6), (x1 - 18, top + 6), (x0 + 6, bot - 18), (x1 - 18, bot - 18)):
            out.append(rect(cx_, cy_, 12, 12, 3, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
        out.append(rect(3790, top + 14, 20, 22, 3, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
        return out
    make(reg, "dressing_costume_trunk", "costume_trunk", "dressing", {"idle": trunk(False), "open": trunk(True)})

    # costume rail: brass rail, four costumes on hangers; occupied = two parted on a dark gap
    cols = [TOMATO_SOFT, ("#F2D58A", "#D9B866", "#FFF0C4"), ("#8FC7E8", "#6FA8CC", "#C9E6F6"), ("#B89CE0", "#9A7EC4", "#DCCBF4")]

    def rail(peek):
        out = [shadow(3981, -8, 72, 6)]
        br = pal.BRASS
        for px in (3920, 4042):
            out += box(px - 5, -430, 10, 406, 4, br, D + 1, hi=False)
            out += box(px - 16, -30, 32, 8, 3, br, D, hi=False)
        out += box(3910, -438, 142, 12, 5, br, D + 1, hi=False)
        xs = [3924, 3938, 4018, 4032] if peek else [3934, 3962, 3990, 4018]
        if peek:
            out.append(dark(PB().poly([(3960, -412), (4022, -412), (4010, -112), (3974, -112)])))
        for i, x in enumerate(xs):
            m = cols[i]
            out.append(path(PB().M(x + 13, -426).Q(x + 13, -438, x + 20, -434), fill="none", sw=D, stroke=INK, sil=False))
            garment = PB().M(x, -416).L(x + 26, -416).L(x + 38, -110).L(x - 12, -110).Z()
            out += [path(garment, fill=m[1]), path(PB().M(x + 2, -414).L(x + 18, -414).L(x + 24, -114).L(x - 8, -114).Z(), fill=m[0], sil=False), ink(garment, D + 1)]
            out.append(path(PB().M(x - 12, -110).Q(x + 13, -100, x + 38, -110), fill="none", sw=D, stroke=INK, sil=False))
        if peek:
            out += glove_fingers(3978, -270, -1, 0.7, 2)
        return out
    make(reg, "dressing_costume_rail", "costume_rail", "dressing", {"idle": rail(False), "occupied": rail(True)}, eyes=(3992, -300), eyes_scale=0.7)

    # trophy shelf: three gold cups on a bracketed shelf; rigged = the bracket screws backed out, the shelf tipping
    def shelf(rigged):
        rot = 0 if not rigged else 4
        items = box(4236, -420, 128, 14, 5, pal.WALNUT, W, hi=False)
        for x, h in ((4250, 70), (4290, 100), (4332, 60)):
            cup = PB().M(x - 12, -420).L(x + 12, -420).L(x + 8, -420 - h * 0.3).Q(x + 22, -420 - h, x, -420 - h).Q(x - 22, -420 - h, x - 8, -420 - h * 0.3).Z()
            items += [path(cup, fill=pal.BRASS[0]), path(PB().M(x - 8, -420 - h * 0.8).Q(x - 12, -420 - h * 0.55, x - 4, -420 - h * 0.4), fill="none", sw=3,
                                                         stroke=pal.BRASS[2], sil=False), ink(cup)]
        out = [group(items, rot=rot, cx=4300, cy=-414)]
        for bx in (4252, 4348):
            out += box(bx - 5, -408, 10, 30, 3, pal.WALNUT, D, hi=False)
        if rigged:
            for sx in (4252, 4348):
                out.append(path(PB().M(sx, -392).L(sx + 10, -380), fill="none", sw=4, stroke=pal.CHROME[1], sil=False))
                out.append(circle(sx + 12, -378, 4, fill=pal.CHROME[0], sw=2, stroke=INK, sil=False))
        return out
    make(reg, "dressing_trophy_shelf", "trophy_shelf", "dressing", {"idle": shelf(False), "rigged": shelf(True)}, tell=(4376, -540))

    # dressmaker's dummy on a tripod stand, wearing his velvet cloak; rigged = a pink tutu instead
    def dummy(rigged):
        out = []
        stand = PB().M(4420, -150).L(4420, -34).M(4420, -34).L(4390, -22).M(4420, -34).L(4450, -22)
        out += [path(stand, fill="none", sw=10, stroke=INK), path(stand, fill="none", sw=5, stroke=pal.WALNUT[0], sil=False)]
        torso = PB().M(4380, -330).Q(4420, -350, 4460, -330).L(4470, -250).Q(4450, -200, 4460, -150).L(4380, -150).Q(4390, -200, 4370, -250).Z()
        out += [path(torso, fill="#DCCCB2"), path(PB().M(4384, -326).Q(4412, -340, 4444, -328).L(4450, -252).Q(4432, -206, 4440, -156).L(4388, -156)
                                                   .Q(4394, -206, 4378, -252).Z(), fill="#EFE3CE", sil=False), ink(torso)]
        out += [circle(4420, -350, 14, fill="#EFE3CE", sw=W, stroke=INK)]
        if rigged:
            tut = PB().M(4360, -190)
            for i in range(8):
                tut.Q(4360 + (i + 0.5) * 16, -150 - (i % 2) * 12, 4360 + (i + 1) * 16, -186)
            tut.L(4480, -210).Q(4420, -230, 4360, -210).Z()
            out += [path(tut, fill=TUTU[0]), path(PB().M(4370, -206).Q(4420, -222, 4470, -206), fill="none", sw=3, stroke=TUTU[2], sil=False), ink(tut)]
        else:
            cloak = PB().M(4376, -318).L(4464, -318).L(4486, -160).Q(4420, -148, 4354, -160).Z()
            out += [path(cloak, fill=CLOAK[1]), path(PB().M(4380, -314).L(4444, -314).L(4456, -166).Q(4410, -158, 4362, -166).Z(), fill=CLOAK[0], sil=False),
                    ink(cloak)]
            out.append(circle(4420, -314, 7, fill=pal.BRASS[0], sw=D, stroke=INK))
        return out
    make(reg, "dressing_dummy", "cloak_dummy", "dressing", {"idle": dummy(False), "rigged": dummy(True)}, tell=(4480, -336))



# =============================================================================== conservatory
def conservatory(reg):
    # Beryl's feed bin: a galvanised bin with a lid, a goat-head pictogram; rigged = treacle poured over the feed
    def bin_(rigged):
        out = [shadow(4022, -6, 62, 6)]
        body = PB().M(3970, -150).L(4074, -150).L(4066, -24).L(3978, -24).Z()
        out += [path(body, fill=ZINC[1]), path(PB().M(3974, -146).L(4050, -146).L(4044, -30).L(3982, -30).Z(), fill=ZINC[0], sil=False)]
        rib = PB().M(3974, -110).L(4070, -110).M(3976, -64).L(4068, -64)
        out += [path(rib, fill="none", sw=4, stroke=ZINC[2], sil=False), det(rib, 2)]
        out.append(ink(body))
        # goat-head pictogram (Beryl's)
        out.append(circle(4022, -88, 17, fill=GOAT[0], sw=D, stroke=INK))
        out.append(path(PB().M(4010, -100).L(4002, -114).M(4034, -100).L(4042, -114), fill="none", sw=D, stroke=INK, sil=False))
        out.append(circle(4022, -76, 5, fill="#FF7FB0", sil=False))
        out += box(3960, -170, 124, 22, 8, ZINC, W, hi=False)
        out += box(4010, -182, 24, 12, 4, ZINC, D, hi=False)
        if rigged:
            # the lid pushed back and treacle glugging over the rim and down the side
            glug = PB().M(3968, -168).Q(3990, -186, 4020, -170).L(4018, -150).Q(4012, -120, 4004, -108).Q(3998, -120, 3996, -150).Q(3986, -140, 3980, -130)
            glug.Q(3974, -142, 3972, -154).Z()
            out += [path(glug, fill=TREACLE[0]), path(PB().M(3990, -168).Q(4000, -174, 4010, -168), fill="none", sw=3, stroke=TREACLE[2], sil=False), ink(glug, D + 1)]
            out += box(4034, -206, 36, 44, 8, ("#2D5E41", "#1F4630", "#3E7A55"), W, hi=False)
        return out
    make(reg, "conservatory_feed_bin", "feed_bin", "conservatory", {"idle": bin_(False), "rigged": bin_(True)}, tell=(4096, -196))

    # the wicker hamper with leather straps; occupied = the lid lifted on a dark gap
    def hamper(peek):
        x0, x1 = 4128, 4258
        out = [shadow(4193, -6, 72, 6)]
        out += box(x0, -170, x1 - x0, 146, 12, WICKER, W, hi=False)
        weave = PB()
        for row, y in enumerate(range(-160, -30, 14)):
            off = 0 if row % 2 == 0 else 9
            for x in range(x0 + 8 + off, x1 - 8, 18):
                weave.M(x, y).Q(x + 4.5, y + 5, x + 9, y)
        out.append(path(weave, fill="none", sw=2.5, stroke=WICKER[1], sil=False))
        for sx in (x0 + 26, x1 - 36):
            out += box(sx, -176, 12, 110, 3, pal.WALNUT, D, hi=False)
            out.append(rect(sx + 1, -96, 10, 10, 2, fill=pal.BRASS[0], sw=2, stroke=INK, sil=False))
        if peek:
            out.append(dark(PB().poly([(x0 + 8, -170), (x1 - 8, -170), (x1 - 8, -192), (x0 + 8, -226)])))
            lid = PB().poly([(x0 - 8, -228), (x1 + 8, -194), (x1 + 8, -178), (x0 - 6, -212)])
            out += [path(lid, fill=WICKER[0]), ink(lid)]
            out += glove_fingers(x0 + 20, -184, -1, 0.75, 2)
        else:
            out += box(x0 - 6, -184, x1 - x0 + 12, 18, 8, WICKER, W, hi=False)
            out += box(4178, -196, 30, 12, 5, pal.WALNUT, D, hi=False)
        return out
    make(reg, "conservatory_hamper", "hamper", "conservatory", {"idle": hamper(False), "occupied": hamper(True)}, eyes=(4196, -192), eyes_scale=0.8)

    # potting bench: slatted wooden bench, a pot plant, a trowel; open = the apple and the feathers it hides
    def bench(open_):
        lw = pal.LIGHTWOOD
        out = [shadow(4620, -6, 74, 6)]
        for lx in (4566, 4674):
            out += box(lx - 5, -160, 10, 136, 3, lw, D + 1, hi=False)
        out += box(4560, -76, 120, 10, 3, lw, D, hi=False)
        out += box(4554, -172, 132, 16, 5, lw, W, hi=True)
        out += box(4570, -214, 30, 44, 6, TERRACOTTA, W, hi=False)
        out += [circle(4585, -228, 15, fill=pal.GRASS[0], sw=W, stroke=INK), circle(4578, -240, 9, fill=pal.GRASS[0], sw=D, stroke=INK)]
        out.append(group([rect(4614, -196, 34, 10, 4, fill=pal.CHROME[0], sw=D, stroke=INK), rect(4646, -196, 22, 10, 4, fill=pal.WALNUT[0], sw=D, stroke=INK)],
                         rot=-8, cx=4640, cy=-190))
        if open_:
            out += [circle(4648, -210, 15, fill=pal.TOMATO[0], sw=W, stroke=INK), circle(4643, -215, 4, fill="#FFFFFF", fop=0.6, sil=False),
                    path(PB().M(4648, -225).L(4652, -236), fill="none", sw=D, stroke=INK)]
            feather = PB().M(4664, -176).Q(4690, -216, 4700, -242).Q(4702, -214, 4672, -176).Z()
            out += [path(feather, fill="#FFFFFF"), ink(feather, D), path(PB().M(4668, -180).L(4698, -236), fill="none", sw=2, stroke=INK, sil=False)]
        else:
            out += box(4618, -196, 54, 24, 6, WICKER, D + 1, hi=False)
        return out
    make(reg, "conservatory_potting_bench", "potting_bench", "conservatory", {"idle": bench(False), "open": bench(True)})


def build(reg):
    landing(reg)
    bathroom(reg)
    bedroom(reg)
    dressing(reg)
    conservatory(reg)
