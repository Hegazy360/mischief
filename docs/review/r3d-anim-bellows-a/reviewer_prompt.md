# Fresh reviewer — r3d-anim-bellows-a (R17)

Give a fresh agent (one that has not seen the game, its notes or these file names) only
`docs/review/r3d-anim-bellows-a/packets/prompt.md` and the `packets/` folder. Paste its answer lines into
`docs/review/r3d-anim-bellows-a/reviewer_answers.md`, then score them:

```bash
python3 tools/art3d/review/packets.py score <SP>/work/r3d-anim-bellows-a/pk/KEY.json \
  docs/review/r3d-anim-bellows-a/reviewer_answers.md --out=docs/review/r3d-anim-bellows-a/verdict.md --bar=4
```

What it checks: the sneeze (the take the acceptance names; bar >= 4 funny and readable) and the tea (an activity
loop; bar >= 3), mute, at phone scale — does the reviewer say what happens to the man?

Round 1 (orchestrator-run, before the tea v2 and fx_off): `reviewer_answers_r1.md`, `verdict_r1.md` (key
`<SP>/work/r3d-anim-bellows-a/pk/KEY_r1.json`) — sneeze 4 / 4 / 3, tea 1 / 2 / 2. The packet now in `packets/` is
round 2: the current sneeze and the reworked tea (the pour from a height, the bigger stir and lid-flip recoil, steam,
sparkles; no stray FX notes).
