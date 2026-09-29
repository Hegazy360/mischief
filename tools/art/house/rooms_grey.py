"""rooms_grey - greybox backgrounds for the rooms outside the slice (landing, bathroom, bedroom,
dressing room, conservatory, garden): the right wallpaper colour + one quiet pattern, correct
doorways/stairwell, windows, and flat block silhouettes of the big non-interactive furniture
(3 px ARCH lines at 80 %, fills in the room's own desaturated tones). They are seen as the
"unlit backstage" above/beside the slice, so they must read as the right room at a glance and
stay calm. Final art replaces them in Stage 3 at the same paths.
"""
import math

import arch
import geo
import pal
from arch import AOP, ARCH, hline, vline
from svgk import PB, Grad, circle, ellipse, lift, mix, mul, path, rect, desat

LW = 3.0


def g_fill(rm, k=0.86):
    return desat(mul(rm.wall, k), 0.75)


def block(rm, x, y, w, h, r=6, k=0.86, fill=None):
    col = fill or g_fill(rm, k)
    rm.bg.add(rect(x, y, w, h, r, fill=col, sil=False))
    rm.bg.add(rect(x, y, w, h, r, fill="none", sw=LW, stroke=ARCH, sop=AOP, sil=False))


def gpath(rm, pb, k=0.86, fill=None):
    col = fill or g_fill(rm, k)
    rm.bg.add(path(pb, fill=col, sil=False), path(pb, fill="none", sw=LW, stroke=ARCH, sop=AOP, sil=False))


def gline(rm, pb, sw=2.5, op=0.6):
    rm.bg.add(path(pb, fill="none", sw=sw, stroke=ARCH, sop=op, sil=False))


def window(rm, x0, x1, top, bot, outside="#CFE9F6"):
    block(rm, x0 - 10, top - 10, x1 - x0 + 20, bot - top + 20, 6, fill=lift(rm.wall, 0.45))
    rm.bg.add(rect(x0, top, x1 - x0, bot - top, 4, fill=mix(outside, rm.wall, 0.25), sil=False))
    rm.bg.add(path(PB().M(x0 + 12, top + 10).L(x0 + 36, top + 10).L(x0 + 18, top + 80).L(x0 + 8, top + 80).Z(), fill="#FFFFFF", fop=0.45, sil=False))
    gline(rm, PB().M((x0 + x1) / 2, top).L((x0 + x1) / 2, bot).M(x0, (top + bot) / 2).L(x1, (top + bot) / 2), 3.0, 0.7)


def std(rm, pattern=None, dado_y=None, **kw):
    arch.standard_room(rm, pattern, dado_y, wains=dado_y is not None, pattern_kw=kw or None)


# ------------------------------------------------------------------------------- landing
def landing():
    rm = arch.Room("landing")
    std(rm, arch.pat_boards, dado_y=-250, step=46)
    # stairwell: the flight arrives from the hall below through the floor at x 1050-1300
    k = 700.0 / 400.0
    op0, op1 = 1050, 1300
    rm.bg.add(rect(op0, geo.BACK, op1 - op0, geo.SLAB_H - geo.BACK, fill="#3A2F40", sil=False))
    g = rm.bg.grad(Grad(rm.gid("well"), "linear", (0, 0, 0, geo.SLAB_H), [(0, pal.INK, 0.1), (1, pal.INK, 0.5)]))
    rm.bg.add(rect(op0, 0, op1 - op0, geo.SLAB_H, fill=g.url(), sil=False))
    # the top steps of the flight inside the slab: nosing y (rel. landing floor) = 700 - (1450 - x) * k
    saw = PB().M(1050, 0)
    run = 400.0 / 14
    for i in range(3):
        x = 1050 + run * i
        saw.L(x, 50.0 * i).L(x + run, 50.0 * i)
    saw.L(1050 + run * 3, geo.SLAB_H).L(1020, geo.SLAB_H).Z()
    gpath(rm, saw, 0.7)
    # balustrade round the opening + a newel at its far end
    rail = PB().M(1130, -170).L(op1, -170)
    rm.bg.add(path(rail, fill="none", sw=14, stroke=ARCH, sop=AOP, sil=False), path(rail, fill="none", sw=8, stroke=g_fill(rm, 0.7), sil=False))
    bal = PB()
    x = 1146
    while x < op1:
        bal.M(x, -168).L(x, geo.BACK)
        x += 26
    gline(rm, bal, 4, 0.6)
    block(rm, op1 - 8, -190, 18, 190 + geo.BACK, 4, 0.7)
    # radiator (DRY station) + window
    block(rm, 1392, -170, 120, 130, 8, 0.92)
    gline(rm, PB().M(1412, -160).L(1412, -50).M(1432, -160).L(1432, -50).M(1452, -160).L(1452, -50).M(1472, -160).L(1472, -50)
          .M(1492, -160).L(1492, -50), 3, 0.5)
    rm.bg.add(rect(1398, -40, 10, 14, 2, fill=g_fill(rm, 0.7), sil=False), rect(1496, -40, 10, 14, 2, fill=g_fill(rm, 0.7), sil=False))
    window(rm, 1590, 1710, -560, -300)
    arch.bands(rm, exterior_left=False)
    return rm


# ------------------------------------------------------------------------------- bathroom
def bathroom():
    rm = arch.Room("bathroom")
    arch.wall_base(rm)
    arch.pat_tiles(rm, -330, geo.SKIRT_TOP, 44, lift(rm.wall, 0.3), mul(rm.wall, 0.94))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    arch.floor_strip(rm, col=mix("#FFFFFF", rm.wall, 0.4), sh=mul(rm.wall, 0.85))
    arch.slab(rm)
    # pedestal basin + mirror cabinet over it (SINK + MIRROR station at 1930)
    block(rm, 1870, -520, 120, 150, 8, 0.8)
    rm.bg.add(rect(1884, -506, 92, 122, 6, fill=lift("#CFE9F6", 0.2), sil=False))
    gpath(rm, PB().M(1904, -180).L(1956, -180).L(1948, -30).L(1912, -30).Z(), 0.95)
    block(rm, 1868, -214, 124, 40, 16, 0.96)
    # scales on the floor + a towel rail
    block(rm, 2248, -42, 64, 22, 6, 0.8)
    rm.bg.add(circle(2280, -32, 7, fill=lift(rm.wall, 0.4), sil=False))
    block(rm, 2180, -330, 90, 10, 4, 0.7)
    gpath(rm, PB().M(2190, -322).L(2260, -322).L(2254, -220).L(2196, -220).Z(), 0.9, fill=mix("#F2B8C8", rm.wall, 0.4))
    # shower curtain rail above the bath
    gline(rm, PB().M(2306, -560).L(2604, -560), 5, 0.7)
    gpath(rm, PB().M(2310, -556).L(2352, -556).Q(2340, -400, 2330, -250).L(2308, -250).Z(), 0.95, fill=mix("#FFFFFF", rm.wall, 0.3))
    window(rm, 2440, 2560, -600, -430)
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- bedroom
def bedroom():
    rm = arch.Room("bedroom")
    std(rm, arch.pat_dots, dado_y=None, step=52, r=4)
    window(rm, 3090, 3230, -590, -400)
    # curtains
    for xa in (3060, 3236):
        gpath(rm, PB().M(xa, -606).L(xa + 30, -606).Q(xa + 22, -500, xa + 28, -380).L(xa + 2, -380).Z(), 0.8)
    # hat stand (the BUTTER-FINGERS dance partner) at 3590
    gline(rm, PB().M(3590, -30).L(3590, -420), 10, 0.75)
    gpath(rm, PB().M(3550, -30).Q(3590, -60, 3630, -30).Z(), 0.7)
    gpath(rm, PB().M(3560, -410).L(3620, -410).L(3610, -440).L(3570, -440).Z(), 0.7)
    block(rm, 3548, -414, 84, 8, 4, 0.6)
    # a rug beside the bed
    rm.bg.add(path(PB().M(3060, geo.BACK + 4).L(3300, geo.BACK + 4).L(3312, -4).L(3048, -4).Z(), fill=mix("#E8A0B8", rm.wall, 0.45), sil=False))
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- dressing room
def dressing():
    rm = arch.Room("dressing")
    std(rm, arch.pat_stripes, dado_y=-240, w=16, gap=40)
    # the theatrical dressing mirror with bulbs (MIRROR station at 4160)
    block(rm, 4094, -520, 132, 170, 10, 0.75)
    rm.bg.add(rect(4108, -506, 104, 142, 6, fill=lift("#CFE9F6", 0.25), sil=False))
    bulbs = PB()
    for i in range(5):
        bulbs.circle(4104 + i * 28, -520, 7).circle(4104 + i * 28, -350, 7)
    rm.bg.add(path(bulbs, fill="#FFF3C0", sil=False), path(bulbs, fill="none", sw=2.5, stroke=ARCH, sop=AOP, sil=False))
    block(rm, 4080, -200, 160, 20, 6, 0.8)
    gpath(rm, PB().M(4096, -180).L(4104, -30).M(4224, -180).L(4216, -30), 0.8)
    gline(rm, PB().M(4096, -180).L(4104, -30).M(4224, -180).L(4216, -30), 8, 0.7)
    # a star on the wall (it is HIS dressing room)
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 34 if i % 2 == 0 else 14
        pts.append((3860 + r * math.cos(a), -520 + r * math.sin(a)))
    gpath(rm, PB().poly(pts), 0.9, fill=mix(pal.GOLD, rm.wall, 0.35))
    arch.bands(rm)
    return rm


# ------------------------------------------------------------------------------- conservatory
def conservatory():
    rm = arch.Room("conservatory")
    glass = rm.wall
    # the back wall is glass: the garden and sky beyond
    g = rm.bg.grad(Grad(rm.gid("sky"), "linear", (0, geo.CEIL, 0, -60), [(0, mix(pal.SKY, "#FFFFFF", 0.25), None), (1, mix(glass, "#FFFFFF", 0.3), None)]))
    rm.bg.add(rect(rm.x0, geo.CEIL, rm.x1 - rm.x0, -geo.CEIL, fill=g.url(), sil=False))
    rm.bg.add(path(PB().M(rm.x0, -140).Q(4100, -230, 4300, -170).Q(4500, -250, rm.x1, -160).L(rm.x1, -60).L(rm.x0, -60).Z(),
                   fill=mix(pal.HEDGE, glass, 0.55), sil=False))
    # brick dwarf wall + glazing bars
    rm.bg.add(rect(rm.x0, -150, rm.x1 - rm.x0, 122, fill=mix(pal.BRICK, glass, 0.45), sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, -150))
    bars = PB()
    x = rm.x0 + 20
    while x < rm.x1:
        bars.M(x, geo.CEIL).L(x, -150)
        x += 100
    bars.M(rm.x0, -400).L(rm.x1, -400)
    rm.bg.add(path(bars, fill="none", sw=10, stroke="#FFFFFF", sil=False), path(bars, fill="none", sw=2.5, stroke=ARCH, sop=0.5, sil=False))
    arch.ceiling_shadow(rm, op=0.08)
    arch.floor_strip(rm, col=mix("#E0A080", glass, 0.3), sh=mul(mix("#E0A080", glass, 0.3), 0.85))
    arch.slab(rm)
    # the sunbeam where Beryl dozes (4360) + the sun lounger (DRY station, 4480)
    arch.light_shaft(rm, 4300, -640, 110, 620, 60, 0.28, "sunbeam")
    gpath(rm, PB().M(4420, -110).L(4560, -130).L(4566, -96).L(4424, -80).Z(), 0.95, fill=mix("#F2D58A", glass, 0.3))
    gline(rm, PB().M(4430, -84).L(4436, -28).M(4556, -100).L(4552, -28).M(4420, -110).L(4400, -170), 6, 0.7)
    arch.bands(rm, exterior_left=True)
    return rm


# ------------------------------------------------------------------------------- garden
def garden():
    rm = arch.Room("garden")
    g = rm.bg.grad(Grad(rm.gid("sky"), "linear", (0, geo.CEIL, 0, -120), [(0, mix(pal.SKY, "#6FB8E0", 0.35), None), (1, lift(pal.SKY, 0.45), None)]))
    rm.bg.add(rect(rm.x0, geo.CEIL, rm.x1 - rm.x0, -geo.CEIL, fill=g.url(), sil=False))
    for (cx, cy, s) in [(4900, -560, 1.0), (5400, -600, 0.7), (5900, -520, 0.9)]:
        pb = PB().ellipse(cx, cy, 60 * s, 22 * s).ellipse(cx - 40 * s, cy + 4 * s, 34 * s, 18 * s).ellipse(cx + 44 * s, cy + 6 * s, 30 * s, 16 * s)
        rm.bg.add(path(pb, fill=lift(pal.SKY, 0.65), sil=False))
    # back fence (boards) with the gate at 6150
    fence = mix("#C9A27A", pal.SKY, 0.2)
    rm.bg.add(rect(rm.x0, -260, rm.x1 - rm.x0, 232, fill=fence, sil=False))
    boards = PB()
    x = rm.x0 + 30
    while x < rm.x1:
        boards.M(x, -260).L(x, -28)
        x += 30
    gline(rm, boards, 2.0, 0.35)
    rm.bg.add(hline(rm.x0, rm.x1, -260, 3, 0.7))
    tops = PB()
    x = rm.x0
    while x < rm.x1:
        tops.M(x, -260).L(x + 15, -276).L(x + 30, -260)
        x += 30
    rm.bg.add(path(tops, fill=fence, sil=False), path(tops, fill="none", sw=2.5, stroke=ARCH, sop=0.6, sil=False))
    block(rm, 6106, -300, 90, 272, 4, fill=mul(fence, 0.85))
    gline(rm, PB().M(6116, -150).L(6186, -210).M(6116, -210).L(6186, -150), 3, 0.6)
    # lawn strip + the stone path (5260-5560) + earth slab
    rm.bg.add(rect(rm.x0, geo.BACK - 10, rm.x1 - rm.x0, -geo.BACK + 10, fill=pal.LAWN, sil=False))
    stones = PB()
    for i, x in enumerate(range(5250, 5580, 56)):
        stones.ellipse(x + 20, -18, 24, 8)
    rm.bg.add(path(stones, fill=mix(pal.STONE, "#FFFFFF", 0.2), sil=False), path(stones, fill="none", sw=2.5, stroke=ARCH, sop=0.6, sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, 0, 3, 0.8))
    arch.slab(rm, kind="earth")
    # rose bushes (5000) + the pond (6060)
    for (bx, by) in [(4990, -120), (5030, -150), (5060, -110)]:
        rm.bg.add(circle(bx, by, 40, fill=mix(pal.HEDGE, pal.LAWN, 0.3), sw=LW, stroke=ARCH, sop=AOP, sil=False))
    roses = PB()
    for (rx, ry) in [(4976, -140), (5020, -176), (5052, -126), (5000, -100), (5072, -160)]:
        roses.circle(rx, ry, 9)
    rm.bg.add(path(roses, fill="#E86A7A", sil=False), path(roses, fill="none", sw=2.0, stroke=ARCH, sop=0.6, sil=False))
    rm.bg.add(ellipse(6056, -12, 110, 14, fill="#6FB8D8", sw=LW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(ellipse(6030, -14, 30, 4, fill="#FFFFFF", fop=0.5, sil=False))
    # only the left band (the conservatory's glazed end wall); the garden runs on to the proscenium
    arch.band(rm, -1, exterior=False, gap=(geo.DOOR_TOP, 0))
    return rm


ROOMS = {"landing": landing, "bathroom": bathroom, "bedroom": bedroom, "dressing": dressing, "conservatory": conservatory, "garden": garden}
