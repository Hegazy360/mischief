# r3d-fix-night2 — fix round 2 (after QA round 2): the curtain call, his bubble, NightScene t1572

Key `r3d-fix-night2`. Requests: **Q2-G7** (the curtain call: 2/2/2, bar 3/3/3), **Q2-C1** (his bubble's glyph: one thing per
head), **16(c)** (NightScene at t1572 in both headless runs). Also r3d-fix-hud3's R1 (`ring_hidden`) and R2 (the shared
overlay placer), which fall in this key's files.

Every frame on this page is the real game: `e2e.sh prologue_ideal --fixed` (P00) or `n01_ideal` (N1), 1200×540,
`--no-captions`, MSAA off, the same route and ticks as QA round 2's packets (strip ticks 3577–4267 every 30; frame j ↔
engine frame 3570 + 3j ↔ tick − 5, QA's mapping). "before" = this tree before my edits (it matches QA's packet pkt_07
frame for frame); "after" = the final tree.

## 1. Q2-G7 — the curtain call

Reviewer (round 2): *"… a stage pelmet lowers onto his head and leaves him with dizzy stars (f540–690); the mime's bow
reads in silhouette, but his bonk is small and the menu covers it."* QA: the pelmet came down over ~30 f at x ≈ 940 px,
between the Gag Reel inset and Night 1 ▶; the title card covered Hush for its 1.2 s hold; the reel printed its pun
captions under `--no-captions`.

| | before (`before/curtain_call_{1,2,3}.jpg`) | after (`after/curtain_call_{1,2,3}.jpg`) |
|---|---|---|
| Hush's bow | centre; the title card lands over her (f180–210: legs only) | she walks in to x 0.30 and bows; the card lands at x 0.60 — she stays in view beside it |
| the title card | still drawn under the results' first frame (f240) | leaves when the results show |
| his walk-on | from the right, behind Night 1 ▶ and the reel inset, on the far band (≈ 32 % of the height, face ≈ 20 px) | from the left wing to x 0.28 (336 px), on a nearer plane (`CurtainBows3D.BIT_Z`: ≈ 46 % of the height) — his face reads |
| the set-up | none: the pelmet appeared at the reel's end | double take at the audience (f360), slow burn — he reddens, glaring at them (f390–450) — and the pelmet lurches into view at the top above him and **wobbles on its ropes** for 0.6 s (one rope slips, dust sifts, a creak): f480 |
| the hit | a 0.12 s lowering at x ≈ 940, under the results' navy wash | the ropes snap, it **drops in 4 frames** onto his head: an impact star, he is squashed into his knees (0.82 → 1.05 → 1), the pelmet squashes (f510) |
| the hold | small, beside the buttons | his dazed face (specs, `st_bonk`) **to camera** (gaze + 70° cheat) with stars circling, **≥ 60 f**, no cut, the reel inset static (f510–f570) |
| the button | — | he straightens and tugs his cravat with the pelmet on like a crown (f570), then glares at the audience under it (looping) while the call waits (f600–690) |
| the reel inset | "ACHOO-RIA!" / "ALLEGRO-GO-GO!" printed under `--no-captions` | no pun caption under `--no-captions` |

What I looked at (after, 1200×540, the packet's ticks): f480 — the pelmet hangs, tilted, above his head while his red
face glares at the camera; f510 — it is on his head, stars, his dazed face; f540 — the dazed face held; f570 — the
cravat tug; f600–690 — the glare under the pelmet. `after/curtain_bonk_beats.jpg` shows the beats every few frames
from the same run (f462 it lurches in, f480 it wobbles, f492 the drop, f498 the contact, f516 and f546 the hold). Nothing overlaps the reel inset, Night 1 ▶ or the results' text; his
feet pass behind Retry for ~0.4 s on the walk-on (f300).

Rubric (TECH §11): set-up before the hit (the wobble he never sees, while he fumes at the audience) ✓; the hit in frame
with contact (4 f drop, impact star, squash) ✓; a held reaction on his face to camera ≥ 30 f (D8; ≥ 60 f by
`bit_plan`) ✓; no camera cut (the bows' lip camera is fixed) ✓; one payoff the eye cannot miss (the pelmet on his
head, centre-left, drawn above the results panel) ✓. The schedule (`CurtainApron.bit_plan(dur)`) puts the hit 1.0 s
before the reel step ends (Prologue 5.0 s: hit at 4.0 s); a reel that ends early now **waits** for the hold
(`bit_done()`); a tap drops the pelmet at once (4 f). Lengths unchanged (Prologue ≤ 10.4 s).

Iteration frames (real-time NightScene `--curtain-call=prologue_done`): `iter_hit6.jpg` (the drop and the hit, full
size), `iter_hold6.jpg` (the dazed hold and the topper — the topper's look-round T-pose that I cut after seeing it).

## 2. Q2-C1 — his bubble: one thing per head (and r3d-fix-hud3 R1)

`game/view/fx/thought_bubble.gd`:
- while his thought (the next activity) shows, **no awareness-glyph disc and no empty ear-pip slots** beside the cloud;
- the squeaks he has heard (1–3 ear pips — the squeak verb's feedback) ride as **gold beads on the cloud's lower-right
  rim**, inside the cloud's span;
- the glyph + pip slots draw only when no thought shows, alone, where the cloud would be (`glyph_shown`);
- `ring_hidden` (hud3 R1): both ring arcs are skipped while a preview badge carries his ring (WorldOverlays sets it) —
  **one countdown ring per target**;
- the cloud: `thought_bubble.svg` clips its own right lobe at its 150-unit viewBox (it was hidden behind the glyph
  disc; with the disc gone the flat cut showed). The bubble now rasterises the same path in a 160-wide viewBox once
  (`ViewKit.svg_tex`, one textured draw). A first try drew the lobes every frame and broke 2D batching (draws p95
  g0 55 → 93, P00 67 → 93, N1 82 → 117 in those runs); with the texture: g0 55 / 61, P00 67 / 76, as before.

| file | what it shows |
|---|---|
| `bubble_p00_t2190_before_after.jpg` | crowding pkt_04 (P00 t2190) above, the same tick now below: his thought = the gramophone icon only, the badge beside the horn carries the one red ring |
| `bubble_p00_t2190_zoom.jpg` | his bubble before (icon + red ring + glyph disc + 3 pip slots) / after (icon only, full cloud) / t675 after one heard squeak (a gold rim bead) |
| `bubble_n01_t6768_before_after.jpg` | crowding pkt_07 (N1 frame 6768): before, two red rings (the kettle badge and his tea thought) + the spectacles glyph; after, one ring (the kettle badge), his tea thought plain, no glyph |

## 3. The shared overlay placer (r3d-fix-hud3 R2): tried, then held

hud3 asked `NightScene._setup_overlays()` to give Overlays3D the WorldOverlays placer (his bubble in the §2.5 one-cloud
rule; captions placed by the same solver) and to check the captions. I wired it and shot P00 with captions ON:
- `caps_accents.jpg`: ACHOO-RIA! shows through the sneeze;
- `caps_allegro_shared_vs_not.jpg`: with the shared placer, **ALLEGRO-GO-GO! vanishes** when the camera punches in
  (t2672 onwards: Overlays3D._place_shared hides a caption the placer makes wait, and the punch-in's face box blocks it);
  without it (this tree) the caption stays above his head to t2720;
- `caps_cues.jpg`: the director cues (vase, bonk, picture) have no pun caption.

So R2 is **not landed**: `_setup_overlays()` carries a note, and the wiring line goes in once a blocked caption keeps
showing (request in the report). The bubble changes of §2 do not depend on it.

## 4. 16(c) — NightScene at t1572: not reproduced

Three headless `prologue_ideal --perf-log --view3d-prof` runs on the live tree (19:10–19:20Z; QA's 4.68 / 1.22 ms was
`ov_apply`, WorldOverlays.apply): in t1560–1590 the NightScene phases peak at 1.13 ms (h1, t1585 `ov_apply`), 0.39 ms
(h2), < 1 ms (h3; its `--ov-dump-slow=1200` probe lists no slow WorldOverlays.apply there). No code change.
The pairs of headless runs name a different "deterministic" site each (h1+h2: NightScene t536 `ov_apply` 3.79 / 3.20 ms,
0.43 ms in h3; h1+h3: t365; h2+h3: t545), and 2–3 pair matches sit inside the chance baseline of the same pairs shifted
by ±60–120 ticks (0–5): "both headless runs" matches at chance on this box too (lead / QA note in the report).

## 5. Tests and checks (final tree)

- `night/` 126/126, `rig3d/` 61/61, full suite 1345/1345 (139 files) — see the report for the final re-run;
- `SANDBOX=r3d-fix-night2-lint tools/scripts/lint.sh --strict`: OK (72 clips strict, 0/0/0); `check_import_meta`: OK;
- `e2e g0_sneeze --strict --perf-log`: PASS, 0 fallbacks, draws p95 55 / max 61;
- `e2e curtain_call`: PASS — P00 9.8 s (reel 5.01 s, ≤ 10.4), N1 first / repeat done, Next ▶ live on frame 1, WIP → N01,
  N02 → To be continued → Playbill, g0 Again ▶ 263 ms.

Tests added or changed: `night/test_curtain_call_table.gd` (+4: the bit's schedule fits 4 / 5 / 8 s reel steps with
≥ 30 f of hold and a 4 f drop; the staging is clear of the reel inset, Next ▶ and Retry; the pelmet wobbles on its
ropes, then drops in ~4 f onto his head and the hold completes; a tap drops it at once), `night/test_bubble_edge.gd`
(rewritten, 8: no glyph beside the thought, the glyph alone without one, nothing past the cloud span at the edge,
rim beads outside the ring and inside the span, `ring_hidden`, `waiting`), `night/test_night3d.gd`
(`test_his_bubble_in_a_night_is_one_thing_per_head`).
