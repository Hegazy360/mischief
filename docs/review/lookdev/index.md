# Look-dev board: choose the 3D look (REDESIGN_3D §6.4, stage R0)

You said the characters didn't look good and that 3D would be more appealing. Three look-devs answer that. Each one
built Hush and Horace Bellows in a different 3D style and rendered them in Godot on the phone renderer (Compatibility),
in the same test kitchen and under the game camera: 1200 × 540, a phone held sideways. **Open `board.png` first.** It
puts the three looks side by side, each with four rows:

1. the kitchen as the game shows it;
2. the turnaround;
3. six faces per character;
4. three beats of the ACHOO-RIA! sneeze gag at game scale.

The folders `look-toy/`, `look-cartoon/` and `look-puppet/` hold each style's full images and a GIF of the sneeze.

## What to judge

- **Would you want to play with these two?** Hush should read as warm and cheeky, never creepy. Bellows should read
  as pompous, not scary.
- **Can you tell what each one is doing at game size?** Try it without the captions. Look at row 1 of the board, or
  open `*/ingame_kitchen.png` on your phone. This was your "actions are not very obvious" complaint.
- **Do the faces carry the joke?** Check shock, furious (Bellows turns beetroot) and dazed.
- **How does it move?** Open the three `sneeze.gif`. C moves in stop-motion steps (12 poses a second) on purpose.
  Does that feel charming or choppy?
- **Don't judge the room.** All three stand in the same *test* kitchen, and it still has too much in it (plates,
  portrait, gramophone and so on). The real house follows REDESIGN_3D §3 whichever look wins: plain walls, at most
  5 live props per room, and only what tonight uses. The one exception is C. It re-dressed the set with wallpaper,
  tiles, a velvet valance and footlights, and that dressing is part of its look.

## A: Toy Box (`look-toy/`)

Chunky vinyl-toy characters with big heads, painted-on faces, soft matte colours and a clean outline.

- **Readability.** It reads best at phone size. Hush's head is about 85 px tall in the 1200 × 540 shot, against
  about 70–75 px in B and C, so her eyes, blush and grin survive at arm's length. The tiptoe, the snicker and the whole
  sneeze read in silhouette: arms up, the CHOO puff, slippers up in the sink.
- **Faces.** They are 2D decal layers on the 3D head (brows, eyes, mouth, extras), drawn from SVG into one atlas per
  character. That is exactly what the spec's "2D face cards on 3D heads" rule asks for, and the same SVG-to-atlas
  route can carry the existing 2D expression vocabulary across.
- **Cost.** It is cheap to run: 1 material, unshaded, and about 4 draws per character.
- **Weaknesses.**
  - The modelling is procedural: Hush's legs are sticks, and the bouffant is a lumpy cloud.
  - Bellows' face is small inside his hair.
  - His teacup is too small to read at game size.
  - The short chibi arms can't reach a real counter, so props and furniture need rescaling.
  - At about 15k triangles per character it is over the 10k budget.

All of these can be fixed with a modeller pass on the same rig.

## B: Saturday Cartoon (`look-cartoon/`)

Stretchy TV-cartoon people in the Scary Teacher / Hello Neighbor family, with real 3D eyeballs, lids and brows, and
painted mouths. It is the most engineered of the three.

- **Budgets.** It is the only look inside the spec's triangle budget (about 10k per character) and matches the spec
  heights exactly.
- **Toolkit.** It has the best animation toolkit: arm IK, automatic foot grounding, and 31 library clips already on
  both characters.
- **Props.** Bellows' cup and saucer read instantly at game size.
- **Weaknesses.**
  - At phone size Hush is a thin dark figure with a face only about 30 px wide.
  - The big 3D eyes on a semi-real head and long neck look a little odd up close.
  - In the sneeze, Bellows tips his face away from the camera, so the build is mostly a purple ball.
  - The look is the most generic of the three.
  - The small painted details (brows) go blocky at close range.

## C: Stop-Motion Puppet (`look-puppet/`)

Handmade felt, knit and clay puppets with bead eyes and swap-in clay mouths. They move in stop-motion steps, and the
house becomes a little theatre set.

- **Appeal.** It is the most distinctive and "premium" look; almost no mobile game looks like this. The close-up faces
  are lovely, and the cotton-wool CHOO and felt stars are great gag props.
- **Weaknesses.**
  - The look works against your "too crowded" note. The fabric grain is too fine to read at phone size, so what sells
    "handmade" in play is the patterned set: wallpaper, tiles, velvet and footlights, the things we are removing.
  - It is the most expensive to run: lit shader with real-time shadows, about 17k triangles and over 90 bones per
    character.
  - The heads are smaller, and Hush is as tall as Bellows.
  - The outline is thin.
  - A player character that moves in 12 fps steps may feel laggy under your thumb. That needs a test on your phone
    before we could commit to it.

## Scores (reviewer's, out of 10)

| Style | Appeal (mobile player) | Reads at phone size | Buildable (about 40 clips per character by agents) | Phone perf | Main reason |
|---|---|---|---|---|---|
| **A: Toy Box** | **8** | **8.5** | 7 | 7.5 | Cutest and clearest. Face decals match the spec and port the 2D faces. Chibi reach and 15k triangles need fixing |
| B: Saturday Cartoon | 6 | 6.5 | **7.5** | **8.5** | In budget, best toolkit and most library clips fit. Small faces at game size; a generic look |
| C: Stop-Motion Puppet | 7.5 | 7 | 6.5 | 5 | Most distinctive. Needs a busy set to sell it, costs the most, and stepped motion is risky on the player |

How the scores were reached:

- **Buildability.** This counts how many of the ~40 clips can come from the CC0 Quaternius library versus custom work.
  All three share that skeleton; each look-dev lists the split in its `NOTES.md`. It also counts how fast agents
  iterate with each toolkit and how faces are authored:
  - A: 2D atlas cells;
  - B: bones plus decals;
  - C: modelled 3D pieces, each new mouth a new mesh.
- **Perf.** This compares each look against the per-character budget in REDESIGN §5.6 (≤ 10k triangles, ≤ 50 deform
  bones, 1 material, ≤ 4 draws) and §5.3 (lighting computed in the shader, no real-time shadows).
- **Frame times.** They were measured on a software renderer, so they are relative only. Device numbers come from
  the pipeline spike.

## Recommendation: A, Toy Box, with the best parts of B and C folded in

A is the look most likely to fix what you felt on the phone. It has the biggest, clearest faces at game size, the
most obvious poses, and the calmest look next to the simplified house, and it already follows the spec's face-card,
lighting and outline rules. Its weaknesses are modelling and budget problems on the same rig, not problems with the
style. For R2, the cast in 3D:

1. **Modeller pass.** Sculpted gloves and shoes, shaped legs, and a styled bouffant with a bigger face inside it:
   about 2–3 days per character. It must end inside the §5.6 budget: ≤ 10k triangles and ≤ 50 deform bones (merge
   the finger joints).
2. **B's animation tools.** Adopt B's arm IK and foot grounding, B's arm-out layer for Bellows' barrel, and B's
   bigger held props. His teacup has to read at game size.
3. **C's ideas, restyled as vinyl.** Adopt C's face-over-body clip layering and C's gag props (the cotton-wool CHOO
   puff and felt dazed-stars).
4. **Chibi reach.** Decide it in R1 before any set is built: props at about 1.5× and furniture at about 0.8×. The
   spec heights stay: Hush 1.60 m, 40 % of the screen.
5. **Keep the cheat-out.** Bodies turn 20–35° toward the audience (§5.1) so the painted faces never go edge-on.

If B or C is your gut pick, both can still work. B has the lowest technical risk. C needs a device test of the
stepped motion and a plan for how it looks handmade on plain walls.

**Please reply with A, B or C.** A combination is fine too, for example "A, but with B's teacup".

## Files

| File | What |
|---|---|
| `board.png` (2400 × 2474) | The comparison board: kitchen, turnaround, faces and sneeze beats for A, B and C, plus the reviewer's scores |
| `*/ingame_kitchen.png`, `*/ingame_wide.png` (1200 × 540) | Game camera: the kitchen, and a wider shot of the parlour and kitchen. Lossless; the key evidence |
| `*/turnaround.jpg` | Front, 3/4, side and back of both characters |
| `*/expressions.jpg` | Six faces each: neutral, sneaky grin / pompous, shock, furious, sneeze build, dazed |
| `*/poses.jpg` | Tiptoe, rigging (pepper into the honey), peeking from the pantry, frozen statue, tea on the stool, the CHOO launch, dazed in the sink |
| `*/sneeze_strip.png` | The sneeze in 8 frames at game framing |
| `*/sneeze.gif` | The whole sneeze take at 600 × 270. Re-encoded to 128 colours to fit this folder; timing unchanged |
| `look-toy/ual_on_chibi.jpg`, `look-puppet/ual_on_puppets.jpg` | Raw CC0 library clips on the rigs: what works without custom animation |
| `*/NOTES.md`, `look-cartoon/CREDITS.md`, `look-cartoon/numbers.txt` | Each look-dev's own notes, copied as written: build, numbers, clip plans, risks and self-rating |
| `board_src/compose_board.py` | The script that composed the board from the look-dev deliverables (Pillow and the game's fonts) |

The copied `NOTES.md` files refer to the look-devs' own working folders (`src/`, `proj/`, `godot/`, `build/`,
`out/`, `work/`), which are not copied here. The large sheets are stored as JPEG, quality 90 with no chroma
subsampling, to keep this folder under 15 MB. The in-game shots and strips are the original PNGs.

## Sources and licences

- **Third-party files:**
  - All three looks use the Quaternius *Universal Animation Library* 1 and 2 [Standard] skeleton and clips,
    **CC0 1.0**: https://quaternius.itch.io/universal-animation-library and
    https://quaternius.itch.io/universal-animation-library-2.
  - B also starts its bodies from the Quaternius *Universal Base Characters* [Standard], **CC0 1.0**:
    https://quaternius.itch.io/universal-base-characters. Its heads, hands, feet and Bellows' torso are replaced.
- **Original work.** Every model, face, texture, custom clip, shader and prop was made for Mischief Next Door in these
  look-devs.
- **The set.** It is the project's own test set (the shared diorama from the pipeline spike). C restyles it with a
  shader.
- **Board labels.** Lilita One and Nunito, the game's own SIL OFL fonts.
