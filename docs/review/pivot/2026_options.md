# A complete pivot: what a one-owner, AI-agent team should build for mobile in 2026

Date: 2026-11-05. Owner's brief after the spikes: *"It's still the same animations and style, and it's
worse. We need a complete pivot. What are the best options to develop a great mobile game in 2026
using AI agents?"*

This document answers that question from research, not from this codebase. §1 is an honest account
of why three rounds of work did not move the needle. §2 is what the market and the case studies say.
§3 is what AI agents are actually good and bad at as a development team. §4 is the options. §5 is the
recommendation and how to decide in two weeks.

---

## 1. Why the last three rounds failed, honestly

Every round kept three things fixed: the cast, the side-view house, and hand-keyed cutout animation
as the medium of comedy. The depth review kept all three and added rules. The spikes kept the first
two and swapped the animation for procedural motion on the same parts. You said the result looked the
same and played worse, and you are right: the identity of the game is its art and its premise, and I
never put those on the table because the brief never did.

There is a deeper reason it kept failing, and it decides the pivot:

> **Hand-authored comedy animation is the single worst-fit medium for an AI-agent team.**

Agents cannot see motion well, cannot judge comic timing, and every gag is a one-off that has to be
reviewed by a human frame by frame. This project spent the bulk of its effort exactly there: 22,900
lines of art tooling, 148 clips, two abandoned 3D casts. Every retrospective of AI-built games says the
same thing — *"difficulty debugging visual/shader issues since Claude cannot see the screen"*
([retrospective](https://daily.dev/posts/gamedev-with-claude-code---a-retrospective-olah9ofly)) — and
the games that shipped are *"predominantly 2D, code-first projects"*
([survey](https://chierhu.medium.com/claude-code-for-game-development-7a88fcd19992)).

The premise compounds it. A neighbour-prank farce is a game where the *content is the joke*: 32 bespoke
reactions, each needing a timed animation. That is an animator's medium. We built an animator's game
with no animator.

So the pivot has two halves, and the second matters more than the first: **a different game, and a
different kind of game — one whose quality lives in systems the agents can build, test and tune, with
an art direction the agents can produce.**

---

## 2. What the market and the case studies say

### 2.1 Mobile in 2026

* Mobile is a mature market growing 1–3 %. Strategy (+20 % IAP) and puzzle (+14 %) grew in 2025;
  RPG fell 15 % ([Sensor Tower State of Gaming 2026](https://investgame.net/wp-content/uploads/2026/02/2026-02-26-sensor_tower__state_of_gaming_2026__en_wp.pdf),
  [Newzoo](https://gamedevreports.substack.com/p/newzoo-the-games-market-in-2025)).
* **Standalone paid downloads are tiny** (€19 M in Germany, €9 M in France for all of 2025). Premium
  on mobile now lives on **Apple Arcade and Netflix Games**, where premium releases jumped 77 % in 2025
  ([Prism](https://www.prismnews.com/hobbies/mobile-gaming/apple-and-netflix-drive-surge-in-premium-mobile-game-ports)).
* The analysts' own conclusion: *"the real indie breakouts of 2025 were on PC… Steam is friendlier to
  indies than mobile stores"* ([DEV](https://dev.to/linou518/2026-game-market-mobile-is-maturing-pc-indie-games-are-the-real-opportunity-4hkl)).
  Every small-team game below that did well on mobile was **PC-first, then ported**.

**Implication:** design for mobile *and* Steam from day one. Godot exports both from one project. A
premium mobile-only game from an unknown studio has almost no path to an audience in 2026.

### 2.2 The pattern behind every small-team success that reached phones

| Game | Team | Art | What the player does | Mobile |
|---|---|---|---|---|
| Balatro | 1 | flat cards, pixel | poker + 150 jokers, synergy discovery | 5 M sold; Best Mobile, TGA 2024; ADA 2025 |
| Slay the Spire (2) | ~10 | static card art | deckbuilder | StS2: $92 M in two weeks on Steam |
| Luck be a Landlord | 1, **Godot** | pixel icons | slot-machine synergies, **portrait** | ~819 K owners / $4.7 M |
| Dicey Dungeons | 1 | flat vector | dice + equipment synergies | ported |
| Peglin | 4 | simple pixel | pachinko roguelike | ~1 M / $14 M; "nearly perfect on iOS" |
| Backpack Hero | small | pixel | spatial inventory synergies | ported |
| Vampire Survivors | 1 | pixel | auto-shooter, build synergies | huge |
| Mini Metro | 2 | **geometry + palette** | transit optimisation | ADA winner; "minimising production art was a necessary restriction" |
| Thronefall | 2 | minimalist low-poly | tower defence + kingdom | 1 M in year one |
| Islanders / Dorfromantik | 2–4 | minimalist | placement puzzles | ported |
| Ball x Pit | small | simple | breakout + bullet heaven | **ADA 2026 finalist, Delight & Fun** |

([Balatro](https://www.switchbladegaming.com/strategy-games/deck-builder-renaissance-2026/),
[LBAL devlog](https://blog.trampolinetales.com/dans-devlog-april-2023/),
[Peglin](https://gamalytic.com/game/1970580),
[Mini Metro](https://en.wikipedia.org/wiki/Mini_Metro_(video_game)),
[Thronefall](https://newsletter.pragmaticengineer.com/p/thronefall),
[ADA 2026](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/))

Every one of them is **systems-dense, art-light, simple-input, synergy- or optimisation-driven, and
plays in short sessions.** The player's joy is *discovering* an interaction the designer set up but did
not script. None of them has a hand-animated character performing a joke. That is not a coincidence:
it is the only shape a two-person team can finish, and it happens to be the shape an agent team is
best at.

Two cautions from the same research:

* **Roguelike deckbuilders are reputationally saturated.** 212 shipped on Steam in 2025; 5.1 % reached
  1,000 reviews ([PokeIndie 2026](https://pokeindie.com/blog/game-genre-study-2026-which-genres-are-worth-building)).
  The *shape* (short runs, synergies, data-driven content) is still the right one; "another deckbuilder"
  as the pitch is not. The hook has to be a verb or a theme nobody has, as poker was for Balatro, a slot
  machine for LBAL, pachinko for Peglin, breakout for Ball x Pit.
* **Shipping fast is not the bottleneck any more; having a sharp idea is.** The cautionary case is the
  one-person Claude Code studio that shipped *seven* games in two months for ~$1 in revenue
  ([DEV](https://dev.to/rudycandy/i-run-a-one-person-game-studio-on-claude-code-two-months-7-games-about-1-in-ad-revenue-4j37)).
  The success stories all had a human with a clear design vision at the top
  ([Block Orbit retrospective](https://daily.dev/posts/gamedev-with-claude-code---a-retrospective-olah9ofly)).

### 2.3 Hybrid-casual, for completeness

The fastest-growing commercial segment (+23 % H1 2026), built on a snackable core plus a meta layer,
measured by D1 ≥ 35 % / D7 ≥ 20 % / D30 ≥ 8 % ([Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/)).
It needs ads + IAP, paid user acquisition, and a polish bar a publisher called *"borderline
unachievable for a small team"* ([Popcore via GameAnalytics](https://www.gameanalytics.com/blog/hybrid-casual-higher-retention-better-engagement)).
It conflicts with this project's no-monetisation rule and with being offline. Not recommended unless
you want to change the business, not just the game.

---

## 3. What AI agents are good and bad at as a studio

From the case studies, the academic work, and this repository's own history.

**Strong — build the game out of these:**

1. **Systems, rules and economies as code**, with tests. The single best documented agent win is a
   coin-pusher economy that produced 3.15 M coins in a 10-minute simulation and was tuned to a median of
   10,000 in three rounds ([one-person studio](https://dev.to/rudycandy/i-run-a-one-person-game-studio-on-claude-code-two-months-7-games-about-1-in-ad-revenue-4j37)).
   This repository's own sim, solver, fuzz and invariants are exactly this kind of work, and they are the
   best thing in it.
2. **Content as data at scale**: hundreds of items, cards, relics, synergies, levels — generated,
   validated against a schema, lint-checked, and balanced by simulation. Agents are tireless here and the
   output is checkable.
3. **Balance by simulation.** LLM-agent playtesters now track human difficulty curves (residual HP per
   boss in Slay the Spire correlates r = 0.87 with human win rates), and multi-agent self-play plus
   Bayesian optimisation balances rule systems automatically
   ([RuleSmith, Feb 2026](https://arxiv.org/abs/2602.06232),
   [LLM agents as game testers](https://www.emergentmind.com/topics/llm-agents-as-game-testers)).
   *"A game can be mathematically balanced and still feel boring"* — the human still decides fun, but
   the agents can remove the broken and the tedious before the human ever plays.
4. **Procedural and generative content** (maps, runs, encounters) — code, testable.
5. **Art that is code**: geometry, palettes, shaders, UI, particles. Mini Metro's look is a renderer.
6. **Static illustration via generative tools, curated by a human.** Card art, item icons, portraits,
   backdrops. Several shipped AI-built games did exactly this (Replicate for art, ElevenLabs for audio
   in [Void Balls](https://app.cinevva.com/news/2026-03-22-solo-devs-shipping-games-with-ai)).
   Strong for stills; the owner picks the winners.
7. **3D from asset libraries with library animations.** KayKit, Quaternius, Kenney (all CC0) and Synty
   share consistent styles, ship rigged characters with 100+ animations, and retarget cleanly
   ([asset guide](https://app.cinevva.com/guides/game-assets-guide)). This repo already proved it:
   the KayKit cast measured jitter 0.13–0.18 with library clips against 0.42 for our own rig. What
   failed in October was *re-dressing them as our 2D characters*, not the approach.
8. **The chores**: store screenshots, icons, localisation, save systems, CI, publishing.

**Weak — do not build the game out of these:**

1. **Hand-keyed animation and comic timing.** See §1.
2. **Bespoke character art that must read as one artist's hand.** Agents can generate stills; they
   cannot keep 400 SVG parts on-model across months without the human doing the real work.
3. **"Feel" without a measurement.** Agents optimise what they can measure. Anything that cannot be
   measured must be judged by the owner on a device, weekly, or it drifts — the whole story of this repo.
4. **Visual debugging.** Agents cannot see the screen; captures and metrics are the workaround.

**The rule that falls out:** *the game's quality must live in things the agents can test, and its look
must come from a pipeline that produces finished-looking results without a human artist in the loop.*

---

## 4. The options

Each is a shape, not a design. The design — the verb nobody else has — is the next week's work.

### Option 1 — Systems roguelike: short runs, a big pool of interacting pieces, synergy discovery

The Balatro / LBAL / Peglin / Backpack Hero shape. Portrait. 10–20 minute runs. 150–300 data-defined
pieces whose rules interact. Meta-unlocks across runs. Premium, Steam + mobile.

* **Agent fit: the best of any option.** Content is data; synergies are rules; balance is simulation
  (this repo's solver culture carries over directly); LLM playtesters measure difficulty; the content
  lint already exists in spirit.
* **Art:** static illustrated cards/items (generative, owner-curated) or iconic flat. No character
  animation at all, or a single procedural "reaction strip". The joy is in the combo text and the
  number going up, as in Balatro's jokers.
* **Risk:** the saturation above. It lives or dies on one distinctive verb or theme.
* **Two flavours to prototype:**
  * **1a — Theme preserved, "Mischief" as a run.** Each Night you draw pranks and rig them onto the
    neighbour's visible routine; chains and residues multiply; his temper is the scoring engine. It keeps
    the story you wrote, the theatre framing and the prank catalogue *as data*, and throws away everything
    you disliked — the stealth loop, the hand animation, the side-view house. The "chain 10 tricks"
    fantasy becomes the core verb, player-invented.
  * **1b — Clean slate.** A new theme chosen for a verb nobody has used (a mechanic from a real-world
    object or ritual the way poker, pachinko and slot machines were).

### Option 2 — Minimalist systems strategy: place things, watch the system respond, optimise

The Mini Metro / Thronefall / Islanders / Dorfromantik shape. Readable geometry and a palette; the art
is a renderer. Premium, Steam + mobile, landscape or portrait.

* **Agent fit: excellent.** Pure systems plus procedural generation; the look is code; difficulty
  curves are measurable.
* **Risk:** these games are *one idea done perfectly*. Without the idea there is nothing. Harder to find
  than Option 1's hook because the mechanic *is* the whole game.

### Option 3 — Toy sandbox in stylised low-poly 3D, library cast, library animation

The Goose lineage, done the way an agent team can: CC0/Synty characters, library clips, physics,
no hand animation. This is what you originally wanted from the spikes, with the art problem solved by
not making the art.

* **Agent fit: medium.** Physics and systems are code; the cast is bought; but *feel* is the whole game
  and it is the least measurable thing on this list. Human: Fall Flat is *"better to watch than play"*;
  Octodad's reviews turned when the controls stopped being funny
  ([post-mortem](https://www.gamedeveloper.com/design/octodad-dadliest-catch-post-mortem-pt-3-design)).
* **Risk:** you rejected two physics spikes this week, partly on art. If the art was the whole
  objection this is back in play; if the play itself bored you, it is not.
* **Engine note:** this is the one option where Unity's asset store and mobile SDK maturity argue
  against Godot; Godot 4.7 with Jolt is adequate.

### Option 4 — Hybrid-casual with a meta (F2P)

See §2.3. Commercially the biggest, operationally the wrong fit for an offline, premium, one-owner
studio with no UA budget. Listed so the decision is explicit.

### Option 5 — Narrative / puzzle (Blue Prince, inkle's TR-49)

Agents write well and reason about puzzle logic well; those titles won on visual craft and authored
surprise that agents are weak at. Viable only if text-forward. Lower fit.

### Engine

**Stay on Godot** for options 1, 2 and 5. Code-first, GDScript and C# both well covered, free, exports
Steam + iOS + Android from one project, and Luck be a Landlord is the existence proof for a solo Godot
roguelike on phones. The review toolchain, CI, deterministic-sim pattern and audio generator in this
repo all carry over. Move to Unity only for option 3 or 4, where its asset store and mobile SDKs matter
([comparison](https://oceanviewgames.co.uk/blog/posts/unity-vs-godot-vs-unreal-mobile-games)).

### What survives from this repository

Keep: the review loop (`sandbox / shot / capture / stability`, e2e), the CI, the deterministic sim +
solver + fuzz *pattern* (not the prank sim itself), the content-as-validated-JSON discipline, the
procedural audio toolchain, the touch-UX research, the story (if 1a). Retire: the rig, the clip
pipeline, the art tooling, the house, the 2D cast. That is most of the code and nearly all of the art,
and it should be said plainly: the parts worth keeping are the parts the agents built well, and the
parts to retire are the parts an agent team should never have been asked to build.

---

## 5. Recommendation

**Build a systems roguelike (Option 1), designed for Steam and phones together, with an art
direction that needs no animator: static generative illustration curated by you, or flat iconic
art. Prototype 1a and 1b in parallel for one week each, on paper first, then as a playable portrait
build, and pick on your phone.**

Why this and not the others: it is the only shape on the list that is simultaneously (i) what every
comparable small team actually finished and sold, (ii) the best fit for what agents do well, (iii)
compatible with premium, offline, no-monetisation, and (iv) measurable end to end — content lint,
synergy coverage, simulated win rates, run length, decision density — so the process failure of this
project (green gates, boring game) cannot recur unnoticed.

Why 1a is worth a week before a clean slate: it salvages the story, the catalogue of 32 pranks as
*data*, the theatre framing and the research, while deleting everything you objected to. If it still
feels like the old game, that is the answer and 1b takes over with nothing lost.

### The two-week plan

| Days | Work | Output |
|---|---|---|
| 1–2 | **Verb hunt.** 20 one-paragraph pitches for 1b; the 1a rule sheet. You pick 2–3 of each. | a page you can read in 10 minutes |
| 2–4 | **Paper prototypes** of the top 1a and 1b: rules, 30–40 pieces each, played by agents in simulation for run length, win rate and degenerate combos *before* you touch them. | a sim report per candidate |
| 4–9 | **Playable portrait builds**, Godot, placeholder flat art, one run each, Steam-style keyboard + touch. | APK / Mac build per candidate |
| 9–10 | **Art-direction test**: 20 generated card illustrations in two styles for each; you pick a style or none. | a contact sheet |
| 11–14 | **You play both on your phone, twice**, and answer the gate below. | the decision |

### The gate (answer in PROGRESS)

1. **Did you discover a combination that delighted you**, unprompted, in the first run?
2. **Did you start a second run without being asked?**
3. **Can you describe it in one sentence that does not contain the word "roguelike"?**
4. **Does the placeholder look already feel like a *style*, or does it feel like placeholder?**
5. **Would you rather spend the next three months on this than on anything built so far?**

### How to run the agents from here

Everything the depth review said about process still holds and matters more now:

* **Brief by measurable goal**, never by spec. *"A run should last 12–18 minutes and the top synergy
  should win no more than 30 % of simulated runs"* is a brief an agent can satisfy and you can check.
* **Simulate before you play.** Every balance change ships with a simulated win-rate table. Build the
  LLM-persona playtester early (it is a week's work on top of this repo's solver pattern).
* **You on the phone weekly**, and your reaction written down. Fun is the one metric only you own.
* **Art by curation, not authoring.** Agents generate twenty; you keep two. Never ask them to animate.
* **One repo, one game, no "stages".** A playable build every week from week one.

---

## Sources

Market: [Sensor Tower State of Gaming 2026](https://investgame.net/wp-content/uploads/2026/02/2026-02-26-sensor_tower__state_of_gaming_2026__en_wp.pdf) ·
[Newzoo 2025](https://gamedevreports.substack.com/p/newzoo-the-games-market-in-2025) ·
[DEV: mobile maturing, PC indie opportunity](https://dev.to/linou518/2026-game-market-mobile-is-maturing-pc-indie-games-are-the-real-opportunity-4hkl) ·
[Prism: premium ports on Arcade/Netflix](https://www.prismnews.com/hobbies/mobile-gaming/apple-and-netflix-drive-surge-in-premium-mobile-game-ports) ·
[Apple Design Awards 2026](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/) ·
[ADA 2026 finalists](https://appleinsider.com/articles/26/05/18/apple-design-awards-2026-finalists-include-cyberpunk-2077-civilization-vii) ·
[PokeIndie genre study 2026](https://pokeindie.com/blog/game-genre-study-2026-which-genres-are-worth-building) ·
[Hybrid-casual 2026](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/) ·
[GameAnalytics / Popcore](https://www.gameanalytics.com/blog/hybrid-casual-higher-retention-better-engagement).
Case studies: [Deck-builder renaissance](https://www.switchbladegaming.com/strategy-games/deck-builder-renaissance-2026/) ·
[Luck be a Landlord devlog](https://blog.trampolinetales.com/dans-devlog-april-2023/) ·
[Peglin stats](https://gamalytic.com/game/1970580) ·
[Mini Metro](https://en.wikipedia.org/wiki/Mini_Metro_(video_game)) ·
[Thronefall / Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/thronefall) ·
[Islanders](https://en.wikipedia.org/wiki/Islanders_(video_game)) ·
[Octodad post-mortem](https://www.gamedeveloper.com/design/octodad-dadliest-catch-post-mortem-pt-3-design).
AI-agent development: [Claude Code gamedev retrospective](https://daily.dev/posts/gamedev-with-claude-code---a-retrospective-olah9ofly) ·
[Survey of Claude Code game projects](https://chierhu.medium.com/claude-code-for-game-development-7a88fcd19992) ·
[One-person studio, 7 games](https://dev.to/rudycandy/i-run-a-one-person-game-studio-on-claude-code-two-months-7-games-about-1-in-ad-revenue-4j37) ·
[Solo devs shipping with AI](https://app.cinevva.com/news/2026-03-22-solo-devs-shipping-games-with-ai) ·
[RuleSmith (automated balancing)](https://arxiv.org/abs/2602.06232) ·
[LLM agents as game testers](https://www.emergentmind.com/topics/llm-agents-as-game-testers) ·
[TITAN](https://arxiv.org/pdf/2509.22170).
Assets and engines: [Free asset guide 2026](https://app.cinevva.com/guides/game-assets-guide) ·
[Kenney vs Quaternius](https://3dxdev.com/kenney-vs-quaternius-the-best-free-cc0-game-assets/) ·
[AI 3D asset tools 2026](https://www.3daistudio.com/blog/best-ai-game-asset-generators-2026) ·
[Godot vs Unity vs Unreal for mobile](https://oceanviewgames.co.uk/blog/posts/unity-vs-godot-vs-unreal-mobile-games).
