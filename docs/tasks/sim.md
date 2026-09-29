# Stage-1 brief: `sim` — the deterministic gameplay simulation

You are building the heart of *Mischief Next Door*: a pure-logic, fixed-tick, integer, seeded simulation of one
Night — Hush sneaking, Bellows living his routine, pranks firing, temper escalating, scoring. The view, the solver
bot and all tests drive it through commands and read it through accessors. It must be **exact, deterministic,
fast and fully tested**, because every other system trusts it.

## 1. Read first (in this order)
1. `/home/user/mischief/CLAUDE.md`
2. `docs/TECH.md` §0–§4 (all of it), §8.2 (condition language), §8.6 (invariants you must make true), §13, §14
   (canonical ids — use them verbatim).
3. `docs/GDD.md` §2.3 (Prologue script), §3.2–§3.4 (what the commands mean to the player), §4 (all: routine,
   activity library, senses, states, temper, chase/caught, fairness), §5.1–§5.7 (prank model, triggers,
   residue/fix-up, combos, Double Acts, squeak/lure, Mirror, Mirror; the catalogue), §6.1–§6.3 (scoring, Script,
   stars), §7.1–§7.2 (house layout, the Prologue and Act I episodes).
4. Booby reference for style and helpers (port, rename, adapt): `/home/user/ideaboard/booby/game/sim/fp.gd`,
   `rng.gd`, `state_hash.gd`, and the header of `sim_world.gd` (tick-order discipline).

## 2. You own (create/modify only these)
- `game/sim/**`
- `game/autoload/content.gd` (the `Content` autoload script; the orchestrator registers it later — your tests
  instantiate it directly)
- `game/tools/sim_run.gd`
- `game/tests/sim/**` (unit tests, scenario tests, fixtures under `game/tests/sim/fixtures/`, goldens under
  `game/tests/sim/golden/`)
- `docs/review/sim/` (a short `index.md` with test counts, perf numbers, and a sample event log)
Everything else is owned by other agents working right now. Data files under `game/data/**` are written by
`content` (items, pranks, activities, reactions, residues, episodes, solutions, barks) and `art-house`
(`house/house.json`). **Do not create them.** Your tests use your own fixtures; integration tests that load the
real `res://data` must `skip()` cleanly when those files are missing or still invalid (and your report lists the
exact validation errors as requests to `content` / `art-house`).

## 3. What to build (TECH §3 is the contract; this is the checklist)
### 3.1 Core
`SimConst` (every number below, named, with the GDD section in a `##` comment), `Fx`, `Rng` (xorshift32 port),
`StateHash` (FNV-1a port). Units: positions in sub-pixels (`SUB = 60` per px, so V px/s = V sub-px per tick),
ticks at 60/s, temper in points × 60, applause in tenths.

Key constants (GDD wins if you find a conflict — report it):
- Speeds px/s: Hush tiptoe 400, run 720; Bellows walk 240 (+5/+10/+15 % Irked/Steaming/Livid), chase 600.
  Doors: Hush 21 ticks, Bellows 30. Stairs: Hush 60, Bellows 108.
- Sight: specs off moving 600 / frozen 250; specs on moving = whole room ahead / frozen 600; absorbed 250 / 0;
  blinded & exhausted 150 / 150; asleep, reacting (+60 ticks after), meltdown, dressing-eyes-shut 0. Doorway
  look-through: within 250 px of an open doorway he faces → sees 300 px into the next room.
- "?" fill: `rules.spot_fill_s` (Prologue 2.0, Act I 1.0, Act II+ 0.8; ×1.5 relaxed; never < 0.8 except the
  Prologue's larger value); drain 2 per tick; near miss if it peaked ≥ 50 % (score max 3 per Night).
- Catch radius 80 px. Chase: run 240 → wheeze 90 → run 120 → Search when out of sight ≥ 90; hard cap 600.
  Search 360 ticks (specs on); On Guard 900 ticks (specs on). Door slam: once per chase, stun 60, when Hush passes
  a doorway with Bellows chasing within 500 px.
- Caught hold 240 ticks: busted cam 60, Lecture 132, wipe 12, doorstep 36; Hush placed on the porch doorstep at
  +204; control at +240; −50 applause tenths; carried items fly home; Running Gag ends; tomato +1; the Hook when
  tomatoes reach the max (rules.tomatoes; −1 = unlimited).
- Entry warning 90 ticks; doorway pause fills the gap; not in CHASE.
- Rig prep ticks: Q 48, S 90, B 150; B-tier steps emit a 500 px noise every 30 ticks while filling.
- Rummage 36 ticks; pick window 180 ticks; dive 15; squeak arm "moving" 18; tray cap 4 (oldest flies home);
  restock 1200 ticks after use.
- Temper gains (points): S 25, M 35, L 45, SIG 55; squeak bit / panto round 5; headbutt 45; witnessed +10. Hold
  360 ticks after the latest gain, then −2 points × 60 / 60 per tick (i.e. `temper_q -= 2` per tick). Paused during
  fix-up detours, REACTING and MELTDOWN. Tiers: Calm < 20 ≤ Irked < 45 ≤ Steaming < 70 ≤ Livid < 100 ≤ Meltdown.
  Look-back at Steaming+: 60-tick pause facing back when crossing a doorway out of a room. Livid → specs on.
- Running Gag live while temper ≥ 20; link multipliers 100 / 150 / 200 / 300 %. Meltdown at ≥ 100 at a reaction
  end: 330 ticks (stomps at 60/150/240), then Exhausted 480, temper → 60, bonus +80 tenths (max 2 per Night),
  counts as a link; QUAKE pranks in his room queue as the next reaction.
- Fix-up: 240 ticks at the station; `fixup` hooks fire at tick 60; clears the residue at the end.
- Scoring: size weights S 10, M 14, L 20, SIG 30; per-episode prank-line bases sum to exactly 700 tenths
  (largest remainder; ties by line order). Bits: squeak bit +20 / +10 / 0 tenths per bit per Night; panto rounds
  +20/+30/+50 (Stage 3); BUTT OF THE JOKE +30 (Stage 3). Bonuses: MELTDOWN +80 (≤ 2), COMBO +40 (each combo once),
  NEAR MISS +20 (≤ 3), EMBARRASSED +50 (Stage 3). ★★★ at ≥ 1000 tenths at the curtain.
- Squeak hearing: same room or a room joined by a doorway. Ear pips window 480 ticks; a squeak bit plays at most 3
  times per activity visit; the third pip within 480 ticks is a lure (CURIOUS detour to the squeak spot, specs on,
  look 180 ticks); lure fatigue: after 2 lures within 3600 ticks, further lures only emit a `lure_fatigue` +
  "PIPE DOWN!" shout (no walk). Asleep: only the nap's bit; reacting: ignored.

### 3.2 Content (`sim/content/`)
`ContentDB.load_dir(root)`, typed defs for every TECH §4 file (house, items, activities, pranks + double_acts,
reactions, residues + combos, episodes), `validate()` with precise messages (`"pranks.json: achoo_ria.rig_point
'kitchen_honey' not in house.json"`), derived data (normalised bases, hook lists per activity sorted by mark then
prank id, nav graph, station indices by kind, reaction lengths per tier). Unknown Stage-3 line kinds (`panto`,
`witness`, `herd`, `prank_witnessed`, `combo_witnessed`) and actors load fine and are reported by
`validate_warnings()` (not errors) until `s3-sim-cast` implements them. `autoload/content.gd`: loads once, prints
errors in debug.

### 3.3 Nav, actors, systems
Implement TECH §3.3–§3.7 exactly: `NavGraph`/`NavPath`; `SimHush`; `SimBellows` states and routine (loop, gates
`until: first_squeak | first_rig | rigged:<prank>`, `plus_s`, `max_s`, `first_loop_only`), detour queue (fix-ups,
lures, search), bubble data, entry warning + doorway pause, look-back, chase; `Senses`; `Pranks` (states, steps —
including per-step `at` rig points and step `conditions` (TECH §4.4) — items, triggers `use | step | quake |
knock_on_only`, `third_party` stubbed for Stage 3, conditions, fizzles, `resume`, `fixup_kinds`, one punchline at a
time; `knock_on` with `headbutt: true` loads but stays inactive until Stage 3); `Reactions` (variant pick, tier, suppressed flag — always false
until Delphine exists, length formula, travel with integer ease tables, end position, knock-on truncation with B
starting at its `accent − 2`); `Residue` (+ combos, blind flag for FRAZZLED from ACHOO-RIA!); `Temper`; `Scoring`;
`ScriptGoals` (line kinds `prank, double_act, combo, meltdown{count}, chase_trip, chain{link}`; stars; Big Number
unseal; `all_lines_done`; candles from `hint_used`); `Bits` (squeak/ear pips/lure/fatigue; **Mirror, Mirror**
rounds: when Bellows starts `mirror` (or a MIRROR fix-up at the hall mirror) with the prank RIGGED and Hush
FROZEN at the frame point, rounds of 72 / 72 / 60 ticks run; Hush in the frame is invisible to Senses until the
end of round 3; releasing FREEZE in round n fires the reaction with tier n (T1/T2/T3 via the modifier, regardless
of temper); still frozen at the end of round 3 → `face_to_face` with a 48-tick "?" window); `Chase`; `Director`
(gates, `cues` via `Conditions`, `safety_net` events, `cant_fail` → `figgis_hook` teleports Hush into the nearest
hiding spot when the "?" fills); `Conditions` (the full §8.2 language — the solver and Director both use it).

### 3.4 World API, commands, events, determinism
Exactly TECH §3.4 (all methods, including `clone()`, `bubble()`, `hotspot_state()`, `bellows_path_preview()`),
§3.5 (all commands with busy/queue semantics), §3.6 (tick order), §3.8 (every event name as a constant in
`sim_events.gd`, payloads ints/strings/bools, plus `static func is_laugh(ev) -> bool`), §3.9 (no floats in state,
sorted iteration, `state_hash()`, `record_hash_every`, golden files, `sim_run.gd` CLI:
`-- --episode=<id> [--data=res://data] [--cmds=/abs/path.json] [--ticks=N] [--dump] [--golden=check|update]`).

## 4. Fixtures (so you never wait for other agents)
Author `game/tests/sim/fixtures/` as a complete mini content set in the TECH §4 formats: a house with `hall`,
`parlour`, `kitchen`, `landing` (+ stairs), ~12 hotspots and 8 stations using canonical ids; 6 items; 10 activities;
8 pranks covering every trigger type, a `resume` hook, a `fixup` hook, a knock-on Double Act, a STEP prank with
`tier_min/or_chase`, a quake prank, a fizzle, `mirror_mirror`; reactions; residues + 2 combos; 3 episodes (a
Prologue-like one with gates/cues/safety net/can't-fail, an Act-I-like one, a Meltdown one). `ContentDB.load_dir()`
must accept this folder as its root.

## 5. Tests you must write (scenario tests drive `SimWorld` with scripted commands)
1. Content: fixtures load with 0 errors; each seeded bad file produces the right error; normalisation sums to 700
   with largest-remainder ties.
2. Nav: costs, doors, stairs, per-mover times, `eta_to_room`.
3. Hush: go + auto actions; idempotent repeat; queue (rig then dive when the ring completes; release also runs
   it); pins while hidden and frozen; pop out to pin; freeze; squeak arm moving 18 ticks; tray cap; restock.
4. Rig: per-mille progress for Q/S/B; release keeps progress; resume later; multi-step; B-rig noise pulses;
   spotted while holding pauses the ring and freezes Hush while `rig` stays on.
5. Routine: loop order; gates (first_rig + 2 s, max 25 s, first loop only); detours before the next activity;
   bubble ring ≥ 240 ticks; `b_next` same tick as `b_detour`; nerves floor.
6. Entry warning ≥ 90 ticks before every non-chase entry into Hush's room, with a doorway pause when needed.
7. Senses: every row of the sight table; facing; behind never; doorway look-through; idle = moving; reacting
   + 60 blind.
8. "?" meter: fill per rules, drain 2×, near miss (≥ 50 %) with the cap, spotted.
9. Hiding: unseen = safe for 10,000 ticks of Bellows walking past; watched → pull-out catch; in-use spot →
   face-to-face 48-tick window, escape by `pop_out` + run = near miss.
10. Bump: first bump per Night = pardon then meter after 2 steps; later bumps open the meter at once; never an
    instant catch.
11. Chase timings, catch radius, wheeze, search, on guard, door slam once, Chase Trip on a STEP prank.
12. Caught timings (+204 doorstep, +240 control), items home, −50, tomato, Hook at max, unlimited when −1.
13. Hooks at marks; `resume`; `fixup` hooks at fix-up tick 60; conditions false → fizzle stays RIGGED; a trigger
    while he's reacting waits for the reaction to end.
14. Reactions: tier by temper, length formula for T1/T2/T3, travel end position, knock-on (A truncated, B from
    accent − 2, link + 1).
15. Temper: gains at the accent, hold, decay, pauses, tiers, speeds, specs at Livid, look-back at Steaming+.
16. Running Gag links + multipliers; ends below 20; Meltdown (timings, stomps, quake prank queued, Exhausted sight
    150, temper 60, bonus cap, counts as a link).
17. Residue: nearest station of the kind on his floor by path; override; clears at the end; interrupt keeps it;
    combo once; FRAZZLED blind until the mirror.
18. Scoring + Script + stars + Big Number unseal + `all_lines_done` + candles; applause never below 0.
19. Squeaks: hearing rooms; ear pips; bits 20/10/0 and max 3 per visit; the third pip lures; fatigue; asleep and
    reacting behaviour.
20. Mirror, Mirror rounds and outcomes.
21. Director: cues fire once when conditions hold; safety net events; can't-fail hook.
22. Determinism: same commands twice → same hash each tick; `clone()` at tick 1,000 continues identically; golden
    file for one fixture episode.
23. Every GDD §4.7 fairness rule as its own named test (`test_fair_1_spot_window`, …).
24. Perf: 18,000 ticks of the Act-I fixture with a scripted Hush ≤ 1.5 s headless.

## 6. Build order (land the core first)
core → content defs + validate → nav → Hush + commands → Bellows routine/bubble → senses + "?" → chase/caught →
pranks + reactions → temper + Running Gag + Meltdown → residue + combos → scoring + Script → squeaks + lure →
Director + Conditions → Mirror, Mirror → hash/clone/golden → perf. If time runs short, Mirror, Mirror may slip to
Stage 2 — say so in the report. Everything else is required.

## 7. Verify
```
tools/scripts/test_game.sh sim -- sim/
tools/scripts/sandbox.sh sim -s res://tools/sim_run.gd -- --episode=fx_act1 --data=res://tests/sim/fixtures --ticks=3600 --dump
```
Headless only; no rendering needed. Put a sample event log and perf numbers in `docs/review/sim/index.md`.

## 8. Acceptance
- [ ] All tests above green in your sandbox (`tools/scripts/test_game.sh sim`); zero script errors.
- [ ] The public API matches TECH §3.4/§3.5/§3.8 exactly (other agents code against it today).
- [ ] No Nodes, no floats in state, no `Time`/`randf` in `game/sim/**` (add a test that greps your sources).
- [ ] Perf target met; `clone()` ≤ 1 ms.
- [ ] Real `res://data` validation run attempted; errors reported as precise requests.
- [ ] Report written to `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/sim.md`: files, API notes, deviations (with reasons), requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/sim/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/sim.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh sim [-- filter]`, `tools/scripts/sandbox.sh sim …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] sim [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/sim/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
