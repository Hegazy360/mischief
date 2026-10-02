**r3d-qa round 3, phase 3: FAIL.** Rows 16, 17 and 19 fail; every other row from 1 to 20a passes.

Tree `446a69b` (content hash `b73588a30a7434b2`). Nothing in `game/` changed after phase 1. I made no git writes, switched no branches, and wrote no file under `reports/`: this answer is the report. Time: about 0.5 h (02:20–02:45Z).

## Pre-gate, row by row
Rows 1–18 and 20a are pass B from phase 1 (one run, alone). Row 19 was re-run alone at 02:42Z with `pregate3d.sh --rows=19`, and the record is archived as `docs/review/r3d-qa/pregate_r3.json`, with a `qa_note`.

| # | Result | Numbers |
|---|---|---|
| 1 | PASS | 1010 .import, 413 .uid |
| 2 | PASS | 1345/1345, 0 skipped, 139 files incl. tests/slice, 366 s |
| 3 | PASS | 72 clips strict, 0 errors / 0 warnings / 0 missing; coverage 72; 0 lints failed |
| 4 | PASS | 5 validators |
| 5 | PASS | 13 routes, every expect OK, 0 invariants, 0 catches on ideal; N01 ideal 116.3, N02 ideal 117.5, required 44.0 / 59.3 |
| 6 | PASS | worst ⏩ dead air 8.1 / 4.8 / 5.9 %; worst gap 5.47 s; edge share 0.221; N02 first prank 19.4 s |
| 7 | PASS | --auto proofs (N01 6, N02 5, P00 2); g0 ideal 23.6 s, ends `g0_done` |
| 8 | PASS | 2400 runs, 0 failed, 0 invariants, 0 soft-locks |
| 9 | PASS | 0 errors, 1 warning (D13) |
| 10 | PASS | 0 errors, 1 warning |
| 11 | PASS | 0 errors, 0 warnings |
| 12 | PASS | 26 route × mode runs, 0 violations; Bellows window share at most 35.0 % |
| 13 | PASS | accent f94, zoom 1.14 / 1.59, hit-stop 83 ms, Again ▶ 240 ms, frame p95 103 ms |
| 14 | PASS | 7 laughs by 60 s, crowd at most 0.254 s after each cue; slow route: first laugh 6.63 s, first prank 27.58 s |
| 15 | PASS | 13/13 scenarios; g0 and P00 0 fallbacks |
| 16 | **FAIL** (D18.2 spike rule only) | All counts and p50/p95 bars pass (draws p95 ≤ 81, tris ≤ 103,310, texture ≤ 110 MB, 0 compiles; view+HUD p50 2.65–3.04 / p95 3.82–4.43 ms). Spikes: 1 site in 3/3 rendered runs (NightScene t1283, 1.14–1.91 ms), plus 27 headless repeats against a chance baseline of 36/36. Pass A, on identical files, flagged a different site (t379), so the rule fires at chance level on this box |
| 17 | **FAIL** | Bellows 0.281 ms (266–290 µs) against 0.25; pass A on the same files gave 0.213 ms, and a re-check gave 279 µs. Hush 0.206 ms |
| 18 | PASS | retry 763 ms; tap feedback 1 frame; tap accuracy 20/20; P00 Next ▶ live on frame 1 |
| 19 | **FAIL** | spot **7/8** (pass); crowded **1/8** (pass, at the bar); verb 7/8 and 2D-vs-3D 8/8 carried from round 1; gags **3 of 9** at their bar |
| 20a | PASS | 73.53 MB, 3279 entries, 78 clip .res + 81 sidecars; exported pack loads 197 scripts with 0 failures, Night OK |
| 20b | pending the push | — |

## Row 19, round 3 (3 reviewers per packet, combined per D18)
- **Spot:** the three reviewers got 7, 6 and 7 right, so the median is 7/8.
  - All three now name the pickle jar as a jar, but all three read it as "spring snakes pop out".
  - One reviewer read the honey/pepper as hot chilli.
- **Crowding:** only Night 1 t6768 counts (2 of 3 said yes): his tea thought and the kettle's badge are two bubbles for one target.
  - Round 2's crowded P00 t2190 frame is fixed (0 of 3).
- **Gags:** in all 27 strip × score cells the three reviewers are within one point of each other, and 15 cells are identical.

| Gag | Median funny / readable / fresh | Bar | Verdict | Round 2 |
|---|---|---|---|---|
| g0 sneeze | 4/4/3 | 4/4/3 | PASS | 3/3/3 |
| P00 sneeze | 4/4/3 | 4/4/3 | PASS | 3/3/3 |
| curtain call | 3/3/3 | 3/3/3 | PASS | 2/2/2 |
| dizzy spin | 3/3/3 | 4/4/3 | FAIL | 3/4/3 |
| picture | 3/3/2 | 3/3/3 | FAIL (fresh) | 3/4/3 |
| door-frame bonk | 3/3/2 | 3/3/3 | FAIL (fresh) | 2/3/1 |
| vase | 2/3/2 | 3/3/3 | FAIL | 2/3/2 |
| squeak bit | 1/2/1 | 3/3/3 | FAIL | 1/2/1 |
| relief | 1/2/1 | 3/3/3 | FAIL | 1/2/2 |

## Requests (FAIL)
The full table is in `docs/review/r3d-qa/readability.md` §R3.6. No fix may regress the two sneezes, the curtain call, or the spot and crowding frames.

| # | What is wrong, and where | Change | Owner |
|---|---|---|---|
| 16 | D18.2 matches at chance level on this box: two passes on identical files flagged different sites | A ruling: judge spikes by replication across two passes, or accept the row on its counts plus p50/p95 and let the device log judge | lead |
| 16 | Overlay re-solve at t3351–3361, when the picture slides off his head | Precompute or warm the re-solve | r3d-hud (`world_overlays.gd`, `overlay_rules.gd`) |
| 16 | Sneeze reaction start at t1279–1284 | Warm it | r3d-view3d / r3d-fix-gags (`gag_stager_3d.gd`, `fx_3d.gd`), r3d-rig |
| 16 | Bellows apply at the bonk, t1676–1684 | Warm the staged clips through `prepare_clips` | r3d-rig / r3d-fix-gags |
| 17 | The host slowed 10–30 % after the restart | A ruling, or about a 15 % CPU cut on `rx_sneeze_blast_a` | lead; r3d-rig / r3d-cast-bellows |
| Q3-G1 | Relief: the `st_double_take` take reads as a T-pose (3/3; it also shows at curtain call f360); the "phew" reads as sweat; he walks in place | Re-pose the take; one readable phew puff that fades within ~40 f; no foot slide | r3d-anim-bellows-b; `hide_spot_3d.gd`, `cue_stager_3d.gd` |
| Q3-G2 | Squeak bit: with the sound off, nothing links cause and payoff | A squeak glyph that carries over to him; a visible voice crack; throat clutch with face to camera ≥ 30 f. Or the lead rules it a sound-led beat | r3d-view3d (`fx_3d.gd`, `cue_stager_3d.gd`), r3d-anim-bellows-b, lead |
| Q3-G3 | Picture: "the stock thing-falls-on-head gag" | He becomes the portrait and holds its pose; a contact pop on the hit; the crooked portrait in shot; no stomp in place | r3d-view3d / r3d-fix-gags, r3d-anim-bellows-c |
| Q3-G4 | Vase: no reaction registers; the vase is small and far from him | Move the vase into his shot (`house3d.json` `decor.parlour_vase`); a smug bow held ≥ 30 f; a bigger shatter | r3d-sets, r3d-anim-bellows-b, r3d-view3d |
| Q3-G5 | Bonk: "the plain walk-into-the-doorframe gag" | A twist inside the strip: he scolds the doorframe while the portrait swings askew in shot; a bigger wind-up the other way | r3d-view3d / r3d-fix-gags, r3d-anim-bellows-c, r3d-sets |
| Q3-G6 | Dizzy spin reads as a dance; his red face reads as angry | Make the cause physical (disc spin lines, a note ribbon pulling him round); spiral eyes and a queasy tint; a ~40 f hold ending nose to nose | r3d-anim-bellows-c, r3d-view3d, r3d-rig |
| Q3-C1 (at the bar) | N1 kettle: two bubbles for one target | Hide his thought while the badge carries his ring; a simpler `kettle_drum` | r3d-hud, `overlays_3d.gd` / `thought_bubble.gd` |
| Q3-S1 / S2 (spot passes) | Pickle gherkins read as snakes; the CHOO puff reads as steam (1 of 3) | Redraw `in_a_pickle.svg` and make the shelf prop a glass jar; optionally tune `achoo_ria.svg` | r3d-hud, r3d-sets |

After the fixes: a new gag packet with a new seed for three new reviewers. If the overlays or previews change, re-run the spot and crowding packets too. Then re-run row 19.

## APK
`/home/user/mischief/build/r3d/mischief-debug.apk`: **73,526,533 bytes (73.53 MB)**, sha256 **`fc4ad3ea145c27e921b880f559fae04ede92702bc62f290030b34170f3ea75ed`** (re-checked on disk).

## The 5 things the owner will notice first
1. **It is calm.** Four HUD pieces, sparse rooms, one countdown ring per target, and the badges sit on their props.
2. **The sneeze lands.** The pepper visibly falls into his cup, the stool launches into the sink, and he holds a dazed, face-up hold with stars. All three reviewers gave it 4/4/3.
3. **Bellows' double take is a T-pose:** both arms straight out, in the relief beat and for a moment in the curtain call.
4. **The smaller Prologue gags read but mostly don't land yet.**
   - The vase "ovation", the squeak bit (with the sound off) and the dizzy spin (it reads as dancing) miss.
   - The picture and the bonk are "the obvious version".
   - The curtain-call pelmet bonk is a good button, but the pelmet seems to hover above his wig.
5. **Hush's face is small at B's head size.** ×1.2 is still the recommendation.

## What I changed
- **Row 19 scoring:**
  - `docs/review/r3d-qa/readability.md`: a new Round 3 section with all 9 answer sheets verbatim per reviewer, the keys, the D18 combination, the verdict lines, what I saw and the requests. The pointer at the top now says round 3.
  - `docs/review/r3d-qa/pregate_r3.json`: now includes row 19, plus a `qa_note`.
  - `docs/review/r3d-qa/index.md`: new §R5.
  - `docs/review/r3d-qa/perf/{budgets,rigs}.png`: regenerated from this record (they were round 2's).
- **Owner pack, `docs/review/r3d/index.md`:** refreshed and still held behind the banner.
  - Re-shot from this build in sandbox `r3d-qa-shot`, with captions and MSAA off: `hud_2d_vs_3d`, `tinker_2d_vs_pepper_rig`, `pip_2d_vs_window`, and the 3D panel of `kitchen_before_after`.
  - New boards: `sneeze_r3`, `curtain_call_r3`, `crowding_r3`. `rig_ring_g0_t192` is rebuilt from a round-3 packet frame. `still_crowded_r2.jpg` is removed.
  - I looked at every image the pack links, and at all 45 packet images and strip pages.
- **`tools/scripts/pregate3d.sh` line 829:** the log cleanup now deletes only `row${row}.log` and `row${row}_*.log`.
  - I applied it after archiving, so the content hash moved to `8863336abbd0abcc`.
  - A `--rows` subset run on this tree will therefore show the archived rows as STALE; the `qa_note` explains this.
- **`docs/PROGRESS.md`:** the R3D section and a log line.
- **The r3d-qa `LANDED.md`:** lines appended, plus REQUESTS.
- **Scratch:** `<SP>/work/r3d-qa/p5/` holds the answers, the per-reviewer verdicts, `gen_r3.py`, `boards.py` and the shots.

## Deviations
- `docs/review/r3d-qa/` is 30 MB, over the 25 MB cap for a review folder. 29 MB of that is the round 1–3 packets, which were already committed in 446a69b. I did not recompress them because they are what the reviewers saw; whether to slim them is your call.
- The e2e wrapper also created a third sandbox folder, `r3d-qa-shot-shot` (67 MB), beyond the two allowed. Total disk use stays under 800 MB.