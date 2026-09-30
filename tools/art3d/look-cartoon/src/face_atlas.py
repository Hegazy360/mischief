"""Face decal atlas (texture swaps): 8 mouth cells + 8 eye (iris) cells, 128 px each, one 1024x256 strip
per character. Drawn with PIL at 8x and downsampled (smooth, readable cartoon shapes).

python3 face_atlas.py <out_dir>   -> atlas_hush.png, atlas_bellows.png, atlas_preview.png

Mouth cell = the mouth window (mouth_w metres square, centred on the mouth); eye cell = the eyeball's
front disc. Frame indices (shared vocabulary with faces.json):
  mouth: 0 neutral, 1 sneaky grin / pompous, 2 shock O, 3 furious, 4 sneeze build "ah", 5 dazed,
         6 snicker (Hush) / sing (Bellows), 7 CHOO
  eye:   0 normal, 1 tiny pupil (shock / fury), 2 spiral (dazed), 3 sparkle (glee)
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFilter

SS = 8
C = 128 * SS


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def arc_pts(cx, cy, w, sag, n=40, tilt=0.0, x0=-1, x1=1):
    """Parabolic smile: y = cy + sag * (1 - t^2) ... returns points (t in [x0, x1])."""
    out = []
    for i in range(n + 1):
        t = x0 + (x1 - x0) * i / n
        out.append((cx + t * w / 2, cy - sag * (1 - t * t) * -1 + tilt * t))
    return out


def thick_line(d, pts, width, fill):
    d.line(pts, fill=fill, width=int(width), joint="curve")
    r = width / 2
    for p in (pts[0], pts[-1]):
        d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=fill)


def poly_smile(cx, cy, w, top_sag, bot_sag, n=40, tilt=0.0):
    """Closed crescent: upper edge sag top_sag, lower edge sag bot_sag (px, + = down at the middle)."""
    up, lo = [], []
    for i in range(n + 1):
        t = -1 + 2 * i / n
        up.append((cx + t * w / 2, cy + top_sag * (1 - t * t) + tilt * t))
        lo.append((cx + t * w / 2, cy + bot_sag * (1 - t * t) + tilt * t))
    return up + lo[::-1]


def cell():
    return Image.new("RGBA", (C, C), (0, 0, 0, 0))


def s(v):
    return v * SS


# ------------------------------------------------------------------------------------------------
def mouths(P):
    lip, dark, tongue, teeth, ink = P["lip"], P["inside"], P["tongue"], P["teeth"], P["ink"]
    W = P["w"]   # neutral mouth width in px (of 128)
    out = []
    cx, cy = s(64), s(64)

    # 0 neutral
    im = cell(); d = ImageDraw.Draw(im)
    if P["who"] == "hush":
        thick_line(d, [(x, y) for x, y in poly_smile(cx, cy - s(4), s(W), s(10), s(10))[:41]], s(6.5), lip)
    else:   # grumpy-pompous flat line, corners slightly down, a lower-lip shadow
        pts = [(cx + t * s(W) / 2, cy + s(2) - s(5) * (t * t)) for t in [(-1 + 2 * i / 40) for i in range(41)]]
        thick_line(d, pts, s(5.5), ink)
        d.chord((cx - s(W * 0.28), cy + s(1), cx + s(W * 0.28), cy + s(15)), 0, 180, fill=lip)
    out.append(im)

    # 1 sneaky grin (Hush) / pompous pout (Bellows)
    im = cell(); d = ImageDraw.Draw(im)
    if P["who"] == "hush":
        poly = poly_smile(cx + s(3), cy - s(6), s(W * 1.45), s(6), s(20), tilt=-s(7))
        d.polygon(poly, fill=lip)
        inner = poly_smile(cx + s(3), cy - s(4), s(W * 1.2), s(7), s(15), tilt=-s(6))
        d.polygon(inner, fill=dark)
        tp = poly_smile(cx + s(3), cy - s(4), s(W * 1.15), s(7), s(11), tilt=-s(6))
        d.polygon(tp, fill=teeth)
        # dimple at the high corner
        hx, hy = cx + s(3) + s(W * 1.45) / 2, cy - s(6) - s(7)
        thick_line(d, [(hx + s(1), hy - s(5)), (hx + s(4), hy + s(1)), (hx + s(2), hy + s(5))], s(3), ink)
    else:
        pts = [(cx + s(4) + t * s(W * 0.7) / 2, cy - s(3) * t - s(3) * (1 - t * t)) for t in [(-1 + 2 * i / 30) for i in range(31)]]
        thick_line(d, pts, s(5.5), ink)
        d.ellipse((cx - s(W * 0.2), cy + s(0), cx + s(W * 0.3), cy + s(13)), fill=lip)
        thick_line(d, [(cx + s(4) + s(W * 0.36), cy - s(8)), (cx + s(4) + s(W * 0.44), cy - s(12))], s(4), ink)
    out.append(im)

    # 2 shock O
    im = cell(); d = ImageDraw.Draw(im)
    rx, ry = s(W * 0.3), s(W * 0.42)
    d.ellipse((cx - rx - s(4), cy - ry - s(4), cx + rx + s(4), cy + ry + s(4)), fill=lip)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=dark)
    d.chord((cx - rx * 0.8, cy + ry * 0.2, cx + rx * 0.8, cy + ry * 1.0), 0, 180, fill=tongue)
    d.chord((cx - rx * 0.75, cy - ry * 1.0, cx + rx * 0.75, cy - ry * 0.45), 180, 360, fill=teeth)
    out.append(im)

    # 3 furious: gritted teeth (Hush) / shouting PIPE DOWN (Bellows)
    im = cell(); d = ImageDraw.Draw(im)
    if P["who"] == "hush":
        bw, bh = s(W * 1.25), s(W * 0.5)
        d.rounded_rectangle((cx - bw / 2 - s(3), cy - bh / 2 - s(3), cx + bw / 2 + s(3), cy + bh / 2 + s(3)), radius=s(10), fill=lip)
        d.rounded_rectangle((cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2), radius=s(8), fill=teeth)
        d.line((cx - bw / 2, cy, cx + bw / 2, cy), fill=ink, width=int(s(2.5)))
        for k in (-2, -1, 0, 1, 2):
            x = cx + k * bw / 5.5
            d.line((x, cy - bh / 2 + s(2), x, cy + bh / 2 - s(2)), fill=ink, width=int(s(2)))
    else:
        poly = [(cx - s(W * 0.7), cy - s(10)), (cx + s(W * 0.7), cy - s(10)), (cx + s(W * 0.5), cy + s(22)), (cx - s(W * 0.5), cy + s(22))]
        d.polygon([(x, y - s(3)) for x, y in poly], fill=lip)
        d.polygon(poly, fill=dark)
        d.rectangle((cx - s(W * 0.62), cy - s(10), cx + s(W * 0.62), cy - s(3)), fill=teeth)
        d.chord((cx - s(W * 0.35), cy + s(8), cx + s(W * 0.35), cy + s(30)), 180, 360, fill=tongue)
    out.append(im)

    # 4 sneeze build "ah..": open, upper lip hitched up
    im = cell(); d = ImageDraw.Draw(im)
    poly = [(cx - s(W * 0.4), cy + s(2)), (cx - s(W * 0.2), cy - s(9)), (cx, cy - s(6)), (cx + s(W * 0.22), cy - s(10)),
            (cx + s(W * 0.42), cy + s(3)), (cx + s(W * 0.2), cy + s(16)), (cx - s(W * 0.2), cy + s(15))]
    d.polygon([(x * 1.0 + 0, y) for x, y in poly], fill=lip)
    inner = [((x - cx) * 0.8 + cx, (y - cy) * 0.75 + cy + s(1)) for x, y in poly]
    d.polygon(inner, fill=dark)
    d.chord((cx - s(W * 0.2), cy + s(4), cx + s(W * 0.2), cy + s(15)), 0, 180, fill=tongue)
    out.append(im)

    # 5 dazed: wobbly squiggle + tongue out of one side
    im = cell(); d = ImageDraw.Draw(im)
    pts = [(cx + t * s(W * 1.1) / 2, cy + s(4) * math.sin(t * 3.2 * math.pi) + s(2)) for t in [(-1 + 2 * i / 60) for i in range(61)]]
    d.ellipse((cx + s(W * 0.12), cy + s(2), cx + s(W * 0.45), cy + s(22)), fill=tongue)
    d.line((cx + s(W * 0.285), cy + s(6), cx + s(W * 0.285), cy + s(16)), fill=(200, 80, 90, 255), width=int(s(1.5)))
    thick_line(d, pts, s(5), lip if P["who"] == "hush" else ink)
    out.append(im)

    # 6 snicker (Hush): big open D grin / sing (Bellows): round baritone O, wide
    im = cell(); d = ImageDraw.Draw(im)
    if P["who"] == "hush":
        poly = poly_smile(cx, cy - s(8), s(W * 1.5), s(0), s(30))
        d.polygon([(x, y) for x, y in poly], fill=lip)
        inner = poly_smile(cx, cy - s(5), s(W * 1.28), s(1), s(24))
        d.polygon(inner, fill=dark)
        tp = poly_smile(cx, cy - s(5), s(W * 1.2), s(1), s(8))
        d.polygon(tp, fill=teeth)
        d.chord((cx - s(W * 0.35), cy + s(6), cx + s(W * 0.35), cy + s(24)), 180, 360, fill=tongue)
    else:
        rx, ry = s(W * 0.42), s(W * 0.36)
        d.ellipse((cx - rx - s(4), cy - ry - s(4), cx + rx + s(4), cy + ry + s(4)), fill=lip)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=dark)
        d.chord((cx - rx * 0.8, cy - ry, cx + rx * 0.8, cy - ry * 0.4), 180, 360, fill=teeth)
        d.chord((cx - rx * 0.7, cy + ry * 0.1, cx + rx * 0.7, cy + ry * 1.0), 0, 180, fill=tongue)
    out.append(im)

    # 7 CHOO: huge blast mouth
    im = cell(); d = ImageDraw.Draw(im)
    rx, ry = s(W * 0.62), s(W * 0.55)
    d.ellipse((cx - rx - s(5), cy - ry - s(5) + s(4), cx + rx + s(5), cy + ry + s(5) + s(4)), fill=lip)
    d.ellipse((cx - rx, cy - ry + s(4), cx + rx, cy + ry + s(4)), fill=dark)
    d.chord((cx - rx * 0.8, cy - ry + s(4), cx + rx * 0.8, cy - ry * 0.35 + s(4)), 180, 360, fill=teeth)
    d.chord((cx - rx * 0.75, cy + ry * 0.05 + s(4), cx + rx * 0.75, cy + ry * 1.0 + s(4)), 0, 180, fill=tongue)
    d.ellipse((cx - s(3), cy + s(8) + s(4), cx + s(3), cy + ry * 0.6 + s(4)), fill=(190, 70, 80, 255))
    out.append(im)
    return out


def eyes(P):
    iris, iris2, pupil = P["iris"], P["iris2"], P["pupil"]
    out = []
    cx, cy = s(64), s(64)
    R = s(64)
    white = (255, 255, 255, 255)

    def base(ir, pr, hl=1.0):
        im = cell(); d = ImageDraw.Draw(im)
        r = R * ir
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=iris2)
        r2 = r * 0.86
        d.ellipse((cx - r2, cy - r2 - r * 0.08, cx + r2, cy + r2 - r * 0.08), fill=iris)
        p = R * pr
        d.ellipse((cx - p, cy - p, cx + p, cy + p), fill=pupil)
        h = R * 0.16 * hl
        hx, hy = cx - r * 0.38, cy - r * 0.4
        d.ellipse((hx - h, hy - h * 0.85, hx + h, hy + h * 0.85), fill=white)
        h2 = R * 0.065 * hl
        d.ellipse((cx + r * 0.38 - h2, cy + r * 0.34 - h2, cx + r * 0.38 + h2, cy + r * 0.34 + h2), fill=white)
        return im, d

    im, d = base(P["ir"], P["pr"])
    out.append(im)
    im, d = base(P["ir"] * 0.55, P["pr"] * 0.4, hl=0.55)
    out.append(im)
    # spiral
    im = cell(); d = ImageDraw.Draw(im)
    pts = []
    for i in range(400):
        a = i / 400 * 3.2 * 2 * math.pi
        r = R * 0.62 * i / 400
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.line(pts, fill=pupil, width=int(s(5)), joint="curve")
    out.append(im)
    im, d = base(P["ir"] * 1.02, P["pr"] * 1.1, hl=1.3)
    # sparkle star
    k = R * 0.2
    d.polygon([(cx + k * 0.35, cy - k * 1.6), (cx + k * 0.55, cy - k * 0.55), (cx + k * 1.4, cy - k * 0.35), (cx + k * 0.55, cy - k * 0.15),
               (cx + k * 0.35, cy + k * 0.9), (cx + k * 0.15, cy - k * 0.15), (cx - k * 0.7, cy - k * 0.35), (cx + k * 0.15, cy - k * 0.55)], fill=white)
    out.append(im)
    while len(out) < 8:
        out.append(cell())
    return out


PAL = {
    "hush": dict(who="hush", lip=hexc("D8354F"), inside=hexc("5B1426"), tongue=hexc("F07A86"), teeth=hexc("FFFFFF"),
                 ink=hexc("2B1E30"), w=54, iris=hexc("3E2724"), iris2=hexc("24161A"), pupil=hexc("120A0E"), ir=0.66, pr=0.36),
    "bellows": dict(who="bellows", lip=hexc("C0706A"), inside=hexc("4E1622"), tongue=hexc("E77B83"), teeth=hexc("FFFDF4"),
                    ink=hexc("4A2630"), w=50, iris=hexc("5F82B4"), iris2=hexc("3A557F"), pupil=hexc("141018"), ir=0.58, pr=0.3),
}


def build(who):
    m = mouths(PAL[who])
    e = eyes(PAL[who])
    strip = Image.new("RGBA", (1024 * SS, 256 * SS), (0, 0, 0, 0))
    for i, im in enumerate(m):
        strip.paste(im, (i * C, 0))
    for i, im in enumerate(e):
        strip.paste(im, (i * C, C))
    return strip.resize((1024, 256), Image.LANCZOS)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    prev = Image.new("RGBA", (1024, 512), (240, 230, 220, 255))
    for j, who in enumerate(("hush", "bellows")):
        st = build(who)
        st.save(os.path.join(out, "atlas_%s.png" % who))
        bg = Image.new("RGBA", st.size, (255, 246, 234, 255) if who == "hush" else (244, 201, 168, 255))
        bg.alpha_composite(st)
        prev.paste(bg, (0, j * 256))
    prev.save(os.path.join(out, "atlas_preview.png"))
