# Look-dev "Stop-Motion Puppet": Hush and Horace Bellows

The characters are handmade miniature puppets, and the dollhouse becomes a small theatre set.

- **Materials.** Felt, chunky knit, plasticine, wool roving and velvet.
- **Shapes.** Everything is slightly lumpy on purpose.
- **Eyes.** Big glossy bead eyes with eyelid shells.
- **Mouths.** Clay replacement mouths that swap instantly.
- **Motion.** Clips play "on twos" (12 fps steps) and the fabric boils slightly between steps.
- **Set.** The shared diorama gets painted-card walls, printed wallpaper, floorboards and a tiled dado. It also gets
  a red velvet swag valance with gold fringe, tab curtains and brass footlights along the lip of the stage.
- **Tools.** The characters are built headless in Blender 4.5 (bpy) on the CC0 Quaternius UAL skeleton and
  exported as one `.glb` each. Everything is rendered in Godot 4.7.2 Compatibility (GLES3), with the game camera at
  1200×540.

## What was built

### Characters

Both are procedural and original. `src/plib.py` is forked from look-toy's `toy_lib.py` (UAL retarget, skinning,
pose language), with these additions:

- detail UVs;
- `lumpy()` hand-made unevenness;
- analytic two-bone **IK baking**, used for hand-to-mouth, cup-to-lips and the grip on the curtain edge;
- a static-mesh exporter.

**Hush** (lanky, about 3.6 heads, 1.72 m to the beret)

- Clothes and hair:
  - tilted cherry felt beret with a stalk;
  - dark wool bob with a fringe;
  - chunky-knit Breton top with 6 bold stripes and striped sleeves;
  - red cotton braces with brass buttons;
  - slim navy twill trousers and black leather flats.
- Huge white felt gloves: 3 fingers and a thumb, with flared gauntlet cuffs.
- Face:
  - white clay face paint;
  - pink felt cheek appliqués;
  - the small blue teardrop;
  - thin black clay brows.

**Bellows** (a barrel on tiny legs, 1.72 m to the bouffant)

- Plum velvet frock coat with darker lapels and tails, over a cream waistcoat with a clean V panel and gold buttons.
- Gold satin bow and jabot.
- Silver wool-roving bouffant (metaballs) and mutton-chop sideburns on bones, so they can bristle.
- Bushy wool brows and a bulbous clay nose on its own bone, for twitch and flare.
- Brass specs on a chain on his belly. The worn pair is a replacement piece on the face.
- Chubby clay hands, and red felt slippers with pompoms.

### Faces are replacement pieces

- **Mouths.** Each mouth is a pillowed clay piece, projected onto the head by ray-cast, on its own bone.
  - Hush has 8: smile, grin, oh, grr, ah, wavy, snicker, pout.
  - Bellows has 7: pompous, sip, oh, grr, ah, choo, wavy.
  - Clips swap them with STEP scale keys, which is literally stop-motion replacement animation.
- **Pupils.** These are pieces too (normal, pinpoint, spiral).
- **Bone-driven parts.** Lids, brows and look direction are bones.
- **Studio faces.** 12 `Face_*` clips per character contain face bones only. `puppet_char.gd` layers them over any
  body clip with a second AnimationPlayer, so body × face combinations cost nothing to author.
- **Temper.** Bellows' temper is a shader uniform on the "skin" material class (peach to beetroot).

### Props and FX

Everything lives in the skinned mesh, and a bone at scale 0 hides it, so props cost no extra draw calls.

- pepper pot and pepper stream;
- teacup (pinkie up) and saucer;
- the CHOO burst: cotton-wool puffs on a root-parented bone, so the cloud hangs in the air while he flies;
- dazed felt stars on wires.

Separate static `.glb` files hold:

- the honey jar (amber glaze, gingham felt cap, wooden dipper);
- the stage dressing;
- the studio flats.

### Shader (`proj/puppet/puppet.gdshader`, 1 material per character)

- **Albedo and class.** A palette cell gives the albedo, and its alpha gives the material class (14 classes).
- **Detail textures.** Two procedural, tiling RGBA "fabric" textures (512², shared by both characters and the set)
  are sampled through metre-scaled detail UVs (UV2). The channels are:
  - felt, knit, clay thumbprints, twill;
  - wool, velvet, wood, paper.
- **Surface.** A derivative bump, so there are no tangents and no normal maps.
- **Custom `light()`:**
  - wrap diffuse, because felt and wool soak up light;
  - fibre sheen at grazing angles (velvet strongest);
  - tight highlights only on beads, brass and china;
  - a boil offset per stop-motion step.
- **Set shader.** `puppet_set.gdshader` restyles the spike's diorama pieces without touching them. A class map is
  laid over the diorama palette, with world-space projection: card, printed wallpaper, floorboards with seams,
  painted balsa, tiles, fabric, a wool rug and brass.
- **Lighting.** Warm tungsten key with soft PCF shadows, cool fill and dusky ambient. An optional unshadowed follow
  spot adds no extra pass.
- **Outline.** A thin warm-brown outline at 1.4 px is kept for phone readability. The A/B is `out/cmp_ab.png`:
  without it the characters sink into the pastel set.

### Clips (30 fps keys, played at 12 fps)

**Hush**

- `Puppet_Idle_Loop`, with a blink.
- `Puppet_Tiptoe_Loop`: paws up, knees high, a sly look at the Stalls.
- `Puppet_Snicker` (the comedy take, 4.1 s):
  - she glances at the Stalls and her gloves fly to her mouth;
  - her shoulders shake at 6 Hz, which is the fastest shake that survives stepping on twos, with squeezed happy lids;
  - she peeks over the gloves with a wink, then settles.
- `Puppet_Pour_Loop`: pepper into the honey jar while the other glove shushes the audience.
- `Puppet_Peek_Loop`.
- `Puppet_Freeze_Statue`: candelabra arms and one knee up; only the eyes dart.
- 12 `Face_*` clips.
- 15 UAL clips.

**Bellows**

- `Puppet_Idle_Loop`: chest out, hands on his belly (IK).
- `Puppet_Walk_Loop`: a pompous strut.
- `Puppet_Tea_Sit_Loop`: on the stool with his tiny legs dangling, pinkie up.
- `Puppet_Sneeze` (4.7 s):
  1. He sips, then his nose twitches three times.
  2. The build follows the rule of three: "ah…", "ah-ah…", "AHHH…". Each one tips his head further back, inflates his
     chest more and raises the cup higher. The build ends in a trembling hold.
  3. **CHOO**: a pose pop held for one step, landing on the same step as the cotton-wool burst.
  4. He is blown backwards 1.46 m in an arc into the sink basin, with his slippers up.
  5. He wobbles to a stop, dazed, with spiral eyes and stars. It is staged for yaw −52° on the stool mark.
- `Puppet_Dazed_Sink_Loop`, with the stars circling.
- 11 `Face_*` clips.
- 9 UAL clips.

## Numbers

| | Hush | Bellows |
|---|---|---|
| triangles | **16,996** (9,140 verts). About 3k are hidden at any moment: spare mouths and pupils, pepper pot, stars | **17,240** (9,181 verts). About 4k hidden: spare mouths, CHOO cloud, worn specs, cup and saucer, stars |
| bones | **91** (UAL 65 + 26 face, prop and FX) | **97** (UAL 65 + 32) |
| meshes / materials | 1 skinned mesh / 1 material, plus the outline pass | 1 / 1 |
| textures | 2 fabric textures, 512² RGBA, **shared** by both characters and the set: 2.7 MB with mipmaps uncompressed, about 0.7 MB with the project's ETC2/ASTC import. Palette 128² (0.06 MB). Each character measures only **+0.1 MB** texture memory (its embedded palette) and **+1.4 MB** buffer memory. | same |
| `.glb` | 6.5 MB (33 clips, every bone sampled every frame; optimisation would shrink it a lot) | 5.0 MB (25 clips) |

**Draw calls** (`--perf3d`, kitchen at the game camera, h = 3.9 m; raw lines in `out/perf/perf.txt`):

| scene | draw calls | primitives |
|---|---|---|
| puppet set + stage dressing | **24** | 44k |
| the spike's toon set, for comparison (prop outlines cost 19 extra draws) | 43 | — |
| kettle hidden | 22 | — |
| + Hush | 26 | 110k |
| + both characters + honey jar | **34** | 183k |
| same, no character outlines | 28 | 112k |
| same, no key shadows | 30 | — |

- Each character costs about **4 draws**: base, outline hull and shadow caster(s). Its custom `light()` runs in the
  base and shadowed-light passes.
- The stage dressing is 1 draw and 15k triangles.

**Render time.**

- The container renders with llvmpipe (software GL), so absolute numbers mean little for a phone. Relative to the set
  alone (106 ms/frame): +45 % with both puppets and outlines, +27 % without outlines.
- Blender build: 18–26 s per character, including UAL import, retarget, modelling, IK-baked clips and `.glb` export.
- Godot still: about 10 s, mostly engine start-up.
- The 170-frame fixed-timestep sneeze sequence takes 75 s.
- All boards: 111 s (`./make_boards.sh`).

## Scaling to ~40 animations per character

### From CC0 libraries

The Quaternius UAL 1 and 2 [Standard] clips play with no retargeting, because only bone lengths changed.
`ual_on_puppets.png` shows raw frames.

- **Played on twos they gain the puppet feel for free.** Because faces are separate overlay clips, any library body
  clip can take any face.
- **Hush, about 14 library clips.** These read well on her lanky proportions:
  - walk, jog, sprint, crouch-walk, crouch-idle;
  - interact, pick-up, push;
  - jump start / loop / land, roll (a dive into a hiding spot);
  - the yes / no nods as mime beats.
- **Bellows, about 6 library clips.** walk (as a base under the strut), sit enter / idle / exit, interact, talking.
  - The sit clips need a seat-height bake.
  - His barrel swallows any clip that brings the arms to the body: talking, pick-up and hit-head read weakly.
  - That is a limit of the design, not of the pipeline.

### Custom

This is the comedy, and the right split for this game. It is authored in the bpy pose language plus the new IK
targets (hand to mouth, cup to lips, grip a point in the set).

- **Hush, about 26 custom clips:**
  - tiptoe start / stop / turn;
  - 4 freeze statues and snicker variants;
  - peek in / out;
  - hide in / out (pantry, curtain, table);
  - 3 tinker loops, and the pour / smear / swap rigs;
  - the Clarence squeak;
  - caught, the Hook yank and the bow.
- **Bellows, about 34 custom clips:**
  - strut start / stop / turn;
  - tea, warm-up and the micro-gags;
  - suspicious with specs on, "PIPE DOWN!" and the stomp;
  - one take plus one dazed / residue loop for every prank;
  - the curtain-call slow burn.

### Why the style helps scaling

- **Faces are cheap.** They are piece swaps on bones, so there are no blend shapes to sculpt per expression. A new
  mouth costs about 10 lines of 2D outline.
- **Coarse keys look deliberate.** Stepped timing hides the stiffness of coarse, code-keyed interpolation: holds look
  intentional, not robotic.
- **Time per clip.** A pose-language loop took 20–40 min. The sneeze took about 6 render-and-look rounds: the cloud
  inside the head, the cloud one step late, over-leaning, a small build.
- **Where an animator pays off.** For the 10–15 hero takes, an animator in Blender on this rig would be clearly
  better, for arcs, overlap and spacing. The exporter takes hand-keyed actions unchanged.
- **Planning figure.** About 55 % custom and 45 % library by count, and about 85 % custom by effort.

## Risks

1. **Stepping versus responsiveness.** A player character posed at 12 fps can feel laggy. Mitigations:
   - the sim moves the node smoothly every frame and only the pose steps;
   - input shows on the next step (≤ 83 ms);
   - optionally step Hush's locomotion at 15 fps and keep 12 for takes.

   This needs a device test with the owner.
2. **The fabric detail is below phone resolution at 1200×540.** In game, the felt and knit read mostly as "soft
   matte with a warm sheen". The handmade feel there comes from shapes, sheen, the stepping and the set dressing,
   not from fibres. On a native 2400×1080 screen more detail survives. On low-end phones at render scale < 1 the
   look drifts toward plain soft 3D.
3. **Head size.** Lanky Hush has smaller on-screen heads than a chibi: about 60–65 px at 1200×540, against about 90 px
   for Toy Box. Faces read, including the pupils and the grin, but a 10–15 % bigger head would be safer.
4. **Triangle budget.** Each character is 17k, over the 15k budget. 3–4k of that is hidden replacement pieces.
   - Fixes: trim them to 150–200 triangles each, or split the pieces into a second tiny mesh (+1 draw).
   - The outline hull doubles the triangles per pass. Each character costs 4 passes with the key shadows on.
5. **Import gotcha.** Godot's glTF import drops any animation track equal to the rest pose. A replacement piece
   switched "on" at scale 1.0 therefore vanishes when the face clip is layered over a body clip. Pieces are keyed at
   1.002. Any exporter or optimiser change must keep that.
6. **Procedural modelling ceiling.**
   - Tube limbs; the metaball bouffant reads as a fleece hat up close; distance weights pinch at extreme bends.
   - A modeller pass would bring sculpted gloves, bouffant and cravat, painted weights, and real fabric seams and
     stitching. That is about 2–3 days per character.
7. **Root-motion gags versus the sim.** The sneeze's travel is baked for one staging. In the game the sim should own
   the travel and the clip only the arc, as in 2D.
8. **Look consistency.** The set restyle is a shader over the spike's pieces. New rooms need the same class map, and
   the dark ceiling and floor bands are now dressed with the valance and footlights. The HUD should sit over the
   velvet band. It is calm, but it is no longer flat black.
9. **Originality.** The stop-motion vocabulary (bead eyes, replacement mouths) is generic, and both designs are
   original. Art direction should avoid drifting toward any specific studio's character shapes.

## Honest appeal rating for a mobile audience: 7.5 / 10

For:

- **Distinctive.** Almost no mobile game looks like a stop-motion miniature, so it would stand out on a store page.
- **The set sells "the house is a stage".** Velvet valance, footlights, wallpaper and floorboards (`ingame_*.png`)
  make it feel like a theatre set on a tabletop, which the GDD framing wants.
- **Faces read at phone size.**
  - Hush reads as warm and cute, never creepy: big bead eyes with catchlights, blush and a smiling mouth.
  - Bellows' beetroot temper plus the specs going on is a one-glance "he's furious".
  - The spiral pupils and felt stars say "dazed" instantly.
- **The actions are obvious.** That was the owner's complaint about the 2D build, and here:
  - paws-up tiptoe;
  - the shaker over the jar with a shush;
  - the curtain peek;
  - the statue;
  - the CHOO cotton cloud;
  - slippers up in the sink.

  Stepped timing adds clear holds on the key poses.
- **Cheap to run.** 1 material and 4 draws per character, textures shared with the set, and faces with no textures.

Against:

- **The procedural modelling shows up close.** The bouffant and sideburns are lumpy clouds, the limbs are tubes, and
  the cravat and gloves are simple.
- **Small texture detail barely reads.** At game scale much of the "handmade" signal rests on shape and lighting.
- **Code-keyed animation is serviceable but stiff.** The on-twos stepping helps, but may feel choppy to players used
  to 60 fps. It needs an owner device test.
- **Bellows loses his face in some angles.** His face is small inside the bouffant and sideburn frame when sipping or
  in 3/4.

**Outlook.** Against Toy Box it is similar in instant cuteness, and more premium and more unusual. With a modeller
pass (sculpted hair and gloves, stitched seams) and an animator on the hero takes, I would expect **8.5**.

## Files (`look-puppet/`)

### Deliverables

- `turnaround.png`
- `expressions.png`
- `poses.png`
- `ingame_kitchen.png`, `ingame_wide.png`: Godot, 1200×540, game camera h 3.9 m
- `sneeze_strip.png`: 8 frames, game scale
- `sneeze.gif`: the full take, 15 fps capture of the 12 fps stepped playback
- `ual_on_puppets.png`: CC0 library clips on both puppets
- `NOTES.md`

### Build output (`build/`)

- `hush_puppet.glb`, `bellows_puppet.glb`, each with a `*.json` of clip metadata
- `puppet_palette.png`, `puppet_palette_rgb.png`, `puppet_palette.json`
- `fabric_a.png`, `fabric_b.png`, `fabric_preview.png`

### Blender and Python sources (`src/`)

- `plib.py`: geometry, UAL retarget, skinning, pose keying with IK, export
- `pface.py`: bead eyes, lid shells, projected replacement pieces
- `ppal.py`: palette and material classes
- `textures.py`: tiling fabric maps
- `build_hush.py`, `clips_hush.py`
- `build_bellows.py`, `clips_bellows.py`
- `build_stage.py`: valance, footlights, proscenium, honey jar, studio flats
- `set_classes.py`, `ppose.py`, `pcommon.py`, `compose.py`

### Godot (`proj/`)

`proj/` is a private copy of the shared diorama; the shared one is untouched. `proj/puppet/` contains:

- `puppet.gdshader`
- `puppet_set.gdshader`
- `puppet_char.gd`: drop-in material setup and driver. It gives 12 fps stepping, boil and the face-overlay layer.
- `puppet_shot.gd` / `PuppetShot.tscn`: the diorama plus puppets, props, stage, follow spot, clip chaining, sequences
  and `--perf3d`
- `puppet_studio.gd` / `PuppetStudio.tscn`: turnaround, heads and poses
- `stage.glb`, `honey_jar.glb`, the `*_flat.glb` studio props
- `set_class.png`, fabric textures, palette

`proj/tools/shot3d_fixed.sh` renders with a fixed 30 fps timestep.

### Scripts

- `build.sh`: textures and both characters
- `make_boards.sh [--build]`: every render and board
- `shot.sh`, `studio.sh`
- Intermediates are in `out/`:
  - `out/sneeze_seq/`: 168 frames
  - `out/perf/perf.txt`
  - `out/cmp_ab.png`: the outline A/B

## Licences

- **Skeleton and 24 library clips.** Quaternius *Universal Animation Library* 1 and 2 [Standard], **CC0 1.0**:
  https://quaternius.itch.io/universal-animation-library and
  https://quaternius.itch.io/universal-animation-library-2. Local copies and their `License.txt` are under
  `../assets/quaternius/`.
- **Base code.** `plib.py` and `ppose.py` are forked from the MND look-toy sources (original MND work).
- **Original work.** Everything else was made for MND in this look-dev: all meshes, the procedural textures, the
  palette, the shaders, the stage dressing, the props, the 11 custom body clips and the 23 `Face_*` clips. No other third-party asset is used.
- **The set.** The diorama pieces are the spike's original MND set, restyled only by shader.
- **Board fonts.** The labels use the game's Lilita One and Nunito (SIL OFL), from `game/ui/theme/fonts`.
