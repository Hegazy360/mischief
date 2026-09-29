# s2-fix round G — review artefacts (Checkpoint G, the Gate-0 APK)

Every image is a real capture of the game at 1200 × 540 (20:9 phone) unless it says "native"
(2400 × 1080, what a 1080p-tall phone draws). "BEFORE" = tree 23f4d13 (a copy of it replayed with
its own scripts), "AFTER" = this round. I looked at every image at phone scale.

| File | Request | What to judge |
|---|---|---|
| `01_facing_tea_before_after.jpg` | #1 (P0, facing) | Before: on the tea stool he faces the fridge, 72 % wide. After: he faces the counter (−1) at full width. |
| `02_caption_before_after.jpg` | #2 (P0, caption) | Before: "HOO-RIA!" under the RUNNING GAG banner. After: the whole pun sits below the banner, or beside his head during the 1.4× punch-in. |
| `03_boot_stage_door.jpg` | #3 (P0, boot config) | The Gate-0 build boots into the stage door: Gate 0, voice/crowd A/B, Cast, Prologue, Night 1/2, Device log. |
| `07_memory_kitchen_native.jpg` | #7 (texture memory) | Native 2400 × 1080 crop, N01 tick 2000. Before: 715 MB. After: ≤ 250 MB. The rooms, props and both characters are identical and crisp. |
| `07_memory_top_band_native.jpg` | #7 | The upstairs strip (unlit, another floor, now ¾×) under the HUD's top row: no visible softening. |
| `07_art_scale_2_vs_1_5.jpg` | #7 | The same beat at ART_SCALE 2 (≥ 3 GB phones) and 1.5 (< 3 GB phones, `-- --art-scale=1.5`). Both are crisp at phone scale. |
| `08_hud_meter_before_after.jpg`, `08_hud_button_before_after.jpg` | #8 (draw calls) | The HUD after UiShapes batching (one triangle array per widget) is pixel-identical to the StyleBox/circle version. |
| `14_hush_climb_in.jpg` | #14 | Before: at tick 60 Hush already stands in the kitchen. After: she is not drawn until her climb-in starts (tick 200: in). |
| `16_drops_at_part.jpg` | #16 | The CHOO's drops leave his nose in his facing direction (−x), the sink dunk's from his torso. |
| `19_pip_offscreen.jpg` | #19 | The PiP shows him while he is off screen (legit). The on-screen suppression is proven by `game/tests/view/test_pip.gd`. |

Numbers (texture MB, draw calls, build/warm ms, RigPerf) are in the round report
(`<SP>/reports/s2-fix-g.md`).
