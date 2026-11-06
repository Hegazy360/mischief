# QA guide — trying Prototype 1a (MISCHIEF RUN)

## 1. Nothing in the old build broke (3 min)

The prototype is new files under `game/proto/`. The shipping game is untouched:

```bash
tools/scripts/test_game.sh mine        # expect: OK … 1113 passed, 0 failed
tools/scripts/lint.sh --strict         # expect: [lint] OK, lint_anim 144 clips 0 errors
tools/ci/check_import_meta.sh          # expect: [import-meta] OK
```

## 2. Play it

```bash
tools/scripts/play.sh res://proto/mischief_run/MischiefRun.tscn
```

If taps ever stop responding, run the built-in input self-test first — it drives the real input path
with synthetic clicks and prints what happened:

```bash
tools/scripts/shot.sh res://proto/mischief_run/MischiefRun.tscn /tmp/x.png 160 proto -- --clicktest
# expect: [clicktest] PASS (0 failure(s))
```

Mouse acts as a finger. For the phone, point the sandbox's `project.godot` `run/main_scene` at
`res://proto/mischief_run/MischiefRun.tscn` and run `tools/scripts/export_android.sh`.

**How to play.** Tap a card in your hand (it lifts). Tap a station on the routine to rig it there. Tap a
rigged station to take the prank back. You have 3 Nerve a round and most pranks cost 1. Tap **CURTAIN
UP** and watch. Tap during the replay to hurry it. Between rounds, tap one of the three offers.

**What to try, in this order:**
1. **Rig three stations next to each other** and watch the chain multiplier climb (×1.5, ×2).
2. **Rig three stations with gaps** between them and see the chain never start. That difference is the
   game.
3. Play SPRAY TAP (leaves SOAKED) in an early round, then look for SLIPPERY FLOOR or DOUGH MAN in a
   later draft. Residues last the whole Night.
4. Take an **Encore** when offered and see whether it changes how you play the next round.
5. Get to Night 3 and lose. Then try again and see whether you plan differently.

## 3. Watch it instead (1 min)

```bash
tools/scripts/capture.sh res://proto/mischief_run/MischiefRun.tscn 420 /tmp/proto.gif proto -- --demo
```

`--demo` plays itself. Committed stills are in `docs/review/pivot/spikes/`.

## 4. Re-run the balance report

```bash
tools/scripts/sandbox.sh proto >/dev/null
NO_IMPORT=1 tools/scripts/sandbox.sh proto -s res://proto/mischief_run/sim.gd -- --runs=200
NO_IMPORT=1 tools/scripts/sandbox.sh proto -s res://proto/mischief_run/sim.gd -- --runs=200 --greedy-draft
```

Edit `game/proto/mischief_run/data/cards.json` and re-run — a card's numbers can be changed and
re-validated in under a minute without touching code. That is the content pipeline being proposed.

## 5. The gate

Answer in `docs/PROGRESS.md`:

1. **Did you discover a combination that delighted you, unprompted, in the first run?**
2. **Did you start a second run without being asked?**
3. **Can you describe it in one sentence that does not contain the word "roguelike"?**
4. **Does the look already feel like a style, or like placeholder?** (It is primitives and type on
   purpose — the question is whether that direction can be made beautiful, not whether it is yet.)
5. **Would you rather spend the next three months on this than on anything built so far?**

Three or more clear yeses → this is the pivot, and the next step is content depth (60+ cards), a meta
layer between runs, sound, and an art-direction pass. Fewer → `docs/review/pivot/next_options.md` has
the prepared steps for the alternatives, and says which one your specific objection points to.
