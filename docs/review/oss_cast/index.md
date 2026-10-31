# Off-the-shelf cast: evaluation and recommendation (replaces the custom character pipeline)

You asked two things: make the review process precise enough to actually catch bad motion, and
check whether a finished open-source character set could replace our hand-built one so the effort
goes into gameplay. Both are answered here with measurements, not impressions.

## 1. The process fix: every capture now gets a stability score

Single frames and 6-frame strips cannot show a one-frame pop or a two-frame oscillation — which is
exactly what "instability" is. `tools/anim/stability.py` now runs inside `capture.sh` on **every
frame** of a Movie Maker capture and writes `<name>_stability.png/json`:

| Metric | Meaning |
|---|---|
| `jitter` | how much the frame-to-frame change oscillates (0.1–0.25 = clean clip; 0.4+ = visible vibration) |
| `pops` | frames that move > 3× the median (snaps, teleports, IK flips) |
| `frozen` | runs of ≥ 6 dead frames in a clip that should be moving |
| `smooth` | 0–100 roll-up |

Measured with it (same camera, same outline, 60 fps):

| Capture | Source | tris | bones | jitter | smooth |
|---|---|---|---|---|---|
| `ours_hush_walk` | our custom rig + 2D retarget + jiggle + IK | 9,999 | 27 | **0.42** | 79 |
| `ours_bellows_strut` | same pipeline | 10,000 | 32 | 0.15 | 92 |
| `knight_sneaking` | KayKit Adventurers + Character Animations | 5,800 | 23 | 0.19 | 91 |
| `rogue_walking` | KayKit | 7,562 | 23 | 0.23 | 88 |
| `large_walking` | KayKit Rig_Large mannequin | 9,148 | 23 | **0.14** | 93 |

`ours_hush_walk_stability.png` is a 2–3-frame sawtooth: the jiggle springs and the foot-grounding
IK correcting each other every frame. That is the instability you saw, it is in **our runtime**, and
it is not present in any of the library clips. Open the `*.gif` files to see it; the `*_strip.png`
files are the numbered frames.

## 2. Open-source candidates, tested in our renderer

| Pack | Licence | What you get | Verdict |
|---|---|---|---|
| **KayKit Character Pack: Adventurers 2.0** + **KayKit Character Animations 1.1** | CC0 (no attribution required) | 6 chunky stylised humanoids, 23-bone rig, **161 clips** across a medium and a large rig, glTF, Godot-ready | **Adopt.** Reads at phone size, the clip list fits a stealth-prank game (`Sneaking`, `Crouching`, `Crawling`, `Lockpicking`, `Interact`, `PickUp`, `Throw`, `Use_Item`, `Sit_Chair_*`, `Lie_*`, `Hit_A/B`, `Cheering`, `Waving`, `Work_*`), both rigs are inside our §5.6 budgets. |
| Quaternius Universal Base Characters + Universal Animation Library | CC0 | semi-realistic bodies, 65-bone UE5 rig, 43 free clips (120+ paid) | No. Free tier ships only Superhero bodies in Godot format; the rig is 40 finger bones over budget; the look is generic (the look-dev board scored it lowest). |
| Kenney Animated Characters / Mini Characters | CC0 | blocky 7-bone figures | No. Too simple to carry faces and reactions. |
| Blender Studio rigs (Rain, Snow, Storm) | CC-BY | film-quality cartoon rigs | No. Hundreds of control bones, bendy bones, Python rig UI: not game-ready, and needs a full bake-down. |
| Mixamo (Adobe) | free, proprietary: use in games allowed, no redistribution of raw files | 2,000+ clips, auto-rigging for any humanoid | **Keep as a clip fallback**, not a base. Not open source, and the "technology preview" licence can change. Use it to fill a gag the KayKit library lacks, bake into the project, never ship loose files. |

Sources: [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) ·
[KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) ·
[KayKit GitHub (CC0)](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) ·
[Quaternius UAL](https://quaternius.itch.io/universal-animation-library) ·
[Quaternius UBC](https://quaternius.itch.io/universal-base-characters) ·
[Mixamo licence FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) ·
[Blender Studio Rain](https://studio.blender.org/characters/rain/v3/)

## 3. Why KayKit fits this project specifically

- **Same hierarchy as our 2D rig.** `hips/spine/chest/head, upperarm/lowerarm/hand, upperleg/
  lowerleg/foot/toes` ×2 — the retarget in `game/view/char3d/pose_retarget3d.gd` drives it with a
  bone-name map, so the 236 authored comedy poses are still usable for the gag beats the library
  does not have (the sneeze build, the freeze poses, the tinker).
- **Same material scheme as our shader.** Each character is one gradient atlas (a 1024² palette,
  downsampleable to 128²) sampled by UV — identical to `cast_toon.gdshader`'s palette path. Recolouring
  the Rogue into Hush's Breton stripes and the Large mannequin into Bellows' plum coat is a texture
  edit, not a remodel.
- **Faces are small separate meshes**, so expression swaps are mesh/decal swaps on the head bone —
  the face-card approach from REDESIGN_3D §5.6 still applies.
- **Prop sockets exist** (`handslot.l/r`) — the pepper, honey and squeaker attach without IK.
- **A large rig exists** for Bellows, with its own 90+ clips (`Rig_Large_*`).
- **Original IP is preserved.** We ship recoloured, re-dressed mannequins with our own faces,
  beret, bouffant and accessories — never the Knight or the Mage as shipped. CC0 permits that.

## 4. What we keep from the custom work, and what we drop

| Keep | Drop |
|---|---|
| `Character3D` as the player, but driving an `AnimationPlayer` of library clips as the **base layer** | `tools/art3d/cast/**` procedural modelling (the Blender builders) |
| `PoseRetarget3D` as an **overlay** layer for the authored gag poses | our custom skeleton `.glb`s |
| `Ik3D` for hand-to-prop reach and ground contact — **with the springs decoupled** (see §5) | — |
| `Jiggle3D` for beret / bouffant only, **off during grounded idles until the oscillation is fixed** | — |
| toon + outline shaders, face atlas | — |
| `tools/anim/stability.py`, `OssCastEval.tscn`, `capture.sh` as the review loop | single-frame `shot.sh` judgments of motion |

## 5. The instability, diagnosed

Each frame `Character3D._apply_pose` runs: FK → jiggle (reads the pose, writes bone rotations) →
`ground_offset` (moves the node) → `plant_feet` (IK writes leg rotations). Jiggle's world-space
springs then see the node move next frame and react; grounding sees the jiggled pose and
re-corrects. Two feedback loops on the same skeleton with no ordering guarantee is a textbook
2-frame oscillator. The fix is structural and short: compute grounding from the **FK-only** pose
before jiggle runs, and give the springs the node's post-grounding transform as their input. It is
a prerequisite for any character, library or custom, so it stays on the list.

## 6. Adoption plan (R2, revised)

1. **Base**: `Mannequin_Medium` → Hush, `Mannequin_Large` → Bellows. Recolour atlases; model the
   beret, bouffant, specs and belly as accessories on the head/spine bones (KayKit ships hats and
   capes as exactly this kind of attachment — `Assets/gltf/`). ~1 day each.
2. **Clips**: map the sim's states to library clips (`Sneaking` for tiptoe, `Walking_A/B`, `Idle_A/B`,
   `Interact`/`Use_Item` for rigging, `Sit_Chair_*` for the tea, `Hit_A/B` for takes, `Lie_*` for
   the dazed state). Keep the authored 2D clips as overlays where the library has no equivalent
   (sneeze build, freezes, snicker). Every mapping goes through `capture.sh` and must score
   `smooth ≥ 85`, `pops = 0`.
3. **Fix the oscillator** (§5), re-measure Hush: target `jitter ≤ 0.25`.
4. **Faces**: port the face atlas to a decal quad on the head bone; blink + look-at as today.
5. Then the environment and rules work (R1), where the time actually goes.

## Files

`knight_sneaking.gif`, `rogue_walking.gif`, `large_walking.gif`, `mage_interact.gif`,
`ours_hush_walk.gif`, `ours_bellows_strut.gif` — each with `_mute.gif`, `_strip.png`,
`_stability.png/json`. Evaluation assets (CC0, with licence files) are under
`game/art3d/eval/` and excluded from exports.
