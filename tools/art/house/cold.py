"""cold - the sets of the Nights' 5-second cold opens (GDD §1.1, §7.2; s2-ftue §4.4 stages them) and their layout
file game/data/house/cold_sets.json.

Screen space: every set is composed on the 2400 x 1080 logical 20:9 frame (top-left 0, 0); the action stays inside
the central 1920 px (x 240 ... 2160) so a 16:9 phone loses nothing. Actors (the real rigs) stand at the `anchors`
and draw between the layers with z <= 0 (behind them) and z >= 2 (in front of them, e.g. the window sill over his
belly); layers with `states` swap art on a timeline `state` event.

N01 "Throat Tea" (dawn): Bellows sings scales through a megaphone out of No. 7's upstairs window; the window of
    No. 9 (Hush's, lilac clapboard, Breton-striped curtains drawn) cracks; the sparrows on her gutter scatter.
N02 "Something Fishy" (day): on No. 7's doorstep he pops a child's balloon (the string runs in from off-frame
    right) with his conductor's baton and drops the string in the CONFISCATED box; his railings carry a
    "no balloons" enamel sign.

Files: game/art/house/cold/<set>_bg.svg (full frame, gradients allowed: sky/glows), <set>_fg.svg (set piece drawn
over the actors), and state sprites (props rules: <= 10 colours, 5 px ink, 3 px margin).
"""
import json
import math
import os

import lettering
import pal
from draw import blob, box, oval, shadow, shape, sparkle
from props_base import ART, REPO, RES, WRITTEN
from svgk import INK, PB, Canvas, Grad, circle, ellipse, lift, mix, mul, path, rect, reduce_palette, write

FW, FH = 2400, 1080
OUT = os.path.join(ART, "cold")
DATA = os.path.join(REPO, "game", "data", "house", "cold_sets.json")
A = pal.ARCH
AOP = 0.8
S = 5.0          # sprite silhouette ink
D = 3.0          # sprite detail ink

BRICK7 = ("#C47A62", "#A8624E", "#D99A82")      # No. 7: warm terracotta brick
STUCCO = ("#F1E6D4", "#D8C9B2", "#FFFFFF")       # No. 7: cream stucco trims
LILAC9 = ("#B7B4E0", "#9C98CC", "#DAD8F4")       # No. 9: lilac clapboard (as seen past the porch)
SLATE = ("#6E6680", "#57506C", "#8A8298")
DARK_ROOM = "#3A2F4A"
CURTAIN7 = ("#9A3548", "#7A2436", "#B9566A")     # his drapes (stage-velvet family, not his plum)
PINK_BAL = pal.PINK                               # the child's balloon


def _clean():
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            if f.endswith(".svg"):
                os.unlink(os.path.join(OUT, f))


def _write(name, cv, x0, y0, w, h, sprite):
    if sprite:
        reduce_palette([cv], 10)
    p = os.path.join(OUT, name + ".svg")
    write(p, cv.svg(x0, y0, w, h))
    WRITTEN.append((p, "cold"))
    return "%s/cold/%s.svg" % (RES, name)


def _sprite(name, items, margin=8):
    """A state sprite: tight canvas (>= 3 px margin). Returns (res path, [x, y] top-left, [w, h])."""
    cv = Canvas()
    cv.add(items)
    bb = cv.bbox()
    x0, y0 = math.floor(bb[0] - margin), math.floor(bb[1] - margin)
    w, h = math.ceil(bb[2] + margin) - x0, math.ceil(bb[3] + margin) - y0
    return _write(name, cv, x0, y0, w, h, True), [x0, y0], [w, h]


def _sprite_box(name, items, box_):
    """A state sprite on a fixed canvas (so every state of a layer shares one top-left + size)."""
    cv = Canvas()
    cv.add(items)
    x0, y0, w, h = box_
    return _write(name, cv, x0, y0, w, h, True), [x0, y0], [w, h]


def aline(pb, sw=3.0, op=AOP, col=A):
    return path(pb, fill="none", sw=sw, stroke=col, sop=op, sil=False)


def arect(x, y, w, h, r, fill, sw=3.0):
    return [rect(x, y, w, h, r, fill=fill, sil=False), rect(x, y, w, h, r, fill="none", sw=sw, stroke=A, sop=AOP, sil=False)]


def bricks(x0, x1, y0, y1, col, course=26, length=70, sw=2.0):
    """Brick courses aligned to a global grid (so a patch redrawn in the fg lines up with the bg)."""
    pb = PB()
    r0 = int(math.floor(y0 / course))
    r1 = int(math.ceil(y1 / course))
    for r in range(r0, r1 + 1):
        y = r * course
        if y0 <= y <= y1:
            pb.M(x0, y).L(x1, y)
        off = 0 if r % 2 == 0 else length / 2.0
        k0 = int(math.floor((x0 - off) / length))
        k1 = int(math.ceil((x1 - off) / length))
        for k in range(k0, k1 + 1):
            x = off + k * length
            if x0 < x < x1:
                ya, yb = max(y, y0), min(y + course, y1)
                if yb > ya:
                    pb.M(x, ya).L(x, yb)
    return path(pb, fill="none", sw=sw, stroke=col, sil=False)


def clap(x0, x1, y0, y1, col, step=34):
    pb = PB()
    y = y0 + step
    while y < y1:
        pb.M(x0, y).L(x1, y)
        y += step
    return path(pb, fill="none", sw=2.5, stroke=col, sil=False)


def cloud(cx, cy, s, col, fop=None):
    pb = PB().ellipse(cx, cy, 70 * s, 24 * s).ellipse(cx - 46 * s, cy + 5 * s, 40 * s, 20 * s).ellipse(cx + 50 * s, cy + 7 * s, 34 * s, 18 * s)
    pb.ellipse(cx - 8 * s, cy - 18 * s, 38 * s, 24 * s)
    return path(pb, fill=col, fop=fop, sil=False)


def digit_plaque(ch, cx, cy, h, plate, ink_col=A):
    """A plaque with a Lilita One numeral (letters are shapes, STYLE §1)."""
    out = arect(cx - h * 0.42, cy - h * 0.5, h * 0.84, h, h * 0.14, plate[0], 3.0)
    pb, _ = lettering.word(ch, cy + h * 0.3, h * 0.6, cx=cx)
    out.append(path(pb, fill=ink_col, sil=False))
    return out


# =============================================================================== N01 — dawn, the megaphone
N1_WIN7 = (640, 350, 1000, 700)          # No. 7 upstairs window opening: x0, y_top, x1, sill_top
N1_FEET = (812, 796)                     # Bellows' feet (his upstairs floor behind the wall)
N1_FG = (560, 680, 1080, 912)            # the sill + wall patch drawn over him: x0, y0, x1, y1
N1_WIN9 = (1700, 380, 1960, 650)         # No. 9 upstairs window: x0, y0, x1, y1
N1_GUTTER9 = 262


def dawn(col, t=0.14):
    return mix(col, "#8A76B8", t)


def n1_no7_lower(cv, region):
    """The wall under No. 7's open window + the heavy stucco sill with brackets. Drawn in the bg and again (cropped
    to `region`) as the fg so it covers his belly and legs exactly where the bg shows the same wall."""
    rx0, ry0, rx1, ry1 = region
    wx0, wy0, wx1, sill = N1_WIN7
    b = [dawn(c) for c in BRICK7]
    cv.add(rect(rx0, ry0, rx1 - rx0, ry1 - ry0, fill=b[0], sil=False))
    cv.add(bricks(rx0, rx1, ry0, ry1, b[1]))
    # the string course (his upstairs floor line) crossing the facade
    sc = [dawn(c) for c in STUCCO]
    cv.add(arect(rx0 - 20, 868, rx1 - rx0 + 40, 30, 0, sc[1]))
    cv.add(rect(rx0 - 20, 868, rx1 - rx0 + 40, 8, fill=sc[0], sil=False))
    # the sill: a deep stucco ledge with a lit top, two scroll brackets
    cv.add(arect(wx0 - 44, sill - 6, wx1 - wx0 + 88, 34, 6, sc[1], 3.5))
    cv.add(rect(wx0 - 40, sill - 4, wx1 - wx0 + 80, 12, 4, fill=sc[0], sil=False))
    cv.add(rect(wx0 - 30, sill - 1, 120, 4, 2, fill="#FFFFFF", fop=0.6, sil=False))
    for bx in (wx0 - 10, wx1 + 10):
        br = PB().M(bx - 18, sill + 28).L(bx + 18, sill + 28).L(bx + 12, sill + 62).Q(bx, sill + 86, bx - 12, sill + 62).Z()
        cv.add(path(br, fill=sc[1], sil=False), aline(br, 3.0))
        cv.add(circle(bx, sill + 60, 7, fill=sc[0], sw=2.5, stroke=A, sop=AOP, sil=False))
    # a panel of stucco under the window (apron) with a carved lyre - he is a Singer
    cv.add(arect(wx0 + 20, sill + 40, wx1 - wx0 - 40, 110, 8, sc[0], 3.0))
    ly = sill + 95
    lyre = PB().M(wx0 + (wx1 - wx0) / 2 - 26, ly + 30).Q(wx0 + (wx1 - wx0) / 2 - 40, ly - 16, wx0 + (wx1 - wx0) / 2 - 18, ly - 32)
    lyre.M(wx0 + (wx1 - wx0) / 2 + 26, ly + 30).Q(wx0 + (wx1 - wx0) / 2 + 40, ly - 16, wx0 + (wx1 - wx0) / 2 + 18, ly - 32)
    lyre.M(wx0 + (wx1 - wx0) / 2 - 26, ly + 30).L(wx0 + (wx1 - wx0) / 2 + 26, ly + 30)
    for k in (-10, 0, 10):
        lyre.M(wx0 + (wx1 - wx0) / 2 + k, ly - 18).L(wx0 + (wx1 - wx0) / 2 + k, ly + 28)
    cv.add(aline(lyre, 3.5, 0.55))


def n1_bg():
    cv = Canvas()
    # dawn sky: lavender -> rose -> apricot at the (hidden) horizon
    g = cv.grad(Grad("n1_sky", "linear", (0, 0, 0, 900), [(0, "#6F79C4", None), (0.45, "#D99BC0", None), (0.8, "#FFC9A0", None), (1, "#FFE2A8", None)]))
    cv.add(rect(0, 0, FW, FH, fill=g.url(), sil=False))
    # the sun coming up between the houses, with a soft glow
    sg = cv.grad(Grad("n1_sun", "radial", (1380, 170, 520), [(0, "#FFF4C0", 0.95), (0.22, "#FFE08A", 0.6), (1, "#FFC080", 0.0)]))
    cv.add(circle(1380, 170, 520, fill=sg.url(), sil=False))
    rays = PB()
    for k in range(12):
        a0 = math.radians(k * 30 - 4)
        a1 = math.radians(k * 30 + 4)
        rays.M(1380 + 140 * math.cos(a0), 170 + 140 * math.sin(a0)).L(1380 + 330 * math.cos(a0), 170 + 330 * math.sin(a0))
        rays.L(1380 + 330 * math.cos(a1), 170 + 330 * math.sin(a1)).L(1380 + 140 * math.cos(a1), 170 + 140 * math.sin(a1)).Z()
    cv.add(path(rays, fill="#FFF1C0", fop=0.35, sil=False))
    cv.add(circle(1380, 170, 112, fill="#FFE9A6", sil=False))
    cv.add(circle(1380, 170, 112, fill="none", sw=4, stroke="#FFB870", sop=0.8, sil=False))
    for cx, cy, s in ((420, 120, 1.3), (1900, 90, 1.0), (2250, 200, 0.8), (1250, 250, 0.7)):
        cv.add(cloud(cx, cy, s, "#F7C6D6", 0.85))
    # the far street: soft violet rooftops and chimneys, a church spire (the town wakes up)
    far = PB().M(1240, 1080).L(1240, 640).L(1290, 640).L(1290, 610).L(1306, 610).L(1306, 640).L(1340, 640).L(1372, 600).L(1404, 640)
    far.L(1440, 640).L(1440, 1080).Z()
    cv.add(path(far, fill="#9A86BE", sil=False))
    cv.add(path(PB().M(1352, 604).L(1362, 520).L(1372, 604).Z(), fill="#9A86BE", sil=False))
    # --- No. 9 (right): lilac clapboard, slate roof, gutter, her window's surround + flower box (the window
    # itself is the `window_no9` layer), the cherry front door below
    l9 = [dawn(c, 0.1) for c in LILAC9]
    x9 = 1440
    roof9 = PB().M(x9 - 10, N1_GUTTER9).L(x9 + 60, 140).L(FW + 20, 140).L(FW + 20, N1_GUTTER9).Z()
    cv.add(path(roof9, fill=dawn(SLATE[0]), sil=False), aline(roof9, 3.5))
    sl = PB()
    for k in range(1, 4):
        yy = 140 + k * 30
        sl.M(x9 + 60 - k * 17, yy).L(FW, yy)
    cv.add(aline(sl, 2.5, 0.5))
    cv.add(arect(2110, 70, 70, 80, 4, dawn(pal.BRICK)))
    cv.add(arect(2100, 58, 90, 18, 4, dawn(pal.BRICK_SH)))
    for px in (2122, 2158):
        cv.add(arect(px - 8, 36, 16, 26, 3, dawn("#C86A4A")))
    cv.add(rect(x9, N1_GUTTER9, FW - x9 + 20, FH - N1_GUTTER9, fill=l9[0], sil=False))
    cv.add(clap(x9, FW, N1_GUTTER9, FH, l9[1]))
    cv.add(rect(x9, N1_GUTTER9, 22, FH - N1_GUTTER9, fill=l9[1], sil=False))
    cv.add(aline(PB().M(x9, N1_GUTTER9).L(x9, FH), 3.0))
    cv.add(arect(x9 - 12, N1_GUTTER9 - 12, FW - x9 + 30, 18, 6, dawn("#8E8AB8")))
    wx0, wy0, wx1, wy1 = N1_WIN9
    cv.add(arect(wx0 - 26, wy0 - 30, wx1 - wx0 + 52, 22, 5, "#F7F4FF"))
    cv.add(arect(wx0 - 30, wy1 + 4, wx1 - wx0 + 60, 18, 4, "#F7F4FF"))
    cv.add(arect(wx0 - 22, wy1 + 22, wx1 - wx0 + 44, 36, 6, dawn("#8E6A4E")))
    fl = PB()
    lv = PB()
    for fx in range(wx0 - 12, wx1 + 16, 26):
        fl.circle(fx, wy1 + 16, 12)
        lv.ellipse(fx + 13, wy1 + 20, 9, 6)
    cv.add(path(lv, fill=dawn("#6BBF59"), sil=False))
    cv.add(path(fl, fill=dawn("#E2566A", 0.08), sil=False), aline(fl, 2.5, 0.7))
    # her door (cherry, a brass 9) peeking at the bottom right
    cv.add(arect(1960, 930, 200, 200, 10, "#F7F4FF"))
    cv.add(arect(1978, 948, 164, 200, 8, dawn(pal.BERET, 0.12)))
    cv.add(digit_plaque("9", 2060, 990, 40, (pal.GOLD, pal.GOLD_SH, pal.GOLD_LT)))
    cv.add(arect(1620, 930, 220, 160, 6, "#F7F4FF"))
    cv.add(rect(1636, 946, 188, 140, 4, fill=dawn("#CFE9F6", 0.25), sil=False))
    # --- the street lamp in the gap, still lit at dawn
    cv.add(arect(1360, 690, 20, 400, 6, dawn("#3E4A6A")))
    cv.add(arect(1344, 650, 52, 46, 10, dawn("#3E4A6A")))
    lg = cv.grad(Grad("n1_lamp", "radial", (1370, 672, 120), [(0, "#FFF2B8", 0.7), (1, "#FFF2B8", 0.0)]))
    cv.add(circle(1370, 672, 120, fill=lg.url(), sil=False))
    cv.add(arect(1354, 658, 32, 28, 6, "#FFE9A0"))
    # --- No. 7 (left): terracotta brick, stucco quoins + cornice, slate roof with two chimneys, a drainpipe
    b7 = [dawn(c) for c in BRICK7]
    sc = [dawn(c) for c in STUCCO]
    x7 = 1300
    roof7 = PB().M(-20, 170).L(-20, 70).L(x7 - 60, 70).L(x7 + 10, 170).Z()
    cv.add(path(roof7, fill=dawn(SLATE[0]), sil=False), aline(roof7, 3.5))
    sl7 = PB()
    for k in range(1, 4):
        sl7.M(-20, 70 + k * 25).L(x7 - 60 + k * 17, 70 + k * 25)
    cv.add(aline(sl7, 2.5, 0.5))
    for chx in (260, 1060):
        cv.add(arect(chx - 40, 0, 80, 80, 4, dawn(pal.BRICK)))
        cv.add(arect(chx - 50, 0, 100, 16, 4, dawn(pal.BRICK_SH)))
        for px in (chx - 18, chx + 18):
            cv.add(arect(px - 9, -8, 18, 16, 3, dawn("#C86A4A")))
    cv.add(rect(-20, 170, x7 + 20, FH - 170, fill=b7[0], sil=False))
    cv.add(bricks(-20, x7, 196, FH, b7[1]))
    cv.add(arect(-24, 160, x7 + 44, 38, 4, sc[1], 3.5))
    cv.add(rect(-20, 162, x7 + 36, 14, fill=sc[0], sil=False))
    dent = PB()
    for x in range(10, x7, 34):
        dent.rrect(x, 184, 18, 12, 2)
    cv.add(path(dent, fill=sc[0], sil=False))
    for qy in range(210, FH, 64):
        cv.add(arect(x7 - 56, qy, 56, 52, 3, sc[0], 2.5))
    cv.add(arect(x7 - 6, 176, 22, FH - 176, 8, dawn("#5A5470")))
    for yy in (300, 620, 940):
        cv.add(arect(x7 - 12, yy, 34, 16, 4, dawn("#4A4460")))
    # the second (closed) upstairs window, curtains drawn - he is the only one up
    cv.add(arect(150, 360, 290, 330, 8, sc[0], 3.5))
    cv.add(rect(170, 380, 250, 290, 4, fill=dawn("#8E7EA8"), sil=False))
    cv.add(path(PB().M(170, 380).L(295, 380).Q(260, 520, 290, 670).L(170, 670).Z().M(420, 380).L(295, 380).Q(330, 520, 300, 670).L(420, 670).Z(),
                fill=dawn(CURTAIN7[1], 0.2), sil=False))
    cv.add(aline(PB().M(295, 380).L(295, 670), 2.5, 0.6))
    cv.add(arect(130, 672, 330, 26, 5, sc[1], 3.0))
    # his open window: stucco surround + pediment, the shoved-up sash (double frame at the top), the dark room,
    # velvet drapes tied back
    wx0, wy0, wx1, sill = N1_WIN7
    cv.add(arect(wx0 - 36, wy0 - 36, wx1 - wx0 + 72, sill - wy0 + 36, 8, sc[0], 3.5))
    ped = PB().M(wx0 - 60, wy0 - 34).L((wx0 + wx1) / 2, wy0 - 120).L(wx1 + 60, wy0 - 34).Z()
    cv.add(path(ped, fill=sc[1], sil=False), aline(ped, 3.5))
    cv.add(path(PB().M(wx0 - 30, wy0 - 44).L((wx0 + wx1) / 2, wy0 - 108).L(wx1 + 30, wy0 - 44).Z(), fill=sc[0], sil=False))
    cv.add(ellipse((wx0 + wx1) / 2, wy0 - 66, 22, 16, fill=dawn(pal.GOLD), sw=3, stroke=A, sop=AOP, sil=False))
    cv.add(rect(wx0, wy0, wx1 - wx0, sill - wy0, fill=DARK_ROOM, sil=False))
    # a glow from inside (his lamp): he has been up for hours
    ig = cv.grad(Grad("n1_room", "radial", ((wx0 + wx1) / 2, wy0 + 60, 260), [(0, "#7A5A8A", 0.8), (1, DARK_ROOM, 0.0)]))
    cv.add(rect(wx0, wy0, wx1 - wx0, sill - wy0, fill=ig.url(), sil=False))
    for side in (0, 1):
        cx0 = wx0 if side == 0 else wx1
        sgn = 1 if side == 0 else -1
        dr = PB().M(cx0, wy0).L(cx0 + sgn * 70, wy0).Q(cx0 + sgn * 24, wy0 + 150, cx0 + sgn * 34, sill).L(cx0, sill).Z()
        cv.add(path(dr, fill=CURTAIN7[0], sil=False), aline(dr, 3.0))
        cv.add(path(PB().M(cx0 + sgn * 20, wy0 + 10).Q(cx0 + sgn * 10, wy0 + 150, cx0 + sgn * 14, sill - 6), fill="none", sw=3, stroke=CURTAIN7[1],
                    sil=False))
        cv.add(ellipse(cx0 + sgn * 24, wy0 + 170, 16, 8, fill=dawn(pal.GOLD), sw=2.5, stroke=A, sop=AOP, sil=False))
    # the two sashes stacked at the top (lower one shoved up behind the upper): a double frame + glints
    fr = "#FFFBF2"
    for (yy, hh) in ((wy0, 98), (wy0 + 12, 98)):
        cv.add(arect(wx0 + 6, yy, wx1 - wx0 - 12, hh, 4, "none" if yy > wy0 else fr, 3.0))
    cv.add(rect(wx0 + 18, wy0 + 12, wx1 - wx0 - 36, 74, 2, fill=dawn("#CFE9F6", 0.3), sil=False))
    cv.add(aline(PB().M((wx0 + wx1) / 2, wy0 + 12).L((wx0 + wx1) / 2, wy0 + 86), 3.0))
    cv.add(arect(wx0 + 6, wy0 + 96, wx1 - wx0 - 12, 16, 3, fr, 3.0))
    cv.add(path(PB().M(wx0 + 40, wy0 + 20).L(wx0 + 70, wy0 + 20).L(wx0 + 50, wy0 + 80).L(wx0 + 30, wy0 + 80).Z(), fill="#FFFFFF", fop=0.5, sil=False))
    # the wall + sill below the window (the same drawing the fg repeats over him)
    n1_no7_lower(cv, (wx0 - 80, sill - 10, wx1 + 80, 912))
    # ground floor tops at the frame bottom: his fanlit front door and a ground-floor window
    cv.add(arect(150, 916, 280, 200, 10, sc[0], 3.5))
    fan = PB().M(180, 1012).Q(180, 944, 290, 944).Q(400, 944, 400, 1012).Z()
    cv.add(path(fan, fill=dawn("#CFE9F6", 0.3), sil=False), aline(fan, 3.0))
    spk = PB()
    for k in range(5):
        a = math.radians(180 + 22.5 + k * 33.75)
        spk.M(290, 1012).L(290 + 100 * math.cos(a), 1012 + 62 * math.sin(a))
    cv.add(aline(spk, 2.5, 0.6))
    cv.add(arect(176, 1016, 228, 90, 4, dawn("#2F5A48")))
    cv.add(digit_plaque("7", 290, 986, 40, (pal.GOLD, pal.GOLD_SH, pal.GOLD_LT)))
    cv.add(arect(640, 930, 360, 180, 8, sc[0], 3.5))
    cv.add(rect(660, 950, 320, 160, 4, fill=dawn("#8E7EA8"), sil=False))
    return _write("n01_bg", cv, 0, 0, FW, FH, False)


def n1_fg():
    cv = Canvas()
    n1_no7_lower(cv, N1_FG)
    x0, y0, x1, y1 = N1_FG
    return _write("n01_sill_fg", cv, x0, y0, x1 - x0, y1 - y0, False), [x0, y0], [x1 - x0, y1 - y0]


def n1_window9(cracked):
    """No. 9's upstairs window: white frame, glass, Breton-striped curtains drawn (she is asleep). `cracked`: a star
    crack from where his top note hits, a shard knocked out, a glint of the pieces."""
    wx0, wy0, wx1, wy1 = N1_WIN9
    cx, cy = (wx0 + wx1) / 2, (wy0 + wy1) / 2
    out = []
    out += box(wx0 - 14, wy0 - 14, wx1 - wx0 + 28, wy1 - wy0 + 28, 8, ("#FFFFFF", "#DAD8F4", "#FFFFFF"), S, hi=False)
    out.append(rect(wx0, wy0, wx1 - wx0, wy1 - wy0, 4, fill="#CFE9F6"))
    # curtains drawn: two panels meeting in the middle, navy stripes
    for side in (0, 1):
        px0 = wx0 + 4 if side == 0 else cx + 2
        px1 = cx - 2 if side == 0 else wx1 - 4
        out.append(rect(px0, wy0 + 4, px1 - px0, wy1 - wy0 - 8, 3, fill="#E4E7F6", sil=False))
        st = PB()
        y = wy0 + 26
        while y < wy1 - 10:
            st.M(px0 + 3, y).L(px1 - 3, y)
            y += 34
        out.append(path(st, fill="none", sw=10, stroke="#2B3566", sil=False))
        out.append(path(PB().M(px0 + (px1 - px0) * 0.5, wy0 + 8).L(px0 + (px1 - px0) * 0.5, wy1 - 8), fill="none", sw=D, stroke=INK, sop=0.35, sil=False))
    out.append(rect(wx0, wy0, wx1 - wx0, 18, 3, fill="#8E8AB8", sil=False))
    out.append(rect(wx0, wy0, wx1 - wx0, wy1 - wy0, 4, fill="#9FD2E3", fop=0.35, sil=False))
    # the glass over the curtains: the glazing bar + a pane glint
    out.append(path(PB().M(wx0, cy).L(wx1, cy).M(cx, wy0).L(cx, wy1), fill="none", sw=8, stroke="#FFFFFF", sil=False))
    out.append(path(PB().M(wx0, cy).L(wx1, cy).M(cx, wy0).L(cx, wy1), fill="none", sw=D, stroke=INK, sop=0.7, sil=False))
    out.append(path(PB().M(wx0 + 14, wy0 + 26).L(wx0 + 44, wy0 + 26).L(wx0 + 24, wy0 + 110).L(wx0 + 8, wy0 + 110).Z(), fill="#FFFFFF", fop=0.55, sil=False))
    out.append(rect(wx0, wy0, wx1 - wx0, wy1 - wy0, 4, fill="none", sw=S, stroke=INK))
    if cracked:
        hx, hy = wx0 + 190, wy0 + 76          # the impact: upper-right pane
        hole = [(hx - 16, hy - 10), (hx + 2, hy - 20), (hx + 18, hy - 6), (hx + 12, hy + 14), (hx - 8, hy + 16)]
        out.append(path(PB().poly(hole), fill="#241D33", sil=False))
        out.append(path(PB().poly(hole), fill="none", sw=D, stroke=INK, sil=False))
        cr = PB()
        for ang, ln in ((-160, 150), (-120, 80), (-70, 60), (-20, 70), (30, 90), (80, 150), (130, 170), (200, 110)):
            a = math.radians(ang)
            mx = hx + ln * 0.5 * math.cos(a) + 8 * math.sin(a)
            my = hy + ln * 0.5 * math.sin(a) - 8 * math.cos(a)
            ex = max(wx0 + 4, min(wx1 - 4, hx + ln * math.cos(a)))
            ey = max(wy0 + 4, min(wy1 - 4, hy + ln * math.sin(a)))
            cr.M(hx, hy).L(mx, my).L(ex, ey)
        out.append(path(cr, fill="none", sw=10, stroke=INK, sil=False))
        out.append(path(cr, fill="none", sw=4.5, stroke="#FFFFFF", sil=False))
        ring = PB()
        for r in (38, 70):
            pts = []
            for k in range(9):
                a = math.radians(-180 + k * 45)
                pts.append((hx + r * math.cos(a) * (1 + 0.1 * (k % 2)), hy + r * math.sin(a) * (1 + 0.1 * (k % 2))))
            ring.M(*pts[0])
            for p in pts[1:]:
                ring.L(*p)
        out.append(path(ring, fill="none", sw=7, stroke=INK, sil=False))
        out.append(path(ring, fill="none", sw=3, stroke="#FFFFFF", sil=False))
        # shards falling out of the frame
        for (sx, sy, s) in ((hx + 14, wy1 + 44, 1.0), (hx - 30, wy1 + 70, 0.8), (hx + 44, wy1 + 86, 0.7)):
            out += shape([(sx, sy), (sx + 24 * s, sy + 10 * s), (sx + 6 * s, sy + 28 * s)], "#CFE9F6", D)
        out += sparkle(hx - 40, hy - 44, 14)
        out += sparkle(wx1 + 36, wy0 + 20, 11)
    else:
        # she is asleep: three Zs (Lilita One shapes) drifting up from the window
        for (zx, zy, zh) in ((wx1 + 26, wy0 + 30, 34), (wx1 + 58, wy0 - 16, 44), (wx1 + 98, wy0 - 70, 54)):
            pb, _ = lettering.word("Z", zy, zh, cx=zx)
            out.append(path(pb, fill="#FFFFFF", sw=5, stroke=INK))
    return out


def n1_birds(flown):
    """Three sparrows on No. 9's gutter; `flown`: flapping up and away, feathers drifting."""
    col = ("#B98A6A", "#9A6E52", "#E7C9A8")
    out = []
    if not flown:
        for bx in (1740, 1830, 1905):
            by = N1_GUTTER9 - 18
            out += oval(bx, by, 22, 17, col, D, hi=False)
            out.append(circle(bx + 14, by - 14, 11, fill=col[0], sw=D, stroke=INK))
            out.append(path(PB().poly([(bx + 24, by - 16), (bx + 34, by - 12), (bx + 24, by - 9)]), fill=pal.GOLD, sw=2.5, stroke=INK))
            out.append(circle(bx + 16, by - 17, 2.6, fill=INK, sil=False))
            out.append(path(PB().M(bx - 20, by - 2).L(bx - 34, by - 10), fill="none", sw=D, stroke=INK))
    else:
        for bx, by, s in ((1700, 150, 1.0), (1860, 110, 0.9), (1990, 170, 1.05)):
            out += oval(bx, by, 20 * s, 14 * s, col, D, hi=False)
            for sgn in (-1, 1):
                wing = PB().M(bx - 6 * s, by - 4 * s).Q(bx + sgn * 10 * s, by - 44 * s, bx + sgn * 34 * s, by - 34 * s).Q(bx + sgn * 14 * s, by - 14 * s, bx + 6 * s, by - 4 * s).Z()
                out.append(path(wing, fill=col[1], sw=D, stroke=INK))
            out.append(circle(bx + 16 * s, by - 6 * s, 9 * s, fill=col[0], sw=D, stroke=INK))
            out.append(path(PB().M(bx - 36 * s, by + 18 * s).L(bx - 54 * s, by + 26 * s).M(bx - 30 * s, by + 30 * s).L(bx - 46 * s, by + 40 * s), fill="none",
                            sw=D, stroke=INK, sil=False))
        for fx, fy in ((1780, 230), (1930, 250)):
            out.append(path(PB().M(fx, fy).Q(fx + 10, fy - 8, fx + 18, fy + 2).Q(fx + 8, fy + 6, fx, fy).Z(), fill=col[2], sw=2.5, stroke=INK))
    return out


def n01():
    bg = n1_bg()
    fg, fpos, fsize = n1_fg()
    wbox = (N1_WIN9[0] - 30, N1_WIN9[1] - 150, N1_WIN9[2] - N1_WIN9[0] + 190, N1_WIN9[3] - N1_WIN9[1] + 270)
    wi, wpos, wsize = _sprite_box("n01_window_no9", n1_window9(False), wbox)
    wc, _, _ = _sprite_box("n01_window_no9_cracked", n1_window9(True), wbox)
    bbox_ = (1640, 60, 420, 240)
    bp, bpos, bsize = _sprite_box("n01_birds", n1_birds(False), bbox_)
    bf, _, _ = _sprite_box("n01_birds_flown", n1_birds(True), bbox_)
    wx0, wy0, wx1, sill = N1_WIN7
    return {
        "episode": "n01_throat_tea",
        "time": "dawn",
        "size": [FW, FH],
        "safe": [240, 0, 1920, FH],
        "layers": [
            {"id": "bg", "art": bg, "pos": [0, 0], "size": [FW, FH], "z": -2},
            {"id": "window_no9", "art": wi, "pos": wpos, "size": wsize, "z": 0, "state": "intact"},
            {"id": "birds", "art": bp, "pos": bpos, "size": bsize, "z": 0, "state": "perched"},
            {"id": "sill_no7", "art": fg, "pos": fpos, "size": fsize, "z": 2},
        ],
        "anchors": {
            "bellows": list(N1_FEET),
            "bellows_face": [N1_FEET[0], N1_FEET[1] - 300],
            "megaphone_mouth": [N1_FEET[0] + 230, N1_FEET[1] - 250],
            "window_no7": [(wx0 + wx1) // 2, (wy0 + sill) // 2],
            "window_no9": [(N1_WIN9[0] + N1_WIN9[2]) // 2, (N1_WIN9[1] + N1_WIN9[3]) // 2],
            "crack": [N1_WIN9[0] + 190, N1_WIN9[1] + 76],
            "birds": [1830, N1_GUTTER9 - 20],
        },
        "actors": {"bellows": {"facing": 1, "scale": 1.0, "pose": "b_sing_big", "behind": "sill_no7"}},
        "states": {
            "window_no9": {"intact": wi, "cracked": wc},
            "birds": {"perched": bp, "flown": bf},
        },
    }


# =============================================================================== N02 — the balloon
N2_PAVE = 900                  # pavement line (his feet)
N2_DOOR = (380, 420, 620, 860)  # front door leaf: x0, y0, x1, y1 (the top step at 860)
N2_BOX = (648, 734, 808, 862)  # CONFISCATED box on the top step: x0, y0, x1, y1
N2_BALLOON = (1300, 455)       # balloon centre
N2_FEET = (1040, N2_PAVE)


def n2_bg():
    cv = Canvas()
    g = cv.grad(Grad("n2_sky", "linear", (0, 0, 0, 800), [(0, "#6FB8E0", None), (1, "#CDEBF8", None)]))
    cv.add(rect(0, 0, FW, FH, fill=g.url(), sil=False))
    for cx, cy, s in ((1500, 150, 1.2), (2050, 260, 0.9), (1180, 300, 0.6)):
        cv.add(cloud(cx, cy, s, "#FFFFFF", 0.9))
    # the far street over No. 9's hedge: soft rooftops
    far = PB().M(1250, 760).L(1250, 560).L(1330, 560).L(1370, 510).L(1410, 560).L(1560, 560).L(1560, 530).L(1580, 530).L(1580, 560).L(1700, 560).L(1700, 760).Z()
    cv.add(path(far, fill="#A8B8D8", sil=False))
    # --- No. 9 (right): lilac clapboard, a cherry door, window with Breton curtains, the hedge
    l9 = LILAC9
    cv.add(rect(1700, 120, FW - 1680, 790, fill=l9[0], sil=False))
    cv.add(clap(1700, FW, 120, 900, l9[1]))
    cv.add(rect(1700, 120, 22, 780, fill=l9[1], sil=False))
    cv.add(aline(PB().M(1700, 120).L(1700, N2_PAVE), 3.0))
    cv.add(arect(1690, 100, FW - 1670, 28, 6, "#8E8AB8"))
    cv.add(arect(1920, 440, 190, 440, 10, "#F7F4FF"))
    cv.add(arect(1938, 458, 154, 422, 8, pal.BERET))
    cv.add(circle(2066, 670, 9, fill=pal.GOLD, sw=3, stroke=A, sop=AOP, sil=False))
    cv.add(digit_plaque("9", 2015, 410, 44, (pal.GOLD, pal.GOLD_SH, pal.GOLD_LT)))
    cv.add(arect(2170, 300, 230, 280, 6, "#F7F4FF"))
    cv.add(rect(2186, 316, 214, 248, 4, fill="#CFE9F6", sil=False))
    st = PB()
    for i in range(6):
        st.M(2190, 336 + i * 40).L(2240 - abs(2.5 - i) * 8, 336 + i * 40)
    cv.add(path(st, fill="none", sw=9, stroke="#5A63A0", sil=False))
    # hedge in No. 9's front garden
    hcol = pal.HEDGE
    hedge = PB().M(1700, N2_PAVE).L(1700, 760).Q(1720, 700, 1780, 720).Q(1810, 680, 1860, 716).L(1860, N2_PAVE).Z()
    cv.add(path(hedge, fill=hcol, sil=False), aline(hedge, 3.0))
    # --- No. 7 (left): brick ground floor, stucco quoins, the fanlit front door, steps, railings, topiary, the
    # "no balloons" enamel sign on the railings
    b7, sc = BRICK7, STUCCO
    cv.add(rect(-20, 0, 1720, N2_PAVE, fill=b7[0], sil=False))
    cv.add(bricks(-20, 1700, 0, 900, b7[1]))
    for qy in range(0, 880, 64):
        cv.add(arect(1644, qy, 56, 52, 3, sc[0], 2.5))
    cv.add(arect(1690, 0, 22, 900, 8, "#5A5470"))
    cv.add(arect(-24, 180, 1730, 34, 0, sc[1], 3.0))
    cv.add(rect(-20, 182, 1720, 12, fill=sc[0], sil=False))
    # front door: stucco surround, fanlight with a gold 7, the door leaf (bottle green), brass knocker + letterbox
    dx0, dy0, dx1, dy1 = N2_DOOR
    cv.add(arect(dx0 - 50, dy0 - 130, dx1 - dx0 + 100, dy1 - dy0 + 130, 10, sc[0], 3.5))
    cv.add(arect(dx0 - 70, dy0 - 160, dx1 - dx0 + 140, 34, 6, sc[1], 3.5))
    fan = PB().M(dx0, dy0 - 10).Q(dx0, dy0 - 110, (dx0 + dx1) / 2, dy0 - 110).Q(dx1, dy0 - 110, dx1, dy0 - 10).Z()
    cv.add(path(fan, fill="#CFE9F6", sil=False), aline(fan, 3.0))
    spk = PB()
    for k in range(5):
        a = math.radians(180 + 22.5 + k * 33.75)
        spk.M((dx0 + dx1) / 2, dy0 - 10).L((dx0 + dx1) / 2 + 118 * math.cos(a), dy0 - 10 + 98 * math.sin(a))
    cv.add(aline(spk, 2.5, 0.6))
    cv.add(digit_plaque("7", (dx0 + dx1) / 2, dy0 - 48, 50, (pal.GOLD, pal.GOLD_SH, pal.GOLD_LT)))
    cv.add(arect(dx0, dy0, dx1 - dx0, dy1 - dy0, 8, "#2F5A48", 3.5))
    cv.add(rect(dx0 + 8, dy0 + 8, dx1 - dx0 - 40, dy1 - dy0 - 16, 6, fill="#3C6E58", sil=False))
    for (px, py, pw, ph) in ((dx0 + 26, dy0 + 30, 80, 150), (dx1 - 106, dy0 + 30, 80, 150), (dx0 + 26, dy0 + 220, 80, 170), (dx1 - 106, dy0 + 220, 80, 170)):
        cv.add(arect(px, py, pw, ph, 6, "#356350", 2.5))
    cv.add(circle((dx0 + dx1) / 2, dy0 + 210, 26, fill="none", sw=7, stroke=pal.GOLD, sil=False))
    cv.add(circle((dx0 + dx1) / 2, dy0 + 184, 12, fill=pal.GOLD, sw=3, stroke=A, sop=AOP, sil=False))
    cv.add(arect((dx0 + dx1) / 2 - 36, dy0 + 262, 72, 16, 4, pal.GOLD))
    cv.add(circle(dx1 - 30, dy0 + 240, 10, fill=pal.GOLD, sw=3, stroke=A, sop=AOP, sil=False))
    # two stone steps
    cv.add(arect(dx0 - 90, dy1, dx1 - dx0 + 340, 22, 5, pal.STONE))
    cv.add(arect(dx0 - 110, dy1 + 20, dx1 - dx0 + 380, 22, 5, pal.STONE_SH))
    cv.add(rect(dx0 - 86, dy1 + 2, dx1 - dx0 + 330, 6, 3, fill="#FFFFFF", fop=0.4, sil=False))
    # topiary balls in square pots either side of the door (pompous)
    for tx in (dx0 - 80,):
        cv.add(arect(tx - 34, dy1 - 70, 68, 70, 6, "#C86A4A"))
        cv.add(circle(tx, dy1 - 118, 52, fill=pal.GRASS[1], sil=False), circle(tx - 8, dy1 - 126, 42, fill=pal.GRASS[0], sil=False))
        cv.add(circle(tx, dy1 - 118, 52, fill="none", sw=3.5, stroke=A, sop=AOP, sil=False))
    # ground-floor sash window with a lace half-curtain
    cv.add(arect(900, 340, 380, 400, 8, sc[0], 3.5))
    cv.add(rect(920, 360, 340, 360, 4, fill="#CFE9F6", sil=False))
    cv.add(path(PB().M(930, 380).L(990, 380).L(950, 560).L(930, 560).Z(), fill="#FFFFFF", fop=0.5, sil=False))
    lace = PB().M(920, 560).L(1260, 560).L(1260, 720).L(920, 720).Z()
    cv.add(path(lace, fill="#FFFFFF", fop=0.85, sil=False))
    scal = PB().M(920, 560)
    for k in range(10):
        scal.Q(920 + k * 34 + 17, 578, 920 + (k + 1) * 34, 560)
    cv.add(aline(scal, 2.5, 0.6))
    cv.add(aline(PB().M(1090, 360).L(1090, 720).M(920, 540).L(1260, 540), 5.0, 0.8))
    cv.add(arect(880, 736, 420, 26, 5, sc[1], 3.0))
    # pavement + kerb + road edge
    cv.add(rect(-20, N2_PAVE, FW + 40, FH - N2_PAVE, fill=mix(pal.STONE, "#FFFFFF", 0.15), sil=False))
    slabs = PB()
    for x in range(40, FW, 150):
        slabs.M(x, N2_PAVE).L(x - 16, 1030)
    slabs.M(-20, 960).L(FW, 960)
    cv.add(path(slabs, fill="none", sw=2.5, stroke=pal.STONE_SH, sil=False))
    cv.add(rect(-20, 1030, FW + 40, 20, fill=pal.STONE_SH, sil=False))
    cv.add(rect(-20, 1050, FW + 40, 40, fill="#6A6A7A", sil=False))
    cv.add(aline(PB().M(-20, N2_PAVE).L(FW, N2_PAVE).M(-20, 1030).L(FW, 1030), 3.0))
    # iron railings along his front (spear tips), the "no balloons" sign hanging on them
    rail = PB()
    for x in range(1320, 1690, 34):
        rail.M(x, N2_PAVE).L(x, 700)
    rail.M(1310, 716).L(1700, 716).M(1310, 870).L(1700, 870)
    cv.add(path(rail, fill="none", sw=8, stroke="#2A2E44", sil=False))
    tips = PB()
    for x in range(1320, 1690, 34):
        tips.poly([(x - 7, 702), (x, 682), (x + 7, 702)])
    cv.add(path(tips, fill=pal.GOLD, sil=False), aline(tips, 2.5))
    sx, sy = 1500, 770
    cv.add(arect(sx - 64, sy - 64, 128, 128, 14, "#FFFFFF", 3.5))
    cv.add(circle(sx, sy, 48, fill="none", sw=10, stroke=pal.STAMP_RED, sil=False))
    bb = PB().ellipse(sx - 4, sy - 12, 18, 22)
    cv.add(path(bb, fill=PINK_BAL[0], sil=False), aline(bb, 2.5))
    cv.add(aline(PB().M(sx - 4, sy + 10).Q(sx + 6, sy + 22, sx - 2, sy + 34), 2.5))
    cv.add(path(PB().M(sx - 34, sy - 34).L(sx + 34, sy + 34), fill="none", sw=10, stroke=pal.STAMP_RED, sil=False))
    for hx in (sx - 40, sx + 40):
        cv.add(aline(PB().M(hx, sy - 64).L(hx, 716), 3.0))
    return _write("n02_bg", cv, 0, 0, FW, FH, False)


def n2_balloon(state):
    """The child's pink balloon on a string that runs in from off-frame right. `whole`; `popped` = rubber scraps
    flying out, the knot + a shred on a string that has gone slack."""
    bx, by = N2_BALLOON
    out = []
    if state == "whole":
        out.append(path(PB().M(bx + 4, by + 84).C(bx + 60, by + 240, 1900, 520, FW + 16, 800), fill="none", sw=3.5, stroke=INK, sil=False))
        out += blob([(bx, by + 76), (bx + 58, by + 20), (bx + 52, by - 44), (bx, by - 74), (bx - 52, by - 44), (bx - 58, by + 20)], PINK_BAL, S, k=0.82, hi=True)
        out.append(path(PB().poly([(bx - 10, by + 88), (bx + 12, by + 88), (bx + 1, by + 74)]), fill=PINK_BAL[1], sw=D, stroke=INK))
        out.append(ellipse(bx - 22, by - 30, 10, 18, fill="#FFFFFF", fop=0.7, sil=False))
    else:
        out.append(path(PB().M(bx + 4, by + 100).C(bx + 40, by + 330, 1900, 560, FW + 16, 800), fill="none", sw=3.5, stroke=INK, sil=False))
        out.append(path(PB().poly([(bx - 10, by + 104), (bx + 12, by + 104), (bx + 1, by + 90)]), fill=PINK_BAL[1], sw=D, stroke=INK))
        shred = [(bx - 16, by + 92), (bx - 4, by + 66), (bx + 10, by + 80), (bx + 20, by + 64), (bx + 22, by + 94)]
        out += shape(shred, PINK_BAL[0], D)
        for (sx, sy, ang, s) in ((bx - 90, by - 50, -30, 1.0), (bx + 80, by - 70, 25, 0.9), (bx - 60, by + 50, 200, 0.8), (bx + 96, by + 30, 150, 1.1),
                                 (bx + 10, by - 110, 90, 0.8)):
            a = math.radians(ang)
            pts = [(sx + math.cos(a + t) * r * s, sy + math.sin(a + t) * r * s) for t, r in ((0, 20), (1.9, 12), (2.8, 18), (4.2, 10), (5.2, 16))]
            out += shape(pts, PINK_BAL[0], D)
            ml = PB().M(sx - math.cos(a) * 30 * s, sy - math.sin(a) * 30 * s).L(sx - math.cos(a) * 46 * s, sy - math.sin(a) * 46 * s)
            out.append(path(ml, fill="none", sw=D, stroke=INK, sil=False))
        out += sparkle(bx, by - 20, 16)
    return out


def n2_box(with_string):
    """The CONFISCATED box on his top step (the same box as the hall's, flaps open); `string`: the popped balloon's
    string and knot flopped over the rim - confiscated."""
    x0, y0, x1, y1 = N2_BOX
    cx = (x0 + x1) / 2
    cb = pal.CARDBOARD
    out = [shadow(cx, y1 - 4, 90, 8)]
    out += shape([(x0 + 2, y0), (x0 - 34, y0 - 36), (x0 - 22, y0 - 48), (x0 + 32, y0 - 4)], cb[1], S)
    out += shape([(x1 - 2, y0), (x1 + 34, y0 - 36), (x1 + 22, y0 - 48), (x1 - 32, y0 - 4)], cb[1], S)
    if with_string:
        st = PB().M(cx - 20, y0 + 6).C(cx - 10, y0 - 60, cx + 60, y0 - 50, x1 + 40, y0 + 40).C(x1 + 60, y0 + 70, x1 + 40, y0 + 110, x1 + 70, y1 - 6)
        out.append(path(st, fill="none", sw=3.5, stroke=INK, sil=False))
        out.append(path(PB().poly([(cx - 34, y0 + 4), (cx - 8, y0 + 4), (cx - 21, y0 - 12)]), fill=PINK_BAL[1], sw=D, stroke=INK))
        out += shape([(cx - 40, y0 + 2), (cx - 30, y0 - 26), (cx - 18, y0 - 12), (cx - 6, y0 - 28), (cx - 2, y0 + 2)], PINK_BAL[0], D)
    out += box(x0, y0, x1 - x0, y1 - y0, 6, cb, S, hi=True)
    # the red CONFISCATED stamp, letters from Lilita One, tilted
    pb, w = lettering.word("CONFISCATED", 0, 16, x=0)
    sc = (x1 - x0 - 24) / w
    pb2, _ = lettering.word("CONFISCATED", y0 + 66, 16 * sc, cx=cx)
    from svgk import group
    out.append(group([rect(cx - (x1 - x0) / 2 + 8, y0 + 40, x1 - x0 - 16, 36, 4, fill="none", sw=3.5, stroke=pal.STAMP_RED, sil=False),
                      path(pb2, fill=pal.STAMP_RED, sil=False)], rot=-6, cx=cx, cy=y0 + 58, sil=False))
    return out


def n02():
    bg = n2_bg()
    bal_box = (1150, 240, FW + 26 - 1150, 640)
    bw, bpos, bsize = _sprite_box("n02_balloon", n2_balloon("whole"), bal_box)
    bp, _, _ = _sprite_box("n02_balloon_popped", n2_balloon("popped"), bal_box)
    bx_box = (N2_BOX[0] - 60, N2_BOX[1] - 80, N2_BOX[2] - N2_BOX[0] + 180, N2_BOX[3] - N2_BOX[1] + 100)
    xe, xpos, xsize = _sprite_box("n02_box", n2_box(False), bx_box)
    xs, _, _ = _sprite_box("n02_box_string", n2_box(True), bx_box)
    return {
        "episode": "n02_something_fishy",
        "time": "day",
        "size": [FW, FH],
        "safe": [240, 0, 1920, FH],
        "layers": [
            {"id": "bg", "art": bg, "pos": [0, 0], "size": [FW, FH], "z": -2},
            {"id": "box", "art": xe, "pos": xpos, "size": xsize, "z": 0, "state": "empty"},
            {"id": "balloon", "art": bw, "pos": bpos, "size": bsize, "z": 0, "state": "whole"},
        ],
        "anchors": {
            "bellows": list(N2_FEET),
            "bellows_face": [N2_FEET[0], N2_FEET[1] - 300],
            "balloon": list(N2_BALLOON),
            "string_in": [FW, 800],
            "box": [(N2_BOX[0] + N2_BOX[2]) // 2, N2_BOX[1]],
            "door": [(N2_DOOR[0] + N2_DOOR[2]) // 2, N2_DOOR[3]],
            "sign": [1500, 770],
        },
        "actors": {"bellows": {"facing": 1, "scale": 1.0, "pose": "b_lecture_wag_a"}},
        "states": {
            "balloon": {"whole": bw, "popped": bp, "none": ""},
            "box": {"empty": xe, "string": xs},
        },
    }


def build(reg=None):
    _clean()
    data = {"version": 1, "frame": [FW, FH], "sets": {"n01_throat_tea": n01(), "n02_something_fishy": n02()}}
    txt = json.dumps(data, indent=2, ensure_ascii=False)
    import re
    txt = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", txt)
    txt = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2, \3, \4]", txt)
    write(DATA, txt + "\n")
    return data
