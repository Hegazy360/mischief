# Row 19 — the readability and gag review (fresh reviewers, opaque packets)

> **Current verdict: round 3, at the end of this file** (2026-10-02, the fix-round-2 tree, 3 fresh reviewers per packet, medians per D18.1): **FAIL** on the gags (3 of 9 at their bar: both sneezes 4/4/3 and the curtain call 3/3/3 pass); spot **7/8** and crowding **1/8** pass; the verb (7/8) and 2D-vs-3D (8/8) results of round 1 carry. Rounds 1 and 2 follow, unchanged.

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

---

# Round 2 — QA round 2 (2026-10-01, fix-round-1 tree): spot, crowding and gags re-run with new reviewers

Tree: `5f0092b` (fix round 1) plus r3d-fix-hud2's working tree, pre-gate content hash `bd0fb2503d06829a`. The packets
were rebuilt by r3d-qa round 2, phase 1, from that tree (`docs/review/r3d-qa/index.md` §R2.3): 1200×540,
NightScene `--no-captions`, MSAA off, new seeds, new keys, the same moments and ticks as round 1. Three **new** fresh
reviewers answered them, one per packet; none had seen a round-1 packet. The orchestrator ran them and handed over the
answers, pasted below verbatim. Round 1 (above) is kept as it was.

**Verdict: FAIL.** Two of the five tests miss their bar:
- crowding: **2/8** "yes" (the bar is ≤ 1/8), the same count as round 1, but on a different pair of frames;
- gags: **1 of 9** strips at its bar (round 1: 3 of 9).

The spot test passes at the bar. The verb test and the 2D-vs-3D test are not re-run: their round-1 results stand
(7/8 and 8/8).

| Test | Packet | Round 2 | Round 1 | Bar | Pass? |
|---|---|---|---|---|---|
| Verb: what is Hush doing | `packets/set_a/` (not rebuilt) | — (round 1 stands) | 7/8 | ≥ 7/8 | PASS (carried) |
| Spot: what happens if he uses it | `packets/set_f/` (8 frames, seed 89) | **6/8** gist right | 6/8 | ≥ 6/8 | PASS (at the bar) |
| Crowding: is the screen crowded | `packets/set_g/` (8 frames, seed 97) | **2/8** "yes" | 2/8 | ≤ 1/8 | **FAIL** |
| 2D vs 3D: which would you rather play | `packets/set_d/` (not rebuilt) | — (round 1 stands) | 8/8 | ≥ 6/8 | PASS (carried) |
| Gags: funny / readable / fresh, 1–5 | `packets/set_h/` (9 strips, seed 113) | **1 of 9** at its bar | 3 of 9 | sneezes and dizzy spin ≥ 4/4; the rest ≥ 3/3; fresh ≥ 3 | **FAIL** |

## R2 verdict lines (read by `tools/scripts/pregate3d.sh` row 19)

Row 19 reads every `verdict` line in this file, and for each test the **last** line wins. These lines therefore
replace round 1's for spot, crowding and the gags, and repeat round 1's verb and 2D-vs-3D results unchanged. Each
packet had one reviewer, so these are single scores, not medians.

```
verdict verb 7/8
verdict spot 6/8
verdict crowded_yes 2/8
verdict prefer_3d 8/8
verdict gag g0_sneeze funny=3 readable=3 fresh=3
verdict gag p00_sneeze funny=3 readable=3 fresh=3
verdict gag p00_dizzy_spin funny=3 readable=4 fresh=3
verdict gag p00_curtain_call funny=2 readable=2 fresh=2
verdict gag p00_picture funny=3 readable=4 fresh=3
verdict gag p00_doorframe_bonk funny=2 readable=3 fresh=1
verdict gag p00_vase funny=2 readable=3 fresh=2
verdict gag p00_squeak_bit funny=1 readable=2 fresh=1
verdict gag p00_relief funny=1 readable=2 fresh=2
```

## R2.1 How it was scored
1. The answers were saved verbatim to `<SP>/work/r3d-qa/p4/answers/{spot,crowding,gags}.md`.
2. `python3 tools/art3d/review/packets.py score <SP>/work/r3d-qa/keys/r2_<packet>_key.json <answers> --out=… --json=…`
   (`--bar=3` for the gags). The verdict files are `<SP>/work/r3d-qa/p4/verdict_{spot,crowding,gags}.{md,json}`.
3. Every row was then judged by hand on the gist, as the key notes require. I looked at every packet image and every
   strip page, and cropped the overlays the answers name. The hand verdict decides.
4. The matcher and the hand verdict agree on every row. The spot matcher left pkt_03 `unmatched` and pkt_01
   `confused` (kettle duet → squeaker); both are judged not right on the gist (below).

Frame tags: `g0:n`, `p00i:n` = frame n of the every-3-tick sequence (tick ≈ 3n); `n01i:n` = every 6 ticks from engine
frame 4404 (tick ≈ 4404 + 6n); `calm_<t>` = a paused shot at tick t on the crafted N1 calm route; `needs:38` ≈ t5219.

## R2.2 Spot — `packets/set_f/` (pass ≥ 6/8 the gist of the joke)

Question (as round 1): *"What will happen if the neighbour uses the object inside the cyan circle? Give the gist of
the joke in a few words. (If the circled thing is a box or cupboard, say what is in it.)"*

| id | Key (item · expected · gist · source) | Answer (verbatim) | Matcher | Gist verdict |
|---|---|---|---|---|
| pkt_01 | sp_needs · kettle duet · "the kettle sings a duet with him; the dimmed preview + the grey squeaker silhouette say she must fetch the squeaker first (his red ring: he is coming for tea next)" · `needs:38` (≈ t5219; round 1 `needs_seq/frame_017`) | the kettle is rigged with a honking horn, so when it boils it blasts a loud honk that startles him (unsure) | confused (→ squeaker) | **not right.** Half of it reads: a horn goes into the kettle, which is the squeaker stuffed into it (`kettle_drum`). The joke does not: the kettle squeaks a melody and he harmonises, but the reviewer saw a startle honk. The notes in the bubble were not read as music, and the "fetch the squeaker first" state was read as part of the rig. See Q2-S2. |
| pkt_02 | sp_honey · sneeze · "he gets a face full of pepper and sneezes" · `g0:30` (≈ t90) | the spice on the shelf (pepper shaker and bowl) makes him sneeze hard (unsure) | correct | **right.** Round 1's Q-S2 is fixed: the redrawn `achoo_ria` pictogram (head back + CHOO puff + pepper pot) reads as a sneeze. |
| pkt_03 | sp_pickle · jar fight · "he fights the jar: it will not open and he strains and slips" · `calm_360` (N1) | the green polka-dot vase gets rigged to tip or fall onto his head (unsure) | unmatched | **wrong.** The redrawn `in_a_pickle` pictogram (him hugging the jar, red-faced, an arrow at the lid) sits about 130 px above the jar, among five bubbles, and was not read. The jar itself was read as a vase. See Q2-S1. |
| pkt_04 | sp_recliner · chair launch · "the recliner launches him up to the ceiling" · `n01i:418` (≈ t6912) | the armchair is spring-loaded, so sitting down launches him up into the chandelier | correct | **right** |
| pkt_05 | sp_kettle · kettle duet · "the kettle sings / plays music along with him" · `calm_520` (N1) | the kettle shrieks a loud whistling tune when he boils it, startling him (unsure) | correct | **right, weakly.** "A whistling tune" names the music, so it passes round 1's standard ("plays a silly musical tune" was accepted). The duet and his singing along were not read, and "startling him" is a different joke. |
| pkt_06 | sp_tap · face wash · "the tap sprays water in his face" · `calm_150` (N1) | the tap sprays water straight into his face | correct | **right** |
| pkt_07 | sp_box · squeaker · "the box holds the squeaker (a squeaky horn toy) she can take" · `n01i:22` (≈ t4536) | the taped box holds a clown bulb horn that honks (prop for a prank) (unsure) | correct | **right** |
| pkt_08 | sp_gramophone · dizzy spin · "the record spins him round until he is dizzy" · `p00i:756` (≈ t2268) | the record plays at triple speed and spins in a hypnotic swirl, leaving him dizzy (unsure) | correct | **right** |

**Result: 6/8. PASS, exactly at the bar** (round 1: 6/8). The sneeze preview now reads (round 1 misread it). The pickle
jar still does not, even with its new pictogram, and the kettle preview with the "needs the squeaker" state reads as a
honk prank. Six of the eight answers carry "(unsure)".

## R2.3 Crowding — `packets/set_g/` (pass ≤ 1/8 "yes")

Question (as round 1): *"Is this screen crowded or confusing? Answer yes or no, then one sentence why."* The key
expects "no" for every frame.

| id | Key (item · source) | Answer (verbatim) | Read as | Round 1 (same moment) |
|---|---|---|---|---|
| pkt_01 | cr_g0_rig · `g0:64` (≈ t192) | no — the mime on the stool with the glowing teapot and its ring is the obvious focus, and the HUD, the camera inset and the action button stay out at the corners. | no | **yes** (Q-C1). Fixed: no cloud on her head while she rigs, the ring stays on the pot, no ghost hand on the button. |
| pkt_02 | cr_p00_d · `p00i:568` (≈ t1704) | no — the dazed character fills the middle and is easy to read, and the applause bar and the silhouette audience sit apart at the top and bottom edges. | no | no |
| pkt_03 | cr_p00_c · `p00i:891` (≈ t2673) | no — this is a close-up of one dazed character with music notes, so the scene is easy to read and the HUD stays at the edges. | no | no |
| pkt_04 | cr_p00_b · `p00i:730` (≈ t2190) | yes — the thought bubble by the old man, the loose record "x3" icon next to the applause bar, two highlighted objects and the floor ring all compete, and it is unclear which icon goes with which object. | **yes** | **yes** (Q-C2), for a different reason then: the badge ran into the RUNNING GAG text. |
| pkt_05 | cr_g0_plan · `g0:30` (≈ t90) | no — the hand pointer and bubble clearly mark the teapot on the shelf, though the floor ring under the stool is a second target that takes a moment to connect (unsure). | no | no |
| pkt_06 | cr_g0_sneeze · `g0:118` (≈ t354) | no — the room is sparse and calm with only the curtain eyes and the corner inset, but the main action happens only in the small inset, so it may feel a bit empty. | no | no |
| pkt_07 | cr_n01 · `n01i:394` (≈ t6768) | yes — two thought bubbles with red rings, a glasses icon squeezed onto the wardrobe top, a pot on the mime's head, a busy row of progress dots, two bottom buttons and a floor ring all appear at once. | **yes** | no (unsure): "several cues … but they are spread out" |
| pkt_08 | cr_p00_a · `p00i:463` (≈ t1389) | no — the old man falling off the stool is clear and funny, though the shelf items and a flying white object overlap the top-left HUD pill and clutter that corner slightly. | no | no |

**Result: 2/8 "yes". FAIL** (the bar is ≤ 1/8). Round 1's g0 rig frame is fixed. What I saw in the two "yes" frames:
- **pkt_04 (P00, t2190).** Round 1's fix moved the gramophone's preview badge (the record, "×3" and his red countdown
  ring) out of the RUNNING GAG text. It now floats beside the APPLAUSE meter at y ≈ 90, about 200 px above the
  gramophone it belongs to (x ≈ 485, y ≈ 310), with no tail to it. On the left, his own thought bubble shows the same
  gramophone inside a **second** red countdown ring, and his awareness glyph and three ear pips sit beside it as a
  third small bubble. On top of that: two outlined props (the gramophone glowing, the piano's blue hiding-spot edge)
  and the floor ring at the gramophone. The answer names the result: "unclear which icon goes with which object".
- **pkt_07 (N1 kitchen, t6768).** The frame is almost the same as round 1's, which the round-1 reviewer called "no
  (unsure)" (side by side: `<SP>/work/r3d-qa/r2/cmp_n01.jpg`, row 3). It has the same pattern: two red countdown rings
  for one target (the kettle preview and his tea thought); his awareness glyph (spectacles + pips) on the pantry top;
  the Script chip's five pips; the item slot; the action button; the floor ring. Hush's head is in front of the pickle
  jar's shelf, so the jar reads as "a pot on the mime's head". N1 is a hidden preview in this build, but the frame is in
  the packet and counts.
- So the 2/8 is partly reviewer variance (pkt_07 is a borderline frame that flipped). Both "yes" frames still share one
  fault: his countdown ring is drawn twice for one target, and the preview badge is pushed away from its prop.

## R2.4 Gag strips — `packets/set_h/` (9 strips, TECH §11 rubric in the prompt)

Bars: the sneezes (`g0_sneeze`, `p00_sneeze`) and `p00_dizzy_spin` need funny ≥ 4 and readable ≥ 4; every other strip
needs ≥ 3 on both; fresh ≥ 3 for all. Question: *"For each strip: what happens, in one sentence? Then score it 1-5 on
funny, readable (can you tell what happens and why, at this size, without sound?) and fresh (not the obvious version
of the joke)."* The prompt adds the rubric checks (silhouette, opposed anticipation, accent ≤ 4 f with a pop, a hold
≥ 30 f where his face reads, one overshoot, no sliding) and skips sound. Each window is `[sequence, t0, t1, stride]`
(ticks), the same as round 1's set_e.

| id | Key (gag · window) | funny | readable | fresh | Answer (verbatim) | Bar | Verdict | Round 1 |
|---|---|---|---|---|---|---|---|---|
| pkt_01 | p00_relief · p00i 3196–3265 /3 (laugh_relief t3238) | 1 | 2 | 2 | The neighbour stands and turns his head with a gramophone thought bubble for 36 frames (f0-36), which is dead air, then at f39 he grabs the velvet rope by its post and scowls toward the piano, where the eyes hidden above it sweat (f42-69), and walks away at f69 with no prank landing; the angry face reads (f42-66) but there is no accent, no overshoot and no payoff (unsure what triggers him). | 3 | **FAIL** (Q2-G3) | 1/3/1 |
| pkt_02 | p00_sneeze · p00i 1318–1456 /6 (accent t1375) | 3 | 3 | 3 | He sips tea on a stool (f0-36), scrunches his face (f42), tips his head back (f54), and at f60 a sneeze cloud blasts him backwards so the stool flies (f60-72) and he lands seated in the sink, where he is stuck and dazed with stars (f78-126) before he gets up and searches (f132-138); the head-back wind-up is a fair opposite move and the cloud gives the accent a pop, but nothing shows what caused the sneeze, and his own arm hides his face for most of the hold in the sink, so his reaction does not read. | 4 | **FAIL** (Q2-G1) | 4/4/3 |
| pkt_03 | p00_squeak_bit · p00i 217–331 /6 (first squeak → bit_warmup t230) | 1 | 2 | 1 | Only the striped mime is on screen: she stands by the curtain, gives off a sparkle burst (f24-42), then tiptoes left across the kitchen (f48-114), while the neighbour appears only in the small inset picture by the gramophone; nothing is set up or paid off in the main view. | 3 | **FAIL** (Q2-G4) | 1/3/1 |
| pkt_04 | p00_dizzy_spin · p00i 2560–2767 /9 (accent t2659) | 3 | 4 | 3 | The gramophone starts playing at f18 and makes him jump (f18-36), then he is pulled into a jerky foot-tapping dance, conducting with a baton (f45-90), hits one big arms-wide pose at f99 (a good single overshoot), and holds red-faced and flustered under the notes for over 50 frames (f108-162) before he searches with a magnifier thought (f180-207); it reads well in silhouette, though "music makes him dance" is close to the obvious version. | 4 | **FAIL** (funny 3; Q2-G2) | 3/3/4 |
| pkt_05 | p00_vase · p00i 82–208 /6 (laugh_vase t138) | 2 | 3 | 2 | He sings along to the gramophone with his eyes shut (f0-48) while the blue vase on the mantel shakes, tips (f54-60) and smashes on the floor (f66), and he keeps singing without noticing (f72-90); then the strip cuts to the mime standing idle by the door for 30 frames (f96-126), which is dead air; "singing breaks the vase" is the obvious version, and there is no reaction from him to hold on. | 3 | **FAIL** (Q2-G5) | 1/2/1 |
| pkt_06 | p00_doorframe_bonk · p00i 1624–1750 /6 (laugh_doorframe t1677) | 2 | 3 | 1 | While searching, he walks left pointing ahead (f0-48), hits the doorframe with a white star pop at f60 (raising his arms at f54 is not a wind-up in the opposite direction), clutches his head with dizzy sparkles (f66-90), and his pained face shows only about 12 frames (f96-108) before he walks on (f114-126); walking into a door is the most obvious version, and the camera change between f48 and f54 muddles where he is in the room. | 3 | **FAIL** (Q2-G6) | 2/2/2 |
| pkt_07 | p00_curtain_call · p00i 3577–4267 /30 | 2 | 2 | 2 | This is the end-of-night sequence: the curtain drops over the house (f0-30), the mime bows and roses are thrown (f60-150), the title card shows (f180-210), and on the results screen the grumpy neighbour walks on (f270-510), and a stage pelmet lowers onto his head and leaves him with dizzy stars (f540-690); the mime's bow reads in silhouette, but his bonk is small and the menu covers it. | 3 | **FAIL** (Q2-G7) | 3/3/3 |
| pkt_08 | p00_picture · p00i 3256–3394 /6 (laugh_picture t3273) | 3 | 4 | 3 | He storms off scowling, using the brass rope post as a cane (f0-12), a portrait drops from above (f18) while he looks up nervously (f24), and it lands on his head at f30, where he stands dazed wearing it like a hat with stars and his face showing for about 40 frames (f30-72), then he turns and stomps off (f78-138); the long hold works, but the frame seems to vanish between f84 and f96 instead of falling off (unsure). | 3 | **PASS** | 1/1/1 |
| pkt_09 | g0_sneeze · g0 1090–1228 /6 (accent t1163) | 3 | 3 | 3 | This is the same tea-and-sneeze gag as pkt_02 with better timing: he sips (f0-42), tips his head back (f48), scrunches up (f54), seems to settle for a moment (f60-66), then the sneeze at f72 rockets him backwards on the stool into the sink (f72-90), where he sits stuck with stars (f96-138); the false-calm beat helps, but nothing shows what caused the sneeze, and his raised arm again hides his face during the long hold in the sink, so his reaction reads weakly. | 4 | **FAIL** (Q2-G1) | 4/4/3 |

**Result: 1 of 9 strips at its bar. FAIL.** Means: funny 2.22, readable 2.89, fresh 2.22 (round 1: 2.22 / 2.78 / 2.11).
- **Better:** the picture (1/1/1 → 3/4/3, PASS); the vase (1/2/1 → 2/3/2) and the bonk (2/2/2 → 2/3/1) now read,
  because the cause and the contact are on screen; the dizzy spin is readable 4 (was 3).
- **Worse:** both sneezes (4/4/3 → 3/3/3) and the curtain call (3/3/3 → 2/2/2).
  - Fix round 1 changed neither: r3d-fix-gags §1 lists no sneeze or curtain-call change, and the strips show the same
    beats as round 1's.
  - This drop is reviewer-to-reviewer spread. The sneeze scored 4/4/3 in round 1 and in both D15 rounds.
  - Both of this round's sneeze notes name the same two faults round 1 named ("nothing shows what caused the sneeze";
    "his face is hard to read in the hold"), so the fix is the same either way.
- **What I saw in the frames:**
  - **Sneeze hold** (g0 f96–138, P00 f78–126): his head is bowed. The flipped bouffant covers his eyes and the gold
    jabot covers his mouth, so no face reads (crop: `<SP>/work/r3d-qa/p4/zoom_sink.png`).
  - **Dizzy spin:** at the 9-tick stride the spin aliases. f81 shows only his back, as r3d-fix-gags predicted ("3 turns
    in 0.73 s").
  - **Bonk:** the camera cuts between f48 and f54, 6 f before the accent. At f54 his 3D thought bubble sits under
    "RUNNING GAG ×1", touching the fuse (the orchestrator's QA2 check: confirmed).
  - **Curtain call:** the pelmet comes down slowly, over about 30 f (f540–570), at x ≈ 940, between the gag-reel inset
    and the "Night 1 ▶" button.
  - **Relief:** f0–36 is his static hold before the near miss; his `st_smirk` does not register at strip size.
  - **Squeak bit:** his answer (`bit_warmup`: the high note cracks into a yodel, he clutches his throat) plays only
    inside the Bellows window. The window is enlarged, but it is still about 180 × 100 px.

## R2.5 Requests (round 2: what was misread, which frame, who can fix it)

Per the brief, the re-run is **r3d-integrate, alone**. The "Owner" column names the area whose files change. Round 1's
requests that fix round 1 closed are not repeated: Q-C1, Q-S2, Q-G3 (the picture passes), Q-V2. The rest carry on below
in their round-2 form.

| # | Test · frame | What the reviewer misread | Change requested | Owner (files) |
|---|---|---|---|---|
| **Q2-C1** | crowding pkt_04 (cr_p00_b, P00 ideal t2190, `p00i:730`) | "the loose record x3 icon next to the applause bar … it is unclear which icon goes with which object" | (1) A preview badge stays attached to its prop. When the top-band keep-out would push it more than ~80 px from the prop's anchor, place it beside the prop (left or right) instead, or draw a tail to the prop. (2) **One countdown ring per target:** while his thought shows the same target as a prop's badge, draw the ring once, on the prop's badge, and show his thought as the plain icon (or hide his thought while the badge carries his ring). (3) Hide his awareness glyph + ear pips while his next-activity thought is up. (4) A layout test over the P00 / g0 routes: every badge within N px of its anchor; at most one countdown ring per target on screen. | r3d-hud (`game/ui/world/{overlay_placer,overlay_rules,preview_cloud}.gd`); his bubble: r3d-view3d (`game/view3d/world/overlays_3d.gd`) and `game/view/fx/thought_bubble.gd` (FxThoughtBubble) |
| **Q2-C2** | crowding pkt_07 (cr_n01, N1 ideal t6768, `n01i:394`) | "two thought bubbles with red rings, a glasses icon squeezed onto the wardrobe top, a pot on the mime's head …" | Q2-C1 (2)+(3) remove the second ring and the glyph bubble. Staging: the N1 kitchen pickle-jar shelf sits at Hush's head height on her walk lane, so the jar reads as a hat. Raise the shelf or move the jar off her head line. The frame is an N1 preview, but it counts in the crowding packet. | r3d-hud (as Q2-C1); r3d-sets (`game/data/house/house3d.json` N1 kitchen shelf / jar `visual_offset`) |
| **Q2-G1** | gags pkt_02 + pkt_09 (P00 t1375 / g0 t1163; bar 4/4; scored 3/3/3 both) | "nothing shows what caused the sneeze"; "his own arm hides his face for most of the hold in the sink" | (1) **The sink hold** (g0 f96–138, P00 f78–126): head up and turned to camera for the hold (a D8 gaze window), the flipped bouffant above the brow and not over the eyes, the jabot down, daze eyes + stars readable for ≥ 30 f. (2) **Show the cause** in the build-up (f0–54): pepper motes falling from the rigged pot into his cup, or a pepper puff at his nose on the "ah". (3) Process: the same clip scored 4/4/3 three times before. For the next row-19 run, the lead may want ≥ 3 reviewers per gag packet with medians (the verdict format already allows them). | r3d-anim-bellows-a (`rx_sneeze_blast_a` dazed-hold pose / sidecar gaze; timing locked, R3) with r3d-rig (gaze); r3d-view3d (`game/view3d/camera/gag_stager_3d.gd`, `fx_3d.gd` pepper motes) |
| **Q2-G2** | gags pkt_04 (p00_dizzy_spin, accent t2659; 3/4/3, bar funny 4) | readable now 4; "'music makes him dance' is close to the obvious version" | r3d-fix-gags' named next lever: a slower 2-turn spin inside the same 36–80 f window, arms out and the bouffant trailing, so he is visibly *spun by the record*, not dancing. A fresher button: his spiral glasses match the record label; on the stop he nearly topples into the piano. For the packet: shoot this window every 6 ticks, not 9, so the spin does not alias. | r3d-anim-bellows-c (`rx_dizzy_spin_a` re-pose + bake within its locked length); r3d-view3d (`fx_3d.gd` spin_lines); r3d-qa (packet stride) |
| **Q2-G3** | gags pkt_01 (p00_relief, laugh_relief t3238; 1/2/2) | "no accent, no overshoot and no payoff (unsure what triggers him)"; f0–36 "dead air" | The near miss now reads (eyes sweat over the piano, f42–69). The beat needs a shape: (1) an accent, a double take toward the eyes with his face to camera (4 f), and a hold of ≥ 30 f where he almost sees her; (2) the turn away; (3) **her** payoff: the eyes squeeze shut and a "phew" puff rises from the piano top as he leaves. The laugh lands on the puff, not on his walk-off. Start the shot at the double take, not on his hold. | r3d-view3d / r3d-fix-gags (`cue_stager_3d.gd` near-miss staging, `game/view3d/set/hide_spot_3d.gd` relief puff); r3d-anim-bellows-b (`st_double_take` aimed at the gap) |
| **Q2-G4** | gags pkt_03 (p00_squeak_bit, t230; 1/2/1); verb Q-V1 | "nothing is set up or paid off in the main view"; he is "only in the small inset" | His answer must be on the main screen. Cut to him for `bit_warmup`'s 90 f (a cue shot like the vase's), or escalate the window to ≥ ⅓ of the screen for that beat. Give the crack a visible glyph (a broken note), and show the throat clutch with his face to camera. Clarence bigger on the squeeze (Q-G5 (3) carries). | r3d-view3d (`camera_director_3d.gd`, `cue_stager_3d.gd`); r3d-anim-bellows-b (`bit_warmup` face / gaze); r3d-anim (`act_squeak`) |
| **Q2-G5** | gags pkt_05 (p00_vase, t138; 2/3/2) | "'singing breaks the vase' is the obvious version, and there is no reaction from him to hold on"; then f96–126 "dead air" on Hush | Give him a reaction he can hold, with his face to camera for ≥ 30 f. For example, the smash lands on his top note like a cymbal: he opens one eye and takes a smug bow. That keeps the "he never notices" joke and adds a button. Hold the cue shot on him until it ends, then cut to her climb-in. A view-side overlay clip does not touch the sim's timing (laugh_vase is a director cue). | r3d-view3d (`cue_stager_3d.gd` hold); r3d-anim-bellows-b (an overlay emote clip in the warm-up) |
| **Q2-G6** | gags pkt_06 (p00_doorframe_bonk, t1677; 2/3/1) | "raising his arms at f54 is not a wind-up in the opposite direction"; "the camera change between f48 and f54 muddles where he is"; pained face "only about 12 frames"; "the most obvious version" | (1) No camera cut within 30 f of the accent: punch in earlier, or after the hit. (2) An opposite anticipation: he leans back and pulls the stick back, then the head-first hit with a ≤ 4 f smear and one recoil overshoot. (3) His dazed face to camera ≥ 30 f. (4) Fresher: the bonk tips the hall portrait askew, so the later picture gag (t3273) pays it off as a callback. (5) His 3D thought bubble at f54 touches the RUNNING GAG fuse: clamp it out of `Hud.transient_rects()` + 24 px and quiet it from the cue frame (t1677), as phase 1 requested. | r3d-view3d / r3d-fix-gags (`cue_stager_3d.gd`, `overlays_3d.gd`); r3d-anim-bellows-c (`cue_doorframe_bonk` anticipation); r3d-sets (portrait tilt) |
| **Q2-G7** | gags pkt_07 (p00_curtain_call; 2/2/2, was 3/3/3) | "his bonk is small and the menu covers it" | Stage his walk-on and the pelmet drop centre-left (x 300–650), clear of the gag-reel inset and the buttons. A fast drop (accent ≤ 4 f) with stars, then his face to camera ≥ 30 f. Known edges carry: the title sign covers Hush for its 1.2 s hold, and the gag-reel inset prints its pun captions under `--no-captions`. | r3d-night (`game/scenes/night/curtain_call.gd`); r3d-hud (results card layout); r3d-anim-bellows-c |
| Q2-G8 *(passed, note)* | gags pkt_08 (p00_picture, t3273; 3/4/3) | "the frame seems to vanish between f84 and f96 instead of falling off" | Let the frame slide off his head, or have him lift it off, instead of popping out. | r3d-view3d (`cue_stager_3d.gd` picture return) |
| Q2-S1 *(at the bar)* | spot pkt_03 (sp_pickle, N1 calm t360) | the jar read as "the green polka-dot vase … tip or fall onto his head"; the redrawn pictogram was not read | The shelf prop must read as a pickle jar: glass, pickles inside, a lid. Today it is a green polka-dot pot. Put the bubble within ~60 px of the jar, with a tail. Apply the one-loud rule to the five preview bubbles N1 shows at once (an integrate note since K3). N1 is a preview, so this can wait for R3 unless the spot test is re-run. | r3d-sets (N1 pickle-jar prop); r3d-hud (`overlay_rules.gd`) |
| Q2-S2 *(at the bar)* | spot pkt_01 (sp_needs, N1 ≈ t5219) | "rigged with a honking horn … blasts a loud honk that startles him" | `kettle_drum` pictogram: show him singing along with the kettle (his open mouth + notes from both), so the duet is the joke. Make the "needs the squeaker" state read as missing (an empty slot with a "+" or "?"), not as part of the rig. R3 unless re-run. | r3d-hud (`game/art/ui/previews/`) |

**After the fixes:** re-shoot the failing frames and strips from the same ticks (the dizzy spin every 6 ticks). Then
run **new** fresh reviewers on rebuilt crowding and gag packets with new seeds, ideally three per packet, scored by
median. Re-run pre-gate row 19.

# Round 3 — QA round 3 (2026-10-02, the fix-round-2 tree): spot, crowding and gags, 3 fresh reviewers per packet (D18.1)

Phase 1 of round 3 rebuilt the spot, crowding and gag packets from 74967b5 + fix round 2 (= 446a69b by content; new
seeds 131 / 137 / 149, new keys `keys/r3_*_key.json`): [`packets/set_i`](packets/set_i/prompt.md) (spot, 8 frames),
[`packets/set_j`](packets/set_j/prompt.md) (crowding, 8 frames), [`packets/set_k`](packets/set_k/prompt.md) (gags,
9 strips; the dizzy spin every 6 ticks). How they were run: [`reviewer_prompts.md`](reviewer_prompts.md) "Round 3".
**Nine new fresh reviewers** answered them, three per packet; none had seen an earlier packet, the game or another
reviewer's answer. The orchestrator ran them and handed over the answers, pasted below verbatim, per reviewer.
Rounds 1 and 2 (above) are kept as they were.

**Verdict: FAIL.** The gags miss their bar: **3 of 9** strips at their bar (round 2: 1 of 9). Spot and crowding now
pass, and the verb and 2D-vs-3D results carry from round 1.

| Test | Packet | Round 3 (D18.1, 3 reviewers) | Round 2 (1 reviewer) | Bar | Pass? |
|---|---|---|---|---|---|
| Verb: what is Hush doing | `packets/set_a/` (not rebuilt) | — (round 1 stands) | — | ≥ 7/8 | PASS (carried, 7/8) |
| Spot: what happens if he uses it | `packets/set_i/` (8 frames, seed 131) | counts 7, 6, 7 → **median 7/8** | 6/8 | median ≥ 6/8 | **PASS** |
| Crowding: is the screen crowded | `packets/set_j/` (8 frames, seed 137) | **1/8** frames with ≥ 2 of 3 "yes" | 2/8 | ≤ 1/8 | **PASS** (at the bar) |
| 2D vs 3D: which would you rather play | `packets/set_d/` (not rebuilt) | — (round 1 stands) | — | ≥ 6/8 | PASS (carried, 8/8) |
| Gags: funny / readable / fresh, 1–5 | `packets/set_k/` (9 strips, seed 149) | **3 of 9** at their bar (medians) | 1 of 9 | sneezes + dizzy spin ≥ 4/4; the rest ≥ 3/3; fresh ≥ 3 | **FAIL** |

| Gag (median funny / readable / fresh) | Round 3 | Round 2 | Round 1 | Bar | Verdict |
|---|---|---|---|---|---|
| g0 sneeze | **4/4/3** | 3/3/3 | 4/4/3 | 4/4/3 | **PASS** |
| P00 sneeze | **4/4/3** | 3/3/3 | 4/4/3 | 4/4/3 | **PASS** |
| curtain call | **3/3/3** | 2/2/2 | 3/3/3 | 3/3/3 | **PASS** |
| dizzy spin | 3/3/3 | 3/4/3 | 3/3/4 | 4/4/3 | FAIL (funny, readable) |
| picture | 3/3/2 | 3/4/3 | 1/1/1 | 3/3/3 | FAIL (fresh) |
| door-frame bonk | 3/3/2 | 2/3/1 | 2/2/2 | 3/3/3 | FAIL (fresh) |
| vase | 2/3/2 | 2/3/2 | 1/2/1 | 3/3/3 | FAIL |
| squeak bit | 1/2/1 | 1/2/1 | 1/3/1 | 3/3/3 | FAIL |
| relief | 1/2/1 | 1/2/2 | 1/3/1 | 3/3/3 | FAIL |

## R3 verdict lines (read by `tools/scripts/pregate3d.sh` row 19)

Row 19 reads every `verdict` line in this file, and for each test the **last** line wins, so these lines replace
rounds 1–2's. Spot is the median of the three reviewers' counts, crowding counts a frame only when ≥ 2 of 3 said
"yes", and each gag score is the median of the three (D18.1). Verb and 2D-vs-3D repeat round 1 unchanged.

```
verdict verb 7/8
verdict spot 7/8
verdict crowded_yes 1/8
verdict prefer_3d 8/8
verdict gag g0_sneeze funny=4 readable=4 fresh=3
verdict gag p00_sneeze funny=4 readable=4 fresh=3
verdict gag p00_dizzy_spin funny=3 readable=3 fresh=3
verdict gag p00_curtain_call funny=3 readable=3 fresh=3
verdict gag p00_picture funny=3 readable=3 fresh=2
verdict gag p00_doorframe_bonk funny=3 readable=3 fresh=2
verdict gag p00_vase funny=2 readable=3 fresh=2
verdict gag p00_squeak_bit funny=1 readable=2 fresh=1
verdict gag p00_relief funny=1 readable=2 fresh=1
```

## R3.1 How it was scored
1. The nine answer sheets were saved verbatim to `<SP>/work/r3d-qa/p5/answers/{spot,crowding,gags}_r{1,2,3}.md`.
2. Each sheet was scored on its own: `python3 tools/art3d/review/packets.py score <SP>/work/r3d-qa/keys/r3_<packet>_key.json
   <answers> --out=… --json=…` (`--bar=3` for the gags) → `<SP>/work/r3d-qa/p5/verdict_<packet>_r<n>.{md,json}`.
3. Every spot row was then judged by hand on the gist, with round 1–2's standard (a horn = the squeaker; "a tune" =
   the kettle duet, weakly; the joke counts, the "needs the squeaker" state is noted, not required). I looked at every
   packet image and every strip page (29 pages). The hand verdict decides.
4. Matcher vs hand: the matcher left the pickle jar `unmatched` on all three sheets and reviewer 2's honey `unmatched`;
   all four are wrong on the gist. Every other row agrees (spot matcher 7 / 6 / 7 = the hand counts).
5. Combined per D18.1 by `<SP>/work/r3d-qa/p5/gen_r3.py` (the tables below; `r3_result.json`).

Frame tags: `g0:n`, `p00i:n` = frame n of the every-3-tick sequence (tick ≈ 3n); `n01i:n` = every 6 ticks from engine
frame 4404 (tick ≈ 4404 + 6n); `calm_<t>` = a paused shot at tick t on the crafted N1 calm route; `needs:n` ≈ 5105 + 3n.
## R3.2 Spot — `packets/set_i/` (pass: the median of the 3 counts ≥ 6/8)

Question (as rounds 1–2): *"What will happen if the neighbour uses the object inside the cyan circle? Give the gist of the joke in a few words. (If the circled thing is a box or cupboard, say what is in it.)"*

| id | Key (item · expected · gist · source) | Reviewer 1 (verbatim) | Reviewer 2 (verbatim) | Reviewer 3 (verbatim) | Gist verdict (R1 · R2 · R3) |
|---|---|---|---|---|---|
| pkt_01 | sp_box · squeaker · "the box holds the squeaker (a squeaky horn toy) she can take" · `n01i:22` (≈ t4536) | The box holds a bike horn, so it honks loudly in his face when he opens it. | the box holds a clown bulb horn, so it HONKS loudly when he opens it (unsure) | The box holds an air horn that blasts him when he opens it (unsure) | right: a horn in the box (matcher: correct) · right (matcher: correct) · right: a horn (matcher: correct). All three name a horn in the taped box (round 1's standard: the squeaker is a squeaky horn toy; the honk-in-his-face is the reviewers' own addition). |
| pkt_02 | sp_recliner · chair launch · "the recliner launches him up to the ceiling (reads the paper in orbit)" · `n01i:418` (≈ t6912) | The armchair is spring-loaded and launches him up into the chandelier when he sits. | a spring in the armchair shoots him up into the chandelier when he sits down | The armchair has a spring under the cushion, so sitting down launches him up into the chandelier | right (matcher: correct) · right (matcher: correct) · right (matcher: correct) |
| pkt_03 | sp_gramophone · dizzy spin · "the record spins him round until he is dizzy (the gramophone goes haywire) (his red countdown ring is on its preview)" · `p00i:756` (≈ t2268) | The gramophone record skips and loops over and over, leaving him dizzy (unsure). | the gramophone plays the record at triple speed and the frantic music makes him dizzy (unsure) | The gramophone record is rigged to skip and loop on a dizzying spin (unsure) | right: dizzy (matcher: correct) · right: dizzy (matcher: correct) · right: a dizzying spin (matcher: correct). Round 3's gramophone badge sits on its prop with a tail (Q2-C1), and the record + ×3 still reads as speed → dizzy. |
| pkt_04 | sp_pickle · jar fight · "he fights the jar: it will not open and he strains and slips (loses a fight with a jar)" · N1 `calm_360` | The jar is full of spring snakes, which pop out at him when he opens it (unsure). | a fake spring snake jumps out of the jar when he opens it (unsure) | A spring snake pops out of the jar when he opens it (unsure) | **wrong**: spring snakes (matcher: unmatched) · **wrong**: a spring snake (matcher: unmatched) · **wrong**: a spring snake (matcher: unmatched). **The jar now reads as a jar** for all three (round 1: "tea jar", round 2: "vase"), but the two fat green gherkins of the redrawn `in_a_pickle` pictogram read as **spring snakes** (3/3), and the strain/twist arrow did not read. The prop on the shelf is still the green polka-dot pot (Q2-S1's prop half is open). |
| pkt_05 | sp_honey · sneeze · "he gets a face full of pepper and sneezes (the pepper pot / honey pot rigged)" · `g0:30` (≈ t90) | The spice or pepper on the shelf is rigged, so he turns red and sneezes or puffs steam (unsure). | the jar's sugar is swapped for hot chili, so he puffs steam from the heat (unsure) | The spice or pepper on the shelf is swapped, so he sneezes or gets a burning puff (unsure) | right: sneezes (matcher: correct) · **wrong**: hot chili, steam (round 1's misread) (matcher: unmatched) · right: sneezes (matcher: correct). Two of three read the sneeze; one repeats round 1's "hot chilli" misread (the red-striped pot reads as a spice jar, the CHOO puff as steam). |
| pkt_06 | sp_tap · face wash · "the tap sprays water in his face (a face wash)" · N1 `calm_150` | The tap sprays water straight into his face. | the tap sprays water straight into his face | The tap sprays water straight into his face | right (matcher: correct) · right (matcher: correct) · right (matcher: correct) |
| pkt_07 | sp_kettle · kettle duet · "the kettle sings / plays music along with him (a duet with the kettle)" · N1 `calm_520` | The kettle blasts a loud whistling tune and he covers his ears. | the kettle whistles a loud tune and startles him over his tea (unsure) | The kettle whistles a loud tune and startles him (unsure) | right, weakly: a tune (the duet not named) (matcher: correct) · right, weakly: a tune (matcher: correct) · right, weakly: a tune (matcher: correct). "A whistling tune" names the music (round 2's standard); none names his singing along; "startles him" / "covers his ears" is a different joke. |
| pkt_08 | sp_needs · kettle duet · "the kettle sings a duet with him - the dimmed preview + the grey squeaker silhouette say she must fetch the squeaker first (his red ring: he is coming for tea next)" · `needs:38` (≈ t5219) | The kettle blasts a loud whistling tune and he covers his ears; the "?" badge suggests it still needs an item (unsure). | the kettle whistles a loud tune and startles him over his tea; this rig seems to still need an extra item (unsure) | The kettle whistles a loud tune and startles him (unsure) | right: a tune + **the need read** (matcher: correct) · right: a tune + **the need read** (matcher: correct) · right, weakly: a tune (the need not named) (matcher: correct). **Round 2's honk misread is gone**: the redrawn `kettle_drum` reads as a tune, and the dashed "?" slot reads as "still needs an item" for 2 of 3 (Q2-S2). |

**Counts: reviewer 1 7/8, reviewer 2 6/8, reviewer 3 7/8 → median 7/8. PASS** (round 2: 6/8; round 1: 6/8).

## R3.3 Crowding — `packets/set_j/` (pass: ≤ 1/8 frames with ≥ 2 of 3 "yes")

Question (as rounds 1–2): *"Is this screen crowded or confusing? Answer yes or no, then one sentence why."* The key expects "no" for every frame.

| id | Key (item · source) | Reviewer 1 (verbatim) | Reviewer 2 (verbatim) | Reviewer 3 (verbatim) | yes | Counts? | Notes |
|---|---|---|---|---|---|---|---|
| pkt_01 | cr_p00_b · `p00i:730` (≈ t2190) | no — the layout is readable, but two gramophone-related bubbles and two outlined objects (gramophone and piano) make it a little unclear which one to use (unsure). | no — The busiest parts are the HUD bar, the thought bubble over the old man and the red-ringed record bubble over the gramophone, but each one is clearly separate and the room has plenty of space between things. | no — It's busy, with the score bar, two thought bubbles, outlined props and a floor marker all showing, but each element has its own space and the bubble by the gramophone clearly points to the next target (unsure). | 0/3 | no | **Fixed** (round 2: "yes"): the gramophone's badge sits on the gramophone with a tail, one ring. R1 and R3 still note two gramophone bubbles (his thought + the badge). |
| pkt_02 | cr_p00_c · `p00i:891` (≈ t2673) | no — one character fills the center and the music notes clearly show the gag, though the thick clump of small notes on his wig looks messy. | no — This is a close-up reaction shot of one character, and the pile of music notes around his head is messy but still reads as a single obvious joke. | no — The old man is clearly the focus, though the pile of music notes around his head is dense and a bit messy. | 0/3 | no | All three: the clump of notes on his wig is messy. |
| pkt_03 | cr_g0_plan · `g0:30` (≈ t90) | no — the room is clean and the path is clear, but the thought bubble and pointing hand above the shelf are too small to read at phone size, and the inset in the top-right corner pulls attention away (unsure). | no — The scene is clean with one character, a highlighted cabinet and a small inset view, though the pointing-hand thought bubble above the shelf is a little unclear about what it wants. | no — The scene is clean with one character walking toward a marked spot, though the small hint bubble with the pointing hand above the shelf is hard to read at a glance. | 0/3 | no | All three: the pointing-hand hint above the shelf is small / unclear at phone size. |
| pkt_04 | cr_p00_d · `p00i:568` (≈ t1704) | no — the dazed character is the clear focus, with only the score bar, two buttons and a quiet row of audience silhouettes around him. | no — The dazed old man is clearly the main subject, and the eyes peeking from the curtain and the audience silhouettes along the bottom stay in the background. | no — One dazed character sits in the center with the score bar and audience silhouettes kept to the edges, so it reads easily. | 0/3 | no |  |
| pkt_05 | cr_g0_sneeze · `g0:118` (≈ t354) | no — the scene is sparse and easy to follow, with the hidden eyes, the falling item and the inset each showing one thing. | no — The room is mostly empty, with just the peeking eyes, a small inset view and a few buttons, so it is easy to read. | no — The screen is sparse and calm with eyes peeking from the curtain and an inset view, though the small red object falling from the shelf is easy to miss (unsure). | 0/3 | no |  |
| pkt_06 | cr_p00_a · `p00i:463` (≈ t1389) | no — the slapstick fall reads clearly, though the shelf debris and smoke cloud crowd the top-left status pill. | no — This chaotic action frame still has one clear focus (the old man falling off the stool), though the falling shelf items brush against the top-left HUD pill (unsure). | no — The big moment of the man flying off the stool is clear, though the debris falling from the shelf overlaps the top-left counter. | 0/3 | no | All three: the shelf debris overlaps the top-left Script pill. |
| pkt_07 | cr_n01 · `n01i:394` (≈ t6768) | yes — two thought bubbles (one ringed bubble packed with tiny icons), an outlined booth, a floor target, a longer status bar and three bottom buttons all compete, so it is hard to tell what to do first (unsure). | yes — Two thought bubbles compete for attention, the red-ringed one packs music notes, a kettle and a face into one small icon, and the highlighted kettle, highlighted curtain, two characters, a dotted progress pill and three buttons all show up together. | no — This is the busiest frame, with two thought bubbles, a highlighted closet, a floor marker and three buttons, but they are spread apart; the red bubble that combines three tiny icons is the hardest part to read (unsure). | 2/3 | **yes** | **Counts as crowded (2 of 3).** The second red ring is gone (Q2-C1), but two thought bubbles remain for one target (the kettle's badge with his ring + his own tea thought), and the new duet pictogram packs notes + kettle + face into one ~80 px bubble. |
| pkt_08 | cr_g0_rig · `g0:64` (≈ t192) | no — the reach-for-the-teapot action and its progress rings are obvious, and the rest of the screen stays calm. | no — The mime reaching the shelf, with matching green progress rings on the object and the action button, is easy to follow, and the rest of the screen is uncluttered. | no — The mime reaching for the jar has matching progress rings on the object and the action button, so it is clear what is happening. | 0/3 | no |  |

**Result: 1/8 frames count as crowded. PASS, at the bar** (round 2: 2/8; round 1: 2/8). Per reviewer: 1, 1 and 0 "yes".

## R3.4 Gag strips — `packets/set_k/` (9 strips, TECH §11 rubric in the prompt; the median per score)

Bars: the sneezes (`g0_sneeze`, `p00_sneeze`) and `p00_dizzy_spin` need funny ≥ 4 and readable ≥ 4; every other strip needs ≥ 3 on both; fresh ≥ 3 for all. Question: *"For each strip: what happens, in one sentence? Then score it 1-5 on funny, readable (can you tell what happens and why, at this size, without sound?) and fresh (not the obvious version of the joke)."* Each window is `[sequence, t0, t1, stride]` (ticks), the same moments as rounds 1–2; the dizzy spin is now shot every 6 ticks (was 9).

### pkt_01 · `p00_relief` · p00i 3196–3265 every 3

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 1 | 2 | 2 | funny=1 readable=2 fresh=2 — Eyes peek over the piano and duck (f0-3), the neighbour snaps into a stiff arms-straight-out pose with his mouth open and holds it for 30 frames (f9-39), which reads like a broken T-pose rather than a startle, then sweat pops over the piano (f42) and he turns and walk-cycles left without really moving (f45-69); there is no wind-up, no accent and no clear gag. |
| 2 | 1 | 1 | 1 | funny=1 readable=1 fresh=1 — With the prankster's eyes peeking over the piano (f0), the neighbour gives a small startled "o" (f6), then locks into a stiff arms-out T-pose held unchanged from f9 to f39 with his cravat covering his mouth so his face never reads, flinches with sweat drops (f42), and turns to walk in place against the doorframe from f45 to f69 while white puffs stack above the piano, so no prank or payoff is readable (unsure what was rigged). |
| 3 | 1 | 2 | 1 | funny=1 readable=2 fresh=1 — With the prankster's eyes peeking over the piano (f0), he snaps into a stiff arms-out T-pose with a blank face and holds it about 30 frames (f9-f39), which looks like a missing animation rather than a reaction; then sweat drops pop over the piano (f42), he turns (f45) and walks off left while barely moving across the floor, so his feet seem to slide (f48-f69, unsure), and no prank lands. |

**Median 1/2/1** (bar 3/3, fresh 3) → **FAIL** (funny 1 < 3, readable 2 < 3, fresh 1 < 3). Round 2: 1/2/2; round 1: 1/3/1. All three: his double-take pose is a stiff **arms-straight-out T-pose** held f9–39 with a blank face (`st_double_take`'s take pose; also seen at the curtain call f360). Two of three: he then walks in place (feet slide, f45–69). The "phew" puffs over the piano read as "sweat" / "white puffs", not relief. The gramophone horn behind him reads as a hat at f12–39.

### pkt_02 · `p00_squeak_bit` · p00i 217–331 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 1 | 2 | 1 | funny=1 readable=2 fresh=1 — The prankster makes a small gesture in the kitchen (f0-18, +2), then the camera cuts to the neighbour, who reaches up at the gramophone (f24-36), startles once (f42), fiddles with something at his chest while a few notes come out (f48-78, unsure), conducts (f84-96) and thinks of tea (f102) as the camera pans back to her (f108-114); no prank lands and no face hold earns anything. |
| 2 | 2 | 3 | 2 | funny=2 readable=3 fresh=2 — A setup with no payoff: the mime loiters in the kitchen under a hint card (f0-f18) while the neighbour stretches by the gramophone (f24-f36), startles (f42), fiddles with something yellow at his chest (f48-f60, unsure whether it is a duck), sways eyes-closed as notes rise (f66-f78), conducts (f84-f96), switches his thought bubble to tea (f102) and heads for the kitchen as the mime sneaks off (f108-f114). |
| 3 | 1 | 2 | 1 | funny=1 readable=2 fresh=1 — The mime tiptoes around the bathroom (f0-f18, small +2 at f12), the camera cuts to the neighbour stretching, fiddling with a small object that gives off notes and conducting by the gramophone (f24-f102) while his thought bubble changes from gramophone to tea (f102), then it cuts back to the mime (f108-f114); nothing happens to him, so there is no gag to read. |

**Median 1/2/1** (bar 3/3, fresh 3) → **FAIL** (funny 1 < 3, readable 2 < 3, fresh 1 < 3). Round 2: 1/2/1; round 1: 1/3/1. His answer is now on the main screen (Q2-G4's cue shot), but nothing links it to her squeak: R1 "no prank lands", R3 "nothing happens to him"; his throat clutch reads as "fiddling with something at his chest" (R2: "something yellow … a duck"). The crack has no visible glyph.

### pkt_03 · `g0_sneeze` · g0 1090–1228 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — He sips tea on a stool while a pepper shaker on the shelf showers him (f0-66), tips his head back with eyes squeezed to wind up (f48-66), then a sneeze with a big white puff launches him and the stool backwards across the room (f72-84) onto the sink by the door (f90), where he sits dazed with stars for over 40 frames (f96-138) while his cup rolls across the floor (f102-138); the silhouette and the hold read well, but the pepper build is long and the pepper sneeze itself is the obvious joke, saved by the stool-rocket and sink landing. |
| 2 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — While he sips tea on a stool, pepper sprinkles from the shelf onto his face (f6-f42), he winds up an inhale with his head thrown back and eyes squinting (f48-f66), then a puff-cloud sneeze (f72) rockets him and the stool backwards across the room (f78-f84) into the sink (f90), where he sits dazed under circling stars for a strong 40+ frame face hold (f96-f138) as the teacup clatters down (f102-f138); the slow pepper build is the only drag. |
| 3 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — Sipping tea on a stool under a shaker that sprinkles pepper on him (f0-f42), he tips his head back and squints in a clear opposite wind-up (f48-f66), then sneezes with a big white puff that launches him and the stool across the kitchen (f72-f84) into the sink (f90), and sits dazed with stars while his teacup lands on the floor (f96-f138, a readable 40+ frame hold); the silhouette is strong and the launch beats the plain sneeze, but the pepper build is slow, the stool stays stuck to his feet in the air, the right edge of the frame crops him, and it ends with no button. |

**Median 4/4/3** (bar 4/4, fresh 3) → **PASS**. Round 2: 3/3/3; round 1: 4/4/3. **Passes, 4/4/3 from all three** (round 2: 3/3/3). Q2-G1 landed: the pepper falling is seen by all three, and the dazed hold in the sink reads ("a readable 40+ frame hold"). Notes: the pepper build is slow; the stool stays stuck to his feet in the air; "ends with no button".

### pkt_04 · `p00_picture` · p00i 3256–3394 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — A picture frame drops off the wall onto his head (f18-30) and he stands dazed wearing it like a portrait of himself (f36-66, a good 30-frame face hold), grumbles while stomping without travelling (f72-90; the stanchion and mirror stay put, so it looks like a treadmill), then the frame slowly slides off (f96-114) and he stays furious (f114-138); the late slide-off is a nice second beat, but it is unclear who rigged it or why. |
| 2 | 3 | 3 | 2 | funny=3 readable=3 fresh=2 — After walking in place against the doorframe (f0-f12, feet stepping but not moving), the portrait above the door drops (f18) and lands on his head like a hat (f24), he wobbles dazed under stars wearing it (f30-f66), turns grumpy (f72-f90), and lets it slide off to the floor (f96-f114) while glaring at camera for a readable hold (f96-f132) before stomping off (f138); it's the obvious picture-falls-on-head joke. |
| 3 | 2 | 3 | 2 | funny=2 readable=3 fresh=2 — As he walks off left (f0-f12) the shot jumps and a picture frame swings down onto his head (f18-f30), he stands dazed with sparkles (f36-f66, a readable hold), turns angry (f72-f90), and the frame slides off and falls to the floor (f96-f114) while he fumes (f114-f138); it is clear, but it is the stock thing-falls-on-head gag, the hit has no squash or pop (f30), and the white cloud stack over the piano (f0-f60) is never explained. |

**Median 3/3/2** (bar 3/3, fresh 3) → **FAIL** (fresh 2 < 3). Round 2: 3/4/3; round 1: 1/1/1. Readable 3 from all; **fails on fresh** (median 2): "the stock thing-falls-on-head gag". R1 liked "wearing it like a portrait of himself" and the late slide-off (Q2-G8 landed). R1 and R3: he stomps without travelling ("a treadmill"); R3: no squash or pop at the hit (f30); the white puff stack over the piano (from the relief) is "never explained".

### pkt_05 · `p00_vase` · p00i 82–208 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 2 | 3 | 2 | funny=2 readable=3 fresh=2 — He belts along to the gramophone (f0-36) while a vase on the far mantel wobbles (f0-54), topples (f60) and smashes (f66) and he keeps conducting (f72-126), with only one wide-eyed glance at f90 and no 30-frame reaction hold; the vase is small and far from him at phone size, and "singing breaks the vase" is the expected version. |
| 2 | 2 | 3 | 2 | funny=2 readable=3 fresh=2 — He belts opera next to the gramophone, and his stream of notes rattles a blue vase on the mantel (f0-f54) until it tips (f60) and shatters on the hearth (f66-f96), while he stays eyes-closed and oblivious apart from one brief wide-eyed beat (f90) and keeps conducting (f96-f126); it's the stock voice-breaks-glass gag, the shards are tiny at this size, and his face never reacts. |
| 3 | 2 | 2 | 2 | funny=2 readable=2 fresh=2 — He sings at the gramophone (f0-f36) and his drifting notes rock the vase on the mantel until it falls and smashes by the fireplace (f42-f72), but he keeps conducting with only a quick wide-eyed glance (f90) and no 30-frame face hold, and the vase is tiny and far from him, so at phone size the payoff is easy to miss; it is the stock voice-breaks-china joke. |

**Median 2/3/2** (bar 3/3, fresh 3) → **FAIL** (funny 2 < 3, fresh 2 < 3). Round 2: 2/3/2; round 1: 1/2/1. Unchanged at 2/3/2: the crash reads, but **his reaction does not** — all three see "only a quick wide-eyed glance (f90), no 30-frame face hold"; Q2-G5's push-in + `st_straighten_cravat` "ovation" did not register. The vase is "tiny and far from him" at phone size. "Voice breaks the vase" is the stock version.

### pkt_06 · `p00_doorframe_bonk` · p00i 1624–1750 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 3 | 3 | 2 | funny=3 readable=3 fresh=2 — He shuffles along conducting with his eyes shut (f24-48), rears back with his arm up (f54, a good opposing wind-up) and bonks the doorframe with a short star pop (f60), stays dazed with wobbly eyes for about 40 frames (f66-108), then carries on (f114-126); it reads as a clean pratfall, but nothing shows what the prankster in the curtain did, and a white oval drifts along with his feet the whole strip (f0-126, unclear what it is). |
| 2 | 3 | 4 | 2 | funny=3 readable=4 fresh=2 — Conducting eyes-closed as he walks left through the kitchen (f0-f48), he rears back (f54) and smacks his head on the doorframe with a clear white impact star (f60), staggers with spiral glasses, stars and a wobbly mouth for a good face hold (f66-f108), then carries on through the door still waving the baton (f114-f126); clean, but it's the obvious walk-into-the-door version. |
| 3 | 2 | 3 | 1 | funny=2 readable=3 fresh=1 — Walking left pointing his baton (f0-f18), he turns to camera mid-yawn (f24-f42), looks up startled (f54) and bonks his head on the wall corner with an impact star (f60), then wobbles dazed with stars and a wavy mouth (f66-f108, a good readable hold) before walking on (f114-f126); it reads, but it is the plain walk-into-the-doorframe gag, the look-up at f54 is not a real opposite wind-up, and applause stays at 37 throughout. |

**Median 3/3/2** (bar 3/3, fresh 3) → **FAIL** (fresh 2 < 3). Round 2: 2/3/1; round 1: 2/2/2. Readable 3–4, **fails on fresh** (median 2): "the plain walk-into-the-doorframe gag". Q2-G6 landed (no cut, a face hold of ~40 f); the f54 wind-up reads for R1 only. The portrait tilt it sets up is outside the strip. R1: a white oval drifts by his feet the whole strip (by my look: the sneeze's dropped teacup on the floor).

### pkt_07 · `p00_dizzy_spin` · p00i 2560–2767 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — With eyes peeking from behind the piano, he cranks the gramophone (f12-42) and dances wildly to the stream of notes (f48-90), then at f96 (+52) heavy dark notes land on him and he slumps red-faced with notes circling his head like dizzy stars (f102-162, a long face hold), grits his teeth (f174), turns suspicious (f180) and leans in nose-to-nose with the hidden eyes (f192-204); notes in place of stars is a fresh twist, but the cause of the switch and whether the red face means dizzy or angry are unclear, and the strip runs long. |
| 2 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — With the prankster's eyes peeking from behind the piano, he leans in to inspect the gramophone (f12) and it blasts a geyser of notes (f18-f42) that drags him into a jerky dance and twirl (f48-f96), leaving him squatting red-faced and dizzy with notes orbiting his head (f102-f162) before he recovers, grits his teeth (f174) and searches nose to nose with the hidden eyes (f186-f204); the ending is nice, but at about 200 frames the strip runs long. |
| 3 | 3 | 3 | 4 | funny=3 readable=3 fresh=4 — He tinkers with the gramophone (f0-f12), bursts of notes (f18-f42) whip him into a frantic dance with notes swirling at his feet (f48-f90), then he slumps flushed and dizzy with music notes circling his head instead of stars (f102-f162, a long readable hold), straightens up grimacing (f168-f174) and shuffles off with a suspicious bubble (f180-f204); the notes-as-stars is a nice twist, but without sound it is unclear why the music makes him dance, and the hold runs long. |

**Median 3/3/3** (bar 4/4, fresh 3) → **FAIL** (funny 3 < 4, readable 3 < 4). Round 2: 3/4/3; round 1: 3/3/4. 3/3/3 (bar 4/4). The 2-turn spin (Q2-G2) now shows, but it reads as **a wild dance**: "unclear why the music makes him dance" (R3), "whether the red face means dizzy or angry" (R1). Liked: notes circling his head instead of stars (R1, R3), the nose-to-nose end with the hidden eyes (R1, R2). All: the hold runs long (~60 f).

### pkt_08 · `p00_curtain_call` · p00i 3577–4267 every 30

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — The curtain drops (f30), the prankster bows under thrown roses (f60-150) beside the title sign (f150-210), then on the results screen the neighbour stomps on (f270-330), flings his arms out stiffly (f360, the same T-pose look as pkt_01), sulks red-faced (f390-480) and gets bonked by the falling pelmet (f480-510, stars), then glowers under it for a long hold (f540-690); having the stage itself prank him at his own curtain call is a good button, but the replay window and text compete with him, the 30-frame spacing hides the accent, and the pelmet hovers just above his head afterwards. |
| 2 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — On the end screen the curtain drops (f30), the mime bows under thrown roses (f60-f150) and peeks from behind the dropping title marquee (f180-f210), then the neighbour storms onto the results screen (f270-f330), shouts with arms flung wide (f360) and fumes red-faced (f390-f450) until a pelmet drops onto his head (f480-f510, stars f540); he then sulks under it, oddly hovering above his head, for a very long hold (f570-f690), small and cluttered behind the results panel. |
| 3 | 3 | 3 | 3 | funny=3 readable=3 fresh=3 — End screen: the curtain drops (f30), the mime bows under thrown roses (f60-f120) and the title sign comes down (f150-f210), then on the results card the neighbour stomps on (f270-f360), sulks (f390-f480), the curtain's pelmet drops on his head with stars (f510-f540), and he glowers under it in a long hold (f570-f690); a good final callback, but frames 30 apart are too far apart to judge the accent or overshoot, it competes with the results text and the replay inset, and the pelmet seems to hang just above his head rather than rest on it (unsure). |

**Median 3/3/3** (bar 3/3, fresh 3) → **PASS**. Round 2: 2/2/2; round 1: 3/3/3. **Passes, 3/3/3 from all three** (round 2: 2/2/2). Q2-G7 landed: "having the stage itself prank him at his own curtain call is a good button". All three: the pelmet seems to hover just above his head; the results text and the replay inset compete with him; the 30-f stride hides the accent. R1: his f360 arms-out pose is the same T-pose as the relief.

### pkt_09 · `p00_sneeze` · p00i 1318–1456 every 6

| Reviewer | funny | readable | fresh | Answer (verbatim) |
|---|---|---|---|---|
| 1 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — A tighter version of the pepper sneeze: pepper showers his tea (f0-42), he tips his head back to inhale (f42-54), the sneeze puff rockets him and the stool backwards (f60-72) onto the sink (f78), he sits dazed with stars for about 40 frames (f78-120), then a suspicious magnifier thought appears (f126) and he walks right past the prankster's eyes in the curtain (f132-138); the quick build and the near-miss ending help, but the core joke is still the expected pepper sneeze. |
| 2 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — Same pepper-sneeze gag with tighter timing: pepper falls into his tea (f0-f42), he inhales with head back and eyes squinting (f48-f54), and a puff-cloud sneeze (f60) launches him and the stool into the sink (f66-f78) right beside the prankster's eyes in the curtain; he sits dazed under stars for a solid face hold (f78-f120), then gets up with a magnifier "who did this" thought (f126) and stomps off pointing his baton (f132-f138), a fuller arc than the stock sneeze. |
| 3 | 4 | 4 | 3 | funny=4 readable=4 fresh=3 — Pepper sprinkles onto him as he sips tea on a stool (f0-f36), he squints and tips his head back in a clear wind-up (f42-f54), and the sneeze puff launches him and the stool across the room into the sink (f60-f72) inside 6 frames, so the accent is short; he sits dizzy with stars while his teacup lands (f78-f120, about a 42-frame face hold), then gets up with a suspicious magnifying-glass bubble and walks off (f126-f138); tight timing with a good button, though the stool again rides with him in the air and the right edge of the frame crops him. |

**Median 4/4/3** (bar 4/4, fresh 3) → **PASS**. Round 2: 3/3/3; round 1: 4/4/3. **Passes, 4/4/3 from all three** (round 2: 3/3/3). "A fuller arc than the stock sneeze" (R2: the magnifier "who did this" button). Notes: the accent is short (6 f launch); the right edge crops him; the stool rides with him.

**Result: 3 of 9 strips at their bar. FAIL.** Means of the medians: funny 2.67, readable 3.00, fresh 2.22 (round 2, one reviewer: 2.22 / 2.89 / 2.22). The three reviewers agree closely: in 27 of the 27 strip × score cells all three are within one point (15 identical), so the medians are not one reviewer's luck.

## R3.5 What I saw in the frames (beyond the answers)
- **The relief and the curtain call share one pose fault:** `st_double_take`'s held take is both arms straight out at
  shoulder height, so it reads as a T-pose (relief f9–39, curtain call f360). Phase 1 flagged it; all three gag
  reviewers named it.
- **Walking in place:** after the relief take (f45–69) and in the picture's stomp (f72–138) his feet cycle while he
  barely moves against the stanchion and the mirror.
- **Lingering puffs:** the relief's "phew" is a stack of small white cloud puffs over the piano that drifts and stays
  for 60+ frames (it is still there at the start of the picture strip); reviewers read it as sweat or "never explained".
  White puffs also keep rising from the vase shards by the parlour fireplace long after the crash (they are still there
  in the kitchen frames at t400–445, `docs/review/r3d/hud_2d_vs_3d.jpg`).
- **The pickle jar** now sits on its raised shelf above Hush's head (Q2-C2), with its ring at [658, 207]. In the calm
  t520 kettle frame (spot pkt_07) she stands right under it and the jar's lit outline nearly touches the top of her beret.
- **The sneezes pass** with the dazed hold now head-up, face to camera, stars readable (g0 f96–138); the pepper motes
  fall from the pot into the cup through the build-up (g0 f6–60).
- **The curtain call passes:** the pelmet drops in a few frames onto him centre-left (f510), stars, then the glare; its
  fringe sits a few pixels above the wig in the hold (f570–690), which all three read as hovering.

## R3.6 Requests (round 3: what was misread, which frame, who can fix it)

Per the brief, the re-run is an **r3d-integrate re-run (alone)** or a fix round; the "Owner" column names the area whose
files change. Round 2's requests that round 3 closed are not repeated: Q2-C1 (the P00 frame now reads "no" 3/3; one ring
per target), Q2-G1 (both sneezes pass), Q2-G7 (the curtain call passes), Q2-G8 (the frame slides off), Q2-S2 (the kettle
reads as a tune and the need reads). **Keep what passes:** no change may regress the sneezes (4/4/3), the curtain call
(3/3/3) or the round-3 spot / crowding frames.

| # | Test · frame | What the reviewers misread | Change requested | Owner (files) |
|---|---|---|---|---|
| **Q3-G1** | gags pkt_01 (`p00_relief`, p00i 3196–3265, laugh_relief t3238; median 1/2/1) | "a stiff arms-straight-out pose … reads like a broken T-pose rather than a startle" (3/3); "walk-cycles left without really moving" (2/3); "white puffs stack above the piano" | (1) Re-pose the **`st_double_take` take**: hands up at chest height with bent elbows, shoulders up, the upper body pulled back away from the gap, eyes wide at the piano with the face to camera (D8); a 4-f accent and a settle, not a frozen 30-f hold. The curtain call's f360 uses the same pose. (2) **Her payoff:** one readable "phew" — her eyes squeeze shut and one sigh puff rises and fades within ~40 f; today's stack of puffs lingers 60+ f and reads as sweat. (3) His walk-off must travel at the walk cycle's speed (no foot slide). (4) Stage him clear of the gramophone horn (it reads as a hat behind his head, f12–39). | r3d-anim-bellows-b (`st_double_take` re-pose + bake); r3d-view3d / r3d-fix-gags (`game/view3d/set/hide_spot_3d.gd` phew, `cue_stager_3d.gd` near-miss staging and walk-off) |
| **Q3-G2** | gags pkt_02 (`p00_squeak_bit`, p00i 217–331, bit_warmup t230; 1/2/1) | "no prank lands" (R1); "nothing happens to him, so there is no gag to read" (R3); the throat clutch read as "fiddles with something at his chest … a duck" | His answer is on the main screen now (Q2-G4), but mute it has no cause and no payoff. (1) **Link the cause:** her squeeze shows a big squeak glyph (a burst of notes from Clarence), and the same glyph arrives at his ear when the shot cuts to him; he lifts his head to it as his cue. (2) **The payoff:** his high note is a big note glyph that visibly cracks (a broken red note, his eyes pop), then the throat clutch with both hands clear of the jabot and his face to camera ≥ 30 f. (3) Keep his thought bubble still during the bit (the gramophone → tea switch at f102 is noise). Alternatively the lead may rule the squeak bit a sound-led beat judged with sound: it has scored 1/2–3/1 mute in all three rounds. | r3d-view3d (`fx_3d.gd` squeak / crack glyphs, `cue_stager_3d.gd` cue shot); r3d-anim-bellows-b (`bit_warmup` pose + gaze); `overlays_3d.gd` (quiet his thought during the bit); lead (the option) |
| **Q3-G3** | gags pkt_04 (`p00_picture`, p00i 3256–3394, laugh_picture t3273; 3/3/**2**) | "the stock thing-falls-on-head gag" (R2, R3); "unclear who rigged it or why" (R1); "the hit has no squash or pop (f30)" (R3); "stomping without travelling … a treadmill" (R1) | Fails on fresh only. (1) **The twist R1 half-saw** ("wearing it like a portrait of himself"): the frame lands framing his face, so he *becomes* the portrait, and he holds the portrait's pompous pose (chin up, hand in the waistcoat) to camera for a beat before he notices. (2) A contact pop at f30 (impact star + a squash). (3) Open the shot on the portrait hanging crooked from the bonk, so the callback is inside the strip. (4) Replace the stomp-in-place with an in-place tantrum, or let him travel. | r3d-view3d / r3d-fix-gags (`cue_stager_3d.gd` picture beat, `fx_3d.gd` impact); r3d-anim-bellows-c (`cue_picture_bonk` portrait-pose hold); r3d-sets (portrait art, optional) |
| **Q3-G4** | gags pkt_05 (`p00_vase`, p00i 82–208, laugh_vase t138; 2/3/2) | "only a quick wide-eyed glance (f90) and no 30-frame face hold" (3/3); "the vase is tiny and far from him" (3/3); "the stock voice-breaks-china joke" | (1) **Bring the vase into his shot:** today it sits on the far mantel, about 50 px tall and about 300 px from him at full size. Move it beside him (the piano top or next to the gramophone) or frame the push-in on both. (2) **An unmistakable "ovation" take:** on the crash he opens his eyes, sees the shards and takes a deep, smug bow to them (hand on heart, face to camera) held ≥ 30 f. `st_straighten_cravat` is too small to register at strip size. (3) A bigger shatter (shards + a puff that clears in ≤ 1 s). | r3d-sets (`game/data/house/house3d.json` `decor.parlour_vase` position); r3d-anim-bellows-b (an overlay bow clip); r3d-view3d / r3d-fix-gags (`cue_stager_3d.gd` framing + hold, `fx_3d.gd` shatter) |
| **Q3-G5** | gags pkt_06 (`p00_doorframe_bonk`, p00i 1624–1750, laugh_doorframe t1677; 3/3/**2**) | "the plain walk-into-the-doorframe gag" (3/3); "the look-up at f54 is not a real opposite wind-up" (R3); "nothing shows what the prankster in the curtain did" (R1) | Fails on fresh only; Q2-G6's no-cut and face hold landed. (1) **A twist inside the strip:** after the daze he scolds the doorframe (wags the baton at it, nose up) and turns away, and the jolted parlour portrait swings askew behind him in the same shot (the set-up of the picture gag, now visible). (2) A bigger wind-up the other way (lean back, chin up, baton drawn back, 6–8 f); `cue_doorframe_windup` is too small at this shot size. (3) The white oval at his feet is the sneeze's teacup on the floor: leave it, or let him kick it for an extra beat. | r3d-view3d / r3d-fix-gags (`cue_stager_3d.gd`); r3d-anim-bellows-c (`cue_doorframe_windup`, `cue_doorframe_bonk`); r3d-sets (the portrait swing) |
| **Q3-G6** | gags pkt_07 (`p00_dizzy_spin`, p00i 2560–2767 every 6, accent t2659; 3/3/3, bar 4/4) | "dances wildly to the stream of notes" (3/3); "unclear why the music makes him dance" (R3); "whether the red face means dizzy or angry" (R1); "the hold runs long" (3/3) | (1) **Make the cause physical:** the gramophone shows the speed-up (spin lines on the disc, the ×3 burst), and a ribbon of notes wraps him and *pulls* him round: arms trailing, not conducting, heels off the floor, the bouffant trailing. (2) **Dizzy, not angry:** spiral eyes from the first slump frame and a queasy green tint instead of the red flush. (3) A shorter hold (~40 f, not ~60) that ends on the button two reviewers liked: nose to nose with the hidden eyes. Keep the notes circling his head instead of stars (liked by R1 and R3). | r3d-anim-bellows-c (`rx_dizzy_spin_a` pose, inside its locked window); r3d-view3d (`fx_3d.gd` spin lines / note ribbon, the gramophone disc); r3d-rig (the face tint / spiral eyes look) |
| Q3-C1 *(at the bar, counts)* | crowding pkt_07 (`cr_n01`, `n01i:394` ≈ t6768; 2 of 3 "yes") | "two thought bubbles compete … the red-ringed one packs music notes, a kettle and a face into one small icon" | While a prop's badge carries his countdown ring for his next activity, hide his own thought bubble for that target (Q2-C1's option (b)): one bubble per target. Draw `kettle_drum` simpler at badge size (two shapes sharing one note). N1 is a hidden preview, but the frame is in the packet and counts. | r3d-hud (`game/ui/world/overlay_rules.gd`, `game/art/ui/previews/kettle_drum.svg`); `game/view3d/world/overlays_3d.gd` / `game/view/fx/thought_bubble.gd` |
| Q3-S1 *(spot passes)* | spot pkt_04 (`sp_pickle`, N1 calm t360; 0 of 3) | "the jar is full of spring snakes, which pop out at him" (3/3) | The jar now reads as a jar; the joke does not. Redraw `in_a_pickle` with the stuck lid as the subject: round pickled onions instead of the long gherkins that read as snakes, a jar label, a big twist arrow and stress lines at the lid, his straining hands. The shelf prop is still the green polka-dot pot: make it a glass jar with pickles (Q2-S1's prop half). N1 preview, so it can wait for R3. | r3d-hud (`game/art/ui/previews/in_a_pickle.svg`); r3d-sets (the N1 pickle-jar prop) |
| Q3-S2 *(spot passes, note)* | spot pkt_05 (`sp_honey`, `g0:30`; 2 of 3 right) | "the jar's sugar is swapped for hot chili, so he puffs steam from the heat" (R2, = round 1's misread) | Optional: make the CHOO puff read as a sneeze spray (droplets, his head thrown back), not steam. | r3d-hud (`game/art/ui/previews/achoo_ria.svg`) |
| notes *(passing)* | curtain call (3/3/3); both sneezes (4/4/3); crowding "no" frames | the pelmet "seems to hang just above his head" (3/3); "the stool stays stuck to his feet in the air", "the right edge of the frame crops him" (sneeze); the hand hint above the shelf is small (crowd pkt_03, 3/3); the note clump on his wig is messy (pkt_02, 3/3); shelf debris over the Script pill (pkt_06, 3/3) | Polish, not required: rest the pelmet on the wig (squash it a little); frame the sneeze launch so he stays inside the frame. | r3d-night (`curtain_bows_3d.gd`); r3d-view3d (`gag_stager_3d.gd`) |

**After the fixes:** re-shoot the gag strips at the same windows (the dizzy spin every 6 ticks) and build a new gag
packet with a new seed for **three new** fresh reviewers (D18.1). If a fix touches the overlays (Q3-C1) or the
previews (Q3-S1/S2), re-run the crowding and spot packets too, so their passes are confirmed on the new frames.
Then re-run pre-gate row 19.
