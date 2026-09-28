# Mischief Next Door: Making the Slapstick Funny, and Having AI Agents Animate It

Research report: comedy animation, staging, sound, genre references, and a Godot 4.7 cutout pipeline that AI agents can author and check themselves.
All frame counts are at **60 fps** (1 frame at 24 fps = 2.5 frames at 60). **[memory]** = my own knowledge, not a fetched page. **[verified]** = I ran it in this container.

---

## 0. Ten findings that matter most

1. **The victim is a straight man with dignity.** Slapstick is a pompous man losing his dignity, not the player losing HP. Booby put the *player's* raider in the traps; here the neighbour is the butt of every joke and the player is the audience's accomplice.
2. **Show the trap first, then hit fast.** Avery: the eye needs about 5 frames at 24 fps (≈12 f here) to register an action, and showing the object "four or five frames before the hit" makes the gag funnier ([Cartoon Brew](https://www.cartoonbrew.com/cartoon-study/a-thrilling-tour-through-the-history-of-wild-takes-in-animation-243744.html)). The walk-up is suspense; the hit is a 2–4 f accent.
3. **Every reaction is ANTICIPATION → ACCENT → HOLD → SETTLE**, with a 30–60 f hold. The laugh lands in the hold, so the laugh track, the rating number and the face read go there.
4. **Cut into reactions, don't blend** (`blend_in: 0`, a pose pop); blend out over 8–12 f. Smooth tweening into an accent is the floaty "Flash cartoon" look.
5. **Repetition kills the laugh.** NfH reviewers complained about "the same exact animation of him roaring in anger" and a neighbour who "moves at a plodding pace" ([Game Hoard](https://thegamehoard.com/2018/04/27/neighbours-from-hell-pc/)). Give each reaction ≥2 variants and 3 intensity tiers, plus **visual residue that persists and stacks**.
6. **Never let a payoff happen off-screen**: auto-pan, or pop up a picture-in-picture inset.
7. **Scale the laugh track to prank quality**: 5 tiers plus "Ooooh!", "Awww" and a gasp. NfH already laughed quietly on setup and loudly on trigger ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/NeighboursFromHell)).
8. **Rig: flat Sprite2D parts plus our own data-driven keyframe player.** Not Skeleton2D/Polygon2D weights: weight painting is editor-only and fragile ([Godot forum](https://forum.godotengine.org/t/polygon2d-skeleton-deformation-some-tips-tricks/46379)), and the 2D modification stack is *Experimental* ([docs](https://docs.godotengine.org/en/stable/classes/class_skeletonmodificationstack2d.html)). Booby's `RigPose` already proves flat FK works.
9. **Agents author poses, not frames**: a pose library, plus clips that reference poses with integer frame keys, named eases and events. A linter enforces the comedy timings as numbers.
10. **Agents must see their work**: pose/contact sheets, onion strips, motion curves, and Movie Maker capture: `xvfb-run … godot --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 60 --quit-after N` produced a PNG sequence plus `f.wav` here **[verified]**.

---

## 1. Comedy animation principles, in numbers

### 1.1 How a gag beat is built

| Phase | Purpose | Small gag | Big gag | Notes |
|---|---|---|---|---|
| **Setup / approach** | Audience sees the trap, then the victim nearing it | 30–60 f | 60–120 f | Music thins out; optional 0.5× slow-mo for the last 24 f |
| **Anticipation** | Wind-up opposite the action | 8–12 f | 15–24 f | in_cubic; must move *against* the accent |
| **Accent** | The hit, pop or launch | 2–4 f | 2–4 f | Step/linear, a 1–2 f smear, hit stop 3–8 f |
| **Hold** | Audience reads the face and laughs | 30–45 f | 45–90 f | "Moving hold" (≤2% drift, breathing, tremble); laugh starts here |
| **Settle** | Overshoot once, recover | 8–15 f | 15–30 f | out_back or one overshoot key; then rage or a dignity beat |

School of Motion's take breakdown at 24 fps ([source](https://www.schoolofmotion.com/blog/how-to-animate-character-takes)):
- 4 poses: Start → Anticipation → Accent → Settle.
- Into anticipation: 4–6 f (10–15 f here), ~90% ease-in.
- Anticipation → accent: ~7 f linear (17 f); accent → settle ~7 f (17 f).
- The punchier Warner Bros style holds anticipation 6 f (15 f), then **pops to the accent in 1 frame (2–3 f here)**.

Use the WB pop for prank reactions and the softer version for "notice" beats.

### 1.2 Takes and double takes

- **Take**: neutral → small squash, eyes shut (anticipation) → pop to the extreme (eyes huge, body stretched, hat off) → hold → settle to a readable emotion.
- **Double take**: glance at the thing, look away obliviously for 12–20 f, snap back. School of Motion spaces head turns 3 f apart at 24 fps (≈8 f here), ~9 f from anticipation to accent (≈22 f).
- **Wild take** (Avery): eyes inflate like balloons, jaws stretch like rubber ([Cartoon Brew](https://www.cartoonbrew.com/cartoon-study/a-thrilling-tour-through-the-history-of-wild-takes-in-animation-243744.html)). In cutout:
  - eye sprites 1.6–2.0× for 3–4 f, settling to 1.2×;
  - head `sy` 1.3;
  - jaw pops down 20 px.
- **Slow burn** (Oliver Hardy's camera look) **[memory]**: after a humiliation, stare at the camera for 60–90 f with one blink. Nearly free to animate; the purest straight-man beat. Use it as the tier-1 post-prank beat about one time in four.

### 1.3 Squash, stretch, overshoot and smears in cutout

- **Whole-body squash around the feet anchor** is the cheapest and strongest tool; Booby did it with body scale around an anchor. Preserve area with `sx = 1/sy`.
  - Landing: `sy 0.70 / sx 1.30` for 3 f → rebound `sy 1.15 / sx 0.87` for 4 f → settle over 6 f.
- **Part squash**: a bonked head squashes into the torso (`sy 0.6`, `y +12`) for 4 f, then accordions back.
- **Overshoot**: Godot's `TRANS_BACK/EASE_OUT` gives 1.08 at t=0.7 **[verified]**. One overshoot per settle; two looks like jelly.
- **Smears** come in three kinds: elongated in-betweens, multiples, motion lines ([Wikipedia](https://en.wikipedia.org/wiki/Smear_frame)). In a cutout rig:
  - (a) stretch the part along its velocity for 1–2 f (`1 + k·v`, cap 2.0×);
  - (b) draw 2–3 ghost copies at the last FK transforms (alpha 0.45/0.25/0.12);
  - (c) speed lines along the trajectory;
  - (d) a `smear` texture swap.
  - Trigger automatically above 25°/f or 40 px/f, or explicitly with an event.
- **Rubber-hose limbs**: arms and legs as round-capped Line2D curves with hand/foot sprites: no seams, free stretch.

### 1.4 How comedy is structured

- **Rule of three**: set up, repeat, subvert.
  - Pepper sneeze: "ah" 20 f → "ahh" 24 → "ahhh" 30 → *false stop* 20 (relief) → CHOO 3 f with recoil.
  - Level scripting too: two near-misses, and the third one gets him.
- **Escalation** by anger and chain count:
  - Tier 1: grumble plus fist shake.
  - Tier 2: red tint plus ear steam.
  - Tier 3: rage stomp ×3 with shake, then a kettle whistle.
  - NfH's anger meter drained fast and was hard to read ([Game Hoard](https://thegamehoard.com/2018/04/27/neighbours-from-hell-pc/)). **Let the body be the meter**, with a 12–15 s chain window **[design suggestion]**.
- **Humiliated more than harmed**: Chuck Jones's rules say "the Coyote is always more humiliated than harmed" and "make gravity the Coyote's greatest enemy" ([Mental Floss](https://www.mentalfloss.com/article/62035/chuck-jones-rules-writing-road-runner-cartoons)). Residue should be ridiculous (frazzled hair, missing eyebrow, underpants), never injury.
- **Dignity recovery**: straighten the tie, look around ("did anyone see?") for 40 f, then resume the routine *still wearing the residue*. A second laugh for free.
- **The prankster's snicker** (shoulders at 8 Hz, 40 f) makes the player complicit.

### 1.5 Variety, so it stays funny for hours

- ≥2 authored variants per reaction.
- Procedural modifiers: timing jitter ±8%, a random voice line, a random falling object (a hat, a tooth, a picture frame) 20 f later.
- **The first hit of a prank type** in an episode plays in full; **repeats play a trimmed cut at about 60% length**, the way TV editors trim.
- **Stacking residue**: soot + drenched = black streaks and a hiss; itch + sticky = scratching while stuck. Angry Birds pigs bruise progressively in the same way **[memory]**.

---

## 2. Staging and camera

| Tool | When | Numbers |
|---|---|---|
| **Punch-in** | Every prank accent | Zoom 1.15 / 1.3 / 1.6 (small, big, chain finale), 6–8 f `out_cubic` on the victim's head; hold through the reaction, return over 24–36 f `in_out_sine` |
| **Hit stop** | Contact frame | 3 / 5 / 8 f. Keep Booby's `JuiceClock` rule: **cap of 150 ms of freeze per 1 s**. The victim vibrates ±3 px during it, as in Smash ([CritPoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/)) |
| **Screen shake** | Explosions, falls, stomps | Trauma model **[memory, Eiserloh GDC 2016]**: 12 px·trauma², 1.5°·trauma², ~25 Hz noise, decay 1.5/s; +0.35 per stomp |
| **Approach slow-mo** | Victim ~0.5 s from an armed prank (first time per type, or chain finisher) | 0.5× for the last 24 f, music to tremolo or tick, vignette |
| **Freeze frame** | Biggest gag of a chain | 45–60 f, 70% desaturation with a paper border, record scratch, "+15%" stamp (4 f, 1.6→1.0) |
| **Picture-in-picture** | Prank fires out of view | Inset ~30% of screen width, pops in over 8 f `out_back`; a second `Camera2D` in a `SubViewport` sharing `world_2d`; stays until the hold ends +20 f |
| **Iris out** | Episode end | Closes over 36 f `in_cubic` to r≈90 px on the neighbour's head, holds 30 f for one last micro-gag, then closes over 8 f. `ColorRect` shader: `alpha = step(r, distance(FRAGCOORD.xy, c))` |
| **Fight cloud** | Neighbour catches the prankster | 90 f dust loop with limbs, stars and "#@$%!" grawlix; the prankster is ejected out the front door **[memory]** |

Frame the side view like a dollhouse (two rooms visible); the victim ≥180–220 px tall at 1080p so faces read on a phone.

---

## 3. Sound

### 3.1 The cartoon SFX palette

- Treg Brown built the Warner library from 1936 to 1963 and got *rid* of the all-purpose slide whistle ("Everything you did was a slide whistle, until you went stark raving mad") ([Wikipedia](https://en.wikipedia.org/wiki/Treg_Brown)). Use the slide whistle only for rises and falls.
- Booby's numpy generator (`tools/audio/gen_audio.py`) already synthesizes boing ×3, slide_up/down, bonk, splat, zap, sizzle, whoosh, sad_trombone, record_scratch, kazoo_fanfare, sneeze and laugh_track. Reuse those recipes.

| Class | Use | Rule |
|---|---|---|
| Wood block / bonk | Head hits, sneak steps | On the contact frame ±1 f |
| Boing | Bounces, eye pops | Pitch rises with the size of the pop |
| Slide whistle ↑↓ | Launch, fall, hang | Down through the whole fall; silence, then crash |
| Whoosh / zip | Exits, smears, run start | Plus a dust puff |
| Crash tail | Off-screen falls | Crash → 300 ms silence → one pan spinning to rest |
| Pizzicato steps | Sneak / tiptoe | One note per footfall, walking up a scale (mickey-mousing) |
| Ratchet / tremolo | Suspense approach | Loops while the victim nears an armed prank |
| Timpani / cymbal | Big accents | Synced to hit stop |
| Tweets / cuckoo | Dazed loop | With orbiting stars |
| Zap / sizzle / hiss | Shock, burnt bum, steam | — |
| Stingers | Armed (ding + 3-note pizz), chain ×2/×3 (rising brass), fail (sad trombone) | ≤1.5 s, duck music −6 dB |

### 3.2 Laugh track and audience

| Tier | Trigger | Content | Length / level |
|---|---|---|---|
| T0 titter | Prank armed | 2–3 voices | 0.6 s, −18 dB |
| T1 chuckle | Low-score prank | 5–6 voices | 1.2 s |
| T2 laugh | Mid-score | 12–14 voices + one "HA!" | 2.0 s |
| T3 laugh + applause | Chain ×2 | 20+ voices, 2 s applause | 3.0 s |
| T4 roar | Chain ×3+, 100% episode | Roar, whistles, stomps | 4–5 s |
| "Ooooh!" | Painful-looking gags | Wince *before* the laugh | 0.8 s |
| "Awww" | Prank fizzles | — | 1.0 s |
| Gasp | Prankster nearly spotted | — | 0.5 s |

- Start the laugh at the **start of the hold** (6–12 f after the accent).
- Never play the same laugh file twice in a row: `AudioStreamRandomizer` has `PLAYBACK_RANDOM_NO_REPEATS` **[verified]**.
- Duck the laugh 6 dB under the neighbour's vocal.
- The audience cheers at episode start and end (as in NfH).

### 3.3 Adaptive music

Untitled Goose Game (UGG) made **two versions of each Debussy Prelude** (a low-energy one and a normal one), split them into reverb-tailed stems, and switched between *silent*, *low-energy* (planning) and *active* (chase) states ([Game Developer](https://www.gamedeveloper.com/audio/getting-goosey-with-debussy-creating-an-adaptive-score-for-i-untitled-goose-game-i-)). Copy this:
- Stems: sneak (pizzicato), suspense (tremolo), chase (galop).
- Base them on **public-domain compositions** (Grieg's *Hall of the Mountain King*, Offenbach's *Galop infernal*, Saint-Saëns), rendered by our own synth, because only the composition is public domain.

### 3.4 Gibberish voices

Prior art: **Simlish** avoided real languages because players "would grow to show disdain for repetitive dialogue" ([Wikipedia](https://en.wikipedia.org/wiki/Simlish)); **Animalese** plays one fast sound per letter, pitched by personality and mood ([Nookipedia](https://nookipedia.com/wiki/Animalese)); **Banjo-Kazooie** rearranged grunt samples ([Wikipedia](https://en.wikipedia.org/wiki/Banjo-Kazooie_(video_game))); **Springbound** uses formant loops, ~0.1 s pitch slides and a ~280 Hz low-pass when the mouth closes ([devlog](https://brycetown.substack.com/p/springbound-devlog-4-making-critters-talk)).

Our recipe reuses Booby's formant synth (`tools/audio/sfx_voices.py`, `voice_lines.py`: `voice()`, `vowel_track`, a `Speaker` with f0/tract/jitter, and contours):
- **Offline (Python)**, per character:
  - ~24 CV syllables at 90–140 ms each;
  - ~12 nonverbals × 2–3 variants: hmph, huh?, WHA!, yow, oof, aaagh, grr, ah-ah-CHOO, cough, snicker, humming. Nonverbals carry slapstick, so give them about 60% of the voice budget.
  - Neighbour: f0 95–110 Hz, tract 0.9. Prankster: f0 260–300 Hz, tract 1.2.
- **Runtime `GibberishVoice`**:
  - 3 round-robin `AudioStreamPlayer`s.
  - 11–15 syllables/s for chatter, 6–8 for grumbles.
  - `pitch_scale = 2^(st/12)` per syllable, following a contour:
    - statement: +2 → −2 st;
    - question: last syllable +5;
    - anger: −3 base, +20% rate, +3 dB, distortion bus;
    - surprise: first syllable +7 at 1.5× length;
    - plus ±1 st jitter.
  - Seed the RNG with a hash of the line so replays are identical.
  - Mouth flaps "open" for 60% of each syllable; anger bubbles show grawlix.

---

## 4. How the reference games sell it

- **Untitled Goose Game**
  - Slapstick and pantomime "with big, over the top reactions" told through body language, plus comic-book FX: honk lines, stars on a hit thumb ([Game Developer](https://www.gamedeveloper.com/design/behind-the-honk-an-i-untitled-goose-game-i-q-a)).
  - NPCs get "reaction animations for state transitions", plus vision cones and thought bubbles.
  - ~160 props, each with its own sounds.
  - The harsh honk is funnier against gentle prop sounds ([A Sound Effect](https://www.asoundeffect.com/untitled-goose-game-sound/)).
  - **Lesson**: state transitions *are* reaction beats; contrast sells.
- **Neighbours from Hell**: TV-show frame, rating % per trap, chain bonus while he still fumes ([Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2584421942)); failed on repetition and waiting. **Lesson**: keep the TV frame, fix variety, give the routine micro-gags every 5–8 s so watching him is entertaining.
- **Scary Teacher 3D** **[memory + weak source]**
  - Each payoff is a short uninterrupted cutscene: a cut to the teacher's huge take and scream, then the player's gloat. The mess persists afterwards.
  - Praised as "over-the-top", "playful rather than cruel" ([source](https://www.gambiacollege.edu.gm/blog/scary-teacher-3d-chapter-2-new-pranks-and-challenges-1767647315)).
  - **Lesson**: on mobile, a 2–4 s no-input payoff is a reward. Take the camera, keep it short.
- **Worms**: tiny characters with big voice banks, catchphrases around actions ([Worms Wiki](https://worms.fandom.com/wiki/Speech)); musical punchlines like the Holy Hand Grenade's "Hallelujah" **[memory]**. **Lesson**: one vocal line per event, a stinger as punchline.
- **Angry Birds** **[memory]**: pigs laugh when you fail; progressive damage faces; distinct material impacts; stillness before a collapse; score numbers float from each broken object. **Lesson**: the neighbour smirks when a prank fizzles; the rating floats out of the victim during the hold.

---

## 5. Tech: cutout rigs in Godot 4.7

### 5.1 Which rig

| | Skeleton2D + Bone2D + Polygon2D | **Flat Sprite2D parts + own FK player (recommended)** |
|---|---|---|
| Agent authoring | Weights painted in the editor, stored as opaque `.tscn` arrays; partial undo; rest-pose traps | `rig.json` + SVG parts, all text and diffable |
| Deformation | Mesh bending | Part scale, rubber-hose Line2D limbs, texture swaps |
| IK | Modification stack (Experimental) | 2-bone analytic IK (~30 lines), for foot plant and reach only |
| Draw order | Awkward | A `z` channel per key; parts are siblings |
| Testing | Needs a scene tree | Pure `RefCounted` sampling, headless unit tests |
| Proven here | No | Booby's `RigPose` (flat FK, `centered=false, offset=-pivot`), `NoodleRig`, `HiResTex` |

- Booby's poses were rotation-only. Add channels `rot, x, y, sx, sy, z, tex, vis, alpha`.
- Put each character's parts in one atlas **[memory: batching]**.

### 5.2 AnimationPlayer or JSON

- AnimationPlayer resources are verbose NodePath tracks with float-exponent transitions and uid ids. They can't say "use pose X", can't be mirrored or varied, and are hard to lint. Manual stepping does exist (`callback_mode_process = manual` + `advance()`, [docs](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)).
- **Recommendation: JSON clips sampled by our own player** (~600–800 lines of GDScript).
  - Eases map to `Tween.interpolate_value(…, TRANS_*, EASE_*)`. BACK, ELASTIC, BOUNCE, EXPO and SPRING exist in 4.7 **[verified]**.
  - One sampler serves the game, the tests and the verification renderer.
  - A dev "anim viewer" scene hot-reloads JSON (mtime poll every 0.5 s) for humans.
  - Keep AnimationPlayer for UI only.

### 5.3 Runtime layers, evaluated in order

1. **Base clip**, crossfaded with per-bone `lerp_angle`.
   - Default blend 6 f; reactions `blend_in` 0; `blend_out` 8–12 f.
   - Walk playback rate = `speed / (stride_px / (cycle_f/60))`, so feet don't slide.
2. **Masked overlay**: an upper-body clip (carrying a bucket) over locomotion.
3. **Additive layer**:
   - Breathing: torso `sy` ±1.5% over 3.2 s (neighbour ±2.5% over 4 s).
   - Shiver: ±2° at 12 Hz.
   - Look-at: head ±20°, pupils ±3 px. The victim's eyes can track the trap: dramatic irony for free.
4. **Springs**:
   - Booby's `NoodleRig` values: k = 220 s⁻², c = 10 s⁻¹ (ζ≈0.34), clamp ±70°, driven by root acceleration and event kicks.
   - Belly or hat: k≈300, c≈12. Hair or tie: a 2–3 link chain at k≈180.
5. **Face**: eyes, brows and mouth slots plus pupils and overlays (sweat, vein, soot mask).
   - Presets in `faces.json`, e.g. `shock = {eyes: wide, brows: up, mouth: O}`.
   - Swaps are always stepped, on key frames.
   - Blinks every 2–6 s, 6 f long (2 closing / 2 closed / 2 opening), 15% chance of a double; suppressed during takes.
6. **Props**: hand sockets (`grip: [x, y, angle]`).
   - An attached prop copies the socket transform.
   - `launch` hands the prop to a deterministic ballistic arc with spin; no physics engine, so replays stay exact.
7. **Facing**: art faces right; flip with root `scale.x = -1`.
   - Turns are a 6 f clip (scale.x 1 → 0.15 → −1, swapping at the midpoint).
   - `no_mirror` parts (signs, text) counter-flip.
8. **SVG at 2×**: reuse `HiResTex`.
   - It uses `Image.load_svg_from_string(svg, 2.0)` ([docs](https://docs.godotengine.org/en/stable/classes/class_image.html)) and overrides the texture size to 1×.
   - It supports colour swaps and drops to 1.5× on phones under 3 GB RAM.
   - Base resolution 1920×1080 landscape; linear filter, no mipmaps.

---

## 6. The data-driven animation format

Rules:
- Integer **frames at 60 fps**, degrees, pixels at 1× scale, y pointing down.
- Closed enums for eases and events; every name must resolve.
- A key's `ease` is **the curve used to travel from the previous key to this key**.
- Poses are **resolved to full poses at load**, so interpolation is never ambiguous.

**`rig.json`**:
```json
{"rig":"neighbour","height_px":210,"root_part":"torso",
 "parts":{
  "torso":{"file":"torso.svg","pivot":[40,70],"z":0},
  "head":{"parent":"torso","offset":[4,-62],"pivot":[38,70],"z":5,"limits":{"rot":[-35,35]}},
  "arm_upper_l":{"parent":"torso","offset":[-18,-48],"pivot":[9,8],"z":-3,"limits":{"rot":[-180,60]}},
  "arm_lower_l":{"parent":"arm_upper_l","offset":[0,34],"pivot":[8,6],"z":-2,"limits":{"rot":[-5,150]}},
  "hand_r":{"parent":"arm_lower_r","offset":[0,30],"pivot":[10,6],"z":7,
            "sockets":{"grip":[12,14,90]},"tex":{"open":"hand_r.svg","fist":"hand_r_fist.svg","smear":"hand_r_smear.svg"}}
 },
 "face":{"anchor":"head","offset":[6,-30],"slots":{"eyes":["open","half","closed","wide","pinpoint","angry","spiral","white_on_soot"],
   "brows":["neutral","up","angry","worried"],"mouth":["closed","smile","grin","O","scream","grit","wavy","open"]}},
 "mirror_pairs":[["_l","_r"]],"no_mirror":["sign"]}
```

**`poses.json`** (40–60 poses per character):
```json
{"nb_stand":{"root":{"y":0},"bones":{"torso":{"rot":0},"head":{"rot":0},"arm_upper_l":{"rot":8}}},
 "nb_take_antic":{"base":"nb_stand","root":{"y":10,"sx":1.12,"sy":0.88},
   "bones":{"torso":{"rot":6},"head":{"rot":10,"y":6},"arm_upper_l":{"rot":20}},"tags":["take","antic"]},
 "nb_take_accent":{"base":"nb_stand","root":{"y":-30,"sx":0.85,"sy":1.25},
   "bones":{"torso":{"rot":-8},"head":{"rot":-12,"y":-18,"sy":1.15},"arm_upper_l":{"rot":-150},"arm_lower_l":{"rot":-20}},
   "tags":["take","accent"],"silhouette":"arms up in a V, body tall"},
 "walk_pass_R":{"mirror":"walk_pass_L"}}
```

**A clip** (`anim/neighbour/take_spot.json`):
```json
{"clip":"nb_take_spot","rig":"neighbour","loop":false,"blend_in":0,"blend_out":10,
 "beats":{"anticipation":[18,30],"accent":[30,33],"hold":[33,60],"settle":[60,72]},
 "keys":[
  {"f":0, "pose":"nb_stand","face":"smug"},
  {"f":10,"pose":"nb_glance_away","ease":"in_out_quad"},
  {"f":18,"pose":"nb_glance_back","ease":"out_quad","face":"blank"},
  {"f":30,"pose":"nb_take_antic","ease":"in_cubic","face":"squint"},
  {"f":33,"pose":"nb_take_accent","ease":"linear","face":"shock","set":{"hand_r":{"tex":"open"}}},
  {"f":42,"pose":"nb_take_accent","ease":"out_back","set":{"root":{"y":-22}}},
  {"f":60,"pose":"nb_take_accent","ease":"hold"},
  {"f":72,"pose":"nb_angry_ready","ease":"out_cubic","face":"furious"}],
 "events":[
  {"f":30,"type":"sfx","id":"slide_up_short"},
  {"f":33,"type":"sfx","id":"boing_eyes"},
  {"f":33,"type":"hitstop","frames":4},
  {"f":33,"type":"cam","op":"punch","zoom":1.2,"in":6,"hold":27,"out":20},
  {"f":33,"type":"fx","id":"surprise_lines","at":"head","dur":24},
  {"f":33,"type":"prop","op":"launch","prop":"hat","vel":[40,-600],"spin":720},
  {"f":34,"type":"voice","vocal":"wha","emotion":"surprise"},
  {"f":36,"type":"laugh","tier":"auto"},
  {"f":33,"type":"mark","name":"accent"}],
 "variation":{"time_jitter":0.08,"rot_jitter":3},
 "smear":{"auto":true}}
```

- **Eases**: `linear, hold, pop`, plus `in_/out_/in_out_` × `quad, cubic, quart, expo, sine, back, elastic, bounce`.
- **Events**: `sfx, voice, laugh, fx, face, cam, shake, hitstop, slowmo, freeze, prop, smear, mark`. `mark` syncs game logic (damage at `accent`, release at `release`).
- **Variants and tiers**: `reactions.json` maps `slip → {t1:[slip_a,slip_b], t2:[…], t3:[…], short:[slip_short]}`, picked without repeats.

---

## 7. How agents check their animations

Every render uses **the game's own sampler**. A tool script runs under `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 --audio-driver Dummy -s res://tools/anim/sheet.gd -- --clip nb_take_spot --out /tmp/anim/` (Booby's CI already uses xvfb + opengl3). It puts the rig in a `SubViewport`, samples frames, calls `get_texture().get_image()`, composes the sheets with `Image.blit_rect`, and writes PNGs, which agents read as images.

1. **Rig sheet**: exploded parts with pivot crosshairs, plus the rig at joint limits (catches wrong pivots).
2. **Pose sheet**: every pose, labelled, plus a **solid black silhouette** of each. A pose that doesn't read in silhouette is rejected.
3. **Contact sheet**: a cell every 3 f plus every key.
   - Keys outlined red, holds blue; events printed under cells (`sfx:bonk`, `face:shock`).
   - A copy at **true phone size**.
4. **Onion strip**: each beat's frames overlaid, tinted blue (past) to red (future), with **spacing traces** (a dot per frame on head top, hands and root).
   - Even spacing = floaty.
   - Dense-then-gap = a proper snap.
   - A zigzag arc = jitter.
5. **Motion curves**: `curves.json` (per bone, per channel, per frame) plotted with Pillow as value and velocity with key markers. Pillow 12.3 and numpy 2.4 are present; matplotlib is not **[verified]**.
6. **Lint and timing report** (the build fails on errors):
   - **Structure**: frames increase; all ids resolve; joint limits respected.
   - **Loops**: seam matches within 0.5° with continuous velocity.
   - **Accent**: ≤4 f, with peak speed ≥20°/f on some bone (otherwise "mushy accent").
   - **Anticipation**: displacement opposes the accent (dot < 0).
   - **Holds**: reaction holds ≥24 f (≥36 f at tier 2+). A hold over 20 f with zero motion on every channel is a "dead hold" unless it is a freeze.
   - **Pops**: no jump over 45°/f unless the key is `pop` or smeared.
   - **Twinning**: left and right limbs identical for more than 10 f.
   - **Feet**: planted foot drifts ≤2 px; nothing more than 3 px below the floor.
   - **Sync**: impact sfx within ±1 f of a key; face swaps only on keys; laugh after the accent.
   - **Length**: reactions 60–180 f unless `skippable`.
   - **Silhouette**: the bounding box changes ≥15% between anticipation and accent.
7. **Movie capture**: the real gag, with audio, via Movie Maker ([docs](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)).
   - Command: `--write-movie /tmp/cap/f.png --fixed-fps 60 --quit-after 300`.
   - Pillow makes a 30 fps GIF for reviewers.
   - The WAV's sfx onsets (numpy onset detection) are checked against the `mark` frames.
8. **Golden hashes** of the sampled poses per clip, so changes show up in review.

**Self-review rubric** (the agent answers each in writing, citing frames):
1. Reads in silhouette at phone size?
2. Anticipation opposes the action?
3. Accent ≤4 f with a pop or smear?
4. A hold of ≥30 f where the face reads?
5. Exactly one overshoot?
6. Sfx on the contact frame?
7. Face swap on the accent?
8. Any sliding or floor penetration?
9. Laugh after the hold starts?
10. How is this different from the last time the player saw it?

---

## 8. Animation beat list (60 fps)

A = anticipation, X = accent, H = hold, S = settle. P = prankster, N = neighbour.

| # | Beat | Who | Structure (frames) | Total | Sound / FX |
|---|---|---|---|---|---|
| 1 | Idle + fidgets | P/N | Loop; fidget every 4–8 s (look 60, scratch 45, hum 90) | 120 loop | Breathing, blinks |
| 2 | Walk | P | 22 per step | 44 loop | Soft steps |
| 3 | Pompous strut | N | 28 per step, 6 px bob, belly spring | 56 loop | Thuds, humming |
| 4 | Cartoon sneak | P | 40 per step, 8 f hang at knee-top | 80 loop | Pizzicato per step |
| 5 | Tiptoe scurry | P | 10 per step, 2 px bob | 20 loop | Ticks |
| 6 | Run | P | 12 per step | 24 loop | Dust on start |
| 7 | Rev-up start | P | Legs spin in place 20, launch 4 | 24 | Flutter, zip |
| 8 | Skid stop | P | Lean back 18, S 6 | 24 | Squeak, dust |
| 9 | Turn | P/N | Squash-swap 6 | 6 | — |
| 10 | Door in/out | P/N | Turn 8, step 12 | 20 | Creak |
| 11 | Stairs / ladder | P/N | 24 per step | 48 loop | Random creaks |
| 12 | Hide (dive) | P | A 4, dive 6, S 4 | 14 | Whoosh, thump |
| 13 | Hidden eyes | P | Eyes in the dark, blinking | 90 loop | — |
| 14 | Hold breath | P | Cheeks puff 12, H, sweat; exhale 20 | 60+ | Gasp if close |
| 15 | Peek | P | Head out 10, look L 18, look R 18, back 6 | 52 | — |
| 16 | Pick up | P | Crouch 8, grab 4, lift 12, H 20 | 44 | Per-object pickup |
| 17 | Tinker / set up | P | Hand flurry, 3 variants | 36 loop | Clanks, sparks |
| 18 | Pour / spread | P | A 6, pour 18, S 6 | 30 | Glug / scatter |
| 19 | Place / throw | P | A 8, X 3, S 9 | 20 | Whoosh |
| 20 | Evil snicker | P | Hunch 8, shoulders 8 Hz × 32 | 40 | T0 titter |
| 21 | Busted! | P | Freeze 6, eyes pop 3, jump 10, land 6 | 25 | Gasp, boing |
| 22 | Collared | P | Legs pedal in the air | 16 loop | Flutter |
| 23 | Thrown out | P | Tumble 40, squash 8, dizzy 60 | 108 | Slam, tweets |
| 24 | Victory | P | Jump 14, fist pump H 30, S 16 | 60 | Cheer, fanfare |
| 25 | Suspicious | N | Stop 10, squint 6, slow head turn 30 | 60 | "hmm?" |
| 26 | Spot (double take) | N | Away 10, back 8, A 12, X 3, H 27, S 12 | 72 | See §6 |
| 27 | Chase | N | 16 per step, fists pumping | 32 loop | Steam, galop |
| 28 | Grab | N | A 8, X 4, H 12 | 24 | Grunt |
| 29 | Fight cloud | N+P | Cloud loop | 90 | Grawlix, bonks |
| 30 | Grumble (tier 1) | N | Fist shake 3 × 10 | 40 | Mutter |
| 31 | Steaming (tier 2) | N | Red ramp 30, steam H 30 | 60 | Kettle hiss |
| 32 | Rage stomp (tier 3) | N | 3 × (A 6, X 2, S 8), kettle H 40 | 88 | Shake per stomp |
| 33 | Slow burn | N | Stare at camera 70, one blink | 70 | Silence → titter |
| 34 | Dignity recovery | N | Straighten tie 30, look around 40 | 70 | "ahem" |
| 35 | Slip | N | Windmill A 18, hang 10, fall 4, X 3 + hitstop 5, dazed H 50, up 24 | 114 | Slide-up, thud, tweets |
| 36 | Bonk | N | X 2, accordion 4, H 24 (lump grows 12), stars 60 | 90 | Bonk, "Ooooh" |
| 37 | Shock | N | Skeleton flash every 4 f × 36, hair spikes → soot | 60 | Zap |
| 38 | Soot / explosion | N | Flash 2, hitstop 6, H 30, 2 blinks × 8, cough 20, tooth falls 12 | 110 | Boom, "tink" |
| 39 | Drenched | N | Splash 3, droop H 40, dog-shake 30 at 10 Hz | 80 | Splash, drips |
| 40 | Sneeze | N | ah 20, ahh 24, ahhh 30, false stop 20, CHOO 3, recoil 20 | 120 | Rule of three |
| 41 | Stuck | N | Tug 3 × 20 (escalating), pop 4, stumble 20 | 90 | Strain, cork pop |
| 42 | Fall (trapdoor/chair) | N | Hang + camera look 30, fall 8, off-screen crash, item lands 20 later | 70 | Down-whistle, crash tail |
| 43 | Burnt bum | N | Sit 10, delay 18, bulge 3, rocket up 12, fanning run 60 | 105 | Sizzle, scream, hiss |
| 44 | Sticky feet | N | Taffy-stretch 30, snap 6, face-plant 8, H 30 | 74 | Creak, splat |
| 45 | Itch | N | Scratch loop (3 intensities), doorframe back-scratch 60 | 36 loop | Scritch |
| 46 | Toe pinch | N | Snap 2, hop 3 × 14 | 50 | Snap, "yow" |
| 47 | Spit take | N | Sip 30, H 12, spray 10, tongue fan 40 | 92 | Spray |
| 48 | Scare jump | N | X 3, clings to lamp H 40 (12 Hz tremble), drop 10 | 55 | Shriek |
| 49 | Dazed | N | Head circle, stars orbit | 60 loop | Tweets |
| 50 | Smirk / taunt | N | Smug 30 when a prank fizzles | 30 | "hmph", "Awww" |

The first minute of play needs #4, #17, #20, #25, #35 and #30/#32. **Build #35 (slip) end to end first** to prove the pipeline.

---

## 9. Suggested agent pipeline

1. **Rig agent**: SVG parts (Booby STYLE.md conventions) → `rig.json` → rig sheet.
2. **Pose agent**: `poses.json` → pose and silhouette sheets.
3. **Clip agent**: clips → lint, sheets, curves → iterate until lint passes and the rubric is answered.
4. **Gag agent**: prank sequences → Movie Maker capture → GIF.
5. **Review agent** (separate context): scores funny / readable / fresh per beat; below the bar goes back.
6. **Owner**: plays the APK; his notes become lint rules or pose changes.

---

## Sources

- School of Motion, takes: https://www.schoolofmotion.com/blog/how-to-animate-character-takes
- Cartoon Brew, wild takes: https://www.cartoonbrew.com/cartoon-study/a-thrilling-tour-through-the-history-of-wild-takes-in-animation-243744.html
- Smear frame: https://en.wikipedia.org/wiki/Smear_frame · https://garagefarm.net/blog/smear-frames-enhancing-motion-in-animation
- Chuck Jones's rules: https://www.mentalfloss.com/article/62035/chuck-jones-rules-writing-road-runner-cartoons
- Hitstop: https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/
- Treg Brown: https://en.wikipedia.org/wiki/Treg_Brown
- UGG: https://www.gamedeveloper.com/design/behind-the-honk-an-i-untitled-goose-game-i-q-a · https://www.asoundeffect.com/untitled-goose-game-sound/ · https://www.gamedeveloper.com/audio/getting-goosey-with-debussy-creating-an-adaptive-score-for-i-untitled-goose-game-i-
- NfH: https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/NeighboursFromHell · https://thegamehoard.com/2018/04/27/neighbours-from-hell-pc/ · https://steamcommunity.com/sharedfiles/filedetails/?id=2584421942
- Scary Teacher (weak): https://www.gambiacollege.edu.gm/blog/scary-teacher-3d-chapter-2-new-pranks-and-challenges-1767647315
- Worms speech: https://worms.fandom.com/wiki/Speech
- Voices: https://en.wikipedia.org/wiki/Simlish · https://nookipedia.com/wiki/Animalese · https://en.wikipedia.org/wiki/Banjo-Kazooie_(video_game) · https://brycetown.substack.com/p/springbound-devlog-4-making-critters-talk
- Godot docs: https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html · https://docs.godotengine.org/en/stable/classes/class_skeletonmodificationstack2d.html · https://docs.godotengine.org/en/stable/classes/class_image.html · https://docs.godotengine.org/en/stable/classes/class_animationplayer.html · https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html
- Polygon2D pitfalls: https://forum.godotengine.org/t/polygon2d-skeleton-deformation-some-tips-tricks/46379
- Spine JSON (prior art): http://esotericsoftware.com/spine-json-format
- Booby code: `game/view/rig_pose.gd`, `game/view/gags/noodle.gd`, `game/view/juice_clock.gd`, `game/view/hi_res_tex.gd`, `tools/audio/sfx_voices.py`, `tools/audio/voice_lines.py`
