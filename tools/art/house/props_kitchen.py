"""Kitchen props (final): kettle, honey jar + pepper pot, pickle jar, fridge (top door = COLD OPEN
shelf, main door = container), table with the long cloth, pantry cupboard + curtain, sink + spray
tap, window (Hush's entry), back door, and decor (stool, pan rail).

All coordinates are world px (x absolute, y relative to the ground floor line); props sit on the
set furniture drawn by rooms_final.kitchen (worktops at y -200, tea shelf -356, pickle shelf -336).
Lines: interactables 5 px ink, details 3 px (STYLE §2).
"""
import math

import draw
import pal
from draw import ball, blob, box, flat, glove_fingers, hush_eyes, knob, oval, shadow, shape, sparkle
from props_base import Prop, emit, emit_decor
from svgk import INK, PB, circle, ellipse, group, lift, line, mix, mul, path, poly, polyline, rect

W = pal.LW_PROP      # 5
D = pal.LW_PROP_D    # 3


def ink(pb, sw=W, sil=True):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=sil)


def detail(pb, sw=D):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=False)


# =============================================================================== kettle
def kettle(reg):
    p = Prop("kettle", "kitchen")
    cx, base = 2940, -200
    cu = pal.COPPER
    body_pts = [(cx - 46, base - 4), (cx + 46, base - 4), (cx + 52, base - 30), (cx + 40, base - 56),
                (cx + 14, base - 68), (cx - 14, base - 68), (cx - 40, base - 56), (cx - 52, base - 30)]

    def body(lid=True):
        out = [shadow(cx, base - 1, 50, 5)]
        # handle (behind the lid, over the top)
        hp = PB().M(cx - 34, base - 58).C(cx - 34, base - 112, cx + 34, base - 112, cx + 34, base - 58)
        out += [path(hp, fill="none", sw=17, stroke=INK), path(hp, fill="none", sw=8, stroke="#4A3040", sil=False)]
        # spout
        sp = [(cx + 36, base - 22), (cx + 44, base - 46), (cx + 82, base - 78), (cx + 92, base - 70), (cx + 56, base - 14)]
        out += shape(sp, cu[1], W, smooth=False)
        out.append(path(PB().M(cx + 48, base - 40).L(cx + 80, base - 68), fill="none", sw=D, stroke=lift(cu[0], 0.3), sil=False))
        out += blob(body_pts, cu, W, k=0.8, hi=True, t=0.6)
        # base band
        out.append(rect(cx - 46, base - 14, 92, 10, 4, fill=cu[1], sil=False))
        out.append(detail(PB().M(cx - 46, base - 14).L(cx + 46, base - 14)))
        if lid:
            out += oval(cx, base - 68, 24, 7, pal.BRASS, D + 1, hi=False)
            out += ball(cx, base - 80, 8, pal.BRASS, D + 1, hi=False)
        return out

    p.add("idle", body())
    p.add("rigged", body())
    # the squeaker jammed in the spout tip (red rubber bulb + brass reed)
    p.add("rigged", rect(cx + 82, base - 82, 14, 10, 3, fill=pal.BRASS[0], sw=D, stroke=INK, sil=False))
    p.add("rigged", group(ball(cx + 100, base - 90, 18, pal.TOMATO, W, hi=True), rot=0))
    p.add("rigged", sparkle(cx + 70, base - 120, 12))
    emit(reg, "kitchen_kettle", p)


# =============================================================================== honey jar + pepper pot
def honey(reg):
    p = Prop("honey_jar", "kitchen")
    cx, base = 2928, -356
    hy = pal.HONEY

    def jar(cap=True, dipper_in=True):
        out = [shadow(cx + 10, base - 1, 52, 4)]
        pts = [(cx - 30, base), (cx + 30, base), (cx + 38, base - 26), (cx + 36, base - 58), (cx + 24, base - 70),
               (cx - 24, base - 70), (cx - 36, base - 58), (cx - 38, base - 26)]
        out += blob(pts, hy, W, k=0.8, t=0.6)
        # glass rim + honey level + glass shine
        out.append(rect(cx - 26, base - 80, 52, 14, 5, fill="#FFFFFF", sil=True))
        out.append(rect(cx - 26, base - 80, 52, 14, 5, fill="none", sw=D, stroke=INK))
        out.append(path(PB().M(cx - 26, base - 52).Q(cx - 28, base - 30, cx - 18, base - 14), fill="none", sw=6,
                        stroke="#FFFFFF", sop=0.7, sil=False))
        # honeycomb dots on the jar
        out.append(path(PB().circle(cx + 8, base - 32, 5).circle(cx + 18, base - 44, 4).circle(cx + 20, base - 24, 3.5),
                        fill=hy[2], sil=False))
        if dipper_in:
            out += dipper(cx + 6, base - 76, -12)
        if cap:
            # pink gingham cloth cap tied with string (hangs over the rim)
            cp = [(cx - 34, base - 66), (cx - 30, base - 88), (cx, base - 96), (cx + 30, base - 88), (cx + 34, base - 66),
                  (cx + 18, base - 72), (cx, base - 68), (cx - 18, base - 72)]
            out += shape(cp, pal.PINK[0], W, smooth=True, t=0.35)
            out.append(detail(PB().M(cx - 12, base - 92).L(cx - 16, base - 70).M(cx + 10, base - 94).L(cx + 14, base - 70), 2.5))
            out.append(detail(PB().M(cx - 32, base - 74).Q(cx, base - 64, cx + 32, base - 74), D))
        return out

    def pepper(x, y, ang=0.0, holes=True):
        items = []
        body = [(x - 13, y), (x + 13, y), (x + 15, y - 30), (x + 11, y - 44), (x - 11, y - 44), (x - 15, y - 30)]
        items += blob(body, ("#FFFFFF", pal.CHROME[0], "#FFFFFF"), W, k=0.84, t=0.5)
        items.append(rect(x - 12, y - 56, 24, 14, 6, fill=pal.PEPPER, sil=True))
        items.append(rect(x - 12, y - 56, 24, 14, 6, fill="none", sw=D, stroke=INK))
        if holes:
            items.append(path(PB().circle(x - 5, y - 50, 1.8).circle(x + 1, y - 51, 1.8).circle(x + 6, y - 49, 1.8), fill="#FFFFFF", sil=False))
        items.append(rect(x - 14, y - 30, 28, 6, 3, fill=pal.PINK[0], sil=False))
        return group(items, rot=ang, cx=x, cy=y) if ang else group(items)

    p.add("idle", jar(), pepper(cx + 56, base))
    # rigged (ACHOO-RIA!): the cloth cap flung off beside the jar, the pepper pot upside down and stuck in
    # the jar mouth, a black volcano of pepper heaped out of the honey with specks running down the glass and
    # a pepper-dust puff above it - the silhouette changes on both sides at phone scale (no text needed)
    p.add("rigged", jar(cap=False, dipper_in=False))
    heap = PB().M(cx - 30, base - 76).Q(cx - 22, base - 96, cx - 8, base - 104).Q(cx + 2, base - 112, cx + 12, base - 104)
    heap.Q(cx + 26, base - 96, cx + 32, base - 76).Q(cx, base - 70, cx - 30, base - 76).Z()
    p.add("rigged", path(heap, fill=pal.PEPPER, sil=True), path(heap, fill="none", sw=D, stroke=INK, sil=True))
    runs = PB()
    for (rx, ry, rl) in [(cx - 20, base - 72, 22), (cx + 4, base - 70, 34), (cx + 22, base - 72, 16)]:
        runs.M(rx - 4, ry).L(rx + 4, ry).L(rx + 3, ry + rl).Q(rx, ry + rl + 6, rx - 3, ry + rl).Z()
    p.add("rigged", path(runs, fill=pal.PEPPER, sil=False))
    specks = PB()
    for i, (sx, sy) in enumerate([(cx - 14, base - 40), (cx + 16, base - 30), (cx - 4, base - 22), (cx + 26, base - 52),
                                  (cx - 26, base - 56), (cx + 6, base - 48)]):
        specks.circle(sx, sy, 3.0 if i % 2 else 2.4)
    p.add("rigged", path(specks, fill=pal.PEPPER, sil=False))
    p.add("rigged", pepper(cx + 6, base - 126, ang=172))
    dust = PB().circle(cx - 34, base - 128, 11).circle(cx - 46, base - 146, 8).circle(cx + 38, base - 136, 9) \
        .circle(cx + 50, base - 154, 6.5).circle(cx - 26, base - 160, 6)
    p.add("rigged", path(dust, fill=pal.PEPPER, fop=0.35, sil=False))
    # the flung cap, lying crumpled where the pepper pot stood
    cap = [(cx + 36, base), (cx + 40, base - 16), (cx + 58, base - 26), (cx + 78, base - 20), (cx + 86, base),
           (cx + 70, base - 6), (cx + 52, base - 4)]
    p.add("rigged", shape(cap, pal.PINK[0], W, smooth=True, t=0.4))
    p.add("rigged", detail(PB().M(cx + 50, base - 20).L(cx + 54, base - 4).M(cx + 66, base - 22).L(cx + 70, base - 4), 2.5))
    p.add("rigged", sparkle(cx - 52, base - 96, 12, col=pal.HONEY[2]))
    emit(reg, "kitchen_honey", p)


def dipper(x, y, ang):
    """Honey dipper: stick + grooved head; (x, y) = where it enters the jar; ang = tilt from vertical."""
    wood = (pal.LIGHTWOOD[0], pal.HONEY[1], pal.LIGHTWOOD[0])
    it = []
    stick = PB().M(x, y + 10).L(x, y - 44)
    it.append(path(stick, fill="none", sw=11, stroke=INK))
    it.append(path(stick, fill="none", sw=5, stroke=wood[0], sil=False))
    it += oval(x, y - 50, 9, 7, wood, D + 1, hi=False)
    return [group(it, rot=ang, cx=x, cy=y)]


# =============================================================================== pickle jar
def pickle_jar(reg):
    p = Prop("pickle_jar", "kitchen")
    cx, base = 3112, -336
    brine = pal.GREEN_GLASS
    onion = ("#F7F0DC", "#DCCFA8", "#FFFFFF")

    def jar(lid="on"):
        out = [shadow(cx, base - 1, 46, 4)]
        out.append(rect(cx - 40, base - 108, 80, 108, 22, fill=brine[1]))
        out.append(rect(cx - 40, base - 108, 70, 100, 22, fill=brine[0], sil=False))
        # onions (a pile of pearl onions)
        pb = PB()
        for (ox, oy, r) in [(-20, -22, 13), (4, -18, 14), (24, -26, 11), (-10, -46, 13), (14, -50, 12), (-24, -66, 11),
                            (4, -74, 12), (24, -68, 10)]:
            pb.circle(cx + ox, base + oy, r)
        out.append(path(pb, fill=onion[0], sil=False))
        out.append(path(pb, fill="none", sw=2.5, stroke=mul(brine[1], 0.7), sil=False))
        tops = PB()
        for (ox, oy) in [(4, -32), (-10, -59), (14, -62), (4, -86)]:
            tops.M(cx + ox, base + oy).L(cx + ox + 2, base + oy - 5)
        out.append(detail(tops, 2.5))
        out.append(path(PB().M(cx - 30, base - 90).Q(cx - 34, base - 50, cx - 26, base - 18), fill="none", sw=7,
                        stroke="#FFFFFF", sop=0.6, sil=False))
        out.append(rect(cx - 40, base - 108, 80, 108, 22, fill="none", sw=W, stroke=INK))
        # label
        out += box(cx - 22, base - 64, 44, 26, 6, pal.CREAM, D, hi=False)
        out.append(path(PB().circle(cx - 6, base - 51, 5).circle(cx + 7, base - 51, 5), fill=onion[1], sil=False))
        if lid == "on":
            out += box(cx - 34, base - 124, 68, 20, 6, pal.BRASS, W, hi=True)
            out.append(detail(PB().M(cx - 24, base - 124).L(cx - 24, base - 104).M(cx - 8, base - 124).L(cx - 8, base - 104)
                              .M(cx + 8, base - 124).L(cx + 8, base - 104).M(cx + 24, base - 124).L(cx + 24, base - 104), 2.5))
        return out

    p.add("idle", jar())
    # rigged: lid cranked (squashed + twisted), a spanner hanging off it, twist arrows + a glint
    p.add("rigged", jar(lid="none"))
    lid = [(cx - 36, base - 104), (cx - 30, base - 126), (cx, base - 118), (cx + 30, base - 128), (cx + 36, base - 104)]
    p.add("rigged", shape(lid, pal.BRASS[1], W, smooth=False))
    p.add("rigged", detail(PB().M(cx - 26, base - 110).L(cx - 20, base - 122).M(cx - 6, base - 108).L(cx, base - 120)
                           .M(cx + 14, base - 108).L(cx + 20, base - 122), 2.5))
    sp = []
    handle = PB().M(cx + 30, base - 118).L(cx + 76, base - 150)
    sp.append(path(handle, fill="none", sw=17, stroke=INK))
    sp.append(path(handle, fill="none", sw=8, stroke=pal.CHROME[0], sil=False))
    sp.append(circle(cx + 80, base - 153, 12, fill=pal.CHROME[1], sw=W, stroke=INK))
    sp.append(circle(cx + 80, base - 153, 5, fill="#FFFFFF", sil=False))
    p.add("rigged", sp)
    tw = PB().M(cx - 48, base - 112).Q(cx - 60, base - 134, cx - 38, base - 146)
    p.add("rigged", detail(tw, D), poly([(cx - 44, base - 150), (cx - 30, base - 146), (cx - 42, base - 138)], fill=INK, sil=False))
    p.add("rigged", sparkle(cx - 6, base - 150, 11))
    # spent: lid off leaning on the jar, brine sloshed, only two onions left rolling on the shelf
    p.add("spent", jar(lid="none"))
    p.add("spent", group(box(cx + 30, base - 20, 60, 18, 6, pal.BRASS, W, hi=False), rot=-60, cx=cx + 40, cy=base - 4))
    p.add("spent", ball(cx - 56, base - 11, 11, onion, W - 1))
    emit(reg, "kitchen_pickle_jar", p)


# =============================================================================== fridge
FR_X0, FR_X1 = 3212, 3348
FR_TOP, FR_SEAM, FR_BOT = -478, -292, -26
ENAMEL = pal.ENAMEL_MINT


def fridge(reg):
    # ---- top door: the COLD OPEN shelf --------------------------------------------------
    t = Prop("fridge_shelf", "kitchen")
    x0, x1 = FR_X0, FR_X1
    w = x1 - x0

    def top(bulge=False):
        out = []
        pb = PB().M(x0, FR_SEAM).L(x0, FR_TOP + 40).C(x0, FR_TOP + 6, x0 + 20, FR_TOP, x0 + 50, FR_TOP)
        pb.L(x1 - 50, FR_TOP).C(x1 - 20, FR_TOP, x1, FR_TOP + 6, x1, FR_TOP + 40).L(x1, FR_SEAM).Z()
        out.append(path(pb, fill=ENAMEL[1]))
        out.append(path(PB().M(x0, FR_SEAM).L(x0, FR_TOP + 40).C(x0, FR_TOP + 6, x0 + 20, FR_TOP, x0 + 50, FR_TOP)
                        .L(x1 - 64, FR_TOP).C(x1 - 38, FR_TOP, x1 - 22, FR_TOP + 8, x1 - 22, FR_TOP + 40).L(x1 - 22, FR_SEAM - 8)
                        .L(x0, FR_SEAM - 8).Z(), fill=ENAMEL[0], sil=False))
        out.append(rect(x0 + 24, FR_TOP + 12, 46, 8, 4, fill="#FFFFFF", fop=0.6, sil=False))
        if bulge:
            bp = PB().M(x0 + 14, FR_SEAM - 16).C(x0 - 10, FR_SEAM - 80, x0 + 6, FR_TOP + 40, x0 + 40, FR_TOP + 26)
            bp.L(x1 - 40, FR_TOP + 26).C(x1 - 6, FR_TOP + 40, x1 + 12, FR_SEAM - 80, x1 - 14, FR_SEAM - 16).Z()
            out.append(path(bp, fill=ENAMEL[0], sil=False))
            out.append(detail(bp, D))
        # door seam lines + chrome handle
        out.append(detail(PB().M(x0 + 12, FR_TOP + 30).L(x0 + 12, FR_SEAM - 10).M(x0 + 12, FR_SEAM - 10).L(x1 - 12, FR_SEAM - 10), 2.5))
        out += box(x1 - 34, FR_TOP + 50, 16, 70, 8, pal.CHROME, W, hi=False)
        out.append(ink(pb))
        return out

    t.add("idle", top())
    t.add("rigged", top(bulge=True))
    # a sausage string escaping the top seam + a wobbling jelly peeking over the door, wobble lines
    saus = PB()
    pts = [(x0 + 14, FR_SEAM - 12), (x0 - 2, FR_SEAM - 26), (x0 - 10, FR_SEAM - 46), (x0 - 8, FR_SEAM - 68), (x0 + 4, FR_SEAM - 86)]
    for (sx, sy) in pts:
        saus.ellipse(sx, sy, 12, 9)
    t.add("rigged", path(saus, fill="#E0876A", sil=True), path(saus, fill="none", sw=D, stroke=INK, sil=True))
    jelly = [(x1 - 76, FR_TOP + 4), (x1 - 74, FR_TOP - 26), (x1 - 58, FR_TOP - 36), (x1 - 40, FR_TOP - 26), (x1 - 38, FR_TOP + 4)]
    t.add("rigged", shape(jelly, "#F07AA8", D + 1, smooth=True))
    t.add("rigged", draw.motion_lines([[(x1 + 6, FR_TOP + 70), (x1 + 16, FR_TOP + 64)], [(x1 + 8, FR_TOP + 96), (x1 + 18, FR_TOP + 96)]]))
    t.add("rigged", sparkle(x0 + 40, FR_TOP + 60, 12))
    emit(reg, "kitchen_fridge_shelf", t)

    # ---- main door: the container (kipper, butter) --------------------------------------
    f = Prop("fridge", "kitchen")

    def main(open_=False):
        out = [shadow((x0 + x1) / 2, -8, 84, 7)]
        # feet
        out += flat(x0 + 16, FR_BOT - 2, 22, 22, 5, pal.CHROME[1], D)
        out += flat(x1 - 38, FR_BOT - 2, 22, 22, 5, pal.CHROME[1], D)
        pb = PB().M(x0, FR_SEAM).L(x1, FR_SEAM).L(x1, FR_BOT - 30).C(x1, FR_BOT - 6, x1 - 16, FR_BOT, x1 - 40, FR_BOT)
        pb.L(x0 + 40, FR_BOT).C(x0 + 16, FR_BOT, x0, FR_BOT - 6, x0, FR_BOT - 30).Z()
        out.append(path(pb, fill=ENAMEL[1]))
        if not open_:
            out.append(path(PB().M(x0, FR_SEAM + 2).L(x1 - 22, FR_SEAM + 2).L(x1 - 22, FR_BOT - 30).C(x1 - 22, FR_BOT - 18, x1 - 34, FR_BOT - 14,
                            x1 - 48, FR_BOT - 14).L(x0 + 40, FR_BOT - 14).C(x0 + 16, FR_BOT - 14, x0, FR_BOT - 18, x0, FR_BOT - 30).Z(),
                            fill=ENAMEL[0], sil=False))
            out.append(detail(PB().M(x0 + 12, FR_SEAM + 10).L(x1 - 12, FR_SEAM + 10).L(x1 - 12, FR_BOT - 30).M(x0 + 12, FR_SEAM + 10)
                              .L(x0 + 12, FR_BOT - 30), 2.5))
            out += box(x1 - 34, FR_SEAM + 30, 16, 96, 8, pal.CHROME, W, hi=False)
            # round maker's badge + a fridge magnet (a little note)
            out += ball(x0 + 50, FR_BOT - 60, 16, pal.CHROME, D + 1)
            out.append(circle(x0 + 50, FR_BOT - 60, 7, fill=pal.TOMATO[0], sil=False))
            out.append(group([*box(x0 + 30, FR_SEAM + 40, 44, 34, 3, ("#FFFFFF", pal.CHROME[0], "#FFFFFF"), D, hi=False),
                              circle(x0 + 52, FR_SEAM + 40, 6, fill=pal.COBALT[0], sw=2.5, stroke=INK, sil=False)],
                             rot=-6, cx=x0 + 52, cy=FR_SEAM + 56, sil=False))
        out.append(ink(pb))
        return out

    f.add("idle", main())
    f.add("open", main(open_=True))
    f.add("open", open_interior(x0, x1, FR_SEAM, FR_BOT, top_part=False))
    f.add("open", door_leaf(x0, FR_SEAM + 6, FR_BOT - 8))
    emit(reg, "kitchen_fridge", f)


def open_interior(x0, x1, ya, yb, top_part):
    """The lit inside of an open fridge compartment (+ contents for the main one).
    Palette shared with the fridge body: ink, white, enamel x2, chrome x2, kipper x2, butter, cobalt."""
    out = []
    out.append(rect(x0 + 8, ya + 8, x1 - x0 - 16, yb - ya - 16, 12, fill=pal.CHROME[0]))
    out.append(rect(x0 + 8, ya + 8, x1 - x0 - 28, yb - ya - 24, 12, fill="#FFFFFF", sil=False))
    out.append(rect(x0 + 8, ya + 8, x1 - x0 - 16, yb - ya - 16, 12, fill="none", sw=D, stroke=INK, sil=False))
    if top_part:
        out.append(detail(PB().M(x0 + 14, (ya + yb) / 2 + 20).L(x1 - 14, (ya + yb) / 2 + 20), 3))
        return out
    # two wire shelves + a kipper + butter dish + milk bottle
    s1, s2 = ya + 88, ya + 176
    out.append(detail(PB().M(x0 + 12, s1).L(x1 - 12, s1).M(x0 + 12, s2).L(x1 - 12, s2), 3.5))
    kx, ky = (x0 + x1) / 2 - 8, s1 - 18
    out += kipper(kx, ky, 0.9)
    butter = "#FFE59A"
    out += [rect(x0 + 22, s2 - 26, 56, 22, 6, fill=butter), rect(x0 + 22, s2 - 26, 56, 22, 6, fill="none", sw=D, stroke=INK)]
    out += [rect(x0 + 16, s2 - 8, 68, 10, 4, fill="#FFFFFF"), rect(x0 + 16, s2 - 8, 68, 10, 4, fill="none", sw=D, stroke=INK)]
    out += box(x1 - 52, s2 - 58, 28, 56, 10, ("#FFFFFF", pal.CHROME[1], "#FFFFFF"), D, hi=False)
    out.append(rect(x1 - 50, s2 - 66, 24, 10, 4, fill=pal.COBALT[0], sw=2.5, stroke=INK, sil=False))
    out.append(circle(x1 - 30, ya + 22, 6, fill=butter, sw=2.5, stroke=INK, sil=False))
    return out


def door_leaf(hinge_x, ya, yb):
    """An open fridge door swung toward the viewer on the left hinge (inner face, door shelves)."""
    lw = 34
    pb = PB().M(hinge_x, ya).L(hinge_x - lw, ya + 16).L(hinge_x - lw, yb - 16).L(hinge_x, yb).Z()
    out = [path(pb, fill=ENAMEL[1])]
    out.append(path(PB().M(hinge_x - 8, ya + 10).L(hinge_x - lw + 6, ya + 22).L(hinge_x - lw + 6, yb - 22).L(hinge_x - 8, yb - 10).Z(),
                    fill=ENAMEL[0], sil=False))
    n_sh = max(1, int((yb - ya) / 90))
    for i in range(n_sh):
        yy = ya + (i + 1) * (yb - ya) / (n_sh + 1)
        out.append(detail(PB().M(hinge_x - 4, yy).L(hinge_x - lw + 4, yy + 8), 3))
    out.append(ink(pb))
    return out


def kipper(cx, cy, s=1.0, ang=0.0):
    """A smoked kipper (golden-brown fish), facing right."""
    k = ("#D9954E", "#B8733A", "#D9954E")
    out = []
    body = [(cx - 40 * s, cy), (cx - 20 * s, cy - 14 * s), (cx + 16 * s, cy - 14 * s), (cx + 40 * s, cy - 2 * s),
            (cx + 16 * s, cy + 12 * s), (cx - 20 * s, cy + 12 * s)]
    tail = [(cx - 38 * s, cy), (cx - 58 * s, cy - 16 * s), (cx - 54 * s, cy), (cx - 58 * s, cy + 16 * s)]
    out += shape(tail, k[1], D + 1)
    out += blob(body, k, D + 1, k=0.8, t=0.6)
    out.append(detail(PB().M(cx - 8 * s, cy - 11 * s).Q(cx - 14 * s, cy, cx - 8 * s, cy + 10 * s), 2.5))
    out.append(circle(cx + 26 * s, cy - 4 * s, 3.5 * s, fill=INK, sil=False))
    out.append(detail(PB().M(cx + 32 * s, cy + 3 * s).L(cx + 38 * s, cy + 2 * s), 2.0))
    return [group(out, rot=ang, cx=cx, cy=cy)] if ang else out


# =============================================================================== table (hiding)
def table(reg):
    p = Prop("kitchen_table", "kitchen")
    cx = 3450
    x0, x1 = cx - 96, cx + 96
    top_y = -178
    cloth = pal.COBALT
    white = "#FFFFFF"

    def base(peek=False):
        out = [shadow(cx, -6, 100, 8)]
        # cloth hanging nearly to the floor, scalloped hem
        hem = -16
        pb = PB().M(x0 - 6, top_y - 4).L(x1 + 6, top_y - 4).L(x1 + 12, hem - 8)
        n = 6
        for i in range(n):
            xa = x1 + 12 - (i + 0.5) * (x1 - x0 + 24) / n
            xb = x1 + 12 - (i + 1) * (x1 - x0 + 24) / n
            pb.Q(xa, hem + 8, xb, hem - 8)
        pb.Z()
        out.append(path(pb, fill=lift(cloth[0], 0.62)))
        # gingham: vertical + horizontal translucent bands
        g = PB()
        step = 28
        x = x0 + 4
        while x < x1:
            g.M(x, top_y).L(x + step / 2, top_y).L(x + step / 2 + (x - cx) * 0.03, hem - 6).L(x + (x - cx) * 0.03, hem - 6).Z()
            x += step
        y = top_y + 10
        while y < hem - 10:
            g.M(x0, y).L(x1, y).L(x1 + 4, y + step / 2).L(x0 - 4, y + step / 2).Z()
            y += step
        out.append(path(g, fill=cloth[0], fop=0.45, sil=False))
        # folds (shade) on the right side + fold lines
        out.append(path(PB().M(x1 - 30, top_y + 4).L(x1 + 6, top_y - 4).L(x1 + 12, hem - 8).Q(x1 - 8, hem + 8, x1 - 22, hem - 4).Z(),
                        fill=cloth[1], fop=0.5, sil=False))
        out.append(detail(PB().M(cx - 50, top_y + 16).Q(cx - 56, -90, cx - 52, hem).M(cx + 30, top_y + 16).Q(cx + 36, -90, cx + 32, hem), 2.5))
        if peek:
            # the cloth hem lifted in a wide arch: a dark gap under the table for Hush's animated eyes
            gp = PB().M(cx - 84, hem - 4).L(cx - 80, -74).Q(cx - 74, -106, cx - 40, -108).L(cx + 40, -108)
            gp.Q(cx + 74, -106, cx + 80, -74).L(cx + 84, hem - 4).Z()
            out.append(path(gp, fill=pal.DARK_GAP, sil=False))
            fold = PB().M(cx - 86, -70).Q(cx - 80, -112, cx - 40, -114).L(cx + 40, -114).Q(cx + 80, -112, cx + 86, -70)
            out.append(path(fold, fill="none", sw=D + 1, stroke=INK, sil=False))
        out.append(ink(pb))
        # table top edge (the cloth drapes over it)
        out.append(rect(x0 - 10, top_y - 10, x1 - x0 + 20, 12, 6, fill=lift(cloth[0], 0.7), sw=W, stroke=INK))
        # fruit bowl on the table
        out += fruit_bowl(cx, top_y - 10)
        return out

    p.add("idle", base())
    p.add("occupied", base(peek=True))
    p.extra["eyes"] = [cx, -58]
    emit(reg, "kitchen_table", p)


def fruit_bowl(cx, y):
    out = []
    out += ball(cx - 18, y - 22, 14, pal.TOMATO, D + 1)
    out += ball(cx + 14, y - 24, 14, pal.TOMATO, D + 1)
    out += ball(cx - 2, y - 36, 13, pal.GRASS, D + 1)
    bw = PB().M(cx - 40, y - 20).L(cx + 40, y - 20).Q(cx + 34, y + 2, cx, y + 2).Q(cx - 34, y + 2, cx - 40, y - 20).Z()
    out += [path(bw, fill=pal.CHROME[0]), path(PB().M(cx - 40, y - 20).L(cx + 26, y - 20).Q(cx + 20, y - 6, cx - 4, y - 4)
                                               .Q(cx - 30, y - 6, cx - 40, y - 20).Z(), fill="#FFFFFF", sil=False), ink(bw, D + 1)]
    out.append(detail(PB().M(cx - 30, y - 12).Q(cx, y - 6, cx + 30, y - 12), 2.5))
    return out


def teapot_small(cx, y):
    m = ("#F5A7C6", "#D884A6", "#FFD9E8")
    out = []
    out += shape([(cx + 22, y - 24), (cx + 44, y - 40), (cx + 48, y - 34), (cx + 26, y - 12)], m[1], D + 1)
    hp = PB().M(cx - 22, y - 34).C(cx - 42, y - 36, cx - 42, y - 12, cx - 22, y - 12)
    out += [path(hp, fill="none", sw=10, stroke=INK), path(hp, fill="none", sw=4, stroke=m[0], sil=False)]
    out += blob([(cx - 26, y), (cx + 26, y), (cx + 30, y - 22), (cx + 16, y - 40), (cx - 16, y - 40), (cx - 30, y - 22)], m, D + 1, k=0.8)
    out += oval(cx, y - 42, 14, 5, m, D, hi=False)
    out += ball(cx, y - 50, 5, m, D, hi=False)
    return out


# =============================================================================== pantry
PX0, PX1 = 3550, 3690


def pantry(reg):
    # ---- the cupboard above (container) --------------------------------------------------
    p = Prop("pantry_shelf", "kitchen")
    ya, yb = -566, -352
    wood = ("#F1E4C4", "#D9C69C", "#FFF6DE")

    def doors_closed():
        out = []
        out += box(PX0, ya, PX1 - PX0, yb - ya, 8, wood, W, hi=True)
        mid = (PX0 + PX1) / 2
        out.append(detail(PB().M(mid, ya + 6).L(mid, yb - 6), D))
        for dx in (PX0 + 12, mid + 8):
            out.append(rect(dx, ya + 16, (PX1 - PX0) / 2 - 20, yb - ya - 32, 6, fill="none", sw=2.5, stroke=INK, sil=False))
            # diamond vent
            vx, vy = dx + ((PX1 - PX0) / 2 - 20) / 2, ya + 50
            out.append(poly([(vx, vy - 12), (vx + 9, vy), (vx, vy + 12), (vx - 9, vy)], fill=wood[1], sw=2.5, stroke=INK, sil=False))
        for kx in (mid - 10, mid + 10):
            out.append(circle(kx, (ya + yb) / 2 + 16, 6, fill=pal.MUSTARD[0], sw=D, stroke=INK))
        return out

    def doors_open():
        out = []
        # interior shelves with the four pantry items (palette: ink, white, wood x2, interior, mustard, pink, green, cobalt)
        out += box(PX0, ya, PX1 - PX0, yb - ya, 8, (mul(wood[1], 0.82), mul(wood[1], 0.82), wood[2]), W, hi=False)
        s1 = ya + 104
        out.append(rect(PX0 + 6, s1, PX1 - PX0 - 12, 8, 3, fill=wood[0], sw=D, stroke=INK, sil=False))
        out.append(rect(PX0 + 6, yb - 14, PX1 - PX0 - 12, 8, 3, fill=wood[0], sw=D, stroke=INK, sil=False))
        out += flour_sack(PX0 + 36, s1, 0.8)
        out += sherbet_tube(PX0 + 96, s1, 0.8)
        out += treacle_tin(PX0 + 36, yb - 14, 0.75)
        out += salt_box(PX0 + 100, yb - 14, 0.75)
        # the two doors swung open toward the viewer (narrow skewed leaves)
        for sgn, hx in ((-1, PX0), (1, PX1)):
            lw = 22
            pb = PB().M(hx, ya + 4).L(hx + sgn * lw, ya + 16).L(hx + sgn * lw, yb - 16).L(hx, yb - 4).Z()
            out += [path(pb, fill=wood[1]), path(PB().M(hx + sgn * 6, ya + 14).L(hx + sgn * (lw - 6), ya + 24).L(hx + sgn * (lw - 6), yb - 24)
                                                     .L(hx + sgn * 6, yb - 14).Z(), fill=wood[0], sil=False), ink(pb)]
        return out

    p.add("idle", doors_closed())
    p.add("open", doors_open())
    emit(reg, "kitchen_pantry_shelf", p)

    # ---- the curtain below (hiding) ------------------------------------------------------
    c = Prop("pantry_curtain", "kitchen")
    ya2, yb2 = -336, -18
    fab = pal.MUSTARD

    def curtain(peek=False):
        out = []
        # rail
        out += box(PX0 - 8, ya2 - 4, PX1 - PX0 + 16, 12, 6, pal.BRASS, D + 1, hi=False)
        halves = []
        mid = (PX0 + PX1) / 2
        if peek:
            # both halves hauled apart at head height (a lens-shaped dark gap for Hush's animated eyes)
            ey = -214
            gap = PB().M(mid - 6, ya2 + 12).Q(mid - 34, ey - 76, mid - 58, ey).Q(mid - 54, ey + 90, mid - 30, yb2 - 4)
            gap.L(mid + 30, yb2 - 4).Q(mid + 54, ey + 90, mid + 58, ey).Q(mid + 34, ey - 76, mid + 6, ya2 + 12).Z()
            out.append(path(gap, fill=pal.DARK_GAP, sil=False))
            for side in (-1, 1):
                xo = PX0 + 4 if side < 0 else PX1 - 4
                pb = PB().M(xo, ya2 + 8).L(mid + side * 6, ya2 + 8).Q(mid + side * 34, ey - 76, mid + side * 58, ey)
                pb.Q(mid + side * 54, ey + 90, mid + side * 30, yb2 - 6)
                pb.Q(mid + side * 30 + (xo - mid - side * 30) * 0.5, yb2 + 6, xo + side * 3, yb2 - 6).Z()
                halves.append((pb, PX0 + 4 if side < 0 else mid + 62, mid - 62 if side < 0 else PX1 - 4))
        else:
            for side in (-1, 1):
                xa = PX0 + 4 if side < 0 else mid
                xb = mid if side < 0 else PX1 - 4
                pb = PB().M(xa, ya2 + 8).L(xb, ya2 + 8)
                # wavy hem
                pb.L(xb + side * 3, yb2 - 6)
                nn = 3
                for i in range(nn):
                    x_a = xb - (i + 0.5) * (xb - xa) / nn
                    x_b = xb - (i + 1) * (xb - xa) / nn
                    pb.Q(x_a, yb2 + 6, x_b, yb2 - 6)
                pb.Z()
                halves.append((pb, xa, xb))
        for pb, xa, xb in halves:
            out.append(path(pb, fill=fab[0]))
            # stripes (ticking) + folds
            st = PB()
            x = xa + 10
            while x < xb - 6:
                st.M(x, ya2 + 10).L(x + 2, yb2 - 8)
                x += 16
            out.append(path(st, fill="none", sw=3, stroke=fab[1], sil=False))
            out.append(ink(pb))
        # tie-back sash hint on the rail rings
        rings = PB()
        x = PX0 + 8
        while x < PX1:
            rings.circle(x, ya2 + 2, 5)
            x += 22
        out.append(path(rings, fill=pal.BRASS[1], sil=False))
        return out

    c.add("idle", curtain())
    c.add("occupied", curtain(peek=True))
    c.extra["eyes"] = [(PX0 + PX1) / 2, -214]
    c.extra["eyes_scale"] = 0.85
    emit(reg, "kitchen_pantry_curtain", c)


def flour_sack(cx, base, s=1.0):
    m = ("#FFFFFF", "#F1E4C4", "#FFFFFF")
    pts = [(cx - 26 * s, base), (cx + 26 * s, base), (cx + 30 * s, base - 40 * s), (cx + 20 * s, base - 70 * s),
           (cx + 8 * s, base - 76 * s), (cx - 8 * s, base - 76 * s), (cx - 20 * s, base - 70 * s), (cx - 30 * s, base - 40 * s)]
    out = blob(pts, m, D + 1, k=0.84)
    out.append(detail(PB().M(cx - 18 * s, base - 64 * s).Q(cx, base - 58 * s, cx + 18 * s, base - 64 * s), 2.5))
    # wheat ear symbol
    out.append(detail(PB().M(cx, base - 12 * s).L(cx, base - 44 * s), 3))
    for i in range(3):
        yy = base - (22 + i * 8) * s
        out.append(ellipse(cx - 6 * s, yy, 5 * s, 3 * s, fill=pal.MUSTARD[0], sil=False))
        out.append(ellipse(cx + 6 * s, yy, 5 * s, 3 * s, fill=pal.MUSTARD[0], sil=False))
    return out


def sherbet_tube(cx, base, s=1.0):
    out = box(cx - 16 * s, base - 80 * s, 32 * s, 80 * s, 8 * s, (pal.MUSTARD[0], pal.MUSTARD[0], pal.MUSTARD[0]), D + 1, hi=False)
    st = PB()
    for i in range(4):
        y = base - (14 + i * 18) * s
        st.M(cx - 15 * s, y).L(cx + 15 * s, y - 8 * s).L(cx + 15 * s, y - 2 * s).L(cx - 15 * s, y + 6 * s).Z()
    out.append(path(st, fill="#F46FA4", sil=False))
    out.append(path(PB().circle(cx - 6 * s, base - 92 * s, 3 * s).circle(cx + 4 * s, base - 98 * s, 2.5 * s).circle(cx + 8 * s, base - 88 * s, 2 * s),
                    fill="none", sw=2.0, stroke=INK, sil=False))
    return out


def treacle_tin(cx, base, s=1.0):
    g = ("#3E7A55", "#3E7A55", "#3E7A55")
    out = box(cx - 26 * s, base - 56 * s, 52 * s, 56 * s, 6 * s, g, D + 1, hi=True)
    out += box(cx - 28 * s, base - 64 * s, 56 * s, 12 * s, 5 * s, (pal.MUSTARD[0],) * 3, D, hi=False)
    drip = PB().M(cx - 14 * s, base - 52 * s).L(cx + 10 * s, base - 52 * s).L(cx + 8 * s, base - 30 * s).Q(cx + 2 * s, base - 22 * s, cx - 2 * s, base - 30 * s).L(cx - 4 * s, base - 40 * s).Q(cx - 10 * s, base - 34 * s, cx - 12 * s, base - 44 * s).Z()
    out += [path(drip, fill=pal.MUSTARD[0], sil=False), detail(drip, 2.5)]
    return out


def salt_box(cx, base, s=1.0):
    b = (pal.COBALT[0], pal.COBALT[0], pal.COBALT[0])
    out = box(cx - 20 * s, base - 64 * s, 40 * s, 64 * s, 6 * s, b, D + 1, hi=True)
    out.append(poly([(cx - 20 * s, base - 64 * s), (cx - 10 * s, base - 74 * s), (cx + 20 * s, base - 64 * s)], fill=b[1], sw=D, stroke=INK, sil=False))
    out.append(circle(cx, base - 32 * s, 9 * s, fill="#FFFFFF", sw=2.5, stroke=INK, sil=False))
    return out


# =============================================================================== sink + spray tap
SX0, SX1 = 3712, 3864


def sink(reg):
    p = Prop("sink_tap", "kitchen")
    cx = (SX0 + SX1) / 2
    top = -200

    def basin_and_tap(twisted=False, flop=False):
        out = []
        # Belfast basin sitting on the worktop (its front face is also the kitchen_sink_lip decor)
        out += basin(top)
        # tap column at the back
        tx = cx + 34
        col = PB().M(tx, top - 52).L(tx, top - 112).Q(tx, top - 140, tx - 28, top - 140).L(tx - 46, top - 140)
        out += [path(col, fill="none", sw=17, stroke=INK), path(col, fill="none", sw=8, stroke=pal.CHROME[0], sil=False)]
        # tap handles
        out += ball(tx - 18, top - 80, 9, pal.CHROME, D + 1, hi=False)
        out += ball(tx + 18, top - 80, 9, pal.CHROME, D + 1, hi=False)
        if flop:
            # hose unhooked and draped over the basin front, dripping
            hose = PB().M(tx - 46, top - 140).C(tx - 90, top - 130, tx - 70, top - 60, tx - 100, top - 20)
            out += [path(hose, fill="none", sw=15, stroke=INK), path(hose, fill="none", sw=7, stroke="#9AA6BC", sil=False)]
            out.append(group(box(tx - 112, top - 22, 26, 34, 8, pal.CHROME, D + 1, hi=False), rot=20, cx=tx - 100, cy=top - 6))
            out.append(ellipse(tx - 96, top + 18, 30, 6, fill=pal.GLASS[0], sw=2.5, stroke=INK, sil=False))
            out += drops([(tx - 104, top + 6), (tx - 92, top + 12)])
        elif twisted:
            # spray head twisted to point out at whoever leans in, trigger taped
            out.append(group(box(tx - 70, top - 150, 30, 26, 8, pal.CHROME, W, hi=False)
                             + [rect(tx - 64, top - 152, 12, 30, 2, fill="#E8E0B0", sw=2.5, stroke=INK, sil=False)],
                             rot=-30, cx=tx - 50, cy=top - 138))
            out += drops([(tx - 90, top - 150), (tx - 98, top - 128), (tx - 84, top - 112)])
        else:
            # spray head neatly in its cradle, pointing down into the sink
            out += box(tx - 60, top - 148, 22, 34, 8, pal.CHROME, W, hi=False)
        return out

    p.add("idle", basin_and_tap())
    p.add("rigged", basin_and_tap(twisted=True))
    p.add("rigged", sparkle(cx - 56, top - 176, 12))
    emit(reg, "kitchen_sink_tap", p)
    # the basin front drawn OVER the characters while he sits in the sink (ACHOO-RIA! / HOT & COLD / TAP DANCE):
    # the same porcelain box as the prop, pixel-for-pixel, so his backside disappears behind the rim
    lip = Prop("kitchen_sink_lip", "kitchen")
    lip.add("idle", basin(top))
    emit_decor(reg, "kitchen_sink_lip", lip, z=2, hidden=True, show="event")


def basin(top):
    """The Belfast basin on the sink worktop (x SX0+6 .. SX1-6, y top-50 .. top), shared by the prop and the lip."""
    out = box(SX0 + 6, top - 50, SX1 - SX0 - 12, 50, 10, pal.PORCELAIN, W, hi=True)
    out.append(detail(PB().M(SX0 + 20, top - 38).L(SX1 - 20, top - 38), 2.5))
    return out


def drops(pts):
    out = []
    for (x, y) in pts:
        pb = PB().M(x, y - 9).Q(x + 7, y + 1, x, y + 5).Q(x - 7, y + 1, x, y - 9).Z()
        out += [path(pb, fill=pal.GLASS[0], sil=False), path(pb, fill="none", sw=2.5, stroke=INK, sil=False)]
    return out


# =============================================================================== window (Hush's entry)
def window(reg):
    p = Prop("kitchen_window", "kitchen")
    x0, x1, ya, yb = 3724, 3852, -598, -366
    frame = ("#FFFFFF", "#D9DEE8", "#FFFFFF")
    sky = ("#B8E4F5", "#9FD6F0", "#E8F7FF")
    mid = (ya + yb) / 2

    def outside(y0, y1):
        o = [rect(x0 + 10, y0, x1 - x0 - 20, y1 - y0, 4, fill=sky[0], sil=False)]
        # garden hedge + a tree top seen through the glass
        o.append(path(PB().M(x0 + 10, y1).L(x0 + 10, y1 - 26).Q(x0 + 40, y1 - 50, x0 + 64, y1 - 30).Q(x0 + 92, y1 - 58, x1 - 10, y1 - 34)
                      .L(x1 - 10, y1).Z(), fill=pal.HEDGE, fop=0.7, sil=False))
        return o

    def win(open_=False):
        out = []
        out += box(x0, ya, x1 - x0, yb - ya, 6, frame, W, hi=False)
        if open_:
            # Hush's climb-in: the lower sash shoved right up behind the upper one, so the top quarter is a
            # double frame (two meeting rails, the lift handles hanging under it) and everything below is a
            # clean hole to the garden - no glass, no glints, a breeze curling in over the sill
            stack = ya + 62
            out += outside(ya + 12, yb - 12)
            out.append(path(PB().M(x0 + 18, ya + 18).L(x0 + 40, ya + 18).L(x0 + 28, stack - 12).L(x0 + 16, stack - 12).Z(),
                            fill="#FFFFFF", fop=0.55, sil=False))
            out.append(rect(x0 + 6, ya + 6, x1 - x0 - 12, stack - ya + 6, 4, fill="none", sw=D + 2, stroke=INK, sil=False))
            out.append(rect(x0 + 8, stack - 8, x1 - x0 - 16, 16, 4, fill=frame[1], sw=D, stroke=INK, sil=False))
            out.append(rect(x0 + 8, ya + 30, x1 - x0 - 16, 12, 3, fill=frame[1], sw=D, stroke=INK, sil=False))
            for hx in (x0 + 34, x1 - 34):
                out.append(path(PB().M(hx - 7, stack + 8).L(hx - 7, stack + 16).Q(hx, stack + 22, hx + 7, stack + 16).L(hx + 7, stack + 8),
                                fill="none", sw=D, stroke=INK, sil=False))
            breeze = PB().M(x0 + 22, yb - 40).Q(x0 + 52, yb - 60, x0 + 70, yb - 42).Q(x0 + 84, yb - 30, x0 + 72, yb - 24)
            breeze.M(x0 + 30, yb - 78).Q(x0 + 60, yb - 96, x0 + 82, yb - 80)
            out.append(path(breeze, fill="none", sw=D, stroke="#FFFFFF", sil=False))
        else:
            out += outside(ya + 12, yb - 12)
            out.append(path(PB().M(x0 + 20, ya + 20).L(x0 + 50, ya + 20).L(x0 + 30, mid - 10).L(x0 + 16, mid - 10).Z(), fill="#FFFFFF",
                            fop=0.55, sil=False))
            out.append(path(PB().M(x0 + 24, mid + 14).L(x0 + 44, mid + 14).L(x0 + 30, yb - 20).L(x0 + 20, yb - 20).Z(), fill="#FFFFFF",
                            fop=0.45, sil=False))
            out.append(rect(x0 + 6, mid - 7, x1 - x0 - 12, 14, 4, fill=frame[1], sw=D, stroke=INK, sil=False))
            out.append(detail(PB().M((x0 + x1) / 2, ya + 10).L((x0 + x1) / 2, yb - 10), D))
            out += knob((x0 + x1) / 2, mid, 5)
        out.append(rect(x0 + 10, ya + 10, x1 - x0 - 20, yb - ya - 20, 4, fill="none", sw=D, stroke=INK, sil=False))
        # sill with a potted herb
        out += box(x0 - 12, yb - 4, x1 - x0 + 24, 14, 5, frame, W, hi=False)
        out += herb_pot(x1 - 26, yb - 4)
        return out

    p.add("idle", win())
    p.add("open", win(open_=True))
    emit(reg, "kitchen_window", p, outline=False)


def herb_pot(cx, base):
    out = []
    leaves = PB()
    for (lx, ly, rx, ry) in [(-10, -30, 8, 12), (8, -34, 8, 13), (-2, -44, 7, 11), (12, -22, 7, 9), (-14, -18, 6, 8)]:
        leaves.ellipse(cx + lx, base + ly, rx, ry)
    out += [path(leaves, fill=pal.GRASS[0], sil=True), path(leaves, fill="none", sw=D, stroke=INK)]
    out += box(cx - 14, base - 22, 28, 22, 4, pal.TOMATO, D + 1, hi=False)
    return out


# =============================================================================== back door
def back_door(reg):
    p = Prop("back_door", "kitchen")
    hinge = 3920
    top = -474
    paint = ("#5FA37A", "#468460", "#A8D6B8")

    def closed():
        out = []
        # the leaf seen edge-on in the wall gap (with its knobs poking out both sides)
        out += box(3882, top + 4, 36, -top - 8, 5, paint, W, hi=False)
        out.append(detail(PB().M(3890, top + 20).L(3890, -20).M(3910, top + 20).L(3910, -20), 2.5))
        out += knob(3874, -226, 9)
        out += knob(3926, -226, 9)
        out += box(3894, top + 60, 12, 26, 3, pal.BRASS, D, hi=False)
        return out

    def opened():
        out = []
        # swung ~60 degrees into the conservatory (foreshortened leaf, hinged at x 3920)
        lw = 92
        top_far, bot_far = top + 26, -22
        pb = PB().M(hinge, top + 2).L(hinge + lw, top_far).L(hinge + lw, bot_far).L(hinge, -4).Z()
        out += [path(pb, fill=paint[1]), path(PB().M(hinge + 6, top + 10).L(hinge + lw - 18, top_far + 6).L(hinge + lw - 18, bot_far - 8)
                                                  .L(hinge + 6, -14).Z(), fill=paint[0], sil=False)]
        # two glass panes on top (skewed), a panel below
        for (ga, gb) in [(0.12, 0.46), (0.52, 0.86)]:
            xa, xb = hinge + lw * ga, hinge + lw * gb
            ya_, yb_ = top + 30 + (top_far - top) * ga, top + 30 + (top_far - top) * gb
            gp = PB().M(xa, ya_).L(xb, yb_).L(xb, yb_ + 150).L(xa, ya_ + 150).Z()
            out += [path(gp, fill=pal.GLASS[0], sil=False), path(gp, fill="none", sw=D, stroke=INK, sil=False)]
        out.append(detail(PB().M(hinge + 14, top + 240).L(hinge + lw - 14, top_far + 230).L(hinge + lw - 14, bot_far - 30).L(hinge + 14, -40).Z(), D))
        out += knob(hinge + lw - 14, -214, 9)
        out.append(ink(pb))
        return out

    p.add("idle", closed())
    p.add("open", opened())
    emit(reg, "kitchen_back_door", p)


# =============================================================================== decor
STOOL_X = 3000        # = st_tea stand_x: he sits on it facing -1 (house.json decor kitchen_stool, STYLE §8)
STOOL_SEAT_Y = -150   # top of the seat cushion (world y): the seat pivot the Bellows stool prop rides on


def stool(reg):
    """The tea stool under st_tea. ONE SVG shared with s2-anim-bellows' stool prop (same look), so its
    canvas carries two documented pivots: `seat` (top-centre of the cushion, where his backside sits) and
    `foot` (floor contact centre, for squash / hop-back). The view hides this decor while his own is out."""
    p = Prop("kitchen_stool", "kitchen")
    cx = STOOL_X
    wood = pal.LIGHTWOOD
    out = [shadow(cx, -4, 42, 5)]
    for (a, b) in [((cx - 22, STOOL_SEAT_Y + 16), (cx - 36, -4)), ((cx + 22, STOOL_SEAT_Y + 16), (cx + 36, -4)),
                   ((cx - 4, STOOL_SEAT_Y + 16), (cx - 8, -8))]:
        pb = PB().M(*a).L(*b)
        out += [path(pb, fill="none", sw=15, stroke=INK), path(pb, fill="none", sw=7, stroke=wood[0], sil=False)]
    rung = PB().M(cx - 29, -58).L(cx + 29, -58)
    out += [path(rung, fill="none", sw=11, stroke=INK), path(rung, fill="none", sw=4, stroke=wood[1], sil=False)]
    out += box(cx - 40, STOOL_SEAT_Y, 80, 20, 9, ("#E07F5C", "#C0633F", "#F6B8A0"), W, hi=True)
    p.add("idle", out)
    pos, size = emit_decor(reg, "kitchen_stool", p, z=0)
    d = reg.decor[-1]
    d["pivots"] = {"seat": [int(cx - pos[0]), int(STOOL_SEAT_Y - pos[1])], "foot": [int(cx - pos[0]), int(0 - pos[1])]}
    d["station"] = "st_tea"


def pan_rail(reg):
    p = Prop("pan_rail", "kitchen")
    x0, x1, y = 3044, 3192, -612
    cu = pal.COPPER
    out = []
    out += box(x0, y, x1 - x0, 10, 5, pal.BRASS, D + 1, hi=False)
    for (px, r, ang) in [(x0 + 30, 22, 6), (x0 + 78, 26, -4), (x0 + 124, 19, 8)]:
        hook = PB().M(px, y + 10).L(px, y + 22)
        items = [path(hook, fill="none", sw=D, stroke=INK, sil=False)]
        h = PB().M(px, y + 18).L(px, y + 44)
        items += [path(h, fill="none", sw=12, stroke=INK), path(h, fill="none", sw=5, stroke="#6B4A3A", sil=False)]
        items += ball(px, y + 44 + r, r, cu, W, hi=True)
        items.append(circle(px, y + 44 + r, r * 0.55, fill=cu[1], sil=False))
        out.append(group(items, rot=ang, cx=px, cy=y + 16))
    p.add("idle", out)
    emit_decor(reg, "kitchen_pans", p, z=0)


def build(reg):
    kettle(reg)
    honey(reg)
    pickle_jar(reg)
    fridge(reg)
    table(reg)
    pantry(reg)
    sink(reg)
    window(reg)
    back_door(reg)
    stool(reg)
    pan_rail(reg)
    reg.quake.setdefault("kitchen", []).append({"prop": "pans", "x": 3118, "decor": "kitchen_pans"})
