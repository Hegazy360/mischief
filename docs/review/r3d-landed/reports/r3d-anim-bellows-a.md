# r3d-anim-bellows-a — report

Horace Bellows' 12 Gate-0 3D clips (all FINAL, no drafts), the shared Bellows `_lib`, `bellows3d/map.json` and the
42-clip Bellows test. Branch r3d, no git writes (the orchestrator commits). Time box 14 h, started 18:02Z; @@HOURS@@.

## Clips (all lint `--strict` clean, in game/, DONE lines in LANDED.md)

| clip | frames | kind | source | .res KB | hours |
|---|---|---|---|---|---|
| `rx_sneeze_blast_a` | 165, lock sim | base, reaction (FINAL, first) | keyed + IK/customs, staged st_tea (x 15.0, z −1.4, facing −1, cheat 35); audio table | 120 | 1.4 |
| `loco_idle` | 240 loop | base | keyed + IK (gloves on the barrel), finger drum, runtime glance | 159 | 0.3 |
| `loco_strut` | 32 loop, 1.2 m/s, stride 0.64 | base | `_lib` Gait (heel–ball roll, auto-plant); audio table | 43 | 0.35 |
| `act_tea` | 480 loop | base, activity (FINAL) | keyed + IK customs, staged st_tea; kettle / honey lend-return, lid_flip; f420 = THE SIP = the sneeze f0; audio table | 230 | 0.9 |
| `act_warmup` | 480 loop | base, activity (FINAL) | keyed + baton-tip IK on the record, staged st_gramophone; audio **own** | 239 | 0.4 |
| `loco_blind_shuffle` | 24 loop, 1.2 m/s | base (walk@blind) | Gait + groping keys; audio table | 38 | 0.15 |
| `cc_wander_on` | 144 | base, curtain call | Gait + look-round keys; audio **own** | 93 | 0.15 |
| `st_bonk` | 60 | base, oneshot:stun | keyed pop + stars; audio table | 53 | 0.15 |
| `beat_slow_burn` | 70 | base, last beat / curtain call | keyed, facing-proof; audio table | 43 | 0.15 |
| `loco_turn` | 8 | base | keyed | 25 | 0.05 |
| `loco_irked` | 28 loop, 1.32 m/s, stride 0.616 | base (walk@tier2) | Gait + fists; audio **own** | 34 | 0.1 |
| `act_fixup_mirror` | 240 loop | base, activity | keyed + comb-tip IK along the hair, staged st_hall_mirror (x 4.76, facing +1); audio **own** | 111 | 0.3 |

Set total ≈ 1.19 MB (≤ 10 MB); largest 239 KB (≤ 250 KB). Shared work (`_lib`, test, map, review, D8 pass, fixes): ≈ @@SHARED@@ h.

## Files (all inside §2)
- `tools/art3d/anim/bellows/_lib/{__init__,presets}.py` — the shared Bellows presets (read-only for -b/-c).
- `tools/art3d/anim/bellows/<clip>.py` ×12 → `game/art3d/anim/bellows/<clip>.res` + `game/data/anim/bellows3d/<clip>.json`.
- `game/data/anim/bellows3d/map.json` — idle, walk, walk@tier2 / @tier3 / @blind, turn, activity:tea / warmup /
  fixup_mirror / hunt / curious, oneshot:stun / head_turn / specs_on / doorway_pause / look_back / bump_look /
  curious_stop / curious_look / fizzle, state:spotted, bit:*, mg:*, cue:laugh_doorframe / laugh_picture, reaction
  (`<from sim>`), reaction_fallback. -b and -c rows added from their DONE lines (the same ids as
  `view/world/default_maps/bellows.json`; curtain:* are clip_rules rows, not map keys — not in the ClipMap schema).
  Walk rows carry `stride_m` / `speed_m_s` (the sidecar values) and `stride_px` / `speed_px_s` (1 m = 200 px).
- `game/tests/anim3d/test_bellows_clips3d.gd` — 9 tests over all 42 Bellows clips (owners -a/-b/-c; a missing clip is
  a named skip with its owner): manifest ⊆ lists; every clip made; lengths vs `SliceClips.build3d` + ClipLib3D
  problems; lint strict; no `arm_out` in `source.layers`; map keys = schema keys and resolve (family patterns
  `bellows/{id}` skipped), walk 240 px/s = 1.2 m/s = the strut's sidecar; the sneeze (accent 94 + face swap, cam punch
  1.4, hitstop 5, the puff, stool decor hidden + ride-along stool shown at 95, the bouffant look, no clip laugh); tea
  (480 f, lid_flip on the spoon contact, lend/return pairs balanced and home by the end); THE SIP continuity (UAL
  bones ≤ 1.5° between act_tea f420 and the sneeze f0).
- `docs/review/r3d-anim-bellows-a/` (24 MB ≤ 25): `sneeze_strip.png` (+ `_2`), `sneeze.gif` + `sneeze_mute.gif`
  (3.4 MB each), `tea_strip.png` (+ `_2`), `sheets/` (12 clips × contact / onion / curves / sil64 / phone / lint),
  `rubric.md`, `index.md`, `packets/` + `reviewer_prompt.md`.

## APIs / contracts others use (`from _lib.presets import *`)
- Staging: `tea_stage()` (TEA_X 15.0, TEA_Z −1.4, facing −1, cheat 35), `SEAT_H` 0.55, `seat(c, f0, f1)` (the barrel's
  `seat` socket on the stool; add before IK).
- Poses (armature axes; the pipeline adds `arm_out` — never key it): `glove / gloves / fist / grip / pinkie_up /
  open_hand`, `ARMS_DOWN / POMPOUS / FLUNG / ON_KNEES`, `POLE_R / POLE_L`, `STAND / SIT / LEGS_UP`, `dangle()`,
  `lean()`, `head()`, `pompous()`, `breath()`, `finger_drum()`, `tremble()`; `Gait(L, speed, …).apply(c, …)`.
- Placement: `place_bone`, `blend_place`, `rigid`, `arm_ik`, `place_prop` (a lent set piece's base on the prop bone,
  up = the bone); `smooth / ramp / window / track`; `qx / qy / qz`.
- Tea: `TeaSet` (cup / saucer / spoon rest points, `place_cup / place_saucer / place_spoon`), `SIP_BODY`, `sip_arms()`
  (THE SIP: act_tea f420 = the sneeze f0), `CUP_BELLY`, `SAUCER_BELLY / SAUCER_CHIN`, glove orientations `SIP_R`,
  `CUP_LOW_R`, `SAUCER_L`, `KETTLE_R`, `JAR_L`; `POLE_SIP_R` (new: the sipping elbow).
- New for D8 / FX: `face_to(pose, point, weight)`, `face_cam(c, f0, f1, weight, ease, target)` (yaw-only face to the
  stage camera on staged clips; add before IK that follows the head; pair with `c.look_camera` for the runtime),
  `fx_off(c, keep=())` (FX bones the clip never shows held at scale 0 every frame), `fx_hidden()`, `stars()`, `notes()`.
- Sidecar facts the view relies on: the sneeze `stage` {x 15.0, z −1.4, facing −1, cheat 35}; events at f94 (mark
  accent, hitstop 5, cam punch 1.4 in 11 / hold 90 / out 21 / yaw 5, shake 0.55, fx choo_puff, look bouffant flipped,
  teacup + saucer launch, jiggle), f95 decor kitchen_stool hidden + prop stool shown, f112 knock_on, f128 stool hidden,
  f158 decor stool back, f165 release; cam push 1.15 at f4 over 70 f. act_tea: lend set:kitchen_kettle grip_r f14 /
  return f78, lend set:kitchen_honey grip_l f104 / return f148, spoon shown 108–250, set_anim kitchen_honey lid_flip
  f126. act_warmup: set_anim parlour_gramophone play f24 (ALLEGRO-GO-GO! trigger f30; -c's dizzy spin starts from
  act_warmup's f30 pose).

## Verification
@@VERIFY@@

## What changed after the first landing (the review pass)
- **D8 (lead note 19:20Z): faces to the camera on every face beat.** Staged clips bake a yaw-only turn of spine_02 /
  spine_03 / neck / head to the stage camera (`face_cam`) + carry the sidecar gaze: the sneeze build (1.0), CHOO (0.8,
  the puff now blasts forward along his front instead of hiding the face), the flight (0.45), the sink (a full look,
  and he sits up in the basin); act_tea's face beats (THE SIP at 1.0 in both clips); act_warmup's singing (40–456);
  act_fixup_mirror's smug glance and kiss (before: the back of his head). Facing-proof clips keep only the runtime gaze
  and their keyed head yaw ≤ 6° (the rig yaws with facing, so a baked turn toward the camera turns away in the other
  facing): loco_idle's glance, beat_slow_burn's stare (was a 26° keyed turn — away from the camera at facing +1),
  st_bonk, cc_wander_on (0.6, still gazing up).
- **FX left up by overlays:** every clip now holds the FX bones it never shows at scale 0 (`fx_off`); in the g0 capture
  -b's `mg_walk_hum` notes stayed over his head through act_tea and the sneeze build (the player keeps a bone's last
  scale when the base clip has no track for it).
- `sip_arms`: the right elbow's pole blends to `POLE_SIP_R` at the lips (the IK flipped at f92 of the sneeze once the
  head turned to the camera). act_tea: two held left-glove joints nudged 0.5° (their constant tracks defeated the
  converter's key reduction: 250.6 KB → 230 KB). act_fixup_mirror: the mirror look now runs before the comb / pat IK
  (the comb rode a head pose the look then moved).

## Deviations
- `act_warmup` is a 480 f (8 s) loop with audio **"own"**: the 2D audio row is 1200 f (two phrases); re-timed into one
  8 s loop (vo_bellows_warmup_1 f40, _3 f250, vase_nudge 45–86 / 254–278, sync false). r3d-integrate needs the row.
- Audio "own" (no table row) also for `loco_irked` (bellows_step 0 / 14), `cc_wander_on` (bellows_step every 16 f),
  `act_fixup_mirror` (vo_bellows_hum 40 / 152) — the lint's L24 lines list them for r3d-integrate.
- The sneeze has no clip `laugh` event: the laugh is the director's event-level reaction laugh (the test asserts
  none in the clip), although the brief lists "laugh after the hold starts" for the sink.
- The sneeze's sink: he sits up in the basin (pelvis −40° instead of lying back −56°) so the dazed face (under the
  flipped bouffant, by design) reads over the basin front with D8's look.
- The tea choreography: the saucer rests on his belly as a shelf 98–166 while the left palm holds the lent honey jar
  (104–148) and the right glove holds the spoon (108–250); the kettle pours from the right glove 40–72.

## Requests
- **r3d-rig** — `RigPlayer3D` / `ClipDef3D`: honour the sidecar `gaze` [{f0, f1, at: "camera", weight, blend}]
  (look_at_point toward the active camera). Nothing reads it yet (r3d-anim asked too); every facing-proof face beat
  (idle glance, slow burn, bonk, wander-on, and -b/-c's) depends on it for D8.
- **r3d-rig** — `game/tools/anim/glb_to_res.gd` key reduction: `Quaternion.angle_to` in float32 is ill-conditioned
  for near-identical values (acos(2d²−1) with d = 0.99999994 ≈ 0.04° > ROT_EPS 0.001°), so constant tracks keep
  ~480 identical keys depending on the value (`ball_l` in every Bellows clip; act_tea had two finger joints at 476).
  Use a robust metric (2·atan2(|q−p|, |q+p|) after the sign fix, or 1 − |dot| < 1e-9): most .res files would shrink a lot.
- **r3d-view3d** — the sneeze in the sink: the punch-in framing clamps him at the right edge of the screen (engine
  f150–199 in `sneeze_strip_2.png`); centre the hold on the landing (or relax the C2 clamp during a reaction hold).
- **r3d-cast-bellows / r3d-rig** — the ride-along `stool` attachment (on bone `ride`) renders pink/salmon; the set's
  kitchen stool is brown, so it reads as a different stool when it swaps in at f95 (use the set palette).
- **r3d-sets** — `landings.kitchen.sink` y 0.58 puts his feet at ≈ 1.09 m against the basin front's 1.05 m: raise the
  landing ≈ 0.1 m or lower the basin front so the slippers-up gag shows.
- **r3d-anim** — `lint3d_limits.json` mark_names: add `"jar_home"` (the brief's act_tea mark; unused until then).
- **r3d-integrate** — audio rows for the "own" clips above (act_warmup's 480 f re-time, loco_irked, cc_wander_on,
  act_fixup_mirror).
- **r3d-anim-bellows-b** — `mg_admire_in_kettle` turns his head away from the camera over act_tea f~124–136 (the back
  of the bouffant to the Stalls in the g0 capture); and rebake `bit_tea` / `mg_pinkie_up` after the `sip_arms` pole
  change (their next bake picks it up; it now matches act_tea's sip).
- **orchestrator (R17)** — run a fresh reviewer on `docs/review/r3d-anim-bellows-a/packets/prompt.md` (mute, the
  sneeze + the tea); scoring in `reviewer_prompt.md`. The rubric acceptance line is pending that review.
- Resolved since the first landing (no longer requested): GagStager3D now plays the clip's `cam push`; CharacterView3D
  eases him out of the landing (LANDING_EXIT_M_S) instead of popping out of the sink.

## Known gaps
- The facing-proof face beats (idle glance, slow burn stare, bonk, wander-on) turn to the camera only once r3d-rig
  reads the sidecar gaze; until then they sit at the view's 35° cheat.
- The rubric is self-scored (sneeze 4 / 4 / 4, every other clip ≥ 3); the fresh-reviewer packet is pending.
- In the sink the flipped bouffant covers his eyes (the residue gag by design); the dazed face reads by the nose and
  the mouth only.
