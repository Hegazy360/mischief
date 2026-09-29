"""props_grey - greybox hotspot props for the rooms outside the slice (landing, bathroom, bedroom,
dressing room, conservatory, garden): correct silhouettes as flat pastel blocks with 4 px ink,
so every hotspot already has idle / outline (+ occupied for hiding spots, rigged for rig points,
open for containers) at its final position. Stage 3 replaces them with final art at the same
paths and hit boxes.
"""
import math

import pal
from draw import glove_fingers, hush_eyes, shadow, sparkle
from props_base import Prop, emit
from svgk import INK, PB, circle, desat, ellipse, lift, mix, mul, path, rect

GW = 4.0


def tone(room, k=1.0):
    base = desat(mix(pal.ROOM[room], "#FFFFFF", 0.42), 0.7)
    return mul(base, k) if k != 1.0 else base


def gb(x, y, w, h, r, col, sw=GW):
    return [rect(x, y, w, h, r, fill=col), rect(x, y, w, h, r, fill="none", sw=sw, stroke=INK, sop=0.85)]


def gp(pb, col, sw=GW):
    return [path(pb, fill=col), path(pb, fill="none", sw=sw, stroke=INK, sop=0.85)]


def gl(pb, sw=3.0):
    return path(pb, fill="none", sw=sw, stroke=INK, sop=0.7, sil=False)


def dark(pb):
    return path(pb, fill=pal.DARK_GAP, sil=False)


def make(reg, hid, name, room, draw_fn, kind, eyes=None, tell=None):
    p = Prop(name, room)
    p.add("idle", draw_fn("idle"))
    if kind == "hiding":
        p.add("occupied", draw_fn("occupied"))
        if eyes:
            p.extra["eyes"] = list(eyes)
    elif kind == "rig_point":
        p.add("rigged", draw_fn("rigged"))
        if tell:
            p.add("rigged", sparkle(tell[0], tell[1], 12))
    elif kind == "container":
        p.add("open", draw_fn("open"))
    emit(reg, hid, p)


# ---------------------------------------------------------------------------------------- landing
def landing(reg):
    t = tone("landing")

    def head(s):
        return gb(1098, -236, 22, 236, 4, mul(t, 0.8)) + [circle(1109, -250, 15, fill=mul(t, 0.8), sw=GW, stroke=INK)]
    make(reg, "stairs_head", "stair_head", "landing", head, "stairs")

    def cupboard(s):
        out = [shadow(1251, -8, 74, 6)] + gb(1182, -330, 138, 312, 6, t)
        if s == "occupied":
            out.append(dark(PB().rrect(1196, -316, 110, 280, 4)))
            out += hush_eyes(1236, -210, 1, 0.9)
            out += gb(1284, -318, 34, 284, 3, mul(t, 0.9))
            out += glove_fingers(1282, -236, -1, 0.85, 3)
        else:
            out.append(gl(PB().rrect(1196, -316, 110, 280, 4)))
            out.append(circle(1296, -170, 6, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
        return out
    make(reg, "landing_airing_cupboard", "airing_cupboard", "landing", cupboard, "hiding", eyes=(1236, -210))

    def valve(s):
        out = gb(1196, -478, 110, 120, 30, mul(t, 0.92))
        out += [gl(PB().M(1250, -358).L(1250, -334), 8)]
        ang = 0 if s == "idle" else 40
        wheel = PB().circle(1250, -500, 18)
        out += [path(wheel, fill="none", sw=8, stroke=INK), path(wheel, fill="none", sw=4, stroke="#D8564A", sil=False)]
        a = math.radians(ang)
        out.append(gl(PB().M(1250 - 18 * math.cos(a), -500 - 18 * math.sin(a)).L(1250 + 18 * math.cos(a), -500 + 18 * math.sin(a)), 4))
        out.append(ellipse(1250, -430, 22, 10, fill="#FFFFFF", fop=0.5, sil=False))
        return out
    make(reg, "landing_boiler_valve", "boiler_valve", "landing", valve, "rig_point", tell=(1300, -520))


# ---------------------------------------------------------------------------------------- bathroom
def bathroom(reg):
    t = tone("bathroom")

    def spray(s):
        out = gb(1914, -268, 30, 58, 8, mix("#F28DB2", t, 0.4))
        out += gb(1918, -290, 22, 24, 4, "#FFFFFF")
        out.append(gl(PB().M(1940, -284).L(1956, -290), 5))
        if s == "rigged":
            out += [circle(1962, -300, 13, fill="#7FD06A", sw=GW, stroke=INK)]
            out.append(gl(PB().M(1962, -313).Q(1972, -330, 1966, -346), 2.5))
        return out
    make(reg, "bathroom_basin_spray", "basin_spray", "bathroom", spray, "rig_point", tell=(1980, -330))

    def cabinet(s):
        out = gb(2046, -528, 128, 156, 8, t)
        if s == "open":
            out.append(dark(PB().rrect(2058, -516, 104, 132, 4)))
            out += gb(2064, -420, 30, 34, 6, "#F2B8C8") + gb(2104, -430, 22, 44, 6, "#9FD6F0") + gb(2132, -416, 22, 30, 6, "#FFE59A")
            out += gb(2024, -522, 30, 144, 3, mul(t, 0.9))
        else:
            out.append(gl(PB().M(2110, -520).L(2110, -380)))
            out.append(circle(2100, -450, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
            out.append(circle(2120, -450, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
        return out
    make(reg, "bathroom_cabinet", "bathroom_cabinet", "bathroom", cabinet, "container")

    def taps(s):
        out = gb(2340, -300, 16, 110, 6, pal.CHROME[1])
        out += gp(PB().M(2332, -300).L(2380, -300).Q(2396, -300, 2396, -280).L(2386, -276).Q(2386, -288, 2376, -288).L(2332, -288).Z(), pal.CHROME[0])
        out += [circle(2334, -312, 10, fill=pal.CHROME[0], sw=GW, stroke=INK), circle(2370, -312, 10, fill=pal.CHROME[0], sw=GW, stroke=INK)]
        if s == "rigged":
            out += gb(2300, -350, 30, 44, 8, "#F28DB2") + gb(2350, -346, 26, 36, 6, "#FFE36B")
        return out
    make(reg, "bathroom_bath_taps", "bath_taps", "bathroom", taps, "rig_point", tell=(2420, -350))

    def duck(s):
        out = gp(PB().M(2520, -200).Q(2520, -236, 2550, -238).Q(2556, -262, 2576, -262).Q(2600, -262, 2598, -238).L(2612, -232).L(2598, -224)
                 .Q(2600, -200, 2570, -198).Z(), "#FFD23F")
        out.append(circle(2582, -248, 3.5, fill=INK, sil=False))
        if s == "rigged":
            # a wind-up croc hides behind the duck: a toothy snout poking out
            out += gp(PB().M(2506, -204).L(2470, -214).L(2468, -196).L(2506, -196).Z(), "#6CC06A")
            out.append(gl(PB().M(2474, -205).L(2478, -200).L(2482, -205).L(2486, -200).L(2490, -205), 2))
        return out
    make(reg, "bathroom_duck", "rubber_duck", "bathroom", duck, "rig_point", tell=(2616, -276))

    def bath(s):
        out = [shadow(2458, -6, 150, 7)]
        out += gp(PB().M(2310, -196).L(2606, -196).Q(2600, -60, 2540, -46).L(2376, -46).Q(2316, -60, 2310, -196).Z(), "#FFFFFF")
        out += gb(2300, -206, 316, 18, 9, "#F4F6FA")
        for fx in (2352, 2560):
            out += gp(PB().M(fx - 12, -50).L(fx + 12, -50).L(fx + 18, -14).L(fx - 18, -14).Z(), pal.BRASS[0])
        if s == "occupied":
            out.append(dark(PB().M(2400, -200).Q(2458, -236, 2520, -200).Z()))
            out += hush_eyes(2458, -214, 1, 0.8)
        return out
    make(reg, "bathroom_bath", "bath", "bathroom", bath, "hiding", eyes=(2458, -214))

    def basket(s):
        out = [shadow(2704, -6, 64, 6)] + gp(PB().M(2646, -200).L(2762, -200).L(2748, -24).L(2660, -24).Z(), mix("#C9A06A", t, 0.3))
        out.append(gl(PB().M(2650, -150).L(2758, -150).M(2654, -100).L(2754, -100).M(2656, -60).L(2752, -60), 2.5))
        if s == "occupied":
            out.append(dark(PB().M(2656, -200).Q(2704, -230, 2752, -200).Z()))
            out += hush_eyes(2704, -214, -1, 0.8)
            out += gb(2640, -222, 128, 16, 7, mix("#C9A06A", t, 0.2))
        else:
            out += gb(2640, -212, 128, 16, 7, mix("#C9A06A", t, 0.2))
            out += gp(PB().M(2690, -212).Q(2700, -250, 2730, -236).Q(2724, -222, 2716, -212).Z(), "#F2B8C8")
        return out
    make(reg, "bathroom_laundry_basket", "laundry_basket", "bathroom", basket, "hiding", eyes=(2704, -214))


# ---------------------------------------------------------------------------------------- bedroom
def bedroom(reg):
    t = tone("bedroom")

    def wardrobe(s):
        out = [shadow(2910, -8, 76, 6)] + gb(2842, -500, 136, 480, 6, t) + gb(2834, -512, 152, 20, 6, mul(t, 0.9))
        if s == "occupied":
            out.append(dark(PB().rrect(2856, -486, 108, 440, 4)))
            out += hush_eyes(2890, -310, 1, 0.9)
            out += gb(2922, -490, 44, 446, 3, mul(t, 0.92))
            out += glove_fingers(2920, -290, -1, 0.9, 3)
        else:
            out.append(gl(PB().M(2910, -486).L(2910, -46)))
            out += [circle(2900, -270, 6, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False), circle(2920, -270, 6, fill=pal.BRASS[0], sw=2.5, stroke=INK,
                                                                                                       sil=False)]
        return out
    make(reg, "bedroom_wardrobe", "wardrobe", "bedroom", wardrobe, "hiding", eyes=(2890, -310))

    def bed(s):
        out = gb(3014, -330, 30, 300, 8, mul(t, 0.75))          # headboard
        out += gb(3300, -230, 24, 200, 8, mul(t, 0.75))         # footboard
        out += gb(3040, -200, 268, 44, 10, "#FFFFFF")            # mattress
        out += gp(PB().M(3120, -212).L(3300, -212).L(3304, -150).L(3116, -150).Q(3100, -180, 3120, -212).Z(), mix("#9FB8E8", t, 0.3))  # duvet
        if s == "rigged":
            # a (goat-shaped) lump under the duvet: Beryl tucked in
            out += gp(PB().M(3190, -212).Q(3230, -270, 3280, -214).Z(), mix("#9FB8E8", t, 0.2))
            out += gp(PB().M(3270, -236).L(3290, -254).L(3294, -232).Z(), "#F3EAD6")
        return out
    make(reg, "bedroom_bed", "bed", "bedroom", bed, "rig_point", tell=(3290, -290))

    def pillow(s):
        out = gp(PB().M(3050, -206).Q(3046, -246, 3090, -244).Q(3130, -246, 3126, -206).Q(3090, -198, 3050, -206).Z(), "#FFFFFF")
        if s == "rigged":
            out += [circle(3108, -236, 11, fill="#E8573F", sw=GW, stroke=INK)]
        return out
    make(reg, "bedroom_pillow", "pillow", "bedroom", pillow, "rig_point", tell=(3130, -266))

    def under(s):
        out = [shadow(3168, -6, 150, 6)] + gp(PB().M(3040, -156).L(3304, -156).L(3304, -34).L(3040, -34).Z(), mix("#9FB8E8", t, 0.45))
        out.append(gl(PB().M(3080, -156).L(3080, -40).M(3140, -156).L(3140, -40).M(3200, -156).L(3200, -40).M(3260, -156).L(3260, -40), 2.5))
        if s == "occupied":
            out.append(dark(PB().M(3130, -34).Q(3168, -110, 3210, -34).Z()))
            out += hush_eyes(3168, -66, 1, 0.8)
        return out
    make(reg, "bedroom_under_bed", "under_bed", "bedroom", under, "hiding", eyes=(3168, -66))

    def bedside(s):
        out = [shadow(3420, -6, 50, 5)] + gb(3378, -150, 84, 124, 6, mul(t, 0.85)) + gb(3370, -162, 100, 16, 6, mul(t, 0.8))
        out.append(gl(PB().M(3378, -96).L(3462, -96)))
        # lamp + his specs folded on the table
        out += gb(3440, -230, 10, 68, 3, pal.BRASS[1]) + gp(PB().M(3420, -230).L(3470, -230).L(3460, -266).L(3430, -266).Z(), "#FFE59A")
        specs = PB().circle(3396, -174, 9).circle(3418, -174, 9)
        lens = "#FFFFFF" if s == "idle" else "#FFE36B"
        out += [path(specs, fill=lens, fop=0.8), path(specs, fill="none", sw=3.5, stroke=INK)]
        return out
    make(reg, "bedroom_bedside", "bedside", "bedroom", bedside, "rig_point", tell=(3400, -206))


# ---------------------------------------------------------------------------------------- dressing room
def dressing(reg):
    t = tone("dressing")

    def trunk(s):
        out = [shadow(3800, -6, 70, 6)] + gb(3734, -150, 132, 126, 10, mix("#9A5B3A", t, 0.35))
        out += [gl(PB().M(3734, -110).L(3866, -110)), rect(3790, -124, 20, 22, 3, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False)]
        if s == "open":
            out += gp(PB().M(3734, -150).L(3866, -150).L(3876, -214).L(3744, -222).Z(), mix("#9A5B3A", t, 0.25))
            out += gp(PB().M(3752, -152).Q(3772, -200, 3806, -170).Q(3826, -200, 3850, -152).Z(), "#F59AC0")
        else:
            out += gp(PB().M(3730, -150).Q(3800, -190, 3870, -150).Z(), mix("#9A5B3A", t, 0.25))
        return out
    make(reg, "dressing_costume_trunk", "costume_trunk", "dressing", trunk, "container")

    def rail(s):
        out = [gl(PB().M(3916, -430).L(4046, -430), 8), gl(PB().M(3920, -430).L(3920, -24).M(4042, -430).L(4042, -24), 8)]
        cols = ["#E86A7A", "#F2D58A", "#8FC7E8", "#B89CE0"]
        for i, x in enumerate(range(3930, 4040, 28)):
            out += gp(PB().M(x, -420).L(x + 26, -420).L(x + 36, -110).L(x - 10, -110).Z(), mix(cols[i % 4], t, 0.3))
        if s == "occupied":
            out.append(dark(PB().M(3972, -110).L(3998, -110).L(3992, -300).L(3978, -300).Z()))
            out += hush_eyes(3985, -150, 1, 0.75)
        return out
    make(reg, "dressing_costume_rail", "costume_rail", "dressing", rail, "hiding", eyes=(3985, -150))

    def shelf(s):
        out = gb(4236, -420, 128, 14, 5, mul(t, 0.8))
        for i, (x, h) in enumerate([(4250, 70), (4290, 100), (4332, 60)]):
            out += gp(PB().M(x - 12, -420).L(x + 12, -420).L(x + 8, -420 - h * 0.3).Q(x + 20, -420 - h, x, -420 - h).Q(x - 20, -420 - h, x - 8, -420 - h * 0.3).Z(),
                      pal.GOLD)
        if s == "rigged":
            out.append(gl(PB().M(4240, -404).L(4250, -390).M(4360, -404).L(4352, -388), 4))
        return out
    make(reg, "dressing_trophy_shelf", "trophy_shelf", "dressing", shelf, "rig_point", tell=(4370, -540))

    def dummy(s):
        out = [gl(PB().M(4420, -150).L(4420, -30), 8), gl(PB().M(4390, -24).L(4450, -24), 8)]
        out += gp(PB().M(4380, -330).Q(4420, -350, 4460, -330).L(4470, -250).Q(4450, -200, 4460, -150).L(4380, -150).Q(4390, -200, 4370, -250).Z(), "#E9DCC6")
        out.append(circle(4420, -344, 14, fill="#E9DCC6", sw=GW, stroke=INK))
        if s == "rigged":
            out += gp(PB().M(4376, -180).Q(4420, -210, 4464, -180).L(4490, -150).Q(4420, -130, 4350, -150).Z(), "#F59AC0")
        else:
            out += gp(PB().M(4376, -310).L(4464, -310).L(4484, -160).L(4356, -160).Z(), mix("#7B6EA8", t, 0.3))
        return out
    make(reg, "dressing_dummy", "cloak_dummy", "dressing", dummy, "rig_point", tell=(4476, -330))


# ---------------------------------------------------------------------------------------- conservatory
def conservatory(reg):
    t = tone("conservatory")

    def bin_(s):
        out = [shadow(4022, -6, 60, 6)] + gb(3968, -150, 108, 126, 10, mix("#8FA0B8", t, 0.3)) + gb(3960, -168, 124, 22, 8, mix("#8FA0B8", t, 0.2))
        if s == "rigged":
            out += gp(PB().M(3980, -150).Q(3990, -120, 3984, -96).Q(3996, -110, 4004, -150).Z(), pal.HONEY[0])
        return out
    make(reg, "conservatory_feed_bin", "feed_bin", "conservatory", bin_, "rig_point", tell=(4090, -180))

    def hamper(s):
        out = [shadow(4193, -6, 70, 6)] + gb(4128, -170, 130, 146, 12, mix("#C9A06A", t, 0.3))
        out.append(gl(PB().M(4130, -130).L(4256, -130).M(4130, -90).L(4256, -90).M(4130, -50).L(4256, -50), 2.5))
        if s == "occupied":
            out.append(dark(PB().M(4140, -170).Q(4193, -200, 4246, -170).Z()))
            out += hush_eyes(4193, -184, -1, 0.8)
            out += gp(PB().M(4124, -184).L(4262, -196).L(4262, -178).L(4124, -168).Z(), mix("#C9A06A", t, 0.2))
        else:
            out += gb(4122, -182, 142, 18, 8, mix("#C9A06A", t, 0.2))
        return out
    make(reg, "conservatory_hamper", "hamper", "conservatory", hamper, "hiding", eyes=(4193, -184))

    def bench(s):
        out = [shadow(4620, -6, 72, 6)] + gb(4556, -170, 128, 16, 5, mix("#A9804C", t, 0.3))
        out.append(gl(PB().M(4566, -154).L(4566, -24).M(4674, -154).L(4674, -24).M(4566, -70).L(4674, -70), 7))
        out += gp(PB().M(4570, -170).L(4600, -170).L(4596, -214).L(4574, -214).Z(), "#C86A4A")
        out += [circle(4585, -226, 14, fill="#6BBF59", sw=GW, stroke=INK)]
        if s == "open":
            out += [circle(4636, -186, 14, fill="#E8573F", sw=GW, stroke=INK)]
            out += gp(PB().M(4650, -174).L(4690, -236).L(4700, -230).L(4660, -170).Z(), "#E9DCC6")
        else:
            out += gb(4616, -196, 56, 26, 6, mix("#C9A06A", t, 0.3))
        return out
    make(reg, "conservatory_potting_bench", "potting_bench", "conservatory", bench, "container")


# ---------------------------------------------------------------------------------------- garden
def garden(reg):
    t = tone("garden")

    def hose(s):
        out = [shadow(4820, -6, 60, 6)] + gb(4806, -250, 26, 226, 5, mix("#A9804C", t, 0.3))
        out += [circle(4820, -130, 34, fill="none", sw=12, stroke=INK), circle(4820, -130, 34, fill="none", sw=6, stroke="#5FAF62", sil=False)]
        out += gb(4812, -238, 16, 22, 4, pal.CHROME[0])
        if s == "rigged":
            out += [circle(4760, -20, 12, fill="#E8573F", sw=GW, stroke=INK)]
        return out
    make(reg, "garden_hose", "garden_hose", "garden", hose, "rig_point", tell=(4868, -270))

    def marrow(s):
        out = gb(5076, -70, 128, 50, 6, mix("#A9804C", t, 0.3))
        body = PB().M(5094, -86).Q(5100, -126, 5150, -124).Q(5196, -122, 5190, -88).Q(5150, -72, 5094, -86).Z()
        col = "#7FBF5A" if s == "idle" else "#6CCB5F"
        out += gp(body, col)
        out.append(gl(PB().M(5110, -104).Q(5150, -112, 5180, -100), 2.5))
        if s == "rigged":
            out.append(gl(PB().M(5190, -96).Q(5210, -104, 5206, -130), 2.5))
        return out
    make(reg, "garden_marrow", "marrow", "garden", marrow, "rig_point", tell=(5210, -150))

    for i, (cx, hy) in enumerate([(5308, -1), (5392, -1), (5476, -1)]):
        def coin(s, cx=cx):
            out = [ellipse(cx, -18, 26, 9, fill=mix(pal.STONE, "#FFFFFF", 0.3), sw=GW, stroke=INK, sop=0.85)]
            if s == "rigged":
                out += [ellipse(cx, -26, 14, 6, fill=pal.GOLD, sw=3, stroke=INK), ellipse(cx, -26, 7, 2.5, fill=pal.GOLD_LT, sil=False)]
            return out
        make(reg, "garden_coin_%d" % (i + 1), "coin_spot_%d" % (i + 1), "garden", coin, "rig_point", tell=(cx + 20, -56))

    def shed(s):
        out = [shadow(5701, -6, 80, 6)] + gb(5636, -330, 130, 306, 4, mix("#8FB070", t, 0.3))
        out += gp(PB().M(5624, -330).L(5701, -400).L(5778, -330).Z(), mix("#9A5B3A", t, 0.3))
        if s == "occupied":
            out.append(dark(PB().rrect(5660, -270, 70, 246, 4)))
            out += hush_eyes(5690, -200, 1, 0.85)
            out += gb(5710, -272, 26, 250, 3, mix("#8FB070", t, 0.2))
        else:
            out += gb(5660, -270, 70, 246, 4, mix("#8FB070", t, 0.2))
            out.append(circle(5716, -150, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK, sil=False))
        out += [circle(5701, -356, 12, fill="#FF7FB0", sw=3, stroke=INK)]      # Beryl's pink collar tag on the gable
        return out
    make(reg, "garden_shed", "shed", "garden", shed, "hiding", eyes=(5690, -200))

    def compost(s):
        out = [shadow(5876, -6, 70, 6)] + gb(5814, -230, 124, 206, 8, mix("#6E8A58", t, 0.3))
        out.append(gl(PB().M(5814, -170).L(5938, -170).M(5814, -110).L(5938, -110), 2.5))
        if s == "occupied":
            out.append(dark(PB().M(5830, -230).Q(5876, -262, 5922, -230).Z()))
            out += hush_eyes(5876, -244, -1, 0.8)
            out += gp(PB().M(5806, -244).L(5946, -262).L(5946, -244).L(5806, -230).Z(), mix("#6E8A58", t, 0.2))
        else:
            out += gb(5806, -244, 140, 18, 8, mix("#6E8A58", t, 0.2))
        return out
    make(reg, "garden_compost", "compost_bin", "garden", compost, "hiding", eyes=(5876, -244))

    def spot(s):
        # an old theatre spotlight on a tall stand (its pole runs down behind the compost bin)
        out = [path(PB().M(5875, -470).L(5875, -262), fill="none", sw=10, stroke=INK, sop=0.85),
               path(PB().M(5875, -470).L(5875, -262), fill="none", sw=5, stroke="#8A8EA8", sil=False)]
        ang = 0 if s == "idle" else 24
        head = PB().M(5830, -560).L(5900, -586).L(5916, -540).L(5846, -516).Z()
        out += gp(head, "#5A5E78")
        out += [ellipse(5910, -562, 10, 22, fill="#FFF3C0", sw=GW, stroke=INK)]
        out += gb(5860, -520, 30, 56, 4, "#5A5E78")
        return out
    make(reg, "garden_spotlight", "spotlight", "garden", spot, "rig_point", tell=(5940, -600))


def build(reg):
    landing(reg)
    bathroom(reg)
    bedroom(reg)
    dressing(reg)
    conservatory(reg)
    garden(reg)
