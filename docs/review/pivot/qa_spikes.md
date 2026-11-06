# QA guide — trying Spikes A and C

How to run the two prototypes, what to look for, and the five questions that pick the direction.
Everything runs from the repo root. One-time setup: `docs/DEV_SETUP.md`.

**What you are judging.** Not polish — these are throwaway prototypes with placeholder traps and no
sound. You are judging one thing: *does making the comedy with your own hands feel better than
watching the current game perform it?* Keep `docs/review/depth/index.md` §1 in mind as the baseline:
the shipping Night 1 is 37 inputs in 138 seconds with 56 % of it on fast-forward.

---

## 1. Nothing is broken in the real game (3 min)

The spikes are new files under `game/spikes/`. Confirm they changed nothing:

```bash
tools/scripts/test_game.sh mine        # expect: OK … 1113 passed, 0 failed
tools/scripts/lint.sh --strict         # expect: [lint] OK + lint_anim 144 clips, 0 errors
tools/scripts/solve.sh n01_throat_tea --route=ideal   # expect: 138.2 s ★★★ 116 applause (unchanged)
tools/ci/check_import_meta.sh          # expect: [import-meta] OK
```

---

## 2. Play them (the real test)

```bash
tools/scripts/play.sh res://spikes/toybox/ToyboxSpike.tscn
# Spike A
tools/scripts/play.sh res://spikes/chase/ChaseSpike.tscn     # Spike C
```

On a phone, `tools/scripts/export_android.sh` builds the debug APK, but it boots the real game — to
get a spike on the device, temporarily set the main scene:

```bash
# in /tmp/mnd_sandbox/play/game/project.godot, under [application]:
#   run/main_scene="res://spikes/chase/ChaseSpike.tscn"
```

Mouse works like a finger on the desktop, so you can judge the feel on the Mac first; judge the
*controls* on the phone, because that is where dragging and tapping actually differ.

### Spike A — Physics Toybox

1. **Press and hold on the kettle, then drag.** She should run over, lift it, and haul it with your
   finger. Let go mid-swing and it should fly.
2. **Fling something at him.** Anything above about 520 px/s knocks him flat. He should land splayed
   and readable, lie there about a second, then scramble up.
3. **Watch what he does next.** He notices the prop is out of place, walks over, carries it home, puts
   it down, and resumes his round. Move something while he is carrying something else.
4. **Try to be inventive.** Stack the stool and the log basket. Drop something on him from above.
   Throw two things at once. Hit him while he is already carrying a prop. See whether the systems
   combine into anything you did not plan — that is the whole promise of this option.
5. **Tap the floor** to send her somewhere without grabbing.

❌ Report: props that pass through him without a reaction; a prop that gets stuck in the floor or the
wall; him failing to get up; him carrying a prop to the wrong place.

### Spike C — The Chase

1. **Tap ahead** to run. He starts behind you and never stops.
2. **Tap a gold trap.** She runs to it and crouches to set it (watch the SETTING… text). Note what it
   costs you — he gets closer every time.
3. **Let him hit it.** Rug = trip forward, marbles = skid, door = bonk backwards, bucket = he gropes
   about blind at 45 % speed for four and a half seconds.
4. **Run out of house.** Both ends are walls. Work out when to double back past him.
5. **Let him catch you once** on purpose, to see the cost: she is flung clear, he is stunned, and
   every trap resets.
6. **Count your fast-forward urges.** There is no such button. Did you ever want one?

❌ Report: a trap that fires with nothing visible happening; being caught with no way to avoid it; the
camera losing either character; him walking through a trap that was armed.

---

## 3. Look at the captures instead of playing (2 min)

If you want the quick version, the frame strips are committed:

```bash
open docs/review/pivot/spikes/cast_flop_and_getup.png   # the new animation, flop → splay → scramble up
open docs/review/pivot/spikes/toybox_strip_1.png        # she hoists the kettle and flattens him
open docs/review/pivot/spikes/toybox_strip_2.png        # he gets up and tidies
open docs/review/pivot/spikes/chase_strip_1.png         # arming traps, him going down, the lead opening
```

Regenerate any of them, or make your own GIFs, with the scripted demo built into both spikes:

```bash
tools/scripts/capture.sh res://spikes/toybox/ToyboxSpike.tscn 560 /tmp/toybox.gif spike -- --demo
tools/scripts/capture.sh res://spikes/chase/ChaseSpike.tscn  560 /tmp/chase.gif  spike -- --demo
tools/scripts/capture.sh res://spikes/common/CastTest.tscn   330 /tmp/cast.gif   spike
```

`--demo` plays a scripted run so the loop shows without a finger on the screen. Each writes a GIF, a
numbered frame strip and a `*_stability.png` motion report next to it.

**Reading the numbers.** Only the `CastTest` bench is comparable to the library band (jitter ≤ 0.25,
pops 0): it scores **0.07 / 0 pops / smooth 97**. In the two scrolling spikes the camera dominates the
measurement, so ignore jitter and pops there — the useful figure is `frozen`, which lists stretches
where *nothing on screen is moving*. The chase reports **none**. The toybox reports one ~1.3 s stretch,
which is Bellows lying on the floor, i.e. the joke.

---

## 4. Deciding

Answer in `docs/PROGRESS.md`, after playing each twice:

1. **Did you laugh at something you caused, unprompted, in the first two minutes?** Which spike, and
   what was it? (This is the question. The shipping build fails it.)
2. **Did you ever want a fast-forward button?**
3. **Did you replay by choice, and did the second run differ because you chose differently?**
4. **In the toybox, did you ever do something the design did not anticipate** — a combination that
   worked because the systems are consistent, not because someone authored it?
5. **Would you rather keep developing either of these than the current build with P2/P3 added?**

How to read your own answers:

* **A wins** → the pivot is the systemic toybox. The next step is a week on grab-and-throw feel and
  prop reactivity, then a Goose-style to-do list written from what you discovered.
* **C wins** → the pivot is pursuit. The next step is more trap verbs, a house that loops rather than
  dead-ends, and the breather/reset rhythm.
* **Both feel good** → they are compatible: the chase is what happens in a toybox once he has seen
  you. That is the strongest outcome, and it argues for A as the base with C as the escalation.
* **Neither** → say what was missing. B (Set the Stage, the contraption builder) is still unbuilt and
  is the one that keeps the deterministic sim and the solver; D (turn-based) is the safe fallback.

A fair warning from the research, worth weighing against your own reaction: *Human: Fall Flat* is
famously better to watch than to play, and *Octodad*'s reviews turned when the controls stopped being
funny and became a chore. If a spike is funnier in the GIF than in your hands, that is a real signal
and it is exactly what this exercise was for.
