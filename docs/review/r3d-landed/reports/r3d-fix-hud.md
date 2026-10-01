# r3d-fix-hud: fix round 1 report (Q-C1, Q-C2, Q-S1, Q-S2, plus the Hud's D17 spikes)

**Status: done; three requests are open.** The rig moment and the P00 frame 2190 are re-shot from the same routes and frames and look calm. Both pictograms are redrawn. The Hud spike is noise under D17.

Still on screen, in other owners' code:
- his bubble's awareness glyph is clipped at the left screen edge (request R1);
- the jar's 3D glow.

Branch `r3d`; no git writes. Review page: `docs/review/r3d-fix-hud/index.md`. LANDED file: `<SP>/work/r3d-fix-hud/LANDED.md`.

## 1. What changed

### Q-C1: the rig moment (g0 frame 192)
1. **`game/ui/world/overlay_rules.gd`.** V1 still shows Hush's thought at the rig point. Once she is RIGGING it goes, and the ring at the prop is the one loud thing. If she lets go early, the thought comes back.
2. **`game/ui/world/world_overlays.gd`.**
   - **Face boxes.** `face_box(actor)` gives the box for Hush and for Bellows: the head anchor to the head top, 0.6 of that span to each side, plus 12 px. Face boxes are hard keep-outs with no anchor exemption.
   - **The thought** is now requested beside her face box.
   - **The rig ring** stays ON the prop. Next to a face it is drawn at 0.85× and passes behind the face (`ring_scale_near` and `RigRing.set_occluders`). I tried pushing the ring sideways first; it then sat beside the jar instead of around it, so I rejected that.
3. **`game/ui/world/rig_ring.gd`.** Arc occlusion: 72 bins, and the arc parts inside an occluder are not drawn. `outer_radius()` and `occluded()` were added.
4. **`game/ui/widgets/action_button.gd`.** While a hold is in progress the face shows its ring and ONE centred icon: no target disc, no arrow, no verb tag. A hold counts when any of these holds:
   - the button is pressed or toggled;
   - `set_holding(true)` was called;
   - the ring rose within the last 400 ms.
5. **`game/ui/hud.gd` and `game/ui/hud_model.gd`.**
   - New field `HudModel.holding`; the Hud passes it to the action button.
   - New `Hud.ghost_yields()`: a glove on `&"action"` steps away while the hold is on and comes back if she lets go early.

### Q-C2: P00 frame 2190
1. **`game/ui/world/overlay_placer.gd`.**
   - **Hard rects:** `solve(protected, safe, hard, focus)` and `place(..., hard, focus)`. Hard rects are never anchor-exempt. Fixed items are still only clamped.
   - **One cloud:** of the two thought clouds, `Pri.BUBBLE` (his) and `Pri.THOUGHT` (hers), only one shows: the one nearest the focus. With no focus, his bubble wins. The loser waits, with a clamped rect.
2. **`game/ui/hud.gd`.** New `transient_rects()` returns the shown APPLAUSE meter (with its "+n" stamp) and the RUNNING GAG fuse, using the same array every call. `WorldOverlays` adds them as hard keep-outs plus 24 px. 24 px is the most that still lets a 16:9 preview slide between the Script chip's +48 rect and the fuse, rather than waiting out a whole Running Gag.
3. **`game/ui/world/{preview_cloud,thought_cloud}.gd`.**
   - `box_size()` now covers what the cloud draws: 142×128, or 146 with his ring, where the placer was told 112×90. The thought is 222×192 against 180×144. That gap is how "clear" overlays still overlapped on screen.
   - With his ring, the tail bubbles now start outside the ring, so a preview the placer moved still points at its prop.
4. **The focus for one-cloud** is the ring anchor of the rig point she is at, else her head.

### Q-S1 / Q-S2: the pictograms
`game/art/ui/previews/in_a_pickle.svg` and `achoo_ria.svg` are redrawn in the same icon style: a 128 canvas, 5 px navy ink, look-A fills, no text. The `<desc>` ids are unchanged, so the previews.json test still matches.
- **Pickle:** Bellows, red-faced, with gritted teeth, sweat and his wig, coat and cravat. Both hands are on a stuck red lid and a twist arrow sits over it. The green jar holds a big gherkin and two pickled onions.
- **Sneeze:** his head thrown back, mouth wide, red nose. A pale-blue CHOO puff (the in-game cotton-wool shape) blasts out of the nose. The white pepper pot hangs upside down, shaking black pepper over him.

### D17: the Hud's own spikes
| Run | Hud max | Profiler frame |
|---|---|---|
| headless, baseline tree | 2.09 ms | 2529 |
| headless, this tree, run 1 | 4.15 ms | 352 |
| headless, this tree, run 2 | 4.08 ms | 2906 |

- Hud p95 is 0.055–0.071 ms in all three runs.
- The spike never repeats at the same frame. In the same headless runs `root:Settings` and `root:Save` go over 1 ms, and eight other nodes reach 5–20 ms. The box preempts headless runs too.
- A scripted bench of the Hud subtree covered every Prologue HUD transition over 1,800 frames. Its worst frame was 0.48 ms.
- **Verdict: noise under D17.**
- One real cold cost turned up: an activity icon's SVG is rasterised on first sight in `Hud.apply`, about 1 ms, counted under NightScene. Tonight's loop and trigger activity icons are now rasterised under the curtain in `WorldOverlays.warm`.
- Evidence: `<SP>/work/r3d-fix-hud/prof/` (the three `*_prof*.json`, `bench_hud_tmp.gd`).

## 2. Before / after frames (`docs/review/r3d-fix-hud/`)
Each before frame is the reviewer's packet image. Each after frame was shot on the same route and frame, 1200×540, `--no-captions`, MSAA off.
- **g0 frame 192, crowding pkt_02:**
  - `crowd_g0_f192_board.jpg`, `crowd_g0_f192_zoom_head.jpg`, `crowd_g0_f192_zoom_button.jpg`, `crowd_g0_f192_after.png`.
  - The after frame has no thought, the ring around the pepper pot with her face in front of it, and a button showing its ring and one glove icon with no tap-hand.
- **P00 frame 2190, crowding pkt_06:**
  - `crowd_p00_f2190_board.jpg`, `crowd_p00_f2190_zoom.jpg`, `crowd_p00_f2190_after.png`.
  - The gramophone preview is clear of the meter and the "RUNNING GAG ×1" text, and its tail points at the gramophone.
- **Spot frames:**
  - Pickle, N1 calm t360: `spot_pickle_board.jpg`, `spot_n1_full_board.jpg`, `spot_n1_calm360_after.png`.
  - Sneeze, g0 frame 90: `spot_g0_f90_board.jpg`, `spot_g0_f90_after.png`.
  - Both pictograms side by side, including at in-game size: `pictograms_before_after.png`.
- Paused seek shots taken while iterating: `crowd_g0_t192_paused_{before,after}.png`.

## 3. Tests and lint
- **New tests.**
  - `game/tests/ui/test_crowding_qa.gd`, 9 tests, with its `.uid`. It covers:
    - no thought while she rigs;
    - the ring passing behind a face, at 3 aspects;
    - no cloud on a face box, at 3 aspects and both sides;
    - the glove stepping off the button and coming back;
    - the held button face;
    - `Hud.transient_rects`;
    - previews keeping out of the shown meter and fuse with the tail still on the prop, at 3 aspects;
    - his bubble waiting while her thought is the action, and clamped otherwise;
    - cloud boxes covering what they draw.
  - `test_overlay_placer.gd` gained 5 tests:
    - the face-box keep-out, with the thought exempt from its anchor rect;
    - the banner keep-out;
    - the safe-rect clamp;
    - the one-cloud rule (all four at 20:9, 16:9 and 4:3);
    - no allocation with hard rects.
- **`ui/`:** 269/269 pass.
- **Full suite** (`test_game.sh r3d-fix-hud`): 1289/1290. The one failure is `set3d/test_house3d_data.gd::test_anchors_inside_the_prop_and_the_preview_band` (`parlour_piano_back.eyes_anchor`). It comes from `game/data/house/house3d.json`, which another fixer is editing right now, not from these changes.
- **`SANDBOX=r3d-fix-hud-lint tools/scripts/lint.sh --strict`:** OK. **`check_import_meta`:** OK.
- **e2e with these changes:** `g0_sneeze` PASS and `prologue_ideal --fixed` PASS. One earlier P00 run failed on another fixer's mid-edit of `gag_stager_3d.gd` (`_burst` arity); a re-run on the fixed tree passed.

## 4. Requests
- **R1, r3d-view3d.** Files: `game/view3d/world/overlays_3d.gd` and `game/view/fx/thought_bubble.gd`. His bubble is clipped at the left edge: the "second bubble half visible" in pkt_06 is the awareness-glyph disc and its ear pips.
  - **What is drawn:** the glyph disc and pips sit −115 local units from the bubble position and the cloud reaches +95 units. At `BUBBLE_SCALE` that is −153 to +127 px.
  - **What is clamped:** the centre is clamped only to `w*0.6` = 120 px.
  - **(a) Clamp:** clamp `sx` to [161, vs.x − 135] and request `_bubble_rect = Rect2(sx − 153, sy − h, 280, h)`.
  - **(b) One-cloud rule:** read `placer.item(&"fx_bubble")` from the last solve. If `was_active and not visible`, fade the bubble out, using a flag of its own rather than `quiet`, which the gag holds use.
  - **(c) Tail:** mirror the cloud texture when the bubble sits left of his head, so the tail points at him.
- **R2, r3d-night.** In `game/scenes/night/hud_presenter.gd`, set `m.holding = snap.hush.state == "RIGGING"`. The Hud infers the hold from the ring rising with a 400 ms grace, and that lapses on paused frames.
- **R3, orchestrator.** I edited `game/art/ui/previews/{in_a_pickle,achoo_ria}.svg`. These belong to r3d-hud under index §4 and were assigned by Q-S1/Q-S2, but they are not in this round's literal ownership list. The old copies are in `<SP>/work/r3d-fix-hud/pict/old/`.
- **R4, r3d-docs or orchestrator.** Proposed REDESIGN §2.4 and §2.5 amendment text:
  - **§2.5:** "Face boxes and the shown transient band (meter + fuse, +24 px) are hard keep-outs for every world overlay. At most one thought cloud shows: his bubble or Hush's, whichever is nearest the action. While Hush rigs, her thought hides and the rig ring passes behind a face next to the prop (drawn at 0.85×)."
  - **§2.4:** "While held, the button shows its ring and one icon, and a teaching glove leaves the button."

## 5. Residual risks
- **Two items still show until R1 lands:**
  - The left-edge clip of his bubble's glyph in the P00 frame 2190.
  - His bubble when both clouds are up: the placer already decides that one should wait, but `Overlays3D` does not read the decision back.
- **The jar's 3D glow still sits next to her face while she rigs.** It is the D10 halo, owned by r3d-view3d. Only one fresh reviewer can say whether the ring behind the face plus that glow reads as calm.
- **The redrawn pictograms are 39 px in a 1200×540 shot** (78 px logical), so detail is limited. They need a new fresh spot reviewer (R17); I did not run one.
- **Bigger cloud boxes and the hard keep-outs make previews wait more often in tight frames.** On a 4:3 tablet, a preview under the left end of the fuse may wait while a Running Gag is live.
- **The hold is inferred from the ring rising.** Until R2 lands, the glove can reappear on paused or very slow frames.
