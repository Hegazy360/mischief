# r3d-view3d — report

The 3D world of "Mischief Next Door", driven by the real sim through `ViewSnapshot`: shaders with look A's vinyl terms,
stage lighting, the camera (C1–C8), both characters on RigPlayer3D, the readability drivers, decals / particles / 2D
overlays, the Bellows window in both modes, the stagers, the Gag Reel ring, the 3D ClipMap + manifest, a sandbox that
plays any Night, and the O2 perf probe. A Night plays end to end in 3D (P00 and g0 on the ideal routes, House3D set,
the cast rigs and every clip that has landed) and the current NightScene can take `WorldView3D` as a drop-in.

## Status against the acceptance list
| Item | State |
|---|---|
| P0a (shaders + globals smoke test, layers, MaterialWarm3D, camera math) | done 16:52Z, announced |
| O1 `shading_a_vs_char_toon.png` | done 16:58Z |
| P0b (a Night plays in ViewSandbox3D + NightScene drop-in, real-time ms/frame, PerfProbe3D) | done 17:58Z, announced |
| Camera C1–C8, punch / push / peek / Map / reduce motion, tests on the numbers; C8 on every tick of g0 + P00 | done (24 camera tests; C8 self-check over both routes in both window modes) |
| CharacterView3D (lane, reach_pos + stool, cheat, travel arcs to 3D landings, hand-offs + keeps, body slots, fallbacks, marble, blob shadows, looks, one-shots, overlays, glances, step-down, sidecar stage facing) | done; hand-offs proven with a fake set (no landed clip emits `prop set:` events yet) |
| Readability: N1 glow, active spot, armed/tag/spent, rig progress, hidden eyes, room lights incl. the lit backstage, "safe" desat + vignette | done (tests + looked at) |
| Decals: stare strip, run + squeak + B-rig rings, destination + path, pop, pins, W3 ghost, N4 pool | done (footprints not built) |
| Both Bellows-window modes + `pip_on_share` | done: numbers below |
| Stagers (Gag, Cue, Caught), 2D FX via OverlayPlacer, particles, audio pan, Stalls hidden at rest | done; the shared placer is a soft hook r3d-night wires |
| `SliceClips.build3d` + ClipMap 3D + `clip_rules.json` | done: 74 rows for g0 + p00 (70 at spec time + the new flavour rows / landed map keys) |
| Fallback counts 0 on g0 / P00 **with the real clips** | puppets 0, greybox props 0; clip fallbacks 51 on P00 — every one is a clip not authored yet (list below) |
| Perf budgets | draw calls / triangles / textures / emitters well inside; view scripts mean 1.4 ms, p95 above 2 ms under load (below) |
| Suites + lint | see "Verification" |
| `docs/review/r3d-view3d/` with mock comparisons and strips, looked at | done: index.md |

## Files (all inside this brief's §2)
- **Shaders** `game/art3d/shaders/`: `stage_light.gdshaderinc`, `char_toon`, `set_toon`, `prop_toon`, `outline`,
  `outline_prop`, `halo`, `decal`, `fx_toon` (`.gdshader`).
- **Stage** `game/view3d/stage/`: `view3d_const.gd` (units, depths, camera numbers, layers, colours, shader paths),
  `stage_lighting_3d.gd` (room levels + globals), `material_warm_3d.gd` (warm registry + warm rig).
- **Camera** `game/view3d/camera/`: `camera_director_3d.gd`, `gag_stager_3d.gd`.
- **World** `game/view3d/world/`: `world_view_3d.gd`, `character_view_3d.gd`, `decals_3d.gd`, `fx_3d.gd`,
  `overlays_3d.gd`, `cue_stager_3d.gd`, `caught_stager_3d.gd`, `moment_recorder_3d.gd`, `greybox_set_3d.gd` (the
  House3D fallback, unused now).
- **Window** `game/view3d/pip/pip_view_3d.gd`. **Probe** `game/view3d/probe/{perf_probe_3d.gd,PerfProbe3D.tscn}`.
- **Sandbox** `game/view3d/sandbox/`: `view_sandbox_3d.gd` + `ViewSandbox3D.tscn`, `lookdev_studio_3d.gd`,
  `dump_slice_clips_3d.gd`.
- **Adapted 2D-era files I own**: `game/view/audio_director.gd` (duck-typed camera/world; 3D pan by projected x;
  3D sidecar sounds), `game/view/stalls/stalls_view.gd` (`hidden_at_rest`), `game/view/world/clip_map.gd` (3D format),
  `game/view/world/slice_clips.gd` (`build3d`), `game/data/anim/clip_rules.json` (+4 `view: "3d"` rows, one-row-per-line
  format kept).
- **Tests** `game/tests/view3d/`: `shader_smoke.gd` + `ShaderSmoke.tscn` (rendered), `test_camera3d.gd` (24),
  `test_stage_lighting3d.gd` (8), `test_view3d_rules.gd` (23), `test_world_view3d.gd` (3 route tests);
  `game/tests/view/fixtures/cmds/n01_throat_tea_{ideal,caught}.cmds.json` refreshed (r3d-content's note).
- **Docs** `docs/review/r3d-view3d/`: index.md, neighbour_strips.md, slice_clips3d.md, boards and strips.

## APIs for r3d-night / r3d-integrate
Wiring (exactly what `ViewSandbox3D.build(world)` does):
```
driver := SimDriver.new(); add_child(driver); driver.setup(world)
cam := CameraDirector3D.new(); cam.time_source = driver; add_child(cam); cam.make_current()
wv := WorldView3D.new(); wv.cam = cam; add_child(wv); wv.setup(db_or_null, episode_or_null, driver)
cam.follow(wv.hush_view, lead_fn)          # lead_fn -> float dir | Vector2(dir, running)
cam.set_other(wv.bellows_view); cam.set_keep_visible(fn)   # fn -> [AABB] live props of her room (C6)
pip := PipView3D.new(); add_child(pip); pip.setup(wv, cam); wv.pip = pip; hud.attach_pip(pip)
stager := GagStager3D.new(); add_child(stager); stager.setup(driver, cam, wv, pip)
audio.setup(driver, cam, wv)               # AudioDirector, duck-typed
stalls.hidden_at_rest = true               # StallsView on CanvasLayer 9
wv.overlays.placer = world_overlays.placer # r3d-hud's shared OverlayPlacer (soft; null = local rules)
wv.hud_rects = hud.always_on_rects()       # protected rects for captions / TapAssist (+48 px inside)
```
- **WorldView3D** (same entry points as WorldView): `setup`, `reset`, `character(id)`, `prop(id)`,
  `fallback_counts() {clip_fallbacks, puppets, greybox_props, by_clip}`, `reveal_badges(on)` / `previews_forced()`,
  `sparkle(hotspot, s)`, `hotspot_rects_in_view()` ([{id, kind, rect (logical px, projected House3D.hotspot_box),
  world_rect, room, priority, enabled, stack}] + a `floor:<room>` band per built room), `warm_clips(extra)`,
  `preroll(dt)`, `tap_feedback(Vector2 screen | Vector3)`, `target_point(target) -> Vector3`, `entry_warning_active()`,
  `start_busted_replay(spotted_tick)` / `end_busted_replay()`, `on_ticked(events)`; signals `built`,
  `cue_staged(id, kind)`, `replay_changed(on)`, `edge_badge_wanted(on)`, `tag_flight(hotspot)`.
  Anchor source (§7.8): `project(Vector3) -> Vector2`, `anchor_of(hotspot, &"preview"|&"tag"|&"ring"|&"item"|&"eyes"|&"reach")`,
  `actor_anchor(&"hush"|&"bellows", &"head"|&"top"|&"chest"|&"feet")`, `actor_screen_rect`, `prop_screen_rect`,
  `protected_rects()`, `safe_rect()`, `on_screen(p)`. Visibility (§7.9): `bellows_on_screen()` (≥ 35 % of his projected
  bounds), `visibility_sample() {tick, sim, reason, on_screen, window, badge}`, `edge_badge_active()`, `window_mode`
  ("sim" | "lean", from Settings `bellows_window`). `warm_materials(cam) -> Node3D` (free after 2 frames).
  Replay (Gag Reel): `recorder` (MomentRecorder3D: `keep(from, to, tag, applause) -> id`, `moment(id).frame(i)`,
  `kept()`, `clear()`), `show_moment_frame(frame)`. Stagers: `cues` (CueStager3D), `caught` (CaughtStager3D).
  **NightScene shims** (so today's NightScene runs unchanged): `warm_hint` (its `clips` list is warmed), `unlocked`,
  `lit_x_range()` (sim px), `fx` (FxShim: `ripple(px)`, `path_dots(points)`, `clear()`, `avoid_screen_fn`).
  `profile` + `prof_us` / `prof_frames` (per-phase µs, perf runs).
- **CameraDirector3D**: `follow`, `set_other`, `set_keep_visible`, `set_safe_rect`, `set_hold_offset(on)` (C4),
  `pan_by` / `end_pan` / `pinch`, `toggle_overview` / `is_overview`, `peek` / `is_peeking`,
  `request_gag(focus: Vector3|Node3D|Vector2 px, zoom, in_f, hold_f, out_f, priority, yaw_deg, approach_f, approach_zoom) -> id`,
  `punch_gag`, `set_gag_focus`, `release_gag`, `cancel_gag`, `clear_gags(keep_id)`, `is_gag_active`, `gag_phase`,
  `shake`, `kick`, `set_reduce_motion`, `project`, `project_aabb`, `screen_to_plane`, `visible_world_rect`,
  `px_per_m_at(z)`, `visible_width_at()`, `aim()`, `distance()`, `yaw_deg()`, `framed_room()`, `is_two_shot()`,
  `snap_now`, `reset_motion`, `advance(view_dt, real_dt)`; `logical_size_override` for headless tests;
  static `rooms_from` / `links_from` (Dictionary or ContentDB) / `built_ids`.
- **PipView3D**: SubViewport sharing the World3D; `setup(wv, cam)`, `shown_changed(on)`, `pip_resized(size)`,
  `screen_rect()`, `escalate(on)`, `share() {frames, shown_frames, pip_on_share, pip_longest_s}` / `reset_share()`,
  `warm()`, static `want_window(on_screen, sim_pip, reason, lean, busy)` / `is_busy(snap, bellows_view)`.
- **CharacterView3D**: `placement_for` (static), anchors (`head_world`, `top_world`, `chest_world`, `feet_world`,
  `world_aabb`, `socket_world`, `socket_node`), `current_clip/frame`, `overlay_clip/frame`, `lane_z`, `cheat_deg`,
  `show_explicit(pos_px, …)`, `show_world(pos3, facing, cheat, clip, frame, shown, looks, tier, ov_clip, ov_frame)`,
  `pose_replay`, `preroll`, `play_cue`, static `rig_stage` / `clip_stage` / `clip_keeps` / `rig_looks` / `residue_slots`.
- **Overlays3D**: `caption(text, at, size, actor)`, `stamp`, `freeze_frame(on)`, `wipe(centre)`, `set_safe(on)`,
  `busted(on)`, `bubble_rect()`, `head_rect(actor)`, static `caption_place(head, box, screen, band_y, prefer)`.
- **PerfProbe3D** for O2: `res://view3d/probe/PerfProbe3D.tscn` (drives House3D + RigPlayer3D directly; nothing
  export-excluded); `--probe-s=<s>`; `[perfprobe]` lines to `user://perfprobe.log` + the summary card.

## Shader uniforms as built
Globals (project.godot `[shader_globals]`, set by StageLighting3D): `mnd_key_dir, mnd_key_color, mnd_key_lit,
mnd_key_top, mnd_fill, mnd_fill_color, mnd_band_soft, mnd_rim_color, mnd_rim_power, mnd_foot_strength, mnd_foot_fade_m,
mnd_lip_z, mnd_outline_scale, mnd_shadow_tint, mnd_bounce, mnd_sheen`. All shaders `unshaded`, lit by
`stage_light.gdshaderinc` (A's vinyl terminator −0.05 ± 2·band_soft, shadow tint, top band, bounce, footlight gradient,
rim `smoothstep(0.10, 0.42, fresnel^power)`, a luminance floor at `mnd_fill` × albedo — the smoke test checks 0.330 ≥ 0.315).
- `char_toon`: palette, albedo_color, face_atlas, face_grid (ivec2 cols, rows), face_cell_a (brows, eyes, pupils,
  mouth), face_cell_b (extra_a, extra_b, lids, spare), face_rect[6], pupil_offset, pupil_range, tint_color
  (a = amount, on COLOR.r skin), stone + stone_color (COLOR.g keeps), flash + flash_color, rim 0.45, rim_damp 0.6
  (× COLOR.b), stage_light, key_front 0.35, desat, vc_masks.
- `set_toon`: palette, albedo_color, stage_light, desat, emissive_gain (palette alpha < 0.5 = emissive).
- `prop_toon` (`stencil_mode write, compare_always, 1`): palette, albedo_color, stage_light, key_front, desat,
  glow_color, glow_amp (0 / 1 / 2), glow_hz 1.2, glow_phase, halo_fresnel, spent.
- `outline` (inverted hull, grows VERTEX in view space by logical px): ink #1B2340, outline_px 3.5 @1080 ×
  mnd_outline_scale × COLOR.a (width_from_alpha), use_color_normal, room_color / room_lerp, stage_light, max_world 0.05.
- `outline_prop`: the same + `stencil_mode write, compare_always, 1`, outline_px 2.5.
- `halo`: see below. `decal`: shape (0 TEX, 1 DISC, 2 RING, 3 STRIP, 4 DOTS), tex, color, color2, softness, inner,
  seg_a, seg_b, dots, progress, stage_light. `fx_toon`: albedo_color, tex, billboard, emissive, stage_light, key_front,
  alpha_scissor, **round_disc** (new: untextured billboards are soft discs shaded as little vinyl balls — the CHOO puff
  read as white squares).

## Halo technique: STENCIL (proved on Compatibility 4.7.2)
The live prop (`prop_toon`) and its ink (`outline_prop`) write stencil ref 1; `halo.gdshader` is its own
MeshInstance3D on layer 3 PROP_INK: a `cull_front` shell grown by ink_px + halo_px (8 px), drawn only where
stencil ≠ 1, with its depth pulled 0.30 m toward the camera (so a prop set into the wall still shows its halo), a
blend_mix alpha pulse (glow_color, glow_amp, glow_hz, glow_phase). The Bellows window's camera excludes layer 3.

## Perf numbers
- **Real time (R11), P00 ideal, 1200×540, xvfb + llvmpipe (software GL) on 4 shared cores at load ~6**:
  MSAA off — frame ms **p50 85.1 / p95 125.2** (11.0 fps); MSAA 2× — **p50 199.9 / p95 265.8** (4.9 fps); draw calls
  p95 51 / max 66; primitives max 87k; textures 41–51 MB; view scripts p50 1.45 / p95 2.5–3.0 ms.
  **For E2E_TIMEOUT:** Godot clamps the frame delta at 66.7 ms (4 physics steps), so the sim runs slower than the
  wall clock above 67 ms/frame: the 59.6 s Night took 81 s (MSAA off) / 183 s (MSAA 2×). Use `--msaa=0` for timing
  runs and budget ×1.5.
- **Headless fixed 60 Hz, P00** (`ViewSandbox3D --run-s=59`): view scripts **mean 1.40 ms/frame** (Hush apply incl.
  lights 0.57, Bellows 0.22, caught + recorder 0.12, props + cues 0.13, decals + particles 0.06, overlays 0.31);
  p50 1.3–1.6, p95 2.6–4.3 ms (noisy: load average 6.5 on 4 cores). The mean is inside the 2 ms budget; the p95 is
  not on this box — the rig players (~0.2 ms each, r3d-rig's) and the overlays are the largest shares.
- **Budgets:** draw calls p95 51 (≤ 150) with both characters, the window and bursts; ≤ 105k triangles (≤ 150k);
  ≤ 8 emitters (pooled, `fixed_fps` 30); textures ≤ 51 MB (≤ 150); the Bellows window renders only while shown, at
  30 Hz; objects / nodes flat over 10 s of PLAY (15768 → 15770 objects, 297 → 297 nodes — a test).
- **PerfProbe3D** (desktop llvmpipe, 3 s runs): msaa2 4.7 fps · msaa off 8.9 · scale 0.85 4.8 · ink off 4.9 ·
  cheapest 11.2; 43 draws (36 without ink); 95–105k tris (54k without ink); 30–40 MB. On llvmpipe MSAA 2× costs ~2×
  and render scale barely matters (the cost is per-sample, not per-pixel shading) — say nothing about phones; that is
  what the probe APK is for.

## Bellows window share (R15), fixed 60 Hz, ideal routes (test_world_view3d, C8 held on every tick)
| route | sim mode | lean mode |
|---|---|---|
| g0 | 30.4 % open, longest 7.2 s | 16.8 % open, longest 2.3 s; edge badge 4.7 s |
| P00 | 30.4 % open, longest 10.7 s | 9.4 % open, longest 2.3 s; edge badge 12.7 s |

## What I changed after LOOKING (1200×540)
The sneeze punch held him at the frame edge (C2 won) → focus kept in the middle 36 %; 20 % of the punch frame was the
dark pit → the aim rises (≤ 0.35 m below the floor); the caption covered his face and drifted into the HUD band →
screen-space captions placed beside the head every frame, keeping their side; his bubble covered the payoff → hidden
while he reacts, and moved beside his head when the HUD band blocks it; he snapped from the sink to the floor → the
landing height eases back; a seek into a reaction panned in from the old framing → kept gags re-base; the CHOO puff
was white squares → round vinyl particles; the probe card was unreadable over the set → a navy panel.

## Requests
- **r3d-sets:** (1) `Prop3D._make_tag()` instances `tag_beret.glb` with its imported (lit) StandardMaterial3D — in our
  unlit world it renders as a **black ellipse** (see `mock_armed_entry_vs_3d.png`); give its meshes `prop_toon` with the
  Hush palette like the other glbs (any glb left on import materials will be black). (2) `hide_spot_3d.gd` briefly
  failed to compile against a changed `Prop3D.setup` signature at 17:37Z (fixed by 17:45Z) — WorldView3D falls back to
  the greybox when House3D cannot instantiate, PerfProbe3D now does too.
- **r3d-cast-bellows:** rig3d.json lists `bouffant_wet.glb` / `bouffant_floured.glb` attachments that did not exist at
  17:3xZ (RigPlayer3D errors at every setup); the FRAZZLED bouffant reads as **bald with side puffs** at game scale
  (P00 strip ticks 1460–1600) — worth a look at 1200×540.
- **r3d-anim / r3d-anim-bellows-* / r3d-anim-hush-b:** P00 clip fallbacks (51, in the 18:07Z render) are all clips not authored at that time: bellows
  act_fixup_mirror, act_hunt, act_tea (the hand-off events `prop set:` are what lend the kettle / jar — none yet),
  act_warmup, bit_warmup, cue_doorframe_bonk, cue_picture_bonk, loco_blind_shuffle, loco_irked, loco_stomp,
  loco_strut, mg_admire_in_kettle, mg_admire_reflection_horn, mg_comb_flourish, mg_cravat_tug, mg_peer_under_piano,
  mg_walk_hum, mg_walk_scale, rx_dizzy_spin_a, st_look_back, st_specs_on; hush act_climb_in, act_dive, act_glance,
  act_pop, act_squeak, rig_allegro_go_go. The full manifest: `docs/review/r3d-view3d/slice_clips3d.md` (74 rows, 7 with
  a sidecar at the time of writing; the sneeze and tea clips landed during this run and play correctly). Honoured:
  the sidecar `stage.facing` + `cheat_deg ≤ 10` while a rig clip plays. On r3d-cast-hush's ACHOO-RIA! staging note: a
  larger turn toward the wall needs a lead exception to R5d (≤ 10° while reaching); the view can take a negative
  `stage.cheat_deg` if the lead allows it.
- **r3d-night:** wire `wv.overlays.placer = WorldOverlays.placer` and `wv.hud_rects`; `hud.attach_pip(pip)`; connect
  `wv.edge_badge_wanted` to the HUD edge badge; `E2E_TIMEOUT` sizing above; NightScene's `world_view: WorldView` typing
  must become duck-typed (the shims cover `warm_hint`, `unlocked`, `lit_x_range`, `fx`). The Busted Cam / Gag Reel
  re-stage uses `wv.recorder` + `wv.show_moment_frame`.
- **Lead:** (1) neighbour strips vs C2 (`neighbour_strips.md`: the N1/P00 kitchen shows 3.16 m of the parlour at 20:9
  because C2 pins it at x 15.32; the 5 m hall cannot meet 1.7 m at the base distance) — built as "the rule applies to
  interior rooms", two dolly options costed; (2) outline width: A's look-dev drew 4.8 px @1080 vs the spec's 3.5 px
  (kept at the spec; Settings "Outline +50 %" = 5.25 px); (3) the manifest is 74 rows now, not 70.
- **r3d-cast-hush / r3d-cast-bellows (repeat from O1):** face atlas cells ≥ 256 px wide (A's were 340; 128-px cells
  blur the eyes).

## Not done / known gaps
Footprint decals; the marble-freeze + stare-strip mock and the tea hand-off strip (no route / clip for them yet); a
rendered lean-mode strip (numbers only); view-script p95 above 2 ms on this loaded box; fallback counts are 0 only
for puppets and greybox props until the clips above land.

## Verification
- `tools/scripts/test_game.sh r3d-view3d -- view3d/ view/`: **238 passed, 0 failed** (view3d: camera 24, lighting 8,
  rules 23, world-view routes 3; view/ 20 files 180).
- Full suite `tools/scripts/test_game.sh r3d-view3d`: **1413 passed, 2 failed** of 1415 — both other tasks' in-flight
  data, not the view: `cast3d/test_hush3d::test_props_sample_used_palette_cells` (r3d-cast-hush: new prop glbs'
  UVs off the palette cell centres) and `ui/test_hud_s2::test_emote_reaches_the_bubble_and_clears` (r3d-hud / the new
  bellows portraits).
- `SANDBOX=r3d-view3d tools/scripts/lint.sh`: **rc 0** (the 3D clip lint: 16 clips, 0 errors, 61 not baked yet).
- The rendered shader smoke test (fresh process): `PASS shaders=8 errors=0 floor_set=0.330 floor_char=0.330`.
- Looked at: the g0 sneeze (4 strips, re-rendered after each fix), the whole P00 Night (6 strips), the Bellows window
  crops through the hall, the probe card, the accent frames after the particle change.

## Hours
About 3 h of wall time in this run (16:1x–19:1x UTC), inside the ≈ 8 h P0b box; most of the render time is llvmpipe
at 2–5 fps under a shared CPU.
