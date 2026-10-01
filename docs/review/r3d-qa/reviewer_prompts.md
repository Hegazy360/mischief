# Row 19 — reviewer prompts (r3d-qa §3.3)

Five opaque packets, built from the real game (NightScene, 1200×540, captions off, MSAA off) with
`tools/art3d/review/packets.py`. Each packet folder holds its own `prompt.md` (the question, the context and a fixed
answer format) and the images under opaque ids `pkt_XX`, shuffled with a fixed seed. The answer keys are **not** in the
repository (they live in the r3d-qa scratch directory, `keys/<packet>_key.json`), so nothing a reviewer can open tells
them what an item is.

## How to run them

- One **fresh** reviewer per packet: an agent that has not seen this game, its docs, its code or another packet.
- Give it exactly two things: the text of the packet's `prompt.md` and read access to the images in that folder.
  Nothing else: no file names outside the folder, no design notes, no other packet, no hint about what is expected.
- Ask for the answer in the prompt's format only (one line per id). Keep the reply verbatim.
- Score with `python3 tools/art3d/review/packets.py score <key.json> <answers.md> --out=<verdict.md>`; the automatic
  match is a helper (it flags `unmatched` answers for a human); the gist decides. Record every answer verbatim, the
  key and the verdict in `docs/review/r3d-qa/readability.md`, with one `verdict …` line per test (format below) for
  pre-gate row 19.

| Packet folder | Test | Items | Answer format | Pass (index §6 row 19) |
|---|---|---|---|---|
| `packets/set_a/` | verb: what is the player character doing | 8 frames | free text | ≥ 7/8 right |
| `packets/set_b/` | spot: what happens if the neighbour uses the circled object | 8 frames | free text | ≥ 6/8 the gist of the joke |
| `packets/set_c/` | crowding: is this screen crowded or confusing | 8 frames | yes / no + why | ≤ 1/8 yes |
| `packets/set_d/` | the same moment drawn two ways, A or B | 8 pairs | A / B + why | the 3D side preferred ≥ 6/8 |
| `packets/set_e/` | gag strips: what happens + funny / readable / fresh 1–5 | 9 strips | scores | sneeze + dizzy spin ≥ 4 funny and readable; the rest ≥ 3; fresh ≥ 3 |

## Verdict lines for pre-gate row 19 (`docs/review/r3d-qa/readability.md`)

```
verdict verb <right>/8
verdict spot <right>/8
verdict crowded_yes <yes answers>/8
verdict prefer_3d <3D chosen>/8
verdict gag <gag id> funny=<n> readable=<n> fresh=<n>
```

One `verdict gag` line per strip, named by the gag's id from the key (the sneeze and dizzy-spin ids carry those words);
medians when several reviewers answered the same packet. A failing test becomes a request: what the reviewer misread,
which frame, which task can fix it.

## Round 2 (2026-10-01, QA round 2): three rebuilt packets, each for a NEW fresh reviewer
These packets were rebuilt from the fix-round-1 tree (5f0092b + r3d-fix-hud2) at the same moments and ticks as round
1, with new seeds and new keys (`keys/r2_<packet>_key.json` in the r3d-qa scratch dir). The reviewers must not have
seen any round-1 packet. Give each one only the packet's `prompt.md` and its images.

| packet | prompt | images |
|---|---|---|
| spot | `docs/review/r3d-qa/packets/set_f/prompt.md` | `set_f/pkt_01.jpg` … `pkt_08.jpg` |
| crowding | `docs/review/r3d-qa/packets/set_g/prompt.md` | `set_g/pkt_01.jpg` … `pkt_08.jpg` |
| gags | `docs/review/r3d-qa/packets/set_h/prompt.md` | `set_h/pkt_01/page_1.jpg` … `pkt_09/page_3.jpg` (9 strips × 3 pages) |

Score with `python3 tools/art3d/review/packets.py score <key> <answers.md>` and record the verdict lines in
`readability.md` (round 2 section). Round 1's verb (set_a, 7/8) and 2D-vs-3D (set_d, 8/8) results stand.
