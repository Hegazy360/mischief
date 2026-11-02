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

## 3D pivot — retired
- [x] R0 look-dev + open-source evaluation done (`docs/review/lookdev/`, `docs/review/oss_cast/`)
- [x] R2 cast built on KayKit and wired into a Night behind a flag — **tried in play and dropped** (glitchy, moved backwards); the 2D rig stays. Record in `docs/review/cast3d/`
- [x] 2D Bellows drawn at 0.9 (`CharacterView.VISUAL_SCALE`) so he reads stout, not giant
- [x] `bellows/loco_blind_shuffle` re-posed (one hand gropes, one shields the eyes)
- [ ] Further 2D polish on the owner's notes as they come

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

- 2026-10-31 — R2 on an open-source base. (1) Fixed the instability: `Character3D` ran the jiggle springs BEFORE
  grounding moved the body, so each frame the springs chased the previous frame's position — two feedback loops on one
  skeleton. Grounding is now solved from the FK-only pose and applied first, the lift is critically damped and the foot
  plant fades over a 2 cm band. Isolation captures then showed the remaining jitter was the authored 2D tiptoe clip
  itself, not the runtime. (2) Replaced the procedural characters with re-dressed KayKit (CC0): `recolour.py` repaints
  the gradient atlas, `redress.py` drops clashing meshes, paints Hush's stripes onto the tunic's own faces and adds our
  accessories on jiggle bones. (3) `ClipMap3D` + `clipmap3d.json` play library clips for everyday motion and keep the
  gags as 2D overlays. Measured: Hush 0.13 / Bellows 0.18 jitter (library band is 0.14–0.23; the old rig was 0.42).
  Retired `mnd_rig.py` and `build_cast.py`; deleted the 18 MB evaluation staging. Tests 1,120 green.
- 2026-10-31 — Owner: the game still shows the old characters. Correct and expected — nothing in the game path used
  the 3D cast, only the dev workbench; that was stated in the docs but buried. Fixed by building `CastProxy2D`, which
  renders each 3D character into a SubViewport and draws it where the 2D rig stood, behind the duck-typed interface
  `CharacterView` already used (`MND_CAST3D=1`; off by default so the suite and house shots keep the 2D rig). Second
  look pass on both characters (high-contrast mime palette, black boots, muttonchops, the Mage's belt kit painted out,
  accessories fitted to the 10k budget). Re-posed `bellows/loco_blind_shuffle`: it was two rigid parallel arms held for
  all 24 frames; now one hand gropes and sweeps while the other shields the eyes, set on every key so the half-cycle
  mirror cannot swap hands. The torso is deliberately left to the poses — it is Bellows' root part, and moving it slid
  the planted foot (anim lint A12/A13/A27). Tests 1,120 green.
- 2026-10-31 — Owner tested `MND_CAST3D=1`: the 3D cast was glitchy and moved backwards, while the 2D animation works.
  Decision: one version, the 2D one, improved incrementally. Removed `view/char3d`, `art3d`, `CastProxy2D`, the clip map,
  the workbench scenes, `tools/art3d/cast` and their tests; `docs/review/{cast3d,oss_cast}` kept as the record with a
  RETIRED banner. Kept `tools/anim/stability.py` (it works on any capture) and the portable `tools/scripts/lib.sh`.
  Bellows now drawn at 0.9 via `CharacterView.VISUAL_SCALE` (HEIGHTS follows, so bubble/badge anchors stay on his head);
  Hush unchanged at the owner's request. The blind-shuffle re-pose from earlier today stands.
- 2026-10-31 — Owner: the levels are samples; plan every level and its scenarios before expanding the repo. Wrote
  `docs/LEVELS.md`: the measured state of all 12 episodes (3 `final` with 15 solver routes; 9 `draft` with none;
  Bellows has 2 of the 75 clips `reactions.json` references and 2 of 27 activity clips, so even the slice plays the
  `st_bonk` fallback for 10 of its 11 reactions; Beryl / Delphine / panto are null seams), a per-level definition of
  done, four scenario families (golden, rule proof, fairness, fun) with stable route names, a build sheet per level
  (premise, clock, Script, what is new per discipline, the scenarios to author, risks), the wave order (wave 0 =
  finish the slice's clips before the Fun Gate), and six decisions for the owner (Act I upstairs loop lengths, the
  spotlight rule, N9's Chase Trip without Beryl, knock-ons into gated STEP pranks, Besotted across the house).
  No code or data changed.
- 2026-11-01 — Owner: go with the six recommended decisions, keep the plan current, and give the Nights a connected
  story. (1) Sim: a loop entry may carry `dur_s` (this Night's activity length; validated ≥ 5 s and against the
  Night's USE hooks) and a USE trigger `at_end: true` fires on the activity's real last tick (BUTTER-FINGERS was
  pinned to 18 s); knock-ons waive the `tier_min` anger gate (ENCORE! → RUG BURN). Tests in test_routine,
  test_conditions, test_reactions. (2) New `tests/solver/test_loop_lengths.gd` measures every episode's steady-state
  loop with the planner's idle probe: N1 58.7, N2 55.4, N3 77.9 → 58.9 (bath 12, dress 5, nap 12), N4 92.6 → 64.6 s
  (warmup 6, paper 6, bath 10, nap 8; the stair round trip alone is 30 s, so GDD §2.4 rule 5 allows 65 s for the
  two-floor finale). Later Acts reported, not gated: N5 55, N6 70, N7 115 (over), N8 70, N9 90, N10 104, Gala 91 s.
  (3) GDD §7.0 "The story: the Summer of the Comeback": one house, one summer; Act I heatwave, Act II show season,
  Act III the last week, Gala = the street's Summer Show he hijacked; the hall countdown poster, the CONFISCATED box
  that fills each cold open and is tipped out at the Gala, one decor set per Act; a story beat per Night. Decisions
  written into GDD §2.4/§4.8/§5.5/§7.2, TECH §4.6, PLAN §3–4 (wave 0 before the Fun Gate), LEVELS §1/§4/§6.
- 2026-11-01 — Owner: start the implementation; every Act reachable on the sandbox; a progress summary per run.
  (1) Stage door: an **All Nights** page lists the 12 episodes (drafts marked), `ep:<id>` buttons; `TESTING_ON_MAC.md`
  lists every `--episode` id. Nights 3, 5 and the Gala launch into the real NightScene headlessly (shots in
  `docs/review/w0-anim/`). (2) Wave 0 begun (LEVELS §5): `tools/art/bellows/poses_w0.py` (37 poses: the pickle
  shelf, the sink, the spin, the recliner cushion (12, −120), the log basket) and `clips_w0.py` (15 clips: DRENCH A,
  SING_CRACK, STRAIN_SLIP, LAUNCH_CEILING, DIZZY_SPIN; act_pickles / rinse / paper; mg_sniff_jar, gargle_hum, tut,
  chuckle_at_own_photo; bit_tea / paper / warmup), wired into `clips_spec.py` + map.json. Authoring lesson, now a
  helper: lint A12 (a planted sole drifts ≤ 2 px) means a standing clip must pin one stance per floor contact —
  `pin()` writes absolute leg angles minus each key's torso lean and the stance's planted root (hip offset
  compensated); a stance only changes across an airborne key, and landings come straight down from a `hover()` key.
  Root squash on planted keys stays ≤ 1.04 (the toe is 50 px from the origin). `lint_anim --rig=bellows --strict`
  30 clips / 0 / 0; suite 1,105 green; solver 14 / 14; import meta OK. Review: `docs/review/w0-anim/index.md`.
  Left in wave 0: N2's 11 clips (COLD OPEN, EYE-POPPING NEWS A/B, FISH SLAP, TIME'S UP, MIRROR, MIRROR + 3 rounds;
  fire / snack / mirror / phone / clock; bits mirror / phone), the Lecture ×3 and 15 state clips, the T3 beats,
  Meltdown a/b/c, `clip_events.md` rows and SFX for the new clips, the new scenarios of LEVELS §4 for P / N1 / N2.
- 2026-11-01 — Wave 0, second run: the Night-2 set. `tools/art/bellows/poses_n2.py` (41 poses) + `clips_n2.py` (21 clips:
  COLD OPEN, EYE-POPPING NEWS, SOMETHING FISHY, TIME'S UP, MIRROR, MIRROR + its three stand-in rounds; act_fire /
  snack / mirror / phone / clock; six micro-gags; bit_mirror / bit_phone). Every slice reaction, activity, micro-gag
  and squeak bit now has a real clip: `lint_anim --rig=bellows --strict` 51 clips / 0 / 0; suite 1,105 green; solver
  14 / 14; import meta OK. **Bug fixed:** `ClipDef.is_reaction()` classified the mirror rounds
  (`sig_mirror_mirror_r1..3`) as reactions by their `sig_` prefix, so the lint demanded beats they must not have;
  `is_round()` now excludes `_r<n>` stand-ins (clip_lib's release-mark default and RigPlayer's jitter rule agree).
  **Gaps noted, not fixed:** (a) COSTUME look `jelly_helmet` exists only as a rig prop, not a residue overlay, so the
  helmet vanishes when COLD OPEN's clip ends although STICKY + COSTUME persist (art-bellows); (b) the view drives the
  specs prop from the sim (on / dangling only), so EYE-POPPING NEWS' `magnifier` state is never shown; (c) no
  `clip_events.md` rows for the 36 new clips yet (sounds sit on contact frames; the sound test covers Phase G only);
  (d) a PropSim launch at the reactions' speeds drifts slowly (gravity 2600 px/s²) — LIFT-OFF hides the paper instead.
  Review: `docs/review/w0-anim/index.md`. Left in wave 0: Lecture ×3, state clips ×15, Meltdown a/b/c + Exhausted,
  T3 beats ×4, the hunt walk, SFX + sound rows, the new scenarios of LEVELS §4 for P / N1 / N2.
- 2026-11-02 — **Wave 0 closed: the vertical slice is animation-complete.** `SliceClips.build()` reports 0 missing
  clips for every rig (it was 47 Bellows + 19 Hush/Figgis at the start of this run). New: `tools/art/bellows/`
  `poses_w0b.py` + `clips_w0b.py` (47 clips — the 15 state clips, the Lecture ×3, the three Meltdowns + Exhausted,
  the four T3 last beats, the three fix-up detours + the hunt, seven micro-gags, `bit_livid`, EYE-POPPING NEWS' B
  variant, TAP DANCE's knock-on entry, the two cold opens, the curtain-call wander-on, the picture-bonk cue, and
  the Irked / Steaming walks + the chase run); `tools/art/hush/clips_w0.py` (15 — the bow, four flavours, the
  rummage and mid-job freeze loops, the door, the wink and the whole caught chain) and `clips_figgis.py` (5 chip
  clips). Totals: Bellows 98, Hush 34, Figgis 5; `lint_anim --all --strict` 144 clips / 0 / 0; `lint.sh --strict`
  all four lints OK (the content lint's anim-coverage block is now clean); suite 1,105 green; import meta OK.
  Six new solver scenarios from LEVELS §4 — P `no_squeak`, N1 `bn_sealed` + `tray_restock`, N2 `caught` + `chase`
  + `mirror_r3` + `frazzle_link` (N2's `mirror_poke` was dropped: the executor's `stand_in` always releases, so the
  poke window needs a solver verb) — solver 21 routes / 0 failed.
  **Authoring rules learned (now in the helpers):** `pin(..., flat=True)` neutralises a key's root scale *and*
  rotation, because both pivot the body about the feet origin and drag the soles (lint A12); a planted foot cannot
  be eased off the floor on his short legs, so a knee hoist must be a `pop` key; a loop's breath period must divide
  its length, and `plant: true` (an IK lock between keys) must not be set on a loop or its seam never closes.
  **Bugs fixed:** (1) `ClipDef.is_reaction()` classified `sig_mirror_mirror_r1..3` as reactions by prefix, so the
  lint demanded beats a stand-in round must not have — `is_round()` now excludes `_r<n>`. (2) `reactions.json`
  `clip_timings` gave `st_bump` 72 f where the sim's clock is 82 (pat 30 + walk-on 40 + turn 12); the sim is the
  authority, so the table and its marks were corrected. (3) `curtain:*` and `cold:*` are not `ClipMap.SCHEMA_KEYS`
  families — those rows resolve from `clip_rules.json`, so they were removed from both rigs' `map.json`.
  **Open issues (unchanged or new, none blocking):** the `jelly_helmet` COSTUME look exists only as a rig prop, so
  it vanishes when COLD OPEN's clip ends; the view drives the specs prop on/dangling only, so EYE-POPPING NEWS'
  `magnifier` state never shows; `tools/audio/clip_events.py` needs numpy, which this machine lacks, so the 118 new
  clips' sounds are placed on their contact frames but not yet published in the s2-sound table (only the four T3
  beats, which were already published, are matched exactly); a PropSim launch at reaction speeds drifts, so
  LIFT-OFF hides the paper instead of throwing it. Review: `docs/review/w0-anim/index.md`.
