# r3d-qa: report (phase 3 of 3, ran alone)

**Verdict: FAIL.** Three rows are red, so R3D is not ready for the owner:
- **20a:** the APK still cannot start the game. The P0 fix from phase 1 is not applied.
- **16:** the D14 spike clause still fails.
- **19:** the readability review misses two bars, crowding (2/8) and the gags (3 of 9 strips at their bar).

Everything else passed in a full re-run alone: rows 1–15, 17 and 18, with row 8 kept because the sim tree is unchanged. The owner pack is drafted and held with a "not ready to send" banner.

Branch `r3d`, HEAD 5b5a135 plus r3d-qa's working tree. I switched no branches and ran no git writes.

## 1. Pre-gate (run alone, 09:43–10:36Z)
Command: `tools/scripts/pregate3d.sh --rows=1-7,9-18,20a`, then `--rows=19`. Content hash `eee8a789f5e192c7`; sim tree `c31a69aac4e0f8dd`, unchanged, so row 8 keeps its 08:38Z result. The record is archived in `docs/review/r3d-qa/pregate.json`.

| # | Row | Result | Numbers |
|---|---|---|---|
| 1 | Import metadata | PASS | 1010 .import, 409 .uid |
| 2 | Full suite | PASS | 1270/1270 passed, 0 failed, 0 skipped; 135 files, including the 2 `tests/slice` files; 322 s |
| 3 | Lints --strict | PASS | 72 clips strict: 0 errors, 0 warnings, 0 missing; coverage 72; content/hotspot/IP 0 failed |
| 4 | Validators | PASS | 5 validators, including gen_audio --check |
| 5 | Every route | PASS | 13 routes OK, 0 invariants, 0 catches on ideal; N01 ideal ★★★ 116.3, N02 ideal ★★★ 117.5; required ★ 44.0 / 59.3; g0 ends g0_done |
| 6 | Dead air (D1) | PASS | worst ⏩: ideal 8.1 %, required 4.8 %, slow 5.9 %; worst gap 5.47 s; edge share 0.221; N02 first prank 19.4 s |
| 7 | Planner proofs + g0 | PASS | --auto: n01 6 lines, n02 5, p00 2; g0 ideal 23.6 s → g0_done |
| 8 | Fuzz | PASS (08:38Z) | 2400 runs, 0 invariants, 0 soft-locks, 0 struck |
| 9 | Set lint | PASS | 0 errors, 1 warning: N02 hall negative space 0.68 m (D13) |
| 10 | Screen-rect lint | PASS | 0 errors, 1 warning: N02 hall clock under the window at 16:9 |
| 11 | HUD lint | PASS | 0 errors, 1 warning: window share 38.1 % on p00_required (R15) |
| 12 | C8 | PASS | 26 route × mode runs: 0 violations in sim, 0 in lean; sim window share max 39.0 % |
| 13 | Gate 0 in 3D | PASS | accent f94; zoom 1.14 at the accent, 1.59 max; hit-stop 83 ms; ACHOO-RIA!; bouffant flipped; lands in the sink; tag 1/1; C8 0; draws p95 57; tex 81.2 MB; 0 compiles; Again 234 ms |
| 14 | Prologue in 3D | PASS | ideal: 7 laughs by 60 s, 4 cues, crowd ≤ 0.269 s, 0 doubles; slow: first laugh 6.63 s, first prank 27.58 s, launch-relative |
| 15 | Other routes | PASS | 13/13, 0 script/engine errors; g0 + P00 0 fallbacks; N01/N02 14–60 per route (info) |
| 16 | Frame budget | **FAIL** | details below |
| 17 | Per character | PASS | Hush 0.195 ms, 2 draws, 9812 tris, 48 bones; Bellows **0.240 ms**, 4 draws, 9495 tris, 50 bones, plus the stool 1 draw / 450 tris reported apart (D16) |
| 18 | Flow / touch | PASS | retry 621 ms; tap feedback 1 frame; pause/back OK; tap_accuracy 20/20 on 6 slice hotspots (25 tested), 0 neighbour hits; g0 Again live; P00 Next live on frame 1 |
| 19 | Readability | **FAIL** | details in §2 |
| 20a | APK (local) | **FAIL** | details below |
| 20b | APK (CI) | pending the push | — |

**Row 16.** Every count passes:
- draw calls p95 ≤ 82, max ≤ 98;
- tris ≤ 101,392; 4 emitters; tex ≤ 103.4 MB;
- 0 shader compiles in PLAY;
- view+HUD p50 2.78–3.12 ms, p95 4.07–4.61 ms, which meets the D14 proxy bars of 3.5 / 8.0.

The spike clause fails: 14 of our nodes or phases are over 1 ms in the 60 slowest Prologue frames.
- NightScene 4.33 ms;
- AudioDirector 2.77;
- hush_apply 2.61;
- hush_view.mine 2.19;
- FxFreezeFrame 2.17;
- CameraDirector3D 2.13;
- bellows_apply 2.12;
- bellows rig_advance 1.87;
- Hud 1.85;
- hush rig_advance 1.29;
- props_cues 1.29;
- StallsView 1.24;
- bellows mine 1.22;
- rest 1.21.

Phase 1's run had 20 over 1 ms, worst 10.2 ms. This run's evaluator reads the profiler's real layout, so the FAIL is now recorded by the run itself.

**Row 17.** Two of the five Bellows runs were over 250 µs (263 and 259). The median passes.

**Row 20a.** The APK itself checks out:
- 73.42 MB (73,419,843 B), 3277 entries;
- 77 clip .res files and 80 sidecars; the excluded paths are absent;
- boot_config: stage_door / 3d / show_previews false / sim / render defaults;
- VIBRATE only, minSdk 24.

But the exported pack has 13 SCRIPT ERRORs, and the Night does not build: `world_view_3d.gd` still declares `var _prof: ScriptProf3D`.

Phase 1's evaluator fixes were exercised live and work:
- row 2 sees the slice files;
- rows 11 and 12 record the window-share and C8 numbers;
- row 16 reads the profiler's real layout.

## 2. Row 19 — scored (`docs/review/r3d-qa/readability.md`)
The file holds every answer verbatim and every key item (expected answer, gist, source frame). Each packet was scored with `tools/art3d/review/packets.py score` and then judged by hand on the gist. The matcher and the hand verdicts agree; the two answers the matcher left `unmatched` (spot pkt_06, pkt_07) are wrong on the gist.

| Test | Result | Bar | |
|---|---|---|---|
| verb | 7/8 | ≥ 7 | PASS. The squeak was read as "fiddling with something small and yellow". |
| spot | 6/8 | ≥ 6 | PASS. The pickle jar was read as a "tampered tea jar"; the sneeze bubble as "chilli, face burns red". |
| crowded_yes | **2/8** | ≤ 1 | **FAIL**: pkt_02 (g0 rig, ≈ t192) and pkt_06 (P00, ≈ t2190) |
| prefer_3d | 8/8 | ≥ 6 | PASS |
| gags (funny / readable / fresh) | 3 of 9 at their bar | | **FAIL**. Passed: g0 sneeze 4/4/3, P00 sneeze 4/4/3, curtain call 3/3/3. Failed: dizzy spin 3/3/4 (bar 4/4), picture 1/1/1, doorframe bonk 2/2/2, vase 1/2/1, squeak bit 1/3/1, relief 1/3/1. |

## 3. Request table (FAIL → an r3d-integrate re-run alone, plus the anim keys where a clip must change)
| # | Row | What was misread, and where | Change | Owner |
|---|---|---|---|---|
| P0 | 20a | The exported pack: `ScriptProf3D` is not declared, so WorldView3D fails to compile, followed by 12 more cascade errors, and `night FAIL` | In `game/view3d/world/world_view_3d.gd` lines 136/171: `var _prof: Object = null`, then `if ResourceLoader.exists(_PROF_PATH): _prof = load(_PROF_PATH).call("maybe_attach", self)`. Patch: `<SP>/work/r3d-qa/fixcheck/world_view_3d.patch`, verified as 0 errors and night OK. | r3d-view3d / r3d-integrate |
| P1 | 16 | D14 spikes (list in §1). Data: `build/r3d/view3d_prof.json` | Fix at the source: NightScene's own per-frame work, AudioDirector cue starts, the hush/bellows apply + rig_advance clip-start path, FxFreezeFrame, CameraDirector3D, Hud | r3d-view3d / r3d-rig / r3d-night / r3d-hud via integrate |
| Q-C1 | 19 crowding pkt_02 (g0 ≈ t192) | The ring, glowing jar and preview cloud pile onto Hush's head; the action button stacks the ring, ghost tap-hand and icon | While she rigs, the preview cloud moves clear of her head (or hides), and the ring stays on the reach target. The ghost hand stays off the button once the hold starts. | r3d-hud (`game/ui/**`) + r3d-view3d anchors |
| Q-C2 | 19 crowding pkt_06 (P00 ≈ t2190; honey ≈ t1059) | The preview badge runs into "RUNNING GAG ×1"; his thought cloud is clipped at the screen edge | Make the transient top-band rects (meter, banner) keep-out zones for OverlayPlacer; clamp clouds inside the safe rect, one at a time; add a layout test over the P00 route | r3d-hud + r3d-view3d |
| Q-G1 | 19 dizzy spin (t2659) | "Unclear why he starts"; read as forced conducting, not a spin | Stage him beside the gramophone, not in front of it. Show the record at speed (disc blur, notes jetting from the horn) at f18–36. Make the spin read in silhouette. | integrate/view3d (GagStager3D); r3d-sets (gramophone fx); r3d-anim-bellows-c (`rx_dizzy_spin_a` re-pose; timing locked) |
| Q-G2 | 19 doorframe bonk (t1677) | At the accent he stands at the pier, back to camera, arm raised; no contact reads | The head meets the pier on the accent frame, with a shake, dust and stars, then a dazed hold with his face to camera (D8) | integrate/view3d (CueStager3D); r3d-anim-bellows-c (`cue_doorframe_bonk`) |
| Q-G3 | 19 picture (t3273) | The fall is hidden behind the pier at the left edge; on his head the picture is a muted square; he walks on the spot through f48–138 | Frame the fall on screen; give the picture a gilt frame or ink edge; play a stunned/fuming hold clip instead of locomotion in place | integrate/view3d; r3d-sets (picture material) |
| Q-G4 | 19 vase (t138) | "No cause or effect": he is only in the small window, and the vase is tiny | Put the cause on screen (escalate the window, or show notes travelling to the vase); scale the vase as a live prop ×1.5 with a wobble beat | r3d-view3d; r3d-sets |
| Q-G5 | 19 squeak bit (t230); verb pkt_05 | His head snap happens only inside the window; Hush stands under the action button; Clarence is too small to read | Escalate the window or cut to him for the reaction; reframe Hush clear of the button; swell Clarence's prop bone on the squeeze and add a squeak ring at the beak | r3d-view3d; r3d-rig (socket scale); r3d-anim (`act_squeak`); r3d-hud |
| Q-G6 | 19 relief (t3238) | "A walk-off, not a gag": the near miss is not shown | Frame hidden Hush with him; add his relieved exhale with the face to camera; then the change of plan | integrate/view3d; r3d-anim-bellows-b |
| Q-S1 / Q-S2 | 19 spot (at the bar) | The pickle preview read as tea; the sneeze preview read as chilli heat | `jar_fight` pictogram: show the straining; the sneeze pictogram: head back plus the CHOO puff, and pepper dots on the white pot | r3d-hud (`game/art/ui/**`) |
| Q-V2 | 19 verb (note) | The dive was read as leaping *out of* the pantry (g0 ≈ t321) | `act_dive` should arc into the curtain, not toward the sink | r3d-anim; r3d-view3d |
| Q-N1 | owner pack | With `show_previews` false, P00's **Next ▶** opens Night 1 directly, with no WIP card | In the slice build, route Next to the WIP card or the stage door (`game/scenes/night/night_scene.gd` `_on_curtain_call_action("next")` / `BootRouting.next_episode`) | r3d-night via integrate (P2) |
| risk | 17 | Bellows median 0.240 ms, with 2 of 5 runs over 0.25 ms; 50 deform bones, exactly at the cap | Watch it at the next run, or trim further | r3d-cast-bellows / r3d-rig |

Process after the fixes:
1. Re-run `tools/scripts/pregate3d.sh --rows=1-7,9-18,20a` alone (about 55 min).
2. Re-shoot the failing frames and strips at the same ticks, then run **new** fresh reviewers on a rebuilt crowding packet and gag packet with a new seed, then row 19.
3. Push, then 20b: `gh run list --branch r3d --workflow android-preview.yml -L 1` and compare the artefact against 20a.
4. Update the owner pack's sha256, remove its banner, and send.

## 4. APK
`/home/user/mischief/build/r3d/mischief-debug.apk`, **73,419,843 bytes (73.42 MB)**, sha256 **`e60c5e7a9997711bb3f48e5c380b706f1ae83ab3c7387bee8c29e477e3d2ff19`**, 3277 entries.
- Every export re-signs the APK, so the sha256 changes; phase 1's copy was `8c4c4e24…3d2`, with the same size and contents.
- **This build does not start the game (P0).**

## 5. The owner pack — `docs/review/r3d/index.md` (drafted, held)
It follows the gate0 format and carries a "not ready to send" banner. Contents:
- The build, the install steps, and what opens (a fresh 1200×540 stage-door shot).
- What to play.
- How to show the N1/N2 previews (⏸ → Settings → Debug → "Night 1/2 previews" → finish the Night → Stage door → Play anyway), with the per-clip fallback table from `slice_all`:
  - reactions play `st_double_take` plus the caption;
  - activities play his idle;
  - micro-gags are skipped.
- The settings:
  - **Sim** ships, because `d1_lean` fails the ⅓ edge cap on 7 of 9 routes;
  - MSAA and render scale: "unchanged — no probe answer".
- The four complaints, each with a before/after board and the reviewer numbers next to it. Boards: the HUD, the kitchen, a new `cast_2d_vs_3d.jpg`, and the tinker vs the pepper rig, plus the window board and the sneeze strips.
- The head question: head B is the default and ×1.2 is recommended (B's head fails the 60 px face bars; ×1.2 passes 6/6 at both views).
- Honest rough edges: the D12, D13 and D15 weak spots, the row-19 gags and overlays, framing, the curtain call, the 38 % window, Figgis, the D14 spikes, the proxy-is-not-a-phone note, the default icon, no O1 answer.
- The verification table, with 20b "pending the push".
- The Bellows-window share for all 13 routes (sim, lean, in-game, and the `d1_lean` result).

I looked at every image it shows: the stage door, the settings debug tab, the HUD, kitchen, cast and tinker boards, the window board, both sneeze strip pages, the head check, and the regenerated `budgets.png` and `rigs.png`.

## 6. Five things the owner will notice first (once the P0 is fixed)
1. **It is calm.** There are four HUD pieces, big 3D characters and a sparse room. In the 2D-vs-3D pairs the fresh reviewer picked 3D 8/8 times, every time for fewer props, fewer HUD pieces and bigger characters.
2. **The sneeze still lands in 3D:** the push-in, the CHOO puff, the stool flight into the sink, the Stalls rising (4/4/3). In the dazed hold his face hides under the bouffant.
3. **Hush's face is small at B's head size.** It reads only when she turns to camera. The "head ×1.2" stage-door button answers this; ×1.2 is recommended.
4. **The busy moments are still busy.** While she rigs on the stool, the joke bubble and ring sit on her face. Joke badges collide with the APPLAUSE / RUNNING GAG text (2/8 "crowded").
5. **The Prologue's smaller laughs don't land without sound:** the picture, the doorframe bonk, the vase, the squeak bit, the relief, and why the dizzy spin starts. The Bellows window is on screen 30–38 % of the time.

## 7. Files (all in r3d-qa's ownership)
- `docs/review/r3d-qa/readability.md` (new): row 19, the verbatim answers, the keys, the verdict lines, the requests.
- `docs/review/r3d-qa/pregate.json`: the archived record of this run.
- `docs/review/r3d-qa/index.md`: new §0 with phase 3's table, plus pointers.
- `docs/review/r3d-qa/perf/{budgets,rigs}.png`: regenerated from this run.
- `docs/review/r3d/{index.md, stage_door.png, cast_2d_vs_3d.jpg}`: the owner pack, 236 KB.
- `docs/PROGRESS.md`: the R3D rows updated and a log line.
- Scratch: `<SP>/work/r3d-qa/p3/` (answer sheets, matcher verdicts, the run log, phase 1's pregate.json and e2e copies) and `LANDED.md` lines.

## 8. GDD text for the orchestrator (GDD is not my file)
From r3d-integrate §9:
- **GDD §9:** "Hush's held pepper pot is the set's pot (white body, dark cap, squat belly)."
- **GDD §9.5:** "`act_warmup` sings two phrases per 8 s (one mouth)."
- **Known weak spots:** the tea (D15, 2/2/2), the snicker (D12, 12/13), the N02 hall (D13), the P00 required window at 38 % (R15), and the row-19 gags (picture, bonk, vase, squeak bit, relief, dizzy-spin cause).

Q03 (the silent title slam) is fixed by the orchestrator's alias, so it is dropped from this list. Phase 1 already folded TECH; this phase made no TECH change.

## 9. Deviations and hours
- I re-ran the full pre-gate rather than row 19 only. Phase 1's evaluator fixes had made every non-sim row STALE, and the fixes had never run live. All rows are now recorded under one hash, and the archived JSON matches its table.
- One extra Godot run before the pre-gate: the stage-door shot, in sandbox r3d-qa-shot.
- Each packet had one reviewer, so the verdicts are single scores, not medians.
- Phase 3 took about 1.1 h.
