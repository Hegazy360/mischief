"""Hall props (final): front door, coat cupboard, the CONFISCATED box, candlestick phone (on the bg
phone table), piggy bank, cheval mirror (glass / no glass / frame-front overlay), grandfather clock
(face = rig point, case = hiding), stair rods, the newel post (stairs foot), decor (coat stand +
hats, umbrella stand).

World px, y relative to the ground floor line. Interactables 5 px ink, details 3 px.
"""
import math

import draw
import pal
from draw import ball, blob, box, flat, glove_fingers, hush_eyes, knob, oval, shadow, shape, sparkle
from props_base import Prop, emit, emit_decor
from props_kitchen import D, W, detail, ink, kipper
from svgk import INK, PB, circle, ellipse, group, lift, mix, mul, path, poly, polyline, rect

DOOR = ("#2E8272", "#23675A", "#7CC4B4")       # glossy front-door green
PHONE = ("#394063", "#262C47", "#7A83AD")


# =============================================================================== front door
def front_door(reg):
    p = Prop("front_door", "hall")
    top = -474
    x0, x1 = 482, 518

    def closed():
        out = []
        out += box(x0, top + 4, x1 - x0, -top - 8, 5, DOOR, W, hi=False)
        out.append(detail(PB().M(x0 + 9, top + 22).L(x0 + 9, -22).M(x1 - 9, top + 22).L(x1 - 9, -22), 2.5))
        # brass knocker ring (porch side) + letterbox rim + knob (hall side)
        out += box(x0 - 12, -348, 14, 26, 4, pal.BRASS, D, hi=False)
        out.append(ellipse(x0 - 16, -312, 10, 18, fill="none", sw=11, stroke=INK))
        out.append(ellipse(x0 - 16, -312, 10, 18, fill="none", sw=5, stroke=pal.BRASS[0], sil=False))
        out += box(x0 - 8, -250, 10, 34, 3, pal.BRASS, D, hi=False)
        out += knob(x1 + 8, -228, 9)
        return out

    def opened():
        out = []
        # swung ~60 degrees into the hall on its hinge at x 518: foreshortened inner face
        lw = 96
        tf, bf = top + 26, -22
        pb = PB().M(x1, top + 2).L(x1 + lw, tf).L(x1 + lw, bf).L(x1, -4).Z()
        out += [path(pb, fill=DOOR[1]),
                path(PB().M(x1 + 6, top + 10).L(x1 + lw - 16, tf + 6).L(x1 + lw - 16, bf - 8).L(x1 + 6, -14).Z(), fill=DOOR[0], sil=False)]
        # four panels in perspective
        for (ya, yb) in [(top + 40, top + 200), (top + 230, -40)]:
            for (ga, gb) in [(0.14, 0.46), (0.56, 0.86)]:
                xa, xb = x1 + lw * ga, x1 + lw * gb
                o_a, o_b = (tf - top) * ga, (tf - top) * gb
                q = PB().M(xa, ya + o_a).L(xb, ya + o_b).L(xb, yb - o_b * 0.6).L(xa, yb - o_a * 0.6).Z()
                out.append(detail(q, 2.5))
        out += knob(x1 + lw - 14, -222, 9)
        out.append(ink(pb))
        # the empty doorway now shows the porch light spilling in
        out.append(rect(x0 + 2, top + 8, x1 - x0 - 4, -top - 12, 3, fill="#FFF3C4", fop=0.55, sil=False))
        return out

    p.add("idle", closed())
    p.add("open", opened())
    emit(reg, "hall_front_door", p)


# =============================================================================== coat cupboard (hiding)
def coat_cupboard(reg):
    p = Prop("coat_cupboard", "hall")
    x0, x1, top, bot = 540, 676, -452, -24
    wood = pal.WALNUT

    def body(ajar=False):
        out = [shadow((x0 + x1) / 2, -8, 72, 6)]
        # cornice cap + plinth
        out += box(x0 - 8, top - 18, x1 - x0 + 16, 24, 6, wood, W, hi=True)
        out += box(x0 - 4, bot - 22, x1 - x0 + 8, 26, 5, wood, W, hi=False)
        out += box(x0, top + 4, x1 - x0, bot - top - 26, 6, wood, W, hi=False)
        dx0, dx1 = x0 + 14, x1 - 14
        if ajar:
            # the door swung open a crack on its right: dark gap with Hush peeking, gloves on the edge
            out.append(rect(dx0, top + 18, dx1 - dx0, bot - top - 54, 4, fill=pal.DARK_GAP, sil=False))
            out += hush_eyes(dx1 - 30, -300, look=1, s=0.95)
            pb = PB().M(dx0, top + 18).L(dx1 - 44, top + 8).L(dx1 - 44, bot - 26).L(dx0, bot - 36).Z()
            out += [path(pb, fill=wood[0], sil=False), detail(pb, D)]
            out.append(detail(PB().rrect(dx0 + 12, top + 40, dx1 - dx0 - 72, 150, 5).rrect(dx0 + 12, top + 214, dx1 - dx0 - 72, 150, 5), 2.5))
            out += knob(dx1 - 54, -236, 7)
            out += glove_fingers(dx1 - 42, -262, side=1, s=0.95, n=3)
        else:
            out.append(rect(dx0, top + 18, dx1 - dx0, bot - top - 54, 4, fill=wood[0], sil=False))
            out.append(detail(PB().rrect(dx0, top + 18, dx1 - dx0, bot - top - 54, 4), D))
            out.append(detail(PB().rrect(dx0 + 14, top + 40, dx1 - dx0 - 28, 150, 5).rrect(dx0 + 14, top + 214, dx1 - dx0 - 28, 150, 5), 2.5))
            out += knob(dx1 - 16, -236, 7)
            # a brass coat hook plate
            out += box((x0 + x1) / 2 - 16, top + 26, 32, 10, 3, pal.BRASS, D, hi=False)
        return out

    p.add("idle", body())
    p.add("occupied", body(ajar=True))
    # a hat and umbrella tip on top = "coats live here" (idle only - part of the object)
    hat = [(x0 + 30, top - 18), (x0 + 36, top - 44), (x0 + 60, top - 50), (x0 + 84, top - 44), (x0 + 90, top - 18)]
    for s in ("idle", "occupied"):
        p.add(s, shape(hat, "#6A7FA0", W, smooth=True), rect(x0 + 18, top - 24, 84, 8, 4, fill="#556A8C", sw=D, stroke=INK))
    p.extra["eyes"] = [x1 - 44, -300]
    emit(reg, "hall_coat_cupboard", p)


# =============================================================================== the CONFISCATED box
LETTERS = {
    "C": [[(10, 2), (6, 0), (3, 0), (0, 3), (0, 13), (3, 16), (6, 16), (10, 14)]],
    "O": [[(3, 0), (7, 0), (10, 3), (10, 13), (7, 16), (3, 16), (0, 13), (0, 3), (3, 0)]],
    "N": [[(0, 16), (0, 0), (10, 16), (10, 0)]],
    "F": [[(10, 0), (0, 0), (0, 16)], [(0, 8), (7, 8)]],
    "I": [[(5, 0), (5, 16)], [(2, 0), (8, 0)], [(2, 16), (8, 16)]],
    "S": [[(10, 2), (7, 0), (3, 0), (0, 3), (0, 6), (3, 8), (7, 8), (10, 10), (10, 13), (7, 16), (3, 16), (0, 14)]],
    "A": [[(0, 16), (5, 0), (10, 16)], [(2, 10), (8, 10)]],
    "T": [[(0, 0), (10, 0)], [(5, 0), (5, 16)]],
    "E": [[(10, 0), (0, 0), (0, 16), (10, 16)], [(0, 8), (7, 8)]],
    "D": [[(0, 0), (0, 16), (5, 16), (10, 12), (10, 4), (5, 0), (0, 0)]],
}


def word(text, x, y, s=1.0, adv=13.0):
    """Block letters as one stroked path (STYLE: letters as shapes, never <text>)."""
    pb = PB()
    for i, ch in enumerate(text):
        for stroke in LETTERS[ch]:
            pts = [(x + i * adv * s + px * s, y + py * s) for px, py in stroke]
            pb.M(*pts[0])
            for q in pts[1:]:
                pb.L(*q)
    return pb


def croc_head(x, y, flip=False):
    """The wind-up croc peeking out: a long snout with a zigzag grin and a bulgy eye (y = where it
    emerges)."""
    g = ("#6CC06A", "#4E9E52", "#B5E8B0")
    s = -1 if flip else 1
    snout = [(x, y), (x + s * 6, y - 30), (x + s * 20, y - 44), (x + s * 58, y - 50), (x + s * 62, y - 38), (x + s * 26, y - 22), (x + s * 20, y)]
    out = blob(snout, g, W, k=0.84, t=0.35)
    teeth = PB().M(x + s * 24, y - 30)
    for i in range(5):
        teeth.L(x + s * (28 + i * 6), y - 36 + (4 if i % 2 else 0))
    out.append(path(teeth, fill="none", sw=2.5, stroke="#FFFFFF", sil=False))
    out.append(path(PB().M(x + s * 22, y - 30).L(x + s * 60, y - 42), fill="none", sw=2.5, stroke=INK, sil=False))
    out.append(circle(x + s * 14, y - 44, 9, fill="#FFFFFF", sw=D, stroke=INK))
    out.append(circle(x + s * 16, y - 44, 4, fill=INK, sil=False))
    return out


def confiscated_box(reg):
    p = Prop("confiscated_box", "hall")
    x0, x1, top, bot = 706, 846, -150, -18
    cb = pal.CARDBOARD
    cx = (x0 + x1) / 2
    bal = ("#6CC06A", "#4E9E52", "#B5E8B0")

    def balloon(bx, by):
        out = [path(PB().M(cx + 24, top - 6).C(cx + 40, top - 50, bx - 26, by + 90, bx, by + 48), fill="none", sw=3, stroke=INK, sil=False)]
        out += blob([(bx, by + 42), (bx + 30, by + 10), (bx + 26, by - 26), (bx, by - 40), (bx - 26, by - 26), (bx - 30, by + 10)], bal, W,
                    k=0.82, hi=True)
        out.append(poly([(bx - 6, by + 48), (bx + 6, by + 48), (bx, by + 40)], fill=bal[1], sw=D, stroke=INK))
        return out

    def stamp():
        items = []
        items.append(rect(cx - 66, -104, 132, 32, 4, fill="none", sw=3.5, stroke=pal.STAMP_RED, sil=False))
        items.append(path(word("CONFISCATED", cx - 60, -96, 1.0, 11.2), fill="none", sw=3.2, stroke=pal.STAMP_RED, sil=False))
        return group(items, rot=-6, cx=cx, cy=-88, sil=False)

    def closed():
        out = [shadow(cx, -10, 76, 7)]
        # toys poking out between the flaps: the wind-up croc's toothy head and a magnifier handle
        out += croc_head(x0 + 30, top + 4, flip=True)
        out.append(group([rect(cx + 14, top - 54, 12, 50, 6, fill=pal.WALNUT[0], sw=W, stroke=INK)], rot=18, cx=cx + 20, cy=top))
        out += balloon(cx - 6, top - 150)
        out += box(x0, top, x1 - x0, bot - top, 6, cb, W, hi=True)
        # flaps folded in
        out += [path(PB().M(x0 + 4, top + 2).L(cx - 6, top - 14).L(cx + 6, top - 14).L(x1 - 4, top + 2).Z(), fill=cb[0]), ink(
            PB().M(x0 + 4, top + 2).L(cx - 6, top - 14).L(cx + 6, top - 14).L(x1 - 4, top + 2), W)]
        out.append(detail(PB().M(cx, top - 12).L(cx, top + 4), D))
        out.append(stamp())
        # tape strip
        out.append(rect(cx - 10, bot - 30, 20, 30, 2, fill="#FFFFFF", fop=0.45, sil=False))
        return out

    def opened():
        out = [shadow(cx, -10, 76, 7)]
        # flaps open outward
        out += shape([(x0 + 2, top), (x0 - 30, top - 34), (x0 - 20, top - 44), (x0 + 30, top - 4)], cb[1], W)
        out += shape([(x1 - 2, top), (x1 + 30, top - 34), (x1 + 20, top - 44), (x1 - 30, top - 4)], cb[1], W)
        # the toys: squeaker, magnifier, wind-up croc, and the balloon on its string
        out += [circle(x0 + 34, top - 14, 16, fill=pal.TOMATO[0], sw=W, stroke=INK), circle(x0 + 28, top - 20, 4, fill="#FFFFFF", fop=0.6, sil=False)]
        out.append(group([circle(cx + 18, top - 50, 18, fill=pal.GLASS[0], sw=W, stroke=INK), rect(cx + 10, top - 34, 14, 40, 6, fill=pal.WALNUT[0], sw=W, stroke=INK)],
                         rot=24, cx=cx + 18, cy=top - 20))
        croc = [(cx - 30, top + 2), (cx - 30, top - 26), (cx + 4, top - 30), (cx + 34, top - 20), (cx + 36, top + 2)]
        out += shape(croc, "#6CC06A", W, smooth=True)
        out.append(path(PB().M(cx - 6, top - 28).L(cx - 2, top - 20).L(cx + 4, top - 28).L(cx + 8, top - 20).L(cx + 14, top - 27), fill="none",
                        sw=D, stroke=INK, sil=False))
        out.append(circle(cx + 22, top - 22, 3.5, fill=INK, sil=False))
        out += balloon(cx - 6, top - 150)
        out += box(x0, top, x1 - x0, bot - top, 6, cb, W, hi=True)
        out.append(stamp())
        return out

    p.add("idle", closed())
    p.add("open", opened())
    emit(reg, "hall_confiscated_box", p)


# =============================================================================== phone (on the bg phone table)
PT = 944
TABLE_TOP = -210


def phone(reg):
    p = Prop("phone", "hall")
    cx = PT + 10

    def body(hook="ear"):
        out = [shadow(cx, TABLE_TOP - 1, 34, 4)]
        out += oval(cx, TABLE_TOP - 10, 32, 12, PHONE, W)
        out += box(cx - 8, TABLE_TOP - 96, 16, 86, 7, PHONE, W, hi=False)
        # mouthpiece horn on top, facing right
        horn = [(cx - 6, TABLE_TOP - 96), (cx + 26, TABLE_TOP - 124), (cx + 34, TABLE_TOP - 108), (cx + 8, TABLE_TOP - 88)]
        out += shape(horn, PHONE[0], W)
        out.append(ellipse(cx + 31, TABLE_TOP - 116, 7, 11, fill=PHONE[1], sw=D, stroke=INK, sil=False))
        # hook on the left of the stem
        hk = PB().M(cx - 8, TABLE_TOP - 78).L(cx - 30, TABLE_TOP - 84).L(cx - 34, TABLE_TOP - 94)
        out += [path(hk, fill="none", sw=11, stroke=INK), path(hk, fill="none", sw=5, stroke=pal.BRASS[0], sil=False)]
        cord = PB().M(cx - 4, TABLE_TOP - 14).C(cx - 30, TABLE_TOP + 2, cx - 50, TABLE_TOP - 10, cx - 44, TABLE_TOP - 40)
        if hook == "ear":
            out.append(path(cord, fill="none", sw=3, stroke=INK, sil=False))
            out += box(cx - 44, TABLE_TOP - 96, 18, 50, 8, PHONE, W, hi=False)
            out += oval(cx - 35, TABLE_TOP - 44, 12, 6, PHONE, D, hi=False)
        return out, cord

    idle, _ = body("ear")
    p.add("idle", idle)
    # rigged: a kipper hangs on the hook (by its tail); the earpiece lies on the table
    rg, cord = body("kipper")
    p.add("rigged", rg)
    p.add("rigged", group(kipper(cx - 38, TABLE_TOP - 48, 0.85), rot=-78, cx=cx - 38, cy=TABLE_TOP - 48))
    p.add("rigged", group(box(cx - 88, TABLE_TOP - 18, 50, 18, 8, PHONE, W, hi=False), sil=True))
    p.add("rigged", path(PB().M(cx - 4, TABLE_TOP - 14).Q(cx - 30, TABLE_TOP - 2, cx - 44, TABLE_TOP - 10), fill="none", sw=3, stroke=INK, sil=False))
    p.add("rigged", sparkle(cx - 60, TABLE_TOP - 108, 12))
    # spent: the kipper lies flopped on the table, the earpiece dangles over the edge
    sp, _ = body("none")
    p.add("spent", sp)
    p.add("spent", kipper(cx - 58, TABLE_TOP - 10, 0.8, ang=10))
    p.add("spent", path(PB().M(cx - 4, TABLE_TOP - 14).C(cx + 40, TABLE_TOP, cx + 50, TABLE_TOP + 20, cx + 48, TABLE_TOP + 40), fill="none", sw=3,
                        stroke=INK, sil=False))
    p.add("spent", group(box(cx + 40, TABLE_TOP + 40, 18, 46, 8, PHONE, W, hi=False), rot=-10, cx=cx + 48, cy=TABLE_TOP + 40))
    emit(reg, "hall_phone", p)


# =============================================================================== piggy bank (container)
def piggy_bank(reg):
    p = Prop("piggy_bank", "hall")
    cx, shelf = PT + 4, -80
    pk = pal.PINK

    def pig(open_=False):
        out = [shadow(cx, shelf - 1, 38, 4)]
        for lx in (cx - 22, cx + 16):
            out += box(lx, shelf - 18, 12, 18, 4, pk, D + 1, hi=False)
        out += shape([(cx - 18, shelf - 56), (cx - 26, shelf - 74), (cx - 8, shelf - 62)], pk[1], D + 1)
        out += blob([(cx - 38, shelf - 30), (cx - 30, shelf - 54), (cx, shelf - 62), (cx + 30, shelf - 54), (cx + 40, shelf - 32),
                     (cx + 26, shelf - 14), (cx - 24, shelf - 14)], pk, W, k=0.82, hi=True)
        # snout, eye, slot, curly tail
        out += box(cx + 34, shelf - 44, 16, 20, 7, pk, D + 1, hi=False)
        out.append(path(PB().circle(cx + 40, shelf - 34, 2).circle(cx + 45, shelf - 34, 2), fill=INK, sil=False))
        out.append(circle(cx + 20, shelf - 44, 3.5, fill=INK, sil=False))
        out.append(rect(cx - 10, shelf - 62, 22, 5, 2, fill=INK, sil=False))
        out.append(path(PB().M(cx - 38, shelf - 34).C(cx - 52, shelf - 40, cx - 46, shelf - 54, cx - 40, shelf - 46), fill="none", sw=D, stroke=INK,
                        sil=False))
        if open_:
            out.append(ellipse(cx - 2, shelf - 16, 8, 4, fill=pal.DARK_GAP, sil=False))
            out += box(cx - 44, shelf - 12, 16, 12, 4, ("#D7A26A", "#B98548", "#F2CFA0"), D, hi=False)
            for (ox, oy) in [(12, -6), (26, -4), (18, -14)]:
                out += oval(cx + ox, shelf + oy, 9, 4.5, pal.BRASS, 2.5, hi=False)
        return out

    p.add("idle", pig())
    p.add("open", pig(open_=True))
    emit(reg, "hall_piggy_bank", p)


# =============================================================================== cheval mirror
MX = 1112


def mirror(reg):
    p = Prop("cheval_mirror", "hall")
    wood = pal.WALNUT
    cy, rx, ry = -296, 50, 116
    glass = ("#D6EEF6", "#B6DCEA", "#FFFFFF")

    def stand():
        out = [shadow(MX, -8, 80, 6)]
        for sx in (-1, 1):
            px = MX + sx * (rx + 14)
            post = PB().M(px, -22).L(px, cy - 40)
            out += [path(post, fill="none", sw=17, stroke=INK), path(post, fill="none", sw=8, stroke=wood[0], sil=False)]
            foot = PB().M(px - 26, -12).Q(px, -30, px + 26, -12)
            out += [path(foot, fill="none", sw=15, stroke=INK), path(foot, fill="none", sw=7, stroke=wood[1], sil=False)]
            out += ball(px, cy - 46, 8, pal.BRASS, D + 1, hi=False)
            out += ball(px, cy, 7, pal.BRASS, D, hi=False)
        return out

    def ring(front=False):
        out = []
        out.append(ellipse(MX, cy, rx + 9, ry + 9, fill="none", sw=24, stroke=INK))
        out.append(ellipse(MX, cy, rx + 9, ry + 9, fill="none", sw=13, stroke=wood[0], sil=False))
        out.append(path(PB().M(MX + rx + 4, cy - 40).Q(MX + rx + 16, cy + 30, MX + 20, cy + ry + 12), fill="none", sw=5, stroke=wood[1], sil=False))
        # crest on top
        crest = [(MX - 22, cy - ry - 10), (MX, cy - ry - 36), (MX + 22, cy - ry - 10)]
        out += shape(crest, pal.BRASS[0], D + 1, smooth=True)
        return out

    def glass_in(crack=False):
        out = [ellipse(MX, cy, rx, ry, fill=glass[1], sil=True)]
        out.append(ellipse(MX - 6, cy - 8, rx - 8, ry - 12, fill=glass[0], sil=False))
        out.append(path(PB().M(MX - 30, cy - 60).L(MX - 12, cy - 86).L(MX - 2, cy - 76).L(MX - 22, cy - 44).Z(), fill="#FFFFFF", fop=0.7, sil=False))
        out.append(path(PB().M(MX - 30, cy - 20).L(MX - 22, cy - 32).L(MX - 16, cy - 26).L(MX - 26, cy - 10).Z(), fill="#FFFFFF", fop=0.6, sil=False))
        if crack:
            out.append(path(PB().M(MX + 10, cy - 100).L(MX + 2, cy - 60).L(MX + 18, cy - 30).L(MX + 4, cy + 10).L(MX + 20, cy + 50), fill="none",
                            sw=D, stroke=INK, sil=False))
            out.append(path(PB().M(MX + 18, cy - 30).L(MX + 36, cy - 40).M(MX + 4, cy + 10).L(MX - 16, cy + 20), fill="none", sw=2.5, stroke=INK,
                            sil=False))
        return out

    p.add("idle", stand(), glass_in(), ring())
    # rigged: the glass lifted out and leaning against the wall behind the right foot; the frame is empty
    p.add("rigged", stand())
    lean = group([ellipse(MX + 76, -86, 30, 70, fill=glass[1]), ellipse(MX + 72, -90, 24, 60, fill=glass[0], sil=False),
                  path(PB().M(MX + 60, -120).L(MX + 70, -134).L(MX + 76, -128).L(MX + 66, -110).Z(), fill="#FFFFFF", fop=0.7, sil=False),
                  ellipse(MX + 76, -86, 30, 70, fill="none", sw=W, stroke=INK)], rot=12, cx=MX + 76, cy=-20)
    p.add("rigged", lean, ring())
    p.add("rigged", sparkle(MX + 30, -176, 13))
    # front: the frame ring only, drawn OVER Hush while she stands in it (MIRROR, MIRROR)
    p.add("front", ring(front=True))
    p.extra["front_while"] = "hush_in_frame"
    emit(reg, "hall_mirror", p)


# =============================================================================== grandfather clock
CX = 1280
HOOD_TOP, HOOD_BOT = -560, -382
TRUNK_BOT = -24


def clock(reg):
    maho = pal.MAHOGANY
    # ---- face (hood) -----------------------------------------------------------------
    p = Prop("clock_face", "hall")
    x0, x1 = CX - 62, CX + 62

    def hood(state="idle"):
        out = []
        # arched pediment with finials
        ped = PB().M(x0 - 6, HOOD_TOP + 34).Q(CX, HOOD_TOP - 26, x1 + 6, HOOD_TOP + 34).Z()
        out += [path(ped, fill=maho[1]), path(PB().M(x0 + 4, HOOD_TOP + 30).Q(CX - 10, HOOD_TOP - 12, x1 - 20, HOOD_TOP + 22).Z(), fill=maho[0],
                                              sil=False), ink(ped)]
        for fx in (x0 + 4, CX, x1 - 4):
            out += ball(fx, HOOD_TOP - (6 if fx == CX else -22), 8, pal.BRASS, D + 1, hi=False)
        out += box(x0, HOOD_TOP + 30, x1 - x0, HOOD_BOT - HOOD_TOP - 30, 6, maho, W, hi=True)
        dcy = HOOD_TOP + 106
        # dial
        out += ball(CX, dcy, 48, pal.BRASS, W, hi=False)
        out.append(circle(CX, dcy, 38, fill="#FFF6E2", sw=D, stroke=INK, sil=False))
        ticks = PB()
        for i in range(12):
            a = math.radians(i * 30)
            r0 = 30 if i % 3 else 26
            ticks.M(CX + r0 * math.sin(a), dcy - r0 * math.cos(a)).L(CX + 35 * math.sin(a), dcy - 35 * math.cos(a))
        out.append(detail(ticks, 2.5))
        if state == "spent":
            # hands spun into a spiral, dial door swung open, a spring sproinging out of the top
            out.append(path(PB().M(CX, dcy).C(CX + 18, dcy - 4, CX + 14, dcy + 18, CX - 2, dcy + 14).C(CX - 22, dcy + 8, CX - 16, dcy - 22, CX + 6,
                            dcy - 22).C(CX + 28, dcy - 20, CX + 30, dcy + 8, CX + 22, dcy + 22), fill="none", sw=D, stroke=INK, sil=False))
            spr = PB().M(x1 - 20, HOOD_TOP + 30)
            for i in range(6):
                spr.Q(x1 + (14 if i % 2 else -6), HOOD_TOP + 20 - i * 12, x1 + 4, HOOD_TOP + 14 - i * 12)
            out.append(path(spr, fill="none", sw=D + 1, stroke=INK, sil=False))
        else:
            out.append(path(PB().M(CX, dcy).L(CX - 16, dcy - 18).M(CX, dcy).L(CX + 20, dcy - 10), fill="none", sw=4.5, stroke=INK, sil=False))
        out.append(circle(CX, dcy, 4, fill=INK, sil=False))
        if state == "rigged":
            # the over-wound key sticking out of the dial, glinting; blur arcs round the hands; a spring poking out
            key = group(box(CX + 16, dcy + 4, 30, 10, 4, pal.BRASS, D + 1, hi=False) + ball(CX + 52, dcy + 9, 12, pal.BRASS, W, hi=True)
                        + [circle(CX + 52, dcy + 9, 4, fill=pal.BRASS[1], sil=False)], rot=-20, cx=CX + 16, cy=dcy + 9)
            out.append(key)
            out.append(path(PB().M(CX - 26, dcy - 20).Q(CX - 32, dcy, CX - 22, dcy + 18), fill="none", sw=D, stroke=INK, sil=False))
            out.append(path(PB().M(CX + 24, dcy - 24).Q(CX + 10, dcy - 34, CX - 6, dcy - 32), fill="none", sw=D, stroke=INK, sil=False))
            spr = PB().M(x0, HOOD_TOP + 90)
            for i in range(5):
                spr.Q(x0 - 14 - i * 5, HOOD_TOP + 82 + i * 4 + (8 if i % 2 else -8), x0 - 10 - i * 6, HOOD_TOP + 100 + i * 4)
            out.append(path(spr, fill="none", sw=D + 1, stroke=INK, sil=False))
            out += sparkle(CX + 66, dcy - 30, 13)
        return out

    p.add("idle", hood("idle"))
    p.add("rigged", hood("rigged"))
    p.add("spent", hood("spent"))
    emit(reg, "hall_clock", p)

    # ---- case (trunk + base, hiding) -------------------------------------------------
    c = Prop("clock_case", "hall")
    tx0, tx1 = CX - 46, CX + 46

    def trunk(ajar=False):
        out = [shadow(CX, -8, 70, 6)]
        out += box(CX - 64, -112, 128, 88, 6, maho, W, hi=True)
        for fx in (CX - 50, CX + 50):
            out += ball(fx, -18, 12, maho, D + 1, hi=False)
        out += box(tx0, HOOD_BOT - 4, tx1 - tx0, -112 - HOOD_BOT + 8, 5, maho, W, hi=False)
        wy0, wy1 = HOOD_BOT + 30, -150
        if ajar:
            out.append(rect(tx0 + 12, wy0, tx1 - tx0 - 24, wy1 - wy0, 30, fill=pal.DARK_GAP, sil=False))
            out += hush_eyes(CX, -300, look=-1, s=0.9)
            door = PB().M(tx1 - 12, wy0).L(tx1 + 26, wy0 + 20).L(tx1 + 26, wy1 - 12).L(tx1 - 12, wy1).Z()
            out += [path(door, fill=maho[0], sil=False), detail(door, D)]
            out += glove_fingers(tx0 + 20, -250, side=-1, s=0.9, n=3)
        else:
            out.append(rect(tx0 + 12, wy0, tx1 - tx0 - 24, wy1 - wy0, 30, fill=pal.GLASS[1], sil=False))
            # pendulum
            out.append(detail(PB().M(CX, wy0 + 6).L(CX, wy1 - 60), 4))
            out += ball(CX, wy1 - 42, 18, pal.BRASS, D + 1, hi=True)
            out.append(path(PB().M(tx0 + 20, wy0 + 30).L(tx0 + 30, wy0 + 16).L(tx0 + 34, wy0 + 70).L(tx0 + 24, wy0 + 90).Z(), fill="#FFFFFF",
                            fop=0.5, sil=False))
            out.append(rect(tx0 + 12, wy0, tx1 - tx0 - 24, wy1 - wy0, 30, fill="none", sw=D, stroke=INK, sil=False))
            out += knob(tx1 - 16, (wy0 + wy1) / 2, 5)
        return out

    c.add("idle", trunk())
    c.add("occupied", trunk(ajar=True))
    c.extra["eyes"] = [CX, -300]
    emit(reg, "hall_clock_case", c)


# =============================================================================== stairs: rods + newel
def stair_steps():
    run = 400.0 / 14
    rise = 50.0
    return run, rise


def stair_rods(reg):
    p = Prop("stair_rods", "hall")
    run, rise = stair_steps()
    brass = pal.BRASS

    def rods(where="on"):
        out = []
        if where == "on":
            for i in range(1, 4):
                # rod at the back of tread i (where the runner tucks into the next riser)
                x = 1450 - run * i
                y = -rise * i
                out += box(x + 1, y - 3, run - 2, 8, 4, brass, D + 1, hi=False)
                out += ball(x + 2, y + 1, 5, brass, 2.5, hi=False)
            # a transparent hit silhouette of the three bottom steps (for the outline sprite)
            return out
        # pulled out: the rods lie in a little pile on the floor by the foot; the runner end curls up
        for j, (dx, ang) in enumerate([(0, -6), (10, 4), (-6, 12)]):
            out.append(group(box(1400 + dx, -16 - j * 9, 44, 8, 4, brass, D + 1, hi=False), rot=ang, cx=1420 + dx, cy=-12 - j * 9))
        curl = PB().M(1456, -2).C(1480, -4, 1486, -34, 1466, -36).C(1452, -36, 1452, -20, 1462, -18)
        out += [path(curl, fill="none", sw=13, stroke=INK), path(curl, fill="none", sw=7, stroke="#C06A6E", sil=False)]
        return out

    p.add("idle", rods("on"))
    p.add("rigged", rods("off"))
    p.add("rigged", sparkle(1404, -70, 12))
    emit(reg, "stairs_rods", p)


def newel(reg):
    p = Prop("stair_foot", "hall")
    wood = pal.WALNUT
    x = 1466
    out = [shadow(x, -6, 24, 4)]
    out += box(x - 16, -30, 32, 30, 4, wood, W, hi=False)
    out += box(x - 11, -236, 22, 210, 4, wood, W, hi=True)
    out.append(detail(PB().M(x - 11, -200).L(x + 11, -200).M(x - 11, -70).L(x + 11, -70), 2.5))
    out += box(x - 17, -254, 34, 20, 5, wood, W, hi=False)
    out += ball(x, -274, 17, pal.BRASS, W, hi=True)
    p.add("idle", out)
    emit(reg, "stairs_foot", p)


# =============================================================================== decor
def coat_stand(reg):
    """A slim Victorian hallstand: pole + hooks (hats are a separate quake sprite), a striped scarf,
    and an umbrella ring with a drip tray at the base (the coat stand AND the umbrella stand landing)."""
    p = Prop("coat_stand", "hall")
    x = 862
    wood = pal.WALNUT
    out = [shadow(x, -6, 44, 5)]
    # umbrellas leaning in the ring (behind the pole)
    u1 = PB().M(x - 10, -16).L(x - 22, -196)
    out += [path(u1, fill="none", sw=12, stroke=INK), path(u1, fill="none", sw=5, stroke="#4F78B8", sil=False)]
    hook = PB().M(x - 22, -196).Q(x - 26, -218, x - 40, -210)
    out += [path(hook, fill="none", sw=10, stroke=INK), path(hook, fill="none", sw=4, stroke=pal.WALNUT[0], sil=False)]
    u2 = PB().M(x + 10, -16).L(x + 22, -176)
    out += [path(u2, fill="none", sw=12, stroke=INK), path(u2, fill="none", sw=5, stroke="#D8664E", sil=False)]
    out += ball(x + 24, -186, 11, pal.MUSTARD, D + 1, hi=False)
    out.append(poly([(x + 34, -190), (x + 46, -186), (x + 34, -182)], fill=pal.TOMATO[0], sw=2.5, stroke=INK))
    for (fx, fy) in [(x - 38, -8), (x + 38, -8)]:
        leg = PB().M(x, -46).Q((x + fx) / 2, -18, fx, fy)
        out += [path(leg, fill="none", sw=14, stroke=INK), path(leg, fill="none", sw=6, stroke=wood[0], sil=False)]
    pole = PB().M(x, -30).L(x, -420)
    out += [path(pole, fill="none", sw=17, stroke=INK), path(pole, fill="none", sw=8, stroke=wood[0], sil=False)]
    # brass umbrella ring + drip tray
    out.append(ellipse(x, -120, 30, 9, fill="none", sw=11, stroke=INK))
    out.append(ellipse(x, -120, 30, 9, fill="none", sw=5, stroke=pal.BRASS[0], sil=False))
    out += oval(x, -14, 34, 8, pal.BRASS, D + 1, hi=False)
    for sgn in (-1, 1):
        hk = PB().M(x, -392).Q(x + sgn * 30, -392, x + sgn * 36, -414)
        out += [path(hk, fill="none", sw=11, stroke=INK), path(hk, fill="none", sw=4, stroke=wood[0], sil=False)]
    out += ball(x, -428, 10, wood, D + 1, hi=False)
    # a striped scarf over the left hook
    sc = PB().M(x - 30, -402).L(x - 18, -404).L(x - 22, -300).L(x - 36, -296).Z()
    out += [path(sc, fill="#E6B640"), path(PB().M(x - 34, -330).L(x - 21, -333).M(x - 34, -360).L(x - 20, -362), fill="none", sw=5, stroke="#2F9C95",
                                              sil=False), ink(sc, D + 1)]
    p.add("idle", out)
    emit_decor(reg, "hall_coat_stand", p, z=-1)

    # the hats (Meltdown quake prop): a bowler on the right hook, a boater on top
    h = Prop("hats", "hall")
    hat = []
    bowl = [(x + 12, -408), (x + 16, -436), (x + 34, -448), (x + 54, -440), (x + 60, -410)]
    hat += shape(bowl, "#4A4E68", W, smooth=True)
    hat.append(rect(x + 2, -414, 68, 10, 5, fill="#3A3E58", sw=D + 1, stroke=INK))
    hat += box(x - 34, -454, 56, 16, 5, ("#F2D58A", "#D8B865", "#FFF1C4"), W, hi=False)
    hat.append(rect(x - 44, -442, 76, 8, 4, fill="#E8C46F", sw=D + 1, stroke=INK))
    hat.append(rect(x - 34, -446, 56, 6, 2, fill=pal.TOMATO[0], sil=False))
    h.add("idle", hat)
    emit_decor(reg, "hall_hats", h, z=0)


def build(reg):
    front_door(reg)
    coat_cupboard(reg)
    confiscated_box(reg)
    phone(reg)
    piggy_bank(reg)
    mirror(reg)
    clock(reg)
    stair_rods(reg)
    newel(reg)
    coat_stand(reg)
    reg.quake.setdefault("hall", []).append({"prop": "hats", "x": 862, "decor": "hall_hats"})
