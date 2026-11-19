# Characters that reach the world: procedural limb goals on the cutout rig

> **Read §11 first.** Phases 1–4 (§6–§10) were built on the older Night game (the cutout `RigPlayer` cast
> — Hush and Bellows — in `house.json`). The current scenes are the **stage Acts** (`game/proto/act1..5`,
> Hush and Gus), whose cast is BAKED by the Bakery; §11 is the same idea moved there, and is what you see in
> the Acts. The cutout-rig work stays valid for the Night game but is parked.

Research report and build plan (2026-11-15; phases 1–2 built 2026-11-16, phases 3–4 2026-11-17). Owner `rig`.
Question from the owner: the cast plays a fixed set of clips whatever the situation, so moves that need a
limb to *go somewhere* (reach a shelf, grab a jar, close on Hush's braces) are impossible today. How do we
push the animation further, more physically, programmatically, and in a way an agent can test for accuracy?

---

## 1. Diagnosis: no clip knows where anything is

The pipeline itself is sound (JSON clips → `RigSampler` → layered `RigPlayer`, springs, rubber-hose limbs,
`AnimLint`, `capture.sh`, `stability.py`). What it lacks is any link from a limb to the world:

- **Every hand is FK.** Clip keys are part rotations. `poses.json` says "IK/aim/pin were solved at build time":
  `tools/art/hush/clipkit.py` `ik()` solves once while authoring and the result is frozen into the key.
- **Runtime IK existed only for feet.** `RigSampler.plant()` was an analytic 2-bone solve used to stop planted
  feet sliding *between keys*. `comedy.md` §5.1 planned 2-bone IK "for foot plant **and reach**"; reach never landed.
- **Look-at is head + pupils only**; the torso does not follow and the eyes do not lead.
- **One clip serves every height.** Measured against `house.json` (40 containers + rig points, using each
  hotspot rect's centre as the stand-in for "where the hand goes"), Hush's shoulder is at ≈190 px and she reaches
  ≈280 px straight up:

| Band (Hush, h_stand) | Hotspots | Examples |
|---|---|---|
| arm alone (≤ 280 px) | 26 | coins 75, piggy bank 83, kettle 252, basin 265 |
| tiptoe + 1.3× hose stretch (≤ 322 px) | 2 | bath taps, duck (312) |
| above her head | 12 | newspaper 334, fridge shelf 384, honey 444, clock 462, chandelier 534, spotlight 542 |

  A single `act_tinker_*` plays for all of them, so the glove is almost never on the object.

## 2. Options weighed

| Option | Verdict |
|---|---|
| **Runtime goal layer: analytic 2-bone IK on our rig, data-driven targets** | **Chosen.** Exact, deterministic, allocation-free, headless-testable; reuses the plant maths and the rubber-hose limbs. |
| Godot `Skeleton2D` + `SkeletonModification2D` (FABRIK / CCD / TwoBoneIK) | No: Experimental, needs Bone2D scenes, does not drive our RenderingServer flat rig (`comedy.md` §5.1 rejected Skeleton2D for the same reasons). |
| Custom FABRIK / CCD for n-bone chains | Not needed yet: every limb is 2-bone; a spine/lean heuristic covers the torso. Revisit for tails, ropes, hoses. |
| Bake low / mid / high variants per action and blend | Content multiplies (×3 per action, ×2 rigs) and the hand still misses between bakes. Useful later as a *base posture* under the IK. |
| Active ragdoll (`game/spikes/common/rag_cast.gd`) | Excellent for knock-downs (jitter 0.07, pops 0) but not precise; keep as a future hit-reaction layer. |
| Motion matching / learned motion | Far outside budget and scope for a 2D cutout farce. |

## 3. The design

A **limb goal** layer in `RigPlayer._update_pose`, after the clip / overlay / additive / procedural layers and
before springs → limits → FK. The clip still owns timing and acting; the goal moves the effector onto the world.

1. **`RigIK` (shared solver).** `two_bone(rig, pose, up, lo, end, target, end_deg, bend, weight, stretch_max, tip, limits)`
   solves in the chain parent's frame (lean, squash and mirroring are exact). The effector is the end joint
   plus a `tip` (the `hand_*:grip` socket), so the **grip** lands, not the wrist. The plant lock now calls it.
2. **Authored arc, retargeted** (phase 2). A reach clip is authored against a `ref_target`; at runtime its hand
   path is displaced by `(real − ref)` under a weight curve, keeping the animator's anticipation / overshoot.
3. **A `reach` block in clip JSON** (built in phase 2 — §7 has the final shape), with the target named and
   resolved at play time from data (golden rule 3): `RigPlayer.set_target("grab", pos)`; `CharacterView`
   fills it from the hotspot's `grab` / `grab_l` in `house.json` (later: a prop socket, or another rig's socket
   — Bellows' `st_grab` closing on `torso:braces`).
4. **Reach escalation** (phase 3), each step capped: arm → torso lean (limits) → tiptoe / crouch (root offset,
   feet held by plant IK) → **rubber-hose stretch** (≤ 1.3×; on-style and funny) → *unreachable* → the view picks an
   authored hop / stool / climb.
5. **Attention leads action** (phase 3): look as a chain — eyes, head 3–4 f later, torso — aimed at the active
   goal; hand texture swap and prop hand-off to `hand_*:grip` on contact; springs give the follow-through.

The sim is untouched: clip lengths and timings do not change (A29 and determinism unaffected).

## 4. Testing for accuracy

What an agent can prove headless, and what still needs the owner's eye:

- **Solver tests** (`game/tests/rig/test_ik.gd`, phase 1): every position is checked with an independent full-rig
  FK (`RigSampler.solve`), never with the solver's own report.
- **Lint rules** (phase 4): A30 reach contact (grip within 2 px of the target at the contact frame, for every
  hotspot a clip is mapped to), A31 no elbow pop, A32 feet stay planted during lean / tiptoe, A33 stretch ≤ cap.
- **Reach matrix** (phase 4): every reach clip × every hotspot → CSV (strategy, stretch, error px) + a contact
  sheet with target crosshairs, looked at like any screenshot.
- **Motion:** `AnimViewer --goal…` + `capture.sh` + `stability.py` (IK flips show as pops); e2e: log the grip at
  each contact event in a scripted Night and compare with the hotspot's `grab` point.
- **The limit:** numbers prove the hand lands and nothing pops or slides. Whether a reach *feels* right on a phone
  held sideways is the owner's call from GIFs, strips and a play.

## 5. Plan

| Phase | Scope | Status |
|---|---|---|
| 1 | `RigIK` + tests; RigPlayer goal API driven from code; AnimViewer `--goal` + crosshair | **done 2026-11-16** |
| 2 | clip `reach` block; hotspot `grab` points (per facing) + tests; port pickup / tinker / rummage; wired into the game | **done 2026-11-16** (low / mid props) |
| 3 | reach posture: step back, straighten, look (eyes lead), tiptoe, stretch, hop, crouch, contact pinch | **done 2026-11-17** |
| 4 | Bellows reaches (the pickle jar, with his own posture); the reach matrix instrument + test; no-pop fixes (soft reach limits, joint rate limit); the Bellows map generator brought back in sync | **done 2026-11-17** |
| 5 | see §10 — what is left | next |

## 6. Phase 1 — what was built and measured

**Code.** `game/view/rig/rig_ik.gd` (new): `chain_of`, `socket_tip`, `limit_bend`, `two_bone`, `effector`.
`RigSampler.plant` now calls `RigIK.two_bone` (same behaviour; the plant test and all anim lints still pass).
`RigPlayer`: `set_goal(limb, world_pos, opts)`, `move_goal`, `clear_goal`, `clear_goals`, `has_goal`,
`goal_weight`, `goal_error`, `goal_stretch`, `goal_target`, `goal_limbs` — one pre-built slot per 2-bone limb in
`rig.json` `limbs`; options `socket`, `weight`, `blend_f`, `end_deg`, `bend`, `stretch`, `follow`, `limits`.
`AnimViewer`: `--goal=<limb>:<x>,<y>[;…]` (x in front of the feet, y down from the floor), `--goal-stretch`,
`--goal-blend`, `--goal-follow`, `--goal-sweep=<f>[:<r>]`, `--goal-cycle=<f>`, a crosshair (green ≤ 2 px, amber
blending, red unreachable) and a live error / stretch / weight readout.

**Decisions the tests forced.**
- *The grip is folded into the forearm, not iterated.* With a free hand the grip is rigid on the lower bone, so
  the chain is solved closed-form with `forearm + rotated grip` as the second bone. The first, iterative version
  missed by up to 11 px on the mannequin.
- *Weight blends the effector, not the angles.* Blending angles hits the ±360° ambiguity (a 209° elbow spin was
  measured); blending the point the chain is solved for gives a straight hand path and returns the clip pose
  exactly at weight 0.
- *±360° representatives are chosen inside the joint limits*, nearest the incoming pose, so a limit is only
  clamped when no in-limit solution exists (the mannequin's [-215, 160] shoulder no longer pops 68°).
- *The grip has a dead zone at the shoulder.* The grip sits 23–36 px past the wrist, so the hand cannot fold
  onto its own shoulder (Bellows' grip: ≥ 36 px away). The solver reports the miss; tests sample each arm's real
  band.

**Measured.**
- Grip error on reachable targets: < 0.5 px over 200 random targets × 2 arms × 3 rigs (mannequin, Hush, Bellows);
  < 1 px in world space through RigPlayer at both facings, on a playing idle, through the 6-frame turn.
- Elbow: constant side and ≤ 4° per sub-pixel target step round a circle in every rig's reach band.
- Blend: monotone approach, first frame < 0.5× the average step, peak ≤ 1.6× (smoothstep, no snap); back to the
  clip pose within 0.01 px after release.
- Cost: 6.5 µs per solve on the desktop (GDScript). **Estimated** 30–40 µs per active limb on a mid-range Android
  phone — not yet measured on a device; a character with no goal pays nothing.
- Capture (`AnimViewer`, Hush idle, `--goal-sweep=120:45 --goal-cycle=60`): jitter 0.22 (library band 0.14–0.23).
  `stability.py` flags 4–5 consecutive frames mid-blend at each toggle: the 10-frame reach itself, crossing a
  3×-median threshold set by a near-motionless idle — a smooth bump on the curve, not a one-frame pop. The
  speed bound above is the real no-snap check.

**Seen in screenshots** (kettle height, high shelf with stretch, Bellows facing left, out of reach).
- Hush's reach reads naturally from the idle.
- **Bellows' near arm crosses his face.** His `arm_r` is drawn over everything (z 60, head 32) but its shoulder
  sits behind his head line (x −14 vs the head's +16), so a forward reach at face height lays the sleeve across
  his chin. His far `arm_l` (z 6) would vanish behind the head instead. Phases 2–3 need a staging rule for
  face-height reaches: keep the near forearm below the chin line (lean / bend choice), or swap the forearm's z
  behind the head while it is above the shoulder. Hush is fine: her near shoulder is in front of her head line.
- An out-of-reach target leaves a straight arm pointing at it and a red marker with the true miss — the gap
  phase 3's tiptoe / lean / stretch must close.

## 7. Phase 2 — reaching in the game

**Why phase 1 changed nothing in play:** it was the solver and an API; no game code called it. Phase 2 is the
first change a player can see — and only on some props, for the reasons below.

**What was built.**
- **Clip `reach` block** (`ClipDef.reach_*`, parsed and validated in `ClipLib`):
  ```json
  "reach": {"target": "grab", "limbs": ["arm_r", "arm_l"], "ref_f": 28, "stretch": 1.25, "max_height": 205,
            "weight": [[0, 1], [96, 1], [104, 0], [138, 0], [146, 1]]}
  ```
  The clip's reference grip (the limbs' mean grip at `ref_f`) is sampled from the clip at load. At runtime
  every listed glove moves by the SAME offset (target − reference) × the weight curve, then RigIK re-solves
  the arm — so the authored motion survives (the tinker jiggle, both gloves' spacing, the hammer arc) and
  lands on the prop at the contact frame. `ref_root: false` for clips played as masked overlays (the pickup:
  overlays never write the root, so its crouch is left out of the reference). No target = the clip exactly
  as authored (tested pose-for-pose).
- **RigPlayer:** `set_target(name, pos)` / `clear_target` / `target_of`, `reach_info(limb)`,
  `is_reaching()`, `reach_skipped()`; the reach runs on the base and overlay clips before code goals.
- **Data:** `grab` (facing right) and `grab_l` (facing left) on all 40 containers / rig points in
  `house.json`, from `tools/art/house/geo.py` `GRAB` via `house_json.py` (`--grab-only` re-applies them
  without the full art build, byte-identical to `build_all.py`). Proposed by `tools/anim/grab_points.py`
  from `game/tools/anim/prop_spans.gd`, which measures each prop's VISIBLE pixels per 8 px column.
- **Game wiring:** `ViewSnapshot.Actor.at_hotspot` (the sim's existing `at_hotspot`, read-only) →
  `CharacterView._drive_reach` sets the grab point for the way Hush faces while she stands at the hotspot.
  `CharacterView.reach_enabled` / `--no-reach` (ViewSandbox, AnimViewer) is the dev A/B switch.
- **Clips** (through the generator, `tools/art/hush/clipkit.reach()`; the build diff is exactly the five
  `reach` blocks): `act_tinker_q`, `act_tinker_s` (both gloves, constant weight), `act_tinker_b` (the f28
  slam; released for the brow wipe f104–f138), `act_rummage` (both gloves, contact f0), `act_pickup`
  (right glove, f6–f18, `ref_root: false`).
- **Tools:** AnimViewer `--hotspot=<id>` (her stand point, facing and grab point in the real room) and
  `--no-reach`; `tools/scripts/reach_sheet.sh` (one shot per hotspot, tiled).

**What the review forced (each one changed the design).**
1. *Bounding boxes lie.* The first rule aimed at each prop's canvas box and put the kettle's grab point on
   Hush's face: the box runs 95 px in front of her, but only the thin spout does. → measure visible pixels.
2. *Props stand behind her.* Every prop is drawn centred over its stand point, so her body hides most of it.
   → aim at the part visible in front of her (the column nearest 62 px ahead).
3. *Her head is over her hands.* Every work clip leans her head out over the gloves (its canvas reaches
   129–191 px forward), so lifting the gloves to head height puts them on her face. → `max_height: 205`:
   props above her chin keep the authored motion until phase 3 moves the body (step back / lean back / look
   up). This is the main limit of phase 2.
4. *She faces the way she walked in*, not the hotspot's listed facing. The first in-game A/B (Night 1, the
   confiscated box) had her gloves reaching AWAY from the box behind her. → a grab point per facing.
5. *Containers are not all boxes.* The rim rule sent the fridge's point to its top. → only short open
   boxes on the floor are reached into; tall or wall-hung ones (fridge, cabinet, pantry) at the door.

**Where it shows.** Of the 40 props, these get the reach at their listed facing (`reach_sheet.sh`; add
`-- --facing=-1` for the other side): the confiscated
box, piggy bank, fridge, mirror, stair rods, gramophone, recliner, tea tray, feed bin, potting bench, hose,
marrow, the three coins, bed, bedside, costume trunk, dummy (and the piano wedge, which her arm points at but
cannot reach — phase 3's crouch). The rest are at head height or above and play as before. **Night 1's ideal
route works mostly at the kitchen's high props** (sink tap, honey, pickle jar, kettle), so in Night 1 the
visible change is the confiscated-box rummage (her gloves go into the box instead of hanging at the floor
beside it) and a few frames at the recliner. The big visible change for Night 1 is phase 3.

**Measured.** Tests (`game/tests/rig/test_reach.gd`, 11): the gloves' midpoint lands within 1.5 px of the
target at the contact frame (both facings), their spacing is kept within 1.5 px, the tinker-B slam lands
within 1.5 px, the brow wipe / no target / above `max_height` frames are pose-for-pose the authored clip, the
pickup overlay lands within 6 px over an idle, all 80 grab points are inside their room and not behind her,
the snapshot carries `at_hotspot`, and a real CharacterView feeds the right side's point and clears it on
walking off. Seen: the 40-hotspot sheet; real-sim A/B sequences of Night 1 (box, recliner) with `--no-reach`.

**Known issue found on the way (not this work):** `e2e.sh n01_ideal --shot-seq` with a late `--seq-from`
(≥ ~4400) captured a frozen early frame (Script panel open, applause 2) instead of the route; a short
sequence from frame 300 plays correctly, and the plain e2e run passes. ViewSandbox `--sim --cmds --seek`
was used instead.

## 8. Phase 3 — the body adapts (the change you can see)

**Why phase 2 was hard to see:** every work clip hunches Hush's head over her gloves, so phase 2 left every
prop above her chin alone — and Night 1's kitchen props (sink tap, honey, pickle jar, kettle) are all up there.

**What was built.** A *reach posture* in `RigPlayer` (`_posture`), configured per rig in `rig.json`
`reach_posture` (Hush only; generated by `tools/art/hush/rig_hush.py`; Bellows has none and never changes).
Driven by the base clip's reach (else the overlay's), scaled by how far the target is above her chin
(`chin` 200 px, full at +`span` 60) or below her knees (`low` 90 px, full at −`low_span` 60), and eased in and
out over `ease_s` 0.2 s (arriving reads as a shuffle, leaving as a straighten; it keeps running while easing
out after the target is cleared, so nothing pops):
- **step back** up to 60 px (root x) so the target sits `clear_fwd` 80 px in front of her;
- **straighten / lean back** — the torso blends to −14° instead of the clip's hunch;
- **look** — the pupils go to the target at once, the head follows `look_lag` 0.12 s behind (±35°);
- **tiptoe** — root up 14 px, feet 22° toes-down and their `tiptoe` texture;
- **stretch** — the arm may stretch to 1.3× while the posture is on;
- **hop** — for what tiptoe + stretch still miss (up to 70 px, 1.7 hops/s, sin^1.6 so she taps at the top
  instead of hanging there): the honey and pickle jars, the clock, the fridge shelf;
- **crouch** — for low targets the hips drop up to 50 px and lean in 20°, and both legs are re-solved by
  RigIK so the feet stay exactly where the clip planted them: the coins, the piano wedge, the marrow;
- **pinch** — a glove within 8 px of its goal switches to its `pinch` texture.
The reach offset is measured from where the CLIP puts the glove, before the posture moves the body (the first
version measured after, and a 68 px hop sent the glove 68 px over the jar — the probe caught it).

The clips' `max_height: 205` stopgap is gone (`max_px` 420 so a chest-height clip may reach the clock); a clip
can still set `max_height` to opt out.

**Measured.** `game/tests/rig/test_posture.gd` (6): the honey jar → full posture, a step back, a hop > 20 px,
the head > 20° up, tiptoe feet, and the glove within 12 px at the top of a hop; the kettle → every frame of the
loop solves within 1 px, no hop, the gloves' midpoint within 3 px at the contact frame, the glove pinches; a
coin → full crouch, the hips drop > 30 px, the feet within 1 px of the clip's for the whole crouch; release →
still mid-ease one frame later, then exactly the authored pose; Bellows → identical with or without a target.

**Seen.** The 12-prop sheet (kitchen, hall, parlour, bathroom, bedroom), the 6 low props, and Night 1 on the
real sim, BEFORE (`--no-reach`) over AFTER at each moment Hush works (`tools/scripts/reach_ab.sh`): the honey
jar and the pickle jar are now a tiptoe-and-hop up to the shelf instead of a hunch at the counter / fridge
door; the sink tap and kettle are an upright reach to the tap / spout; the confiscated box is gloves in the
box; the recliner is the least changed (facing left its point is the tall back).

**Not done / known limits.**
- The kettle, sink tap and basin: their visible part is just in front of her face, so the glove ends at her
  chin; the kettle body stays hidden behind her. Phase 4: a better point or a deeper step back for these.
- Prop hand-off (the picked item travelling in the glove) is not built.
- **Cost:** the reach + posture is ~32 µs per frame on the desktop while Hush is reaching (two-limb IK 14,
  posture 8, the rest bookkeeping); her whole rig update goes from ~60 to ~130 µs on the desktop. On a
  mid-range phone that is an estimated 100–150 µs extra while she reaches — possibly over the 0.25 ms per
  character budget for those moments. Not measured on a device yet; nothing is paid when no reach is on.

## 9. Phase 4 — Bellows reaches, and the instrument that keeps reaches honest

**Scope decisions, from looking.** Bellows' activity clips mostly handle HELD props (the handset at his cheek,
the paper, the cup, the winding key), so pulling those hands onto the fixed prop would make them worse — only
the pickle jar, the fridge and the sink touch a fixed prop, and of those only the pickle jar reads right (the
sink's target is the tap at his face; the fridge clip reaches into its top shelf, not the door). His catch
(`st_grab`) is covered by the Busted Cam replay and the lecture already snaps Hush to his fist, so a real grab
would not be seen. Hush's kettle / sink / basin: a deeper step back did not help (their visible part is a thin
front edge at her face; showing the body would need her 150 px off her sim position) and it cost the honey
hop 10 px, so it was reverted — those three stay "glove on the visible edge".

**Built.**
- **Bellows reaches the pickle jar** (`act_pickles` reach block, both hands, f54–f190; `tools/art/bellows/
  clips_spec.reach()`), with his own `reach_posture` (rig_spec.py: no step back or crouch — his stations stand
  him beside his props — but a straighten, a look, tiptoe, 1.35× stretch and a hop up to 75 px: "Bellows loses
  a fight with a jar"). `CharacterView._drive_reach` now serves him too: the prop at his activity's station
  (nearest hand height when a station has two — st_tea's kettle over the honey), its centre
  (`grab`/`grab_l` midpoint) since he stands beside it. In Night 1 (ticks 6193–6493) he goes from hands at his
  face to a jump for the shelf.
- **ReachMatrix** (`game/view/rig/reach_matrix.gd`, `tools/scripts/reach_matrix.sh`,
  `game/tests/rig/test_reach_matrix.gd`): every container / rig point × facing through the real RigPlayer,
  headless, scored — best glove-midpoint distance over a settled loop, at the contact frame, posture, hop,
  crouch, the worst per-frame arm joint change against the SAME clip with no target (the authored motion's
  own fastest joint). Status reached ≤ 6 px, touch ≤ 20 px (needed the hop / crouch), short, pop (> 25°/f
  over authored). The test forbids pops, requires ≥ 62 of 80 reached or touched, and pins the short list.
- **No-pop fixes the matrix forced.** The first run flagged every container cell (68–150°/f vs 24° authored)
  and every crouch cell (32° vs 4°): not elbow flips (hysteresis on the elbow side changed nothing) but the two
  singularities of a two-bone arm — a translated toss path sweeping past arm's length and past the shoulder.
  Fixed by (1) `RigIK.two_bone(…, soft)`: the last 12 % of the reach near full extension AND near the fold is
  eased asymptotically (the plant lock keeps hard clamps); (2) a per-joint rate limit in the reach: solved
  joints may outpace the clip's own joints by ≤ 24°/f, so a sweep lags a frame instead of snapping; (3) the
  rummage reach weighted 1 in the box and 0.35 during the right glove's tosses. Result: 0 pops, 49 reached,
  18 touched, 13 short (the clock, chandelier, spotlight, pantry shelf, cabinet, boiler valve, trophy shelf
  facing left — all far above tiptoe + stretch + hop; a stool / climb clip's job).
- **Generator drift fixed:** `tools/art/bellows/clips_w0b.py`'s map lacked the hand-added `oneshot:head_turn`
  variants and `oneshot:notice`; it now emits them (map.json regenerates semantically identical).

**Measured.** `test_posture.gd` (7): Bellows' pickle reach → posture on, no step back, head up, a real hop
(> 40 px), hands within 30 px of the jar's centre (inside the 130 px jar art). `test_reach_matrix.gd` (1):
the contract above. Seen: Bellows at the jar in the viewer and in Night 1 (`--no-reach` A/B).

## 10. What is left

1. **Device performance.** The reach + posture costs ~32 µs per reaching frame on the desktop (Hush's update
   ~60 → ~130 µs). Not measured on a phone; estimated 100–150 µs extra there, possibly over the 0.25 ms per
   character budget during reaches. Measure on the mid-range Android target first; if over, cache the posture
   floats and the chain parents, or move RigIK to C++/GDExtension.
2. **Kettle, sink tap, basin spray (Hush).** Glove on the thin visible edge at her chin; the prop body stays
   behind her. Options: hand-placed grab points on the visible edge, a view-only turn to face the prop's
   visible side (needs a per-hotspot `work_facing`), or re-staging those three props' art.
3. **The 13 short cells** (clock, chandelier, spotlight, pantry shelf, cabinet, boiler valve, trophy shelf
   facing left): too high for any posture — a stool / climb clip chosen by the view when ReachMatrix says
   short (the tinker clip already carries a stool prop).
4. **Prop hand-off.** The picked item does not travel in her glove to the tray.
5. **Bellows' other activities.** Fridge (the clip reaches into the top shelf: needs a shelf grab point),
   sink (hands in the basin: a basin point, not the tap), the fix-up detours (`act_fixup_sink`/`_mirror`),
   and his near arm crossing his face on face-height reaches (a z swap or a forearm-below-chin rule).
6. **Lint rules A30–A33 as AnimLint rules.** Reach-block validity is a ClipLib error (surfaced by A02) and
   contact / pop accuracy lives in the ReachMatrix test; the plan's named lint rules were not added as such.
7. **Look chain for everyone.** The posture's eyes-lead-head look runs only during reaches; Bellows' look-at
   toward Hush / the Stalls still moves head + pupils together (`look_toward`).
8. **Tuning by eye.** Hop height / rate, the 0.2 s ease, the 1.3× stretch — all data in `rig.json`
   (`reach_posture`), waiting for the owner's pass on a phone.

## 11. The stage Acts — reaches baked by the Bakery (2026-11-18)

**Why the earlier phases were invisible in the Acts.** The Acts (`proto/stage/show.gd`) draw a BAKED cast:
Hush and Gus are sprite sheets rendered from 3D models (`tools/bakery`, CC0 KayKit library clips), and the
show only picks frames. None of RigPlayer / RigIK / the posture is in that path. Every hand beat in the Acts
was a library clip played where the actor happened to stand — Hush "wound the treadmill" at chest height
beside its pole, Gus "checked the wardrobe" at the air. The Act V log already said it: no carried props
"until the cast has grab poses".

**Built.**
- **Bakery `reach` recipe** (`tools/bakery/bake.py`): the same offset-retargeting idea, in 3D at bake time.
  The clip's hands are carried onto a STAGE point by one film-plane offset (target minus where the clip has
  the hands at its contact, measured in the planted stage frame), each arm re-solved by analytic 2-bone IK
  (elbow kept in the clip's own bend plane; soft limits at full extension and at the fold), with **rubber-
  hose stretch** (the arm bones lengthen, the glove keeps its size — the chibi cast's arms are ~40 sprite px,
  so head-height props need it) topped up iteratively, and an optional posture (lean, look at it, tiptoe).
  Contact modes: seconds, `forward`, `lowest`, `highest`, `mean` (centre a sawing stroke); weight keys or
  `{"around": …}` (one-shots reach only around their contact).
- **Every sheet now carries per-frame hand points** (`hands`), carried through prune / sheet / the index,
  and reach clips carry their contact error (`reach`). `run.py` fails a reach over 3 px at contact / 6 px
  while on (sprite px; ×1.6 on stage).
- **Targets in stage terms**: `reach.stage = {act, at | mark, stand, dir}` (`run.py resolve_reach`).
  `tools/stage/reach_map.py` draws an Act's set in TRUE stage coordinates (no camera) with a grid, marks,
  pivots and stand lines, to read targets off; `tools/bakery/reach_spec.json` + `tools/bakery/add_reach.py`
  add the clips to clips.json without disturbing it; `tools/stage/swap_clip.py` points a timeline beat at a
  clip without disturbing the timeline.
- **show.gd**: `hand_point(who, side)` (where a hand is on stage, frame by frame); props can **ride a hand**
  (`prop` `"ride": who, "hand": "l"`) and are let go where the hand had them.
- **Content**: 14 targeted clips on 19 beats in all five Acts — Act I gramophone, pedestal saw, butter on the
  floor; Act II toaster, chair-leg saw, pantry hammer, Gus into the fridge (×6); Act III mower throttle, shed
  post saw; Act IV treadmill console; Act V Gus at the wardrobe (×2) and the light switch, Hush's alarm-clock
  pick-up (the clock now travels **in her hand** before the toss into the pillow) and the bed frame.

**Accuracy.** Bake: every reach 0.0–2.0 px at contact, ≤ 3.8 px while on. Stage
(`game/tests/stage/test_stage_reach.gd`): each Act played headless through the real show; at every reach
beat the actor must stand and face as baked (±3 px), the clip must still be playing at contact, and the
hand (placed exactly as the show draws it) must land within 12 stage px of the target (strokes: their
centre). It found, and forced fixes for: Hush standing at 1753 not 1785 for the shed saw and at 1791 for
the hammer (targets had assumed the timeline's `move to`); the hammer's "lowest" frame falling after the
beat ended (pinned to the first strike, 0.27 s); and **Hush still sliding into the pickup** at 1642 in
Act V (a pre-existing timing glitch — the clip now reaches from where she is). A second test checks a
hand-held prop is drawn exactly at the hand and is let go where the hand had it.

**Seen.** All 15 hand beats before / after on the real stage (`--start=` stills, the camera included) and
the Act V clock grab as a sequence. Clear wins: the console, the mower, the bed, the pantry, the chair, the
butter, the gramophone, the clock grab; subtle: the pedestal and shed saws.

**Left (stage Acts).**
1. **Act IV bag strap** — 440 px above the floor, out of any reach; needs a hop the bake and the stage
   timeline agree on (or a stool beat).
2. **A held prop draws behind her** while riding (the Act's draw order puts props before the cast);
   needs "held props draw in front of the holder".
3. **Gus's interact beats** land on target at contact but are one-shots: a still between beats can catch
   the wind-up; worth a look at speed (the test proves contact, not taste).
4. **More grabs now possible**: the Act V gown (removed for lack of grab poses) could come back with a
   real hand-off; Act II pancake / toast catches; Act III Gus's `grab` at the shed.
5. **Marks for handles**: targets are read off the set (`reach_map.py`) as stage px; adding named marks
   for the handles in the set builders (`tools/stage/actN_set.py`) would make them survive a re-staging.
6. **Contact sheets** (`run.py --contact`) were not regenerated.

**Parked (the older Night game, cutout rig):** device perf of the RigPlayer reach, kettle / sink / basin,
stool / climb for too-high props, Bellows' other activities, A30–A33 as lint rules, eyes-lead look for all
looks — see §10. They matter only if the Night game comes back.
