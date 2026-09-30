# r3d-anim-hush-b — fresh-reviewer mute test of the band clips (R17)

Brief §6 asks of `bands.png`: "can a muted player tell what she is doing to the prop?" A fresh reviewer should answer that,
not the author. This task has no agent-spawn tool, so (R17) the packets are built here and the orchestrator runs the
reviewers. The acceptance line stays **pending review** until then.

## The two packets (one fresh reviewer each; never the same reviewer twice, never with this file)

| Packet | Condition | Answer key (outside the packet) |
|---|---|---|
| `docs/review/r3d-anim-hush-b/packets/bands_now/` | the three band clips (`rig_mid` at the sink tap, `rig_high` at the clock on the mime step, `rig_low` at the recliner) at the **19:59** `house3d.json` `reach_pos` (before r3d-sets applied the proposed spots) | `<SP>/work/r3d-anim-hush-b/review_key_now.json` |
| `docs/review/r3d-anim-hush-b/packets/bands_staged/` | the same three clips at the **proposed** spot: the prop 0.24–0.30 m ahead of her and 0.2 m upstage (the sidecar `reach_offset`). The tap and clock spots are what `house3d.json` has had since 20:42 | `<SP>/work/r3d-anim-hush-b/review_key_staged.json` |

`<SP>` = `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd`.

Each item is a numbered strip of 8 frame-locked 1200×540 frames of the real N1 / N2 set, cropped around Hush. The frames
are clip frames; 60 = 1 s. Give the reviewer exactly the text of `<packet>/prompt.md`. The reviewer answers, for each id,
what the mime is doing and to which object, in a few words. Paste each reviewer's verbatim answer into
`docs/review/r3d-anim-hush-b/reviewer_answers_<now|staged>.md`, then score:

```bash
SP=/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd
for c in now staged; do
  python3 tools/art3d/review/packets.py score $SP/work/r3d-anim-hush-b/review_key_$c.json \
    docs/review/r3d-anim-hush-b/reviewer_answers_$c.md --out=docs/review/r3d-anim-hush-b/verdict_$c.md \
    --json=$SP/work/r3d-anim-hush-b/verdict_$c.json
done
```

## Pass and use

- **Pass** = the reviewer names the object she works on for 3 of 3 items. The aliases are sink/tap/faucet, clock, and
  armchair/chair/recliner.
- If `bands_staged` passes and `bands_now` does not, the clips are fine and the staging requests stand:
  - r3d-sets: `reach_pos` from the placed reach target minus the band clip's `reach_offset`.
  - r3d-view3d: `reach_offset` applied while a band clip plays.
- If neither passes, the clips go back to their author: bigger hand actions, and a prop state change during the clip.
