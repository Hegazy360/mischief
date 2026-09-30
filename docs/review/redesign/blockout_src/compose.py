"""Compose the REDESIGN_3D review boards (audit, before/after, HUD layout, camera section)."""
from PIL import Image, ImageDraw, ImageFont
import math, os
D = os.path.dirname(os.path.abspath(__file__))
OUT = "/home/user/mischief/docs/review/redesign"
REV = "/home/user/mischief/docs/review"
FB = "/home/user/mischief/game/ui/theme/fonts/Nunito-Black.ttf"
FD = "/home/user/mischief/game/ui/theme/fonts/LilitaOne-Regular.ttf"
def f(sz, disp=False): return ImageFont.truetype(FD if disp else FB, sz)
NAVY = (27, 35, 64); RED = (226, 59, 78); GOLD = (242, 182, 50); CREAM = (255, 246, 234); BLUE = (61, 123, 217)

# ------------------------------------------------------------------ 1. audit of the current build
im = Image.open(f"{REV}/s2-ui/night/n01_20x9.png").convert("RGB")
W, H = im.size
board = Image.new("RGB", (W, H + 330), (22, 18, 30))
board.paste(im, (0, 0))
d = ImageDraw.Draw(board)
callouts = [  # (n, x, y, box)
    (1, 880, 44, (0, 0, 1200, 92)),
    (2, 230, 88, (18, 12, 750, 76)),
    (3, 1075, 150, (962, 10, 1190, 140)),
    (4, 470, 150, (400, 80, 870, 270)),
    (5, 1000, 250, (900, 95, 1200, 418)),
    (6, 210, 440, (16, 340, 390, 515)),
    (7, 700, 520, (0, 465, 1200, 540)),
    (8, 250, 250, (100, 225, 245, 415)),
    (8, 930, 300, (812, 238, 895, 415)),
    (9, 1115, 380, (1068, 408, 1165, 505)),
]
for n, x, y, bx in callouts:
    d.rectangle(bx, outline=RED, width=3)
for n, x, y, bx in callouts:
    d.ellipse((x - 17, y - 17, x + 17, y + 17), fill=RED, outline=CREAM, width=3)
    d.text((x, y), str(n), font=f(22), fill=CREAM, anchor="mm")
legend = [
    "1  Upper floor strip (17 % of the height): bath, wardrobe, bed — not playable in Nights 1–2, noise behind the HUD row.",
    "2  Top row of 5 HUD pieces: pause, Figgis chip, 600 px brass meter (dial + 0 + 0/6), plus 3 and the overview button.",
    "3  Bellows-Cam 448×252 + overview button: on in every captured frame, often while he is already on screen.",
    "4  Kitchen: about 25 drawn objects, 11 hotspots, 4 vertical stacks; 6 look-alike badges (4 gold stars, 2 blue eyes)",
    "    float 60–100 px above their objects (the honey's star sits on the plate rack). Nothing says what a spot does.",
    "5  Locked conservatory (25 % of the width) drawn at full detail behind the velvet rope.",
    "6  Clarence + 4 EMPTY tray slots always on, sitting on the parlour floor at Bellows' feet.",
    "7  Bottom band: 11 gold footlights + apron + 24 Stalls heads — busiest strip of the screen, zero gameplay.",
    "8  Characters are 31–35 % of the height, same ink weight and saturation as the props; plum Bellows on dusty rose.",
    "9  The loudest button shows FREEZE all the time (purple, full colour), even when nothing threatens Hush.",
]
y = H + 14
d.text((16, y), "GATE-0 BUILD, NIGHT 1 (20:9, 1200×540) — WHAT CROWDS THE SCREEN", font=f(24, True), fill=GOLD)
y += 40
for line in legend:
    d.text((16, y), line, font=f(17), fill=CREAM)
    y += 27
board.save(f"{OUT}/audit_current_n01.png")

# ------------------------------------------------------------------ 2. before / after
new = Image.open(f"{D}/out/plan.png").convert("RGB")
ba = Image.new("RGB", (1200, 540 * 2 + 96), (22, 18, 30))
d = ImageDraw.Draw(ba)
d.text((16, 8), "BEFORE — Gate-0 build (2D cutout), Night 1: 9 HUD pieces always on, 31 hotspots in 3 rooms", font=f(20), fill=CREAM)
ba.paste(im, (0, 40))
d.text((16, 540 + 52), "AFTER — 3D blockout of this spec, Night 1: 4 always-on HUD pieces (+ the carried squeaker), 5 live props, characters 40–44 % tall", font=f(20), fill=GOLD)
ba.paste(new, (0, 540 + 90))
ba.save(f"{OUT}/before_after_n01.png")

# ------------------------------------------------------------------ 3. HUD layout (logical px, 20:9 and 16:9)
def hud(Wl, name, bg):
    Hl = 1080
    base = Image.open(bg).convert("RGB").resize((Wl, Hl))
    base = Image.blend(base, Image.new("RGB", (Wl, Hl), (20, 16, 28)), 0.55)
    d = ImageDraw.Draw(base)
    S = T = B = 0
    def rect(r, col, label, solid=True, w=6):
        x0, y0, x1, y1 = r
        if solid:
            d.rectangle(r, outline=col, width=w)
        else:
            L = 18
            for x in range(int(x0), int(x1), L * 2):
                d.line((x, y0, min(x + L, x1), y0), fill=col, width=4); d.line((x, y1, min(x + L, x1), y1), fill=col, width=4)
            for yy in range(int(y0), int(y1), L * 2):
                d.line((x0, yy, x0, min(yy + L, y1)), fill=col, width=4); d.line((x1, yy, x1, min(yy + L, y1)), fill=col, width=4)
        d.text((x0 + 12, y0 + 8), label, font=f(30), fill=col)
    # always-on (solid gold)
    rect((S + 24, T + 24, S + 168, T + 168), GOLD, "1")
    rect((S + 192, T + 24, S + 504, T + 168), GOLD, "2 Script chip")
    rect((S + 32, Hl - B - 200, S + 200, Hl - B - 32), GOLD, "3")
    ax, ay = Wl - S - 168, Hl - B - 168
    rect((ax - 120, ay - 120, ax + 120, ay + 120), GOLD, "4 ACTION")
    # contextual (dashed cream)
    rect((Wl / 2 - 230, T + 24, Wl / 2 + 230, T + 128), CREAM, "meter (on change, 2.5 s)", False)
    rect((Wl / 2 - 260, T + 144, Wl / 2 + 260, T + 200), CREAM, "Running Gag fuse", False)
    rect((Wl - S - 424, T + 24, Wl - S - 24, T + 249), CREAM, "Bellows window 400×225", False)
    rect((S + 224, Hl - B - 188, S + 224 + 2 * 144 + 24, Hl - B - 44), CREAM, "items", False)
    rect((S + 24, T + 192, S + 504, T + 400), CREAM, "Figgis card", False)
    rect((Wl - S - 344, T + 273, Wl - S - 24, T + 385), CREAM, "BOW (after 1st star)", False)
    rect((S + 560, Hl - B - 150, Wl - S - 440, Hl - B), (170, 160, 200), "Stalls rise here (never a target)", False)
    rect((S + 24, 430, S + 160, 650), (170, 160, 200), "edge", False)
    rect((Wl - S - 160, 430, Wl - S - 24, 650), (170, 160, 200), "edge", False)
    small = base.resize((Wl // 2, Hl // 2), Image.LANCZOS)
    out = Image.new("RGB", (Wl // 2, Hl // 2 + 44), (22, 18, 30))
    out.paste(small, (0, 0))
    dd = ImageDraw.Draw(out)
    dd.text((12, Hl // 2 + 10), f"{name}: gold = always on (4) · dashed = contextual · grey = never a target", font=f(18), fill=CREAM)
    return out
a = hud(2400, "20:9 (2400×1080 logical)", f"{D}/out/plan.png")
b = hud(1920, "16:9 (1920×1080 logical)", f"{D}/out/plan_16x9.png")
hb = Image.new("RGB", (1200, 584 * 2 + 16), (22, 18, 30))
hb.paste(a, (0, 0)); hb.paste(b, (0, 600))
hb.save(f"{OUT}/hud_layout.png")

# ------------------------------------------------------------------ 4. camera section + plan
cs = Image.new("RGB", (1200, 700), (246, 240, 228))
d = ImageDraw.Draw(cs)
# section (z horizontal: camera on the right; y up); 1 m = 60 px
ox, oy, k = 90, 330, 60
def P(z, y): return (ox + (z + 3.0) * k, oy - y * k)
# floor + back wall + ceiling
d.line([P(-2.4, 0), P(0.3, 0)], fill=(120, 80, 50), width=8)
d.line([P(-2.4, 0), P(-2.4, 3.2)], fill=(150, 130, 90), width=8)
d.line([P(-2.5, 3.2), P(0.3, 3.2)], fill=(60, 50, 70), width=6)
cam = (6.5, 1.9)
aim = (-1.0, 1.35)
pitch = math.atan2(cam[1] - aim[1], cam[0] - aim[0])
for s in (-1, 1):
    a2 = pitch + s * math.radians(15)
    z_end = -2.4
    y_end = cam[1] - (cam[0] - z_end) * math.tan(a2)
    d.line([P(*cam), P(z_end, y_end)], fill=BLUE, width=3)
d.line([P(*cam), P(*aim)], fill=(120, 150, 200), width=2)
d.ellipse([P(cam[0], cam[1])[0] - 12, P(cam[0], cam[1])[1] - 12, P(cam[0], cam[1])[0] + 12, P(cam[0], cam[1])[1] + 12], fill=NAVY)
# characters on the lane
for (z, hgt, col) in ((-1.0, 1.6, (38, 48, 94)), (-1.15, 1.78, (123, 63, 140))):
    d.rounded_rectangle([P(z - 0.18, hgt)[0], P(z, hgt)[1], P(z + 0.18, 0)[0], P(z, 0)[1]], radius=10, fill=col)
T2 = f(20)
d.text(P(6.5, 2.4), "camera: y 1.9 m, 7.5 m from the lane,\nFOV 30° vertical, pitch −4.2°", font=T2, fill=NAVY)
d.text(P(-2.35, 4.2), "back wall z −2.4 (8.9 m from camera): 1 m = 226 px", font=T2, fill=NAVY)
d.text(P(-1.6, -0.35), "lane z −1.0 (7.5 m): 1 m = 269 px", font=T2, fill=NAVY)
d.line([P(0.25, 0), P(0.25, -0.3)], fill=(200, 150, 60), width=6)
d.text(P(0.4, -0.05), "stage lip z +0.25", font=T2, fill=NAVY)
d.text((20, 18), "CAMERA SECTION (side view of the set; px are logical px of a 1080-tall screen)", font=f(24, True), fill=NAVY)
d.text((20, 400), "Hush 1.60 m = 434 px (40 %)   Bellows 1.78 m = 471 px (44 %)   visible height at the lane 4.02 m", font=f(22), fill=NAVY)
# plan view
d.text((20, 450), "PLAN: visible width at the lane — 20:9 = 8.93 m · 16:9 = 7.15 m · 4:3 tablet = 5.36 m", font=f(22), fill=NAVY)
rooms = [("porch", 0, 2.5), ("hall", 2.5, 7.5), ("parlour", 7.5, 14.0), ("kitchen", 14.0, 19.5)]
sx, sy, kk = 40, 560, 58
for name, x0, x1 in rooms:
    d.rectangle([sx + x0 * kk, sy, sx + x1 * kk, sy + 60], outline=NAVY, width=3, fill=(230, 222, 200))
    d.text((sx + (x0 + x1) / 2 * kk, sy + 30), f"{name} {x1 - x0:.1f} m", font=f(20), fill=NAVY, anchor="mm")
cx = 15.33
for wv, col, lab in ((8.93, BLUE, "20:9"), (7.15, RED, "16:9")):
    x0, x1 = cx - wv / 2, cx + wv / 2
    d.rectangle([sx + x0 * kk, sy - 14 - (0 if lab == "20:9" else 14), sx + x1 * kk, sy - 6 - (0 if lab == "20:9" else 14)], fill=col)
    d.text((sx + x0 * kk - 50, sy - 24 - (0 if lab == "20:9" else 14)), lab, font=f(18), fill=col)
d.text((40, 640), "Kitchen framed at camera x 15.33 (clamped: ≤ 0.3 m of unbuilt set shows past the kitchen's right wall).", font=f(20), fill=NAVY)
cs.save(f"{OUT}/camera_section.png")
print("ok")
