# 3D clips — the animation pipeline (R3D ruling R2)

Clips are **authored in Python** (a pose language on the rig's armature, with IK, foot grounding, steps and reach
helpers), **evaluated at 60 fps** by the pipeline itself, keyed on every frame into one Blender action, exported as a
glTF action and converted to a Godot `Animation` resource, plus a JSON **sidecar** with the beats, events, face timeline
and lint data (index §7.2). One clip = three files, all written by `bake.sh`:

| file | what | git |
|---|---|---|
| `tools/art3d/anim/<rig>/<clip>.py` | **the spec you write** | yes |
| `game/data/anim/<rig>3d/<clip>.json` | the sidecar (generated from the spec) | yes |
| `game/art3d/anim/<rig>/<clip>.res` | the baked `Animation` (binary, uncompressed, ≤ 250 KB) | yes |
| `build/art3d/anim/<rig>/<clip>.glb` + `bake.log` | the intermediate action + one log line per bake | no |

Library (owner `r3d-anim`; other keys request fixes): `lib/pose.py` (pose language, FK, IK, look-at), `lib/clip.py`
(`Clip`: keys, eases, beats, events, face, constraints, steps, UAL), `lib/stage.py` (world ↔ character space, the
camera, the placed reach geometry of `house3d.json`), `lib/events.py` (the audio table, R3), `lib/ual.py` (UAL
retarget), `lib/ease.py`, `lib/export.py` + `lib/bake_main.py` (Blender side), `lib/bake_cli.py` (bake.sh's helper),
`lib/fixtures/` (the lint's fixture clips). Converter + lint (Godot): `game/tools/anim/{glb_to_res,lint3d_rules,
lint_anim}.gd`, thresholds `game/tools/anim/lint3d_limits.json`.

## Quick start — your first clip in 5 minutes

```bash
# 1. write tools/art3d/anim/hush/act_wave.py (below)
# 2. bake it (Blender + the converter + the lint, one table at the end); SANDBOX = YOUR task key
SANDBOX=r3d-anim-hush-b tools/art3d/anim/bake.sh hush act_wave
# 3. look at it (sheets + a 1200×540 strip in the real set; r3d-rig's tools)
tools/scripts/anim_sheet3d.sh hush hush/act_wave docs/review/<your-key>/sheets
tools/scripts/shot.sh res://scenes/dev/anim3d/AnimViewer3D.tscn /abs/out.png 1 <your-key>-shot -- --rig=hush \
    --clip=hush/act_wave --room=kitchen --x=15.0 --play --shot-seq=/abs/seq --every=3 --count=20
# 4. lint strict (the R9 scope: the Gate-0 + Prologue set)
NO_IMPORT=1 tools/scripts/sandbox.sh <your-key> -s res://tools/anim/lint_anim.gd -- --format=3d --clip=hush/act_wave --strict
# 5. when it is FINAL: the resume line for your LANDED.md (R16)
tools/art3d/anim/bake.sh hush --done act_wave        # -> DONE hush/act_wave <sha256 of the spec>
```

```python
# tools/art3d/anim/hush/act_wave.py — a spec is a module with build(ctx) -> Clip
from lib.clip import Clip
from lib.pose import sym, merge, curl

REST_ARMS = sym({"upperarm_l": [("y", 70)], "lowerarm_l": [("z", -12)]})   # arms down (sym mirrors l -> r)

def build(ctx):
    c = Clip(ctx, "hush/act_wave", length=60, cheat_deg=35)
    wave = merge(REST_ARMS, {"upperarm_r": [("y", -150)], "lowerarm_r": [("z", 30)]}, curl("r", 10))
    c.key(0, REST_ARMS)
    c.key(8, merge(REST_ARMS, {"upperarm_r": [("y", -40)]}), "in_out_sine")   # anticipation: the arm dips first
    c.key(11, wave, "pop")                                                     # accent: pops in on f 11
    c.key(24, merge(wave, {"lowerarm_r": [("z", 50)]}))                        # a moving hold
    c.key(40, merge(wave, {"lowerarm_r": [("z", 20)]}))
    c.key(60, REST_ARMS, "in_out_cubic")
    c.beats(anticipation=(0, 8), accent=(8, 11), hold=(11, 44), settle=(44, 60))
    c.ground()                                  # the lowest sole point on the floor every frame
    c.face(0, "neutral"); c.face(8, "grin")     # face timeline (preset names = the rig's faces.json)
    c.sfx(11, "whoosh")                         # sounds sit on a beat boundary / mark / pop / contact (±1 f)
    return c
```

## The pose language (`lib/pose.py`)
A pose is a dict `{bone: [(axis, degrees), ...]}` of rotations about **armature axes**, applied in order as if the
parent were at rest (FK: children inherit). Bones not named stay at rest. Armature axes (the rig's own frame):
**+x = her LEFT, −y = her FRONT, +z = up**.

| bone | +x | y | z |
|---|---|---|---|
| spine / neck / Head | bend forward | lean sideways (+ = to her left) | turn (+ = to her left) |
| thigh | leg back (−x = knee up) | leg out/in | twist |
| calf | bend the knee | | |
| foot | point the toes (−x = toes up) | | |
| upperarm_l (T-pose along +x) | twist | + = arm down from the T | − = arm forward |
| lowerarm_l | | | − = elbow bend (forward) |

The right side mirrors: `mirror(rots)` flips y and z, `sym(pose)` copies every `*_l` to `*_r` mirrored, `swap(pose)`
swaps sides (the second half of a cycle), `merge(a, b, …)` (later wins per bone), `add(a, b)` (b's rotations after a's),
`scaled(pose, k)`, `mix(a, b, k)` (a true in-between: quaternion slerp bone by bone — use it for a key half-way
between two poses; `scaled` only scales angles), `curl(side, deg, thumb=, spread=)` (fingers). Entries may be `{"r": [...], "s": scale, "t": (x, y,
z) offset}`. Special keys: `"_pelvis": (x, y, z)` / `"_root": (x, y, z)` armature-space offsets (m). Scale survives
the bake only on extra (non-UAL) bones; squash with poses (knees, spine), not scale.

## `Clip(ctx, id, length, **options)` (`lib/clip.py`)
Options (sidecar fields, index §7.2): `loop`, `layer` (`base` | `overlay` | `additive`), `mask` (`upper` `head` `arms`
`face`), `lock` (`None` | `"sim"` reactions/bits/one-shots | `"rig_pm"` every rigging clip), `blend_in`, `blend_out`,
`cheat_deg` (performing 35, walking 20, reaching ≤ 10), `stride_m`, `speed_m_s`, `audio` (`"table"` | `"own"`, below),
`skippable`, `draft` (R19: still lint-clean, only exempt from rubric scoring), `stage` (a `Stage`, below), `keeps`,
`tags`. Frame 0 = clip start; frames 0..length; on loops frame `length` IS frame 0.

**Keys:** `c.key(f, pose, ease)` — `ease` is the curve INTO that key: `linear hold pop` and `in_ | out_ | in_out_` ×
`quad cubic quart expo sine back elastic bounce` (identical to the 2D RigEase; back/elastic overshoot). A `pop` key adds
its frame to `lint.pop_frames` (the only frames allowed a > 45°/f jump). `c.hold(f0, f1, pose, drift)` (a moving hold),
`c.overshoot(f, pose, pct=0.15, frames=6)` (arrive through exactly ONE overshoot).

**Beats, events, face:** `c.beats(anticipation=(a, b), accent=(b, c), hold=(c, d), settle=(d, e))`; `c.event(f, type,
**fields)` with the §7.2 types (`sfx voice laugh fx face cam shake hitstop slowmo freeze prop mark decor set_anim
set_part look jiggle`); shortcuts `c.sfx(f, id)`, `c.mark(f, name)` (`accent release knock_on contact`),
`c.face(f, preset | slots=…)`. Set pieces: `c.event(f, "prop", op="lend", prop="set:kitchen_kettle", socket="grip_r",
frames=6)` / `op="return"`. Glances at the audience that must work facing either way: `c.look_camera(f0, f1)` (sidecar
`gaze` → the player's runtime look-at; a baked head turn only reads for one facing).

**Sounds (ruling R3):** `audio="table"` (default) copies every sound of the clip's row in
`game/data/audio/clip_events.json` into the sidecar — do NOT place those sounds yourself — and the bake FAILS if the
row's `len_f` differs from your length. Loops / locomotion retimed to the 3D gaits: `audio="own"` and place the
contact sounds yourself (ids from `game/audio/sfx_map.json`); `bake.sh --audio-rows` lists them for `r3d-integrate`.

**Constraints** (applied every frame, in the order you add them — ground first, then plants / IK / look):
- `c.ground(f0=0, f1=None, lift=0, per_frame=True)` — pelvis height so the lowest sole point (heel / ball / toe) sits on
  the support. `per_frame=False`: one offset for the whole range (runs with a flight phase).
- `c.auto_plant(speed_m_s=None)` — **locomotion**: finds each foot's stance and pins its rolling contact (heel → ball →
  toe) in LANE space (sliding back at `speed_m_s` in clip space); the planted foot keeps its keyed pitch but not a yaw;
  after lift-off the foot eases back to the keyed swing. `None` measures the motion's own speed (UAL clips). Sets
  `speed_m_s` / `stride_m`. In-place walks: key the cycle, `ground()`, `auto_plant(2.0)` → lint-clean feet.
  `auto_plant(0.0)` holds standing feet still (a planted stance while the upper body acts).
- `c.plant(side, f0, f1, at=None, part="foot"|"ball", travel=None)` — hold one foot over a range by hand.
- `c.ik(side, target, f0, f1, pole=, hand=, effector="palm"|"wrist"|"tip"|<socket>, blend=4, world=True)` — 2-bone
  arm IK (look B's analytic solver): `target` = a world (Godot) point, `("camera",)`, `(bone, rest point)` riding on a
  bone, or `callable(frame) -> point`; `pole` = the elbow direction (armature space); `hand` = the glove's rotation
  about armature axes (e.g. palm down); the IK weight eases in / out over `blend` frames.
  `blend` may be a pair `(in, out)`; `soft=0.06` is the soft-IK zone near full extension (no elbow snap as a target
  comes into reach; the hand falls short by ≤ soft/e at full stretch — use 0.03 when the hand must land exactly).
  `target`, `pole` and `hand` may also be `fn(frame, pose)` (the pose so far: keys + layers + earlier constraints);
  `hand` may return a world `Quaternion`. `c.keyed_arm(pose, side, effector)` → (the keyed effector point, the keyed
  elbow pole, the keyed glove rotation) for such callables.
- `c.ik_handoff(side, path, f0, f1, pole, hand=, effector=, ramp=6, ramp_out=, hand_ramp=, soft=)` — **the grab**:
  IK along `path(frame) -> armature point` that TAKES OVER from the keyed hand over `ramp` frames after f0 and GIVES
  IT BACK by f1 — target, elbow swivel (rotated about the shoulder→hand axis) and glove turn all ease from the keyed
  arm's own, so a hand that must reach a prop after a hop never flips its elbow mid-move (rig_achoo_ria,
  rig_allegro_go_go). Key the arm roughly where the IK will take it, then let this do the last 30 cm.
- `c.reach(side, world_target, f0, f1, …)` — IK to a placed reach target + the head turned to the camera (R5d).
- `c.look(target, f0, f1, weight, blend)` — a baked head / neck aim (staged clips only: rigs).
- `c.custom(fn, f0, f1)` — `fn(pose, frame)` for anything else (see `lib/fixtures/` for examples).

**Steps (R5):** `c.step_up("stool", 0.55, f0, f1, decor_id="kitchen_stool")` — hop onto a support between take-off f0
and landing f1 (the feet ground on it from f1; a `decor {id, anim: wobble}` event at the landing for a stool);
`c.step_up("mime", 0.40, f0, f1)` — the invisible step (pat the air first in your keys). `c.step_down(f0, f1)` — back
to the floor (support 0 from f0 + 1). The sidecar gets `step {kind, h, id, support: [[f, h], …]}`; root x/z never move.
`c.start_on("stool", 0.55, "kitchen_stool")` — a clip that STARTS on a step (rig_step_down, a sill: act_climb_in).
`c.jump(f0, f1, arc)` — a flight that lands on the same support (a dive, a star jump): grounding is suspended in the
air, the pelvis follows the arc. Tiptoe / heel-pops: `c.plant(side, f0, f1, part="ball")` holds the ball of the foot
AND keeps the toes flat on the floor as the heel lifts (auto_plant would roll the contact and slide it).

**Where the clip is performed:** `from lib.stage import Stage, reach_geometry`. `Stage(x, z, facing, cheat)` converts
world points (`stage.to_char((x, y, z))`) and gives the camera (`stage.camera()`, the audience at (x, 1.9, 6.5)).
`reach_geometry("kitchen_honey")` reads `house3d.json` (+ house.json x/y): `{target: world (x, y, z), pos: {x, z, step,
step_h}, facing, band}` — stage a rig clip with `Stage(pos["x"], pos["z"], facing, cheat=10)` and reach `target`.
`prop_point(hotspot, local)` gives any other prop-local anchor in world space exactly as `SetGeo.to_world` does (the
prop's yaw and scale applied) — e.g. the lever pivot, the set pepper pot's spot. The placed target moves when
r3d-sets re-places a prop: derive every staging number from these, never hard-code world metres, and re-bake.
Rig clips (`rig_*`) record their stage in the sidecar (`stage {x, z, facing, cheat_deg}`): the view must play them
with that facing.

**Pose layers:** the rig's default layers (`rig3d.json` `anim.layers`, e.g. Bellows' `arm_out` +40° arm abduction)
are applied by the pipeline to EVERY clip — never key them by hand. Per clip: `c.pose_layer("mime")` (elbows up,
gloves like paws). Angles: `lib/clip.py` `LAYER_DEFS`, overridable per rig in `rig3d.json` `anim.layer_defs`.

**UAL (CC0 Quaternius library):** in a spec, `c = Clip.from_ual(ctx, "hush/loco_x", "Walk_Loop", layers=["mime"])`,
then `c.ground(); c.auto_plant()` + face / events as usual; ad hoc: `SANDBOX=<key> tools/art3d/anim/bake.sh hush --ual
Walk_Loop --as hush/ual_walk --layers mime,damp_head`. Rotations transfer as world offsets from rest (rests share
UAL's directions), pelvis translation × the leg ratio, extra bones at rest. Names: `Walk_Loop Crouch_Fwd_Loop
Jog_Fwd_Loop Sprint_Loop Jump_Start Jump_Land Roll Chest_Open PickUp_Table ClimbUp_1m Idle_Loop Walk_Formal_Loop
Sitting_* Interact Idle_Talking_Loop Zombie_Walk_Fwd …` (86 clips in UAL1 + UAL2).

## bake.sh
```
SANDBOX=<key> tools/art3d/anim/bake.sh <rig> <clip> [<clip> …]   # named specs
SANDBOX=<key> tools/art3d/anim/bake.sh <rig> --all                # every spec of the rig (skips _*.py)
SANDBOX=<key> tools/art3d/anim/bake.sh <rig> --changed            # specs newer than their .res, or older than lib/,
                                                                  # the rig's glb or <rig>/_lib/ — the resume (R16)
tools/art3d/anim/bake.sh <rig> --done <clip>                      # the DONE line for LANDED.md
```
One Blender process (via `tools/art3d/blender.sh`, one CPU slot) for all listed clips, then one Godot run in YOUR
sandbox (`glb_to_res.gd --batch … --lint`); prints a table (clip, frames, max°/f, bake ms, KB, OK / lint errors) and
exits 1 on any failure. Shared pose presets go in `tools/art3d/anim/<rig>/_lib/*.py` (not specs; import them with
`from _lib.presets import …`). Env: `RIG_GLB=/abs/stand_in.glb` (until the cast glb exists), `STRICT` via `--strict`,
`NO_LINT=1`, `BAKE_SIDECAR_DIR` / `BAKE_RES_DIR` / `BAKE_RES_PREFIX` (fixtures, experiments). ≈ 0.5 s per custom
clip, ≈ 3–4 s for a UAL clip (the library import), + ≈ 10 s for the converter run.

## The lint (`lint_anim.gd --format=3d`)
```
NO_IMPORT=1 tools/scripts/sandbox.sh <key> -s res://tools/anim/lint_anim.gd -- --format=3d --rig=hush --scope=g0,p00 --strict
    [--clip=hush/x | --file=/abs/or/res/sidecar.json] [--json=/abs/report.json]
```
Rules L01–L30 (header of `game/tools/anim/lint3d_rules.gd`; thresholds in `lint3d_limits.json`): ids, lengths,
frames, loop seams (≤ 0.5°, continuous velocity), accent ≤ 4 f with ≥ 20°/f, anticipation opposes the accent, holds
≥ 24 / 36 f (tier 2), no dead hold > 20 f (every body bone < 0.3°/f — a hold must MOVE: breath, tremble, a finger),
no > 45°/f jump off `pop_frames`, no L/R mirror twinning > 10 f, **feet in lane space** (planted points drift
≤ 0.01 m over a contact of ≥ 3 frames or a landing that ends a one-shot; walks: stance velocity = −speed_m_s ±
5 %), soles never > 0.015 m below the support, sounds within ±1 f of
a beat / mark / pop / contact, the take's face swap on the accent, laughs after it, reaction lengths 60–240 (≤ 420),
bounding box ≥ 15 % change, beats within 2 f of `reactions.json`, time_jitter 0, the audio table, the manifest
lengths (`SliceClips.build3d`), cheat ∈ [0, 40] (≤ 10 on rig clips), root travel ≤ 0.15 m, rig clips (`rig_pm`,
prank = its tier's frames Q 48 / S 90 / B 150, band clips ≥ 48 f without glance marks, stepped clips end on the
floor), lock values, `.res` size. `--scope=g0,p00` = the R9 set; unbaked clips print as `INFO MISSING`.
The lint samples the baked tracks itself (FK on the rig skeleton; `test_pipeline.gd` checks it against RigSampler3D).

## Troubleshooting
- *"sound frames differ from the audio table"* — you placed a sound the table already has (audio="table" copies it),
  or retimed the clip: keep the 2D length, or `audio="own"` for loops.
- *"planted foot slides"* — add `auto_plant()` (walks) / `auto_plant(0.0)` (standing) after `ground()`; check the
  foot is not twisting (a planted foot's yaw is pinned).
- *"mushy accent"* — the accent beat must contain the fast frames: put a `pop` key (or a 2–4 f move) inside it.
- *"no motion for ≥ 21 f"* — make the hold move (≥ 0.3°/f on some body bone every ≤ 20 f), or `c.freeze_hold(f0, f1)`.
- *"clip baked on another skeleton"* — the rig glb changed (skeleton v0 → frozen): re-bake (`--changed` does it).
- *"jumps 50°/f without a pop"* on a hop or a grab — the keyed arm and the IK arm disagree: key the arm near where
  the IK takes it and use `ik_handoff`; a body rising out of a squash in one frame (`out_cubic` into the next key) is
  the other usual cause — `in_out_sine` it over ≥ 3 frames. A deliberate smear (a dive's launch, a whip) goes in
  `c.pop_frames`.
- *"no motion for ≥ 21 f"* on a performed hold (a bow) — layer `c.motion(fn)` nods / sways over it.
- A Blender traceback prints under the `[bake] FAILED <clip>` line; the full log is kept in the temp dir it names.
- Silhouettes: `tools/scripts/shot.sh res://tools/anim/Verbs3D.tscn /abs/x.png <6×items+10> <sandbox> -- --out=/abs/dir
  --items="name=hush/clip@frame[:facing=-1][:cheat=10][:prop=pepper_pot.held],…"` renders RGBA cut-outs on the game's
  RigPlayer3D (then `tools/art3d/review/sil64.py masks … --mode=alpha`).
