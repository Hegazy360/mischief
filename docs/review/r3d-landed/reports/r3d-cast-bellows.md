# r3d-cast-bellows: report

Horace Bellows in 3D, look A (Toy Box) with the board's fixes. The glb, descriptor, face atlas, presets, portraits, tests and boards have all landed. The skeleton was frozen at 17:58Z. The one open item is the fresh-reviewer read test, which is **pending review** (R17 fallback).

## Files built (all under owned paths)

**Pipeline: `tools/art3d/bellows/`**
- `skeleton.py` + `skeleton.json`: the contract armature.
  - Frozen: sha256 `3fad5abf2daf35c3b405fc55367fda5d1a3ab3e6c8459c03bf158cac35d6bfad`.
  - 90 bones: UAL 65, rest directions and rolls kept, plus 25 extras.
  - `--ual-ref` writes `ual_ref.json`.
- `blib.py` + `bpalette.py`: look-A toy library and palette.
  - Vertex-colour masks: R skin tint, G stone keep, B rim damp, A outline scale.
  - Palette: 256² PNG of 8×8 cells.
- `parts.py`: all geometry.
  - Head with jowls and the face card on UV2, rosy nose, chops, a three-lobe scalloped bouffant.
  - Barrel with shirt, plum coat, lapels, tails and gold spotted cravat.
  - White gloves, striped trousers, spats.
  - Props and FX.
  - The 4 bouffant variant attachments.
- `face_atlas.py`: `face_bellows.png` (1024², 47 cells of 128 px) and `face_bellows.json`.
- `descriptor.py`: writes `rig3d.json` and `faces.json` (45 presets under their 2D names).
- `portraits.json`: face, tint, props and slots for each of the 15 portraits.
- `poses.py`: proof poses and reach solving (analytic 2-bone IK plus grip offsets, `arm_out` on).
- `build.py`: one command builds everything:
  `tools/art3d/blender.sh --python tools/art3d/bellows/build.py -- --out game/art3d/chars/bellows [--meta <json>] [--poses <scratch.glb>] [--rig-out <dir>]`

**Game assets: `game/art3d/chars/bellows/`**
- `bellows.glb`: 9,155 tris, 1 skinned mesh, 1 material, rest = UAL T-pose, no clips.
- `palette_bellows.png`, `face_bellows.png`, `face_bellows.json`.
- `bouffant_{flipped 772, frazzled 816, wet 792, floured 650}.glb`, all on bone `Head`.
- `portraits/bellows_{neutral,pompous,irked,suspicious,furious,livid,dazed,sing,hum,smug,laugh,tut,sniff,yum,yawn}.png` (256² RGBA).

**Rig data: `game/data/rigs3d/bellows/`**
- `rig3d.json`, `faces.json`, `ual_ref.json`.

**Tests**
- `game/tests/cast3d/test_bellows3d.gd`: 13 tests.
  - Descriptor loads through RigDef3D.
  - One skinned surface with COLOR and UV2.
  - Bones = UAL 65 + extras; deform ≤ 50 excluding jiggle.
  - tris ≤ 10k, equal to the descriptor, and **body + largest slot variant ≤ 10k**.
  - Height 1.77–1.79 m.
  - UAL rest directions and rolls within 0.5°.
  - `arm_out` layer.
  - 45 presets, their cells and mirror pairs.
  - Tint tiers.
  - Props, attachments and FX resolve.
  - Slots and looks.
  - Sockets.
  - Portraits exist.

**Boards: `docs/review/r3d-cast-bellows/`** (3.9 MB)
- `index.md` has one line per artefact.
- Boards: `turnaround`, `before_after`, `ingame_kitchen`, `ingame_kitchen_hold`, `reach_proof`, `faces_45`, `faces_game`, `face_turn`, `tint_tiers`, `props`, `looks`, `choo`, `stars_notes`, `portraits`, `silhouettes_64`, `value_check`.
- Read test: `packets/faces_c35/`, `packets/faces_face/` and `reviewer_prompt.md`.

## APIs and contracts (rig3d.json, index §7.3 plus additive fields)

**Top-level fields**
- `scene`: `res://art3d/chars/bellows/bellows.glb`
- `skeleton`: `Armature/Skeleton3D`
- `mesh`: `Armature/Skeleton3D/bellows_body`
- `tris` 9155, `deform_bones` 49, `height_m` 1.78, `head_scale` 1.0, `blob_shadow_r` 0.48.

**Sockets** (position is bone-local; Blender bone frame = Godot bone frame, verified)
- `grip_r` / `grip_l` on `prop_r` / `prop_l`
- `mouth`, `head_top` and `face` on `Head`
- `nose_tip` on `nose`
- `specs_face`, `specs_chest`
- `belly_front` on `spine_02`
- `seat` on `pelvis`
- `feet` on `root`
- `ride` on `ride`

**Props** (default hidden, each on its own bone)
- `teacup` {held, sip} on `prop_teacup`
- `saucer`, `spoon`, `comb`, `baton` {held}
- `specs` {on, magnifier}: hides `specs_dangling`
- `specs_dangling` {dangling}: hides `specs`

**Attachments**
- `bouffant_{flipped, frazzled, wet, floured}` on `Head`.
- `stool` on `ride`: `res://art3d/set/stool.glb`, soft, pos [0, −0.55, 0]. It exists now.

**Slots, looks and FX**
- `slots.bouffant` {neat: base, flipped, frazzled, wet, floured}.
- `slot_parts.bouffant.hide_bones` [bouffant, bouffant_l, bouffant_r].
- `looks`:
  - FRAZZLED: swap frazzled, face_extra singe.
  - BLINDED: swap flipped.
  - SOAKED: swap wet.
  - FLOURY: swap floured, flash #FFFFFF 0.18.
  - SQUEAKY: face_extra pinch + hiccup.
- `fx` {choo_puff: fx_choo, stars: fx_stars, notes: fx_notes}. These are clip-driven by scale keys.
- `hidden_bones`: the 5 held-prop bones, `specs_face` and the 3 FX bones (scale 0 at setup).

**Animation and jiggle**
- `anim.layers` ["arm_out"].
- `layer_params.arm_out.rots`, armature axes: upperarm_l y −40°, upperarm_r y +40°. Pre-multiplied onto the keyed FK rotations.
- `jiggle`: bouffant ×3, sideburns, belly, cravat, coat tails (9 bones).

**Face**
- Atlas 8×8 on UV2.
- Layers: brows, eyes, pupils, mouth, extra_a, extra_b, lids. Lids use the eyes' rect.
- Composite order: extra_a, brows, eyes, pupils, lids, mouth, extra_b.
- `pupil_range` [0.035, 0.025]; `default` pompous; `mirror_cells`.
- `no_pupils` [closed, pinpoint, spiral, balloon, squint].
- `blink.hide_layers` [pupils, lids].
- `card` 0.60 × 0.60 m centred at z 1.25.

**Tint and cheat**
- `tint`: tiers #FFFFFF / #FFE0DC / #FFC2B8 / #F59A94, multiplied onto `skin` #F0C2A0.
- Livid is #B8324B.
- `sideburn_scale` [1, 1.15, 1.15, 1.35] on `scale_bones` sideburn_l/_r.
- `livid_specs` on.
- `cheat` {idle 35, walk 20, perform 35, face_to_face 5}, per the §5.1 spec.

**Portraits**
- `portraits` {dir `res://art3d/chars/bellows/portraits`, names: the 15 above}. The HUD edge bubble already loads `bellows_<emote>.png`.

## Verification

**Tests and lint**
- `tools/scripts/test_game.sh r3d-cast-bellows -- cast3d/test_bellows`: 13/13 pass.
- **Full suite** `tools/scripts/test_game.sh r3d-cast-bellows` (19:13Z run): **1417 passed, 0 failed, 0 skipped** in 156 files.
  - An earlier run at 19:04Z had 2 foreign failures that were mid-landing. Both passed on re-run after the owners landed:
    - `test_hush3d` props, in-flight Hush glbs.
    - `test_hud_s2` emote test, updated at 19:05Z to accept my portraits.
- `SANDBOX=r3d-cast-bellows tools/scripts/lint.sh`: **exit 1, not caused by this task.**
  - The main lint is OK (0 lints failed).
  - `lint_anim 3d` has 3 L10_pop_jump errors, all in untracked in-flight Hush files: `game/data/anim/hush3d/{act_dive, act_snicker, rig_step_down}.json`.
  - Nothing Bellows-related errors; Bellows 3D clips only show as "missing, not baked yet".

**Budgets**
- Body 9,155 tris; with the largest variant (frazzled 816) 9,971. The test asserts this.
- 90 bones: 49 deform + 9 jiggle. RigPerf3D counts 57 because it includes 8 weighted jiggle bones; the budget is ≤ 50 + jiggle.
- RigPerf3D `--rig=bellows --clip=bellows/rx_sneeze_blast_a`, 3 runs:
  - 9,927 tris in frame (body + the flipped variant).
  - 4 draw calls.
  - CPU median 213 / 233 / 230 µs against the ≤ 250 µs budget.
  - p95 327–405 µs, loadavg ~6.
- `glb_strut`: 162 µs median, 2 draw calls.

**Proportions and reach** (skeleton frozen, arm_out on, grip error 0 everywhere)
- Height 1.781 m to the top of the bouffant. Hip 0.45 m.
- Arms ×0.92 of UAL: shoulder→wrist 0.503 m. Hands ×1.18.
- Wrist distance of the 0.503 m arm in each reach:

| Reach | Wrist distance (m) |
|---|---|
| (a) sip | 0.313 |
| (a) saucer | 0.387 |
| (b) 0.25 m in front of the belly at y 1.0 | 0.417 |
| (c) comb over the bouffant top | 0.433 |
| (d) seated, kettle / jar | 0.418 / 0.369 |
| tea_hold | 0.402 |
| conduct | 0.472 |
| spoon | 0.443 |

**Game-scale read**
- He stands about 233 px tall at 1200×540.
- Face card 48 px; eyes 10–16 px at cheat 35.

**Value rule** (`tools/art3d/review/lab.py value` on a flat-lit render + mask)

| View | L* ≥ 85 | L* ≤ 40 | Result |
|---|---|---|---|
| Game framing | 33.4 % | 44.8 % | PASS |
| Front | 37.2 % | 40.6 % | PASS |

- Palette checks: gold cup band C* 70.6; comb C* 69.1; coat L* 37; bouffant L* 92; face L* 82.

**Silhouettes** (`sil64.py`, proof poses)
- Two pairs are at or above 0.80: idle×strut 0.81 and strut×tea_seat 0.83.
- Every other pair is below 0.72.

**Boards**
- Every board was rendered through the game's own RigPlayer3D + char_toon (reach_proof and value_check excepted, see the index).
- The kitchen shots use r3d-sets' real House3D kitchen (p00).
- I looked at every render, after the final trim.

## Deviations

- **Tri trim after the first P2 build.** The body went from 9,937 to 9,155 tris so that body + any bouffant variant stays ≤ 10k (RigPerf had shown 11,049 with the flipped variant on). What changed:
  - Sideburns, palms and shoes: se_blob n 4→3.
  - Fingers: 5→4 sides.
  - Specs torus segments reduced.
  - CHOO puff rings/segs reduced.
  - Flipped and frazzled variants re-segmented. The frazzled variant has fewer spikes than before.
  - The skeleton is untouched.
- **pinky_01 is weighted** (the pinkie-up gag), so there are 49 deform bones, not 48.
- **Each prop has its own bone** (prop_teacup/_spoon/_comb/_baton under prop_r, prop_saucer under prop_l). The props are skinned into the one mesh and shown by bone scale; they are not separate scenes.
- **FX are clip-driven.** They are bones in `hidden_bones`, and a clip must key their scale to show them.
- **The glb has no clips.** Proof poses live only in the scratch `poses.glb`.
- **Bouffant variants are attachments on `Head`.** The base lobes are hidden via `slot_parts.hide_bones`.
- **The flipped variant is a forward mop** that covers the eyes, for the BLINDED gag.
- **Tint mode is multiply** with `tint.skin` (2D modulate semantics).
- **Descriptor cheat stays at the spec's idle 35°.** At that angle the face reads badly (see requests).
- **P2 props not built:** newspaper, phone, kettle_lid, kipper, onion, megaphone. The prop_r/prop_l grip frames are ready for them as attachments.

## Requests

1. **Orchestrator: read test.** Run the two fresh-reviewer packets per `docs/review/r3d-cast-bellows/reviewer_prompt.md` (one reviewer each; keys in `<SP>/work/r3d-cast-bellows/review_key_{c35,face}.json`). Why: the brief's face bar (≥ 5/6 correct, no confused pair) needs a reviewer who has not seen the presets, and this task cannot spawn one.
2. **Orchestrator: imports.** In the `.import` files of `game/art3d/chars/bellows/face_bellows.png` and `portraits/*.png`, use lossless compression (no VRAM compression) with mipmaps. In `palette_bellows.png`, use lossless with nearest filtering. Why: 10–16 px eyes and 1-cell palette lookups smear under VRAM compression.
3. **r3d-view3d / r3d-anim-bellows: face beats.** Every Bellows face beat (reaction, sniff, sneeze build, tier change) should call `RigPlayer3D.look_at_point(camera_pos, 1.0)` for its length, or ease the cheat to ≥ 45°. Why: at the bare cheat 35° his face is 55° off frontal. The far eye sits on the silhouette edge and the mouth wraps around the jowl, so pompous, suspicious and sneeze_build look alike. With the head turned to the camera all six read (`face_turn.png`).
4. **r3d-anim(-bellows): arm_out.** Apply the `arm_out` layer to FK keys before arm IK. Why: the reaches were proven that way.
5. **r3d-anim(-bellows): scale keys.** Key the scale of the `prop_*` / `fx_*` bones in clips. Why: `ClipLib3D.load_glb_action` drops scale tracks, so a glb-loaded action cannot show props or FX; I had to show them via `set_prop` and a hidden-bone override in the boards.
6. **r3d-rig: attachment warning.** RigDef3D warns "5 attachments (budget ≤ 4 visible at once)", but it counts the four mutually exclusive bouffant variants. At most 1 variant + the stool are ever visible. Why: the warning is a false alarm; my test allows it.

## Known gaps

- **The read test is pending review.**
- **The bare cheat-35 face read is weak** until request 3 lands.
- **Two silhouette pairs are at or above 0.80** (idle×strut, strut×tea_seat). These are proof poses; the real clips belong to r3d-anim-bellows.
- **`reach_proof.png` is the P1 render** (scratch studio shader, P1 mesh). Its numbers still hold because the skeleton is frozen.
- **RigPerf CPU p95 is above 250 µs** on this loaded box (medians pass).
- **The P2 props listed in Deviations are not built.**

## Hours

About 2.8 h (16:31Z–19:20Z).

## Addendum: FIX PASS 2026-10-01 (index row 17, integrate Q02)

Row 17 is now green. I ran alone on 5fd4911; the fix pass took about 50 minutes.

### Row 17 numbers
RigPerf3D `--rig=bellows --clip=bellows/rx_sneeze_blast_a --perf-log`, 5 runs, median.

| Metric | Budget | Before | After |
|---|---|---|---|
| CPU | ≤ 0.25 ms | 0.215 ms | **0.199 ms** (195 / 199 / 206 / 207 / 194 µs; p95 316) |
| Draw calls | ≤ 4 | 5 | **4** (the borrowed stool is reported apart: `set_piece_draw_calls` 1) |
| Triangles | ≤ 10k (target ≤ 9.6k) | 10,377 | **9,495** (`set_piece_tris` 450; 9,945 if you count the stool too) |
| Deform bones | ≤ 50 | 57 | **50** |

### What the 5 draws were
In the measured frame (sneeze f95–128):
- the body and its outline (2),
- the flipped bouffant variant and its outline (2),
- the ride-along kitchen stool (1, 450 tris).

The stool is `res://art3d/set/stool.glb`, an attachment under contract §7.3. RigPlayer3D draws it with the set's `set_toon` shader and the kitchen palette, without an outline. The same clip hides the set's own stool on the same frame (`decor kitchen_stool visible false`, f95). So the frame total does not change, and row 16 already counts the draw.

REDESIGN §5.6 budgets a character at "1 skinned mesh + ≤ 4 attachments, 1 material + outline (≤ 4 draw calls)". The stool is one of the ≤ 4 attachments, but its draw is not one of the character's own material draws.

There was no real draw left to cut:
- Baking the stool into the body as a bone prop would add 450 tris to every frame of every clip.
- It would also drop r3d-rig's same-stool-as-the-set material path, which §7.3 specifies.
- The flipped variant cannot share the body's surface without a new bone, and the skeleton is frozen.

So I fixed the measurement. `RigProfile3D.rig_counts` now reports a visible set or props-art attachment as `set_piece_draw_calls` / `set_piece_tris`, separate from the character's `draw_calls` / `tris`. `game/tools/anim3d/rig_profile3d.gd` belongs to r3d-rig; I edited it under this brief's measurement clause.

### Triangles
- **Body: 9,155 → 8,755.** Only hidden geometry was removed:
  - the shirt core under the coat (above the hem and outside the V, with margins),
  - the legs' hip ends inside the barrel,
  - the cuffs' elbow caps inside the sleeve,
  - the tea disc, from n3 to n2.
- **Variants:** flipped 772 → 740 and wet 792 → 722. They lose faces buried in the head below the crown opening. Frazzled (816) and floured (650) are unchanged.
- **Worst body + slot variant:** 9,571.

### Deform bones: 57 → 50
- **Ring finger:** rides the middle finger's bones (middle_01/_02), weighted along its own segments with `seg_override`. `curl()` and `fist()` curl both fingers alike, so the bend is unchanged.
- **Thumb:** rigid on thumb_01.
- **Neck stub:** blends spine_03 → Head.

ring_01/_02, thumb_02 and neck_01 stay in the skeleton without weight. The descriptor's `deform_bones` is now the count of weighted bones, jiggle and prop / FX bones included. That matches how RigPerf3D and Hush count it, and `build.py` computes it from the vertex groups. The test asserts that the count is ≤ 50 and equals the descriptor, and it names the freed and the kept bones.

### Skeleton contract: unchanged
- `skeleton.json` sha256 is still 3fad5abf…bfad.
- The glb has the same 91 nodes and 90 joints: same names, order, hierarchy and rest TRS. The inverse binds differ by at most 0.0.
- No clip was touched. Lint --strict passes on all 72 3D clips (0 errors, 0 warnings), and `anim3d/test_bellows_clips3d.gd` passes.

### Looked at
`docs/review/r3d-cast-bellows/fixpass_before_after.png`: 26 before/after frames at 1200×540.
- Covered: the game camera (idle, sneeze f94, f110), the face camera, tea, livid fists, hunt curls, the variants from q34, back and above, and the side view of the sneeze build.
- Result: he looks the same.

Tried and reverted, because they showed:
- making all fingers rigid (stiff fists),
- culling the sleeve's shoulder cap (a gap when the arms go up in bit_livid),
- culling the spat sole,
- culling sibling lobes on the variants (lost creases and a gap),
- culling above the crown opening (the back of the head showed through).

### Checks
| Check | Result |
|---|---|
| Focused tests (cast3d/, anim3d/test_bellows_clips3d.gd, rig3d/test_perf_3d.gd) | 43 passed, 0 failed, 0 skipped |
| Full suite | 1262 passed, 0 failed |
| lint.sh --strict | rc 0 |
| e2e g0_sneeze --strict | PASS (draw p95 57, no shader compiles in play) |
| Import metadata | OK |
| Rebuild from source | byte-identical outputs |

### Requests
- **r3d-rig:** adopt the `rig_profile3d.gd` set-piece split.
- **Orchestrator / r3d-docs:** add one line to index row 17 and REDESIGN §5.6 saying a borrowed set piece is reported apart.

### Residual risk
The deform-bone count is exactly 50, so there is no margin. The next weighted bone has to come from merging another one.
