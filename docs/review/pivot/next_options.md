# If Prototype 1a is not good enough — the prepared next steps

Date: 2026-11-06. Companion to `docs/review/pivot/2026_options.md` and
`docs/review/pivot/qa_proto1.md`. Read the row that matches your objection.

The rule for all of them: **one prototype at a time, one week each, judged on your phone against the
same five questions.** Every prototype below reuses `run.gd`'s pattern — a pure deterministic engine
plus a headless simulator — because that is the part that let 1a be balanced before it was played.

---

## Route your objection

| What you felt about 1a | What it means | Go to |
|---|---|---|
| "Fun, but I never found a surprising combination" | The shape is right, the content is thin | **A. Deepen 1a** |
| "The theme drags it down — it still feels like the old game" | Form is right, fiction is wrong | **B. Prototype 1b** |
| "Too much reading. I want to *do* something, not plan it" | Wrong interaction register | **C. Prototype 2** |
| "Cards are not a game I want to make" | Wrong genre entirely | **D. Prototype 3** |
| "It's fine but I don't care about it" | No hook | **E. Verb hunt first** |

---

## A. Deepen 1a (1 week) — if the shape worked

The prototype has 24 cards; Balatro has 150+ jokers and that density *is* the game. Nothing here is
new engineering, which is the point: it is the cheapest week on this page.

1. **Content to 60 cards and 20 Encores.** New synergy axes beyond the four it has (residue, chain,
   temper, room): *station-order* effects (pays if rigged on an odd stop), *deck* effects (pays per copy
   you own), *negative-space* effects (pays for stations left empty).
2. **A meta layer between runs**: unlock cards into the pool by doing things ("land a ×4 chain"), which
   is what turns one good run into ten.
3. **Balance the whole pool with `sim.gd`** — target every card between 8 and 25 average gain, no card
   under 5 % pick rate at random draft.
4. **Art direction pass**: the look is code, so this is a palette, a type scale and a card frame, not an
   art budget. One day, reversible.
5. **Sound**: the repo's procedural audio toolchain already exists and is one of the few parts worth
   keeping.

Decision: replay the gate. If Q1 ("a combination that delighted you") now passes, commit to it.

## B. Prototype 1b — same shape, new fiction (1 week)

Keep `run.gd` almost verbatim; replace the theme, the track metaphor and the card pool.

1. **Two days of verb hunting.** 20 one-paragraph pitches, each built on a real-world object or ritual
   with its own rhythm — the way poker was Balatro's, a slot machine was Luck be a Landlord's, pachinko
   was Peglin's, a backpack was Backpack Hero's. The test for each: *can you say the hook in six words
   and does it suggest ten cards immediately?*
2. You pick two. Each gets a card pool and a simulated balance pass **before** any UI.
3. Build the better one on the existing UI in two days (it is theme-agnostic: a track, cards, a tally).

This is the cheapest genuinely different game on this page, because 1a's engine, UI and simulator all
carry over untouched.

## C. Prototype 2 — minimalist systems strategy (1.5 weeks)

Mini Metro / Thronefall / Islanders. You place things on a board, the system responds continuously,
you optimise under pressure. Direct manipulation instead of card text.

1. Pick the one system. Candidates that suit a house and a grump: routing something through rooms;
   a spreading mess you contain; a schedule you fill without collisions.
2. Build the simulation first, headless, with a difficulty curve the simulator reports.
3. The look is a renderer — geometry, a five-colour palette, no assets. Same no-artist pipeline.

Risk, stated plainly: these games are one idea executed perfectly. Do not start without the idea.

## D. Prototype 3 — low-poly 3D toy sandbox on library assets (2 weeks)

Only if your objection to the spikes was the *art*, not the play. The approach that failed in October
was re-dressing bought characters into our 2D cast; the approach that worked was using them as they come
(KayKit measured jitter 0.13–0.18 with library clips, against 0.42 for our own rig).

1. Buy/adopt one coherent set (Synty POLYGON paid, or KayKit/Quaternius/Kenney CC0 — all consistent
   within a pack) and **do not restyle it**.
2. Library animations only, retargeted. No hand-keyed frames, ever.
3. One room, physics props, one NPC with a routine and a reaction state. One week to a playable toy.
4. Engine check at the end of week one: if the physics or the mobile build fight Godot, this is the one
   option where moving to Unity is justified.

## E. Verb hunt first (3 days) — if nothing has a hook

Stop building. Spend three days generating and killing ideas on paper, with the agents producing volume
and you cutting. Output: 30 pitches, 5 survivors, 2 with a simulated core loop. Then re-enter at B.

---

## What stays true whichever way it goes

* **Steam and mobile together.** A premium mobile-only game from an unknown studio has no path to an
  audience in 2026; every comparable small-team success was PC-first and ported.
* **No hand-keyed animation in the pipeline.** It is the one thing this team cannot do well, and three
  rounds of this project were spent proving it.
* **Pure engine + headless simulator, from the first commit.** It is what let 1a be balanced before it
  was played, and it is the only defence against the failure mode that started all this — every gate
  green and the game still dull.
* **You on the phone, weekly, with your reaction written down.** Fun is the one metric no agent owns.
