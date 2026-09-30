# R3D §6.3 lint failures per owner (2026-09-30T20:10Z)

This file triggers the lint fix passes (index §3.3.1): an owner still running fixes its rows before it reports; an
owner that has reported gets a ≤ 2 h relaunch. Regenerate after each fix pass:

```bash
SANDBOX=<key> tools/scripts/lint3d.sh --set --screen --all-nights --aspects=20x9,16x9,4x3 --json=/abs/set_screen.json
SANDBOX=<key> tools/scripts/lint3d.sh --visibility --routes=all --json=/abs/c8.json
SANDBOX=<key> tools/scripts/lint3d.sh --hud --from=<dir of 3D e2e reports> --json=/abs/hud.json
tools/scripts/perf3d.sh <dir>/*.json --json=/abs/perf.json
python3 game/tools/lint3d/status_md.py /abs/{set_screen,c8,hud,perf}.json --out=docs/review/r3d-tools-b/status.md --note=<this note>
```

Reading the rows (what each rule measures is in `game/tools/lint3d/*.gd` class docs; boards in `index.md`):
* **set / screen** run on the tree as it stands (house3d.json, SetList, the cast v0/v1 on RigPlayer3D, CameraDirector3D);
  the screen lint sweeps every camera position a room can use (Hush walked across it both ways, C1/C2/C6 applied) at
  20:9 (2400×1080, punch-hole S = 96), 16:9 (1920×1080) and 4:3 (1440×1080 world frame, HUD from the 1920×1440 tablet
  canvas at ×0.8, REDESIGN §2.6).
* **hud** runs on the e2e reports named in the summary; **perf** on their `perf3d` blocks (desktop llvmpipe proxy).
* **visibility (C8)** replays every solver route through SimDriver → WorldView3D → CameraDirector3D → PipView3D at a
  fixed 60 fps: errors in the shipped `bellows_window` mode (boot_config.json), the other mode as info.
* Rulings applied (see the report): the four always-on pieces at their exact REDESIGN §2.1 rects are *info* in the
  middle-band rule (the action button's 240 hit circle reaches y 792 by §2.1's own numbers — lead ruling requested);
  the escalated window / BOW-under-the-window are §2.2 placements in the band (warning while ≤ 5 s); every live prop
  lists a verb `halo` in house3d.json, so "C* ≥ 45 or a halo" passes by the halo (the measured C* is reported).

| mode | result | errors | warnings | skips |
|---|---|---|---|---|
| set | FAIL | 7 | 2 | 0 |
| screen | FAIL | 10 | 0 | 0 |
| visibility | PASS | 0 | 0 | 0 |
| hud | PASS | 0 | 1 | 0 |
| perf | FAIL | 5 | 0 | 0 |

## Errors by owner (22)

### r3d-cast-hush (3)

| lint | rule | Night / room / sample | measured | limit | owner | detail |
|---|---|---|---|---|---|---|
| set | colour | N01 kitchen hush [character]: character share L* ≥ 85 | 0.199 | 0.2 | r3d-cast-hush | FAIL  |
| set | colour | N02 kitchen hush [character]: character share L* ≥ 85 | 0.195 | 0.2 | r3d-cast-hush | FAIL  |
| set | colour | N02 parlour hush [character]: character share L* ≥ 85 | 0.194 | 0.2 | r3d-cast-hush | FAIL  |

### r3d-sets (7)

| lint | rule | Night / room / sample | measured | limit | owner | detail |
|---|---|---|---|---|---|---|
| set | negative_space | P00 parlour x 9.88–10.90 m | 1.02 | 1.5 | r3d-sets | longest lane stretch with nothing behind it at head height; blockers parlour_gramophone, parlour_piano_back, parlour_window, parlour_portrait, parlour_vase, parlour_fireplace, parlour_mantel |
| set | negative_space | N01 parlour x 9.88–10.90 m | 1.02 | 1.5 | r3d-sets | longest lane stretch with nothing behind it at head height; blockers parlour_piano_back, parlour_gramophone, parlour_window, parlour_portrait, parlour_fireplace, parlour_mantel |
| set | negative_space | N02 hall x 6.82–7.50 m | 0.68 | 1.5 | r3d-sets | longest lane stretch with nothing behind it at head height; blockers hall_clock, hall_coat_cupboard, hall_mirror, hall_phone, hall_window, hall_coat_stand, hall_front_door_flat |
| set | stack | N02 kitchen kitchen_fridge|kitchen_fridge_shelf | 5.589 | 24 | r3d-sets | 20x9 worst framing cam x 15.32 (projected hit boxes) |
| screen | gap | N02 kitchen kitchen_fridge|kitchen_fridge_shelf | 5.589 | 24 | r3d-sets | 20x9: 1 framing(s), cam x 15.32…15.32: hit boxes closer than 24 px |
| screen | gap | N02 kitchen kitchen_fridge|kitchen_fridge_shelf | 5.589 | 24 | r3d-sets | 16x9: 1 framing(s), cam x 16.22…16.22: hit boxes closer than 24 px |
| screen | gap | N02 kitchen kitchen_fridge|kitchen_fridge_shelf | 5.589 | 24 | r3d-sets | 4x3: 8 framing(s), cam x 16.39…17.11: hit boxes closer than 24 px |

### r3d-view3d (12)

| lint | rule | Night / room / sample | measured | limit | owner | detail |
|---|---|---|---|---|---|---|
| screen | safe_rect | g0 kitchen kitchen_honey | [-4.6, 217.1, 226.8, 221] | [0, 0, 1440, 1080] | r3d-view3d | 4x3: 1 framing(s), cam x 16.94…16.94: outside the safe rect (C6) |
| screen | safe_rect | P00 parlour parlour_gramophone | [-2.8, 283.7, 228.5, 567.7] | [0, 0, 1440, 1080] | r3d-view3d | 4x3: 2 framing(s), cam x 10.77…11.61: outside the safe rect (C6) |
| screen | safe_rect | P00 kitchen kitchen_honey | [-4.6, 217.1, 226.8, 221] | [0, 0, 1440, 1080] | r3d-view3d | 4x3: 1 framing(s), cam x 16.94…16.94: outside the safe rect (C6) |
| screen | hud_overlap | N01 hall hall_front_door|clarence | 3645.71 | 0 | r3d-view3d | 16x9: 1 framing(s), cam x 5.0…5.0: under the always-on clarence hit rect (camera C6 keeps it clear, or house3d.json moves it) |
| screen | safe_rect | N01 hall hall_front_door | [-107.3, 287.7, 252.9, 629] | [0, 0, 1440, 1080] | r3d-view3d | 4x3: 4 framing(s), cam x 4.89…5.11: outside the safe rect (C6) |
| screen | hud_overlap | N02 hall hall_front_door|clarence | 3645.71 | 0 | r3d-view3d | 16x9: 1 framing(s), cam x 5.0…5.0: under the always-on clarence hit rect (camera C6 keeps it clear, or house3d.json moves it) |
| screen | safe_rect | N02 hall hall_front_door | [-107.3, 287.7, 252.9, 629] | [0, 0, 1440, 1080] | r3d-view3d | 4x3: 4 framing(s), cam x 4.89…5.11: outside the safe rect (C6) |
| perf | script_ms_p95 | g0 g0_night | 7.59 | <= 4.0 | r3d-view3d |  |
| perf | script_ms_p95 | P00 p00 | 5.66 | <= 4.0 | r3d-view3d | view + HUD scripts (view_ms_p95) |
| perf | script_ms_p95 | P00 p00_ideal_night | 6.84 | <= 4.0 | r3d-view3d | view + HUD scripts (view_ms_p95) |
| perf | script_ms_p95 | P00 p00_required_night | 10.48 | <= 4.0 | r3d-view3d |  |
| perf | script_ms_p95 | P00 p00_slow_night | 9.79 | <= 4.0 | r3d-view3d |  |

## Warnings (3)

| lint | rule | Night / room / sample | measured | limit | owner | detail |
|---|---|---|---|---|---|---|
| set | negative_space | N01 porch x 1.10–2.50 m | 1.4 | 1.5 | r3d-sets | longest lane stretch with nothing behind it at head height; blockers porch_no9_door |
| set | negative_space | N02 porch x 1.10–2.50 m | 1.4 | 1.5 | r3d-sets | longest lane stretch with nothing behind it at head height; blockers porch_no9_door |
| hud | window_share | P00 p00_required_night | 38.0 % | 35 % (warning) | r3d-view3d / orchestrator (R15 window default) | mode sim; longest 4.5 s; windows (open→close tick) [[48.0, 1128.0], [2316.0, 2552.0], [2604.0, 2628.0], [2696.0, 2876.0]] |

## Skips (0)

| lint | rule | what is missing | owner |
|---|---|---|---|
