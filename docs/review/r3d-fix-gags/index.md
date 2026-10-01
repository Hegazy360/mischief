# r3d-fix-gags: QA round 1, fix round 1 (Q-G1 to Q-G6, Q-V2, fix-hud R1)

QA round 1 scored 6 of the 9 gag strips under their bar (`docs/review/r3d-qa/readability.md` §6). The fresh reviewer could
not see the **cause** or the **contact**: it happened off frame, behind his body, inside the small Bellows window, or with
his back to the camera. This page re-shoots every Prologue gag on the same route and at the same ticks: `prologue_ideal
--fixed`, 1200×540, `--no-captions`, MSAA off, a DevShot frame every 3 ticks. The strips use the reviewer packet layout:
2 columns, half scale, frames numbered from f0.

- **before/**: the exact packet pages the reviewer judged (`docs/review/r3d-qa/packets/set_e/pkt_0N/page_*.jpg`).
- **after/**: the same moment from the final tree (run `v8`, 13:00Z, `--strict`).

Every change is view-only. The sim, `reactions.json` and the clip lengths are unchanged, and no clip was re-baked in this
pass.

| gag (P00 ideal tick) | QA score (funny/readable/fresh) | bar | before | after |
|---|---|---|---|---|
| dizzy spin (accent t2659) | 3/3/4 | 4/4 | `before/dizzy_spin_{1,2,3}.jpg` | `after/dizzy_spin_{1,2,3}.jpg` |
| doorframe bonk (t1677) | 2/2/2 | 3/3 | `before/doorframe_bonk_{1,2,3}.jpg` | `after/doorframe_bonk_{1,2,3,4}.jpg` |
| picture (t3273) | 1/1/1 | 3/3 | `before/picture_{1,2,3}.jpg` | `after/picture_{1,2,3}.jpg` |
| vase (t138) | 1/2/1 | 3/3 | `before/vase_{1,2,3}.jpg` | `after/vase_{1,2,3}.jpg` |
| squeak bit (t230) | 1/3/1 | 3/3 | `before/squeak_bit_{1,2,3}.jpg` | `after/squeak_bit_{1,2}.jpg` |
| relief (t3238) | 1/3/1 | 3/3 | `before/relief_{1,2,3}.jpg` | `after/relief_{1,2,3}.jpg` |
| the dive (verb pkt_01, g0 ≈ t321) | verb right, direction wrong | — | QA `packets/set_a/pkt_01.jpg` | `after/dive_before_after.jpg` |
| his bubble at the left edge (crowd pkt_06, P00 frame 2190) | "half visible" | — | QA `packets/set_c/pkt_06.jpg` | `after/bubble_edge_f2190.jpg` |

The scores need **new** fresh reviewers on a rebuilt packet with a new seed. I did not score my own strips.

## Q-G1: the dizzy spin
The reviewer said: "without sound it is unclear why he starts … forced to conduct".
- **He stands beside the gramophone.** A view-only 0.5 m sidestep at `st_gramophone` (`house3d.json` `bellows_dx`) keeps the
  turntable, horn and lever in view, and the sidestep holds through the reaction.
- **The record runs away on screen at f18–45.** Big inked notes jet out of the horn (6 bursts, 9 f apart). The horn
  swings and pulses, and the whole cabinet rattles for 1 s (Prop3D `play`). White flecks whirl off the turntable twice.
- **The spin reads in a still.** Inked dust puffs whirl on a floor ring round his toe and on a waist-high ring, so the
  cartoon top / whirlwind silhouette shows in the 0.73 s, three-turn spin. The collapse, the notes orbiting his head and
  the face push-in are unchanged.

## Q-G2: the doorframe bonk
The reviewer said: "nothing lands … his face only shows briefly".
- **The contact.** He stops dead at the parlour|kitchen wing flat, his face at its edge (a view pin), with a 1.3 punch-in
  on his head. On the accent a big white impact star flashes where his head meets the edge. Then a plaster puff comes off
  the edge, plaster sifts down from above, and inked stars spin round his head.
- **The frame takes the hit.** The wing flat rocks on its base, its top away from him (2.2°, gone in 30 f).
- **The dazed hold.** He plays `st_bonk` instead of the hunt walk: head into the collar, then groggy, his face to camera
  (f96–108). His thought bubble steps out of the close-up.

## Q-G3: the picture
The reviewer said: "the fall is hidden … a muted square … he walks on the spot".
- A 1.2 cue shot frames him at the doorway, so the fall is on screen. The frame is gilt round a dark portrait
  (`palettes.py`, `build.py`, `picture_frame.glb`).
- It lands with THUNK stars and a jolt. He stands stunned (`st_bonk`) while it rides askew on his bouffant, never walking
  on the spot. His bubble fades out of the close-up.

## Q-G4: the vase
The reviewer said: "no clear cause or effect … a small grey object".
- The curtain rises on **him and the vase** (a cue shot until Hush's climb-in), so the cause is not only in the small
  window.
- Each warm-up note flies from his mouth to the vase and nudges it along the mantel. From the third nudge it rocks on
  its base, harder with every note, then tips and drops.
- The vase is ×1.5 (the live-prop rule) in blue-and-white china against the pink wall. The crash jolts the frame and
  throws a bigger inked puff.

## Q-G5: the squeak bit
The reviewer said: "no prank is set or sprung"; in the verb test, "fiddling with something small and yellow".
- The squeak's answer, his head snap, plays in the **escalated** Bellows window: it punches to the big size for 1.8 s.
- At Clarence's beak there is a yellow burst, then two sound rings, camera-facing rings of bright dots that swell
  outward 7 f apart.
- Hush is kept clear of the action button at the kitchen window: the camera may go up to 1 m past C2 to clear her.
- Clarence swells on the squeeze: `act_squeak` scales the prop bones ×2.4 across. This shows now that r3d-fix-perf's
  RigMods3D MODE_SOCKET keeps the baked prop scale (11:40Z).

## Q-G6: the relief
The reviewer said: "a walk-off, not a gag: the near miss is not shown".
- **A two-shot.** While he hunts within 1.7 m of her hiding spot, a 1.3 two-shot holds him and her eyes in the gap
  behind the piano. The eyes are 1.6× larger there.
- **The near miss**, timed off his hunt running out (that is what fires `laugh_relief`). 46 ticks before the cue he
  turns to peer straight at the gap. 22 ticks before it her eyes sink out of sight. On the cue he turns away with a smug
  "nothing here" (`st_smirk`) to camera. Her eyes pop back up with a blink, big sweat drops fly off her brow, and the
  Stalls exhale. Then his bubble switches to the stairs (the change of plan).

## Q-V2: the dive
The reviewer said: "diving out of the wardrobe".
- Through `state:diving` her body turns away from the camera (cheat −85°, almost full back view, eased in 0.07 s). The
  flat-out flight is now seen from behind, going up and into the curtain alcove, and the legs tuck in last.
  `after/dive_before_after.jpg` shows the QA frame above and t312–324 below.

## fix-hud R1: his bubble at the left edge (P00 frame 2190)
- `Overlays3D` clamps his bubble so its **drawn** extent stays on screen: the glyph disc and ear pips 153 px left, the
  cloud lobe 127 px right, plus 8 px. With r3d-fix-perf's glyph flip, the glyph moves right of the cloud at the left
  edge, and the clamp then uses that side's extent (73 / 207 px). The placer rect is the same extent.
- The one-cloud rule is read back: when the last solve kept his bubble waiting, it fades on its own flag
  (`FxThoughtBubble.waiting`).
- `after/bubble_edge_f2190.jpg`: the whole bubble is on screen and the glyph sits right of the cloud.

## Tests
`game/tests/view3d/test_gag_staging3d.gd`, 10 tests:
- the sidestep;
- the dive turned upstage;
- the vase teeter;
- the cue pieces' data;
- Hush clear of the action button;
- a cue shot yields to a punch-in;
- the bonked flat's wobble;
- the ring and whirl bursts, and the shared pool resets them;
- the bubble clamp extents;
- the near-miss timing.
