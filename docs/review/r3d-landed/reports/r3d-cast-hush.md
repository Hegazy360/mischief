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
