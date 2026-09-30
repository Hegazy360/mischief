# r3d-anim-bellows-c — TECH §11 rubric (Bellows' Prologue-only clips, 10)

Answered from the fixed-60-fps captures at the game camera in the real P00 parlour (AnimViewer3D through
`capture.sh`, 1200×540: `dizzy_strip.png`, the two cue strips, `boards/*.jpg`), two in-game runs of the Prologue
(`e2e.sh prologue_ideal`, real time on the CPU box: ≈ 4 clip frames per rendered frame; `boards/ingame_*.jpg`) and
r3d-rig's sheets (`sheets/<clip>_*`, rendered at facing +1 — the other facing from my captures, so every clip that
plays either way was judged in both). **Sheet caveat:** f0–f7 of every base-clip sheet show a crossfade from the
clip's LAST pose (sheet3d.gd's bounds pre-pass leaves the pose at the end frame, then `play()` blends in over the
clip's `blend_in` 8 f) — a tool artefact (request r3d-rig); the AnimViewer strips and boards start correctly. No clip is a draft (the R19 cut line was never reached). Scores 1–5 on
funny / readable / fresh; the bar is ≥ 4 funny and readable on the dizzy spin, ≥ 3 on every other clip.

**Caveat for every face beat (lead note D8).** The face beats carry sidecar `gaze` entries (`look_camera`, weight
0.6–1.0, 4–8 f eases). `RigPlayer3D` / `CharacterView3D` do not honour sidecar `gaze` yet, and the view drives the
cheat from its own table (idle 35°, walk 20°) rather than the clip's `cheat_deg`; the rig *yaws* with facing (it
does not mirror), so a baked head turn toward the camera would turn away in the other facing. The clips that play
facing either way (the bit, the last beats, the loops, the micro-gag) therefore keep every glance within ≈ 24° of
yaw and never bow the head under the bouffant for a face beat; only the dizzy spin (fixed staging, facing −1) turns
the whole body to the house. Request filed (report §Requests, r3d-view3d).

## The FINAL three

### `rx_dizzy_spin_a` (169 f, base, lock sim — ALLEGRO-GO-GO!'s payoff, the Prologue's second prank)
- **Silhouette at phone size?** Yes, every beat changes the outline: the singing carriage with the baton (f0) → the
  needle-screech flinch (pop f3: arms in, head back) → the chipmunk babble, conducting at ×3 with a jerky head bob
  (f12–33) → the wind-up crouch (f34–36) → up onto the tip of the LEFT slipper and spinning like a top, arms flung
  wide, coat tails flying: 3 turns + 32° (f39–80, `dizzy_strip.png` rows 3–5 show front / back / front) → the top
  wobbling round its toe, rising onto the point as it slows (f70–84) → COLLAPSE (f86) onto his bottom → the dizzy
  hold on the floor with the vinyl notes orbiting the bouffant (f89–149) → he shakes the notes off, spins back 32°
  on his bottom (f150–155), tucks and springs up (f154–161) and glares (f161–169).
- **Anticipation opposes the accent?** Yes: f70–86 he rises tall onto the point, arms up (the slowing top); the
  accent drops everything down and out (L07 clean).
- **Accent ≤ 4 f with a pop?** f86–89, pop key f86, hit-stop 5, cam punch 1.4 (in 11 / hold 70 / out 21, yaw 4),
  shake 0.45, jiggle on the bouffant / belly / tails; `thud` on the landing contact f88.
- **≥ 30 f hold where the face reads?** f89–149 (60 f): `dazed_open` → `dazed`, the body turned +32° past the
  station yaw so the seated face is on the camera (35 + 32 = 67° toward the house), runtime gaze 0.6 on top.
- **One overshoot?** f92 (out_back: the squash rebounds, the notes pop to 1.25 and settle to 1.0).
- **SFX on the frame?** `record_scratch` 0, `vo_bellows_dizzy_babble` 12, `spin` 40, `thud` 88, `dizzy_tweets` 89,
  `vo_bellows_ugh` 149 — each on a beat start / contact (L14 clean); no audio-table row → audio "own" (rows for
  r3d-integrate). The laugh event (tier auto) is f94, after the squash settles.
- **Face swap on the accent?** f86 `dazed_open` (f78 `terrified` on the wobble before it).
- **Sliding / floor?** The spin pivots on the left toe tip pinned at the root's origin (the pelvis moves over it, the
  root turns about it): no foot slide, no root travel; exact IK holds f0–35 and f158–169; soles never below the
  floor (L12/L13/L27 clean). Frame 0 = act_warmup's evaluated f30 (the ALLEGRO trigger), eased into the flinch by f2.
- **In game** (`boards/ingame_dizzy.jpg`, rendered frames 654–692): the flinch and the toe spin read even at
  ≈ 4 clip frames per rendered frame; the collapse lands exactly on the ALLEGRO-GO-GO! label and the punch-in; the
  seated dazed hold with the stars fills the punch-in (≈ 1 s); he is up again as the camera pulls out.
- **Fresh?** The cast's only full-body spin; a 3D-native gag (the turns show front, back, front).
- **Weak spots:** at the game camera the V of the raised legs mostly hides behind the barrel (the seated read comes
  from the height drop and the notes); the in-game label sits over his head on the first punch-in frame (the view's
  label placement); the Stalls silhouettes cover the slippers during the punch-in.
- **Scores:** funny 4 · readable 4 · fresh 4.

### `cue_doorframe_bonk` (36 f, overlay `upper` over `loco_blind_shuffle`, the `laugh_doorframe` cue)
- **Silhouette?** Groping blind (the bouffant flipped over his eyes, f0) → leans in (f3) → BONK (pop f4: both arms
  thrown up, head snapped back) → recoil (f7) → reel (f11, arms back) → the camera-side LEFT glove rubs his brow on
  IK riding the face socket (f12–31) → groping again (f36). `cue_doorframe_bonk_strip.png`.
- **Anticipation** f0–3 (lean in, arms low and forward) → **accent** f3–7 (up and back; L07/L18 clean).
- **Hold** f7–31: the rub; the face is under the flipped bouffant by design (he is blind), so the hold reads by the
  hand on the head, not the face. **Settle** f31–36 back onto the shuffle's arms.
- **SFX:** the audio table's `woodblock_bonk` 4 (the pop) and `vo_bellows_oof` 7.
- **In game** (`boards/ingame_cues.jpg`, top row): CueStager3D turns him to the camera on the bonk with the stars —
  the arms-up + stars read at the wide hall camera; the view turns him back into the walk after ≈ 1 rendered frame,
  so the rub reads less than in the strip.
- **Scores:** funny 3 · readable 3 · fresh 3.

### `cue_picture_bonk` (48 f, overlay `upper` over the livid stomp, the `laugh_picture` cue)
- **Silhouette?** The haughty stomp (f0) → chin up, arms swung back (f6–11) → BONK (pop f12: the head squashed down
  into the frame, shoulders up round his ears, fists out) → deepest squash (f15) → he looks down at the frame round
  his neck (f18–29, chin 19° down so the face stays out from under the bouffant) → the framed slow burn to the Stalls
  (f30–40, fists trembling, gaze 1.0) → "Hmph!" chin toss (f41) → stomps on (f48).
- **Anticipation** f6–11 (up and back) → **accent** f11–15 (down and forward; the accent beat opens on the last
  chin-up frame so the pop and the squash sit inside it — L07). **Hold** f15–40, **settle** f40–48.
- **SFX:** `bonk` 12 (the pop), `vo_bellows_hmph` 40 (the settle) — audio "own"; the crash is the cue's.
- **In game** (`boards/ingame_cues.jpg`, bottom row): the stager faces him to the camera; the stars, the head-down
  and the glare read. The picture frame itself does NOT show: CueStager3D lends `parlour_picture_frame` to
  `socket_node("head")`, which the Bellows rig does not have, so it falls back to the root (request r3d-view3d).
  Without the frame round his neck the look-down reads as "ow, my head".
- **Scores:** funny 3 · readable 3 (4 once the frame hangs on him) · fresh 3.

## The other seven (all authored as real clips — no drafts)

### `bit_livid` (120 f, base, lock sim — the squeak bit at Livid)
- Rigid (f0–6) → the enormous breath, arching back, fists drawn behind the barrel (f6–22) → the coil, leaning in
  with the right slipper hauled up off its print (f21–29) → STAMP + "WHO SQUEAKED?!" (pop f30: the slipper slams back
  on the same print, arms flung up, head thrown back at the ceiling) → the trembling rage aria (f33–57) → the fists
  hammered down (f57, `meltdown_stomp`) → glares round the room, left then right, each kept within ≈ 24° of yaw so
  neither turns the face away (f78–104) → harrumph (f110) → the livid stance (f120).
- Anticipation f6–29 against the accent, accent f29–33 (pop 30), hold f33–78 (45 f), settle f78–120. Voice
  `vo_bellows_who_squeaked` on the pop (the clip owns the bit voice: the AudioDirector skips its own), `stomp` 30.
- Weak spot: the aria is at the ceiling, so the livid face reads as an open mouth under the specs, not a full face.
- **Scores:** funny 4 · readable 4 · fresh 3.

### `loco_stomp` (26 f loop, `walk@tier3`, 1.38 m/s, stride 0.598 m)
- Head down like a bull, the barrel pitched forward, fists pumping ±58°, each slipper hauled up 15.5 cm and SLAMMED
  down (contacts f0 / f13 = `stomp`), the jolt through the spine and a sharp nod on every contact, a puff of ear
  steam once a cycle (fx `steam` f0). In place (the planted foot slides back at exactly the walk speed; L12 clean).
- In game (both e2e runs, rendered frames ≈ 700–770): the stomp reads at the wide camera; the steam puffs trail him.
- **Scores:** funny 3 · readable 4 · fresh 3.

### `act_hunt` (180 f loop, the standing part of the hunt, specs on)
- Crouched creep on IK, fingers curled like claws: peers low to his right, sniffing (f0–36) → snaps up and glares
  over his specs (f38–56, `furious`) → peers high (f60–90); the same to his left (f90–180) — each half is one
  "look this way" beat matching the sim's 1.5 s search turns, so a facing flip never catches him mid-glance.
- Weak spot: one of the two low peers always faces away from the camera (facing +1: f96–120, `sheets/act_hunt_phone.jpg`;
  facing −1: f0–36): it reads as nose-to-the-floor "look over there", not as a face beat; both glares read in both
  facings.
- **Scores:** funny 3 · readable 3 · fresh 3.

### `mg_peer_under_piano` (60 f, overlay `upper`, the hunt's micro-gag)
- Bent double (spine 44° + 34°), the left glove braced on his knee, the right shading his specs, nose an inch off the
  floor, the magnified eyes swivelling (f12–38) → "Hmm." (f38, `vo_bellows_hmm`) → heaves up with the gloves on the
  small of his back (f48) → upright (f60). Captured over the stomp (it fires 2.5 s into the hunt walk); `boards/peer_under_piano.jpg`.
- **Scores:** funny 3 · readable 3 · fresh 3.

### `beat_dignity_fail` (70 f, T3 last beat)
- Both gloves on the cravat (IK), tugging it straight with a little shimmy (f0–26, `cravat_tug` 2) → chin up, the
  lofty "ahem" survey of the house, 12° one way (f34) and 12° the other (f46) → satisfied (f57) → PING (pop f60: a jolt back, arms out, the cravat
  flies −80°, `cravat_ping`) → mortified, eyes down at it, chin only half down so the face stays readable (f64–70).
- Facing-proof (review pass 3): the survey used to turn 26° to his left, which at facing +1 put the back of the
  bouffant to the camera for f30–36; now ±12°, the face stays in profile or 3/4 in facing +1 and turns full-on to
  the camera on the "ahem" in facing −1 (`boards/dignity_facings.jpg`, both rows at the game camera).
- Weak spot: the cravat is small at the game camera; the tug reads as "fussing at his collar", the ping by the jolt.
- **Scores:** funny 3 · readable 3 · fresh 3.

### `beat_bow_topple` (60 f, T3 last beat)
- A grand courtly bow to the Stalls, one glove on the belly, the other flourishing, going on and on (pelvis pitch
  0 → 62°, `bow_creak` 4, f0–30) → the slippers leave the floor (f30, `slide_down_short`) → SLAP flat on his belly
  (pop f34, `slip_thud`, shake) → rocking on the barrel like a beached tortoise, arms and slippers paddling (f34–60).
  The root and pelvis stay on the spot (L27); the barrel's front rests on the boards.
- **Scores:** funny 4 · readable 4 · fresh 4.

### `beat_tear` (60 f, T3 last beat)
- The fight goes out of him: shoulders sag, gloves clasped at his heart (IK), the lip trembling (f0–24) → a single
  tear (f24, `teary`, `tear_plink`) → he holds it, wobbling (f24–40) → an enormous SNIFF (f42, `sniffle`): chest out,
  chin up → the brave pompous "perfectly fine" with a glove on his lapel (f42–60). The sag now bows the head 9° (was
  18°) so the face stays out from under the bouffant.
- Weak spot: the tear is a face-card beat; at the game camera the face is ≈ 25 px, so the clip reads by the sag →
  sniff silhouette change and relies on the runtime gaze.
- **Scores:** funny 3 · readable 3 · fresh 3.
