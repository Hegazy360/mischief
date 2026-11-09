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

---

## 7. Round 2 — flat by default, and making flat play right (owner feedback)

**Verdict:** the flat takes won; the filtered ones were too wobbly and unnatural. The filter is now
**opt-in** (`amount` defaults to 0 and is applied only when > 0). Nothing else about the knob changed,
so a single gag can still ask for it.

Playing the flat takes in a game exposed five problems that had nothing to do with the filter:

1. **Invented timing.** Frames were picked evenly and played at a fixed 12 fps, so every clip ran at
   whatever speed its frame count implied. Now the bake samples in real time at the library's own
   speed (24 fps source with fractional lengths, sub-frame sampled to a target fps) and every frame
   carries its on-screen duration. Pruning hands a dropped frame's time to its neighbour; the
   validator proves each clip still lasts as long as its source.
2. **Loop seam hitch.** Loops sampled both ends (the same pose), so every cycle held a frame. Loops
   now divide the cycle without its end point, prune folds a repeated tail into its neighbour, and
   the validator checks last→first.
3. **Per-clip zoom.** Each clip was framed to its own bounds, so the knocked-down knight was a third
   the size of the standing one. Now one pixels-per-metre per character (from the bind pose); the
   cell grows instead of the character shrinking. Each sheet records the **anchor** — the root on the
   floor — so clips swap without the feet moving.
4. **Bodies in the floor.** The library clips sink this character into the floor (9 cm on a walk,
   43 cm getting up). The bake enforces floor contact per pose — lifted only, never pushed down, so
   jumps still leave the ground — and the validator checks the lowest pixel sits on the floor line.
5. **Moonwalking and jumping chains.** Locomotion's travel speed is measured from the planted foot
   (`ground_speed_px`), and a clip that `follows` another stores how far the body moves at the switch
   (`enter_dx`; knocked→getup was 34 px), which the runtime applies.

Added clips a prank game needs: startle, interact, tinker (lockpick), knocked, getup, sit, sit_idle.
15 clips bake and validate in ~80 s. Viewer is now a stage rehearsal driven by `routine.json`.
Stills: `spikes/bakery_stage.png`, `spikes/bakery_rehearsal_seq.png`.

Still open: civilian cast, props in hand, faces, a contact shadow that follows a lying body.

---

## 8. Round 3 — the real cast: Hush and Horace Bellows (characters and movement only)

Owner: round 2 results good; now the actual characters, and only characters + movement — props in
hand and faces come later, each in its own round.

**Where the cast came from.** Not designed here. In October the project re-dressed two CC0 KayKit
characters into the GDD cast (Hush = the Rogue, Bellows = the Mage) with `recolour.py` (repaints
KayKit's 8x8 palette atlas) and `redress.py` (accessories on new bones inside KayKit's own rig). That
cast was dropped only because the **runtime** 3D was glitchy. The Bakery removes the runtime, so the
tools were restored from git (`8d7c654^`) into `tools/bakery/cast/` and pointed at the KayKit files
already in the repo. Same rig, so every library clip drives the cast unchanged.

**What was wrong at first look, and the fixes:**

| problem | cause | fix |
|---|---|---|
| everything washed out (cherry beret → salmon) | Blender's default AgX view transform | `Standard` view transform; exposure lowered (world 0.62, sun 1.9) so whites keep shading |
| Bellows read as a wizard behind a white wall | the Mage's long hair curtains hid the face side-on | `trim_hair` deletes hair faces below the brow (552); crown stays for the bouffant |
| Bellows had no barrel | Mage body is a straight robe | `barrel` bulges the robe's own vertices (sine profile, skin weights untouched) |
| Bellows' cravat grey-blue | sampled a Hush-only atlas cell | gold cell, as the GDD specifies |
| Hush's Breton stripes jagged | big low-poly faces straddled band edges | `slice_bands` bisects the tunic at every band edge first (weights interpolated) |
| faces hard to read | 70° camera is near-profile | 50°: faces show, bodies still read side-on |
| both normalised to one height | ppm per character | **cast-wide `ppm` 80**, so Bellows stands taller and much wider than Hush |
| Hush's idle pruned to 3 frames | prune floor tuned for big motion | idles carry their own lower `min_change` → 12 frames |

**Movement, chosen per character** (compared on the actual characters first —
`spikes/bakery_cast_*`): Hush walks with `Walking_C` (careful, upright), sneaks with `Sneaking`,
hides with `Crouching`; Bellows struts with `Walking_B` (chest out, arms back — the vain one), potters
with `Walking_C`, idles with `Idle_B`. 15 + 13 clips, all PASS, 100 s from a clean checkout for the
whole cast (3 Blender jobs in parallel; the models are build output, made automatically).

Viewer: a two-actor scene from `routine.json` (Bellows preens, struts, takes tea, sits; Hush creeps
in, rigs, waves to the Stalls, scarpers; the gag lands, he goes flat and gets up) plus every clip of
both characters. Stills: `spikes/bakery_cast_stage.png`, `bakery_cast_scene_seq.png`,
`bakery_cast_closeups.png`, `bakery_cast_before.png` / `bakery_cast_after.png`.

Still open for this round's subject: Bellows lying down shows up into his robe (reads like a barrel
lid — owner's call); shadow does not follow a lying body; library has no "angry" or "freeze" clip
(the GDD's freeze-in-plain-sight needs one). Next rounds: props in hand, then faces.

---

## 9. Round 4 — a new neighbour from scratch: Gus Thudd

Owner: round 3 still leaned on the first version's designs. Keep the prankster; replace the other
character completely with a new one. So Bellows (the Mage re-dress, §8) is gone from the tools,
manifest and sheets, and the neighbour was rebuilt from a base that carries no earlier design.

**Base.** KayKit's **Large mannequin** (CC0, recovered from the October evaluation commit
`1cd74f3`; now in `tools/bakery/cast/src/`): a blank, featureless heavy body — huge chest and arms,
small head, solid legs — the opposite silhouette to Hush. Its Large clip library (idle, walk, run,
hit, death, **flexing**) is small, but it shares bone names with the Medium rig, so Hush's library
(press-ups, sit, interact, get-up…) drives it too; verified by rendering before committing to it.

**Gus Thudd** (concept, owner to approve): ex-strongman and the street's self-appointed lawn
inspector; lives by a stopwatch (press-ups at six, mowing at eight), flexes in every reflective
surface. Lawn-green singlet, tangerine track shorts, flat-top, wristbands, white sneakers — kept
well away from Hush's navy / white / cherry so they never blur at 50 px.

**How he is dressed — `tools/bakery/cast/neighbour.py`.** The mannequin atlas shares one cell
between an arm, half the torso, a leg and part of the head, so atlas recolouring cannot put a singlet
on the chest and skin on the arms. Instead every face is coloured by the **bone that carries most of
its weight** (chest → singlet, wrist → wristband, lower leg → skin / sock band, foot → sneaker /
sole), with height bands inside a part, pinned to cells of a palette generated in Blender. The look
is one table (`LOOK`) and one function (`colour_for`). Skinning is untouched.

**Fixes found on the way:**

| problem | fix |
|---|---|
| Gus faced the camera front-on at Hush's angle (the Large body rests ~20° differently) | per-character camera: Gus 65°, Hush 50° — matched side by side |
| shorts stripe landed on the knees as white patches | shorts end mid-thigh, stripe at the leg hole |
| ten sheets wider than 4096 px (flex 11,648) — blank sprite on many phone GPUs | sheets wrap into a grid ≤ 4096 a side (`cols` in the json); a sheet that cannot fit fails the bake |
| Gus floated 30 px mid get-up / sit (Medium clips on longer Large legs); whole-clip floor check passed it | clips are **planted** per frame by default (`"plant": false` for a future jump); validator checks every frame |

Per-character `ppm` (Gus 60 vs cast 80) makes him ~1.3× Hush on stage. 14 Gus clips (idle, walk,
run, flex, pushups, interact, use, sit, sit_idle, stand, startle, hit, knocked, getup) + Hush's 15,
all PASS, ~90 s from a clean checkout.

**Capture note.** Mid-session, long Godot captures returned stale frames: the scene logic was proven
running on time (step log through Gus's get-up at 20.7 s) but the window had stopped drawing (OS
display state). The knocked → getup join was verified offline instead: body centre moves 0.5 px.

Open: Gus has no face yet (the faces round); the GDD still describes Bellows — rewriting it around
Gus is the owner's call.

## 10. Round 5 — FREEZE statues and the neighbour's reactions (composed, still flat)

Owner: keep improving; the **flat** takes are right, the cartoon filter was too wobbly and unnatural
(it stays off — `amount` 0 everywhere). The biggest gap between the cast and the game was motion the
GDD's core loop needs and the CC0 library does not have: Hush's **FREEZE** (eight statue poses, GDD
§5) and the neighbour's suspicion / anger / catch. Nothing here is hand-keyed and nothing is filtered:
new clips are **composed** from library poses by three recipe fields in `clips.json`, applied in
`bake.py` before the same render, plant, prune and validate path as every other clip.

| field | what it does | used for |
|---|---|---|
| `pose` | ease (quadratic ease-out, no overshoot) from the character's `rest` stance into ONE frame of any library clip in `secs`, then hold it `hold` s dead still; accent = the lock frame | Hush's 8 `freeze_*` statues |
| `layer` | some bones (and their children) from a second clip; on a loop it is time-fitted to the base period so the seam stays clean | Gus `stomp` = Large walk legs + fists-up arms |
| `tweak` | eased (cosine) extra turns per bone in BODY axes `[t, pitch, roll, yaw]` (+pitch bows, +roll leans to its own left, +yaw turns to its own left = toward the Stalls), applied parents-first about each bone's head | Gus `search` look-around; `stomp` hunch; `freeze_hurrah` proud lean |
| `repeat` | plays a base loop N times so a tweak can be longer than the clip | `search` (Idle_A ×2 = 3.9 s) |

**Statues (Hush):** bow (PickUp 0.43 s), kick (Kick 0.37), punch (Punch_A 0.58), tiptoe (Sneaking
1.55), discus (Throw 0.78), hurrah (Cheering 0.33 + lean back), ta-da (Spawn_Air 0.49, arms wide on
her toes), boulder (Spawn_Air 0.89, curled up like a garden rock). Picked by probing candidate clips
at 12 fps and ranking frames by how far the silhouette reaches beyond the standing pose; the first
picks for "wave" and "cast" were too close to standing to read at 50 px and were replaced. Each is a
0.2 s snap + 0.6 s hold (the runtime holds the last frame for as long as FREEZE is held).

**Gus:** `search` (looks to the Stalls, then away, inspecting the floor), `fume` (fists-up boxer's
stance), `stomp` (fists-up march, measured ground speed — no sliding), `grab` (the lunge that pulls
Hush out of a hiding spot).

**Fixes on the way:** re-importing a library already loaded returns its actions as `Throw.001`
(recipes load libraries by path and match that suffix); a cubic ease's last step was 1.6 % of the
move — a dead frame at 48 px that the validator rightly failed — so the snap is quadratic (6 %).

41 clips (Hush 23, Gus 18) PASS in ~113 s from clean. The stage rehearsal now has Hush strike *ta-da*
in plain sight while Gus searches, stomps over and lunges at the statue before the gag lands; looked
at stills and a 31-frame, one-per-second sequence (`spikes/bakery_freeze_*.png`,
`bakery_statues.png`, `bakery_gus_reactions.png`).

Open: punch / discus / tiptoe are the least distinct statues (a hand-picked tweak could push them
apart); statue choice by room/prop is runtime work; faces and props in hand are still later rounds.

## 11. Round 6 — faces and props in hand

Owner: keep the characters as they are; next, faces and props in hand. Flat look unchanged.

**Gus's face** (`tools/bakery/cast/neighbour.py`, `add_face`). The Large mannequin's head is blank and
small for the body, so the face is a few BIG shapes that stand off the head and survive a
three-quarter view at ~50 px: heavy brows, a bulb nose and a strongman's **handlebar moustache** (the
shape that carries him in profile). Parts are placed by ray-casting onto the head's front surface and
skinned rigidly to `head`. Five **expression sets** — neutral (smug), suspicious (one brow up),
angry (brows down, gritted teeth, temper flush), shock (eye whites, "O" mouth), daze (squeezed shut) —
are meshes named `Gus_Face.<expr>.<part>` (`all` = shared nose and moustache). `bake.py` shows one set
per frame; `face` in `clips.json` is one expression or timed switches, so startle goes neutral →
shock on the jolt, knocked goes shock → daze, and getup comes round daze → angry. Hush keeps her
painted face: it already reads, and a mime's face staying put is the joke.

**Props** (`tools/bakery/props.py`). Nine chunky flat-colour items, each authored in PROP SPACE
(origin = grip, +Z along the handle): apple, kipper, feather duster and Clarence (GDD items/cast),
saw, mallet, spanner (rigging), stopwatch (Gus) and a debug `stick`. `bake.py` parents them to a bone
— KayKit's `handslot.l/.r` weapon sockets, or any bone (Clarence rides on `chest`) — so the library
motion carries them, and shows them by `from`/`until` (the kipper appears as she grabs it, the apple
leaves on release). The body alone decides floor contact; props only widen the cell. Items are
scaled per character (cast ppm ÷ character ppm) so an apple is one apple on stage in either hand; a
character's `wear` list is added to every clip (`"wear": false` opts out — Hush's `squeak` holds
Clarence instead).

| clip | prop | note |
|---|---|---|
| hush (every clip) | Clarence tucked at the chest | GDD: rides in her braces |
| hush `squeak` (new, Holding_A) | Clarence in hand | the squeak verb |
| hush `saw` (new, Sawing) / `hammer` (new, Hammering) | saw / mallet | readable "rigging" at 50 px |
| hush `tinker` / `pickup` / `throw` | spanner / kipper (from 0.5 s) / apple (until 0.82 s) | |
| hush `freeze_hurrah` | feather duster | "Liberty" statue |
| gus `use` | stopwatch | lives by it |

**Found on the way:** the camera sits on the cast's LEFT, so the right hand is the far hand —
items there vanished behind the body; each prop was placed by rendering a debug stick through the
clip and then trying rotations side by side (the stopwatch showed its back until `rot [0, 90, 0]`).
Gus's `Use_Item` raises his right hand, not the near one. `build.sh` reported a failed Gus build as
built (it checked for a stale `.glb`); it now deletes the old model first.

44 clips (Hush 26, Gus 18) PASS in ~125 s from clean. Rehearsal: Gus checks his stopwatch, Hush saws,
hammers and squeaks Clarence before the freeze. Looked at close-ups, game-size renders, a stage still
and a 16-frame sequence (`spikes/bakery_gus_faces.png`, `bakery_props*.png`).

Open: "suspicious" is the subtlest expression at three-quarter view; Hush has no expression changes;
props pass through fingers rather than being gripped (fists are closed blobs, invisible at 50 px);
the GDD's other items (squeaker, balloon, butter, flour…) are one builder each in `props.py`.

## 12. Round 7 — Hush's expressions, and the first gameplay sample

Owner: Gus is fine; Hush should get expressions too; props are ours to grow; and show a **sample of
actual gameplay** — how the new cast integrates, not a full game.

**Hush's expressions.** Her neutral face stays the painted one (a mime's resting face is the act).
Three panto overlays — **shock** (saucer eyes, O mouth), **daze** (drooped shut) and **grin** (closed
happy eyes, big smile) — built by the same facekit as Gus's (`tools/bakery/cast/facekit.py`, shared
now), pinned to her palette, placed by measuring where the **painted eyes actually are**: the head
faces that sample the atlas ink cell average to (±0.19, z 1.60) — the first guess by eye was a head
height too high. The covers use her face-paint colour so the painted eyes vanish under them. Wired:
startle → shock on the jolt, knocked shock → daze, getup wakes neutral, cheer / squeak / the ta-da
and hurrah statues grin. bake.py change: a model without a "neutral" set means "bare face".

**The gameplay sample** — `res://proto/bakery/Gameplay.tscn` (`gameplay.gd` + `gameplay.json`): one
scripted Act in the parlour with the GDD's staging on screen — hotspot badges (gold rig point, blue
closed-eye hiding spot), ghost-finger taps and holds, the **RIG ring** (partial fill kept on release),
**FREEZE** held while Gus walks past and inspects the "statue" (suspicious face, caption "Hm. New
statue. …Tasteful."), the **awareness "?"** filling over Hush and draining when she's still, his
**stare strip** on the floor, **Clarence** as a lure (squeak → "WHO SQUEAKED?!" stomp), hide behind
the plant (sprite ghosts at 45% so the demo stays readable), the rigged gramophone firing a
boxing-glove-on-a-spring with confetti, knocked flat → getup → fume while Hush takes her bow, Stalls
flashes and the Applause meter. The timeline is ONE event list in `gameplay.json` (move / clip /
ghost / ring / freeze / hide / bubble / awareness / gag / applause / caption…); the engine only knows
the verbs, blits the baked sheets exactly as the stage viewer does (same anchors, ground speeds and
`enter_dx` chains), and loops every 37 s. Locomotion uses a per-move time multiplier `k` (clip clock
and measured ground speed scale together, so feet stay planted): walk ×2.6 ≈ the GDD's tiptoe pace.

**Two instability causes found and fixed:**
* raw bake frames lived in a fixed `/tmp/bakery_frames` — a parallel session in another worktree
  rmtree'd clips mid-bake (validate read half a clip: "accent 2 of 1"). Now keyed by checkout path.
* a virtual display can run Godot unthrottled (bursts near 1000 fps), so a real-time timeline crawls
  or sprints on camera depending on load; the sample caps `Engine.max_fps = 60`, putting live play
  and frame captures on one clock.

44 clips PASS in ~133 s from clean. Evidence: `spikes/bakery_hush_faces.png` (close + game size),
`bakery_hush_expr_clips.png` (expressions inside baked clips), `bakery_gameplay_freeze.png` (the
freeze-in-plain-sight beat), `bakery_gameplay_gag.png`, `bakery_gameplay_seq.png` (19-tile act).

Open: the sample is scripted, not played (touch input is the real game's job); knocked Gus overlaps
the table a little; Hush's grin lids sit close to her hairline at some angles; next prop batches come
per story as the owner identifies them.

## 13. Round 8 — Act I: one full scene on a set built in Blender

Owner: the sample was too basic; build one full scene, visually appealing, everything from scratch
in Blender, and take everything else off the screen (visual cleanup only for now).

**The set** — `tools/stage/act1_set.py` models Gus's front room from primitives (no imported scenes):
striped wallpaper and wainscot, plank floor and rug, a window onto an immaculate striped lawn, door,
self-portrait of Gus, clock, armchair, floor lamp, gramophone, standing mirror, weight rack and
trophy shelf; around it a gold proscenium with velvet valance, house curtains, footlights and a
silhouetted front row of the Stalls. One ortho camera tilted 10° at exactly the cast's on-screen
scale (1 model unit = 128 px = the baked sheets at 1.6x), so the actors stand in the room at the
right size. It renders as layers: the static room, things in front of the actors (the plant), each
moving prop alone with its pivot (door shut/open, trophy pedestal, trophy, butter, boxing glove,
spring, three dumbbells), frame, curtains, audience, and HUD icons on their own camera (Clarence,
spanner, ice crystal, star, comic burst, beret stamp). `tools/stage/build.py` crops them and
writes `game/proto/act1/art/layout.json` (positions, pivots, named marks). ~25 s for everything.

**The scene** — `res://proto/act1/Act1.tscn` (`act1.gd`, `act1.json`), a 67 s looping Act:
curtain up on Gus doing press-ups; Hush slips in by the door and rigs the gramophone behind his back;
he checks his stopwatch and goes to the mirror; she saws the trophy pedestal; he turns — she FREEZEs
as a Liberty statue and he inspects her ("Since when do I own a statue?" … "…Tasteful."); she butters
the floor behind his flexing back, runs to the plant and squeaks Clarence; he stomps after the
noise, slips, slides into the pedestal and the trophy bonks him; up, livid, he goes for "calming
music" — the glove springs out of the horn and launches him into the weight rack, the dumbbells
follow; confetti, Hush's bow, curtain down, the Curtain Call card. On screen only the show and the
game's HUD: Applause meter on the valance, Clarence / FREEZE / RIG buttons with the rig ring, touch
ripples, speech bubbles, the awareness "?", comic bursts, dazed stars, the Stalls bobbing as they
laugh. No debug captions or labels. `tools/scripts/play.sh` with no argument now opens this scene.

Evidence: `spikes/act1_beats.png` (freeze, bonk, pow, bow), `act1_finale.png`, `act1_seq_a/b.png`.
Open: sound; Hush's statue choice by room; Gus's knocked pose meets the floor props approximately
(sprites, no contact); the HUD's RIG button covers the rack corner on 20:9.

## 14. Round 9 — Act I, quality pass (same pranks, same story)

Owner: Act I is the right path and fun to watch; push quality as far as it goes before moving on.

**Rendering.** The set now renders in **Cycles** on the GPU (Metal), denoised: bounce light, soft
contact shadows, glossy planks and glowing practicals. Lighting was rebalanced for path tracing (the
first Cycles pass washed out): dimmer ambient, a defined warm key, lamp / pendant / sconce / window /
footlight sources. `python3 tools/stage/build.py` renders everything in ~7 min; `--engine eevee`
previews in ~1 min. Small layers render inside their own screen box (`use_border`) at fewer samples.

**Set dressing** (all primitives in `act1_set.py`): Regency wallpaper with a diamond motif (shader),
plank grain, picture rail, hanging pendant lamp, two sconces, a coat stand with Gus's tracksuit top
and cap, side table with a protein shaker on a doily, a framed "LAWN INSPECTOR OF THE YEAR — G.
THUDD" certificate (Blender text), a window-sill cactus, a light switch and socket for scale, and a
daylight **shaft** layer from the window.

**Motion baked in 3D.** Props that move are now animated in Blender and rendered frame by frame,
in place (no 2D rotation of flat sprites): the door swing (6), pedestal topple about its base edge
with a settle (9), trophy flung, spinning onto his head and hopping off on its side (12), three
dumbbells raining off the rack and rolling (12), the glove on a real coiled spring that stretches and
recoils (7), the house curtains gathering as they open (9), and a dust puff (6, drawn wherever it
happens). `build.py` groups them into `layout.json` → `seqs`.

**Direction** (`act1.gd` + `act1.json`): an eased camera (push in on the first rig, the freeze
inspection, the butter; punch in on the slip and on Gus at the horn; let the flight go wide; settle on
the bow), shake, dust on every landing, a motion smear on the flight, landing squash, the plant
rustling when Hush dives in and squeaks, a spotlight for the bow, dust motes in the window shaft,
typewriter speech bubbles, softer layered contact shadows, a warm tint so the cast sits in the lamp
light, a smaller HUD so the finale stays clear.

**Capture.** `--fixed-step` advances the show exactly 1/60 s per frame and `--start=SECONDS`
fast-forwards to a beat; long captures on this machine still go stale (window stops redrawing), so
evidence stills are shot as short runs from `--start`.

Evidence: `spikes/act1v2_set.png`, `act1v2_sequences.png`, `act1v2_freeze.png`, `act1v2_bonk.png`,
`act1v2_flight.png`, `act1v2_pow_bow.png`.

Open: art is 22 MB at full 2400×1080 per sequence frame (pack into atlases / trim before a phone
build); no sound; the characters are still lit by the bake's flat rig (re-baking them under the set's
lights is the next quality step); a small dark notch under the closed curtains at centre.
