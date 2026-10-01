# r3d-fix-perf: fix round 1 report (resumed run)

**Status: done.** All six steps landed.
- **D17:** 5 call sites repeated at the same tick in every run. 4 are fixed at the source; the fifth is in r3d-hud's file and goes to them as request RQ1.
- **Verification on the live tree:**
  - full suite 1303/1303;
  - `lint.sh --strict` OK;
  - `e2e g0_sneeze --strict` PASS;
  - `e2e curtain_call` PASS, now through the WIP card;
  - row 16 re-measured (§4).

Branch `r3d`; no git writes. LANDED: `<SP>/work/r3d-fix-perf/LANDED.md`. Spike tables: `<SP>/work/r3d-fix-perf/spikes.md`. Review page: `docs/review/r3d-fix-perf/index.md`.

## 1. What changed (all in my ownership)

### (1) Landed early, 11:40Z: RigMods3D `MODE_SOCKET` keeps the clip's baked prop-bone scale
`game/view3d/char/rig_mods_3d.gd`
- A prop moved to another socket keeps the clip's keyed bone scale; before, it was forced to 1. This is how Clarence's `squeeze` → `grip_r` swell from `act_squeak` now shows.
- A key below 0.01 on any axis still shows at 1. That is the bake's scale-0 key for hidden extras.
- Home mode (`prop_fix_scale`) is unchanged.
- Test: `rig3d/test_player_3d.gd::test_socket_mode_keeps_the_clips_baked_prop_scale`.

### (2) fix-hud R2: the hold comes from the sim
`game/scenes/night/hud_presenter.gd`: `fill` sets `m.holding = hush.state == "RIGGING"`.
- This holds on paused frames and on the fallback-verb path.
- Test: `night/test_hud_presenter.gd::test_holding_while_she_rigs`.

### (3) fix-hud R1 (b): his bubble's glyph near the screen edge
`game/view/fx/thought_bubble.gd`
- When the left edge would clip the awareness glyph disc and its ear pips, they are drawn on the right of the cloud, the inside of the screen.
  - They go back left once that side has 24 px of slack, so it does not flicker.
  - "Inside the cloud" itself has no room: the 88 px icon and the 50 px ring fill it.
- New API:
  - `glyph_right`;
  - `local_span(right_side)`;
  - `screen_span()`;
  - `waiting`, the one-cloud fade. It has its own alpha, apart from the gag-hold `quiet`.
- r3d-fix-gags already reads `glyph_right` and `waiting` in `overlays_3d.gd`, for the clamp, `_bubble_rect` and the one-cloud wait.
- Test: `night/test_bubble_edge.gd`, 3 tests, a new file with its `.uid`.

### (4) D17 analysis and the fixes at the source
**Instrument.**
- `game/tools/e2e.gd` records the sim tick of every profiler frame in `prof_frame_ticks`, so the 60 slowest frames can be matched across runs by tick.
- `NightScene` has an opt-in split of its own HUD pass: `profile` / `prof_frame_us`, 9 phases. The e2e driver switches it on only while ScriptProf3D runs, and reports `night_phase_frames` and `night_phase_stats`. Nothing is stamped otherwise.

**Runs.**
- 3 rendered and 2 headless `prologue_ideal --perf-log --view3d-prof` runs, before and after.
- They ran on a frozen snapshot: HEAD plus my files. My first live-tree batch broke on r3d-fix-gags' edit of `overlays_3d.gd`, which was in progress at the time.
- Plus a headless rig bench.

**Deterministic before:** 5 sites repeated at the same tick in both headless runs and in 3 of 3 rendered runs. All were in the NightScene HUD pass.

| tick | cause (found with a scratch-only Hud split) | fix | after |
|---|---|---|---|
| 376–379 (rig on) | `ActionButton.set_icons` rasterised the rig point's icon (`honey_jar.svg`) and the needed item on first sight | `NightWarm.list` gets `hud_icons` (each rig point's icon and the steps' items); `NightWarmer._warm_ui_icons` rasterises them under the curtain | gone |
| 1376 / 2659 / 3102 (reaction accents; temper tier rises) | `Hud.apply` → `EdgeBubble.set_tier` → `face_for()` loaded a portrait PNG on first sight: 2.4–3.3 ms | `NightWarmer.hud` = the Night's Hud; the warmer calls `EdgeBubble.face_for` for the 4 tier faces and 8 emotes, plus the emote puffs | gone |
| 1447–1450 (the knock-on lands) | `Hud.apply` tail (`_tick_contextual`, the first meter / Running Gag show): 1.1–1.45 ms | none: `game/ui/hud.gd` is r3d-hud's file | **request RQ1** |

**Also changed.**
- `AudioDirector.clip_sounds` reads ClipLib3D's parsed events. A cue's first L12 check no longer reads a sidecar JSON from disk during PLAY. NightWarmer's clips step pre-builds them with `warm_clip_sounds`.
- `NightScene.next_useful` is cached for 6 ticks; it walks the Script lines and allocates.

**Rig clip-start path (my file): no deterministic cost.** The bench covered every clip of both rigs after `warm()`:
- `play()` takes at most 0.26 ms;
- the first advance after a switch takes at most 0.29 ms;
- steady advance takes 0.03–0.06 ms;
- the first pass equals the second.

The 1–6 ms `rig_advance` frames appear in 2 of 3 rendered runs at clip switches, never headless. They are render contention.

**FxFreezeFrame:** `_process` p95 is 0.007 ms. It never spiked. Noise.

**Tests:** `night/test_night_warm.gd::test_hud_icons_cover_tonights_rig_points` and `::test_edge_badge_faces_are_warmed`.

### (5) Q-N1: the Prologue's Next ▶ with the previews hidden
- `BootRouting.after_next(nxt, previews_on, has_stage_door)` in `game/scenes/boot/boot_routing.gd` decides where Next ▶ goes:
  - a slice Night that is still a preview (N01/N02), with `show_previews` off in a debug build, goes to the stage door with `{wip: <episode>}`;
  - a release build, which has no stage door, plays it as before;
  - when there is no next Night, it goes to "To be continued…".
- `game/scenes/night/night_scene.gd` routes `_on_curtain_call_action("next")` through it.
- `StageDoor.setup(params)` opens the WIP card on that Night (Play anyway / Back). `--wip=<ep>` does the same for shots.
- The e2e `curtain_call` flow (`game/tools/e2e/e2e_flows.gd`, `_next_into`) presses Play anyway through the card. It reports `p00_next_wip` and `n01_next_wip`.
- Tests:
  - `night/test_boot_routing.gd::test_next_to_a_hidden_preview_opens_the_wip_card`;
  - `night/test_night3d.gd::test_stage_door_opens_the_wip_card_from_router_params`.

## 2. Before / after frames (`docs/review/r3d-fix-perf/`, index.md)
- **R1, P00 frame 2190 (crowding pkt_06).** Same route and frame, 1200×540, `--no-captions`, MSAA off.
  - Files: `bubble_p00_f2190_before.png` (fix-hud's after frame), `bubble_p00_f2190_after.png`, and the zoom `bubble_p00_f2190_zoom.png`.
  - Looked at: before, the glyph disc and its pips are cut at x = 0. After, they sit just right of the gramophone cloud, whole, clear of the RUNNING GAG text and the record preview.
- **Q-N1:** `q_n1_wip_card_after.png`, the stage door with the "Work in progress" card and Play anyway / Back. It was looked at. Before this, Next ▶ opened N1 directly; there is no frame of that.
- **R2, g0 frame 192 paused (crowding pkt_02, fix-hud's paused seek):**
  - Files: `g0_t192_paused_after.png` and the zoom `g0_t192_button_zoom.png`.
  - Looked at: before (`../r3d-fix-hud/crowd_g0_t192_paused_after.png`), the teaching glove, the HOLD tag and the item badge were back on the held button. After, the button shows its ring and one centred icon, with no glove.

## 3. D17 spike table, before → after (full tables in spikes.md)
| | before | after |
|---|---|---|
| repeats at the same tick in both headless runs | 5 | **0** |
| rendered clusters with 3 of 3 runs at the same tick | 6 (t377, t1376, t1752, t2299, t2660, t3100) | 3: t1448 (Hud tail, RQ1), t1678 (CharacterView3D at the bonk cue, RQ3), t1348–1359 (different sub-site each run: noise) |
| NightScene max per run, rendered | 5.61 / 5.92 / 5.15 ms | 5.48 / 3.71 / 2.39 ms; 2.72 on the live tree |
| NightScene p95, rendered | 1.29 / 1.35 / 1.23 ms | 1.08 / 1.09 / 1.14 ms |

## 4. Row 16 re-measured: the perf3d command on the live tree, 12:34–12:53Z
| route | view + HUD p50 / p95 | draws p95 / max | tris max | emitters | tex MB | compiles in PLAY |
|---|---|---|---|---|---|---|
| g0_sneeze (`--strict`) | 2.84 / 4.09 | 55 / 63 | 81,129 | 4 | 87.4 | 0 |
| prologue_ideal | 3.25 / 4.65 | 71 / 79 | 98,950 | **8** | 109.5 | 0 |
| n01_ideal | 3.29 / 4.75 | 82 / 101 | 101,162 | 4 | 108.8 | 0 |

Snapshot A/B for prologue_ideal, 3 rendered runs each, which isolates my changes:
- view + HUD p50 went from 3.30–3.48 to 3.12–3.33 ms;
- p95 went from 5.20–5.62 to 4.60–4.86 ms;
- the profiler frame-total p95 went from 4.90–5.40 to 4.34–4.61 ms.

D14/D17's bars of p50 ≤ 3.5 and p95 ≤ 8.0 are met in every run.

QA round 1 had g0 2.78/4.07, P00 3.05/4.40 and N01 3.12/4.61. Since then the live tree gained fix-gags' staging FX, which explains P00's 8 emitters.

## 5. Tests and lint (live tree)
- **night/ + rig3d/:** 199/199.
- **Full suite** (`test_game.sh r3d-fix-perf-full`): **1303/1303 passed, 0 failed**, 138 files. The house3d anchor test passes again.
- **`SANDBOX=r3d-fix-perf-lint tools/scripts/lint.sh --strict`:** OK, 0 failed. `check_import_meta`: OK (1010 .import, 412 .uid).
- **e2e:**
  - `g0_sneeze --strict --perf-log`: PASS, 0 fallbacks, accent frame 94.
  - `curtain_call`: PASS. P00 Next → WIP → N01; N01 Next → WIP → N02; N02 → To be continued → Playbill; g0 Again 267 ms.
  - `prologue_ideal --perf-log --view3d-prof`: PASS.
  - `n01_ideal --perf-log`: PASS (8245 frames).
- `perf3d.sh` exits 1 only on its own 4.0 ms script-p95 device line, as it did for QA. D14/D17 judge the proxy at 3.5 / 8.0, and that is met.

## 6. Requests (also in LANDED.md)
- **RQ1, r3d-hud (`game/ui/hud.gd`).** At t1447–1450 `Hud.apply` takes 1.09–1.45 ms in all 5 after-runs, rendered and headless. This is the one D17-deterministic spike left.
  - It sits in `apply`'s tail (`_tick_contextual`, the meter / banner on first show), not in an icon.
  - Fix: prime that first show under the curtain.
- **RQ2, r3d-hud (`game/ui/world/world_overlays.gd`).** `WorldOverlays.apply` is NightScene's steady cost: p50 0.30 / p95 0.54 ms every frame headless, from the placer solve each frame. It reached 2.7–3.1 ms at t2970 in 2 of 3 rendered runs.
  - Fix: dirty-flag the solve.
- **RQ3, r3d-view3d / r3d-fix-gags (`character_view_3d.gd`, `cue_stager_3d.gd`).** Bellows' `CharacterView3D.apply` at the doorframe-bonk cue, t1678–1680, takes 1.42–2.05 ms in 3 of 3 rendered runs and 1.71 in one headless run. This is the stage hold / pin path, not `rig_advance`.
- **RQ4, r3d-qa / orchestrator (`tools/scripts/pregate3d.sh` row 16).** The evaluator still applies D14, any call site over 1 ms in the 60 slowest frames.
  - D17 needs tick matching across 3 rendered runs plus the headless ones.
  - The e2e reports now carry `prof_frame_ticks`, `night_phase_frames` and `night_phase_stats`.
  - `<SP>/work/r3d-fix-perf/{spikes.py,clusters.py}` implement the matching.
- **RQ5, r3d-fix-gags / orchestrator (emitters).** With the new staging FX, `prologue_ideal` peaks at **8 emitters**. That is exactly row 16's cap of 8; QA had 4.

## 7. Residual risks
- **The t1447 Hud tail spike (RQ1)** stays until r3d-hud fixes it. It is about 1.2 ms on the proxy, so likely below 1 ms on a device, but it is deterministic.
- **The clip-switch frames** (`hush_apply`, `bellows_apply`, `rig_advance`) reach 1–6 ms in 2 of 3 rendered runs. They never repeat headless, and the bench clears RigPlayer3D, so I judge them render contention. A device trace should confirm this.
- **More memory under the curtain.** The warm adds about 12 edge-badge portraits and tonight's rig icons, small textures, and loads them earlier.
- **The NightScene split instrument** is opt-in through `profile` and costs nothing when off. It stays because pregate D17 needs it.
- **Q-N1 in a release build** still plays N01 after the Prologue; there is no stage door there. That is intended. The WIP card text names "these Nights", not N1 specifically.
- **Clarence's swell:** RigMods now keeps any keyed socket scale above 0.01. A clip that keys a socketed prop at a stray small scale (0.01–0.5) would now show it small. No current clip does: lint_anim is clean and the fixtures pass.
