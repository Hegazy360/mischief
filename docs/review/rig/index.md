# Review: `rig` — the cutout rig player, animation QA tools and the `_mannequin` proof

Every image here comes from the game's own `RigPlayer` and `RigSampler`, rendered by
`tools/scripts/anim_sheet.sh`, `tools/scripts/capture.sh` or `tools/scripts/shot.sh`. `mq_` means the
geometric `_mannequin` test rig. `hush_`, `bellows_` and `figgis_` are the character rigs other agents
delivered, run through the same tools.

## Mannequin: the rig
| File | What it shows | What to judge |
|---|---|---|
| `mq_rig.png` | Every texture laid out separately with a pivot crosshair and its name: part variants, face slots, residue overlays, the mug prop. Also the rig at rest, at every joint's minimum limit and at its maximum limit. | Pivots sit on the joints. The limits look anatomical, with no inverted knees. |
| `mq_poses.png` | All 59 poses (51 authored plus 8 mirrored walk poses), each with its name, tags, a note on its silhouette and a solid black 50 px silhouette. | Each pose reads from its black silhouette alone. The feet sit on the floor line. |
| `mq_poses_phone.png` | The same poses at true phone scale (0.5×). | Faces and hands are still readable at phone size. |
| `mq_residues.png` | The rest pose with each residue look: none, FRAZZLED (singed hat), SOAKED (wet hat and drips). | The looks are recognisable at a glance. |

## Mannequin: the five demo clips (all lint-clean: 0 errors, 0 warnings)
| File | What it shows | What to judge |
|---|---|---|
| `mq_rx_take_contact.png` | `rx_take`, one cell every 3 frames plus one per key. Keys are outlined red and hold-beat frames blue. Events are printed under each cell and the beat bar runs along the top. The clip: 12 f anticipation squash, a pop at f30 into a 3 f accent with smear ghosts, a 5 f hitstop and a cam punch, a 36 f moving hold with the hat on its spring, then a 21 f settle that collapses with a thud at f75 and overshoots once. | It snaps: a pose pop at f30 and no floaty in-between. The hold stays alive without drifting. The thud lands on the collapse key. |
| `mq_rx_take_contact_phone.png` | The same cells at phone scale. | The take still reads at phone size. |
| `mq_rx_take_onion.png` | Spacing dots for the whole clip (head top, hands, root), then one panel per beat with its frames overlaid, blue for earlier and red for later. | Dense dots into the accent, then a gap: that is the snap. |
| `mq_rx_take_curves.png` | Value per frame (ink) and velocity per frame (grey) for each channel that moves, with keys and their eases in red and beat bands behind. | Ease-in into the pop, a hard step at f30, a slow-in hold, and one overshoot in the settle. |
| `mq_rx_take_t3_contact.png` | Tier 3: the hold is stretched ×1.5 (36 → 54 f; total 108 f = 90 + 36 × 50 / 100). It adds a `prop fall` event, and the `beat_slow_burn` last beat is queued after the clip. | The hold is longer but keeps the same shape. The rest of the clip keeps its timing. |
| `mq_rx_take_sup_contact.png` | Suppressed: the settle (hold end → end) is replaced by the 60 f `beat_suppressed` clip (lips pressed, fists clenched). | The cut into the suppressed beat is clean, with no pop. |
| `mq_rx_launch_contact.png` | `rx_launch`: sip → anticipation → f27 jolt that launches the mug (attach at f0, launch at f27 with velocity [140, −1000] and spin 900). Hat spring kick, hitstop, cam punch. He watches the mug in the air; it lands at f82 on the flinch key, with `crash_small` on the same frame, then bounces. The cells widen automatically so the flying mug stays in its own cell. | The mug hits the floor on the flinch frame. The mug in each cell belongs to that cell. |
| `mq_rx_launch_onion.png`, `mq_rx_launch_curves.png` | Spacing and curves for `rx_launch`. | Same as for the take. |
| `mq_rx_launch_t2_contact.png` | Tier 2: the hold is stretched ×1.2. There is a shake at the hold start. | Events inside the hold keep their order. |
| `mq_rx_land_contact.png` | `rx_land`: a fall, then a squash to 0.70 / 1.30 at f10 with `thud_big`, a 6 f hitstop and a cam punch. A rebound to 1.15 / 0.87 (f13–23, `boing` at f17), then a dazed hold, then a settle. | The squash reads as weight, the rebound overshoots once, and the feet stay planted through the squash. |
| `mq_rx_land_onion.png`, `mq_rx_land_curves.png` | Spacing and curves for `rx_land`. | Same as for the take. |
| `mq_loco_walk_contact.png` (+ `_phone`) | `loco_walk`, a 48 f loop with stride_px 144 (180 px/s natural speed, which `RigPlayer` scales to the sim's speed), 2 steps. | Planted feet do not slide (plant lock). Arms move in counter-phase. Frame 48 loops cleanly into frame 0. |
| `mq_loco_walk_onion.png`, `mq_loco_walk_curves.png` | Spacing and curves for the walk. | Even spacing, with no hitch at the seam. |
| `mq_loco_idle_contact.png`, `mq_loco_idle_curves.png` | `loco_idle`, a 240 f loop with a weight shift at f100 and a look around at f130–175 (with a voice event), then back to stand. | It is alive but calm. |
| `mq_beat_slow_burn_contact.png`, `mq_beat_suppressed_contact.png` | The tier 3 last beat, a 70 f slow burn with a blink at f40 and a cross face at f46, and the 60 f suppressed beat, a trembling hold-it-in with a shake at f24. | They read without sound. |

## Mannequin: motion and sound
| File | What it shows | What to judge |
|---|---|---|
| `mq_take.gif` | 180 engine frames of `rx_take` looping in the AnimViewer, captured by Movie Maker (30 fps GIF). The **sound strip** under the picture shows loudness per frame in blue, detected onsets as orange ticks, the scene's sfx and voice events as labels, and a playhead. `--blips` plays a test tone per sfx event. | Sound onsets sit on the contact frames. The sync report says every event is −1 f, which is capture latency. The hitstop freezes visibly. |
| `mq_take_mute.gif` | The same frames without the strip (for the mute test pack). | The take reads without sound. |
| `mq_launch.gif` | `rx_launch` played once, with the sound strip (gulp, whoosh, land_soft, crash_small at the landing). | `crash_small` falls on the frame the mug lands. |
| `mq_viewer.png` | AnimViewer (1200×540, phone aspect) playing `loco_walk`. Rig, clip and pose menus. Info: frame, tier, stride and natural speed, keys, events. An event ticker, a timeline with key ticks and scrubbing, and buttons: play/pause, restart, step back and forward, T1–T3, SUP, FLIP, and one per residue. | The controls are big enough for touch, and the info panel is legible. |
| `mq_viewer_take_t3.png` | The viewer started with `--tier=3 --frame=40 --paused --residue=SOAKED`: the T3 beat bar shows the stretched hold (33–87) and `→ beat_slow_burn`, and the SOAK button is lit. | The flags from the launch arguments are reflected in the UI. |
| `perf_mannequin_x6.png` | The RigPerf scene with 6 mannequins alternating `loco_walk` and `rx_take`. | See the perf numbers below. |

## Character rigs (delivered by art-hush and art-bellows, not edited here)
| File | What it shows | What to judge |
|---|---|---|
| `hush_poses.png`, `hush_poses_phone.png` | All 59 Hush poses, labelled and at phone scale. | The mime's poses read from the silhouette. |
| `hush_rig.png`, `hush_residues.png` | Hush's exploded textures and joint limits, and her residue look (TOMATO). | Pivots, and the limits compared with what the poses actually use (see lint). |
| `bellows_poses.png`, `bellows_poses_phone.png` | All 80 Bellows poses. The cells size themselves to the widest pose (his belly and lunges). | Poses read at phone scale. |
| `bellows_rig.png`, `bellows_residues.png` | 141 textures, and 19 residue looks including costumes, sub-looks and the combos (chicken, dough_man, mad_maestro, poodle). | Each look is distinct. The tutu costume swaps in tiptoe slippers, which are packed on atlas page 2; drawing them exposed a runtime bug, now fixed and tested. |
| `figgis_poses.png`, `figgis_poses_phone.png`, `figgis_rig.png`, `figgis_residues.png` | Figgis, a window-bust rig with 5 poses. | — |

## Lint results (`sandbox.sh rig -s res://tools/anim/lint_anim.gd -- --all`)
- `_mannequin`: 7 clips, rig and poses: **0 errors, 0 warnings**.
- `hush`: 0 errors, 9 warnings:
  - `R04_mirror`: the hip offsets of leg_upper_r and leg_upper_l are (6.1, 5.2) and (−6.1, 5.2), so a mirrored walk cannot land the feet in the same place.
  - `R08_poses` (8 warnings): hand rotations of 120.7°–160.2° in h_tip_contact_l/r, h_tip_pass_l/r and h_near_miss, outside the ±120° limit.
- `bellows`, `figgis`: 0 errors, 0 warnings.

## Perf (RigPerf through shot.sh; a shared 4-core desktop at load ≈ 6–7, so the timings are inflated)
| Scene | Draw calls | advance + _draw CPU per character |
|---|---|---|
| 1 mannequin (walk / take with the prop) | 5 / 6–7 | — |
| 2 mannequins | 12 (budget ≤ 24) | 0.117 + 0.140 ms |
| 6 mannequins | 36 | 0.100 + 0.131 ms |
| 1 Hush | 5 | 0.100 + 0.226 ms |
| 1 Bellows | 4 (plus 1–2 while a page-2 variant is on) | 0.128 + 0.264 ms |

The headless test measures the pure sampler at ≈ 0.06–0.08 ms per frame for 21 parts and `RigPlayer.advance`
at ≈ 0.05 ms, with zero allocations after warm-up.

## Recipe for animators — Stage 2 (s2-rig; the Stage-1 recipe above still holds)
1. **Micro-gags are overlays:** `"layer": "overlay", "mask": "upper"` (a rig.json `masks` name or a part list), `blend_in`/`blend_out` ≥ 4 f (default 6). The root, the feet and their ancestors are never written (`"touch_legs": true` to allow), so the walk underneath keeps its planted feet. Lint A23 checks it.
2. **Watch it over the base:** `shot.sh res://scenes/dev/AnimViewer.tscn out.png 90 <sb> -- --rig=bellows --clip=loco_strut --overlay=mg_conduct_air --room=kitchen` (the overlay replays every `--overlay-gap` frames; `--overlay-at` delays the first).
3. **In the real set:** `--room=<id>` (house.json art at game scale, decor shown / hidden by your `decor` events), `--station=st_tea` or `--x=`, `--zoom=`, `--clean` for cast shots; `--skin=pip`, `--looks=SOAKED,COSTUME:jelly_helmet`, `--tint=2`, `--prop=specs:on`, `--part-tex=bouffant:flipped`.
4. **Two rigs:** `--rig2=hush --clip2=lec_dangled --x2=180 [--attach2=hand_r:grip,braces_loop:grab]` (the Lecture dangle, the HOT & COLD hand-off). `--help` lists every flag.
5. **House props in a clip:** `{"f": 92, "type": "decor", "id": "kitchen_stool", "visible": false}` hides the house sprite while your prop rides the gag (lint A28 checks the id against house.json).
6. **Lengths are contracts:** `bit_*` = its squeak bit's `len_f` ± 2 (A24), `mg_*` = its micro-gag's `len_f` ± 12 (A25), every sim-timed state / one-shot = the SliceClips `expect_f` exactly, or loops where the row allows (A29). Cold opens / curtain call (tag `cold` / `curtain`) may run to 420 f and hold 90 f (A26). Walks mapped with `speed_px_s` must not slide at that speed (A27).
7. **Sheets:** `anim_sheet.sh bellows mg_hum <dir> --base=loco_strut` draws the overlay over its base with the base-only pose as a blue ghost in every cell; `--rig2=hush --clip2=<clip> --x2=300` adds the second rig to every cell.
8. **Hear it, in game too:** `capture.sh res://scenes/boot/Boot.tscn 2400 out.gif -- --e2e --e2e-scenario=g0_sneeze` captures the real game with its own audio; every run writes `<out>_strip.png` (numbered cells every `STRIP_EVERY` frames — what reviewers read), `_sync.json` (each sound vs its onset, ± 1 f) and GIFs ≤ 4 MB.
9. **Lint strict before you hand over:** `sandbox.sh <sb> -s res://tools/anim/lint_anim.gd -- --all --strict` (the pre-gate: every WARN is an ERROR).
10. **Perf is shared:** `shot.sh res://scenes/dev/RigPerf.tscn out.png 600 <sb> -- --rig=bellows --clip=rx_sneeze_blast_a --perf-log` prints the per-character medians (≤ 0.25 ms, ≤ 12 draw calls); residue looks cost no memory until used (`RigPlayer.warm_looks` builds them under the curtain).
