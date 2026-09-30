"""Face decal atlases for the Toy Box characters (SVG -> rsvg-convert -> PIL atlas).

Face space: a 1000 x 1000 SVG square = the planar FaceUV square on the head (u right as seen from the
front, v up; SVG y is down). Every LAYER (brows / eyes / mouth / extra) only needs its horizontal band of
the face, so a layer's cells are full-width but band-high. The toy shader samples one cell per layer
(index uniforms) and alpha-composites them over the skin colour.

python3 face_atlas.py <out_dir> [hush|bellows|all]   -> face_<who>.png, face_<who>.json, face_<who>_preview.png
"""
import os, sys, json, subprocess, math, io
from PIL import Image, ImageDraw

ATLAS = 1024
CELL_W = 340          # px per face width (3 cells per row)
INK = "#2A2036"


def svg_doc(body, y0, y1):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 %d 1000 %d">%s</svg>'
            % (CELL_W * 2, int(round(CELL_W * 2 * (y1 - y0) / 1000.0)), y0, y1 - y0, body))


def raster(body, y0, y1):
    """Render at 2x, return a PIL RGBA image of CELL_W x band height."""
    svg = svg_doc(body, y0, y1)
    png = subprocess.run(["rsvg-convert", "-f", "png"], input=svg.encode(), capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    h = int(round(CELL_W * (y1 - y0) / 1000.0))
    return im.resize((CELL_W, h), Image.LANCZOS)


# ------------------------------------------------------------------------------------------------
# drawing helpers (SVG snippets)
# ------------------------------------------------------------------------------------------------
def ell(cx, cy, rx, ry, fill, stroke=None, sw=0, rot=0, extra=""):
    s = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    if rot:
        s += f' transform="rotate({rot} {cx} {cy})"'
    return s + f' {extra}/>'


def path(d, fill="none", stroke=INK, sw=16, cap="round", join="round", extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="{join}" {extra}/>'


def mirror_x(fn):
    """Draw fn(side, cx) for both eyes: side -1 = viewer's left eye."""
    return fn


# ================================================================================================
# HUSH  (head: face square 0.58 m; eyes at y 552, x 336/664; mouth y 736; fringe ~ y 320)
# ================================================================================================
H_EYE_Y = 540
H_EYE_X = (334, 666)
H_EYE = "#2B2140"


def h_eye_open(look=0, lid=0.0, scale=1.0, sparkle=True):
    out = []
    for i, cx in enumerate(H_EYE_X):
        rx, ry = 70 * scale, 92 * scale
        cid = f"c{i}{int(lid*100)}{int(scale*100)}"
        clip = ""
        if lid > 0:
            # an upper lid cut (sleepy / sly), slanting down toward the outer corner
            top = H_EYE_Y - ry + 2 * ry * lid
            slope = 14 if i == 1 else -14
            clip = f'<clipPath id="{cid}"><path d="M{cx-120},{top-slope} L{cx+120},{top+slope} L{cx+120},{H_EYE_Y+200} L{cx-120},{H_EYE_Y+200} Z"/></clipPath>'
        out.append(clip)
        g = f'<g clip-path="url(#{cid})">' if lid > 0 else "<g>"
        g += ell(cx, H_EYE_Y, rx, ry, H_EYE)
        # warm iris glow at the bottom
        g += ell(cx + look * 6, H_EYE_Y + ry * 0.45, rx * 0.62, ry * 0.36, "#5B3B63")
        if sparkle:
            g += ell(cx + 20 * scale + look * 10, H_EYE_Y - 34 * scale, 22 * scale, 26 * scale, "#FFFFFF")
            g += ell(cx - 22 * scale + look * 8, H_EYE_Y + 30 * scale, 9 * scale, 9 * scale, "#FFFFFF")
        g += "</g>"
        out.append(g)
        if lid > 0:
            top = H_EYE_Y - ry + 2 * ry * lid
            slope = 14 if i == 1 else -14
            out.append(path(f"M{cx-rx-6},{top-slope*0.9} Q{cx},{top-8} {cx+rx+6},{top+slope*0.9}", sw=15))
        else:
            # a single lash flick at the outer corner
            ox = cx + (rx - 6) * (1 if i == 1 else -1)
            out.append(path(f"M{ox},{H_EYE_Y-ry*0.55} q{18*(1 if i==1 else -1)},-16 {30*(1 if i==1 else -1)},-12", sw=11))
    return "".join(out)


def h_eye_arcs(kind):
    out = []
    for i, cx in enumerate(H_EYE_X):
        if kind == "happy":      # ^ ^
            out.append(path(f"M{cx-54},{H_EYE_Y+22} Q{cx},{H_EYE_Y-62} {cx+54},{H_EYE_Y+22}", sw=20))
        elif kind == "closed":   # soft closed lids
            out.append(path(f"M{cx-56},{H_EYE_Y+4} Q{cx},{H_EYE_Y+46} {cx+56},{H_EYE_Y+4}", sw=18))
            ox = cx + 56 * (1 if i == 1 else -1)
            out.append(path(f"M{ox},{H_EYE_Y+4} l{16*(1 if i==1 else -1)},-12", sw=10))
        elif kind == "squeeze":  # > <
            d = 1 if i == 0 else -1
            out.append(path(f"M{cx-40*d},{H_EYE_Y-40} L{cx+40*d},{H_EYE_Y} L{cx-40*d},{H_EYE_Y+40}", sw=20))
        elif kind == "spiral":
            pts = []
            for k in range(60):
                a = k * 0.36
                r = 4 + k * 1.05
                pts.append((cx + r * math.cos(a), H_EYE_Y + r * math.sin(a) * 1.15))
            d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
            out.append(path(d, sw=11))
    return "".join(out)


def h_eye_wide():
    out = []
    for cx in H_EYE_X:
        out.append(ell(cx, H_EYE_Y - 6, 70, 90, "#FFFFFF", INK, 12))
        out.append(ell(cx, H_EYE_Y - 2, 24, 30, H_EYE))
        out.append(ell(cx + 8, H_EYE_Y - 12, 7, 8, "#FFFFFF"))
    return "".join(out)


def h_eye_angry():
    out = []
    for i, cx in enumerate(H_EYE_X):
        inner = 1 if i == 0 else -1   # direction toward the nose
        cid = f"ang{i}"
        out.append(f'<clipPath id="{cid}"><path d="M{cx-120},{H_EYE_Y-60-40*inner} L{cx+120},{H_EYE_Y-60+40*inner} L{cx+120},{H_EYE_Y+200} L{cx-120},{H_EYE_Y+200} Z"/></clipPath>')
        g = f'<g clip-path="url(#{cid})">' + ell(cx, H_EYE_Y + 6, 58, 74, H_EYE)
        g += ell(cx + 16, H_EYE_Y - 4, 13, 14, "#FFFFFF") + "</g>"
        out.append(g)
        out.append(path(f"M{cx-70},{H_EYE_Y-66-40*inner} L{cx+70},{H_EYE_Y-66+40*inner}", sw=18))
    return "".join(out)


def h_eye_teary():
    """sneeze build: eyes screwed half shut, watering, looking up."""
    out = []
    for i, cx in enumerate(H_EYE_X):
        cid = f"tear{i}"
        out.append(f'<clipPath id="{cid}"><rect x="{cx-100}" y="{H_EYE_Y-10}" width="200" height="200"/></clipPath>')
        out.append(f'<g clip-path="url(#{cid})">' + ell(cx, H_EYE_Y + 10, 60, 62, H_EYE) + ell(cx + 18, H_EYE_Y + 4, 16, 12, "#FFFFFF") + "</g>")
        out.append(path(f"M{cx-66},{H_EYE_Y-2} Q{cx},{H_EYE_Y-36} {cx+66},{H_EYE_Y-2}", sw=17))
        out.append(ell(cx + 40 * (1 if i == 1 else -1), H_EYE_Y + 70, 13, 17, "#8FD3F4", INK, 6))
    return "".join(out)


H_BROW_Y = 418


def h_brow(kind):
    out = []
    for i, cx in enumerate(H_EYE_X):
        s = -1 if i == 0 else 1          # outward direction
        if kind == "neutral":
            d = f"M{cx-50},{H_BROW_Y+6} Q{cx},{H_BROW_Y-22} {cx+50},{H_BROW_Y+6}"
        elif kind == "raised":
            d = f"M{cx-52},{H_BROW_Y-24} Q{cx},{H_BROW_Y-66} {cx+52},{H_BROW_Y-24}"
        elif kind == "angry":
            d = f"M{cx-52*s},{H_BROW_Y-26} L{cx+46*s},{H_BROW_Y+26}" if False else f"M{cx+52*s},{H_BROW_Y-22} Q{cx},{H_BROW_Y-4} {cx-44*s},{H_BROW_Y+30}"
        elif kind == "worried":
            d = f"M{cx+52*s},{H_BROW_Y+14} Q{cx},{H_BROW_Y-12} {cx-44*s},{H_BROW_Y-34}"
        elif kind == "sly":
            if i == 0:
                d = f"M{cx-50},{H_BROW_Y+14} Q{cx},{H_BROW_Y+2} {cx+50},{H_BROW_Y+18}"
            else:
                d = f"M{cx-50},{H_BROW_Y-10} Q{cx},{H_BROW_Y-52} {cx+54},{H_BROW_Y-24}"
        else:
            return ""
        out.append(path(d, sw=15))
    return "".join(out)


H_MOUTH_Y = 736
M_DARK = "#5A1F36"
TONGUE = "#F07A8A"


def h_mouth(kind):
    y = H_MOUTH_Y
    if kind == "smile":
        return path(f"M{438},{y-8} Q500,{y+34} {562},{y-8}", sw=15)
    if kind == "grin":        # sneaky wide open grin
        d = f"M400,{y-22} Q500,{y-4} 600,{y-30} Q580,{y+62} 500,{y+66} Q420,{y+62} 400,{y-22} Z"
        return (path(d, fill=M_DARK, sw=13) +
                f'<clipPath id="gr"><path d="{d}"/></clipPath><g clip-path="url(#gr)">' +
                ell(500, y + 70, 60, 34, TONGUE) + f'<rect x="380" y="{y-40}" width="240" height="34" fill="#FFFFFF"/></g>' +
                path(d, sw=13))
    if kind == "o":
        return ell(500, y + 8, 34, 46, M_DARK, INK, 12) + ell(500, y + 34, 20, 12, TONGUE)
    if kind == "snicker":     # closed-teeth hee-hee
        d = f"M410,{y-16} Q500,{y+8} 590,{y-16} Q576,{y+44} 500,{y+50} Q424,{y+44} 410,{y-16} Z"
        return (path(d, fill="#FFFFFF", sw=12) + path(f"M420,{y+6} Q500,{y+22} 580,{y+6}", sw=7) +
                path(f"M500,{y+2} L500,{y+46}", sw=6) + path(f"M458,{y+2} L462,{y+40}", sw=6) + path(f"M542,{y+2} L538,{y+40}", sw=6))
    if kind == "grit":        # furious clenched teeth
        d = f"M410,{y-20} L590,{y-20} Q600,{y+36} 580,{y+40} L420,{y+40} Q400,{y+36} 410,{y-20} Z"
        return (path(d, fill="#FFFFFF", sw=13) + path(f"M412,{y+10} L588,{y+10}", sw=7) +
                "".join(path(f"M{x},{y-18} L{x},{y+38}", sw=6) for x in (455, 500, 545)))
    if kind == "ah":          # sneeze build: wobbly open mouth, tongue up
        d = f"M452,{y-10} Q500,{y-30} 548,{y-10} Q562,{y+50} 500,{y+74} Q438,{y+50} 452,{y-10} Z"
        return path(d, fill=M_DARK, sw=13) + ell(500, y + 52, 26, 14, TONGUE)
    if kind == "choo":        # big blast
        d = f"M420,{y-34} Q500,{y-50} 580,{y-34} Q610,{y+60} 500,{y+96} Q390,{y+60} 420,{y-34} Z"
        return path(d, fill=M_DARK, sw=13) + ell(500, y + 70, 50, 22, TONGUE)
    if kind == "wavy":
        return path(f"M430,{y+6} q18,-18 35,0 t35,0 t35,0 t35,0", sw=13)
    if kind == "frown":
        return path(f"M446,{y+20} Q500,{y-16} 554,{y+20}", sw=15)
    if kind == "shh":         # small pursed 'o'
        return ell(500, y + 4, 16, 14, M_DARK, INK, 10)
    return ""


def h_extra(kind):
    cheek = lambda cx, a: f'<ellipse cx="{cx}" cy="662" rx="62" ry="36" fill="#FF8C99" fill-opacity="{a}"/>'
    tear = path("M318,672 q-10,24 0,36 q10,-12 0,-36 Z", fill="#2B3566", stroke="#2B3566", sw=6)
    if kind == "cheeks":
        return cheek(232, 0.78) + cheek(768, 0.78) + tear
    if kind == "blush":
        return (cheek(232, 0.95) + cheek(768, 0.95) + tear +
                "".join(path(f"M{x},650 l-14,26", stroke="#E0576A", sw=7) for x in (214, 238, 262, 750, 774, 798)))
    if kind == "sweat":
        return (cheek(232, 0.7) + cheek(768, 0.7) + tear +
                path("M846,420 q-28,44 0,62 q28,-18 0,-62 Z", fill="#8FD3F4", sw=8))
    return ""


HUSH = {
    "layers": {
        # name: (band y0, y1 in face units, [(variant, svg)])
        "brows": (330, 480, [("none", ""), ("neutral", h_brow("neutral")), ("raised", h_brow("raised")),
                             ("angry", h_brow("angry")), ("worried", h_brow("worried")), ("sly", h_brow("sly"))]),
        "eyes": (440, 670, [("open", h_eye_open()), ("happy", h_eye_arcs("happy")), ("closed", h_eye_arcs("closed")),
                            ("sly", h_eye_open(look=1, lid=0.42)), ("wide", h_eye_wide()), ("angry", h_eye_angry()),
                            ("squeeze", h_eye_arcs("squeeze")), ("spiral", h_eye_arcs("spiral")), ("teary", h_eye_teary())]),
        "mouth": (680, 840, [("none", ""), ("smile", h_mouth("smile")), ("grin", h_mouth("grin")), ("o", h_mouth("o")),
                             ("snicker", h_mouth("snicker")), ("grit", h_mouth("grit")), ("ah", h_mouth("ah")),
                             ("choo", h_mouth("choo")), ("wavy", h_mouth("wavy")), ("frown", h_mouth("frown")),
                             ("shh", h_mouth("shh"))]),
        "extra": (400, 720, [("none", ""), ("cheeks", h_extra("cheeks")), ("blush", h_extra("blush")), ("sweat", h_extra("sweat"))]),
    },
    "presets": {
        "neutral": {"eyes": "open", "brows": "neutral", "mouth": "smile", "extra": "cheeks"},
        "sneaky": {"eyes": "sly", "brows": "sly", "mouth": "grin", "extra": "cheeks"},
        "shock": {"eyes": "wide", "brows": "raised", "mouth": "o", "extra": "sweat"},
        "furious": {"eyes": "angry", "brows": "angry", "mouth": "grit", "extra": "cheeks"},
        "sneeze_build": {"eyes": "teary", "brows": "worried", "mouth": "ah", "extra": "blush"},
        "dazed": {"eyes": "spiral", "brows": "worried", "mouth": "wavy", "extra": "cheeks"},
        "snicker": {"eyes": "happy", "brows": "raised", "mouth": "snicker", "extra": "blush"},
        "blink": {"eyes": "closed", "brows": "neutral", "mouth": "smile", "extra": "cheeks"},
        "statue": {"eyes": "closed", "brows": "raised", "mouth": "smile", "extra": "cheeks"},
        "focus": {"eyes": "sly", "brows": "neutral", "mouth": "shh", "extra": "cheeks"},
        "choo": {"eyes": "squeeze", "brows": "angry", "mouth": "choo", "extra": "blush"},
    },
    "skin": "#FFF6EA",
}


# ================================================================================================
# BELLOWS  (face square 0.52 m; small beady eyes under heavy lids at y 470, x 372/628; big nose (3D)
# at the centre; mouth y 700 under the nose; bushy silver brows; the sideburns are 3D)
# ================================================================================================
B_EYE_Y = 442
B_EYE_X = (334, 666)
LID = "#E8B594"     # lid a shade darker than the peach skin
B_INK = "#2A2036"
SILVER = "#DADDE8"


def b_eyes(kind):
    out = []
    for i, cx in enumerate(B_EYE_X):
        inner = 1 if i == 0 else -1
        if kind in ("open", "pompous", "suspicious"):
            lid = {"open": 0.3, "pompous": 0.58, "suspicious": 0.62}[kind]
            rx, ry = 72, 76
            out.append(ell(cx, B_EYE_Y, rx, ry, "#FFFFFF", B_INK, 10))
            px = cx + (8 * inner if kind == "suspicious" else 0)
            out.append(ell(px, B_EYE_Y + 12, 34, 38, "#241A2E"))
            out.append(ell(px + 12, B_EYE_Y, 11, 11, "#FFFFFF"))
            top = B_EYE_Y - ry + 2 * ry * lid
            sl = (-10 if kind != "suspicious" else 8) * inner
            cid = f"bl{i}{kind}"
            out.append(f'<clipPath id="{cid}"><ellipse cx="{cx}" cy="{B_EYE_Y}" rx="{rx+5}" ry="{ry+5}"/></clipPath>')
            out.append(f'<g clip-path="url(#{cid})"><path d="M{cx-80},{B_EYE_Y-120} L{cx+80},{B_EYE_Y-120} L{cx+80},{top+sl} L{cx-80},{top-sl} Z" fill="{LID}"/></g>')
            out.append(path(f"M{cx-rx-8},{top-sl*1.1} L{cx+rx+8},{top+sl*1.1}", stroke=B_INK, sw=13))
        elif kind == "wide":
            out.append(ell(cx, B_EYE_Y - 8, 80, 92, "#FFFFFF", B_INK, 13))
            out.append(ell(cx, B_EYE_Y - 4, 19, 21, "#241A2E"))
        elif kind == "furious":
            out.append(ell(cx, B_EYE_Y + 6, 68, 58, "#FFFFFF", B_INK, 12))
            out.append(ell(cx + 4 * inner, B_EYE_Y + 14, 26, 28, "#241A2E"))
            cid = f"bf{i}"
            out.append(f'<clipPath id="{cid}"><ellipse cx="{cx}" cy="{B_EYE_Y+6}" rx="50" ry="44"/></clipPath>')
            out.append(f'<g clip-path="url(#{cid})"><path d="M{cx-80},{B_EYE_Y-100} L{cx+80},{B_EYE_Y-100} L{cx+80},{B_EYE_Y-14+22*inner} L{cx-80},{B_EYE_Y-14-22*inner} Z" fill="{LID}"/></g>')
            out.append(path(f"M{cx-52},{B_EYE_Y-16-24*inner} L{cx+52},{B_EYE_Y-16+24*inner}", stroke=B_INK, sw=14))
        elif kind == "squeeze":   # screwed shut (sneeze build)
            out.append(path(f"M{cx-46},{B_EYE_Y+6} Q{cx},{B_EYE_Y-30} {cx+46},{B_EYE_Y+6}", stroke=B_INK, sw=16))
            out.append(path(f"M{cx-30},{B_EYE_Y+22} Q{cx},{B_EYE_Y+10} {cx+30},{B_EYE_Y+22}", stroke=B_INK, sw=9))
        elif kind == "shut":      # CHOO: > <
            d = 1 if i == 0 else -1
            out.append(path(f"M{cx-34*d},{B_EYE_Y-32} L{cx+34*d},{B_EYE_Y} L{cx-34*d},{B_EYE_Y+32}", stroke=B_INK, sw=17))
        elif kind == "spiral":
            pts = []
            for k in range(50):
                a = k * 0.4
                r = 3 + k * 1.0
                pts.append((cx + r * math.cos(a) * inner, B_EYE_Y + r * math.sin(a)))
            out.append(path("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts), stroke=B_INK, sw=10))
        elif kind == "closed":
            out.append(path(f"M{cx-44},{B_EYE_Y+4} Q{cx},{B_EYE_Y+30} {cx+44},{B_EYE_Y+4}", stroke=B_INK, sw=14))
    return "".join(out)


B_BROW_Y = 352


def b_brows(kind):
    out = []
    for i, cx in enumerate(B_EYE_X):
        s = -1 if i == 0 else 1   # outward
        if kind == "neutral":
            pts = [(cx - 70, B_BROW_Y + 10), (cx, B_BROW_Y - 22), (cx + 70, B_BROW_Y + 10)]
        elif kind == "pompous":   # arched high and haughty
            pts = [(cx - 72, B_BROW_Y + 2), (cx + 6 * s, B_BROW_Y - 44), (cx + 74, B_BROW_Y - 2)]
        elif kind == "raised":
            pts = [(cx - 70, B_BROW_Y - 30), (cx, B_BROW_Y - 72), (cx + 70, B_BROW_Y - 30)]
        elif kind == "angry":
            pts = [(cx + 74 * s, B_BROW_Y - 30), (cx + 10 * s, B_BROW_Y - 2), (cx - 58 * s, B_BROW_Y + 40)]
        elif kind == "worried":
            pts = [(cx + 74 * s, B_BROW_Y + 22), (cx, B_BROW_Y - 10), (cx - 60 * s, B_BROW_Y - 40)]
        elif kind == "sneeze":    # pulled up and together
            pts = [(cx + 72 * s, B_BROW_Y + 6), (cx - 4 * s, B_BROW_Y - 36), (cx - 62 * s, B_BROW_Y - 20)]
        else:
            return ""
        (x0, y0), (x1, y1), (x2, y2) = pts
        d = f"M{x0},{y0} Q{x1},{y1} {x2},{y2}"
        # bushy: a thick silver stroke with an ink edge, plus tufts
        out.append(path(d, stroke=B_INK, sw=58))
        out.append(path(d, stroke=SILVER, sw=40))
        for t in (0.2, 0.5, 0.8):
            bx = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
            by = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
            out.append(path(f"M{bx-8},{by-6} l{10*s},-18", stroke="#A7ACBE", sw=6))
    return "".join(out)


B_MOUTH_Y = 748


def b_mouth(kind):
    inner = _b_mouth(kind)
    return f'<g transform="translate(500 {B_MOUTH_Y}) scale(1.6) translate(-500 -{B_MOUTH_Y})">{inner}</g>' if inner else ""


def _b_mouth(kind):
    y = B_MOUTH_Y
    if kind == "pursed":     # pompous little pout
        return path(f"M464,{y+4} Q500,{y-16} 536,{y+4}", stroke=B_INK, sw=14) + ell(500, y + 12, 12, 6, "#C4726E")
    if kind == "smug":
        return path(f"M446,{y+6} Q500,{y+22} 560,{y-12}", stroke=B_INK, sw=14)
    if kind == "o":
        return ell(500, y + 16, 34, 44, M_DARK, B_INK, 11) + ell(500, y + 40, 20, 11, TONGUE)
    if kind == "rage":       # PIPE DOWN! square bellow with teeth
        d = f"M420,{y-24} L580,{y-24} Q596,{y+60} 570,{y+74} L430,{y+74} Q404,{y+60} 420,{y-24} Z"
        return (path(d, fill=M_DARK, stroke=B_INK, sw=12) + f'<clipPath id="rg"><path d="{d}"/></clipPath>' +
                f'<g clip-path="url(#rg)"><rect x="410" y="{y-30}" width="180" height="30" fill="#FFFFFF"/>' +
                ell(500, y + 78, 56, 26, TONGUE) + "</g>" + path(d, stroke=B_INK, sw=12))
    if kind == "ah":         # sneeze build: gaping, trembling
        d = f"M458,{y-8} Q500,{y-26} 542,{y-8} Q556,{y+60} 500,{y+80} Q444,{y+60} 458,{y-8} Z"
        return path(d, fill=M_DARK, stroke=B_INK, sw=12) + ell(500, y + 60, 24, 12, TONGUE)
    if kind == "choo":
        d = f"M424,{y-30} Q500,{y-44} 576,{y-30} Q604,{y+70} 500,{y+100} Q396,{y+70} 424,{y-30} Z"
        return path(d, fill=M_DARK, stroke=B_INK, sw=12) + ell(500, y + 76, 44, 20, TONGUE)
    if kind == "wavy":
        return path(f"M444,{y+8} q14,-16 28,0 t28,0 t28,0 t28,0", stroke=B_INK, sw=12)
    if kind == "sip":        # lips pushed out to the cup
        return ell(500, y + 4, 22, 16, "#C4726E", B_INK, 10)
    return ""


def b_extra(kind):
    if kind == "none":
        return ""
    if kind == "steam":      # anger vein
        return (path("M820,290 l24,-24 m-4,28 l28,-4 m-50,-8 l-4,-30 m-6,40 l-30,4", stroke="#D8344A", sw=14))
    if kind == "sweat":
        return path("M818,330 q-26,40 0,58 q26,-18 0,-58 Z", fill="#8FD3F4", stroke=B_INK, sw=7)
    if kind == "tears":
        return "".join(ell(x, 540, 14, 19, "#8FD3F4", B_INK, 6) for x in (300, 700))
    return ""


BELLOWS = {
    "layers": {
        "brows": (240, 420, [("none", ""), ("neutral", b_brows("neutral")), ("pompous", b_brows("pompous")),
                             ("raised", b_brows("raised")), ("angry", b_brows("angry")), ("worried", b_brows("worried")),
                             ("sneeze", b_brows("sneeze"))]),
        "eyes": (330, 560, [("open", b_eyes("open")), ("pompous", b_eyes("pompous")), ("suspicious", b_eyes("suspicious")),
                            ("wide", b_eyes("wide")), ("furious", b_eyes("furious")), ("squeeze", b_eyes("squeeze")),
                            ("shut", b_eyes("shut")), ("spiral", b_eyes("spiral")), ("closed", b_eyes("closed"))]),
        "mouth": (660, 900, [("none", ""), ("pursed", b_mouth("pursed")), ("smug", b_mouth("smug")), ("o", b_mouth("o")),
                             ("rage", b_mouth("rage")), ("ah", b_mouth("ah")), ("choo", b_mouth("choo")),
                             ("wavy", b_mouth("wavy")), ("sip", b_mouth("sip"))]),
        "extra": (250, 620, [("none", ""), ("steam", b_extra("steam")), ("sweat", b_extra("sweat")), ("tears", b_extra("tears"))]),
    },
    "presets": {
        "neutral": {"eyes": "open", "brows": "neutral", "mouth": "pursed", "extra": "none"},
        "pompous": {"eyes": "pompous", "brows": "pompous", "mouth": "smug", "extra": "none"},
        "shock": {"eyes": "wide", "brows": "raised", "mouth": "o", "extra": "sweat", "specs": 1},
        "furious": {"eyes": "furious", "brows": "angry", "mouth": "rage", "extra": "steam", "temper": 1.0, "specs": 1},
        "sneeze_build": {"eyes": "squeeze", "brows": "sneeze", "mouth": "ah", "extra": "tears", "temper": 0.35},
        "dazed": {"eyes": "spiral", "brows": "worried", "mouth": "wavy", "extra": "none", "temper": 0.15},
        "choo": {"eyes": "shut", "brows": "angry", "mouth": "choo", "extra": "none", "temper": 0.5},
        "sip": {"eyes": "closed", "brows": "pompous", "mouth": "sip", "extra": "none"},
        "blink": {"eyes": "closed", "brows": "neutral", "mouth": "pursed", "extra": "none"},
        "suspicious": {"eyes": "suspicious", "brows": "angry", "mouth": "pursed", "extra": "none", "temper": 0.3, "specs": 1},
    },
    "skin": "#F4C9A8",
}


def build(who, spec, out_dir):
    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    per_row = ATLAS // CELL_W
    y = 0
    layout = {"atlas": ATLAS, "layers": {}}
    for lname in ("brows", "eyes", "mouth", "extra"):
        y0, y1, variants = spec["layers"][lname]
        ch = int(round(CELL_W * (y1 - y0) / 1000.0))
        cells = []
        for i, (vname, svg) in enumerate(variants):
            col, row = i % per_row, i // per_row
            px, py = col * CELL_W, y + row * ch
            if svg:
                im = raster(svg, y0, y1)
                atlas.alpha_composite(im, (px, py))
            cells.append(vname)
        rows = (len(variants) + per_row - 1) // per_row
        layout["layers"][lname] = {"band": [1.0 - y1 / 1000.0, 1.0 - y0 / 1000.0], "origin_px": [0, y], "cell_px": [CELL_W, ch],
                                   "per_row": per_row, "cells": cells}
        y += rows * ch + 2
        assert y <= ATLAS, (who, lname, y)
    # alpha bleed: fully transparent pixels take the ink colour (no light fringes under filtering)
    px = atlas.load()
    ink = (0x2A, 0x20, 0x36)
    for yy in range(ATLAS):
        for xx in range(ATLAS):
            r, g, b, a = px[xx, yy]
            if a == 0:
                px[xx, yy] = (ink[0], ink[1], ink[2], 0)
    atlas.save(os.path.join(out_dir, f"face_{who}.png"))
    layout["used_px"] = y
    layout["presets"] = spec["presets"]
    json.dump(layout, open(os.path.join(out_dir, f"face_{who}.json"), "w"), indent=1)
    # preview: every preset composited over a skin disc (quick check without the engine)
    names = list(spec["presets"].keys())
    P = Image.new("RGBA", (CELL_W * len(names) // 2 + 1, CELL_W * 2 + 40), (40, 34, 52, 255))
    d = ImageDraw.Draw(P)
    for k, pn in enumerate(names):
        face = Image.new("RGBA", (CELL_W, CELL_W), (0, 0, 0, 0))
        fd = ImageDraw.Draw(face)
        fd.ellipse((10, 10, CELL_W - 10, CELL_W - 10), fill=spec["skin"])
        pr = spec["presets"][pn]
        for lname in ("extra", "brows", "eyes", "mouth"):
            L = layout["layers"][lname]
            vi = L["cells"].index(pr[lname])
            col, row = vi % per_row, vi // per_row
            cw, ch = L["cell_px"]
            box = (col * cw, L["origin_px"][1] + row * ch, col * cw + cw, L["origin_px"][1] + row * ch + ch)
            cell = atlas.crop(box)
            yb = int(round((1.0 - L["band"][1]) * CELL_W))
            face.alpha_composite(cell, (0, yb))
        x, yy = (k % (len(names) // 2 + len(names) % 2)) * (CELL_W // 2), (k // (len(names) // 2 + len(names) % 2)) * (CELL_W + 20)
        P.alpha_composite(face.resize((CELL_W // 2, CELL_W // 2)), (x, yy // 2 * 1))
        d.text((x + 4, yy // 2 + CELL_W // 2 - 12), pn, fill=(255, 240, 200))
    P.save(os.path.join(out_dir, f"face_{who}_preview.png"))
    print("FACE", who, "rows used", y, "px")


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    if which in ("hush", "all"):
        build("hush", HUSH, out)
    if which in ("bellows", "all"):
        build("bellows", BELLOWS, out)
