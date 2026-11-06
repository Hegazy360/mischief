# Prototype 3 — THE KEEP

Date: 2026-11-07. Option 3 from `docs/review/pivot/2026_options.md` / `next_options.md` §D: a low-poly
3D toy sandbox on **library assets used exactly as shipped**, animated **only** by a library. Code and
assets in `game/proto/toyhouse/`.

## What it is

A stone hall. A Knight goes about his day — sits in his chair, works at his bench, waves out of the
window, walks his rounds. You are the Rogue. Everything loose is physics: six crates, four barrels, three
buckets, fifteen books on a shelf, six plates on the long table, a ball. Tap the floor to run there; tap
a prop to pick it up; tap the Knight (or anything else) while holding to throw at it; THROW lobs it ahead.
Walking into things shoves them.

Hit him hard enough and he staggers (`Hit_A`), goes down (`Death_A`), lies there (`Lie_Idle`), gets up
(`Lie_StandUp`), looks round (`Idle_B`). If he sees you, he chases (`Running_A`) and, if he catches you,
knocks you flat and celebrates (`Cheering`). If he does not see you, he notices what you moved, walks over,
picks it up (`PickUp`), carries it home and puts it back (`Interact`) — then carries on with his day.

## The rule, kept to the letter

* **Characters:** KayKit Adventurers (CC0) — the Knight and the Rogue, textures and all, untouched.
* **Animation:** KayKit Character Animations (CC0) — six library files merged onto each character by bone
  name. **Not one frame in this prototype was made here.** The October attempt failed because those same
  assets were re-dressed into our 2D cast; this time they are the cast.
* **Environment:** primitives and a palette. No modelled art.
* Licence file ships beside the assets.

## What the build process caught, in order

These are worth recording because every one would have reached you as "it doesn't work", and every one
was found by a trace or a self-test rather than by eye:

1. **The carried crate fired the Rogue out of the hall.** A frozen `RigidBody3D` is a *static collider*;
   parked in front of her chest every frame it pushed her backwards, the crate followed, and the feedback
   loop accelerated her through the front lip into the void. Fix: a carried prop leaves every collision
   layer (`KayActor.hold_prop` / `release_prop`). The Knight's tidy-carry had the identical bug.
2. **The Knight never reached his chair.** The seat collider held him 0.4 m short of a 0.3 m arrival
   radius, so he stood beside it for ever and never sat, worked or waved. Fix: a visual-only seat, a wider
   arrival radius, and a stall rule ("barely moving for a second = arrived") for both actors.
3. **Every tap hit the invisible front wall.** Added so nothing could leave the hall, it sat between the
   camera and everything else, so taps never reached a crate or the Knight. The scripted demo masked it
   (it calls the actions directly); the input self-test caught it. Fix: the tap ray excludes the fence.

## Verified

* `--clicktest` (synthetic taps through the real input path): floor tap moves her 5.1 m; crate tap →
  holding; Knight tap while holding → thrown. **PASS 3/3.**
* `--demo --trace`: sitting → throw → `HIT` → `DOWN` → `GETUP` → `ALERT` → `TIDY_PICK` → `TIDY_CARRY`,
  one knockdown, zero catches — the whole loop, in one trace.
* Shipping game untouched: suite 1,113 green, all lints green.
* Captured stills: `docs/review/pivot/spikes/keep_*.png`.

## Honest state

* One room, one NPC, 35 props, four stations. No sound, no goals, no score beyond a knockdown counter.
* The camera is a fixed three-quarter follow with a lean toward the Knight; pinch/wheel zooms.
* The Knight's sight is a 63° cone to 11 m with no occlusion — crates do not hide you yet.
* Characters are KayKit's native 2.2–2.6 m, so the hall is built big to match.
* Library clips have no "carry while walking" — he and she carry with the plain walk.
