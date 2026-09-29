# Mischief Next Door — Game Design Document (v1.1, BINDING)

*"A silent comedy for a very loud man."*

Status: final, binding design for v1. Built on the panel's winning proposal ("The Comedy Sandbox"), with the
judges' grafts from "Snackable" and "Classic" and every must-fix resolved (traceability table in Appendix A).
Technical contracts: `docs/TECH.md`. Build plan: `docs/PLAN.md`. Status: `docs/PROGRESS.md`.

**Changelog.**
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
| **Audience** | **The Stalls**: a strip of silhouetted theatre heads that laughs in 5 tiers, gasps, shushes and shouts "BEHIND YOU!". Score is **Applause** (0–100+); stars are **Curtain Calls**. |
| **Fairness** | You can always read where he goes next (thought bubble + ring), what he can see (awareness glyph + stare strip on the floor), and when he's coming (1.5 s door jiggle + footsteps + PiP). Every catch starts with a ≥ 0.8 s "?" window and is replayed by the **Busted Cam**. |
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

| Character | Role and personality | Silhouette (must read as a 50 px black shape) | Size at zoom 1.0 | Colours |
|---|---|---|---|---|
| **Hush** (player), street mime, ~25, lives at No. 9 | Silent, gleeful, a brave coward who can't resist showing off. Mimes everything; glances at the audience after every rig (makes the player complicit). **Warm, never creepy**: big round pupils, rosy blush, smiling default mouth, small teardrop. | Lanky; tilted beret; Breton stripes; braces; **huge white gloves** (1.6× hand size — the gloves act); flat shoes. | 340 px tall, head 130 px | Face paint `#FFF6EA`, stripes navy `#2B3566`, **cherry-red beret + braces `#E23B4E`**, cheeks `#FF9AA2` |
| **Clarence** | Hush's rubber chicken, rides in her braces. Pitch follows the squeak. | Floppy chicken, red comb. | 90 px | Yellow `#FFD23F`, comb `#E23B4E` |
| **Horace Bellows** (neighbour), 61 | Retired bass-baritone ("fourth most famous in the county") planning a comeback nobody wants. Vain, stingy, short-sighted: his specs hang on a chain, unworn, until he's suspicious or furious. Catchphrase **"PIPE DOWN!"** The straight man with far too much dignity. | **A dandelion clock on a barrel**: barrel torso on tiny legs, silver **bouffant**, **mutton-chop sideburns** (springs that bristle with temper), specs on a chain. | 380 px tall, head 140 px | Plum jacket `#7B3F8C`, gold cravat `#E8B33A`, bouffant `#D9DCE6`; face ramps peach `#F4C9A8` → pink → red → beetroot `#B8324B` with temper |
| **Beryl** (Act II+) | His pygmy goat ("my little prima donna"). Dozes in sunbeams, loves apples, **headbutts anyone who bends over near her**. Never gives Hush away, never harmed. | Box body, stick legs, triangle beard, rectangular pupils, jingling bell. | 210 px | Cream `#F3EAD6`, **pink collar `#FF7FB0`** |
| **Dame Delphine Trill** (Act III+) | Retired soprano, his old stage partner and unrequited crush. Blind as a bat without her opera glasses; easily scandalised. Her high C cracks mirrors. | A gliding triangle gown under a towering auburn **beehive with a tiara**; opera glasses on a stick. | 420 px | **Emerald `#1FA37A`**, beehive `#B5562E` |
| **Old Figgis** (hints) | The ancient prompter. Whispers "psst!", holds up picture cue cards. | A tiny head with huge ears in a hooded prompt box — lives in a top-left HUD chip. | 128 px chip | Hood `#3A3050`, face `#F4C9A8` |
| **The Stalls** (audience) | The visible laugh track: ~24 silhouetted heads (bowlers, beehives, a shiny bald head, a toddler on a shoulder). | Head/hat silhouettes only. | 40 px resting, up to 120 px during laughs | Aubergine `#2A1E3A` at 0.6 alpha |

**Pip fallback (kept wired, R4).** If the owner rejects the mime at the cast review, Hush is replaced by *Pip*,
an 11-year-old "Statues" champion (red beanie, striped jumper, same gloves-as-mittens idea). Same rig topology,
same pivots, same verbs, same clips; only part SVGs, face paint and the Lecture's grab (Pip is shooed out
with a broom-sweep instead of lifted) change. Art tasks MUST keep part names and pivots rig-compatible.

### 1.3 Framing: "the house is a stage"
A stage farce, not television: there are no cameras, viewers, ratings, channels, seasons or directors.
- Episodes are **Nights**; groups of Nights are **Acts**; the cutaway house is the set with its fourth wall
  missing. A red curtain rises and falls each Night. Footlights glow along the bottom of the set.
- Score is **Applause** on a brass **Applause-o-Meter**. Stars are **Curtain Calls** (★ ★★ ★★★).
- Each catch earns Hush a **tomato** from the Stalls; three bring out **the Hook** (a vaudeville cane).
- **Results = the curtain call** (§6.2). Bellows, still wearing his residue, wanders onstage, sees the audience
  for the first time, slow-burns, and the curtain drops on his head.
- **The fourth wall.** Bellows never acknowledges the audience during play — except in SPOTLIGHT STEALER (§5.7),
  where that is the joke. Hush glances at the audience after every rig.

---

## 2. The core loop

### 2.1 The 30-second beat (8–12 per Night)

| t | Player | Screen and audience |
|---|---|---|
| 0–3 s | **Read** his thought bubble (next activity icon + countdown ring + awareness glyph). | He hums through an activity with a micro-gag every 5–8 s. |
| 3–8 s | **Move**: tap a glowing hotspot; Hush tiptoes (400 px/s). | Ripple ≤ 16 ms, dotted path, 8 ms haptic tick, pizzicato footsteps. |
| 8–11 s | **Rig**: hold the action button 0.8 / 1.5 / 2.5 s. | Hush fiddles, then frantically works, then wipes her brow, then snickers at the Stalls (titter). |
| 11–14 s | **Cover**: tap a hiding spot, or hold FREEZE, or squeak Clarence for a laugh or a lure. | 1.5 s before he enters: door jiggle, footsteps crescendo, PiP pops, "BEHIND YOU!" if she's exposed. |
| 14–22 s | **Watch** him approach the trap. | Suspense tremolo. A first-time prank plays its last 0.4 s at 0.5×. |
| 22–26 s | **Payoff.** | Punch-in, hit-stop, a 2–4 s reaction, a pun caption, a tiered laugh, the Applause needle jumps. |
| 26–30 s | **Decide**: he's fuming (Running Gag fuse burning) and his bubble shows where he'll go to clean up. Rig that spot, squeak to keep him simmering, or back off because his specs just went on. | His body is the meter: face colour, sideburns, steam. The fuse bar drains under the Applause-o-Meter. |

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
Rooms: **parlour + kitchen** only (the hall doorway is roped off "backstage"; Bellows goes through it, the PiP
follows him). No menus before play. Times are **from app launch** on a mid-range Android: launch-relative =
sim time + 2.3 s (Boot and the sim clock, below). Where the *ideal* and the *slow first-timer* routes differ, t
gives the range ideal–slow (solver-measured at Checkpoint G, `docs/review/s2-content/prologue_clock.md`).
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
   PiP frame, its sounds. **No texture page is built during play.**
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
   the beat credit on any route.**
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
clusters.

### 3.1 Gesture grammar

| Input | Rule | Result |
|---|---|---|
| **Tap world** | Touch-up ≤ 300 ms after touch-down, travel ≤ 24 px, no second finger. Fires on **touch-up**. | Target priority: hotspot (tap-assist snaps within 90 px to the nearest hotspot) > door/stairs > floor. Hush **tiptoes** (400 px/s, silent). Feedback ≤ 16 ms: ripple (0.35 s fade), dotted path (0.4 s), 8 ms haptic, destination marker. A new tap re-routes instantly. A repeat tap on the current target does nothing (idempotent). |
| **Second tap** | ≤ 280 ms and ≤ 64 px from the first | Upgrades the current walk to a **run** (720 px/s, noisy: 500 px noise ring every 0.5 s). The first tap is never delayed. |
| **Tap a hotspot** | — | "Go and do it": pick-ups, hiding, doors, stairs and Take a Bow auto-execute on arrival. **Rigs never auto-execute**: Hush arrives, faces the rig point, and the action button lights up. |
| **Long-press world** | ≥ 450 ms, travel ≤ 24 px | **Reveal**: every hotspot in view shows its badge for 2 s; lifting over one selects it. 8 ms haptic. |
| **Drag world** | travel > 24 px | Camera pans 1:1; release flings (τ 0.25 s), holds 1.5 s, eases back over 0.5 s. **A drag never moves Hush**, even when hidden. No drag may start within 48 px of a side edge (Android back gesture). |
| **Pinch** | two touches, distance change > 32 px | Zoom 0.5–1.25 anchored at the midpoint. The **Overview** button is the one-finger alternative (toggle 1.0 ↔ 0.5). |
| **Tap PiP / edge bubble** | — | **Peek**: camera flies to Bellows in 0.35 s, holds 1.8 s (longer while the finger stays down), flies back. |
| **Tap a tray slot** | — | "Where does this go?": matching rig points pulse; off-screen ones get edge arrows for 3 s. |
| **Android back / iOS edge swipe** | — | Pause menu. Never quits. |

### 3.2 The action button (right thumb)
Bottom-right, visual 190 px, hit 240 px circle. It shows exactly one verb as a 96 px icon.

| Verb | When shown | Input | Effect |
|---|---|---|---|
| **RIG** (item icon → target icon) | Hush stands at a rig point whose prank is available and she has what it needs (or it's free). Pops 1.08× on arrival. | **Hold** | A 14 px ring fills over the prank's prep tier: **Q 0.8 s, S 1.5 s, B 2.5 s** (never > 3 s). Yellow → green; pulses at 3 Hz over the last 20 %; 8 ms haptic at 50 %; completion pops 1.0 → 1.18 → 1.0 over 180 ms with a ding and a 30 ms haptic. **Release early keeps progress** (the icon shows the partial ring; coming back resumes). Sliding > 80 px off the button cancels (progress kept). |
| RIG (dimmed, item silhouette) | At a rig point but missing the item | Tap | The container that holds the item pulses (edge arrow if off-screen). |
| **FREEZE** (statue icon) | Everywhere else, whenever Hush is not hidden. **Persistent**: it never turns into HIDE or anything else. | **Hold** | Hush strikes one of 8 ridiculous statue poses (chosen by the room/prop) and stays frozen while held. Release unfreezes. World taps while frozen drop a destination **pin**; releasing goes there. |
| **POP OUT** / **GO ▶** | Hush is hidden | Tap | Leaves the hiding spot (to the pin if one is set, button reads GO ▶). A double-tap pops out and runs. The rim shows danger: **green** = he is not in this room or the next; **amber** = he's next door or heading here; **red** = he's in this room. |

Rules:
- **Verb latch:** the verb is fixed at touch-down; nothing that happens during the press changes what the
  press does. Each verb stays visible ≥ 250 ms before it may change (hysteresis), with a 120 ms cross-fade.
- **Caught mid-job:** if a "?" starts filling on Hush while she holds RIG, the ring pauses and — as long as
  the thumb stays down — Hush freezes in place mid-task (a statue holding a saw). Releasing unfreezes.
- **Thumb occlusion:** while the button is held the camera offsets 200 px so Hush sits at 40–55 % of screen
  width, never under the thumb.
- **Tap-to-rig** (setting): holds become tap-to-start/tap-to-stop; FREEZE becomes a toggle.

### 3.3 Clarence / ⏩ (left thumb)
Visual 128 px, hit 168 px, directly above the tray's left end. Centre distance to the action button ≥ 1,300 px.
- **Tap: SQUEAK** (0.12 s). No cooldown, ever. Hush's arm moves for 0.3 s (counts as *moving* for sight, §4.3).
  A press that begins within 150 ms of an action-button press is ignored (prevents two-thumb slips).
- **Hold (≥ 0.5 s): WHEEZE** — a falling squeak up to 1.5 s long. Same rules as a squeak (counts once).
- **Lure ring:** a thin ring around the button shows lure readiness; it **greys out** after two lures inside
  60 s (lure fatigue, §5.6). The squeak itself still works and is still funny.
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

### 3.5 Hotspots and highlighting
- **Current room:** every interactable has a 4 px outline pulsing alpha 0.6 ↔ 1.0 at 1.2 Hz and a sparkle every
  1.2 s. Outlines are pre-baked sprites in the prop's atlas (one batch, no shader).
- **Badges** (56 px icons above the hotspot): **gold** = usable right now (you carry the item, or it's free);
  **blue closed eye** = hiding spot; **red** = in use next; **grey thought-cloud with the item silhouette** =
  a rig point that needs an item you haven't got. Spent rig points (prank landed) grey out.
- **Hit boxes:** ≥ 144 × 144 px however small the art (the pepper pot is 60 px), ≥ 24 px dead space between any
  two targets, no overlaps. Enforced by the hotspot lint (TECH §10.5) on every house and Night.
- Setting **Hints**: Always (default) / On long-press / Off.

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

### 3.7 Camera
- **Framing:** at zoom 1.0 one floor fills the screen height (640 px interior + 60 px slab) with ≈ 190 px of the
  floors above and below visible. Seeing his legs on the floor above is both a cue and a gag.
- **Follow:** Hush at 40–45 % of the width with 12 % look-ahead toward her walk; exponential smoothing
  τ 0.20 s (0.15 s running); floor changes ease over 0.40 s; no walk bob; limits = house bounds.
- **Gag-Cam** (every prank payoff): cut focus to Bellows, zoom 1.0 → 1.4 (small 1.15, big 1.3, chain finale or
  signature 1.6) in 0.18 s, hit-stop 3 / 5 / 8 frames (cap 150 ms per second), shake 10–16 px decaying over
  0.25 s, hold 1.2–2.0 s on his face, ease back in 0.35 s. **Input stays live; taps queue.**
- **Off-screen payoffs:** if Hush is mid-rig or in danger, the PiP grows to a 704 × 396 **Gag-Cam window**
  instead of cutting away. **No punchline is ever missed.** A gag-cam queue guarantees one punchline at a time.
- **Bellows-Cam PiP:** 448 × 252 at top-right, shown when he is off-screen **and** (within one room, heading to
  Hush's room, or she is rigging); hides 2 s after. Its 6 px frame is coloured by his temper tier. Renders at
  30 Hz. When hidden, an **edge bubble** (112 px face, 36 px label "↑ upstairs", "2 rooms →") points at him.
- **Overview** (0.5×): planning only; poses read, faces don't, so every payoff zooms back in.
- **Audio is the third channel:** his footsteps pan by screen x and fade by rooms between you.

### 3.8 HUD layout (1920 × 1080 base; positions are the top-left of the hit box)

| Element | Position | Visual / hit | Notes |
|---|---|---|---|
| Pause | (S+24, T+24) | 112 / 144 | — |
| **Figgis chip** (hints) | (S+192, T+24) | 128 / 144 | Pulses "psst" after 40 s without progress |
| **Applause-o-Meter** | centred, y = T+16 | 600 × 132 / 600 × 144 | Brass dial 120 px, Applause number 56 px, Script counter "3/5" 48 px, tomatoes 3 × 44 px. Tap = Script panel (pauses). |
| Running Gag banner | centred, y = T+164 | "RUNNING GAG ×1.5" 52 px + fuse bar 420 × 18 | Only while active; non-interactive |
| **Bellows-Cam PiP** | (W−S−472, T+24) | 448 × 252 | Conditional; tap = peek |
| Overview toggle | (W−S−168, T+300) | 112 / 144 | — |
| **Tray** | (S+32, H−B−200) | 4 × 128 / 168, 24 px gaps | — |
| **Clarence / ⏩** | (S+32, H−B−392) | 128 / 168 | Lure ring 8 px |
| **Action button** | centre (W−S−168, H−B−168) | 190 / 240 circle | Ring 14 px |
| **The Stalls** | band from x = S+800 to W−S−312, bottom edge | 40 px resting, up to 120 px on laughs | `mouse_filter = IGNORE`; never a touch target |
| Thought bubble | world space above his head | 150 × 130, icon 88, ring 10 px, glyph 48, ear pips 3 × 20 | Clamped below the HUD band |
| Pun caption | world space by his head | 88 px bold, 6 px outline | 1.2 s, stamp-in 1.6 → 1.0 over 4 f |
| Bonus stamps | beside the caption | 64 px | "MELTDOWN! +8", "COMBO! +4", "NEAR MISS! +2", "EMBARRASSED! +5" |
| Script panel (paused) | centred | 1000 × 680, rows 84 px, text 44 px, icons 72 px | — |

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ [II] [Figgis]        ┌ APPLAUSE ◔ 64   3/5   ● ● ○ ┐          ┌ BELLOWS-CAM ─┐ │
│                      └──── RUNNING GAG ×1.5 ▬▬▬▬░░ ┘          │   448×252    │ │
│                                                               └──────────────┘ │
│                     (   bubble: [🛁 ring]  👓  ••   )                 [ovw]     │
│                                                                                │
│                (world only — the middle 60 % of the height stays clear)         │
│                                                                                │
│ (🐔/⏩)                                                                          │
│ [itm][itm][itm][itm]      ˙ ˙ ˙ the Stalls (heads, IGNORE) ˙ ˙ ˙     ( ACTION )  │
└────────────────────────────────────────────────────────────────────────────────┘
```
HUD anchors to the safe-area corners (symmetric side inset `S = max(left, right)`), sits ≥ 32 px inside it, and
the bottom-centre never holds a touch target. On tablets (logical height > 1250) the HUD scales ×0.8.

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

### 3.10 Text, icons and haptics
- Text: **≥ 36 px anywhere; 44 px for anything read during play; 48–56 px HUD numbers; 80–96 px captions and
  titles**; always a 4–6 px navy outline over the world. Icons and pantomime over words; Script lines are the
  only sentences during play. Fonts: Lilita One (display), Nunito ExtraBold (UI) — both OFL.
- Haptics (`Input.vibrate_handheld`, VIBRATE permission only): tap 8 ms/0.3; ring 50 % 8 ms; rig done
  30 ms/0.7; prank accent 40 + 60 ms; near-miss 20 ms; caught 3 × 30 ms; Meltdown stomps 3 × 60 ms.
  Rate-limited (≤ 6 pulses/s).

### 3.11 Settings and accessibility
Relaxed mode (unlimited tomatoes, "?" windows ×1.5, no badge, no penalty) · Tap-to-rig · Left-handed ·
Hotspot hints (Always / Long-press / Off) · Stare strip (On/Off) · Audience volume · Voice volume · Music ·
SFX · Haptics · Reduce motion (no shake, punch-ins ≤ 1.15×) · Reduce flashing · Text +20 %.
Everything is readable with the sound off (the mute test, §10.4).

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
   next useful hotspot sparkles.
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
Locked rooms in a Night are shown dimmed behind a velvet rope ("backstage").

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

**PROLOGUE — "Curtain Up"** (parlour, kitchen; the hall is backstage) — §2.3. New: squeak, move, hold, hide
(ghost finger each), and ⏩ once. No loading card (its new rule is `basics`) and no Big Number. Loop (scripted,
player-led): `warmup` (waits for the first squeak, then +1 s, max 15 s) → `warmup` (waits until the honey is
rigged, then +2 s; no cap) → `tea` → [FRAZZLED → hall mirror, off-stage] → `warmup` (waits for the lever rig, then
+2 s, or 25 s) → `hunt` (specs on, 6 s, walks 2350 → 1650) → the exit detour upstairs (bubble: the exit icon).
Script: R **ACHOO-RIA!** · R **ALLEGRO-GO-GO!** (lines as "Bellows sneezes up a storm", "Bellows gets in a spin").
No Curtain Calls; unlimited tomatoes; "?" 2.0 s; 60–75 s (Checkpoint G: 62–70 s launch-relative).

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

### 9.1 Art direction (AI-authored SVG cutouts)
- **One-line style:** Saturday-morning cartoon on a stage set — chunky rounded shapes, thick navy ink, flat
  saturated fills with one flat shade tone per shape, lit from the top-left. Family-friendly.
- **SVG rules** (ported from Booby's STYLE.md, `game/art/STYLE.md` is the file copy): presentation attributes
  only; `path/rect/circle/ellipse/line/polyline/polygon/g`, gradients only for walls/sky/glows; no filters, masks,
  `<text>`, `<image>`, CSS or `<use>` chains; ≤ 10 colours per sprite; 3 px canvas margin; compact (1-decimal
  coordinates); authored at display size (1×) and rasterised at 2× by HiResTex.
- **Line weights by layer:** characters 6 px (detail 3.5 px) · interactable props 5 px (detail 3 px) · set
  dressing 4 px (2.5 px) · architecture 3 px `#3A3050` at 80 % opacity. Ink `#1B2340`, round joins and caps.
- **Value hierarchy:** characters strongest saturation; interactables clean and bright with pre-baked outline /
  glow sprites; rooms pastel and 20–30 % desaturated so faces pop.
- **Room palettes:** hall sage `#A9B79A` · parlour dusty rose `#D9A7A0` · kitchen buttercream `#F2DFA6` ·
  conservatory glass `#CDE7E1` · garden lawn `#8ACB6A`, hedge `#4E9A4A`, sky `#9FD6F0` · landing honey wood
  `#C9A27A` · bathroom mint `#BFE3D5` · bedroom powder blue `#B8C7E6` · dressing room teal `#6FA3A8` · floors oak
  `#C98B55` / `#A96C3C`.
- **The stage:** red velvet curtain `#B3122E` with gold trim `#E8B33A`; a gilded proscenium at the house's far
  ends; a warm footlight glow along the bottom (additive sprite) and a cool top vignette. No Light2D, no
  CanvasGroup per character.
- **Rasterisation:** backgrounds/architecture at 1× and VRAM-compressed; characters and props at 2× (1.5× on
  phones with < 3 GB RAM) packed into **one runtime atlas per character and per room** (TECH §5.3).

### 9.2 Characters, faces and takes
- **Rigs:** flat Sprite2D parts on our JSON FK player, rubber-hose Line2D limbs, springs for secondary motion.
  - **Bellows** (~22 parts): barrel torso, belly spring, head, **bouffant** (7 textures: neat, flipped, frazzled,
    wet, floured, feathered, poodle), **sideburn springs** (flat / bristle / puffed), brows, **specs** (on nose,
    dangling, buttered, magnifier), cravat spring, coat tails, hose arms, 6 mitten hands (open, fist, point, grip,
    wag, conduct), hose legs, slippers. Face: eyes × 10 (open, half, closed, wide, pinpoint, angry, spiral,
    balloon, squint, teary), brows × 6, mouths × 10 including the **singing O** in 3 sizes. Skin tinted by temper.
  - **Hush** (~20 parts): beret spring, head, braces, striped torso, hose limbs, flat shoes, **8 glove shapes**
    (wall palm, point, pinch, fist, open, thumbs-up, shush, wave), Clarence as a socketed prop. Face: eyes × 8
    (pupils ≥ 14 px), brows × 5, mouths × 8 (smile default), blush, a small teardrop.
  - **Beryl** (Act II): box body, head, beard, ear/tail/bell springs, 4 hose legs with hooves, eyes × 4.
  - **Delphine** (Act III): gown triangle with a sway spring, head, **beehive spring** with tiara, arms, opera
    glasses on a stick, fan; eyes × 6, mouths × 6.
  - **Figgis:** a bust in a hood (4 expressions + cue-card hands). **The Stalls:** 24 head/hat silhouettes × 3
    frames (rest, laugh-up, lean) on one atlas.
- **Readability minimums at zoom 1.0:** heads 120–150 px; eye whites ≥ 24 px; pupils ≥ 10 px (Hush 14); an open
  mouth ≥ 40 px wide; outlines 6 px. Gag-Cam heads reach 170–210 px.
- **Hush warmth rule:** at a 50 px silhouette and a 96 px face crop she reads as a smiling person, never a clown:
  big pupils, blush, smiling default, thin eye paint, no black lips. Checked on the cast sheet by the owner.
- **Residue overlays** share part pivots: drips, flour tint, frizz, feathers, jelly helmet, tutu, trophy helmet,
  long johns, hedge twigs, tomato splats. Combos have their own looks.

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
| Priority | Hush | Bellows | Others |
|---|---|---|---|
| **P0 — slice** (Stage 2) | idle + 3 fidgets, tiptoe scurry (10 f per step), run (12 f), turn (6 f), door, stairs, rummage, tinker × 3 (Q/S/B), snicker + glance at the Stalls, dive / pop out, hidden eyes, 4 freeze poses, squeak arm, climb in the window, busted, dangled (Lecture), doorstep + tomato, bow | idle + fidgets, strut (28 f per step, belly spring), Irked walk, Steaming stomp, turn, door, stairs; activities: warmup, tea, pickles, snack, rinse, paper, fire, mirror, phone, clock, hunt; suspicious, double take, "?" look, chase, wheeze, grab, Lecture × 3, Meltdown × 1, Exhausted, slow burn, dignity recovery, door-slam bonk, "pardon" bump; reactions: SNEEZE_BLAST, DRENCH A, SING_CRACK, STRAIN_SLIP, AVALANCHE_HELMET A, DIZZY_SPIN, LAUNCH_CEILING, BLIND_BUMBLE A, FISH_SLAP, JACKHAMMER_CLING, the MIRROR, MIRROR signature, HOT & COLD; squeak bits × 6 | Stalls laugh set; Figgis; curtain |
| **P1 — Stage 3** | 4 more freeze poses, garden walk, panto set, Besotted-leading, stage bow | upstairs/garden/Delphine activities; archetypes 9, 10, 13–22; signatures #11, #12, #19, #23, #32; Meltdown × 2 more; 4 combo beats; remaining squeak bits; cold opens × 11 | **Beryl:** idle, graze walk, doze, trot, follow, paw, headbutt, bleat, herded tug · **Delphine:** glide, sit, sip, spray, fan, glasses lift, high C, sing |
| **P2 — Stage 4** | curtain-call variants | curtain-call slow burns | Gag Reel staging, Playbill |

Build order: the **sneeze (#1) end to end first** — rig, clip, sound, laugh, camera, lint, GIF — then the owner
judges it (Gate 0) before mass authoring. A separate review agent scores every gag 1–5 on *funny / readable /
fresh* from its contact sheet and GIF; anything under 3 goes back.

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

### 10.3 The vertical slice (Stage 2)
**Prologue + Nights 1 and 2 at final polish:** hall, parlour and kitchen art; the Hush and Bellows rigs; 11
pranks + HOT & COLD; MIRROR, MIRROR; 6 squeak bits; temper, Running Gag and Meltdown; FREEZE and the specs rule;
hiding, pins and the command queue; the Lecture and the Busted Cam; Figgis hints 1–3; the Stalls at every tier;
the Bellows-Cam; the curtain call with the Gag Reel; adaptive music; haptics; settings (Relaxed, tap-to-rig,
left-handed, volumes). Left out: Beryl, Delphine, upstairs, the garden, the panto bit, meta.

### 10.4 The fun gate (the owner plays the debug APK on his own phone)
**Automated pre-checks (all must pass before he sees it):** the solver clears the Prologue, N1 and N2 on the
*ideal* (★★★), *required-only* (★) and *slow first-timer* routes; Prologue: 6 laughs in 60 s (ideal) and first
player laugh ≤ 10 s / first prank ≤ 30 s from launch (slow); dead air within the §2.4 gate (ideal ≤ 20 %,
required ≤ 25 %, slow ≤ 30 %, worst gap ≤ 12 s, edge beats ≤ ⅓ of the beat credit); the fairness fuzz is green; every
clip passes the animation lint; hotspot, content and IP lints pass; the **mute test** — at least 4 of 6 silent
reaction GIFs read as jokes to a review agent that doesn't know the prank; review scores ≥ 3/5 on every gag;
60 fps p95 with the Gag-Cam, PiP and particles at ≤ 150 draw calls; launch to first laugh ≤ 10 s on a budget
Android (measured from app launch).

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
