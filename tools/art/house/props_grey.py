"""props_grey - greybox hotspot props for the garden (the one room no slice shot shows up close): correct
silhouettes as flat pastel blocks with 4 px ink, so every hotspot already has idle / outline (+ occupied for
hiding spots - a dark gap, no baked eyes -, rigged for rig points, open for containers) at its final position.
Stage 3 replaces them with final art at the same paths and hit boxes. (The landing, bathroom, bedroom, dressing
room and conservatory props went final in Stage 2: props_edge.py.)
"""
import math

import pal
from draw import shadow, sparkle
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
    import props_edge
    if hid in props_edge.PROVIDES:
        return            # final art (s2-art) replaces this greybox block
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
    garden(reg)
