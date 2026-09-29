"""icons_activities - thought-bubble icons (88 px canvas, 5 px ink) for every activity id and the
detours (TECH §14): what Bellows will do next, readable at a glance inside his bubble (GDD §3.9).
Written to game/art/icons/activities/<id>.svg (activities.json "icon" points there)."""
import math
import os

import pal
from draw import ball, blob, box, oval, shape, sparkle
from props_base import REPO, WRITTEN
from svgk import INK, PB, Canvas, circle, ellipse, fit, group, lift, mix, mul, path, poly, rect, reduce_palette, write

S = 5.0
D = 3.0
N = 88
OUT = os.path.join(REPO, "game", "art", "icons", "activities")
WHITE3 = ("#FFFFFF", "#DDE3EE", "#FFFFFF")
STEAM = "#FFFFFF"


def det(pb, sw=D):
    return path(pb, fill="none", sw=sw, stroke=INK, sil=False)


def thick(pb, sw, col):
    return [path(pb, fill="none", sw=sw + 2 * S * 0.8, stroke=INK), path(pb, fill="none", sw=sw, stroke=col, sil=False)]


def note(x, y, s=1.0):
    out = [ellipse(x, y, 8 * s, 6 * s, fill=INK)]
    out.append(path(PB().M(x + 7 * s, y - 2 * s).L(x + 7 * s, y - 26 * s).L(x + 16 * s, y - 20 * s), fill="none", sw=4 * s, stroke=INK))
    return out


def steam(x, y, h=20):
    pb = PB().M(x, y).C(x - 8, y - h * 0.35, x + 8, y - h * 0.65, x, y - h)
    return [path(pb, fill="none", sw=7, stroke=INK), path(pb, fill="none", sw=3, stroke=STEAM, sil=False)]


def cup(cx, base, w=40, col=WHITE3):
    out = []
    hd = PB().M(cx + w / 2 - 2, base - 22).C(cx + w / 2 + 14, base - 24, cx + w / 2 + 14, base - 6, cx + w / 2 - 4, base - 6)
    out += thick(hd, 4, col[0])
    out += blob([(cx - w / 2, base - 26), (cx + w / 2, base - 26), (cx + w * 0.36, base - 2), (cx - w * 0.36, base - 2)], col, S, k=0.84, smooth=False)
    out.append(ellipse(cx, base - 26, w / 2, 5, fill="#C9855A", sw=D, stroke=INK))
    out += oval(cx, base + 1, w * 0.62, 5, col, D, hi=False)
    return out


def question(x, y, s=1.0, col=pal.GOLD):
    pb = PB().M(x - 9 * s, y - 10 * s).Q(x - 9 * s, y - 22 * s, x + 1 * s, y - 22 * s).Q(x + 11 * s, y - 22 * s, x + 11 * s, y - 12 * s)
    pb.Q(x + 11 * s, y - 4 * s, x + 1 * s, y + 1 * s).L(x + 1 * s, y + 6 * s)
    return thick(pb, 5 * s, col) + [circle(x + 1 * s, y + 16 * s, 4.5 * s, fill=col, sw=D, stroke=INK)]


# ------------------------------------------------------------------------------------------ icons
def warmup():
    out = []
    neck = PB().M(34, 60).C(26, 44, 30, 32, 42, 26)
    out += thick(neck, 7, pal.BRASS[1])
    out += blob([(38, 30), (48, 16), (70, 6), (82, 12), (80, 30), (60, 40), (44, 40)], pal.BRASS, S, k=0.8, t=0.4)
    out += box(12, 58, 50, 24, 5, pal.WALNUT, S, hi=False)
    out += oval(36, 58, 24, 5, ("#2C2B38", "#1F1E28", "#5A5970"), D, hi=False)
    out += note(70, 66, 0.8)
    return out


def tea():
    return steam(38, 34, 22) + steam(52, 32, 18) + cup(44, 78, 46)


def pickles():
    b = pal.GREEN_GLASS
    out = box(20, 24, 48, 58, 14, b, S, hi=False)
    pb = PB().circle(34, 66, 8).circle(52, 64, 8).circle(42, 48, 8)
    out += [path(pb, fill="#F7F0DC", sil=False), det(pb, 2.5)]
    out += box(16, 12, 56, 16, 5, pal.BRASS, S, hi=False)
    return out


def snack():
    out = box(22, 8, 44, 74, 10, pal.ENAMEL_MINT, S, hi=True)
    out.append(det(PB().M(22, 34).L(66, 34)))
    out += box(56, 16, 6, 12, 3, pal.CHROME, D, hi=False)
    out += box(56, 42, 6, 20, 3, pal.CHROME, D, hi=False)
    # a sausage poking out
    out += blob([(60, 50), (78, 44), (84, 52), (66, 60)], ("#E0876A", "#C0664A", "#F4B8A0"), D + 1, k=0.8)
    return out


def rinse():
    out = []
    col = PB().M(26, 60).L(26, 30).Q(26, 14, 44, 14).L(58, 14)
    out += thick(col, 7, pal.CHROME[0])
    out += box(52, 10, 16, 14, 5, pal.CHROME, D + 1, hi=False)
    out += ball(26, 38, 7, pal.CHROME, D, hi=False)
    for (x, y) in [(60, 40), (66, 58), (56, 72)]:
        pb = PB().M(x, y - 9).Q(x + 7, y + 1, x, y + 5).Q(x - 7, y + 1, x, y - 9).Z()
        out += [path(pb, fill=pal.GLASS[0]), path(pb, fill="none", sw=D, stroke=INK)]
    out += box(10, 62, 36, 20, 6, WHITE3, S, hi=False)
    return out


def paper():
    out = shape([(10, 24), (46, 14), (78, 22), (76, 74), (44, 80), (12, 72)], "#F4F0E4", S)
    out.append(det(PB().M(44, 14).L(44, 80), D))
    cols = PB()
    for i in range(4):
        y = 34 + i * 10
        cols.M(18, y).L(38, y - 2).M(50, y - 2).L(70, y)
    out.append(det(cols, 2.5))
    out += box(16, 22, 22, 8, 2, ("#3A3050", "#2A2240", "#6A6080"), 2, hi=False)
    return out


def fire():
    out = []
    fl = [(44, 82), (22, 70), (18, 46), (32, 22), (36, 40), (46, 8), (60, 34), (64, 22), (72, 46), (68, 70)]
    out += shape(fl, "#F7A23E", S, smooth=True, t=0.45)
    out += shape([(44, 78), (32, 68), (32, 54), (42, 40), (46, 52), (54, 44), (58, 60), (56, 72)], "#FFE07A", D, smooth=True)
    out += box(14, 74, 60, 10, 5, ("#8A5A3E", "#6E4530", "#B8845C"), D + 1, hi=False)
    return out


def mirror():
    out = []
    out += thick(PB().M(44, 62).L(44, 84), 8, pal.WALNUT[0])
    out += ball(44, 36, 30, pal.WALNUT, S, hi=False)
    out += ball(44, 36, 22, pal.GLASS, D, hi=False)
    out.append(path(PB().M(32, 30).Q(34, 20, 44, 18), fill="none", sw=5, stroke="#FFFFFF", sil=False))
    return out


def phone():
    ph = ("#394063", "#262C47", "#7A83AD")
    out = oval(40, 76, 26, 8, ph, S, hi=False)
    out += box(34, 20, 12, 56, 6, ph, S, hi=False)
    out += shape([(38, 22), (62, 6), (70, 18), (46, 30)], ph[0], S)
    out += thick(PB().M(34, 36).L(18, 34).L(16, 26), 4, pal.BRASS[0])
    out += box(8, 22, 14, 40, 6, ph, S, hi=False)
    return out


def clock():
    out = ball(44, 44, 36, pal.BRASS, S, hi=False)
    out.append(circle(44, 44, 27, fill="#FFF6E2", sw=D, stroke=INK))
    t = PB()
    for i in range(12):
        a = math.radians(i * 30)
        t.M(44 + 21 * math.sin(a), 44 - 21 * math.cos(a)).L(44 + 25 * math.sin(a), 44 - 25 * math.cos(a))
    out.append(det(t, 2.5))
    out.append(path(PB().M(44, 44).L(33, 31).M(44, 44).L(58, 40), fill="none", sw=5, stroke=INK))
    out.append(circle(44, 44, 4, fill=INK))
    return out


def piano():
    out = box(6, 22, 76, 50, 8, ("#FFFFFF", "#DDE3EE", "#FFFFFF"), S, hi=False)
    keys = PB()
    for i in range(1, 6):
        keys.M(6 + i * 12.7, 24).L(6 + i * 12.7, 70)
    out.append(det(keys, 2.5))
    for i in (0, 1, 3, 4):
        out.append(rect(6 + (i + 1) * 12.7 - 4, 22, 8, 28, 2, fill=INK))
    out += note(64, 18, 0.55)
    return out


def gargle():
    out = box(28, 34, 30, 48, 10, ("#F59AC0", "#D877A0", "#FFD0E4"), S, hi=True)
    out += box(32, 16, 22, 20, 5, WHITE3, S, hi=False)
    out += thick(PB().M(54, 22).L(70, 16), 4, WHITE3[0])
    for (x, y, r) in [(76, 12, 5), (80, 28, 4), (70, 36, 3.5)]:
        out.append(circle(x, y, r, fill="#E8F7FF", sw=D, stroke=INK))
    return out


def bath():
    out = []
    for (x, y, r) in [(24, 24, 9), (40, 16, 11), (58, 20, 9), (70, 30, 6)]:
        out.append(circle(x, y, r, fill="#E8F7FF", sw=D, stroke=INK))
    tub = PB().M(8, 42).L(80, 42).Q(78, 72, 60, 74).L(28, 74).Q(10, 72, 8, 42).Z()
    out += [path(tub, fill=WHITE3[1]), path(PB().M(10, 44).L(70, 44).Q(66, 66, 50, 66).L(28, 66).Q(14, 64, 10, 44).Z(), fill=WHITE3[0], sil=False),
            path(tub, fill="none", sw=S, stroke=INK)]
    out += box(4, 36, 80, 10, 5, WHITE3, S, hi=False)
    for fx in (24, 64):
        out += shape([(fx - 6, 72), (fx + 6, 72), (fx + 8, 84), (fx - 8, 84)], pal.BRASS[0], D)
    return out


def radiator():
    out = box(10, 26, 68, 50, 8, WHITE3, S, hi=False)
    fins = PB()
    for i in range(1, 5):
        fins.M(10 + i * 13.6, 30).L(10 + i * 13.6, 72)
    out.append(det(fins, 3))
    for i, x in enumerate((24, 44, 64)):
        pb = PB().M(x, 20).C(x - 6, 14, x + 6, 10, x, 4)
        out += thick(pb, 3, "#F7A23E")
    return out


def dress():
    out = []
    out += thick(PB().M(44, 8).Q(52, 8, 50, 16).L(44, 20), 3, pal.CHROME[0])
    out += thick(PB().M(14, 34).L(44, 20).L(74, 34), 4, pal.WALNUT[0])
    jacket = [(18, 34), (44, 26), (70, 34), (74, 82), (52, 84), (44, 60), (36, 84), (14, 82)]
    out += shape(jacket, "#7B3F8C", S)
    out += shape([(36, 30), (44, 58), (52, 30)], "#E8B33A", D)
    return out


def nap():
    out = blob([(8, 64), (14, 46), (44, 42), (76, 46), (82, 64), (76, 78), (44, 80), (12, 78)], WHITE3, S, k=0.86)
    zz = PB().M(40, 8).L(56, 8).L(40, 26).L(56, 26).M(62, 18).L(74, 18).L(62, 32).L(74, 32)
    out.append(path(zz, fill="none", sw=5, stroke=INK))
    return out


def feed_beryl():
    out = []
    out += shape([(14, 44), (74, 44), (66, 82), (22, 82)], "#8FA0B8", S)
    out.append(ellipse(44, 44, 30, 8, fill="#C9A06A", sw=D, stroke=INK))
    pb = PB().circle(34, 40, 4).circle(46, 38, 4).circle(56, 41, 4)
    out.append(path(pb, fill="#E8C87A", sil=False))
    out += thick(PB().M(18, 46).Q(44, 8, 70, 46), 3, pal.CHROME[0])
    out += ball(66, 22, 9, ("#FF7FB0", "#E0609A", "#FFC0DA"), D, hi=False)
    return out


def roses():
    out = []
    out += thick(PB().M(44, 50).Q(40, 70, 46, 84), 4, pal.GRASS[1])
    out += shape([(44, 70), (26, 60), (34, 74)], pal.GRASS[0], D)
    out += ball(44, 32, 24, ("#E86A7A", "#C84A5E", "#F8B0BC"), S, hi=False)
    sp = PB().M(44, 32).Q(54, 24, 48, 18).Q(36, 18, 34, 30).Q(34, 44, 50, 44).Q(62, 40, 60, 26)
    out.append(det(sp, 3))
    return out


def marrow():
    out = blob([(8, 56), (18, 36), (48, 30), (80, 40), (82, 58), (58, 70), (24, 70)], ("#7FBF5A", "#5E9E44", "#B8E0A0"), S, k=0.84, hi=True)
    out.append(det(PB().M(18, 50).Q(46, 40, 76, 50).M(20, 58).Q(46, 52, 74, 58), 2.5))
    out += thick(PB().M(80, 44).Q(86, 36, 80, 28), 3, pal.GRASS[1])
    return out


def stroll():
    out = []
    for (x, y, ang) in [(26, 64, -10), (54, 36, 10)]:
        items = [ellipse(x, y, 10, 16, fill=INK), circle(x - 6, y - 22, 4, fill=INK), circle(x + 1, y - 25, 4.5, fill=INK), circle(x + 8, y - 22, 4, fill=INK)]
        out.append(group(items, rot=ang, cx=x, cy=y))
    out += thick(PB().M(70, 82).L(78, 20).Q(80, 8, 68, 10), 4, pal.WALNUT[0])
    return out


def polish():
    out = shape([(26, 14), (62, 14), (60, 34), (50, 46), (38, 46), (28, 34)], pal.GOLD, S)
    out += thick(PB().M(26, 20).Q(8, 20, 18, 36), 3, pal.GOLD)
    out += thick(PB().M(62, 20).Q(80, 20, 70, 36), 3, pal.GOLD)
    out += box(38, 46, 12, 16, 3, pal.BRASS, D, hi=False)
    out += box(26, 62, 36, 18, 4, pal.WALNUT, S, hi=False)
    out += sparkle(72, 58, 12, sw=3)
    return out


def cloak():
    out = []
    out += thick(PB().M(14, 22).L(44, 12).L(74, 22), 4, pal.WALNUT[0])
    cape = [(20, 22), (44, 16), (68, 22), (80, 82), (44, 76), (8, 82)]
    out += shape(cape, "#3E73D6", S)
    out += shape([(28, 24), (44, 20), (60, 24), (58, 36), (44, 32), (30, 36)], "#E86A7A", D)
    return out


def answer_door():
    out = box(18, 8, 44, 76, 6, ("#2E8272", "#23675A", "#7CC4B4"), S, hi=False)
    out.append(det(PB().rrect(26, 16, 28, 26, 3).rrect(26, 48, 28, 28, 3), 2.5))
    out += ball(54, 50, 4, pal.BRASS, 2.5, hi=False)
    bell = PB().M(64, 40).Q(64, 20, 76, 20).Q(88, 20, 88, 40).L(90, 44).L(62, 44).Z()
    out += [path(bell, fill=pal.GOLD), path(bell, fill="none", sw=D + 1, stroke=INK)]
    out.append(circle(76, 48, 4, fill=INK))
    return out


def host_tea():
    out = []
    tp = [(12, 66), (44, 66), (48, 48), (38, 34), (18, 34), (8, 48)]
    out += shape([(44, 52), (58, 40), (62, 44), (46, 62)], WHITE3[1], D + 1)
    out += blob(tp, WHITE3, S, k=0.84, smooth=False)
    out.append(path(PB().M(12, 50).Q(28, 58, 44, 50), fill="none", sw=3, stroke=pal.COBALT[0], sil=False))
    out += ball(28, 30, 5, WHITE3, D, hi=False)
    out += cup(68, 80, 26)
    # a little heart (he is courting)
    out.append(path(PB().M(68, 32).C(58, 24, 62, 12, 68, 18).C(74, 12, 78, 24, 68, 32).Z(), fill="#E86A7A", sw=D, stroke=INK))
    return out


def tango():
    """Her red heeled shoe and his black brogue mid-step, and the rose (the tango)."""
    out = []
    red = ("#E0413E", "#B82E2C", "#F49A98")
    heel = group(shape([(10, 58), (18, 44), (40, 50), (52, 62), (48, 68), (16, 68)], red[0], S, smooth=True, t=0.35)
                 + [path(PB().M(14, 66).L(12, 82), fill="none", sw=8, stroke=INK), path(PB().M(14, 66).L(12, 82), fill="none", sw=3, stroke=red[0], sil=False)],
                 rot=-14, cx=30, cy=60)
    brogue = group(shape([(44, 70), (48, 56), (70, 52), (84, 60), (82, 72), (46, 76)], "#3A3050", S, smooth=True, t=0.35)
                   + [path(PB().M(56, 60).L(72, 58), fill="none", sw=2.5, stroke="#8A8298", sil=False)], rot=10, cx=64, cy=64)
    out += [heel, brogue]
    out += thick(PB().M(30, 30).Q(46, 18, 60, 26), 3, pal.GRASS[1])
    out += shape([(40, 24), (34, 14), (46, 18)], pal.GRASS[0], D)
    out += ball(64, 22, 11, ("#E86A7A", "#C84A5E", "#F8B0BC"), D + 1, hi=False)
    out.append(path(PB().M(64, 22).Q(70, 16, 66, 12).Q(58, 14, 60, 22), fill="none", sw=2.5, stroke=INK, sil=False))
    return out


def rehearse():
    out = []
    beam = PB().M(22, 20).L(8, 84).L(80, 84).L(50, 20).Z()
    out.append(path(beam, fill="#FFF3C0", fop=0.9, sil=False))
    out += box(24, 8, 26, 18, 5, ("#5A5E78", "#44485E", "#8A8EA8"), S, hi=False)
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 16 if i % 2 == 0 else 7
        pts.append((44 + r * math.cos(a), 62 + r * math.sin(a)))
    out += shape(pts, pal.GOLD, S)
    return out


def hunt():
    out = []
    out += thick(PB().M(52, 52).L(76, 76), 8, pal.WALNUT[0])
    out += ball(38, 38, 26, pal.BRASS, S, hi=False)
    out += ball(38, 38, 18, pal.GLASS, D, hi=False)
    out += question(38, 42, 0.8, INK)
    return out


def fixup_dry():
    out = []
    towel = [(14, 30), (74, 30), (70, 84), (18, 84)]
    out += shape(towel, "#F2B8C8", S)
    out.append(det(PB().M(18, 70).L(70, 70).M(18, 76).L(70, 76), 2.5))
    out += box(8, 22, 72, 10, 5, pal.WALNUT, D + 1, hi=False)
    for x in (30, 44, 58):
        out += thick(PB().M(x, 18).C(x - 6, 12, x + 6, 8, x, 2), 3, "#F7A23E")
    return out


def fixup_sink():
    out = box(14, 46, 56, 30, 12, ("#9FE0D0", "#78C4B2", "#D0F4EA"), S, hi=True)
    for (x, y, r) in [(26, 30, 10), (48, 22, 13), (68, 34, 9), (74, 14, 6)]:
        out.append(circle(x, y, r, fill="#E8F7FF", sw=D, stroke=INK))
        out.append(circle(x - r * 0.3, y - r * 0.3, r * 0.25, fill="#FFFFFF", sil=False))
    return out


def fixup_honey():
    out = []
    out += thick(PB().M(58, 10).L(38, 52), 5, pal.LIGHTWOOD[0])
    out += group(oval(34, 60, 16, 12, pal.LIGHTWOOD, S, hi=False) + [det(PB().M(22, 56).L(46, 56).M(22, 64).L(46, 64), 2.5)], rot=-24, cx=34, cy=60).items
    drip = PB().M(28, 70).Q(30, 80, 26, 86).Q(22, 80, 24, 72).Z()
    out += [path(drip, fill=pal.HONEY[0]), path(drip, fill="none", sw=D, stroke=INK)]
    out += ball(66, 70, 14, pal.HONEY, S, hi=True)
    return out


def fixup_mirror():
    out = []
    out += thick(PB().M(32, 58).L(32, 84), 7, pal.WALNUT[0])
    out += ball(32, 36, 24, pal.WALNUT, S, hi=False)
    out += ball(32, 36, 17, pal.GLASS, D, hi=False)
    comb = [(56, 12), (82, 12), (82, 24), (56, 24)]
    out += shape(comb, "#E8B33A", S)
    teeth = PB()
    for i in range(6):
        x = 58 + i * 4.4
        teeth.M(x, 24).L(x, 40)
    out += [path(teeth, fill="none", sw=6, stroke=INK), path(teeth, fill="none", sw=2.5, stroke="#E8B33A", sil=False)]
    return out


def curious():
    ear = PB().M(26, 20).Q(56, 8, 60, 40).Q(60, 60, 44, 70).Q(36, 76, 30, 68).Q(40, 60, 36, 50).Q(20, 44, 26, 20).Z()
    out = [path(ear, fill="#F4C9A8"), path(PB().M(34, 26).Q(50, 20, 50, 40).Q(48, 50, 42, 52), fill="none", sw=D, stroke=INK, sil=False),
           path(ear, fill="none", sw=S, stroke=INK)]
    out += question(68, 50, 0.9)
    return out


def herd_beryl():
    cream = ("#F3EAD6", "#DCCFB0", "#FFFFFF")
    out = []
    for sgn in (-1, 1):
        out += shape([(44 + sgn * 14, 30), (44 + sgn * 34, 20), (44 + sgn * 24, 38)], cream[1], D + 1)
        out += thick(PB().M(44 + sgn * 8, 22).Q(44 + sgn * 18, 6, 44 + sgn * 26, 10), 3, "#C9B894")
    out += blob([(26, 30), (62, 30), (66, 56), (54, 76), (34, 76), (22, 56)], cream, S, k=0.86)
    out += shape([(38, 74), (50, 74), (44, 88)], cream[1], D)
    for sgn in (-1, 1):
        out.append(ellipse(44 + sgn * 11, 46, 7, 6, fill="#FFFFFF", sw=D, stroke=INK))
        out.append(rect(44 + sgn * 11 - 4, 44, 8, 4, 1.5, fill=INK))
    out.append(ellipse(44, 64, 6, 4, fill="#E8A0B0", sw=D, stroke=INK))
    out += box(28, 78, 32, 8, 4, ("#FF7FB0", "#E0609A", "#FFC0DA"), D, hi=False)
    return out


def search():
    out = []
    specs = PB().circle(26, 44, 16).circle(62, 44, 16)
    out += [path(specs, fill="#E8F7FF", fop=0.9), path(specs, fill="none", sw=S, stroke=INK)]
    out.append(path(PB().M(42, 42).Q(44, 36, 46, 42), fill="none", sw=S, stroke=INK))
    out.append(circle(30, 46, 5, fill=INK))
    out.append(circle(66, 46, 5, fill=INK))
    out += question(44, 18, 0.55, pal.GOLD)
    return out


ICONS = {
    "warmup": warmup, "tea": tea, "pickles": pickles, "snack": snack, "rinse": rinse, "paper": paper, "fire": fire, "mirror": mirror,
    "phone": phone, "clock": clock, "piano": piano, "gargle": gargle, "bath": bath, "radiator": radiator, "dress": dress, "nap": nap,
    "feed_beryl": feed_beryl, "roses": roses, "marrow": marrow, "stroll": stroll, "polish": polish, "cloak": cloak,
    "answer_door": answer_door, "host_tea": host_tea, "tango": tango, "rehearse": rehearse, "hunt": hunt,
    "fixup_dry": fixup_dry, "fixup_sink": fixup_sink, "fixup_honey": fixup_honey, "fixup_mirror": fixup_mirror,
    "curious": curious, "herd_beryl": herd_beryl, "search": search,
}


def build(reg):
    for name, fn in ICONS.items():
        cv = Canvas()
        cv.add(fit(fn(), 4, 4, N - 4, N - 4))
        reduce_palette([cv], 10)
        p = os.path.join(OUT, name + ".svg")
        write(p, cv.svg(0, 0, N, N))
        WRITTEN.append((p, "icons"))
