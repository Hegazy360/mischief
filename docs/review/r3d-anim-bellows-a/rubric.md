# r3d-anim-bellows-a — TECH §11 rubric (Bellows' Gate-0 clips, 12)

Answered from the fixed-60-fps game captures at 1200×540 (`ViewSandbox3D --sim --episode=g0_sneeze`, the ideal
commands: `sneeze_strip.png` / `sneeze.gif` seek 1040, `tea_strip.png` seek 600), frame-locked AnimViewer3D shots in the
real kitchen / parlour / hall at the game camera, and r3d-rig's sheets (`sheets/<clip>_*`). Engine frame = clip frame
+ 29 in the sneeze strip (+ 5 after the f 94 hit-stop), + 50 in the tea strip. No clip is a draft (the R19 cut line
was never reached). Scores 1–5 on funny / readable / fresh; the bar: ≥ 4 funny and readable on the sneeze, ≥ 3 on every
other clip. Self-scored, with a mute fresh review: round 1 (orchestrator-run) scored the sneeze funny 4 / readable 4 /
fresh 3 ("a huge ACHOO-RIA! sneeze at 33 that blasts him backwards across the room … slumped … seeing stars"; held back
by "the wind-up at tiny wide-shot size") and the tea 1 / 2 / 2 ("holding a kettle and fidgeting slightly") → act_tea v2
below; the round-2 packet (current captures) is in `packets/`, pending.

**D8 (faces face the camera).** Staged clips bake it (`_lib` `face_cam()`: a yaw-only turn of spine_02 / spine_03 /
neck / head to the stage camera — the keyed pitch and roll stay, the chest turns with it so a glove at the mouth never
crosses the barrel) and carry the sidecar `gaze` too. Clips that play facing either way (idle, slow burn, bonk,
wander-on) have only the sidecar `gaze`, which the 3D player does not read yet (request r3d-rig): until then their face
beats sit at the view's 35° cheat.

## The FINAL one

### `rx_sneeze_blast_a` (165 f, base, lock sim — ACHOO-RIA!'s payoff)
- **Silhouette at phone size?** Yes, one outline per beat: the pinkie-up sip (f0, = act_tea f420), the chest swelling
  and the head tipping back with the cup held off (f20–74, the arch deepest at f74), the relieved re-sip (f82–91),
  the gasp (f93), CHOO (f94: arms flung, knees up, the puff out in front), blown back on the stool (f97), windmilling
  in the flight (f100–109), the cork in the sink with the slippers up (f112–145), sitting up under the stars
  (f149–165). `sheets/rx_sneeze_blast_a_sil64.png`: the five beat silhouettes (74 / 94 / 97 / 145 / 165) are all
  their own family at 64 px (IoU 0.24–0.63, none ≥ 0.80).
- **Anticipation opposes the accent?** Yes: the build pulls back and up (lean −23°, head −27°, pelvis −8° at f74; the
  gasp snaps back further at f93); CHOO throws him forward and down (lean +12°, head +14°) — L07 clean.
- **Accent ≤ 4 f with a pop?** f94–97, pop keys 94 / 95 / 112; hit-stop 5, cam punch 1.4 (in 11, hold 90, out 21,
  yaw 5), shake 0.55, the puff pinned where it burst (f94–103), cup and saucer launched, bouffant flipped, jiggle kick.
  In game (strip engine f123–133) it is the loudest frame of the Night: the caption, the puff, the crockery, the flight.
- **≥ 30 f hold where the face reads?** f112–145 (33 f in the sink) + the dazed settle to 165: the face is aimed at the
  camera (full look 0.9, the torso sat up in the basin); the flipped bouffant covers his eyes by design (the residue
  gag the blind shuffle carries on), the nose and the open mouth read under it (strip engine f150–199).
- **One overshoot?** f149 (out_back: the sit-up, the star ring popping to 1.25 and settling to 1.0).
- **SFX on the frame?** The audio table row: vo ah1 0 / ah2 20 / ah3 44 / hm 76 / choo 94, stool_scrape 95,
  slide_up_flight 96, sink_crash 112, ladle_spin 154 — each on a beat / contact (L14 clean).
- **Face swap on the accent?** f93 `sneeze_gasp` → f94 `sneeze_choo` → f97 `wild_take` → f112 `dazed_open`.
- **Sliding / floor?** Seated on the 0.55 m stool (the seat socket pinned) to f94; the view carries the root into the
  sink (travel arc, landing kitchen.sink); no foot contact to slide. Frame 0 matches act_tea f420 (test ≤ 1.5°).
- **Laugh after the hold starts?** The laugh is event-level (the director's reaction laugh), not a clip event (the
  test asserts it).
- **Different from last time?** It is the Gate-0 payoff, seen once a night; in 3D the ride on the stool, the tumble of
  the stool and the puff blasting forward past the face are new against the 2D take.
- **Scores:** funny **4**, readable **4**, fresh **3–4** (the reviewer: 3, a stock sneeze-blast idea). Holding it
  back from 5: view-side items (the punch-in framing puts him at the right edge in the sink; the ride-along stool
  renders pink; the basin front hides the slippers) — requests in the report.

## The other eleven

### `act_tea` (480 f loop, base; st_tea, facing −1)
- Silhouette: kettle up in the right glove (lend f14–78: pour f40–72 from the glove into the cup), the saucer on his
  belly as a shelf (f98–166) with the honey jar in the left palm (lend f104–148), the spoon in the jar and the lid
  flipping on the spoon contact (`set_anim lid_flip` f126), the stir (f169–243), the sniff, the pompous blow (f330),
  the pinkie-up sip (f388–446) = THE SIP at f420. Every lent piece is home by f148; the teacup is in his hand or on the
  saucer in every frame (`tea_strip.png`).
- Anticipation / accent: no take; the beats are the hand-offs (contact marks on the strip) and the lid flip.
- Face on the camera: the smug glance with the kettle up (f18–40), "huh" and the smug look after the lid flip
  (f128–166), and the whole performance from the stir to the seam (f240–480 + 0–12). NB: in game at f124–136 -b's
  `mg_admire_in_kettle` overlay turns his head away (note to -b in LANDED).
- SFX: kettle_pour 40, spoon_clink 169 / 243, tea_stir 182, tea_sniff 270, tea_slurp 388, teacup_clink 462,
  stool_creak 472 (the audio table). No sliding (seated; the slippers dangle).
- v2 after the fresh review: the pour from a height (kettle 0.26–0.30 m over the cup, tipped 58–62°, the body leaning
  back, chin up: strip engine f80–125), the lid-flip recoil (f132), a bigger stir with the chest rocking in time
  (f169–243), steam on the sniff (f270), sparkles of bliss after the sip (f446).
- **Scores:** funny 3, readable 3 (the small props still carry most of it at the wide shot), fresh 3.

### `act_warmup` (480 f loop, base; st_gramophone, facing −1)
- The baton's tip taps the needle down (IK on the tip, f6–34; `set_anim parlour_gramophone play` f24 = ALLEGRO-GO-GO!'s
  trigger at f30), the big breath (f40), then two phrases sung to the Stalls with the baton beating time every 30 f,
  the left glove on his heart, the belly trembling with the vibrato; the top note (f100–160, the vase nudging), the low
  note down in his knees (f350–405), and back. Face on the camera f40–456 (baked + gaze).
- SFX: vo warmup_1 40 / warmup_3 250, vase_nudge (sync false) — audio "own" (the 2D 1200 f row re-timed into 8 s).
- **Scores:** funny 3, readable 4, fresh 3 (the baton beat could be bigger).

### `act_fixup_mirror` (240 f loop, base; st_hall_mirror, facing +1)
- Combing the bouffant in long strokes with the red comb (f40–100, f152–212: the comb tip IK'd along the hair), the
  left glove patting it (f16, f118), admiring himself; the smug glance (f12–30) and the kiss + smug look (f104–146) to
  the audience (before D8 he showed the back of his head there). Hums at 40 / 152.
- **Scores:** funny 3, readable 4, fresh 3.

### `loco_idle` (240 f loop, base)
- Pompous stance, gloves on the barrel's sides (IK), belly finger-drum, the pinkie flourish (f56–80), the audience
  glance (f118–150, runtime gaze), the cravat tug (f170, cravat_tug). Reads at 64 px (the flourish arm).
- **Scores:** funny 3, readable 4, fresh 3.

### `loco_strut` (32 f loop, 1.2 m/s, stride 0.64 m)
- Chest-out strut, toes out 12°, a heel–ball roll with the planted foot sliding back at exactly the walk speed (L12
  clean), steps on 0 / 16 (the audio table). **Scores:** funny 3, readable 4, fresh 3.

### `loco_irked` (28 f loop, 1.32 m/s, stride 0.616 m — walk@tier2)
- Faster, fists clenched, head forward, red; steps 0 / 14 (audio own). **Scores:** funny 3, readable 4, fresh 3.

### `loco_blind_shuffle` (24 f loop, 1.2 m/s — walk@blind)
- The bouffant over his eyes (the residue slot), both gloves groping the air, fingers wiggling, head cocked to
  listen, slippers barely lifting (slipper_scuff 0 / 12). The aftermath the owner watches all the way to the mirror.
  **Scores:** funny 4, readable 4, fresh 3.

### `loco_turn` (8 f)
- The pompous about-face with a disdainful sniff (face f3). Utility. **Scores:** funny 3, readable 4, fresh 3.

### `cc_wander_on` (144 f, curtain call)
- Ambles on in the strut, gloves on the belly, humming, gazing up at the flies as if it were his own parlour
  (oblivious — st_double_take follows); the blissful face turned 3/4 to the Stalls at 0.6 (runtime gaze).
  **Scores:** funny 3, readable 3, fresh 3.

### `st_bonk` (60 f, oneshot:stun)
- The squash on the pop (f0) with the knees buckling, the recoil (f2, the accent), dazed under the star ring
  (f6–60, spinning), a head shake (f48–54); woodblock_bonk 0, dizzy_tweets 6. **Scores:** funny 3, readable 4, fresh 3.

### `beat_slow_burn` (70 f, curtain call)
- The stare: a slow turn of the head to the audience (runtime gaze f10–70), one brow up (f30), the blink (f40–44),
  the sideburn twitch (f57); bassoon_burn 0. Depends on the runtime gaze for the full effect. **Scores:** funny 3,
  readable 4, fresh 3.
