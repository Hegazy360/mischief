# Review: `s2-rig` — overlays, decor events, lints A23–A29, animator tools, lazy looks, per-character CPU

Every image is the game's own `RigPlayer` (AnimViewer, anim sheets, RigPerf, or the real game under
`capture.sh`). Shots are 1200×540 (a 20:9 phone). Scratch copies and the full captures are in
`<SP>/work/s2-rig/`.

## Overlay clips (micro-gags over a walk)
| File | What it shows | What to judge |
|---|---|---|
| `overlay_strut_conduct_strip.png` | Numbered frame strip (every 3 f, f8–f80) of `bellows/mg_conduct_air` (overlay, mask `upper`) over `bellows/loco_strut` in the kitchen, from `capture.sh` on AnimViewer. The arm rises into the conduct from f11 to f17 and drops back from f56 to f62. | The blend in and out is smooth, with no pop. The legs keep the strut's cadence and the feet keep their plant under the gag. |
| `overlay_strut_conduct.gif` (+ `_mute`, `_sync.json`) | The same run as a 30 fps GIF with the sound strip; `--blips` beeps on each sfx event. The sync report puts every onset at 0–2 f from its event. | The steps and the baton swish land on their frames. |
| `sheets/mg_conduct_air_on_loco_strut_contact.png` (+ `_phone`) | `anim_sheet.sh bellows mg_conduct_air … --base=loco_strut`. Each cell draws the base-only pose as a **blue ghost** under the overlaid pose. | Only the head and arms depart from the ghost; the legs and feet coincide with it. |
| `sheets/cue_doorframe_bonk_2rig_contact.png` (+ `_phone`) | A two-rig sheet: `--rig2=hush --clip2=act_snicker --x2=300`, with rig 2 drawn in every cell. The bonk is also an overlay, so it has the ghost. | Both rigs sit on the same frame, and cells widen to fit rig 2. |

## AnimViewer in the real sets
| File | What it shows | What to judge |
|---|---|---|
| `room_parlour_bellows.png` | `--room=parlour --rig2=hush --x2=-420`: Bellows (idle) and Hush in the parlour at game scale, with the kitchen continuing to the right. | Bellows' plum reads on the parlour rose (yes: the dark ink outline carries it), and Hush's black and white reads on the piano. |
| `specs_on_nose.png` | `--station=st_tea --prop=specs:on --zoom=1.8 --clean`: `set_prop_state("specs","on")` re-attaches the specs through `state_sockets` from the chain to the nose. | The specs sit on the nose, above the face (`state_z_offset`). |
| `pip_clarence.png` | Hush and Pip (`--skin=pip`) side by side on `idle_fidget_clarence` f40. Clarence is on `hand_r:grip` at `z_by_socket` 20, behind the glove fingers. | Pip has teal sleeves and denim legs (the skin's limb fills). Clarence tucks behind the glove. No stray smear ghosts: this shot found a real bug, where ghosts from `smear` events on non-auto clips stayed stuck at the feet. It is now fixed and tested. |
| `feathers_on_arm_bones_choo.png` | `rx_sneeze_blast_a` f95 (the CHOO) with `--looks=FEATHERED --zoom=2.2`. FEATHERED's overlays sit on the invisible arm limb bones. | The feathers follow the arm bones (art-bellows request 2). The rocket pose reads, and the stool rides under him. |
| `viewer_ui_take_pip.png` | The viewer UI with a fixture take at f24 in the kitchen, Pip as rig 2, the beat bar and the event ticker. | Both rigs render (s2-rig renders every part as its own canvas item) and the UI is legible. |

## capture.sh on the real game
| File | What it shows | What to judge |
|---|---|---|
| `g0_capture_sneeze_strip.png` | `capture.sh res://scenes/boot/Boot.tscn 2400 … -- --e2e --e2e-scenario=g0_sneeze` with `STRIP_RANGE=1140-1236`. The strip covers Boot → NightScene (frame 3) → the tea → the build-up → CHOO at **f1167** (the ACHOO-RIA! caption) → the stool ride into the sink (f1185) → the stool decor reappearing (f1233). | This is the real game: HUD, Stalls silhouettes and hidden eyes in the pantry. From the log: 96 clip sound events matched to a started sound, 95 of them at 0 f and 1 at 2 f. The 3 `vase_nudge` repeats were dropped by the Audio repeat guard. |

The 40 s GIF fits 4 MB after automatic reduction to 320 px and 20 fps; the reductions are printed on stderr. It is in the scratch folder (`<SP>/work/s2-rig/g0/`), not here, because the orchestrator's `docs/review/gate0/` is the official copy. `CaptureStub.tscn` is a two-scene stand-in that plays game sounds through the Audio autoload. It showed the log is frame-exact: `slide_up`, `thud` and `boing` at 0 f.

## Perf (RigPerf `--perf-log`, medians per character, 2 characters; shared 4-core VM)
| Clip | Stage 1 | Now (`nice -15`, `LP_NUM_THREADS=1`, load < 1) | Now (tight-loop on-CPU, `rig_profile.gd`) | Draw calls |
|---|---|---|---|---|
| `hush/loco_run` | ≈ 0.33 ms | **0.24–0.29 ms** | 0.145 ms | 5 |
| `bellows/loco_strut` | ≈ 0.39 ms | 0.31–0.36 ms | 0.154 ms | 4 |
| `bellows/rx_sneeze_blast_a` | — | 0.34–0.41 ms | 0.19 ms | 6.5 |
| `_mannequin/loco_walk` | 0.26 ms | 0.23 ms | — | 5 |

Wall-clock runs vary by ±30 % from run to run on this machine, even when it is quiet, because llvmpipe's render threads compete with the main thread. The pre-gate should run RigPerf alone with `LP_NUM_THREADS=1`. `--breakdown` prints µs per section.

Memory: Bellows' base atlas at 2× is **10.2 MB with mipmaps** (Stage 1 built all 29 MB at setup). Each residue look is a lazy page of 0.1–2.5 MB. Hush is 4.7 MB.
