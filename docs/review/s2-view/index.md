# s2-view — review index (Stage 2 batch 1)

All shots are 1200 × 540 (a 20:9 phone held sideways), in the real view stack (`view/sandbox/ViewSandbox.tscn`)
with the **real Hush and Bellows rigs** — never the Stage-1 puppets. Where a clip is not authored yet the
view falls through to the next map key (counted by `WorldView.fallback_counts()`); `--fixtures` adds
s2-view's static-pose fixture clips (`tests/view/fixtures/anim/`) only for rigs whose real `map.json` is
missing. Judge at phone scale: does it read in half a second, does it answer the thumb, is it funny.

| Artefact | What it shows | What to judge |
|---|---|---|
| `slice_clips.md` | `SliceClips.build()` — every clip the slice can play, expected length, tolerance, loop rule, why | the one manifest (L14) the lints and anim tests check against |
| `g0_sneeze_sheet_1.jpg`, `g0_sneeze_sheet_2.jpg` | ACHOO-RIA! on the **real SimWorld** (`--sim --episode=g0_sneeze --cmds=<g0 ideal dump> --seek=1120`), every 6th frame from the tea approach to the dazed blind shuffle | the whole gag reads without sound; the camera pushes in on the CHOO; the caption lands on the accent |
| `g0_choo_zoom.jpg` | f33–f54 at a larger size | the house stool hides on the CHOO frame (clip `decor` event) and only the rig's stool rides the flight — never two stools; the punch-in (≈1.3×) and the ACHOO-RIA! caption on the accent frame; the spray |
| `g0_landing_zoom.jpg` | f57–f120 | he lands in the sink behind the `kitchen_sink_lip` (decor z 2, over the characters); the hold; he comes out FRAZZLED with the bouffant flipped over his eyes (blind shuffle); the house stool comes back once the clip is over |
| `g0_f033.jpg` … `g0_f090.jpg` | single frames of the same run | face in the hold, the caption size at phone scale |
| `p00_vase_smash.jpg` | the Prologue's `laugh_vase` cue (real sim, P00 ideal dump): the vase creeps along the mantel on his warm-up notes, tips and smashes (shards + dust) | the smash is on screen (left edge) and in the PiP |
| `p00_sheet_1.jpg` … `p00_sheet_4.jpg` | the whole Prologue on the **real SimWorld** (`--sim --episode=p00_curtain_up --cmds=<P00 ideal dump>`), every 15th frame f0–f4185 (the sim ends at tick 3573) | the climb-in, Hush in the pantry (hidden eyes), the sneeze, the blind shuffle, the hunt, ALLEGRO-GO-GO! at the piano; director beats vase / door-frame / relief / picture (`cue_picture_bonk` not authored yet: it falls back) |
| `p00_sneeze_zoom.jpg`, `p00_allegro_zoom.jpg` | f1410–f1575 and f2580–f2745 of the same run, larger | the sink landing + blind shuffle out of the kitchen; the piano punch-in, caption + RUNNING GAG stamp, Hush's eyes under the piano, the Stalls on their feet |
| `micro_gag.jpg` | a micro-gag (`pinkie_up`) on the overlay layer over the real tea loop | the gag plays over the base without popping it |
| `hidden_eyes.jpg` | Hush hidden in the pantry: animated eyes at the hotspot's `eyes` point, pupils tracking Bellows (±6/±3 px), blinking 6 f every 2–6 s | the eyes read as "she's in there" |
| `queued_tap.jpg` | a tap during the climb-in: `cmd_queued` → pulsing marker with a "…" badge, then the dotted path when the command runs | a tap never says "nothing happened" |
| `doorframe.jpg` | `laugh_doorframe`: stars at the parlour_kitchen frame + his `cue:laugh_doorframe` overlay over the blind shuffle | the bonk reads at phone scale |
| `stairs.jpg` | the stairs demo: Bellows on the landing, **his own legs** at the top of the screen as he heads for the stairs, the Stalls' BEHIND YOU! (point frames) | the warning reads before he appears |
| `caught.jpg`, `busted_rig.jpg`, `caught_sheet_1.jpg`, `caught_sheet_2.jpg` | caught → Busted Cam re-stage (real rigs replaying their recorded clips, sight line, split frame) → Lecture (Hush's braces on his grip socket) → wipe → doorstep | two rigs, one transform chain; the doorstep bonk. The `lec_*` / `lec_dangled` clips are not authored yet, so the attach holds her against his idle pose (she reads as a lump on his chest at phone scale): re-shoot when the Lecture clips land |
| `stalls_sheet.jpg` | the Stalls from `stalls.json` (layout order, face_dir leans, point frame, tumble frames at 8 f) through the sneeze gag (`--scenario=gag_punch`, every 10th frame) | laugh track visible, never covering play |
| `rig_<scenario>.jpg` | the Stage-1 scenarios re-shot with real rigs (walk, bubble, stare_off, stare_on, squeak_rings, entry_warning, gag_punch, captions, pip, pip_escalate, spotted, near_miss, busted_cam, stalls_t4, overview, peek, micro_gag, hidden_eyes, queued_tap, residue, squeak_bit, stairs) | no puppet anywhere; props at scale 1 from `art_pos`; gold outlines on the pale kitchen / hall |
| perf line (in the report) | `--scenario=pip --perf-log` with two rigs + PiP + a gag burst: `draw calls avg 97.2 p95 130 max 142 \| objects max 288 \| particles max 40` (llvmpipe; process ms not meaningful on a shared software renderer) | ≤ 150 draw calls p95 |

Reproduce (repo root): see `<SP>/reports/s2-view.md` §Verification. Contact sheets: `sheet.py` in the task's
scratch dir (PIL).
