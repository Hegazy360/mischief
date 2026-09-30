# r3d-tools-a — the shared review toolset, run on fixtures and on the real look-dev images

The tools live in `tools/art3d/review/` (README there: one example per tool, the thresholds per consumer, the JSON
formats). Every artefact below was made by those tools and looked at; the numbers were checked against the eye.

| Artefact | What it shows | What to judge |
|---|---|---|
| `falsecolor_lookA_kitchen.png` | `lab.py falsecolor` on look A's in-game kitchen (`docs/review/lookdev/look-toy/ingame_kitchen.png`) with a hand-made ID pass (`tools/art3d/review/fixtures/lookdev/`): the image, its L* bands, its C* bands (band edges = the REDESIGN §3.7 thresholds), region medians with PASS/FAIL | The bands match the eye: the pale mint kitchen wall sits in the ≥ 85 band, the salmon floors in 62–76, Hush's navy in ≤ 40, Bellows' bouffant ≥ 85, the gramophone horn saturated. |
| `rules_lookA_kitchen.txt` | `lab.py rules --rules=set` on those regions | **Look A's look-dev room fails §3.7 as built** (it was never meant to be judged as a set): kitchen wall L* 90.6 (rule 62–76), parlour wall 78.6, floors 62–64 (rule 40–50), the pantry curtain C* 43.5 (rule ≥ 45 — just under), the white fireplace 17 L* off the pink wall (rule ≤ 15). Passing: wall chroma, the gramophone horn C* 66, Bellows' value rule. → `r3d-sets` builds darker walls/floors (the blockout values: wall 73, floor 44). |
| `value_lookA_hush.png` | `lab.py value --hist` on Hush (hand mask, ink outline included): histogram, masked pixels, dark / mid / light paint | **Hush fails the character rule in this frame: 11.9 % at L* ≥ 85 (need ≥ 20 %)**, 58 % at ≤ 40. The eye agrees: navy costume + bob are dark; the face paint is light only on its lit half, the shaded half and the red beret are mid. (Ink eroded by 3 px: 14.5 % / 51.8 % — still fails.) → `r3d-cast-hush`: brighter face paint / gloves / white stripes, the face card as big as R6 step 1 allows. |
| `value_lookA_bellows.png` | the same for Bellows | Passes: 32 % light (bouffant, waistcoat, cuffs), 37 % dark (plum jacket, ink). Matches the blockout's bouffant 91 / jacket 35. |
| `sil64_lookA_cast.png` | `sil64.py masks` on the two hand masks: 64 px silhouettes (1×, 2×), IoU matrix | Hush (hunched sneak, big head) and Bellows (a barrel under a puff) are different families: IoU 0.67 < 0.80. Both read at 64 px. |
| `strip_lookA_sneeze.jpg` | `strip.py` on the 66 frames of look A's `sneeze.gif` (frames 12–46, every 2nd, GIF frame numbers), marks: anticipation 20 (head back), accent 24 (the CHOO), key 28 (the launch), settle 36 (in the sink) | The strip format reviewers get: numbered cells at 600×270, outlined marks. Does the CHOO read on the accent cell? (Yes: the head is thrown down at f 24; the launch reads clearest at f 28–32.) |
| `pair_2d_vs_lookA.png` | `boards.py pair`: the 2D build's N1 kitchen at rest (`docs/review/r3d-ref2d/`) vs look A's 3D kitchen | The before/after format `r3d-sets`, `r3d-integrate` and `r3d-qa` use. The owner's complaints are visible: the 2D frame is crowded (HUD all round, PiP, 15+ props), the 3D one is calm. |
| `grid_lookdev_kitchens.png` | `boards.py grid` (at `--scale=0.5`): the three look-dev kitchens with labels + notes | The grid format (`hybrid_vs_ab.png` etc.); labels carry `×`/`≥` glyphs (Nunito). |
| `sil64_fixture.png` | `sil64.py masks tools/art3d/review/fixtures/masks` | Seven distinct prop families + a 5 %-scaled copy of the jar: only jar × jar_scaled_105 is flagged (IoU 1.00); bottle × clock is the closest distinct pair (0.78, amber). |
| `strip_fixture.jpg` | `strip.py` on the 24-frame fixture, every 3rd, marks anticipation 6 / accent 12 / settle 18 | Accent red, anticipation blue, settle purple; frame numbers printed. |
| `packet_example/` + `packet_example_verdict.md` | `packets.py build --kind=crops` on the fixture silhouettes (7 props, 10 choices incl. distractors) and `packets.py score` on a **synthetic** answer sheet (format demo, not a review) | The packet is opaque: `pkt_01.png … pkt_07.png`, `prompt.md` names no item outside the alphabetical choice list, the key lives in `<SP>/work/r3d-tools-a/packet_example_key.json`. The verdict: 6/7, "phone → lamp" as a confusion. |

Reference checks (`python3 -m unittest tools/art3d/review/test_review.py`, 51 tests, ≈ 10 s): the sRGB corners and
mid-grey within ±0.5 of the published CIELAB values; the blockout kitchen wall `#C7B684` → L* 74.4, C* 27.7; exact
medians and eroded pixel counts on synthetic ID passes; exact value shares; every §3.7 rule's pass and fail edge;
IoU 1.0 / ≈ 0 / ≥ 0.80 / scale- and position-invariant; 100 frames → one strip ≤ 4 MB with the accent outlined;
packets never carry a name (file names, PNG text chunks, prompt) and scoring reproduces a known sheet; the look-A
kitchen numbers above are pinned; the perf budgets (regions / value ≤ 2 s, sil64 20 masks ≤ 5 s, strip 150 frames ≤ 10 s).
