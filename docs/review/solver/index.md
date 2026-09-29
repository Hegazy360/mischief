# Solver review: the bot, fairness fuzz, lints and CI (Stage 1)

> **Stage 2 (s2-sim, batch 1):** `solve_report.md/.json` and `timelines/` are refreshed with the D1 gate — dead air
> in real time with the persona's ⏩ latch and visible micro-gag beats, the scenario routes, `g0_sneeze`, a BEATS
> and an FF row in every timeline. The before/after tables, `alive_by`, edge share and the ⏩ model are in
> [../s2-sim/index.md](../s2-sim/index.md). The Stage-1 text below is kept as the record of the starting point.


These are the headless proofs that each final Night can be completed, 3-starred and played fairly,
plus the numbers the owner's fun gate cares about. Everything here was run on the real `SimWorld`
with the real `game/data` (Prologue, Night 1 and Night 2 are `final`) on 2026-09-29.

| Artefact | What it shows | What to judge |
|---|---|---|
| [solve_report.md](solve_report.md) / [.json](solve_report.json) | All 9 routes (ideal / required / slow × P00, N01, N02) plus the planner proofs | Stars, applause, laugh clock, dead air, gaps |
| [timelines/](timelines/) | One strip chart per run: Bellows' room and state, Hush's room (hidden = dark stripes, frozen = white), the "?" meter, input, laughs, dead air, events | Where the waiting is. Grey bars in DEAD AIR are what a player would feel as "nothing's happening". |
| [fuzz_report.md](fuzz_report.md) | 60 seeded bot runs (random, reckless, hider, bait × 5 × 3 Nights): invariants, determinism replays, soft-lock probes | 60/60 green |
| [lint_report.md](lint_report.md) | Content, hotspot and IP lints (12 episodes, 32 pranks, 53 files, 88 GDD strings), plus the rig agent's animation lint | All green |

How to regenerate:
`tools/scripts/solve.sh all --route=all --auto --report=/abs/solve.json --timeline=/abs/dir`,
`tools/scripts/fuzz.sh all --runs=5`, `tools/scripts/lint.sh`.

## Headline numbers (real sim, real content)

| Night | Route | Result | Duration | Applause | 1st player laugh* | 1st prank* | Laughs by 60 s* | Dead air (sim / ⏩) | Longest gap (sim / ⏩) |
|---|---|---|---|---|---|---|---|---|---|
| P00 Curtain Up | ideal | OK | 59 s | 89.5 | **6.1 s** | **24.7 s** | **7** | 31 % / 25 % | 13.8 s / 5.9 s |
| P00 | slow first-timer | OK | 62 s | 89.5 | **6.6 s** | **27.7 s** | 7 | 28 % / 21 % | 13.2 s / 5.7 s |
| N01 Throat Tea | ideal | ★★★ | 131 s | 118.3 | 0.5 s | 17.0 s | 4 | 50 % / 37 % | 21.0 s / 10.0 s |
| N01 | slow | ★ | 155 s | 44.5 | 3.6 s | 26.4 s | 3 | 64 % / 44 % | 44.4 s / 15.0 s |
| N02 Something Fishy | ideal | ★★★ | 183 s | 116.5 | 3.8 s | **48.9 s** | 2 | 55 % / 38 % | 39.0 s / 13.5 s |
| N02 | slow | ★ | 86 s | 61.3 | 8.6 s | 48.9 s | 2 | 54 % / 38 % | 32.6 s / 11.6 s |

\* Launch-relative: sim time plus the director's `launch_offset_s` (2.3 s in the Prologue). The "⏩"
figures count hidden ticks at 1/3, which is how long they feel to a player who fast-forwards while
hidden. They are informational; expects use the TECH §8.5 sim-time metric.

- **Prologue laugh clock: met.** GDD §2.3 asks for 6 laughs in 60 s on the ideal route (it gets 7),
  and a first player laugh ≤ 10 s and first prank ≤ 30 s on the slow first-timer (6.6 s and 27.7 s).
- **★★★ is reachable on N1 and N2.** Both authored ideal routes get it (118 and 116 applause). The
  planner also finds it by itself on N1 (106 applause).
- **Dead air is the main fun risk.** Every route is 28 to 74 % dead air against the < 20 % target
  (GDD §2.1, TECH §8.5). Even with ⏩ compression N1/N2 sit at 37 to 58 %. Where it comes from, per
  the timelines:
  - **N02:** about 36 s of hidden waiting before the first prank lands (at 48.9 s from curtain up).
  - **N01:** about 28 s of fix-up detours after HOT & COLD (FRAZZLED → hall mirror, then SOAKED → DRY).
  - **Everywhere:** the long "hide and wait for the payoff" stretches between rig and reaction.
  - The content agent has since **removed `dead_air_pct_max` from the slow routes**, so right now no
    route gates dead air. See the requests in the report.

## Planner proofs (`--auto`, deterministic budget: 400 macro runs, ≤ 50 s wall time per Night)

| Night | Whole Script | Each line alone | ★★★ | Soft-lock (3 forced catches, re-plan) | Time |
|---|---|---|---|---|---|
| N01 | 6/6 lines incl. HOT & COLD | all 6 | yes (planner, 106) | OK | 43 s, 180 macros |
| N02 | 5/5 lines incl. MIRROR, MIRROR | all 5 | yes (authored route) | OK | 50 s, 174 macros |
| P00 | 2/2 | both (in Script order: the Prologue is linear) | n/a (no Curtain Calls) | OK: can't-fail, so no catch can be forced | 12 s, 40 macros |

## Fairness (TECH §8.6, all 11 rules)

60/60 fuzz runs are green on the real sim, as are all 9 authored routes. That covers every catch
having a fair "?" window, no ambush entries, unseen hiding being safe, bubble notice, determinism
(command-log replays match the hash), no soft-locks, speed and loop order, blindness while reacting,
progress, one reaction at a time with applause ≥ 0 and bases summing to 700, and the Beryl
headbutt rule (inactive until Stage 3). The sim's own `invariant_counters` are also checked and
come out zero.

Sim behaviour confirmed along the way: `clone()` is fully independent of the original (stepping a
clone for 3,000 ticks leaves the original's hash untouched), and consecutive worlds on one ContentDB
don't leak state.
