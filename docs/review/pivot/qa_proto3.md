# QA guide — trying Prototype 3 (THE KEEP)

## 1. Nothing in the old build broke (3 min)

```bash
tools/scripts/test_game.sh mine        # expect: OK … 1113 passed, 0 failed
tools/scripts/lint.sh --strict         # expect: [lint] OK, lint_anim 144 clips 0 errors
tools/ci/check_import_meta.sh          # expect: [import-meta] OK
```

## 2. Prove the input works before you judge the play (30 s)

```bash
tools/scripts/shot.sh res://proto/toyhouse/TheKeep.tscn /tmp/x.png 450 keep -- --clicktest
# expect: [clicktest] PASS (0 failure(s))
```

This pushes real taps through the real input path: floor → she runs, crate → she holds it, Knight while
holding → she throws. If it fails, stop and report the three lines it prints.

## 3. Play it

```bash
tools/scripts/play.sh res://proto/toyhouse/TheKeep.tscn
```

Mouse is a finger; wheel zooms. For the phone, set `run/main_scene` in the sandbox's `project.godot` to
`res://proto/toyhouse/TheKeep.tscn` and run `tools/scripts/export_android.sh`.

**Try, in this order:**
1. Tap the floor a few times. She runs; close taps walk. Run into the barrels — they should shove.
2. Tap a crate. She fetches it and holds it in front of her chest. Tap the floor: she carries it.
3. Wait until the Knight sits in his chair. Tap him. She throws. Watch him stagger, fall flat, lie
   there, get up, look round.
4. **Stay in his view** when he gets up. He should chase you. Let him catch you once: you go down, he
   cheers, then goes back to his day.
5. **Hide behind the crates** when he gets up instead. He should walk over to the thrown crate, pick it
   up, carry it back to the stack and put it down.
6. Knock the books off the shelf one by one. Throw plates. Stack crates. Roll the ball at him. See whether
   the systems combine into anything you did not plan.

❌ Report: a prop stuck in the floor or wall; either character leaving the hall; him standing still for
more than ~5 s with no label change; a tap on a visible prop that does nothing.

## 4. Watch it instead

```bash
tools/scripts/shot.sh res://proto/toyhouse/TheKeep.tscn /tmp/k.png 960 keep -- --demo --shot-seq=/tmp/kseq --every=60 --count=16
open /tmp/kseq
```

`--demo` fetches a crate, waits until he has sat down, throws, and hides. Add `--trace` for a one-line
state dump every half second.

## 5. The gate

1. **Did you laugh at something you caused, unprompted, in the first two minutes?**
2. **Did you do something the design did not anticipate** that worked because the systems are consistent?
3. **Did you ever want a fast-forward button?**
4. **Does the KayKit look feel like a *style* you would ship, or like placeholder?** (That is the one
   question this option cannot answer later — it is the whole bet.)
5. **Would you rather spend three months on this than on the card prototype or the old build?**

Three or more yeses → this is the pivot. Next: a second NPC, occlusion for his sight, sound, a goal
layer (a to-do list in the Goose style, written from what *you* found funny here), and a house instead
of a hall. Fewer → say which of the five failed; `next_options.md` §B (new fiction on the roguelike
engine) and §C (minimalist systems strategy) are the remaining unbuilt options.
