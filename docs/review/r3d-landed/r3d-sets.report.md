# r3d-sets: report

Branch `r3d`. I made no git writes; the orchestrator commits. Landings are in `<SP>/work/r3d-sets/LANDED.md`: P0 17:20Z, P1a 17:58Z, P1b 18:21Z, P1c 19:23Z, P2 at the end.

## 1. Outcome

The slice's 3D sets are built in look A with the board's fixes:
- the Prologue and Gate 0 rooms (kitchen, parlour, dark hall) at final polish;
- the Night 1 and Night 2 rooms (porch, hall, parlour, kitchen) complete.

Every built room of every slice Night is rendered at 20:9, 16:9 and 4:3 with both characters. The renders are looked at and indexed in `docs/review/r3d-sets/index.md` (6.2 MB).

On a phone held sideways, the renders address the owner's complaints as follows:
- **UI and house too crowded.** Each room has one flat wall field, a wainscot and a picture rail, and at most 4 dressing pieces. Only tonight's live props glow. Struck props are simply not built: the N2 kitchen has no empty honey shelf, and N1 has no fridge or table.
- **Characters.** Hush and Bellows own the value extremes (lab.py character rule PASS).
- **Actions not obvious.**
  - Each live prop is a saturated, outlined toy.
  - "Armed" shows Hush's red beret tag.
  - Hit boxes are ≥ 163 logical px and ≥ 24 px apart.
  - Hidden eyes show in the hiding spots.
- **Staging.** Tea staging, reach and landings are all checked by data and tests.

## 2. Files (all within my §2)

**`game/data/house/house3d.json`** is the view data contract. It is view-only; `house.json` is untouched.

**`game/view3d/set/`:**
- `set_geo.gd`
- `set_list.gd`
- `set_prims.gd`
- `set_mats.gd`
- `prop_3d.gd`
- `hide_spot_3d.gd`
- `room_shell_3d.gd`
- `house_3d.gd`
- `set_check.gd`

**`game/scenes/dev/set3d/`:**
- `SetPreview3D.tscn` with `set_preview_3d.gd`
- `SetPreviewBatch3D.tscn` with `set_preview_batch_3d.gd` (new: many shots in one import)

**`game/tests/set3d/`** (37 tests):
- `test_house3d_data.gd`
- `test_set_list.gd`
- `test_house3d_build.gd`

**`tools/art3d/set/`:**
- `build.sh`
- `build.py`
- `setlib.py`
- `palettes.py`
- `measure.sh`

**`game/art3d/set/`:**
- 4 room arch glbs, plus the hall's front-door leaf
- conditional built-ins: `kitchen_honey_shelf`, `kitchen_dresser_rack`, `kitchen_pickle_shelf`
- 17 furniture, dressing and decor glbs
- `palette_<room>.png` ×5, `palettes.json`, `build_report.json`

**`game/art3d/props/`:**
- 16 live-prop glbs, each one skinned mesh with parts as bones: honey jar, kettle, pickle jar, sink tap, fridge, pantry, gramophone, piano, recliner, newspaper, chandelier, wardrobe, crate, phone, mirror, clock
- `palette_props.png`

**`docs/review/r3d-sets/`:**
- `index.md`
- `rooms/` (39 frames + 4 Night boards)
- `rects/` (8)
- `props_states.png`
- `silhouettes_64.png`
- `before_after.png`
- `hide_eyes.png`
- `value_map.png`
- `tea_staging.png`
- `reach_check.png`
- `landings.png`

Built size is about 1.5 MB of glb. The set textures are 6 palettes at 256², about 1.5 MB in VRAM against the 8 MB budget.

## 3. API as built

**house3d.json blocks:**
- `version, notes, units`
- `reach{shoulder_y_m 1.127, shoulder_half_m 0.118, tiptoe_m 0.07, kneel_drop_m 0.42, max_m 0.5, bands, step_above_m 1.7, hush{radius_m, height_m}, bellows{radius_m, barrel_y_m}}`
- `stage{lip, apron, proscenium (z −2.3, gold edge 3.13 m), wing_flat (front z −1.4, 0.22 m), end_flat, footlight, void}`
- `rooms.<id>{wall, wainscot(+h), rail(+h), floor[2], outdoor, arch, palette, built_ins.<id>{box, color, with?, basin?, firebox?, steps?, leaf?}}`
- `hotspots.<id>{model, primitive, z, yaw, scale, visual_offset, hit_box, hit_z_half?, bounds, collide?, reach, reach_target, reach_pos{dx, z, step, step_h}, silhouette, view_kind, color, states, anims, parts, tag_socket, preview_anchor, ring_anchor, item_anchor, eyes_anchor, halo, stack, merge/zone/zone_bounds?, part_of?, staged_by?, seat_y_m?, why_offset}`
- `stations.<id>{bellows_z, yaw, furniture, seat_y_m, handoffs[{prop: "set:<id>", socket}]}`
- `furniture.<id>{x_m, y_m, z, yaw, box, model, seat_y_m, anims, with}`
- `landings.<room>.<name>{z, y, yaw, box, host}`
- `dressing.<id>{room, x_m, y_m, z, box, model, nights | quake | landing | with | on}`
- `decor.<id>{room, model, cue | station | of, anims, hidden}`

**`SetGeo`** (pure, static):

| Function | Returns / notes |
|---|---|
| `load_house3d(path?, reload?)`, `clear_cache()`, `reach_cfg(h3)` | the data and its reach config |
| `rect_m`, `prop_origin`, `basis_of`, `prop_xform`, `to_world` | prop placement |
| `local_bounds`, `world_aabb`, `world_obb(s)`, `obb_from_box`, `obb_aabb` | boxes |
| `hit_box(rect, e)` | AABB: the explicit box or rect + `visual_offset`, z ± `hit_z_half` (default 0.3) |
| `contains_xy`, `band_of` | tests |
| `reach_stand`, `reach_info(rect, e, use_x, cfg)` | `{target, band, shoulder, dist, ok, step, step_h, needs_step, stand}` |
| `capsule`, `hush_capsule`, `bellows_capsule`, `capsule_obb_depth`, `capsule_hits` | collision checks |
| `s`, `vec2`, `vec3`, `color` | conversions |

**`SetList.for_episode(db, episode, house3d = {}, prefer_sim = true) -> SetList.Result`:**
- Result fields: `rooms_lit, rooms_backstage, live{id: kind}, furniture, furniture_pieces, dressing, decor, quake, landings, handoffs, dormant, architecture, struck, stations, pranks, meltdown, live_source`.
- Result methods: `rooms_built()`, `is_room_built(r)`, `role(id)` (live, furniture, dormant, architecture, struck or absent), `is_built`, `room_of`, `ids_in(room, role)`, `live_props_in(room)`, `to_dict()`.
- Static helpers: `tonight_pranks`, `local_live`.
- The live mask is `SimCtx.live_hotspots` when present; a test holds `local_live` equal to it.

**`House3D`:**
- Setup: `merge_static := true` (set before build), `build(result, house3d = {}, db = null)`.
- Props: `prop(id) -> Prop3D`, `props()`, `rooms_built()`.
- Lighting: `set_room_light(room, level, desat)` (0.4 s tween), `snap_room_light`, `room_light(room) -> Vector2`.
- Queries: `advance(dt)`, `hotspot_box(id) -> AABB`, `floor_band(room)`.
- Decor: `decor(id)`, `play_decor(id, anim)`, `set_decor_visible(id, on)`.
- Lending: `lend(id | "set:<id>", to, frames = 6) -> Node3D`, `return_home(id, frames)`, `return_all()`.
- Landings: `landing_box(id)`, `landing_point(id) -> {pos, yaw}`.
- Staging data: `furniture_boxes()`, `collision_solids()`, `reach_pos(hs) -> {x, z, step, step_h}`.
- Diagnostics: `room_material_count(room)`, `room_shell(room)`, `merged_pieces()`, `static_draws(room)`, `room_tris(room)`, `stats() -> {rooms, props, pieces, solids, merged, build_ms}`.

**`Prop3D`:**
- `setup(id, entry, xf, room, verb, live, room_color, mats = null, palette = null)`
- State: `set_state(&"idle"|&"armed"|&"spent"|&"open")`, `state()`, `set_rig_progress(0…1)`, `rig_progress()`
- Look: `set_glow(color, amp)`, `glow_amp()`, `set_light(level, desat)`, `show_tag(on, animate)`, `tag_shown()`, `tag_wiggle()`
- Animation: `play(anim)`, `playing()`
- Parts: `set_part(part, on)`, `part_visible`, `has_part`
- Hiding: `set_occupied`, `occupied`, `eyes_look`, `eyes_blink`
- Placement: `anchor(&"preview"|&"tag"|&"ring"|&"item"|&"eyes"|&"reach")`, `home_aabb()`, `lend(to, frames)`, `return_home(frames)`, `is_lent()`
- Other: `advance(dt)`, `counts()`, `verb_color(verb)`, `is_static_glb()`, `static_meshes()`, `hide_visual()`
- Animations: `lid_flip wobble nudge fall smash play spray ring avalanche door_open close burst breathe launch pogo swing shatter`. A prop only processes while an animation plays.

**`HideSpot3D`** (a Prop3D): `set_occupied`, `eyes_look`, `eyes_blink`, `look_dir`, `eyes_visible`. The eye card is r 0.046.

**`SetCheck.run(house)`** returns `{episode, reach[], collisions[], errors[], warnings[]}`. Reach problems are errors on P00 and g0, warnings on N1 and N2.

**`SetPreview3D` flags:**
- `--episode --room --x --zoom --y --lit`
- `--hit-rects --anchors --reach=hush --check`
- `--state=<hs|all>:<idle|armed|spent|rig@f>`, `--glow`, `--tag`, `--occupied [--look]`, `--decor=<id>:<anim>`, `--lend`
- `--landings --rects-json=/abs --perf --counts`
- `--pass=id --legend=/abs --no-merge`
- `--chars` with `--hush_*` / `--bellows_*` (`x y z facing cheat clip frame anim_glb anim_name`)

**`SetPreviewBatch3D --jobs=/abs.json`** takes `[{out, frames, args}]`.

## 4. Per-room counts (final build, `--counts`)

"Pieces" counts dressing, decor and furniture. Tris include the ink and halo passes. Static draws are the merged arch + static pieces, plus unmerged pieces. Prop draws are 3 per live prop plus 1 per furniture-role prop. Framed draws are measured at 1200×540 with the set only (`--perf`).

| Night | Room | Live | Dressing (+decor/furn.) | Tris | Static draws | Prop draws | Framed draws |
|---|---|---|---|---|---|---|---|
| P00 | kitchen | 2 | window, lamp (+stool) | 14,124 | 2 | 8 | 20 |
| P00 | parlour | 2 | window, portrait (+vase, picture) | 8,208 | 3 | 6 | 29 |
| P00 | hall (backstage) | 0 | — | 2,856 | 2 | 1 | — |
| g0 | kitchen | 2 | window, lamp (+stool) | 14,124 | 2 | 8 | — |
| g0 | parlour | 0 | window, portrait | 3,230 | 1 | 1 | — |
| N1 | porch | 0 | — | 1,552 | 1 | 0 | 28 |
| N1 | hall | 2 + exit | window, coat stand, hats | 7,630 | 3 | 7 | 31 |
| N1 | parlour | 2 | window, portrait, log basket (+fire) | 10,398 | 3 | 9 | 39 |
| N1 | kitchen | 5 | window, lamp, pans (+stool) | 20,532 | 3 | 15 | 34 |
| N2 | porch | 0 | — | 1,552 | 1 | 0 | 35 |
| N2 | hall | 5 + exit | window, coat stand, hats (+phone table) | 16,284 | 3 | 15 | 36 |
| N2 | parlour | 2 | window, portrait (+fire) | 6,194 | 3 | 7 | 35 |
| N2 | kitchen | 3 (fridge ×2 zones, pantry) | window, lamp, pans | 13,188 | 2 | 10 | 24 |

Budget results:
- **Triangles:** ≤ 25k per lit room holds (max 20.5k).
- **Static draws:** ≤ 3 per room holds, tested.
- **Framed draws:** ≤ 45 holds (max 39).
- **Build time:** `House3D.build` takes 21–76 ms (≤ 150 ms).

## 5. Measured L*/C* (lab.py `rules --rules=set` on ID-pass regions)

| Room (lit) | Wall L* / C* | Wainscot ΔL* | Floor L* |
|---|---|---|---|
| kitchen | 67.8 / 22.1 | 8.8 | 49.5 |
| parlour | 66.1 / 14.8 | 9.5 | 49.5 |
| hall | 65.8 / 12.6 | 9.7 | 49.5 |
| porch | 70.3 / 18.9 | 8.5 | 49.3 |

- **Dimmed neighbours:** kitchen 53.7 / 10.8, parlour 52.7 / 7.0.
- **Dressing:** C* ≤ 12.7 and |ΔL*| ≤ 12.3. The pendant lamp is exempt as the light source.
- **Live props:** C* ≥ 45 or haloed.
- **Characters:** PASS. Hush has 0.22 of her pixels at L* ≥ 85 and 0.62 at L* ≤ 40; Bellows has 0.32 and 0.36.
- **Remaining FAILs:** only the wainscot ΔL* in dimmed or backstage rooms (5–8), and the backstage hall wall at 19.4. Both are by design (§3.7 states the wainscot rule for lit walls; backstage is 0.3). See the requests.

Palette changes this session:
- wainscots: kitchen #A5926C, parlour #A48783, hall #86917A, porch #7CA1B1
- panes: #A9C6D2
- window frames: parlour #CEBDB9, hall #BEC3B3
- floors warmer, closer to look A's toy-box wood: #926647 / #8A6043 (C* ≈ 28–30)
- porch pavement: #767066 / #6E695F

## 6. Staging decisions

**Tea (`tea_staging.png`).**
- Bellows sits on his stool at x 15.0 (`st_tea`), facing the dresser.
- The kettle stands on the dresser counter at 14.40, left of his barrel.
- The honey jar sits on its lowered bracket shelf at 14.55, base 1.79 m, left of his bouffant.
- The ID-pass pixel counts with and without him give: kettle 100 % visible, jar 100 % visible.
- Handoffs are kettle → `grip_r` and honey → `grip_l`; both are a short slide from home.
- His seated pose is the vendored UAL `Sitting_Idle_Loop` as a stand-in until his tea clip lands.

**Reach and the stool step.**
- ACHOO-RIA! climbs Bellows' own stool (`step "stool:kitchen_stool"`, step_h 0.55). Hush stands on the stool's left half at x 14.85, z −1.42.
- The jar was lowered and moved left to meet r3d-cast-hush's request (the mouth must be ≤ 2.04 m for the shaken pepper spout).
- `reach_target` is now the jar mouth, at (14.55, 2.023, −1.72); the reach is 0.446 m.
- The honey shelf and rack are built only when the honey is live.

**Wing flats.**
- At the gramophone lever and the kettle, Hush now reaches from z −1.30. The flats' front is at z −1.40, so they can no longer hide her; before, the hall/parlour flat covered about a third of her at the lever.

**Hit boxes.**
- On neighbours that were close, the boxes are 0.12 m deep (`hit_z_half`), with explicit boxes where needed. This keeps off-centre parallax small.
- Every projected live box is ≥ 163 logical px and ≥ 24 px from its neighbour. I checked this against the rects JSON of every framed room.

**Silhouettes.**
- The fridge is now a squat retro fridge (1.52 m, domed, on legs). Its zone boxes are lower [16.0, 0, 16.8, 0.76] and upper [16.0, 0.86, 16.8, 1.62]; the shelf's reach target is y 0.95.
- The wardrobe got bun feet and a pediment.
- The pickle jar is fat, with a narrow neck.
- No pair is at IoU ≥ 0.80 any more; before, the fridge×wardrobe pair was at 0.94. The highest pair is now pickle jar × piano back at 0.80⁻ (different rooms).

**Tag.** `tag_beret.glb` is drawn on Hush's palette with the prop ink. It rendered black before.

**Every `visual_offset` and its reason** (also recorded in each entry's `why_offset`):
- `kitchen_honey` [−0.15, 0]: the jar stands left of Bellows' bouffant at tea and beside Hush on the stool; its mouth (rim 2.02 m) is under her pepper spout; the hit box moves with the jar and its pot.
- `kitchen_kettle` [−0.30, −0.10]: left of the stool on the dresser counter (0.75 m), ≥ 60 % visible past his barrel.
- `kitchen_pickle_jar` [0.25, −0.35]: on a 1.35 m shelf above his barrel, reachable without a step, and clear of the honey's hit box.
- `kitchen_sink_tap` [0.21, −0.08]: on the sink counter right of the basin, arching over it; the basin stays at the sneeze landing.
- `kitchen_fridge_shelf` [0, −1.47] and `kitchen_fridge` [0, 0.1]: one squat fridge standing on the floor, with two zone hit boxes 0.10 m apart.
- `kitchen_pantry_curtain`, `parlour_recliner` (+0.05 x), `hall_mirror` (+0.12 x), `hall_confiscated_box` (+0.07 x, ×1.4), `hall_coat_cupboard` (+0.04 x), `parlour_gramophone` [·, 0.1]: on the floor (the rects sit 0.10 m below it). The x offsets keep ≥ 24 px between hit boxes, or clear the coat stand's base (the crate).
- `parlour_piano_back` [0.31, −0.87]: clears Bellows' barrel at `st_gramophone` and leaves the 0.30 m hiding gap behind it.
- `parlour_newspaper` [0.33, −0.66]: on the recliner's right arm, as REDESIGN §3.4 says.
- `parlour_chandelier` [0, 0.1]: floor-line correction only; built as furniture on N1 (the LIFT-OFF landing).
- `hall_front_door` [0.3, −0.1]: the leaf sits in the full-depth flat at x 2.50.
- `hall_phone` [0.17, −0.1]: on the phone table top (x 4.89).
- `hall_clock` [0.12, −1.86]: the whole case stands on the floor (the rect is only its face).

## 7. Reach distances (SetCheck: nearer shoulder → placed target, limit 0.50 m; no collisions on any Night)

| Night | Hotspot | Band | Step | Target (m) | Distance |
|---|---|---|---|---|---|
| P00 / g0 | kitchen_honey | high | stool (0.55) | 14.55, 2.023, −1.72 | 0.446 |
| P00 | parlour_gramophone | mid | — | 8.00, 1.00, −1.72 | 0.384 |
| N1 | kitchen_kettle | mid | — | 14.40, 0.96, −1.71 | 0.341 |
| N1 | kitchen_pickle_jar | high | — (tiptoe) | 15.80, 1.665, −1.675 | 0.480 |
| N1 | kitchen_sink_tap | mid | — | 19.12, 0.90, −1.895 | 0.331 |
| N1 | parlour_recliner | low | — (kneel) | 10.55, 0.28, −1.65 | 0.460 |
| N2 | hall_clock | high | mime 0.45 | 6.52, 2.05, −1.84 | 0.460 |
| N2 | hall_mirror | high | mime 0.35 | 5.82, 1.80, −1.908 | 0.412 |
| N2 | hall_phone | mid | — | 5.015, 1.15, −1.99 | 0.475 |
| N2 | kitchen_fridge_shelf | mid | — | 16.60, 0.95, −1.88 | 0.276 |
| N2 | parlour_newspaper | mid | — | 10.756, 0.75, −1.73 | 0.417 |

## 8. Verification

- **Set tests:** `tools/scripts/test_game.sh r3d-sets -- set3d/` → 37/37 pass. They cover:
  - the data contract and anchors
  - bands, reach and steps
  - hit boxes ⊇ visuals, including the default box
  - landings, handoffs and quake heights
  - the §3.4 tables and dressing per Night
  - local live mask == sim live mask
  - build, collisions and stack gaps
  - lend / return and the Prop3D API
  - hide eyes, decor and room light
  - one material per room
  - static draws ≤ 3, tris ≤ 25k, and merge keeping the piece API and the door leaf
- **Full suite:** `tools/scripts/test_game.sh r3d-sets` (no filter) → 1476 pass, 2 fail, 2 skip. Both failures are in `anim3d/test_bellows_clips3d.gd` (`test_the_sneeze`, `test_the_sip_is_continuous_into_the_sneeze`), which is r3d-anim-bellows' area, not mine.
- **Lint:** `SANDBOX=r3d-sets tools/scripts/lint.sh` exits 1.
  - Content, hotspot and ip lints: OK.
  - The only errors are `lint_anim 3d` on `hush3d/rig_allegro_go_go.json` (L10 pop jump f10, L14 sound sync f13), which is r3d-anim's clip.
- **Set lint:** `lint3d.sh --set` does not exist yet, because r3d-tools-b has not landed it, so there is no set-lint result. I checked the same rules with `measure.sh` / lab.py and `sil64.py` instead (§5, §6).
- **Setcheck:** `SetPreview3D --check` on all four slice Nights gives 0 collisions, 0 errors and 0 warnings.
- **Solver baseline:** not needed. I changed nothing the sim reads (house3d.json is view-only), and `SetList` only mirrors the sim.

## 9. Requests

1. **r3d-anim:** re-bake these clips from house3d.json:
   - `hush/rig_achoo_ria`: the jar moved (mouth at 14.55, 2.023, −1.72; stand 14.85 / −1.42 on the stool).
   - `rig_allegro_go_go`: Hush's lever stand is now z −1.30.
   - `rig_kettle_drum`: the stand is now z −1.30.
   - `rig_allegro_go_go` also currently fails lint_anim (L10, L14).
2. **r3d-tools-a (lab.py `SET_RULES`):**
   - Apply the "wainscot 8–10 L* darker" rule to lit walls only (§3.7 row "Walls (lit room)").
   - Do not judge backstage rooms (stage light 0.3) as "dimmed walls 45–58".
3. **r3d-tools-b (set lint, when it lands):**
   - Take the ID pass from `SetPreview3D --pass=id --legend=` (it never merges pieces).
   - Take the projected hit rects from `--rects-json=`.
4. **r3d-content:**
   - `SetList.local_live` mirrors your in-flight rule that doors and stairs are live only when they lead to a room she may enter tonight (the back door is architecture in Act I). Keep it, or tell me if you revert it.
   - rig_actions bands are unchanged. The fridge shelf target is now y 0.95 (still mid).
5. **r3d-anim-bellows:** the tea clip. Bellows sits at x 15.0 on the 0.55 m stool, facing −x, with the kettle and jar at his left hand (`tea_staging.png` shows the space).
6. **Import (R13):** the palettes want lossless, no mipmaps, nearest filter. The new glbs and pngs rely on the sandbox import (never `NO_IMPORT=1`).
7. **r3d-view3d:** your `CameraDirector3D.links_from` fix is noted; `SetPreview3D` works with either the house.json dict or the db.

## 10. Deviations and known gaps

- Bellows' tea pose in the review renders is a UAL stand-in, not his clip.
- `reach_check.png` shows the pre-rebake `rig_achoo_ria`: the glove is at the old target, but the reach lines are green.
- The static merge covers pieces with no animations that are not quake props tonight. A merged piece ignores `set_decor_visible`; none of them needs it.
- Only the N1 and N2 front door (a side-facing leaf in the full-depth flat) reads edge-on from the porch side, as in REDESIGN's mock. From the hall it reads as a green door.
- The house is more muted than the look-dev diorama, because §3.7 caps lit walls at L* 76 and C* 28 (the diorama's walls are brighter). The floors were warmed to recover some of the toy-box feel.
- No fresh-reviewer packet was built. Nothing in this brief requires one.

## 11. Hours

About 7.5 h in total. P0 took about 3 h and landed within its ≤ 3 h box.

## Fix pass addendum (2026-09-30, 20:15–21:06Z; lint rows of `docs/review/r3d-tools-b/status.md` 20:10Z)

I fixed 6 of my 7 error rows and both warning rows. The seventh row, the N02 hall negative space, cannot be fixed in the set alone; it needs a lead ruling (reasons below). The fix pass took about 0.9 h.

### Lint result, before → after

Re-run with `SANDBOX=r3d-sets-fix tools/scripts/lint3d.sh --set --screen --all-nights --aspects=20x9,16x9,4x3`, with renders.

- **Negative space, P00, g0 and N01 parlour:** 1.02 → **1.57 m** (x 9.88–11.45).
- **Negative space, N02 parlour:** 1.62 m (it already passed).
- **Negative space, N01 and N02 porch:** 1.40 → **1.60 m** (x 0.90–2.50). Both warnings are cleared.
- **Negative space, N01 hall:** 1.499 m, unchanged, and it passes.
- **Negative space, N02 hall:** still **0.68 m**. This is the one error left.
- **Stack / gap, N02 kitchen fridge | fridge_shelf:** 5.6 → **36.8 px** at the worst framing. This clears the set stack row and the three screen gap rows (20:9, 16:9 and 4:3).
- **Set mode overall:** 1 error, the N02 hall. All colour rules pass.
- **Screen mode overall:** 0 errors. There is 1 warning, `window_overlap` on the N02 hall clock at 16:9; it is r3d-view3d's.
- I made no change to the `hall_front_door` rows. r3d-view3d posted no REQUESTS line asking me to, and those rows no longer appear.

### What changed (all within my own files)

**`game/data/house/house3d.json`**
- **Parlour fireplace:** narrowed and moved right.
  - The fireplace is x 11.50–12.56 and the firebox 11.73–12.33.
  - The mantel is 11.45–12.61. Its top stays at 1.46 m, so the quake-prop "on the mantel" rule still holds.
  - The fire and the portrait now sit over it, at x 12.03 and 12.15.
  - The vase is at 11.68, 0.23 m in from the mantel's left edge, so its five 5 cm warm-up nudges still leave it teetering on the edge. Its smashed pieces moved to 11.48.
  - The window is 0.8 m wide, at x 13.21.
  - The recliner (N1) and the log basket sit in the opened stretch, both below head height.
- **Porch:** No. 9's door is now 0.7 m wide, at x 0.2–0.9.
- **Fridge zones:** the zone boxes are now lower [0, 0.71] and upper [0.90, 1.52]. The hit boxes are [16.0, 0, 16.8, 0.71] and [16.0, 0.90, 16.8, 1.62], each with `hit_z_half` 0.12. The shelf reach target stays at y 0.95.
- **Band stands:** every N1/N2 rig point that uses a band clip now has `reach_pos` = placed target − the clip's `reach_offset`, with z ≥ −1.6, adjusted until nothing collides. This is r3d-anim-hush-b's request: Hush now stands beside the prop instead of in front of it (`band_stands.jpg`).
- **Honey bounds:** the x minimum is −0.215, because the pepper pot moved (next item).

**Rebuilt glbs** (`tools/art3d/set/build.py`, `game/art3d/set/`, `game/art3d/props/`; palettes unchanged, byte for byte)
- `fridge.glb`: a 0.19 m chrome divider band (0.71–0.90 m) between the two doors. The doors, handles and the armed sausage moved to match.
- `honey_jar.glb`: the pepper pot's centre is now at `PEPPER_X` = −0.16 local, 0.24 m from the jar's axis (it was 0.30 m). This is r3d-anim's request, so the stool-top snatch needs no lean-out. The tea staging is unchanged: the jar and pot stay clear of Bellows' bouffant.
- Also rebuilt: `parlour_arch.glb`, `porch_arch.glb`, `parlour_window.glb`. `build_report.json` is updated.

**`game/view3d/set/set_mats.gd`**
- `ink_mat` now uses `View3DConst.OUTLINE_PROP_PX` (3.4 px, lead ruling D7) instead of 2.5. This was r3d-view3d's request.

**`game/view3d/set/prop_3d.gd`**
- The beret tag is now built, hidden, when a live rig prop is set up, so `show_tag` never creates a node or material during play. This was r3d-night's request.

### New numbers

- **Reach (SetCheck, nearer shoulder, limit 0.50 m):**

  | Night | Rig point | Distance (m) |
  |---|---|---|
  | P00 / g0 | honey | 0.446 |
  | P00 | gramophone | 0.384 |
  | N1 | kettle | 0.255 |
  | N1 | pickle jar | 0.490 |
  | N1 | sink tap | 0.388 |
  | N1 | recliner | 0.482 |
  | N2 | clock | 0.485 |
  | N2 | mirror | 0.397 |
  | N2 | phone | 0.380 |
  | N2 | fridge shelf | 0.354 |
  | N2 | newspaper | 0.483 |

  All four Nights have 0 errors, 0 warnings and 0 collisions.
- **Fridge hit boxes:** 194×171 (shelf) and 193×172 (door) logical px, 36.8 px apart at the worst framing.
- **Colours:** the parlour measures as before: wall L* 66.1 / C* 14.8, wainscot ΔL* 9.5. The dressing measures C* ≤ 11.7 and |ΔL*| ≤ 12.0.

### Why the N02 hall cannot reach 1.5 m in the set alone

The lint counts everything between y 1.1 and 1.8 m whose x span overlaps the lane. The N02 hall packs, into 5 m:

- **Five live props (the §3.3 maximum)**, at house.json use_x spaced 0.84 m apart (frozen, C3): the cupboard at 3.04 m, the crate at 3.88, the phone at 4.72, the mirror at 5.56 and the clock at 6.40.
- **The coat stand**, which must stay at x ≈ 4.31. It is where MIRROR, MIRROR lands him: pranks.json `end x 862, landing coat_stand`.

Of these, four are taller than 1.1 m: the cupboard, the phone, the mirror and the clock. Together with the coat stand, the largest gap they can leave is:

- **Cupboard to coat stand:** at most 0.87 m (3.44–4.31), even with the window moved.
- **Between the stand, phone, mirror and clock:** at most 0.29 m.
- **Clock to the room end:** 0.68 m (6.82–7.50).

The only lever would be taking a tall prop out of the head band:
- A wall-hung clock would free 6.00–7.50. But TIME'S UP is a tall-case gag: "he clings on as the clock pogoes across the hall; the pendulum door smacks his bum".
- Shifting props by view offsets would need 0.8 m or more, which desyncs them from where the sim puts them.
- The window cannot move above any live prop, because that breaks the preview-band rule.

I left the hall unchanged.

**Options for the lead / r3d-integrate:**
- (a) A ruling that exempts a room at the §3.3 five-live-prop maximum (the N2 hall), or turns its row into a warning.
- (b) A content change in R3: re-space the hall hotspots in house.json, or move the MIRROR, MIRROR landing.
- (c) Strike one hall prank from N2.

### Handed on

- **r3d-anim:** re-bake `hush/rig_achoo_ria` with `POT_PIVOT = (-0.16, 0, 0)`. The jar mouth and Hush's stand are unchanged.
- **r3d-anim-hush-b:** I applied its stand values except two.
  - The kettle's visual did not move: it is the P00 tea hand-off home and is stacked under the honey. Hush stands at x 14.28 z −1.44 instead, the closest spot that does not collide right of the wing flat; her gloves land 0.14 m past the kettle.
  - The recliner uses dx +0.15, not −0.15, so her gloves stay on the spring key within 0.50 m.
- **r3d-integrate:** the N02 hall ruling (above). D7 is done in my files; Bellows' `rig3d.json` and `rig_def_3d.gd` outline defaults are still yours, per r3d-view3d.
- **Import (R13):** no new files. The rebuilt glbs keep their existing `.import` sidecars.

### Verification

- `test_game.sh r3d-sets-fix -- set3d/`: 37/37 passed.
- Full suite: 1496 passed, 0 failed, 0 skipped.
- `SANDBOX=r3d-sets-fix tools/scripts/lint.sh`: rc 0.
- `SetPreview3D --check`, P00 / g0 / N01 / N02: all rc 0.
- I looked at the renders, the review boards and `fix_pass.jpg`, and the rooms read calm:
  - The parlour now has plain wall behind the heads between the piano and the fireplace.
  - The fridge reads as one retro fridge with two doors.
  - Hush's gloves are on each band prop.

  The one weak spot is the mirror: Hush still covers the left of its glass while rigging (its reachable edge is its front-right edge).
- `docs/review/r3d-sets/` is 6.6 MB: `fix_pass.jpg`, `band_stands.jpg`, and every kitchen, parlour and porch room at three aspects plus the Night boards re-rendered, with `tea_staging`, `reach_check`, `landings` and the rects refreshed.
