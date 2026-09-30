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
