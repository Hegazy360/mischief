"""Parlour props (final): gramophone (+ speed lever / their-song record), baby grand piano (hiding
behind its fringed shawl) + brake wedge, wingback recliner (+ spring) + newspaper (+ magnifier),
fireplace bellows (+ flour), chandelier (+ loosened chain), chaise longue (hiding), tea tray
(+ salt) and Delphine's wall fan (+ feathers); decor: the Prologue vase (+ shards), Bellows'
portrait (+ floured), the falling picture frame, the log basket, the piano stool.

World px, y relative to the ground floor line. Interactables 5 px ink, details 3 px.
"""
import math

import draw
import pal
from draw import ball, blob, box, flat, glove_fingers, hush_eyes, knob, oval, shadow, shape, sparkle
from props_base import Prop, emit, emit_decor
from props_kitchen import D, W, detail, ink
from svgk import INK, PB, circle, ellipse, group, lift, mix, mul, path, poly, polyline, rect

PIANO = ("#34374F", "#24263A", "#6E7396")
VELVET_TEAL = ("#2F9C95", "#237A74", "#8FD6D0")
MUST = ("#E6B640", "#C99A2A", "#F8DD8C")


# =============================================================================== gramophone
def gramophone(reg):
    p = Prop("gramophone", "parlour")
    cx = 1640
    wood = pal.WALNUT
    top = -214

    def body(lever="slow", record="plain", arm="on"):
        """Palette (10): ink, white, walnut x2, brass x2, gold-light, chrome, tomato, record red."""
        chrome = pal.CHROME[0]
        out = [shadow(cx, -8, 66, 6)]
        # cabinet on little legs
        for lx in (cx - 50, cx + 38):
            out += box(lx, -40, 12, 30, 3, wood, D + 1, hi=False)
        out += box(cx - 60, top + 10, 120, -top - 50, 7, wood, W, hi=True)
        out.append(detail(PB().rrect(cx - 46, top + 30, 92, 110, 6), 2.5))
        out.append(path(PB().circle(cx, top + 85, 22), fill="none", sw=2.5, stroke=INK, sil=False))
        # turntable + record
        out += box(cx - 58, top - 4, 116, 16, 5, wood, W, hi=False)
        rec = INK if record in ("plain", "warped") else "#C8324A"
        if record == "warped":
            pb = PB().M(cx - 52, top - 6).Q(cx - 26, top - 20, cx, top - 8).Q(cx + 26, top + 2, cx + 52, top - 12).L(cx + 50, top - 2).Q(cx + 24, top + 10, cx, top)
            pb.Q(cx - 26, top - 10, cx - 50, top + 4).Z()
            out += [path(pb, fill=rec), ink(pb, D)]
        else:
            out.append(ellipse(cx, top - 6, 52, 7, fill=rec, sw=D + 1, stroke=INK))
            out.append(path(PB().M(cx - 40, top - 8).Q(cx - 20, top - 12, cx, top - 12), fill="none", sw=2.5, stroke="#FFFFFF", sop=0.35, sil=False))
            out.append(ellipse(cx, top - 6, 12, 3, fill=pal.GOLD_LT if record == "plain" else "#FFFFFF", sil=False))
            if record != "plain":
                # heart label on "their song"
                hx, hy = cx, top - 7
                out.append(path(PB().M(hx, hy + 3).C(hx - 8, hy - 2, hx - 4, hy - 7, hx, hy - 3).C(hx + 4, hy - 7, hx + 8, hy - 2, hx, hy + 3).Z(),
                                fill="#C8324A", sil=False))
        # horn: brass flower horn rising from the back and flaring to the right
        neck = PB().M(cx - 30, top - 10).C(cx - 44, top - 60, cx - 40, top - 120, cx - 14, top - 150)
        out += [path(neck, fill="none", sw=22, stroke=INK), path(neck, fill="none", sw=12, stroke=pal.BRASS[1], sil=False)]
        bell = [(cx - 22, top - 136), (cx - 6, top - 170), (cx + 34, top - 226), (cx + 70, top - 226), (cx + 84, top - 196),
                (cx + 66, top - 160), (cx + 20, top - 134), (cx - 4, top - 128)]
        out += blob(bell, pal.BRASS, W, k=0.8, t=0.4, hi=True)
        out.append(ellipse(cx + 66, top - 196, 16, 30, fill=pal.BRASS[1], sw=D, stroke=INK, sil=False))
        out.append(path(PB().M(cx + 10, top - 178).Q(cx + 30, top - 200, cx + 50, top - 210).M(cx + 6, top - 152).Q(cx + 34, top - 162, cx + 58, top - 172),
                        fill="none", sw=2.5, stroke=INK, sil=False))
        # tonearm
        if arm == "on":
            ta = PB().M(cx - 36, top - 20).L(cx + 10, top - 26).L(cx + 26, top - 14)
        else:
            ta = PB().M(cx - 36, top - 20).L(cx - 4, top - 44).L(cx + 20, top - 50)
        out += [path(ta, fill="none", sw=10, stroke=INK), path(ta, fill="none", sw=4, stroke=chrome, sil=False)]
        out.append(circle(cx - 36, top - 20, 7, fill=chrome, sw=D, stroke=INK))
        # speed dial + lever on the cabinet front (the ALLEGRO tell): red zone = x3
        dcx, dcy = cx + 40, top + 34
        out.append(path(PB().M(dcx - 22, dcy).Q(dcx, dcy - 26, dcx + 22, dcy), fill="none", sw=8, stroke=INK, sil=False))
        out.append(path(PB().M(dcx - 22, dcy).Q(dcx - 8, dcy - 18, dcx + 2, dcy - 13), fill="none", sw=4, stroke=chrome, sil=False))
        out.append(path(PB().M(dcx + 6, dcy - 12).Q(dcx + 16, dcy - 8, dcx + 22, dcy), fill="none", sw=4, stroke=pal.TOMATO[0], sil=False))
        ang = -58 if lever == "slow" else 62
        knob_col = pal.TOMATO[0] if lever != "slow" else chrome
        lv = group([rect(dcx - 5, dcy - 44, 10, 44, 5, fill=chrome, sw=D + 1, stroke=INK), circle(dcx, dcy - 50, 11, fill=knob_col, sw=W, stroke=INK),
                    circle(dcx - 3, dcy - 54, 3, fill="#FFFFFF", fop=0.7, sil=False)], rot=ang, cx=dcx, cy=dcy)
        out.append(lv)
        out.append(circle(dcx, dcy, 5, fill=pal.BRASS[0], sw=2.5, stroke=INK))
        return out

    p.add("idle", body())
    p.add("rigged", body(lever="fast"))
    p.add("rigged", sparkle(cx + 92, top + 2, 13))
    p.add("rigged", draw.motion_lines([[(cx + 84, top + 40), (cx + 98, top + 36)], [(cx + 82, top + 54), (cx + 96, top + 58)]]))
    p.add("rigged_it_takes_two", body(record="their_song"))
    p.add("rigged_it_takes_two", sparkle(cx - 60, top - 30, 12))
    emit(reg, "parlour_gramophone", p)


# =============================================================================== piano (hiding) + wedge
PX0, PX1 = 1712, 1962
BODY_TOP, BODY_BOT = -236, -150


def piano_body(peek=False):
    out = [shadow((PX0 + PX1) / 2, -8, 130, 7)]
    # legs with castors
    for lx in (PX0 + 30, PX1 - 34):
        leg = PB().M(lx, BODY_BOT).L(lx + 2, -30)
        out += [path(leg, fill="none", sw=22, stroke=INK), path(leg, fill="none", sw=12, stroke=PIANO[0], sil=False)]
        out += ball(lx + 2, -18, 10, pal.BRASS, D + 1, hi=False)
    # pedal lyre
    lyre = PB().M(PX1 - 80, BODY_BOT).L(PX1 - 80, -46)
    out += [path(lyre, fill="none", sw=12, stroke=INK), path(lyre, fill="none", sw=5, stroke=PIANO[0], sil=False)]
    out += box(PX1 - 94, -48, 28, 10, 3, pal.BRASS, D, hi=False)
    # raised lid (the "sail") with its prop stick
    stick = PB().M(PX0 + 70, BODY_TOP).L(PX0 + 96, BODY_TOP - 104)
    out += [path(stick, fill="none", sw=10, stroke=INK), path(stick, fill="none", sw=4, stroke=PIANO[2], sil=False)]
    lid = [(PX0 + 6, BODY_TOP - 6), (PX0 + 60, BODY_TOP - 136), (PX0 + 150, BODY_TOP - 150), (PX1 - 30, BODY_TOP - 40), (PX1 - 30, BODY_TOP - 6)]
    out += blob(lid, PIANO, W, k=0.86, smooth=False)
    out.append(path(PB().M(PX0 + 70, BODY_TOP - 120).L(PX0 + 146, BODY_TOP - 134).L(PX1 - 50, BODY_TOP - 42), fill="none", sw=4, stroke=PIANO[2],
                    sop=0.7, sil=False))
    # the body (curved tail on the left)
    bp = PB().M(PX0 + 10, BODY_BOT).C(PX0 - 4, BODY_BOT - 30, PX0 - 2, BODY_TOP + 8, PX0 + 30, BODY_TOP).L(PX1, BODY_TOP).L(PX1, BODY_BOT).Z()
    out += [path(bp, fill=PIANO[1]), path(PB().M(PX0 + 14, BODY_BOT - 12).C(PX0 + 6, BODY_BOT - 36, PX0 + 10, BODY_TOP + 12, PX0 + 36, BODY_TOP + 8)
                                         .L(PX1 - 16, BODY_TOP + 8).L(PX1 - 16, BODY_BOT - 12).Z(), fill=PIANO[0], sil=False)]
    out.append(rect(PX0 + 40, BODY_TOP + 12, 90, 7, 3, fill="#FFFFFF", fop=0.35, sil=False))
    # keyboard at the right end
    out += box(PX1 - 4, BODY_TOP + 12, 26, 26, 4, PIANO, D + 1, hi=False)
    out.append(rect(PX1 - 2, BODY_TOP + 16, 22, 8, 2, fill="#FFFFFF", sil=False))
    out.append(ink(bp))
    # the fringed shawl draped over the body (the hiding cover)
    sh = [(PX0 + 50, BODY_TOP + 2), (PX1 - 44, BODY_TOP + 2), (PX1 - 30, BODY_BOT + 44), (PX0 + 150, BODY_BOT + 34), (PX0 + 40, BODY_BOT + 50)]
    out += shape(sh, VELVET_TEAL[0], W, smooth=False)
    out.append(path(PB().M(PX0 + 60, BODY_TOP + 20).L(PX1 - 50, BODY_TOP + 20).M(PX0 + 90, BODY_TOP + 20).L(PX0 + 74, BODY_BOT + 40)
                    .M(PX1 - 90, BODY_TOP + 20).L(PX1 - 72, BODY_BOT + 38), fill="none", sw=2.5, stroke=VELVET_TEAL[1], sil=False))
    fr = PB()
    x = PX0 + 44
    while x < PX1 - 32:
        t = (x - PX0 - 40) / (PX1 - 30 - PX0 - 40)
        yb = BODY_BOT + 50 - 16 * t + (6 if 0.35 < t < 0.6 else 0)
        fr.M(x, yb - 4).L(x, yb + 12)
        x += 9
    out.append(path(fr, fill="none", sw=4, stroke=pal.GOLD, sil=False))
    if peek:
        # the shawl fringe lifted between the legs: a wide dark gap under the piano for Hush's animated eyes
        g = PB().M(PX0 + 50, -22).L(PX0 + 52, BODY_BOT + 66).Q(PX0 + 56, BODY_BOT + 44, PX0 + 90, BODY_BOT + 44)
        g.L(PX1 - 74, BODY_BOT + 42).Q(PX1 - 52, BODY_BOT + 44, PX1 - 50, BODY_BOT + 66).L(PX1 - 48, -22).Z()
        out.append(path(g, fill=pal.DARK_GAP, sil=False))
    return out


def piano(reg):
    p = Prop("piano", "parlour")
    p.add("idle", piano_body())
    p.add("occupied", piano_body(peek=True))
    p.extra["eyes"] = [(PX0 + PX1) / 2 - 4, -66]
    emit(reg, "parlour_piano_back", p)

    w = Prop("piano_wedge", "parlour")
    lx = PX1 - 32
    wood = pal.LIGHTWOOD

    def wedge(x, y, ang):
        items = shape([(x - 18, y), (x + 18, y), (x + 18, y - 22)], wood[0], W)
        items.append(detail(PB().M(x - 6, y - 4).L(x + 12, y - 16), 2.5))
        return group(items, rot=ang, cx=x, cy=y)

    w.add("idle", wedge(lx - 4, -4, 0))
    # rigged: the wedge kicked out, lying on its side on the floor, the castor free (wobble marks)
    w.add("rigged", wedge(lx + 50, -4, 180 - 12))
    w.add("rigged", draw.motion_lines([[(lx - 20, -16), (lx - 30, -10)], [(lx + 22, -16), (lx + 32, -10)]]))
    w.add("rigged", sparkle(lx + 50, -46, 12))
    emit(reg, "parlour_piano_wedge", w)



# =============================================================================== recliner + newspaper
RX = 2080


def recliner_body(state="idle"):
    out = [shadow(RX, -8, 80, 7)]
    fab = MUST
    # feet
    for fx in (RX - 58, RX + 50):
        out += box(fx, -30, 14, 24, 4, pal.WALNUT, D + 1, hi=False)
    # backrest with wings (left side: he sits facing right)
    back = [(RX - 72, -110), (RX - 92, -246), (RX - 84, -296), (RX - 50, -310), (RX - 12, -292), (RX - 6, -246), (RX - 26, -200), (RX - 20, -110)]
    out += blob(back, fab, W, k=0.86, t=0.4, hi=True)
    # the wing (a curved ear on the near side of the backrest)
    wing = [(RX - 40, -196), (RX - 30, -262), (RX - 8, -276), (RX + 8, -250), (RX - 2, -200), (RX - 16, -170)]
    out += blob(wing, fab, W, k=0.84, t=0.45)
    out.append(path(PB().circle(RX - 62, -262, 3.5).circle(RX - 60, -214, 3.5).circle(RX - 56, -164, 3.5), fill=fab[1], sil=False))
    # seat + base
    out += box(RX - 72, -120, 150, 92, 16, fab, W, hi=False)
    # arm on the near side (front)
    arm = [(RX - 40, -150), (RX + 70, -156), (RX + 84, -140), (RX + 80, -100), (RX - 36, -96)]
    out += blob(arm, fab, W, k=0.86, t=0.3)
    # lever on the right side
    lever_ang = 0 if state == "idle" else -38
    lv = group(box(RX + 70, -140, 8, 44, 4, pal.WALNUT, D + 1, hi=False) + ball(RX + 74, -144, 8, pal.WALNUT, D + 1, hi=False),
               rot=lever_ang, cx=RX + 74, cy=-100)
    if state == "spent":
        # cushion flipped off, springs sagging out of the seat
        spr = PB()
        for i, sx in enumerate((RX - 30, RX, RX + 30)):
            spr.M(sx - 10, -120)
            for j in range(4):
                spr.Q(sx + (12 if j % 2 else -12), -128 - j * 9, sx, -134 - j * 9)
        out.append(path(spr, fill="none", sw=D + 1, stroke=INK, sil=False))
        out.append(group(box(RX + 40, -40, 70, 26, 12, fab, W, hi=False), rot=24, cx=RX + 76, cy=-28))
    else:
        out += box(RX - 30, -150, 104, 30, 14, fab, W, hi=True)       # seat cushion
    out.append(lv)
    if state == "rigged":
        # a big coil spring poking up from under the lifted cushion + the cranked lever
        spr = PB().M(RX + 10, -150)
        for j in range(6):
            spr.Q(RX + (34 if j % 2 else -14), -160 - j * 12, RX + 12, -166 - j * 12)
        out.append(path(spr, fill="none", sw=9, stroke=INK))
        out.append(path(spr, fill="none", sw=4, stroke=pal.CHROME[0], sil=False))
        out += sparkle(RX + 44, -232, 13)
        out += draw.motion_lines([[(RX + 92, -168), (RX + 104, -176)], [(RX + 96, -150), (RX + 110, -150)]])
    return out


def recliner(reg):
    p = Prop("recliner", "parlour")
    p.add("idle", recliner_body("idle"))
    p.add("rigged", recliner_body("rigged"))
    emit(reg, "parlour_recliner", p)

    n = Prop("newspaper", "parlour")
    nx, ny = RX - 50, -312

    def paper(state="idle"):
        out = []
        if state == "spent":
            for sgn in (-1, 1):
                half = [(nx + sgn * 6, ny - 34), (nx + sgn * 50, ny - 44), (nx + sgn * 56, ny + 30), (nx + sgn * 10, ny + 38)]
                items = shape(half, "#F4F0E4", W) + [detail(PB().M(nx + sgn * 16, ny - 24).L(nx + sgn * 44, ny - 30).M(nx + sgn * 16, ny - 8)
                                                               .L(nx + sgn * 46, ny - 12), 2.5)]
                out.append(group(items, rot=sgn * 12, cx=nx, cy=ny + 30))
            return out
        # folded newspaper draped over the top of the wing
        pg = [(nx - 44, ny + 24), (nx - 40, ny - 30), (nx + 40, ny - 40), (nx + 50, ny + 14), (nx + 30, ny + 34), (nx - 26, ny + 40)]
        out += shape(pg, "#F4F0E4", W)
        out.append(path(PB().M(nx - 40, ny - 30).L(nx - 34, ny + 36), fill="none", sw=D, stroke=INK, sil=False))
        cols = PB()
        for i in range(4):
            yy = ny - 20 + i * 12
            cols.M(nx - 26, yy).L(nx + 6, yy - 3).M(nx + 12, yy - 4).L(nx + 38, yy - 7)
        out.append(detail(cols, 2.5))
        out += box(nx - 26, ny - 36, 36, 12, 2, ("#3A3050", "#2A2240", "#6A6080"), 2.5, hi=False)
        if state == "rigged":
            # the magnifying glass tucked in the fold, lens glinting
            mg = group(ball(nx + 38, ny - 36, 20, pal.GLASS, W, hi=True) + box(nx + 30, ny - 14, 12, 44, 6, pal.WALNUT, W, hi=False)
                       + [path(PB().M(nx + 28, ny - 46).Q(nx + 34, ny - 54, nx + 44, ny - 50), fill="none", sw=4, stroke="#FFFFFF", sil=False)],
                       rot=-24, cx=nx + 38, cy=ny - 20)
            out.append(mg)
            out += sparkle(nx + 70, ny - 60, 12)
        return out

    n.add("idle", paper("idle"))
    n.add("rigged", paper("rigged"))
    n.add("spent", paper("spent"))
    emit(reg, "parlour_newspaper", n)


# =============================================================================== bellows
def bellows(reg):
    p = Prop("bellows", "parlour")
    bx, by = 2230, -290      # hook point on the fireplace's left jamb (above the log basket: UP IN SMOKE)
    wood = pal.WALNUT
    leather = ("#C98A5E", "#A86C44", "#E8B890")

    def body(state="idle"):
        out = []
        out.append(detail(PB().M(bx, by - 8).L(bx, by + 6), 4))
        out += ball(bx, by - 10, 6, pal.BRASS, D, hi=False)
        flat_ = state == "spent"
        # handles loop at the top, paddles, pleated leather, brass nozzle pointing down
        hb = PB().M(bx - 20, by + 6).Q(bx, by - 14, bx + 20, by + 6)
        out += [path(hb, fill="none", sw=12, stroke=INK), path(hb, fill="none", sw=5, stroke=wood[0], sil=False)]
        w_ = 22 if flat_ else 40
        pad = [(bx - w_, by + 20), (bx + w_, by + 20), (bx + w_ * 0.9, by + 70), (bx + 12, by + 104), (bx - 12, by + 104), (bx - w_ * 0.9, by + 70)]
        out += blob(pad, wood, W, k=0.84, smooth=False)
        pl = PB()
        for i in range(3):
            yy = by + 34 + i * 18
            pl.M(bx - w_ + 8 + i * 3, yy).L(bx + w_ - 8 - i * 3, yy)
        out.append(path(pl, fill="none", sw=5, stroke=leather[0], sil=False))
        out.append(detail(pl, 2.0))
        out += box(bx - 7, by + 102, 14, 34, 5, pal.BRASS, W, hi=False)
        out += ball(bx, by + 60, 8, pal.BRASS, D, hi=False)
        if state == "rigged":
            # flour in the nozzle + a dusting on the paddle
            puff = PB().circle(bx - 4, by + 142, 12).circle(bx + 8, by + 148, 10).circle(bx - 10, by + 152, 8)
            out += [path(puff, fill=pal.FLOUR), path(puff, fill="none", sw=D, stroke=INK)]
            dust = PB().circle(bx - 22, by + 30, 5).circle(bx + 14, by + 26, 4).circle(bx + 28, by + 44, 3.5).circle(bx - 8, by + 86, 4)
            out.append(path(dust, fill="#FFFFFF", fop=0.9, sil=False))
            out += sparkle(bx + 40, by + 128, 12)
        if state == "spent":
            smear = PB().circle(bx - 10, by + 40, 8).circle(bx + 6, by + 60, 7)
            out.append(path(smear, fill="#FFFFFF", fop=0.8, sil=False))
        return out

    for s in ("idle", "rigged", "spent"):
        p.add(s, body(s))
    emit(reg, "parlour_bellows", p)


# =============================================================================== chandelier
def chandelier(reg):
    p = Prop("chandelier", "parlour")
    cx = 2330
    ceil = -628
    body_y = -530

    def fixture(tilt=0.0):
        items = []
        # central stem + bowl + 5 candle arms + crystal drops
        items += box(cx - 7, body_y - 34, 14, 40, 5, pal.BRASS, D + 1, hi=False)
        bowl = PB().M(cx - 40, body_y).Q(cx, body_y + 44, cx + 40, body_y).Z()
        items += [path(bowl, fill=pal.BRASS[1]), path(PB().M(cx - 36, body_y + 2).Q(cx - 6, body_y + 34, cx + 26, body_y + 6).Z(), fill=pal.BRASS[0],
                                                       sil=False), ink(bowl)]
        for i, ax in enumerate((-90, -50, 0, 50, 90)):
            arm = PB().M(cx, body_y + 4).Q(cx + ax * 0.6, body_y + 30, cx + ax, body_y - 6)
            items += [path(arm, fill="none", sw=11, stroke=INK), path(arm, fill="none", sw=5, stroke=pal.BRASS[0], sil=False)]
            items += box(cx + ax - 10, body_y - 14, 20, 10, 4, pal.BRASS, D, hi=False)
            items += box(cx + ax - 5, body_y - 44, 10, 30, 4, pal.PORCELAIN, D, hi=False)
            items.append(ellipse(cx + ax, body_y - 52, 5, 9, fill="#FFD05A", sw=2.5, stroke=INK))
            if i in (0, 2, 4):
                items.append(poly([(cx + ax * 0.55, body_y + 26), (cx + ax * 0.55 + 6, body_y + 36), (cx + ax * 0.55, body_y + 48),
                                   (cx + ax * 0.55 - 6, body_y + 36)], fill=pal.GLASS[0], sw=2.5, stroke=INK))
        items.append(poly([(cx, body_y + 30), (cx + 8, body_y + 44), (cx, body_y + 60), (cx - 8, body_y + 44)], fill=pal.GLASS[0], sw=D, stroke=INK))
        return group(items, rot=tilt, cx=cx, cy=body_y - 34)

    def chain(broken=False, n=6):
        out = []
        y = ceil
        for i in range(n):
            if broken and i == n - 2:
                # an opened link
                out.append(path(PB().M(cx - 5, y + 2).Q(cx - 12, y + 9, cx - 6, y + 15).M(cx + 6, y + 4).Q(cx + 12, y + 10, cx + 4, y + 16),
                                fill="none", sw=D + 1, stroke=INK))
            else:
                out.append(ellipse(cx, y + 8, 6 if i % 2 else 3.5, 8, fill="none", sw=D + 1, stroke=INK))
            y += 14
        return out

    p.add("idle", chain(), fixture())
    p.add("rigged", chain(broken=True), fixture(tilt=9))
    p.add("rigged", sparkle(cx + 36, ceil + 40, 12))
    p.add("rigged", draw.motion_lines([[(cx - 26, ceil + 50), (cx - 36, ceil + 44)], [(cx + 22, ceil + 64), (cx + 34, ceil + 60)]]))
    # spent: the chandelier is gone (it became his tutu); a stub of chain dangles from the rose
    p.add("spent", chain(broken=True, n=3))
    emit(reg, "parlour_chandelier", p)


# =============================================================================== chaise (hiding)
def chaise(reg):
    p = Prop("chaise", "parlour")
    x0, x1 = 2470, 2650
    fab = VELVET_TEAL
    wood = pal.WALNUT

    def body(peek=False):
        out = [shadow((x0 + x1) / 2, -8, 92, 7)]
        for fx in (x0 + 16, x1 - 26):
            out += box(fx, -32, 12, 26, 4, wood, D + 1, hi=False)
        if peek:
            # Hush crouched behind the low back: her shadow rises over it with the tip of her red beret; the view
            # draws her animated eyes (and the glove fingertips curled over the back) at `eyes`
            sh = PB().M(x0 + 36, -112).Q(x0 + 32, -196, x0 + 108, -198).Q(x0 + 184, -196, x0 + 180, -112).Z()
            out.append(path(sh, fill=pal.DARK_GAP, sil=False))
            bt = [(x0 + 104, -192), (x0 + 112, -210), (x0 + 138, -218), (x0 + 162, -208), (x0 + 166, -192)]
            out.append(group(shape(bt, pal.BERET, D, smooth=True, t=0.4)
                             + [circle(x0 + 138, -220, 4.5, fill=pal.BERET, sw=2.5, stroke=INK, sil=False)],
                             rot=14, cx=x0 + 136, cy=-196, sil=False))
        # scrolled high end on the left + a low back running right
        head = [(x0, -60), (x0 - 6, -200), (x0 + 20, -232), (x0 + 46, -214), (x0 + 38, -170), (x0 + 54, -120), (x1 - 40, -120), (x1 - 20, -140),
                (x1, -126), (x1, -60)]
        out += blob(head, fab, W, k=0.88, t=0.35, hi=True)
        out.append(path(PB().circle(x0 + 20, -206, 12), fill="none", sw=D, stroke=INK, sil=False))
        out += box(x0 + 30, -110, x1 - x0 - 30, 50, 12, fab, W, hi=True)
        tuft = PB()
        for tx in range(int(x0 + 70), int(x1 - 20), 36):
            tuft.circle(tx, -86, 3)
        out.append(path(tuft, fill=fab[1], sil=False))
        out += box(x0 - 4, -64, x1 - x0 + 8, 26, 8, wood, W, hi=False)
        return out

    p.add("idle", body())
    p.add("occupied", body(peek=True))
    p.extra["eyes"] = [x0 + 108, -150]
    emit(reg, "parlour_chaise_back", p)


# =============================================================================== tea tray + fan
TT = 2728


def tea_tray(reg):
    p = Prop("tea_tray", "parlour")
    top = -154
    silver = pal.CHROME
    china = ("#FFFFFF", "#DCE3EE", "#FFFFFF")

    def tray(state="idle"):
        out = []
        out += box(TT - 56, top - 10, 112, 10, 4, silver, D + 1, hi=False)
        # teapot (left), sugar bowl (middle), two cups (right)
        tp = TT - 30
        out += shape([(tp + 18, top - 30), (tp + 36, top - 46), (tp + 40, top - 40), (tp + 22, top - 18)], china[1], D + 1)
        hd = PB().M(tp - 18, top - 40).C(tp - 34, top - 40, tp - 34, top - 18, tp - 18, top - 18)
        out += [path(hd, fill="none", sw=9, stroke=INK), path(hd, fill="none", sw=3.5, stroke=china[0], sil=False)]
        out += blob([(tp - 22, top - 10), (tp + 22, top - 10), (tp + 24, top - 30), (tp + 12, top - 46), (tp - 12, top - 46), (tp - 24, top - 30)], china,
                    W, k=0.82)
        out.append(path(PB().M(tp - 16, top - 28).Q(tp, top - 20, tp + 16, top - 28), fill="none", sw=3, stroke=pal.COBALT[0], sil=False))
        out += ball(tp, top - 52, 6, china, D, hi=False)
        sb = TT + 10
        out += box(sb - 14, top - 32, 28, 22, 8, china, D + 1, hi=False)
        out.append(ellipse(sb, top - 33, 12, 4, fill="#FFFFFF", sw=2.5, stroke=INK, sil=False))
        if state == "rigged":
            # the salt cellar tipped against the sugar bowl, glittering grains heaped on top
            out.append(path(PB().M(sb - 12, top - 34).Q(sb, top - 48, sb + 12, top - 34).Z(), fill="#FFFFFF", sw=2.5, stroke=INK, sil=False))
            sc = group(box(sb + 18, top - 58, 18, 30, 5, ("#5E8FE0", "#4471C0", "#A9C7F5"), D + 1, hi=False)
                       + [rect(sb + 20, top - 64, 14, 8, 3, fill=silver[0], sw=2.5, stroke=INK)], rot=-50, cx=sb + 26, cy=top - 30)
            out.append(sc)
            gr = PB().circle(sb - 4, top - 52, 2).circle(sb + 6, top - 56, 2).circle(sb + 2, top - 62, 2)
            out.append(path(gr, fill="#FFFFFF", sw=1.5, stroke=INK, sil=False))
            out += sparkle(sb - 22, top - 66, 11)
        for i, cxp in enumerate((TT + 36, TT + 52)):
            if state == "spent" and i == 1:
                out.append(group(box(cxp - 8, top - 22, 18, 14, 5, china, D + 1, hi=False), rot=100, cx=cxp, cy=top - 12))
                out.append(ellipse(cxp + 8, top - 10, 12, 3, fill="#C99A6A", sil=False))
                continue
            out += box(cxp - 9, top - 22, 18, 12, 5, china, D + 1, hi=False)
        return out

    for s in ("idle", "rigged", "spent"):
        p.add(s, tray(s))
    emit(reg, "parlour_tea_tray", p)


def fan(reg):
    p = Prop("fan", "parlour")
    cx, cy = TT, -370           # pivot of the open fan (mounted on the wall on a little hook)
    lace = ("#FBE4EE", "#E8BCD0", "#FFFFFF")

    def fan_shape(state="idle"):
        out = []
        out.append(detail(PB().M(cx, cy - 104).L(cx, cy - 86), 3))
        out += ball(cx, cy - 106, 5, pal.BRASS, 2.5, hi=False)
        r = 64
        # ribs
        ribs = PB()
        for i in range(9):
            a = math.radians(-160 + i * 17.5)
            ribs.M(cx, cy).L(cx + r * math.cos(a), cy + r * math.sin(a))
        if state == "spent":
            out.append(path(ribs, fill="none", sw=6, stroke=INK))
            out.append(path(ribs, fill="none", sw=3, stroke=pal.WALNUT[0], sil=False))
            out += ball(cx, cy, 6, pal.BRASS, 2.5, hi=False)
            return out
        pb = PB().M(cx, cy)
        for i in range(9):
            a = math.radians(-160 + i * 17.5)
            pb.L(cx + r * math.cos(a), cy + r * math.sin(a))
        pb.Z()
        out += [path(pb, fill=lace[0])]
        scal = PB()
        for i in range(8):
            a0 = math.radians(-160 + i * 17.5)
            a1 = math.radians(-160 + (i + 1) * 17.5)
            am = (a0 + a1) / 2
            scal.M(cx + r * math.cos(a0), cy + r * math.sin(a0)).Q(cx + (r + 10) * math.cos(am), cy + (r + 10) * math.sin(am), cx + r * math.cos(a1),
                                                                     cy + r * math.sin(a1))
        out.append(path(scal, fill=lace[0], sw=D, stroke=INK))
        out.append(path(ribs, fill="none", sw=2.5, stroke=lace[1], sil=False))
        dots = PB()
        for i in range(8):
            a = math.radians(-151 + i * 17.5)
            dots.circle(cx + 44 * math.cos(a), cy + 44 * math.sin(a), 4)
        out.append(path(dots, fill=pal.PINK[0], sil=False))
        out.append(ink(pb))
        out += ball(cx, cy, 6, pal.BRASS, 2.5, hi=False)
        if state == "rigged":
            # feathers stuffed in between the ribs
            for i, ang in enumerate((-140, -110, -80, -50, -24)):
                a = math.radians(ang)
                fx, fy = cx + 70 * math.cos(a), cy + 70 * math.sin(a)
                fe = [(fx, fy), (fx + 18 * math.cos(a - 0.4), fy + 18 * math.sin(a - 0.4)), (fx + 34 * math.cos(a), fy + 34 * math.sin(a)),
                      (fx + 18 * math.cos(a + 0.4), fy + 18 * math.sin(a + 0.4))]
                out += shape(fe, "#FFFFFF", D, smooth=True)
            out += sparkle(cx + 70, cy - 16, 11)
        return out

    for s in ("idle", "rigged", "spent"):
        p.add(s, fan_shape(s))
    emit(reg, "parlour_fan", p)


# =============================================================================== decor
MANTEL = -300


VASE_X = 2226
MANTEL_L = 2186          # left end of the mantel shelf (rooms_final.fireplace: cx 2330 - 130 - 14)


def vase(reg):
    """The vase on the mantel (Prologue `laugh_vase`): the view slides it 10-14 px toward the mantel's left
    end on every warm-up note, tips it over the edge at `slide.edge_x` and swaps in `parlour_vase_smashed`."""
    p = Prop("vase", "parlour")
    vx = VASE_X
    blue = ("#6E9BE0", "#4E7AC0", "#B4CDF5")
    out = [shadow(vx, MANTEL - 1, 22, 3)]
    pts = [(vx - 12, MANTEL), (vx + 12, MANTEL), (vx + 22, MANTEL - 26), (vx + 16, MANTEL - 48), (vx + 10, MANTEL - 60), (vx + 14, MANTEL - 72),
           (vx - 14, MANTEL - 72), (vx - 10, MANTEL - 60), (vx - 16, MANTEL - 48), (vx - 22, MANTEL - 26)]
    out += blob(pts, blue, W, k=0.84, t=0.45, hi=True)
    out.append(path(PB().M(vx - 18, MANTEL - 30).Q(vx, MANTEL - 22, vx + 18, MANTEL - 30), fill="none", sw=3, stroke="#FFFFFF", sil=False))
    out += ball(vx - 4, MANTEL - 86, 9, pal.PINK, D, hi=False)
    out += ball(vx + 8, MANTEL - 80, 7, pal.MUSTARD, D, hi=False)
    out.append(detail(PB().M(vx - 4, MANTEL - 78).L(vx - 2, MANTEL - 70).M(vx + 6, MANTEL - 74).L(vx + 4, MANTEL - 70), 2.5))
    p.add("idle", out)
    pos, size = emit_decor(reg, "parlour_vase", p, z=0)
    d = reg.decor[-1]
    # `base` = bottom centre on the mantel (slide it along x, tip it around `tip_l` = its bottom-left corner)
    d["pivots"] = {"base": [int(vx - pos[0]), int(MANTEL - pos[1])], "tip_l": [int(vx - 12 - pos[0]), int(MANTEL - pos[1])]}
    d["slide"] = {"dir": -1, "step_px": [10, 14], "edge_x": MANTEL_L + 6, "floor_y": -8, "smashed": "parlour_vase_smashed"}
    # the smashed vase: shards on the hearth under the mantel's left end (shown when it lands)
    s = Prop("vase_smashed", "parlour")
    sx = MANTEL_L - 4
    sh = []
    for (ox, oy, ang) in [(-30, -8, 20), (-6, -6, -30), (18, -10, 60), (38, -6, -10)]:
        sh.append(group(shape([(sx + ox - 10, oy), (sx + ox + 10, oy), (sx + ox + 4, oy - 14)], blue[0], D + 1), rot=ang, cx=sx + ox, cy=oy))
    sh += ball(sx - 46, -12, 9, pal.PINK, D, hi=False)
    sh += ball(sx + 58, -10, 7, pal.MUSTARD, D, hi=False)
    s.add("idle", sh)
    emit_decor(reg, "parlour_vase_smashed", s, z=1, hidden=True, show="event")


def fire(reg):
    """The parlour fire: flames + logs in the firebox, 3 flicker frames played at 8 fps (decor `frames`)."""
    p = Prop("parlour_fire", "parlour")
    cx = 2330
    logs = PB().rrect(cx - 62, -52, 124, 20, 10).rrect(cx - 40, -66, 90, 18, 9)
    shapes = [
        # (outer tips [(x, y)...], inner tips)
        ([(-50, -44), (-26, -118), (-8, -80), (16, -150), (34, -96), (52, -126), (50, -44)],
         [(-30, -44), (-10, -92), (6, -66), (24, -110), (34, -44)]),
        ([(-50, -44), (-32, -106), (-10, -86), (8, -140), (30, -104), (48, -134), (50, -44)],
         [(-30, -44), (-16, -84), (2, -70), (18, -116), (34, -44)]),
        ([(-50, -44), (-22, -126), (-4, -90), (20, -142), (38, -92), (54, -118), (50, -44)],
         [(-30, -44), (-6, -100), (8, -72), (26, -102), (34, -44)]),
    ]
    for i, (outer, inner) in enumerate(shapes):
        st = "idle" if i == 0 else "f%d" % i
        o = [(cx + x, y) for x, y in outer]
        n = [(cx + x, y) for x, y in inner]
        items = [path(PB().smooth(o, True, 0.35), fill="#F7A23E"), path(PB().smooth(n, True, 0.35), fill="#FFE07A", sil=False),
                 path(logs, fill="#7A4E36"), path(logs, fill="none", sw=pal.LW_SET_D, stroke=pal.ARCH, sop=pal.ARCH_OP, sil=False)]
        # a couple of rising sparks, different per frame
        sp = PB()
        for (sx_, sy_) in [(-18 + i * 14, -150 - i * 6), (28 - i * 10, -168 + i * 8)]:
            sp.circle(cx + sx_, sy_, 3.2)
        items.append(path(sp, fill="#FFE07A", sil=False))
        p.add(st, items)
    _emit_frames(reg, "parlour_fire", p, 8.0, z=-1)


def candles(reg):
    """The two candle flames on the mantel's right end (3 frames at 6 fps; the sticks are in the room bg)."""
    p = Prop("parlour_candles", "parlour")
    x1 = 2330 + 130
    tips = [[(0, 0), (1, 0)], [(-2, 3), (2, -2)], [(2, -2), (-1, 2)]]
    for i, tp in enumerate(tips):
        st = "idle" if i == 0 else "f%d" % i
        items = []
        for j, (kx, h) in enumerate([(x1 - 34, 54), (x1 - 12, 44)]):
            top = MANTEL - 20 - h
            dx, dh = tp[j]
            fl = PB().M(kx - 5, top - 4).Q(kx - 6 + dx, top - 14 - dh, kx + dx, top - 24 - dh).Q(kx + 6 + dx, top - 14 - dh, kx + 5, top - 4).Q(kx, top + 1, kx - 5, top - 4).Z()
            items += [path(fl, fill="#FFD05A"), path(PB().ellipse(kx, top - 8, 2.2, 4.5), fill="#FFFFFF", sil=False)]
        p.add(st, items)
    _emit_frames(reg, "parlour_candles", p, 6.0, z=0)


def _emit_frames(reg, decor_id, prop, fps, z=0):
    """Emit a decor whose states idle/f1/f2... are animation frames: `art.idle` = frame 0, `frames` = all
    frames in order, `fps` (STYLE §8). All frames share the canvas top-left."""
    emit_decor(reg, decor_id, prop, z=z)
    d = reg.decor[-1]
    art = d["art"]
    keys = ["idle"] + sorted(k for k in art if k.startswith("f") and k[1:].isdigit())
    d["frames"] = [art[k] for k in keys]
    d["fps"] = fps
    d["art"] = {"idle": art["idle"]}


def portrait(reg):
    """Bellows' portrait over the mantel: the Great Baritone in his finest (floured by BELLOWS BLOWS)."""
    p = Prop("portrait", "parlour")
    cx, y0, y1 = 2330, -494, -318
    w = 150

    def pic(floured=False):
        f = lambda c: mix(c, "#FFFFFF", 0.78) if floured else c
        out = [rect(cx - w / 2 + 5, y0 + 6, w, y1 - y0, 6, fill=INK, fop=0.12, sil=False)]
        out += box(cx - w / 2, y0, w, y1 - y0, 6, pal.BRASS, W, hi=True)
        ix0, iy0, iw, ih = cx - w / 2 + 16, y0 + 16, w - 32, y1 - y0 - 32
        out.append(rect(ix0, iy0, iw, ih, 3, fill=f("#3C5A6E"), sil=False))
        # the sitter: plum coat, gold cravat, peach face, silver bouffant + mutton chops
        mcx = cx
        out.append(path(PB().M(ix0, iy0 + ih).L(ix0 + 8, iy0 + ih - 46).Q(mcx, iy0 + ih - 70, ix0 + iw - 8, iy0 + ih - 46).L(ix0 + iw, iy0 + ih).Z(),
                        fill=f("#7B3F8C"), sil=False))
        out.append(poly([(mcx - 12, iy0 + ih - 58), (mcx + 12, iy0 + ih - 58), (mcx, iy0 + ih - 30)], fill=f("#E8B33A"), sil=False))
        out.append(ellipse(mcx, iy0 + 62, 26, 30, fill=f("#F4C9A8"), sw=2.5, stroke=INK, sil=False))
        out.append(path(PB().M(mcx - 34, iy0 + 50).Q(mcx - 40, iy0 + 20, mcx - 18, iy0 + 12).Q(mcx, iy0 - 2, mcx + 18, iy0 + 12).Q(mcx + 40, iy0 + 20,
                        mcx + 34, iy0 + 50).Q(mcx + 16, iy0 + 30, mcx, iy0 + 34).Q(mcx - 16, iy0 + 30, mcx - 34, iy0 + 50).Z(), fill=f("#D9DCE6"),
                        sw=2.5, stroke=INK, sil=False))
        for sgn in (-1, 1):
            out.append(ellipse(mcx + sgn * 24, iy0 + 72, 8, 14, fill=f("#D9DCE6"), sw=2.0, stroke=INK, sil=False))
        out.append(path(PB().M(mcx - 12, iy0 + 56).L(mcx - 4, iy0 + 54).M(mcx + 4, iy0 + 54).L(mcx + 12, iy0 + 56), fill="none", sw=2.5, stroke=INK,
                        sil=False))
        out.append(ellipse(mcx, iy0 + 78, 7, 5, fill=f("#B8324B"), sw=2.0, stroke=INK, sil=False))
        # a little brass name plate
        out += box(cx - 26, y1 - 14, 52, 10, 3, pal.BRASS, 2.5, hi=False)
        if floured:
            dust = PB().circle(cx - 40, y0 + 30, 10).circle(cx + 36, y0 + 60, 12).circle(cx - 20, y1 - 30, 9).circle(cx + 10, y0 + 20, 7)
            out.append(path(dust, fill="#FFFFFF", fop=0.9, sil=False))
        return out

    p.add("idle", pic())
    p.add("floured", pic(True))
    emit_decor(reg, "parlour_portrait", p, z=0)


def picture_frame(reg):
    """The picture by the hall doorway: falls on his head in the Prologue (`laugh_picture`) and is a Meltdown
    prop. `falling` = the same frame with his head burst through the canvas (a real transparent hole), so the
    view can drop it on his head socket and hang it round his neck (pivot `hole`)."""
    p = Prop("picture_frame", "parlour")
    x0, y0, w, h = 1530, -598, 128, 104
    hx, hy = x0 + w / 2, y0 + h / 2 + 2

    def frame(torn=False):
        out = []
        if torn:
            # the snapped wire: two loose ends
            out.append(detail(PB().M(x0 + 20, y0).Q(x0 + 16, y0 - 16, x0 + 30, y0 - 22).M(x0 + w - 20, y0).Q(x0 + w - 12, y0 - 14, x0 + w - 26, y0 - 24), 2.5))
        else:
            out.append(detail(PB().M(x0 + 20, y0).L(hx, y0 - 26).L(x0 + w - 20, y0), 2.5))
            out += ball(hx, y0 - 28, 4, pal.BRASS, 2.0, hi=False)
        ring = PB().rrect(x0, y0, w, h, 6).rrect(x0 + 14, y0 + 14, w - 28, h - 28, 3)
        el = path(ring, fill=pal.WALNUT[0])
        el.attrs["fill-rule"] = "evenodd"
        out.append(el)
        sh = PB().M(x0 + w, y0 + 8).L(x0 + w, y0 + h - 6).Q(x0 + w, y0 + h, x0 + w - 6, y0 + h).L(x0 + 8, y0 + h).L(x0 + 14, y0 + h - 14)
        sh.L(x0 + w - 14, y0 + h - 14).L(x0 + w - 14, y0 + 14).Z()
        out.append(path(sh, fill=pal.WALNUT[1], sil=False))
        if torn:
            # canvas torn open: jagged paper flaps round a head-sized hole (transparent: his head shows through)
            ix0, iy0, ix1, iy1 = x0 + 14, y0 + 14, x0 + w - 14, y0 + h - 14
            jag = []
            n = 14
            for i in range(n):
                a = math.radians(360.0 * i / n)
                r = (0.62 if i % 2 else 0.8)
                jag.append((hx + math.cos(a) * (ix1 - ix0) * 0.5 * r, hy + math.sin(a) * (iy1 - iy0) * 0.5 * r))
            paper = PB().rrect(ix0, iy0, ix1 - ix0, iy1 - iy0, 3).poly(jag, True)
            pe = path(paper, fill="#FFF6E2", sil=False)
            pe.attrs["fill-rule"] = "evenodd"
            out.append(pe)
            out.append(path(PB().poly(jag, True), fill="none", sw=2.5, stroke=INK, sil=False))
            # a scrap of the sheet music still stuck on one flap
            out.append(path(PB().ellipse(ix0 + 12, iy1 - 12, 5, 3.6), fill=INK, sil=False))
        else:
            out.append(rect(x0 + 14, y0 + 14, w - 28, h - 28, 3, fill="#FFF6E2", sil=False))
            # a sheet-music motif (notes) - the house of a singer
            notes = PB()
            for (nx, ny) in [(x0 + 40, y0 + 64), (x0 + 62, y0 + 54), (x0 + 86, y0 + 60)]:
                notes.ellipse(nx, ny, 7, 5.2)
            out.append(path(notes, fill=INK, sil=False))
            out.append(detail(PB().M(x0 + 46, y0 + 64).L(x0 + 46, y0 + 38).L(x0 + 68, y0 + 32).L(x0 + 68, y0 + 54).M(x0 + 92, y0 + 60)
                              .L(x0 + 92, y0 + 36), 2.5))
            out.append(detail(PB().M(x0 + 26, y0 + 76).L(x0 + w - 26, y0 + 76), 1.5))
        out.append(path(PB().rrect(x0, y0, w, h, 6), fill="none", sw=W, stroke=INK))
        out.append(path(PB().rrect(x0 + 14, y0 + 14, w - 28, h - 28, 3), fill="none", sw=D, stroke=INK, sil=False))
        return out

    p.add("idle", frame())
    p.add("falling", frame(torn=True))
    pos, size = emit_decor(reg, "parlour_picture_frame", p, z=0)
    d = reg.decor[-1]
    d["pivots"] = {"hook": [int(hx - pos[0]), int(y0 - 28 - pos[1])], "hole": [int(hx - pos[0]), int(hy - pos[1])]}
    d["cue"] = "laugh_picture"


def log_basket(reg):
    p = Prop("log_basket", "parlour")
    cx = 2236
    wick = ("#C9A06A", "#A9804C", "#E8C894")
    out = [shadow(cx, -6, 46, 5)]
    for (lx, ly, ang) in [(-18, -70, -14), (6, -78, 8), (22, -66, 20)]:
        out.append(group(box(cx + lx - 10, ly - 30, 20, 52, 8, ("#8A5A3E", "#6E4530", "#B8845C"), D + 1, hi=False)
                         + [ellipse(cx + lx, ly - 30, 9, 5, fill="#E0B888", sw=2.0, stroke=INK)], rot=ang, cx=cx + lx, cy=ly))
    bp = PB().M(cx - 46, -64).L(cx + 46, -64).L(cx + 38, -8).L(cx - 38, -8).Z()
    out += [path(bp, fill=wick[0])]
    weave = PB()
    for i in range(4):
        yy = -54 + i * 12
        weave.M(cx - 44 + i * 2, yy).L(cx + 44 - i * 2, yy)
    for xx in range(-36, 40, 14):
        weave.M(cx + xx, -64).L(cx + xx * 0.84, -8)
    out.append(path(weave, fill="none", sw=2.5, stroke=wick[1], sil=False))
    out.append(ink(bp))
    hdl = PB().M(cx - 30, -64).Q(cx, -110, cx + 30, -64)
    out += [path(hdl, fill="none", sw=11, stroke=INK), path(hdl, fill="none", sw=5, stroke=wick[0], sil=False)]
    p.add("idle", out)
    emit_decor(reg, "parlour_log_basket", p, z=1)


def build(reg):
    gramophone(reg)
    piano(reg)
    recliner(reg)
    bellows(reg)
    chandelier(reg)
    chaise(reg)
    tea_tray(reg)
    fan(reg)
    vase(reg)
    portrait(reg)
    picture_frame(reg)
    log_basket(reg)
    fire(reg)
    candles(reg)
    reg.quake.setdefault("parlour", []).extend([
        {"prop": "picture_frame", "x": 1594, "decor": "parlour_picture_frame"},
        {"prop": "vase", "x": 2226, "decor": "parlour_vase"},
        {"prop": "portrait", "x": 2330, "decor": "parlour_portrait"},
    ])
