# r3d-anim report (A0 pipeline + A1: Hush's 17 clips)

All 17 of Hush's clips are FINAL, baked with `--strict`, and lint clean. Every check passes, and every clip has a DONE line in `<SP>/work/r3d-anim/LANDED.md`. A0 landed at 17:20 UTC, A1 at 20:17 UTC, and the final check ran at 21:08 UTC.

Three things are still open:
- **The 64 px verb test (W1) is pending review.** This task cannot start a reviewer, so under R17 I built the packet and prompt. The orchestrator needs to run them; the bar is at least 11 of 13 named correctly.
- **ACHOO-RIA! staging is weak because of where the set pieces are placed.** The pepper pot's spout reaches the jar's mouth within 0.012 m on all three shakes, and the test checks this. But her glove is partly hidden behind her head from the camera. On the grab frame (f 7) her hand also stops 5–7 cm short of the pot on the shelf.
- **ALLEGRO-GO-GO! staging.** The parlour wall end covers her back on f 9–19, while she is turned toward the lever.

Both staging problems are requests to r3d-sets below.

I could not write `<SP>/reports/r3d-anim.md`: the environment blocks subagents from writing report files, so this answer is the report.

## Verification
- **Bake:** `bake.sh hush <all 17> --strict` gives 17 OK.
- **Lint:** `lint_anim --format=3d --rig=hush --scope=g0,p00 --strict` checks 35 clips with 0 errors. All 35 Hush and 32 Bellows clips are also clean with `--strict`.
- **Repo lint:** `SANDBOX=r3d-anim lint.sh` passes; its 3D lint covers 77 clips with 0 errors.
- **Full suite:** `test_game.sh r3d-anim`, with the import step, gives 1496 passed, 0 failed, 0 skipped.
- **Hush clip tests:** `game/tests/anim3d/test_hush_clips3d.gd` passes 9 of 9. It covers:
  - clip lengths, and the rows the g0 + p00 manifest (`SliceClips.build3d`) expects;
  - `--strict` lint;
  - every `map.json` key resolves, and the walk and run numbers match the clips;
  - the statues snap on f 5 and hold;
  - rig staging;
  - the ACHOO spout is within 0.03 m of the target at f 16, 26 and 36;
  - on ALLEGRO, the right glove is on the knob at f 14 and 16.
- **Looked at:** the review sheets for all 17 clips, the kitchen and parlour strips, the Gate-0 path strip, and the 64 px verb board, all at 1200×540.

## Pipeline commands
```
SANDBOX=<key> tools/art3d/anim/bake.sh <rig> <clip…>|--all|--changed [--strict]
SANDBOX=<key> tools/art3d/anim/bake.sh <rig> --ual <action> --as <rig>/<id> [--layers mime,damp_head]
tools/art3d/anim/bake.sh <rig> --done <clip>        # the DONE line
tools/art3d/anim/bake.sh --audio-rows               # docs/review/r3d-anim/audio_rows.md
NO_IMPORT=1 tools/scripts/sandbox.sh <key> -s res://tools/anim/lint_anim.gd -- --format=3d [--rig|--clip|--file] [--scope=g0,p00] [--strict] [--json=]
tools/scripts/shot.sh res://tools/anim/Verbs3D.tscn /abs/x.png <6×items+10> <key>-shot -- --out=/abs/dir --items="name=hush/clip@f[:facing=-1][:cheat=10][:prop=id.state],…"
```

**New in A1 (documented in `tools/art3d/anim/README.md`):**
- **`ik_handoff`:** an IK path that takes over from the keyed hand and gives it back, easing target, elbow swivel and glove turn, so the arm never flips mid-move.
- **IK helpers:**
  - `keyed_arm`;
  - IK targets, poles and hands can be `fn(frame, pose)`;
  - `blend=(in, out)`;
  - `soft=`.
- **Pose helpers:**
  - `start_on`: a clip that starts on a step;
  - `jump`: a flight that lands on the same floor;
  - `pose.mix`: a true in-between of two poses;
  - `stage.prop_point`: prop anchors placed the same way the game's `SetGeo.to_world` does. `reach_geometry` now applies the prop's rotation too.

**Pipeline fixes that change existing results:**
- A ball plant now keeps the toes flat.
- A short foot contact that ends a one-shot is now planted.
- The arm IK takes its elbow hinge from the pole plane, so a straight arm no longer flips 180°.
- The `run_arms` preset now swings about the right axis; before, it only twisted the arm.

## Sidecar fields as used
Base fields (v2): `version, format, clip, rig, fps 60, length, loop, anim, layer, mask, lock, blend_in, blend_out, cheat_deg, stride_m, speed_m_s, root.travel, events, face, beats, lint{pop_frames, freeze_holds, draft}, keeps, tags, notes, source{spec, audio, bake}`.

Optional fields I added:
- **`stage` {x, z, facing, cheat_deg}:** the view must play the clip with this facing. `rig_achoo_ria` is −1, `rig_allegro_go_go` is +1.
- **`step` {kind, h, id, support}.**
- **`gaze` [{f0, f1, at: "camera", weight, blend}]:** a look toward the audience applied at runtime, so it works facing either way. Used on `loco_idle` f 0–50 and 112–240, and on `act_snicker` f 22–40.
- **`source.audio`:** `table` or `own`.

## Lint rules and thresholds
The rules are in `game/tools/anim/lint3d_rules.gd` and the thresholds in `lint3d_limits.json`. All angles are per frame of a bone's local rotation.

**Structure**
- L01: ids, sound ids, faces and props all resolve.
- L02: `.res` length and loop mode match the sidecar.
- L03: events and faces fall inside the clip.
- L04: loop seam ≤ 0.5°; the velocity kink across the seam ≤ max(1°/f, the clip's own worst kink).

**Timing**
- L05: accent ≤ 4 f.
- L06: some bone turns ≥ 20°/f around the accent.
- L07: the anticipation moves against the accent.
- L08: holds ≥ 24 f (36 f at tier 2).
- L09: no dead hold over 20 f (every body bone under 0.3°/f, pelvis under 1 mm/f) unless it is a declared freeze.
- L10: no jump over 45°/f except on declared pop frames.
- L11: left and right limbs never mirror each other within 1° for more than 10 f.

**Feet**
- L12: judged per heel, ball and toe point, in lane space.
  - A planted point drifts ≤ 0.01 m.
  - New in A1: a contact only counts as planted at ≥ 3 frames (`plant_min_f`), or when it is a landing that ends a one-shot.
  - In walks, the planted foot moves at −speed ± 5 %.
- L13: no sole point more than 0.015 m below the floor or step.

**Sound, face and reactions**
- L14: sounds within ±1 f of a beat, mark, pop or contact.
- L15: face swap on the accent ±1 f.
- L16: laughs start after the accent.
- L17: reactions 60–240 f; signatures ≤ 420 f.
- L18: silhouette size changes ≥ 15 % from anticipation to accent.
- L19: beats within 2 f of `reactions.json`.
- L20: `time_jitter` is 0.
- L21: reaction clips define all four beats.
- L22: mark names are accent, release, knock_on or contact.
- L23: overlays have a mask and blend over ≥ 4 f.

**Data**
- L24: sounds match the audio table.
- L25: lengths match the manifest.

**Staging**
- L26: cheat 0–40°, ≤ 10° on rig clips that reach. New in A1: `rig_step_down` is exempt.
- L27: root travel ≤ 0.15 m.
- L28: rig clips:
  - lock is `rig_pm`;
  - tier lengths Q 48 / S 90 / B 150;
  - band clips ≥ 48 f with no glance marks;
  - stepped clips end on the floor ± 0.01 m.
  - New in A1: a missing lock no longer crashes this rule.
- L29: lock values are valid.
- L30: `.res` ≤ 250 KB.

## Clip table
Bake time is the Blender step per clip; the converter and lint add about 15 s per batch.

| # | clip | frames | kind | how it's made | audio | bake ms | KB | ≈ h |
|---|---|---|---|---|---|---|---|---|
| 1 | loco_idle | 240 loop | loop | keyed poses, layered motion, hip IK, runtime look to camera | own | 1892 | 128 | 0.4 |
| 2 | loco_walk | 54 loop, 2.0 m/s, stride 1.80 | loop | procedural feet with leg IK | own | 461 | 47 | 0.5 |
| 3 | rig_achoo_ria | 48, rig_pm | take | keyed + `ik_handoff` along the pot's path, stool step, head look | own | 462 | 45 | 1.8 |
| 4 | rig_step_down | 8 | take | keyed, starts on the stool, steps down | own | 193 | 25 | 0.1 |
| 5 | act_snicker | 60 | take | keyed + giggle layer, ball plant, runtime look | table | 570 | 52 | 0.3 |
| 6 | act_dive | 15 | take | keyed + jump arc | table | 196 | 32 | 0.15 |
| 7 | act_pop | 15 | take | keyed + jump arc | table | 234 | 33 | 0.1 |
| 8–11 | freeze_1..4 | 150 each | take | shared statue builder: in-between, overshoot, snap on f 5, frozen hold | table | 987–1193 | 46–68 | 0.6 total |
| 12 | act_squeak | 18 | take | keyed + Clarence squash layer, prop attach events | table | 239 | 32 | 0.2 |
| 13 | loco_run | 24 loop, 3.6 m/s | loop | procedural feet, arm pump | table | 290 | 32 | 0.3 |
| 14 | loco_turn | 6 | take | keyed | own | 140 | 22 | 0.05 |
| 15 | act_climb_in | 60 | take | keyed, starts on a 0.9 m sill, steps down | table | 533 | 47 | 0.3 |
| 16 | rig_allegro_go_go | 48, rig_pm | take | two `ik_handoff` arms following the lever's arc | own | 525 | 55 | 0.4 |
| 17 | act_bow | 150 loop | loop | keyed + nod and sway layers | own | 1244 | 116 | 0.25 |

Totals and cost:
- Size: the 17 `.res` files total 0.87 MB against an 8 MB budget.
- Bake: all 17 take 11.5 s in Blender, plus about 15 s for the converter.
- Lint speed: all 35 Hush clips lint in 0.6 s.
- Cost per clip: a loop took 0.3–0.5 h and a one-shot take 0.1–0.4 h. The two staged rig clips took 0.4–1.8 h, mostly because the prop placements kept changing while I worked.

## Sound rows for r3d-integrate (from `docs/review/r3d-anim/audio_rows.md`)
These are the `own`-audio rows to fold into `clip_events.json`:
- `loco_walk` (loop): `step_pizz_up` at f 0 and 27.
- `rig_achoo_ria` (48):
  - `stool_creak` at f 6;
  - `pepper_shake` at f 16, 26 and 36;
  - `step_pizz_up` at f 47.
- `rig_allegro_go_go` (48): `creak` at f 13, `clack` at f 22.
- `rig_step_down` (8): `step_pizz_up` at f 6.
- `act_bow` (loop): `bow_creak` at f 28.
- `loco_idle` and `loco_turn`: no sounds.

The table rows for `loco_run` and `act_climb_in` stay as they are; those clips were timed to them.

## Requests (also listed in LANDED.md under REQUESTS)
1. **r3d-rig:**
   - Honour the sidecar `gaze` field. Without it, the snicker's sly look and the idle's head turn to the audience don't happen.
   - Frame the review-sheet phone cells on the clip's bounds. Right now the fixed crop cuts her off above the knees when she is on the stool.
2. **r3d-view3d:**
   - Play every `rig_*` clip with the sidecar's `stage.facing`, at cheat ≤ 10.
   - At the honey jar, her floor spot (x 14.85) is inside the stool's seat footprint (14.81–15.19), so her feet overlap the stool on f 0 and f 48. Either walk her in beside the stool or accept those two frames.
3. **r3d-sets (`house3d.json`):**
   - **Honey jar's pepper pot.** It sits 0.30 m beyond the jar, so she only reaches it with a 30° lean-out on one foot, and her hand stops 5–7 cm short on the grab. If Bellows' hair clearance allows, move its pivot from x −0.2 to about −0.15.
   - **Honey jar from the camera.** The jar is behind her head. Each extra 0.1 m of `reach_pos` dx uncovers more of it.
   - **Gramophone lever.** Its `rig` animation should move the lever 40° toward the front between progress 16/48 and 22/48, so the knob stays under her gloves.
   - **Gramophone standing spot.** Increasing its `reach_pos` dx by 0.15 would clear the wall end that covers her back.

   Both rig clips re-bake from this data.
4. **r3d-cast-hush:** her `pepper_pot` prop is a small dark cylinder, but the pot on the shelf is 0.44 m tall, white with a dark cap. Make them match so the swap on f 7 and f 42 doesn't show. The clip assumes the pot's holes (`fx_pepper`) sit 0.215 m up the pot from the grip.
5. **Orchestrator (R17):** run a fresh reviewer on `docs/review/r3d-anim/packets/verbs_64/prompt.md`. The answer key is at `<SP>/work/r3d-anim/review_key_verbs.json`; scoring steps are in `reviewer_prompt.md`.
   - My weakest guesses are snicker, squeak and reach-mid.
   - No two of the 18 silhouettes overlap by 0.80 or more; the worst pair is 0.61.
6. **Import metadata:** the new scripts need their `.uid` files from the real-project import: `game/tools/anim/verbs3d.gd`, `Verbs3D.tscn` and `game/tests/anim3d/test_hush_clips3d.gd`.

## Suggested text for TECH and GDD (for r3d-docs)
- **TECH §7.2:** list the optional sidecar fields `stage`, `step`, `gaze` and `source.audio`. `gaze` is a look toward the audience applied at runtime. A head turn baked into a clip only works for one facing, so baked turns are for staged rig clips only.
- **TECH §10.5 (3D):**
  - The lint is `lint_anim.gd --format=3d`, rules L01–L30, thresholds in `lint3d_limits.json`.
  - Feet are judged per sole point in lane space; a contact counts as a plant at 3 frames or more, or when it ends a one-shot.
  - `rig_step_down` is not a reach.
- **TECH §11.1:** `game/tools/anim/Verbs3D.tscn` renders transparent cut-outs of clip frames on the game's own player, for the 64 px silhouette tool.
- **GDD §4.3 (ACHOO-RIA!):** the reach target is now the jar's mouth. The pot's spout goes there and the glove holds the pot 0.215 m above it, so the acceptance test is "spout within 0.03 m", not "glove within 0.03 m".

## Hours
Wall clock was about 16:25 to 21:10 UTC, roughly 4.75 h, on a shared machine with waits for CPU slots. A0 took about 0.9 h, A1's clips about 3 h, and review and wrap-up about 1 h. Nothing was cut.

## Files
- **Clip specs** (`tools/art3d/anim/hush/`): all 17 `<clip>.py` plus `_freeze.py`.
- **Pipeline** (`tools/art3d/anim/`):
  - `lib/` — changed: `clip.py`, `pose.py`, `stage.py`, `hush_presets.py`;
  - `README.md`.
- **Game data** (`game/data/anim/hush3d/`): `map.json` and the 17 clip sidecars; the baked clips are in `game/art3d/anim/hush/`.
- **Game tools and tests:**
  - `game/tools/anim/{lint3d_rules.gd, lint3d_limits.json, verbs3d.gd, Verbs3D.tscn}`;
  - `game/tests/anim3d/test_hush_clips3d.gd`.
- **Review** (`/home/user/mischief/docs/review/r3d-anim/`):
  - `index.md`, `rubric.md`, `reviewer_prompt.md`;
  - `verbs_64.png`, `verbs_64.json`, `packets/verbs_64/`;
  - `achoo_kitchen.jpg`, `achoo_kitchen_pot.jpg`, `allegro_parlour.jpg`, `gate0_path.jpg`;
  - `audio_rows.md`, `sheets/`.
- **Landing log:** `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/r3d-anim/LANDED.md`