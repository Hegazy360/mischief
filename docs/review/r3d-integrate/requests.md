# r3d-integrate — the request table (brief §3.1)

Every open request from the R3D reports (`<SP>/reports/r3d-*.md`), their LANDED.md `REQUESTS` blocks, the lead's
"integrate queue" lines in `issues.md` (D7–D15) and the owner checkpoints (O1/O2: unanswered → defaults). Applied in
dependency order: data and assets → rig/cast data → clips → view/scenes → HUD → lints/tests → the 2D deletion.

Status: **applied** (by this task; file named) · **closed upstream** (a B1/fix pass landed it before this launch; the
evidence named) · **deferred to R3** (with the reason) · **refused** (with the reason) · **orchestrator** (not a file
change this task may make: git, `project.godot`, imports, reviewer runs, docs).

## 1. Applied by r3d-integrate

| id | from → to | file | change | status |
|---|---|---|---|---|
| A01 | anim-bellows-c → view3d | `game/view3d/world/cue_stager_3d.gd:105` | `socket_node("head")` → `socket_node("head_top")` (Bellows has no `head` socket: the picture frame now hangs on him) | applied |
| A02 | D7 (cast-bellows, view3d, rig) | `game/data/rigs3d/bellows/rig3d.json`, `tools/art3d/bellows/descriptor.py` | `material.outline_px` 3.5 → 4.8 (Hush's is 4.8) | applied |
| A03 | D10 / tools-b → view3d | `game/view3d/world/world_view_3d.gd` | the lean-mode edge badge is decided after PipView3D's post-camera `on_screen` (`_decide_badge()` from `set_window_shown`), no frame shows neither | applied |
| A04 | anim-bellows-b #3 (D8) → view3d | `world_view_3d.gd` `_update_gaze` | the squeak/noise gaze aims halfway to the camera (`NOISE_GAZE_CAM 0.5`) at weight 0.7: the head turn shows his face | applied |
| A05 | anim-bellows-b #2 → view3d | `game/view3d/world/character_view_3d.gd` `_play_overlay` | an overlay plays with its sidecar `mask` first (`mg_admire_in_kettle` = head), `ClipRules.mask_of()` only as fallback | applied |
| A06 | cast-hush, night → view3d | `character_view_3d.gd` | the statue plinth: set shader in STONE (registered with the material warm-up), the rig lifted by the plinth height × pop scale, built hidden at setup | applied |
| A07 | view3d #2 → night | `game/scenes/night/night_scene.gd` | `perf3d.frame()` + `shader_watch.frame()` moved out of the measured window (`_PerfSample`, priority 901, after `_FrameEnd`); `world.action_context()` cached per tick | applied |
| A08 | anim-hush-b view3d #3 / D11 → view3d | `game/view/world/clip_map.gd` | `freeze_midjob` holds the band's segment frame (`ClipMap.midjob_frame`, `rig_band_of`) | applied |
| A09 | rig, anim-hush-b (D8) → clips | `tools/art3d/anim/hush/act_glance.py` → `game/data/anim/hush3d/act_glance.json`, `game/art3d/anim/hush/act_glance.res` | `c.look_camera(5, 15)` over the audience snap: the runtime gaze gives the glance for either facing (rebaked, lint strict clean) | applied |
| A10 | audio table check → clips | `tools/art3d/anim/bellows/cc_wander_on.py` → `cc_wander_on.{json,res}` | the f144 step that collided with the loop seam dropped (steps every 16 f from 0); rebaked | applied |
| A11 | audio table (one-mouth rule) → view | `game/view/audio_director.gd` | one mouth: a new voice line within 2.5 s of the last cuts it (`VOICE_CUT_S`, `voice_cuts`); repeat guard kept | applied |
| A12 | anim-bellows-a/-b/-c, anim-hush-b, anim → R3 frozen audio | `tools/audio/clip_events.py` → `game/data/audio/clip_events.json`, `docs/review/s2-sound/clip_events.md` | the audio frame table regenerated from the 3D sidecars (`source.audio: own` rows, phase R3D; every row the reports listed: bit_warmup, bit_tea, st_suspicious, st_straighten_cravat, mg_comb_flourish, mg_cravat_tug, mg_walk_hum, mg_walk_scale, rx_dizzy_spin_a, cue_picture_bonk, bit_livid, loco_stomp, act_hunt, mg_peer_under_piano, loco_arrive, loco_skid, act_rummage, act_wheeze, st_yanked, rig_mid/high/low, freeze_5..8, act_warmup, loco_irked, cc_wander_on, act_fixup_mirror); the 2D tinker rows retired; one-mouth validation (`VOICE_CUT_MIN_F 8`); 156 rows; `gen_audio.py --check` PASS | applied |
| A13 | L12 one owner per sound | `game/data/audio/cues.json` | the `rig_start` pepper cue removed (the 3D `rig_achoo_ria` clip owns `pepper_shake`) | applied |
| A14 | night → hud | `game/data/ui/strings.json` | `stage_door.{g0_head_b, g0_head_scaled, night1_preview, night2_preview, wip_title, wip_text, wip_play, cast_turn}` | applied |
| A15 | D13 (lead) → sets lint | `game/tools/lint3d/set_lint.gd`, `game/tests/lint3d/test_set_lint.gd` | `negative_space` is a WARNING (value printed) for a room at the 5-live-prop cap — N02 hall only (`NEG_SPACE_EXEMPT`) + a fixture test | applied |
| A16 | brief §3.2 → night e2e | `game/tools/e2e/e2e_probe.gd`, `game/tools/e2e.gd`, `game/tools/e2e/e2e_scenarios.gd` | report fields `clips_played`, `c8`, `tag_flights`, `sneeze` (accent frame, punch-in zoom from the real camera, hit-stop, caption, bouffant, stool doubled/missing, landing box) + the strict checks | applied |
| A17 | tools-b → night e2e | `e2e_probe.gd` | report fields `viewport: [w, h]` and `bellows_window` (the HUD lint stops inferring them) | applied |
| A18 | content CI-P0 (D14 note) → art | `game/art/chars/figgis/_src/gen_figgis.py` → `figgis_point.svg`; `tools/art/hush/validate.py` | the point card/glove 3 px off the edge; the validator scoped to what the 3D build ships (Figgis R7 vinyl busts: `<desc>` allowed, ≤ 24 colours, bottom may touch; the Stalls) — `lint_all.sh --no-godot` green | applied |
| A19 | anim-bellows-a → sets | `game/data/house/house3d.json` `landings.kitchen.sink` | y 0.58 → 0.68: his slippers show over the basin front after the sneeze | applied |
| A20 | anim-bellows-a / D15 → view3d | `game/view3d/camera/gag_stager_3d.gd` | the gag approach takes the reaction clip's own `cam push` zoom (`clip_push3d`), so the sneeze wind-up pushes in at the wide shot | applied |
| A21 | content → integrate (§5.4) | `game/tools/lint/beat_lint.gd`, `run_lints.gd`, `tests/solver/test_lints.gd`, `tools/scripts/lint.sh` | the 2D clip-coverage check dropped with the 2D path (the 3D coverage stays); `lint.sh --strict` green | applied |
| A22 | rig → integrate | `game/tools/anim/capture.gd` | deleted (no user since `capture3d.gd`) — see the deletion list | applied |
| A23 | cast-hush → view3d | `character_view_3d.gd` (`carry_looks`), `game/tests/view3d/test_view3d_rules.gd` | Hush shows `CARRY_SQUEAKER / MAGNIFIER / KIPPER` (rig3d.json looks) for the items she carries, two hands at most | applied |
| A24 | anim-bellows-b #12 → view | `clip_map.gd` one-shot rows, `tests/view/test_clip_map.gd` | a frame-locked LOOP one-shot wraps (`fposmod`) when the sim holds it longer than the clip, instead of freezing on the last frame | applied |
| A25 | §5.4 follow-up | `game/scenes/night/night_warm.gd`, `tests/night/test_night_warm.gd` | the warm list's per-rig looks come from `rigs3d/<rig>/rig3d.json` (the 2D rig.json pages are gone) | applied |
| A27 | cast-hush (D12 note) → cast data | `tools/art3d/hush/{palette,build}.py` → `game/art3d/chars/hush/{hush,hush_head_b}.glb`, `palette_hush.png`, `game/data/rigs3d/hush/rig3d{,_head_b}.json` (tris) | her `pepper_pot` prop = the set's pot: white body `#F4F1EA`, dark cap `#2A2D36`, the squat belly; the holes end stays 0.215 m out of the fist (the clip's spout targets). Looked at in game: the red cap read as the honey lid and the white body as her glove; the snatched pot now reads as the shelf's pot | applied |
| A28 | clip_rules.json `flavour:skid` / `flavour:arrive` (3D rows) → view3d | `character_view_3d.gd` (`stop_flavour`), `tests/view3d/test_view3d_rules.gd` | Hush's run stop plays the skid and a walk's stop the small arrival settle — CharacterView3D had rows and clips but no trigger (found by the clip coverage below) | applied |
| A29 | brief §3.2 (every build3d clip played) → night e2e | `game/tools/e2e.gd`, `game/scenes/night/curtain_bows_3d.gd` (`current_clip`), `game/tools/e2e/e2e_probe.gd` (`play_from_frame`), `tools/scripts/e2e.sh` (`--fixed`) | `clips_played` sampled every frame of route AND flow runs (base + overlay + the curtain call's bows); a launch-clock scenario can run at a fixed 60 fps for frame strips | applied |
| A30 | brief §3.2 (a clip that cannot occur leaves the manifest) | `game/data/anim/clip_rules.json` `oneshot:fizzle` | `episodes` = the Nights after the Prologue: `bellows/st_smirk` (his fizzle "huh?") cannot occur in g0 / P00 — neither of their pranks (`achoo_ria`, `allegro_go_go`) has a fizzle | applied |
| A31 | brief §3.3 (the P00 picture strip) → view3d / sets | `game/view3d/world/cue_stager_3d.gd` (`picture_pose`), `game/view3d/set/{prop_3d,house_3d}.gd`, `game/view3d/world/greybox_set_3d.gd` (`lend(…, at)`), `tests/view3d/test_view3d_rules.gd` | the frame lent to `head_top` (A01) slid to an identity pose under his head bone: edge-on to the camera whenever he faces ±x, so it showed for 10 ticks and vanished. `lend` takes an end pose in the socket's space; the frame now lands face-on, askew 14° on the bouffant, rides his head's position (never its turns: `_hold_picture_on_head`) for 60 f, then slides down beside his feet (20 f) and goes in a puff of dust (`strips/p00_picture*.jpg`, re-shot) | applied |
| A32 | brief §3.2 (a clip that cannot occur leaves the manifest) | `game/view/world/slice_clips.gd`, `game/data/anim/clip_rules.json` (`bit:bit_livid` row), `tests/view/test_slice_clips.gd` | (1) the T3 last-beat pool is listed only where a reaction can START at T3 (the other pranks' gains reach Livid first: total − smallest ≥ 70); P00 (55 + 45) reaches Livid only after both pranks (walk@tier3 stays) — `beat_dignity_fail` / `beat_bow_topple` / `beat_tear` leave the g0+P00 manifest (N01/N02 keep them). (2) a `bit:<id>` row of its own overrides `bit:*` and its `episodes` drop the bit: `bit:bit_livid` `episodes: []` — the sim never plays `while_tier` bits (request Q01) | applied |
| A26 | brief §3.5 | the 2D path | `--view=2d` and every 2D branch removed; 2D files deleted after the reachability scan (`reachability.md`) | applied |

## 2. Closed upstream (landed by a B1 task or fix pass before this launch; checked on this tree)

| id | from → to | change | evidence |
|---|---|---|---|
| U01 | anim, anim-bellows-a/-b, anim-hush-b → rig | RigPlayer3D honours sidecar `gaze` on base and overlay clips (D8), PiP/off-screen fallback | `game/view3d/char/rig_gaze_3d.gd`, `tests/rig3d/test_gaze_3d.gd` (r3d-rig fix pass 1) |
| U02 | anim-bellows-b #4/#11, anim-bellows-c #3, anim-hush-b → rig | sheet3d: overlays sheeted over idle, `blend_in 0`, `--facing`, phone cells on the clip bounds; AnimViewer3D `--fixed-step` | `game/tools/anim3d/sheet3d.gd`, `scenes/dev/anim3d/anim_viewer_3d.gd` |
| U03 | anim-bellows-a, cast-bellows → rig | attachment palettes (the ride-along stool brown, set palette) | r3d-rig FIX PASS 21:38Z |
| U04 | rig ↔ view3d | Settings "Outline +50 %" one path (`StageLighting3D.set_outline_scale`) | r3d-rig report §5 |
| U05 | view3d → rig (D7) | `rig_def_3d.gd` default `outline_px` → `View3DConst.OUTLINE_CHAR_PX` | `rig_def_3d.gd:156` |
| U06 | view3d → rig | play() / advance spikes / set_look precompute / `prepare_all_clips` in warm() | r3d-rig perf pass 2 (play 69/84 µs) |
| U07 | view3d, night → sets | Prop3D beret tag on the Hush palette + prop ink, built hidden at setup | `game/view3d/set/prop_3d.gd:118–125, 454` |
| U08 | night → view3d | `stage_lighting_3d.gd` uses `ProjectSettings.has_setting` (no editor-only call, no engine ERROR) | `stage_lighting_3d.gd:188–190` |
| U09 | cast-hush → sets | HideSpot3D eye card from Hush's atlas cells (`eyes_dark_*`), discs only as fallback | `game/view3d/set/hide_spot_3d.gd:3–35` |
| U10 | view3d → cast-bellows | `bouffant_wet.glb` / `bouffant_floured.glb` exist | `game/art3d/chars/bellows/` |
| U11 | tools-b → sets | fridge stack gap (`hit_z_half` 0.12), parlour negative space 1.57 m, porch 1.60 m | r3d-sets FIX PASS 21:06Z; `house3d.json` |
| U12 | tools-b → view3d | C6 at 4:3 (honey / gramophone / front door), front door under Clarence at 16:9 | r3d-view3d FIX PASS 21:30Z (screen lint 0 errors) |
| U13 | tools-b → cast-hush | Hush L* ≥ 85 face share 0.246–0.275 in all 9 lit rooms | r3d-cast-hush FIX PASS 21:06Z |
| U14 | D11, anim-hush-b → sets | band staging data: `reach_pos` = placed reach target − band `reach_offset` (sink tap, clock, recliner, fridge shelf, …); the kettle's overlap cleared (dx −0.42, z −1.44; set3d test green) | r3d-sets fix pass; `verdict_staged.md` 3/3 |
| U15 | anim, cast-hush, sets → clips | `rig_achoo_ria` re-baked on the restaged jar with the pot pivot −0.16 (glove 0.041 m from the set pot on f7); `rig_allegro_go_go` / kettle drum on the z −1.30 stands; L10 / L14 clean | r3d-anim FIX PASS 21:50Z; `lint_anim 3d` 77 clips 0 errors |
| U16 | anim-bellows-c #1 → anim-bellows-a | bellows3d `map.json` rows `walk@tier3`, `activity:hunt`, `cue:laugh_doorframe`, `cue:laugh_picture` | `game/data/anim/bellows3d/map.json` |
| U17 | anim-hush-b → anim | hush3d `map.json` rows (flavours, fidgets, freeze_midjob, rummage, wheeze, shrug, yanked, freeze 1–8) | `game/data/anim/hush3d/map.json` |
| U18 | hud, view3d → night | NightScene wiring of HudModel R3D fields, OverlayCtx, WorldOverlays placer, `attach_pip`, edge badge, pause menu, `ScriptPanel.set_rule`; duck-typed `world_view` | r3d-night report; suite green |
| U19 | hud → view3d | Overlays3D captions / stamps / his bubble registered in the §2.5 placer | `overlays_3d.gd:44–47, 185–193` |
| U20 | tools-a → content | `lint_all.sh` runs `tools/art3d/review/test_review.py` | `tools/ci/lint_all.sh` |
| U21 | hud, cast-hush → cast-hush, anim-hush-b | `test_hush3d::test_props_sample_used_palette_cells`, `st_shrug` L15/L07 | suite 1510/0 at K3; lint_anim 0 errors |
| U22 | view3d, night → anim-* | every Gate-0 / Prologue clip authored (0 fallbacks per clip on g0 + P00) | baseline + this task's e2e reports |
| U23 | cast-bellows, view3d → cast-* | face cells ≥ 256 px (Hush 341 px; Bellows atlas v1) and D8 face beats turned to the camera | `verdict_face.md` 5/6, Hush faces 6/6 |
| U24 | tools-b, hud → lead | D9: the four always-on HUD pieces exempt from the middle-band rule; escalated window / BOW-under-window = warning ≤ 5 s | `issues.md` D9; HUD lint as built |
| U25 | content → content | door/stairs far-room rule kept (`SetList.local_live` mirrors it) | r3d-content NOTE 22:18Z |

## 3. Deferred to R3 (with the reason)

| id | from → to | file | change | reason |
|---|---|---|---|---|
| R01 | D15 round 2 (lead) | `tools/art3d/anim/bellows/act_tea.py` | a bigger pour stream, a held sip with steam, a longer lid-flip beat | ruled "accepted for the slice below the ≥ 3 bar"; owner-pack known weak spot (tea 2/2/2) |
| R02 | D12 v3 (lead) | `tools/art3d/anim/hush/act_snicker.py` | a more upright snicker (shoulders shaking, knees knocked) | ruled "W1 accepted at 12/13" (one-way snicker → reach low); owner-pack known weak spot |
| R03 | D15 queue (anim pass 2) | `tools/art3d/anim/hush/rig_high.py` | crank elbows straight over the head (gloves ≥ 0.15 m above the beret) | a band clip of the N1/N2 previews only (no Gate-0 / Prologue prank uses `rig_high`); D13: the slice's exit bar is Gate 0 + the Prologue |
| R04 | anim-hush-b view3d #5 | `character_view_3d.gd` | yaw her toward the container for `act_rummage` / `state:pick_window` | N1/N2 item pick-ups only (none in g0 / P00) |
| R05 | D13 (lead) | `game/data/house/house.json` N2 hall | re-space the hall hotspots (or move the MIRROR, MIRROR landing / drop a prank) + solver baseline + content retune | frozen C3 data; R3 brings N2 to final polish (warning printed by A15 until then) |
| R06 | anim-bellows-a → anim | `game/tools/anim/glb_to_res.gd` | a robust quaternion key-reduction metric | every clip would re-convert (size only, no visual change); r3d-anim's converter, not owned here; a ~MB-scale .res saving for R3 |
| R07 | anim-bellows-a → anim | `game/tools/anim/lint3d_limits.json` | mark name `jar_home` | no clip uses the mark yet (the brief's act_tea mark was not needed) |
| R08 | rig → cast-bellows | `tools/art3d/bellows/descriptor.py` | `deform_bones` 49 vs 57 weighted bones in `bellows.glb` | an informational budget count (no runtime effect); dropping the stray weights is a Blender re-export of the cast (R3 cast pass) |
| R09 | cast-bellows → rig | `game/view3d/char/rig_def_3d.gd:440` | the attachment budget warning counts the 4 exclusive bouffant variants | a false-alarm warning only (tests allow it); r3d-rig's file |
| R10 | D15 note (anim pass 2) → rig | `game/view3d/char/rig_mods_3d.gd` MODE_SOCKET | keep a clip's baked prop-bone scale (a held Clarence swelling) | r3d-rig's file; the squeak reads 12/13 without it (the body squash carries it) |
| R11 | anim-bellows-b #9 → cast-bellows | the Bellows face atlas | a one-eye wink cell | nice-to-have; the kettle wink reads as closed eyes + cocked brow |
| R12 | anim-bellows-b #7 → content | `mg_admire_in_kettle` `at_s` | move the micro-gag to a moment both gloves are free | content timing (frozen sim data for the slice); the clip is restaged to read face-on |
| R13 | tools-b, view3d (optional) → sets | `house3d.json` `hall_front_door.hit_box` y0 → ~0.6 m | lets the 16:9 hall frame at x 5.0 | optional; a screen-lint WARNING only, N01/N02 (the P00/g0 hall is backstage) |
| R14 | hud → view3d | `world_view_3d.gd` `protected_rects()` | cache the actor AABBs per frame | ~230 µs on its first call per frame (llvmpipe), below D14's 1 ms spike rule; no spike in the profiler's slowest frames |
| R15 | view3d → cast-bellows | the FRAZZLED bouffant | reads "bald with side puffs" at game scale | not in a Gate-0 / Prologue route (the gramophone/allegro look is N1+); R3 look pass |
| R16 | cast-hush | `rig_achoo_ria` re-bake at cheat ≤ 10 facing −x | her head partly covers the pot hand from the game camera | R5d forbids a larger turn while reaching (lead); with the matched pot (A27) the tilted pot shows over the jar between her glove and the lid (`pot/` check frames in the report) |
| R18 | anim → view3d | `character_view_3d.gd` honey floor spot (x 14.85) vs the stool seat (14.81–15.19) | her feet overlap the stool on f0 and f48 | the clip steps up onto the stool at f3–6 and down at f44–47 (`step.support`); looked at in the g0 frames: it reads as hopping on and off the stool |
| R17 | anim-bellows-b #10 → view3d | specs shown from the sim's `specs_on` on the one-shot's first tick | the clip slaps them on at f4 (0.07 s lead) | accepted (0.07 s, under the overlay's blend) |

## 3b. Requests this task makes (not its files)

| id | to | file | change | why |
|---|---|---|---|---|
| Q01 | sim owner (r3d-content / R3 sim) | `game/sim/systems/bits.gd` `on_squeak` | play `squeak_bits` entries with `while_tier: "livid"` (`bit_livid`, once per Night) while Bellows is Livid, then set `clip_rules.json` `bit:bit_livid` `episodes` back to `"all"` | GDD's 'WHO SQUEAKED?!' rage aria is authored (clip, voice, audio rows) but the sim only plays the current activity's own `squeak_bit` |
| Q02 | r3d-cast-bellows (R3 cast pass) | `game/art3d/chars/bellows/bellows.glb`, `tools/art3d/bellows/descriptor.py` | 5 → ≤ 4 draw calls, 57 → ≤ 50 deform bones, 10377 → ≤ 10k triangles | pre-gate row 17 (per-character budget) is red on Bellows; CPU 0.195 ms median is inside 0.25 ms |
| Q03 | sound owner (R3, frozen `game/audio/**`) | `game/audio/sfx_map.json` + `game/audio/sfx/` | add `sting_title_slam` (GDD §: the title card's `title_slam` sting) | `CurtainCall` calls `Audio.sting("title_slam")` at the P00 title (since Stage 2); the id has no file, so the slam is silent and the run logs `WARNING: Audio: unknown id 'sting_title_slam'` (the only warning of the `curtain_call` flow) |

## 4. Refused (with the reason)

| id | from → to | change | reason |
|---|---|---|---|
| X01 | r3d-cast-bellows #3 | ease the bare cheat to ≥ 45° for face beats | superseded by D8 (the runtime gaze turns the head to the camera; the cheat lint caps clips at 40) |
| X02 | r3d-rig → view3d | also call `look_at_point(camera, 1.0)` for gaze windows | r3d-rig: not needed (the gaze runtime does it); not added |
| X03 | r3d-view3d → lead | a negative `stage.cheat_deg` (turn ACHOO-RIA! toward the wall) | needs a lead exception to R5d (≤ 10° while reaching); none was given |

## 5. For the orchestrator (not a file this task may change)

| id | from | item | state |
|---|---|---|---|
| O01 | every R17 task | fresh-reviewer runs | **all verdicts are in**: cast-bellows `verdict_c35.md` 4/6 + `verdict_face.md` 5/6 (D8 face-turn passes); cast-hush 4/6 (B c35), 6/6 (B face, head_b c35, head_b face); anim verbs v3 12/13 (D12 accepted); anim-bellows-a r1/r2 (sneeze 4/4/3 PASS, tea 2/2/2 accepted, D15); anim-hush-b bands now 2/3, staged 3/3 (D11); tools-a example 3/3. The `index.md` "pending review" lines of r3d-anim, r3d-anim-bellows-a, r3d-anim-hush-b and r3d-cast-bellows are stale (their files; the verdict files sit beside them). |
| O02 | cast-*, sets (R13) | import settings (faces + portraits lossless + mipmaps; palettes lossless, nearest, no mipmaps) | done at K2 |
| O03 | hud, rig, anim | `.import` / `.uid` sidecars for the B1 files (Figgis busts, previews, `verb_freeze_quiet.svg`, verbs3d, rig_gaze_3d, …) | present on this tree (K2/K3 import); this task added no new asset; new script `tools/art/hush/build.py` is Python (no sidecar) |
| O04 | night | the O2 probe branch drops `view3d/probe/*` from `exclude_filter` if its APK needs the probe scene | note kept in `game/export_presets.cfg` |
| O05 | docs, hud, night, tools-b | GDD/TECH amendment text | in the report (§ GDD/TECH text for r3d-qa) |
| O06 | cast-hush | CREDITS: the Quaternius UAL1 skeleton (CC0) is vendored; no new third-party asset | no change |
| O07 | O1/O3 (owner) | Hush head B vs ×1.2 | unanswered → default B's head + the stage-door "head ×1.2" entry |
| O08 | O2 (owner) | perf-probe card | unanswered → render defaults stay `BootConfig.DEFAULTS`; the DeviceLog perf3d notes decide later (D14) |
| O09 | R15 (content, lead) | Bellows window default | `bellows_window: "sim"` kept (`d1_lean` fails the ⅓ edge-share cap on 7 of 9 routes) |

## 6. Checks of §3.1
- **Drafts:** no sidecar carries `lint.draft: true` (`grep '"draft": *true' game/data/anim/*3d/*.json` → none); nothing for the owner pack.
- **Named skips:** the Hush and Bellows clip tests (`tests/anim3d/test_hush_clips3d.gd`, `test_bellows_clips3d.gd`) run with 0 skips (suite: 0 skipped).
- **`clip_rules.json` `episodes`:** `oneshot:fizzle` (A30, `st_smirk`: no g0 / P00 prank has a fizzle) and `bit:bit_livid` (A32, the sim plays no `while_tier` bit); the T3 pool left the P00 manifest by the T3 reachability rule (A32). Every other clip of `SliceClips.build3d(["g0_sneeze","p00_curtain_up"])` was played across the route, flow and coverage replays (`clips_played`).
