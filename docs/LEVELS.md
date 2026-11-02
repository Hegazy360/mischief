# Mischief Next Door — Level & Scenario Plan (v1.0)

Design authority: `docs/GDD.md` §7.2 (the 12 episodes), §5.7 (the 32 pranks), §4.1.1 (the activity library).
Contracts: `docs/TECH.md` §4.6 (episode files), §8.2 (solution files). Build order: `docs/PLAN.md` Stage 3.
The story that connects the Nights (one summer, three Acts, the countdown, the box, the seasons): GDD §7.0.
This document does not change the design. It turns §7.2 into a **per-level build sheet**: what each Night needs
from every discipline, what already exists, and the **scenarios** (solver routes) each Night must pass before it is
called done. Read it before expanding `game/data/**`.

Vocabulary: a **level** is one episode file in `game/data/episodes/`. A **scenario** is one route in that
episode's `game/data/solutions/<episode>.json`: a scripted player persona (ideal / required / slow / scenario)
plus an `expect` block the solver checks headlessly (TECH §8.2). "Done" is defined in §2 below.

---

## 1. Where we stand (2026-11-01)

Every episode exists as data, but only the slice is finished. The rest are **samples**: a valid JSON file that
loads, lints and runs in the sim, with no solutions, no bespoke clips, greybox props and no sound.

| Level | Status | Solutions / scenarios | Solver | Bellows clips used by it | Notes |
|---|---|---|---|---|---|
| P — Curtain Up | `final` | 4 (+ `no_squeak`) | OK, dead-air gate green | all | wave 0 complete |
| G0 — the Sneeze (dev) | `draft` | 1 | OK | all | Gate 0 stage-door scene; keep as the end-to-end smoke test |
| N1 — Throat Tea | `final` | 8 (+ `bn_sealed`, `tray_restock`) | OK | all | wave 0 complete |
| N2 — Something Fishy | `final` | 9 (+ `caught`, `chase`, `mirror_r3`, `frazzle_link`) | OK | all | wave 0 complete |
| N3 — Singing in the Bath | `draft` | 0 | not gated | 0 | loop 58.9 s measured after the `dur_s` trims (was 77.9 s) |
| N4 — The Big Sulk | `draft` | 0 | not gated | 0 | loop 64.6 s measured after trims (was 92.6 s); 65 s two-floor allowance; first Night with tomatoes and Meltdown lines |
| N5 — Enter Beryl | `draft` | 0 | not gated | 0 | Beryl is a null seam in the sim (`sim_beryl.gd`, 14 lines) |
| N6 — Behind You! | `draft` | 0 | not gated | 0 | panto bit not in the sim (`bits.gd`); `panto` line kind parsed only |
| N7 — Kidding Around | `draft` | 0 | not gated | 0 | herding + `herd` line kind need Beryl |
| N8 — Company's Coming | `draft` | 0 | not gated | 0 | Delphine is a null seam (`sim_delphine.gd`); `witness` kinds parsed only |
| N9 — Tutu Much | `draft` | 0 | not gated | 0 | `chase_trip` line kind; dressing room first opens |
| N10 — It Takes Two | `draft` | 0 | not gated | 0 | `nerves` rule in schema, untested in play |
| Gala — The Comeback | `draft` | 0 | not gated | 0 | 8-minute hard cap; Beryl + Delphine + spotlight together |

Shared assets, measured against what the 12 levels reference:

| Asset class | Referenced | Exists | Gap |
|---|---|---|---|
| Bellows reaction / state / beat clips (`reactions.json`) | 68 | 41 (every clip the slice plays) | 27, all Act I–III: 17 reactions + 5 signatures, 4 combo beats and `beat_suppressed` |
| Bellows activity clips (`activities.json`) | 27 | 11 + 4 detours (the whole slice set) | 16 (the Act I–III activities) |
| Squeak-bit clips | 10 | 6 (tea, paper, warmup, mirror, phone, livid) | 4 (bath, nap, feed, piano) |
| Hush clips | — | 34 (slice set complete, incl. the caught chain and the bow) | panto set, garden walk, Besotted-leading |
| Beryl / Delphine rigs | 2 | 0 | both (GDD §9.4 P1 lists their clip sets) |
| Room art (bg + fg) | 10 | 10 | upstairs, conservatory, garden, dressing room are greybox |
| Slice props with states | — | ≈ 110 files | upstairs / garden / dressing props mostly single-state |
| Residue overlays + combo looks | 7 + 4 | all present | — |
| Cold-open sets (`cold_sets.json` + art) | 11 | 2 (N1, N2) | 9 |
| Audio: prank cues | 32 | 9 | 23; archetype cues 5 of 22; squeak-bit cues 0 of 10 |
| Sim: Beryl, Delphine, panto, herding, witness, third-party triggers | — | seams only | `s3-sim-cast` (PLAN Stage 3A) |
| Tests | — | 1,105 across 126 files | no per-Night scenario tests beyond P, N1, N2, G0 |

Loop lengths measured on 2026-11-01 by `tests/solver/test_loop_lengths.gd` (the planner's idle probe: Hush hidden,
walking included, no Beryl / Delphine detours yet, steady-state loop):

| Night | Measured | Band (GDD §7.3) | Note |
|---|---|---|---|
| N1 / N2 | 58.7 / 55.4 s | ≤ 60 | match Checkpoint G |
| N3 | 58.9 s | ≤ 60 | `bath` 12, `dress` 5, `nap` 12 this Night |
| N4 | 64.6 s | ≤ 65 (two floors) | `warmup` 6, `paper` 6, `bath` 10, `nap` 8; 30 s of the loop is the stair round trip |
| N5 | 55.1 s | 80–95 | short: no Beryl doze/herding yet, `tea` is the only indoor stop; retune in wave 2 |
| N6 | 70.0 s | 80–95 | panto rounds will add ~10 s per visit; re-measure with the sim cast |
| N7 | 114.9 s | 80–95 | **over**: garden → upstairs bath + nap; trim `bath`/`nap` with `dur_s` in wave 2 |
| N8 | 69.7 s | 90–120 | short: `answer_door` is first-loop only; Delphine's loop will add detours |
| N9 | 89.6 s | 90–120 | at the band's edge |
| N10 | 104.2 s | 90–120 | in band |
| Gala | 91.2 s | 90–120 | in band; four loops fit the 8-minute cap |

Two consequences for the expansion:
1. **The slice is not animation-complete.** Finishing N1 and N2's clips (11 reactions, 8 activities, 6 squeak
   bits) is the first content wave regardless of which Night comes next; every later Night reuses them.
2. **Acts II–III are blocked on the sim**, not on content. Beryl, Delphine, panto, herding and witness scoring
   must land before N5–Gala can have solutions at all. Start `s3-sim-cast` in parallel with the Act I wave.

---

## 2. Definition of done for a level

A Night moves `draft → final` only when all of the following hold. The solver only gates `final` episodes
(TECH §4.6), so flipping the flag is the last step, never the first.

**Content**
- [ ] Episode file matches GDD §7.2 exactly: rooms (+ porch), entry, rules, card text, cold-open description,
      start positions, loop + gates, `fixup_overrides`, Script (≤ 7 lines, one Big Number, `rearm_on_unseal`
      per §6.2), director cues for its new rule's Figgis card.
- [ ] Every prank the Night lists has `nights` containing it in `pranks.json`; every item it needs is in a
      container inside the Night's rooms; every fix-up station kind it can trigger has a station in its rooms
      or backstage (GDD §5.4 rule 1). Content lint green.
- [ ] Micro-gags authored for every activity and detour the Night uses (GDD §4.1 rules 1–3).
- [ ] Solution file with the full scenario set of §3 for this Night; every route's `expect` passes.
- [ ] Loop measured by the solver with Hush idle and recorded in §4 below; Act I ≤ 60 s, Act II 80–95 s,
      Act III and Gala 90–120 s. Dead air ≤ 20 / 25 / 30 % and worst gap ≤ 12 s on ideal / required / slow.
- [ ] First clear on the slow route inside the §7.3 target; nothing over 8 min.

**Simulation**
- [ ] Every rule the Night introduces has a scenario test in `game/tests/sim/` that fails without the feature.
- [ ] Every GDD §4.7 fairness rule still passes with the Night's rooms and cast (the fuzz runs on it).

**Animation / art / audio**
- [ ] Every reaction archetype, signature, activity, squeak bit and detour the Night uses has a real clip,
      lint-clean, with a GIF in `docs/review/<key>/` that someone looked at and scored ≥ 3 on funny / readable /
      fresh (GDD §9.4).
- [ ] Rooms the Night opens have final bg/fg art and every slice prop in all its states with outline sprites.
- [ ] Cold-open set + clip; loading-card icon; new activity icons; item icons.
- [ ] SFX for every new prank and archetype; the Night's phrase-bank lines; crowd specials it can trigger.

**Review**
- [ ] Screenshots at 1200×540 of every new room at zoom 1.0 and the house overview; a frame sequence of each
      new reaction; `docs/PROGRESS.md` log line.

---

## 3. Scenario families

Every Night authors routes from four families. Names are stable so tests and reports can refer to them.

| Family | Routes | Persona | Gated by | Purpose |
|---|---|---|---|---|
| **Golden** | `ideal`, `required`, `slow` | ideal / required / slow | dead-air gate (GDD §2.4), stars, Applause band, first-prank time, catches 0 | Proves the Night is playable, paced and clearable at ★ / ★★★ |
| **Rule proof** | one or more named after the Night's new rule, e.g. `fixup_chain`, `panto_three` | scenario | `events_min`, line ids | Proves the new rule happens on the real routine, in the real rooms, and its failure case reads |
| **Fairness** | `caught`, `chase`, and from N2 `face_to_face`; from N5 `beryl_butts_hush`; from N8 `delphine_high_c` | scenario | `events_min` (`caught`, `doorstep`, `chase_start`, `search` …), never an unfair catch | The §4.7 rules against this Night's geometry and cast |
| **Fun** | `meltdown`, the Big Number while sealed (`bn_sealed`), chains and combos the Night promises | scenario | `events_min`, `lines` includes `bn`, chain length | Proves the "one more Night" moments exist and the re-arm rule (§6.2) works |

Conventions: route step verbs and `expect` keys are the ones already used in
`game/data/solutions/n01_throat_tea.json` (`rig`, `pick`, `hide`, `pop_out`, `squeak`, `move`, `wait`,
`wait_event`, `bow`; `expect.lines`, `events_min`, `catches_max`, `applause`, `stars`, `dead_air_pct_max`,
`max_gap_s_max`, `first_prank_s_max`). New verbs a Night needs (`lead_beryl`, `drop_item`, `tuck_in`,
`stand_in_frame`) are listed in its sheet and must be added to the solver executor before the route is written.

---

## 4. Per-level build sheets

Each sheet: premise · stage · his clock · the Script · what is new (and what is reused) · scenarios · risks.
"New" means first appearance in play order; everything else is reuse. Loop times are GDD estimates until the
solver measures them; write the measured figure in the sheet when it exists.

### P — "Curtain Up" (Prologue) — `final`
- **Premise:** the first 60 seconds. Hush climbs in the kitchen window; one sneeze, one spin, no Script, can't fail.
- **Story beat:** First morning of the summer holidays; 6 a.m. scales; Hush climbs in "just to make him sneeze once". The countdown poster reads 12.
- **Stage:** parlour, kitchen (hall backstage). Bellows alone. Entry: window. "?" 2.0 s, tomatoes ∞.
- **His clock:** scripted, player-led: warmup (gated on the first squeak) → warmup (gated on the honey rig) → tea →
  [FRAZZLED → hall mirror fix-up, off-stage] → warmup (gated on the lever rig) → hunt → exit upstairs.
- **Script:** R ACHOO-RIA! · R ALLEGRO-GO-GO!. No Big Number.
- **Exists:** everything but the DIZZY_SPIN clip (ALLEGRO-GO-GO! plays the bonk fallback) and the title-slam audio check.
- **To finish:** `rx_dizzy_spin_a` (+ its SFX); the `hunt` and `exit` walk clips; look at the Gag Reel (the sneeze).
- **Scenarios (kept):** `ideal`, `required`, `slow`. Add **`no_squeak`**: the player never squeaks; the 15 s cap
  releases the first warm-up gate and the safety net pulses the pantry curtain before his entry (GDD §2.3).
- **Risk:** none open. Checkpoint G numbers in GDD §2.4 rule 6 are the regression baseline.

### N1 — "Throat Tea" — `final`
- **Premise:** the tray, the Script and the bow. He makes tea twice a loop; the kettle is the star.
- **Story beat:** Heatwave, day one; the megaphone cracks her window. The first thing she takes from the box is her own squeaker, confiscated last summer (the `card_tray` moment).
- **Stage:** porch, hall, parlour, kitchen. Entry: window. "?" 1.0 s, tomatoes ∞, no combos, DRY → fireplace.
- **His clock (58.7 s measured):** warmup (first-loop gate) → tea → pickles → rinse → tea → paper (specs on).
- **Script:** R KETTLE DRUM · R TAP DANCE · R IN A PICKLE · O LIFT-OFF · O ACHOO-RIA! · BN HOT & COLD (Double Act).
- **New pranks:** TAP DANCE, KETTLE DRUM, IN A PICKLE, LIFT-OFF. **New items:** squeaker.
- **Clips missing:** `rx_drench_a`, `rx_sing_crack_a`, `rx_strain_slip_a`, `rx_launch_ceiling_a`;
  `act_pickles`, `act_rinse`, `act_paper`; squeak bits: tea up the nose, paper rip, warm-up yodel; the HOT & COLD
  knock-on frame (sneeze frame 112 → TAP DANCE) must be checked once the drench clip exists.
- **Scenarios (kept, 6):** `ideal`, `required`, `slow`, `caught`, `chase`, `meltdown`. Add **`bn_sealed`**:
  land HOT & COLD before the three required lines, then finish them; `bn` counts on unseal and ACHOO-RIA! / TAP
  DANCE re-arm. Add **`tray_restock`**: use the squeaker on KETTLE DRUM, wait 20 s, pick it again.
- **Risk:** the Fun Gate (PLAN §3) is played on this Night; the clip wave above is what the owner will see.

### N2 — "Something Fishy" — `final`
- **Premise:** FREEZE and the specs rule. He opens the Night reading with his specs on, in his recliner.
- **Story beat:** He pops a child's balloon; on the phone he tells his agent the comeback is ON, through a kipper.
- **Stage:** porch, hall, parlour, kitchen. Entry: window. "?" 1.0 s, tomatoes ∞, no combos.
- **His clock (55.4 s measured):** paper (specs on) → fire → snack → mirror → phone → clock.
- **Script:** R SOMETHING FISHY · R TIME'S UP · R COLD OPEN · O EYE-POPPING NEWS · BN MIRROR, MIRROR (signature).
- **New pranks:** COLD OPEN, EYE-POPPING NEWS, SOMETHING FISHY, TIME'S UP, MIRROR, MIRROR. **Items:** kipper, magnifier.
- **Clips missing:** `rx_avalanche_helmet_a`, `rx_blind_bumble_a`, `rx_fish_slap_a`, `rx_jackhammer_cling_a`,
  `sig_mirror_mirror` (+ `_r1/_r2/_r3` rounds); `act_fire`, `act_snack`, `act_mirror`, `act_phone`, `act_clock`;
  squeak bits: comb flies off, "I did NOT squeak!"; `st_specs_on`, `st_look`, `st_double_take`, `st_suspicious`
  (the stare strip is the lesson here, so the state clips matter more than on N1).
- **Scenarios (kept, 5):** `ideal`, `required`, `slow`, `face_to_face`, `face_to_face_lost`. Add **`caught`** and
  **`chase`** (N1 has them; N2 does not), **`mirror_r3`** (survive all three rounds, release at the specs tell,
  T3 scream), **`mirror_poke`** (stay frozen past the tell → the 0.8 s "?" → bolt), **`frazzle_link`** (TIME'S UP →
  mirror fix-up → MIRROR, MIRROR as one Running Gag).
- **Risk:** MIRROR, MIRROR is the first signature; its clip budget (≤ 420 f) and the frame-in-the-mirror pose for
  Hush are unproven.

### N3 — "Singing in the Bath" — `draft` → Act I wave
- **Premise:** upstairs opens. Items live downstairs; the lesson is reading his fix-up bubble and rigging the
  station he is about to visit.
- **Story beat:** The heat drives him to the bath at dawn; with every window open, upstairs is open too (heatwave decor: sun-blinds, a fan on the landing).
- **Stage:** + landing, bathroom, bedroom (7 rooms with porch). Entry: window. "?" 1.0 s, tomatoes ∞. HONEY →
  kitchen tea counter. Combos allowed (POODLE is the Big Number). Bellows starts at the basin; Hush in the kitchen.
- **His clock (58.9 s measured):** gargle → bath (12 s this Night, absorbed) → radiator → dress (5 s) → nap (12 s this
  Night, asleep). The trims are loop-entry `dur_s` overrides; the library keeps 24 / 6 / 18 s for other Nights.
- **Script:** R SOPRAN-OH-NO · R SNAP DECISION · R PIPE DOWN! · O PILLOW TALK · O BUTTER-FINGERS · O ACHOO-RIA!
  (via SQUEAKY → honey downstairs) · BN POODLE (combo: SOAKED + FRAZZLED). Re-arm: SNAP DECISION, PIPE DOWN!.
- **New pranks:** SOPRAN-OH-NO, SNAP DECISION, PIPE DOWN!, PILLOW TALK, BUTTER-FINGERS. **Items:** balloon,
  croc, butter (+ squeaker).
- **New sim:** stairs for both movers (exists in nav; verify Bellows 1.8 s / Hush 1.0 s); `absorbed` and `asleep`
  awareness; the in-use bath and wardrobe; BLINDED from buttered specs at `nap` end; cross-floor fix-up routing
  ("nearest of that kind on his floor", with the HONEY override pulling him downstairs).
- **New clips:** `rx_squeaky_voice_a`, `rx_scare_leap_a`, `rx_steam_duel_a`, `rx_feather_burst_a`,
  `rx_blind_bumble_b`; `act_gargle`, `act_bath` (+ progress bar), `act_radiator`, `act_dress`, `act_nap` (+ sleep
  bar); squeak bits: periscope eyebrows, headboard bonk; `combo_poodle`; Bellows and Hush stair clips; the
  Overview and Bellows-Cam are first needed here.
- **Art:** landing, bathroom, bedroom final; props in states (airing cupboard, radiator, basin + cabinet, scales,
  bath + duck, laundry basket, wardrobe, bed + pillow, bedside table + specs, hat stand); cold open (alarm clock).
- **Audio:** soprano aria, croc snap, steam duel, feather burst, the +12 semitone SQUEAKY voice filter.
- **Scenarios:** Golden ×3 · Rule proof **`fixup_chain`** (SNAP DECISION soaks him → bubble shows the radiator →
  PIPE DOWN! fires at the fix-up's 1 s hook; expect `fixup_queued` then `prank_fired:pipe_down` within 12 s) ·
  **`honey_downstairs`** (SOPRAN-OH-NO → HONEY override → ACHOO-RIA! in the kitchen) · **`bath_absorbed`** (Hush
  walks past at > 250 px while he bathes, no "?"; at < 250 px a "?" starts) · **`nap_asleep`** (squeak during the
  nap triggers only the nap bit) · Fairness `caught`, `chase` (a chase down the stairs), `face_to_face` ·
  Fun `meltdown`, **`bn_sealed`** (POODLE before the required lines; re-arm check), **`butter_window`**
  (BUTTER-FINGERS blinds him 15 s; Hush crosses the bedroom in the open).
- **Risks / decisions:** (1) Loop: resolved, 58.9 s after the trims (was 77.9 s). (2) Carrying items
  upstairs costs a stair round trip; the ideal route must still land a first prank ≤ 25 s — pre-rig the free
  PIPE DOWN! (B prep) or start Hush near the box. (3) The first upstairs catch must land Hush on the porch, not
  the landing (GDD §4.6).

### N4 — "The Big Sulk" — `draft` → Act I wave (Act finale)
- **Premise:** temper management. Keep him climbing; a Meltdown is a Script line; tomatoes now count.
- **Story beat:** He snaps a child's kite (into the box). The first Meltdown; he blames the parlour's acoustics and resolves to sing outdoors — which is why Act II has a goat.
- **Stage:** whole house minus conservatory, garden, dressing (7 rooms + porch). Entry: window. "?" 1.0 s,
  **tomatoes 3**. Starts in the parlour.
- **His clock (64.6 s measured, 65 s two-floor allowance):** warmup (6 s) → paper (6 s, specs on) → fire → bath
  (10 s, upstairs) → nap (8 s). Every trim is a `dur_s` override; 30 s of the loop is the stair round trip.
- **Script:** R RUG BURN (Steaming or chasing, going up) · R ALLEGRO-GO-GO! · R MELTDOWN ×1 · O PRIMA BALLERINA
  (Meltdown in the parlour) · O BELLOWS BLOWS · O LIFT-OFF (→ DA UP IN SMOKE) · BN IN OVER HIS HEAD (signature).
- **New pranks:** BELLOWS BLOWS, PRIMA BALLERINA, RUG BURN, IN OVER HIS HEAD. **Items:** flour, bubble bath,
  sherbet. First 2-step rig (IN OVER HIS HEAD).
- **New sim:** QUAKE trigger with a room filter; STEP trigger with direction + anger gate + chase; the tomato
  counter and the lost Night (3 catches); Meltdown b/c variants and the 8 s blind sulk; Exhausted; the lost-Night
  curtain call.
- **New clips:** `rx_poof_a`, `rx_drop_on_a`, `rx_surf_out_a`, `sig_in_over_his_head`, `melt_b`, `melt_c`,
  `melt_exhausted`, the four T3 last beats (first Night where T3 is routine), hedge-wearing walk-back after RUG BURN.
- **Art:** chandelier states, stair rods + runner, umbrella stand landing, flour portrait, cold open (kite).
- **Audio:** chandelier drop, runner whip, bubble aria, three Meltdown arias, tomato splat tiers.
- **Scenarios:** Golden ×3 · Rule proof **`rug_burn_gate`** (he passes the rods Calm: no fire; the same pass at
  Steaming: SURF_OUT) · **`chase_trip_stairs`** (chased up the stairs over the rods → "HE FELL FOR IT!") ·
  **`meltdown_quake`** (Meltdown in the parlour drops the chandelier; Meltdown in the kitchen does not) ·
  **`sulk_blind`** (8 s window after Meltdown: Hush walks past him in the open) · **`tomatoes_out`** (three catches
  → Night lost → results with the why-missed line; expect `events_min: {caught: 3, night_lost: 1}`) · Fairness
  `caught`, `chase`, `face_to_face` · Fun **`up_in_smoke`** (LIFT-OFF → log basket → BELLOWS BLOWS as one knock-on),
  **`bn_sealed`**, **`exhausted`** (second Meltdown in one loop → Exhausted, temper floor).
- **Risks / decisions:** Loop: resolved at 64.6 s (was 92.6 s) with every activity at or near its floor; it cannot
  reach 60 s without cutting the stair round trip, so GDD §2.4 rule 5 now allows 65 s for the two-floor finale. The
  8 s nap is short for an "asleep" stealth window; if it reads as a blink on the phone, lengthen it to 10 s and accept
  66 s. Owner check for Act I happens after this Night.

### N5 — "Enter Beryl" — `draft` → Act II wave
- **Premise:** the garden and the goat. The bend-over rule is the universal finisher; apples lead her.
- **Story beat:** August, bunting porch to fence. He hoses her chalk mime away. Beryl has arrived "to crop the lawn" for a garden stage and is already "my little prima donna"; a marrow grows for the Show's vegetable class.
- **Stage:** ground floor + conservatory + garden (upstairs roped off). **Entry: fence gate** (Hush starts at the
  pond end, x 6150). "?" 0.8 s, tomatoes 3.
- **His clock (~85 s est.):** feed_beryl (bends) → roses → marrow (bends) → stroll (walks the coin path) → tea.
  Beryl: grazing lane 3950–5650 at 70 px/s, dozes 20 s of every 60 s in the sunbeam.
- **Script:** R HOSED · R MARROW ESCAPE · R PENNY PINCHER (3 coin spots) · O ACHOO-RIA! · BN MARROW MAYHEM
  (Double Act: balloon chase → bend → headbutt → pond). Re-arm: MARROW ESCAPE.
- **New pranks:** HOSED, MARROW ESCAPE, PENNY PINCHER. **Items:** apple, coins (3 per pick). First 3-step rig.
- **New sim (`s3-sim-cast`, part 1):** Beryl actor: moods Dozing / Grazing / Besotted, wake on noise ≤ 300 px,
  follow at 150 px, bleat every 6 s as a noise ring; the bend-over rule for both characters; BUTT OF THE JOKE
  (+3, +45 temper, once per Night); "only on camera" rule; blame bark; THIRD_PARTY trigger (`beryl_on:
  garden_hose`); PENNY PINCHER's three bends with the `beryl_within: 300` check on the third; fizzles for HOSED
  and PENNY PINCHER; the fence-gate entry; the garden as "ground floor" for fix-up routing.
- **New clips:** Beryl rig + idle, graze walk, doze, trot, follow, paw, headbutt, bleat; `rx_drench_c`,
  `rx_balloon_chase_a`, `rx_headbutt_launch_a`, `rx_penny_bend_1/2`; `act_feed_beryl`, `act_roses`,
  `act_marrow`, `act_stroll`; Hush garden walk, Besotted-leading, tumble (headbutt on Hush); squeak bit: Beryl
  butts him (small).
- **Art:** conservatory + garden final; feed bin, hamper, sunbeam, lounger, potting bench, hose + tap, roses,
  marrow bed, 3 coin spots, shed, compost, pond, fence gate; landings table (roses, pond, compost, hamper); cold
  open (hosing the chalk mime).
- **Audio:** Beryl's bell, bleat, paw; balloon shriek; hose sploosh; coin clinks; pond splash.
- **Scenarios:** Golden ×3 (new verbs: `drop_item apple`, `lead_beryl`) · Rule proof **`beryl_butts_hush`** (Hush
  picks up within 300 px of an awake Beryl facing her → 300 px tumble + noise ring, no catch) ·
  **`butt_of_the_joke`** (he bends at the marrow with Beryl beside him and no prank rigged → +3, Running Gag link) ·
  **`hosed_fizzle`** (HOSED rigged, Beryl dozing → "hmph", stays rigged) · **`penny_fizzle`** (three coins, Beryl
  far → he pockets them) · **`doze_wake`** (she sleeps through a tiptoe at 350 px, wakes to a run at 200 px) ·
  **`lure_fatigue_bleat`** (Besotted bleats draw him Curious; third lure in 60 s greys out) · Fairness `caught`
  (doorstep is a long walk from the garden: check control returns at +240 ticks), `chase` (garden to house),
  `face_to_face` · Fun `meltdown`, **`marrow_mayhem`** / **`bn_sealed`**, **`off_camera_paw`** (Beryl paws and
  gives up when his room is neither on screen nor in the PiP).
- **Risks / decisions:** (1) The coin round trip (piggy bank in the hall → garden) is the longest fetch in the
  game; the ideal route needs the stroll timing to fit one loop. (2) The headbutt landing table is per room and
  does not exist yet. (3) Beryl's "only on camera" rule depends on view state inside a deterministic sim; the
  sim must take the camera's room as an input, not read the view.

### N6 — "Behind You!" — `draft` → Act II wave
- **Premise:** the panto bit. Squeak behind him at the piano, freeze before he turns, read the feint.
- **Story beat:** He silences the dawn chorus and rehearses his Show number at the piano; the street answers BEHIND YOU!.
- **Stage:** ground floor + conservatory + garden; no upstairs, so RUG BURN only through DA ENCORE!. Entry: gate.
  "?" 0.8 s, tomatoes 3. He starts at the piano.
- **His clock (~85 s est.):** piano (panto, 12 s) → warmup (panto) → feed_beryl → marrow → paper (specs on).
- **Script:** R panto ×3 rounds · R SWEET TOOTH · R ALLEGRO-GO-GO! · O EYE-POPPING NEWS · O MARROW ESCAPE ·
  O RUG BURN (knock-on only) · BN GRAND EXIT (signature; source of DA ENCORE!).
- **New pranks:** GRAND EXIT, SWEET TOOTH. **Items:** treacle (+ balloon, magnifier).
- **New sim (`s3-sim-cast`, part 2):** the panto bit (conditions, three rounds with their timings, the feint tell,
  one bit per activity visit, "…the pipes." when nothing is seen, +2/+3/+5 and +5 temper); `panto` line kind;
  herding detour after SWEET TOOTH (10 s shove-and-tug); the piano as a moving prop across parlour + hall; a
  knock-on into a STEP prank (ENCORE! flips him onto the runner: knock-ons waive the anger gate, GDD §5.5; in the sim
  since 2026-11-01, `Conditions.prank_conditions(…, knock_on)`).
- **New clips:** `st_panto_twitch`, `st_panto_turn`, `st_panto_look`, `st_panto_tell`, `st_panto_whip`;
  `sig_grand_exit` (piano chase through two rooms, flip, lid); `rx_goat_kiss_a`; `act_piano`; the herding tug
  (Bellows + Beryl); squeak bit: wrong chord BONG; Hush: panto freeze set behind him.
- **Art:** piano in motion states + lid; feed bin treacle state; cold open (dawn chorus, feather in tea).
- **Audio:** "BEHIND YOU!" crowd special; piano rolling, fortissimo chord, muffled chord; goat lick; treacle.
- **Scenarios:** Golden ×3 · Rule proof **`panto_three`** (three squeaks inside the 8 s windows, frozen on every
  look → "PANTO BIT!" T3 laugh) · **`panto_seen`** (moving during round 2's look → a normal "?") ·
  **`panto_feint`** (release FREEZE at the false turn-back → seen on the whip) · **`panto_once_per_visit`**
  (a fourth squeak at the same piano visit is just an ear pip) · **`panto_specs_on`** (no panto while he reads) ·
  **`herd_after_kiss`** (SWEET TOOTH → she follows him in → herding detour in the bubble at once) · Fairness
  `caught`, `chase`, `face_to_face`, `beryl_butts_hush` · Fun `meltdown`, **`encore_da`** (GRAND EXIT → runner →
  RUG BURN as one knock-on; he returns in the hedge), **`bn_sealed`**.
- **Risks / decisions:** GRAND EXIT crosses two rooms with a moving prop and a camera follow; it is the most
  expensive clip in the game after the Gala. Build it after the panto set, which is the Night's actual lesson.

### N7 — "Kidding Around" — `draft` → Act II wave (Act finale)
- **Premise:** lead the goat indoors and put her in his bed.
- **Story beat:** He sells her unicycle to pay for stage lights. A goat in his bed. Curtain-call teaser: the committee's letter — this year's judge is Dame Delphine Trill.
- **Stage:** whole house except the dressing room (9 rooms + porch). Entry: gate. "?" 0.8 s, tomatoes 3.
- **His clock (~95 s est.):** feed_beryl → roses → paper (specs on) → bath (upstairs) → nap.
- **Script:** R SWEET TOOTH · R HOSED · R herd ×2 · O IN OVER HIS HEAD · O LIFT-OFF · BN KIDDING AROUND (signature).
- **New pranks:** KIDDING AROUND (apple lead to the bed + Q tuck-in with `beryl_within: 150`). **Items:** none new.
- **New sim:** Beryl indoors and **upstairs** (stairs for a third mover, doors); the herding lure as a Script line
  kind (`herd {count}`); Besotted following through doorways; her bleats as noise inside the house; the
  `tuck_in` step with a live-actor condition.
- **New clips:** `sig_kidding_around` (the wildest take; off the bed, through the door, into the laundry basket);
  Beryl stairs + in-bed pose; Hush tuck-in; herding tug upstairs.
- **Art:** bed with goat state; cold open (unicycle sold).
- **Audio:** bleat under the duvet, the take, laundry basket landing.
- **Scenarios:** Golden ×3 (verbs `lead_beryl` through rooms, `tuck_in`) · Rule proof **`herd_twice`** (lead her
  into the kitchen twice, he spots her twice → two detours; expect `herd_start: 2`) · **`herd_drops_activity`**
  (he abandons `paper` mid-read, resumes the loop at `bath`) · **`besotted_expires`** (20 s pass, she wanders back
  to the lane; the tuck-in fails its condition) · **`bleat_gives_nothing`** (her bleats never trigger a "?" on Hush
  directly) · Fairness `caught`, `chase`, `face_to_face`, `beryl_butts_hush` (now indoors) · Fun `meltdown`,
  **`bn_sealed`**, **`float_and_goat`** (IN OVER HIS HEAD → umbrella stand, then KIDDING AROUND on the next nap in
  one Night).
- **Risks / decisions:** leading a goat up the stairs is the longest escorted walk in v1; the 20 s Besotted timer
  from the potting bench to the bed needs a second apple at the landing: decided, another apple while Besotted
  restarts the 20 s (GDD §4.8). The measured loop is 114.9 s against the 80–95 s band: trim `bath` / `nap` with
  `dur_s` in wave 2.

### N8 — "Company's Coming" — `draft` → Act III wave
- **Premise:** Dame Delphine visits. He must stay dignified; everything that happens in front of her is worse.
- **Story beat:** Delphine to tea; he has rehearsed his bow to a cardboard cut-out of her. Last-week decor: stacked deckchairs, first leaves.
- **Stage:** whole house except the dressing room (9 rooms + porch; feathers come from the potting bench). Entry:
  gate. "?" 0.8 s (Delphine 1.0 s), tomatoes 3. He starts at the hall mirror.
- **His clock (~100 s est.):** mirror → answer_door (first loop only) → host_tea (14 s) → piano → tea → mirror.
  Delphine: chaise → piano → powders her nose upstairs 15 s → chaise.
- **Script:** R SPIT TAKE · R FAN MAIL · R witness ×2 (EMBARRASSED!) · O BELLOWS BLOWS (the DRY fix-up after SPIT
  TAKE) · O ACHOO-RIA! · BN DOUGH MAN witnessed (combo SOAKED + FLOURY in front of her; TEA FOR TWO optional).
  Re-arm: SPIT TAKE, BELLOWS BLOWS.
- **New pranks:** SPIT TAKE, FAN MAIL. **Items:** salt, feathers.
- **New sim (`s3-sim-cast`, part 3):** Delphine actor: scheduled doorbell, her loop, opera-glass sight (12 s cycle,
  1 s lift, 3 s look; 600 / 250 px), her own 1.0 s "?", the high C (nearest mirror cracks, Bellows Curious at
  chase speed), witness (EMBARRASSED! +5 / +10, Suppressed ending), `witness`, `combo_witnessed` line kinds,
  first-loop-only activities, THIRD_PARTY triggers for SPIT TAKE and FAN MAIL, DA TEA FOR TWO.
- **New clips:** Delphine rig + glide, sit, sip, spray, fan, glasses lift, high C, sing; `rx_drench_b`,
  `rx_feather_burst_b`, `beat_suppressed`; `act_answer_door`, `act_host_tea`; `combo_dough_man`.
- **Art:** chaise side table (tea tray, sugar bowl, fan), front door swing, cracked-mirror state; cold open
  (cardboard Delphine).
- **Audio:** doorbell, spray, "HORACE!", high C + glass crack, strained "ha-ha, my dear"; crowd "Ooooh".
- **Scenarios:** Golden ×3 · Rule proof **`delphine_high_c`** (Hush moves in her sight with the glasses up → high C
  → the hall mirror cracks → Bellows arrives Curious; no catch by her) · **`glasses_window`** (Hush crosses the
  parlour during the 9 s the glasses are down, unseen) · **`witness_twice`** (two reactions on the chaise, each
  Suppressed) · **`witness_offstage`** (the same prank while she powders her nose: a normal reaction, no bonus) ·
  **`tea_for_two`** (SPIT TAKE → she fans him dry → FAN MAIL) · Fairness `caught`, `chase`, `face_to_face` ·
  Fun `meltdown` (in front of her), **`dough_witnessed`** / **`bn_sealed`**.
- **Risks / decisions:** two NPCs with sight plus Bellows is the fairness-fuzz stress case; run the §4.7 fuzz on
  N8 before authoring art. Delphine's upstairs trip must not block Hush's stairs.

### N9 — "Tutu Much" — `draft` → Act III wave
- **Premise:** the dressing room opens; chases become scoring chances.
- **Story beat:** He tears down the Show poster and pins up his own: the hijack is official. The costume trunk is his old stage wardrobe.
- **Stage:** whole house (10 rooms + porch). Entry: gate. "?" 0.8 s, tomatoes 3. DRY → landing radiator. He
  starts in the dressing room; Delphine visits all Night.
- **His clock (~100 s est.):** cloak (eyes shut) → polish (specs on) → mirror (dressing) → host_tea (downstairs)
  → piano.
- **Script:** R TUTU MUCH · R AWARD-WINNING · R any Chase Trip · O RUG BURN · O PIPE DOWN! · O SPIT TAKE · BN TUTU
  MUCH witnessed by Delphine ("Take the tutu to tea"). Re-arm: TUTU MUCH.
- **New pranks:** TUTU MUCH, AWARD-WINNING. **Items:** tutu.
- **New sim:** `chase_trip` and `prank_witnessed {residue_witness}` line kinds; `blind` awareness while dressing;
  the DRY override to the landing (SPIT TAKE soak → upstairs past the rods → PIPE DOWN!); COSTUME residue carried
  into a witnessed scene.
- **New clips:** `rx_costume_burn_a` (70 f slow burn), `rx_avalanche_helmet_b`; `act_cloak`, `act_polish`,
  dressing-mirror variant of `act_mirror`; Hush costume-rail hide.
- **Art:** dressing room final (trunk, rail, mirror, trophy shelf, cloak dummy); cold open (poster).
- **Audio:** trophy bonks in rising pitch, muffled "PIPE DOWN!", tulle rustle.
- **Scenarios:** Golden ×3 · Rule proof **`chase_trip_required`** (provoke a chase, run him over the rods: the
  `trip` line completes) · **`chase_trip_penny`** (same over a coin spot, no Beryl: PENNY PINCHER fizzles mid-chase;
  RUG BURN is the Night's only trip, by design — GDD §7.2 N9) · **`tutu_to_tea`** (TUTU MUCH, skip the mirror
  fix-up before `host_tea`, she sees it → BN) · **`tutu_fixed_first`** (he reaches the dressing mirror first → no
  witness, BN stays open) · **`dry_upstairs`** (SPIT TAKE → radiator → RUG BURN on the way up at Steaming → PIPE
  DOWN!: a link-3 chain) · **`cloak_blind`** (Hush walks past while he dresses) · Fairness `caught`, `chase`,
  `face_to_face`, `delphine_high_c` · Fun `meltdown`, **`bn_sealed`**.
- **Risks / decisions:** the cut list merges N9 into N10 if late (PLAN §7); keep its unique clips (COSTUME_BURN,
  AVALANCHE B) first so a merge loses rooms, not jokes.

### N10 — "It Takes Two" — `draft` → Act III wave (Act finale)
- **Premise:** opening-night nerves. He starts every loop Irked; chains and Meltdowns come easy.
- **Story beat:** Dress rehearsal; opening-night nerves; windows crack the length of the street. Countdown reads 1.
- **Stage:** whole house. Entry: gate. "?" 0.8 s, tomatoes 3. `nerves: true`, `nerves_temper: 20`.
- **His clock (~110 s est.):** warmup → host_tea → tango (12 s) → bath → cloak.
- **Script:** R IT TAKES TWO (signature, always Suppressed) · R FAN MAIL · R MELTDOWN ×2 · O IN OVER HIS HEAD ·
  O TUTU MUCH · BN link-4 Running Gag. Re-arm: IT TAKES TWO, FAN MAIL, IN OVER HIS HEAD, TUTU MUCH.
- **New pranks:** IT TAKES TWO. **Items:** "their song" record.
- **New sim:** nerves (temper floor 20 at loop start; decay never below it); `chain {link}` line kind with
  `counts_while_sealed`; two Meltdowns in one Night without Exhausted locking the second out.
- **New clips:** `sig_it_takes_two` (the dip, the rip, the frozen grin); `act_tango` (two-character clip).
- **Art:** long johns are drawn; the record sleeve; cold open (windows crack down the street).
- **Audio:** the tango, RRRIP, her furious fan; nerves motif in the sneak stem.
- **Scenarios:** Golden ×3 · Rule proof **`nerves_start`** (temper reads 20 at tick 0 and after every loop
  wrap; Irked walk speed +5 %) · **`two_meltdowns`** (both land; Exhausted only after the second) ·
  **`specs_come_easy`** (Irked → Steaming after one M prank; stare strip appears sooner) · **`link4`** (SPIT TAKE →
  FAN MAIL → MIRROR fix-up chain → one more inside the fuse) · Fairness `caught`, `chase`, `face_to_face`,
  `delphine_high_c` · Fun **`bn_sealed`** (link-4 before the required lines; four re-arms).
- **Risks / decisions:** with a 20-point floor, the fairness rule "no unfair catch" has less margin: the specs-on
  share of each loop rises. Measure the specs-on fraction on the slow route; if above the Act III band, lower
  `nerves_temper` to 15 rather than changing the activity list.

### Gala — "The Comeback" — `draft` → Act III wave
- **Premise:** everyone at once. The street is the Stalls; he rehearses on a garden stage under a spotlight.
- **Story beat:** Show night. The street brings deckchairs into his garden; he booms PIPE DOWN! at his own audience. The pond. At the curtain call the box is tipped out and every toy goes home, her unicycle first; dripping, he bows too, and the street applauds him for once.
- **Stage:** whole house + garden stage (5000–5800, wings 5850). Entry: gate. "?" 0.8 s, tomatoes 3,
  `max_minutes: 8` (hard cap; the solver fails the build above it).
- **His clock (~120 s est.):** warmup → host_tea → feed_beryl → stroll → rehearse (panto, 14 s) → mirror.
- **Script:** R SPOTLIGHT STEALER · R PENNY PINCHER · R SPIT TAKE · R MIRROR, MIRROR · O ALLEGRO-GO-GO! · O FAN
  MAIL · BN CURTAIN CALL (Double Act: bends for a thrown rose → Beryl → pond). Re-arm: SPOTLIGHT STEALER.
- **New pranks:** SPOTLIGHT STEALER. **Items:** none new.
- **New sim:** the spotlight rule (GDD §7.2 Gala: the lit stage sees Hush as always moving, Bellows on stage never
  looks back, Delphine's glasses re-aim at the light); Beryl and Delphine in the same Night; crowd tomatoes and roses as
  cosmetic events; the 8-minute cap as a solver invariant.
- **New clips:** `sig_spotlight_stealer` (fourth wall: he bows to the real Stalls); `act_rehearse`; the CURTAIN
  CALL bend-and-headbutt into the pond; Hush stage bow; the Stalls' standing finale.
- **Art:** garden stage, spotlight, wings, deckchairs; cold open (the street arrives).
- **Audio:** his comeback aria (full), tomato volley, the finale crowd tier, curtain music.
- **Scenarios:** Golden ×3 with **`duration_s` max 480 on every route** · Rule proof **`spotlight_rule`** (per the
  decision below) · **`everyone_at_once`** (Delphine's glasses, Beryl's bend rule and his specs all active in the
  garden within one loop; no unfair catch) · Fairness `caught`, `chase`, `face_to_face`, `beryl_butts_hush`,
  `delphine_high_c` · Fun `meltdown`, **`curtain_call_da`**, **`bn_sealed`**, **`mirror_r3`** (returning signature,
  second variant).
- **Risks / decisions:** (1) The spotlight rule is defined (GDD §7.2 Gala); it still needs its sim scenario test
  before art. (2) The 8-minute cap with a 91 s loop allows five loops; the ideal route must finish in three.

---

## 5. Build order and dependencies

The waves follow PLAN Stage 3 but are stated per level, with the slice's unfinished clips as wave 0. Each wave ends
with the solver run on its Nights, screenshots, and the owner check PLAN §4 names.

| Wave | Levels | Must land first | Unlocks |
|---|---|---|---|
| **0 — finish the slice** ✅ **done 2026-11-02** | P, N1, N2 | 118 clips (Bellows 98, Hush 34, Figgis 5 — the slice manifest reports 0 missing), the six new solver scenarios, strict lints green | the Fun Gate on real animation; every later Night reuses these clips |
| **1 — Act I** | N3, N4 | upstairs art + props; 8 reaction clips + IN OVER HIS HEAD; 5 activity clips; Meltdown a/b/c, Exhausted, 4 T3 beats, POODLE beat; loop retune (N3, N4); solutions | owner check Act I |
| **1′ — sim cast (parallel)** | — | Beryl, panto, herding, Delphine, witness, THIRD_PARTY, line kinds `panto/herd/witness/combo_witnessed/prank_witnessed/chase_trip/chain`; a sim scenario test per rule | wave 2 and 3 solutions |
| **2 — Act II** | N5, N6, N7 | Beryl rig + clips; conservatory + garden art; 4 reaction clips + 2 penny bends + GRAND EXIT + KIDDING AROUND; 5 activity clips; 5 panto state clips; solver verbs `drop_item`, `lead_beryl`, `tuck_in`; solutions | owner check Act II |
| **3 — Act III + Gala** | N8, N9, N10, Gala | Delphine rig + clips; dressing room + stage art; 4 reaction clips + IT TAKES TWO + SPOTLIGHT STEALER + Suppressed; 6 activity clips; 3 combo beats; the spotlight rule; remaining 9 cold opens; solutions | owner check Act III + Gala; Stage 4 |

Order inside a wave: **sim rule → solution routes on greybox → clips → art → audio → `final`.** Routes on greybox
catch pacing and geometry problems while they are cheap to fix; clips are the expensive part and should be authored
against a Night whose timings have stopped moving.

Cost control: before wave 1, time one prank end to end in wave 0 (art → clip → sound → lint → GIF) and record it in
`docs/PROGRESS.md` (PLAN §4). With 73 Bellows clips outstanding, that number sets the schedule.

---

## 6. Decisions taken (2026-11-01; iterate if play says otherwise)

1. **Act I loop rule upstairs:** trimmed, not re-framed. N3 uses `bath` 12 / `dress` 5 / `nap` 12 s and measures
   58.9 s; N4 uses `warmup` 6 / `paper` 6 / `bath` 10 / `nap` 8 s and measures 64.6 s, so GDD §2.4 rule 5 now allows
   65 s for the two-floor Act I finale. Mechanism: a loop-entry `dur_s` override (TECH §4.6) and `at_end` USE hooks,
   guarded by `tests/solver/test_loop_lengths.gd` and the validator.
2. **Besotted across the house:** another apple while Besotted restarts the 20 s (GDD §4.8). Sim work in wave 1′.
3. **The spotlight rule:** the lit stage is a trade (Hush always "moving" in the light; Bellows on stage never looks
   back; Delphine's glasses re-aim at it) — GDD §7.2 Gala.
4. **Knock-ons into gated STEP pranks:** the anger gate is waived for knock-ons; every other condition holds
   (GDD §5.5). In the sim and tested.
5. **N9's Chase Trip:** RUG BURN is the only trip that Night, by design; the hint points at the stair rods (GDD §7.2).
6. **Wave 0 before the Fun Gate:** PLAN §3 and §4 updated; the slice's clips come first.

**Story:** the Nights are now one summer in three chapters (GDD §7.0): the countdown poster, the CONFISCATED box
that fills and is finally tipped out, and one decor set per Act. Each sheet above carries its story beat.
