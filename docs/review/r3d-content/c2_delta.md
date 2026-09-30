# C2 — Night 1 re-plans, before (67c7276 / 9ca1db7) vs after (R3D hides)

REDESIGN_3D §6.2 C2 predicted +170 px ≈ +0.43 s of tiptoe per moved hide. Measured by `tools/content/c2_delta.py` on the
solver's event dumps (pristine HEAD sandbox vs this tree; `solve.sh n01_throat_tea --route=all --dump-events`).

## n01_throat_tea — routes before / after C2

| route | duration s | dead air ⏩ % | max gap ⏩ s | stars | applause | hides moved | Δ tiptoe per moved hide |
|---|---|---|---|---|---|---|---|
| caught | 86.7 → 86.7 | 5.2 → 5.1 | 6.2 → 6.2 | ★☆☆ → ★☆☆ | 48 → 48 | 1 | +0.43 s mean (+0.43) |
| chase | 82.8 → 83.6 | 17.6 → 16.3 | 5.0 → 5.9 | ☆☆☆ → ☆☆☆ | 0 → 0 | 1 | +1.82 s mean (+1.82) |
| ideal | 138.2 → 138.2 | 7.9 → 7.8 | 4.0 → 4.3 | ★★★ → ★★★ | 116 → 116 | 4 | +0.32 s mean (+0.42, +0.43, +0.42, +0.00) |
| meltdown | 53.0 → 53.0 | 13.9 → 13.7 | 4.2 → 4.2 | ☆☆☆ → ☆☆☆ | 72 → 72 | 2 | +0.43 s mean (+0.42, +0.43) |
| required | 79.0 → 79.0 | 4.8 → 4.8 | 5.5 → 5.5 | ★☆☆ → ★☆☆ | 44 → 44 | 1 | +0.42 s mean (+0.42) |
| slow | 85.3 → 88.7 | 2.1 → 1.9 | 4.4 → 4.4 | ★☆☆ → ★☆☆ | 46 → 46 | 1 | +0.42 s mean (+0.42) |

Per moved hide (tiptoe + dive, from the tap to the curtain closing):

- caught hide 3: kitchen_table 1.08 s → kitchen_pantry_curtain 1.52 s (go→hide)
- chase hide 1: parlour_chaise_back 3.35 s → parlour_piano_back 5.17 s (go→hide)
- ideal hide 1: kitchen_table 1.52 s → kitchen_pantry_curtain 1.93 s (go→hide)
- ideal hide 2: kitchen_table 1.08 s → kitchen_pantry_curtain 1.52 s (go→hide)
- ideal hide 6: kitchen_table 4.32 s → kitchen_pantry_curtain 4.73 s (go→hide)
- ideal hide 7: kitchen_table 14.15 s → kitchen_pantry_curtain 14.15 s (go→hide)
- meltdown hide 1: kitchen_table 1.52 s → kitchen_pantry_curtain 1.93 s (go→hide)
- meltdown hide 2: kitchen_table 1.08 s → kitchen_pantry_curtain 1.52 s (go→hide)
- required hide 4: kitchen_table 1.52 s → kitchen_pantry_curtain 1.93 s (go→hide)
- slow hide 5: kitchen_table 1.52 s → kitchen_pantry_curtain 1.93 s (go→hide)

**Reading.** Every moved kitchen hide costs +0.42–0.43 s of tiptoe (the pantry curtain is 170 px past the table), exactly
the REDESIGN estimate; ideal hide 7 costs nothing (she already waits there for the rinse). Stars, applause and every
route's duration are unchanged except slow (+3.4 s: its wrong tap is now a live spot of her start room, not the struck
sink tap) and chase (+0.8 s: the chase now starts behind the piano — Hush walks into his view at x 2400, is spotted,
runs past the doorway (door slam kept) and hides in the pantry; the chaise it used is struck). D1 dead air (⏩): ideal
7.9 → 7.8 %, required 4.8 → 4.8 %, slow 2.1 → 1.9 % — far inside the gate (20 / 25 / 30 %). Night 2's ideal and
required routes are byte-identical (same final state hash); N2 slow differs only by its dropped wrong tap (no live
distractor left in the decluttered kitchen; same 56.0 s); the two face-to-face scenarios are retired. P00 ideal/required
are byte-identical; P00 slow's wrong tap changed (−0.6 s). Gate 0 (g0 ideal): see index.md.
