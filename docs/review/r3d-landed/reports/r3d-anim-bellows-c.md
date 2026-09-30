# r3d-anim-bellows-c — report (Bellows' 10 Prologue-only clips in 3D)

All 10 clips on my list are baked, lint `--strict` clean and in `game/`, with a DONE line each. None is a draft: the
R19 cut line was never reached (2.4 h of a 12 h box). The dizzy spin, the Prologue's second prank, landed first and
plays in the real game. It scores 4/4/4 (funny / readable / fresh), which meets the ≥ 4 bar. Every other clip scores
≥ 3.

This run was resumed (R16). It picked up after review pass 2 and did three things:
- Finished the review sheets.
- Found and fixed a facing bug in `beat_dignity_fail`: its "ahem" survey showed the back of the wig in one facing.
- Ran the final checks and wrote the review index.

## Files built (all under my §2 ownership)
- Specs: `tools/art3d/anim/bellows/{rx_dizzy_spin_a, cue_doorframe_bonk, cue_picture_bonk, bit_livid, loco_stomp,
  act_hunt, mg_peer_under_piano, beat_dignity_fail, beat_bow_topple, beat_tear}.py`. They import `_lib.presets`
  read-only.
- Bakes: `game/art3d/anim/bellows/<clip>.res`, 656 KB for all 10 (largest `act_hunt` 143 KB, under the 250 KB limit).
- Sidecars: `game/data/anim/bellows3d/<clip>.json`.
- Review folder: `docs/review/r3d-anim-bellows-c/` (15 MB), containing `index.md`, `rubric.md`, `dizzy_strip.png`,
  `dizzy.gif` + `dizzy_mute.gif` (0.56 MB), `cue_doorframe_bonk_strip.png`, `cue_picture_bonk_strip.png`,
  `boards/{ingame_dizzy, ingame_cues, peer_under_piano, dignity_facings}.jpg` and `sheets/` (sheets for the 7 base
  clips, lint files for all 10).

## Clip table
All clips are hand-keyed specs in the Blender pose language (sidecar `source: custom`, no UAL). All run at 60 fps.
Hours are approximate, taken from the LANDED.md timeline.

| # | Clip | Frames | Layer | Timing / sounds | FINAL / draft | Score f/r/fr | ≈ h |
|---|---|---|---|---|---|---|---|
| 1 | `rx_dizzy_spin_a` | 169 | base, `lock: sim` | reactions.json beats: antic 70 / accent 86 / hold 89–149 / release 169, plus the 7 named beats; cam punch 1.4, hit-stop 5; sounds are the clip's own (no table row) | FINAL | 4/4/4 | 0.9 |
| 2 | `cue_doorframe_bonk` | 36 | overlay `upper` (over `loco_blind_shuffle`) | table: `woodblock_bonk` 4, `vo_bellows_oof` 7 | FINAL | 3/3/3 | 0.2 |
| 3 | `cue_picture_bonk` | 48 | overlay `upper` (over `loco_stomp`) | own: `bonk` 12, `vo_bellows_hmph` 40 | FINAL | 3/3/3 | 0.2 |
| 4 | `bit_livid` | 120 | base, `lock: sim` | own: `vo_bellows_who_squeaked` + `stomp` 30, `meltdown_stomp` 57 (the clip owns the bit's voice) | not a draft | 4/4/3 | 0.25 |
| 5 | `loco_stomp` | 26 loop | base (`walk@tier3`) | 1.38 m/s, stride 0.598 m; own: `stomp` 0 / 13 | not a draft | 3/4/3 | 0.15 |
| 6 | `act_hunt` | 180 loop | base (`activity:hunt`) | halves match the sim's 1.5 s search turns; own: `creak` 0 / 90 | not a draft | 3/3/3 | 0.25 |
| 7 | `mg_peer_under_piano` | 60 | overlay `upper` | own: `vo_bellows_hmm` 38 | not a draft | 3/3/3 | 0.1 |
| 8 | `beat_dignity_fail` | 70 | base (T3 last beat) | table: `cravat_tug` 2, `vo_bellows_ahem` 34, `cravat_ping` 60 | not a draft | 3/3/3 | 0.25 |
| 9 | `beat_bow_topple` | 60 | base (T3 last beat) | table: `bow_creak` 4, `slide_down_short` 30, `slip_thud` 34 | not a draft | 4/4/4 | 0.1 |
| 10 | `beat_tear` | 60 | base (T3 last beat) | table: `sad_violin` 0, `tear_plink` 24, `sniffle` 42 | not a draft | 3/3/3 | 0.1 |

The other ≈ 0.3 h went to review passes, captures, the in-game check and this report. DONE lines, as appended to
LANDED.md: dizzy `0b51e6b6…`, doorframe `008c053f…`, picture `d9a5a0b1…`, livid `b3ee3b57…`, stomp `15acc9c0…`,
hunt `be2fa229…`, peer `2147da33…`, dignity `c9926aff…`, bow `d084cc5e…`, tear `1cf774c4…`. Each is the sha256 of the
current spec; LANDED.md has the full values.

## Verification
- Full suite (`tools/scripts/test_game.sh r3d-anim-bellows-c`): 1501 passed, 2 failed, 0 skipped.
  - Both failures are `rig3d/test_gaze_3d.gd` (`test_camera_left_and_right`, `test_viewport_camera_pupils_and_clamp`).
    This is r3d-rig's sidecar-gaze work, still in progress: `rig_gaze_3d.gd` and the test are untracked files written
    at 21:31Z. Not in my area.
  - `anim3d/test_bellows_clips3d` (owned by -a, covers all 42 clips) passes 9/9 with 0 skips, so all 10 of my clips
    are checked by it.
- `SANDBOX=r3d-anim-bellows-c tools/scripts/lint.sh` returns 0: 3D anim lint 77 clips, 0 errors; content, hotspot and
  ip all OK.
- `lint_anim.gd --format=3d --rig=bellows --scope=g0,p00 --strict`: 42 clips, 0 errors, 0 warnings, 0 missing.
- In game (review pass 2, 21:17Z): `e2e.sh prologue_ideal` ran twice, PASS, 0 fallbacks. The dizzy spin, both cue
  bonks, the stomp and the hunt all play in P00 (`boards/ingame_*.jpg`).
- Every sound id my clips emit exists in `game/audio/sfx_map.json`.
- Looked at, at phone scale:
  - the dizzy strip and GIF;
  - both cue strips, every frame;
  - the peer board;
  - the two-facing dignity board;
  - the facing +1 phone sheets of all 7 base clips.

## What this run changed (review pass 3)
- **`beat_dignity_fail` now works in both facings.** The rig turns the whole body to face left or right; it does not
  mirror the clip. So a head turn that shows his face in one facing hides it in the other. The sheets render facing
  +1; all my earlier captures were facing −1. In facing +1, the survey's 26° turn put the back of the wig to the
  camera for f30–36, right on the "ahem". The turn is now 12° each way (spine 4° + head 8°). Checked at the game
  camera in both facings (`boards/dignity_facings.jpg`): the face stays in profile or 3/4 in facing +1 and turns
  full-on on the "ahem" in facing −1. Re-baked, lint clean, re-sheeted.
- **The other either-facing clips, checked in the other facing:**
  - `bit_livid` holds up (only f84–93 half-hides the face).
  - `act_hunt`: one of its two low peers always faces away (f96–120 in facing +1, f0–36 in facing −1). It reads as a
    nose-to-the-floor "look over there", not a face beat, so I left it. The rubric lists it as a weak spot.
- **Overlay clips have no sheets**, because the sheet tool has no overlay mode. They are reviewed over their base clip
  instead: the two cue strips and a new peer board, `boards/peer_under_piano.jpg`.

## Deviations
None on timing. Every length matches the manifest, every timed beat is within ±2 f of `reactions.json`, and every
table sound is on its table frame. No retime requested. Clips with no audio-table row carry their own sounds; the lint
reports them as INFO rows for r3d-integrate, listed below.

## Requests
1. **r3d-anim-bellows-a, `game/data/anim/bellows3d/map.json`.** Add the -c rows now that the DONE lines are in:
   - `"walk@tier3": {"clip": "bellows/loco_stomp", "stride_m": 0.598, "speed_m_s": 1.38, "stride_px": 120, "speed_px_s": 276}`
   - `"activity:hunt": "bellows/act_hunt"`
   - `"cue:laugh_doorframe": "bellows/cue_doorframe_bonk"`
   - `"cue:laugh_picture": "bellows/cue_picture_bonk"`

   Today these fall back to `view/world/default_maps/bellows.json`, whose `walk@tier3` has no 3D gait values.
   `bit:livid`, `mg:peer_under_piano`, the dizzy reaction and the T3 last beats already resolve (through `bit:*`,
   `mg:*`, `reaction` and `reactions.json t3_last_beats`).
2. **r3d-view3d, `game/view3d/world/cue_stager_3d.gd:105`.** Change `socket_node("head")` to
   `socket_node("head_top")`. Bellows' rig has no `head` socket (`rig3d.json`: grip_r, grip_l, mouth, head_top,
   nose_tip, face, …), so the falling picture frame is lent to his root and never hangs on him. Without the frame,
   `cue_picture_bonk`'s look-down reads as "ow, my head" (readable 3; 4 with the frame).
3. **r3d-rig, `game/tools/anim3d/sheet3d.gd` `_mode_clip`.**
   - After the bounds pre-pass it calls `_rig.reset(); _rig.play(cid, opts)` without `blend_in: 0`. The pose is still
     at the last frame, so f0–f7 of every base-clip sheet crossfade from the clip's end pose. This affects every key's
     sheets; the AnimViewer strips are correct.
   - A `--base=<clip>` overlay mode would give the overlays proper sheets.
4. **r3d-rig and r3d-view3d: sidecar `gaze` and the clip's `cheat_deg`.** This repeats the requests from r3d-anim and
   -a. The work is in progress (`rig_gaze_3d.gd`).
   - My gaze windows: dizzy 8–36 (1.0), 92–147 (0.6), 160–169 (0.8); picture 30–40 (1.0); livid 80–108 (0.5);
     hunt 38–60 and 128–150 (0.8); dignity 30–44 (0.9), 56–70 (0.7); bow 0–26 (0.8); tear 0–60 (0.9).
   - Once gaze lands, the face beats should read better than in my captures, which ran without it. The in-game strips
     should be re-shot then (r3d-integrate / r3d-qa).
5. **r3d-integrate, `game/data/audio/clip_events.json`.** Add rows for the sounds these clips carry themselves:
   - `rx_dizzy_spin_a`: 0 `record_scratch`, 12 `vo_bellows_dizzy_babble`, 40 `spin`, 88 `thud`, 89 `dizzy_tweets`,
     149 `vo_bellows_ugh`
   - `cue_picture_bonk`: 12 `bonk`, 40 `vo_bellows_hmph`
   - `bit_livid`: 30 `vo_bellows_who_squeaked`, 30 `stomp`, 57 `meltdown_stomp`
   - `loco_stomp`: 0 `stomp`, 13 `stomp`
   - `act_hunt`: 0 `creak`, 90 `creak`
   - `mg_peer_under_piano`: 38 `vo_bellows_hmm`

## Pipeline issues (for r3d-anim / r3d-rig)
- The sheet crossfade and the missing overlay mode (request 3).
- In AnimViewer captures (`capture.sh`), file 0 is the rest pose before the first advance: arms out, FX bones at rest
  scale, so the CHOO puff and stars show. Clip frame 0 is file 1. It only affects raw captures; my strips skip it.
- The rig turns the body for each facing; it does not mirror the clip. So a head turn baked into a clip only faces the
  camera in one facing. Until sidecar gaze is honoured, clips that play in either facing must keep glances small
  (≤ ≈ 12–24°).

## Known gaps
- The picture frame does not hang on him in game (request 2).
- The doorframe rub reads less in game than in the strip, because the view turns him back into the walk after about
  1 rendered frame.
- The dizzy spin's raised-legs V mostly hides behind his body at the game camera.
- The cravat is small at the game camera.
- `beat_tear`'s tear is a face-card beat; the face is about 25 px on screen.

All of these are in the rubric with frame numbers.

## Hours
2.4 h active (19:15Z → 21:37Z) of the 12 h box. No drafts.
