# art-hush review — Hush (+ Pip), Clarence, Old Figgis, the Stalls

Everything here is generated from parameters by `tools/art/hush/` and rendered either by our Python FK
compositor (`preview.py`, rsvg-convert) or by the game's own `RigPlayer` (`engine_*.png`, via
`tools/scripts/anim_sheet.sh`). Regenerate with:

```
python3 tools/art/hush/build.py      # SVGs + rig/poses/faces/stalls JSON
python3 tools/art/hush/validate.py   # SVG rules + schema + parity (exit 1 on error)
python3 tools/art/hush/preview.py --out <dir>
```

| File | What it shows | What to judge |
|---|---|---|
| `cast.png` | **The Gate 0 cast sheet**: a 1200 × 540 phone screen (20:9, zoom 1.0 at 0.5 px/px). Hush at rest, snickering and frozen as the hat stand; Bellows (art-bellows' rig); Pip; Clarence; the Figgis chip at HUD size; the Stalls along the bottom band. Everyone is to scale. | Does she read as a warm, cheeky mime next to him at real phone size? |
| `warmth.png` | The GDD §9.2 warmth check: 50 px solid silhouettes and colour thumbnails of 6 poses, plus 96 px face crops of neutral, snicker, shock, grin, sad and busted. | Does she look like a smiling person rather than a clown? |
| `rest.png` | Hush and Pip rest pose (1.2×), then every texture with pivots (red +) and sockets (green ○): body parts, the **8 gloves × 2 hands**, flat/tiptoe feet, Clarence's 4 states, the hidden look, the TOMATO overlay. | Are the gloves distinct and expressive? Are the pivots sensible? |
| `poses.png` / `poses_phone.png` | All **59 poses** (52 required + 7 extras), each with its tags, the silhouette note and a solid **50 px silhouette**. | Do the freezes and takes read as jokes in silhouette? |
| `faces.png` | The head at ~2× for all **23 face presets** (13 required + 10 extras). | Is each emotion instantly readable? |
| `pip.png` | Hush vs Pip on 14 poses, using the same rig, poses, pivots and sockets. | Could the Pip fallback ship unchanged? |
| `figgis.png` | Old Figgis presets `f_rest, f_psst, f_point, f_shh, f_proud` at 2× and at the real 128 px chip size. | Does the tiny head with huge ears peering over his specs read at 128 px? |
| `stalls.png` | The 24 heads in rest (alpha 0.6), laugh, lean and point (BEHIND YOU!) frames, a mixed T4 strip, and the 4-frame tumble. | Does it read as a crowd seen from behind, and is the laugh visible? |
| `engine_poses_phone.png` | The same 59 poses drawn by the game's `RigPlayer` (rig agent's `sheet.gd`): **errors 0**, identical to the Python preview. | Proof that the data works in-engine. |
| `engine_rig.png`, `engine_figgis_rig.png` | `RigDef` view of both rigs: 26 parts incl. 7 face slots, 4 limbs, 340 px; Figgis 11 parts, 128 px. | Proof that every texture loads. |

## Self-assessment against the warmth rule (GDD §9.2)
- **Pupils:** 14.3–14.6 px on screen (≥ 14). Eye whites 24.4 / 26.1 px (≥ 24). Every eye has a glint.
- **Blush:** always-on rosy cheeks `#FF9AA2`, plus a stronger blush overlay for laugh and proud.
- **Smile:** the default mouth is a small **red** smile with a dimple. Lips are never black.
- **Paint:** thin eye paint (a fine liner flick) and a small navy teardrop. There is no clown nose, no white-out mouth and no fixed grin.
- **Hair:** a soft plum-black bob with a fringe under a slouched cherry beret. At 50 px the beret and bob, the lanky legs and the huge gloves are her signature.
- **96 px crops:** neutral, snicker, shock, grin, sad and busted all read as a person first, a mime second. I judge the rule **met**.
- **Weakest reads:** the `shh` mouth is small at 96 px (it relies on the shush glove). `h_freeze_2` (teapot) is the least instant of the statues because its elbow "handle" sits behind her back.
- **Gesture rule:** gloves work in front of the face (x > 62 px), below the chin, or behind the head, never across the eyes. When a raised near arm must pass the face it goes *behind* the head (a z override).

## Scale note
Hush is authored 1/0.87 large and drawn at scale 0.87. Outlines are authored at 6/0.87 so they land on
exactly **6 px / 3.5 px**. Measured height is **344 px** from the beret stalk to the sole ink (Pip 350 with the pompom),
and head plus beret is about 149 px. Clarence and Figgis are drawn at 1×.
