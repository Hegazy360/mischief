# Solver report

| episode | route | ok | duration | stars | applause | lines | catches | 1st laugh* | 1st prank* | laughs@60* | dead air ⏩ [sim] | max gap ⏩ [sim] | ⏩ naive | beats room/pip/edge (hidden) | edge share | hold | near misses |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| n01_throat_tea | ideal | OK | 138.3 s | ★★★ | 116.3 | 6 | 0 | 0.5 s | 17.5 s | 5 | 7.9 % [14.3 %] | 4.0 s [10.6 s] | 9.4 % | 6/9/0 (0) | 0.00 | 6.4 s | 0 |
| n01_throat_tea | required | OK | 79.0 s | ★☆☆ | 44.0 | 3 | 0 | 18.7 s | 18.7 s | 2 | 4.8 % [5.2 %] | 5.5 s [7.0 s] | 5.7 % | 5/6/2 (0) | 0.22 | 3.1 s | 0 |
| n01_throat_tea | slow | OK | 85.3 s | ★☆☆ | 46.0 | 3 | 0 | 3.6 s | 24.4 s | 3 | 2.1 % [4.6 %] | 4.4 s [6.1 s] | 2.6 % | 6/6/2 (0) | 0.16 | 3.1 s | 0 |
| n01_throat_tea | caught | OK | 86.7 s | ★☆☆ | 48.4 | 3 | 1 | 25.4 s | 25.4 s | 1 | 5.2 % [4.6 %] | 6.2 s [6.2 s] | 5.8 % | 5/7/3 (0) | 0.31 | 4.2 s | 0 |
| n01_throat_tea | chase | OK | 82.8 s | ☆☆☆ | 0.0 | 0 | 0 | 68.7 s | — | 0 | 17.6 % [21.0 %] | 5.0 s [13.0 s] | 18.1 % | 5/7/0 (0) | 0.00 | 0.0 s | 0 |
| n01_throat_tea | meltdown | OK | 53.2 s | ☆☆☆ | 71.9 | 3 | 0 | 0.5 s | 17.5 s | 5 | 13.9 % [24.6 %] | 4.2 s [11.6 s] | 17.9 % | 1/2/0 (0) | 0.00 | 3.1 s | 0 |
| n02_something_fishy | ideal | OK | 149.3 s | ★★★ | 117.5 | 5 | 0 | 0.5 s | 19.4 s | 5 | 6.9 % [12.5 %] | 3.9 s [10.7 s] | 8.1 % | 7/11/0 (0) | 0.00 | 8.6 s | 0 |
| n02_something_fishy | required | OK | 55.4 s | ★☆☆ | 59.3 | 3 | 0 | 19.4 s | 19.4 s | 4 | 1.9 % [3.9 %] | 3.7 s [7.1 s] | 2.5 % | 2/6/0 (0) | 0.00 | 3.8 s | 0 |
| n02_something_fishy | slow | OK | 56.0 s | ★☆☆ | 61.3 | 3 | 0 | 3.6 s | 19.4 s | 5 | 1.6 % [3.8 %] | 4.7 s [7.1 s] | 2.1 % | 3/5/0 (0) | 0.00 | 3.8 s | 0 |
| n02_something_fishy | face_to_face | OK | 66.4 s | ☆☆☆ | 13.4 | 1 | 0 | 19.4 s | 19.4 s | 2 | 6.1 % [9.3 %] | 4.9 s [7.7 s] | 6.8 % | 5/6/0 (0) | 0.00 | 1.5 s | 1 |
| n02_something_fishy | face_to_face_lost | OK | 62.6 s | ☆☆☆ | 6.4 | 1 | 1 | 19.4 s | 19.4 s | 1 | 12.9 % [10.7 %] | 6.1 s [8.2 s] | 14.2 % | 4/6/0 (0) | 0.00 | 1.5 s | 0 |
| p00_curtain_up | ideal | OK | 59.6 s | ☆☆☆ | 89.5 | 2 | 0 | 6.1 s | 25.2 s | 7 | 3.0 % [4.3 %] | 4.1 s [5.7 s] | 3.1 % | 2/6/0 (0) | 0.00 | 1.6 s | 0 |
| p00_curtain_up | required | OK | 67.5 s | ☆☆☆ | 87.5 | 2 | 0 | 33.2 s | 33.2 s | 4 | 1.8 % [2.7 %] | 4.1 s [5.0 s] | 2.2 % | 2/8/0 (0) | 0.00 | 1.6 s | 0 |
| p00_curtain_up | slow | OK | 62.5 s | ☆☆☆ | 89.5 | 2 | 0 | 6.6 s | 28.2 s | 7 | 5.9 % [6.6 %] | 5.4 s [5.4 s] | 4.3 % | 2/6/0 (0) | 0.00 | 1.6 s | 0 |
| g0_sneeze | ideal | OK | 23.6 s | ☆☆☆ | 70.0 | 1 | 0 | 19.4 s | 19.4 s | 1 | 8.1 % [10.5 %] | 3.9 s [6.0 s] | 7.2 % | 1/2/0 (0) | 0.00 | 0.8 s | 0 |

\* launch-relative (sim time + the episode's director `launch_offset_s`). ⏩ = the D1 gate: real time with the persona's ⏩ latch (hidden ticks weigh 1/3 only while ⏩ is held; dropped on prank fire / "?" / entry warning; ruling L2) and visible micro-gag beats. naive = every hidden tick 1/3 (Stage 1). Edge share **bold** above 1/3 (ruling L1).
