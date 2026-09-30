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
