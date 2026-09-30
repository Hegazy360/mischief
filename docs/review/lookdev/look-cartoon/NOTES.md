# Look-dev "Saturday Cartoon" (key `look-cartoon`)

Semi-realistic stylised humans with exaggerated proportions, in the Scary Teacher 3D / Hello Neighbor cartoon
family. Both characters are built on a **CC0 Quaternius Universal Base Character** body and the **CC0 Quaternius
UAL (UE5-mannequin, 65-bone) skeleton**, so the 86 CC0 UAL1+UAL2 clips play on them. Then they are heavily
customised: new cartoon heads, 3D eyes with lids and brows on bones, swappable painted mouths and irises,
metaball-clay hair, gloves, hands, shoes and costume parts, a painted 1024² texture, and 11 custom comedy clips.
Everything is rendered in the **shared diorama**, in Godot 4.7.2, Compatibility renderer, at 1200x540.

## Files (all in this folder)

| File | What |
|---|---|
| `turnaround.png` | front, 3/4, side and back of both characters (idle frame 0, the in-game shader) |
| `expressions.png` | 6 heads each. Hush: neutral, sneaky grin, shock, furious, sneeze build, dazed. Bellows: neutral, pompous, shock, furious (temper tint), sneeze build, dazed |
| `poses.png` | Hush: tiptoe, rigging (pepper into the honey jar), peeking from the pantry, frozen statue. Bellows: sipping tea on the stool, the CHOO launch, dazed in the sink. All in the set |
| `ingame_kitchen.png`, `ingame_wide.png` | game-scale renders, 1200x540. The kitchen at h 4.0 m (the base framing): Bellows sips tea while Hush snickers at the Stalls by the pantry. The wide shot is the C3 two-shot pull-back at h 4.6 m: Hush tiptoes through the parlour |
| `sneeze_strip.png` | the ACHOO-RIA! sequence in 8 frames at game framing (the real clip plus its face timeline) |
| `sneeze_game_framing.gif`, `sneeze_punchin.gif` | the full 6.3 s sneeze. The second one has the 1.4x gag-cam punch-in the GDD asks for |
| `snicker.gif`, `walk_tiptoe_strut.gif` | Hush's comedy take; Hush's tiptoe and Bellows' strut crossing the kitchen |
| `numbers.txt` | all measurements |
| `CREDITS.md` | third-party sources and licences (all CC0) |
| `chars/hush.glb`, `chars/bellows.glb` | the characters: 1 skinned mesh, 1 material, 1 texture, 36-37 clips. Also `*_faces.json` (face timelines per clip), `*_meta.json` (landmarks), the albedo PNGs, `atlas_preview.png` |
| `src/` | the whole pipeline (Blender bpy + numpy + PIL, see "Reproduce") |
| `godot/` | a copy of the shared diorama project plus `cartoon/` (shader, outline, face rig, shot scene, props) and `tools/cshot.sh` |

## How the look works

- **Body.** The Hush body comes from the female base and the Bellows arms and legs from the male base. They keep the
  base's skin weights. The base heads, hands and feet are cut away, and Bellows' torso too. `reshape()` then sets the
  proportions: per-bone scales go down the chain like a pose and are applied with the mesh's own skin weights. Bone
  directions and rolls stay as they were, so UAL keys mean the same motion. After that come smoothing, chest
  flattening and cloth inflation. Heights are exact: Hush 1.60 m, Bellows 1.78 m.
- **Clay parts.** The heads, hair, beret, bouffant, mutton chops, gloves, hands, shoes, Bellows' barrel, cravat and
  coat tails are metaball "clay", converted and decimated. Hush's gloves have 4 digits (thumb + 3 fingers, the
  cartoon convention) and are built along the UAL finger bones, so the finger curls in the clips work.
- **Paint.** Cycles bakes the rest position, normal, region id and AO into maps. `paint.py` then paints the texture
  in numpy as functions of that position: Breton stripes, braces, blush, the teardrop, lash lines, glove stitching,
  hair strands, the plum jacket with a shirt V and lapels, pinstripes, spats and cravat dots. It all goes in one
  1024² atlas with gloss in alpha.
- **Faces.** The faces use 3D eyeballs (`eye_l/r` bones, look-at), 3D upper lids (`lid_l/r` bones, blink and squint)
  and 3D brows (`brow_l/r` bones, raise and tilt). On top of that, the **mouth and iris are 2D decals** swapped by
  frame index from 8+8 cells in the same texture (UV2, one material). `CartoonFace` in `godot/cartoon/` drives the
  named presets (the faces.json vocabulary), blinks and face timelines. It also does Bellows' **temper tint**,
  peach to beetroot `#B8324B`, on a skin mask.
- **Shading.** `cartoon_char.gdshader` is unshaded, with the lighting computed in the shader (REDESIGN §5.3): a
  soft wrapped key read from the set's own Key light, a cool lilac shade, a warm bounce, a soft gloss highlight and
  a cool rim. The rim is damped on dark cloth. The outline is an inverted hull, **4 px at a 1080-px-tall render**
  and scaled with the viewport. A 540-px shot therefore shows 2 px, which is the same weight the phone shows.
- **Clips.** The 31 UAL clips have their pelvis translation scaled to the new leg length (Bellows 0.48x). Bellows also
  gets a 40° arm-out layer so his arms clear the barrel. The custom clips come from `poses.py`: FK posing about
  armature axes, an analytic **2-bone arm IK** (targets ride on bones, for example "glove at the mouth"), and
  **automatic foot grounding**, with contact sheets rendered in Godot for each iteration.
  - Hush: `Hush_Idle_Loop`, `Tiptoe_Loop` (10 f per step), `Snicker` (the audience take), `Freeze_Statue`,
    `Rig_Pour_Loop`, `Peek_Loop`.
  - Bellows: `Pompous_Idle_Loop`, `Strut_Loop` (12 f per step, tiny fast legs, chin up), `Tea_Sip_Loop`, `Sneeze`
    (ah 20 f, ahh 24 f, AHHH 30 f, a 20 f false stop, then CHOO, a root-motion launch 1.15 m back into the sink, and
    dazed), `Dazed_Loop`.

## GDD §1.2 identity check

- **Hush.** Lanky: long thin limbs, a big head of 1/3.2 of her height with the beret. She has a tilted cherry-red
  beret with a stalk, Breton navy and white stripes, red braces with clips, huge white 4-digit gloves at 1.65x hand
  size (with cuffs and stitching), cream face paint `#FFF6EA`, big warm round brown eyes with two highlights, rosy
  cheeks, a smiling default mouth, the little navy teardrop, a dark bob and flat black shoes. Clarence the rubber
  chicken rides in her right brace. She reads as warm, not creepy.
- **Bellows.** A barrel torso about 0.9 m wide on ~0.5 m legs (hip joint at 0.50 m), a silver dandelion bouffant (with a `bouffant` bone,
  so it can flop over his face in the sink), mutton-chop sideburns, bushy silver brows, a bulbous rosy nose, heavy
  pompous lids, specs on a gold chain resting on his belly, a plum jacket with lapels and a shirt V, gold buttons, a
  gold cravat, coat tails, white cuffs and tiny shoes with spats. He reads as pompous, not scary.

## Numbers (details in `numbers.txt`)

| | Hush | Bellows | budget (REDESIGN §5.6) |
|---|---|---|---|
| triangles | 9,680 | 9,966 | ≤ 10k |
| skeleton / weighted joints | 71 / 52 | 72 / 53 | ≤ 50 deform + jiggle |
| meshes / materials / textures | 1 / 1 / 1 × 1024² | 1 / 1 / 1 × 1024² | 1 mesh + ≤ 4 attachments, 1 material |
| texture memory | 5.33 MB lossless, or 1.33 MB VRAM-compressed | same | — |
| draw calls | 2 (base + outline); 4 under the set's shadowed key | same | ≤ 4 |
| .glb | 3.63 MB (37 clips) | 3.88 MB (36 clips) | — |

In the scene, the kitchen with both characters has 53 draw calls against 45 for the empty set (shadows on), or 29
against 25 with shadows off. The characters add 10.7 MB of texture memory lossless, or 2.7 MB compressed.

Frame times here come from llvmpipe (a software rasterizer), so they are relative only: both characters cost
+19 ms on a 65 ms empty set. The character shader has no per-light passes. Build time is about 50 s per character
through the whole Blender pipeline. A Godot still takes about 10 s and all deliverables take 2 min 20 s.

## Scaling to ~40 animations per character

The mapping uses the P0 lists in GDD §10.

| | From the CC0 UAL1+UAL2 libraries (same skeleton, no retarget: pelvis scale plus a per-character layer) | Custom (pose toolkit: FK + IK + grounding, face timeline sidecar) |
|---|---|---|
| **Hush** (~14 + ~26) | run (Jog/Sprint + mime arm layer), crouch hide and sneak (Crouch_Idle/Fwd), climb in the window (ClimbUp_1m), dive (Roll / Slide_Start), pop out (Jump_Start/Land), rummage (Chest_Open, PickUp_Table), tinker B (Fixing_Kneeling), push, carry (Walk_Carry), throw (OverhandThrow), busted recoil (Hit_Knockback), get up (LayToIdle), celebrate (Dance) | tiptoe scurry ✓, snicker + glance ✓, 4 freeze poses (1 ✓), prop-specific rigs Q/S/B (pour ✓ + 2), peek ✓, squeak Clarence, idle ✓ + 3 mime fidgets (invisible wall, rope, cane), turn, door, stairs up/down, busted take, dangled in the Lecture (paired), doorstep + tomato, bow, hidden-eyes face states |
| **Bellows** (~12 + ~28) | walk (Walk_Formal + chin-up), irked walk (Walk + stomp layer), chase (Jog), armchair (Sitting_Enter/Idle/Exit), phone (Idle_TalkingPhone), lecture base (Idle_Talking), tut-tut (Idle_No), snack (Consume), grab / fire (Interact, PickUp_Table), small bumps (Hit_Head), dignity recovery (LayToIdle), **blind bumble (Zombie_Walk_Fwd, UAL2)** | strut ✓, pompous idle ✓ + fidgets, tea ✓, sneeze ✓, dazed ✓, the other 11 reactions (DRENCH, SING_CRACK, STRAIN_SLIP, AVALANCHE_HELMET, DIZZY_SPIN, LAUNCH_CEILING, BLIND_BUMBLE top layer, FISH_SLAP, JACKHAMMER_CLING, MIRROR, HOT & COLD), warmup singing, mirror admire, suspicious (arms cannot fold over the barrel), double take, slow burn, meltdown, lecture x3 (paired), steaming stomp, turn, door, stairs, wheeze |

- **Rule of thumb.** Locomotion and generic chores come from the library. Anything funny, prop-specific or
  timing-critical (beats within 2 f of `reactions.json`) is custom. That is about 65-70 % custom, because the
  comedy is the product.
- **Cost.** With this toolkit, a simple loop takes 20-30 min of iteration. A comedy take with props, a face timeline
  and staging takes 1-2 h. That comes to roughly 40-50 h per character for blocking-plus quality. A human animator
  working on the same skeleton in Blender (keys import as-is) should polish the top 10 takes: overshoot, smear,
  squash on the barrel.
- **Extra CC0 supply.** Quaternius' paid Source tiers of UAL1/UAL2 (also CC0) add more bases. Kenney's animated
  characters use a different 7-bone rig, so they don't fit. Mixamo is not CC0, so it is excluded.

## Risks

1. **The appeal ceiling of procedural modelling.** The metaball clay reads well at game scale. In close-ups the
   bouffant is lumpy ("cauliflower"), the clothes have no folds, and the hands are simple. A production pass by a
   character artist (sculpt, retopo, hand-painted texture on the same skeleton and UV2 face system) is what takes
   this from look-dev to ship.
2. **Semi-realistic body under a cartoon head.** Hush's limbs come from a realistic base. They are fine at 216 px
   tall, but the neck/collar seam and the realistic limb shapes show in punch-ins.
3. **2D decal mouths on 3D faces.** They read very clearly, but can look like stickers at the 1.6x signature
   punch-in. The alternative is blend-shape mouths (heavier, more authoring).
4. **Barrel plus short arms.** His hands cannot reach round his belly. Every arm-heavy library clip needs the arm-out
   layer or a custom version, and hand contact on the belly stays approximate. His interaction poses have to be
   staged to the side of the barrel.
5. **Joint budget.** 52-53 weighted joints against ≤ 50. Merging the finger `_03` bones into `_02` saves 8 joints.
6. **Texture compression.** S3TC/ETC2-class compression bleeds colour into the tiny brow and collar islands (measured
   and visible). The options are: ship lossless (5.3 MB per character), use ASTC 4x4, or give those parts more UV
   padding (already raised to 14 px) or move them to vertex colour.
7. **Two lighting models.** The characters use computed-in-shader light; the set uses the toon shader with scene
   lights. They match because the shared key direction is read from the set's Key light. A lighting change must
   update both. Converging on REDESIGN §5.3 (everything computed in-shader) removes this risk.
8. **Outline seams.** The inverted-hull outline draws lines where parts intersect (lids and eyeballs, arms entering
   the barrel). This is acceptable at game scale.
9. **Face and body kept separate.** Face timelines are a sidecar, not glTF keys (`*_faces.json`,
   `CartoonFace.play_timeline`). The view has to keep them in sync with the clip's beats and events.
10. **Pip fallback.** Pip needs a new head and costume on the same skeleton and face system. That is about a day
    with this pipeline.

## Self-rating of appeal (mobile audience): **7 / 10**

**For it:**

- The silhouettes are instantly distinct at phone size: a round silver puff on a plum barrel on tiny legs, next to a
  lanky red-beret stick with white glove blobs.
- The faces carry the jokes. Hush's big warm eyes and swappable mouths read from across the room, and Bellows'
  heavy lids and temper tint make him pompous, not scary.
- The look is in the family mobile players already like: Scary Teacher 3D, Hello Neighbor.
- The sneeze gag reads end to end in the real set, at game framing and in the punch-in.
- It fits every budget except joints (by 2-3).

**Against it:**

- The modelling is programmer-grade: lumpy hair, no cloth detail, simple hands.
- The animation is blocking-plus. It needs a human pass for snap, overshoot and squash on Bellows' belly, and
  secondary motion (jiggle bones on the bouffant, beret and coat tails are specced but not built).
- The semi-realistic middle ground can feel a little generic next to a bolder, fully graphic toon style.

With a professional sculpt and texture pass and an animator's polish on the top takes, I would expect 8.5.

## Reproduce

```bash
cd look-cartoon
work/run.sh hush && work/run.sh bellows          # Blender geometry -> bake -> paint -> clips -> chars (work/b/*.glb)
blender -b --python src/build_props.py -- $PWD/godot/cartoon/props
work/render_all.sh                               # every sheet, in-game shot, strip and GIF into work/final/
godot/tools/cshot.sh out.png 24 -- --cam=x=7.2,h=4.0 --char=$PWD/work/b/bellows.glb@stool@Tea_Sip_Loop@-55@@pompous
```

`godot/cartoon/cartoon_shot.gd` documents every argument: characters with face presets, `--tl` face timelines,
`--pin`/`--attach` props, timed `--at` set and camera events, and `--fcam` punch-ins. To use a character in another
scene, instance the .glb, add a `CartoonFace` child (`who = "hush"|"bellows"`) and call `set_face("shock")` or
`play_timeline(...)`. The shared diorama's own `DioramaShot` can load the .glb too, but its `toonify()` path does not
know the UV2 face decals: the face would show no mouth or iris. Use `CartoonFace`.
