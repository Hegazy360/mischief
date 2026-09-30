# r3d-cast-hush: report

Hush in 3D is built. She has look B's body (1.60 m, B's joints, B's head, neck and torso proportions) and look A's Toy
Box vinyl construction: superellipsoid blobs, capsule chains, a masked-shell bob, bisect-cut stripes and palette-UV
colour. She is warm and cheeky, never creepy: a smiling default, big warm-brown irises with two highlights, rosy
cheeks, the little navy teardrop, white 4-digit gloves and the cherry beret with its stalk. The default build ships
B's head (head_scale 1.0), which is the owner's pick. The R6 alternate `head_b` (×1.2) is built next to it and does not
replace it.

Hours: about 3.1 h active (16:32 to 19:37 UTC). P0 landed at 17:00, the reach proof and SKELETON FROZEN at 17:16,
the O1 boards at 17:48, the R6 head check at 17:53 and P2 at 19:30 (verified 19:35).

## Files built (all owned paths)
- **Sources** in `tools/art3d/hush/`:
  - `hush_dims.py` holds the numbers.
  - `skeleton.py` builds the UAL1 armature, re-proportioned by length to B's joints, plus the extras.
  - `skeleton.json` is the frozen contract.
  - `toy_lib.py` and `palette.py`.
  - `build.py` builds the mesh, weights, sockets, meta and the board poses.
  - `face_atlas.py`, `write_rig.py` and `glb_strip.py`.
  - `props.py` builds the tag beret, plinth, TOMATO splat and carry items.
  - `board_poses.py`, `reach_targets.py` and `face_preview.py`.
  - `build.sh` runs everything, including the `--head-scale 1.2 --variant head_b` variant.
- **Game** in `game/art3d/chars/hush/`:

  | File | Size |
  |---|---|
  | `hush.glb` | 468 KB |
  | `hush_head_b.glb` | 469 KB |
  | `palette_hush.png` | 256², 32 colours |
  | `face_hush.png` | 2048×1024, 294 KB |
  | `tag_beret.glb` | 864 tris, bone `string` |
  | `plinth.glb` | Ø0.5 m × 0.12 m, 224 tris |
  | `tomato_splat.glb` | — |
  | `carry_squeaker.glb`, `carry_magnifier.glb`, `carry_kipper.glb` | ×1.5 |

  The textures are stripped from every glb; the PNGs ship beside them.
- **Data** in `game/data/rigs3d/hush/`: `rig3d.json`, `rig3d_head_b.json`, `faces.json` (26 presets under their 2D names)
  and `skeleton.json` (a mirror).
- **Tests**: `game/tests/cast3d/test_hush3d.gd` has 16 tests.
- **Review**: `docs/review/r3d-cast-hush/` holds `index.md`, 12 boards, `head_check.json`, `reviewer_prompt.md` and four
  reviewer packets.

## Numbers
- **Mesh**: 9,830 tris in one surface (≤ 10k). There are 79 bones: UAL 65 plus 14 extras. 48 carry weight (≤ 50):
  40 body bones and 8 jiggle bones.
- **Height**: 1.600 m to the beret top with the stalk excluded (the stalk tip is at 1.606); feet at y 0. `head_b` is
  9,848 tris and 1.674 m tall.
- **Skeleton**: UAL rest directions are within 0.5°. The arms match B's within 5 mm: upper arm 0.1986 m, forearm
  0.2060 m, shoulder height 1.127 m. `skeleton.json` sha256 is ae9961b6b346…, frozen at 17:16.
- **RigPerf3D** (desktop proxy, 3 runs, load average 6–7):
  - rest pose: 60–62 µs median, 2 draw calls, 19,660 primitives including the outline.
  - `hush/loco_walk` with jiggle: 178–214 µs median (p95 266–288), 2 draw calls.
  - r3d-rig measured 186–192 µs on the same walk. The budget is ≤ 250 µs.
- **Reach at B's arm lengths** (shoulder to the placed target; bar ≤ 0.50 m), re-measured after r3d-sets restaged the
  honey jar:

  | Band | Distance |
  |---|---|
  | Stool, to the jar mouth (14.55, 2.023, −1.72) | 0.433 m |
  | Gramophone lever | 0.375 m |
  | Mime step to 2.0 m | 0.415 m |
  | Kneel to 0.40 m | 0.330 m |

  All four pass.
- **Value rule** (`lab.py value`):

  | Condition | L* ≥ 85 | L* ≤ 40 | Result |
  |---|---|---|---|
  | Flat-lit 1200×540, the brief's measurement | 25.8 % | 55.1 % | PASS |
  | Flat-lit with the 4.8 px outline | 20.6 % | 63.1 % | PASS |
  | Game runtime, toon-shaded in the lit kitchen (informational) | 19.5 % | 67.5 % | at the bar |

  The cream stripes were widened at P2 to meet it.
- **Silhouettes at 64 px**: no pair reaches IoU 0.80. The closest are idle / reach-mid 0.68, idle / snicker 0.66 and
  reach-mid / squeak 0.63.
- **Tests**: cast3d 29/29 (hush 16, 0 skip). Full suite (`tools/scripts/test_game.sh r3d-cast-hush`): 1423 passed, 0 failed, 1 skipped. Lint (`SANDBOX=r3d-cast-hush tools/scripts/lint.sh`) exits 1 on one error, and it is not mine: `L10_pop_jump` in r3d-anim-bellows' `bellows3d/bit_warmup.json` f27. Nothing in Hush's files is flagged.

## R6 head verdict and the owner question
- **Step 1**: the maximal face card inside B's head fails. The head is 54.5 px (< 60) in every view. The face card is
  24.6 px at cheat 35 and 33.7 px with the face turned to the camera (< 40).
- **Step 2**: ×1.2 is the smallest scale that passes every measured bar with the face given to the camera (cheat 35 plus
  a 25° head turn):

  | Measure | ×1.2 | Bar |
  |---|---|---|
  | Head | 65.4 px | ≥ 60 |
  | Card | 40.5 px | ≥ 40 |
  | Eye white | 12.7 px | ≥ 9 |
  | Pupil | 8.2 px | ≥ 4 |
  | Mouth | 19.5 px | ≥ 16 |
  | Brow | 4.2 px | ≥ 3 |

  At the bare 35° cheat the face is 55° off frontal, and no scale up to 1.3 meets the horizontal bars.
- **What shipped**: the proposal is variant `head_b`: `rig3d_head_b.json` plus `hush_head_b.glb`, with the same 79 bone
  names and the head scaled about the Head joint. The default stays 1.0.
- **Reviewer read test (R17)**: the four packets are built and still need a fresh reviewer (see REQUESTS).
- **Owner question (O3)**: "Keep B's head (at 1200×540 the face card is 34 px with her face turned to the camera, under
  the 40 px bar), or grow it ×1.2 (41 px, passes every bar)?" The lead recommends ×1.2. The build keeps 1.0 until he
  answers.

## APIs and contract as built (`rig3d.json`, validated by RigDef3D)
- **Scene paths**: `scene` is `res://art3d/chars/hush/hush.glb` (or `hush_head_b.glb`), `skeleton` is
  `Armature/Skeleton3D`, and `mesh` is `Armature/Skeleton3D/hush_body`.
- **Sockets** (bone-local position):

  | Socket | Bone | Position |
  |---|---|---|
  | `grip_r` | `hand_r` | (−0.03, 0.09, 0.004) |
  | `grip_l` | `hand_l` | (0.03, 0.09, 0.004) |
  | `head_top` | `Head` | (0, 0.373, 0.026) |
  | `brace_r` | `spine_02` | (−0.072, −0.003, 0.099) |
  | `carry_1` | `spine_02` | (0.078, 0.046, 0.131) |
  | `carry_2` | `spine_02` | (0.08, −0.073, 0.119) |
  | `feet` | `root` | 0 |
  | `face` | `Head` | (0, 0.13, 0.181) |

- **Props**:
  - `clarence` on bone `prop_clarence`. States: brace → `brace_r`, held → `grip_r`, squeeze → `grip_r`. Squash bone
    `clarence_body`. Default brace.
  - `pepper_pot` on bone `prop_r`. States: held → `grip_r`, hidden. FX bone `fx_pepper`. Default hidden.
- **Attachments**: `tomato_splat` (bone Head), `carry_squeaker` and `carry_magnifier` (socket `carry_1`), `carry_kipper`
  (socket `carry_2`). The matching looks are TOMATO, CARRY_SQUEAKER, CARRY_MAGNIFIER and CARRY_KIPPER.
- **Jiggle**, tuned on r3d-anim's `loco_walk`:

  | Bones | Stiffness | Drag | Gravity | Radius | Clamp |
  |---|---|---|---|---|---|
  | `beret`, `beret_stalk` | 2.6 | 0.40 | 0.25 | 0.05 | 26° |
  | `hair_l`, `hair_r` | 3.6 | 0.50 | 0.35 | 0.03 | 16° |
  | `brace_l`, `brace_r` | 7.0 | 0.65 | 0.10 | 0.02 | 8° |
  | `clarence_body` | 2.6 | 0.30 | 0.45 | 0.04 | 32° |
  | `clarence_comb` | 5.0 | 0.30 | 0.15 | 0.015 | 24° |

- **Face**:
  - Grid [6, 8] on `atlas_size` [2048, 1024]. Cell uv = ((col + lu) / 6, (row + 1 − lv) / 8).
  - Layers draw in the order `extra_a`, `brows`, `eyes`, `pupils`, `mouth`, `extra_b`, each with its own `layer_rects`.
  - Cells:

    | Layer | Cells |
    |---|---|
    | eyes | open, wide, half, squint, worried, closed, happy, wink, wink_m, spiral |
    | pupils | centre, small |
    | brows | neutral, up, determined, worried, sly, sly_m |
    | mouth | smile, grin, laugh, O, grimace, puffed, shh, tongue, wavy |
    | extra_a | cheeks, cheeks_m, blush, blush_m |
    | extra_b | sweat, sweat_m, tear |
    | card | eyes_dark_open, eyes_dark_blink, pupils_dark (the hiding-spot eye card) |

  - `mirror_cells`: sly → sly_m, wink → wink_m, cheeks → cheeks_m, blush → blush_m, sweat → sweat_m.
    `mirror_pupil_x` is true.
  - Blink: every 2–6 s, 6 frames. The cell is closed and the half cell is half. Blinkable: open, wide, half, worried.
  - `no_pupils` lists the baked-pupil eyes.
  - `pupil_range` is [0.022, 0.035]; presets carry `gaze` [x, y].
- **Material**: palette, `outline_px` 4.8 (D7), `rim` 0.45.
- **Vertex colour**: R is the skin tint (unused, 0), G is stone keep (eyes, beret, braces, clip), B is rim damp (navy,
  trousers, hair, shoes), A is the outline scale.
- **Stone**: `#E8E6E1`, keep [eyes, beret, braces], plinth and tag paths.
- **Cheat**: idle 35, walk 20, perform 35, face_to_face 5. `blob_shadow_r` is 0.34.

## Deviations
- **Face atlas**: 2048×1024 in 6×8 cells of 341×128 px instead of the brief's 1024² 8×8. This follows the lead note and
  issues D7 (keep look A's horizontal cell resolution, ≥ 256 px). `face.atlas_size` is an added field; `atlas_px`
  stays as the width.
- **Outline**: 4.8 px @1080, not 3.5 (D7).
- **Stripes**: the cream stripes are wider than the navy ones (0.048 vs 0.026 m) to meet the value rule under the
  thicker outline.
- **Face presets**:
  - dazed uses the `spiral` eyes (an override of the 2D map).
  - wide eyes use the `small` pupil cell.
  - The extra cells (mirrors, the card) are additive.
- **Textures**: stripped from the glbs (the PNGs ship beside them) so that Godot does not extract embedded images.
- **head_b**: stands 1.674 m because the head grows about the Head joint. The bone rests are unchanged apart from the
  Head descendants.
- **P2 boards**: they render on the game runtime (AnimViewer3D in r3d-sets' n01 set), except the silhouette masks,
  the flat-lit value measurement and the head-check crops and packets, which render in the scratch look-A studio with
  the same char_toon shader.
- **`hybrid_vs_ab.png`**: still the P1 render (before the stripe change).

## Requests
- **Orchestrator (R17)**: run the four fresh-reviewer packets in
  `docs/review/r3d-cast-hush/packets/faces_{b_c35,b_face,hb_c35,hb_face}/`, one fresh reviewer each, giving them only
  that folder's `prompt.md`. Paste each verbatim answer into `docs/review/r3d-cast-hush/reviewer_answers_<packet>.md`,
  then score with `tools/art3d/review/packets.py score` using the keys in `<SP>/work/r3d-cast-hush/review_key_*.json`
  (commands in `reviewer_prompt.md`). The packets were rebuilt on the v1 atlas.
- **r3d-view3d (CharacterView3D)**:
  - The plinth is 0.12 m tall with its origin at the floor, but the rig is not lifted while she is frozen, so her shoes
    sink into it. Lift the rig by 0.12 × the pop scale.
  - While a rig clip plays, set Hush's facing from the sidecar's `stage`. Add carry looks for Nights 1–2 (CARRY_*).
- **r3d-rig / r3d-anim (R6, R5d)**: Hush's idle, perform and rig clips should turn the head about 25° toward the camera
  on top of the 35° body cheat. `faces_game.png` shows that the 1× read depends on it.
- **r3d-anim (rig_achoo_ria)**: re-bake on the restaged jar. The pot now reaches the mouth (0.433 m), but at cheat ≤ 10
  facing −x her head still partly covers the pot hand from the game camera (`poses.png`).
- **r3d-sets (HideSpot3D)**: the eye-card cells exist (`face.card_cells`, 6×8 grid); HideSpot3D still draws its
  fallback discs. My P1 jar requests (mouth ≤ 2.04 m, `reach_target` at the mouth) are met by the 18:21 restage.
- **r3d-view3d / r3d-integrate (R13 import)**:
  - `face_hush.png` should import lossless, or at least without VRAM-compression bleed across the 341×128 cells, with
    mipmaps on (it is minified about 10× at base framing). Sizes: RGBA8 8 MB, 11 MB with mips; ETC2/ASTC about 2.8 MB
    with mips.
  - `palette_hush.png` should import lossless, nearest, no mipmaps.
- **r3d-night**: label the stage-door head switch "Gate 0 · Hush, head ×1.2" (variant `head_b`).
- **r3d-hud**: a Settings or dev toggle `hush_head` (1.0 / head_b) until the owner answers.
- **GDD amendment**, if the owner picks ×1.2: "Hush's head is 1.2× look B's (1.674 m standing), so her painted face
  reads at phone scale."
- **CREDITS**: the skeleton is the Quaternius Universal Animation Library 1 (CC0), already vendored. No new third-party
  assets.

## Gaps
- The fresh-reviewer read test has not run yet (this task has no agent-spawn tool). The head verdict rests on the
  measured bars.
- The toon-shaded light share in the lit kitchen sits at the bar (19.5 %); the flat-lit rule passes.
- HideSpot3D does not sample the card cells yet, so the peek board is a flat composite of the cells.
- `hybrid_vs_ab.png` was not re-rendered at P2.

## Addendum: lint fix pass (index §3.3.1, 2026-09-30 20:17–21:06 UTC)

The pass fixed all 3 of my rows in `docs/review/r3d-tools-b/status.md` (20:10Z). Each was set/colour "character share L* ≥ 85" for Hush, bar 0.20. Every lit slice room now clears the 0.23 target with both head variants. The key light and `stage_light` were not changed, so there is no REQUESTS line.

### Cause
The face albedo was already near white: paint `#FFF6EA` is L* 97. The lint stands Hush facing +x, which is away from the upper-left key, at cheat 35°. So char_toon's vinyl terminator ran across her face:
- Only 40 % of the face-card vertices were fully lit at cheat 35, and 24 % at the walk cheat of 20°.
- The rest sat in the lilac shadow band. The 66 % floor holds that band at about L* 83, just under 85. That is the "L* 60–80" face tools-b measured.

Brighter albedo could not fix this. Even pure white floors to exactly L* 85.0.

### Fix (my files only)
I bent the shading normals of the face paint, which covers the head blob, the neck by its Head weight, and the button nose:
- Each normal loses half of its sideways (X) part.
- Each normal gets +1.2 × the head's up axis, then is renormalised.

The constants are `FACE_LIFT_UP` 1.2, `FACE_LIFT_FLAT_X` 0.5 and `FACE_LIFT_FWD` 0 in `tools/art3d/hush/hush_dims.py`. The code is `build.py face_lift()`, which writes Blender custom split normals that export as the glb's NORMAL.

The stage key comes mostly from above (y 0.62 of the vinyl key), so her face now stays in the lit band from either facing. The face card is fully lit, facing away from the key:

| Cheat | Before | After |
|---|---|---|
| Idle, 35° | 40 % | 99.6 % |
| Walk, 20° | 24 % | 95 % |
| Face to face, 5° | 15 % | 87 % |

Facing into the key it is 100 % at every cheat.

What did not change:
- Positions, UVs, weights, bones, tris and the build meta are identical. `rig3d.json`, `rig3d_head_b.json`, `faces.json`, the atlas and the palette are byte-identical.
- The skeleton contract is untouched.
- The body's terminator, the stripes, the gloves, the rim and the outline are untouched.
- The head A/B switch is untouched. Both glbs were rebuilt through `build.sh --no-props`.

I tried a softer lift first (+0.9 up, no flattening). It passed the lint too, with 0.244–0.265, but covered only 71 % of the face at walk cheat facing away. So I shipped the stronger version.

### Numbers: Hush share L* ≥ 85 per room
Source: `lint3d.sh --set --all-nights`, LintShot3D staging.

| Room | B's head before | B's head after | ×1.2 before | ×1.2 after |
|---|---|---|---|---|
| g0 kitchen | 0.230 | 0.261 | 0.222 | 0.263 |
| P00 kitchen | 0.229 | 0.262 | 0.225 | 0.263 |
| P00 parlour | 0.224 | 0.257 | 0.221 | 0.265 |
| N01 hall | 0.225 | 0.259 | 0.222 | 0.266 |
| **N01 kitchen** | **0.197** | 0.270 | 0.191 | 0.275 |
| N01 parlour | 0.227 | 0.265 | 0.228 | 0.273 |
| N02 hall | 0.226 | 0.260 | 0.223 | 0.265 |
| **N02 kitchen** | 0.217 (status.md: **0.195**) | 0.247 | 0.220 | 0.249 |
| **N02 parlour** | **0.194** | 0.246 | 0.186 | 0.263 |

- **B's head, before**: my 20:20Z run of the same lint. N02 kitchen varied run to run with the idle frame, because the terminator moved across her face.
- **B's head, after**: the named re-run on the shipped tree, `SANDBOX=r3d-cast-hush-fix tools/scripts/lint3d.sh --set --all-nights --json=<SP>/work/r3d-cast-hush/fix_set.json`. It has no Hush rows. The only error left is r3d-sets' N02 hall negative space (0.68 m).
- **×1.2 columns**: the same lint on a scratch mirror of the tree with `rig3d.json` pointed at `head_b`, since the lint only loads the default rig. The "after" glb is byte-identical to the shipped `hush_head_b.glb`.

The dark share (L* ≤ 40) stays 0.54–0.63 for B's head and 0.49–0.60 for ×1.2, against a bar of 0.20.

### Checks
- **Tests**: cast3d passes 30/30 (hush 17, 0 skipped). The new test is `test_face_paint_stays_in_the_lit_band_both_facings`. For both glbs it checks two things:
  - the face-card normals lean up (mean y above 0.6);
  - under StageLighting3D's key plus key_front 0.35, at least 95 % of the face card is fully lit at the idle cheat and at least 90 % at the walk cheat, in both facings. The P2 glb fails this with 40 % and 24 %.
- **Lint**: `SANDBOX=r3d-cast-hush-fix tools/scripts/lint.sh` exits 0.
- **Boards, looked at**:
  - `ingame_kitchen.png` is a re-shoot. Facing away from the key, her face now reads as white mime paint. The snicker face card, blush and ink lines are intact. She still has B's dimensions and A's vinyl.
  - `faces_fix.png` is the head-check crop: neutral, shock and snicker at 1×, for B's head and ×1.2. It shows cheat 35 away from the key, cheat 35 into the key, and head to camera. All six conditions read.
  - `face_lift.png` has the per-room table above, the N02 parlour value map before and after, and 5× head crops for both variants.
  - The index marks `faces_game.png`, `turnaround.png` and `value_check.png` as P2, from before the lift.

### Handed on
- **r3d-integrate**: nothing new. The glbs keep their `.import` files.
- **r3d-tools-b**: regenerate `status.md`. The three Hush rows should be gone.
