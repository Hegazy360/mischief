# Reviewing the game on a Mac

How to look at what we are building, on your own machine, without needing to know the internals.
One-time setup is in [DEV_SETUP.md](DEV_SETUP.md) — install Godot 4.7.2 (and Blender only if you
want to rebuild art), then come back here.

Everything below is run from the repository root. Each command prints the file it wrote; open it
with `open <file>`.

---

## 1. The fastest look: play it

```bash
tools/scripts/sandbox.sh play
godot --path /tmp/mnd_sandbox/play/game
```

This opens the real game in a window. It runs from a private copy, so nothing you do can disturb
the repository. Close the window when you are done.

To jump straight into a Night instead of the front end:

```bash
godot --path /tmp/mnd_sandbox/play/game res://scenes/night/NightScene.tscn -- --episode=n01_throat_tea
```

Episodes: `p00_curtain_up` (Prologue), `g0_sneeze` (the sneeze gag), `n01_throat_tea`,
`n02_something_fishy`.

---

## 2. A still frame

```bash
tools/scripts/shot.sh res://scenes/night/NightScene.tscn /tmp/night.png 150 mine -- \
  --episode=n01_throat_tea --seek-tick=420 --no-curtain
```

`1200x540` is a phone held sideways, which is the size every judgement should be made at. The last
number is how many frames to run before the shot, so raise it to see a later moment.

Other useful scenes:

| Scene | What it shows |
|---|---|
| `res://scenes/boot/Boot.tscn` | the front end |

---

## 3. Motion: always review as a GIF, never as a still

**This is the important one.** A still frame cannot show a judder, a snap or a sliding foot. Every
judgement about *movement* has to be made on a capture.

```bash
tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 150 /tmp/walk.gif -- --rig=hush --clip=loco_walk
```

That writes four things next to `/tmp/walk.gif`:

| File | What it is |
|---|---|
| `walk.gif` | the animation, with a sound strip under it |
| `walk_mute.gif` | the picture only |
| `walk_strip.png` | numbered still frames, for pointing at a specific frame |
| `walk_stability.png` | **the motion quality report** |

### Reading the stability report

It plots how much the picture changes each frame and prints one line:

```
[stability] walk: smooth 92/100, pops 0 [], jitter 0.16, frozen []
```

| Number | Means | Good |
|---|---|---|
| `jitter` | vibration — the motion speeding up and slowing down every frame or two | **≤ 0.25** |
| `pops` | frames that jump (a snap, a teleport, a limb flipping) | **0** |
| `frozen` | stretches where nothing moves although it should | **none** |
| `smooth` | overall roll-up | **≥ 85** |

For reference: a clean clip sits around 0.15–0.25; a build that measured 0.42 is what "unstable" felt like.

### Comparing two options

Add a flag to turn one layer off and capture again:

```bash
tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 150 /tmp/strut.gif -- --rig=bellows --clip=loco_strut
```

The AnimViewer takes `--rig=` and `--clip=`; see its header for the full list.

---

## 4. Seeing a whole Night play itself

```bash
tools/scripts/e2e.sh n01_ideal --report=/tmp/n01.json
```

It plays a solved route through the real game and reports whether the timing gates held. Add
`--shot-seq=/tmp/frames --every=60 --count=12` to get a dozen stills across the Night.

---

## 5. Checking nothing is broken

```bash
tools/scripts/test_game.sh mine        # ~5 min; expect "OK: ... 0 failed"
tools/ci/lint_all.sh                   # art, content and audio checks
tools/ci/check_import_meta.sh          # expect "[import-meta] OK"
```

One test, `test_clone_under_1ms`, measures wall-clock speed and can fail if your Mac is busy. Run
it alone to confirm: `tools/scripts/test_game.sh mine -- test_determinism`.

---

---

## Gotchas specific to macOS

- **A window opens during captures.** Godot cannot render without one. Don't click on it; let it
  finish. It closes itself.
- **Don't worry if it loses focus.** The game pauses when backgrounded, which is correct on a
  phone, but it is suppressed during captures so your screenshots are not of the pause menu.
- **Sandboxes live in `/tmp/mnd_sandbox/`.** They are private copies; delete the folder any time.
- **First run of a sandbox is slow** (it imports ~1,200 assets). Later runs reuse the cache.
