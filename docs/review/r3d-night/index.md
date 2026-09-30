# r3d-night — the Night, curtain call, Gag Reel and stage door on the 3D view

Everything here is the real game (`Boot`/`NightScene`/`StageDoor` with the 3D view, the default since 18:34Z, ruling R1),
rendered on the 4-core CPU box under llvmpipe at **1200×540** (20:9 phone held sideways; logical 2400×1080), MSAA off
for the timing runs (R11). Cast, clips and sets are whatever `r3d-cast-*`, `r3d-anim*` and `r3d-sets` had landed by
19:40Z — the Bellows clips still missing are played by the view's fallback (counted, see the e2e table).

| Artefact | What it shows | Verdict after looking |
|---|---|---|
| [g0_route_strip.jpg](g0_route_strip.jpg) | `e2e.sh g0_sneeze` (fixed 60 fps), every 48th frame: the 2D curtain rise, Hush's climb-in, the squeak lesson, the honey with the gold ring + LIVE RIG button, the dotted path to the pantry, the dive, Bellows at the tea in the Bellows window, then in the kitchen, the CHOO (punch-in, caption, Stalls), the curtain call with **Again ▶** | calm; one loud call to action at a time (the action button or the tray), every tap answered by the ring + path; the Bellows window only while he is off screen |
| [g0_curtain_call_strip.jpg](g0_curtain_call_strip.jpg) | the g0 call: the fall, the results panel, the **Gag Reel 3D** re-staging the recorded CHOO in its slot (first frame at once), Again ▶ and Stage door live | the reel frames Bellows' chest and follows him onto the stool and into the sink; the caption appears after the accent |
| [p00_route_strip.jpg](p00_route_strip.jpg) | `e2e.sh prologue_ideal` (real time, launch clock), every 30th frame: kitchen → parlour, the Figgis card cue, the lever sparkle, ALLEGRO-GO-GO!, the running gag, the curtain with Retry / Night 1 | reads end to end at the base framing; the room dimming carries "where the action is" |
| [p00_curtain_call_strip.jpg](p00_curtain_call_strip.jpg) | the P00 call: the fall, **3D bows** in front of the 2D curtain (Hush walks in and bows under the roses, the title slams over her, then Bellows wanders on, turns red in the slow burn and the valance drops on his head), results + the Gag Reel (ACHOO-RIA! in the kitchen, then ALLEGRO-GO-GO! in the parlour) | reads as the Stage-2 call with 3D actors; Hush is ~55 % of the frame height at the lip, Bellows (upstage band) ~40 %; the title covers Hush's torso for its 1.2 s hold |
| [stage_door.png](stage_door.png) | the stage door with `show_previews: false`: Gate 0, Prologue, **Cast**, "Gate 0 · Hush, B's head", "Gate 0 · Hush, head ×1.2" (r3d-cast-hush shipped `head_b`), the A/B launches and pages, Device log; **no Night 1 / Night 2** | as specified; the head buttons never say "head A / B" |
| [cast_page.jpg](cast_page.jpg) | Stage door → Cast in 3D: Hush and Bellows on the lane at the base framing; Next = idle → snicker → freeze (marble + stone plinth) → take (`bellows/rx_sneeze_blast_a` frame 94 held); Turn rotates both 45° | missing clips are labelled "(… not in yet)"; the plinth glb rendered as a black disc until the page gave it the set shader in stone (request to r3d-view3d for the in-game plinth) |
| [gate0_card.png](gate0_card.png) | the Gate-0 3-icon card over the curtain: the honey jar and the pantry curtain rendered live from the game's `Prop3D` with their glow, the LIVE RIG button (gold disc + glove + filling ring) | after looking: the honey thumb was cropped (bottle cut, jar on the bottom edge) → wider framing; the glove was missing (`UiIcons.get_icon("rig")` has no file) → `hand_rig` |
| [g0_hud_off_no_captions_strip.jpg](g0_hud_off_no_captions_strip.jpg) | `NightScene --hud=off --no-captions` from tick 1100: the CHOO with no HUD, no world overlays, no Stalls and no caption (r3d-qa's caption-free packets / set shots) | the flags hide exactly those; the curtain call's own panel still shows (it is not the world) |
| [n01_preview_boot.jpg](n01_preview_boot.jpg) | Night 1 booted on the 3D view (`--no-curtain`, frame 60) — N1/N2 are previews behind the WIP card | boots and plays; at the rise every live prop shows its preview bubble at once (5 bubbles) — r3d-hud's OverlayRules, info for the N1 pass |

## Perf (desktop proxy, `--perf-log`, 3D, MSAA off; PLAY frames only)

| Route | draw calls p95 / max | tris max | emitters max | tex MB | shader compiles in PLAY | frame ms p50 / p95 | scripts p95 (view + HUD / sim) | build / warm ms | Bellows window share / longest |
|---|---|---|---|---|---|---|---|---|---|
| g0_sneeze (fixed 60) | 57 / 65 | 68.4k | 4 | 81.2 | **0** | 98.9 / 142.0 | 7.6 ms | 629 / 316 | 0.280 / 6.4 s |
| prologue_ideal | 72 / 80 | 92.8k | 4 | 103.4 | **0** | 101.0 / 131.7 | 9.2 (5.1 / 4.7) ms | 597 / 371 | 0.298 / 2.5 s |
| prologue_required | 71 / 83 | 92.9k | 4 | 103.4 | **0** | 102.6 / 150.4 | 10.5 ms | 564 / 378 | 0.380 / 4.5 s |
| prologue_slow | 72 / 80 | 92.9k | 4 | 103.4 | **0** | 93.7 / 116.6 | 9.1 (4.6 / 4.7) ms | 537 / 342 | 0.333 / 3.1 s |
| g0_sneeze headless (no rasteriser) | — | — | 4 | — | **0** | 3.2 / 6.4 | 4.7 (3.4 / 1.7) ms | — | — |
| budget (§6.3) | ≤ 150 / ≤ 250 | ≤ 150k | ≤ 8 | ≤ 250 | 0 | — | ≤ 4 ms (view + HUD) | ≤ 1500 / ≤ 1000 | warn > 35 % |

Draw calls, triangles, emitters, texture memory, compiles, build and warm are inside the budget. The view + HUD script
time is 4.6–5.1 ms p95 rendered (llvmpipe rasterises on the same 4 cores) and 3.4 ms headless; the device (O2 probe
APK) is the number that counts. (`prologue_required` is from the first pass, before the view/sim split.) `prologue_required` shows the Bellows window 38 % of
PLAY (> 35 % warning); the P00-ideal share that decides R15 is 29.6 %, so `bellows_window` stays `"sim"`.

## e2e in 3D (this task's runs; strict = `--strict`, R9 scope)

| Scenario | Result | Notes (owner of what is left) |
|---|---|---|
| g0_sneeze (rendered, strict) | ends g0_done, 0 script errors, 0 compiles; **strict red only on 9 Bellows clip fallbacks** | act_tea ×3, act_fixup_mirror, act_warmup, loco_blind_shuffle, mg_admire_in_kettle, mg_admire_reflection_horn, mg_walk_hum → r3d-anim-bellows-a/-b; 1 engine ERROR per Night from `stage_lighting_3d.gd:188` → r3d-view3d |
| prologue_ideal / required / slow (rendered, strict) | end to end (prologue_done), laughs by 60 s 7 / 4 / 7, slow: first laugh 4.3 s, first prank 25.3 s, 0 doubles, 0 compiles, every laugh cue staged with its crowd ≤ 0.27 s; **strict red only on 11 clip fallbacks** (latest ideal + slow) | bellows/act_hunt, loco_stomp, mg_admire_in_kettle, mg_admire_reflection_horn, mg_comb_flourish, mg_cravat_tug, mg_peer_under_piano, mg_walk_hum, mg_walk_scale → r3d-anim-bellows-a/-b |
| slice_all (headless, fixed 60) | g0, P00 ×3, n01_required/slow, n02_required/slow, n01_chase, n01_meltdown PASS; n01_ideal, n02_ideal, n01_caught red → fixed in r3d-night files and re-run | doubles: six 60 fps frames summed to 0.09999 s (1 ms slack); compiles: the lazily built freeze plinth (now warmed) |
| retry / pause_back / touch_smoke | PASS | retry 907 ms (wall 1024 ms, frame 112 ms) |
| curtain_call | PASS | P00 9.5 s → Next → N01 6.5 s, repeat 6.5 s → N02 → playbill → To be continued; g0 Again live in 356 ms |
| tap_accuracy (projected boxes, ±40 px) | PASS | every P00 / g0 live hotspot 20/20, 0 neighbours, 0 drags that moved; N01 / N02 (info) 20/20 |

Headless runs now project at the phone's 2400×1080 (their square viewport put Bellows off screen more often: window
share 0.42–0.55 → 0.17–0.27, in line with the rendered runs). The E2eProbe stamps a laugh cue and its crowd on the same
current-frame clock and takes the crowd from `AudioDirector.laugh` / `crowd_special` (the director's own clock lags a
frame inside the sim's `ticked`): the P00 "crowd after 0.32 s / 0.87 s" reds were those clock artefacts.

## Shader compiles during PLAY — how they are counted

Godot 4.7.2's Compatibility renderer reports 0 for every `RENDERING_INFO_PIPELINE_COMPILATIONS_*` counter even while a
never-seen shader compiles (measured: a 480 ms frame, `tests/night/CompileProbe.tscn`). `ShaderWatch` therefore counts
**first uses**: at the rise it records every shader the warm-up drew (MaterialWarm3D's registry + every material of
the Night's tree, particles also as their instanced variant); in PLAY, any registry key first registered and any shader
first seen on a visible instance (a tree scan every 60 frames) is a compile, plus hitches > max(50 ms, 2.5 × median).
A BaseMaterial3D counts by its feature set (Godot generates one shader per set and shares it), and every scene first
use records its node and material. Found and fixed: Prop3D builds the beret tag's material the first time a rig lands
(g0 tick 211) — the warm-up hangs every live rig prop's tag for its two frames; CharacterView3D builds the freeze
plinth at the first freeze (N01 caught tick 647, N02 ideal tick 6161) — the warm-up draws `NightWarmer.LAZY_SCENES`
and hands its keys to the watch. g0 and P00 since: 0.

## Notes from looking
- The curtain call bows render in their own transparent world (a stage-lip camera, two `RigPlayer3D`s) composited
  under the roses / title / valance; g0 has no bow step (fall → reel → Again), P00 and the Nights do.
- The Gag Reel re-poses both characters by clip + frame from `MomentRecorder3D`, puts every prop in that moment's
  state, lights their rooms and films through a camera like the live punch-in; it primes its first frame when the
  call starts, so the box is never empty. Its framing was loosened after the first look (focus 1.2 m up, distance ×0.82).
- At the P00 end the Retry / Night 1 buttons appear before the curtain has fallen — by design (Next live on frame 1 of
  the call, `curtain_call` flow `next_live_frame1`).
