# r3d-docs report — GDD v1.2, TECH v1.1-3D, PLAN v1.1

## Files built (all mine per brief §2)
- `/home/user/mischief/docs/GDD.md` — v1.2 (2,042 lines). Every changed paragraph is marked "(v1.2)", and the changelog names every amended section. The text REDESIGN does not amend is word for word v1.1; the only exception is one paragraph in §2.3 ("Rooms…"), whose line breaks were reflowed with its words unchanged.
- `/home/user/mischief/docs/TECH.md` — v1.1-3D. New text is marked "(v1.1-3D)". 2D-only text is marked "(2D, main only)" and was not deleted.
- `/home/user/mischief/docs/PLAN.md` — v1.1. Adds the stage table rows (Gate 0 2D, R0, R3D, R3, R4) and the new §2b "R3D — the 3D slice".
- `/home/user/mischief/docs/review/r3d-docs/index.md` — per-amendment tables for GDD, TECH and PLAN (section → what changed → source).
- Scratch: `<SP>/work/r3d-docs/` holds `orig/` (the v1.1 / v1.0 docs for diffing), the section drafts, `reflow.py` and the lint logs.

## Amendment table (full version: `docs/review/r3d-docs/index.md`)
| GDD section | Change | Source |
|---|---|---|
| Header / conventions | v1.2, the pivot line, the changelog; 3D units; a term map for unamended text (PiP → Bellows window, badge → glow / previews / tags, tray → chips) | REDESIGN §6.6, D6 |
| §0 | Fairness row: the Bellows window; new Look row; Stalls hidden at rest | §6.6 |
| §1.2 / §1.3 | 64 px silhouettes; metres and px (1.60 m = 434 px = 40 %; 1.78 m = 471 px = 44 %; 217 / 236 px at 1200×540); the owner's hybrid; face cards; value extremes + outline + rim; R6 head check + `head_b` + stage-door labels; Pip / Figgis (R7); footlights are light | REDESIGN §5.5–§5.6, R6, R7, D6, D7 |
| §2.1, §2.3, §2.4 | before / during / after / trigger feedback column; 3D cue staging (no timing change) + 3D warm-up; Bellows window + `d1_lean` | §4.1, §4.4, R15 |
| §3 intro, §3.1–§3.11 | projected tap rects; QUIET / LIVE; ring at the prop; marble freeze; Clarence bottom-left; `hides` + one spot per room + the in-use lesson from Night 3; glow / halo / previews / needs / item bubbles / tags + W/N/V rules; carried chips; 3D camera + the Bellows window + C8 + `sim` / `lean` + the 35 % share + data-driven default; the REDESIGN §2 HUD; 3D bubble sizes and floor decals; new settings + debug keys | REDESIGN §2, §3.3, §4, §5.2, R15 |
| §4.10, §6.4, §6.5 | Stalls hidden at rest; the spotlight pool in step 1, Hint in the pause panel | §2.2, §4.4 |
| §7.1, §7.2 | the 3D stage (units, depth bands, flats, layers, strike rule, density, walls, silhouettes, R5 reach ruling, values, room light); Set lines + `hides` for P00 / N1 / N2; N2 has no clock case | §3, §5, R4, R5 |
| §9.1–§9.5 | Toy Box 3D art direction + the owner's vinyl-shading pick + D7 outlines; 3D rigs; the 3D pipeline and the 70-clip R3D set (§9.3 unchanged); A/B defaults kept | §5.3–§5.8, §7.6, R2, R3, R19 |
| §10.2–§10.5, App. A | 3D budgets; R0 → R3D → R3 → R4; 3D pre-checks + the readability review; X1–X9; the 3D-decision table | §6.3–§6.5, index §6 |

TECH: the header; §0 principle 5; **§1.1 the 3D module map** with owners and export filters; §2 (units, axes, depth bands, yaw facing, 60 fps clips); §3.5 / §3.8 / **§3.10** (`cmd_rejected struck`, `SimCtx.live_hotspots`, `SimVisibility.pip_reason`); §4.1 / §4.6–§4.8 notes; **§4.10–§4.13** (`rig3d.json`, sidecar v2 + `.res` + map keys, `house3d.json`, `previews.json` / `rig_actions.json`); **§5.11–§5.19** (scene tree + warm-up + curtain call + stage door + `boot_config.json`; `RigPlayer3D` + the pure layer; `WorldView3D` / `SetList` / `House3D` / `Prop3D` / `CharacterView3D` / ClipMap 3D / `SliceClips.build3d`; `CameraDirector3D`; `PipView3D` + C8 + both modes; decals + overlays + the anchor API + `OverlayPlacer`; shaders, globals, lighting, uniforms, layers, `MaterialWarm3D`; audio, HUD, settings; Stalls, Figgis); §6–§8 notes (input, settings keys, `d1_lean`, invariants 12–13); **§9** 3D budgets; §10.1 / **§10.5** 3D lints; **§11.1** 3D review tooling + R17; §12 build chain; §13 rules 7–10; §14 3D ids. §14's additions sit after **Items** so `tools/art/house/canon.py` still parses the hotspot list.

PLAN: §2b gives why, the D6 pick, one build on `r3d`, the 18-key task table with launch, the batches, queue and checkpoints (K1–K3, O1–O3), the exit (index §6), what is deferred to R3, and what comes next (R3: slice sets and all 137 clips in 3D; R4: the Fun Gate in 3D).

## Verification
- `SANDBOX=r3d-docs tools/scripts/lint.sh` → **rc 0**: content OK, hotspot OK, ip OK with 111 files and 90 GDD strings.
  - I checked the IP lint's GDD string set against v1.1 with a Python replica: identical.
  - The content coverage WARN (103/137 2D clips) and "lint_anim 3d: 73 missing" are pre-existing, or waiting on the animation keys.
  - Log: `<SP>/work/r3d-docs/lint2.log`.
  - My first run, at about 17:00, failed on `rig_actions.json` `times_up` / `mirror_mirror` `step` null ≠ `house3d.json` "mime". That mismatch was between r3d-content's and r3d-sets' files; r3d-content's 17:07 landing aligned them, and the re-run is green.
- `python3 tools/content/catalogue.py --no-write` → 0 mismatches vs GDD §5.7 / §7.2. The §7.2 Loop bullets and Script quotes are untouched; the new Set lines are separate bullets or sentences after "Script:".
- `python3 tools/art/house/lint_rects.py` → OK. It re-parses TECH §14 through `canon.check_against_tech()`.
- Number cross-check:
  - I extracted every numeric token from the added lines and looked each up in REDESIGN, the index, the briefs, issues.md and `project.godot`.
  - The only numbers not found are section references and three computed values: 3,000 px = `st_tea.stand_x`, and (−0.451, 0.752, 0.481) = the registered `mnd_key_dir`.
- Markdown hygiene: I checked the new lines for accidental list markers (fixed two) and reflowed lines over 125 characters.
- **Deviation — the full suite was not run** (`test_game.sh r3d-docs`). I grepped `game/tests` and `tools/ci`: no test reads `docs/GDD.md`, `TECH.md` or `PLAN.md`, and this task changed no other file. With all 4 CPU slots busy from the render tasks, I left the slot to them. The docs-parsing lints above cover everything that reads my files.
- No solver baseline was needed: nothing the sim reads was changed.

## Requests / proposed text for the orchestrator
- **CLAUDE.md** was already updated for the 3D view in pre-flight (the 3D view line, CPUParticles3D, `blender.sh`, `bake.sh`, `slot.sh`, the report in place of the PROGRESS line). Proposed additions to "Commands", once the owners land these scripts:
  - `- 3D sheets / lints: tools/scripts/anim_sheet3d.sh <rig> <clip> <out_dir>; tools/scripts/lint3d.sh --set|--screen|--hud|--visibility; tools/scripts/perf3d.sh <e2e.json>…`
  - `- Dev scenes: res://scenes/dev/anim3d/AnimViewer3D.tscn, res://scenes/dev/set3d/SetPreview3D.tscn, res://view3d/sandbox/ViewSandbox3D.tscn`
  - Design line: `Design: docs/GDD.md (v1.2) + docs/REDESIGN_3D.md (the 3D spec). Tech/contracts: docs/TECH.md (v1.1-3D).`
- **README.md**: after "Status: in development." add: "Branch `r3d` builds the 3D view (Node3D world, Camera3D, a 2D HUD; `docs/REDESIGN_3D.md`); `main` keeps the 2D Gate-0 build."
- **issues.md D7** (outline 4.8 / 3.4 px @1080, face cells ≥ 256 px wide) is folded into GDD §1.2, §3.5, §7.1, §9.1 and TECH §4.10 / §5.17. The landed `outline.gdshader` still defaults to 3.5 / 2.5 (r3d-view3d LANDED says it was kept at the spec). Applying D7 in code belongs to r3d-view3d or r3d-integrate, as D7 already says.

## Conflicts found in the sources (I resolved each by the stated precedence and left REDESIGN frozen)
1. **Hush's head.** REDESIGN §5.5 gives 0.47 m (≈ 127 px); the brief and cast-hush give ≈ 0.50 m including the beret (B's 1/3.2). The GDD uses 0.50 m, because the owner's pick of B's dimensions outranks REDESIGN.
2. **Hush's reach depth.** REDESIGN §5.1 / §5.5 has her step to z −1.5; index R5 has `reach_pos` z ≥ −1.6, default −1.6, and −1.4 on the stool. R5 follows from the owner's pick (B's arms), so it is what the GDD and TECH carry.
3. **Outline width.** REDESIGN §5.4 and index §7.6 say 3.5 / 2.5 px; lead decision D7 says 4.8 / 3.4 px. The docs carry D7.
4. **HUD sizes.** REDESIGN §2.6 has HUD numbers 48–60 px, captions 88–104 px and the HUD ≥ 24 px inside the safe area; GDD v1.1 has §3.10 at 48–56 / 80–96 and §3.8 at ≥ 32 px. §3.8 is replaced with REDESIGN's values, and §3.10 got a one-line (v1.2) pointer instead of a rewrite.
5. **Bellows window hide delay.** GDD v1.1 says 2 s, REDESIGN 1.5 s. The docs use 1.5 s.
6. **Stalls band.** GDD v1.1 has x S+800 … W−S−312, REDESIGN S+560 … W−S−440. The docs use REDESIGN's.
7. **Gloves.** REDESIGN says 1.6× hand size, cast-hush 1.65× (both ≈ 0.20 m). The GDD keeps 1.6× and ≈ 0.20 m.
8. **Hush's mouth cells.** GDD v1.1 counts 8 mouths; cast-hush lists 9 cell names. The GDD keeps "the v1.1 vocabulary"; the as-built fold-in should reconcile it.
9. **Camera numbers as built** (view3d LANDED): 268 px/m at the lane (spec 269); visible widths 8.95 / 7.16 / 5.37 m (spec 8.93 / 7.15 / 5.36); C2 x 15.32 m (spec 15.33). These are rounding differences. The docs keep the spec values, as designed.
10. **`mnd_key_dir`.** The index says "from travel direction (0.45, −0.75, −0.48) normalised"; `project.godot` stores the vector *toward* the key, −normalize(travel) = (−0.451, 0.752, 0.481). TECH now states this explicitly.

## Open points for r3d-qa's as-built fold-in (TECH is theirs once r3d-integrate starts)
- **§1.1 file names:** only class names are given where the index names no file.
- **HudModel as built** (r3d-hud LANDED):
  - `edge_badge_side/_arrow/_icon/_lean`, `pip_next_icon`, `pip_ring_frac`, `tag_flights {line_index, from}`, `lure_ring` −1 = from `lure_grey`.
  - Settings `render_scale` accepts 0.5–1.0 (designed 1.0 | 0.85); Settings `FILE_VERSION` 3.
  - `OverlayCtx.prepare(...)` and its per-frame fields; `WorldOverlays.setup(anchor_src, hud)`.
- **`char_toon` uniforms as built:** `albedo_color`, `vc_masks`, the face-UV2 convention, `stone_color`, `rim_damp`, `key_front`. Also the decal shapes and the outline uniforms (`width_from_alpha`, `use_color_normal`, `room_color`).
- **The Hints setting:** whether `hints` is removed or aliased now that Previews exists (the GDD says Previews takes its place).
- **The in-use hiding spot's red marker:** REDESIGN has no 3D design for it (Night 3, Stage 3).
- **Face atlas cells:** D7 asks for ≥ 256 px wide; cast-hush's v0 is 8×8 × 128 px.
- **Figgis moods:** GDD §9.2 says 4 expressions; as built there are 5 (idle, psst, point, shh, proud).
- **Values to record once known:** the R15 window default (after the measured `pip_on_share`), the O2 render defaults, whether statues 5–8 shipped ("4 of 8"), the head-check outcome (whether `head_b` and its ×scale exist), and the queue as it actually ran (PLAN §2b table).
- **Pre-existing gap from before R3D:** TECH v1.0 never documented Stage 2's as-built sim and view additions (`SimVisibility` beyond what §3.10 now says, `micro_gag` events, `SimOneshots`, the ClipMap schema, `SliceClips`, `SimFf`). They are referenced where the 3D contracts need them, but not written up in full.

## Hours
≈ 0.7 h active (16:32–17:10 UTC).
