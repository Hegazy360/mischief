"""Compose the look-dev boards (labels in the game's fonts: Lilita One + Nunito, OFL)."""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont
R = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(R, "out")
FD = "/home/user/mischief/game/ui/theme/fonts"
TITLE = ImageFont.truetype(os.path.join(FD, "LilitaOne-Regular.ttf"), 44)
H2 = ImageFont.truetype(os.path.join(FD, "LilitaOne-Regular.ttf"), 30)
LAB = ImageFont.truetype(os.path.join(FD, "Nunito-ExtraBold.ttf"), 22)
SMALL = ImageFont.truetype(os.path.join(FD, "Nunito-Bold.ttf"), 18)
BG = (46, 37, 64)
INK = (255, 240, 214)
DIM = (190, 176, 210)


def board(w, h, title, sub=""):
    im = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(im)
    d.text((28, 18), title, font=TITLE, fill=INK)
    if sub:
        d.text((30, 70), sub, font=SMALL, fill=DIM)
    return im, d


def turnaround(dst):
    a = Image.open(os.path.join(OUT, "turn_final_hush.png")).convert("RGB")
    b = Image.open(os.path.join(OUT, "turn_final_bellows.png")).convert("RGB")
    W = a.width
    ya, yb = 170, 170 + a.height + 110
    im, d = board(W, yb + b.height + 40, "Toy Box — turnaround",
                  "Godot 4.7 Compatibility (GLES3), toy shader + 2.4 px outline, same key light as the diorama. Idle clip, frame 0.")
    im.paste(a, (0, ya))
    im.paste(b, (0, yb))
    ppm = 640 / 1.95
    for i, lab in enumerate(["front", "3/4", "side", "back"]):
        x = int(W / 2 + (-1.95 + 1.3 * i) * ppm)
        tw = d.textlength(lab, font=LAB)
        d.text((x - tw / 2, ya + a.height - 8), lab, font=LAB, fill=DIM)
        d.text((x - tw / 2, yb + b.height - 8), lab, font=LAB, fill=DIM)
    d.text((28, ya - 60), "HUSH", font=H2, fill=(226, 59, 78))
    d.text((140, ya - 52), HUSH_SUB, font=SMALL, fill=DIM)
    d.text((28, yb - 60), "HORACE BELLOWS", font=H2, fill=(232, 179, 58))
    d.text((300, yb - 52), BELL_SUB, font=SMALL, fill=DIM)
    im.save(dst)


HUSH_SUB = "street mime · 1.58 m to the beret · ~2.5 heads · 14.5k tris · 68 bones (UAL 65 + 3)"
BELL_SUB = "retired baritone · 1.74 m to the bouffant · ~2.2 heads · 15.0k tris · 75 bones (UAL 65 + 10)"


def expressions(dst):
    rows = [("hush", ["neutral", "sneaky", "shock", "furious", "sneeze_build", "dazed"],
             ["neutral", "sneaky grin", "shock", "furious", "sneeze build", "dazed"], "HUSH", (226, 59, 78)),
            ("bellows", ["neutral", "pompous", "shock", "furious", "sneeze_build", "dazed"],
             ["neutral", "pompous", "shock (specs on)", "furious (temper tint)", "sneeze build", "dazed"], "HORACE BELLOWS", (232, 179, 58))]
    cw, chh = 400, 400
    im, d = board(cw * 6 + 40, 110 + 2 * (chh + 90), "Toy Box — expressions",
                  "Swappable face decals: 4 layers (brows / eyes / mouth / extra) picked from one 1024² atlas per character; temper = skin tint; specs + sideburns = bones.")
    y = 110
    for who, names, labels, title, col in rows:
        d.text((24, y), title, font=H2, fill=col)
        y += 40
        for i, (n, l) in enumerate(zip(names, labels)):
            h = Image.open(os.path.join(OUT, "heads_" + who, n + ".png")).convert("RGB").resize((cw, chh), Image.LANCZOS)
            x = 20 + i * cw
            im.paste(h, (x, y))
            tw = d.textlength(l, font=LAB)
            d.text((x + cw / 2 - tw / 2, y + chh + 4), l, font=LAB, fill=INK)
        y += chh + 50
    # phone-size inset: the same faces at in-game head size (~70 px)
    im.save(dst)


def grid(dst, title, sub, cells, cols, cw, chh):
    rows = (len(cells) + cols - 1) // cols
    im, d = board(cols * cw + (cols + 1) * 16, 110 + rows * (chh + 44), title, sub)
    for i, (path, lab) in enumerate(cells):
        c, r = i % cols, i // cols
        x, y = 16 + c * (cw + 16), 110 + r * (chh + 44)
        t = Image.open(path).convert("RGB")
        t = t.resize((cw, int(t.height * cw / t.width)), Image.LANCZOS)
        im.paste(t.crop((0, 0, cw, chh)), (x, y))
        d.text((x + 6, y + chh + 6), lab, font=LAB, fill=INK)
    im.save(dst)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "turnaround":
        turnaround(sys.argv[2])
    elif what == "expressions":
        expressions(sys.argv[2])
    elif what == "grid":
        spec = json.load(open(sys.argv[2]))
        grid(spec["out"], spec["title"], spec.get("sub", ""), spec["cells"], spec["cols"], spec["cw"], spec["ch"])
