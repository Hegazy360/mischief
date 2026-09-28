# Neighbours from Hell: series deep dive (for "Mischief Next Door")

Research date: 2026-09-28. This is a genre reference only. Every name, character, layout and prank below belongs to THQ Nordic's *Neighbours from Hell* (NfH) IP. We invent our own.

Tags used in this report:
- **[web]** claims cite a URL in the Sources list.
- **[wiki-data]** marks numbers read through the MediaWiki API from the fan wiki's episode infoboxes. It also covers the game-logic dump from the PC game's debug log that the wiki hosts.
- **[memory]** marks things I recall but could not confirm. GameSpot, GameFAQs, IGN, MobyGames, TCRF and the Wayback Machine were Cloudflare-blocked from this container.
- **[inference]** marks my own reading of the data.

---

## 0. TL;DR

- NfH is a **puzzle game about timing, played on a side-view doll's house cut in half.** The neighbour loops 2–10 activities. You search containers for items, use each item on a hotspot tied to one of his activities, and hide. Each prank fires when he reaches that activity.
- **The fun comes from:**
  - the reaction animation, since that is the punchline;
  - **chaining** pranks while he is still angry;
  - the fear of being seen.
- **The complaints were:**
  - it is short (2–3 h per game);
  - it is repetitive (one house, one rage animation);
  - you work out pranks by trial and error;
  - there is a lot of waiting;
  - a full restart when caught (NfH1);
  - an unreadable anger meter;
  - click misreads.
- **The 2017 mobile ports reached 15M+ Google Play installs at 3.7★.** The main complaints were a paywall after three episodes, plus tiny tap targets with no tap feedback.

---

## 1. The series at a glance

| Title | Release | Content | Reception |
|---|---|---|---|
| *Neighbours from Hell* | PC 2003. JoWooD Vienna, designer Michael Paeck | 3 training episodes plus 14 episodes in 3 seasons, one house | Metacritic PC 69. IGN 7, GameSpot 6.7, Worthplaying 8.4 [web] |
| *NfH 2: On Vacation* | PC Feb 2004 | 14 episodes on a cruise ship, in China, India and Mexico. Adds Mother, Olga and 3 lives | Gamekult 4/10, JV 12/20. "Still fun, but not for very long – after half a day the credits are already rolling" [web] |
| GameCube/Xbox *NfH* | 2005, EU only | A remix of NfH1 and NfH2 levels, plus minigames and medals | Metacritic 41 and 49 [web] |
| Mobile *Season 1 / Season 2* | May 2017. THQ Nordic, dev Big Moon | Tutorial and about 3 episodes free, then an IAP unlock. Ads | Google Play: **S1 10M+ installs, 3.7★ (213K)**. **S2 5M+, 3.7★ (51.4K)** [web] |
| *Neighbours back From Hell* | Oct 2020 PC/consoles. Aug 2021 mobile, $4.99. Farbworks / HandyGames | NfH1 and NfH2 remixed into 4 seasons plus a finale. HD, double-frame-rate animation | Steam **5,357 reviews, 95% positive**. Metacritic 69. OpenCritic 66 [web] |

The 2003/04 Steam compilation still has 3,159 reviews at 98% positive, and in Russia the game was a phenomenon ("Как достать соседа") [web]. There is a real, lasting audience for the genre.

---

## 2. Episode structure and goals

### NfH1: rating, trick count and time limit per episode [wiki-data]

| Ep | Name | Tricks | Time | Rating needed |
|---|---|---|---|---|
| S1E1 | The First Trick | 4 | 5:00 | 50% |
| S1E2 | TV Afternoon | 6 | 5:00 | 55% |
| S1E3 | Birthday Surprises | 6 | 5:00 | 60% |
| S1E4 | The Apple Pie | 7 | 6:00 | 65% |
| S1E5 | The Old Spoilsport | 8 | 6:00 | 70% |
| S1E6 | Bath Time | 9 | 6:00 | 75% |
| S2E1–4 | Art for Mum's Sake / A Sunny Morning / One Little Piggy / Barbecue Time | 7 / 6 / 7 / 6 | 7:00 | 60 / 65 / 70 / 75% |
| S3E1–4 | Laundry Day / Fitness Frenzy / Do It Yourself / Night of the Hunter | 8 / 10 / 8 / 9 | 10:00 | 60 / 65 / 70 / 75% |

Patterns:
- The required rating climbs **+5% per episode** and **resets at each season**, because new rooms arrive then:
  - S1: hall, bathroom, kitchen, living room.
  - S2: adds bedroom, balcony and a parrot.
  - S3: adds basement, study and a dog [web: wiki].
- The game has 101 tricks in total.
- The timer was optional ("the game discourages" turning it off) [web: Game Hoard].
- You end an episode by walking out of the front door [web: Wikipedia].
- A skilled player finishes all 14 episodes in about 2–3 hours, per a review quoted on Steam.

### NfH2 [wiki-data; web: cheatbook]

The 14 episodes have **4–9 tricks each, with a minimum to pass that is usually total minus 2**:

| Episode | Tricks (minimum) |
|---|---|
| All Aboard! | 4 (3) |
| Covert Advance | 5 (3) |
| The Cabin is Occupied | 5 (3) |
| For Whom the Gong Sounds | 6 (4) |
| Ping-Pong Fucius | 5 (3) |
| Every Shot a Hit | 6 (4) |
| Mummy's Darling | 7 (5) |
| Above the Clouds | 7 (5) |
| Burning with Ambition | 7 (5) |
| The Enlightenment | 8 (6) |
| Neighbour Overboard | 8 (5) |
| Action! | 9 (7) |
| Eat and Be Eaten | 9 (7) |
| Don't Panic! | 6 (4) |

Other NfH2 rules:
- Tricks earn coins, and you need a minimum number of coins to go on.
- You get **3 lives per episode**. Being caught by the neighbour or his mother costs one [web: Wikipedia].
- Locations: ship → China ×4 → ship → India ×4 → ship → Mexico ×2 → ship. The finale hits an iceberg.

---

## 3. How the neighbour's routine works

**The loop.** Each episode gives him an ordered list of "affairs" (the wiki's word for his activities). He walks to each, plays a fixed animation, moves on, and repeats the list [wiki-data]:

- **The First Trick** (2 steps): watch TV → spy through the binoculars.
- **TV Afternoon** (2): TV → fridge for a beer.
- **Birthday Surprises** (4): take a candle → light it on the cake → party horn → check the letterbox.
- **The Old Spoilsport** (3): piano → throw back the kids' football and scold them → sniff his prized flower.
- **One Little Piggy** (9): dentures in a glass → bed → alarm → cage key → milk → feed the pig → chips → feed the parrot → key back.
- **Fitness Frenzy** (9): yoga book → fish → yoga → trampoline → bike → mixer → chest expander → barbell → skipping rope.

The episode card frames the loop as his day: "Like every Sunday afternoon... he slouches back and forth to the fridge".

**Movement.** The debug log dump exposes the engine's values. Units are ticks and pixels at 800×600; I **infer** about 10 ticks per second [wiki-data, Debugging Tools]:

| Mover | Mode | Speed | Noise |
|---|---|---|---|
| Neighbour | walk | 8 (3 on stairs) | — |
| Neighbour | run | 18, about 2.25× his walk | — |
| Woody | walk | 17 | 1 |
| Woody | sneak | 5, about 30% of his walk | 0 |

- Woody outpaces a walking neighbour but not a running one.
- Rooms are single walk lines joined by doors, and the pathfinder treats each door as a 1000-cost edge. Door transitions take 9–25 ticks.
- Crossing a room takes the neighbour about 7 s walking or 3 s running, and takes Woody about 12 s tiptoeing [inference].

**Action timings** [wiki-data]:
- Double-take: 14–23 ticks.
- Shouts: 24, 44, and 91 for the big tantrum (about 9 s).
- Slip: 30. Beating up Woody: 59–75.
- The config sets `angrytime="280"`, which I read as anger decaying over about 28 s [inference].
- Preparing a prank takes real time. Sawing the sofa legs takes **13 s** [wiki].
- A **progress bar** over Woody shows long actions, and progress carries across visits. The remaster removed it, and one Steam reviewer asked: "WHERE IS THE PROGRESS BAR?! How am I to know if one room visit will be enough".

**The telegraph.**
- The neighbour's portrait sits bottom-left with a speech bubble that "tells you what action/area he is on route for" [web: trophy-guide snippet]. ru.wikipedia says "his immediate intentions are displayed in the interface" [web].
- NfH2 added a **sleep progress bar** for the neighbour and Mum [web: cheatbook].
- The whole house is always visible, so you can watch him walk [memory, consistent with ru.wikipedia].

**Pranks that bend the loop** are the best puzzles [wiki-data]:
- Laxative in the beer makes him **run** to the toilet, which opens the 13 s sofa-sawing window.
- A mousetrap in the letterbox sends him running for first aid.
- Cheese on his flower sends him to the toilet.
- A BBQ flare-up sends him for the extinguisher, whose nozzle you have twisted.
- A soiled carpet adds "vacuum" to his loop.
- A prank call pulls him to the phone.
- After the fart-cushion prank he stops bringing Mum her pillow.

---

## 4. How pranks work

1. **Search.** Tap a drawer, fridge, medicine cabinet or bin. Woody rummages and gets 1–3 items. "Most items have single purposes" [web: Game Hoard].
2. **Use the item on a hotspot**: glue on binoculars, egg in the microwave, soap on the floor. Some pranks need no item: knot the TV aerial, spin a stool, open a valve.
3. **Trigger.** Most fire when **he uses the rigged object**. Others fire when he **passes by** (the microwave egg), **enters the room** (the knotted aerial), or **discovers** it (a clogged toilet, a defaced portrait of his mother) [wiki-data].
4. **Multi-step pranks**:
   - Take a bottle from the bin, fill it at the running bath, and swap it for his milk.
   - Unlock the medicine cabinet with a key from the bedside drawer.
   - Get into the captain's cabin, drug the toddy and unlock the helm.
   - Blow up a statue, then plant its flying head in a child's sand castle.
5. **Timing windows**:
   - You can only open valves after he closes them.
   - You can only swap the kids' football for a bowling ball in the seconds after it lands.
   - The whipped cream must be swapped between the microwave step and the eating step.
6. **Chains (NfH2).** Several tricks fire in one sequence [wiki-data; web: cheatbook]:
   - Chilli sauce on the toilet paper plus an oiled rice-chute lever: two tricks at once.
   - Soap in a puddle plus an open railing gate: overboard.
   - A crab in the sand castle plus a sea urchin on his towel, then Olga punches him: a **triple**.
7. **Captions.** Each NfH2 trick fires with a pun caption: "ping-SPLAT", "FLAMBE", "takes the subway", "a load of bull" [web: cheatbook].

---

## 5. Detection, noise, hiding and getting caught

- **Sight is room-based.** A Steam review: "if the bully ever ends up in the same room as you and you get seen, the computer walks you up to him so he can beat you up. Since there are very few places to hide this makes the game a quite difficult stealth game".
  - The guides plan around "wait for the neighbour to leave room X".
  - Exceptions: while he is asleep you can tiptoe into his room. You can slip in "while the neighbour is exiting", which implies he doesn't look back [web: 100% guide].
  - I could not confirm an exact facing rule [memory: on entering a room he spots you almost at once].
- **Noise is two-tier** [wiki-data]:
  - Woody walking = noise 1, which wakes pets.
  - A pet barking = noise 2, which **alarms** the neighbour, who runs over.
  - Tiptoeing (right-click) = noise 0.
  - A woken dog is also a **lure**: leave before he arrives and "he will stay in the room for some time" [wiki].
  - NfH2 dropped tiptoe. When the remaster added a sneak mechanic to the NfH2 levels, fans called it "godawful".
- **Hiding places**:
  - NfH1: the hallway wardrobe, a big chest of drawers, under the bed.
  - NfH2: baskets, statues, bins, chairs, vents [web: cheatbook].
  - Console: a balance minigame to stay hidden [wiki].
- **When caught**, Woody freezes and trembles, then gets beaten (about 6–7 s).
  - NfH1: the **episode restarts from zero** ("the show will be taken off the air").
  - NfH2 and the remaster: you lose one of 3 lives. In the remaster Woody is "beaten and kicked to another room/floor" [web: Games of Dayne].

---

## 6. Secondary characters

| Character | Role | How it complicates play |
|---|---|---|
| Parrot (NfH1 S2) | Sleeping sentinel | Walking wakes it and it screams, so "go to another room before the neighbour comes running", or tiptoe [wiki] |
| Guard dog (NfH1 S3) | Sentinel and lure | Its bark summons him at a run. Leaving before he arrives parks him in that room [wiki] |
| Mother (NfH2) | **Second patroller** with a short 2–3 station loop | Beats Woody on sight (costs a life). Calls her son away, which you can **provoke** by untying her dog. Spanks him when he embarrasses her [wiki] |
| Olga (NfH2) | Love interest, neutral | **Punches the neighbour** when he misbehaves, so she is a comic punisher who scores as a trick [wiki] |
| Olga's son | Victim NPC | The neighbour bullies him and Olga retaliates [wiki] |
| Mum's small dog | Item guardian | Guards Mum's bag. Bribe it with a sausage [wiki] |
| Elephant, bull, chef, pig | Environmental agents | Other characters deliver the gag: the elephant sprays him, the bull charges at red paint, the chef hits him with a pan [wiki] |

The sweet spot per level is 1 patroller, 0–2 sentinels and 1–3 punisher NPCs [inference].

---

## 7. Anger, rating, awards and the TV show

- **Anger meter.** Each prank fills it and it drains over time. Chaining the next prank before it empties earns a bonus [web: Game Hoard, Worthplaying].
  - NfH1: 100% needs every trick, and "some scenes require us to chain multiple tricks in succession" [web: 100% guide].
  - The early HUD counted "dirty tricks and neighbour's nervous breakdowns" [wiki].
  - NfH2's **Golden Neighbour needs the anger bar at MAXIMUM at the episode's end**, so you must order the whole level into one climax [web: cheatbook].
  - The meter was hard to read: "fairly unhelpful" [web: Game Hoard].
- **Awards.** NfH1 used a viewer-rating %, and a search snippet says 90%+ earns the Golden Neighbour [web, unverified]. NfH2 used bronze, silver and gold statuettes.
- **The remaster flattened scoring** to speed-based points, with gold for just doing every prank. Fans hated it: "kills half of the fun and puzzle solving"; "you had to plan and arrange traps in a specific order so the meter doesn't go back to 0" (Steam).
- **The TV framing**:
  - Woody stars in a hidden-camera reality show, and a director gives tutorial hints while breaking the fourth wall [wiki].
  - Each episode opens with a title card and teaser text ("he celebrates this happy day with his best friend – himself").
  - A "cheesy laughing crowd" plays "different levels of laughter suitable to the trick" [web: Worthplaying snippet].
  - The rating rises live.
  - An idle Woody **knocks on the screen**, which fans still remember (Steam).
  - The original had an optional **Trap Camera** picture-in-picture: "enable the Trap Camera... that's the best part of the game" (Steam).
  - The remaster's neighbour-cam was praised: "press a button and watch what happens... often quite hilarious".

---

## 8. Tutorial, pacing and moment-to-moment feel

- **Tutorial.** NfH1 opens with 3 training episodes. The first has **no neighbour at all**, just collecting tags and learning doors and stairs. So the first several minutes have no comedy. NfH2 teaches inside a real 4-trick episode. The mobile port's unskippable tutorial drew complaints ("I'm tired of replaying it again and again").
- **Pacing.** A first-time clear takes 5–10 min per episode and 2–4 h per game [web: Games of Dayne; Steam]. The 100% guide's final level says "patience is needed... lots of idling".
- **Feel** [memory, consistent with sources]:
  1. Click, and Woody walks across the cutaway house, pausing at doors and stairs.
  2. He rummages and an item pops into the inventory strip.
  3. You use it on a hotspot, a progress bar fills, and Woody gives the camera a cheeky "triumph" pose.
  4. You watch the neighbour trudge toward the trap, with your stomach knotting when he heads for your room.
  5. The trap fires: double-take, gag, shout, crowd laugh, rating tick. Then he stomps on while the meter drains.

  Reviewers call it "a mix of Hitman strategy with the stupidness of Mr Bean" [web: TheXboxHub], "Home Alone", and "Wallace and Gromit" art (Steam).

---

## 9. Prank catalogue: 48 series examples

Genre reference only [web: 100% guide; wiki; cheatbook].

**Fires when he uses the object**
1. Glue on the binoculars.
2. Laxative in the beer.
3. Gag dynamite in the birthday-candle box.
4. Mousetrap in the letterbox.
5. Shaving foam swapped for the whipped cream.
6. Superglue in the aftershave.
7. Hair restorer in the deodorant.
8. Stinky cheese on his prized flower.
9. Scribbles on the piano sheet music.
10. Shoe polish on his towel. **We should avoid this one** because it reads as a face-darkening gag; use blue dye instead.
11. Glue in the photo album.
12. Bath pearls swapped for his sweets.
13. Bathwater swapped for his milk.
14. Dirty shoe brush swapped for his toothbrush.
15. Honey in the sun cream.
16. Weedkiller in the watering can.
17. Potting soil in the coffee tin.
18. Hot sauce on his dentures.
19. Vinegar swapped for his wine.
20. Growth formula in the plant sprayer, so the flytrap grows huge.
21. Red wine in the washing machine.
22. Soap flakes in the fish food.
23. Spring under the trampoline.
24. Yoga book swapped for a knot book.
25. Sawn barbell.
26. Assembly instructions swapped for a torture book.
27. Gunpowder in his pipe tobacco.
28. Cork in the shotgun.
29. Nail in the gramophone.
30. Balloon in the hunting horn.
31. Rat in the medal box.

**Fires when he walks past or steps on it**
32. Egg in the microwave, which explodes as he passes.
33. Soap, marbles or a banana peel on the floor. Soap only works in wet rooms; the others work anywhere.
34. Roller skate on the floor.
35. Cut cable in a puddle, plugged in.

**Fires on discovery**
36. Knotted TV aerial.
37. Mum's portrait "improved" with a marker.
38. Clogged toilet.

**Fires when he sits, with prep time**
39. Sawn sofa legs (13 s, needs the laxative detour).
40. Drawing pins on a chair.
41. Fart cushion.
42. Cactus on the alarm clock.

**Routine-exploiting**
43. Prank call from his own phone.
44. Kids' football swapped for a bowling ball, which he kicks back.
45. Pig released from its cage.

**NfH2 chains and third-party gags**
46. Duck egg swapped for the ping-pong ball: it hits Olga and she punches him.
47. Red paint on the bench, so the bull charges.
48. Urinal tablets in the sweets plus the toilet signs swapped, so he is sick in the ladies' room with Olga inside.

More NfH2 examples: a cannonball disguised as a watermelon; a real brick among the foam karate bricks; a firecracker in a hot dog; water skis nailed to the jetty; a cow-pat in the ice-cream machine; a piñata swapped onto a beehive; a shark fin on an RC submarine; a drugged toddy plus an unlocked helm, which sinks the ship.

---

## 10. What players loved (quotes)

- **Reactions**:
  - "Every time this man had a near stroke from rage, I giggled like a 5 year old."
  - "I'm writhing in laughter every time the fat guy starts yelling, even though I've already played the joke 20 times." (Steam)
- **Chaining**:
  - "I'd show my parents how I can chain 10 tricks and make the neighbor lose his ♥♥♥♥."
  - "figure out the order with which the traps have to be placed to maximize the poor bastard's anger." (Steam)
- **Stealth fear**: "The thrill of sneaking around... We would hide for ages, too scared to come out." (Steam)
- **Payoff watching**: "set up all the different traps... and then wait for him to step into each one." (Steam)
- **Discovery**: "far more fun if you're just playing it for the first time and performing random, non-sequential tricks just to see all animations." (Steam)
- **Mastery**: "I still can't 100% it... but boy, oh boy, is it satisfying when you finally succeed." (Steam)
- **Combinations**: "Finding the multiple possible combinations of setting up pranks is fun and rewarding" [web: TheXboxHub].

## 11. What players criticised (quotes)

- **Short**: "after half a day the credits are already rolling" [web: Wikipedia NfH2].
- **Repetitive**:
  - "After you've seen it once, you've seen it a million times" [web: Worthplaying].
  - "interest waning by the second season... needs more surprises" [web: TheXboxHub].
  - "9/10 for the 30 min, then 2/10" (Steam).
- **Trial and error**:
  - "four to five attempts upwards to successfully beat each level"; "All the pranks are totally 'pre-cooked'"; "First one didn't age well. A lot of trial and error... Second one... discernable intended solution" (Steam).
  - NfH2 had "highlighted hints and fleshed out items that no longer blend in with the background" (Steam).
- **Waiting**: "Too much waiting and watching the same thing over and over" (Steam). "Slow neighbour movement creates tedious waiting periods" [web: Game Hoard].
- **Harsh failure**: "every time the neighbor catches you, you have to redo everything" (Steam).
- **Controls**:
  - "clicking for Woody to do something and he either doesn't do it" [web: Worthplaying].
  - "you clicked to hide under the bed but the game decided you clicked to walk around the bed instead" (Steam).
- **Missed punchlines**: you "miss a trick's entire punch line" when watching elsewhere [web: Worthplaying].
- **Forced laughs**: "annoying... laugh track... trying to force a laugh out of you"; "a loud airhorn every time you pull off a prank" (Steam).
- **Moral friction**: "Why am I repeatedly pranking my sad, lonely neighbor?" The remaster's intro showing his cruelty helped: "we now have a bit more context on why he's being a prick" (Steam).

## 12. The 2020 remaster and the mobile ports: touch and UX

**Remaster** [Steam; wiki]:
- *Praised:* 16:9 HD graphics, a zoom-out view, a follow-the-neighbour camera and controller support.
- *Hated:* the forgiving rage meter and speed-based score ("baby mode"); the removed progress bar; new slot-machine and match-3 search minigames ("all it does is waste time"); the cut tutorial and levels (later restored).
- *Input bugs:* "commands don't queue"; Woody "will go to that room and stop right in the middle"; "You have to click 2, 3 or 4 times on objects".

**2017 mobile ports** (Google Play reviews, fetched 2026-09-28):
- "On a phone it's so small it's hard to tell where to tap... which sucks because it's a game about timing. A lot of the time I tap a door more than once bc there's no feedback and he goes thru twice and I get caught. Some sort of indication that you entered a recognizable command would be welcome."
- "Really struggle to 'click' on an item. This game is a PC game and they have not done enough to make it work with touch screen." (45 helpful votes)
- "Sometimes touching different objects is difficult because my fingers are a bit big."
- "I hate when I have to keep the tool in the center." This refers to NfH2's dexterity minigame, which "nudges your cursor in random directions" [web: cheatbook].
- Most 1★ reviews are about the paywall after 3–6 episodes and ads on a paid game.

The 2021 remaster port was $4.99 premium with controller support [web: TouchArcade].

---

## 13. Design lessons for our game

1. **A laugh within 30 s, with no tutorial level.** Episode 1 should open with the neighbour mid-loop and a glowing container one step away, and a one-item prank should pay off on his very next activity. Teach sneaking, hiding and chaining inside real pranks, with 3–4 per episode for episodes 1–3.
2. **The reaction animation is the product.** Each prank gets a unique 2–4 s payoff plus a pun caption.
   - Rage comes in 3 tiers (2 s grumble, 4 s shout, about 6 s tantrum), each with at least 3 random variants.
   - Keep the tantrum shorter than NfH's 9 s one, which players tired of.
3. **Never let a punchline happen off-screen.** When a prank fires elsewhere, open an automatic trap-cam picture-in-picture at about 35% of the screen, or pan if the player is idle. Add a "watch him" follow button.
4. **Over-telegraph.**
   - A thought bubble shows the icon of his next activity and its room, with a countdown ring to his departure.
   - A tappable routine strip shows the whole loop.
   - Sleep and bath get their own countdown bars.
   - Readable schedules turn trial and error into planning.
5. **Kill waiting.**
   - Keep loops at 60–75 s early on and 90–120 s late.
   - Give the player lures that pull him off-loop on demand: a phone, a doorbell, a pet, a radio.
   - Offer ×2 fast-forward while hidden and idle.
   - No level may require "idling".
6. **Stealth that is tense but fair.**
   - Sight is room plus facing, with a **0.8 s double-take window**: a "?" bubble and a sting sound, during which tapping a hiding spot saves you. Near-misses become comedy.
   - Keep the two-tier noise model: walking wakes pets, a pet's bark summons him at a run, and tiptoe is silent at about 30% speed.
   - Woody walks about 2× the neighbour's walk and is slower than his run.
7. **Being caught is a gag, not a reset.**
   - Play a 3 s thrashing, then Woody is tossed out of the front door and walks back in.
   - Pranks stay rigged, and the cost is rating plus one of 3 "takes".
   - NfH1's full restart was the harshest complaint.
8. **Chaining is the depth.**
   - Keep a big, always-visible rage meter that drains over 20–25 s, with multipliers of ×1.5 and then ×2 for pranks inside the window.
   - A full meter triggers a tantrum climax worth a bonus.
   - Use three goals per episode: *pass* (N of M pranks), *all pranks*, and *Golden* (finish at max rage). Veterans loved this and hated the remaster removing it.
9. **Each episode needs at least one routine-bending prank.** The laxative detour opening a 13 s sawing window is the model "aha".
10. **Author Rube Goldberg chains.** Two or three pranks should fire in one fall, often finished by a third-party punisher (Mum, a bystander, an animal). NfH2's best laughs were built this way.
11. **No pixel hunting.** Give interactables outlines or sparkles and show a ghost of an item's target. A producer character gives two-tier hints on request, first a nudge and then the exact hotspot.
12. **Hold-to-rig, never minigames.** A progress ring lasts 0.5–3 s for normal pranks and 5–13 s for big ones, and progress persists across visits. No dexterity, slot or match-3 minigames; they were the most-hated additions in the series.
13. **Touch must give feedback on every tap.** This was the ports' core failure.
    - Hit areas of at least 10 mm, snapping to the nearest hotspot.
    - An instant ripple, a haptic tick and a "Woody is going here" marker.
    - Queued commands, with repeat taps idempotent (a double-tapped door ≠ two door trips).
    - A large contextual HIDE button and hold-to-tiptoe.
    - The current room fills at least 55% of screen height, with pinch-out to see the whole house.
    - This also answers our owner's Booby feedback that the buttons and rooms were too small.
14. **Add one complicating character per season**, each with its own telegraphed loop: a sleeping pet that is also a lure, then a second patroller who punishes the neighbour, then a bystander who beats him when he's rude.
15. **Variety for hours, not 2–3.**
    - A new location every 4–6 episodes and a new mechanic every 2–3.
    - More pranks than required per episode (e.g. 8 available, 5 to pass), with **2 ways to sabotage most stations**, which answers "pre-cooked".
    - Challenge stars: all pranks, one unbroken chain, never hide, beat a target time.
16. **Use the TV show as the feedback system, with restraint.** A live rating ticker, a crowd whose laugh scales titter → laugh → roar → applause on combos, and episode title cards with one-line teasers. No air-horn, and vary the laugh samples.
17. **Justify the revenge.** A 20–30 s cold open should show the neighbour being awful. Keep the slapstick cartoonish, and cut dated gags such as peeping or face-darkening.
18. **Mobile session shape.** Episodes should run 2–4 min early and 5–8 min late, with a soft timer (rating decay) rather than a fail. Keep the "walk out of the front door" ending ritual.
19. **Plan for small fourth-wall delights.** Idle gags such as knocking on the screen, looks to camera and a triumph pose after rigging are what fans remember 20 years later.
20. **Don't monetise mid-story.** This is later scope, but most 1★ reviews of the 15M-install ports were about paywalls and ads, not gameplay.

---

## Sources

- Steam 100% guide: https://steamcommunity.com/sharedfiles/filedetails/?id=2584421942
- Fan wiki, read via `https://neighboursfromhell.fandom.com/api.php?action=parse&prop=wikitext`:
  - Episode pages, e.g. https://neighboursfromhell.fandom.com/wiki/The_First_Trick, …/TV_Aftermoon, …/Birthday_Surprises, …/The_Apple_Pie, …/The_Old_Spoilsport, …/Bath_Time, …/One_Little_Piggy, …/Barbecue_Time, …/Laundry_Day, …/Fitness_Frenzy, …/Do_it_yourself, …/Night_of_the_hunter, …/All_Aboard!, …/Convert_Advance, …/The_Cabin_is_Occupied, …/Ping-pong_fucius, …/Every_shot_a_hit, …/Mummy%27s_darling, …/Above_the_clouds, …/Neighbour_over_board!, …/Action!, …/Eat_and_be_eaten, …/Don%27t_panic!
  - Engine data: https://neighboursfromhell.fandom.com/wiki/Debugging_Tools
  - Characters: …/Guard_Dog, …/Chilli, …/Mama_Rottweiler, …/Olga, …/Yapper, …/Joe
  - Versions: …/Neighbours_back_From_Hell, …/Neighbours_From_Hell_(Gamecube,_Xbox), …/First_Steps, …/Early/unused_content
- Wikipedia: https://en.wikipedia.org/wiki/Neighbours_from_Hell, https://en.wikipedia.org/wiki/Neighbours_from_Hell_2:_On_Vacation and https://ru.wikipedia.org/wiki/Как_достать_соседа
- HandWiki: https://handwiki.org/wiki/Software:Neighbours_from_Hell
- NfH2 walkthrough: https://www.cheatbook.de/wfiles/neighboursfromhel2onvacationsalution.htm
- Reviews:
  - https://thegamehoard.com/2018/04/27/neighbours-from-hell-pc/
  - https://worthplaying.com/article/2003/8/28/reviews/12069-pc-review-neighbors-from-hell/
  - https://www.thexboxhub.com/neighbours-back-from-hell-review/
  - https://gamesofdayne.com/neighbours-back-from-hell/
  - https://opencritic.com/game/10315/neighbours-back-from-hell/reviews
- Steam:
  - https://store.steampowered.com/app/1283190/
  - https://store.steampowered.com/app/260750/
  - Review API: https://store.steampowered.com/appreviews/1283190?json=1
- Google Play: https://play.google.com/store/apps/details?id=com.nordigames.nfh and https://play.google.com/store/apps/details?id=com.nordigames.nfh2
- TouchArcade:
  - https://toucharcade.com/2017/05/30/thq-releases-a-free-neighbours-from-hell-port-on-the-app-store/
  - https://toucharcade.com/2021/08/03/neighbours-back-from-hell-iphone-android-out-now-price-controller-support-handy-games/
- TapTap: https://www.taptap.io/app/51592 and https://www.taptap.io/app/219602
- Search snippets only (the pages were blocked):
  - https://www.gamespot.com/reviews/neighbors-from-hell-review/1900-6075608/
  - https://dexdotexe.com/neighbours-back-from-hell-trophy-guide/
  - https://www.neoseeker.com/neighbours-from-hell/faqs/86250-neighbors-from-hell-neughboursfromhell.html
