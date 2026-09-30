# r3d-tools-a — report: the shared review toolset (`tools/art3d/review/`)

**Status: done.** P0 landed at 16:47 UTC, 16 min after launch (16:31), and was announced in
`<SP>/work/r3d-tools-a/LANDED.md`. The hardening landing followed at 17:04. Tests: 51/51 green in about 10 s.
Every tool was run on the real look-dev images and I looked at each output.

## 1. Files built (all new; only my §2 paths were touched)
- `tools/art3d/review/_common.py`: shared helpers.
  - The game's Nunito font, falling back to DejaVu.
  - JSON writing, natural sort, reading hex colours.
  - Reading masks (`auto|alpha|dark|color`), erosion, bounding boxes, connected components and `despeckle`.
  - Letterboxing, saving images with no metadata, and `run_cli`: bad input exits 2 with one line of text, never a traceback.
- `tools/art3d/review/lab.py`: CIELAB. Subcommands `color`, `regions`, `value`, `rules`, `falsecolor`.
- `tools/art3d/review/sil64.py`: 64 px silhouettes. Subcommands `masks` (IoU matrix and board) and `extract` (a mask PNG from a render).
- `tools/art3d/review/strip.py`: numbered strips at phone scale, with marks and pages.
- `tools/art3d/review/boards.py`: `grid` and `pair`.
- `tools/art3d/review/packets.py`: `build` (opaque packets, `prompt.md`, and a key kept outside the packet dir) and `score` (the verdict table).
- `tools/art3d/review/README.md`: one copy-paste example per tool, the thresholds each consumer uses, and every JSON format.
- `tools/art3d/review/test_review.py`: 51 unittest tests (`python3 -m unittest tools/art3d/review/test_review.py`).
- `tools/art3d/review/fixtures/`:
  - `make_fixtures.py` (deterministic) builds `masks/` (7 prop families plus a 5 %-scaled jar), `regions/` (a synthetic beauty image, ID pass and legend), `frames/` (24 frames) with `frames_marks.json`, and `answers/answers.md`.
  - `lookdev/make_lookdev.py` builds `hush_mask.png`, `bellows_mask.png`, `id.png` and `legend.json`: hand-made masks and an ID pass for look A's in-game kitchen. The test pins the numbers read from them.
- `docs/review/r3d-tools-a/`: `index.md` plus 11 artefacts (§4), about 2 MB.

## 2. The contract (CLI + JSON; from P0 on only optional flags and fields are added)
**Importing the tools:** `sys.path.insert(0, "tools/art3d/review"); import lab, sil64, strip, boards, packets`.
Every CLI takes `--json=/abs` where it produces data. The README has the full field lists.

**`lab.py`**
- **Conversion:** sRGB with the IEC transfer curve → XYZ → CIELAB with D65 white (0.95047, 1, 1.08883).
- **Functions:** `rgb_to_lab`, `lab_of`, `chroma`, `delta_l`, `delta_e76`, `regions`, `value_shares`, `check_rules`, `falsecolor_board`, `SET_RULES`.
- **`regions <img> --id=<id.png> --legend=<legend.json> [--erode=1 --tol=2 --min-px=20]`**
  - The canonical legend is `{"regions": [{color, name, class, room?, lit?, wall?, halo?, exempt?}]}`.
  - Output per region: `{name, class, color, px, L{median,p10,p90,mean}, C{…}, a, b, share_hi, share_lo, visible, median_hex, …legend extras}`, plus `size`, `unmatched_px`.
- **`value <img> --mask=<png|alpha> [--mask-color --erode --hi=85 --lo=40 --min-share=0.20 --hist=png]`**
  - Output: `{px, L, C, share_hi, share_lo, share_mid, pass, bbox, …}`.
- **`rules <regions.json> [--rules=set|character] [--strict] [--no-fail]`**
  - Output: `{pass, counts{PASS,FAIL,SKIP,EXEMPT,INFO}, results[{name,class,rule,value,limit,status,detail}], thresholds}`.
  - Exits 1 on a FAIL (with `--strict`, also on a SKIP).
- **`falsecolor <img> --out=png [--id --legend --mask]`**: a board of L* bands, C* bands and region medians with PASS/FAIL.
- **`color <#hex…>`**: prints L*, a*, b*, C* and h for each colour.

**`sil64.py`**
- **`masks <dirs|files> --out=png [--same-family=0.80 --height=64 --canvas=96 --fit=height|box --names --cells-dir --despeckle=0.002]`**
  - Output: `{names, files, iou[[…]], pairs_over[{a,b,iou}], threshold, height, canvas, fit, sizes, empty}`.
  - Functions: `run_masks`, `normalise`, `iou`, `iou_matrix`, `board`.
- **`extract <render> --out=mask.png [--mode --color]`**: writes a mask PNG from a render.

**`strip.py`**
- **Command:** `strip.py <dir> <out.jpg> [--every --cols --scale=1.0 --width=2400 --marks=<json|sidecar v2> --marks-offset --label-frames --frame-step --frame-offset --from --to --per-page --max-mb=4 --quality=85 --title --no-mark-text]`.
- **Output:** `{pages, page_cells, cells[{index,frame,file,mark}], cell_size, cols, quality, bytes, every, marks, frame_dir}`.
- **Frame selection:** a frame's number comes from its file name × step + offset. Marked frames are always kept. Output stays ≤ 4 MB per page.

**`boards.py`**
- **Commands:** `grid <out> --cells=a,b,… [--labels --notes --sep --cols --cell=1200x540 --title --scale]` and `pair <out> <before> <after> [--labels="2D,3D" --stack]`.
- **Functions:** `grid()`, `pair()`.

**`packets.py`**
- **`build <dir> --items=… --key=/abs(outside) [--kind=frames|strips|crops|pairs --format=free|choice|yesno|ab|scores --choices --scores --expected --aliases --names --seed --question --context --force]`**
  - The key: `{version, kind, seed, packet_dir, prompt, question, answer_format, choices, score_fields, items[{id,name,expected,aliases,file,source|pages|A,B,candidate,reference}]}`.
- **`score <key> <answers.md> [--out=md --json --bar]`**
  - Output: `{n, correct, counts{correct,confused,unmatched,missing,scored,under_bar}, confusions, confused_pairs, rows, yes/no, scores{field:{mean,min}}}`.

**Thresholds** (`lab.SET_RULES`, REDESIGN §3.7; the medians are what gets judged):

| Region | Rule |
|---|---|
| Lit wall | L* 62–76, C* ≤ 28 |
| Dimmed wall (`lit:false` / `wall_dim`) | L* 45–58, C* ≤ 15 |
| Wainscot | 8–10 L* darker than its wall |
| Lit floor | L* 40–50 (a dimmed floor is INFO only) |
| Dressing | C* ≤ 30, and \|ΔL*\| ≤ 15 against its wall (found by legend `wall`, else by `room`), or `exempt` |
| Live prop | C* ≥ 45, or `halo: true` |
| Character | `share_hi` (L* ≥ 85) ≥ 0.20 and `share_lo` (L* ≤ 40) ≥ 0.20 |

Silhouettes with IoU ≥ 0.80 count as the same family. The README has a table giving each consumer's bars (cast, sets, anim, tools-b, integrate, qa).

## 3. Reference checks (`test_review.py`, 51 tests, ≈ 10 s)
- **Colour maths:** these match the published CIELAB values within ±0.5:
  - white 100/0/0 and black 0
  - `#808080` 53.59
  - red 53.24/80.09/67.20, green 87.73/−86.18/83.18, blue 32.30/79.19/−107.86
  - cyan 91.11/−48.09/−14.13, magenta 60.32/98.23/−60.82, yellow 97.14/−21.55/94.48
  - the blockout kitchen wall `#C7B684` → **L\* 74.36, C\* 27.73** (the brief says ≈ 74 / ≈ 28)
- **`regions`:** returns the exact medians and the exact pixel counts after 1 px erosion on synthetic ID passes. Near colours match within `--tol`. Transparent beauty pixels are ignored.
- **`value`:** gives exact shares on a two-tone silhouette (0.40 / 0.60). It fails at 15 %.
- **`rules`:** every rule passes and fails at its edge (a C* 40 dressing and an L* 80 wall both fail). SKIP, EXEMPT and INFO behave as specified, and the exit codes are right.
- **`sil64`:**
  - identical shapes → 1.0; disjoint shapes → < 0.02
  - a 5 %-scaled copy → ≥ 0.80; a half-size, off-centre copy → ≥ 0.93 (scale and position invariant)
  - the height is exactly 64 px; the canvas widens for wide shapes
  - stray pixels no longer skew the result
- **`strip`:** 100 textured 1200×540 frames fit in one page of ≤ 4 MB with the accent cell outlined in red. It numbers frames correctly with step/offset, reads marks from a sidecar v2, and splits into pages.
- **`packets`:**
  - Never leaks a name: file names are opaque, PNG text chunks are stripped, and the prompt names no item outside the choices. The PNG test inputs carry a "Title" chunk to prove it.
  - Refuses a key inside the packet dir, a prompt that leaks, or a non-empty dir; nothing is written on a refusal.
  - `score` reproduces the committed fixture sheet: 5/8, `snicker → run`, one unmatched and one missing.
  - Pairs, yes/no, scores and folder items all work.
- **Real image:** the look-A kitchen numbers are pinned (§4).
- **Perf** (1200×540):
  - `regions` / `value` ≤ 2 s (`regions` measured 0.4 s with 40 legend colours)
  - `sil64`, 20 masks ≤ 5 s (about 0.5 s)
  - `strip`, 150 frames ≤ 10 s (about 5 s for full-size cells, about 1 s paged)

## 4. Runs on the real look-dev images (looked at; all in `docs/review/r3d-tools-a/index.md`)
The numbers match what the eye sees. Hush's navy costume and bob read dark, the face paint and gloves light. Bellows' bouffant and waistcoat read light, the plum jacket dark.

Two findings for the owners of the cast and the sets. They are measurements only: neither task was blocked, and nothing was changed.
- **`r3d-sets`:** look A's look-dev kitchen does not meet §3.7 as rendered (`falsecolor_lookA_kitchen.png`, `rules_lookA_kitchen.txt`). It was never meant to be judged as a set, but these are the values to move away from:

  | Region | Measured | Rule |
  |---|---|---|
  | Kitchen wall | L* 90.6 | 62–76 |
  | Parlour wall | L* 78.6 | 62–76 |
  | Kitchen / parlour floor | L* 64.3 / 62.1 | 40–50 |
  | Pantry curtain | C* 43.5 | ≥ 45 |
  | White fireplace against the pink wall | \|ΔL*\| 17.1 | ≤ 15 |

  The gramophone horn passes (C* 65.7).
- **`r3d-cast-hush`:** look A's Hush in the bent sneak pose fails the character value rule. Only **11.9 % of her silhouette is at L\* ≥ 85** (the rule is ≥ 20 %); 58 % is at ≤ 40. With the outline eroded (3 px) it is 14.5 % / 51.8 %, still failing. The shaded half of the face paint and the red beret sit in the mid band (`value_lookA_hush.png`). So her face paint, gloves and white stripes need to be brighter, and the face card as big as R6 step 1 allows.

  Bellows passes: 32 % at L* ≥ 85, 37 % at ≤ 40 (`value_lookA_bellows.png`).
- **The cast at 64 px:** Hush and Bellows are distinct, IoU 0.67 (`sil64_lookA_cast.png`).
- **Strips:** `strip_lookA_sneeze.jpg` is the look-A sneeze GIF as a numbered strip with marks: anticipation 20, accent 24, key 28, settle 36.
- **Boards:**
  - `pair_2d_vs_lookA.png` puts the crowded 2D N1 kitchen beside the calm 3D one.
  - `grid_lookdev_kitchens.png` shows the grid format.
- **Packets:** `packet_example/` is an opaque crops packet with its `prompt.md`. `packet_example_verdict.md` scores it on a **synthetic** answer sheet, as a format demo only (6/7, phone → lamp).

## 5. Deviations from the brief (all additive, all with reasons)
- **Extra subcommands:**
  - `lab.py color` (quick checks)
  - `sil64.py extract` (a mask PNG from a render or an ID colour — the cast tasks render on a transparent background)
  - `lab.py value --mask=alpha` (use the render's own alpha)
- **`sil64 --despeckle=0.002` (on by default):** it drops connected specks smaller than 0.2 % of a mask. One stray ID pixel or particle otherwise stretches the bounding box and ruins the IoU (tested). `--despeckle=0` gives the brief's exact behaviour.
- **Canvas widening in `sil64`:** a shape wider than 96 px at 64 px height (a dive, a piano) widens the shared canvas for every mask in the run, instead of being clipped.
- **`strip` labels and pages:**
  - Cells are labelled `#1…` by default and `f N` with `--label-frames`.
  - `--per-page` exists because an image reader shrinks tall strips; a warning suggests it past 3000 px.
  - Size is predicted from a sample so long strips render once.
- **`packets` extras:**
  - Extra kinds `crops` (the face and verb tests) and `pairs` (the 2D-vs-3D preference, with the candidate on a random side).
  - Formats `choice`, `yesno`, `ab` and `scores`, because the §6 row 19 tests need each of them.
  - Folder items for multi-page strips.
  - The build *refuses* rather than warns when a name would leak.
- **`rules` status codes:** SKIP when a region is not visible or has no reference wall, EXEMPT through a legend `exempt` (the lamp shade, the one light source of §3.7), INFO for classes with no rule.
- **Fonts:** all board text uses Nunito, because Lilita One lacks ≥ ≤ × and labels like "head ×1.2" need them.

## 6. Requests for other owners
1. **`r3d-content`** (`tools/ci/lint_all.sh`, which CI's `python-checks` job and pre-gate row 4 already run): add, after the art validators:
   `echo "[lint_all] python3 -m unittest tools/art3d/review/test_review.py"; python3 -m unittest tools/art3d/review/test_review.py || rc=1`
   The job already installs numpy and Pillow, and the tests take about 10 s. Without this, nothing in CI guards the toolset every lint depends on. Alternative: `r3d-qa` adds it as a step in `.github/workflows/ci.yml`.
2. **`r3d-docs`**: amendment text for TECH §11, "Review tooling", to insert after the capture bullet:
   > - **Measurements (R3D, index R14):** every colour, value, silhouette, strip, board and reviewer packet comes from
   >   `tools/art3d/review/` (`lab.py` CIELAB D65 + the REDESIGN §3.7 rules; `sil64.py` 64 px masks, IoU ≥ 0.80 = same
   >   family; `strip.py` numbered phone-scale strips ≤ 4 MB with marked accents; `boards.py` grids and before/after
   >   pairs at 1200×540 per cell; `packets.py` opaque `pkt_XX` packets + `prompt.md`, the key outside the packet dir, and
   >   `score` for the verdict tables). The CLI flags and JSON formats in its README are a contract; no task keeps a
   >   private sampler. Tests: `python3 -m unittest tools/art3d/review/test_review.py`.
3. **`r3d-tools-b`**: write `LintShot3D --pass=id`'s legend in the README's canonical shape (`{"regions": [{color, name, class, room, lit, wall, halo, exempt}]}`).
   - Classes: `wall`, `wainscot`, `floor`, `dressing`, `live_prop`, `character`, `other`.
   - Give each dressing piece `room` (or `wall`), dimmed neighbours `"lit": false`, and halo props `"halo": true` from `house3d.json`.
   - For the rule logic, call `lab.regions` / `lab.check_rules` / `sil64.run_masks` rather than shelling out.
   - Render the `mask` pass black on transparent.
4. **Orchestrator (optional, info only):** to smoke-test the R17 route end to end, have one fresh reviewer answer `docs/review/r3d-tools-a/packet_example/prompt.md`. Paste the answers to `docs/review/r3d-tools-a/reviewer_answers.md`, then run `packets.py score <SP>/work/r3d-tools-a/packet_example_key.json docs/review/r3d-tools-a/reviewer_answers.md`. Nothing waits on it.
5. **Import sidecars:** none needed. The review folders and `tools/` hold no Godot assets, and nothing was added under `game/`.

## 7. Verification commands (run from the repo root)
```bash
python3 -m unittest tools/art3d/review/test_review.py                      # 51 tests OK (~10 s)
python3 tools/art3d/review/lab.py value docs/review/lookdev/look-toy/ingame_kitchen.png \
  --mask=tools/art3d/review/fixtures/lookdev/hush_mask.png --json=<SP>/work/r3d-tools-a/value.json   # 11.9 % / 58.1 % FAIL
python3 tools/art3d/review/sil64.py masks tools/art3d/review/fixtures/masks --out=docs/review/r3d-tools-a/sil64_fixture.png
python3 tools/art3d/review/strip.py tools/art3d/review/fixtures/frames docs/review/r3d-tools-a/strip_fixture.jpg \
  --every=3 --marks=tools/art3d/review/fixtures/frames_marks.json --label-frames
```
**Full game suite and lint.** I ran them on the shared tree at 17:05–17:10 UTC, one slot:
- `tools/scripts/test_game.sh r3d-tools-a`: **1217 passed, 7 failed, 2 skipped** (1226 tests).
- `SANDBOX=r3d-tools-a tools/scripts/lint.sh`: **exit 0** (content has 0 errors and 27 warnings; the 2D and 3D animation lints have 0 errors).

My changes are Python and docs only, so none of the 7 failures come from this task. All are in other B1 tasks' work in progress, as index R10 anticipates. I fixed none of them. Owners:

| Owner | Failure |
|---|---|
| `r3d-cast-bellows` | `cast3d/test_bellows3d.gd` does not load: parse error at line 52, `Cannot infer the type of "per"` |
| `r3d-content` | `content/test_hides.gd` ×2: the Act-I one-hiding-spot validation |
| `r3d-content` | `content/test_view_data.gd::test_bands_and_steps_equal_the_placed_reach_targets`: `times_up` / `mirror_mirror` `step` is null against `house3d.json`'s `mime` |
| `r3d-content` | `solver/test_real_solutions.gd` ×2: the p00 fuzz regressions (`cmd_queued`; a soft-lock at 180 s) |
| `r3d-rig` | `rig3d/test_player_3d.gd::test_launch_is_deterministic_and_reset_reattaches`: the launch path changed |

The sandbox has been deleted.

## 8. Known gaps
- **No fresh reviewer was run.** This task has no agent tool. The packets are built and tested; the reviewers run later (R17).
- **The look-A masks and ID pass are hand-made:** a polygon plus flood fill, accurate to 1–2 px. One enclosed background pocket sits between Bellows' arm and his head. They are good enough to exercise the tools; the real ID and mask passes come from `r3d-tools-b`'s `LintShot3D`.
- **Rules judge medians.** A prop that is half saturated and half white can fail C* ≥ 45 on its median while still reading as loud. p10 and p90 are in the JSON for anyone who needs them. Hue is reported but no rule uses it.
- **Default strips at 1200×540 cells get very tall past about 20 frames.** Reviewers should get `--per-page=12 --cols=4`; the tool warns about this.

## 9. Hours
About 0.7 h of wall-clock time, 16:31–17:12 UTC:
- P0 landed at 16:47.
- Hardening and the real-image runs finished at 17:04.
- The full suite and lint ran 17:05–17:10.

That is well inside the S budget (P0 ≤ 2 h, about 3 h in total).
