#!/usr/bin/env python3
"""The preview pictograms (REDESIGN_3D §4.3 BEFORE column, r3d-hud brief §4.4): one composite SVG
per slice prank in game/art/ui/previews/<prank>.svg — a picture of the JOKE (not the instruction),
drawn to sit inside the cream preview cloud and read at 78 px on a 1200x540 phone shot.

One visual language: flat fills + ONE darker shade shape, navy #1B2340 ink (5 px on the 128 canvas
~ 3 px at 78 px), round joins, look A's palette (toy_palette.py: Bellows' peach/nose/plum, Hush's
beret cherry and paint white, the honey gold, the cup blue), the "impact" yellow/orange and the
danger red kept for the payoff. Every file declares the previews.json pictogram ids it draws in
<desc>ids: ...</desc> (tests/ui/test_world_overlays.gd checks them). ThorVG-safe features only.

Run:  python3 game/art/ui/_src/gen_previews.py [sheet.png]
"""
import math
import os
import subprocess
import sys

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "previews"))

INK = "#1B2340"
W = 5
CREAM = "#FFF4E0"
WHITE = "#FFFFFF"
PEACH = "#F4C9A8"
PEACH_S = "#DDA27E"
NOSE = "#F2A38E"
NOSE_S = "#D98672"
PLUM = "#7B3F8C"
PLUM_S = "#5B2D6B"
GOLD = "#E8B33A"
GOLD_S = "#C99422"
YELLOW = "#FFD23F"
ORANGE = "#FF8A1F"
RED = "#E8413C"
RED_S = "#B32A26"
CHERRY = "#E23B4E"
BLUE = "#5E7FC2"
WATER = "#6FC3F2"
WATER_S = "#3E97D1"
GREEN = "#6DBE45"
GREEN_S = "#4A9230"
JELLY = "#E8413C"
TEAL = "#4E9C9A"
TEAL_S = "#357574"
STEEL = "#C9CED9"
STEEL_S = "#9CA3B4"
BLACK = "#26202E"
PAPER = "#F6F1E6"
PAPER_S = "#DDD3BF"
WOOD = "#A86B3C"
WOOD_S = "#80502A"
SILVER = "#D9DCE6"
ONION = "#E9B8E6"
ONION_S = "#D8C49A"
HAIR = "#4A2C3C"


def svg(ids, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
            '<desc>ids: %s</desc>\n%s\n</svg>\n' % (" ".join(ids), "\n".join(body)))


def p(d, fill, w=W, stroke=INK, op=1.0):
    s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, w) if w else ""
    o = ' fill-opacity="%.2f"' % op if op < 1 else ""
    return '<path d="%s" fill="%s"%s%s/>' % (d, fill, o, s)


def c(cx, cy, r, fill, w=W, op=1.0):
    s = ' stroke="%s" stroke-width="%s"' % (INK, w) if w else ""
    o = ' fill-opacity="%.2f"' % op if op < 1 else ""
    return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"%s%s/>' % (cx, cy, r, fill, o, s)


def e(cx, cy, rx, ry, fill, w=W, rot=0, op=1.0):
    s = ' stroke="%s" stroke-width="%s"' % (INK, w) if w else ""
    t = ' transform="rotate(%s %.1f %.1f)"' % (rot, cx, cy) if rot else ""
    o = ' fill-opacity="%.2f"' % op if op < 1 else ""
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"%s%s%s/>' % (cx, cy, rx, ry, fill, o, s, t)


def ln(d, w=W, col=INK):
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (d, col, w)


def rect(x, y, w_, h, fill, rx=6, w=W):
    s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (INK, w) if w else ""
    return '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"%s/>' % (x, y, w_, h, rx, fill, s)


def star(cx, cy, r_out, r_in, n, fill, rot=-90, w=W):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / n)
        pts.append("%.1f %.1f" % (cx + math.cos(a) * r, cy + math.sin(a) * r))
    return p("M" + " L".join(pts) + " Z", fill, w)


def poly(pts, fill, w=W):
    return p("M" + " L".join("%.1f %.1f" % q for q in pts) + " Z", fill, w)


# --- the eleven slice pranks -------------------------------------------------------------------

def achoo_ria():
    """A nose + a star burst: Bellows' big bulb nose explodes into a sneeze."""
    b = []
    # the burst first (behind the nose tip), a big yellow star with an orange core
    b.append(star(86, 56, 40, 19, 9, YELLOW, rot=-80))
    b.append(star(86, 56, 21, 10, 9, ORANGE, rot=-60, w=0))
    for (x, y, r) in ((122, 26, 4.5), (124, 74, 5), (110, 100, 4.5), (64, 18, 4)):
        b.append(c(x, y, r, WHITE, 3))
    # a slice of his face (peach) and the huge bulb nose pointing at the burst
    b.append(p("M2 20 Q24 14 34 30 L30 116 Q14 122 2 118 Z", PEACH))
    b.append(p("M2 96 Q16 104 30 100 L30 116 Q14 122 2 118 Z", PEACH_S, 0))
    b.append(c(46, 72, 30, NOSE))
    b.append(p("M46 102 Q72 98 76 72 Q74 92 60 100 Z", NOSE_S, 0))
    b.append(e(36, 60, 8, 5, WHITE, 0, rot=-30, op=0.6))
    b.append(e(52, 88, 7, 5, "#7A2336", 0, rot=-20))
    # the "ah-" twitch lines above the nose
    b.append(ln("M36 26 Q44 18 52 26 M58 30 Q64 24 70 30", 4))
    return svg(["nose", "star_burst"], b)


def allegro_go_go():
    """A record with "x3" and a spiral: the gramophone at triple speed."""
    b = []
    b.append(c(56, 70, 44, BLACK))
    for r in (34, 24):
        b.append('<circle cx="56" cy="70" r="%d" fill="none" stroke="#4A4050" stroke-width="3"/>' % r)
    b.append(c(56, 70, 14, CHERRY, 4))
    b.append(c(56, 70, 3.5, CREAM, 0))
    # speed swooshes
    b.append(ln("M12 40 Q20 24 38 18", 5, INK))
    b.append(ln("M6 62 Q6 44 16 34", 4, INK))
    # the red x3 sticker
    b.append(p("M78 12 L122 8 L124 44 L80 48 Z", RED))
    b.append(ln("M88 20 L102 38 M102 20 L88 38", 5.5, CREAM))
    b.append('<path d="M108 20 Q118 18 116 26 Q114 30 110 30 Q118 32 116 38 Q112 44 106 40" fill="none" stroke="%s" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>' % CREAM)
    # the dizzy spiral on top of the record
    sp = []
    for i in range(0, 64):
        a = i * 0.34
        r = 2 + i * 0.30
        sp.append("%.1f %.1f" % (100 + math.cos(a) * r, 92 + math.sin(a) * r))
    b.append(c(100, 92, 23, CREAM, 4))
    b.append(ln("M" + " L".join(sp), 4, PLUM))
    return svg(["record", "x3", "spiral"], b)


def kettle_drum():
    """A kettle + music notes + a red crack: the whistle turns into a song, then it cracks."""
    b = []
    # body
    b.append(p("M22 110 Q14 70 40 56 L76 56 Q100 68 94 110 Z", TEAL))
    b.append(p("M76 56 Q100 68 94 110 L80 110 Q86 72 70 58 Z", TEAL_S, 0))
    b.append(e(36, 76, 5, 9, WHITE, 0, rot=20, op=0.45))
    # lid + knob
    b.append(p("M34 58 Q58 40 82 58 Z", TEAL))
    b.append(c(58, 44, 6, GOLD, 4))
    # spout
    b.append(p("M92 84 L118 62 L122 70 L100 96 Z", TEAL))
    # handle
    b.append(ln("M34 58 Q58 20 82 58", 6, INK))
    # the red crack
    b.append(ln("M48 70 L56 82 L50 90 L60 104", 6, RED))
    # notes from the spout
    b.append(c(108, 40, 6, INK, 0))
    b.append(ln("M113 40 L113 18 L122 22", 4))
    b.append(c(88, 26, 5, INK, 0))
    b.append(ln("M92 26 L92 8", 4))
    return svg(["kettle", "notes", "crack"], b)


def tap_dance():
    """Tap -> water jet -> face: the spray rose blasts him in the face."""
    b = []
    # tap (top left)
    b.append(rect(4, 12, 40, 16, STEEL, 6))
    b.append(p("M36 18 L54 18 Q62 18 62 26 L62 38 L50 38 L50 30 L36 30 Z", STEEL))
    b.append(c(18, 8, 7, RED, 4))
    # the spray rose + a fat jet arcing down to the face
    b.append(e(56, 42, 12, 6, STEEL_S, 4))
    b.append(p("M46 46 Q56 92 84 92 L86 108 Q44 110 36 50 Z", WATER, 4))
    b.append(p("M62 48 Q76 80 94 76 L96 90 Q70 96 54 50 Z", WATER, 4))
    # the face (Bellows, eyes squeezed shut, mouth O), big
    b.append(c(98, 98, 27, PEACH, W))
    b.append(p("M72 90 Q76 70 98 70 Q122 70 126 88 Q110 78 90 80 Z", SILVER, 4))
    b.append(ln("M86 94 L94 99 L86 104 M112 94 L104 99 L112 104", 4))
    b.append(e(99, 114, 6, 5, "#7A2336", 3))
    # splash drops
    for (x, y) in ((70, 120), (124, 122), (78, 64)):
        b.append(e(x, y, 4.5, 7, WATER, 3))
    return svg(["tap", "water_jet", "face"], b)


def in_a_pickle():
    """A jar + a straining arm + flying onions: the lid is on too tight."""
    b = []
    # jar
    b.append(rect(20, 50, 58, 70, "#CFE8D8", 12))
    b.append(p("M62 54 L74 54 Q78 54 78 60 L78 110 Q78 118 70 118 L60 118 Q68 110 68 84 Z", "#A9CFB6", 0))
    for (x, y) in ((36, 80), (52, 96), (40, 104), (58, 72)):
        b.append(e(x, y, 7, 11, GREEN, 3, rot=20))
    b.append(rect(16, 38, 66, 16, RED, 5))
    # the straining arm (plum sleeve, peach hand gripping the lid)
    b.append(p("M126 22 L96 30 L92 46 L126 40 Z", PLUM))
    b.append(p("M94 30 Q74 26 70 38 Q70 50 86 50 Q96 48 96 40 Z", PEACH))
    b.append(ln("M76 36 L84 40 M74 42 L82 46", 3))
    # strain marks
    b.append(ln("M104 12 L100 20 M114 10 L112 18", 3.5, RED))
    # flying pickled onions (fat, with a sprout) and speed lines
    b.append(c(102, 76, 12, ONION, 4))
    b.append(p("M100 64 Q102 56 108 58", "none", 3.5))
    b.append(c(112, 106, 11, ONION, 4))
    b.append(p("M111 95 Q114 88 119 91", "none", 3.5))
    b.append(ln("M82 70 L90 74 M92 112 L100 110", 3.5))
    return svg(["jar", "straining_arm", "onions"], b)


def lift_off():
    """A chair + a spring + an up arrow to the chandelier: the recliner launches him."""
    b = []
    # chandelier (top right)
    b.append(ln("M96 2 L96 12", 3))
    b.append(p("M78 12 L114 12 L106 24 L86 24 Z", GOLD))
    for x in (80, 96, 112):
        b.append(e(x, 28, 3.5, 6, YELLOW, 2.5))
    # the big up arrow
    b.append(poly([(40, 52), (62, 30), (84, 52), (72, 52), (72, 66), (52, 66), (52, 52)], RED))
    # the spring
    b.append(ln("M46 92 L78 88 L44 82 L78 76 L46 70", 5, STEEL_S))
    # the chair (armchair) on top of the spring, tilted a bit
    b.append(p("M20 118 L20 98 Q20 92 28 92 L96 92 Q104 92 104 98 L104 118 Z", PLUM))
    b.append(p("M8 120 L8 96 Q8 88 18 88 Q26 88 26 96 L26 120 Z", PLUM))
    b.append(p("M98 120 L98 96 Q98 88 108 88 Q118 88 118 96 L118 120 Z", PLUM))
    b.append(p("M28 94 L96 94 L96 104 L28 104 Z", PLUM_S, 0))
    return svg(["chair", "spring", "up_arrow", "chandelier"], b)


def cold_open():
    """A fridge + an avalanche + a jelly helmet: the door opens and it all comes down."""
    b = []
    # fridge body + open door
    b.append(rect(8, 12, 56, 108, "#E6EEF2", 10))
    b.append(ln("M8 50 L64 50", 4))
    b.append(p("M64 14 L92 26 L92 116 L64 118 Z", "#C9D6DE"))
    b.append(ln("M86 60 L86 80", 5))
    # avalanche: food tumbling out
    b.append(c(40, 36, 9, "#F2A92E", 4))       # cheese wheel
    b.append(p("M20 62 Q40 54 54 66 L50 76 Q36 68 24 74 Z", "#D8344A"))   # sausage
    b.append(c(30, 94, 8, GREEN, 4))
    b.append(c(50, 100, 7, "#F7C95A", 4))
    # the jelly helmet (a wobbly red mould) flying out top right
    b.append(p("M92 30 Q92 10 110 8 Q126 10 126 30 Q126 38 118 38 L100 38 Q92 38 92 30 Z", JELLY))
    b.append(ln("M100 16 Q98 26 100 34 M112 12 Q110 24 112 36", 3, RED_S))
    b.append(e(104, 14, 3, 2, WHITE, 0, op=0.7))
    b.append(ln("M86 44 Q96 50 106 46 M110 46 Q116 52 124 48", 3))
    return svg(["fridge", "avalanche", "jelly_helmet"], b)


def eye_popping_news():
    """A newspaper + a magnifier + ballooned eyes: behind the lens his eyes swell x4."""
    b = []
    b.append(p("M6 24 L84 16 L90 110 L12 118 Z", PAPER))
    b.append(p("M48 20 L84 16 L90 110 L54 114 Z", PAPER_S, 0))
    for y in (34, 46, 58, 70, 82, 94):
        b.append(ln("M16 %d L44 %d" % (y + 2, y - 1), 3.5, "#A7A097"))
    # the magnifier with a HUGE eye in it
    b.append(ln("M110 118 L96 98", 10, WOOD))
    b.append(c(76, 66, 36, "#DCEBF2", 6))
    b.append(c(76, 66, 26, WHITE, 3))
    b.append(c(80, 68, 14, "#3B5BA8", 3))
    b.append(c(82, 70, 7, INK, 0))
    b.append(c(76, 62, 4, WHITE, 0))
    b.append(ln("M46 44 Q76 30 106 44", 4))
    return svg(["newspaper", "magnifier", "ballooned_eyes"], b)


def something_fishy():
    """A phone + a fish: the handset is a kipper."""
    b = []
    # candlestick phone base
    b.append(p("M20 118 Q20 98 40 96 L56 96 Q76 98 76 118 Z", BLACK))
    b.append(rect(42, 58, 12, 40, BLACK, 4))
    b.append(e(48, 56, 14, 6, BLACK, 4))
    b.append(c(48, 106, 6, GOLD, 3))
    # the kipper as the handset (orange-bronze smoked fish), lifted to the ear
    b.append(p("M56 30 Q80 10 108 22 Q116 26 112 32 Q88 44 62 40 Z", "#D98A3A"))
    b.append(poly([(58, 34), (40, 18), (40, 50)], "#D98A3A"))
    b.append(p("M70 36 Q88 38 104 30 Q90 42 70 40 Z", "#B06A26", 0))
    b.append(c(100, 24, 3.5, INK, 0))
    b.append(ln("M76 22 L80 30 M86 20 L90 28", 3))
    # the ring: vibration marks
    b.append(ln("M112 50 Q120 58 114 66 M100 58 Q106 64 102 70", 4))
    return svg(["phone", "fish"], b)


def times_up():
    """A clock + a zigzag + "!": the wound-up clock goes haywire."""
    b = []
    b.append(c(50, 58, 40, CREAM))
    b.append(c(50, 58, 32, WHITE, 3))
    for i in range(12):
        a = math.radians(i * 30)
        b.append(ln("M%.1f %.1f L%.1f %.1f" % (50 + math.cos(a) * 26, 58 + math.sin(a) * 26,
                                               50 + math.cos(a) * 30, 58 + math.sin(a) * 30), 3))
    b.append(ln("M50 58 L50 34 M50 58 L68 66", 5))
    b.append(c(50, 58, 4, INK, 0))
    # the sprung zigzag bursting out
    b.append(ln("M76 90 L96 84 L86 100 L108 94 L98 112 L120 106", 5, STEEL_S))
    # the "!"
    b.append(p("M104 8 L122 8 L116 52 L108 52 Z", RED))
    b.append(c(112, 64, 7, RED))
    # blur marks
    b.append(ln("M8 30 Q4 58 12 84", 4))
    return svg(["clock", "zigzag", "exclaim"], b)


def mirror_mirror():
    """An oval with Hush's face + a wink: she is the reflection."""
    b = []
    b.append(e(64, 66, 46, 58, GOLD))
    b.append(e(64, 66, 38, 50, "#BFE0FF", 4))
    b.append(p("M40 30 Q48 22 58 22 L42 44 Z", WHITE, 0, op=0.6))
    # Hush: painted white face, cherry beret, bob hair
    b.append(p("M34 70 Q34 36 64 36 Q94 36 94 70 L94 92 L82 92 L82 70 L46 70 L46 92 L34 92 Z", HAIR, 4))
    b.append(c(64, 72, 22, "#FFF6EA", 4))
    b.append(p("M36 44 Q46 22 70 24 Q94 26 96 42 Q80 34 58 36 Q44 38 36 44 Z", CHERRY, 4))
    b.append(c(78, 24, 4, CHERRY, 3))
    # the wink: one eye closed arc, one open
    b.append(ln("M50 72 Q55 67 60 72", 3.5))
    b.append(c(74, 70, 3.5, INK, 0))
    b.append(ln("M56 84 Q64 90 72 84", 3.5))
    b.append(e(50, 80, 4, 2.5, "#FF9AA2", 0))
    b.append(e(78, 80, 4, 2.5, "#FF9AA2", 0))
    # the wink sparkle
    b.append(star(104, 22, 12, 5, 4, YELLOW, rot=-90, w=3))
    return svg(["oval_face", "wink"], b)


def unknown():
    b = [c(64, 64, 34, YELLOW), ln("M52 52 Q52 38 64 38 Q78 38 78 52 Q78 60 64 66 L64 74", 7), c(64, 88, 5, INK, 0)]
    return svg(["unknown"], b)


def badge_to_sink():
    """The HOT & COLD combine badge's target: the sink tap."""
    b = [rect(10, 30, 60, 24, STEEL, 8), p("M60 38 L90 38 Q104 38 104 52 L104 72 L84 72 L84 58 L60 58 Z", STEEL),
         c(34, 22, 10, RED, 4), e(94, 92, 7, 11, WATER, 4)]
    return svg(["to_sink"], b)


PRANKS = {
    "achoo_ria": achoo_ria, "allegro_go_go": allegro_go_go, "kettle_drum": kettle_drum, "tap_dance": tap_dance,
    "in_a_pickle": in_a_pickle, "lift_off": lift_off, "cold_open": cold_open, "eye_popping_news": eye_popping_news,
    "something_fishy": something_fishy, "times_up": times_up, "mirror_mirror": mirror_mirror,
    "_unknown": unknown, "badge_to_sink": badge_to_sink,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    paths = []
    for name, fn in PRANKS.items():
        path = os.path.join(OUT, name + ".svg")
        with open(path, "w") as f:
            f.write(fn())
        paths.append(path)
    if len(sys.argv) > 1:
        from PIL import Image, ImageDraw
        tiles = []
        for path in paths[:11]:
            png = path + ".png"
            subprocess.run(["rsvg-convert", "-w", "78", path, "-o", png], check=True)
            tiles.append(Image.open(png).convert("RGBA"))
            os.remove(png)
        cell = 112
        sheet = Image.new("RGBA", (cell * len(tiles) + 16, cell + 16), (120, 110, 90, 255))
        d = ImageDraw.Draw(sheet)
        for i, t in enumerate(tiles):
            x0 = 8 + i * cell
            d.ellipse((x0 + 4, 8 + 8, x0 + cell - 4, 8 + cell - 8), fill=(255, 244, 224, 255), outline=(27, 35, 64, 255), width=4)
            sheet.alpha_composite(t, (x0 + (cell - 78) // 2, 8 + (cell - 78) // 2))
        sheet.save(sys.argv[1])
    print("wrote", len(paths))


if __name__ == "__main__":
    main()
