# Solver report

| episode | route | ok | duration | stars | applause | lines | catches | 1st laugh* | 1st prank* | laughs@60* | dead air | max gap | dead air ⏩ | max gap ⏩ | hold | near misses |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| n01_throat_tea | ideal | OK | 131.1 s | ★★★ | 118.3 | 6 | 0 | 0.5 s | 17.0 s | 4 | 50.0 % | 21.0 s | 37.4 % | 10.0 s | 6.4 s | 0 |
| n01_throat_tea | required | OK | 148.8 s | ★☆☆ | 39.5 | 3 | 0 | 20.7 s | 20.7 s | 2 | 73.9 % | 49.9 s | 57.2 % | 16.9 s | 3.1 s | 0 |
| n01_throat_tea | slow | OK | 155.1 s | ★☆☆ | 44.5 | 3 | 0 | 3.6 s | 26.4 s | 3 | 63.8 % | 44.4 s | 43.6 % | 15.0 s | 3.1 s | 0 |
| n02_something_fishy | ideal | OK | 182.8 s | ★★★ | 116.5 | 5 | 0 | 3.8 s | 48.9 s | 2 | 54.6 % | 39.0 s | 37.6 % | 13.5 s | 8.6 s | 0 |
| n02_something_fishy | required | OK | 85.9 s | ★☆☆ | 59.3 | 3 | 0 | 48.9 s | 48.9 s | 1 | 69.6 % | 44.8 s | 57.8 % | 15.4 s | 3.8 s | 0 |
| n02_something_fishy | slow | OK | 86.5 s | ★☆☆ | 61.3 | 3 | 0 | 8.6 s | 48.9 s | 2 | 53.8 % | 32.6 s | 38.4 % | 11.6 s | 3.8 s | 0 |
| p00_curtain_up | ideal | OK | 59.1 s | ☆☆☆ | 89.5 | 2 | 0 | 6.1 s | 24.7 s | 7 | 31.2 % | 13.8 s | 25.1 % | 5.9 s | 1.6 s | 0 |
| p00_curtain_up | required | OK | 67.0 s | ☆☆☆ | 87.5 | 2 | 0 | 32.7 s | 32.7 s | 4 | 39.8 % | 22.0 s | 31.7 % | 8.6 s | 1.6 s | 0 |
| p00_curtain_up | slow | OK | 62.0 s | ☆☆☆ | 89.5 | 2 | 0 | 6.6 s | 27.7 s | 7 | 27.8 % | 13.2 s | 20.7 % | 5.7 s | 1.6 s | 0 |

\* launch-relative (sim time + the episode's director `launch_offset_s`). ⏩ = hidden ticks weigh 1/3 (a player fast-forwarding while hidden).

## Planner proofs

| episode | ok | script | lines alone | ★★★ | soft-lock |
|---|---|---|---|---|---|
| n01_throat_tea | OK | OK | kettle ✓, tap ✓, pickle ✓, orbit ✓, sneeze ✓, bn ✓ | yes (planner) | OK |
| n02_something_fishy | OK | OK | fish ✓, clock ✓, dinner ✓, news ✓, bn ✓ | yes (authored route) | OK |
| p00_curtain_up | OK | OK | sneeze ✓, spin ✓ | n/a (no Curtain Calls) | OK |
