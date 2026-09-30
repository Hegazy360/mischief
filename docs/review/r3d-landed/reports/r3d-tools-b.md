# r3d-tools-b — report: the REDESIGN §6.3 lints on the 3D game

All five §6.3 checks are built: the set lint, the screen-rect lint, the HUD lint (with the Bellows-window share warning), the visibility test C8 in both window modes, and the perf checker. So is `LintShot3D`. 48 fixture tests prove the rules. Every check has been run on the game as it stands, and every board was looked at. The failures are listed per owner in `docs/review/r3d-tools-b/status.md`: **22 errors and 3 warnings**. That file triggers the fix passes (index §3.3.1).

**Headline results:**
- **C8** holds on every frame of all 13 solver routes in the shipped `sim` mode (0 violations).
- **HUD:**
  - Every sample has 4 always-on pieces and at most 2 overlays / 2 loud.
  - The middle band is clear except for the action button at its REDESIGN §2.1 rect.
  - The window share is 28–39 %. The only warning is P00 required at 38–39 %.
- **Screen rects:** every live target is ≥ 163 px at every aspect and every framing. There are 10 errors in three groups:
  - the N02 fridge's two zones sit 5.6 px apart;
  - the hall front door runs under Clarence at 16:9 and off the 4:3 edge;
  - the honey and the gramophone sit 3–5 px off the 4:3 edge.
- **Set:**
  - The live and dressing counts match the REDESIGN §3.4 tables exactly.
  - Negative space fails in the parlour (1.02 m) and the N02 hall (0.68 m).
  - The N02 fridge stack fails.
  - Hush's light share sits at the rule's edge (0.194–0.230 against ≥ 0.20). The value board shows why: her painted face renders mid-value.
- **Perf:** only the view + HUD script time fails, at 5.7–10.5 ms p95 on the llvmpipe proxy. Everything else is inside budget:
  - draw calls p95 57–72;
  - at most 103k triangles;
  - 4 emitters;
  - at most 103 MB of textures;
  - 0 shader compiles in PLAY.

---

## 1. Files built (all within brief §2)
| File | What it is |
|---|---|
| `game/tools/lint3d/lint3d.gd` (`Lint3D`) | The issue record `{lint, rule, level: error\|warning\|info\|skip, night, room, subject, value, limit, owner, detail}`. Also `report()`, `print_issues()`, `write_json()`, `read_json()`, `to_json()`, `rect_gap()` (the ≥ 24 px separation, side by side or stacked, as in the Stage-1 hotspot lint) and `NIGHTS` = g0, P00, N01, N02. |
| `game/tools/lint3d/set_lint.gd` (`SetLint3D`) | The set lint: `facts_for(db, episode, house3d, result)`, `check_facts(facts, mantels)`, `free_stretch(room)`, `check_stacks(...)`, `check_measures(measure, nights)`, `colour_issues`, `iou_issues`, `mantels`, `run(db, nights, measure)`. |
| `game/tools/lint3d/screen_rect_lint.gd` (`ScreenRectLint3D`) | The screen-rect lint: `hud_rects(episode, aspect)`, `make_camera`, `frame_at`, `sweep(cam, room, boxes, keep)`, `check_frame(...)` (pure), `fold`, `run(db, nights, aspects)`. `hud_rects` uses a real `Hud` and its `always_on_rects()` with the Night's Script pips, and falls back to `HudLayout.compute`. |
| `game/tools/lint3d/hud_lint.gd` (`HudLint3D`) | `check_report(report, name)`, `viewport_of`, `band_rect`, `at_spec`. |
| `game/tools/lint3d/visibility_check.gd` (`VisibilityCheck3D`) | `check_row` and `check_rows` (pure), `violation_issues`, `replay(parent, db, episode, cmds, mode, aspect)`, `route_files`, `shipped_mode()`. |
| `game/tools/lint3d/perf_check.gd` (`PerfCheck3D`) | `check(report, name)` and `table(rows)`. |
| `game/tools/lint3d/run_lint3d.gd` | The SceneTree runner: `--set --screen --hud --visibility --perf`, plus `--json`, `--strict` and `--verbose`. |
| `game/tools/lint3d/render_measure.py` | The rendered half of the set lint. It takes LintShot3D's manifest and runs r3d-tools-a's `lab.regions`, `lab.check_rules("set")`, `lab.falsecolor_board`, `sil64.run_masks` + board, and `boards.grid` for the rects boards. It contains no colour maths of its own. |
| `game/tools/lint3d/status_md.py` | Turns the lint JSONs into `status.md`: errors by owner, then warnings, then skips. |
| `game/scenes/dev/review3d/LintShot3D.tscn` + `lint_shot_3d.gd` | Four passes: `beauty`, `id` (+ legend JSON), `mask:<hotspot>` and `rects`. It runs a single job or `--batch=all`. Each job renders into its own SubViewport at 540 px high (1200 / 960 / 720 wide). |
| `tools/scripts/lint3d.sh`, `tools/scripts/perf3d.sh` | The entry points. They run one Godot process at a time through slot.sh. |
| `game/tests/lint3d/test_{set_lint,screen_rect_lint,hud_lint,visibility_check,perf_check}.gd` + `fixtures/` | 48 tests. `fixtures/shots/` holds `.gdignore` and a synthetic LintShot3D output for the Python self-test. |
| `docs/review/r3d-tools-b/{index.md, status.md, lintshot_passes.png, boards/}` | The review set: 9 rects, 9 colour and 9 sil64 boards, plus the Hush value board. Total 4.3 MB. |

## 2. Commands
```bash
tools/scripts/test_game.sh <key> -- lint3d/                                   # 48 fixture tests, ~10 s
SANDBOX=<key> tools/scripts/lint3d.sh --self-test                             # Python half on fixtures (no Godot)
SANDBOX=<key> tools/scripts/lint3d.sh --set --all-nights [--json=/abs.json] [--boards=<dir>] [--no-render] [--strict]
SANDBOX=<key> tools/scripts/lint3d.sh --screen --aspects=20x9,16x9,4x3 [--json=…]
SANDBOX=<key> tools/scripts/lint3d.sh --visibility --routes=all [--aspects=20x9,4x3] [--mode=sim|lean] [--json=…]
SANDBOX=<key> tools/scripts/lint3d.sh --hud --from=<dir of 3D e2e reports> [--json=…]
tools/scripts/perf3d.sh <e2e report.json>… [--json=…] [--strict]
python3 game/tools/lint3d/status_md.py <jsons>… --out=docs/review/r3d-tools-b/status.md
```
- `--set` and `--screen` share one xvfb render batch. `--screen` also renders the rects boards. `--no-render` runs only the headless rules; the colour and silhouette rules then report SKIP.
- `--visibility` first dumps the route commands. It runs `solve.sh all --route=all --dump-cmds`, plus `solve.sh g0_sneeze` because Gate 0 is a draft episode. It shoots the first violation per route with ViewSandbox3D.
- A missing input prints `SKIP <rule>: <what> (<owner>)` and exits 0. It fails only under `--strict`. Warnings never fail.
- Timings measured on this box:

  | Step | Time |
  |---|---|
  | set headless | 0.3 s |
  | screen headless | 0.25 s |
  | HUD | 0.04 s |
  | perf | 0.03 s |
  | set renders (42 jobs) | 8 s |
  | set + rects renders (69 jobs) | 14 s |
  | C8, 13 routes × 2 modes | 155 s |

  Each Godot start adds about 5 s plus slot waits. All steps are inside the brief §7 budgets.

## 3. What each rule measures (thresholds)
**Set lint.** It runs per Night (g0, P00, N01, N02) and per built lit room, using the facts from `SetList.for_episode`, `house3d.json` and `house.json`.

*Counts and geometry (headless):*
- `live_count` ≤ 5: rig + take + hide from `live_props_in`. Owner r3d-content.
- `dressing_count` ≤ 4: `dressing` plus the decor pieces marked `"dressing": true`.
- `hides_act1`: one hiding spot per room in acts 0–1.
- `dressing_size` ≥ 0.5 m on the longest side.
- `dressing_lane`: a piece whose front is at z > −1.6 must not rise above 0.45 m.
- `preview_band`: no dressing inside the x-extent of a live prop's visual, from its top up 0.6 m.
- `quake_height`: bottom ≥ 2.2 m, or sitting on a `*mantel*` built-in.
- `negative_space`: the longest stretch of the room's lane with nothing at head height (y 1.1–1.8 m) must be ≥ 1.5 m. Live props, furniture, dressing, decor and built-ins all block. A room with no live prop (the porch) only warns.
- `silhouette_family`: live props in a room must have distinct `house3d.json` families. Merged zones count as one prop.
- `stack`: projected hit boxes in a room at 20:9 must stay ≥ 24 px apart at every framing the room can use.

*Rendered checks:*
- `silhouette_iou`: 64 px masks from sil64. An IoU ≥ 0.80 in one room is an error.
- `colour`: every FAIL from lab.py's §3.7 rules is an error. These cover:
  - lit walls L* 62–76 and C* ≤ 28;
  - wainscot 8–10 L* darker;
  - dimmed walls L* 45–58 and C* ≤ 15;
  - floors L* 40–50;
  - dressing C* ≤ 30 and |ΔL*| ≤ 15;
  - live props C* ≥ 45 or a halo;
  - characters ≥ 20 % at L* ≥ 85 and ≥ 20 % at L* ≤ 40.

  The measured values go into the JSON as info rows.

**Screen-rect lint.** It projects each live hotspot's hit box (`SetGeo.hit_box` = `House3D.hotspot_box`, index R5a) with a real `CameraDirector3D`. This happens at every framing the room can use: Hush walks the room in 0.25 m steps, both ways, and the camera snaps with C1, C2 and C6 applied. The aspects are 20:9 (2400×1080 with S = 96), 16:9 (1920×1080) and 4:3 (1440×1080).

Rules for the framed room's live rects:
- `min_size` ≥ 144×144;
- `gap` ≥ 24 px to every live rect on screen, neighbours included;
- `safe_rect`: inside the safe rect;
- `hud_overlap`: not under an always-on hit rect (error);
- `window_overlap`: not under the Bellows window (warning);
- `back_wall` ≥ 201 px/m;
- `on_screen`.

Results are folded per room, rule, prop and aspect, keeping the worst value and the camera-x range.

**HUD lint.** It reads the e2e reports' `hud_pieces`, `overlays` and `pip_*` fields.
- `always_on_count` ≤ 4, and only pause, script, clarence and action.
- `middle_band`: nothing always-on or persistent in y 250–880, scaled to the viewport. Persistent means one piece seen in the band over a run of samples spanning more than 5 s of sim ticks. The edge badge (outer 160 px), Figgis and the pick strip are allowed. The deviations in §6 apply.
- `overlays` ≤ 6, with ≤ 2 loud.
- `window_share`: a WARNING above 35 %, with `pip_longest_s` and the open→close ticks.

**Visibility check C8.** Every frame of every route is replayed through SimDriver → WorldView3D → CameraDirector3D → PipView3D at a fixed 60 fps. The replay stops at the solver's `ticks`.
- `c8_shown`: when the sim says room or pip, Bellows must be on screen or in the window. Under `lean` the edge badge also counts on `adjacent` ticks.
- `c8_exclusive`: when he is on screen, the window must be closed.
- The shipped mode comes from boot_config.json (`sim` today) and its violations are errors. The other mode is reported as info. The window share and badge frames are printed per route.

**Perf checker.** It reads the `perf3d` blocks.
- Draw calls p95 ≤ 150 and max ≤ 250.
- Triangles ≤ 150k.
- Emitters ≤ 8.
- Textures ≤ 250 MB.
- `shader_compiles_play` == 0.
- Script time p95 ≤ 4 ms. It uses `view_ms_p95` (view + HUD, index row 16) when the block has it, and `script_ms_p95` otherwise.

## 4. Current results per Night
**Set counts** (live / dressing / free stretch):

| Night | Room | Live | Dressing | Free stretch |
|---|---|---|---|---|
| g0 | kitchen | 2 | 2 | 2.84 m |
| P00 | kitchen | 2 | 2 | 2.84 m |
| P00 | parlour | 2 | 4 | **1.02 m** |
| N01 | kitchen | 5 | 3 | 1.63 m |
| N01 | parlour | 2 | 3 | **1.02 m** |
| N01 | hall | 2 | 3 | 1.50 m |
| N01 | porch | 0 | 0 | 1.40 m (warn) |
| N02 | kitchen | 3 | 3 | 2.02 m |
| N02 | parlour | 2 | 2 | 1.62 m |
| N02 | hall | 5 | 3 | **0.68 m** |
| N02 | porch | 0 | 0 | 1.40 m (warn) |

- The live counts equal the REDESIGN §3.4 tables.
- Families are distinct. The max mask IoU is 0.72 (N01 parlour piano vs recliner; N02 kitchen fridge vs pantry).
- Stacks fail only for the N02 fridge (5.6 px).

**Colour and value:**
- Lit walls: L* 65.8–67.8, C* ≤ 22.
- Wainscots: 8.5–9.7 darker.
- Lit floors: L* 49.5.
- Dimmed walls: L* 52–54, C* 7–11.
- Dressing: C* ≤ 15, |ΔL*| ≤ 12.
- Every live prop passes by its halo. The measured median C* is low: honey 22, pantry 22, gramophone 31, piano 8, mirror 6, phone 8.
- Bellows: 0.33 at L* ≥ 85 and 0.30–0.34 at L* ≤ 40. Pass.
- Hush: 0.194–0.230 at L* ≥ 85. It FAILS in the N01 kitchen (0.199), N02 kitchen (0.195) and N02 parlour (0.194). Her share at L* ≤ 40 is 0.54–0.62.

**Screen:** every live rect is ≥ 163 px at every aspect and framing.

| Night | Aspect | Smallest rect |
|---|---|---|
| P00 | 20:9 | 194 px (honey) |
| P00 | 4:3 | 195 px (piano) |
| N01 | all | 166–167 px (CONFISCATED box) |
| N02 | all | 163 px (phone) |

- The N02 fridge shelf and door are 5.6 px apart at every aspect.
- The hall front door is under Clarence at 16:9 and 107 px off the left edge at 4:3.
- Honey (4.6 px) and gramophone (2.8 px) fall off the 4:3 edge in 1–2 framings.
- The C6 keep-visible clamp cannot fit the whole 5.5 m kitchen at 4:3 when Hush is at the far right.

**C8, window share per route** (sim / lean; sim violations are 0 everywhere):

| Route | Sim | Lean |
|---|---|---|
| g0 ideal | 30.4 % | 16.8 % |
| P00 ideal | 30.8 % | 9.4 % |
| P00 required | **39.0 %** (longest 18.7 s) | 8.3 % |
| P00 slow | 34.0 % | 9.6 % |
| N01 ideal | 17.8 % | 5.7 % |
| N01 required | **35.1 %** | 12.8 % |
| N01 slow | 31.5 % | 11.7 % |
| N01 caught | 28.0 % | 11.4 % |
| N01 chase | 20.6 % | 0.3 % |
| N01 meltdown | 10.0 % | 7.4 % |
| N02 ideal | 20.1 % | 10.6 % |
| N02 required | 15.6 % | 9.9 % |
| N02 slow | 15.1 % | 9.7 % |

- Lean has 1–6 one- or two-frame violations per route, at doorway transitions: the badge is off for one frame (request to r3d-view3d below).
- These headless numbers match the e2e `pip_on_share` (P00 29.9 %, g0 28.0 %).

**HUD** (my P00-ideal e2e plus r3d-night's g0, P00 ideal, required and slow):
- 4 always-on pieces.
- The band is clear except for the action button at its §2.1 rect (info). Figgis was seen transiently.
- Overlays max 2, loud 2.
- One WARNING: P00 required window share 38.0 %.

**Perf:**

| Report | Draws p95 / max | Triangles | Emitters | Textures | Compiles in PLAY | Script p95 |
|---|---|---|---|---|---|---|
| P00 ideal (mine) | 72 / 80 | 102.5k | 4 | 103 MB | 0 | view + HUD 5.66 ms (sim 5.26) |

- g0, P00 ideal, required and slow (r3d-night's reports) fail only the script row. Their script p95 runs 6.8–10.5 ms; the older reports carry no view/sim split. This is the llvmpipe CPU proxy at load average ~5, so it is proxy evidence; the device numbers come from O2.

## 5. What I looked at
- Every board in `docs/review/r3d-tools-b/boards/`.
- The P00 kitchen and parlour, N01 kitchen and N02 parlour renders, in both character placements.
- The ID-vs-beauty alignment.
- The mask crops.

The lint agrees with my eyes:
- The N02 fridge's shelf and door boxes visibly touch.
- The hall front door's lower corner sits in Clarence's corner at 16:9.
- The parlour's head-height band is crowded by the window, portrait, vase and mantel line. So is the N02 hall (five live props, coat stand, window).
- Hush's face renders mid-grey (L* 60–80) under the stage light. Her light share comes from the stripes and gloves (`value_hush_N02_parlour.png`).

Two fixes came from looking:
- The first colour pass stood Hush in front of the pickle jar and Bellows in front of the pantry. The characters now stand where no live prop is behind them, near the room centre and ≥ 1.4 m apart.
- An earlier 4:3 run flagged the pantry under the action button. That came from a 1:1 HUD at 1440×1080; the HUD is now computed at the 4:3 device scale (§6.3).

## 6. Deviations and why
1. **Middle band vs REDESIGN §2.1.** The action button's 240 px hit circle reaches y 792 by §2.1's own numbers, and Clarence starts at y 880. An always-on piece at exactly its §2.1 rect (±2 px) is reported as info. Anywhere else in the band it is an error. This answers r3d-hud's request. A lead ruling is requested.
2. **§2.2 placements inside the band.** The escalated window (704×396) and BOW under the window (T+273) sit in the band per §2.2. They are a warning while transient (≤ 5 s) and an error when persistent. Every other contextual piece in the band is an error.
3. **4:3 HUD.** A real 4:3 canvas is 1920×1440, where §2.6 scales the HUD ×0.8. The HUD rects are computed there with `Hud.always_on_rects()` and mapped into the brief's 1440×1080 frame (×0.75). World rects are measured in 1440×1080, which is the stricter proxy.
4. **Screen scope.** The size, safe-rect and HUD rules apply to the framed room's live rects. Gaps include the neighbour rooms' visible rects.
5. **Colour legend classes.** Furniture (stations, landing hosts, the stool, the phone table) is `furniture`, reported as info rather than as dressing. Dimmed wainscots are `wainscot_dim` and backstage rooms `*_backstage`, both info, because the wainscot rule applies to lit walls (r3d-sets' note). lab.py SKIP rows (not visible in the framing) are info, so `--strict` does not trip on an off-screen backstage room. The one light-source dressing, the lamp shade, is `exempt`.
6. **Halo.** Every live prop in `house3d.json` has `halo`, and every Prop3D builds the halo shell. So "C* ≥ 45 or a halo" passes by the halo everywhere. The measured C* values are reported.
7. **Perf script budget.** It judges `view_ms_p95` (view + HUD, index row 16) when present. It falls back to `script_ms_p95`, which includes the sim.
8. **C8.** It checks every view frame, which covers every tick. It stops at the solver's run length, because the scenario routes (chase, meltdown) end without the Night ending.
9. **Negative space.** "Head height" is y 1.1–1.8 m. Windows, portraits and the mantel line count as "something behind".
10. **D7 (outline widths).** The mask pass hides ink and halo shells, and ID regions exclude the outline hull. The silhouette and value numbers therefore do not depend on outline width, and D7 changes no lint input. D7 has not landed yet (`View3DConst.OUTLINE_CHAR_PX` is 3.5). Re-running after it lands needs nothing extra.

## 7. Requests
| To | File / change | Why |
|---|---|---|
| **r3d-sets** | `house3d.json`: move `kitchen_fridge_shelf` and `kitchen_fridge` further apart, e.g. `hit_z_half` 0.12 like the other tall props, or a larger zone gap. | Their projected boxes are 5.6 px apart; ≥ 24 is needed. This is REDESIGN §3.3's named stack. |
| **r3d-sets** | Parlour: clear a 1.5 m head-height stretch. Today it is 1.02 m at x 9.88–10.90; the blockers are the window at y 1.15–2.35, the portrait, vase and mantel line, the piano and the gramophone. N02 hall: today 0.68 m. | REDESIGN §3.3 negative space. |
| **r3d-sets** (or r3d-view3d) | `hall_front_door` `hit_box`: raise y0 to about 0.6 m, or let C6 keep it clear of Clarence. | It runs under Clarence at 16:9 and 107 px off the edge at 4:3. |
| **r3d-view3d** | `WorldView3D._update_visibility`: decide `badge` after PipView3D's post-camera `on_screen` (e.g. in `set_window_shown`). | Under `lean`, 1–2 frames per doorway transition show neither the badge nor the window. That would fail C8 if `lean` shipped. |
| **r3d-view3d** | C6 at 4:3: bias toward keeping the room's live rects inside the safe rect when the overflow is a few px. | Honey is 4.6 px off and the gramophone 2.8 px off. |
| **r3d-view3d / r3d-hud** | View + HUD script time is 5.7–10.5 ms p95 on the proxy (P00 required 10.5, slow 9.8), against a 4 ms budget. | Row 16. It may be proxy-only (load ~5); O2 decides. |
| **r3d-cast-hush** (with r3d-view3d `key_front`) | Hush's face renders L* 60–80 under the stage light. Her ≥ L* 85 share is 0.194–0.230, and fails in 3 of 9 rooms. | REDESIGN §3.7: faces are the comedy, and the face should be the light extreme. |
| **r3d-night** | Add `viewport: [w, h]` and `bellows_window` (the mode) to the e2e report, and `pip_on_share_lean` if cheap. | The HUD lint infers the viewport from the pause and action rects meanwhile. |
| **Lead** | Rule on the band vs §2.1 action position (deviation 1) and the §2.2 escalated window / BOW-low (deviation 2). Decide whether `house3d.json` `halo` should be limited to metal/wood props as REDESIGN §3.7 implies (deviation 6). Note P00 required's window share of 38–39 %, longest 18.7 s (R15 data point). | Spec conflicts, and the R15 default. |
| **r3d-qa** (pregate3d.sh) | Row 9: `SANDBOX=r3d-qa tools/scripts/lint3d.sh --set --all-nights --strict`. Row 10: `… --screen --aspects=20x9,16x9,4x3 --strict`. Row 11: `… --hud --from=$PWD/build/r3d/e2e --strict`. Row 12: `… --visibility --routes=all --strict`. Row 16: `tools/scripts/perf3d.sh build/r3d/e2e/*.json`. | The commands as built. |
| **r3d-docs / r3d-qa** | TECH §10.5 as-built: `lint3d.sh --self-test`, `--no-render`, `--boards=`; the 4:3 HUD mapping; the band spec-position exemption; the view + HUD budget key; C8 stopping at the solver's `ticks`; LintShot3D `--batch=all` and `--passes` / `--aspects`. | The as-built fold-in. |

## 8. Verification
- `tools/scripts/test_game.sh r3d-tools-b -- lint3d/`: **48/48**. Each rule fails on its fixture and passes on a clean one.
  - Fixtures: 6 live props; 5 dressing; 2 hides in Act I; a stack 20 px apart; IoU 0.885 masks; a dressing at C* 40.4 (a real lab.py result); a 130 px rect; a rect under pause; 5 always-on pieces; a persistent rect at y 400; 7 overlays / 3 loud; share 0.6 (warning only); the C8 traces (off-screen room, `lean` adjacency + badge passes, heading + badge fails, on screen + window fails); a quake prop at 1.6 m; a neighbour 20 px away; 180 draw calls p95; a view/HUD split.
  - Also: real-data smoke tests on the P00 counts, the P00 sweep, and a 240-frame g0 replay through the real view stack.
- `lint3d.sh --self-test`: OK. The C* 40 dressing FAILs and the jar/twin pair is ≥ 0.80.
- The real runs above. Every JSON is in `<SP>/work/r3d-tools-b/{set,c8,hud,perf}.json` and `out/screen.json`.
- Full suite `tools/scripts/test_game.sh r3d-tools-b` (no filter): **OK, 1482 passed, 0 failed, 1 skipped** (a pre-existing skip in `view/test_audio_director.gd`), 1483 tests in 163 files, 263 s. The 5 lint3d files are 14 + 12 + 9 + 7 + 6 = 48.
- `SANDBOX=r3d-tools-b tools/scripts/lint.sh`: **rc 0**, "0 lint(s) failed, 0 skipped". The WARNs are existing coverage warnings from other owners: 16 of 77 g0/p00 clips without a v2 sidecar, 103 of 137 SliceClips clips missing, and N01/N02 3D clips not baked yet.
- `solve.sh all` (run by the C8 dump): **OK, 12 runs, 0 failed**, plus the separate g0 solve. Nothing the sim reads was changed.
- `docs/review/r3d-tools-b/` is 4.3 MB, under the 25 MB limit. No `.import` or `.uid` file was hand-written, and no frozen file was touched.

## 9. Hours
About 0.9 wall-clock hours (19:21Z–20:16Z), with most of the render and replay time spent in queued background runs. No solver baseline was needed, because nothing the sim reads was changed.
