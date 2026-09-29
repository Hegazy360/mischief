"""rooms_final - final-quality backgrounds for the slice rooms: porch, hall, parlour, kitchen.

Only non-interactive set dressing lives here (4 px lines, soft ARCH ink at 80 %, fills mixed
toward the wall so the room stays pastel); every interactable is a separate prop sprite
(props_*.py), drawn on top by the view.
"""
import math

import arch
import draw
import geo
import pal
from arch import AOP, AW, ARCH, aline, hline, vline
from svgk import PB, Grad, circle, ellipse, lift, mix, mul, path, rect, desat

SW = pal.LW_SET          # set dressing 4 px
SD = pal.LW_SET_D        # detail 2.5 px


def soft(col, room_wall, t=0.25, sat=0.8):
    """Set-dressing colour: pulled toward the wall and desaturated (stays behind the props)."""
    return desat(mix(col, room_wall, t), sat)


def sm(col, wall, t=0.25, sat=0.8, k=0.84):
    b = soft(col, wall, t, sat)
    return (b, mul(b, k), lift(b, 0.4))


def sbox(rm, x, y, w, h, r, col, hi=False, bx=None, by=None):
    return draw.box(x, y, w, h, r, col, SW, ARCH, AOP, bx=bx, by=by, hi=hi)


def slines(pb, sw=SD, op=0.7):
    return path(pb, fill="none", sw=sw, stroke=ARCH, sop=op, sil=False)


def shadow_rect(x, y, w, h, op=0.12):
    return rect(x, y, w, h, 6, fill=pal.INK, fop=op, sil=False)


# =============================================================================== KITCHEN

def kitchen():
    rm = arch.Room("kitchen")
    wall = rm.wall
    arch.wall_base(rm)
    arch.pat_gingham(rm, geo.CORNICE, geo.SKIRT_TOP, step=44, col=mul(wall, 0.965))
    # splashback tiles behind the tea counter + pickle shelf, and under the window at the sink
    tile = lift(wall, 0.55)
    arch.pat_tiles(rm, -430, -196, 36, tile, mix(wall, "#FFFFFF", 0.1), x0=2844, x1=3196)
    arch.pat_tiles(rm, -352, -196, 36, tile, mix(wall, "#FFFFFF", 0.1), x0=3700, x1=3880)
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    # checker lino floor strip
    kitchen_floor(rm)
    arch.slab(rm)

    wood = sm("#8FBFA8", wall, 0.2, 0.75)          # soft sage-mint cabinets
    top = sm("#E9E2D2", wall, 0.1, 0.9)            # worktop
    # --- tea counter (x 2848-3044) -----------------------------------------------------
    counter(rm, 2848, 3044, wood, top)
    shelf(rm, 2852, 3040, -356, wood[0])
    # a couple of soft tins on the tea shelf ends (behind the honey prop)
    tin(rm, 2872, -356, 20, 34, sm("#D98A6A", wall))
    tin(rm, 3018, -356, 18, 28, sm("#7FA8D8", wall))
    # --- pickle shelf (x 3044-3190) ----------------------------------------------------
    shelf(rm, 3040, 3192, -336, wood[0])
    jar_bg(rm, 3062, -336, 24, 46, sm("#B7D48A", wall))
    jar_bg(rm, 3166, -336, 22, 40, sm("#E6A24C", wall))
    # --- pantry alcove frame (x 3540-3700) ------------------------------------------------
    alcove(rm, 3538, 3702, -580, wood)
    # --- sink cabinet (x 3704-3872) ------------------------------------------------------
    counter(rm, 3704, 3872, wood, top, doors=1)
    # window frame recess behind the window prop
    rm.bg.add(rect(3726, -598, 124, 232, 8, fill=mul(wall, 0.86), sil=False))
    # --- pendant lamp above the table, and a wall clock -----------------------------------
    pendant(rm, 3450, -640, -540, sm("#E8C16A", wall, 0.15, 0.9))
    wall_clock(rm, 3276, -560, 30, sm("#E07F5C", wall))
    # window light shaft (top-left light) from the sink window, falling right on the floor
    arch.light_shaft(rm, 3730, -590, 110, 560, 90, 0.10)
    # plates on a little rail between the doorway and the counter (set dressing, readable warmth)
    plate_rail(rm, 2836, 3040, -520, wall)
    arch.bands(rm)
    return rm


def kitchen_floor(rm):
    y0 = geo.BACK
    a = mix(pal.OAK, "#FFF0D0", 0.55)
    b = mix(pal.OAK, "#B0704A", 0.35)
    rm.bg.add(rect(rm.x0, y0, rm.x1 - rm.x0, -y0, fill=a, sil=False))
    pb = PB()
    step = 56
    x = rm.x0
    i = 0
    while x < rm.x1:
        # two rows of checks in the 28 px strip, in slight perspective
        if i % 2 == 0:
            pb.M(x, y0).L(x + step / 2, y0).L(x + step / 2 + 2, y0 + 14).L(x + 2, y0 + 14).Z()
        else:
            pb.M(x + 2, y0 + 14).L(x + step / 2 + 2, y0 + 14).L(x + step / 2 + 4, 0).L(x + 4, 0).Z()
        x += step / 2
        i += 1
    rm.bg.add(path(pb, fill=b, fop=0.8, sil=False))
    rm.bg.add(rect(rm.x0, y0, rm.x1 - rm.x0, 5, fill=pal.OAK_SH, fop=0.5, sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, 0, 3.0, 0.8))


def counter(rm, x0, x1, wood, top, doors=2):
    w = x1 - x0
    rm.bg.add(shadow_rect(x0 + 6, -20, w, 20, 0.1))
    rm.bg.add(sbox(rm, x0 + 6, -186, w - 12, 166, 6, wood, bx=10, by=10))
    # doors
    dw = (w - 12 - 18) / doors
    for i in range(doors):
        dx = x0 + 6 + 9 + i * dw
        rm.bg.add(rect(dx + 3, -170, dw - 6, 128, 5, fill="none", sw=SD, stroke=ARCH, sop=0.6, sil=False))
        kx = dx + (dw - 18 if i % 2 == 0 else 12)
        rm.bg.add(circle(kx, -110, 5, fill=mix(pal.BRASS[0], rm.wall, 0.3), sw=2.0, stroke=ARCH, sop=0.7, sil=False))
    # kick plate
    rm.bg.add(rect(x0 + 10, -40, w - 20, 16, 3, fill=wood[1], sil=False))
    # worktop
    rm.bg.add(sbox(rm, x0, -200, w, 18, 5, top, bx=0, by=6))


def shelf(rm, x0, x1, y, col):
    rm.bg.add(rect(x0, y, x1 - x0, 12, 4, fill=col, sil=False))
    rm.bg.add(rect(x0, y, x1 - x0, 12, 4, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    for bx in (x0 + 18, x1 - 30):
        rm.bg.add(path(PB().M(bx, y + 12).L(bx + 12, y + 12).L(bx + 12, y + 30).Z(), fill=mul(col, 0.85), sil=False))
        rm.bg.add(path(PB().M(bx, y + 12).L(bx + 12, y + 12).L(bx + 12, y + 30).Z(), fill="none", sw=SD, stroke=ARCH,
                       sop=AOP, sil=False))


def tin(rm, cx, base_y, w, h, m):
    rm.bg.add(sbox(rm, cx - w / 2, base_y - h, w, h, 4, m, bx=5, by=0))
    rm.bg.add(rect(cx - w / 2 - 2, base_y - h - 5, w + 4, 7, 3, fill=m[1], sw=SD, stroke=ARCH, sop=AOP, sil=False))


def jar_bg(rm, cx, base_y, w, h, m):
    rm.bg.add(sbox(rm, cx - w / 2, base_y - h, w, h, 8, m, bx=6, by=0))
    rm.bg.add(rect(cx - w / 2 + 2, base_y - h - 7, w - 4, 8, 3, fill=mix(pal.BRASS[0], rm.wall, 0.35), sw=SD, stroke=ARCH,
                   sop=AOP, sil=False))


def alcove(rm, x0, x1, top, wood):
    """Architrave + recess for the pantry cupboard/curtain props."""
    dark = mul(rm.wall, 0.72)
    rm.bg.add(rect(x0 + 10, top + 10, x1 - x0 - 20, -top - 10 - 28, 6, fill=dark, sil=False))
    g = rm.bg.grad(Grad(rm.gid("alcove"), "linear", (0, top, 0, 0), [(0, pal.INK, 0.25), (1, pal.INK, 0.05)]))
    rm.bg.add(rect(x0 + 10, top + 10, x1 - x0 - 20, -top - 10 - 28, 6, fill=g.url(), sil=False))
    cas = soft("#F4EAD2", rm.wall, 0.15)
    pb = PB().M(x0, -28).L(x0, top + 8).Q(x0, top, x0 + 8, top).L(x1 - 8, top).Q(x1, top, x1, top + 8).L(x1, -28)
    pb.L(x1 - 12, -28).L(x1 - 12, top + 12).L(x0 + 12, top + 12).L(x0 + 12, -28).Z()
    rm.bg.add(path(pb, fill=cas, sil=False), path(pb, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))


def pendant(rm, x, y_ceil, y_lamp, m):
    rm.bg.add(line(x, y_ceil, x, y_lamp - 26, 3, ARCH, sop=0.8))
    pb = PB().M(x - 44, y_lamp).Q(x - 38, y_lamp - 34, x, y_lamp - 36).Q(x + 38, y_lamp - 34, x + 44, y_lamp).Z()
    rm.bg.add(path(pb, fill=m[0], sil=False), path(PB().M(x + 10, y_lamp - 33).Q(x + 36, y_lamp - 30, x + 44, y_lamp)
                                                     .L(x + 20, y_lamp).Z(), fill=m[1], sil=False))
    rm.bg.add(path(pb, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(ellipse(x, y_lamp + 4, 14, 8, fill="#FFF6D8", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    g = rm.bg.grad(Grad(rm.gid("lampglow%d" % x), "radial", (x, y_lamp + 20, 150), [(0, "#FFF4C8", 0.35), (1, "#FFF4C8", 0.0)]))
    rm.bg.add(circle(x, y_lamp + 20, 150, fill=g.url(), sil=False))


def line(x1, y1, x2, y2, sw, col, sop=None):
    return path(PB().M(x1, y1).L(x2, y2), fill="none", sw=sw, stroke=col, sop=sop, sil=False)


def wall_clock(rm, cx, cy, r, m):
    rm.bg.add(circle(cx + 3, cy + 4, r, fill=pal.INK, fop=0.1, sil=False))
    rm.bg.add(circle(cx, cy, r, fill=m[0], sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(circle(cx, cy, r - 7, fill="#FFF8EA", sw=SD, stroke=ARCH, sop=0.6, sil=False))
    rm.bg.add(line(cx, cy, cx, cy - 15, 3, ARCH, 0.85), line(cx, cy, cx + 11, cy + 4, 3, ARCH, 0.85))


def plate_rail(rm, x0, x1, y, wall):
    rm.bg.add(rect(x0, y, x1 - x0, 10, 3, fill=soft("#B98A5E", wall), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    cols = ["#7FB0D8", "#E3A07C", "#9CCB8E", "#E8C46A"]
    x = x0 + 34
    i = 0
    while x < x1 - 20:
        c = soft(cols[i % 4], wall, 0.25, 0.75)
        rm.bg.add(ellipse(x, y - 22, 22, 24, fill=c, sw=SD, stroke=ARCH, sop=AOP, sil=False))
        rm.bg.add(ellipse(x, y - 22, 12, 13, fill=mix(c, "#FFFFFF", 0.35), sil=False))
        x += 52
        i += 1


# =============================================================================== HALL
STAIR_FOOT, STAIR_HEAD = 1450, 1050      # x at the ground floor line / at the landing line (y -700)
N_STEPS = 14


def stair_pts():
    """Sawtooth of the flight: from the foot (1450, 0) up-left to (1050, -700)."""
    run = (STAIR_FOOT - STAIR_HEAD) / N_STEPS
    rise = 700.0 / N_STEPS
    pts = [(STAIR_FOOT + 6, 0)]
    for i in range(N_STEPS):
        x = STAIR_FOOT - run * i
        pts.append((x, -rise * (i + 1)))
        pts.append((x - run, -rise * (i + 1)))
    return pts, run, rise


def stairs(rm, clip_top=geo.CEIL, floor_y=0.0):
    """The staircase band on the back wall (the view walks Hush/Bellows along it). The flight rises to
    the LEFT: nosings on the line y = -(1450 - x) * 1.75; the stringer's underside runs parallel,
    T px lower (so it meets the floor left of the foot)."""
    pts, run, rise = stair_pts()
    wall = rm.wall
    wood = sm("#A0714E", wall, 0.15, 0.85)
    runner = sm("#B85A5E", wall, 0.25, 0.75)
    k = 700.0 / (STAIR_FOOT - STAIR_HEAD)
    T = 96.0

    def nose_y(x):
        return -(STAIR_FOOT - x) * k

    s_pts = [p for p in pts if p[1] >= clip_top - 0.1]
    top_tread_x = s_pts[-1][0]
    x_under_top = STAIR_FOOT - (-clip_top + T) / k
    x_under_floor = STAIR_FOOT - T / k
    # soft shadow the flight casts on the wall (light from the top-left -> shadow to the lower right)
    sh = PB().M(STAIR_FOOT + 20, 0)
    for p in s_pts:
        sh.L(p[0] + 18, p[1] + 14)
    sh.L(x_under_top + 18, clip_top).L(x_under_floor + 18, 0).Z()
    rm.bg.add(path(sh, fill=pal.INK, fop=0.07, sil=False))
    # the solid flight: sawtooth (upper right) + the stringer underside (lower left)
    pb = PB().M(STAIR_FOOT + 6, 0)
    for p in s_pts:
        pb.L(*p)
    pb.L(top_tread_x, clip_top).L(x_under_top, clip_top).L(x_under_floor, 0).Z()
    rm.bg.add(path(pb, fill=wood[1], sil=False))
    # outer stringer board (lighter band along the underside)
    sb = PB().M(x_under_floor, 0).L(x_under_top, clip_top).L(x_under_top + 30, clip_top).L(x_under_floor + 30, 0).Z()
    rm.bg.add(path(sb, fill=wood[0], sil=False))
    # tread tops (lit) + runner carpet + riser faces
    tr = PB()
    rn = PB()
    rs = PB()
    for i in range(len(s_pts) - 1):
        a, b = s_pts[i], s_pts[i + 1]
        if abs(a[1] - b[1]) < 0.1:          # tread from a (right) to b (left)
            tr.M(a[0], a[1]).L(b[0], b[1]).L(b[0], b[1] + 7).L(a[0], a[1] + 7).Z()
            rn.M(a[0] - 1, a[1] + 1).L(b[0] + 3, b[1] + 1).L(b[0] + 3, b[1] + 26).L(a[0] - 1, a[1] + 26).Z()
        else:                                # riser (vertical face, faces right)
            rs.M(a[0], a[1]).L(b[0], b[1]).L(b[0] - 8, b[1]).L(a[0] - 8, a[1]).Z()
    rm.bg.add(path(rs, fill=wood[2], fop=0.35, sil=False))
    rm.bg.add(path(rn, fill=runner[0], sil=False))
    rm.bg.add(path(tr, fill=wood[0], sil=False))
    saw = PB().M(*s_pts[0])
    for p in s_pts[1:]:
        saw.L(*p)
    rm.bg.add(path(saw, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(PB().M(x_under_floor, 0).L(x_under_top, clip_top), fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(PB().M(x_under_floor + 30, 0).L(x_under_top + 30, clip_top), fill="none", sw=SD, stroke=ARCH, sop=0.5, sil=False))
    # banister: balusters from each tread up to a handrail 170 px above the nosing line
    H = 170.0
    bal = PB()
    for i in range(1, N_STEPS + 1):
        x = STAIR_FOOT - run * (i - 0.5)
        y_tread = -rise * i
        y_rail = nose_y(x) - H
        if y_rail < clip_top + 4:
            break
        bal.M(x, y_tread).L(x, y_rail)
    rm.bg.add(path(bal, fill="none", sw=6, stroke=ARCH, sop=0.55, sil=False))
    rm.bg.add(path(bal, fill="none", sw=3, stroke=mix(wood[0], "#FFFFFF", 0.1), sil=False))
    x_rail_top = STAIR_FOOT - (-clip_top - H) / k
    hr = PB().M(STAIR_FOOT - 4, nose_y(STAIR_FOOT - 4) - H).L(x_rail_top, clip_top)
    rm.bg.add(path(hr, fill="none", sw=16, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(hr, fill="none", sw=9, stroke=wood[0], sil=False))


def phone_table(rm, cx):
    wall = rm.wall
    wood = sm("#9A5B3A", wall, 0.15, 0.85)
    rm.bg.add(shadow_rect(cx - 56, -22, 112, 18, 0.1))
    for lx in (cx - 44, cx + 36):
        rm.bg.add(rect(lx, -196, 10, 176, 4, fill=wood[1], sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, cx - 54, -80, 108, 12, 5, wood, by=4, bx=0))
    rm.bg.add(sbox(rm, cx - 60, -210, 120, 16, 6, wood, by=5, bx=0))


def frame_pic(rm, x, y, w, h, scene_cols, gold=None):
    wall = rm.wall
    gold = gold or sm(pal.GOLD, wall, 0.2, 0.8)
    rm.bg.add(rect(x + 4, y + 5, w, h, 5, fill=pal.INK, fop=0.1, sil=False))
    rm.bg.add(sbox(rm, x, y, w, h, 5, gold, bx=6, by=6))
    ix, iy, iw, ih = x + 12, y + 12, w - 24, h - 24
    rm.bg.add(rect(ix, iy, iw, ih, 3, fill=scene_cols[0], sil=False))
    rm.bg.add(path(PB().M(ix, iy + ih).L(ix, iy + ih * 0.62).Q(ix + iw * 0.3, iy + ih * 0.4, ix + iw * 0.55, iy + ih * 0.6)
                   .Q(ix + iw * 0.8, iy + ih * 0.45, ix + iw, iy + ih * 0.55).L(ix + iw, iy + ih).Z(), fill=scene_cols[1], sil=False))
    rm.bg.add(circle(ix + iw * 0.75, iy + ih * 0.3, min(iw, ih) * 0.12, fill=scene_cols[2], sil=False))
    rm.bg.add(rect(ix, iy, iw, ih, 3, fill="none", sw=SD, stroke=ARCH, sop=0.6, sil=False))


def runner_rug(rm, x0, x1, col, border):
    y0 = geo.BACK + 3
    rm.bg.add(path(PB().M(x0 + 10, y0).L(x1 - 10, y0).L(x1, -3).L(x0, -3).Z(), fill=col, sil=False))
    rm.bg.add(path(PB().M(x0 + 16, y0 + 5).L(x1 - 16, y0 + 5).L(x1 - 8, -8).L(x0 + 8, -8).Z(), fill="none", sw=2.5, stroke=border, sil=False))
    rm.bg.add(path(PB().M(x0 + 10, y0).L(x1 - 10, y0).L(x1, -3).L(x0, -3).Z(), fill="none", sw=2.5, stroke=ARCH, sop=0.6, sil=False))


def hall():
    rm = arch.Room("hall")
    wall = rm.wall
    t = rm.t
    dado_y = -250
    arch.wall_base(rm)
    arch.pat_stripes(rm, geo.CORNICE, dado_y, w=22, gap=30, col=lift(wall, 0.08))
    arch.wainscot(rm, dado_y + 7, geo.SKIRT_TOP, panel_w=160, col=mul(wall, 0.86))
    arch.dado(rm, dado_y, col=lift(wall, 0.45))
    arch.ceiling_shadow(rm)
    arch.cornice(rm)
    arch.skirting(rm)
    arch.floor_strip(rm)
    runner_rug(rm, 560, 1390, soft("#5E8C84", wall, 0.25), lift(soft("#5E8C84", wall, 0.25), 0.3))
    arch.slab(rm)
    # stairwell: the ceiling opens above the top of the flight (a soft dark well)
    k = 700.0 / (STAIR_FOOT - STAIR_HEAD)
    x_ceil = STAIR_FOOT - 640 / k
    g = rm.bg.grad(Grad(rm.gid("well"), "linear", (0, geo.CEIL, 0, geo.CEIL + 160), [(0, pal.INK, 0.28), (1, pal.INK, 0.0)]))
    rm.bg.add(path(PB().M(x_ceil - 60, geo.CEIL).L(x_ceil + 230, geo.CEIL).L(x_ceil + 150, geo.CEIL + 160).L(x_ceil - 20, geo.CEIL + 160).Z(),
                   fill=g.url(), sil=False))
    stairs(rm)
    phone_table(rm, 944)
    frame_pic(rm, 780, -596, 124, 92, (soft("#BFE0EE", wall, 0.1), soft("#8CC07A", wall, 0.2), soft("#F4D06A", wall, 0.1)))
    pendant(rm, 690, -640, -566, sm("#E8C16A", wall, 0.15, 0.9))
    arch.bands(rm)
    return rm


# =============================================================================== PARLOUR
def window_drapes(rm, x0, x1, top, sill, drape):
    wall = rm.wall
    frame = sm("#FFFFFF", wall, 0.12, 0.9)
    sky = soft("#BFE6F5", wall, 0.1, 0.95)
    rm.bg.add(rect(x0 - 10, top - 10, x1 - x0 + 20, sill - top + 20, 8, fill=pal.INK, fop=0.08, sil=False))
    rm.bg.add(sbox(rm, x0, top, x1 - x0, sill - top, 6, frame, bx=0, by=0))
    rm.bg.add(rect(x0 + 12, top + 12, x1 - x0 - 24, sill - top - 24, 4, fill=sky, sil=False))
    # street outside: the roofline of No. 11 and a lamp post (soft)
    rm.bg.add(path(PB().M(x0 + 12, sill - 12).L(x0 + 12, top + 150).L(x0 + 60, top + 110).L(x0 + 110, top + 150).L(x1 - 12, top + 150)
                   .L(x1 - 12, sill - 12).Z(), fill=soft("#C99A8C", wall, 0.35, 0.7), sil=False))
    rm.bg.add(path(PB().M(x0 + 28, top + 24).L(x0 + 60, top + 24).L(x0 + 36, top + 100).L(x0 + 20, top + 100).Z(), fill="#FFFFFF", fop=0.5, sil=False))
    rm.bg.add(slines(PB().M((x0 + x1) / 2, top + 12).L((x0 + x1) / 2, sill - 12).M(x0 + 12, (top + sill) / 2).L(x1 - 12, (top + sill) / 2), 3.0, 0.7))
    rm.bg.add(sbox(rm, x0 - 14, sill - 2, x1 - x0 + 28, 14, 5, frame, bx=0, by=4))
    # velvet drapes + pelmet
    for sgn, xa in ((-1, x0 - 30), (1, x1 - 20)):
        pb = PB().M(xa, top - 16).L(xa + 50, top - 16).Q(xa + 30 + sgn * 6, (top + sill) / 2, xa + 44 + sgn * 10, sill + 70).L(xa + 4, sill + 70).Q(
            xa - 4, (top + sill) / 2, xa, top - 16).Z()
        rm.bg.add(path(pb, fill=drape[0], sil=False))
        rm.bg.add(slines(PB().M(xa + 18, top).Q(xa + 14, (top + sill) / 2, xa + 22, sill + 64).M(xa + 34, top).Q(xa + 30, (top + sill) / 2, xa + 36,
                                                                                                            sill + 66), SD, 0.5))
        rm.bg.add(path(pb, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
        rm.bg.add(ellipse(xa + 26, (top + sill) / 2 + 30, 16, 8, fill=sm(pal.GOLD, wall, 0.2)[0], sw=SD, stroke=ARCH, sop=AOP, sil=False))
    pel = PB().M(x0 - 40, top - 34).L(x1 + 40, top - 34).L(x1 + 40, top - 4)
    for i in range(6):
        xa = x1 + 40 - (i + 0.5) * (x1 - x0 + 80) / 6
        xb = x1 + 40 - (i + 1) * (x1 - x0 + 80) / 6
        pel.Q(xa, top + 16, xb, top - 4)
    pel.Z()
    rm.bg.add(path(pel, fill=drape[1], sil=False), path(pel, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))


def fireplace(rm, cx, mantel_y):
    wall = rm.wall
    marble = sm("#F1E9E4", wall, 0.12, 0.9)
    x0, x1 = cx - 130, cx + 130
    rm.bg.add(rect(x0 - 4, mantel_y, x1 - x0 + 8, -mantel_y - 24, 6, fill=pal.INK, fop=0.08, sil=False))
    # jambs + frieze
    rm.bg.add(sbox(rm, x0 + 8, mantel_y + 12, 44, -mantel_y - 36, 6, marble, bx=8, by=0))
    rm.bg.add(sbox(rm, x1 - 52, mantel_y + 12, 44, -mantel_y - 36, 6, marble, bx=8, by=0))
    rm.bg.add(sbox(rm, x0 + 8, mantel_y + 12, x1 - x0 - 16, 50, 6, marble, bx=0, by=10))
    # firebox (arched) with glowing logs
    fb0, fb1 = x0 + 52, x1 - 52
    arch_top = mantel_y + 70
    pb = PB().M(fb0, -24).L(fb0, arch_top + 40).Q(fb0, arch_top, (fb0 + fb1) / 2, arch_top).Q(fb1, arch_top, fb1, arch_top + 40).L(fb1, -24).Z()
    rm.bg.add(path(pb, fill="#3A2A36", sil=False))
    g = rm.bg.grad(Grad(rm.gid("fire"), "radial", (cx, -40, 120), [(0, "#FFC860", 0.95), (0.45, "#F08A3A", 0.6), (1, "#F08A3A", 0.0)]))
    rm.bg.add(path(pb, fill=g.url(), sil=False))
    flames = PB().M(cx - 50, -44).Q(cx - 46, -96, cx - 26, -118).Q(cx - 24, -86, cx - 8, -80).Q(cx - 4, -130, cx + 16, -150).Q(cx + 20, -100, cx + 34, -96)
    flames.Q(cx + 44, -120, cx + 52, -126).Q(cx + 58, -80, cx + 50, -44).Z()
    rm.bg.add(path(flames, fill="#F7A23E", sil=False))
    fl2 = PB().M(cx - 30, -44).Q(cx - 24, -80, cx - 10, -92).Q(cx - 4, -70, cx + 6, -66).Q(cx + 14, -104, cx + 24, -110).Q(cx + 28, -74, cx + 34, -44).Z()
    rm.bg.add(path(fl2, fill="#FFE07A", sil=False))
    logs = PB().rrect(cx - 62, -52, 124, 20, 10).rrect(cx - 40, -66, 90, 18, 9)
    rm.bg.add(path(logs, fill="#7A4E36", sil=False), path(logs, fill="none", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(pb, fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    # glow on the floor + hearth stone
    g2 = rm.bg.grad(Grad(rm.gid("hearthglow"), "radial", (cx, -10, 220), [(0, "#FFC870", 0.35), (1, "#FFC870", 0.0)]))
    rm.bg.add(ellipse(cx, -10, 220, 60, fill=g2.url(), sil=False))
    rm.bg.add(sbox(rm, x0 - 16, -30, x1 - x0 + 32, 16, 5, sm("#BFB3AE", wall, 0.1, 0.9), bx=0, by=5))
    # mantel shelf
    rm.bg.add(sbox(rm, x0 - 14, mantel_y - 4, x1 - x0 + 28, 20, 6, marble, bx=0, by=6))
    # candlesticks on the right end of the mantel
    for i, (kx, h) in enumerate([(x1 - 34, 54), (x1 - 12, 44)]):
        rm.bg.add(rect(kx - 6, mantel_y - 4 - 16, 12, 16, 3, fill=sm(pal.GOLD, wall, 0.2)[0], sw=SD, stroke=ARCH, sop=AOP, sil=False))
        rm.bg.add(rect(kx - 5, mantel_y - 20 - h, 10, h, 4, fill="#FFF6E6", sw=SD, stroke=ARCH, sop=AOP, sil=False))
        rm.bg.add(ellipse(kx, mantel_y - 30 - h, 5, 9, fill="#FFD05A", sil=False))


def ceiling_rose(rm, cx):
    wall = rm.wall
    rm.bg.add(ellipse(cx, geo.CORNICE + 4, 44, 12, fill=lift(wall, 0.5), sw=SD, stroke=ARCH, sop=0.6, sil=False))


def rug(rm, x0, x1, col, border):
    y0 = geo.BACK + 2
    pb = PB().M(x0 + 14, y0).L(x1 - 14, y0).L(x1, -2).L(x0, -2).Z()
    rm.bg.add(path(pb, fill=col, sil=False))
    rm.bg.add(path(PB().M(x0 + 22, y0 + 5).L(x1 - 22, y0 + 5).L(x1 - 10, -7).L(x0 + 10, -7).Z(), fill="none", sw=3, stroke=border, sil=False))
    motif = PB()
    x = x0 + 60
    while x < x1 - 50:
        motif.M(x, y0 + 8).L(x + 10, y0 + 14).L(x, y0 + 20).L(x - 10, y0 + 14).Z()
        x += 70
    rm.bg.add(path(motif, fill=border, sil=False))
    rm.bg.add(path(pb, fill="none", sw=2.5, stroke=ARCH, sop=0.6, sil=False))


def tea_table(rm, cx, top_y):
    wood = sm("#8E4636", rm.wall, 0.15, 0.85)
    rm.bg.add(shadow_rect(cx - 40, -20, 80, 14, 0.1))
    rm.bg.add(path(PB().M(cx - 6, top_y + 10).L(cx - 8, -60).Q(cx - 40, -40, cx - 44, -12).M(cx + 6, top_y + 10).L(cx + 8, -60).Q(cx + 40, -40, cx + 44, -12)
                   .M(cx, -60).L(cx, -14), fill="none", sw=10, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(PB().M(cx - 6, top_y + 10).L(cx - 8, -60).Q(cx - 40, -40, cx - 44, -12).M(cx + 6, top_y + 10).L(cx + 8, -60).Q(cx + 40, -40, cx + 44, -12)
                   .M(cx, -60).L(cx, -14), fill="none", sw=5, stroke=wood[0], sil=False))
    rm.bg.add(sbox(rm, cx - 56, top_y - 4, 112, 16, 7, wood, bx=0, by=5))


def parlour():
    rm = arch.Room("parlour")
    wall = rm.wall
    dado_y = -236
    arch.wall_base(rm)
    arch.pat_damask(rm, geo.CORNICE, dado_y, step=64, col=lift(wall, 0.1), dot=mul(wall, 0.955))
    arch.wainscot(rm, dado_y + 7, geo.SKIRT_TOP, panel_w=170, col=mul(wall, 0.84))
    arch.dado(rm, dado_y, col=lift(wall, 0.5))
    arch.ceiling_shadow(rm)
    arch.cornice(rm, col=lift(wall, 0.55))
    arch.skirting(rm, col=lift(wall, 0.5))
    arch.floor_strip(rm)
    rug(rm, 1600, 2700, soft("#5E7FA0", wall, 0.3, 0.7), soft("#E8C46A", wall, 0.25, 0.8))
    arch.slab(rm)
    window_drapes(rm, 1776, 1904, -588, -300, sm("#9C5A78", wall, 0.25, 0.7))
    arch.light_shaft(rm, 1790, -580, 100, 560, 160, 0.10, "shaft_parlour")
    fireplace(rm, 2330, -300)
    ceiling_rose(rm, 2330)
    tea_table(rm, 2728, -150)
    arch.bands(rm)
    return rm


# =============================================================================== PORCH (exterior)
def digit(ch, x, y, s=1.0):
    D9 = {"9": [[(10, 6), (5, 0), (1, 3), (0, 8), (4, 12), (10, 8), (10, 6), (9, 16), (6, 21), (1, 19)]],
          "7": [[(0, 0), (10, 0), (4, 21)], [(3, 10), (9, 10)]]}
    pb = PB()
    for stroke in D9[ch]:
        pts = [(x + px * s, y + py * s) for px, py in stroke]
        pb.M(*pts[0])
        for q in pts[1:]:
            pb.L(*q)
    return pb


def cloud(rm, cx, cy, s, col):
    pb = PB().ellipse(cx, cy, 60 * s, 22 * s).ellipse(cx - 40 * s, cy + 4 * s, 34 * s, 18 * s).ellipse(cx + 44 * s, cy + 6 * s, 30 * s, 16 * s)
    pb.ellipse(cx - 6 * s, cy - 16 * s, 34 * s, 22 * s)
    rm.bg.add(path(pb, fill=col, sil=False))


def porch():
    rm = arch.Room("porch")
    sky = pal.SKY
    g = rm.bg.grad(Grad(rm.gid("sky"), "linear", (0, geo.CEIL, 0, -120), [(0, mix(sky, "#6FB8E0", 0.35), None), (1, lift(sky, 0.45), None)]))
    rm.bg.add(rect(rm.x0, geo.CEIL, rm.x1 - rm.x0, -geo.CEIL, fill=g.url(), sil=False))
    cloud(rm, 250, -560, 1.0, lift(sky, 0.75))
    cloud(rm, 420, -470, 0.6, lift(sky, 0.65))
    # the street beyond: a row of soft rooftops and chimneys
    roofs = PB().M(rm.x0, -150).L(rm.x0, -300).L(200, -300).L(236, -340).L(272, -300).L(330, -300).L(330, -330).L(346, -330).L(346, -300)
    roofs.L(420, -300).L(456, -350).L(492, -300).L(rm.x1, -300).L(rm.x1, -150).Z()
    rm.bg.add(path(roofs, fill=mix(sky, "#9A8FB8", 0.45), sil=False))
    win = PB()
    for wx in (214, 260, 380, 440):
        win.rrect(wx, -280, 18, 26, 3)
    rm.bg.add(path(win, fill=lift(sky, 0.5), sil=False))
    # garden wall across the street + pavement
    rm.bg.add(rect(rm.x0, -150, rm.x1 - rm.x0, 122, fill=mix("#C9B4A0", sky, 0.25), sil=False))
    brick = PB()
    for row in range(5):
        y = -150 + row * 24
        brick.M(rm.x0, y).L(rm.x1, y)
        off = 0 if row % 2 else 24
        x = rm.x0 + off
        while x < rm.x1:
            brick.M(x, y).L(x, y + 24)
            x += 48
    rm.bg.add(path(brick, fill="none", sw=2.0, stroke=mix("#A8907C", sky, 0.2), sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, -150, 3, 0.6))
    # pavement / front path (the floor strip) + earth slab
    pav = mix(pal.STONE, "#FFFFFF", 0.1)
    rm.bg.add(rect(rm.x0, geo.BACK, rm.x1 - rm.x0, -geo.BACK, fill=pav, sil=False))
    pb = PB()
    x = rm.x0 + 60
    while x < rm.x1:
        pb.M(x - 3, geo.BACK).L(x + 3, 0)
        x += 90
    rm.bg.add(path(pb, fill="none", sw=2.0, stroke=pal.STONE_SH, sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, 0, 3.0, 0.8))
    arch.slab(rm, kind="earth")
    # --- No. 9 (Hush's house): a strip of lilac-blue facade with her window, flower box and the "9"
    n9 = ("#B7B4E0", "#9C98CC", "#DAD8F4")
    rm.bg.add(rect(rm.x0, geo.CEIL, 168, -geo.CEIL, fill=n9[0], sil=False))
    rm.bg.add(rect(150, geo.CEIL, 18, -geo.CEIL, fill=n9[1], sil=False))
    rm.bg.add(vline(168, geo.CEIL, 0))
    sid = PB()
    y = geo.CEIL + 40
    while y < -30:
        sid.M(rm.x0, y).L(150, y)
        y += 36
    rm.bg.add(path(sid, fill="none", sw=2.0, stroke=n9[1], sil=False))
    # her window: glass, Breton-striped curtains tied back, a box of red geraniums, a beret on the latch
    wx0, wx1, wy0, wy1 = 24, 132, -500, -300
    rm.bg.add(sbox(rm, wx0 - 10, wy0 - 10, wx1 - wx0 + 20, wy1 - wy0 + 20, 6, sm("#FFFFFF", sky, 0.05, 1.0), bx=0, by=0))
    rm.bg.add(rect(wx0, wy0, wx1 - wx0, wy1 - wy0, 4, fill=mix("#CFE9F6", sky, 0.2), sil=False))
    rm.bg.add(path(PB().M(wx0 + 14, wy0 + 10).L(wx0 + 40, wy0 + 10).L(wx0 + 20, wy0 + 90).L(wx0 + 8, wy0 + 90).Z(), fill="#FFFFFF", fop=0.6, sil=False))
    for sgn, cx0 in ((1, wx0), (-1, wx1)):
        cur = PB().M(cx0, wy0).L(cx0 + sgn * 34, wy0).Q(cx0 + sgn * 10, wy0 + 100, cx0 + sgn * 16, wy1).L(cx0, wy1).Z()
        rm.bg.add(path(cur, fill="#F7F8FF", sil=False))
        st = PB()
        for i in range(5):
            yy = wy0 + 16 + i * 38
            wdt = 30 - abs(2 - i) * 6
            st.M(cx0, yy).L(cx0 + sgn * max(8, wdt), yy)
        rm.bg.add(path(st, fill="none", sw=7, stroke=mix("#2B3566", sky, 0.25), sil=False))
        rm.bg.add(path(cur, fill="none", sw=SD, stroke=ARCH, sop=AOP, sil=False))
        rm.bg.add(ellipse(cx0 + sgn * 12, wy0 + 104, 12, 5, fill=soft(pal.BERET, sky, 0.1, 0.9), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(slines(PB().M((wx0 + wx1) / 2, wy0).L((wx0 + wx1) / 2, wy1).M(wx0, (wy0 + wy1) / 2).L(wx1, (wy0 + wy1) / 2), 3.0, 0.8))
    rm.bg.add(sbox(rm, wx0 - 16, wy1 + 6, wx1 - wx0 + 32, 26, 5, sm("#8E6A4E", sky, 0.1, 0.9), bx=0, by=6))
    flowers = PB()
    for fx in range(wx0 - 4, wx1 + 8, 22):
        flowers.circle(fx, wy1 + 2, 10)
    leaves = PB()
    for fx in range(wx0 + 7, wx1, 22):
        leaves.ellipse(fx, wy1 + 4, 7, 5)
    rm.bg.add(path(leaves, fill=soft("#6BBF59", sky, 0.1, 0.9), sil=False))
    rm.bg.add(path(flowers, fill=soft("#E2566A", sky, 0.1, 0.9), sil=False), path(flowers, fill="none", sw=SD, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(PB().ellipse(wx1 + 8, wy0 + 44, 20, 8).ellipse(wx1 + 10, wy0 + 34, 12, 10), fill=soft(pal.BERET, sky, 0.1, 0.9), sw=SD,
                   stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, 56, -250, 44, 56, 6, sm(pal.GOLD, sky, 0.1, 0.9), bx=4, by=4))
    rm.bg.add(path(digit("9", 70, -233, 1.1), fill="none", sw=4.5, stroke=ARCH, sop=0.9, sil=False))
    # --- the hedge between the houses (a landing target: RUG BURN ends in it)
    hcol = soft(pal.HEDGE, sky, 0.05, 0.95)
    pts = []
    import math as _m
    for i in range(22):
        t = i / 22.0
        a = _m.pi + t * _m.pi       # upper half arc from the left ground point to the right one
        bump = 12 if i % 2 else 0
        pts.append((256 + (120 + bump) * _m.cos(a), -4 + (250 + bump) * _m.sin(a) * 0.95))
    pts = [(136, -2)] + pts + [(376, -2)]
    rm.bg.add(path(PB().smooth(pts, True, 0.6), fill=hcol, sil=False))
    rm.bg.add(path(PB().ellipse(222, -176, 30, 24).ellipse(280, -130, 26, 20).ellipse(206, -96, 20, 16).ellipse(312, -196, 18, 14),
                   fill=lift(hcol, 0.2), sil=False))
    rm.bg.add(path(PB().M(190, -60).Q(200, -74, 214, -70).M(262, -210).Q(272, -222, 284, -216).M(318, -96).Q(328, -108, 340, -100), fill="none",
                   sw=SD, stroke=ARCH, sop=0.5, sil=False))
    rm.bg.add(path(PB().smooth(pts, True, 0.6), fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    # --- No. 7: the doorstep, the doormat, the canopy over the front door, the lamp and the "7"
    rm.bg.add(sbox(rm, 330, -30, 150, 30, 5, sm(pal.STONE, sky, 0.05, 0.9), bx=0, by=8))
    rm.bg.add(rect(352, -34, 100, 6, 3, fill=soft("#B8674A", sky, 0.1, 0.8), sw=SD, stroke=ARCH, sop=AOP, sil=False))
    can = sm("#E9E2D6", sky, 0.05, 0.9)
    rm.bg.add(path(PB().M(360, -498).L(420, -540).L(480, -498).Z(), fill=can[0], sil=False))
    rm.bg.add(path(PB().M(360, -498).L(420, -540).L(480, -498).Z(), fill="none", sw=SW, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(sbox(rm, 350, -500, 132, 18, 4, sm("#7A5A74", sky, 0.1, 0.8), bx=0, by=5))
    rm.bg.add(path(PB().M(372, -482).Q(372, -430, 470, -430), fill="none", sw=6, stroke=ARCH, sop=AOP, sil=False))
    rm.bg.add(path(digit("7", 414, -530, 1.1), fill="none", sw=4.5, stroke=soft(pal.GOLD, sky, 0.1, 0.9), sil=False))
    # hanging porch lantern
    rm.bg.add(line(444, -482, 444, -456, 3, ARCH, 0.8))
    rm.bg.add(sbox(rm, 432, -456, 24, 34, 5, sm("#FFE7A0", sky, 0.0, 1.0), bx=0, by=0))
    g2 = rm.bg.grad(Grad(rm.gid("lamp"), "radial", (444, -440, 90), [(0, "#FFF2B8", 0.45), (1, "#FFF2B8", 0.0)]))
    rm.bg.add(circle(444, -440, 90, fill=g2.url(), sil=False))
    # a flower pot by the step
    rm.bg.add(sbox(rm, 318, -64, 30, 34, 5, sm("#C86A4A", sky, 0.1, 0.85), bx=4, by=0))
    rm.bg.add(path(PB().circle(326, -74, 10).circle(340, -80, 11).circle(333, -92, 9), fill=soft("#6BBF59", sky, 0.1, 0.9), sw=SD, stroke=ARCH, sop=AOP,
                   sil=False))
    # No. 7's front wall half-band (brick outside) with the door gap
    arch.band(rm, 1, exterior=True, gap=(geo.DOOR_TOP + 16, 0))
    return rm


ROOMS = {"kitchen": kitchen, "hall": hall, "parlour": parlour, "porch": porch}
