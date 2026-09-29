"""arch - the shared architecture of every room canvas (walls, wallpaper, cornice, skirting, floor
strip, slab cut, partition bands with doorway gaps) - STYLE.md §7.

Room canvas = [x0, x1] x [-640, +60] relative to the room's floor line (TECH §2). Everything is
drawn in world coords (x absolute, y floor-relative) and serialised with the (x0, -640) offset.
Architecture lines: 3 px ARCH at 80 %.
"""
import geo
import pal
from svgk import PB, Canvas, Grad, circle, ellipse, lift, line, mix, mul, path, rect, desat

AW = pal.LW_ARCH
AOP = pal.ARCH_OP
ARCH = pal.ARCH


def aline(pb, sw=AW, op=AOP, col=ARCH):
    return path(pb, fill="none", sw=sw, stroke=col, sop=op, sil=False)


def hline(x0, x1, y, sw=AW, op=AOP, col=ARCH):
    return aline(PB().M(x0, y).L(x1, y), sw, op, col)


def vline(x, y0, y1, sw=AW, op=AOP, col=ARCH):
    return aline(PB().M(x, y0).L(x, y1), sw, op, col)


class Room:
    """Collects bg/fg canvases for one room and knows its geometry."""

    def __init__(self, rid):
        r = geo.ROOM[rid]
        self.id = rid
        self.x0, self.x1 = r["x0"], r["x1"]
        self.floor = r["floor"]
        self.outdoor = r["outdoor"]
        self.wall = r["wallpaper"]
        self.t = pal.room_tones(rid) if rid in pal.ROOM else None
        self.bg = Canvas()
        self.fg = Canvas()
        self.left = self._side(self.x0, -1)
        self.right = self._side(self.x1, +1)

    def _side(self, x, sgn):
        """What is on this side wall: ('doorway'|'door'|'wall'|'open', link) ."""
        for l in geo.LINKS:
            if l["kind"] in ("doorway", "door") and l["x"] == x and self.id in (l["a"], l["b"]):
                return (l["kind"], l)
        other = geo.room_of_x(self.floor, x + sgn * 5)
        if other is None:
            return ("wall", None)          # exterior wall with nothing beyond
        return ("wall", None)

    def gid(self, name):
        return "%s_%s" % (self.id, name)

    def svg_bg(self):
        return self.bg.svg(self.x0, geo.CEIL, self.x1 - self.x0, geo.INTERIOR_H + geo.SLAB_H)

    def svg_fg(self):
        return self.fg.svg(self.x0, geo.CEIL, self.x1 - self.x0, geo.INTERIOR_H + geo.SLAB_H)


# ---------------------------------------------------------------------------- walls

def wall_base(rm, top=geo.CEIL, bottom=geo.BACK):
    t = rm.t
    g = rm.bg.grad(Grad(rm.gid("wall"), "linear", (rm.x0, top, rm.x0 + 700, bottom + 300),
                        [(0, t["wall_lt"], None), (0.55, t["wall"], None), (1, mul(t["wall"], 0.95), None)]))
    rm.bg.add(rect(rm.x0, top, rm.x1 - rm.x0, bottom - top, fill=g.url(), sil=False))


def ceiling_shadow(rm, y=geo.CORNICE, h=70, op=0.14):
    g = rm.bg.grad(Grad(rm.gid("ceilsh"), "linear", (0, y, 0, y + h),
                        [(0, pal.INK, op), (1, pal.INK, 0.0)]))
    rm.bg.add(rect(rm.x0, y, rm.x1 - rm.x0, h, fill=g.url(), sil=False))


def cornice(rm, col=None):
    col = col or rm.t["trim"]
    sh = mix(col, rm.wall, 0.4)
    rm.bg.add(rect(rm.x0, geo.CEIL, rm.x1 - rm.x0, geo.CORNICE - geo.CEIL, fill=col, sil=False))
    rm.bg.add(rect(rm.x0, geo.CORNICE - 8, rm.x1 - rm.x0, 8, fill=sh, sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, geo.CORNICE))
    rm.bg.add(hline(rm.x0, rm.x1, geo.CORNICE - 9, 2.0, 0.45))


def skirting(rm, col=None, top=geo.SKIRT_TOP):
    col = col or rm.t["trim"]
    rm.bg.add(rect(rm.x0, top, rm.x1 - rm.x0, geo.BACK - top, fill=col, sil=False))
    rm.bg.add(rect(rm.x0, geo.BACK - 7, rm.x1 - rm.x0, 7, fill=mix(col, rm.wall, 0.45), sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, top))
    rm.bg.add(hline(rm.x0, rm.x1, top + 7, 2.0, 0.4))


def dado(rm, y, col=None):
    col = col or rm.t["trim"]
    rm.bg.add(rect(rm.x0, y - 7, rm.x1 - rm.x0, 14, fill=col, sil=False))
    rm.bg.add(rect(rm.x0, y + 2, rm.x1 - rm.x0, 5, fill=mix(col, rm.wall, 0.45), sil=False))
    rm.bg.add(hline(rm.x0, rm.x1, y - 7))
    rm.bg.add(hline(rm.x0, rm.x1, y + 7))


def wainscot(rm, top, bottom, panel_w=150, col=None, x0=None, x1=None):
    """Raised panels between the dado and the skirting."""
    col = col or rm.t["wains"]
    x0 = rm.x0 if x0 is None else x0
    x1 = rm.x1 if x1 is None else x1
    rm.bg.add(rect(x0, top, x1 - x0, bottom - top, fill=col, sil=False))
    n = max(1, int(round((x1 - x0) / panel_w)))
    pw = (x1 - x0) / n
    lt = mix(col, "#FFFFFF", 0.14)
    sh = mul(col, 0.9)
    pb_sh = PB()
    pb_lt = PB()
    pb_ln = PB()
    for i in range(n):
        px = x0 + i * pw + 16
        py = top + 16
        w = pw - 32
        h = bottom - top - 32
        if w < 20 or h < 20:
            continue
        pb_ln.rrect(px, py, w, h, 4)
        pb_sh.M(px + w, py).L(px + w, py + h).L(px, py + h).L(px + 6, py + h - 6).L(px + w - 6, py + h - 6).L(px + w - 6, py + 6).Z()
        pb_lt.M(px, py).L(px + w, py).L(px + w - 6, py + 6).L(px + 6, py + 6).L(px + 6, py + h - 6).L(px, py + h).Z()
    rm.bg.add(path(pb_sh, fill=sh, sil=False), path(pb_lt, fill=lt, sil=False), aline(pb_ln, 2.5, 0.55))


# ---------------------------------------------------------------------------- wallpaper patterns

def pat_stripes(rm, top, bottom, w=26, gap=26, col=None, pin=True):
    col = col or rm.t["pattern"]
    pb = PB()
    x = rm.x0 + 8
    while x < rm.x1:
        pb.M(x, top).L(x + w, top).L(x + w, bottom).L(x, bottom).Z()
        x += w + gap
    rm.bg.add(path(pb, fill=col, sil=False))
    if pin:
        pb2 = PB()
        x = rm.x0 + 8 + w + gap / 2
        while x < rm.x1:
            pb2.M(x, top).L(x, bottom)
            x += w + gap
        rm.bg.add(path(pb2, fill="none", sw=2.0, stroke=mul(rm.wall, 0.93), sil=False))


def _clip_seg(xa, ya, xb, yb, x0, x1):
    """Clip a segment to x0 <= x <= x1 (y already inside)."""
    if xa > xb:
        xa, ya, xb, yb = xb, yb, xa, ya
    if xb < x0 or xa > x1 or xb == xa:
        return None if (xb < x0 or xa > x1) else (xa, ya, xb, yb)
    t0 = max(0.0, (x0 - xa) / (xb - xa))
    t1 = min(1.0, (x1 - xa) / (xb - xa))
    if t1 <= t0:
        return None
    return (xa + (xb - xa) * t0, ya + (yb - ya) * t0, xa + (xb - xa) * t1, ya + (yb - ya) * t1)


def pat_damask(rm, top, bottom, step=64, col=None, dot=None):
    """Diamond trellis + a small four-petal motif in each diamond."""
    col = col or rm.t["pattern"]
    dot = dot or mul(rm.wall, 0.94)
    pb = PB()
    x0, x1 = rm.x0, rm.x1
    # 45-degree lattice clipped to the band: lines x = c + sgn * y
    for sgn in (1, -1):
        lo = (x0 - bottom) if sgn > 0 else (x0 + top)
        hi = (x1 - top) if sgn > 0 else (x1 + bottom)
        c = lo - (lo % step)
        while c <= hi + step:
            seg = _clip_seg(c + sgn * top, top, c + sgn * bottom, bottom, x0, x1)
            if seg:
                pb.M(seg[0], seg[1]).L(seg[2], seg[3])
            c += step
    rm.bg.add(path(pb, fill="none", sw=2.5, stroke=col, sil=False))
    motif = PB()
    half = step / 2.0
    d = int(top // half) + 1
    while d * half < bottom - 8:
        y = d * half
        off = half if d % 2 == 0 else 0.0
        x = x0 - (x0 % step) + off - step
        while x < x1 + step:
            if x0 - 12 < x < x1 + 12 and y > top + 8:
                s = 6.5
                motif.M(x, y - s * 1.6).Q(x + s, y - s * 0.4, x, y).Q(x - s, y - s * 0.4, x, y - s * 1.6).Z()
                motif.M(x, y + s * 1.6).Q(x + s, y + s * 0.4, x, y).Q(x - s, y + s * 0.4, x, y + s * 1.6).Z()
                motif.M(x - s * 1.6, y).Q(x - s * 0.4, y - s, x, y).Q(x - s * 0.4, y + s, x - s * 1.6, y).Z()
                motif.M(x + s * 1.6, y).Q(x + s * 0.4, y - s, x, y).Q(x + s * 0.4, y + s, x + s * 1.6, y).Z()
            x += step
        d += 1
    rm.bg.add(path(motif, fill=dot, sil=False))


def pat_gingham(rm, top, bottom, step=40, col=None):
    col = col or rm.t["pattern"]
    pb = PB()
    x = rm.x0
    while x < rm.x1:
        pb.M(x, top).L(x + step / 2, top).L(x + step / 2, bottom).L(x, bottom).Z()
        x += step
    y = top
    while y < bottom:
        pb.M(rm.x0, y).L(rm.x1, y).L(rm.x1, y + step / 2).L(rm.x0, y + step / 2).Z()
        y += step
    rm.bg.add(path(pb, fill=col, fop=0.55, sil=False))


def pat_dots(rm, top, bottom, step=48, r=4, col=None):
    col = col or rm.t["pattern"]
    from draw import dots_grid
    rm.bg.add(path(dots_grid(rm.x0 + step / 2, top + step / 2, rm.x1, bottom - 8, step, step * 0.8, r), fill=col, sil=False))


def pat_tiles(rm, top, bottom, size=40, col=None, grout=None, x0=None, x1=None):
    col = col or lift(rm.wall, 0.35)
    grout = grout or mul(rm.wall, 0.9)
    x0 = rm.x0 if x0 is None else x0
    x1 = rm.x1 if x1 is None else x1
    rm.bg.add(rect(x0, top, x1 - x0, bottom - top, fill=col, sil=False))
    pb = PB()
    y = top + size
    while y < bottom - 2:
        pb.M(x0, y).L(x1, y)
        y += size
    x = x0 + size
    while x < x1 - 2:
        pb.M(x, top).L(x, bottom)
        x += size
    rm.bg.add(path(pb, fill="none", sw=2.0, stroke=grout, sil=False))
    rm.bg.add(hline(x0, x1, top, 2.5, 0.6))


def pat_boards(rm, top, bottom, step=44, col=None):
    """Vertical tongue-and-groove boards (landing honey wood)."""
    col = col or mul(rm.wall, 0.93)
    pb = PB()
    x = rm.x0 + step
    while x < rm.x1:
        pb.M(x, top).L(x, bottom)
        x += step
    rm.bg.add(path(pb, fill="none", sw=2.5, stroke=col, sil=False))


# ---------------------------------------------------------------------------- floor + slab

def floor_strip(rm, col=pal.OAK, sh=pal.OAK_SH, x0=None, x1=None):
    x0 = rm.x0 if x0 is None else x0
    x1 = rm.x1 if x1 is None else x1
    y0 = geo.BACK
    rm.bg.add(rect(x0, y0, x1 - x0, -y0, fill=col, sil=False))
    rm.bg.add(rect(x0, y0, x1 - x0, 6, fill=sh, fop=0.7, sil=False))     # contact shade under the skirting
    # plank seams in slight perspective (converge toward the back)
    pb = PB()
    step = 96
    x = x0 + ((-x0) % step)
    while x < x1:
        pb.M(x - 3, y0 + 2).L(x + 3, 0)
        x += step
    pb2 = PB().M(x0, y0 + 14).L(x1, y0 + 14)
    rm.bg.add(path(pb, fill="none", sw=2.0, stroke=sh, sil=False), path(pb2, fill="none", sw=2.0, stroke=sh, sop=0.6, sil=False))
    rm.bg.add(hline(x0, x1, 0, 3.0, 0.8))


def slab(rm, x0=None, x1=None, kind="floor"):
    """The 60 px cut through the floor: boards, joists, ceiling plaster (or earth outdoors)."""
    x0 = rm.x0 if x0 is None else x0
    x1 = rm.x1 if x1 is None else x1
    if kind == "earth":
        g = rm.bg.grad(Grad(rm.gid("earth"), "linear", (0, 0, 0, geo.SLAB_H),
                            [(0, "#8B6A4E", None), (1, "#6E5240", None)]))
        rm.bg.add(rect(x0, 0, x1 - x0, geo.SLAB_H, fill=g.url(), sil=False))
        stones = PB()
        k = 0
        x = x0 + 30
        while x < x1:
            yy = 22 + (k * 17) % 26
            stones.ellipse(x, yy, 9 + (k % 3) * 3, 5 + (k % 2) * 2)
            x += 70 + (k * 23) % 50
            k += 1
        rm.bg.add(path(stones, fill="#9C7E62", sil=False))
        rm.bg.add(hline(x0, x1, 0, 3.0, 0.8))
        return
    rm.bg.add(rect(x0, 0, x1 - x0, 12, fill=pal.OAK_SH, sil=False))
    rm.bg.add(rect(x0, 12, x1 - x0, 32, fill=pal.JOIST, sil=False))
    rm.bg.add(rect(x0, 44, x1 - x0, geo.SLAB_H - 44, fill=pal.PLASTER, sil=False))
    rm.bg.add(rect(x0, 44, x1 - x0, 4, fill=pal.PLASTER_SH, sil=False))
    # joist ends
    pb = PB()
    step = 80
    x = x0 + ((-x0 + 20) % step)
    while x < x1 - 10:
        pb.rrect(x, 16, 30, 24, 3)
        x += step
    rm.bg.add(path(pb, fill=pal.JOIST_SH, sil=False))
    rm.bg.add(hline(x0, x1, 12, 2.0, 0.6), hline(x0, x1, 44, 2.5, 0.7), hline(x0, x1, geo.SLAB_H - 1, 2.0, 0.5))
    rm.bg.add(hline(x0, x1, 0, 3.0, 0.8))


# ---------------------------------------------------------------------------- partitions

def band(rm, side, exterior=False, gap=None):
    """Half of a partition band on the left (-1) or right (+1) edge, with an optional doorway gap
    (gap = (top_y, bottom_y) of the opening)."""
    if side < 0:
        bx0, bx1 = rm.x0, rm.x0 + geo.BAND / 2
        inner = bx1
    else:
        bx0, bx1 = rm.x1 - geo.BAND / 2, rm.x1
        inner = bx0
    face = pal.PLASTER if not exterior else pal.BRICK
    shade = pal.PLASTER_SH if not exterior else pal.BRICK_SH
    segs = [(geo.CEIL, 0)] if gap is None else [(geo.CEIL, gap[0])]
    for (a, b) in segs:
        rm.bg.add(rect(bx0, a, bx1 - bx0, b - a, fill=face, sil=False))
        # shade on the half that faces away from the light (right edge of each band)
        if side > 0:
            rm.bg.add(rect(bx1 - 7, a, 7, b - a, fill=shade, sil=False))
        rm.bg.add(vline(inner, a, b))
    if gap is not None:
        # lintel underside + the reveal (a soft shadow in the opening)
        top = gap[0]
        g = rm.bg.grad(Grad(rm.gid("reveal%d" % side), "linear", (0, top, 0, 0),
                            [(0, pal.INK, 0.22), (0.35, pal.INK, 0.08), (1, pal.INK, 0.04)]))
        rm.bg.add(rect(bx0, top, bx1 - bx0, geo.BACK - top, fill=g.url(), sil=False))
        rm.bg.add(hline(bx0, bx1, top))
        # floor continues through the opening (floor_strip covers it)
        cas = mix(pal.OAK, "#FFFFFF", 0.25)
        if side < 0:
            cx0 = bx1 - 2
        else:
            cx0 = bx0 - 8
        # side casings sit BEHIND characters (a fg strip would slice anyone standing near the doorway);
        # only the lintel lip is in the fg (it occludes tall launches / floating props passing through)
        rm.bg.add(rect(cx0, top - 10, 10, -top + 10 - 2, 3, fill=cas, sil=False))
        rm.bg.add(rect(cx0, top - 10, 10, -top + 10 - 2, 3, fill="none", sw=2.5, stroke=ARCH, sop=AOP, sil=False))
        rm.fg.add(rect(bx0 - (4 if side > 0 else 0), top - 12, bx1 - bx0 + 4, 12, 3, fill=cas, sil=False))
        rm.fg.add(rect(bx0 - (4 if side > 0 else 0), top - 12, bx1 - bx0 + 4, 12, 3, fill="none", sw=2.5, stroke=ARCH,
                       sop=AOP, sil=False))


def light_shaft(rm, x, y, w, h, dx, op=0.12, name="shaft"):
    """A soft diagonal window-light parallelogram falling to the lower right (light from the top-left)."""
    g = rm.bg.grad(Grad(rm.gid(name), "linear", (x, y, x + dx, y + h),
                        [(0, "#FFFFFF", op), (1, "#FFFFFF", 0.0)]))
    rm.bg.add(path(PB().M(x, y).L(x + w, y).L(x + w + dx, y + h).L(x + dx, y + h).Z(), fill=g.url(), sil=False))


def standard_room(rm, pattern, dado_y=None, wains=True, pattern_kw=None):
    """Wall + pattern + cornice + (dado + wainscot) + skirting + floor + slab + bands."""
    wall_base(rm)
    top = geo.CORNICE
    bot = dado_y if dado_y is not None else geo.SKIRT_TOP
    if pattern:
        pattern(rm, top, bot, **(pattern_kw or {}))
    if dado_y is not None and wains:
        wainscot(rm, dado_y + 7, geo.SKIRT_TOP)
        dado(rm, dado_y)
    ceiling_shadow(rm)
    cornice(rm)
    skirting(rm)
    floor_strip(rm)
    slab(rm)


def bands(rm, exterior_left=False, exterior_right=False):
    for side, (kind, l) in ((-1, rm.left), (1, rm.right)):
        ext = exterior_left if side < 0 else exterior_right
        if kind == "doorway":
            band(rm, side, ext, gap=(geo.DOOR_TOP, 0))
        elif kind == "door":
            band(rm, side, ext, gap=(geo.DOOR_TOP + 16, 0))
        else:
            band(rm, side, ext)
