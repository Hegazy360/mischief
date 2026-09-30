# r3d-content: report (final, 23:37Z)

Branch `r3d`, B1. P0 landed at 17:07Z, about 35 min after launch. P1 ran through 22:18Z. A container restart at 22:37Z
killed the N02 fuzz; I resumed at 22:40Z and re-ran it, then ran every exit gate on the final tree (23:23–23:36Z). The
landing lines are in `<SP>/work/r3d-content/LANDED.md`. Review folder: `docs/review/r3d-content/`, with index.md,
c2_delta.md, d1_lean.md, solve.md, fuzz.md, timelines/ and e2e/.

**Status: every acceptance item is done.** Two rows are red, and neither is in my area. `lint.sh --strict` fails only
the 2D clip-coverage check, which predates this work; r3d-integrate removes it. `lint_all --no-godot` fails only on
r3d-hud's Figgis SVGs.

## 1. What I built

### C1: `hides` and the sim's live mask (REDESIGN §6.2 C1, index §7.5)
- `game/data/episodes/{p00_curtain_up,g0_sneeze,n01_throat_tea,n02_something_fishy}.json` gain `"hides"`:
  - P00: pantry curtain and piano back.
  - g0: pantry curtain.
  - N1/N2: pantry curtain, piano back and coat cupboard.
  - Drafts are unchanged.
- `EpisodeDef.hides: PackedStringArray` and `EpisodeDef.has_hides: bool`. When `hides` is absent, every hiding spot of
  the rooms Hush may enter is live.
- `SimCtx.live_hotspots(db: ContentDB, episode: EpisodeDef) -> Dictionary` is static and pure (about 0.1 ms). It
  returns `{hotspot_id: "rig" | "take" | "hide" | "door" | "exit" | "stairs"}`, keys in house.json order. The rules:
  - **Rig point:** live iff a prank the Night **names** rigs there (Script lines incl. the Big Number, Double Acts,
    pranks.json `nights`). A knock-on pull-in does NOT count, so P00/g0's `kitchen_sink_tap` and N1's
    `parlour_bellows` stay furniture. REDESIGN §3.4's counts require this.
  - **Container:** live iff it is the source of an item one of those pranks needs.
  - **Hiding spot:** live iff it is listed in `hides`.
  - **Exits:** as before.
  - **Doors and stairs:** live only when they lead to a room Hush may enter tonight. The kitchen back door and the
    roped-off stairs are struck (REDESIGN §3.4, r3d-sets' request). `kitchen_window` stays untappable.
  - Nothing in a backstage room, or in a room she may not enter, is live.
  - World side: `world.ctx.live_mask: PackedByteArray` (one byte per hotspot index), `world.ctx.live_kind`,
    `world.ctx.is_live(hi) -> bool`.
- **The sim refuses struck hotspots.** A `SimHush` go, a pin, or a go while hidden/frozen/diving (which counts as a
  pin) on a struck hotspot produces the event `cmd_rejected {c: "go"|"pin", why: "struck", target: <id>}`. Hush does
  not move and the command is never queued.
  - Check order: unknown_hotspot → not_tappable → backstage → locked → struck.
  - `hotspot_state(id).enabled` is false for struck hotspots.
  - The Figgis hook (can't-fail) only yanks her into a live spot.
- **The mask per Night.** These counts equal REDESIGN §3.4 and are tested in tests/sim/test_live_mask.gd:

| Night | kitchen | parlour | hall | struck (a tap → `cmd_rejected struck`) |
|---|---|---|---|---|
| P00 | 2: honey, pantry curtain | 2: gramophone, piano back | 0 (backstage) | table, sink tap (TAP DANCE is only the sneeze's knock-on), kettle, pickle jar, fridge (+shelf), pantry shelf, back door; chaise, recliner, newspaper, chandelier, fireplace bellows, piano wedge, tea tray, fan |
| g0 | 2: honey, pantry curtain | 0 | 0 (backstage) | as P00, plus the gramophone and the piano back (g0 names only the sneeze) |
| N1 | 5: kettle, honey, pickle jar, sink tap, pantry curtain | 2: recliner, piano back | 2: CONFISCATED box, coat cupboard | table, fridge (+shelf), pantry shelf, back door; gramophone, newspaper, chaise, chandelier, bellows, wedge, tray, fan; clock case, phone, clock, mirror, piggy bank, stair rods, stairs |
| N2 | 3: fridge shelf, fridge, pantry curtain | 2: newspaper, piano back | 5: box, coat cupboard, phone, clock, mirror | table, honey, kettle, pickle jar, sink tap, pantry shelf, back door; gramophone, recliner, chaise, chandelier, bellows, wedge, tray, fan; clock case, piggy bank, stair rods, stairs |

  `hall_front_door` stays an exit (N1/N2).
- **Validation.** `ContentValidate._hides` checks:
  - ids are hiding hotspots in the Night's rooms, with no repeats;
  - the safety-net pulse, and every Director cue that targets a hiding spot, are listed;
  - Act 0–1 finals have one hiding spot per room (`ContentValidate.hides_per_room()`; a warning for drafts).

  The content lint runs the same JSON-level rules. It also checks that every solution `hide` / `go` / `pop_out to`
  step uses a live hotspot (`SolutionDef.validate_live`).

### C2: solution re-plans
- **`solutions/n01_throat_tea.json`:**
  - Every `kitchen_table` hide becomes `kitchen_pantry_curtain`: ideal ×4, required, slow, caught, meltdown ×2.
  - The chase starts behind the piano. She walks into his view at x 2400, is spotted, runs the doorway (the door slam
    is kept) and dives into the pantry as a direct running hide.
- **`solutions/n02_something_fishy.json`:** `face_to_face` and `face_to_face_lost` are **retired**, because
  `hall_clock_case` is struck in N2. The in-use lesson moves to Night 3. r3d-night has already dropped both e2e rows.
- **Timing deltas** (docs/review/r3d-content/c2_delta.md):
  - Each moved hide costs **+0.42–0.43 s** of tiptoe; REDESIGN predicted +0.43 s. Ideal hide 7 costs 0 s.
  - Durations, stars and applause are unchanged, with two exceptions:
    - N1 slow: +3.4 s. Its wrong tap is now a live spot in her start room, not the struck sink tap.
    - Chase: +0.8 s.
  - **N1 dead air ⏩** (ideal / required / slow) went from 7.9 / 4.8 / 2.1 % to **7.8 / 4.8 / 1.9 %**.
  - N2 ideal/required, P00 ideal/required and g0 ideal have final state hashes identical to the baseline.

### C3: `house.json` is frozen
`game/tests/content/test_house_frozen.gd` pins house.json (33287f5e…) and cold_sets.json (302e35a2…) to 67c7276. It also
checks that the two live slice stacks keep their 24 px gaps. No edit was requested or made.

### C4: view data (final, validated)
- **`game/data/view/previews.json`** `{version: 1, pranks: {<prank>: {pictogram: [ids], needs: item|null, combines:
  [{with, badge}]}}}`:
  - covers the 11 slice pranks with REDESIGN §4.3 ids;
  - `achoo_ria.combines = [{with: tap_dance, badge: to_sink}]`.
- **`game/data/anim/hush3d/rig_actions.json`** `{version: 1, tiers {q 48, s 90, b 150}, bands {low [0, 0.55] rig_low,
  mid [0.55, 1.40] rig_mid, high [1.40, 2.15] step_above_m 1.70 rig_high}, pranks {<prank>: {hotspot, tier, band, clip,
  prop_anim, held, step, glances, noise_rings}}}`.
  - Bands and steps are re-derived from `house3d.json`'s placed reach targets:
    - achoo_ria: high, `stool:kitchen_stool` (2.02 m);
    - times_up (2.05 m) and mirror_mirror (1.80 m): high, `"mime"`;
    - in_a_pickle: high at 1.67 m (tiptoe, no step);
    - lift_off: low (0.28 m);
    - the other six: mid.
  - Re-checked at 22:45Z against the latest house3d.json (after r3d-sets' fix passes, D11 staging): all 11 match. The
    fridge shelf at y 0.95 is still mid.
  - Own clips: achoo_ria and allegro_go_go. The rest are null and use the band clip.
  - `held` items: pepper_pot, squeaker, magnifier, kipper.
- **`ViewDataLint`** (`game/tools/lint/view_data_lint.gd`, inside the content lint) checks:
  - ids resolve and every slice prank is covered;
  - tiers equal pranks.json prep, and hotspots equal the rig point;
  - against house3d.json: the band equals the band of the placed reach target's world y, and the step equals
    `reach_pos.step`;
  - a target above 1.70 m must have a step.

  `tests/content/test_view_data.gd` checks the same.

### R15: the Bellows-window reason and `d1_lean`
- `SimVisibility.pip_reason(w: SimWorld) -> StringName` returns `&""` | `&"room"` | `&"heading"` | `&"rigging"` |
  `&"adjacent"`. Heading and rigging win over adjacent. It is pure and allocation-free. `pip_shows` is unchanged,
  which tests/sim/test_pip_reason.gd proves on every tick of real runs. `micro_gag` events carry `pip_reason`.
- In the solver, every report row has `d1_lean {dead_air_ff_pct, max_gap_ff_s, edge_share, beats {room, pip, edge,
  hidden, adjacent_pip}, ok, fail}`, plus a summary-line and markdown column. Timelines draw adjacency-only PiP beats in
  light blue.
- **Result: lean does NOT pass D1** (docs/review/r3d-content/d1_lean.md).
  - Lean dead air and gaps equal the gate's.
  - But the edge badge carries 37–62 % of the beat credit on 7 of 9 gated routes, against a ⅓ cap (ruling L1).
  - Only N2 slow (0.29) and P00 slow (0.16) are OK.
  - **So `bellows_window: "sim"` stays the default.**

### Lints, scripts, invariants
- `tools/scripts/lint.sh` forwards `lint_anim.gd -- --format=3d --scope=g0,p00` (plus `--strict` and
  `--json=<out>_anim3d.json`).
- The content lint gains 3D coverage (`BeatLint.coverage3d`): every clip of
  `SliceClips.build3d(["g0_sneeze","p00_curtain_up"])` plus `hush/rig_high|mid|low` must exist as a v2 sidecar.
  - It warns, and is an error under `--strict`.
  - N01/N02 rows are info.
- Invariant **rule 13** (`Invariants.rule13_struck`): every go/pin on a struck hotspot is answered the same tick by
  `cmd_rejected struck`, and no `hush_go` / `hush_arrive` / `hide` names one. In the fuzz, random taps land on a struck
  hotspot 1 in 4.
- **SolverData twin of the mask:** `live_hotspots(ep)`, `live_kind`, `is_live`, `live_hides`, `struck_hotspots`,
  `named_pranks`, `hush_rooms`, `fixup_hold_activities`.
  - `nearest_hiding(..., ep_id)` skips struck spots.
  - The planner's escape never runs into a backstage or locked room.
  - The slow persona's wrong tap is a live unused spot, in her start room only.
  - A test proves the twin equals `SimCtx.live_hotspots` on all 13 episodes.
- `solve.sh --baseline` lists a baseline route that is gone from its solution file as "absent (retired)", never as a
  failure.
- New tools: `tools/content/c2_delta.py` and `tools/content/d1_lean_md.py`.
- `tools/ci/lint_all.sh` now runs `python3 -m unittest tools/art3d/review/test_review.py` (51 tests OK).

### Fixes forced by the fuzz (all route-neutral)
1. **A tap on the hiding spot she is in.** A go or pin while she is HIDDEN or DIVING now clears any pin and answers
   `cmd_rejected {why: "here"}`.
   - Before, it pinned her own spot and POP OUT dived straight back in. The fuzz found this as a soft-lock (P00 seeds
     41/97).
   - The executor ignores "here".
2. **`director.fixup_holds` [{kind, until}]** is a new optional episode field (`EpisodeDef.fixup_holds`, validated). A
   fix-up of that kind does not end while `until` is false.
   - P00 uses `{"kind": "MIRROR", "until": "rigged:allegro_go_go"}`: after the sneeze he primps at the hall mirror until
     the lever is set.
   - Without it the Prologue could lose its spin for good (fuzz seeds 9/21/77).
   - Every authored route rigs the lever inside the 4 s fix-up, so no route hash changed.
   - Held fix-ups are exempt from rule 9's 60 s progress check.
3. **Invariant rule 3 false positive.** A catch on the same tick as a `pop_out` from that spot no longer counts as a
   catch in the spot. She popped out mid-chase into his arms (N1 hider seeds 14/71/75/103/105). A pop_out from another
   spot, or on an earlier tick, still flags. No sim change.

## 2. Verification
The final gates ran on the final tree (23:23–23:36Z) with nothing else running, one Godot process at a time, in sandbox
`r3d-content`:

| gate | result |
|---|---|
| `solve.sh all --route=all --report=… --timeline=… --baseline=<SP>/work/r3d-pre/solve_before.json` | **12/12 OK, 0 new failures**; `n02 face_to_face*` absent (retired) |
| `solve.sh all --auto` | N01 auto OK (6 lines, lines alone, ★★★ reachable, soft-lock OK); N02 auto OK (5 lines …); P00 auto OK (can't-fail) |
| `solve.sh g0_sneeze --route=ideal` | OK, 23.6 s, ends by `g0_done`, hash identical to baseline |
| D1 (⏩) ideal / required / slow | P00 3.0 / 1.8 / 5.9 %; N1 7.8 / 4.8 / 1.9 %; N2 6.9 / 1.9 / 1.6 %. Worst gap ≤ 5.5 s (gated routes; caught 6.2 s); edge share ≤ 0.22 on gated routes; N2 first prank 19.4 s |
| stars / applause | N1 ideal ★★★ 116; N2 ideal ★★★ 118; required ★ 44 / 59; P00 `[null, null, null]`; 0 catches on ideal; 0 invariant violations |
| `fuzz.sh <ep> --runs=200`, 4 bots each | P00 800/800, N01 800/800, N02 800/800 (N02 re-run at 22:49–23:23Z, in two halves); **0 soft-locks, 0 invariant violations** (rules 3 and 13 included). Table: `docs/review/r3d-content/fuzz.md` |
| `lint.sh` | **OK** (0 lints failed) |
| `lint.sh --strict` | content rules 0 errors; **3D coverage 77/77 OK**; hotspot OK; IP OK; lint_anim 2D 0 errors; **lint_anim 3D strict 77 clips, 0 errors, 0 warnings**. RED only on the 2D clip coverage 103/137 (see below) |
| `tools/ci/lint_all.sh --no-godot` | RED only on `tools/art/hush/validate.py` × r3d-hud's Figgis SVGs; everything else OK |
| full suite `test_game.sh r3d-content` | **1510 passed, 0 failed, 0 skipped** (166 files) |

The 2D clip coverage failure predates this work (since Stage 2). It stays until r3d-integrate removes the 2D check
(index §5.4); I left that check alone, as the brief says.

**LOOK (§6)** in the real 3D game:
- Command: `E2E_SANDBOX=r3d-content tools/scripts/e2e.sh n01_ideal --max-s=45 --shot-seq=… --every=30 --count=80`.
- It passed, cut at 45 s by design: 0 script / engine errors, 0 shader compiles in PLAY, draw p95 82, 105k tris,
  5 laughs, first prank 17.5 s, PiP share 0.10.
- 13 fallbacks, all N01-only Bellows clips (info, R9).
- Strips (1200×540 frames, read at full size): `docs/review/r3d-content/e2e/n01_pantry_hides.jpg` and
  `n01_overview.jpg`.
- **Verdict: yes, and it is fair.**
  - The kitchen has no table any more. The pantry curtain is the room's one lit hiding spot, marked by its halo and the
    floor ring.
  - Hush tiptoes to it and dives. Her eyes peek through the curtain while Bellows walks in, still thinking of tea.
  - The dive lands before he clears the doorway (`hide watched: false`).
  - On the second visit she pops out behind his back, rigs the pickle jar and slips back in.
- Solver timelines (`timelines/`): the pantry hides add no dead-air stretch.

## 3. Contracts others use
- `SimCtx.live_hotspots(db, episode) -> Dictionary`; `world.ctx.is_live(hi)`; `world.ctx.live_kind`;
  `hotspot_state(id).enabled`.
- `cmd_rejected {c, why: "struck" | "here", target}`, plus the older whys, which have no target.
- `SimVisibility.pip_reason(w) -> StringName`; `micro_gag.pip_reason`.
- `previews.json` and `rig_actions.json` (schemas above; index §7.10).
- Episode fields `hides` (C1) and `director.fixup_holds` (new).
- Solver report `d1_lean`; `Metrics.d1_lean(log, laugh_fn, persona)`; `Metrics.lean_text(report, color)`.
- `SolverData.live_hotspots / live_kind / live_hides / struck_hotspots / is_live / named_pranks / hush_rooms /
  fixup_hold_activities`.
- Fresh route command dumps are in `<SP>/work/r3d-content/cmds/<episode>_<route>.cmds.json`. r3d-view3d already
  refreshed its N01 fixtures from them.

## 4. Deviations (with reasons)
1. **Knock-on pull-ins don't make a rig point live** (P00/g0 sink tap, N1 fireplace bellows). REDESIGN §3.4's counts
   require it. The sim still keeps the knock-on prank in the Night, so a sneeze can still land in the sink.
2. **Doors and stairs** are live only when they lead where she may go tonight, instead of "as today". REDESIGN §3.4
   outranks the index here, and r3d-sets asked for it.
   - The rule is **kept**; r3d-sets' `SetList.local_live` mirrors it.
   - Only the kitchen back door and the N1/N2 stairs change. No route used them.
3. `live_mask` is a byte per hotspot (PackedByteArray), not an int bit mask, because there are 60+ hotspots.
4. **Two sim fixes and a new episode field** (`director.fixup_holds`) were needed to make fuzz 200 clean. They remove
   real player-facing traps and change no authored route.
5. The slow persona's wrong tap happens only in her start room. The fuzz random bot's taps are weighted toward built
   hotspots, with a struck one 1 in 4.
6. The §6 LOOK ran with `--max-s=45 --count=80` instead of the brief's `--count=60`. The longer count covers both
   kitchen pantry visits (ticks 394 and 1613); the rest of the route is parlour and hall.

## 5. Requests
- **r3d-integrate (CI-P0, D14): the Figgis SVGs.** `tools/art/hush/validate.py` fails on
  `game/art/chars/figgis/figgis_{chip,point,proud,psst,shh}.svg`: `<desc>` not allowed, 17–20 colours (max 10), and
  paint inside the 3 px margin. Conform the SVGs, or scope the validator for R7's vinyl restyle. Until then
  `lint_all.sh --no-godot` stays red.
- **r3d-integrate: the 2D coverage check.** When the 2D path goes (§5.4), drop the 2D clip-coverage check from
  `game/tools/lint/beat_lint.gd` / `content_lint.gd`. That is the only red row in `lint.sh --strict`. It is my file; I
  left it alone per the brief. The 3D coverage check stays.
- **r3d-view3d / r3d-night / r3d-integrate (info): the Prologue mirror hold.** In a dawdling Prologue, Bellows may
  now stay at the hall mirror past the fix-up's 4 s: `fixup_mirror` is held and the bubble ring is hidden while held.
- **Orchestrator (R15):** keep `bellows_window: "sim"`. `d1_lean` fails the ⅓ edge-share cap on 7 of 9 routes.
- **R3 (D13 follow-up):** if N2's hall is re-spaced in `house.json`, C3's hash pin in `test_house_frozen.gd`, the
  solver baseline and the N2 routes must be re-cut together.
- Closed since the draft:
  - r3d-anim's `rig_achoo_ria` L10: lint_anim 3D now has 0 errors.
  - r3d-view3d's N01 fixtures were refreshed at 18:51Z.
  - r3d-night dropped the `n02_face_to_face*` e2e rows.

## 6. Amendment text for r3d-docs / r3d-qa
**TECH §3.10**, already landed by r3d-docs. Corrections:
- "a container iff it is the source of an item one of the Night's *named* pranks needs";
- "exits as before; doors and stairs only when they lead to a room Hush may enter tonight (the kitchen back door and
  the roped-off stairs are struck in Act I)";
- "`SimCtx` stores it as a byte per hotspot (`live_mask`, `is_live(hi)`)";
- add: "`micro_gag` events carry `pip_reason`".

**TECH §3.5 (commands):** "`cmd_rejected {c, why, target}`: why `struck` (a hotspot not on stage tonight) and `here`
(a go / pin on the hiding spot she is in or diving into; it clears any pin, and POP OUT then goes nowhere)."

**TECH §4.6 (episodes):** "`hides` (optional list of hiding hotspots; one per room in Act I finals);
`director.fixup_holds` [{kind: DRY|SINK|HONEY|MIRROR, until: a gate condition}]: a fix-up of that kind does not end
while `until` is false (the Prologue: the mirror waits for the lever)."

**TECH §8.6 (invariants):** "13. no command on a struck hotspot is accepted: every go/pin on one is answered the same
tick by `cmd_rejected struck`; no `hush_go`, `hush_arrive` or `hide` names one (fuzz random taps include struck
hotspots, 1 in 4). Rule 3 ignores a catch on the tick she pops out of that spot. Rule 9's progress check exempts held
fix-ups like uncapped gates."

**TECH §8.5 (report):** "`d1_lean`: the D1 metric with adjacency-only PiP beats visible only with an emote (as edge
beats, inside the ⅓ cap); an info column; it decides R15."

**GDD §2.3 (Prologue, v1.2):** "After the sneeze he primps at the hall mirror until the gramophone lever is set (the
sparkle cue points at it); only then does he come back to warm up, so the Prologue cannot lose its spin."

**GDD §3.4 / §7.2:** as landed by r3d-docs (v1.2), which matches the build. Add: "a tap on the spot she is hiding in
keeps her there (it cancels a GO ▶ pin)."

## 7. Known gaps
- None open in my area.
- The N01/N02 3D clip coverage (64 N01/N02-only clips) is info by R9.
- The strict 2D-coverage row goes away with r3d-integrate §5.4.

## 8. Hours
About 7.1 h of wall clock: 16:32Z → 22:37Z (killed by the restart), then 22:40Z → 23:37Z.
