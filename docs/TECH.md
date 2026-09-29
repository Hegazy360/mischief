# Mischief Next Door — Technical Design and Contracts (v1.0, BINDING)

Godot **4.7.2**, GDScript (typed, tabs, `##` docs), Compatibility renderer, 2D, 1920×1080 base, `canvas_items` +
`expand`, landscape (`SENSOR_LANDSCAPE`). Design: `docs/GDD.md` (binding). Plan: `docs/PLAN.md`.
This document is the contract between parallel agents: module boundaries, file ownership, data formats, public
APIs, events, determinism rules, tools, budgets and tests. If code and this document disagree, fix the code or
raise a request — never silently diverge.

---

## 0. Principles
1. **Sim / view split.** Gameplay truth lives in a deterministic fixed-tick **SIM** made of `RefCounted` classes
   (no Nodes, no engine time, no floats in state). The **VIEW** (Nodes) renders snapshots, plays clips, sounds and
   FX, and turns touches into sim commands. The view never mutates sim state except through commands.
2. **Everything is data.** Houses, rooms, hotspots, items, pranks, activities, routines, episodes, reactions,
   rigs, poses, clips, faces, barks, audio cues and solutions are JSON under `game/data/**`, validated at load.
   No level content in scripts.
3. **Verifiable by agents.** Every episode is proven completable and 3-starable by a headless **solver bot**;
   every clip is linted and rendered to contact sheets; every screen has a DevShot screenshot at 1200×540.
4. **Same inputs → same Night.** A state hash after every tick is reproducible across runs and machines.
5. **Phone-first performance.** Atlased cutout rigs, pooled FX, no per-frame allocations in hot paths.

---

## 1. Module map, directory layout and ownership

Owners are Stage-1 task keys (PLAN.md §2). "S2+" = created in a later stage. Every file has exactly one owner per
stage; tests live in the owner's `tests/<area>/` folder.

```
game/
  project.godot, export_presets.cfg            lead (changes by request only)
  autoload/
    dev_shot.gd                                 (exists; lead)
    content.gd            Content autoload: the loaded ContentDB            [sim]
    settings.gd           player settings (user://settings.cfg)              [ui]
    save.gd               progress save (user://save.json)                   [ui]
    haptics.gd            vibration patterns, rate-limited                    [ui]
    router.gd             scene routes + transitions + Android back           [ui]
    audio.gd              buses, SFX pool, music stems, voices, crowd         [audio]
    support/safe_area.gd, ui_scale.gd, fade_transition.gd                    [ui]
  sim/                                                                        [sim]
    core/      sim_const.gd fx.gd rng.gd state_hash.gd
    content/   content_db.gd validate.gd defs/*.gd (HouseDef RoomDef LinkDef HotspotDef StationDef ItemDef
               PrankDef ActivityDef EpisodeDef LineDef ReactionDef ResidueDef ComboDef DoubleActDef)
    nav/       nav_graph.gd nav_path.gd
    world/     sim_world.gd sim_cmd.gd sim_events.gd snapshot docs in sim_world.gd
    actors/    sim_hush.gd sim_bellows.gd  (sim_beryl.gd sim_delphine.gd: S3)
    systems/   routine.gd senses.gd temper.gd pranks.gd reactions.gd residue.gd scoring.gd script_goals.gd
               bits.gd chase.gd director.gd conditions.gd (the condition language, §8.2)
  solver/                                                                     [solver]
    solution_def.gd executor.gd planner.gd metrics.gd personas.gd invariants.gd fuzz.gd
  view/
    tex/       hi_res_tex.gd atlas_builder.gd                                 [rig]
    rig/       rig_def.gd pose_lib.gd clip_lib.gd rig_sampler.gd rig_player.gd springs.gd face_layer.gd
               prop_layer.gd line_limb.gd clip_events.gd                      [rig]
    sim_driver.gd                                                             [view]
    world/     world_view.gd room_view.gd prop_view.gd hotspot_view.gd character_view.gd
               view_snapshot.gd default_maps/<rig>.json                       [view]
    camera/    camera_director.gd juice_clock.gd                              [view]
    fx/        fx_layer.gd caption.gd stamp.gd particle_pool.gd ripple.gd noise_rings.gd footprints.gd
               stare_strip.gd thought_bubble.gd badges.gd busted_cam.gd       [view]
    pip/       pip_view.gd                                                     [view]
    stalls/    stalls_view.gd                                                  [view]
    audio_director.gd                                                          [view]
    sandbox/   ViewSandbox.tscn view_sandbox.gd fake_world.gd                  [view]
  ui/                                                                          [ui]
    theme/     theme.tres fonts/ (Lilita One, Nunito ExtraBold + OFL.txt) ui_kit.gd
    input/     input_router.gd tap_assist.gd gesture_config.gd
    widgets/   action_button.gd clarence_button.gd tray.gd applause_meter.gd running_gag_banner.gd
               tomatoes.gd figgis_chip.gd pause_button.gd overview_button.gd edge_bubble.gd pick_strip.gd
               pip_frame.gd (shows PipView's texture)
    panels/    script_panel.gd pause_menu.gd settings_panel.gd loading_card.gd results_screen.gd
    hud.gd hud_model.gd
    demo/      UiDemo.tscn ui_demo.gd
  scenes/
    boot/      Boot.tscn boot.gd                                               (exists; S2 slice-integrate)
    night/     NightScene.tscn night_scene.gd                                  S2
    dev/       AnimViewer.tscn anim_viewer.gd                                   [rig]
    dev/house_preview/  HousePreview.tscn (rooms + props from house.json)       [art-house]
  data/
    house/house.json                                                           [art-house]
    items.json pranks.json activities.json reactions.json residues.json barks.json
    episodes/*.json   solutions/*.json                                         [content]
    rigs/hush/ rigs/figgis/ rigs/stalls/   (rig.json poses.json faces.json)    [art-hush]
    rigs/bellows/                                                              [art-bellows]
    rigs/_mannequin/  anim/_mannequin/                                         [rig]
    anim/hush/ anim/bellows/                                                   S2 anim tasks
    audio/cues.json                                                            [audio]
    ui/strings.json                                                            [ui]
  art/
    STYLE.md                                                                   [art-house]
    chars/hush/ chars/figgis/ chars/stalls/ (+ _src/ generators, .gdignore)     [art-hush]
    chars/bellows/ (+ _src/)                                                   [art-bellows]
    chars/_mannequin/                                                          [rig]
    house/rooms/ house/props/ house/stage/ house/items/ icons/activities/ (+ _src/)   [art-house]
    ui/ (HUD icons, verb icons, glyphs)                                        [ui]
    fx/ (particles, caption plates, noise/footprint sprites)                   [view]
  audio/  sfx/ music/ voice/ sfx_map.json                                      [audio]
  default_bus_layout.tres  (Master ← Music, SFX, Voice, Crowd, UI)              [audio]
  tests/  run_tests.gd test_base.gd test_smoke.gd (exist)
          sim/ solver/ rig/ view/ ui/ content/ audio/ art/                      [each owner]
  tools/  (in-engine tool scripts, not exported)
          anim/ sheet.gd lint_anim.gd lint_rig.gd capture.gd                   [rig]
          lint/ content_lint.gd hotspot_lint.gd ip_lint.gd run_lints.gd        [solver]
          solve.gd fuzz.gd                                                     [solver]
          sim_run.gd                                                           [sim]
tools/ (repo root)
  audio/                  procedural synth (ported from Booby)                 [audio]
  anim/                   gif.py curves.py contact.py                           [rig]
  content/                catalogue export + data checks                        [content]
  art/hush/ art/bellows/ art/house/   SVG generator helpers                    [art-*]
  scripts/  (exist) + solve.sh fuzz.sh lint.sh                                 [solver]
            anim_sheet.sh capture.sh                                            [rig]
            gen_audio.sh                                                        [audio]
  ci/       (exist) + lint_all.sh                                              [solver]
.github/workflows/ci.yml                                                       [solver]
docs/GDD.md TECH.md PLAN.md PROGRESS.md                                        lead
docs/review/<task-key>/  review artefacts (PNGs, GIFs, WAV lists, index.md)    [each task]
```
Export filters exclude `tools/`, `tests/`, `scenes/dev/`, `view/sandbox/`, `ui/demo/`, `data/solutions/` and every
`_src/` folder (lead updates `export_presets.cfg` in Stage 2).

---

## 2. Conventions
- **World space:** px at zoom 1.0; x grows right; **y grows down**; the ground floor line is y = 0, the upper
  floor line y = −700. A floor is 640 px of interior above its line plus a 60 px slab below it.
- **Sim units:** positions are integer **sub-pixels, `SUB = 60` per px**, so a speed of V px/s moves exactly V
  sub-px per tick. Time is integer **ticks, 60 per second**. JSON uses px and seconds; conversion happens only at
  load (`Fx.px(v)`, `Fx.ticks(sec)`, round half away from zero).
- **Facing:** `+1` right, `−1` left. Art faces right; the view mirrors with `scale.x = -1`.
- **Ids:** `snake_case` strings in JSON; the sim interns them to ints at load (stable order = sorted ids).
- **Percent maths:** `v * pct / 100` with floor division helpers (`Fx.mul_pct`). No floats in sim state.
- **Animation frames = ticks** (60 fps). A clip frame number is directly comparable to sim ticks.
- **JSON style:** 2-space indent, UTF-8, no comments, keys in `snake_case`; colours as `"#RRGGBB"`; world rects as
  `[x, y, w, h]` with y relative to the room's floor line (negative = up).
- **GDScript:** `class_name` for every reusable class; typed vars and returns; tabs; `##` doc comment on every
  public method; no `await` in sim code; no `get_node` paths across module boundaries (use exported references or
  signals).

---

## 3. The SIM (owner: `sim`)

### 3.1 Core (`sim/core/`)
- `SimConst` — every tunable number from GDD §4–§6 as a named constant with the GDD section in its doc comment:
  `SUB := 60`, `TPS := 60`, speeds (`HUSH_TIPTOE := 400`, `HUSH_RUN := 720`, `B_WALK := 240`, `B_CHASE := 600`),
  door/stairs times, sight ranges, `SPOT_FILL_S` per act, `NEAR_MISS_MIN_PCT := 50`, `CATCH_PX := 80`, temper
  constants (`TEMPER_Q := 60`, gains, `HOLD_S := 6`, `DECAY_PER_S := 2`, tier thresholds 20/45/70/100),
  chain multipliers `[100, 150, 200, 300]`, bonuses, bit values, Lecture timings, `ENTRY_WARN_S := 1.5`,
  `RESTOCK_S := 20`, `FIXUP_S := 4`, `FIXUP_MARK_S := 1`. Episode `rules` may override a whitelisted subset.
- `Fx` — integer helpers: `px(v: float) -> int`, `ticks(sec: float) -> int`, `div(a, b)` (floor),
  `mul_pct(v, pct)`, `clampi`, `absi`, `signi`, `lerp_i(a, b, num, den)`.
- `Rng` — seeded xorshift32 (port of Booby `sim/rng.gd`): `next_u32()`, `range_int(lo, hi)`, `chance_pct(p)`,
  `fork(salt)`. The ONLY randomness in the sim; v1 gameplay uses none (routines are pure clocks) — it exists for
  deterministic tie-breaks and Stage-3 actors.
- `StateHash` — FNV-1a 32-bit over canonical ints (port of Booby `sim/state_hash.gd`).

### 3.2 Content (`sim/content/`)
- `ContentDB` (RefCounted): `static func load_dir(root := "res://data") -> ContentDB`; typed defs for every file in
  §4; `errors: PackedStringArray`; `func validate() -> PackedStringArray` (schema, id resolution, cross references,
  derived numbers). Loads in < 150 ms on desktop.
- Derived at load (never stored in JSON): Script normalisation (per episode, per prank line: `base_tenths`, sum
  exactly 700 by largest remainder over weights S 10, M 14, L 20, SIG 30); per-activity hook lists (sorted by mark,
  then prank id); nav graph; station-kind indices; reaction durations per tier.
- `Content` autoload (`autoload/content.gd`): `var db: ContentDB` loaded once at startup; in debug builds a
  non-empty `validate()` prints every error and shows a red banner. Tests construct `ContentDB` directly.

### 3.3 Navigation (`sim/nav/`)
- Rooms are 1-D segments `[x0, x1]` on a floor. Links: `doorway` (always open, shared x), `door` (front/back:
  open–close animation time only), `stairs` (hall foot ↔ landing head, traversal ticks per mover).
- `NavGraph.build(house: HouseDef)`: portal nodes; `func path(from_room: int, from_x: int, to_room: int, to_x: int,
  mover: int) -> NavPath` (Dijkstra, cost = ticks for that mover). `NavPath` = array of waypoints
  `{room, x, kind: WALK|DOOR|STAIRS, ticks}`; `func eta_to_room(room) -> int` (ticks until entering it, −1 if never).
- Paths are recomputed only on a new target; walkers advance by speed each tick. No allocations per tick.

### 3.4 `SimWorld` (the public API)
```gdscript
class_name SimWorld extends RefCounted
static func create(db: ContentDB, episode_id: String, config: Dictionary = {}) -> SimWorld
	## config: {relaxed: bool, seed: int (optional override), record_hash_every: int (0 = off),
	##          invariants: bool (collect fairness counters; tests/solver only)}
func reset() -> void                          ## retry in place: identical to a fresh create()
func clone() -> SimWorld                      ## deep copy of mutable state (shares ContentDB); ≤ 1 ms
func step(cmds: Array) -> void                ## advance ONE tick; cmds = Array[Dictionary] (§3.5)
func drain_events() -> Array                  ## events since the last drain, each {"e": name, "t": tick, ...}
func state_hash() -> int
var tick: int                                 ## ticks since curtain up
var ended: bool ; var end_reason: String      ## "bow" | "hook" | "prologue_done"
var hush: SimHush ; var bellows: SimBellows   ## read-only for callers (§3.9)
var beryl: SimBeryl ; var delphine: SimDelphine   ## null unless the episode has them (S3)
var episode: EpisodeDef ; var db: ContentDB
func prank_state(id: String) -> int           ## PrankState enum (§3.7.4)
func rig_progress_pm(id: String) -> int       ## per-mille of the current step
func line_states() -> Array                   ## [{id, done, req, big_number, sealed, candle}]
func applause_tenths() -> int ; func stars() -> Array  ## [bool, bool, bool]
func link() -> int ; func fuse_ticks() -> int  ## Running Gag link count and time left
func tomatoes() -> int ; func tomatoes_max() -> int    ## max −1 = unlimited
func hotspot_state(id: String) -> Dictionary  ## {kind, enabled, stock:[items], occupant:bool, in_use_next:bool,
                                              ##  spent:bool, rigged:bool, needs_item:String, seen:bool}
func bubble() -> Dictionary                   ## {next: activity|detour id, icon, ring_ticks, glyph, ear_pips}
func bellows_path_preview(ticks: int) -> PackedInt32Array  ## [room, x_sub, ...] samples every 10 ticks
func hush_can_see(hotspot_id: String) -> bool ## for "???" line reveal (visited room)
```
`SimWorld` owns the systems (§3.7) and calls them in the fixed order of §3.6. Nothing outside `sim/` writes its
fields. Performance: ≤ 0.05 ms per tick on desktop headless (a 5-minute Night = 18,000 ticks ≈ 1 s), ≤ 0.3 ms on a
mid-range phone.

### 3.5 Commands (`sim/world/sim_cmd.gd`)
The only way anything changes the sim. Each is a Dictionary with key `"c"`; unknown or invalid commands are
ignored and produce a `cmd_rejected {c, why}` event (never an error).

| Command | Fields | Meaning |
|---|---|---|
| `go` | `hotspot: String, run: bool` | Walk to the hotspot's use point; on arrival auto-execute (container → rummage, hiding → dive, door/stairs → traverse, exit → bow if ★). Rig points: arrive and face; nothing else. Same target as current = no-op. |
| `move` | `room: String, x: int (px), run: bool` | Walk to a floor point (clamped to the room). |
| `pick` | `item: String` | Take that item from the container Hush is at (valid during the 3 s pick window, or any time she stands at it). |
| `rig` | `on: bool` | Rig hold state; true while the action button is held in the RIG verb. |
| `freeze` | `on: bool` | FREEZE hold state. |
| `squeak` | — | One squeak (tap). |
| `wheeze` | `on: bool` | Long squeak (hold ≥ 0.5 s); counts as one squeak when it starts. |
| `pin` | `room, x` or `hotspot` | While hidden or frozen: set the destination pin (replaces). |
| `pop_out` | `run: bool` | Leave the hiding spot (to the pin if set). |
| `bow` | — | Take a Bow (valid after ★ from anywhere; the view calls it from the pause menu or on arrival at the front door). |
| `hint_used` | `line: String, step: int` | Records a step-3 hint (candle) for results. |

**Busy and the queue:** Hush is *busy* while rummaging (0.6 s), diving (0.25 s), squeaking (0.3 s), holding RIG
with the ring filling, in the Lecture, or bowing. A `go`/`move` arriving while busy is stored as the single
`queued` command (a newer one replaces it) and runs the tick the busy action ends — for a rig: when the step
completes **or** when the hold is released. A `freeze` or `rig` command is never queued (holds are immediate).

### 3.6 Tick order (`SimWorld.step`)
1. `tick += 1`; apply commands in array order (validation, queue).
2. `Director` gates and cues (player-led pacing, safety net, Prologue can't-fail).
3. `SimHush.update` — busy timers, rig ring (per-mille), movement along her path (doors, stairs), dive / pop out,
   freeze, squeak arm, queued command, carried items, noise emission (run, B-rig).
4. Stage-3 actors: `SimBeryl.update`, `SimDelphine.update` (null-safe).
5. `SimBellows.update` — state machine (§3.7.1), movement, activity timer, hook evaluation → `Pranks.fire`,
   detour queue, entry warning / doorway pause, chase.
6. `Senses.update` — sight/hearing for Bellows (and Delphine): "?" meters, near miss, spotted, bumps, pull-outs.
7. `Temper.update` — hold, decay (paused during fix-ups and reactions), tier changes, Meltdown entry.
8. `Scoring` + `ScriptGoals` — applause from this tick's events, lines, Big Number unseal, stars.
9. Invariant counters (if `config.invariants`), state hash (if recording), event stamping.

### 3.7 Systems

#### 3.7.1 `SimBellows` states
`ROUTINE, DETOUR, CURIOUS, SPOTTED, CHASE, SEARCH, REACTING, MELTDOWN, EXHAUSTED, CAUGHT_HOLD` (Lecture) plus the
flag `on_guard_until` and `asleep` (an activity property). Priority exactly as GDD §4.4. Fields readable by the
view: `room, floor, x_sub, facing, state, activity_id, activity_t, activity_len, detour (kind, station),
specs_on, blinded_until, temper_q, tier, residues (sorted kinds), spot_meter, spot_fill, ear_pips, reacting
{prank, archetype, variant, tier, suppressed, t, len, travel}, bump_count, look_back_until`.
- **Routine / gates:** `Routine` holds the loop index, loop count and the detour queue. An activity is
  `WALK_TO → PERFORM(t) → DONE`. A prank that fires during PERFORM ends it unless its hook is `resume`. On DONE:
  pop the next detour, else advance the loop (wrap; `loop_count += 1`; if `rules.nerves` set temper to at least 20).
  Gates (`until`, `plus_s`, `max_s`, `first_loop_only`) extend PERFORM.
- **Bubble:** `next` = first queued detour, else the next loop activity; `ring_ticks` = remaining PERFORM ticks
  when ≤ 240 (4 s) else −1. A detour queued this tick changes `next` this tick (event `b_next`).
- **Entry warning:** each tick in ROUTINE/DETOUR/CURIOUS, if `path.eta_to_room(hush.room)` ≤ 90 and no warning is
  active for that entry, emit `entry_warning {room, eta}`; if eta < 90 at that moment, insert a doorway pause of
  (90 − eta) ticks at the portal (`doorway_pause`). Not applied in CHASE.
- **Look-back:** at Steaming+, on crossing a doorway out of a room he pauses 60 ticks facing back (a sight check).
- **Speed:** `B_WALK × (100 + tier_pct) / 100`, tier_pct 0/5/10/15.
- **Chase:** GDD §4.4 timings (run 240 ticks → wheeze 90 → run 120 → Search if Hush out of sight ≥ 90 ticks; hard
  cap 600 ticks then Search). Catch when same room, |dx| ≤ 80 px, Hush not hidden (or hidden in a watched spot).
  Door slam once per chase (stun 60). STEP pranks on his path fire (Chase Trip).
- **Caught:** `CAUGHT_HOLD` 240 ticks: busted cam 60 → Lecture 132 → wipe 12 → doorstep 36. At tick 204 Hush is
  placed on the doorstep; control returns at 240. Carried items fly home, −50 applause tenths, Running Gag ends,
  `on_guard_until = tick + 900`, tomato +1 (Hook if `tomatoes == max`).

#### 3.7.2 `SimHush`
States `IDLE, WALK, RUN, STAIRS, DOOR, RUMMAGE, PICK_WINDOW, RIGGING, DIVING, HIDDEN, POPPING, FROZEN, SQUEAKING,
CAUGHT, BOWING`. Fields: `room, floor, x_sub, facing, state, hidden_spot, watched_spot, frozen, freeze_pose_seed,
carrying (≤ 4 item ids, oldest first), rig_prank, rig_step, pin, queued, last_input_tick, arm_moving_until`.
`is_moving()` = not FROZEN and not HIDDEN (idle counts as moving; `arm_moving_until` covers squeaks).

#### 3.7.3 `Senses`
Implements GDD §4.3 exactly (sight table, facing, doorway look-through, frozen vs moving ranges, awareness,
blinded, absorbed, asleep, reacting + 60 ticks). "?" meter: +1 per tick while visible, −2 while not; fill =
`rules.spot_fill_s` (×1.5 relaxed); near miss when it returns to 0 after peaking ≥ 50 % (max 3 per Night scored);
full → `spotted`. Hiding while visible sets `watched_spot` (meter continues). Bump: Bellows' walk step would
overlap a FROZEN Hush within 40 px → first bump per Night emits `bump {first: true}` then 2 steps later opens the
meter at 0; later bumps open it at once. Mirror, Mirror and panto rounds override visibility per their rules
(`Bits` owns those state machines). Hearing: `heard(kind, room, x)` → rooms: same room or joined by a doorway
(squeak); path distance ≤ 500 px (run, B-rig pulses).

#### 3.7.4 `Pranks` and `Reactions`
- `PrankState`: `LOCKED, AVAILABLE, IN_PROGRESS, RIGGED, FIRED, LANDED`. Available = in the episode's Script,
  not sealed (Big Number lines unseal after the required lines). Steps persist per-mille progress.
- Rig: at the rig point, correct item carried (consumed on step completion) or free, `rig on` → +1000 per-mille
  over the step's prep ticks (48 / 90 / 150). Spotted while rigging pauses the ring and (while `rig` stays on)
  sets Hush FROZEN in place. Completion of the last step → `RIGGED` + event `rigged`.
- Fire: a hook at its mark, a PASS/STEP overlap, a QUAKE (after a Meltdown in the room), a knock-on, or a
  third-party event, with all `conditions` true → `FIRED`. Conditions false with a `fizzle` defined → event
  `fizzle` (stays RIGGED). While Bellows is REACTING/MELTDOWN, triggers wait (one punchline at a time).
- `Reactions.start(prank)`: picks archetype variant (`variant = hash(episode.seed, prank, loop_count) % n` —
  deterministic), tier from temper (T1 < 45 ≤ T2 < 70 ≤ T3), `suppressed` if witnessed, duration from
  `ReactionDef` (`frames + hold_len × (tier_scale − 100) / 100`, tier_scale 100/120/150; suppressed replaces
  settle with 60 frames), travel keys, and the end position (landing table / `end`). Bellows is blind and deaf for
  the duration + 60. Knock-on: at `knock_on.frame`, if B is RIGGED, A is truncated and B starts at its
  `accent − 2` frame (anticipation skipped), link + 1.
- On `reaction_end`: residues added (→ `Residue`), temper gain applied at the accent (→ `Temper`), `LANDED`,
  line checks (→ `ScriptGoals`).

#### 3.7.5 `Residue`
Adds residue kinds with `blind` flags; queues one fix-up detour per new kind (oldest first) to the nearest
station of its kind on his floor (episode override first; ties by station id); emits `residue_add`, `combo`
(first time per combo per Night) and `b_detour`. Fix-up: 240 ticks at the station; its `fixup` hooks fire at tick
60; completing it clears that residue (`residue_clear`); a prank firing during it interrupts it (residue stays).

#### 3.7.6 `Temper`
Integer `temper_q` (points × 60). Gains at a reaction's accent (S/M/L/SIG 25/35/45/55, bits 5, headbutt 45,
witnessed +10); hold 360 ticks from the last gain, then −2 per tick; hold and decay paused while DETOUR(fix-up),
REACTING or MELTDOWN. Tier events on change. Running Gag live while ≥ 20 points: each landed prank while live is
link+1 (first prank that starts it is link 1); a Meltdown is a link; falls below 20 → `running_gag_end`, link 0.
Meltdown when ≥ 100 at a reaction end: MELTDOWN 330 ticks (stomps at 60/150/240 → `meltdown_stomp {n}`; QUAKE
pranks in his room queue as the next reaction), then EXHAUSTED 480, temper set to 60.

#### 3.7.7 `Scoring`, `ScriptGoals`, `Bits`, `Chase`, `Director`
- `Scoring` (applause in tenths): gag = `base_tenths × mult / 100` at the accent (mult 100/150/200/300 by link);
  bits and bonuses per GDD §6.1 (caps enforced here); catch −50; never below 0. Every change emits
  `applause {delta, total, kind, label}`; bonuses also emit `bonus {kind, amount}`.
- `ScriptGoals`: line kinds `prank, double_act, combo, combo_witnessed, prank_witnessed, meltdown{count},
  panto, witness{count}, herd{count}, chase_trip, chain{link}` → `line_done`, `big_number_unsealed`,
  `all_lines_done`; stars at curtain (`stars()`); `candle` from `hint_used`.
- `Bits`: squeak handling (ear pips over a 480-tick window, squeak-bit use counts, lure + fatigue: 2 lures per
  3,600 ticks), the panto state machine (GDD §5.6 timings), Mirror, Mirror rounds (GDD #15), BUTT OF THE JOKE.
- `Chase`: chase/search/on-guard helpers used by `SimBellows`.
- `Director`: episode `director` block (Prologue/N1): `gates`, `cues` (emits `director_cue {id}` when its `when`
  condition first becomes true — the view shows Figgis cards and ghost fingers), `safety_net` (emits
  `safety_net {on}`; the view slows time — the sim itself never changes speed), `cant_fail` (a full "?" teleports
  Hush into the nearest hiding spot: `figgis_hook`).

### 3.8 Events (`sim/world/sim_events.gd` holds the name constants)
Every event is `{"e": String, "t": int, ...}`. Payload fields are ints/strings/bools only.

| Group | Events (payload) |
|---|---|
| Hush | `hush_go {target, run}`, `hush_arrive {hotspot}`, `hush_room {room}`, `rummage {container}`, `pick_window {container, items}`, `pick {item}`, `item_home {item}`, `restock {item, container}`, `rig_start {prank, step}`, `rig_pause {prank}`, `rig_step_done {prank, step}`, `rigged {prank}`, `hide {spot, watched}`, `pop_out {spot}`, `freeze {on}`, `noise {kind, room, x, r}`, `squeak {room, x, heard}`, `pin {room, x}` |
| Bellows | `b_activity {id}`, `b_activity_end {id}`, `b_next {id, detour}`, `b_detour {kind, station, why}`, `b_room {room}`, `entry_warning {room, eta}`, `doorway_pause {ticks}`, `specs {on}`, `glyph {id}`, `look_back`, `ear_pip {n}`, `squeak_bit {bit, score}`, `head_turn`, `lure {room, x}`, `lure_fatigue` |
| Danger | `spot_start {by}`, `near_miss {by}`, `spotted {by}`, `chase_start`, `wheeze`, `door_slam`, `chase_end {why}`, `search`, `on_guard`, `bump {first}`, `face_to_face {spot}`, `caught {cause, spotted_tick, by}`, `busted_cam`, `lecture {variant}`, `doorstep`, `tomato {n}`, `hook` |
| Comedy | `prank_fire {prank, trigger, link, tier, witnessed}`, `reaction_start {prank, archetype, variant, tier, suppressed, len, entry}`, `reaction_accent {prank}`, `reaction_end {prank}`, `knock_on {a, b}`, `fizzle {prank}`, `residue_add {kind}`, `residue_clear {kind}`, `combo {id}`, `temper_tier {tier}`, `running_gag {link, mult}`, `running_gag_end`, `meltdown_start`, `meltdown_stomp {n}`, `exhausted`, `panto_round {round, phase}`, `panto_bit`, `mirror_round {round}`, `wink {round}`, `headbutt {target, landing}` |
| Score | `applause {delta, total, kind, label}`, `bonus {kind, amount}`, `line_done {line}`, `big_number_unsealed`, `all_lines_done`, `star {n}` |
| Flow | `director_cue {id}`, `safety_net {on}`, `figgis_hook`, `night_end {reason}`, `cmd_rejected {c, why}` |
| Stage 3 | `beryl_mood {mood}`, `bleat`, `herd_start`, `herd_end`, `delphine_arrive`, `glasses {up}`, `high_c {room, x}`, `embarrassed {prank}` |

`game/sim/world/sim_events.gd` MUST also expose `static func is_laugh(ev: Dictionary) -> bool` (reaction accents,
squeak bits, panto rounds, near misses, combos, Meltdown, bump-first, door slam, `director_cue` ids starting with
`laugh_`) — used by the solver metrics and the audio director.

### 3.9 Determinism rules
- No `Time`, no `randf()`, no floats in state, no Dictionary-order dependence (iterate sorted id arrays), no
  engine physics. Integer maths only; `Fx` helpers for division.
- `state_hash()` mixes every mutable field in a fixed order. `config.record_hash_every = N` appends `[tick, hash]`
  to `hash_log`.
- **Golden tests** (`tests/sim/golden/*.json`): `{episode, cmds: [[tick, cmd], ...], checkpoints: [[tick, hash]]}`;
  regenerate only with `tools/scripts/sandbox.sh ... -s res://tools/sim_run.gd -- --golden=update` and a reason in
  the commit message.
- `tools/sim_run.gd` (sim-owned CLI): `-- --episode=n01_throat_tea --cmds=path.json [--ticks=N] [--dump]` prints
  events and the final hash.

---

## 4. Data formats (`game/data/**`)
All files carry `"version": 1`. `ContentDB.validate()` enforces every MUST below; the content lint (§10.5) adds
design rules. Examples are normative in shape, illustrative in values (GDD numbers win).

### 4.1 `house/house.json` (owner `art-house`)
```json
{"version": 1, "id": "humdrum_7", "floor_pitch": 700, "interior_h": 640, "slab_h": 60,
 "floors": [{"index": 0, "y": 0}, {"index": 1, "y": -700}],
 "rooms": [
  {"id": "hall", "floor": 0, "x0": 500, "x1": 1500, "outdoor": false, "wallpaper": "#A9B79A",
   "art": {"bg": "res://art/house/rooms/hall_bg.svg", "fg": "res://art/house/rooms/hall_fg.svg"}}],
 "links": [
  {"id": "hall_parlour", "kind": "doorway", "a": "hall", "b": "parlour", "x": 1500},
  {"id": "front_door", "kind": "door", "a": "porch", "b": "hall", "x": 500, "art": "res://art/house/props/front_door.svg"},
  {"id": "stairs", "kind": "stairs", "a": "hall", "ax": 1450, "b": "landing", "bx": 1050, "hush_s": 1.0, "bellows_s": 1.8}],
 "stations": [
  {"id": "st_tea", "room": "kitchen", "x": 2960, "stand_x": 2900, "facing": 1, "kinds": ["HONEY"]},
  {"id": "st_sink", "room": "kitchen", "x": 3800, "stand_x": 3740, "facing": 1, "kinds": ["SINK"]},
  {"id": "st_hall_mirror", "room": "hall", "x": 1160, "stand_x": 1080, "facing": 1, "kinds": ["MIRROR"],
   "frame_x": 1240}],
 "hotspots": [
  {"id": "hall_confiscated_box", "kind": "container", "room": "hall", "use_x": 790, "facing": 1,
   "rect": [710, -230, 160, 230], "art": {"idle": "res://art/house/props/confiscated_box.svg",
   "open": "res://art/house/props/confiscated_box_open.svg", "outline": "res://art/house/props/confiscated_box_ol.svg"}},
  {"id": "kitchen_pantry_curtain", "kind": "hiding", "room": "kitchen", "use_x": 3640, "rect": [3560, -300, 160, 300],
   "in_use_by": null, "art": {"idle": "...", "occupied": "...", "outline": "..."}},
  {"id": "hall_clock_case", "kind": "hiding", "room": "hall", "use_x": 1340, "rect": [...], "in_use_by": "clock"},
  {"id": "kitchen_honey", "kind": "rig_point", "room": "kitchen", "use_x": 2990, "rect": [...], "station": "st_tea"},
  {"id": "hall_front_door", "kind": "exit", "room": "hall", "use_x": 560, "rect": [...]},
  {"id": "stairs_foot", "kind": "stairs", "link": "stairs", "room": "hall", "use_x": 1450, "rect": [...]}],
 "landings": {"kitchen": {"sink": 3760, "table": 3470}, "garden": {"pond": 6060, "roses": 5000, "compost": 5880}},
 "quake_props": {"parlour": [{"prop": "picture_frame", "x": 2150}, {"prop": "vase", "x": 2330}]},
 "entries": {"window": {"room": "kitchen", "x": 3800}, "gate": {"room": "garden", "x": 6150},
             "doorstep": {"room": "porch", "x": 350}}}
```
- `rect` is the **hit box** in world px (y relative to that room's floor line). MUST be ≥ 144 × 144; the hotspot
  lint also checks ≥ 24 px gaps and no overlaps between any two targets in the same room (hotspots, stairs, doors).
- `kind` ∈ `container | hiding | rig_point | exit | stairs | door`. Rig points reference a station when an
  activity uses it. `in_use_by` = the activity id that opens that hiding spot.
- Every room in GDD §7.1 exists (with greybox art until final art lands); every station x ± 80 px of the GDD.

### 4.2 `items.json` (owner `content`)
```json
{"version": 1, "items": {
  "squeaker": {"name": "Squeaker", "icon": "res://art/house/items/squeaker.svg", "source": "hall_confiscated_box",
               "pranks": ["kettle_drum", "pillow_talk"], "count": 1},
  "coins": {"name": "Coins", "icon": "...", "source": "hall_piggy_bank", "pranks": ["penny_pincher"], "count": 3}}}
```
`count` = uses per pick (coins: 3 rig points). Restock 20 s after the last use (`SimConst.RESTOCK_S`).

### 4.3 `activities.json` (owner `content`)
```json
{"version": 1, "activities": {
  "tea": {"station": "st_tea", "dur_s": 10, "facing": 1, "specs": false, "awareness": "normal",
          "squeak_bit": "bit_tea", "panto": false, "bend": false, "in_use": null,
          "clip": "bellows/act_tea", "icon": "res://art/icons/activities/tea.svg"},
  "nap": {"station": "st_bed", "dur_s": 18, "awareness": "asleep", "bar": "sleep", "squeak_bit": "bit_nap",
          "clip": "bellows/act_nap", "icon": "..."}},
 "squeak_bits": {"bit_tea": {"clip": "bellows/bit_tea", "len_f": 90}}}
```
`awareness` ∈ `normal | absorbed | asleep | blind`. `bar` ∈ `null | sleep | bath` (the view draws a progress bar).
Hooks are declared on the prank (§4.4), never here.

### 4.4 `pranks.json` (owner `content`)
```json
{"version": 1, "pranks": {
  "achoo_ria": {
    "caption": "ACHOO-RIA!", "size": "M", "rig_point": "kitchen_honey",
    "steps": [{"prep": "Q", "needs": null, "fx": "pepper_shake"}],
    "trigger": {"type": "use", "activity": "tea", "mark_s": 7.0, "resume": false, "fixup_kinds": ["HONEY"]},
    "conditions": [], "fizzle": null,
    "reaction": {"archetype": "sneeze_blast", "variants": ["a", "b"], "end": {"room": "kitchen", "x": 3760}},
    "knock_on": {"prank": "tap_dance", "frame": 110},
    "residue": [{"kind": "FRAZZLED", "blind": true}],
    "tags": ["free"], "nights": ["p00_curtain_up", "n01_throat_tea"]},
  "rug_burn": {"caption": "RUG BURN", "size": "L", "rig_point": "stairs_rods",
    "steps": [{"prep": "S", "needs": null}],
    "trigger": {"type": "step", "at": "stairs_foot", "dir": "up", "chase": true},
    "conditions": [{"tier_min": "steaming", "or_chase": true}], ...}},
 "double_acts": {"hot_and_cold": {"a": "achoo_ria", "b": "tap_dance", "caption": "HOT & COLD!"}}}
```
- `size` ∈ `S | M | L | SIG`; `prep` ∈ `Q | S | B`; `needs` = item id or null. A step may name its own rig point
  with `"at": "<hotspot>"` (default: the prank's `rig_point`) — PENNY PINCHER is 3 steps at `garden_coin_1..3`, each
  consuming one of the 3 coins; a step may carry `conditions` (KIDDING AROUND's tuck-in: `{"beryl_within": 150}`).
- `knock_on` = `{"prank": "<id>", "frame": n}` (a Double Act into a rigged prank) or `{"headbutt": true, "frame": n,
  "requires": {"beryl_within": 300}}` (MARROW MAYHEM, CURTAIN CALL — implemented by `s3-sim-cast`; the Stage-1 sim
  loads it and treats it as inactive).
- `trigger.type` ∈ `use` (activity + mark), `step` (walk over a hotspot; `chase: true` fires in chases),
  `quake` (Meltdown in `room`), `third_party` (`actor`: `beryl | delphine`, `event`), `knock_on_only`.
- `conditions` ∈ `{tier_min}`, `{beryl_within: px}`, `{beryl_on: hotspot}`, `{delphine_present: true}`,
  `{meltdown_in_room: room}`, `{hush_in_frame_frozen: true}`, `{or_chase: true}` (AND of all entries).
- `reaction.end` = where he ends up (world room/x) or null; `variants` pick deterministically (§3.7.4).
- Signatures have `"reaction": {"archetype": "sig_mirror_mirror", ...}` with their own ReactionDef.

### 4.5 `reactions.json` (owner `content`; timings checked against clips by the anim lint)
```json
{"version": 1, "archetypes": {
  "sneeze_blast_a": {"clip": "bellows/rx_sneeze_blast_a", "frames": 150,
     "marks": {"antic": 62, "accent": 92, "hold": [95, 140], "release": 150},
     "travel": {"from_f": 92, "to_f": 110, "ease": "out_cubic", "arc_px": 60},
     "t3_prop_f": 112, "cam": {"zoom": 1.4, "hitstop": 5}},
  "suppressed": {"clip": "bellows/rx_suppressed", "frames": 60}},
 "meltdown": ["bellows/meltdown_a", "bellows/meltdown_b", "bellows/meltdown_c"],
 "lecture": ["bellows/lecture_a", "bellows/lecture_b", "bellows/lecture_c"],
 "t3_last_beats": ["bellows/beat_slow_burn", "bellows/beat_dignity_fail", "bellows/beat_bow_topple", "bellows/beat_tear"]}
```
Until the real clip exists, `frames`/`marks` are the design values; the anim lint fails if a clip's beats differ
from them by more than 2 frames.

### 4.6 `residues.json` and `episodes/*.json` (owner `content`)
```json
{"version": 1, "residues": {"SOAKED": {"fixup": "DRY", "overlay": "soaked"}, "FRAZZLED": {"fixup": "MIRROR", "overlay": "frazzled"}},
 "combos": {"dough_man": {"of": ["SOAKED", "FLOURY"], "caption": "DOUGH MAN!", "clip": "bellows/combo_dough_man"}}}
```
```json
{"version": 1, "id": "n01_throat_tea", "act": 1, "index": 1, "title": "Throat Tea", "status": "final",
 "seed": 101, "rooms": ["hall", "parlour", "kitchen"], "entry": "window",
 "rules": {"spot_fill_s": 1.0, "tomatoes": -1, "cant_fail": false, "nerves": false},
 "new_rule": "items", "card": {"text": "Your tray carries things. Glowing spots take them. Do the Script, then take a bow at the front door.", "icon": "tray"},
 "cold_open": {"clip": "cold/n01_megaphone", "len_s": 5},
 "hush": {"start": {"room": "kitchen", "x": 3800}},
 "bellows": {"start": {"room": "parlour", "x": 1700},
   "loop": [{"a": "warmup", "gate": {"until": "first_rig", "plus_s": 2, "max_s": 25, "first_loop_only": true}},
            {"a": "tea"}, {"a": "pickles"}, {"a": "paper"}, {"a": "rinse"}]},
 "fixup_overrides": {},
 "script": [
   {"id": "kettle", "kind": "prank", "prank": "kettle_drum", "req": true, "text": "Bellows sings a duet with his kettle",
    "hint": {"item": "squeaker", "container": "hall_confiscated_box", "rig_point": "kitchen_kettle", "when": "tea"}},
   {"id": "bn", "kind": "double_act", "double_act": "hot_and_cold", "big_number": true,
    "text": "HOT & COLD: sneeze him into the sink"}],
 "director": null, "encores": []}
```
- `status` ∈ `draft | final` (drafts are loaded and linted but the solver only gates `final`).
- `rules.tomatoes`: −1 = unlimited. Line `kind` per §3.7.7 with fields `prank | double_act | combo | count | link`.
- `director` (Prologue): `{"gates": [...], "cues": [{"id": "ghost_squeak", "when": {"tick_ge_s": 3.7}}, ...],
  "safety_net": {"hide_before_entry_s": 1.5, "slowmo": 0.5, "pulse": "kitchen_pantry_curtain"}}` — the `when` language is
  the solver's condition language (§8.2).

### 4.7 Rigs: `rigs/<id>/rig.json`, `poses.json`, `faces.json` (owners `art-hush`, `art-bellows`, `rig`)
```json
{"version": 1, "rig": "bellows", "height_px": 380, "root_part": "torso", "origin": "feet",
 "parts": {
  "torso": {"file": "res://art/chars/bellows/torso.svg", "pivot": [95, 160], "z": 0},
  "belly": {"parent": "torso", "offset": [0, 20], "pivot": [60, 40], "z": 1,
            "spring": {"channel": "sy", "k": 300, "c": 12, "clamp": 0.08}},
  "head": {"parent": "torso", "offset": [8, -150], "pivot": [70, 130], "z": 5, "limits": {"rot": [-35, 35]}},
  "bouffant": {"parent": "head", "offset": [0, -110], "pivot": [80, 60], "z": 6,
               "tex": {"neat": "bouffant_neat.svg", "flipped": "bouffant_flipped.svg", "frazzled": "bouffant_frazzled.svg",
                       "wet": "bouffant_wet.svg", "floured": "bouffant_floured.svg", "feathered": "bouffant_feathered.svg",
                       "poodle": "bouffant_poodle.svg"},
               "spring": {"channel": "rot", "k": 220, "c": 10, "clamp": 30}},
  "arm_upper_r": {"parent": "torso", "offset": [40, -110], "pivot": [0, 0], "z": 3, "draw": "limb:arm_r"},
  "arm_lower_r": {"parent": "arm_upper_r", "offset": [0, 70], "pivot": [0, 0], "z": 3, "draw": "limb:arm_r"},
  "hand_r": {"parent": "arm_lower_r", "offset": [0, 70], "pivot": [20, 10], "z": 7, "sockets": {"grip": [22, 30, 90]},
             "tex": {"open": "hand_r_open.svg", "fist": "hand_r_fist.svg", "point": "hand_r_point.svg"}}},
 "limbs": {"arm_r": {"joints": ["arm_upper_r", "arm_lower_r", "hand_r"], "width": 24, "fill": "#7B3F8C",
                     "outline": 6, "ink": "#1B2340", "cap": "round"}},
 "face": {"anchor": "head", "offset": [18, -60],
          "slots": {"eyes": {"z": 8, "variants": {"open": "eyes_open.svg", "wide": "eyes_wide.svg"}},
                    "pupils": {"z": 9, "file": "pupils.svg", "range": [6, 4]},
                    "brows": {"z": 9, "variants": {}}, "mouth": {"z": 8, "variants": {}}}},
 "residues": {"SOAKED": {"tex": {"bouffant": "wet"}, "overlays": {"torso": "torso_drips.svg"}},
              "FRAZZLED": {"tex": {"bouffant": "frazzled"}}},
 "tint": {"parts": ["head", "hand_l", "hand_r"], "tiers": ["#FFFFFF", "#FFE0DC", "#FFC2B8", "#F59A94"]},
 "props": {"specs": {"file": "specs.svg", "pivot": [30, 10], "socket": "head:specs", "states": ["dangling", "on", "buttered", "magnifier"]}},
 "mirror_pairs": [["_l", "_r"]], "no_mirror": []}
```
- Parts are **flat Sprite2D cutouts** (`centered = false`, `offset = -pivot`), joints solved by forward
  kinematics from the feet origin. `draw: "limb:<id>"` bones are invisible; the limb is a round-capped Line2D
  (+ outline) through their joint positions (a quadratic curve through the elbow).
- `poses.json`: `{"poses": {"b_stand": {"root": {"x": 0, "y": 0, "rot": 0, "sx": 1, "sy": 1},
  "bones": {"torso": {"rot": 0}}, "face": "neutral", "tags": ["idle"]}, "b_take_antic": {"base": "b_stand",
  "root": {"y": 10, "sx": 1.12, "sy": 0.88}, "bones": {...}, "tags": ["take", "antic"], "silhouette": "crouched,
  arms in"}}, "mirror_of": {"walk_pass_r": "walk_pass_l"}}` — channels `rot, x, y, sx, sy, z, tex, vis, alpha`;
  poses resolve to full poses at load; 40–60 poses per main character.
- `faces.json`: `{"presets": {"neutral": {"eyes": "open", "brows": "neutral", "mouth": "closed"},
  "shock": {"eyes": "wide", "brows": "up", "mouth": "O"}}}`.
- Hush and the Pip fallback share part **names and pivots**; Pip is a `skin` (texture set) over the same rig.

### 4.8 Clips: `anim/<rig>/<clip>.json` (owners: `rig` for `_mannequin`, Stage-2 anim tasks for characters)
The comedy.md §6 format, binding:
```json
{"version": 1, "clip": "bellows/rx_sneeze_blast_a", "rig": "bellows", "loop": false, "length": 150,
 "layer": "base", "mask": null, "blend_in": 0, "blend_out": 10,
 "beats": {"anticipation": [62, 92], "accent": [92, 95], "hold": [95, 140], "settle": [140, 150]},
 "keys": [
  {"f": 0, "pose": "b_tea_sip", "face": "smug"},
  {"f": 20, "pose": "b_sneeze_ah1", "ease": "in_out_sine", "face": "sneeze_build"},
  {"f": 92, "pose": "b_sneeze_choo", "ease": "pop", "face": "shock", "set": {"bouffant": {"tex": "flipped"}}},
  {"f": 140, "pose": "b_sneeze_choo", "ease": "hold"},
  {"f": 150, "pose": "b_dazed", "ease": "out_back"}],
 "events": [
  {"f": 92, "type": "sfx", "id": "sneeze_choo"}, {"f": 92, "type": "hitstop", "frames": 5},
  {"f": 92, "type": "cam", "op": "punch", "zoom": 1.4, "in": 6, "hold": 40, "out": 20},
  {"f": 93, "type": "shake", "trauma": 0.45}, {"f": 98, "type": "laugh", "tier": "auto"},
  {"f": 92, "type": "prop", "op": "launch", "prop": "teacup", "vel": [-300, -700], "spin": 540},
  {"f": 92, "type": "mark", "name": "accent"}],
 "variation": {"time_jitter": 0.0, "rot_jitter": 2}, "smear": {"auto": true}}
```
- Frames are ints at 60 fps. `ease` on a key = the curve *into* that key: `linear, hold, pop,` and
  `in_ | out_ | in_out_` × `quad, cubic, quart, expo, sine, back, elastic, bounce`.
- `layer` ∈ `base | overlay (with mask) | additive`. Walk clips add `"stride_px"` so playback rate matches speed.
- Events: `sfx, voice, laugh, fx, face, cam, shake, hitstop, slowmo, freeze, prop, smear, mark`. `mark` names used
  by the sim: `accent`, `release`, `knock_on`.
- `variation` jitter is applied only in the view, and seeded (§5.3), never in reactions whose timing the sim uses
  (`time_jitter` MUST be 0 for `rx_*` clips).

### 4.9 `barks.json`, `ui/strings.json`, `audio/cues.json`, `solutions/*.json`
- `barks.json` (content): voice barks `{"pipe_down": {"speaker": "bellows", "kind": "shout", "bank": "vo_b_pipe_down"}}`,
  Figgis cards `{"figgis_cards": {"ghost_squeak": {"icons": ["clarence", "arrow", "bellows"]}}}`, results
  templates `{"results": {"missed_link": "Applause {n} — land one more prank inside a Running Gag"}}`.
- `ui/strings.json` (ui): every UI string by key (English only in v1; no hard-coded text in scenes).
- `audio/cues.json` (audio): sim event → sound mapping (§5.8).
- `solutions/<episode>.json` (content authors, solver verifies): §8.2.

---

## 5. The VIEW

### 5.1 Scene tree of a Night (`scenes/night/NightScene.tscn`, Stage 2)
```
NightScene (Node)                      night_scene.gd — wires everything; owns no gameplay rules
├─ SimDriver (Node)                    view/sim_driver.gd — owns SimWorld, tick accumulator, rates
├─ World (Node2D)                      view/world/world_view.gd — rooms, props, hotspots, characters
│  ├─ Rooms (Node2D)                   RoomView × n (bg layer, fg layer)
│  ├─ Props (Node2D)                   PropView per hotspot/prop (state textures, outline, badge)
│  ├─ Characters (Node2D)              CharacterView (RigPlayer + clip mapping) × actors
│  └─ FxWorld (Node2D)                 stare strip, footprints, noise rings, bubble, captions, particles
├─ CameraDirector (Camera2D)           view/camera/camera_director.gd (+ JuiceClock child)
├─ InputRouter (Node2D)                ui/input/input_router.gd (world gestures; _unhandled_input)
├─ AudioDirector (Node)                view/audio_director.gd
├─ PipView (SubViewport + Camera2D)    view/pip/pip_view.gd
└─ Hud (CanvasLayer, layer 10)         ui/hud.gd — widgets; StallsView on layer 9
```
Scene hooks: `func setup(params: Dictionary)` (`{episode: String, relaxed: bool}`) before `_ready`, and
`func handle_back() -> bool` (pause). Retry = `SimDriver.reset()` + `WorldView.reset()` (pooled; ≤ 1.5 s).

### 5.2 `SimDriver` (owner `view`)
```gdscript
class_name SimDriver extends Node
signal ticked(events: Array)            ## after every sim tick, with that tick's events
var world: SimWorld
var juice: JuiceClock                   ## hit-stop / slow-mo segments (real time)
func setup(world: SimWorld) -> void
func push_cmd(cmd: Dictionary) -> void  ## applied at the next tick (array order preserved)
func set_ff(on: bool) -> void           ## ×3, only honoured while Hush is hidden; auto-off on danger events
func set_safety_slowmo(on: bool) -> void## ×0.5 (Director safety net)
func set_paused(on: bool) -> void
func alpha() -> float                   ## 0..1 fraction toward the next tick (render interpolation)
func view_delta() -> float              ## delta × current rate (for view-time animation)
func reset() -> void
```
`_process(delta)`: `acc += delta × 60 × rate` with `rate = juice.scale() × ff × safety` (0 when paused);
run whole ticks (max 8 per frame; drop the rest); after each tick emit `ticked(world.drain_events())`.
**No `Engine.time_scale`**: UI tweens stay real-time; world visuals use `view_delta()`. Hit-stop is a JuiceClock
segment (freeze scale 0.05, cap 150 ms per 1 s, port of Booby `juice_clock.gd`). Reaction clips are
frame-locked to sim ticks (`frame = world.tick − reaction.start + alpha`), so sound, picture and gameplay agree.

### 5.3 The rig system (owner `rig`)
**Pure layer (headless-testable, no Nodes):**
- `RigDef.load(path) -> RigDef` (parts in parent-first order, pivots, offsets, limits, sockets, limbs, face slots,
  residue maps, tint, props), `PoseLib.load(rig, path)` (resolves `base`/`mirror_of`, full poses as
  `PackedFloat32Array` of `[root x, y, rot, sx, sy, (per part: rot, x, y, sx, sy, z, tex, vis, alpha)…]`),
  `ClipLib.get(id) -> ClipDef` (keys resolved to full poses, ease ids, events sorted by frame, beats, marks).
- `RigSampler.sample(clip: ClipDef, frame: float, out: PackedFloat32Array) -> void` — interpolates between keys with
  the key's ease (`Tween.interpolate_value` equivalents precomputed), steps discrete channels (tex, vis, z, face) on
  keys; `blend(a, b, t, out)` with per-part `lerp_angle`; `apply_additive`, `apply_mask`. No allocations.
- `Springs` (damped springs per part: `k`, `c`, clamp; driven by root acceleration and event kicks; fixed 60 Hz
  substeps), `FaceState` (slot variants, pupils, blinks every 2–6 s with a seeded RNG, suppressed during takes),
  `PropSim` (sockets, attach/detach, deterministic ballistic launch with spin).
- `ClipEvents.between(clip, f0, f1) -> Array` — events crossed this frame (for audio/FX/camera).

**Node layer:**
```gdscript
class_name RigPlayer extends Node2D
signal clip_event(ev: Dictionary)       ## sfx, voice, laugh, fx, cam, shake, hitstop, slowmo, freeze, prop, smear, mark
signal clip_finished(clip_id: String)
func setup(rig_id: String, skin := "") -> void           ## loads rig, poses, faces; builds the atlas
func play(clip_id: String, opts := {}) -> void           ## opts: blend_in, speed, loop, start_frame, tier, suppressed, seed
func set_external_frame(frame: float) -> void            ## drive frame from the sim clock (reactions)
func set_facing(dir: int, animate := true) -> void       ## 6-frame squash turn
func set_face(preset: String) -> void ; func set_slot(slot: String, variant: String) -> void
func set_residue(kind: String, on: bool) -> void ; func set_tint_tier(tier: int) -> void
func set_prop_state(prop: String, state: String) -> void
func look_at(world_pos: Vector2, weight: float) -> void  ## additive head/pupil look
func current_clip() -> String ; func current_frame() -> float
```
- **Rendering:** one atlas per rig (all part, face, residue and prop textures), rasterised by `AtlasBuilder`.
  The recommended implementation draws all parts from one CanvasItem in `_draw()` with `draw_set_transform_matrix`
  + `draw_texture_rect_region` (same texture → batched rects) and limbs as round-capped polylines (fill + ink).
  Budget: **≤ 12 draw calls per character**, ≤ 0.25 ms CPU per character per frame on a mid-range phone.
- **Tier modifiers** (GDD §5.8) are applied by the player at play time: `tier` 2/3 stretch the clip's hold
  interval (time remap), T3 adds the falling prop event and appends the last beat; `suppressed` swaps the settle
  for the `suppressed` clip. The sim computes identical lengths from `reactions.json` (§3.7.4).
- **Smears:** automatic when a part moves > 25°/f or > 40 px/f: stretch along velocity (≤ 2×) for 1–2 frames, plus
  2 ghost copies (alpha 0.45 / 0.25).

**Textures (`view/tex/`):**
- `HiResTex` — port of Booby `view/hi_res_tex.gd`: `get_texture(path, swaps := {}, scale := -1.0) -> Texture2D`,
  `warm(paths, budget_ms) -> int`, `ART_SCALE` (2.0; 1.5 below 3 GB RAM).
- `AtlasBuilder.build(key: String, paths: PackedStringArray, scale := -1.0, swaps := {}) -> AtlasSet` and
  `AtlasBuilder.warm(key, paths, budget_ms) -> bool` (rasterise on WorkerThreadPool, pack on the main thread;
  shelf packer, 2 px padding + 1 px extrude, pages ≤ 2048² preferred, 4096² max). `AtlasSet.region(path) -> Rect2`,
  `AtlasSet.page(path) -> Texture2D`, `AtlasSet.size_1x(path) -> Vector2` (layout always in 1× px).
- Rooms: backgrounds import at 1× (VRAM compressed); props per room go through one `AtlasBuilder` set per room.

**Tools** (§11): rig sheet, pose + silhouette sheet, contact sheet, onion strip, curves, lint, capture, the
`AnimViewer` dev scene (pick rig/clip, scrub, play, hot-reload JSON on mtime every 0.5 s), and the `_mannequin`
rig + demo clips (a geometric stand-in: proves every feature before character art lands).

### 5.4 World view (owner `view`)
- `WorldView.setup(db: ContentDB, episode: EpisodeDef, world: SimWorld)` builds RoomViews for the episode's
  rooms (locked rooms dimmed + velvet rope), PropViews for every hotspot/prop (state textures: idle / open /
  rigged / spent / occupied; pre-baked outline sprite pulsing alpha 0.6 ↔ 1.0 at 1.2 Hz; 56 px badges), and
  CharacterViews.
- **Snapshot seam:** every view class reads a plain `ViewSnapshot` (`view/world/view_snapshot.gd`,
  `ViewSnapshot.from_sim(world)`) plus the tick's events — never sim internals. `view/sandbox/fake_world.gd` produces
  the same snapshots from a scripted timeline, so the view is testable without the sim.
- `CharacterView` maps sim state → clips through `data/anim/<rig>/map.json` (owned by the rig's anim task; until it
  exists the view uses its defaults in `view/world/default_maps/<rig>.json`): `{"idle": "...", "walk": {"clip": "...", "stride_px": 67}, "run": ...,
  "activity:tea": "...", "state:chase": "...", "reaction": "<from sim>", "bit:<id>": "...", "freeze": ["..."]}`.
  Positions are interpolated between ticks with `SimDriver.alpha()`.
- `WorldView.hotspot_rects_in_view() -> Array` (id, kind, screen rect, priority) for tap-assist.

### 5.5 Camera (owner `view`)
```gdscript
class_name CameraDirector extends Camera2D
func setup(house: HouseDef) -> void
func follow(target: Node2D, lead_dir_fn: Callable) -> void
func set_hold_offset(on: bool) -> void                   ## +200 px while the action button is held
func pan_by(screen_delta: Vector2) -> void ; func pinch(factor: float, mid: Vector2) -> void
func toggle_overview() -> void
func peek(world_pos: Vector2, hold_s := 1.8) -> void
func request_gag(focus: Vector2, zoom: float, in_f: int, hold_f: int, out_f: int, priority := 0) -> int
func shake(trauma: float) -> void ; func kick(dir: Vector2, px: float) -> void
func is_gag_active() -> bool ; func visible_world_rect() -> Rect2
```
Framing, smoothing (exponential, never built-in `position_smoothing`), limits, gag punch-ins, peeks and the
one-at-a-time gag queue per GDD §3.7. Shake and kicks run in real time; follow and zooms in view time.
`reduce_motion`: no shake, punch-ins ≤ 1.15×, 0.25 s linear pans.

### 5.6 Bellows-Cam PiP (owner `view`)
`PipView`: a SubViewport sharing `world_2d`, its own Camera2D following Bellows (zoom 0.75), 448 × 252, rendered
at 30 Hz only while visible (`UPDATE_ONCE` every other frame), `canvas_cull_mask` excludes the FX/marker layer
(visibility layer 2). `set_visible_if(cond: bool)` with a 2 s hide delay; `escalate(on: bool)` → 704 × 396 Gag-Cam
window; `get_texture()` feeds the HUD's `PipFrame` widget (owner `ui`), which draws the frame (colour by temper tier),
the awareness glyph and handles the tap → `CameraDirector.peek`.

### 5.7 FX (owner `view`)
`FxLayer` (world space, pooled, no allocations after warm-up):
`caption(text, world_pos, size := 88)`, `stamp(text, world_pos)`, `burst(kind, world_pos, amount)`
(CPUParticles2D pool: dust, flour, feathers, drops, steam, sparkles, notes, roses — ≤ 8 emitters / 300 particles,
`fixed_fps = 30`), `ripple(world_pos)`, `path_dots(points)`, `noise_ring(world_pos, radius, color)`,
`footprints(points)`, `stare_strip(bellows_snapshot)`, `thought_bubble(actor_snapshot)`, `badge(hotspot, kind)`,
`busted_cam(buffer, spotted_tick)`. The Busted Cam re-stages the last 90 ticks from a view-side ring buffer of
both characters' `(room, x, facing, clip, frame)` with a red vignette, split-frame border, "SPOTTED!" and a dotted
line from his eyes to Hush (the sim holds Bellows still during `CAUGHT_HOLD`, so rewinding the views is safe).

### 5.8 Audio (`audio` owns the autoload and cues; `view` owns the director)
```gdscript
# autoload/audio.gd
func play_sfx(id: String, pan := 0.0, vol_db := 0.0, pitch := 1.0) -> void
func play_voice(bank: String) -> void                 ## random variant, never the same file twice in a row
func crowd(kind: String) -> void                      ## t0..t4, ooh, gasp, aww, shh, behind_you, chant, boo, relief
func music_state(state: String) -> void               ## curtain, sneak, suspense, chase, results, silence
func chain_section(n: int) -> void                    ## 0 off, 1..4 (Mountain King sections, switched on the bar)
func sting(id: String) -> void                        ## ducks Music −6 dB for its length
func set_bus_volume(bus: String, linear: float) -> void   ## Music, SFX, Voice, Crowd, UI
func has_sfx(id: String) -> bool
func set_voice_style(style: String) -> void           ## "formant" | "tuba" (Gate 0 A/B)
func set_crowd_style(style: String) -> void           ## "formant" | "fallback"
```
`data/audio/cues.json`: `{"events": {"rigged": {"sting": "rigged", "crowd": "t0"}, "near_miss": {"sting":
"near_miss", "crowd": "relief"}, ...}, "laugh_tiers": {"t1_max": 120, "t2_max": 240}, "music": {...}}`.
`AudioDirector` listens to `SimDriver.ticked` and `RigPlayer.clip_event`, pans by screen x, attenuates by rooms
between Hush and the source, picks laugh tiers from applause deltas (GDD §6.5), and drives music states
(suspense while a "?" fills or he's ≤ 2 s from an armed prank; chase in CHASE; chain sections by link). Missing
ids are silent no-ops (soft hook).

### 5.9 HUD and UI (owner `ui`)
- `HudModel` (plain RefCounted, filled by NightScene each frame from the snapshot): `applause, lines_done,
  lines_total, tomatoes_left, tomatoes_max, link, mult_pct, fuse_frac, temper_tier, verb (RIG|RIG_DIM|FREEZE|
  POP_OUT|GO), verb_item_icon, verb_target_icon, ring_frac, clarence_mode (SQUEAK|FF), lure_grey, rim (GREEN|
  AMBER|RED), tray (≤ 4 item ids), tray_highlight, figgis_pulse, pip_visible, pip_frame_tier, edge_bubble (dir,
  label), script (lines for the panel), pick_strip (container, items), paused`.
- `Hud.apply(model: HudModel)` is idempotent and allocation-free. Widgets emit **intents** (signals on `Hud`):
  `action_down(verb)`, `action_up(verb, cancelled)`, `clarence_down()`, `clarence_up(held_ms)`, `tray_tap(i)`,
  `pick(item)`, `figgis_tap()`, `pause_tap()`, `overview_tap()`, `pip_tap()`, `meter_tap()`.
- Widgets are custom Controls reading `InputEventScreenTouch/Drag` by index (two thumbs at once), STOP filter;
  full-screen containers use IGNORE. Sizes and positions exactly per GDD §3.8, anchored to `SafeArea` insets
  (symmetric sides, re-queried on resize, resume and every 0.5 s); tablets ×0.8 (`UiScale`).
- Panels: `ScriptPanel`, `PauseMenu` (Resume, Retry, Take a Bow when ★, Settings, Playbill), `SettingsPanel`
  (GDD §3.11), `LoadingCard`, `ResultsScreen` (curtain call layout, stars, why-missed line, Gag Reel slot,
  Next ▶ / Retry / Playbill). All text from `data/ui/strings.json`.
- `UiDemo.tscn` drives every widget from a scripted fake `HudModel` for screenshots.

### 5.10 The Stalls and Figgis (owner `view` for the Stalls; `ui` for the Figgis chip)
`StallsView`: one Node2D drawing 24 head sprites from one atlas in `_draw()` (one batched draw call) along the
bottom-centre band (GDD §3.8), resting 40 px, rising per tier with springs, T4: one head tumbles; no input
handling at all. The Figgis chip is a HUD widget with pulse/card/ghost states.

---

## 6. Input model (owner `ui` for gestures and widgets; NightScene maps intents to commands)
1. **World gestures** (`InputRouter`, touchux.md §6.3): `tapped(world_pos, is_double)`, `long_pressed(world_pos)`,
   `long_released(world_pos)`, `pan(screen_delta)`, `pinch(factor, mid)`. Touch-up activation; slop 24 px; tap
   ≤ 300 ms; double ≤ 280 ms / 64 px (never delays the first tap); long ≥ 450 ms; no drag starting within 48 px of
   a side edge; mouse events ignored (desktop tests use `emulate_touch_from_mouse`).
2. **Tap resolution** (`TapAssist.resolve(world_pos, candidates, zoom) -> Dictionary`): exact hit on a hotspot
   rect first; else the nearest hotspot within 90 screen px (90 / zoom world px); priority hotspot > door/stairs >
   floor; floor → `{c: move, room, x}`. Result → `go`/`move` (`run` = is_double or upgrade of the current walk).
   While Hush is hidden or frozen, taps become `pin`.
3. **Action button:** verb computed from the snapshot each frame with ≥ 250 ms hysteresis; **latched at
   touch-down**. RIG → `rig on` / `rig off` on release or slide-off (> 80 px); FREEZE → `freeze on/off`;
   POP OUT / GO → `pop_out` on touch-up. Tap-to-rig setting converts holds to toggles.
4. **Clarence:** touch-up < 500 ms → `squeak`; hold ≥ 500 ms → `wheeze on` … `wheeze off`; ignored if it began within
   150 ms of an action press; while hidden it is ⏩ (`SimDriver.set_ff`).
5. **Feedback within 16 ms** of every accepted tap: ripple, dotted path, 8 ms haptic (Haptics autoload).
6. **Pause/back:** `NOTIFICATION_WM_GO_BACK_REQUEST` → Router → scene `handle_back()` → pause.
7. Every accepted command is logged (`[tick, cmd]`) so a device session can be replayed headless (debug builds
   write `user://last_session.json`).

## 7. Save data and settings (owner `ui`)
- `Save` autoload → `user://save.json`, written atomically (`.tmp` + rename), debounced 0.5 s:
```json
{"version": 1, "prologue_done": true,
 "nights": {"n01_throat_tea": {"played": 3, "stars": [true, true, false], "best_applause": 92,
            "lines": ["kettle", "tap", "pickle"], "candles": [], "encores": []}},
 "seen": {"rx:achoo_ria:t1:a": true, "bit:bit_tea": true, "combo:dough_man": true},
 "stats": {"catches": 4, "pranks": 17, "play_s": 1240}}
```
  API: `night(id) -> Dictionary`, `record_result(id, result: Dictionary)`, `mark_seen(key) -> bool` (true if new →
  "+NEW!"), `is_seen(key)`, `set_prologue_done()`, `flush()`. Unknown versions are migrated or backed up, never
  crash.
- `Settings` autoload → `user://settings.cfg`: `music_vol, sfx_vol, voice_vol, crowd_vol, haptics, relaxed,
  tap_to_rig, left_handed, hints (always|long_press|off), stare_strip, reduce_motion, reduce_flash, text_scale`;
  signal `changed(key, value)`.

---

## 8. The solver bot and QA automation (owner `solver`)
Goal: prove, on every build, that every episode is **completable**, **3-starable** and **fair**, and measure the
numbers the fun gate needs (time to first laugh, dead air, durations). Everything runs headless on `SimWorld`
(no rendering) through the sandbox scripts.

### 8.1 Pieces (`game/solver/`)
| File | Class | Job |
|---|---|---|
| `solution_def.gd` | `SolutionDef` | parse + validate `data/solutions/<episode>.json` |
| `executor.gd` | `Executor` | turn macro steps into per-tick commands; timeouts; failure reasons |
| `personas.gd` | `Persona` | `ideal`, `required`, `slow` (first-timer), plus fuzz bots |
| `metrics.gd` | `Metrics` | consumes events → the run report |
| `planner.gd` | `Planner` | the auto-solver (§8.4) |
| `invariants.gd` | `Invariants` | fairness assertions over an event log (§8.6) |
| `fuzz.gd` | `Fuzz` | random/reckless bots + invariants |
The condition language (§8.2) is evaluated by `Conditions` in `sim/systems/conditions.gd` (owner `sim`; the sim's
Director uses it too); the solver only consumes it. Entry points: `game/tools/solve.gd`, `game/tools/fuzz.gd`; shell: `tools/scripts/solve.sh`, `tools/scripts/fuzz.sh`.

### 8.2 Solution files (`data/solutions/<episode>.json`, authored by `content`, verified by `solver`)
```json
{"version": 1, "episode": "n01_throat_tea", "routes": {
 "ideal": {"persona": "ideal", "steps": [
   {"do": "pick", "item": "squeaker", "from": "hall_confiscated_box"},
   {"do": "wait", "until": {"bellows_not_in_room": "kitchen"}, "max_s": 40},
   {"do": "rig", "prank": "kettle_drum"},
   {"do": "rig", "prank": "achoo_ria"},
   {"do": "rig", "prank": "tap_dance"},
   {"do": "hide", "spot": "kitchen_pantry_curtain"},
   {"do": "wait_event", "event": "reaction_end", "match": {"prank": "tap_dance"}, "max_s": 90},
   {"do": "bow"}],
  "expect": {"stars": [true, true, true], "applause": [100, 140], "catches_max": 0, "duration_s": [120, 300]}},
 "required": {"persona": "ideal", "steps": [], "expect": {"stars": [true, null, null]}},
 "slow": {"persona": "slow", "steps": [], "expect": {"stars": [true, null, null], "first_player_laugh_s_max": 10,
          "first_prank_s_max": 30, "dead_air_pct_max": 20}}}}
```
- **Steps:** `go {to, run}`, `move {room, x, run}`, `pick {item, from}`, `rig {prank, step?}` (walks there and holds
  until the step completes), `hide {spot}`, `pop_out {to?, run}`, `freeze {until, max_s}`, `squeak {n, gap_s}`,
  `stand_in {prank: "mirror_mirror", release_round}`, `panto {rounds}`, `wait {until, max_s}`,
  `wait_event {event, match, max_s}`, `idle {s}`, `bow`.
- **Conditions** (shared with episode `director.when`): `bellows_activity`, `bellows_activity_in`,
  `bellows_state`, `bellows_in_room`, `bellows_not_in_room`, `bellows_eta_to_room_gt_s [room, s]`,
  `bellows_activity_remaining_le_s`, `bellows_facing_away_from_hush`, `hush_visible`, `hush_hidden`,
  `spot_meter_pct_ge`, `prank_state [id, state]`, `temper_tier_ge`, `link_ge`, `line_done`, `all_required_done`,
  `tick_ge_s`, `first_squeak`, `first_rig`, `event_seen`, `and`, `or`, `not`.
- **Expect keys:** `stars` (null = don't care), `applause [min, max]`, `lines`, `catches_max`, `duration_s`,
  `first_player_laugh_s_max`, `first_prank_s_max`, `laughs_by_s [[s, n], ...]`, `dead_air_pct_max`,
  `max_gap_s_max`. Launch-relative checks add `episode.director.launch_offset_s` (Prologue: 2.3 s, re-measured on
  a device in Stage 2).

### 8.3 Personas
- `ideal` — zero decision latency, runs when safe, uses ⏩ implicitly (the solver simply steps ticks).
- `required` — executes only required lines (proves ★ without optional content).
- `slow` — a first-timer: 0.6 s latency before each step, 3 s dawdle at the start, one wrong glowing tap per
  Night, tiptoes only, hides as soon as a warning appears, never uses pins or the queue.
- Fuzz bots (§8.6): `random`, `reckless`, `hider`, `bait`.

### 8.4 The auto-planner (`Planner`)
1. **Predict:** clone the world and run it with Hush hidden and idle for two loops → the activity timeline (who is
   where, when), fix-up stations per residue, in-use hiding spots.
2. **Tasks:** each Script line → a macro template from content (items → containers, rig steps, trigger activity,
   knock-on/condition requirements; goal lines → templates: Meltdown = chain three rigs on one loop segment,
   panto = `panto {rounds: 3}`, etc.).
3. **Search:** beam search (width 6) over task orderings and timing windows. Each candidate is executed on a
   **clone** with the real executor; a window is safe when Bellows' predicted room differs from the task room for
   (walk + rig + escape) ticks, or he faces away with Hush outside his range. Failures (spotted) retry with the
   next window; hiding picks the nearest spot not `in_use_next`.
4. **Score:** lines done > stars > applause (target ≥ 100) > shorter duration > fewer catches.
5. **Proofs written to the report:** every line achievable alone from the start; the whole Script achievable; ★★★
   reachable (applause ≥ 100); a soft-lock check (inject 3 forced catches at random ticks, re-plan the remaining
   lines, must succeed). Output `data/solutions/_auto/<episode>.json` (never overwrites authored files).
6. Budget: ≤ 60 s wall time per episode in CI.

### 8.5 Metrics (per run report, JSON)
`{episode, route, persona, ok, fail[], duration_s, stars, applause, lines, catches [{t, cause}], near_misses,
first_player_laugh_s, first_prank_s, laughs [{t, kind}], laughs_by_60, dead_air_pct, max_gap_s,
prank_interval_mean_s, hold_total_s, hash}`.
- A **laugh** is `SimEvents.is_laugh(ev)`; *player-caused* excludes `director_cue laugh_*`.
- A tick is **dead air** when there was no player command in the previous 180 ticks, no laugh in the previous 300,
  and Bellows isn't reacting. Target < 20 % per Night; `max_gap_s` ≤ 10 on ideal routes.

### 8.6 Fairness invariants (`Invariants`, run on every solver and fuzz log)
1. Every `caught` has a preceding "?" that filled continuously for ≥ the episode's fill time (or a
   `face_to_face` window ≥ 48 ticks) in which escape was possible.
2. Every `b_room` into Hush's room (not in CHASE) has an `entry_warning` ≥ 90 ticks earlier.
3. No `caught` while Hush is in an unwatched hiding spot that is not in use.
4. `b_next` shows each loop activity ≥ 240 ticks before it starts when the previous activity is ≥ 4 s long;
   every `b_detour` has a `b_next` on the same tick.
5. Determinism: the same command log gives the same hash (run twice).
6. No soft-lock: the planner completes all required lines after the fuzz run's state (sampled every 60 s).
7. Bellows' non-chase speed ≤ 1.15 × walk; the `b_activity` sequence follows the loop order (detours excluded).
8. No `spot_start` by Bellows while he is reacting or within 60 ticks after.
9. Progress: Bellows' activity changes at least every 60 s; Hush commands produce movement or a rejection event.
10. At most one reaction active at a time; applause never negative; each Night's prank bases sum to 700 tenths.
11. (Stage 3) Beryl's headbutt never produces `caught`.
Fuzz bots: `random` (a random valid command every 0.2–2 s), `reckless` (straight to rig points ignoring Bellows),
`hider` (hides, squeaks, pops out), `bait` (gets spotted on purpose and runs over STEP pranks). CI runs 20 runs
per final episode per bot with fixed seeds; the nightly/local run uses 200.

---

## 9. Performance budgets
| Budget | Target (mid-range Android: Adreno 610 / Mali-G52 class) | How it's measured |
|---|---|---|
| Frame rate | 60 fps p95 (never 30 by Swappy: `swappy_mode = 0`) | DevShot `--perf-log`, on-device overlay |
| Draw calls | ≤ 150 p95, 250 hard ceiling (PiP visible + a gag burst) | `RENDER_INFO_DRAW_CALLS_IN_FRAME` |
| Per character | ≤ 12 draw calls, ≤ 0.25 ms CPU | rig perf test (`tests/rig/`) |
| Sim | ≤ 0.05 ms/tick desktop headless, ≤ 0.3 ms/tick on device | `tests/sim/test_perf.gd` |
| Particles | ≤ 8 emitters, ≤ 300 live particles, CPUParticles2D only | FxLayer caps + perf log |
| CanvasGroup / Light2D | ≤ 1 CanvasGroup on screen; no Light2D | code review + lint grep |
| Textures | ≤ 250 MB total (target 150); pages ≤ 2048² preferred | `RENDER_TEXTURE_MEM_USED` |
| Startup | first frame ≤ 2.5 s; curtain rises ≤ 3.1 s; **first player-caused laugh reachable ≤ 10 s from launch** | device log timestamps |
| Allocations | none per frame in the sim, sampler, FX pools, HUD apply | code review + profiler spot checks |
| APK | ≤ 150 MB; audio ≤ 40 MB | CI artefact size |
| Memory | ≤ 500 MB RSS | on-device |

---

## 10. Test strategy
### 10.1 Layers
| Layer | What | Owner | Where |
|---|---|---|---|
| Unit | every sim system; rig sampler/eases/springs; atlas packer; tap-assist; gesture classifier; HUD model mapping; save/settings; audio cue mapping | each task | `tests/<area>/test_*.gd` |
| Golden | command logs → state hashes at checkpoints; pose hashes per clip | sim, rig | `tests/sim/golden/`, `tests/rig/golden/` |
| Solution replays | every route of every `final` episode meets its `expect` | solver (runner), content (routes) | `tests/solver/test_solutions.gd` |
| Fairness fuzz | §8.6 invariants | solver | `tests/solver/test_fuzz.gd` (bounded) |
| Lints | content, hotspot, IP, animation, rig | solver (content/hotspot/IP), rig (anim/rig) | `tools/scripts/lint.sh` |
| Screens | each scene/demo renders at 1200×540 with no errors, and is *looked at* | every UI/view/art task | `docs/review/<task>/` |
| Device | the owner checklist (GDD §10.4, touchux.md §6.7) | Stage 2+ | PROGRESS.md |

### 10.2 Rules for every test
- Tests run only through `tools/scripts/test_game.sh <unique-sandbox> [-- filter]`. The runner fails on any
  script error or unexpected engine error.
- Sim tests never instantiate Nodes. View/UI tests may, and must free them.
- A test that depends on a module still being built (another task) uses a soft hook and `skip()`s with a clear
  reason when the module is absent; Stage-2 integration removes those skips.

### 10.3 Definition of done per task
Tests green in the task's sandbox; lints for the task's files green; screenshots / sheets written to
`docs/review/<task>/` **and looked at**; the final report lists public APIs, verification and requests.

### 10.4 Device checklist (owner-facing, Stage 2+)
touchux.md §6.7 plus GDD §10.4: both landscape orientations; nothing under the punch-hole; 19/20 taps on a 60 px
hotspot; pan while hidden never moves Hush; hold ring readable under the thumb; 36 px text readable at arm's
length; 60 fps with PiP + gag burst; launch → first laugh ≤ 10 s.

### 10.5 Lints (definitions)
- **Content lint** (`game/tools/lint/content_lint.gd`): ids resolve; every prank's trigger activity appears in the
  loop of every Night that lists it; every needed item has a source container in the Night's rooms; Script ≤ 7
  lines, 3–6 plus Big Number; prank bases sum to 700 tenths; loading card ≤ 25 words; one `new_rule` per Night;
  residue fix-up kinds have a station on each floor used; `reactions.json` covers every archetype; captions ≤ 18
  characters; `time_jitter == 0` on reaction clips.
- **Hotspot lint** (`hotspot_lint.gd`): hit boxes ≥ 144 × 144; ≥ 24 px gaps; no overlaps (hotspots, doors, stairs)
  per room; use points inside the room; station x within 80 px of the GDD table.
- **IP lint** (`ip_lint.gd`): case-insensitive scan of `game/data/**`, `game/ui/**`, `docs/GDD.md` Script and
  caption text for banned terms: `neighbours from hell, neighbors from hell, woody, rottweiler, olga, golden
  neighbour, viewer rating, audience rating, street share, golden remote, trap camera, season 1, episode rating,
  on air, channel 11` and the nfh.md §9 gag keywords (`binoculars, laxative, mousetrap, fart cushion, drawing pin,
  marbles, banana peel, cactus`).
- **Animation lint** (`game/tools/anim/lint_anim.gd`, comedy.md §7.6): frames increase; ids resolve; joint limits;
  loop seams ≤ 0.5° with continuous velocity; accent ≤ 4 f with ≥ 20°/f peak on some part; anticipation opposes
  the accent (dot < 0); reaction holds ≥ 24 f (≥ 36 f at tier ≥ 2); no dead hold > 20 f unless `freeze`; no jump
  > 45°/f unless `pop`/smear; no L/R twinning > 10 f; planted feet drift ≤ 2 px and never > 3 px below the floor;
  impact sfx within ±1 f of a key; face swaps only on keys; laugh after the accent; reactions 60–240 f (signatures
  ≤ 420) unless `skippable`; bounding box changes ≥ 15 % from anticipation to accent; beats match
  `reactions.json` within 2 f.
- **Rig lint:** every part file exists and parses; pivots inside the canvas; parent chain acyclic; mirror pairs
  resolve; face slot variants exist; the rest pose silhouette at 50 px is non-empty and within 20 % of
  `height_px`.

---

## 11. Review tooling (agents must LOOK at their work)
- **Screenshots:** `tools/scripts/shot.sh res://scenes/x.tscn out.png [frames] [sandbox] -- [user args]`
  (1200×540 = 20:9; `SHOT_SIZE=960x540` 16:9, `SHOT_SIZE=1080x810` 4:3). **Frame sequences:** add
  `--shot-seq=/abs/dir --every=N --count=K`.
- **Animation sheets:** `tools/scripts/anim_sheet.sh <rig> <clip|--poses|--rig> <out_dir>` (xvfb + opengl3,
  renders with the game's own sampler in a SubViewport) writes:
  - `rig.png` (exploded parts with pivot crosshairs + the rig at joint limits);
  - `poses.png` (every pose labelled + a solid black silhouette at 50 px and at phone size);
  - `<clip>_contact.png` (a cell every 3 f + every key; keys outlined red, holds blue; events printed under cells;
    a second copy at true phone scale);
  - `<clip>_onion.png` (per beat, frames tinted blue → red, spacing dots on head top, hands and root);
  - `<clip>_curves.json` → `tools/anim/curves.py` → `<clip>_curves.png` (value + velocity per channel, key markers);
  - `<clip>_lint.txt`.
- **Capture:** `tools/scripts/capture.sh <res://scene.tscn> <frames> <out.gif> [-- args]` uses Movie Maker
  (`--write-movie f.png --fixed-fps 60`) and `tools/anim/gif.py` (Pillow, 30 fps GIF + a mute copy); the WAV is
  kept for sync checks (numpy onset detection vs `mark` frames).
- **Review folders:** each task writes `docs/review/<task-key>/index.md` listing every artefact with one line on
  what it shows and what to judge. PNG/GIF only (no multi-MB videos in git; GIFs ≤ 4 MB).
- **The review agent rubric** (per gag, from contact sheet + GIF, answered in writing with frame numbers): reads in
  silhouette at phone size? anticipation opposes the action? accent ≤ 4 f with a pop or smear? a ≥ 30 f hold where
  the face reads? exactly one overshoot? sfx on the contact frame? face swap on the accent? sliding or floor
  penetration? laugh after the hold starts? how is it different from the last time the player saw it? Then a
  1–5 score on *funny*, *readable*, *fresh*; < 3 on any → back to the author.
- **Mute test pack:** `docs/review/mute_test/` — 6 silent GIFs of slice reactions, shown to a fresh review agent
  that doesn't know the pranks; ≥ 4 must read as jokes.

---

## 12. Build and CI
- Existing: `tools/scripts/{sandbox,test_game,shot,export_android}.sh`, `tools/ci/{check_import_meta,export_lib,
  verify_android}.sh`, `.github/workflows/{ci,android-preview}.yml`.
- New (Stage 1): `tools/scripts/{solve,fuzz,lint}.sh` + `tools/ci/lint_all.sh` (solver), `tools/scripts/
  {anim_sheet,capture}.sh` (rig), `tools/scripts/gen_audio.sh` (audio: `python3 tools/audio/gen_audio.py` +
  `--check`).
- **CI jobs** (`.github/workflows/ci.yml`, solver edits): import metadata → GDScript tests → lints → solutions for
  `final` episodes → bounded fuzz → `gen_audio.py --check`. Android preview APK on every push to `main` (exists).
- **Import metadata:** every new asset/script ships its `.import` / `.uid` sidecar. Agents never run Godot on
  `game/` directly; the orchestrator runs one import on the real project after each stage and commits sidecars.

## 13. Parallel-build rules (binding for every task)
1. Only create or modify files you own (§1, your brief). Need a change elsewhere? Put a precise request in your
   final report (file, what, why).
2. **Soft hooks** when you depend on a module being built in parallel:
```gdscript
const _SIM_WORLD := "res://sim/world/sim_world.gd"
static func _soft_script(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null
# ...
var sw := _soft_script(_SIM_WORLD)
if sw == null:
	skip("sim not built yet")   # tests; runtime code falls back to a stub or does nothing
	return
```
   Autoload methods that may not exist yet are called behind `has_method`. Stage 2 converts soft hooks to typed
   calls.
3. Keep public APIs exactly as specified here; add optional parameters only with defaults that preserve behaviour.
4. Unique sandbox names per task (`tools/scripts/test_game.sh <task-key>`); scratch output under
   `<scratchpad>/mnd/work/<task-key>/`; reports to `<scratchpad>/mnd/reports/<task-key>.md`.
5. Never run git write commands; the orchestrator commits.
6. No placeholder TODOs where an implementation is asked for; if something is cut, say so in the report.

---

## 14. Canonical ids (binding — parallel tasks must use exactly these)
Adding an id is allowed (report it); renaming one is not.

- **Rigs:** `hush` (skin `pip` = fallback), `bellows`, `beryl`, `delphine`, `figgis`, `stalls`, `_mannequin`.
- **Rooms:** `porch, hall, parlour, kitchen, conservatory, garden, landing, bathroom, bedroom, dressing`.
- **Links:** `front_door` (door porch↔hall), `hall_parlour`, `parlour_kitchen` (doorways), `back_door` (door
  kitchen↔conservatory), `conservatory_garden`, `landing_bathroom`, `bathroom_bedroom`, `bedroom_dressing`
  (doorways), `stairs` (hall foot ↔ landing head).
- **Stations** (`kinds` in brackets): `st_gramophone, st_piano, st_recliner, st_fireplace [DRY], st_chaise,
  st_parlour_centre` (parlour) · `st_tea [HONEY], st_pickles, st_fridge, st_sink [SINK]` (kitchen) ·
  `st_hall_mirror [MIRROR], st_phone, st_clock, st_front_door` (hall) · `st_feed_bin, st_sun_lounger [DRY]`
  (conservatory) · `st_hose, st_marrow, st_path, st_stage` (garden) · `st_radiator [DRY]` (landing) ·
  `st_basin [SINK, MIRROR], st_bath` (bathroom) · `st_wardrobe, st_bed` (bedroom) · `st_dressing_mirror [MIRROR],
  st_trophy, st_dummy` (dressing).
- **Hotspots — containers:** `hall_confiscated_box, hall_piggy_bank, kitchen_fridge, kitchen_pantry_shelf,
  bathroom_cabinet, conservatory_potting_bench, dressing_costume_trunk`.
- **Hotspots — hiding** (in-use activity): `hall_coat_cupboard, hall_clock_case (clock), parlour_piano_back,
  parlour_chaise_back, kitchen_pantry_curtain, kitchen_table, conservatory_hamper, garden_shed, garden_compost,
  landing_airing_cupboard, bathroom_bath (bath), bathroom_laundry_basket, bedroom_wardrobe (dress),
  bedroom_under_bed, dressing_costume_rail`.
- **Hotspots — rig points** (prank): `kitchen_honey (achoo_ria), kitchen_kettle (kettle_drum), kitchen_pickle_jar
  (in_a_pickle), kitchen_fridge_shelf (cold_open), kitchen_sink_tap (tap_dance), parlour_gramophone
  (allegro_go_go, it_takes_two), parlour_recliner (lift_off), parlour_newspaper (eye_popping_news),
  parlour_bellows (bellows_blows), parlour_chandelier (prima_ballerina), parlour_piano_wedge (grand_exit),
  parlour_tea_tray (spit_take), parlour_fan (fan_mail), hall_phone (something_fishy), hall_clock (times_up),
  hall_mirror (mirror_mirror; stand-in point = the frame), stairs_rods (rug_burn), bathroom_basin_spray
  (sopran_oh_no), bathroom_duck (snap_decision), bathroom_bath_taps (in_over_his_head), landing_boiler_valve
  (pipe_down), bedroom_pillow (pillow_talk), bedroom_bedside (butter_fingers), bedroom_bed (kidding_around),
  dressing_dummy (tutu_much), dressing_trophy_shelf (award_winning), conservatory_feed_bin (sweet_tooth),
  garden_hose (hosed), garden_marrow (marrow_escape), garden_coin_1, garden_coin_2, garden_coin_3
  (penny_pincher), garden_spotlight (spotlight_stealer)`.
- **Hotspots — exits, doors, stairs:** `hall_front_door` (exit + Take a Bow), `kitchen_back_door`, `stairs_foot`,
  `stairs_head`, `kitchen_window` (Hush's entry, not tappable).
- Where two hotspots share an object (fridge + fridge shelf, pantry shelf + curtain, clock face + case, airing
  cupboard + boiler valve, bath taps + bath, bed + under-bed + pillow, stair rods + stair foot), their hit boxes are
  **stacked vertically** with the 24 px gap; the hotspot lint checks it.
- **Items:** `squeaker, magnifier, balloon, croc, kipper, butter, flour, sherbet, treacle, salt, bubble_bath,
  apple, feathers, coins, tutu, record`.
- **Activities:** `warmup, tea, pickles, snack, rinse, paper, fire, mirror, phone, clock, piano, gargle, bath,
  radiator, dress, nap, feed_beryl, roses, marrow, stroll, polish, cloak, answer_door, host_tea, tango, rehearse,
  hunt`. Detours: `fixup_dry, fixup_sink, fixup_honey, fixup_mirror, curious, herd_beryl, search`.
- **Pranks:** `achoo_ria, tap_dance, kettle_drum, in_a_pickle, cold_open, allegro_go_go, lift_off,
  eye_popping_news, bellows_blows, prima_ballerina, grand_exit, it_takes_two, something_fishy, times_up,
  mirror_mirror, rug_burn, sopran_oh_no, snap_decision, in_over_his_head, pipe_down, pillow_talk, butter_fingers,
  kidding_around, tutu_much, award_winning, hosed, marrow_escape, penny_pincher, sweet_tooth, spit_take, fan_mail,
  spotlight_stealer`.
- **Squeak bits:** `bit_warmup, bit_tea, bit_paper, bit_mirror, bit_phone, bit_bath, bit_nap, bit_feed, bit_piano,
  bit_livid`.
- **Residues:** `SOAKED, FLOURY, STICKY, SQUEAKY, FRAZZLED, FEATHERED, COSTUME`; fix-up kinds `DRY, SINK, HONEY,
  MIRROR`. **Combos:** `dough_man, poodle, chicken, mad_maestro`. **Double Acts:** `hot_and_cold, up_in_smoke,
  marrow_mayhem, encore, tea_for_two, curtain_call`.
- **Episodes:** `p00_curtain_up, n01_throat_tea, n02_something_fishy, n03_singing_in_the_bath, n04_the_big_sulk,
  n05_enter_beryl, n06_behind_you, n07_kidding_around, n08_companys_coming, n09_tutu_much, n10_it_takes_two,
  gala_the_comeback`.
- **Reaction archetypes** (`reactions.json` keys add `_a/_b/_c`): `sneeze_blast, drench, sing_crack, strain_slip,
  avalanche_helmet, dizzy_spin, launch_ceiling, blind_bumble, poof, drop_on, fish_slap, jackhammer_cling,
  surf_out, squeaky_voice, scare_leap, steam_duel, feather_burst, costume_burn, balloon_chase, headbutt_launch,
  goat_kiss, suppressed`; signatures `sig_mirror_mirror, sig_in_over_his_head, sig_grand_exit,
  sig_kidding_around, sig_it_takes_two, sig_spotlight_stealer`.
- **Clip ids:** `<rig>/<prefix>_<name>` with prefixes `loco_` (idle, walk, strut, run, turn, door, stairs), `act_`
  (activities), `rx_` (reactions, e.g. `bellows/rx_sneeze_blast_a`), `sig_`, `bit_`, `st_` (states: suspicious,
  double_take, look, chase, wheeze, grab, search, bump, bonk), `lec_` (Lecture a/b/c), `melt_` (a/b/c, exhausted),
  `combo_`, `beat_` (T3 last beats, suppressed), `cold_` (cold opens), `hush/` specifics: `act_tinker_q|s|b,
  act_rummage, act_dive, act_pop, act_squeak, act_snicker, freeze_1..8, st_busted, lec_dangled, st_doorstep,
  act_bow, act_climb_in`.
- **Director cues (Prologue):** `laugh_vase, figgis_psst, ghost_squeak, ghost_honey, ghost_hold, ghost_hide,
  sparkle_lever, title_card`.
- **Audio ids:** SFX `snake_case` (`sneeze_choo`, `woodblock_bonk`…); voice banks `vo_<speaker>_<line>`; crowd
  `crowd_<tier>`; stings `sting_<id>`; music `mus_<state>` and `mus_chain_1..4`. `sfx_map.json` aliases resolve.
