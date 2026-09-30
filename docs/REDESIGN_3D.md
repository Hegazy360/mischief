# Mischief Next Door — REDESIGN_3D (v1.0, BINDING for the 3D pivot)

*"The idea is there, it's great. The UI is too crowded, the characters don't look good — 3D characters would be more
appealing — the house is too crowded, and the actions the character is taking are not very obvious. The core idea
itself is correct."* — the owner, after playing the Gate-0 build on his phone.

**Lead decision:** the view goes full 3D: 3D characters in a simplified 3D "dollhouse cutaway" seen from the side
(fixed side-on camera, slight perspective, follows Hush). The sim, content, solver, audio and UI logic stay. The HUD is
decluttered, the house simplified and every action made obvious.

**What this document is.** The binding spec for those four fixes. It overrides `docs/GDD.md` v1.1 only where §6.6 lists
an amendment; everything else in the GDD (verbs, rules, Nights, pranks, scoring, fairness, timing numbers, tone) stays
binding and unchanged. It is style-agnostic about the *look* of the 3D art (the three style look-devs and the owner
board pick it), but binding about readability: sizes, framing, value hierarchy, outlines, what shows when.

**Conventions.** Sizes are logical px at the 1920×1080 base (`canvas_items` + `expand`; a 20:9 phone is 2400×1080
logical, the review shots are 1200×540). `S` / `T` / `B` = side / top / bottom safe insets, `W` = logical width
(1920–2520), `H` = 1080. 3D units are metres. "MUST" rules are acceptance rules. Sim px are the sim's world px
(TECH §2). **1 m = 200 sim px** (§5.5).

**Evidence.** Every number in §5 was checked on a Compatibility-renderer blockout of this spec (greybox set, toy
stand-ins for Hush and Bellows, the real fonts), rendered at 1200×540 and looked at: `docs/review/redesign/`
(index in `docs/review/redesign/index.md`, source in `blockout_src/`). The blockout uses no third-party assets
other than the project's own OFL fonts (Lilita One, Nunito).

---

## 0. The decisions in one table

| Complaint | Root cause (measured, §1) | Fix (binding) |
|---|---|---|
| **UI too crowded** | 9 HUD pieces always on (5 in the top row), 4 empty tray slots, a 448×252 PiP in every frame, a gold footlight row and 24 Stalls heads in the bottom band. | **4 always-on pieces** (pause, Script chip, Clarence, action button). Everything else appears only when it means something (§2). |
| **Characters don't look good** | 2D cutouts with rubber-hose limbs at 31–35 % of the screen height, same ink and saturation as the furniture. | **3D toy-proportioned characters** at 40–44 % of the height, the only things with a 3.5 px outline and a rim light; 2D face cards on 3D heads keep the expression vocabulary (§5.6). |
| **House too crowded** | ~25 drawn objects and 11 hotspots per room, 31 hotspots in 3 rooms, the upper floor and the locked conservatory drawn at full detail, patterned walls. | **The set is dressed per Night**: only what tonight uses is on stage; **≤ 5 live props per room**, ≤ 4 big low-contrast dressing pieces, one hiding spot per room in Act I, plain walls, one floor at a time, locked rooms not built (§3). |
| **Actions not obvious** | One generic "tinker" for every rig (gloves ±10 px in front of the chest), the progress ring only under the thumb, identical gold-star badges, a subtle "armed" art swap. | **Before / during / after / trigger** for every verb and every prank: a preview of the joke, a prop-specific action with a ring *at the prop*, a visible armed state (the red beret tag), and staged payoffs (§4). **One verb per screen.** |
| (keep) | The core loop, the Nights, the sim. | Sim, solver, content, audio, UI logic and the `ViewSnapshot` seam are kept; only two content changes are needed (§6.2). |

---

## 1. What makes today's build crowded and unclear (audit)

Screens looked at: `docs/review/gate0/*` (sneeze strip, cast, stage door), `docs/review/s2-ui/night/*` (the real
NightScene HUD at every aspect), `docs/review/ui/20x9/*`, `docs/review/s2-view/*` (bubble, stare strip, entry warning,
PiP, overview, queued tap, hidden eyes, squeak rings), `docs/review/art-house/*` (every room with hit boxes, rigged and
spent states), `docs/review/s2-night/*`, `docs/review/s2-anim-hush/contact/*`. Board: `redesign/audit_current_n01.png`.

### 1.1 The UI (Night 1, 20:9, `s2-ui/night/n01_20x9.png`)
1. **Nine HUD pieces are on screen at rest:** pause, Figgis chip, the 600×144 brass Applause-o-Meter (dial, number,
   Script counter), the 448×252 Bellows-Cam, the overview button, Clarence, the 744×168 tray (four empty slots),
   the action button and the Stalls band. Their hit boxes cover **18 % of the screen**; with the Stalls band, 24 %.
2. **The top row holds five pieces** and sits over the upper-floor strip (bath, wardrobe, bed): the top 17 % of the
   screen is two layers of detail, none of it playable in Nights 1–2.
3. **The PiP is on in every NightScene capture reviewed** (`n01_20x9`, `n02_20x9`, `p00_t420`, `p00_t900`,
   `prologue_first_cue`), often while Bellows is already on screen — a second copy of what the player is looking at.
4. **The bottom 20 % is the busiest strip:** 11 gold footlights, the apron, 24 silhouetted heads, Clarence, the four
   empty tray slots and the purple action button — zero gameplay information except two buttons.
5. **The loudest button shows FREEZE all the time** (full-colour purple statue) although FREEZE matters only when he
   can see Hush. The one verb that matters at a rig point (RIG) looks the same weight.
6. **Badges don't say anything:** the kitchen shows 6 look-alike badges (4 gold stars, 2 blue closed eyes), placed at
   the top of each hit box, 60–100 px above their objects — the honey's star sits on the plate rack.

### 1.2 The house (`art-house/{hall,parlour,kitchen}_rects.png`, `overview.png`)
1. **Density:** the kitchen alone draws about 25 objects (plates ×3, pans ×3, wall clock, lamp, honey, pepper, spice
   jars, pickle jar, two shelves, kettle, cupboard, stool, fridge with magnet and note, table with cloth and fruit bowl,
   pantry cupboard, curtain, window with plant, sink, tap, back door) on a tiled, wainscoted wall. The parlour ~20, the
   hall ~17.
2. **Hotspots:** 31 in the three slice rooms (hall 10, parlour 10, kitchen 11), drawn with the same ink and saturation
   whether or not tonight uses them; **9 vertical stacks** (kettle/honey, fridge/shelf, pantry shelf/curtain,
   clock/clock case, sink tap/window, piano back/wedge, recliner/newspaper, tea tray/fan, stair rods/foot).
3. **Nothing is hierarchical:** props, set dressing and characters all use 5–6 px navy ink and full saturation
   (GDD §9.1 asked for pastel rooms; in practice the wallpaper diamonds, tiles and gold trims are as busy as the props).
   Plum Bellows stands on a dusty-rose wall of the same hue family.
4. **Off-limits space is drawn at full detail:** the locked conservatory takes the right 25 % of the kitchen view; the
   upper floor shows along the top in every Night.

### 1.3 The actions (`s2-anim-hush/contact/act_tinker_*.png`, `s2-view/rig_*`)
1. **Rigging is one generic fiddle:** `act_tinker_q` is 49 frames of the gloves moving ±10 px in front of the chest,
   identical for pepper→honey, lever→gramophone and squeaker→kettle; the prop does not change while she works.
2. **Progress is under the thumb:** the rig ring lives on the action button (bottom-right), 1,200+ px from the prop
   she is working on.
3. **"Armed" is subtle:** the rigged art variants (`kitchen_rigged.png`) differ by a few sparkles and small inserts;
   the beret stamp is ~20 px on the phone.
4. **What a spot will do is never shown in the world:** the Script panel (paused) holds the only description.
5. **Readability overlays are thin:** the noise ring is a faint 3 px circle; the stare strip is a 20 px band on a 60 px
   floor; the thought bubble is 75×65 px on the phone with a 5 px ring.

---

## 2. HUD declutter

### 2.1 Always on: four pieces (MUST be ≤ 4)

| # | Piece | Hit rect (top-left, size) | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Pause** | (S+24, T+24) 144×144 | 96 px disc, navy `#1B2340` at 62 % alpha, white bars 44 px | Opens the pause panel (§2.3). Android back / iOS edge swipe does the same. |
| 2 | **Script chip** | (S+192, T+24) 312×144 | 312×96 pill (same navy 62 %) at y T+48: playbill icon 40×52, **one 34 px pip per required line** (gold filled = done, white ring = open), one 14 px dot per optional line, a 32 px star for the Big Number (grey sealed → gold unsealed) | Tap = Script panel (pauses). When a line lands, the prank's red beret tag flies from the prop to its pip (0.6 s) and the pip fills with a pop. The pill grows with the Script (112 + 46 per required line + 22 per optional line + 50 px, ≤ 440 px). |
| 3 | **Clarence / ⏩** | (S+32, H−B−200) 168×168 | 128 px disc, navy 62 %, Clarence in colour | Tap = SQUEAK, hold = WHEEZE, ⏩ while hidden (GDD §3.3, unchanged). The lure ring (8 px) shows only when lure fatigue is close (≥ 1 lure in the last 60 s); grey when fatigued. |
| 4 | **Action button** | centre (W−S−168, H−B−168), 240 circle | 190 px disc | Two visual states (§2.4): **QUIET** (FREEZE with no danger: navy 62 %, white statue icon 84 px, no ring) and **LIVE** (any verb that is the right move now: full colour, 1.08× pop, icon 96 px, ring 14 px). Verbs, latch, hysteresis, queue: GDD §3.2 unchanged. |

Clarence centre (S+116) to action centre (W−S−168) = W − 2S − 284 ≥ 1,300 px for S ≤ 168 (GDD two-thumb rule holds).
Left-handed mode mirrors every rect horizontally (x' = W − x − w) except the centred meter.

### 2.2 Contextual and transient (shown only when meaningful)

| Piece | When it shows | Where / size | Replaces today's |
|---|---|---|---|
| **Applause meter** | 2.5 s after any Applause change (count-up 0.6 s, stamp beside it); stays while a Running Gag is live | centred, (W/2−230, T+24) 460×104 pill: dial 72, "APPLAUSE" 36 px, number 60 px, delta "+35" 56 px outside the pill | the permanent 600×144 brass meter |
| **Running Gag fuse** | while the Running Gag is live | under the meter: "RUNNING GAG ×1.5" 44 px + fuse bar 420×18 at y T+144 | the separate banner |
| **Bellows window** (PiP) | Bellows off-screen **and** `SimVisibility.pip_shows` (adjacent room, heading to Hush's room, or she is rigging); never while he is on screen; hides 1.5 s after | top-right, (W−S−424, T+24) 400×225 + 6 px frame coloured by temper tier; his next-activity chip (72 px, with the bubble's ring) in its lower-left corner. Escalates to 704×396 in the same corner for an off-screen payoff (GDD §3.7). Tap = peek. | the 448×252 always-visible Bellows-Cam |
| **Edge badge** | Bellows off-screen and no Bellows window (≥ 2 rooms away, not heading here) | left or right edge zone, x S+24…S+160 / W−S−160…W−S−24, y 430–650: his 112 px face, an arrow, the next-activity icon 64 px; plays emotes for edge micro-gags (D1 rule 2 unchanged) | edge bubble (kept, moved) |
| **Carried items** | only while Hush carries something | chips 128 visual / 144 hit at (S+224 + i·168, H−B−188), max 4, right of Clarence | the always-visible 4-slot tray |
| **Figgis** | a nudge (40 s without progress), a card cue, or "Hint" from the pause panel; auto-hides after 4 s | bust 128 px at (S+24, T+192), card 320×200 to its right; obeys §2.5 | the permanent Figgis chip |
| **BOW** | after ★ (every required line) | (W−S−344, T+273) 320×112, "Take a Bow ▶"; slides under the Bellows window when that is open; the front door glows cream | pause-menu-only bow |
| **Pick strip** | a container with 2–4 useful items (not in the slice) | above the container (GDD §3.6 sizes) | unchanged |
| **The Stalls** | on audience events only: laughs (rise 60–150 px by tier), gasp, shush, "BEHIND YOU!", chants, boos | bottom band x ∈ [S+560, W−S−440] on canvas layer 9 (under the HUD, so item chips 3–4 stay on top), never a target; **hidden at rest** (the laugh track keeps them present by ear) | the 40 px resting row |
| **Overview** | hidden in Act I (one floor, ≤ 4 rooms); pinch-out still works; "Map" in the pause panel; from Night 3 a 144 px button appears only while Bellows is on the other floor | (W−S−168, T+300) when shown | the permanent overview button |
| **Tomatoes** | on a catch (Night 4+): three 44 px tomatoes in the transient meter for 2.5 s | inside the meter | inside the permanent meter |

**Removed from the play screen:** empty tray slots, the idle Figgis chip, the permanent meter and banner, the overview
button in Act I, the footlight sprites (the footlights become a warm light gradient, §5.3), the resting Stalls row.

### 2.3 What moves into the pause and Script panels
- **Pause panel** (pauses): Resume · Retry · Take a Bow (after ★) · **Hint** (Figgis steps 2–3) · **Map** (the Overview
  of tonight's set, tap a room to peek) · Settings · Playbill. Header: Applause total, tomatoes, Curtain Calls so far.
- **Script panel** (tap the chip or the meter; pauses): every line with its ribbon/candle, "???" lines, the sealed Big
  Number, **his routine strip** with rigged stations stamped with the red beret (GDD §4.2), and the loading-card rule
  of tonight as a one-line reminder.

### 2.4 The action button's two states (one-verb rule for the HUD)
- **QUIET:** FREEZE while nothing threatens Hush (he is not in her room, or she is hidden). It stays pressable (GDD
  §3.2: FREEZE is persistent) but doesn't shout.
- **LIVE:** RIG (item icon → target icon, gold `#F2B632`), RIG_DIM (the missing item's silhouette, grey, taps show where
  it is), POP OUT / GO ▶ (the green/amber/red danger rim, GDD §3.2), and **FREEZE when it matters**: stone-white face
  with an amber rim while he is in her room and she is exposed, pulsing 3 Hz red-amber while a "?" fills on her.
  Hysteresis ≥ 250 ms and the 120 ms cross-fade apply to state changes too.
- While held, the ring (14 px) fills on the button **and** at the prop (§4.1).

### 2.5 Hints never cover the action (binding placement rules)
- **Protected rects** (recomputed every frame, in screen space): Hush's projected bounding box + 48 px; Bellows' + 48 px;
  his thought bubble; the prop Hush is at (projected rect + its preview); the four always-on hit rects + 48 px; the
  Bellows window.
- **Placement priority:** Bellows' bubble (never moves except to clamp inside the safe area) > Hush's own thought
  cloud > danger markers (the safety-net hiding marker) > passive previews > container item bubbles > Figgis card >
  captions and stamps. A lower item that would overlap a higher one or a protected rect slides sideways (≤ one cloud
  width), then up (≤ 150 px), then waits. Passive previews may be covered by Hush's thought (they are faded then).
- **Danger is sacred:** during an entry warning, a "?" fill, a chase or a reaction, all hints and previews hide; the
  only teaching allowed is the safety-net hiding marker (`ghost_hide` and the Director safety net). Queued hints fire
  1.0 s after it is safe.
- **Hints point at the world, never at text:** a ghost finger on the spot (approaching from the side away from Hush),
  a spotlight pool on the floor in front of the spot (§4.4 N4), or Figgis's picture card; no arrows over characters.
- The middle band **y 250–880** holds no always-on or persistent HUD. Only world-anchored bubbles, previews and
  captions, and three short-lived contextual pieces that obey the protected rects (the edge badge in the outer 160 px,
  the Figgis card, the pick strip), may appear there.

### 2.6 Safe areas, sizes, text
- The HUD anchors to the safe-area corners (symmetric side inset `S = max(left, right)`), ≥ 24 px inside it; tablets
  (logical height > 1250 or 4:3) scale the HUD ×0.8 (`UiScale`, unchanged).
- The 3D view renders full-bleed, but the camera keeps Hush and every live prop of her room **inside the safe rect**
  (§5.2 rule C6): the punch-hole never covers a target.
- Hit sizes unchanged (≥ 144×144 world targets on screen, §5.5; HUD targets as §2.1). Text: ≥ 44 px during play, HUD
  numbers 48–60 px, captions 88–104 px Lilita One with a 6 px navy outline (GDD §3.10).
- Board: `redesign/hud_layout.png` (20:9 and 16:9, gold = always on, dashed = contextual).

---

## 3. House simplification

### 3.1 Rooms per Night (slice)
| Night | Built and lit | Built dark ("backstage") | Not built at all |
|---|---|---|---|
| Prologue | parlour, kitchen | hall (architecture only, stage light 0.3, velvet rope at the doorway; Bellows' mirror detour is seen in the Bellows window) | porch, upstairs, conservatory, garden |
| Gate 0 | parlour, kitchen | hall | as above |
| Night 1, Night 2 | porch, hall, parlour, kitchen | — | upstairs, conservatory, garden (the back door is a closed door) |

**On screen at a time:** one room is framed (§5.2); at 20:9 at most 1.7 m of each neighbour shows, dimmed (§5.3); at
16:9 at most 0.8 m. **One floor at a time:** the upper floor is never visible in Act I; from Night 3 the camera
cranes between floors and the other floor is not visible except in the Bellows window or the Map (GDD §3.7's "his legs
on the floor above" gag is dropped).

### 3.2 Three set layers
1. **Architecture** — every Night: walls, floor, the stage lip, wing flats (room dividers, §5.1), doors, windows, the
   stairs, built-in units (kitchen counters and sink unit, fireplace and mantel). Low contrast, no outline, no glow.
2. **Furniture / stations** — built only in the Nights that use them.
3. **Props** — small interactives and cue props — built only in the Nights that use them.

**The strike rule (binding):** a furniture piece or prop is on stage in a Night **only if** that Night uses it: a
station of an activity or detour in its loop (fix-ups after overrides included), a rig point of one of its pranks, a
container holding one of its items, a listed hiding spot (§6.2 C1), a reaction landing or knock-on target of one of
its pranks, a Director cue prop, a quake prop of a room where a Meltdown can happen tonight, or the entry/doorstep.
Everything else is **struck** (not instanced). The view derives the set list (`SetList.for_episode`) from content;
nobody hand-writes it.

### 3.3 Density limits (MUST, checked by the new set lint, §6.3)
- **≤ 5 live props per room per Night** (rig points with a prank tonight + containers with an item tonight + listed
  hiding spots; doors, exits and stairs are architecture and don't count). Target 2–4.
- **≤ 4 set-dressing pieces per room** (non-interactive, not functional: a window, a portrait, a lamp, a rail).
- **One hiding spot per room in Act I** (kitchen: pantry curtain; parlour: behind the piano; hall: coat cupboard).
- **No two live props stacked** in the same Night unless their projected rects keep ≥ 24 px between them (the slice
  keeps exactly two such pairs: kettle over-under honey in Night 1, the fridge's shelf over its door in Night 2).
- **Negative space:** each room keeps one 1.5 m-wide stretch of the lane with nothing behind it at head height (the
  "stage space" where the two characters act); in the Night-1 kitchen that is x 3,180–3,540 (the fridge and table are
  struck).

### 3.4 Slice rooms: every hotspot kept, merged or struck
Live = interactive tonight · Furn. = on stage as furniture/station (no glow, no preview) · — = struck (not built).
Content ids are unchanged; `house.json` keeps every hotspot for later Nights.

**Kitchen** (x 2,800–3,900)
| Hotspot (kind) | Uses | Prologue | Night 1 | Night 2 | Decision |
|---|---|---|---|---|---|
| `kitchen_honey` (rig) | ACHOO-RIA! | **Live** | **Live** | — | keep; honey jar + oversized pepper pot on the shelf above the kettle |
| `kitchen_kettle` (rig) | KETTLE DRUM | Furn. (tea station) | **Live** | — | keep; stacked under the honey (27 px gap on screen, §3.3) |
| `kitchen_pickle_jar` (rig) | IN A PICKLE | — | **Live** | — | keep |
| `kitchen_sink_tap` (rig) | TAP DANCE; SINK fix-up | Furn. (sneeze landing) | **Live** | Furn. (STICKY → SINK) | keep |
| `kitchen_fridge_shelf` (rig) + `kitchen_fridge` (container) | COLD OPEN; kipper | — | — | **Live** (both) | **merge** into one fridge prop with two zones: upper shelf = rig, lower door = take |
| `kitchen_pantry_curtain` (hiding) | Prologue lesson, safety net | **Live** | **Live** | **Live** | keep: *the* kitchen hiding spot |
| `kitchen_table` (hiding) | N1 routes | — | **struck** (removed from Night 1's hides, §6.2 C2) | — | cut from the slice (no reaction lands on it in the slice) |
| `kitchen_pantry_shelf` (container) | flour, sherbet, treacle, salt (Night 4+) | shelves drawn inside the pantry alcove, dormant | dormant | dormant | dormant (not live) until a Night needs its items |
| `kitchen_window` (entry) | climb-in | architecture | architecture | architecture | keep (not tappable, as today) |
| `kitchen_back_door` (door) | to the conservatory (Night 5+) | closed | closed | closed | architecture, not tappable in Act I |
| dressing | — | window, pendant lamp | window, pendant lamp, pan rail (kitchen quake prop) | window, pendant lamp, pan rail | plates, spice jars, wall clock, tiles, fruit bowl, plant, magnet/note: **cut** |
| **Live count** | | **2** | **5** | **3** | |

**Parlour** (x 1,500–2,800)
| Hotspot (kind) | Uses | Prologue | Night 1 | Night 2 | Decision |
|---|---|---|---|---|---|
| `parlour_gramophone` (rig) | ALLEGRO-GO-GO! | **Live** | Furn. (warmup) | — | keep |
| `parlour_piano_back` (hiding) | hunt, routes | **Live** | **Live** | **Live** | keep: *the* parlour hiding spot |
| `parlour_piano_wedge` (rig) | GRAND EXIT (Night 6) | dormant (part of the piano) | dormant | dormant | dormant |
| `parlour_recliner` (rig) | LIFT-OFF | — | **Live** | Furn. (paper station) | keep |
| `parlour_newspaper` (rig) | EYE-POPPING NEWS | — | Furn. (the paper he reads) | **Live** | keep; the folded paper lies on the recliner's arm (never live with the recliner in the same Night) |
| `parlour_chandelier` (rig) | PRIMA BALLERINA (Night 4) | — | Furn. (LIFT-OFF landing) | — | dormant; built only where a reaction needs it |
| `parlour_bellows` (rig) | BELLOWS BLOWS (Night 4/8) | part of the fireplace | part of the fireplace (DRY station, override) | part of the fireplace (fire station) | dormant |
| `parlour_chaise_back` (hiding) | N1 chase route | — | **struck** (§6.2 C2) | — | cut from the slice |
| `parlour_tea_tray`, `parlour_fan` (rig) | Act III | — | — | — | struck until Night 8 |
| dressing | — | window, vase (`laugh_vase`), picture frame (`laugh_picture`), portrait | window, portrait (quake prop), log basket (landing) | window, portrait | wallpaper pattern, rug, side table, candles, sheet-music frame: **cut** |
| **Live count** | | **2** | **2** | **2** | |

**Hall** (x 500–1,500)
| Hotspot (kind) | Uses | Prologue | Night 1 | Night 2 | Decision |
|---|---|---|---|---|---|
| `hall_confiscated_box` (container) | squeaker (N1), magnifier (N2) | backstage | **Live** | **Live** | keep; big crate with the red CONFISCATED band |
| `hall_coat_cupboard` (hiding) | routes | backstage | **Live** | **Live** | keep: *the* hall hiding spot |
| `hall_phone` (rig) | SOMETHING FISHY | — | — | **Live** | keep (phone table = furniture) |
| `hall_clock` (rig) | TIME'S UP | — | — | **Live** | keep |
| `hall_clock_case` (hiding, in use at `clock`) | N2 face-to-face scenario routes | — | — | **struck** (§6.2 C2) | the "in use next" lesson moves to Night 3 (wardrobe / bath) |
| `hall_mirror` (rig, signature) | MIRROR, MIRROR; MIRROR fix-up | backstage (FRAZZLED fix-up, seen in the Bellows window) | Furn. (fix-up station) | **Live** | keep |
| `hall_front_door` (exit) | Take a Bow; RUG BURN exit | — | architecture; glows cream after ★ | same | keep |
| `stairs_foot` (stairs), `stairs_rods` (rig, Night 4+) | upstairs from Night 3 | Bellows' exit only | roped off, not tappable | roped off | architecture (three steps into the dark + a velvet rope) |
| `hall_piggy_bank` (container) | coins (Night 5) | — | — | — | struck until Night 5 |
| dressing | — | — | coat stand with hats (hall quake prop), one window | coat stand (MIRROR, MIRROR landing), one window | wall pictures, pendant lamp, balloon, stair clutter: **cut** |
| **Live count** | | 0 (backstage) | **2** | **5** | |

**Porch** (x 0–500): architecture only — the doorstep (a caught Hush lands here), a step, the hedge (Night 4 landing),
No. 9's door silhouette.

### 3.5 Set-dressing rules
- **Few:** ≤ 4 per room (§3.3). **Big:** each ≥ 0.5 m in its longest side (≥ 110 px on screen) — no clutter of small
  things. **Low contrast:** chroma C* ≤ 30 and |ΔL*| ≤ 15 against the wall behind it; **no outline, no glow, no
  preview, never tappable**. **Out of the way:** never in the acting lane (z > −1.6, §5.1) above 0.45 m, never in the
  0.6 m band above a live prop (where its preview sits).
- **Walls are fields, not patterns:** one flat colour per room + one wainscot band 9 L* darker + one picture rail; no
  wallpaper motifs, tiles or panel mouldings. Floors: plain boards, two tones.
- **Quake props** (GDD §4.5) count as dressing and hang high (≥ 2.2 m) or sit on the mantel.

### 3.6 Silhouettes (every live prop reads as a black shape at 64 px)
Honey jar = squat cylinder + red lid + tall pepper pot beside it · kettle = round body, spout, arched handle ·
pickle jar = tall glass cylinder with a gold lid and white onions · sink tap = a tall chrome gooseneck with a blue
knob · fridge = tall rounded box with a chrome bar handle · pantry = dark arched alcove with a gathered curtain ·
gramophone = a big horn · recliner = a fat armchair leaning back · newspaper = a folded broadsheet with a magnifier
handle once armed · piano = a black upright block · CONFISCATED box = a crate with a red band · phone = a candlestick
telephone · mirror = an oval on a stand · clock = a tall case with a round face · coat cupboard = a tall wardrobe with
one door line. **No two live props in one room share a silhouette family** (the lint compares 64 px masks, §6.3).

### 3.7 Colour and value hierarchy (measured on the blockout; lint on every set render)
| Layer | Rule | Blockout value |
|---|---|---|
| Walls (lit room) | L* 62–76, C* ≤ 28; wainscot 8–10 L* darker | kitchen wall L* 73 C* 26; wainscot 64 |
| Walls (dimmed room, §5.3) | L* 45–58, C* ≤ 15 | parlour L* 50 C* 9 |
| Floor | L* 40–50 | 44 |
| Dressing | C* ≤ 30, |ΔL*| ≤ 15 vs its wall, no outline | stool L* 53, lamp shade 89 (the one light-valued dressing, the light source) |
| **Live props** | C* ≥ 45 **or** a verb halo (metal/wood props); 2.5 px ink outline; verb glow pulse 0.6↔1.0 at 1.2 Hz while Hush is in the room | honey C* 72, pickle jar 49, curtain 64, chrome tap 10 + halo |
| **Characters** | each has ≥ 20 % of its silhouette at L* ≥ 85 **and** ≥ 20 % at L* ≤ 40; 3.5 px outline; rim light | Hush face 96 / costume 22; Bellows bouffant 91, face 81 / jacket 35 |
| **Verb colours** (halo, glow, previews) | rig = gold `#FFC838`, hide = blue `#5C9EFF`, take = cream `#FFF4DB`, exit = cream after ★ | — |
| **The active prank spot** | the prop Hush is at, or an armed prop whose trigger is his next activity: glow pulse 2× amplitude | — |

Characters are the only things with both the extremes of the value range and a rim light; live props are the only
saturated things with an outline; everything else is a mid-value, low-chroma field. Boards:
`redesign/before_after_n01.png`, `mock_n1_kitchen_plan.png`, `mock_n2_hall_plan.png`.

---

## 4. Action readability

### 4.1 The four moments of every action
- **BEFORE — what this will do:** a preview of the *joke* (not the instruction) in the world, at the spot.
- **DURING — what Hush is doing:** an exaggerated, prop-specific pose readable in silhouette at 64 px, the prop
  changing as she works, and one progress indicator **at the prop** (echoed on the button).
- **AFTER — it's armed:** the prop visibly changed + Hush's calling card, the **red beret tag** (a 0.28 m 3D beret on a
  string, ≈ 65 px on screen), hung on the prop; Hush snickers at the audience (40 f, interruptible).
- **TRIGGER — he walks into it:** anticipation (the tag wiggles, the suspense stem, the camera finds the two-shot), the
  accent (punch-in, hit-stop, caption, laugh), then the prop shows **spent** (glow off, the tag flies to the Script
  chip's pip, §2.1).

World overlays used (all 2D, anchored to 3D points, §5.8): **passive preview** — a 112×90 cloud with a 78 px pictogram
at 80 % strength above each available rig point in Hush's room; **Hush's thought** — a 180×144 cloud with a 124 px
pictogram at her head, on the side away from the prop, when she stands at a rig point (she imagines the payoff);
**needs cloud** — the passive preview with the missing item's grey silhouette (after she has seen its container);
**item bubble** — a 116 px cream disc with the item icon above a container that holds tonight's item; **rig ring** —
radius 118 px, 14 px stroke, yellow `#F2D23A` → green `#5CCF6A`, on an 18 px 35 % black track, centred on the prop.

### 4.2 Verbs

| Verb | BEFORE | DURING (pose, time, feedback) | AFTER |
|---|---|---|---|
| **Move — tiptoe** (tap floor/spot) | live props glow in their verb colour; the tapped spot pops | ripple ≤ 16 ms, a 0.5 m white destination ring + dotted path decals on the floor; **cartoon sneak**: knees high, elbows up, gloves like paws, body leaning 15°, 2.2 steps/s; pizzicato steps | arrival settle (one small hop, 8 f); the ring pops |
| **Run** (second tap) | — | lean 25°, arms pumping, dust puff each step; a **white noise ring decal to its true radius (2.5 m)** every 0.5 s so the player sees how far it carries | skid stop (6 f) |
| **Pick up** (tap a container) | item bubble over the container (tonight's item icon); a grey needs cloud on the rig point that wants it | she opens the container (door swing / lid up, 0.2 s), dives in to the waist, legs kicking (0.6 s rummage) | **"item get"**: she pops out holding the item over her head at 1.6× scale (0.4 s, sparkle; view-only, cut short by the next command), tucks it in her braces (the item stays visible on her model), and its chip flies to the HUD beside Clarence; the needs cloud turns into a full preview |
| **Rig** (hold at a rig point) | Hush's thought shows the joke; every other preview fades to 30 %; the action button goes LIVE (item → target) | a **prop-specific action** built from one of three reach bands (high / mid / low) × the prep tier (Q 0.8 / S 1.5 / B 2.5 s) + the prop's own animation (§4.3); she **glances left and right** at 30 % and 70 % of S/B rigs; B rigs emit a noise ring every 0.5 s; the rig ring fills at the prop and on the button; release keeps progress (the ring stays partial at the prop) | the armed look + red beret tag; ding + 3 pizzicato notes; titter; snicker glance at the audience; all previews in the room return |
| **Hide** (tap a hiding spot) | blue halo pulse; in danger the nearest free spot shows the safety-net marker (a white disc with a blue closed eye, 88 px) | a big cartoon leap in an arc (0.25 s dive) with a whoosh smear; the cloth or door swings shut and wobbles (0.4 s) | only her eyes blink in the dark gap (3D eye card inside the prop) and track him; the cloth breathes; the world desaturates 20 % with a soft vignette = "safe"; Clarence becomes ⏩; the action button shows POP OUT with the danger rim |
| **Freeze** (hold) | QUIET button; turns LIVE with an amber rim when he is in her room and she is exposed, pulsing red-amber while a "?" fills | she snaps into one of 8 statue poses and **turns to marble** (every part desaturated to stone white, the ink outline kept) **except her eyes, beret and braces** (the player never loses her), a stone plinth pops up under her feet (0.1 s), woodblock clack; the stare strip shows whether she is inside his frozen range (the darker inner segment) | release: colour returns with a shiver (0.15 s); a pin tapped while frozen shows as a floor pin |
| **Squeak** (tap Clarence) | ear pips (24 px, up to 3) under his bubble show what he has heard | Hush whips Clarence out and squeezes him (0.3 s; Clarence squashes, his comb flares), a **yellow ring decal expands to the true hearing reach** (her room and every open doorway) | his reaction: squeak bit / head turn / lure (his bubble changes the same tick) |
| **Pop out / GO ▶** (tap while hidden) | the danger rim (green / amber / red) and, if set, a floor pin | she bursts out (0.25 s) with the cloth flapping | walks (or runs on a double tap) to the pin |
| **Take a Bow** (after ★) | BOW chip; the front door glows cream; the Stalls chant when every line is done | she walks to the door and bows, roses fly | the curtain call |

**Bellows' actions are readable too:** every activity has a signature held prop (teacup, newspaper, pickle jar,
sponge, phone handset, comb, the gramophone needle) and pose; his bubble (200×170, icon 112, ring 12 px, awareness glyph
60 px, ear pips 3 × 24 px) always shows the **next** activity. When his next activity will trigger an available,
unarmed rig point in Hush's room, that spot's preview gets **his ring** (the same red countdown ring as his bubble):
*"he's coming for this next."*

### 4.3 The slice pranks

Punch-in by size (a dolly toward his head and chest, §5.2 C7): S 1.15, M 1.4, L 1.3, signature and chain finale 1.6.
The first time a prank fires in a Night its last 0.4 s of approach plays at 0.5× (GDD §9.3, unchanged).

| Prank (id, rig point, prep) | BEFORE — preview pictogram | DURING — Hush's action | AFTER — armed look | TRIGGER — anticipation → payoff |
|---|---|---|---|---|
| **ACHOO-RIA!** (`achoo_ria`, `kitchen_honey`, Q) | a nose + a star burst | reach-high: she lifts the oversized pepper pot over the open jar and shakes three big shakes; pepper falls in a stream | pepper speckles on the honey rim, the lid askew, a tiny pepper puff every 2 s; tag on the jar | tea: he spoons honey (the jar lid flips), sips; a slow push to 1.15 during "ah… ahh… AHHH…"; CHOO: 1.4, 5 f hit-stop, he rockets backwards on the stool into the sink; ACHOO-RIA! caption; Stalls rise |
| **ALLEGRO-GO-GO!** (`allegro_go_go`, `parlour_gramophone`, Q) | a record with "×3" and a spiral | reach-mid: both gloves on the big red-knobbed speed lever, a lean-back yank | lever in the red ×3 zone, a red "×3" sticker on the label; tag on the horn | warmup: he drops the needle; screech; chipmunk babble; he spins like a top (the 3D spin reads) and collapses dizzy under orbiting notes; 1.4 on the collapse |
| **KETTLE DRUM** (`kettle_drum`, `kitchen_kettle`, Q, squeaker) | kettle + music notes + a red crack; without the squeaker: the needs cloud with its grey silhouette | reach-mid: lid off, thumb the squeaker into the spout, lid back | the squeaker's yellow tail pokes out of the spout; tag on the handle | tea @3 s: the kettle whistles a tune, he harmonises, cracks, the lid pops onto his nose; he pours anyway (resume); 1.4 |
| **TAP DANCE** (`tap_dance`, `kitchen_sink_tap`, Q) | tap → water jet → face | reach-mid: a big two-handed twist that swaps the tap head for a spray rose | a blue spray rose on the tap, dripping; tag | rinse @1 s: face blast, he wrestles the hose like a python; SOAKED drips; 1.15 |
| **HOT & COLD** (double act: ACHOO-RIA! → TAP DANCE) | when both are armed, the honey's preview gets a small "→ sink" badge (these two combine) | — | both tags | the sneeze flight ends in the sink, the spray fires inside the same reaction; the camera holds the punch through both accents (1.4 → 1.6 on the second), caption HOT & COLD! |
| **IN A PICKLE** (`in_a_pickle`, `kitchen_pickle_jar`, S) | a jar, a straining arm, flying onions | reach-high: three full-body cranks on the lid with knee bends, tongue out, a glance at 50 % | the lid visibly over-tightened with a spanner hanging off it; tag | pickles @1 s: he strains, purples, sideburns spring; POP, onions pinball, he slips and windmills down; 1.3; an onion stays on his head 20 s |
| **LIFT-OFF** (`lift_off`, `parlour_recliner`, B) | chair + spring + an up arrow to the chandelier | reach-low: she crawls half under the seat and cranks a big winding key (visible turns), noise rings every 0.5 s, glances at 30/60/90 % | a coiled spring bulging under the seat, the key sticking out; tag | paper @1 s: he pulls the lever — launch; the camera tilts up with him (pitch up to +10°) as his cravat snags the chandelier, he swings and drops into the log basket; 1.3; FRAZZLED → his bubble shows the mirror at once |
| **COLD OPEN** (`cold_open`, `kitchen_fridge_shelf`, S) | fridge + avalanche + jelly helmet | reach-mid: door open, she stacks three foods into a teetering tower, shuts the door with her back | the fridge door strains 1 cm ajar with a sausage poking out; tag on the handle | snack @1 s: door open → avalanche → jelly-mould helmet and sausage boa; 1.4; STICKY + COSTUME looks |
| **EYE-POPPING NEWS** (`eye_popping_news`, `parlour_newspaper`, Q, magnifier) | newspaper + magnifier + ballooned eyes | reach-mid: unfold, slide the magnifier behind the page, refold | the magnifier handle pokes out of the folded paper; tag | paper @2 s: he opens it, specs on: eyes balloon ×4 behind the lens; 1.4; then 15 s blind bumbling (glyph = blinded, the stare strip greys: a visible stealth window) |
| **SOMETHING FISHY** (`something_fishy`, `hall_phone`, Q, kipper) | phone + fish | reach-mid: lift the handset, lay the kipper in the cradle, pocket the handset | a kipper in the cradle, its tail flopping every 3 s; tag | phone @1 s: ring-ring; he answers pompously into the kipper; it slaps him twice; slow burn; 1.4 |
| **TIME'S UP** (`times_up`, `hall_clock`, S) | a clock + a zig-zag + "!" | reach-high: she opens the face and winds the key furiously (big cranks, hands spinning) | hands creeping on their own, the pendulum bobbing fast, a spring poking out; tag | clock @1 s: machine-gun chimes, he clings as the clock pogoes across the hall; the pendulum door smacks his bum; 1.4; FRAZZLED → mirror (the MIRROR, MIRROR link) |
| **MIRROR, MIRROR** (`mirror_mirror`, `hall_mirror`, B, signature) | an oval with Hush's face + a wink | reach-high: she lifts the pane out (noisy clinks every 0.5 s) and leans it behind the cupboard | the empty frame with **two footprint decals inside it** ("stand here and FREEZE"); tag | mirror @0.5 s: when he arrives, the button shows FREEZE LIVE with a mirror icon; three round pips over the frame; while held the icon reads WINK ("release = wink"); the camera yaws 8° into a face-to-face two-shot; release → scream by rounds survived, he flies into the coat stand which spins him; 1.6 |

### 4.4 "What am I doing / what can I do next" (binding rules)
- **W1** Hush's current verb is readable from her body alone at 64 px: sneak crouch, run lean, three reach bands,
  dive, statue, squeak, peek, bow. No two verbs share a silhouette.
- **W2** Every held verb has exactly one world progress indicator (the rig ring at the prop, the frozen stone look)
  and its echo on the button.
- **W3** A queued command (`cmd_queued`) shows a ghost ring at its target with a small chevron until it runs.
- **W4** Bellows' current activity is readable from his held prop and pose; his bubble shows the next one.
- **N1** Everything live in Hush's room glows in its verb colour; nothing else glows.
- **N2** Every available rig point in her room shows its preview; armed ones show the tag instead; spent ones show
  nothing.
- **N3** The action button's face is the verb available right here, right now.
- **N4** After 6 s without input (Figgis nudge at 40 s unchanged), the "next useful" spot (the hint ladder's choice,
  GDD §6.4) gets a **spotlight**: a soft warm pool on the floor in front of it and its preview at full size.

### 4.5 One verb per screen (binding)
At any moment the screen makes **one** loud call to action:
- **V1** at a rig point: the LIVE button + Hush's thought; other previews fade to 30 %;
- **V2** in danger (entry warning, "?" filling, chase): FREEZE LIVE if she is seen, else the nearest hiding spot's
  safety-net marker; every preview hides;
- **V3** hidden: POP OUT / GO ▶ with its rim; the world desaturates;
- **V4** otherwise nothing is loud: the passive previews are the menu.
- **V5** After an action completes, nothing new is suggested for 1.0 s (the consequence gets the screen).
- **V6** World overlays on screen at once: ≤ 6, of which ≤ 2 loud (full strength, ≥ 150 px).

Boards: `mock_n1_kitchen_plan.png` (V4 + a live rig point), `mock_n1_kitchen_rigging.png` (V1 during a rig),
`mock_n1_kitchen_armed_entry.png` (V2: entry warning, three armed tags, the safety-net marker),
`mock_n1_kitchen_payoff.png` (the payoff), `mock_n2_hall_freeze.png` (FREEZE live, marble statue on its plinth,
the stare strip), `mock_n2_hall_plan.png` (five live props, an item bubble, the Bellows window).

---

## 5. 3D staging

### 5.1 The stage in depth (z toward the camera)
| z (m) | Band | What lives there |
|---|---|---|
| +0.25 | stage lip | a thin gilded edge; below it the dark apron where the Stalls rise |
| 0 … −0.4 | apron band | nothing stands here |
| −0.4 … −1.6 | **acting lane** | characters walk at **z −1.0**; Bellows stands at z −1.4 at his stations; Hush steps to z −1.5 to reach a prop (0.2 s ease, view only); floor decals (stare strip z −1.5…−0.5, footprints, rings, pins) |
| −1.6 … −2.4 | **set band** | furniture, props, hiding spots |
| −2.4 | back wall | a flat colour field |

- **Wing flats** divide rooms: a partition at each room boundary x, from the back wall to z −1.4 (1.0 m deep, 0.22 m
  thick, cream `#E9DCC4`, no outline), so the front of the lane is open between rooms — the doorway is implicit and a
  character is never hidden behind a door frame. Doors that really close (front door, back door) are full-depth flats
  with the door leaf in the lane.
- No side walls except at the ends of the built set; no ceiling surface — a dark **proscenium header** band
  (`#1D1728`, 0.8 m, with a thin gold edge at 3.13 m) closes the top of every frame, and the top HUD row sits on it.
- Characters **cheat out**: the sim's facing is ±x; the view yaws the body 35° toward the camera while idle or
  performing, 20° while walking, 0–10° in face-to-face beats, per clip in reactions. Props are yawed 10–20° toward the
  camera when their front is the readable side.

### 5.2 Camera (Camera3D, perspective, `KEEP_HEIGHT`)
- **Base framing (binding numbers):** vertical FOV **30°**; the camera **7.5 m** in front of the lane (z +6.5) at
  **y 1.9 m**, aimed at y 1.35 m on the lane → pitch **−4.2°**; near 0.5 m, far 60 m. Measured on the blockout:
  visible height at the lane 4.02 m; **1 m = 269 px** at the lane, **226 px** at the back wall (8.9 m), 322 px at the
  lip; visible width at the lane **8.93 m at 20:9, 7.15 m at 16:9, 5.36 m at 4:3**. The top ~90 px of the frame shows
  the proscenium header; the bottom ~100 px the lip and the dark apron. Board: `redesign/camera_section.png`.
- **C1 Room framing:** the camera frames Hush's room. If the room fits (width + 0.6 m ≤ visible width), the camera x is
  clamped to [x1 − V/2 + 0.3, x0 + V/2 − 0.3] (the whole room in view) and biased toward Hush's walk by her 12 %
  look-ahead; otherwise it follows her (40–45 % of the width, 12 % look-ahead) clamped to the room. Exponential
  smoothing τ 0.20 s (0.15 s running); crossing a doorway eases to the new room's framing over 0.45 s (never a cut).
- **C2 Edge clamp:** at most 0.3 m of unbuilt space shows past the Night's outermost built walls (the Night-1 kitchen
  frames at camera x 15.33 m at 20:9).
- **C3 Two-shot:** when Bellows is in Hush's room, or in a linked room within 3 m of the shared doorway, the camera
  may pull back to **≤ 1.15×** distance (8.63 m) and shift to hold both, Hush ≥ 20 % from either edge. (1.15× keeps the
  back wall ≤ 10.0 m away, so a 0.72 m hotspot still projects to ≥ 144 px — §5.5.)
- **C4 Hold offset:** while the action button is held, Hush stays at 40–55 % of the width (away from the thumb).
- **C5 Floors:** a floor change cranes the camera 3.5 m over 0.40 s; the other floor is never in frame.
- **C6 Safe rect:** Hush and the projected rects of every live prop in her room stay inside the safe rect; the
  camera shifts (within C1/C2) to guarantee it.
- **C7 Punch-ins (Gag-Cam):** a dolly along the view axis toward his head/chest to distance 7.5 / zoom (S 1.15 = 6.52 m,
  L 1.3 = 5.77 m, M 1.4 = 5.36 m, signature 1.6 = 4.69 m; never closer than 4.5 m), 0.18 s in, hold 1.2–2.0 s, 0.35 s
  out, plus a 3–6° yaw toward his face side for M/L/signature (8° for MIRROR, MIRROR's face-to-face); hit-stop and shake
  as GDD §3.7; input stays live; one punchline at a time. Off-screen payoffs escalate the Bellows window.
- **C8 Visibility contract (keeps the dead-air gate valid):** whenever `SimVisibility.beat_vis` says `room` or `pip`,
  the view MUST show Bellows — on screen or in the Bellows window. Whenever he is on screen, the Bellows window is closed.
- **Overview / Map:** a dolly back to 15 m (0.5×); from Night 3 also a crane to show both floors. Planning only; taps
  still resolve through tap-assist.
- **Reduce motion:** no shake, no yaw, punch-ins ≤ 1.15×, 0.25 s linear moves.
- Peek (tap the Bellows window / edge badge): the camera flies to him in 0.35 s, holds 1.8 s, returns (GDD).

### 5.3 Lighting (readable at phone brightness)
- **One key**, a directional "stage key" from the upper left front (direction of travel (0.45, −0.75, −0.48) normalised:
  ≈ 49° elevation, from the left of the camera), warm `#FFF4E0`: +28 % on the lit band, +8 % on a top band.
- **Flat fill** 0.66 (neutral-warm `#A8A4AE`): no surface falls below 66 % of its albedo, so nothing crushes to black
  at 30–50 % phone brightness.
- **Rim** on characters only: fresnel power 2.5, strength 0.35–0.55, cool `#BFE0FF` (Hush's navy costume separates from
  dark backgrounds; Bellows from warm walls).
- **Stage light per room** (a per-room material uniform, tweened 0.4 s): Hush's room 1.0; Bellows' room when it is not
  hers 0.9; other built rooms 0.78 with 40 % desaturation; backstage 0.3.
- **No real-time shadows.** Blob shadows under characters (ellipse r 0.34 m Hush, 0.45 m Bellows, 32 % alpha).
- **Practicals** (fire, lamps, windows) are emissive only; no extra light sources.
- **Footlights:** an additive warm gradient from the lip (12 % at z +0.25 fading to 0 by 1.2 m up); no sprites.
- The whole lighting model is **computed in the shader** (unshaded + a uniform key), so the Compatibility, Mobile and
  Forward+ renderers look identical and cost the same.

### 5.4 Toon shading and outlines
- **Shading:** two soft bands (band softness 0.08) + the top band; no specular, no PBR, no normal maps. Albedo comes
  from a shared **palette texture** (one 256² palette per room set, one per character) so each room is 1 material.
- **Outlines:** inverted hull, **constant screen width**: characters **3.5 px**, live props **2.5 px**, dressing and
  architecture **none**; ink `#1B2340`, lerped 50 % toward the room colour in a dimmed room. Hard-edged meshes carry
  smoothed outline normals baked into a vertex attribute (box props otherwise split at the corners).
- **Verb halo** on live props (§3.7): a second shell 8 px wide in the verb colour behind the ink outline, pulsing
  0.6↔1.0 at 1.2 Hz. It MUST stay visible against the back wall: use the stencil (the prop writes ref 1, the halo draws
  where ≠ 1, depth-tested only against characters) or, as the fallback, a fresnel verb glow inside the prop's own
  shader. (The blockout shows why: a plain hull behind a wall-mounted prop is clipped by the wall.)
- Note for implementers: Godot 4.7's Compatibility renderer uses reverse-Z; depth offsets in clip space are
  `clip.z -= k * clip.w` to push *away* from the camera.

### 5.5 Scale and the sim → 3D mapping
- **1 m = 200 sim px** (sim sub-units: `x_m = x_sub / 12000`). Room x ranges and every `use_x`, station and rect in
  `house.json` map directly: kitchen 2,800–3,900 px = 14.0–19.5 m. Floors: floor `f` stands at **y = 3.5 f m** (the
  700 px pitch); a rect's y (negative up from the floor line) maps to `y_m = −y_px / 200`.
- The sim is 1-D per floor; the view owns depth: characters on the lane (z −1.0), Hush at z −1.5 while reaching, at the
  spot's z while hidden; props at their `house3d.json` z (§6.2 C4).
- **Characters:** Hush **1.60 m** (head 0.47 m, gloves 1.6× hand size ≈ 0.2 m), Bellows **1.78 m** to the top of the
  bouffant (barrel torso 0.85 m wide, legs 0.45 m). At the base framing: Hush **434 px (40 % of the height)**, Bellows
  **471 px (44 %)**; heads ≈ 127 px (Hush) and ≈ 120 px plus the bouffant (Bellows), inside GDD §9.2's 120–150 px;
  on a 1200×540 shot the figures are 217 / 236 px tall.
  Speeds in m/s: tiptoe 2.0, run 3.6, Bellows walk 1.2, chase 3.0 (GDD px/s ÷ 200).
- **Hit testing:** each hotspot rect becomes a 3D box (its x and y, z = the prop's z ± 0.3 m); its 8 corners are
  projected every frame and the screen bounding rect is what `TapAssist` sees (unchanged 90 px assist, priorities).
  At the base framing a 0.72 m (144 px) data rect projects to ≥ 163 px at the back wall; any framing used for play MUST
  keep the back wall ≤ 10 m from the camera (≥ 201 px/m).

### 5.6 The cast in 3D (readability constraints; the look is the look-devs')
- Toy proportions: heads ≈ 1/3.4 of the height, hands and feet oversized, simple forms that read at 64 px (Hush =
  beret + gloves + stripes; Bellows = a dandelion puff on a barrel).
- **Faces are 2D cards on 3D heads**: eyes, brows and mouth are texture swaps from a face atlas (the existing
  `faces.json` presets and the eye/brow/mouth vocabulary carry over; the SVG face parts can be rasterised into the atlas),
  pupils are small cards moved by look-at, blinks swap a lid frame. No blend shapes needed on the Compatibility renderer.
- Secondary motion on jiggle bones (Hush: beret, braces, Clarence, hair tips; Bellows: belly, bouffant ×3, sideburns
  ×2, cravat, coat tails ×2), computed in the view, never in the sim.
- Residues are attachment meshes and material swaps sharing bones (flipped/wet/frazzled bouffant, drips, flour tint,
  jelly helmet, sausage boa…); temper tints the skin by a material parameter (peach → beetroot, GDD §1.2).
- Budgets per character on a mid-range phone: ≤ 10k triangles, ≤ 50 deform bones + jiggle, 1 skinned mesh + ≤ 4
  attachments, 1 material + outline (≤ 4 draw calls), ≤ 0.25 ms CPU (skinning + jiggle).
- The Pip fallback stays a skin on Hush's skeleton (GDD §1.2).

### 5.7 Animation data
The existing clip model stays: `anim/<rig>/<clip>.json` keys, eases, **beats**, **events** and **marks**, and
`reactions.json` timings (the sim's reaction lengths do not change). Poses become bone rotations of the 3D skeleton;
the pipeline spike decides between authoring poses in JSON (sampled by a ported `RigSampler`) and baking glTF actions
with the same beats/events sidecar. Either way the animation lint's timing rules (accent ≤ 4 f, holds, one overshoot,
beats within 2 f of `reactions.json`) run on the 3D clips. Locomotion may be retargeted from CC0 libraries (candidates:
the Quaternius animation library and Kenney kits, both published as CC0; the spike records each file's source URL and
licence in `art3d/CREDITS.md`).

### 5.8 What stays 2D
The HUD and every panel; captions (88–104 px), stamps, the meter; Bellows' bubble, glyph, ear pips and "?" meter; the
previews, needs clouds, item bubbles and the rig ring; the ghost finger and spotlight labels; Figgis (a flat bust — a
pre-rendered sprite of the chosen 3D style once it exists); the Stalls silhouettes; the red Boot curtain (GDD §2.3 Boot
rule: the first frame stays a pre-rasterised 2D curtain); the Busted Cam frame and "SPOTTED!"; the Gag Reel frame.
All world-anchored 2D items are placed with `Camera3D.unproject_position` every frame and obey §2.5.
**In 3D:** the set, props, characters, the red beret tags, hidden eyes inside hiding spots, and the floor decals (stare
strip, footprints, noise and squeak rings, destination ring, pins, spotlight pool, blob shadows).

---

## 6. Impact on the build

### 6.1 Modules
**Kept as they are:** `game/sim/**` (except C1 below), `game/solver/**`, `game/data/**` (except §6.2), `game/audio/**`,
`tools/audio/**`, `autoload/{content,settings,save,haptics,router,audio,dev_shot}.gd`, `ui/input/{input_router,
tap_assist,gesture_config}.gd` (TapAssist now receives projected rects), `ui/theme/**`, `view/sim_driver.gd`,
`view/camera/juice_clock.gd`, **`view/world/view_snapshot.gd` (the seam)**, `view/world/moment_recorder.gd`,
`view/haptics_director.gd`, `view/sandbox/fake_world.gd`, `scenes/boot/**`, `scenes/night/{night_args,cmd_replay,
why_missed,to_be_continued,night_curtain}.gd`, `scenes/debug/**`, the solver/fuzz/lint tools and CI.

**Adapted:** `ui/hud.gd`, `ui/hud_layout.gd`, `ui/hud_model.gd` (4 always-on pieces, contextual rules, `verb_live`,
preview list); `ui/widgets/{action_button,clarence_button,tray,applause_meter,running_gag_banner,figgis_chip,pip_frame,
edge_bubble}.gd`; `ui/panels/{pause_menu,script_panel}.gd` (Hint, Map, routine strip); `view/camera/camera_director.gd`
→ `CameraDirector3D` (same public API as TECH §5.5 on a Camera3D); `view/camera/gag_stager.gd` (3D focus points,
dolly punch-ins); `view/pip/pip_view.gd` (SubViewport sharing the World3D, 400×225); `view/audio_director.gd` (pan by
projected x); `view/fx/*` split into 3D decals (`stare_strip`, `footprints`, `noise_rings`, `ripple`, `falling_props`)
and 2D overlays (`caption`, `stamp`, `thought_bubble`, `badges` → previews and tags, `spot_meter`, `busted_cam`,
`freeze_frame`, `wipe`, `entry_warning`); `view/world/{world_view,character_view,clip_map,clip_rules,slice_clips,
cue_stager,caught_stager}.gd` (3D targets, same ClipMap contract); `view/stalls/stalls_view.gd` (hidden at rest);
`scenes/night/{night_scene,hud_presenter,night_input,night_warm,night_warmer,curtain_call,curtain_apron,
cue_fallback}.gd`; `scenes/results/gag_reel.gd` (3D replay in a SubViewport); `scenes/stage_door/cast.gd`;
`tools/anim/{sheet,lint_anim,capture}` (3D contact sheets; the GIF tooling is unchanged).

**Replaced:** `view/rig/**` (2D cutout FK player, springs, line limbs, face layer) → a 3D character player (skeleton,
jiggle bones, face cards, attachments); `view/tex/**` for characters and rooms (HiResTex stays for UI icons);
`view/world/{room_view,prop_view,house_art,decor_set,house_layout,stage_view,hidden_eyes,fallback_puppet}.gd` →
`House3D` (builds architecture, furniture and props from `house.json` + `house3d.json` + `SetList`); `art/chars/**`,
`art/house/**` SVGs → `art3d/**` (glTF + palette textures); `data/rigs/**` 2D rigs → 3D rig descriptors (bone map,
jiggle, face atlas, attachments); the 2D clip poses → 3D poses (§5.7).

### 6.2 Content changes (all small; sim and solver stay valid)
- **C1 `hides` per episode** (new optional field): `p00_curtain_up` [`kitchen_pantry_curtain`, `parlour_piano_back`];
  `g0_sneeze` [`kitchen_pantry_curtain`]; `n01_throat_tea` and `n02_something_fishy` [`kitchen_pantry_curtain`,
  `parlour_piano_back`, `hall_coat_cupboard`]. Absent = every hiding spot of the Night's rooms (drafts unchanged).
  Sim: `SimCtx` builds a live-hotspot mask (rig point live iff a prank tonight uses it; container live iff it holds a
  tonight item; hiding spot live iff listed; doors/exits/stairs as today); `SimHush._cmd_go` and the hotspot pin reject
  a non-live hotspot with `cmd_rejected {why: "struck"}`; `hotspot_state().enabled` follows the mask. Validation: every
  listed id is a hiding hotspot in the Night's rooms; the Director's safety-net pulse and every solution `hide` step
  use a listed spot.
- **C2 Solution re-plans:** `solutions/n01_throat_tea.json` — every `kitchen_table` hide → `kitchen_pantry_curtain`
  (ideal, required, slow, caught, meltdown; +170 px ≈ +0.43 s of tiptoe per hide) and the chase route's
  `parlour_chaise_back` → `parlour_piano_back`; `solutions/n02_something_fishy.json` — the `face_to_face` and
  `face_to_face_lost` scenario routes are retired (the in-use hiding lesson moves to Night 3, re-authored when it goes
  final). Then re-run `solve.sh all`, the dead-air gate (GDD §2.4), fuzz and the content lint; expected impact is a few
  tenths of a second per hide on N1's routes, well inside the gate (N1 dead air 7.9 / 4.8 / 2.1 % today).
- **C3 No change to `house.json`** x positions, rects, stations or ids: the 3D view reads them as they are. Only the
  two slice stacks that stay live (kettle/honey, fridge/shelf) keep their current ≥ 24 px gaps.
- **C4 New view-owned data** (not read by the sim): `data/house/house3d.json` (per hotspot/decor/station: model, z,
  yaw, reach band, armed and spent variants, tag socket, preview anchor, silhouette family); `data/view/previews.json`
  (per prank: pictogram frames, needs-cloud item, "combines with" badge); `data/anim/hush3d/rig_actions.json` (per
  prank: reach band, action clip, prop animation, glance marks).
- **C5 Strings:** new UI strings for Hint, Map, BOW, "struck" feedback (none shown during play; icons first).

### 6.3 New checks
- **Set lint** (per Night): live props per room ≤ 5, dressing ≤ 4, one hiding spot per room in Act I, no live stack
  under 24 px on screen, silhouette families distinct (64 px masks), dressing C*/ΔL* limits on a rendered set shot.
- **Screen-rect lint:** every live hotspot of every final Night projected at the base framing (20:9, 16:9, 4:3) is
  ≥ 144×144 px, ≥ 24 px apart, inside the safe rect.
- **HUD lint:** ≤ 4 always-on pieces in every captured play frame; the middle band y 250–880 holds no always-on or
  persistent HUD rect (§2.5).
- **Visibility test:** replaying each solver route through the view, C8 holds on every tick (Bellows on screen or in
  the Bellows window whenever the sim says `room`/`pip`).
- **Perf:** the TECH §9 budgets restated for 3D — 60 fps p95, ≤ 150 draw calls p95, ≤ 150k triangles on screen,
  ≤ 8 particle emitters (CPUParticles3D), ≤ 250 MB textures, **no shader compiled during play** (every material is
  rendered once under the curtain, extending `night_warm`).

### 6.4 Staged plan to a new playable slice
| Stage | Contents | Exit check |
|---|---|---|
| **R0** (now) | this spec; the pipeline spike (glTF → Godot Compatibility on Android: skinned toon characters with outlines at 60 fps on a mid-range phone, shader warm-up, draw calls); three style look-devs; the owner board | the owner picks a style; the spike's perf numbers on device |
| **R1 — 3D greybox slice** | `House3D` from `house.json` + `SetList` with primitive stand-ins; `CameraDirector3D` (C1–C8); 3D decals; the decluttered HUD; previews, tags, rig rings; toy stand-ins like the blockout driven by the real sim through `ViewSnapshot`; C1/C2 content; Gate 0 and the Prologue playable end to end | **Owner check R1** on his phone: uncrowded? can he tell what Hush is doing and what each spot will do? (before any character art money is spent) |
| **R2 — cast in 3D** | final Hush and Bellows in the chosen style, face cards, jiggle, residue attachments, Hush's verb pose set and three reach bands, Bellows' locomotion, tea and warmup, the sneeze | **Gate 0 again, in 3D** ("Sneeze 3D"): the owner judges the sneeze and the cast |
| **R3 — slice sets and clips** | kitchen, parlour, hall, porch final 3D per §3.4; all 11 slice pranks' armed/spent looks and rig actions; the 137 slice clips (`s2-view/slice_clips.md`) in 3D; Stalls, curtain call and Gag Reel over the 3D view | pre-gate green: solver, fuzz, dead-air gate, lints (incl. §6.3), mute test on 3D GIFs, perf on device |
| **R4 — Fun Gate (3D)** | the GDD §10.4 owner checks on his phone | pass → Stage 3 content |

### 6.5 Risks
| # | Risk | Mitigation |
|---|---|---|
| X1 | **3D performance** on a mid-range phone with the Compatibility renderer (skinning, outline passes double the draws, fill rate at 2400×1080) | budgets §5.6/§6.3; outlines only on characters and live props; one palette material per room; merged static meshes; MSAA 2× with an off switch; render scale 0.85 fallback; the R0 spike measures on device first |
| X2 | **Shader compile hitches** (no ubershaders in Compatibility) | warm every material under the curtain; the device log reports any compile during play as a failure |
| X3 | **Animation throughput** — 3D comedy animation is costlier than 2D FK JSON | keep the data-driven clip format, beats, events and lint; retarget CC0 locomotion; three reach bands × prop animations instead of bespoke rig clips; R1 validates readability with stand-ins before R3 volume |
| X4 | **Charm lost in 3D** (faces were the comedy) | 2D face cards keep the 2D expression vocabulary; the owner judges at R2 ("Sneeze 3D") before mass authoring |
| X5 | **The 1-D sim in a 3D space** (players expect depth moves) | the lane rule, wing flats, cheat-out and a shallow 2.4 m set make it read as a stage, not a room to explore |
| X6 | **Tap misreads** from perspective (props at different depths) | projected hit rects + the screen-rect lint; stacks kept only where ≥ 24 px apart |
| X7 | **Content churn** (hides, route re-plans) | C1/C2 are small and machine-checked; the gates re-run before R1's owner check |
| X8 | **Schedule:** the view, rig and art are rebuilt or adapted (`view/**` + `scenes/night/**` ≈ 27k lines, much of it adapted rather than rewritten, and all 820 SVG art files); sim, solver, UI logic and autoloads (≈ 25k lines), audio and content carry over | R1 reuses everything behind `ViewSnapshot`; fake-world sandbox shots from day one |
| X9 | **Licensing** | CC0/public-domain only; `art3d/CREDITS.md` records the source URL and licence of every third-party file |

### 6.6 GDD sections to amend (the lead folds these into GDD v1.2)
- **§0 Summary** — "Readable danger" row wording (Bellows window instead of PiP); the art line (3D).
- **§1.2 Cast** — sizes in metres and on-screen px (§5.5), silhouettes at 64 px, face cards; **§1.3** footlights as light.
- **§2.1** — the beat table's feedback column (rig ring at the prop, previews, tags).
- **§2.3 Prologue** — cue staging in 3D (ghost fingers on projected spots; `sparkle_lever` = the spotlight pool);
  no timing change.
- **§3.1** — tap targets are projected 3D rects; pinch/drag move the 3D camera within C1–C3 limits.
- **§3.2** — the action button's QUIET/LIVE states; the ring also at the prop.
- **§3.3** — Clarence moves to the bottom-left corner; the lure ring is contextual.
- **§3.4** — one hiding spot per room in Act I; `hides` per Night; the in-use lesson starts in Night 3.
- **§3.5** — badges replaced by verb glow/halo, previews, needs clouds, item bubbles and red beret tags.
- **§3.6** — the tray becomes carried-item chips shown only while carrying.
- **§3.7** — camera (§5.2 numbers), Bellows window 400×225 and its visibility contract, Overview hidden in Act I, the
  floor-above gag dropped.
- **§3.8** — the HUD layout table and diagram replaced by §2.
- **§3.9** — bubble 200×170 / icon 112 / ring 12 px / glyph 60 px; stare strip, footprints and rings as floor decals.
- **§3.11** — settings: Previews (Always / After 6 s idle / Off), Room dimming (On/Off), Outline +50 %.
- **§4.10 / §6.5** — the Stalls hidden at rest, rising on events.
- **§6.4** — step 1 nudge adds the spotlight pool.
- **§7.1** — world units (1 m = 200 px), the depth bands, set layers and the strike rule; locked rooms not built.
- **§7.2** — Prologue, Night 1, Night 2 rows: `hides`; Night 2 without the clock-case hiding spot.
- **§9.1–§9.4** — art direction, rigs and animation list in 3D (timing rules §9.3 unchanged).
- **§10.2–§10.5** — content budget (3D rigs), slice description, Fun Gate pre-checks (set/screen/HUD lints, 3D perf),
  risks X1–X9.
- TECH.md (for the lead): the header (2D → 3D view), §1 module map, §2 world units, §5 view contracts (camera,
  rig, world, FX, PiP), §9 budgets, §10.5 lints, §11 review tooling.

---

## Appendix A — numbers cheat-sheet
| Thing | Value |
|---|---|
| World scale | 1 m = 200 sim px; floor pitch 3.5 m; room height 3.2 m; set depth 2.4 m; lane z −1.0 |
| Camera | FOV 30° vertical, 7.5 m from the lane, y 1.9 m, pitch −4.2°, near 0.5, far 60 |
| Visible width at the lane | 8.93 m (20:9) · 7.15 m (16:9) · 5.36 m (4:3) |
| px per metre | 269 at the lane · 226 at the back wall · ≥ 201 required for play |
| Characters on screen | Hush 1.60 m = 434 px (40 %) · Bellows 1.78 m = 471 px (44 %) |
| Punch-in distance | S 6.52 · L 5.77 · M 5.36 · SIG 4.69 m (min 4.5) · two-shot ≤ 8.63 m |
| Outlines | characters 3.5 px · live props 2.5 px · dressing 0 · halo 8 px |
| Always-on HUD | pause 144 · Script chip 312×144 · Clarence 168 · action 240 |
| Contextual HUD | meter 460×104 · Bellows window 400×225 (escalated 704×396) · item chips 144 · BOW 320×112 |
| World overlays | bubble 200×170 · passive preview 112×90 · Hush's thought 180×144 · item bubble 116 · rig ring r 118 / 14 px · tag 0.28 m |
| Density | ≤ 5 live props / room / Night · ≤ 4 dressing · 1 hiding spot per room (Act I) · ≤ 6 world overlays, ≤ 2 loud |
