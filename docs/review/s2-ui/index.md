# s2-ui review: the HUD and panels at final polish, and the Stage-2 hooks

Every image is a real capture:
- **UiDemo:** `res://ui/demo/UiDemo.tscn -- --state=<state>`. It shows a fake HudModel over the parlour art.
- **NightScene:** `res://scenes/night/NightScene.tscn -- --episode=… --no-curtain`. It shows the real scene with the real HUD.

Phone scale is 1200 × 540 (20:9). The variants are:
- `16x9` = 960 × 540
- `4x3` = 1080 × 810 (a tablet, HUD at ×0.8)
- `notch` = `--safe-area=162,0,162,58`
- `lh` = `--left-handed`
- `notch_lh` = notch and left-handed together
- `text_big` = `--text-big` (Settings "Text +20 %")

I looked at every image listed here at phone scale.

## Stage-2 widgets and states (20:9)

| What | Shot | What to judge |
|---|---|---|
| Edge-bubble emotes (D1) | `emotes_phone_scale.png` (all 8, cropped at 1:1), `20x9/emote_<sing,hum,smug,laugh,tut,sniff,yum,yawn>.png` | Bellows' 112 px face swaps to the emote face with a pop. A cream thought-cloud floats toward the screen centre holding a pictogram, so you can tell which one it is in half a second: notes = sing, squiggle + note = hum, sparkles = smug, rays = laugh, wagging finger = tut, scent lines = sniff, steaming cup = yum, zZ = yawn. The label stays under the face. |
| Ghost finger on the world | `20x9/ghost_world.png` (TAP), `20x9/ghost_world_hold.png` (HOLD 0.8 s ring, yellow → green) | The glove sits on the demo "hotspot" (the mantel candles). It never leaves the safe area: see the clamp tests. |
| Figgis cue card + arrow | `20x9/figgis_card.png`, `20x9/figgis_arrow.png` (target off screen right: a gold edge arrow with the target's icon at its tail), `20x9/figgis_arrow_on.png` (target on screen: the arrow bobs above it) | Figgis holds up his card prop with the cue icons drawn inside `props.card.icon_rect`. The readable card sits under the chip. The spelled-out "arrow" keys from barks.json are separators, so the card never shows an arrow twice. |
| Figgis moods | `20x9/figgis_proud.png` | Proud: the card is held high. The card prop shows only while he points (point) or beams (proud). |
| "Show me" dim | `20x9/dim.png` | The house lights go down. A soft spotlight stays on the ghost's patch and the HUD widgets fade. |
| Script flash at curtain up | `20x9/script_flash.png` | Full size (44 px rows) with lines only. It sits under the meter, clear of every target. It is non-pausing and touches outside the card pass through. |
| "Where does this go?" | `20x9/tray_arrows.png` (kipper → two off-screen rig points), `20x9/rig_dim_arrow.png` (RIG_DIM → the container upstairs) | Chunky gold arrows with the item disc at the tail. They sit in the band below the overview row and above the thumb clusters and never touch a button (polygon test). |
| Gag-Cam window | `20x9/pip_escalated.png` | 704 × 396 in the top-right corner. The overview button drops under it and it never covers the action column. |
| Curtain call | `20x9/results.png` (★★, why line, 2 "+NEW!"), `20x9/results_reel.png` (★★★ + a live reel texture), `20x9/results_why_long.png` (a wrapped why line), `20x9/results_prologue.png` (no stamps, "Night 1 ▶"), `20x9/results_gate0.png` ("Again ▶" + Stage door) | Next ▶ is 240 px tall and glowing under the right thumb, and it is live from the first frame. The lower stage band between the corner buttons stays empty for Bellows' slow burn. |
| Loading card | `20x9/loading_n01.png` (a key icon, 160 px), `20x9/loading_vignette.png` (a live Texture2D framed 240 px tall) | A rule of ≤ 25 words at 44 px. "tap to start" appears after 1 s. |
| Settings | `20x9/settings.png`, `20x9/settings_debug.png` | Four tabs + Done, 24 px apart. The debug-only tab holds the three Gate-0 keys (Baritone/Tuba, Voices/Kazoo, Mime/Pip). |
| Pause | `20x9/pause_nobow.png` | There is no Take a Bow before ★. |
| Stage-1 states re-checked | `20x9/rig_50.png`, `20x9/edge_bubble.png` | Real item and activity icons everywhere; no "?" boxes left. |

## Sizes, insets, handedness, text +20 %

- `16x9/`, `4x3/`, `notch/`, `lh/`: rig_50, emote_sing, tray_arrows, figgis_arrow, script_flash, results_reel, settings_debug and pip_escalated. `16x9/` and `notch/` also have ghost_world_hold.
  - The whole layout mirrors or insets correctly.
  - Arrows stay in their band.
  - The escalated PiP keeps its corner.
  - At 4:3 (HUD ×0.8) nothing crowds.
- `notch_lh/`: rig_50, emote_sing, tray_arrows, figgis_arrow.
- `text_big/`: script, script_flash, results_why_long, loading_n01, settings, settings_debug.
  - Nothing clips.
  - Button labels shrink to fit their face ("Comfort" in a 4-tab header).
  - Rule and why lines wrap.

## The real NightScene (`night/`)

- `n01_20x9.png`, `n02_20x9.png`, `n01_16x9.png`, `n01_4x3.png`, `n01_notch.png`, `n01_lh.png`, `n01_notch_lh.png`: the play HUD over the real house with the real Hush and Bellows.
  - The top row and the thumb clusters sit per GDD §3.8.
  - The Stalls band is untouched.
  - The bottom centre holds no target.
- `p00_t420.png`: the Prologue's ghost finger on Clarence (s2-night's no-FTUE cue fallback calling `Hud.ghost_finger`).
- `n02_20x9.png`: a ghost HOLD on the action button (card_freeze).
- Observation for s2-view: in `n01_notch.png` and `n01_lh.png` the PiP shows Bellows while he is also on screen in the parlour. `n01_20x9.png` has no PiP. This may be the PipView visibility rule under a moved camera; it is not a HUD issue.

## Verdict

At arm's length on a 20:9 phone:
- Every new element reads in half a second.
- Every target is ≥ 144 px, with 24 px dead space between targets.
- No teaching element covers the thing it teaches.

The weakest reads are the emote faces themselves (112 px is small), so the pictogram cloud carries the emote.
