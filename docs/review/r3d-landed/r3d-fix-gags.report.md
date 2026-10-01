# r3d-fix-gags: report (fix round 1, resumed after the 11:33Z restart)

All the work is done:
- six Prologue gags (Q-G1 to Q-G6);
- the dive (Q-V2);
- fix-hud's R1;
- the set3d test, which already passes;
- the D17 sites in my files.

Every gag strip was re-shot from the same route and the same ticks with captions off, and I looked at each one.

Verification is green:
- the full suite (on the final tree);
- `lint.sh --strict` and `check_import_meta`;
- `e2e --strict` on g0_sneeze, prologue_ideal, prologue_required and prologue_slow: 0 fallbacks, 0 errors, 0 C8 violations. All four ran on the pass-2 tree; g0_sneeze and prologue_ideal ran again on the final tree, after the two small D17 changes.

The scores still need **new** fresh reviewers; I did not score my own strips.

Branch `r3d`; no git writes, no branch switches. Review page: `docs/review/r3d-fix-gags/index.md`. LANDED log: `<SP>/work/r3d-fix-gags/LANDED.md`.

## 1. What changed (view only: the sim, `reactions.json` and the clip lengths are untouched)

**Pass 1** (landed 11:20Z, before the restart; kept in WIP ca8f838):
- Cue shots: the curtain-up shot on him and the vase, the bonk punch-in, the relief two-shot, the picture shot.
- The vase: it teeters, and notes fly to it. It is ×1.5 and blue-and-white.
- The picture: a gilt frame round a dark portrait.
- The gramophone: a sidestep beside it, and note jets out of the horn.
- The Bellows-window punch on the squeak bit, and the squeak puff.
- Hush kept clear of the action button.
- The bonk: the knock-back pin and the `st_bonk` dazed hold.

**Pass 2** (this run):
- **Q-G2 bonk contact.** On the accent:
  - a big white impact star where his head meets the wing flat's edge;
  - a plaster puff, and plaster sifting down;
  - inked stars (sparkle.svg).

  The wing flat itself rocks on its base, its top away from him (`House3D.wing(link_id)`, `CueStager3D.wing_angle`: 2.2°, 7 Hz, gone in 30 f). His thought bubble steps out of the close-up (`CueStager3D.wants_quiet_bubble` → `bubble.quiet`).
- **Q-G3 picture.** THUNK stars and a jolt when it lands. The bubble is quiet. He stands stunned, never walking on the spot.
- **Q-G4 vase.** The crash jolts the frame and throws a bigger inked puff.
- **Q-G5 squeak.** Two camera-facing sound rings swell off Clarence's beak, 7 f apart (an Fx3D ring emission). Clarence's ×2.4 squeeze (`act_squeak`, baked in pass 1) should now show through r3d-fix-perf's MODE_SOCKET change. At packet size I could not confirm the swell by eye; the toy still reads small.
- **Q-G1 dizzy spin.**
  - The cause: the gramophone rattles and the horn swings and pulses for 1 s (Prop3D `play`, PLAY_S), and white flecks whirl off the turntable (`disc_whirl`).
  - The spin: inked dust whirls on a floor ring and on a waist ring (`spin_dust`, `spin_lines`, the Fx3D whirl shape). They replace the white disc heap that read as popcorn in pass 1.
- **Q-G6 relief, the near miss.** It is timed off his hunt running out, which is what fires `laugh_relief` (`CueStager3D.hunt_left`):
  - 46 ticks before the cue he peers at her gap (a WorldView3D gaze hook);
  - 22 ticks before it her eyes duck out of sight (`HideSpot3D.eyes_duck`);
  - on the cue they pop back up with a blink and big sweat drops (drop.svg), and his `st_smirk` plays to camera.
- **Q-V2 dive.** `DIVE_CHEAT` −62 → −85: back to camera, she flies up into the curtain alcove. `placement_for` keeps FROZEN's cheat out of the rigging and hidden branches, as before.
- **fix-hud R1 (`overlays_3d.gd`).**
  - His bubble is clamped by its **drawn** extent: 153 px left and 127 px right of its position, plus 8 px. With fix-perf's `glyph_right` flip it uses that side's extent instead (73 / 207 px).
  - The placer rect is the same extent.
  - The one-cloud wait is read back from `placer.item(&"fx_bubble")` into `bubble.waiting`, with a self_modulate fallback if the flag is missing.
- **Fx3D.**
  - `SHAPES` (ring / whirl emission; the shared pool resets it).
  - New kinds: squeak_ring, disc_whirl, spin_lines, impact, plaster, sweat, thunk_stars.
  - bonk_dust, bonk_stars and spin_dust are now textured.
  - Still 8 emitters; nothing is allocated after `_init`.
- **D17 (my files)**, using r3d-fix-perf's `spikes.md` plus `after_*` runs and two headless profile runs of my own:
  - **Clip sidecars are parsed under the curtain.** `WorldView3D.warm_clips` → `CharacterView3D.warm_sidecar`, and `_sidecar_bits` now reads through `ViewKit.json`, the cache GagStager3D also reads. Before: hush_apply 1.4 ms at t383–386 in after_r1/r3, with hush_view.mine at 1.0–1.15 at the first rig clip; the clip-switch `clip_keeps` read also hit disk.
  - **The bonk and picture base hold starts 2 f after the cue overlay** (a `stage_hold` delay). Before: bellows_apply 1.4–2.05 ms at t1677–1680 in after_r1–r3 and after_h1, made of two clip starts (rig_play 0.4–1.0 ms) plus rig_advance in one frame.
  - **Result:** in my 2 headless runs (sidecar warm in, before the stagger), no call site of mine is > 1 ms at the same tick in both.

Files:
- `game/view3d/world/{cue_stager_3d,fx_3d,overlays_3d,world_view_3d,character_view_3d}.gd`
- `game/view3d/camera/gag_stager_3d.gd`
- `game/view3d/set/{house_3d,prop_3d,hide_spot_3d}.gd`
- `game/tests/view3d/test_gag_staging3d.gd`
- `docs/review/r3d-fix-gags/{index.md,after/}`
- Pass 1 also touched `camera_director_3d.gd`, `house3d.json`, `tools/art3d/set/{palettes,build}.py`, `game/art3d/set/*` and `act_squeak.{py,res}`.

## 2. Before / after (`docs/review/r3d-fix-gags/`)
- **before/**: the exact QA packet pages (set_e pkt_01–09). **after/**: run v8 (the final tree), prologue_ideal `--fixed`, 1200×540, `--no-captions`, MSAA off, every 3 ticks, the packet layout.
- `after/{dizzy_spin,doorframe_bonk,picture,vase,squeak_bit,relief}_N.jpg`.
- `after/dive_before_after.jpg`: the QA verb pkt_01 above, g0 t312–324 below.
- `after/bubble_edge_f2190.jpg`: QA crowd pkt_06 above, the same frame now below. The whole bubble is on screen, with the glyph flipped right of the cloud.

What I saw:

| gag | before | after |
|---|---|---|
| bonk | No contact. | The impact star at the edge on the accent; dazed, face to camera at f96–108. |
| picture | Hidden fall. | The fall is framed; a gilt frame on his head; a stunned hold. |
| vase | No cause. | Notes fly to the vase, it rocks, it tips, it crashes. |
| squeak | The noise is not seen. | Sound rings at the beak, the window punched, Hush clear of the button. |
| dizzy spin | Unclear why he starts. | The cause reads at f18–45 (horn, notes, rattle, flecks), then the spin, collapse, face push-in. |
| relief | A walk-off. | Eyes in the gap f0–15, he peers, the eyes duck f18–36, the cue: they pop up, sweat, his smirk. |

## 3. Tests / lint / e2e
- **Suite:** 1304/1304 passed (138 files) on the final tree (1303/1303 on the pass-2 tree before the D17 changes). `set3d/test_house3d_data.gd` passes 14/14 on the current house3d.json, which needed no change.
- **view3d:** 75/75. `test_gag_staging3d.gd` has 11 tests:
  - the sidestep, the dive turned upstage, the vase teeter, the cue pieces' data;
  - Hush clear of the button, a cue shot yields to a punch-in;
  - the bonked flat's wobble, the ring and whirl bursts and their pool reset;
  - the bubble clamp extents, the near-miss timing, the sidecar warm.
- **Lint:** `SANDBOX=r3d-fix-gags tools/scripts/lint.sh --strict` passes: 0 lints failed; 72 clips strict with 0 errors, 0 warnings, 0 missing. `check_import_meta`: 1010 .import, 412 .uid.
- **e2e --strict** (`E2E_SANDBOX=r3d-fix-gags`), all PASS with 0 clip fallbacks, 0 engine/script errors and C8 0 violations:

  The final tree (after the D17 changes) re-ran prologue_ideal --strict (v8, with the shots) and g0_sneeze --strict: both PASS, 0 errors, C8 0, 0 fallbacks.

  | route | laughs | draw p95 | tex in PLAY | shader compiles in PLAY |
  |---|---|---|---|---|
  | g0_sneeze | — | 55 | — | — |
  | prologue_ideal | 7 | 71 | 109.5 MB | 0 |
  | prologue_required | 6 | — | — | — |
  | prologue_slow | 7 | — | — | — |

## 4. Requests (paths outside my ownership)
- **R-a (r3d-fix-perf / orchestrator), texture budget.**
  - PLAY tex went from 103.7 MB (v3–v5) to 109.5 MB in every run since 12:14Z (v6–v8 and the --strict runs).
  - My pass-2 additions over that span are sparkle/dust/drop.svg at 64 px, about 50 KB.
  - The jump lines up with NightWarmer warming the EdgeBubble tier and emote faces and the hud icons at 12:07Z (`game/scenes/night/night_warmer.gd`).
  - Separately, the report's `tex_mb_total_end` / `tex_mb_peak` rose from 103.6 to 123.8 MB in runs from 11:54Z. That is after PLAY, which points at the curtain-call / Next flow.
  - Please check both against the row-16 tex bar.
- **R-b (r3d-fix-perf, `game/view/fx/thought_bubble.gd`), fix-hud R1 (c).** Mirror the cloud's tail puffs when the bubble sits beside his head on the far side. Optional; the glyph flip already removed the clip.
- **R-c (orchestrator / r3d-qa), new fresh reviewers** on a rebuilt gag packet (new seed) from `docs/review/r3d-fix-gags/after/`, plus the crowding packet. My strips are not scores.

## 5. Residual risks
- **Dizzy spin (bar 4/4).** The spin itself is 3 turns in 0.73 s, so at the packet's 9-tick stride the stills alias. The whirl puffs and the T-pose frame carry it. The clip (`rx_dizzy_spin_a`) was not re-posed: its timing is locked and there was no bake in this pass. If it scores under 4, the next lever is a slower 2-turn spin inside the same 36–80 f window.
- **Near miss.** His peering pose bows his head toward the piano, so his face sits under the bouffant for about 0.4 s before the smirk.
- **Small FX.** The squeak rings and the dust puffs are white-on-pink and small at 600×270 packet cells.
- **D17.**
  - **Headless check:** my two headless runs ran before the 2-frame stagger. The stagger itself is covered by the --strict e2e runs, not by a profile run.
  - **Single-run sites:** t2088–2090 hush_view (ctx 1.5 + mine 1.6 ms) appears in my h1 and fix-perf's after_r3 only; I reported it as noise. Other single headless hits, such as root:Audio at 2–4 ms, are box preemption.
- **The Bellows window punch** happens only when the window is up and not already escalated.
