# r3d-anim-hush-b — LANDED
2026-09-30T17:25Z START (queue launch, priority 3). Time box 10 h (R19: cut line at 7.5 h active).
18:23Z FINAL hush/loco_arrive (8 f, flavour:arrive) + the three band fallbacks hush/rig_mid (96 f), hush/rig_high (120 f, the mime step +0.40), hush/rig_low (144 f, crawl half under) + FINAL hush/freeze_midjob (loop 600: mid/high/low held segments, sidecar variants) — baked, lint --strict clean, sheets in docs/review/r3d-anim-hush-b/sheets/
DONE hush/loco_arrive ef79f74d1d0b4f783d56d50f1b1e540ac509c874c2e6cd8481a78323f27dc499
DONE hush/rig_mid 2db5b7611a481f1dc42c6fa2fb8ff2ad77080bf0f115e8c5aa048724a032c5a5
DONE hush/rig_high 55fe4f75b0b67769a645c103435b18cdf89d136b8db1ab89d25e600fbd531ffb
DONE hush/rig_low 0e74814d3a9653b1e271b30c82e9294da3e52f4f02f3c86f82620c2b4eb8350f
DONE hush/freeze_midjob b454de673c65878bb9f7ca8febc420908030ae89d00931a2fd4f885e714ab740
18:44Z hush/act_glance (30 f, overlay mask head), hush/loco_skid (6 f), hush/idle_fidget_look (80), hush/idle_fidget_proud (84), hush/idle_fidget_clarence (80, audio-table row kept) — baked, lint --strict clean
DONE hush/act_glance 17e76e8a6fbddba522d13f6d5e774b563b61680f68f3b7d18a058aaa6d04ba63
DONE hush/loco_skid 83fcc6d0ca9f944e4e990c511812257326ddc3772763adb38b8921e433ff2ed1
DONE hush/idle_fidget_look 61023d7955f2f47445216eeecea559ec5791bc2366d7078f57781c8c4dbb47cb
DONE hush/idle_fidget_proud e6f3276c4aed889021fb40d43857faf2b0911adffa3e27f367ddd959279c6982
DONE hush/idle_fidget_clarence bd1e445163dd4c58d119744f56b0bdcee9a63024c5c77a8f6d280db1f9070685
REQUESTS
  r3d-anim (hush3d/map.json, the clips above have DONE lines): "flavour:arrive": "hush/loco_arrive", "flavour:skid": "hush/loco_skid", "flavour:glance": "hush/act_glance" (overlay, mask head — also the view's flavour:glance_rig), "idle_fidgets": ["hush/idle_fidget_look", "hush/idle_fidget_proud", "hush/idle_fidget_clarence"], "freeze_midjob": {"clip": "hush/freeze_midjob", "loop": true}. rig:<prank> rows stay derived (bands.<band>.clip = hush/rig_mid|rig_high|rig_low, all landed).
  r3d-view3d (CharacterView3D): (1) play every rig_* clip with the sidecar's stage.facing (the band clips are baked facing +1: the thing ahead and up-stage at her front-left) and cheat ≤ 10 — r3d-anim asked the same; (2) hush/freeze_midjob carries an optional sidecar field "variants" {"mid": [0, 359], "high": [360, 479], "low": [480, 599]} + "variant_default": "mid": play it with start_frame = variants[<the prank's rig_actions band>][0] and hold that frame (set_external_frame) — a view that ignores it shows the mid statue for 6 s, then high, then low; (3) act_glance is layer overlay / mask head (only neck + head move), 30 f.
  r3d-sets (house3d.json, N1/N2 band props — kettle, sink tap, fridge shelf, newspaper, phone, pickle jar, clock, mirror, recliner): reach_pos.dx so that Hush stands BESIDE the prop (dx ≈ -0.26 with facing +1: the prop 0.26 m ahead and 0.2-0.3 m up-stage), not in front of it — in the N1 kitchen (ViewSandbox3D --sim, tap_dance at t 52-100) she stands at x 19.04 in front of the tap at 19.12, so her body hides the tap and the band clip's gloves work 0.2 m to the right of it.
19:20Z hush/act_rummage (loop 36), hush/act_wheeze (loop 60), hush/st_shrug (20, overlay upper), hush/st_yanked (36), hush/freeze_5 hat-tip / freeze_6 ballerina / freeze_7 lamp post / freeze_8 scarecrow (150 each; 64 px IoU among 5-8 max 0.57) — baked, lint --strict clean. All 18 clips of the list now exist (no drafts).
DONE hush/act_rummage 60008f7b241c63b86a1c3803e55af2639635655ff607f8a879dcf8b6e4497dd1
DONE hush/act_wheeze e4cab6be5fa665e61c3763b88bb6198ed748abfbd561e0b65d6f08a80d627a64
DONE hush/st_shrug ede4018b3ed54e42aaba6d0fccae3236dd0849a8af40bb5f7389a4d989d41ed1
DONE hush/st_yanked 8b7227723ade1fc966ece3d30413610f9da71534be3dfdc13dc8d706fd72e4ae
DONE hush/freeze_5 4dbeee5bd2467e2bf1f845399c4f54d113d487ba5d0211a97303b727e69c038f
DONE hush/freeze_6 27e7c0adeeccad8d7326fcc804b806abfdb1b9d88763c3fab494d0e9c8e73fea
DONE hush/freeze_7 7aa7faf263e19cff1e385dbd1b0bd86275ab8c93ec0ca02b6743cb4efed0fbac
DONE hush/freeze_8 89102f82212fc5cc916dd9816fe32b0271bc4494927e9b819b62e3a8ff70386b
REQUESTS
  r3d-anim (hush3d/map.json): "state:rummage": {"clip": "hush/act_rummage", "loop": true}, "state:pick_window": {"clip": "hush/act_rummage", "loop": true}, "oneshot:wheeze": {"clip": "hush/act_wheeze", "loop": true}, "flavour:shrug": "hush/st_shrug" (overlay upper), "oneshot:yanked": "hush/st_yanked", "freeze": add "hush/freeze_5".."hush/freeze_8" to the freeze_1..4 variation list.
19:51Z re-baked all 18 on r3d-anim's updated lib (clip.py/pose.py 19:25-19:29), lint --strict clean; band clips gain the optional sidecar field reach_offset [dx, y, dz]; rig_low's bracing glove moved under the shoulder (IK within 0.033 m); st_shrug palms-up IK; freeze_6 arms in a V; 8-statue 64 px IoU max 0.57 (docs/review/r3d-anim-hush-b/statues_8.json)
DONE hush/st_shrug 902c8d009b5bff6fe4b7d32b69130aa68cfea243cb57aefe962bd411b1cd6202
DONE hush/rig_mid bfa9d2ec74b28ea804af977cea1bdecf70203bb910f4d3bcab727946c3ee1677
DONE hush/rig_high 262d1bb74e7ebc35d2a98deae7005b1459be982c71174bf1855f69a04efa630b
DONE hush/rig_low 21e9c11899dc55a66ea31aaa14c40b8183bb306c42fa21ab81cc16761f112ec1
DONE hush/freeze_6 986040cfdeda52a5d91503e601c772f10b965dc028036866ed72edf2e9f0449e
20:00Z lead note D8: runtime camera gaze (sidecar "gaze", c.look_camera) on the face beats — st_shrug 0-18, st_yanked 0-25 + 27-36, idle_fidget_proud 6-78, idle_fidget_clarence 52-76 (after the head-riding shush), act_wheeze 0-60; motion unchanged; rebaked, lint --strict clean
DONE hush/st_shrug 1e0918d4f0f7684be319d6f4b7bfb3874f480691c47bf686976ea9c5d16b4d35
DONE hush/st_yanked 4027c56eb132c6847a4634567b11c661f74179f8ec6daa84f1e33be1ddd63fd1
DONE hush/idle_fidget_proud fea1f677465438b4e100eddb2c0ea30e9b4fa7a2be84942c3eb6af0b3b20169c
DONE hush/idle_fidget_clarence db1ad080f81e637ab3acd8a028d97a3b7deaff4ce8bb4d40765897d509856eda
DONE hush/act_wheeze 52fe603f0aa9aa35609fdfd953764d4f95ba7d2fbe6b8636f7fb304b15948f48
20:20Z hush/act_wheeze: the squeeze reads at game scale (the strain down to the knees f 40, a gasp f 48, Clarence squashes 60 %); rebaked, lint --strict clean
DONE hush/act_wheeze 879ea504b1754d5772f45f7671deaaece8b0b5c47aa9d55be563fb90aa403812
20:38Z review: sheets re-rendered after the last bakes; statues_8 re-measured (max IoU 0.571, freeze_7/8); bands_staged.jpg + bands_staged_strips/ (the band clips at today's reach_pos vs the prop 0.24-0.30 m ahead); rubric.md, index.md, reviewer_prompt.md + packets/bands_now|bands_staged (R17, pending review)
REQUESTS
  r3d-sets (house3d.json): reach_pos = placed reach target - the band clip's sidecar reach_offset (rig_mid [0.26, 1.00, -0.20], rig_high [0.24, 1.86, -0.20], rig_low [0.30, 0.28, -0.22]; z >= -1.6) — measured: kitchen_sink_tap dx -0.08 z -1.60, hall_clock dx -0.12 z -1.60, parlour_recliner dx -0.15 z -1.43; kitchen_kettle: visual_offset.x -0.30 -> >= +0.05 (her spot 0.26 m left of it is inside the kitchen/parlour wall today), then dx ~ -0.26 (docs/review/r3d-anim-hush-b/bands_staged.jpg)
  r3d-view3d: (a) or place her at placed reach target - reach_offset while a band clip plays; (b) consume sidecar "gaze" windows via look_at_point(camera, weight) (st_shrug, st_yanked, idle_fidget_proud/clarence, act_wheeze + r3d-anim's clips); act_glance's audience snap is baked for facing +1 (all band rigs) — as flavour:glance facing -1 it looks upstage until gaze is consumed; (c) act_rummage / state:pick_window: yaw her toward the container
  r3d-rig: anim_sheet3d.sh crashes on overlay sidecars (act_glance, st_shrug); AnimViewer3D --play --shot-seq runs on the real clock (a heavy --episode set skips the clip start) — a fixed-step option would make sequences exact
  orchestrator (R17): run the two mute-test packets of docs/review/r3d-anim-hush-b/reviewer_prompt.md
20:51Z bands.png / bands_frames.jpg re-shot in ViewSandbox3D --sim on r3d-sets' 20:42 reach_pos (kettle, jar, clock face, recliner now under her gloves; mirror still behind her). Verify: test_hush_b 6/6, lint hush --strict 35 clips 0 errors, full suite 1494 passed / 1 failed (r3d-sets set3d collisions, in progress), lint.sh exit 0. Report: <SP>/reports/r3d-anim-hush-b.md — DONE
