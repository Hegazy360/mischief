# r3d-fix-gags2: QA round 2, fix round 2 (row 9, 16(b)/(c), Q2-C1, Q2-C2, Q2-G1 to Q2-G6, Q2-G8)

QA round 2 failed rows 9, 16 and 19 (`docs/review/r3d-qa/readability.md` "Round 2"). This page re-shoots every gag it
judged, on the same route and at the same ticks as the round-2 packet (`packets/set_h`): `prologue_ideal --fixed` and
`g0_sneeze`, 1200×540, `--no-captions`, MSAA off, a DevShot frame every 3 ticks. The strips use the reviewer packet
layout: 2 columns, half scale, frames numbered from the window start (f0 = the window's first tick).

- **before/**: the exact round-2 packet pages the reviewers judged (`set_h/pkt_NN/page_N.jpg`, renamed by gag), the
  crowding frames `set_g/pkt_04` (P00 t2190) and `set_g/pkt_07` (N1 t6768).
- **after/**: the final tree (run `e1` for the Prologue, `g2` for Gate 0; earlier looks `a1`–`d1` in the work dir), the
  same windows and strides.

The scores need **new** fresh reviewers (D18.1: three per packet, medians). I did not score my own strips. Mute,
captions off, at phone size, the rubric of TECH §11: the set-up before the hit, the hit in frame with contact, a held
reaction on his face to the camera (≥ 30 f, D8), no camera cut within 30 f of the hit, one payoff the eye cannot miss.

| gag (window, stride) | round 2 (funny/readable/fresh) | bar | before | after |
|---|---|---|---|---|
| g0 sneeze (g0 1090–1228 /6, accent t1163) | 3/3/3 | 4/4, fresh 3 | `before/g0_sneeze_{1,2,3}.jpg` | `after/g0_sneeze_{1,2,3}.jpg` |
| P00 sneeze (1318–1456 /6, accent t1375) | 3/3/3 | 4/4, fresh 3 | `before/p00_sneeze_{1,2,3}.jpg` | `after/p00_sneeze_{1,2,3}.jpg` |
| dizzy spin (2560–2767 /9 and /6, accent t2659) | 3/4/3 | 4/4, fresh 3 | `before/dizzy_spin_{1,2,3}.jpg` | `after/dizzy_spin_s9_*.jpg`, `after/dizzy_spin_s6_*.jpg` |
| relief (3196–3265 /3, cue t3238) | 1/2/2 | 3/3/3 | `before/relief_{1,2,3}.jpg` | `after/relief_{1,2,3}.jpg` |
| squeak bit (217–331 /6, bit t230) | 1/2/1 | 3/3/3 | `before/squeak_bit_{1,2,3}.jpg` | `after/squeak_bit_{1,2,3}.jpg` |
| vase (82–208 /6, cue t138) | 2/3/2 | 3/3/3 | `before/vase_{1,2,3}.jpg` | `after/vase_{1,2,3}.jpg` |
| doorframe bonk (1624–1750 /6, cue t1677) | 2/3/1 | 3/3/3 | `before/doorframe_bonk_{1,2,3}.jpg` | `after/doorframe_bonk_{1,2,3}.jpg` |
| picture (3256–3394 /6, cue t3273; passed) | 3/4/3 | 3/3/3 | `before/picture_{1,2,3}.jpg` | `after/picture_{1,2,3}.jpg` |
| crowding P00 t2190 (Q2-C1, his bubble) | "yes" | ≤ 1/8 | `before/crowd_p00_t2190_pkt04.jpg` | `after/crowd_p00_t2190.jpg` |
| crowding N1 t6768 (Q2-C2, the pickle jar) | "yes" | ≤ 1/8 | `before/n01_t6768_crowd_pkt07.jpg` | `after/n01_pickle_shelf.jpg` |

## What changed, gag by gag (what I saw in the after strips)

### Q2-G1, both sneezes
- **The cause is on screen.** Through the build-up (reaction f0–78) the rigged pepper pot on the shelf above him shakes
  every 24 f and a stream of big dark pepper flecks falls from it onto his nose (Fx3D `pepper_fall`, every 7 f); a dark
  sniff-puff at his nose on each "ah" (`pepper_nose`). Seen in g0 f6–42 and P00 f0–48.
- **The sink hold reads.** `rx_sneeze_blast_a`: in the sink (112–165) his head is up and turned to the Stalls (the
  existing gaze 114–165), the chin off the jabot, the gloves on the basin rims; the splash frizzes the flipped bouffant
  UP above his brows (look event f113: `flipped` → `frazzled`); the star ring circles from f117. Seen: g0 f96–138 and
  P00 f78–120 — his dazed spiral-eyed face to camera for ≥ 42 frames. The jabot still touches his chin; the eyes,
  nose and the stars read.

### Q2-G2, the dizzy spin
- `rx_dizzy_spin_a`: **two** turns (752°, was 1112°) in the same locked 36–80 f window, so each 6-tick still shows a
  quarter turn, not a blur.
- He is spun BY the record: during the spin the notes whirl round his waist (Fx3D `note_whirl`, a swept ring of note
  glyphs) fed by a jet of notes from the horn straight at him (alternating with the floor dust whirl). Seen at f48–90
  (stride 6). The collapse and the dizzy face hold (f96–138) are unchanged.

### Q2-G3, the relief
- The near miss has a shape (all before the cue, so it fits the round-2 window): he glances at her gap (her eyes are
  there), then the **double take** (`st_double_take` at 40 ticks of hunt left: he looks away, her eyes duck, he snaps
  back to an empty gap) held to the cue with his face to camera (32 f).
- **Her payoff** on the cue: the eyes pop up and squeeze shut (HideSpot3D `eyes_phew`), two white "phew" puffs rise
  from the gap (Fx3D `phew`) with sweat drops; his thought bubble is quiet through the two-shot. Seen f9–39 (the take)
  and f42–69 (the phew).

### Q2-G4, the squeak bit
- His answer is on the **main screen**: 0.2 s after the bit starts (her squeeze and Clarence's ring show first) a cue
  shot whips to him in the parlour (×1.25, 12 f in, 66 f hold, 18 f out) — the crack (limp notes tumbling out of his
  mouth + the squeak's yellow ring out of HIS mouth), the yodel, the throat clutch and "...the pipes." with his face to
  camera — then back to Hush. While Hush is busy CameraDirector3D plays it in the escalated window instead.
- Seen: f0–18 Hush squeezes Clarence, f24 the whip, f30–96 him, f108–114 back on her.

### Q2-G5, the vase
- The crash lands on his top note like a cymbal and he takes it as his ovation: 6 f after the smash the curtain-up
  shot pushes in on him (×1.15) and he straightens his cravat and gives the Stalls a haughty sniff
  (`st_straighten_cravat`, face to camera), held 30 f, the vase shards in the same frame; then the shot eases back to
  Hush before the squeak (≈ t226). Seen f72–114.

### Q2-G6, the doorframe bonk
- **Anticipation the other way:** ≤ 40 f before he reaches the parlour|kitchen frame (blind, FRAZZLED; timed off his
  walk's ETA) he draws himself up and back, nose in the air, smug to camera — a new overlay
  `bellows/cue_doorframe_windup` (a dip, then a pop up and back) — then tips forward into the frame.
- **No camera cut near the hit:** the bonk shot leads the hit by 64 f with a 24 f push, so the camera is still from
  ≥ 30 f before the hit, and the cue keeps that same shot (`CameraDirector3D.extend_gag`), holding 36 f past the 58 f
  pin. Seen: the push f0–24, the wind-up f24–48, the hit f60, the same framing to f108.
- **The face hold:** the bonk overlay gazes to the camera from its f7 (and the rub is on his crown, chin up); every
  cue close-up (bonk, picture, vase) now looks at the camera over any noise glance, chin a little up. And the BONK
  knocks his frazzled hair back up off his eyes (clip look event f4 `bouffant: neat`) so the dazed face reads, until it
  flops back down over them at f32 (`frazzled`) and he gropes on — a small second laugh inside the hold.
- **The fresher twist:** the jolt runs along the wall — the parlour picture swings on its hook and settles askew (9°,
  `CueStager3D.picture_swing`), so the picture that falls on him at t3273 was set up by this bonk.

### Q2-G8, the picture (passed; note)
- It no longer pops out of sight: after the 60 f hang it is let go where it sits (`Prop3D.release_here`) and slides
  off his head, down past his shoulder, tipping onto its side to the floor beside his feet (26 f), lands with a dust
  puff and stays there. Seen f96–138.

### Q2-C1, his 3D thought bubble vs the APPLAUSE / RUNNING GAG band
- `after/crowd_p00_t2190.jpg` (the same tick on the final tree): his bubble sits at the left, clear of the band; the
  gramophone badge beside its prop and the ring count are r3d-hud's (in flight in their round). The parlour picture
  hangs askew since the bonk — the set-up for t3273.
- `Overlays3D`: while the band shows, the Hud's transient rects (+ 24 px) are a keep-out for his bubble: beside his
  head when that side is clear, else below the band (`Overlays3D.band_bottom_of`). The Hud is found up the tree
  (NightScene's `hud`). His bubble is also quiet through every cue close-up (bonk from the wind-up on, picture, vase
  ovation, relief two-shot), which removes the round-2 bonk f54 overlap.

### Q2-C2 and row 9 (house3d.json)
- The N1 pickle-jar shelf is at 1.63–1.66 m (was 1.32–1.35): the jar stands above Hush's 1.6 m head line on a visible
  shelf, not on her beret. Reach target = the jar's base (high band, no step, 0.486 m ≤ 0.5); the pan rail moved 0.4 m
  left (the jar's preview band). SetCheck n01/p00/g0: 0 errors, 0 warnings.
- `decor.parlour_vase` is no longer `"dressing"` (it is the laugh_vase cue prop, loud on purpose):
  `lint3d --set --all-nights` 0 errors (1 warning: D13's N02 hall).

## Row 16 (b)/(c) (D18.2)
- I added a sub-phase probe to `CharacterView3D._drive_rig` in a scratch build and ran two fresh headless
  `prologue_ideal --perf-log --view3d-prof` runs (the probe printed every drive pass > 0.6 ms). Neither run has a Hush
  call over 0.72 ms at t965–1005 (the pantry hide) or t2830–2855 (behind the piano); the only probe hits were clip
  switches at other ticks (base play 0.6–1.7 ms, rig_play). The QA's t977–996 and t2846 hits did not reproduce on this
  tree. The probe was removed again.
- The new staging adds no first-time reads in PLAY: the stager's own clips (`CueStager3D.STAGED_CLIPS`) are warmed under
  the curtain by `WorldView3D.warm_clips` (sidecar + clip), like the map's clips.

## Tests
- `view3d/test_gag_staging3d.gd` +6: the wind-up ETA, the picture's askew swing about its hook, `extend_gag` holding the
  same shot, the round-2 FX kinds and staged clips, the bubble band keep-out math, the near-miss / vase / squeak
  timing constants.
- `anim3d/test_bellows_clips3d.gd` +2: the sneeze sink hold (bouffant up + ≥ 30 f gaze), the wind-up overlay (layer,
  mask, length, `.res`, strict lint) and the bonk overlay's gaze.
- `set3d/test_set_list.gd`: the P00 parlour dressing list without the vase.
