# r3d-sets — review index

The 3D sets of the slice (Prologue, Gate 0, Night 1, Night 2) in look A with the board's fixes, rendered with
`SetPreview3D` (`SetPreviewBatch3D` for the batches) at the base framing (CameraDirector3D C1). 1200×540 = a 20:9 phone
held sideways; 960×540 = 16:9; 1080×810 = 4:3. Characters: Hush and Bellows on the game's RigPlayer3D (`hush/loco_idle`,
`bellows/loco_idle`; at tea Bellows sits in the vendored UAL `Sitting_Idle_Loop` as a stand-in until his tea clip lands).
Measured with `tools/art3d/review/` (lab.py, sil64.py, boards.py). Ask of each frame: calm? Does the eye go first to the
characters and the one thing that glows? Can you tell what each lit prop is at 64 px?

| Artefact | What it shows | What to judge |
|---|---|---|
| `rooms/<episode>_<room>_20x9.png` | every built room of every slice Night, framed and lit (its neighbours dimmed at 0.78 + 40 % desat, backstage rooms at 0.3) | calm? one flat wall field + wainscot + rail, ≤ 4 dressing pieces, the live props readable as themselves |
| `rooms/<episode>_<room>_16x9.png`, `_4x3.png` | the same frames at 16:9 and 4:3 | nothing important lost at the narrower aspects |
| `rooms/<episode>_board.jpg` | one board per Night: all its rooms at 20:9 (half size) | the house as the owner will meet it Night by Night — P00 two rooms + a dark hall, N1/N2 four rooms |
| `rects/<episode>_<room>_rects.png` | tonight's live hit boxes (projected, logical px size printed; colour = verb) + the anchors (preview yellow, tag red, ring green, eyes blue, reach orange) | every box ≥ 144 px and contains its prop; the two stacks (kettle/honey, fridge shelf/door) separated |
| `props_states.png` | every live prop at game scale (1:1 crops of 1200×540): idle, rig 50 %, armed (+ Hush's beret tag), spent | is "armed" obvious from across the room? spent reads as used-up, not broken |
| `silhouettes_64.png` | every live prop as a 64 px mask, grouped by room, with the IoU matrix (≥ 0.80 = same family) | can you tell each prop from its shape alone? no pair in the same family |
| `before_after.png` | the 2D Prologue kitchen (r3d-ref2d) · the look-A look-dev diorama kitchen · the 3D Prologue kitchen | the owner's four complaints: less crowded, better characters, simpler house, clearer actions |
| `hide_eyes.png` | the three hiding spots occupied (pantry curtain, piano back, coat cupboard): the frame + a 2× crop of the eye card in the dark gap | only the eyes read; they look toward the lane |
| `value_map.png` | lab.py false colour of the Prologue kitchen with both characters (L* bands, C* bands, region medians) | walls mid-value low-chroma, the characters own the extremes |
| `tea_staging.png` | Bellows on his stool at st_tea (x 15.0) with the kettle and the honey jar; the ID pass with the measured visibility | kettle ≥ 60 % visible past his barrel, the jar clear of his bouffant |
| `reach_check.png` | `--reach=hush`: Hush on Bellows' stool under the jar (ACHOO-RIA!), Hush at the gramophone lever (ALLEGRO-GO-GO!) | every line green, no red box; Hush in front of the wing flat |
| `landings.png` | tonight's landing boxes + points: the sink basin (N1 kitchen), the log basket (N1 parlour), the coat stand (N2 hall) | each box sits on its host piece |
| `fix_pass.jpg` | lint fix pass (r3d-tools-b status.md 20:10Z): before / after of the P00 and N1 parlour (negative space), the N2 fridge zones (stack gap), the N1 porch | a plain 1.5 m of wall behind the characters' heads in every room but the N2 hall; the fridge's two zones read as two targets |
| `band_stands.jpg` | Hush at every N1/N2 band rig point's new `reach_pos` (placed target − the band clip's reach_offset), the band clip at a mid frame | her gloves on the prop and the prop beside her, not hidden behind her |

## Numbers (measured on these renders)

- **Values (lab.py `rules --rules=set`)** — lit walls: kitchen L* 67.8 / C* 22.1, parlour 66.1 / 14.8, hall 65.8 / 12.6,
  porch 70.3 / 18.9 (rule 62–76, ≤ 28); wainscot ΔL* 8.8 / 9.5 / 9.7 / 8.5 (8–10); floors L* 49.3–49.5 (40–50);
  dimmed neighbours 52.7–53.7 / C* 7.0–10.8 (45–58, ≤ 15); dressing C* ≤ 12.7, |ΔL*| ≤ 12.3 (≤ 30, ≤ 15; the pendant
  lamp exempt as the light source); characters PASS (Hush ≥ 85: 0.22, ≤ 40: 0.62; Bellows 0.32 / 0.36). The only FAILs
  are the wainscot rule applied to dimmed / backstage rooms (a lint request: §3.7 states it for lit walls) and the
  backstage hall at stage light 0.3 (by design).
- **Hit boxes** — every live box ≥ 163 logical px on its short side, ≥ 24 px from its neighbours in every framed room.
- **Silhouettes** — no pair of live props at IoU ≥ 0.80 (highest: pickle jar × piano back 0.80⁻, different rooms; pantry ×
  coat cupboard 0.77).
- **Tea** — Bellows seated at x 15.0: kettle 100 % visible, honey jar 100 % visible (ID-pass pixel counts with / without him).
- **Reach** — every rig point ≤ 0.50 m from Hush's nearer shoulder (P00/g0: honey 0.446 on the stool, gramophone lever
  0.384); no Hush or Bellows capsule hits a solid on any slice Night.
- **Budgets** — static draws ≤ 3 per room (the arch + static pieces merged into one mesh), lit-room triangles ≤ 20.5k
  (N1 kitchen, ink + halo passes counted), framed-room draw calls 20–39 without characters (≤ 45), set textures 6
  palettes of 256² (≈ 1.5 MB), `House3D.build` 21–76 ms.

## Fix pass (2026-09-30, lint3d status.md 20:10Z)

- **Negative space** (`lint3d --set`, head band y 1.1–1.8 m): P00 / g0 / N1 parlour 1.02 → **1.57 m** (x 9.88–11.45: the
  fireplace is 1.06 m wide at x 11.50–12.56 with the mantel 11.45–12.61, fire and portrait over it, the vase 0.23 m in from
  the mantel's left edge, the window 0.8 m at 13.21); N1 / N2 porch 1.40 → **1.60 m** (No. 9's door 0.7 m at x 0.2–0.9);
  N1 hall 1.499 (unchanged, passes). **N2 hall stays 0.68 m** — not fixable in the set alone (see the report addendum).
- **Stack** (N2 fridge shelf | door, projected hit boxes, every framing at 20:9 / 16:9 / 4:3): 5.6 → **36.8 px** (a 0.19 m chrome
  divider band 0.71–0.90 m between the doors; zone hit boxes [0, 0.71] / [0.90, 1.62] m, 0.12 m deep; shelf target y 0.95 kept).
- **Band stands**: every N1/N2 band rig point stands Hush beside the prop (placed target − the clip's reach_offset, z ≥ −1.6,
  collision-free): reach ≤ 0.490 m, no warnings (`band_stands.jpg`).
- Full `lint3d --set --screen` (renders, all Nights, three aspects): set 1 error (N2 hall negative space), colour rules all
  PASS; screen 0 errors.
