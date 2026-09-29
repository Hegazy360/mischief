# Review: `content` (Stage 1 data, retuned for D1 in Stage 2 by `s2-content`)

What to judge: is the data a faithful expression of GDD §4.1.1, §5 and §7.2 (plus the documented D1 deviations in
`docs/review/s2-content/d1_changes.md`)? Are the slice Nights provably completable and 3-starable, and are they busy
enough — does something funny or interactive happen every few seconds?

| Artefact | What it shows | What to judge |
|---|---|---|
| `catalogue.md` | `python3 tools/content/catalogue.py`: all 32 pranks, 6 Double Acts, 16 items, per-episode rooms, rule, card, loop and Script; diffed against GDD §5.7 / §7.2. **0 mismatches**; the two D1 loop changes are listed as ACCEPTED (its `DEVIATIONS` table), anything else still fails. | One Night's table against the GDD; the Script lines are punchlines, not instructions. |
| `solve_report.md` | `SANDBOX=… tools/scripts/solve.sh all --route=all` (+ `g0_sneeze --route=ideal`): **15/15 routes OK** with the D1 gates on every non-scenario route. | Applause bands, stars, the laugh clock, dead air (⏩ gate and sim time), edge share. |
| `timeline_<episode>_<route>.png` | Solver timelines. Rows: Bellows' room, his state (teal = fix-up, purple/brown = Meltdown/Exhausted), Hush's room (hatched = hidden), "?" meter, inputs, laughs, **beats** (visible micro-gags: green room, blue PiP, orange edge), **dead air** (grey), ⏩ latched, events. | Grey bars should be short and rare; the beat row dense where Hush is. |

## Solver numbers (Stage 2 final, real sim, current house)

| Night | route | result | Applause | time | 1st laugh* | 1st prank* | laughs by 60 s* | dead air ⏩ [sim] | worst gap ⏩ | edge share |
|---|---|---|---|---|---|---|---|---|---|---|
| Prologue | ideal | OK | 90 | 60 s | 6.1 s | 25.2 s | **7** | 3.0 % [4.3] | 4.1 s | 0.00 |
| Prologue | required | OK | 88 | 68 s | 33.2 s | 33.2 s | 4 | 1.8 % [2.7] | 4.1 s | 0.00 |
| Prologue | slow | OK | 90 | 63 s | **6.6 s** | **28.2 s** | 7 | 5.9 % [6.6] | 5.4 s | 0.00 |
| Night 1 | ideal | ★★★ | 116 | 138 s | 0.5 s | 17.5 s | 5 | 7.9 % [14.3] | 4.0 s | 0.00 |
| Night 1 | required | ★ | 44 | 79 s | 18.7 s | 18.7 s | 2 | 4.8 % [5.2] | 5.5 s | 0.22 |
| Night 1 | slow | ★ | 46 | 85 s | 3.6 s | 24.4 s | 3 | 2.1 % [4.6] | 4.4 s | 0.16 |
| Night 2 | ideal | ★★★ | 118 | 149 s | 0.5 s | **19.4 s** | 5 | 6.9 % [12.5] | 3.9 s | 0.00 |
| Night 2 | required | ★ | 59 | 55 s | 19.4 s | **19.4 s** | 4 | 1.9 % [3.9] | 3.7 s | 0.00 |
| Night 2 | slow | ★ | 61 | 56 s | 3.6 s | **19.4 s** | 5 | 1.6 % [3.8] | 4.7 s | 0.00 |
| Gate 0 | ideal | OK (`g0_done`) | 70 | 24 s | 19.4 s | 19.4 s | 1 | 8.1 % [10.5] | 3.9 s | 0.00 |

\* launch-relative for the Prologue (sim + `launch_offset_s` 2.3 s). Scenario routes (not gated on D1): N01
`caught` (caught mid-rig → Lecture → doorstep → finishes ★), `chase` (spotted → chase → door slam → search),
`meltdown`; N02 `face_to_face` (POP OUT of the in-use clock case → near miss) and `face_to_face_lost` (caught →
doorstep) — all OK, see `solve_report.md`.

## The worst remaining gap, per Night (what the player does and sees)
- **Prologue.** The longest quiet stretch (5.4 s ⏩ on the slow route) is Hush crouched in the pantry while he
  finishes his warm-up and walks in to brew the tea; she watches the entry warning and BEHIND YOU!, then his kettle
  primping and the pinkie-up sip in her own room — the sneeze build-up the whole minute is aimed at.
- **Night 1.** The worst stretch (4.0 s ⏩, 10.6 s at ×1 on the ideal route) is his first Meltdown after HOT & COLD
  and IN A PICKLE: Hush is under the kitchen table while he stomps and sulks in front of her, so the player is
  watching a tantrum, not waiting — the metric just doesn't count a Meltdown as a reaction (request to `s2-sim`).
  Otherwise it is the fireplace fix-up (10 s) and the walks, all covered by beats in the kitchen/parlour.
- **Night 2.** Same shape (3.9 s ⏩, 10.7 s at ×1, ideal): the Meltdown after COLD OPEN → SOMETHING FISHY → TIME'S
  UP in the hall with Hush in the coat cupboard, then his frizz fix-up at the mirror; she can rig MIRROR, MIRROR the
  moment he settles into the paper. The opening is no longer a wait: he reads, warms his hands and walks into the
  kitchen trap at 19 s.

Pacing findings from Stage 1 (N02's 48 s opening, N01's loop-and-a-half squeaker wait) are resolved at the source;
the numbers and every change are in `docs/review/s2-content/`.
