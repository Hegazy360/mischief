# View review — camera, PiP, FX, Stalls (Stage 1, task `view`)

Every shot comes from `game/view/sandbox/ViewSandbox.tscn`: the full view stack (SimDriver → WorldView +
FxLayer → GagStager → CameraDirector → PipView + ui's PipFrame → AudioDirector → StallsView) running on
`FakeWorld`'s scripted ≈ 47 s Night (hall / parlour / kitchen unlocked, art-house's house art). Characters are
the stand-in puppets (their clips do not exist yet); `rig_*.png` show the rig path with the `_mannequin` rig.
The sandbox steps at a fixed 1/60 s with a virtual juice clock, so frame N of a scenario is reproducible.
PNGs are palette-quantised for git. Regenerate:

```
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn out.png 60 view -- --scenario=<name> [--rig=_mannequin]
# the gag frame sequence (frames must be >= every x count):
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn x.png 100 view -- --scenario=gag_punch --shot-seq=/abs/dir --every=4 --count=24
# perf:
tools/scripts/shot.sh res://view/sandbox/ViewSandbox.tscn perf.png 600 view -- --scenario=pip --perf-log
```
Window 1200×540 = 20:9 phone (logical 2400×1080). Each scenario jumps to its start tick
(`FakeWorld.SCENARIOS`) and is shot 60 frames later.

## Scenarios
| File | What it shows | What to judge |
|---|---|---|
| `walk.png` | Hush tiptoes to a tapped spot: gold tap ripple + path dots; Bellows (parlour, one room over) in the 448×252 PiP | the tap reads at a glance; the PiP (ui's PipFrame) top-right |
| `bubble.png` | Camera peek on Bellows: thought bubble (tea icon, red 10 px countdown ring), awareness glyph + ear pips at its left | icon 88 px readable; ring starts ≥ 4 s before he leaves |
| `stare_off.png` | He walks into the kitchen, specs off: the short stare strip on the floor ahead of him; Hush hidden behind the pantry curtain (peeking eyes) | strip visible but quiet; no PiP (he is on screen) |
| `stare_on.png` | Specs on (Livid, red tint): long strip with chevrons toward frozen Hush; the "?" meter filling (yellow ring) over his head, bubble lifted above it | "?" readable; strip reaches Hush; PiP still up for its 2 s hide delay after he walked on screen |
| `squeak_rings.png` | A floor squeak: yellow noise ring around Hush (shock face), ear pip + "+2" bit beside his bubble | ring radius = hearing radius; the bit is small, not a pun |
| `entry_warning.png` | "He's coming" at an open doorway: his shadow + amber chevrons marching in, the Stalls' "BEHIND YOU!" balloon, her run ring | readable ≥ 1.5 s ahead; chevrons point from his side |
| `gag_punch.png` | ACHOO-RIA! (T3, link 1) 20 frames after the accent: punched in to 1.4, caption on its burst plate riding him, sneeze drops, Stalls heads up | pun at 88 px on screen; the close-up keeps the lit room (no locked-room half frame) |
| `captions.png` | The chain's end: the POODLE! combo pun, COMBO! +4 and MELTDOWN! +8 stamps stacked beside it (the MELTDOWN! pun waits until POODLE! has been read) | puns never overlap; stamps beside, not on his face |
| `pip.png` | Hush rigging the pickle jar while he checks the hall mirror two rooms away: rigging keeps the PiP on | PiP follows him at 0.75 zoom; the glyph chip in its corner |
| `pip_escalate.png` | TIME'S UP (link 2) fires off screen while Hush is busy: the 704×396 Gag-Cam PiP carries the payoff, pun and particles; the main camera does not cut away | escalated size; the pun is clamped inside the PiP, not the main view |
| `spotted.png` | On Guard: the red "!" (120 px on a pink burst) over his head, the strip at full length | the "!" reads instantly; PiP hidden (he's on screen) |
| `near_miss.png` | He turns a beat too late: NEAR MISS! +2 stamp; frozen Hush | stamp placement |
| `busted_cam.png` | The catch: Busted Cam replay of the 45 frames before / 15 after the "!" with red vignette, comic frame, slanted split between them, SPOTTED! stamp, blinking REPLAY chip, dotted sight line, the Stalls' "Awww…" | the split falls between the two; sight line eye → Hush |
| `stalls_t4.png` | IN A PICKLE (T3, link 3) accent: punch-in 1.6 (link ≥ 3), the 24 Stalls heads risen for the laugh | the heads frame the bottom without hiding the gag |
| `overview.png` | Overview (zoom 0.5 of base): both floors, the flies, apron footlights, the proscenium; hints and bubble at constant screen size | whole slice readable; badges still tappable-sized |
| `peek.png` | A peek flown to Bellows (Hush off screen), holding before the return | the peek frames him with his bubble |

## Frame sequence — the punch-in
`gag_punch_contact.jpg` (24 frames, every 4th, labels = frames after the scenario start) and `gag_punch.gif`
(the same frames at real speed). ACHOO-RIA!: the approach frames him from frame 4 (the view-time approach);
the accent lands at frame 40 (tick 772): 5-frame hit-stop, and the punch-in runs in REAL time through it (frames
44–56), the caption stamps 1.6 → 1.0, drops burst; HOLD ≈ 72 frames on him while the caption rides him; his face
settles at frame 92 and the camera eases out after the reaction ends (tick 830, just past the last frame).

## Rig path
`rig_stare_on.png`, `rig_gag_punch.png`: the same scenarios with `--rig=_mannequin` — both characters drawn by
RigPlayer with the stand-in rig and clips, driven through ClipMap (walk stride from speed, reaction clip on the
sim's frame, Bellows' temper tint tier, freeze pose). Real Hush / Bellows clips do not exist yet, so the default
run (and `--rig` alone) uses the puppets; a rig with no idle clip falls back to the puppet instead of drawing
nothing.

## Overview sheet
`scenarios_sheet.jpg`: all 16 scenario shots on one page.

## Perf (sandbox, `--scenario=pip --perf-log`, 600 frames, xvfb + llvmpipe software GL)
```
[perf] 570 frames: draw calls avg 93.1 p95 114 max 121 | objects max 419 | process ms avg 59.09 p95 102.20 | particles max 52
```
Draw calls p95 114 ≤ 150 (main view + PiP SubViewport + Stalls in one call + FX). "process ms" includes
`RenderingServer.sync()` under software GL on a shared 4-core container: the static art-house preview scene
measures 34 ms avg the same way with 49 draw calls; the view's own scripts cost ≈ 0.9 ms/frame headless
(driver 0.32, WorldView 0.38, stager + audio 0.05, camera 0.05, FX 0.05, PiP + Stalls + HUD 0.07).
Pools: `Performance.OBJECT_COUNT` is flat (±2) when the same 720 frames of the timeline are replayed
(`test_fx_pools.gd`).
