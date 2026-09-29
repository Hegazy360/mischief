# Stage-1 brief: `solver` — the episode solver bot, fairness fuzz, content/hotspot/IP lints, CI

Booby shipped levels nobody had proven were fun or fair. This time a headless bot plays every episode on every
build: it proves each Night is completable and 3-starable, measures the numbers the owner's fun gate cares about
(time to first laugh, dead air, first-clear duration), and hammers the sim with random and reckless players to prove
the fairness rules (no catch without a warning window, no ambush, no soft-lock). You also own the design lints and
the CI workflow.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/TECH.md` §3.4–§3.8 (the SimWorld API, commands, events you drive and read), **§8 (your contract)**, §10
   (test strategy; §10.5 lint rules you implement: content, hotspot, IP), §12 (CI), §13, §14 (canonical ids).
3. `docs/GDD.md` §2.3 (Prologue laugh clock), §4.3–§4.7 (senses, states, fairness rules), §6.1–§6.2 (scoring,
   stars), §7.2 (episodes: what "completable" means per Night), §10.4 (the automated pre-gate numbers).
4. Existing infra: `tools/scripts/{sandbox,test_game,shot}.sh`, `tools/ci/*.sh`, `.github/workflows/ci.yml`,
   `.github/actions/setup-godot`, `game/tests/run_tests.gd`, `game/autoload/dev_shot.gd`.

## 2. You own
- `game/solver/**` (`solution_def.gd, executor.gd, personas.gd, metrics.gd, planner.gd, invariants.gd, fuzz.gd`)
- `game/tools/solve.gd`, `game/tools/fuzz.gd`, `game/tools/lint/**` (`content_lint.gd, hotspot_lint.gd, ip_lint.gd,
  run_lints.gd`)
- `tools/scripts/{solve,fuzz,lint}.sh`, `tools/ci/lint_all.sh`, `.github/workflows/ci.yml`
- `game/tests/solver/**` (incl. `fixtures/`), `docs/review/solver/`
Built in parallel: `SimWorld` + `Conditions` (`sim`, in `game/sim/**`), the data and authored solutions (`content`),
`house.json` (`art-house`), the animation/rig lints (`rig`, `game/tools/anim/`). Use **soft hooks**; never edit their
files.

## 3. Specs
### 3.1 Executor and solutions (TECH §8.2)
`SolutionDef` parses/validates `data/solutions/<episode>.json` (routes, steps, expect). `Executor.new(world,
route, persona, cond_fn := Callable())` → `run(max_ticks) -> Dictionary` report. It turns macro steps into per-tick
command arrays for `world.step(cmds)`: `go/move/pick/rig/hide/pop_out/freeze/squeak/stand_in/panto/wait/wait_event/
idle/bow`. `rig` walks to the rig point, holds `rig on` until `rig_step_done`, releases; `hide` walks + dives and
waits for `hide`; `stand_in` holds FREEZE at the mirror frame until `mirror_round == release_round` then releases;
`panto` squeaks only while Bellows faces away and holds FREEZE through his looks. Every step has a timeout
(`max_s`, default 60 s) → a failure reason naming the step. Conditions are evaluated by `cond_fn` (default:
`Conditions.eval(world, cond)` from `res://sim/systems/conditions.gd` via a soft hook) so tests can inject a mock.

### 3.2 Personas (TECH §8.3)
`ideal`, `required`, `slow` (0.6 s latency before each step, a 3 s dawdle at the start, one wrong glowing tap per
Night — a `go` to the nearest non-useful hotspot — tiptoe only, hides on the first warning, never uses pins or the
queue). Personas transform a route; they never change the sim.

### 3.3 Metrics (TECH §8.5)
From the event stream + per-tick samples: duration, stars, applause, lines, catches with causes, near misses, first
player-caused laugh (s, with `episode.director.launch_offset_s` added for launch-relative checks), first prank,
laughs list, laughs by 60 s, dead-air % (no command in the previous 180 ticks, no laugh in the previous 300, Bellows not
reacting), longest gap, mean prank interval, total hold time, final hash. Laugh classification = `SimEvents.is_laugh`
(soft; fallback list in your code mirrors TECH §3.8). Report JSON + a markdown table.

### 3.4 Planner (TECH §8.4)
Predict (clone + run with Hush hidden) → line tasks from content templates → beam search (width 6) over orderings
and safe windows using `world.clone()` and the real executor → score (lines > stars > applause ≥ 100 > duration >
catches) → proofs: each line alone, the whole Script, ★★★ reachable, soft-lock check (3 forced catches at random
ticks, then re-plan). Writes `game/data/solutions/_auto/<episode>.json` **only through your CLI when asked**
(`--write-auto`); never overwrite authored files. Budget ≤ 60 s per episode.

### 3.5 Invariants and fuzz (TECH §8.6)
`Invariants.check(log) -> Array[String]` implementing all 11 rules (rule 11 behind a `beryl` presence check). The
executor/fuzzer records the needed per-tick samples (spot meter, Bellows state/room/speed, Hush hidden spot,
reacting flag) compactly. `Fuzz` bots: `random`, `reckless`, `hider`, `bait` with fixed seeds; each run ends with
invariants + a soft-lock probe (planner on the final state).

### 3.6 CLIs and scripts
- `tools/scripts/solve.sh [<episode>|all] [--route=ideal|required|slow|all] [--auto] [--write-auto]
  [--report=/abs/out.json]` → wraps `tools/scripts/sandbox.sh solve -s res://tools/solve.gd -- …`; exit 1 on any
  failed `expect`, invariant or missing route. `all` = every episode whose `status` is `final`.
- `tools/scripts/fuzz.sh [<episode>|all] [--runs=20] [--seed=1] [--bot=all]`.
- `tools/scripts/lint.sh` → `res://tools/lint/run_lints.gd -- --all` (content + hotspot + IP) and, if present, the
  animation/rig lints (`res://tools/anim/lint_anim.gd -- --all`); `tools/ci/lint_all.sh` = `lint.sh` + any
  `tools/art/*/validate*.py` + `python3 tools/audio/gen_audio.py --check` when those exist.
- Every tool prints a one-line summary (`[solve] n01_throat_tea ideal OK 214.3 s ★★★ 118 …`) and writes reports under
  `--report`.

### 3.7 Lints (TECH §10.5) — standalone JSON readers (don't depend on `ContentDB`)
- **Content:** id resolution across items/pranks/activities/reactions/residues/episodes/house; each prank's trigger
  activity is in the loop of every episode that lists the prank; needed items have a source container in the
  episode's rooms; Script 3–6 lines + Big Number, ≤ 7 total; one `new_rule` per Night; card ≤ 25 words; captions ≤ 18
  characters; fix-up station kinds exist on each floor the episode uses; `reactions.json` covers every archetype used;
  `time_jitter == 0` on `rx_*` clips when clips exist; prank-line bases normalise to exactly 700 tenths.
- **Hotspot:** rects ≥ 144 × 144, ≥ 24 px gaps, no overlaps among hotspots/doors/stairs in a room; use points inside
  rooms; station x within 80 px of the GDD §7.1 table (embed the table).
- **IP:** banned-term scan (TECH §10.5 list, case-insensitive, word-boundary aware) over `game/data/**/*.json`,
  `game/data/ui/strings.json`, `.tscn` text, and the Script/caption strings.

### 3.8 CI (`.github/workflows/ci.yml`)
Jobs on push/PR: import metadata check → GDScript tests (`tools/scripts/test_game.sh ci`) → `tools/scripts/lint.sh`
→ `tools/scripts/solve.sh all` → `tools/scripts/fuzz.sh all --runs=20` → audio check (`actions/setup-python`,
`pip install numpy pillow`, `python3 tools/audio/gen_audio.py --check`, skipped if `tools/audio` is absent). Keep the
existing android-preview workflow untouched. Each step must pass on an empty-but-valid repo state (skip gracefully
when a module doesn't exist yet, with a clear log line).

## 4. Tests (`game/tests/solver/`)
- A deterministic **`MockWorld`** in `tests/solver/fixtures/` implementing the TECH §3.4 surface your code uses
  (tick, step, drain_events, clone, hush/bellows fields, prank_state, line_states, stars, applause, hotspot_state)
  with trivial scripted behaviour — so executor, personas, metrics, invariants and planner logic are unit-tested
  today.
- Executor: every step type, timeouts, failure reasons; persona transforms; metrics (dead air, first laugh,
  laughs-by-60) on synthetic event logs; each invariant fires on a purpose-built bad log and passes a good one;
  planner finds the known solution in a MockWorld puzzle.
- Lints: each rule caught on a seeded bad fixture set under `tests/solver/fixtures/lint_bad_*`, and passes on a good
  set; IP lint catches every banned term and doesn't false-positive on "woodblock" or "goldenrod".
- Real-sim integration tests (`test_real_*.gd`) soft-skip unless `res://sim/world/sim_world.gd` **and** the
  episode data exist; when they do, run `ideal` routes for `p00_curtain_up`, `n01_throat_tea`,
  `n02_something_fishy`.

## 5. Verify
```
tools/scripts/test_game.sh solver -- solver/
tools/scripts/lint.sh ; echo "exit=$?"
tools/scripts/solve.sh all --route=all --report=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/solver/solve.json ; echo "exit=$?"
tools/scripts/fuzz.sh all --runs=5 ; echo "exit=$?"
```
If the sim and content exist by the end of your session, run them for real and put the reports (and any failures as
precise requests to `sim` / `content`) in `docs/review/solver/index.md`.

## 6. Acceptance
- [ ] TECH §8 APIs and CLIs; exit codes correct; reports readable.
- [ ] All tests green (real-sim tests skip cleanly when absent).
- [ ] Lints implemented with every rule proven by a bad fixture.
- [ ] CI workflow updated and robust to missing modules.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/solver.md`: files, how to add a route, how to read a report, requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/solver/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/solver.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh solver [-- filter]`, `tools/scripts/sandbox.sh solver …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] solver [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/solver/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
