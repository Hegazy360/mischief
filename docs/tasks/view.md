# Stage-1 brief: `view` — sim driver, world view, camera, FX, PiP, the Stalls, audio director

You build everything between the simulation and the player's eyes and ears: the driver that ticks the sim and
handles hit-stop and fast-forward, the side-view world with its props and glowing hotspots, the camera that frames
one floor and punches in on every payoff, the pooled comedy FX (captions, stamps, particles, noise rings, the stare
strip, the thought bubble), the Bellows-Cam picture-in-picture, the Busted Cam, the audience strip and the audio
director. It must feel **juicy and readable** and hold 60 fps on a mid-range phone.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §2.1 (the beat), §3.7 (camera: framing, follow, Gag-Cam, PiP, overview, edge bubble), §3.9
   (readability overlays — bubble, glyph, stare strip, footprints, noise rings, entry warning), §4.3 (sight ranges
   the stare strip draws), §4.6 (Busted Cam), §6.5 (laugh tiers and Stalls behaviours), §9.3 (timing numbers).
3. `docs/TECH.md` §3.4 + §3.7.1–§3.7.2 + §3.8 (what the sim exposes), §5.1–§5.8 and §5.10 (**your contract**), §9
   (perf), §13 (soft hooks), §14.
4. `docs/research/touchux.md` §3.5 (camera numbers), §6.4 (Camera2D: never use built-in smoothing), §6.5 (batching
   rules), §6.6 (PiP SubViewport code). `docs/research/comedy.md` §2 (staging and camera table).
5. Booby modules to port/adapt: `/home/user/ideaboard/booby/game/view/juice_clock.gd` (port), `camera_rig.gd`
   (concepts: exponential follow, kicks, trauma shake, real-time vs view-time), `fx_layer.gd` and
   `particle_kit.gd` (pooling patterns).

## 2. You own
- `game/view/**` **except** `game/view/rig/**` and `game/view/tex/**` (those are `rig`'s)
- `game/art/fx/**` (particle textures, caption plates, footprint and ring sprites)
- `game/tests/view/**`, `docs/review/view/`
Built in parallel by others (use **soft hooks**, TECH §13): `SimWorld` (`sim`), `RigPlayer` + `AtlasBuilder`
(`rig`), `house.json` + room/prop art (`art-house`), the Audio autoload + `cues.json` (`audio`), HUD widgets including
`PipFrame` (`ui`; you provide the viewport texture), Stalls atlas (`art-hush`, `res://data/rigs/stalls/stalls.json`).

## 3. Specs
### 3.1 `SimDriver` and `JuiceClock` (TECH §5.2)
Accumulator stepping (`rate = juice × ff × safety`, 0 when paused), max 8 ticks per frame, `ticked(events)` after each
tick, `alpha()`, `view_delta()`, `push_cmd`, `set_ff` (×3 honoured only while Hush is hidden; auto-off on
`entry_warning` for Hush's room, `prank_fire`, `spot_start`), `set_safety_slowmo`, `set_paused`, `reset`. **Never
touch `Engine.time_scale`.** `JuiceClock`: port of Booby's (freeze scale 0.05, segments merge, **cap 150 ms of freeze
per 1 s**, slow segments ease back), driven in real time; request kinds `hit_small (3 f), hit_big (5 f), hit_sig
(8 f), approach_slowmo (0.5× for 24 f), freeze_frame (45–60 f)`.

### 3.2 A view snapshot seam
Write `view/world/view_snapshot.gd`: `ViewSnapshot.from_sim(world) -> ViewSnapshot` reading only TECH §3.4 accessors
and §3.7.1–§3.7.2 fields, producing plain data (positions in px as floats, states, facing, glyph, bubble, meter %,
residues, reacting clip + frame, hotspot states, applause, link, fuse). Every view class consumes `ViewSnapshot` +
events — never the sim directly. `view/sandbox/fake_world.gd` produces the same snapshots and events from a scripted
timeline, so the whole view runs today without the sim.

### 3.3 World (TECH §5.4)
`WorldView.setup(db_or_null, episode_or_null, snapshot_source)` builds `RoomView`s from `house.json` (bg/fg layers;
locked rooms rendered as an unlit set: dimmed to ~30 % with a blue-grey tint, velvet rope at roped doorways), the stage
dressing (apron + footlight glow below the ground floor, flies above the upper floor, proscenium at the ends),
`PropView` per hotspot (state textures idle/open/rigged/spent/occupied from `art`; pre-baked outline sprite pulsing
alpha 0.6 ↔ 1.0 at 1.2 Hz for the current room; 56 px badges gold / blue / red / grey-cloud; spent = greyed), and
`CharacterView`s. **Fallbacks:** without `house.json`, build greybox rooms from GDD §7.1 widths; without `RigPlayer`,
draw a coloured capsule with a face dot and facing arrow. `CharacterView` maps snapshot state → clip via
`data/anim/<rig>/map.json` (format TECH §5.4) when it exists (written later by each rig's animation task); until then
it uses your defaults in `view/world/default_maps/<rig>.json` (a `_mannequin` map at least). Reactions are
frame-locked (`set_external_frame`); positions interpolate with `alpha()`. `hotspot_rects_in_view()` for
tap-assist.

### 3.4 Camera (TECH §5.5)
One floor fills the height at zoom 1.0 (640 + 60, ≈ 190 px of the floors above/below visible); Hush at 40–45 % width
with 12 % look-ahead; exponential smoothing τ 0.20 s (0.15 running), floor change 0.40 s ease; limits = house bounds;
`set_hold_offset` +200 px; drag pan 1:1 with fling (τ 0.25 s), hold 1.5 s, ease back 0.5 s; pinch 0.5–1.25 anchored;
overview toggle 1.0 ↔ 0.5; peek (0.35 s fly, 1.8 s hold, back); **gag queue**: one gag at a time, punch-in zoom
1.15 / 1.3 / 1.4 / 1.6 in 0.18 s on the focus, hold, ease back 0.35 s; if Hush is busy/in danger and the focus is off
screen → `PipView.escalate(true)` instead; trauma shake (12 px·trauma², 1.5°·trauma², ~25 Hz, decay 1.5/s) and
spring kicks in real time. `reduce_motion` per TECH.

### 3.5 PiP and Busted Cam (TECH §5.6, §5.7)
`PipView`: SubViewport sharing `world_2d`, own Camera2D (zoom 0.75) following Bellows, 448 × 252, updates at 30 Hz
only while visible, `canvas_cull_mask` excluding FX layer 2; `set_visible_if(cond)` with a 2 s hide delay;
`escalate(on)` 704 × 396; `get_texture()` for the HUD's `PipFrame`. Visibility rule (GDD §3.7): Bellows off-screen
**and** (within one room, heading to Hush's room, or Hush rigging) — plus any escalated gag. `BustedCam`: a view-side
ring buffer of both characters' `(room, x, facing, clip, frame)` for 120 ticks; on `caught` it re-stages the 60 ticks
from `spotted_tick` with a red vignette, split-frame border, "SPOTTED!" and a dotted line from his eyes to Hush.

### 3.6 FX (TECH §5.7) — all pooled, zero allocations after warm-up
Captions (88 px Lilita One, 6 px outline, stamp-in 1.6 → 1.0 over 4 f, 1.2 s), bonus stamps (64 px), particles
(CPUParticles2D pool: dust, flour, feathers, drops, steam, sparkles, notes, roses — ≤ 8 emitters, ≤ 300 particles,
`fixed_fps 30`, one-shot + `restart()`), tap ripple (≤ 16 ms, 0.35 s), dotted path (0.4 s), noise rings (true radius,
0.5 s, yellow for squeaks), footprints (his next 1.5 s from `bellows_path_preview`), the **stare strip** (20 px amber
band at alpha 0.35 for moving range, darker inner band at 0.55 for frozen range; red-amber and to the wall with specs
on; grey while blind), the **thought bubble** (150 × 130: next-activity icon 88 px, 10 px countdown ring, awareness
glyph 48 px, ear pips; clamped below the HUD band; progress bar for bath/nap), the "?" / "!" meter over his head,
room-entry warning FX (door-handle jiggle, legs on the stairs), T3 falling-prop sprites.

### 3.7 The Stalls (TECH §5.10)
`StallsView` on its own CanvasLayer under the HUD: 24 heads from the Stalls atlas drawn in `_draw()` (one draw call)
along the bottom-centre band, 40 px resting, rising per tier (T0 nudge, T1 bob, T2 bounce, T3 +60 px, T4 stand +
one head tumbles), shush lean, gasp jolt, "BEHIND YOU!" point, boo; alpha 0.6 at rest, 1.0 during reaction holds.
No input handling. Fallback without the atlas: simple rounded silhouettes.

### 3.8 AudioDirector (TECH §5.8)
Listens to `SimDriver.ticked` and `RigPlayer.clip_event`; maps via `data/audio/cues.json` (soft) to `Audio` calls
(soft, `has_method`); pans by screen x; attenuates by rooms between Hush and the source; laugh tier from the gag's
applause delta (T1 < 12, T2 12–24, T3 > 24 or link 2, T4 link ≥ 3 / Meltdown / signature); music state (suspense
while a "?" fills or Bellows is ≤ 2 s from an armed prank; chase in CHASE; chain section = link).

### 3.9 `ViewSandbox`
`game/view/sandbox/ViewSandbox.tscn` runs `FakeWorld` through a ~40 s scripted timeline covering every feature above.
User args `--scenario=<name>` jump to a moment for screenshots: `walk, bubble, stare_off, stare_on, squeak_rings,
entry_warning, gag_punch, captions, pip, pip_escalate, spotted, near_miss, busted_cam, stalls_t4, overview, peek`.

## 4. Tests (`game/tests/view/`)
SimDriver (with a stub world: rates, ff only while hidden and auto-off, 8-tick cap, pause, alpha); JuiceClock (cap
150 ms per second, merging); camera (frame-rate-independent smoothing at 30 vs 60 fps within 2 px; limits; floor
ease; gag queue order and one-at-a-time; PiP escalation when Hush is busy); PiP visibility rule and 2 s delay;
AudioDirector tier mapping and music-state rules on synthetic events; FX pools don't grow after warm-up
(`Performance.OBJECT_COUNT` stable over 600 frames of the sandbox); `ViewSnapshot.from_sim` against a stub world with
TECH field names (and against the real `SimWorld` + sim fixtures if they exist — soft).

## 5. Verify and look
```
tools/scripts/test_game.sh view -- view/
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/view/gag.png 60 view -- --scenario=gag_punch
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/view/x.png 1 view -- --scenario=gag_punch --shot-seq=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/view/gag_seq --every=4 --count=24
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/view/perf.png 600 view -- --scenario=pip --perf-log
```
Look at each scenario and each frame sequence. Does the punch-in *snap* with hit-stop, and is the face readable in the
hold? Is the stare strip legible but calm? Does the bubble read at a glance? Is the Stalls strip unobtrusive at rest?
Iterate, then copy finals (PNG sequences as contact strips or GIFs via `tools/anim/gif.py` if present) to
`docs/review/view/` with `index.md`. Report the perf line.

## 6. Acceptance
- [ ] TECH §5.1–§5.8, §5.10 APIs exactly; everything consumes `ViewSnapshot` + events.
- [ ] Runs today on `FakeWorld`; switches to the real `SimWorld` when present with no code changes elsewhere.
- [ ] Tests green; sandbox perf ≤ 150 draw calls p95; pools stable.
- [ ] Every scenario screenshot + the gag frame sequence looked at, in `docs/review/view/`.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/view.md`: files, APIs, fallbacks, deviations, requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/view/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/view.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh view [-- filter]`, `tools/scripts/sandbox.sh view …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] view [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/view/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
