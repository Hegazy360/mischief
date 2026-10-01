# r3d-qa — the R3D pre-gate, the slice tests, perf evidence, the APK and the row-19 packets

Branch `r3d` at `5b5a135` plus the r3d-qa working-tree changes (the orchestrator commits them). Pre-gate content hash
`910d23a982ac1d19`. Box: 4 CPU cores, llvmpipe (software GL), 1200×540, MSAA off; the timing rows ran with no other Godot or
Blender process on the box.

## 0. Phase 3 — the final pre-gate run and row 19 (2026-10-01, 09:43–10:36Z, alone)

**Verdict: FAIL.** `tools/scripts/pregate3d.sh --rows=1-7,9-18,20a`, then `--rows=19`, run alone under content hash
`eee8a789f5e192c7` (the sim tree `c31a69aac4e0f8dd` is unchanged, so row 8 keeps its 08:38Z result). This run also
exercises phase 1's evaluator fixes live:
- row 2 sees the 2 `tests/slice` files;
- rows 11 and 12 record the window share and C8 numbers;
- row 16 reads the profiler's real layout and FAILs on its own.

The record is [`pregate.json`](pregate.json), copied from `build/r3d/pregate.json`. The phase-1 copy is kept in the r3d-qa scratch dir.

| # | Row | Result | Key numbers |
|---|---|---|---|
| 1 | Import metadata | PASS | 1010 .import, 409 .uid |
| 2 | Full suite | PASS | 1270/1270, 0 failed, 0 skipped, 135 files incl. 2 `tests/slice` files; 322 s |
| 3 | Design lints --strict | PASS | 72 clips strict, 0 errors / 0 warnings / 0 missing; coverage 72; content / hotspot / IP 0 failed |
| 4 | Art + audio validators | PASS | 5 validators incl. gen_audio --check |
| 5 | Every route | PASS | 13 routes OK, 0 invariants, 0 catches on ideal; N01 ideal ★★★ 116.3, N02 ideal ★★★ 117.5 |
| 6 | Dead air (D1) | PASS | worst ⏩ ideal 8.1 % / required 4.8 % / slow 5.9 %; worst gap 5.47 s; edge share 0.221; N02 first prank 19.4 s |
| 7 | Planner proofs + g0 | PASS | --auto n01 6 / n02 5 / p00 2 lines; g0 ideal 23.6 s → g0_done |
| 8 | Fairness fuzz | PASS (08:38Z, sim tree unchanged) | 2400 runs, 0 invariants, 0 soft-locks |
| 9 | Set lint | PASS | 0 errors, 1 warning (N02 hall negative space 0.68 m, D13) |
| 10 | Screen-rect lint | PASS | 0 errors, 1 warning (N02 hall clock under the window at 16:9) |
| 11 | HUD lint | PASS | 0 errors, 1 warning: window share 38.1 % on P00 required (R15) |
| 12 | Visibility C8 | PASS | 26 route × mode runs, 0 violations in sim (shipped), 0 in lean; sim window share max 39.0 % (P00 required) |
| 13 | Gate 0 in 3D | PASS | g0_done; accent f 94; zoom 1.14 at the accent / 1.59 max; hit-stop 83 ms; ACHOO-RIA!; flipped bouffant; sink landing; tag 1/1; C8 0; draws p95 57; 0 compiles; Again ▶ 234 ms |
| 14 | Prologue in 3D | PASS | ideal: 7 laughs by 60 s, 4 cues, crowd ≤ 0.269 s, 0 doubles; slow: first laugh 6.63 s / first prank 27.58 s launch-relative |
| 15 | Other routes in 3D | PASS | 13/13, 0 script / engine errors; g0 + P00 0 fallbacks; N01 / N02 14–60 (info) |
| 16 | Frame budget (proxy) | **FAIL** | counts pass (draws p95 ≤ 82 / max ≤ 98, tris ≤ 101,392, 4 emitters, tex ≤ 103.4 MB, 0 compiles); view + HUD p50 2.78–3.12 / p95 4.07–4.61 ms (D14 3.5 / 8.0 met); **D14 spikes: 14 of our nodes / phases over 1 ms in the 60 slowest Prologue frames** (NightScene 4.33, AudioDirector 2.77, hush_apply 2.61, hush_view.mine 2.19, FxFreezeFrame 2.17, CameraDirector3D 2.13, bellows_apply 2.12, bellows rig_advance 1.87, Hud 1.85 ms …); whole-frame script time p50 3.03 / p95 4.39 / max 8.66 ms over 882 frames |
| 17 | Per-character budget | PASS | Hush 0.195 ms (runs 168–214 µs), 2 draws, 9812 tris, 48 bones; Bellows **0.240 ms** (runs 213–263 µs: 2 of 5 over 250), 4 draws, 9495 tris, 50 bones, + stool 1 draw / 450 tris apart (D16) |
| 18 | Flow, feedback, touch | PASS | retry 621 ms; tap feedback 1 frame; pause / back OK; tap accuracy 20/20 on 6 slice hotspots (25 tested), 0 neighbours; g0 Again ▶ live, P00 Next ▶ live frame 1 |
| 19 | Readability | **FAIL** | verb 7/8, spot 6/8, **crowded_yes 2/8** (bar ≤ 1), prefer_3d 8/8; gags: g0 + P00 sneeze 4/4/3, curtain call 3/3/3, **dizzy spin 3/3/4** (bar 4/4), picture 1/1/1, bonk 2/2/2, vase 1/2/1, squeak bit 1/3/1, relief 1/3/1 ([`readability.md`](readability.md)) |
| 20a | APK (local) | **FAIL** | 73.42 MB (73419843 B), sha256 `e60c5e7a9997711bb3f48e5c380b706f1ae83ab3c7387bee8c29e477e3d2ff19`, 3277 entries, 77 clip .res, 80 sidecars, excluded paths absent, boot_config OK, VIBRATE only, minSdk 24; **exported pack: 13 script errors (`ScriptProf3D`), Night does not build** (P0 unchanged, §5) |
| 20b | APK (CI) | pending the push | — |

The P0 (§5) is not applied: `game/view3d/world/world_view_3d.gd` still declares `var _prof: ScriptProf3D`. The owner pack is drafted in [`../r3d/index.md`](../r3d/index.md), with its "not ready to send" banner. Its images are:
- the stage door, shot on this tree;
- a new 2D-vs-3D cast board;
- the four complaint boards, the head check, the sneeze strips and the perf charts, all looked at.

The rows in §1 below are phase 1's run (09:29Z, hash `910d23a982ac1d19`). They are superseded by this table.

## 1. Pre-gate — `tools/scripts/pregate3d.sh` (r3d-index §6)

**Verdict: rows 1–15, 17 and 18 PASS · 16 FAIL on lead ruling D14's spike clause (every count and the p50 / p95 rule
pass; §3) · 20a FAIL (the exported APK does not boot the 3D game, §5) · 19 pending (the packets are built, not
scored).** `tools/scripts/pregate3d.sh [--rows=…] [--no-render] [--force] [--fresh]` runs the rows in
sandbox `r3d-qa`, one Godot process at a time, and writes `build/r3d/pregate.json` (copied here as `pregate.json`):
per row the command, pass, numbers, wall time and the content hash of its inputs (a row kept from an earlier run whose
inputs changed is reported STALE and fails the table).

| # | Row | Result | Key numbers | Wall |
|---|---|---|---|---|
| 1 | Import metadata | PASS | 1010 .import, 409 .uid sidecars | 0.0s |
| 2 | Full suite | PASS | 1270/1270 passed, 0 failed, 0 skipped, 135 files (tests/slice: 2 files) | 333.0s |
| 3 | Design lints --strict | PASS | 3D anim lint strict: 72 clips, 0 errors, 0 warnings, 0 missing; coverage3d 72 clips; content/hotspot/IP 0 failed | 13.0s |
| 4 | Art + audio validators | PASS | 5 validators OK (art, review toolset tests, gen_audio --check) | 18.0s |
| 5 | Every route | PASS | 13 routes all OK, 0 invariant violations, 0 catches on ideal; N01/N02 ideal n01 3★ 116, n02 3★ 118; g0 ideal g0_done | 26.0s |
| 6 | Dead-air gate (D1) | PASS | worst ⏩ dead air ideal 8.1 % / required 4.8 % / slow 5.9 % (bars 20/25/30), worst gap 5.47 s (≤ 12), edge share 0.221 (≤ 0.33), N02 first prank 19.43 s (≤ 25) | 0.0s |
| 7 | Planner proofs + g0 route | PASS | solve --auto: n01 script OK (6 lines), n02 script OK (5 lines), p00 script OK (2 lines); g0 ideal 23.6 s, ends g0_done | 151.0s |
| 8 | Fairness fuzz | PASS | 2400 runs (200 per bot × 4 bots × 3 final episodes), all OK, 0 invariant violations, 0 soft-locks | 5829.0s |
| 9 | Set lint | PASS | 0 errors, 1 warnings (n02_something_fishy hall negative_space x 6.82–7.50 m: 0.68) | 52.0s |
| 10 | Screen-rect lint | PASS | 0 errors, 1 warnings (n02_something_fishy hall window_overlap hall_clock: 572.7882) | 18.0s |
| 11 | HUD lint | PASS | 0 errors, 1 warnings (p00_curtain_up  window_share p00_required: 38.4 %) | 9.0s |
| 12 | Visibility C8 | PASS | 0 errors; C8 on every tick of 26 route×mode runs (13 solver routes × sim + lean): 0 violations in the shipped mode (sim), 0 in the other; window share in sim max 39 % | 182.0s |
| 13 | Gate 0 in 3D | PASS | ends g0_done; CHOO accent clip f 94.0 (94), punch-in zoom max 1.59, hit-stop 83.0 ms, caption ACHOO-RIA!, bouffant flipped, lands in the sink True, tag → Script pip 1/1, C8 0; window share 28 % (longest 6.4 s); draws p95 57.0, tris max 67533.0, tex 81.2 MB, shader compiles in PLAY 0 | 152.0s |
| 14 | Prologue in 3D | PASS | ideal (strict): 7 laughs by 60 s (≥ 6), 4 cues staged, crowd ≤ 0.27 s, 0 doubles, window 30 %; slow: first laugh 6.63 s / first prank 27.58 s launch-relative (≤ 10 / ≤ 30); required: 4 laughs by 60 s (info); every route ends prologue_done, C8 0 | 292.0s |
| 15 | Other routes in 3D | PASS | 13/13 scenarios OK, 0 script/engine errors; g0 + P00 0 fallbacks; N01/N02 fallbacks (info, R9): n01_ideal 34, n01_required 18, n01_slow 18, n02_ideal 60, n02_required 22, n02_slow 24, n01_caught 27, n01_chase 14, n01_meltdown 16 | 480.0s |
| 16 | Frame budget (proxy) | FAIL | g0: draws p95 57.0 / max 65.0, tris 67533.0, emitters 4, tex 81.2 MB, compiles 0, view+HUD p50 2.81 / p95 4.08 ms; n01_ideal_perf: draws p95 82.0 / max 99.0, tris 101392.0, emitters 4, tex 102.1 MB, compiles 0, view+HUD p50 3.04 / p95 4.56 ms; p00_ideal: draws p95 73.0 / max 81.0, tris 91215.0, emitters 4, tex 103.4 MB, compiles 0, view+HUD p50 3.02 / p95 4.57 ms; p00_required: draws p95 73.0 / max 83.0, tris 91115.0, emitters 4, tex 103.4 MB, compiles 0, view+HUD p50 2.96 / p95 4.65 ms; p00_slow: draws p95 73.0 / max 82.0, tris 92192.0, emitters 4, tex 103.4 MB, compiles 0, view+HUD p50 2.99 / p95 4.43 ms; perf3d.sh's own ≤ 4.0 ms line FAILs by design (D14 judges p50 ≤ 3.5 / p95 ≤ 8.0 on the proxy); **FAIL (D14 spike rule, re-evaluated from build/r3d/view3d_prof.json — the run's evaluator read an older profiler layout and passed it vacuously; fixed in pregate3d.sh):** 20 of our nodes / phases over 1 ms in the 60 slowest Prologue frames, worst NightScene 10.23 ms, WorldView3D.bellows_apply 7.28 ms, WorldView3D.bellows_view.rig_advance 7.16 ms, WorldView3D.props_cues 6.63 ms, WorldView3D.overlays 4.85 ms, WorldView3D.rest 4.47 ms, WorldView3D.caught_recorder 4.28 ms, StallsView 3.90 ms | 811.0s |
| 17 | Per-character budget | PASS | hush (hush/loco_run): CPU median of 5 0.160 ms (≤ 0.25), 2 draws, 9812 tris, 48 deform bones; set piece apart 0 draws / 0 tris; bellows (bellows/rx_sneeze_blast_a): CPU median of 5 0.234 ms (≤ 0.25), 4 draws, 9495 tris, 50 deform bones; set piece apart 1 draws / 450 tris | 186.0s |
| 18 | Flow, feedback, touch | PASS | retry 634 ms (wall 707 ms) vs max(1500, one frame 74 ms); tap feedback 1 frame(s); pause/back all OK; tap_accuracy min 20/20 on 6 slice hotspots, 0 neighbour hits; g0 Again ▶ live True, P00 Next ▶ live on frame 1 True | 192.0s |
| 20a | APK (local) | FAIL | debug APK 73.42 MB (≤ 150), sha256 8c4c4e2482869c64c85ce36099fe24c21892ae51d705f9ae1518f50e5c1e03d2, 3277 entries, 77 3D clip .res, 80 clip sidecars, excluded paths absent, boot_config start stage_door / view 3d / show_previews False / bellows_window sim / render {"msaa_3d": true, "render_scale": 1.0, "outline": true}, permissions android.permission.VIBRATE, minSdk 24; exported pack: 197 scripts, night FAIL view=3d world_view=null tick=-; **FAIL:** the exported pack: 13 script / parse errors, first ['SCRIPT ERROR: Parse Error: Could not find type "ScriptProf3D" in the current scope.', 'SCRIPT ERROR: Parse Error: Identifier "ScriptProf3D" not declared in the current scope.', 'SCRIPT ERROR: Compile Error: Failed to compile depended scripts.']; the exported pack does not build a 3D Night: [apkprobe] night FAIL view=3d world_view=null tick=- | 41.0s |
| 19 | Readability review | FAIL | verdicts pending (packets built, not scored): no readability.md; **FAIL:** docs/review/r3d-qa/readability.md missing (the reviewer run is pending) | 0.0s |

Notes on the numbers:
- Row 8 ran as three parallel per-episode processes (`fuzz.sh <episode> --runs=200`, merged): the serial `fuzz.sh all`
  was projected at ~3.5 h. Seeds 1–200 per bot are a superset of CI's `--runs=20`.
- Row 16 judges the view + HUD script time by lead ruling D14: on the proxy p50 ≤ 3.5 ms AND p95 ≤ 8.0 ms (met on
  every route: p50 2.8–3.0, p95 4.1–4.7 ms) AND no single node / phase of our code over 1 ms in the profiler's 60
  slowest frames (**not met**, §3); the ≤ 4.0 ms p95 of index row 16 is judged on the owner's device. The run's own
  evaluator read an older profiler layout and passed the spike clause vacuously; the table applies it to
  `build/r3d/view3d_prof.json` and `pregate3d.sh` now does too.
- Row 17 reports a borrowed set piece apart (`set_piece_draw_calls` / `set_piece_tris`, D16).
- Rows 11 and 12 carry the Bellows-window share per route (R15): the shipped `sim` mode peaks at 39 % on the Prologue
  `required` route (HUD-lint WARNING above 35 %; the owner-pack number). `d1_lean` (the lean-mode dead-air re-run) fails
  on several routes (edge share above ⅓) — the data behind shipping `sim`.
- Rows 9 / 10 warnings: the N02 hall's negative space (D13, a room at the 5-live-prop cap) and the N02 hall clock under
  the Bellows window at 16:9 — both N02, hidden in this build.

## 2. Slice integration tests — `game/tests/slice/` (§3.2)

Two files, 8 tests, ≈ 2.1 min headless, in the suite (row 2) and in CI:

- `test_slice_manifest.gd` — `SliceClips.build3d(["g0_sneeze","p00_curtain_up"])` lists the slice set (69 rows as built:
  r3d-integrate A30 / A32 dropped the clips g0 / P00 cannot play and added `freeze_5..8`), two rigs, no Figgis rows;
  every clip (+ the `rig_high / mid / low` bands) has its baked `.res` and v2 sidecar and matches the manifest's length
  (a loop only where the manifest allows one); every room of g0, P00 (errors) and the N01 / N02 previews keeps the
  REDESIGN §3.4 counts through the set lint's own facts (live ≤ 5, dressing ≤ 4, one hiding spot per room in Act I).
- `test_slice_routes.gd` — `g0_sneeze` ideal and the Prologue's ideal / required / slow routes, dumped by the solver's
  executor and replayed through the real NightScene with the 3D world stepped by hand (g0 at 60 fps with C8 checked on
  every frame in the shipped `bellows_window` mode; P00 at 30 fps): each ends by its own reason, 0 view fallbacks per
  clip id, 0 script / engine errors, exactly the four always-on HUD pieces on every sampled PLAY frame, the sneeze and
  ACHOO-RIA! / the dizzy spin and ALLEGRO-GO-GO! clips played.

`allowed_skips.md` lists every skip the suite may print (none today); an unlisted skip fails row 2.

## 3. Perf evidence (§3.4)

The charts are regenerated from the phase-3 run (§0); the profiler numbers in the paragraphs below are phase 1's.

![The 3D frame budget per route on the desktop proxy](perf/budgets.png)

![The per-character budget, median of 5 RigPerf3D runs](perf/rigs.png)

**llvmpipe frame rates are not phone numbers.** The proxy renders on the CPU (one render thread per process, R11):
its frame times (≈ 90–100 ms p95) say nothing about a phone's GPU. What the proxy does measure fairly are the
counts (draw calls, triangles, emitters, texture memory, shader compiles during PLAY — all inside budget on every
route) and the script time of the view + HUD (D14). **60 fps is judged on the owner's device** — the device log the
game writes shows it.

**The D14 spike clause fails.** ScriptProf3D on the Prologue ideal route (880 frames; whole-frame script time p50
3.04 / p95 4.94 / max 14.5 ms) finds 20 of our nodes or WorldView3D phases over 1 ms in its 60 slowest frames. The
recurring ones (frames over 1 ms of the 60 / worst): NightScene's own time 26 / 10.2 ms, `hush_apply` 20 / 3.1 ms,
`bellows_apply` 17 / 7.3 ms (`bellows_view.rig_advance` 6 / 7.2 ms, `bellows_view.mine` 6 / 3.3 ms),
`hush_view.rig_advance` 8 / 2.9 ms, `overlays` 7 / 4.9 ms; once or twice: `props_cues` 6.6, `rest` 4.5,
`caught_recorder` 4.3, StallsView 3.9, CameraDirector3D 2.5, Audio 2.2, `decals_fx` 1.9, Hud 1.7, House3D 1.6 ms. D14
says spikes are fixed at the source, not averaged away — request to r3d-view3d / r3d-integrate (the clip-start path in
`RigPlayer3D` advance / `set_look`, NightScene's per-frame measurement, the overlay placer, the caught recorder, the
cue / caption start).

## 4. The APK — row 20a (§3.5)

`tools/scripts/export_android.sh --sandbox r3d-qa --out build/r3d/mischief-debug.apk`: debug APK, **73.42 MB**
(73419843 bytes), **sha256 `8c4c4e2482869c64c85ce36099fe24c21892ae51d705f9ae1518f50e5c1e03d2`**. Contents: `art3d/`, `data/rigs3d/`, the 3D sidecars and the baked
`.res` clips present; `tests/ tools/ scenes/dev/ view3d/sandbox/ view3d/probe/ ui/demo/ _src/` absent;
`boot_config.json` = `start: stage_door`, `view: 3d`, `show_previews: false`, `bellows_window: sim`, `render:
{msaa_3d: true, render_scale: 1.0, outline: true}` (BootConfig defaults, no perf-probe answer); permissions VIBRATE
only; minSdk 24 (Android 7); landscape; `verify_android: OK` (the debug APK is re-signed on every export, so its
sha256 changes from run to run; the contents list does not). **But the exported pack fails** — see §5. Row 20b (the CI
artefact after the push) is the orchestrator's post-push confirmation.

## 5. P0 found by row 20a — the exported APK cannot build the 3D game

Row 20a unzips the APK's `assets/`, loads every shipped script headless and builds g0 in 3D. Result: 13 `SCRIPT ERROR`s
and `[apkprobe] night FAIL view=3d world_view=null` (`build/r3d/logs/row20a_probe.log`).
`game/view3d/world/world_view_3d.gd:136` declares `var _prof: ScriptProf3D` and `:171` calls
`ScriptProf3D.maybe_attach(self)`; `ScriptProf3D` lives in `game/view3d/probe/script_prof_3d.gd`, which the export
filter excludes (rightly — `view3d/probe/` must stay out of the APK). In the exported pack `WorldView3D` does not
compile, and the failure cascades to `character_view_3d.gd`, `caught_stager_3d.gd`, `night_scene.gd`,
`night_warm(er).gd`, `curtain_call.gd`, `curtain_apron.gd`, `curtain_bows_3d.gd` and `scenes/boot/boot.gd`: **the APK
would not start the game.** The source-tree suite cannot see this (the probe script is present there). The CI
android-preview APK of the pushed head would carry the same break.

**Fix (verified):** a soft load in `world_view_3d.gd` — `var _prof: Object = null`, and `if
ResourceLoader.exists(_PROF_PATH): _prof = load(_PROF_PATH).call("maybe_attach", self)` with `_PROF_PATH :=
"res://view3d/probe/script_prof_3d.gd"`. Exported from a scratch copy with that patch: 0 script errors, `[apkprobe]
night OK view=3d world_view=Node3D tick=112`. Owner: r3d-view3d / r3d-integrate (not r3d-qa's file). After the fix every
pre-gate row must be re-run (the inputs of every row change). TECH §12 now states the rule (shipped code reaches
dev-only scripts by soft load only).

## 6. Row 19 — the reviewer packets (§3.3) — scored in phase 3: [`readability.md`](readability.md) (FAIL: crowding 2/8, gags 3/9 at bar)

Built with `tools/art3d/review/packets.py` from the real game at 1200×540, captions off (NightScene `--no-captions`,
MSAA off), shuffled, opaque ids; **not scored and not shown to anyone yet**. The prompts and how to run them:
`reviewer_prompts.md`. The answer keys are outside the repository (r3d-qa's scratch directory).

| Folder | Test | Items | Pass |
|---|---|---|---|
| `packets/set_a/` | what is the player character doing | 8 frames | ≥ 7/8 |
| `packets/set_b/` | what happens if the neighbour uses the circled object | 8 frames | ≥ 6/8 (the gist) |
| `packets/set_c/` | is this screen crowded or confusing | 8 frames | ≤ 1/8 yes |
| `packets/set_d/` | the same moment drawn two ways (2D `r3d-ref2d` vs 3D, same ticks) | 8 pairs | 3D preferred ≥ 6/8 |
| `packets/set_e/` | every Prologue gag strip + the g0 sneeze, captions off | 9 strips | sneeze + dizzy spin ≥ 4 funny and readable, the rest ≥ 3, fresh ≥ 3 |

Choices made while building them: the verb question names the character by her look ("black-and-white striped top and
red beret" — the brief's "purple-and-white" describes the neighbour); the spot frames from Night 1 come from paused
NightScene shots on a crafted calm route (all four kitchen previews up) and from a real-time route that sees the
CONFISCATED box without taking the squeaker (the needs cloud only appears after the container was seen, which a
`--seek-tick` jump skips); two Night-1 3D sides of the 2D-vs-3D pairs are shot on the r3d Night-1 ideal route at the
same tick (the 2D route hides under `kitchen_table`, which the 3D set replaced with the pantry curtain); the g0 sneeze
payoff is left out of the pairs (its 2D frame shows the pun caption the 3D packets hide).

## 7. CI (§3.7)

`.github/workflows/ci.yml` (on `main`, `r3d`): import metadata → the suite (incl. `tests/slice/`) → `lint.sh --strict`
→ `lint3d.sh --screen --no-render --aspects=20x9,16x9,4x3` and `lint3d.sh --set --no-render --all-nights` (headless;
JSON uploaded with the solver reports) → `solve.sh all --route=all` → `fuzz.sh all --runs=20`; the Python job runs
`lint_all.sh --no-godot`. Every command was run locally on this tree: the suite (row 2), `lint.sh --strict` (row 3),
`lint3d --screen --no-render` (OK, 0 errors, 1 warning, 9 s) and `--set --no-render --all-nights` (OK, 0 errors,
1 warning, 2 skips — the render measures, 8 s), `solve.sh all` (row 5), the fuzz (row 8's seeds include CI's),
`lint_all.sh --no-godot` (row 4, incl. `gen_audio.py --check`), `check_import_meta.sh` (row 1). The last CI run on
`r3d` is the pre-flight (`9ca1db7`, CI + Android preview green); GitHub lists no run for the later heads — the run on
the next pushed head is the confirmation.

## 8. What the frames showed (requests for other tasks)

- **P0** — §5 (the APK).
- **D14 spikes** — §3 (row 16).
- Overlays over transient HUD: the gramophone's preview sits on the RUNNING GAG label (P00 ideal ~t 2190) and the
  honey's preview under the APPLAUSE meter during the squeak (t ~1050). OverlayPlacer should keep clear of the meter /
  fuse rects (r3d-hud / r3d-view3d).
- ACHOO-RIA! rig: the thought cloud covers her face, the ring sits over her arms, her feet hover above the stool seat
  (g0 ≈ t 180–200) (r3d-anim-hush-b / r3d-view3d).
- `act_dive` leaps away from the pantry toward the sink before she appears inside (g0 ≈ t 312–336) (r3d-anim-hush-b).
- Hush under the action button after the climb-in (P00 ≈ t 78–140) and during the squeak (r3d-view3d framing).
- Curtain call: the title sign covers Hush; Bellows wanders on behind "Night 1 ▶"; the Gag Reel inset still shows its
  pun caption with `--no-captions` (r3d-night).
- Weak gags to expect from the reviewers: the vase (tiny on screen), the squeak bit (mostly inside the window), the
  picture frame (muted), the relief (unclear).
- In the needs-cloud route the kitchen renders dark and desaturated for a few frames when Hush enters from the parlour
  (camera / room-light hand-off), then lights normally.

## 9. Deviations

- Row 8 split into three parallel per-episode fuzz processes (sim only) and ran while the packet frames were shot
  (two to three Godot processes at once); rows 1–7, 9, 10, 12 and 20a first ran with `--force` beside the last fuzz
  process, then **every row except 8 was re-run alone** for the table above.
- `pregate3d.sh` fixes after that run (the numbers above are unaffected): row 2 now requires the `tests/slice` files in
  the suite log; rows 11 / 12 record the C8 and window-share numbers (row 12's are read from
  `build/r3d/lint3d_visibility.json` above); row 16 applies D14's spike clause to the profiler's real layout (the
table above re-evaluates it from `build/r3d/view3d_prof.json`). The next full run records all three under the new
content hash.
- The two slice test scripts' `.uid` sidecars were added (row 1 caught them).
