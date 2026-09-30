# r3d-anim-bellows-b — TECH §11 rubric (Bellows' bits, one-shots and micro-gags, 20 clips)

Answered from the fixed-60-fps captures at the game camera in the real P00 set (`boards/*.png`, AnimViewer3D through
`capture.sh`, 1200×540), the in-game P00 capture (the Bellows window during the squeak bit, `boards/ingame_bit_warmup_pip.png`)
and the sheets (`sheets/<clip>_contact.png` etc., r3d-rig's tool: side profile + a facing +1 phone strip). No clip is a
draft (R19 cut line never reached). Scores 1–5 on funny / readable / fresh; the brief's bar is ≥ 3 on every non-draft.

**Caveat that applies to every face beat (lead ruling D8):** the face beats carry sidecar `gaze` entries
(`look_camera`, weight 1.0, 6–8 f eases) and, where the staging is fixed (the gramophone, the stool, the hall mirror),
a baked head aim at the camera as well. `RigPlayer3D` does not honour sidecar `gaze` yet (r3d-rig finished before
r3d-anim's request) — until it does, the facing-proof clips (one-shots, walking micro-gags) show their faces at the
plain 35° / 20° cheat. The boards marked "(look-at)" simulate the runtime gaze with AnimViewer3D `--look-at` at the
camera. Request filed (report §Requests).

## The FINAL five

### `bit_warmup` (90 f, base, lock sim — the Prologue's first player laugh, ≈ 6–7 s)
- **Silhouette at phone size?** Yes. Singing carriage (f0–8, baton up) → the crack (f8, head jerks back) → the yodel
  (f11–26: the baton arm flapping above the bouffant, the barrel waggling) → arms thrown wide and BACK (f30–34, the
  widest frame of the clip) → the snap to the collar (f36) → the chin-up "…the pipes" hold → the carriage again.
  In the Bellows window (≈ 200 px wide, in-game capture) the yodel flap and the wide wind-up read; the clutch reads
  as "hands at the chest" — the weakest beat at window size.
- **Anticipation opposes?** Yes: f30–35 the arms go out and back and the chest lifts; the accent pulls them in and the
  barrel forward (L07 clean; L18 +28 % bbox).
- **Accent ≤ 4 f with a pop?** f35–38, pop key f36 (+ overshoot f38), timed to the squeak_bit rim-shot (+0.6 s).
- **≥ 30 f hold where the face reads?** f38–70 (32 f): `mortified` → `pardon` ("…the pipes", f46) → `sulk`, head
  baked to the camera (0.75) + gaze; the glove sits at the side of his neck so the forearm never crosses the mouth
  (two earlier versions covered the mouth with the sleeve — fixed).
- **One overshoot?** Yes, f38. **SFX on the frame?** `vo_bellows_yodel` on the crack pop f8, `vo_bellows_the_pipes`
  on the beat f46 (no table row: new rows for r3d-integrate). **Face on the accent?** f36 `mortified`.
- **Sliding / floor?** Feet planted (auto_plant 0), L12/L13 clean. **Fresh?** Different from every warm-up gag: the
  only beat where his voice fails him.
- **Scores:** funny 4 · readable 4 (window: 3) · fresh 4.

### `bit_tea` (100 f, base, lock sim, on the stool)
- **Silhouette?** Yes: the hurried sip (f4–13, cup at the lips), the inhale (f16, chin up), the SNORT (f17: head down,
  the little legs kick out, the saucer glove flung out behind him — the silhouette explodes sideways), the splutter
  with the cup held away, the glare, back to act_tea's rest.
- **Anticipation opposes?** Yes (chin up / chest in → head down / limbs out; L18: box area +23 % f16 → f19). **Accent** f16–19, pop f17 (+ overshoot f19).
- **Hold where the face reads?** f19–58 `teary` (39 f) with the coughs (f28/40/50) and the drops FX; f64–74 the
  `suspicious` glare turned to the camera (baked 0.5 + gaze).
- **SFX:** `tea_slurp` f4, `vo_bellows_pff` f17 (the pop), `vo_bellows_ugh` f28, `sniffle` f58 (own rows).
- **Props:** teacup + saucer shown, spoon hidden on f0; `keeps: []`, no hand-off in flight. The ×1.8 cup reads in every
  cell of `boards/bit_tea.png`.
- **Scores:** funny 4 · readable 4 · fresh 4.

### `st_head_turn` (60 f, overlay `head`, lock sim)
- The view already aims his head at the squeak (WorldView3D noise gaze, 1.2 s); this overlay adds the character: a
  start (f3), the ear cocked hard over (f8–28), a squint with the chin forward (f30–42), a shake-off (f44). Only the
  neck and head drive (mask); no accent beat (a listening beat, not a take). The event's own "huh" is cues.json's.
- **Scores:** funny 3 · readable 3 (4 with the gaze) · fresh 3.

### `st_double_take` (18 f, base — also the N1/N2 reaction fallback)
- Glance (0–3) → look away with the gloves tucked (3–8) → SNAP (pop f9): the head whips round, both gloves thrown
  out, eyes popped (`shock` f8 → `wild_take` f11), a trembling held take to f18 so a view that holds the last frame
  still reads. The camera-side glove stays low and wide so it never covers the face in either facing (the first
  version threw it across the face — fixed). L18 bbox +42 %.
- **Scores:** funny 3 · readable 4 (look-at) · fresh 3.

### `st_specs_on` (12 f, overlay `upper`, lock sim)
- The right glove whips the dangling specs off his chest and slaps them on (prop `specs` shown on f4 = the `magnified`
  face), pushes them up the bridge, drops. A glint (fx sparkles f5); the tink is cues.json's. The glove at the bridge reads
  in both facings (`boards/oneshots.png` row 2, facing −1); the specs appearing + the tink carry the beat.
- **Scores:** funny 3 · readable 3 · fresh 3.

## The other fifteen (all authored as real clips — no drafts)
| clip | f | layer | what reads (frames) | funny | readable | fresh |
|---|---|---|---|---|---|---|
| `st_suspicious` | 60 | base | halt rock (0–8), sniff (8–14), chin-OUT lean-in with the glove stroking his chin, the face level (14–48), "hmm" (48–60) | 3 | 4 | 3 |
| `st_look` | 180 loop | base | specs on, crouched peer left (20–58) / right (58–100) / at the floor (100–128), the palms-up shrug (128–160) | 3 | 3 | 3 |
| `st_look_back` | 60 | base | a paranoid double look back: over the left shoulder (12–30), SNAP over the right (31–35), "hmph" front (44–60) — one of the two always passes the face across the camera | 3 | 3 | 3 |
| `st_smirk` | 30 | overlay upper | the fizzle: chin up, belly pats, a smug little chuckle (8–22) | 3 | 3 | 3 |
| `st_straighten_cravat` | 92 loop | base | the doorway pause: both gloves to the cravat, TUG (20, cravat_tug), lapels smoothed, chin-up sniff; 92 f so one cycle covers the longest pause (90 − eta + 1 ticks — the view frame-locks one-shots without wrapping) | 3 | 3 | 3 |
| `mg_hum` | 48 | overlay upper | eyes shut, the barrel tick-tocking like a metronome, the baton wagging, a note burst | 3 | 3 | 3 |
| `mg_trill` | 48 | overlay upper | arms flung wide and chin right up, the head vibrating (4–30), throat taps "still got it" (30–42) | 4 | 4 | 3 |
| `mg_conduct_air` | 60 | overlay upper | baton down / across / UP on the table's swishes (5/20/30), the deep bow to the empty room (42) | 3 | 3 | 3 |
| `mg_admire_reflection_horn` | 60 | overlay upper | leans into the horn (6, glint), a smug look to the house (14–26), pucker, the blown kiss (42) | 4 | 3 | 4 |
| `mg_pinkie_up` | 48 | overlay upper | THE SIP path of act_tea (f420): the cup up, the pinkie cocked to 1.35 with a tuning-fork wobble, "Ahhh" (30) | 3 | 3 | 3 |
| `mg_admire_in_kettle` | 48 | overlay (head) | a glance down at the kettle (2–13, glint), then the vanity is played TO THE HOUSE: chin up, a WINK (face slots, 18–24), a preening head roll (26–40) — see staging note | 3 | 3 | 3 |
| `mg_comb_flourish` | 48 | overlay upper | at the hall mirror (facing +1, the comb hand on the camera side): one big stroke over the bouffant, the flourish, the tuck behind the ear | 4 | 4 | 3 |
| `mg_cravat_tug` | 48 | overlay upper | the tug (10) and the chest swelling enormous mid-stride, a second ping (27) | 3 | 3 | 3 |
| `mg_walk_hum` | 48 | overlay upper | chin up, eyes shut, the index finger beating the march on the strut's 16 f period | 3 | 3 | 3 |
| `mg_walk_scale` | 48 | overlay upper | do-re-mi on 0/16/32: the chin and the glove climb a rung per note, the last one held with the arm flung out | 3 | 3 | 3 |

**Known weak spots (every clip ≥ 3):**
- `mg_admire_in_kettle`: the kettle sits on his far (right-back) side at the stool, so looking at it turns his face
  away from the house (so the look is only 11 f and the wink goes to the house); and the mg fires at act_tea's honey
  beat (f120), so the hands cannot pat the bouffant (they hold the lent jar and the spoon). Authored for the `head`
  mask; staging reported to r3d-sets / -a / content (report §Requests). With the kettle lent into a free glove at
  another moment of the tea it would read at 4.
- `bit_warmup` in the Bellows window (≈ 200 px): the yodel flap and the wide wind-up read, the collar clutch reads only
  as "hand to the chest" (`boards/ingame_bit_warmup_pip.png`).
- `mg_conduct_air`: the baton is in the far glove when he faces −1 at the gramophone — the strokes read smaller than
  the bow.
- Face beats of the facing-proof clips wait on the runtime `gaze` (D8) — see the caveat at the top.
