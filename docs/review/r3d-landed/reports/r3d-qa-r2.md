**Verdict: FAIL.** Rows 9, 16 and 19 fail; every other row from 1 to 20a passes. The owner pack stays held. It was refreshed with the round-2 results and new shots from this build, and its "not ready" banner stays because those three rows are still red.

Tree: `5f0092b` plus r3d-fix-hud2's working tree. I made no git writes and switched no branches. I did not write `reports/r3d-qa.md`, because my rules forbid report files, so this answer is the report.

## Pre-gate, row by row
Rows 1–18 and 20a ran alone at 13:58–16:40Z (row 8 ran with `--force`; it is sim-only). Row 19 ran alone at 17:03Z with `tools/scripts/pregate3d.sh --rows=19`.

The record is `/home/user/mischief/docs/review/r3d-qa/pregate_r2.json`. Its table marks rows 1–4, 9–18 and 20a "STALE". That happens only because phase 1 edited `pregate3d.sh` after its run, which changed the content hash. No file in `game/`, `tools/ci`, `tools/art3d/review` or `tools/audio` changed after 13:58Z, so those results stand; the `qa_note` in the record says so.

| # | Result | Numbers |
|---|---|---|
| 1 | PASS | 1010 .import, 412 .uid |
| 2 | PASS | 1312/1312 tests, 0 skipped, 138 files incl. 2 in tests/slice |
| 3 | PASS | 72 clips strict, 0 errors / 0 warnings / 0 missing |
| 4 | PASS | 5 validators |
| 5 | PASS | 13 routes, every expect OK, 0 invariant violations, 0 catches on ideal |
| 6 | PASS | worst dead air (ff): ideal 8.1 %, required 4.8 %, slow 5.9 %; worst gap 5.47 s; edge share 0.221 |
| 7 | PASS | planner proofs; g0 ideal ends `g0_done` |
| 8 | PASS | 2400 runs, 0 invariants, 0 soft-locks, 0 commands on a struck hotspot |
| 9 | **FAIL** | 2 errors on the P00 parlour vase, which is still flagged `dressing`: C* 42.7 > 30 and \|ΔL*\| 20.79 > 15 against the wall. 1 warning (N02 hall, D13) |
| 10 | PASS | 0 errors, 1 warning |
| 11 | PASS | 0 errors, 2 warnings (middle-band window punch of 0.0 s, within D9/D10) |
| 12 | PASS | 26 route × mode runs, 0 violations; window share at most 35.0 % (was 39 %) |
| 13 | PASS | accent f94; zoom 1.14 at the accent, 1.59 max; hit-stop 83 ms; 0 compiles; Again 272 ms |
| 14 | PASS | ideal: 7 laughs by 60 s, crowd ≤ 0.268 s after each cue; slow: first laugh 6.63 s, first prank 27.58 s |
| 15 | PASS | 13/13 routes; g0 and P00 have 0 fallbacks |
| 16 | **FAIL** (D17) | Every count passes: draws p95 ≤ 82 / max 101, tris ≤ 101,162, texture ≤ 110.7 MB, 0 compiles in PLAY; view+HUD p50 2.91–3.16 ms, p95 4.28–4.72 ms. But 11 call sites go over 1 ms at the same tick in ≥ 2 of 3 rendered runs, and 20 headless hits repeat in another run |
| 17 | PASS | Hush 0.159 ms / 2 draws / 9812 tris / 48 bones; Bellows 0.198 ms / 4 / 9495 / 50 |
| 18 | PASS | retry 632 ms; tap feedback in 1 frame; tap accuracy 20/20; Next ▶ live on frame 1 |
| 19 | **FAIL** | spot 6/8 (pass); crowded 2/8 (bar ≤ 1); gags 1 of 9 at their bar; verb 7/8 and 2D-vs-3D 8/8 carried from round 1 |
| 20a | PASS | 73.47 MB; exported pack loads 197 scripts with 0 failures and builds a 3D Night |
| 20b | pending the push | — |

## Row 19, round 2
Every answer and its key is in `docs/review/r3d-qa/readability.md` under "Round 2". I scored each packet with `packets.py`, looked at every packet image and strip page, and judged the gist by hand.

- **Spot, 6/8 (pass at the bar).** The sneeze preview now reads as a sneeze.
  - The pickle jar was read as "a vase that falls on his head".
  - The kettle that still needs the squeaker was read as "a honk that startles him", so it is not counted.
- **Crowding, 2/8 yes (fail).**
  - Round 1's crowded Gate-0 rig frame now reads as "no".
  - Prologue t2190: his countdown ring is drawn twice for the gramophone (in his thought and on its preview badge), and the badge floats about 200 px away from it.
  - Night 1 t6768: this frame is nearly identical to the one round 1's reviewer called "no", so this one is partly reviewer variance.
- **Gags, 1 of 9 at their bar (fail).**

| Gag | Round 2 (funny / readable / fresh) | Round 1 | Bar |
|---|---|---|---|
| picture | 3/4/3 — **passes** | 1/1/1 | 3/3/3 |
| dizzy spin | 3/4/3 | 3/3/4 | 4/4, fresh 3 |
| vase | 2/3/2 | 1/2/1 | 3/3/3 |
| doorframe bonk | 2/3/1 | 2/2/2 | 3/3/3 |
| curtain call | 2/2/2 | 3/3/3 | 3/3/3 |
| relief | 1/2/2 | 1/3/1 | 3/3/3 |
| squeak bit | 1/2/1 | 1/3/1 | 3/3/3 |
| both sneezes | 3/3/3 each | 4/4/3 each | 4/4, fresh 3 |

The sneeze clip did not change in fix round 1, and three earlier reviewers gave it 4/4/3. This drop is one reviewer scoring differently, but this reviewer named the same two faults as round 1.

## Requests (an r3d-integrate re-run, alone)
| Row | What is wrong, and where | Change | Owner |
|---|---|---|---|
| 9 | In `game/data/house/house3d.json`, `decor.parlour_vase` is still `"dressing": true` | Drop the flag, then re-run `lint3d --set --all-nights` and the set3d tests | r3d-sets / integrate |
| 16 (a) | `ov_apply` (WorldOverlays.apply) at t255–263: 0.88–1.11 ms in 3 of 3 rendered runs, 4.37 ms headless | Warm that first overlay show under the curtain | r3d-hud |
| 16 (b) | Hush's CharacterView3D `mine` at t977–996, while she hides in the pantry: 2.3–3.9 ms | Precompute that work | r3d-view3d |
| 16 (c) | Hush's apply at t2846 (1.98 ms in two runs) and `ov_apply` 3.15 ms at t2842, behind the piano; NightScene at t1572 in both headless runs | Warm or precompute | r3d-view3d / r3d-fix-gags |
| 16 | D17's "≥ 2 of 3 rendered runs" matches at chance level on this box (11 clusters, against 9–18 with the runs shifted) | Ruling: count a site only if it repeats in 3 of 3 rendered runs, in both headless runs, or in a rendered plus a headless run | lead |
| 19 Q2-C1 | crowd pkt_04, P00 t2190 | One countdown ring per target; keep a badge within about 80 px of its prop or give it a tail; hide his awareness glyph and ear pips while his thought shows; add a layout test | r3d-hud (`overlay_placer`, `overlay_rules`, `preview_cloud`); `overlays_3d.gd`; `thought_bubble.gd` |
| 19 Q2-C2 | crowd pkt_07, N1 t6768 | Same as Q2-C1; move the N1 pickle-jar shelf off Hush's head line | r3d-hud, r3d-sets |
| 19 Q2-G1 | sneezes, g0 t1163 and P00 t1375 | Dazed sink hold: head up, face to camera (D8), bouffant above the brows, jabot down, at least 30 frames; show the pepper falling during the build-up | r3d-anim-bellows-a, r3d-rig (gaze), r3d-view3d |
| 19 Q2-G2 | dizzy spin, t2659 | A slower 2-turn spin inside the locked window, so he reads as spun by the record; shoot this strip every 6 ticks, not 9 | r3d-anim-bellows-c, r3d-view3d, r3d-qa |
| 19 Q2-G3 | relief, t3238 | A double take at the hidden eyes with a 30-frame hold, then her "phew" puff as the payoff | r3d-view3d / r3d-fix-gags (`hide_spot_3d`), r3d-anim-bellows-b |
| 19 Q2-G4 | squeak bit, t230 | Put his throat-clutch answer on the main screen: a cue shot, or a window at least ⅓ of the screen | r3d-view3d, r3d-anim-bellows-b, r3d-anim |
| 19 Q2-G5 | vase, t138 | Give him a reaction beat he holds for 30 frames; keep the shot on him until it ends | r3d-view3d, r3d-anim-bellows-b |
| 19 Q2-G6 | bonk, t1677 | No camera cut within 30 frames of the hit; an anticipation the other way; a 30-frame face hold; a fresher twist (the bonk tilts the portrait that falls later); keep his 3D bubble out of the RUNNING GAG bar | r3d-view3d / r3d-fix-gags, r3d-anim-bellows-c, r3d-sets |
| 19 Q2-G7 | curtain call | Pelmet drop centre-left, clear of the buttons and inset; a fast drop; a 30-frame face hold | r3d-night, r3d-hud, r3d-anim-bellows-c |
| 19 Q2-G8 (passed) | picture | The frame pops off his head; let it slide off instead | r3d-view3d |
| 19 Q2-S1/S2 (at the bar) | pickle jar; kettle that needs the squeaker | Make the jar read as a pickle jar; show the duet in the `kettle_drum` pictogram; can wait for R3 | r3d-sets, r3d-hud |

For the next row-19 run I suggest at least 3 reviewers per gag packet, scored by median.

## The APK
`/home/user/mischief/build/r3d/mischief-debug.apk`, **73,468,995 bytes (73.47 MB)**, 3277 entries, sha256 **`9478f00dc5dec2dca1c17a38beb8dc00652091b5997d089dac81c237e6446316`** (re-checked at 17:05Z).

## Five things the owner will notice first
1. **It is calm.** Four HUD pieces, big characters and sparse rooms; the rig moment on the stool now shows one clear ring on the pot and nothing on her head.
2. **The sneeze still lands as slapstick** (the stool launch into the sink, the Stalls rising). But in the dazed hold his face is hidden under the bouffant and the jabot, and nothing shows the pepper.
3. **The busy moments show his countdown ring twice** (in his thought and on the prop's badge), with the badge floating away from the gramophone or kettle.
4. **The small Prologue gags now show cause and contact**, and the picture passes. Most still lack a payoff: he never reacts to the vase, the relief has no "phew", the squeak's answer is inside the small window, and the curtain-call bonk is small beside the buttons.
5. **Hush's face is small at B's head size** and reads only when she turns to camera. The ×1.2 head is the recommended answer.

## What I changed
- `docs/review/r3d-qa/readability.md`: added a pointer at the top and a full Round 2 section at the end; round 1 is kept unchanged above it.
- `docs/review/r3d-qa/index.md`: new §R3 for this phase.
- `docs/review/r3d-qa/pregate_r2.json`: the archived record, with the `qa_note`.
- `docs/review/r3d-qa/perf/{budgets,rigs}.png`: regenerated from this run's record.
- `docs/review/r3d/index.md`: the owner pack, refreshed and still held.
- New boards in `docs/review/r3d/`: `hud_2d_vs_3d.jpg`, `tinker_2d_vs_pepper_rig.jpg`, `pip_2d_vs_window.jpg` and `kitchen_before_after.jpg` (3D frames re-shot live from this build at the 2D-reference ticks, sandbox `r3d-qa-shot`); `rig_ring_g0_t192.jpg` and `still_crowded_r2.jpg` (built from the round-2 packet frames). I looked at every image the pack shows.
- `docs/PROGRESS.md`: the R3D section and a log line.
- The r3d-qa `LANDED.md`: lines added, including the round-2 requests under REQUESTS.
- Scratch: `<SP>/work/r3d-qa/p4/` holds the answers, the scorer's verdict files, the crops and the board script.

## Deviations
- My first board-shoot run passed bad arguments. It wrote 18 empty frames into a stray `/home/user/mischief/p4/` folder, which I deleted, and then I re-shot correctly. Every Godot run went through the slot scripts, one process at a time.
- I did not re-run rows 9 or 16, because nothing was fixed after phase 1's run.

Time spent: about 0.4 h.