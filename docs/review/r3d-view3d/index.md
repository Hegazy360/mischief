# r3d-view3d — review artefacts

The 3D world driven by the real sim through `ViewSnapshot` (WorldView3D + CharacterView3D + CameraDirector3D + the
Bellows window + decals / FX / overlays), rendered through `tools/scripts/shot.sh` at **1200×540** (20:9, the phone
held sideways; logical 2400×1080). No HUD in these frames (r3d-hud's layer is not wired in ViewSandbox3D); the Bellows
window is drawn with the sandbox's plain frame. Cast = the v0 rigs of r3d-cast-hush / r3d-cast-bellows with whatever
clips r3d-anim* had landed (Bellows had none yet: his static pose), set = r3d-sets' House3D.

| Artefact | What it shows | Verdict |
|---|---|---|
| [shading_a_vs_char_toon.png](shading_a_vs_char_toon.png) (+ [shading_look_a.png](shading_look_a.png), [shading_char_toon.png](shading_char_toon.png)) | O1: look A's look-dev Hush + Bellows in `toy.gdshader` next to the same glbs in `char_toon` (same camera, same face cells) | the same vinyl material; `key_front` 0.35 keeps the faces lit |
| [mock_plan_vs_3d.png](mock_plan_vs_3d.png) | REDESIGN V4 calm plan vs P00 tick 320: Hush sneaking to the honey (dotted path + destination ring), N1 glows (honey yellow, pantry blue), Bellows in the window | reads; the mock frames closer (its figures ~50 % of the height vs our 40 % spec) |
| [mock_rigging_vs_3d.png](mock_rigging_vs_3d.png) | V1 rigging vs P00 tick 400: Hush on Bellows' stool at the honey (reach z −1.4, body cheat ≤ 10°), sparkles | reads; rig progress ring is r3d-hud's (not in this sandbox) |
| [mock_armed_entry_vs_3d.png](mock_armed_entry_vs_3d.png) | V2 armed + entry warning vs P00 tick 740: the jar armed (lid askew, pepper puffs), Hush's eyes in the pantry curtain, the entry chevrons at the doorway, his bubble (tea, ring) | **the armed tag renders as a black ellipse** (House3D's tag glb keeps its lit import material in our unlit world — request to r3d-sets) |
| [mock_payoff_vs_3d.png](mock_payoff_vs_3d.png) | payoff vs g0 f112: `bellows/rx_sneeze_blast_a` (landed during this run) — he rockets back on the stool into the sink, the 1.4 punch-in, "ACHOO-RIA!" beside his head, the Stalls up | reads: the sim's landing frame, pelvis in the sink box |
| [bellows_window_mirror.png](bellows_window_mirror.png) | the Bellows window (400×225 logical) through the P00 hall: dark backstage (0.3) as he enters, lit 0.9 with him in it, at the mirror | lit and readable at 400×225; the mirror stand and his silhouette read |
| [g0_sneeze_strip.jpg](g0_sneeze_strip.jpg) … `_4` | the whole g0 sneeze with the real clip (reaction frames −26…211): the slow push through the tea, the punch on f94 with the pepper puff, the flight on the stool, the sink landing on f112, the hold, the climb down, the ease out | the push builds; the landing is on the sim's frame (pelvis inside kitchen.sink — a test); the caption sits beside his head and keeps its side; no bubble during the payoff; one stool (the house stool hides while the clip carries it) |
| [p00_night_strip.jpg](p00_night_strip.jpg) … `_6` | the whole Prologue on the ideal route, one frame every 20 ticks: Hush's entrance, the squeak ring, the path + destination ring, the stool rig with sparkles, the dive into the pantry (eyes), his entry chevrons, the tea at the stool, the sneeze, his exit, the Bellows window through the parlour and the hall mirror, her pop-out, the gramophone rig, ALLEGRO-GO-GO!, the piano hide | reads at 1200×540; room dimming carries "where the action is" |
| [perf_probe_card.png](perf_probe_card.png) | PerfProbe3D's summary card (desktop llvmpipe, 3 s runs) | the O2 device probe works end to end |
| [neighbour_strips.md](neighbour_strips.md) | the C1 neighbour-strip numbers per room / aspect and the C2 conflict | for the lead |
| [slice_clips3d.md](slice_clips3d.md) | `SliceClips.build3d(g0, p00)` — every clip the two Nights play in 3D, which exist | for r3d-anim* |

## Notes from looking
- **Iterated after looking at the sneeze:** the punch-in held him at the frame edge in the sink (C2 won over the
  focus) → the focus now stays in the middle 36 % (`GAG_FOCUS_MID` 0.18); the punch framed 20 % of dark pit under
  the stage → the aim rises so at most 0.35 m below the floor shows; the caption sat on his face and drifted off the
  top-left as the camera moved → captions are screen-space and re-placed beside his head every frame (above it when
  that clears the HUD band); his bubble covered the payoff → hidden while he reacts; it sat on his bouffant under the
  HUD band → it moves beside his head; he snapped out of the sink to the floor in one frame → the landing height eases
  back at 2 m/s; a seek into a reaction panned in from the camera's old position → a kept gag re-bases its start;
  with the real sneeze clip the caption hopped from one side of his head to the other → it keeps its side while it fits;
  the CHOO puff particles were white squares → untextured particles are round vinyl balls (`fx_toon.round_disc`).
- Characters are the spec size (Hush ≈ 185–210 px tall at 1200×540 in her tiptoe walk; spec 217 px standing).
- The Stalls rise on Hush's entrance, the squeak and the payoff and sink away at rest.
- Not yet rendered (no route or clip for them yet): the marble freeze + stare strip mock (no freeze on the ideal
  routes), the tea hand-offs (no `prop set:` events in the landed tea clip), the Bellows window in the lean mode (numbers
  only: `test_world_view3d` — g0 16.8 % / P00 9.4 % open vs 30.4 % in the sim mode), a run with noise rings.
- The armed tag is black (see the armed board) and Bellows' FRAZZLED bouffant reads as bald at game scale — both
  requests in the report.
- `d7_outline_p00_t300.png` (fix pass, 20:5xZ) — lead ruling D7 in game: P00 kitchen at tick 300, 1200×540, ViewSandbox3D on
  the real sim. Hush's ink 4.8 px @1080 (look A's 2.4 px @540), the live props' ink 3.4 px (honey jar + pepper pot with
  the gold halo, the pantry curtain with the blue halo), dressing (kettle, stool) without ink. Judge: does Hush read as a
  vinyl toy against the wall, and do the live props still separate from the dressing? (Bellows, in the window, is still
  3.5 px until his rig3d.json takes 4.8 — request in the report.)
