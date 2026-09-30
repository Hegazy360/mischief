# Mischief Next Door — Game Design Document (v1.2, BINDING)

*"A silent comedy for a very loud man."*

Status: final, binding design for v1. Built on the panel's winning proposal ("The Comedy Sandbox"), with the
judges' grafts from "Snackable" and "Classic" and every must-fix resolved (traceability table in Appendix A).
Technical contracts: `docs/TECH.md`. Build plan: `docs/PLAN.md`. Status: `docs/PROGRESS.md`.
**The 3D pivot (v1.2):** the view is 3D (`docs/REDESIGN_3D.md` v1.0, owner decision D6); this version folds in every
amendment REDESIGN §6.6 lists, the owner's style pick and the R3D lead rulings that change design. The branch `r3d`
builds it; `main` keeps the 2D Gate-0 build that v1.1 describes.

**Changelog.**
- **v1.2 (2026-09-30, the 3D pivot: REDESIGN_3D v1.0, owner decision D6, R3D rulings R5–R7 and R15, lead decision D7 on
  outline widths).** The owner played the 2D Gate-0 build: the core idea is right, but the UI was too crowded, the
  characters didn't look good (he wants 3D), the house was too crowded and the actions weren't obvious. His style pick:
  *"Prankster dimensions from B, the rest from A"* — Hush = look B's body dimensions in look A's Toy Box style; Bellows,
  the house, lighting, shading, faces and props = look A with the look-dev board's fixes. Changed (every changed
  paragraph is marked "(v1.2)"): Conventions (3D units, terms); §0 (Fairness row: the Bellows window; new Look row);
  §1.2 (the 3D cast in metres and on-screen px, 64 px silhouettes, face cards, the owner's hybrid Hush, the head check,
  Pip, Figgis); §1.3 (footlights as light); §2.1 (the feedback column: before / during / after / trigger); §2.3 (cue
  staging in 3D, no timing change; the Boot warm-up); §2.4 (the Bellows window's name, the `lean` check); §3 intro; §3.1
  (projected tap targets, pinch and drag within C1–C3); §3.2 (QUIET / LIVE, the ring at the prop, the marble freeze);
  §3.3 (Clarence bottom-left, the contextual lure ring); §3.4 (one hiding spot per room in Act I, `hides`, the in-use
  lesson from Night 3); §3.5 (verb glow / halo, previews, needs clouds, item bubbles, red beret tags; W1–W4, N1–N4,
  V1–V6); §3.6 (carried-item chips); §3.7 (the 3D camera, the Bellows window 400×225 and C8 with its two presentations,
  the Overview hidden in Act I, the floor-above gag dropped); §3.8 (the HUD: four always-on pieces, contextual pieces,
  the panels, the placement rules); §3.9 (bubble sizes; floor decals); §3.10 (a pointer to the 3D HUD's text sizes);
  §3.11 (Previews, Room dimming, Outline +50 %; the debug keys); §4.10 and §6.5 (the Stalls hidden at rest); §6.4 (the
  spotlight pool; Hint in the pause panel); §7.1 (the 3D stage: units, depth bands, set layers, the strike rule,
  density, the reach ruling, locked rooms not built); §7.2 (`hides`, the rooms built per Night, Night 2 without the
  clock case); §9.1–§9.4 (3D art direction and shading, rigs, the animation pipeline and list; §9.3's timing rules
  unchanged); §9.5 (voice and crowd defaults kept); §10.2–§10.5 (3D budgets, R3D = R1 + R2, the Fun-Gate pre-checks in
  3D, risks X1–X9); Appendix A (the 3D decisions). Everything else is word for word v1.1.
- **v1.1 (2026-09-29, Stage 2 Checkpoint G).** Folded in the Stage-1 content resolutions ("GDD ambiguities" 1–8),
  every Stage-2 D1 data change (`docs/review/s2-content/d1_changes.md`), lead decision D1 (the dead-air gate, with
  rulings L1/L2/L4), the sim-clock / Boot contract (L13) and the curtain-call step table. Changed: §0 laugh clock;
  §2.1; §2.2; §2.3 (measured Prologue clock, cue ids, the ⏩ lesson, Boot and the sim clock); **new §2.4** (dead
  air); §3.3; §4.1 + §4.1.1 (D1 durations, tea faces left, timed micro-gags, the `exit` detour); §5.4 (fix-up rooms
  and overrides, residue clears, `rules.combos`); §5.7 (#1, #2, #32); §6.2 (Big Number re-arm, curtain call); §7.1
  (porch); §7.2 (rooms, loops, rules, card cues); §7.3; §8; §10.4; §10.5 R6.
- v1.0 — the panel's binding design.

**Conventions.** All sizes are logical px at the 1920×1080 base (`canvas_items` + `expand`; ≈17 px per mm on
every phone). Times are seconds of game time; animation frames are at 60 fps (1 frame = 1 sim tick).
`S` = symmetric side safe inset, `T` = top inset, `B` = bottom inset, `W` = logical width (1920–2520), `H` = 1080.
"MUST" statements are testable acceptance rules. Anything not in this document is OUT of v1 unless PLAN.md
adds it after the fun gate.
**(v1.2) 3D conventions.** 3D sizes are metres; **1 m = 200 sim px** (§7.1). "At the base framing" = the play camera
of §3.7 on a 1920×1080 logical screen (1 m = 269 px at the acting lane); the review shots are 1200×540 (half of that:
a figure of 434 px is 217 px in a shot). Terms in sections v1.2 did not amend: **"PiP" / "Bellows-Cam"** means the
Bellows window of §3.7; **"badge"** means the verb glow / halo, previews and tags of §3.5; **"tray"** means the
carried-item chips of §3.6; **"Figgis chip"** means his contextual bust of §3.8.

**Originality.** Everything here is original. We never use *Neighbours from Hell* names, characters, art,
level layouts, gags listed in `docs/research/nfh.md` §9, TV/"viewers"/rating-% framing, or branding.
A content lint (TECH §10.5) rejects banned terms.

---

## 0. Summary

| | |
|---|---|
| **Pitch** | A silent street mime takes revenge on the loudest man alive. Sneak through retired opera baritone Horace Bellows' house, rig his day with slapstick, **freeze in plain sight**, and bring the house down for a live theatre audience. |
| **Format** | Solo, fully offline, landscape phone game. A 70 s **Prologue**, **10 Nights in 3 Acts** and **Gala Night**: 12 episodes, 4–8 min each. One side-view house that opens up from 2 rooms to 10 spaces. |
| **Verbs** | Tap to tiptoe (double-tap to run). **Hold** the action button to rig. **Hold FREEZE** to become a statue. Tap a hiding spot to hide. Tap **Clarence** the rubber chicken to squeak. |
| **Depth** | Three systems, deep rather than wide: (1) the **specs rule** (one danger read), (2) **Temper → Running Gag → Meltdown** (one chain engine, fed by **residue → fix-up** routing), (3) the **squeak** (one free comic verb that is also a lure). |
| **Content** | 32 original pranks (6 signature set pieces), 10 squeak bits, 6 Double Acts, 7 residues, 4 combos, 22 reaction archetypes. |
| **Audience** | **The Stalls**: a strip of silhouetted theatre heads that laughs in 5 tiers, gasps, shushes and shouts "BEHIND YOU!" ((v1.2) hidden at rest, rising only on audience events, §4.10). Score is **Applause** (0–100+); stars are **Curtain Calls**. |
| **Fairness** | You can always read where he goes next (thought bubble + ring), what he can see (awareness glyph + stare strip on the floor), and when he's coming (1.5 s door jiggle + footsteps + **the Bellows window** — (v1.2) a 400 × 225 inset shown only while he is off-screen and in the next room, heading to Hush's room, or she is rigging — never an always-on PiP, §3.7). Every catch starts with a ≥ 0.8 s "?" window and is replayed by the **Busted Cam**. |
| **Look** (v1.2) | **3D toy-proportioned characters** — Hush in look B's body dimensions rendered in look A's *Toy Box* vinyl style; Bellows, the house and the props in look A — in a **simplified 3D dollhouse-cutaway stage**, dressed per Night with only what tonight uses, seen by a **fixed side-on perspective camera** that follows Hush. A 4-piece HUD; every action readable before, during, after and at the trigger (§3.5). |
| **Failure** | **The Lecture**: a 4-second sung scolding, then Hush lands on the doorstep and takes a tomato. Every rig and every laugh is kept. Three tomatoes bring **the Hook** (from Night 4; never in Relaxed). Retry in place in ≤ 1.5 s. |
| **Laugh clock** | ≈ 5 s a vase smashes behind him · **≤ 10 s from app launch the player's first squeak cracks his high note** · ≈ 25–28 s first prank (ACHOO-RIA!, ≤ 30 s) · ≈ 47–50 s his first Running Gag link (ALLEGRO-GO-GO! ×1.5) · six laughs in the first 60 s (launch-relative, §2.3). |
| **Length** | ≈ 60 min to clear once; 3–4 h for all Curtain Calls; Encores and the Programme (Stage 4) extend it. |

**Pillars (in priority order):**
1. **He is the show.** Bellows' reactions are the product; every system exists to set up a bigger, better-timed reaction.
2. **Readable danger.** The rules fit on a loading card. A catch is always explainable in one sentence.
3. **Thumb-simple.** Two thumbs, three inputs, zero pixel hunting. Every tap answers within 16 ms.
4. **Play it by ear.** Improvising (squeaks, freezes, panto) scores alongside solving.

**What v1 deliberately is NOT:** no minigames, no dexterity tests, no time limits, no energy, no ads, no IAP,
no network, no accounts, no daily/streak systems. Meta (Playbill wall, Encores, Programme) is built only
after the owner's fun gate passes (PLAN Stage 4).

---

## 1. Title, tone, cast and framing

### 1.1 Title, logline, tone
- **Title:** *Mischief Next Door* (working title kept; repo `mischief`, Android package `gg.mischief.app`).
- **Logline:** "Horace Bellows sings scales at six every morning and got the street's only mime banned for
  'visual noise'. Tonight, the mime sneaks next door."
- **Tone:** silent-film pantomime crossed with a stage farce, at Looney Tunes timing. A pompous man loses his
  dignity: "humiliated more than harmed". Residue is ridiculous (frizz, flour, feathers, a tutu), never injury.
  Explosions frizz hair and never darken a face. No animal is ever hurt. No toilet humour, no weapons, no gore,
  no jump-scares. Target rating PEGI 7 / Apple 9+.
- **Why he deserves it:** each Night opens with a 5 s **cold open** of Bellows being awful (§7.2).
- **The comic engine is contrast:** a silent performer against a booming baritone. Every squeak, freeze and mime
  is funny because he is so loud.

### 1.2 Cast

| Character | Role and personality | Silhouette (v1.2: must read as a **64 px** black shape) | Size (v1.2: metres; px at the base framing, §3.7) | Colours |
|---|---|---|---|---|
| **Hush** (player), street mime, ~25, lives at No. 9 | Silent, gleeful, a brave coward who can't resist showing off. Mimes everything; glances at the audience after every rig (makes the player complicit). **Warm, never creepy**: big round pupils, rosy blush, smiling default mouth, small teardrop. | Lanky; tilted beret; Breton stripes; braces; **huge white gloves** (1.6× hand size — the gloves act); flat shoes. (v1.2) At 64 px: beret + gloves + stripes on a lanky frame. | (v1.2) **1.60 m** to the top of the beret = **434 px, 40 % of the screen height** (217 px in a 1200×540 shot); head ≈ 0.50 m incl. the beret (look B's proportions); gloves ≈ 0.20 m | Face paint `#FFF6EA`, stripes navy `#2B3566`, **cherry-red beret + braces `#E23B4E`**, cheeks `#FF9AA2` |
| **Clarence** | Hush's rubber chicken, rides in her braces. Pitch follows the squeak. | Floppy chicken, red comb. | (v1.2) a hand-sized squeaky prop on her right brace (a rig prop: in the brace, held, squeezed) | Yellow `#FFD23F`, comb `#E23B4E` |
| **Horace Bellows** (neighbour), 61 | Retired bass-baritone ("fourth most famous in the county") planning a comeback nobody wants. Vain, stingy, short-sighted: his specs hang on a chain, unworn, until he's suspicious or furious. Catchphrase **"PIPE DOWN!"** The straight man with far too much dignity. | **A dandelion clock on a barrel**: barrel torso on tiny legs, silver **bouffant**, **mutton-chop sideburns** (springs that bristle with temper), specs on a chain. (v1.2) At 64 px: a dandelion puff on a barrel. | (v1.2) **1.78 m** to the top of the bouffant = **471 px, 44 % of the screen height** (236 px in a 1200×540 shot); barrel torso 0.85 m wide on 0.45 m legs; head ≈ 120 px plus the bouffant | Plum jacket `#7B3F8C`, gold cravat `#E8B33A`, bouffant `#D9DCE6`; face ramps peach `#F4C9A8` → pink → red → beetroot `#B8324B` with temper |
| **Beryl** (Act II+) | His pygmy goat ("my little prima donna"). Dozes in sunbeams, loves apples, **headbutts anyone who bends over near her**. Never gives Hush away, never harmed. | Box body, stick legs, triangle beard, rectangular pupils, jingling bell. | 210 px (2D; her 3D size is set when she is built, Stage 3) | Cream `#F3EAD6`, **pink collar `#FF7FB0`** |
| **Dame Delphine Trill** (Act III+) | Retired soprano, his old stage partner and unrequited crush. Blind as a bat without her opera glasses; easily scandalised. Her high C cracks mirrors. | A gliding triangle gown under a towering auburn **beehive with a tiara**; opera glasses on a stick. | 420 px (2D; her 3D size is set when she is built, Stage 3) | **Emerald `#1FA37A`**, beehive `#B5562E` |
| **Old Figgis** (hints) | The ancient prompter. Whispers "psst!", holds up picture cue cards. | A tiny head with huge ears in a hooded prompt box — (v1.2) a contextual HUD bust (§3.8), no longer an always-on chip. | 128 px bust (2D) | Hood `#3A3050`, face `#F4C9A8` ((v1.2) redrawn in look A's palette, below) |
| **The Stalls** (audience) | The visible laugh track: ~24 silhouetted heads (bowlers, beehives, a shiny bald head, a toddler on a shoulder). | Head/hat silhouettes only (2D). | (v1.2) hidden at rest; they rise 60–150 px by laugh tier on audience events (§4.10) | Aubergine `#2A1E3A` at 0.6 alpha |

**(v1.2) The cast in 3D — the owner's pick: "Prankster dimensions from B, the rest from A."**
- **Hush** has **look B's body dimensions and proportions** — 1.60 m, B's lanky long limbs, B's torso and head
  proportions and **B's neck** (the Breton collar may cover it, never shorten it) — **rendered in look A's style**:
  matte vinyl-toy forms, a painted face from one decal atlas, A's palette, the toy shader with its outline, A's
  gloves / beret / stripes vocabulary. Her arms are B's (shoulder 1.127 m above the floor, 0.405 m shoulder → wrist),
  which is why the set brings what she rigs into her reach (§7.1).
- **Horace Bellows** is **look A** with the look-dev board's fixes: a modeller pass inside the budget of §9.2, a bigger
  face inside the bouffant, arms that clear his barrel, bigger held props (the teacup must read at game size), the
  cotton-wool CHOO puff and the felt dazed stars restyled as vinyl, the 20–35° face cheat-out (§7.1).
- **Faces are 2D painted cards on the 3D heads** — eyes, brows and mouth are cells of one face atlas per character,
  pupils follow a look-at, blinks swap a lid cell; the same presets and the same expression vocabulary as v1.1 (§9.2).
- **Value hierarchy:** the characters are the only things on stage with both value extremes (≥ 20 % of the silhouette
  at L* ≥ 85 and ≥ 20 % at L* ≤ 40), a **4.8 px outline** (look A's weight, lead decision D7) and a **rim light** (§9.1).
- **The head check (Hush).** The owner's pick is B's head. If B's head makes her painted face unreadable at game size,
  the face card is first enlarged *inside* the head (no silhouette change); only if a maximal face card still fails the
  readability bar are head-scale variants rendered (×1.1 / ×1.2 / ×1.3 about the neck) and the smallest that reads is
  **proposed** — never silently shipped. The build keeps B's head (scale 1.0) until the owner answers; the alternate is
  the rig variant `head_b`, and the debug stage door offers **"Gate 0 · Hush, B's head"** and **"Gate 0 · Hush, head
  ×<scale>"** (e.g. "head ×1.2") so he can judge it in play. The head scale never changes the skeleton or the clips;
  B's neck bone and visible neck length stay.
- **Figgis** is a flat bust (2D SVG) restyled as matte vinyl in look A's palette; his idle rig animation is dropped in
  R3D (a stated downgrade), and a pre-rendered sprite in the 3D style is R3 work. **The Stalls** stay 2D silhouettes.

**Pip fallback (kept wired, R4).** If the owner rejects the mime at the cast review, Hush is replaced by *Pip*,
an 11-year-old "Statues" champion (red beanie, striped jumper, same gloves-as-mittens idea). Same rig topology,
same pivots, same verbs, same clips; only part SVGs, face paint and the Lecture's grab (Pip is shooed out
with a broom-sweep instead of lifted) change. Art tasks MUST keep part names and pivots rig-compatible.
**(v1.2)** In 3D the Pip fallback is a skin on Hush's 3D skeleton (same bones, same clips). The owner never answered
"mime or Pip" (D2), so R3D builds the mime only: a `pip` skin request falls back to Hush (logged once); Pip is R3 work
once D2 is answered.

### 1.3 Framing: "the house is a stage"
A stage farce, not television: there are no cameras, viewers, ratings, channels, seasons or directors.
- Episodes are **Nights**; groups of Nights are **Acts**; the cutaway house is the set with its fourth wall
  missing. A red curtain rises and falls each Night. Footlights glow along the bottom of the set — (v1.2) as
  **light, not sprites**: a warm additive gradient from the gilded stage lip (12 % at the lip, fading to 0 by 1.2 m
  up), computed in the shaders like the rest of the stage light (§9.1).
- Score is **Applause** on a brass **Applause-o-Meter**. Stars are **Curtain Calls** (★ ★★ ★★★).
- Each catch earns Hush a **tomato** from the Stalls; three bring out **the Hook** (a vaudeville cane).
- **Results = the curtain call** (§6.2). Bellows, still wearing his residue, wanders onstage, sees the audience
  for the first time, slow-burns, and the curtain drops on his head.
- **The fourth wall.** Bellows never acknowledges the audience during play — except in SPOTLIGHT STEALER (§5.7),
  where that is the joke. Hush glances at the audience after every rig.

---

## 2. The core loop

### 2.1 The 30-second beat (8–12 per Night)

| t | Player | Screen and audience ((v1.2) the feedback of every action: **BEFORE / DURING / AFTER / TRIGGER**, §3.5) |
|---|---|---|
| 0–3 s | **Read** his thought bubble (next activity icon + countdown ring + awareness glyph). | He hums through an activity with a micro-gag every 5–8 s. (v1.2) **BEFORE:** every available rig point in Hush's room shows a passive preview of its *joke* (§3.5). |
| 3–8 s | **Move**: tap a glowing hotspot; Hush tiptoes (400 px/s). | Ripple ≤ 16 ms, dotted path, 8 ms haptic tick, pizzicato footsteps. (v1.2) The path and a 0.5 m destination ring are floor decals; at the rig point Hush's thought shows the joke and the other previews fade to 30 %. |
| 8–11 s | **Rig**: hold the action button 0.8 / 1.5 / 2.5 s. | Hush fiddles, then frantically works, then wipes her brow, then snickers at the Stalls (titter). (v1.2) **DURING:** a prop-specific action in one of three reach bands, the prop changing as she works, the **rig ring filling at the prop** with its echo on the button. **AFTER:** the prop's armed look + Hush's **red beret tag** hung on it; she snickers at the audience. |
| 11–14 s | **Cover**: tap a hiding spot, or hold FREEZE, or squeak Clarence for a laugh or a lure. | 1.5 s before he enters: door jiggle, footsteps crescendo, PiP pops, "BEHIND YOU!" if she's exposed. |
| 14–22 s | **Watch** him approach the trap. | Suspense tremolo. A first-time prank plays its last 0.4 s at 0.5×. (v1.2) **TRIGGER:** the tag wiggles and the camera finds the two-shot. |
| 22–26 s | **Payoff.** | Punch-in, hit-stop, a 2–4 s reaction, a pun caption, a tiered laugh, the Applause needle jumps. (v1.2) The punch-in is a camera dolly; afterwards the prop shows **spent** (glow off) and its tag flies to the Script chip's pip. |
| 26–30 s | **Decide**: he's fuming (Running Gag fuse burning) and his bubble shows where he'll go to clean up. Rig that spot, squeak to keep him simmering, or back off because his specs just went on. | His body is the meter: face colour, sideburns, steam. The fuse bar drains under the Applause-o-Meter ((v1.2) the transient meter, shown while the Running Gag is live, §3.8). |

A skilled run lands a laugh every 15–25 s and a prank every 40–60 s. No stretch of more than 12 s of real time
may pass without player input, a laugh or a *visible* micro-gag, and dead air stays within the gate of §2.4
(TECH §8.5).

### 2.2 The Night
1. **Cold open** (5 s, tap skips after the first viewing): Bellows being awful.
2. **Loading card** on the curtain: one new rule, ≤ 25 words, one icon. Tap or 4 s. (The Prologue has none: its
   rule, `basics`, is taught by ghost fingers.)
3. Curtain up — **sim tick 0 is the frame the curtain starts to rise** (§2.3, Boot and the sim clock). **The
   Script** slides in from the top for 2.5 s: 3–6 punchline lines + a sealed **Big Number**.
4. Play until the required lines are done (★). The Big Number unseals: a 2–3-room chain finale.
5. **Take a Bow** at the front door (or from the pause menu) any time after ★. When every line is done, the
   Stalls chant "BOW! BOW!" and the front door flashes.
6. **Curtain call** results with the **Gag Reel** of your 3 best moments — a fixed sequence of ≤ 12.8 s
   unskipped, ≤ 7.5 s on a repeat viewing (§6.2). "Next Night ▶" is the default button.

There is no clock and no Bedtime in v1: nothing punishes watching and planning. Pranks score once per Night
(a landed prank's station greys out), squeak bits diminish to zero, so Applause is naturally bounded.

### 2.3 The first 60 seconds — Prologue "Curtain Up"
Rooms: **parlour + kitchen** only (the hall doorway is roped off "backstage"; Bellows goes through it, the PiP follows
him — (v1.2) the Bellows window of §3.7). No menus before play. Times are **from app launch** on a mid-range Android:
launch-relative = sim time + 2.3 s (Boot and the sim clock, below). Where the *ideal* and the *slow first-timer* routes
differ, t gives the range ideal–slow (solver-measured at Checkpoint G, `docs/review/s2-content/prologue_clock.md`).
Director cue ids are in `code`; they are binding for the FTUE, the view and the sound.

| t (s) | Beat | Player | Laugh |
|---|---|---|---|
| 0.0–2.3 | Engine splash (background colour only) → Boot shows the **red curtain** on its first frame (a 1× pre-rasterised SVG) with a house-lights-dimming hum. The Night is built and warmed under the curtain (≤ 2.0 s budget) while the sim waits at tick 0 and Bellows's warm-up clip pre-rolls. | — | — |
| 2.3–3.1 | **Tick 0:** the curtain rises (0.8 s). Parlour (left) and kitchen (right). Bellows stands at the gramophone, back to the kitchen, singing "MI-MI-MIIII". Each note nudges a vase along the mantel. Input is live from half-up (≈ 2.7). | may tap | — |
| 4.6 | The vase smashes behind him (`laugh_vase`). He doesn't notice and sings on. | — | titter (1) |
| 5.0 | The kitchen window creaks; Hush climbs in on an invisible mime ladder, finger to her lips (3.7 s; a tap during it is queued, with instant feedback). The Stalls shush each other. | — | giggle |
| 6.0 | Figgis pops up in his top-left chip: "psst!" + cue card *chicken → Bellows* (`figgis_psst`). A **ghost finger** pulses on Clarence (left thumb, `ghost_squeak`). | — | — |
| ≈ 6–7 | **SQUEAK.** His high note cracks into a yodel; he clutches his throat: "…the pipes." (squeak bit, teaches the squeak) | tap Clarence | **laugh (2) — first player-caused laugh ≤ 10 s from launch** |
| +1.0 after the squeak (or 15.0 if none) | He hums "Hm-hm-hmm… TEA." Bubble: teacup → kitchen. The **honey jar** (with the pepper pot beside it) glows; ghost finger taps it (`ghost_honey`). **This step waits for the player** (no cap): he keeps warming up with micro-gags; after 8 s idle Figgis nudges again. | tap jar, Hush tiptoes 2 s | — |
| ≈ 9–12 | Action button inflates to RIG (pepper → honey); ghost thumb shows *hold* (`ghost_hold`). Hold 0.8 s: ding, Hush snickers at the Stalls. (teaches move + hold) | hold 0.8 s | titter |
| rig + 2.0 | He leaves the gramophone for the kitchen (≈ 4.5 s walk). 1.5 s entry warning before he enters (≈ 14–17): footsteps, door jiggle, the Stalls shout "BEHIND YOU!". The pantry curtain pulses; ghost finger (`ghost_hide`). **Safety net:** if Hush isn't hidden 1.5 s before he enters, time drops to 0.5× and the pantry pulses harder. (teaches hide) | tap pantry | gasp |
| CHOO − 7 | He brews honey tea at the counter (8 s), **facing left** — the pantry and the sink behind his back (kettle, spoon, stir, sniff; he admires himself in the kettle). "ah… (20 f) ahh… (24 f) AHHH… (30 f)" — false stop, relieved smile (20 f)… | watch | — |
| **≈ 25–28** | **"CHOO!"** He rockets backwards on his stool into the sink; bouffant flipped over his face. Punch-in 1.4×, 5 f hit-stop, caption **ACHOO-RIA!**, Applause +35. | — | **laugh + applause (3) — first prank ≤ 30 s** |
| ≈ 30–33 | Hair over his eyes (FRAZZLED), he shuffles blind toward the hall mirror, bonking the door frame (`laugh_doorframe`). Bubble shows the mirror at once. "RUNNING GAG" banner + fuse appear. | — | titter |
| ≈ 32–35 | **The ⏩ lesson** (`ghost_ff`, Hush's first hidden wait, 1.5 s after the bonk): Figgis's card *Clarence held → clock fast* and a ghost thumb holding ⏩, until Hush presses ⏩ or leaves her spot. Never during the sneeze build-up. | hold ⏩ | — |
| mirror detour + 8 s (≈ 34–37) | The gramophone's speed lever sparkles (`sparkle_lever`, counted from the moment the mirror detour is queued, if the lever isn't rigged yet; no ghost finger — the first unguided step). He combs himself off-stage (≈ 11 s round trip). | tap lever, hold 0.8 s, tap piano to hide (the command queue dives her in when the ring completes) | — |
| ≈ 47–50 | He returns combed and drops the needle. ×3 speed: he babbles, spins like a top and collapses dizzy. **"ALLEGRO-GO-GO! RUNNING GAG ×1.5"**. The Stalls rise. | — | roar (4) |
| ≈ 50–53 | Livid, he **jams his specs on** (tink!) and hunts the parlour for 6 s, walking 2350 → 1650 past the piano; he bends to peer under it, nose an inch from Hush's eyes darting in the dark. (shows "specs on = danger" and the glyph) | hold breath | — |
| ≈ 56–59 | He finds nothing: she hid unseen (`laugh_relief`). | — | relief laugh (5) |
| ≈ 57–60 | "Hmph!" He stomps out toward the stairs (the bubble shows the exit icon); a picture falls on his head in the doorway (`laugh_picture`). | — | titter (6) |
| ≈ 61–64 | The curtain falls (`title_card`, 4 s after the picture; the Prologue ends 1 s later). The Prologue curtain call (§6.2): Hush pops out and bows; roses fly. Only now the **title card** slams down: MISCHIEF NEXT DOOR. Applause total, the Gag Reel (the sneeze), then **"Night 1 ▶"**. | tap | cheer |

Prologue rules: it **cannot be failed** (the "?" window is 2.0 s; if it ever fills, Figgis's hook yanks Hush
into the nearest hiding spot — "the show must go on!"). No loading card, no Big Number and no Curtain Calls (the
Prologue is the overture, marked "Seen" on the Playbill); Applause is shown. If the player never rigs the
gramophone, he warms up again (at most 25 s), the fuse runs out, and the Prologue still ends after the hunt
(ALLEGRO fires on his next warm-up if rigged later). The solver MUST reproduce "6 laughs in 60 s" on the *ideal*
route and "first player laugh ≤ 10 s, first prank ≤ 30 s, ≥ 4 laughs by 75 s" on the *slow first-timer* route
(TECH §8.5; Checkpoint G: ideal 7 laughs by 60 s; slow 6.6 s / 28.2 s / 7 laughs by 75 s). **ALLEGRO lands at
≈ 47–50 s, not the v1.0 sketch's ≈ 38 s:** the blind round trip to the hall mirror is ≈ 11 s of walking; the
6-laughs-in-60-s script still holds, so this is accepted.

**Director cues (binding ids, in firing order):** `laugh_vase` · `figgis_psst` + `ghost_squeak` · `ghost_honey` ·
`ghost_hold` · `ghost_hide` · `laugh_doorframe` · `ghost_ff` · `sparkle_lever` · `laugh_relief` · `laugh_picture` ·
`title_card`. Every `laugh_*` cue MUST produce a visible prop or clip change **and** a crowd sound within 0.3 s.
`title_card` stages nothing during play: the title slams only in the curtain call, after the fall.

**(v1.2) Cue staging in 3D — no timing change** (every second of the table above stands). The set is the parlour and
the kitchen built and lit; the hall is built dark ("backstage": architecture, the mirror and the stair foot he uses, a
velvet rope at the doorway), so Bellows' FRAZZLED mirror detour is seen in the **Bellows window** (§3.7), with the dark
hall lit for him while he is in it. Ghost fingers (`ghost_squeak`, `ghost_honey`, `ghost_hold`, `ghost_hide`) point at
the **projected** spot on screen, approaching from the side away from Hush; **`sparkle_lever` is the spotlight pool** —
a soft warm pool on the floor in front of the gramophone, its preview at full size (§3.5 N4); Figgis's psst card is
his contextual bust (§3.8). The `laugh_*` cues are staged in the 3D set: the vase nudges along the mantel on each
warm-up note and smashes behind him (`laugh_vase`), the blind bonk at the doorway (`laugh_doorframe`), the relief
laugh (`laugh_relief`), the picture falling on his head in the doorway (`laugh_picture`). The pantry curtain and the
piano back are the Prologue's two hiding spots (`hides`, §3.4).

**Boot and the sim clock (binding, every Night).**
1. Boot draws the red curtain (the 1× SVG, no warm-up wait) on its **first frame**, plays the house-lights hum and
   builds the Night underneath it. No menus before play.
2. **Sim tick 0 is the frame the curtain starts to rise.** Under the curtain the simulation is paused at tick 0
   and no sim event fires; the view pre-rolls Bellows's clips (he is already mid-"MI-MI-MIIII" when the curtain
   lifts, sounds muted) without advancing the sim.
3. The rise starts at `director.launch_offset_s` after process start (2.3 s; the value is clamped to 2.0–3.0 s)
   or, if the Night is not warm by then, the moment it is — and at 3.0 s at the latest, then on 1× textures, anything
   still cold being finished under the curtain on that frame, never during play.
4. On the rise frame the `curtain_rise` sting plays, the music goes curtain → sneak, the sim unpauses and the device
   log stamps `sim_start`. Input is live when the curtain is half up (0.4 s after tick 0).
5. Nights 1 and 2 keep the same contract after their cold open and loading card (tick 0 = the curtain rise; their
   clocks have no launch offset); Gate 0 after its stage-door card.
6. Every Night warms its own list under its curtain, cold open or card — both rigs' atlases, its rooms and props,
   every look it can show (residues, blinded, costumes, the combos it allows), its FX, the fonts at play sizes, one
   PiP frame, its sounds. **No texture page is built during play.** (v1.2) In 3D the list is every character look,
   tint tier, stone and prop state, every set piece and prop state (glow, halo, tag, hidden eyes), every floor-decal and
   particle material, one Bellows-window frame and the overlay textures: every material is drawn once under the
   curtain, so **no shader is compiled during play** (§10.4).
7. Acceptance: tick 0 = the rise frame ± 1 frame; 0 sim events before it; input live ≤ 0.4 s (+ 1 frame) after
   tick 0; on the slow route the first player laugh ≤ 7.7 s and the first prank ≤ 27.7 s after tick 0. Process
   start → curtain up is reported (target 3.1 s, TECH §9) and measured by the device log on the phone.

### 2.4 Dead air — the waiting gate (lead decision D1)
Waiting is the genre's most common complaint (`docs/research/`), so dead air is a gate, not a guideline. It binds every
non-scenario route (ideal, required, slow) of every `final` Night and of Gate 0; the solver checks it (TECH §8.5).
1. **A dead moment:** the player gave no command in the previous 3 s, nothing got a laugh and no *visible*
   micro-gag played in the previous 5 s, and Bellows isn't reacting.
2. **Visible beats only.** A micro-gag (§4.1) counts only when the player can see it: Bellows is in Hush's room
   (hidden: her spot's room); or the PiP shows him (adjacent room, heading to her room, or she is rigging, §3.7);
   or — only for a gag with an emote — the HUD edge bubble plays it. **Edge-bubble beats MAY carry at most ⅓ of
   the beat credit on any route.** (v1.2) In 3D "the PiP" is the Bellows window and the edge bubble is the edge
   badge (§3.7, §3.8); the gate itself is unchanged, because the view MUST show him whenever the sim counts him as
   visible (the visibility contract C8, §3.7). Under the `lean` window presentation an adjacency-only beat shows only
   in the edge badge, so it counts only when its gag has an emote; the solver reports that variant as `d1_lean`.
3. **Real time with ⏩.** The gate counts the time the player really waits: a tick at ⏩ weighs ⅓, and ⏩ counts
   only where the game would really run at ×3 — Hush hidden and ⏩ held, dropped by the game's own rule (a prank
   fires, a "?" starts, an entry warning for her room; §3.3), re-pressed after the persona's delay (ideal 0.5 s,
   required 1.0 s, slow 2.0 s; never during a reaction). The slow first-timer uses ⏩ only once the Prologue's
   `ghost_ff` lesson has taught it. The Stage-1 formula (every hidden tick at ⅓) is reported beside it, for
   information only.
4. **Targets (MUST):** dead air ≤ 20 % on the ideal route, ≤ 25 % on the required-lines route, ≤ 30 % on the slow
   first-timer route, and the worst gap ≤ 12 s on every route. Scenario routes (caught, chase, Meltdown,
   face-to-face) are exempt.
5. **Fixed at the source, never by pressure on the player** (no timer, no penalty — §2.2): every Act I loop is
   ≤ 60 s with Hush idle (walking included); Nights 1 and 2 land their first prank ≤ 25 s on the ideal and required
   routes (≤ 30 s slow); Night 1 has two kettle windows per loop and each of its fix-up detours takes ≤ 12 s from
   queued to done; every activity and fix-up detour has a micro-gag every 5–8 s (§4.1); no activity lasts under 5 s
   (the bubble ring must read).
6. Checkpoint G (ideal / required / slow): Prologue 3.0 / 1.8 / 5.9 %, Night 1 7.9 / 4.8 / 2.1 %, Night 2
   6.9 / 1.9 / 1.6 %, Gate 0 8.1 %; worst gap 5.5 s; edge share ≤ 0.22; loops 58.7 s (N1) and 55.4 s (N2); N1
   detours ≤ 10.0 s; first prank N1 17.5 / 18.7 / 24.4 s, N2 19.4 s on all three.

---

## 3. Controls and UI

Scheme: **Tap-to-Sneak + Thumb Action** (touchux.md §0), no joystick. Right thumb: the **action button**.
Left thumb: the **tray** and **Clarence**. Everything else is a world tap. Left-handed mode mirrors the two
clusters. (v1.2) Left thumb: **Clarence** in the bottom-left corner and, only while Hush carries something, the
carried-item chips beside him (§3.6). The world is 3D; every world tap resolves on screen against projected targets
(§3.1).

### 3.1 Gesture grammar

| Input | Rule | Result |
|---|---|---|
| **Tap world** | Touch-up ≤ 300 ms after touch-down, travel ≤ 24 px, no second finger. Fires on **touch-up**. | Target priority: hotspot (tap-assist snaps within 90 px to the nearest hotspot) > door/stairs > floor. Hush **tiptoes** (400 px/s, silent). Feedback ≤ 16 ms: ripple (0.35 s fade), dotted path (0.4 s), 8 ms haptic, destination marker. A new tap re-routes instantly. A repeat tap on the current target does nothing (idempotent). |
| **Second tap** | ≤ 280 ms and ≤ 64 px from the first | Upgrades the current walk to a **run** (720 px/s, noisy: 500 px noise ring every 0.5 s). The first tap is never delayed. |
| **Tap a hotspot** | — | "Go and do it": pick-ups, hiding, doors, stairs and Take a Bow auto-execute on arrival. **Rigs never auto-execute**: Hush arrives, faces the rig point, and the action button lights up. |
| **Long-press world** | ≥ 450 ms, travel ≤ 24 px | **Reveal**: every hotspot in view shows its badge for 2 s; lifting over one selects it. 8 ms haptic. (v1.2) The reveal shows every live spot's verb halo and preview (§3.5). |
| **Drag world** | travel > 24 px | Camera pans 1:1; release flings (τ 0.25 s), holds 1.5 s, eases back over 0.5 s. **A drag never moves Hush**, even when hidden. No drag may start within 48 px of a side edge (Android back gesture). (v1.2) The drag pans the 3D camera within its C1–C3 limits (§3.7). |
| **Pinch** | two touches, distance change > 32 px | Zoom 0.5–1.25 anchored at the midpoint. The **Overview** button is the one-finger alternative (toggle 1.0 ↔ 0.5). (v1.2) The pinch dollies the 3D camera within the C1–C3 limits; a pinch-out still opens the Overview (a dolly back to 15 m, 0.5×). The Overview button is hidden in Act I: **Map** in the pause panel is the one-finger alternative (§3.7, §3.8). |
| **Tap PiP / edge bubble** | — | **Peek**: camera flies to Bellows in 0.35 s, holds 1.8 s (longer while the finger stays down), flies back. (v1.2) Tap the Bellows window or the edge badge. |
| **Tap a tray slot** | — | "Where does this go?": matching rig points pulse; off-screen ones get edge arrows for 3 s. (v1.2) Tap a carried-item chip (§3.6). |
| **Android back / iOS edge swipe** | — | Pause menu. Never quits. |

**(v1.2) Tap targets are projected 3D rects.** Every hotspot's hit box is a 3D box — its `house.json` rect's x and y
(or the view's own offset / hit box for that prop, §7.1) × the prop's depth ± 0.3 m. Its 8 corners are projected every
frame, and the screen bounding rect is what tap-assist resolves against (the 90 px assist and the priorities above are
unchanged). Every projected target is **≥ 144 × 144 px**, ≥ 24 px from its neighbours and inside the safe rect; any
camera framing used for play keeps the back wall ≤ 10 m from the camera (≥ 201 px per metre), so a 0.72 m (144 px)
rect still projects to ≥ 144 px (≥ 163 px at the back wall at the base framing).

### 3.2 The action button (right thumb)
Bottom-right, visual 190 px, hit 240 px circle. It shows exactly one verb as a 96 px icon.

**(v1.2) Two visual states** (the one-verb rule for the HUD, §3.5 V1–V6), centre (W−S−168, H−B−168):
- **QUIET** — FREEZE while nothing threatens Hush (he is not in her room, or she is hidden): navy disc at 62 % alpha,
  a white 84 px statue icon, no ring. It stays pressable (FREEZE is persistent) but doesn't shout.
- **LIVE** — any verb that is the right move now: full colour, a 1.08× pop, a 96 px icon, a 14 px ring. RIG (item icon
  → target icon, gold `#F2B632`), RIG_DIM (the missing item's grey silhouette; a tap shows where it is), POP OUT / GO ▶
  (with the green / amber / red danger rim) and **FREEZE when it matters**: a stone-white face with an amber rim while
  he is in her room and she is exposed, pulsing 3 Hz red-amber while a "?" fills on her.
- The ≥ 250 ms hysteresis and the 120 ms cross-fade apply to state changes too. While RIG is held, the ring fills on the
  button **and at the prop** (the world rig ring, §3.5).

| Verb | When shown | Input | Effect |
|---|---|---|---|
| **RIG** (item icon → target icon) | Hush stands at a rig point whose prank is available and she has what it needs (or it's free). Pops 1.08× on arrival. | **Hold** | A 14 px ring fills over the prank's prep tier: **Q 0.8 s, S 1.5 s, B 2.5 s** (never > 3 s). Yellow → green; pulses at 3 Hz over the last 20 %; 8 ms haptic at 50 %; completion pops 1.0 → 1.18 → 1.0 over 180 ms with a ding and a 30 ms haptic. **Release early keeps progress** (the icon shows the partial ring; coming back resumes). Sliding > 80 px off the button cancels (progress kept). |
| RIG (dimmed, item silhouette) | At a rig point but missing the item | Tap | The container that holds the item pulses (edge arrow if off-screen). |
| **FREEZE** (statue icon) | Everywhere else, whenever Hush is not hidden. **Persistent**: it never turns into HIDE or anything else. | **Hold** | Hush strikes one of 8 ridiculous statue poses (chosen by the room/prop) and stays frozen while held. Release unfreezes. World taps while frozen drop a destination **pin**; releasing goes there. (v1.2) She **turns to marble** — every part desaturated to stone white, the ink outline kept — **except her eyes, beret and braces** (the player never loses her), a stone plinth pops up under her feet (0.1 s), a woodblock clack; release: the colour returns with a shiver (0.15 s). R3D builds statues 1–4 first and 5–8 after them; if the R3D animation time box runs out, statues 5–8 ship in R3 and the build plays "4 of 8" until then (PLAN R3D). |
| **POP OUT** / **GO ▶** | Hush is hidden | Tap | Leaves the hiding spot (to the pin if one is set, button reads GO ▶). A double-tap pops out and runs. The rim shows danger: **green** = he is not in this room or the next; **amber** = he's next door or heading here; **red** = he's in this room. |

Rules:
- **Verb latch:** the verb is fixed at touch-down; nothing that happens during the press changes what the
  press does. Each verb stays visible ≥ 250 ms before it may change (hysteresis), with a 120 ms cross-fade.
- **Caught mid-job:** if a "?" starts filling on Hush while she holds RIG, the ring pauses and — as long as
  the thumb stays down — Hush freezes in place mid-task (a statue holding a saw). Releasing unfreezes.
- **Thumb occlusion:** while the button is held the camera offsets 200 px so Hush sits at 40–55 % of screen
  width, never under the thumb. (v1.2) In 3D this is camera rule C4 (§3.7): the camera shifts within its limits so
  Hush stays at 40–55 % of the width while the button is held.
- **Tap-to-rig** (setting): holds become tap-to-start/tap-to-stop; FREEZE becomes a toggle.

### 3.3 Clarence / ⏩ (left thumb)
Visual 128 px, hit 168 px, directly above the tray's left end. Centre distance to the action button ≥ 1,300 px.
(v1.2) Clarence moves to the **bottom-left corner**: hit (S+32, H−B−200) 168×168, a 128 px navy disc at 62 % with
Clarence in colour (there is no tray below him any more, §3.6). Centre (S+116) to the action centre (W−S−168) =
W − 2S − 284 ≥ 1,300 px for S ≤ 168: the two-thumb rule holds at every aspect.
- **Tap: SQUEAK** (0.12 s). No cooldown, ever. Hush's arm moves for 0.3 s (counts as *moving* for sight, §4.3).
  A press that begins within 150 ms of an action-button press is ignored (prevents two-thumb slips).
- **Hold (≥ 0.5 s): WHEEZE** — a falling squeak up to 1.5 s long. Same rules as a squeak (counts once).
- **Lure ring:** a thin ring around the button shows lure readiness; it **greys out** after two lures inside
  60 s (lure fatigue, §5.6). The squeak itself still works and is still funny. (v1.2) The 8 px lure ring is
  **contextual**: it shows only when lure fatigue is close (≥ 1 lure in the last 60 s) and is grey when fatigued;
  otherwise Clarence's button carries no ring.
- **While hidden, the button becomes ⏩** (hold = world ×3). ⏩ drops to ×1 instantly on an entry warning for
  Hush's room, a prank trigger, a "?" or release. **Hush can never squeak from a hiding spot**, so a stray
  press can't break "hidden = safe". The Prologue teaches ⏩ once, at Hush's first hidden wait (`ghost_ff`, §2.3);
  this drop rule is the one the dead-air gate models (§2.4).

### 3.4 Hiding
- Hiding is a **world tap on a hiding spot** (blue closed-eye badge), like any hotspot: Hush walks there and
  dives in on arrival (0.25 s). Hidden, only her eyes blink in the dark gap and track Bellows.
- **Command queue:** one follow-up command waits behind the current action. Tap the pantry mid-rig and Hush
  dives in the instant the ring completes. "Rig, then dash" is the core tension beat.
- **Pins:** while hidden, world taps drop a destination pin and the button reads **GO ▶**; you plan the escape
  while waiting and time it with one tap. You can never pop out by accident.
- **In use next:** a hiding spot that his routine will open during his **next** activity (the wardrobe before
  he dresses, the bath before bath time, the clock before he winds it) wears a **red badge**. Hide there anyway
  and he opens it: face to face, both shriek, a 0.8 s "?" window in which POP OUT + run escapes ("BOO!",
  near-miss) — otherwise it's a catch. Hiding there is a gag, never an ambush.
- **(v1.2) One hiding spot per room in Act I.** Each Night lists its live hiding spots (`hides`, §7.2) — kitchen:
  the pantry curtain; parlour: behind the piano; hall: the coat cupboard. The Prologue lists the pantry curtain and
  the piano back, Gate 0 the pantry curtain, Nights 1 and 2 all three. A Night without the list uses every hiding spot
  of its rooms (the draft Nights). An unlisted spot is **struck** — not built on the stage — and the sim refuses a
  command to it (`cmd_rejected`, reason `struck`; the view answers a stray tap with a small "no" wobble, no text).
- **(v1.2) The in-use lesson starts in Night 3** (the wardrobe, the bath): Night 2 no longer has the clock-case
  hiding spot. The in-use spot's red marker is drawn in the 3D style when Night 3 goes final (Stage 3).
- **(v1.2) Hidden, in 3D:** the dive is a big cartoon leap in an arc (0.25 s) with a whoosh; the cloth or door swings
  shut and wobbles (0.4 s); only her eyes blink in the dark gap (a 3D eye card inside the prop) and track him; the
  cloth breathes; the world desaturates 20 % with a soft vignette = "safe"; Clarence becomes ⏩ and the action button
  shows POP OUT with the danger rim.

### 3.5 Hotspots and highlighting
- **Current room:** every interactable has a 4 px outline pulsing alpha 0.6 ↔ 1.0 at 1.2 Hz and a sparkle every
  1.2 s. Outlines are pre-baked sprites in the prop's atlas (one batch, no shader).
- **Badges** (56 px icons above the hotspot): **gold** = usable right now (you carry the item, or it's free);
  **blue closed eye** = hiding spot; **red** = in use next; **grey thought-cloud with the item silhouette** =
  a rig point that needs an item you haven't got. Spent rig points (prank landed) grey out.
- **Hit boxes:** ≥ 144 × 144 px however small the art (the pepper pot is 60 px), ≥ 24 px dead space between any
  two targets, no overlaps. Enforced by the hotspot lint (TECH §10.5) on every house and Night.
- Setting **Hints**: Always (default) / On long-press / Off.

**(v1.2) In 3D the badges are gone.** The two bullets on outlines and badges above describe the 2D build (`main`);
on the 3D stage every action is readable in four moments, and the world says what each spot will do:
- **Verb glow and halo.** Live props (and only they) carry a 3.4 px ink outline (D7) and, while Hush is in their room, an
  8 px **verb halo** that pulses 0.6 ↔ 1.0 at 1.2 Hz in the verb's colour: **rig gold `#FFC838`**, **hide blue
  `#5C9EFF`**, **take cream `#FFF4DB`**, **exit cream after ★** (the front door). **The active prank spot** — the prop
  Hush is at, or an armed prop whose trigger is his next activity — pulses at 2× amplitude.
- **BEFORE — a preview of the joke, not the instruction.** A **passive preview** (a 112×90 cloud with a 78 px
  pictogram, at 80 % strength) sits above every available rig point in Hush's room; **Hush's thought** (a 180×144 cloud
  with a 124 px pictogram at her head, on the side away from the prop) shows the payoff while she stands at a rig
  point; a **needs cloud** is the preview with the missing item's grey silhouette (once she has seen its container);
  an **item bubble** (a 116 px cream disc with the item icon) sits above a container that holds tonight's item. When
  his next activity will trigger an available, unarmed rig point in her room, that preview gets **his ring** (the red
  countdown ring of his bubble): *he's coming for this next.* When two armed pranks combine (HOT & COLD), the first
  one's preview carries a small "→ sink" badge.
- **DURING — what Hush is doing.** A prop-specific pose readable in silhouette at 64 px, the prop changing as she
  works, and one progress indicator **at the prop**: the **rig ring** (radius 118 px, 14 px stroke, yellow `#F2D23A` →
  green `#5CCF6A` on an 18 px 35 % black track), echoed on the button; release keeps progress (the ring stays partial
  at the prop).
- **AFTER — it's armed.** The prop visibly changes (its armed look) and Hush's calling card, the **red beret tag** (a
  0.28 m 3D beret on a string, ≈ 65 px on screen), hangs on it; she snickers at the audience (40 f, interruptible).
- **TRIGGER — he walks into it.** Anticipation (the tag wiggles, the suspense stem, the camera finds the two-shot),
  the accent (punch-in, hit-stop, caption, laugh), then the prop shows **spent** (glow off) and the tag flies to its
  pip on the Script chip (0.6 s).
- **"What am I doing / what can I do next"** (binding): **W1** Hush's verb reads from her body alone at 64 px (sneak
  crouch, run lean, three reach bands, dive, statue, squeak, peek, bow; no two verbs share a silhouette). **W2** every
  held verb has exactly one world progress indicator (the rig ring at the prop, the frozen stone look) and its echo on
  the button. **W3** a queued command shows a ghost ring with a small chevron at its target until it runs. **W4** his
  current activity reads from his held prop and pose; his bubble shows the next one. **N1** everything live in Hush's
  room glows in its verb colour; nothing else glows. **N2** every available rig point in her room shows its preview;
  armed ones show the tag instead; spent ones show nothing. **N3** the action button's face is the verb available
  right here, right now. **N4** after 6 s without input (the Figgis nudge at 40 s is unchanged) the "next useful" spot
  (§6.4) gets the **spotlight pool** — a soft warm pool on the floor in front of it — and its preview at full size.
- **One verb per screen** (binding): **V1** at a rig point: the LIVE button + Hush's thought; other previews fade to
  30 %. **V2** in danger (entry warning, "?" filling, chase): FREEZE LIVE if she is seen, else the nearest hiding
  spot's safety-net marker (a white 88 px disc with a blue closed eye); every preview hides. **V3** hidden: POP OUT / GO
  ▶ with its rim; the world desaturates. **V4** otherwise nothing is loud: the passive previews are the menu. **V5**
  after an action completes, nothing new is suggested for 1.0 s (the consequence gets the screen). **V6** at most 6
  world overlays on screen at once, at most 2 of them loud (full strength, ≥ 150 px).
- **Hit boxes** are the projected 3D rects of §3.1 (≥ 144 × 144 px, ≥ 24 px apart); the screen-rect lint checks them at
  every aspect. The **Hints** setting becomes **Previews** (§3.11).

### 3.6 Tray and items
- Bottom-left, **4 slots**: visual 128 px, hit 168 px, 24 px gaps (744 × 168 px). No bag screen, no scrolling.
- At a rig point that accepts a carried item, that slot rises 12 px and glows, and the action button shows
  *item → target*. There is never a "select item, then target" two-step.
- **Containers:** tapping a container walks Hush there; a 0.6 s rummage follows. If it holds one useful item,
  she takes it. If it holds 2–4, a **pick strip** of 144 px item icons (24 px gaps) pops above the container
  for 3 s — tap one. Tray full: the oldest item hops home with a "plop".
- **Respawn:** a used item restocks at its container 20 s later. A carried item flies home when Hush is caught.
  Nothing can soft-lock a Night.
- Optional power-user path: drag a tray item onto a hotspot = walk there and rig (still a hold).
- **(v1.2) The tray becomes carried-item chips, shown only while carrying.** No empty slots: each carried item is a
  chip (128 px visual / 144 px hit) at (S+224 + i·168, H−B−188), right of Clarence, at most 4 (the fifth pick sends
  the oldest home with a "plop"). **The item stays visible on Hush's model**, tucked in her braces. "Item get": she
  pops out of the container holding it over her head at 1.6× (0.4 s, a sparkle; view-only, cut short by the next
  command), tucks it in her braces, and its chip flies to the HUD; the needs cloud on its rig point turns into a full
  preview (§3.5). At a rig point that takes a carried item, its chip rises 12 px and glows and the action button
  shows *item → target*, as above; tapping a chip pulses the rig points it serves; dragging a chip onto a hotspot is
  the power-user path. The pick strip is unchanged.

### 3.7 Camera
(v1.2 — the whole section: a 3D perspective camera replaces the 2D zoom camera; REDESIGN_3D §5.2.)
- **Base framing (binding numbers):** a perspective Camera3D, vertical FOV **30°** (the height is kept, the width
  follows the aspect), **7.5 m** in front of the acting lane, at **y 1.9 m**, aimed at y 1.35 m on the lane (pitch
  **−4.2°**), near 0.5 m, far 60 m. It sees 4.02 m of height at the lane: **1 m = 269 px at the lane**, 226 px at the
  back wall, 322 px at the lip; the visible width at the lane is **8.93 m at 20:9, 7.15 m at 16:9, 5.36 m at 4:3**. The
  top ≈ 90 px of the frame show the dark proscenium header (the top HUD row sits on it), the bottom ≈ 100 px the stage
  lip and the dark apron. Hush (1.60 m) is 434 px tall = 40 % of the screen height; Bellows 471 px = 44 %.
- **C1 Room framing:** the camera frames Hush's room. If the room fits (width + 0.6 m ≤ the visible width) the camera
  x is clamped to [x1 − V/2 + 0.3, x0 + V/2 − 0.3] (the whole room in view) and biased toward her walk by her 12 %
  look-ahead; otherwise it follows her at 40–45 % of the width with 12 % look-ahead, clamped to the room. Exponential
  smoothing τ 0.20 s (0.15 s running); no walk bob; crossing a doorway eases to the new room's framing over 0.45 s
  (never a cut). At 20:9 at most 1.7 m of each neighbouring room shows (dimmed), at 16:9 at most 0.8 m.
- **C2 Edge clamp:** at most 0.3 m of unbuilt space shows past the Night's outermost built walls (the Night-1 kitchen
  frames at camera x 15.33 m at 20:9).
- **C3 Two-shot:** when Bellows is in Hush's room, or in a linked room within 3 m of the shared doorway, the camera may
  pull back to ≤ 1.15× its distance (8.63 m) and shift to hold both, Hush ≥ 20 % from either edge (1.15× keeps the back
  wall ≤ 10.0 m away, so a 0.72 m hotspot still projects to ≥ 144 px).
- **C4 Hold offset:** while the action button is held, Hush stays at 40–55 % of the width (away from the thumb, §3.2).
- **C5 Floors — one floor at a time:** a floor change cranes the camera 3.5 m over 0.40 s; **the other floor is never
  in frame** (the upper floor is never visible in Act I). The v1.1 gag "his legs on the floor above" is **dropped**.
- **C6 Safe rect:** Hush and the projected rects of every live prop in her room stay inside the safe rect (the
  punch-hole never covers a target); the camera shifts within C1 / C2 to guarantee it.
- **C7 Gag-Cam punch-ins** (every prank payoff): a **dolly** along the view axis toward his head and chest to the
  distance 7.5 m / zoom — **S 1.15 = 6.52 m, L 1.3 = 5.77 m, M 1.4 = 5.36 m, signature and chain finale 1.6 = 4.69 m,
  never closer than 4.5 m** — in 0.18 s, plus a 3–6° yaw toward his face side for M / L / signature (8° for MIRROR,
  MIRROR's face-to-face); hit-stop 3 / 5 / 8 frames (cap 150 ms per second), shake 10–16 px decaying over 0.25 s,
  hold 1.2–2.0 s on his face, ease back in 0.35 s. A clip may add a slow push (the sneeze build pushes to 1.15).
  **Input stays live; taps queue.** A gag-cam queue guarantees one punchline at a time.
- **Off-screen payoffs:** if Hush is mid-rig or in danger, the Bellows window escalates to **704 × 396** in the same
  corner instead of cutting away. **No punchline is ever missed.**
- **The Bellows window** (the old always-on 448 × 252 Bellows-Cam is gone): **400 × 225** at the top right
  (W−S−424, T+24) plus a 6 px frame coloured by his temper tier, his next-activity chip (72 px, with the bubble's ring)
  in its lower-left corner; it renders the same 3D world through its own camera at 30 Hz, only while shown. It shows
  **only while Bellows is off-screen and the sim says the player should see him** (he is in the next room, heading to
  Hush's room, or she is rigging); it **never shows while he is on screen**, and hides 1.5 s after the reason ends. Tap
  = peek. When he is off-screen and there is no window (≥ 2 rooms away, not heading here), the **edge badge** (his
  112 px face, an arrow and the 64 px next-activity icon, in the outer edge zone at y 430–650) points at him and plays
  the emotes of his edge micro-gags.
- **C8 — the visibility contract (keeps the dead-air gate valid, §2.4):** whenever the sim counts Bellows as visible
  (in Hush's room, or "in the window"), the view MUST show him — on screen or in the Bellows window; whenever he is on
  screen, the Bellows window is closed.
- **Two presentations of the window** (a debug setting, §3.11): **`sim`** — C8 exactly as written; **`lean`** — while
  the only reason the sim shows him is adjacency (he is not heading to her room, she is not rigging, no reaction or
  payoff is running), the edge badge stands in for the window (face, next-activity icon, micro-gag emotes); heading,
  rigging and payoffs still open it, and C8 accepts the badge on those adjacency-only ticks. The window must not
  become the new always-on PiP, so the automated checks measure its share of PLAY time and warn above **35 %**. **The
  shipped default is set at integration from the measured share:** `sim`, unless the first 3D Prologue run shows the
  window up more than 35 % of PLAY and the dead-air gate still passes with adjacency-only beats counted through the
  badge (`d1_lean`, §2.4) on every route — then `lean`. The owner can flip it in Settings (debug).
- **Overview / Map** (a dolly back to 15 m, 0.5×; from Night 3 also a crane that shows both floors): planning only;
  poses read, faces don't, so every payoff zooms back in; taps still resolve through tap-assist. **Hidden in Act I**
  (one floor, ≤ 4 rooms): **Map** in the pause panel opens it (tap a room to peek), and a pinch-out still works; from
  Night 3 a 144 px Overview button appears only while Bellows is on the other floor.
- **Peek** (tap the Bellows window or the edge badge): the camera flies to him in 0.35 s, holds 1.8 s (longer while the
  finger stays down) and flies back.
- **Reduce motion:** no shake, no yaw, punch-ins ≤ 1.15×, 0.25 s linear moves.
- **Audio is the third channel:** his footsteps pan by his projected screen x and fade by rooms between you.

### 3.8 HUD layout (1920 × 1080 base; positions are the top-left of the hit box)
(v1.2 — the whole section: the v1.1 table and diagram are replaced by REDESIGN_3D §2. The old HUD had nine pieces on
screen at rest, covering 18 % of the screen, 24 % with the Stalls band; the 3D HUD has four.)

**Always on — four pieces (MUST be ≤ 4):**

| # | Piece | Hit rect (top-left, size) | Visual | Behaviour |
|---|---|---|---|---|
| 1 | **Pause** | (S+24, T+24) 144×144 | 96 px disc, navy `#1B2340` at 62 % alpha, white bars 44 px | Opens the pause panel. Android back / iOS edge swipe does the same. |
| 2 | **Script chip** | (S+192, T+24) 312×144 | 312×96 pill (navy 62 %) at y T+48: playbill icon 40×52, **one 34 px pip per required line** (gold filled = done, white ring = open), one 14 px dot per optional line, a 32 px star for the Big Number (grey sealed → gold unsealed) | Tap = Script panel (pauses). When a line lands, the prank's red beret tag flies from the prop to its pip (0.6 s) and the pip fills with a pop. The pill grows with the Script (112 + 46 per required line + 22 per optional line + 50 px, ≤ 440 px). |
| 3 | **Clarence / ⏩** | (S+32, H−B−200) 168×168 | 128 px disc, navy 62 %, Clarence in colour | Tap = SQUEAK, hold = WHEEZE, ⏩ while hidden (§3.3). The 8 px lure ring only when lure fatigue is close; grey when fatigued. |
| 4 | **Action button** | centre (W−S−168, H−B−168), 240 circle | 190 px disc | QUIET / LIVE (§3.2); verbs, latch, hysteresis and queue unchanged. |

Clarence's centre (S+116) to the action centre (W−S−168) = W − 2S − 284 ≥ 1,300 px for S ≤ 168 (the two-thumb rule).
Left-handed mode mirrors every rect horizontally (x' = W − x − w) except the centred meter.

**Contextual and transient — shown only when they mean something:**

| Piece | When it shows | Where / size | Replaces v1.1's |
|---|---|---|---|
| **Applause meter** | 2.5 s after any Applause change (count-up 0.6 s, stamp beside it); stays while a Running Gag is live | centred, (W/2−230, T+24) 460×104 pill: dial 72, "APPLAUSE" 36 px, number 60 px, delta "+35" 56 px outside the pill | the permanent 600×144 brass meter |
| **Running Gag fuse** | while the Running Gag is live | under the meter: "RUNNING GAG ×1.5" 44 px + a 420×18 fuse bar at y T+144 | the separate banner |
| **Bellows window** | Bellows off-screen **and** the sim shows him (§3.7, C8); never while he is on screen; hides 1.5 s after | top right, (W−S−424, T+24) 400×225 + a 6 px frame coloured by temper tier; his next-activity chip (72 px, with the bubble's ring) in its lower-left corner; escalates to 704×396 in the same corner for an off-screen payoff. Tap = peek. | the 448×252 always-visible Bellows-Cam |
| **Edge badge** | Bellows off-screen and no Bellows window (≥ 2 rooms away, not heading here; or adjacency-only under the `lean` presentation, §3.7) | the left or right edge zone, x S+24…S+160 / W−S−160…W−S−24, y 430–650: his 112 px face, an arrow, the 64 px next-activity icon; plays the emotes of his edge micro-gags (§2.4 rule 2 unchanged) | the edge bubble (kept, moved) |
| **Carried items** | only while Hush carries something | chips 128 visual / 144 hit at (S+224 + i·168, H−B−188), max 4, right of Clarence (§3.6) | the always-visible 4-slot tray |
| **Figgis** | a nudge (40 s without progress), a card cue, or Hint from the pause panel; auto-hides after 4 s | bust 128 px at (S+24, T+192), card 320×200 to its right; obeys the placement rules below | the permanent Figgis chip |
| **BOW** | after ★ (every required line) | (W−S−344, T+273) 320×112, "Take a Bow ▶"; slides under the Bellows window when that is open; the front door glows cream | the pause-menu-only bow |
| **Pick strip** | a container with 2–4 useful items (not in the slice) | above the container (§3.6 sizes) | unchanged |
| **The Stalls** | on audience events only: laughs (rising 60–150 px by tier), gasp, shush, "BEHIND YOU!", chants, boos | the bottom band x ∈ [S+560, W−S−440] on the layer under the HUD (so carried chips 3–4 stay on top), never a target; **hidden at rest** (the laugh track keeps them present by ear) | the 40 px resting row |
| **Overview** | hidden in Act I (one floor, ≤ 4 rooms); a pinch-out still works; **Map** in the pause panel; from Night 3 a 144 px button only while Bellows is on the other floor | (W−S−168, T+300) when shown | the permanent overview button |
| **Tomatoes** | on a catch (Night 4+): three 44 px tomatoes in the transient meter for 2.5 s | inside the meter | inside the permanent meter |

**Removed from the play screen:** the empty tray slots, the idle Figgis chip, the permanent meter and banner, the
Overview button in Act I, the footlight sprites (the footlights are light, §1.3), the resting Stalls row.

**What moves into the panels:**
- **Pause panel** (pauses): Resume · Retry · Take a Bow (after ★) · **Hint** (Figgis steps 2–3, §6.4) · **Map** (the
  Overview of tonight's set; tap a room to peek) · Settings · Playbill. Header: the Applause total, tomatoes, Curtain
  Calls so far.
- **Script panel** (tap the chip or the meter; pauses; centred 1000 × 680, rows 84 px, text 44 px, icons 72 px): every
  line with its ribbon / candle, "???" lines, the sealed Big Number, **his routine strip** with rigged stations stamped
  with the red beret (§4.2), and tonight's loading-card rule as a one-line reminder.

**Over the world (2D, anchored to 3D points):** his thought bubble (§3.9: 200 × 170, icon 112, ring 12 px, glyph 60,
ear pips 3 × 24); pun captions (88–104 px Lilita One, 6 px navy outline; 1.2 s, stamp-in 1.6 → 1.0 over 4 f); bonus
stamps beside the caption (64 px: "MELTDOWN! +8", "COMBO! +4", "NEAR MISS! +2", "EMBARRASSED! +5"); the previews,
Hush's thought, needs clouds, item bubbles, the rig ring and the safety-net marker (§3.5).

**Hints never cover the action (binding placement rules):**
- **Protected rects**, recomputed every frame on screen: Hush's projected bounding box + 48 px; Bellows' + 48 px; his
  thought bubble; the prop Hush is at (its projected rect + its preview); the four always-on hit rects + 48 px; the
  Bellows window.
- **Placement priority:** his bubble (never moves, except to clamp inside the safe area) > Hush's thought > danger
  markers (the safety-net hiding marker) > passive previews > container item bubbles > the Figgis card > captions and
  stamps. A lower item that would overlap a higher one or a protected rect slides sideways (≤ one cloud width), then
  up (≤ 150 px), then waits. Passive previews may be covered by Hush's thought (they are faded then).
- **Danger is sacred:** during an entry warning, a "?" fill, a chase or a reaction, all hints and previews hide; the
  only teaching allowed is the safety-net hiding marker (`ghost_hide` and the Director's safety net). Queued hints fire
  1.0 s after it is safe.
- **Hints point at the world, never at text:** a ghost finger on the spot (approaching from the side away from Hush),
  the spotlight pool on the floor in front of the spot (§3.5 N4), or Figgis's picture card; no arrows over characters.
- **The middle band y 250–880 holds no always-on or persistent HUD** — only world-anchored bubbles, previews and
  captions, and three short-lived contextual pieces that obey the protected rects (the edge badge in the outer 160 px,
  the Figgis card, the pick strip).

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ (II) [▤ ● ● ○ · · ☆]    ┌ APPLAUSE ◔ 64 ┐ +35         ┌─ BELLOWS WINDOW ──┐    │
│  pause + Script chip    └ RUNNING GAG ×1.5 ▬▬▬░░ ┘    │ 400×225, only when│    │
│ [Figgis] (nudge / Hint)   (transient: 2.5 s)          └[next]─ he matters ┘    │
│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ y 250 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [BOW ▶] (after ★)  │
│                     (   his bubble 200×170   )                                 │
│ [edge   world only: previews, Hush's thought, rig ring, item bubbles, captions │
│  badge]  (no always-on or persistent HUD between y 250 and y 880)              │
│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ y 880 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ (Clarence/⏩) [itm][itm] (only while carrying)  ˙ Stalls: laughs only ˙ (ACT)  │
└────────────────────────────────────────────────────────────────────────────────┘    │  400×225, only    │     │
│ [Figgis] (nudge / Hint)   (transient: 2.5 s)          └[next]─ if needed ─┘     │
│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ y 250 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ [BOW ▶] (after ★)│
│                     (   his bubble 200×170   )                                 │
│ [edge   world only: previews, Hush's thought, rig ring, item bubbles, captions  │
│  badge]  (no always-on or persistent HUD between y 250 and y 880)              │
│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ y 880 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ (Clarence/⏩) [itm][itm] (only while carrying)  ˙ Stalls: on laughs only ˙ (ACT) │
└────────────────────────────────────────────────────────────────────────────────┘
```
HUD anchors to the safe-area corners (symmetric side inset `S = max(left, right)`), sits ≥ 24 px inside it, and
the bottom-centre never holds a touch target. On tablets (logical height > 1250, or 4:3) the HUD scales ×0.8. The 3D
view renders full-bleed, but the camera keeps Hush and every live prop of her room inside the safe rect (§3.7 C6).
Text during play ≥ 44 px; HUD numbers 48–60 px; captions 88–104 px.

### 3.9 Readability overlays
- **Thought bubble:** his **next** activity icon with a countdown ring that starts ≥ 4 s before he leaves; a
  route change (fix-up, lure, herding) replaces the icon **the same tick** it is queued. Left of it, the
  **awareness glyph** (48 px), always shown: *specs dangling* (specs off), *specs on*, *blinded* (butter/flour/hair),
  *zZ* (asleep), *stars* (reacting: blind and deaf). Under it, up to 3 **ear pips** (squeaks he heard in the
  last 8 s).
- **Stare strip:** an amber band (20 px tall, alpha 0.35) on the floor from his feet in his facing direction,
  as long as his *moving* sight; a darker inner segment (alpha 0.55) as long as his *frozen* sight. With specs
  on it turns red-amber and runs to the wall. Grey while he's blind. Setting to hide it.
- **Footprints:** his walking line for the next 1.5 s, drawn as faint footprints, whenever he's in Hush's room
  or the next one.
- **Noise rings:** every noise draws an expanding ring to its true radius over 0.5 s (6 px, alpha 0.5 → 0);
  squeaks yellow, runs and rigs white. The lure radius is learnable.
- **Room-entry warning:** ≥ 1.5 s before he enters Hush's room: door-handle jiggle (or his legs on the stairs),
  footsteps crescendo panned to his side, PiP pops, and the Stalls shout "BEHIND YOU!" if she's exposed.
- **(v1.2) Sizes and floor decals in 3D.** His thought bubble (2D, anchored above his head) is **200 × 170 with a
  112 px icon, a 12 px ring, a 60 px awareness glyph and 3 × 24 px ear pips**, and always shows the *next* activity.
  The stare strip, the footprints and the rings are **floor decals** on the 3D stage floor (flat, unlit, no depth
  write): the **stare strip** lies on the floor in front of the acting lane (z −1.5 … −0.5, §7.1) from his feet in his
  facing direction, the darker inner segment his frozen range, grey while he's blind; the **footprints** show his next
  1.5 s of walking; the **noise rings** expand to their **true radius** — a run's white ring to 2.5 m (500 px) every
  0.5 s, a B rig's every 0.5 s, and the squeak's yellow ring to its true hearing reach (her room and every open
  doorway) — so the player sees how far a noise carries. The tap feedback (a 0.5 m white destination ring, dotted path
  decals, the tapped spot's pop), floor pins, the W3 queued ghost ring and the N4 spotlight pool are decals too; the
  characters' blob shadows (r 0.34 m Hush, 0.45 m Bellows, 32 % alpha) are the only shadows. On the entry warning the
  Bellows window opens (when he is off-screen).

### 3.10 Text, icons and haptics
- Text: **≥ 36 px anywhere; 44 px for anything read during play; 48–56 px HUD numbers; 80–96 px captions and
  titles**; always a 4–6 px navy outline over the world. Icons and pantomime over words; Script lines are the
  only sentences during play. Fonts: Lilita One (display), Nunito ExtraBold (UI) — both OFL. (v1.2) The 3D HUD
  (§3.8) sizes follow REDESIGN_3D §2.6: text read during play ≥ 44 px, HUD numbers 48–60 px (the meter's number is
  60 px), captions 88–104 px Lilita One with a 6 px navy outline.
- Haptics (`Input.vibrate_handheld`, VIBRATE permission only): tap 8 ms/0.3; ring 50 % 8 ms; rig done
  30 ms/0.7; prank accent 40 + 60 ms; near-miss 20 ms; caught 3 × 30 ms; Meltdown stomps 3 × 60 ms.
  Rate-limited (≤ 6 pulses/s).

### 3.11 Settings and accessibility
Relaxed mode (unlimited tomatoes, "?" windows ×1.5, no badge, no penalty) · Tap-to-rig · Left-handed ·
Hotspot hints (Always / Long-press / Off) · Stare strip (On/Off) · Audience volume · Voice volume · Music ·
SFX · Haptics · Reduce motion (no shake, punch-ins ≤ 1.15×) · Reduce flashing · Text +20 %.
Everything is readable with the sound off (the mute test, §10.4).
**(v1.2) New settings:** **Previews** (Always / After 6 s idle / Off — Off keeps Hush's thought, the rig ring and the
safety-net marker; it takes the place of the badge-era Hotspot hints) · **Room dimming** (On/Off; Off lights every
built room fully) · **Outline +50 %** (thicker character and prop outlines). Reduce motion also removes the camera
yaw and makes camera moves 0.25 s linear (§3.7). **Debug section** (owner builds only; the defaults come from the
build's boot configuration): Hush's head (B's head / the proposed head, §1.2 — shown only when the variant exists),
the Bellows window (`sim` "when the sim shows him" / `lean` "only when he's coming", §3.7), MSAA and render scale (the
device-performance toggles), and "Night 1/2 previews (work in progress)".

---

## 4. Neighbour AI and secondary characters

A deterministic 60 Hz simulation (TECH §3). Same inputs → same Night, always. Randomness is cosmetic and
lives in the view (variant picks, fidgets).

### 4.1 The routine: a clock you can read
Each Night gives Bellows an ordered **loop of 4–6 activities** (§7.2). An activity is
`{id, station, room, duration, facing, specs, awareness, squeak_bit, panto, hooks[], bend}` (activity library
§4.1.1). He walks to the station, performs, and moves on; after the last activity the loop repeats.

- **Loop length** (measured by the solver with Hush idle, walking included): **Act I ≤ 60 s** (D1, §2.4 rule 5;
  Night 1 58.7 s, Night 2 55.4 s — the draft Nights 3–4 are re-measured against it in Stage 3, §7.2), Act II
  80–95 s, Act III and Gala 90–120 s.
- **Micro-gags** (timed, D1): every activity and fix-up detour a Night uses carries authored beats
  `{id, at_s, len_f, emote, gag}` in `activities.json` (`at_s` from the activity's start; `gag` is the one-line
  joke the animator builds from; table: `docs/review/s2-content/micro_gags.md`; ids are stable — add, never rename):
  1. The first beat lands 2–3 s into the activity, then one every 5–8 s, never two within 5 s. A gated or long
     activity repeats its list every `mg_cycle_s` (20 s on the warm-up) while he keeps performing.
  2. A non-chase walk longer than 5 s plays a walk beat every 4 s (`walk_hum`, `cravat_tug`, `walk_scale`).
  3. Each beat is a ≈ 1 s joke readable at 50 px (36–72 f; the slice uses 48–60 f: admires himself in the kettle,
     trills, conducts the air), overlaid on the activity clip, with an **emote** (sing, hum, smug, laugh, tut, sniff,
     yum, yawn) that the HUD edge bubble draws when he is off-screen. The emote is null only where the gag has no
     face (`peer_under_piano`: his head is under the piano); such a beat never plays in the edge bubble.
  4. Beats never change Applause, temper or senses. They are dropped, not deferred, while he reacts, plays a squeak
     bit, is Curious, Searching, Spotted, chasing, melting down or Exhausted, pauses at a doorway, bumps into Hush,
     or during a face-to-face or the Mirror rounds.
  5. A beat is "not dead air" only when the player can see it (§2.4 rule 2).
- **Speeds (px/s):** Bellows walks **240** (Irked +5 %, Steaming +10 %, Livid +15 % — never more), chases
  **600**. Hush tiptoes **400** (silent) and runs **720** (noisy). Doors: Hush 0.35 s, Bellows 0.5 s.
  Stairs: Hush 1.0 s, Bellows 1.8 s.
- **Interruptions never reorder or skip the loop.** A prank that fires during activity A ends A (unless the
  hook says `resume`, §5.3). **Detours** — fix-ups (§5.4), lures (§5.6), herding Beryl (§4.8) — are inserted
  *before the next activity*, and appear in the bubble the same tick they are queued. Afterwards he carries on
  with the next activity in the loop.
- **Player-led gates** (Prologue and Night 1 only): an activity may wait for the player (e.g. "ends 2 s after
  the honey is rigged"; Night 1: "his first activity ends 2 s after the first rig, or at 25 s"). From Night 2 on,
  routines are pure clocks.

#### 4.1.1 Activity library (v1)
| id | Station (room) | Dur. | Specs | Awareness | Hooks (prank → mark) | Squeak bit |
|---|---|---|---|---|---|---|
| `warmup` | gramophone (parlour), faces left | **8 s** | off | normal | ALLEGRO-GO-GO! @0.5 s (drops needle) | note cracks into a yodel; "…the pipes." |
| `tea` | tea counter (kitchen), **faces left**: he stands right of the counter (≈ 3000) with the pantry and the sink behind his back, so ACHOO-RIA! and HOT & COLD blast him backwards into the sink | **8 s** | off | normal | KETTLE DRUM @3 s (resume) · ACHOO-RIA! @7 s (sip) · SOPRAN fix-up target | tea goes up his nose |
| `pickles` | pickle shelf (kitchen) | **5 s** | off | normal | IN A PICKLE @1 s | — |
| `snack` | fridge (kitchen) | **5 s** | off | normal | COLD OPEN @1 s | — |
| `rinse` | sink (kitchen) | 5 s | off | normal | TAP DANCE @1 s | — |
| `paper` | recliner (parlour), sits facing right | **8 s** | **on** | normal | LIFT-OFF @1 s (pulls lever) · EYE-POPPING NEWS @2 s (opens paper) | rips the paper in half |
| `fire` | fireplace (parlour) | **5 s** | off | normal | BELLOWS BLOWS @2 s | — |
| `mirror` | cheval mirror (hall), faces right | **5 s** (the three MIRROR, MIRROR rounds run inside the reaction) | off | normal | MIRROR, MIRROR @0.5 s | his comb flies off |
| `phone` | phone table (hall) | 8 s | off | normal | SOMETHING FISHY @1 s (answers) | argues with the caller: "I did NOT squeak!" |
| `clock` | grandfather clock (hall) | 5 s | off | normal; uses the clock case (in-use) | TIME'S UP @1 s | — |
| `piano` | piano (parlour), faces left | 12 s | off | normal; **panto** | GRAND EXIT @2 s (fortissimo) | BONG — wrong chord, glares at the piano |
| `gargle` | basin (bathroom) | 5 s | off | normal | SOPRAN-OH-NO @1 s | — |
| `bath` | bath (bathroom); uses the bath (in-use) | 24 s + progress bar | off | **absorbed** (sees moving ≤ 250 px) | SNAP DECISION @1 s (duck serenade) · IN OVER HIS HEAD @4 s | only periscope eyebrows rise from the foam |
| `radiator` | radiator (landing) | 5 s | off | normal | PIPE DOWN! @1 s | — |
| `dress` | wardrobe (bedroom); uses the wardrobe (in-use) | 6 s | off | normal | — | — |
| `nap` | bed (bedroom) | 18 s + sleep bar | off (specs on the bedside table) | **asleep** | PILLOW TALK @1 s · KIDDING AROUND @1 s · BUTTER-FINGERS @end (specs back on) | bolts upright, bonks the headboard, snores on |
| `feed_beryl` | feed bin (conservatory), **bends** | 6 s | off | normal | SWEET TOOTH @2 s | *Beryl* headbutts *him* (small) |
| `roses` | hose (garden) | 8 s | off | normal | HOSED @3 s | — |
| `marrow` | marrow bed (garden), **bends** | 6 s | off | normal | MARROW ESCAPE @2 s | — |
| `stroll` | garden path (walks 5,260 → 5,560) | 6 s | off | normal | PENNY PINCHER (pass, per coin) | — |
| `polish` | trophy shelf (dressing room) | 8 s | **on** | normal | AWARD-WINNING @2 s | — |
| `cloak` | cloak dummy (dressing room), eyes shut | 6 s | off | blind while dressing | TUTU MUCH @1 s | — |
| `answer_door` | front door (hall) | 6 s | off | normal | Delphine arrives (scheduled) | — |
| `host_tea` | chaise (parlour), with Delphine | 14 s | off | normal | SPIT TAKE @3 s · FAN MAIL @8 s | — |
| `tango` | gramophone floor (parlour), with Delphine | 12 s | off | normal | IT TAKES TWO @4 s | — |
| `rehearse` | garden stage (Gala) | 14 s | off | normal; **panto** | SPOTLIGHT STEALER @2 s | — |
| `hunt` | walks the parlour 2350 → 1650, past the piano (Prologue only, scripted) | 6 s | **on** | searching | — | — |
| *any, while Livid* | — | — | — | — | — | "WHO SQUEAKED?!" rage aria at the ceiling (once per Night) |

That is exactly **10 squeak bits**.

- **Durations in bold are the D1 values** (v1.1, `d1_changes.md` ALL-1): they bring the Act I loops to ≤ 60 s and
  every hook mark still fits (KETTLE DRUM @3 s and the ACHOO-RIA! sip @7 s in an 8 s tea; LIFT-OFF @1 s and
  EYE-POPPING NEWS @2 s in an 8 s paper). The draft Nights share them. **No activity lasts under 5 s**, so the
  bubble's ring always reads. A gated activity (§4.1 player-led gates) keeps performing past its duration.
- **Detours** (not loop activities; shown in the bubble the tick they are queued): the fix-ups `fixup_dry`,
  `fixup_sink`, `fixup_honey`, `fixup_mirror` (4 s at the station, one micro-gag each, §5.4); `curious`, `search`,
  `herd_beryl` (no micro-gags); and **`exit`** — the Prologue's scripted walk-off after the hunt: the bubble shows
  the exit icon, he stomps toward the stairs, no hooks, only the walk beats play.

### 4.2 Telegraphs (the readability triad)
1. **What he'll do next:** the thought bubble (§3.9) with a ring that starts ≥ 4 s before he leaves; route
   changes shown the same tick. The Script panel shows his whole loop as an icon strip with rigged stations
   stamped with Hush's beret.
2. **What he can see:** the awareness glyph (always on) and the stare strip on the floor. Specs going on is a
   loud "tink" and a glint.
3. **When he's coming:** ≥ 1.5 s entry warning (door jiggle, footsteps, PiP, "BEHIND YOU!"). **No ambushes**:
   if a route change would bring him into Hush's room sooner, he pauses at the doorway to straighten his cravat
   until 1.5 s have passed (not during a chase).
4. **His temper:** his body is the meter (§4.5), echoed by the PiP frame colour and the Running Gag fuse.

### 4.3 Senses — the specs rule
Loading card (Night 2): ***"Hold FREEZE to be a statue. Specs off, he only spots what moves. Specs on, get out of sight."***

Sight covers **his current room, in the direction he faces**, to the wall. Through an open doorway he faces,
he also sees 300 px into the next room if he is within 250 px of that doorway. He never sees behind himself,
into a hiding spot he didn't watch Hush enter, or up/down stairs.

| His state | Sees Hush **moving** within | Sees Hush **frozen** within |
|---|---|---|
| **Specs off** (default) | 600 px ahead | 250 px ahead |
| **Specs on** (reading, polishing, Curious, Searching, On Guard, Livid) | the whole room ahead | 600 px ahead |
| **Absorbed** (bath) | 250 px | 0 |
| **Blinded** (butter, magnifier, hair over eyes) / **Exhausted** | 150 px | 150 px |
| **Asleep**, **Reacting** (+1 s after), **Meltdown**, dressing eyes-shut | 0 | 0 |

- **Moving** = walking, running, rigging, picking, squeaking (0.3 s), diving, or simply standing: an idle
  Hush fidgets. **Only FREEZE is still.** Hidden = invisible.
- **The "?" window.** When he can see her, a "?" over his head fills over **2.0 s (Prologue), 1.0 s (Act I),
  0.8 s (Act II onward)** — never less; ×1.5 in Relaxed. If she leaves his sight (hides unseen, freezes outside
  frozen range, leaves the room, gets behind him) it drains at 2× speed. A "?" that reached ≥ 50 % and drains to
  zero is a **NEAR MISS** (gasp, then a relieved laugh; +2 Applause, max 3 per Night). A full "?" becomes
  "!": he gives chase.
- **Hiding in view:** diving into a hiding spot while he can see her doesn't help — the "?" keeps filling on the
  spot; if it fills he walks over and pulls her out (a catch).
- **The bump rule (fair version):** his footprints show his next 1.5 s of walking. If he walks into a frozen
  Hush on his line: the **first bump each Night** is a gag — "Pardon", he pats the "statue", walks on 2 steps,
  then double-takes into the normal "?" window. Later bumps stop him and open the "?" window at once. A bump is
  never an instant catch.
- **Hearing.** Squeaks are heard in Hush's room and in rooms joined to it by an open doorway (§5.6). Running:
  500 px. Big (2.5 s) rigs: 500 px, a ring every 0.5 s. Beryl's bleat: her room and neighbours. Delphine's high
  C: the whole house. A noise he investigates makes him **Curious** (below).

### 4.4 States and priorities
Priority: **Chase > Reacting / Meltdown > Spotted > Curious > Detour (fix-up, herd) > Routine**.

| State | Enter | Behaviour | Exit |
|---|---|---|---|
| Routine | default | activities in loop order | — |
| Detour | residue, lure, herding | walks to the detour station; shown in the bubble | → next activity |
| Curious | a lure (3 squeaks), a big-rig noise, Delphine's high C, a near miss | walks to the source, **specs on**, looks both ways 3 s, shrugs | → next activity |
| Spotted | "?" full | "!" sting, 0.3 s double take | → Chase (or pull-out if she dived in view) |
| Chase | Spotted | runs 600 px/s toward Hush; **catches within 80 px** | 4 s → **wheeze** 1.5 s (bent double, harmless) → 2 s more → if she's out of sight ≥ 1.5 s: Search |
| Search | lost her | specs on, looks around the room 6 s; never opens a hiding spot unless he saw her enter it | → On Guard |
| On Guard | after Search or a catch | 15 s with specs on | → Routine at the next activity |
| Reacting | a prank fires | plays the reaction; blind and deaf until 1 s after it ends | → Detour (residue) or next activity |
| Meltdown | temper ≥ 100 after a reaction | 5.5 s tantrum (§4.5) | → Exhausted |
| Exhausted | after Meltdown | sits and pants 8 s; sight 150 px, specs off | → next activity |
| Asleep | `nap` | blind and deaf (only the squeak bit wakes a snort) | → next activity |

**Chase extras:** when Hush runs through a door with him chasing within 500 px, she slams it — he bonks it
(1 s stun, laugh) once per chase. **Chase Trips:** any rigged STEP prank on his chase path fires
("HE FELL FOR IT!"): the chase ends in a reaction, and it counts as a Running Gag link.

### 4.5 Temper — the escalation engine
**Gains:** small prank +25, medium +35, large +45, signature +55; a squeak bit or panto round +5; Beryl's
headbutt +45; a prank witnessed by Delphine +10 extra. **Decay:** temper holds for 6 s after the latest gain,
then falls 2 per second. The hold and decay **pause** during fix-up detours and reactions.

| Tier | Temper | Body tell | Behaviour | Reaction cut |
|---|---|---|---|---|
| Calm | 0–19 | peach face, sideburns flat | routine, specs off | T1 |
| Irked | 20–44 | pink, sideburns bristle, grawlix bubble | +5 % speed | T1 |
| Steaming | 45–69 | red, ear steam, stomps | +10 % speed; at a doorway he pauses 1.0 s and **looks back** (visible stop-and-turn) | T2 |
| Livid | 70–99 | beetroot, sideburns puffed, **specs jammed on** | +15 % speed; specs on (§4.3) | T3 |
| **MELTDOWN** | ≥ 100 | — | 5.5 s tantrum: three stomps shake the house, loose props in *his current room* drop (authored per room), quake-armed pranks in that room fire, the Stalls chant "PIPE-DOWN! PIPE-DOWN!". Then **Exhausted** 8 s; temper resets to 60 so the chain goes on. | 3 variants |

- **The Running Gag** is live while temper ≥ 20. Each prank that lands while it's live is the next **link**
  (multipliers §6.1). A Meltdown counts as a link. When temper falls below 20 the Running Gag ends and links
  reset. The fuse bar shows the time left: remaining hold + (temper − 20) / 2 seconds.
- One small prank from Calm gives an 8.5 s window, a medium 13.5 s, a large 18.5 s. Small → medium → large in
  quick succession (25 → 60 → 100+) ends in a Meltdown.
- **You want him furious, and furious means specs on.** That is the core risk/reward.
- **Angrier = a new joke:** the same prank plays its T2 or T3 cut (§5.8) — a longer hold, a bigger launch, an
  extra falling prop, a bespoke last beat.

### 4.6 Chase, caught, retry
- **Caught** (grab within 80 px, a pull-out, or a lost face-to-face) → **Busted Cam** 1.0 s: a split-frame replay
  of the moment he saw her, with a dotted sight line (tap skips after 0.5 s) → **the Lecture** 2.2 s: he lifts
  Hush by her braces at arm's length and sings a scolding, finger-wagging on the beat, her feet pedalling
  (3 variants) → a 0.2 s wipe → the **doorstep**: he plonks her down, slams the door, the knocker bonks her and
  a tomato splats (0.6 s). **Control returns ≤ 4.0 s after the grab.**
- **Kept:** every rig, every landed line, all Applause. **Lost:** the carried items (fly home), 5 Applause, the
  current Running Gag. He is **On Guard** for 15 s.
- **Tomatoes:** 3 per Night from Night 4; the third brings **the Hook**, which ends the Night as it stands
  (Curtain Calls already earned are kept). Unlimited in the Prologue, Nights 1–3 and Relaxed mode.
- **Retry** from pause or results: back in control in ≤ 1.5 s, in place, no scene reload.

### 4.7 Fairness rules (binding; each is a headless test, TECH §8.6)
1. No catch without a "?" window of at least 0.8 s (2.0 s Prologue, 1.0 s Act I) that Hush could have escaped.
2. A hiding spot entered unseen is 100 % safe — except a red-badged in-use spot, which still opens a "?" window.
3. ≥ 1.5 s entry warning before he enters Hush's room (except in a chase).
4. His next activity is shown ≥ 4 s before he leaves the current one; route changes show the same tick.
5. He is blind and deaf while Reacting and for 1 s after.
6. Same inputs → same Night (state hash identical).
7. Every Script line stays achievable from any reachable state (no soft-locks); items respawn in 20 s.
8. Every catch is logged with its cause and replayed by the Busted Cam.
9. Temper changes his speed by at most 15 % and never skips or reorders activities.
10. Beryl's headbutt on Hush is never a catch.

### 4.8 Beryl the goat (Acts II–III)
Cheap rig (box body, rubber-hose legs, springs for ears/beard/tail/bell), simple rules, no pathfinding
surprises.
- **Moods:** **Dozing** (in the conservatory sunbeam; wakes on any noise within 300 px, or on a schedule),
  **Grazing** (wanders a fixed lane conservatory ↔ garden, x 3,950–5,650, at 70 px/s, pausing 3 s at each end),
  **Besotted** (for 20 s after Hush drops or offers an apple within 200 px: follows Hush at 150 px, bleating every
  6 s — each bleat is a noise ring: a liability, and a way to lead her).
- **The bend-over rule (the universal finisher):** when anyone bends (activities tagged `bend`, a pick-up, getting
  up from a slip) within 300 px of an awake Beryl facing them, she paws the ground for 0.6 s (telegraph, bell
  jingle) and headbutts. **Bellows** flies along the room's authored landing table (roses, pond, compost,
  hamper) — first headbutt each Night not already part of a prank is **BUTT OF THE JOKE** (+3, +45 temper, a
  Running Gag link once per Night). **Hush** tumbles 300 px with a noise ring — a gag, never a catch.
- **Only on camera:** a headbutt on Bellows only fires when his room is on screen or in the PiP; otherwise
  she paws and gives up.
- **Blame:** a prank that fires with Beryl in the room gets a bellowed "BERYL!" and an indignant "MEH!" (bark only).
- **Herding (a lure):** if Bellows sees Beryl indoors (Besotted, following Hush, or after SWEET TOOTH), he drops
  what he's doing to herd her out: a 10 s shove-and-tug detour, queued and shown in the bubble at once.
- She never eats rigged items (v1 has no eating), never gives Hush away, is never harmed.

### 4.9 Dame Delphine (Act III, Gala)
- **Arrives** by the doorbell at a scheduled time (a doorbell icon on his loop strip); he answers and hosts.
  Her loop while visiting: tea on the chaise (while he `host_tea`s) → sings at the piano (while he plays) →
  powders her nose upstairs 15 s (while he makes fresh tea and preens) → back.
- **Sight:** only with her **opera glasses up**: every 12 s she lifts them (1.0 s visible lift), looks for 3 s,
  lowers them. Glasses up: sees moving Hush within 600 px ahead, frozen within 250 px (the specs-off table).
  Glasses down: sees nothing. Her own "?" fills over 1.0 s.
- **If she spots Hush:** a **high C** — "INTRUDER!" — cracks the nearest mirror and sends Bellows running to
  the spot (Curious at chase speed). She never catches Hush herself.
- **Witness:** any prank reaction on Bellows in her room, in front of her, is **EMBARRASSED!** (+5 Applause,
  +10 temper) and ends with the shared **Suppressed** beat: a strained grin, a twitching eye, a squeaky
  "ha-ha, my dear" (T1/T2/T3 cuts still apply before it).
- Anything that happens to her is his fault ("HORACE!"). No prank targets her directly.

### 4.10 Figgis and the Stalls
- **Figgis** introduces each new system once, the first time it matters (the loading card + a one-time ghost
  finger for each new input). He is the hint ladder (§6.4). He can be muted; he never covers play.
- **The Stalls** boo Bellows' first entrance (playfully), shush when Hush shares his room, gasp at a "?", laugh
  with relief at near misses, shout "BEHIND YOU!", chant at Meltdowns, stand for ×3 chains, and at the top tier
  one of them tumbles out of their seat laughing. They never laugh at nothing, or when Hush is caught (they go
  "Awww" and throw the tomato).
- **(v1.2) The Stalls are hidden at rest.** They rise out of the dark apron below the stage lip only on audience
  events — laughs (60–150 px by tier), a gasp, a shush, "BEHIND YOU!", chants, boos — and sink back when the moment
  is over; the laugh track keeps them present by ear. They are never a touch target. Figgis appears only on a nudge,
  a card cue or Hint (§3.8).

---

## 5. Pranks

### 5.1 The prank model
`{id, caption, size: S|M|L|SIG, room, rig_point, needs[], steps[{prep: Q|S|B, needs}], trigger, hooks[],
reaction: {archetype, variants, landing}, residue, tags[], nights[]}` — full schema in TECH §4.4.

- **Prep tiers:** Q 0.8 s, S 1.5 s, B 2.5 s (B rigs are noisy: a 500 px ring every 0.5 s). Total hold time per
  Night stays under 20 s on the ideal route.
- **States:** locked (sealed Big Number, or not in this Night) → available → in progress (partial ring, kept) →
  **rigged** (armed; Hush's beret stamp on the prop; the Script strip stamps his station) → fired (reaction) →
  **landed** (spent: the station greys out; each prank scores once per Night). A **fizzle** (the trigger happens
  but a condition is missing, e.g. no goat nearby) is a joke too: he smirks "hmph", the Stalls go "Awww", and the
  prank stays rigged.
- **Guessable, never moon logic:** every item sits in the room or container where you'd expect it, and every rig
  point that needs an item shows the item's silhouette in a grey thought-cloud once Hush has seen it.

### 5.2 Items and containers (16 items)

| Container (room) | Items (per Night, only those that Night needs) |
|---|---|
| **CONFISCATED box** (hall) — his box of toys taken from the street's children | squeaker, magnifier, balloon (green, helium-filled), wind-up croc |
| **Fridge** (kitchen) | kipper, butter |
| **Pantry** (kitchen) | flour, sherbet, treacle, salt |
| **Bathroom cabinet** | bubble bath |
| **Potting bench** (conservatory) | apple, feathers (a feather duster) |
| **Piggy bank** (hall phone table) | coins (one pick = 3 coins) |
| **Costume trunk** (dressing room) | tutu, "their song" record |

Items have 1–2 uses (the squeaker serves KETTLE DRUM or PILLOW TALK; the balloon serves SOPRAN-OH-NO or MARROW
ESCAPE). Used items restock in 20 s.

### 5.3 Triggers
- **USE** — an activity hook at a mark (seconds into the activity). Hooks marked `resume` let the activity
  continue after the reaction (KETTLE DRUM: he still drinks his tea), enabling same-activity chains. Hooks marked
  `fixup` also fire when a fix-up detour visits that station — this is how residue builds chains (§5.4).
- **PASS / STEP** — he walks over the rig point (RUG BURN, PENNY PINCHER). STEP pranks also fire mid-chase
  (**Chase Trip**, §4.4).
- **QUAKE** — a Meltdown in the prank's room (PRIMA BALLERINA only).
- **THIRD-PARTY** — Beryl or Delphine completes it (HOSED, KIDDING AROUND, SPIT TAKE, FAN MAIL).
- **KNOCK-ON** — another reaction's landing lands him on it (Double Acts, §5.5).
- Only **one punchline at a time:** a hook that would fire while Bellows is already reacting waits (the prank
  stays rigged).

### 5.4 Residue → fix-up → chain (the chaining spine)
Every residue immediately queues a **fix-up detour** to a known station kind, shown in his bubble **the same
tick**. The station is the nearest of that kind on his floor by path (garden counts as ground floor); a Night may
override. The detour lasts 4 s at the station; its `fixup` hooks fire at 1 s. **Rig the fix-up station in advance
and the fix-up becomes the next link.** A prank that fires during a fix-up interrupts it and the residue stays —
that's how combos form. Several residues queue fix-ups oldest first. The Running Gag fuse pauses during fix-ups.

1. **Fix-up stations MUST lie in the Night's rooms or its backstage rooms** — never in a room the Night keeps
   closed. Hush never enters a backstage room.
2. **Overrides** (`fixup_overrides`, per Night): one named station for a kind, and it MUST be a station of that
   kind. v1 uses three: **Night 1 DRY → parlour fireplace** (otherwise the nearest DRY is the sun lounger in the
   closed conservatory); **Night 3 HONEY → kitchen tea counter** (SQUEAKY's trip downstairs); **Night 9 DRY →
   landing radiator** (SPIT TAKE's soak sends him upstairs, past RUG BURN, to PIPE DOWN!).
3. **A reaction may clear residues** (`clears`) as part of the joke: **TAP DANCE clears FRAZZLED** — the drench
   flattens a flipped bouffant into dripping spaniel ears, so HOT & COLD leaves only SOAKED and one fix-up (the
   parlour fireplace, ≈ 10 s from queued to done in Night 1) instead of two; the frizz is still seen for the second
   the Double Act takes. MIRROR, MIRROR clears FRAZZLED, FEATHERED and COSTUME (he flees).

| Residue | Look (overlay) | Fix-up station kind | Stations (v1) | Chains into |
|---|---|---|---|---|
| **SOAKED** | drips, spaniel-ear sideburns, squelching steps | DRY | parlour fireplace · landing radiator · conservatory sun lounger | BELLOWS BLOWS, PIPE DOWN! |
| **FLOURY** | ghost-white tint, a puff every step | SINK | kitchen sink · bathroom basin | TAP DANCE |
| **STICKY** | the next thing he touches sticks to his hand | SINK | kitchen sink · bathroom basin | TAP DANCE |
| **SQUEAKY** | every sung/said line +12 semitones | HONEY | kitchen tea counter | ACHOO-RIA!, KETTLE DRUM |
| **FRAZZLED** | frizzed or flipped bouffant (flipped = BLINDED until fixed) | MIRROR | hall cheval mirror · bathroom basin mirror · dressing mirror | MIRROR, MIRROR |
| **FEATHERED** | feathers everywhere; a small sneeze every 6 s | MIRROR | as above | MIRROR, MIRROR |
| **COSTUME** | tutu, trophy helmet, jelly helmet, long johns | MIRROR | as above | MIRROR, MIRROR |

**Combos** (two residues at once; +4 COMBO! each, first time per Night; unique look + a 1.5 s combo beat):

| Combo | Residues | The joke |
|---|---|---|
| **DOUGH MAN** | SOAKED + FLOURY | He looks down: he's dough. Squelch-puff steps; Beryl tries to lick him. |
| **POODLE** | SOAKED + FRAZZLED | His bouffant balls into a pom-pom; his "PIPE DOWN!" comes out as a yap. |
| **CHICKEN** | STICKY + FEATHERED | Feathers stick: every sung note clucks; Clarence squeaks back, smitten (heart). |
| **MAD MAESTRO** | FRAZZLED + SQUEAKY | A wild-haired chipmunk tenor, conducting furiously at nobody. |

**Combo rule per Night** (`rules.combos`: the allowed combo ids; absent = all): **Nights 1 and 2 allow none
(`[]`)** — POODLE stays Night 3's Big Number, in any order of play (TAP DANCE then ACHOO-RIA! or LIFT-OFF, or the
reverse). A disallowed pair keeps both residues and their fix-ups, but shows no combo look and plays no combo beat,
event or score. The fairness fuzz checks it, and the curtain call never suggests a combo on such a Night.

### 5.5 Double Acts and Chase Trips
A **Double Act** is an authored knock-on: A's reaction physically carries him into a rigged B as one continuous
fall (A's landing target *is* B's rig point). B fires inside A's reaction and is the next Running Gag link. Six in
v1, two per Act, each a Big Number or an optional flourish:

| Double Act | A → B | Where |
|---|---|---|
| **HOT & COLD** | ACHOO-RIA! blasts him backwards on his stool into the sink → TAP DANCE | Night 1 Big Number |
| **UP IN SMOKE** | LIFT-OFF drops him into the log basket, jolting the bellows → BELLOWS BLOWS | Night 4 |
| **MARROW MAYHEM** | MARROW ESCAPE's chase ends by Beryl; he bends for the balloon → headbutt → pond | Night 5 Big Number |
| **ENCORE!** | GRAND EXIT flips him out of the piano onto the stair runner → RUG BURN | Night 6 |
| **TEA FOR TWO** | SPIT TAKE soaks him; Delphine fans him dry with her rigged fan → FAN MAIL | Night 8 |
| **CURTAIN CALL** | SPOTLIGHT STEALER: he bends for a thrown rose → Beryl headbutt → pond | Gala Big Number |

**Chase Trips:** RUG BURN and PENNY PINCHER are STEP pranks; if he chases Hush over them they fire ("HE FELL FOR
IT!"). Getting chased is a scoring chance, not only a failure.

### 5.6 Free verbs
**The squeak (Clarence).** He hears a squeak when he is in Hush's room or a room joined to it by an open doorway.
When he hears one:
1. If the **panto** conditions hold (below) → a panto round.
2. Else he gains an **ear pip** (shown under the glyph, fades 8 s after the last squeak) and, if his current
   activity has a **squeak bit** that hasn't been used 3 times this activity, it plays (a 1–2 s micro-reaction,
   +5 temper; Applause +2 the first time that bit plays this Night, +1 the second, 0 after). Otherwise he turns
   his head: "…the pipes?" (1.0 s).
3. The **third ear pip** within 8 s is a **lure**: he goes Curious — walks to the squeak's spot, specs on, looks
   3 s (shown in the bubble at once). **Lure fatigue:** after two lures within 60 s the Clarence ring greys; a
   further third pip only gets a "PIPE DOWN!" shouted from where he stands.
- Squeaks while he's asleep only trigger the nap bit; while he's reacting they're ignored. Squeaking is
  *moving* for 0.3 s, so squeak behind his back, not in his face.

**The panto bit — "BEHIND YOU!"** (from Night 6). Conditions: he is at an activity tagged `panto` (warmup,
piano, rehearse), specs off, below Livid, not reacting; Hush is in his room, **behind him**, within 600 px, not
hidden. A squeak starts a round:
- **Round 1:** ear twitch (0.5 s; the Stalls shout "BEHIND YOU!"), he turns (0.8 s), looks (1.2 s), turns back.
- **Round 2** (squeak within 8 s): turn 0.6 s, look 1.0 s.
- **Round 3** (squeak within 8 s): the **feint** — an eyebrow wiggle (0.6 s tell), he turns back *without*
  looking (0.4 s), then whips round (0.5 s) and looks 1.5 s.
- If Hush is frozen beyond his frozen range (or out of sight) whenever he looks: "…the pipes." Round scores
  +2 / +3 / +5 (bits) and +5 temper each; surviving round 3 = **"PANTO BIT!"** caption and a T3 laugh. Seen during
  a look → the normal "?" window. One panto bit per activity visit. One input (squeak) plus holding FREEZE; the
  skill is reading the tells, not reflexes.

**Mirror, Mirror** — push-your-luck with one input (#15 below).

### 5.7 The catalogue: 32 original pranks
Format: **#n `id` CAPTION** (size) · rig point · needs ← source · prep · trigger → the joke *(reaction archetype)*
· residue · Nights. Temper gain by size (§4.5); Applause base by size weight, normalised per Night (§6.1).

**Kitchen**
- **#1 `achoo_ria` ACHOO-RIA!** (M) · tea counter · free (the pepper pot beside the honey) · Q · USE `tea` @7 s,
  also HONEY fix-ups → rule-of-three sneeze: "ah (20 f)… ahh (24 f)… AHHH (30 f)…", false stop (20 f), CHOO
  (3 f accent, 5 f hit-stop); he faces left at the counter (§4.1.1), so he rockets backwards on his stool into the
  sink behind him, bouffant flipped over his face
  *(SNEEZE_BLAST)* · FRAZZLED (blinded) · P, 1, 3, 5, 8.
- **#2 `tap_dance` TAP DANCE** (S) · sink · free (twist the spray tap) · Q · USE `rinse` @1 s, also SINK fix-ups,
  also DA HOT & COLD → a face blast; he wrestles the hose like a python and loses *(DRENCH)* · SOAKED; clears
  FRAZZLED (the drench flattens the flipped bouffant, §5.4) · 1.
- **#3 `kettle_drum` KETTLE DRUM** (M) · kettle · squeaker ← CONFISCATED box · Q · USE `tea` @3 s (`resume`),
  also HONEY fix-ups → the kettle squeaks a melody; he harmonises, cracks on the high note, the lid pops onto his
  nose — then pours his tea anyway *(SING_CRACK)* · — · 1.
- **#4 `in_a_pickle` IN A PICKLE** (L) · pickle shelf · free (over-tighten the onion jar) · S · USE `pickles` @1 s
  → he strains, purples, sideburns spring; POP — onions pinball off the pans; he slips on one and windmills down
  *(STRAIN_SLIP)* · — (an onion stays on his head 20 s) · 1.
- **#5 `cold_open` COLD OPEN** (M) · fridge · free (stack the fridge shelf) · S · USE `snack` @1 s → avalanche:
  he ends up in a jelly-mould helmet with a sausage boa *(AVALANCHE_HELMET)* · STICKY + COSTUME · 2.

**Parlour**
- **#6 `allegro_go_go` ALLEGRO-GO-GO!** (M) · gramophone · free (speed lever to ×3) · Q · USE `warmup` @0.5 s →
  his record screeches to triple speed; he babbles his scales as a chipmunk, spins like a top and collapses dizzy
  under orbiting notes *(DIZZY_SPIN)* · — · P, 4, 6, G.
- **#7 `lift_off` LIFT-OFF** (L) · recliner · free (crank the recliner spring) · B · USE `paper` @1 s → he pulls
  the lever: catapulted, his cravat snags the chandelier, he swings, drops into the log basket *(LAUNCH_CEILING)*
  · FRAZZLED · 1, 4, 7. (Source of DA UP IN SMOKE.)
- **#8 `eye_popping_news` EYE-POPPING NEWS** (M, functional) · newspaper · magnifier ← CONFISCATED box · Q ·
  USE `paper` @2 s → specs on behind a magnifier: his eyes balloon ×4 and he bumbles blind for 15 s, bowing to
  the hat stand *(BLIND_BUMBLE)* · BLINDED 15 s (a stealth window) · 2, 6.
- **#9 `bellows_blows` BELLOWS BLOWS** (M) · fireplace bellows · flour ← pantry · Q · USE `fire` @2 s, also DRY
  fix-ups, also DA UP IN SMOKE → POOF: ghost-white, and so is his portrait; he coughs a smoke ring *(POOF)* ·
  FLOURY · 4, 8.
- **#10 `prima_ballerina` PRIMA BALLERINA** (L, quake) · beneath the chandelier · free (loosen the chain) · B ·
  QUAKE (a Meltdown in the parlour) → the chandelier drops round his waist like a tutu, candles and all; he
  tiptoes out on pointe, mortified *(DROP_ON)* · COSTUME · 4.
- **#11 `grand_exit` GRAND EXIT** (★) · piano · free (kick out the brake wedge) · B · USE `piano` @2 s → his
  fortissimo chord sets the piano rolling; he chases it, still playing, across the parlour and the hall; it flips
  at the stair foot with him inside; one muffled chord; the lid rises — he's wearing it *(signature)* · FRAZZLED ·
  6 (BN). (Source of DA ENCORE!)
- **#12 `it_takes_two` IT TAKES TWO** (★, Delphine) · gramophone · "their song" ← costume trunk · S · USE `tango`
  @4 s → he can't resist the tango with Delphine; the dip… RRRIP: split trousers, spotty long johns, frozen
  mid-dip with a strangled grin while she fans herself furiously *(signature, always Suppressed)* · COSTUME · 10.

**Hall**
- **#13 `something_fishy` SOMETHING FISHY** (M) · phone · kipper ← fridge · Q · USE `phone` @1 s → his agent
  calls; he speaks pompously into a kipper; it flops and slaps him twice; slow burn to the Stalls *(FISH_SLAP)* ·
  — · 2.
- **#14 `times_up` TIME'S UP** (M) · grandfather clock · free (over-wind it) · S · USE `clock` @1 s →
  machine-gun chimes; he clings on as the clock pogoes across the hall ("a-a-a-a"); the pendulum door smacks his
  bum *(JACKHAMMER_CLING)* · FRAZZLED · 2.
- **#15 `mirror_mirror` MIRROR, MIRROR** (★) · cheval mirror · free (lift out the glass, B), then **stand in the
  frame and hold FREEZE** · USE `mirror` @0.5 s, also MIRROR fix-ups → push-your-luck: round 1 (1.2 s) he preens;
  round 2 (1.2 s) he leans in and squints; round 3 (1.0 s tell) he lifts his specs toward his nose. **Release FREEZE
  at any moment to WINK**: the scream scales with rounds survived (T1 / T2 / T3) — he flies backwards into the coat
  stand, which spins him like a revolving door. Still frozen when the specs land → he pokes the "glass": a 0.8 s
  "?" — bolt or be caught. No Hush in the frame → he preens at an empty frame, too vain to notice (fizzle)
  *(signature)* · clears his FRAZZLED/FEATHERED/COSTUME (he fled) · 2 (BN), G.
- **#16 `rug_burn` RUG BURN** (L, STEP, anger-gated) · stair foot · free (pull the stair rods) · S · PASS going
  **up** while Steaming or angrier, or in a chase → the runner whips away; he surfs it down, across the hall and out
  of the front door; 4 s later he walks back in wearing half a hedge *(SURF_OUT)* · FRAZZLED · 4, 6, 9.

**Bathroom and landing**
- **#17 `sopran_oh_no` SOPRAN-OH-NO** (M) · basin (throat spray) · balloon ← CONFISCATED box · Q · USE `gargle`
  @1 s → helium for throat spray: a chipmunk-soprano aria; he stops, tries again, slow burn *(SQUEAKY_VOICE)* ·
  SQUEAKY (→ honey in the kitchen: a trip downstairs) · 3.
- **#18 `snap_decision` SNAP DECISION** (M) · bath rim (the rubber duck) · wind-up croc ← CONFISCATED box · Q ·
  USE `bath` @1 s → he serenades his "duck"; it snaps his nose; soprano shriek; he leaps, tangles in the shower
  curtain and lands in the laundry basket *(SCARE_LEAP)* · SOAKED · 3.
- **#19 `in_over_his_head` IN OVER HIS HEAD** (★) · bath · bubble bath ← bathroom cabinet (S) + sherbet ← pantry
  (Q): 2 steps · USE `bath` @4 s → a foam mountain; he rises inside a giant bubble still singing, drifts out of the
  door and down the stairwell, and pops into the hall umbrella stand, wearing it *(signature)* · SOAKED · 4 (BN),
  7, 10.
- **#20 `pipe_down` PIPE DOWN!** (L) · airing cupboard (boiler valve) · free · B · USE `radiator` @1 s, also DRY
  fix-ups at the radiator → the pipes whistle his tune back, wrong; he sings louder; they answer louder; "PIPE
  DOWN!" — a steam blast *(STEAM_DUEL)* · FRAZZLED · 3, 9.

**Bedroom**
- **#21 `pillow_talk` PILLOW TALK** (M) · pillow · squeaker ← CONFISCATED box · Q · USE `nap` @1 s → SQUEAK…
  SQUEAK… on the third he punches the pillow; it bursts; a feather blizzard and a sneeze fit *(FEATHER_BURST)* ·
  FEATHERED · 3.
- **#22 `butter_fingers` BUTTER-FINGERS** (M, functional) · bedside table (his specs, while he naps) · butter ←
  fridge · Q · USE `nap` @end (specs back on) → blinded by buttered lenses he serenades the hat stand, dips it and
  kisses its hand *(BLIND_BUMBLE)* · BLINDED 15 s · 3.
- **#23 `kidding_around` KIDDING AROUND** (★, Beryl) · bed · lead a Besotted Beryl to the bed (apple ← potting
  bench), then tuck her in (Q) · USE `nap` @1 s → he snuggles his "hot-water bottle"; it bleats; goat eyes 5 cm
  from his; the wildest take in the game; she headbutts him off the bed, through the door and into the laundry
  basket *(signature)* · — · 7 (BN).

**Dressing room**
- **#24 `tutu_much` TUTU MUCH** (M) · cloak dummy · tutu ← costume trunk · S · USE `cloak` @1 s → he dresses with
  his eyes shut, humming; opens them at the mirror: a tutu; a 70 f slow burn. If he reaches Delphine before the
  MIRROR fix-up, he meets her in it (EMBARRASSED) *(COSTUME_BURN)* · COSTUME · 9, 10.
- **#25 `award_winning` AWARD-WINNING** (L) · trophy shelf · free (loosen the shelf) · S · USE `polish` @2 s →
  trophies bonk him in rising pitch; "Best Baritone 1987" lands over his head as a helmet; a muffled "PIPE DOWN!"
  *(AVALANCHE_HELMET, variant B)* · COSTUME · 9.

**Conservatory and garden**
- **#26 `hosed` HOSED** (M, Beryl) · by the hose · apple ← potting bench, dropped (Q); an awake Beryl within
  400 px trots over and stands on the hose · USE `roses` @3 s → nothing comes out; he peers down the dead nozzle;
  Beryl trots off; SPLOOSH *(DRENCH, variant C)* · SOAKED · 5, 7. Fizzle without Beryl on the hose.
- **#27 `marrow_escape` MARROW ESCAPE** (M) · marrow bed · balloon ← CONFISCATED box · S · USE `marrow` @2 s → his
  prize marrow is a balloon: it shrieks round his head, deflating; he chases it round the garden
  *(BALLOON_CHASE)* · — · 5, 6. (Source of DA MARROW MAYHEM.)
- **#28 `penny_pincher` PENNY PINCHER** (L, Beryl, STEP) · 3 coin spots on the garden path · coins ← piggy bank ·
  Q × 3 · PASS (`stroll` or a chase) → too stingy to pass a coin, he bends — once, twice — and on the third bend, if
  Beryl is within 300 px and facing him, HEADBUTT into the roses *(HEADBUTT_LAUNCH)* · FRAZZLED · 5, G. Fizzle: he
  pockets the coins, richer.
- **#29 `sweet_tooth` SWEET TOOTH** (M, Beryl) · Beryl's feed bin · treacle ← pantry · Q · USE `feed_beryl` @2 s →
  treacle everywhere; Beryl licks his face adoringly and follows him indoors, so he must herd her out (a 10 s
  detour) *(GOAT_KISS)* · STICKY · 6, 7.

**With Delphine**
- **#30 `spit_take` SPIT TAKE** (M, Delphine) · sugar bowl on the tea tray · salt ← pantry · Q · USE `host_tea`
  @3 s → he serves Delphine; she sips… holds it… and sprays him full in the face; he grins through gritted teeth
  *(DRENCH, always Suppressed)* · SOAKED · 8, 9, G. (Source of DA TEA FOR TWO.)
- **#31 `fan_mail` FAN MAIL** (M, Delphine) · Delphine's fan · feathers ← potting bench · Q · USE `host_tea` @8 s →
  she fans herself beside him: a feather storm; his sneeze blows her beehive back; "HORACE!"
  *(FEATHER_BURST, variant B)* · FEATHERED · 8, 10, G.

**Gala**
- **#32 `spotlight_stealer` SPOTLIGHT STEALER** (★) · the old stage spotlight in the garden-stage wings · free
  (aim it at the apron) · B · USE `rehearse` @2 s → he steps into the light and can't help himself: he bows to the
  real Stalls and launches into his aria; they pelt him with tomatoes (and a few roses); he slips on a tomato into
  the pond *(signature, fourth wall)* · SOAKED · G. A **required** line of the Gala, not its Big Number: the
  Big Number is the CURTAIN CALL Double Act that grows out of it (§5.5, §7.2).

Sizes: 1 S, 18 M, 7 L, 6 signatures. Signatures (bespoke 4–7 s clips, unique sting, 0.5× approach, 45–60 f
paper-bordered freeze-frame): #11, #12, #15, #19, #23, #32.

### 5.8 The reaction kit (buildability)
Every non-signature reaction is one of **22 archetypes**, parameterised by prop, landing target, residue and
tier. A prank adds only its prop, its anticipation beat and its residue.

| # | Archetype | Used by |
|---|---|---|
| 1 | SNEEZE_BLAST | ACHOO-RIA! (and FEATHERED's small sneezes) |
| 2 | DRENCH (A/B/C) | TAP DANCE, HOSED, SPIT TAKE |
| 3 | SING_CRACK | KETTLE DRUM |
| 4 | STRAIN_SLIP | IN A PICKLE |
| 5 | AVALANCHE_HELMET (A/B) | COLD OPEN, AWARD-WINNING |
| 6 | DIZZY_SPIN | ALLEGRO-GO-GO! |
| 7 | LAUNCH_CEILING | LIFT-OFF |
| 8 | BLIND_BUMBLE (A/B) | EYE-POPPING NEWS, BUTTER-FINGERS |
| 9 | POOF | BELLOWS BLOWS |
| 10 | DROP_ON | PRIMA BALLERINA |
| 11 | FISH_SLAP | SOMETHING FISHY |
| 12 | JACKHAMMER_CLING | TIME'S UP |
| 13 | SURF_OUT | RUG BURN |
| 14 | SQUEAKY_VOICE | SOPRAN-OH-NO |
| 15 | SCARE_LEAP | SNAP DECISION |
| 16 | STEAM_DUEL | PIPE DOWN! |
| 17 | FEATHER_BURST (A/B) | PILLOW TALK, FAN MAIL |
| 18 | COSTUME_BURN | TUTU MUCH |
| 19 | BALLOON_CHASE | MARROW ESCAPE |
| 20 | HEADBUTT_LAUNCH | PENNY PINCHER, BUTT OF THE JOKE, MARROW MAYHEM, CURTAIN CALL |
| 21 | GOAT_KISS | SWEET TOOTH |
| 22 | SUPPRESSED (ending beat) | any witnessed reaction |

Plus: Meltdown × 3 variants, Exhausted, the Lecture × 3, 4 combo beats, 10 squeak bits, panto turns, 6 signatures.

**Tiers are procedural modifiers on the same clip, not new clips:**
- **T1** (Calm, Irked): the authored clip.
- **T2** (Steaming): hold × 1.2, face tint one step redder, one extra shake.
- **T3** (Livid): hold × 1.5, launch/travel distance × 1.3, maximum residue intensity, one falling prop from the
  room's prop table 20 f after the accent (picture frame, his hat, a sausage), and one bespoke last beat from a
  shared pool of four (70 f slow burn to the Stalls; a failed dignity recovery; a bow that topples; a single tear).
- **Suppressed** (Delphine watching): the settle is replaced by the SUPPRESSED beat.
- **Variants:** archetypes with several users get A/B(/C) variants; a returning prank alternates variants.
  "+NEW!" marks the first time a prank × tier is ever seen (feeds the Programme, Stage 4).

### 5.9 Originality check
Checked against every gag in `docs/research/nfh.md` §9 and its NfH2 list. None of these appear: glue on
binoculars, laxatives, gag dynamite, a letterbox mousetrap, shaving-foam/cream swaps, aftershave or deodorant
sabotage, cheese on a flower, sheet-music scribbles, anything on a towel, photo-album glue, bath-pearl or
bathwater swaps, toothbrush swaps, sun-cream, weedkiller, coffee, dentures, wine/vinegar, growth formula,
washing machines, fish food, trampolines, book swaps, barbells, pipe tobacco, shotguns, a nail in a gramophone,
hunting horns, medal boxes, microwave eggs, floor soap/marbles/banana/roller skate, electrified puddles, aerials,
defaced portraits, clogged toilets, sawn furniture, drawing pins, fart cushions, alarm-clock cactus, prank calls,
football swaps, releasing animals. Where we share an object (a gramophone, a phone, a portrait), the mechanism
and the joke are different. The framing has no TV, cameras, viewers, rating %, seasons, "takes" or golden awards.

---

## 6. Scoring, goals, failure, hints and the laugh track

### 6.1 Applause (explainable by design)
**Applause = Σ gags + Σ bits + Σ named bonuses − 5 per catch** (never below 0; shown as an integer).

1. **Gags (pranks):** `base × chain multiplier`.
   - **Base:** size weights S 1.0, M 1.4, L 2.0, ★ 3.0. Each Night normalises the bases of its **prank lines**
     so that **all prank lines landed unchained add up to exactly 70** (largest-remainder rounding; enforced by
     the content lint). Goal lines (Meltdown, panto, "embarrass him twice", combos, Double Acts) carry no base —
     they pay through the multiplier and the bonuses.
   - **Chain multiplier** (Running Gag link): link 1 ×1, link 2 ×1.5, link 3 ×2, link 4+ ×3. A Meltdown is a link.
2. **Bits** (never multiplied, never links): squeak bit +2 / +1 / 0 (per bit per Night); panto rounds +2 / +3 / +5;
   BUTT OF THE JOKE +3.
3. **Named bonuses — only these four exist**, each shown as a stamp during the reaction's hold:
   **MELTDOWN! +8** (max 2 per Night) · **COMBO! +4** (each combo once per Night) · **NEAR MISS! +2** (max 3 per
   Night) · **EMBARRASSED! +5** (per witnessed prank).
- The needle always moves for a reason the player can name, with the stamp on screen when it happens.
- Above 100 the meter sparkles **ENCORE!** (display cap 150).
- Solver acceptance per Night: the ideal route reaches 100–140; a required-lines-only route lands 35–60.

### 6.2 The Script and the Curtain Calls
- **The Script** is a Goose-style to-do list of **punchlines, never instructions** ("Bellows talks to a fish", not
  "put the kipper on the phone"). 3–6 lines plus the sealed **Big Number**; never more than 7. Required lines wear
  a red ribbon. Undiscovered optional lines show "???" until Hush has seen their rig point. The Big Number
  unseals (with a drum roll) when the required lines are done. A line solved after a step-3 hint gets a small
  candle icon — the only hint penalty.
- **The Big Number can never be soft-locked.** A chain Big Number (a Double Act, a combo, a witnessed prank, a
  link count) that the player achieves while it is still sealed counts the moment it unseals. The landed pranks
  it needs are **re-armed on unseal** (`rearm_on_unseal`; they score no base the second time) — without this,
  landing ACHOO-RIA! alone in Night 1 would make HOT & COLD impossible. Re-armed in v1: N1 ACHOO-RIA!, TAP DANCE ·
  N2 TIME'S UP (the frazzle → mirror fix-up → MIRROR, MIRROR link) · N3 SNAP DECISION, PIPE DOWN! · N5 MARROW
  ESCAPE · N8 SPIT TAKE, BELLOWS BLOWS · N9 TUTU MUCH · N10 IT TAKES TWO, FAN MAIL, IN OVER HIS HEAD, TUTU MUCH ·
  Gala SPOTLIGHT STEALER.
- **Curtain Calls** (independent, shown as three stars):
  - ★ **Opening Night** — every required line. Unlocks Take a Bow and the next Night.
  - ★★ **Full Script** — every line, Big Number included.
  - ★★★ **Standing Ovation** — Applause ≥ 100 when the curtain falls.
- **The curtain call (results)** is a fixed, time-bound sequence played by the Night itself (no scene change):
  1. **Next Night ▶** (default, 240 px) and **Retry** (in place ≤ 1.5 s) are live from the call's **first frame**;
     **Playbill** is the third button. A tap anywhere else skips the current step.
  2. The steps, unskipped (a *repeat viewing* = the Save already holds a result for this Night):

     | Step | First viewing (s) | Repeat viewing (s) |
     |---|---|---|
     | The curtain falls | 0.8 | 0.8 |
     | Hush steps out on the apron and bows; roses rain | 1.6 | 0.8 |
     | Results: the Applause counts up with the needle; a stamp per Curtain Call (0.3 s each); the why-missed line; "+NEW!" chips on reactions (prank × tier × variant), bits and combos never seen before | 2.4 | 1.9 |
     | The **Gag Reel** (the 3 best moments; on a repeat, the best one plus any "+NEW!"), while Bellows wanders on in his residue on the stage band behind the panel, double-takes at the audience, slow-burns, and the curtain drops on his head | 8.0 | 4.0 |
     | **Total** | **12.8** | **7.5** |

  3. **Prologue** (no Curtain Calls): fall 0.8 → Hush bows, roses 1.6 → the **title card** slams down (a 0.3 s
     drop with a squash on landing, the marquee bulbs chase, the `title_slam` sting; held 1.2 s) 1.5 → the Applause
     total 1.5 → the Gag Reel (the sneeze) 5.0 = **10.4 s**. "Night 1 ▶" is live from the fall. The title card
     never appears during play.
  4. **Gate 0** (the debug stage door's sneeze test, `g0_sneeze`; it ends 3 s after the sneeze's reaction): fall
     0.8 → the sneeze's Gag Reel 5.0 = **5.8 s**, with **Again ▶** (default; retry ≤ 1.5 s) and **Stage door**, both
     live from the first frame.
  5. **The why-missed line** — one line, the first that applies: (1) a required line missed ("4/5 lines — Bellows
     still hasn't talked to a fish"); (2) the Big Number still sealed or open; (3) an optional line missed;
     (4) Applause < 100 → the first hint the Night can offer and the player hasn't maxed, in the order: one more
     Running Gag link ("Applause 91 — land one more prank inside a Running Gag"), a Meltdown, near misses, bits, a
     combo, EMBARRASSED!; (5) catches that cost Applause; (6) ★★★ → the standing-ovation line. The Prologue has its
     own line. A Night never suggests what it can't offer: no combo where `rules.combos` is `[]`, no
     Meltdown where none can happen, no EMBARRASSED! without Delphine.
  6. **The Gag Reel** scores moments by Applause (ties: the higher tier, then the later); a knock-on chain is one
     moment. Each moment is re-staged in the real set by replaying the deterministic Night from a snapshot, so every
     prop, residue, launch and camera move is the one the player saw, framed like the live punch-in.
  7. The Stalls' "BOW! BOW!" chant plays only on Nights that end with a bow (not the Prologue or Gate 0).
  8. After the last Night a build contains (Night 2 in the slice), Next ▶ shows "To be continued…" (2 s, tap
     skips), then the Playbill with the next Night locked. Next ▶ never loads a draft episode.

### 6.3 Failure and retry
Soft failure only (§4.6): the Lecture, tomatoes, the Hook from Night 4. No restart from zero, no energy, no
paid continues, no time limits. Relaxed mode removes the Hook and widens "?" windows ×1.5 with no badge.

### 6.4 Hints — Figgis's ladder (free, unlimited)
1. **Nudge:** after 40 s without progress (no rig progress, item or line), Figgis's chip pulses "psst" and the
   next useful hotspot sparkles. (v1.2) **Step 1 adds the spotlight pool:** already after 6 s without input, the
   "next useful" spot gets a soft warm pool of light on the floor in front of it and its preview at full size (§3.5
   N4) — pointing at the world, never at text, and never during danger (V2); at 40 s without progress Figgis's bust
   pops up "psst" (§3.8) over the same pool. **Steps 2–3 are the Hint button of the pause panel** (the Figgis chip
   is no longer on screen at rest).
2. **Cue card:** tap Figgis → a picture card (*item → target*, room icon) for 4 s, plus an edge arrow.
3. **Show me:** tap again → the game pauses and a ghost Hush acts out the next step at 2× (≤ 6 s); for timing
   lines a ghost Bellows shows *when*.
"Next useful" = the first unfinished required line (then optional, then the Big Number) whose next step is
possible now, using each line's authored hint data (TECH §4.6).

### 6.5 The laugh track (the Stalls)

| Tier | Trigger | Sound | Stalls |
|---|---|---|---|
| T0 titter | a rig completes; Hush's snicker | 2–3 voices, 0.6 s, −18 dB | two heads nudge |
| T1 chuckle | a bit; a gag < 12 Applause | 5–6 voices, 1.2 s | heads bob |
| T2 laugh | a gag 12–24 | 12–14 voices + one "HA!", 2 s | heads bounce |
| T3 laugh + applause | a gag > 24, link 2, a combo, a panto bit | 20+ voices, 3 s | heads rise 60 px |
| T4 roar | link 3+, a Meltdown, a signature | roar, whistles, stamping, 4–5 s | everyone stands; one head tumbles out of its seat laughing |
| specials | — | "Ooooh!" *before* painful-looking accents; a gasp on "?"; relieved laugh on near misses; "Awww" on fizzles and catches; "shhh"; "BEHIND YOU!"; the "PIPE-DOWN!" chant; boos on his first entrance | — |

- (v1.2) The Stalls column plays **from hidden**: at rest there are no heads on screen (§4.10); each tier raises
  them into view (60–150 px by tier, T4 everyone standing) and they sink back afterwards.
- The laugh starts at the **start of the hold** (6–12 f after the accent), ducks 6 dB under his voice, never
  repeats the same file twice in a row, never uses an air horn, and is earned only (a titter at most on setup).
- Audience-volume slider. Fallback crowd (applause, whistles, "ooh", a kazoo "ha-ha" choir) if the formant
  laughter reads as creepy in the week-1 A/B (§9.5).

---

## 7. Content

### 7.1 The world: No. 7 Humdrum Road ("Crescendo")
One side-view house, a dollhouse cut in half, opening up across the Acts. Floor pitch 700 px (640 px interior +
60 px slab). World x grows to the right; ground floor line y = 0, upper floor line y = −700. Hush lives at No. 9
(its porch and pond are visible beyond the porch and past the fence). Room widths are binding; station x values
are guides that the house geometry may shift ≤ 80 px to satisfy the hotspot lint (the solver measures real
timings).

```
UPPER (y −700)            ┌ LANDING 800 ┬ BATHROOM 1000 ┬ BEDROOM 900 ┬ DRESSING RM 800 ┐
                          │ airing cpbd │ basin+mirror  │ wardrobe    │ costume trunk   │
                          │ radiator    │ cabinet scales│ bed pillow  │ rail  mirror    │
                          │ stair head  │ bath  basket  │ bedside hat │ trophies dummy  │
GROUND (y 0) ┌ PORCH 500 ┬ HALL 1000 ─stairs┬ PARLOUR 1300 ┬ KITCHEN 1100 ┬ CONSERV. 800 ┬ GARDEN 1500 ┐
             │ doorstep  │ cupboard box  │ gramophone    │ tea counter  │ feed bin     │ hose  roses │
             │ (No. 9 →) │ phone mirror  │ piano recliner│ pickles fridge│ hamper sun  │ marrow path │
             │           │ clock  stairs │ fire chaise   │ table pantry │ lounger bench│ shed compost│
             └───────────┴───────────────┴───────────────┴ sink backdoor┴──────────────┴ pond  fence ┘
```

| Room (x range) | Stations, left → right (approx x) | Hiding spots | Opens |
|---|---|---|---|
| Porch (0–500) | doorstep (caught Hush lands here, 350) | — | N1 (in every Night from Night 1: the doorstep and the RUG BURN exit; the Prologue can't be failed) |
| Hall (500–1500) | front door 520 · coat cupboard 600 · CONFISCATED box 790 · phone table + piggy bank 980 · cheval mirror 1160 · grandfather clock 1340 · stair foot 1450 | coat cupboard; clock case (in use at `clock`) | N1 |
| Parlour (1500–2800) | gramophone 1640 · piano 1840 · recliner + newspaper 2080 · fireplace + bellows + log basket 2330 (chandelier above) · chaise 2560 with a side table (tea tray, Delphine's fan; Act III) | behind the piano; behind the chaise (Act III) | P |
| Kitchen (2800–3900) | tea counter (kettle, honey, pepper) 2960 · pickle shelf 3130 · fridge 3300 · table 3470 · pantry 3640 · sink + window 3800 · back door 3900 | pantry curtain; under the table | P |
| Conservatory (3900–4700) | feed bin 4020 · wicker hamper 4190 · sunbeam (Beryl) 4360 · sun lounger 4480 · potting bench 4620 | wicker hamper | N5 |
| Garden (4700–6200) | hose + tap 4820 · roses 5000 · marrow bed 5180 · coin path 5260–5560 · Beryl's shed 5700 · compost bin 5880 · pond 6060 · (Gala stage 5000–5800, spotlight wings 5850) | Beryl's shed; compost bin | N5 |
| Landing (1000–1800) | stair head 1050 · airing cupboard 1250 · radiator 1450 · window 1650 | airing cupboard | N3 |
| Bathroom (1800–2800) | basin + mirror cabinet 1930 · bathroom cabinet 2110 · scales 2280 · bath + duck 2520 · laundry basket 2700 | bath (in use at `bath`); laundry basket | N3 |
| Bedroom (2800–3700) | wardrobe 2920 · bed + pillow 3200 · bedside table 3420 · hat stand 3590 | wardrobe (in use at `dress`); under the bed | N3 |
| Dressing room (3700–4500) | costume trunk 3800 · costume rail 3980 · dressing mirror 4160 · trophy shelf 4300 · cloak dummy 4420 | costume rail | N9 |

Doorways between adjacent rooms are always open, except the front door and back door (they swing when used).
Stairs join the hall foot (1450, 0) and the landing head (1050, −700). Hush enters by the kitchen window
(Prologue–N4) or the garden fence gate (N5 on); a caught Hush always lands on the porch doorstep.
Locked rooms in a Night are shown dimmed behind a velvet rope ("backstage"). (v1.2) In 3D **a room the Night keeps
closed is not built at all**; only a *backstage* room that the Night's routine passes through (the Prologue's and
Gate 0's hall) is built dark: architecture only, stage light 0.3, a velvet rope at the doorway.

**(v1.2) The 3D stage** (REDESIGN_3D §3, §5; the sim stays 1-D per floor — the view owns depth).
- **World units.** **1 m = 200 sim px** (a sim x of 3,000 px is 15.0 m; the kitchen's 2,800–3,900 px are 14.0–19.5 m).
  Floor `f` stands at y = 3.5 f m (the 700 px pitch); a height of y px above the floor line is y / 200 m. **Room height
  3.2 m, set depth 2.4 m.** Every room x, station, rect and use point of the table above maps directly; nothing in the
  house data changes for 3D. Speeds: Hush tiptoes 2.0 m/s and runs 3.6 m/s; Bellows walks 1.2 m/s and chases 3.0 m/s.
- **Depth bands** (z toward the camera, metres): **+0.25 the stage lip** (a thin gilded edge; below it the dark apron
  where the Stalls rise) · **0 … −0.4 the apron** (nothing stands here) · **−0.4 … −1.6 the acting lane** —
  characters walk at **z −1.0**, Bellows stands at z −1.4 at his stations, Hush steps back toward a prop to reach it,
  the floor decals live here (the stare strip z −1.5 … −0.5) · **−1.6 … −2.4 the set band** (furniture, props, hiding
  spots; its front edge, z −1.65 … −1.80, is the **reach row**) · **−2.4 the back wall**, a flat colour field.
- **The frame of the stage.** **Wing flats** divide the rooms: at each room boundary a cream partition (`#E9DCC4`, 0.22 m
  thick, no outline) runs from the back wall to z −1.4, so the front of the lane is open between rooms — the doorway is
  implicit and a character is never hidden behind a door frame. Doors that really close (front door, back door) are
  full-depth flats with the leaf in the lane. No side walls except at the ends of the built set, no ceiling: a dark
  **proscenium header** (`#1D1728`, 0.8 m, a thin gold edge at 3.13 m) closes the top of every frame. Characters
  **cheat out**: the sim's facing is ±x, and the view yaws the body toward the camera — 35° idle or performing, 20°
  walking, 0–10° in face-to-face beats and while reaching (the head turns to the camera instead) — so painted faces
  never go edge-on; props whose front is the readable side are yawed 10–20° toward the camera.
- **Three set layers.** (1) **Architecture**, every Night: walls, floor, the lip, wing flats, doors, windows, the
  stairs, built-in units (kitchen counters and sink unit, fireplace and mantel) — low contrast, no outline, no glow.
  (2) **Furniture / stations**, built only in the Nights that use them. (3) **Props**, small interactives and cue props,
  built only in the Nights that use them.
- **The strike rule (binding).** A furniture piece or prop is on stage in a Night **only if** that Night uses it: a
  station of an activity or detour in its loop (fix-ups after overrides included) and the set pieces that station's
  activity borrows, a rig point of one of its pranks, a container holding one of its items, a listed hiding spot
  (`hides`, §3.4), a reaction landing or knock-on target of one of its pranks, a Director cue prop, a quake prop of a
  room where a Meltdown can happen tonight, the entry / doorstep, or a step a live rig point uses. Everything else is
  **struck** (not built). The view derives each Night's set list from the content; nobody hand-writes it.
- **Density (MUST, checked by the set lint):** **≤ 5 live props per room per Night** (rig points with a prank
  tonight + containers with an item tonight + listed hiding spots; doors, exits and stairs are architecture; target 2–4);
  **≤ 4 set-dressing pieces per room** (non-interactive: a window, a portrait, a lamp, a rail), each ≥ 0.5 m on its
  longest side, low contrast (C* ≤ 30, |ΔL*| ≤ 15 against its wall), never outlined, glowing, previewed or tappable,
  never in the acting lane above 0.45 m and never in the 0.6 m band above a live prop (where its preview sits);
  quake props (§4.5) count as dressing and hang ≥ 2.2 m or sit on the mantel; **one hiding spot per room in Act I**;
  no two live props stacked unless their projected rects keep ≥ 24 px (the slice keeps exactly two such pairs: the
  kettle under the honey in Night 1, the fridge's shelf over its door in Night 2); each room keeps a 1.5 m stretch of
  lane with nothing behind it at head height (the Night-1 kitchen: x 3,180–3,540, the fridge and table struck).
- **Walls are fields, not patterns:** one flat colour per room + one wainscot band 9 L* darker + one picture rail; no
  wallpaper motifs, tiles or panel mouldings; floors plain boards in two tones. **One floor at a time** (§3.7 C5).
  Every live prop reads as its own black shape at 64 px; no two live props of a room share a silhouette family
  (honey jar = squat cylinder + red lid + a tall pepper pot · kettle = round body, spout, arched handle · pickle jar =
  tall glass cylinder, gold lid, white onions · sink tap = tall chrome gooseneck, blue knob · fridge = tall rounded box
  with a chrome bar handle · pantry = dark arched alcove with a gathered curtain · gramophone = a big horn · recliner =
  a fat armchair leaning back · newspaper = a folded broadsheet · piano = a black upright block · CONFISCATED box = a
  crate with a red band · phone = a candlestick telephone · mirror = an oval on a stand · clock = a tall case with a
  round face · coat cupboard = a tall wardrobe with one door line).
- **Scale and reach (the owner's hybrid, R5).** Live and held props are **×1.5** their real size (Bellows' teacup and
  saucer ×1.8, ≥ 0.16 m wide); furniture **×0.8** (counter top 0.75 m, stool seat 0.55 m, armchair seat 0.42 m, table
  0.62 m); architecture is real (doors 2.1 m, rooms 3.2 m). Hush has **look B's arms** (shoulder at 1.127 m, 0.405 m
  from shoulder to wrist; the palm centre 0.09 m and the fingertips 0.23 m beyond the wrist; tiptoe +0.07 m), so:
  - the **reach part** of every live rig prop (what her glove touches) sits in the **reach row** (z −1.65 … −1.80), on a
    shelf or counter ≤ 0.35 m deep; the rest of the prop may extend back;
  - while rigging, Hush stands at the spot's **reach position** (a small x offset from its use point, z −1.6 or
    nearer the camera; view only, eased 0.2 s); a target is **reachable** iff it is ≤ 0.50 m from her nearer shoulder;
  - the **reach band** comes from the placed target's height: **low 0.00–0.55 m** (kneel / crawl), **mid 0.55–1.40 m**
    (standing), **high 1.40–2.15 m** (tiptoe, arms up); **above 1.70 m she needs a step** — **ACHOO-RIA! climbs
    Bellows' own kitchen stool** (seat 0.55 m; the stool wobbles as she steps on and off), and the band fallback for
    other high spots uses **the mime's invisible step** (she pats the air, then steps up 0.30–0.45 m on nothing); a rig
    released mid-step ends with a small hop down before she moves;
  - **Bellows never reaches up:** set pieces come to his hands (the kettle for the pour, the honey jar for the spoon
    beat slide into his grip and home again, keeping their armed look and tag);
  - the view may move a prop's visual and its hit box inside its room to stage it well; `house.json` stays unchanged
    (the sim uses only its use points and rects).
- **Colour and value hierarchy (measured on every set render):** lit walls L* 62–76, C* ≤ 28 (the wainscot 8–10 L*
  darker); a dimmed neighbour's walls L* 45–58, C* ≤ 15; floors L* 40–50; dressing as above; **live props C* ≥ 45 or a
  verb halo** (metal and wood props) with a 3.4 px ink outline and the verb glow (§3.5); **characters** each with
  ≥ 20 % of the silhouette at L* ≥ 85 and ≥ 20 % at L* ≤ 40, a 4.8 px outline and a rim light. Characters are the only
  things with both extremes of the value range and a rim; live props are the only saturated things with an outline;
  everything else is a mid-value, low-chroma field.
- **Room light:** Hush's room is lit 1.0; Bellows' room when it is not hers 0.9; other built rooms 0.78 with 40 %
  desaturation; backstage rooms 0.3 — except a backstage room that holds Bellows, lit 0.9 while he is in it (so his
  mirror gag in the Prologue's dark hall reads in the Bellows window); his own light never drops below 0.9. Changes
  tween over 0.4 s; Room dimming off (§3.11) lights every built room 1.0.

### 7.2 The v1 episode list — Prologue, 10 Nights, Gala Night
Each Night: rooms, the one new rule and its loading card, the cold open, his loop, the Script (R = required,
O = optional, BN = Big Number), pranks (new in **bold**), tomatoes, "?" fill time and the first-clear target.
Loops are listed as activities; walking time is added by the sim and measured by the solver.

Rules for every Night (v1.1):
1. **The porch is in every Night from Night 1** (the doorstep a caught Hush lands on, the RUG BURN exit); the room
   lists below leave it out.
2. Loop times are solver-measured with Hush idle, walking included; the slice Nights (Prologue, 1, 2) are `final`
   and MUST pass the dead-air gate of §2.4 on every route; Nights 3–Gala are `draft` until Stage 3 retunes them.
3. Where a Night departs from the defaults, its **Rules** line says so: fix-up overrides and `rules.combos` (§5.4),
   and the Figgis **card cues**, which fire by id (`card_*`) and are presented by the FTUE. Every Night's Big
   Number re-arms are listed in §6.2.
4. **(v1.2) `hides` and the set.** A Night may list its live hiding spots (`hides`); in Act I it lists one per room
   (§3.4), and every unlisted hiding spot is struck. Absent = every hiding spot of the Night's rooms (the draft Nights).
   Gate 0 (`g0_sneeze`, §6.2) lists the pantry curtain only. Each final Night's **Set** line gives the rooms built and
   lit, built dark ("backstage") and not built, and its live props per room (REDESIGN_3D §3.1, §3.4); the rest of the
   set follows the strike rule of §7.1.

**PROLOGUE — "Curtain Up"** (parlour, kitchen; the hall is backstage) — §2.3. New: squeak, move, hold, hide
(ghost finger each), and ⏩ once. No loading card (its new rule is `basics`) and no Big Number. Loop (scripted,
player-led): `warmup` (waits for the first squeak, then +1 s, max 15 s) → `warmup` (waits until the honey is
rigged, then +2 s; no cap) → `tea` → [FRAZZLED → hall mirror, off-stage] → `warmup` (waits for the lever rig, then
+2 s, or 25 s) → `hunt` (specs on, 6 s, walks 2350 → 1650) → the exit detour upstairs (bubble: the exit icon).
Script: R **ACHOO-RIA!** · R **ALLEGRO-GO-GO!** (lines as "Bellows sneezes up a storm", "Bellows gets in a spin").
No Curtain Calls; unlimited tomatoes; "?" 2.0 s; 60–75 s (Checkpoint G: 62–70 s launch-relative).
**Set (v1.2):** parlour and kitchen built and lit; the hall built dark (architecture, the mirror and the stair foot
he uses, a velvet rope at the doorway; his mirror detour is seen in the Bellows window); porch, upstairs, conservatory
and garden not built. `hides`: the pantry curtain and the piano back. Live props: kitchen 2 (the honey jar with the
pepper pot, the pantry curtain), parlour 2 (the gramophone, the piano back), hall 0 (backstage); the kettle (the tea
station), the sink (the sneeze landing) and Bellows' stool are furniture; dressing: the kitchen window and pendant
lamp; the parlour window, the vase, the picture frame and a portrait.

**ACT I — "The Tenor at Home"**

**Night 1 — "Throat Tea"** (hall, parlour, kitchen)
- New: **carrying items in the tray, the Script, Take a Bow.** Card: *"Your tray carries things. Glowing spots take
  them. Do the Script, then take a bow at the front door."*
- Cold open: at dawn he sings through a megaphone out of his window; Hush's window at No. 9 cracks.
- Loop (~59 s; the first loop ≈ 76 s): `warmup` (first-loop gate: ends 2 s after the first rig, or 25 s) → `tea`
  → `pickles` → `rinse` → `tea` → `paper` (specs on). Two kettle windows per loop (D1): the squeaker round trip to
  the hall box, which is safe while he reads the paper, no longer costs a whole loop.
- Rules: no combos (`rules.combos: []`); fix-up override DRY → parlour fireplace; TAP DANCE clears FRAZZLED, so
  HOT & COLD queues one fix-up (≈ 10 s); on unseal ACHOO-RIA! and TAP DANCE re-arm. Figgis card cues: `card_script`
  at 1 s, `card_tray` at the first pick-up, `card_bow` when every required line is done. First prank ≤ 25 s, every
  fix-up detour ≤ 12 s (§2.4).
- **Set (v1.2):** porch, hall, parlour and kitchen built and lit; upstairs, conservatory and garden not built (the back
  door is a closed door). `hides`: the pantry curtain, the piano back and the coat cupboard — the kitchen table and
  the chaise back are struck, and the solution routes hide in the pantry and behind the piano instead (+≈ 0.43 s of
  tiptoe per hide). Live props: kitchen 5 (honey, the kettle stacked under it with a 27 px gap on screen, pickle jar,
  sink tap, pantry curtain; the fridge and the table struck), parlour 2 (recliner, piano back; the gramophone is
  furniture for the warm-up, the newspaper the paper he reads, the chandelier LIFT-OFF's landing), hall 2 (the
  CONFISCATED box, the coat cupboard; the mirror is furniture for the fix-up). The front door glows cream after ★.
- Script: R "Bellows sings a duet with his kettle" (**KETTLE DRUM**) · R "Bellows gets a face wash" (**TAP DANCE**)
  · R "Bellows loses a fight with a jar" (**IN A PICKLE**) · O "Bellows reads the paper in orbit" (**LIFT-OFF**) ·
  O "Bellows sneezes up a storm" (ACHOO-RIA!) · BN **HOT & COLD** — "Sneeze him into the sink" (Double Act).
- Tomatoes unlimited · "?" 1.0 s · first clear 3–4 min.

**Night 2 — "Something Fishy"** (hall, parlour, kitchen)
- New: **FREEZE and the specs rule** (stare strip appears). Card: *"Hold FREEZE to be a statue. Specs off, he only
  spots what moves. Specs on, get out of sight."*
- Cold open: he pops a child's balloon with his conductor's baton and drops the string in the CONFISCATED box.
- Loop (~55 s; he starts in his recliner, parlour x 2080): `paper` (specs on) → `fire` → `snack` → `mirror` →
  `phone` → `clock`. The v1.0 cycle, rotated to open kitchen-side (D1): he reaches the fridge at ≈ 18 s, so the
  first prank (COLD OPEN) lands at ≈ 19 s instead of ≈ 49 s, and the hall is never sealed in the first 30 s. COLD
  OPEN's two fix-ups (the sink, then the hall mirror, ≈ 21 s) are the window for rigging the phone and the clock.
- Rules: no combos (`rules.combos: []`); on unseal TIME'S UP re-arms. Figgis card cues: `card_specs` at 1 s (he
  opens reading with specs on, so *specs on → get out of sight* is true on screen), then `card_freeze` the moment
  his specs first come off. First prank ≤ 25 s (§2.4).
- **Set (v1.2):** as Night 1 (porch, hall, parlour, kitchen). `hides`: the pantry curtain, the piano back and the coat
  cupboard. **Night 2 has no clock-case hiding spot**: the clock case is struck, its two face-to-face scenario routes
  are retired, and the in-use lesson moves to Night 3 (§3.4). Live props: kitchen 3 (the fridge — one prop with two
  live zones, the upper shelf to rig and the lower door to take the kipper — and the pantry curtain; the sink is
  furniture for the STICKY fix-up), parlour 2 (the newspaper on the recliner's arm, the piano back), hall 5 (the
  CONFISCATED box, the coat cupboard, the phone, the clock, the mirror).
- Script: R "Bellows talks to a fish" (**SOMETHING FISHY**) · R "Bellows rides the grandfather clock"
  (**TIME'S UP**) · R "Bellows wears his dinner" (**COLD OPEN**) · O "Bellows reads the news up close"
  (**EYE-POPPING NEWS**) · BN "Be his reflection" (**MIRROR, MIRROR**). (TIME'S UP frazzles him → the mirror
  fix-up → MIRROR, MIRROR as a link.)
- Tomatoes unlimited · "?" 1.0 s · 4 min.

**Night 3 — "Singing in the Bath"** (+ landing, bathroom, bedroom; stairs, Overview, Bellows-Cam)
- New: **residue → fix-up.** Card: *"Soaked, floury or frazzled? He goes to fix it, and his bubble shows where. Rig
  that spot first."*
- Cold open: 6 a.m. scales through the bathroom window; Hush's alarm clock shakes itself off her shelf.
- Loop (~75 s, upstairs; draft, above the Act-I 60 s target of §2.4, re-measured in Stage 3): `gargle` → `bath` →
  `radiator` → `dress` → `nap`. (Items come from downstairs: carry them up.)
- Rules: fix-up override HONEY → kitchen tea counter (SQUEAKY's trip downstairs); combos allowed (POODLE is the Big
  Number); on unseal SNAP DECISION and PIPE DOWN! re-arm. Figgis card cue `card_fixup`.
- Script: R "Bellows sings soprano" (**SOPRAN-OH-NO**) · R "Bellows meets the bath croc" (**SNAP DECISION**) ·
  R "Bellows argues with the plumbing" (**PIPE DOWN!**) · O "Bellows has a pillow fight" (**PILLOW TALK**) ·
  O "Bellows serenades the hat stand" (**BUTTER-FINGERS**) · O "Bellows sneezes up a storm" (ACHOO-RIA!, reached via
  SQUEAKY → honey downstairs) · BN "Make a POODLE of him" (combo: SNAP DECISION soaks him → radiator → PIPE DOWN!).
- Tomatoes unlimited · "?" 1.0 s · 4–5 min.

**Night 4 — "The Big Sulk"** (whole house, ground + upper) — Act I finale
- New: **MELTDOWN**; tomatoes count from tonight. Card: *"Keep him fuming, prank after prank. At full temper he
  melts down, then sulks blind for 8 s. Tomatoes count now."*
- Cold open: he confiscates a kite and snaps it over his knee.
- Loop (~90 s; draft, above the Act-I 60 s target of §2.4, re-measured in Stage 3): `warmup` → `paper` (specs on)
  → `fire` → `bath` (upstairs) → `nap`.
- Script: R "Bellows surfs the stairs" (**RUG BURN** — he must be Steaming, or chasing Hush, going up) ·
  R "Bellows gets in a spin" (ALLEGRO-GO-GO!) · R "Bellows throws a tantrum" (MELTDOWN) · O "Bellows dances in the
  chandelier" (**PRIMA BALLERINA**, Meltdown in the parlour) · O "Bellows turns into a ghost" (**BELLOWS BLOWS**) ·
  O "Bellows reads the paper in orbit" (LIFT-OFF; DA UP IN SMOKE with BELLOWS BLOWS) · BN "Bellows floats away"
  (**IN OVER HIS HEAD**).
- Tomatoes 3 · "?" 1.0 s · 5 min.

**ACT II — "The Goat and the Garden"**

**Night 5 — "Enter Beryl"** (+ conservatory, garden; upstairs roped off)
- New: **Beryl** (bend-over rule, apples, Besotted). Card: *"Beryl headbutts anyone who bends over near her.
  Anyone. Feed her an apple and she'll follow you."*
- Cold open: he hoses Hush's chalk mime drawings off the pavement, then hoses Hush (she mimes an umbrella).
- Loop (~85 s): `feed_beryl` → `roses` → `marrow` → `stroll` → `tea`. Beryl: Grazing lane, dozes in the sunbeam
  for 20 s of every 60 s.
- Script: R "Bellows peers down a hose" (**HOSED**) · R "Bellows's marrow flies away" (**MARROW ESCAPE**) ·
  R "Bellows pinches a penny too far" (**PENNY PINCHER**) · O "Bellows sneezes up a storm" (ACHOO-RIA!) ·
  BN "Chase the marrow into the goat" (**MARROW MAYHEM**, Double Act).
- Tomatoes 3 · "?" 0.8 s · 5 min.

**Night 6 — "Behind You!"** (ground floor, conservatory, garden; no upstairs, so RUG BURN comes only through DA ENCORE!)
- New: **the panto bit.** Card: *"Squeak behind his back, then FREEZE before he turns. Survive three rounds and the
  Stalls go wild."*
- Cold open: he conducts the dawn chorus to be quiet — "PIPE DOWN!" — and the offended birds leave in a huff; a
  feather lands in his tea.
- Loop (~85 s): `piano` (panto) → `warmup` (panto) → `feed_beryl` → `marrow` → `paper`.
- Script: R "Survive three rounds of BEHIND YOU!" (panto bit) · R "Beryl gives him a kiss" (**SWEET TOOTH**) ·
  R "Bellows gets in a spin" (ALLEGRO-GO-GO!) · O "Bellows reads the news up close" (EYE-POPPING NEWS) ·
  O "Bellows's marrow flies away" (MARROW ESCAPE) · O "Bellows surfs the stairs" (RUG BURN; knock-on via DA
  ENCORE!) · BN **GRAND EXIT** — "Bellows chases his piano".
- Tomatoes 3 · "?" 0.8 s · 5–6 min.

**Night 7 — "Kidding Around"** (whole house + garden) — Act II finale
- New: **leading Beryl indoors (herding lure).** Card: *"Lead Beryl indoors with an apple. If he spots her inside,
  he drops everything to herd her out."*
- Cold open: he sells Hush's confiscated unicycle to the rag-and-bone man.
- Loop (~95 s): `feed_beryl` → `roses` → `paper` (specs on) → `bath` (upstairs) → `nap`.
- Script: R "Beryl gives him a kiss" (SWEET TOOTH) · R "Bellows peers down a hose" (HOSED) · R "Herd the goat twice"
  (two herding detours) · O "Bellows floats away" (IN OVER HIS HEAD) · O "Bellows reads the paper in orbit"
  (LIFT-OFF) · BN **KIDDING AROUND** — "Put a goat in his bed".
- Tomatoes 3 · "?" 0.8 s · 6 min.

**ACT III — "Company's Coming"**

**Night 8 — "Company's Coming"** (ground floor + upstairs, and the conservatory and garden: FAN MAIL's feathers come from the potting bench)
- New: **Dame Delphine** (opera glasses, high C, EMBARRASSED!). Card: *"Dame Delphine sees nothing without her
  opera glasses. Prank him in front of her: he's EMBARRASSED, and the Stalls love it."*
- Cold open: he rehearses his bow to a cardboard cut-out of Delphine, then hides it as the doorbell rings.
- Loop (~100 s): `mirror` → `answer_door` (first loop only: she arrives) → `host_tea` → `piano` → `tea` → `mirror`.
  Delphine: chaise → piano → powder her nose upstairs 15 s → chaise.
- Script: R "Delphine gives him a spray" (**SPIT TAKE**) · R "Bellows blows her beehive back" (**FAN MAIL**) ·
  R "Embarrass him in front of her twice" · O "Bellows turns into a ghost" (BELLOWS BLOWS — the DRY fix-up after
  SPIT TAKE) · O "Bellows sneezes up a storm" (ACHOO-RIA!) · BN "Make DOUGH of him in front of her" (DOUGH MAN
  witnessed; TEA FOR TWO is the optional flourish).
- Tomatoes 3 · "?" 0.8 s (Delphine 1.0 s) · 6 min.

**Night 9 — "Tutu Much"** (+ dressing room; whole house)
- New: **Chase Trips** (formally). Card: *"Being chased? Run him over something you rigged. He falls for it every
  time."*
- Cold open: he tears down the street's talent-show poster and pins up "BELLOWS: THE COMEBACK".
- Loop (~100 s): `cloak` → `polish` (specs on) → `mirror` (dressing mirror) → `host_tea` (downstairs; Delphine
  visits all Night) → `piano`.
- Script: R "Bellows wears a tutu" (**TUTU MUCH**) · R "Bellows wins an award, hard" (**AWARD-WINNING**) · R "He fell
  for it! Trip him mid-chase" (any Chase Trip) · O "Bellows surfs the stairs" (RUG BURN) · O "Bellows argues with
  the plumbing" (PIPE DOWN!) · O "Delphine gives him a spray" (SPIT TAKE) · BN "Take the tutu to tea" (TUTU MUCH
  witnessed by Delphine).
- Rules: fix-up override DRY → landing radiator (SPIT TAKE's soak sends him upstairs, past RUG BURN, to PIPE
  DOWN!).
- Tomatoes 3 · "?" 0.8 s · 6–7 min.

**Night 10 — "It Takes Two"** (whole house) — Act III finale
- New: **opening-night nerves**: each loop starts with temper at 20 (Irked). Card: *"Opening-night nerves: he starts
  every loop already irked. Chains come easy, and so do his specs."*
- Cold open: he rehearses his comeback aria; windows crack all down the street.
- Loop (~110 s): `warmup` → `host_tea` → `tango` → `bath` → `cloak`.
- Script: R "Bellows splits his trousers" (**IT TAKES TWO**) · R "Bellows blows her beehive back" (FAN MAIL) ·
  R "Two tantrums in one Night" (2 × MELTDOWN) · O "Bellows floats away" (IN OVER HIS HEAD) · O "Bellows wears a
  tutu" (TUTU MUCH) · BN "Land four in one Running Gag" (a link-4 chain).
- Tomatoes 3 · "?" 0.8 s · 7 min.

**GALA NIGHT — "The Comeback"** (whole house + garden stage; the street fills the Stalls)
- New: **the spotlight** (and everyone at once). Card: *"It's his comeback concert. Give the street the show they
  deserve."*
- Cold open: the street arrives with deckchairs; he booms "PIPE DOWN!" at his own audience.
- Loop (~120 s): `warmup` → `host_tea` → `feed_beryl` → `stroll` → `rehearse` (garden stage) → `mirror`.
- Script: R "Bellows steals the spotlight" (**SPOTLIGHT STEALER**) · R "Bellows pinches a penny too far"
  (PENNY PINCHER) · R "Delphine gives him a spray" (SPIT TAKE) · R "Be his reflection" (MIRROR, MIRROR) ·
  O "Bellows gets in a spin" (ALLEGRO-GO-GO!) · O "Bellows blows her beehive back" (FAN MAIL) · BN **CURTAIN CALL**
  — "Take a bow, Bellows" (Double Act into Beryl and the pond).
- Tomatoes 3 · "?" 0.8 s · 7–8 min (hard cap 8; the solver fails the build above it).

All 32 pranks appear; 16 of them return in later Nights, each reframed (a new residue route, a witness, Beryl,
nerves, a new Double Act).

### 7.3 Difficulty curve and length
| Lever | Prologue | Act I | Act II | Act III + Gala |
|---|---|---|---|---|
| "?" fill | 2.0 s | 1.0 s | 0.8 s | 0.8 s (never lower) |
| Loop | scripted | ≤ 60 s (N1–2, D1); ~75–90 s (N3–4, draft) | 85–95 s | 100–120 s |
| Required lines | 2 | 3 | 3 | 3–4 |
| Characters | Bellows | Bellows | + Beryl | + Delphine (+ Beryl in the Gala) |
| Tomatoes | ∞ | ∞ N1–3, 3 from N4 | 3 | 3 |
| Max rig steps | 1 | 2 | 3 (coins) | 2 |
| First clear | 70 s | 3–5 min | 5–6 min | 6–8 min |

Difficulty comes from planning and temper management, never twitch skill. **Playtime:** ≈ 60 min to clear once
(≈ 75 min with retries); every Curtain Call ≈ 3–4 h; Encores (Stage 4) add ≈ 1.5 h. Playtest rule: any Night whose
first clear exceeds 8 min is split or trimmed.

---

## 8. Progression and "one more Night" hooks (non-predatory)

**Until the owner's fun gate passes, only three meta hooks exist** (the Booby lesson: meta comes last):
1. **"Next Night ▶"** is the default results button and teases the next Night's new prop as a silhouette
   ("Tomorrow night: Bellows takes a bath…").
2. **The Gag Reel** — your 3 best moments, re-staged in the set from a replay of the Night (§6.2).
3. **Near-miss nudges** on the results screen ("Applause 91 — one more link…", "4/5 — the kettle is still out
   there…").

**Stage 4 (after the gate):**
- **The Playbill Wall** — episode select as a wall of posters, roses for Curtain Calls. Night N+1 unlocks on ★ in
  Night N; an Act unlocks when every Night of the previous Act has ★. ★★★ is never required.
- **Encores** — after a Night's first ★, three remix lines appear (e.g. "Never hide", "Land four in one Running
  Gag", "Survive MIRROR, MIRROR to round 3", "BUTT OF THE JOKE twice", "No tomatoes"). Each earns a **Rose**
  (36 in all: 12 episodes × 3; the Prologue's are tutorial-light). Roses are counted, never spent.
- **The Programme** — a page per prank with T1 / T2 / T3 / Suppressed / Double Act thumbnails, plus combos, squeak
  bits, panto rounds, Lectures and Meltdowns. Unseen entries are silhouettes ("Gags seen 57/170"). Playing the
  same Night differently fills it.

**Never:** energy, timers, ads, IAP, streaks, dailies, loot boxes, push notifications, accounts, leaderboards.

**P1 backlog (post-v1, only after the owner has played v1):** Improv Night (endless, re-arming pranks), Rehearsal
(no Bellows), cosmetics (berets, Clarence skins), Company Manners (the Bottle / Blow-Up / Scandal), critics'
quotes, Act IV (cellar and attic), Beryl eating paper, the "butler" gag, sharing clips (online).

---

## 9. Art, camera, animation and audio

### 9.1 Art direction (v1.2: 3D Toy Box; SVG for what stays 2D)
(v1.2 — the whole section. v1.1's 2D art direction — AI-authored SVG cutouts, line weights by layer, pre-baked outline
sprites, runtime atlases — describes the 2D build on `main`; its SVG rules still govern everything that stays 2D.)
- **One-line style:** a Saturday-morning cartoon on a toy stage — **chunky matte vinyl-toy characters** with big
  painted faces and a clean ink outline, in a **simplified 3D dollhouse-cutaway set** of calm colour fields, lit from
  the upper left front. Family-friendly. The owner's pick (D6): **Hush = look B's body dimensions in look A's Toy Box
  style; Bellows, the house, lighting, shading, faces and props = look A** (Toy Box) with the look-dev board's fixes
  (`docs/review/lookdev/index.md`).
- **Materials:** every 3D surface takes its albedo from a shared **palette texture** (one 256² palette per room set,
  one per character), so each room is one material and each character one material + its outline. No PBR, no
  specular maps, no normal maps.
- **Lighting is computed in the shader** (unshaded materials reading shared stage-light parameters), so every renderer
  looks the same and costs the same: **one key**, a directional stage key from the upper left front (≈ 49° elevation),
  warm `#FFF4E0`, +28 % on the lit band and +8 % on a top band; a **flat fill of 0.66** — no surface falls below 66 % of
  its albedo's luminance, so nothing crushes to black at 30–50 % phone brightness; two soft bands (softness 0.08) + the
  top band; a **rim on characters only** (fresnel power 2.5, strength 0.35–0.55, cool `#BFE0FF`, which separates Hush's
  navy costume from dark backgrounds and Bellows from warm walls). **No real-time lights and no real-time shadows**:
  **blob shadows** under the characters (ellipses r 0.34 m Hush, 0.45 m Bellows, 32 % alpha); practicals (fire, lamps,
  windows) are emissive only; the footlights are an additive warm gradient from the lip (§1.3). Per-room stage light as
  §7.1.
- **The owner's shading pick — look A's vinyl shading is kept** on the characters and the vinyl live props: the soft
  two-tone terminator with A's warm **lilac shadow tint** (`#B9A3E0`), the **ground-bounce** darkening on down-facing
  surfaces (0.14) and a **0.10 matte vinyl sheen** on the lit band — all inside the readability floor above (no surface
  below 66 % of its albedo). The **set keeps the neutral fill** (`#A8A4AE`) so the room stays a calm field behind the
  toys.
- **Outlines:** inverted hull, **constant screen width** — characters **4.8 px**, live props **3.4 px** (at the 1080
  base; lead decision D7: look A's own weight — REDESIGN §5.4's 3.5 / 2.5 px read less like a vinyl toy), dressing and
  architecture **none**; ink `#1B2340`, lerped 50 % toward the room colour in a dimmed room; hard-edged props carry
  smoothed outline normals. The **verb halo** on live props is a second 8 px shell in the verb colour behind the ink,
  pulsing 0.6 ↔ 1.0 at 1.2 Hz, that must stay visible against the back wall (§3.5).
- **Value hierarchy and room colours:** §7.1 (walls L* 62–76 as flat fields, floors L* 40–50, dressing low contrast,
  live props saturated or haloed, characters with both value extremes). The v1.1 room palette families carry over —
  hall sage, parlour dusty rose (calmer, so Bellows' plum separates from it), kitchen buttercream, porch sky — with the
  exact values chosen to pass the §7.1 rules with both characters in frame.
- **The stage:** red velvet curtain `#B3122E` with gold trim `#E8B33A` (the Boot curtain stays a pre-rasterised 2D
  curtain); the gilded stage lip (`#C9A24A`) and the dark apron; the dark proscenium header (`#1D1728`, 0.8 m, gold
  edge at 3.13 m); cream wing flats (`#E9DCC4`) between rooms (§7.1).
- **What stays 2D:** the HUD and every panel; captions, stamps and the meter; Bellows' bubble, glyph, ear pips and "?"
  meter; the previews, needs clouds, item bubbles, the rig ring and the safety-net marker; the ghost finger and the
  spotlight labels; Figgis (a flat bust); the Stalls silhouettes; the red Boot curtain; the Busted Cam frame and
  "SPOTTED!"; the Gag Reel frame. Every world-anchored 2D item is placed at its projected 3D point every frame and
  obeys the placement rules (§3.8). **In 3D:** the set, the props, the characters, the red beret tags, the hidden eyes
  inside hiding spots and the floor decals (§3.9).
- **SVG rules** (for what stays 2D; ported from Booby's STYLE.md, `game/art/STYLE.md` is the file copy): presentation
  attributes only; `path/rect/circle/ellipse/line/polyline/polygon/g`, gradients only for walls/sky/glows; no filters,
  masks, `<text>`, `<image>`, CSS or `<use>` chains; ≤ 10 colours per sprite; 3 px canvas margin; compact (1-decimal
  coordinates); authored at display size (1×) and rasterised at 2× by HiResTex. Ink `#1B2340`, round joins and caps.
- **Third-party art:** CC0 / public-domain only (the Quaternius Universal Animation Library skeleton and clips, CC0
  1.0), each file's source URL and licence recorded in `game/art3d/CREDITS.md`; everything else is original.

### 9.2 Characters, faces and takes
(v1.2 — the rigs are 3D; the face vocabulary, the readability minimums' intent, the warmth rule and the residue list
carry over. The v1.1 cutout-rig text — Sprite2D parts, rubber-hose Line2D limbs, springs — describes the 2D build.)
- **Rigs (3D):** every character is **one skinned mesh on the CC0 Quaternius UAL 65-bone humanoid skeleton**
  (bone names, directions and rolls kept, lengths re-proportioned per character), plus extra bones for props, FX and
  secondary motion. **Budget per character on a mid-range phone:** ≤ 10k triangles, ≤ 50 deform bones + the jiggle
  bones, 1 skinned mesh + ≤ 4 attachments, 1 material + the outline (≤ 4 draw calls), ≤ 0.25 ms CPU (skinning +
  jiggle + face). **Secondary motion on jiggle bones**, computed in the view, never in the sim. **Residues and costumes**
  are attachment meshes and material swaps sharing the bones; mutually exclusive variants of one body part are **body
  slots** (the bouffant: neat / flipped / frazzled / wet …). **Temper** tints the skin by a material parameter
  (peach → beetroot, §1.2). **Faces** are 2D cards: cells of one face atlas per character (eyes, brows, mouth, extras),
  pupils moved by a look-at, blinks every 2–6 s (6 f, suppressed during takes); no blend shapes.
  - **Bellows** (look A + the board's fixes): the barrel torso (0.85 m) on 0.45 m legs, belly jiggle; the **bouffant**
    (body-slot variants neat, flipped, frazzled, wet, floured, feathered, poodle; three jiggle bones); **sideburn
    jiggle bones** (flat / bristle / puffed with temper); cravat and two coat-tail jiggle bones; **specs** (on nose,
    dangling, buttered, magnifier); an **arm-out pose layer** on every clip so his arms clear the barrel; big held
    props — the **teacup and saucer ×1.8** (≥ 0.16 m wide), the newspaper, the pickle jar, the sponge, the phone
    handset, the comb, the gramophone needle; his ride-along stool for the sneeze. Face (atlas cells, the v1.1
    vocabulary): eyes × 10 (open, half, closed, wide, pinpoint, angry, spiral, balloon, squint, teary), brows × 6,
    mouths × 10 including the **singing O** in 3 sizes, **a bigger face inside the bouffant** than look A's look-dev.
    The CHOO puff and the dazed stars are vinyl FX meshes.
  - **Hush** (look B's dimensions, look A's style): 1.60 m, head ≈ 0.50 m incl. the beret, B's neck, a narrow torso in
    a loose Breton top, long thin arms (B's: 0.405 m shoulder → wrist) ending in white four-finger gloves ≈ 0.20 m
    long, long thin legs in straight navy trousers, flat shoes; jiggle on the beret (+ its stalk), the braces, the hair
    tips and Clarence (comb + body); props: Clarence (in the brace, held, squeezed), the oversized pepper pot (×1.5,
    for ACHOO-RIA!), carried items tucked in her braces; the **marble** look (§3.2) keeps her eyes, beret and braces in
    colour. Face (atlas cells, the v1.1 vocabulary): eyes × 8, brows × 5, mouths × 8 (smile default), blush, a small
    teardrop, plus the dark-gap eye cells for hiding spots; asymmetric marks have mirrored cells, because facing is a
    yaw, never a mirror image.
  - **Beryl** (Act II) and **Delphine** (Act III): built in 3D on the same pipeline in Stage 3 (their v1.1 forms:
    Beryl's box body, beard, ear / tail / bell and legs; Delphine's gown, beehive with tiara, opera glasses and fan;
    springs become jiggle bones).
  - **Figgis:** a flat 2D bust in look A's palette (4 expressions + cue-card hands), contextual (§3.8). **The Stalls:**
    24 head/hat silhouettes × 3 frames (rest, laugh-up, lean) on one atlas, 2D.
- **Readability minimums at the base framing:** Hush 434 px and Bellows 471 px tall (40 % / 44 % of the height); heads
  inside 120–150 px (Hush ≈ 0.50 m incl. the beret; Bellows ≈ 120 px plus the bouffant); the painted face card as big as
  the head allows. At 1200×540 Hush's head is ≥ 60 px, her face card ≥ 40 px wide, eye whites ≥ 9 px, pupils ≥ 4 px, the
  mouth ≥ 16 px wide, brows ≥ 3 px thick (the head check of §1.2 uses this bar and a fresh-reviewer face test). Every
  verb reads as a 64 px silhouette (§3.5 W1); punch-ins enlarge his head by their factor (§3.7 C7).
- **Hush warmth rule:** at a 50 px silhouette and a 96 px face crop she reads as a smiling person, never a clown:
  big pupils, blush, smiling default, thin eye paint, no black lips. Checked on the cast sheet by the owner.
- **Residue looks** share the bones: drips, flour tint, frizz, feathers, jelly helmet, tutu, trophy helmet, long johns,
  hedge twigs, tomato splats. Combos have their own looks. A reaction's look owns its body slot until the reaction's
  release frame; from then on the sim's residue owns it (e.g. the sneeze flips the bouffant, then BLINDED keeps it
  flipped until the mirror); a retry clears it.

### 9.3 Comedy timing (numbers the animation lint enforces)
- Every reaction is **anticipation → accent → hold → settle**: anticipation 8–12 f (small) / 15–24 f (big),
  moving *against* the accent; **accent 2–4 f as a pose pop** (`blend_in: 0`), hit-stop 3 / 5 / 8 f; **hold
  30–45 f (small) / 45–90 f (big)** as a moving hold (≤ 2 % drift, breathing, tremble) — the laugh starts here;
  settle 8–15 / 15–30 f with **exactly one overshoot**; blend out 8–12 f. Reactions run 90–240 f (signatures up
  to 420 f).
- **Wild take:** eyes 1.6–2.0× for 3–4 f then 1.2×, head sy 1.3, jaw drops 20 px, bouffant springs up 40 px,
  sideburns flare. **Double take:** glance, look away 12–20 f, snap back in ~8 f. **Slow burn:** 60–90 f stare
  at the Stalls with one blink — one reaction in four ends with one. **Dignity recovery:** straighten the cravat
  (30 f), look around (40 f), resume *still wearing the residue*.
- Squash and stretch around the feet, area-preserving (`sx = 1/sy`); smears automatically above 25°/f or
  40 px/f; Hush's snicker = shoulders at 8 Hz for 40 f; blinks every 2–6 s (6 f), suppressed during takes.
- **First time** a prank fires in a Night, the last 0.4 s of his approach plays at 0.5×. Rule of three for
  sneezes and panto rounds. He is humiliated more than harmed.

### 9.4 Animation list and priorities
**(v1.2) Animation in 3D.** The §9.3 numbers are unchanged; the animation lint enforces them on the sampled 3D clips.
- **Pipeline:** poses are authored in Blender in a small pose language (rotations per bone, 2-bone arm IK, foot
  grounding, steps and reach helpers, eases per key, 60 fps, frame 0 = the clip start) and **baked one clip per file**
  into an engine animation plus a **JSON sidecar** that keeps the clip model of v1.1 — beats, events (sounds, laughs,
  FX, camera, hit-stop, props, looks), marks, loop, layer / mask, blend, variation — and adds a **face timeline**. Clip
  ids are unchanged (`bellows/rx_sneeze_blast_a`, `hush/loco_walk`), so reactions, one-shots, sound frames and the
  clip manifest carry over. A clip the sim or a cue times keeps its v1.1 length, every beat and mark of its reaction
  within 2 f and every sound frame; loops and locomotion may retime to the REDESIGN_3D §4.2 gaits (Hush's cartoon sneak
  2.2 steps/s at 2.0 m/s, a 1.80 m stride; Bellows' strut a 0.64 m stride at 1.2 m/s). The automatic 2D smear is
  dropped: accents pop on the frame instead.
- **Locomotion** is retargeted from the CC0 Quaternius library where it fits (walks, runs, idles, climbs), with
  per-character layers (Hush's mime paws; Bellows' arm-out on every clip).
- **Rigging is readable, not generic:** each rig is a **prop-specific action** — one of **three reach bands** (high /
  mid / low; §7.1) × the prep tier (Q 0.8 / S 1.5 / B 2.5 s) plus the prop's own animation as she works — and the two
  Prologue pranks have their own: **ACHOO-RIA!** climbs Bellows' stool, lifts the oversized pepper pot over the jar and
  shakes it three times; **ALLEGRO-GO-GO!** grips the big red-knobbed lever with both gloves and yanks it back. Rig
  clips follow the rig's progress (one band clip serves every tier); the glances left and right at 30 % and 70 % of S
  and B rigs are overlaid by the view. The v1.1 generic "tinker × 3" is not made in 3D.
- **The R3D set (Gate 0 + the Prologue, 70 clips):** Hush 28 — idle, the sneak walk, run, turn, arrive, skid, the two
  Prologue rig actions, the step-down hop, snicker, dive, pop, **statues 1–4** (5–8 follow: "4 of 8" until they land,
  R3 at the latest), squeak, climb in, bow, the fidgets, glance, rummage, wheeze, the frozen mid-job statue, shrug,
  yanked; plus the three band fallbacks for Nights 1–2 — and Bellows 42 — the sneeze first, then tea (with the kettle
  and honey jar coming to his hands), warm-up, the mirror fix-up, five walks, the bonk, the curtain-call wander-on, the
  slow burn, the Gate-0 bits, one-shots and micro-gags, and the Prologue's dizzy spin, doorframe and picture bonks,
  livid bit, stomp, hunt, peer under the piano and the T3 last beats. Everything else of the 137-clip Stage-2 slice
  list below is **R3** (Nights 1–2 play in 3D meanwhile with readable fallbacks — a double take held to the sim's length
  plus the caption, never a rest pose — and stay hidden in the owner build).

| Priority | Hush | Bellows | Others |
|---|---|---|---|
| **P0 — slice** (Stage 2) | idle + 3 fidgets, tiptoe scurry (10 f per step), run (12 f), turn (6 f), door, stairs, rummage, tinker × 3 (Q/S/B), snicker + glance at the Stalls, dive / pop out, hidden eyes, 4 freeze poses, squeak arm, climb in the window, busted, dangled (Lecture), doorstep + tomato, bow | idle + fidgets, strut (28 f per step, belly spring), Irked walk, Steaming stomp, turn, door, stairs; activities: warmup, tea, pickles, snack, rinse, paper, fire, mirror, phone, clock, hunt; suspicious, double take, "?" look, chase, wheeze, grab, Lecture × 3, Meltdown × 1, Exhausted, slow burn, dignity recovery, door-slam bonk, "pardon" bump; reactions: SNEEZE_BLAST, DRENCH A, SING_CRACK, STRAIN_SLIP, AVALANCHE_HELMET A, DIZZY_SPIN, LAUNCH_CEILING, BLIND_BUMBLE A, FISH_SLAP, JACKHAMMER_CLING, the MIRROR, MIRROR signature, HOT & COLD; squeak bits × 6 | Stalls laugh set; Figgis; curtain |
| **P1 — Stage 3** | 4 more freeze poses, garden walk, panto set, Besotted-leading, stage bow | upstairs/garden/Delphine activities; archetypes 9, 10, 13–22; signatures #11, #12, #19, #23, #32; Meltdown × 2 more; 4 combo beats; remaining squeak bits; cold opens × 11 | **Beryl:** idle, graze walk, doze, trot, follow, paw, headbutt, bleat, herded tug · **Delphine:** glide, sit, sip, spray, fan, glasses lift, high C, sing |
| **P2 — Stage 4** | curtain-call variants | curtain-call slow burns | Gag Reel staging, Playbill |

Build order: the **sneeze (#1) end to end first** — rig, clip, sound, laugh, camera, lint, GIF — then the owner
judges it (Gate 0) before mass authoring. A separate review agent scores every gag 1–5 on *funny / readable /
fresh* from its contact sheet and GIF; anything under 3 goes back. (v1.2) In 3D the order holds again: the sneeze is
the first Bellows clip, and the owner judges it as **Gate 0 in 3D ("Sneeze 3D")**; clips that run out of their time
box ship as lint-clean drafts (never fallbacks) marked for R3 polish.

### 9.5 Audio direction (procedural, extending Booby's `tools/audio`)
- **The score is a pit orchestra** (piano, pizzicato strings, clarinet, bassoon, tuba, timpani, woodblock, slide
  whistle) in adaptive, synchronised stems: **sneak** (pizzicato, near-silent between beats — Hush's pizzicato
  footsteps walk up a scale), **suspense** (tremolo + ticking during a "?" or as he nears an armed prank),
  **chase** (an arrangement of Offenbach's *Galop infernal*).
- **The chain is the music:** Grieg's *In the Hall of the Mountain King*, pre-rendered as **4 sections at
  stepped tempos** (links 1, 2, 3, 4+), crossfaded on the bar — never live tempo changes. A Meltdown hits the
  climax section. All compositions are public domain; every note is rendered by our synth.
- **Stingers** (≤ 1.5 s, music ducks −6 dB): rigged = ding + 3 pizzicato notes; bit = rim-shot; fizzle = tuba
  "wah-wah"; caught = sad trombone; near miss = harp glissando; combo = brass sting; +NEW! = celesta.
- **Bellows' voice** is a **pre-rendered phrase bank** from the formant synth (baritone f0 90–110 Hz, 5.5 Hz
  vibrato ±40 cents, distortion on shouts): warm-up scales × 6, "PIPE DOWN!" × 4, Lecture phrases × 3, 12
  nonverbals × 3 (hmph, huh?, WHA!, yow, grr, ahem…), sneeze parts, humming × 4, "BERYL!", "…the pipes." Outside
  reactions he sings at most one line per 6 s. **Fallback voice:** a muted "talking tuba" (instrumental speech),
  A/B-tested with the owner in week 1; the owner picks.
- **(v1.2) The A/B defaults stand.** The owner never answered the Gate-0 voice and crowd A/B (D3 / D4), so the
  formant baritone and the formant crowd stay the defaults and the A/B pages stay in the debug stage door. The audio
  is unchanged by the 3D pivot, except that sounds pan by the source's projected screen x.
- **Hush has no voice; the pit plays her:** slide-whistle takes, a woodblock "clack" when she freezes, a breathy
  "hff-hff" silent laugh. **Delphine:** soprano f0 280–340 Hz with a glass-crack tail on the high C. **Beryl:** an
  FM + formant "mehhh" and a positional bell. **Clarence:** a rubber squeak whose pitch follows the press; the
  wheeze falls.
- **SFX:** a unique sound per object and surface (≈ 140 one-shots in v1), Treg-Brown rules: a woodblock bonk on
  the contact frame ±1 f; slide whistle only for rises and falls; crash → 300 ms of silence → one pan spinning to
  rest.
- **Crowd:** formant laughter tiers T0–T4 and the specials (§6.5), randomised without repeats; fallback crowd of
  applause, whistles, "ooh" and a kazoo "ha-ha" choir (A/B in week 1).
- **Mix:** buses Master ← Music, SFX, Voice, Crowd, UI; sliders for music, SFX, voice, audience. All audio is rendered by our synth as 22.05 kHz
  mono WAV and compressed on import (QOA); all audio ≤ 40 MB in the APK.

---

## 10. Scope, risks and the fun gate

### 10.1 v1 scope
**IN:** one house (10 spaces); Hush, Bellows, Beryl, Delphine, Figgis, the Stalls; the Prologue, 10 Nights and
the Gala; 32 pranks, 10 squeak bits, the panto bit, 7 residues, 4 combos, 6 Double Acts; temper, Running Gag,
Meltdown; the specs rule; the Script and Curtain Calls; the Gag Reel; hints; settings (§3.11); Playbill,
Encores and the Programme (Stage 4, after the gate); English, icon-first; local save; Android and iOS.

**OUT:** anything online; monetisation; accounts; cloud save; achievements; dailies; a second house; more
characters; real-word voice acting; controller support; tablet-specific tuning beyond the ×0.8 HUD; a physics
engine (every gag is keyframed and deterministic); everything in the P1 backlog (§8).

### 10.2 Content budget (hard caps)
| Item | Slice | v1 total |
|---|---|---|
| Pranks | 11 (cap 12) | 32 (cap 32) |
| Signatures (bespoke clips) | 1 | 6 (cap 6) |
| Reaction archetypes | 10 | 22 (cap 24) |
| Squeak bits | 6 | 10 (cap 10) |
| Episodes | Prologue + 2 | 12 |
| Rooms | 3 | 10 |
| Full character rigs | 2 | 4 (+ Figgis bust, Stalls atlas) |
| SFX one-shots | ≈ 60 | ≈ 140 |

T2/T3/Suppressed are procedural modifiers on existing clips, never new clips. Before committing to Stage 3, one
prank is timed end to end in the slice (art → clip → sound → lint → GIF) and the cost per prank is recorded in
PROGRESS.md.

**(v1.2) 3D budgets.** "Full character rigs" are 3D rigs: **per character ≤ 10k triangles, ≤ 50 deform bones + the
jiggle bones, 1 skinned mesh + ≤ 4 attachments, 1 material + outline (≤ 4 draw calls), ≤ 0.25 ms CPU** (§9.2). The set
per Night: **≤ 5 live props and ≤ 4 dressing pieces per room**, one palette material per room set, static meshes
merged per room (§7.1). Clips: the 137-clip Stage-2 slice list is rebuilt in 3D — the 70 clips of Gate 0 and the
Prologue in R3D, the rest in R3 (§9.4). Third-party files: CC0 only, each recorded in `game/art3d/CREDITS.md`.

### 10.3 The vertical slice (Stage 2)
**Prologue + Nights 1 and 2 at final polish:** hall, parlour and kitchen art; the Hush and Bellows rigs; 11
pranks + HOT & COLD; MIRROR, MIRROR; 6 squeak bits; temper, Running Gag and Meltdown; FREEZE and the specs rule;
hiding, pins and the command queue; the Lecture and the Busted Cam; Figgis hints 1–3; the Stalls at every tier;
the Bellows-Cam; the curtain call with the Gag Reel; adaptive music; haptics; settings (Relaxed, tap-to-rig,
left-handed, volumes). Left out: Beryl, Delphine, upstairs, the garden, the panto bit, meta.

**(v1.2) The slice in 3D.** The 2D slice reached Gate 0 (the Gate-0 build on `main`); the owner's verdict started the
3D pivot, which rebuilds the slice's view in stages (REDESIGN_3D §6.4): **R0** (done) the spec, the pipeline spike,
three look-devs and the owner's pick; **R3D = R1 + R2 in one build** (branch `r3d`) — the 3D sets from the content
(`SetList`, the strike rule), the 3D camera (C1–C8), the decluttered HUD, the previews, tags and rig rings, the final
3D Hush and Bellows in the owner's hybrid style with face cards, jiggle and residue looks, Hush's verb pose set and
reach bands, Bellows' walks, tea, warm-up and the sneeze, and the two small content changes (`hides`, the Night-1 /
Night-2 route re-plans); **its exit: Gate 0 in 3D ("Sneeze 3D") and the Prologue playable end to end in 3D on the
owner's phone** (a debug APK), with the solver, fuzz, lints, the dead-air gate and the new 3D checks green; Nights 1
and 2 boot and play in 3D but are hidden in the owner build (their reactions are fallbacks until R3). **R3** — the
slice sets and all 137 slice clips in 3D, the 11 slice pranks' armed / spent looks and rig actions, the Stalls,
curtain call and Gag Reel over the 3D view; **R4** — the Fun Gate (§10.4) in 3D. Content (sim, solver, data, audio,
UI logic) carries over unchanged except `hides` and the re-plans.

### 10.4 The fun gate (the owner plays the debug APK on his own phone)
**Automated pre-checks (all must pass before he sees it):** the solver clears the Prologue, N1 and N2 on the
*ideal* (★★★), *required-only* (★) and *slow first-timer* routes; Prologue: 6 laughs in 60 s (ideal) and first
player laugh ≤ 10 s / first prank ≤ 30 s from launch (slow); dead air within the §2.4 gate (ideal ≤ 20 %,
required ≤ 25 %, slow ≤ 30 %, worst gap ≤ 12 s, edge beats ≤ ⅓ of the beat credit); the fairness fuzz is green; every
clip passes the animation lint; hotspot, content and IP lints pass; the **mute test** — at least 4 of 6 silent
reaction GIFs read as jokes to a review agent that doesn't know the prank; review scores ≥ 3/5 on every gag;
60 fps p95 with the Gag-Cam, PiP and particles at ≤ 150 draw calls; launch to first laugh ≤ 10 s on a budget
Android (measured from app launch).
**(v1.2) The 3D pre-checks, added:** the **set lint** (per Night and room: ≤ 5 live props, ≤ 4 dressing, one hiding
spot per room in Act I, no live stack under 24 px on screen, distinct 64 px silhouette families, the dressing and
value rules of §7.1 on a rendered set shot); the **screen-rect lint** (every live hotspot of every final Night,
projected at the base framing at 20:9, 16:9 and 4:3: ≥ 144 × 144 px, ≥ 24 px apart, inside the safe rect, not under
an always-on HUD piece); the **HUD lint** (≤ 4 always-on pieces in every captured play frame, nothing always-on or
persistent in the middle band y 250–880, ≤ 6 world overlays with ≤ 2 loud; the Bellows window's share of PLAY time
reported, a warning above 35 %); the **visibility test** (on every tick of every solver route, whenever the sim counts
Bellows as visible the view shows him on screen or in the Bellows window, and the window is closed while he is on
screen — C8, §3.7); and **3D performance** — 60 fps p95 with the punch-in, the Bellows window and a particle burst, ≤ 150
draw calls p95 (≤ 250 max), ≤ 150k triangles on screen, ≤ 8 particle emitters, ≤ 250 MB of textures, **no shader
compiled during play** (every material drawn once under the curtain), each character inside its §9.2 budget. Before
the Fun Gate itself, R3D adds a **readability review**: fresh reviewers name Hush's verb from caption-free frames
(≥ 7/8), say what a lit spot will do from its preview (≥ 6/8), call the screen crowded at most once in 8, and prefer the
3D frame to the matching 2D one (≥ 6/8) — the owner's four complaints as acceptance tests.

**Owner checks (all must hold):**
1. First player-caused laugh ≤ 10 s and first prank ≤ 30 s from launch (log timestamps on his phone).
2. At least 5 audible laughs or grins in the first 10 minutes (his count or a screen recording).
3. He replays Night 1 or 2 unprompted, for ★★★ or an unseen reaction.
4. He calls Bellows' next destination correctly in 9 of 10 spot checks.
5. He calls no catch unfair, and the log shows a ≥ 1.0 s "?" before every catch.
6. At most 1 misfire in 20 taps on a 60 px hotspot; the hold ring is readable under his thumb; panning never moves
   Hush; he never says "I tapped and nothing happened".
7. Stable 60 fps on his phone (debug overlay).
8. In his own words: funnier than Booby within a minute.

| If it fails on… | Response (content stays frozen until it passes) |
|---|---|
| Unfunny reactions | Double the holds, add residue, falling props and sound; re-run the mute test; the review agent re-scores. |
| Unfair / confusing stealth | Widen "?" windows, enlarge the specs and stare strip, simplify to "frozen = safe unless in his way". |
| Too many rules | Push Meltdown to Night 3 and residue formalities later; Nights 1–2 teach only tap, hold, hide, squeak, freeze. |
| The mime doesn't land | Switch to the Pip fallback (same rig and verbs). |
| The singing grates | Switch Bellows to the talking-tuba voice. |
| Controls | Fix input first: tap-assist radius, hit boxes, latch timings. |

### 10.5 Biggest risks and early validation
| # | Risk | Early validation |
|---|---|---|
| R1 | **The animation isn't funny** — and the reaction *is* the product | Gate 0 **Sneeze Test** early in Stage 2: one kitchen, one prank, full juice, as a GIF and an APK; the owner judges. Review agent + mute test on every gag. |
| R2 | **Too many rules** | One new rule per Night with a body tell and a ≤ 25-word card; Nights 1–2 teach only 5 inputs; meta held back. |
| R3 | **Emergence breaks fairness** | Deterministic sim, authored landing tables, one punchline at a time, fairness fuzz, solution replays per Night. |
| R4 | **The mime divides people** | Cast sheet + the sneeze GIF to the owner at Gate 0; Pip fallback kept rig-compatible. |
| R5 | **Synthesised singing / laughter sounds robotic or creepy** | Week-1 A/B: formant baritone vs talking tuba; formant crowd vs applause/kazoo crowd. Owner picks. |
| R6 | **Waiting** | Act I loops ≤ 60 s in the slice, ⏩ while hidden (taught in the Prologue), lures, timed micro-gags every 5–8 s; the §2.4 dead-air gate (real time with ⏩, visible beats only) on every route. |
| R7 | **Touch misreads** | Touch-up activation, 144 px hit boxes, 90 px assist, verb latch, queue, idempotent taps; on-device 19/20 test. |
| R8 | **Performance / startup** | Runtime atlases (≈ 1–3 draw calls per character), PiP at 30 Hz, ≤ 8 particle emitters; HiResTex warm hidden under the curtain; measured on a budget Android in Stage 2. |
| R9 | **Content cost** | 22 archetypes + procedural tiers; one prank timed end to end before Stage 3; per-Act owner checks; cut order in PLAN.md. |
| X1 | (v1.2) **3D performance** on a mid-range phone with the Compatibility renderer (skinning, outline passes double the draws, fill rate at 2400×1080) | the per-character and per-frame budgets (§9.2, §10.4); outlines only on characters and live props; one palette material per room; merged static meshes; MSAA 2× with an off switch; a 0.85 render-scale fallback; the pipeline spike and an on-device perf probe measure first |
| X2 | (v1.2) **Shader compile hitches** (no ubershaders in Compatibility) | every material warmed under the curtain; the device log reports any compile during play as a failure |
| X3 | (v1.2) **Animation throughput** — 3D comedy animation costs more than 2D keyframes | the data-driven clip format, beats, events and lint kept; CC0 locomotion retargeted; three reach bands × prop animations instead of bespoke rig clips; readability checked on the Gate-0 / Prologue set before the R3 volume |
| X4 | (v1.2) **Charm lost in 3D** (the faces were the comedy) | 2D face cards keep the 2D expression vocabulary; the owner judges "Sneeze 3D" before mass authoring |
| X5 | (v1.2) **The 1-D sim in a 3D space** (players expect depth moves) | the lane rule, wing flats, cheat-out and a shallow 2.4 m set make it read as a stage, not a room to explore |
| X6 | (v1.2) **Tap misreads from perspective** (props at different depths) | projected hit rects + the screen-rect lint; stacks only where ≥ 24 px apart |
| X7 | (v1.2) **Content churn** (hides, route re-plans) | the two content changes are small and machine-checked; the gates re-run before the owner sees the build |
| X8 | (v1.2) **Schedule:** the view, rig and art are rebuilt or adapted (≈ 27k lines of view and Night code, all 820 SVG art files); sim, solver, UI logic and autoloads (≈ 25k lines), audio and content carry over | everything behind the view's snapshot seam is reused; fake-world sandbox shots from day one; parallel tasks with time boxes |
| X9 | (v1.2) **Licensing** | CC0 / public-domain third-party files only; `art3d/CREDITS.md` records each file's source URL and licence |

---

## Appendix A — How every judge's must-fix is resolved

| Must-fix | Resolution in this GDD |
|---|---|
| Cut the system count | Heat, the Bottle / Blow-Ups / Scandal, the warpath, perform bits, CHEEKY, critics, Improv, Rehearsal, Dressing room: cut or P1 (§8). Core = routine + bubble; tap/hold/hide; squeak; FREEZE + specs; temper tiers + Running Gag + Meltdown; residue → fix-up (§0). One new rule per Night with a body tell (§7.2). |
| Routine stays a readable clock | Temper speed ≤ +15 %, never skips or reorders; detours inserted before the next activity and shown the same tick (§4.1, §4.7 rule 9). |
| Bedtime / soft clocks punish planning | No Bedtime, no idle decay, no dead-air penalty in v1 (§2.2). Gala capped at 8 min. |
| Hero speeds too slow | Hush 400 / 720 px/s, Bellows 240 / 600 (§4.1). |
| Button cluster / stray squeaks | Clarence moved to the left thumb (≥ 1,300 px from the action button); 150 ms two-thumb suppression; Figgis in a top-left chip; bottom-centre free of targets (§3.3, §3.8). |
| HIDE/FREEZE auto-flip; tap-on-hero | Hiding is a world tap; the action button is FREEZE whenever not at a rig point; verbs latch at touch-down and show ≥ 250 ms; no tap-on-Hush verb (§3.2). |
| Bump rule | Footprints 1.5 s ahead; first bump per Night is a "pardon" gag; every bump opens a "?" window (§4.3). |
| Scoring legibility | base × chain + four named bonuses shown as stamps; lines normalised to 70; results explain every miss (§6.1–6.2). |
| Prologue safety nets | Player-led gates, 8 s sparkle nudge, 0.5× safety net, 2.0 s "?" and Figgis's hook; slow-route validation (§2.3). |
| Content budget | 32 pranks, 12 in the slice, 10 squeak bits, 6 signatures, procedural tiers (§10.2). |
| Mirror, Mirror minigame | Reworked as hold-FREEZE-in-the-frame, release to wink: one input, push your luck (#15). |
| Cast validation, Hush warmth, Pip | Cast sheet + Gate 0 GIF; warmth rule; Pip fallback kept rig-compatible (§1.2, §9.2). |
| Singing validation / fatigue | Pre-rendered phrase bank, ≤ 1 sung line per 6 s, voice slider, talking-tuba fallback A/B (§9.5). |
| Panto British-only / Act I | Universal "BEHIND YOU!" only, no "OH YES HE IS!"; from Night 6; one telegraphed input (§5.6). |
| Stalls strip | IGNORE, bottom-centre band, 40 px resting, never over hotspots or Hush's feet, one instanced atlas (§3.8, TECH §5.10). |
| Beryl side effects | No eating in v1; headbutt on Hush = gag; 0.6 s paw telegraph; authored landing tables; only on camera (§4.8). |
| Entry warning | ≥ 1.5 s, enforced by a doorway pause (§4.2). |
| Meta held back | Three hooks until the gate; Playbill / Encores / Programme in Stage 4 (§8). |
| Unbounded finishers; simultaneous punchlines | Landing tables per room; Meltdown props in his room only; one punchline at a time; hooks wait (§4.5, §5.3). |
| Draw calls and startup | Runtime atlas per character/room; warm under the curtain; launch-to-first-laugh measured (§9.1, TECH §5.3, §9). |
| Audio linchpin | Phrase bank, stepped-tempo chain sections, crowd fallback (§9.5). |
| Timing-skill bits | Panto = one read + one input with 0.5–0.8 s turns and tells; the "?" never below 0.8 s; Mirror reworked (§5.6). |
| Determinism and fairness QA | Solver, personas, fuzz invariants (TECH §8). |
| Catch-gag tone | The non-violent Lecture; never a fight cloud (§4.6). |
| IP distance | Stage framing only; no TV/rating/golden awards/seasons/takes; IP lint (§1.3, §5.9). |
| First-minute teaching load | Prologue teaches squeak, move, hold, hide with ghost fingers; FREEZE waits for Night 2; the specs are only *shown* (§2.3). |
| Human-vs-neighbour fantasy | Kept: a human prankster against a grumpy human neighbour; pets and guests are supporting acts (§1.2). |

**(v1.2) The owner's Gate-0 verdict and the 3D decisions** (REDESIGN_3D v1.0, owner decision D6, the R3D rulings):

| Complaint / decision | Resolution in this GDD |
|---|---|
| "The UI is too crowded" | Four always-on HUD pieces (pause, Script chip, Clarence, action button); everything else contextual; nothing always-on or persistent in the middle band; the placement rules (§3.8). |
| "The characters don't look good — 3D would be more appealing" | 3D toy-proportioned characters at 40–44 % of the screen height, the only things with both value extremes, a 4.8 px outline and a rim; face cards keep the 2D vocabulary (§1.2, §9.1–§9.2). |
| "The house is too crowded" | The set is dressed per Night: the strike rule, ≤ 5 live props and ≤ 4 dressing per room, one hiding spot per room in Act I, plain walls, one floor at a time, locked rooms not built (§7.1, §7.2). |
| "The actions aren't obvious" | Before / during / after / trigger for every verb and prank: previews of the joke, prop-specific actions with the ring at the prop, the armed look + red beret tag, staged payoffs; one verb per screen (§2.1, §3.5). |
| The owner's style pick (D6) | "Prankster dimensions from B, the rest from A": Hush = look B's body in look A's Toy Box style; Bellows, the house, lighting, shading, faces, props = look A with the board's fixes; A's vinyl shading kept on characters and vinyl props inside the 66 % floor (§1.2, §9.1). |
| Hush can't reach what she rigs with B's arms | Props ×1.5, furniture ×0.8, the reach row, reach positions, bands by the placed target, ACHOO-RIA! on Bellows' own stool, the mime's invisible step, set pieces come to Bellows' hands (§7.1). |
| B's head may shrink her painted face | The head check: enlarge the face card first; propose a head scale only if that fails; B's head ships until the owner answers; a `head_b` variant and stage-door buttons to judge in play (§1.2). |
| The Bellows window may become the new always-on PiP | Its PLAY-time share is measured and warned above 35 %; the `lean` presentation (the edge badge while he is merely next door) with its own dead-air check; the default is set from the measurement (§3.7, §2.4). |
| Unanswered owner questions (D2–D4) | The mime only (Pip later), the formant voice and crowd stay the defaults (§1.2, §9.5); Figgis a flat bust in look A's palette (§1.2). |
| No time or tone change | The sim, solver, content, audio, the Prologue's minute, the reaction lengths and every §9.3 timing rule are unchanged (§2.3, §9.3–§9.4). |
