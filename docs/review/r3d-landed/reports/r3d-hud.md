# r3d-hud report (B1, branch r3d)

Scope: the decluttered R3D HUD (REDESIGN_3D §2), its panels, the world overlays (§4.1, §4.4, §4.5) with their
rules and placer (§2.5), preview pictograms, Settings keys, C5 strings and Figgis on the SVG level. All files are
inside my brief's §2 paths. Landing log: `<SP>/work/r3d-hud/LANDED.md`. Review: `docs/review/r3d-hud/index.md`.

## 1. What was built

HUD (`game/ui/`)
- `hud.gd`, `hud_layout.gd` rewritten. There are four always-on pieces: pause (96 px navy disc), the Script chip (new `widgets/script_chip.gd`: pips, dots and a star; pill width 112+46r+22o+50, capped at 440), Clarence (navy disc, with a lure ring only when it applies), and the action button, QUIET/LIVE (`set_face(verb, live)`, 250 ms hysteresis, 120 ms cross-fade; LIVE FREEZE is a stone face with an amber rim that goes red/amber at 3 Hz while he is filling).
- Contextual pieces:
  - the transient 460×104 meter: shows for 2.5 s after a change, during a Running Gag, and with tomatoes on a catch; draws a "+n" stamp;
  - the fuse under the meter;
  - the Bellows window with a next-activity chip (`PipFrame.set_next`);
  - the edge badge: 136×220 zones, uses the landed 3D portraits (falls back to the 2D face), has a lean;
  - carried-item chips, shown only while carrying;
  - Figgis for 4 s after a nudge, or while its card is up;
  - the BOW chip (new `widgets/bow_chip.gd`);
  - the overview, shown only when `overview_visible` is set;
  - tag flights that pop a Script pip.
- `hud_model.gd` gains an R3D block:
  - enums `Pip`, `FreezeDanger`, `LureRing`;
  - fields `verb_live`, `freeze_danger`, `meter_until_s`, `carrying`, `bow_visible`, `figgis_visible`, `overview_visible`, `lure_ring`, `script_pips`, `edge_badge_side/_arrow/_icon/_lean`, `pip_next_icon`, `pip_ring_frac`, `tag_flights`.
- Widgets restyled: pause_button, clarence_button, action_button, applause_meter, running_gag_banner, pip_frame, edge_bubble (now the edge badge), tray (chips only).
- `figgis_chip.gd` works on the SVG level only: moods idle/psst/point/shh/proud, a 0.15 s bob/tilt on each swap, and a 320×200 card. No RigPlayer, ClipLib, Atlas*, RigDef or PropSim references (a source-scan test checks this).

Panels
- PauseMenu: Resume across the full width, then two columns (Retry, Take a Bow, Hint, Map, Settings, Playbill) and a header showing applause, tomatoes and curtain calls.
- `ScriptPanel.set_rule(text)` draws a "Tonight: …" line above the routine strip.
- SettingsPanel:
  - a new View tab (Previews always/when idle/off, Room dimming, Outline +50 %);
  - Debug keys: hush_head (shown only when `data/rigs3d/hush/rig3d_head_b.json` exists), bellows_window, msaa_3d, render_scale, show_previews;
  - tabs with more than 5 rows use two columns whose rows stack the label over the control (fixed this session: labels and descriptions used to overlap the buttons).

World overlays (`game/ui/world/`)
- **OverlayModel:** pooled slots — previews ×8, thought, item bubbles ×4, rig ring, safety marker, tag flights ×4 — plus `at_hotspot`.
- **OverlayCtx:** built once by `prepare(db, episode)` from content and `data/view/previews.json`. The Night fills its per-frame fields.
- **OverlayRules.fill:** implements N2, N4, V1–V6, the Settings modes, his ring, the needs cloud, item bubbles and the combine badge. `suggest_next_useful` is a stand-in for N4 until the hint system supplies the next useful spot.
- **OverlayPlacer:** the §2.5 priority order. Other items slide sideways (≤ their own width), then up (≤ 150 px), then wait. It can be used standalone or as one shared placer per frame.
- **WorldOverlays:** a CanvasLayer on layer 8 with `setup(anchor_src, hud)`, `warm(ctx)` and `apply(model)`.
- **View nodes:** PreviewCloud, ThoughtCloud, ItemBubbleView, RigRing, SafetyMarker, TagFlight, PreviewArt.
- **FakeAnchors:** a greybox anchor source built from house.json, viewed through a real Camera3D.

Art
- `game/art/ui/previews/*.svg`: the 11 slice pranks, plus `_unknown` and `badge_to_sink`. Each SVG declares its previews.json ids in `<desc>ids: …</desc>`; generator `game/art/ui/_src/gen_previews.py`.
- `game/art/ui/verb_freeze_quiet.svg`.
- `game/art/chars/figgis/figgis_{chip,psst,point,shh,proud}.svg`: a look-A vinyl mouse in the navy prompt-box hood; generator `_src/gen_figgis.py` (the gloves were redrawn as round mittens this session).

Settings and strings
- `game/autoload/settings.gd` keys:
  - player keys: previews, room_dimming, outline_boost;
  - debug keys: hush_head, bellows_window, msaa_3d, render_scale, show_previews.
- The debug keys' defaults come from `scenes/boot/boot_config.json` (`reload_boot_defaults()`, `default_of(key)`). `save()` leaves out a boot key while it equals its default. FILE_VERSION is 3.
- `game/data/ui/strings.json`: the C5 strings (pause.hint/map/applause/curtain_calls, hud.bow/applause/script, settings.* for every new key, script.routine, script.rule, fx.struck).

Demos and review tools
- `ui/demo/UiDemo.tscn`: 46 states over the greybox kitchen, with overlays driven by the real rules. Flags: `--cycle`, `--state=`, `--debug-rects`, `--backdrop=2d`.
- New `ui/demo/HudOn3D.tscn`: the HUD and overlays over the REAL 3D view. It reuses ViewSandbox3D's wiring and adds the Stage-2 HudPresenter and the overlay rules. Extra flags: `--at=<tick>`, `--idle-s`, `--pieces`, `--perf`, `--no-hud`, `--no-overlays`.

Tests (`game/tests/ui/`)
- New:
  - test_overlay_rules, including suggest_next_useful and at_hotspot;
  - test_overlay_placer;
  - test_world_overlays, including the at-prop exemption and the hud_rects handoff;
  - test_settings_r3d;
  - test_hud_r3d;
  - test_tap_assist_3d.
- Rewritten: test_hud_layout, test_hud_pip.
- Updated: test_panels_s2 (Figgis SVG, stacked settings rows), test_panels, test_settings_haptics, test_s2_contracts, test_hud_s2 (the emote face now comes from the portrait).

## 2. Fixes found while looking at the real 3D view (this session)
- **Invisible caption text.** `UiKit.font()` changes the shared fonts' MSDF range and size the first time they are used. If the HUD loads after the view has drawn captions, those captions render as white bars with no text. Fix: new `UiKit.warm_fonts()`, called from the Settings autoload's `_ready`, so the fonts are configured before anything draws. Rule for everyone: the first UiKit font use must come before the first text draw (the autoload now guarantees this).
- **Preview pushed off its own prop.** WorldView3D protects "the prop Hush is at + its preview", but that rect was also pushing that same preview away. It is now exempt: `OverlayModel.at_hotspot` is set, and the placer's `exempt_anchor` applies to that preview only.
- **HUD rects added twice.** WorldView3D already adds `hud_rects` to its protected set, and WorldOverlays was adding them again. Now, when the anchor source has a `hud_rects` property, WorldOverlays hands `hud.always_on_rects()` to it instead of adding its own copy.
- **Debug view.** `OverlayPlacer.pool()`, `Item.was_active` and `WorldOverlays.phase_us` exist so the `--debug-rects` view can show the last solve.
- **Demo glitches.** Fixed greybox z-fighting and made the tag flight stay visible in the demo.

## 3. Verification
- **Tests:** `test_game.sh r3d-hud -- ui/` gives 255 passed, 0 failed.
- **Full suite:** 1413 of 1415 passed. The two failures:
  - `cast3d/test_hush3d.gd::test_props_sample_used_palette_cells` belongs to r3d-cast-hush;
  - `ui/test_hud_s2.gd::test_emote_reaches_the_bubble_and_clears` was mine: it broke because the Bellows portraits landed. Fixed and now green.
- **Also seen:** `tests/night/test_night_scene.gd` failed to compile in one run (`night_scene.gd` referenced ShaderWatch, Perf3D and `_on_tag_flight` from r3d-night's work in progress).
- **Lint:** `SANDBOX=r3d-hud lint.sh` exits with rc=1. The main lint passes ("0 lint(s) failed", ip OK, hotspot OK). The only errors are `lint_anim 3d` on `data/anim/hush3d/st_shrug.json` (L15_face_accent, L07_antic_opposes), which belongs to r3d-anim-hush-b.
- **Pieces on screen** (`Hud.debug_pieces()`) on the real 3D view:

  | moment | pieces |
  |---|---|
  | P00 calm | 5 (the 4 always-on + the window) |
  | Rigging | 5 |
  | N1 entry warning | 4 |
  | N2 freeze | 4 |
  | g0 payoff | 6 (+ meter, banner) |

  The 2D reference frames show about 12. Always-on is exactly 4 (test).
- **Middle band:** no always-on or persistent piece intrudes into y 250–880, except the action circle's top edge (y 792) and BOW-under-window (see §4).
- **Performance** (HudOn3D `--perf`, N1 ideal from tick 250, 240 frames, llvmpipe, other Godot slots busy):

  | measured | median | p95 |
  |---|---|---|
  | Hud.apply | 22 µs | 55 µs |
  | OverlayRules.fill | ~100 µs | ~200 µs |
  | WorldOverlays.apply | 335 µs | 657 µs |
  | – of which WorldView3D.protected_rects() (second call, warm) | ~125 µs | |
  | WorldView3D.protected_rects() on its own, first call in a frame | ~230 µs | |

  - Hud.apply + WorldOverlays.apply comes to about 0.36 ms median, under the 0.5 ms budget.
  - The HUD and overlays cost 10 canvas draw calls (69 with them vs 59 without), under the 30 budget.
  - Allocation-free per frame: pooled models, a fixed pool of protected rects, const arrays.
- **Visual review** (every frame looked at, at 1200×540):
  - 46 UiDemo states at 20:9, 16:9 and 4:3;
  - 14 real-3D shots;
  - before/after against the 2D reference frames at 5 moments;
  - the placement debug view;
  - the pictogram board and the Figgis board.

  All are in `docs/review/r3d-hud/` (3.0 MB).

## 4. Deviations from REDESIGN / the brief
1. **Action button in the middle band.** §2.1's action circle (centre at H−B−168, 240 px hit) necessarily reaches y 792 at the 1080 base, inside §2.5's middle band (250–880).
2. **BOW chip.** It sits top-right (W−S−344, T+24) while the window is closed. Under an open Bellows window it slides to T+273 (`bow_low`), which is inside the band while it shows; `debug_pieces` marks it persistent.
3. **Escalated window.** It keeps the top-right corner but shrinks (keeping its aspect) to stay 24 px clear of the Script chip and the meter. At 16:9 the full 704×396 would touch the meter.
4. **No label text on the edge badge.** It shows icons only; `edge_bubble_label` is ignored.
5. **Figgis downgrade.** The 2D rig idle animation is gone. Figgis is one SVG per mood with a 0.15 s swap bob/tilt, and the look was restyled to look A.
6. **Tag flights.** When a Hud is bound, it flies the tag (above the chip) instead of WorldOverlays.
7. **The at-prop preview exemption and the hud_rects handoff** (see §2).
8. **Waiting previews at 16:9 and 4:3.** A preview whose anchor sits under the top-left HUD cluster waits, per the rule: slide sideways ≤ its width, up ≤ 150 px, else wait. Example: the P00 honey on its high left shelf at 4:3 (`on3d_v4_calm_4x3`). I did not add a "slide down" fallback, because §2.5 does not allow one.

## 5. Requests
- **r3d-night:**
  - Fill the R3D HudModel fields: verb_live, freeze_danger, script_pips (or leave them empty and the Hud derives them from script_lines), carrying, bow_visible, figgis_visible, overview_visible, lure_ring, edge_badge_*, pip_next_icon, pip_ring_frac, meter_until_s, tag_flights.
  - Each frame, fill the OverlayCtx fields: now_s, idle_s, previews_mode (Settings "previews"), entry_warning, spot_filling, chase, reaction, next_useful, at_hotspot, action (= action_context()), hide_all.
    - For entry_warning: set it from the sim's `entry_warning` event (room = Hush's room) until eta + 0.3 s.
    - For next_useful: take it from the hint system, or use `OverlayRules.suggest_next_useful` as a fallback.
    - Call `note_action_done()` on each player action.
  - Once, under the curtain: `OverlayCtx.prepare(db, episode)`, then `WorldOverlays.setup(world_view, hud)` and `warm(ctx)`.
  - Every frame: after `Hud.apply`, call `OverlayRules.fill` and then `WorldOverlays.apply`.
  - Other wiring:
    - `hud.attach_pip(pip_view_3d)`;
    - use `Hud.open_pause_menu(can_bow, header)`, or handle its "hint"/"map" results;
    - `ScriptPanel.set_rule(text)`.
  - `game/ui/demo/hud_on_3d.gd` shows the whole wiring.
  - `night_scene.gd` failed to compile in one suite run (ShaderWatch, Perf3D, `_on_tag_flight`).
- **r3d-view3d:**
  - Register the Overlays3D captions and stamps in `world_overlays.placer` (Pri.CAPTION, his bubble as Pri.BUBBLE fixed). At N2 6520, "SOMETHING FISHY" and "TIME'S UP" overlap each other and his bubble.
  - `protected_rects()` costs about 230 µs on its first call in a frame (llvmpipe). Please cache the actor AABBs per frame.
  - Consider keeping live props out of the top-left HUD corner in the camera's keep-visible framing.
- **r3d-tools-b / lead:** The HUD lint should exempt the always-on pieces' own rects (the action circle) and the BOW-under-window from the middle-band rule.
- **r3d-docs:** GDD/TECH amendment text:
  - 4 always-on pieces plus the contextual list;
  - the placer exemption for the preview of the prop Hush is at;
  - the rule that fonts are configured before the first draw (`UiKit.warm_fonts` at boot);
  - the Figgis downgrade;
  - the new Settings keys and the boot_config defaults.
- **r3d-integrate / orchestrator:** These new SVGs have no committed `.import` files: `game/art/chars/figgis/figgis_*.svg`, `game/art/ui/previews/*.svg`, `game/art/ui/verb_freeze_quiet.svg`. They are rasterised at runtime from the raw SVG, and sandbox imports work. Please generate and commit the `.import` files through the normal editor import (not hand-written), or keep `*.svg` in the export include filter.
- **r3d-cast-hush:** `cast3d/test_hush3d.gd::test_props_sample_used_palette_cells` fails.
- **r3d-anim-hush-b:** `lint_anim 3d` errors on st_shrug (L15, L07) make `lint.sh` exit with rc=1.

## 6. Gaps
- There is no real NightScene3D shot yet: r3d-night has not landed. HudOn3D is the stand-in, and its R3D presenter fields use the simplest rules.
- Figgis's 3D-portrait parity is only judged against the landed Bellows portraits; there are no Hush portraits to compare with.
- The perf figures are from llvmpipe on a shared CPU, not from a device.

## 7. Hours
About 2.7 h active (16:30–19:15 UTC).
