# r3d-anim — fresh-reviewer test of Hush's verbs at 64 px (W1, index R17)

Brief §4.4 W1: *Hush's verb is readable from her body alone at 64 px* — a fresh reviewer, told only the verb list,
names each black silhouette of `verbs_64.png`; the bar is **≥ 11 / 13 named, no two different verbs confused**. This
task has no agent-spawn tool, so (R17) the packet is built here and the orchestrator runs the reviewer. The acceptance
line stays **pending review** until then.

## The packet (one fresh reviewer; never one who has seen this file, the board or the file names)

| Packet | Items | Answer key (outside the packet) |
|---|---|---|
| `docs/review/r3d-anim/packets/verbs_64/` (**v3**, lead 22:15Z re-test) | 13 silhouettes, 64 px tall, black on white, shuffled (seed 19; v2 was seed 41, v1 seed 7): sneak, run, reach high, reach mid, reach low, dive, statue × 4, squeak, bow, snicker | `<SP>/work/r3d-anim/review_key_verbs_v3.json` (earlier keys: `review_key_verbs_v1.json`, `review_key_verbs_v2.json`; the v2 packet is kept in `<SP>/work/r3d-anim/packet_v2/`) |

`<SP>` = `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd`.

**v3 (fix pass 2, lead 22:15Z)** — run 2 scored 10/13: squeak ↔ snicker swapped both ways (both were an upright figure
with bent knees and the gloves at the chest / chin) and the thinker statue read as *reach low* (its crouch hid the
plinth). Changed: squeak = Clarence thrust OUT at arm's length in front of her chest, both fists on him at the end of
straight arms, his neck + beak and flared comb beyond her outline, his body bulging x1.8 between the fists, her body
squashed behind (knees deep, shoulders up) — `act_squeak` f 8, the runtime camera gaze moved to f 9–14 so it no longer
swings the straight arms toward the camera on the sampled frame; snicker = both gloves over the mouth by IK, a hip
hinge into a giggling hunch, the left heel flicked up behind her, the right heel popped — `act_snicker` f 18 (before
its gaze window, f 22–40); the statues' plinth is drawn wider so the crouch cannot swallow it (thinker x1.8, the other
three x1.4 across, √k in height; Verbs3D `:plinth=<k>`). Board: max IoU 0.61 (reach mid / hush-b's statue 7),
squeak / snicker 0.35 (v2 ≈ 0.5). Use a NEW fresh reviewer (never run 1's or run 2's).

**v2 (fix pass, issues.md D12)** — run 1 scored 6/13. Changed: the statues carry the freeze's stone plinth in the mask
(as in game, `plinth.glb`); squeak = the chest-height squeeze with a whole-body squash (`act_squeak` re-authored, f 8);
bow = the deepest hinge, heels together, the free glove flung up behind (`act_bow` re-keyed, f 40); run = a flight frame
with the long split (`loco_run` f 9, the swing reaches further); reach high = both arms up on the step (`rig_achoo_ria`
f 16: the pot in one glove, the other flung up "olé"). Verbs3D no longer cross-fades one cut-out into the next (v1's
cells carried up to 8 f of the previous item's pose), and the cells are flattened black on white. Use a NEW fresh
reviewer (never run 1's).

The silhouettes are frame-locked cut-outs rendered with the game's own `RigPlayer3D` (`game/tools/anim/Verbs3D.tscn`)
looking down −z like the game camera, each clip at its own cheat (performing 35, walking 20, reaching 10), then
normalised by `tools/art3d/review/sil64.py masks` (the same cells as the board). Frames (v3): sneak = `loco_walk` f 13,
run = `loco_run` f 9 (flight), reach high = `rig_achoo_ria` f 16 (the first shake, pot in hand, the other glove up),
reach mid = `rig_allegro_go_go` f 24 (the yank held), reach low = `rig_low` f 72 (r3d-anim-hush-b), dive = `act_dive`
f 8, statues = `freeze_1..4` f 30 on the plinth (x1.4; the thinker x1.8), squeak = `act_squeak` f 8, bow = `act_bow`
f 40, snicker = `act_snicker` f 18 (items: `<SP>/work/r3d-anim/verbs_items_v3.txt`; v2's: `verbs_items_v2.txt`).

Give the reviewer exactly the text of `packets/verbs_64/prompt.md` (it lists the images and the ten verbs). Paste the
verbatim answer into `docs/review/r3d-anim/reviewer_answers_verbs_v3.md` (run 1's and run 2's files stay as they are),
then score:

```bash
SP=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd
python3 tools/art3d/review/packets.py score $SP/work/r3d-anim/review_key_verbs_v3.json \
  docs/review/r3d-anim/reviewer_answers_verbs_v3.md --out=docs/review/r3d-anim/verdict_verbs_v3.md \
  --json=$SP/work/r3d-anim/verdict_verbs_v3.json
```

## Pass and use
- **Pass:** ≥ 11 of 13 correct and no confused pair between different verbs (the four statues all answer *statue*; a
  statue named *bow* or *dive* is a confusion).
- **Fail:** the verdict names the confused pairs; each failing verb goes back to its spec (`tools/art3d/anim/hush/<clip>.py`)
  for a stronger silhouette on the sampled frame — the author's own weakest guesses (v3) are *squeak* vs *reach
  mid* (both have the arms forward at chest height; squeak's tells are the deep squat and the chicken's head + comb
  above the fists — Clarence is only ~0.2 m, so he is ~10 px at 64) and *snicker* vs *sneak* (both lean forward on
  one foot; snicker's tells are the gloves at the face and the heel flicked up BEHIND her, where a sneak's knee steps
  forward).
- The IoU matrix on the board is the objective half: no pair of the 18 silhouettes (with r3d-anim-hush-b's rummage and
  statues 5–8) reaches 0.80 (`verbs_64.json` v3, max 0.61: reach mid / statue 7; v2 max 0.64, v1 0.61).
