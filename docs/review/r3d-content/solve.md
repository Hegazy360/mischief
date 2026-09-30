# Solver report

| episode | route | ok | duration | stars | applause | lines | catches | 1st laugh* | 1st prank* | laughs@60* | dead air ⏩ [sim] | max gap ⏩ [sim] | ⏩ naive | beats room/pip/edge (hidden) | edge share | hold | near misses | d1_lean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| n01_throat_tea | ideal | OK | 138.2 s | ★★★ | 116.3 | 6 | 0 | 0.5 s | 17.5 s | 5 | 7.8 % [14.3 %] | 4.3 s [10.6 s] | 9.1 % | 7/8/0 (0) | 0.00 | 6.4 s | 0 | ⏩ 7.8 % gap 4.3 s edge 0.37 **FAIL** |
| n01_throat_tea | required | OK | 79.0 s | ★☆☆ | 44.0 | 3 | 0 | 18.7 s | 18.7 s | 2 | 4.8 % [5.2 %] | 5.5 s [7.0 s] | 5.7 % | 5/6/2 (0) | 0.22 | 3.1 s | 0 | ⏩ 4.8 % gap 5.5 s edge 0.62 **FAIL** |
| n01_throat_tea | slow | OK | 88.7 s | ★☆☆ | 46.0 | 3 | 0 | 3.6 s | 27.8 s | 3 | 1.9 % [4.4 %] | 4.4 s [6.1 s] | 2.4 % | 6/6/2 (0) | 0.15 | 3.1 s | 0 | ⏩ 1.9 % gap 4.4 s edge 0.49 **FAIL** |
| n01_throat_tea | caught | OK | 86.7 s | ★☆☆ | 48.4 | 3 | 1 | 25.4 s | 25.4 s | 1 | 5.1 % [4.6 %] | 6.2 s [6.2 s] | 5.8 % | 5/7/3 (0) | 0.31 | 4.2 s | 0 | ⏩ 5.1 % gap 6.2 s edge 0.73 info |
| n01_throat_tea | chase | OK | 83.6 s | ☆☆☆ | 0.0 | 0 | 0 | 69.8 s | — | 0 | 16.3 % [20.5 %] | 5.9 s [13.8 s] | 16.8 % | 5/7/0 (0) | 0.00 | 0.0 s | 0 | ⏩ 16.3 % gap 5.9 s edge 0.55 info |
| n01_throat_tea | meltdown | OK | 53.1 s | ☆☆☆ | 71.9 | 3 | 0 | 0.5 s | 17.5 s | 5 | 13.7 % [24.6 %] | 4.2 s [11.6 s] | 17.4 % | 1/2/0 (0) | 0.00 | 3.1 s | 0 | ⏩ 13.7 % gap 4.2 s edge 0.34 info |
| n02_something_fishy | ideal | OK | 149.3 s | ★★★ | 117.5 | 5 | 0 | 0.5 s | 19.4 s | 5 | 6.9 % [12.5 %] | 3.9 s [10.7 s] | 8.1 % | 7/11/0 (0) | 0.00 | 8.6 s | 0 | ⏩ 6.9 % gap 3.9 s edge 0.49 **FAIL** |
| n02_something_fishy | required | OK | 55.4 s | ★☆☆ | 59.3 | 3 | 0 | 19.4 s | 19.4 s | 4 | 1.9 % [3.9 %] | 3.7 s [7.1 s] | 2.5 % | 2/6/0 (0) | 0.00 | 3.8 s | 0 | ⏩ 1.9 % gap 3.7 s edge 0.57 **FAIL** |
| n02_something_fishy | slow | OK | 56.0 s | ★☆☆ | 61.3 | 3 | 0 | 3.6 s | 19.4 s | 5 | 1.6 % [3.8 %] | 4.3 s [7.1 s] | 2.2 % | 3/5/0 (0) | 0.00 | 3.8 s | 0 | ⏩ 1.6 % gap 4.3 s edge 0.29 OK |
| p00_curtain_up | ideal | OK | 59.6 s | ☆☆☆ | 89.5 | 2 | 0 | 6.1 s | 25.2 s | 7 | 3.0 % [4.3 %] | 4.1 s [5.7 s] | 3.1 % | 2/6/0 (0) | 0.00 | 1.6 s | 0 | ⏩ 3.0 % gap 4.1 s edge 0.44 **FAIL** |
| p00_curtain_up | required | OK | 67.5 s | ☆☆☆ | 87.5 | 2 | 0 | 33.2 s | 33.2 s | 4 | 1.8 % [2.7 %] | 4.1 s [5.0 s] | 2.2 % | 2/8/0 (0) | 0.00 | 1.6 s | 0 | ⏩ 1.8 % gap 4.1 s edge 0.62 **FAIL** |
| p00_curtain_up | slow | OK | 61.9 s | ☆☆☆ | 89.5 | 2 | 0 | 6.6 s | 27.6 s | 7 | 5.9 % [6.7 %] | 5.4 s [5.4 s] | 4.4 % | 2/6/0 (0) | 0.00 | 1.6 s | 0 | ⏩ 5.9 % gap 5.4 s edge 0.16 OK |

\* launch-relative (sim time + the episode's director `launch_offset_s`). ⏩ = the D1 gate: real time with the persona's ⏩ latch (hidden ticks weigh 1/3 only while ⏩ is held; dropped on prank fire / "?" / entry warning; ruling L2) and visible micro-gag beats. naive = every hidden tick 1/3 (Stage 1). Edge share **bold** above 1/3 (ruling L1).
