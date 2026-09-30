# r3d-cast-hush — fresh-reviewer face read test (ruling R6 / R17)

The brief's head-check bar (§4.3) needs a fresh reviewer who does not know the presets: 6 unlabelled 1× crops
(neutral, sneak, shock, snicker, fear, dazed, shuffled) and a list of 10 names; **pass = ≥ 5/6 correct and no two crops
confused with each other**. This task has no agent-spawn tool, so (R17) the packets are built and the orchestrator runs
the reviewers.

## What to run (four packets, one fresh reviewer each — never the same reviewer twice, never with this file)

| Packet | Condition | Answer key (outside the packet) |
|---|---|---|
| `docs/review/r3d-cast-hush/packets/faces_b_c35/` | B's head (head_scale 1.0), the idle cheat 35° (face 55° off frontal) | `<SP>/work/r3d-cast-hush/review_key_b_c35.json` |
| `docs/review/r3d-cast-hush/packets/faces_b_face/` | B's head, the face given to the camera (cheat 35° + a 25° head turn) | `<SP>/work/r3d-cast-hush/review_key_b_face.json` |
| `docs/review/r3d-cast-hush/packets/faces_hb_c35/` | head ×1.2 (`head_b`), cheat 35° | `<SP>/work/r3d-cast-hush/review_key_hb_c35.json` |
| `docs/review/r3d-cast-hush/packets/faces_hb_face/` | head ×1.2, the face given to the camera | `<SP>/work/r3d-cast-hush/review_key_hb_face.json` |

`<SP>` = `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd`.

For each packet: give a fresh reviewer exactly the text of `<packet>/prompt.md` (it names the folder and the answer
format; the crops are 100×108 px, 1× from 1200×540 base-framing renders in the kitchen). Paste each reviewer's verbatim
answer under its packet heading in `docs/review/r3d-cast-hush/reviewer_answers.md`, then score:

```bash
SP=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd
for c in b_c35 b_face hb_c35 hb_face; do
  # one answers file per packet (the answer sheet lines pkt_01: … of that reviewer)
  python3 tools/art3d/review/packets.py score $SP/work/r3d-cast-hush/review_key_$c.json \
    docs/review/r3d-cast-hush/reviewer_answers_$c.md --out=docs/review/r3d-cast-hush/verdict_$c.md \
    --json=$SP/work/r3d-cast-hush/verdict_$c.json
done
```

## How the verdict is used

- The measured bar (`head_check.json`): B's head fails head height (54.5 px < 60) in every view and the face-card width
  even with the face turned to the camera; ×1.2 is the smallest scale that passes every measured bar with the face given
  to the camera. The read test decides whether that holds for a human: if `faces_b_*` already reads ≥ 5/6 with no
  confused pair, B's head reads and the owner question is lighter; if only `faces_hb_*` passes, ×1.2 is confirmed.
- The owner question (O3, in the owner pack): "Keep B's head (reads at …), or grow it ×1.2 (reads at …)?" — the build keeps
  B's head (`rig3d.json`, head_scale 1.0) until he answers; the alternate is variant `head_b`
  (`rig3d_head_b.json` + `hush_head_b.glb`).
