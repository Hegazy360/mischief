# UI review — HUD, panels, touch layer (Stage 1, task `ui`)

All shots come from `game/ui/demo/UiDemo.tscn` (a scripted fake `HudModel` over art-house's parlour art with
stand-in characters; item / activity icons are still art-house's pending files, so tray slots and the RIG
target badge show the neutral `item_fallback` / `script` fallbacks). Regenerate:

```
tools/scripts/shot.sh res://ui/demo/UiDemo.tscn out.png 30 ui -- --state=<state> [--left-handed] [--safe-area=162,0,162,58]
# every state in one run (40 frames apart):
tools/scripts/shot.sh res://ui/demo/UiDemo.tscn last.png 930 ui -- --cycle --shot-seq=/abs/dir --every=40 --count=23
```
Sizes: 1200×540 = 20:9 phone (logical 2400×1080), `SHOT_SIZE=960x540` 16:9 (1920×1080),
`SHOT_SIZE=1080x810` 4:3 tablet (1920×1440 → HUD ×0.8). PNGs are palette-quantised for git.

## The four brief shots (judge at 100 %)
| File | What it shows | What to judge |
|---|---|---|
| `rig_50.png` | 20:9, holding RIG at 50 %: item → target on a gold disc, the 14 px yellow→green ring, the "HOLD" tag; the accepting tray slot risen + glowing | ring readable around the thumb; the world's middle 60 % stays clear |
| `16x9.png` | 16:9 (1920 wide, the tightest phone), FREEZE held (frosty statue) | the free bottom-centre band between tray and action button; 144–240 px targets |
| `4x3.png` | 4:3 tablet (HUD ×0.8), the Script panel: ticks, beret stamp, "???", ribbons, candle, sealed Big Number, his loop strip | 44 px rows readable; panel fits |
| `notch.png` | 20:9 with 162 px notch insets + left-handed: mirrored clusters, PiP top-left (livid frame + specs-on glyph), POP OUT with red rim | nothing under the notch; mirroring complete |

## Every state at 20:9 — `20x9/<state>.png`
`rig_0` (ghost glove teaching HOLD) · `rig_50` · `rig_100` (completion) · `rig_dim` (missing item: silhouette in
the grey thought-cloud, "NEED ITEM") · `freeze` (held) · `pop_green` / `pop_amber` / `pop_red` (danger rim;
Clarence is ⏩ while hidden) · `go` (pin + GO ▶) · `ff` (⏩ held) · `lure_grey` (lure ring greyed) ·
`tray_highlight` · `figgis_pulse` ("psst!") · `figgis_card` (cue card chicken → Bellows) · `pip_steaming`
(Bellows-Cam, steaming frame + Running Gag ×1.5 with the fuse) · `edge_bubble` ("↑ upstairs" under the banner) ·
`pick_strip` (3 items + the 3 s drain bar) · `script` · `pause` (Interval) · `settings` (Play tab) · `loading`
(the rule card on art-house's curtain) · `results` (curtain call: stamps, count-up, why-missed line, Gag Reel
slot, +NEW! chips, Next Night ▶ under the right thumb) · `encore` (118: gold number, sparkles).

## Contact sheets — `sheets/<variant>.png` (all 23 states, 50 %)
`20x9` · `16x9` · `4x3` · `notch` (162,0,162,58) · `lefthand` · `notch_lefthand`.

## Icons — `icons.png`
Every `game/art/ui/*.svg` at 128 px and 48 px (generator: `game/art/ui/_src/gen_ui_icons.py`): verbs, Clarence
fallback, ⏩, pause, overview, Figgis chip, script, tomato + splat, stars, rose, candle, ribbon, wax seal, beret
and tick stamps, arrow, ghost glove, tray, gear, retry, lock, item fallback, Bellows' edge-bubble face, the 5
awareness glyphs and the 4 hotspot badges (for `view`).

## What I judged (and changed after looking)
- Clarence read as a speck → now art-hush's upright Clarence at 150 px, squashing on press.
- POP OUT was a dark icon on a dark disc → cream disc, danger rim.
- ENCORE flash collided with the Running Gag banner → a stamp across the meter plate.
- Settings title collided with the tabs; row backgrounds were muddy (a navy base under translucent fills) → fixed
  in `UiKit.draw_chunky_rect`.
- Curtain-call star labels overlapped → 330 px column pitch; the flat spotlight discs → a soft falloff.
- Left-handed Figgis "psst" / cue card opened over Pause → they open toward the centre.
- Remaining look gaps: item / activity icons are fallbacks until art-house lands them; the parlour art under
  the demo is art-house's.
