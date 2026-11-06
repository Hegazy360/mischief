# QA guide — P1 "Meddle" and P5 "Clarence is a toy"

What changed, how to check it on the Mac and on the phone, and how to decide whether it moved the needle.
Everything runs from the repo root. One-time setup: `docs/DEV_SETUP.md`; the review basics: `docs/TESTING_ON_MAC.md`.

## 0. What you are testing

| | Before | After |
|---|---|---|
| Tap a prop that is not one of tonight's pranks | "nuh-uh" sound, a grey ripple, Hush shrugs | Hush walks there, the button offers a **0.8 s hold**; the prop tilts **askew**; the badge goes out |
| Bellows walks toward an askew prop | — | he **stops 1 s**, tuts / straightens / peers, the prop is right again, "+1" stamp (first time per prop), a titter |
| Night 1 props that respond | 5 | **12** (hall phone, mirror, clock, stair rods; gramophone, piano wedge, newspaper, chandelier, bellows, tea tray, fan; fridge shelf) |
| Squeak when he can hear you (no squeak bit) | the same head turn every time | **three** head turns in rotation (glance, look over the shoulder, squint), each with its own grunt |
| Two lures inside a minute | Clarence ring **greys out** | the ring stays live; a third pip still only gets his "PIPE DOWN!" |
| Squeak when nobody can hear | nothing on screen but the sound | Hush **glances at the Stalls** |

What did **not** change: the Script, the five pranks, his loop, every fairness rule, the solver's numbers (21 routes
identical to the decimal), scoring of pranks. Meddling pays +1 once per prop as a *bit*; it never multiplies.

## 1. Automated checks (5 minutes, run first)

```bash
tools/scripts/test_game.sh mine                      # expect: OK … 0 failed  (1,113 tests; test_meddle ×7 inside)
tools/scripts/lint.sh --strict                       # expect: lint_anim 144 clip(s), 0 error(s); [lint] OK
tools/scripts/solve.sh all --route=all               # expect: OK: 21 run(s), 0 failed — same numbers as before
tools/scripts/fuzz.sh all --runs=6 --seed=3          # expect: OK: 72 run(s), 0 failed (the random bots meddle now)
tools/ci/check_import_meta.sh                        # expect: [import-meta] OK
```

If `solve.sh` numbers differ from `docs/review/depth/index.md` §1, something leaked into the routes: stop and report.

## 2. Scripted look on the Mac (3 minutes)

Two command files drive the real Night 1 so you can see the loop without playing it. Write them once:

```bash
mkdir -p /tmp/mnd_qa && cat > /tmp/mnd_qa/parlour.cmds.json <<'J'
{"episode":"n01_throat_tea","ticks":2400,"cmds":[
 [30,{"c":"go","hotspot":"parlour_fan","run":false}],[260,{"c":"rig","on":true}],[330,{"c":"rig","on":false}],
 [340,{"c":"go","hotspot":"parlour_chandelier","run":false}],[450,{"c":"rig","on":true}],[520,{"c":"rig","on":false}],
 [530,{"c":"go","hotspot":"kitchen_table","run":false}]]}
J
```

1. **The askew props** (still, tick 700 — Bellows is still warming up, Hush is under the table):
   ```bash
   tools/scripts/shot.sh res://scenes/night/NightScene.tscn /tmp/mnd_qa/askew.png 30 shots -- \
     --episode=n01_throat_tea --cmds=/tmp/mnd_qa/parlour.cmds.json --seek-tick=700 --no-curtain
   open /tmp/mnd_qa/askew.png
   ```
   ✅ The pink fan (left of the kitchen wall) hangs tilted off its hook. Its gold badge is gone. Applause 0.
2. **The notices** (16 frames across his walk from the gramophone to the kitchen):
   ```bash
   tools/scripts/shot.sh res://scenes/night/NightScene.tscn /tmp/mnd_qa/last.png 270 shots -- \
     --episode=n01_throat_tea --cmds=/tmp/mnd_qa/parlour.cmds.json --seek-tick=1560 --no-curtain \
     --shot-seq=/tmp/mnd_qa/seq --every=16 --count=16
   open /tmp/mnd_qa/seq
   ```
   ✅ Around frame 2 a "+1" stamp by the chandelier and Applause 1; around frame 10 Applause 2 (the fan); in the last
   frames the fan hangs straight. He stands still for ~1 s at each, then carries on to his tea as normal.
   ❌ Report if: Applause stays 0; he walks past without stopping; a prop stays tilted after he passed within a
   step of it; he changes direction or skips the tea.
3. **Motion, not stills** — the notice flavours and the head turns are one-shots; judge them on a capture:
   ```bash
   tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 150 /tmp/mnd_qa/suspicious.gif -- --rig=bellows --clip=st_suspicious
   tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 150 /tmp/mnd_qa/lookback.gif   -- --rig=bellows --clip=st_look_back
   ```
   ✅ `[stability] … pops 0`, jitter ≤ 0.25 — these are existing clips; nothing new was authored.

## 3. Play it (the real test — phone first, Mac if you must)

Build the debug APK (`tools/scripts/export_android.sh`) or run `tools/scripts/sandbox.sh play && godot --path
/tmp/mnd_sandbox/play/game`. Start **Night 1** from the stage door. Play **twice**: once your normal way, once trying
to meddle with everything you can reach. Keep a note of the time on the clock when each thing below happens.

### 3.1 Meddle — step by step
1. Curtain up. Bellows warms up at the gramophone. **Tap the pink fan** on the parlour wall.
   ✅ Hush tiptoes there. The action button turns into the glove → fan icon and says HOLD.
   ❌ The button says FREEZE, or a grey "nuh-uh" ripple.
2. **Hold** the button.
   ✅ The ring fills in under a second; a soft "ding"; the fan **tilts** off its hook; its gold badge goes out.
   ❌ The ring never fills; the fan does not move; the badge stays.
3. **Tap the fan again.**
   ✅ Hush shrugs (grey ripple) — it is already askew. Nothing else happens.
4. **Tap the chandelier**, hold. ✅ Same as 2.
5. Hide under the kitchen table (tap it). Wait, with ⏩ if you like.
6. Watch him leave the gramophone for his tea.
   ✅ Walking right, he **stops at the chandelier** for about a second, tuts / straightens / peers; it stands straight;
   **"+1"** floats up; the Stalls titter; the Applause needle moves to 1.
   ✅ He **stops again at the fan** a step later: +1 → Applause 2.
   ✅ He then goes to the counter and makes his tea **exactly as before** (same route, same timing give or take 2 s).
   ❌ He stops but the prop stays tilted. ❌ He turns round, skips the tea or walks somewhere new. ❌ Applause moves by
   anything but +1. ❌ A "?" appears over his head while Hush is under the table (that would be a senses bug).
7. **Meddle with the fan again** on his next loop (he warms up again after the paper).
   ✅ He notices again (stops, tuts) but **no "+1"**: a prop pays once per Night. The needle does not move.
8. **A prop with a prank tonight** — tap the kettle with an empty tray, hold.
   ✅ Nothing to rig (the old behaviour: that prop belongs to the Script). The honey, the sink, the pickle jar and the
   recliner behave exactly as before.
9. **While he can see you** — stand in his sight line and start a hold on the gramophone.
   ✅ The hold pauses and Hush freezes (the same rule as a real rig); the "?" fills as usual.
10. Count: by the end of Night 1 you should have been able to fiddle with **12 props** in the hall, parlour and kitchen.

### 3.2 Clarence — step by step
1. He is at the pickle shelf (no squeak bit there). You are in the parlour, out of sight. **Squeak.**
   ✅ He glances toward you with a "huh?". Ear pip ×1.
2. **Squeak again** after he has turned back.
   ✅ A **different** take — he looks over his shoulder with a "hmph". Ear pip ×2.
3. Squeak a third time within 8 s. ✅ The lure, as before: he comes to look (hide first).
4. Lure him twice inside a minute, then try a third.
   ✅ He shouts "PIPE DOWN!" from where he stands. The Clarence ring **does not grey out**.
5. Go where he cannot hear you (he is in the kitchen, you are in the hall with the parlour between) and **squeak**.
   ✅ The squeak sounds and Hush glances at the audience. No "?" anywhere.
6. Squeak during a reaction (he is mid-sneeze). ✅ Same glance; nothing else.

### 3.3 What to watch that is *not* the feature
- ⏩ still drops out of fast-forward when a notice happens? (It should not need to — a notice is not a prank; if ⏩
  stays on, that is fine. If the screen jumps to him, note it.)
- The camera: when he notices something off-screen, the PiP should show him. Note if you missed a notice entirely.
- Frame rate on the phone while a prop tilts (a tween on one sprite — should be invisible in the frame counter).
- Any prop that looks wrong tilted (a wall-mounted item pivots at its bottom centre: fine for a fan or a clock,
  maybe odd for a picture rail).

## 4. Deciding — did it move the needle?

Answer these after the two play-throughs, honestly, in `docs/PROGRESS.md` under a dated line.

1. **Did you meddle without being told to?** (Yes on the first play-through = the discovery works. Only on the second
   = the badges are not inviting enough.)
2. **How many times did you press ⏩ in Night 1, and for how long?** Before this change the best route spent 56 % of
   the Night on ⏩. If your own number barely moved, meddling is not yet filling the wait — P2/P3 (more live
   pranks, two ways per station) is the next lever, not more meddling.
3. **Did a notice make you smile the first time? The fourth?** If the first did and the fourth did not, the three
   flavours are too few: author a 60 f double-take and two more flavours before adding anything else.
4. **Did you ever feel Clarence was "used up"?** If yes, where — fatigue, bits at zero, or out of earshot?
5. **Any moment where he behaved unfairly** (a stop that let him catch you; a "?" you could not explain)? These are
   bugs: note the clock time and which prop.
6. **The one-line verdict:** *more fun / same / worse*, and the single thing you would change first.

If the verdict is "same": the proposal's P2 (two ways to sabotage each station) and P3 (nine live pranks, require
four) are the depth fix proper; P1/P5 were the cheap test of whether reactivity alone is the missing ingredient.

## 5. Measuring it (optional, for the record)

The solver's routes never meddle, so the automated numbers did not move. To measure a human play-through, play on
the Mac with `--e2e` recording or dump your own commands and replay them:

```bash
tools/scripts/e2e.sh n01_ideal --report=/tmp/mnd_qa/n01.json        # the baseline route, for comparison
```

Then compare `ff_s`, `alive_by.input` and the `applause` breakdown in the report with the baseline in
`docs/review/depth/index.md` §1 — the `notice` events are listed as visible beats (`beats.room` / `beats.pip`).
