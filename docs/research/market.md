# Market research: modern prank and stealth-comedy games on mobile

For: *Mischief Next Door* (working title). Landscape, side-view house, solo offline prank episodes. Godot 4.7.2, 2D.
Date: 2026-09-28. Web sources are cited inline and listed at the end. Anything marked **[memory]** comes from my own knowledge and could not be checked online in this session, so treat it as likely but not verified.

---

## 0. The short version

1. **The genre already works on phones, in landscape.** Scary Teacher 3D, the biggest prank game on mobile, has about 290M Google Play installs and 4.28 stars from 1.8M ratings ([AppBrain](https://www.appbrain.com/app/scary-teacher-3d/com.zakg.scaryteacher.hellgame)). Its bad reviews are about monetization and controls, not the idea.
2. **The best comedy design is Untitled Goose Game's.** It has a to-do list of punchlines, NPC routines you can predict, a spammable verb that is funny on its own (the honk), a unique sound for every object, and music that reacts. The player is the comedian ([ACMI](https://www.acmi.net.au/stories-and-ideas/untitled-goose-player-comedians/)).
3. **Keep levels short.** Median mobile sessions are 5–6 minutes, and the top quartile reaches 8–9 ([GameAnalytics 2025](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)). Our target is **4–6 minutes to clear and 7–9 minutes for 100%**.
4. **Laugh within 30 seconds.** Guidance is core play within 60 seconds and the "aha" within 90 seconds ([Playio](https://blog.playio.co/mobile-game-onboarding-retention)).
5. **The same five complaints come up everywhere:**
   - ads and energy walls
   - floaty joysticks
   - vague objectives
   - paid hints that give away the whole answer
   - a full restart after one mistake

   Avoiding all five already sets us apart.
6. **Make getting caught a soft failure.** In Granny, being caught costs one of five "days" and your progress is kept. In Scary Teacher, "your rewards suffer no penalty for being spotted" ([Level Winner](https://www.levelwinner.com/scary-teacher-3d-walkthrough-guide-tips-tricks-strategies-to-prank-your-creepy-teacher/)).

---

## 1. Game-by-game teardown

### 1.1 Scary Teacher 3D (Z&K Games, developed by GenITeam)

**Scale.** About 290M Android installs, #1 in Simulation ([AppBrain](https://www.appbrain.com/app/scary-teacher-3d/com.zakg.scaryteacher.hellgame)), and 4.6 stars from 476K ratings on iOS ([App Store](https://apps.apple.com/us/app/scary-teacher-3d/id1250783151)).

**Structure.**
- There are 10 locations. One is free, three unlock with ads and six are paid.
- Miss T's house has **14 pranks played in a fixed order, one per level**, for example a mousetrap, sabotaged cereal, a spider in a book, jelly in the bath and a beehive in a parcel ([Level Winner](https://www.levelwinner.com/scary-teacher-3d-walkthrough-guide-tips-tricks-strategies-to-prank-your-creepy-teacher/)).
- A level is one prank of 2–5 steps: find the item, place it, flee.
- You can carry at most **4 items**. Keys and crowbars gate the house's 15 rooms.

**Payoff.** A finished prank cuts to a reaction cinematic in which Miss T overreacts. Being caught also plays a comic "told off" cutscene. Each reaction runs about 3–6 seconds [memory].

**Hints and currencies.**
- **Stars** buy hints, and an ad gives one free star per play-through.
- **Coins** buy tools and energy. **Energy** limits play and also acts as health.
- If you are caught, you can watch an ad to continue, and Miss T is teleported away.
- IAP prices: 10 stars $0.99, chapters 2–5 $0.99 each, unlimited hints $1.99, no ads $0.99, and subscriptions from $4.99–$9.99 ([App Store](https://apps.apple.com/us/app/scary-teacher-3d/id1250783151)).

**Complaints.**
- Frequent ads that are hard to close.
- Energy that drains fast, then waits of hours ([Google Play](https://play.google.com/store/apps/details?id=com.zakg.scaryteacher.hellgame&hl=en)).
- Paid chapters.
- A hint slider that will "NOT GO AWAY."
- From Common Sense Media ([review](https://www.commonsensemedia.org/app-reviews/scary-teacher-3d)): at a doorway "you may need to swipe to swivel the perspective," walking is "maddeningly slow," and "the instructions for pranks aren't very detailed."

**Controls.** Landscape, a joystick on the left, and an action button on the right that lights up near interactable objects. You can hide in closets and under beds ([weak source](https://www.seeles.ai/games/adventure/scary-teacher-3d), and it matches my memory).

**Lesson.** The loop works at huge scale: one prank objective, fetch and place, flee, reaction cinematic. What players hate is everything wrapped around it.

### 1.2 Neighbours back From Hell (HandyGames / THQ Nordic, 2020 PC, 2021 mobile)

This is the remaster the owner remembered. We study its design and reuse none of its IP.

**Mobile release.**
- It launched on mobile at $4.99 with 28 episodes over two seasons. Animations run at double the original frame rate, and controllers are supported ([TouchArcade](https://toucharcade.com/2021/08/03/neighbours-back-from-hell-iphone-android-out-now-price-controller-support-handy-games/), [App Store](https://apps.apple.com/us/app/neighbours-back-from-hell/id1537362903)).
- The older free-to-start port *Season 1* has 3.9 stars from about 2,000 ratings. After two missions it asks for $3.99, and reviewers are angry: "you download 1gb, and at last, you can play 2 missions" ([App Store](https://apps.apple.com/us/app/neighbours-from-hell-season-1/id1114028201)).

**The formula** ([Wikipedia](https://en.wikipedia.org/wiki/Neighbours_from_Hell), [Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2584421942)):
- Each episode has a required number of pranks. Extras earn bonus points, and pranks landed back to back earn a chain bonus.
- 100% rating means every trick in the episode. The tutorial episode needs about 8 actions to reach it.
- Being caught ends the episode and you restart.
- Pets make noise that draws the neighbour. You hide in wardrobes and under beds.

**Remaster complaints (a spec of what not to do):**
- "The prompt system [is] rather random, especially if there are more objects in the same area" ([Softpedia/Xbox Tavern via search](https://www.softpedia.com/reviews/games/playstation-4/neighbours-back-from-hell-review-531358.shtml)).
- "Going up and down stairs is an all or nothing affair."
- "No progress bar when [the hero] prepares a prank." Players also miss the original's **command chaining** ([Steam](https://steamcommunity.com/app/1283190/discussions/0/4070650515239562749/)).
- On mobile it is "easy to tap a different action than what you meant" ([TapTap](https://www.taptap.io/app/219602)).

**Lesson.** The formula still earns 95% positive Steam reviews. Its weak points are input precision and feedback, which a touch-first rebuild can fix.

### 1.3 Hello Neighbor mobile (tinyBuild) and the Dark Riddle clones

- It is a 3D first-person game about breaking into a neighbour's house. Mobile reviews single out the controls: the floating joystick "sets itself based on where you press, which is incredibly frustrating in a stealth horror game," and "on-screen buttons get in the way of character movement" ([search summary incl. AppUnwrapper / MiniReview](https://www.appunwrapper.com/2018/07/29/hello-neighbor-ios-gameplay-video-and-impressions/)).
- Reviewers recommend it only if you "aren't afraid of the lackluster controls and **zero guidance**."
- Puzzles are "convoluted and confusing," and players say you need a guide. Acts 2–3 sit behind a paywall. Crashes are common ([Google Play summary](https://play.google.com/store/apps/details/Hello_Neighbor?id=com.tinybuildgames.helloneighbor&hl=en_NZ)).
- Dark Riddle (PAGA Group) copies the format with heavy IAP and ads, and its reviews complain about the same things ([JustUseApp](https://justuseapp.com/en/app/1385421494/dark-riddle/reviews)).

**Lesson.** Opaque puzzles plus bad movement equals rage. On mobile, a stealth game lives or dies on how precise its input is.

### 1.4 Prank Master 3D (Alpha Potato) and "troll" puzzles

**Prank Master 3D.** Hypercasual and portrait [memory]. You tap one of 2–3 objects and a short 3D gag plays ([Uptodown](https://prank-master-3d.en.uptodown.com/android)). Reviewers complain:
- "75% ads and about 25% actual gameplay," with ads "after every level."
- The same water-balloon prank turns up "in level 2 and then again in level 40."
- "If you get one wrong, you have to start from the beginning" ([App Store via search](https://apps.apple.com/us/app/prank-master-3d/id1528127833)).

**Troll Face Quest (Spil Games).** 30+ levels, each "can usually be solved in less than a minute" ([Uptodown](https://troll-face-quest-classic.en.uptodown.com/android)). The logic is deliberately absurd, and every wrong tap gets its own joke.

**Lesson.**
- Keep the laugh rate (a gag every 20–40 seconds) and wrong attempts that are funny.
- Drop the recycled gags, the per-level ads and the moon logic, which is fine over one minute but maddening over five.

### 1.5 Untitled Goose Game (House House, 2019): the benchmark

**Recognition and length.**
- It won Game of the Year at both D.I.C.E. and the GDC Awards, and sold over 1M copies by the end of 2019 ([Wikipedia](https://en.wikipedia.org/wiki/Untitled_Goose_Game)).
- It takes 2–3 hours ([Gamepur](https://www.gamepur.com/guides/how-long-to-beat-untitled-goose-game)). Kotaku took 2.5 hours plus 1 hour of bonus content ([Kotaku](https://kotaku.com/untitled-goose-game-the-kotaku-review-1838264644)). It "gets in and out before its joke stops being funny" ([GameCritics](https://gamecritics.com/mike-suskie/untitled-goose-game-review/)).

**The to-do list.**
- Each area has 5–7 lines. The garden's are "Get into the garden, Get the groundskeeper wet, Steal his keys, Make him wear his sun hat, Rake in the lake, Have a picnic" [memory].
- After **five tasks**, a **starred finale** appears ("*Make the groundskeeper hammer his thumb"), and finishing it unlocks the next area ([Gamepur](https://www.gamepur.com/guides/how-long-to-beat-untitled-goose-game)).
- After the credits you get an extra-gags list ("To Do (As Well)" [memory]) and a "To Do (Quickly!!)" speed list with about 6–7 minutes per area.
- Designers wrote list items after spotting funny things players could already do: "just think of interesting things you could already do in the game and just write them down" ([Q&A](https://www.gamedeveloper.com/design/behind-the-honk-an-i-untitled-goose-game-i-q-a)).

**Why it is funny.**
- **Goals are punchlines, not instructions.** "Make someone hammer his own hand; make someone buy back their own stuff" ([analysis](https://www.gamedeveloper.com/design/an-untitled-i-untitled-goose-game-i-analysis)). The game sets up the joke and the player delivers it ([ACMI](https://www.acmi.net.au/stories-and-ideas/untitled-goose-player-comedians/)).
- **Stealth makes it funnier.** "It was funnier when the goose tried to steal things when people weren't looking." NPCs have "very limited vision" and "discrete AI states" ([Road to the IGF](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i-)).
- **Routines are predictable.** "You know what's going to happen next – and that's part of the fun."
- **The world reacts densely.**
  - About 160 objects each have their own pickup, drop, clang and drag sounds on every surface.
  - NPCs tidy up what you moved.
  - The team kept "filling in edge cases where something felt like it 'should' work" ([Q&A](https://www.gamedeveloper.com/design/behind-the-honk-an-i-untitled-goose-game-i-q-a)).
- **The music reacts.** A Debussy prelude was cut into about 357 stems, in high- and low-energy takes. It is silent while you are unseen, quiet when you are noticed and loud in a chase, "like… a silent film pianist" ([Gameplay.co](https://gameplay.co/untitled-goose-game-music-sound-design/)).
- **The honk has no spam limit.** It is a toy, a lure and a joke at once.
- **The setting is grounded.** Big ideas were cut to keep "a very normal day."

**Criticisms.** It is short, the camera swings, some objectives "didn't make intuitive sense," detection is sometimes inconsistent, and there is little reason to replay ([Metacritic](https://www.metacritic.com/game/untitled-goose-game/user-reviews/)).

### 1.6 Hitman GO (2014) and Lara Croft GO (2015), Square Enix Montreal

**Hitman GO.**
- It launched with 68 levels and grew to 90+ over 7 chapters ([Wikipedia](https://en.wikipedia.org/wiki/Hitman_Go)).
- Each level has **three objectives**, for example "reach the exit unseen," "finish in ≤10 turns killing nobody" or "take the briefcase" ([TouchArcade](https://toucharcade.com/2014/04/17/hitman-go-review/)). Stars unlock the next board.
- There is **no undo**: one mistake means "you'll need to restart the whole mission."
- Hints: 5 free, then $1.99 for 5 or $14.99 for a walkthrough. They reveal the full solution, and Game Informer called the scheme "shameful" ([search summary](https://gameinformer.com/games/hitman_go/b/ios/archive/2016/02/23/hitman-go-review-game-informer.aspx)).

**Lara Croft GO.**
- 40 levels in 5 chapters. It won Apple's iPhone Game of the Year 2015 ([Wikipedia](https://en.wikipedia.org/wiki/Lara_Croft_Go)).
- It was built for "shorter but more frequent sessions… a progression that can easily be left off and resumed later" ([PocketGamer.biz](https://www.pocketgamer.biz/the-making-of-lara-croft-go/)).
- The team **rejected virtual joysticks** as "too complex" for casual players, and used swipes plus flashing tap arrows instead.

**Lesson.**
- Readable, deterministic patterns, objectives shown up front, and stars that gate chapters all work.
- Discrete input (tap or swipe) beats analogue sticks.
- Paid hints give reviewers an easy target.

### 1.7 Granny (DVloper, 2017)

- It is one developer's first-person escape-horror game. A blog reports 540M+ Google Play installs, which I did not verify ([Aprasi](https://www.aprasi.com/blogs/trending-topics/why-granny-by-dvloper-became-a-mobile-horror-hit)). It went viral with YouTubers in 2018.
- **Fail model.** You have 5 "days." Being caught or hitting a trap costs one day and you wake up back in bed, with the world state kept ([Granny Wiki via search](https://granny.fandom.com/wiki/Granny_(game))).
- **Noise lure.** Dropping an item or stepping on a creaky floor brings Granny running to the spot, and players use this deliberately, for example by dropping a vase to pull her downstairs.
- **Difficulty.** Easy, Normal, Hard and Extreme settings, plus a **Practice mode with no Granny** ([TV Tropes/Fandom via search](https://granny.fandom.com/wiki/Difficulties)).
- **Lesson.**
  - A few lives framed as fiction (days) turns failure into progress: you learn her route and keep your work.
  - Noise as a player tool is great for stealth.
  - A "no enemy" practice mode is cheap to add and valued by nervous players.

### 1.8 Two closer cousins: Tiny Thief and Robbery Bob

Both are landscape stealth-comedy games on mobile, one side-view and one top-down.

**Tiny Thief (5Ants/Rovio, 2013).**
- 6 chapters × 5 levels ([Wikipedia](https://en.wikipedia.org/wiki/Tiny_Thief)).
- **3 stars:** the main item, 1–4 hidden items (shown as "?" silhouettes), and a pet ferret you tap when it peeks out.
- "Touch an area to move there, touch an object to interact." A dedicated button gets you out of a barrel, so you "never blame the… touch-screen controls."
- Hints are "visual clues… step by step" ([Destructoid](https://www.destructoid.com/reviews/review-tiny-thief/)).
- Complaint: some actions lock you out and force a restart ([JayIsGames](https://jayisgames.com/review/tiny-thief.php)).

**Robbery Bob (Level Eight).**
- 50 levels. Stars for going undetected, for time and for all the loot. Enemies include "little old ladies with rolling pins."
- Complaints: it's "really hard to see what's going on in the whole house," there's no zoom during play, and the D-pad is cumbersome ([148Apps](https://www.148apps.com/reviews/robbery-bob-review/)).

---

## 2. Findings across all the games

### 2.1 Session and level length

| Game | Typical level / episode | Whole game |
|---|---|---|
| Troll Face Quest | < 1 min | 30–48 levels |
| Prank Master 3D | 15–40 s [memory] | "tons," recycled |
| Hitman GO / Lara Croft GO | 1–5 min [memory] | 68–90 levels / 40 levels |
| Tiny Thief | "a few minutes" to ~8 min | 30 levels |
| Scary Teacher 3D | one prank, ~2–5 min [memory] | 14 pranks per house, 10 locations |
| NfH-style episodes | 5–12 min for 100% [memory] | 14–28 episodes |
| Untitled Goose Game area | ~20–40 min (5–6 tasks + finale) | 2–3 h, speed lists 6–7 min |
| Market benchmark | median session 5–6 min, top quartile 8–9 min, ~4 sessions a day, 22 min a day ([GameAnalytics](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)) | Puzzle retention: D1 31.9%, D7 12.2%, D30 5.4% ([Segwise](https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies)) |

**Takeaway.** A 4–6 minute clear fits inside one median session, and a 100% run fits the top-quartile 8–9 minutes. Goose-length areas of 20–40 minutes are too long for a phone session.

### 2.2 First-time user experience and time to first laugh

- **Benchmarks:** core play within 60 seconds, the "aha" within 90 seconds, and a first-run tour of no more than 2 steps ([Playio](https://blog.playio.co/mobile-game-onboarding-retention)).
- **Goose Game** puts you in control within seconds. The honk works right away and gets a laugh before you have done any task, and the first task ("Get into the garden") is also the tutorial [memory].
- **Scary Teacher** opens with a short story cutscene. Its first prank (the mousetrap) pays off in about 1.5–2.5 minutes [memory, estimate].
- **Prank Master and Troll Face Quest** give a laugh within about 15 seconds, but the laughs stay shallow.

**Target for us:** a laugh with no goal attached in 5–10 seconds (the free comedic verb), the first set-up prank landing within 30 seconds, and a first chain before 90 seconds.

### 2.3 Objective checklist UI patterns

- **Goose:** a corner notepad with 5–7 handwritten punchlines, each scribbled out with a sound. The starred finale appears afterwards.
- **Scary Teacher:** one objective at a time with a step list and a hint arrow. It is clear, but railroaded.
- **Hitman GO:** three objective lines shown before the level and ticked on the results screen.
- **Tiny Thief:** "?" silhouettes that show how many things are left to find.
- **Ours:** a slide-out clipboard with 3–6 punchline lines, silhouettes for pranks not yet found, and a stamped tick when a prank lands. The finale line appears once the required pranks are done.

### 2.4 Star and rating systems

| Game | System | What we learn |
|---|---|---|
| NfH | Audience rating % + chain bonus; 100% = every trick | A % score is readable and motivating, and chains reward timing |
| Hitman GO | 3 stars = 3 distinct objectives, and stars gate chapters | Separate objectives create replays, but conflicting ones feel forced |
| Tiny Thief | Main goal / hidden items / hidden pet | A collectible that sits apart from the main goal adds exploration |
| Robbery Bob | Undetected / time / all loot | Time stars suit speedrunners and punish people who experiment |
| Scary Teacher | Stars are hint currency | Mixing reward and hint currency confuses players and leads to monetization abuse |

### 2.5 Hints

- **Good examples:** Tiny Thief's step-by-step visual clues, and Goose, which has no hints but relies on grounded tasks and NPC tells.
- **Bad examples:**
  - Hitman GO sells hints ($1.99 for 5) that dump the whole solution.
  - Scary Teacher's hints cost stars or ads, and its hint UI covers the screen.
  - Hello Neighbor has none, so players need a guide.
- **Model:** a free, unlimited ladder of three steps in which each step reveals only a little more.

### 2.6 Failure and retry

| Model | Example | Felt as |
|---|---|---|
| Caught means the episode fails and you restart | NfH original, Prank Master | Fair on PC in 2003, punishing now: losing 5+ minutes of setup for one mistake |
| Restart the mission, no undo | Hitman GO | Fine for 1–3 minute puzzles |
| Watch an ad to continue, enemy teleported | Scary Teacher | Works mechanically but feels predatory |
| Lose a "day," keep the world | Granny | Tense and fair, progress is kept, and you learn the route |
| Chased away, retry quickly | Goose | Almost no penalty, keeps experimenting cheap |

### 2.7 Unlock pacing

- Scary Teacher's model (1 location free, 3 behind ads, 6 behind purchases) is disliked.
- Hitman GO gates boards by stars, so you need some optional objectives but not all.
- Goose uses a hard gate (the starred finale), which is simple and satisfying.
- Tiny Thief and Robbery Bob unlock level by level.
- **Our pace:** show something new in every episode (a gadget, a behaviour, a room or an NPC). Players need about 60% of a season's stars to open the next one, so they never need 100%.

### 2.8 "One more level" hooks that are not predatory

1. **Short episodes.** Five minutes is easy to "just try."
2. **"Next" is the default button on the results screen**, with the next episode's gadget shown as a silhouette.
3. **A near-miss prompt**, for example "4/5 pranks. The fridge gag is still out there…"
4. **A gag reel.** The results screen replays the 3 best reaction cams, which rewards you and tempts you to chase a better chain.
5. **A new toy every 2 episodes**, and each one makes old episodes worth replaying.
6. **Remix lists** after you clear an episode ("Quickly!!", "Deluxe").
7. **A reaction scrapbook**, for example "37/60 reactions seen," with silhouettes for the rest.

None of these needs energy, timers, ads or streak pressure.

### 2.9 Top app-store and review complaints

| # | Complaint | Where |
|---|---|---|
| 1 | Too many ads, ads after every level, ads to continue | Scary Teacher, Prank Master, Dark Riddle, Hello Neighbor |
| 2 | Energy or stamina walls, waiting hours | Scary Teacher |
| 3 | Paywall after a couple of levels or chapters | NfH Season 1 mobile, Hello Neighbor, Scary Teacher |
| 4 | Imprecise movement: floating stick, swipe-camera to enter doors, slow walk | Hello Neighbor, Scary Teacher, Robbery Bob |
| 5 | Wrong-object taps and ambiguous prompts when objects overlap | NbFH, TapTap mobile reviews |
| 6 | No feedback on action duration, no queued actions | NbFH |
| 7 | "Zero guidance," puzzles that need a guide | Hello Neighbor, Scary Teacher |
| 8 | Hints that cost money or give away everything | Hitman GO |
| 9 | Restart from the beginning after one mistake, soft-locks | Prank Master, Tiny Thief, Hitman GO |
| 10 | Repeated or recycled gags | Prank Master |
| 11 | Can't see the whole house or the enemy | Robbery Bob, and all first-person games |
| 12 | Crashes, freezes, big downloads | Hello Neighbor, Scary Teacher, NfH Season 1 (1 GB) |
| 13 | Too short | Goose, Lara Croft GO, Tiny Thief ("I wish there was more of it") |

### 2.10 Landscape or portrait

- The stealth-prank hits are all **landscape**: Scary Teacher is confirmed, and Hello Neighbor, Granny, Dark Riddle, NbFH, Tiny Thief and Robbery Bob are from memory.
- **Portrait** is for hypercasual one-tap prank games such as Prank Master 3D [memory]. Landscape suits "games where horizontal extent matters — side-scrollers" ([overview](https://umjynb-lab.github.io/gameorientation/)).
- A side-view house of 2 floors with 3–4 rooms each is about 2:1, which fits a 20:9 phone (about 2.2:1). Portrait shows only about 1.5 rooms across, so the owner is right.
- **Controls.** In landscape, thumbs rest in the lower corners and the upper middle is hard to reach. That means **tap-to-move and tap-to-act anywhere**, with no stick. Put the persistent HUD (pop out, gadget, hint) in the lower corners.

---

## 3. What we should steal (mechanics, not IP)

1. **A to-do list of punchlines** (Goose). Write "Make him sneeze into his soup," not "place pepper in bowl." The list never says *how*.
2. **A starred finale gag** (Goose). It appears once the required pranks are done and is a bigger chain across several rooms.
3. **A spammable comedic verb** (the honk). One button with no cooldown that is funny on its own and also works as a lure. It must be our own sound, for example a raspberry, a party horn or a squeaky toy.
4. **Predictable NPC routines** (Goose, Hitman GO). A 60–90 second loop (kitchen → TV → bathroom → garden), with a "next stop" thought bubble.
5. **A reaction cam for every prank** (Scary Teacher). The camera punches in, time slows briefly, and the neighbour overreacts for 2.5–4 seconds while the hero snickers. Reactions you have already seen can be skipped.
6. **A chain multiplier** (NfH). A prank that lands while he is still reeling scores ×1.5, then ×2, then ×3. This is the skill ceiling and the reason for "one more try."
7. **A % rating turned into 3 stars, with stars gating seasons** (NfH, Hitman GO, Tiny Thief). The % shows how you did, and the stars are progress.
8. **A hidden critter** (Tiny Thief's ferret). You tap it when it peeks out, and it is tracked apart from the stars.
9. **Silhouette slots for undiscovered pranks** (Tiny Thief's "?"). They show how many are left without saying where.
10. **Tap-to-move and tap-to-act, with contextual icons above objects** (Tiny Thief, Lara Croft GO). The input is discrete and deterministic, so a miss is always the player's plan and never the controls.
11. **A dedicated "pop out" button when hiding** (Tiny Thief), so there are no accidental exits.
12. **A progress ring and a command queue** (what NbFH players asked for). Setup actions show a 0.8–2.5 second ring, and a tap during it queues the next action.
13. **Soft failure framed as fiction** (Granny's days). Being caught keeps the world state, so you lose time, not progress.
14. **Noise as a tool** (Granny, the honk). Dropped items, creaky stairs and the comedic verb pull the neighbour to a spot.
15. **A unique sound per object and surface** (Goose's 160 objects). This is the cheapest big comedy win.
16. **Adaptive music** (Goose). Near-silence while sneaking, a vamp when he is suspicious, a frantic cue in a chase, and a stinger when a prank lands.
17. **A grounded "normal day" setting** (Goose). Everyday objects and escalating pettiness, with no gore. It is funnier and suitable for all ages.
18. **The neighbour tidies up** (Goose). He puts moved objects back, which makes the house feel alive and adds timing pressure.
19. **Post-clear remix lists** (Goose's "Quickly!!"). A timed list and a "Deluxe chain" list for each episode roughly double playtime at almost no content cost.
20. **A Rehearsal mode with no neighbour** (Granny's Practice mode), for learning a house or just messing about.

---

## 4. What to avoid

1. **Energy or stamina of any kind.** It is Scary Teacher's biggest complaint.
2. **Ads between levels or ads to continue.** Being offline and ad-free is a selling point.
3. **Paywalls after 1–2 episodes.** NfH Season 1's "2 missions then pay" drew angry reviews.
4. **Virtual joysticks**, especially floating ones (Hello Neighbor, Robbery Bob).
5. **Camera swiping to get through doors** (Scary Teacher). Doors and stairs should be tap targets.
6. **Overlapping, ambiguous prompts** (NbFH). Every action icon needs a hit area of at least 48 dp that doesn't overlap another.
7. **Moves you can't cancel**, such as NbFH's all-or-nothing stairs. Tapping elsewhere should cancel mid-way.
8. **Actions with no progress feedback** (NbFH).
9. **Paid hints, or hints that dump the whole solution** (Hitman GO).
10. **Hint UI that covers the play area or won't dismiss** (Scary Teacher).
11. **A full episode restart after one mistake** (Prank Master, classic NfH).
12. **Soft-locks** (Tiny Thief). Consumed items respawn, so a prank can never become impossible.
13. **Moon logic** (Troll Face Quest, Hello Neighbor). Every prank should be guessable from the objects: pepper next to soup is an invitation.
14. **Recycled gags** (Prank Master's water balloon in levels 2 and 40). Recombine gadgets and never repeat a reaction.
15. **More than one currency, or stars used to buy hints** (Scary Teacher). Stars mean progress and nothing else.
16. **Time-limit stars by default** (Robbery Bob). They punish the experimenting that produces the comedy, so keep timers in the opt-in remix.
17. **Hiding the enemy** (first-person games, Robbery Bob). The neighbour should always be visible, or marked with an edge arrow when he is off-screen.
18. **Horror tone and jump-scares** (Granny, Hello Neighbor). Tension should come from risk, and the payoff should always be a laugh.
19. **Long intros or account and consent walls before play.**
20. **Punishing curiosity.** Wrong combinations should get a small gag, never a fail.
21. **Episodes that drag.** If a first clear routinely goes past about 8 minutes, split the episode.
22. **Anything taken from NfH's IP.** No character names, no "viewers" TV-show framing, and none of its well-known gags or layouts.

---

## 5. Recommendations for *Mischief Next Door*

### 5.1 Episode length
- **Cold-open tutorial (Episode 0): 60–90 seconds, 2 pranks and 1 chain.**
  - Seconds 0–10: the player gets control. Pressing the comedic-verb button makes the dozing neighbour snort awake and fall back asleep, which is the first laugh.
  - Seconds 10–30: the first prank, for example swapping sugar for salt, lands with a reaction cam.
  - By 90 seconds: a second prank lands while he is still sputtering, the game shows "CHAIN ×2!", and the results screen plays the gag reel.
  - No menus before this. The title card appears after the episode.
- **Standard episode:** **4–6 minutes to clear** (target median 5), **7–9 minutes for 100%**. Hard cap on the first clear in playtests: 8 minutes.

### 5.2 Prank count per episode
| Season | Required to clear | Total pranks | Starred finale | Steps per prank |
|---|---|---|---|---|
| 1 (house A, 6 eps) | 2–3 | 4–5 | 1 (2-room chain) | 1–2 |
| 2–3 | 3 | 5–6 | 1 (3-room chain) | 2–3 |
| 4–5 | 3–4 | 6–8 | 1 (whole-house chain) | 2–4 |

- The clipboard never shows more than 7 lines, including the finale.
- At least **one prank should land every 45–60 seconds** of a skilled run.

### 5.3 Rating
- Every prank adds points to a **Mischief %**. The chain window is 6–8 seconds after a reaction ends, with multipliers of ×1.5, ×2 and ×3.
- **Stars:**
  - ★ all required pranks
  - ★★ every prank
  - ★★★ every prank plus the finale, or a ×3 chain
- The hidden critter is a separate badge and doesn't count toward stars.
- Season gates open at about 60% of the stars available so far.

### 5.4 Fail and retry model (soft failure, 3 strikes)
- **Being caught:** a 2–3 second slapstick "caught" gag, for example being bundled out of the front door by the collar. You reappear at the house entrance **within 4 seconds of being grabbed**.
- **Kept:** every prank already set up, and the pranks already done.
- **Lost:** the item you were carrying, which returns to where it came from.
- **Aftermath:** the neighbour is *wary* for 20 seconds (walks 20% faster and checks one hiding spot).
- **Three strikes per episode.** On the third, the episode ends and the results screen scores what you managed. **Retry reloads in under 2 seconds**, and nothing is ever taken away.
- **Episodes 0–3 and Rehearsal mode:** unlimited strikes. A **Relaxed** toggle in settings gives unlimited strikes everywhere, with a small badge on the stars and no score penalty.
- **Hints:** a free, unlimited 3-step ladder.
  1. After 40 seconds without progress, the next useful object sparkles.
  2. Tapping the hint button shows a thought bubble of "item → target."
  3. Tapping again plays a ghost demonstration.
  Step 3 marks that prank with a small bulb icon and has no other penalty.
- **Never:** energy, ads, paid continues or paid hints.

### 5.5 How long it lasts
- 5 seasons × 6 episodes × about 5 minutes ≈ **2.5 hours to clear once**.
- Going for 100% adds about 1.5–2 hours. "Quickly!!" and "Deluxe" remix lists add about 1.5 hours. The reaction scrapbook, the hidden critters and a free-play sandbox after the credits (all gadgets unlocked, Rehearsal rules) make it open-ended.
- That comes to **roughly 6 hours of core content** without padding, in 5–9 minute bites that match 3–4 phone sessions a day.

---

## Sources
- AppBrain, Scary Teacher 3D stats: https://www.appbrain.com/app/scary-teacher-3d/com.zakg.scaryteacher.hellgame
- App Store, Scary Teacher 3D: https://apps.apple.com/us/app/scary-teacher-3d/id1250783151
- Google Play, Scary Teacher 3D: https://play.google.com/store/apps/details?id=com.zakg.scaryteacher.hellgame&hl=en
- Level Winner, Scary Teacher 3D guide: https://www.levelwinner.com/scary-teacher-3d-walkthrough-guide-tips-tricks-strategies-to-prank-your-creepy-teacher/
- Common Sense Media, Scary Teacher 3D: https://www.commonsensemedia.org/app-reviews/scary-teacher-3d
- SEELE AI description (weak source): https://www.seeles.ai/games/adventure/scary-teacher-3d
- Wikipedia, Neighbours from Hell: https://en.wikipedia.org/wiki/Neighbours_from_Hell
- Steam guide, 100% viewers' rating: https://steamcommunity.com/sharedfiles/filedetails/?id=2584421942
- Steam discussion, NbFH controls: https://steamcommunity.com/app/1283190/discussions/0/4070650515239562749/
- Softpedia NbFH review (via search summary): https://www.softpedia.com/reviews/games/playstation-4/neighbours-back-from-hell-review-531358.shtml
- 3rd-strike NbFH review: https://3rd-strike.com/neighbours-back-from-hell-review/
- TouchArcade, NbFH mobile launch: https://toucharcade.com/2021/08/03/neighbours-back-from-hell-iphone-android-out-now-price-controller-support-handy-games/
- App Store, NbFH: https://apps.apple.com/us/app/neighbours-back-from-hell/id1537362903
- App Store, NfH Season 1: https://apps.apple.com/us/app/neighbours-from-hell-season-1/id1114028201
- TapTap, NbFH: https://www.taptap.io/app/219602
- AppUnwrapper, Hello Neighbor iOS (via search summary): https://www.appunwrapper.com/2018/07/29/hello-neighbor-ios-gameplay-video-and-impressions/
- Google Play, Hello Neighbor: https://play.google.com/store/apps/details/Hello_Neighbor?id=com.tinybuildgames.helloneighbor&hl=en_NZ
- JustUseApp, Dark Riddle reviews: https://justuseapp.com/en/app/1385421494/dark-riddle/reviews
- Uptodown, Prank Master 3D: https://prank-master-3d.en.uptodown.com/android
- App Store, Prank Master 3D: https://apps.apple.com/us/app/prank-master-3d/id1528127833
- Uptodown, Troll Face Quest Classic: https://troll-face-quest-classic.en.uptodown.com/android
- Wikipedia, Untitled Goose Game: https://en.wikipedia.org/wiki/Untitled_Goose_Game
- Game Developer, Behind the HONK Q&A: https://www.gamedeveloper.com/design/behind-the-honk-an-i-untitled-goose-game-i-q-a
- Game Developer, Untitled Goose Game analysis: https://www.gamedeveloper.com/design/an-untitled-i-untitled-goose-game-i-analysis
- Game Developer, Road to the IGF: https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i-
- ACMI, player-comedians: https://www.acmi.net.au/stories-and-ideas/untitled-goose-player-comedians/
- Gameplay.co, Goose music and sound: https://gameplay.co/untitled-goose-game-music-sound-design/
- Gamepur, Goose length: https://www.gamepur.com/guides/how-long-to-beat-untitled-goose-game
- Kotaku, Goose review: https://kotaku.com/untitled-goose-game-the-kotaku-review-1838264644
- GameCritics, Goose review: https://gamecritics.com/mike-suskie/untitled-goose-game-review/
- Metacritic, Goose user reviews: https://www.metacritic.com/game/untitled-goose-game/user-reviews/
- TouchArcade, Hitman GO review: https://toucharcade.com/2014/04/17/hitman-go-review/
- Wikipedia, Hitman Go: https://en.wikipedia.org/wiki/Hitman_Go
- Game Informer, Hitman GO review (via search summary): https://gameinformer.com/games/hitman_go/b/ios/archive/2016/02/23/hitman-go-review-game-informer.aspx
- Wikipedia, Lara Croft Go: https://en.wikipedia.org/wiki/Lara_Croft_Go
- PocketGamer.biz, the making of Lara Croft GO: https://www.pocketgamer.biz/the-making-of-lara-croft-go/
- Aprasi, Granny (unverified install claim): https://www.aprasi.com/blogs/trending-topics/why-granny-by-dvloper-became-a-mobile-horror-hit
- Granny Wiki (via search summary): https://granny.fandom.com/wiki/Granny_(game) and https://granny.fandom.com/wiki/Difficulties
- Wikipedia, Tiny Thief: https://en.wikipedia.org/wiki/Tiny_Thief
- Destructoid, Tiny Thief review: https://www.destructoid.com/reviews/review-tiny-thief/
- JayIsGames, Tiny Thief: https://jayisgames.com/review/tiny-thief.php
- 148Apps, Robbery Bob review: https://www.148apps.com/reviews/robbery-bob-review/
- GameAnalytics 2025 benchmarks via GameDevReports: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks
- Segwise, retention benchmarks: https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies
- Playio, onboarding and D1: https://blog.playio.co/mobile-game-onboarding-retention
- Orientation overview: https://umjynb-lab.github.io/gameorientation/
