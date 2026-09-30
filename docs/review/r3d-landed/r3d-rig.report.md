# r3d-rig report: the 3D character runtime and the animators' review tools

**Status: done.**

Timeline (UTC):
- 16:20: launched.
- 17:12: P0 landed and announced (0.9 h, within the 3 h limit).
- 17:14: P1a, RigSampler3D.
- 17:28: P1, the full player and tools.
- 18:16: finish.

Final check: the full suite has **1376 passed, 0 failed, 1 skipped**, and rig3d passes 46/46 with no leaks. `lint.sh` exits 1, and the only error is in r3d-anim's area (see §4). Every render cited here and in `docs/review/r3d-rig/` was looked at.

I touched only §2 paths: `game/view3d/char/**`, `game/scenes/dev/anim3d/**`, `game/tools/anim3d/**`, `tools/anim/sheet3d.py`, `tools/scripts/{anim_sheet3d,capture}.sh`, `game/tests/rig3d/**` and `docs/review/r3d-rig/`. I ran no git write commands. Godot ran only through `sandbox.sh`, `test_game.sh`, `shot.sh`, `capture.sh`, `anim_sheet3d.sh` and `lint.sh`, one process at a time, in the `r3d-rig` and `r3d-rig-shot` sandboxes.

## 1. Files built

**Runtime (`game/view3d/char/`)**
- `rig_def_3d.gd`: `RigDef3D`, the §7.3 descriptor.
  - Parses and validates it against the instantiated scene (bones, parents, rests).
  - Errors are formatted `<file>: <key>: <what>`.
  - Descriptors are cached. A `pip` variant falls back to base (R7).
- `clip_def_3d.gd`: `ClipDef3D`, the typed §7.2 v2 sidecar. Events are sorted, with `clip`, `rig` and `f` added. It also carries marks, beats and the face timeline.
- `clip_lib_3d.gd`: `ClipLib3D`, a lazy cache of clips.
  - Maps `hush/loco_walk` → `data/anim/hush3d/loco_walk.json` + `art3d/anim/hush/loco_walk.res`, and sets loop mode from the sidecar.
  - Hot-reloads on mtime.
  - `load_glb_action` loads dev look-dev actions.
- `clip_events_3d.gd`: `ClipEvents3D`. Returns events with f0 < f ≤ f1, with loop wrap.
- `play_plan_3d.gd`: `PlayPlan3D`, a port of `play_plan.gd`. Handles the T2/T3 hold stretch, the T3 last beat, the suppressed settle and rig-progress frames.
- `face_cards_3d.gd`: `FaceCards3D`, the face driver.
  - 8 layer slots and presets.
  - The clip timeline wins over the view's preset.
  - Seeded blinks, mirror cells, and pupils driven from look-at.
- `rig_player_3d.gd`: `RigPlayer3D`, the §7.1 player.
- `rig_mods_3d.gd`: `RigMods3D`, a `SkeletonModifier3D`.
  - Handles prop states, sockets and flight.
  - Scales hidden bones (looks, slots, extras) to ≈ 0.
  - Applies the tint-tier bone scale.
- `rig_jiggle_clamp_3d.gd`: `RigJiggleClamp3D`. Holds each spring within `clamp_deg` of its animated pose.
- `prop_sim_3d.gd`: `PropSim3D`, a closed-form ballistic path (gravity 9.8 × 1.6, bounce 0.3, friction 0.6, spin halves per bounce).
- `char_stand_in_3d.gd`: the capsule stand-in used when a descriptor is broken.
- `rig_sampler_3d.gd`: `RigSampler3D`, the headless sampler for the lint and the tests.

**Dev scenes (`game/scenes/dev/anim3d/`)**
- `AnimViewer3D.tscn` + `anim_viewer_3d.gd` (flags in §3).
- `RigPerf3D.tscn` + `rig_perf_3d.gd`.

**Tools**
- `game/tools/anim3d/sheet3d.gd`: renders the clip, turntable and faces frames with RigPlayer3D.
- `game/tools/anim3d/capture3d.gd`: the Movie Maker hook, with duck-typed `clip_event`.
- `game/tools/anim3d/rig_profile3d.gd`: `RigProfile3D`.
- `tools/anim/sheet3d.py`: the composer.
- `tools/scripts/anim_sheet3d.sh`: new.
- `tools/scripts/capture.sh`: `-s` now points at `res://tools/anim3d/capture3d.gd`.

**Tests (`game/tests/rig3d/`)**
- 7 files, 46 tests.
- `fixtures/`:
  - The generator `make_fixtures.gd` makes a 27-bone skinned box rig with palette and face UV2, 3 attachment scenes and 7 baked clips.
  - Data files for the rig, head_b variant, faces, sidecars and reactions.
  - `fix_env.gd` pushes and pops the data roots.

**Review**
- `docs/review/r3d-rig/index.md` + 22 artefacts (≈ 6.5 MB).

## 2. API as built (the contract others use)

**`RigPlayer3D extends Node3D`.** Everything in index §7.1 exists with the signatures given there:
- `setup`, `play`, `play_overlay`, `stop_overlay`, `set_external_frame`, `release_external`.
- `set_facing`, `set_cheat`, `set_face`, `set_slot`, `look_at_point`.
- `set_look`, `set_body_slot`, `reset`, `set_tint_tier`, `set_stone`, `set_prop`, `attach`, `detach`.
- `socket_global`, `head_global`, `top_global`, `feet_global`, `screen_aabb`.
- `current_clip`, `current_frame`, `has_clip`, `clip_length`, `set_outline_scale`, `warm`, `counts`.
- The signals `clip_event(ev)` and `clip_finished(clip_id)`.

`play` opts: `blend_in`, `speed`, `loop`, `start_frame`, `tier`, `suppressed`, `seed`. Also `hold`, `suppressed_clip`, `last_beat`, `t3_prop_f` and `t3_prop` (overrides; normally they come from `reactions.json`).

**Additions (optional to use):**
- Clock and playback:
  - `@export auto_advance := true` and `advance(view_dt)`. With `auto_advance = false`, the view drives the player on its own (hit-stopped) clock.
  - `is_external()`.
  - `set_speed(m_s)`: rate = m_s / clip `speed_m_s`.
  - `plan() -> PlayPlan3D`.
- Facing: `body_yaw()`, and `static yaw_for(dir, cheat)` (right = 90 − cheat, left = −90 + cheat).
- Jiggle: `reset_jiggle()`, `kick_jiggle(k)`.
- Looks and body slots: `has_look`, `body_slot(slot)`, `body_slot_owner(slot) -> &"clip" | &"residue" | &""`, and `reset(clear_residues := false)`.
- Material state:
  - `static tint_uniform(def, tier) -> Color`, `tint_tier()`.
  - `stone_amount()`, `flash(color, s := 0.15)`.
  - `set_stage_light(level, desat := 0.0)`, `material() -> ShaderMaterial`.
- Props and sockets:
  - `prop_state(id)`.
  - `launch_prop(id, vel, spin_deg, at_f := -1)`. `vel` is in m/s; x is mirrored by facing.
  - `socket_node(socket) -> Node3D`, for set pieces lent by `House3D.lend`.
  - `attach(node, socket, keep_world := false)`.
- `ok`, `rig_id`, `variant`, `def`, `skeleton`, `face`, `facing` are readable.

**Rules for the view (`CharacterView3D` already follows them):**
- Position the RigPlayer3D node. The player yaws its own child `Body`: never rotate the node for facing.
- Call `advance(dt)` every frame, whether through `auto_advance` or yourself. The skeleton's modifiers run in MANUAL mode inside it, so a hit-stop also freezes springs and look-at.
- Under frame-lock, `set_external_frame(sim_timeline_frame)` takes the tier-remapped timeline frame, i.e. the sim's frames.
- Events fire after that frame's pose is applied, so a launched prop leaves from the hand's position on that frame.
- The player handles and still emits `face`, `look`, `prop` and `jiggle` events. `prop` events on `set:<id>` are emitted only.
- Body slots: a clip's `look {set:…}` owns the slot until the release frame (`marks.release`, else the clip's end). After that the residue wins. `reset()` clears clip-owned slots, re-attaches launched props and resets jiggle.
- An unknown slot, variant or prop gives `push_error("RigPlayer3D(<rig>): … (clip <id>)")`.

**Pure layer (headless):**
- `RigDef3D`:
  - `RigDef3D.load(rig_id, variant := "")`, `exists`, `invalidate`.
  - Helpers `bone(role)`, `cell_index(layer, cell)`, `mirrored(layer, cell)`, `tint_color(tier)`, `cheat_deg(kind)`.
  - `static var search_roots := ["res://data"]`.
- `ClipLib3D`:
  - `get_clip(id) -> ClipDef3D`, `exists`, `animation(id)`, `length`, `clips_of(rig)`.
  - `register(def, anim)`, `reload_if_changed`, `problems(id)`.
  - `load_glb_action(rig, path, name) -> "<rig>/glb_<name>"`.
- `ClipEvents3D.between(clip, f0, f1)`.
- `PlayPlan3D.build(clip, opts)` and `sim_length(frames, hold, tier, suppressed)`.
- `PropSim3D.pose_at(start, vel, spin, t, floor_y)`.

**`RigSampler3D`** (for r3d-anim's lint):
- `RigSampler3D.sample(rig, clip, frame) -> {local_rot, local_pos, global_pos}`.
- Or `RigSampler3D.for_rig(rig).pose_at(clip, f)`, then:
  - `global_pos(bone[, f])`, `global_xf`, `local_rot`, `local_pos`.
  - `angle_delta_deg(bone, f0, f1)`, `height(bone[, f])`, `aabb([f])`.
- Globals are in MODEL space: the rig root frame, +y up, facing +z.
- It matches the live player within 1 mm (test). 100 frames take less than 5 ms (test).
- It needs the SceneTree, because it adds a hidden instance under root.

**Descriptor fields honoured beyond §7.3** (the cast use these already):
- `face.default`, and nested `face.mirror_cells {layer: {cell: cell}}`.
- `face.blink.hide_layers`, `face.mirror_pupil_x`.
- `slot_parts.<slot>.hide_bones`, and `hidden_bones` (scale 0 unless the playing clip keys that bone's scale or the prop is shown).
- `props.<id>.hides`, `attachments.<id>.soft` (a missing scene gives a warning and is skipped), `attachments.<id>.socket`.
- `looks.<id>.face_extra`, `tint.livid_specs`.
- `tint.skin`: new and optional, the skin colour the tier multiply colours act on (default #E9B79A).

**char_toon uniforms set** (r3d-view3d's shader; the player doesn't change it):
- `palette`, `face_atlas`, `face_grid`, `face_cell_a/b`.
- `face_rect[6]` (the descriptor's `layer_rects`), `pupil_offset`, `pupil_range`.
- `tint_color`: tiers 1–3 = `tint.skin` × the tier colour, livid = `tint.livid`, alpha 1; tier 0 = alpha 0.
- `stone`, `stone_color`, `flash` (+ colour), `rim`, `stage_light`, `desat`, `albedo_color`.
- `vc_masks`: false when a mesh has no vertex colours.

Outlines and materials:
- The outline is a `next_pass` with `outline_px` = the descriptor value (Hush 4.8, Bellows 3.5) × `set_outline_scale(k)`.
- Attachments get a copy of the character material with the face cells off. A white, untextured material keeps the rig palette (the cast's palette-UV convention); a coloured one draws flat.
- All materials are registered via `MaterialWarm3D.register(mat, &"char")`. Meshes are on visual layer CHAR (bit 2) and cast no shadow.

## 3. Tools

**AnimViewer3D (`--help`)**
- Rig and clip: `--rig`, `--variant`, `--clip`, `--pose=rest`, `--anim-glb`/`--anim-name`, `--frame`, `--play`, `--speed`, `--tier`, `--suppressed`, `--overlay`/`--mask`.
- Camera: `--cam=game|front|q34|side|back|face|turn`, `--dist`, `--cam-y`.
- Character state: `--face`, `--looks`, `--slot`, `--prop`, `--tint=0..4`, `--stone`, `--facing`, `--cheat`, `--look-at`.
- Scene: `--room`, `--x`, `--z`, `--episode` (House3D, soft).
- Second rig: `--rig2`, `--clip2`, `--x2`, `--facing2`, `--frame2`.
- Scripted actions: `--then=<clip>|glb:<action>` with `--then-at`/`--then-blend`, `--flip-every`, `--launch=<prop>@<f>[:v]`, `--stone-at`.
- Output: `--events`, `--sound`, `--data-root`, `--clean`, plus the DevShot flags.
- Sidecars hot-reload every 0.5 s.

**`anim_sheet3d.sh <rig> <clip> <out> [--room --cam --tier --suppressed]`** writes:
- `_contact.png`: a cell every 3 f plus every beat boundary; beats outlined anticipation blue / accent red / hold grey / settle teal; events under their cells.
- `_onion.png`: blue → red, with dots on head top, hands and pelvis.
- `_curves.json` and `.png`.
- `_sil64.png`, via review/sil64.py.
- `_phone.jpg`: 1× crops of the 1200×540 framing every 3 f, via review/strip.py.
- `_lint.txt`: r3d-anim's `lint_anim.gd --format=3d`, run in the same imported sandbox.

Also `--turntable` (front / 3/4 / side / back) and `--faces` (every preset at 3×). Runs sharing a sandbox are locked with `flock`.

**`capture.sh`** runs `capture3d.gd`, which logs every node that has a `clip_event` signal (RigPlayer3D and the 2D RigPlayer). Its log rows carry `rig`, and `hooked_players` is in the summary.

**`RigPerf3D.tscn`**
- Flags: `--rig`, `--clip`|`--anim-glb`, `--variant`, `--perf-log`.
- 600 frames in two phases, skin bound and unbound.
- Prints one `[rigperf3d]` JSON line: µs median/p95/max, with and without skinning, draw calls, primitives, bones, deform bones, tris, and loadavg.

## 4. Verification

| Check | Command | Result |
|---|---|---|
| Full suite | `tools/scripts/test_game.sh r3d-rig` | **1376 passed, 0 failed, 1 skipped** (1377 tests / 155 files). The skip is `cast3d/test_bellows3d::test_portraits_exist`, which waits on AnimViewer3D; `--cam=face` exists now. An earlier run had 4 failures in other areas (set3d ×2, solver p00 fuzz, view3d slice_clips); all were fixed by their owners before this run. |
| rig3d | `test_game.sh r3d-rig -- rig3d/` | 46/46 in 17 s, 0 leaked objects |
| Lint | `SANDBOX=r3d-rig tools/scripts/lint.sh` | Exit 1. content, hotspot and ip are OK. 2D lint_anim: 41 clips, 0 errors. **3D lint: 1 error in r3d-anim's area:** `hush3d/rig_achoo_ria.json:f7 upperarm_r jumps 48°/f without a pop (L10_pop_jump)`. The rest are coverage WARN/INFO (70 of 77 g0/p00 3D clips are not baked yet). r3d-anim's own forward kinematics produces this, not the sampler. |
| RigPerf3D Hush | `shot.sh …RigPerf3D.tscn … --rig=hush --clip=hush/loco_walk --perf-log`, ×5 | Medians 188 / 192 / 190 / 186 / 189 µs (p95 ≈ 275–299); 182–206 µs with skinning. 9,838 tris, 79 bones, 48 deform bones, **2 draw calls**. |
| RigPerf3D Bellows | the same, `--anim-glb=look-toy/bellows_toy.glb --anim-name=Toy_Sneeze`, ×3 | Medians 186 / 187 / 189 µs (p95 245–273); 185–194 µs with skinning. 9,947 tris, 90 bones, 57 deform bones, **2 draw calls**. |
| Budget | test_perf_3d | ≤ 250 µs: **within budget on both rigs**, measured on a box at load average 5–6 on 4 cores (the headless test measures 28 µs on hush/loco_arrive). No objects are created per frame over 300 frames. `warm()` is ≤ 20 ms. ≤ 4 draw calls and ≤ 10k tris on both cast rigs. |

Test coverage: every §5 item has a test.
- Descriptor rules: one broken fixture per rule, and the real cast descriptors.
- ClipLib3D: parse, path, loop mode.
- PlayPlan3D: the 2D `test_tier` cases with exact frames.
- Frame-lock: `set_external_frame(92)` shows exactly frame 92, with no drift after 300 frames.
- Yaw math and the 6-frame turn.
- Face: preset → cells, timeline wins, seeded and suppressed blinks, mirror.
- Events: wrap and tier remap, never twice.
- Props: attach/detach keep world transforms, launch is deterministic, reset re-attaches, props resolve before attachments, `set:` ids are emitted only.
- Looks: attachments, bones, params.
- **Body slots: the Bellows sneeze sequence** (neat → flipped at f94, clip-owned → residue BLINDED keeps flipped → reset → neat; a residue during the clip does not override it).
- Tint and stone uniforms; the stand-in; the masked overlay.
- Look-at limits; spring swing, settle and clamp.
- Sampler vs live player within 1 mm; the perf budget.

Looked at (all in `docs/review/r3d-rig/`):
- Faces boards for both rigs: 26 and 45 presets, all resolve.
- Turntables.
- Bellows in the kitchen at base framing: 242 px tall vs the 236 px spec.
- The turn: through the camera side, no pop, the face never edge-on.
- Marble: beret and braces keep their colour, the outline stays.
- Tint tiers and livid with specs.
- Look-at.
- Walk → idle cross-fade: no pop, the springs settle.
- Teacup launch arc: leaves from the hand, bounces, rests, and does not snap home on the loop wrap.
- Hush's socket attachments.
- r3d-anim's `hush/loco_walk` through all the sheets.
- Capture (`capture/hush_walk.gif`): the event log matches the movie frames (clip f 27 = movie f 27).

## 5. 2D logic ports
- `play_plan.gd` → `PlayPlan3D`: the same hold stretch (T2 ×1.2, T3 ×1.5 + last beat) and suppressed tail; lengths equal the sim formula for random clips (test).
- `face_state` → `FaceCards3D`: xorshift blinks, suppressed during the hold, mirror cells.
- `prop_sim` → `PropSim3D`, now in metres.
- `clip_events` → `ClipEvents3D`.
- The reaction-table lookups → `PlayPlan3D.entry_for_clip`, `suppressed_for`, `last_beats_for` (`static var reaction_files`).
- `capture.gd` → `capture3d.gd`. The 2D file is untouched, and `capture.sh` no longer references it.

## 6. Deviations
- **No `breath` layer.** It was optional (Bellows' belly ±2.5 %). RigMods3D is the place for it if it's wanted.
- **The skeleton's modifiers run in MANUAL mode inside `advance()`** instead of on the engine's process step: RigMods3D → LookAtModifier3D → SpringBoneSimulator3D → RigJiggleClamp3D. This keeps them on the view's clock and makes tests deterministic, and tests must `await process_frame` before reading a pose.
- **Extra `RigJiggleClamp3D`** implements the descriptor's `clamp_deg`, which SpringBoneSimulator3D does not have.
- **`load_glb_action` drops scale tracks.** Look-dev actions key props at scale 0, and the rig's prop states should decide visibility. This is dev only; baked `.res` clips keep their tracks.
- **Mask `face`** plays only the overlay's face timeline. There are no bone tracks.
- **Launched props fly on the view clock**, except for a frame-locked, non-looping reaction, which uses a closed form in clip frames so that seek and replay match.

## 7. Requests
- **r3d-cast-hush:**
  - **Bug (new this batch):** `carry_squeaker.glb`, `carry_kipper.glb`, `tomato_splat.glb`, `tag_beret.glb` and `plinth.glb` have only the four 0/1 corner values in `TEXCOORD_0` (checked by decoding the glbs), not palette-cell UVs. `carry_magnifier` has 20 values, which also doesn't look like palette cells. Every face therefore samples all of `palette_hush.png`, including its unused magenta half. See `docs/review/r3d-rig/attachments_hush.png`. Suspect the `uv_layers.new(name="UVMap")` in `tools/art3d/hush/props.py::to_object` clashing with a UV map the primitives already have, so the default one is exported. The body glb is fine.
  - The `face` socket (used by the faces board and `--cam=face`) and `carry_1`/`carry_2` now work. Carry attachments were dropped at setup before this landing.
- **r3d-cast-bellows:**
  - `deform_bones` is 49 in the descriptor, but 57 bones carry weight > 0 in `bellows.glb`. Either correct the number or drop the stray weights.
  - `material.outline_px` is 3.5, but the lead note (D7, look A) says characters get 4.8 px @1080 (Hush's descriptor has 4.8). Raise it, or say why Bellows differs.
  - `tint.skin` is optional; set it if the skin isn't #E9B79A.
  - Portraits can now be rendered: `AnimViewer3D --rig=bellows --cam=face --face=<preset> --clean`.
  - The stool attachment stays soft until r3d-sets' `stool.glb` exists.
- **r3d-anim:**
  - `rig_achoo_ria.json` f7 fails L10: a 48–51°/f arm jump without a pop.
  - The loco_walk curves show a ~15°/f foot-rotation step at the plants (f 26 / 53). That's your call.
  - `anim_sheet3d.sh` runs your lint for every clip sheet.
  - `RigSampler3D`'s API is in §2.
  - A Bellows baked clip is needed for a true Bellows perf number.
- **r3d-view3d:**
  - Tint semantics: the player sets `tint_color` = skin × tier colour with alpha 1, and the shader MIXes it by alpha on the skin mask. Confirm this is the intended meaning.
  - Outline: the player sets `outline_px` = descriptor × `set_outline_scale(k)`, and the shader also multiplies by the global `mnd_outline_scale`. Settings "Outline +50 %" should use exactly one of the two, or it compounds.
  - `CharacterView3D` already sets `auto_advance = false` and calls `advance()`. Keep calling it every frame, including during hit-stop with dt = 0.
- **Orchestrator (R13):**
  - `.uid` sidecars are needed for my 26 new `.gd` files, from the import-meta step.
  - Fixture `.tscn` and `.tres` files are under `game/tests/rig3d/fixtures/`.
  - I created no hand-written `.import` or `.uid` files, and nothing needs non-default import settings.
- **r3d-integrate:** the 2D `game/tools/anim/capture.gd` is no longer referenced by `capture.sh`, so your scan can delete it.

## 8. Known gaps
- **Bellows has no baked clip yet.** Its perf number is on look A's `Toy_Sneeze` action through `load_glb_action`.
- **Capture of the real 3D game with characters is not verified yet.** Boot → StageDoor captured 600 frames with 0 RigPlayer3D hooked, because that path has no 3D characters. The 3D NightScene is r3d-night's. The hook itself is proven on AnimViewer3D (`hooked_players` 1, 14 events). The WAV had no onsets because `--sound` came later.
- **The feet-never-slide check at 2.0 / 3.6 / 1.2 / 3.0 m/s is not measured.** Only `set_speed`'s rate math is tested, because there is one walk clip so far.
- **The RigPerf numbers were taken on a loaded box** (load average 5–7). The medians have headroom (≈ 190 of 250 µs), but should be re-measured quiet or on a device.
- **Face readability at game scale depends on the cast's atlases** (lead note D7: cells of 256–340 px). The player places whatever grid the descriptor declares.

## 9. Hours
About 2.0 h wall-clock, 16:20–18:20 UTC. P0 took 0.9 h.

---

# Fix pass addendum (2026-09-30 21:26–21:57Z, about 0.5 h of the 2 h box)

**Status: done.** Everything in the brief's three priorities landed and was checked:
- the D8 runtime gaze;
- the set and props attachment palette;
- the sheet crash, the stepped phone framing, `--fixed-step` and the single outline path.

I touched only my own files. Godot ran only through the slot-wrapped scripts, one process at a time, in the `r3d-rig` and `r3d-rig-shot` sandboxes.

## 1. D8: the sidecar `gaze` is honoured

**What it does.** Inside `[f0, f1]` of the playing clip, the face turns to the active camera. `blend` defaults to 6 frames.
- It works for both base and overlay clips.
- It turns about the vertical only. The yaw is shared the same way as the clips' own `face_cam`: spine_02 0.15, spine_03 0.15, neck 0.25, head 0.45. The keyed pitch and roll stay.
- It works for either facing.
- It runs after RigMods3D and the look-at, and before the springs and the jiggle clamp. The beret stays within `clamp_deg` (tested).

**The turn is absolute, not added on top.** It measures where the face points now and turns the rest of the way. So:
- A clip whose `face_cam` is already baked for its staged facing gets about 0 extra.
- The mirrored facing gets the whole turn.
- The total turn is capped at ±85°.

**Files.**
- `ClipDef3D` (`clip_def_3d.gd`) parses `gaze` and adds `gaze_weight(f)`:
  - The ramps are inside the window.
  - On a loop, a window touching the seam carries straight across it (act_tea 0–12 plus 240–480, Hush loco_idle).
  - Overlapping windows take the higher weight.
  - A window outside the clip is an error. An `at` other than `"camera"` is a warning and is ignored.
  - All 43 current sidecars with `gaze` validate.
- `RigGaze3D` is a new modifier: `game/view3d/char/rig_gaze_3d.gd`.
- `RigPlayer3D` changes:
  - The base window cross-fades with the outgoing clip's window. An overlay window counts × the overlay's blend weight.
  - Which camera it turns to:
    - `set_gaze_camera(cam)` if the view gave one.
    - Otherwise `get_viewport().get_camera_3d()`.
    - When the head is outside that camera's view, the face goes to the audience straight in front of him (the camera's height and depth, his x). This case is Bellows drawn only in the PiP, which shares the World3D and this pose.
  - `gaze_enabled` lets the view switch it off. `gaze_weight()` and `gaze_weight_now()` read the weight.
  - While the gaze is full, the look-at pupils return to centre, so he looks at the camera.
- Also new: `set_overlay_frame(f)`, `current_overlay()`, `current_overlay_frame()`.

**Tests.** `game/tests/rig3d/test_gaze_3d.gd` has 8 tests:
- The camera placed left and right.
- Both facings.
- Weight 0 changes nothing, and frames outside the window change nothing.
- The ramp values, and the turn growing through the ramp.
- The default blend and the loop seam.
- The overlay's weight.
- The viewport camera, the gaze winning over a look-at pointed elsewhere, the pupils and the clamp.
- The off-screen audience fallback.

**Looked at:** `docs/review/r3d-rig/gaze_before_after.jpg`, at the game camera in the kitchen, `--no-gaze` against gaze.

| Frame | Facing | `--no-gaze` | With gaze |
|---|---|---|---|
| Bellows `rx_sneeze_blast_a` f 60 | −1 (staged) | face to camera (baked) | the same image: nothing extra |
| Bellows `rx_sneeze_blast_a` f 60 | +1 | the back of the bouffant | his face comes round to the camera |
| Hush `st_shrug` f 10 | −1 | a 3/4-left face | full face to the camera, the arms unchanged |

**Perf.** The gaze cost is inside the run-to-run noise. Hush `idle_fidget_proud` measured 189 and 201 µs with the gaze, and 205 and 187 µs without (RigPerf3D `--no-gaze`, load average 4–5). Bellows `act_tea` measured 233 µs. Both are within the 250 µs budget, with 2 draw calls.

## 2. Attachments keep the palette they were built with

**Rule.** An attachment whose scene is under `res://art3d/set/` or `res://art3d/props/` now draws with `set_toon` (`prop_toon` for props/). It uses the palette the glb was built on, found in this order:
1. The new optional descriptor field `attachments.<id>.palette`.
2. The glb's own texture.
3. `palette_props.png` for props/.
4. For set/, the palette of the room that `house3d.json` places the model in (`rooms.<room>.palette`).
5. The room named at the start of the file name.

These attachments get no outline, like set furniture, and no face, tint or stone state. `set_stage_light` reaches them.

**Result.** The ride-along stool (`res://art3d/set/stool.glb` on bone `ride`) is now the kitchen's brown stool, not salmon.
- Looked at: `docs/review/r3d-rig/stool_set_palette.jpg`, with the `g0_sneeze` set built. It shows f 60 (the set's stool), then f 100 and f 110 (the ride-along stool), with the colours matching side by side.
- Tests: `rig3d/test_attachments_3d.gd`. The room and palette lookup is checked, and the real Bellows stool gets `set_toon`, the kitchen palette, no `next_pass` and the stage light. The bouffants stay on `char_toon`.

## 3. My own queued items
- **Overlay sidecars no longer crash `sheet3d.gd`** (act_glance, st_shrug, mg_*). An overlay is sheeted over `<rig>/loco_idle` held at f 0, with the overlay's frame locked.
- **Stepped clips were cut in the phone strip, and the cause was a cross-fade.** Each pass restarted the clip with the default 6-frame cross-fade. A frame-locked sheet advances no view time, so the crop measured the previous pass's last pose. That is what cut `rig_achoo_ria` above the knees. Every pass now starts with `blend_in` 0, and the phone crop covers the whole clip.
- **Staged clips are sheeted as staged.** A sidecar `stage` gives the x, z, facing and cheat; `--facing`, `--x` and `--cheat` override it.
- **Gaze in sheets.** The profile cells show the authored motion (gaze off). The phone pass shows the game's gaze, and `--no-gaze` turns it off.
- **Looked at:** `sheet3d_stepped_phone.jpg` (feet, knees and the raised arm on the step, at facing −1) and `sheet3d_overlay_contact.png`.
- **AnimViewer3D:**
  - `--fixed-step`: exactly 1/60 s per rendered frame. A `--shot-seq --every=10` run with `--episode=g0_sneeze` loaded read clip f 9, 19, 29, 39 exactly.
  - `--no-gaze`.
  - An overlay clip given through `--clip` plays over the idle, and `--frame` locks the overlay's frame.
  - The label shows the overlay and the gaze weight.
- **Outline, one path.** `RigPlayer3D.set_outline_scale(k)` now sets the global `mnd_outline_scale`, the same global `StageLighting3D.set_outline_scale` sets, and never scales `outline_px`. The view calling both gives 1.5, not 2.25. `outline_px` stays the descriptor value; this is tested in `test_player_3d`. `outline_scale()` is a new getter.

## 4. Verification

| Check | Result |
|---|---|
| Full suite (`test_game.sh r3d-rig`) | **1506 passed, 0 failed, 0 skipped**, 166 files |
| rig3d, after the last change (the off-screen fallback) | 57/57 |
| view3d/ | 61/61 |
| `SANDBOX=r3d-rig lint.sh` | exit 0; lint_anim 3d: 77 clips, 0 errors, 0 warnings |

## 5. Requests
- **r3d-view3d / r3d-integrate:**
  - Nothing is needed for the gaze. `CharacterView3D`'s RigPlayer3D picks up the sidecar windows at the viewport camera.
  - If Bellows' PiP window should be exact, call `rig.set_gaze_camera(pip.cam)` while he is drawn only there, and `set_gaze_camera(null)` after. The built-in fallback (the audience straight in front of him) is close enough otherwise.
  - Do not also call `look_at_point(camera, 1.0)` for these windows. It is harmless, but it is not needed.
  - Settings "Outline +50 %": keep the one call (`StageLighting3D.set_outline_scale`). `RigPlayer3D.set_outline_scale` now writes the same global.
- **r3d-anim-hush-b (or r3d-integrate):** `hush/act_glance` (overlay, head) has no `gaze` window. Its audience snap is baked for facing +1 only, so as `flavour:glance` at facing −1 it still looks upstage. Add `c.look_camera(f0, f1)` over the snap, and the runtime then gives it for either facing.
- **r3d-anim:** the `glb_to_res.gd` key-reduction request from r3d-anim-bellows-a (Quaternion.angle_to on float32 near identical values) is addressed to me, but `game/tools/anim/**` is r3d-anim's. Their suggested metric (`2*atan2(|q-p|, |q+p|)` after the sign fix, or `1-|dot| < 1e-9`) looks right.
- **r3d-cast-bellows:** the `stool` attachment can stay as it is: the palette is derived. The optional `"palette": "res://art3d/set/palette_kitchen.png"` would make it explicit.
- **Orchestrator (R13):** new `game/view3d/char/rig_gaze_3d.gd` and `game/tests/rig3d/test_gaze_3d.gd`, `test_attachments_3d.gd` need `.uid` sidecars. No asset needs non-default import settings.

## 6. Known gaps
- The gaze has not been seen inside the full NightScene or e2e, only in AnimViewer3D, the sheets and the tests. CharacterView3D uses the same RigPlayer3D, so no view change is needed.
- AnimViewer3D does not act on clip `decor` events, so the set's stool stays visible during the sneeze there. The game view does act on them.

---

# Fix pass 2 addendum — rig perf (2026-09-30, 21:57–22:36Z; LEAD_NOTE 21:45Z PERF, issues.md D14)

**Result.** Every target is met on the llvmpipe proxy.
- `play()` after `prepare_clips` costs 0.07–0.08 ms mean and 0.12 ms max in the final run. It was 0.95–0.96 ms mean,
  4.1 ms max.
- The frame after a switch now costs about what any other frame costs: 0.16–0.20 ms mean, 0.50 ms max. It was
  0.38–0.40 ms mean with 0.7–0.8 ms p95.
- The per-character mean with clips switching every 10 frames and the skin bound is 0.12–0.16 ms (0.18–0.25 ms in
  the earlier runs).
- The only advance() frames over 1 ms were single non-switch frames that moved to a different clip and frame on
  every run, and a re-run had none. That pattern is preemption on the shared box, not a code path.

**Where the old costs came from** (measured per step):
- **play():** the first play of each clip loaded its `.res`: 0.8 ms on Hush and 1.5 ms on Bellows, per clip. On
  top of that came the library add, a rebuilt PlayPlan3D (16–46 µs) and a full looks refresh on every switch
  (15–80 µs).
- **The spike in the frame after a switch:** a new library entry invalidates the AnimationTree's track caches, so
  the next evaluation rebuilt them over every animation of every library. That frame also re-ran the whole looks
  refresh for look and prop events.

## What changed (all in `game/view3d/char/`)
1. **`RigPlayer3D.prepare_clips(ids: PackedStringArray) -> int` and `prepare_all_clips()`.** For every clip, they:
   - load the Animation and conform its loop mode;
   - add it to the tree's library;
   - cache its playable StringName, its plain plans in both loop modes, and the bones its scale tracks key;
   - then run ONE mixer evaluation, so the track caches are rebuilt now and not after the first switch.

   It is idempotent: an already prepared clip costs a lookup. `warm()` calls `prepare_all_clips()`. That is the path
   the Night already takes: NightWarmer's materials step → `WorldView3D.warm_materials` → `rig.warm()` on both
   live rigs, under the curtain. With `--prepare`, RigPerf3D measured 25–29 ms for Hush's 33 base clips and 25–31 ms
   for Bellows' 26 on the proxy. Headless, warm() with every clip of the rig (35 / 42) took 41 / 59 ms, about
   1.2–1.4 ms a clip, almost all of it `.res` loads. **No integrate change is needed.** Optionally,
   `WorldView3D.warm_clips` can also call `cv.rig.prepare_clips(ids)` with the Night's list, which is cheap after
   warm().
2. **play() does no load, no Animation build, no library add and no string building.**
   - `_ensure_anim` is cached per ClipDef3D, checked against ClipLib3D's current Animation, so a hot reload still
     re-adds.
   - Plain plays (tier ≤ 1, not suppressed, no hold override) reuse one cached, never-mutated plan per clip and loop
     mode. Tiered and suppressed plays still build their own plan.
   - `PlayPlan3D` caches `entry_for_clip` per clip id.
   - The no-op `_prop_on_clip_switch` is gone.
3. **Looks are precomputed at setup** (`_build_look_fx`). Each look and slot variant becomes a `_LookFx`:
   attachment indices shown and hidden, bone props, hidden bone indices, uniforms converted to StringName → value,
   and face cells. `_refresh_looks` is split into two passes:
   - **The looks pass** (attachments, uniforms, face cells) runs only when the looks, slots or forced attachments
     changed (`_looks_dirty`). It sets a node's visibility or a uniform only when the value changes.
   - **The bones pass** (the props' scale fix and hidden bones, from packed per-bone marks) runs on a clip switch or
     a prop state change.

   `set_look`, `set_body_slot`, the clip-ownership release, `reset`, attachment `set_prop` (a no-op when the state
   is unchanged) and the end of warm() mark the looks dirty. Prop events run the bones pass only. A new stats
   field, `looks_passes`, counts the looks passes.
4. **`screen_aabb()`:** the roles are a const `AABB_ROLES`, and their bone indices and the skeleton-to-world
   transform are resolved once per call instead of per bone. `socket_global` caches each socket's bone index.
5. **D7 default** (view3d request): `RigDef3D.outline_px` now defaults to `View3DConst.OUTLINE_CHAR_PX` (4.8) when
   the descriptor names none.

## RigPerf3D switch mode (new; `game/scenes/dev/anim3d/rig_perf_3d.gd`)
Command:
`tools/scripts/shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn out.png 600 <sb> -- --rig=hush --switch-every=10 --look-every=40 [--prepare] [--clips=a,b] --perf-log`

- It plays the next base clip every N frames: every base clip of the rig with a baked Animation, cycling. Nothing
  is loaded before the run.
- It toggles the rig's looks every M frames.
- `--prepare` calls `prepare_clips(list)` after setup.
- The skin stays bound for the whole run.
- Each of play(), advance(), the advance right after a play, the other advances and set_look() is timed on its
  own. The run prints {n, mean, p95, max} for each, the 5 slowest advances (µs, frame, clip, clip frame, and
  whether it was a switch or look frame), `looks_passes` and `prepare_ms`.

## Before → after
Proxy: llvmpipe via shot.sh at 1200x540, 598 frames, a switch every 10 frames (60 switches), a look toggle every
40 frames. Values are mean / p95 / max in µs.
- **Before:** the code at the start of this pass, lazy loads, at load 3.3–3.8.
- **After:** the final code with `--prepare`, at load 1.8.
- **Earlier after-runs:** before the last bones-pass tweak, at load 0.6–0.9. Ranges are over those runs (two for
  Hush, four for Bellows, including the 21:52Z timing run).

| call | Hush before | Hush after | Hush earlier | Bellows before | Bellows after | Bellows earlier |
|---|---|---|---|---|---|---|
| play() | 962 / 1896 / 2309 | **69 / 83 / 115** | 98–100 / 124–139 / 137–173 | 954 / 2226 / 4089 | **84 / 110 / 123** | 106–128 / 141–175 / 148–215 |
| advance(), frame after a switch | 400 / 744 / 1141 | **159 / 225 / 385** | 213–246 / 286–324 / 327–441 | 382 / 705 / 805 | **204 / 295 / 500** | 232–292 / 332–426 / 369–613 |
| advance(), every frame | 262 / 395 / 1141 | **122 / 206 / 385** | 180–221 / 263–318 / 462–638 | 280 / 404 / 3738 | **159 / 257 / 500** | 192–250 / 283–368 / 613–1633* |
| set_look() | 39 / 55 / 97 | 39 / 47 / 79 | 46–55 / 55–62 / 68–75 | 60 / 76 / 106 | 64 / 100 / 106 | 87 / 111–121 / 117–145 |
| prepare_clips (ms) | — | 30 | 27–29 | — | 23 | 25–31 |

\* **Bellows' advance() over 1 ms.** Across the Bellows runs there were four such frames, each once:
- bit_livid f9, 1633 µs, and bit_tea f5, 1563 µs, in the same run;
- st_look f8, 1324 µs, in the next;
- the 21:52Z timing run's 1041 µs frame (the clip was not logged).

None of them was a switch or look frame, the three logged ones repeat at no clip or frame, and the final run's max
was 500 µs. So this is preemption on the shared box (D14), not a code path. Every frame right after a switch
stayed ≤ 0.61 ms.

**set_look().** It is a single precomputed looks pass (0.05–0.12 ms). The in-game 1.6 ms outlier did not reproduce
in any run.

**Per-character budget (exit row 17), budget mode.** This is the existing RigPerf3D mode with the meshes unbound,
median / p95 / max in µs:
- Hush loco_walk: 133 / 199 / 245 (it was 186–192 median at load 3–6).
- Bellows loco_strut: 89 / 159 / 288.
- 2 draw calls each.

**Headless** (the rig3d tests, dummy renderer): 26–27 µs a frame, and with the churn test play() is 19–24 µs median.
On the proxy most of the per-frame rig cost therefore sits with the software rasteriser. Its threads compete with
the main thread, or its RenderingServer calls are what costs; RigPerf3D cannot separate the two. This supports
D14's ruling that the device p95 is what counts.

## Tests (game/tests/rig3d/)
- **test_perf_3d.gd:**
  - new `test_play_after_prepare_allocates_nothing` (fixture rig). After `prepare_clips`:
    - 3 × every base clip, plain and loop-flipped, creates 0 objects (`OBJECT_COUNT`);
    - no library entry is added;
    - ClipLib3D's Animation for each clip is the same object;
    - switching loco_walk ⇄ loco_idle runs 0 looks passes, and a slot change runs exactly 1;
    - a tiered play builds its own plan, and the cached plain plan keeps tier 1 and its loop mode, with opts.loop
      getting its own cached plan.
  - new `test_clip_churn_costs` (Hush, else the fixture): a switch every 10 frames over 300 frames. play() median
    must be ≤ 300 µs × load scale and the advance after a switch ≤ 1000 µs × load scale (headless: 19 µs and
    71 µs).
  - the warm budget is now `prepare_all_clips` ≤ 3 ms a clip, then warm() ≤ 20 ms with the clips prepared.
- **test_rig_def_3d.gd:** new `test_outline_default_is_d7`.

## Verification
All runs used the sandbox r3d-rig-p2.
- `test_game.sh -- rig3d/ view3d/`: **121/121** (rig3d 60, view3d 61). This re-ran on the final code after the last
  edit, which covered teardown clears, the bone → prop map and the forced-attachment guard.
- Full suite (`test_game.sh r3d-rig-p2`): **1510 passed, 0 failed, 0 skipped** (rc 0). It ran one edit before the
  final code; that edit was only the small rig_player_3d.gd changes above, re-verified by rig3d/view3d.
- `SANDBOX=r3d-rig-p2 lint.sh`: **rc 0** (lint_anim 3d: 77 clips, 0 errors, 0 warnings).
- Artefacts: `<SP>/work/r3d-rig/perf2/` holds before.txt, after1–3.txt, budget.txt, the scratch profilers
  prof.gd / prof2.gd, and their logs.

## Requests
- **r3d-integrate:** none required: the Night already reaches `prepare_all_clips` through `warm_materials`. Optional:
  `WorldView3D.warm_clips` calls `cv.rig.prepare_clips(ids)`.
- **Lead / QA:** judge exit row 17 with RigPerf3D `--switch-every=10 --prepare` (the in-game churn) or the budget
  mode, and read one-off >1 ms frames against the D14 preemption rule. The deterministic post-switch costs are gone.

## Hours
About 0.65 h (21:57–22:36Z).
