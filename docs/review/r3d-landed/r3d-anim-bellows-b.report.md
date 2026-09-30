# r3d-anim-bellows-b — report

Key `r3d-anim-bellows-b` (queue priority 6): Horace Bellows' Gate-0 bits, one-shots and micro-gags in 3D, 20 clips on
r3d-anim's pipeline (brief `<SP>/tasks/r3d-anim-bellows.md`, index §5.3). Launched 19:21Z and finished 21:30Z, about
2.2 h of a 10 h box. **All 20 clips are final and none are drafts** (the R19 cut line at 02:51Z was never reached).
Each clip is baked, passes `lint --strict`, has a DONE line and was looked at at 1200×540 in the real P00 set. The two
squeak bits were also checked in game.

## Files built (all inside my §2 ownership)
- `tools/art3d/anim/bellows/<clip>.py`: 20 specs.
- `game/art3d/anim/bellows/<clip>.res`: 20 baked clips, 26–112 KB each (≤ 250 KB).
- `game/data/anim/bellows3d/<clip>.json`: 20 sidecars (v2).
- `docs/review/r3d-anim-bellows-b/`: `index.md`, `rubric.md`, `boards/` (bits, oneshots, microgags, in-game Bellows
  window board + mute GIF) and `sheets/` (r3d-rig's sheets for the 7 base clips, the lint for all 20). 14 MB in total.

No shared helper file was created: each spec carries its own 8-line `hide_fx()` (see "Pipeline notes").
`_lib/presets.py` (-a's) is used read-only.

## Clip table
| # | clip | frames | layer / mask | lock | staging | sounds | FINAL | h |
|---|---|---|---|---|---|---|---|---|
| 1 | `bit_warmup` | 90 | base | sim | st_gramophone (8.65, −1.4, facing −1, cheat 35); face baked to camera + gaze | own: 8 yodel, 46 the_pipes | FINAL | 0.5 |
| 2 | `bit_tea` | 100 | base | sim | tea_stage() on the stool; cup + saucer shown, spoon hidden, keeps [] | own: 4 slurp, 17 pff, 28 ugh, 58 sniffle | FINAL | 0.35 |
| 3 | `st_head_turn` | 60 | overlay head | sim | facing-proof, gaze | (cues "huh") | FINAL | 0.15 |
| 4 | `st_double_take` | 18 | base | view | facing-proof, gaze; ends on a held take (the N1/N2 reaction fallback) | — | FINAL | 0.25 |
| 5 | `st_specs_on` | 12 | overlay upper | sim | facing-proof; `prop show specs` f4 | (cues tink) | FINAL | 0.1 |
| 6 | `st_suspicious` | 60 | base | sim | facing-proof | own: 10 sniffle | — | 0.1 |
| 7 | `st_look` | 180 loop | base | sim | facing-proof (symmetric peers) | — | — | 0.1 |
| 8 | `st_look_back` | 60 | base | sim | a look back over both shoulders | — | — | 0.1 |
| 9 | `st_smirk` | 30 | overlay upper | sim | facing-proof | (cues hmph) | — | 0.05 |
| 10 | `st_straighten_cravat` | 92 loop | base | sim | facing-proof (92 f ≥ the longest doorway pause) | own: 20 cravat_tug | — | 0.15 |
| 11 | `mg_hum` | 48 | overlay upper | view | st_gramophone | table (0 hum) | — | 0.05 |
| 12 | `mg_trill` | 48 | overlay upper | view | st_gramophone | table (0 trill, 30 teacups_rattle) | — | 0.1 |
| 13 | `mg_conduct_air` | 60 | overlay upper | view | st_gramophone, the baton | table (5/20/30 swish, 42 bow_creak) | — | 0.05 |
| 14 | `mg_admire_reflection_horn` | 60 | overlay upper | view | st_gramophone, horn world point | table (6 glint, 14 smug, 42 kiss) | — | 0.1 |
| 15 | `mg_pinkie_up` | 48 | overlay upper | view | tea_stage(), THE SIP path | table (10 clink, 14 wobble, 30 bliss) | — | 0.05 |
| 16 | `mg_admire_in_kettle` | 48 | overlay head (sidecar) | view | tea_stage(), kettle world point; wink via face slots | table (6 glint, 14 smug) | — | 0.2 |
| 17 | `mg_comb_flourish` | 48 | overlay upper | view | st_hall_mirror (4.76, −1.4, facing +1) | own: 6 zip, 20 sparkle | — | 0.05 |
| 18 | `mg_cravat_tug` | 48 | overlay upper | view | facing-proof | own: 10 cravat_tug, 27 cravat_ping | — | 0.05 |
| 19 | `mg_walk_hum` | 48 | overlay upper | view | facing-proof | own: 0 hum | — | 0.05 |
| 20 | `mg_walk_scale` | 48 | overlay upper | view | facing-proof | own: 0 scales | — | 0.05 |

Source kind for all 20: custom (bpy pose language + IK, `_lib.presets`). The remaining ≈ 0.6 h went on the review
pass (sheets, boards, in-game capture, suite and lint). Lengths, locks, layers and masks follow `clip_rules.json`,
`SimOneshots`, `activities.json` (`squeak_bits.len_f`, the micro-gag `len_f`) and the manifest
`SliceClips.build3d(["g0_sneeze","p00_curtain_up"])`.

## What each FINAL clip reads as (details and frame numbers in `rubric.md`)
- **`bit_warmup`** (P00's first player laugh, ≈ 6 s): he is singing the top note. The squeak cracks it (f8 pop,
  yodel), the baton arm flaps above the bouffant, and he throws his arms wide and back (f30–35). Then SNAP: one glove to
  the side of his neck, the other on his heart (accent f35–38, on the squeak-bit rim-shot at +0.6 s). A chin-up
  "…the pipes." with the face turned to the house, then back to the warm-up carriage. In game it plays in the Bellows
  window while Hush is in the kitchen (`boards/ingame_bit_warmup_pip.png`). There the yodel and the wind-up read, and
  the clutch reads as "hand to the chest".
- **`bit_tea`**: a hurried sip, then the SNORT (f17 pop). The head whips down, his little legs kick out and the saucer
  glove is flung out behind him, with tea drops (fx) at the nose. Then three coughs with a teary face, a suspicious
  glare at the house, and back to act_tea's rest. The ×1.8 cup is readable in every cell.
- **`st_head_turn`**: the listening beat added on top of the view's own squeak gaze: a start, the ear cocked hard
  over, a squint, a shake-off.
- **`st_double_take`**: glance, a look away with his hands tucked, then a SNAP (pop f9) into a trembling held take:
  gloves out and low (never over the face), eyes popped. It must read on its own as the fallback.
- **`st_specs_on`**: the glove whips the dangling specs onto his nose (f4 `magnified`) and pushes them up the bridge,
  with a glint.

## Verification
- `SANDBOX=r3d-anim-bellows-b tools/art3d/anim/bake.sh bellows <clip…> --strict`: all 20 OK (scratch bake first via
  BAKE_SIDECAR_DIR/BAKE_RES_DIR, then landed only when clean).
- `NO_IMPORT=1 tools/scripts/sandbox.sh r3d-anim-bellows-b -s res://tools/anim/lint_anim.gd -- --format=3d --rig=bellows --scope=g0,p00 --strict`:
  42 clips, 0 errors, 0 warnings, 0 missing (the INFO rows list the new audio frames).
- `tools/scripts/test_game.sh r3d-anim-bellows-b -- anim3d/test_bellows`: 9/9 passed, 0 skipped (all 42 Bellows clips
  present).
- Full suite `tools/scripts/test_game.sh r3d-anim-bellows-b` (21:15Z): 1496 passed, 0 failed, 0 skipped. After it I
  lengthened `st_straighten_cravat` to 92 f; re-running `anim3d/` then gave 51/52. The only failure is r3d-anim's
  in-flight `hush/act_squeak` (L10 pop at f13, `test_hush_clips3d::test_lint_strict_clean`). That is not my file and
  was not changed by me.
- `SANDBOX=r3d-anim-bellows-b tools/scripts/lint.sh`: rc 0 (3D anim lint 77 clips, 0 errors).
- Solver baseline (R10): not applicable. Nothing the sim reads was touched.
- LOOKED at (Read every PNG):
  - the fixed-60-fps captures of all 20 clips at the game camera in the real P00 set (`capture.sh` → AnimViewer3D);
  - the micro-gags re-captured over -a's real `act_warmup` / `act_tea` (f420, f120) / `act_fixup_mirror` / `loco_strut`;
  - an in-game ViewSandbox3D P00 run (the real sim, the ideal route, ticks 120–450) showing the horn micro-gag and the
    squeak bit in the Bellows window;
  - r3d-rig's sheets for the base clips.
- What changed because of looking:
  - the throat clutch no longer covers the mouth (the glove moved to the neck side; two versions were rejected);
  - the yodel flaps and the trill arms no longer cross the face;
  - the double-take gloves stay low and wide;
  - `st_suspicious` keeps its face level (the first lean-in showed only the bouffant);
  - `st_look` / `st_look_back` were rebalanced;
  - `mg_admire_in_kettle` was restaged (see Deviations);
  - the FX bones are hidden in every clip. An overlay that did not key them showed the CHOO puff and the stars.

## Deviations (with reasons)
- **`bit_warmup` content.** The brief's table says "a vain double-check of his reflection, 'who's there?'". The binding
  content (`activities.json` `squeak_bits.bit_warmup.desc`, GDD §2.3 and §4.1) is "His high note cracks into a yodel;
  he clutches his throat: '…the pipes.'" with voice `vo_bellows_the_pipes`, and the Prologue beat at ≈ 6–7 s is
  exactly that. I built the content's version.
- **D8 (every face beat turns to the camera).**
  - Clips with a fixed staging (the bits, the warm-up and tea micro-gags, the comb) bake a head aim at the camera for
    their staging and also carry sidecar `gaze` entries.
  - The 14 facing-proof clips (one-shots, walking micro-gags) can only express D8 as `gaze`. A baked turn reads for one
    facing only, and the lint caps `cheat_deg` at 40, so a clip cannot choose "cheat ≥ 45".
  - `RigPlayer3D` does not honour `gaze` yet, so until request 1 lands those faces show at the plain 35° / 20° cheat.
- **`mg_admire_in_kettle`.**
  - It fires at tea 2.0 s = act_tea f120, the honey beat. The jar is lent to his left palm and the spoon is in his
    right glove, so an upper-body overlay cannot pat the bouffant or take the kettle without dragging the lent jar.
  - The kettle also sits on his far right-back side, so looking at it turns his face away from the house.
  - The clip is therefore authored for the `head` mask. It glances at the kettle for 11 f (glint), then plays the
    vanity and a WINK (face slots: eyes closed under one cocked brow) to the house.
  - Its arms copy the honey hold, so it is safe under the `upper` mask that clip_rules applies today.
  - Staging reported to r3d-sets, -a and content (requests 2, 7, 8), as the brief asked.
- **`st_straighten_cravat` is 92 f, not a shorter loop.** The doorway pause lasts up to 90 − eta + 1 ticks, and the
  view frame-locks one-shots with a clamp, not a wrap. One cycle must therefore cover the longest pause.
- **Sheets.** r3d-rig's sheet tool fails on overlay clips, and its phone strip is fixed at facing +1, z −1.0. So only
  the 7 base clips have sheets. The 13 overlays are reviewed in the boards (fixed 60 fps, over their real activities).
- **Retimes: none.** Every table row is kept exactly (audio "table" on the 6 micro-gags that have rows). The bits and
  one-shots have no 2D rows; their sounds are new rows (request 5). No cues.json sound is duplicated in a clip (L12).

## Map rows (for -a's `game/data/anim/bellows3d/map.json`)
None are needed. Every clip resolves through `view/world/default_maps/bellows.json` and `clip_rules.json` with the same
ids. The optional explicit rows are listed in request 6.

## Pipeline notes for r3d-anim
- `c.face(f, slots=…)` without a preset counts a face miss in `FaceCards3D` (the preset is empty). Pass a preset
  together with the slots: `c.face(18, "smug", slots={…})`.
- An FX bone that no clip keys still gets a constant-1 scale track, so an overlay that does not key it shows it
  (request 13). This key wraps `c.key` / `c.overshoot` so every key carries `fx_hidden("fx_choo", "fx_stars",
  "fx_notes")`.
- A debugging aid for L18: `<SP>/work/r3d-anim-bellows-b/glbfk.py` does FK on a baked `build/…/<clip>.glb` and prints
  the lint's camera-view bbox per frame. It is a scratch tool, not a measurement tool.

## Requests for other owners (file, change, why)

1. **r3d-rig → r3d-integrate** (`game/view3d/char/rig_player_3d.gd`, `clip_def_3d.gd`): honour the sidecar `gaze`
   entries (`[{f0, f1, at: "camera", weight, blend}]`, r3d-anim's optional field) on the BASE and the OVERLAY clip:
   `look_at_point(camera_point, weight)` eased over `blend` frames inside [f0, f1]. Why: lead ruling D8 — every face
   beat must turn the head to the camera; the 14 facing-proof clips of this key (one-shots, walking micro-gags) can
   only express that as `gaze` (a baked turn reads for one facing only, and the lint caps `cheat_deg` at 40, so the
   "cheat ≥ 45" alternative is not open to a clip). ClipDef3D does not parse `gaze` today.
2. **r3d-view3d → r3d-integrate** (`game/view3d/world/character_view_3d.gd` `_play_overlay`): play an overlay with the
   clip sidecar's `mask` when it has one, `ClipRules.mask_of()` only as the fallback. Why: `mg_admire_in_kettle` is
   authored for the `head` mask (the mg fires at act_tea f120, the honey beat: an `upper` overlay drags the lent jar and
   the spoon with its own hands); under today's `upper` the clip's arms approximate act_tea's honey hold, so it is safe,
   but the head mask is the intended one.
3. **r3d-view3d → r3d-integrate** (`game/view3d/world/world_view_3d.gd` `_update_gaze`, the `noise` branch): the squeak
   gaze aims his head at the noise point (weight 0.85 for 1.2 s) — Hush is usually behind him, so the face of the head
   turn / lure goes AWAY from the house. Bias the target toward the camera (e.g. halfway between the noise point and
   the camera) or drop the weight to ≈ 0.5 while `st_head_turn`'s own gaze asks for the camera (D8).
4. **r3d-rig** (`game/tools/anim3d/sheet3d.gd` phone pass): take `--facing` / `--z` (or the sidecar `stage` block) —
   the phone strip is always facing +1 at z −1.0, so every clip staged facing −1 (the bits, the warm-up and tea
   micro-gags, -a's tea and sneeze) is reviewed mirrored with its baked camera-look turned away.
5. **r3d-integrate** (`game/data/audio/clip_events.json`, via `tools/audio/clip_events.py`): new rows from the 3D
   sidecars (no 2D row existed): `bit_warmup` 90 f {8 vo_bellows_yodel, 46 vo_bellows_the_pipes}; `bit_tea` 100 f
   {4 tea_slurp, 17 vo_bellows_pff, 28 vo_bellows_ugh, 58 sniffle}; `st_suspicious` 60 f {10 sniffle −4}; `st_straighten_cravat`
   loop 92 {20 cravat_tug −3}; `mg_comb_flourish` 48 {6 zip −6, 20 sparkle −4}; `mg_cravat_tug` 48 {10 cravat_tug −3,
   27 cravat_ping −4}; `mg_walk_hum` 48 {0 vo_bellows_hum}; `mg_walk_scale` 48 {0 vo_bellows_scales}. The six micro-gags
   with 2D rows keep them exactly (audio "table"). No sound of cues.json is duplicated (head_turn "huh", specs tink,
   doorway "ahem", fizzle "hmph", spotted "wha" stay event-level, ruling L12).
6. **r3d-anim-bellows-a** (`game/data/anim/bellows3d/map.json`, optional): every clip of this key already resolves
   through `view/world/default_maps/bellows.json` with the same ids (`bit:*`, `mg:*`, `oneshot:head_turn|specs_on|
   doorway_pause|look_back|curious_stop|curious_look|bump_look|fizzle`, `activity:curious`, `state:spotted`,
   `reaction_fallback`, `curtain:double_take` via clip_rules). If explicit rows are wanted: `"oneshot:head_turn":
   "bellows/st_head_turn"`, `"oneshot:specs_on": "bellows/st_specs_on"`, `"oneshot:doorway_pause": {"clip":
   "bellows/st_straighten_cravat", "loop": true}`, `"oneshot:look_back": "bellows/st_look_back"`, `"oneshot:curious_stop":
   "bellows/st_suspicious"`, `"oneshot:curious_look": {"clip": "bellows/st_look", "loop": true}`, `"activity:curious":
   {"clip": "bellows/st_look", "loop": true}`, `"oneshot:fizzle": "bellows/st_smirk"`, `"state:spotted":
   "bellows/st_double_take"`, `"bit:*": "bellows/{id}"`, `"mg:*": "bellows/mg_{id}"`.
7. **r3d-anim-bellows-a / r3d-content** (staging, report only): `mg_admire_in_kettle` fires at tea 2.0 s = act_tea f120,
   inside the honey beat (jar lent to grip_l 104–148, spoon in the right glove 104–250, lid flip f126), so the hands
   cannot pat the bouffant or take the kettle. If a later content pass can move the mg's `at_s` to a moment both
   gloves are free, the kettle could be lent to his hand and the gag would read face-on.
8. **r3d-sets** (staging, report only, per the brief): the kettle's home at the stool (house3d `kitchen_kettle`,
   world ≈ (14.40, 0.95, −1.82)) is on his far right-back side when he sits facing −1, so admiring his reflection in it
   turns his face away from the house; the clip now glances at it for 11 f (f 2–13) and plays the vanity + the WINK to the house.
9. **r3d-cast-bellows** (nice to have): a one-eye wink cell (`eyes: wink_l` / mirrored) — the kettle wink today is
   both eyes shut under one cocked brow (`eyes closed` + `brows one_up` slots).
10. **r3d-view3d** (minor): the view shows the specs from the sim's `specs_on` on the one-shot's first tick; the clip
   slaps them on at f4 (`prop show specs`). Either let the one-shot's first 4 f own the prop, or accept the 0.07 s lead.
11. **r3d-rig** (`game/tools/anim3d/sheet3d.gd` lines 124–126): the sheets fail on every OVERLAY clip — `_rig.play()`
   routes an overlay to `play_overlay()`, so `plan()` is null and `plan.length` errors ("Invalid access to property or
   key 'length' on a base object of type 'Nil'"). Play overlays on the base layer for the sheet (or over `loco_idle`).
   13 of this key's 20 clips are overlays (st_head_turn, st_specs_on, st_smirk, the 10 micro-gags): their review is the
   fixed-60-fps captures over the real activities in `docs/review/r3d-anim-bellows-b/boards/` instead.
12. **r3d-view3d / r3d-rig** (`game/view/world/clip_map.gd` `_try`, `RigPlayer3D.set_external_frame`): a frame-locked
   one-shot whose clip LOOPS (`oneshot:doorway_pause`, `curious_look`, `bump_look`) is clamped at the clip's end, not
   wrapped (`clampf(frame, 0, length)`), so a sim duration longer than the loop freezes on its last frame. This key
   sized its loops to the longest sim duration (`st_straighten_cravat` 92 f ≥ 90 − eta + 1; `st_look` 180 = the
   curious look), but a `fposmod(frame, length)` for `loop` rows would make it robust.
13. **r3d-anim** (`game/tools/anim/glb_to_res.gd`, advisory): every extra bone gets a scale track (a constant rest
   scale 1 when the spec never keys it), and `RigPlayer3D` shows a `hidden_bones` bone whenever a playing clip has a
   scale track for it — so an overlay that does not key the FX bones shows the CHOO puff and the dazed stars at full
   size. This key keys `fx_choo` / `fx_stars` / `fx_notes` at scale 0 on every key of its clips (-c does the same);
   dropping constant scale tracks of hidden bones in the converter would make that unnecessary.

## Known gaps
- The face beats of the 14 facing-proof clips wait on the runtime `gaze` (request 1).
- `bit_warmup`'s collar clutch is small at Bellows-window size.
- `mg_conduct_air`'s baton is in the far glove at the gramophone (facing −1).
- The pinkie wobble of `mg_pinkie_up` is ≈ 3 px at phone scale; the sip and the "Ahhh" head roll carry the gag.
- `bit_tea` and the tea micro-gags were checked in the viewer over act_tea. The ideal P00 and g0 routes never play a tea
  squeak, and `mg_pinkie_up` coincides with the ACHOO-RIA! trigger, so neither shows in those in-game runs.
- The rubric scores are my own. No fresh reviewer ran: none is required for this key's list, and the owner pack's
  row 19 is r3d-qa's.

## Hours
≈ 2.2 h active (19:21Z → 21:30Z), of a 10 h box.
