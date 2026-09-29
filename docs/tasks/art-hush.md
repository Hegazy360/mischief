# Stage-1 brief: `art-hush` — Hush (+ Pip skin), Clarence, Old Figgis, the Stalls

You are drawing the player character of a slapstick game the owner will judge on his phone. Hush must be
instantly readable at phone size, **warm and appealing (never a creepy clown)**, and built as a clean cutout rig
that animators can pose into ridiculous freezes and snappy takes. You also draw her rubber chicken, the prompter
who gives hints, and the audience silhouettes. Everything is SVG authored by script — you are the artist.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §1.2 (cast: sizes, colours, silhouettes, the warmth rule, the Pip fallback), §2.3 (what she does in
   the first minute), §3.4 (hiding: eyes in the dark), §9.1–§9.4 (art direction, line weights, readability
   minimums, faces, timing, the P0 animation list you must cover with poses).
3. `docs/TECH.md` §4.7 (rig.json / poses.json / faces.json — your output format), §13, §14 (rig ids, clip names).
4. Style reference (quality bar, SVG discipline): `/home/user/ideaboard/booby/game/art/STYLE.md` and its
   generators `/home/user/ideaboard/booby/tools/art/booby_art_style/{svgk.py,raider.py,rig_build.py,boo_poses.py}`
   — port helpers into your own `tools/art/hush/`, do not import from Booby at runtime. Never reuse Booby
   characters or names.
5. `docs/research/comedy.md` §1.2–§1.3 (takes, squash, readable poses), §5.1 (rig choice).

## 2. You own
- `game/art/chars/hush/**` (incl. `pip/` skin), `game/art/chars/figgis/**`, `game/art/chars/stalls/**`
  (+ `_src/` generator folders with a `.gdignore`)
- `game/data/rigs/hush/{rig.json,poses.json,faces.json}`, `game/data/rigs/figgis/**`, `game/data/rigs/stalls/**`
- `tools/art/hush/**` (generators, the Python FK preview, the validator)
- `game/tests/art/test_hush_rigs.gd`
- `docs/review/art-hush/`
The rig *player* is being built right now by `rig` (TECH §5.3); you cannot rely on it. Preview your rig with your
own Python FK compositor (`rsvg-convert` + Pillow + numpy are installed). Bellows is drawn in parallel by
`art-bellows`; for the cast sheet use his files if present, else a grey 380 px placeholder silhouette.

## 3. Specs
### 3.1 SVG rules (binding; GDD §9.1)
Presentation attributes only; elements `path, rect, circle, ellipse, line, polyline, polygon, g`; no filters, masks,
`<text>`, `<image>`, CSS, `<use>` chains; ≤ 10 colours per file; 3 px canvas margin; coordinates to 1 decimal; canvas
= display size at zoom 1.0 (`width/height` = pixels); files < 12 KB typical. Ink `#1B2340`, round joins/caps.
Character outlines **6 px**, inner detail **3.5 px**; one flat shade tone per shape on the lower/right (light from
the top-left); an optional white highlight capsule at 0.55 opacity.

### 3.2 Hush (rig id `hush`, 340 px tall at zoom 1.0, head ≈ 130 px, feet origin)
- **Look:** lanky; tilted cherry-red beret `#E23B4E` (spring part); white face paint `#FFF6EA` with rosy cheeks
  `#FF9AA2`, **big round pupils (≥ 14 px)**, a small teardrop, **smiling default mouth**, thin eye paint, no black
  lips; Breton stripes navy `#2B3566` / white; red braces; navy trousers; flat shoes `#3A3050`; **huge white gloves**
  (1.6× hand size — the gloves act). Clarence rides in her braces.
- **Parts (names are binding — the Pip skin and all clips depend on them):** `pelvis` (root), `torso` (stripes +
  braces), `head`, `beret` (spring: rot, k 180, c 9, clamp 25), `hand_l`, `hand_r` (8 textures each: `wall`,
  `point`, `pinch`, `fist`, `open`, `thumbs_up`, `shush`, `wave`), `foot_l`, `foot_r` (textures `flat`, `tiptoe`),
  limb bones `arm_upper_l/r`, `arm_lower_l/r`, `leg_upper_l/r`, `leg_lower_l/r` (`draw: "limb:…"`; limbs
  `arm_l/arm_r` striped-sleeve colour, `leg_l/leg_r` navy, width 22–26, outline 6). Sockets: `hand_r:grip`,
  `hand_l:grip`, `torso:braces` (Clarence), `head:hat`. Mirror pairs `_l/_r`.
- **Face** (anchor `head`): `eyes` × 8 (`open, half, closed, wide, happy, worried, squint, wink`), `pupils`
  (range [6, 4]), `brows` × 5 (`neutral, up, worried, sly, determined`), `mouth` × 8 (`smile, grin, O, shh,
  grimace, wavy, laugh, puffed`), overlays `blush`, `sweat`, `tear`. `faces.json` presets ≥ 12: `neutral` (smile),
  `grin`, `snicker`, `shock`, `fear`, `hold_breath`, `smug`, `wince`, `determined`, `sad`, `busted`, `wink`,
  `statue` (serene, eyes half).
- **Hidden look:** a separate `hidden_eyes.svg` (two eyes + gloved fingertips in darkness) for hiding spots.
- **Poses (`poses.json`, ≥ 40)** covering every P0 Hush clip in GDD §9.4: `h_stand`, `h_breath_in/out`,
  `h_fidget_look`, tiptoe scurry `h_tip_contact_l/pass_l/contact_r/pass_r`, run `h_run_contact_l/pass_l/…`,
  `h_turn_mid`, `h_door_reach`, `h_stairs_a/b`, `h_rummage_a/b`, `h_pickup`, tinker `h_tinker_q_a/b`,
  `h_tinker_s_a/b`, `h_tinker_b_a/b`, `h_brow_wipe`, `h_snicker_a/b`, `h_glance_stalls`, `h_dive_antic`, `h_dive`,
  `h_pop_out`, **8 freeze statues** `h_freeze_1..8` (e.g. the thinker, a teapot, a flamingo, a discus thrower, a
  hat stand, a ballerina, a lamp, a startled vase — each absurd and readable in silhouette), `h_squeak`,
  `h_climb_a/b` (mime ladder at the window), `h_busted` (eyes pop, jump), `h_dangled_a/b` (lifted by the braces, feet
  pedalling), `h_doorstep_sit`, `h_tomato_splat`, `h_bow_a/b`, `h_wink`, `h_victory`. Tag each (`idle, loco,
  tinker, freeze, take, …`) and give every take/freeze a one-line `silhouette` note.
### 3.3 Pip skin (fallback, `game/art/chars/hush/pip/`)
An 11-year-old "Statues" champion: red beanie, striped jumper, mittens with the same 8 shapes, no face paint (warm
skin tone). **Identical part names, canvases and pivots** so every clip plays unchanged (`setup("hush", "pip")`).
Deliver head, torso, hands, feet, limb colours, face slot variants where they differ.
### 3.4 Clarence (prop `clarence` in Hush's rig)
Rubber chicken, yellow `#FFD23F`, red comb, 90 px; states `limp`, `squeezed` (squashed), `stretched` (wheeze),
`smitten` (heart eyes, for the CHICKEN combo gag); sockets `torso:braces` and `hand_r:grip`.
### 3.5 Old Figgis (rig id `figgis`, a HUD bust for a 128 px chip)
Hood `#3A3050`, tiny head `#F4C9A8`, huge ears (springs), spectacles on his nose, hands holding a cue card (the card
is a blank prop; the UI draws item icons onto it). Face: eyes × 3, mouth × 3; presets `psst`, `point`, `shh`, `proud`.
### 3.6 The Stalls (id `stalls`)
24 head/hat silhouettes (bowlers, beehives, a shiny bald head, a toddler on a shoulder, feathered hats, curlers,
a top hat …), each 40–110 px tall, 3 frames: `rest`, `laugh` (head up, mouth open silhouette), `lean` (toward a
neighbour), plus one `tumble` sequence (4 frames) for the T4 fall. Single flat fill `#2A1E3A` (alpha is applied at
runtime), no outline. `game/data/rigs/stalls/stalls.json`: `{"version":1,"heads":[{"id","w","h","frames":{…}}],
"tumble":[…]}`.

## 4. Tools you write (`tools/art/hush/`)
- Generators (Python) that emit every SVG from parameters (so edits are repeatable), in `_src/` or
  `tools/art/hush/`.
- `validate.py`: SVG rules (§3.1), rig.json/poses.json/faces.json schema (TECH §4.7), every file referenced
  exists, every pose's parts exist, mirror pairs resolve, Pip skin names/pivots identical. Exit code ≠ 0 on failure.
- `preview.py`: a minimal FK compositor (rasterise parts with `rsvg-convert`, place by pivot/offset/rotation, draw
  hose limbs with round caps) that renders: rest pose; a poses sheet (every pose labelled) with 50 px black
  silhouettes beside each; an expressions sheet (head at 2×, every preset); the Pip comparison (same poses side by
  side); Figgis presets; the Stalls strip at rest and laughing; the **cast sheet** (Hush, Pip, Figgis, the Stalls
  strip and Bellows or his placeholder, to scale, at phone size 1200 px wide); `warmth.png` (Hush at 50 px silhouette
  + 96 px face crops in neutral / snicker / shock).

## 5. Tests
`game/tests/art/test_hush_rigs.gd`: the three JSON files parse, required keys exist, every `file` path exists
(`FileAccess.file_exists`), parts count ≥ 18, 8 glove textures on both hands, ≥ 40 poses, ≥ 12 face presets,
Pip skin parity; if `res://view/rig/rig_def.gd` exists (soft hook), `RigDef.load` + `PoseLib` load with no errors,
else `skip()` that part.

## 6. Verify and look (iterate until it's genuinely good at phone scale)
```
python3 tools/art/hush/validate.py
python3 tools/art/hush/preview.py --out /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-hush/
tools/scripts/test_game.sh art-hush -- art/test_hush
```
Read every PNG you render. Judge at the phone-scale copies: does she read as a warm, cheeky mime at 50 px? Do the
freezes read as jokes in silhouette? Are the gloves expressive? Is anything muddy? Fix and re-render. Copy the final
sheets to `docs/review/art-hush/` with an `index.md` (what each shows; your self-assessment against the warmth
rule). The cast sheet goes to the owner at Gate 0.

## 7. Acceptance
- [ ] All parts, faces, poses, Pip skin, Clarence, Figgis, Stalls delivered with the binding names.
- [ ] `validate.py` and the GDScript test green; SVG rules respected; colour counts ≤ 10.
- [ ] Sheets rendered and looked at: poses + silhouettes, expressions, Pip comparison, Figgis, Stalls, cast sheet,
      warmth check.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-hush.md`: files, part/pivot table, known weaknesses, requests (e.g. to
      `rig` if a feature you need is missing).

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-hush/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-hush.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh art-hush [-- filter]`, `tools/scripts/sandbox.sh art-hush …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] art-hush [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/art-hush/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
