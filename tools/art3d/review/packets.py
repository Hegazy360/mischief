#!/usr/bin/env python3
"""Opaque reviewer packets and their scoring (Stage-2 ruling L10; index R17 — the orchestrator runs a fresh reviewer on
`prompt.md` when a task cannot spawn one).

usage:
  packets.py build <out dir> --items=<a.png,b.png,…|dir> --key=/abs/KEY.json [--kind=frames|strips|crops|pairs]
                   [--seed=S] [--names=a,b,…] [--question="…"] [--format=free|choice|yesno|ab|scores]
                   [--choices=a,b,…|@/abs/list.txt] [--scores=funny,readable,fresh] [--expected=<answer for all>]
                   [--aliases=/abs/aliases.json] [--context="…"] [--sep=,] [--force]
  packets.py score <KEY.json> <answers.md> [--out=/abs/verdict.md] [--json=/abs.json] [--bar=N]

build — copies each item under an opaque id `pkt_01`, `pkt_02` … in a seeded shuffled order, re-encoded without
metadata; a directory item (a multi-page strip, a strip + contact sheet) becomes a folder `pkt_XX/page_1.jpg` …;
`--kind=pairs` takes `ref.png:cand.png` items and composes one image per pair with the two sides labelled A and B in
random order (the expected answer is the candidate's side). Writes `<out dir>/prompt.md` (the question, the answer
format, "answer each id; do not guess from file names or order") and the answer key to `--key`, which must lie
OUTSIDE the packet dir. It refuses to write a packet that leaks an item name or a source file name into the packet
dir (file names, prompt text — choices excepted) and refuses a non-empty packet dir unless --force.
Names default to the file stems (the directory name for a folder item); `expected` defaults to the name
(or --expected for all, e.g. "no" for "is this screen crowded?").

score — reads the reviewer's answers (`pkt_01: <answer>` lines; markdown bullets, bold ids and table rows
`| pkt_01 | … |` also parse) and writes the verdict table: per id the key, the answer verbatim and correct /
confused (with what) / unmatched (needs a human) / missing; the confused pairs; for `scores` the numbers per field
(mean, min; `--bar` flags items under it).
Matching (free / choice): answer words are lower-cased and stemmed (sneaking = sneak, diving = dive, running = run);
a candidate (every item's name + aliases + the choices) is named when all its words appear; the FIRST candidate
named in the answer is the reviewer's answer. Importable: `build`, `score`, `parse_answers`.
"""
from __future__ import annotations

import argparse
import random
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as cm  # noqa: E402
import boards  # noqa: E402

KINDS = ("frames", "strips", "crops", "pairs")
FORMATS = ("free", "choice", "yesno", "ab", "scores")
DEFAULT_QUESTION = {
	"frames": "What is happening in this frame? Answer in a few words.",
	"strips": "What happens in this sequence? Answer in a few words.",
	"crops": "Which of the listed names fits this picture best?",
	"pairs": "Which of the two frames, A or B, reads better on a phone held sideways?",
}
KIND_TEXT = {
	"frames": "Each item is one frame of a phone game held sideways (1200×540).",
	"strips": "Each item is a numbered strip of frames from a phone game held sideways: read the cells left to right, "
				"top to bottom; the numbers printed on the cells are frame numbers (60 frames = 1 second).",
	"crops": "Each item is an unlabelled crop from a phone game.",
	"pairs": "Each item shows two frames of the same moment side by side, labelled A (left) and B (right).",
}
FORMAT_TEXT = {
	"free": "pkt_01: <your answer in a few words>",
	"choice": "pkt_01: <one name from the list>",
	"yesno": "pkt_01: yes | no — <one sentence why>",
	"ab": "pkt_01: A | B — <one sentence why>",
	"scores": "pkt_01: {fields} — <one sentence, citing frame numbers>",
}


# --- words -----------------------------------------------------------------------------------------------------------

def stem(w: str) -> str:
	w = w.lower()
	for suf in ("ing", "ed", "es", "s"):
		if w.endswith(suf) and len(w) - len(suf) >= 3:
			w = w[: -len(suf)]
			break
	if len(w) >= 4 and w[-1] == w[-2] and w[-1] not in "lsz":
		w = w[:-1]
	if len(w) >= 4 and w.endswith("e"):
		w = w[:-1]
	return w


def words(text: str) -> list[str]:
	return [stem(t) for t in re.split(r"[^0-9A-Za-z]+", text) if t]


def _find(cand_words: list[str], ans_words: list[str]) -> int:
	"""Position of the first answer word of `cand_words` when every candidate word appears in the answer, else -1."""
	if not cand_words:
		return -1
	pos = []
	for cw in cand_words:
		try:
			pos.append(ans_words.index(cw))
		except ValueError:
			return -1
	return min(pos)


# --- build -----------------------------------------------------------------------------------------------------------

def _copy_image(src: Path, dst: Path) -> None:
	"""Re-encode (drops text chunks, EXIF, ICC names) so no metadata can carry a name."""
	with Image.open(src) as im:
		data = im.convert("RGBA") if im.mode in ("RGBA", "LA", "P") else im.convert("RGB")
		clean = Image.new(data.mode, data.size)
		clean.paste(data)
	cm.save_image(clean if dst.suffix.lower() == ".png" else clean.convert("RGB"), dst, quality=90)


def _leak_tokens(names: list[str], sources: list[Path]) -> list[str]:
	toks = set()
	for n in names:
		if len(n) >= 4:
			toks.add(n.lower())
	for s in sources:
		st = s.stem.lower()
		if len(st) >= 4:
			toks.add(st)
	return sorted(toks)


def _contains_phrase(text: str, phrase: str) -> bool:
	t = " " + " ".join(re.split(r"[^0-9a-z]+", text.lower())) + " "
	p = " " + " ".join(re.split(r"[^0-9a-z]+", phrase.lower())).strip() + " "
	return p.strip() != "" and p in t


def build(out_dir, items: list[str], key_path, kind: str = "frames", seed: int = 1, names: list[str] | None = None,
		question: str | None = None, fmt: str | None = None, choices: list[str] | None = None,
		score_fields: list[str] | None = None, expected: str | None = None, aliases: dict | None = None,
		context: str = "", force: bool = False) -> dict:
	"""Write the packet dir + prompt.md and the key; returns the key dict."""
	out = Path(out_dir).resolve()
	key_p = Path(key_path).resolve()
	if kind not in KINDS:
		raise ValueError("kind must be one of %s" % (KINDS,))
	if out == key_p.parent or out in key_p.parents:
		raise ValueError("the key %s must lie outside the packet dir %s" % (key_p, out))
	if out.exists() and any(out.iterdir()):
		if not force:
			raise ValueError("packet dir %s is not empty (use --force to replace its packets)" % out)
		for p in out.iterdir():
			if p.name.startswith("pkt_") or p.name == "prompt.md":
				shutil.rmtree(p) if p.is_dir() else p.unlink()
		left = [p.name for p in out.iterdir()]
		if left:
			raise ValueError("packet dir %s holds other files (%s); use an empty dir" % (out, ", ".join(left)))
	fmt = fmt or {"pairs": "ab", "crops": "choice"}.get(kind, "free")
	if fmt not in FORMATS:
		raise ValueError("format must be one of %s" % (FORMATS,))
	if fmt == "scores" and not score_fields:
		score_fields = ["funny", "readable", "fresh"]
	if question is None and fmt == "scores":
		question = ("Score each item 1–5 on %s. What happens, and what would make it funnier?"
					% ", ".join(score_fields))
	# items → sources
	srcs: list[list[Path]] = []
	for it in items:
		if kind == "pairs":
			a, b = it.split(":", 1) if ":" in it else (None, None)
			if a is None:
				raise ValueError("pairs items are ref.png:cand.png, got %r" % it)
			srcs.append([Path(a), Path(b)])
		else:
			srcs.append([Path(it)])
	for group in srcs:
		for p in group:
			if not p.exists():
				raise ValueError("missing item %s" % p)
	if names is None:
		names = [g[-1].stem if g[-1].is_file() else g[-1].name for g in srcs]
	if len(names) != len(srcs):
		raise ValueError("%d names for %d items" % (len(names), len(srcs)))
	rng = random.Random(seed)
	order = list(range(len(srcs)))
	rng.shuffle(order)
	width = max(2, len(str(len(srcs))))
	choices_sorted = sorted(set(choices), key=str.lower) if choices else []
	# plan first (ids, file names, the prompt), check for leaks, and only then write anything
	plan = []
	for n_i, src_i in enumerate(order, start=1):
		pid = "pkt_%0*d" % (width, n_i)
		group = srcs[src_i]
		row = {"id": pid, "name": names[src_i], "expected": expected if expected is not None else names[src_i],
				"aliases": list((aliases or {}).get(names[src_i], []))}
		if kind == "pairs":
			row["file"] = pid + ".png"
			row["_side"] = rng.choice(["A", "B"])
		elif group[0].is_dir():
			pages = cm.list_images(group[0])
			if not pages:
				raise ValueError("item folder %s holds no images" % group[0])
			row["file"] = pid + "/"
			row["pages"] = ["%s/page_%d%s" % (pid, k, pg.suffix.lower()) for k, pg in enumerate(pages, start=1)]
			row["_pages"] = pages
		else:
			row["file"] = pid + group[0].suffix.lower()
		plan.append((row, group))
	plan.sort(key=lambda x: x[0]["id"])
	all_sources = [p for _, g in plan for p in g] + [p for r, _ in plan for p in r.get("_pages", [])]
	prompt = _prompt(out, [r for r, _ in plan], kind, fmt, question or DEFAULT_QUESTION[kind], choices_sorted,
					score_fields, context)
	leaks = []
	body = prompt.split("## Choices")[0] + (prompt.split("## Answer format")[1] if "## Answer format" in prompt else "")
	low_choices = [c.lower() for c in choices_sorted]
	for tok in _leak_tokens(names, all_sources):
		if tok not in low_choices and _contains_phrase(body, tok):
			leaks.append("prompt mentions %r" % tok)
		for r, _ in plan:
			for fname in [r["file"]] + r.get("pages", []):
				if _contains_phrase(fname, tok):
					leaks.append("file name %s contains %r" % (fname, tok))
	if leaks:
		raise ValueError("packet would leak names: %s" % "; ".join(sorted(set(leaks))))
	out.mkdir(parents=True, exist_ok=True)
	key_items = []
	for row, group in plan:
		pid = row["id"]
		if kind == "pairs":
			ref, cand = group
			side = row.pop("_side")
			left, right = (cand, ref) if side == "A" else (ref, cand)
			boards.grid([left, right], ["A", "B"], out / row["file"], cols=2)
			row.update({"A": str(left.resolve()), "B": str(right.resolve()), "candidate": str(cand.resolve()),
						"reference": str(ref.resolve())})
			if expected is None:
				row["expected"] = side
		elif "pages" in row:
			(out / pid).mkdir()
			for pg, rel in zip(row.pop("_pages"), row["pages"]):
				_copy_image(pg, out / rel)
			row["source"] = str(group[0].resolve())
		else:
			_copy_image(group[0], out / row["file"])
			row["source"] = str(group[0].resolve())
		key_items.append(row)
	(out / "prompt.md").write_text(prompt, encoding="utf-8")
	key = {"version": 1, "tool": "tools/art3d/review/packets.py", "kind": kind, "seed": seed,
			"created": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "packet_dir": str(out),
			"prompt": str(out / "prompt.md"), "question": question or DEFAULT_QUESTION[kind], "answer_format": fmt,
			"choices": choices_sorted, "score_fields": score_fields or [], "items": key_items}
	cm.write_json(key_p, key)
	return key


def _prompt(out: Path, items: list[dict], kind: str, fmt: str, question: str, choices: list[str],
			fields: list[str] | None, context: str) -> str:
	ids = [r["id"] for r in items]
	lines = ["# Review packet", "",
			"You are a fresh reviewer: you have not seen this game, its design notes or its file names. %s" % KIND_TEXT[kind],
			""]
	if context:
		lines += [context, ""]
	lines += ["Packet folder: `%s`" % out, "", "## Items", ""]
	for r in items:
		if "pages" in r:
			lines.append("- `%s` — %s" % (r["id"], ", ".join("`%s`" % p for p in r["pages"])))
		else:
			lines.append("- `%s` — `%s`" % (r["id"], r["file"]))
	lines += ["", "## Question", "", question, ""]
	if choices:
		lines += ["## Choices", "", "Pick from this list (alphabetical; some may fit no item, one may fit several):", ""]
		lines += ["- %s" % c for c in choices]
		lines.append("")
	lines += ["## Answer format", "", "One line per id, exactly like this:", "", "```"]
	tmpl = FORMAT_TEXT[fmt].format(fields=" ".join("%s=<1-5>" % f for f in (fields or [])))
	lines.append(tmpl)
	for i in ids[1:3]:
		lines.append(tmpl.replace("pkt_01", i, 1))
	lines += ["…", "```", "",
			"Rules: answer every id (%s); judge only what you see; do not guess from file names, ids or their order; "
			"if unsure give your best guess and add \"(unsure)\"." % ", ".join(ids), ""]
	if fmt == "scores":
		lines += ["Scores: 1 = bad, 3 = OK, 5 = great. Cite frame numbers for what you judged.", ""]
	return "\n".join(lines)


# --- score -----------------------------------------------------------------------------------------------------------

_ID = re.compile(r"(pkt_\d+)", re.I)


def parse_answers(text: str) -> dict[str, str]:
	"""`pkt_XX` → the answer text (first line naming the id wins)."""
	out: dict[str, str] = {}
	for raw in text.splitlines():
		m = _ID.search(raw)
		if not m:
			continue
		pid = m.group(1).lower()
		if pid in out:
			continue
		rest = raw[m.end():]
		if raw.lstrip().startswith("|"):
			cells = [c.strip() for c in raw.strip().strip("|").split("|")]
			idx = next((k for k, c in enumerate(cells) if _ID.search(c)), 0)
			rest = " | ".join(c for c in cells[idx + 1:] if c)
		rest = re.sub(r"^[\s*_`:=|\-–—.)\]]+", "", rest).strip()
		rest = rest.strip("* ").strip()
		out[pid] = rest
	return out


def _ab(ans: str) -> str | None:
	m = re.search(r"\b([AB])\b", ans)
	if m:
		return m.group(1)
	m = re.search(r"\b(left|right)\b", ans, re.I)
	if m:
		return "A" if m.group(1).lower() == "left" else "B"
	m = re.search(r"\b([ab])\b", ans)
	return m.group(1).upper() if m else None


def _yesno(ans: str) -> str | None:
	m = re.search(r"\b(yes|no)\b", ans, re.I)
	return m.group(1).lower() if m else None


def score(key, answers, bar: float | None = None) -> dict:
	"""Score an answer sheet (text or path) against a key (dict or path)."""
	k = cm.read_json(key) if isinstance(key, (str, Path)) else key
	text = Path(answers).read_text(encoding="utf-8") if isinstance(answers, Path) or (
		isinstance(answers, str) and "\n" not in answers and Path(answers).exists()) else str(answers)
	ans = parse_answers(text)
	fmt = k["answer_format"]
	cands: dict[str, list[list[str]]] = {}
	for it in k["items"]:
		for c in [it["expected"], it["name"]] + list(it.get("aliases", [])):
			cands.setdefault(it["expected"], []).append(words(c))
	for c in k.get("choices", []):
		cands.setdefault(c, []).append(words(c))
	rows = []
	for it in k["items"]:
		pid = it["id"]
		a = ans.get(pid)
		row = {"id": pid, "name": it["name"], "expected": it["expected"], "answer": a, "given": None}
		if a is None:
			row["verdict"] = "missing"
		elif fmt in ("free", "choice"):
			aw = words(a)
			best, best_pos, best_len = None, 10 ** 9, 0
			for canon, variants in cands.items():
				for v in variants:
					p = _find(v, aw)
					if p < 0:
						continue
					if p < best_pos or (p == best_pos and len(v) > best_len):
						best, best_pos, best_len = canon, p, len(v)
			row["given"] = best
			row["verdict"] = "unmatched" if best is None else ("correct" if best == it["expected"] else "confused")
		elif fmt == "yesno":
			g = _yesno(a)
			row["given"] = g
			row["verdict"] = "unmatched" if g is None else ("correct" if g == str(it["expected"]).lower()
															else "confused")
		elif fmt == "ab":
			g = _ab(a)
			row["given"] = g
			row["verdict"] = "unmatched" if g is None else ("correct" if g == str(it["expected"]).upper()
															else "confused")
		elif fmt == "scores":
			sc = {}
			for f in k.get("score_fields", []):
				m = re.search(r"\b%s\w*\s*[=:]?\s*(\d+(?:\.\d+)?)" % re.escape(f), a, re.I)
				sc[f] = float(m.group(1)) if m else None
			row["scores"] = sc
			if any(v is None for v in sc.values()):
				row["verdict"] = "unmatched"
			elif bar is not None and any(v < bar for v in sc.values()):
				row["verdict"] = "under_bar"
			else:
				row["verdict"] = "scored"
		rows.append(row)
	n = len(rows)
	counts = {v: sum(1 for r in rows if r["verdict"] == v) for v in
			("correct", "confused", "unmatched", "missing", "scored", "under_bar")}
	expected_set = {it["expected"] for it in k["items"]}
	conf = [{"id": r["id"], "expected": r["expected"], "given": r["given"]} for r in rows if r["verdict"] == "confused"]
	pairs = sorted({tuple(sorted((c["expected"], c["given"]))) for c in conf if c["given"] in expected_set})
	res = {"kind": k["kind"], "answer_format": fmt, "n": n, "counts": counts, "correct": counts["correct"],
			"confusions": conf, "confused_pairs": [list(p) for p in pairs], "rows": rows}
	if fmt == "yesno":
		res["yes"] = sum(1 for r in rows if r["given"] == "yes")
		res["no"] = sum(1 for r in rows if r["given"] == "no")
	if fmt == "scores":
		agg = {}
		for f in k.get("score_fields", []):
			vals = [r["scores"][f] for r in rows if r.get("scores", {}).get(f) is not None]
			agg[f] = {"mean": cm.rounded(sum(vals) / len(vals)) if vals else None, "min": min(vals) if vals else None}
		res["scores"] = agg
		res["bar"] = bar
	return res


def verdict_md(res: dict, key: dict) -> str:
	fmt = res["answer_format"]
	lines = ["# Packet verdict — %s, %d items (seed %s)" % (res["kind"], res["n"], key.get("seed")), "",
			"Question: %s" % key.get("question", ""), ""]
	if fmt == "scores":
		fields = key.get("score_fields", [])
		lines.append("| id | key | %s | answer (verbatim) | verdict |" % " | ".join(fields))
		lines.append("|---|---|%s---|---|" % ("---|" * len(fields)))
		for r in res["rows"]:
			sc = r.get("scores") or {}
			lines.append("| %s | %s | %s | %s | %s |" % (r["id"], r["name"], " | ".join(
				"-" if sc.get(f) is None else "%g" % sc[f] for f in fields), _cell(r["answer"]), r["verdict"]))
		lines += ["", "Means: " + ", ".join("%s %s (min %s)" % (f, v["mean"], v["min"])
											for f, v in res["scores"].items())]
		if res.get("bar") is not None:
			lines.append("Under the bar (%g): %d" % (res["bar"], res["counts"]["under_bar"]))
	else:
		lines.append("| id | key | answer (verbatim) | read as | verdict |")
		lines.append("|---|---|---|---|---|")
		for r in res["rows"]:
			key_txt = r["name"] if r["name"] == r["expected"] else "%s (expect %s)" % (r["name"], r["expected"])
			lines.append("| %s | %s | %s | %s | %s |" % (r["id"], key_txt, _cell(r["answer"]), r["given"] or "-",
														r["verdict"]))
		c = res["counts"]
		lines += ["", "**Correct: %d/%d** · confused %d · unmatched %d (a human must judge) · missing %d" % (
			c["correct"], res["n"], c["confused"], c["unmatched"], c["missing"])]
		if fmt == "yesno":
			lines.append("Yes: %d · No: %d" % (res["yes"], res["no"]))
		if res["confusions"]:
			lines.append("Confusions: " + "; ".join("%s → %s (%s)" % (x["expected"], x["given"], x["id"])
													for x in res["confusions"]))
		if res["confused_pairs"]:
			lines.append("Confused pairs (both are items): " + "; ".join(" ↔ ".join(p) for p in res["confused_pairs"]))
	return "\n".join(lines) + "\n"


def _cell(s: str | None) -> str:
	return "-" if s is None else s.replace("|", "\\|")


# --- CLI -------------------------------------------------------------------------------------------------------------

def _list_arg(s: str | None, sep: str) -> list[str] | None:
	if s is None:
		return None
	if s.startswith("@"):
		return [ln.strip() for ln in Path(s[1:]).read_text(encoding="utf-8").splitlines() if ln.strip()]
	return cm.split_list(s, sep)


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(prog="packets.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("build")
	p.add_argument("out_dir")
	p.add_argument("--items", required=True)
	p.add_argument("--key", required=True)
	p.add_argument("--kind", default="frames", choices=KINDS)
	p.add_argument("--seed", type=int, default=1)
	p.add_argument("--names")
	p.add_argument("--question")
	p.add_argument("--format", choices=FORMATS)
	p.add_argument("--choices")
	p.add_argument("--scores")
	p.add_argument("--expected")
	p.add_argument("--aliases")
	p.add_argument("--context", default="")
	p.add_argument("--sep", default=",")
	p.add_argument("--force", action="store_true")
	p = sub.add_parser("score")
	p.add_argument("key")
	p.add_argument("answers")
	p.add_argument("--out")
	p.add_argument("--json")
	p.add_argument("--bar", type=float)
	a = ap.parse_args(argv)
	if a.cmd == "build":
		if a.kind == "pairs":
			items = cm.split_list(a.items, a.sep)
		else:
			items = []
			for s in cm.split_list(a.items, a.sep):
				pth = Path(s)
				if pth.is_dir() and a.kind != "strips":
					items += [str(x) for x in cm.list_images(pth)]
				elif pth.is_dir():
					subdirs = sorted([x for x in pth.iterdir() if x.is_dir()], key=lambda x: cm.natural_key(x.name))
					items += [str(x) for x in (subdirs or cm.list_images(pth))]
				else:
					items.append(s)
		aliases = cm.read_json(a.aliases) if a.aliases else None
		try:
			key = build(a.out_dir, items, a.key, a.kind, a.seed, _list_arg(a.names, a.sep), a.question, a.format,
						_list_arg(a.choices, a.sep), _list_arg(a.scores, a.sep), a.expected, aliases, a.context,
						a.force)
		except ValueError as e:
			print("packets: %s" % e, file=sys.stderr)
			return 2
		print("wrote %d packets to %s (+ prompt.md); key → %s" % (len(key["items"]), key["packet_dir"], a.key))
		return 0
	res = score(a.key, Path(a.answers), a.bar)
	md = verdict_md(res, cm.read_json(a.key))
	print(md)
	if a.out:
		Path(a.out).parent.mkdir(parents=True, exist_ok=True)
		Path(a.out).write_text(md, encoding="utf-8")
	if a.json:
		cm.write_json(a.json, res)
	return 0


if __name__ == "__main__":
	sys.exit(cm.run_cli(main, "packets.py"))
