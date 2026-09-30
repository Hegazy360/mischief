# Mischief Next Door — Technical Design and Contracts (v1.1-3D, BINDING)

Godot **4.7.2**, GDScript (typed, tabs, `##` docs), Compatibility renderer, **a 3D view (Node3D world, Camera3D) with
a 2D HUD and overlays** (branch `r3d`; `main` keeps the 2D view), 1920×1080 base, `canvas_items` + `expand`,
landscape (`SENSOR_LANDSCAPE`). Design: `docs/GDD.md` v1.2 (binding) + `docs/REDESIGN_3D.md` (the 3D spec). Plan:
`docs/PLAN.md`.
This document is the contract between parallel agents: module boundaries, file ownership, data formats, public
APIs, events, determinism rules, tools, budgets and tests. If code and this document disagree, fix the code or
raise a request — never silently diverge.

**Versions.** **v1.1-3D (2026-09-30, the 3D pivot)** adds the 3D view's contracts *as designed* for R3D (the build plan
and binding contract text are `<SP>/tasks/r3d-index.md` §7, R1–R19; the lead decisions D6–D7 in `<SP>/issues.md`): the
header, §1.1 (the 3D module map, owners, export filters), §2 (world units, axes, depth bands), §3.10 (the live mask, the
Bellows-window reason), §4.1 note, §4.6 (`hides`), §4.10–§4.13 (`rig3d.json`, the clip sidecar v2 + `.res`,
`house3d.json`, `previews.json`, `rig_actions.json`), the §5 intro and §5.11–§5.19 (the 3D view: scene tree,
`RigPlayer3D`, `WorldView3D` / `House3D` / `SetList`, `CameraDirector3D`, `PipView3D` + C8, decals and overlays, shaders
and the lighting model, audio, HUD, Stalls), §6–§8 notes, §9 (3D budgets), §10.5 (the 3D lints), §11 (3D review
tooling), §12 (Blender, the bake, CPU slots, shader globals, R16), §13 (the R3D rules), §14 (the new ids). Text that
only the 2D build uses is marked **"(2D, main only)"**: it stays true on `main` and on `r3d` until `r3d-integrate`'s
reachability scan deletes the 2D path. `r3d-qa` folds the as-built deltas in at the end of R3D. v1.0 — the Stage-1
contracts.

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
5. **Phone-first performance.** Atlased cutout rigs, pooled FX, no per-frame allocations in hot paths. (3D: one
   palette material per room set and per character, merged static set meshes, lighting computed in the shader, no
   real-time lights or shadows, ≤ 4 draw calls per character, pooled decals and CPUParticles3D; §9.)

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

### 1.1 The 3D modules (v1.1-3D; branch `r3d`; owners are the R3D task keys of `r3d-index.md` §4)
New 3D code lives in **new folders**; the 2D modules REDESIGN §6.1 lists as *replaced* (`view/rig/**`,
`view/tex/{atlas_builder,atlas_set}.gd`, `view/world/{world_view,character_view,room_view,prop_view,hotspot_view,
house_art,decor_set,house_layout,stage_view,hidden_eyes,fallback_puppet}.gd`, `view/camera/camera_director.gd`,
`view/pip/pip_view.gd`, the 2D decal FX, `data/rigs/{hush,bellows,_mannequin}/**`, `data/anim/{hush,bellows,
_mannequin}/**`, `art/chars/{hush,bellows}/**`, `art/house/**`) are **(2D, main only)**: frozen on `r3d`, untouched and
green, until `r3d-integrate`'s reachability scan deletes what no live 3D file reaches. **A replaced 2D file is frozen
whatever ownership glob covers it.**
```
game/
  view3d/                                                                     [r3d-view3d, except char/ and set/]
    world/     world_view_3d.gd (WorldView3D + the overlay-anchor source) character_view_3d.gd (CharacterView3D)
               decals_3d.gd fx_3d.gd
    camera/    camera_director_3d.gd (CameraDirector3D)
    pip/       pip_view_3d.gd (PipView3D — the Bellows window)
    stage/     stage_lighting_3d.gd (StageLighting3D) view3d_const.gd (View3DConst) material_warm_3d.gd (MaterialWarm3D)
    sandbox/   ViewSandbox3D.tscn + script (FakeWorld / --sim)                (not exported)
    probe/     PerfProbe3D.tscn + script (the on-device perf probe)           (not exported)
    char/      RigDef3D ClipLib3D (+ ClipDef3D) RigPlayer3D (rig_player_3d.gd) RigSampler3D PlayPlan3D
               (play_plan_3d.gd) face cards (face_cards_3d.gd) ClipEvents3D PropSim3D CharStandIn3D   [r3d-rig]
    set/       House3D SetList Prop3D HideSpot3D                              [r3d-sets]
  art3d/
    chars/hush/ (hush.glb, hush_head_b.glb when proposed, face_hush.png, palette_hush.png, tag_beret.glb, plinth.glb)
                                                                              [r3d-cast-hush]
    chars/bellows/ (bellows.glb, attachments, face atlas, palette, props)     [r3d-cast-bellows]
    anim/<rig>/<clip>.res   one baked Animation per clip                      [the animation keys, by clip]
    set/ props/  architecture, furniture, dressing, live props (glb + palettes)  [r3d-sets]
    shaders/ fx/ the shaders of §5.17, decal textures, FX meshes              [r3d-view3d]
    CREDITS.md   source URL + licence of every third-party file               [orchestrator]
  data/
    rigs3d/<rig>/rig3d.json (+ rig3d_<variant>.json), faces.json               [cast task of the rig]
    anim/<rig>3d/<clip>.json  clip sidecars v2 (§4.11); map.json               [the animation keys; map: r3d-anim / -bellows-a]
    anim/hush3d/rig_actions.json                                              [r3d-content]
    view/previews.json                                                        [r3d-content]
    house/house3d.json                                                        [r3d-sets]  (house.json, cold_sets.json: frozen)
  tools/anim3d/   sheet3d.gd capture3d.gd (in-engine 3D review tools)         [r3d-rig]
  tools/anim/     lint_anim.gd (+ --format=3d) lint3d_rules.gd lint3d_limits.json glb_to_res.gd  [r3d-anim]
  tools/lint3d/   set / screen-rect / HUD / visibility lints, visibility_check.gd, perf checker  [r3d-tools-b]
  scenes/dev/anim3d/   AnimViewer3D.tscn RigPerf3D.tscn                        [r3d-rig]
  scenes/dev/set3d/    SetPreview3D.tscn                                       [r3d-sets]
  scenes/dev/review3d/ LintShot3D.tscn                                         [r3d-tools-b]
  ui/world/       OverlayModel, OverlayRules, OverlayPlacer, WorldOverlays (CanvasLayer 8)  [r3d-hud]
  tests/          view3d/ rig3d/ set3d/ cast3d/ anim3d/ lint3d/ (+ the existing folders)  [each owner]
tools/ (repo root)
  art3d/setup_blender.sh blender.sh README.md SOURCES.txt vendor/ual/**       [orchestrator]
  art3d/look-toy/** look-cartoon/** spike/** diorama/**   the look-dev references (frozen)  [orchestrator]
  art3d/hush/** art3d/bellows/**   character builders (Blender)               [cast tasks]
  art3d/set/**                     set builders (Blender)                     [r3d-sets]
  art3d/anim/lib/** bake.sh README.md   the clip pipeline                     [r3d-anim]
  art3d/anim/<rig>/<clip>.py       clip specs                                 [the animation keys, by clip]
  art3d/anim/bellows/_lib/**       Bellows pose presets                       [r3d-anim-bellows-a]
  art3d/review/**                  the shared review toolset (§11.1)          [r3d-tools-a]
  scripts/slot.sh                                                             [orchestrator]
  scripts/{lint3d,perf3d}.sh                                                  [r3d-tools-b]
  scripts/anim_sheet3d.sh, capture.sh (switched to capture3d.gd)             [r3d-rig]
  ci/setup_godot.sh                                                           [orchestrator]
```
**Export filters (3D):** include `art3d/**` (glb, png, res), `data/rigs3d/**`, `data/anim/*3d/**`, `data/view/**`,
`data/house/house3d.json`; exclude `tests/`, `tools/`, `scenes/dev/`, `view3d/sandbox/`, `view3d/probe/`,
`view/sandbox/`, `ui/demo/`, every `_src/` folder and `data/solutions/` (`r3d-night` owns `export_presets.cfg` in R3D).
The perf-probe APK (a throwaway `r3d-probe` branch) is the one build that ships `view3d/probe/`.
Class names above are the contract; file names not given in `r3d-index.md` are the owners' (the as-built list is
`r3d-qa`'s fold-in).

---

## 2. Conventions
- **World space:** px at zoom 1.0; x grows right; **y grows down**; the ground floor line is y = 0, the upper
  floor line y = −700. A floor is 640 px of interior above its line plus a 60 px slab below it.
- **Sim units:** positions are integer **sub-pixels, `SUB = 60` per px**, so a speed of V px/s moves exactly V
  sub-px per tick. Time is integer **ticks, 60 per second**. JSON uses px and seconds; conversion happens only at
  load (`Fx.px(v)`, `Fx.ticks(sec)`, round half away from zero).
- **Facing:** `+1` right, `−1` left. Art faces right; the view mirrors with `scale.x = -1` (2D, main only). In 3D
  facing is a **body yaw** (+90° right / −90° left, a 6-frame eased turn) plus the cheat-out toward the camera —
  **never a negative scale**; asymmetric face marks swap to mirrored atlas cells by facing.
- **3D world units and axes (v1.1-3D, ruling R4):** metres; **1 m = 200 sim px** (`x_m = x_sub / 12000`); Godot axes
  **+x right, +y up, +z toward the camera**. Floor `f` stands at **y = 3.5 f m** (the 700 px pitch); a `house.json` rect
  y (negative up from the floor line) maps to `y_m = −y_px / 200`; room height 3.2 m; set depth 2.4 m. **Depth bands
  (z, m):** stage lip **+0.25**; apron **0 … −0.4** (nothing stands here); **acting lane −0.4 … −1.6** — characters at
  **z −1.0**, Bellows at **−1.4** at his stations (`house3d.json` `stations.<id>.bellows_z`), Hush at the hotspot's
  `reach_pos` while rigging (z ≥ −1.6, default −1.6; eased 0.2 s, view only), at a hiding spot's `occupant_z` while
  hidden; floor decals here (the stare strip z −1.5 … −0.5); **set band −1.6 … −2.4** with the **reach row −1.65 …
  −1.80** at its front; **back wall −2.4**. Wing flats at room boundaries run from the back wall to z −1.4. Scale
  (R5): live and held props ×1.5 (Bellows' teacup + saucer ×1.8, ≥ 0.16 m wide), furniture ×0.8, architecture real.
- **Screen space (3D):** logical px at the 1920×1080 base; world-anchored 2D items are placed with
  `Camera3D.unproject_position` every frame; hit testing projects 3D boxes to screen rects (§5.14, §6).
- **Ids:** `snake_case` strings in JSON; the sim interns them to ints at load (stable order = sorted ids).
- **Percent maths:** `v * pct / 100` with floor division helpers (`Fx.mul_pct`). No floats in sim state.
- **Animation frames = ticks** (60 fps). A clip frame number is directly comparable to sim ticks. The 3D clips keep
  it: authored and baked at 60 fps, **frame 0 = the clip start**, `length` in frames (the baked `Animation.length` =
  frames / 60 s).
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

**Busy and the queue:** Hush is *busy* while climbing in (the episode's `hush.enter`), rummaging (0.6 s), diving
(0.25 s), squeaking (0.3 s), holding RIG with the ring filling, on the stairs or in a door, in the Lecture, or
bowing. A `go`/`move` arriving while busy is stored as the single `queued` command (a newer one replaces it) and
runs the tick the busy action ends — for a rig: when the step completes **or** when the hold is released. Every
such command emits `cmd_queued {c, why, target}` the tick it is stored (`why`: `entering` during the climb-in,
else `busy`), so a held tap is never silent — the view shows it as queued. A `freeze` or `rig` command is never
queued (holds are immediate); any other command during the climb-in is rejected (`cmd_rejected {why: "entering"}`).
**(v1.1-3D) Struck hotspots:** a `go` (and a hotspot `pin`) to a hotspot outside the episode's live mask (§3.10) is
rejected with `cmd_rejected {c, why: "struck", target}` — feedback, never silence (fairness rule 9 counts it); Hush
does not move.

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
  Gates (`until`, `plus_s`, `max_s`, `first_loop_only`) extend PERFORM. A capped gate is a timeout: an
  interruption (Curious, Spotted, a prank firing) ends the activity as usual. An **uncapped** gate
  (`max_s: null`, GDD §2.3 "this step waits for the player") whose `until` is still false *holds* the loop: the
  interruption does not complete the activity (no `b_activity_end`, the loop index stays), and once the detour,
  reaction or chase is over he starts that activity again (a new `b_activity`), exactly as after an interrupted
  walk. Only the player can open it. Likewise, when the loop doesn't repeat (`rules.loop_repeat: false`, the
  Prologue) and one of the activity's `use` hooks still ahead belongs to a RIGGED prank (ACHOO-RIA! on the tea),
  an interruption restarts the activity instead of ending it — the loop never comes back to it, so ending it would
  lose the armed prank for good (`SimBellows.hook_pending()`). A prank firing ends its activity as usual (it is
  FIRED by then); a looping Night keeps the plain rule (the hook comes round next loop).
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
| Flow | `director_cue {id}`, `safety_net {on}`, `figgis_hook`, `night_end {reason}`, `cmd_rejected {c, why}` ((v1.1-3D) `why: "struck"` adds `target`, §3.5), `cmd_queued {c, why, target}` (a go/move held as the queued command, §3.5; `why`: `entering` \| `busy`) |
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

### 3.10 The live mask and the Bellows-window reason (v1.1-3D; owner `r3d-content`)
- `SimCtx.live_hotspots(db: ContentDB, episode: EpisodeDef) -> Dictionary` (static, pure, deterministic): `{hotspot_id:
  "rig" | "take" | "hide" | "door" | "exit" | "stairs"}` — a rig point is live iff a prank the Night *names* rigs there
  (Script lines, Double Acts, `nights`; a knock-on pull-in does not count — so the Prologue's and Gate 0's sink tap is
  struck and stays furniture, the sneeze's landing); a container iff it holds an item some prank of tonight needs; a
  hiding spot iff it is in the episode's `hides` (absent → every hiding spot of the Night's rooms); doors, exits and
  stairs as before (tappable in a room Hush may enter; `kitchen_window` stays untappable). A command's check order:
  unknown hotspot, not tappable, backstage, locked, struck. `SimCtx` stores it as a bit mask at `create()`;
  `hotspot_state(id).enabled` follows it; commands to a struck hotspot are rejected (§3.5); the solver's executor and
  planner never target one, and the Director's safety-net pulse and every solution `hide` step use a listed spot. The
  view's `SetList` (§5.13) derives the same live set and builds nothing that is struck.
- `SimVisibility` (`sim/world/sim_visibility.gd`, Stage 2): `beat_vis(w, has_emote) -> String` (`"room"` | `"pip"` |
  `"edge"` | `""` — whether a Bellows beat is visible; the dead-air gate's input), `in_room(w)` and `pip_shows(w)` (he
  is one link from Hush's room, his path ends in her room, or she is rigging) are unchanged. **New:**
  `SimVisibility.pip_reason(w: SimWorld) -> StringName` (static, pure, allocation-free): `&""` when `pip_shows` is
  false, else `&"room"`, `&"heading"` (his path ends in her room), `&"rigging"` (she is rigging) or `&"adjacent"` (only
  the nav link) — heading and rigging win over adjacent. The Bellows window's `lean` mode (§5.15) and the solver column
  `d1_lean` (§8.5) read it; the timeline beats (`--timeline`) carry the reason per beat.

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
- **(v1.1-3D) Frozen on `r3d` (C3):** x positions, rects, stations and ids do not change for 3D (a checksum test pins
  `house.json` and `cold_sets.json`); the 3D view reads them as they are and adds depth, models, anchors and view-only
  offsets in `house3d.json` (§4.12). The `art` paths are (2D, main only).

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
- **(v1.1-3D) `hides`** (optional array of hotspot ids): the Night's live hiding spots (GDD §3.4, REDESIGN §6.2 C1) —
  `p00_curtain_up` `["kitchen_pantry_curtain", "parlour_piano_back"]`; `g0_sneeze` `["kitchen_pantry_curtain"]`;
  `n01_throat_tea` and `n02_something_fishy` `["kitchen_pantry_curtain", "parlour_piano_back", "hall_coat_cupboard"]`.
  Absent = every hiding spot of the Night's rooms (the drafts). Validation (`validate()` + the content lint): every
  listed id is a hiding hotspot in the Night's rooms; one per room in Act I episodes with a list (a warning for drafts);
  every solution `hide` step and the Director's safety-net pulse use a listed spot. It drives the live mask (§3.10).

### 4.7 Rigs: `rigs/<id>/rig.json`, `poses.json`, `faces.json` (owners `art-hush`, `art-bellows`, `rig`)
**(2D, main only)** — the cutout rig format. The 3D rigs use `rigs3d/<rig>/rig3d.json` (§4.10); `faces.json` preset
*names* carry over to `rigs3d/<rig>/faces.json`. `rigs/figgis/**` and `rigs/stalls/**` are kept on `r3d` (Figgis is
drawn at its SVG level; the Stalls stay 2D).
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
**(2D, main only)** — the JSON key-pose clip format sampled by the 2D `RigSampler`. The 3D clips are baked
`Animation` resources with a sidecar v2 (§4.11) that keeps this format's beats, events, marks, loop, layer / mask,
blend and variation; clip ids are unchanged. The comedy.md §6 format, binding:
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

### 4.10 The 3D rig descriptor: `rigs3d/<rig>/rig3d.json` (v1.1-3D; writers the cast tasks; reader `RigDef3D`)
```json
{"version": 1, "rig": "hush", "scene": "res://art3d/chars/hush/hush.glb", "skeleton": "Armature/Skeleton3D",
 "mesh": "Armature/Skeleton3D/hush_body", "height_m": 1.60, "head_scale": 1.0, "tris": 9800, "deform_bones": 46,
 "bones": {"root": "root", "pelvis": "pelvis", "spine_top": "spine_03", "neck": "neck_01", "head": "Head",
           "hand_l": "hand_l", "hand_r": "hand_r", "foot_l": "foot_l", "foot_r": "foot_r"},
 "sockets": {"grip_r": {"bone": "hand_r", "pos": [0.0, 0.09, 0.02], "rot_deg": [0, 0, 0]}, "head_top": {"bone": "Head", "pos": [0, 0.42, 0]},
             "brace_r": {"bone": "spine_02", "pos": [-0.09, 0.05, 0.11]}},
 "props": {"clarence": {"bone": "prop_clarence", "states": {"brace": "brace_r", "held": "grip_r"}, "default": "brace"},
           "pepper_pot": {"bone": "prop_r", "default": "hidden"}},
 "attachments": {"bouffant_flipped": {"scene": "res://art3d/chars/bellows/bouffant_flipped.glb", "bone": "bouffant", "default": false}},
 "slots": {"bouffant": {"neat": null, "flipped": "bouffant_flipped", "frazzled": "bouffant_frazzled", "wet": "bouffant_wet"}},
 "anim": {"layers": []},
 "jiggle": [{"bones": ["beret"], "stiffness": 3.0, "drag": 0.4, "gravity": 0.3, "radius": 0.05, "clamp_deg": 30}],
 "face": {"atlas": "res://art3d/chars/hush/face_hush.png", "atlas_px": 1024, "grid": [8, 8],
          "layers": ["brows", "eyes", "pupils", "mouth", "extra_a", "extra_b"],
          "layer_rects": {"eyes": [0.18, 0.40, 0.82, 0.62]},
          "cells": {"eyes": {"open": 8, "wide": 9}, "pupils": {"centre": 24}, "mouth": {"smile": 32}},
          "pupil_range": [0.05, 0.03], "presets": "res://data/rigs3d/hush/faces.json",
          "blink": {"every_s": [2.0, 6.0], "frames": 6, "cell": "closed", "blinkable": ["open", "happy", "wide", "squint"]}},
 "material": {"palette": "res://art3d/chars/hush/palette_hush.png", "outline_px": 4.8, "rim": 0.45},
 "vertex_color": {"r": "skin_tint", "g": "stone_keep", "b": "rim_damp", "a": "outline_scale"},
 "looks": {"TOMATO": {"show": ["tomato_splat"]}},
 "tint": {"tiers": ["#FFFFFF", "#FFE0DC", "#FFC2B8", "#F59A94"], "livid": "#B8324B"},
 "stone": {"color": "#E8E6E1"}, "cheat": {"idle": 35, "walk": 20, "perform": 35, "face_to_face": 5},
 "blob_shadow_r": 0.34, "skins": {}}
```
(The `slots` and `attachments` rows show Bellows' values for the example; Hush has `slots: {}` and `anim.layers: []`.)
`outline_px` follows lead decision D7 (characters 4.8 px, live props 3.4 px at the 1080 base, look A's weight; the index
example said 3.5). **Face cells (D7):** keep look A's horizontal face-cell resolution (A's cells ≈ 340 px wide) — the
atlas grid in the example is illustrative; do not squeeze the cells to 128 px.
- **Skeleton:** the Quaternius UAL 65-bone UE5-mannequin skeleton (CC0; bone names, **directions and rolls kept**,
  lengths re-proportioned), armature object `Armature`, + extra bones (props, FX, jiggle). A cast test checks that the
  upper-arm rest directions equal UAL's within 0.5°; nothing is "built into the rest pose".
- **`anim.layers`**: pose layers the bake pipeline applies to **every** clip of the rig, UAL and custom (Bellows:
  `["arm_out"]` — +40° upper-arm abduction so the arms clear the 0.85 m barrel). A layer is never passed per clip, so
  no clip can get it twice.
- **Body slots** (`slots.<slot>.<variant>` → an attachment id; `null` = the base mesh part): mutually exclusive variants
  of one body part; `look` events and looks address slots, never attachments directly. Ownership: a clip's `look`
  event owns its slot until the clip's release frame (reactions: `marks.release`; other clips: their end); from then on
  the sim's residue owns it (`CharacterView3D` applies `residues.json` looks with owner `&"residue"`); `reset()` (retry,
  seek, teleport) clears every clip-set slot. The sneeze: neat → `flipped` at f 94 (clip) → BLINDED from f 165
  (residue) → neat after a retry.
- **Looks** (`looks.<id>`): `show` / `hide` (attachment ids), `hide_bones` (scaled to 0), `params` (material uniforms),
  `swap` (`{slot: variant}`, e.g. `BLINDED: {swap: {bouffant: "flipped"}}`, `FRAZZLED: {swap: {bouffant: "frazzled"}}`).
- `props.<id>.states` map a state to a socket or `hidden`; `prop` show / hide events resolve `props` first, then
  `attachments` (Bellows' ride-along `stool` is an attachment). `face.mirror_cells` (`{cell: mirrored_cell}`) swap by
  facing (facing is a yaw, never a negative scale).
- **Faces:** preset names in `rigs3d/<rig>/faces.json` are the 2D `rigs/<rig>/faces.json` names (Hush 26, Bellows 45);
  cell names are the 2D slot-variant names.
- **Variants:** `rig3d_<variant>.json` (same bone names, same clips) loads with `RigDef3D.load(rig, variant)`. Hush's
  only variant is **`"head_b"`** (the proposed head scale of the head check, GDD §1.2; `head_scale` is a build
  parameter that never invalidates clips; B's neck is kept). A `"pip"` skin request falls back to `""` (logged once).
- **Budgets** (checked by the cast tests): `tris` ≤ 10,000, `deform_bones` ≤ 50 (+ jiggle), 1 skinned mesh + ≤ 4
  attachments, 1 material + the outline pass.

### 4.11 The 3D clip: `art3d/anim/<rig>/<clip>.res` + sidecar v2 `data/anim/<rig>3d/<clip>.json` (v1.1-3D, ruling R2)
Poses are authored in Blender 4.5 (the bpy pose language: FK, 2-bone arm IK, foot grounding, steps, reach helpers,
60 fps, frame 0 = the clip start) and **baked one clip per file** to a Godot `Animation` resource (binary `.res`,
uncompressed; track paths `Armature/Skeleton3D:<bone>`; `length = frames / 60`; `loop_mode` from the sidecar). The
**sidecar** keeps TECH §4.8's beats, events, marks, loop, layer / mask, blend and variation, plus a face timeline.
JSON poses sampled by a ported `RigSampler` are **not** built.
```json
{"version": 2, "format": "anim3d", "clip": "bellows/rx_sneeze_blast_a", "rig": "bellows",
 "anim": "res://art3d/anim/bellows/rx_sneeze_blast_a.res", "length": 165, "fps": 60, "loop": false,
 "layer": "base", "mask": null, "blend_in": 0, "blend_out": 10, "lock": "sim",
 "beats": {"anticipation": [74, 94], "accent": [94, 97], "hold": [97, 145], "settle": [145, 165]},
 "events": [{"f": 94, "type": "voice", "id": "vo_bellows_sneeze_choo"}, {"f": 94, "type": "hitstop", "frames": 5},
            {"f": 94, "type": "cam", "op": "punch", "zoom": 1.4, "in": 11, "hold": 90, "out": 21, "yaw": 5},
            {"f": 94, "type": "mark", "name": "accent"}, {"f": 94, "type": "look", "set": {"bouffant": "flipped"}},
            {"f": 95, "type": "decor", "id": "kitchen_stool", "visible": false}, {"f": 95, "type": "prop", "op": "show", "prop": "stool"},
            {"f": 94, "type": "fx", "id": "choo_puff"}],
 "face": [{"f": 0, "preset": "sip"}, {"f": 20, "preset": "sneeze_build"}, {"f": 94, "preset": "sneeze_choo"}],
 "cheat_deg": 30, "root": {"travel": "sim"}, "stride_m": null, "speed_m_s": null,
 "variation": {"time_jitter": 0, "rot_jitter_deg": 0},
 "source": {"kind": "custom", "script": "tools/art3d/anim/bellows/rx_sneeze_blast_a.py"},
 "lint": {"skippable": false, "pop_frames": [94], "freeze_holds": [], "draft": false}}
```
- **Clip ids and paths:** ids are unchanged (`hush/loco_walk`, `bellows/rx_sneeze_blast_a`), so `reactions.json`,
  `clip_rules.json`, the map keys, `SliceClips`, `SimOneshots` and `data/audio/clip_events.json` carry over.
  `hush/loco_walk` → sidecar `res://data/anim/hush3d/loco_walk.json`, animation `res://art3d/anim/hush/loco_walk.res`.
- **Timing (ruling R3):** a clip the sim or a cue times (a `SliceClips` row with an expected length: reactions, bits,
  one-shots, beats, cue clips, micro-gags) keeps its 2D length, every beat / mark of `reactions.json` within 2 f and
  every sound frame of `data/audio/clip_events.json`; loops and locomotion (expected length −1) may retime to the
  REDESIGN §4.2 gaits, their contact sounds re-placed on the 3D contact frames as sidecar events.
- `lock`: `"sim"` (frame = sim tick − start + alpha: reactions, bits, one-shots), `"rig_pm"` (frame = rig progress ‰ /
  1000 × length: every rigging clip, **normalised** — one clip serves the Q / S / B tiers, the tier only changes how
  fast progress runs; release keeps the pose; prank clips are authored at their tier's length — Q 48, S 90, B 150 —,
  band clips at any length ≥ 48), `null` (the view clock). `layer` `base | overlay` (+ `mask` `upper | head | arms |
  face`) `| additive`. `root.travel` `"sim"` = the clip never moves the root in x/z (the view moves the character along
  the `reactions.json` travel arcs); the pelvis may move in y and a little in x/z (≤ 0.15 m) — e.g. a step's rise.
- **Events:** TECH §4.8's types (`sfx, voice, laugh, fx, face, cam, shake, hitstop, slowmo, freeze, prop, mark`; `smear`
  is dropped in 3D) + `decor {id, visible?, anim?}` (a furniture / decor piece: hide / show or play one of its anims,
  e.g. the stool's `wobble`), `set_anim {hotspot, anim}`, `set_part {hotspot, part, visible}`, `look {set: {<slot>:
  <variant>}}` (a body slot, §4.10), `prop {op: attach | detach | launch | show | hide, prop, socket?, vel?, spin?}`
  (`prop` = a rig `props` id, else an `attachments` id), `prop {op: lend | return, prop: "set:<id>", socket?, frames?}`
  (a **set piece** — a hotspot prop or a furniture id — slides into / out of a socket over `frames`, default 6; the view
  calls `House3D.lend` / `return_home`; the piece keeps its state, armed look, tag and particles while lent; on a clip
  switch every lent piece returns unless the new clip lists it in `keeps`), `jiggle {bones, kick}`; `cam` ops
  `push {zoom, frames}` (a slow dolly, e.g. 1.15 through the sneeze build) and `punch {zoom, in, hold, out, yaw}` (C7).
  Sound ids come from `game/audio/sfx_map.json`; timed sound frames are copied from `data/audio/clip_events.json`.
  Face timeline entries: `{f, preset}` and/or `{f, slots: {layer: cell}}`, held until the next entry; blinks are
  automatic unless `"blink": false`.
- Walk and run loops carry `stride_m` (one full cycle) and `speed_m_s` and are **in place**; the player scales playback
  to the character's speed; the lint measures foot drift in lane space.
- `lint.draft: true` marks a draft clip (a clip made after its key's time box ran out): it passes every lint rule and
  is exempt only from rubric scoring; the owner pack lists it as "draft (R3 polish)".
- **Map keys** (`data/anim/<rig>3d/map.json` over `view/world/default_maps/<rig>.json`): the Stage-2 schema + `rig:<prank>
  {clip, lock: "rig_pm"}` before `rigging@<tier>`, `flavour:arrive`, `flavour:skid`, `flavour:step_down`, `state:freeze`
  variations. **`ClipMap` and `SliceClips.build3d` derive a `rig:<prank>` row for every prank of `rig_actions.json`**
  (the prank's own `clip`, else `bands.<band>.clip`; a `map.json` row may override); `rigging@*` with no `rig:` row
  resolves to `bands.mid.clip`, counted as a clip fallback. `act_tinker_q` is not in the 3D manifest.

### 4.12 `house/house3d.json` (v1.1-3D; owner `r3d-sets`; readers `House3D`, `SetList`, view3d, hud, tools, content's validation)
```json
{"version": 1,
 "units": {"px_per_m": 200, "floor_pitch_m": 3.5, "room_h_m": 3.2, "lane_z": -1.0, "back_wall_z": -2.4},
 "stage": {"lip_z": 0.25, "lip_color": "#C9A24A", "proscenium": {"color": "#1D1728", "h_m": 0.8, "edge_y_m": 3.13},
           "wing_flat": {"front_z": -1.4, "thick_m": 0.22, "color": "#E9DCC4"}, "footlight": {"strength": 0.12, "fade_m": 1.2}},
 "rooms": {"kitchen": {"wall": "#C7B684", "wainscot": "#AE9C70", "wainscot_h_m": 0.9, "rail_h_m": 2.2, "floor": ["#8E6E52", "#86664B"],
                       "arch": "res://art3d/set/kitchen_arch.glb", "palette": "res://art3d/set/palette_kitchen.png"}},
 "hotspots": {"kitchen_honey": {"model": "res://art3d/props/honey_jar.glb", "z": -1.75, "yaw": 15, "scale": 1.5,
               "visual_offset": [0.15, 0.01], "hit_box": null,
               "reach": "high", "reach_target": [0.0, 0.12, 0.10],
               "reach_pos": {"dx": 0.30, "z": -1.40, "step": "stool:kitchen_stool", "step_h": 0.55},
               "silhouette": "squat_jar", "view_kind": "rig",
               "states": ["idle", "armed", "spent"], "anims": {"rig": "rig", "armed": "pepper_puff", "trigger": "lid_flip"},
               "parts": ["pepper_pot"], "tag_socket": [0.08, 0.10, 0.06], "preview_anchor": [0.0, 0.54, 0.0],
               "ring_anchor": [0.0, 0.07, 0.0], "item_anchor": null, "eyes_anchor": null, "halo": "fresnel", "stack": "kitchen_kettle"}},
 "stations": {"st_tea": {"furniture": "kitchen_stool", "bellows_z": -1.4, "yaw": -35,
              "handoffs": [{"prop": "set:kitchen_kettle", "socket": "grip_r"}, {"prop": "set:kitchen_honey", "socket": "grip_l"}]}},
 "furniture": {"kitchen_stool": {"room": "kitchen", "model": "res://art3d/set/stool.glb", "x_m": 15.0, "z": -1.4, "yaw": 0,
               "decor_id": "kitchen_stool", "seat_y_m": 0.55, "anims": ["wobble"]}},
 "landings": {"kitchen.sink": {"z": -1.95, "y": 0.58, "yaw": 20}},
 "dressing": {"kitchen_window": {"room": "kitchen", "model": "res://art3d/set/kitchen_window.glb", "x_m": 17.9, "y_m": 1.4, "z": -2.38, "nights": "all"}},
 "decor": {"parlour_vase": {"model": "res://art3d/set/vase.glb", "cue": "laugh_vase", "z": -2.1}},
 "hide": {"kitchen_pantry_curtain": {"occupant_z": -2.1, "eyes_anchor": [0.0, 1.25, 0.06], "anims": ["close", "wobble", "breathe", "burst"]}}}
```
(Colours, depths and offsets are an example that meets REDESIGN §3.7 and ruling R5; `r3d-sets` places the real ones and
its tests prove them.)
- **Positions.** x and y come from `house.json` and stay frozen (C3): a hotspot's rect centre-x / bottom-y, `use_x`,
  station `x` / `stand_x` (the stool's seat pivot = `st_tea.stand_x` 3,000 px = **15.0 m**, where Bellows sits), decor
  `pos`, the `landings` x. `house3d.json` adds depth, models, anchors and **view-only** offsets: `visual_offset` [dx, dy] m
  moves the visual (and its default hit box) within the room; `hit_box` [x0, y0, x1, y1] m (optional) replaces the
  rect-derived box — it must contain the visual, project ≥ 144 px at the base framing and keep ≥ 24 px from its
  neighbours. The default hit box is the rect's x/y (+ `visual_offset`) × the prop's z ± 0.3 m.
- **The prop frame** (every anchor): origin = (rect centre-x + `visual_offset.x`, rect bottom-y + `visual_offset.y`, the
  prop's `z`); axes y up, +z toward the camera; anchors in **metres before `scale`**. Example: the jar's origin is
  (14.70 + 0.15, 1.79 + 0.01, −1.75) = (14.85, 1.80, −1.75); `reach_target` [0, 0.12, 0.10] × 1.5 → world (14.85,
  **1.98**, −1.60) — high band, above 1.70 m, so a step; `preview_anchor` 0.54 → world 2.61 m (0.6 m above the jar's
  2.01 m top).
- **`reach_pos`** (rig points): where Hush stands while rigging — `dx` m from `use_x`, `z` (≥ −1.6; default −1.6),
  `step` (`null` | `"stool:<furniture id>"` | `"mime"`), `step_h` (the stool's `seat_y_m`, or 0.30–0.45 for `mime`).
  **Reachable** iff the distance from her nearer shoulder (at `reach_pos`; y 1.127 + 0.07 tiptoe for the high band +
  `step_h`; x ±0.118) to the placed `reach_target` is **≤ 0.50 m** (a `r3d-sets` test: error on P00 / g0, warning on
  N01 / N02). The example: Hush at x 15.00 on Bellows' stool (feet 0.55 m) → nearer shoulder ≈ (15.0, 1.68, −1.52) →
  0.33 m to the target. `reach` (`low | mid | high`) is derived from the target's world y — **low 0.00–0.55, mid
  0.55–1.40, high 1.40–2.15, a step above 1.70** — and must equal `rig_actions.json`.
- **`landings.<room>.<id>`** (every landing a slice reaction uses — at least `kitchen.sink`, `parlour.log_basket`,
  `parlour.chandelier`, `hall.coat_stand`): the landing's z, the pelvis y at rest and a yaw; x from `house.json`
  `landings`. `CharacterView3D` interpolates x, y and z along the `reactions.json` travel frames; `House3D.landing_box(id)`
  is the volume the landing must end inside (the sneeze: his pelvis inside the sink basin on f 112).
- **`stations.<id>.handoffs`**: the set pieces an activity borrows (`prop {op: lend | return, prop: "set:<id>"}`,
  §4.11); `SetList` keeps them built on tonight's set even when the hotspot is not live (a non-interactive piece: no
  glow, no hit box). **Bellows never reaches up**: set pieces come to his sockets.
- `view_kind` ∈ `rig | hide | take | exit | door | stairs`; `halo` ∈ `stencil | fresnel`; `silhouette` = the 64 px
  family (no two live props of a room share one). `nights` (dressing) is `"all"` or a list; omitted = derived by
  `SetList`. Every slice hotspot of P00 / g0 / N01 / N02 has an entry; later-Night hotspots may be absent (struck).
  Furniture `anims` play through `decor {id, anim}` events and `House3D.play_decor`.

### 4.13 The view data: `view/previews.json` and `anim/hush3d/rig_actions.json` (v1.1-3D; owner `r3d-content`)
- `previews.json` `{version, pranks: {<prank>: {pictogram: [ids], needs: item | null, combines: [{with, badge}]}}}` —
  the BEFORE pictures (REDESIGN §4.3): e.g. `achoo_ria` `["nose", "star_burst"]` combining with `tap_dance` → badge
  `to_sink`; `kettle_drum` needs `squeaker`. The pictogram ids are the contract `r3d-hud` draws (`game/art/ui/previews/`).
  Readers: hud, view3d, tools.
- `rig_actions.json` `{version, tiers: {q: 48, s: 90, b: 150}, bands: {low: {glove_y_m: [0.00, 0.55], clip:
  "hush/rig_low"}, mid: {glove_y_m: [0.55, 1.40], clip: "hush/rig_mid"}, high: {glove_y_m: [1.40, 2.15],
  step_above_m: 1.70, clip: "hush/rig_high"}}, pranks: {<prank>: {hotspot, tier, band, clip, prop_anim, held, step,
  glances: [‰], noise_rings}}}` — tiers in frames (= the prep tiers 0.8 / 1.5 / 2.5 s) and equal to `pranks.json`;
  `hotspot` = the prank's `rig_point`; **`band` and `step` derived from `house3d.json`'s placed `reach_target` /
  `reach_pos`** (one source of truth, checked on both sides); `clip` = the prank's own rig clip or null (→ the band
  clip; the Prologue's `achoo_ria` → `hush/rig_achoo_ria` with `step: "stool:kitchen_stool"`, `allegro_go_go` →
  `hush/rig_allegro_go_go`); `glances` = ‰ of rig progress at which the **view** overlays `hush/act_glance` (mask
  `head`) — never baked into band clips; `noise_rings` true for B rigs. Readers: anim, sets, view3d.


---

## 5. The VIEW

**(v1.1-3D)** §5.1–§5.10 are the Stage-1/2 view contracts. Where a heading says **(2D, main only)** the 3D view replaces
it with §5.11–§5.19, **keeping the public names and entry points `NightScene` uses**; §5.2 (`SimDriver`) and the
`ViewSnapshot` seam are unchanged and frozen (`view/world/view_snapshot.gd`, `view/sim_driver.gd`).

### 5.1 Scene tree of a Night (`scenes/night/NightScene.tscn`, Stage 2) (2D, main only — 3D: §5.11)
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

### 5.3 The rig system (owner `rig`) (2D, main only — 3D: §5.12)
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

### 5.4 World view (owner `view`) (2D, main only — 3D: §5.13)
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

### 5.5 Camera (owner `view`) (2D, main only — 3D: §5.14, same public API)
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

### 5.6 Bellows-Cam PiP (owner `view`) (2D, main only — 3D: the Bellows window, §5.15)
`PipView`: a SubViewport sharing `world_2d`, its own Camera2D following Bellows (zoom 0.75), 448 × 252, rendered
at 30 Hz only while visible (`UPDATE_ONCE` every other frame), `canvas_cull_mask` excludes the FX/marker layer
(visibility layer 2). `set_visible_if(cond: bool)` with a 2 s hide delay; `escalate(on: bool)` → 704 × 396 Gag-Cam
window; `get_texture()` feeds the HUD's `PipFrame` widget (owner `ui`), which draws the frame (colour by temper tier),
the awareness glyph and handles the tap → `CameraDirector.peek`.

### 5.7 FX (owner `view`) (2D, main only — 3D: §5.16)
`FxLayer` (world space, pooled, no allocations after warm-up):
`caption(text, world_pos, size := 88)`, `stamp(text, world_pos)`, `burst(kind, world_pos, amount)`
(CPUParticles2D pool: dust, flour, feathers, drops, steam, sparkles, notes, roses — ≤ 8 emitters / 300 particles,
`fixed_fps = 30`), `ripple(world_pos)`, `path_dots(points)`, `noise_ring(world_pos, radius, color)`,
`footprints(points)`, `stare_strip(bellows_snapshot)`, `thought_bubble(actor_snapshot)`, `badge(hotspot, kind)`,
`busted_cam(buffer, spotted_tick)`. The Busted Cam re-stages the last 90 ticks from a view-side ring buffer of
both characters' `(room, x, facing, clip, frame)` with a red vignette, split-frame border, "SPOTTED!" and a dotted
line from his eyes to Hush (the sim holds Bellows still during `CAUGHT_HOLD`, so rewinding the views is safe).

### 5.8 Audio (`audio` owns the autoload and cues; `view` owns the director) (3D delta: §5.18)
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

### 5.9 HUD and UI (owner `ui`) (3D delta: §5.18 — the four-piece HUD)
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

### 5.10 The Stalls and Figgis (owner `view` for the Stalls; `ui` for the Figgis chip) (3D delta: §5.19)
`StallsView`: one Node2D drawing 24 head sprites from one atlas in `_draw()` (one batched draw call) along the
bottom-centre band (GDD §3.8), resting 40 px, rising per tier with springs, T4: one head tumbles; no input
handling at all. The Figgis chip is a HUD widget with pulse/card/ghost states.

### 5.11 Scene tree of a Night in 3D (v1.1-3D; owner `r3d-night`)
```
NightScene (Node)                      night_scene.gd — wires everything; owns no gameplay rules; view switch --view=2d|3d
├─ SimDriver (Node)                    view/sim_driver.gd — unchanged (§5.2)
├─ World (Node3D)                      view3d/world/world_view_3d.gd — WorldView3D: House3D set, CharacterView3D × 2,
│                                      Decals3D, Fx3D, StageLighting3D; the overlay-anchor source (§5.16)
├─ CameraDirector3D (Camera3D)         view3d/camera/camera_director_3d.gd — the current camera (§5.14)
├─ InputRouter (Node)                  ui/input/input_router.gd — logical screen positions (no Camera2D)
├─ AudioDirector (Node)                view/audio_director.gd — pans by projected screen x
├─ PipView3D (SubViewport + Camera3D)  view3d/pip/pip_view_3d.gd — the Bellows window (§5.15)
├─ GagStager (Node)                    view/camera/gag_stager.gd — 3D focus points, dolly punch-ins
├─ WorldOverlays (CanvasLayer 8)       ui/world/ — previews, thought, needs clouds, item bubbles, rig ring, marker, tags
├─ Stalls (CanvasLayer 9)              view/stalls/stalls_view.gd — hidden at rest
├─ Hud (CanvasLayer 10)                ui/hud.gd — the four always-on pieces + contextual pieces (§5.18)
├─ HapticsDirector (Node)
└─ Curtain (CanvasLayer 20)            the 2D Boot / curtain-call curtain
```
- **The view switch** (ruling R1): `NightArgs --view=2d|3d` and `boot_config.json` `"view"`; 3D becomes the default as
  soon as the Gate-0 route plays in it; `--view=2d` works until `r3d-integrate` removes the 2D path.
- Every Stage-2 flow is unchanged in 3D: tick 0 = the curtain-rise frame (`SimDriver` paused at tick 0 during
  build / warm; input live at half up); the view pre-rolls without advancing the sim; pause / Android back / focus-out
  pauses; retry ≤ 1.5 s (`SimDriver.reset()` + `WorldView3D.reset()`, pooled); seek; `--cmds` replay; the cold-open
  hook; the Gate-0 card (its three icons redrawn for 3D: tap the honey → hold RIG → hide in the pantry).
- **Warm-up (no shader compiled during play):** `NightWarm.list(episode)` in 3D = every character look / tint tier /
  stone / prop state (`RigPlayer3D.warm()`), every `Prop3D` state + glow + halo + tag + hidden-eye card, every decal kind,
  every particle material, the FX meshes (CHOO puff, stars, notes, plinth), one Bellows-window render, the world
  overlays' textures, the Stalls atlas; `NightWarmer` draws every material registered in `MaterialWarm3D` once in front
  of the camera under the curtain (within `WARM_CAP_S` 3.0 s; the curtain rises anyway after it). Detection: the
  engine's pipeline-compilation counters when the Compatibility renderer reports them, else every material first
  registered or first made visible after the rise (`MaterialWarm3D.first_use_after_warm`) and every frame > 50 ms in
  PLAY; both go to the device log (`shader_first_use`, `hitch`) and the e2e report (`perf3d.shader_compiles_play`).
- **Curtain call over 3D:** the 2D curtain falls (unchanged art and timing); the bows are 3D (a transparent
  SubViewport sharing the World3D with its own camera at the lip renders Hush's bow and Bellows' wander-on and slow
  burn / bonk in front of the curtain). **Gag Reel:** the recorded moment re-staged in 3D in a SubViewport through
  `WorldView3D`'s replay API, framed like the live punch-in, never an empty box. **Stage door:** "Gate 0: the Sneeze",
  "Prologue", a 3D **Cast** page, the voice / crowd A/B pages, and — only when the `head_b` variant exists — "Gate 0 ·
  Hush, B's head" / "Gate 0 · Hush, head ×<scale>" (setting `hush_head` to `""` / `"head_b"`); "Night 1 (preview)" /
  "Night 2 (preview)" only when `show_previews` is true, behind a work-in-progress card.
- **`boot_config.json`** (file `r3d-night`, values the orchestrator's): `{"start": "stage_door", "view": "3d",
  "show_previews": false, "bellows_window": "sim", "render": {"msaa_3d": true, "render_scale": 1.0, "outline": true}}` —
  the owner APK's values; the Bellows-window default (§5.15) and the perf probe's device numbers may flip
  `bellows_window` / `render`; Boot and NightScene read every key (defaults when absent).

### 5.12 The 3D character player — `RigPlayer3D` and the pure layer (v1.1-3D; owner `r3d-rig`, `game/view3d/char/`)
```gdscript
class_name RigPlayer3D extends Node3D
signal clip_event(ev: Dictionary)        ## every sidecar event crossed this frame (sfx voice laugh fx face cam shake hitstop slowmo
                                         ## freeze prop mark decor set_anim set_part look jiggle), with "clip" and "f" added;
                                         ## `prop` events on "set:<id>" pieces are emitted only (the view lends them, §4.11)
signal clip_finished(clip_id: String)
func setup(rig_id: String, variant := "") -> bool       ## loads data/rigs3d/<rig>/rig3d[_<variant>].json + its scene; false (+ push_error) on
                                                        ## failure; variant "" | "head_b"; a "pip" skin request falls back to ""
func play(clip_id: String, opts := {}) -> void          ## opts: blend_in (frames), speed, loop, start_frame, tier (1–3), suppressed, seed
func play_overlay(clip_id: String, mask := "upper", blend_f := 6) -> void ; func stop_overlay(blend_f := 6) -> void
func set_external_frame(frame: float) -> void          ## frame-lock (reactions, one-shots, rig progress); no own clock while set
func release_external() -> void
func set_facing(dir: int, animate := true) -> void     ## ±1 → body yaw ±90° (sim facing), 6-frame turn when animated
func set_cheat(deg: float, ease_s := 0.2) -> void      ## extra yaw toward the camera (idle 35, walk 20, face-to-face 0–10)
func set_face(preset: String) -> void ; func set_slot(slot: String, cell: String) -> void
func look_at_point(world: Vector3, weight: float) -> void   ## head + pupils, additive, clamped
func set_look(look: String, on: bool) -> void          ## residues / costumes from rig3d.json "looks" (owner "residue": the sim's state)
func set_body_slot(slot: String, variant: String, owner := &"clip") -> void  ## rig3d.json "slots" (e.g. bouffant: neat|flipped|frazzled);
                                                        ## owner &"clip" (a clip's look event) or &"residue" (the view, from residues.json)
func reset() -> void                                    ## retry / seek / teleport: clears clip-set slots, re-attaches launched props,
                                                        ## resets jiggle; residue looks are re-applied by the view
func set_tint_tier(tier: int) -> void ; func set_stone(on: bool, ease_s := 0.1) -> void
func set_prop(prop: String, state: String) -> void     ## show/hide/state of a bone-driven prop ("teacup": "held" | "hidden") or of an
                                                        ## attachment ("stool": "shown" | "hidden") — props first, then attachments
func attach(node: Node3D, socket: String) -> void ; func detach(node: Node3D) -> void
func socket_global(socket: String) -> Transform3D
func head_global() -> Vector3 ; func top_global() -> Vector3 ; func feet_global() -> Vector3
func screen_aabb() -> AABB                             ## skinned bounds for projection (protected rects, hit tests)
func current_clip() -> String ; func current_frame() -> float ; func has_clip(id: String) -> bool ; func clip_length(id: String) -> int
func set_outline_scale(k: float) -> void               ## Settings "Outline +50 %" → 1.5
func warm() -> void                                    ## every material state drawn once (NightWarm)
func counts() -> Dictionary                            ## {missing_clips: {id: n}, face_misses: n}
```
- **Pure layer (headless):** `RigDef3D.load(rig_id, variant := "") -> RigDef3D` (validates the descriptor against its
  scene: bones, sockets, props, jiggle, attachments, slots, looks, face cells, presets); `ClipLib3D.get_clip(id) ->
  ClipDef3D` (length, fps, loop, layer, mask, lock, beats, events sorted by frame, marks, face timeline, cheat, stride_m,
  speed_m_s), `ClipLib3D.exists(id)`, `path_of(id)`, `animation(id)` (lazy), `clips_of(rig)`; `RigSampler3D.sample(rig,
  clip, frame) -> Dictionary` (bone local rotations / positions from the `Animation` tracks + global positions via a
  headless `Skeleton3D`; helpers `global_pos`, `angle_delta_deg`, `height`, `aabb`; ≤ 5 ms per 100 frames headless) —
  the animation lint and the tests use it.
- **Node layer:** one `AnimationPlayer` in manual callback mode (advanced with view time, or `seek` when frame-locked),
  filled lazily per clip; base + one masked overlay layer (masks `upper` spine_02 up incl. arms, `head` neck up, `arms`,
  `face` = the face timeline only); tier and suppressed remapping (`PlayPlan3D`, the sim's `reactions.json` lengths);
  face cards through the `char_toon` uniforms, blinks every 2–6 s (seeded, 6 f, `blinkable` eyes only, suppressed in a
  take's hold); look-at (±35° yaw, ±20° pitch, eased 0.2 s); jiggle (`SpringBoneSimulator3D` per descriptor group,
  kicked by `jiggle` events, reset on teleport / seek / retry); looks and body slots (§4.10; an unknown slot or variant
  is a `push_error`, never silent); props (`prop {op: launch}` → deterministic ballistic `PropSim3D`: gravity 9.8 × 1.6,
  floor bounce 0.3); walk speed (`set_speed(m_s)` = m_s / clip `speed_m_s`); the outline as a `next_pass` on visual
  layer 2 `CHAR`; every material registered with `MaterialWarm3D` (kind `&"char"`).
- **Fallback:** when `setup()` fails, `CharStandIn3D` — a capsule in the character's two main colours at the right
  height — so the Night still plays; counted by the view as a "puppet".
- **Budget:** ≤ 0.25 ms CPU per character per frame (skinning + jiggle + face), ≤ 4 draw calls, ≤ 10k triangles,
  ≤ 50 deform bones (`RigPerf3D`, §9).

### 5.13 World in 3D — `WorldView3D`, `House3D`, `SetList`, `CharacterView3D` (v1.1-3D; owners `r3d-view3d`, `r3d-sets`)
- **`WorldView3D.setup(db, episode, snapshot_source)`** (the same signature and entry points as `WorldView`: `reset`,
  `character`, `prop`, `fallback_counts`, `reveal_badges` → previews on, `sparkle(hotspot, s)` → the spotlight pool,
  `hotspot_rects_in_view`, `warm_clips`, `preroll`, `tap_feedback`, `target_point`, `entry_warning_active`,
  `start_busted_replay`, signals `built`, `cue_staged`, `replay_changed`) builds `SetList.for_episode` → `House3D.build`,
  two `CharacterView3D`, `Decals3D`, `Fx3D` and the lighting; `advance(delta)` interpolates snapshots with
  `SimDriver.alpha()` (allocation-free); `on_ticked(events)` routes reactions, one-shots, micro-gags, rig progress,
  residues, prank states and director cues. Plus the overlay-anchor source (§5.16), `bellows_on_screen()` (≥ 35 % of
  his projected bounds inside the viewport), `visibility_sample()` (§5.15), `warm_materials(cam)`, the `edge_badge_wanted`
  and `tag_flight` signals and a replay API (`show_explicit` / `pose_replay`) for the Gag Reel and the Busted Cam.
- **`hotspot_rects_in_view() -> Array`**: every live hotspot's `House3D.hotspot_box` projected (8 corners → the screen
  bounding rect) as `{id, kind, rect (logical screen px), room, priority, enabled, stack}` + one floor band per built
  room (its lane floor projected); `TapAssist` resolves them in screen space at zoom 1.0 (§6).
- **`SetList.for_episode(db, episode) -> SetList.Result`** (`r3d-sets`): `rooms_lit`, `rooms_backstage`, `live` (= the sim's
  mask, §3.10), `furniture`, `dressing`, `decor`, `quake`, `landings`, `handoffs`, `struck` — the strike rule (GDD §7.1):
  stations of tonight's loop incl. fix-ups and detours **and the set pieces their `handoffs` borrow**, rig points of
  tonight's pranks, containers of tonight's items, listed hides, reaction landings and knock-on targets, Director cue
  props, quake props of rooms where a Meltdown can happen, entry / doorstep, and the steps named by live rig points'
  `reach_pos`. Sets per Night: P00 / g0 — parlour and kitchen lit, the hall built dark (backstage 0.3), porch, upstairs,
  conservatory, garden not built; N01 / N02 — porch, hall, parlour, kitchen lit; upstairs, conservatory, garden not built.
- **`House3D`** (`r3d-sets`): `build(result: SetList.Result, house3d: Dictionary)` (rooms lit / backstage / not built;
  architecture per built room + the proscenium, lip, apron, wing flats; tonight's furniture / dressing / decor only;
  live props as `Prop3D` / `HideSpot3D`; build ≤ 150 ms), `prop(id) -> Prop3D`, `set_room_light(room, level, desat)`
  (tweened 0.4 s), `hotspot_box(id) -> AABB` (the `hit_box` if given, else the rect's x/y + `visual_offset`, z = prop
  z ± 0.3 m), `floor_band(room) -> AABB`, `decor(id) -> Node3D`, `play_decor(id, anim)`, `set_decor_visible(id, on)`,
  `lend(id: String, to: Node3D, frames := 6) -> Node3D` + `return_home(id, frames := 6)` + `return_all()` (hotspot props
  and furniture; world transforms kept at both ends, the piece keeps its state), `landing_box(id) -> AABB`,
  `furniture_boxes() -> Array[AABB]`, `reach_pos(hotspot) -> Dictionary`, `rooms_built()`. Per room, architecture,
  furniture and dressing merge into ≤ 3 static meshes on one palette material; live props and animated furniture stay
  separate nodes. **`Prop3D`**: `lend(to)`, `return_home()`, `set_state(idle | armed | spent)`, `set_rig_progress(frac)`
  (scrubs the prop's `rig` animation), `set_glow(color, amp)`, `show_tag(on, animate)` (the red beret tag `tag_beret.glb`
  at `tag_socket`, a 0.3 s swing-in), `tag_wiggle()`, `play(anim)`, `set_part(name, visible)`, `set_occupied(on)`,
  `eyes_look(dir: Vector2)`, `eyes_blink()`, `anchor(kind) -> Vector3`; **`HideSpot3D`** adds the `close`, `wobble`,
  `breathe`, `burst` anims and the eye card in the dark gap.
- **`CharacterView3D`** (on `RigPlayer3D`): x_m = sim x / 200, floor y = 3.5 f m, **lane z −1.0**; Bellows at the station's
  `bellows_z` (−1.4); while Hush rigs she eases (0.2 s) to `House3D.reach_pos(id)` — for ACHOO-RIA! **onto Bellows' stool**
  (x 15.0, z −1.4; the clip carries the 0.55 m step, the stool `wobble`s through `decor` events); a stepped rig released
  mid-way plays `hush/rig_step_down` (`flavour:step_down`) before any locomotion; the dive follows an arc to the spot's
  `occupant_z`. **Reaction travel** from `reactions.json travel` (x toward the `house.json` landing, `arc_px` as a y arc)
  **and z + pelvis y from `house3d.json landings`** over the same frames — the sneeze's pelvis ends inside
  `landing_box("kitchen.sink")` on f 112. **Hand-offs:** `prop {op: lend | return, prop: "set:<id>"}` events → `House3D.lend`
  / `return_home` to `RigPlayer3D.socket_node(socket)`; `return_all()` on a clip switch except the new clip's `keeps`.
  **Cheat-out:** 35° idle / performing, 20° walking, 0–10° face-to-face, **≤ 10° while reaching** (the head turns to the
  camera), the clip's `cheat_deg` in reactions. **Body slots:** clip-owned until release, then residue-owned; `reset()`
  then re-apply residues on retry / seek. **Stage light:** Hush's `char_toon` `stage_light` = her room's level; Bellows'
  = max(his room's level, 0.9). **Freeze = marble:** `set_stone(true)` in 0.1 s except eyes / beret / braces, the plinth
  pops up (0.1 s), colour returns with a shiver (0.15 s). **Blob shadows:** r 0.34 m (Hush) / 0.45 m (Bellows), 32 %
  alpha, following the pelvis x/z (on the stool seat while she stands on it). **Variants:** Hush loads
  `setup("hush", Settings.hush_head)`; `hush_skin == "pip"` falls back to Hush (logged once, not counted).
- **ClipMap 3D** (`view/world/clip_map.gd`, adapted): `data/anim/<rig>3d/map.json` over `default_maps/<rig>.json`, the
  Stage-2 resolution order + the derived `rig:<prank>` rows (frame-locked to `rig_pm`) before `rigging@<tier>`,
  `flavour:arrive|skid|step_down`, glances (`rig_actions.json` ‰ → `hush/act_glance` as a `head` overlay, once per mark),
  reactions frame-locked with tiers and last beats, one-shots from `clip_rules.json`, micro-gags as `upper` overlays,
  flavours (snicker after an arm, 40 f, interruptible; glance; shrug; arrive; skid; step-down), knock-on `_ko` variants.
  `fallback_counts()` = `{clip_fallbacks, puppets, greybox_props, by_clip}` — 0 required on the Prologue and Gate-0
  routes. **Fallbacks that still read** (N01 / N02): a missing reaction plays `bellows/st_double_take` held to the sim's
  length + the reaction's caption (never a rest pose); a missing activity plays `loco_idle` with the activity's
  signature held prop; a missing micro-gag is skipped; each counted per clip id.
- **`SliceClips.build3d(episodes: PackedStringArray) -> Array[Dictionary]`** (+ `to_markdown`): the 3D clip manifest —
  `state:rigging` / `rigging@*` swapped for a `rig:<prank>` row per prank of `rig_actions.json`, the
  `flavour:arrive|skid|step_down` rows, `freeze_5..8` once `hush3d/map.json` lists them, `act_tinker_q` dropped;
  `build3d(["g0_sneeze", "p00_curtain_up"])` = **70 rows** (Bellows 42 + Hush 28); the band clips `rig_high/mid/low` are
  listed with `episodes: [n01, n02]`. `SliceClips.build()` (2D) stays intact.
- **Readability drivers** (`WorldView3D`): N1 glow (every live prop in Hush's room in its verb colour — rig `#FFC838`,
  hide `#5C9EFF`, take `#FFF4DB`, exit cream after ★; the active spot at glow amplitude 2), AFTER (`set_state(armed)` +
  `show_tag`), TRIGGER (`tag_wiggle()` + the C3 two-shot as he approaches; after the payoff `set_state(spent)`, the tag
  hides and `tag_flight(hotspot)` goes to the HUD), DURING (`set_rig_progress(rig_pm / 1000)` every frame), hidden
  (`set_occupied`, eyes tracking him, the world desaturated 20 % with a vignette), **room lights** (Hush's room 1.0,
  Bellows' room 0.9, other built rooms 0.78 + 40 % desaturation, backstage 0.3 — a backstage room holding Bellows 0.9 —
  tweened 0.4 s; `room_dimming` off → every built room 1.0).

### 5.14 Camera in 3D — `CameraDirector3D` (v1.1-3D; owner `r3d-view3d`, `game/view3d/camera/camera_director_3d.gd`)
The same public API as §5.5 with sim-px arguments at the lane, on a `Camera3D`:
```gdscript
class_name CameraDirector3D extends Camera3D
signal gag_started(id: int, in_pip: bool) ; signal gag_finished(id: int)
func setup(house: Variant, set_list: Variant) -> void        ## built rooms and floors (C1, C2 limits)
func follow(target: Node3D, lead_dir_fn: Callable) -> void ; func set_other(target: Node3D) -> void   ## Bellows, for C3
func set_hold_offset(on: bool) -> void                       ## C4: Hush at 40–55 % of the width while the action button is held
func set_safe_rect(r: Rect2) -> void ; func set_keep_visible(rects_fn: Callable) -> void              ## C6
func pan_by(screen_delta: Vector2) -> void ; func end_pan() -> void ; func pinch(factor: float, mid: Vector2) -> void  ## within C1–C3
func toggle_overview() -> void ; func is_overview() -> bool   ## the Map: dolly back to 15 m
func peek(world_pos: Vector2, hold_s := 1.8, follow_fn := Callable()) -> void ; func is_peeking() -> bool
func request_gag(focus: Variant, zoom: float, in_f: int, hold_f: int, out_f: int, priority := 0, yaw_deg := 0.0) -> int  ## C7 dolly
                                                             ## (+ optional approach_f, approach_zoom: the clip's `cam push`)
func punch_gag(id: int) -> void ; func set_gag_focus(id: int, p: Variant) -> void ; func release_gag(id: int) -> void
func cancel_gag(id: int) -> void ; func clear_gags(keep_id := 0) -> void ; func is_gag_active() -> bool ; func active_gag_id() -> int
func shake(trauma: float) -> void ; func kick(dir: Vector2, px: float) -> void ; func set_reduce_motion(on: bool) -> void
func visible_world_rect() -> Rect2                           ## sim px at the lane (z −1.0)
func world_to_screen(p: Vector2) -> Vector2                  ## sim px on the lane → logical screen px
func screen_to_world(p: Vector2) -> Vector2                  ## logical screen px → sim px on the lane plane (ray hit)
func project(p: Vector3) -> Vector2 ; func project_aabb(b: AABB) -> Rect2   ## 8 corners → screen bounding rect
func lane_point(x_px: float, floor: int, z := -1.0) -> Vector3 ; func px_per_m_at(z: float) -> float
func advance(view_dt: float, real_dt: float) -> void ; func snap_now() -> void ; func reset_motion() -> void
```
- **Base framing (REDESIGN §5.2):** vertical FOV **30°**, `KEEP_HEIGHT`, camera **7.5 m** in front of the lane (z +6.5) at
  **y 1.9 m** aimed at y 1.35 m on the lane (pitch **−4.2°**), near 0.5, far 60 → **1 m = 269 px at the lane** (1080
  logical), **226 at the back wall**, 322 at the lip; visible width at the lane **8.93 m (20:9), 7.15 m (16:9), 5.36 m
  (4:3)**.
- **C1** room framing (fit if width + 0.6 ≤ visible: clamp x to [x1 − V/2 + 0.3, x0 + V/2 − 0.3], else follow at 40–45 %
  with 12 % look-ahead; τ 0.20 s, 0.15 s running; doorway ease 0.45 s, never a cut; neighbour strips ≤ 1.7 m at 20:9,
  ≤ 0.8 m at 16:9); **C2** edge clamp 0.3 m (the Night-1 kitchen frames at camera x 15.33 m at 20:9); **C3** two-shot
  ≤ 1.15× (8.63 m), Hush ≥ 20 % from either edge; **C4** hold offset; **C5** floor crane 3.5 m / 0.40 s, the other floor
  never in frame; **C6** safe rect (Hush and every live prop of her room inside it); **C7** punch-ins — a dolly toward his
  head / chest to 7.5 / zoom: **S 1.15 = 6.52 m · L 1.3 = 5.77 · M 1.4 = 5.36 · SIG 1.6 = 4.69 (≥ 4.5)**, 0.18 s in, hold
  1.2–2.0 s, 0.35 s out, yaw 3–6° toward his face side for M / L / SIG (8° MIRROR, MIRROR), the clip's `cam push` slow
  dolly, hit-stop and shake per GDD §3.7, one punchline at a time; **C8** §5.15. Overview / Map: a dolly back to 15 m
  (0.5×). Reduce motion: no shake, no yaw, punch ≤ 1.15×, 0.25 s linear moves. Any framing used for play keeps the back
  wall ≤ 10 m from the camera (≥ 201 px/m, so a 0.72 m hotspot projects ≥ 144 px).
- **Render settings** (applied at runtime from Settings / `boot_config.json` `render`, never `project.godot`): MSAA 3D 2×
  (off for timing runs), 3D render scale 1.0 (0.85 fallback), outlines on / off, no shadows, no glow / SSAO / fog;
  background `#1D1728`.

### 5.15 The Bellows window — `PipView3D` and visibility contract C8 (v1.1-3D; owner `r3d-view3d`; checked by `r3d-tools-b`)
- `PipView3D`: a SubViewport sharing the main `World3D`, its own `Camera3D` framing Bellows (≈ 1.8 m tall in the window),
  cull mask `WORLD | CHAR` (no prop ink / halo, no decals, no `MAIN_ONLY` FX), **400 × 225**, rendered at 30 Hz only while
  shown; it **shows iff Bellows is off-screen** (`WorldView3D.bellows_on_screen()` false) **and**
  `SimVisibility.pip_shows(world)`; hides 1.5 s after; escalates to **704 × 396** in the same corner for an off-screen
  payoff; never while he is on screen. `get_texture()`, `shown_changed`, `pip_resized` feed the HUD's `PipFrame` (the
  frame in the temper-tier colour, his next-activity chip, the tap → peek).
- **C8 (binding):** whenever `SimVisibility.beat_vis` ∈ {`room`, `pip`}, the view MUST show Bellows — on screen or in the
  Bellows window; whenever he is on screen, the window is closed. `WorldView3D.visibility_sample() -> {tick, sim:
  String, reason: StringName, on_screen: bool, window: bool, badge: bool}` for the test.
- **Two modes (ruling R15)**, Settings / `boot_config.json` `bellows_window`: **`"sim"`** — as above; **`"lean"`** — when
  `SimVisibility.pip_reason(world) == &"adjacent"` (§3.10) and no reaction / payoff / micro-gag without an emote is
  running, the window stays closed and `WorldView3D` raises `edge_badge_wanted` (the HUD's edge badge shows him: face,
  next-activity icon, emotes); C8 accepts `badge` for those ticks. Both modes are built and tested. **Default `"sim"`;**
  the orchestrator flips `boot_config.json` to `"lean"` before `r3d-integrate` iff the first 3D P00-ideal e2e shows
  `pip_on_share` > 35 % **and** `d1_lean` (§8.5) passes D1 on every route; the owner can flip it in Settings (debug).

### 5.16 FX in 3D — floor decals, 2D overlays, the anchor API, `OverlayPlacer` (v1.1-3D; owners `r3d-view3d`, `r3d-hud`)
- **Floor decals** (`Decals3D`, visual layer 4 `DECAL`; unshaded transparent quads with depth test and no depth write —
  Godot's `Decal` node is not available on the Compatibility renderer; pooled): the stare strip (z −1.5 … −0.5: his
  moving-sight range + the darker inner frozen segment, greyed when blinded), footprints, the run noise ring (white, to
  its true radius 2.5 m, every 0.5 s), the squeak ring (yellow, to the true hearing reach: her room and every open
  doorway), B-rig noise rings every 0.5 s (`rig_actions.json noise_rings`), the destination ring (0.5 m, white) + dotted
  path + the tapped-spot pop (feedback ≤ 16 ms), floor pins, the W3 queued ghost ring with a chevron, the N4 spotlight
  pool (`sparkle()`, the Prologue's `sparkle_lever`), blob shadows.
- **2D FX over the world** (`view/fx/*`, adapted): captions (88–104 px Lilita One, 6 px navy outline), stamps, **his
  bubble** (200 × 170, icon 112, ring 12 px, awareness glyph 60 px, ear pips 3 × 24 px), the "?" spot meter, the entry
  warning, freeze frame, wipe, the Busted Cam frame — anchored with `project()`, placed through `OverlayPlacer` every
  frame (his bubble first; captions and stamps last; captions never under the transient meter / fuse).
- **Particles:** a CPUParticles3D pool, ≤ 8 emitters live (dust, pepper, sparkles, notes, drops, roses, onions, steam),
  `fixed_fps` 30, on visual layer 5 `MAIN_ONLY` when the Bellows window must not show them.
- **The overlay-anchor API** — anchor source implemented by `WorldView3D`:
```gdscript
func project(p: Vector3) -> Vector2                         ## logical screen px
func anchor_of(hotspot_id: String, kind: StringName) -> Vector3   ## kind: &"preview" &"tag" &"ring" &"item" &"eyes" &"reach"
func actor_anchor(actor: StringName, kind: StringName) -> Vector3 ## actor &"hush" &"bellows"; kind &"head" &"top" &"chest" &"feet"
func actor_screen_rect(actor: StringName) -> Rect2 ; func prop_screen_rect(hotspot_id: String) -> Rect2
func protected_rects() -> Array[Rect2]                       ## Hush +48, Bellows +48, his bubble, the prop Hush is at (+ preview), the Bellows window
func safe_rect() -> Rect2 ; func on_screen(p: Vector3) -> bool
```
- **The overlays** (`r3d-hud`, `game/ui/world/`): `OverlayModel` (RefCounted: `previews[] {hotspot, prank, pictogram,
  strength (0.3 | 0.8 | 1.0), needs_item, combines_badge, his_ring_ticks, loud}`, `thought {hotspot, pictogram, side}`,
  `item_bubbles[] {hotspot, item}`, `rig_ring {hotspot, frac}`, `safety_marker {hotspot}`, `tag_flights[] {hotspot,
  line_index}`, `hidden: bool`); `OverlayRules.fill(model, snap: ViewSnapshot, ctx: OverlayCtx) -> void` (the W3 / N1–N4 /
  V1–V6 rules of GDD §3.5; `OverlayCtx` = db, episode, `SetList.Result`, `previews.json`, settings, idle seconds, danger
  flags, `next_useful`); `WorldOverlays` (CanvasLayer 8: `setup(anchor_src)`, `apply(model)` idempotent and
  allocation-free); `OverlayPlacer.place(items: Array, protected: Array[Rect2], safe: Rect2) -> void` — priority: his
  bubble > Hush's thought > danger markers > passive previews > item bubbles > the Figgis card > captions and stamps; a
  lower item slides sideways ≤ one cloud width, then up ≤ 150 px, then waits. Sizes: passive preview 112 × 90 (78 px
  pictogram, 80 %), Hush's thought 180 × 144 (124 px), item bubble 116 px, rig ring r 118 / 14 px (yellow `#F2D23A` →
  green `#5CCF6A` on an 18 px 35 % black track), safety-net marker 88 px, the tag flight 0.6 s to its Script pip.
  `r3d-view3d`'s 2D FX register their rects with the same `OverlayPlacer` every frame.

### 5.17 Shaders and the lighting model (v1.1-3D; owner `r3d-view3d`, `game/art3d/shaders/`)
- Files: `stage_light.gdshaderinc` (the one lighting function), `char_toon.gdshader` (characters: palette + face
  decals + tint + stone + rim), `set_toon.gdshader` (architecture / furniture / dressing: palette + stage light + dim /
  desaturate), `prop_toon.gdshader` (live props: set_toon + the vinyl terms + the verb glow pulse), `outline.gdshader`
  (inverted hull, constant screen width, `outline_px`, ink `#1B2340`, `room_lerp`; no POSITION writes;
  `abs(PROJECTION_MATRIX[1][1])`), `outline_prop.gdshader` (the live props' ink shell; writes stencil 1),
  `halo.gdshader` (the 8 px verb shell; **stencil** — the prop and its ink write ref 1, the halo draws where ≠ 1 —
  proved on the 4.7.2 Compatibility renderer with a wall-embedded prop in `r3d-view3d` P0a; the fresnel glow in
  `prop_toon` stays as the in-body pulse), `decal.gdshader` (floor quads), `fx_toon.gdshader` (vinyl FX, particles).
  **All `unshaded`**; lighting is computed in the shader — no `Light3D` nodes, no real-time shadows. Compatibility uses
  reverse-Z: depth offsets in clip space are `clip.z -= k * clip.w`.
- **Global parameters** (`global uniform`), registered in `project.godot` `[shader_globals]` (ruling R8 — a global
  compiles only if it exists at compile time) and **set** at runtime by `StageLighting3D`
  (`RenderingServer.global_shader_parameter_set`): `mnd_key_dir` vec3 (toward the key: −normalize(travel (0.45, −0.75,
  −0.48)) = (−0.451, 0.752, 0.481)), `mnd_key_color` `#FFF4E0`, `mnd_key_lit` 0.28, `mnd_key_top` 0.08, `mnd_fill` 0.66,
  `mnd_fill_color` `#A8A4AE` (the set's neutral shadow band), `mnd_band_soft` 0.08, `mnd_rim_color` `#BFE0FF`,
  `mnd_rim_power` 2.5, `mnd_foot_strength` 0.12, `mnd_foot_fade_m` 1.2, `mnd_lip_z` 0.25, `mnd_outline_scale` 1.0 (1.5
  with "Outline +50 %"), and look A's vinyl terms **`mnd_shadow_tint`** `#B9A3E0` (A's lilac (0.66, 0.58, 0.80) lifted to
  luminance 0.67), **`mnd_bounce`** 0.14, **`mnd_sheen`** 0.10. A new global is a request to the orchestrator (the owner
  of `project.godot`); until it is registered the shader uses a plain uniform.
- **The model:** one key (+28 % on the lit band, +8 % on a top band), two soft bands (softness 0.08), **no surface below
  66 % of its albedo's luminance** (the include clamps the final shade's luminance ≥ `mnd_fill` after tint and bounce);
  the footlight gradient (additive warm, 12 % at the lip z +0.25 fading to 0 by 1.2 m up); rim on characters only
  (fresnel power 2.5, strength 0.35–0.55). **Look A's shading is kept on characters and vinyl props** (`char_toon`,
  `prop_toon`): A's `toy.gdshader` soft two-tone terminator with the lilac shadow tint, the ground-bounce darkening on
  down-facing normals and the 0.10 matte vinyl sheen (`smoothstep(0.86, 0.97, N·H)`, lit band only) — inside the 66 %
  floor; `set_toon` keeps the neutral `mnd_fill_color` band. No normal maps, no PBR.
- **Room light (`stage_light`):** Hush's room 1.0; Bellows' room when it is not hers 0.9; other built rooms 0.78 + 40 %
  desaturation; backstage 0.3 — **except a backstage room that holds Bellows, lit 0.9** (architecture + the station
  furniture he uses; tweened 0.4 s) — and **his `char_toon` `stage_light` never drops below 0.9** (Hush's follows her room).
- **Per-material uniforms:** `char_toon` — `palette`, `face_atlas`, `face_grid` (ivec2), `face_cell_a` (ivec4: brows,
  eyes, pupils, mouth; −1 = off), `face_cell_b` (ivec4: extra_a, extra_b, lids, spare), `face_rect[6]` (vec4),
  `pupil_offset` (vec2, −1…1 of `pupil_range`), `tint_color` (vec4, alpha = amount; skin mask = COLOR.r), `stone` (0…1;
  keep mask = COLOR.g), `flash` + `flash_color`, `rim` (0.35–0.55), `stage_light`, `desat`; `set_toon` / `prop_toon` —
  `palette`, `stage_light` (1.0 / 0.9 / 0.78 / 0.3), `desat` (0 / 0.4), `glow_color`, `glow_amp` (0 off; 1 normal
  0.6↔1.0 at 1.2 Hz; 2 the active spot); `outline` — `outline_px` (characters 4.8, live props 3.4 at the 1080
  base — lead decision D7, look A's own weight; REDESIGN §5.4 and `r3d-index.md` §7.6 said 3.5 / 2.5), `room_lerp` (0.5
  in a dimmed room).
- **Visual layers** (`View3DConst`): 1 `WORLD` (set + props), 2 `CHAR` (characters; their outline is a `next_pass`),
  3 `PROP_INK` (prop outline + halo shells, separate static instances so they can be culled), 4 `DECAL`, 5 `MAIN_ONLY`
  (FX the Bellows window never shows). The Bellows window's cull mask = `WORLD | CHAR`.
- **The vinyl key (`r3d-view3d` P0a):** `char_toon`, `prop_toon` and `fx_toon` take `key_front` (default 0.35) — the key
  bent toward the camera as look A's character key, so the painted faces stay lit; `set_toon` keeps the pure key.
- `MaterialWarm3D.register(mat: Material, kind: StringName)` (kinds `&"char"`, `&"set"`, `&"prop"`, `&"ink"`,
  `&"halo"`, `&"decal"`, `&"fx"`) — every task that creates a material at runtime registers it; `NightWarm` draws every
  registered (shader, kind) pair once under the curtain (§5.11). A rendered smoke test compiles every shader from a
  fresh process and checks the dark-side luminance floor.

### 5.18 Audio, HUD and UI in 3D (v1.1-3D; `AudioDirector` `r3d-view3d`; HUD `r3d-hud`)
- **AudioDirector:** pans by the source's **projected screen x**; everything else in §5.8 is unchanged (the audio files
  and cues are frozen during R3D).
- **HUD** (GDD §3.8): **four always-on pieces** — pause (S+24, T+24) 144×144, the Script chip (S+192, T+24) 312×144,
  Clarence / ⏩ (S+32, H−B−200) 168×168, the action button centred at (W−S−168, H−B−168), a 240 circle; contextual pieces —
  the transient Applause meter (W/2−230, T+24) 460×104 + the Running Gag fuse, the Bellows window frame (W−S−424, T+24)
  400×225, the edge badge, carried-item chips (S+224 + i·168, H−B−188), Figgis (S+24, T+192), BOW (W−S−344, T+273)
  320×112, the pick strip, the Overview button from Night 3, tomatoes in the meter. **New `HudModel` fields:** `verb_live`,
  `freeze_danger` (0 none, 1 exposed, 2 "?" filling), `meter_until_s`, `carrying`, `bow_visible`, `figgis_visible`,
  `overview_visible`, `lure_ring` (0 hidden, 1 on, 2 grey), `script_pips` (per line: required / optional / big, state),
  `edge_badge_*` (incl. `edge_badge_lean`), `tag_flights`. `Hud.apply(model)` stays idempotent and allocation-free.
  **`Hud.debug_pieces() -> Array[{name, rect, always_on, persistent}]`** and **`Hud.always_on_rects() -> Array[Rect2]`**
  for the HUD and screen-rect lints; `fly_tag(from, line_index)`, `open_pause_menu(can_bow, header)` and the intents
  `bow_tap`, `hint_tap`, `map_open`, `tag_arrived` join §5.9's. The action button's QUIET / LIVE states (GDD §3.2); the
  ring fills on the button and at the prop (the overlay rig ring).
- **Panels:** the pause panel gains **Hint** (Figgis steps 2–3) and **Map** (the `map_open` intent: the sim stays paused,
  the panel closes, `cam.toggle_overview()`, a tap on a room → `cam.peek(<room centre>)`); the Script panel gains his
  routine strip with beret stamps and tonight's rule. Strings (C5): `pause.hint`, `pause.map`, `hud.bow`,
  `settings.previews.*`, `settings.room_dimming`, `settings.outline_boost`, `fx.struck` (reserved; nothing is shown in
  play) — all through `UiStrings`.
- **Settings keys** (§7): `previews` (`always` | `idle_6s` | `off`), `room_dimming` (bool), `outline_boost` (bool); debug:
  `hush_head` (`""` | `"head_b"`), `bellows_window` (`"sim"` | `"lean"`), `msaa_3d`, `render_scale`, `show_previews`; a
  debug key's default comes from `boot_config.json` when present.

### 5.19 The Stalls and Figgis in 3D (v1.1-3D)
- **StallsView** (`r3d-view3d`): **hidden at rest**; it rises 60–150 px by tier on laughs, and for a gasp, shush, "BEHIND
  YOU!", chants and boos, in the band x ∈ [S+560, W−S−440] on layer 9 (under the HUD); never a target; one batched draw.
- **Figgis** (`r3d-hud`): `FiggisChip` runs at its **SVG level** only (no reference to the 2D `RigPlayer` / `ClipLib` /
  `AtlasBuilder`, so the 2D rig runtime can be deleted); moods swap SVG poses with a small 0.15 s bob / tilt; the bust
  SVGs are restyled as a flat matte-vinyl bust in look A's palette; the card, arrow and 4 s auto-hide are unchanged. A
  pre-rendered 3D-style sprite is R3.

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
8. **(v1.1-3D) Input on the 3D view** (`scenes/night/night_input.gd`, `r3d-night`): `InputRouter` emits **logical screen
   positions** (no Camera2D; the 2D conversion is kept only where one exists). A tap resolves with
   `TapAssist.resolve(screen_pos, world_view.hotspot_rects_in_view(), 1.0)` against the **projected hit boxes** (§5.13;
   unchanged 90 px assist, priorities and stacks); a floor result takes its `x` from `cam.screen_to_world(pos).x` (the
   lane plane); go / run (double tap) / pin while hidden or frozen / long-press as before; pan and pinch →
   `cam.pan_by` / `cam.pinch` within C1–C3 (a pan while hidden never moves Hush); the action-button hold →
   `cam.set_hold_offset(true)` (C4); `world_view.tap_feedback(...)` within 1 frame (the ripple + destination ring); a
   `cmd_rejected {why: "struck"}` → a small "no" wobble at the tap, no text.

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
- **(v1.1-3D) New keys** (`r3d-hud`): `previews` (`always` | `idle_6s` | `off`; default `always`), `room_dimming`
  (bool, default on), `outline_boost` (bool, default off; → `mnd_outline_scale` 1.5 and `RigPlayer3D.set_outline_scale`);
  debug: `hush_head` (`""` | `"head_b"`), `bellows_window` (`"sim"` | `"lean"`), `msaa_3d` (bool), `render_scale` (1.0 |
  0.85), `show_previews` (the N1 / N2 stage-door entries). A debug key's default comes from `boot_config.json` when
  present (§5.11), so the orchestrator's value flips reach the owner build without code changes. The Stage-2 keys
  `voice_style` / `crowd_style` (`formant` defaults) and `hush_skin` stay.

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
- **(v1.1-3D) `d1_lean`** (a per-route report column, ruling R15): the D1 dead-air metric recomputed with
  adjacency-only `pip` beats (`SimVisibility.pip_reason == &"adjacent"`, §3.10) counted as visible **only** when the
  micro-gag has an `emote` (the Stage-2 edge rule, incl. the ≤ ⅓ edge-share cap); the D1 thresholds (ideal ≤ 20 %,
  required ≤ 25 %, slow ≤ 30 %, worst gap ≤ 12 s) applied as info rows. It decides whether the `lean` Bellows-window
  mode may ship (§5.15). The N02 `face_to_face` and `face_to_face_lost` scenario routes are retired (GDD §3.4); N01's
  hides re-plan to the pantry curtain and the piano back.
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
9. Progress: Bellows' activity changes at least every 60 s (uncapped player-led gates excepted); Hush's go/move
   commands produce movement, an arrival, a rejection or a `cmd_queued` event within 150 ticks.
10. At most one reaction active at a time; applause never negative; each Night's prank bases sum to 700 tenths.
11. (Stage 3) Beryl's headbutt never produces `caught`.
12. (Stage 2, ruling L4) No `combo` the Night's `rules.combos` does not allow (`[]` = none).
13. (v1.1-3D) **No command on a struck hotspot is accepted:** every `go` / `pin` on a hotspot outside the live mask
    (§3.10) is refused with `cmd_rejected {why: "struck"}` and Hush does not move; the fuzz bots' random taps include
    struck hotspots.
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

**(v1.1-3D) The budgets restated for the 3D view** (REDESIGN §5.6 + §6.3; the rows above that name 2D machinery —
"Per character ≤ 12 draw calls", "CPUParticles2D only", "CanvasGroup / Light2D", atlas pages — are (2D, main only)):

| Budget | Target (mid-range Android: Adreno 610 / Mali-G52 class) | How it's measured |
|---|---|---|
| Frame rate | **60 fps p95** with two characters, the Bellows window and a gag burst (punch-in + particles) | DevShot `--perf-log` (3D fields), e2e `frame_ms_p50/p95`, the on-device perf probe |
| Draw calls | **≤ 150 p95, ≤ 250 max**, the Bellows window + a gag burst included | `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` → e2e `perf3d.draw_calls_p95/max` |
| Triangles on screen | **≤ 150k** | primitives in frame → `perf3d.tris_max` |
| Per character | **≤ 10k triangles, ≤ 50 deform bones** (+ jiggle), 1 skinned mesh + ≤ 4 attachments, 1 material + outline = **≤ 4 draw calls**, **≤ 0.25 ms CPU** (skinning + jiggle + face) | `RigPerf3D` (median of 5 runs: `hush/loco_run`, `bellows/rx_sneeze_blast_a`), the cast tests |
| Particles | **≤ 8 CPUParticles3D emitters** live (CPUParticles2D in the HUD), `fixed_fps` 30 | `perf3d.emitters_max` |
| Textures | **≤ 250 MB** (target 150) — **`Performance.RENDER_TEXTURE_MEM_USED`** (the engine's number; `TexStats` keeps its breakdown of runtime rasters) | `perf3d.tex_mb_max` |
| Shader compiles | **0 during PLAY** (every material drawn once under the curtain, §5.11) | `perf3d.shader_compiles_play` + the device log's `shader_first_use` / `hitch` lines |
| View + HUD scripts | ≤ 4 ms / frame p95 (view scripts ≤ 2 ms headless); no per-frame allocations in `advance`, decals, FX, overlays, `Hud.apply` | the perf checker (`perf3d.sh`); counter tests |
| Lights / shadows | no `Light3D`, no real-time shadows, no glow / SSAO / fog; MSAA 3D 2× with an off switch, render scale 1.0 with a 0.85 fallback | code review + the render settings (§5.14) |
| Bellows window | rendered only while shown, at 30 Hz, cull mask `WORLD \| CHAR` | §5.15 |
| Set build | `House3D.build` ≤ 150 ms; the Night's build + warm under the curtain inside GDD §2.3's budget (≤ 2.0 s; the curtain rises at 3.0 s at the latest, `WARM_CAP_S`) | tests + the device log |
The desktop proxy (llvmpipe, one render thread per process) is relative only: every real-time check compares against
max(threshold, one measured frame time) and runs with MSAA off; the device numbers come from the owner's phone (the
perf probe, then the owner APK's device log).
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
| 3D lints (v1.1-3D) | the 3D animation lint; set, screen-rect, HUD, visibility, perf (§10.5) | `r3d-anim`; `r3d-tools-b` | `tools/scripts/lint.sh` (3D anim), `tools/scripts/lint3d.sh`, `tools/scripts/perf3d.sh` |
| 3D tests (v1.1-3D) | rig player + sampler, sets + reach + collisions, cast budgets, clips, camera numbers, C8, overlays | each R3D owner | `tests/{rig3d,set3d,cast3d,anim3d,view3d,lint3d}/` |
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
- **Animation lint** (`game/tools/anim/lint_anim.gd`, comedy.md §7.6; the 2D rules, (2D, main only) — the 3D rules
  below): frames increase; ids resolve; joint limits; loop seams ≤ 0.5° with continuous velocity; accent ≤ 4 f with ≥
  20°/f peak on some part; anticipation opposes the accent (dot < 0); reaction holds ≥ 24 f (≥ 36 f at tier ≥ 2); no
  dead hold > 20 f unless `freeze`; no jump > 45°/f unless `pop`/smear; no L/R twinning > 10 f; planted feet drift ≤ 2
  px and never > 3 px below the floor; impact sfx within ±1 f of a key; face swaps only on keys; laugh after the accent;
  reactions 60–240 f (signatures ≤ 420) unless `skippable`; bounding box changes ≥ 15 % from anticipation to accent;
  beats match `reactions.json` within 2 f.
- **Rig lint** (2D, main only): every part file exists and parses; pivots inside the canvas; parent chain acyclic;
  mirror pairs resolve; face slot variants exist; the rest pose silhouette at 50 px is non-empty and within 20 % of
  `height_px`.
- **(v1.1-3D) 3D animation lint** (`game/tools/anim/lint_anim.gd -- --format=3d [--rig=R] [--clip=ID] [--scope=g0,p00]
  [--strict] [--json=/abs]`, rules in `lint3d_rules.gd` + `lint3d_limits.json` on `RigSampler3D`; owner `r3d-anim`;
  `tools/scripts/lint.sh` forwards it with `--scope=g0,p00` when `data/anim/hush3d/` exists). "Angular speed" = the
  per-frame rotation angle of a bone's local rotation. Rules: ids resolve (sidecar ↔ `.res` ↔ rig: sound ids in
  `sfx_map.json`, face presets / cells in the rig, props / looks / sockets in `rig3d.json`); length = the Animation's
  frames; frames inside the clip; loop seams ≤ 0.5° on every bone with continuous angular velocity; **accent ≤ 4 f with
  a ≥ 20°/f peak on some bone**; anticipation opposes the accent (the dominant bone's mean angular velocity over the
  anticipation · over the accent < 0, or the pelvis moves against it); reaction holds ≥ 24 f (≥ 36 f at tier ≥ 2 through
  `PlayPlan3D`); no dead hold > 20 f (every bone < 0.3°/f) unless in `lint.freeze_holds` or a freeze clip; no jump > 45°/f
  unless the frame is in `lint.pop_frames`; no L/R twinning > 10 f; **feet in lane space** — for clips with `speed_m_s`
  (in-place walks and runs) `speed_m_s · t` is added along the facing axis first, then a planted foot drifts ≤ 0.01 m
  over its contact range and its clip-space stance velocity equals −`speed_m_s` ± 5 %; other clips in clip space; a foot
  never > 0.015 m below its support (y 0, or `step_h` on a step); impact sounds within ±1 f of a beat boundary or a
  `mark`; the take's face swap within ±1 f of the accent; the laugh after the accent; reactions 60–240 f (signatures
  ≤ 420) unless `lint.skippable`; bounding-box change ≥ 15 % from anticipation to accent; beats within 2 f of
  `reactions.json`; `variation.time_jitter == 0` on `rx_*`; sound frames = the audio table; lengths = the manifest's
  expect ± tolerance (`SliceClips.build3d`); `cheat_deg` ∈ [0, 40] (≤ 10 on rig clips while reaching); `root.travel ==
  "sim"` ⇒ root x/z displacement ≤ 0.15 m; **rig clips** (`rig_*`): `lock == "rig_pm"`, a prank clip's length = its tier's
  frames (48 / 90 / 150), a band clip any length ≥ 48 and **no baked glance marks**, a stepped clip ends on the floor
  (pelvis back to 0 ± 0.01 m). `lint.draft: true` exempts a clip only from rubric scoring. `--strict` makes every warning
  an error; the exit scope (ruling R9) = every clip of `SliceClips.build3d(["g0_sneeze", "p00_curtain_up"])` (70, +
  `freeze_5..8` once mapped) + `rig_high/mid/low`, drafts included; N01 / N02 clips missing in 3D are info.
- **(v1.1-3D) The REDESIGN §6.3 lints** (`game/tools/lint3d/**`, `tools/scripts/lint3d.sh`; owner `r3d-tools-b`; every
  colour / silhouette number comes from the shared toolset `tools/art3d/review/`, §11.1):
  - **Set lint** (`lint3d.sh --set [--night=<id> | --all-nights] [--strict] [--json=…]`), per final Night (+ g0) and built
    room: live props ≤ 5 (rig points with a prank tonight + containers with an item tonight + listed hiding spots;
    doors / exits / stairs excluded), dressing ≤ 4, one hiding spot per room in Act I, dressing ≥ 0.5 m on its longest
    side, never in the lane above 0.45 m, never in the 0.6 m band above a live prop, quake props ≥ 2.2 m or on the
    mantel, a 1.5 m stretch of lane clear behind at head height; no two live props closer than 24 px on screen
    (projected hit boxes at the base framing; the two allowed stacks keep ≥ 24 px); silhouettes — each live prop
    rendered alone as a black mask 64 px tall (`LintShot3D --pass=mask:<hotspot>`), pairwise IoU per room (`sil64.py`),
    **IoU ≥ 0.80 = same family = error**, and the `house3d.json` families differ; colour and value on rendered shots
    (`--pass=beauty` + `--pass=id` with its legend → `lab.py regions` + `lab.py rules --rules=set`): lit walls L* 62–76 and
    C* ≤ 28, wainscot 8–10 L* darker, dimmed walls L* 45–58 and C* ≤ 15, floors L* 40–50, dressing C* ≤ 30 and
    |ΔL*| ≤ 15 vs its wall, live props C* ≥ 45 or a verb halo, characters ≥ 20 % of the silhouette at L* ≥ 85 and ≥ 20 %
    at L* ≤ 40.
  - **Screen-rect lint** (`lint3d.sh --screen --aspects=20x9,16x9,4x3`, headless): every live hotspot of every final Night
    (+ g0) — `House3D.hotspot_box` projected with `CameraDirector3D` at the base framing for every camera position the
    room can use (one C1 framing when the room fits, else a 0.25 m sweep of the clamped range; C2 applied), at 2400×1080,
    1920×1080 and 1440×1080 logical with a punch-hole phone's insets (S = 96 at 20:9): **≥ 144×144 px, ≥ 24 px** from
    every other live rect, **inside the safe rect**, **not under an always-on HUD hit rect** (`Hud.always_on_rects()`;
    error), not under the Bellows window (warning); the back wall ≤ 10 m from the camera.
  - **HUD lint** (`lint3d.sh --hud --from=<dir of e2e reports>`): **≤ 4 always-on pieces** in every `hud_pieces` sample
    (pause, script_chip, clarence, action); **no always-on or persistent rect in the middle band y 250–880** (persistent =
    shown > 5 s continuously; the only contextual pieces allowed there: the edge badge in the outer 160 px, the Figgis
    card, the pick strip); **≤ 6 world overlays with ≤ 2 loud** (V6); the **Bellows-window share**: `pip_on_share` and
    `pip_longest_s` read from every report, a **warning above 35 %** (never an error).
  - **Visibility test C8** (`lint3d.sh --visibility --routes=all [--aspects=20x9,4x3] [--mode=sim|lean]`): every solver
    route of every final Night (+ g0) replayed headless through SimWorld + `WorldView3D` + `CameraDirector3D` + the
    `PipView3D` rule at a fixed 60 fps; on **every tick**, in the shipped `bellows_window` mode (the other mode as info):
    `beat_vis` ∈ {`room`, `pip`} ⇒ Bellows on screen (≥ 35 % of his projected bounds inside the viewport) or the window
    shown — under `lean` also the edge badge on ticks whose `pip_reason` is `adjacent`; on screen ⇒ window closed; each
    route's window share printed; the first violation per route shot at 1200×540.
  - **Perf checker** (`tools/scripts/perf3d.sh <e2e report.json>…`): reads the `perf3d` blocks — draw calls p95 ≤ 150 and
    max ≤ 250, triangles max ≤ 150k, emitters max ≤ 8, texture ≤ 250 MB, `shader_compiles_play` == 0, script time p95
    ≤ 4 ms; one row per report; exit 1 on any breach. `r3d-tools-b` posts every lint failure with its owner in
    `docs/review/r3d-tools-b/status.md`.
- **(v1.1-3D) Content lint additions** (`r3d-content`): `hides` validation (§4.6); `previews.json` and `rig_actions.json`
  (ids resolve, every slice prank covered, tiers = `pranks.json` prep, hotspots = `rig_point`, bands / steps = the
  placed targets of `house3d.json`); the 3D clip coverage — every clip of `SliceClips.build3d(["g0_sneeze",
  "p00_curtain_up"])` exists as a v2 sidecar (error under `--strict`), N01 / N02 3D coverage as info. The hotspot lint
  keeps guarding `house.json` (≥ 144 × 144 rects, ≥ 24 px gaps) and a test pins its checksum (C3).

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

### 11.1 Review tooling in 3D (v1.1-3D)
The 2D sheet tools above (`anim_sheet.sh`, the 2D `capture.gd`) are (2D, main only). In 3D:
- **`AnimViewer3D.tscn`** (`scenes/dev/anim3d/`, `r3d-rig`; shot-able): `--rig=<id> [--variant=head_b] (--clip=<id> |
  --pose=rest | --anim-glb=/abs [--anim-name=N]) [--frame=N] [--play] [--speed=k] [--cam=game|front|q34|side|back|face|turn]
  [--face=<preset>] [--looks=a,b] [--tint=0-4] [--stone] [--facing=1|-1] [--cheat=deg] [--room=<room> --x=<m> --z=<m>]
  [--rig2=… --clip2=… --x2=… --facing2=…] [--events]`; hot-reloads the sidecar on mtime every 0.5 s; `--room` builds the
  room through `House3D` with the game camera.
- **`tools/scripts/anim_sheet3d.sh <rig> <clip> <out_dir> [--room=<room>] [--cam=side|game]`** (xvfb + opengl3, `sheet3d.gd`,
  rendering with `RigPlayer3D` — the game's own player) writes `<clip>_contact.png` (a cell every 3 f + every beat
  boundary; anticipation blue, accent red, hold grey; events under the cells; a second copy at phone scale — the
  character at 217 / 236 px on a 1200×540 cell), `<clip>_onion.png` (per beat, blue → red, spacing dots on head top, hands,
  pelvis), `<clip>_curves.json` → `tools/anim/curves.py` → `<clip>_curves.png` (rotation angle + angular speed for pelvis,
  spine_03, Head, hands, feet; beat markers), `<clip>_sil64.png` (black silhouettes 64 px tall at the beat frames),
  `<clip>_lint.txt`; plus `--turntable` (front / 3/4 / side / back) and `--faces` (every preset on the head at 3×).
- **`RigPerf3D.tscn`** (`--rig --clip [--variant] --perf-log`): one character, 600 frames; µs per frame (animation
  advance + modifiers + face), draw calls, primitives, bone and triangle counts; one `[rigperf3d]` JSON line.
- **`SetPreview3D.tscn`** (`scenes/dev/set3d/`, `r3d-sets`): `--episode=<id> [--room=<room>] [--x=<cam x m>] [--hit-rects]
  [--anchors] [--reach=hush] [--state=<hotspot>:<idle|armed|spent|rig@0.5>] [--glow=<hotspot>|all] [--occupied=<hide>]
  [--lit=<room>] [--chars] [--check]` — the base framing (or C1), projected hit boxes with their sizes, a Hush capsule
  (r 0.15 m, 1.60 m + step) at every live rig point's `reach_pos` with her shoulder-to-target line (green ≤ 0.50 m, red
  above) and **collision checks** (her capsule at every `reach_pos` and on the lane, Bellows' r 0.45 m barrel at every
  station, against `furniture_boxes()` and the live props' AABBs); `--check` prints JSON and exits 1 on any error.
- **`LintShot3D.tscn`** (`scenes/dev/review3d/`, `r3d-tools-b`): `--episode --room --aspect --pass=beauty|id|mask:<hotspot>
  --chars --x=<m> [--legend=/abs.json]` — the render passes the set lint measures (the `id` pass writes the legend
  `lab.py regions` reads; the `mask` pass the black-on-transparent PNG `sil64.py` reads).
- **`ViewSandbox3D.tscn`** (`view3d/sandbox/`): `--scenario=<id>` over `FakeWorld`, or `--sim --episode --cmds --seek
  [--realtime]`; `PerfProbe3D.tscn` (`view3d/probe/`) — the self-running on-device perf probe (the P00 kitchen, both
  characters walking / idling, the Bellows window, outlines and halos, a gag burst every 10 s; 20 s per setting — MSAA 2× /
  off, render scale 1.0 / 0.85, outlines on / off — then a summary card, also written as `[perfprobe]` lines to
  `user://perfprobe.log`).
- **Capture on 3D:** `tools/scripts/capture.sh` runs `res://tools/anim3d/capture3d.gd` (a duck-typed hook on any node
  with a `clip_event` signal) through Movie Maker on the real 3D game; `tools/anim/gif.py` makes the 30 fps GIF + a mute
  copy; the WAV is kept for sync checks.
- **`tools/art3d/review/`** (`r3d-tools-a`) — the **one shared measuring toolset** every visual task uses (no private
  samplers): `lab.py` (sRGB → CIELAB D65, L*, C*ab, ΔL*, ΔE76; `regions` per ID colour of an ID pass, `value` = the
  shares of a silhouette at L* ≥ 85 and ≤ 40, `rules --rules=set` = the GDD §7.1 set rules, `falsecolor`), `sil64.py`
  (masks → 64 px tall on a 96×96 canvas, pairwise IoU, `--same-family=0.80`, a board), `strip.py` (numbered frame strips
  at phone scale, JPEG q85 ≤ 4 MB, accent frames outlined from a marks JSON — strips replace raw frame folders),
  `boards.py` (`grid`, `pair` before / after at 1200×540 per cell), `packets.py` (`build` opaque reviewer packets
  `pkt_XX` in shuffled order with the key written **outside** the packet dir and a `prompt.md`; `score` → the verdict
  table), a README with one example per tool, fixtures and `test_review.py`.
- **Fresh reviewers (ruling R17):** a check that needs a fresh reviewer (the cast face tests, the 64 px verb board, the
  readability review) spawns one when the task's tools allow; otherwise the task writes opaque packets
  (`packets.py`) + `docs/review/<key>/reviewer_prompt.md` (the key apart in `<SP>/work/<key>/review_key.json`), lists
  them under REQUESTS in its `LANDED.md` and reports the line "pending review"; the orchestrator runs the reviewers and
  pastes the verbatim answers into `docs/review/<key>/reviewer_answers.md`.
- **The 2D "before" frames** for every before / after comparison: `docs/review/r3d-ref2d/` (the 2D build at 67c7276 shot
  at fixed ticks, with `ticks.json`); the 3D frames are shot at the same ticks.

---

## 12. Build and CI
- Existing: `tools/scripts/{sandbox,test_game,shot,export_android}.sh`, `tools/ci/{check_import_meta,export_lib,
  verify_android}.sh`, `.github/workflows/{ci,android-preview}.yml`.
- New (Stage 1): `tools/scripts/{solve,fuzz,lint}.sh` + `tools/ci/lint_all.sh` (solver), `tools/scripts/
  {anim_sheet,capture}.sh` (rig), `tools/scripts/gen_audio.sh` (audio: `python3 tools/audio/gen_audio.py` +
  `--check`).
- **CI jobs** (`.github/workflows/ci.yml`, solver edits): import metadata → GDScript tests → lints → solutions for
  `final` episodes → bounded fuzz → `gen_audio.py --check`. Android preview APK on every push to `main` (exists).
  The Python job (`tools/ci/lint_all.sh --no-godot`: art validators + `gen_audio.py --check`) needs Python 3 with
  numpy + Pillow and `rsvg-convert` from apt `librsvg2-bin` (not on the `ubuntu-24.04` runner image; the job
  installs it) — the art validators rasterise every SVG part with it. Locally: `apt install librsvg2-bin`.
- **Import metadata:** every new asset/script ships its `.import` / `.uid` sidecar. Agents never run Godot on
  `game/` directly; the orchestrator runs one import on the real project after each stage and commits sidecars.
- **(v1.1-3D) The 3D build chain:**
  - **Blender 4.5 LTS** headless: `tools/art3d/setup_blender.sh` (idempotent, locked; reinstalls 4.5.14 into
    `/opt/blender` with a pinned sha256 when `/opt` was wiped) and `tools/art3d/blender.sh [blender args]` (= `slot.sh
    blender -b --factory-startup --threads 1 …`). Godot 4.7.2, its export templates and the Android SDK:
    `tools/ci/setup_godot.sh` (idempotent, locked; sha-checked downloads). A task that finds either missing runs the
    script once.
  - **Vendored CC0 inputs:** `tools/art3d/vendor/ual/{UAL1_Standard.glb, UAL2_Standard.glb, License_UAL1.txt,
    License_UAL2.txt, SHA256SUMS}` (the Quaternius Universal Animation Library 1 + 2, CC0 1.0) — build inputs only, never
    under `game/`; `game/art3d/CREDITS.md` records the source URL and licence of every third-party file.
  - **The look-dev references** are committed (restart safety): `tools/art3d/look-cartoon/**` (look B — the owner's
    binding reference for Hush's dimensions) and `tools/art3d/look-toy/proj/**` (look A's Godot project: `toy.gdshader`
    is the template for `char_toon`, `toy_char.gd` the face driver); their `.glb`s regenerate with the committed
    builders into the gitignored `tools/art3d/cache/`; `build/art3d/` is gitignored too.
  - **The clip pipeline** (`r3d-anim`): specs `tools/art3d/anim/<rig>/<clip>.py` on the pose language
    (`tools/art3d/anim/lib/`); `tools/art3d/anim/bake.sh <rig> [clip… | --all | --changed] [--ual <UAL clip> --as <clip id>
    [--layers …]]` runs one Blender process for the listed specs (→ `build/art3d/anim/<rig>/<clip>.glb`: armature + one
    action, no mesh) and one Godot run of `game/tools/anim/glb_to_res.gd` for all of them (→ `game/art3d/anim/<rig>/
    <clip>.res` + the sidecar `game/data/anim/<rig>3d/<clip>.json`); it applies the rig's `anim.layers` to every clip,
    copies the timed sound frames from `data/audio/clip_events.json` and fails the bake if a timed clip's length differs;
    `--changed` rebakes specs newer than their `.res`. The README (`tools/art3d/anim/README.md`) is enough to bake a first
    clip.
  - **Shader globals:** every `mnd_*` global of §5.17 is registered in `game/project.godot` `[shader_globals]` (the only
    `project.godot` change of R3D; the orchestrator's file) so a `global uniform` compiles from a fresh process.
  - **CI:** `r3d` (and the throwaway `r3d-probe`) are in `on.push.branches` of `android-preview.yml`, `r3d` in `ci.yml`;
    WIP commits carry `[skip ci]`.
  - **WIP pushes and the landed mirror (ruling R16):** during R3D the orchestrator commits `WIP r3d <UTC> [skip ci]` and
    pushes `r3d` every 60–90 min, mirroring every `<SP>/work/r3d-*/LANDED.md`, `<SP>/reports/r3d-*.md` and
    `solve_before.json` into `docs/review/r3d-landed/`; after a container restart it re-runs the setup scripts, restores
    them and relaunches the running tasks (each resumes, §13).


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
7. **(v1.1-3D) CPU slots (ruling R11):** every Godot and Blender process goes through `tools/scripts/slot.sh <cmd…>` —
   4 global slots (`/tmp/mnd_slots/slot{1..4}.lock`, `flock -n`, a 3 s retry, `[slot] waiting` once a minute, exit 75
   after `MND_SLOT_WAIT`, default 1800 s); a slot is **one process and one render thread** (`slot.sh` exports
   `LP_NUM_THREADS=1` and `GALLIUM_THREAD=0`; `blender.sh` passes `--threads 1`); `MND_SLOT_HELD=1` skips re-acquiring in
   nested calls. The scripts already call it (`sandbox.sh`, `test_game.sh`, `solve.sh`, `lint.sh`, `fuzz.sh`, `shot.sh`,
   `capture.sh`, `e2e.sh`, `anim_sheet.sh`, `anim_sheet3d.sh`, `blender.sh`); **each task runs at most one Godot /
   Blender process at a time**, keeps renders at 1200×540, uses `--fixed-fps 60` sequences with `--every=N`, runs long
   jobs in the background and polls; never override the thread variables.
8. **(v1.1-3D) The R3D soft-hook rules:** stand-ins until the real piece lands (the look-dev glbs loaded at runtime
   with `GLTFDocument` in shots only, never committed under `game/`; `House3D` greybox primitives from `house.json`;
   UAL idle / walk clips or a rest pose; the current HUD widgets) and every consumer re-shoots with the real pieces
   before it reports; soft calls (`ResourceLoader.exists`, `FileAccess.file_exists`, `_soft_script(path)`, `has_method`;
   tests `skip("<module> not built yet — <owner>")`); the contracts of `r3d-index.md` §7 are binding from launch — change
   one only by adding optional fields with defaults, a breaking need is a request; **never leave the tree broken**
   (risky rewrites in the scratch dir; a broken shader, scene or JSON in `game/` breaks every sandbox copy within
   minutes); shared assets flow one way (cast → rig / anim / view3d; sets → view3d / hud / tools / content; anim →
   view3d; content → sets / hud / anim; view3d → everyone; tools-a → every visual task); **a replaced 2D file is frozen
   whatever glob covers it** (§1.1); import sidecars (`.import` / `.uid`) are never hand-written — the orchestrator runs
   one import on the real project between batches.
9. **(v1.1-3D) `LANDED.md` and resume (ruling R16):** each task appends one line per landing to
   `<SP>/work/<key>/LANDED.md` (UTC time, what, where; `REQUESTS` for blocking asks) and reads the others' before polling
   the tree; on every (re)launch a task reads its own `LANDED.md`, its report draft and its scratch dir first and
   continues from the last landing — never redoes landed work; animation keys write one `DONE <clip> <sha256 of the
   spec>` line per finished clip and a relaunch runs `bake.sh <rig> --changed` first.
10. **(v1.1-3D) Baselines and disk:** before its first change to anything the sim reads, a task saves
    `SANDBOX=<key> tools/scripts/solve.sh all --route=all --report=<SP>/work/<key>/solve_before.json` and checks against it
    at the end (`--baseline=`; no route or expect key that passed may fail); ≤ 800 MB per task (at most two sandboxes,
    `<key>` and `<key>-shot`); raw frame folders deleted once the strip / GIF exists; review folders ≤ 25 MB, GIFs ≤ 4 MB.

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
- **(v1.1-3D) 3D ids** (added; nothing renamed):
  - **Rig variants:** `hush` variant `head_b` (the proposed head scale; `""` = B's head); a `pip` skin request falls
    back to Hush (R3D builds the mime only).
  - **New clip ids:** `hush/rig_achoo_ria`, `hush/rig_allegro_go_go` (prank rig actions, `lock: rig_pm`),
    `hush/rig_high`, `hush/rig_mid`, `hush/rig_low` (the normalised band fallbacks), `hush/rig_step_down`,
    `hush/loco_arrive`, `hush/loco_skid`, `hush/freeze_5` … `hush/freeze_8` (statues 5–8), `hush/act_glance` (the view's
    head overlay), `hush/freeze_midjob`, `hush/idle_fidget_look|proud|clarence`, `hush/st_shrug`, `hush/st_yanked`,
    `hush/act_wheeze`, `bellows/cc_wander_on` (curtain call), `bellows/cue_doorframe_bonk`, `bellows/cue_picture_bonk`
    (Prologue cue clips), `bellows/mg_<gag>` micro-gag overlays (e.g. `mg_hum`, `mg_admire_in_kettle`, `mg_walk_scale`).
    `hush/act_tinker_q|s|b` are not in the 3D manifest.
  - **Map keys:** `rig:<prank>` (derived from `rig_actions.json` for every prank: its own clip, else
    `bands.<band>.clip`; frame-locked to `rig_pm`; before `rigging@<tier>`, whose last resort is `bands.mid.clip`,
    counted as a fallback), `flavour:arrive`, `flavour:skid`, `flavour:step_down`, `state:freeze` variations
    (`freeze_1..8`).
  - **Clip events (sidecar v2, §4.11):** `decor {id, visible?, anim?}`, `set_anim {hotspot, anim}`, `set_part {hotspot,
    part, visible}`, `look {set: {<slot>: <variant>}}` (body slots), `prop {op: lend | return, prop: "set:<id>", socket?,
    frames?}` (set pieces) alongside `prop {op: attach | detach | launch | show | hide}`, `jiggle {bones, kick}`, `cam`
    op `push {zoom, frames}` (alongside `punch {zoom, in, hold, out, yaw}`); `smear` is dropped in 3D.
  - **Sim event:** `cmd_rejected {c, why: "struck", target}`. **`SimVisibility.pip_reason`:** `""`, `room`, `heading`,
    `rigging`, `adjacent`. **Solver report column:** `d1_lean`. **e2e report fields:** `hud_pieces`, `overlays`,
    `visibility` (incl. `reason`, `badge`), `pip_on_share`, `pip_longest_s`, `frame_ms_p50` / `frame_ms_p95`, `perf3d
    {draw_calls_p95, draw_calls_max, tris_max, emitters_max, tex_mb_max, shader_compiles_play}`.
  - **Settings keys:** `previews`, `room_dimming`, `outline_boost`; debug `hush_head`, `bellows_window` (`sim` | `lean`),
    `msaa_3d`, `render_scale`, `show_previews`. **`boot_config.json` keys:** `start`, `view` (`2d` | `3d`),
    `show_previews`, `bellows_window`, `render {msaa_3d, render_scale, outline}`.
  - **Set ids (`house3d.json`):** furniture `kitchen_stool` (Bellows' stool at `st_tea`, x 15.0 m, seat 0.55 m; also
    ACHOO-RIA!'s step, `step: "stool:kitchen_stool"`), landings `kitchen.sink`, `parlour.log_basket`,
    `parlour.chandelier`, `hall.coat_stand`; set pieces lent by `st_tea`: `set:kitchen_kettle` → `grip_r`,
    `set:kitchen_honey` → `grip_l`; reach bands `low | mid | high`; steps `null | "stool:<furniture>" | "mime"`;
    `view_kind` `rig | hide | take | exit | door | stairs`; `halo` `stencil | fresnel`.
  - **Shader globals:** `mnd_key_dir, mnd_key_color, mnd_key_lit, mnd_key_top, mnd_fill, mnd_fill_color, mnd_band_soft,
    mnd_rim_color, mnd_rim_power, mnd_foot_strength, mnd_foot_fade_m, mnd_lip_z, mnd_outline_scale, mnd_shadow_tint,
    mnd_bounce, mnd_sheen`. **Visual layers:** 1 `WORLD`, 2 `CHAR`, 3 `PROP_INK`, 4 `DECAL`, 5 `MAIN_ONLY`.
    **Material kinds** (`MaterialWarm3D`): `char`, `set`, `prop`, `ink`, `halo`, `decal`, `fx`.
