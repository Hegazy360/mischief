# sim — review artefacts (Stage 1)

The deterministic gameplay simulation (`game/sim/**`): headless only, so the artefacts are test results,
perf numbers and event logs rather than screenshots.

## Tests
`tools/scripts/test_game.sh sim -- sim/` → **223 passed, 0 failed, 0 skipped, 223 tests in 30 files, ≈ 18 s.**
The full project suite in the same sandbox: 641 passed, 1 failed (`solver/test_real_solutions.gd` does not parse —
`strict_keys` type inference — not sim).

| File | What it proves |
|---|---|
| `test_content.gd` (22) | fixtures load with 0 errors; 16 seeded bad files each give the precise message; Stage-3 kinds are warnings; bases normalise to exactly 700 (largest remainder, ties by line order); derived hooks, reaction lengths, station indices; load < 150 ms |
| `test_nav.gd` (8) | per-mover costs, doorways, doors (21/30), stairs (60/108), room masks, `eta_to_room` == the real entry tick, pauses |
| `test_hush.gd` (21) | go + auto actions (rummage → pick / pick window, dive, rig point face, stairs), idempotent go + run upgrade, the single queue (rig → dive on completion, release runs it, newer replaces), pins while hidden/frozen, pop out to the pin, freeze, squeak arm 18 ticks, no squeak while hidden, tray cap, restock 1200 ticks, locked rooms, rejected commands |
| `test_rig.gd` (7) | Q/S/B = 48/90/150, per-mille, release keeps progress, resume, multi-step with per-step `at`, B-rig noise every 30 ticks, step conditions, spotted mid-rig pauses the ring and freezes Hush |
| `test_routine.gd` (11) | loop order + wrap, gates (first_rig + 2 s, max 25 s, first loop only, first_squeak), detours before the next activity, `b_next` same tick as `b_detour`, the 240-tick ring, every activity shown ≥ 240 ticks ahead, nerves floor, resume |
| `test_entry_warning.gd` (6) | exactly 90 ticks, doorway pause for late entries, at-the-portal entries, stairs, chases exempt, a 12,000-tick wander with zero unwarned entries |
| `test_senses.gd` (14) | every row of the sight table, idle = moving, behind never, look-through (and not from > 250 px), head turn, reacting + 60 blind, stairs, hidden/watched |
| `test_meter.gd` (5) | fill per rules / relaxed / never < 0.8 s, +1 / −2 per tick, near miss ≥ 50 % with the cap of 3, spotted → chase after 18 ticks |
| `test_hiding.gd` (4) | unseen hiding safe for 10,000 ticks of him walking past; dive in view → pull-out; in-use spot → 48-tick face-to-face → caught, or pop out + run = near miss |
| `test_bump.gd` (2) | first bump = pardon, meter reset, window opens after pat + 2 steps + turn; later bumps stop him with the meter running; never an instant catch |
| `test_chase.gd` (6) | catch radius 80, run → wheeze → run → search → on guard timings, cap 600, door slam once + stun, Chase Trip (RUG BURN), STEP needs Steaming outside a chase |
| `test_caught.gd` (5) | +60 Lecture, +204 doorstep, +240 control, items home, −5.0, tomato, the Hook at the max, unlimited at −1 / relaxed, applause floor |
| `test_hooks.gd` (6) | marks, `resume`, fix-up hooks at +60, fizzle stays RIGGED, same-mark trigger waits for the punchline |
| `test_reactions.gd` (7) | tier by temper, `frames + hold × (scale − 100)/100`, accent frame, travel end, deterministic variant hash, HOT & COLD knock-on (A truncated at its tier-remapped frame, B from accent − 2, link + 1), headbutt inactive |
| `test_temper.gd` (7) | gains at the accent, hold 360, −2/tick, pauses, tiers + events, walk speeds 240/252/264/276, specs at Livid, look-back at Steaming+ |
| `test_running_gag.gd` (6) | links 1-2-3-4 with ×1 / ×1.5 / ×2 / ×3 on the real bases, end below 20, fuse, Meltdown timeline (stomps, Exhausted 150/150, temper 60, bonus, link), quake prank queued, bonus cap |
| `test_residue.gd` (7) | nearest station on his floor by path, overrides, 240-tick fix-up clears, interrupt keeps residue + DOUGH MAN, combo once, FRAZZLED blind until the mirror, oldest first |
| `test_scoring.gd` (8) | lines, Big Number sealed → unsealed (and retroactive), all lines, ★/★★/★★★, no stars in the Prologue, chain/meltdown lines, candles, bow |
| `test_squeaks.gd` (7) | hearing rooms, bits 20/10/0 and ≤ 3 per visit, ear pips + fade, lure (curious at the spot), fatigue, asleep = nap bit only, reacting = deaf |
| `test_mirror.gd` (4) | rounds 72/72/60 with Hush invisible, release in round n = tier n, still frozen → face-to-face, bolt = near miss, MIRROR fix-up starts the rounds, clears FRAZZLED |
| `test_director.gd` (4) | cues once, `laugh_` cues are laughs, safety net on/off, can't-fail Figgis hook (2.0 s window), the Prologue ends after the hunt |
| `test_conditions.gd` (5) | every §8.2 key, combinators, validation, prank condition entries (`or_chase`, Stage-3 keys false) |
| `test_determinism.gd` (7) | same commands → same hash on every one of 6,000 ticks; `clone()` at 1,000 continues identically for 4,000 ticks; clone is deep; `reset()` == fresh; the golden file; `record_hash_every`; clone ≤ 1 ms |
| `test_fairness.gd` (10) | `test_fair_1_spot_window` … `test_fair_10_headbutt_never_a_catch` — one test per GDD §4.7 rule over an 18,000-tick scripted Night plus targeted scenarios |
| `test_perf.gd` (2) | 18,000 ticks ≤ 1.5 s; state hash cost |
| `test_purity.gd` (3) | no Nodes / Time / randf / await / Engine in `game/sim/**`, no float state, all RefCounted |
| `test_misc.gd` (10) | path preview, bubble / hotspot_state / snapshot getters, wheeze, noises → Curious, knock_on_only, director gates, `event_ago_ge_s`, the Content autoload script |
| `test_episode_rules.gd` (14) | `bellows.exit` + `director.end` (walks out, bubble shows `exit`), `loop_repeat: false`, `end_when` after the exit, `hush.enter` (busy, unseen, queued move), `curtain_calls: false`, `nerves_temper`, nested `director.gates`, `safety_net.room / once`, `event_seen` `after_s` / `count_ge` (never mutates content), the required-key cue prefilter, `rearm_on_unseal` (a gag scores once a Night), `stand_in.rounds_f`, STEP `at` lists + `fire_at`, headbutt Double Act warning |
| `test_real_data.gd` (3) | the real `res://data` validates (0 errors, Stage-3 warnings listed); all 12 episodes run 3,600 ticks with every invariant counter at 0; a scripted Hush plays the real Prologue to `prologue_done` in 58.9 s (every cue, both lines, no spot, no stars) |

## Perf (desktop headless, Godot 4.7.2)
| Measure | Result | Budget |
|---|---|---|
| 18,000-tick Act-I Night with a scripted Hush (`cmds_fx_act1.json`) | **363–407 ms (0.020–0.023 ms/tick)**, 711 events | ≤ 1.5 s (0.083 ms/tick); PROGRESS box ≤ 0.05 ms/tick |
| Real data, 18,000 idle ticks (`sim_run.gd`) | p00 0.036, n01 0.030, n04 0.025 ms/tick | — |
| `clone()` mid-Night | **150–161 µs** | ≤ 1 ms |
| `state_hash()` | 166 µs (on demand / every N ticks only) | — |
| `ContentDB.load_dir` | fixtures < 10 ms; real `res://data` 13–15 ms | < 150 ms |

## Golden
`game/tests/sim/golden/fx_act1.json`: 372 commands, 30 checkpoints (every 600 ticks) over 18,000 ticks.
`tools/scripts/sandbox.sh sim -s res://tools/sim_run.gd -- --golden=check --golden-file=res://tests/sim/golden/fx_act1.json`
→ `golden OK: 0 mismatches over 30 checkpoints` (exit 0). Regenerate only with a reason:
`… -- --episode=fx_act1 --data=res://tests/sim/fixtures --cmds=res://tests/sim/fixtures/cmds_fx_act1.json --ticks=18000 --golden=update --golden-file=/abs/repo/game/tests/sim/golden/fx_act1.json`.

## Sample event log
`sample_fx_act1_3600.log` — the first minute of the scripted fixture Night
(`sim_run.gd -- --episode=fx_act1 --data=res://tests/sim/fixtures --cmds=… --ticks=3600 --dump`). What to judge:
does the sequence read as a farce with fair warnings? Excerpt:

```
{"e":"rigged","prank":"achoo_ria","t":170}                      Hush rigs the pepper in 0.8 s
{"e":"hide","spot":"kitchen_pantry_curtain","t":469,"watched":false}
{"e":"entry_warning","eta":90,"room":"kitchen","t":475}         1.5 s before…
{"chase":false,"e":"b_room","room":"kitchen","t":565}           …he walks in
{"e":"prank_fire","link":1,"prank":"achoo_ria","t":1010,…}       7 s into his tea
{"e":"reaction_accent","prank":"achoo_ria","t":1102}            CHOO!
{"a":"achoo_ria","b":"tap_dance","e":"knock_on","t":1120}       HOT & COLD: into the rigged sink
{"e":"running_gag","link":2,"mult":150,"t":1122}
{"e":"combo","id":"poodle","t":1222}                            FRAZZLED + SOAKED
{"e":"b_detour","kind":"fixup_dry","station":"st_fireplace",…}   the bubble shows where he's going
{"e":"prank_fire","link":3,"prank":"in_a_pickle","t":3080,"tier":2,…}
{"e":"meltdown_start","t":3253}                                 link 4, ×3, MELTDOWN! +8
```

## Real data: the Prologue, scripted (`test_real_prologue_plays_to_the_curtain`)
```
{"e":"director_cue","id":"laugh_vase","t":138}                   the vase inches along the mantel
{"e":"squeak","heard":true,"room":"kitchen","t":223,"x":3800}     first squeak → warm-up gate opens (+1 s)
{"e":"rigged","prank":"achoo_ria","t":417}                        pepper in the honey
{"e":"hide","spot":"kitchen_pantry_curtain","t":535,"watched":false}
{"e":"entry_warning","eta":90,"room":"kitchen","t":715}
{"e":"prank_fire","link":1,"prank":"achoo_ria","t":1245,"tier":1,…}   7 s into his tea
{"e":"b_detour","kind":"fixup_mirror","station":"st_hall_mirror","t":1410,"why":"FRAZZLED"}
{"e":"pop_out","spot":"kitchen_pantry_curtain","t":1950}           he's at the hall mirror
{"e":"rigged","prank":"allegro_go_go","t":2309}
{"e":"hide","spot":"parlour_chaise_back","t":2463,"watched":false} 12 ticks after he walks back in
{"e":"prank_fire","link":2,"prank":"allegro_go_go","t":2536,…}     ×1.5, ALLEGRO-GO-GO!
{"e":"all_lines_done","t":2705}
{"e":"b_activity","id":"hunt","t":2840} … {"e":"b_next","id":"exit","t":3200}
{"e":"director_cue","id":"laugh_picture","t":3236}                 he stomps out; the picture falls
{"e":"night_end","reason":"prologue_done","t":3536}
```

## Fixtures
`game/tests/sim/fixtures/`: a complete mini content set in the TECH §4 formats (porch, hall, parlour, kitchen,
landing + stairs; 28 hotspots, 11 stations with canonical ids; 6 items; 14 activities + 6 detours; 14 pranks covering
use / step / quake / knock_on_only / third_party (stub), resume, fixup hooks, 3 Double Acts, a STEP prank with
`tier_min` + `or_chase`, a quake prank, a fizzle, Mirror, Mirror, a headbutt knock-on; 16 reactions; 6 residues +
2 combos; 3 episodes: `fx_prologue` (gates, cues, safety net, can't-fail, scripted end), `fx_act1`, `fx_meltdown`).
`ContentDB.load_dir("res://tests/sim/fixtures")` loads it with 0 errors.
