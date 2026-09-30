# r3d-anim-hush-b report: Hush's remaining 18 clips on the 3D pipeline

**Status: done.** All 18 clips are made, baked, lint `--strict` clean and FINAL. There are no drafts, because the R19 cut
line was never reached.

Timeline (UTC):
- 17:25: started.
- 18:23: the FINAL clips (`loco_arrive`, `freeze_midjob`) and the band fallbacks landed.
- 18:44: the glance, the skid and the three fidgets.
- 19:20: rummage, wheeze, shrug, yanked and statues 5–8.
- 19:51: all 18 re-baked on r3d-anim's updated lib.
- 20:00: lead note D8 (faces to the camera).
- 20:20: the stronger wheeze.
- 20:55: finish.

That is about 3.5 h of the 10 h box. Every render cited here and in `docs/review/r3d-anim-hush-b/` was looked at
full size.

I touched only §2 paths:
- `tools/art3d/anim/hush/<clip>.py`, `game/art3d/anim/hush/<clip>.res` and `game/data/anim/hush3d/<clip>.json` for the 18
  clips below.
- `game/tests/anim3d/test_hush_b_clips3d.gd`.
- `docs/review/r3d-anim-hush-b/`.

I ran no git write commands. Blender and Godot ran only through `bake.sh`, `test_game.sh`, `sandbox.sh`, `shot.sh`,
`anim_sheet3d.sh` and `lint.sh`, one process at a time, in the `r3d-anim-hush-b` and `r3d-anim-hush-b-shot` sandboxes.
Scratch is in `<SP>/work/r3d-anim-hush-b/`. LANDED lines and a `DONE <clip> <sha>` for every bake are in `LANDED.md`, and
every current sha matches `bake.sh hush --done`.

## 1. The clips

"Source" is the kind of source each clip has. All 18 are custom bpy specs on r3d-anim's lib; none is UAL-retargeted.
Hours are active hours, including the looks and fixes.

| # | clip | frames | source | state | what it is | h |
|---|---|---|---|---|---|---|
| 1 | `loco_arrive` | 8 | custom spec | **FINAL** | walk end → dip (2) → small hop, gloves up (4) → landing pop 6 (`land_soft`) → settle | 0.15 |
| 2 | `freeze_midjob` | loop 600 | custom, poses sampled from the band clips | **FINAL** | three held statues: mid 0–359 (`rig_mid` f 22), high 360–479 (`rig_high` f 66 upper body on the mid legs, so no step), low 480–599 (`rig_low` f 60); `hold_breath`, a 0.4° tremble; sidecar `variants` | 0.2 |
| 3 | `act_glance` | 30 | custom | FINAL | overlay, mask `head`: flick (2), snap to the audience (6), hold, worried look over the left shoulder (20), back (30) | 0.1 |
| 4 | `loco_skid` | 6 | custom | FINAL | heel dug in, toes up, gloves flung; pops 1–3, `slide_down_short` + dust at 2 | 0.05 |
| 5 | `idle_fidget_look` | 80 | custom (on r3d-anim's `loco_idle.base`) | FINAL | hand cupped to the ear (IK riding the head) 3–44, looks left 28–38; visor at the brow 40–66, looks right 50–60 | 0.1 |
| 6 | `idle_fidget_proud` | 84 | custom | FINAL | fists on hips (IK), chest out, chin bobs 24 / 36, ta-da 52–70; gaze to the camera 6–78 | 0.1 |
| 7 | `idle_fidget_clarence` | 80 | custom (audio-table row kept) | FINAL | Clarence pops up, smitten at 12 (`clarence_smitten`); finger to the lips (IK riding the head) 22–52; pats his head 46–70; gaze 52–76 | 0.1 |
| 8 | `act_rummage` | loop 36 | custom | FINAL | folded 70° at the hips into a container, both legs kicking up behind; `rustle` 0 / 18 | 0.1 |
| 9 | `act_wheeze` | loop 60 | custom | FINAL | squeezes Clarence at her chin: shoulders to her ears, knees dip, spine curls (40); a gasp (48); `clarence_body` squash 60 %; `wheeze_chicken` 0; gaze 0–60 | 0.2 |
| 10 | `st_shrug` | 20 | custom | FINAL | overlay, mask `upper`: forearms uncurl (0–3) → palms up and out, shoulders up (3–6, pops 4–6, palm IK riding `spine_03`) → hold → settle; gaze 0–18 | 0.15 |
| 11 | `st_yanked` | 36 | custom | FINAL | rises on her toes (0–4) → yanked by the cane (pops 5–7, `whoosh` + cane fx 4, beret jiggle 6) → stretched flat in the air (7–22) → lands dazed 27 (`land_soft`) → wobble; gaze 0–25, 27–36 | 0.1 |
| 12 | `rig_mid` | 96 | custom | FINAL | normalised (`rig_pm`), stage facing +1 / cheat 10: turns to the job, three crank rounds with a tug each (28 / 52 / 76, `tinker`), foot braced on the last; head to the camera (baked look) | 0.3 |
| 13 | `rig_high` | 120 | custom | FINAL | the mime's invisible step: pats an air rail (6 / 11), toe test (15 / 18, `tiptoe`), hop up (20–27, `slide_up_short`, +0.40 m), wobble, cranks overhead 42–96 (`tinker` 59 / 77 / 95), steps down 103–110 (`land_soft`); ends on the floor | 0.25 |
| 14 | `rig_low` | 144 | custom | FINAL | plops onto her knees (9–11, `thud`), all fours with a waggling foot, cranks 4 turns 28–112 (`tinker` ×4), boings up 124–132 (`boing_small`) | 0.3 |
| 15 | `freeze_5` | 150 | custom (shared `statue()`) | FINAL | the hat-tip: dip (0–2), snap (5, `freeze_clack`), one overshoot → hold 9–150 (smug, blink 78) | 0.1 |
| 16 | `freeze_6` | 150 | custom | FINAL | the ballerina en pointe, arms in a high V (proud) | 0.1 |
| 17 | `freeze_7` | 150 | custom | FINAL | the lamp post: one arm up and over, the hand drooping (statue face) | 0.05 |
| 18 | `freeze_8` | 150 | custom | FINAL | the scarecrow: arms out, hands limp, head tipped (dazed) | 0.05 |

Review, staging proofs, tests and the report took about 1.0 h more.

## 2. Contracts others use (sidecar fields, all optional)

So far only the tests read the new fields. `stage` is read by `CharacterView3D.rig_stage`.

- **Band clips:** `rig_mid` / `rig_high` / `rig_low` carry `"stage": {"x": 0, "z": -1.5, "facing": 1, "cheat_deg": 10}`,
  `"lock": "rig_pm"` and no `glance` mark. They also carry a new **`"reach_offset": [dx, y, dz]`**: where her gloves
  work, relative to her root, in the clip's facing (+1).

  | clip | `reach_offset` |
  |---|---|
  | `rig_mid` | [0.26, 1.00, −0.20] |
  | `rig_high` | [0.24, 1.86, −0.20] (the mime step's 0.40 included) |
  | `rig_low` | [0.30, 0.28, −0.22] |

  To make the job read, she stands at `placed reach target − reach_offset`.
- **`rig_high`** carries `"step": {"kind": "mime", "h": 0.4, "support": [[f, h] …]}`. The support is 0 at f 0, 0.40 from f 27,
  and 0 again from f 104, so the clip ends on the floor.
- **`freeze_midjob`** carries `"variants": {"mid": [0, 359], "high": [360, 479], "low": [480, 599]}` and
  `"variant_default": "mid"`. The view plays it with `start_frame = variants[<the prank's band>][0]` and holds that frame
  (`set_external_frame`). A view that ignores the field shows the mid statue for 6 s, then high, then low. Each segment
  is also a `lint.freeze_holds` entry.
- **`gaze`** (lead note D8, `c.look_camera`): runtime look-at-the-camera windows, facing-proof, additive, on these clips.

  | clip | gaze window (f) |
  |---|---|
  | `st_shrug` | 0–18 |
  | `st_yanked` | 0–25, 27–36 |
  | `idle_fidget_proud` | 6–78 |
  | `idle_fidget_clarence` | 52–76 (only after the finger leaves her lips) |
  | `act_wheeze` | 0–60 |

  No gaze is put where a glove rides the head, because a runtime head turn would pull the head off the glove:
  `idle_fidget_look`'s ear and visor, and the shush.
- **Overlays:** `act_glance` is `layer overlay` / `mask head`, and `st_shrug` is `overlay` / `upper` (clip_rules.json).
  The .res carries every bone's track, with the non-mask bones holding one constant stance; the player's mask keeps them out.
- All `.res` ≤ 250 KB: the largest is `freeze_midjob` at 212 KB, then `rig_low` at 113 KB. No clip needs runtime script.

## 3. Verification

- **Bake:** `SANDBOX=r3d-anim-hush-b tools/art3d/anim/bake.sh hush <all 18> --strict` → 18 OK. Max °/f is at pop
  frames only.
- **Tests:** `tools/scripts/test_game.sh r3d-anim-hush-b -- anim3d/test_hush_b` → **6 passed, 0 failed, 0 skipped**, statue IoU check included. The test covers:
  - all 18 exist, load through ClipLib3D, have the expected lengths, and are loops where allowed;
  - they lint `--strict` clean;
  - the band rules (`rig_pm`, ≥ 48 f, no `glance` mark, facing +1, cheat ≤ 10, the mime step 0.30–0.45 m, `rig_high` ending
    on the floor);
  - the overlay layer / mask, and the `freeze_midjob` variants plus its three holds;
  - `freeze_1..8` pairwise 64 px IoU < 0.80, from `statues_8.json`. The test finds the JSON through the working directory, and
    that check is a named skip when the JSON is absent.
- **Lint (hush scope):** `NO_IMPORT=1 tools/scripts/sandbox.sh r3d-anim-hush-b -s res://tools/anim/lint_anim.gd --
  --format=3d --rig=hush --scope=g0,p00 --strict` → **35 clips, 0 errors, 0 warnings, 0 missing**.
- **Statues:** `tools/art3d/review/sil64.py masks` on the eight statues, masked from `AnimViewer3D --cam=front --facing=1
  --cheat=35 --stone` frame-100 renders, re-shot after the last bakes. 0 pairs ≥ 0.80. The closest pair is
  `freeze_7`/`freeze_8` at **0.571**. The largest IoU between a new statue and an old one is 0.56 (`freeze_6` vs
  `freeze_3`).
- **Full suite:** `tools/scripts/test_game.sh r3d-anim-hush-b` → **1494 passed, 1 failed, 0 skipped** (1495 tests, 164 files). The one failure is r3d-sets' `set3d/test_house3d_build.gd::test_collisions_none_on_every_slice_night`: `hush@kitchen_kettle` overlaps the kettle by 0.033 m and `hush@parlour_newspaper` overlaps the recliner by 0.040 m. It comes from `house3d.json`, which was being edited at 20:42 while r3d-sets applied the staging request. An earlier run (19:49) had three other foreign failures (r3d-anim-bellows-a ×2, r3d-tools-b ×1); they pass now.
- **`SANDBOX=r3d-anim-hush-b tools/scripts/lint.sh`** → **exit 0** (`[lint] OK: 0 lint(s) failed`; `lint_anim` 41 clips and `lint_anim 3d` 77 clips, 0 errors). An earlier run at 19:53 exited 1 on r3d-anim's `rig_allegro_go_go` while it was being edited; that is clean now.
- **Solver baseline:** not applicable. No sim data changed.
- **Looked at:**
  - every contact / phone sheet, re-rendered after the last bakes;
  - the in-set frames (`bands.png`, `bands_frames.jpg`, `bands_staged.jpg`, the frame-locked strips);
  - `idles.png`, the overlay captures and the statue boards.

## 4. What the looks found, and what changed because of them

- **The band clips read in the studio, but at first not in the real sets.** At the 19:59 `reach_pos`, most N1/N2 band
  props sat directly upstage of her: the kettle, tap, pickle jar, fridge shelf, clock, recliner and newspaper were within
  ±0.1 m of her x (the phone and the mirror were already 0.24 / 0.36 m ahead). So at cheat 10 her body hid the kettle,
  the tap, the pickle jar and the clock face.

  `bands_staged.jpg` and the frame-locked strips show the same clips with the prop 0.24–0.30 m ahead: the tap, the clock
  face and the chair front are visible under her gloves. The kettle was the exception: its proposed spot is inside the
  kitchen/parlour wall. I added the sidecar `reach_offset` so either owner can place her exactly, and requested the
  staging.

  **r3d-sets applied most of it at 20:42.** I re-shot `bands.png` / `bands_frames.jpg` in `ViewSandbox3D --sim` with those
  values: the kettle, the pickle jar, the clock face and the recliner are now under her gloves. The mirror is still
  mostly behind her.
- **`act_wheeze`** first read as "holding something at her chin": the squeeze was invisible at game scale. Now the strain
  goes down through the whole body (shoulders, spine, knees), then a gasp.
- **D8:** all five face beats with no head-riding glove got a runtime gaze (§2).
- **`idle_fidget_look` f 6:** the glove passes in front of her face for 2–3 f on its way to the ear. I accepted this: it
  is quick and it reads as the start of the gesture.

## 5. Deviations

- `idles.png` is a 128-colour PNG (554 KB). The full-colour one was 1.8 MB.
- The sheet renderer crashes on overlay clips (r3d-rig, §6), so `act_glance` and `st_shrug` have no contact sheet. They
  are shown by AnimViewer overlay captures instead: `act_glance_over_rig_mid.jpg` and `st_shrug_over_idle.jpg`.
- `freeze_midjob` is 600 f, not 840. At 840 f the .res was 277 KB, over the 256 000-byte L30 limit, so the high and low
  segments are 120 f each. The view holds a frame anyway (`variants`).
- The fresh-reviewer mute test of the band clips is **pending review**. The packets and `reviewer_prompt.md` are ready,
  because this task cannot spawn a reviewer.

## 6. Requests for other owners

- **r3d-anim (`hush3d/map.json`): all applied (map.json 20:13), nothing open.** The rows are:
  - `flavour:arrive`, `flavour:skid`, `flavour:glance`
  - `idle_fidgets` [look, proud, clarence]
  - `freeze_midjob` {loop}
  - `state:rummage` and `state:pick_window` → `act_rummage` {loop}
  - `oneshot:wheeze` {loop}
  - `flavour:shrug`
  - `oneshot:yanked`
  - `freeze` [freeze_1..8]

  The `rig:<prank>` rows stay derived: `bands.<band>.clip` = `rig_mid` / `rig_high` / `rig_low`.
- **r3d-sets (`game/data/house/house3d.json`, the N1/N2 band props): mostly applied at 20:42.** The rule: set
  `reach_pos` so the prop's placed reach target lies at her `reach_offset`. That is `reach_pos.dx = placed_target.x −
  use_x − reach_offset.x` and `reach_pos.z = placed_target.z − reach_offset.z`, clamped to z ≥ −1.6.

  | prop | `reach_pos` at 20:42 | status |
  |---|---|---|
  | `kitchen_sink_tap` | dx −0.08, z −1.60 | as proposed |
  | `hall_clock` | dx −0.12, z −1.60 | as proposed |
  | `kitchen_fridge_shelf` | dx −0.06 | as the rule gives |
  | `kitchen_kettle` | dx −0.42, z −1.44 | reads in `bands.png`, but she overlaps the kettle by 0.033 m (the failing set3d test) |

  Still open:
  - **The kettle:** moving its `visual_offset.x` from −0.30 to ≥ +0.05 would let her stand the full 0.26 m to its left
    and still be clear of the wall.
  - **Values that differ from the rule.** The rule assumes `reach_target` scales with the prop (×1.5 for the tap, the
    pickle jar, the newspaper and the phone), as the tap's value does. They matter only where a prop still hides behind
    her, as the mirror does in `bands.png`:

    | prop | rule gives | 20:42 value |
    |---|---|---|
    | `parlour_recliner` | −0.15 | +0.15 |
    | `kitchen_pickle_jar` | +0.01 | +0.15 |
    | `hall_mirror` | +0.16 | +0.02 |
    | `parlour_newspaper` | +0.07 | +0.10 |
    | `hall_phone` | +0.02 | +0.03 |
- **r3d-view3d (`CharacterView3D`):**
  1. Play every `rig_*` clip with the sidecar's `stage.facing` and a cheat ≤ 10. This is already done by `rig_stage`.
  2. While a band clip plays, place her at `placed reach target − reach_offset` (the facing +1 offset), eased 0.2 s,
     wherever `reach_pos` would leave the prop hidden. Either this or the r3d-sets change is enough.
  3. Honour `freeze_midjob.variants`: start at the band's segment and hold that frame.
  4. Consume the sidecar `gaze` windows (r3d-anim's clips use them too) through `look_at_point(camera, weight)`.
     `act_glance`'s audience snap is baked toward her right, which is the camera only when she faces +1. Until gaze is
     consumed, play `act_glance` as a flavour only facing +1, or accept an upstage glance when she faces −1. Every band
     rig is facing +1, so the rig glances are right.
  5. `act_rummage` / `state:pick_window`: yaw her toward the container (she folds straight ahead).
- **r3d-rig:**
  - `anim_sheet3d.sh` crashes on overlay clips (`act_glance`, `st_shrug`: the play plan is null for a `layer overlay`
    sidecar). Please sheet overlays over the rig's idle.
  - `AnimViewer3D --play --shot-seq` runs on the real clock, so in a heavy `--episode` set the first frames skip a
    second or more of the clip. A fixed-step option (`--fixed-step`, or `set_external_frame` per view frame) would make
    sequences exact. I used `--frame=N` shots.
- **r3d-integrate (audio rows):** these clips have no row, and their sound frames are new.

  | clip | sound frames (f, id) |
  |---|---|
  | `loco_arrive` | 6 `land_soft` |
  | `loco_skid` | 2 `slide_down_short` |
  | `act_rummage` | 0 / 18 `rustle` |
  | `act_wheeze` | 0 `wheeze_chicken` |
  | `st_yanked` | 4 `whoosh`, 27 `land_soft` |
  | `rig_mid` | 28 / 52 / 76 `tinker` |
  | `rig_high` | 15 `tiptoe`, 27 `slide_up_short`, 59 / 77 / 95 `tinker`, 110 `land_soft` |
  | `rig_low` | 10 `thud`, 48 / 69 / 90 / 111 `tinker`, 132 `boing_small` |
  | `freeze_5..8` | 5 `freeze_clack` |

  `bake.sh --audio-rows` lists them. `idle_fidget_clarence` keeps its table row.
- **Orchestrator (R17):** run the two mute-test packets in `reviewer_prompt.md`.

## 7. Known gaps

- The band clips' read in the sets depends on staging that r3d-sets was still tuning at 20:42. The mirror is still hidden
  behind her, and the kettle spot collides. The mute test (R17) is pending.
- `act_glance` turns only the head (the bob and beret flip); there is no pupil or eye beat, because the face cards have none.
- Clarence is small at game scale, so `idle_fidget_clarence`'s peek and `act_wheeze`'s squash read mostly through her
  body, not the chicken.
- The IK residuals are accepted:

  | clip | residual | where |
  |---|---|---|
  | `rig_low` | 0.033 m | the bracing glove at the full tip |
  | `rig_high` | 0.032 m | the far crank point |

- The band clips have one fixed hand height per band (mid 1.00 m, high 1.86 m, low 0.28 m). A mid prop at 0.60 m or
  1.35 m is worked from the same height.
- Foreign failures, not mine and not fixed: `set3d/test_house3d_build.gd::test_collisions_none_on_every_slice_night` (r3d-sets, in progress, see §3).

## 8. Non-default import needs

None. The clips are `.res` Animations written by the converter. The new test script
`game/tests/anim3d/test_hush_b_clips3d.gd` gets its `.gd.uid` at the orchestrator's real-project import, as
r3d-anim's `test_hush_clips3d.gd` does. Tasks don't run Godot on `game/`.

## 9. Hours

About 3.5 h active, of the 10 h box. The cut line was never reached, so there are no drafts.
