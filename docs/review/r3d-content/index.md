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
| fuzz 200 / episode | see `fuzz.md` (rule 13 — no command on a struck hotspot accepted — included) |
| `lint.sh --strict` | content rules 0 errors; hotspot OK; IP OK; RED rows: 2D clip coverage 103/137 (pre-existing since Stage 2, until `r3d-integrate` drops the 2D check), 3D coverage 70/77 g0+p00 clips without a v2 sidecar (the animation keys are still authoring), lint_anim 3D 1 error (`rig_achoo_ria` L10, `r3d-anim`) |
| `tools/ci/lint_all.sh --no-godot` | RED only on `tools/art/hush/validate.py` × the new Figgis SVGs (`r3d-hud`, request filed) |
| full suite | 1376 passed, 0 failed, 1 skipped |

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
