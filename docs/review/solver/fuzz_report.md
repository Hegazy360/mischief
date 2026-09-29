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
