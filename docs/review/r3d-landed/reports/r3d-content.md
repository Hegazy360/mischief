# r3d-content — report

Branch `r3d`, B1. P0 landed at 17:07Z (≈ 35 min after launch); P1 through 18:50Z. Landing lines:
`<SP>/work/r3d-content/LANDED.md`. Review folder: `docs/review/r3d-content/` (index.md, c2_delta.md, d1_lean.md,
solve.md, fuzz.md, timelines/).

## 1. What I built

### C1 — `hides` and the sim's live mask (REDESIGN §6.2 C1, index §7.5)
- `game/data/episodes/{p00_curtain_up,g0_sneeze,n01_throat_tea,n02_something_fishy}.json`: `"hides"` (P00 pantry
  curtain + piano back; g0 pantry curtain; N1/N2 pantry curtain + piano back + coat cupboard). Drafts unchanged.
- `EpisodeDef.hides: PackedStringArray`, `EpisodeDef.has_hides: bool` (absent → every hiding spot of the rooms Hush may enter).
- `SimCtx.live_hotspots(db: ContentDB, episode: EpisodeDef) -> Dictionary` (static, pure; ≈ 0.1 ms):
  `{hotspot_id: "rig" | "take" | "hide" | "door" | "exit" | "stairs"}`, keys in house.json order.
  - rig point live iff a prank the Night **names** rigs there (Script lines incl. the Big Number, Double Acts,
    pranks.json `nights`; a knock-on pull-in does NOT count — so P00/g0's `kitchen_sink_tap` and N1's `parlour_bellows`
    stay furniture, which is what REDESIGN §3.4 counts);
  - container iff it is the source of an item one of those pranks needs;
  - hiding spot iff listed in `hides`;
  - exit as today; **door / stairs only when they lead to a room Hush may enter tonight** (the kitchen back door and
    the roped-off stairs are struck — REDESIGN §3.4, r3d-sets' request); `kitchen_window` stays untappable;
  - nothing in a backstage room or a room she may not enter.
  - World side: `world.ctx.live_mask: PackedByteArray` (a byte per hotspot idx — there are > 63 hotspots, so not an
    int bit mask), `world.ctx.live_kind`, `world.ctx.is_live(hi) -> bool`.
- The sim refuses struck hotspots: `SimHush` go, pin, and a go while hidden/frozen/diving (= a pin) →
  event `cmd_rejected {c: "go"|"pin", why: "struck", target: <id>}`; she does not move; never queued. Check order:
  unknown_hotspot → not_tappable → backstage → locked → struck. `hotspot_state(id).enabled` is false for struck.
  The Figgis hook (can't-fail) only yanks her into a live spot.
- Counts (tests/sim/test_live_mask.gd, = REDESIGN §3.4): P00 kitchen 2 / parlour 2 / hall 0; g0 2 / 0 / 0; N1 5 / 2 / 2;
  N2 3 / 2 / 5. Full per-Night live/struck lists: `docs/review/r3d-content/index.md`.
- Validation: `ContentValidate._hides` (ids are hiding hotspots in the Night's rooms, no repeats, the safety-net
  pulse and every Director cue that targets a hiding spot are listed; one hiding spot per room in Act 0–1 finals —
  `ContentValidate.hides_per_room()`, a warning for drafts). Content lint: the same JSON-level rules + every solution
  `hide` / `go` / `pop_out to` step uses a live hotspot (`SolutionDef.validate_live`).

### C2 — solution re-plans
- `solutions/n01_throat_tea.json`: every `kitchen_table` hide → `kitchen_pantry_curtain` (ideal ×4, required, slow,
  caught, meltdown ×2); chase: starts behind the piano, walks into his view (x 2400), is spotted, runs the doorway
  (door slam kept) and dives into the pantry (a direct running hide).
- `solutions/n02_something_fishy.json`: `face_to_face` and `face_to_face_lost` **retired** (hall_clock_case struck).
- Measured (docs/review/r3d-content/c2_delta.md): **+0.42–0.43 s per moved hide** (REDESIGN predicted +0.43 s);
  durations, stars and applause unchanged except N1 slow +3.4 s (its wrong tap) and chase +0.8 s. N1 dead air ⏩
  7.9 / 4.8 / 2.1 % → **7.8 / 4.8 / 1.9 %**. N2 ideal/required, P00 ideal/required and g0 ideal: final state hashes
  identical to the 9ca1db7 baseline.

### C3 — `house.json` frozen
`game/tests/content/test_house_frozen.gd` pins house.json (33287f5e…) and cold_sets.json (302e35a2…) to 67c7276 and
checks the two live slice stacks keep their 24 px gaps. No edit was needed or made.

### C4 — view data (final; validated)
- `game/data/view/previews.json` `{version: 1, pranks: {<prank>: {pictogram: [ids], needs: item|null, combines:
  [{with, badge}]}}}` — the 11 slice pranks, REDESIGN §4.3 ids (r3d-hud's `game/art/ui/previews/*.svg` use them);
  `achoo_ria.combines = [{with: tap_dance, badge: to_sink}]`.
- `game/data/anim/hush3d/rig_actions.json` `{version: 1, tiers {q 48, s 90, b 150}, bands {low [0, 0.55] rig_low, mid
  [0.55, 1.40] rig_mid, high [1.40, 2.15] step_above_m 1.70 rig_high}, pranks {<prank>: {hotspot, tier, band, clip,
  prop_anim, held, step, glances, noise_rings}}}`. Bands and steps re-derived from r3d-sets' placed reach targets:
  achoo_ria high `stool:kitchen_stool`; times_up (2.05 m) and mirror_mirror (1.85 m) high `"mime"`; in_a_pickle high
  (1.67 m, tiptoe, no step); lift_off low; the other six mid. Own clips: achoo_ria, allegro_go_go; the rest null → the
  band clip. `held`: pepper_pot, squeaker, magnifier, kipper.
- `ViewDataLint` (`game/tools/lint/view_data_lint.gd`, in the content lint): ids resolve, every slice prank covered,
  tiers = pranks.json prep, hotspots = rig_point, and with house3d.json: band = the band of the placed reach
  target's world y (computed independently: floor + rect bottom + visual_offset.y + reach_target.y × scale), step =
  `reach_pos.step`, and a target above 1.70 m must have a step. `tests/content/test_view_data.gd` checks the same.

### R15 — the Bellows-window reason and `d1_lean`
- `SimVisibility.pip_reason(w: SimWorld) -> StringName`: `&""` | `&"room"` | `&"heading"` | `&"rigging"` |
  `&"adjacent"` (heading and rigging win over adjacent; pure, allocation-free; `pip_shows` unchanged — proved on every
  tick of real runs, tests/sim/test_pip_reason.gd). `micro_gag` events carry `pip_reason` (String).
- Solver: every report row has `d1_lean {dead_air_ff_pct, max_gap_ff_s, edge_share, beats {room, pip, edge, hidden,
  adjacent_pip}, ok, fail}`; summary line + markdown column; timelines draw adjacency-only PiP beats light blue.
- **Result (docs/review/r3d-content/d1_lean.md): lean does NOT pass D1.** Every adjacency-only beat carries an emote,
  so lean dead air and gaps are identical to the gate, but the edge badge then carries 37–62 % of the beat credit on 7
  of 9 gated routes (cap ⅓, ruling L1; OK only N2 slow 0.29, P00 slow 0.16). By R15 the shipped default stays
  `bellows_window: "sim"`.

### Lints, scripts, invariants
- `tools/scripts/lint.sh`: forwards `lint_anim.gd -- --format=3d --scope=g0,p00` (+ `--strict`, `--json=<out>_anim3d.json`)
  when `game/data/anim/hush3d/` exists and lint_anim.gd supports `--format=3d`.
- Content lint 3D coverage (`BeatLint.coverage3d`): every clip of `SliceClips.build3d(["g0_sneeze","p00_curtain_up"])`
  + `hush/rig_high|mid|low` must exist as a v2 sidecar — WARN, errors under `--strict`; N01/N02-only rows as info.
  The 2D coverage check is unchanged.
- Invariant **rule 13** (`Invariants.rule13_struck`): every go/pin on a struck hotspot is answered the same tick by
  `cmd_rejected struck`, and no `hush_go` / `hush_arrive` / `hide` names one. `SolverLog.struck` is filled only when
  the world applies a mask (mocks exempt). Fuzz random taps: tonight's built hotspots, 1 in 4 a struck one.
- SolverData twin of the mask: `live_hotspots(ep)`, `live_kind`, `is_live`, `live_hides`, `struck_hotspots`,
  `named_pranks`, `hush_rooms`, `fixup_hold_activities`; `nearest_hiding(..., ep_id)` skips struck spots; the executor
  and planner pass the episode; the planner's escape never runs into a backstage / locked room; the slow persona's
  wrong tap is a live unused spot in her start room only (REDESIGN §4.4 N1: only her room glows). A test proves the
  twin equals `SimCtx.live_hotspots` on all 13 episodes.
- `solve.sh --baseline`: baseline routes gone from an episode's solution file are listed "absent (retired)", never a failure.
- Tools: `tools/content/c2_delta.py`, `tools/content/d1_lean_md.py`.

### Two sim fixes the fuzz forced (both mine, both route-neutral)
1. **A tap on the hiding spot she is in** (go or pin, HIDDEN or DIVING) clears any pin and answers
   `cmd_rejected {why: "here", target}` — before, it pinned her own spot and POP OUT dived straight back in (fuzz
   soft-lock, P00 seeds 41/97). The executor ignores "here".
2. **`director.fixup_holds` [{kind, until}]** (new optional episode field; `EpisodeDef.fixup_holds`; validated): a
   fix-up of that kind does not end while `until` (a gate condition) is false. `p00_curtain_up`: `{"kind": "MIRROR",
   "until": "rigged:allegro_go_go"}` — after the sneeze he primps at the hall mirror until the lever is set, so the
   Prologue's last warm-up never starts with the gramophone unrigged (in the non-repeating loop the spin was then lost
   for good: fuzz random seeds 9/21/77). All authored routes rig the lever inside the 4 s fix-up → every route hash
   unchanged. Held fix-ups are exempt from rule 9's 60 s progress check (like an uncapped gate).

## 2. Verification (commands, numbers)
| gate | result |
|---|---|
| `SANDBOX=r3d-content tools/scripts/solve.sh all --route=all --report=… --timeline=… --baseline=<SP>/work/r3d-content/solve_before.json` | 12/12 OK, 0 new failures; `n02 face_to_face*` "absent (retired)" |
| `solve.sh g0_sneeze --route=ideal` | OK, ends by `g0_done`, hash identical |
| `solve.sh all --auto` | N01, N02, P00 auto OK (script, lines alone, ★★★ authored, soft-lock) |
| D1 (⏩) ideal / required / slow | P00 3.0 / 1.8 / 5.9 %; N1 7.8 / 4.8 / 1.9 %; N2 6.9 / 1.9 / 1.6 %; worst gap ≤ 5.5 s; edge share ≤ 0.22; N2 first prank 19.4 s |
| stars / applause | N1 ideal ★★★ 116, N2 ideal ★★★ 118; required ★ 44 / 59; P00 [null, null, null]; 0 catches on ideal; 0 invariant violations |
| `fuzz.sh <ep> --runs=200` (P00, N01, N02) | FUZZ_RESULT |
| `lint.sh --strict` | content rules 0 errors, hotspot OK, IP OK. RED (not mine): 2D clip coverage 103/137 (pre-existing since Stage 2), 3D coverage 70/77 g0+p00 clips without v2 sidecars (animation keys authoring), lint_anim 3D 1 error (`hush/rig_achoo_ria` L10 pop jump, r3d-anim) |
| `lint.sh` | content/hotspot/IP OK; exits 1 only on that lint_anim 3D error |
| `tools/ci/lint_all.sh --no-godot` | RED only on `tools/art/hush/validate.py` × r3d-hud's new Figgis SVGs |
| full suite `test_game.sh r3d-content` | 1376 passed, 0 failed, 1 skipped (FULL_RERUN) |
| sim/solver/content | 464 passed, 0 failed |

LOOK: the N1 3D e2e (`e2e.sh n01_ideal --shot-seq`) needs `r3d-night`'s 3D NightScene, which is not launched yet —
pending (§5). I looked at the solver timelines (N1 ideal: the pantry hides add no dead-air stretch; light-blue
adjacency-only PiP beats are where `lean` would hand him to the edge badge).

## 3. Contracts others use
- `SimCtx.live_hotspots(db, episode) -> Dictionary`; `world.ctx.is_live(hi)`; `hotspot_state(id).enabled`.
- `cmd_rejected {c, why: "struck" | "here", target}` (+ the older whys without target).
- `SimVisibility.pip_reason(w) -> StringName`; `micro_gag.pip_reason`.
- `previews.json`, `rig_actions.json` (schemas above; index §7.10 unchanged).
- Episode fields `hides` (C1) and `director.fixup_holds` (new).
- Solver report `d1_lean`; `Metrics.d1_lean(log, laugh_fn, persona)`, `Metrics.lean_text(report, color)`.
- `SolverData.live_hotspots / live_hides / struck_hotspots / is_live / named_pranks / hush_rooms / fixup_hold_activities`.

## 4. Deviations (with reasons)
1. Knock-on pull-ins don't make a rig point live (P00/g0 sink tap, N1 fireplace bellows struck): REDESIGN §3.4's
   counts require it; the sim still keeps the knock-on prank "in the Night" (a sneeze can still land in the sink).
2. Doors/stairs "as today" → live only when they lead somewhere she may go tonight (REDESIGN §3.4 outranks the index;
   r3d-sets asked). Only the kitchen back door and the N1/N2 stairs change; no route used them.
3. `live_mask` is a byte per hotspot (PackedByteArray), not an int bit mask (60+ hotspots).
4. Two sim fixes + a new episode field (`director.fixup_holds`, the P00 mirror hold) to make fuzz 200 clean: they
   remove real player-facing traps (a pinned own spot; a Prologue line lost forever), and change no authored route.
5. The slow persona's wrong tap only in her start room; the fuzz random bot's taps weighted to built hotspots.

## 5. Requests
- **r3d-view3d**: `game/tests/view/fixtures/cmds/n01_throat_tea_{ideal,caught}.cmds.json` replay kitchen-table gos (now
  refused); refresh from `<SP>/work/r3d-content/cmds/` (fresh `--dump-cmds` of this tree). Tests still pass on the old ones.
- **r3d-hud**: Figgis SVGs fail `tools/art/hush/validate.py` (`<desc>` not allowed, 17–20 colours > 10, paint in the
  3 px margin) → `lint_all.sh --no-godot` red. Conform, or the orchestrator relaxes that validator for R7's restyle.
- **r3d-anim**: `lint.sh` now runs the 3D lint; it is red on `hush/rig_achoo_ria` L10 (f38 lowerarm_r 56°/f without a pop).
- **r3d-night**: e2e scenarios `n02_face_to_face` / `n02_face_to_face_lost` are retired; drop their rows. Once the 3D
  NightScene plays, the orchestrator/r3d-integrate should run the §6 LOOK: `E2E_SANDBOX=r3d-content tools/scripts/e2e.sh
  n01_ideal --shot-seq=<SP>/work/r3d-content/n01 --every=30 --count=60` (does Hush dive into the pantry where she used
  to hide under the table, and does it still feel fair?).
- **r3d-view3d / r3d-night** (info): in a dawdling Prologue Bellows may now stay at the mirror past the fix-up's 4 s
  (`fixup_mirror` held; bubble ring hidden while held).
- **orchestrator (R15)**: keep `bellows_window: "sim"` — `d1_lean` fails the ⅓ edge-share cap on 7/9 routes.

## 6. Amendment text for r3d-docs / r3d-qa
**TECH §3.10 (already landed by r3d-docs — corrections):** "a container iff it is the source of an item one of the
Night's *named* pranks needs"; "exits as before; doors and stairs only when they lead to a room Hush may enter tonight
(the kitchen back door and the roped-off stairs are struck in Act I)"; "`SimCtx` stores it as a byte per hotspot
(`live_mask`, `is_live(hi)`)"; add: "`micro_gag` events carry `pip_reason`".
**TECH §3.5 (commands):** "`cmd_rejected {c, why, target}`: why `struck` (a hotspot not on stage tonight) and `here` (a
go / pin on the hiding spot she is in or diving into: it clears any pin — POP OUT then goes nowhere)."
**TECH §4.6 (episodes):** "`hides` (optional list of hiding hotspots; one per room in Act I finals); `director.fixup_holds`
[{kind: DRY|SINK|HONEY|MIRROR, until: a gate condition}] — a fix-up of that kind does not end while `until` is false
(the Prologue: the mirror waits for the lever)."
**TECH §8.6 (invariants):** "13. no command on a struck hotspot is accepted: every go/pin on one is answered the same
tick by `cmd_rejected struck`; no `hush_go`, `hush_arrive` or `hide` names one (fuzz random taps include struck
hotspots, 1 in 4). Rule 9's progress check exempts held fix-ups like uncapped gates."
**TECH §8.5 (report):** "`d1_lean` — the D1 metric with adjacency-only PiP beats visible only with an emote (as edge
beats, inside the ⅓ cap); info column; decides R15."
**GDD §2.3 (Prologue, v1.2):** "After the sneeze he primps at the hall mirror until the gramophone lever is set (the
sparkle cue points at it); only then does he come back to warm up — the Prologue cannot lose its spin."
**GDD §3.4 / §7.2:** as landed by r3d-docs (v1.2) — matches the build; add "a tap on the spot she is hiding in keeps
her there (it cancels a GO ▶ pin)".

## 7. Known gaps
- The §6 LOOK in the real 3D game (needs r3d-night).
- `lint.sh --strict` 3D coverage stays red until the animation keys land their sidecars (recorded, R9).

## 8. Hours
≈ HOURS h (16:32Z → END).
