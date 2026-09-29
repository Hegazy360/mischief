# Fuzz report (real sim + real content, 5 seeded runs per bot per final episode)

Soft-lock probe on every 4th run of each bot (runs 1 and 5); determinism replay on every 5th (run 1).

```
[fuzz] n01_throat_tea random: 5/5 OK, 34 catches, 18 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea reckless: 5/5 OK, 68 catches, 42 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea hider: 5/5 OK, 37 catches, 16 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea bait: 5/5 OK, 20 catches, 30 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy random: 5/5 OK, 42 catches, 15 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy reckless: 5/5 OK, 81 catches, 73 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy hider: 5/5 OK, 41 catches, 18 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy bait: 5/5 OK, 35 catches, 20 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up random: 5/5 OK, 0 catches, 20 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up reckless: 5/5 OK, 0 catches, 14 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up hider: 5/5 OK, 0 catches, 4 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up bait: 5/5 OK, 0 catches, 10 near misses, 0 soft-lock(s)
[fuzz] OK: 60 run(s), 0 failed, 145.2 s
```

## Stage 2 (s2-sim, batch 1): 20 runs × 4 bots × 3 Nights, rule 9 tightened (1 tick; queued runs when busy ends), rule 12 (no combo where rules.combos is [])

```
[fuzz] n01_throat_tea random: 20/20 OK, 115 catches, 49 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea reckless: 20/20 OK, 265 catches, 155 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea hider seed=11 FAIL 180.0 s, 82 cmds, 5 catches, 6 near misses, 7 laughs — rule 9: {"c":"go","hotspot":"kitchen_table","run":true} at t=10196 (169.93 s) was queued but did not r
[fuzz] n01_throat_tea hider: 19/20 OK, 154 catches, 67 near misses, 0 soft-lock(s)
[fuzz] n01_throat_tea bait: 20/20 OK, 120 catches, 40 near misses, 0 soft-lock(s)
[fuzz] FAIL: 80 run(s), 1 failed, 2736.9 s
[fuzz] n02_something_fishy random: 20/20 OK, 180 catches, 72 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy reckless: 20/20 OK, 247 catches, 147 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy hider: 20/20 OK, 153 catches, 86 near misses, 0 soft-lock(s)
[fuzz] n02_something_fishy bait: 20/20 OK, 160 catches, 0 near misses, 0 soft-lock(s)
[fuzz] OK: 80 run(s), 0 failed, 2098.0 s
[fuzz] p00_curtain_up random: 20/20 OK, 0 catches, 60 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up reckless: 20/20 OK, 0 catches, 47 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up hider: 20/20 OK, 0 catches, 26 near misses, 0 soft-lock(s)
[fuzz] p00_curtain_up bait: 20/20 OK, 0 catches, 120 near misses, 0 soft-lock(s)
[fuzz] OK: 80 run(s), 0 failed, 2689.3 s
```

The single red run (N01 hider seed 11) was a rule-9 false positive (the queued go ran the tick the POP OUT ended, the same tick he grabbed her); fixed in `Invariants._queued_ran` and the N01 hider bot re-run clean. See ../s2-sim/index.md.
