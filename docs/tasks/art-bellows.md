# Stage-1 brief: `art-bellows` — Horace Bellows, the loudest man alive

He is the show (GDD pillar 1). Every laugh in the game lands on his face and body, so he must be a superb cutout:
a pompous barrel of a man whose bouffant, sideburns, specs and cravat all *act*, whose face can pop into a wild
take and hold a slow burn, and who can be soaked, floured, frazzled, feathered and dressed in a tutu — cleanly, on
the same rig. You author everything as SVG by script.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §1.2 (his look, size, colours, personality), §4.5 (temper tiers: his body is the meter), §5.4
   (residues and combos — the looks you must draw), §5.7 (the prank catalogue: what happens to him), §5.8 (the
   reaction archetypes), §9.1–§9.4 (art direction, line weights, readability, takes, the P0 animation list your poses
   must cover).
3. `docs/TECH.md` §4.7 (rig.json / poses.json / faces.json — your output format, with a Bellows example), §13, §14.
4. Quality/SVG discipline reference: `/home/user/ideaboard/booby/game/art/STYLE.md` and
   `/home/user/ideaboard/booby/tools/art/booby_art_style/{svgk.py,raider.py,rig_build.py}` (port helpers into
   `tools/art/bellows/`; never reuse Booby characters).
5. `docs/research/comedy.md` §1 (takes, squash & stretch, slow burn, dignity recovery), §5.3 layer 5 (face slots).

## 2. You own
- `game/art/chars/bellows/**` (+ `_src/` with `.gdignore`)
- `game/data/rigs/bellows/{rig.json,poses.json,faces.json}`
- `tools/art/bellows/**` (generators, validator, Python FK preview)
- `game/tests/art/test_bellows_rig.gd`
- `docs/review/art-bellows/`
The rig player is being built in parallel by `rig`; preview with your own Python FK compositor (`rsvg-convert`,
Pillow, numpy). Hush is drawn in parallel by `art-hush`; use her files for a scale comparison if present.

## 3. Specs
### 3.1 SVG rules (binding; GDD §9.1)
As in TECH/GDD: presentation attributes only; `path/rect/circle/ellipse/line/polyline/polygon/g`; no filters, masks,
`<text>`, `<image>`, CSS, `<use>` chains; ≤ 10 colours per file; 3 px margin; 1-decimal coordinates; canvas = display
size at zoom 1.0. Ink `#1B2340`, **6 px** character outlines, **3.5 px** inner detail, round joins; one flat shade
tone per shape (lower/right), optional highlight capsule.

### 3.2 Bellows (rig id `bellows`, 380 px tall at zoom 1.0, head ≈ 140 px, feet origin)
- **Silhouette:** "a dandelion clock on a barrel" — barrel torso on tiny legs, a silver bouffant `#D9DCE6`, mutton-chop
  sideburns, specs on a chain. Plum jacket `#7B3F8C`, gold cravat `#E8B33A`, cream shirt front, tartan slippers.
  Skin peach `#F4C9A8`.
- **Parts (binding names):** `torso` (root: barrel + jacket), `belly` (spring on `sy`, k 300, c 12, clamp 0.08),
  `coat_tails` (spring rot), `cravat` (spring rot, k 220, c 10), `head`, `bouffant` (7 textures: `neat, flipped`
  (over his eyes), `frazzled, wet, floured, feathered, poodle`; spring rot), `sideburn_l/r` (textures `flat, bristle,
  puffed, wet`; springs), `hand_l/r` (6 textures: `open, fist, point, grip, wag, conduct`), `foot_l/r` (`flat,
  tiptoe`), limb bones `arm_upper_l/r, arm_lower_l/r, leg_upper_l/r, leg_lower_l/r` (`draw: limb:…`; plum sleeves,
  short plum legs, width 26–30, outline 6). Sockets: `hand_l:grip`, `hand_r:grip`, `head:specs`, `head:hat`,
  `torso:chain`. Props in the rig: `specs` (states `dangling` on the chain, `on` his nose, `buttered`, `magnifier`),
  `teacup`, `newspaper` (`closed, open`), `comb`, `baton`, `phone_handset`, `kipper_held`, `pickled_onion`,
  `kettle_lid`, `jelly_helmet`, `sausage_boa`, `megaphone` (cold open).
- **Face** (anchor `head`): `eyes` × 10 (`open, half, closed, wide, pinpoint, angry, spiral, balloon, squint,
  teary`), `pupils` (range [6, 4]; ≥ 10 px), `brows` × 6 (`neutral, up, angry, worried, sly, one_up`; 8 px thick —
  they carry the emotion), `mouth` × 10 (`closed, smile, smug, O_small, O_mid, O_big` (the singing O in 3 sizes),
  `scream, grit, wavy, open`), overlays `sweat, vein, steam_l, steam_r, blush`. Eye whites ≥ 24 px; open mouth ≥ 40 px
  wide.
- **`faces.json` presets (≥ 16):** `neutral, smug, sing_small, sing_mid, sing_big, suspicious, shock, wild_take,
  furious, sneeze_build, sneeze_choo, dazed, slow_burn, strained_grin` (the SUPPRESSED beat), `sulk, terrified,
  asleep, blissful`.
- **Temper tint** (`tint`): parts `head, hand_l, hand_r`; four modulate colours so the rendered skin reads peach →
  pink → red → beetroot `#B8324B` (tune by rendering; the Livid face must still read expressions).
- **Residues** (`residues` map + overlay SVGs sharing part pivots): `SOAKED` (wet bouffant + sideburns, drip overlays
  on head and torso), `FLOURY` (floured bouffant + white overlays for head/torso/hands), `STICKY` (treacle/jelly drips,
  a spoon stuck to `hand_r`), `SQUEAKY` (a tiny tell: pinched lips overlay + helium hiccup puff), `FRAZZLED` (frazzled
  bouffant, singed brows; `flipped` when blind), `FEATHERED` (feather clusters on head/torso/limbs), `COSTUME`
  variants (`jelly_helmet`, `tutu_tulle`, `tutu_chandelier` with candles, `trophy_helmet`, `long_johns` (spotty),
  `hedge_twigs`, `umbrella_stand`). **Combos:** `dough_man` (lumpy dough overlay), `poodle` (bouffant `poodle`),
  `chicken` (feather suit + comb on the bouffant), `mad_maestro` (wild frizz + baton in hand).
- **Poses (`poses.json`, ≥ 50)** covering every P0 Bellows clip in GDD §9.4: `b_stand, b_breath_in/out,
  b_fidget_admire`; strut `b_strut_contact_l/pass_l/contact_r/pass_r` (belly leads, chin up), `b_irked_walk_a/b`,
  `b_stomp_a/b`; `b_turn_mid, b_door_reach, b_stairs_a/b`; activities `b_sing_breath, b_sing_small, b_sing_big` (arm
  flung out), `b_tea_pour, b_tea_spoon, b_tea_sip, b_tea_sniff`, `b_jar_strain`, `b_fridge_reach`, `b_sink_hands`,
  `b_sit_read, b_lever_pull`, `b_bellows_pump`, `b_preen, b_lean_in, b_specs_lift`, `b_phone_pompous`, `b_clock_wind`,
  `b_hunt_peer_l/r`; states `b_suspicious, b_dt_away, b_dt_back, b_take_antic, b_take_accent` (wild: arms V, body
  tall), `b_look_behind, b_chase_a/b, b_wheeze, b_grab, b_lecture_hold, b_lecture_wag_a/b, b_melt_stomp_up/down,
  b_exhausted_sit, b_slow_burn, b_dignity_straighten, b_pardon_pat, b_bonk_door`; reactions `b_sneeze_ah1/ah2/ah3,
  b_sneeze_false_stop, b_sneeze_choo, b_sneeze_recoil, b_dazed_sit, b_dizzy_a/b, b_launched, b_dangle, b_slip_windmill,
  b_fall_sit, b_blind_arms_out, b_fish_slap_recoil, b_cling`. Tags + one-line `silhouette` notes on every take.
  Poses must read in solid black at 50 px — the accent pose's bounding box differs ≥ 15 % from its anticipation.

## 4. Tools (`tools/art/bellows/`)
Generators for every SVG (parametric, repeatable); `validate.py` (SVG rules, TECH §4.7 schema, file refs, pose
parts, mirror pairs, residue/combos completeness); `preview.py` (FK compositor as in `art-hush`: rest pose; poses
sheet with 50 px silhouettes; expressions sheet (head at 2×, every preset); **residue sheet** (rest pose × each of the
7 residues, the COSTUME variants and the 4 combos); **temper ramp** (the same take at the 4 tints); props sheet; a
scale comparison beside Hush (her files if present, else a 340 px grey placeholder); a phone-scale copy (1200 px
wide) of every sheet).

## 5. Tests
`game/tests/art/test_bellows_rig.gd`: JSON parses; required keys; all referenced files exist; ≥ 20 parts; 7 bouffant
textures; 6 hand textures ×2; face slot counts; ≥ 16 presets; ≥ 50 poses; residues for all 7 kinds + 4 combos;
soft-hook `RigDef.load` + `PoseLib` with zero errors when `res://view/rig/rig_def.gd` exists, else `skip()`.

## 6. Verify and look
```
python3 tools/art/bellows/validate.py
python3 tools/art/bellows/preview.py --out /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-bellows/
tools/scripts/test_game.sh art-bellows -- art/test_bellows
```
Read every sheet, especially at phone scale. Does the wild take *pop*? Does the slow burn read as a stare at the
audience? Is he pompous and funny, not grotesque? Do residues read instantly (soaked vs floured vs frazzled) and still
leave his face readable? Iterate. Copy finals to `docs/review/art-bellows/` with `index.md`.

## 7. Acceptance
- [ ] Parts, faces, presets, props, tint, residues, costumes, combos and ≥ 50 poses delivered with the binding names.
- [ ] Validator + GDScript test green; SVG rules; ≤ 10 colours per file.
- [ ] Sheets rendered and looked at (poses + silhouettes, expressions, residues, temper ramp, props, scale).
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-bellows.md`: files, part/pivot table, weaknesses, requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-bellows/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-bellows.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh art-bellows [-- filter]`, `tools/scripts/sandbox.sh art-bellows …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] art-bellows [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/art-bellows/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
