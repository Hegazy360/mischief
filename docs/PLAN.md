# Mischief Next Door — Build Plan (v1.0)

Design: `docs/GDD.md` (binding). Contracts: `docs/TECH.md` (binding). Status: `docs/PROGRESS.md`.
Task briefs (self-contained, one per task): `<scratchpad>/mnd/tasks/<key>.md` (Stage 2: `s2-<name>.md` + `s2-index.md`); task reports:
`<scratchpad>/mnd/reports/<key>.md`.

## 0. How we build
- **Stages** run as batches of parallel agent tasks with **disjoint file ownership** (TECH §1, §13). The
  orchestrator commits after each batch, runs one Godot import on the real project, registers autoloads, and runs
  the full test + lint + solver suite before the next batch.
- **Gates** stop the line: Gate 0 (Sneeze & Cast, early Stage 2), the **Fun Gate** (end of Stage 2, owner on his
  phone), one **owner check per Act** in Stage 3, and the release check. Content never outruns a failed gate.
- **Meta comes last.** Nothing from GDD §8 Stage 4 is built before the Fun Gate passes.
- Every task ends with: tests green in its sandbox, its lints green, review artefacts in `docs/review/<key>/`
  that the agent actually looked at, and a report listing APIs, verification, deviations and requests.

| Stage | What | Exit |
|---|---|---|
| 1 Foundation | 10 parallel tasks (below) | every module builds and tests alone; integration pass green |
| 1i Integration | orchestrator + a short fix task | autoloads registered; real data loads with 0 errors; solver runs P/N1/N2 |
| 2 Vertical slice | Prologue + Nights 1–2 at final polish | Gate 0 passed early; automated pre-gate green |
| Fun Gate | owner plays the debug APK | all 8 owner checks (GDD §10.4) |
| 3 Content | Act I rest → Act II → Act III + Gala, one wave per Act | owner check per Act |
| 4 Meta + FTUE + polish | Playbill, Encores, Programme, cold opens, polish passes | full playthrough review |
| 5 Release | signed builds via CI | release checklist |

---

## 1. Stage 1 — FOUNDATION (10 parallel tasks)
All ten start together; none needs another to finish first. Each codes against TECH.md and uses **soft hooks**
(TECH §13) for modules built in parallel. Autoload registration and `project.godot` edits are done by the
orchestrator in the integration pass (tasks instantiate their autoload scripts directly in tests).

### 1.1 `sim` — the deterministic gameplay simulation (critical path)
- **Goal:** TECH §3 in full for the Prologue and Act I: content loading/validation, nav, Hush, Bellows (routine,
  gates, detours, entry warning, look-back), senses (specs rule, "?" meter, near miss, bump, watched hiding,
  in-use spots), chase / search / on guard / door slam / Chase Trips, caught + Lecture timing + tomatoes + Hook,
  pranks (steps, items, restock, triggers, conditions, fizzles, resume/fixup hooks, one punchline at a time),
  reactions (tier lengths, suppressed, travel, knock-on Double Acts), temper (tiers, hold/decay/pauses, Running
  Gag links, Meltdown, Exhausted), residue → fix-up → combos, scoring (normalisation, multipliers, bits, the four
  bonuses), Script goals + stars + Big Number, squeak bits / ear pips / lure / fatigue, Mirror, Mirror rounds,
  Director (gates, cues, safety net, can't-fail), Conditions language, events, state hash, clone, `sim_run.gd`.
  Beryl, Delphine and the panto bit are Stage 3 (`s3-sim-cast`): leave null-safe seams.
- **Owns:** `game/sim/**`, `game/autoload/content.gd`, `game/tools/sim_run.gd`, `game/tests/sim/**`,
  `docs/review/sim/`.
- **Depends on:** nothing to start (own fixtures in `tests/sim/fixtures/`); reads real `data/` via soft checks.
- **Exposes:** `SimWorld` (§3.4), commands (§3.5), events + `SimEvents.is_laugh` (§3.8), `ContentDB` (§3.2),
  `Conditions` (§8.2), `SimConst`.
- **Consumes:** data schemas TECH §4 (house from `art-house`, the rest from `content`).
- **Acceptance:** scenario tests for every GDD §4.7 fairness rule and every system listed above (list in the
  brief); golden hash test; `clone()` equality; perf ≤ 0.05 ms/tick (18,000 ticks ≤ 1.5 s); `ContentDB.validate()`
  on the real data dir returns 0 errors or a precise request list; `sim_run.gd` prints events for a command log.
- **Effort:** XL (one long session). Internal order in the brief; Mirror rounds may slip to Stage 2 if needed
  (report it).

### 1.2 `rig` — cutout rig and animation system + texture atlases + animation QA tools
- **Goal:** TECH §5.3 and §11: pure `RigDef / PoseLib / ClipLib / RigSampler / Springs / FaceState / PropSim /
  ClipEvents`, the `RigPlayer` node (atlas-backed, ≤ 12 draw calls per character), tier/suppressed remapping,
  smears, `HiResTex` (port) + `AtlasBuilder`, the animation and rig lints, `anim_sheet.sh` (rig, pose + silhouette,
  contact, onion, curves) and `capture.sh` (Movie Maker → GIF), the `AnimViewer` dev scene with hot reload, and a
  `_mannequin` rig with demo clips proving every feature.
- **Owns:** `game/view/rig/**`, `game/view/tex/**`, `game/scenes/dev/**` (except `house_preview/`),
  `game/tools/anim/**`, `tools/anim/**`, `tools/scripts/anim_sheet.sh`, `tools/scripts/capture.sh`,
  `game/data/rigs/_mannequin/**`, `game/data/anim/_mannequin/**`, `game/art/chars/_mannequin/**`,
  `game/tests/rig/**`, `docs/review/rig/`.
- **Depends on:** nothing; if `art-hush` / `art-bellows` rigs exist at the end, run the rig lint and pose sheets on
  them and report findings.
- **Exposes:** everything in TECH §5.3; lint entry points; sheet/capture scripts.
- **Acceptance:** mannequin (≥ 14 parts, 2 hose limbs, face slots, a spring, a prop socket), ≥ 12 poses, 5 demo
  clips (idle loop, walk with stride, take, launch with a prop, squash landing), all lint-clean; unit tests (eases,
  stepping, mirror, crossfade, additive, springs, seeded blinks, props, tier lengths = TECH formula, atlas packing,
  every lint rule caught on a seeded bad clip); perf (2 mannequins ≤ 24 draw calls, sampler allocation-free); sheets
  + GIF for every demo clip; AnimViewer screenshot.
- **Effort:** L–XL.

### 1.3 `art-hush` — Hush (+ Pip skin), Clarence, Figgis, the Stalls
- **Goal:** final-quality SVG cutout parts and data for the player character and the small cast; the owner's cast
  sheet.
- **Owns:** `game/art/chars/hush/**`, `game/art/chars/figgis/**`, `game/art/chars/stalls/**`,
  `game/data/rigs/hush/**`, `game/data/rigs/figgis/**`, `game/data/rigs/stalls/**`, `tools/art/hush/**`,
  `game/tests/art/test_hush_rigs.gd`, `docs/review/art-hush/`.
- **Depends on:** nothing (own Python FK preview). **Exposes:** `data/rigs/{hush,figgis,stalls}` per TECH §4.7 with the
  binding part names; the Pip skin; the cast sheet. **Consumes:** TECH §4.7 schema; GDD §1.2, §9.1–§9.3.
- **Acceptance:** rig.json/poses.json/faces.json valid (own Python validator + GDScript test via soft hook to
  `RigDef`); ~20 parts incl. 8 glove textures; face slots (eyes 8, brows 5, mouths 8) and ≥ 12 presets; ≥ 40 poses
  covering every P0 Hush clip (GDD §9.4); Pip skin on identical part names/pivots; Clarence prop; Figgis bust
  (4 expressions); Stalls atlas (24 heads × 3 frames); preview sheets rendered by a Python FK compositor (rest,
  poses + 50 px silhouettes, expressions, the cast sheet at phone scale); warmth rule verified at 50 px and 96 px.
- **Effort:** L.

### 1.4 `art-bellows` — Horace Bellows
- **Goal:** final-quality SVG parts and data for the neighbour, including every residue and combo look and the
  temper tint.
- **Owns:** `game/art/chars/bellows/**`, `game/data/rigs/bellows/**`, `tools/art/bellows/**`,
  `game/tests/art/test_bellows_rig.gd`, `docs/review/art-bellows/`.
- **Depends on:** nothing. **Exposes:** `data/rigs/bellows` per TECH §4.7 (parts, faces, residues, tint, props, poses).
  **Consumes:** TECH §4.7; GDD §1.2, §5.4, §9.
- **Acceptance:** ~22 parts; bouffant × 7, sideburns × 3 states, specs × 4 states, 6 hands; faces (eyes 10, brows 6,
  mouths 10 incl. singing O × 3) and ≥ 16 presets; residue overlays for all 7 residues and the 4 combo looks;
  temper tint tiers; ≥ 50 poses covering every P0 Bellows clip; expression, residue and silhouette sheets at phone
  scale; valid data (as art-hush).
- **Effort:** L.

### 1.5 `art-house` — house geometry, ground-floor art, props, icons, the stage
- **Goal:** `house.json` for all 10 rooms with every canonical id (TECH §14); final art for porch, hall, parlour and
  kitchen (bg/fg layers) and every slice prop in all its states with outline sprites; greybox art for the other
  rooms; item icons (16) and activity icons (27); the stage (curtain, proscenium, footlights, vignette); STYLE.md.
- **Owns:** `game/art/house/**`, `game/art/icons/**`, `game/art/STYLE.md`, `game/data/house/**`,
  `tools/art/house/**`, `game/scenes/dev/house_preview/**`, `game/tests/art/test_house.gd`,
  `docs/review/art-house/`.
- **Depends on:** nothing. **Exposes:** `house.json` (TECH §4.1, ids TECH §14), room/prop/icon/stage art paths.
  **Consumes:** GDD §7.1 layout, §9.1 palettes.
- **Acceptance:** house.json passes its own schema + hotspot-rect checks (≥ 144, 24 px gaps, no overlaps, stacked
  shared objects); a preview scene renders each room from house.json; screenshots at 1200×540 of each final room at
  zoom 1.0 (with props, outlines, badges mocked) and a 0.5 overview; greybox screenshots; icon sheet; the curtain.
- **Effort:** L.

### 1.6 `ui` — UI kit, HUD, input, panels, settings/save
- **Goal:** TECH §5.9, §6, §7: theme + fonts, every HUD widget at GDD §3.8 sizes, `HudModel` + intents,
  `InputRouter` + `TapAssist`, panels (Script, pause, settings, loading card, results skeleton, pick strip), ports of
  Booby `settings`, `haptics`, `router`, `safe_area`, `ui_scale`, `fade_transition`, a new `save`, UI icons and
  glyphs, strings, `UiDemo`.
- **Owns:** `game/ui/**`, `game/art/ui/**`, `game/autoload/{settings,save,haptics,router}.gd`,
  `game/autoload/support/**`, `game/data/ui/**`, `game/tests/ui/**`, `docs/review/ui/`.
- **Depends on:** nothing (fake HudModel). **Exposes:** TECH §5.9 (HudModel, Hud intents, PipFrame), §6 (InputRouter,
  TapAssist), §7 (Save, Settings), Haptics and Router APIs. **Consumes (soft):** item/activity icons (`art-house`), the
  PiP texture (`view`), the curtain art (`art-house`).
- **Acceptance:** UiDemo screenshots at 20:9, 16:9, 4:3, with fake insets and left-handed, of every widget state;
  tests for gesture thresholds, edge exclusion, tap-assist priority and radius, verb latch + 250 ms hysteresis,
  150 ms two-thumb suppression, slide-off cancel, hold-ring timing, save atomicity + migration, settings
  persistence, haptics rate limit; a layout test asserting hit sizes, 24 px gaps and a target-free bottom-centre.
- **Effort:** L.

### 1.7 `view` — driver, world view, camera, FX, PiP, Stalls, audio director
- **Goal:** TECH §5.1–§5.8 and §5.10 (Stalls): `SimDriver`, `JuiceClock` (port), `CameraDirector`, `WorldView` /
  `RoomView` / `PropView` / `HotspotView` / `CharacterView` (+ `map.json` format), `FxLayer` and all its pooled
  effects, `BustedCam`, `PipView`, `StallsView`, `AudioDirector`, and a `ViewSandbox` driven by a `FakeWorld`.
- **Owns:** `game/view/**` except `view/rig/**` and `view/tex/**`; `game/art/fx/**`; `game/tests/view/**`;
  `docs/review/view/`.
- **Consumes (soft):** `SimWorld` API, `RigPlayer` (capsule fallback), `Audio`, `house.json` (greybox fallback from
  GDD widths).
- **Acceptance:** ViewSandbox screenshots + frame sequences of every effect (list in the brief); tests for driver
  rates/ff/max ticks/pause, JuiceClock cap, camera smoothing and limits and gag-queue order, PiP rule and hide
  delay, audio tier mapping, pools without growth; perf log ≤ 150 draw calls p95 in the sandbox.
- **Effort:** L.

### 1.8 `audio` — procedural sound, voices, crowd, music, Audio autoload
- **Goal:** port Booby `tools/audio` and `autoload/audio.gd`; render the slice sound set, Bellows' phrase bank and
  the talking-tuba fallback, Clarence, the crowd (formant + fallback), stingers, adaptive stems and the 4 chain
  sections; `sfx_map.json`, `cues.json`; A/B review pages for the owner.
- **Owns:** `tools/audio/**`, `game/audio/**`, `game/autoload/audio.gd`, `game/data/audio/**`,
  `tools/scripts/gen_audio.sh`, `game/tests/audio/**`, `docs/review/audio/`.
- **Depends on:** nothing. **Exposes:** the Audio API (TECH §5.8), sound ids (`sfx_map.json`), `cues.json`.
  **Consumes:** sim event names (TECH §3.8), Settings volume keys (soft).
- **Acceptance:** deterministic render + `--check`; ≈ 60 slice SFX, the voice and crowd banks, music; Audio API
  (TECH §5.8) with no-repeat, buses, ducking, bar-synced chain switching; tests; slice audio ≤ 15 MB; review index
  with the voice and crowd A/B.
- **Effort:** L.

### 1.9 `solver` — solver bot, fuzz, lints, CI
- **Goal:** TECH §8, §10.5 (content, hotspot, IP lints), §12: `SolutionDef`, `Executor`, `Persona`, `Metrics`,
  `Planner`, `Invariants`, `Fuzz`, the CLIs and scripts, and the CI workflow.
- **Owns:** `game/solver/**`, `game/tools/solve.gd`, `game/tools/fuzz.gd`, `game/tools/lint/**`,
  `tools/scripts/{solve,fuzz,lint}.sh`, `tools/ci/lint_all.sh`, `.github/workflows/ci.yml`,
  `game/tests/solver/**`, `docs/review/solver/`.
- **Consumes (soft):** `SimWorld`, `Conditions`, content solutions.
- **Depends on:** nothing to start (MockWorld fixtures). **Exposes:** the CLIs, run reports, lints, the CI workflow.
- **Acceptance:** unit tests on fixtures (skip cleanly without the sim); every lint rule caught on a seeded bad
  fixture; CLIs return correct exit codes; CI updated; if sim + content exist at the end, a solve report for
  P/N1/N2 in `docs/review/solver/`.
- **Effort:** L.

### 1.10 `content` — the data: pranks, items, activities, reactions, episodes, solutions
- **Goal:** TECH §4.2–§4.6 and §4.9 data for all 32 pranks, 16 items, the activity library, reaction timings,
  residues/combos, Double Acts, all 12 episodes (Prologue, N1, N2 `final`; the rest complete `draft`), barks and
  Figgis cards, and authored solutions (ideal / required / slow) for P, N1, N2.
- **Owns:** `game/data/{items,pranks,activities,reactions,residues,barks}.json`, `game/data/episodes/**`,
  `game/data/solutions/**`, `game/tests/content/**`, `docs/review/content/`.
- **Depends on:** nothing (ids from TECH §14). **Exposes:** TECH §4.2–§4.6 data and §8.2 solutions.
  **Consumes:** house ids (TECH §14; cross-checked against `house.json` when it exists).
- **Acceptance:** a content test validating schema, canonical ids (TECH §14), normalisation (Σ 700 tenths), ≤ 7
  lines, card ≤ 25 words, one new rule per Night, cross references to house ids; a generated catalogue table
  (`docs/review/content/catalogue.md`) diffed against GDD §5.7 and §7.2 by eye and by script.
- **Effort:** M–L.

### 1.11 Stage 1 exit (integration pass)
- Orchestrator: commit; one import; register autoloads (`Content`, `Settings`, `Save`, `Haptics`, `Router`,
  `Audio`); update export filters; run tests, lints, `solve.sh all`, `fuzz.sh` (bounded).
- A short `s1-integrate` task applies cross-module requests from the ten reports (typed calls replace soft hooks
  where modules now exist) until everything is green.

---

## 2. Stage 2 — VERTICAL SLICE (Prologue + Nights 1–2 at final polish)
Briefs: `<scratchpad>/mnd/tasks/s2-<name>.md`; index (rulings, ownership, batches, Gate 0, pre-gate, request coverage,
review findings): `<scratchpad>/mnd/tasks/s2-index.md`. Lead decision **D1** (dead air) is binding: the gate is real time
with ⏩ (credited only where the game really runs at ×3, and for a first-timer only once the `ghost_ff` cue has taught
it) plus *visible* Bellows micro-gag beats (edge-bubble beats ≤ ⅓ of the credit) — ideal ≤ 20 %, required ≤ 25 %,
slow ≤ 30 %, worst gap ≤ 12 s — fixed in the data. Stage-2 rulings that shape every task (index §1): clip events own
every sound inside a clip, `cues.json` only event-level sound (L12); sim tick 0 = the curtain starting to rise (L13);
one clip manifest, `SliceClips` (L14); mid-batch solver checks compare against a baseline (L15); the Fun-Gate APK is a
release-template "profile" build with the device log (L17).

**Gate 0 — "Sneeze & Cast" (first deliverable of Stage 2):** ACHOO-RIA! end to end in the kitchen (rig, clips, sound,
laugh, camera, lint, in-game capture, a debug APK route: the stage door's `g0_sneeze` — senses off, a 3-icon card first,
and a short curtain call with **Again ▶** so the sneeze can be rewatched in seconds), the cast sheet (Hush vs Pip in
engine), the voice A/B and crowd A/B (on desktop, and on the phone *in context*: "Play Gate 0 with voice A / B"). The
owner decides: mime or Pip; formant baritone or talking tuba; formant crowd or fallback crowd; and whether the sneeze is
funny. **Mass animation (batch 2) starts only after it passes.**

| Key | Goal | Owns |
|---|---|---|
| `s2-sim` | D1 in sim + solver: `micro_gag` beats with visibility, the ⏩ gate (`SimFf`, personas) on restored expect keys (`warn_` form, `--baseline`), command feedback, `action_context()`, one-shot accessors + `SimOneshots`, last beats, view accessors, rules `combos`/`senses`, scenario routes, backstage/fix-up rules, lints (micro-gag cadence, coverage against `SliceClips`, hotspot, `--strict` forwarded), `--dump-cmds` | `game/sim/**`, `game/autoload/content.gd`, `game/tools/sim_run.gd`, `game/solver/**`, `game/tools/{solve,fuzz}.gd`, `game/tools/lint/**`, `game/tests/{sim,solver}/**`, `tools/scripts/{solve,fuzz,lint}.sh`, `tools/ci/lint_all.sh` |
| `s2-content` | dead air to the D1 targets at the source (N02 first prank ≤ 25 s, N01 detours ≤ 12 s, two kettle windows, loops ≤ 60 s, timed micro-gags every 5–8 s, edge share ≤ ⅓), gates on every route, `g0_sneeze` (ending, senses off), `combos: []` in N1/N2, scenario routes, the `ghost_ff` cue, Prologue clock, hints | `game/data/{items,pranks,activities,residues,barks}.json`, `game/data/episodes/**`, `game/data/solutions/**`, `game/tests/content/**`, `tools/content/**` |
| `s2-night` | NightScene; Boot → curtain → live Prologue (tick 0 = curtain, per-Night warm-up); Night flow, pause/back/background, retry ≤ 1.5 s, time-bound curtain call + Gag Reel, "To be continued", save hooks, Playbill stub; debug stage door (Gate-0 route + card, in-context A/B, cast); device log + overlay inside DevShot; NightScene CLI flags; e2e driver (`slice_all`, `tap_accuracy`); a real APK checked here | `game/scenes/**` (except `game/scenes/dev/**`), `game/tests/night/**`, `game/autoload/dev_shot.gd`, `game/tools/e2e.gd`, `game/tools/e2e/**`, `tools/scripts/e2e.sh`, `game/export_presets.cfg` |
| `s2-view` | the clip contract (map-key schema, one-shot table, `clip_rules.json`, `SliceClips`); real RigPlayer clips instead of puppets; reactions + tiers + last beats + knock-on variants; temper/residue mapping; micro-gag overlays; director-cue and caught/Lecture staging; sound delays in view time; hidden eyes; stairs; PiP/Busted/`MomentRecorder` with rigs; pre-roll; queued-tap FX; haptics; every view request | `game/view/**` (except `game/view/{rig,tex}/**`), `game/art/fx/**`, `game/data/anim/clip_rules.json`, `game/tests/view/**` |
| `s2-rig` | overlay clips, `decor` event, lints A23–A29 + `--strict`, AnimViewer flags + in-game capture (P0), the art requests to rig, ≤ 0.25 ms per character, mipmaps + lazy looks + `TexStats`, per-path atlas scale | `game/view/{rig,tex}/**`, `game/scenes/dev/**` (except `game/scenes/dev/house_preview/**`), `game/tools/anim/**`, `tools/anim/**`, `tools/scripts/{anim_sheet,capture}.sh`, `game/{data/rigs,data/anim,art/chars}/_mannequin/**`, `game/tests/rig/**` |
| `s2-ui` | Gate-0 settings keys, `stage_door` route, CARD_ALIASES, the Stage-2 string key sets, TapAssist stacks, Hud-owned PiP, edge-bubble emotes, world ghost finger, Figgis chip rig, Script flash, curtain-call results (live buttons, why line), settings complete, MSDF, polish in the real scene | `game/ui/**` (except `game/ui/ftue/**`; incl. the fonts' MSDF import flag), `game/art/ui/**`, `game/autoload/{settings,save,haptics,router}.gd`, `game/autoload/support/**`, `game/data/ui/**`, `game/tests/ui/**` |
| `s2-art` | `st_tea` first; Gate-0 kitchen; slice rooms final with the real characters (incl. the visible upper band + conservatory edge); hidden-eye gaps; gag props; decor frames; cold-open sets; title card; atlas hints | `game/art/house/**`, `game/art/icons/**`, `game/art/STYLE.md`, `game/data/house/**`, `tools/art/house/**`, `game/scenes/dev/house_preview/**`, `game/tests/art/test_house.gd` |
| `s2-anim-bellows` | G: the sneeze end to end (+ rig requests, stool prop). M: every slice Bellows clip in the order the player meets them (Prologue set first, then cold opens, Night 1, Night 2) + `map.json` | `game/data/anim/bellows/**`, `game/data/rigs/bellows/**`, `game/art/chars/bellows/**`, `tools/art/bellows/**`, `game/data/reactions.json`, `game/tests/art/test_bellows_rig.gd`, `game/tests/anim/test_bellows_clips.gd` |
| `s2-anim-hush` | G: Gate-0 Hush set + the cast sheet (+ R04/R08). M: every slice Hush clip (Prologue set first), Figgis clips, the Stalls `tiers.json` | `game/data/anim/{hush,figgis,stalls}/**`, `game/data/rigs/{hush,figgis,stalls}/**`, `game/art/chars/{hush,figgis,stalls}/**`, `tools/art/hush/**`, `game/tests/art/test_hush_rigs.gd`, `game/tests/anim/test_hush_clips.gd` |
| `s2-sound` | G: the sneeze in context, the clip-event split (L12), `Audio.preview`, the voice/crowd A/B. M: every cue (incl. the director laughs and the title slam), per-object SFX, voice placement, music transitions, measured loudness + sync, losers deleted | `tools/audio/**`, `game/audio/**`, `game/autoload/audio.gd`, `game/data/audio/**`, `game/default_bus_layout.tres`, `tools/scripts/gen_audio.sh`, `game/tests/audio/**` |
| `s2-ftue` | Prologue cues on screen (Figgis, ghost fingers, nudges, the ⏩ lesson), hint ladder 1–3 with the ghost demo (always on), loading-card vignettes, N1–N2 cold opens (the cue *schedule* stays content's) | `game/ui/ftue/**`, `game/data/anim/cold/**`, `game/data/ftue/**`, `game/tests/ftue/**` |
| `s2-integrate` | alone after batch 2: every route and scenario replayed in NightScene with the real clips, 0 fallbacks per clip id, mapping/timing/staging fixed in the view, scenes and maps, in-game strips of every gag, clip requests for `s2-fix` | (alone) `game/view/**` (except rig/tex), `game/art/fx/**`, `game/scenes/**` (except dev), `game/data/anim/clip_rules.json`, `game/data/anim/{bellows,hush,figgis}/map.json`, `game/tests/{view,night}/**`, e2e files |
| `s2-fix` | alone-running round that applies every open cross-module request (after `s2-integrate`; after each failing QA round) | exactly the files in its request table (it runs alone) |
| `s2-qa` | `pregate.sh`, slice integration tests over whole routes, fresh-reviewer gag scores + mute test on opaque frame strips, perf charts (RigPerf medians), local APK checks, the Fun-Gate kit, TECH.md + PROGRESS.md fold-in, CI job | `game/tests/slice/**`, `game/tests/{run_tests,test_base,test_smoke}.gd`, `tools/scripts/pregate.sh`, `.github/workflows/ci.yml`, `docs/review/{s2-qa,mute_test}/**`, `docs/TECH.md`, `docs/PROGRESS.md` |

Each task also owns `docs/review/<key>/` (and refreshes its Stage-1 review folder). The authoritative globs are in
`s2-index.md` §3 and each brief's §2.

**Batches:** P pre-flight (commit the CI fix; CI green) → **batch 1** (10 in parallel: sim, content, night, view, rig,
ui, art, anim-bellows[G], anim-hush[G], sound[G]) → **Checkpoint G** (GDD fold-in of the content deviations; Gate-0 APK
with `boot_config` = `stage_door`, owner decisions; loop on the sneeze until it passes) → **batch 2** (anim-bellows[M],
anim-hush[M], sound[M], ftue) → **I: s2-integrate** (alone) → **F: s2-fix** (alone) → **batch 3: s2-qa** (alone, last)
→ FAIL: s2-fix round → s2-qa re-run … → PASS: Fun-Gate profile APK (`boot_config` = `auto`).

**Automated pre-gate (all green; `tools/scripts/pregate.sh`, exact rows in `s2-index.md` §6; run with nothing else in
the container):** import metadata; full suite (skips only those listed in `allowed_skips.md`); strict lints (content
incl. micro-gag cadence + clip coverage against `SliceClips`, hotspot, IP, anim A23–A29, rig); art + audio validators;
every route's own expect block plus the N1/N2 star and applause bands, no `warn_` keys left; the Prologue laugh clock;
dead air per D1 incl. edge share ≤ ⅓; planner proofs; the Gate-0 route; fuzz 200 (incl. no combo where forbidden); clip
coverage + lengths; slice integration over the full replay of every route and scenario (0 fallbacks per clip id, 0
puppets/greybox, 0 texture pages built during play, no doubled sound) + the APK's contents; the launch clock relative to
the curtain (absolute desktop time reported, not gated); ≥ 6 laughs in 60 s in the real game with every director laugh
seen and heard; 60 fps proxy p95 ≤ 150 draw calls with Gag-Cam + PiP + particles; ≤ 0.25 ms per character (RigPerf median
of 5); retry ≤ 1.5 s, backgrounding pauses, tap accuracy ≥ 19/20, a time-bound curtain call; mute test ≥ 4/6 on frame
strips (≥ 2 Prologue gags); reviews ≥ 4/5 funny on every Prologue gag and Night 1's first prank, ≥ 3/5 on the rest;
audio and APK budgets (debug and profile APKs built locally).

## 3. The FUN GATE (owner, the profile APK — release template with the device log —, his own phone, no coaching)
Reviewers prepare: a clean install build, the device log exporter (plus a screen recording of the first minute from the
app icon), a one-page "what to try" card (never read aloud before he plays). **Pass = all 8 checks of GDD §10.4** (first laugh ≤ 10 s and first prank ≤ 30 s from launch; ≥ 5
laughs in 10 min; unprompted replay; 9/10 destination calls; no unfair catch with the ≥ 1.0 s "?" in the log; ≤ 1
misfire in 20 taps on a 60 px target, readable ring, pan never moves Hush, never "nothing happened"; 60 fps; "funnier
than Booby within a minute"). **Fail** → the response table in GDD §10.4; Stage 3 does not start; the slice
iterates until it passes.

## 4. Stage 3 — CONTENT (one wave per Act, owner check after each)
| Wave | Tasks (keys) | New work |
|---|---|---|
| 3A — Act I rest (N3, N4) | `s3-sim-cast` (Beryl, Delphine, panto, herding, witness — starts now so Act II isn't blocked), `s3-art-upstairs` (landing, bathroom, bedroom final art + props), `s3-anim-act1` (upstairs activities, archetypes POOF, DROP_ON, SURF_OUT, SQUEAKY_VOICE, SCARE_LEAP, STEAM_DUEL, FEATHER_BURST, IN OVER HIS HEAD, Meltdown b/c, combo beats), `s3-content-act1` (N3–N4 final + solutions), `s3-sound-act1` | owner check: Act I |
| 3B — Act II (N5–N7) | `s3-art-beryl`, `s3-art-garden` (conservatory, garden), `s3-anim-act2` (Beryl set, garden activities, BALLOON_CHASE, HEADBUTT_LAUNCH, GOAT_KISS, GRAND EXIT, KIDDING AROUND, panto set), `s3-content-act2`, `s3-sound-act2` | owner check: Act II |
| 3C — Act III + Gala (N8–N10, G) | `s3-art-delphine`, `s3-art-dressing` (dressing room, garden stage, spotlight), `s3-anim-act3` (Delphine set, host/tango/cloak/polish, COSTUME_BURN, SUPPRESSED, IT TAKES TWO, SPOTLIGHT STEALER, remaining cold opens), `s3-content-act3`, `s3-sound-act3` | owner check: Act III + Gala |

Before 3A: record the measured cost of one prank end to end (from Stage 2) in PROGRESS.md and confirm the budget.

## 5. Stage 4 — META + FTUE + polish (only after the Fun Gate)
`s4-playbill` (menu, Playbill wall, unlocks), `s4-encores` (3 remix lines per Night, roses, new goal kinds in the
sim by request), `s4-programme` (seen tracking, gallery with silhouettes), `s4-ftue-polish` (all cold opens, cards,
Figgis introductions, settings complete, accessibility pass), `s4-polish` (juice, perf and mix passes on device),
`s4-review` (solver full-game run, review agents on every gag, owner playthrough).

## 6. Stage 5 — Release
`s5-release`: version/codes, icon and splash, landscape store screenshots, permissions audit (VIBRATE only), release
signing and AAB through CI secrets (`android.yml`), iOS export notes, device matrix (2 Android budget/mid, 1 iPhone),
final PROGRESS sign-off. The debug preview APK keeps building on every push to `main`.

## 7. Cut order (if late) and never-cut list
Cut in this order: the Programme → Encores → the Gala's CURTAIN CALL Double Act (keep the signature) → merge Night 9
into Night 10 → the T3 last-beat pool to 2 → Delphine's high C (glasses sight only) → Act III to 2 Nights.
**Never cut:** the telegraphs (bubble, glyph, stare strip, entry warning), the Busted Cam, the Gag-Cam and PiP, laugh
tiers, P0 reaction polish, the solver and fairness gates.
