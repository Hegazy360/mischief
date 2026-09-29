#!/usr/bin/env python3
"""Build every art-hush asset: Hush + Pip SVG parts, Clarence, the hidden look, Figgis, the Stalls, and
their rig/poses/faces/stalls JSON. Deterministic and repeatable:

    python3 tools/art/hush/build.py            # writes game/art/chars/{hush,figgis,stalls} + game/data/rigs/...

Only files owned by art-hush are touched. Stale SVGs in the output folders are removed.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hush_art  # noqa: E402
import rig_hush  # noqa: E402
import poses_hush  # noqa: E402
import figgis_art  # noqa: E402
import stalls_art  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, "..", "..", "..", "game"))
OUT_HUSH = os.path.join(GAME, "art", "chars", "hush")
OUT_PIP = os.path.join(OUT_HUSH, "pip")
OUT_FIGGIS = os.path.join(GAME, "art", "chars", "figgis")
OUT_STALLS = os.path.join(GAME, "art", "chars", "stalls")
DATA = os.path.join(GAME, "data", "rigs")


def write_json(path, data):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as fh:
		json.dump(data, fh, indent=2, ensure_ascii=False)
		fh.write("\n")


def write_svgs(folder, files):
	os.makedirs(folder, exist_ok=True)
	keep = set(files)
	for name in os.listdir(folder):
		if name.endswith(".svg") and name not in keep:
			os.remove(os.path.join(folder, name))
	for name, text in files.items():
		with open(os.path.join(folder, name), "w") as fh:
			fh.write(text)


def main():
	hush = hush_art.build("hush")
	pip_all = hush_art.build("pip")
	# the Pip skin only ships files whose look differs from Hush's
	pip = {k: v for k, v in pip_all.items() if k in hush and v != hush[k]}
	write_svgs(OUT_HUSH, hush)
	write_svgs(OUT_PIP, pip)
	write_json(os.path.join(DATA, "hush", "rig.json"), rig_hush.rig(hush, pip))
	write_json(os.path.join(DATA, "hush", "faces.json"), rig_hush.faces())
	write_json(os.path.join(DATA, "hush", "poses.json"), poses_hush.poses())
	fig = figgis_art.build()
	write_svgs(OUT_FIGGIS, fig)
	write_json(os.path.join(DATA, "figgis", "rig.json"), figgis_art.rig())
	write_json(os.path.join(DATA, "figgis", "faces.json"), figgis_art.faces())
	write_json(os.path.join(DATA, "figgis", "poses.json"), figgis_art.poses())
	st, meta = stalls_art.build()
	write_svgs(OUT_STALLS, st)
	write_json(os.path.join(DATA, "stalls", "stalls.json"), meta)
	print("hush %d files, pip %d, figgis %d, stalls %d" % (len(hush), len(pip), len(fig), len(st)))


if __name__ == "__main__":
	main()
