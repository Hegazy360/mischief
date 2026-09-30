# `tools/art3d/review/` — the one review toolset of R3D

Every visual task measures with these five tools (index ruling R14: no private samplers). Python 3 + Pillow + numpy
only — no Godot, no Blender, no CPU slot needed. Every tool is a CLI (`--json=/abs.json` writes the machine-readable
result) and an importable module:

```python
import sys; sys.path.insert(0, "tools/art3d/review")
import lab, sil64, strip, boards, packets
```

| Tool | What | Who uses it |
|---|---|---|
| `lab.py` | sRGB → CIELAB (D65), L*, C*, ΔL*, ΔE76; per-region stats from an ID pass; the character value shares; the REDESIGN §3.7 rules; L*/C* false-colour boards | cast ×2 (value rule), sets (`value_map.png`, build to the rules), `r3d-tools-b` set lint |
| `sil64.py` | 64 px silhouettes, pairwise IoU, same-family flags, board | sets (`silhouettes_64.png`), `r3d-tools-b` set lint, `r3d-anim` / `-hush-b` (`verbs_64.png`, statues 5–8), cast |
| `strip.py` | numbered frame strips at phone scale with marked accents | every animation key, `r3d-integrate`, `r3d-qa`, reviewer packets |
| `boards.py` | labelled grids and before/after pairs, 1200×540 per cell | cast (`hybrid_vs_ab.png`), sets (`before_after.png`), `r3d-integrate` (2D vs 3D) |
| `packets.py` | opaque reviewer packets + prompt + answer key; scoring the answers | cast face read test, `verbs_64`, `r3d-qa` row 19 (index R17) |

Tests: `python3 -m unittest tools/art3d/review/test_review.py` (< 30 s). Fixtures: `fixtures/` (regenerate with
`python3 tools/art3d/review/fixtures/make_fixtures.py`); `fixtures/lookdev/` = hand-made masks + an ID pass for look
A's in-game kitchen (`make_lookdev.py`), whose numbers the tests pin. Worked examples on real images:
`docs/review/r3d-tools-a/`. Exit codes: 0 ok; 1 = `lab.py rules` found a FAIL; 2 = bad input (one line on stderr).

---

## `lab.py` — colour and value

The conversion: sRGB with the IEC 61966-2-1 transfer curve (linear below 0.04045), the sRGB → XYZ matrix, D65 white
(0.95047, 1.0, 1.08883), CIE L*a*b*; C* = √(a*² + b*²). Checked: white L* 100, mid-grey `#808080` 53.59, red 53.24 /
80.09 / 67.20, the blockout kitchen wall `#C7B684` L* 74.4 C* 27.7.

```bash
# one colour (or several)
python3 tools/art3d/review/lab.py color '#C7B684' '#1E2748'

# per-region stats: a beauty render + an ID pass (flat unshaded ID colours) + the legend
python3 tools/art3d/review/lab.py regions tools/art3d/review/fixtures/regions/beauty.png \
  --id=tools/art3d/review/fixtures/regions/id.png --legend=tools/art3d/review/fixtures/regions/legend.json \
  --json=$SP/work/<key>/regions.json

# the §3.7 rules on that result: PASS / FAIL per region (exit 1 on a FAIL; --strict also fails on SKIP)
python3 tools/art3d/review/lab.py rules $SP/work/<key>/regions.json --rules=set --json=$SP/work/<key>/rules.json

# the character value rule on a render (mask = its own alpha, a mask PNG, or an ID colour)
python3 tools/art3d/review/lab.py value hush_flat.png --mask=alpha --label=hush \
  --hist=docs/review/<key>/value_hush.png --json=$SP/work/<key>/value_hush.json
python3 tools/art3d/review/lab.py value kitchen.png --mask=kitchen_id.png --mask-color='#00FF80' --erode=1 --label=bellows

# a false-colour board (L* bands, C* bands; region medians printed when an ID pass is given)
python3 tools/art3d/review/lab.py falsecolor kitchen.png --out=docs/review/<key>/value_map.png \
  [--id=kitchen_id.png --legend=legend.json] [--mask=alpha]
```

**Masks** (`value --mask`, `falsecolor --mask`, `sil64`): `alpha` = the image's own alpha (a character rendered on a
transparent background); a PNG with transparency = opaque pixels are inside; an opaque PNG = dark pixels (luma < 128,
a black shape on white) are inside; `--mask-color` = one exact ID colour (±`--tol`, default 2). **Outlines:** the ink
outline is dark and would count toward the L* ≤ 40 share — measure with the outline pass off, or take the mask from an
ID/mask pass (no hull), or `--erode` by the outline width in px when the mask is the beauty's alpha.

**Legend JSON** (`regions`; `r3d-tools-b`'s `LintShot3D --pass=id` writes it) — canonical shape:

```json
{"regions": [
  {"color": "#FF0000", "name": "kitchen_wall",     "class": "wall",      "room": "kitchen"},
  {"color": "#00FF00", "name": "kitchen_wainscot", "class": "wainscot",  "room": "kitchen"},
  {"color": "#0000FF", "name": "kitchen_floor",    "class": "floor",     "room": "kitchen"},
  {"color": "#A0A0FF", "name": "parlour_wall",     "class": "wall",      "room": "parlour", "lit": false},
  {"color": "#FFFF00", "name": "kitchen_stool",    "class": "dressing",  "wall": "kitchen_wall"},
  {"color": "#FFE0A0", "name": "lamp_shade",       "class": "dressing",  "room": "parlour", "exempt": "the light source (§3.7)"},
  {"color": "#00FFFF", "name": "kitchen_honey",    "class": "live_prop"},
  {"color": "#800000", "name": "kitchen_tap",      "class": "live_prop", "halo": true},
  {"color": "#008000", "name": "hush",             "class": "character"}
]}
```
Also accepted: a bare list of those rows, or `{"#RRGGBB": {"name": …, "class": …}}` / `{"#RRGGBB": "name"}`.
Classes: `wall` (`"lit": false` or class `wall_dim` = a dimmed neighbour), `wainscot`, `floor`, `dressing`,
`live_prop`, `character`, anything else (`other`, `hiding`, `architecture` …) is reported as INFO. A dressing piece or
wainscot finds its wall by `wall` (a region name), else the one wall of its `room`, else the only wall in the legend;
none → SKIP. Extra fields pass through to the output. Colours must be unique. ID pixels are matched exactly, leftovers
within ±`--tol`; each region is eroded by `--erode` px (default 1: drops antialiased ID edges); beauty pixels with
alpha < 128 are ignored; a region with fewer than `--min-px` (20) pixels is `visible: false` → SKIP.

**`regions` JSON:**
```json
{"size": [1200, 540], "erode": 1, "tol": 2, "min_px": 20, "unmatched_px": 2560,
 "image": "/abs/beauty.png", "id_pass": "/abs/id.png", "legend": "/abs/legend.json",
 "regions": [{"name": "kitchen_wall", "class": "wall", "room": "kitchen", "color": "#FF0000", "px": 330184,
              "L": {"median": 74.36, "p10": 74.36, "p90": 74.36, "mean": 74.36},
              "C": {"median": 27.73, "p10": 27.73, "p90": 27.73, "mean": 27.73},
              "a": -1.39, "b": 27.7, "share_hi": 0.0, "share_lo": 0.0, "visible": true, "median_hex": "#C7B684"}]}
```
`share_hi` / `share_lo` = the region's share of pixels at L* ≥ 85 / ≤ 40.

**The rules (`lab.SET_RULES`, REDESIGN §3.7; medians are judged):**

| Class | Rule | Threshold |
|---|---|---|
| `wall` (lit) | L* median / C* median | 62–76 / ≤ 28 |
| `wall` (`lit: false`, `wall_dim`) | L* / C* | 45–58 / ≤ 15 |
| `wainscot` | wall L* − wainscot L* | 8–10 |
| `floor` (lit; a dimmed floor is INFO) | L* | 40–50 |
| `dressing` | C* / \|ΔL*\| vs its wall | ≤ 30 / ≤ 15 (`exempt` for the one light source) |
| `live_prop` | C* median, **or** `"halo": true` in the legend | ≥ 45 |
| `character` | share at L* ≥ 85 **and** share at L* ≤ 40 | ≥ 0.20 each |

**`rules` JSON:** `{"rules": "set", "thresholds": {…SET_RULES}, "pass": false, "counts": {"PASS": 10, "FAIL": 2,
"SKIP": 0, "EXEMPT": 0, "INFO": 0}, "results": [{"name", "class", "rule", "value", "limit", "status", "detail"}]}`.
`--rules=character` checks only the characters.

**`value` JSON:** `{"px", "L": {median, p10, p90, mean}, "C": {…}, "a", "b", "share_hi", "share_lo", "share_mid",
"hi": 85, "lo": 40, "min_share": 0.2, "pass": true, "bbox": [x0, y0, x1, y1], "image", "mask", "label", "erode"}`.
The `--hist` PNG (1200×540): the L* histogram with the ≤ 40 / ≥ 85 zones and PASS/FAIL, the masked pixels, and the
same pixels painted dark (blue) / mid (grey) / light (gold) — look at it: the dark must be the costume, the light the face.

## `sil64.py` — 64 px silhouettes

```bash
python3 tools/art3d/review/sil64.py masks tools/art3d/review/fixtures/masks \
  --out=docs/review/r3d-tools-a/sil64_fixture.png --json=$SP/work/<key>/sil64.json [--same-family=0.80] \
  [--cells-dir=$SP/work/<key>/sil_cells] [--despeckle=0.002]   # --cells-dir: each 64 px silhouette as a PNG (packets)
python3 tools/art3d/review/sil64.py extract render.png --out=mask.png --mode=alpha   # or --mode=color --color=#RRGGBB
```
Inputs: directories and/or files, names = file stems (or `--names=a,b,…`). Each mask first loses its specks
(connected parts under `--despeckle` = 0.2 % of its pixels — stray ID pixels, particles; `--despeckle=0` keeps all), is cropped to its bounds,
area-resampled so its **height is 64 px** (aspect kept; `--fit=box` fits the longer side), thresholded at ½ and centred
by its bounding box on a 96×96 canvas — widened for all when a shape is wider (a dive, a piano) so every pair is
compared on one canvas. IoU = |A∩B| / |A∪B|; **IoU ≥ 0.80 = same family** (the set lint's error; `r3d-anim-hush-b`'s
statues must stay under it). Board: 1× and 2× silhouettes, the matrix (green < 0.60, amber 0.60–0.80, red ≥ 0.80), the
flagged pairs overlaid (red A, blue B, purple both).

**JSON:** `{"names": [...], "files": [...], "iou": [[1.0, 0.2, …], …], "pairs_over": [{"a": "jar", "b":
"jar_scaled_105", "iou": 0.9994}], "threshold": 0.8, "height": 64, "canvas": [96, 96], "fit": "height", "sizes":
[[w, h], …], "empty": []}` (`pairs_over` sorted by IoU, highest first).

## `strip.py` — numbered strips

```bash
python3 tools/art3d/review/strip.py tools/art3d/review/fixtures/frames docs/review/r3d-tools-a/strip_fixture.jpg \
  --every=3 --cols=4 --marks=tools/art3d/review/fixtures/frames_marks.json --label-frames
# a DevShot sequence (--shot-seq=DIR --every=3 --seq-from=30): real frame numbers on the cells
python3 tools/art3d/review/strip.py $SEQ out.jpg --frame-step=3 --frame-offset=30 --label-frames
# marks straight from a clip sidecar (beats starts + mark events), the clip starting at capture frame 40
python3 tools/art3d/review/strip.py $CAP out.jpg --every=3 --marks=game/data/anim/hush3d/snicker.json --marks-offset=40 --label-frames
# reviewer packets: pages of 12 cells that an image reader can see whole
python3 tools/art3d/review/strip.py $CAP $SP/work/<key>/strips/g07.jpg --every=3 --cols=4 --per-page=12 --label-frames
```
Frames = every PNG/JPEG in the folder, natural-sorted; a frame's number = the last digit group of its name ×
`--frame-step` + `--frame-offset`. `--every=N` keeps every N-th file, **marked frames are always kept**. Cells default
to the frame size × `--scale` (1.0: a 1200×540 capture → 1200×540 cells, 2 per row in 2400 px); `--cols` shrinks them to
fit `--width` (2400). Labels: `#1, #2 …` or, with `--label-frames`, `f 123`. Marks `{"94": "accent"}` (or
`{"marks": {…}}`, `[{"frame", "kind"}]`, a sidecar v2): accent red, anticipation blue, contact orange, hold green,
settle purple, key amber, release cyan, other grey; the kind is printed on the cell (`--no-mark-text` hides it).
JPEG q85, **≤ 4 MB per page** (quality, then cell size, step down; printed on stderr). After the strip exists, delete
the raw frames (R12). **JSON:** `{"pages": [...], "cells": [{"index", "frame", "file", "mark"}], "cell_size": [w, h],
"cols", "quality", "bytes": [...], "every", "marks": {…}, "frame_dir"}`.
Budget: 150 frames ≤ 10 s.

## `boards.py` — grids and pairs

```bash
python3 tools/art3d/review/boards.py pair docs/review/<key>/before_after.png \
  docs/review/r3d-ref2d/n1_kitchen_rest_20x9.png $SP/work/<key>/n1_kitchen_3d.png --labels="2D,3D"
python3 tools/art3d/review/boards.py grid docs/review/r3d-cast-hush/hybrid_vs_ab.png \
  --cells=hybrid.png,look_a.png,look_b.png --labels="hybrid (B body, A style)|look A|look B" --sep='|' --cols=3 \
  [--notes="1.60 m|toy box|cartoon"] [--title="Hush"] [--cell=1200x540] [--scale=0.5]
```
Each cell keeps its image's aspect, letterboxed on dark, never stretched; label bar under each cell (+ an optional
note line). `--cells` may be a folder (labels = file stems). `pair --stack` puts after under before.

## `packets.py` — opaque reviewer packets (index R17)

```bash
# 1. build: items copied under pkt_01 … in a seeded shuffle, re-encoded without metadata; KEY outside the packet dir
python3 tools/art3d/review/packets.py build docs/review/r3d-anim/packets/verbs64 \
  --items=$SP/work/r3d-anim/verbs_cells --kind=crops --seed=11 --key=$SP/work/r3d-anim/review_key.json \
  --question="What is this character doing? One verb from the list." \
  --choices=sneak,run,reach-high,reach-mid,reach-low,dive,statue,squeak,peek,bow,snicker,wave,sit,fall \
  --aliases=$SP/work/r3d-anim/aliases.json
# the face read test: 6 crops, a list of 10 names (distractors included)
python3 tools/art3d/review/packets.py build docs/review/r3d-cast-hush/packets/faces --items=$SP/work/r3d-cast-hush/face_crops \
  --kind=crops --key=$SP/work/r3d-cast-hush/review_key.json --question="Which expression is this face making?" \
  --choices=neutral,sneak,shock,snicker,fear,dazed,angry,sleepy,sad,wink
# crowding (yes/no, every item expects "no") and 2D-vs-3D preference (pairs: the candidate's side is expected)
python3 tools/art3d/review/packets.py build docs/review/r3d-qa/packets/crowd --items=$SP/work/r3d-qa/crowd \
  --format=yesno --expected=no --question="Is this screen crowded or confusing?" --key=$SP/work/r3d-qa/crowd_key.json
python3 tools/art3d/review/packets.py build docs/review/r3d-qa/packets/prefer --kind=pairs \
  --items=docs/review/r3d-ref2d/p00_calm_plan_20x9.png:$SP/work/r3d-qa/p00_calm_plan_3d.png,… \
  --question="Which frame, A or B, is clearer to play on a phone?" --key=$SP/work/r3d-qa/prefer_key.json
# gag strips (a folder per gag = a multi-page strip) scored 1–5
python3 tools/art3d/review/packets.py build docs/review/r3d-qa/packets/gags --items=$SP/work/r3d-qa/gag_strips \
  --kind=strips --format=scores --scores=funny,readable,fresh --key=$SP/work/r3d-qa/gags_key.json
# 2. a fresh reviewer answers <packet dir>/prompt.md (spawned, or the orchestrator runs it — R17)
# 3. score: the verdict table for readability.md / reviewer_answers.md
python3 tools/art3d/review/packets.py score $SP/work/r3d-anim/review_key.json docs/review/r3d-anim/reviewer_answers.md \
  --out=docs/review/r3d-anim/verdict.md --json=$SP/work/r3d-anim/verdict.json [--bar=3]
```
- **Opaque:** file names are `pkt_XX.<ext>` (a folder item → `pkt_XX/page_1.jpg …`), images are re-encoded (no text
  chunks or EXIF), ids are dense and shuffled by `--seed`, choices are listed alphabetically. The build **refuses** a
  packet whose prompt (outside the choices list) or file names contain an item name or a source file stem, refuses a
  key inside the packet dir and a non-empty packet dir (`--force` replaces earlier `pkt_*` + `prompt.md` only).
- **Formats** (`--format`, default by kind: frames/strips `free`, crops `choice`, pairs `ab`): `free`, `choice`,
  `yesno`, `ab`, `scores` (`--scores=funny,readable,fresh`). `expected` = the item's name (file stem, `--names`) unless
  `--expected=<one answer for all>`; pairs expect the candidate's side (A or B, random per pair).
- **Answer sheet:** one line per id, `pkt_01: <answer>` (also `- **pkt_01**: …`, `| pkt_01 | … |`, `pkt_01 — …`);
  scores as `pkt_01: funny=4 readable=5 fresh=3 — …`.
- **Matching:** words are lower-cased and stemmed (sneaking = sneak, diving = dive, running = run, reach-high = reach
  high); a candidate (every item's name + its `--aliases` JSON `{"sneak": ["tiptoe", "creep"]}` + the choices) is named
  when all its words are in the answer; the **first** candidate named is the answer (ties → the longer one). Verdicts:
  `correct`, `confused` (read as another candidate), `unmatched` (nothing recognised — a human judges it), `missing`;
  scores: `scored` / `under_bar` / `unmatched`.
- **KEY.json:** `{"version": 1, "kind", "seed", "created", "packet_dir", "prompt", "question", "answer_format",
  "choices": [...], "score_fields": [...], "items": [{"id": "pkt_01", "name", "expected", "aliases": [...], "file",
  "source" | "pages" + "source" | "A", "B", "candidate", "reference"}]}`.
- **score JSON:** `{"kind", "answer_format", "n", "correct", "counts": {"correct", "confused", "unmatched", "missing",
  "scored", "under_bar"}, "confusions": [{"id", "expected", "given"}], "confused_pairs": [["bottle", "clock"]],
  "rows": [{"id", "name", "expected", "answer", "given", "verdict", "scores"?}], "yes"/"no" (yesno), "scores": {field:
  {"mean", "min"}} + "bar" (scores)}`.

---

## Thresholds by consumer (the numbers each brief checks with these tools)

| Consumer | Check | Tool call | Bar |
|---|---|---|---|
| `r3d-cast-hush` §4.2 | value rule, flat-lit 1200×540 render | `lab.py value … --mask=alpha` (outline off) | `share_hi` ≥ 0.20 and `share_lo` ≥ 0.20 (face ≈ 96, navy ≈ 22) |
| `r3d-cast-hush` §4.3 | face read test (6 crops, 10 names) | `packets.py build --kind=crops --choices=…` → `score` | ≥ 5/6 correct, `confused_pairs` empty |
| `r3d-cast-bellows` §4.2 | value rule; 64 px pose masks | `lab.py value`; `sil64.py masks` | ≥ 0.20 each (bouffant ≈ 91, jacket ≈ 35) |
| `r3d-sets` §4.2 / §6 | walls, wainscot, floors, dressing, live props; `value_map.png`; `silhouettes_64.png`; `before_after.png` | `lab.py regions` + `rules --rules=set`; `falsecolor`; `sil64.py masks` per room; `boards.py pair` | §3.7 table above; IoU < 0.80 within a room |
| `r3d-anim` §4.4 (+ `-hush-b`) | `verbs_64.png` reviewer test; statues 5–8 distinct | `sil64.py masks --cells-dir` → `packets.py build --kind=crops` → `score`; `sil64.py masks` | ≥ 11/13, no confused pair; IoU < 0.80 among the 8 statues |
| every animation key | in-set strips, contact strips | `strip.py --every=3 --marks=<sidecar> --label-frames` | ≤ 4 MB per page |
| `r3d-tools-b` §4.1 | set lint colour/value + silhouettes | `lab.regions` / `lab.check_rules` / `sil64.run_masks` (import) | as above; `lab.py rules` exits 1 on a FAIL |
| `r3d-integrate` | 2D vs 3D boards, strips | `boards.py pair`, `strip.py` | — |
| `r3d-qa` §3.3 row 19 | verb ≥ 7/8, spot ≥ 6/8, crowded ≤ 1/8 yes, 3D preferred ≥ 6/8, gags ≥ 4/5 or ≥ 3/5 | `packets.py build` (frames / yesno / pairs / strips+scores) → `score [--bar]` | as in the index §6 row 19 |

Perf (1200×540): `regions` / `value` ≤ 2 s, `sil64` 20 masks ≤ 5 s, `strip` 150 frames ≤ 10 s (`test_review.py`
asserts them).

After P0 the CLI flags and JSON shapes above are a contract (index §3.5 rule 3): only optional flags and fields are
added. A missing capability is a request to `r3d-tools-a`.
