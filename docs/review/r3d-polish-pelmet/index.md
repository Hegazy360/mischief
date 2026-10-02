# r3d-polish-pelmet — the curtain-call pelmet CONTACTS his wig (D19 polish)

Key `r3d-polish-pelmet`. QA round 3 (3/3 reviewers, curtain call 3/3/3 PASS): *"the pelmet seems to hang just above his
head rather than rest on it"* — its fringe sat a few pixels above the wig through the hold (f570–690).

## Why it hovered

- The pelmet landed with its **rect's bottom** 30 px (1080 base) under `head_top`. The valance art
  (`curtain_valance.svg`, 1920×260) is solid fabric only down to **62 %** of its height; the scalloped fringe and tassels
  hang to ≈ 86 % and the last 13 % is empty. So the solid fabric stopped ≈ 28 base px (≈ 14 screen px) above the wig and
  only the tassel tips touched it: the full rounded crown showed under the fringe.
- Nothing on his wig reacted to the hit (the body squash only), and the 8-frame impact star covered the wig on the
  contact frames.

## What changed (game/scenes/night/curtain_apron.gd, curtain_bows_3d.gd)

- **The contact line is the fabric's edge** (`PELMET_FABRIC_K` 0.62), and it rests `PELMET_PRESS` (14 base px) into
  the top of his wig — `pelmet_state()` now returns `line` (the contact) as well as `bottom`.
- **The wig top comes from the rig, every frame** — `CurtainBows3D.wig_top_screen()`: the crown of the neat bouffant on
  the `bouffant` bone (0.296 m above its head, from tools/art3d/bellows/parts.py; = the `head_top` socket unsquashed,
  checked by a test), or a body-slot variant's own mesh bounds (`Att_bouffant_*`), squashed, projected through the lip
  camera. No fixed height: it follows his clip, the jiggle-free bone pose, the body squash and the wig squash.
- **The wig squashes on contact** — a `SkeletonModifier3D` (`CurtainWigSquash`, added last under his skeleton) scales
  the `bouffant` bone (a, sy, a) about a pivot 0.15 m below its head (the scalp line, so the wig never lifts off his
  head); variants squash through their holder transform about the same pivot. Curve `wig_squash_at()`: 0.6 for 3 f
  (flat and wide), springs back to 0.97 by f9 (lifting the pelmet), settles at 0.88 under its weight while the pelmet
  stays on (the topper and the glare). Reset on `hide_bellows` / `start_bellows`.
- **The pelmet squashes and rocks about the contact line** (`rock_at()`, ±0.06 rad, settled by 40 f), so it never
  lifts off the wig.
- **Whack lines + a small dust puff** replace the big impact star: 3 ink/cream lines out of each side of the wig (6 f)
  and two clumps of 5 dust puffs (`dust_puff()`, pure, Vector4 — no allocation) billowing out and up from where the
  fabric meets the wig, gone by 30 f. Nothing covers the wig on the contact frame: its squash is the read.
- Then the face hold, unchanged: `st_bonk` dazed face to camera with the stars for `BIT_HOLD_S` (60 f ≥ 30 f), the
  topper and the glare with the pelmet on like a crown.
- Staging unchanged (round 2): his mark x 0.28, `BIT_Z`, clear of the Gag Reel inset, Next ▶ and Retry.
- Also: the apron frees its pelmet control when nobody parented it (it leaked a CanvasItem per apron in tests).

## Frames (1200×540, `--no-captions`, MSAA off)

| file | what |
|---|---|
| `before_after.jpg` | the same frames before (this tree before the edits) / after, real-time NightScene `--curtain-call=prologue_done` at a fixed 60 fps (capture.sh): f495 contact, f497, f510 hold, f600 the crown, f680 the glare |
| `curtain_call_strip.jpg` | QA's strip on the final tree: `E2E_SANDBOX=r3d-polish-pelmet-e2e e2e.sh prologue_ideal --fixed --shot-seq=… --every=3 --count=240 --seq-from=3570 -- --no-captions --e2e-hold-s=13` (PASS, 0 fallbacks), a cell every 30 frames, labelled like QA's packet (f0 ↔ engine frame 3570) |
| `curtain_bonk_beats.jpg` | the same run round the hit, 1:1 crops: f480 wobble, f498 the ropes snap, f501 the drop, **f504 contact**, f507 the wig springs back, f513 the rebound + dust, f525–570 the dazed hold, f600 the topper, f645–690 the glare |
| `contact_f504.jpg`, `hold_f600.jpg` | the contact frame and the topper, full 1200×540 |

What I looked at (final tree, e2e strip): the pelmet's fabric edge lands ON the wig at f504 — the bouffant is flat and
wide under it, whack lines and two little dust clumps puff out of its sides, his face to camera (wide eyes); f507 the
wig springs back and lifts the pelmet, which rocks once; from f525 the fringe drapes over the top of the wig and the
pelmet stays seated on it through the dazed hold (stars), the cravat tug and the glare to f690 — no gap anywhere
between the fabric and the wig. Before (`before_after.jpg` top row): the tassel tips only grazed the wig and its full
round crown showed under the fringe, and the impact star covered the wig on the contact frames. Nothing new overlaps
the Gag Reel inset, Night 1 ▶ or Retry (the dust spreads ≈ ±110 px around his head, centre-left). Timings unchanged
(`bit_plan`: the 4 f drop, the ≥ 60 f hold, the reel waits for it).

## Tests

- `night/test_curtain_pelmet.gd` (new, 7): the valance art's alpha profile puts the contact line at its fabric edge;
  the wig squash curve (flat on contact, springs back, rests at 0.88) and the rock; the dust puffs (both sides,
  outwards and up, small, out of the wig's sides, gone by 30 f, capped); the fabric edge rests at the wig top it is
  given; **on the real rig**: the unsquashed crown = the `head_top` socket (< 6 cm), the modifier really scales the
  `bouffant` bone (read inside `skeleton_updated`), the squashed crown drops (0.296 + 0.15) × (1 − sy) m and comes down
  on screen; in the bit the pelmet's line is on his squashed wig on the contact frame and the wig rests squashed after;
  a residue variant (`frazzled`) uses its own bounds and its holder carries the squash.
- `night/test_curtain_call_table.gd`: the landing assertion now checks the fabric edge (`line`).
- `night/` 133/133 (with the variant test); the two curtain files leak nothing at exit now.
