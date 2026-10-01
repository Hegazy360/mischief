RQ1 is fixed: the spikes at t1447–1450 and t3237 are gone in all 6 after-runs. RQ2's dirty flag is in and tested, but it saves almost nothing: the placer solve was never the main cost. All requested tests and lint pass.

## RQ1 — the t1447 spike was a cold icon, not the meter/banner first show
I split `Hud.apply` by section and logged every icon-cache miss during play (scratch copy only):
- **Meter/banner show is cheap:** `_tick_contextual` takes 7–24 µs on that frame and `banner.set_values` under 10 µs.
- **The cost is the edge badge:** 0.97–1.66 ms on that frame, in its next-activity icon. After the knock-on, Bellows' next activity is the mirror fix-up, and `fixup_mirror.svg` was rasterised on first sight (0.84 ms).
- **Same cause at t3237:** his exit (`exit.svg`, 0.92 ms). This was deterministic in 3 of 3 baseline runs; r3d-fix-perf had filed it as noise.

Fix:
- `NightWarmer._warm_ui_icons` now rasterises every detour icon listed in `activities.json` under the curtain (8 icons: the 4 fix-ups, curious, herd_beryl, search, exit), via the new `Hud.warm_activity_icons()`.
- I also added `Hud.warm_contextual()` as you asked. It shows and draws the meter, the Running Gag fuse and the edge badge for 2 frames under the curtain, plus their text at the sizes they use, then restores them from the model.

| `Hud.apply` (ms) | headless | rendered 1 | rendered 2 |
|---|---|---|---|
| t1447–1450, before | 1.16 | 1.15 | 1.33 |
| t1447–1450, after | <0.30 | 0.15 | 0.11 |
| t3230–3238, before | 1.42 / 1.72 | 1.18 | 1.04 |
| t3230–3238, after | <0.30 | <0.30 | <0.30 |
| p95, before → after | 0.056 → 0.044 | 0.064 → 0.063 | 0.060 → 0.054 |

- One rendered after-run has 5.58 ms at t510. Nothing appears there in any other run, so under D17 it is noise.
- Warm-up time is unchanged (187–375 ms after vs 200–483 before). Peak texture memory rose by 0.9 MB (129.2 → 130.1).

## RQ2 — dirty flag added, but the solve was 7% of the cost
`OverlayPlacer.solve()` now re-solves only when an input moved more than 1 px or the overlay set changed. On skipped frames an item follows its own sub-pixel drift, so slow pans don't step. It allocates nothing per frame.

What the probe measured inside `WorldOverlays.apply` (headless, p50/p95 µs):

| phase | p50 / p95 µs |
|---|---|
| WorldView3D protected rects | 144 / 277 |
| face boxes | 71 / 168 |
| requests | 29 / 90 |
| **solve** | **22 / 82** |
| writing results to the nodes | 31 / 77 |

In the Prologue only 2.3% of solves can be skipped (977 of 1000 frames have something moving more than 1 px).

I also made one more cut in my file: face boxes now check `character(id).visible` instead of projecting each character's bounding box again. This gives exactly the same result for WorldView3D; FakeAnchors keeps the old check.

| `WorldOverlays.apply` p50 / p95 (ms) | headless | rendered 1 | rendered 2 |
|---|---|---|---|
| before | 0.308 / 0.576 | 0.359 / 0.578 | 0.374 / 0.620 |
| dirty flag only | 0.296 / 0.490 | 0.367 / 0.564 | 0.350 / 0.569 |
| final (+ face-box check) | 0.279 / 0.467 | 0.355 / 0.578 | 0.338 / 0.538 |

- **t2970:** the 2.7–3.1 ms reported by r3d-fix-perf did not reproduce in any of my runs, before or after (0.30–0.60 ms at most).
- **Frames over 1.5 ms:** they land at a different tick in every run, so they are noise under D17.
- **Request to r3d-view3d:** cache `actor_screen_rect` / `project_aabb` per frame. Bellows' box is projected 3 times a frame, and the protected-rects phase is half of `WorldOverlays.apply`.

## Spike clusters (r3d-fix-perf's `clusters.py`) and overall numbers
- **Before:** 12 clusters, including t1449 NightScene 2.08 / 2.25 ms.
- **After:** 4 clusters, none in `Hud.apply`:
  - t287–290 and t403–409 are sums of small phases, each under 0.75 ms;
  - t1451–1456 comes with `bellows_apply` slowing in the same frames, i.e. Bellows' clip switch under rendering load.

  None repeats headless.
- **View+HUD p50/p95:** headless 2.25/4.06 → 2.10/3.35 ms; rendered 3.13–3.25/5.00–5.27 → 2.95–3.12/4.45–4.67 ms. Each run shared the box with one other Godot process on both sides, so part of this gain may be load variance.

## Tests and checks
- ui/ + night/ + view3d/: 467 passed, 0 failed.
- Full suite on the final tree: 1312 passed, 0 failed.
- `SANDBOX=r3d-fix-hud2 tools/scripts/lint.sh --strict`: OK. Import metadata check: OK.
- All 6 profiler runs of prologue_ideal pass.
- **Frames looked at:**
  - frame 60: nothing from the warm-up left on screen;
  - frame 1450: the meter shows 37 and the fuse "RUNNING GAG ×1" from the model, as before.

  That shot run was cut at 26 s, so its "3 laughs by 60 s" failure comes from the shortened run, not from this change.

This answer is the report: the computed task asked for one in `reports/`, but my instructions forbid writing report files there. The full tables are on the review page.

Changed files, all in /home/user/mischief, uncommitted:
- game/ui/hud.gd
- game/ui/widgets/running_gag_banner.gd
- game/ui/world/overlay_placer.gd
- game/ui/world/world_overlays.gd
- game/scenes/night/night_warmer.gd
- tests in game/tests/ui/test_overlay_placer.gd, game/tests/ui/test_hud_apply.gd, game/tests/night/test_night_warm.gd
- review page: docs/review/r3d-fix-hud2/index.md, with p00_f0060.png and p00_f1450.png

Raw runs and scripts: /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/r3d-fix-hud2/runs/