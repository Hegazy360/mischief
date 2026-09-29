# Prologue clock (GDD §2.3 vs the sim) — s2-content

Measured with `SANDBOX=s2-content tools/scripts/solve.sh p00_curtain_up --route=all --dump-events=<dir>
--report=<dir>/p00.json` then `python3 tools/content/prologue_clock.py <dir> --report=<dir>/p00.json --check`
(regenerate it the same way). **Launch times** = sim time + `director.launch_offset_s` 2.3 s (ruling L13: sim tick 0
is the curtain starting to rise). The slow first-timer (0.6 s latency, 3 s dawdle, one wrong tap, tiptoes, hides at
the first warning) is the column the GDD table is written for; ideal and required are shown beside it.

| beat (GDD §2.3) | GDD target (launch s) | slow (launch s) | ideal (launch s) | required (launch s) |
|---|---|---|---|---|
| Curtain up, input live | 2.3–3.1 | 2.3 | 2.3 | 2.3 |
| Vase smashes behind him (titter) | ≈ 4.6 | 4.6 | 4.6 | 4.6 |
| Figgis psst + ghost finger on Clarence | ≈ 6.0 | 6.0 | 6.0 | 6.0 |
| SQUEAK → yodel (first player laugh) | ≈ 7–9, ≤ 10 | 6.6 | 6.1 | — |
| Honey jar glows, ghost finger | squeak + 1.0 (≤ 15) | 8.1 | 7.6 | 17.3 |
| Rig the honey (hold 0.8 s) | ≈ 12 | 12.4 | 9.4 | 9.1 |
| Entry warning + BEHIND YOU! | rig + 2.0 (≈ 16) | 17.3 | 14.3 | 22.3 |
| Hide in the pantry | — | 14.9 | 11.3 | 11.0 |
| CHOO! (first prank) | ≈ 26, ≤ 30 | 28.2 | 25.2 | 33.2 |
| Blind shuffle bonks the door frame | ≈ 29 | 33.2 | 30.2 | 38.2 |
| ⏩ lesson (ghost_ff, Hush hidden) | (new) | 34.7 | 31.8 | 39.7 |
| Mirror fix-up (off-stage, hall) | — | 40.6 | 37.6 | 45.5 |
| Gramophone lever sparkles (unguided) | mirror detour + 8 | 37.4 | 34.4 | 42.4 |
| ALLEGRO-GO-GO! (roar) | ≈ 38 (≈ 46 accepted) | 49.6 | 46.6 | 54.6 |
| Specs on, the hunt | ≈ 46 | 53.2 | 50.2 | 58.2 |
| Relief laugh (found nothing) | hunt + 6 | 59.2 | 56.3 | 64.2 |
| Picture falls on his head | ≈ 54 | 59.8 | 56.8 | 64.8 |
| Curtain falls; title card | ≈ 58–70 | 63.8 | 60.8 | 68.8 |
| Prologue ends | title + 1.0 | 64.8 | 61.8 | 69.8 |

| laugh clock | target | slow | ideal | required |
|---|---|---|---|---|
| laughs by 10 s | slow ≥ 1 player laugh | 2 | 2 | 1 |
| laughs by 60 s | ideal ≥ 6 | 7 | 7 | 4 |
| laughs by 75 s | slow ≥ 4 | 7 | 7 | 6 |

| dead air (p00_curtain_up) | ⏩ latched (gate) | naive ⏩ (info) | sim time (info) | worst gap ⏩ | edge share |
|---|---|---|---|---|---|
| ideal | 3.0 % | 3.1 % | 4.3 % | 4.1 s | 0.00 |
| required | 1.8 % | 2.2 % | 2.7 % | 4.1 s | 0.00 |
| slow | 5.9 % | 4.3 % | 6.6 % | 5.3 s | 0.00 |

## Reading it
- **On spec:** vase 4.6 s, Figgis psst + ghost finger on Clarence 6.0 s, first player laugh 6.6 s (≤ 10), honey
  ghost 1.5 s after the squeak (8.1 s, ≤ 15), rig 12.4 s (≈ 12), sneeze 28.2 s slow / 25.2 s ideal (≤ 30 / ≈ 26),
  the lever sparkles exactly 8 s after the mirror detour is queued (37.4 s), title card 63.8 s (58–70), 7 laughs by
  60 s on the ideal route (≥ 6) and 7 by 75 s on the slow one (≥ 4). Every existing cue id is kept.
- **Late against the GDD sketch, accepted:** the entry warning is 17.3 s (≈ 16): he leaves 2 s after the rig and
  walks 4.5 s from the gramophone to the kitchen door, the warning is 1.5 s before he enters. The door-frame bonk is
  33.2 s slow / 30.2 s ideal (≈ 29): it waits for the 2.7 s sneeze reaction and the blind shuffle to the doorway.
  ALLEGRO-GO-GO! lands at 49.6 s slow / 46.6 s ideal (GDD ≈ 38): the hall-mirror round trip is ≈ 11 s of walking
  (Stage-1 content report, ambiguity 8 — "ALLEGRO ≈ 46 s"), so the hunt (53.2 s) and the picture (59.8 s) shift too.
- **The ⏩ lesson (`ghost_ff`, new):** fires at 34.7 s (slow): Hush is hidden in the pantry, he has just bonked the
  door frame and is shuffling off-stage to the hall mirror — the first *hidden wait* a first-timer meets (≈ 3 s at ×1
  before the sparkle, ≈ 1 s at ⏩). It is never during the sneeze build-up (watched at ×1). The cue holds a ghost
  thumb on Clarence (card `ff`) until Hush leaves her spot (`until {hush_hidden: false}`) or the first ⏩ press
  (`s2-ftue` dismisses it). The slow persona starts latching ⏩ at that cue (ruling L2).
- **Dead air, slow route:** the gate metric (⏩ latched from the cue) is 5.9 %; the naive Stage-1 weighting (every
  hidden tick ⅓) says 4.3 %; sim time 6.6 %. Before the cue the slow first-timer is at ×1 everywhere, which is why
  latched > naive. The worst gap is 5.3 s. The Prologue is dense by design: no stretch of the first minute lacks a
  laugh, a visible beat or an input.
