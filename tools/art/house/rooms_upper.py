"""rooms_upper - final backgrounds for the upper floor (landing, bathroom, bedroom, dressing room) and the
conservatory. Stage 2: every ground-floor shot shows the bottom ~260 px of the upper rooms and ~600 px of
the conservatory (dimmed as the unlit set while they are locked), so they are drawn to the same finish as
the slice rooms: one quiet wallpaper pattern, moulded trim, set dressing in soft ARCH ink pulled toward
the wall colour (rooms_final.soft), a calm walk band. Every interactable is a prop (props_upper.py).
Replaces rooms_grey for these five rooms (same paths).
"""
import math

import arch
import geo
import pal
from arch import AOP, ARCH, hline
from rooms_final import SD, SW, line, sbox, shadow_rect, slines, sm, soft
from svgk import PB, Grad, circle, ellipse, lift, mix, mul, path, rect


def sash_window(rm, x0, x1, top, bot, outside="#BFE3F4", curtain=None):
    """A painted sash window with the sky + a tree top outside; optional curtains either side."""
    wall = rm.wall
    frame = sm("#FFFFFF", wall, 0.12, 0.9)
    rm.bg.add(shadow_rect(x0 - 8, top - 4, x1 - x0 + 22, bot - top + 18, 0.08))
    rm.bg.add(sbox(rm, x0 - 10, top - 10, x1 - x0 + 20, bot - top + 20, 6, frame, bx=6, by=6))
    sky = mix(outside, wall, 0.2)
    rm.bg.add(rect(x0, top, x1 - x0, bot - top, 4, fill=sky, sil=False))
    tree = PB().M(x0, bot).L(x0, bot - 40).Q(x0 + (x1 - x0) * 0.3, bot - 90, x0 + (x1 - x0) * 0.55, bot - 52)
    tree.Q(x0 + (x1 - x0) * 0.8, bot - 80, x1, bot - 46).L(x1, bot).Z()
    rm.bg.add(path(tree, fill=soft(pal.HEDGE, wall, 0.35, 0.8), sil=False))
    rm.bg.add(path(PB().M(x0 + 12, top + 10).L(x0 + 34, top + 10).L(x0 + 18, top + 70).L(x0 + 8, top + 70).Z(), fill="#FFFFFF",
                   fop=0.45, sil=False))
    mid = (top + bot) / 2
    rm.bg.add(rect(x0 - 2, mid - 6, x1 - x0 + 4, 12, 3, fill=frame[0], sw=SD, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(slines(PB().M((x0 + x1) / 2, top).L((x0 + x1) / 2, bot), SD, 0.6))
    rm.bg.add(sbox(rm, x0 - 18, bot + 4, x1 - x0 + 36, 14, 4, frame, bx=0, by=4))
    if curtain:
        for side in (-1, 1):
            xa = x0 - 36 if side < 0 else x1 + 6
            pb = PB().M(xa, top - 22).L(xa + 30, top - 22).Q(xa + (26 if side < 0 else 4), mid, xa + (34 if side < 0 else -4), bot + 30)
            pb.L(xa + (6 if side < 0 else 24), bot + 30).Q(xa + (2 if side < 0 else 30), mid, xa, top - 22).Z()
            rm.bg.add(path(pb, fill=curtain[0], sil=False), path(pb, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
            rm.bg.add(slines(PB().M(xa + 15, top - 16).Q(xa + 15 + side * 4, mid, xa + 17, bot + 24), SD, 0.45))
        rm.bg.add(sbox(rm, x0 - 46, top - 30, x1 - x0 + 92, 10, 5, sm(pal.GOLD, wall, 0.3), bx=0, by=3))


def picture(rm, x, y, w, h, cols, gold=True):
    wall = rm.wall
    rm.bg.add(rect(x + 4, y + 5, w, h, 5, fill=pal.INK, fop=0.1, sil=False))
    fr = sm(pal.GOLD if gold else "#9A5B3A", wall, 0.25)
    rm.bg.add(sbox(rm, x, y, w, h, 5, fr, bx=0, by=0))
    rm.bg.add(rect(x + 10, y + 10, w - 20, h - 20, 3, fill=cols[0], sil=False))
    hill = PB().M(x + 10, y + h - 10).L(x + 10, y + h * 0.62).Q(x + w * 0.45, y + h * 0.42, x + w - 10, y + h * 0.66).L(x + w - 10, y + h - 10).Z()
    rm.bg.add(path(hill, fill=cols[1], sil=False))
    rm.bg.add(circle(x + w * 0.72, y + h * 0.34, min(w, h) * 0.1, fill=cols[2], sil=False))
    rm.bg.add(slines(PB().rrect(x + 10, y + 10, w - 20, h - 20, 3), SD, 0.5))


def rug(rm, x0, x1, col, border):
    y0 = geo.BACK + 3
    pb = PB().M(x0 + 12, y0).L(x1 - 12, y0).L(x1, -2).L(x0, -2).Z()
    rm.bg.add(path(pb, fill=col, sil=False))
    rm.bg.add(path(PB().M(x0 + 20, y0 + 5).L(x1 - 20, y0 + 5).L(x1 - 9, -7).L(x0 + 9, -7).Z(), fill="none", sw=3, stroke=border, sil=False))
    rm.bg.add(path(pb, fill="none", sw=2.5, stroke=ARCH, sop=0.6, sil=False))


# ------------------------------------------------------------------------------- landing
def landing():
    rm = arch.Room("landing")
    wall = rm.wall
    dado_y = -250
    arch.wall_base(rm)
    arch.pat_boards(rm, geo.CORNICE, dado_y, step=46, col=mul(wall, 0.93))
    arch.wainscot(rm, dado_y + 7, geo.SKIRT_TOP, panel_w=150, col=mul(wall, 0.84))
    arch.dado(rm, dado_y, col=lift(wall, 0.45))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    arch.floor_strip(rm)
    rug(rm, 1330, 1780, soft("#5E7FA0", wall, 0.3, 0.7), soft("#E8C46A", wall, 0.25, 0.8))
    arch.slab(rm)
    # stairwell: the flight arrives from the hall through the floor at x 1050-1300
    op0, op1 = 1050, 1300
    rm.bg.add(rect(op0, geo.BACK, op1 - op0, geo.SLAB_H - geo.BACK, fill="#3A2F40", sil=False))
    g = rm.bg.grad(Grad(rm.gid("well"), "linear", (0, 0, 0, geo.SLAB_H), [(0, pal.INK, 0.1), (1, pal.INK, 0.5)]))
    rm.bg.add(rect(op0, 0, op1 - op0, geo.SLAB_H, fill=g.url(), sil=False))
    tread = sm("#C98B55", wall, 0.1, 0.9)
    run = 400.0 / 14
    for i in range(3):
        x = 1050 + run * i
        rm.bg.add(rect(x, 50.0 * i - 4, run + 6, 10, 3, fill=tread[0], sw=SD, stroke=ARCH, sop=AOP, sil=False))
    # balustrade round the opening: handrail, turned spindles, a newel with a ball cap
    wood = sm("#8E4636", wall, 0.2, 0.85)
    rail = PB().M(1120, -176).L(op1 + 6, -176)
    rm.bg.add(path(rail, fill="none", sw=16, stroke=ARCH, sop=AOP, sil=False), path(rail, fill="none", sw=10, stroke=wood[0], sil=False))
    rm.bg.add(path(PB().M(1124, -180).L(op1, -180), fill="none", sw=3, stroke=wood[2], sop=0.7, sil=False))
    x = 1146
    spind = PB()
    while x < op1 - 6:
        spind.M(x, -168).L(x, geo.BACK)
        x += 26
    rm.bg.add(path(spind, fill="none", sw=8, stroke=ARCH, sop=AOP, sil=False), path(spind, fill="none", sw=4, stroke=wood[1], sil=False))
    rm.bg.add(sbox(rm, op1 - 10, -196, 22, 196 + geo.BACK, 4, wood, bx=5, by=0))
    rm.bg.add(circle(op1 + 1, -206, 13, fill=wood[0], sw=SW, stroke=ARCH, sop=AOP, sil=False))
    # radiator (the DRY station) with its pipes + a towel drying on it
    metal = sm("#F4F0E6", wall, 0.1, 0.9)
    rm.bg.add(shadow_rect(1396, -40, 118, 12, 0.1))
    rm.bg.add(sbox(rm, 1392, -176, 120, 136, 10, metal, bx=10, by=0))
    fins = PB()
    for fx in range(1410, 1500, 18):
        fins.M(fx, -164).L(fx, -54)
    rm.bg.add(slines(fins, SD, 0.45))
    rm.bg.add(line(1400, -40, 1400, -28, 6, ARCH, 0.7), line(1504, -40, 1504, -28, 6, ARCH, 0.7))
    towel = PB().M(1428, -178).L(1474, -178).L(1478, -110).Q(1466, -104, 1452, -110).Q(1438, -104, 1424, -110).Z()
    rm.bg.add(path(towel, fill=soft("#F2B8C8", wall, 0.25), sil=False), path(towel, fill="none", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    # the window, a framed poster of his big night, a wall lamp
    sash_window(rm, 1590, 1710, -560, -300, curtain=sm("#7FA8C8", wall, 0.3, 0.7))
    picture(rm, 1420, -540, 110, 132, (soft("#F4E4C0", wall, 0.1), soft("#9C5A78", wall, 0.25), soft(pal.GOLD, wall, 0.1)))
    rm.bg.add(ellipse(1360, -420, 18, 12, fill=soft("#FFE59A", wall, 0.1), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(line(1360, -408, 1360, -380, 4, ARCH, 0.7))
    arch.bands(rm, exterior_left=False)
    return rm


# ------------------------------------------------------------------------------- bathroom
def bathroom():
    rm = arch.Room("bathroom")
    wall = rm.wall
    arch.wall_base(rm)
    arch.pat_tiles(rm, -330, geo.SKIRT_TOP, 44, lift(wall, 0.32), mul(wall, 0.93))
    rm.bg.add(rect(rm.x0, -338, rm.x1 - rm.x0, 12, fill=lift(wall, 0.5), sil=False), hline(rm.x0, rm.x1, -338, 2.5, 0.6),
              hline(rm.x0, rm.x1, -326, 2.0, 0.45))
    # a quiet bubble motif on the upper wall
    bub = PB()
    for i, x in enumerate(range(rm.x0 + 40, rm.x1, 96)):
        y = -560 + (i % 3) * 64
        bub.circle(x, y, 9 + (i % 2) * 4)
    rm.bg.add(path(bub, fill="none", sw=3, stroke=lift(wall, 0.35), sil=False))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm, col=lift(wall, 0.4))
    # chequered lino
    arch.floor_strip(rm, col=mix("#FFFFFF", wall, 0.35), sh=mul(wall, 0.84))
    chk = PB()
    x = rm.x0
    i = 0
    while x < rm.x1:
        if i % 2 == 0:
            chk.M(x, geo.BACK).L(x + 28, geo.BACK).L(x + 30, -14).L(x + 2, -14).Z()
        else:
            chk.M(x + 2, -14).L(x + 30, -14).L(x + 32, 0).L(x + 4, 0).Z()
        x += 28
        i += 1
    rm.bg.add(path(chk, fill=mul(wall, 0.86), fop=0.8, sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, 0, 3.0, 0.8))
    arch.slab(rm)
    # pedestal basin + the mirror cabinet over it (SINK + MIRROR station at 1930)
    por = sm("#FFFFFF", wall, 0.08, 0.9)
    frame = sm("#E8E0D0", wall, 0.15, 0.9)
    rm.bg.add(sbox(rm, 1866, -524, 128, 158, 8, frame, bx=8, by=8))
    rm.bg.add(rect(1880, -510, 100, 130, 5, fill=lift("#CFE9F6", 0.2), sil=False))
    rm.bg.add(path(PB().M(1892, -500).L(1914, -500).L(1898, -430).L(1886, -430).Z(), fill="#FFFFFF", fop=0.5, sil=False))
    ped = PB().M(1906, -186).L(1954, -186).Q(1946, -110, 1950, -30).L(1910, -30).Q(1914, -110, 1906, -186).Z()
    rm.bg.add(path(ped, fill=por[1], sil=False), path(PB().M(1910, -182).L(1940, -182).Q(1934, -110, 1938, -34).L(1914, -34)
                                                       .Q(1918, -110, 1910, -182).Z(), fill=por[0], sil=False),
              path(ped, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, 1864, -216, 132, 38, 16, por, bx=10, by=8))
    rm.bg.add(rect(1880, -34, 100, 8, 4, fill=mul(wall, 0.8), sil=False))
    # towel rail with a pink towel, a loofah hook
    rm.bg.add(line(2180, -330, 2276, -330, 7, ARCH, 0.8))
    rm.bg.add(line(2182, -330, 2274, -330, 3, lift(pal.BRASS[0], 0.2), 0.9))
    tw = PB().M(2192, -326).L(2262, -326).L(2258, -214).Q(2244, -206, 2228, -214).Q(2212, -206, 2196, -214).Z()
    rm.bg.add(path(tw, fill=soft("#F2A8C0", wall, 0.25), sil=False), path(tw, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(slines(PB().M(2196, -240).L(2258, -240).M(2196, -250).L(2258, -250), SD, 0.5))
    # bathroom scales on the floor (with a tiny dial)
    rm.bg.add(sbox(rm, 2244, -44, 72, 24, 8, sm("#F4F0E6", wall, 0.1), bx=0, by=6))
    rm.bg.add(circle(2280, -34, 7, fill="#FFFFFF", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    # shower curtain on its ring rail over the bath (gathered at the left end)
    rm.bg.add(line(2300, -566, 2612, -566, 6, ARCH, 0.75))
    rings = PB()
    for rx in range(2306, 2360, 11):
        rings.circle(rx, -560, 5)
    rm.bg.add(path(rings, fill="none", sw=2.5, stroke=ARCH, sop=0.8, sil=False))
    sc = sm("#FFFFFF", wall, 0.2, 0.9)
    cur = PB().M(2302, -556).L(2366, -556).Q(2352, -420, 2344, -236).L(2310, -236).Q(2316, -420, 2302, -556).Z()
    rm.bg.add(path(cur, fill=sc[0], sil=False), path(cur, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(slines(PB().M(2324, -550).Q(2328, -400, 2322, -240).M(2344, -550).Q(2340, -400, 2334, -240), SD, 0.45))
    dots = PB()
    for (dx, dy) in [(2318, -500), (2340, -470), (2320, -420), (2338, -370), (2322, -320), (2336, -280)]:
        dots.circle(dx, dy, 4)
    rm.bg.add(path(dots, fill=soft("#7FB8E8", wall, 0.2), sil=False))
    sash_window(rm, 2440, 2560, -600, -430, curtain=None)
    # a bath mat in front of the tub
    rm.bg.add(path(PB().M(2360, geo.BACK + 4).L(2560, geo.BACK + 4).L(2570, -4).L(2352, -4).Z(), fill=soft("#9FD2C0", wall, 0.2), sil=False))
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- bedroom
def bedroom():
    rm = arch.Room("bedroom")
    wall = rm.wall
    dado_y = -236
    arch.wall_base(rm)
    arch.pat_dots(rm, geo.CORNICE, dado_y, step=52, r=4, col=lift(wall, 0.18))
    arch.wainscot(rm, dado_y + 7, geo.SKIRT_TOP, panel_w=150, col=mul(wall, 0.86))
    arch.dado(rm, dado_y, col=lift(wall, 0.5))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    arch.floor_strip(rm)
    rug(rm, 3050, 3320, soft("#E8A0B8", wall, 0.35, 0.8), soft("#FFFFFF", wall, 0.2))
    arch.slab(rm)
    sash_window(rm, 3100, 3236, -590, -404, curtain=sm("#E8A0B8", wall, 0.35, 0.75))
    # a framed portrait of HIM over the bed (he adores himself) + a wall sconce
    picture(rm, 3380, -560, 92, 112, (soft("#F4E4C0", wall, 0.1), soft("#7B3F8C", wall, 0.45, 0.7), soft("#D9DCE6", wall, 0.1)))
    # hat stand (the BUTTER-FINGERS dance partner) at 3590 with a bowler and a scarf
    wood = sm("#8E4636", wall, 0.2, 0.85)
    rm.bg.add(line(3590, -30, 3590, -430, 12, ARCH, 0.8), line(3590, -32, 3590, -428, 6, wood[0], 1.0))
    base = PB().M(3548, -28).Q(3590, -62, 3632, -28).Z()
    rm.bg.add(path(base, fill=wood[0], sil=False), path(base, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    for (hx, hy, sx) in [(3590, -432, 0), (3560, -404, -1), (3620, -404, 1)]:
        rm.bg.add(line(3590, hy + 10, 3590 + sx * 34, hy - 6, 6, ARCH, 0.8))
    hat = PB().M(3548, -440).Q(3552, -486, 3590, -488).Q(3628, -486, 3632, -440).Z()
    rm.bg.add(path(hat, fill=soft("#5A5E78", wall, 0.2), sil=False), path(hat, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, 3536, -446, 108, 10, 5, sm("#5A5E78", wall, 0.2), bx=0, by=3))
    scarf = PB().M(3604, -400).Q(3640, -360, 3626, -260).L(3610, -262).Q(3620, -350, 3592, -392).Z()
    rm.bg.add(path(scarf, fill=soft("#E8B33A", wall, 0.3), sil=False), path(scarf, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    # his slippers by the rug
    for (sx, sy) in [(3350, -12), (3384, -8)]:
        rm.bg.add(ellipse(sx, sy, 16, 7, fill=soft("#7B3F8C", wall, 0.4, 0.75), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- dressing room
def dressing():
    rm = arch.Room("dressing")
    wall = rm.wall
    dado_y = -240
    arch.wall_base(rm)
    arch.pat_stripes(rm, geo.CORNICE, dado_y, w=16, gap=40, col=lift(wall, 0.1))
    arch.wainscot(rm, dado_y + 7, geo.SKIRT_TOP, panel_w=150, col=mul(wall, 0.84))
    arch.dado(rm, dado_y, col=lift(wall, 0.5))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    arch.floor_strip(rm)
    # a strip of red carpet (it is HIS dressing room)
    rug(rm, 3740, 4480, soft(pal.VELVET, wall, 0.35, 0.75), soft(pal.GOLD, wall, 0.25))
    arch.slab(rm)
    # the theatrical dressing mirror ringed with bulbs over a dressing table (MIRROR station at 4160)
    frame = sm("#E8D8B0", wall, 0.2, 0.9)
    rm.bg.add(sbox(rm, 4092, -524, 136, 176, 10, frame, bx=8, by=8))
    rm.bg.add(rect(4106, -510, 108, 148, 6, fill=lift("#CFE9F6", 0.25), sil=False))
    rm.bg.add(path(PB().M(4118, -500).L(4140, -500).L(4124, -430).L(4112, -430).Z(), fill="#FFFFFF", fop=0.5, sil=False))
    bulbs = PB()
    for i in range(5):
        bulbs.circle(4104 + i * 28, -524, 8).circle(4104 + i * 28, -348, 8)
    for j in range(4):
        bulbs.circle(4092, -490 + j * 40, 8).circle(4228, -490 + j * 40, 8)
    rm.bg.add(path(bulbs, fill="#FFF3C0", sil=False), path(bulbs, fill="none", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    g = rm.bg.grad(Grad(rm.gid("bulbglow"), "radial", (4160, -436, 180), [(0, "#FFF3C0", 0.3), (1, "#FFF3C0", 0.0)]))
    rm.bg.add(circle(4160, -436, 180, fill=g.url(), sil=False))
    table = sm("#9A5B3A", wall, 0.25, 0.85)
    rm.bg.add(sbox(rm, 4076, -206, 168, 22, 6, table, bx=0, by=6))
    rm.bg.add(line(4094, -184, 4102, -30, 9, ARCH, 0.8), line(4226, -184, 4218, -30, 9, ARCH, 0.8))
    rm.bg.add(line(4094, -184, 4102, -32, 4, table[0], 1.0), line(4226, -184, 4218, -32, 4, table[0], 1.0))
    # make-up pots + a powder puff on the table
    for (px, h, c) in [(4110, 22, "#F59AC0"), (4136, 16, "#FFE59A"), (4200, 26, "#9FD6F0")]:
        rm.bg.add(sbox(rm, px - 9, -206 - h, 18, h, 4, sm(c, wall, 0.2), bx=0, by=0))
    rm.bg.add(circle(4170, -214, 10, fill=soft("#FFE1EC", wall, 0.1), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    # a gold star on the wall + a playbill poster
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 34 if i % 2 == 0 else 14
        pts.append((3860 + r * math.cos(a), -520 + r * math.sin(a)))
    rm.bg.add(path(PB().poly(pts), fill=soft(pal.GOLD, wall, 0.2), sil=False), path(PB().poly(pts), fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, 3776, -420, 70, 100, 4, sm("#FFF4DC", wall, 0.15), bx=0, by=0))
    rm.bg.add(rect(3784, -410, 54, 36, 3, fill=soft(pal.VELVET, wall, 0.3), sil=False))
    rm.bg.add(slines(PB().M(3786, -360).L(3836, -360).M(3786, -346).L(3826, -346).M(3786, -334).L(3832, -334), SD, 0.55))
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- conservatory
def conservatory():
    rm = arch.Room("conservatory")
    glass = rm.wall
    # the back wall is glass: sky, a far hedge and the garden trees beyond
    g = rm.bg.grad(Grad(rm.gid("sky"), "linear", (0, geo.CEIL, 0, -60), [(0, mix(pal.SKY, "#FFFFFF", 0.2), None),
                                                                          (1, mix(glass, "#FFFFFF", 0.35), None)]))
    rm.bg.add(rect(rm.x0, geo.CEIL, rm.x1 - rm.x0, -geo.CEIL, fill=g.url(), sil=False))
    for (cx, cy, s) in [(4060, -560, 0.8), (4420, -590, 1.0)]:
        cl = PB().ellipse(cx, cy, 54 * s, 18 * s).ellipse(cx - 34 * s, cy + 4 * s, 30 * s, 14 * s).ellipse(cx + 38 * s, cy + 5 * s, 26 * s, 12 * s)
        rm.bg.add(path(cl, fill=lift(pal.SKY, 0.7), sil=False))
    trees = PB().M(rm.x0, -150).L(rm.x0, -250).Q(4000, -330, 4080, -270).Q(4160, -360, 4260, -280).Q(4360, -340, 4460, -260)
    trees.Q(4560, -330, rm.x1, -250).L(rm.x1, -150).Z()
    rm.bg.add(path(trees, fill=mix(pal.HEDGE, glass, 0.45), sil=False))
    hedge = PB().M(rm.x0, -150).L(rm.x0, -196).Q(4100, -230, 4300, -196).Q(4500, -236, rm.x1, -196).L(rm.x1, -150).Z()
    rm.bg.add(path(hedge, fill=mix(pal.HEDGE, glass, 0.3), sil=False))
    # glazing: white bars with a soft glass sheen
    bars = PB()
    x = rm.x0 + 20
    while x < rm.x1:
        bars.M(x, geo.CEIL).L(x, -150)
        x += 100
    bars.M(rm.x0, -400).L(rm.x1, -400)
    rm.bg.add(path(bars, fill="none", sw=12, stroke="#FFFFFF", sil=False), path(bars, fill="none", sw=2.5, stroke=ARCH, sop=0.5, sil=False))
    sheen = PB()
    x = rm.x0 + 36
    while x < rm.x1:
        sheen.M(x, -620).L(x + 26, -620).L(x + 8, -520).L(x - 4, -520).Z()
        x += 200
    rm.bg.add(path(sheen, fill="#FFFFFF", fop=0.35, sil=False))
    # brick dwarf wall with a stone coping
    rm.bg.add(rect(rm.x0, -150, rm.x1 - rm.x0, 122, fill=mix(pal.BRICK, glass, 0.4), sil=False))
    br = PB()
    for row, y in enumerate(range(-140, -30, 22)):
        off = 0 if row % 2 == 0 else 30
        x = rm.x0 + off
        br.M(rm.x0, y).L(rm.x1, y)
        while x < rm.x1:
            br.M(x, y).L(x, y + 22)
            x += 60
    rm.bg.add(path(br, fill="none", sw=2.0, stroke=mix(pal.BRICK_SH, glass, 0.35), sil=False))
    rm.bg.add(sbox(rm, rm.x0, -162, rm.x1 - rm.x0, 16, 3, sm(pal.STONE, glass, 0.15, 0.9), bx=0, by=5))
    arch.ceiling_shadow(rm, op=0.08)
    # terracotta tiles
    arch.floor_strip(rm, col=mix("#E0A080", glass, 0.25), sh=mul(mix("#E0A080", glass, 0.25), 0.84))
    arch.slab(rm)
    # plants on the coping: a fern and a spider plant
    for (px, kind) in [(4330, "fern"), (4660, "spider")]:
        pot = sm("#C86A4A", glass, 0.2, 0.9)
        rm.bg.add(sbox(rm, px - 18, -198, 36, 36, 6, pot, bx=5, by=0))
        leaves = PB()
        if kind == "fern":
            for a in (-70, -40, -12, 16, 44, 72):
                r = math.radians(a - 90)
                leaves.M(px, -198).Q(px + math.cos(r) * 30, -198 + math.sin(r) * 50, px + math.cos(r) * 58, -198 + math.sin(r) * 44)
        else:
            for a in (-60, -25, 10, 45, 80):
                r = math.radians(a - 90)
                leaves.M(px, -198).Q(px + math.cos(r) * 24, -198 + math.sin(r) * 30, px + math.cos(r) * 46, -190 + math.sin(r) * 10)
        rm.bg.add(path(leaves, fill="none", sw=7, stroke=ARCH, sop=0.7, sil=False),
                  path(leaves, fill="none", sw=4, stroke=soft("#6BBF59", glass, 0.15, 0.9), sil=False))
    # a hanging basket from the roof bar
    rm.bg.add(line(4100, -640, 4100, -470, 3, ARCH, 0.7), line(4080, -470, 4100, -520, 2.5, ARCH, 0.6), line(4120, -470, 4100, -520, 2.5, ARCH, 0.6))
    bask = PB().M(4072, -470).L(4128, -470).Q(4124, -440, 4100, -436).Q(4076, -440, 4072, -470).Z()
    rm.bg.add(path(bask, fill=soft("#C9A06A", glass, 0.2), sil=False), path(bask, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    trail = PB().M(4080, -466).Q(4070, -430, 4078, -400).M(4118, -466).Q(4130, -420, 4122, -392)
    rm.bg.add(path(trail, fill="none", sw=5, stroke=soft("#6BBF59", glass, 0.15, 0.9), sil=False))
    flw = PB().circle(4088, -474, 6).circle(4104, -478, 6).circle(4118, -472, 5)
    rm.bg.add(path(flw, fill=soft("#E86A7A", glass, 0.1), sil=False))
    # the sunbeam where Beryl dozes (4360) + the striped sun lounger (DRY station, 4480)
    arch.light_shaft(rm, 4300, -640, 110, 620, 60, 0.28, "sunbeam")
    canvas = sm("#F2D58A", glass, 0.2, 0.9)
    frame = sm("#FFFFFF", glass, 0.1)
    lounger = PB().M(4416, -104).L(4568, -124).L(4574, -92).L(4420, -76).Z()
    rm.bg.add(path(lounger, fill=canvas[0], sil=False))
    stripes = PB()
    for i in range(5):
        xa = 4430 + i * 30
        stripes.M(xa, -104 - i * 4).L(xa + 14, -106 - i * 4).L(xa + 14, -78 - i * 4).L(xa, -76 - i * 4).Z()
    rm.bg.add(path(stripes, fill=soft("#E86A7A", glass, 0.25), sil=False))
    rm.bg.add(path(lounger, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    back = PB().M(4416, -104).L(4390, -176).L(4404, -182).L(4432, -104).Z()
    rm.bg.add(path(back, fill=canvas[0], sil=False), path(back, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(line(4428, -80, 4434, -28, 7, ARCH, 0.8), line(4560, -94, 4556, -28, 7, ARCH, 0.8))
    rm.bg.add(line(4428, -80, 4434, -30, 3, frame[0], 1.0), line(4560, -94, 4556, -30, 3, frame[0], 1.0))
    # a watering can by the bench
    can = PB().M(4278, -24).L(4278, -60).Q(4300, -66, 4322, -60).L(4322, -24).Z()
    rm.bg.add(path(can, fill=soft("#7FA8D8", glass, 0.2), sil=False), path(can, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(line(4322, -50, 4354, -72, 5, ARCH, 0.8))
    arch.bands(rm, exterior_left=True)
    return rm


ROOMS = {"landing": landing, "bathroom": bathroom, "bedroom": bedroom, "dressing": dressing, "conservatory": conservatory}
