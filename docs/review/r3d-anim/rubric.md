# r3d-anim — TECH §11 rubric per clip (author's pass)

All 17 clips of the list are made, FINAL (R19: no drafts) and lint `--strict` clean, so the machine-checkable rubric
questions — sliding (L12, lane space), floor penetration (L13), sounds off their contact (L14), face swaps off the
accent (L15), > 45°/f jumps off a declared pop (L10), dead holds (L09), mirror twinning (L11), root travel (L27), the
rig rules (L26/L28) — are answered *yes* by the lint for every clip. This is the **author's own pass** on the rest,
written from `sheets/<clip>_contact.png` (cells every 3 f), `sheets/<clip>_phone.jpg` (the 1200×540 framing), the
in-set frames (`achoo_kitchen.jpg`, `achoo_kitchen_pot.jpg`, `allegro_parlour.jpg`, `gate0_path.jpg`) and the sidecars.
A fresh reviewer's pass (R17) has not run — `reviewer_prompt.md` (the 64 px verb test) is pending. Scores 1–5 on
*funny / readable / fresh*; "readable" is judged at game scale (Hush ≈ 150 px tall at 1200×540).

| clip | silhouette at phone size | anticipation → accent (≤ 4 f) → hold ≥ 30 f where the face reads | one overshoot / sfx on contact / face on the accent | fresh vs. last time | F / R / Fr |
|---|---|---|---|---|---|
| `loco_idle` (loop 240) | the contrapposto + glove on the hip reads; Clarence's peek (f 44–118) is small at 150 px but the head dip toward him (f 64–92) sells it | weight shift f 112→136, flourish anticipation f 150 → "ta-da" accent f 160–170 (out_back = the one overshoot) → hold to f 204 | no sounds (own); faces curious f 62, proud f 160, smug f 196; runtime gaze to the camera f 0–50 / 112–240 | two weight states + a flourish every 4 s — not a static loop | 3 / 4 / 3 |
| `loco_walk` (loop 54) | knees high, paws, 16° lean: the sneak reads in profile and at the 20° cheat | a bound per step: pelvis low mid-stance, high mid-float (the float is the "accent" of each step) | step_pizz_up on each ball contact (f 0 / 27), lint-checked in lane space at 2.0 m/s | the cartoon tiptoe — the 2D sneak's rhythm, in 3D | 3 / 5 / 3 |
| `rig_achoo_ria` (48, rig_pm) | hop (f 3–6) → **lean-out snatch with the leg kicked back** (f 7–9) → pot swung over the jar, three shakes (f 16 / 26 / 36) → lean-out put-back (f 41–42) → hop down (f 44–47) | anticipation crouch f 3 → landing squash f 6; each shake: the wind-up (pot cocked 78°) → POP down to 52° on the shake frame, the spout on the jar's mouth; the face holds to the camera f 10–40 (30 f) | pepper_shake + fx pepper_stream on each pop; stool_creak on the landing (f 6); faces sneak (grab) → snicker / grin / laugh on the shakes → smug on the put-back | the joke is *set up* in view: the snatch is precarious, the shakes are big; see "known limits" | 4 / 3 / 4 |
| `rig_step_down` (8) | dip → tuck → two-foot land → up: a clean hop off the stool | dip f 0–2, airborne f 2–6, land f 6 (squash) | step_pizz_up on the landing f 6 | a utility clip | 2 / 4 / 2 |
| `act_snicker` (60) | gloves at the chin, shoulders to the ears, knees knocked, one heel popped | shrug f 2 → gloves up f 5–8 (accent f 8, out_sine) → the giggle bursts (8 Hz shakes) f 8–44 with the sly look f 24–36 (face `glance` + runtime gaze to the camera) → snort f 40 → composure f 48 | hush_snicker at f 0 (table); face snicker f 6 → glance f 24 → snicker f 38 → smug f 46 | a mime's stifled giggle, eyes over the gloves | 4 / 3 / 3 |
| `act_dive` (15) | coiled → push → **flat-out superman** (f 6–10) → tucked ball (f 13–15) | f 0–2 coil, launch smear f 2–4 (declared pops), flight f 6–10, tuck f 13 | `dive` whoosh at f 0 (table); face frantic f 4 → hold_breath f 12 | the big cartoon leap | 4 / 5 / 3 |
| `act_pop` (15) | tucked ball → squash → **star jump** (arms and legs flung wide) → toes | squash f 0–2 → burst f 3–6 (out_back overshoot) → peak f 9 → land f 12 | `pop_out` f 0 (table); face grin f 3 → happy f 8 | the reveal | 4 / 4 / 3 |
| `freeze_1` arabesque (150) | on the ball of the left foot, the right leg stretched back, arms fore and aft — unmistakable | 3 f wind → overshoot f 4 → SNAP f 5, dead still to f 150 (`freeze_holds`) | freeze_clack f 5 (table), face `statue` f 5 | four statues, each its own family (IoU ≤ 0.53 among 1–4) | 4 / 5 / 4 |
| `freeze_2` the thinker | down on one knee, the elbow on the other, chin on the fist | the right foot steps back (lifted f 2) before the knee goes down; snap f 5 | same | the Rodin gag | 4 / 5 / 4 |
| `freeze_3` surprise | on her toes, arms flung up in a V (the left higher), a knee jerked up, head back, mouth an O | snap f 5 | face `shock` | the "eek!" | 4 / 4 / 3 |
| `freeze_4` flamingo | on the right leg, the left knee high in front, foot tucked to the knee, wings folded | the knee lifts on f 2 (a step, not a drag); snap f 5 | face `statue` | prim | 4 / 5 / 4 |
| `act_squeak` (18) | Clarence whipped out of the brace, **hoisted up high like a horn** and squeezed, a knee kicked up | grab f 3 → whip out f 4 (declared pop) → SQUEEZE f 8 (pop: fist 92°, his body squashes, comb flares) → recoil f 11 → back in the brace f 15 | no sounds (table: the sim plays the squeak); prop attach grip_r f 4 / brace_r f 15; faces grin f 4 → laugh f 8 → smug f 13 | the rubber-chicken beat | 4 / 3 / 3 |
| `loco_run` (loop 24) | lean 24°, fists pumping about her x axis (fixed: the old preset twisted), knees driving | a flight between the 5-frame stances | step_pizz_up +2 dB on each contact (table f 0 / 12) + fx dust_puff | the dash | 3 / 4 / 3 |
| `loco_turn` (6) | a squash into the turn and a stretch out of it | squash f 2 → stretch f 4 | — | a utility clip | 2 / 3 / 2 |
| `act_climb_in` (60, 2D beats) | perched on the sill, a leg feels down, she slips off, lands in a crouch, "shh!", three tiptoe steps and a bold one | slip f 7–12 (landing squash f 12, mark contact) → shh + look round f 12–17 → steps f 18 / 28 / 38 / 50 | window_creak f 0, step_pizz_up −2 dB f 18 / 28 / 38, f 50 (table, at their 2D frames); faces hold_breath → shush → curious → sneak → grin | the Prologue's first beat | 3 / 4 / 3 |
| `rig_allegro_go_go` (48, rig_pm) | eyes the lever, turns in, both gloves on it, **yanks** — hips drop, head thrown back — holds straining, lets go and dusts off | wiggling fingers f 5 → grips f 13 (mark contact, creak) → lean-in f 13–16 → YANK f 16–22 (pop, the knob arcs 40° toward her under the gloves) → strain hold f 22–40 with the face to the camera → release f 40–42 → dust-off f 45 | clack on the stop f 22 (the accent mark); faces sneak → determined → frantic → grin → smug | reads in the set (the red knob at her gloves); weaker in silhouette | 3 / 3 / 3 |
| `act_bow` (loop 150) | a deep hinge at the hips with the sweep of the right glove, then up with the left glove to the gallery, a kiss | flourish f 0–12 → bow f 12–28 (bow_creak) → held bow with two thank-you dips f 28–52 → up f 52–66 (out_back) → kiss f 94 → applause sway to f 150 | faces happy → laugh → wink → happy → proud | the curtain call | 3 / 4 / 3 |

## Known limits (honest)
- **ACHOO-RIA! staging.** The jar and the set pot are on the back shelf and her reaching hand is on the wall side of
  her body (facing −x, cheat ≤ 10): the pot, its three shakes and the jar read beside her head, with her face to the
  audience, but her glove is partly behind her head from the camera (`achoo_kitchen_pot.jpg`). The set pot is 0.30 m
  beyond the jar, so the snatch needs a 30° lean-out on one foot (a gag in itself); her glove stops 0.05–0.07 m short of
  the set pot on the snatch frame (f 7, a declared pop, when the set pot hides and hers shows). Requests to r3d-sets and
  r3d-cast-hush in the report.
- In the kitchen, the anticipation crouch (f 3) brings her ready right claw in front of the kettle on the cabinet
  (a 2-frame overlap at 1200×540, `achoo_kitchen.jpg` f 3); the set places the kettle there — not re-staged.
- **ALLEGRO-GO-GO! staging.** At reach_pos x 7.8 she works right against the parlour's wall end: the pillar
  overlaps her back while she is turned in to the lever (f 9–19, `allegro_parlour.jpg`); from the yank on (f 22–40)
  her face and the red knob at her gloves read. Request to r3d-sets (reach_pos dx) in the report.
- The frame-locked review renders do not run the props' own `rig` anims (the jar, the lever) or the fx: the pepper
  stream and the lever travelling to ×3 are the view's, from these clips' events and the rig progress.
- `loco_turn` and `rig_step_down` are utility clips (scored low on *funny* by design).
