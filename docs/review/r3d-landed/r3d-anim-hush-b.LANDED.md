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
