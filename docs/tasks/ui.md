# Stage-1 brief: `ui` — UI kit, HUD widgets, touch input, panels, settings / save / haptics / router

The owner's Booby verdict included "buttons and rooms too small" and "controls were a platformer joystick". Your
job is the opposite: a two-thumb landscape HUD that is **big, calm, instantly legible and never in the way**, and a
touch layer that never misreads a tap. Every number below comes from the GDD and touch research — follow them
exactly, then look at the screenshots on a 20:9 frame and iterate until it feels like a polished console game UI
shrunk onto a phone.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §3 (all of it: gestures, the action button, Clarence/⏩, hiding + pins, hotspots, tray + pick strip,
   camera interactions, **§3.8 HUD layout table — binding sizes and positions**, §3.9 overlays, §3.10 text/haptics,
   §3.11 settings), §6.2 (Script panel and results content), §6.4 (Figgis hint ladder).
3. `docs/TECH.md` §5.9 (HudModel + intents), §6 (input model), §7 (save + settings), §13, §14.
4. `docs/research/touchux.md` §1 (physical constants), §3 (gesture grammar), §5 (safe areas), §6.2–§6.3 (safe-area
   helper and the `InputRouter` reference code — start from it).
5. Booby modules to port (rename, adapt to landscape; drop everything online/social):
   `/home/user/ideaboard/booby/game/autoload/{settings,haptics,router}.gd`,
   `autoload/support/{safe_area,ui_scale,fade_transition}.gd`, fonts `game/ui/fonts/{LilitaOne-Regular,
   Nunito-ExtraBold,Nunito-Bold,Nunito-Black}.ttf` (OFL — include the OFL license text as
   `game/ui/theme/fonts/OFL.txt`), and `ui/ui_kit.gd` for patterns only.

## 2. You own
- `game/ui/**` (theme, fonts, `input/`, `widgets/`, `panels/`, `hud.gd`, `hud_model.gd`, `demo/`)
- `game/art/ui/**` (HUD/verb icons, awareness glyphs, badges, stars, tomato, rose, candle, ribbon, wax seal)
- `game/autoload/{settings,save,haptics,router}.gd`, `game/autoload/support/**`
- `game/data/ui/strings.json`
- `game/tests/ui/**`, `docs/review/ui/`
Autoloads are registered in `project.godot` by the orchestrator after Stage 1; your tests instantiate the scripts
directly. The `view` task renders world-space things (bubble, stare strip, captions, badges placement) and the PiP
viewport texture — you supply the **icons** they use (badges, glyphs) and the **`PipFrame`** widget that shows the
texture. Item and activity icons come from `art-house` (`res://art/house/items/*.svg`, `res://art/icons/activities/
*.svg`); load them softly with a neutral fallback.

## 3. Specs
### 3.1 Theme and text
Lilita One for display (numbers, captions, titles), Nunito ExtraBold for UI text. Sizes: ≥ 36 px anywhere, 44 px
for anything read during play, 48–56 px HUD numbers, 80–96 px titles; 4–6 px navy `#1B2340` outline on anything over
the world. MSDF font import. Buttons: chunky rounded rectangles/circles, 6 px navy outline, one flat shade, pressed
state = 0.94 scale + darker shade in ≤ 16 ms. Palette: cream `#FFF4E0`, navy `#1B2340`, cherry `#E23B4E`, brass
`#D9A441`, curtain red `#B3122E`, stage gold `#E8B33A`.

### 3.2 Widgets (sizes/positions exactly GDD §3.8; anchored to the safe-area corners)
- **ActionButton** — custom Control reading `InputEventScreenTouch/Drag` by index; 240 px hit circle, 190 px visual;
  verbs `RIG` (item icon → target icon), `RIG_DIM` (silhouette, tap = intent), `FREEZE` (statue icon — persistent),
  `POP_OUT` (rim green/amber/red), `GO` (▶ with pin). **Latch the verb at touch-down**; a verb change is shown only
  after the current verb has been visible ≥ 250 ms (120 ms cross-fade) and never while pressed. Ring: 14 px arc from
  12 o'clock, yellow → green, 3 Hz pulse in the last 20 %, completion pop 1.0 → 1.18 → 1.0 over 180 ms. Slide > 80 px
  off = cancel. Emits `action_down(verb)`, `action_up(verb, cancelled)`. Arrival pop 1.08×. Tap-to-rig setting: toggle
  semantics.
- **ClarenceButton** — 168 hit / 128 visual; modes `SQUEAK` (a mini Clarence that squashes on press) and `FF` (⏩);
  tap (< 500 ms) vs hold (≥ 500 ms); a press starting within 150 ms of an action press is ignored (the Hud tracks the
  last action-down time); 8 px lure ring that greys when `lure_grey`. Emits `clarence_down()`, `clarence_up(held_ms)`.
- **Tray** — 4 slots, 168 hit / 128 visual, 24 px gaps; the highlighted slot rises 12 px and glows; tap → `tray_tap(i)`;
  optional drag → `tray_drag(i, screen_pos)` on release.
- **ApplauseMeter** — 600 × 132 brass panel: a 120 px dial with a sprung needle, the Applause number (56 px, counts
  up), the Script counter "3/5" (48 px), 3 × 44 px tomatoes (splat when used; hidden when unlimited), ENCORE sparkle
  above 100. Tap → `meter_tap()`.
- **RunningGagBanner** — "RUNNING GAG ×1.5" (52 px) + a 420 × 18 fuse bar draining; pops 1.2 → 1.0 on a new link;
  IGNORE mouse filter.
- **FiggisChip** — 144 hit / 128 visual at top-left beside pause; states idle, `pulse` ("psst" bubble), `card` (a
  cue card of 2–3 icons + arrow for 4 s), `ghost` (step 3 armed); tap → `figgis_tap()`.
- **PipFrame** — 448 × 252 (escalated 704 × 396) frame with a `set_texture(tex)` slot, 6 px border coloured by
  temper tier (calm cream, irked pink, steaming red, livid beetroot), the awareness glyph in a corner; tap →
  `pip_tap()`.
- **EdgeBubble** — 112 px face circle + 36 px label at a screen edge (from the model); 144 hit; tap → `pip_tap()`.
- **PickStrip** — 144 px item icons with 24 px gaps at a screen point from the model; 3 s timeout; tap → `pick(item)`.
- **PauseButton**, **OverviewButton** — 144 hit / 112 visual.
- Everything that is not a target (`RunningGagBanner`, labels, full-screen containers) uses `MOUSE_FILTER_IGNORE`.
  The **bottom-centre band** (x from S+800 to W−S−312) holds no targets.

### 3.3 `HudModel` and `Hud`
Exactly TECH §5.9 fields; `Hud.apply(model)` is idempotent and allocation-free (no string formatting unless a value
changed). `Hud` exposes every intent signal listed in TECH §5.9 plus `tray_drag`. Left-handed mode mirrors the two
clusters (tray + Clarence ↔ action button) and swaps top corners' pause/Figgis with PiP/overview.

### 3.4 Panels
`ScriptPanel` (1000 × 680; 84 px rows; 44 px text; 72 px icons; ribbons on required lines; "???" undiscovered; beret
stamp = rigged; tick stamp = done; a wax-sealed Big Number; candle icons; his loop as an activity-icon strip along the
bottom with rigged stations stamped; opening pauses), `PauseMenu` (Resume, Retry, Take a Bow (only when ★),
Settings, Playbill; 96 px-tall buttons), `SettingsPanel` (every GDD §3.11 setting; sliders/toggles ≥ 144 px hit),
`LoadingCard` (curtain backdrop, one 160 px icon, the ≤ 25-word rule at 52 px, "tap to start" after 1 s, auto 4 s),
`ResultsScreen` skeleton (curtain-call layout: 3 × 160 px Curtain Call stamps, Applause count-up, the why-missed line
at 44 px, a Gag Reel slot rect, "+NEW!" chips, buttons **Next Night ▶** 240 px default, Retry, Playbill). All text
from `data/ui/strings.json`.

### 3.5 Input (`ui/input/`)
- `InputRouter` (Node2D, `_unhandled_input`): signals `tapped(world_pos, is_double)`, `long_pressed(world_pos)`,
  `long_released(world_pos)`, `pan(screen_delta)`, `pinch(factor, mid)`. Constants in `gesture_config.gd`: slop 24,
  tap 300 ms, double 280 ms / 64 px (the first tap is emitted immediately), long 450 ms, pinch 32 px, **edge exclusion
  48 px** (drags starting there are ignored), mouse events ignored (desktop testing via `emulate_touch_from_mouse`).
- `TapAssist.resolve(world_pos, candidates, zoom) -> Dictionary` — exact hit first; else the nearest candidate within
  90 screen px (90 / zoom world px); priority hotspot > door/stairs > floor; floor → `{c: "move", room, x}`.
  Candidates are `{id, kind, rect (world), room, priority}`.

### 3.6 Autoloads (ports)
- `Settings` → `user://settings.cfg`, keys exactly TECH §7 with defaults; signal `changed(key, value)`; debounced
  save.
- `Save` (new) → `user://save.json`, TECH §7 schema and API; atomic `.tmp` + rename; version migration; corrupted file
  → backup + fresh.
- `Haptics` → named pulses `tap (8 ms/0.3)`, `ring_half (8)`, `rig_done (30/0.7)`, `accent (40+60)`,
  `near_miss (20)`, `caught (3×30)`, `stomp (60)`, `ui (8)`; rate limit ≤ 6/s; respects Settings; no-op on desktop
  unless `force_enabled` (tests).
- `Router` → routes `boot`, `night`, `playbill` (a generated "coming soon" screen until Stage 4); transitions `fade`
  and `curtain` (drop/rise using `res://art/house/stage/curtain.svg` via a soft load, fade fallback); Android back →
  current scene `handle_back()`; `setup(params)` before `_ready`.
- `support/safe_area.gd` (symmetric sides, re-query on resize/resume/focus and every 0.5 s, dev flag
  `--safe-area=L,T,R,B`), `ui_scale.gd` (×0.8 when logical height > 1250), `fade_transition.gd`.

### 3.7 `UiDemo`
`game/ui/demo/UiDemo.tscn` shows the full HUD over a neutral backdrop driven by a scripted fake `HudModel`; user args
`--state=<name>` (e.g. `rig_0, rig_50, rig_100, rig_dim, freeze, pop_green, pop_amber, pop_red, go, ff, lure_grey,
tray_highlight, figgis_pulse, figgis_card, pip_steaming, edge_bubble, pick_strip, script, pause, settings, loading,
results, encore`), `--left-handed`, `--safe-area=162,0,162,58`, `--cycle` (steps through all states for a frame
sequence).

## 4. Tests (`game/tests/ui/`)
Gesture classification (tap / double / long / drag / pinch thresholds; first tap never delayed; edge exclusion;
mouse ignored); TapAssist (exact hit, 90 px assist scaled by zoom, priorities, floor fallback); ActionButton (latch at
touch-down, 250 ms hysteresis, slide-off cancel, tap-to-rig toggles, ring timing callbacks); ClarenceButton (tap vs
hold at 500 ms, 150 ms suppression, FF mode); layout (every target's hit rect ≥ spec, ≥ 24 px apart, none inside the
bottom-centre band, all inside the safe area + 32 px, at 1920×1080, 2400×1080, 1920×1440 and with 162 px insets;
left-handed mirror); Save (atomic write, reload, migration, corrupt file); Settings persistence; Haptics rate limit;
Hud.apply idempotence (two identical applies change nothing).

## 5. Verify and look
```
tools/scripts/test_game.sh ui -- ui/
tools/scripts/shot.sh res://ui/demo/UiDemo.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/ui/rig_50.png 30 ui -- --state=rig_50
SHOT_SIZE=960x540 tools/scripts/shot.sh res://ui/demo/UiDemo.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/ui/16x9.png 30 ui -- --state=freeze
SHOT_SIZE=1080x810 tools/scripts/shot.sh res://ui/demo/UiDemo.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/ui/4x3.png 30 ui -- --state=script
tools/scripts/shot.sh res://ui/demo/UiDemo.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/ui/notch.png 30 ui -- --state=pop_red --safe-area=162,0,162,58 --left-handed
```
Look at every state. Is the world area calm and uncluttered? Are thumb targets obviously tappable? Is every number
readable at arm's length (judge the 1200×540 image at 100 %)? Iterate, then copy the finals to `docs/review/ui/` with
`index.md`.

## 6. Acceptance
- [ ] Every widget, panel and autoload above, with TECH §5.9/§6/§7 APIs exactly.
- [ ] All tests green; the layout test proves the GDD sizes, gaps, safe-area anchoring and the free bottom-centre.
- [ ] Screenshots of every state at 20:9, 16:9, 4:3, notched, left-handed — looked at, in `docs/review/ui/`.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/ui.md`: files, intent/API list, deviations, requests (e.g. to `view` for
      screen positions of the pick strip/edge bubble, to the orchestrator for autoload registration).

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/ui/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/ui.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh ui [-- filter]`, `tools/scripts/sandbox.sh ui …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] ui [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/ui/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
