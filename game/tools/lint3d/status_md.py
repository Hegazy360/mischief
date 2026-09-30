#!/usr/bin/env python3
"""status_md.py — the failure list per owner (`docs/review/r3d-tools-b/status.md`, index §3.3.1: it triggers the
lint fix passes). One row per failure — lint, rule, Night / room / sample, measured value, owner key — from the JSON
files `tools/scripts/lint3d.sh --json=…` / `perf3d.sh --json=…` write ({mode: {issues, …}}).

usage: status_md.py <lint json>… --out=<status.md> [--title=…] [--note=<markdown file prepended under the title>]
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import OrderedDict
from pathlib import Path

LABEL = {"g0_sneeze": "g0", "p00_curtain_up": "P00", "n01_throat_tea": "N01", "n02_something_fishy": "N02"}


def fmt(v) -> str:
	if isinstance(v, float):
		return "%g" % round(v, 3)
	if isinstance(v, list):
		return "[" + ", ".join(fmt(x) for x in v) + "]"
	return "" if v is None else str(v)


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("files", nargs="+")
	ap.add_argument("--out", required=True)
	ap.add_argument("--title", default="R3D §6.3 lint failures per owner")
	ap.add_argument("--note", default="")
	a = ap.parse_args(argv)
	rows, warns, skips, summary = [], [], [], []
	for f in a.files:
		try:
			doc = json.loads(Path(f).read_text())
		except (OSError, ValueError) as e:
			summary.append("| %s | unreadable: %s |" % (f, e))
			continue
		for mode, rep in doc.items():
			if not isinstance(rep, dict) or "issues" not in rep:
				continue
			c = rep.get("counts", {})
			summary.append("| %s | %s | %d | %d | %d |" % (mode, "PASS" if rep.get("pass") else "FAIL", c.get("error", 0),
														c.get("warning", 0), c.get("skip", 0)))
			for i in rep["issues"]:
				where = " ".join(x for x in (LABEL.get(i.get("night", ""), i.get("night", "")), i.get("room", ""),
											i.get("subject", "")) if x)
				row = "| %s | %s | %s | %s | %s | %s | %s |" % (i.get("lint", mode), i.get("rule", ""), where,
					fmt(i.get("value")), fmt(i.get("limit")), i.get("owner", ""), str(i.get("detail", "")).replace("|", "/"))
				lv = i.get("level")
				if lv == "error":
					rows.append((i.get("owner", ""), row))
				elif lv == "warning":
					warns.append((i.get("owner", ""), row))
				elif lv == "skip":
					skips.append("| %s | %s | %s | %s |" % (i.get("lint", mode), i.get("rule", ""), i.get("detail", ""),
															i.get("owner", "")))
	hdr = "| lint | rule | Night / room / sample | measured | limit | owner | detail |\n|---|---|---|---|---|---|---|"
	out = ["# %s" % a.title, ""]
	if a.note and Path(a.note).exists():
		out += [Path(a.note).read_text().rstrip(), ""]
	out += ["| mode | result | errors | warnings | skips |", "|---|---|---|---|---|"] + summary + [""]
	by_owner: OrderedDict[str, list[str]] = OrderedDict()
	for owner, r in sorted(rows, key=lambda t: t[0]):
		by_owner.setdefault(owner, []).append(r)
	out.append("## Errors by owner (%d)" % len(rows))
	for owner, rs in by_owner.items():
		out += ["", "### %s (%d)" % (owner, len(rs)), "", hdr] + rs
	out += ["", "## Warnings (%d)" % len(warns), "", hdr] + [r for _, r in sorted(warns, key=lambda t: t[0])]
	out += ["", "## Skips (%d)" % len(skips), "", "| lint | rule | what is missing | owner |", "|---|---|---|---|"] + skips
	Path(a.out).write_text("\n".join(out) + "\n")
	print("[status_md] %d error(s), %d warning(s), %d skip(s) -> %s" % (len(rows), len(warns), len(skips), a.out))
	return 0


if __name__ == "__main__":
	sys.exit(main())
