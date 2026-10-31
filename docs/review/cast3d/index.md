# The cast in 3D — KayKit base, re-dressed (REDESIGN_3D R2)

The procedural characters that used to live here are gone. The cast now stands on the KayKit
Adventurers rig (CC0), re-dressed into Hush and Bellows, and moves on the KayKit Character
Animations library. The reasoning and the alternatives are in
[`../oss_cast/index.md`](../oss_cast/index.md); this page is what came out of it.

## What to look at

| File | What it shows |
|---|---|
| `cast_idle.png` | Hush and Bellows at review framing (1200×540 = a phone held sideways) |
| `hush_sneak.gif` | her walk — the library's `Sneaking`, which is the right motion for this game for free |
| `hush_rig.gif` | rigging a prank — the library's `Interact` |
| `bellows_walk.gif` | his strut |
| `*_stability.png` | the motion-quality report for each capture (jitter, pops, frozen runs) |

Re-render any of them yourself — see [`../../TESTING_ON_MAC.md`](../../TESTING_ON_MAC.md).

## Motion quality

Measured with `tools/anim/stability.py` on every frame, same camera and capture settings:

| Capture | jitter (≤ 0.25) | pops (0) | smooth (≥ 85) |
|---|---|---|---|
| Hush sneak | **0.13** | 0 | 93 |
| Hush rigging | **0.06** | 0 | 97 |
| Bellows walk | **0.18** | 0 | 91 |
| *(the procedural rig this replaced)* | *0.42* | *0* | *79* |

Two things got us here. The library clips are professionally animated, and the runtime stopped
fighting itself: grounding used to run *after* the jiggle springs had already sampled the body's
position, so every frame the springs chased where the body had been one frame earlier — two
feedback loops on one skeleton, oscillating at 2–3 frames. Grounding is now solved from the FK-only
pose and the body moved before the springs run, the lift is critically damped, and the foot plant
fades in over a 2 cm band instead of switching on at a hard threshold.

## How a character is made now

The body, skeleton, skinning and 132 clips are KayKit's and are never rebuilt. `tools/art3d/cast/`
does only what makes a character ours:

1. **`recolour.py`** repaints the character's gradient atlas into our palette. KayKit textures a
   whole character from one 8×8 grid of colour cells, so re-dressing is repainting cells — no
   re-unwrap, no per-character texture work. Each cell keeps its own shading ramp.
2. **`redress.py`** (Blender) drops the meshes whose cells clash (the Rogue's cape, the Mage's
   hat), swaps the atlas in, paints Hush's Breton stripes onto the tunic's **own faces** by height
   band, and adds our accessories — beret, braces, bouffant, nose, specs, cravat — as meshes on new
   jiggle bones parented into KayKit's rig.
3. **`build.sh`** runs both for both characters. About 4 seconds each.

| | Hush (from the Rogue) | Bellows (from the Mage) | budget (§5.6) |
|---|---|---|---|
| Triangles | 9,518 | 9,044 | ≤ 10,000 |
| Bones incl. jiggle | 26 | 28 | ≤ 50 |
| Draw calls | 2 per mesh (toon + outline) | same | ≤ 4 |

Hush's stripes are worth a note: a KayKit face samples one flat palette cell, so the whole tunic is
one colour whatever is painted in that cell. The first attempt added hoops of geometry round the
torso and read as barrel bands. Repainting the tunic's existing faces by height band gives real
stripes that follow the body, skin with it for free, and cost no extra triangles.

## Animation: library first, ours for the gags

`game/data/anim/clipmap3d.json` maps each of our clip ids to a library clip. Walking, idling,
reaching, sitting and reacting are all library animation. What stays ours is the comedy the library
has no equivalent for — the freezes, the snicker, the sneeze — replayed on the 3D skeleton by
`PoseRetarget3D`, which is why that retarget was worth keeping when the custom rig was dropped. A
clip in neither list still plays, as a 2D overlay, with one warning.

## In the game

The 3D cast now plays in a real Night. `CastProxy2D` renders each character into its own
SubViewport and shows it where the 2D rig used to stand, behind the same duck-typed interface
`CharacterView` already used — so the house, HUD and effects stay 2D and nothing else changed.
It is **off by default** (`MND_CAST3D=1` or `--cast3d`), because the test suite and every house
review shot assume the 2D rig. `in_game_n01.png` is Night 1 with it on.

This is a bridge, not the destination: at R1 the set becomes 3D and the characters move into the
shared world, at which point `cast_proxy2d.gd` goes away.

## Honest state
- **Faces are baked into the texture.** Both characters currently wear the one expression KayKit
  painted. The face-card atlas (`face_hush.png`, `face_bellows.png`) and the shader path for it
  exist and the full 2D expression vocabulary is ported, but it is not yet applied to a KayKit
  head — that is the next cast job.
- **Colour polish left.** A few atlas cells on Hush's bracers are still the Rogue's leather, and
  the Mage's belt pouch and book are still on Bellows' coat. Both are entries in `recolour.py`.
- **No on-device perf numbers.** Budgets are met in the editor; risk X1 needs a real Android run.
- **Seated clips need grounding off** (`ground_weight = 0`), not yet a per-clip flag.
