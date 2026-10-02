# r3d-polish-take: Bellows' double take, no more T-pose (D19 pre-send polish, Q3-G1 part 1)

QA round 3 (`docs/review/r3d-qa/readability.md` Round 3, pkt_01 and pkt_07): `bellows/st_double_take` held a pose
with both arms straight out at shoulder height. All three gag reviewers read it as a "broken T-pose" in the relief beat
(P00 p00i 3196–3265, frames f9–39). One also saw it at the curtain call (f360). Before: `docs/review/r3d-fix-gags2/after/relief_{1,2}.jpg`.

## Cause
The clip itself, not a view fallback. Its `TAKE_ARMS` keyed `upperarm y 58 / z -52`. The rig's `arm_out` layer
(+40° abduction, added after the keys) turned that into arms almost horizontal. Both stagings hold the clip's last frame:
`cue_stager_3d.gd` `stage_hold(st_double_take, left + 8)` (~48 f) and the curtain apron's
`pose_bellows(…, st_double_take, loop=false)` until the slow burn. So the bad pose was the one on screen for the whole hold.

A second fault was found while looking. The sidecar gaze window `[8, 18]` with blend 2 fades to weight 0 exactly at
f18 (`ClipDef3D.gaze_weight`), and the held last frame is f18. So during every hold his face turned away from the
camera (the "blank face" and "the cravat covers his mouth" notes).

## What changed (`tools/art3d/anim/bellows/st_double_take.py` → `.res` + sidecar; length 18, lock null, beats unchanged)
- **0–3 the glance**: a bored nod at the thing.
- **3–8 the look away**: chin down and turned off, knees soft, shoulders drop. The gloves sink to the belly front
  (IK, chest-carried), so the anticipation goes DOWN.
- **9 the SNAP (pop)**: the head whips back with the face to camera. The shoulders jerk up (clavicle shrug) and the
  barrel pulls back (lean −14, chin up −20). Both gloves fly up and tuck against the chest on either side of the jabot,
  below the chin: palms out, fingers splayed and tilted out, elbows bent at his sides. The face goes `shock` → `wild_take`.
- **9–13** one overshoot (shoulders highest), then the settle. **13–18** a held, trembling take.
- **Gaze (D8)**: two windows. `[7, 11]` blend 2 brings the face in, and `[9, 18]` blend 0 keeps it at full weight
  through the held last frame. The face stays on the camera for the whole hold now.
- **Baton**: the warm-up baton is still in his right glove during the hunt (`act_warmup` shows it, and nothing before
  the relief hides it). The take turns that wrist so the stick points out and down, away from his face.
- L18 silhouette change (anticipation → accent) 37 % (bar 15 %), no IK misses.

## Frames (real game, `e2e.sh prologue_ideal --fixed`, 1200×540, `--no-captions`, MSAA off; engine frames ≈ tick)
- `p00_relief_t3192-3270.jpg`: the relief window, every 3 frames. Glance 3192–3201, look away 3204–3210,
  snap 3213, take held with the face to camera to 3243, then the cue and the walk-off.
- `p00_relief_take_zoom.jpg`: glance / look away / sink / snap / hold / release, cropped at full size.
- `curtain_call_t3900-3990.jpg`, `curtain_call_take_zoom.jpg`: the curtain-call bit (wander on → double take →
  slow burn), every 3 frames.
- `bench_take_both_facings.jpg`: AnimViewer3D in the parlour, facing +1 (top) and −1 (bottom), with the baton held,
  f3/6/8/9/11/18.

## Checks
`bake.sh bellows st_double_take --strict` OK. `anim3d/test_bellows_clips3d` 11/0, `view3d/test_gag_staging3d`
17/0, `night/` 133/0. `lint.sh --strict` OK (72 scope clips 0/0). Full suite 1351/0, run after the gaze fix and before
the last glove and wrist moves, which changed no sidecar field. `e2e prologue_ideal --fixed` PASS, 0 clip fallbacks.

## Not changed (other owners, still open from Q3-G1)
- The hold itself stays frozen after f18: the view holds the last frame for ~30 f (the clip length is locked).
  If the hold should move, the fix is view-side: loop a tremble or play a held clip.
- The "phew" puff stack, the walk-off foot slide, the gramophone horn behind his head (`hide_spot_3d.gd`,
  `cue_stager_3d.gd`).
- The baton could be put away before the near miss, e.g. a `prop hide` in `act_hunt` (anim-bellows-c).
