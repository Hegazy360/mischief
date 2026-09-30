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
| [mock_payoff_vs_3d.png](mock_payoff_vs_3d.png) | payoff vs g0 f112: the 1.4 punch-in on him in the sink, "ACHOO-RIA!" beside his head, the Stalls up | reads; his pose is the static fallback until `bellows/rx_sneeze_blast_a` lands |
| [bellows_window_mirror.png](bellows_window_mirror.png) | the Bellows window (400×225 logical) through the P00 hall: dark backstage (0.3) as he enters, lit 0.9 with him in it, at the mirror | lit and readable at 400×225; the mirror stand and his silhouette read |
| [g0_sneeze_strip.jpg](g0_sneeze_strip.jpg) … `_4` | the whole g0 sneeze (reaction frames −26…211): the slow push through the tea, the punch on f94, the flight to the sink landing on f112, the hold, his climb down, the ease out | push builds, the landing is on the sim's frame (pelvis inside kitchen.sink — a test), the caption never covers his face, no bubble during the payoff |
| [p00_night_strip.jpg](p00_night_strip.jpg) … `_9` | the whole Prologue on the ideal route, one frame every 20 ticks | see the notes below |
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
  back at 2 m/s; a seek into a reaction panned in from the camera's old position → a kept gag re-bases its start.
- Characters are the spec size (Hush ≈ 185–210 px tall at 1200×540 in her tiptoe walk; spec 217 px standing).
- The Stalls rise on Hush's entrance, the squeak and the payoff and sink away at rest.
