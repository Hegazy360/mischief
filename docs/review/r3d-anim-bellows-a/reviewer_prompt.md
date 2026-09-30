# Fresh reviewer — r3d-anim-bellows-a (R17)

Give a fresh agent (one that has not seen the game, its notes or these file names) only
`docs/review/r3d-anim-bellows-a/packets/prompt.md` and the `packets/` folder. Paste its answer lines into
`docs/review/r3d-anim-bellows-a/reviewer_answers.md`, then score them:

```bash
python3 tools/art3d/review/packets.py score <SP>/work/r3d-anim-bellows-a/pk/KEY.json \
  docs/review/r3d-anim-bellows-a/reviewer_answers.md --out=docs/review/r3d-anim-bellows-a/verdict.md --bar=4
```

What it checks: the two takes the acceptance names (the sneeze and the tea), mute, at phone scale — does the reviewer
say what happens to the man, and do both score ≥ 4 on funny and readable for the sneeze (≥ 3 on the tea)?
