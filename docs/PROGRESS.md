# Mischief Next Door — Progress

Acceptance checklist per stage (docs/PLAN.md). Tick a box only when its evidence exists (tests green, artefact in
`docs/review/<key>/` looked at, or an owner note). Add a dated line under "Log" for every change of status.

## Stage 1 — Foundation
### sim
- [ ] ContentDB loads + validates every TECH §4 file; real data dir returns 0 errors (or precise requests filed)
- [ ] Nav graph + paths (doors, stairs, per-mover costs)
- [ ] Hush: commands, busy + single queue, idempotent go, pins, hide/pop out, freeze, squeak arm, items + restock
- [ ] Bellows: routine loop, gates, detours, bubble (≥ 4 s ring), entry warning + doorway pause, look-back, speeds ≤ +15 %
- [ ] Senses: specs table, doorway look-through, "?" meter by act, near miss, watched hiding, in-use spots, bump rule
- [ ] Chase / wheeze / search / on guard / door slam / Chase Trips
- [ ] Caught: busted cam → Lecture → doorstep, control at +240 ticks, items home, −5, tomatoes, the Hook
- [ ] Pranks: steps, prep tiers, conditions, fizzles, resume + fixup hooks, one punchline at a time
- [ ] Reactions: tier lengths, suppressed, travel, knock-on Double Acts
- [ ] Temper: gains, hold/decay/pauses, tiers, Running Gag links + multipliers, Meltdown, Exhausted
- [ ] Residue → fix-up routing, interrupts, combos
- [ ] Scoring (normalisation 700, bits, four bonuses), Script goals, Big Number, stars
- [ ] Squeak bits 2/1/0, ear pips, lure, lure fatigue; Mirror, Mirror rounds
- [ ] Director: gates, cues, safety net, can't-fail
- [ ] Conditions language; events + `is_laugh`; state hash; clone; golden tests; `sim_run.gd`
- [ ] Every GDD §4.7 fairness rule has a passing scenario test
- [ ] Perf: ≤ 0.05 ms/tick headless
### rig
- [ ] RigDef / PoseLib / ClipLib / RigSampler / Springs / FaceState / PropSim / ClipEvents (pure, tested)
- [ ] RigPlayer: atlas-backed, ≤ 12 draw calls per character, tiers/suppressed remap, smears, facing turns
- [ ] HiResTex port + AtlasBuilder (packing tests)
- [ ] Animation lint + rig lint (every rule caught on seeded bad data)
- [ ] anim_sheet.sh (rig, poses + silhouettes, contact, onion, curves) + capture.sh (GIF)
- [ ] AnimViewer with hot reload
- [ ] Mannequin rig + 12 poses + 5 demo clips, lint-clean, sheets + GIFs in docs/review/rig/
### art-hush
- [ ] Hush parts (~20, 8 gloves), rig.json, faces (8/5/8, ≥ 12 presets), ≥ 40 poses
- [ ] Pip skin (same names + pivots), Clarence prop, Figgis bust, Stalls atlas
- [ ] Preview sheets: rest, poses + 50 px silhouettes, expressions, cast sheet; warmth rule checked
### art-bellows
- [ ] Bellows parts (~22; bouffant × 7, sideburns × 3, specs × 4, hands × 6), rig.json, faces (10/6/10, ≥ 16 presets)
- [ ] Residue overlays × 7, combo looks × 4, temper tint tiers
- [ ] ≥ 50 poses; expression, residue and silhouette sheets
### art-house
- [ ] house.json: all 10 rooms, links, stations, hotspots (canonical ids), landings, quake props, entries
- [ ] Hotspot rect checks green (≥ 144, 24 px gaps, no overlaps, stacked shared objects)
- [ ] Final art: porch, hall, parlour, kitchen (bg/fg) + every slice prop in all states with outline sprites
- [ ] Greybox art for the other 6 rooms; item icons × 16; activity icons × 27; the stage; STYLE.md
- [ ] Preview scene + screenshots (zoom 1.0 per room, 0.5 overview)
### ui
- [ ] Theme + fonts (OFL); every HUD widget at GDD §3.8 sizes; HudModel + intents
- [ ] InputRouter + TapAssist; verb latch/hysteresis; two-thumb suppression; slide-off cancel
- [ ] Panels: Script, pause, settings, loading card, results skeleton, pick strip
- [ ] Autoload scripts: settings, save, haptics, router (+ support: safe area, ui scale, fade)
- [ ] UiDemo screenshots at 20:9, 16:9, 4:3, fake insets, left-handed; layout test green
### view
- [ ] SimDriver (rates, ff, pause, max 8 ticks), JuiceClock port
- [ ] CameraDirector (follow, pan/pinch, overview, peek, gag queue, shake/kick, hold offset)
- [ ] WorldView / RoomView / PropView / HotspotView / CharacterView + map.json
- [ ] FxLayer (captions, stamps, particles, ripple, rings, footprints, stare strip, bubble, badges), BustedCam
- [ ] PipView (30 Hz, escalate), StallsView (1 draw call), AudioDirector
- [ ] ViewSandbox screenshots + frame sequences; perf ≤ 150 draw calls p95
### audio
- [ ] tools/audio ported; deterministic render; `--check` in CI
- [ ] Slice SFX (≈ 60), Clarence, stingers
- [ ] Bellows phrase bank + talking-tuba fallback; crowd tiers + specials + fallback crowd
- [ ] Music stems (sneak, suspense, chase) + 4 chain sections + curtain/results
- [ ] Audio autoload API + cues.json; tests; A/B review index
### solver
- [ ] SolutionDef, Executor, Personas, Metrics, Planner, Invariants, Fuzz (tested on fixtures)
- [ ] Content, hotspot and IP lints (every rule caught on seeded bad fixtures)
- [ ] solve.sh / fuzz.sh / lint.sh / lint_all.sh with exit codes; CI workflow updated
- [ ] Solve report for P/N1/N2 (if sim + content present)
### content
- [ ] items (16), pranks (32 + 6 Double Acts), activities (27 + detours), reactions (22 + 6 signatures + meltdown/lecture/beats), residues (7) + combos (4)
- [ ] Episodes: P, N1, N2 final; N3–N10 + Gala complete drafts
- [ ] barks (Figgis cards, results templates, cold-open notes); solutions for P/N1/N2 (ideal, required, slow)
- [ ] Content test green; catalogue table matches GDD §5.7 / §7.2
### Integration pass
- [ ] One import; autoloads registered; export filters set
- [ ] All tests + lints green; `solve.sh all` runs; bounded fuzz green
- [ ] Cross-module requests applied (`s1-integrate`)

## Stage 2 — Vertical slice
- [ ] Gate 0: ACHOO-RIA! end to end (GIF + APK route); cast sheet; voice A/B; crowd A/B — owner decisions recorded
- [ ] NightScene: Boot → curtain → Prologue (warm under the curtain), retry ≤ 1.5 s, pause/back, results + Gag Reel
- [ ] Every P0 Bellows clip lint-clean + reviewed ≥ 3/5
- [ ] Every P0 Hush clip lint-clean + reviewed ≥ 3/5; Figgis + Stalls clips
- [ ] Slice sound mix complete; music transitions; loudness pass
- [ ] Prologue director beats, Figgis cards, ghost fingers, hint ladder 1–3, loading cards, N1–N2 cold opens
- [ ] Solver: P, N1, N2 × ideal / required / slow meet `expect`; Prologue 6 laughs in 60 s (ideal)
- [ ] Slow route: first player laugh ≤ 10 s, first prank ≤ 30 s from launch; dead air < 20 %
- [ ] Fuzz 200 runs green; all lints green
- [ ] Mute test ≥ 4/6; review agent ≥ 3/5 on every gag
- [ ] 60 fps p95, ≤ 150 draw calls with Gag-Cam + PiP + particles; launch → first laugh ≤ 10 s on a budget Android
- [ ] Cost of one prank end to end recorded here

## R3D — the 3D view slice (branch `r3d`; `<SP>/tasks/r3d-index.md`, TECH v1.2-3D)
The owner's Gate-0 verdict (core idea right; UI crowded, characters unappealing, house crowded, actions unclear) moved
the view to 3D (look A, Hush in B's dimensions) for g0 + the Prologue, with Nights 1–2 as hidden previews.
- [x] Pre-flight: CPU slots (`slot.sh`), Godot / Blender / SDK setup scripts, the CC0 UAL skeleton, look-dev references,
  the 2D reference frames (`docs/review/r3d-ref2d/`), CI on `r3d`
- [x] B1 (10 tasks), queue keys 1–6, the lint fix passes; K2 real-project import; K3
- [x] r3d-integrate: request table, g0 + every Prologue route in 3D, `slice_all` N01/N02, the 2D view deleted (§3.5)
- [x] r3d-qa Phase 1: `tools/scripts/pregate3d.sh`, `game/tests/slice/` (8 tests, ≈ 2.1 min), CI (`lint.sh --strict`,
  headless `lint3d --screen/--set`), TECH as built, the row-19 packets built (`docs/review/r3d-qa/`)
- [x] Fix round 1 (5f0092b: r3d-fix-hud / -gags / -perf) + r3d-fix-hud2 (the Hud first-show warm, the overlay solve
  dirty flag)
- [x] QA round 2 (5f0092b + r3d-fix-hud2): rows 9, 16, 19 FAIL (`docs/review/r3d-qa/index.md` §R2–§R3,
  `pregate_r2.json`) → fix round 2 (r3d-fix-hud3 / -gags2 / -night2), committed unchanged as 446a69b
- [x] QA round 3 pre-gate, alone, one invocation, on 446a69b (hash b73588a30a7434b2, sim tree ee4b12e86af732e9;
  2026-10-01 23:13Z – 10-02 02:05Z): rows 1–15, 18, 20a PASS — row 9 now 0 errors (the vase fix landed); record
  `docs/review/r3d-qa/pregate_r3.json`, numbers in `docs/review/r3d-qa/index.md` §R4
- [x] **20a: the exported APK boots the 3D game** — 73,526,533 B, 3279 entries, sha256 fc4ad3ea…75ed; 197 scripts,
  0 failures, Night OK
- [ ] Row 16 (D18.2): every count and the p50 / p95 rule pass; 1 site in 3/3 rendered runs (NightScene t1283; chance
  baseline 2 / 0) + 27 headless repeats (chance 36 / 36); the previous pass on identical files flagged a different
  site (t379) — chance level on this box; lead ruling asked + 3 recurring sites sent as fixes (t3351 picture slide-off,
  t1283 sneeze reaction start, t1677 doorframe bonk)
- [ ] Row 17: Bellows 0.281 ms > 0.25 (the same files gave 0.213 ms in pass A; re-check 279 µs; the host slowed
  10–30 % after the ~23:00Z restart); Hush 0.206 ms — lead ruling asked (or a ~15 % rx_sneeze_blast_a CPU cut)
- [ ] 19: round 3 (3 fresh reviewers per packet, medians, D18.1) — **FAIL** (`docs/review/r3d-qa/readability.md`,
  Round 3): spot **7/8** PASS (counts 7/6/7), crowded **1/8** PASS (at the bar), verb 7/8 and 3D preferred 8/8
  carried; gags **3 of 9** at their bar — both sneezes 4/4/3 and the curtain call 3/3/3 PASS; dizzy spin 3/3/3 (bar
  4/4), picture 3/3/2, bonk 3/3/2, vase 2/3/2, squeak bit 1/2/1, relief 1/2/1 — requests Q3-G1…G6, Q3-C1, Q3-S1/S2
- [ ] 20b: the CI android-preview APK of the pushed head matches 20a
- [ ] Owner check: R1 / R2 verdict on the owner pack (`docs/review/r3d/index.md` — refreshed for round 3, held until
  16 / 17 / 19 pass)

| Exit row (index §6) | Result | Numbers (QA round 3, pass B) |
|---|---|---|
| 1 import metadata · 2 suite · 3 lints --strict · 4 validators | PASS | 1010 .import / 413 .uid; 1345/1345 tests, 0 skips, 139 files; 72 clips strict 0 errors; 5 validators |
| 5 routes · 6 dead air · 7 planner | PASS | 13 routes, every expect OK; worst ⏩ 8.1 / 4.8 / 5.9 %, gap 5.47 s, edge 0.221; N02 first prank 19.4 s |
| 8 fuzz | PASS | 2400 runs, 0 failed, 0 invariants, 0 soft-locks |
| 9 set lint | PASS | 0 errors; 1 warning (N02 hall, D13) |
| 10 screen · 11 HUD · 12 C8 | PASS | 0 errors (10: 1 warning); C8 0 violations on 13 routes × 2 modes; Bellows window ≤ 35.0 % |
| 13 g0 · 14 Prologue · 15 other routes | PASS | CHOO accent f 94, hit-stop 83 ms, Again 240 ms; 7 laughs by 60 s, crowd ≤ 0.254 s; slow first laugh 6.63 s / prank 27.58 s; 13/13 scenarios |
| 16 frame budget | **FAIL** (D18.2) | draws p95 ≤ 81 (max 96), tris ≤ 103k, tex ≤ 110 MB, emitters ≤ 8, 0 compiles in PLAY, view + HUD p50 2.65–3.04 / p95 3.82–4.43 ms; 1 site 3/3 rendered (chance level) + 27 headless repeats |
| 17 per character | **FAIL** | Bellows 0.281 ms (266–290 µs) / 4 draws / 9.5k tris / 50 bones; Hush 0.206 ms / 2 / 9.8k / 48 |
| 18 flows | PASS | retry 763 ms, tap 20/20, feedback 1 frame, g0 Again 294 ms, P00 Next live frame 1 |
| 19 readability | **FAIL** | spot 7/8, crowded 1/8, gags 3 of 9 at bar (medians of 3 reviewers; verb 7/8, 3D preferred 8/8 carried) |
| 20a APK | PASS | 73.53 MB, 3279 entries, exported pack 197 scripts / 0 failures / Night OK |
| 19 readability | **FAIL** | verb 7/8 · spot 6/8 · crowded 2/8 (≤ 1) · 3D preferred 8/8; sneezes 4/4/3, dizzy spin 3/3/4 (≥ 4/4), 5 small gags < 3 |
| 20a APK | **FAIL** | 73.4 MB, VIBRATE only, minSdk 24, contents OK — the exported pack does not compile `WorldView3D` |

## Fun Gate (owner, his phone)
- [ ] 1. First player-caused laugh ≤ 10 s and first prank ≤ 30 s from launch (log)
- [ ] 2. ≥ 5 audible laughs or grins in the first 10 minutes
- [ ] 3. Unprompted replay of Night 1 or 2
- [ ] 4. 9/10 correct calls of Bellows' next destination
- [ ] 5. No catch called unfair; ≥ 1.0 s "?" before every catch in the log
- [ ] 6. ≤ 1 misfire in 20 taps on a 60 px hotspot; ring readable; pan never moves Hush; never "nothing happened"
- [ ] 7. Stable 60 fps on his phone
- [ ] 8. "Funnier than Booby within a minute"

## Stage 3 — Content
### Wave 3A — Act I rest
- [ ] s3-sim-cast: Beryl, Delphine, panto, herding, witness (tests + invariant 11)
- [ ] Upstairs art final (landing, bathroom, bedroom) + props
- [ ] Act I animation set (archetypes, IN OVER HIS HEAD, Meltdown b/c, combo beats) reviewed ≥ 3/5
- [ ] N3, N4 final + solutions green; sound
- [ ] Owner check: Act I
### Wave 3B — Act II
- [ ] Beryl rig + set; conservatory + garden art
- [ ] Act II animation (Beryl, garden, BALLOON_CHASE, HEADBUTT_LAUNCH, GOAT_KISS, GRAND EXIT, KIDDING AROUND, panto)
- [ ] N5–N7 final + solutions green; sound
- [ ] Owner check: Act II
### Wave 3C — Act III + Gala
- [ ] Delphine rig + set; dressing room, garden stage, spotlight art
- [ ] Act III animation (Delphine, host/tango/cloak/polish, COSTUME_BURN, SUPPRESSED, IT TAKES TWO, SPOTLIGHT STEALER, cold opens)
- [ ] N8–N10 + Gala final + solutions green; Gala first clear ≤ 8 min; sound
- [ ] Owner check: Act III + Gala

## Stage 4 — Meta + FTUE + polish
- [ ] Playbill wall + unlocks
- [ ] Encores (3 per Night) + roses
- [ ] Programme (seen tracking, silhouettes)
- [ ] All cold opens, loading cards, Figgis introductions; settings + accessibility complete
- [ ] Juice, perf and mix passes on device
- [ ] Full-game solver run; review agents on every gag; owner playthrough

## Stage 5 — Release
- [ ] Version/codes, icon, splash, store screenshots (landscape)
- [ ] Permissions audit (VIBRATE only); no network
- [ ] Signed release APK/AAB via CI; iOS export notes
- [ ] Device matrix pass (2 Android, 1 iPhone)
- [ ] Final sign-off

## Log
- 2026-09-29 — Design panel complete: GDD, TECH, PLAN and Stage-1 briefs written. Nothing built yet.
- 2026-09-29 — CI fix pass on 981ea07 (red on main): (1) the Python job installs `librsvg2-bin` (`rsvg-convert` for
  the art validators); rendered `squelch` ×2 (SOAKED steps), "I did NOT squeak!" ×2 (+ tuba) and the Stage-3 lines
  (BERYL! ×2, ha-ha my dear, Delphine HORACE! ×2 + the high-C INTRUDER!, Beryl MEH! + bleat ×3) → `gen_audio.py
  --check` PASS; (2) the sim emits `cmd_queued {c, why, target}` for a go/move held while busy (climb-in: `entering`),
  rule 9 accepts it as feedback; (3) Prologue soft-lock (fuzz hider seed 13): a Curious detour ended the uncapped
  "until rigged:achoo_ria" warm-up, so he brewed the tea with nothing rigged and the sneeze became impossible — an
  uncapped player-led gate now holds the loop through interruptions (TECH §3.7.1). Regression tests in
  tests/sim/test_routine.gd, test_episode_rules.gd, test_hush.gd, tests/solver/test_invariants.gd, test_real_solutions.gd.
- 2026-09-29 — CI fix verification (sandbox `civerify`): every CI step green; `fuzz.sh p00_curtain_up --runs=100
  --seed=21` found 3 more Prologue rule-6 failures past CI's seeds. (a) random 21: a lure mid-tea (honey rigged) ended
  the tea before ACHOO-RIA!'s 7 s hook and the non-repeating loop never came back → in a `loop_repeat: false` Night an
  interruption restarts an activity whose rigged prank is still to come (`SimBellows.hook_pending()`, TECH §3.7.1);
  (b) hider 53 / 73: false alarms — the run ended mid-dive, the probe's first go was pinned (TECH §3.5) and the
  executor never popped her out → `Executor._ensure_mobile()` waits out a dive. Tests in tests/sim/test_routine.gd and
  tests/solver/test_real_solutions.gd.
- 2026-10-01 — r3d-qa Phase 1 on `r3d` 5b5a135 + its working tree: `tools/scripts/pregate3d.sh` (rows 1–18, 19, 20a +
  an exported-pack probe), `game/tests/slice/` (8 tests), CI (`lint.sh --strict`, headless `lint3d --screen/--set`), TECH
  v1.2-3D as built, the five row-19 packets built (not scored). Pre-gate alone on the CPU box: rows 1–15, 17, 18 PASS;
  16 FAIL (D14 spike clause); **20a FAIL — the exported APK cannot compile `WorldView3D` (`ScriptProf3D` lives in the
  export-excluded `view3d/probe/`), so the game would not start**; fix verified in a scratch export; 19 pending.
- 2026-10-01 — r3d-qa Phase 3: row 19 scored from the fresh reviewers' verbatim answers (`docs/review/r3d-qa/readability.md`,
  `packets.py score` + the gist by hand): verb 7/8, spot 6/8, 3D preferred 8/8 PASS; crowded 2/8 and the Prologue's small
  gags FAIL (requests Q-C1/2, Q-G1–6, Q-S1/2, Q-V1/2). Full pre-gate re-run alone (hash eee8a789f5e192c7): 1–15, 17, 18
  PASS (8 kept), 16 FAIL (14 spikes, worst 4.3 ms), 19 FAIL, 20a FAIL (the P0 `ScriptProf3D` fix is not applied; APK
  73.42 MB, sha256 e60c5e7a…ff19). Owner pack `docs/review/r3d/index.md` drafted (held: "not ready to send").
- 2026-10-01 — r3d-qa round 2 (5f0092b + r3d-fix-hud2): phase 1 ran the full pre-gate alone (row 16 now D17: 3 rendered
  + 2 headless profiler runs) and rebuilt the spot / crowding / gag packets; new fresh reviewers answered them; phase 3
  scored row 19 (`readability.md` Round 2: spot 6/8 PASS, crowded 2/8 FAIL, gags 1 of 9 at bar FAIL — the picture now
  passes 3/4/3, the sneezes fell to 3/3/3 with an unchanged clip) and re-ran row 19. Verdict FAIL on rows 9 (vase still
  flagged dressing), 16 (D17) and 19; 20a PASS (APK 73,468,995 B, sha256 9478f00d…6316). Owner pack refreshed (boards
  re-shot from this build, round-2 verdicts, rough edges), still held.
- 2026-10-02 — r3d-qa round 3 (446a69b = 74967b5 + fix round 2): phase 1 ran the full pre-gate alone (pass B, the
  record; pass A on identical files kept for comparison) and reused the packets set_i / set_j / set_k; nine new fresh
  reviewers (3 per packet, D18.1) answered them; phase 3 scored row 19 (`readability.md` Round 3: spot 7/8 PASS,
  crowded 1/8 PASS, gags 3 of 9 at bar FAIL — both sneezes 4/4/3 and the curtain call 3/3/3 now pass) and re-ran row
  19 alone. Verdict FAIL on rows 16 (D18.2 at chance level), 17 (Bellows 0.281 ms on the slowed host) and 19; 20a PASS
  (APK 73,526,533 B, sha256 fc4ad3ea…75ed). Owner pack refreshed (boards re-shot from this build, round-3 verdicts,
  rough edges), still held.
