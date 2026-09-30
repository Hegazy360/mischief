# Look-dev "Toy Box": Hush and Horace Bellows

Chunky vinyl-toy / soft-clay characters with big heads and stubby limbs. Materials are matte pastel, with toy
shading and a thin outline. Faces are swappable decals. Both characters are built headless in Blender 4.5 (bpy),
rigged on the CC0 Quaternius UAL skeleton, exported as one `.glb` each, and rendered in Godot 4.7.2
(Compatibility / GLES3) in the shared diorama at 1200×540.

## What was built

- **Forms.** Everything is procedural and original.
  - Main parts are superellipsoid "blobs" built on quad spheres: head, torso, shoes, palms and beret.
  - Limbs and fingers are swept capsules.
  - The bouffant, sideburns, cravat and sneeze puff are metaball clusters. They are decimated, then smoothed.
  - Colour borders are cut exactly with bisect planes: the Breton stripes, soles, coat lapels and cup band.
  - The bob hair and the plum coat are "masked shells". The base surface is pushed out where there is hair or
    coat and pulled inside where there is face or waistcoat. Their edges are the clean intersection curves, and the
    outline pass draws a hairline or lapel line there for free.
- **Faces.** The head's front faces carry a planar FaceUV (`TEXCOORD_1`). The toy shader alpha-composites 4
  layers, each taking one cell from one 1024² atlas per character:

  | Layer | Hush cells | Bellows cells |
  |---|---|---|
  | brows | 6 | 7 |
  | eyes | 9 | 9 |
  | mouth | 11 | 9 |
  | extra (cheeks, tear, sweat, steam) | 4 | 4 |

  - Presets are defined as eyes + brows + mouth + extra, plus temper and specs, in `face_<who>.json`.
  - Each clip carries a face timeline, exported next to the `.glb`.
  - The eyes blink on their own.
  - Bellows' temper (peach to beetroot) is a skin tint driven by palette-alpha flags, so only skin and nose tint.
  - Worn specs, sideburn bristle and the nose twitch are bones.
  - The atlas is drawn from SVG with `rsvg-convert` (`src/face_atlas.py`).
- **Shader** (`proj/toy/toy.gdshader`). It is unshaded and does its own lighting, from the diorama key light's
  direction:
  - a soft terminator with a warm lilac shadow tint;
  - ground-bounce darkening;
  - a rim light and a soft vinyl sheen;
  - the decals and the temper tint.

  The inverted-hull outline is the diorama's `outline.gdshader` at 2.4 px. Each character is one material and one
  mesh, with no per-light pass.
- **Rig.**
  - The UAL 65-bone skeleton is re-proportioned by bone length. Directions and rolls are kept, so the UAL clips
    still apply.
    - Hush: legs ×0.42, spine ×0.7, arms ×0.55.
    - Bellows: legs ×0.24, spine ×1.17, arms ×0.74.
  - Pelvis keys in the library clips are scaled to the new hip height.
  - Extra bones:
    - Hush: `beret`, `prop_r` (pepper pot), `fx_pepper`.
    - Bellows: `bouffant`, `sideburn_l`/`sideburn_r`, `nose`, `specs_face`, `specs_chest`, `cravat`,
      `fx_choo` (sneeze burst), `prop_r` (teacup), `prop_l` (saucer).
  - Props and FX live in the skinned mesh. A bone at scale 0 hides them, so they cost no extra draw calls.
- **Clips.** They are keyed in bpy with a small pose language: rotations about armature axes, `sym`, `swap`,
  `lerp`, and root / pelvis offsets.
  - Hush has 6 custom clips:
    - `Toy_Idle_Loop`, `Toy_Tiptoe_Loop`, `Toy_Snicker`: the comedy take (gloves to the chin, giggle shakes, sly
      glance at the Stalls);
    - `Toy_Pour_Loop`, `Toy_Peek_Loop`, `Toy_Freeze_Statue`.
  - Hush also carries 10 UAL clips.
  - Bellows has 5 custom clips:
    - `Toy_Idle_Loop`, `Toy_Walk_Loop` (a pompous strut-waddle), `Toy_Tea_Sit_Loop` (pinkie up);
    - `Toy_Sneeze`: the comedy take, 4.5 s. Sip, nose twitch, "ah… ah-ah… AHHH" hold, then CHOO with the spray
      burst. He is launched backwards off the stool by 1.4 m of root motion, lands in the sink with his slippers up,
      and ends dazed.
    - `Toy_Dazed_Sink_Loop`.
  - Bellows also carries 8 UAL clips.

## Numbers

| | Hush | Bellows |
|---|---|---|
| triangles | **14,516** (7,395 verts) | **14,972** (7,709 verts) |
| bones | 68 (UAL 65 + 3) | 75 (UAL 65 + 10) |
| meshes / materials | 1 skinned mesh / 1 material | 1 / 1 |
| textures | palette 128² (0.06 MB) + face atlas 1024² RGBA | same |
| texture memory | measured +5.4 MB per character (atlas with mipmaps, uncompressed, runtime GLTF load); ≈1.4 MB with the project's ETC2/ASTC import; ≈0.35 MB with a 512² atlas, which is still enough at game scale | same |
| buffer memory | +0.69 MB | +0.69 MB |
| `.glb` size | 3.5 MB, 16 clips | 3.7 MB, 13 clips |
| standing height | 1.58 m to the beret, ~2.5 heads | 1.74 m to the bouffant, ~2.2 heads |

- **Draw calls** (`--perf3d`, kitchen at game scale, h = 3.9 m):
  - Each character adds **+4**: base, outline hull and 2 directional-shadow cascades. There is no lit pass.
  - Set alone: 43 draws and 54k primitives. With both characters: **51 draws and 172k primitives**.
  - With MSAA 2× and key shadows off: 27 draws and 86k primitives.
  - Studio (no set): 4 draws and 58k primitives per character.
- **Render time.** This container renders with llvmpipe (software GL), so fps is not meaningful for a phone.
  - The same scene ran at 5–9 fps with or without the characters. The difference is noise.
  - A Blender build takes about 14 s per character: UAL import, retarget, model, clips, `.glb` export.
  - A Godot still takes 10–13 s, mostly engine start-up.
  - The 300-frame fixed-timestep sneeze sequence took 44 s.
  - The whole board set rebuilds in 2 min 11 s (`./make_boards.sh`).

## Scaling to ~40 animations per character

**From CC0 libraries.** The Quaternius UAL1 and UAL2 clips play on these rigs with no retargeting tool, because
the skeleton is the same and only bone lengths change. `ual_on_chibi.png` shows the evidence.

- **Hush, about 14 clips.** walk, jog, sprint, crouch-walk, crouch-idle, interact, pick-up, push, jump start /
  loop / land, roll (dive into a hiding spot), and the "yes" / "no" nods as mime beats. These already read well on
  her.
- **Bellows, about 6 clips.** walk (only as a base for the strut), sit enter / idle / exit, interact, pick-up and
  talking. He needs a seat-height bake.
  - His barrel breaks anything that brings the arms to the body or the face. Arms sink in: FoldArms,
    Consume and Hit_Head all fail or read weakly.
- The build step now keys the extra bones (props, FX, worn specs) at scale 0 into every library clip. Without it
  they appeared in every library clip. Library clips also need face timelines added.
- Most library clips will want an additive chibi fix: arms spread about 10° so they clear the round torso, and a
  head-bob damp.

**Custom.** Every comedy beat is custom, because the jokes are character-specific. That is the right split for this
game.

- **Hush, about 26 clips:**
  - tiptoe start / stop / turn;
  - 4 freeze statues and snicker variants;
  - peek in / out;
  - hide in / out (pantry, curtain, under the table);
  - 3 rig-tinker loops (fiddle, frantic, wipe brow);
  - pour, and a Clarence squeak;
  - caught, the Hook yank and the curtain-call bow.
- **Bellows, about 34 clips:**
  - strut start / stop / turn and a blind shuffle;
  - tea, warm-up and 6 micro-gags;
  - suspicious look with specs on, "PIPE DOWN!" and a furious stomp;
  - one take and one dazed / residue loop for each prank (sneeze, doorframe bonk, and so on);
  - the curtain-call slow burn.

**Cost.** Two ways to make the custom clips:

- **Pose language (bpy).** A loop took 20–40 min with 2–3 render-and-look iterations. A hero take took 2–4 h: the
  sneeze needed 5 rounds for face readability, the spray and the leg angles.
- **Animator in Blender.** For the 10–15 hero takes, a Blender animator on this same rig would be faster and
  clearly better, particularly for overlap, arcs and spacing. The toolchain accepts hand-keyed actions unchanged:
  export via `ACTIONS` mode, with faces as a JSON timeline or keyed on the bone.
- **Planning figure.** About 60 % custom and 40 % library by count, and about 85 % custom by effort.

## Risks

1. **Chibi on a real-scale set.**
   - The counter reaches Hush's chin, and her 0.3 m arms cannot reach counters. Bellows' arms cannot pass his belly.
   - Staging has to bring props to them. The pour was restaged with the jar on the stool, and props are
     toy-scaled ×1.5.
   - Otherwise scale the furniture about 0.8×. The spec should decide this before content is built.
2. **Faces in profile.** The camera is side-on, and decals flatten toward the silhouette.
   - Walks need a 25–40° cheat-out plus head turns toward the Stalls. The tiptoe already does this.
   - Left-facing moves need the rig mirrored. The asymmetric decals (the tear, the sly brow) then flip, which is a
     small identity risk.
3. **No received shadows.** The unshaded toy shader keeps the look consistent and saves the lit pass. The cost is
   that characters are never shaded by the set. A `light()` variant is possible at +1 pass per character.
4. **Procedural modelling ceiling.**
   - Limbs are tubes; Hush's legs read as sticks.
   - The metaball bouffant is lumpy or blobby rather than sculpted.
   - Distance-based weights pinch at extreme elbow and knee bends.
   - A modeller pass would fix all three: sculpted gloves and shoes, a retopologised bouffant, painted weights.
     That is about 2–3 days per character.
5. **Secondary motion is hand-keyed.** The beret lag, bouffant and sideburn wobble are keyed by hand. Spring bones
   (SkeletonModifier3D) are needed for free jiggle across 40 clips.
6. **Root-motion gags vs the sim.** The sneeze travel is baked for one staging (yaw −38° on the stool). In the game
   the sim should own travel and the clip only the arc, as in 2D.
7. **Library-clip hygiene.** Unkeyed extra bones show props, which is now fixed at build time. Face timelines must
   be authored for every library clip, or they fall back to the neutral face.

## Honest appeal rating for a mobile audience: 7.5 / 10

For:

- Warm and instantly readable. At game scale (`ingame_*.png`) the heads are about 90 px tall at 1200×540, and the
  faces, gloves, beret and bouffant all read. The actions read too: paws-up tiptoe, the shaker over the jar,
  gloves parting the curtain, the CHOO spray and slippers-up in the sink. That answers the owner's "actions not
  obvious".
- Hush is genuinely cute: big warm eyes, blush and a sneaky grin, never creepy.
- Bellows' temper tint plus specs plus sideburn bristle make the "his body is the meter" rule readable in one glance.
- Cheap and robust: 1 material, about 15k triangles, 4 draw calls and one atlas per character, and faces that
  cost no bones.

Against:

- The procedural modelling shows. The limbs look primitive, the bouffant looks like a cotton cloud rather than a
  styled dandelion clock, and Bellows' face is a little small inside his hair and sideburn frame.
- Keyed-by-code motion is serviceable but stiffer than hand animation.
- It is not yet at Animal Crossing or Fall Guys polish. With a modeller and animator pass on these same rigs and
  shaders, I would expect 8.5.

## Files (`look-toy/`)

- **Deliverables**
  - `turnaround.png`
  - `expressions.png`
  - `poses.png`
  - `ingame_kitchen.png`, `ingame_wide.png`: 1200×540 Godot, game scale
  - `sneeze_strip.png`: 8 frames, game scale
  - `sneeze.gif`: the whole take, fixed timestep, 15 fps
  - `ual_on_chibi.png`
  - `NOTES.md`
- **Build output**
  - `build/hush_toy.glb`, `build/bellows_toy.glb`, each with a `.json` of face timelines and clip metadata
  - `build/face_*.png` and `.json`: atlas and presets
  - `build/toy_palette.png`
  - `build/honey_jar*.glb`
- **Blender sources** (`src/`)
  - `toy_lib.py`: geometry, retarget, skinning, pose keying, export
  - `build_hush.py`, `build_bellows.py`, `clips_hush.py`, `clips_bellows.py`
  - `toy_pose.py`, `toy_palette.py`, `face_atlas.py`, `build_props.py`
  - `compose.py`, `sheet.py`
- **Godot**
  - `proj/` is a private copy of the shared diorama (the shared one is untouched), plus `proj/toy/`:
    - `toy.gdshader`
    - `toy_char.gd`: material setup and face driver; drop-in for the game view
    - `toy_shot.gd` / `ToyShot.tscn`: DioramaShot plus toy characters, props, stills and placement
    - `toy_studio.gd` / `ToyStudio.tscn`: turnaround, heads and studio
  - `proj/tools/shot3d_fixed.sh` renders with a fixed timestep.
- **Scripts**
  - `build.sh`: palette, atlases, both `.glb`
  - `make_boards.sh`: everything
  - `still.sh`, `turn.sh`, `heads.sh`, `clipsheet.sh`, `expr.sh`
  - Intermediate renders are in `out/`; `out/perf*.txt` holds the raw perf lines.

## Licences

- **Skeleton and 18 library clips.** Quaternius *Universal Animation Library* 1 and 2 [Standard], **CC0 1.0**:
  https://quaternius.itch.io/universal-animation-library and
  https://quaternius.itch.io/universal-animation-library-2. Local copies and their `License.txt` are under
  `../assets/quaternius/`.
- **Original work.** All meshes, face art, the palette, shaders, scripts and the 11 custom clips were made for MND
  in this look-dev.
- **Board fonts.** The labels use the game's own Lilita One and Nunito (SIL OFL), from
  `game/ui/theme/fonts`. They are used only for these review images.
