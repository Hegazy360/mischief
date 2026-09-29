# Stage-1 brief: `content` — pranks, items, activities, reactions, residues, episodes, barks, solutions

You turn the binding design into the data the whole game runs on. The GDD already specifies every prank, activity,
routine and Script line; your job is to express it **exactly**, completely and consistently in the TECH §4 JSON
formats, fill in the few design numbers the GDD leaves to data (reaction beat timings, hint cards, marks), and author
the solution routes the solver bot will verify. Precision matters more than prose: the sim, the view, the solver and
the lints all read your files.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` — all of §2.3, §4 (especially **§4.1.1 activity library**), §5 (especially **§5.2 items, §5.4
   residues/combos, §5.5 Double Acts, §5.6 squeaks/panto, §5.7 the 32-prank catalogue, §5.8 archetypes**), §6.1–§6.4,
   **§7.1 the house, §7.2 the 12 episodes**, §9.3 (timing rules your reaction timings must obey).
3. `docs/TECH.md` **§4 (all formats)**, §3.7 (how the sim interprets them), §8.2 (solution files + condition
   language), §10.5 (the lints that will judge your data), **§14 (canonical ids — use exactly these)**.
4. `docs/research/comedy.md` §1.1–§1.2 and §8 (beat structures and frame counts per reaction type).

## 2. You own
- `game/data/items.json`, `pranks.json`, `activities.json`, `reactions.json`, `residues.json`, `barks.json`
- `game/data/episodes/**` (12 files named by episode id), `game/data/solutions/**` (not `_auto/`)
- `tools/content/**` (a catalogue exporter + any helper scripts)
- `game/tests/content/**`, `docs/review/content/`
`game/data/house/house.json` is written in parallel by `art-house` with the same canonical ids; `rigs/`, `anim/`,
`audio/`, `ui/` belong to others. Where you need their ids (clip ids, audio banks, icons), use the TECH §14 naming
conventions; they will be created to match.

## 3. What to write
### 3.1 `items.json` — 16 items (GDD §5.2, TECH §4.2)
Name, icon `res://art/house/items/<id>.svg`, `source` container hotspot id, `pranks` it serves, `count` (coins = 3).

### 3.2 `activities.json` — 27 activities + 10 squeak bits (GDD §4.1.1, TECH §4.3)
Every row of the activity table: `station` (TECH §14 station ids), `dur_s`, `facing`, `specs`, `awareness`
(`normal | absorbed | asleep | blind`), `squeak_bit`, `panto` (warmup, piano, rehearse), `bend` (feed_beryl, marrow),
`in_use` (clock → `hall_clock_case`, bath → `bathroom_bath`, dress → `bedroom_wardrobe`), `bar` (bath, nap), `clip`
(`bellows/act_<id>`), `icon` (`res://art/icons/activities/<id>.svg`). `stroll` walks from 5,260 to 5,560 (`path`
field). Detours `fixup_dry, fixup_sink, fixup_honey, fixup_mirror, curious, herd_beryl, search` with their clips and
icons. `squeak_bits`: the 10 bits with clip ids `bellows/bit_<name>` and lengths (60–120 f).

### 3.3 `pranks.json` — all 32 pranks + 6 Double Acts (GDD §5.7, §5.5; TECH §4.4)
For each: `caption` (≤ 18 chars), `size`, `rig_point` (TECH §14), `steps` (prep tier + `needs` item; IN OVER HIS
HEAD has 2 steps; PENNY PINCHER is 3 steps with `"at": "garden_coin_1..3"`, each needing `coins`; KIDDING AROUND's
tuck-in step has `conditions: [{"beryl_within": 150}]` — TECH §4.4), `trigger` (type, activity,
`mark_s` from the GDD activity table, `resume`, `fixup_kinds`; STEP pranks with `at`, `dir`, `chase`; QUAKE with
`room`; THIRD_PARTY with `actor` + `event`), `conditions` (e.g. `rug_burn`: `[{"tier_min": "steaming", "or_chase":
true}]`; `hosed`: `[{"beryl_on": "garden_hose"}]`; `penny_pincher`: `[{"beryl_within": 300}]` on the third bend;
`mirror_mirror`: `[{"hush_in_frame_frozen": true}]`), `fizzle` (where the GDD defines one), `reaction`
(`archetype`, `variants`, `end` {room, x} using house landings from GDD §7.1/TECH §4.1), `knock_on` (TECH §4.4; the
Double Act sources: `achoo_ria → tap_dance`, `lift_off → bellows_blows`, `grand_exit → rug_burn`, `spit_take →
fan_mail`, and headbutt knock-ons for `marrow_escape` and `spotlight_stealer`), `residue` (kinds; ACHOO-RIA! FRAZZLED with `"blind": true`),
`tags`, `nights`. `double_acts` block with the 6 ids, a/b, caption.

### 3.4 `reactions.json` — timings the sim trusts (TECH §4.5)
For every archetype variant used (22 archetypes incl. A/B/C variants), the 6 signatures, `suppressed`, the 3
Meltdowns, 3 Lectures, 4 T3 last beats, 4 combo beats, and the Busted/Lecture states: `clip` id, `frames`, `marks`
(`antic`, `accent`, `hold` [start, end], `release`, optional `knock_on`), `travel` (from_f, to_f, ease, arc_px) where
he moves, `t3_prop_f`, `cam` (zoom, hitstop). **Obey GDD §9.3:** anticipation 8–12 f (small) / 15–24 f (big) before the
accent, accent ≤ 4 f, hold 30–45 f (small) / 45–90 f (big), settle 8–30 f, totals 90–240 f (signatures ≤ 420 f);
the sneeze uses the rule-of-three beat of GDD §2.3 (ah 20, ahh 24, AHHH 30, false stop 20, CHOO 3). Base them on
comedy.md §8's beat list. Animators will match these numbers (the lint enforces ±2 f).

### 3.5 `residues.json` — 7 residues + 4 combos (GDD §5.4, TECH §4.6)
Fix-up kinds, overlay ids (matching `art-bellows`' residue names), blind flag support; combos with `of`, caption,
clip `bellows/combo_<id>`.

### 3.6 `episodes/*.json` — all 12 (GDD §7.2, TECH §4.6)
`p00_curtain_up`, `n01_throat_tea`, `n02_something_fishy` with `"status": "final"`; the other nine complete with
`"status": "draft"`. Each: act, index, title, seed, rooms, entry (`window` until N4, `gate` from N5), `rules`
(`spot_fill_s` 2.0 / 1.0 / 0.8, `tomatoes` −1 for P and N1–N3 else 3, `cant_fail` for the Prologue, `nerves` for
N10), `new_rule`, `card` (text ≤ 25 words exactly as the GDD, icon), `cold_open` (clip `cold/<episode>` + a one-line
description for the animators; none for the Prologue), start positions, the Bellows `loop` (activity refs + gates),
`fixup_overrides` (if any), and the `script`: every line with `id`, `kind`, refs, `req`, `big_number`, the GDD's
punchline `text`, and a `hint` block (`item`, `container`, `rig_point`, `when` activity) for Figgis. Line kinds for
goal lines: `meltdown {count}`, `chain {link}`, `chase_trip`, `combo`, `double_act`, and the Stage-3 kinds
`panto`, `witness {count}`, `herd {count}`, `prank_witnessed`, `combo_witnessed`.
**Prologue `director`:** gates (warmup until `first_squeak` max 15 s; warmup until `rigged:achoo_ria` + 2 s, no cap;
warmup-after-fix-up until `rigged:allegro_go_go` + 2 s or 25 s), `cues` (`laugh_vase` at 4.6 s after curtain-up
minus the launch offset, `figgis_psst`, `ghost_squeak`, `ghost_honey`, `ghost_hold`, `ghost_hide`, `sparkle_lever`
8 s after the fix-up starts, `title_card`), `safety_net` (1.5 s, 0.5×, pulse `kitchen_pantry_curtain`),
`launch_offset_s: 2.3`, and a `hunt` activity + exit. **Night 1:** first-loop gate on `warmup` (first_rig + 2 s, max
25 s).

### 3.7 `barks.json` (TECH §4.9)
Voice barks mapping to audio banks (`vo_bellows_pipe_down`, `vo_bellows_lecture_a`, `vo_bellows_the_pipes`, …),
Figgis cue cards (icon lists for each Prologue cue and each line's step-2 card), results templates for every
"why you missed" case (missed required line, missed optional line, missed Big Number, Applause short by a link / a
Meltdown / a combo / near misses), cold-open descriptions, and the loading-card icon ids.

### 3.8 `solutions/*.json` — authored routes for P, N1, N2 (TECH §8.2)
`ideal` (★★★, 100–140 Applause, no catches), `required` (★ only), `slow` (the first-timer persona; expect ★ and the
laugh-clock numbers from GDD §2.3/§10.4). Use waits on conditions (`bellows_not_in_room`, `bellows_activity`,
`bellows_facing_away_from_hush`) rather than fixed ticks, so routes survive timing tweaks. The Prologue ideal route
must show the 6-laughs-in-60-s script; the N1 ideal route must include HOT & COLD; the N2 ideal route must include
MIRROR, MIRROR as a chained link after TIME'S UP.

## 4. Checks you write
- `game/tests/content/test_content.gd` (standalone JSON reading — don't depend on `ContentDB`): every file parses;
  required fields; ids ⊆ TECH §14 (embed the lists) and every cross reference resolves; each prank-line's trigger
  activity is in that episode's loop; needed items' containers are in the episode's rooms; 3–6 lines + BN, ≤ 7;
  exactly one `new_rule`; cards ≤ 25 words; captions ≤ 18; prank-line weights normalise to 700 tenths (compute it);
  reaction timings obey §9.3 ranges; `rx_*` have no jitter fields; against `house.json` if it exists (soft): every
  hotspot/station referenced exists.
- `tools/content/catalogue.py`: exports `docs/review/content/catalogue.md` — a table of all 32 pranks (id, caption,
  size, rig point, needs, prep, trigger, residue, nights) and a per-episode table (loop, lines, req, BN) — and diffs
  the prank names/nights against GDD §5.7 by parsing the GDD text; any mismatch printed and non-zero exit.

## 5. Verify
```
tools/scripts/test_game.sh content -- content/
python3 tools/content/catalogue.py
tools/scripts/solve.sh all --route=all   # only if the sim + solver already exist; otherwise note it in the report
```

## 6. Acceptance
- [ ] Every file above, complete, with canonical ids; P, N1, N2 `final`.
- [ ] Content test green; catalogue export matches the GDD (zero diffs).
- [ ] Solutions authored for P, N1, N2 (three routes each).
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/content.md`: files, any GDD ambiguity you resolved and how (so the lead can
      fold it back into the GDD), encoding notes for `sim` (multi-rig-point pranks, gates), requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/content/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/content.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh content [-- filter]`, `tools/scripts/sandbox.sh content …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] content [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/content/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
