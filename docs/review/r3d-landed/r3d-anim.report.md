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

# r3d-anim fix-pass addendum (index §3.3.1; D12 + r3d-sets 21:06Z)

The new verb packet (v2) is built and "R17 verbs_64 v2 ready" is posted in my LANDED.md; a new fresh reviewer still has to run it, and I did not score it. The moved pepper pot is baked in and the spout-to-mouth test still passes. The gramophone was not re-baked because nothing about it changed. Full suite: 1506 passed, 0 failed, 0 skipped; `lint.sh` is clean. I could not write `<SP>/reports/r3d-anim.md` (report files are blocked for subagents), so this answer is the addendum.

Two things to know first:
- **Run 1 was partly testing blended poses.** The silhouette renderer cross-faded each item from the previous one for up to 8 frames, but only settled for 4. Some of run 1's silhouettes were therefore mixes of two verbs; the bow was blended with the squeak, and reach high with the run. That is fixed.
- **Reach high is not on the mime step.** The mime-step clip (`rig_high`) belongs to r3d-anim-hush-b, and none of its frames reads as reach high at 64 px. The packet uses my ACHOO-RIA clip instead: on the stool with both arms up.

## 1. D12: the 64 px verb test, v2

**Renderer fixes** (`game/tools/anim/verbs3d.gd`):
- Each item now plays with no cross-fade, so every silhouette is its own clip frame only.
- New `:plinth=1` option: puts the game's own `plinth.glb` under her, the same model `CharacterView3D._ensure_plinth` uses.

**Per-verb changes.** Every changed clip was re-baked with `--strict` and lints clean.

| verb | run 1 sample | v2 sample and change |
|---|---|---|
| statue ×4 | `freeze_1..4` f 30, no plinth | Same frames, with the stone plinth in the silhouette as in game. |
| squeak | `act_squeak` f 9, chicken hoisted overhead | Clip re-authored, sampled at f 8. She squeezes Clarence at chest height with a whole-body squash: knees deep, spine curled over him, shoulders up, feet planted. Both fists hold him by IK, and his neck and head point forward-up in front of her face, clear of it. Tucked back by f 15. The whip out of the holder is declared as pops on f 4–5. New camera gaze over f 6–13 (D8). |
| bow | `act_bow` f 40, legs in a stride | Held bow (f 28–52) re-keyed, sampled at f 40: heels together, legs straight, about a 100° hinge at the hips. The right glove sweeps across her middle; the left is flung up behind like a plume. |
| run | `loco_run` f 3 (a contact frame) | Sampled at f 9, mid-flight with both feet off. The back foot kicks further back early in the swing (0.30 m, was 0.22). The front foot reaches 0.16 m further ahead late in the flight and paws back to the contact point. Speed (3.6 m/s), stance and loop are unchanged. |
| reach high | `rig_achoo_ria` f 16, pot in one glove | Same frame. During the shakes (f 14–37) the free glove now goes up and out to her left with fingers spread, so both arms are up while she stands on tiptoe on the stool. The raised glove stays clear of her face and the jar in the kitchen view (`achoo_kitchen_fix.jpg`). |

**Board:** `docs/review/r3d-anim/verbs_64.png` / `.json` (v2), 18 silhouettes (mine plus hush-b's rummage and statues 5–8, all statues on the plinth).
- The most similar pair (IoU) is sneak/snicker at 0.64; no pair reaches 0.80.
- Next highest: squeak/reach mid 0.62; snicker/statue 8, squeak/statue 7 and reach mid/statue 7 at 0.61 each.
- Item list: `<SP>/work/r3d-anim/verbs_items_v2.txt`.

**Packet:** `docs/review/r3d-anim/packets/verbs_64/`
- 13 items, shuffle seed 41 (run 1 used seed 7), black on white (run 1 was black on transparent).
- New key: `<SP>/work/r3d-anim/review_key_verbs_v2.json`. Run 1's key is renamed `review_key_verbs_v1.json`; the old packet is kept in `<SP>/work/r3d-anim/packet_v1/`.
- `reviewer_prompt.md` has the v2 scoring command; it writes `reviewer_answers_verbs_v2.md` and `verdict_verbs_v2.md`. Run 1's files are untouched.

**Why not `rig_high`:** I sampled frames 16–104. At 64 px the crank reads as a standing pole with the gloves bunched at her head (`<SP>/work/r3d-anim/fx/e2_sil.png`).

**Weakest item (my guess, not a score):** squeak. Clarence's neck and head are only about 8 px in front of her chin. They are rigid; only his body scales, so her crouch carries most of the squash.

## 2. Pepper pot moved (r3d-sets request)
- `POT_PIVOT` is now (-0.16, 0, 0) in `tools/art3d/anim/hush/rig_achoo_ria.py`, matching `PEPPER_X` in `tools/art3d/set/build.py`.
- **Grab frame f 7:** her glove now stops 0.041 m short of the pot (was 0.05–0.07 m); f 8 is 0.028 m short. I tried pushing the hips forward and shrugging the shoulder; it made no difference (0.043 m), so I reverted it — her arm is at full stretch from the stool. The leftover gap is on the frame where the shelf pot swaps for the held one, about 2 px at 1200×540.
- **Spout to jar mouth:** `test_hush_clips3d` passes 9/9; within 0.03 m at f 16, 26 and 36 (actual 0.014 m).

## 3. Gramophone: not re-baked
- `parlour_gramophone.reach_pos` is still dx −0.4, z −1.30.
- `gramophone.glb` was last written at 19:47Z, before my 20:17Z bake.
- r3d-sets' 21:06Z landing does not mention the lever.

## 4. Verification
- **Full suite** (`test_game.sh r3d-anim`, with import): 1506 passed, 0 failed, 0 skipped. The red "FAIL" words in the solver's `d1_lean` printouts are metric prints, not test failures.
- **Repo lint:** `SANDBOX=r3d-anim lint.sh` returns 0; the 3D animation lint covers 77 clips with 0 errors.
- **Hush strict lint:** `lint --format=3d --rig=hush --strict` gives 35 clips, 0 errors.
- **Looked at:** every candidate frame in colour and at 64 px, the v2 board, the packet images, and the kitchen strip.

## For r3d-integrate
- **Renderer:** `verbs3d.gd` changes are listed in §1. Its `.uid` still comes from the real-project import.
- **Re-baked clips:** `act_squeak` (new pose, pops f 4–5, new camera gaze f 6–13, prop events still at f 4 and f 15), `act_bow` (`bow_creak` still at f 28), `loco_run` (sound table row unchanged), `rig_achoo_ria` (sound rows unchanged). Lengths are unchanged, so `map.json` and the manifest are untouched.
- **Stale:** `docs/review/r3d-anim/sheets/` for those four clips still show the old bakes; I skipped re-rendering them to stay in the time box. Re-run `anim_sheet3d.sh hush <clip>`.
- **Request (r3d-anim-hush-b or integrate):** in `rig_high`'s crank (f 42–96), straighten the elbows fully over her head so the gloves clear the beret by at least 0.15 m. Then the band clip itself reads as reach high.
- **Still open from D12:** the held `pepper_pot` prop should match the shelf pot (0.44 m, white, dark cap, holes 0.215 m up from the grip). In `achoo_kitchen_fix.jpg` it is barely visible.
- **Not mine:** with `NO_IMPORT=1`, `tests/rig3d/test_gaze_3d.gd` and `test_attachments_3d.gd` fail to parse (`RigGaze3D` / `gaze_mod`). This comes from someone's in-progress gaze work in `rig_player_3d.gd`; the full run with import passes.

## Files changed
- **Clip specs:** `tools/art3d/anim/hush/{act_squeak,act_bow,loco_run,rig_achoo_ria}.py`
- **Baked clips:** `game/art3d/anim/hush/{act_squeak,act_bow,loco_run,rig_achoo_ria}.res`
- **Sidecars:** `game/data/anim/hush3d/{act_squeak,act_bow,loco_run,rig_achoo_ria}.json`
- **Tool:** `game/tools/anim/verbs3d.gd`
- **Review docs** (`docs/review/r3d-anim/`): `verbs_64.png`, `verbs_64.json`, `packets/verbs_64/*`, `reviewer_prompt.md`, `index.md`, `achoo_kitchen_fix.jpg`
- **Scratch:** `<SP>/work/r3d-anim/` — `LANDED.md` (FIX PASS lines, 4 DONE lines, "R17 verbs_64 v2 ready"), `review_key_verbs_v2.json`, `verbs_items_v2.txt`, `fx/`

FIX PASS 2 addendum (r3d-anim, lead note 22:15Z)

The v3 verb packet is built and "R17 verbs_64 v3 ready" is in my LANDED.md. It still needs a new fresh reviewer, and I have not scored it. Both issues from the lead note are fixed: squeak and snicker are now different shapes, and every statue has a plinth you can see. The anim3d tests pass (52/0), the clip-event test passes (12/0), `lint.sh` is clean and the strict Hush lint is clean. I did not write `<SP>/reports/r3d-anim.md` because report files are blocked for subagents, so this answer is the addendum.

**Squeak (`act_squeak`, sampled at f 8)**
- She now holds Clarence out at arm's length. Her grip is 0.43 m in front of her chest, both arms straight and both fists on him. His neck, beak and comb stick out past her outline.
- Her body squashes behind the arms: a deep squat with her shoulders up.
- His body swells to 1.8× between her fists and his comb flares to 2.4×.
- **Held chicken could not be scaled up:** the game resets the scale of an attached prop to 1 (in `RigMods3D`, which is not my file). So his neck and head cannot grow and he is still only about 10 px at 64. I scaled his body and comb instead. The lead's "dangling feet" do not exist; the model has no legs.
- **Why the old squeak read wrong:** its turn-to-camera window covered f 8, and it rotates her whole upper spine, which pointed her straight arms at the camera. I moved the window from f 6–13 to f 9–14. In game she now looks at the audience just after the squeeze.
- I added a hold key at f 10 and moved the recoil to f 12 to clear two frame-jump lint errors.

**Snicker (`act_snicker`, sampled at f 18)**
- Both gloves are over her mouth by IK on the head from f 4 to f 46, and she bends forward at the hips into a giggling hunch.
- Her left heel flicks up behind her and her right heel is popped. I put the heel behind her rather than the knee forward because a knee stepping forward is the stock sneak pose.
- The clap onto the mouth is declared as a 2-frame snap at f 6–7.
- I sample f 18 because her turn-to-camera window (f 22–40) straightens the hunch in silhouette.

**Statues**
- The silhouette renderer (`verbs3d.gd`) now takes `:plinth=<k>`: the plinth is k times wider and √k times taller.
- The thinker crouch uses 1.8, which gives a clear slab under her. The other three of my statues use 1.4. r3d-anim-hush-b's statues 5–8 stay at 1.
- **Not true to the game:** the plinth in game is 1×, so these silhouettes show a bigger plinth than the player sees. The lead's note allowed this.

**Board and packet**
- `docs/review/r3d-anim/verbs_64.png` / `.json` v3 has 18 silhouettes. The most similar pair is reach mid / statue 7 at 0.61 IoU, so no pair reaches 0.80. Squeak / snicker is now 0.35.
- The packet is at `docs/review/r3d-anim/packets/verbs_64/`: 13 items, seed 19, and a prompt identical to v2's.
- The key is `<SP>/work/r3d-anim/review_key_verbs_v3.json`. The v1 and v2 keys and the v2 answers and verdict are untouched. The v2 packet is saved in `<SP>/work/r3d-anim/packet_v2/`.
- `reviewer_prompt.md` has the v3 notes and a scoring command that writes `reviewer_answers_verbs_v3.md` and `verdict_verbs_v3.md`. `index.md` is updated.
- I looked at every candidate frame in colour and at 64 px, and at the board, the packet sheet and the new contact and phone sheets.
- My guesses at the weakest reads (not a score): squeak vs reach mid (0.53), since both have the arms forward at chest height; and snicker vs sneak, since both lean forward on one foot.

**Sheets:** re-rendered for `act_squeak`, `act_snicker`, `act_bow`, `loco_run` and `rig_achoo_ria`, so none are stale now.

**For r3d-integrate**
- `act_squeak`'s turn-to-camera window is now f 9–14. Its prop events are still at f 4 and f 15, and its length is still 18.
- `act_snicker` gains pops at f 6–7. Its length (60), its `hush_snicker` sound at f 0 and its camera window (f 22–40) are unchanged.
- `map.json` and the manifest are unchanged.

**Request (r3d-rig):** in `MODE_SOCKET`, keep a clip's baked scale on the prop bone instead of forcing it to 1. That would let a held Clarence (or any held prop) grow for a squeeze.

**Files changed**
- `tools/art3d/anim/hush/{act_squeak,act_snicker}.py`
- `game/art3d/anim/hush/{act_squeak,act_snicker}.res`
- `game/data/anim/hush3d/{act_squeak,act_snicker}.json`
- `game/tools/anim/verbs3d.gd`
- In `docs/review/r3d-anim/`: `verbs_64.png`, `verbs_64.json`, `packets/verbs_64/*`, `reviewer_prompt.md`, `index.md`, and `sheets/` for the five clips above
- In `<SP>/work/r3d-anim/`: `LANDED.md` (FIX PASS 2 lines, two DONE lines, the R17 line), `review_key_verbs_v3.json`, `verbs_items_v3.txt`, `packet_v2/`, `fp2/`