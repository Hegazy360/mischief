"""Horace Bellows' face-decal atlas (look A's painted style, the 2D face vocabulary): SVG -> rsvg-convert -> PIL.

    python3 tools/art3d/bellows/face_atlas.py --out game/art3d/chars/bellows [--faces game/data/rigs3d/bellows/faces.json]
        [--preview <png>]

Face space: a 1000 x 1000 SVG square = the planar FaceUV square on the head front (0.56 m, parts.FACE_W; u right as
seen from the front, v up; SVG y down). The atlas is 1024^2, an 8 x 8 grid of 128 px cells; every LAYER has one rect of
face space (`layer_rects`, uv [u0, v0, u1, v1], v up) and each of its cells is that rect rasterised into one 128 px cell
(non-uniform: the shader maps the cell back onto the rect). Cells are named with the 2D slot variant names per layer.
Layers (composited in this order): extra_a, extra_b, brows, eyes, pupils, lids, mouth. Lids share the eyes' rect.

Beetroot-proof: every mark is ink `#2A2036` or an opaque colour; the heavy lids are a translucent dark wash + an ink lash
line (so they darken whatever the temper tint makes of the skin underneath, never a peach patch on a beetroot face).
"""
import os, sys, json, subprocess, io, math
from PIL import Image, ImageDraw

ATLAS = 1024
GRID = 8
CELL = ATLAS // GRID
INK = "#2A2036"
SILVER = "#E2E5EE"
SILVER_DK = "#A9AEC0"
M_DARK = "#5A1A2C"
TONGUE = "#E0707C"
WHITE = "#FFFFFF"
PUPIL = "#241A2E"
LID_WASH = "#6E2E3A"      # drawn at ~0.30 alpha: darkens any skin tint

EYE_Y = 423
EYE_X = (348, 652)
BROW_Y = 318
MOUTH_Y = 748

# layer rects in face space (SVG x0, y0, x1, y1; y down)
RECTS = {
    "brows": (110, 170, 890, 430),
    "eyes": (150, 280, 850, 580),
    "pupils": (150, 280, 850, 580),
    "lids": (150, 280, 850, 580),
    "mouth": (190, 610, 810, 990),
    "extra_a": (0, 60, 1000, 980),
    "extra_b": (0, 0, 1000, 1000),
}
ORDER = ["extra_a", "extra_b", "brows", "eyes", "pupils", "lids", "mouth"]


def uv_rect(r):
    x0, y0, x1, y1 = r
    return [round(x0 / 1000, 4), round(1 - y1 / 1000, 4), round(x1 / 1000, 4), round(1 - y0 / 1000, 4)]


# ---- SVG helpers ---------------------------------------------------------------------------------------------------
def ell(cx, cy, rx, ry, fill, stroke=None, sw=0, rot=0, extra=""):
    s = f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{sw}"'
    if rot:
        s += f' transform="rotate({rot} {cx} {cy})"'
    return s + f" {extra}/>"


def path(d, fill="none", stroke=INK, sw=16, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'


def mirror_svg(body):
    return f'<g transform="translate(1000 0) scale(-1 1)">{body}</g>'


# ---- eyes (the eyeballs; pupils and lids are their own layers) ---------------------------------------------------------
ERX, ERY = 86, 100        # a bigger eye than look A's (72 x 76 of a 0.52 m face): >= 10 px tall at 1200 x 540
LID_CUT = {"half": (0.42, -8), "angry": (0.36, 30)}     # lid line: fraction of the eye height from the top, slant (+ = down to the nose)


def lid_line(kind, i):
    """(y at the inner corner side, y at the outer side) of the lid line of eye i (0 = viewer's left)."""
    frac, sl = LID_CUT[kind]
    inner = 1 if i == 0 else -1
    top = EYE_Y - ERY + 2 * ERY * frac
    return top, sl * inner


def lid_clip(kind, i, cid):
    """clipPath = the eyeball below the lid line (the skin shows above it, so the temper tint reads through)."""
    cx = EYE_X[i]
    top, sl = lid_line(kind, i)
    return (f'<clipPath id="{cid}"><path d="M{cx-120},{top-sl} L{cx+120},{top+sl} L{cx+120},{EYE_Y+200} L{cx-120},{EYE_Y+200} Z"/>'
            f'</clipPath>')


def eyes(kind):
    out = []
    for i, cx in enumerate(EYE_X):
        inner = 1 if i == 0 else -1          # toward the nose
        if kind in ("open", "teary"):
            out.append(ell(cx, EYE_Y, ERX, ERY, WHITE, INK, 13))
            if kind == "teary":
                out.append(f'<clipPath id="tc{i}"><ellipse cx="{cx}" cy="{EYE_Y}" rx="{ERX}" ry="{ERY}"/></clipPath>')
                out.append(f'<g clip-path="url(#tc{i})">' + ell(cx, EYE_Y + ERY * 0.75, ERX * 1.1, ERY * 0.42, "#8FD3F4") + "</g>")
                out.append(ell(cx - 12 * inner, EYE_Y + ERY + 22, 16, 22, "#8FD3F4", INK, 6))
        elif kind in ("half", "angry"):      # heavy pompous / furious lids: the eyeball cut by the lid line + a lash line
            cid = f"ec{kind}{i}"
            out.append(lid_clip(kind, i, cid))
            out.append(f'<g clip-path="url(#{cid})">' + ell(cx, EYE_Y, ERX, ERY, WHITE, INK, 13) + "</g>")
            top, sl = lid_line(kind, i)
            out.append(path(f"M{cx-ERX-12},{top-sl*1.15} L{cx+ERX+12},{top+sl*1.15}", sw=19))
        elif kind == "wide":
            out.append(ell(cx, EYE_Y - 10, ERX * 1.12, ERY * 1.16, WHITE, INK, 14))
        elif kind == "balloon":            # magnified x4 behind the lens: huge white discs, big pupils drawn in
            out.append(ell(cx, EYE_Y - 4, 150, 150, WHITE, INK, 15))
            out.append(ell(cx + 6 * inner, EYE_Y + 6, 62, 64, PUPIL))
            out.append(ell(cx + 30 * inner + 18, EYE_Y - 26, 20, 20, WHITE))
        elif kind == "pinpoint":           # terrified: wide whites, pinprick pupils drawn in
            out.append(ell(cx, EYE_Y - 8, ERX * 1.08, ERY * 1.12, WHITE, INK, 14))
            out.append(ell(cx, EYE_Y - 4, 11, 12, PUPIL))
        elif kind == "closed":             # smug, content closed lids (down-curved)
            out.append(path(f"M{cx-70},{EYE_Y+4} Q{cx},{EYE_Y+52} {cx+70},{EYE_Y+4}", sw=20))
            ox = cx - 70 * inner
            out.append(path(f"M{ox},{EYE_Y+4} l{-18*inner},-14", sw=12))
        elif kind == "squint":             # suspicious slits under the brows
            out.append(path(f"M{cx-72},{EYE_Y+6} Q{cx},{EYE_Y-22} {cx+72},{EYE_Y+6}", sw=22))
            out.append(path(f"M{cx-54},{EYE_Y+22} Q{cx},{EYE_Y+34} {cx+54},{EYE_Y+22}", sw=12))
            out.append(ell(cx + 8 * inner, EYE_Y + 12, 16, 10, PUPIL))
        elif kind == "spiral":
            pts = []
            for k in range(56):
                a = k * 0.42
                r = 4 + k * 1.35
                pts.append((cx + r * math.cos(a) * inner, EYE_Y + r * math.sin(a) * 1.05))
            out.append(ell(cx, EYE_Y, ERX * 0.98, ERY * 0.98, WHITE, INK, 11))
            out.append(path("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts), sw=12))
    return "".join(out)


def pupils(kind):
    """default: full pupils; half / angry: the same pupils clipped under that lid line (for the lidded eyes); small."""
    out = []
    for i, cx in enumerate(EYE_X):
        if kind in ("default", "half", "angry"):
            g = ell(cx, EYE_Y + 14, 40, 46, PUPIL) + ell(cx + 15, EYE_Y - 4, 13, 13, WHITE)
            if kind != "default":
                cid = f"pc{kind}{i}"
                out.append(lid_clip(kind, i, cid))
                g = f'<g clip-path="url(#{cid})">{g}</g>'
            out.append(g)
        elif kind == "small":
            out.append(ell(cx, EYE_Y + 4, 26, 30, PUPIL))
            out.append(ell(cx + 9, EYE_Y - 6, 9, 9, WHITE))
    return "".join(out)


def lids(kind):
    """The heavy fleshy upper lid: a translucent dark wash above the lash line + a crease (tint-safe: no skin colour)."""
    out = []
    for i, cx in enumerate(EYE_X):
        if kind not in LID_CUT:
            return ""
        top, sl = lid_line(kind, i)
        cid = f"lw{kind}{i}"
        out.append(f'<clipPath id="{cid}"><ellipse cx="{cx}" cy="{EYE_Y}" rx="{ERX+14}" ry="{ERY+10}"/></clipPath>')
        out.append(f'<g clip-path="url(#{cid})"><path d="M{cx-120},{EYE_Y-150} L{cx+120},{EYE_Y-150} L{cx+120},{top+sl} '
                   f'L{cx-120},{top-sl} Z" fill="{LID_WASH}" fill-opacity="0.26"/></g>')
        cy = EYE_Y - ERY - 4
        out.append(path(f"M{cx-ERX+6},{cy+18} Q{cx},{cy-8} {cx+ERX-6},{cy+18}", stroke=INK, sw=8, extra='stroke-opacity="0.55"'))
    return "".join(out)


# ---- brows: bushy silver, ink-edged, with tufts --------------------------------------------------------------------
def _brow(cx, s, kind, y):
    if kind == "neutral":
        pts = [(cx - 84, y + 14), (cx, y - 22), (cx + 84, y + 14)]
    elif kind == "up":            # arched high and haughty
        pts = [(cx - 86, y - 6), (cx + 6 * s, y - 72), (cx + 86, y - 10)]
    elif kind == "angry":         # down toward the nose
        pts = [(cx + 88 * s, y - 34), (cx + 10 * s, y + 4), (cx - 70 * s, y + 52)]
    elif kind == "worried":       # up toward the nose
        pts = [(cx + 88 * s, y + 26), (cx, y - 10), (cx - 72 * s, y - 52)]
    elif kind == "low":           # the other brow of one_up: pulled down, flat
        pts = [(cx - 84, y + 30), (cx, y + 6), (cx + 84, y + 26)]
    elif kind == "sly_down":
        pts = [(cx + 86 * s, y - 6), (cx, y + 18), (cx - 76 * s, y + 38)]
    else:
        return ""
    (x0, y0), (x1, y1), (x2, y2) = pts
    d = f"M{x0},{y0} Q{x1},{y1} {x2},{y2}"
    out = [path(d, stroke=INK, sw=66), path(d, stroke=SILVER, sw=46)]
    for t in (0.18, 0.5, 0.82):
        bx = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
        by = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
        out.append(path(f"M{bx-8},{by+2} l{12*s},-20", stroke=SILVER_DK, sw=7))
    return "".join(out)


def brows(kind):
    out = []
    for i, cx in enumerate(EYE_X):
        s = -1 if i == 0 else 1       # outward (viewer's left eye = his right)
        k = kind
        if kind == "one_up":          # his LEFT brow (viewer's right) cocked up, the other pulled down
            k = "up" if i == 1 else "low"
        elif kind == "sly":           # viewer's left brow down-slanted, right slightly up
            k = "sly_down" if i == 0 else "up"
        out.append(_brow(cx, s, k, BROW_Y))
    return "".join(out)


# ---- mouths (x1.5 of look A so they read under the big nose) ---------------------------------------------------------
def _mouth(kind):
    y = MOUTH_Y
    if kind == "closed":      # the pompous pursed line
        return path(f"M438,{y+10} Q500,{y-16} 562,{y+10}", sw=18) + ell(500, y + 18, 16, 8, "#C4726E")
    if kind == "smug":        # a lopsided smirk up to his left (viewer's right)
        return path(f"M430,{y+8} Q500,{y+30} 580,{y-22}", sw=18) + path(f"M580,{y-22} l10,-4", sw=14)
    if kind == "smile":
        return path(f"M420,{y-6} Q500,{y+56} 580,{y-6}", fill=M_DARK, sw=16) + ell(500, y + 28, 30, 10, TONGUE)
    if kind == "open":        # talking / lecturing
        d = f"M440,{y-18} Q500,{y-30} 560,{y-18} Q570,{y+50} 500,{y+64} Q430,{y+50} 440,{y-18} Z"
        return path(d, fill=M_DARK, sw=15) + ell(500, y + 44, 34, 14, TONGUE)
    if kind in ("O_small", "O_mid", "O_big"):   # the singing O in three sizes
        rx, ry = {"O_small": (30, 38), "O_mid": (46, 60), "O_big": (66, 86)}[kind]
        return ell(500, y + ry * 0.3, rx, ry, M_DARK, INK, 15) + ell(500, y + ry * 0.3 + ry * 0.55, rx * 0.6, ry * 0.26, TONGUE)
    if kind == "grit":        # gritted teeth
        d = f"M410,{y-26} L590,{y-26} Q604,{y+30} 580,{y+40} L420,{y+40} Q396,{y+30} 410,{y-26} Z"
        teeth = "".join(path(f"M{x},{y-24} L{x},{y+38}", sw=7) for x in (455, 500, 545))
        return path(d, fill=WHITE, sw=15) + teeth + path(f"M414,{y+8} L586,{y+8}", sw=7)
    if kind == "scream":      # PIPE DOWN! / the CHOO: a big bellow with top teeth and tongue
        d = f"M404,{y-40} Q500,{y-58} 596,{y-40} Q628,{y+80} 500,{y+118} Q372,{y+80} 404,{y-40} Z"
        return (path(d, fill=M_DARK, sw=15) + f'<clipPath id="sc"><path d="{d}"/></clipPath>' +
                f'<g clip-path="url(#sc)"><rect x="390" y="{y-60}" width="220" height="44" fill="{WHITE}"/>' +
                ell(500, y + 104, 64, 32, TONGUE) + "</g>" + path(d, sw=15))
    if kind == "wavy":
        return path(f"M420,{y+8} q20,-22 40,0 t40,0 t40,0 t40,0", sw=16)
    return ""


def mouth(kind):
    """Every mouth drawn 1.7x about its centre (they sit under the big 3D nose and must read at 1x: an open mouth
    >= 14 px wide on the 48 px face card, GDD 9.2's 40 px of a 140 px 2D head)."""
    body = mirror_svg(_mouth("smug")) if kind == "smug_m" else _mouth(kind)
    return f'<g transform="translate(500 {MOUTH_Y}) scale(1.7) translate(-500 -{MOUTH_Y})">{body}</g>' if body else ""


# ---- extras ----------------------------------------------------------------------------------------------------------
def extra(kind):
    if kind == "blush":
        return ell(236, 610, 70, 40, "#FF8A96", extra='fill-opacity="0.75"') + ell(764, 610, 70, 40, "#FF8A96", extra='fill-opacity="0.75"')
    if kind == "vein":        # the anger vein on his forehead, viewer's right
        return path("M760,190 l30,-30 m-6,36 l36,-6 m-62,-10 l-6,-38 m-8,50 l-38,6", stroke="#D8344A", sw=18)
    if kind == "vein_m":
        return mirror_svg(extra("vein"))
    if kind == "singe":       # soot smudges
        return (ell(300, 180, 90, 40, "#3A2A30", extra='fill-opacity="0.55"') + ell(700, 700, 70, 34, "#3A2A30", extra='fill-opacity="0.45"')
                + ell(260, 720, 50, 26, "#3A2A30", extra='fill-opacity="0.45"'))
    if kind == "pinch":       # SQUEAKY: the pinched nose wrinkle lines
        return path("M440,520 q-20,20 -8,44 M560,520 q20,20 8,44", sw=10)
    if kind == "sweat":       # one drop at his left temple (viewer's right)
        return path("M862,300 q-34,52 0,76 q34,-24 0,-76 Z", fill="#8FD3F4", sw=8)
    if kind == "sweat_m":
        return mirror_svg(extra("sweat"))
    if kind == "steam_l":     # steam puffs at the temple edge (the view adds the real steam FX)
        return "".join(ell(x, y, r, r, WHITE, INK, 7) for x, y, r in ((120, 330, 34), (80, 270, 26), (58, 214, 18)))
    if kind == "steam_r":
        return mirror_svg(extra("steam_l"))
    if kind == "steam":
        return extra("steam_l") + extra("steam_r")
    if kind == "hiccup":
        return ell(620, 860, 26, 26, "#DCEBF2", INK, 7) + ell(668, 812, 16, 16, "#DCEBF2", INK, 6)
    if kind == "tears":
        return ell(262, 560, 18, 26, "#8FD3F4", INK, 7) + ell(738, 560, 18, 26, "#8FD3F4", INK, 7)
    return ""


# ---- the cell table (index = row-major 8 x 8) ---------------------------------------------------------------------------
CELLS = [
    ("eyes", "open", lambda: eyes("open")), ("eyes", "half", lambda: eyes("half")), ("eyes", "angry", lambda: eyes("angry")),
    ("eyes", "balloon", lambda: eyes("balloon")), ("eyes", "closed", lambda: eyes("closed")),
    ("eyes", "pinpoint", lambda: eyes("pinpoint")), ("eyes", "spiral", lambda: eyes("spiral")),
    ("eyes", "squint", lambda: eyes("squint")), ("eyes", "teary", lambda: eyes("teary")), ("eyes", "wide", lambda: eyes("wide")),
    ("pupils", "default", lambda: pupils("default")), ("pupils", "half", lambda: pupils("half")),
    ("pupils", "angry", lambda: pupils("angry")), ("pupils", "small", lambda: pupils("small")),
    ("lids", "half", lambda: lids("half")), ("lids", "angry", lambda: lids("angry")),
    ("brows", "neutral", lambda: brows("neutral")), ("brows", "up", lambda: brows("up")), ("brows", "angry", lambda: brows("angry")),
    ("brows", "worried", lambda: brows("worried")), ("brows", "one_up", lambda: brows("one_up")),
    ("brows", "one_up_m", lambda: mirror_svg(brows("one_up"))), ("brows", "sly", lambda: brows("sly")),
    ("brows", "sly_m", lambda: mirror_svg(brows("sly"))),
    ("mouth", "closed", lambda: mouth("closed")), ("mouth", "smug", lambda: mouth("smug")), ("mouth", "smug_m", lambda: mouth("smug_m")),
    ("mouth", "smile", lambda: mouth("smile")), ("mouth", "open", lambda: mouth("open")), ("mouth", "O_small", lambda: mouth("O_small")),
    ("mouth", "O_mid", lambda: mouth("O_mid")), ("mouth", "O_big", lambda: mouth("O_big")), ("mouth", "grit", lambda: mouth("grit")),
    ("mouth", "scream", lambda: mouth("scream")), ("mouth", "wavy", lambda: mouth("wavy")),
    None,
    ("extra_a", "blush", lambda: extra("blush")), ("extra_a", "vein", lambda: extra("vein")), ("extra_a", "vein_m", lambda: extra("vein_m")),
    ("extra_a", "singe", lambda: extra("singe")), ("extra_a", "pinch", lambda: extra("pinch")),
    ("extra_b", "sweat", lambda: extra("sweat")), ("extra_b", "sweat_m", lambda: extra("sweat_m")),
    ("extra_b", "steam_l", lambda: extra("steam_l")), ("extra_b", "steam_r", lambda: extra("steam_r")),
    ("extra_b", "steam", lambda: extra("steam")), ("extra_b", "hiccup", lambda: extra("hiccup")), ("extra_b", "tears", lambda: extra("tears")),
]
MIRROR = {"brows": {"one_up": "one_up_m", "one_up_m": "one_up", "sly": "sly_m", "sly_m": "sly"},
          "mouth": {"smug": "smug_m", "smug_m": "smug"},
          "extra_a": {"vein": "vein_m", "vein_m": "vein"},
          "extra_b": {"sweat": "sweat_m", "sweat_m": "sweat", "steam_l": "steam_r", "steam_r": "steam_l"}}
BLINKABLE = ["open", "half", "angry", "wide", "teary"]
NO_PUPILS = ["closed", "pinpoint", "spiral", "balloon", "squint"]     # eye cells that draw their own (or no) pupils


def raster(body, rect):
    x0, y0, x1, y1 = rect
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{CELL*2}" height="{CELL*2}" viewBox="{x0} {y0} {x1-x0} {y1-y0}" '
           f'preserveAspectRatio="none">{body}</svg>')
    png = subprocess.run(["rsvg-convert", "-f", "png"], input=svg.encode(), capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return im.resize((CELL, CELL), Image.LANCZOS)


def build(out_dir):
    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    cells = {l: {} for l in ORDER}
    for idx, c in enumerate(CELLS):
        if c is None:
            continue
        layer, name, fn = c
        im = raster(fn(), RECTS[layer])
        atlas.alpha_composite(im, ((idx % GRID) * CELL, (idx // GRID) * CELL))
        cells[layer][name] = idx
    # alpha bleed: transparent pixels take the ink colour (no light fringes under filtering)
    px = atlas.load()
    for yy in range(ATLAS):
        for xx in range(ATLAS):
            r, g, b, a = px[xx, yy]
            if a == 0:
                px[xx, yy] = (0x2A, 0x20, 0x36, 0)
    atlas.save(os.path.join(out_dir, "face_bellows.png"))
    layout = {"atlas_px": ATLAS, "grid": [GRID, GRID], "layers": ORDER, "order": ORDER,
              "layer_rects": {l: uv_rect(RECTS[l]) for l in ORDER}, "cells": cells, "mirror_cells": MIRROR,
              "blinkable": BLINKABLE, "no_pupils": NO_PUPILS}
    with open(os.path.join(out_dir, "face_bellows.json"), "w") as f:
        json.dump(layout, f, indent=1)
    return atlas, layout


def composite(atlas, layout, preset, skin="#F0C2A0", size=256, tint=None):
    """A preset over a skin disc (quick check without the engine)."""
    face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(face)
    col = skin if tint is None else tint
    d.ellipse((size * 0.06, size * 0.02, size * 0.94, size * 0.98), fill=col)
    for layer in ORDER:
        name = preset.get(layer)
        if not name:
            continue
        idx = layout["cells"][layer][name]
        cell = atlas.crop(((idx % GRID) * CELL, (idx // GRID) * CELL, (idx % GRID + 1) * CELL, (idx // GRID + 1) * CELL))
        u0, v0, u1, v1 = layout["layer_rects"][layer]
        box = (int(u0 * size), int((1 - v1) * size), int(u1 * size), int((1 - v0) * size))
        face.alpha_composite(cell.resize((box[2] - box[0], box[3] - box[1]), Image.LANCZOS), (box[0], box[1]))
    return face


if __name__ == "__main__":
    a = sys.argv[1:]
    out = a[a.index("--out") + 1] if "--out" in a else "."
    os.makedirs(out, exist_ok=True)
    atlas, layout = build(out)
    if "--preview" in a:
        faces = json.load(open(a[a.index("--faces") + 1]))["presets"]
        names = list(faces.keys())
        cols = 9
        S = 180
        P = Image.new("RGBA", (cols * S, ((len(names) + cols - 1) // cols) * (S + 18)), (40, 34, 52, 255))
        dr = ImageDraw.Draw(P)
        for k, n in enumerate(names):
            x, y = (k % cols) * S, (k // cols) * (S + 18)
            P.alpha_composite(composite(atlas, layout, faces[n], size=S), (x, y))
            dr.text((x + 4, y + S + 2), n, fill=(255, 240, 200))
        P.save(a[a.index("--preview") + 1])
    print("FACE_ATLAS", out, sum(len(v) for v in layout["cells"].values()), "cells")
