# r3d-anim — review index

The 3D animation pipeline (A0) and Hush's 17 FINAL clips (A1). Everything below is rendered with the game's own
`RigPlayer3D` (frame-locked) on the frozen Hush skeleton; every clip lints `--strict` clean.

| artefact | what it shows | what to judge |
|---|---|---|
| `rubric.md` | the author's TECH §11 pass per clip, with frame numbers, and the known limits | do the numbers match the sheets? is a *funny* < 3 a utility clip? |
| `verbs_64.png` / `verbs_64.json` | the W1 board **v3** (fix pass 2, lead 22:15Z): 13 verbs (+ r3d-anim-hush-b's rummage and statues 5–8) as black silhouettes 64 px tall, 1× and 2×, statues on the plinth (wider for the crouches), squeak held out at arm's length, snicker = gloves over the mouth + hip hunch + heel flick, with the IoU matrix (max 0.61; no pair ≥ 0.80; squeak/snicker 0.35) | can each be named from the verb list alone? |
| `reviewer_prompt.md`, `packets/verbs_64/` | the R17 packet v3 for a NEW fresh reviewer (13 shuffled silhouettes, seed 19, the verb list; key outside the repo). Run 1 (v1): `verdict_verbs.md` 6/13 FAIL; run 2 (v2): `verdict_verbs_v2.md` 10/13 (squeak ↔ snicker, a statue → reach low) | **pending review (v3)** — the orchestrator runs it; bar ≥ 11/13 |
| `achoo_kitchen.jpg` | ACHOO-RIA! in the P00 kitchen (House3D, game camera, x 14.85 z −1.42 facing −1 cheat 10): hop, lean-out snatch, swing, shakes 16 / 26 / 36, put-back, hop down | the joke set up in view: the pot over the jar, her face to us |
| `achoo_kitchen_pot.jpg` | the same with her pepper pot forced `held` (the frame-locked viewer does not replay prop events), close crop | the pot tipped over the jar mouth on the shakes |
| `allegro_parlour.jpg` | ALLEGRO-GO-GO! at the gramophone (x 7.8 z −1.3 facing +1 cheat 10): eyes it, grips, yanks, holds with the face to us | both gloves on the red knob; the yank's weight (the parlour wall end overlaps her back f 9–19: a staging request) |
| `gate0_path.jpg` | the Gate-0 Hush path in the real kitchen: sneak to the honey → the rig with the pepper pot → snicker → run → dive into the pantry → pop out | a muted player can follow it |
| `sheets/<clip>_contact.png` | every 3 f + beat boundaries, events under the cells (r3d-rig's `anim_sheet3d.sh`) | spacing, poses, accents |
| `sheets/<clip>_phone.jpg` | the 1200×540 game framing every 3 f (r3d-rig's fixed crop cuts a stepped clip — rig_achoo_ria on the stool — above the knees: judge that one on `achoo_kitchen.jpg`) | readability at phone scale |
| `sheets/<clip>_onion.png`, `_curves.png`, `_sil64.png`, `_lint.txt` | arcs, angular speed, 64 px silhouettes at the beats, the lint | smooth arcs, one overshoot, the pops where declared |
| `audio_rows.md` | every `audio="own"` clip's sound rows (all keys) for `r3d-integrate` to regenerate `clip_events.json` | lengths and contact frames |

Clips: `loco_idle` (loop 240), `loco_walk` (loop 54, 2.0 m/s, stride 1.80), `rig_achoo_ria` (48, rig_pm),
`rig_step_down` (8), `act_snicker` (60), `act_dive` (15), `act_pop` (15), `freeze_1..4` (150), `act_squeak` (18),
`loco_run` (loop 24, 3.6 m/s), `loco_turn` (6), `act_climb_in` (60), `rig_allegro_go_go` (48, rig_pm), `act_bow`
(loop 150). Specs `tools/art3d/anim/hush/<clip>.py`; sidecars `game/data/anim/hush3d/<clip>.json`; map
`game/data/anim/hush3d/map.json`; tests `game/tests/anim3d/test_hush_clips3d.gd`. Pipeline: `tools/art3d/anim/README.md`.
