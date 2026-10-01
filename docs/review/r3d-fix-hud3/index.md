# r3d-fix-hud3 — fix round 2 (HUD side): attached badges, one ring per target, the pickle jar, the kettle duet, the first overlay show

QA round 2 (`docs/review/r3d-qa/readability.md` "Round 2") failed crowding 2/8 "yes" and put the spot test exactly at
its bar. This page shows what the HUD side changed for the rows assigned to it — **Q2-C1** (crowd pkt_04, P00 frame
2190), **Q2-C2** (crowd pkt_07, N1 frame 6768, HUD side), **Q2-S1** (spot pkt_03, the pickle jar), **Q2-S2** (spot
pkt_01, the kettle that still needs the squeaker) and **16(a)** (WorldOverlays.apply at its first busy frames,
t255–263).

Every **before** image is the packet frame the round-2 reviewer judged (`docs/review/r3d-qa/packets/`). Every
**after** image is shot from this tree on the same route and frame as r3d-qa's `shoot_r2.sh`: 1200×540,
`--no-captions`, MSAA off (`E2E_MSAA=off` / `--msaa=off`), one Godot process at a time (sandbox
`r3d-fix-hud3-shot`). Scripts: `<SP>/work/r3d-fix-hud3/{shoot.sh,perf.sh,board.py,d182.py}`.

## What changed (HUD files only)

| Rule | Where | What the player sees |
|---|---|---|
| **Attached badges** (Q2-C1) | `game/ui/world/overlay_placer.gd` (`request_attached`), `world_overlays.gd` | A preview badge never floats off its prop. It stays within `DETACH_MAX` = 80 px (1080 base) of its *stalk* (the preview anchor → the top of the prop's visual bounds) or of the prop itself. When the HUD band (APPLAUSE + RUNNING GAG) or a face blocks its own spot, it first slides only as far as keeps it over its prop, then takes a spot **beside the prop's top** (the side away from Hush first), then waits. Before, it slid up-left by up to a cloud width and 150 px and ended next to the meter, ~200 px off the gramophone. |
| **Tails to the prop** (Q2-C1/C2) | `preview_cloud.gd` (`set_tail`), `world_overlays.gd` (`tail_target`) | The tail is a chain of shrinking thought-dots (2–4) from the cloud to the **prop's top edge**, not two dots into the empty air above it. A chain that would run through another overlay keeps the short tail (two stacked props must not read as one chain). |
| **One countdown ring per target** (Q2-C1/C2) | `world_overlays.gd`, `hud.gd` (`set_his_ring_on_prop`) | The prop's badge carries his red countdown ring; his own bubble then shows the icon only (through `FxThoughtBubble.ring_hidden`, request **R1**, landed by r3d-fix-night2) and the Bellows-window chip drops its ring. A bubble that cannot drop its ring keeps it and the badge then draws **no** ring — one ring on screen either way. |
| **Pickle jar** (Q2-S1) | `game/art/ui/previews/in_a_pickle.svg` | The jar is the hero: clear glass, two fat bumpy green gherkins and two pickled onions behind it, a red ridged screw lid with a twist arrow, his red straining face (gritted teeth, sweat) over its shoulder and both hands wrenching. |
| **Kettle duet** (Q2-S2) | `game/art/ui/previews/kettle_drum.svg` | The joke is the duet: the kettle's note from its spout and **his** sung note (eyes shut, mouth wide) beamed together over them; his note cracks (red zig-zag). Before it was a kettle with a red crack and two notes — read as "a honk that startles him". |
| **"Fetch it first" slot** (Q2-S2) | `preview_cloud.gd` | The needs state is an **empty slot**: a dashed ring with the missing item's faint silhouette and a gold "?", not a solid grey horn stuck on the joke ("rigged with a honking horn"). |
| **First show primed** (16(a)) | `world_overlays.gd` (`warm_first_show`, called by `warm`) | Nothing visible: under the curtain every placer item is pooled and solved once and one overlay of every kind is drawn at 1 % alpha for 2 frames; the placer's per-item search now only looks at the blockers near the item (a waiting badge used to test every protected × hard × item rect per candidate). |

The pictogram ids are unchanged (`previews.json` untouched), so content's `test_view_data` stays green. The
generator `game/art/ui/_src/gen_previews.py` carries both new drawings (`--only=kettle_drum,in_a_pickle`; a full
run would rewrite r1's hand-edited `achoo_ria.svg` from the older function).

## Before / after

### Q2-C1 — crowd pkt_04, P00 frame 2190
`crowd_p00_t2190_board.jpg`, zoom `crowd_p00_t2190_zoom.jpg`, after frame `crowd_p00_t2190_after.png`.

What I saw: before, the record "×3" badge with his red ring floats beside the APPLAUSE meter, ~200 px above the
gramophone, with no tail to it, while his bubble shows a second red ring for the same gramophone (and his glyph + ear
pips beside it). After (final tree, with r3d-fix-night2's `ring_hidden` and glyph change in): the badge sits right
beside the gramophone's horn (its left, away from Hush), clear of the meter and the RUNNING GAG fuse, its tail on the
horn and the ONE red countdown ring on it; his bubble shows the gramophone icon only. `crowd_p00_t2190_fallback_ring.png`
is the same frame before `ring_hidden` existed: one ring then too, on his bubble, the badge plain.
Noted for r3d-fix-night2 (not my file): his cloud sprite's right lobe is cut flat (visible now that the glyph disc no
longer covers it — it is in the QA packet too).

### Q2-C2 — crowd pkt_07, N1 frame 6768
`crowd_n01_t6768_board.jpg`, after frame `crowd_n01_t6768_after.png`.

What I saw: before, two red countdown rings for one target (the kettle preview and his tea thought), his spectacles
glyph squeezed onto the pantry top and the pickle jar on Hush's head line. After (final tree): ONE red ring, on the
kettle's duet badge, whose dotted tail runs down to the kettle; his tea thought shows the cup only and no glyph
(r3d-fix-night2); the jar shelf sits clear of her head (r3d-fix-gags2). `crowd_n01_t6768_fallback_ring.png` is the
same frame before `ring_hidden` existed (one ring, on his thought).

### Q2-S1 — spot pkt_03, N1 calm route t360 (the pickle jar)
`spot_n1_calm360_board.jpg`, after frame `spot_n1_calm360_after.png`, pictograms `pictograms_before_after.png`.

What I saw: every preview of the kitchen now has a dotted chain down to its own prop (the pickle cloud's chain ends on
the jar, the kettle's on the kettle, the tap's on the tap); the spice shelf's preview, whose prop is hidden behind the
kettle's cloud, keeps the short tail. The new pickle pictogram reads as a jar of green pickles with a red lid and a red
face at 39 px; the 3D jar itself is still the green polka-dot pot (request R3).

### Q2-S2 — spot pkt_01, N1 needs route ≈ t5219 (the kettle that still needs the squeaker)
`spot_n1_needs_board.jpg`, zoom `spot_n1_needs_zoom.jpg`, after frame `spot_n1_needs_after.png`.

What I saw: before, a teal kettle with a red crack and two notes, a solid grey horn badge stuck in the cloud's corner
("rigged with a honking horn … startles him"). After, the duet (the kettle's note and his sung note beamed together,
his face singing) at 75 % while it waits, the squeaker in an empty dashed slot with a gold "?" on the cloud's shoulder
(outside the pictogram — my first try put the slot over his singing face; moved), his ring on the badge and a dotted
tail to the kettle. The Bellows-window chip (top right) shows the cup without a second ring.

## 16(a) — verified under D18.2
The pre-gate row-16 commands (`prologue_ideal --perf-log -- --view3d-prof`, 3 rendered + 2 headless, one at a time),
judged with `<SP>/work/r3d-fix-hud3/d182.py` (r3d-qa's `d17.events`, D18.2's three clauses). Runs:
`<SP>/work/r3d-fix-hud3/prof/{a1,a2}/` (a1 = this work before r3d-fix-night2's placer wiring; a2 = the final tree).

| | QA round 2 (`build/r3d/prof`) | a1 (18:30Z) | a2 (19:02Z, final) |
|---|---|---|---|
| NightScene > 1 ms at t255–263 | r1 1.39 · r2 1.82 · r3 1.15 · h1 4.55 — **3 of 3 rendered + headless** | none (r2 1.10 at t251, alone) | none (r1 1.52 at t256, alone) |
| ov_apply in those frames | 0.88 / 1.09 / 1.11 ms, h1 4.37 | ≤ 0.66 rendered | ≤ 0.98 rendered |
| D18.2 match in t240–280 | t257–263 (deterministic) | t269/271 r2 1.06 + h2 1.87 (one rendered + one headless) | **none** |
| ov_apply p50 / p95, rendered | 0.35 / 0.55–0.56 | 0.41–0.42 / 0.65–0.73 | 0.44 / 0.67–0.68 |
| ov_apply p50 / p95, headless | 0.26–0.28 / 0.42–0.45 | 0.32 / 0.53–0.54 | 0.38 / 0.58–0.62 |
| view+HUD p50 / p95, rendered | 3.09–3.13 / 4.66–4.88 | 3.32–3.42 / 5.15–5.60 | 3.39–3.44 / 4.98–5.02 |

The first-busy-frames cluster is gone in both batches. The steady overlay cost rose by ~0.06–0.1 ms p50 (the attach
geometry, the tail checks, and in a2 his bubble + captions now going through the shared placer); view+HUD p50 is close
to the 3.5 ms bar on this box — most of that rise is outside the overlays. The overlay probe (`--ov-dump`) shows where
the remaining > 1 ms overlay frames come from: the first bone query of a frame (face boxes / Hush's head →
CharacterView3D.head_world → the rig's head_global) and WorldView3D.protected_rects — request R5.

## Tests
`game/tests/ui/test_crowding_qa2.gd` (new): the P00 badge attached at 20:9 / 16:9 / 4:3 (beside the prop at 20:9 and
16:9), every shown badge within `DETACH_MAX` under a wide band, the attached order + never floating + unattached items
unchanged, segment / rect distances, attached placing allocation-free, one ring per target (a ring-hiding bubble /
today's bubble / bubble off screen), the Bellows-window chip, the N1 kettle tail at 3 aspects, the tail target, a tail
never through another cloud at 3 aspects, the needs slot draw, the first-show primer (pools every item, hands the
nodes back, no Item made on the first show; a primer without frames).

## Requests to other owners (full text in `<SP>/work/r3d-fix-hud3/LANDED.md`)
- **R1** (r3d-fix-night2, `thought_bubble.gd`): `FxThoughtBubble.ring_hidden` — **landed** by r3d-fix-night2 during
  this round; WorldOverlays sets it every apply. Without it the HUD keeps one ring on his bubble (tested).
- **R2** (NightScene): wire `world_view.overlays.placer = overlays.placer` — **landed** by r3d-fix-night2; his bubble
  and the captions now go through the shared §2.5 placer in a real Night.
- **R3** (r3d-sets / r3d-fix-gags2): the 3D pickle jar is still a green polka-dot pot — make it a clear jar with green
  gherkins and a red lid like the pictogram.
- **R4** (r3d-docs / orchestrator): REDESIGN §2.5 / §4.1 / §4.2 text for attached badges, the tail chain, one ring per
  target and the empty "?" slot.
- **R5** (r3d-view3d / r3d-rig): the first bone query of a frame (head_world → rig.head_global) forces the skeleton
  update inside whoever asks first — cache the head/top points after the rig's own apply.

## Dev probe
`--ov-dump=/abs/file.jsonl [--ov-dump-frames=a-b] [--ov-dump-slow=µs]` (user args after `--`): WorldOverlays appends
one JSON line per slow apply (default ≥ 400 µs) and per apply in the frame window — the per-step µs split and the
placer's items (want / rect / anchor / prop rect / beside spots / side / detach / visible), protected, hard and safe
rects. Zero cost when off.
