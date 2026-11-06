# An animation engine built for agents — "the Bakery"

Date: 2026-11-08. Owner's brief: *not a complex animation system, but not super basic either; it has to
be enjoyable to end users; we may need our own animation engine that works well with AI agents and
produces accurate results; cartoonish like the classic Neighbours from Hell if that is not harder;
use open-source assets and do not design our own.*

This is the design, and a working proof of it. Code in `tools/bakery/`, output in
`game/proto/bakery/`.

---

## 1. Why every previous attempt felt cheap

Four attempts, two failure modes, one cause.

* **The 2D cutout rig** (the original game) had genuinely good comedy motion, because a human had
  keyed 148 clips. It could never have enough of them: every new gag cost an animator a day, and this
  team has no animator. The repo spent 22,900 lines of art tooling getting there.
* **The spikes and the 3D toy** used procedural springs and then library clips. Nothing had to be
  authored — and nothing was funny, because library clips are deliberately neutral and springs have
  no comic timing.

So the choice has always looked like *expensive and good* or *free and bland*. The missing option is a
system where **the comedy is a function with a knob on it**, cheap to evaluate, impossible to get
mechanically wrong, and checkable without a human watching.

## 2. The idea

**The Cartoon Animation Filter** (Wang, Drucker, Agrawala et al., SIGGRAPH 2006): convolve a motion
curve with an inverted Laplacian-of-Gaussian and anticipation, follow-through, overshoot and
squash-and-stretch *fall out of the arithmetic*.

```
filtered = x − amount · (x ∗ d²G/dt²)
```

Before a sharp move the curve dips the wrong way; after it, it sails past and settles. That is
anticipation and follow-through — two of the twelve principles of animation — as a one-line
convolution. ([paper](https://grail.cs.washington.edu/wp-content/uploads/2015/08/wang-2006-tca.pdf),
[skeletal follow-up](https://dl.acm.org/doi/10.1145/1666778.1666789))

That is the whole animation engine. An agent never touches a curve, a pose or a keyframe. It writes
**one line of JSON per clip**:

```json
{ "name": "hit", "lib": "General", "clip": "Hit_A", "amount": 1.4, "frames": 10 }
```

…and the pipeline bakes a finished, validated sprite sheet. `amount` is the only creative dial.

## 3. The pipeline

```
CC0 character (KayKit)  ─┐
CC0 clip library (KayKit)┴─► cartoon filter ─► Blender headless render ─► prune ─► sheet+ink ─► validate
                                 numpy            EEVEE, deterministic     dedupe     PNG+JSON    PASS/FAIL
```

| Stage | File | What it guarantees |
|---|---|---|
| Filter | `cartoon_filter.py` | pure numpy, no Blender — **13 self-tests in 40 ms** |
| Bake | `bake.py` | headless, `--factory-startup`, same command → same pixels |
| Prune | `prune.py` | no frame you cannot tell apart from its neighbour |
| Pack | `sheet.py` | strip + metadata, ink outline from alpha dilation |
| Validate | `validate.py` | six objective checks on the rendered PNGs |
| Runtime | `viewer.gd` | **advance an integer, blit a region of a PNG** |

Neighbours from Hell shipped exactly this way — its `gfxdata.bnd` is RLE-compressed `.tga` sprite
sheets, not runtime 3D ([fan teardown](https://github.com/thegoosesans/NeighboursfromHell-PythonRecreation)).
So the look you asked for and the architecture that suits agents are the same architecture.

### Why this is the agent-friendly part

Every runtime animation bug this project has hit — the jiggle/grounding oscillation at jitter 0.42,
the ragdoll that never stood up, the frozen rigid body that fired the player through a wall, the
slotted-action clip that silently played nothing — **cannot exist here**, because at runtime there is
no rig. There is a PNG. The risk moves offline, where it is deterministic and measurable.

## 4. The proof

`docs/review/pivot/spikes/bakery_filter_compare.png` — one KayKit clip, three filter amounts, nothing
else changed. The wind-up deepens and the extremes extend as the knob turns.

Objective, from `validate.py`: the filter raises how much the silhouette changes at 48 px — the size
it is actually drawn — from **31.9 % to 42.6 %**. It measurably reads better, not just differently.

Twelve clips bake, prune, pack and validate in **34 seconds**, all PASS. Contact sheet:
`bakery_contact.png`. Animating: `bakery_viewer.png` / the Godot scene.

### Five real bugs the harness caught that eyes would not have

1. **Blender 4.4 slotted actions** — assigning a library action to another rig without binding its
   slot plays nothing. Every frame rendered identical and looked plausible.
2. **The library's own mannequin** stood in shot in every frame, because importing a clip library
   brings its mesh along.
3. **`Rogue.glb` ships a stray unskinned Icosphere** — someone else's asset junk, now auto-dropped.
4. **Framing measured on world axes** let a body lying along the camera axis clip out of its cell;
   it has to be measured on the film plane.
5. **Unbounded quaternion exaggeration** flipped the character horizontal at `amount 1.8`. There is
   now a hard angular ceiling, so **any** amount an agent types gives a strong take, never a broken
   one — the self-test proves it holds at amount 8.

That list is the argument for the whole approach: these are exactly the failures that have been
reaching you as "it still looks wrong", and every one is now either impossible or caught by a check.

## 5. What this does not yet do

Honest gaps, in priority order:

* **Only one view angle.** A side-on game needs left/right (mirror, free) and probably a 3/4. An
  eight-direction bake is a loop over `--angle` — the Blender add-on ecosystem does this routinely.
* **No facial expression.** NfH's comedy is largely faces. KayKit heads are separate meshes, so a
  face-swap layer is viable, but it is not built.
* **No props in hand.** The rig has `handslot.l/r`; attaching a thrown object is unbuilt.
* **The filter is global per clip.** Wang's paper also time-shifts *per joint*, which is what gives
  whip and drag through a limb. That is the single highest-value upgrade and is maybe a day.
* **KayKit is fantasy.** For a domestic prank game the cast is wrong; Quaternius and Polygonal Mind's
  100 Avatars (200+ rigged CC0 characters) are the places to look for civilians.
* **It is a renderer, not a game.** Nothing here decides whether the game is fun.

## 6. What I recommend

Treat this as the animation layer and **stop re-deciding the game every round**. The honest position
after four rejected prototypes is that I have been choosing designs and you have been rejecting them,
which is a bad loop. The Bakery is different in kind: it is infrastructure that makes *any* of those
designs affordable to animate well, and it is the first thing built that directly attacks the thing
you keep objecting to.

Concretely, one week:

1. **Two days** — per-joint time-shift (whip/drag), eight-direction bake, hand-slot props.
2. **One day** — swap KayKit for a civilian cast; bake a grump and a prankster.
3. **Two days** — twenty gag clips from the CC0 libraries at various amounts, validated, in a contact
   sheet you flip through and mark funny / not funny.

That last artefact is the one that matters: for the first time you would be judging **a page of
comedy takes**, cheap enough to regenerate the same afternoon, instead of judging a prototype.
