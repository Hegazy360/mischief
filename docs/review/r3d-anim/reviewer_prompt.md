# r3d-anim — fresh-reviewer test of Hush's verbs at 64 px (W1, index R17)

Brief §4.4 W1: *Hush's verb is readable from her body alone at 64 px* — a fresh reviewer, told only the verb list,
names each black silhouette of `verbs_64.png`; the bar is **≥ 11 / 13 named, no two different verbs confused**. This
task has no agent-spawn tool, so (R17) the packet is built here and the orchestrator runs the reviewer. The acceptance
line stays **pending review** until then.

## The packet (one fresh reviewer; never one who has seen this file, the board or the file names)

| Packet | Items | Answer key (outside the packet) |
|---|---|---|
| `docs/review/r3d-anim/packets/verbs_64/` | 13 silhouettes, 64 px tall, shuffled (seed 7): sneak, run, reach high, reach mid, reach low, dive, statue × 4, squeak, bow, snicker | `<SP>/work/r3d-anim/review_key_verbs.json` |

`<SP>` = `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd`.

The silhouettes are frame-locked cut-outs rendered with the game's own `RigPlayer3D` (`game/tools/anim/Verbs3D.tscn`)
looking down −z like the game camera, each clip at its own cheat (performing 35, walking 20, reaching 10), then
normalised by `tools/art3d/review/sil64.py masks` (the same cells as the board). Frames: sneak = `loco_walk` f 13,
run = `loco_run` f 3, reach high = `rig_achoo_ria` f 16 (the first shake, pot in hand), reach mid =
`rig_allegro_go_go` f 24 (the yank held), reach low = `rig_low` f 72 (r3d-anim-hush-b), dive = `act_dive` f 8,
statues = `freeze_1..4` f 30, squeak = `act_squeak` f 9, bow = `act_bow` f 40, snicker = `act_snicker` f 24.

Give the reviewer exactly the text of `packets/verbs_64/prompt.md` (it lists the images and the ten verbs). Paste the
verbatim answer into `docs/review/r3d-anim/reviewer_answers_verbs.md`, then score:

```bash
SP=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd
python3 tools/art3d/review/packets.py score $SP/work/r3d-anim/review_key_verbs.json \
  docs/review/r3d-anim/reviewer_answers_verbs.md --out=docs/review/r3d-anim/verdict_verbs.md \
  --json=$SP/work/r3d-anim/verdict_verbs.json
```

## Pass and use
- **Pass:** ≥ 11 of 13 correct and no confused pair between different verbs (the four statues all answer *statue*; a
  statue named *bow* or *dive* is a confusion).
- **Fail:** the verdict names the confused pairs; each failing verb goes back to its spec (`tools/art3d/anim/hush/<clip>.py`)
  for a stronger silhouette on the sampled frame — the author's own weakest guesses are *snicker* (gloves at the chin,
  knees knocked, heel popped), *squeak* (the chicken hoisted high, a knee kicked) and *reach mid* (the lever yank is a
  lean away from the camera; its gloves read against the gramophone in the set, not in silhouette).
- The IoU matrix on the board is the objective half: no pair of the 18 silhouettes (with r3d-anim-hush-b's rummage and
  statues 5–8) reaches 0.80 (`verbs_64.json`, max 0.61: snicker / statue 7, snicker / statue 8, run / snicker).
