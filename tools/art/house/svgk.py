"""svgk - the SVG kit for Mischief Next Door house art (ported and extended from Booby's
tools/art/booby_art_style/svgk.py; no Booby assets are used).

Everything is drawn as *element objects* in WORLD coordinates (px, x grows right, y down,
y relative to the floor line of the thing being drawn). A `Canvas` then serialises the
elements with an integer offset, so the same drawing code can be written straight against the
house layout (geo.py) and still produce tight, 1-decimal SVG files (game/art/STYLE.md §1).

Elements know their bounding box (stroke included), can be recoloured into the flat-white
"grown 4 px" outline sprite (STYLE §6) and can be serialised at an offset.
"""
import colorsys
import math
import os
import subprocess

INK = "#1B2340"          # character / interactable ink
ARCH = "#3A3050"         # architecture line colour (drawn at 80 % opacity)
WHITE = "#FFFFFF"

# ------------------------------------------------------------------ numbers & colours


def n(v):
    """1-decimal compact number."""
    if isinstance(v, str):
        return v
    s = "%.1f" % v
    if s.endswith(".0"):
        s = s[:-2]
    if s == "-0":
        s = "0"
    return s


def rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def hexc(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    """a -> b by t (0 = a)."""
    ca, cb = rgb(a), rgb(b)
    return hexc([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def mul(a, k, warm=True):
    """The STYLE §3 shade tone: multiply by k with a slight warm (or cool) hue shift."""
    c = [v * k for v in rgb(a)]
    if warm:
        c[0] *= 1.03
        c[2] *= 0.95
    else:
        c[0] *= 0.97
        c[2] *= 1.04
    return hexc(c)


def lift(a, t):
    """Towards white."""
    return mix(a, "#FFFFFF", t)


def hsv(h):
    r, g, b = [v / 255.0 for v in rgb(h)]
    return colorsys.rgb_to_hsv(r, g, b)


def desat(h, k):
    """Scale HSV saturation by k (0.7 = 30 % desaturated)."""
    hh, s, v = hsv(h)
    r, g, b = colorsys.hsv_to_rgb(hh, max(0.0, min(1.0, s * k)), v)
    return hexc([r * 255, g * 255, b * 255])


def lum(h):
    r, g, b = [v / 255.0 for v in rgb(h)]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# ------------------------------------------------------------------ elements

class El:
    """One SVG element. geo holds geometry in world coords; attrs holds presentation."""

    def __init__(self, tag, geo, attrs, sil=True):
        self.tag = tag
        self.geo = geo
        self.attrs = attrs
        self.sil = sil          # part of the silhouette (used for the outline sprite)

    # -- bounds ---------------------------------------------------------------
    def _pts(self):
        g = self.geo
        t = self.tag
        if t == "rect":
            return [(g["x"], g["y"]), (g["x"] + g["w"], g["y"] + g["h"])]
        if t == "circle":
            return [(g["cx"] - g["r"], g["cy"] - g["r"]), (g["cx"] + g["r"], g["cy"] + g["r"])]
        if t == "ellipse":
            return [(g["cx"] - g["rx"], g["cy"] - g["ry"]), (g["cx"] + g["rx"], g["cy"] + g["ry"])]
        if t in ("polygon", "polyline"):
            return list(g["pts"])
        if t == "line":
            return [(g["x1"], g["y1"]), (g["x2"], g["y2"])]
        if t == "path":
            return _path_pts(g["cmds"])
        return []

    def bbox(self):
        pts = self._pts()
        if not pts:
            return None
        sw = float(self.attrs.get("stroke-width", 0) or 0) if self.attrs.get("stroke") not in (None, "none") else 0.0
        h = sw / 2.0
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return (min(xs) - h, min(ys) - h, max(xs) + h, max(ys) + h)

    # -- serialise --------------------------------------------------------------
    def svg(self, ox=0.0, oy=0.0):
        g = self.geo
        t = self.tag
        a = []
        if t == "rect":
            a += [("x", g["x"] - ox), ("y", g["y"] - oy), ("width", g["w"]), ("height", g["h"])]
            if g.get("rx"):
                a.append(("rx", g["rx"]))
        elif t == "circle":
            a += [("cx", g["cx"] - ox), ("cy", g["cy"] - oy), ("r", g["r"])]
        elif t == "ellipse":
            a += [("cx", g["cx"] - ox), ("cy", g["cy"] - oy), ("rx", g["rx"]), ("ry", g["ry"])]
        elif t in ("polygon", "polyline"):
            a.append(("points", " ".join("%s,%s" % (n(x - ox), n(y - oy)) for x, y in g["pts"])))
        elif t == "line":
            a += [("x1", g["x1"] - ox), ("y1", g["y1"] - oy), ("x2", g["x2"] - ox), ("y2", g["y2"] - oy)]
        elif t == "path":
            a.append(("d", _path_d(g["cmds"], ox, oy)))
        out = " ".join('%s="%s"' % (k, n(v)) for k, v in a)
        for k, v in self.attrs.items():
            if v is None:
                continue
            out += ' %s="%s"' % (k, n(v) if not isinstance(v, str) else v)
        return "<%s %s/>" % (t, out)

    # -- outline --------------------------------------------------------------
    def to_outline(self, grow=4.0):
        """Flat white copy grown by `grow` px (stroke width + 2*grow; fills get a 2*grow stroke)."""
        a = {}
        fill = self.attrs.get("fill", "#000000")
        a["fill"] = "none" if fill == "none" else WHITE
        sw = self.attrs.get("stroke-width")
        if self.attrs.get("stroke") not in (None, "none") and sw:
            a["stroke"] = WHITE
            a["stroke-width"] = float(sw) + 2 * grow
        elif fill != "none":
            a["stroke"] = WHITE
            a["stroke-width"] = 2 * grow
        else:
            return None
        a["stroke-linejoin"] = "round"
        a["stroke-linecap"] = "round"
        return El(self.tag, self.geo, a, True)

    def colours(self):
        out = set()
        for k in ("fill", "stroke"):
            v = self.attrs.get(k)
            if v and v.startswith("#"):
                out.add(v.upper())
        return out


class Group:
    """A <g> with an optional rotation about a world point (the only transform the kit emits)."""

    def __init__(self, items, rot=0.0, cx=0.0, cy=0.0, sil=True, opacity=None):
        self.items = list(items)
        self.rot = rot
        self.cx = cx
        self.cy = cy
        self.sil = sil
        self.opacity = opacity

    def bbox(self):
        bb = union([i.bbox() for i in self.items])
        if bb is None or not self.rot:
            return bb
        pts = [rot_pt(p, self.rot, (self.cx, self.cy)) for p in
               [(bb[0], bb[1]), (bb[2], bb[1]), (bb[0], bb[3]), (bb[2], bb[3])]]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return (min(xs), min(ys), max(xs), max(ys))

    def svg(self, ox=0.0, oy=0.0):
        inner = "".join(i.svg(ox, oy) for i in self.items)
        at = ""
        if self.rot:
            at += ' transform="rotate(%s %s %s)"' % (n(self.rot), n(self.cx - ox), n(self.cy - oy))
        if self.opacity is not None:
            at += ' opacity="%s"' % n(self.opacity)
        return "<g%s>%s</g>" % (at, inner)

    def to_outline(self, grow=4.0):
        kids = [k.to_outline(grow) for k in self.items if getattr(k, "sil", True)]
        kids = [k for k in kids if k is not None]
        if not kids:
            return None
        return Group(kids, self.rot, self.cx, self.cy)

    def colours(self):
        out = set()
        for i in self.items:
            out |= i.colours()
        return out


class Xform:
    """<g transform="translate(tx ty) scale(s)"> around items (icon fitting only)."""

    def __init__(self, items, tx, ty, s):
        self.items = list(items)
        self.tx, self.ty, self.s = tx, ty, s
        self.sil = True

    def bbox(self):
        bb = union([i.bbox() for i in self.items])
        if bb is None:
            return None
        return (self.tx + bb[0] * self.s, self.ty + bb[1] * self.s, self.tx + bb[2] * self.s, self.ty + bb[3] * self.s)

    def svg(self, ox=0.0, oy=0.0):
        return '<g transform="translate(%s %s) scale(%s)">%s</g>' % (n(self.tx - ox), n(self.ty - oy), ("%.3f" % self.s).rstrip("0").rstrip("."),
                                                                     "".join(i.svg(0, 0) for i in self.items))

    def to_outline(self, grow=4.0):
        return None

    def colours(self):
        out = set()
        for i in self.items:
            out |= i.colours()
        return out


def fit(items, x0, y0, x1, y1):
    """Scale (down only) + centre items so their bbox fits inside [x0, x1] x [y0, y1]."""
    bb = union([i.bbox() for i in items])
    if bb is None:
        return items
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    s = min(1.0, (x1 - x0) / w, (y1 - y0) / h)
    if s >= 0.999 and bb[0] >= x0 and bb[1] >= y0 and bb[2] <= x1 and bb[3] <= y1:
        return items
    s = math.floor(s * 1000) / 1000.0
    cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
    tx = (x0 + x1) / 2 - cx * s
    ty = (y0 + y1) / 2 - cy * s
    return [Xform(items, tx, ty, s)]


def recolour(items, mapping):
    """Replace colours (fill / stroke / stop-color) in-place through `mapping` {HEX: HEX}."""
    for it in items:
        if isinstance(it, (Group, Xform)):
            recolour(it.items, mapping)
            continue
        for k in ("fill", "stroke"):
            v = it.attrs.get(k)
            if v and v.upper() in mapping:
                it.attrs[k] = mapping[v.upper()]


def _lab(h):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = [lin(v) for v in rgb(h)]
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def reduce_palette(canvases, max_colours=10, keep=(INK, WHITE)):
    """Merge the closest colours (CIE76) across all canvases of one sprite until <= max_colours,
    consistently for every state. Returns the list of merges done."""
    merges = []
    keep = set(k.upper() for k in keep)
    while True:
        freq = {}

        def walk(items):
            for it in items:
                if isinstance(it, (Group, Xform)):
                    walk(it.items)
                    continue
                for k in ("fill", "stroke"):
                    v = it.attrs.get(k)
                    if v and v.startswith("#"):
                        freq[v.upper()] = freq.get(v.upper(), 0) + 1
        for c in canvases:
            walk(c.items)
        cols = sorted(freq)
        if len(cols) <= max_colours:
            return merges
        best = None
        for i in range(len(cols)):
            for j in range(i + 1, len(cols)):
                a, b = cols[i], cols[j]
                if a in keep and b in keep:
                    continue
                la, lb = _lab(a), _lab(b)
                d = math.sqrt(sum((la[k] - lb[k]) ** 2 for k in range(3)))
                if best is None or d < best[0]:
                    best = (d, a, b)
        _, a, b = best
        # the kept colour: a protected one, else the more frequent one
        if b in keep or (a not in keep and freq[b] > freq[a]):
            a, b = b, a
        merges.append((b, a))
        for c in canvases:
            recolour(c.items, {b: a})


def union(bbs):
    bbs = [b for b in bbs if b]
    if not bbs:
        return None
    return (min(b[0] for b in bbs), min(b[1] for b in bbs), max(b[2] for b in bbs), max(b[3] for b in bbs))


def rot_pt(p, ang, c=(0, 0)):
    a = math.radians(ang)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


# ------------------------------------------------------------------ paths
# cmds: list of (op, [numbers]) with absolute ops M L C Q Z.

def _path_pts(cmds):
    pts = []
    cur = (0.0, 0.0)
    start = cur
    for op, v in cmds:
        if op == "M":
            cur = (v[0], v[1])
            start = cur
            pts.append(cur)
        elif op == "L":
            cur = (v[0], v[1])
            pts.append(cur)
        elif op == "C":
            p0 = cur
            p1, p2, p3 = (v[0], v[1]), (v[2], v[3]), (v[4], v[5])
            for i in range(1, 13):
                t = i / 12.0
                mt = 1 - t
                x = mt ** 3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t ** 3 * p3[0]
                y = mt ** 3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t ** 3 * p3[1]
                pts.append((x, y))
            cur = p3
        elif op == "Q":
            p0 = cur
            p1, p2 = (v[0], v[1]), (v[2], v[3])
            for i in range(1, 9):
                t = i / 8.0
                mt = 1 - t
                pts.append((mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0],
                            mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]))
            cur = p2
        elif op == "Z":
            cur = start
    return pts


def _path_d(cmds, ox, oy):
    out = []
    for op, v in cmds:
        if op == "Z":
            out.append("Z")
            continue
        vals = []
        for i, x in enumerate(v):
            vals.append(n(x - (ox if i % 2 == 0 else oy)))
        out.append(op + " ".join(vals))
    return "".join(out)


class PB:
    """Path builder (absolute coords)."""

    def __init__(self):
        self.cmds = []

    def M(self, x, y):
        self.cmds.append(("M", [x, y]))
        return self

    def L(self, x, y):
        self.cmds.append(("L", [x, y]))
        return self

    def C(self, x1, y1, x2, y2, x, y):
        self.cmds.append(("C", [x1, y1, x2, y2, x, y]))
        return self

    def Q(self, x1, y1, x, y):
        self.cmds.append(("Q", [x1, y1, x, y]))
        return self

    def Z(self):
        self.cmds.append(("Z", []))
        return self

    def poly(self, pts, close=True):
        self.M(*pts[0])
        for p in pts[1:]:
            self.L(*p)
        if close:
            self.Z()
        return self

    def smooth(self, pts, close=True, t=0.5):
        """Catmull-Rom through points -> cubic beziers."""
        m = len(pts)
        self.M(*pts[0])
        rng = range(m) if close else range(m - 1)
        for i in rng:
            p0 = pts[(i - 1) % m] if close else pts[max(i - 1, 0)]
            p1 = pts[i % m]
            p2 = pts[(i + 1) % m] if close else pts[i + 1]
            p3 = pts[(i + 2) % m] if close else pts[min(i + 2, m - 1)]
            c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
            c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
            self.C(c1[0], c1[1], c2[0], c2[1], p2[0], p2[1])
        if close:
            self.Z()
        return self

    def rrect(self, x, y, w, h, r):
        """Rounded rect as a path (for shapes combined in one path)."""
        r = min(r, w / 2.0, h / 2.0)
        k = 0.5523 * r
        self.M(x + r, y).L(x + w - r, y).C(x + w - r + k, y, x + w, y + r - k, x + w, y + r)
        self.L(x + w, y + h - r).C(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h)
        self.L(x + r, y + h).C(x + r - k, y + h, x, y + h - r + k, x, y + h - r)
        self.L(x, y + r).C(x, y + r - k, x + r - k, y, x + r, y).Z()
        return self

    def circle(self, cx, cy, r):
        k = 0.5523 * r
        self.M(cx + r, cy).C(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
        self.C(cx - k, cy + r, cx - r, cy + k, cx - r, cy).C(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
        self.C(cx + k, cy - r, cx + r, cy - k, cx + r, cy).Z()
        return self

    def ellipse(self, cx, cy, rx, ry):
        kx, ky = 0.5523 * rx, 0.5523 * ry
        self.M(cx + rx, cy).C(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry)
        self.C(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy).C(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry)
        self.C(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy).Z()
        return self


def pts_rot(pts, ang, c):
    return [rot_pt(p, ang, c) for p in pts]


# ------------------------------------------------------------------ element constructors

def _paint(fill, sw, stroke, op, sop, fop, cap=True):
    a = {"fill": fill}
    if fop is not None and fop < 1:
        a["fill-opacity"] = fop
    if sw:
        a["stroke"] = stroke
        a["stroke-width"] = float(sw)
        if sop is not None and sop < 1:
            a["stroke-opacity"] = sop
        a["stroke-linejoin"] = "round"
        if cap:
            a["stroke-linecap"] = "round"
    if op is not None and op < 1:
        a["opacity"] = op
    return a


def rect(x, y, w, h, rx=0, fill="none", sw=None, stroke=INK, op=None, sop=None, fop=None, sil=True):
    return El("rect", dict(x=x, y=y, w=w, h=h, rx=rx), _paint(fill, sw, stroke, op, sop, fop, cap=False), sil)


def circle(cx, cy, r, fill="none", sw=None, stroke=INK, op=None, sop=None, fop=None, sil=True):
    return El("circle", dict(cx=cx, cy=cy, r=r), _paint(fill, sw, stroke, op, sop, fop, cap=False), sil)


def ellipse(cx, cy, rx, ry, fill="none", sw=None, stroke=INK, op=None, sop=None, fop=None, sil=True):
    return El("ellipse", dict(cx=cx, cy=cy, rx=rx, ry=ry), _paint(fill, sw, stroke, op, sop, fop, cap=False), sil)


def path(pb, fill="none", sw=None, stroke=INK, op=None, sop=None, fop=None, sil=True):
    cmds = pb.cmds if isinstance(pb, PB) else pb
    return El("path", dict(cmds=cmds), _paint(fill, sw, stroke, op, sop, fop), sil)


def poly(pts, fill="none", sw=None, stroke=INK, op=None, sop=None, fop=None, sil=True, close=True):
    return path(PB().poly(pts, close), fill, sw, stroke, op, sop, fop, sil)


def line(x1, y1, x2, y2, sw=3, stroke=INK, op=None, sop=None, sil=False):
    return path(PB().M(x1, y1).L(x2, y2), "none", sw, stroke, op, sop, None, sil)


def polyline(pts, sw=3, stroke=INK, sop=None, sil=False, smooth=False):
    pb = PB().smooth(pts, close=False) if smooth else PB().poly(pts, close=False)
    return path(pb, "none", sw, stroke, None, sop, None, sil)


def group(items, rot=0.0, cx=0.0, cy=0.0, sil=True, opacity=None):
    return Group(items, rot, cx, cy, sil, opacity)


# ------------------------------------------------------------------ gradients (walls/sky/glows only)

class Grad:
    def __init__(self, gid, kind, coords, stops):
        self.gid = gid
        self.kind = kind          # "linear" | "radial"
        self.coords = coords      # linear: x1 y1 x2 y2 ; radial: cx cy r (world coords)
        self.stops = stops        # [(offset, colour, opacity)]

    def svg(self, ox, oy):
        st = "".join('<stop offset="%s" stop-color="%s"%s/>' % (
            n(o), c, (' stop-opacity="%s"' % n(a)) if a is not None and a < 1 else "") for o, c, a in self.stops)
        if self.kind == "linear":
            x1, y1, x2, y2 = self.coords
            return ('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
                    % (self.gid, n(x1 - ox), n(y1 - oy), n(x2 - ox), n(y2 - oy), st))
        cx, cy, r = self.coords
        return ('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">%s</radialGradient>'
                % (self.gid, n(cx - ox), n(cy - oy), n(r), st))

    def url(self):
        return "url(#%s)" % self.gid


# ------------------------------------------------------------------ canvas

class Canvas:
    """A drawing: items in world coords + gradients. Serialise with an explicit origin/size
    (rooms, stage) or a tight bbox (props: `fit`)."""

    def __init__(self):
        self.items = []
        self.grads = []

    def add(self, *items):
        for it in items:
            if it is None:
                continue
            if isinstance(it, (list, tuple)):
                self.add(*it)
            else:
                self.items.append(it)
        return self

    def grad(self, g):
        self.grads.append(g)
        return g

    def bbox(self):
        return union([i.bbox() for i in self.items])

    def colours(self):
        out = set()
        for i in self.items:
            out |= i.colours()
        return out

    def svg(self, ox, oy, w, h):
        defs = ""
        if self.grads:
            defs = "<defs>%s</defs>" % "".join(g.svg(ox, oy) for g in self.grads)
        body = "".join(i.svg(ox, oy) for i in self.items)
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w, h, w, h)
                + defs + body + "</svg>\n")

    def outline(self, grow=4.0):
        c = Canvas()
        for it in self.items:
            if not getattr(it, "sil", True):
                continue
            o = it.to_outline(grow)
            if o is not None:
                c.items.append(o)
        return c


def fit_box(canvases, margin=12):
    """Integer canvas box (x0, y0, w, h) enclosing every canvas' items (+ margin)."""
    bb = union([c.bbox() for c in canvases])
    x0 = math.floor(bb[0] - margin)
    y0 = math.floor(bb[1] - margin)
    x1 = math.ceil(bb[2] + margin)
    y1 = math.ceil(bb[3] + margin)
    return (x0, y0, x1 - x0, y1 - y0)


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as fh:
        fh.write(s)
    return p


def render(svgp, pngp, w=None, h=None, zoom=None):
    cmd = ["rsvg-convert", svgp, "-o", pngp]
    if zoom:
        cmd += ["-z", str(zoom)]
    if w:
        cmd += ["-w", str(w)]
    if h:
        cmd += ["-h", str(h)]
    subprocess.check_call(cmd)
    return pngp
