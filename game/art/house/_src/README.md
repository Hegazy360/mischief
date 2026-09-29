# game/art/house/_src (Godot-ignored)

The house art is generated, not hand-edited. Sources live in `tools/art/house/`:

    python3 tools/art/house/build_all.py --report   # every room / prop / icon / stage SVG + game/data/house/house.json
    python3 tools/art/house/validate_svg.py          # STYLE.md §1 rules
    python3 tools/art/house/lint_rects.py            # hotspot rules (TECH §10.5)

Rules: `game/art/STYLE.md`. Layout (rooms, stations, hit boxes): `tools/art/house/geo.py`.
