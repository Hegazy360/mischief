# QA guide — the Bakery (agent-facing animation engine)

## 1. The maths, with no renderer (2 seconds)

```bash
python3 tools/bakery/cartoon_filter.py --selftest     # expect: OK: 13/13 checks
```

This is the claim "produces accurate results", tested directly: a still pose stays still, constant
speed is untouched, a sharp move gains anticipation *before* and overshoot *after*, the knob is
monotonic, loops keep their seam, quaternions survive a sign flip, the angular ceiling holds even at
amount 8, squash preserves volume.

## 2. Bake everything (35 seconds)

```bash
python3 tools/bakery/run.py --contact
```

Expect twelve clips, each `=> PASS (6/6)`, and `[run] 12 clip(s) baked in ~35s`. It writes sprite
sheets + JSON to `game/proto/bakery/sheets/` and a contact sheet at `sheets/_contact.png`.

**Now change something.** Open `tools/bakery/clips.json`, change `"amount"` on `hit` from 1.4 to 0.2,
re-run with `--only hit --contact`, and compare. That edit — one number — is the entire authoring
interface an agent uses. There is no curve, no pose, no keyframe anywhere in this system.

## 3. Watch it move (the only way to judge animation)

```bash
tools/scripts/play.sh res://proto/bakery/Bakery.tscn
```

Top row is three **pairs**: the same KayKit clip baked flat (left, grey label) and filtered (right,
gold label). That comparison is the whole proposal. Bottom row is the rest of the set.

What to look for: on the cartoon side the wind-up goes further before the action and the body carries
past the end of it before settling. On the flat side the motion starts and stops where it is told.

## 4. See a single clip as frames

```bash
open docs/review/pivot/spikes/bakery_filter_compare.png   # one clip at amount 0.0 / 0.8 / 1.6
open game/proto/bakery/sheets/_contact.png                # every clip, accent frame boxed in gold
```

## 5. Check nothing in the old build broke

```bash
tools/scripts/test_game.sh mine        # expect 1113 passed, 0 failed
tools/scripts/lint.sh --strict         # expect [lint] OK, 144 clips 0 errors
tools/ci/check_import_meta.sh          # expect [import-meta] OK
```

## 6. The gate

This is infrastructure, not a game, so the questions are different from the prototype gates:

1. **Does the cartoon side of a pair read as funnier than the flat side?** If not, the filter is not
   earning its place and the approach fails here.
2. **Is this look — CC0 low-poly baked to sprites — one you would ship?** It is close to the NfH
   architecture but the *cast* is fantasy knights; imagine it with civilians.
3. **Could you direct this?** Reading `clips.json`, can you see yourself saying "push the flinch to
   1.8, pull the idle back to 0.3" and trusting the result?
4. **Is 35 seconds for twelve clips fast enough** that you would ask for twenty variations of a gag?
5. **What is missing before it is enjoyable?** Faces, props, more angles, a civilian cast — ranked.

If (1) and (3) are yes, the next week is in `animation_engine.md` §6, and it ends with a page of
twenty comedy takes for you to mark funny or not.
