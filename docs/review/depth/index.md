# Why it plays basic — a measured review, and what to change

Date: 2026-11-02. Owner's note: *"the gameplay is too basic, not engaging, and I'm not sure the
development process produces a high-quality gaming experience."*

This is the evidence for that feeling, the root cause, and a ranked set of changes. Everything below
is measured on the build at `2fadc01`, on the **ideal** route of Night 1 — that is, the game playing
as well as it can possibly be played.

---

## 1. What a Night actually asks of the player

Measured with `solve.sh n01_throat_tea --route=ideal --dump-cmds` and the run's own `Metrics` report.

| | Night 1, ideal route |
|---|---|
| Length | **138.2 s** |
| Total player inputs | **37** (14 `go`, 10 `rig` = 5 holds, 7 `pop_out`, 4 `squeak`, 1 `pick`, 1 `bow`) |
| Total time holding the rig button | **6.4 s** |
| Time on fast-forward (`ff_s`) | **76.9 s — 56 % of the Night** |
| Longest stretch with no input at all | **27.1 s** (then 20.0, 17.7, 15.5, 13.3, 11.8) |
| Live pranks in the Night | **5** |
| Script lines | 5 prank lines + the Big Number — **every available prank is also an objective** |

The required-lines route is 19 inputs over 79 s, with a 19.8 s gap.

So the best possible performance of Night 1 is: **37 taps and six and a half seconds of held button,
spread over two and a quarter minutes, of which the player spends more than half pressing
fast-forward.** That is the whole of it. The feeling of "basic" is not a mood — it is this table.

## 2. Why the existing gates all pass anyway

Every quality gate in the project is green: 1,105 tests, solver 21/21 routes, all four lints clean,
dead air 7.9 % against a 20 % limit, 60 fps. None of them measures whether the player is playing.

`Metrics` decides a moment is "alive" if **any** of six things is true — and the report for the ideal
route breaks down as:

| Reason the moment counted as alive | Share |
|---|---|
| `input` — the player did something (credit lasts 3 s per input) | 43.9 % |
| `laugh` | 19.2 % |
| `beat_pip` — a micro-gag seen in the picture-in-picture | 13.9 % |
| `beat_room` — a micro-gag seen in the room | 9.1 % |
| `reacting` — Bellows is mid-reaction | 5.9 % |
| (dead air) | 7.9 % |

Five of the six reasons are **things the player watches**. The dead-air gate — the project's flagship
anti-boredom measure, lead decision D1, with its own solver, its own rulings and its own section of
the GDD — is fully satisfiable by spectacle. A Night could have zero player inputs and still pass it,
provided Bellows keeps doing bits.

This is the central process failure, and it explains the whole situation: **the project measured
presentation exhaustively and agency not at all, so presentation got excellent and agency never
arrived.** The build is not sloppy. It is precisely what was specified and precisely what was gated.

## 3. The design root cause: authored one-offs, not systems

The content model makes every joke a bespoke tuple. From `pranks.json`:

- **32 pranks, each with exactly one `rig_point`, one `trigger`, one prep tier.** There is never a
  choice of *how* to sabotage anything.
- **4 to 6 pranks live per Night**, and the Script lists all of them. Nothing is discretionary, so
  there is nothing to choose, prioritise, or skip.
- **24 of the 32 pranks have a single reaction variant** (only `drench` a/b/c, `avalanche_helmet`,
  `blind_bumble` and `feather_burst` have more). The thing the genre's players praise most — "I'm
  writhing in laughter even though I've played the joke 20 times" — is authored once.
- **Chaining is a lookup table**, not an invention: 6 hand-authored Double Acts, 4 hand-authored
  combos. The player cannot discover a combination the designer did not write down.
- **The house is inert.** 60 hotspots across 10 rooms (33 of them rig points); on Night 1 about five
  of them do anything. Touching any of the others returns `cmd_rejected` → the `ui_nuh_uh` sound.
  The project's own market research lists "punishing curiosity — wrong combinations should get a
  small gag, never a fail" under *what to avoid*.

For comparison, the benchmark the research names: *Untitled Goose Game* has roughly 160 objects with
their own interactions, NPCs that systemically tidy up after you, and a four-person team that built
depth out of **consistency rather than content volume**. Its designers found their core rule — that
stealing is funnier when unobserved — by iterating toward a laugh and *then* formalising it as a
systemic rule. ([Road to the IGF](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i-),
[VicScreen](https://vicscreen.vic.gov.au/news/developing-a-horrible-goose-and-a-huge-following/))

Worth saying plainly: **the repo's own research already contains most of these answers.**
`docs/research/nfh.md` §13.15 recommends "more pranks than required per episode (e.g. 8 available,
5 to pass), with 2 ways to sabotage most stations, which answers 'pre-cooked'"; §13.2 asks for "at
least 3 random variants" per reaction. Neither reached the GDD. The research was done and then not
carried into the spec.

---

## 4. Gameplay changes, ranked by (impact ÷ cost)

### P1 — Give the world a default reaction. Delete "nuh-uh". *(cheap, do first)*
Any prop can be meddled with (Q prep, 0.8 s) even when it carries no scored prank. The next time
Bellows passes, he notices and fixes it: straightens the picture, tuts at the moved vase, re-folds
the paper, sniffs the swapped jar. One new systemic rule, reusing the micro-gag machinery that
already exists and the fix-up detour routing that already exists.

Why it matters more than it sounds: it converts 28 dead hotspots per Night into things that do
something, it rewards curiosity instead of rejecting it, it gives the player work during the 77 s
currently spent on fast-forward, and it is the Goose "NPCs tidy up" loop — a gag the player can
re-enter and escalate, rather than a one-shot.

### P2 — Two ways to sabotage each station. *(the real depth fix)*
Each station gets 2–3 rig options with genuinely different cost / risk / payoff. The kettle:
*squeaker* (Q prep, needs an item from the box, small laugh, activity resumes) **or** *over-fill*
(B prep 2.5 s, noisy — a 500 px ring every 0.5 s — bigger laugh, leaves SOAKED). Now rigging is a
decision with a trade-off, routes differ between players, and "pre-cooked" stops being true.

`rig_point` is a field on the prank, so several pranks can already share a station; the new work is a
pick UI when more than one is available at the station Hush is standing at.

### P3 — Make the Script a goal list, not an inventory of the Night.
Night 1 should carry ~9 live pranks and require 4. The player then *chooses* four, and the rest are
the reason to replay and the content of ★★ Full Script. This is the research's "8 available, 5 to
pass", and it is what makes P2's choices matter.

### P4 — Starve the fast-forward button by feeding the fuse.
56 % on ⏩ is the symptom; P1–P3 are most of the cure, because they give the player something to do
while he walks. The other half: make the **Running Gag fuse the spine of scoring**. The multiplier is
already built and correct (`SimConst.mult_for_link`: ×1 / ×1.5 / ×2 / ×3) — it is simply starved,
because you cannot chain four pranks in a Night that only contains five.

With 9 live pranks the skilled play becomes: pre-rig a route, then detonate it in his loop order.
That is the "I'd show my parents how I can chain 10 tricks" fantasy the research identifies as the
single most-loved thing in the genre, and it needs content, not code.

### P5 — Give the squeak back its toy-ness. *(cheap)*
Clarence is used 4 times in a 138 s Night, held back by lure fatigue and bits that decay to zero.
The honk it is modelled on has no limit and is funny every time. Keep the *score* decaying so it
isn't an exploit, but always play a reaction and vary it. A free verb that is fun to press for its
own sake is the cheapest density in the game.

### P6 — Three reaction variants for the top ~10 pranks. *(content volume, high confidence)*
The genre's most-praised element, currently authored once. The authoring pipeline is proven — wave 0
shipped 144 lint-clean clips — so this is a known-cost, known-quality investment rather than a risk.

### P7 — Rehearsal mode. *(optional)*
The house with no Bellows, nothing scored. Research rec #20. Nearly free given the sim, and it is
where players discover what the systems do — which is also where the next P1-style rule comes from.

**Suggested order:** P1 + P5 first (cheap, immediately raises felt density, and they tell you whether
reactivity is really the missing ingredient before you commit to P2). Then P3 + P2 together, since
choice needs something to choose between. Then P4 tuning and P6 volume.

---

## 5. Development-process changes

### Q1 — Measure agency, and gate it. *(the most important item here)*
`Metrics` already logs everything needed. Add, and gate in `solve.sh` exactly as dead air is gated:

| Metric | Suggested gate (Act I) |
|---|---|
| `ff_share` = `ff_s` / duration | ≤ 25 % (today: **56 %**) |
| `inputs_per_min` | ≥ 20 (today: **16**) |
| `longest_no_input_gap_s` | ≤ 8 s (today: **27.1 s**) |
| `alive_by.input` | ≥ 60 % (today: **43.9 %**) |
| `live_rig_points / rig_points_in_rooms` | ≥ 60 % (today: ~15 %) |
| `choice_points` — moments with ≥ 2 legal scoring actions | ≥ 1 per 15 s |
| `route_diversity` — materially different plans reaching ★★★ | ≥ 3 |

`route_diversity` falls out of the `Planner` almost free: it already beam-searches (width 6) over
task orderings and executes each candidate on a real `world.clone()`. Counting distinct *winning
task-sets* rather than keeping only the best node turns the existing solver into a strategy-diversity
measure — which is the direct, automatable test for "pre-cooked".

Also split the dead-air gate in two and report both: **"something is happening"** (today's number,
which is fine and passing) and **"the player is doing something"** (new). Conflating them is what
let the project pass its anti-boredom gate while being boring.

### Q2 — The Fun Gate has never been run, and content is being built on top of it.
`docs/PROGRESS.md` has **every Stage 1 and Stage 2 acceptance box unticked**, including all eight Fun
Gate items — yet wave 0 (a Stage 3 prerequisite) is closed and 144 clips are authored. The project is
adding content on an unvalidated core, which is exactly how "it's not fun" gets discovered this late.

Recommend: pause content authoring; run the Fun Gate on the phone *now* as the gating event it was
designed to be; and ship the owner a debug APK on a fixed cadence (weekly) rather than at stage
boundaries. The Fun Gate's item 8 — *"funnier than Booby within a minute"* — is the only test that
was ever going to catch this, and it has never been run.

### Q3 — The owner's platform is untested, and his review loop was broken.
`e2e.sh`, `fuzz.sh` and `solve.sh` called GNU `realpath -m` while `lib.sh` has provided the portable
`mnd_abspath` since 2026-10-30. On macOS those three scripts died at argument parsing, so the
end-to-end review, the fairness fuzzer and the solver reports **all failed on the owner's machine** —
silently enough that a stale `/tmp/n01.json` from 31 Oct was the most recent evidence available.
CI runs `ubuntu-24.04` only, so nothing caught it.

Fixed in this change. Recommend a macOS CI job, or at minimum a portability lint that greps for
GNU-only flags (`realpath -m`, `sed -i`, `date -d`, `readlink -f`) — the owner's machine is the one
that decides whether this game is fun, so it is the one that must never be broken.

### Q4 — "BINDING" is now the bottleneck.
`docs/GDD.md` is 137 kB and marked **v1.1, BINDING**; `CLAUDE.md` makes it the contract and the test
suite locks it in. Claude Code then executed it with high fidelity — which is why the build is
polished, conformant, and exactly as deep as the document said. **The spec is the problem, not the
implementation.** A binding design written before anything was playable encodes pre-play guesses as
contracts, and 1,105 tests make them expensive to revisit.

Recommend: demote the GDD from BINDING to *current intent*, and add an explicit design-spike lane — a
scratch scene plus a feature flag where a mechanic can be tried in an hour without touching content,
lints or tests, and is promoted to spec only after it survives a play session. The 3D cast is the
cautionary case: fully built on a 65-bone rig, retargeted, lint-clean, tested — then dropped on
first contact with play. That was the right call, made at maximum cost.

### Q5 — Make the review artefact 30 seconds of real play.
`TESTING_ON_MAC.md` already argues this for animation ("a still frame cannot show a judder"). The
same is true of pacing: no still shows a 27-second gap. Extend the definition of done so a gameplay
change ships with a capture of a real Night, not a screenshot.

### Q6 — How to brief Claude Code for this work.
What went well here is worth keeping: the sim is clean, deterministic and genuinely well-factored;
the solver, lints and animation pipeline are real engineering that will pay off through the changes
above. The failure was not in execution. Three adjustments:

1. **Give goals and measurements, not specifications.** "Get `ff_share` under 25 % on N1 ideal, here
   is the metric" lets an agent search the design space. "Implement §4.1.1 exactly" guarantees it
   transcribes. The first brief is also self-checking.
2. **Prefer systemic work over per-content authoring.** One rule applied to all props (P1) is where
   an agent's leverage is highest and the review cost is lowest; 32 bespoke tuples is where it is
   lowest and review cost highest. This is the same lesson the Goose team learned about consistency
   beating volume.
3. **One change per run, with a measured before/after**, and a capture attached.

---

## 6. What this does not change

The art direction is working — the house reads beautifully at 1200×540, the Script panel is the
Goose-style punchline list the design asked for (*"Bellows loses a fight with a jar"*, never "put
pepper in the honey"), the residue overlays land, and the PiP does its job. The sim is fast,
deterministic and clean. None of the above is a rewrite: P1, P2, P3 and P5 are additive, and P4 and
Q1 mostly exploit machinery that is already built and already correct.
