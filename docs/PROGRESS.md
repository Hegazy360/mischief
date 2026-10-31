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

## 3D pivot — R0/R2 (REDESIGN_3D §6.4)
### R0 — look-dev + spike
- [x] Three style look-devs + owner board (`docs/review/lookdev/`); reviewer recommends A (Toy Box)
- [ ] Owner picks a style (A / B / C) — still open; the cast runtime below is style-agnostic
- [ ] Device perf numbers from the pipeline spike (risk X1)
### R2 — cast in 3D (started)
- [x] Self-contained cast skeleton (`tools/art3d/cast/mnd_rig.py`): 20 body bones + jiggle, no Quaternius dependency
- [x] Hush + Bellows rebuilt as skinned glTF inside §5.6 budgets (9,999 / 10,000 tris; 27 / 32 bones)
- [x] 2D → 3D pose retarget: all 236 authored poses + 34 lint-checked clips replay unchanged
- [x] Procedural layers: jiggle (secondary motion), two-step foot grounding + two-bone IK, squash & stretch, moving holds
- [x] Toon + inverted-hull outline shaders; 2D face cards on 3D heads (full expression atlas ported)
- [x] CastWorkbench review scene + shots in `docs/review/cast3d/`
- [x] 19 tests in `tests/view/test_char3d.gd` (budgets, retarget convention, IK, jiggle, grounding)
- [x] Off-the-shelf cast evaluated in-engine (`docs/review/oss_cast/`): adopt KayKit (CC0) mannequins + 161 clips; drop the procedural Blender builders
- [x] `tools/anim/stability.py` in every `capture.sh` run (jitter / pops / frozen); Hush jitter 0.42 vs library 0.14–0.23 — the oscillation is our jiggle↔grounding loop
- [ ] Decouple jiggle from grounding (FK-only grounding, springs fed the post-ground transform); target Hush jitter ≤ 0.25
- [ ] Re-dress KayKit Medium/Large mannequins as Hush/Bellows (recolour atlas, beret/bouffant/specs accessories)
- [ ] Sim-state → library-clip map; authored 2D clips kept as overlays for gag beats
- [ ] Per-clip `ground_weight` flag (seated clips like `bellows/act_tea`)
- [ ] Residue attachments, temper tint tiers on the 3D cast
- [ ] Wire Character3D into NightScene (needs R1: House3D, CameraDirector3D, HUD declutter)

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
- 2026-10-30 — Dev environment made cross-platform, and the 3D cast runtime built (R2 start). (1) `tools/scripts/lib.sh`:
  macOS has no `timeout`, `xvfb-run`, `flock` or GNU `realpath -m`, so every script now picks the native tool or a
  portable equivalent (`MND_GUI` is a prefix array, not a function — coreutils `timeout` execs its argument and bash 3.2
  errors on an empty array under `set -u`). Godot 4.7.2 + Blender 4.5 LTS install steps in `docs/DEV_SETUP.md`.
  `DevShot.is_shooting()` stops NightScene auto-pausing during a capture (a desktop window loses focus, so every shot
  was of the pause menu). (2) The answer to "should we change technology" is no: the gap was the character pipeline,
  not the engine — see `docs/review/cast3d/index.md`. Built `game/view/char3d/**` (CastRig3D, PoseRetarget3D, Jiggle3D,
  Ik3D, Character3D) + `tools/art3d/cast/**`, on a self-contained 20-bone skeleton rather than Quaternius' 65-bone UE5
  mannequin (40 finger joints on a cast wearing mittens, over the §5.6 budget, and not committed). The retarget means
  236 poses and 34 clips carry over with zero re-authoring. Tests found an inverted IK bend axis and a grounding bug
  that floated any root-lifted clip on stretched legs. Full suite 1,114 green.
- 2026-10-30 — Owner: motion still unstable, models not good enough, prefer open source. (1) Review loop fixed: strips
  cannot show a 1-frame pop, so `tools/anim/stability.py` now scores every frame of every `capture.sh` run; it showed Hush's
  walk at jitter 0.42 (a 2–3-frame sawtooth = jiggle and grounding IK correcting each other) against 0.14–0.23 for library
  clips. (2) Evaluated KayKit, Quaternius, Kenney, Blender Studio rigs and Mixamo inside our renderer (`OssCastEval.tscn`,
  `docs/review/oss_cast/`). Recommendation: adopt KayKit Adventurers + Character Animations (CC0; 23-bone rig matching our 2D
  hierarchy; 161 clips incl. Sneaking/Lockpicking/Interact/Sit_Chair; medium + large rigs inside §5.6) as the base, keep our
  retarget/IK/face layers as overlays, drop the procedural Blender modelling. Mixamo only as a baked clip fallback.
