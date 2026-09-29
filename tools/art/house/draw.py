"""draw - cartoon drawing helpers on top of svgk (STYLE.md §2-§6).

Conventions
* colours are (base, shade, light) material tuples from pal.py;
* every helper returns a list of elements in draw order (fills, shade, highlight, ink on top);
* `sw` = the silhouette ink width for the layer (props 5, set dressing 4, architecture 3);
* `ink` defaults to INK; set dressing passes pal.ARCH with `sop` 0.8 so rooms stay softer;
* one flat shade tone per shape on its lower-right, light from the top-left.
"""
import math

import pal
from svgk import (INK, PB, circle, ellipse, group, line, path, poly, polyline, rect, mix, mul, lift)


def _k(ink, sop):
    return {"stroke": ink, "sop": sop}


def box(x, y, w, h, r, m, sw=5.0, ink=INK, sop=None, bx=None, by=None, hi=True, lit=True):
    """Rounded box with a shade band on the right/bottom (shade-first inset)."""
    base, shade, light = m
    out = [rect(x, y, w, h, r, fill=shade)]
    if lit:
        bx_ = bx if bx is not None else max(5.0, min(w * 0.16, 26.0))
        by_ = by if by is not None else max(4.0, min(h * 0.12, 22.0))
        if w - bx_ > 4 and h - by_ > 4:
            out.append(rect(x, y, w - bx_, h - by_, max(0.0, r - 1), fill=base, sil=False))
    if hi and w > 30 and h > 24:
        out.append(rect(x + max(6, r * 0.6), y + 6, min(w * 0.3, 60), 6, 3, fill="#FFFFFF", fop=0.55, sil=False))
    if sw:
        out.append(rect(x, y, w, h, r, fill="none", sw=sw, **_k(ink, sop)))
    return out


def flat(x, y, w, h, r, col, sw=5.0, ink=INK, sop=None):
    """Flat box (no shading) - greybox and small parts."""
    out = [rect(x, y, w, h, r, fill=col)]
    if sw:
        out.append(rect(x, y, w, h, r, fill="none", sw=sw, **_k(ink, sop)))
    return out


def oval(cx, cy, rx, ry, m, sw=5.0, ink=INK, sop=None, hi=True, k=0.82):
    """Ellipse, shade-first: a lit ellipse pulled to the top-left."""
    base, shade, light = m
    out = [ellipse(cx, cy, rx, ry, fill=shade)]
    lx, ly = cx - rx * (1 - k) * 0.9, cy - ry * (1 - k) * 0.9
    out.append(ellipse(lx, ly, rx * k, ry * k, fill=base, sil=False))
    if hi and rx > 10 and ry > 8:
        out.append(ellipse(cx - rx * 0.42, cy - ry * 0.48, max(2.5, rx * 0.2), max(2.0, ry * 0.12),
                           fill="#FFFFFF", fop=0.55, sil=False))
    if sw:
        out.append(ellipse(cx, cy, rx, ry, fill="none", sw=sw, **_k(ink, sop)))
    return out


def ball(cx, cy, r, m, sw=5.0, ink=INK, sop=None, hi=True):
    return oval(cx, cy, r, r, m, sw, ink, sop, hi)


def _scale_pts(pts, s, c):
    return [(c[0] + (p[0] - c[0]) * s, c[1] + (p[1] - c[1]) * s) for p in pts]


def blob(pts, m, sw=5.0, ink=INK, sop=None, smooth=True, k=0.84, hi=False, t=0.5):
    """Closed (smooth) shape through pts, shade-first with a lit copy scaled toward its top-left."""
    base, shade, light = m
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    c = (min(xs) + (max(xs) - min(xs)) * 0.28, min(ys) + (max(ys) - min(ys)) * 0.26)
    mk = (lambda q: PB().smooth(q, True, t)) if smooth else (lambda q: PB().poly(q, True))
    out = [path(mk(pts), fill=shade)]
    if k:
        out.append(path(mk(_scale_pts(pts, k, c)), fill=base, sil=False))
    if hi:
        w, h = max(xs) - min(xs), max(ys) - min(ys)
        out.append(ellipse(min(xs) + w * 0.3, min(ys) + h * 0.22, max(3, w * 0.1), max(2, h * 0.05),
                           fill="#FFFFFF", fop=0.55, sil=False))
    if sw:
        out.append(path(mk(pts), fill="none", sw=sw, stroke=ink, sop=sop))
    return out


def shape(pts, fill, sw=5.0, ink=INK, sop=None, smooth=False, sil=True, fop=None, t=0.5):
    pb = PB().smooth(pts, True, t) if smooth else PB().poly(pts, True)
    out = [path(pb, fill=fill, sil=sil, fop=fop)]
    if sw:
        out.append(path(pb, fill="none", sw=sw, stroke=ink, sop=sop, sil=sil))
    return out


def stroke_path(pb, sw, ink=INK, sop=None, sil=False):
    return path(pb, fill="none", sw=sw, stroke=ink, sop=sop, sil=sil)


def shadow(cx, y, rx, ry=None, op=0.18):
    return ellipse(cx, y, rx, ry if ry is not None else max(4.0, rx * 0.12), fill=INK, fop=op, sil=False)


def knob(cx, cy, r, m=pal.BRASS, sw=3.0):
    base, shade, light = m
    return [circle(cx, cy, r, fill=shade), circle(cx - r * 0.2, cy - r * 0.2, r * 0.72, fill=base, sil=False),
            circle(cx - r * 0.35, cy - r * 0.4, max(1.2, r * 0.22), fill="#FFFFFF", fop=0.7, sil=False),
            circle(cx, cy, r, fill="none", sw=sw)]


def sparkle(cx, cy, r, col=pal.GOLD_LT, sw=3.0):
    """4-point glint star: the 'something is rigged here' tell accent."""
    pts = []
    for i in range(8):
        a = math.radians(-90 + i * 45)
        rr = r if i % 2 == 0 else r * 0.34
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return shape(pts, col, sw)


def motion_lines(pts_list, sw=3.0, ink=INK):
    return [polyline(p, sw, ink) for p in pts_list]


def hush_eyes(cx, cy, look=1, s=1.0, dark=True):
    """Hush's eyes peeking out of a dark gap: big round whites, big pupils with a glint (warm, never
    creepy - GDD §9.2). cx, cy = midpoint between the eyes. look = -1 left / +1 right."""
    out = []
    er = 13 * s
    gap = 16 * s
    for i, dx in enumerate((-gap, gap)):
        ex = cx + dx
        ey = cy + (1.5 * s if i == 0 else -0.5 * s)
        out.append(ellipse(ex, ey, er, er * 1.12, fill=pal.EYE_W, sil=False))
        out.append(ellipse(ex, ey, er, er * 1.12, fill="none", sw=3.0, stroke=INK, sil=False))
        px = ex + look * er * 0.32
        out.append(circle(px, ey + er * 0.1, er * 0.56, fill=INK, sil=False))
        out.append(circle(px - er * 0.2, ey - er * 0.2, er * 0.2, fill="#FFFFFF", sil=False))
    return out


def glove_fingers(x, y, side=1, s=1.0, n=3):
    """Hush's huge white glove fingertips curled round an edge at (x, y); side=+1 fingers point right."""
    out = []
    for i in range(n):
        fy = y + i * 15 * s
        fx = x
        pb = PB().rrect(fx - (0 if side > 0 else 20 * s), fy, 20 * s, 13 * s, 6.5 * s)
        out.append(path(pb, fill=pal.GLOVE, sil=False))
        out.append(path(pb, fill="none", sw=3.0, stroke=INK, sil=False))
    return out


def rope_sag(x1, y1, x2, y2, sag):
    mx = (x1 + x2) / 2
    return PB().M(x1, y1).Q(mx, max(y1, y2) + sag, x2, y2)


def dots_grid(x0, y0, x1, y1, step_x, step_y, r, offset_rows=True):
    """One path of many small circles (wallpaper / fabric dots)."""
    pb = PB()
    row = 0
    y = y0
    while y <= y1:
        x = x0 + (step_x / 2 if (offset_rows and row % 2) else 0)
        while x <= x1:
            pb.circle(x, y, r)
            x += step_x
        y += step_y
        row += 1
    return pb


def tassel_fringe(x0, x1, y, h, step=8):
    pb = PB()
    x = x0
    while x <= x1:
        pb.M(x, y).L(x, y + h)
        x += step
    return pb


def planks(x0, x1, y0, y1, step, jitter=0):
    """Vertical plank seams."""
    pb = PB()
    x = x0 + step
    i = 0
    while x < x1 - 2:
        pb.M(x, y0).L(x, y1)
        x += step + (jitter if i % 2 else -jitter)
        i += 1
    return pb
