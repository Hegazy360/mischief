# r3d-integrate — the 2D-path reachability scan (r3d-index §5.4, brief §3.5)

**Method.** `reach.py` (scratch `<SP>/work/r3d-integrate/scan/`) builds a reference graph over `game/`, `tools/` and
`.github/`: `class_name`s used in `.gd`/`.tscn`/`.tres` code (comments stripped), `res://` strings (`preload`/`load`/
`ext_resource`/data JSON), repo paths in `.sh`/`.py`/`.yml`/`.cfg` files (shell calls), Python imports, and
`lint_all.sh`'s `tools/art/*/validate*.py` / `lint_*.py` glob. Roots = every live file outside the candidate trees
(Boot, NightScene, the stage door, the HUD, the 3D view, the lints, `lint_all.sh`, CI, the export presets, the data).
A candidate is **keep** when a root reaches it (the referring file is named) — or, for the files reached through a
path the code BUILDS (sidecars, default maps, Figgis moods, plugin scripts) or a tool run by hand, with that reason
written out. Everything else is **delete**; the tests that referenced only deleted classes were deleted with them, and
every remaining reference was fixed (no live file names a deleted class or path: rescan after the deletion = 0).

**Totals:** 1006 candidate files at the R3D head — keep 545 (scan-reached 425, built path / by hand 120), delete 461 (+ their
`.import`/`.uid` sidecars: 934 files removed in all, + 2 emptied `_src/.gdignore` folders). Unreached-but-kept: 0.

**Where the scan differs from the index's expected outcome** (the scan decides):
- *Kept:* `game/art/house/{props,items}/**` (house.json hotspot art → `ContentDB.hs_icon` → the sim snapshot's preview / bubble icons; items.json
  icons), `game/art/house/{stage,cold}/**` (curtain, title card, cold opens), `game/view/world/house_layout.gd`
  (NightScene / WorldView3D layout), `game/view/view_kit.gd`, `game/view/sandbox/fake_world.gd` (ViewSandbox3D),
  `game/data/rigs/{hush,bellows}/faces.json` (the 3D cast builders + lint3d_rules preset parity), `game/data/rigs/figgis/**`
  (R3's sprite, validated), `game/art/chars/hush/clarence_{squeezed,stretched}.svg` (the HUD's Clarence button).
- *Deleted although the index listed them as likely keeps:* `game/view/world/{cue_stager,caught_stager,moment_recorder}.gd`,
  `game/view/camera/gag_stager.gd`, `game/view/fx/busted_cam.gd` — no live file references them (CueStager3D,
  CaughtStager3D, GagStager3D, the 3D recorder / GagReel3D replaced them).
- *Follow-ups:* `game/data/house/house.json` (frozen, C3) still names the 2D room backdrops in `rooms[].art`; nothing in
  the 3D build loads them (`RoomDef.art` was read only by the deleted RoomView) and `lint_rects.py` no longer checks
  them. `HiResTex.trim_globs` defaults to empty (it named the deleted room layers).

**Files changed because they referenced deleted files** (all in the report's deletion list): NightScene, NightInput,
NightWarmer, NightWarm, CurtainApron, CurtainCall, GagReel, Gate0Card, NightArgs, BootConfig, Cast, StageDoor,
CueFallback (docs), ThoughtBubble, PipView3D (`fallback_rule`), ScriptProf3D, ClipMap, AudioDirector, e2e flows/probe,
`run_lints.gd`, `beat_lint.gd`, `lint_anim.gd`, `lint.sh`, `capture.sh`, `tools/art/hush/{build,validate}.py`,
`tools/art/house/{build_all,lint_rects}.py`, `hi_res_tex.gd`, `game/art/STYLE.md`, tests (content, solver lints, view
compiles / fixtures / clip map / audio director, night input / night3d / warm). `tools/ci/lint_all.sh` needed no edit:
its glob now finds only the kept validators (house SVG + rects, Figgis + Stalls). The export presets needed no edit:
the include filter (`*.svg, *.json`) simply finds fewer files and every exclude entry still names a live folder.

**2D-only tests deleted (76):** `game/tests/anim/test_bellows_clips.gd`, `game/tests/anim/test_hush_clips.gd`, `game/tests/art/test_bellows_rig.gd`, `game/tests/art/test_house.gd`, `game/tests/art/test_hush_rigs.gd`, `game/tests/rig/fixtures/bad_accent.json`, `game/tests/rig/fixtures/bad_antic.json`, `game/tests/rig/fixtures/bad_beats_match.json`, `game/tests/rig/fixtures/bad_dead.json`, `game/tests/rig/fixtures/bad_floor.json`, `game/tests/rig/fixtures/bad_frames.json`, `game/tests/rig/fixtures/bad_ids.json`, `game/tests/rig/fixtures/bad_jump.json`, `game/tests/rig/fixtures/bad_limits.json`, `game/tests/rig/fixtures/bad_rx_laugh.json`, `game/tests/rig/fixtures/bad_rx_long.json`, `game/tests/rig/fixtures/bad_rx_nobeats.json`, `game/tests/rig/fixtures/bad_rx_short_hold.json`, `game/tests/rig/fixtures/bad_seam.json`, `game/tests/rig/fixtures/bad_sil.json`, `game/tests/rig/fixtures/bad_slide.json`, `game/tests/rig/fixtures/bad_sync.json`, `game/tests/rig/fixtures/bad_twin.json`, `game/tests/rig/fixtures/real/bellows_mg_preen.json`, `game/tests/rig/fixtures/real/bellows_strut.json`, `game/tests/rig/fixtures/real/bellows_take.json`, `game/tests/rig/fixtures/real/hush_mg_shrug.json`, `game/tests/rig/fixtures/real/hush_run.json`, `game/tests/rig/fixtures/real/hush_take.json`, `game/tests/rig/fixtures/rigs/r01_files/rig.json`, `game/tests/rig/fixtures/rigs/r02_pivots/rig.json`, `game/tests/rig/fixtures/rigs/r03_hierarchy/rig.json`, `game/tests/rig/fixtures/rigs/r04_mirror/rig.json`, `game/tests/rig/fixtures/rigs/r05_face/faces.json`, `game/tests/rig/fixtures/rigs/r05_face/rig.json`, `game/tests/rig/fixtures/rigs/r06_silhouette/rig.json`, `game/tests/rig/fixtures/rigs/r07_refs/rig.json`, `game/tests/rig/fixtures/rigs/r08_poses/poses.json`, `game/tests/rig/fixtures/rigs/r08_poses/rig.json`, `game/tests/rig/fixtures/s2/bad_a23_overlay.json`, `game/tests/rig/fixtures/s2/bad_a24_bit.json`, `game/tests/rig/fixtures/s2/bad_a25_mg.json`, `game/tests/rig/fixtures/s2/bad_a26_cold.json`, `game/tests/rig/fixtures/s2/bad_a28_decor.json`, `game/tests/rig/fixtures/s2/bad_a29_bump.json`, `game/tests/rig/fixtures/s2/good_a29_look.json`, `game/tests/rig/fixtures/s2/manifest_a29.json`, `game/tests/rig/fixtures/s2/map_a27.json`, `game/tests/rig/test_art_requests.gd`, `game/tests/rig/test_atlas.gd`, `game/tests/rig/test_auto_combos.gd`, `game/tests/rig/test_char_rigs.gd`, `game/tests/rig/test_clip_events.gd`, `game/tests/rig/test_eases.gd`, `game/tests/rig/test_lint.gd`, `game/tests/rig/test_lint_s2.gd`, `game/tests/rig/test_overlay.gd`, `game/tests/rig/test_perf.gd`, `game/tests/rig/test_player.gd`, `game/tests/rig/test_reset_objects.gd`, `game/tests/rig/test_rig_data.gd`, `game/tests/rig/test_run_fill.gd`, `game/tests/rig/test_s2_tools.gd`, `game/tests/rig/test_sampler.gd`, `game/tests/rig/test_secondary.gd`, `game/tests/rig/test_tex_s2.gd`, `game/tests/rig/test_tier.gd`, `game/tests/view/test_camera.gd`, `game/tests/view/test_character_view.gd`, `game/tests/view/test_fx_pools.gd`, `game/tests/view/test_gag_stager.gd`, `game/tests/view/test_pip.gd`, `game/tests/view/test_real_routes.gd`, `game/tests/view/test_room_art_scales.gd`, `game/tests/view/test_view_bits.gd`, `game/tests/view/test_world_staging.gd`

## The table (every file)

| file | verdict | reason |
|---|---|---|
| `game/addons/mnd_export/plugin.cfg` | keep | reached by `game/project.godot` |
| `game/addons/mnd_export/plugin.gd` | keep | plugin.cfg `script="plugin.gd"` (enabled in project.godot; ships the raw SVGs HiResTex rasterises) |
| `game/art/chars/_mannequin/_src/.gdignore` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/_src/build.py` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/badge.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/brows_angry.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/brows_neutral.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/brows_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/brows_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/eyes_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/eyes_half.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/eyes_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/eyes_squint.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/eyes_wide.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/foot_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/foot_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hand_l_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hand_l_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hand_r_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hand_r_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hat_singed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hat_wet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/hips.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_O.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_frown.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_grit.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_pressed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mouth_smile.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mug_empty.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/mug_full.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/pupils.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/_mannequin/torso_drips.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/_src/.gdignore` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/_src/README.md` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/blush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_angry.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_neutral.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_one_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_sly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/brows_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_angry.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_balloon.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_half.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_pinpoint.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_spiral.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_squint.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_teary.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/eyes_wide.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/hiccup.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/lids_angry.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/lids_half.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_O_big.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_O_mid.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_O_small.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_grit.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_scream.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_smile.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_smug.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/mouth_wavy.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/pinch.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/pupils.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/singe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/steam_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/steam_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/sweat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/face/vein.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_feathered.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_flipped.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_floured.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_frazzled.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_neat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_poodle.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/bouffant_wet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/coat_tails.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/cravat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/foot_l_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/foot_l_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/foot_r_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/foot_r_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_conduct.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_grip.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_l_wag.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_conduct.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_grip.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/hand_r_wag.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/nose.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_l_bristle.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_l_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_l_puffed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_l_wet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_r_bristle.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_r_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_r_puffed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/sideburn_r_wet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/parts/torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/baton.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/comb.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/jelly_helmet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/kettle_lid.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/kipper_held.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/megaphone.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/newspaper_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/newspaper_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/phone_handset.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/pickled_onion.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/sausage_boa.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/specs_buttered.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/specs_dangling.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/specs_magnifier.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/specs_on.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/stool_flying.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/stool_under.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/teacup_held.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/props/teacup_sip.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_arm_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_arm_upper_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_arm_upper_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_comb.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_leg_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/chicken_wattle.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_bouffant.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_hand_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_hand_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/dough_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_arm_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_arm_upper_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_arm_upper_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_leg_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_nose.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/feathered_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_arm_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_arm_upper_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_hand_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_hand_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/floury_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/hedge_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/hedge_bouffant.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/hedge_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/hedge_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_leg_lower_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_leg_lower_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_leg_upper_l.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_leg_upper_r.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_seat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/lj_tails_rip.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/maestro_frizz.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/soaked_belly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/soaked_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/soaked_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/sticky_bouffant.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/sticky_head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/sticky_spoon.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/sticky_torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/trophy_helmet.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/tutu_chandelier.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/tutu_tulle.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/bellows/residue/umbrella_stand.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/figgis/_src/.gdignore` | keep | the R7 busts' generator (`gen_figgis.py`) and its `.gdignore` |
| `game/art/chars/figgis/_src/gen_figgis.py` | keep | the R7 busts' generator (`gen_figgis.py`) and its `.gdignore` |
| `game/art/chars/figgis/body.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/box.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/card_up.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/ear_l.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/ear_r.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/eyes_happy.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/eyes_open.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/eyes_wide.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/figgis_chip.svg` | keep | FiggisChip `ART_DIR + "figgis_<mood>.svg"` (R7 vinyl busts) |
| `game/art/chars/figgis/figgis_point.svg` | keep | FiggisChip `ART_DIR + "figgis_<mood>.svg"` (R7 vinyl busts) |
| `game/art/chars/figgis/figgis_proud.svg` | keep | FiggisChip `ART_DIR + "figgis_<mood>.svg"` (R7 vinyl busts) |
| `game/art/chars/figgis/figgis_psst.svg` | keep | FiggisChip `ART_DIR + "figgis_<mood>.svg"` (R7 vinyl busts) |
| `game/art/chars/figgis/figgis_shh.svg` | keep | FiggisChip `ART_DIR + "figgis_<mood>.svg"` (R7 vinyl busts) |
| `game/art/chars/figgis/hand_l_cup.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_l_hold.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_l_point.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_l_shh.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_r_cup.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_r_hold.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_r_point.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hand_r_shh.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/head.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/hood.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/mouth_psst.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/mouth_shh.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/mouth_smile.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/figgis/specs.svg` | keep | reached by `game/data/rigs/figgis/rig.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/hush/beret.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/braces_front.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/braces_loop.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/brows_determined.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/brows_neutral.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/brows_sly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/brows_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/brows_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/clarence_limp.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/clarence_smitten.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/clarence_squeezed.svg` | keep | reached by `game/ui/widgets/clarence_button.gd` |
| `game/art/chars/hush/clarence_stretched.svg` | keep | reached by `game/ui/widgets/clarence_button.gd` |
| `game/art/chars/hush/eyes_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_half.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_happy.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_squint.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_wide.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_wink.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/eyes_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/foot_l_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/foot_l_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/foot_r_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/foot_r_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/fx_blush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/fx_sweat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/fx_tear.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hair_back.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_pinch.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_shush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_thumbs_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_wall.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_l_wave.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_pinch.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_shush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_thumbs_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_wall.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hand_r_wave.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/head_tomato.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hidden_eyes.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hidden_eyes_blink.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hidden_eyes_whites.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/hidden_pupils.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_O.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_grimace.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_grin.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_laugh.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_puffed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_shh.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_smile.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_tongue.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/mouth_wavy.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pelvis.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/beret.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/braces_front.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/braces_loop.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/brows_determined.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/brows_neutral.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/brows_sly.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/brows_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/brows_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_closed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_half.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_squint.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_wide.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_wink.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/eyes_worried.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/foot_l_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/foot_l_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/foot_r_flat.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/foot_r_tiptoe.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hair_back.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_pinch.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_shush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_thumbs_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_wall.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_l_wave.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_fist.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_open.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_pinch.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_point.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_shush.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_thumbs_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_wall.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hand_r_wave.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/head.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hidden_eyes.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hidden_eyes_blink.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/hidden_eyes_whites.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/mouth_puffed.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/mouth_shh.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/mouth_smile.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/pelvis.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pip/torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_down.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_down_left.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_left.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_right.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_up.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/pupils_up_right.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/hush/torso.svg` | delete | no live 3D file reaches it (scan) — the 2D character part SVGs (the 3D cast is game/art3d/chars/**) |
| `game/art/chars/stalls/afro_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/afro_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/afro_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/afro_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bald_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bald_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bald_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bald_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beanie_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beanie_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beanie_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beanie_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beehive_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beehive_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beehive_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/beehive_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_bow_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_bow_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_bow_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_bow_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_ears_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_ears_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_ears_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/big_ears_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bob_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bob_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bob_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bob_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bowler_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bowler_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bowler_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bowler_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bunny_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bunny_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bunny_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/bunny_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/cowlick_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/cowlick_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/cowlick_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/cowlick_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/curlers_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/curlers_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/curlers_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/curlers_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/feather_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/feather_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/feather_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/feather_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flat_cap_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flat_cap_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flat_cap_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flat_cap_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flower_hat_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flower_hat_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flower_hat_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/flower_hat_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/mohawk_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/mohawk_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/mohawk_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/mohawk_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/pigtails_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/pigtails_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/pigtails_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/pigtails_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/ponytail_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/ponytail_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/ponytail_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/ponytail_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/side_cap_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/side_cap_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/side_cap_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/side_cap_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/spiky_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/spiky_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/spiky_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/spiky_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/sunhat_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/sunhat_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/sunhat_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/sunhat_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tiara_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tiara_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tiara_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tiara_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/toddler_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/toddler_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/toddler_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/toddler_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/top_hat_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/top_hat_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/top_hat_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/top_hat_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/topknot_laugh.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/topknot_lean.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/topknot_point.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/topknot_rest.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tumble_1.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tumble_2.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tumble_3.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/chars/stalls/tumble_4.svg` | keep | reached by `game/data/rigs/stalls/stalls.json` (root `tools/ci/lint_all.sh`) |
| `game/art/house/_src/.gdignore` | keep | the house art sources' notes / `.gdignore` |
| `game/art/house/_src/README.md` | keep | the house art sources' notes / `.gdignore` |
| `game/art/house/cold/n01_bg.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n01_birds.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n01_birds_flown.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n01_sill_fg.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n01_window_no9.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n01_window_no9_cracked.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n02_balloon.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n02_balloon_popped.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n02_bg.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n02_box.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/cold/n02_box_string.svg` | keep | reached by `game/data/house/cold_sets.json` |
| `game/art/house/items/apple.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/balloon.svg` | keep | reached by `game/tests/sim/fixtures/items.json` |
| `game/art/house/items/bubble_bath.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/butter.svg` | keep | reached by `game/tests/sim/fixtures/items.json` |
| `game/art/house/items/coins.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/croc.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/feathers.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/flour.svg` | keep | reached by `game/tests/sim/fixtures/items.json` |
| `game/art/house/items/kipper.svg` | keep | reached by `game/tests/sim/fixtures/items.json` |
| `game/art/house/items/magnifier.svg` | keep | reached by `game/tests/sim/fixtures/items.json` |
| `game/art/house/items/record.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/salt.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/sherbet.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/squeaker.svg` | keep | reached by `game/tests/solver/fixtures/mock_data/items.json` |
| `game/art/house/items/treacle.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/items/tutu.svg` | keep | reached by `game/data/items.json` |
| `game/art/house/props/airing_cupboard.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/airing_cupboard_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/airing_cupboard_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/back_door.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/back_door_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/back_door_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/basin_spray.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/basin_spray_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/basin_spray_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath_taps.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath_taps_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bath_taps_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bathroom_cabinet.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bathroom_cabinet_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bathroom_cabinet_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bed.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bed_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bed_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bedside.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bedside_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bedside_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bellows.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bellows_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bellows_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/bellows_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/boiler_valve.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/boiler_valve_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/boiler_valve_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chaise.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chaise_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chaise_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chandelier.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chandelier_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chandelier_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/chandelier_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cheval_mirror.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cheval_mirror_front.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cheval_mirror_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cheval_mirror_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cloak_dummy.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cloak_dummy_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/cloak_dummy_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_case.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_case_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_case_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_face.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_face_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_face_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/clock_face_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coat_cupboard.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coat_cupboard_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coat_cupboard_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coat_stand.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_1.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_1_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_1_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_2.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_2_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_2_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_3.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_3_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/coin_spot_3_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/compost_bin.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/compost_bin_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/compost_bin_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/confiscated_box.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/confiscated_box_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/confiscated_box_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_rail.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_rail_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_rail_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_trunk.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_trunk_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/costume_trunk_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fan.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fan_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fan_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fan_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/feed_bin.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/feed_bin_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/feed_bin_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge_shelf.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge_shelf_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/fridge_shelf_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/front_door.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/front_door_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/front_door_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/garden_hose.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/garden_hose_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/garden_hose_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/gramophone.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/gramophone_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/gramophone_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/gramophone_rigged_it_takes_two.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/hamper.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/hamper_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/hamper_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/hats.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/honey_jar.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/honey_jar_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/honey_jar_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kettle.svg` | keep | reached by `game/tests/night/test_hud_presenter.gd` |
| `game/art/house/props/kettle_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kettle_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_sink_lip.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_stool.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_table.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_table_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_table_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_window.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/kitchen_window_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/laundry_basket.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/laundry_basket_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/laundry_basket_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/log_basket.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/marrow.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/marrow_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/marrow_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/newspaper.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/newspaper_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/newspaper_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/newspaper_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pan_rail.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_curtain.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_curtain_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_curtain_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_shelf.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_shelf_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pantry_shelf_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_candles.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_candles_f1.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_candles_f2.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_fire.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_fire_f1.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/parlour_fire_f2.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/phone.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/phone_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/phone_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/phone_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano_wedge.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano_wedge_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piano_wedge_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pickle_jar.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pickle_jar_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pickle_jar_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pickle_jar_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/picture_frame.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/picture_frame_falling.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piggy_bank.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piggy_bank_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/piggy_bank_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pillow.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pillow_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/pillow_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/portrait.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/portrait_floured.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/potting_bench.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/potting_bench_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/potting_bench_open.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/recliner.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/recliner_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/recliner_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/rubber_duck.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/rubber_duck_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/rubber_duck_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/shed.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/shed_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/shed_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/sink_tap.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/sink_tap_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/sink_tap_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/spotlight.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/spotlight_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/spotlight_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_foot.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_foot_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_head.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_head_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_rods.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_rods_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/stair_rods_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/tea_tray.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/tea_tray_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/tea_tray_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/tea_tray_spent.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/trophy_shelf.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/trophy_shelf_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/trophy_shelf_rigged.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/under_bed.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/under_bed_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/under_bed_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/vase.svg` | keep | reached by `game/view/tex/hi_res_tex.gd` (root `tools/scripts/lint.sh`) |
| `game/art/house/props/vase_smashed.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/wardrobe.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/wardrobe_occupied.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/props/wardrobe_ol.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/rooms/bathroom_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/bathroom_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/bedroom_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/bedroom_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/conservatory_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/conservatory_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/dressing_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/dressing_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/garden_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/garden_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/hall_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/hall_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/kitchen_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/kitchen_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/landing_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/landing_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/parlour_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/parlour_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/porch_bg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/rooms/porch_fg.svg` | delete | no live 3D file reaches it (scan) — the 2D room backdrops (the 3D rooms are built from house3d.json) |
| `game/art/house/stage/apron.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/bow_spot.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/curtain.svg` | keep | reached by `game/scenes/night/night_curtain.gd` |
| `game/art/house/stage/curtain_valance.svg` | keep | reached by `game/scenes/night/curtain_call.gd` |
| `game/art/house/stage/flies.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/footlight_glow.svg` | keep | reached by `game/view/view_kit.gd` (root `tools/scripts/lint.sh`) |
| `game/art/house/stage/front_door_glow.svg` | keep | reached by `game/view/view_kit.gd` (root `tools/scripts/lint.sh`) |
| `game/art/house/stage/proscenium_l.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/proscenium_r.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/roof_main_l.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/roof_main_r.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/sky_left.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/sky_right.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/title_card.svg` | keep | reached by `game/scenes/night/curtain_call.gd` |
| `game/art/house/stage/title_card_bulbs_a.svg` | keep | reached by `game/scenes/night/curtain_apron.gd` |
| `game/art/house/stage/title_card_bulbs_b.svg` | keep | reached by `game/scenes/night/curtain_apron.gd` |
| `game/art/house/stage/velvet_rope.svg` | keep | reached by `game/data/house/house.json` |
| `game/art/house/stage/vignette_top.svg` | keep | reached by `game/data/house/house.json` |
| `game/data/anim/_mannequin/beat_slow_burn.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/beat_suppressed.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/loco_idle.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/loco_walk.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/reactions.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/rx_land.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/rx_launch.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/_mannequin/rx_take.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/act_tea.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/act_warmup.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/cue_doorframe_bonk.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/loco_blind_shuffle.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/loco_idle.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/loco_strut.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/loco_turn.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/map.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_admire_in_kettle.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_admire_reflection_horn.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_conduct_air.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_hum.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_pinkie_up.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/mg_trill.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/rx_sneeze_blast_a.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows/st_bonk.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/bellows3d/act_fixup_mirror.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/act_hunt.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/act_tea.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/act_warmup.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/beat_bow_topple.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/beat_dignity_fail.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/beat_slow_burn.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/beat_tear.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/bit_livid.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/bit_tea.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/bit_warmup.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/cc_wander_on.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/cue_doorframe_bonk.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/cue_picture_bonk.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_blind_shuffle.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_idle.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_irked.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_stomp.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_strut.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/loco_turn.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/map.json` | keep | reached by `game/tests/anim3d/test_bellows_clips3d.gd` |
| `game/data/anim/bellows3d/mg_admire_in_kettle.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_admire_reflection_horn.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_comb_flourish.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_conduct_air.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_cravat_tug.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_hum.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_peer_under_piano.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_pinkie_up.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_trill.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_walk_hum.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/mg_walk_scale.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/rx_dizzy_spin_a.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/rx_sneeze_blast_a.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_bonk.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_double_take.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_head_turn.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_look.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_look_back.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_smirk.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_specs_on.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_straighten_cravat.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/bellows3d/st_suspicious.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/clip_rules.json` | keep | reached by `game/view/world/clip_rules.gd` (root `tools/scripts/lint.sh`) |
| `game/data/anim/hush/act_climb_in.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_dive.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_pop.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_snicker.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_squeak.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_tinker_b.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_tinker_q.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/act_tinker_s.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/freeze_1.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/freeze_2.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/freeze_3.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/freeze_4.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/idle_fidget_clarence.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/idle_fidget_look.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/idle_fidget_proud.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/loco_idle.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/loco_run.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/loco_turn.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/loco_walk.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush/map.json` | delete | no live 3D file reaches it (scan) — the 2D clips + maps (the 3D clips are game/data/anim/*3d/**) |
| `game/data/anim/hush3d/act_bow.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_climb_in.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_dive.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_glance.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_pop.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_rummage.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_snicker.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_squeak.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/act_wheeze.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_1.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_2.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_3.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_4.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_5.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_6.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_7.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_8.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/freeze_midjob.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/idle_fidget_clarence.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/idle_fidget_look.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/idle_fidget_proud.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_arrive.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_idle.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_run.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_skid.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_turn.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/loco_walk.json` | keep | reached by `game/view/world/clip_map.gd` (root `tools/scripts/lint.sh`) |
| `game/data/anim/hush3d/map.json` | keep | reached by `game/tests/anim3d/test_hush_clips3d.gd` |
| `game/data/anim/hush3d/rig_achoo_ria.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/rig_actions.json` | keep | reached by `game/tools/anim/lint3d_rules.gd` (root `tools/scripts/lint.sh`) |
| `game/data/anim/hush3d/rig_allegro_go_go.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/rig_high.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/rig_low.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/rig_mid.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/rig_step_down.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/st_shrug.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/anim/hush3d/st_yanked.json` | keep | `ClipMap.sidecar_path` (`res://data/anim/<rig>3d/<clip>.json`) for every SliceClips.build3d clip |
| `game/data/rigs/_mannequin/faces.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/_mannequin/poses.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/_mannequin/rig.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/bellows/faces.json` | keep | reached by `tools/art3d/bellows/descriptor.py` |
| `game/data/rigs/bellows/poses.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/bellows/rig.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/figgis/faces.json` | keep | reached by `tools/art/hush/validate.py` (root `tools/ci/lint_all.sh`) |
| `game/data/rigs/figgis/poses.json` | keep | reached by `tools/art/hush/validate.py` (root `tools/ci/lint_all.sh`) |
| `game/data/rigs/figgis/rig.json` | keep | reached by `tools/art/hush/validate.py` (root `tools/ci/lint_all.sh`) |
| `game/data/rigs/hush/faces.json` | keep | reached by `tools/art3d/hush/write_rig.py` |
| `game/data/rigs/hush/poses.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/hush/rig.json` | delete | no live 3D file reaches it (scan) — the 2D rig / pose data (the 3D cast is game/data/rigs3d/**) |
| `game/data/rigs/stalls/stalls.json` | keep | reached by `tools/art/hush/validate.py` (root `tools/ci/lint_all.sh`) |
| `game/scenes/dev/AnimViewer.tscn` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/CaptureStub.tscn` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/RigPerf.tscn` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/anim3d/AnimViewer3D.tscn` | keep | reached by `tools/scripts/capture.sh` |
| `game/scenes/dev/anim3d/RigPerf3D.tscn` | keep | dev scene that stays: rig CPU budget (exit row 17, `shot.sh res://scenes/dev/anim3d/RigPerf3D.tscn`) |
| `game/scenes/dev/anim3d/anim_viewer_3d.gd` | keep | reached by `game/scenes/dev/anim3d/AnimViewer3D.tscn` (root `tools/scripts/capture.sh`) |
| `game/scenes/dev/anim3d/rig_perf_3d.gd` | keep | RigPerf3D.tscn's script |
| `game/scenes/dev/anim_viewer.gd` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/capture_stub.gd` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/house_preview/HousePreview.tscn` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/house_preview/house_preview.gd` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/review3d/LintShot3D.tscn` | keep | reached by `tools/scripts/lint3d.sh` |
| `game/scenes/dev/review3d/lint_shot_3d.gd` | keep | reached by `game/scenes/dev/review3d/LintShot3D.tscn` (root `tools/scripts/lint3d.sh`) |
| `game/scenes/dev/rig_perf.gd` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/room_backdrop.gd` | delete | no live 3D file reaches it (scan) — 2D dev scenes (AnimViewer3D / RigPerf3D / SetPreview3D replace them) |
| `game/scenes/dev/set3d/SetPreview3D.tscn` | keep | reached by `tools/art3d/set/measure.sh` |
| `game/scenes/dev/set3d/SetPreviewBatch3D.tscn` | keep | dev scene that stays: the r3d-sets review boards (`shot.sh …SetPreviewBatch3D.tscn`) |
| `game/scenes/dev/set3d/set_preview_3d.gd` | keep | reached by `game/scenes/dev/set3d/SetPreview3D.tscn` (root `tools/art3d/set/measure.sh`) |
| `game/scenes/dev/set3d/set_preview_batch_3d.gd` | keep | SetPreviewBatch3D.tscn's script |
| `game/tools/anim/Verbs3D.tscn` | keep | the 64 px verb silhouettes (R17 packets; `tools/art3d/anim/README.md`) |
| `game/tools/anim/anim_lint.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/atlas_report.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/capture.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/glb_to_res.gd` | keep | reached by `tools/art3d/anim/bake.sh` |
| `game/tools/anim/lint3d_limits.json` | keep | reached by `game/tools/anim/lint3d_rules.gd` (root `tools/scripts/lint.sh`) |
| `game/tools/anim/lint3d_rules.gd` | keep | reached by `game/tools/anim/lint_anim.gd` (root `tools/scripts/lint.sh`) |
| `game/tools/anim/lint_anim.gd` | keep | reached by `tools/scripts/lint.sh` |
| `game/tools/anim/lint_rig.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/rig_lint.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/rig_profile.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/sheet.gd` | delete | no live 3D file reaches it (scan) — the 2D rig lints / sheets / capture hook (lint_anim keeps `--format=3d`; capture3d.gd replaces capture.gd) |
| `game/tools/anim/verbs3d.gd` | keep | Verbs3D.tscn's script |
| `game/view/audio_director.gd` | keep | reached by `game/view3d/sandbox/view_sandbox_3d.gd` |
| `game/view/camera/camera_director.gd` | delete | no live 3D file reaches it (scan) — the 2D camera / gag stager: replaced by CameraDirector3D / GagStager3D |
| `game/view/camera/gag_stager.gd` | delete | no live 3D file reaches it (scan) — the 2D camera / gag stager: replaced by CameraDirector3D / GagStager3D |
| `game/view/camera/juice_clock.gd` | keep | reached by `game/view/sim_driver.gd` (root `game/view3d/sandbox/view_sandbox_3d.gd`) |
| `game/view/fx/badges.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/busted_cam.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/busted_overlay.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/cane.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/caption.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/entry_warning.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/falling_props.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/footprints.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/freeze_frame.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/fx_art.gd` | keep | reached by `game/view/fx/entry_warning.gd` (root `game/view3d/world/overlays_3d.gd`) |
| `game/view/fx/fx_layer.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/noise_rings.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/particle_pool.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/ripple.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/spot_meter.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/stamp.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/stare_strip.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/stars.gd` | delete | no live 3D file reaches it (scan) — 2D FX replaced by decals / previews / Overlays3D |
| `game/view/fx/thought_bubble.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/fx/wipe.gd` | keep | reached by `game/view3d/world/overlays_3d.gd` |
| `game/view/haptics_director.gd` | keep | reached by `game/view3d/probe/script_prof_3d.gd` |
| `game/view/pip/pip_view.gd` | delete | no live 3D file reaches it (scan) — the 2D PiP: replaced by PipView3D |
| `game/view/rig/clip_def.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/clip_events.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/clip_lib.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/face_state.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/line_limb.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/play_plan.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/pose_lib.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/prop_sim.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/reaction_table.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/rig_bounds.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/rig_def.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/rig_ease.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/rig_player.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/rig_sampler.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/rig/springs.gd` | delete | no live 3D file reaches it (scan) — the 2D rig runtime (RigPlayer, ClipLib, atlases): replaced by game/view3d/char/** (RigPlayer3D) |
| `game/view/sandbox/ViewSandbox.tscn` | delete | no live 3D file reaches it (scan) — the 2D ViewSandbox (ViewSandbox3D replaces it) |
| `game/view/sandbox/fake_world.gd` | keep | reached by `game/view3d/sandbox/view_sandbox_3d.gd` |
| `game/view/sandbox/view_sandbox.gd` | delete | no live 3D file reaches it (scan) — the 2D ViewSandbox (ViewSandbox3D replaces it) |
| `game/view/sim_driver.gd` | keep | reached by `game/view3d/sandbox/view_sandbox_3d.gd` |
| `game/view/stalls/stalls_view.gd` | keep | reached by `game/view3d/sandbox/view_sandbox_3d.gd` |
| `game/view/tex/atlas_builder.gd` | delete | no live 3D file reaches it (scan) — 2D rig atlases (no user since FiggisChip is on its SVG level, R7) |
| `game/view/tex/atlas_set.gd` | delete | no live 3D file reaches it (scan) — 2D rig atlases (no user since FiggisChip is on its SVG level, R7) |
| `game/view/tex/hi_res_tex.gd` | keep | reached by `game/view/view_kit.gd` (root `tools/scripts/lint.sh`) |
| `game/view/tex/tex_stats.gd` | keep | reached by `game/view/view_kit.gd` (root `tools/scripts/lint.sh`) |
| `game/view/view_kit.gd` | keep | reached by `game/view/world/slice_clips.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/caught_stager.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/character_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/clip_map.gd` | keep | reached by `game/view/world/slice_clips.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/clip_rules.gd` | keep | reached by `game/view/world/slice_clips.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/content_info.gd` | keep | reached by `game/view3d/world/world_view_3d.gd` |
| `game/view/world/cue_stager.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/decor_set.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/default_maps/_mannequin.json` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/default_maps/bellows.json` | keep | `ClipMap.DEFAULT_DIR + "/<rig>.json"` (the default maps under the 3D maps) |
| `game/view/world/default_maps/hush.json` | keep | `ClipMap.DEFAULT_DIR + "/<rig>.json"` (the default maps under the 3D maps) |
| `game/view/world/fallback_puppet.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/hidden_eyes.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/hotspot_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/house_art.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/house_layout.gd` | keep | reached by `game/view/world/slice_clips.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/moment_recorder.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/prop_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/room_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/slice_clips.gd` | keep | reached by `game/tools/anim/lint3d_rules.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/stage_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `game/view/world/view_snapshot.gd` | keep | reached by `game/view/world/slice_clips.gd` (root `tools/scripts/lint.sh`) |
| `game/view/world/world_view.gd` | delete | no live 3D file reaches it (scan) — the 2D world view (WorldView, CharacterView, rooms, props, stagers, recorder): replaced by game/view3d/world/** and view3d/set/** |
| `tools/anim/curves.py` | keep | `tools/scripts/anim_sheet3d.sh` (`$ROOT/tools/anim/curves.py`) |
| `tools/anim/gif.py` | keep | reached by `tools/scripts/capture.sh` |
| `tools/anim/mannequin_poses.py` | delete | no live 3D file reaches it (scan) — the 2D mannequin pose tool |
| `tools/anim/sheet3d.py` | keep | `tools/scripts/anim_sheet3d.sh` (`$ROOT/tools/anim/sheet3d.py`) |
| `tools/art/bellows/build.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/clips_spec.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/faces_spec.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/fk.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/palette.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/parts_body.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/parts_face.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/parts_head.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/parts_props.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/parts_residue.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/poses_s2.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/poses_spec.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/preview.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/rig_spec.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/svgk.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/bellows/validate.py` | delete | no live 3D file reaches it (scan) — the 2D Bellows rig art generator + validator |
| `tools/art/house/README.md` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/arch.py` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/build_all.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/canon.py` | keep | reached by `tools/art/house/lint_rects.py` (root `tools/ci/lint_all.sh`) |
| `tools/art/house/cold.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/compose.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/draw.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/geo.py` | keep | reached by `tools/art/house/lint_rects.py` (root `tools/ci/lint_all.sh`) |
| `tools/art/house/house_json.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/icons_activities.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/icons_items.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/lettering.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/lint_rects.py` | keep | reached by `tools/ci/lint_all.sh` |
| `tools/art/house/pal.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_base.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_edge.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_grey.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_hall.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_kitchen.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/props_parlour.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/review_s2.sh` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/review_shots.sh` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/rooms_final.py` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/rooms_grey.py` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/rooms_upper.py` | delete | no live 3D file reaches it (scan) — the 2D room generators / review shot scripts |
| `tools/art/house/sheets.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/stage.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/svgk.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/title.py` | keep | the house art generator (`python3 tools/art/house/build_all.py`, game/art/STYLE.md) of the props / items / stage / cold-open / icon SVGs and house.json that ship |
| `tools/art/house/validate_svg.py` | keep | reached by `tools/ci/lint_all.sh` |
| `tools/art/hush/build.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/cast_sheet.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/clip_preview.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/clipkit.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/clips_hush.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/figgis_art.py` | keep | the Figgis + Stalls generator (`python3 tools/art/hush/build.py`) and its validator |
| `tools/art/hush/fk.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/hush_art.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/pal.py` | keep | the Figgis + Stalls generator (`python3 tools/art/hush/build.py`) and its validator |
| `tools/art/hush/poses_hush.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/preview.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/rig_hush.py` | delete | no live 3D file reaches it (scan) — the 2D Hush / Pip rig art and clip generators |
| `tools/art/hush/stalls_art.py` | keep | the Figgis + Stalls generator (`python3 tools/art/hush/build.py`) and its validator |
| `tools/art/hush/svgk.py` | keep | the Figgis + Stalls generator (`python3 tools/art/hush/build.py`) and its validator |
| `tools/art/hush/validate.py` | keep | reached by `tools/ci/lint_all.sh` |
| `tools/scripts/anim_sheet.sh` | delete | no live 3D file reaches it (scan) — the 2D sheet script (anim_sheet3d.sh replaces it) |
