"""title - the Prologue's title card (GDD §2.3: "Only now the title card slams down: MISCHIEF NEXT DOOR") and its
bulb-chase overlays, for the curtain call (s2-night §4.3: 0.3 s drop with a squash on landing, the bulbs chase,
held 1.2 s).

A gilded marquee board flown in on two ropes: a deep-violet field, MISCHIEF / NEXT DOOR in cream-to-gold letters
converted to paths from the project's OFL Lilita One (lettering.py; no <text>), a crest with a star, a ring of
marquee bulbs round the frame, and Hush peeking over the top-right corner (beret, eyes, glove fingertips) - the
mime who just wrecked the evening, taking a sly look at the Stalls.

Files (screen space, gradients allowed - STYLE §1 stage):
  stage/title_card.svg          the board, every bulb drawn unlit-warm (reads on its own)
  stage/title_card_bulbs_a.svg  even bulbs lit (halo + hot core), same canvas -> drawn over the board
  stage/title_card_bulbs_b.svg  odd bulbs lit
house.json stage.title_card = {art, bulbs[a, b], size, pivot (squash, bottom centre of the board), hang (rope tops),
rest_center (where it lands in the 2400 x 1080 frame), chase_hz, screen}.
"""
import math
import os

import lettering
import pal
from props_base import ART, RES, WRITTEN
from svgk import INK, PB, Canvas, Grad, circle, ellipse, lift, mix, mul, path, rect, write

W, H = 1500, 790
BX0, BY0, BX1, BY1 = 40, 150, 1460, 750         # board (frame outer edge)
FRAME = 66                                      # frame width
FX0, FY0, FX1, FY1 = BX0 + FRAME, BY0 + FRAME, BX1 - FRAME, BY1 - FRAME
ROPES = (330, 1110)
FIELD_TOP = "#3E2F66"
FIELD_BOT = "#1F1A2E"
FACE = "#FFF6EA"          # Hush's face paint
NAVY = "#2B3566"          # Hush's pupils / stripes
CHERRY = "#E23B4E"        # Hush's beret
BULB_DIM = ("#D9963A", "#B8762A", "#FFE3A0")
BULB_HOT = "#FFF8DC"


def _write(name, cv):
    p = os.path.join(ART, "stage", name + ".svg")
    write(p, cv.svg(0, 0, W, H))
    WRITTEN.append((p, "stage"))
    return "%s/stage/%s.svg" % (RES, name)


def bulb_points():
    """Centres of the marquee bulbs along the frame's centre line, evenly spaced, clockwise from top-left."""
    inset = FRAME / 2.0
    x0, y0, x1, y1 = BX0 + inset, BY0 + inset, BX1 - inset, BY1 - inset
    pts = []
    nx, ny = 20, 7
    for i in range(nx):
        pts.append((x0 + (x1 - x0) * i / nx, y0))
    for i in range(ny):
        pts.append((x1, y0 + (y1 - y0) * i / ny))
    for i in range(nx):
        pts.append((x1 - (x1 - x0) * i / nx, y1))
    for i in range(ny):
        pts.append((x0, y1 - (y1 - y0) * i / ny))
    return pts


def _letters(cv, text, baseline, cap_h, track, gid):
    """One line of marquee letters: velvet drop shadow, ink outline, cream-to-gold face, a white sheen."""
    shadow, _ = lettering.word(text, baseline + cap_h * 0.07, cap_h, cx=W / 2.0 + cap_h * 0.03, track=track)
    body, wdt = lettering.word(text, baseline, cap_h, cx=W / 2.0, track=track)
    cv.add(path(shadow, fill=pal.VELVET_DEEP, sw=cap_h * 0.09, stroke=pal.VELVET_DEEP, sil=False))
    cv.add(path(body, fill=INK, sw=cap_h * 0.085, stroke=INK, sil=False))
    g = cv.grad(Grad(gid, "linear", (0, baseline - cap_h, 0, baseline), [(0, "#FFFBEF", None), (0.5, pal.GOLD_LT, None), (1, pal.GOLD, None)]))
    cv.add(path(body, fill=g.url(), sil=False))
    # a thin warm sheen across the top third of the letters (the bulbs' reflection)
    sheen = cv.grad(Grad(gid + "s", "linear", (0, baseline - cap_h, 0, baseline - cap_h * 0.55),
                         [(0, "#FFFFFF", 0.55), (1, "#FFFFFF", 0.0)]))
    cv.add(path(body, fill=sheen.url(), sil=False))
    return wdt


def _star(cx, cy, r, k=0.46):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        rr = r if i % 2 == 0 else r * k
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return PB().poly(pts)


def _bulb_dim(cv, x, y):
    cv.add(circle(x, y, 15, fill=BULB_DIM[1], sil=False))
    cv.add(circle(x - 2, y - 2, 11, fill=BULB_DIM[0], sil=False))
    cv.add(circle(x - 5, y - 6, 3.5, fill=BULB_DIM[2], fop=0.8, sil=False))
    cv.add(circle(x, y, 15, fill="none", sw=3, stroke=INK, sil=False))


def _bulb_hot(cv, x, y, gid):
    g = cv.grad(Grad(gid, "radial", (x, y, 40), [(0, "#FFF4C8", 0.9), (0.4, "#FFE08A", 0.45), (1, "#FFC050", 0.0)]))
    cv.add(circle(x, y, 40, fill=g.url(), sil=False))
    cv.add(circle(x, y, 15, fill=BULB_HOT, sil=False))
    cv.add(circle(x - 5, y - 6, 4, fill="#FFFFFF", sil=False))
    cv.add(circle(x, y, 15, fill="none", sw=3, stroke=INK, sil=False))


def board():
    cv = Canvas()
    # the two fly ropes (gold, twisted) + brass rings on the board's top rail
    for rx in ROPES:
        rope = PB().M(rx, 4).L(rx, BY0 - 6)
        cv.add(path(rope, fill="none", sw=12, stroke=INK, sil=False), path(rope, fill="none", sw=7, stroke=pal.GOLD_SH, sil=False))
        tw = PB()
        y = 10
        while y < BY0 - 16:
            tw.M(rx - 3, y).L(rx + 3, y + 8)
            y += 12
        cv.add(path(tw, fill="none", sw=2.5, stroke=pal.GOLD_LT, sil=False))
        cv.add(circle(rx, BY0 - 8, 13, fill="none", sw=10, stroke=INK, sil=False), circle(rx, BY0 - 8, 13, fill="none", sw=5, stroke=pal.GOLD, sil=False))
    # the crest over the top rail: a gilded half-medallion with a star
    crest = PB().M(W / 2 - 170, BY0 + 6).Q(W / 2 - 150, BY0 - 118, W / 2, BY0 - 124).Q(W / 2 + 150, BY0 - 118, W / 2 + 170, BY0 + 6).Z()
    cv.add(path(crest, fill=pal.GOLD_SH), path(PB().M(W / 2 - 150, BY0).Q(W / 2 - 132, BY0 - 104, W / 2, BY0 - 110).Q(W / 2 + 120, BY0 - 100, W / 2 + 130, BY0 - 10).Z(),
                                               fill=pal.GOLD, sil=False))
    cv.add(path(crest, fill="none", sw=6, stroke=INK))
    cv.add(path(_star(W / 2, BY0 - 50, 42), fill=pal.VELVET, sw=5, stroke=INK))
    cv.add(path(_star(W / 2 - 4, BY0 - 55, 20), fill=pal.VELVET_LT, sil=False))
    for sx in (-1, 1):
        cv.add(circle(W / 2 + sx * 110, BY0 - 36, 9, fill=pal.GOLD_LT, sw=3.5, stroke=INK, sil=False))
    # the gilded frame (shade-first inset: shade, lit face up-left, a gold-light bevel), ink outline
    cv.add(rect(BX0, BY0, BX1 - BX0, BY1 - BY0, 46, fill=pal.GOLD_SH))
    cv.add(rect(BX0, BY0, BX1 - BX0 - 10, BY1 - BY0 - 12, 42, fill=pal.GOLD, sil=False))
    cv.add(rect(BX0 + 14, BY0 + 12, BX1 - BX0 - 44, 10, 5, fill=pal.GOLD_LT, fop=0.8, sil=False))
    cv.add(rect(BX0, BY0, BX1 - BX0, BY1 - BY0, 46, fill="none", sw=6, stroke=INK))
    # beading: a thin inner bevel line round the field
    cv.add(rect(FX0 - 12, FY0 - 12, FX1 - FX0 + 24, FY1 - FY0 + 24, 26, fill="none", sw=4, stroke=pal.GOLD_SH, sil=False))
    # the field: deep violet, a soft glow behind the words
    g = cv.grad(Grad("tc_field", "linear", (0, FY0, 0, FY1), [(0, FIELD_TOP, None), (1, FIELD_BOT, None)]))
    cv.add(rect(FX0, FY0, FX1 - FX0, FY1 - FY0, 20, fill=g.url(), sil=False))
    gl = cv.grad(Grad("tc_glow", "radial", (W / 2, (FY0 + FY1) / 2 - 20, 560), [(0, "#8A5CC8", 0.45), (1, "#8A5CC8", 0.0)]))
    cv.add(ellipse(W / 2, (FY0 + FY1) / 2 - 20, 600, 230, fill=gl.url(), sil=False))
    # a sprinkle of tiny gold stars in the field corners
    for sx, sy, r in ((FX0 + 44, FY0 + 40, 12), (FX1 - 44, FY0 + 40, 12), (FX0 + 40, FY1 - 44, 9), (FX1 - 40, FY1 - 44, 9)):
        cv.add(path(_star(sx, sy, r, 0.4), fill=pal.GOLD_LT, sil=False))
    cv.add(rect(FX0, FY0, FX1 - FX0, FY1 - FY0, 20, fill="none", sw=4, stroke=INK, sil=False))
    # the words
    _letters(cv, "MISCHIEF", FY0 + 226, 178, 6, "tc_l1")
    # the rule between the lines: gold ribbon with a diamond
    ry = FY0 + 276
    for sx in (-1, 1):
        rl = PB().M(W / 2 + sx * 40, ry).L(W / 2 + sx * 300, ry)
        cv.add(path(rl, fill="none", sw=10, stroke=INK, sil=False), path(rl, fill="none", sw=5, stroke=pal.GOLD, sil=False))
        cv.add(circle(W / 2 + sx * 312, ry, 7, fill=pal.GOLD, sw=3.5, stroke=INK, sil=False))
    dm = PB().poly([(W / 2, ry - 18), (W / 2 + 18, ry), (W / 2, ry + 18), (W / 2 - 18, ry)])
    cv.add(path(dm, fill=pal.VELVET, sw=4, stroke=INK, sil=False))
    _letters(cv, "NEXT DOOR", FY0 + 428, 118, 10, "tc_l2")
    # bulbs (unlit-warm)
    for (x, y) in bulb_points():
        _bulb_dim(cv, x, y)
    # Hush peeking over the top-right of the frame: beret, painted face, big warm eyes glancing at the words,
    # and three glove fingertips gripping the rail
    hx, hy = 1300, BY0 + 4
    face = PB().M(hx - 70, hy + 10).Q(hx - 72, hy - 84, hx, hy - 88).Q(hx + 72, hy - 84, hx + 70, hy + 10).Z()
    cv.add(path(face, fill=FACE, sw=6, stroke=INK))
    beret = PB().M(hx - 80, hy - 60).Q(hx - 60, hy - 138, hx + 20, hy - 132).Q(hx + 84, hy - 124, hx + 78, hy - 70).Q(hx, hy - 88, hx - 80, hy - 60).Z()
    cv.add(path(beret, fill=CHERRY, sw=6, stroke=INK))
    cv.add(path(PB().M(hx + 6, hy - 132).Q(hx + 10, hy - 150, hx + 22, hy - 152), fill="none", sw=6, stroke=INK, sil=False))
    cv.add(path(PB().M(hx - 56, hy - 84).Q(hx - 20, hy - 112, hx + 40, hy - 116), fill="none", sw=5, stroke="#FFFFFF", sop=0.5, sil=False))
    for ex in (-26, 26):
        cv.add(ellipse(hx + ex, hy - 40, 20, 24, fill="#FFFFFF", sw=4, stroke=INK))
        cv.add(circle(hx + ex - 8, hy - 36, 12, fill=NAVY, sil=False))
        cv.add(circle(hx + ex - 12, hy - 41, 4, fill="#FFFFFF", sil=False))
    cv.add(path(PB().M(hx - 48, hy - 70).Q(hx - 30, hy - 80, hx - 10, hy - 72).M(hx + 8, hy - 76).Q(hx + 30, hy - 82, hx + 48, hy - 66), fill="none", sw=5,
                stroke=INK, sil=False))
    # blush peeking just above the rail
    for ex in (-44, 44):
        cv.add(ellipse(hx + ex, hy - 6, 13, 7, fill="#FF9FB0", fop=0.7, sil=False))
    # glove fingertips curled over the rail: two hands of three round tips (ink-first so the tips separate)
    for hand in ((hx - 96, hx - 76, hx - 56), (hx + 52, hx + 72, hx + 92)):
        for fx in hand:
            cv.add(ellipse(fx, hy - 2, 13.5, 16.5, fill=INK, sil=False))
        for fx in hand:
            cv.add(ellipse(fx, hy - 3, 9.5, 12.5, fill="#FFFFFF", sil=False))
        cv.add(path(PB().M(hand[0] - 6, hy - 8).Q(hand[0] - 2, hy - 13, hand[0] + 3, hy - 12), fill="none", sw=2.5, stroke="#DDE3EE", sil=False))
    return cv


def bulbs(parity):
    cv = Canvas()
    for i, (x, y) in enumerate(bulb_points()):
        if i % 2 == parity:
            _bulb_hot(cv, x, y, "tcb%d_%d" % (parity, i))
    return cv


def build():
    """Writes the three files; returns the house.json stage.title_card block."""
    art = _write("title_card", board())
    a = _write("title_card_bulbs_a", bulbs(0))
    b = _write("title_card_bulbs_b", bulbs(1))
    return {"art": art, "bulbs": [a, b], "size": [W, H], "screen": True, "pivot": [W // 2, BY1], "hang": [W // 2, 0],
            "rest_center": [1200, H // 2], "chase_hz": 6.0, "drop_s": 0.3, "hold_s": 1.2}
