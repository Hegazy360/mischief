# r3d-cast-bellows: fresh-reviewer face read test (R17 fallback)

The brief's face bar needs a fresh reviewer who does not know the presets: 6 unlabelled 1× crops (pompous,
suspicious, shock, furious at temper tier 3, sneeze_build, dazed, shuffled) and a list of 10 names. **Pass = ≥ 5/6
correct and no two crops confused with each other.** This task has no agent-spawn tool, so (R17) the packets are
built here and the orchestrator runs the reviewers.

## What to run (two packets, one fresh reviewer each; never the same reviewer twice, never with this file)

| Packet | Condition | Answer key (outside the packet) |
|---|---|---|
| `docs/review/r3d-cast-bellows/packets/faces_c35/` | the idle cheat 35° alone (the face 55° off frontal) | `<SP>/work/r3d-cast-bellows/review_key_c35.json` |
| `docs/review/r3d-cast-bellows/packets/faces_face/` | cheat 35° + RigPlayer3D `look_at_point(camera, 1.0)` (head yaw clamp 35°) | `<SP>/work/r3d-cast-bellows/review_key_face.json` |

`<SP>` = `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd`.

The crops are 124×124 px, 1× from 1200×540 base-framing renders (FOV 30°, KEEP_HEIGHT, camera (x, 1.9, 6.5)) in
r3d-sets' kitchen (episode p00_curtain_up), Bellows at z −1.4 facing left, the game's RigPlayer3D + char_toon.

For each packet, give a fresh reviewer only the text of `<packet>/prompt.md`. It names the folder and the answer
format. Paste each reviewer's verbatim answer lines into `docs/review/r3d-cast-bellows/reviewer_answers_<c>.md`, then
score:

```bash
SP=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd
for c in c35 face; do
  python3 tools/art3d/review/packets.py score $SP/work/r3d-cast-bellows/review_key_$c.json \
    docs/review/r3d-cast-bellows/reviewer_answers_$c.md --out=docs/review/r3d-cast-bellows/verdict_$c.md \
    --json=$SP/work/r3d-cast-bellows/verdict_$c.json
done
```

Aliases used in scoring (`<SP>/work/r3d-cast-bellows/review_aliases.json`): pompous = haughty/snooty/proud/superior/
smug/arrogant; angry = furious/livid/mad/cross; sneeze = sneezing/about to sneeze/achoo; shock = shocked/surprised/
startled; dazed = dizzy/confused/stunned/woozy; suspicious = skeptical/doubtful/wary/squinting.

## How the verdict is used

- The expected result, from looking at the renders (`face_turn.png`): at the bare cheat 35° the far eye sits on the
  silhouette edge and the mouth wraps round the jowl, so pompous, suspicious and sneeze_build look alike; with the
  head turned to the camera all six read. If `faces_face` passes and `faces_c35` does not, the build is fine and the
  request below stands. If both fail, the face atlas needs another pass (bigger eye whites, or EYE_X pulled in, in
  `tools/art3d/bellows/face_atlas.py`).
- Request (r3d-view3d / r3d-anim-bellows): every Bellows face beat (a reaction, a sniff, a sneeze build, a temper
  tier change) calls `look_at_point(camera, 1.0)` for its length, or eases the cheat to ≥ 45°. The descriptor keeps
  the §5.1 cheat (idle 35).
