"""compose - quick Pillow compositor for review sheets (no Godot needed): renders a room's bg,
its props in a chosen state, decor and fg exactly where house.json places them, optionally with
the hit boxes and mock characters for scale. The Godot HousePreview scene is the real check;
this is the fast iteration loop and the source of the static review sheets."""
import json
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.join(REPO, "game")

_cache = {}


def res_path(p):
    return os.path.join(GAME, p[len("res://"):])


def raster(svg, scale=1.0):
    key = (svg, scale)
    if key in _cache:
        return _cache[key]
    fd, out = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    subprocess.check_call(["rsvg-convert", "-z", str(scale), svg, "-o", out])
    im = Image.open(out).convert("RGBA")
    os.unlink(out)
    _cache[key] = im
    return im


def pick(art, state):
    for s in ([state] if isinstance(state, str) else state) + ["idle"]:
        if s in art:
            return art[s]
    return None


def room_image(house, room_id, state="idle", rects=False, chars=False, scale=0.5, outline=False, pad_x=0):
    rooms = {r["id"]: r for r in house["rooms"]}
    r = rooms[room_id]
    fy = {f["index"]: f["y"] for f in house["floors"]}[r["floor"]]
    x0, x1 = r["x0"] - pad_x, r["x1"] + pad_x
    y0, y1 = -640, 60
    W, H = int((x1 - x0) * scale), int((y1 - y0) * scale)
    img = Image.new("RGBA", (W, H), (31, 26, 46, 255))

    def paste(svg_res, wx, wy):
        im = raster(res_path(svg_res), scale)
        img.alpha_composite(im, (int(round((wx - x0) * scale)), int(round((wy - y0) * scale))))

    for rr in house["rooms"]:
        if rr["floor"] == r["floor"] and rr["x1"] > x0 and rr["x0"] < x1:
            paste(rr["art"]["bg"], rr["x0"], -640)
    for d in house.get("decor", []):
        if rooms[d["room"]]["floor"] == r["floor"] and d.get("z", 0) < 0 and not d.get("hidden"):
            paste(pick(d["art"], state), d["pos"][0], d["pos"][1])
    for h in sorted(house["hotspots"], key=lambda q: q.get("z", 0)):
        if rooms[h["room"]]["floor"] != r["floor"] or "art" not in h:
            continue
        if outline and "outline" in h["art"]:
            paste(h["art"]["outline"], h["art_pos"][0] - 4, h["art_pos"][1] - 4)
        paste(pick(h["art"], state), h["art_pos"][0], h["art_pos"][1])
    for d in house.get("decor", []):
        if rooms[d["room"]]["floor"] == r["floor"] and d.get("z", 0) >= 0 and not d.get("hidden"):
            paste(pick(d["art"], state), d["pos"][0], d["pos"][1])
    if chars:
        dr = ImageDraw.Draw(img)
        _mock_chars(dr, house, room_id, x0, y0, scale)
    for rr in house["rooms"]:
        if rr["floor"] == r["floor"] and rr["x1"] > x0 and rr["x0"] < x1:
            paste(rr["art"]["fg"], rr["x0"], -640)
    if rects:
        dr = ImageDraw.Draw(img)
        for h in house["hotspots"]:
            if rooms[h["room"]]["floor"] != r["floor"]:
                continue
            x, y, w, hh = h["rect"]
            col = {"hiding": (60, 140, 255), "container": (255, 200, 40), "rig_point": (255, 90, 90)}.get(h["kind"], (200, 200, 200))
            dr.rectangle([(x - x0) * scale, (y - y0) * scale, (x + w - x0) * scale, (y + hh - y0) * scale], outline=col + (255,), width=2)
            dr.text(((x - x0) * scale + 3, (y - y0) * scale + 2), h["id"].split("_", 1)[1][:14], fill=(255, 255, 255, 255))
    return img


def _mock_chars(dr, house, room_id, x0, y0, s):
    """Flat silhouettes at the real sizes (Bellows 380 px, Hush 340 px) for scale/contrast checks."""
    st = [st for st in house["stations"] if st["room"] == room_id]
    if st:
        bx = st[0]["stand_x"]
        # Bellows: barrel + head + bouffant, plum/gold
        dr.ellipse([(bx - 95 - x0) * s, (-300 - y0) * s, (bx + 95 - x0) * s, (-40 - y0) * s], fill=(123, 63, 140, 255), outline=(27, 35, 64, 255), width=3)
        dr.ellipse([(bx - 70 - x0) * s, (-380 - y0) * s, (bx + 70 - x0) * s, (-240 - y0) * s], fill=(244, 201, 168, 255), outline=(27, 35, 64, 255), width=3)
        dr.ellipse([(bx - 80 - x0) * s, (-400 - y0) * s, (bx + 80 - x0) * s, (-330 - y0) * s], fill=(217, 220, 230, 255), outline=(27, 35, 64, 255), width=3)
        dr.rectangle([(bx - 50 - x0) * s, (-50 - y0) * s, (bx + 50 - x0) * s, (0 - y0) * s], fill=(58, 48, 80, 255))
    hx = [h for h in house["hotspots"] if h["room"] == room_id]
    if hx:
        x = hx[len(hx) // 2]["use_x"]
        dr.rectangle([(x - 40 - x0) * s, (-240 - y0) * s, (x + 40 - x0) * s, (-60 - y0) * s], fill=(43, 53, 102, 255), outline=(27, 35, 64, 255), width=3)
        for i in range(4):
            yy = -230 + i * 44
            dr.rectangle([(x - 40 - x0) * s, (yy - y0) * s, (x + 40 - x0) * s, (yy + 18 - y0) * s], fill=(255, 246, 234, 255))
        dr.ellipse([(x - 62 - x0) * s, (-370 - y0) * s, (x + 62 - x0) * s, (-240 - y0) * s], fill=(255, 246, 234, 255), outline=(27, 35, 64, 255), width=3)
        dr.ellipse([(x - 60 - x0) * s, (-390 - y0) * s, (x + 50 - x0) * s, (-340 - y0) * s], fill=(226, 59, 78, 255), outline=(27, 35, 64, 255), width=3)
        dr.rectangle([(x - 36 - x0) * s, (-60 - y0) * s, (x + 36 - x0) * s, (0 - y0) * s], fill=(43, 53, 102, 255))


def load_house(path=None):
    return json.load(open(path or os.path.join(GAME, "data", "house", "house.json")))
