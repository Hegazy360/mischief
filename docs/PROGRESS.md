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
- 2026-11-02 — Owner: the gameplay is too basic and not engaging; review it and the process that produced it.
  Measured review in `docs/review/depth/index.md`. (1) **Tooling bug fixed:** `e2e.sh`, `fuzz.sh` and `solve.sh`
  called GNU `realpath -m` while `lib.sh` has exported the portable `mnd_abspath` since 2026-10-30, so all three
  died at argument parsing on macOS — the owner's end-to-end review, fuzzer and solver reports had been broken
  (the newest e2e report on this machine was a stale 31 Oct file). `fuzz.sh` and `solve.sh` now source `lib.sh`.
  Verified: `e2e.sh n01_ideal` + `--shot-seq` writes frames, `solve.sh` 3/3 routes, `fuzz.sh` 8/8 runs. CI is
  ubuntu-only, so nothing caught it. (2) **Measured the ideal route of Night 1** (the best possible play): 138.2 s,
  37 inputs, 6.4 s total rig-button time, **76.9 s (56 %) on fast-forward**, longest no-input gap 27.1 s, 5 live
  pranks of which all 5 are Script lines. `alive_by` shows the dead-air gate is 56 % satisfied by things the player
  watches, so a Night with zero inputs could pass it — the gates measure presentation, not agency, which is why
  every gate is green and the game is dull. (3) Root cause is the authored-one-off content model: one rig point and
  one trigger per prank, 24 of 32 pranks with a single reaction variant, chaining as a 6-entry lookup table, and
  ~28 of 33 rig points inert per Night answering with `ui_nuh_uh`. (4) Seven ranked gameplay changes (P1 default
  world reaction, P2 two ways per station, P3 more pranks than required, P4 feed the Running Gag fuse, P5 un-nerf
  Clarence, P6 three reaction variants, P7 Rehearsal) and six process changes (Q1 agency metrics as gates incl.
  `route_diversity` from the existing Planner beam search, Q2 run the never-run Fun Gate before more content,
  Q3 macOS CI, Q4 demote the BINDING GDD + a design-spike lane, Q5 captures not stills, Q6 brief by goal+metric).
  No gameplay code or content changed.
- 2026-11-02 — Owner: start with P1 + P5 (`docs/review/depth/index.md`) and judge whether they move the needle before
  anything bigger. **P1 — Meddle, "the house is a toybox" (GDD §5.6).** Every rig point that carries no prank tonight
  takes a Q hold (`meddle_start` → `meddled`): the prop sits askew (PropView tilts it 0.13 rad about its foot; the
  gold badge goes out) until Bellows walks toward it in its room (≤ 220 px, ROUTINE / DETOUR walk, not blinded) and
  stops for 1.0 s to put it right — a path pause (`NavPath.AUX_NOTICE`, `notice {hotspot, variant, len, vis, score}`),
  three rotating flavours (`oneshot:notice`: suspicious / straighten / peer), his "hmph" + a titter, +3 temper, and
  **+1 Applause the first time per prop** (a bit, label `notice`). New `sim/systems/meddle.gd` (state in the hash and
  the clone), `rules.meddle` (default true), `hotspot_state.meddle / .meddled`, `meddle_progress_pm()`,
  `action_context.meddle`; tonight's props stay the Script's (`nothing_to_rig` as before); a notice counts as a visible
  beat for dead air (`SimEvents.is_visible_beat`, `Metrics.beat_kind`). Night 1 now has **12 props that answer** in
  its three rooms where it had 5. **P5 — Clarence is a toy.** The head turn rotates three flavours (`head_turn
  {variant}` → st_head_turn / st_look_back / st_suspicious, each with its own grunt), the Clarence ring no longer greys
  under lure fatigue (the "PIPE DOWN!" shout is the joke), and an unheard squeak makes Hush glance at the Stalls.
  **Verified:** suite 1,113 green (test_meddle ×7, head-turn rotation, golden regenerated with a reason: new hashed
  state only), `lint.sh --strict` 144 clips / 0 / 0, solver 21 / 21 unchanged to the decimal (no route meddles),
  fuzz 72 / 72 with the random bots now meddling (every fairness invariant held), import meta OK; captured in the
  real Night 1 (`/tmp/mnd_meddle2`): Applause 1 → 2 as he fixes the chandelier then the fan, "+1" stamps, the fan
  visibly askew on its hook. **Open:** `st_double_take` (18 f, no loop) cannot serve a 60-tick notice — a 60 f
  double-take would be the best third flavour; the meddle hold shows the generic HOLD tag (a "FIDDLE" tag is a
  strings.json + action-button change); the fridge shelf has no visible idle art, so its askew state is invisible.
  QA guide: `docs/review/depth/qa_p1_p5.md`.
- 2026-11-04 — Owner: P1/P5 is better but still the same game; wants completely different animations and
  mechanics, a redesign from scratch before more complexity; look at the options first (redesign, new engine, or
  bigger improvements). Wrote `docs/review/pivot/index.md`: the test a pivot must pass (the player causes the comedy
  with their hands; animation that is not hand-keyed; judgeable in a week on a phone), a reuse table per module, five
  options with keep-% and a one-week spike each — A Physics Toybox (Goose/Octodad lineage, ~35 % kept, highest
  ceiling and highest tuning risk), B Set the Stage (rehearsal → performance contraption builder, ~55 %, keeps the
  deterministic sim and solver, makes the chain fantasy the core verb), C The Chase (pursuit with real-time traps,
  ~50 %, cheapest to feel), D Board Farce (turn-based, ~75 %, the safe fallback, fails the brief), E stay-and-deepen
  (the baseline the spikes are judged against). Engine: stay on Godot — the diagnosis is design, every option is
  buildable in Godot 4 (Rapier2D for joint chains), and the review toolchain is the owner's only instrument.
  Recommendation: spike B and C in parallel in `game/spikes/` on a shared procedural ragdoll/spring cast, two weeks,
  decide on the phone with a five-question gate. P1/P5 stay on the tree, uncommitted, as the proposed last change on
  the current design.
- 2026-11-05 — Owner: build spikes A and C as samples before choosing a direction. Built in `game/spikes/`
  (throwaway: no tests, no lints, no content JSON; the shipping game untouched — suite 1,113 green, all lints
  green, `solve.sh n01 ideal` identical to the decimal, import meta OK). **Shared procedural cast**
  (`spikes/common/rag_cast.gd`, ~320 lines): rebuilds both characters from the real rig.json and the real SVG
  parts, then drives them with **no keyframed clips at all** — an active ragdoll (every joint an angular spring
  behind one `muscle` number; `hit()` drops it to 0, the body tumbles, settles, and the muscle ramps back for a
  scramble-up), a procedural sine walk that works at any speed, and jiggle springs on the bouffant, cravat, coat
  tails and beret. Bench `spikes/common/CastTest.tscn`: **jitter 0.07, pops 0, smooth 97** (library band
  0.14–0.25; the retired 3D cast scored 0.42). **Spike A** `spikes/toybox/` — eight rigid-body props in the real
  parlour and kitchen, drag to haul and fling, anything over 520 px/s knocks him flat, then he gets up, notices
  the mess, carries it home and resumes (the Goose tidy-up loop). **Spike C** `spikes/chase/` — three real rooms,
  he pursues and never stops, four trap kinds, and setting a trap costs 0.42 s crouched while he closes; the
  house has two ends. Chase reports **no frozen frames and no pops** across a 9 s run; the toybox's one 1.3 s
  frozen stretch is him lying on the floor. Both take `--demo` for a scripted capture. **Three bugs the spikes
  found and fixed** (all in the ragdoll, all the kind only play reveals): limp limbs with only gravity torque
  collapse into an unreadable heap and need residual tone; settling on a per-frame ground flag never fires
  because the contact point moves as the body rotates (0.18 s coyote window); spin needs air drag or a thrown
  body pirouettes onto its head. Notes `docs/review/pivot/spikes.md`, artefacts `docs/review/pivot/spikes/`,
  QA guide `docs/review/pivot/qa_spikes.md` (five questions, and how to read each answer).
- 2026-11-05 — Owner: the spikes are the same animations and style and play worse; a complete pivot; research
  the best options for a one-owner, AI-agent team to make a great mobile game in 2026. Wrote
  `docs/review/pivot/2026_options.md`. Diagnosis: every round kept the cast, the house and hand-keyed comedy
  animation fixed, and hand-authored comedy animation is the worst-fit medium for an agent team (agents cannot
  see motion or judge timing; this repo's effort went exactly there). Market: mobile mature (+1–3 %), paid
  downloads tiny, premium lives on Apple Arcade / Netflix and on Steam-first indies; every small-team game that
  reached phones (Balatro, StS, Luck be a Landlord, Peglin, Backpack Hero, Mini Metro, Thronefall, Ball x Pit)
  is systems-dense, art-light, simple-input, synergy-driven, short-session — the only shape two people finish
  and the shape agents are best at (content as data, balance by simulation, LLM playtesters now track human
  difficulty r≈0.87, art that is code or curated stills). Options: 1 systems roguelike (1a theme preserved
  as a prank-chaining run, 1b clean slate), 2 minimalist systems strategy, 3 low-poly 3D toy sandbox on
  library assets, 4 hybrid-casual F2P (wrong business), 5 narrative/puzzle (low fit). Engine: Godot unless
  3 or 4. Recommendation: Option 1, Steam + mobile from day one, no animator anywhere in the pipeline;
  prototype 1a and 1b in parallel over two weeks (verb hunt → paper + simulated → playable portrait →
  art-direction contact sheet → owner plays), five-question gate. Nothing built; no code changed.
- 2026-11-06 — Owner: start with Option 1, build a prototype to try, and prepare the next options in case it is
  not good enough. Built **Prototype 1a "MISCHIEF RUN"** in `game/proto/mischief_run/` — the Mischief theme as a
  systems roguelike. Bellows walks a six-station routine; you rig prank cards onto stations; CURTAIN UP resolves
  it left to right with a chain multiplier on adjacent firings, residues that stick for the Night and feed later
  cards, and temper tiers that pay a bonus per hit; between rounds you draft one of three (prank or Encore);
  three Nights, four rounds each. One tap picks a card, one places it, one raises the curtain. **No sprites, no
  cast, no house, no animation frame anywhere** — the whole screen is primitives, two OFL fonts and a palette.
  `run.gd` is a pure deterministic engine (no nodes), so `sim.gd` plays it headlessly: balance was tuned before
  the UI existed and the report is 22 % full clears on random drafts / 52 % greedy, Night 1 100 % → Night 3 26 %.
  The simulator found two dead cards pre-play (THE BIG NUMBER could never fire on 3 Nerve; GOAD scores only
  indirectly). Content: 24 cards + 10 Encores in JSON, tunable without touching code. Verified: suite 1,113 green,
  lints green, import meta OK, no class-name collisions; the loop captured end to end with `--demo` (rig →
  resolve → chain → draft → next round → Night end). Known gaps: no sound, no save, no meta between runs, glyph
  art depends on system font fallback. Notes `docs/review/pivot/proto1_mischief_run.md`, QA + five-question gate
  `docs/review/pivot/qa_proto1.md`, and the prepared fallbacks — deepen 1a / new fiction 1b / minimalist strategy /
  low-poly 3D toy / verb hunt — routed by objection in `docs/review/pivot/next_options.md`.
- 2026-11-06 — Owner: the prototype did not respond to clicks — only "Rig at least one prank". **Fixed.** Cause:
  `project.godot` sets `pointing/emulate_touch_from_mouse=true`, so one click arrives as BOTH an
  `InputEventMouseButton` and an `InputEventScreenTouch` in the same frame. Every handler accepted both, so each
  tap fired twice: selecting a card and instantly deselecting it, which left nothing selected and produced
  exactly the reported message. All four input handlers (prototype card + root, and both spikes, which had the
  same latent bug) now ignore a second press in the same `Engine.get_process_frames()`.
  **Also added `--clicktest`**: a self-test that pushes synthetic clicks through the real input path and asserts
  card select / deselect / rig / take-back / CURTAIN UP, printing PASS or FAIL —
  `tools/scripts/shot.sh res://proto/mischief_run/MischiefRun.tscn /tmp/x.png 160 proto -- --clicktest`.
  Worth recording: the first version of that harness used `Input.parse_input_event()`, which treats the position
  as window pixels and then applies the stretch, so every synthetic click landed off-screen and the test
  "reproduced" a bug that was not there; `get_viewport().push_input(ev, true)` pushes in viewport coordinates and
  gives the true answer. Now 5/5 PASS, the scene renders, and both spikes still run.
- 2026-11-07 — Owner: the card prototype is repetitive and not fun; cards are not the path; proceed with Option 3.
  Built **Prototype 3 "THE KEEP"** in `game/proto/toyhouse/`: a low-poly 3D toy sandbox on **library assets used
  exactly as shipped**. The KayKit Adventurers Knight and Rogue (CC0, recovered from commit 1cd74f3, untouched) are
  animated **only** by the KayKit Character Animations library — six .glb files merged onto each character by bone
  name (`kay_actor.gd`); **not one animation frame is ours**. A stone hall of primitives with 35 physics props
  (crates, barrels, buckets, books, plates, a ball). Tap the floor to run, tap a prop to pick it up, tap the Knight
  while holding to throw at him. He keeps a four-station routine (sits, works, waves, patrols); a hard-enough hit
  plays `Hit_A` → `Death_A` → `Lie_Idle` → `Lie_StandUp` → `Idle_B`, then he chases if he sees you (`Running_A`,
  `Cheering` on a catch) or tidies what you moved (`PickUp` → carry → `Interact`) — the Goose loop. Walking into
  props shoves them. **Three bugs found by trace / self-test, not by eye:** (1) a frozen carried crate is a static
  collider and shoved the Rogue out of the hall in a feedback loop → held props leave every collision layer;
  (2) the chair's seat collider kept the Knight 0.4 m short of a 0.3 m arrival radius, so he never sat → visual-only
  seat + wider radius + a stall-equals-arrived rule for both actors; (3) the invisible front fence intercepted every
  tap, so nothing was ever grabbable by touch (the scripted demo masked it; `--clicktest` caught it) → the tap ray
  excludes the fence. **Verified:** `--clicktest` PASS 3/3 through the real input path; `--demo --trace` shows the
  whole loop in one run (sitting → throw → HIT → DOWN → GETUP → ALERT → TIDY_PICK → TIDY_CARRY); suite 1,113 green;
  lints green; import meta OK. Stills in `docs/review/pivot/spikes/keep_*.png`. Notes
  `docs/review/pivot/proto3_the_keep.md`; QA + gate `docs/review/pivot/qa_proto3.md`. Known gaps: one room, one NPC,
  no sound, no goals, no sight occlusion, native 2.2–2.6 m KayKit scale.
- 2026-11-08 — Owner: the 3D toy is still not enjoyable; not after a complex animation system but not a basic
  one either; consider building our own animation engine that works well with AI agents and produces accurate
  results; cartoonish like classic Neighbours from Hell if not harder; use open-source assets, do not design our
  own. Built **"the Bakery"** (`tools/bakery/`, output `game/proto/bakery/`): an animation engine whose entire
  authoring surface is one line of JSON per clip. Core is the **Cartoon Animation Filter** (Wang et al.,
  SIGGRAPH 2006) — convolving a motion curve with an inverted Laplacian-of-Gaussian yields anticipation,
  follow-through, overshoot and squash-and-stretch as arithmetic, with one `amount` knob. Pipeline: CC0 KayKit
  character + CC0 clip library → filter (pure numpy, **13 self-tests, no Blender**) → headless Blender EEVEE
  render (`--factory-startup`, deterministic) → silhouette-based frame prune → sprite strip + alpha-dilation ink
  outline → six objective validators on the rendered PNGs. Runtime is a PNG region blit, which is how the real
  Neighbours from Hell shipped (its gfxdata.bnd is RLE .tga sheets) — so every runtime rig bug this project has
  hit becomes structurally impossible. **Measured:** the filter raises silhouette change at 48 px from 31.9 % to
  42.6 %; twelve clips bake, prune, pack and validate in 34 s, all PASS. **Five bugs the harness caught that the
  eye would not:** Blender 4.4 slotted actions silently play nothing when an action is assigned across rigs; the
  clip library's own mannequin stands in every shot; `Rogue.glb` ships a stray unskinned Icosphere; world-axis
  framing clips a body lying along the camera axis (must be measured on the film plane); unbounded quaternion
  exaggeration flips the character horizontal, now capped by a hard angular ceiling proven to hold at amount 8.
  Also fixed: my own patch helper silently no-ops on an anchor miss, which hid two edits. Godot viewer
  `res://proto/bakery/Bakery.tscn` plays flat-vs-cartoon pairs. Suite 1,113 green, lints green, import meta OK.
  Design `docs/review/pivot/animation_engine.md` (incl. honest gaps: one angle, no faces, no hand props, global
  rather than per-joint filtering, fantasy cast); QA + gate `docs/review/pivot/qa_bakery.md`.
- 2026-11-08 — Owner: `godot --path /tmp/mnd_sandbox/play/game res://proto/bakery/Bakery.tscn` fails with "Cannot
  open file". Cause: the `play` sandbox is a private copy that only updates when `tools/scripts/sandbox.sh play` is
  run first, and it had last been synced on **30 Oct** — before every prototype. Not a bug in the scene; a two-step
  launch that is easy to miss. Fixed twice over: the sandbox is re-synced, and `tools/scripts/play.sh <scene>` now
  syncs and launches in one command (verified end to end with `--quit-after`). Every QA guide and
  `TESTING_ON_MAC.md` point at it instead of the two-step.
- 2026-11-06 — Owner: continue the headless-Blender Bakery; prefers the **flat** takes, the cartoon
  filter is too wobbly and unnatural. Filter is now opt-in (`amount` 0 by default); cartoon/flat pairs
  removed. Fixed what made flat takes play wrong as sprites: real-time sampling at the library's own
  speed with per-frame durations (was fixed 12 fps), seamless loops (first==last frame hitch), one
  pixels-per-metre per character with a recorded feet **anchor** (knocked-down knight was a third the
  size), per-pose floor contact (library sank a lying body 43 cm into the floor), foot-measured
  locomotion speed (`ground_speed_px`, no moonwalking) and `follows` chain offsets (knocked→getup
  jumped 34 px). Validator gained speed / seam / floor checks; prune and validate share one silhouette
  measure. 15 clips (added startle, interact, tinker, knocked, getup, sit, sit_idle) bake + PASS in
  ~80 s. `Bakery.tscn` is now a stage rehearsal from `game/proto/bakery/routine.json` plus a timed
  gallery; looked at still + 62-frame sequence. Suite 1,113 green, lints green, import meta OK.
  Notes `animation_engine.md` §7; QA `qa_bakery.md`. Open: civilian cast, props in hand, faces,
  shadow that follows a lying body.
- 2026-11-07 — Owner: round 2 good; now the actual characters, characters + movement only (props in
  hand and faces later, separately). Restored the October KayKit re-dress tools from git (`8d7c654^`;
  that cast was dropped only for runtime 3D glitches, which the Bakery removes) into
  `tools/bakery/cast/` (`build.sh`, `recolour.py`, `redress.py`; models are build output, git-ignored,
  built automatically by `run.py`). Fixed: AgX view transform washing the palette out (→ Standard +
  lower exposure); Bellows' hair curtains hiding his face (trim below the brow); no barrel (robe
  bulged on its own vertices); cravat sampling a Hush-only cell; jagged Breton stripes (tunic bisected
  at band edges before painting); camera 70°→50° so faces read; cast-wide ppm so relative size holds;
  Hush's idle pruned to 3 frames (per-clip prune floor). Manifest is now per character; `run.py`
  rewritten for a cast (`--who`, `--only`, 3 parallel Blender jobs). Hush 15 clips (walk=Walking_C,
  sneak, crouch, run, interact, tinker, pickup, throw, startle, hit, knocked, getup, wave, cheer),
  Bellows 13 (idle=Idle_B, strut=Walking_B, potter, run, interact, use, sit/sit_idle/stand, startle,
  hit, knocked, getup); all 28 PASS in 100 s from a clean checkout. Knight retired. `Bakery.tscn` is a
  two-actor scene (`routine.json`) + both galleries; looked at stills, close-ups and a 48-frame
  sequence. Suite 1,113 green, lints green, import meta OK. Notes `animation_engine.md` §8, QA
  `qa_bakery.md`. Open: Bellows' robe opening when lying down, shadow on a lying body, no library
  "freeze"/"angry" clip.
- 2026-11-07 — Owner: still too influenced by the first version's designs; keep the prankster,
  replace the other character completely. Bellows removed from the cast tools, manifest and sheets.
  New neighbour **Gus Thudd** (concept for approval: ex-strongman lawn inspector, green singlet,
  tangerine shorts, flat-top) built from scratch on KayKit's blank **Large mannequin** (CC0, from
  `1cd74f3`, now `tools/bakery/cast/src/`) by new `tools/bakery/cast/neighbour.py`, which colours
  each face by its dominant bone (the mannequin atlas shares cells across parts). Large and Medium
  clip libraries both drive him (same bone names). Fixes: per-character camera angle (Gus 65°) and
  ppm (~1.3× Hush); shorts stripe off the knees; sheets wrapped to ≤ 4096 px grids (flex was 11,648
  px — would not load on many phones) with `cols` in the json, viewer reads frames by row/col; clips
  planted per frame (Gus floated 30 px mid get-up) + per-frame validator. 29 clips PASS (Hush 15, Gus
  14) in ~90 s from clean. Long Godot captures went stale mid-session (window stopped drawing; logic
  proven by a step log); knocked→getup join verified offline (0.5 px). Suite 1,113 green, lints
  green, import meta OK. Notes `animation_engine.md` §9, QA `qa_bakery.md`. Open: GDD still
  describes Bellows (owner's call), Gus has no face yet (faces round).

- 2026-11-08 — Owner: keep improving the headless-Blender Bakery; flat takes preferred, the cartoon
  filter was too wobbly (still off everywhere, `amount` 0). Added the motion the core loop needs and
  the CC0 library lacks, **composed** from library poses (no hand keys, no filter): `bake.py` recipe
  fields `pose` (eased snap into one library frame, held dead still), `layer` (bones from a second
  clip, time-fitted to the loop), `tweak` (eased body-axis bone turns) and `repeat`; `run.py` passes
  them and labels them. Hush: 8 **FREEZE statues** (bow, kick, punch, tiptoe, discus, hurrah, ta-da,
  boulder; weak first picks wave/cast replaced after probing + ranking frames by silhouette reach).
  Gus: `search`, `fume`, `stomp`, `grab`. Fixes: re-imported library actions come back `.001`;
  cubic snap left a dead last frame (→ quadratic). 41 clips PASS in ~113 s from clean. Rehearsal now
  has Hush freeze in plain sight while Gus searches, stomps and lunges; gallery labels statues in
  ice-blue. Looked at stills, statue/reaction close-ups and a 31-frame sequence. Suite 1,113 green,
  lints green, import meta OK (12 new sidecars). Notes `animation_engine.md` §10, QA `qa_bakery.md`.
  Open: punch/discus/tiptoe the least distinct statues; statue-by-room is runtime work; faces, props.
- 2026-11-08 — Owner: keep the characters as they are; next, faces and props in hand. **Gus's face**
  (`neighbour.py` `add_face`): brows, bulb nose, handlebar moustache, ray-cast onto the blank Large
  head and skinned to `head`, in five expression sets (neutral, suspicious, angry with temper flush,
  shock, daze) named `Gus_Face.<expr>.<part>`; `bake.py` shows one per frame from `face` in clips.json,
  with timed switches (startle neutral→shock, knocked shock→daze, getup daze→angry). Hush keeps her
  painted face. **Props**: new `tools/bakery/props.py` (apple, kipper, duster, Clarence, saw, mallet,
  spanner, stopwatch, debug stick) parented to bones with `from`/`until` visibility, per-character
  scale and a character `wear` list (Clarence at Hush's chest). New Hush clips `saw`, `hammer`,
  `squeak`; props on tinker/pickup/throw/freeze_hurrah and Gus's `use`. Fixes: right hand is the far
  hand (props placed by debug-stick renders + side-by-side rotations); build.sh passed a failed Gus
  build on a stale .glb (now deleted first). 44 clips PASS in ~125 s from clean; rehearsal uses the
  props; looked at close-ups, game-size renders, stage still and sequence. Suite 1,113 green, lints
  green, import meta OK. Notes `animation_engine.md` §11, QA `qa_bakery.md`. Open: "suspicious" is
  subtle at ¾ view; no Hush expressions; remaining GDD items.
- 2026-11-08 — Owner: Gus fine; Hush gets expressions too; props grow per story; show a **gameplay
  sample**. Hush: shock / daze / grin overlays (shared `facekit.py`, used by both cast builders) over
  her painted neutral, placed by measuring the painted eyes off the atlas ink cell (±0.19, z 1.60);
  wired into startle/hit/knocked/getup/cheer/squeak/freeze_tada/freeze_hurrah; bake treats a missing
  "neutral" set as the bare face. **Gameplay sample** `Gameplay.tscn` + `gameplay.gd` +
  `gameplay.json`: one scripted 37 s Act in the parlour on the baked sheets with GDD staging — ghost
  taps, RIG ring (partial progress kept), FREEZE statue inspected up close ("Hm. New statue.
  …Tasteful."), awareness "?" + stare strip, Clarence squeak lure, hide (ghosted sprite + breathing
  badge), gramophone gag (spring glove + confetti), knocked→getup→fume vs cheer, Stalls + Applause;
  engine knows only verbs, timeline is one JSON event list; locomotion uses k-multiplied clip time so
  feet stay planted at game pace. Fixed two instabilities: shared `/tmp/bakery_frames` raced parallel
  worktree sessions (now keyed by checkout); unthrottled virtual display made real-time timelines
  crawl on camera (demo caps 60 fps). 44 clips PASS ~133 s clean; suite 1,113 green; lints green;
  import meta OK. Notes `animation_engine.md` §12; QA `qa_bakery.md`; evidence
  `spikes/bakery_hush_faces.png`, `bakery_hush_expr_clips.png`, `bakery_gameplay_{freeze,gag,seq}.png`.
  Open: sample is scripted (no touch input); knocked Gus nicks the table; next prop batch per story.
- 2026-11-08 — Owner: sample too basic; one full scene, from scratch in Blender, visually appealing,
  nothing else on screen (visual cleanup only). New `tools/stage/act1_set.py` (Blender, primitives
  only) models Gus's front room + proscenium/curtains/footlights/Stalls + moving props with pivots +
  HUD icons; `tools/stage/build.py` renders (~25 s), crops and writes `game/proto/act1/art/` +
  `layout.json`. New `res://proto/act1/Act1.tscn` (`act1.gd` + `act1.json` timeline): a 67 s looping
  Act — curtain, three rigs (gramophone, pedestal, butter), FREEZE inspected up close, Clarence lure,
  slip → pedestal → trophy bonk, gramophone glove → weight rack → dumbbells, bow, Curtain Call card;
  clean game HUD only. `play.sh` defaults to it. Looked at a 66-frame sequence and key stills. Suite
  1,113 green, lints green, import meta OK. Notes `animation_engine.md` §13; evidence
  `spikes/act1_*.png`. Open: sound, RIG button over the rack corner on 20:9.
- 2026-11-09 — Owner: Act I is the path; push its quality, same pranks and story. Set now renders in
  Cycles (GPU, denoised, relit for path tracing) with richer dressing (wallpaper motif, pendant,
  sconces, coat stand + tracksuit, shaker, LAWN INSPECTOR certificate, cactus, window light shaft).
  Moving props are baked as 3D frame sequences in Blender (door, pedestal topple, trophy tumble,
  dumbbells, spring glove, curtain gather, dust) instead of 2D-rotated sprites; `build.py` groups them
  (`seqs`), ~7 min full / `--engine eevee` ~1 min. Scene: eased camera direction (push-ins, punch-ins,
  wide finale), shake, dust, flight smear, landing squash, plant rustle, bow spotlight, motes, typed
  speech, layered shadows, warm cast tint, smaller HUD; capture flags `--fixed-step` / `--start=`.
  Looked at full-act sequences and beat stills. Suite 1,113 green, lints green, import meta OK. Notes
  `animation_engine.md` §14, evidence `spikes/act1v2_*.png`. Open: 22 MB art (atlas before phone),
  sound, re-bake cast under set lights.
