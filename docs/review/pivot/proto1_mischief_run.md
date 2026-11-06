# Prototype 1a — MISCHIEF RUN

Date: 2026-11-06. The first pivot prototype from `docs/review/pivot/2026_options.md` §5: **Option 1a**,
the Mischief theme rebuilt as a systems roguelike. Code in `game/proto/mischief_run/`.

## What it is

Bellows walks a routine of six stations. You rig prank cards onto them, raise the curtain, and watch
the routine resolve left to right. Stations that fire next to each other build a **chain multiplier**;
residues stick to him for the rest of the Night and feed later cards; his **temper** tiers up and pays
a bonus on every hit. Between rounds you take one of three offers — a new prank or an **Encore** that
changes a rule for the rest of the run. Three Nights, four rounds each, escalating targets.

**One tap to pick a card, one tap to place it, one tap to raise the curtain.** That is the whole input.

## What is deliberately gone

No cast, no house, no sneaking, no stealth, no fast-forward, and **not one animation frame**. There are
no sprites in this prototype at all: every pixel is primitives, two OFL fonts and a palette. That is the
pipeline argument from the research — the quality lives in rules and data that agents can build, test
and balance, and the look is code rather than an artist's hand.

## Why these numbers

`run.gd` is a pure, deterministic engine with no nodes, so `sim.gd` can play it headlessly. Balance was
tuned against simulated runs *before* the UI existed:

```
=== MISCHIEF RUN — balance report (200 runs, greedy bot) ===
draft policy: random (unbiased)        full clears: 44 / 200  (22.0%)

Night  target   reached   cleared   clear%   avg Applause
  1       65       200       200    100.0%     90.3
  2      120       200       171     85.5%    137.9
  3      230       171        44     25.7%    187.7
```

With a greedy drafter instead of a random one the same bot clears 52 %. A human should land between the
two, so roughly a third of runs should end in a win — Night 1 a gentle on-ramp, Night 3 the wall.

The simulator also found two dead cards before anyone played: THE BIG NUMBER needed all six stations and
could never fire on three Nerve (now four), and GOAD scored nothing because its value is the temper it
leaves behind. That is the loop the research recommends and this project has never had: **the bot removes
the broken and the tedious before the owner spends an evening on it.**

## Honest state

* Content is a prototype set: 24 cards, 10 Encores, one routine shuffled per Night. Balatro ships 150+
  jokers — this is enough to prove the shape, not enough to sustain a run.
* No sound, no save, no meta-progression between runs, no tutorial.
* The card art is a glyph. On macOS the system font covers them; some may not resolve on Android.
* Resolution pacing is fixed (0.62 s per firing station). Tap to hurry it.
* The one real UI bug found and fixed in review: the headline Applause used to jump to its final value
  at the start of the replay instead of counting up with it.
