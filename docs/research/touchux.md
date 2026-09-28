# Touch UX + Godot 4.7 implementation — "Mischief Next Door" (landscape, side-view prank/stealth)

Research brief for the design panel. Scope: control scheme, touch ergonomics, readability numbers, camera, safe areas, and Godot 4.7.2 (Compatibility renderer) implementation specifics.

Tags: **[web]** = sourced (URLs at the end, numbered S1…), **[src]** = verified by reading the Godot **4.7.2-stable** source/class XML (fetched from GitHub, and `godot --doctool` on the container's 4.7.2 binary), **[derived]** = my arithmetic from sourced numbers, **[memory]** = my own knowledge, not verified this session.

---

## 0. TL;DR: the one control scheme

**"Tap-to-Sneak + Thumb Action"**: point-and-click movement, plus one big context button under the right thumb.

1. **Tap the world** (any finger) to tiptoe there. Tap a hotspot (item, prank spot, hiding place, door, stairs) and the hero walks to its use-point. **Pick-ups, hiding and doors run by themselves on arrival.** **A second tap within 280 ms turns the walk into a run**, which is noisy. A single tap never waits to find out whether a double tap is coming.
2. **Action button** (bottom-right, 240 px hit area, 190 px visual). It shows the current context verb as an icon. Tap it for instant verbs. For **pranks, hold it**: a progress ring fills over 0.8, 1.5 or 2.5 s. Letting go pauses the prank and keeps the progress. Sliding more than 80 px off the button, or being spotted, cancels it.
3. **Item tray** (bottom-left, up to 4 slots). Items apply themselves: when you are at a hotspot that accepts something you carry, the action button shows that item. Tapping a slot asks "where can I use this?" and edge arrows point to matching hotspots.
4. **Camera**: auto-follows the hero. One-finger drag on empty world pans, and the camera springs back 1.5 s after release. Pinch zooms between 0.5× and 1.25×, and a toggle button gives the same overview for people who cannot pinch. A **Neighbour-Cam picture-in-picture** (top-right, 448×252) appears only when the neighbour is relevant and off-screen. Tapping it is a **peek**: the main camera flies to him for 1.8 s and comes back.
5. **Top-left**: pause. **Top-centre**: rating meter and prank counter, which you only glance at and never tap.

Why this scheme: every reference game that turned a side-view or diorama puzzle-stealth game into a good touch game used tap-to-target, not a stick (Monument Valley, Thimbleweed Park, Broken Sword DC, the NfH mobile port, Hitman GO's swipe-on-a-graph). The game where direct physical control *was* the point (Untitled Goose Game) never shipped on phones, because "it'll take a lot of design work to make a version that works good for touch controls" (Panic's Cabel Sasser) [web S10]. Booby's floating joystick plus JUMP (portrait) is exactly the twitch-platformer scheme this genre does not need (booby/game/scenes/raid/touch_controls.gd). The fun here is **observe, plan, time, payoff**. The controls should take one thumb and then get out of the way of the comedy.

---

## 1. The physical constants (design at 1080 logical px height)

With base resolution 1920×1080, `canvas_items` stretch and `expand` aspect (section 6), **every phone renders at exactly 1080 logical px tall** and wider screens gain width. Phones in landscape are 57–73 mm tall, so **1 mm ≈ 15–19 logical px on every phone**. Design with **17 px/mm**. This matters because Godot's `screen_get_dpi()` is useless for mm maths on Android: it "groups" densities into six buckets (120/160/240/320/480/640) [src DisplayServer.xml].

| Device (landscape) | Logical viewport | Screen height | px/mm | 144 px = | 240 px = | 360 px character = |
|---|---|---|---|---|---|---|
| iPhone SE 3 (4.7", 16:9) | 1920×1080 | 58.4 mm | 18.5 | 7.8 mm | 13.0 mm | 19.5 mm |
| iPhone 13 mini (5.4") | 2340×1080 | 57.6 mm | 18.7 | 7.7 mm | 12.8 mm | 19.2 mm |
| iPhone 16 (6.1") | 2341×1080 | 65.1 mm | 16.6 | 8.7 mm | 14.5 mm | 21.7 mm |
| iPhone 16 Pro Max (6.9") | 2347×1080 | 72.9 mm | 14.8 | 9.7 mm | 16.2 mm | 24.3 mm |
| Budget Android 6.5" 720×1600 | 2400×1080 | 67.7 mm | 15.9 | 9.0 mm | 15.1 mm | 22.6 mm |
| Pixel 8a (6.1", 20:9) | 2400×1080 | 63.8 mm | 16.9 | 8.5 mm | 14.2 mm | 21.3 mm |
| Xperia 10 (6.1", 21:9) | 2520×1080 | 61.1 mm | 17.7 | 8.1 mm | 13.6 mm | 20.4 mm |
| iPad 10th gen (10.9") | 1920×1334 | 157.8 mm | 8.5 | 17 mm | 28 mm | 43 mm |
| Galaxy Z Fold inner (7.6") | 1920×1650 | 126 mm | 13.1 | 11 mm | 18 mm | 27 mm |

[derived from panel pixel counts and ppi; iPhone point sizes from S13]

### 1.1 Minimum tap target
- Material 48 dp on the most common Android viewport, 360×800 dp (~11 % share, S16), is 48/360 × 1080 = **144 px** [derived]. Apple's 44 pt on a 375-pt-tall iPhone is 127 px [web S7, derived].
- Hoober's field data: about 7 mm in the screen centre, but **11 mm at the top edge and 12 mm at the bottom edge** [web S6]. That is ≈120 / 187 / 204 px.
- Xbox Accessibility Guideline 107 for **game** touch controls on phones: **15 mm × 15 mm** (24 mm on tablets) [web S8]. That is ≈255 px.

**Rules:**
- **Absolute minimum hit area: 144×144 px.**
- **Standard HUD buttons: 168 px hit, 128 px visual (≈10 mm).**
- **Primary action button: 240 px hit circle, 190 px visual (≈14 mm).**
- **World hotspots: hit box at least 144×144 px, however small the art** (a banana peel is 60 px). Add tap-assist that snaps a miss to the nearest hotspot within 90 px.
- **At least 24 px of dead space between targets**, as XAG 107 recommends [web S8].

### 1.2 Minimum text size (Godot font size = em height, in logical px)
- iOS: never below 11 pt [web S7]. On a 375-pt-tall phone that is **32 px**. Android's 12 sp caption on a 360-dp-tall phone is **36 px** [derived].
- Microsoft's handheld guidance: at least 14 px text height at 1080p on a 7" screen, 18 px recommended [web S9]. A 7" 1080p panel runs ≈12.4 px/mm and our phones ≈17, so the same physical text height is ≈25 px, which is a **≈36 px font** at a cap height of 0.7 em [derived]. Two independent routes give the same number.
- **Rules: 36 px minimum anywhere. 44 px for anything read during play** (item names, bubbles, prompts). **48–56 px for HUD numbers. 72–96 px for titles.** Always add a 4–6 px dark outline over the game world. Prefer icons and pantomime to text: the owner judges this on a phone, and every second spent reading is a second not laughing.

### 1.3 How big characters must be to read expressions
- Our reference is the PC original: 1024×768 with ~100 px characters on a ~23 cm-tall monitor at ~60 cm [memory]. That is ≈3° of visual angle. At a 30 cm phone distance, 3° is ≈15 mm, or **≈250 px**.
- Humans read posed facial expressions at great distances (every observer labelled them correctly at 30–45 m) [web S15]. That is an argument for **big, clean, exaggerated faces**, not for tiny ones.
- **Rule: hero and neighbour stand ≈360 px tall (33 % of screen height, 19–24 mm on phones). Heads are ≥120 px (≈7 mm), using 1:3 cartoon proportions. Eye whites ≥24 px, pupils ≥10 px, an open mouth ≥40 px wide, outlines 5–6 px.** During a gag payoff the camera punches to 1.4–1.5×, which makes heads ≈170–180 px.
- For comparison, Booby's portrait raider was ~216 px (booby/game/view/camera_rig.gd header).
- **Consequence for level design:** do *not* show the whole house at once the way the PC original did. At that scale a phone shows 8 mm-tall people with 3 mm heads and the jokes die. Show **one floor per screen**: 640 px room interior plus 60 px slabs ≈ 700 px, leaving ≈190 px above and below. That leak is useful: seeing **the neighbour's legs on the floor above** is both a stealth cue and a gag.
- At overview zoom 0.5 (characters 180 px, heads 60 px) poses still read but faces do not. Auto-zoom back in for every payoff.

---

## 2. What the reference games teach

| Game (touch) | Scheme | Lesson for us |
|---|---|---|
| **NfH mobile ports** (2017 Season 1 free port by Big Moon/THQ Nordic; 2021 "Neighbours back From Hell" remaster, $4.99, controller support) [web S1, S2, S3] | Tap-based point-and-click | "Easy to use interface and controls" [S2]. User complaints: minigames that ask you to keep an object inside a circle were hard on touch, and **"swiping to move the screen … while hiding causes Woody to move"** [S1 summary]. Fixes: separate pan and tap with a travel threshold, fire on touch-up, never read a drag as a move. No precision-tracking minigames. |
| **Thimbleweed Park** iOS/Android [web S4, S5] | Tap to walk, verbs, double-tap = default verb, **tap-and-hold anywhere = show all hotspots, then drag to one and lift**; double-tap-and-hold = hero follows your finger | Ron Gilbert: "on touch they will be triggered on touch up, so you can swipe around the screen for hotspots" [S4]. We copy **activation on touch-up** and **hold-to-reveal hotspots**. We drop verbs: the context button replaces them. |
| **Broken Sword DC** iOS [web S11] | Tap to move, tap to interact, optional **swipe-to-reveal hotspots**, hint system | Hotspot reveal can be optional so purists can ignore it. |
| **Monument Valley** [web S12] | Pure tap-to-move on a walkable graph; re-tapping re-routes instantly; short path preview | Tapping somewhere new must **re-route instantly** while walking, with a brief path preview. |
| **Hitman GO** [web S14] | Swipe along node-graph lines, turn-based | Stealth works on touch when *state is readable*: enemy facing and route always visible. For us that means the neighbour's alert icon, sight hint and next-destination bubble. |
| **Untitled Goose Game** | Not on mobile; Panic said touch "will take a lot of design work" [web S10] | Stick-driven physical slapstick does not port. Keep slapstick in the *animation*, not in the input. |
| **Scary Teacher 3D** (the genre's mass-market mobile heir) | Virtual joystick bottom-left, big hand-icon action button bottom-right, swipe to look [web S17] | Its contextual action button is proven. The joystick is forced by its 3D camera; our side view does not need one. |
| **Sneaky Sasquatch** | Joystick/swipe movement | Reviewed as getting "a bit wonky" as a one-finger, movement-only game [web S18]. |

**Why not a virtual joystick:** a side-view house is almost 1-D per floor plus doors and stairs, so a stick adds overshoot and a permanently busy thumb for no expressive gain. It forces the two-handed "gamer stance", which is a niche on phones [web S19]. Tap-to-move also works one-handed ("casual prodder") and lets the eyes stay on the neighbour instead of the hero's feet.

**Why not swipe-to-walk:** it cannot express "go to *that* vase". Swipe gestures also collide with the Android back gesture at the side edges (section 5.3).

---

## 3. The recommended scheme in full

### 3.1 Gesture grammar (all distances in logical px at 1080 height)

| Input | Rule | Result |
|---|---|---|
| **Tap** | Touch-up ≤300 ms after touch-down, travel ≤24 px (≈1.4 mm), no second finger | Priority: hotspot (with 90 px tap-assist) > door/stairs > floor. The hero walks; ripple marker (≤16 ms, 0.35 s fade) and dotted path (0.4 s). |
| **Second tap** | ≤280 ms and ≤64 px from the first | Upgrades the current walk to a **run** (700 vs 380 px/s starting values; running makes noise). Never delay the first tap. |
| **Long-press on world** | ≥450 ms, travel ≤24 px | **Reveal**: every hotspot in view shows its icon for 2 s; lifting on one selects it (Thimbleweed pattern). Mild haptic (8 ms). |
| **One-finger drag on world** | Travel >24 px | Camera pan 1:1 (world follows the finger). On release, fling with decay τ = 0.25 s, hold 1.5 s, then ease back over 0.5 s. **A drag never moves the hero**, even when hidden (the NfH complaint). |
| **Pinch** | Two touches, distance change >32 px | Zoom 0.5–1.25, anchored at the pinch midpoint. **Overview toggle button** as the non-multi-touch alternative (XAG 107 asks for alternatives to multi-point gestures [S8]). |
| **Tap action button** | Instant verbs | Grab / hide / leave hiding / open / close / use a switch. |
| **Hold action button** | Pranks | Ring fills over the prank's tier time (below). |
| **Tap Neighbour-Cam** | | **Peek**: camera flies 0.35 s to the neighbour, holds 1.8 s (as long as the finger stays down if held), flies back. |
| **Tap item slot** | | "Where can I use this?": matching hotspots pulse and off-screen ones get edge arrows for 3 s. |
| **Drag item onto hotspot** | Optional power-user path | Same as walk + use. Never the only way (XAG: path gestures need alternatives [S8]). |
| **Android back / iOS swipe** | | Pause menu, never quit (`application/config/quit_on_go_back=false`, handle `NOTIFICATION_WM_GO_BACK_REQUEST`) [src]. |

Activation happens on **touch-up** everywhere except the hold button, as XAG 107 recommends ("Control activations should occur on touch-end") [S8]. Thimbleweed does the same [S4].

**Arrival auto-actions.** Tapping a hotspot means "go and do it". Pick-ups, hiding, doors and stairs execute on arrival with no second input. **Pranks do not auto-execute.** The hero arrives, faces the spot and the action button lights up with the prank icon plus a 1.08× pop, and the player chooses *when* to commit. That hold is the game's tension beat: "one more second… he's coming… let go!"

### 3.2 Hold-to-perform with progress ring and cancel
- **Tier times:** quick 0.8 s (soap the step), standard 1.5 s (loosen the chair leg), big 2.5 s (rig the ceiling fan). **Never over 3 s**: XAG flags holds of 2–3 s or more [S8]. Total hold time per episode should stay under ~20 s.
- **Ring:** 14 px stroke around the 190 px button, clockwise from 12 o'clock, yellow turning green. It pulses at 3 Hz for the last 20 %. On completion the button pops 1.0 → 1.18 → 1.0 over 180 ms, with a "done" sting and a 30 ms, 0.7-amplitude haptic. A 50 % tick gives an 8 ms haptic. `Input.vibrate_handheld(ms, amplitude)` needs the Android `VIBRATE` permission [src Input.xml].
- The hero's animation **escalates with progress** (tiptoe fiddling, then frantic sawing, then a smug wipe of the brow). Progress is diegetic, not just a ring.
- **Release early:** progress is **kept** and the icon shows the partial ring, so returning resumes. The genre's comedy is in the *getting caught*, not in redoing work.
- **Cancel:** slide more than 80 px off the button (the XAG "short press and drag to cancel" pattern [S8]), or automatically when spotted: the hero drops everything with a comic yelp and the partial progress stays.
- **Accessibility toggle "Tap to prank":** holds become tap-to-start / tap-to-stop, like The Long Dark's "accessible interactions" cited in XAG 107 [S8].
- **Thumb occlusion:** while the button is held, the right thumb and palm cover about the bottom-right 250×300 px. **Offset the camera 200 px so the hero sits at 40–60 % of screen width**, never under the thumb.

### 3.3 Hotspot highlighting
- **Current room, default "always":** a 4 px outline pulsing at alpha 0.6 ↔ 1.0 at 1.2 Hz, plus a sparkle every 1.2 s. Hotspots you can act on **right now** (you carry the item, or it is a free prank) get a stronger gold glow and a 56 px icon badge above them.
- **Long-press reveal** as in 3.1. A setting offers Hints: Always / On long-press / Off.
- **Implementation:** use **pre-baked outline sprites in the same atlas** as the object, not a per-sprite outline shader. In the GLES3 canvas renderer a material change starts a new batch (`_render_items`, 4.7.2 [src]). If a shader is needed, share **one** ShaderMaterial resource across all highlighted objects.

### 3.4 Inventory in landscape
- Bottom-left tray: **4 slots × 128 px visual (168 px hit), 16 px gaps** (≈560×168 px) at (safe_left + 40, H − safe_bottom − 184). Four slots is a deliberate design cap: no scrolling, no bag screen.
- The item that the current hotspot accepts rises 12 px and glows. The action button then shows *item icon + verb*, so there is never a "select item, then target" two-step. That two-step is a classic point-and-click friction on touch.
- Left-handed setting: mirror the tray and the action button (Booby already had `left_handed`).

### 3.5 Camera: auto-follow, pan/pinch, peek, Neighbour-Cam
- **Framing:** one floor fills the height at zoom 1.0. The hero sits at 40–45 % of screen width with a **12 % look-ahead** toward the walking direction.
- **Smoothing:** exponential, τ = 0.20 s horizontally, 0.15 s while running. Vertical only snaps floor to floor with a 0.40 s ease-in-out when stairs are used. The camera never bobs with the walk.
- **Limits** are the house bounds, so the camera never shows void.
- **Gag camera:** on a prank trigger, cut focus to the victim. Zoom 1.0 → 1.4 in 0.18 s, **80–120 ms hit-stop** on impact, shake 10–16 px decaying over 0.25 s, hold 1.2–2.0 s on the reaction face, ease back in 0.35 s. Input stays live during the gag, but taps are queued, not dropped.
- **Neighbour-Cam PiP:** a 448×252 window, 16:9, ≈26×15 mm, top-right inside the safe area with 24 px margins, 5 px frame, and a mood icon (36 px) in its corner. It only shows when the neighbour is **off-screen AND** (he is within 1 room, or heading to your room, or you are mid-prank). It hides 2 s after the condition clears. Rendering it only while visible keeps it cheap (6.6).
- **Off-screen indicator** when the PiP is hidden: a 96 px face bubble on the screen edge pointing at him, with "↑ upstairs" or "2 rooms" text at 36 px.
- **Audio** is the third channel. Neighbour footsteps are panned by his screen-relative x and attenuated by rooms between you. It is the cheapest "where is he" UI there is.

### 3.6 HUD map (examples: 2400×1080 Android, 2341×1080 iPhone)

```
┌──────────────────────────────────────────────────────────────────────┐
│ [II]            [ RATING ████░░  3/7 pranks  2:41 ]      [ NEIGHBOUR │
│ pause                                                     CAM 448×252]│
│                                                             [overview]│
│                                                                      │
│          (world only — keep the middle 60 % of height clear)          │
│                                                                      │
│ [itm][itm][itm][itm]                                        ( ACTION ) │
│  4×128 px tray                                               190/240px │
└──────────────────────────────────────────────────────────────────────┘
```

- Anchor HUD to **safe-area corners, not to the 1920 central rect**, so buttons hug the physical corners where the thumbs are.
- Two-handed thumbs comfortably cover roughly a 45–50 mm (~800 px) quarter-disc from each bottom corner [memory/estimate]. **Top-centre is the least reachable zone**, so put only glanceable information there. Pause sits in a corner at 144 px: reachable, but hard to hit by accident.
- On tablets and foldables (logical height >1250) scale the HUD ×0.8. Physical sizes stay above 14 mm.

### 3.7 First-minute UX
- The first episode teaches **two inputs only**: tap the glowing thing, then hold the big button. A ghost finger demonstrates each once (Booby's hint system is reusable).
- Pan, pinch, peek and item-tap are introduced in episodes 2–3, when a level first *needs* them.
- **Target: the first gag lands 30–40 s after boot**, with no menu before episode 1.

---

## 4. Aspect ratios 16:9 → 21:9 and 4:3

Base **1920×1080 + `canvas_items` + `expand`**:

| Aspect ratio | Logical viewport | Effect |
|---|---|---|
| 16:9 | 1920×1080 | The gameplay-safe minimum |
| 19.5:9 / 20:9 | ≈2340–2400×1080 | +220–240 px per side |
| 21:9 | 2520×1080 | +300 px per side |
| 4:3 iPad | 1920×1334–1440 | Extra floor above and below becomes visible |
| 16:10 tablet | 1920×1200 | Extra floor above and below becomes visible |
| Fold inner | 1920×~1650 | Extra floor above and below becomes visible |

[derived; stretch semantics per S20 and ProjectSettings.xml src]

**1920×1080 vs 2400×1080 base:**
- A 2400×1080 base behaves identically on 20:9 phones.
- On narrower screens it adds *height by shrinking everything*: 16:9 phones get 2400×1350, which makes HUD and characters 20 % smaller on the smallest phones, and 4:3 gets 2400×1800, 40 % smaller.
- **Choose 1920×1080.** Design all gameplay for a guaranteed 1920×1080 world view. Treat extra width as a bonus periphery, and make sure no warning depends on it (the PiP, the edge bubble and audio carry warnings).
- The notch and cutout insets (section 5) almost exactly consume the extra width on phones: an iPhone 16 keeps 2341 − 2×162 = **2017 px** of fully safe width [derived]. The HUD therefore never overlaps the 1920 core even on notched phones.
- Keep camera zoom at 1.0 on all aspect ratios, so character size relative to screen height is constant. Tablets simply see more of the floors above and below, which is a mild, harmless advantage.
- Godot's own guidance for mobile: canvas_items + expand. A 1920×1080 base is its "high-end" option with a larger theme scale [web S20].

---

## 5. Notches, cutouts, safe areas, system gestures

### 5.1 iOS (landscape insets from S13)
| Model | Left/right inset | Bottom inset | In logical px |
|---|---|---|---|
| iPhone 16 / 16 Plus | 59 pt | 21 pt | ≈162 px per side, ≈58 px bottom |
| iPhone 16 Pro | 62 pt | 21 pt | ≈167 px per side |
| iPhone 16 Pro Max | 62 pt | 21 pt | ≈152 px per side |
| iPad (Face ID models) | none | home indicator | ≈20 pt bottom [memory] |

- iOS reports the side insets **symmetrically**, even though the Dynamic Island is on one side.
- Godot settings [src ProjectSettings.xml]:
  - `display/window/ios/hide_home_indicator=true` (default).
  - `display/window/ios/suppress_ui_gesture=true` (default): "it will require two swipes to access iOS UI that uses gestures", so bottom-edge swipes do not exit mid-prank.

### 5.2 Android
- In landscape the punch-hole sits on a **short edge**, so left or right. The window can render into short-edge cutouts but "can never extend into a cutout area on the long edges" [web S21].
- **Android 15 with targetSdk 35 enforces edge-to-edge.** `SHORT_EDGES` and `NEVER` are both treated as `ALWAYS` [web S21, S22].
- **What Godot 4.7.2 actually does** [src Godot.kt, GodotIO.java]:
  - With export option `screen/immersive_mode=true` it hides the system bars (`BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE`) and sets root padding to 0, so the game draws full-bleed including behind the cutout.
  - `DisplayServer.get_display_safe_area()` then returns **display-cutout insets only**.
  - `screen/edge_to_edge` only matters when *not* immersive (translucent bars).
  - **Recommended export: `screen/immersive_mode=true`, `screen/edge_to_edge=false`**, which is Booby's preset. `get_display_cutouts()` is Android-only; iOS returns an empty array [src].
- Typical punch-hole inset in landscape is ≈80–140 logical px on one side [memory/estimate]. **Measure it on the owner's phone** with a debug overlay.

### 5.3 Rules
1. **Symmetric HUD insets:** `side = max(left, right)`, applied to both sides.
2. Use orientation `SENSOR_LANDSCAPE` so the phone can be flipped (charging cable, left-handers). With symmetric insets the layout does not jump when the cutout changes sides.
3. **Re-query the safe area** on `size_changed`, on `NOTIFICATION_APPLICATION_RESUMED` and focus-in, **and poll it every 0.5 s**. A 180° flip does not change the window size, so size-based signals may not fire [derived; verify on device].
4. The world renders full-bleed. Only HUD, bubbles and edge indicators respect the insets.
5. **Android back gesture:** it is an inward swipe from the left or right edge, which in landscape means right next to both thumbs [web S23].
   - Immersive mode suppresses most system gestures, but a swipe re-enables them [S23].
   - `setSystemGestureExclusionRects` is capped at 200 dp per edge. The cap is waived when the nav bar is hidden with transient-by-swipe, which is Godot's immersive mode [web S24]. Godot exposes no exclusion API [memory].
   - So: **no gameplay drag may start within 48 px of a side edge**. Buttons sit at least 32 px inside the safe area. Map back to pause.

---

## 6. Godot 4.7.2 implementation specifics

### 6.1 `project.godot` (landscape)

```ini
[application]
config/quit_on_go_back=false          ; back gesture -> pause (NOTIFICATION_WM_GO_BACK_REQUEST)
run/max_fps=60                        ; cap 90/120 Hz phones: thermals + battery

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1200 ; desktop test window = 20:9 at half size
window/size/window_height_override=540
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4         ; DisplayServer.SCREEN_SENSOR_LANDSCAPE (0=LANDSCAPE fixed)
window/ios/hide_home_indicator=true
window/ios/suppress_ui_gesture=true
window/frame_pacing/android/swappy_mode=0 ; pipeline_forced_on (default 2 may settle at 30 fps)

[input_devices]
pointing/emulate_touch_from_mouse=true ; desktop mouse -> touch events for testing
; emulate_mouse_from_touch stays true (default) but gameplay ignores mouse events

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
2d/snap/snap_2d_transforms_to_pixel=false
```

Notes on these settings:
- Enum values verified in the 4.7.2 XML [src]: orientation LANDSCAPE=0 … SENSOR_LANDSCAPE=4.
- On iOS, `screen_set_orientation` only works when the setting is `SCREEN_SENSOR` [src], so pick the orientation in project settings, not at runtime.
- Swappy: the doc warns that the auto modes "will often downgrade the max FPS", so a game running at 40–60 fps "after some time" renders at 30 [src]. Slapstick timing suffers at 30. Force the pipeline and fix the frame budget instead.
- Test aspect ratios on desktop with 960×540 (16:9), 1260×540 (21:9) and 1024×768 (4:3). Reuse Booby's `--safe-area=L,T,R,B` fake-inset flag (booby/game/scenes/raid/touch_controls.gd) to test notch layouts on desktop.

### 6.2 Safe-area helper (symmetric, flip-proof)

Adapted from booby/game/autoload/support/safe_area.gd:

```gdscript
## Returns insets in logical px: x=left, y=top, z=right, w=bottom; sides made symmetric.
static func insets(vp: Viewport) -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()   # physical px, Rect2i
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var s := vp.get_visible_rect().size / Vector2(win)  # physical -> logical
	var side := maxf(safe.position.x, win.x - safe.end.x) * s.x
	return Vector4(side, safe.position.y * s.y, side, (win.y - safe.end.y) * s.y)
```

Call it from a HUD root on `size_changed`, on `NOTIFICATION_APPLICATION_RESUMED`, and from a 0.5 s Timer. Re-layout only when a value changes by more than 1 px.

### 6.3 Touch routing (what the 4.7.2 source says)
- **Controls receive `InputEventScreenTouch/Drag` directly.** `Viewport` hit-tests with `gui_find_control`, remembers `touch_focus[index]` so the release goes to the same control, and calls `_gui_input` [src viewport.cpp].
- A `MOUSE_FILTER_STOP` control marks the event handled, so it never reaches `_unhandled_input` [src Control.xml].
- **Rules:** HUD widgets use STOP. Full-screen layout containers use IGNORE, or they swallow world taps. World input lives in `_unhandled_input`.
- **Emulated mouse follows only the first touch.** `Input` translates only `mouse_from_touch_index` [src input.cpp].
  - In 4.7.2 `BaseButton` also tracks its own real touch index, skipping emulated events [src base_button.cpp], so two thumbs on two Buttons work.
  - Still, **write the action button as a custom Control that reads `InputEventScreenTouch/Drag` by index.** It needs press, release, slide-off and a hold timer anyway.
  - In gameplay code ignore every `InputEventMouse*`. Desktop testing still works through `emulate_touch_from_mouse`; emulated events carry `device == InputEvent.DEVICE_ID_EMULATION` (−1) [src].
- `InputEventScreenDrag.relative` and `velocity` are scaled by the stretch; `screen_relative` and `screen_velocity` are not [src]. For panning in *logical* px use `relative`, divided by camera zoom.
- Avoid `Viewport.physics_object_picking` for hotspots. It is "limited to 64" objects "selected in a non-deterministic order" [src]. Hit-test your own hotspot rectangles, sorted by priority and then distance.

Minimal world input router (a Node2D in the world canvas):

```gdscript
extends Node2D
signal tapped(world_pos: Vector2, is_double: bool)
signal long_pressed(world_pos: Vector2)
signal pan(delta_screen: Vector2)
signal pinch(factor: float, mid_screen: Vector2)
const SLOP := 24.0
const TAP_MS := 300
const LONG_MS := 450
const DOUBLE_MS := 280
const DOUBLE_SLOP := 64.0
var _t := {}                   # index -> {p0: Vector2, p: Vector2, t0: int, moved: bool, long: bool}
var _last_tap_ms := -100000
var _last_tap_pos := Vector2(-1e9, -1e9)
var _pinch_d := 0.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_t[e.index] = {"p0": e.position, "p": e.position, "t0": Time.get_ticks_msec(), "moved": false, "long": false}
			if _t.size() == 2:
				_pinch_d = _two_dist()
		else:
			var d: Dictionary = _t.get(e.index, {})
			_t.erase(e.index)
			if d.is_empty() or e.canceled or d.moved or d.long or not _t.is_empty():
				return
			if Time.get_ticks_msec() - int(d.t0) > TAP_MS:
				return
			var now := Time.get_ticks_msec()
			var dbl: bool = now - _last_tap_ms <= DOUBLE_MS and e.position.distance_to(_last_tap_pos) <= DOUBLE_SLOP
			_last_tap_ms = now
			_last_tap_pos = e.position
			tapped.emit(_to_world(e.position), dbl)   # never wait for a possible double tap
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and _t.has(e.index):
		var d: Dictionary = _t[e.index]
		d.p = e.position
		if not d.moved and e.position.distance_to(d.p0) > SLOP:
			d.moved = true
		if _t.size() == 1 and d.moved:
			pan.emit(e.relative)
		elif _t.size() == 2 and _pinch_d > 0.0:
			var nd := _two_dist()
			pinch.emit(nd / _pinch_d, _two_mid())
			_pinch_d = nd
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	for i in _t:
		var d: Dictionary = _t[i]
		if not d.moved and not d.long and _t.size() == 1 and Time.get_ticks_msec() - int(d.t0) >= LONG_MS:
			d.long = true
			long_pressed.emit(_to_world(d.p))

func _to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen

func _two_dist() -> float:
	var v := _t.values()
	return (v[0].p as Vector2).distance_to(v[1].p)

func _two_mid() -> Vector2:
	var v := _t.values()
	return ((v[0].p as Vector2) + (v[1].p as Vector2)) * 0.5
```

Use `pinch` as `zoom = clamp(zoom * factor, 0.5, 1.25)`, then shift the camera so the world point under `mid_screen` stays put. Pinch is implemented by hand from two touch indices. `InputEventMagnifyGesture` on Android needs `input_devices/pointing/android/enable_pan_and_scale_gestures` [src], and the manual version behaves the same on both platforms.

### 6.4 Camera2D: smoothing and limits
- **Do not use built-in `position_smoothing`.** In 4.7.2 it is a plain linear step, `c = position_smoothing_speed * delta` (so it depends on frame rate), and the engine carries a FIXME that it "may be called MULTIPLE TIMES on certain frames… haphazard results" [src camera_2d.cpp lines ~194–204].
- Set `position_smoothing_enabled=false` and drive the camera yourself:
  `position = position.lerp(target, 1.0 - exp(-delta / 0.20))` (frame-rate independent). Shake goes in `offset`.
- Set `limit_left/right/top/bottom` to the house bounds; clamping still applies. `zoom > 1` zooms **in** [src].
- Use `get_screen_center_position()` for the *actual* centre [src].
- Run camera and hero motion in `_process`: tap-to-move needs no physics bodies. This also avoids physics-interpolation questions (`physics/common/physics_interpolation` stays off).

### 6.5 Performance on mid-range Android (Compatibility renderer)

**What breaks a 2D batch** in 4.7.2 GLES3 [src rasterizer_canvas_gles3.cpp `_render_items` / `_record_item_commands`]: a change of
- clip owner (`clip_children`)
- **material/shader**
- texture filter
- texture repeat
- **blend mode**
- lit/unlit state
- **texture** (or command type)

Only **rects and nine-patches are instanced into one draw call** (`glDrawElementsInstanced` with N instances). **Every Polygon2D and every mesh, MultiMesh or particle command is its own draw call** [src `_render_batch`].

**Rules that follow:**
- Build characters from **Sprite2D/AnimatedSprite2D parts in one atlas per character**, which gives ~1–3 draw calls per character. Deformed Polygon2D/Skeleton2D rigs cost one call per polygon.
- Keep each room's props in 1–2 atlases.
- Avoid Light2D: bake lighting into the art and use additive sprites.
- **CanvasGroup is expensive on tile GPUs.** Each group flushes pending batches, renders its children into the back buffer (a render-target switch), then composites [src]. Allow at most 1–2 on screen and never one per character. For fades, modulate the parts.
- **Particles:** use CPUParticles2D for gag bursts (dust, feathers, soap bubbles). They are one draw call per emitter; set `one_shot`, pool and `restart()`, and use `fixed_fps=30`.
  - Budget: ≤8 active emitters and ≤300 live particles.
  - GPUParticles2D *does* run in Compatibility (only trails and SDF collision are unsupported per the official table [web S25]; there are 4.2-era bugs about it failing to emit [web S26]). One blog claims GPU particles "silently fail" in Compatibility [web S27]; that contradicts the docs. CPU particles are simply the lower-risk choice.
- **Budgets for a Galaxy A-series / Adreno 610 / Mali-G52 class phone** [memory, verify on device]:
  - ≤150 2D draw calls per frame (≤250 hard ceiling).
  - Overdraw ≤4 full-screen blended layers. All 2D is alpha-blended with no depth rejection, so a full-screen vignette costs as much as a wall.
  - Textures ≤4096² per page. GLES 3.0 only guarantees 2048; nearly all current devices do 4096 [memory].
  - Total textures ≤250 MB. Backgrounds VRAM-compressed (ETC2/ASTC); characters and UI lossless.
  - Mipmaps only on world textures that are shown at overview zoom 0.5 (+33 % memory).
- **Fonts:** MSDF import for crisp scaling and cheap outlines [memory].
- **Measure on device:** `get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)`. Canvas draws are counted under `VIEWPORT_RENDER_INFO_TYPE_CANVAS` [src]. Also watch `Performance.RENDER_TEXTURE_MEM_USED`. Put both on a debug overlay the owner can toggle.

### 6.6 Neighbour-Cam PiP (SubViewport sharing the world)

```gdscript
@onready var pip_vp: SubViewport = $PipViewport       # child Camera2D follows the neighbour
@onready var pip_rect: TextureRect = $HUD/PipRect      # 448x252, top-right inside safe area
func _ready() -> void:
	pip_vp.world_2d = get_viewport().world_2d            # same world, no duplicate nodes
	pip_vp.size = Vector2i(448, 252)
	pip_vp.canvas_cull_mask = 0b01                       # items on visibility_layer 2 (hotspot glows, hero marker) hidden
	pip_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pip_rect.texture = pip_vp.get_texture()
func set_pip_visible(on: bool) -> void:
	pip_rect.visible = on
	pip_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
```

- A Camera2D registers with the nearest Viewport ancestor [src], so put the PiP's camera inside the SubViewport. Give it zoom 0.75 (it sees ≈600×340 world px around him).
- HUD `CanvasLayer`s are not part of `world_2d.canvas`, so they do not appear in the PiP [memory, consistent with how canvas layers work].
- **Cost:** a second render of whatever is in its view, ≈+30–50 % draw calls while visible. To halve it, render at 30 Hz by setting `UPDATE_ONCE` every other frame.

### 6.7 Owner-on-phone checklist (debug APK)
1. Walk, run and use the action button on the owner's phone in both landscape directions. Check that nothing sits under the punch-hole.
2. Tap a banana-peel-sized hotspot 20 times with a thumb: at least 19 hits.
3. Pan while hidden: the hero never moves.
4. Hold a prank with the right thumb: the hero is visible and the ring is readable.
5. Check that 36 px text is readable at arm's length.
6. Stable 60 fps with the PiP open plus a gag burst, as shown by the debug overlay.
7. Time from boot to the first laugh: under 40 s.

---

## Sources
- S1 Neighbours back From Hell, Metacritic user reviews (summary incl. touch complaints): https://www.metacritic.com/game/neighbours-back-from-hell/ ; search summary of App Store/Play reviews
- S2 NfH Season 1, App Store: https://apps.apple.com/us/app/neighbours-from-hell-season-1/id1114028201 ; TouchArcade 2017 free port: https://toucharcade.com/2017/05/30/thq-releases-a-free-neighbours-from-hell-port-on-the-app-store/ ; Wikipedia (mobile port 25 May 2017, Big Moon Entertainment): https://en.wikipedia.org/wiki/Neighbours_from_Hell
- S3 TouchArcade, Neighbours back From Hell mobile ($4.99, controller support, 3 Aug 2021): https://toucharcade.com/2021/08/03/neighbours-back-from-hell-iphone-android-out-now-price-controller-support-handy-games/
- S4 Thimbleweed Park blog, "Thimbleweed Park on the iPhone": https://blog.thimbleweedpark.com/thimble_phone.html
- S5 AppUnwrapper, Thimbleweed Park touch controls guide (via search summary; page returned 403): https://www.appunwrapper.com/2017/09/20/thimbleweed-park-touch-controls-guide/
- S6 Smashing Magazine, Accessible Target Sizes Cheatsheet (Hoober 7/11/12 mm): https://www.smashingmagazine.com/2023/04/accessible-tap-target-sizes-rage-taps-clicks/
- S7 Apple HIG 44 pt / 11 pt minimums (via LogRocket and HIG summaries): https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/ ; https://developer.apple.com/design/human-interface-guidelines/accessibility
- S8 Xbox Accessibility Guideline 107 (input; mobile 15 mm targets, touch-up activation, holds, cancel, Long Dark example): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107
- S9 Microsoft handheld guidance (text ≥14 px, rec. 18 px at 1080p on 7"): https://learn.microsoft.com/en-us/gaming/gdk/docs/gdk-dev/pc-dev/handheld/handheld-guidance
- S10 Untitled Goose Game not on mobile, Cabel Sasser quote: https://www.imore.com/untitled-goose-game-could-make-its-way-mobile ; https://www.cultofmac.com/news/untitled-goose-game-mobile
- S11 Broken Sword DC iOS (swipe-to-reveal hotspots, hints): https://toucharcade.com/2010/01/25/broken-sword-the-directors-cut-a-point-and-click-classic-made-even-better/ ; https://www.pocketgamer.com/articles/018016/broken-sword-directors-cut/
- S12 Monument Valley tap-to-move: https://www.macstories.net/reviews/monument-valley-review/ ; https://en.wikipedia.org/wiki/Monument_Valley_(video_game)
- S13 iPhone 16 screen sizes and landscape safe-area insets: https://useyourloaf.com/blog/iphone-16-screen-sizes/
- S14 Hitman GO design (GDC 2015, Daniel Lutz): https://www.gamedeveloper.com/design/being-smart-being-stupid-with-i-hitman-go-i-s-design ; https://en.wikipedia.org/wiki/Hitman_Go
- S15 Hager & Ekman 1979, long-distance transmission of facial affect signals: https://www.paulekman.com/wp-content/uploads/2013/07/Long-Distance-Transmission-Of-Facial-Affect-Signals.pdf
- S16 Mobile resolution share (360×800 ≈11 %): https://www.browserstack.com/guide/common-screen-resolutions ; https://gs.statcounter.com/screen-resolution-stats/mobile/worldwide
- S17 Scary Teacher 3D controls (joystick + hand action button): https://poki.com/en/g/scary-teacher-3d
- S18 Sneaky Sasquatch review ("controls get a bit wonky"): https://www.dcgameblog.com/2021/05/apple-arcade-reviews-sneaky-sasquatch-pinball-wizard/
- S19 Mobile Free To Play, "Touch Control Design: Ways of Playing on Mobile": https://mobilefreetoplay.com/control-mechanics/
- S20 Godot docs, Multiple resolutions: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- S21 Android, Support display cutouts: https://developer.android.com/develop/ui/views/layout/display-cutout
- S22 Android edge-to-edge enforcement codelab: https://developer.android.com/codelabs/edge-to-edge
- S23 Android, gesture navigation compatibility: https://developer.android.com/develop/ui/views/touch-and-input/gestures/gesturenav
- S24 Chris Banes, gesture navigation conflicts / 200 dp exclusion limit (search summary): https://medium.com/androiddevelopers/gesture-navigation-handling-gesture-conflicts-8ee9c2665c69
- S25 Godot docs, Overview of renderers (Compatibility feature table): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- S26 godotengine/godot #84072, "GPU Particles 2D/3D in compatibility rendering sometimes don't emit on 4.2": https://github.com/godotengine/godot/issues/84072
- S27 Bugnet blog claim (contradicted by S25): https://bugnet.io/blog/fix-godot-gpu-particles-not-rendering-mobile
- Godot 4.7.2 source read this session [src]: `scene/2d/camera_2d.cpp`, `drivers/gles3/rasterizer_canvas_gles3.cpp`, `scene/main/viewport.cpp`, `core/input/input.cpp`, `scene/gui/base_button.cpp`, `platform/android/java/lib/src/main/java/org/godotengine/godot/{Godot.kt,GodotIO.java}`, `doc/classes/{DisplayServer,ProjectSettings,Camera2D,Viewport,SubViewport,Control,Input,InputEvent*,CanvasGroup,CPUParticles2D}.xml` at https://github.com/godotengine/godot/tree/4.7.2-stable
- Local reference code: `/home/user/ideaboard/booby/game/scenes/raid/touch_controls.gd`, `/home/user/ideaboard/booby/game/autoload/support/safe_area.gd`, `/home/user/ideaboard/booby/game/view/camera_rig.gd`, `/home/user/ideaboard/booby/game/export_presets.cfg`
