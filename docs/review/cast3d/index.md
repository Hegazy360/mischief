# The cast in 3D — first playable runtime (REDESIGN_3D §5.6/§5.7, stage R2)

You said the characters and their movement felt too basic, and asked whether the fix is new
technology, better assets, or more animation. **It is the last two, on the engine we already have.**
This folder is the evidence for that answer and the first build of the system behind it.

## The short version

| Question | Answer | Why |
|---|---|---|
| Change engine (Unity / Unreal)? | **No** | The complaint is not something Godot cannot do — the look-dev renders you already saw were Godot's Compatibility renderer. Moving engines would throw away ~25k lines of *tested* sim, solver, content, audio and UI (1,114 green tests) and buy nothing against the actual problem. |
| So what was wrong? | **The character pipeline, and missing animation layers** | The 2D cast are flat cutouts with no volume, and every part only moves when an animator keys it. See "What was actually broken". |
| What changed | A self-contained 3D cast rig, both characters rebuilt as skinned 3D, and four procedural animation layers a 2D cutout rig could not have | `game/view/char3d/**`, `tools/art3d/cast/**` |
| What it cost in re-authoring | **Nothing** | All 236 authored poses and 34 lint-checked clips replay on the 3D skeleton unchanged (see "The retarget"). |

## What was actually broken

**The movement.** Open `docs/review/s2-anim-hush/` or re-render `hush/loco_walk`: it is 80 frames in
which the legs scissor and almost nothing else happens. The data does carry a root bob and torso and
head angles, but at 1–2° of travel, and the arms are locked in a clasped "paws" pose for the whole
cycle. Nothing lags, nothing overshoots, nothing settles, and no part moves unless a key moves it.
That is the definition of stiff, and it is a property of the *rig*, not of the animator: a flat
cutout rig has no secondary motion, no IK and no volume to squash.

**The characters.** Flat vector cutouts at ~31–35 % of screen height, drawn with the same ink weight
and saturation as the furniture (REDESIGN_3D §1.2), so they never separate from the set.

## What to look at

| File | What it shows |
|---|---|
| `cast_idle.png` | Hush and Bellows standing, at the review framing (1200×540 = a phone held sideways). Faces, beret, bouffant, outline, toon banding. |
| `hush_walk.png` | The 3D tiptoe walk — the same `hush/loco_walk` clip you already own, retargeted. |
| `bellows_strut.png` | Bellows walking, with the belly, jowls, bouffant and coat tails swinging. |
| `jiggle_ab.png` | **The clearest single piece of evidence.** Four frames of the same strut, jiggle on (top) and off (bottom). Off, the bouffant and belly are welded to the body — that is how all 2D motion looks today. On, they lag the turn and settle after it. Nothing was keyed to get that. |
| `face_hush_preview.png`, `face_bellows_preview.png` | The expression atlases: the full 2D face vocabulary (brows, eyes, mouth, extra), carried over as 2D cards on 3D heads per §5.6. |

Render any of them yourself:

```bash
tools/scripts/shot.sh res://scenes/dev/CastWorkbench.tscn out.png 90 cast -- \
  --who=hush --clip=loco_walk --speed=400 --yaw=-55 --outline=7
```

`--no-jiggle`, `--no-ground`, `--fk=x|y|z`, `--temper=0.8`, `--mode=pose` switch individual layers
off for an A/B. Outline widths are quoted at a 1080-tall viewport, so pass `--outline=7` to judge
3.5 px at the 540-tall review size.

## The retarget — why no animation was re-authored

`game/data/rigs/**` holds 236 authored poses and `game/data/anim/**` 34 clips whose beats and
timings are already lint-checked against `reactions.json`. All of it is plain humanoid FK: one
clockwise screen-space rotation per joint. So the whole 2D pipeline upstream of the draw — `ClipLib`,
`RigSampler`, `ClipEvents`, `PlayPlan` — is kept, and only the last step is replaced:
`RigSampler.solve()` produced one `Transform2D` per cutout; `PoseRetarget3D` produces bone rotations
instead. A 2D "torso" hinge is spread over spine + chest (and "head" over neck + head) so the pose
keeps its authored silhouette while bending like a spine rather than a hinge.

That is the whole reason this build uses its own skeleton instead of the CC0 Quaternius one the
look-devs used. Quaternius is the UE5 mannequin — 65 bones, **40 of them finger joints**, on a cast
whose hands are mitten gloves — which is over the §5.6 budget of ≤ 50 deform bones before a single
useful bone, does not line up with the 2D channel names, and has to be re-downloaded on every
rebuild because the packs are deliberately not committed.

## The four layers that fix "basic"

1. **Jiggle** (`jiggle3d.gd`) — beret, hair, braces, bouffant ×3, jowls, nose, cravat, belly, coat
   tails on spring-damped bones in world space, so they react to the body *translating* as well as
   turning. 5 bones on Hush, 10 on Bellows.
2. **Foot grounding** (`ik3d.gd`) — two steps: move the body so the lowest *sole* meets the floor,
   then IK only the residual. The 2D rig could only match one authored `stride_px`, so any other
   walk speed skated; now nothing slides at any speed.
3. **Squash & stretch** — the authored root `sx`/`sy` become a volume-preserving 3D squash (depth
   follows width), so an accent reads as weight instead of a flat scale pop.
4. **Moving holds** — breathing and a sub-degree sway, so a held pose is never dead-still.

## Budgets (checked by `tests/view/test_char3d.gd`, not assumed)

| | Hush | Bellows | §5.6 budget |
|---|---|---|---|
| Triangles | 9,999 | 10,000 | ≤ 10,000 |
| Bones (incl. jiggle) | 27 | 32 | ≤ 50 |
| Materials / draw calls | 1 / 2 (body + outline pass) | same | ≤ 4 |

## Honest state — what is NOT done

- **Not wired into a Night yet.** This is the cast runtime and the workbench. `NightScene` still
  renders the 2D view; R1 (`House3D`, `CameraDirector3D`, the decluttered HUD) comes before the 3D
  cast reaches gameplay.
- **Modelling is a first pass.** Bellows' belly still reads as a separate egg and his arms merge
  into the torso; Hush's legs are thin. These are surface fixes on a rig that is now correct.
- **No device perf numbers.** Budgets are met on paper and in the editor; the §6.5 X1 risk needs a
  real Android run.
- **Seated clips need grounding switched off** (`ground_weight = 0`) — `bellows/act_tea` is authored
  sitting on a stool, so with grounding on it correctly refuses to stretch his legs to the floor.
  Wiring that to a per-clip flag is R2 work.
- **The style question is still open.** This build takes the look-dev board's own recommendation
  (A: Toy Box) as the default. If you prefer B or C, the runtime, the retarget and the budgets are
  unchanged — only `tools/art3d/cast/build_cast.py` is restyled.
