# r3d-integrate: report (launch I, ran alone)

Everything the brief asks for is done, with one pre-gate row red: **row 17, Bellows' per-character budget** (owner r3d-cast-bellows). Row 8 (fuzz) is also only partly re-run on this tree. The 2D path is gone, and every Gate-0 and Prologue route and flow passes in 3D on the final code. N01 and N02 run in 3D with 0 errors. The full suite and both lints are green: 1262 passed, 0 failed, 0 skipped. Every clip in the g0 + P00 manifest was played (69/69). The APK went from 74.08 MB to 73.43 MB.

Writing a report file was refused ("Subagents should return findings as text"), so this answer is the report; please save it as `<SP>/reports/r3d-integrate.md`. The LANDED lines are in `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/r3d-integrate/LANDED.md`.

## 1. Request table
Full table: `/home/user/mischief/docs/review/r3d-integrate/requests.md`. No request is left without a status, and nothing was skipped.

| Status | Count | Notes |
|---|---|---|
| Applied by this task | 32 (A01–A32) | |
| Closed upstream | 25 (U01–U25) | Checked on this tree |
| Deferred to R3, with reason | 18 (R01–R18) | Includes tea D15 2/2/2, snicker D12 12/13, `rig_high` elbows, the N02 hall re-spacing (D13), frazzled bouffant, the honey floor spot |
| Refused, with reason | 3 (X01–X03) | |
| Orchestrator items | 9 (O01–O09) | All R17 reviewer verdicts are in. O1/O2 were unanswered, so the defaults stand: head B, `BootConfig.DEFAULTS`. R15 keeps `bellows_window: "sim"`. |
| New requests from this task | 3 (Q01–Q03) | Listed below |

Requests from this task to other owners:
- **Q01 (sim owner):** in `game/sim/systems/bits.gd` `on_squeak`, play squeak bits that have `while_tier: "livid"` (`bit_livid`). Then set `clip_rules.json` `bit:bit_livid` episodes back to `"all"`.
- **Q02 (r3d-cast-bellows, R3):** bring `bellows.glb` within the per-character budget: 5 → ≤ 4 draws, 57 → ≤ 50 deform bones, 10377 → ≤ 10k tris.
- **Q03 (sound owner, R3, frozen audio):** add `sting_title_slam` to `game/audio/sfx_map.json`. `CurtainCall` has called it since Stage 2, so the title slam is silent and logs `WARNING: Audio: unknown id 'sting_title_slam'`. This is the only warning in the `curtain_call` flow.

## 2. What I fixed, and where
**Data, rigs and clips**
- A02: Bellows' outline is 4.8 px, the same as Hush's (`rig3d.json`, `descriptor.py`).
- A09: `act_glance` turns her gaze to the camera; rebaked.
- A10: `cc_wander_on` dropped the f144 step that collided with the loop seam; rebaked.
- A12: the audio frame table is regenerated from the 3D sidecars (`clip_events.py` → `clip_events.json`, 156 rows), with one-mouth validation.
- A13: the pepper `rig_start` cue is removed, so the clip alone owns `pepper_shake`.
- A14: new `stage_door.*` strings.
- A19: the sink landing is raised (y 0.68).
- A27: Hush's pepper pot is now the set's pot: white body `#F4F1EA`, dark cap `#2A2D36`, squat belly. This touched `tools/art3d/hush/{palette,build}.py`, both head GLBs, `palette_hush.png` and the tri counts in `rig3d*.json`.
- A30 and A32: `clip_rules.json` gained a `oneshot:fizzle` episode list and a `bit:bit_livid` row with `episodes: []`.

**View (3D)**
- A01: the picture frame is lent to the `head_top` socket.
- A03: the lean edge badge is decided after the Bellows window reports whether he is on screen.
- A04: the squeak gaze leans toward the camera (D8).
- A05: overlays use their own sidecar mask first.
- A06: the statue plinth.
- A07: perf sampling moved out of the measured window.
- A08: `freeze_midjob` holds the frame of the band the rig was in.
- A20: the sneeze wind-up pushes in from the wide shot.
- A23: Hush shows her carry looks.
- A24: frame-locked looping one-shots wrap instead of freezing (`clip_map.gd`).
- A28: the run's skid stop and the walk's arrival settle now actually play (`stop_flavour`).
- **A31 (found in the 1200×540 strips):** the picture frame slid onto Bellows' head bone edge-on and vanished after about 10 ticks.
  - The set's `lend()` now takes an end pose, `at`.
  - `CueStager3D.picture_pose` places the frame face-on to the camera, tilted 14°.
  - `_hold_picture_on_head` keeps it following his head's position but never its turns, for 60 frames. It then slides down beside his feet and disappears in dust.

**Night, HUD and audio**
- A11: AudioDirector plays one voice line at a time (`VOICE_CUT_S` 2.5 s).
- A15: set-lint `negative_space` is a warning for the N02 hall (ruling D13).
- A16, A17 and A29: new e2e report fields:
  - `clips_played`, sampled every frame of route and flow runs, base and overlay clips plus the curtain-call bows (`CurtainBows3D.current_clip`).
  - `c8`, `tag_flights`, `sneeze`, `viewport`, `bellows_window`, `play_from_frame`, plus the strict checks.
  - `e2e.sh --fixed`.
- A25: NightWarm reads each rig's looks from `rig3d.json`.

**Manifest (A32)**
- `SliceClips.build3d` lists the T3 last-beat clips only where a reaction can start at T3: the other pranks' temper gains must reach Livid (70) before the last prank (total minus the smallest gain).
- The Prologue's two pranks (55 + 45) only reach Livid after both have landed, so walk@tier3 stays in the manifest and the T3 beats leave it.
- A clip_rules row for one specific `bit:<id>` can now drop that bit from a Night.

**Lints and tools (A18, A21, A22)**
- The Figgis point card sits 3 px off the edge.
- `validate.py` is scoped to what ships: the Figgis R7 busts and the Stalls.
- The 2D clip coverage check is removed.
- `capture.gd` is deleted.

## 3. Deletions (A26, §3.5)
- The reachability scan is in `/home/user/mischief/docs/review/r3d-integrate/reachability.md`:

  | Item | Count |
  |---|---|
  | Candidate files | 1006 |
  | Kept | 545 |
  | Deleted | 461, plus 76 tests |

  It was generated by `scan/gen_reach_md.py`.
- 537 files were deleted (936 counting `.import`/`.uid` sidecars), listed in `/home/user/mischief/docs/review/r3d-integrate/deleted_files.txt`:

  | Directory | Files | Contents |
  |---|---|---|
  | `game/art/chars` | 292 | Hush and Bellows 2D parts, `_mannequin` |
  | `game/tests/rig` | 62 | 2D rig tests |
  | `game/data/anim` | 44 | 2D clips and maps |
  | `game/art/house` | 20 | 2D room backdrops |
  | `game/view/rig` | 15 | |
  | `game/view/world` | 14 | |
  | `game/view/fx` | 12 | |
  | `game/tests/view` | 9 | |
  | `game/scenes/dev` | 9 | |
  | `game/tools/anim` | 7 | |
  | `game/data/rigs` | 7 | |
  | `tools/art/{bellows,hush,house}` | 32 | 2D art tools |
  | Smaller groups | 14 | 2D pip, camera, sandbox, tex helpers |

- `--view=2d` and every 2D code branch are gone.
- Every file that referenced the deleted ones was updated: tests, lints, `lint.sh`, `lint_all.sh` validators, `tools/art/hush/build.py` (output byte-identical), `build_all.py`, `lint_rects.py`.
- The tree diff is 1016 files changed, +2095 / −90438 lines.

## 4. Numbers (final code)
**Per route**

| Route | Result | Fallbacks | Errors | Window share | Longest window | C8 violations | Laughs by 60 s |
|---|---|---|---|---|---|---|---|
| g0_sneeze (strict) | PASS | 0 | 0 | 0.280 | 6.4 s | 0 / 1413 | 1 (one prank) |
| prologue_ideal (strict) | PASS | 0 | 0 | 0.301 | 2.5 s | 0 / 3572 | 7 |
| prologue_required (strict) | PASS | 0 | 0 | 0.383 (warning, R15) | 4.5 s | 0 / 4050 | 4 |
| prologue_slow (strict) | PASS | 0 | 0 | 0.333 | 3.2 s | 0 / 3713 | 7 |
| N01 ideal / required / slow | PASS | 34 / 18 / 18 (R3 backlog, info) | 0 | 0.17 / 0.33 / 0.31 | | 0 | |
| N02 ideal / required / slow | PASS | 60 / 22 / 24 (R3 backlog, info) | 0 | 0.20 / 0.16 / 0.15 | | 0 | |

- **slice_all:** 13/13 PASS, 0 errors, 0 doubled props, 0 puppets.
- **Slow route:** first laugh 4.3 s (limit 10 s), first prank 25.3 s (limit 30 s).
- **Laugh cues:** every cue is staged, and its crowd sound follows within 0.0–0.27 s (limit 0.3 s).
- **Repeated sounds:** no sound id plays twice within 100 ms.
- **The Script tag** flies to the Script pip (1/1 in g0, 2/2 in P00).
- **The sneeze (g0):** accent on f94, hit-stop 83 ms, caption ACHOO-RIA!, bouffant flipped, stool never doubled, landing inside the sink box at f112.
  - Zoom is 1.14 at the accent frame and peaks at 1.59. In P00 the zoom at the accent is 1.32–1.37.
- **Clip coverage:** 69/69 of `build3d(["g0_sneeze","p00_curtain_up"])` were played, gathered from 55 route, flow and coverage reports.
- **Perf (perf3d PASS, desktop proxy):**

  | | g0 | P00 |
  |---|---|---|
  | Draw calls p95 | 57 | 73 |
  | Triangles max | 68k | 93k |
  | Emitters | 4 | 4 |
  | Texture memory | 81 MB | 103 MB |
  | Shader compiles in PLAY | 0 | 0 |
  | View + HUD script ms p95 (limit 4.0) | 3.64 | 3.99 |

- **Rigs (median of 5 runs):**

  | Rig | CPU | Draws | Tris | Deform bones | Verdict |
  |---|---|---|---|---|---|
  | Hush | 0.152 ms | 2 | 9812 | 48 | OK |
  | Bellows | 0.195 ms | 5 | 10377 | 57 | Red |

- **APK:**
  - Old: 74.08 MB, 4225 entries (r3d at 19:39, before the deletion).
  - New: 73.43 MB, 3277 entries.
  - The deleted 2D files made up 988 entries and 1.71 MB compressed of the old APK. The net shrink is smaller because assets landed after 19:39.
  - `verify_android` OK.
  - `tests/`, `tools/`, `scenes/dev/`, `view3d/{sandbox,probe}/`, `ui/demo/` and `_src/` are absent.
  - `boot_config.json` reads `stage_door` / `3d` / `show_previews false` / `bellows_window sim`.
  - The export logs a pre-existing "No project icon" error (`project.godot` is the orchestrator's).

## 5. Pre-gate rows 1–18
| # | Result |
|---|---|
| 1 | OK: 1010 `.import`, 407 `.uid` |
| 2 | OK: 1262 passed, 0 failed, 0 skipped |
| 3 | OK: `lint.sh --strict` (content incl. 3D coverage of 72 clips, hotspot, IP; `lint_anim 3d` strict 0 errors) |
| 4 | OK: `lint_all --no-godot` |
| 5 | OK: 12/12 routes; baseline check shows 0 new failures; N01/N02 ideal ★★★ 116/118 applause, required ★ 44/59 |
| 6 | OK: ⏩ ideal ≤ 7.8 %, required ≤ 4.8 %, slow ≤ 5.9 %; worst gap 6.2 s; edge share ≤ 0.31; N02 first prank 19.4 s. The `d1_lean` FAIL lines are info only (lean mode does not ship, R15). |
| 7 | OK: `--auto` passes all three episodes; g0 ideal ends by `g0_done` |
| 8 | Partial: P00 800/800 (4 bots), N01 800/800, N02 random 200/200; the full `fuzz all` run hit its 2 h timeout before N02's other three bots. Sim inputs are unchanged versus HEAD. Owner r3d-qa (`pregate3d`). |
| 9 | OK with 1 warning: N02 hall negative space 0.68 m (D13, R3 to re-space) |
| 10 | OK with 1 warning: N02 hall clock under the window at 16:9 |
| 11 | OK with 1 warning: P00 required window share 38.3 % (R15, for the owner pack) |
| 12 | OK: C8 has 0 violations on every route |
| 13 | PASS |
| 14 | PASS (ideal, required, slow) |
| 15 | PASS |
| 16 | PASS |
| 17 | **Red: Bellows over the per-character budget** (5 draws, 57 deform bones, 10377 tris). His CPU is inside 0.25 ms. Hush passes. Owner r3d-cast-bellows (Q02, R08). |
| 18 | PASS: retry 548 ms; tap feedback; pause and focus behaviour; tap accuracy 20/20 on all 25 live hotspots with 0 neighbour hits; curtain call (g0 → Again, P00 → Night 1). The flow logs Q03's warning. |

## 6. Evidence (looked at, 1200×540)
`/home/user/mischief/docs/review/r3d-integrate/index.md` describes every artefact below. The folder is 21 MB.
- **Strips** in `strips/`: 58 pages covering 11 gags plus Gate 0, captions on (`<gag>.jpg`) and off (`<gag>_nocap.jpg`). They are JPEG q62 with half-scale cells to stay under the size cap. The picture strip was re-shot after A31.
- **Boards** in `boards/`: HUD, kitchen, tinker vs the pepper rig, PiP vs the window, and the ten reference moments.
- **3D reference frames** in `ref3d/`: 20 frames at the r3d-ref2d ticks, at 20:9 and 16:9.

## 7. Residual risks for the owner
- The tea routine reads as a routine, not a gag (D15, 2/2/2). The snicker vs reach-low reads 12/13 (D12).
- The N02 hall negative space is a warning only (D13).
- `act_warmup` sings two phrases per 8 s instead of one per 6 s (one-mouth rule).
- P00 *required* shows the Bellows window 38 % of PLAY.
- Bellows' rig is over budget (row 17).
- The 3D reference frames land 30–40 ticks after the seek, because the CPU proxy renders at about 70 ms per frame; the strips show the exact moments.
- The T3 last-beat clips and `bit_livid` occur only in N01/N02, and `bit_livid` only once Q01 is done.
- The stool is hidden off-screen for 22 samples after the landing.
- The sneeze zoom at the accent frame is 1.14 in g0 (peak 1.59).
- P00 view + HUD script time is 3.99 ms p95, right at the 4.0 ms limit on the proxy.
- The picture frame is set dressing, so on his head it reads as a muted mauve rectangle against the pink wall. An R3 ink pass would help.
- The title slam is silent (Q03).
- Bellows' 5 o'clock dead-air numbers and other N01/N02 fallbacks remain in the R3 backlog (info, R9).

## 8. Deviations
- The APK export used sandbox `r3d-integrate-shot` (the second of the two allowed sandboxes).
- Strips are JPEG q62 with half-scale cells to stay under the 25 MB folder cap.
- The `cov4` coverage replay "FAILs" its scenario checks by design: it is a freeze-coverage command list, not a route. It was used only for `clips_played`.

## 9. GDD / TECH text for r3d-qa
Paste each into the named section.

**TECH §5 (view): the 2D path is gone.**
"The game has one view: the 3D one (`game/view3d/**`, Node3D world + Camera3D + the 2D HUD). The Stage-2 2D view (`game/view/rig/**`, WorldView / CharacterView / RoomView / PropView, the 2D camera, PiP, FX, ViewSandbox, the 2D rig lints, the 2D rig / clip / art data) was deleted on `r3d` after a reachability scan (`docs/review/r3d-integrate/reachability.md`); `--view=2d` and `BootConfig.VIEWS` "2d" no longer exist (`VIEWS = ["3d"]`). Still shared with the 3D view from `game/view/`: `view_snapshot.gd`, `sim_driver.gd`, `audio_director.gd`, `haptics_director.gd`, `view_kit.gd`, `world/{clip_map,clip_rules,slice_clips,content_info,house_layout}.gd` (+ `default_maps/`), `camera/juice_clock.gd`, `stalls/**`, `tex/{hi_res_tex,tex_stats}.gd`, the 2D screen overlays `fx/{caption,stamp,thought_bubble,spot_meter,freeze_frame,wipe,entry_warning,fx_art}.gd` and `sandbox/fake_world.gd`. `main` keeps the 2D Gate-0 build."

**TECH §6 (audio): one mouth.**
"AudioDirector plays one voice line at a time: a new voice line within `VOICE_CUT_S` (2.5 s) of the last one cuts it (`Audio.stop_voice`, counted in `voice_cuts`). The audio frame table (`game/data/audio/clip_events.json`) is generated by `tools/audio/clip_events.py` from the 3D sidecars (`source.audio: "own"` → phase `R3D` rows); its validation rejects a voice line cut by the next before it sounded 8 frames (`VOICE_CUT_MIN_F`) and a sound owned by both a clip and a cue (L12). The 2D tinker rows are retired; the pepper `rig_start` cue is gone (the `rig_achoo_ria` clip owns `pepper_shake`)."

**TECH §5.x (ClipMap).**
"A frame-locked one-shot whose map row loops wraps (`fposmod`) when the sim holds it longer than the clip; a non-loop one-shot holds its last frame. `freeze_midjob` holds the frame of the band the rig was in (`ClipMap.midjob_frame`)."

**TECH §5.x (CharacterView3D).**
"An overlay plays with its sidecar `mask` (else `ClipRules.mask_of`). Hush's carry looks follow `snapshot.hush.carrying` (`CARRY_<ITEM>`, at most two). A stop after a run plays `flavour:skid`, after a walk `flavour:arrive` (`stop_flavour`). The statue plinth is built hidden at setup in the set shader's STONE. The squeak / noise gaze aims halfway between the noise and the camera (weight 0.7, D8). The gag approach takes the reaction clip's own `cam push` zoom."

**TECH §5.x (set hand-offs).**
"`House3D.lend(id, socket, frames, at := Transform3D.IDENTITY)` (and `Prop3D.lend`) ends at `at` in the socket's space. The `laugh_picture` frame passes `CueStager3D.picture_pose(...)`: face-on, 14° askew on Bellows' bouffant; for 60 f it follows his head's position but never its turns, then slides down beside his feet (20 f) and is gone in dust."

**TECH §5.3 / §7.10 (SliceClips.build3d).**
"The T3 last-beat pool is listed only when a reaction can start at T3 (total temper gain minus the smallest ≥ 70); the Prologue reaches Livid only after both pranks (walk@tier3 listed, the T3 beats not). A `clip_rules.json` row for exactly `bit:<id>` overrides `bit:*` and its `episodes` drop that bit (`bit:bit_livid`: `[]` until the sim plays `while_tier` bits)."

**TECH §10.5 (lints).**
"`lint.sh` runs content / hotspot / IP and the 3D anim lint (full + g0/p00 `--strict`); the 2D anim / rig lints and the 2D clip coverage went with the 2D path. Set-lint `negative_space` is a WARNING for a room at the 5-live-prop cap (the N02 hall, D13). `lint_all.sh` runs `tools/art/house/{validate_svg,lint_rects}.py` (no 2D room backdrops) and `tools/art/hush/validate.py` (Figgis R7 busts + the Stalls)."

**TECH §11 (e2e report).**
"New fields: `clips_played` (base + overlay + the curtain-call bows; route and flow runs), `c8`, `tag_flights`, `sneeze` {accent_frame, zoom_at_accent, zoom_max, hitstop_us, captions, bouffant_after, stool_doubled, stool_missing, land_frame, land_in_box, land_pelvis}, `viewport`, `bellows_window`, `play_from_frame`. `--strict` adds the C8 and sneeze checks. `e2e.sh --fixed` runs a launch-clock scenario at a fixed 60 fps."

**GDD §9 (art).**
"Hush's held pepper pot is the set's pot (white body, dark cap, squat belly)."

**GDD §9.5 (voice), deviation kept.**
"`act_warmup` sings two phrases per 8 s (one mouth)."

**GDD, known weak spots for the owner pack.**
Tea (D15, 2/2/2); snicker vs reach-low at 64 px (D12, 12/13); the N02 hall's negative space (D13); P00 required window 38 % (R15); the silent title slam (Q03).

## 10. Hours
23:51Z → 05:30Z, about 5.6 h.

## Files
- `/home/user/mischief/docs/review/r3d-integrate/index.md`
- `/home/user/mischief/docs/review/r3d-integrate/requests.md`
- `/home/user/mischief/docs/review/r3d-integrate/reachability.md`
- `/home/user/mischief/docs/review/r3d-integrate/deleted_files.txt`
- `/home/user/mischief/docs/review/r3d-integrate/strips/`
- `/home/user/mischief/docs/review/r3d-integrate/boards/`
- `/home/user/mischief/docs/review/r3d-integrate/ref3d/`
- `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/r3d-integrate/LANDED.md`
- `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/r3d-integrate/gate/` (all logs and the e2e, flow, lint and perf reports)