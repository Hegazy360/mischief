# Spikes A and C — what was built, and how to judge them

Date: 2026-11-05. Built against `docs/review/pivot/index.md` §5. Throwaway code in `game/spikes/`:
no tests, no lints, no content JSON, nothing in `game/data`. The whole folder is deleted once a
direction is chosen. The shipping game is untouched — suite 1,113 green, all lints green, solver
identical to the decimal.

## The one thing both spikes change

Neither spike plays a single keyframed clip. The 148 authored clips are not used at all. Instead
`game/spikes/common/rag_cast.gd` (≈320 lines) rebuilds both characters from the **real** rig files and
**real** SVG parts, and moves them procedurally:

* **Active ragdoll.** Every joint is an angular spring with one `muscle` number. At 1 the springs chase
  a procedural pose; at 0 they go limp and gravity torque swings each limb toward hanging. `hit()`
  drops the muscle to 0 and throws the body; once it has lain still for a third of a second the muscle
  ramps back and he scrambles up. That one number is the whole comedy, and it is never the same twice.
* **Procedural walk.** A sine cycle over hips, knees, arms and a waddling torso, scaled by speed. Any
  speed works, including a blind stagger at 45 %.
* **Secondary motion.** The bouffant, cravat, coat tails, sideburns and beret are jiggle springs driven
  by the body's own acceleration.
* **Faces** swap variants on impact (eyes wide, mouth open) and back again on recovery.

Measured on the bench (`spikes/common/CastTest.tscn`, fixed camera, `tools/anim/stability.py`):
**jitter 0.07, pops 0, smooth 97/100** — against a library band of 0.14–0.25 and the 0.42 that the 3D
cast scored when the owner called it unstable. `cast_flop_and_getup.png` is the frame strip: both
characters land flat on their backs, splayed and readable, then scramble up.

**Three bugs worth recording**, because they are the kind a spike exists to find:

1. Limp limbs that only have gravity torque collapse into an unreadable heap. They need a little tone
   even when dead (`LIMP_TARGET`, a weak spring to a splayed pose) or the gag does not read at size.
2. Settling on a per-frame "am I touching the floor" flag never works: as the body rotates into its
   lying pose the contact point keeps changing, contact flickers, and the still-timer resets for ever —
   he lay on the floor for four seconds. A 0.18 s coyote window fixed it.
3. Spin needs air drag, not just contact damping, or a thrown body pirouettes for ever and ends up
   balanced on its head.

## Spike A — Physics Toybox (`spikes/toybox/ToyboxSpike.tscn`)

Everything loose in the parlour and the kitchen is a `RigidBody2D`. Press a prop, Hush picks it up;
drag it and she hauls it; let go with a flick and it flies. Anything that reaches Bellows above
520 px/s knocks him flat. Then he gets up, notices the mess, carries the prop home and carries on —
the Goose "NPCs tidy up" loop, which is what makes the gag re-enterable.

Eight props, two stations, no script, no prank list, no scoring beyond a knock-down counter.

`toybox_strip_1.png`: Hush walks to the kettle, hoists it over her head, and flattens him with it.
`toybox_strip_2.png`: he lies there, scrambles up, and walks off to tidy.

## Spike C — The Chase (`spikes/chase/ChaseSpike.tscn`)

Three real rooms (hall, parlour, kitchen). He has seen you and he never stops coming. You run ahead
and set traps in his path: rug (trip), marbles (skid), bucket (blind for 4.5 s at 45 % speed), door
(bonk backwards). Eight trap sites.

The tension comes from one rule: **setting a trap costs you.** Tapping a gold trap sends her to it and
she must crouch over it for 0.42 s while he closes. The house has two ends, so running for ever is not
an option. Catch = she is flung clear, he is stunned, every trap resets.

`chase_strip_1.png` / `chase_strip_2.png`: traps arming (gold → red), him tumbling, the lead opening up.

Measured: **no frozen frames and no pops across a 9-second run** — there is no moment where nothing is
happening, which is the hypothesis this spike exists to test. (The toybox still has one ~1.3 s frozen
stretch: him lying on the floor. That is the intended comic beat, not a hang.)

## Known rough edges (deliberate — these are spikes)

* The first 8 frames of any capture are the scene building; `stability.py` scores them as pops. Ignore.
* `stability.py` measures whole-frame change, so in a **scrolling** scene the camera dominates and
  jitter is meaningless. Only the bench numbers above are comparable to the library band.
* Traps are drawn as coloured blocks, not art. Grey = out of reach, gold = tap me, red = armed.
* No sound in either spike.
* The toybox camera follows Hush, so Bellows can tidy off-screen. The real game's PiP solves this.
* Hush can be knocked over by her own thrown props in the toybox. It is funny; it is also unhandled.
