# Pivot options — where to take Mischief Next Door before building more

Date: 2026-11-04. Owner's brief: *P1/P5 made it better but it is still the same game. I want completely
different animations and gameplay mechanics — redesign from scratch before adding complexity. Look at the
options first: a redesign, a new engine, or more noticeable improvements on the current system.*

This document is the look at the options. It ends with a recommendation and a two-week plan to settle it on
the phone rather than on paper.

---

## 1. The test any pivot has to pass

`docs/review/depth/index.md` measured the current game: on its best route the player makes 37 inputs in 138 s,
holds a button for 6.4 s in total, and spends 56 % of the Night on fast-forward. The comedy is authored and
performed *at* the player. So the test for a pivot is not "is it more complex" but:

> **Does the player cause the comedy with their hands, moment to moment, and can they do it a different way
> next time?**

Two secondary tests, because they decide whether the thing can actually be built here:

- **Animation that is not hand-keyed.** 148 clips were the slowest, least agent-friendly part of this project.
  Procedural, spring, IK and physics motion is *code*: Claude Code builds it well, tunes it against the existing
  `stability.py` numbers, and it produces infinite variety for free. Any pivot should move animation that way.
- **Judgeable in a week on a phone.** A pivot whose first prototype cannot be felt inside a week is one we cannot
  afford to be wrong about.

---

## 2. What exists, and what each option keeps

| Module | Size | What it is |
|---|---|---|
| `game/sim` | 9.4k LOC | deterministic 60 Hz world: routine, senses, temper, pranks, residue, scoring |
| `game/view` | 22.6k LOC | rig player, clip map, atlas, camera, FX, world/prop views |
| `game/ui` + `scenes` | 15k LOC | HUD, input router, Night scene, stage door, results |
| `game/solver` | 5.8k LOC | planner, executor, metrics, invariants, fuzz |
| `game/tests` | 23.6k LOC | 1,113 tests |
| `tools/art` (Python) | 22.9k LOC | SVG part generators, pose + clip authoring helpers, validators |
| Art / audio / clips | 820 SVGs, 396 wavs, 148 clips, 13 rigs | the cast, the house, the sound |

The house, the cast's look, the sound library and the review toolchain (`sandbox / shot / capture / stability`)
survive every option below. What varies is how much of the **sim, the clips and the solver** survive — and
whether that even matters, because the sim is not what is boring.

---

## 3. The options

### A. Physics Toybox — "everything in the house can be picked up"

**Fantasy.** Hush is a one-thumb puppet; every prop in the house is a rigid body. Drag the vase to the edge of the
mantel. Stack the pickle jars on the fridge door. Tie the rug to the gramophone. Bellows is an *active ragdoll*: he
walks his loop under animation, and the moment something hits him the physics takes over and he falls like a sack
of potatoes — then gets up, puts it back, and carries on. Nothing is scripted; the Script is a Goose-style to-do
list written *after* finding what is funny in the sandbox.

**30-second beat.** Drag a thing (continuous input) → it wobbles, it falls, it rolls → he reacts physically → he
tidies up (the loop re-arms itself) → you do it differently.

**What changes.** Everything the player touches. Animation becomes ragdoll + springs + IK with authored *poses*
blended on top (a bouffant that is a jiggle chain, a cravat that flaps, limbs that find the floor). The 148 clips
become reference poses, not timelines.

**Keeps.** Art (SVG parts become physics shapes), house layout, audio, HUD shell, camera, FX, the routine half of
the sim. **Loses.** Determinism (and with it the solver and most tests), the prank/residue/scoring sim as written,
the clip pipeline. Roughly **35 %** of the code survives; nearly all of the art does.

**Why it could be the one.** It is the lineage of the three games the research keeps naming — Goose, Octodad,
Human: Fall Flat — and the reason those are funny is that *the controls are the joke and failure is a laugh*
([Octodad post-mortem](https://www.gamedeveloper.com/design/octodad-dadliest-catch-post-mortem-pt-3-design)).
Infinite variety, no authoring per gag, replay built in.

**Why it could fail.** Physics comedy on a touchscreen is the hardest thing on this list to tune: Human: Fall Flat
is famously better to *watch* than to play; Octodad's reviews turned when the controls stopped being funny and
started being a chore. Godot's default 2D physics is unstable on joint chains — the current advice is the
[Rapier2D](https://supermatrix.studio/blog/how-to-make-a-physics-based-2d-ragdoll-in-godot) addon, angular limits,
continuous collision. The GDD explicitly ruled "a physics engine" out of scope (§10.1) and TECH built the sim on
integer maths for determinism — this option reverses an architectural decision, which is fine, but it must be
said.

**Spike (1 week).** One room, five rigid props, Hush as a dragged hand, Bellows as a 9-joint ragdoll on Rapier2D
walking a two-station loop with a get-up. No score, no HUD. Judge: do you laugh at a *fall you caused* in the
first two minutes, and is dragging on a phone pleasant after ten?

### B. Set the Stage — "rig the whole house, then raise the curtain"

**Fantasy.** The theatre framing finally becomes the game. Each Night has two phases. **Rehearsal:** the house is
empty, time is stopped, and you place and connect gadgets — a tripwire from the rug to the bellows, a bucket on the
door, a marble run down the stairs into the pickle shelf — from a toolbox, anywhere physics allows. You can
*test* any contraption with a tap. **Performance:** curtain up, Bellows walks his loop, and your machine either
plays like clockwork or goes gloriously wrong. Encore: do it better.

**30-second beat.** Place → connect → test (tap, watch, adjust) → place more → curtain → *watch what you built hit
him* → tweak and encore.

**What changes.** The verb set entirely: place, rotate, connect, test. Waiting disappears because Performance is
the payoff, not the wait. Chaining stops being a 6-entry table and becomes the thing the player *builds* — the
"chain 10 tricks" fantasy the research found players loved most, made into the core mechanic rather than a
scoring bonus.

**Animation.** Gadgets are physical (balls, boards, buckets, springs: deterministic kinematic physics, or Rapier2D
in Performance only). Bellows' reactions become **impact-driven**: the contraption delivers a force and direction,
and a small set of physical *archetypes* (knocked back, lifted, spun, doused, buried) is produced by springs and
IK from the hit, not from a hand-keyed 112-frame timeline. The existing clips become T3 "last beats" played after
the physics settles — the one place authored timing still earns its keep.

**Keeps.** Routine sim (he walks a loop and visits stations: this *is* the clock the player builds against), senses
(a rehearsal that fails = he sees the tripwire), temper and scoring, house, art, audio, HUD shell, the Script,
Curtain Calls. **Loses.** The prank catalogue as 32 bespoke tuples (it becomes ~12 gadgets that combine), the
item/container economy, the rig-hold verb, the stealth-while-rigging tension (stealth moves into Performance:
Hush can still sneak to re-arm or nudge). Roughly **55 %** of the code, nearly all of the content model's data
*shape*. The solver survives if the contraption sim stays deterministic — and it should: a kinematic gadget sim
is small, and a deterministic one keeps the whole test/solve/fuzz investment alive.

**Why it could be the one.** It is the biggest change in *what the player does* on this list while keeping the
sim, the story, the stage and the cast. The Incredible Machine lineage is proven on touch (Contraption Maker,
Rube Works, Crazy Machines on iOS) and has had **no notable mobile successor since 2015** — Rovio pulled Amazing
Alex and nobody filled the gap. Planning puzzles are also the most agent-buildable genre here: discrete,
deterministic, testable, and the Planner already does beam search over orderings.

**Why it could fail.** Builder games risk feeling like work; the comedy must live in the *test* button (every
test is a mini-show) and in the failure modes (a machine that misfires is funnier than one that works). Phase
structure can kill the "live" feeling the current build has. Touch placement needs big targets and snap points.

**Spike (1 week).** One room, six gadgets (ball, ramp, bucket, tripwire, spring board, string), a test button,
and Bellows walking one two-station loop with impact-driven knockback + get-up. Judge: do you *build* something
you did not plan, laugh when it misfires, and press Encore unprompted?

### C. The Chase — "he's after you; lay the traps while you run"

**Fantasy.** Flip stealth into pursuit. Bellows has seen you; he is coming, slowly, relentlessly, through the whole
house — Tom and Jerry, not Hitman. You run ahead through rooms and *lay traps in his path* in real time: kick the
rug, swing the door, tip the bucket, drop the marbles. Each trap he hits stalls him for a laugh and raises the
Applause; each one he dodges brings him closer. The Night is a 3–5 minute pursuit with three or four "breathers"
(he loses you, resets, you re-arm) and a big finale room.

**30-second beat.** Run (continuous) → see the room's traps glow ahead → tap two or three as you pass → look back:
he hits one, trips, you get ten metres → he gets up, closer → next room.

**What changes.** Pacing, completely. There is no waiting and no fast-forward because the pressure is the
pursuer. Input is continuous (tap-to-run with a destination, as Sneaky Sasquatch does — still no joystick) and
decisions are fast: which trap, which door, when to double back. Risk/reward is built in: a trap takes time to
set and he is coming.

**Animation.** Runs, trips, slides, bonks, doors in faces — the slapstick vocabulary that physics and springs do
*best*: a trip is a ragdoll for 40 frames and a spring-driven get-up; a door in the face is an impulse plus a
squash. Very little needs hand-keying.

**Keeps.** Nav graph, house, senses (he sees you = pursuit speed), the chase/wheeze/door-slam code that already
exists, art, audio, HUD shell, temper. **Loses.** The routine loop as the spine (it becomes the *breathers*), the
rig-hold verb, the stealth tension (replaced by pursuit tension), the bulk of the prank catalogue. Roughly
**50 %**. Deterministic — the solver and fuzz survive and the fairness invariants become "no unavoidable catch".

**Why it could be the one.** It is the cheapest option to *feel*: the chase already exists in the sim, the house
is already a chain of rooms, and a one-room spike is two or three days. It directly tests the hypothesis that
waiting is the disease. Tonally it is the most slapstick of all of them.

**Why it could fail.** Pursuit on a phone can read as stress, not comedy, and the current cast's charm is that he
*doesn't know* — pursuit throws that away. It is also the closest to a known mobile shape (Robbery Bob) and would
need its own identity (the stage framing: he is chasing you *across the set* while the audience roars).

**Spike (3–4 days).** Three rooms, four trap types, Bellows pursuing at a tuned speed with ragdoll trips and a
get-up, tap-to-run. Judge: heart rate up *and* laughing? Did you want to run it again immediately?

### D. Board Farce — "a stage in miniature, one move at a time"

**Fantasy.** Hitman GO's lineage: the house as a diorama board; Bellows moves one node per turn along his visible
route; Hush moves one node per turn; traps are placed on nodes; the show plays out as vignettes when he lands on
one. Pure planning, zero reflex, three objectives per board.

**What changes.** Time. Everything else stays — which is the point and the problem.

**Keeps.** Almost everything: the sim is already a tick-based graph with a visible route, so turns are a
presentation layer; the solver is a *perfect* fit; the clips are the vignettes. Roughly **75 %**.

**Why it could be the one.** Lowest risk, highest testability, excellent on touch, strong star-gating structure.

**Why it is probably not the one.** It fails the owner's brief twice: the animations are the *same* clips, and the
mechanics are the current ones made discrete. It is the right fallback if A–C all disappoint, not the pivot.

### E. Stay and deepen — P2 / P3 / P6 (the depth review's plan)

Two ways to sabotage each station, nine live pranks with four required, three reaction variants. Roughly **95 %**
kept, 4–6 weeks, measurable improvement in `ff_share` and `route_diversity`. **The owner has already said this is
not what they want**, and the measurement agrees that it would make the same game deeper rather than a different
game. Listed for completeness and as the baseline the spikes are judged against: *would you rather play this
spike than the current build plus P2/P3?*

---

## 4. The engine question, answered directly

**Stay on Godot.** The reasons, in order of weight:

1. **The problem is design, not engine.** Nothing in §1's diagnosis is an engine limitation. The 3D attempt
   already reached this conclusion the expensive way (`docs/review/cast3d/index.md`: the gap was the character
   pipeline, not the engine).
2. **Every option above is buildable in Godot 4.** 2D rigid bodies and joints are built in; joint-chain ragdolls
   want the Rapier2D addon for stability; spring secondary motion is built in (`SkeletonModification2DJiggle`) and
   the codebase already has its own `Springs`/IK layers in `view/rig`. 3D ragdolls, if A went 3D, are
   `PhysicalBone3D` on Jolt.
3. **The review loop is the owner's only instrument and it is engine-specific.** `sandbox.sh`, `shot.sh`,
   `capture.sh`, `stability.py`, the e2e driver and the solver are months of work that make Claude Code's output
   checkable on this machine. An engine change throws them away and restarts the cycle that produced §1.
4. **What Unity would buy** — a bigger asset store and more mature 3D ragdoll tooling — only matters if the chosen
   pivot is *3D physics comedy with bought characters*. That is option A in 3D, which is the highest-risk branch of
   the highest-risk option, and the 2D cast you have is already the thing people like about the build.

If after the spikes the answer is "A, in 3D, with Mixamo-style characters", revisit this section. Otherwise the
engine is settled.

---

## 5. Recommendation

**Spike B (Set the Stage) and C (The Chase) in parallel, in throwaway scenes, and decide on the phone in two
weeks.** Build a shared **procedural-animation layer** first, because both need it and it is the piece that makes
the animations "completely different": a ragdoll-on-impact Bellows with spring get-ups and jiggle secondary
motion, on the existing SVG parts.

Why these two and not A first: B is the pivot with the largest change to *what the player does* that still plays
to this project's strengths (deterministic, testable, the stage framing becomes structural, the chain fantasy
becomes the core verb). C is the cheapest to feel and the sharpest test of the waiting hypothesis. They are
opposite in energy — plan-then-watch versus run-and-react — so whichever one lands tells you what kind of game
you actually want. A is the highest ceiling, but it is the one most likely to eat three weeks of physics tuning
before you can judge it; if B's test button and C's trips feel good, A's lesson (physical comedy) has already been
absorbed into whichever you pick. D stays in the drawer as the safe fallback.

### The two-week plan

| Days | Work | Output on the phone |
|---|---|---|
| 1–3 | **Procedural cast.** Bellows as a 9-joint 2D ragdoll (Rapier2D) that walks under the existing clips and goes physical on impact; spring get-up; bouffant/cravat jiggle. Hush as a one-thumb drag/run puppet. `stability.py` numbers on every capture. | a GIF of him hit by a ball from three angles, never the same twice |
| 3–7 | **Spike C** in `game/spikes/chase/`: three rooms, four traps, pursuit AI on the existing nav, tap-to-run. | an APK; one 3-minute chase |
| 4–10 | **Spike B** in `game/spikes/stage/`: one room, six gadgets, place/connect/test, one two-station loop, impact reactions. | an APK; one room to rig, test and perform |
| 11–14 | **Owner plays both, twice each**, answers §6, writes the verdict in PROGRESS. | the decision |

Rules for the spikes, so they stay cheap and honest: no tests, no lints, no HUD beyond what the spike needs, no
content JSON, nothing committed to `game/data`. Reuse art and audio freely. Each spike ships with a 60-second
capture and its `stability` report. Everything in `game/spikes/` is deleted when the pivot is chosen.

### How Claude Code should be briefed for the spikes

The depth review's lesson applies doubly here. Brief each spike with the **feel target and the measurement**, not
a specification: *"Three rooms, four traps, he chases at a speed where a good player stays one room ahead; I
should laugh at a trip in the first minute; capture it and tell me the jitter."* Let the agent pick structures.
Review captures, not code. One spike per worktree, one change per capture.

---

## 6. Judging the spikes (the Fun Gate for prototypes)

Answer after two plays of each, on the phone, in `docs/PROGRESS.md`:

1. **Did you laugh at something you caused**, unprompted, in the first two minutes? (The only question that
   matters; the current build fails it.)
2. **Did you ever want a fast-forward button?** (There isn't one. If you wanted one, waiting is still in the
   design.)
3. **Did you replay by choice**, and did the second play go differently because *you* chose differently?
4. **Could you describe it to a friend in one sentence**, and does the sentence sound like a game you would buy?
5. **Would you rather play this than the current build with P2/P3 added?**

Three or more clear yeses on one spike: that is the pivot. Both: pick the one with the better answer to Q1. Neither:
A gets its week, with D as the fallback.

---

## 7. What happens to the work on the tree

P1 (Meddle) and P5 (Clarence) are complete, tested and documented on the working tree, uncommitted. They are not
wasted: B keeps "every prop answers" as a rehearsal-phase rule, and C keeps the toy squeak as the lure that bends
his pursuit. Recommend **committing them as the last change on the current design** so the spikes branch from a
green, measured baseline — and so the depth review's numbers remain the before-picture whichever way this goes.
