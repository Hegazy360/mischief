#!/usr/bin/env python3
"""Build the 2D character art the 3D build still ships (R3D, r3d-integrate): Old Figgis's 2D rig parts + his
rig/faces/poses JSON (kept for R3's 3D-style sprite, r3d-index §5.4) and the Stalls (the crowd silhouettes +
stalls.json). Deterministic and repeatable:

    python3 tools/art/hush/build.py            # writes game/art/chars/{figgis,stalls} + game/data/rigs/{figgis,stalls}
    python3 tools/art/hush/build.py --game=DIR # the same into another copy of game/ (a staging tree)

The 2D Hush / Pip rig, their clips and Clarence's rig parts were deleted with the 2D view (the 3D cast is built by
tools/art3d/**). FiggisChip shows the R7 vinyl busts `figgis_*.svg` (game/art/chars/figgis/_src/gen_figgis.py); this
never touches them. Stale part SVGs in the output folders are removed. Validate with tools/art/hush/validate.py.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import figgis_art  # noqa: E402
import stalls_art  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, "..", "..", "..", "game"))
for _a in sys.argv[1:]:
	if _a.startswith("--game="):
		GAME = os.path.abspath(_a[len("--game="):])
OUT_FIGGIS = os.path.join(GAME, "art", "chars", "figgis")
OUT_STALLS = os.path.join(GAME, "art", "chars", "stalls")
DATA = os.path.join(GAME, "data", "rigs")
## SVGs another generator owns in the same folder (gen_figgis.py's R7 busts): never removed as stale.
FOREIGN_PREFIX = "figgis_"


def write_json(path, data):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as fh:
		json.dump(data, fh, indent=2, ensure_ascii=False)
		fh.write("\n")


def write_svgs(folder, files):
	os.makedirs(folder, exist_ok=True)
	keep = set(files)
	for name in os.listdir(folder):
		if name.endswith(".svg") and name not in keep and not name.startswith(FOREIGN_PREFIX):
			os.remove(os.path.join(folder, name))
	for name, text in files.items():
		with open(os.path.join(folder, name), "w") as fh:
			fh.write(text)


def main():
	fig = figgis_art.build()
	write_svgs(OUT_FIGGIS, fig)
	write_json(os.path.join(DATA, "figgis", "rig.json"), figgis_art.rig())
	write_json(os.path.join(DATA, "figgis", "faces.json"), figgis_art.faces())
	write_json(os.path.join(DATA, "figgis", "poses.json"), figgis_art.poses())
	st, meta = stalls_art.build()
	write_svgs(OUT_STALLS, st)
	write_json(os.path.join(DATA, "stalls", "stalls.json"), meta)
	print("figgis %d files, stalls %d" % (len(fig), len(st)))


if __name__ == "__main__":
	main()
