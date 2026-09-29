"""icons_items - the 16 item icons (TECH §14 ids) at a 128 px canvas: bold silhouettes, 6 px ink,
one flat shade per shape, readable at 64 px (tray slots are 128 px, pick-strip 144 px, badges 56 px).
Written to game/art/house/items/<item>.svg (items.json points its "icon" there)."""
import math
import os

import pal
from draw import ball, blob, box, oval, shape, sparkle
from props_base import ART, WRITTEN
from svgk import INK, PB, Canvas, circle, ellipse, fit, group, lift, mix, mul, path, poly, rect, reduce_palette, write

S = 6.0          # icon silhouette ink
D = 3.5          # icon detail ink
N = 128


def ink(pb, sw=S):
    return path(pb, fill="none", sw=sw, stroke=INK)


def det(pb, sw=D):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=False)


def squeaker():
    out = []
    horn = [(64, 58), (112, 34), (118, 42), (118, 100), (112, 108), (64, 84)]
    out += shape(horn, pal.BRASS[0], S)
    out.append(path(PB().M(70, 64).L(110, 44).L(110, 58).L(70, 74).Z(), fill=pal.BRASS[2], fop=0.7, sil=False))
    out.append(ellipse(114, 71, 6, 32, fill=pal.BRASS[1], sw=S, stroke=INK))
    out += ball(42, 71, 34, pal.TOMATO, S)
    out.append(det(PB().M(26, 50).Q(18, 70, 26, 92), 3.5))
    return out


def magnifier():
    out = []
    h = PB().M(80, 80).L(114, 114)
    out += [path(h, fill="none", sw=24, stroke=INK), path(h, fill="none", sw=12, stroke=pal.WALNUT[0], sil=False)]
    out += ball(52, 52, 40, pal.BRASS, S, hi=False)
    out += ball(52, 52, 30, pal.GLASS, D, hi=False)
    out.append(path(PB().M(34, 44).Q(38, 30, 52, 26), fill="none", sw=6, stroke="#FFFFFF", sil=False))
    return out


def balloon():
    g = ("#6CCB5F", "#4FA844", "#B8EEB0")
    out = [path(PB().M(64, 96).C(52, 106, 76, 112, 60, 122), fill="none", sw=4, stroke=INK, sil=False)]
    out += blob([(64, 94), (98, 58), (96, 22), (64, 6), (32, 22), (30, 58)], g, S, k=0.82, hi=True)
    out += shape([(56, 102), (72, 102), (64, 92)], g[1], D + 1)
    return out


def croc():
    g = ("#6CC06A", "#4E9E52", "#B5E8B0")
    out = []
    # wind-up key on the back
    out += [path(PB().M(52, 50).L(52, 34), fill="none", sw=10, stroke=INK)]
    out += shape([(52, 36), (36, 22), (36, 40)], pal.BRASS[0], D + 1)
    out += shape([(52, 36), (68, 22), (68, 40)], pal.BRASS[0], D + 1)
    body = [(10, 84), (16, 62), (40, 52), (78, 52), (104, 58), (122, 62), (122, 76), (100, 82), (80, 92), (30, 96)]
    out += blob(body, g, S, k=0.86, t=0.4)
    # zigzag grin + teeth, eye bump, legs
    tz = PB().M(84, 72)
    for i in range(6):
        tz.L(88 + i * 6, 66 if i % 2 else 74)
    out.append(path(tz, fill="none", sw=3, stroke="#FFFFFF", sil=False))
    out.append(det(PB().M(82, 70).L(120, 70), 3))
    out += ball(84, 48, 11, ("#FFFFFF", "#DDE3EE", "#FFFFFF"), D, hi=False)
    out.append(circle(86, 48, 5, fill=INK, sil=False))
    for lx in (30, 62):
        out += box(lx, 90, 14, 20, 5, g, D + 1, hi=False)
    bumps = PB()
    for bx in (26, 40, 54, 68):
        bumps.M(bx - 5, 56).L(bx, 48).L(bx + 5, 56)
    out.append(path(bumps, fill=g[1], sw=D, stroke=INK, sil=False))
    return out


def kipper():
    k = ("#D9954E", "#B8733A", "#F5C68A")
    out = []
    tail = [(26, 64), (6, 40), (14, 64), (6, 88)]
    out += shape(tail, k[1], S)
    body = [(24, 64), (44, 42), (86, 38), (120, 60), (86, 86), (44, 86)]
    out += blob(body, k, S, k=0.82, t=0.5, hi=True)
    out.append(det(PB().M(52, 46).Q(42, 64, 52, 82), 3.5))
    out.append(det(PB().M(64, 56).L(92, 54).M(64, 70).L(94, 70), 3))
    out.append(circle(100, 56, 6, fill=INK, sil=False))
    out.append(circle(98, 54, 2, fill="#FFFFFF", sil=False))
    return out


def butter():
    y = ("#FFE59A", "#E8C25E", "#FFF5CC")
    out = []
    out += oval(64, 96, 56, 16, pal.PORCELAIN, S, hi=False)
    out.append(ellipse(64, 94, 40, 8, fill=pal.COBALT[2], sil=False))
    blk = [(22, 86), (30, 52), (98, 44), (108, 78)]
    out += shape([(22, 86), (30, 52), (88, 46), (84, 82)], y[0], S)
    out += shape([(84, 82), (88, 46), (98, 44), (108, 78)], y[1], S)
    out.append(path(PB().M(34, 56).L(80, 50), fill="none", sw=5, stroke="#FFFFFF", sop=0.8, sil=False))
    return out


def flour():
    m = ("#FBF7EC", "#E2D8C0", "#FFFFFF")
    out = blob([(24, 118), (104, 118), (112, 70), (96, 26), (80, 16), (48, 16), (32, 26), (16, 70)], m, S, k=0.84)
    out.append(det(PB().M(38, 30).Q(64, 40, 90, 30), 4))
    out.append(det(PB().M(64, 104).L(64, 52), 4))
    for i in range(3):
        yy = 90 - i * 14
        out.append(ellipse(54, yy, 9, 5, fill=pal.MUSTARD[0], sw=2.5, stroke=INK, sil=False))
        out.append(ellipse(74, yy, 9, 5, fill=pal.MUSTARD[0], sw=2.5, stroke=INK, sil=False))
    out.append(ellipse(64, 46, 6, 9, fill=pal.MUSTARD[0], sw=2.5, stroke=INK, sil=False))
    return out


def sherbet():
    out = box(38, 30, 52, 92, 12, ("#FFE36B", "#E8C23A", "#FFF6B8"), S, hi=False)
    st = PB()
    for i in range(4):
        y = 108 - i * 22
        st.M(40, y).L(88, y - 14).L(88, y - 6).L(40, y + 8).Z()
    out.append(path(st, fill="#F46FA4", sil=False))
    out.append(rect(38, 30, 52, 92, 12, fill="none", sw=S, stroke=INK))
    fizz = PB().circle(52, 18, 6).circle(72, 12, 5).circle(84, 24, 4).circle(40, 8, 3.5)
    out.append(path(fizz, fill="#FFFFFF", sw=3, stroke=INK, sil=True))
    return out


def treacle():
    g = ("#3E7A55", "#2D5E41", "#7DB08E")
    out = box(24, 40, 80, 80, 10, g, S, hi=True)
    out += box(20, 28, 88, 20, 8, pal.BRASS, S, hi=False)
    drip = PB().M(40, 46).L(84, 46).L(82, 84).Q(72, 100, 66, 84).L(64, 66).Q(56, 76, 50, 62).L(44, 76).Q(36, 74, 40, 46).Z()
    out += [path(drip, fill=pal.HONEY[0], sil=False), det(drip, 3)]
    return out


def salt():
    b = ("#5E8FE0", "#4471C0", "#A9C7F5")
    out = box(34, 30, 60, 90, 10, b, S, hi=True)
    out += shape([(34, 30), (52, 10), (76, 10), (94, 30)], b[1], S)
    out.append(circle(64, 76, 16, fill="#FFFFFF", sw=D, stroke=INK, sil=False))
    gr = PB().circle(60, 72, 3).circle(68, 78, 3).circle(62, 82, 2.5)
    out.append(path(gr, fill=b[2], sil=False))
    out += box(56, 4, 14, 12, 3, ("#FFFFFF", "#DDE3EE", "#FFFFFF"), D, hi=False)
    return out


def bubble_bath():
    p_ = ("#F59AC0", "#D877A0", "#FFD0E4")
    out = box(40, 44, 50, 78, 16, p_, S, hi=True)
    out += box(52, 22, 26, 26, 6, ("#FFFFFF", "#DDE3EE", "#FFFFFF"), S, hi=False)
    out.append(ellipse(65, 84, 16, 12, fill="#FFFFFF", sw=D, stroke=INK, sil=False))
    for (bx, by, r) in [(22, 40, 14), (104, 30, 12), (108, 64, 9), (18, 76, 9), (32, 16, 7)]:
        out.append(circle(bx, by, r, fill="#E8F7FF", sw=4, stroke=INK))
        out.append(circle(bx - r * 0.3, by - r * 0.3, r * 0.25, fill="#FFFFFF", sil=False))
    return out


def apple():
    a = ("#E8473C", "#C0302A", "#FFA79C")
    out = []
    out += shape([(66, 30), (92, 12), (104, 22), (80, 36)], pal.GRASS[0], S, smooth=True)
    out.append(path(PB().M(64, 34).Q(60, 20, 66, 10), fill="none", sw=8, stroke=INK))
    out.append(path(PB().M(64, 34).Q(60, 20, 66, 10), fill="none", sw=3, stroke=pal.WALNUT[0], sil=False))
    out += blob([(64, 36), (92, 28), (112, 56), (100, 104), (74, 120), (64, 112), (54, 120), (28, 104), (16, 56), (36, 28)], a, S, k=0.84, hi=True)
    return out


def feathers():
    """A feather duster: a fat fan of plumes on a turned handle."""
    out = []
    h = PB().M(62, 76).L(44, 122)
    out += [path(h, fill="none", sw=20, stroke=INK), path(h, fill="none", sw=9, stroke=pal.WALNUT[0], sil=False)]
    cols = ["#FFFFFF", "#F5C0D8", "#FFE59A", "#C8E6F8", "#F5C0D8", "#FFFFFF"]
    for i, ang in enumerate((-75, -45, -15, 15, 45, 75)):
        a = math.radians(ang - 90)
        tipx, tipy = 64 + 58 * math.cos(a), 70 + 58 * math.sin(a)
        nx, ny = -math.sin(a), math.cos(a)
        mx, my = 64 + 34 * math.cos(a), 70 + 34 * math.sin(a)
        f = [(64 + 6 * nx, 70 + 6 * ny), (mx + 16 * nx, my + 16 * ny), (tipx, tipy), (mx - 16 * nx, my - 16 * ny), (64 - 6 * nx, 70 - 6 * ny)]
        out += shape(f, cols[i], D + 1, smooth=True, t=0.4)
        out.append(path(PB().M(64, 70).L(tipx * 0.85 + 64 * 0.15, tipy * 0.85 + 70 * 0.15), fill="none", sw=2.5, stroke=INK, sil=False))
    out += box(50, 64, 26, 20, 7, pal.BRASS, D + 1, hi=False)
    return out


def coins():
    out = []
    for i, (cx, cy) in enumerate([(52, 96), (70, 78), (58, 58)]):
        out += oval(cx, cy + 10, 40, 14, pal.BRASS, S, hi=False)
        out += oval(cx, cy, 40, 14, pal.BRASS, S, hi=False)
        out.append(ellipse(cx, cy, 22, 6, fill="none", sw=3, stroke=pal.BRASS[1], sil=False))
    out += sparkle(104, 34, 14, sw=3)
    return out


def tutu():
    pk = ("#F9B7D0", "#E88FB2", "#FFE0EC")
    out = []
    out += blob([(10, 86), (30, 66), (64, 62), (98, 66), (118, 86), (100, 100), (64, 104), (28, 100)], pk, S, k=0.86, t=0.3)
    out += blob([(22, 72), (40, 58), (64, 56), (88, 58), (106, 72), (88, 84), (64, 86), (40, 84)], (pk[2], pk[0], "#FFFFFF"), S, k=0.86, t=0.3)
    out += box(42, 34, 44, 28, 10, pk, S, hi=True)
    out.append(det(PB().M(30, 92).L(36, 80).M(52, 98).L(56, 86).M(76, 98).L(72, 86).M(98, 92).L(92, 80), 3))
    out += ball(64, 34, 8, pal.PINK, D, hi=False)
    return out


def record():
    out = []
    out += ball(64, 64, 56, ("#2C2B38", "#1F1E28", "#5A5970"), S, hi=False)
    grooves = PB().circle(64, 64, 44).circle(64, 64, 34)
    out.append(path(grooves, fill="none", sw=3, stroke="#4A4960", sil=False))
    out.append(path(PB().M(30, 40).Q(40, 26, 58, 22), fill="none", sw=5, stroke="#FFFFFF", sop=0.35, sil=False))
    out.append(circle(64, 64, 20, fill="#C8324A", sw=D, stroke=INK, sil=False))
    out.append(path(PB().M(64, 74).C(52, 66, 56, 54, 64, 60).C(72, 54, 76, 66, 64, 74).Z(), fill="#FFD6E0", sil=False))
    out.append(circle(64, 64, 3, fill=INK, sil=False))
    return out


ITEMS = {"squeaker": squeaker, "magnifier": magnifier, "balloon": balloon, "croc": croc, "kipper": kipper, "butter": butter,
         "flour": flour, "sherbet": sherbet, "treacle": treacle, "salt": salt, "bubble_bath": bubble_bath, "apple": apple,
         "feathers": feathers, "coins": coins, "tutu": tutu, "record": record}


def build(reg):
    for name, fn in ITEMS.items():
        cv = Canvas()
        cv.add(fit(fn(), 4, 4, N - 4, N - 4))
        reduce_palette([cv], 10)
        p = os.path.join(ART, "items", name + ".svg")
        write(p, cv.svg(0, 0, N, N))
        WRITTEN.append((p, "items"))
