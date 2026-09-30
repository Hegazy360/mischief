#!/usr/bin/env python3
"""render_measure.py — the measured half of the set lint (r3d-tools-b §4.1; `tools/scripts/lint3d.sh --set` runs it).

Reads LintShot3D's batch manifest (`<dir>/manifest.json`: beauty / id / mask / rects PNGs per Night and room) and
measures every room with r3d-tools-a's shared toolset (`tools/art3d/review/`, index R14 — no colour maths here):
  * colour and value: `lab.regions(beauty, id, legend)` → `lab.check_rules(..., "set")` (REDESIGN §3.7) and a
    false-colour board `colour_<night>_<room>.png` (`lab.falsecolor_board`);
  * silhouettes: `sil64.run_masks(<room's live-prop masks>)` (64 px, IoU, same family ≥ 0.80) and its board
    `sil64_<night>_<room>.png`;
  * the screen-rect boards: `boards.grid` of the room's `rects_<aspect>` renders → `rects_<night>_<room>.png`.
Writes the measure file the GDScript lint reads (`--measure=`): {rooms: [{night, room, regions, rules, sil, boards}],
missing: [...]}.

usage: render_measure.py <shots dir> --review=<repo>/tools/art3d/review --boards=<docs/review/r3d-tools-b>
                         --out=<measure.json>
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("shots")
	ap.add_argument("--review", required=True)
	ap.add_argument("--boards", required=True)
	ap.add_argument("--out", required=True)
	a = ap.parse_args(argv)
	sys.path.insert(0, a.review)
	import boards  # noqa: E402
	import lab  # noqa: E402
	import sil64  # noqa: E402

	shots = Path(a.shots)
	man_p = shots / "manifest.json"
	out = {"rooms": [], "missing": []}
	if not man_p.exists():
		out["missing"].append("no LintShot3D manifest at %s" % man_p)
		Path(a.out).write_text(json.dumps(out, indent=2))
		return 0
	man = json.loads(man_p.read_text())
	bdir = Path(a.boards)
	bdir.mkdir(parents=True, exist_ok=True)
	rooms: dict[tuple[str, str], dict] = {}

	def rel(v):
		# manifest paths are absolute (LintShot3D) or relative to the manifest's folder (fixtures)
		if not v:
			return v
		q = Path(v)
		return str(q if q.is_absolute() else shots / q)

	for j in man.get("jobs", []):
		j = dict(j, png=rel(j.get("png")), legend=rel(j.get("legend")))
		key = (j["night"], j["room"])
		r = rooms.setdefault(key, {"night": j["night"], "room": j["room"], "masks": [], "rects": []})
		if j["pass"] == "beauty":
			r["beauty"] = j["png"]
			r["cam_x"] = j.get("cam_x")
		elif j["pass"] == "id":
			r["id"] = j["png"]
			r["legend"] = j.get("legend")
		elif j["pass"] == "mask":
			r["masks"].append((j.get("hotspot", Path(j["png"]).stem), j["png"]))
		elif j["pass"] == "rects":
			r["rects"].append((j.get("aspect", ""), j["png"]))
	label = {"g0_sneeze": "g0", "p00_curtain_up": "P00", "n01_throat_tea": "N01", "n02_something_fishy": "N02"}
	for (night, room), r in sorted(rooms.items()):
		tag = "%s_%s" % (label.get(night, night), room)
		row = {"night": night, "room": room, "cam_x": r.get("cam_x"), "boards": {}}
		if r.get("beauty") and r.get("id") and r.get("legend"):
			reg = lab.regions(r["beauty"], r["id"], r["legend"])
			row["regions"] = reg
			row["rules"] = lab.check_rules(reg, "set")
			fc = bdir / ("colour_%s.png" % tag)
			lab.falsecolor_board(r["beauty"], fc, id_pass=r["id"], legend=r["legend"],
								title="%s %s — L* / C* bands, region medians (REDESIGN §3.7)" % (label.get(night, night), room))
			row["boards"]["colour"] = str(fc)
		else:
			out["missing"].append("%s: beauty / id / legend missing" % tag)
		if len(r["masks"]) >= 1:
			names = [n for n, _ in r["masks"]]
			res = sil64.run_masks([Path(p) for _, p in r["masks"]], names=names)
			sb = bdir / ("sil64_%s.png" % tag)
			sil64.board(res, sb, title="%s %s — live props at 64 px (IoU ≥ 0.80 = same family)" % (label.get(night, night), room))
			res.pop("_norm", None)
			row["sil"] = res
			row["boards"]["sil64"] = str(sb)
		else:
			out["missing"].append("%s: no masks" % tag)
		if r["rects"]:
			order = {"20x9": 0, "16x9": 1, "4x3": 2}
			rs = sorted(r["rects"], key=lambda t: order.get(t[0], 9))
			rb = bdir / ("rects_%s.png" % tag)
			boards.grid([Path(p) for _, p in rs], ["%s %s %s" % (label.get(night, night), room, asp) for asp, _ in rs], rb,
						cols=len(rs), cell=(1200, 540), scale=0.5,
						title="%s %s — projected live hit boxes (W×H logical px), always-on HUD, Bellows window, safe rect" % (
							label.get(night, night), room))
			row["boards"]["rects"] = str(rb)
		out["rooms"].append(row)
	Path(a.out).write_text(json.dumps(out, indent=2))
	print("[render_measure] %d room(s) measured, %d missing -> %s" % (len(out["rooms"]), len(out["missing"]), a.out))
	return 0


if __name__ == "__main__":
	sys.exit(main())
