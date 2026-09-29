#!/usr/bin/env python3
"""Generates the `_mannequin` cutout parts (a geometric stand-in rig for the rig system).

Run:  python3 game/art/chars/_mannequin/_src/build.py
Writes every SVG next to this folder (game/art/chars/_mannequin/). GDD §9.1 rules: navy ink
#1B2340, 6 px character outlines (3.5-4.5 px details), one flat shade tone per shape on the
lower/right (light from the top-left), <= 10 colours per file, 3 px canvas margin,
presentation attributes only, 1-decimal coordinates. Authored at display size (1x).
"""
import os

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK = "#1B2340"
W = 6          # silhouette outline
D = 4          # face / detail lines
HL = 'fill="#FFFFFF" fill-opacity="0.55"'

TEAL, TEAL_S = "#2FA39A", "#238A82"
NAVY, NAVY_S = "#3A4A7A", "#2C3963"
SKIN, SKIN_S = "#F1D3A8", "#D9B384"
MUST, MUST_S = "#F2B33D", "#D9952B"
RED, RED_S = "#E24B3B", "#B83A2E"
REDF, REDF_S = "#B83A2E", "#933024"
MITT, MITT_S = "#FFFFFF", "#D8DDEA"
MITTF, MITTF_S = "#D8DDEA", "#B9C0D4"
CREAM = "#FFF6EA"
TEA = "#8A5A3A"
MOUTH, TONGUE = "#7A1F2B", "#E0707A"
SOOT = "#3A3050"
WATER = "#7EC8F0"


def f(v):
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def svg(name, w, h, body):
    txt = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
           + "".join(body) + "</svg>\n")
    with open(os.path.join(OUT, name), "w") as fh:
        fh.write(txt)


def stroke(width=W):
    return f'stroke="{INK}" stroke-width="{f(width)}" stroke-linejoin="round" stroke-linecap="round"'


def ellipse(cx, cy, rx, ry, fill, line=W, extra=""):
    st = stroke(line) if line else 'stroke="none"'
    return f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}" {st} {extra}/>'


def circle(cx, cy, r, fill, line=W, extra=""):
    st = stroke(line) if line else 'stroke="none"'
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}" {st} {extra}/>'


def path(d, fill="none", line=W, extra=""):
    st = stroke(line) if line else 'stroke="none"'
    return f'<path d="{d}" fill="{fill}" {st} {extra}/>'


def rect(x, y, w, h, rx, fill, line=W):
    st = stroke(line) if line else 'stroke="none"'
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(rx)}" fill="{fill}" {st}/>'


def shaded_ellipse(cx, cy, rx, ry, base, shade):
    """Shade-first inset: the silhouette in shade, a lit ellipse up-left, then the outline."""
    return [ellipse(cx, cy, rx, ry, shade, 0),
            ellipse(cx - rx * 0.12, cy - ry * 0.12, rx * 0.84, ry * 0.84, base, 0),
            ellipse(cx, cy, rx, ry, "none", W)]


# --- body -------------------------------------------------------------------------------------

def hips():
    # Shorts: a rounded bean around the hip joint (pivot 46, 26).
    d = "M10 16 Q12 6 30 6 L62 6 Q80 6 82 16 L84 34 Q84 50 66 50 L26 50 Q8 50 8 34 Z"
    ds = "M84 30 Q84 50 66 50 L26 50 Q14 50 10 42 Q40 46 84 30 Z"
    svg("hips.svg", 92, 56, [path(d, NAVY, 0), path(ds, NAVY_S, 0), path(d, "none", W),
                             path("M46 30 L46 48", line=3.5)])


def torso():
    # A bean-shaped jersey, pivot at the waist (55, 116).
    d = "M20 30 Q24 6 55 6 Q86 6 92 30 L102 92 Q106 122 72 122 L38 122 Q4 122 8 92 Z"
    ds = "M104 96 Q106 122 72 122 L44 122 Q70 112 84 86 Q92 60 90 26 L102 92 Z"
    body = [path(d, TEAL, 0), path(ds, TEAL_S, 0),
            f'<path d="M26 34 Q30 16 48 14 Q38 22 34 40 Z" {HL}/>',
            path("M22 104 Q55 112 96 102", line=3.5),
            path(d, "none", W)]
    svg("torso.svg", 110, 128, body)


def torso_drips():
    # SOAKED overlay: wet patches + drips on the torso canvas.
    body = [path("M30 40 Q38 34 46 42 Q48 56 40 58 Q30 56 30 40 Z", WATER, 3.5, 'fill-opacity="0.85"'),
            path("M64 70 Q74 62 82 72 Q84 88 74 90 Q64 86 64 70 Z", WATER, 3.5, 'fill-opacity="0.85"'),
            path("M50 96 Q52 104 50 112 Q46 116 44 110 Q44 102 50 96 Z", WATER, 3.5),
            path("M86 92 Q88 100 86 106 Q82 110 80 104 Q80 98 86 92 Z", WATER, 3.5)]
    svg("torso_drips.svg", 110, 128, body)


def badge():
    # A chest badge with a letter-like zigzag: a no_mirror part (it counter-flips).
    body = shaded_ellipse(20, 20, 15, 15, MUST, MUST_S)
    body.append(path("M12 26 L14 14 L20 21 L26 14 L28 26", line=3.5))
    svg("badge.svg", 40, 40, body)


def head():
    # Circle head (centre 66, 70, r 58), nose on the right, ear on the left; pivot (66, 128).
    body = [circle(66, 70, 58, SKIN_S, 0),
            circle(60, 64, 50, SKIN, 0),
            f'<path d="M26 52 Q34 24 62 18 Q44 32 38 56 Z" {HL}/>',
            circle(66, 70, 58, "none", W),
            ellipse(28, 76, 9, 12, SKIN, 3.5),
            path("M28 70 Q24 76 29 82", line=3),
            circle(120, 88, 12, SKIN_S, 0), circle(118, 86, 9, SKIN, 0), circle(120, 88, 12, "none", 4.5)]
    svg("head.svg", 140, 136, body)


def hat(name, base, shade, wet=False, singed=False):
    # Bowler: dome + band + brim; pivot (58, 58) = brim centre.
    if wet:
        brim = "M8 58 Q10 70 22 66 Q58 60 94 66 Q106 70 108 58 Q58 50 8 58 Z"
    else:
        brim = "M6 58 Q8 66 30 66 L86 66 Q108 66 110 58 Q108 50 58 50 Q8 50 6 58 Z"
    dome = "M22 54 Q20 12 58 10 Q96 12 94 54 Z" if not singed else "M22 54 Q18 20 40 16 L48 22 L58 8 L68 20 L78 14 Q98 22 94 54 Z"
    dome_s = "M94 54 Q96 22 72 12 Q88 30 80 54 Z"
    body = [path(dome, base, 0), path(dome_s, shade, 0),
            f'<path d="M32 40 Q32 22 48 16 Q40 28 40 42 Z" {HL}/>',
            path(dome, "none", W),
            path("M22 44 Q58 50 94 44 L94 54 Q58 60 22 54 Z", NAVY, 4),
            path(brim, base, W)]
    if wet:
        body += [path("M30 68 Q31 76 30 80 Q27 82 26 78 Q26 73 30 68 Z", WATER, 3),
                 path("M88 68 Q89 75 88 79 Q85 81 84 77 Q84 72 88 68 Z", WATER, 3)]
    if singed:
        body += [ellipse(46, 34, 8, 6, SOOT, 0), ellipse(74, 28, 6, 5, SOOT, 0), ellipse(62, 44, 5, 3, SOOT, 0)]
    svg(name, 116, 84 if wet else 72, body)


def hand(name, base, shade, fist=False):
    # A mitten, wrist at the top (pivot 28, 10), fingers down, thumb forward (+x).
    cuff = rect(14, 4, 30, 12, 6, shade, 4.5)
    if fist:
        body = [circle(30, 38, 22, shade, 0), circle(27, 35, 18, base, 0), circle(30, 38, 22, "none", W),
                path("M22 50 Q30 54 38 50", line=3.5), path("M42 30 Q50 36 44 44", line=3.5), cuff]
    else:
        palm = "M10 24 Q10 14 28 14 Q46 14 46 26 L48 50 Q48 62 30 62 Q10 62 10 48 Z"
        thumb = "M44 26 Q58 20 58 32 Q58 40 46 42 Z"
        body = [path(thumb, base, W), path(palm, shade, 0),
                path("M12 24 Q12 16 28 16 Q42 16 42 26 L44 48 Q40 56 28 56 Q14 56 12 46 Z", base, 0),
                path(palm, "none", W), path("M24 46 L24 58", line=3), cuff]
    svg(name, 64, 68, body)


def foot(name, base, shade):
    # A round-toed shoe pointing right; ankle pivot (24, 10); sole at y 37.
    d = "M8 20 Q8 6 22 6 L34 6 Q40 18 54 18 Q72 20 72 32 Q72 37 64 37 L12 37 Q6 37 6 30 Z"
    ds = "M72 30 Q72 37 64 37 L20 37 Q46 32 70 26 Z"
    body = [path(d, base, 0), path(ds, shade, 0),
            f'<path d="M46 22 Q56 20 62 24 Q54 24 48 26 Z" {HL}/>',
            path("M8 31 L70 31", line=3), path(d, "none", W)]
    svg(name, 78, 40, body)


def mug(name, full):
    # A mug held by its handle (pivot 12, 26 = the handle's middle).
    body = [path("M16 16 Q2 16 4 28 Q6 40 18 38", line=5.5),
            path("M16 8 L50 8 L48 44 Q48 48 42 48 L22 48 Q18 48 18 44 Z", CREAM, 0),
            path("M50 8 L48 44 Q48 48 42 48 L36 48 Q44 30 42 8 Z", MITT_S, 0),
            path("M17 22 L50 22 L49.5 30 L17.5 30 Z", RED, 0),
            path("M16 8 L50 8 L48 44 Q48 48 42 48 L22 48 Q18 48 18 44 Z", "none", W)]
    if full:
        body.append(ellipse(33, 9, 15, 3.5, TEA, 3))
    else:
        body.append(ellipse(33, 9, 15, 3.5, "#E9DCCB", 3))
    svg(name, 56, 54, body)


# --- face (canvases centred on the face anchor) -----------------------------------------------

EYE_L, EYE_R, EYE_Y = 30, 64, 30


def eyes(name, kind):
    body = []
    if kind in ("open", "wide"):
        rx, ry = (13, 17) if kind == "open" else (16, 21)
        body += [ellipse(EYE_L, EYE_Y, rx, ry, "#FFFFFF", D), ellipse(EYE_R, EYE_Y, rx + 1, ry + 1, "#FFFFFF", D)]
    elif kind == "half":
        for cx, rx, ry in ((EYE_L, 13, 17), (EYE_R, 14, 18)):
            body += [ellipse(cx, EYE_Y, rx, ry, "#FFFFFF", 0),
                     path(f"M{cx - rx} {EYE_Y} Q{cx - rx} {EYE_Y - ry} {cx} {EYE_Y - ry} Q{cx + rx} {EYE_Y - ry} {cx + rx} {EYE_Y} Z", SKIN, 0),
                     ellipse(cx, EYE_Y, rx, ry, "none", D),
                     path(f"M{cx - rx} {EYE_Y + 1} L{cx + rx} {EYE_Y + 1}", line=D)]
    elif kind == "closed":
        for cx in (EYE_L, EYE_R):
            body.append(path(f"M{cx - 13} {EYE_Y + 2} Q{cx} {EYE_Y + 12} {cx + 13} {EYE_Y + 2}", line=5))
    elif kind == "squint":
        for cx, s in ((EYE_L, 1), (EYE_R, -1)):
            body.append(path(f"M{cx - 12 * s} {EYE_Y - 9} L{cx + 10 * s} {EYE_Y} L{cx - 12 * s} {EYE_Y + 9}", line=5))
    svg(name, 96, 60, body)


def pupils():
    body = []
    for cx, r in ((EYE_L + 2, 7), (EYE_R + 2, 7.5)):
        body += [circle(cx, EYE_Y + 2, r, INK, 0), circle(cx - 2.5, EYE_Y - 1, 2.2, "#FFFFFF", 0)]
    svg("pupils.svg", 96, 60, body)


def brows(name, kind):
    y = {"neutral": 16, "up": 10, "angry": 16, "worried": 16}[kind]
    dl = {"neutral": (0, 0), "up": (-2, -2), "angry": (-5, 5), "worried": (5, -5)}[kind]
    body = [path(f"M{18} {y + dl[0]} Q{30} {y - 4 + min(dl)} {42} {y + dl[1]}", line=6),
            path(f"M{56} {y + dl[1]} Q{68} {y - 4 + min(dl)} {80} {y + dl[0]}", line=6)]
    svg(name, 100, 30, body)


def mouth(name, kind):
    if kind == "smile":
        body = [path("M18 18 Q38 38 58 18", line=5)]
    elif kind == "frown":
        body = [path("M20 32 Q38 16 56 32", line=5)]
    elif kind == "flat":
        body = [path("M22 26 L54 26", line=5)]
    elif kind == "O":
        body = [ellipse(38, 26, 11, 15, MOUTH, D), ellipse(38, 33, 6, 4, TONGUE, 0)]
    elif kind == "open":
        body = [path("M12 14 Q38 18 64 14 Q62 46 38 46 Q14 46 12 14 Z", MOUTH, 0),
                ellipse(38, 38, 12, 6, TONGUE, 0),
                path("M12 14 Q38 18 64 14 Q62 46 38 46 Q14 46 12 14 Z", "none", D)]
    elif kind == "grit":
        body = [rect(14, 14, 48, 22, 9, "#FFFFFF", D), path("M16 25 L60 25", line=3), path("M30 15 L30 35 M46 15 L46 35", line=2.5)]
    elif kind == "pressed":
        body = [path("M18 26 Q28 22 38 26 Q48 30 58 26", line=5), path("M16 22 L16 30 M60 22 L60 30", line=3)]
    svg(name, 76, 52, body)


def main():
    hips(); torso(); torso_drips(); badge(); head()
    hat("hat.svg", MUST, MUST_S)
    hat("hat_wet.svg", "#C9922E", "#A87A24", wet=True)
    hat("hat_singed.svg", "#B8872E", "#8F6A24", singed=True)
    hand("hand_r_open.svg", MITT, MITT_S)
    hand("hand_r_fist.svg", MITT, MITT_S, fist=True)
    hand("hand_l_open.svg", MITTF, MITTF_S)
    hand("hand_l_fist.svg", MITTF, MITTF_S, fist=True)
    foot("foot_r.svg", RED, RED_S)
    foot("foot_l.svg", REDF, REDF_S)
    mug("mug_full.svg", True)
    mug("mug_empty.svg", False)
    for k in ("open", "half", "closed", "wide", "squint"):
        eyes(f"eyes_{k}.svg", k)
    pupils()
    for k in ("neutral", "up", "angry", "worried"):
        brows(f"brows_{k}.svg", k)
    for k in ("smile", "frown", "flat", "O", "open", "grit", "pressed"):
        mouth(f"mouth_{k}.svg", k)


if __name__ == "__main__":
    main()
