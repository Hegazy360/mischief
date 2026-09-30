# MND shared 3D diorama (look-dev set)

A standalone Godot 4.7.2 project holding the simplified 3D "dollhouse cutaway" set for Mischief Next Door:
parlour and kitchen on one floor, back wall and floor, the front wall missing, section cuts dark. It is
lit like a stage from the audience side and shot by a fixed, slightly perspective side-on camera that follows
a character. Every look-dev places their characters in **this same set** and shoots them the same way, so
the three styles can be compared side by side.

Renderer and window contract are the game's: **Compatibility (GLES3)**, landscape 1920x1080 base,
1200x540 (20:9) window, `canvas_items` + `expand`.

```
diorama/                 res://diorama/  (drop this folder into the game project as-is: all paths are res://diorama/...)
  diorama.tscn           the set: Set/ (14 glb pieces), Marks/ (Marker3D), Actors/, Lights/, WorldEnvironment, CameraRig
  diorama.gd             toon look, marks, add_character(), toonify(), play(), highlight()
  camera_rig.gd          side-on follow camera (keep-height, clamps to the set, presets)
  DioramaShot.tscn/.gd   command-line shot scene (characters, walks, cameras, look toggles, sequences, perf)
  shaders/toon.gdshader  stepped diffuse + stepped shadow + rim, palette alpha = emissive
  shaders/outline.gdshader  inverted hull, ~constant pixel width
  props/*.glb            the set pieces (one mesh, one surface, palette UVs each)
  palette.png            8x8 palette, 16 px cells (alpha 0 = unshaded/emissive: fire, sky)
  layout.json            piece transforms + marks (Godot coordinates), house dimensions
chars/hush_test.glb      spike test character: toon mime proxy on the UAL skeleton, 34 clips
chars/bellows_test.glb   spike test character: Bellows proxy (legs 0.68x, barrel torso), same 34 clips
src/                     Blender (bpy) + Python sources for the set, the palette and the test characters
tools/shot.sh            shoot this project (xvfb + opengl3)          tools/rebuild.sh  rebuild the set from src/
```

## Shoot it

```bash
cd /tmp/.../mnd/work/3d/diorama                     # this folder
tools/shot.sh /abs/out/wide.png 40 -- --cam=wide       # the empty set (first run imports, ~20 s)
tools/shot.sh /abs/out/k.png 60 -- --char=res://chars/hush_test.glb@stool@Idle_Loop@20@1.75 --cam=kitchen
NO_IMPORT=1 tools/shot.sh ...                           # skip the import pass when nothing changed
SHOT_SIZE=960x540 tools/shot.sh ...                     # 16:9 check (camera keeps HEIGHT, width expands)
```

`tools/shot.sh <out.png> [frames] -- <args>` wraps `tools/shot3d.sh <project> <scene> <out> <frames>`.
It runs `godot --headless --import`, then `xvfb-run godot --rendering-driver opengl3 --resolution 1200x540`.
Always **Read the PNG you made**.

### DioramaShot arguments

| arg | meaning |
|---|---|
| `--char=<src>@<mark>[@<anim>[@<yaw>[@<height_m>]]]` | repeatable. `src` = `res://…` scene/glb, or an **absolute .glb/.gltf path** loaded at runtime with GLTFDocument (no import needed). `yaw` in degrees, 0 = facing the camera, 90 = facing +X (right). `height_m` rescales the model to that standing height |
| `--walk=<i>@<to_mark>@<m_per_s>[@<anim>]` | character *i* walks from its mark to another mark (camera follows character 0 unless `--follow`) |
| `--cheat=<deg>` | walkers turn toward the audience by this much (stage "cheat out"; 25–35 reads best) |
| `--cam=wide\|parlour\|kitchen\|follow\|x=<x>,h=<m>` | framing. `follow` (default with characters) = h 3.9 m; `--h=<m>` changes it |
| `--follow=<i>` | follow character *i* |
| `--seek=<s>` | start all clips at time *s* (posed stills) |
| `--toon=0` | imported StandardMaterial3D instead of the toon shader (set **and** characters) |
| `--outline-set=0`, `--outline-chars=0`, `--rim=<f>` | outline on props (default on, 1.5 px), on characters (default on, 3.5 px), character rim (0.55) |
| `--key=<e> --fill=<e> --amb=<e>` | override key / fill / ambient energy (defaults 0.32 / 0.1 / 0.36, see Gotchas) |
| `--shadows=0`, `--shadow-size=<px>`, `--msaa=0\|2\|4` | key shadows off, directional shadow atlas size, 3D MSAA (default 4) |
| `--hide=a,b` | hide set pieces (names below) |
| `--highlight=kettle,stool [--flash=0.35]` | hotspot affordance: warm flash plus warm outline on those pieces |
| `--marks=1` | draw every mark (pink disc, arrow = facing, name label) |
| `--shot-seq=/abs/dir --every=N --count=K [--seq-from=F]` | frame sequence `frame_000.png…` (use `frames` ≥ F + N·K) |
| `--lib=<res:// or abs .glb>` | share that scene's AnimationLibrary with every character at runtime (same skeleton + armature named `Armature`); clips are then `<file>/<clip>`, e.g. `--char=res://chars/me.glb@kettle@UAL2_Standard/Farm_Watering --lib=/abs/UAL2_Standard.glb` |
| `--perf3d` | prints `[perf3d] frames … draw calls … primitives … objects … texture/buffer/video MB` |

Frame sequence to GIF: `python3 -c "from PIL import Image;import glob;f=[Image.open(p).convert('RGB').resize((600,270)) for p in sorted(glob.glob('/abs/dir/frame_*.png'))];f[0].save('/abs/out.gif',save_all=True,append_images=f[1:],duration=100,loop=0)"`

## Put your character in the set

1. Export a **.glb** (glTF 2.0 binary) from Blender: metres, the character **faces -Y in Blender** (the
   glTF/Godot +Z default, i.e. toward the camera), origin between the feet on the floor, standing height
   about 1.6–1.8 m (or pass `height_m`). Apply transforms. One skinned mesh is best.
2. Either pass its absolute path directly (`--char=/abs/path/me.glb@stool@Idle_Loop`), or copy it into
   `chars/` and use `res://chars/me.glb`. On import Godot **strips a `_Loop` suffix and loops the clip**:
   `Walk_Loop` becomes `Walk`. `Diorama.play()` accepts either name.
3. Materials: any StandardMaterial3D albedo colour/texture is converted by `toonify()` to the toon shader,
   plus an outline pass. Palette-UV characters (like `src/build_char.py`, sampling `palette.png`) get the
   emissive-alpha trick as well. Smooth-shade characters: the outline follows `NORMAL`, so hard edges crack it.
4. Budget per character: ≤ 15k triangles, 1–3 materials, ≤ 1 × 1024² texture. Each skinned character
   costs 4 passes (base + outline + shadow caster + shadowed-light pass).
5. **Skeleton**: to reuse the CC0 Quaternius UAL clips with no retargeting, build on the UAL / UE5-mannequin
   65-bone skeleton (bone names `root pelvis spine_01..03 neck_01 Head clavicle_l upperarm_l lowerarm_l
   hand_l … thigh_l calf_l foot_l ball_l …`, T-pose, facing -Y). You may change **bone lengths** (legs,
   arms, neck) but keep bone directions and rolls, and scale the pelvis location keys by the leg ratio.
   `src/build_char.py --leg 0.68` does this. See `bellows_test.glb`. Name the armature **object**
   `Armature` (as UAL does): shared clip tracks are `Armature/Skeleton3D:<bone>`, so another name
   leaves a shared library unbound (T-pose). Blender's glTF import→export round trip keeps UAL's bone
   rest orientations exactly (checked: 0.0° over 65 bones), so the raw UAL/UAL2 .glb libraries work at
   runtime. On a short-legged rig, **bake** crouch/sit clips (scaled pelvis keys) instead of using the raw library.

### Marks (Godot coordinates, metres; yaw 0 = facing the camera, 90 = facing +X)

| mark | position (x, y, z) | yaw | use |
|---|---|---|---|
| `hush_start` | (0.70, 0.00, -1.05) | 90 | Hush entering the parlour, walking right |
| `bellows_start` | (1.50, 0.00, -1.35) | 0 | Bellows standing in the parlour |
| `armchair_sit` | (1.45, 0.00, -1.88) | -18 | sit here with `Sitting_Idle_Loop` (seat 0.53 m) |
| `armchair_front` | (1.70, 0.00, -1.05) | 0 | in front of the armchair |
| `fireplace` | (3.45, 0.00, -1.15) | 180 | facing the fireplace (back to camera) |
| `gramophone` | (4.75, 0.00, -1.20) | 150 | at the gramophone |
| `doorway` | (6.15, 0.00, -1.05) | 90 | inside the parlour↔kitchen doorway |
| `kettle` | (7.20, 0.00, -1.30) | 180 | at the counter / kettle (use `Interact`) |
| `stool` | (8.15, 0.00, -1.35) | 0 | beside the stool |
| `stool_top` | (8.15, 0.66, -1.35) | 0 | standing ON the stool |
| `sink` | (9.30, 0.00, -1.40) | 180 | at the sink |
| `pantry` | (10.55, 0.00, -2.90) | 0 | hidden inside the pantry alcove, behind the curtain |
| `pantry_front` | (10.55, 0.00, -1.05) | 0 | in front of the pantry |

The walking lane is z = -1.05. Set pieces (for `--hide` / `--highlight`): `shell_frame room_parlour room_kitchen
par_window fireplace armchair gramophone rug kit_window counter kettle sink stool pantry`. See
`../spike/05_diorama_marks.png` for the marks drawn in the set.

### Camera

`CameraRig` never yaws. It slides along X, clamped so the frame never leaves the set, and frames
`view_height` metres at the lane (fov 28°, pitch 4° down, keep-height, so 16:9, 20:9 and 4:3 all show the
same height). Presets: `wide` fits 12 m of house, `parlour` / `kitchen` fit a room, and `follow` is h = 3.9 m
(a 1.75 m character is ~45 % of the screen height). The dark ceiling band and floor slab are the calm areas
where the HUD should live.

## Rebuild or modify the set

- `tools/rebuild.sh` (needs `blender` 4.5 LTS on PATH): `src/palette.json` → `palette.png`,
  `src/build_diorama.py` → `diorama/props/*.glb` + `layout.json`, then `src/gen_tscn.py` → `diorama.tscn`.
- Colours: edit `src/palette.json` (name, hex, optional `1` = emissive) and rebuild, or edit
  `diorama/palette.png` directly (the toon shader samples it; UVs sit at cell centres).
- Props: each `build_*()` in `build_diorama.py` is ~10–25 lines of bevelled boxes, cylinders, lathes and
  curtains (`src/mnd3d.py`). Placement: `place(name, x, y, z, rot)` in Blender axes (+Y into the screen).
  Marks: the `marks` dict at the bottom.
- The test characters: `blender -b --python src/build_char.py -- --ual1 <UAL1_Standard.glb> --ual2 <UAL2_Standard.glb>
  --out chars/x.glb [--variant bellows --leg 0.68 --girth 1.55] [--preview <dir>]` (the preview needs xvfb-run).

## Gotchas (Godot 4.7.2 Compatibility)

- **Shadowed DirectionalLight3D is a second pass added in sRGB space.** With ambient > 0 the lit side
  comes out much brighter than the energies suggest (measured: 0.25 ambient + 0.5 key = 1.58x albedo,
  not 0.75x). It affects StandardMaterial3D too. Tune energies by eye: the defaults (0.32 / 0.1 / 0.36)
  are already tuned. Phones run the same GLES3 path.
- **Outline shaders must not write POSITION** (depth breaks and the hull covers the object), and
  `PROJECTION_MATRIX[1][1]` is **negative** in the vertex stage. Use `abs()`. `outline.gdshader` does both.
- `.tscn` `Transform3D(...)` lists the basis **rows**, then the origin (writing columns silently transposes
  every rotation).
- Coplanar faces z-fight in the shots (the floor sits in a 2 cm slab recess for that reason).
- The glTF importer extracts each embedded image to `props/<name>_palette.png` on import. They are
  harmless (the toon shader uses `diorama/palette.png`) and are regenerated on import.
- MSAA 4x adds ~20 MB of texture memory at 1200x540 (~80 MB at a phone's native 2400x1080). Prefer MSAA 2x
  on device, or a 3D render scale below 1.

## Licences

The set, the palette, the shaders, the scripts and the two test characters' meshes were made for MND in
this spike (original, procedural). The animation clips inside `chars/*.glb` come from Quaternius
*Universal Animation Library* 1 and 2 (Standard), **CC0 1.0**, https://quaternius.com. The custom clips
`Tiptoe_Sneak_Loop`, `Freeze_Statue` and `Snicker` are original (keyframed in bpy).
