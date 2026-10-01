# r3d-integrate — review index

The real cast, clips and sets in the real 3D game; every Gate-0 / Prologue route and flow replayed; N01/N02 in 3D; the
2D path removed. Every image here was looked at (1200×540 phone scale unless noted). Report: `<SP>/reports/r3d-integrate.md`
(the orchestrator saves the task's final answer there).

## Tables
| file | what | judge |
|---|---|---|
| `requests.md` | every open request of the R3D reports / LANDED / the lead's queue: applied (A01–A32), closed upstream (U01–U25), deferred to R3 with the reason (R01–R18), this task's requests to other owners (Q01–Q02), refused (X01–X03), orchestrator items (O01–O09), the §3.1 checks | nothing open without a status and a reason |
| `reachability.md` | the 2D-path reachability scan: every file of the candidate trees, keep (the live file that reaches it, or the built path / tool that loads it) or delete | no kept file is 2D-only; no deleted file is reached |
| `deleted_files.txt` | the 537 files removed (+ their `.import` / `.uid` sidecars; 934 + 2 files in all) | — |

## Strips (`strips/`, `tools/art3d/review/strip.py`, numbered by sim tick, accents outlined red)
Shot in the real game at 1200×540 (`e2e.sh prologue_ideal --fixed` / `g0_sneeze`, DevShot `--shot-seq --every=3`; the
picture re-shot after A31 with `--seq-from=3255`), captions on (`<gag>.jpg`) and off (`<gag>_nocap.jpg`,
`--no-captions`); multi-page strips continue in `_2`, `_3`, `_4`. Cells are half scale (600×270), JPEG q62 (the folder
stays under 25 MB); the gag reads the same at full scale.
| strip | the gag (P00 ideal route ticks) | judge |
|---|---|---|
| `p00_vase` | the curtain-up vase (laugh_vase t138): it creeps along the mantel on his warm-up notes, tips and drops; the Bellows window shows him singing | small at phone scale (a mantel piece) — the Stalls and the window carry it |
| `p00_squeak_bit` | the first squeak → Bellows' warm-up bit (t230) | the squeak → his head snap |
| `p00_honey_rig` | ACHOO-RIA!: Hush on Bellows' stool shakes the set's pepper pot (white body, dark cap — A27) over the honey jar (t360–440) | the pot reads as the shelf's pot |
| `p00_wait` | the ⏩ wait in the pantry (her eyes in the curtain, ⏩ ×3 on the button) while he takes his tea (every 9 ticks) | tea is a routine, not a gag (D15) |
| `p00_sneeze` | the sneeze (accent t1375): the camera push, CHOO + ACHOO-RIA! caption, the flight with the stool, the sink landing, the flipped bouffant, the Stalls rise | the payoff |
| `p00_doorframe_bonk` | blinded, he shuffles into the door frame (laugh_doorframe t1677) | |
| `p00_dizzy_spin` | ALLEGRO GO-GO!: the gramophone at speed, the dizzy spin (accent t2659) | the second payoff |
| `p00_relief` | the relief beat (laugh_relief t3238) | |
| `p00_picture` | the picture frame drops from the wall onto his head (laugh_picture t3273), rides there face-on, askew, while he fumes (t3298–3345), then slides off (A31) | before A31 it slid on edge-on and vanished after 10 ticks; the frame is set dressing (muted against the pink wall) |
| `p00_curtain_call` | the curtain call: the title, Hush's bow, Bellows' wander-on / double take / slow burn / bonk, the reel (every 9 ticks) | |
| `g0_route` / `g0_sneeze` | Gate 0 whole (every 24 ticks) and the sneeze at 1 frame / 3 ticks (accent t1163) | |

## Boards (`boards/`, `tools/art3d/review/boards.py pair`)
The 2D reference frames are the orchestrator's pre-flight set from `main` (`docs/review/r3d-ref2d/`); the 3D frames
(`ref3d/`, JPEG, 20:9 and 16:9) were shot with the same command, episode, route commands, tick and aspect (`shot.sh
NightScene --episode --cmds --seek-tick`, 10 frames). Note: the sim keeps playing in real time for those 10 frames, and a
3D frame takes ~70 ms on this CPU proxy (the 2D one ~20 ms), so the 3D frames land ~30–40 ticks after the seek: the
48-tick honey rig is already over in `hush_rigging_honey` (Hush walks on to the pantry) — `strips/p00_honey_rig.jpg`
shows the rig itself.
| board | pair |
|---|---|
| `hud_2d_vs_3d.jpg` | the 2D HUD vs the four always-on pieces (pause, Script chip, Clarence, action) — P00 slow t415 |
| `kitchen_2d_vs_3d.jpg` | the 2D kitchen vs the 3D kitchen (N01 ideal t5400; the Prologue kitchen is the same set) |
| `tinker_2d_vs_pepper_rig.jpg` | the 2D tinker vs the pepper-pot band rig on the stool — P00 ideal t400 (see the note) |
| `pip_2d_vs_window.jpg` | the 2D PiP vs the Bellows window — P00 ideal t445 |
| `ref_moments_3d.jpg` | all ten reference moments in 3D at 20:9 (16:9 frames in `ref3d/`) |

## Numbers (the e2e reports on the final code; full table in the report)
| route | PASS | fallbacks | errors | pip_on_share | longest window | C8 violations | laughs by 60 s |
|---|---|---|---|---|---|---|---|
| g0_sneeze (strict) | yes | 0 | 0 | 0.280 | 6.4 s | 0 / 1413 ticks | 1 (one prank) |
| prologue_ideal (strict) | yes | 0 | 0 | 0.299 | 2.5 s | 0 / 3572 | 7 |
| prologue_required (strict) | yes | 0 | 0 | 0.383 (warning > 0.35, R15) | 4.5 s | 0 / 4050 | 4 |
| prologue_slow (strict) | yes | 0 | 0 | 0.333 | 3.2 s | 0 / 3713 | 7 (first laugh 4.3 s, first prank 25.3 s) |
| N01 ideal / required / slow (slice_all) | yes | 34 / 18 / 18 (R3 backlog, info) | 0 | 0.17 / 0.33 / 0.31 | | 0 | |
| N02 ideal / required / slow (slice_all) | yes | 60 / 22 / 24 (R3 backlog, info) | 0 | 0.20 / 0.16 / 0.15 | | 0 | |

Clip coverage: all 69 clips of `SliceClips.build3d(["g0_sneeze","p00_curtain_up"])` were played (`clips_played` of the
route, flow and coverage replays); 5 left the manifest because they cannot occur in g0 / P00 (A30, A32).
