"""stage - the theatre around the house (GDD §1.3, §9.1): curtain, valance, proscenium, apron with
footlight cups, footlight glow, flies (backstage above the set), cool top vignette, the velvet rope
for roped-off doorways, and the exterior set pieces (sky flats, the hall's lean-to roof, the main
roof). Gradients are allowed here (stage drapes, sky, glows - STYLE §1).

World placement is written into house.json["stage"] (the view reads it; see STYLE §8).
"""
import math
import os

import geo
import pal
from draw import ball, box, shape
from props_base import ART, RES, WRITTEN
from svgk import INK, PB, Canvas, Grad, circle, ellipse, lift, mix, mul, path, rect, write

A = pal.ARCH
WORLD_X0, WORLD_X1 = -220, 6420
WORLD_Y0, WORLD_Y1 = -1640, 250
UPPER_TOP = -1340


def _write(name, cv, ox, oy, w, h, kind="stage"):
    p = os.path.join(ART, "stage", name + ".svg")
    write(p, cv.svg(ox, oy, w, h))
    WRITTEN.append((p, kind))
    return "%s/stage/%s.svg" % (RES, name)


def aline(pb, sw=3.0, op=0.8, col=A):
    return path(pb, fill="none", sw=sw, stroke=col, sop=op, sil=False)


# =============================================================================== curtain
def velvet_folds(cv, x0, x1, y0, y1, period, gid, deep=False):
    """Vertical velvet folds: one gradient per fold, repeated (tileable when (x1-x0) % period == 0)."""
    g = cv.grad(Grad(gid, "linear", (0, 0, period, 0), [(0, pal.VELVET_DEEP, None), (0.18, pal.VELVET_SH, None), (0.45, pal.VELVET_LT, None),
                                                        (0.62, pal.VELVET, None), (0.86, pal.VELVET_SH, None), (1, pal.VELVET_DEEP, None)]))
    # userSpaceOnUse gradients do not repeat: emit one rect + gradient per fold instead
    x = x0
    i = 0
    while x < x1:
        gi = cv.grad(Grad("%s%d" % (gid, i), "linear", (x, 0, x + period, 0), g.stops))
        cv.add(rect(x, y0, period + 0.5, y1 - y0, fill=gi.url(), sil=False))
        x += period
        i += 1
    cv.grads.remove(g)


def curtain():
    cv = Canvas()
    W, H = 1920, 1080
    velvet_folds(cv, 0, W, 0, H, 160, "fold")
    # soft fold highlights (a thin sheen down each fold)
    sheen = PB()
    for i in range(12):
        x = i * 160 + 72
        sheen.M(x, 0).Q(x + 6, H * 0.5, x - 2, H - 80).L(x + 8, H - 80).Q(x + 16, H * 0.5, x + 10, 0).Z()
    cv.add(path(sheen, fill="#FFFFFF", fop=0.08, sil=False))
    # scalloped bottom hem + gold fringe band + a gold rope
    hem = PB().M(0, H - 96)
    for i in range(12):
        hem.Q(i * 160 + 80, H - 70, (i + 1) * 160, H - 96)
    hem.L(W, H).L(0, H).Z()
    cv.add(path(hem, fill=pal.VELVET_DEEP, sil=False))
    fr = PB()
    x = 0
    while x < W:
        fr.M(x + 4, H - 86).L(x + 4, H - 30)
        x += 12
    cv.add(path(fr, fill="none", sw=7, stroke=pal.GOLD, sil=False), path(fr, fill="none", sw=2, stroke=pal.GOLD_SH, sop=0.6, sil=False))
    rope = PB().M(0, H - 96)
    for i in range(12):
        rope.Q(i * 160 + 80, H - 70, (i + 1) * 160, H - 96)
    cv.add(path(rope, fill="none", sw=16, stroke=pal.GOLD_SH, sil=False), path(rope, fill="none", sw=9, stroke=pal.GOLD, sil=False),
           path(rope, fill="none", sw=3, stroke=pal.GOLD_LT, sil=False))
    for i in range(12):
        tx = i * 160 + 80
        cv.add(ellipse(tx, H - 72, 14, 10, fill=pal.GOLD, sw=3, stroke=pal.GOLD_SH, sil=False))
        cv.add(path(PB().M(tx - 12, H - 66).L(tx + 12, H - 66).L(tx + 16, H - 22).L(tx - 16, H - 22).Z(), fill=pal.GOLD, sw=3, stroke=pal.GOLD_SH,
                    sil=False))
    # darker bottom shadow (depth)
    g = cv.grad(Grad("cbot", "linear", (0, H - 260, 0, H), [(0, "#000000", 0.0), (1, "#1A0610", 0.35)]))
    cv.add(rect(0, H - 260, W, 260, fill=g.url(), sil=False))
    return _write("curtain", cv, 0, 0, W, H)


def valance():
    cv = Canvas()
    W, H = 1920, 260
    velvet_folds(cv, 0, W, 0, 150, 80, "vfold")
    sw = PB().M(0, 140)
    for i in range(6):
        sw.Q(i * 320 + 160, 250, (i + 1) * 320, 140)
    sw.L(W, 0).L(0, 0).Z()
    g = cv.grad(Grad("vswag", "linear", (0, 60, 0, 240), [(0, pal.VELVET, None), (0.7, pal.VELVET_SH, None), (1, pal.VELVET_DEEP, None)]))
    cv.add(path(sw, fill=g.url(), sil=False))
    folds = PB()
    for i in range(6):
        c = i * 320 + 160
        for k in (-80, -30, 30, 80):
            t = (k + 160) / 320.0
            yend = 140 + 220 * t * (1 - t) - 14
            folds.M(c + k * 1.4, 40).Q(c + k * 1.15, (40 + yend) / 2, c + k, yend)
    cv.add(path(folds, fill="none", sw=6, stroke=pal.VELVET_DEEP, sop=0.5, sil=False))
    fr_line = PB().M(0, 140)
    for i in range(6):
        fr_line.Q(i * 320 + 160, 250, (i + 1) * 320, 140)
    cv.add(path(fr_line, fill="none", sw=14, stroke=pal.GOLD_SH, sil=False), path(fr_line, fill="none", sw=8, stroke=pal.GOLD, sil=False))
    for i in range(7):
        tx = i * 320
        cv.add(ellipse(tx, 146, 16, 12, fill=pal.GOLD, sw=3, stroke=pal.GOLD_SH, sil=False))
        cv.add(path(PB().M(tx - 12, 156).L(tx + 12, 156).L(tx + 16, 222).L(tx - 16, 222).Z(), fill=pal.GOLD, sw=3, stroke=pal.GOLD_SH, sil=False))
    cv.add(rect(0, 0, W, 26, fill=pal.GOLD_SH, sil=False), rect(0, 4, W, 14, fill=pal.GOLD, sil=False))
    return _write("curtain_valance", cv, 0, 0, W, H)


# =============================================================================== proscenium
def proscenium(side):
    """Gilded pillar framing the house's far end (left: world x -220..0, right: 6200..6420)."""
    cv = Canvas()
    W = 220
    H = WORLD_Y1 - WORLD_Y0
    x0 = 0
    # red velvet backing strip on the outer side, gilded pillar on the inner side
    g = cv.grad(Grad("pvel", "linear", (0, 0, W, 0), [(0, pal.VELVET_DEEP, None), (0.5, pal.VELVET_SH, None), (1, pal.VELVET_DEEP, None)]))
    cv.add(rect(0, 0, W, H, fill=g.url(), sil=False))
    px0, px1 = (60, 200) if side == "l" else (20, 160)
    gg = cv.grad(Grad("pgold", "linear", (px0, 0, px1, 0), [(0, pal.GOLD_LT, None), (0.35, pal.GOLD, None), (0.8, pal.GOLD_SH, None),
                                                            (1, mul(pal.GOLD_SH, 0.8), None)]))
    cv.add(rect(px0, 0, px1 - px0, H, fill=gg.url(), sil=False))
    fl = PB()
    for k in range(4):
        fx = px0 + 24 + k * 30
        fl.M(fx, 260).L(fx, H - 260)
    cv.add(path(fl, fill="none", sw=9, stroke=pal.GOLD_SH, sop=0.8, sil=False), path(fl, fill="none", sw=3, stroke=pal.GOLD_LT, sop=0.8, sil=False))
    # capitals / bases with scrolls
    for yy, up in ((180, True), (H - 190, False)):
        cv.add(rect(px0 - 14, yy - 40, px1 - px0 + 28, 80, 10, fill=pal.GOLD, sw=4, stroke=pal.GOLD_SH, sil=False))
        for sx in (px0 + 8, px1 - 8):
            cv.add(circle(sx, yy, 22, fill=pal.GOLD_LT, sw=4, stroke=pal.GOLD_SH, sil=False))
            cv.add(circle(sx, yy, 9, fill=pal.GOLD, sw=3, stroke=pal.GOLD_SH, sil=False))
    # repeating rosettes along the pillar
    ros = PB()
    y = 420
    while y < H - 400:
        ros.circle((px0 + px1) / 2, y, 14)
        y += 260
    cv.add(path(ros, fill=pal.GOLD_LT, sw=3, stroke=pal.GOLD_SH, sil=False))
    edge = px1 if side == "l" else px0
    cv.add(path(PB().M(edge, 0).L(edge, H), fill="none", sw=4, stroke=INK, sop=0.6, sil=False))
    return _write("proscenium_%s" % side, cv, 0, 0, W, H)


# =============================================================================== apron, footlights, flies, vignette
def apron():
    cv = Canvas()
    W, H = 1024, 190
    g = cv.grad(Grad("aboard", "linear", (0, 0, 0, 90), [(0, pal.STAGE_BOARD, None), (1, pal.STAGE_BOARD_SH, None)]))
    cv.add(rect(0, 0, W, 90, fill=g.url(), sil=False))
    seams = PB()
    for x in range(0, W, 128):
        seams.M(x + 20, 0).L(x + 26, 90)
    for y in (30, 60):
        seams.M(0, y).L(W, y)
    cv.add(path(seams, fill="none", sw=2.5, stroke=pal.STAGE_BOARD_SH, sil=False))
    # the stage lip (gilded moulding) and the dark pit below
    cv.add(rect(0, 88, W, 22, fill=pal.GOLD_SH, sil=False), rect(0, 90, W, 10, fill=pal.GOLD, sil=False), rect(0, 90, W, 3, fill=pal.GOLD_LT, sil=False))
    g2 = cv.grad(Grad("apit", "linear", (0, 110, 0, H), [(0, "#2A1A2A", None), (1, "#120C18", None)]))
    cv.add(rect(0, 110, W, H - 110, fill=g2.url(), sil=False))
    # footlight cups (brass shells facing up) every 256 px - tile-aligned
    for i in range(4):
        cx = i * 256 + 128
        shell = PB().M(cx - 44, 80).Q(cx, 40, cx + 44, 80).L(cx + 34, 96).L(cx - 34, 96).Z()
        cv.add(path(shell, fill=pal.GOLD_SH, sil=False),
               path(PB().M(cx - 38, 80).Q(cx, 50, cx + 30, 76).L(cx + 20, 86).L(cx - 30, 88).Z(), fill=pal.GOLD, sil=False),
               path(shell, fill="none", sw=4, stroke=INK, sop=0.8, sil=False))
        cv.add(ellipse(cx, 64, 18, 7, fill="#FFF4C8", sil=False))
    return _write("apron", cv, 0, 0, W, H)


def footlight_glow():
    cv = Canvas()
    W, H = 512, 220
    g = cv.grad(Grad("fglow", "radial", (256, 220, 256), [(0, "#FFE7A8", 0.7), (0.35, "#FFC870", 0.28), (1, "#FFB050", 0.0)]))
    cv.add(ellipse(256, 220, 256, 220, fill=g.url(), sil=False))
    return _write("footlight_glow", cv, 0, 0, W, H)


def flies():
    """Backstage above the set (tileable 1024 wide, 400 tall; its bottom edge sits on the top of the set)."""
    cv = Canvas()
    W, H = 1024, 400
    g = cv.grad(Grad("fbg", "linear", (0, 0, 0, H), [(0, "#120E1C", None), (1, pal.STAGE_DARK2, None)]))
    cv.add(rect(0, 0, W, H, fill=g.url(), sil=False))
    # a batten pipe with two stage lamps, three hanging ropes, a sandbag
    cv.add(rect(0, 96, W, 12, 6, fill="#4A4258", sil=False), rect(0, 96, W, 4, fill="#6A6280", sil=False))
    for lx in (180, 700):
        cv.add(path(PB().M(lx, 108).L(lx, 124), fill="none", sw=5, stroke="#4A4258", sil=False))
        cv.add(path(PB().M(lx - 24, 124).L(lx + 24, 124).L(lx + 30, 176).L(lx - 30, 176).Z(), fill="#2E2840", sw=3, stroke="#57506C", sil=False))
        cv.add(ellipse(lx, 178, 26, 7, fill="#F7D98A", fop=0.8, sil=False))
        gl = cv.grad(Grad("flamp%d" % lx, "radial", (lx, 190, 160), [(0, "#FFE7A8", 0.18), (1, "#FFE7A8", 0.0)]))
        cv.add(circle(lx, 190, 160, fill=gl.url(), sil=False))
    for rx in (330, 360, 860):
        cv.add(path(PB().M(rx, 0).Q(rx + 6, H * 0.5, rx - 2, H - 6), fill="none", sw=5, stroke="#8A7A5E", sop=0.7, sil=False))
    cv.add(path(PB().M(360, 300).Q(346, 330, 360, 360).Q(376, 330, 360, 300).Z(), fill="#6E6048", sil=False))
    return _write("flies", cv, 0, 0, W, H)


def vignette_top():
    cv = Canvas()
    W, H = 1920, 360
    g = cv.grad(Grad("vtop", "linear", (0, 0, 0, H), [(0, "#141A34", 0.55), (0.5, "#1A2240", 0.18), (1, "#1A2240", 0.0)]))
    cv.add(rect(0, 0, W, H, fill=g.url(), sil=False))
    return _write("vignette_top", cv, 0, 0, W, H)


def velvet_rope():
    """Two brass stanchions + a sagging red rope (roped-off doorway, 'backstage')."""
    cv = Canvas()
    W, H = 200, 176
    rope = PB().M(40, 50).Q(100, 120, 160, 50)
    cv.add(path(rope, fill="none", sw=18, stroke=INK), path(rope, fill="none", sw=11, stroke=pal.VELVET, sil=False),
           path(PB().M(46, 54).Q(100, 112, 154, 54), fill="none", sw=3, stroke=pal.VELVET_LT, sil=False))
    for sx in (40, 160):
        cv.add(*box(sx - 6, 40, 12, 110, 5, pal.BRASS, 5, hi=False))
        cv.add(*ball(sx, 34, 13, pal.BRASS, 5, hi=True))
        cv.add(*box(sx - 30, 146, 60, 18, 8, pal.BRASS, 5, hi=False))
        cv.add(circle(sx, 48, 7, fill=pal.GOLD_SH, sw=3, stroke=INK, sil=False))
    return _write("velvet_rope", cv, 0, 0, W, H)


# =============================================================================== exterior set pieces
def sky_grad(cv, gid, x0, x1, y0, y1):
    g = cv.grad(Grad(gid, "linear", (0, y0, 0, y1), [(0, mix(pal.SKY, "#5FA8D8", 0.5), None), (1, mix(pal.SKY, "#6FB8E0", 0.35), None)]))
    cv.add(rect(x0, y0, x1 - x0, y1 - y0, fill=g.url(), sil=False))


def cloud(cv, cx, cy, s, col):
    pb = PB().ellipse(cx, cy, 60 * s, 22 * s).ellipse(cx - 40 * s, cy + 4 * s, 34 * s, 18 * s).ellipse(cx + 44 * s, cy + 6 * s, 30 * s, 16 * s)
    pb.ellipse(cx - 6 * s, cy - 16 * s, 34 * s, 22 * s)
    cv.add(path(pb, fill=col, sil=False))


def sky_left():
    """Above the porch and the hall's front part (world x -220..1000, y -1340..-640): sky, No. 9's upper
    storey and roof (Hush's attic window), No. 7's slate lean-to roof over the hall."""
    cv = Canvas()
    x0, x1, y0, y1 = WORLD_X0, 1000, UPPER_TOP, -640
    sky_grad(cv, "skyl", x0, x1, y0, y1)
    cloud(cv, 60, -1180, 1.2, lift(pal.SKY, 0.6))
    cloud(cv, 380, -1000, 0.8, lift(pal.SKY, 0.55))
    n9 = ("#B7B4E0", "#9C98CC", "#DAD8F4")
    cv.add(rect(x0, -1010, 168 - x0, 370, fill=n9[0], sil=False), rect(150, -1010, 18, 370, fill=n9[1], sil=False))
    sid = PB()
    y = -1000
    while y < -640:
        sid.M(x0, y).L(150, y)
        y += 36
    cv.add(path(sid, fill="none", sw=2.0, stroke=n9[1], sil=False))
    roof = PB().M(x0, -1010).L(x0, -1130).L(60, -1200).L(196, -1010).Z()
    cv.add(path(roof, fill="#7C6F9C", sil=False), path(roof, fill="none", sw=4, stroke=A, sop=0.8, sil=False))
    # Hush's attic window (round) with a tiny beret-red curtain
    cv.add(circle(70, -880, 50, fill="#FFFFFF", sw=4, stroke=A, sop=0.8, sil=False))
    cv.add(circle(70, -880, 38, fill=mix("#CFE9F6", pal.SKY, 0.2), sil=False))
    cv.add(path(PB().M(34, -896).Q(70, -870, 106, -896).L(106, -910).Q(70, -920, 34, -910).Z(), fill=mix(pal.BERET, pal.SKY, 0.15), sil=False))
    cv.add(path(PB().M(70, -918).L(70, -842).M(32, -880).L(108, -880), fill="none", sw=3, stroke=A, sop=0.8, sil=False))
    # No. 7's lean-to roof over the hall (slates), meeting the landing's wall at x 1000
    lt = PB().M(468, -640).L(1000, -900).L(1000, -640).Z()
    cv.add(path(lt, fill="#6E6680", sil=False))
    sl = PB()
    for k in range(1, 8):
        t = k / 8.0
        sl.M(468 + (1000 - 468) * t * 0.02, -640 - 0).L(1000, -640 - 260 * (1 - t) - 0)
    slates = PB()
    for k in range(1, 9):
        yy = -640 - k * 30
        xa = 468 + (1000 - 468) * (k * 30) / 260.0
        slates.M(xa, yy).L(1000, yy)
    cv.add(path(slates, fill="none", sw=2.5, stroke="#57506C", sil=False))
    cv.add(path(PB().M(460, -636).L(1000, -904), fill="none", sw=10, stroke="#8A8298", sil=False))
    cv.add(path(lt, fill="none", sw=4, stroke=A, sop=0.8, sil=False))
    # chimney
    cv.add(rect(900, -960, 50, 120, 4, fill=pal.BRICK, sw=4, stroke=A, sop=0.8, sil=False))
    cv.add(rect(890, -972, 70, 18, 4, fill=pal.BRICK_SH, sw=4, stroke=A, sop=0.8, sil=False))
    return _write("sky_left", cv, x0, y0, x1 - x0, y1 - y0), (x0, y0, x1 - x0, y1 - y0)


def sky_right():
    """Above the conservatory's open end and the garden (world x 4500..6420, y -1340..-640)."""
    cv = Canvas()
    x0, x1, y0, y1 = 4500, WORLD_X1, UPPER_TOP, -640
    sky_grad(cv, "skyr", x0, x1, y0, y1)
    cloud(cv, 5000, -1150, 1.3, lift(pal.SKY, 0.6))
    cloud(cv, 5760, -1040, 0.9, lift(pal.SKY, 0.55))
    cloud(cv, 6250, -1220, 0.7, lift(pal.SKY, 0.55))
    # distant trees behind the garden fence
    trees = PB()
    for (tx, r) in [(5160, 90), (5330, 120), (5520, 80), (5900, 110), (6120, 95), (6330, 120)]:
        trees.circle(tx, -640 - r * 0.7, r)
    cv.add(path(trees, fill=mix(pal.HEDGE, pal.SKY, 0.35), sil=False))
    # the conservatory's glass lean-to roof (4500-4700), sloping down from the dressing room wall
    gr = PB().M(4500, -760).L(4720, -640).L(4500, -640).Z()
    cv.add(path(gr, fill=mix(pal.ROOM["conservatory"], "#FFFFFF", 0.3), fop=0.9, sil=False))
    mull = PB()
    for k in range(1, 4):
        mull.M(4500, -760 + k * 30).L(4500 + 220 * (1 - (120 - k * 30) / 120.0) + 0, -640)
    cv.add(path(PB().M(4560, -727).L(4560, -640).M(4620, -694).L(4620, -640).M(4680, -662).L(4680, -640), fill="none", sw=3, stroke="#FFFFFF", sil=False))
    cv.add(path(gr, fill="none", sw=4, stroke=A, sop=0.8, sil=False))
    return _write("sky_right", cv, x0, y0, x1 - x0, y1 - y0), (x0, y0, x1 - x0, y1 - y0)


def roof_main():
    """No. 7's roof over the upper floor (x 960..4540): slates, two chimneys, a weather-vane shaped like
    a singing mouth (a vain man's house). Split in two canvases (<= 2048 px wide each)."""
    out = []
    y_eave, y_top = UPPER_TOP, UPPER_TOP - 250
    x0, x1 = 960, 4540
    halves = [(x0, 2750), (2750, x1)]
    for idx, (hx0, hx1) in enumerate(halves):
        cv = Canvas()
        # the sky behind the roof (so the flies don't show through gaps)
        sky_grad(cv, "skyroof%d" % idx, hx0, hx1, y_top - 40, y_eave)
        roof = PB().M(x0, y_eave).L(x0 + 180, y_top).L(x1 - 180, y_top).L(x1, y_eave).Z()
        cv.add(path(roof, fill="#6E6680", sil=False))
        slates = PB()
        for k in range(1, 8):
            yy = y_eave - k * 30
            inset = 180 * (k * 30) / 250.0
            slates.M(x0 + inset, yy).L(x1 - inset, yy)
        cv.add(path(slates, fill="none", sw=2.5, stroke="#57506C", sil=False))
        cv.add(rect(x0 - 20, y_eave - 12, x1 - x0 + 40, 16, 6, fill="#8A8298", sw=4, stroke=A, sop=0.8, sil=False))
        cv.add(path(roof, fill="none", sw=4, stroke=A, sop=0.8, sil=False))
        for cx in (1500, 3700):
            if hx0 <= cx < hx1:
                cv.add(rect(cx - 30, y_top - 90, 60, 120, 4, fill=pal.BRICK, sw=4, stroke=A, sop=0.8, sil=False))
                cv.add(rect(cx - 40, y_top - 104, 80, 20, 4, fill=pal.BRICK_SH, sw=4, stroke=A, sop=0.8, sil=False))
        if hx0 <= 2750 < hx1 or idx == 1:
            vx = 2760
            cv.add(path(PB().M(vx, y_top).L(vx, y_top - 110), fill="none", sw=5, stroke=A, sop=0.9, sil=False))
            cv.add(ellipse(vx + 22, y_top - 100, 26, 16, fill=pal.GOLD, sw=4, stroke=A, sop=0.9, sil=False))
            cv.add(ellipse(vx + 26, y_top - 100, 12, 8, fill="#3A2A36", sil=False))
        name = "roof_main_%s" % ("l" if idx == 0 else "r")
        out.append((name, _write(name, cv, hx0, y_top - 40, hx1 - hx0, y_eave - y_top + 40 + 4), (hx0, y_top - 40, hx1 - hx0, y_eave - y_top + 44)))
    return out


def front_door_glow(reg):
    """The front door's bow glow (GDD §2.2 Take a Bow; "the front door flashes" when every line is done): a warm
    additive light round the doorway gap at x 500 with a lit frame and soft rays. Decor `hall_front_door_glow`
    (hidden; the view shows it while Take a Bow is available, pulsing, and brighter while the Stalls chant)."""
    cv = Canvas()
    x0, y0, W, H = 300, -560, 400, 600
    cx, cy = 500, -240
    g = cv.grad(Grad("dglow", "radial", (cx, cy, 300), [(0, "#FFF1B8", 0.85), (0.35, "#FFD27A", 0.45), (0.75, "#FFB050", 0.12),
                                                         (1, "#FFB050", 0.0)]))
    cv.add(ellipse(cx, cy, 196, 296, fill=g.url(), sil=False))
    # soft rays fanning out of the doorway
    rays = PB()
    for ang in (-62, -38, -14, 14, 38, 62, 180 - 50, 180 + 50):
        a = math.radians(ang - 90)
        a1, a2 = a - math.radians(4), a + math.radians(4)
        rays.M(cx + 20 * math.cos(a), cy + 20 * math.sin(a)).L(cx + 230 * math.cos(a1), cy + 290 * math.sin(a1)).L(cx + 230 * math.cos(a2), cy + 290 * math.sin(a2)).Z()
    cv.add(path(rays, fill="#FFE7A8", fop=0.22, sil=False))
    # the lit door frame (the gap from -474 to the floor, 40 px band)
    frame = PB().M(476, -8).L(476, -470).Q(476, -484, 490, -484).L(510, -484).Q(524, -484, 524, -470).L(524, -8)
    cv.add(path(frame, fill="none", sw=18, stroke="#FFD27A", sop=0.55, sil=False))
    cv.add(path(frame, fill="none", sw=6, stroke="#FFF6D8", sop=0.9, sil=False))
    art = _write("front_door_glow", cv, x0, y0, W, H)
    reg.decor.append({"id": "hall_front_door_glow", "room": "hall", "pos": [x0, y0], "size": [W, H], "art": {"idle": art},
                      "z": 1, "hidden": True, "show": "bow", "blend": "add", "pulse_hz": 1.5, "link": "front_door"})


def bow_spot():
    """A warm light pool on the apron for the curtain call (screen-space, additive; bottom-centred)."""
    cv = Canvas()
    W, H = 1100, 300
    g = cv.grad(Grad("bspot", "radial", (W / 2, H - 40, W / 2), [(0, "#FFF1C8", 0.8), (0.45, "#FFD27A", 0.35), (1, "#FFB050", 0.0)]))
    cv.add(ellipse(W / 2, H - 40, W / 2 - 4, 150, fill=g.url(), sil=False))
    # the beam from the flies above (a soft cone into the pool)
    cone = PB().M(W / 2 - 90, 0).L(W / 2 + 90, 0).L(W / 2 + 380, H - 60).L(W / 2 - 380, H - 60).Z()
    cv.add(path(cone, fill="#FFE7A8", fop=0.1, sil=False))
    return _write("bow_spot", cv, 0, 0, W, H)


def build(reg):
    front_door_glow(reg)
    st = {}
    st["curtain"] = {"art": curtain(), "size": [1920, 1080], "tile_x": 1920, "screen": True}
    st["curtain_valance"] = {"art": valance(), "size": [1920, 260], "tile_x": 1920, "screen": True}
    st["proscenium_l"] = {"art": proscenium("l"), "world_pos": [WORLD_X0, WORLD_Y0], "size": [220, WORLD_Y1 - WORLD_Y0]}
    st["proscenium_r"] = {"art": proscenium("r"), "world_pos": [6200, WORLD_Y0], "size": [220, WORLD_Y1 - WORLD_Y0]}
    st["apron"] = {"art": apron(), "top_y": geo.SLAB_H, "size": [1024, 190], "tile_x": 1024, "x0": 0, "x1": 6200}
    st["footlight_glow"] = {"art": footlight_glow(), "size": [512, 220], "blend": "add", "every_px": 256, "first_x": 128,
                            "bottom_y": geo.SLAB_H + 40, "x0": 0, "x1": 6200, "alpha": 0.5}
    st["flies"] = {"art": flies(), "size": [1024, 400], "tile_x": 1024, "bottom_y": UPPER_TOP, "x0": WORLD_X0, "x1": WORLD_X1,
                   "fill_color": pal.STAGE_DARK2}
    st["vignette_top"] = {"art": vignette_top(), "size": [1920, 360], "screen": True}
    st["velvet_rope"] = {"art": velvet_rope(), "size": [200, 176], "anchor": [100, 176]}
    st["bow_spot"] = {"art": bow_spot(), "size": [1100, 300], "screen": True, "blend": "add", "anchor": "bottom_centre", "alpha": 0.85}
    pieces = []
    art, box_ = sky_left()
    pieces.append({"id": "sky_left", "art": art, "world_pos": [box_[0], box_[1]], "size": [box_[2], box_[3]], "z": -2})
    art, box_ = sky_right()
    pieces.append({"id": "sky_right", "art": art, "world_pos": [box_[0], box_[1]], "size": [box_[2], box_[3]], "z": -2})
    for name, art, bx in roof_main():
        pieces.append({"id": name, "art": art, "world_pos": [bx[0], bx[1]], "size": [bx[2], bx[3]], "z": -1})
    st["pieces"] = pieces
    st["bounds"] = [WORLD_X0, WORLD_Y0, WORLD_X1 - WORLD_X0, WORLD_Y1 - WORLD_Y0]
    st["clear_color"] = pal.STAGE_DARK
    reg.stage = st
