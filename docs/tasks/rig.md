# Stage-1 brief: `rig` — cutout rig + keyframe animation system, texture atlases, animation QA tools

The reaction animation *is the product* (GDD pillar 1). You build the machinery every animator agent will use for
months: a data-driven flat-cutout rig player that looks snappy, runs at 60 fps on a mid-range phone, and — just as
important — tools that let an AI agent **see and measure** its animation (contact sheets, onion strips, curves,
lints, GIFs). Prove it all with a geometric `_mannequin` rig.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/TECH.md` §0–§2, §4.7 (rig/poses/faces), §4.8 (clips), §5.3 (the rig system — your contract), §9 (perf),
   §10.5 (animation + rig lint rules), §11 (review tooling), §13, §14 (clip id conventions).
3. `docs/GDD.md` §9.2–§9.4 (faces, takes, timing numbers, animation list).
4. `docs/research/comedy.md` §1 (timing), §5 (runtime layers), §6 (the format), §7 (how agents check animation) —
   the canonical source for the lint rules and sheet designs.
5. Booby references to port/adapt: `/home/user/ideaboard/booby/game/view/rig_pose.gd` (flat FK, `centered = false,
   offset = -pivot`), `view/gags/noodle.gd` (springs k 220, c 10), `view/hi_res_tex.gd` (port it), and the
   `xvfb-run … --write-movie` capture approach in comedy.md §7.7.

## 2. You own
- `game/view/rig/**`, `game/view/tex/**` (`hi_res_tex.gd`, `atlas_builder.gd`)
- `game/scenes/dev/**` except `game/scenes/dev/house_preview/**` (AnimViewer lives here)
- `game/tools/anim/**` (`sheet.gd`, `lint_anim.gd`, `lint_rig.gd`, `capture.gd`)
- `tools/anim/**` (`gif.py`, `curves.py`, `contact.py` helpers — Pillow + numpy only; matplotlib is not installed)
- `tools/scripts/anim_sheet.sh`, `tools/scripts/capture.sh`
- `game/data/rigs/_mannequin/**`, `game/data/anim/_mannequin/**`, `game/art/chars/_mannequin/**`
- `game/tests/rig/**`, `docs/review/rig/`
Character rigs (`data/rigs/hush`, `data/rigs/bellows`) are being authored right now by `art-hush` and
`art-bellows` against TECH §4.7. Don't edit them; if they exist when you finish, run your rig lint and pose sheets on
them and put the results + requests in your report.

## 3. What to build
### 3.1 Pure layer (RefCounted, headless-testable, allocation-free per frame)
- `RigDef.load(path)`: parts in parent-first order, pivots, offsets, z, limits, `tex` variants, sockets,
  `draw: "limb:<id>"` bones, `limbs`, `face` slots, `residues` map, `tint`, `props`, `mirror_pairs`, `no_mirror`,
  `height_px`, feet origin. Validates (feeds the rig lint).
- `PoseLib`: resolves `base` inheritance and `mirror_of` into full pose arrays (channels `rot, x, y, sx, sy, z, tex,
  vis, alpha` per part + root `x, y, rot, sx, sy`), tags, silhouette notes, face presets.
- `ClipLib.get(id)`: parses clip JSON (TECH §4.8), resolves poses, maps `ease` names to precomputed curves
  (`linear, hold, pop`, and `in_/out_/in_out_` × `quad, cubic, quart, expo, sine, back, elastic, bounce` — match
  Godot's `Tween.interpolate_value` within 1e-4), sorts events, exposes beats/marks, `length`, `loop`, `layer`,
  `mask`, `blend_in/out`, `stride_px`, `variation`, `smear`.
- `RigSampler`: `sample(clip, frame: float, out)`; continuous channels interpolate with the *incoming* key's ease;
  discrete channels (tex, vis, z, face) step on keys; `blend(a, b, t, out)` per part with `lerp_angle`; masked
  overlays; additive layers (breathing: torso sy ±1.5 % / 3.2 s, Bellows ±2.5 % / 4 s; look-at: head ±20°, pupils
  ±3 px; shiver ±2° at 12 Hz); FK solve to part transforms from the feet origin.
- `Springs` (per-part damped springs on `rot` or `sy`, k/c/clamp from rig.json, driven by root acceleration and
  explicit kicks, fixed 60 Hz sub-steps, stable at 30–120 fps), `FaceState` (slot variants, pupils, seeded blinks
  every 2–6 s, 6 frames, 15 % doubles, suppressed during clips tagged `take`), `PropSim` (sockets, attach/detach,
  deterministic ballistic `launch` with spin and floor bounce-off), `ClipEvents.between(clip, f0, f1)`.
- **Tier / suppressed remap:** `tier 2` stretches the hold beat ×1.2, `tier 3` ×1.5 (time remap of the hold
  interval, integer-frame length exactly `frames + hold_len × (scale − 100) / 100`), T3 appends a falling-prop event
  at `t3_prop_f` and a last beat clip; `suppressed` replaces the settle beat with a given clip. Lengths must equal the
  sim's formula (TECH §3.7.4) — write a test that computes both.

### 3.2 `RigPlayer` (Node2D) — TECH §5.3 API exactly
`setup(rig_id, skin)`, `play(clip_id, opts)`, `set_external_frame(frame)` (sim-locked reactions), `set_facing(dir,
animate)` (6-frame squash turn: scale.x 1 → 0.15 → −1, swap at the midpoint; `no_mirror` parts counter-flip),
`set_face`, `set_slot`, `set_residue`, `set_tint_tier`, `set_prop_state`, `look_at`, `current_clip`, `current_frame`;
signals `clip_event`, `clip_finished`. Crossfade between clips (default 6 f; `blend_in: 0` = pose pop for
reactions). Walk clips scale playback by `speed / (stride_px / cycle_seconds)`. Smears: auto stretch along velocity
(≤ 2×) above 25°/f or 40 px/f for 1–2 f plus 2 ghost copies (alpha 0.45 / 0.25). Rubber-hose limbs: a round-capped
polyline (fill width + ink outline) through the joint positions of the `limb` bones (quadratic curve through the
elbow/knee).
- **Rendering budget: ≤ 12 draw calls per character, ≤ 0.25 ms CPU per character per frame.** Recommended: one
  CanvasItem drawing all parts from one atlas page in `_draw()` (`draw_set_transform_matrix` +
  `draw_texture_rect_region`), limbs as polylines; redraw only while animating.
- Skins: `setup("hush", "pip")` swaps textures by part name (same pivots).

### 3.3 Textures (`view/tex/`)
- `HiResTex`: port Booby `hi_res_tex.gd` (rename nothing but the header; keep `get_texture(path, swaps, scale)`,
  `warm(paths, budget_ms)`, `request`, `ART_SCALE` 2.0 / 1.5 under 3 GB RAM, scopes, cache, trim).
- `AtlasBuilder.build(key, paths, scale, swaps) -> AtlasSet` and `warm(key, paths, budget_ms) -> bool`: rasterise
  SVGs at scale (WorkerThreadPool when available), shelf-pack sorted by height with 2 px padding + 1 px edge extrude,
  pages ≤ 2048² preferred (4096² max), one `ImageTexture` per page, `AtlasSet.region(path)`, `page(path)`,
  `size_1x(path)`. All layout stays in 1× px.

### 3.4 QA tools (TECH §11 — agents will live in these)
- `tools/scripts/anim_sheet.sh <rig> <clip|--poses|--rig> <out_dir> [--scale=1.0]` → xvfb + opengl3, renders with
  the real `RigSampler`/`RigPlayer` in a SubViewport and writes `rig.png`, `poses.png` (with 50 px black
  silhouettes + a phone-scale copy), `<clip>_contact.png` (cell every 3 f + every key; keys red, holds blue; events
  printed under cells), `<clip>_onion.png` (per beat, blue→red tint, spacing dots on head top, hands, root),
  `<clip>_curves.json` (+ `tools/anim/curves.py` → `<clip>_curves.png`), `<clip>_lint.txt`.
- `game/tools/anim/lint_anim.gd` + `lint_rig.gd`: every rule in TECH §10.5 (animation + rig), each with a stable
  rule id, file, frame and message; exit code for CI (`tools/scripts/lint.sh` from `solver` will call
  `godot … -s res://tools/anim/lint_anim.gd -- --all`).
- `tools/scripts/capture.sh <res://scene.tscn> <frames> <out.gif> [-- user args]` → Movie Maker PNG sequence + WAV,
  `tools/anim/gif.py` makes a 30 fps GIF (≤ 4 MB) and a mute copy.
- `scenes/dev/AnimViewer.tscn`: choose rig + clip (user args `--rig= --clip=`), play/pause, scrub, tier 1/2/3 and
  suppressed toggles, facing flip, residue toggles; hot-reloads JSON by mtime every 0.5 s.

### 3.5 The mannequin (`_mannequin`)
A clean geometric stand-in (capsule torso, circle head with eye/mouth slots, hose arms and legs, mitten hands with
2 textures, a hat with a spring, a prop socket in the right hand) ≥ 14 parts, authored as SVG in
`game/art/chars/_mannequin/` (navy `#1B2340` 6 px outlines per GDD §9.1). ≥ 12 poses (stand, walk contact/pass ×2,
take antic/accent, crouch, reach, land squash/stretch, dazed, look back). Demo clips in `data/anim/_mannequin/`:
`loco_idle` (loop, fidget), `loco_walk` (loop, stride_px), `rx_take` (antic 12 f → pop accent 3 f + hitstop +
cam punch → 36 f moving hold → settle with one overshoot), `rx_launch` (prop launch + smear), `rx_land` (squash
0.70/1.30 → rebound 1.15/0.87 → settle). All five lint-clean; tier 2/3 and suppressed variants demonstrable in the
viewer.

## 4. Tests (`game/tests/rig/`)
Eases vs `Tween.interpolate_value` at 11 points each; hold/pop stepping; discrete channels step on keys; mirror
poses; crossfade continuity; masked overlay; additive; spring stability (no NaN, settles) at 30/60/120 fps; seeded
blink determinism; prop launch determinism; tier/suppressed lengths = TECH §3.7.4 formula for 10 random clips;
atlas packing (no overlaps, padding, regions map to 1× sizes, ≥ 90 % pack for the mannequin); each lint rule
triggers on a purpose-built bad clip in `tests/rig/fixtures/` and passes on the demo clips; perf: sample 20 parts ×
1,000 frames with zero allocations after warm-up (count via `Performance.OBJECT_COUNT` stable) and time budget; a
DevShot perf run of a scene with two mannequins → ≤ 24 draw calls.

## 5. Verify and look
```
tools/scripts/test_game.sh rig -- rig/
tools/scripts/anim_sheet.sh _mannequin rx_take  /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/rig/sheets
tools/scripts/anim_sheet.sh _mannequin --poses  /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/rig/sheets
tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 180 /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/rig/take.gif -- --rig=_mannequin --clip=rx_take
tools/scripts/shot.sh res://scenes/dev/AnimViewer.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/rig/viewer.png 60 rig -- --rig=_mannequin --clip=loco_walk
```
Read every PNG. The take must *snap*: dense spacing into the accent, a gap, a readable hold. Iterate until the
contact sheet looks like a Warner Bros take, not a floaty tween. Copy the final sheets/GIFs to `docs/review/rig/`
with `index.md`.

## 6. Acceptance
- [ ] TECH §5.3 APIs exactly; pure layer has no Node dependencies.
- [ ] All tests green; lints green on the mannequin; every rule demonstrably catches its bad fixture.
- [ ] ≤ 12 draw calls per character; sampler allocation-free.
- [ ] Sheets, onion, curves, lint, GIF, viewer screenshot in `docs/review/rig/` — looked at and described.
- [ ] If character rigs exist: rig lint + pose sheets run on them; findings reported.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/rig.md`: files, APIs, how an animator uses the tools (a 10-line recipe),
      deviations, requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/rig/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/rig.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh rig [-- filter]`, `tools/scripts/sandbox.sh rig …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] rig [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/rig/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
