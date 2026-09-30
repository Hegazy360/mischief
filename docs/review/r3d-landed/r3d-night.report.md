# r3d-night — report

The Night, Boot, curtain call, Gag Reel and stage door on the 3D view; warm-up and compile detection; DevShot, the
device log and the e2e in 3D; the APK route. Branch `r3d`, Godot 4.7.2 (Compatibility), CPU box (llvmpipe). All Godot
runs went through the slot-wrapped scripts, one process at a time, sandboxes `r3d-night` / `r3d-night-shot`. No git
writes. Review folder: `docs/review/r3d-night/index.md` (3.4 MB). Per-landing log: `<SP>/work/r3d-night/LANDED.md`.

## 1. Files built (all inside my brief's §2)

New:
- `game/scenes/boot/boot_config.gd` — `BootConfig`: reads `boot_config.json` with a default for every key.
- `game/scenes/night/shader_watch.gd` — `ShaderWatch`: the "no shader compiled during PLAY" detector.
- `game/scenes/night/perf3d.gd` — `Perf3D`: the 3D frame-budget sampler of PLAY frames.
- `game/scenes/night/curtain_bows_3d.gd` — `CurtainBows3D`: the curtain call's 3D bows (its own transparent world).
- `game/scenes/results/gag_reel_3d.gd` — `GagReel3D`: the Gag Reel re-staged from `MomentRecorder3D`.
- `game/tests/night/test_night3d.gd` (23 tests), `game/tests/night/compile_probe.gd` + `CompileProbe.tscn` (the
  measurement that GLES3 reports 0 pipeline compilations).

Changed: `game/scenes/boot/{boot.gd, boot_config.json}`, `game/scenes/night/{night_scene.gd, night_args.gd,
night_input.gd, night_warmer.gd, hud_presenter.gd, cue_fallback.gd, curtain_call.gd, curtain_apron.gd, gate0_card.gd}`,
`game/scenes/results/gag_reel.gd`, `game/scenes/stage_door/{stage_door.gd, cast.gd}`, `game/scenes/debug/device_log.gd`,
`game/autoload/dev_shot.gd`, `game/tools/e2e.gd`, `game/tools/e2e/{e2e_probe.gd, e2e_scenarios.gd, e2e_flows.gd}`,
`tools/scripts/e2e.sh`, `game/export_presets.cfg`, `game/addons/mnd_export/plugin.gd` (doc), `game/tests/night/
{test_device_log.gd, test_e2e_probe.gd}`, `docs/review/r3d-night/*`.

## 2. Public APIs

- **BootConfig** (static): `read(path) -> Dictionary`, `merged(raw) -> Dictionary` (every key, coerced: `view` ∈ 2d|3d,
  `render_scale` 0.5–1.0), `view() -> String`, `render() -> Dictionary`. `DEFAULTS` = `{start: "auto", view: "3d",
  show_previews: false, bellows_window: "sim", render: {msaa_3d: true, render_scale: 1.0, outline: true}}`.
- **NightScene**: `view_mode` ("3d" default; setup param `view` > `--view` > boot_config), `world_view`, `cam`, `pip`,
  `stager`, `overlays`, `omodel`, `octx`, `render_cfg`, `shader_watch`, `perf3d`, `map_open`, `idle_s`;
  `next_useful(snap) -> String` (the hint ladder), `hint()`, `open_map()`, `close_map()`, `map_room_at(screen) -> String`.
  Setup keys added: `view`, `card`. NightArgs: `--view=2d|3d`, `--msaa=off|2|4`, `--no-captions`, `--hud=off`,
  `--window=sim|lean`, `--card=g0`.
- **HudPresenter**: `fill_r3d(model, snap, ctx, env)`; `HudEnv` + `edge_lean`, `can_bow`, `entry_warning`, `overview_allowed`.
- **NightInput**: `view3d`; `candidates()` = projected rects (`WorldView3D.hotspot_rects_in_view`) in 3D, zoom 1.0;
  `lane_x(pos, room)`.
- **NightWarmer**: 3D steps `materials, clips, overlays, fonts, pip, audio, textures, ui_icons`; `build_scene_rig(parent,
  camera, root)`; `LAZY_SCENES` (the freeze plinth); `warmed_keys`; `materials_drawn`, `instanced_drawn`, `clips_warmed`.
- **ShaderWatch**: `arm(root, warmed = {})`, `reset()`, `frame(dt, tick)`, `scan(tick)`, `compiles_play()`,
  `median_ms()`, `summary()` {method, shader_compiles_play, first_use[{key, kind, tick, source, node, material}],
  hitches, hitch_max_ms, pipeline_delta, known}; static `shader_key(material, instanced)`, `base_key(BaseMaterial3D)`,
  `pipeline_total()`.
- **Perf3D**: `frame(dt, world_view)`, `add_script_ms(ms, sim_ms)`, `summary(watch)` {frames, frame_ms_p50/p95/max,
  draw_calls_p95/max, tris_max, objects_max, emitters_max, tex_mb_max, vmem_mb_max, process_ms_p95, script_ms_p50/p95,
  sim_ms_p95, view_ms_p50/p95, shader_compiles_play, hitches, hitch_max_ms, compile_method}.
- **CurtainBows3D** (TextureRect): `lip_point(x_frac, feet_frac, z)`, `pose_hush(x, clip, facing, cheat)`, `hide_hush()`,
  `pose_bellows(...)`, `hide_bellows()`, `set_residues(residues)`, `set_bellows_tier(tier)`, `head_screen(id)`.
- **GagReel3D**: signals `moment_started(index, moment)`, `finished()`; `get_texture()`, `prime(night, moments)`,
  `start(night, moments, budget_s, cmds)`, `skip()`, `stop()`, `primed`, `played`, `frames_shown`.
  **GagReel.Log**: `keep_3d(events, recorder)`, `record_clones`.
- **StageDoor**: static `menu3d(head_scale, previews)`, `head_b_scale(path)`, `label(key, args)`; `previews_on()`,
  `open_wip()` / `close_wip()`; entries `g0_head_b`, `g0_head_scaled`, `night1_preview`, `night2_preview`.
  **CastPage**: `set_beat(i)`, `turn(deg)`, static `stone(root)`; shot args `--beat=`, `--turn=`.
- **DeviceLog**: `shader_first_use(key, kind, tick)`, `hitch(frame_ms, median_ms, tick)`; the per-Night `perf3d:<episode>`
  note. **DevShot** `--perf-log`: a `[perf3d] {json}` line (draw calls, primitives, objects, tex / video MB, emitters,
  wall frame ms, process ms).
- **E2eProbe** report fields: `view`, `fallback_counts`, `hud_pieces`, `overlays`, `visibility` {fields, rows},
  `pip_on_share`, `pip_longest_s`, `pip_windows`, `frame_ms_p50/p95`, `perf3d` (+ compile detail), `cue_staged`,
  `laugh_cues`, `doubles`, `warm3d`. **E2eScenarios** `within_quantised(value, threshold, frame)`, `STRICT_EPISODES`.

## 3. How it works (short)

- **View switch (R1)**: 3D is the default (announced 18:34Z). The 3D tree: SimDriver · WorldEnvironment ·
  CameraDirector3D · WorldView3D · InputRouter (screen px) · PipView3D · GagStager3D · AudioDirector · WorldOverlays
  (layer 8) · Stalls (9, hidden at rest) · Hud (10) · Curtain (20). `--view=2d` keeps the Stage-2 tree.
- **Input**: taps resolve by TapAssist on the projected hit boxes; a floor tap moves along the lane (x from
  `screen_to_world`, clamped to the room); struck spots are never candidates (the sim's `cmd_rejected struck` gets the
  grey pop); every tap answers with `tap_feedback` + path dots on the same frame.
- **Overlays / presenters**: `OverlayRules.fill` every frame with the hint ladder (`next_useful`), the N4 spotlight pool
  after 6 s idle, the V2 danger rule (hints hidden, queued 1 s), tag flights to the Script pip. Map = the overview dolly;
  tapping a room peeks it 2.4 s; Back / tap outside closes.
- **Warm-up (under the 2D curtain)**: the MaterialWarm3D rig + RigPlayer3D.warm, a rig of every other material of the
  Night's tree (hidden ones too) + one-instance MultiMeshes for the particle materials' instanced variant, the lazily
  built scenes (`LAZY_SCENES`: the freeze plinth), every live rig prop's tag shown for the two warm frames; clips,
  overlays, fonts, PiP, audio, textures, UI icons.
- **Compile detection** (the detector's method): GLES3 reports **0** for every pipeline-compilation counter even while a
  new shader compiles (measured: a 480 ms frame, CompileProbe), so `ShaderWatch` counts **first uses**: at the rise it
  records the warmed set (registry keys + every material in the tree + NightWarmer.warmed_keys); in PLAY every registry
  key first registered and every shader first seen on a visible instance (a tree scan every 60 frames) is a compile,
  keyed by shader (ShaderMaterial) or feature set (BaseMaterial3D, one generated shader per set); plus hitches
  > max(50 ms, 2.5 × median). Found and fixed two lazy builds: Prop3D's beret tag (g0 tick 211) and CharacterView3D's
  freeze plinth (N01 caught tick 647, N02 ideal tick 6161).
- **Curtain call**: the 2D curtain falls as before; the bows render in their own transparent world (a stage-lip
  camera, two RigPlayer3Ds) under the roses / title / valance; Hush walks in and bows (`hush/act_bow`), Bellows
  `cc_wander_on → st_double_take → beat_slow_burn (red) → st_bonk` under the valance. g0: fall → reel → Again ▶ (no bow
  step, as in Stage 2); P00 → Next.
- **Gag Reel 3D**: one MomentRecorder3D window per reaction (`Log.keep_3d`, knock-ons merged); the reel poses both
  characters by clip + frame (`WorldView3D.show_moment_frame`), sets every prop's state and the decor, lights their rooms
  and films it at 704×396 in a SubViewport sharing the World3D (a punch-in camera; caption after the accent); `prime()`
  draws the first frame when the call starts. Sounds are not replayed (the call's crowd and music carry on).
- **Stage door**: Gate 0, Prologue, Cast (3D), "Gate 0 · Hush, B's head" and "Gate 0 · Hush, head ×1.2" (`head_b`
  shipped; each sets Settings `hush_head` to "" / "head_b" and launches g0 with its card), the A/B pages; Night 1/2
  previews only with `show_previews` or the debug setting, behind the WIP card ("Work in progress: Bellows' reactions in
  these Nights are not animated yet", Play anyway / Back).
- **Boot**: unchanged 2D curtain first frame; build + warm under it.

## 4. Verification

Commands (all with the slot wrappers): `tools/scripts/test_game.sh r3d-night` (full) and `-- night/`;
`E2E_SANDBOX=r3d-night tools/scripts/e2e.sh <scenario> [--strict --perf-log --report=… --shot-seq=…]`;
`tools/scripts/shot.sh <scene> <png> <frames> r3d-night-shot [args]`; `tools/scripts/export_android.sh --sandbox
r3d-night`; `SANDBOX=r3d-night tools/scripts/lint.sh`.

- **Full suite**: `== OK: 1482 passed, 0 failed, 1 skipped, 1483 tests in 163 files ==`; `night/` 107/107
  (test_night3d 23). **Lint**: `[lint] OK: 0 lint(s) failed, 0 skipped` (lint_anim 3d: 61 clips, 0 errors, 16 missing =
  info).
- **Perf (desktop proxy, 3D, MSAA off, PLAY frames)**:

| Route | draw p95 / max | tris max | emitters | tex MB | compiles in PLAY | frame ms p50 / p95 | scripts p95 (view + HUD / sim) | build / warm ms | window share / longest |
|---|---|---|---|---|---|---|---|---|---|
| g0_sneeze (fixed 60) | 57 / 65 | 68.4k | 4 | 81.2 | 0 | 98.9 / 142.0 | 7.6 ms | 629 / 316 | 0.280 / 6.4 s |
| prologue_ideal | 72 / 80 | 92.8k | 4 | 103.4 | 0 | 101.0 / 131.7 | 9.2 (5.1 / 4.7) ms | 597 / 371 | 0.298 / 2.5 s |
| prologue_required | 71 / 83 | 92.9k | 4 | 103.4 | 0 | 102.6 / 150.4 | 10.5 ms | 564 / 378 | 0.380 / 4.5 s |
| prologue_slow | 72 / 80 | 92.9k | 4 | 103.4 | 0 | 93.7 / 116.6 | 9.1 (4.6 / 4.7) ms | 537 / 342 | 0.333 / 3.1 s |
| g0 headless (no rasteriser) | — | — | 4 | — | 0 | 3.2 / 6.4 | 4.7 (**3.4** / 1.7) ms | — | — |
| budget | ≤ 150 / ≤ 250 | ≤ 150k | ≤ 8 | ≤ 250 | 0 | — | ≤ 4 (view + HUD) | ≤ 1500 / ≤ 1000 | warn > 35 % |

  Every row inside budget except the rendered view + HUD script time (4.6–5.1 ms p95; llvmpipe rasterises on the same
  4 cores); headless (no rasteriser) view + HUD is 3.4 ms p95. (prologue_required is from the first pass, before the
  view/sim split; slow's tris max was 102.4k in that pass.) Process start → curtain up (Boot → PLAY, e2e): P00 7.7–7.9 s real time (g0
  11.8 s under fixed 60 fps). Retry 907 ms (≤ 1.5 s).
- **R15**: pip_on_share / pip_longest_s — g0 0.280 / 6.4 s; P00 ideal 0.295–0.298 / 2.5 s (4 runs); required 0.380 /
  4.5 s (above the 35 % warning); slow 0.330–0.333 / 3.1 s (in LANDED.md). The P00-ideal share is under 35 %, so `bellows_window` stays "sim".
- **e2e**: g0_sneeze strict: g0_done, 0 script errors, 0 compiles; red only on 9 clip fallbacks. prologue_ideal /
  required / slow strict: prologue_done, laughs by 60 s 7 / 4 / 7, slow first laugh 4.3 s / first prank 25.3 s, 0
  doubles, 0 compiles, every `laugh_*` cue staged with its crowd 0.0–0.26 s later (after the probe clock fix: the
  earlier 0.32 s / 0.87 s reds were the probe stamping cue and crowd on clocks a frame apart); latest ideal + slow red
  only on 11 clip fallbacks (9 Bellows clip ids). slice_all (headless): g0, P00 ×3,
  n01_required/slow, n02_required/slow, n01_chase, n01_meltdown PASS; n01_ideal / n02_ideal / n01_caught red → fixed
  and re-run PASS. Flows: retry, pause_back, touch_smoke, curtain_call (P00 9.5 s → Next → N01 6.5 s / repeat 6.5 s →
  N02 → playbill → To be continued; g0 Again live 356 ms), tap_accuracy (every P00 / g0 live hotspot 20/20 at ±40 px on
  the projected boxes, 0 neighbours, 0 drags that moved; N01/N02 info 20/20) — all PASS.
- **E2E_TIMEOUT table** (measured; also in `tools/scripts/e2e.sh`'s header): g0_sneeze fixed 60 → 210 s (373 s with a
  shot sequence) → 600 s; prologue_ideal 134–163 s → 600; prologue_required 152 s → 600; prologue_slow 147 s → 700;
  retry 26 s, pause_back 30 s, touch_smoke 20 s → 400; curtain_call 115 s → 900; tap_accuracy 73 s → 1200;
  n01/n02 rendered not measured (est. ~14 min → 1800); slice_all headless 576 s for 13 routes.
- **APK**: `build/android/mischief-debug.apk` 71 MB, verify_android OK; `unzip -l`: 4225 files — art3d/ 126 + 51
  imported glb scenes, data/rigs3d 7, data/anim/*3d 38, data/view, data/house/house3d.json, view3d/ 72, shaders 9;
  **0** entries under tests/, tools/, solver/, scenes/dev/, view3d/sandbox/, view3d/probe/, ui/demo/, */_src/,
  data/solutions/, addons/; boot_config.json inside = the owner values.
- **Looked at** (1200×540): both route strips, the g0 and P00 curtain calls, the Gag Reel, stage door, Cast (all beats +
  turn), the Gate-0 card, `--hud=off --no-captions`, N01 boot. Iterated after looking: Gag Reel framing loosened; Cast
  plinth black → stone; Gate-0 card honey thumb cropped → reframed; LIVE RIG glove missing → `hand_rig`.

## 5. Deviations

- Bows render in their **own** World3D (not the Night's): the curtain hides the house, and the lip camera must not see
  the set; same rigs, same clips.
- The Gag Reel does not replay sounds (the 2D reel re-ran the sim with its sounds; the 3D one re-poses frames).
- `script_ms_p95` is the whole frame's `_process` time; its split `view_ms_p95` (view + HUD, the 4 ms row) /
  `sim_ms_p95` (the SimDriver's `_process`, including the `ticked` handlers) is by an `_AfterSim` stamp.
- The hitch threshold is relative (2.5 × the running median, floor 50 ms): the CPU box's median frame is ~100 ms.
- R11 crowd check uses max(0.3 s, one frame) as briefed; the probe now stamps cue and crowd on the same clock.
- `--hud=off` hides the HUD, world overlays, bubble and Stalls, not the curtain call's own panel.

## 6. Requests

- **r3d-view3d** — `game/view3d/stage/stage_lighting_3d.gd:188` `_globals_available()` calls
  `RenderingServer.global_shader_parameter_get_list()`, which logs an engine ERROR ("should never be used outside the
  editor") on every Night — exit row 13 wants 0 engine errors; use `ProjectSettings.has_setting("shader_globals/mnd_fill")`.
- **r3d-view3d** — `game/view3d/world/character_view_3d.gd` `_ensure_plinth()`: `plinth.glb`'s only material is a bare
  StandardMaterial3D (`hush_prop`, no texture) that renders as a flat black disc in the toon world; give its meshes the
  set shader in `View3DConst.STONE` (as the stand-in; the Cast page does it with `CastPage.stone`) — or r3d-cast-hush
  exports it with the palette. Building it at setup (hidden) instead of at the first freeze would also make the warm-up
  list unnecessary.
- **r3d-sets** — `Prop3D` builds the beret tag's material the first time `show_tag` runs (a compile in PLAY unless the
  warm-up shows it): build it hidden at setup.
- **r3d-hud** — `game/data/ui/strings.json`: add `stage_door.g0_head_b` "Gate 0 · Hush, B's head",
  `stage_door.g0_head_scaled` "Gate 0 · Hush, head ×{s}", `stage_door.night1_preview` "Night 1 (preview)",
  `stage_door.night2_preview` "Night 2 (preview)", `stage_door.wip_title` "Work in progress", `stage_door.wip_text`
  "Work in progress: Bellows' reactions in these Nights are not animated yet", `stage_door.wip_play` "Play anyway",
  `stage_door.cast_turn` "Turn" (the screens fall back to these texts until then). Also: N01 at the rise shows every live
  prop's preview bubble at once (5), and the e2e `overlays.loud_max` reads 2 on g0/P00 — for the one-loud rule.
- **r3d-anim-bellows-a / -b** — the clip fallbacks that keep exit rows 13–14 red under `--strict` (latest runs): g0
  bellows/act_tea ×3, act_fixup_mirror, act_warmup, loco_blind_shuffle, mg_admire_in_kettle, mg_admire_reflection_horn,
  mg_walk_hum (9); P00 ideal + slow bellows/act_hunt, loco_stomp ×2, mg_admire_in_kettle, mg_admire_reflection_horn ×2,
  mg_comb_flourish, mg_cravat_tug, mg_peer_under_piano, mg_walk_hum, mg_walk_scale (11). Cast page labels: st_smirk,
  st_suspicious not in yet.
- **r3d-tools-b** — the HUD piece names in `hud_pieces` are `pause`, `script`, `clarence`, `action`, `pip`; report
  fields as in §2.
- **orchestrator** — (1) the O2 probe branch must drop `view3d/probe/*` from `exclude_filter` if its APK needs the
  probe scene; (2) import sidecars / .uid for the new files are in (the WIP commits carry them) — none hand-written;
  (3) GDD/TECH amendment text: TECH §5.x "no shader compiled during PLAY" is measured by first use on GLES3 (the
  pipeline counters are 0 there), with the lazy-scene list; the Gag Reel 3D replays no sounds.

## 7. Gaps

- Exit rows 13–14 stay red under `--strict` only on clip fallbacks (owners above) and row 13's engine ERROR (r3d-view3d).
- N01/N02 rendered runs were not done (headless slice_all only; ~14 min each rendered).
- The device numbers (O2 APK) are not mine; the CPU box's script time is rasteriser-bound.

## 8. Hours

18:01Z → 20:20Z, ≈ 2.3 h wall (of which ≈ 1 h waiting on slot-wrapped runs).
