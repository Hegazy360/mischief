"""sheets - review contact sheets (rsvg-convert + Pillow): icon sheets at 1x and at phone scale,
prop state sheets, the stage sheet. Used for docs/review/art-house/."""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(REPO, "game", "art")


def render(svg, scale=1.0, w=None):
    fd, out = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    cmd = ["rsvg-convert", svg, "-o", out]
    cmd += ["-w", str(w)] if w else ["-z", str(scale)]
    subprocess.check_call(cmd)
    im = Image.open(out).convert("RGBA")
    os.unlink(out)
    return im


def icon_sheet(folder, out, cell, scales=(1.0, 0.5), cols=8, bg=(236, 228, 214), bubble=False):
    files = sorted(f for f in os.listdir(folder) if f.endswith(".svg"))
    rows = (len(files) + cols - 1) // cols
    big = cell
    small = int(cell * scales[1])
    cw = big + small + 36
    ch = big + 26
    sheet = Image.new("RGBA", (cols * cw + 16, rows * ch + 16), bg + (255,))
    dr = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        x = 16 + (i % cols) * cw
        y = 16 + (i // cols) * ch
        if bubble:
            dr.ellipse([x - 8, y - 8, x + big + 8, y + big + 8], fill=(255, 255, 255, 255), outline=(27, 35, 64, 255), width=5)
        a = render(os.path.join(folder, f), w=big)
        sheet.alpha_composite(a, (x, y))
        b = render(os.path.join(folder, f), w=small)
        sheet.alpha_composite(b, (x + big + 14, y + big - small))
        dr.text((x, y + big + 6), f[:-4], fill=(27, 35, 64, 255))
    sheet.save(out)
    return out


def prop_sheet(house, room, out, scale=0.75, bg=(236, 228, 214)):
    """Every hotspot / decor sprite of a room with all its states side by side (labelled), at `scale`
    (0.5 = true 20:9 phone size at zoom 1.0)."""
    rows = []
    for h in house["hotspots"] + [dict(d, art_pos=d["pos"]) for d in house.get("decor", [])]:
        if h["room"] != room or "art" not in h:
            continue
        states = [(k, v) for k, v in h["art"].items() if k != "outline"]
        ims = [(k, render(os.path.join(REPO, "game", v[len("res://"):]), scale)) for k, v in states]
        if "outline" in h["art"]:
            ol = render(os.path.join(REPO, "game", h["art"]["outline"][len("res://"):]), scale)
            base = Image.new("RGBA", ol.size, (0, 0, 0, 0))
            tint = Image.new("RGBA", ol.size, (255, 214, 90, 255))
            base.paste(tint, (0, 0), ol.getchannel("A"))
            off = int(round(4 * scale))
            base.alpha_composite(ims[0][1], (off, off))
            ims.append(("outline", base))
        rows.append((h["id"], ims))
    pad = 14
    rh = [max(im.height for _, im in ims) + 30 for _, ims in rows]
    rw = [sum(im.width + pad for _, im in ims) + 220 for _, ims in rows]
    sheet = Image.new("RGBA", (max(rw) + pad, sum(rh) + pad), bg + (255,))
    dr = ImageDraw.Draw(sheet)
    y = pad
    for (hid, ims), h_ in zip(rows, rh):
        dr.text((pad, y + 4), hid, fill=(27, 35, 64, 255))
        x = 220
        for k, im in ims:
            sheet.alpha_composite(im, (x, y + h_ - 30 - im.height))
            dr.text((x, y + h_ - 24), k, fill=(90, 80, 110, 255))
            x += im.width + pad
        y += h_
    sheet.save(out)
    return out


def stage_sheet(out, bg=(60, 56, 72)):
    names = ["curtain", "curtain_valance", "apron", "flies", "footlight_glow", "velvet_rope", "vignette_top", "sky_left", "sky_right",
             "roof_main_l", "roof_main_r"]
    ims = [(n, render(os.path.join(ART, "house", "stage", n + ".svg"), 0.4)) for n in names]
    pros = [render(os.path.join(ART, "house", "stage", "proscenium_%s.svg" % s), 0.4) for s in "lr"]
    W = max(max(im.width for _, im in ims), 900) + 200
    H = sum(im.height + 26 for _, im in ims) + 20
    sheet = Image.new("RGBA", (W, max(H, pros[0].height + 40)), bg + (255,))
    dr = ImageDraw.Draw(sheet)
    y = 10
    for n, im in ims:
        sheet.alpha_composite(im, (10, y))
        dr.text((10, y + im.height + 4), n, fill=(255, 255, 255, 255))
        y += im.height + 26
    sheet.alpha_composite(pros[0], (W - 190, 10))
    sheet.alpha_composite(pros[1], (W - 95, 10))
    dr.text((W - 190, pros[0].height + 14), "proscenium l / r", fill=(255, 255, 255, 255))
    sheet.save(out)
    return out


if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    icon_sheet(os.path.join(ART, "house", "items"), os.path.join(out_dir, "items_sheet.png"), 128, (1.0, 0.5), cols=8)
    if os.path.isdir(os.path.join(ART, "icons", "activities")):
        icon_sheet(os.path.join(ART, "icons", "activities"), os.path.join(out_dir, "activities_sheet.png"), 88, (1.0, 0.5), cols=9, bubble=True)
    import json
    house = json.load(open(os.path.join(REPO, "game", "data", "house", "house.json")))
    for room in ("hall", "parlour", "kitchen", "landing", "bathroom", "bedroom", "dressing", "conservatory"):
        prop_sheet(house, room, os.path.join(out_dir, "props_%s_states.png" % room))
    stage_sheet(os.path.join(out_dir, "stage_sheet.png"))
