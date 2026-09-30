# r3d-content — review index

The two content changes of REDESIGN_3D §6.2 (C1 `hides` + the sim's live mask, C2 the solution re-plans), the view
data the 3D slice reads per prank (C4 `previews.json`, `rig_actions.json`), the Bellows-window reason (R15
`pip_reason`, `d1_lean`) and every gate re-run. Branch `r3d`; baseline = `solve.sh all` at 9ca1db7 (pre-flight).

## The live mask per Night (`SimCtx.live_hotspots`, = REDESIGN §3.4 "Live")

| Night | kitchen | parlour | hall | struck (a tap → `cmd_rejected {why: "struck"}`) |
|---|---|---|---|---|
| P00 | 2 — honey, pantry curtain | 2 — gramophone, piano back | 0 (backstage) | kitchen table, sink tap (TAP DANCE is only the sneeze's knock-on), kettle, pickle jar, fridge (+shelf), pantry shelf, back door; chaise, recliner, newspaper, chandelier, fireplace bellows, piano wedge, tea tray, fan |
| g0 | 2 — honey, pantry curtain | 0 | 0 (backstage) | as P00 + the gramophone and the piano back (the Gate-0 scene names only the sneeze) |
| N1 | 5 — kettle, honey, pickle jar, sink tap, pantry curtain | 2 — recliner, piano back | 2 — CONFISCATED box, coat cupboard | table, fridge (+shelf), pantry shelf, back door; gramophone, newspaper, chaise, chandelier, bellows, wedge, tray, fan; clock case, phone, clock, mirror, piggy bank, stair rods, stairs (roped off) |
| N2 | 3 — fridge shelf, fridge, pantry curtain | 2 — newspaper, piano back | 5 — box, coat cupboard, phone, clock, mirror | table, honey, kettle, pickle jar, sink tap, pantry shelf, back door; gramophone, recliner, chaise, chandelier, bellows, wedge, tray, fan; clock case (C2), piggy bank, stair rods, stairs |

Plus architecture that stays tappable: `hall_front_door` (exit, N1/N2). Doors and stairs are live only when they lead
to a room Hush may enter tonight; the kitchen window stays untappable.

## Gates (§4.6)

| gate | result |
|---|---|
| `solve.sh all --route=all --baseline=` | 12/12 OK, **0 new failures**; the retired `n02 face_to_face*` reported "absent" (`solve.md`) |
| `solve.sh g0_sneeze --route=ideal` | OK, ends by `g0_done`, final state hash identical to the baseline |
| `solve.sh all --auto` | N01, N02, P00: script, lines alone, ★★★ (authored), soft-lock proofs OK |
| D1 (gate ⏩) | P00 3.0 / 1.8 / 5.9 %, N1 7.8 / 4.8 / 1.9 %, N2 6.9 / 1.9 / 1.6 % (ideal / required / slow); worst gap ≤ 5.5 s; edge share ≤ 0.22 (ruling L1); N2 first prank 19.4 s |
| stars / applause | N1 ideal ★★★ 116, N2 ideal ★★★ 118, required ★ 44 / 59, P00 `[null, null, null]` |
| fuzz 200 / episode | P00, N01, N02 × random / reckless / hider / bait: **2400/2400 OK, 0 soft-locks, 0 invariant violations** — `fuzz.md` (rule 13 — no command on a struck hotspot accepted — included; rule 3 no longer flags a catch on the tick she popped out of her spot) |
| `lint.sh --strict` (23:26Z) | content rules 0 errors; **3D coverage OK (77/77: g0 + p00 + rig_high/mid/low)**; N01/N02-only 3D clips 64 missing (info); hotspot OK; IP OK; lint_anim 2D 41 clips 0 errors; **lint_anim 3D strict 77 clips, 0 errors, 0 warnings**. The one RED row: the 2D clip coverage 103/137 (pre-existing since Stage 2; stays until `r3d-integrate` drops the 2D check, index §5.4) |
| `lint.sh` | OK (0 lints failed) |
| `tools/ci/lint_all.sh --no-godot` (22:44Z) | RED only on `tools/art/hush/validate.py` × the new Figgis SVGs (`r3d-hud`, request filed); now also runs the R14 review toolset tests (`tools/art3d/review/test_review.py`, 51 OK — r3d-tools-a's request) |
| full suite (23:35Z) | `test_game.sh r3d-content`: **1510 passed, 0 failed, 0 skipped** (166 files) |
| N1 in the real 3D game (§6 LOOK) | `e2e.sh n01_ideal --max-s=45 --shot-seq` PASS (cut at 45 s by design): 0 script / engine errors, 0 shader compiles in PLAY, draw p95 82, 5 laughs, first prank 17.5 s; 13 fallbacks = N01-only Bellows clips (info, R9) — `e2e/` |

## Artefacts (one line each: what it shows, what to judge)

- `c2_delta.md` — Night 1 before/after per route and per moved hide: judge that each kitchen hide costs ≈ +0.43 s and
  nothing else moved (stars, applause, dead air).
- `d1_lean.md` — the R15 lean dead-air check per route: judge the verdict (lean fails only the ⅓ edge-share cap; ship
  `bellows_window: "sim"`).
- `timelines/<episode>_<route>.png` — the solver timelines (rooms, Bellows' state, "?", input, laughs, beats — light
  blue = adjacency-only PiP beats, the ones `lean` hands to the edge badge — dead air, ⏩, events): judge that no
  stretch of dead air grew after the re-plans (N1 ideal: the pantry hides).
- `solve.md` — the solver table of this tree (incl. the `d1_lean` column).
- `fuzz.md` — fuzz 200 per final episode: judge 0 violations.
- `e2e/n01_pantry_hides.jpg` — N1 ideal in the real 3D game, both pantry visits (f 300–390: tiptoe to the only lit
  hiding spot of the kitchen, dive, eyes behind the curtain as Bellows walks in for his tea; f 1290–1590: pop out behind
  his back, rig the pickle jar, back in): judge that the pantry reads as THE hiding spot (halo + floor ring) and that the
  dive lands before he can see her.
- `e2e/n01_overview.jpg` — the first 45 s of that run, every 30 frames (the room is calm: no kitchen table, one hiding
  spot, five lit props).
