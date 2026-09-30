# r3d-hud review: the decluttered HUD, panels and world overlays (R3D)

All shots are at the phone size (1200 x 540, 20:9) unless the name says 16x9 (960 x 540) or 4x3 (1080 x 810,
tablet, UiScale 0.8). Every PNG is palette-quantised (256 colours) to keep the folder small.

## 1. On the real 3D view (`on3d/`)

`res://ui/demo/HudOn3D.tscn` = ViewSandbox3D's full wiring (SimDriver, WorldView3D, CameraDirector3D, PipView3D,
AudioDirector, Stalls) plus the Hud, the Stage-2 HudPresenter and OverlayRules -> WorldOverlays on WorldView3D's
anchor source (index §7.8). It stands in for NightScene3D until r3d-night lands; the R3D HudModel fields the Night
presenter will own are filled there with the simplest rule from the snapshot.

```
tools/scripts/shot.sh res://ui/demo/HudOn3D.tscn out.png 20 <sandbox> -- --sim --episode=<id> \
  --cmds=/abs/docs/review/r3d-ref2d/cmds/<route>.cmds.json --at=<tick> [--idle-s=8] [--pieces] [--perf]
```

| file | moment | what to check |
|---|---|---|
| on3d_v4_calm_20x9 | P00 slow route, tick 415 | calm rest: only the 4 always-on pieces + the Bellows window (with its next-activity chip); the honey's passive preview (80 %) |
| on3d_n4_idle_20x9 | same, `--idle-s=8` | N4: after 6 s idle the next useful spot's preview goes loud (x1.35, full strength) |
| on3d_v1_rigging_20x9 | P00 ideal, tick 400 | V1: rig ring ON the honey (yellow -> green), Hush's thought beside her head (away from the prop), RIG LIVE |
| on3d_v2_entry_20x9 | N1 ideal, tick 420 | V2: entry warning -> every preview gone, the safety-net marker on the pantry curtain, FREEZE LIVE with the amber rim |
| on3d_freeze_him_20x9 | N2 ideal, tick 6520 | frozen with him in the room: FREEZE LIVE (stone face, amber rim), no overlays; Script chip 3 of 3 + optional dot + star |
| on3d_payoff_20x9 | g0 ideal, tick 1160 | the payoff owns the screen: transient meter + Running Gag fuse, POP OUT, fast-forward x3 on Clarence |
| on3d_window_20x9 | P00 ideal, tick 445 | armed prank: no preview (N2); the window shows him, so no edge badge |
| on3d_armed3_20x9 | N2 ideal, tick 6430 | frozen in the hall as he enters |
| on3d_*_16x9 / _4x3 | the V4 / V1 / V2 moments | the same rules at 16:9 and on the tablet |

`[hudpieces]` at those ticks (Hud.debug_pieces()): calm 5 (pause, script, clarence, action, pip), rigging 5,
entry warning 4, freeze 4, payoff 6 (+ meter, banner), window 5. The 2D reference frames show about a dozen (pause, Figgis + card, meter + Script, window, overview, Clarence, four tray slots, action + label).

## 2. Before / after (`before_after.png`)

Left: the 2D Gate-0 build at the exact moments of `docs/review/r3d-ref2d/` (main @ 67c7276). Right: the new HUD over
the 3D view at the same tick (HudOn3D, same command logs; N1 was re-planned by r3d-content, so its hide differs).

## 3. UiDemo states (`states_20x9/` all 46; `states_16x9/`, `states_4x3/` 21 key states)

`res://ui/demo/UiDemo.tscn -- --cycle` (or `--state=<name>`): the greybox kitchen (FakeAnchors, built from
house.json, a real Camera3D) with the world overlays driven by the REAL OverlayRules on n01/n02 content. States:
play_quiet, rig_live, rig_dim, freeze_live, freeze_filling, hidden_green, hidden_red, go, carrying, meter,
running_gag, catch, bellows_window, window_escalated, edge_badge (3D portrait), edge_lean, emote_sing,
figgis_nudge, figgis_card, bow, bow_window, script_full, tag_flight, tray_arrows, pick_strip, lure_ring, lure_grey,
overlays_v4 / v1 / rigging / v2 / v3 / n4 / needs / items / his_ring / combine, placement, script (with tonight's
rule line), pause, pause_nobow, settings, settings_debug (two columns, label over control), loading, results, encore.

## 4. Placement (`placement.png`)

`--state=placement --debug-rects`: red = protected rects (Hush +48, Bellows +48, the prop Hush is at + its
preview, the always-on HUD +48), navy = the four always-on hit rects, green = where the placer put each overlay
(thin green + line = where it wanted to be), blue lines = the middle band y 250-880. His bubble (fixed, top
priority) and a pun caption are registered in the SAME placer the way WorldView3D's FX will.

## 5. Art

* `pictograms.png`: the 11 slice pranks + `_unknown` + `badge_to_sink` at 78 px (the 1080 base, as drawn in
  the 112 x 90 cloud) and at 2x. Each SVG declares its previews.json ids in `<desc>ids: ...</desc>`
  (tested). Generator: `game/art/ui/_src/gen_previews.py`.
* `figgis.png`: the restyled look-A Figgis (vinyl mouse in the navy prompt-box hood) in five moods at 144 px (the
  1080 base), 72 px (the phone) and 256 px, beside the landed 3D Bellows portraits and the old 2D rig chip.
  Figgis is now one SVG per mood (no RigPlayer / clips / atlas): the idle rig animation is gone, replaced by a
  0.15 s swap bob / tilt. Generator: `game/art/chars/figgis/_src/gen_figgis.py`.

## 6. Known limits seen in these shots

* 16:9 and 4:3: a preview whose anchor sits under the top-left HUD cluster (the P00 honey on its high shelf at
  the left of the frame) WAITS (placement rule: sideways <= its width, up <= 150 px, else wait). See
  `on3d_v4_calm_4x3` and `states_16x9/overlays_v4`. The camera could frame live props clear of the HUD corners.
* The view's pun captions (Overlays3D) are not yet registered in the shared placer: at N2 6520 "SOMETHING FISHY"
  and "TIME'S UP" overlap each other and his bubble (`on3d_freeze_him_20x9`).
* Hush's stone look, Bellows' T-pose during the sneeze and the tap marker ring are the rig / anim / view tasks' WIP.
