# r3d-rig — the 3D character runtime, looked at

Everything here was rendered with the game's own `RigPlayer3D` (char_toon + outline from `r3d-view3d`, the cast's
landed `hush.glb` / `bellows.glb` v0, r3d-sets' RoomShell3D kitchen greybox, 1200×540 unless noted). Where no baked
clip existed yet (Bellows), look A's look-dev actions were played through `ClipLib3D.load_glb_action` (dev only; their
scale keys are dropped). Regenerate: `tools/scripts/anim_sheet3d.sh`, AnimViewer3D flags (`--help`), the commands below.

| Artefact | What it shows | What to judge |
|---|---|---|
| `viewer_bellows_kitchen.png` | AnimViewer3D `--rig=bellows --pose=rest --cam=game --room=kitchen --x=14.7`: Bellows (T-pose) at base framing, face preset `pompous` on the face card, outline, CHAR layer | The first light of the real cast on the runtime: 242 px tall ≈ the 236 px spec; face cells land on the card |
| `faces_hush.png` | `anim_sheet3d.sh hush --faces`: all 26 Hush presets driven through `FaceCards3D` → `face_cell_a/b` | Every preset resolves (no blank layer); pupils hide on closed / squint eyes; sneak ≠ smug, fear ≠ shock (cast's call) |
| `faces_bellows.png` | the same for Bellows' 45 presets incl. the `lids` layer | Lids, spiral eyes, extras (sweat, tears, vein) all reach the card |
| `turntable_hush.png`, `turntable_bellows.png` | `--turntable`: front / 3/4 / side / back, rest pose | Nothing missing or inside-out from any side; the face card on the head |
| `turn_hush.png` | `--flip-every=60`, every 2 f from f56: the 6-frame turn right → left at cheat 35° | The turn goes through the camera side (f 62 faces us), no pop, the face never goes edge-on; mirrored cells swap at the turn's midpoint |
| `stone_hush.png` | `--stone-at=20`: the marble statue in 0.1 s | Everything goes stone white except the beret and braces (the cast's COLOR.g keep mask); the ink outline stays |
| `tint_bellows.png` | `--tint=0..4 --face=furious`: temper tiers 0–3 + livid | Peach → beetroot reads as a meter; livid puts the specs on (`tint.livid_specs`) |
| `lookat_hush.png` | top: no look-at; bottom: `--look-at=2.5,1.9,0.5` | Head turns (clamped ±35° / ±20°) and the pupils follow the point |
| `walk_stop_bellows.png` | a walk, then `--then=glb:Toy_Idle_Loop` at f 60 (8 f cross-fade), every 6 f | The base cross-fade has no pop; the bouffant springs are subtle (stiffness 2.2) — see `test_jiggle_3d.gd` for the measured swing / settle |
| `launch_bellows.png` | `--prop=teacup:held,saucer:held --launch=teacup@20:1.2,3.2,0.4`, every 3 f from f 14: the teacup leaves the hand on a `PropSim3D` arc (gravity 9.8 × 1.6, restitution 0.3, spin 540°/s) | It leaves from where the hand is on f 20 (no pop), arcs up and toward the camera, bounces once and then rests; the idle loop's wrap does not snap it back home (flight time is on the view clock). Under xvfb the view dt is > 1/60 on a loaded box, so the arc spans fewer captured frames than it will on a device |
| `sheets/loco_walk_contact.png` | `anim_sheet3d.sh hush hush/loco_walk --room=kitchen`: r3d-anim's first baked clip, a cell every 3 f in an orthographic profile, step events under their cells | Reads like the 2D contact sheets: the sneak's knee lift, the contact frames at 0 / 27 |
| `sheets/loco_walk_phone.jpg` | the same clip at TRUE phone scale (1× crops of the 1200×540 game framing, cheat 35°) | Hush is ~215 px tall; the face card is readable while she walks |
| `sheets/loco_walk_onion.png`, `_curves.png`, `_sil64.png`, `_lint.txt` | onion (blue → red, dots on head top / hands / pelvis), bone angle + angular speed curves, 64 px silhouettes (review/sil64.py), r3d-anim's 3D lint through the sheet script | The pipeline end to end; the foot curves show a ~15°/f foot-rotation step at the plants (f 26 / 53) — r3d-anim's call |
| `capture/hush_walk.gif` (+ `_mute`, `_strip.png`, `_events.json`) | `capture.sh` on AnimViewer3D with the new `capture3d.gd` hook: 360 frames, turns every 120 f | Every RigPlayer3D step event is logged on its movie frame (clip f 0 → movie f 1, f 27 → 27): the capture hook works on the 3D player |

Measured (report §Verification): RigPerf3D `hush/loco_walk` median of 5 runs = **189 µs / frame** (p95 ≈ 282 µs) on a box at load
average 5–7 on 4 cores; the same player headless in the test suite: 27 µs. 9,838 triangles, 48 deform bones, 2 draw calls.
