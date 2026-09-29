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

## Stage 5 — Release
- [ ] Version/codes, icon, splash, store screenshots (landscape)
- [ ] Permissions audit (VIBRATE only); no network
- [ ] Signed release APK/AAB via CI; iOS export notes
- [ ] Device matrix pass (2 Android, 1 iPhone)
- [ ] Final sign-off

## Log
- 2026-09-29 — Design panel complete: GDD, TECH, PLAN and Stage-1 briefs written. Nothing built yet.
