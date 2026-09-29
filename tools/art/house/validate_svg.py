#!/usr/bin/env python3
"""validate_svg - the SVG rules of game/art/STYLE.md §1 for every file under game/art/house/** and
game/art/icons/**.

Checks: well-formed XML; the root header (width/height = integer px = viewBox); only the allowed
elements (svg defs g path rect circle ellipse line polyline polygon linearGradient radialGradient
stop); no style/class/filter/mask/clip-path/href/<text>/<image>/<use>; gradients only in rooms/ and
stage/; <= 10 distinct colours per sprite (props, items, icons); outline sprites (*_ol.svg) are flat
white; numbers have <= 1 decimal; the canvas size matches its kind (room = width x 700, item 128,
activity icon 88); the 3 px canvas margin is empty (rendered alpha, sprites only); file size caps.
Exit 1 on any error. Usage: python3 tools/art/house/validate_svg.py [--no-render]
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.join(REPO, "game")
ROOTS = [os.path.join(GAME, "art", "house"), os.path.join(GAME, "art", "icons")]
NS = "{http://www.w3.org/2000/svg}"
ALLOWED = {"svg", "defs", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "linearGradient", "radialGradient", "stop"}
BAD_ATTR = {"style", "class", "filter", "mask", "clip-path", "href", "{http://www.w3.org/1999/xlink}href"}
MAX_COLOURS = 10
SIZE_CAP = {"props": 48 * 1024, "items": 16 * 1024, "icons": 16 * 1024, "rooms": 120 * 1024, "stage": 160 * 1024}
NUM = re.compile(r"-?\d+\.(\d+)")
HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")


def kind_of(path):
    rel = os.path.relpath(path, os.path.join(GAME, "art"))
    parts = rel.split(os.sep)
    if parts[0] == "icons":
        return "icons"
    if parts[0] == "house" and len(parts) > 1:
        return parts[1]          # rooms | props | stage | items | _src
    return "other"


def room_widths():
    h = json.load(open(os.path.join(GAME, "data", "house", "house.json")))
    return {r["id"]: r["x1"] - r["x0"] for r in h["rooms"]}


def check_file(path, widths, render=True, tmp=None):
    errs = []
    kind = kind_of(path)
    name = os.path.basename(path)
    txt = open(path).read()
    try:
        root = ET.fromstring(txt)
    except ET.ParseError as e:
        return ["%s: XML parse error %s" % (name, e)]
    m = re.match(r'<svg xmlns="http://www.w3.org/2000/svg" width="(\d+)" height="(\d+)" viewBox="0 0 (\d+) (\d+)">', txt)
    if not m or m.group(1) != m.group(3) or m.group(2) != m.group(4):
        errs.append("%s: root header must be <svg xmlns=... width=W height=H viewBox=\"0 0 W H\"> with integer px" % name)
        return errs
    w, h = int(m.group(1)), int(m.group(2))
    grads = 0
    for el in root.iter():
        tag = el.tag.replace(NS, "")
        if tag not in ALLOWED:
            errs.append("%s: element <%s> not allowed" % (name, tag))
        for a in el.attrib:
            if a in BAD_ATTR:
                errs.append("%s: attribute %s not allowed" % (name, a))
        if tag in ("linearGradient", "radialGradient"):
            grads += 1
    if grads and kind not in ("rooms", "stage"):
        errs.append("%s: gradients are only for rooms/stage (walls, sky, glows)" % name)
    for mm in NUM.finditer(re.sub(r'transform="[^"]*"', "", txt)):
        if len(mm.group(1)) > 1:
            errs.append("%s: number %s has more than 1 decimal" % (name, mm.group(0)))
            break
    cols = set(c.upper() for c in HEX.findall(txt))
    if name.endswith("_ol.svg"):
        if cols - {"#FFFFFF"}:
            errs.append("%s: outline sprite must be flat white, has %s" % (name, sorted(cols)))
    elif kind in ("props", "items", "icons") and len(cols) > MAX_COLOURS:
        errs.append("%s: %d colours > %d" % (name, len(cols), MAX_COLOURS))
    cap = SIZE_CAP.get(kind)
    if cap and len(txt.encode()) > cap:
        errs.append("%s: %d bytes > %d" % (name, len(txt.encode()), cap))
    if kind == "rooms":
        rid = name.rsplit("_", 1)[0]
        if rid in widths and (w, h) != (widths[rid], 700):
            errs.append("%s: canvas %dx%d, room %s needs %dx700" % (name, w, h, rid, widths[rid]))
    elif kind == "items" and (w, h) != (128, 128):
        errs.append("%s: item icons are 128x128 (got %dx%d)" % (name, w, h))
    elif kind == "icons" and (w, h) != (88, 88):
        errs.append("%s: activity icons are 88x88 (got %dx%d)" % (name, w, h))
    if render and kind in ("props", "items", "icons"):
        errs += margin_check(path, name, w, h, tmp)
    return errs


def margin_check(path, name, w, h, tmp):
    from PIL import Image
    out = os.path.join(tmp, "m.png")
    subprocess.check_call(["rsvg-convert", path, "-o", out])
    im = Image.open(out).convert("RGBA")
    a = im.getchannel("A")
    px = a.load()
    W, H = im.size
    for y in range(H):
        for x in list(range(0, 3)) + list(range(W - 3, W)) if 3 <= y < H - 3 else range(W):
            if px[x, y] > 8:
                return ["%s: ink/outline inside the 3 px canvas margin at (%d, %d)" % (name, x, y)]
    return []


def main(argv):
    render = "--no-render" not in argv
    widths = room_widths()
    errs = []
    n = 0
    by_kind = {}
    with tempfile.TemporaryDirectory() as tmp:
        for root in ROOTS:
            for dp, dns, fns in os.walk(root):
                if "_src" in dp.split(os.sep):
                    continue
                for f in sorted(fns):
                    if f.endswith(".svg"):
                        p = os.path.join(dp, f)
                        n += 1
                        k = kind_of(p)
                        by_kind[k] = by_kind.get(k, 0) + 1
                        errs += check_file(p, widths, render, tmp)
    for e in errs:
        print("FAIL", e)
    print("validate_svg: %d files (%s) - %s" % (n, ", ".join("%s %d" % kv for kv in sorted(by_kind.items())),
                                                 "OK" if not errs else "%d errors" % len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
