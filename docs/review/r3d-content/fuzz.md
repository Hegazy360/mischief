# r3d-content — fuzz 200 per final episode

`SANDBOX=r3d-content tools/scripts/fuzz.sh <episode> --runs=200 --report=<SP>/work/r3d-content/fuzz_<episode>.json`
on this tree (the live mask, the `here` rule, the P00 mirror hold, the door/stairs rule, invariant rule 13; rule 3
skips a catch on the tick she popped out of her spot). Random taps include a struck hotspot 1 in 4; the hider uses
only tonight's hiding spots; every 5th run replays for determinism; the soft-lock probe runs where the fuzzer
samples it. N02 ran in two halves (`--bot=random,reckless`, `--bot=hider,bait`; 23:00Z, after the 22:37Z container
restart killed the first attempt). Judge: every row n/n, 0 soft-locks, 0 invariant violations.

| episode | bot | ok | catches | near misses | soft-locks | invariant msgs | lines landed (top 4) |
|---|---|---|---|---|---|---|---|
| p00_curtain_up | random | 200/200 | 0 | 668 | 0 (49 probed) | 0 | sneeze 61, spin 9 |
| p00_curtain_up | reckless | 200/200 | 0 | 494 | 0 (0 probed) | 0 | sneeze 200, spin 200 |
| p00_curtain_up | hider | 200/200 | 0 | 515 | 0 (50 probed) | 0 | - |
| p00_curtain_up | bait | 200/200 | 0 | 0 | 0 (50 probed) | 0 | - |
| n01_throat_tea | random | 200/200 | 1096 | 439 | 0 (50 probed) | 0 | pickle 13, tap 11, orbit 10, sneeze 6 |
| n01_throat_tea | reckless | 200/200 | 2600 | 1346 | 0 (50 probed) | 0 | tap 145, orbit 140, kettle 124, pickle 115 |
| n01_throat_tea | hider | 200/200 | 1254 | 618 | 0 (50 probed) | 0 | - |
| n01_throat_tea | bait | 200/200 | 1200 | 800 | 0 (50 probed) | 0 | - |
| n02_something_fishy | random | 200/200 | 1516 | 637 | 0 (50 probed) | 0 | dinner 11, clock 8, fish 1 |
| n02_something_fishy | reckless | 200/200 | 2328 | 1489 | 0 (50 probed) | 0 | clock 121, dinner 104, fish 102, news 94 |
| n02_something_fishy | hider | 200/200 | 1502 | 828 | 0 (50 probed) | 0 | - |
| n02_something_fishy | bait | 200/200 | 1800 | 1200 | 0 (50 probed) | 0 | - |

## Violations

None.
