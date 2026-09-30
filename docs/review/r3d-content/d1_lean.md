# d1_lean — the D1 gate if the Bellows window stayed closed on adjacency-only ticks (R15)

Source: `solve_c2b.json` (solve.sh --report). `lean` counts a PiP micro-gag whose `pip_reason` is `adjacent` as visible only when it has an emote (the HUD edge badge plays it: an edge beat); heading / rigging / room beats are unchanged. Thresholds: ideal ≤ 20 %, required ≤ 25 %, slow ≤ 30 %, worst gap ≤ 12 s, edge share ≤ ⅓.

| episode | route | persona | gate ⏩ dead air | gate gap | lean ⏩ dead air | lean gap | lean edge share | adjacency-only PiP beats | lean verdict |
|---|---|---|---|---|---|---|---|---|---|
| n01_throat_tea | ideal | ideal | 7.8 % | 4.3 s | 7.8 % | 4.3 s | 0.37 | 6 of 8 | **FAIL** (edge share 0.37 > 1/3) |
| n01_throat_tea | required | required | 4.8 % | 5.5 s | 4.8 % | 5.5 s | 0.62 | 4 of 6 | **FAIL** (edge share 0.62 > 1/3) |
| n01_throat_tea | slow | slow | 1.9 % | 4.4 s | 1.9 % | 4.4 s | 0.49 | 4 of 6 | **FAIL** (edge share 0.49 > 1/3) |
| n01_throat_tea | caught | scenario | 5.1 % | 6.2 s | 5.1 % | 6.2 s | 0.73 | 5 of 7 | info |
| n01_throat_tea | chase | scenario | 16.3 % | 5.9 s | 16.3 % | 5.9 s | 0.55 | 7 of 7 | info |
| n01_throat_tea | meltdown | scenario | 13.7 % | 4.2 s | 13.7 % | 4.2 s | 0.34 | 1 of 2 | info |
| n02_something_fishy | ideal | ideal | 6.9 % | 3.9 s | 6.9 % | 3.9 s | 0.49 | 7 of 11 | **FAIL** (edge share 0.49 > 1/3) |
| n02_something_fishy | required | required | 1.9 % | 3.7 s | 1.9 % | 3.7 s | 0.57 | 4 of 6 | **FAIL** (edge share 0.57 > 1/3) |
| n02_something_fishy | slow | slow | 1.6 % | 4.3 s | 1.6 % | 4.3 s | 0.29 | 3 of 5 | OK |
| p00_curtain_up | ideal | ideal | 3.0 % | 4.1 s | 3.0 % | 4.1 s | 0.44 | 5 of 6 | **FAIL** (edge share 0.44 > 1/3) |
| p00_curtain_up | required | required | 1.8 % | 4.1 s | 1.8 % | 4.1 s | 0.62 | 7 of 8 | **FAIL** (edge share 0.62 > 1/3) |
| p00_curtain_up | slow | slow | 5.9 % | 5.3 s | 5.9 % | 5.3 s | 0.16 | 5 of 6 | OK |

**Verdict:** d1_lean does NOT pass D1 on every gated route.

**Reading.** Every adjacency-only PiP micro-gag of the slice carries an emote, so under `lean` each one is still seen
(on the HUD edge badge) and the dead air and worst gaps are *identical* to the gate. What fails is Stage-2 ruling L1:
with the window closed on adjacency-only ticks, 37–62 % of the beat credit comes from the edge badge on 7 of the 9
gated routes (cap ⅓) — most of his visible comedy would play on a 112 px face instead of the window. By R15 (`lean`
only if `d1_lean` passes D1 on every route) the shipped default stays **`bellows_window: "sim"`**, whatever the first
3D P00 e2e measures for `pip_on_share`. If the orchestrator wants `lean` anyway, the lever is content, not the gate:
more of his loop inside Hush's room or heading to it (P00/N1/N2 loops), or fewer emote beats on adjacency.
