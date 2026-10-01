# Row 19 — the readability and gag review (fresh reviewers, opaque packets)

r3d-qa §3.3, index §6 row 19. **Verdict: FAIL.** Two of the five tests miss their bar:
- crowding: 2/8 frames answered "yes, crowded" (the bar is ≤ 1/8);
- gags: 6 of the 9 strips are under their bar, including the dizzy spin at 3/3 (its bar is 4/4).

The verb, spot and 2D-vs-3D tests pass. The failures are listed as requests in §7.

| Test | Packet | Result | Bar | Pass? |
|---|---|---|---|---|
| Verb: what is Hush doing | `packets/set_a/` (8 frames) | **7/8** named right | ≥ 7/8 | PASS (at the bar) |
| Spot: what happens if he uses it | `packets/set_b/` (8 frames) | **6/8** gist right | ≥ 6/8 | PASS (at the bar) |
| Crowding: is the screen crowded | `packets/set_c/` (8 frames) | **2/8** "yes" | ≤ 1/8 | **FAIL** |
| 2D vs 3D: which would you rather play | `packets/set_d/` (8 pairs) | **8/8** chose the 3D side | ≥ 6/8 | PASS |
| Gags: funny / readable / fresh, 1–5 | `packets/set_e/` (9 strips) | 3 of 9 at or over their bar | sneezes and dizzy spin ≥ 4/4; the rest ≥ 3/3; fresh ≥ 3 | **FAIL** |

## Verdict lines (read by `tools/scripts/pregate3d.sh` row 19)

Each packet had one reviewer, so these are that reviewer's numbers, not medians.

```
verdict verb 7/8
verdict spot 6/8
verdict crowded_yes 2/8
verdict prefer_3d 8/8
verdict gag g0_sneeze funny=4 readable=4 fresh=3
verdict gag p00_sneeze funny=4 readable=4 fresh=3
verdict gag p00_dizzy_spin funny=3 readable=3 fresh=4
verdict gag p00_curtain_call funny=3 readable=3 fresh=3
verdict gag p00_picture funny=1 readable=1 fresh=1
verdict gag p00_doorframe_bonk funny=2 readable=2 fresh=2
verdict gag p00_vase funny=1 readable=2 fresh=1
verdict gag p00_squeak_bit funny=1 readable=3 fresh=1
verdict gag p00_relief funny=1 readable=3 fresh=1
```

## 1. How the review ran

**The frames.** Built by r3d-qa phase 1 with `tools/art3d/review/packets.py build` from the real game:
- 1200×540, NightScene `--no-captions`, MSAA off;
- shuffled with a fixed seed per packet, opaque ids `pkt_NN`;
- prompts in each folder's `prompt.md`, the how-to in `reviewer_prompts.md`.

**The reviewers.** One fresh reviewer per packet, run by the orchestrator (ruling R17). Each saw only that packet's `prompt.md` and images. The answers below are pasted verbatim from the orchestrator's hand-off.

**Scoring.**
1. `python3 tools/art3d/review/packets.py score <key> <answers.md>` matched each answer against the key (and `--bar=3` for the gags).
2. Every row was then judged by hand on the gist, as the key's notes require. The hand verdict decides.
3. The matcher and the hand verdict agree on every row. The matcher left two spot answers `unmatched`; both are wrong on the gist.

**Where things are.** The keys were outside the repo until scoring and are copied into §2–§6 now that the review is over. Source key files: `<SP>/work/r3d-qa/keys/{verb,spot,crowd,compare,gags}_key.json`. The verbatim answer sheets and the matcher's verdict files are in `<SP>/work/r3d-qa/p3/{answers/,verdict_*.md}`.

**Source frames.** Each frame is named `<sequence>:<n>`: frame n of a DevShot sequence taken every 3 ticks (every 6 for `n01i`). The sim tick is about n × 3 (n × 6 for `n01i`). `cov2` starts at tick 230, so its tick is 230 + n × 3. The sequences:
- `g0` = Gate 0;
- `p00i` = Prologue ideal;
- `cov2` = r3d-integrate's coverage replay 2;
- `n01i` = Night 1 ideal;
- `N1Q:calm_<tick>` = a paused shot on a crafted calm Night-1 route.

## 2. Verb test — `packets/set_a/` (pass ≥ 7/8)

Question: *"What is the character in the black-and-white striped top and red beret doing in this frame? Answer with what she is doing, in a few words."*

The brief's wording, "purple-and-white", describes Bellows, so the question names Hush by her look. The two rigging frames both score as "rigging" (the pre-registered key accepts the reach).

| id | Key (item · expected · gist · source) | Answer (verbatim) | Matcher | Gist verdict |
|---|---|---|---|---|
| pkt_01 | vb_dive · diving into hiding · "diving into hiding (the pantry)" · g0:107 (≈ t321) | diving out of the wardrobe headfirst, arms forward | correct | **right** on the verb. Note: she was read as diving *out* of the pantry, see Q-V2. |
| pkt_02 | vb_statue · frozen as a statue · "frozen as a statue on a plinth" · cov2:72 (≈ t446) | posing frozen as a white statue, arms raised (unsure) | correct | **right** |
| pkt_03 | vb_reach_high · rigging · "reaching up to rig the pepper pot / honey on the shelf" · g0:63 (≈ t189) | standing on the stool, reaching for the striped jar on the shelf | correct | **right**: the reach-high on the stool. The reviewer did not say it was a prank set-up. |
| pkt_04 | vb_run · running · "running" · cov2:22 (≈ t296) | running left away from the wardrobe, holding something | correct | **right** |
| pkt_05 | vb_squeak · squeaking her toy · "squeezing her squeaky toy bird to make a noise" · cov2:278 (≈ t1064) | crouching at the sink, fiddling with something small and yellow (unsure) | confused (→ rigging) | **wrong**: the squeak was read as fiddling or rigging at the sink. See Q-V1. |
| pkt_06 | vb_bow · bowing · "taking a deep bow" · p00i:1226 | taking a deep bow on stage while roses fall | correct | **right** |
| pkt_07 | vb_reach_mid · rigging · "rigging the gramophone's lever" · p00i:774 (≈ t2322) | tampering with the gramophone horn | correct | **right** |
| pkt_08 | vb_sneak · sneaking · "sneaking / tiptoeing" · p00i:102 (≈ t306) | tiptoeing sneakily to the left | correct | **right** |

**Result: 7/8. PASS, exactly at the bar.** The one confusion is squeak → rigging (the same squeak / reach confusion D12 found at 64 px).

## 3. Spot test — `packets/set_b/` (pass ≥ 6/8 the gist of the joke)

Question: *"What will happen if the neighbour uses the object inside the cyan circle? Give the gist of the joke in a few words. (If the circled thing is a box or cupboard, say what is in it.)"*

| id | Key (item · expected · gist · source) | Answer (verbatim) | Matcher | Gist verdict |
|---|---|---|---|---|
| pkt_01 | sp_box · squeaker · "the box holds the squeaker (a squeaky horn toy) she can take" · n01i:756 (≈ t4536) | the box hides a honking bike/clown horn, so it blasts HONK in his face when he opens it (unsure) | correct | **right**: a horn in the box. The HONK-in-his-face joke is the reviewer's own invention. |
| pkt_02 | sp_gramophone · dizzy spin · "the record spins him round until he is dizzy" · p00i:756 (≈ t2268) | the gramophone record is rigged to skip or spin too fast, so the music goes haywire and leaves him dizzy (unsure) | correct | **right** |
| pkt_03 | sp_kettle · kettle duet · "the kettle sings / plays music along with him" · N1Q:calm_520 | the kettle sings a silly musical tune instead of whistling when it boils | correct | **right**: the kettle sings. The duet part (along with him) was not named. |
| pkt_04 | sp_recliner · chair launch · "the recliner launches him up to the ceiling" · n01i:1152 (≈ t6912) | a spring under the armchair cushion launches him up into the chandelier | correct | **right** |
| pkt_05 | sp_tap · face wash · "the tap sprays water in his face" · N1Q:calm_150 | the tap sprays water straight into his face | correct | **right** |
| pkt_06 | sp_pickle · jar fight · "he fights the jar: it will not open and he strains and slips" · N1Q:calm_360 | the tea jar has been tampered with, so something nasty comes out instead of tea leaves (unsure) | unmatched | **wrong**: read as a tampered tea jar. The struggle with the lid did not come across. See Q-S1. |
| pkt_07 | sp_honey · sneeze · "he gets a face full of pepper and sneezes" · g0:30 (≈ t90) | the sugar pot was swapped for hot chilli/spice, so his face burns red (unsure) | unmatched | **wrong**: the spice was read, but the sneeze was read as a burning red face. See Q-S2. |
| pkt_08 | sp_needs · kettle duet · "the kettle sings a duet with him; the dimmed preview + the grey squeaker silhouette say she must fetch the squeaker first" · n1q/needs_seq/frame_017 (≈ t5220) | the kettle plays a silly musical tune instead of whistling (unsure) | correct | **right** on the joke. The "fetch the squeaker first" need was not mentioned. |

**Result: 6/8. PASS, exactly at the bar.** The pickle jar and the honey/pepper previews were misread.

## 4. Crowding — `packets/set_c/` (pass ≤ 1/8 "yes")

Question: *"Is this screen crowded or confusing? Answer yes or no, then one sentence why."* The key expects "no" for every frame.

| id | Key (item · source) | Answer (verbatim) | Read as |
|---|---|---|---|
| pkt_01 | cr_g0_plan · g0:30 (≈ t90) | no — The mime, the single thought bubble with its tap-hand pointing at the shelf jar, and the corner minimap and buttons are all well spaced, so it's clear what to do next. | no |
| pkt_02 | cr_g0_rig · g0:64 (≈ t192) | yes — The progress ring, the glowing jar and a thought bubble all pile onto the mime's head, and the bottom-right button stacks a ring, a tap-hand and a small icon on top of each other, which makes both spots hard to read. (unsure) | **yes**. See Q-C1. |
| pkt_03 | cr_p00_c · p00i:891 (≈ t2673) | no — It is a clean close-up of one reacting character with music notes, and the applause meter and running-gag bar sit clearly at the top. | no |
| pkt_04 | cr_g0_sneeze · g0:118 (≈ t354) | no — The room is calm, with only the peeking eyes in the curtain and the minimap showing where the other character is, so nothing competes for attention. | no |
| pkt_05 | cr_p00_d · p00i:568 (≈ t1704) | no — The old man's thought bubble and the applause bar are easy to read, though the small extra bubble and the dropped items on the floor add a little noise. | no |
| pkt_06 | cr_p00_b · p00i:730 (≈ t2190) | yes — The red-ringed record bubble and its "x3" badge run into the "RUNNING GAG ×1" text, and the old man's thought bubble is cut off at the left edge with a second bubble only half visible. | **yes**. See Q-C2. |
| pkt_07 | cr_n01 · n01i:1128 (≈ t6768) | no — There are several cues (the kettle bubble, the tea thought bubble, the glasses icon and two bottom-left buttons), but they are spread out and tell one clear story: the old man wants tea and the kettle is the thing to use. (unsure) | no |
| pkt_08 | cr_p00_a · p00i:463 (≈ t1389) | no — The flying old man and the steam puff make one clear focal action, and the applause gain is easy to read; only a shelf item slightly touches the top-left HUD pill. | no |

**Result: 2/8 "yes". FAIL (the bar is ≤ 1/8).** Both "yes" frames show the same fault: transient overlays stack on each other or on HUD text. The rig ring, preview cloud and Hush's head pile up in pkt_02; the preview badge runs into the RUNNING GAG banner, and his thought cloud is clipped at the screen edge, in pkt_06. The calm screens (plan, wait, the payoff) all read as uncrowded.

## 5. 2D vs 3D — `packets/set_d/` (pass: the 3D side preferred ≥ 6/8)

Question: *"Which of the two frames, A or B, would you rather play on a phone held sideways: which is clearer and less crowded? Answer A or B, then one sentence why."*

The 2D side is `docs/review/r3d-ref2d/<moment>_20x9.png` (shot from `main`). The 3D side is the same moment and tick, with captions off.

| id | Key (moment · 3D side) | Answer (verbatim) | Read as | Verdict |
|---|---|---|---|---|
| pkt_01 | cmp_p00_calm_plan · A | A — It has far fewer props and HUD pieces, so the mime and the goal hint are easy to pick out, while B packs in furniture, a score bar, item slots and a conveyor strip. | A | 3D preferred |
| pkt_02 | cmp_n1_armed_entry · B | B — The large old man and the few room objects read at a glance, while A crowds a small character into a cluttered illustrated kitchen with extra UI rows along the bottom. | B | 3D preferred |
| pkt_03 | cmp_armed3_entry_n2 · B | B — The open room with a large mime and few props is easier to read, though the old woman at the right edge crowds the action button a little; A is dense with clutter and overlapping sprites. | B | 3D preferred |
| pkt_04 | cmp_bellows_offscreen_pip · B | B — The running mime stands out clearly in a sparse room with a minimal HUD, while A's busy kitchen and stacked UI bars make the small mime harder to track. | B | 3D preferred |
| pkt_05 | cmp_freeze_him_in_room · A | A — The large mime and grandparent stand clearly in a sparse hallway, while B is packed with detailed props, a gold side rail, item slots and a score panel. | A | 3D preferred |
| pkt_06 | cmp_n1_kitchen_rest · B | B — It has a calm, open room and fewer HUD elements, while A crams detailed kitchen art, a meter and a bottom slot row onto the screen, even though B's faint grey shape on the shelf is a bit unclear. | B | 3D preferred |
| pkt_07 | cmp_hush_rigging_honey · B | B — The mime on the stool, the thought bubble and the HOLD prompt are large and isolated, while A's small mime gets lost among dense kitchen detail and extra UI. | B | 3D preferred |
| pkt_08 | cmp_n2_hall_rest · B | B — The clean hallway and the clearly labelled applause and running-gag bar read easily, while A layers many props, a side rail, slots and overlapping text into a cramped frame. | B | 3D preferred |

**Result: 8/8. PASS.** Every reason given names fewer props, fewer HUD pieces and bigger characters: the owner's "UI too crowded" and "house too crowded" complaints, answered side by side.

Two side notes:
- In pkt_03 Bellows was read as "the old woman". In that N2 frame he enters at the right screen edge, cut off by the edge and overlapping the action button (N2 framing, R3).
- In pkt_06 the shelf shape was "a bit unclear".

## 6. Gag strips — `packets/set_e/`

Bars: the sneezes (`g0_sneeze`, `p00_sneeze`) and `p00_dizzy_spin` need funny ≥ 4 and readable ≥ 4; every other strip needs ≥ 3 on both; fresh ≥ 3 for all.

Question: *"For each strip: what happens, in one sentence? Then score it 1-5 on funny, readable (can you tell what happens and why, at this size, without sound?) and fresh (not the obvious version of the joke)."* The strips are r3d-integrate's Prologue gag strips plus the g0 sneeze, re-numbered from f0 (60 f = 1 s), captions off.

| id | Key (gag · P00 ideal tick) | funny | readable | fresh | Answer (verbatim) | Bar | Verdict |
|---|---|---|---|---|---|---|---|
| pkt_01 | p00_picture · laugh_picture t3273 | 1 | 1 | 1 | He walks up to the smoking gramophone (f0-f42), then turns and seems to walk on the spot by the doorway rope post, scowling, with a few sparkles near his head (f48-f138); I can see no setup, no hit and no payoff, so this looks like him being stuck rather than a gag (unsure). | 3 | **FAIL** (Q-G3) |
| pkt_02 | p00_doorframe_bonk · laugh_doorframe t1677 | 2 | 2 | 2 | With a search thought bubble, he jabs a long pointed stick around the fireplace with his back mostly to us (f0-f90), while eyes peek out of the yellow cupboard door to the right (f0-f120); "he is searching in the wrong place" just about reads, but nothing lands, and his face only shows briefly (f96-f108). | 3 | **FAIL** (Q-G2) |
| pkt_03 | p00_vase · laugh_vase t138 | 1 | 2 | 1 | With the neighbour only in the small corner inset, a small grey object tips off the left mantelpiece and lands in a puff by the hearth (f42-f72), then the mime climbs in at the right edge and stands still (f78-f126); there is no clear cause or effect, so it reads as a setup beat and not a gag (unsure). | 3 | **FAIL** (Q-G4) |
| pkt_04 | p00_squeak_bit · first squeak → bit_warmup t230 | 1 | 3 | 1 | The mime gets a hint card (duck arrow to an object, f6-f48), does a quick flourish for +2 applause (f18-f24), then tiptoes left towards a marked ring by the stool (f30-f114); the sneaking reads well in silhouette, but no prank is set or sprung. | 3 | **FAIL** (Q-G5) |
| pkt_05 | p00_curtain_call | 3 | 3 | 3 | The curtain falls (f30), the mime bows while roses rain down (f60-f150), the title card comes up (f180-f240), then on the Curtain Call screen the grumpy neighbour stomps on stage (f270-f510) and a fringed curtain pelmet lowers onto his head with little stars (f540-f690); it is a nice closing button with a long hold on his face, but the bonk is small and slow at this size. | 3 | PASS (at the bar) |
| pkt_06 | p00_sneeze · accent t1375 | 4 | 4 | 3 | Sitting on a stool with his tea, he winds up a long "ah-ah" (f0-f54), and the sneeze blasts him backwards across the kitchen (f60-f72) into the sink corner, where he slumps dazed under stars while the cup bounces on the floor (f78-f126), then he gets up searching (f126-f138); the windup and the hit read clearly in silhouette, but his face is mostly hidden in the hold and nothing shows what caused the sneeze. | 4 | PASS (at the bar) |
| pkt_07 | p00_dizzy_spin · accent t2659 | 3 | 3 | 4 | The gramophone startles him and something small and red flies off (f18-f36), then he can't stop conducting wildly with a baton (f54-f99), and the camera pushes in on his flushed face, steamed-up glasses and swirling notes (f99-f162) before he recovers, suspicious (f171-f207); "forced to conduct" is a fresher idea and the face hold works, but without sound it is unclear why he starts. | 4 | **FAIL** (Q-G1) |
| pkt_08 | g0_sneeze · accent t1163 | 4 | 4 | 3 | The same tea-and-stool sneeze launch as pkt_06, but with a better fake-out: his "ah-ah" (f0-f48) settles into relief (f54-f66) before the sneeze fires him backwards into the sink (f72-f90), and he stays slumped under stars with the cup rattling on the floor (f96-f138); the anticipation is stronger, but again his face is hard to read in the hold. | 4 | PASS (at the bar) |
| pkt_09 | p00_relief · laugh_relief t3238 | 1 | 3 | 1 | His thought bubble shows the gramophone while he stands by the doorway (f0-f36), then it switches to stairs and he turns and walks off towards the gramophone and rope post (f39-f69); it is a clear change of plan, but it is a walk-off, not a gag. | 3 | **FAIL** (Q-G6) |

**Result: 3/9 strips at or over their bar. FAIL.** Means: funny 2.22, readable 2.78, fresh 2.11.
- **Pass:** both sneezes (4/4/3, the same score D15 gave the sneeze in both of its rounds) and the curtain call (3/3/3).
- **Fail:** the dizzy spin (3/3/4) is one point under its 4/4 bar. The picture, the doorframe bonk, the vase, the squeak bit and the relief are under 3.

These are the weak gags phase 1 predicted from the frames: the vase is tiny, the squeak bit happens inside the Bellows window, the picture is muted, the relief is unclear. In each failing strip the reviewer could not see the **cause** or the **contact**: the hit happens off frame, behind his body, inside the small Bellows window, or with his back to the camera.

## 7. Requests (every failing or at-the-bar item: what was misread, which frame, who can fix it)

All R3D tasks have reported. Per the brief, the re-run is **r3d-integrate, alone**. The "Owner" column names the area whose files change, so the right brief is reopened.

| # | Test · frame | What the reviewer misread | Change requested | Owner (files) |
|---|---|---|---|---|
| **Q-C1** | crowding pkt_02 (cr_g0_rig, g0 ≈ t192). The same frame is verb pkt_03, and phase 1 saw it at g0 ≈ t180–200. | The ring, the glowing jar and the preview cloud "all pile onto the mime's head". The action button stacks its hold ring, the ghost tap-hand and the small prank icon. | (1) While Hush rigs, the preview / thought cloud moves to the free side of the target, or hides, because the ring already says what is happening. It must never sit over her face or her reach. (2) The ghost tap-hand stays off the action button once the hold has started. (3) Keep the rig ring on the reach target, clear of her arms. | r3d-hud (`game/ui/**` OverlayPlacer / OverlayRules, the ghost finger), with r3d-view3d for the anchor rects (`game/view3d/**`) |
| **Q-C2** | crowding pkt_06 (cr_p00_b, P00 ideal ≈ t2190) | The gramophone preview badge (record + red ring + "x3") "runs into the RUNNING GAG ×1 text". His thought cloud is clipped at the left screen edge, with a second bubble half visible. | (1) OverlayPlacer treats the transient top-band rects (APPLAUSE meter, RUNNING GAG banner) as keep-out while they show. (2) Thought clouds are clamped inside the safe rect, one at a time. Phase 1 also saw the honey preview under the APPLAUSE meter (≈ t1059). Add a layout test over the P00 ideal route: no world overlay intersects a shown HUD rect, and every cloud lies inside the safe rect. | r3d-hud (`game/ui/**`), r3d-view3d (anchor projection) |
| **Q-G1** | gags pkt_07 (p00_dizzy_spin, accent t2659, strip f0–f207) | "Without sound it is unclear why he starts": the cause (the record at speed) does not read. What he does reads as "forced to conduct", not a spin. Readable 3, funny 3 (the bar is 4/4). | (1) Stage him **beside** the gramophone, not in front of it. In f0–f90 his body hides the turntable and most of the cabinet; only the top of the horn shows behind his head. (2) Show the record at speed at the trigger (f18–f36): a spinning-disc blur, notes jetting out of the horn, the horn shaking. (3) Let the spin itself read in silhouette: a full turn with arms out before the conducting, held long enough to see. | r3d-integrate / r3d-view3d (GagStager3D staging position, `game/view3d/**`); r3d-sets (gramophone fx, `game/art3d/props/**`, `house3d.json`); r3d-anim-bellows-c (`rx_dizzy_spin_a`, timing locked by R3: re-pose only) |
| **Q-G2** | gags pkt_02 (p00_doorframe_bonk, accent t1677; integrate strip `p00_doorframe_bonk.jpg` t1627–1696) | The bonk does not land. At the accent (t1678) he stands at the wall pier in `act_hunt` with his back to the camera and raises his arm. No head contact, frame shake or stars read. The reviewer saw "searching in the wrong place … nothing lands". | (1) Stage the bonk **at** the pier or door frame: his head meets it on the accent frame, with a frame shake, a dust puff and stars. (2) Give a dazed hold with his face turned to camera (D8). (3) Keep his face visible through `cue_doorframe_bonk`. Phase 1's note "his face only shows briefly (f96–f108)" says the same. | r3d-integrate / r3d-view3d (CueStager3D target, `game/view3d/**`); r3d-anim-bellows-c (`cue_doorframe_bonk` gaze / turn) |
| **Q-G3** | gags pkt_01 (p00_picture, laugh_picture t3273, strip f0–f138) | "No setup, no hit and no payoff … him being stuck." The picture's fall happens behind the doorway pier at the screen's left edge. On his head the frame is a muted mauve square against the pink wall (f48–f90). He walks on the spot through f48–f138. | (1) Frame the cue so the fall is on screen: he stops a step away from the pier, or the camera pans to the doorway. (2) Give the picture a dark gilt frame or ink edge so it reads against the pink wall (r3d-integrate residual risk: "an R3 ink pass would help"). (3) Play a stunned / fuming hold clip instead of locomotion in place while the frame rides on his head. | r3d-integrate / r3d-view3d (CueStager3D, CameraDirector3D, `game/view3d/**`); r3d-sets (picture material, `game/art3d/set/**`) |
| **Q-G4** | gags pkt_03 (p00_vase, laugh_vase t138) | "No clear cause or effect": Bellows is only in the small window, and the vase is "a small grey object" on the left mantel. | (1) Put the cause on screen: his warm-up notes visibly travel to the vase, or the Bellows window escalates (bigger) for the cue. (2) The vase as a live prop at the ×1.5 rule (R5), not dressing size, with a wobble beat before it tips. (3) A puff and shards that read at 1200×540. | r3d-view3d (window escalation, `game/view3d/**`); r3d-sets (vase scale / value, `game/art3d/props/**`, `house3d.json`) |
| **Q-G5** | gags pkt_04 (p00_squeak_bit, t230); verb pkt_05 (cov2:278 ≈ t1064) | The reviewer saw only Hush: "no prank is set or sprung". His head snap happens inside the small Bellows window. In the verb test the squeak itself read as "fiddling with something small and yellow". | (1) The squeak's answer (his head snap) must be seen: escalate the Bellows window or cut to him for the reaction beat. (2) Get Hush out from under the action button after the climb-in and during the squeak. Phase 1 saw her there at P00 ≈ t78–140, and in this strip she stands at x ≈ 1150 under the button. (3) A bigger Clarence on the squeeze: swell the prop bone (D15 queue: RigMods3D MODE_SOCKET keeps a clip's baked prop-bone scale) and add a visible squeak ring or puff at the beak, so the toy and the noise read at phone size. | r3d-view3d (camera framing / window, `game/view3d/**`); r3d-rig (`game/view3d/char/**` socket scale); r3d-anim (`act_squeak`, the arm's-length squeeze); r3d-hud (noise ring) |
| **Q-G6** | gags pkt_09 (p00_relief, laugh_relief t3238) | "A walk-off, not a gag": the near miss is not shown, only his change of plan (gramophone → stairs). | (1) Show what he almost found: frame Hush hidden (eyes in the gap or frozen) together with him. (2) His relieved exhale with the face turned to camera (D8). (3) Then the plan change. | r3d-integrate / r3d-view3d (cue staging + framing); animation key for his relief beat (r3d-anim-bellows-b `st_*`) |
| Q-S1 *(at the bar)* | spot pkt_06 (sp_pickle, N1 calm t360) | The pickle jar's preview was read as "the tea jar … something nasty comes out". | The `jar_fight` pictogram should show the struggle (his straining face, both hands on the lid, sweat drops), not the jar and its contents. N1 is a preview in this build, so this can wait for R3 unless the spot test is re-run. | r3d-hud (`game/art/ui/**` pictograms) |
| Q-S2 *(at the bar)* | spot pkt_07 (sp_honey, g0 ≈ t90); the same preview appears in crowding pkt_02 | The sneeze preview (his face with an orange burst at the nose) was read as "hot chilli, his face burns red". | Draw the preview as a sneeze: head thrown back plus the cotton-wool CHOO puff blasting out (the in-game puff shape), not a red burst at the nose. Also give the white pepper pot a pepper-dot pictogram so it is not read as sugar. | r3d-hud (`game/art/ui/**` pictograms) |
| Q-V1 *(at the bar)* | verb pkt_05 (vb_squeak, cov2:278) | Read as "crouching at the sink, fiddling with something small and yellow". | See Q-G5 (3). The squeak shares one fix with the squeak bit. | r3d-anim / r3d-rig / r3d-hud |
| Q-V2 *(note)* | verb pkt_01 (vb_dive, g0:107 ≈ t321) | Right verb, wrong direction: "diving out of the wardrobe". | `act_dive` leaps right, toward the sink, past the pantry, before she appears inside. It should arc into the curtain (phase-1 note, g0 ≈ t310–336). | r3d-anim (`act_dive`, `game/art3d/anim/hush/**`); r3d-view3d (dive target) |

**After the fixes:** re-shoot the failing frames and strips from the same ticks. Then run **new** fresh reviewers (never the same ones) on a rebuilt packet with a new seed, for at least the crowding packet and the gag strips. Re-run pre-gate row 19.
