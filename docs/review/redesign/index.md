# Redesign review: the 3D pivot (spec `docs/REDESIGN_3D.md`)

Every image here is 1200 × 540 (a 20:9 phone held sideways) unless noted, and was looked at at that size.
The mocks are a **greybox blockout** of the spec rendered by Godot 4.7.2 with the Compatibility renderer (the
renderer the phone build uses): toy stand-ins made of primitives for Hush and Bellows, a greybox Night-1 set, the
spec's camera, lighting, outlines and HUD. They check layout, scale and hierarchy — **not the final art style**
(the three style look-devs do that).

## The current build (what the owner played)

| File | What it shows | What to judge |
|---|---|---|
| `audit_current_n01.png` (1200 × 870) | The Gate-0 build's Night 1 HUD over the real house, with 9 numbered callouts and a legend | The spec's audit (§1): what makes the UI and the house crowded |
| `before_after_n01.png` (1200 × 1176) | The same moment: the Gate-0 build on top, the 3D blockout below | Is the bottom one calmer, and do the characters read better? |

## The spec's layouts and numbers

| File | What it shows | What to judge |
|---|---|---|
| `hud_layout.png` (1200 × 1184) | The HUD rects at 20:9 (2400 × 1080 logical) and 16:9 (1920 × 1080): gold = the 4 always-on pieces, dashed = contextual, grey = never a target | ≤ 4 always-on pieces; the middle band y 250–880 is world only |
| `camera_section.png` (1200 × 700) | A side section of the set with the camera (FOV 30°, 7.5 m, y 1.9 m, pitch −4.2°), px per metre at the lane and the back wall, and the plan with the visible width at 20:9 / 16:9 | The framing numbers of §5.2 |

## The blockout mocks (Night 1 kitchen, Night 2 hall)

| File | Scene | What to judge |
|---|---|---|
| `mock_n1_kitchen_plan.png` | Night 1, calm: Hush at the kettle carrying the squeaker; Bellows walking in from the parlour with his bubble (next: tea, 62 % ring) and specs glyph; his stare strip on the floor; Hush's thought (the kettle joke); faded previews on the honey, pickle jar and tap; the LIVE action button (squeaker → kettle); the carried-item chip | One loud call to action (V1); characters 40–44 % tall; live props saturated and outlined, dressing flat |
| `mock_n1_kitchen_plan_16x9.png` (960 × 540) | The same at 16:9 | Hush's thought flips to avoid Bellows' bubble (§2.5 priority rule) |
| `mock_n1_kitchen_rigging.png` | Hush rigging ACHOO-RIA! (reach-high, pepper over the jar): the rig ring at the jar, 60 % on the button too; every other preview hidden | You can watch the progress where she works |
| `mock_n1_kitchen_armed_entry.png` | Three pranks armed (red beret tags on the kettle, honey jar and tap), Bellows entering: "BEHIND YOU!", the safety-net hiding marker on the pantry, previews hidden (V2), FREEZE quiet (he can't see her yet) | Armed state readable at a glance; danger speaks alone |
| `mock_n1_kitchen_payoff.png` | The ACHOO-RIA! punch-in (dolly to 1.4×, 5° yaw): caption, transient Applause meter "+35", the Stalls risen, Hush's eyes in the pantry gap | The payoff owns the screen; the HUD stays out of the way |
| `mock_n2_hall_plan.png` | Night 2 hall with its 5 live props (phone, mirror, clock, CONFISCATED box with the magnifier bubble, coat cupboard), the front door and the roped stairs; Bellows next door in the 400 × 225 Bellows window with his next-activity chip | The densest slice room still reads; the window replaces the old PiP only while he is off-screen |
| `mock_n2_hall_freeze.png` | FREEZE: Hush turned to marble on a pop-up plinth (eyes, beret and braces stay in colour), Bellows passing with specs off, his stare strip's darker frozen-range segment stopping short of her; FREEZE LIVE (stone face, amber rim) | Is it obvious she is a statue and that she is safe? |

Measured on the blockout (1080-tall logical frame): Hush's head top y 469 → feet 903 (434 px, 40 %), Bellows 425 →
896 (471 px, 44 %); visible width at the lane 8.93 m (20:9), 7.15 m (16:9). Colour samples (CIELAB): kitchen wall
L* 73 C* 26, dimmed parlour wall L* 50 C* 9, floor L* 44, honey jar C* 72, Hush's face L* 96 vs costume L* 22,
Bellows' bouffant L* 91 vs jacket L* 35.

## Reproducing the mocks

`blockout_src/` holds the whole blockout: `project.godot`, `main.tscn`, `main.gd` (set, cast, camera, HUD overlay),
`toon.gdshader` (fake-light two-band toon + rim + room dimmer), `outline.gdshader` (screen-constant inverted hull),
`halo.gdshader` (the verb halo shell), `render.sh` and `compose.py` (the boards). Copy the folder to a scratch
directory, put `LilitaOne-Regular.ttf` and `Nunito-Black.ttf` from `game/ui/theme/fonts/` in a `fonts/` folder next to
`project.godot`, run `godot --headless --path . --import` once, then
`render.sh <plan|rig|armed|trigger|hall2|hall2c> [1200x540|960x540] [name]` (it expects the project in a `blockout/`
folder beside it and writes `out/<name>.png`). No third-party assets are used besides those OFL fonts.
