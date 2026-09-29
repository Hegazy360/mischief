#!/usr/bin/env python3
"""build_all - regenerate every house SVG + game/data/house/house.json (deterministic).

    python3 tools/art/house/build_all.py            # everything
    python3 tools/art/house/build_all.py --report   # + per-room prop atlas budget

Then: python3 tools/art/house/validate_svg.py && python3 tools/art/house/lint_rects.py
"""
import importlib
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import geo  # noqa: E402
import house_json  # noqa: E402
import props_base  # noqa: E402
from svgk import write  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(REPO, "game", "art", "house")
DATA = os.path.join(REPO, "game", "data", "house", "house.json")

PROP_MODULES = ["props_kitchen", "props_hall", "props_parlour", "props_grey"]
ROOM_MODULES = ["rooms_final", "rooms_grey"]


def clean(sub):
    """Remove previously generated SVGs of a folder (keeps any .import sidecars' SVGs regenerated)."""
    d = os.path.join(ART, sub)
    if not os.path.isdir(d):
        return
    for f in os.listdir(d):
        if f.endswith(".svg"):
            os.unlink(os.path.join(d, f))


def build(report=False):
    reg = house_json.Registry()
    for sub in ("props", "rooms"):
        clean(sub)
    # rooms
    done = set()
    for mod in ROOM_MODULES:
        try:
            m = importlib.import_module(mod)
        except ModuleNotFoundError as e:
            if e.name != mod:
                raise
            continue
        for rid, fn in m.ROOMS.items():
            rm = fn()
            p = write(os.path.join(ART, "rooms", rid + "_bg.svg"), rm.svg_bg())
            props_base.WRITTEN.append((p, "rooms"))
            p = write(os.path.join(ART, "rooms", rid + "_fg.svg"), rm.svg_fg())
            props_base.WRITTEN.append((p, "rooms_fg"))
            done.add(rid)
    # props
    for mod in PROP_MODULES:
        try:
            m = importlib.import_module(mod)
        except ModuleNotFoundError as e:
            if e.name != mod:
                raise
            continue
        m.build(reg)
    # stage, items, activity icons
    for mod in ("stage", "icons_items", "icons_activities"):
        try:
            m = importlib.import_module(mod)
        except ModuleNotFoundError as e:
            if e.name != mod:
                raise
            continue
        m.build(reg)
    house = house_json.build(reg)
    house_json.dump(house, DATA)
    missing = [r[0] for r in geo.ROOMS if r[0] not in done]
    print("build_all: %d files, rooms %d/%d%s, house.json %d hotspots" % (
        len(props_base.WRITTEN), len(done), len(geo.ROOMS), (" (missing %s)" % ", ".join(missing)) if missing else "",
        len(house["hotspots"])))
    if report:
        for room, area in sorted(props_base.AREAS.items()):
            print("  props %-12s %5.2f MPx (states @2x + outlines @1x; one 2048^2 page = 4.19 MPx)" % (room, area / 1e6))
    return house


if __name__ == "__main__":
    build("--report" in sys.argv)
