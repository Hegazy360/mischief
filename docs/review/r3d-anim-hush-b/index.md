# r3d-anim-hush-b — review index

Hush's remaining 18 clips on the 3D pipeline (brief `r3d-anim-hush-b`). All are baked, lint `--strict` clean, and
none is a draft. There is one line per artefact: what it shows, then what to judge. The sheets come from
`tools/scripts/anim_sheet3d.sh` (the game's RigPlayer3D, studio camera). The in-set frames come from `ViewSandbox3D --sim`
(the real N1/N2 sets) or from `AnimViewer3D --room --episode` (the real set at a chosen spot).

## Per clip — `sheets/`
For each clip there are seven files: `<clip>_contact.png` (cells every 3 f plus the beat boundaries, events under the
cells), `<clip>_onion.png` (the arcs), `<clip>_curves.png` / `.json` (the per-bone curves), `<clip>_sil64.png` (64 px
silhouettes), `<clip>_phone.jpg` (the 1200×540 game framing every 3 f) and `<clip>_lint.txt` (the 3D lint).

- `loco_arrive` (8 f, FINAL): the walk ends in a small hop and a landing dip. Judge whether the hop reads at game scale (f 3–6).
- `rig_mid` (96 f): three crank rounds, each ending in a tug (28 / 52 / 76), then the foot brace (72–88). Judge the crank rhythm.
- `rig_high` (120 f): pats an invisible rail, tests the invisible step with a toe, hops up (27), cranks overhead, steps down (110).
  Judge whether "standing on nothing" reads.
- `rig_low` (144 f): plops onto her knees (10), works on all fours with a waggling foot, boings up (132). Judge the plop and the crawl.
- `loco_skid` (6 f): heel dug in, gloves flung (f 2–3). Judge the brake shape.
- `idle_fidget_look` / `idle_fidget_proud` / `idle_fidget_clarence` (80 / 84 / 80): listen and peer; fists on hips and ta-da;
  Clarence pops up, shush, pat. Judge whether each is one clear idea.
- `act_rummage` (loop 36): folded into a container, legs kicking. Judge the legs-in-the-air read.
- `act_wheeze` (loop 60): squeezes Clarence at her chin, the strain down to the knees (f 40), then a gasp (48). Judge whether
  the squeeze reads with a chicken this small.
- `st_yanked` (36): the hook from the wings: stretched flat 7–22, lands dazed 27. Judge the yank pop (5–7).
- `freeze_5` … `freeze_8` (150 each): hat-tip, ballerina en pointe, lamp post, scarecrow. Judge the snap (2–5) and the hold.
- `act_glance_lint.txt`: the lint for the head-mask overlay. The sheet renderer crashes on overlay clips (reported to r3d-rig),
  so `act_glance` and `st_shrug` are shown by the two overlay captures below.

## Boards
- `bands.png`: each band clip in the real N1/N2 sets at 1:1 crops, re-shot with r3d-sets' `reach_pos` of 20:42 (mid: kettle,
  fridge shelf; high: pickle jar, clock, mirror; low: recliner). Judge whether a muted player can tell what she is doing
  to the prop. The kettle, the jar, the clock face and the chair are now under her gloves; the mirror is still mostly
  behind her.
- `bands_frames.jpg`: the same six moments as full 1200×540 frames (at ½; `ViewSandbox3D --sim`, the ideal routes). Judge the
  read at phone framing.
- `bands_staged.jpg`: the kettle, the tap, the clock and the recliner, each at the 19:59 `reach_pos` (left) and at the
  proposed spot (right: the prop 0.24–0.30 m ahead and 0.2 m upstage of her, from the sidecar `reach_offset`). Judge whether the
  proposed spot makes the job read.
- `bands_staged_strips/`: the three band clips, `rig_mid` at the sink tap, `rig_high` at the clock and `rig_low` at the
  recliner. Each has 8 frame-locked 1200×540 frames cropped around her, labelled with clip frame numbers. `now_*` is at
  the 19:59 `reach_pos` and `staged_*` at the proposed spot. Judge the same question as `bands.png`. These strips are the
  mute-test items.
- `statues_8.png` + `statues_8.json`: all eight statues (`freeze_1..4` by r3d-anim, `5..8` here) as 64 px black masks, with the
  pairwise IoU matrix. Judge that no pair reaches 0.80 (the closest pair is printed in the JSON).
- `statues_8_marble.png`: the same eight statues as marble (`--stone`), studio front view. Judge whether each reads as a pose.
- `freeze_midjob_variants.png`: the three held segments of `freeze_midjob` (mid f 0, high f 360, low f 480) in the game framing.
  Judge whether each is recognisably "caught mid-job".
- `idles.png`: the three fidgets in game framing in the kitchen, every 3 f. Judge the faces at cheat 35.
- `act_glance_over_rig_mid.jpg`: `act_glance` as a head overlay over `rig_mid`. Judge whether only the head moves and the snap reads.
- `st_shrug_over_idle.jpg`: `st_shrug` as an upper-body overlay over the idle. Judge the palms-up shrug at 6–14.

## Text
- `rubric.md`: the TECH §11 rubric per clip, with frame numbers and scores (the author's pass).
- `reviewer_prompt.md`: the fresh-reviewer mute test of the band clips (R17). It is pending, because the orchestrator runs it.
- `packets/bands_now/`, `packets/bands_staged/`: the opaque packets for that test, made by `packets.py build`, each with a
  `prompt.md`. The answer keys are outside the repo, in the task scratch.
