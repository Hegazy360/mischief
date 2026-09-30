"""face_atlas -- Hush's R3D face-decal atlas (look A's painted-decal style, the 2D face vocabulary).

    python3 tools/art3d/hush/face_atlas.py <out_dir> [--json-dir <dir>] [--preview]

Writes <out_dir>/face_hush.png (1024 x 1024 RGBA, an 8 x 8 grid of 128 px cells) and <json_dir>/face_hush.json (the cell
table, layer rects, mirror cells, blink + pupil data write_rig.py puts into rig3d.json). rsvg-convert rasterises each cell.

FACE SPACE. The head's front faces carry a planar FaceUV (glTF TEXCOORD_1): a square of D.FACE_W metres centred on
the face; in the shader fuv = (UV2.x, 1 - UV2.y) is (u right as seen from the front = her LEFT, v up). Each LAYER owns
a rect [u0, v0, u1, v1] of that square; its current cell (128 x 128 px) is stretched over the rect:
    atlas_uv = ((col + lu) / 8, (row + 1 - lv) / 8),  lu = (u - u0) / (u1 - u0), lv = (v - v0) / (v1 - v0)
(row 0 = the top row of the PNG; cell index = row * 8 + col). Cells are drawn in face units (1000 x 1000 = the face
square, SVG y down) inside the layer rect, so every layer lines up with every other.

Readability at 1200 x 540 (brief 4.3 bar): eye whites 0.075 m tall (~10 px), pupils 0.036 m (~4.8 px), brows 0.026 m
thick (~3.5 px), smile 0.13 m wide (~17 px). Warm, never creepy: big round warm-brown pupils with two highlights, rosy
cheeks, a smiling default, thin lash flicks, no black lips; the little navy teardrop under her left eye.
"""
import io
import json
import math
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

ATLAS, GRID, CELL = 1024, 8, 128
INK = "#2A2036"
BROW = "#3A2230"
IRIS = "#5A3424"
IRIS_GLOW = "#8C5A38"
PUPIL = "#1E1216"
RIM = "#7A5A60"
MOUTH = "#6E1F34"
TONGUE = "#F07A8A"
CHEEK = "#FF9AA2"
TEAR_MARK = "#2B3566"
WATER = "#8FD3F4"
WHITE = "#FFFFFF"

# layer rects in face UV (u0, v0, u1, v1), v up
RECTS = {
    "brows": (0.08, 0.63, 0.92, 0.89),
    "eyes": (0.08, 0.33, 0.92, 0.73),
    "pupils": (0.08, 0.33, 0.92, 0.73),
    "mouth": (0.16, 0.06, 0.84, 0.37),
    "extra_a": (0.0, 0.16, 1.0, 0.62),
    "extra_b": (0.0, 0.0, 1.0, 1.0),
}
LAYERS = ["brows", "eyes", "pupils", "mouth", "extra_a", "extra_b"]
# composite order the shader should use (under -> over)
DRAW_ORDER = ["extra_a", "brows", "eyes", "pupils", "mouth", "extra_b"]

EYE_Y = 473                   # face units (SVG y down): v 0.527 = z 1.360 m
EYE_X = (298, 702)            # viewer's left (her right), viewer's right (her left)
EYE_RX, EYE_RY = 104, 130
IRIS_R = 84
BROW_Y = 240                  # v 0.760 = z 1.430 m
BROW_W = 86                   # stroke (0.026 m)
MOUTH_Y = 772                 # v 0.228 = z 1.270 m


# -------------------------------------------------------------------------------------------------------------
# svg helpers
# -------------------------------------------------------------------------------------------------------------
def ell(cx, cy, rx, ry, fill, stroke=None, sw=0, rot=0, opacity=None):
    s = f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    if rot:
        s += f' transform="rotate({rot} {cx:.1f} {cy:.1f})"'
    if opacity is not None:
        s += f' fill-opacity="{opacity}"'
    return s + "/>"


def path(d, fill="none", stroke=INK, sw=16, cap="round", join="round", extra=""):
    return (f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" '
            f'stroke-linejoin="{join}" {extra}/>')


def raster(body: str, rect) -> Image.Image:
    """Rasterise face-unit SVG `body` over a layer rect into one 128 x 128 cell (drawn at 2x, downsampled)."""
    u0, v0, u1, v1 = rect
    x0, x1 = u0 * 1000.0, u1 * 1000.0
    y0, y1 = (1.0 - v1) * 1000.0, (1.0 - v0) * 1000.0
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{CELL * 2}" height="{CELL * 2}" '
           f'viewBox="{x0:.2f} {y0:.2f} {x1 - x0:.2f} {y1 - y0:.2f}" preserveAspectRatio="none">{body}</svg>')
    png = subprocess.run(["rsvg-convert", "-f", "png"], input=svg.encode(), capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return im.resize((CELL, CELL), Image.LANCZOS)


def raster_square(body: str) -> Image.Image:
    """A standalone card (the hiding-spot eye card): a 1000 x 1000 viewBox straight into the cell."""
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{CELL * 2}" height="{CELL * 2}" viewBox="0 0 1000 1000">'
           f'{body}</svg>')
    png = subprocess.run(["rsvg-convert", "-f", "png"], input=svg.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)


# -------------------------------------------------------------------------------------------------------------
# eyes (whites + ink rim + lash flick; pupils are their own layer for open / wide, baked for the rest)
# -------------------------------------------------------------------------------------------------------------
def iris(cx, cy, r=IRIS_R, look=(0, 0)):
    """Big warm brown iris, a dark pupil, two highlights (look B's warmth in look A's flat paint)."""
    x, y = cx + look[0], cy + look[1]
    return (ell(x, y, r, r * 1.04, IRIS) + ell(x, y + r * 0.30, r * 0.72, r * 0.52, IRIS_GLOW, opacity=0.9) +
            ell(x, y + r * 0.04, r * 0.50, r * 0.52, PUPIL) +
            ell(x + r * 0.33, y - r * 0.36, r * 0.34, r * 0.36, WHITE) + ell(x - r * 0.36, y + r * 0.34, r * 0.16, r * 0.16, WHITE))


def flick(cx, cy, rx, ry, side):
    """A single lash flick at the outer corner (side +1 = viewer's right eye)."""
    ox = cx + (rx - 8) * side
    return path(f"M{ox:.1f},{cy - ry * 0.52:.1f} q{22 * side},-20 {40 * side},-14", sw=18)


def eye_white(cx, cy, rx, ry, lid=None, low=None, side=1, look=(0, 0), baked=False, iris_r=IRIS_R):
    """lid: (top_y_offset, slant) -- an upper lid cut; low: lower lid raise (y offset from the bottom)."""
    cid = f"e{cx}{cy}{rx}{ry}{lid}{low}".replace(".", "").replace("(", "").replace(")", "").replace(",", "").replace(" ", "").replace("-", "m")
    clip_d = f"M{cx - rx - 40},{cy - ry - 60} L{cx + rx + 40},{cy - ry - 60} L{cx + rx + 40},{cy + ry + 60} L{cx - rx - 40},{cy + ry + 60} Z"
    top_line = None
    if lid is not None:
        t, sl = lid
        top = cy - ry + t
        clip_d = f"M{cx - rx - 40},{top - sl * side} L{cx + rx + 40},{top + sl * side} L{cx + rx + 40},{cy + ry + 60} L{cx - rx - 40},{cy + ry + 60} Z"
        top_line = (top, sl)
    out = [f'<clipPath id="{cid}"><path d="{clip_d}"/></clipPath>']
    low_clip = ""
    if low is not None:
        lc = cid + "l"
        by = cy + ry - low
        out.append(f'<clipPath id="{lc}"><path d="M{cx - rx - 40},{cy - ry - 80} L{cx + rx + 40},{cy - ry - 80} '
                   f'L{cx + rx + 40},{by} Q{cx},{by - 30} {cx - rx - 40},{by} Z"/></clipPath>')
        low_clip = f' clip-path="url(#{lc})"'
    g = f'<g clip-path="url(#{cid})"><g{low_clip}>' + ell(cx, cy, rx, ry, WHITE)
    if baked:
        g += iris(cx, cy + 8, iris_r, look)
    g += "</g></g>"
    out.append(g)
    if top_line is not None:
        top, sl = top_line
        out.append(path(f"M{cx - rx - 12},{top - sl * side * 1.1:.1f} Q{cx},{top - 14:.1f} {cx + rx + 12},{top + sl * side * 1.1:.1f}", sw=26))
    else:
        out.append(path(f"M{cx - rx - 2},{cy - ry * 0.40:.1f} Q{cx},{cy - ry - 26:.1f} {cx + rx + 2},{cy - ry * 0.40:.1f}", sw=34))
        out.append(path(f"M{cx - rx * 0.86:.1f},{cy + ry * 0.48:.1f} Q{cx},{cy + ry + 14:.1f} {cx + rx * 0.86:.1f},{cy + ry * 0.48:.1f}", stroke=RIM, sw=9))
        out.append(flick(cx, cy, rx, ry, side))
    if low is not None:
        by = cy + ry - low
        out.append(path(f"M{cx - rx * 0.8:.1f},{by + 4} Q{cx},{by - 26} {cx + rx * 0.8:.1f},{by + 4}", sw=14))
    return "".join(out)


def eyes(kind: str, mirror=False) -> str:
    out = []
    for i, cx in enumerate(EYE_X):
        side = 1 if i == 1 else -1
        cy = EYE_Y
        if kind == "open":
            out.append(eye_white(cx, cy, EYE_RX, EYE_RY, side=side))
        elif kind == "wide":
            out.append(eye_white(cx, cy - 10, EYE_RX + 12, EYE_RY + 24, side=side))
        elif kind == "half":        # heavy sleepy / smug lids, pupils baked under them
            out.append(eye_white(cx, cy, EYE_RX, EYE_RY, lid=(EYE_RY * 0.95, 10), side=side, baked=True, look=(0, 10)))
        elif kind == "squint":      # sly squeeze: a lid from above, a cheek from below
            out.append(eye_white(cx, cy, EYE_RX, EYE_RY, lid=(EYE_RY * 0.80, 16), low=EYE_RY * 0.70, side=side,
                                 baked=True, look=(10 * side, 4)))
        elif kind == "worried":     # sad slant, a big wet highlight, looking up
            out.append(eye_white(cx, cy, EYE_RX, EYE_RY, lid=(EYE_RY * 0.30, 38), side=side, baked=True, look=(0, 6)))
            out.append(ell(cx + 22, cy - 6, 20, 22, WHITE))
        elif kind == "closed":      # soft closed lids with a lash flick
            out.append(path(f"M{cx - 78},{cy + 2} Q{cx},{cy + 58} {cx + 78},{cy + 2}", sw=26))
            out.append(path(f"M{cx + 76 * side},{cy + 4} l{22 * side},-20", sw=16))
        elif kind == "happy":       # ^ ^
            out.append(path(f"M{cx - 74},{cy + 34} Q{cx},{cy - 76} {cx + 74},{cy + 34}", sw=30))
        elif kind == "wink":        # her right eye (viewer's left) closed ^, the other open with a baked pupil
            closed_i = 1 if mirror else 0
            if i == closed_i:
                out.append(path(f"M{cx - 74},{cy + 30} Q{cx},{cy - 64} {cx + 74},{cy + 30}", sw=30))
            else:
                out.append(eye_white(cx, cy, EYE_RX, EYE_RY, side=side, baked=True))
        elif kind == "spiral":      # dizzy
            pts = []
            for k in range(70):
                a = k * 0.33 * (1 if i == 0 else -1)
                r = 4 + k * 1.25
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a) * 1.18))
            out.append(ell(cx, cy, EYE_RX, EYE_RY, WHITE, INK, 16))
            out.append(path("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts), sw=15))
    return "".join(out)


def pupils(look=(0, 0), r=IRIS_R) -> str:
    return "".join(iris(cx, EYE_Y + 8, r, look) for cx in EYE_X)


# -------------------------------------------------------------------------------------------------------------
# brows (bold painted brows, 0.026 m thick)
# -------------------------------------------------------------------------------------------------------------
def brows(kind: str, mirror=False) -> str:
    out = []
    y = BROW_Y
    for i, cx in enumerate(EYE_X):
        s = -1 if i == 0 else 1            # outward (toward the temple)
        if kind == "neutral":
            d = f"M{cx - 78},{y + 14} Q{cx},{y - 26} {cx + 78},{y + 14}"
        elif kind == "up":
            d = f"M{cx - 80},{y - 22} Q{cx},{y - 78} {cx + 80},{y - 22}"
        elif kind == "determined":     # down and in, a firm straight line
            d = f"M{cx + 84 * s},{y - 26} Q{cx + 8 * s},{y - 8} {cx - 70 * s},{y + 34}"
        elif kind == "worried":        # up in the middle
            d = f"M{cx + 84 * s},{y + 20} Q{cx},{y - 8} {cx - 70 * s},{y - 40}"
        elif kind == "sly":            # one flat and low, the other arched high
            high_i = 0 if mirror else 1
            if i == high_i:
                d = f"M{cx - 80},{y - 8} Q{cx},{y - 84} {cx + 84},{y - 30}"
            else:
                d = f"M{cx - 80},{y + 26} Q{cx},{y + 8} {cx + 80},{y + 30}"
        else:
            return ""
        out.append(path(d, stroke=BROW, sw=BROW_W))
    return "".join(out)


# -------------------------------------------------------------------------------------------------------------
# mouths (a bold line; open mouths dark with a tongue)
# -------------------------------------------------------------------------------------------------------------
def mouth(kind: str) -> str:
    y = MOUTH_Y
    if kind == "smile":
            return path(f"M{268},{y - 24} Q500,{y + 78} {732},{y - 24}", sw=40)
    if kind == "grin":      # a sneaky open grin, teeth + tongue
        d = f"M290,{y - 40} Q500,{y - 6} 710,{y - 48} Q672,{y + 104} 500,{y + 110} Q328,{y + 104} 290,{y - 40} Z"
        return (path(d, fill=MOUTH, sw=26) + f'<clipPath id="gr"><path d="{d}"/></clipPath><g clip-path="url(#gr)">' +
                ell(500, y + 116, 110, 54, TONGUE) + f'<rect x="270" y="{y - 70}" width="460" height="62" fill="{WHITE}"/></g>' +
                path(d, sw=26))
    if kind == "laugh":     # big open laugh
        d = f"M300,{y - 40} Q500,{y - 30} 700,{y - 40} Q690,{y + 150} 500,{y + 160} Q310,{y + 150} 300,{y - 40} Z"
        return (path(d, fill=MOUTH, sw=26) + f'<clipPath id="la"><path d="{d}"/></clipPath><g clip-path="url(#la)">' +
                ell(500, y + 170, 130, 74, TONGUE) + f'<rect x="280" y="{y - 70}" width="440" height="56" fill="{WHITE}"/></g>' +
                path(d, sw=26))
    if kind == "O":
        return ell(500, y + 22, 68, 88, MOUTH, INK, 24) + ell(500, y + 70, 40, 24, TONGUE)
    if kind == "grimace":   # clenched teeth, corners pulled down
        d = f"M300,{y - 12} Q500,{y - 44} 700,{y - 12} L690,{y + 62} Q500,{y + 40} 310,{y + 62} Z"
        return (path(d, fill=WHITE, sw=24) + path(f"M306,{y + 26} Q500,{y} 694,{y + 26}", sw=12) +
                "".join(path(f"M{x},{y - 30 + abs(x - 500) * 0.07:.0f} L{x},{y + 52 - abs(x - 500) * 0.05:.0f}", sw=11)
                        for x in (380, 440, 500, 560, 620)))
    if kind == "puffed":    # cheeks full of air, lips pressed small
        return (ell(500, y + 10, 64, 34, "#F4B8BE", INK, 20) + path(f"M462,{y + 10} L538,{y + 10}", sw=16))
    if kind == "shh":       # pursed little 'o' pushed to one side
        return ell(462, y + 8, 52, 46, MOUTH, INK, 24) + ell(462, y + 24, 26, 14, TONGUE)
    if kind == "tongue":    # concentration: tongue poking out of the corner
        return (path(f"M320,{y} Q500,{y + 46} 680,{y - 6}", sw=32) + ell(620, y + 40, 44, 40, TONGUE, INK, 16) +
                path(f"M620,{y + 18} L620,{y + 60}", stroke="#D05A6E", sw=8))
    if kind == "wavy":
        return path(f"M300,{y + 14} q33,-38 66,0 t66,0 t66,0 t66,0 t66,0 t66,0", sw=30)
    return ""


# -------------------------------------------------------------------------------------------------------------
# extras: rosy cheeks + the navy teardrop mark (identity), blush, sweat, crying tears
# -------------------------------------------------------------------------------------------------------------
def tear_mark(x):
    return path(f"M{x},{632} q-24,40 0,62 q24,-22 0,-62 Z", fill=TEAR_MARK, stroke=TEAR_MARK, sw=8)


def extra(kind: str) -> str:
    def cheeks(a, mark_x):
        return (ell(190, 648, 84, 50, CHEEK, opacity=a) + ell(810, 648, 84, 50, CHEEK, opacity=a) + tear_mark(mark_x))
    if kind == "cheeks":
        return cheeks(0.85, EYE_X[1] + 58)
    if kind == "cheeks_m":
        return cheeks(0.85, EYE_X[0] - 58)
    if kind in ("blush", "blush_m"):
        mx = EYE_X[1] + 58 if kind == "blush" else EYE_X[0] - 58
        return (ell(190, 646, 96, 58, "#FF7F92", opacity=0.95) + ell(810, 646, 96, 58, "#FF7F92", opacity=0.95) +
                "".join(path(f"M{x},{622} l-22,44", stroke="#D94A62", sw=12) for x in (160, 200, 240, 780, 820, 860)) +
                tear_mark(mx))
    if kind in ("sweat", "sweat_m"):
        x = 905 if kind == "sweat" else 95
        return path(f"M{x},{170} q-46,74 0,104 q46,-30 0,-104 Z", fill=WATER, stroke=INK, sw=14)
    if kind == "tear":      # crying: a drop running from each eye
        return "".join(path(f"M{cx + 50 * s},{560} q-30,56 0,86 q30,-30 0,-86 Z", fill=WATER, stroke=INK, sw=12)
                       for cx, s in ((EYE_X[0], -1), (EYE_X[1], 1)))
    return ""


# -------------------------------------------------------------------------------------------------------------
# the hiding-spot eye card (r3d-sets): glowing eyes on a dark gap, a standalone quad
# -------------------------------------------------------------------------------------------------------------
def dark_eyes(kind: str) -> str:
    out = []
    for cx in (290, 710):
        if kind == "open":
            out.append(ell(cx, 500, 170, 230, WHITE, "#12101A", 26))
        elif kind == "blink":
            out.append(path(f"M{cx - 150},{520} Q{cx},{600} {cx + 150},{520}", stroke="#F4EEF8", sw=46))
    return "".join(out)


def dark_pupils() -> str:
    out = []
    for cx in (290, 710):
        out.append(ell(cx, 530, 104, 110, IRIS) + ell(cx + 36, 480, 36, 40, WHITE) + ell(cx - 38, 570, 16, 16, WHITE))
    return "".join(out)


# -------------------------------------------------------------------------------------------------------------
CELLS = [
    # (layer, name, svg-or-callable) -- order = cell index
    ("eyes", "open", lambda: eyes("open")), ("eyes", "wide", lambda: eyes("wide")),
    ("eyes", "half", lambda: eyes("half")), ("eyes", "squint", lambda: eyes("squint")),
    ("eyes", "worried", lambda: eyes("worried")), ("eyes", "closed", lambda: eyes("closed")),
    ("eyes", "happy", lambda: eyes("happy")), ("eyes", "wink", lambda: eyes("wink")),
    ("eyes", "wink_m", lambda: eyes("wink", mirror=True)), ("eyes", "spiral", lambda: eyes("spiral")),
    ("pupils", "centre", lambda: pupils()),
    ("pupils", "small", lambda: pupils(r=IRIS_R * 0.72)),
    ("brows", "neutral", lambda: brows("neutral")), ("brows", "up", lambda: brows("up")),
    ("brows", "determined", lambda: brows("determined")), ("brows", "worried", lambda: brows("worried")),
    ("brows", "sly", lambda: brows("sly")), ("brows", "sly_m", lambda: brows("sly", mirror=True)),
    ("mouth", "smile", lambda: mouth("smile")), ("mouth", "grin", lambda: mouth("grin")),
    ("mouth", "laugh", lambda: mouth("laugh")), ("mouth", "O", lambda: mouth("O")),
    ("mouth", "grimace", lambda: mouth("grimace")), ("mouth", "puffed", lambda: mouth("puffed")),
    ("mouth", "shh", lambda: mouth("shh")), ("mouth", "tongue", lambda: mouth("tongue")),
    ("mouth", "wavy", lambda: mouth("wavy")),
    ("extra_a", "cheeks", lambda: extra("cheeks")), ("extra_a", "cheeks_m", lambda: extra("cheeks_m")),
    ("extra_a", "blush", lambda: extra("blush")), ("extra_a", "blush_m", lambda: extra("blush_m")),
    ("extra_b", "sweat", lambda: extra("sweat")), ("extra_b", "sweat_m", lambda: extra("sweat_m")),
    ("extra_b", "tear", lambda: extra("tear")),
    ("card", "eyes_dark_open", lambda: dark_eyes("open")), ("card", "eyes_dark_blink", lambda: dark_eyes("blink")),
    ("card", "pupils_dark", lambda: dark_pupils()),
]
# face.mirror_cells: at facing -1 (a yaw, never a negative scale) the rig swaps each asymmetric mark for its mirror
MIRROR = {"sly": "sly_m", "wink": "wink_m", "cheeks": "cheeks_m", "blush": "blush_m", "sweat": "sweat_m"}


def build(out_dir: str, preview: bool = False, json_dir: str = "") -> dict:
    os.makedirs(out_dir, exist_ok=True)
    json_dir = json_dir or out_dir
    os.makedirs(json_dir, exist_ok=True)
    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    cells = {ln: {} for ln in LAYERS}
    cells["card"] = {}
    for idx, (layer, name, fn) in enumerate(CELLS):
        body = fn()
        im = raster_square(body) if layer == "card" else raster(body, RECTS[layer])
        col, row = idx % GRID, idx // GRID
        atlas.alpha_composite(im, (col * CELL, row * CELL))
        cells[layer][name] = idx
    path_png = os.path.join(out_dir, "face_hush.png")
    atlas.save(path_png)
    mirror = dict(MIRROR)
    info = {"atlas": "face_hush.png", "atlas_px": ATLAS, "grid": [GRID, GRID], "cell_px": CELL,
            "layers": LAYERS, "draw_order": DRAW_ORDER, "layer_rects": {k: list(v) for k, v in RECTS.items()},
            "cells": cells, "mirror_cells": mirror,
            "marks": {"eye_x": list(EYE_X), "eye_y": EYE_Y, "eye_rx": EYE_RX, "eye_ry": EYE_RY, "iris_r": IRIS_R,
                      "mouth_x": [268, 732], "mouth_y": MOUTH_Y, "brow_y": BROW_Y, "brow_w": BROW_W,
                      "units": "face units: 1000 = the face square (FACE_W m), y down"}}
    with open(os.path.join(json_dir, "face_hush.json"), "w") as f:
        json.dump(info, f, indent=1)
        f.write("\n")
    if preview:
        _preview(atlas, cells, os.path.join(json_dir, "face_hush_preview.png"))
    return info


def _preview(atlas, cells, path_out):
    """The atlas on a grey checker with cell names (a look-at aid; not shipped)."""
    from PIL import ImageDraw
    bg = Image.new("RGBA", atlas.size, (150, 140, 160, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, ATLAS, 16):
        for x in range(0, ATLAS, 16):
            if (x // 16 + y // 16) % 2:
                d.rectangle([x, y, x + 15, y + 15], fill=(170, 160, 180, 255))
    bg.alpha_composite(atlas)
    d = ImageDraw.Draw(bg)
    for layer, names in cells.items():
        for name, idx in names.items():
            col, row = idx % GRID, idx // GRID
            d.rectangle([col * CELL, row * CELL, col * CELL + CELL - 1, row * CELL + CELL - 1], outline=(40, 30, 60, 255))
            d.text((col * CELL + 3, row * CELL + 2), f"{layer[:5]}/{name}", fill=(0, 0, 0, 255))
    bg.save(path_out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "..", "game", "art3d", "chars", "hush")
    jd = sys.argv[sys.argv.index("--json-dir") + 1] if "--json-dir" in sys.argv else ""
    info = build(out, preview="--preview" in sys.argv, json_dir=jd)
    print("FACE_ATLAS", sum(len(v) for v in info["cells"].values()), "cells ->", out)
