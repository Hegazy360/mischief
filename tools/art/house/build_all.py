#!/usr/bin/env python3
"""build_all - regenerate every house SVG + game/data/house/house.json (deterministic).

R3D: the 2D room backdrops (rooms_final / rooms_grey / rooms_upper, game/art/house/rooms/**) were deleted with the 2D
path (docs/review/r3d-integrate/reachability.md); the 3D rooms are built from game/data/house/house3d.json. The props
(hotspot icons), items, stage, activity icons and cold-open sets this builds still ship.

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

import house_json  # noqa: E402
import props_base  # noqa: E402
from svgk import write  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(REPO, "game", "art", "house")
DATA = os.path.join(REPO, "game", "data", "house", "house.json")

PROP_MODULES = ["props_kitchen", "props_hall", "props_parlour", "props_edge", "props_grey"]


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
    clean("props")
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
    for mod in ("stage", "icons_items", "icons_activities", "cold"):
        try:
            m = importlib.import_module(mod)
        except ModuleNotFoundError as e:
            if e.name != mod:
                raise
            continue
        m.build(reg)
    house = house_json.build(reg)
    house_json.dump(house, DATA)
    print("build_all: %d files, house.json %d hotspots" % (len(props_base.WRITTEN), len(house["hotspots"])))
    if report:
        for room, area in sorted(props_base.AREAS.items()):
            page = 2048 * 2048
            print("  props %-12s %5.2f MPx (states @ raster hint (default 2x) + outlines @1x; one 2048^2 page = %.2f MPx, "
                  "%3.0f %%)" % (room, area / 1e6, page / 1e6, 100.0 * area / page))
    return house


if __name__ == "__main__":
    build("--report" in sys.argv)
