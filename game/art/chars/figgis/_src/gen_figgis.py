#!/usr/bin/env python3
"""Old Figgis, the prompter mouse, as a flat matte-vinyl BUST in look A's (Toy Box) palette
(r3d-hud brief §4.7, index R7): the chip's idle bust `figgis_chip.svg` + one SVG per mood
(`figgis_psst`, `figgis_point`, `figgis_shh`, `figgis_proud`), 128 x 128.

Vinyl look in flat SVG: every form = its base colour + ONE soft lilac shadow shape (A's shadow tint
#B9A3E0 multiplied in, never below ~66 % of the albedo's value) on the side away from the key
(the key comes from the upper left, like the 3D stage light) + one small matte sheen ellipse on
the lit side; navy ink #1B2340 outline (5 px). Colours come from tools/art3d/look-toy/toy_palette.py
(plum, cream, cheek pink, nose, specs gold, lens, glove white) so he sits beside the 3D cast.
Only ThorVG-safe features (paths, circles, ellipses, rects, strokes, opacity) — no gradients.

Run:  python3 game/art/chars/figgis/_src/gen_figgis.py [contact_sheet.png]
"""
import os
import subprocess
import sys

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))

INK = "#1B2340"
# look A palette (toy_palette.py)
NAVY_A = "#2B3566"      # the prompt-box hood (A's Breton navy)
NAVY_A_S = "#232A52"
GOLD = "#E8B33A"        # cravat gold -> the box's gilt trim
GOLD_S = "#C99422"
FUR = "#CFC6D8"         # a soft lilac-grey mouse
FUR_S = "#AFA3C4"
MUZZLE = "#FBF6EC"      # cuff cream
MUZZLE_S = "#E3D9E6"
EAR_IN = "#FF9AA2"      # cheek pink
NOSE = "#F2A38E"
NOSE_S = "#D98672"
SPECS = "#D2A33C"
LENS = "#DCEBF2"
GLOVE = "#FFFFFF"
GLOVE_S = "#E9E6F0"
CARD = "#FFF4E0"
CARD_S = "#EBD7B3"
BLUSH = "#FF9AA2"
EYE = "#1B2340"
MOUTH = "#7A2336"
SHEEN = "#FFFFFF"

W = 5  # ink width


def svg(body, desc):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
            '<desc>%s</desc>\n%s\n</svg>\n' % (desc, "\n".join(body)))


def ink(d, fill, w=W):
    return '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"/>' % (d, fill, INK, w)


def flat(d, fill, op=1.0):
    return '<path d="%s" fill="%s" fill-opacity="%.2f"/>' % (d, fill, op)


def circ(cx, cy, r, fill, stroke=True, w=W, op=1.0):
    s = ' stroke="%s" stroke-width="%s"' % (INK, w) if stroke else ""
    return '<circle cx="%s" cy="%s" r="%s" fill="%s" fill-opacity="%.2f"%s/>' % (cx, cy, r, fill, op, s)


def ell(cx, cy, rx, ry, fill, stroke=True, w=W, rot=0, op=1.0):
    s = ' stroke="%s" stroke-width="%s"' % (INK, w) if stroke else ""
    t = ' transform="rotate(%s %s %s)"' % (rot, cx, cy) if rot else ""
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" fill-opacity="%.2f"%s%s/>' % (cx, cy, rx, ry, fill, op, s, t)


def line(d, w=4, col=INK):
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (d, col, w)


def hood():
    """The prompter's box: a navy hood with a gilt rim; the bust sits inside it."""
    body = "M10 126 L10 58 Q10 10 64 8 Q118 10 118 58 L118 126 Z"
    out = [ink(body, NAVY_A)]
    # the inside of the shell (darker) and a lilac-cool shadow on the right flank
    out.append(flat("M22 126 L22 62 Q22 22 64 20 Q106 22 106 62 L106 126 Z", NAVY_A_S))
    out.append(flat("M96 20 Q118 30 118 58 L118 126 L106 126 L106 62 Q106 36 96 20 Z", "#1E2448", 0.8))
    # gilt rim along the arch
    out.append(line("M13 60 Q13 13 64 11 Q115 13 115 60", 5, GOLD))
    out.append(line("M13 60 Q13 13 64 11", 2, "#FFE08A"))
    # sheen on the upper left of the hood
    out.append(ell(34, 34, 9, 4, SHEEN, False, rot=-38, op=0.22))
    return out


def ears():
    out = []
    for cx, rot in ((28, -16), (100, 16)):
        out.append(ell(cx, 56, 20, 23, FUR, rot=rot))
        out.append(ell(cx + (3 if cx < 64 else -3), 58, 11, 14, EAR_IN, False, rot=rot))
    # shade on the right ear
    out.append(ell(106, 62, 9, 14, FUR_S, False, rot=16, op=0.7))
    return out


def head(blush=False):
    out = []
    # the head: a soft pear, fur with the lilac shadow on the lower right
    out.append(ink("M64 34 Q92 34 94 66 Q96 96 64 102 Q32 96 34 66 Q36 34 64 34 Z", FUR))
    out.append(flat("M86 44 Q94 58 93 70 Q92 94 64 100 Q84 90 86 70 Q88 56 86 44 Z", FUR_S, 0.9))
    out.append(ell(48, 46, 8, 4, SHEEN, False, rot=-30, op=0.3))
    # muzzle
    out.append(ink("M64 70 Q84 70 84 86 Q82 100 64 100 Q46 100 44 86 Q44 70 64 70 Z", MUZZLE, 4))
    out.append(flat("M76 74 Q84 80 82 90 Q78 99 66 100 Q78 94 79 86 Q80 79 76 74 Z", MUZZLE_S))
    if blush:
        out.append(ell(42, 82, 7, 4, BLUSH, False, op=0.8))
        out.append(ell(86, 82, 7, 4, BLUSH, False, op=0.8))
    # whiskers
    out.append(line("M44 84 L28 80 M44 89 L28 91 M84 84 L100 80 M84 89 L100 91", 2.5))
    return out


def nose():
    return [ell(64, 76, 7, 5, NOSE, w=3.5), ell(62, 74.5, 2.5, 1.5, SHEEN, False, op=0.7)]


def specs(eyes="open"):
    """Round gold specs; eyes: open | side | closed | half."""
    out = []
    for cx in (52, 76):
        out.append(circ(cx, 60, 11, LENS, w=4))
    out.append(line("M63 60 L65 60", 4))
    out.append(line("M41 58 L35 55 M87 58 L93 55", 3))
    for cx in (52, 76):
        out.append('<circle cx="%s" cy="60" r="11" fill="none" stroke="%s" stroke-width="2.5"/>' % (cx, SPECS))
        if eyes == "open":
            out.append(circ(cx, 61, 3.6, EYE, False))
            out.append(circ(cx - 1.2, 59.6, 1.1, SHEEN, False))
        elif eyes == "side":
            out.append(circ(cx - 4, 61, 3.6, EYE, False))
            out.append(circ(cx - 5.2, 59.6, 1.1, SHEEN, False))
        elif eyes == "closed":
            out.append(line("M%s 62 Q%s 56 %s 62" % (cx - 5, cx, cx + 5), 3))
        elif eyes == "half":
            out.append(line("M%s 60 L%s 60" % (cx - 5, cx + 5), 3))
            out.append(circ(cx, 62.5, 2.6, EYE, False))
    # brows
    return out


def brows(kind="soft"):
    if kind == "up":
        return [line("M44 43 Q52 38 58 42 M70 42 Q76 38 84 43", 3.5)]
    if kind == "sly":
        return [line("M44 45 Q52 42 58 46 M70 43 Q77 39 84 42", 3.5)]
    return [line("M45 45 Q52 41 58 44 M70 44 Q76 41 83 45", 3.5)]


def mouth(kind):
    if kind == "smile":
        return [line("M57 91 Q64 96 71 91", 3.5)]
    if kind == "o":
        return [ell(66, 92, 4, 4.5, MOUTH, w=3)]
    if kind == "grin":
        return [ink("M54 88 Q64 100 74 88 Z", MOUTH, 3), flat("M58 91 Q64 95 70 91 Z", "#FF9AA2")]
    if kind == "shh":
        return [line("M59 92 Q64 90 69 92", 3)]
    return []


def glove(cx, cy, rot=0, kind="cup"):
    """A white cartoon glove: a round mitten with two finger creases (and a raised index finger for
    "finger")."""
    t = 'transform="rotate(%s %s %s)"' % (rot, cx, cy)
    g = ['<g %s>' % t]
    if kind == "finger":
        g.append(ink("M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % (
            cx - 4, cy - 2, cx - 4, cy - 22, cx - 4, cy - 28, cx, cy - 28, cx + 4, cy - 28, cx + 4, cy - 22, cx + 4, cy - 2),
            GLOVE, 3.5))
    g.append(ell(cx, cy + 4, 13, 10, GLOVE, w=4))
    g.append(ell(cx + 4, cy + 8, 7, 4, GLOVE_S, False))
    if kind != "finger":
        g.append(line("M%s %s L%s %s M%s %s L%s %s" % (cx - 4, cy - 4, cx - 4, cy + 3, cx + 4, cy - 4, cx + 4, cy + 3), 2.5))
    g.append('</g>')
    return g


def ledge():
    """The box's front ledge the bust leans on (hides the neck)."""
    return [ink("M8 106 L120 106 L120 124 Q120 126 118 126 L10 126 Q8 126 8 124 Z", GOLD),
            flat("M11 118 L117 118 L117 123 L11 123 Z", GOLD_S), line("M14 110 L114 110", 2.5, "#FFE08A")]


def bust(mood):
    b = hood() + ears() + head(blush=mood in ("proud", "psst"))
    if mood == "idle":
        b += specs("open") + brows("soft") + nose() + mouth("smile")
        b += ledge()
        b += glove(44, 110, -10, "cup") + glove(84, 110, 10, "cup")
    elif mood == "psst":
        b += specs("side") + brows("up") + nose() + mouth("o")
        b += ledge()
        b += glove(44, 110, -10, "cup")
        b += glove(92, 90, -20, "cup")      # a hand cupped beside the mouth
        b += [line("M104 80 Q110 76 114 80 M106 88 Q114 86 118 90", 3, INK)]
    elif mood == "point":
        b += specs("open") + brows("up") + nose() + mouth("smile")
        # the blank cue card held up beside him (the HUD draws the real card)
        # (3 px inside the right edge: the 3 px clear margin of the art validator; the bust may touch the bottom)
        b += [ink("M81 64 L117 58 L121 90 L85 96 Z", CARD, 4), flat("M85 90 L120 85 L121 90 L85 96 Z", CARD_S),
              line("M91 74 L111 71 M93 82 L107 80", 3, "#C9B38A")]
        b += ledge()
        b += glove(44, 110, -10, "cup") + glove(89, 94, 12, "card")
    elif mood == "shh":
        b += specs("half") + brows("sly") + nose() + mouth("shh")
        b += ledge()
        b += glove(44, 110, -10, "cup")
        b += glove(64, 104, 0, "finger")    # finger to the lips
    elif mood == "proud":
        b += specs("closed") + brows("up") + nose() + mouth("grin")
        b += ledge()
        b += glove(40, 106, -24, "cup") + glove(88, 106, 24, "cup")
        b += [line("M18 30 L10 24 M16 42 L6 42 M110 30 L118 24 M112 42 L122 42", 3.5, GOLD)]
    return svg(b, "Old Figgis, %s (look A vinyl bust)" % mood)


MOODS = {"figgis_chip": "idle", "figgis_psst": "psst", "figgis_point": "point", "figgis_shh": "shh",
         "figgis_proud": "proud"}


def main():
    paths = []
    for name, mood in MOODS.items():
        p = os.path.join(OUT, name + ".svg")
        with open(p, "w") as f:
            f.write(bust(mood))
        paths.append(p)
    if len(sys.argv) > 1:
        from PIL import Image
        tiles = []
        for p in paths:
            png = p + ".png"
            subprocess.run(["rsvg-convert", "-w", "256", p, "-o", png], check=True)
            tiles.append(Image.open(png).convert("RGBA"))
            os.remove(png)
        sheet = Image.new("RGBA", (256 * len(tiles) + 20 * (len(tiles) + 1), 296), (201, 182, 132, 255))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t, (20 + i * 276, 20))
        sheet.save(sys.argv[1])
    print("wrote", len(paths))


if __name__ == "__main__":
    main()
