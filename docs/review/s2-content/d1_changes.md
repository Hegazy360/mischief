# D1 changes (s2-content, Stage 2 batch 1) — every GDD deviation, with its measured effect

Lead decision D1 fixes dead air **in the data**. Each change below names the GDD text it departs from, why, and
what it measured (solver, the ⏩ + visible-beat gate of `s2-sim` §4.2, ruling L2; Hush-idle loop timings from a
`SimWorld` run). The orchestrator folds this file into GDD §4.1.1, §5.4 and §7.2 (Checkpoint G, step 1b).
`tools/content/catalogue.py` accepts exactly the documented loop deviations (its `DEVIATIONS` table) and still
exits 1 on anything else; `game/tests/content/content_canon.gd` `D1_DURATIONS` does the same for durations.

## Summary (before → after)

| Night | ideal | required | slow | worst ⏩ gap | 1st prank ideal / req / slow | loop (Hush idle) |
|---|---|---|---|---|---|---|
| P00 | 25.1 → **3.0 %** | 31.7 → **1.8 %** | 20.7 → **5.9 %** | 8.6 → **5.3 s** | 24.7 → 25.2 / 33.2 / 28.2 s (launch-relative) | scripted |
| N01 | 37.4 → **7.9 %** | 57.2 → **4.8 %** | 43.6 → **2.1 %** | 16.9 → **5.5 s** | 17.0 → **17.5 / 18.7 / 24.4 s** | 67.8 → **58.7 s** |
| N02 | 37.6 → **6.9 %** | 57.8 → **1.9 %** | 38.4 → **1.6 %** | 15.4 → **4.7 s** | **48.9 → 19.4 / 19.4 / 19.4 s** | 62.4 → **55.4 s** |

"Before" is the brief's Stage-1 table (⏩-weighted, no beats counted). The metric change alone (s2-sim: visible
beats count, ⏩ latched per persona) already took the unchanged data to N01 13.4 / 13.4 / 15.5 %, N02 9.7 / 8.6 /
13.6 %, P00 3.0 / 1.8 / 6.6 % with gaps ≤ 9.0 s — the rows below are what the data changes added on top.
Targets: ideal ≤ 20, required ≤ 25, slow ≤ 30 %, gap ≤ 12 s — met on every route with margin; edge-bubble beats
carry ≤ 0.22 of the beat credit on every authored route (≤ ⅓, ruling L1).

## The changes

### ALL-1 Activity durations (GDD §4.1.1) — lever 4 "Act I loops ≤ 60 s"
| activity | GDD | D1 | why it still reads |
|---|---|---|---|
| `warmup` | 10 s | **8 s** | gated in the Prologue / N1 first loop anyway; two beats (2 s, 7 s) per ungated run |
| `tea` | 10 s | **8 s** | KETTLE DRUM @3 s, ACHOO-RIA! @7 s both still fit; beats at 2 s and 7 s (the sip) |
| `pickles` | 6 s | **5 s** | IN A PICKLE @1 s; one beat at 2 s |
| `snack` | 6 s | **5 s** | COLD OPEN @1 s |
| `paper` | 12 s | **8 s** | LIFT-OFF @1 s, EYE-POPPING NEWS @2 s; beats at 2 s and 7 s |
| `fire` | 6 s | **5 s** | BELLOWS BLOWS @2 s |
| `mirror` | 6 s | **5 s** | MIRROR, MIRROR @0.5 s (the three rounds run inside the reaction, not the activity) |
Measured: N01 loop (GDD order) 67.8 → 58.8 s; N02 62.4 → 55.4 s. No `dur_s` below 5 s (the bubble ring reads).
The draft Nights (N03–Gala) share these activities and get the shorter durations too (not solver-gated yet).

### N01-1 Loop `warmup → tea → pickles → rinse → tea → paper` (GDD §7.2: `warmup → tea → pickles → paper → rinse`) — lever 3
Two kettle windows per loop: the squeaker round trip (the hall box is reachable only while he reads the paper) no
longer costs a whole loop. Walking per loop drops from 24.7 s to 16.6 s, so the extra 8 s tea costs nothing:
58.7 s loop (Hush idle; first loop 75.7 s, the warm-up holds up to 25 s for the first rig). Measured: required
148.8 → 79.0 s, slow 155.1 → 85.3 s; ideal ★★★ 116 in 138.3 s (HOT & COLD + IN A PICKLE + Meltdown in loop 1,
three squeak bits to fill the quiet middle, KETTLE DRUM at loop 2's second tea chained into LIFT-OFF).

### N01-2 TAP DANCE washes out the frizz: `tap_dance.clears: ["FRAZZLED"]` (GDD §5.4 residue table) — lever 2
HOT & COLD used to leave FRAZZLED + SOAKED: two queued fix-ups (hall mirror 17.6 s, then the fireplace 27.3 s
after the drench). Now the drench flattens the flipped bouffant into dripping spaniel ears, so only SOAKED stays:
one fix-up at the parlour fireplace, **10.0 s** from `b_detour` to its end (`tools/content/detour_times.py`). Every
N01 route's worst detour: ideal 10.0 s, required 9.7 s, slow 9.7 s (≤ 12 s). TAP DANCE is N01-only, so no other
Night changes. The frizz is still seen for the second the double act takes (ACHOO-RIA! lands first).
Not done (needs another owner, see the report): ACHOO-RIA! *alone* in N01 still sends him blind to the hall mirror
(≈ 16 s); the kettle's reflection at `st_tea` would be a 7 s, funnier fix-up, but `fixup_overrides` may only name a
station of that kind (`validate.gd`) and `st_tea` has kind HONEY only.

### N01-3 / N02-3 `rules.combos: []` (ruling L4)
No combo can form on Night 1 or 2 in any order (TAP DANCE then ACHOO-RIA!/LIFT-OFF, or the reverse) — POODLE stays
Night 3's Big Number. Measured: 0 `combo` events on every N01/N02 route (test `test_no_combo_on_act_one_routes`).

### N02-1 Loop rotated to start kitchen-side: `paper → fire → snack → mirror → phone → clock`, Bellows starts at the recliner (parlour 2080) (GDD §7.2: `mirror → phone → clock → paper → fire → snack`, start in the hall) — lever 1
The same cycle, so the loop and its hooks are unchanged; he now reaches the fridge at 17.7 s instead of 47.1 s.
Hush rigs COLD OPEN while he reads (kitchen is another room), hides in the pantry, and the first prank lands at
**19.4 s** on the ideal, required and slow routes (was 48.9 s). The hall is never sealed in the first 30 s: he is
in the parlour 0–15 s and in the kitchen 16–29 s; the COLD OPEN fix-ups (sink, then the hall mirror) are the window
in which Hush rigs the phone and the clock. Ideal ★★★ 118 in 149.3 s (was 186.1 s), required 55.4 s (was 85.9 s).
`n02` ideal `duration_s` expect lowered from [150, 360] to [100, 360] (the route is simply faster now).

### N02-2 Card cue order (GDD §7.2 loading card unchanged)
He opens the Night reading with **specs on**, so `card_specs` now fires at 1.0 s and `card_freeze` at his first
`specs {on: false}` (he leaves the paper for the fire): the player meets "specs on → get out of sight" while it is
true on screen, then "FREEZE" the moment specs come off. Ids unchanged (`s2-ftue` presents them by id).

### ALL-2 Timed micro-gags (GDD §2.1 "a micro-gag every 5–8 s", §4.1) — lever 5
Every slice activity and fix-up detour has `micro_gags: [{id, at_s, len_f, emote, gag}]` (first beat 2–3 s, then
every 5–8 s; `mg_cycle_s` 20 s on the gated warm-up), plus root `walk_beats` for walks ≥ 5 s. Table and id changes:
`docs/review/s2-content/micro_gags.md`. Measured edge share (edge-bubble beats / all beat credit): ≤ 0.22 on every
authored route; most beats are `room` or `pip`.

### P00-1 The ⏩ lesson: cue `ghost_ff` (new; GDD §2.3 has no ⏩ beat)
At the Prologue's first hidden wait — Hush in the pantry after the sneeze while he shuffles off to the hall mirror
(1.5 s after the door-frame bonk, launch 34.7 s on the slow route). Never during the sneeze build-up. Measured
(slow route): gate metric 6.6 % → 5.9 % (the slow persona now latches ⏩ from 32.4 s); naive 4.3 %. Details:
`prologue_clock.md`.

### P00-2 The walk-off shows a bubble icon: detour `exit` (new)
`activities.json detours.exit` (icon `res://art/icons/activities/exit.svg` by `s2-art`, clip `bellows/loco_stomp`),
no hooks, no timed beats (walk beats play). The sim already emits `b_next/b_activity {id: "exit"}`.

### ROUTES D1 expects restored on every route (s2-sim §4.2, ruling L15)
`dead_air_pct_max` 20 / 25 / 30 by persona and `max_gap_s_max` 12 on every non-scenario route of P00, N01, N02 and
`g0_sneeze` ideal (landed as `warn_` first, flipped once the numbers passed; no `warn_` key left), plus
`first_prank_s_max` 25 (ideal, required) / 30 (slow) on N01 and N02. Scenario routes (persona `scenario`,
`events_min`): N01 `caught`, `chase`, `meltdown`; N02 `face_to_face`, `face_to_face_lost`.

### VOICE `barks.json`
`did_not_squeak` and `beryl` drop their `vo_bellows_grr` fallback (their own banks are rendered); the bank itself
stays (reactions and cues use it). New Figgis card sets `ghost_ff` / `ff` = Clarence held → arrow → clock fast.

## Kept (checked)
Applause bands (N01 ideal 116, required 44; N02 ideal 118, required 59), ★ / ★★★ as before, P00 "6 laughs in
60 s" (7) and slow "first player laugh ≤ 10 s (6.6 s), first prank ≤ 30 s (28.2 s), ≥ 4 laughs by 75 s (7)",
Σ prank bases 700 tenths, one new rule per Night.

Launch time: the Prologue's first-laugh / first-prank figures are launch-relative (sim time + `launch_offset_s`
2.3 s, ruling L13); N01 / N02 have no offset (their clock starts at the curtain).
