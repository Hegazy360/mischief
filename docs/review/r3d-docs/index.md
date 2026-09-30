# r3d-docs — GDD v1.2, TECH v1.1-3D, PLAN v1.1 (the 3D pivot, as designed)

What to judge: every REDESIGN_3D §6.6 amendment, the owner's style pick (D6) and the R3D rulings that change design are
in the GDD; the 3D contracts of `r3d-index.md` §7 are in TECH; PLAN has the R3D section; numbers match their sources;
unamended text is word for word. No renders: this task writes documents only.

Artefacts: `docs/GDD.md` (every changed paragraph marked "(v1.2)"), `docs/TECH.md` (new text marked "(v1.1-3D)", 2D-only
text marked "(2D, main only)"), `docs/PLAN.md` (§2b R3D + the stage table). Checks run: `python3 tools/content/catalogue.py
--no-write` (0 mismatches vs GDD §5.7 / §7.2), the IP lint's GDD string set (90 strings, identical to v1.1),
`python3 tools/art/house/lint_rects.py` (TECH §14 ids: OK), `SANDBOX=r3d-docs tools/scripts/lint.sh` (ip + hotspot OK; see
the report for the content-lint row owned by `r3d-content` / `r3d-sets`).

## GDD v1.2 — per amendment

| Section | What changed | Source |
|---|---|---|
| Header, changelog, conventions | v1.2; the 3D pivot line; a changelog entry naming every amended section; 3D conventions (metres, 1 m = 200 sim px, "at the base framing", 1200×540 = half) and a term map for unamended text (PiP → Bellows window, badge → glow / previews / tags, tray → chips, Figgis chip → bust) | REDESIGN §6.6; D6 |
| §0 Summary | Fairness row: the Bellows window (400×225, only while he is off-screen and the sim shows him); new **Look** row (3D toy characters, Hush = B's dimensions in A's style, simplified 3D stage, fixed side-on perspective camera); Audience row: Stalls hidden at rest | REDESIGN §6.6, §2.2; D6 |
| §1.2 Cast | 64 px silhouettes; sizes in metres and px (Hush 1.60 m = 434 px = 40 %, head ≈ 0.50 m incl. beret, gloves ≈ 0.20 m; Bellows 1.78 m = 471 px = 44 %, barrel 0.85 m, legs 0.45 m; 217 / 236 px at 1200×540); the 3D cast block (the owner's hybrid, B's arms, Bellows' fixes, face cards, value extremes + 4.8 px outline + rim, the head check R6 with `head_b` and the stage-door labels, Figgis restyled, Stalls 2D); Pip in 3D (skin on the skeleton; not built in R3D, D2) | REDESIGN §5.5–§5.6; index R6, R7, §5.2; D6; D7 |
| §1.3 | footlights are light (a warm gradient from the lip, 12 % → 0 by 1.2 m) | REDESIGN §5.3 |
| §2.1 | feedback column: BEFORE preview / DURING rig ring at the prop + button echo / AFTER armed look + red beret tag / TRIGGER tag wiggle, two-shot, dolly punch-in, spent + tag to the Script pip | REDESIGN §4.1, §6.6 |
| §2.3 Prologue | cue staging in 3D (projected ghost fingers, `sparkle_lever` = the spotlight pool, the dark hall + the Bellows window, the `laugh_*` stagings), no timing change; Boot rule 6 in 3D (every material warmed: no shader compiled during play) | REDESIGN §3.1, §4.4 N4, §6.3; index §5.1 |
| §2.4 | the PiP is the Bellows window; the gate unchanged via C8; `lean` counts adjacency-only beats only through the edge badge (`d1_lean`) | index R15 |
| §3 intro, §3.1 | left thumb = Clarence + chips; projected 3D tap rects (rect x/y × prop z ± 0.3 m, ≥ 144 px, back wall ≤ 10 m, ≥ 163 px at the back wall); pinch / drag within C1–C3; Map as the one-finger Overview | REDESIGN §5.5, §2.2, §6.6 |
| §3.2 | QUIET / LIVE states; the ring at the prop; the marble freeze + plinth; statues 5–8 may be R3; C4 | REDESIGN §2.4, §4.2; index §8.6 |
| §3.3 | Clarence bottom-left (S+32, H−B−200) 168×168; the contextual lure ring | REDESIGN §2.1 |
| §3.4 | one hiding spot per room in Act I; `hides` per Night (P00, g0, N1/N2); struck = not built + `cmd_rejected struck`; the in-use lesson from Night 3 (N2 without the clock case); hidden in 3D (eye card, desaturation) | REDESIGN §3.3, §6.2 C1/C2, §4.2 |
| §3.5 | badges replaced: verb glow / halo (rig `#FFC838`, hide `#5C9EFF`, take `#FFF4DB`, exit cream after ★), the active spot, passive previews, Hush's thought, needs clouds, item bubbles, his ring, the combine badge, the rig ring, the red beret tag, spent + tag flight; W1–W4, N1–N4, V1–V6; the Hints setting → Previews | REDESIGN §3.7, §4.1–§4.5 |
| §3.6 | the tray → carried-item chips only while carrying; the item stays on Hush; "item get" | REDESIGN §2.2, §4.2 |
| §3.7 | the whole camera section in 3D (FOV 30°, 7.5 m, y 1.9, pitch −4.2°, 269 / 226 / 322 px per m, 8.93 / 7.15 / 5.36 m, C1–C8, punch-ins S 6.52 / L 5.77 / M 5.36 / SIG 4.69 m ≥ 4.5), the Bellows window 400×225 / 704×396, C8, the `sim` / `lean` presentations with the 35 % share warning and the data-driven default, the Overview hidden in Act I, the floor-above gag dropped, peek, reduce motion | REDESIGN §5.2, §2.2, §3.1; index R15, §7.7, §7.9 |
| §3.8 | the HUD table and diagram replaced by REDESIGN §2 (four always-on pieces with rects, the contextual table, what moved into the panels, the placement rules, the middle band) | REDESIGN §2.1–§2.6 |
| §3.9 | his bubble 200×170 / icon 112 / ring 12 / glyph 60 / ear pips 3 × 24; stare strip, footprints, rings, pins, spotlight pool as floor decals at true radii | REDESIGN §4.2, §5.1, §5.8 |
| §3.10 | a one-line pointer to the 3D HUD's text sizes (see conflicts in the report) | REDESIGN §2.6 |
| §3.11 | Previews, Room dimming, Outline +50 %; the debug section (head, window mode, MSAA, render scale, N1/N2 previews) | REDESIGN §6.6; index §7.10 |
| §4.10, §6.5 | the Stalls hidden at rest, rising 60–150 px by tier | REDESIGN §2.2 |
| §6.4 | step 1 adds the spotlight pool (after 6 s idle); steps 2–3 via Hint in the pause panel | REDESIGN §4.4 N4, §2.3 |
| §7.1 | the 3D stage: units, depth bands, wing flats / proscenium / cheat-out, three set layers, the strike rule, density limits, plain walls, silhouettes, the reach ruling R5 (×1.5 / ×0.8, B's arms, reach row, reach position, bands, the stool and the mime step, Bellows never reaches up, view offsets), the value hierarchy, room light; locked rooms not built | REDESIGN §3, §5.1, §5.3, §5.5; index R4, R5, §7.6 |
| §7.2 | rule 4 (`hides`, the Set lines); Set lines for the Prologue, Night 1, Night 2 (rooms built / dark / not built, `hides`, live props per room, Night 2 without the clock case) | REDESIGN §3.1, §3.4, §6.2 |
| §9.1 | 3D Toy Box art direction: palette materials, shader-computed light, no real-time shadows, blob shadows, **look A's vinyl shading kept** (lilac terminator, bounce 0.14, sheen 0.10) inside the 66 % floor, the set's neutral fill, 4.8 / 3.4 px outlines (D7), halo, what stays 2D, SVG rules for 2D, CC0 only | REDESIGN §5.3–§5.4, §5.8; index §7.6; D6; D7 |
| §9.2 | 3D rigs (UAL 65-bone skeleton, ≤ 10k tris, ≤ 50 deform bones + jiggle, attachments, body slots, tint, face cards), Bellows (arm-out, ×1.8 teacup, bigger face), Hush (B's body, props, marble), Beryl / Delphine later, Figgis, readability minimums (the head-check bar), warmth rule kept | REDESIGN §5.6; index §7.3, R6 |
| §9.4 | the 3D pipeline (Blender pose language → baked clips + sidecars; ids and timed lengths unchanged; smear dropped), UAL locomotion, three reach bands × tiers + the two Prologue rig actions, glances in the view, the R3D 70-clip set (Hush 28, Bellows 42), the rest R3; "Sneeze 3D"; drafts | REDESIGN §5.7; index R2, R3, R19, §5.3 |
| §9.5 | voice / crowd defaults (formant) kept, A/B pages stay; pan by projected x | index R7; D6 |
| §10.2 | 3D per-character and per-room budgets; clips 70 in R3D, the rest R3 | REDESIGN §5.6, §3.3 |
| §10.3 | R0 → R3D (= R1 + R2) → R3 → R4; the R3D exit | REDESIGN §6.4; index exit |
| §10.4 | the 3D pre-checks (set / screen-rect / HUD / visibility lints, 3D perf incl. no shader compiled during play) + the readability review | REDESIGN §6.3; index §6 |
| §10.5 | risks X1–X9 merged | REDESIGN §6.5 |
| Appendix A | the owner's four complaints and the 3D decisions → sections | REDESIGN §0; D6; index |

## TECH v1.1-3D — per amendment

| Section | What changed | Source |
|---|---|---|
| Header | 3D view (Node3D world, Camera3D) + 2D HUD; the version note; "(2D, main only)" marking rule | brief §4.2 |
| §0 | principle 5 in 3D | REDESIGN §6.5 X1 |
| §1.1 (new) | the 3D module map + owners (index §4), the frozen replaced 2D files, the 3D export filters | index §4, R1; r3d-night §4.5 |
| §2 | 3D facing (yaw, never a negative scale), world units and axes, depth bands, reach row, scale; screen space; clip frames at 60 fps | index R4, R5 |
| §3.5, §3.8, §3.10 (new) | `cmd_rejected {why: "struck", target}`; `SimCtx.live_hotspots`; `SimVisibility.pip_reason` | index §7.5, §7.10, R15 |
| §4.1, §4.6–§4.8 | `house.json` frozen (C3); `hides`; 2D rig / clip formats marked (2D, main only) | REDESIGN §6.2; index R2 |
| §4.10–§4.13 (new) | `rig3d.json` (+ body slots, `anim.layers`, variants, D7 outline and face cells), the clip sidecar v2 + `.res`, map keys, `house3d.json` (prop frame, `visual_offset`, `hit_box`, `reach_pos`, landings, hand-offs), `previews.json`, `rig_actions.json` | index §7.2–§7.4, §7.10; D7 |
| §5 intro, §5.1–§5.10 | the 2D view sections marked; names kept | brief §4.2 |
| §5.11–§5.19 (new) | the 3D scene tree + warm-up + curtain call + stage door + `boot_config.json`; `RigPlayer3D` + the pure layer; `WorldView3D` / `SetList` / `House3D` / `Prop3D` / `CharacterView3D` / ClipMap 3D / `SliceClips.build3d`; `CameraDirector3D`; `PipView3D` + C8 + the two modes; decals, 2D overlays, the anchor API, `OverlayPlacer`; shaders, globals, the lighting model with A's vinyl terms, uniforms, layers, `MaterialWarm3D`; audio, HUD, settings; Stalls, Figgis | index §7.1, §7.4–§7.10; r3d-night §4.1–§4.3; landed view3d / hud names |
| §6, §7, §8 | input on projected rects; the new settings keys; `d1_lean`, retired N02 routes, invariants 12–13 | index §7.10, R15; `game/solver/invariants.gd` |
| §9 | the 3D budget table (60 fps p95, ≤ 150 / 250 draws, ≤ 150k tris, ≤ 10k tris / ≤ 50 bones / ≤ 4 draws / ≤ 0.25 ms per character, ≤ 8 CPUParticles3D, ≤ 250 MB via `RENDER_TEXTURE_MEM_USED`, 0 shader compiles in PLAY) | REDESIGN §5.6, §6.3; index §6 rows 16–17 |
| §10.1, §10.5 | the 3D test / lint layers; the 3D animation lint rules; the set, screen-rect, HUD, visibility and perf lints; the content-lint additions | r3d-anim §4.1.7; r3d-tools-b §4; r3d-content §4.4–§4.5 |
| §11.1 (new) | AnimViewer3D, `anim_sheet3d.sh`, RigPerf3D, SetPreview3D, LintShot3D, ViewSandbox3D, PerfProbe3D, capture on 3D, `tools/art3d/review/`, the reviewer fallback R17, the 2D reference frames | r3d-rig §4.4; r3d-sets §4.6; r3d-tools-a/-b §4; index R17 |
| §12 | Blender 4.5 LTS + setup scripts, the vendored CC0 UAL files + CREDITS, the committed look-dev references, the bake pipeline, `[shader_globals]`, CI on `r3d`, WIP pushes + the landed mirror | index §3.1, §3.4, §3.6–§3.7, R8, R16 |
| §13 | rules 7–10: CPU slots (`LP_NUM_THREADS=1`, `GALLIUM_THREAD=0`, Blender `--threads 1`), the R3D soft-hook rules, LANDED.md + resume, baselines and disk | index R10–R13, R16, §3.5 |
| §14 | the 3D ids: variants, new clip ids, map keys, sidecar events, `cmd_rejected struck`, `pip_reason`, report fields, settings / boot keys, set ids, shader globals, layers, material kinds (placed after **Items** so `tools/art/house/canon.py` still parses the hotspot list) | index §5.3, §7 |

## PLAN v1.1

| Section | What changed | Source |
|---|---|---|
| Header, §0, stage table | v1.1; Gate 0 (2D) verdict, R0, R3D, R3, Fun Gate = R4 rows; the 3D Gate 0 note | REDESIGN §6.4 |
| §2b (new) | R3D: why (the owner's words), the D6 pick, one build on `r3d`, the task table (18 keys, launch), batches + the queue + K / O checkpoints, the exit, deferred to R3, what comes next (R3, R4) | index §2–§3, §6, §8.6 |
| §3 | the Fun Gate is played as R4 on the 3D build | REDESIGN §6.4 |
