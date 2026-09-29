#!/usr/bin/env python3
"""Generate the view's FX sprites (owner: view) into game/art/fx/.

Particles are white-filled with the navy ink outline (colour comes from the particle
colour ramp as a modulate), authored at 64 px and drawn at scale 0.5 so they stay crisp
under the 1.6x Gag-Cam. Everything follows game/art/STYLE.md: presentation attributes
only, no filters/text/images, gradients only for glows, round joins, ink #1B2340.

Run:  python3 game/art/fx/_src/gen_fx.py   (from the repo root)
"""
from pathlib import Path

INK = "#1B2340"
OUT = Path(__file__).resolve().parent.parent


def svg(w, h, body):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{w}' height='{h}' viewBox='0 0 {w} {h}'>"
            f"{body}</svg>\n")


def stroke(w=4.0):
    return f"stroke='{INK}' stroke-width='{w}' stroke-linejoin='round' stroke-linecap='round'"


FILES = {
    # --- particles (64 px) ----------------------------------------------------------------
    "particles/dust.svg": svg(64, 64,
        f"<path d='M17 50 A11 11 0 0 1 12 30 A14 14 0 0 1 32 14 A13 13 0 0 1 51 28 A10 10 0 0 1 47 50 Z' "
        f"fill='#FFFFFF' {stroke(4)}/>"
        f"<path d='M22 26 A9 9 0 0 1 32 20' fill='none' stroke='#FFFFFF' stroke-width='5' stroke-linecap='round' opacity='0.7'/>"),
    "particles/flour.svg": svg(64, 64,
        "<circle cx='32' cy='32' r='22' fill='#FFFFFF' opacity='0.92'/>"
        "<circle cx='24' cy='26' r='7' fill='#FFFFFF'/>"),
    "particles/feather.svg": svg(64, 64,
        f"<path d='M32 4 C50 16 50 40 35 60 L29 60 C14 40 14 16 32 4 Z' fill='#FFFFFF' {stroke(3.5)}/>"
        f"<path d='M32 12 L32 62 M32 26 L42 20 M32 36 L22 30 M32 45 L42 39' fill='none' {stroke(2.8)}/>"),
    "particles/drop.svg": svg(64, 64,
        f"<path d='M32 5 C44 23 52 33 52 42 A20 20 0 0 1 12 42 C12 33 20 23 32 5 Z' fill='#FFFFFF' {stroke(4)}/>"
        "<ellipse cx='24' cy='40' rx='4.5' ry='7' fill='#FFFFFF' opacity='0.85'/>"),
    "particles/steam.svg": svg(64, 64,
        "<path d='M14 48 A12 12 0 0 1 12 26 A15 15 0 0 1 36 12 A14 14 0 0 1 54 30 A11 11 0 0 1 48 50 Z' "
        "fill='#FFFFFF' opacity='0.9'/>"),
    "particles/sparkle.svg": svg(64, 64,
        f"<path d='M32 3 L38 26 L61 32 L38 38 L32 61 L26 38 L3 32 L26 26 Z' fill='#FFFFFF' {stroke(3.5)}/>"),
    "particles/note.svg": svg(64, 64,
        f"<path d='M26 48 L26 12 L52 6 L52 40' fill='none' stroke='{INK}' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>"
        f"<path d='M26 48 L26 12 L52 6 L52 40' fill='none' stroke='#FFFFFF' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>"
        f"<ellipse cx='18' cy='49' rx='10' ry='8' fill='#FFFFFF' {stroke(3.5)}/>"
        f"<ellipse cx='44' cy='42' rx='10' ry='8' fill='#FFFFFF' {stroke(3.5)}/>"),
    "particles/rose.svg": svg(64, 64,
        f"<path d='M30 40 C26 50 22 56 18 60' fill='none' stroke='{INK}' stroke-width='7' stroke-linecap='round'/>"
        f"<path d='M30 40 C26 50 22 56 18 60' fill='none' stroke='#3E8E41' stroke-width='3' stroke-linecap='round'/>"
        f"<path d='M22 50 C14 46 12 40 16 36 C22 38 24 44 22 50 Z' fill='#4E9A4A' {stroke(3)}/>"
        f"<circle cx='32' cy='26' r='19' fill='#E23B4E' {stroke(4)}/>"
        f"<path d='M22 24 C26 14 38 14 42 24 C38 32 28 32 26 24 C30 20 34 20 36 25' fill='none' stroke='#9E1B32' stroke-width='3' stroke-linecap='round'/>"),
    # --- caption plate (starburst behind a pun caption) -----------------------------------
    "caption_burst.svg": svg(400, 170,
        "<path d='M200 6 L228 34 L276 12 L282 46 L338 30 L322 62 L392 66 L346 90 L394 118 L326 120 "
        "L340 156 L280 138 L262 166 L226 140 L200 166 L174 140 L138 166 L120 138 L60 156 L74 120 "
        "L6 118 L54 90 L8 66 L78 62 L62 30 L118 46 L124 12 L172 34 Z' "
        f"fill='#FFD23F' {stroke(6)}/>"
        "<path d='M200 30 L222 52 L262 38 L266 62 L314 58 L300 82 L340 94 L300 106 L312 128 L264 122 "
        "L256 146 L222 128 L200 146 L178 128 L144 146 L136 122 L88 128 L100 106 L60 94 L100 82 L86 58 "
        "L134 62 L138 38 L178 52 Z' fill='#FFF4E0' opacity='0.55'/>"),
    # --- Bellows' footprint (slipper), drawn faint on the floor ------------------------------
    "footprint.svg": svg(40, 24,
        "<ellipse cx='22' cy='12' rx='16' ry='8.5' fill='#FFFFFF'/>"
        "<ellipse cx='8' cy='12' rx='5' ry='6' fill='#FFFFFF'/>"),
    # --- red vignette for the Busted Cam (radial glow; gradients allowed for glows) --------
    "vignette_red.svg": svg(480, 270,
        "<defs><radialGradient id='v' cx='50%' cy='50%' r='70%'>"
        "<stop offset='0.55' stop-color='#B3122E' stop-opacity='0'/>"
        "<stop offset='0.85' stop-color='#B3122E' stop-opacity='0.55'/>"
        "<stop offset='1' stop-color='#6E0A1E' stop-opacity='0.85'/></radialGradient></defs>"
        "<rect x='0' y='0' width='480' height='270' fill='url(#v)'/>"),
    # --- T3 falling props / Meltdown quake props ------------------------------------------
    "props/picture_frame.svg": svg(110, 90,
        f"<rect x='5' y='5' width='100' height='80' rx='4' fill='#E8B33A' {stroke(5)}/>"
        f"<rect x='18' y='17' width='74' height='56' fill='#9FD6F0' stroke='{INK}' stroke-width='3'/>"
        f"<path d='M18 62 L40 44 L56 58 L70 48 L92 66 L92 73 L18 73 Z' fill='#8ACB6A' stroke='{INK}' stroke-width='3' stroke-linejoin='round'/>"
        f"<circle cx='74' cy='30' r='6' fill='#FFD23F' stroke='{INK}' stroke-width='2.5'/>"),
    "props/vase.svg": svg(70, 100,
        f"<path d='M24 6 L46 6 L44 18 C62 30 64 60 52 84 C48 92 22 92 18 84 C6 60 8 30 26 18 Z' fill='#3AA7E0' {stroke(5)}/>"
        f"<path d='M16 50 C28 56 42 56 56 50' fill='none' stroke='{INK}' stroke-width='3'/>"
        f"<path d='M20 62 C30 66 40 66 52 62' fill='none' stroke='#FFFFFF' stroke-width='4' stroke-linecap='round'/>"),
    "props/hat.svg": svg(120, 70,
        f"<ellipse cx='60' cy='56' rx='54' ry='10' fill='#2A1E3A' {stroke(5)}/>"
        f"<path d='M26 56 C24 24 36 8 60 8 C84 8 96 24 94 56 Z' fill='#2A1E3A' {stroke(5)}/>"
        f"<path d='M27 44 C48 50 72 50 93 44 L93 52 C72 58 48 58 27 52 Z' fill='#B3122E' stroke='{INK}' stroke-width='3'/>"),
    "props/sausage.svg": svg(120, 50,
        f"<path d='M14 30 C14 12 30 8 60 10 C90 8 106 12 106 30 C106 42 92 44 60 42 C28 44 14 42 14 30 Z' fill='#C9563A' {stroke(5)}/>"
        f"<path d='M30 20 C50 16 72 16 92 20' fill='none' stroke='#F4A58A' stroke-width='4' stroke-linecap='round'/>"
        f"<path d='M8 30 L2 26 M112 30 L118 26' fill='none' {stroke(4)}/>"),
    "props/pan.svg": svg(130, 70,
        f"<path d='M70 36 L124 26' fill='none' stroke='{INK}' stroke-width='14' stroke-linecap='round'/>"
        f"<path d='M70 36 L124 26' fill='none' stroke='#6B4A34' stroke-width='7' stroke-linecap='round'/>"
        f"<ellipse cx='40' cy='38' rx='36' ry='26' fill='#9AA3B5' {stroke(5)}/>"
        f"<ellipse cx='40' cy='36' rx='24' ry='16' fill='#C9D0DE' stroke='{INK}' stroke-width='3'/>"),
    "props/onion.svg": svg(60, 64,
        f"<path d='M30 6 C34 14 52 24 52 40 C52 54 42 60 30 60 C18 60 8 54 8 40 C8 24 26 14 30 6 Z' fill='#F3EAD6' {stroke(4.5)}/>"
        f"<path d='M30 12 C24 26 22 44 28 58 M30 12 C38 26 40 44 34 58' fill='none' stroke='#C9A27A' stroke-width='2.5'/>"),
    # --- fallback awareness glyphs (48 px; the real ones are ui's) -------------------------
    "fallback/glyph_specs_off.svg": svg(48, 48,
        f"<path d='M10 6 C8 18 14 22 18 26' fill='none' stroke='{INK}' stroke-width='2.5' stroke-dasharray='3 3'/>"
        f"<path d='M38 6 C40 18 34 22 30 26' fill='none' stroke='{INK}' stroke-width='2.5' stroke-dasharray='3 3'/>"
        f"<g transform='rotate(18 24 34)'><circle cx='14' cy='34' r='8' fill='#FFFFFF' {stroke(3.5)}/>"
        f"<circle cx='34' cy='34' r='8' fill='#FFFFFF' {stroke(3.5)}/>"
        f"<path d='M22 34 L26 34' {stroke(3.5)}/></g>"),
    "fallback/glyph_specs_on.svg": svg(48, 48,
        f"<circle cx='13' cy='24' r='10' fill='#FFF4E0' {stroke(4)}/>"
        f"<circle cx='35' cy='24' r='10' fill='#FFF4E0' {stroke(4)}/>"
        f"<path d='M23 23 L25 23' {stroke(4)}/>"
        f"<circle cx='14' cy='24' r='3.5' fill='{INK}'/><circle cx='36' cy='24' r='3.5' fill='{INK}'/>"
        "<path d='M8 18 L12 14' stroke='#FFFFFF' stroke-width='2.5' stroke-linecap='round'/>"),
    "fallback/glyph_blinded.svg": svg(48, 48,
        f"<circle cx='13' cy='24' r='10' fill='#F2DFA6' {stroke(4)}/>"
        f"<circle cx='35' cy='24' r='10' fill='#F2DFA6' {stroke(4)}/>"
        f"<path d='M23 23 L25 23' {stroke(4)}/>"
        f"<path d='M7 20 C11 26 15 18 19 24 M29 20 C33 26 37 18 41 24' fill='none' {stroke(3)}/>"),
    "fallback/glyph_asleep.svg": svg(48, 48,
        f"<path d='M6 20 L20 20 L6 36 L20 36' fill='none' {stroke(4.5)}/>"
        f"<path d='M26 8 L40 8 L26 24 L40 24' fill='none' {stroke(4)}/>"),
    "fallback/glyph_stars.svg": svg(48, 48,
        f"<path d='M14 4 L17 12 L25 13 L19 18 L21 26 L14 22 L7 26 L9 18 L3 13 L11 12 Z' fill='#FFD23F' {stroke(3)}/>"
        f"<path d='M34 18 L37 26 L45 27 L39 32 L41 40 L34 36 L27 40 L29 32 L23 27 L31 26 Z' fill='#FFD23F' {stroke(3)}/>"),
    # --- fallback hotspot badges (56 px; the real ones are ui's) ---------------------------
    "fallback/badge_gold.svg": svg(56, 56,
        f"<circle cx='28' cy='28' r='24' fill='#FFD23F' {stroke(4)}/>"
        f"<path d='M28 12 L32 23 L44 23 L34 30 L38 42 L28 35 L18 42 L22 30 L12 23 L24 23 Z' fill='#FFFFFF' {stroke(3)}/>"),
    "fallback/badge_blue.svg": svg(56, 56,
        f"<circle cx='28' cy='28' r='24' fill='#3AA7E0' {stroke(4)}/>"
        f"<path d='M12 26 C20 36 36 36 44 26' fill='none' stroke='#FFFFFF' stroke-width='4.5' stroke-linecap='round'/>"
        f"<path d='M17 32 L13 37 M28 35 L28 41 M39 32 L43 37' stroke='#FFFFFF' stroke-width='3.5' stroke-linecap='round'/>"),
    "fallback/badge_red.svg": svg(56, 56,
        f"<circle cx='28' cy='28' r='24' fill='#E23B4E' {stroke(4)}/>"
        f"<path d='M28 13 L28 32' stroke='#FFFFFF' stroke-width='7' stroke-linecap='round'/>"
        f"<circle cx='28' cy='42' r='4' fill='#FFFFFF'/>"),
    "fallback/badge_grey.svg": svg(56, 56,
        f"<path d='M14 40 A9 9 0 0 1 10 24 A11 11 0 0 1 24 12 A12 12 0 0 1 44 18 A10 10 0 0 1 46 38 Z' fill='#D9DCE6' {stroke(4)}/>"
        f"<circle cx='12' cy='48' r='4' fill='#D9DCE6' {stroke(2.5)}/>"
        f"<rect x='20' y='20' width='16' height='14' rx='4' fill='#9AA3B5'/>"),
    # --- fallback activity icon (88 px; the real ones are art-house's) --------------------
    "fallback/icon_generic.svg": svg(88, 88,
        f"<circle cx='44' cy='44' r='34' fill='#FFF4E0' {stroke(5)}/>"
        f"<path d='M34 60 L34 26 L60 20 L60 54' fill='none' stroke='{INK}' stroke-width='6' stroke-linecap='round' stroke-linejoin='round'/>"
        f"<ellipse cx='28' cy='60' rx='8' ry='6.5' fill='{INK}'/><ellipse cx='54' cy='54' rx='8' ry='6.5' fill='{INK}'/>"),
    # --- thought bubble cloud (150 x 130 incl. the tail puffs) ------------------------------
    "thought_bubble.svg": svg(150, 130,
        f"<path d='M30 94 A22 22 0 0 1 14 58 A26 26 0 0 1 44 20 A30 30 0 0 1 96 14 A26 26 0 0 1 136 44 "
        f"A22 22 0 0 1 130 88 A24 24 0 0 1 92 104 A28 28 0 0 1 52 104 A22 22 0 0 1 30 94 Z' fill='#FFFFFF' {stroke(5)}/>"
        f"<circle cx='22' cy='112' r='8' fill='#FFFFFF' {stroke(4)}/>"
        f"<circle cx='9' cy='124' r='4.5' fill='#FFFFFF' {stroke(3)}/>"),
    "dot.svg": svg(16, 16, "<circle cx='8' cy='8' r='7' fill='#FFFFFF'/>"),
    "props/door_handle.svg": svg(40, 60,
        f"<rect x='12' y='6' width='16' height='48' rx='6' fill='#E8B33A' {stroke(4)}/>"
        f"<circle cx='20' cy='22' r='9' fill='#FFD23F' {stroke(4)}/>"
        f"<circle cx='20' cy='42' r='3' fill='{INK}'/>"),
    "fallback/legs.svg": svg(120, 150,
        f"<path d='M34 0 L34 120' stroke='{INK}' stroke-width='30' stroke-linecap='round'/>"
        f"<path d='M34 0 L34 120' stroke='#7B3F8C' stroke-width='20' stroke-linecap='round'/>"
        f"<path d='M84 0 L84 104' stroke='{INK}' stroke-width='30' stroke-linecap='round'/>"
        f"<path d='M84 0 L84 104' stroke='#7B3F8C' stroke-width='20' stroke-linecap='round'/>"
        f"<ellipse cx='44' cy='132' rx='30' ry='14' fill='#B3122E' {stroke(5)}/>"
        f"<ellipse cx='94' cy='116' rx='30' ry='14' fill='#B3122E' {stroke(5)}/>"),
    "fallback/eyes.svg": svg(64, 32,
        f"<ellipse cx='18' cy='16' rx='12' ry='13' fill='#FFFFFF' {stroke(3)}/>"
        f"<ellipse cx='46' cy='16' rx='12' ry='13' fill='#FFFFFF' {stroke(3)}/>"),
    # --- velvet rope (roped doorways into unlit rooms; art-house may ship its own) --------
    "fallback/velvet_rope.svg": svg(220, 150,
        f"<rect x='12' y='30' width='14' height='110' rx='4' fill='#E8B33A' {stroke(4)}/>"
        f"<rect x='194' y='30' width='14' height='110' rx='4' fill='#E8B33A' {stroke(4)}/>"
        f"<circle cx='19' cy='26' r='10' fill='#E8B33A' {stroke(4)}/><circle cx='201' cy='26' r='10' fill='#E8B33A' {stroke(4)}/>"
        f"<ellipse cx='19' cy='142' rx='16' ry='5' fill='#E8B33A' {stroke(3)}/><ellipse cx='201' cy='142' rx='16' ry='5' fill='#E8B33A' {stroke(3)}/>"
        f"<path d='M24 40 C70 96 150 96 196 40' fill='none' stroke='{INK}' stroke-width='14' stroke-linecap='round'/>"
        f"<path d='M24 40 C70 96 150 96 196 40' fill='none' stroke='#B3122E' stroke-width='8' stroke-linecap='round'/>"),
}


NAVY = "#2B3566"
CHERRY = "#E23B4E"
PAINT = "#FFF6EA"
PLUM = "#7B3F8C"
GOLD = "#E8B33A"
SILVER = "#D9DCE6"
PEACH = "#F4C9A8"


def hush(pose):
    """Hush stand-in puppet, 220 x 350, feet at (110, 346)."""
    s = stroke(6)
    parts = []
    # legs + shoes
    if pose == "step":
        legs = [("M98 222 L78 334", "M122 222 L140 330")]
    elif pose == "freeze":
        legs = [("M98 222 L82 336", "M122 222 L150 318")]
    else:
        legs = [("M98 222 L92 336", "M122 222 L128 336")]
    for a, b in legs:
        for d in (a, b):
            parts.append(f"<path d='{d}' stroke='{INK}' stroke-width='26' stroke-linecap='round'/>")
            parts.append(f"<path d='{d}' stroke='#20263F' stroke-width='14' stroke-linecap='round'/>")
    feet = {"step": [(72, 338), (148, 334)], "freeze": [(76, 340), (160, 322)]}.get(pose, [(86, 340), (136, 340)])
    for fx, fy in feet:
        parts.append(f"<ellipse cx='{fx}' cy='{fy}' rx='22' ry='9' fill='#20263F' {stroke(5)}/>")
    # arms behind torso
    if pose == "freeze":
        arms = ["M76 132 C52 104 40 78 34 52", "M144 132 C170 110 182 86 188 58"]
        gloves = [(32, 44), (190, 50)]
    elif pose == "shock":
        arms = ["M76 132 C54 118 44 98 40 76", "M144 132 C166 118 176 98 180 76"]
        gloves = [(38, 66), (182, 66)]
    else:
        arms = ["M78 132 C62 156 58 180 60 204", "M142 132 C158 156 162 180 160 204"]
        gloves = [(60, 212), (160, 212)]
    for d in arms:
        parts.append(f"<path d='{d}' fill='none' stroke='{INK}' stroke-width='24' stroke-linecap='round'/>")
        parts.append(f"<path d='{d}' fill='none' stroke='#FFFFFF' stroke-width='12' stroke-linecap='round'/>")
    # torso: breton stripes
    parts.append(f"<rect x='70' y='118' width='80' height='112' rx='26' fill='#FFFFFF' {s}/>")
    for y in (138, 162, 186, 210):
        parts.append(f"<path d='M74 {y} L146 {y}' stroke='{NAVY}' stroke-width='9'/>")
    parts.append(f"<rect x='70' y='118' width='80' height='112' rx='26' fill='none' {s}/>")
    parts.append(f"<path d='M88 122 L92 228 M132 122 L128 228' stroke='{CHERRY}' stroke-width='7'/>")
    # clarence peeking from the braces
    parts.append(f"<ellipse cx='136' cy='150' rx='9' ry='12' fill='#FFD23F' {stroke(3)}/>")
    parts.append(f"<path d='M133 139 L136 132 L140 139' fill='{CHERRY}' stroke='{INK}' stroke-width='2'/>")
    # gloves (huge)
    for gx, gy in gloves:
        parts.append(f"<circle cx='{gx}' cy='{gy}' r='23' fill='#FFFFFF' {s}/>")
        parts.append(f"<path d='M{gx-8} {gy-6} L{gx-8} {gy+6} M{gx} {gy-8} L{gx} {gy+6}' stroke='{INK}' stroke-width='2.5' stroke-linecap='round'/>")
    # head
    parts.append(f"<circle cx='110' cy='70' r='60' fill='{PAINT}' {s}/>")
    if pose == "shock":
        parts.append(f"<ellipse cx='88' cy='66' rx='15' ry='19' fill='#FFFFFF' {stroke(3.5)}/>")
        parts.append(f"<ellipse cx='132' cy='66' rx='15' ry='19' fill='#FFFFFF' {stroke(3.5)}/>")
        parts.append(f"<circle cx='88' cy='68' r='6' fill='{INK}'/><circle cx='132' cy='68' r='6' fill='{INK}'/>")
        parts.append(f"<ellipse cx='110' cy='104' rx='11' ry='13' fill='#7A2233' {stroke(3.5)}/>")
    elif pose == "freeze":
        parts.append(f"<path d='M78 68 L98 68 M122 68 L142 68' stroke='{INK}' stroke-width='5' stroke-linecap='round'/>")
        parts.append(f"<path d='M96 100 L124 100' stroke='{INK}' stroke-width='5' stroke-linecap='round'/>")
    else:
        parts.append(f"<ellipse cx='88' cy='66' rx='10' ry='13' fill='{INK}'/><ellipse cx='132' cy='66' rx='10' ry='13' fill='{INK}'/>")
        parts.append("<circle cx='92' cy='61' r='4' fill='#FFFFFF'/><circle cx='136' cy='61' r='4' fill='#FFFFFF'/>")
        parts.append(f"<path d='M92 96 C100 108 120 108 128 96' fill='none' stroke='{INK}' stroke-width='5' stroke-linecap='round'/>")
    parts.append("<circle cx='72' cy='88' r='10' fill='#FF9AA2'/><circle cx='148' cy='88' r='10' fill='#FF9AA2'/>")
    parts.append(f"<path d='M84 84 C82 90 86 94 88 90 C90 88 86 86 84 84 Z' fill='{NAVY}'/>")
    # beret
    parts.append(f"<path d='M58 38 C62 6 150 -2 166 30 C150 40 90 46 58 38 Z' fill='{CHERRY}' {s}/>")
    parts.append(f"<path d='M112 12 L116 2' stroke='{INK}' stroke-width='6' stroke-linecap='round'/>")
    return svg(220, 350, "".join(parts))


def bellows_body(pose):
    """Bellows body (no head), 260 x 390, feet at (130, 386)."""
    s = stroke(6)
    parts = []
    legs = [("M106 326 L100 376", "M154 326 L160 376")] if pose != "step" else [("M106 326 L88 372", "M154 326 L170 370")]
    for a, b in legs:
        for d in (a, b):
            parts.append(f"<path d='{d}' stroke='{INK}' stroke-width='28' stroke-linecap='round'/>")
            parts.append(f"<path d='{d}' stroke='#3A3050' stroke-width='16' stroke-linecap='round'/>")
    feet = [(92, 378), (168, 378)] if pose != "step" else [(80, 374), (178, 372)]
    for fx, fy in feet:
        parts.append(f"<ellipse cx='{fx}' cy='{fy}' rx='24' ry='10' fill='#B3122E' {stroke(5)}/>")
    # arms
    for d in ("M50 210 C30 240 30 270 42 292", "M210 210 C230 240 230 270 218 292"):
        parts.append(f"<path d='{d}' fill='none' stroke='{INK}' stroke-width='30' stroke-linecap='round'/>")
        parts.append(f"<path d='{d}' fill='none' stroke='{PLUM}' stroke-width='18' stroke-linecap='round'/>")
    for gx, gy in ((42, 300), (218, 300)):
        parts.append(f"<circle cx='{gx}' cy='{gy}' r='20' fill='{PEACH}' {s}/>")
    # barrel torso
    parts.append(f"<ellipse cx='130' cy='250' rx='98' ry='90' fill='{PLUM}' {s}/>")
    parts.append(f"<path d='M70 196 C90 214 170 214 190 196' fill='none' stroke='#5E2C6E' stroke-width='5'/>")
    parts.append(f"<path d='M130 176 L130 336' stroke='#5E2C6E' stroke-width='4'/>")
    for y in (236, 272, 308):
        parts.append(f"<circle cx='142' cy='{y}' r='6' fill='{GOLD}' {stroke(3)}/>")
    # cravat
    parts.append(f"<path d='M104 172 L156 172 L142 206 L130 236 L118 206 Z' fill='{GOLD}' {stroke(5)}/>")
    # specs dangling on a chain
    parts.append(f"<path d='M96 186 C104 230 156 230 164 186' fill='none' stroke='{GOLD}' stroke-width='3' stroke-dasharray='5 4'/>")
    parts.append(f"<circle cx='118' cy='222' r='10' fill='#E8F4FF' {stroke(3.5)}/><circle cx='142' cy='222' r='10' fill='#E8F4FF' {stroke(3.5)}/>")
    return svg(260, 390, "".join(parts))


def bellows_face(pose):
    """Bellows' face (tinted by temper), 260 x 200, drawn with its top at feet − 390."""
    s = stroke(6)
    parts = [f"<circle cx='130' cy='110' r='70' fill='#FFFFFF' {s}/>"]
    if pose == "shock":
        parts.append(f"<ellipse cx='106' cy='96' rx='16' ry='20' fill='#FFFFFF' {stroke(4)}/><ellipse cx='154' cy='96' rx='16' ry='20' fill='#FFFFFF' {stroke(4)}/>")
        parts.append(f"<circle cx='106' cy='98' r='5' fill='{INK}'/><circle cx='154' cy='98' r='5' fill='{INK}'/>")
        parts.append(f"<ellipse cx='130' cy='150' rx='20' ry='24' fill='#7A2233' {stroke(4.5)}/>")
        parts.append(f"<path d='M86 66 L118 76 M174 66 L142 76' stroke='{INK}' stroke-width='8' stroke-linecap='round'/>")
    else:
        parts.append(f"<circle cx='108' cy='98' r='7' fill='{INK}'/><circle cx='152' cy='98' r='7' fill='{INK}'/>")
        parts.append(f"<path d='M88 80 L122 84 M172 80 L138 84' stroke='{INK}' stroke-width='9' stroke-linecap='round'/>")
        parts.append(f"<path d='M108 150 C120 142 140 142 152 150' fill='none' stroke='{INK}' stroke-width='5.5' stroke-linecap='round'/>")
    parts.append(f"<ellipse cx='130' cy='124' rx='14' ry='11' fill='#F29C8A' {stroke(4)}/>")
    return svg(260, 200, "".join(parts))


def bellows_hair(pose, specs=False):
    """Bouffant + mutton chops (+ specs on), 260 x 200, same frame as the face."""
    s = stroke(6)
    lift = -22 if pose == "shock" else 0
    parts = [
        f"<path d='M60 {70+lift} C40 {40+lift} 70 {6+lift} 104 {16+lift} C116 {-4+lift} 150 {-4+lift} 160 {14+lift} "
        f"C196 {4+lift} 222 {40+lift} 200 {72+lift} C188 {62+lift} 168 {56+lift} 130 {58+lift} C98 {56+lift} 74 {62+lift} 60 {70+lift} Z' fill='{SILVER}' {s}/>",
        f"<path d='M74 {40+lift} C92 {30+lift} 112 {30+lift} 126 {40+lift} M140 {32+lift} C156 {26+lift} 176 {30+lift} 188 {44+lift}' fill='none' stroke='#FFFFFF' stroke-width='5' stroke-linecap='round'/>",
        f"<path d='M62 94 C44 120 52 160 80 170 C84 150 80 124 76 100 Z' fill='{SILVER}' {s}/>",
        f"<path d='M198 94 C216 120 208 160 180 170 C176 150 180 124 184 100 Z' fill='{SILVER}' {s}/>",
    ]
    if specs:
        parts.append(f"<circle cx='108' cy='98' r='18' fill='#E8F4FF' fill-opacity='0.35' {stroke(5)}/>")
        parts.append(f"<circle cx='152' cy='98' r='18' fill='#E8F4FF' fill-opacity='0.35' {stroke(5)}/>")
        parts.append(f"<path d='M126 98 L134 98' {stroke(5)}/>")
        parts.append("<path d='M96 88 L102 82 M140 88 L146 82' stroke='#FFFFFF' stroke-width='3.5' stroke-linecap='round'/>")
    return svg(260, 200, "".join(parts))


for _p in ("stand", "step", "freeze", "shock"):
    FILES[f"fallback/puppet_hush_{_p}.svg"] = hush(_p)
for _p in ("stand", "step"):
    FILES[f"fallback/puppet_bellows_body_{_p}.svg"] = bellows_body(_p)
for _p in ("stand", "shock"):
    FILES[f"fallback/puppet_bellows_face_{_p}.svg"] = bellows_face(_p)
    FILES[f"fallback/puppet_bellows_hair_{_p}.svg"] = bellows_hair(_p)
FILES["fallback/puppet_bellows_specs.svg"] = svg(260, 200,
    f"<circle cx='108' cy='98' r='18' fill='#E8F4FF' fill-opacity='0.35' {stroke(5)}/>"
    f"<circle cx='152' cy='98' r='18' fill='#E8F4FF' fill-opacity='0.35' {stroke(5)}/>"
    f"<path d='M126 98 L134 98' {stroke(5)}/>"
    "<path d='M96 88 L102 82 M140 88 L146 82' stroke='#FFFFFF' stroke-width='3.5' stroke-linecap='round'/>")


def main():
    for rel, text in FILES.items():
        p = OUT / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    print(f"wrote {len(FILES)} files under {OUT}")


if __name__ == "__main__":
    main()
