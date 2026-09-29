# Stage-1 brief: `art-house` — the house (geometry + ground-floor art), props, icons, the stage

The house is the stage set. You own both its **geometry** (`house.json`: rooms, doors, stairs, stations, hotspots —
the data the sim walks on and the lints check) and its **look** (a cosy, pastel dollhouse cut in half, framed as a
theatre set, where every interactable prop pops). The vertical slice plays in the hall, parlour and kitchen; those
must reach final quality. The rest of the house gets correct geometry and tasteful placeholder art.

## 1. Read first
1. `/home/user/mischief/CLAUDE.md`
2. `docs/GDD.md` §1.3 (stage framing), §3.5 (hotspots, highlighting, badges, hit boxes), §3.7 (camera framing:
   one floor fills the screen, 190 px of the floors above/below show), §4.1.1 (activity library: stations), §5.2
   (containers and items), §5.7 (the prank catalogue: every prop and its rigged look), §7.1 (THE house: room widths,
   station order and x, hiding spots, doors, stairs, entries), §9.1 (art direction, palettes, line weights by layer).
3. `docs/TECH.md` §2 (world coordinates), §4.1 (`house.json` — your output), §5.4 (how the view uses props and
   outlines), §9 (texture budgets), §10.5 (hotspot lint rules), §14 (**canonical ids — use exactly these**).
4. SVG quality reference: `/home/user/ideaboard/booby/game/art/STYLE.md`, `/home/user/ideaboard/booby/game/art/
   rooms/`, `props/` and the generator helpers in `/home/user/ideaboard/booby/tools/art/booby_art_style/svgk.py`
   (port helpers into `tools/art/house/`; never reuse Booby assets).

## 2. You own
- `game/data/house/house.json`
- `game/art/house/**` (`rooms/`, `props/`, `stage/`, `items/`, + `_src/` with `.gdignore`), `game/art/icons/**`
  (`activities/`), `game/art/STYLE.md`
- `tools/art/house/**`
- `game/scenes/dev/house_preview/**` (your own preview scene — independent of the `view` task)
- `game/tests/art/test_house.gd`
- `docs/review/art-house/`
Parallel tasks: `content` references your hotspot/station ids (they use TECH §14 — so must you); `view` will render
your rooms/props through `house.json`; `solver` writes the official hotspot lint (you write your own checker too).

## 3. Specs
### 3.1 `house.json` (TECH §4.1) — all 10 rooms now
- Floors: ground line y = 0, upper y = −700; interior 640, slab 60.
- Rooms and x ranges exactly as GDD §7.1: porch 0–500, hall 500–1500, parlour 1500–2800, kitchen 2800–3900,
  conservatory 3900–4700, garden 4700–6200; landing 1000–1800, bathroom 1800–2800, bedroom 2800–3700,
  dressing 3700–4500. `outdoor: true` for porch and garden.
- Links (TECH §14): doors `front_door` (x 500), `back_door` (x 3900); doorways at every other shared wall; `stairs`
  hall foot x 1450 ↔ landing head x 1050 (`hush_s` 1.0, `bellows_s` 1.8).
- Stations (TECH §14) with `x`, `stand_x`, `facing`, `kinds`; the hall mirror has `frame_x` (Hush's stand-in point).
- Hotspots: **every** id in TECH §14 with `kind`, `room`, `use_x`, `facing`, hit `rect`, `in_use_by`, `station` where
  relevant, and `art` state paths. Hit boxes ≥ 144 × 144, ≥ 24 px apart, never overlapping; shared objects stacked
  vertically (fridge / fridge shelf, pantry shelf / curtain, clock face / case, airing cupboard / boiler valve, bath taps
  / bath, bed / under-bed / pillow, stair rods / stair foot). Station x within 80 px of GDD §7.1.
- `landings` per room (reaction landing targets: kitchen `sink, table`; parlour `log_basket, chandelier`; hall
  `coat_stand, umbrella_stand, front_door`; porch `hedge`; conservatory `hamper`; garden `pond, roses, compost`;
  landing `stair_head`; bathroom `laundry_basket`; bedroom `bed, doorway`; dressing `costume_rail`).
- `quake_props` (Meltdown drops, view-only: parlour `picture_frame, vase, portrait`; kitchen `pans`; hall `hats`),
  `entries` (`window` kitchen 3800, `gate` garden 6150, `doorstep` porch 350).

### 3.2 Room art
- Each room: `rooms/<room>_bg.svg` (walls with the room's wallpaper colour + one tiling pattern, windows, skirting,
  back furniture that isn't interactive, floorboards, the slab edge) at `width × 700` px, and `rooms/<room>_fg.svg`
  (only what must occlude characters: door jambs, the slab lip). Architecture lines **3 px `#3A3050` at 80 %**, fills
  20–30 % desaturated pastels (GDD §9.1 palette), light from the top-left.
- **Final quality now:** porch (exterior: sky, a strip of Hush's house No. 9 with her window, the doorstep, a hedge),
  hall, parlour, kitchen. **Greybox now** (tasteful flat blocks with correct silhouettes of the big furniture, the
  right wallpaper colour, correct doorways — they are visible as "unlit backstage" above/beside the slice): landing,
  bathroom, bedroom, dressing, conservatory, garden.
- **Locked rooms** are drawn by the view as an unlit set (dimmed, blue-grey); provide `stage/velvet_rope.svg`
  (stanchions + rope) for roped-off doorways.

### 3.3 Props for the slice (hall, parlour, kitchen) — every state + a pre-baked outline sprite
Interactables use **5 px** outlines, set dressing 4 px. For each hotspot provide `idle` and, where relevant, `open`,
`rigged` (a visible tell: the squeaker in the kettle spout, the loosened jar lid, a glinting clock key, the recliner
spring poking out, the brake wedge on the floor, the missing mirror glass, flour in the bellows nozzle…), `spent`,
`occupied` (hiding spots with Hush's eyes), and `<name>_ol.svg` (the same silhouette grown 4 px, flat white, for the
pulsing outline). Slice list:
- Hall: front door (closed/open), coat cupboard, CONFISCATED box (a cardboard box stencilled with a big red
  "CONFISCATED" drawn as shapes, not `<text>`), phone table + phone, piggy bank, cheval mirror (glass / no glass),
  grandfather clock (face = rig point, case = hiding), stairs (background band) + stair rods, coat stand, umbrella stand.
- Parlour: gramophone (+ speed lever), piano (+ brake wedge; behind-the-piano hiding), recliner (+ spring), newspaper,
  fireplace + bellows + log basket, chandelier (+ chain), mantel with the Prologue vase (idle / smashed), Bellows'
  portrait (decor), chaise + side table with tea tray and fan (needed in Act III; draw now if time allows).
- Kitchen: tea counter with kettle, honey jar + pepper pot, pickle shelf + onion jar, fridge (closed / open) + fridge
  shelf, table with a long tablecloth (hiding), pantry (shelf container + curtain hiding), sink + spray tap, window
  (Hush's entry), back door.
- Put every room's props on as few canvases as sensible; the view packs one atlas per room (≤ 2048² at 2×).

### 3.4 Icons
- `house/items/<item>.svg` × 16 (TECH §14 item ids) at a 128 px canvas: bold, readable at 64 px, 6 px outline.
- `icons/activities/<activity>.svg` × 27 (every activity id) + detours `fixup_dry, fixup_sink, fixup_honey,
  fixup_mirror, curious, herd_beryl, search` at an 88 px canvas (thought-bubble icons: a teacup, a gramophone, a bath…).

### 3.5 The stage
`stage/curtain.svg` (full-screen red velvet `#B3122E` folds with gold trim `#E8B33A`, 1920 × 1080, tileable
horizontally for wide phones), `stage/curtain_valance.svg`, `stage/proscenium_l.svg` / `_r.svg` (gilded frame at the
house's far ends), `stage/apron.svg` (the stage floor + footlight cups below the ground floor, tileable, 190 px tall),
`stage/footlight_glow.svg` (warm additive glow), `stage/flies.svg` (above the upper floor: roof silhouette, rigging
ropes), `stage/vignette_top.svg` (cool top vignette).

### 3.6 `game/art/STYLE.md`
Port Booby's STYLE.md into a binding file for this game: canvas/file rules, allowed SVG features, line weights by
layer (characters 6, interactables 5, set dressing 4, architecture 3 @ 80 %), palettes (GDD §9.1), shading, prop state
and outline-sprite conventions, naming, the "readable at phone scale" checks. Characters follow the same file.

## 4. Tools and preview
- `tools/art/house/`: generators for every SVG (parametric, repeatable), `lint_rects.py` (≥ 144, 24 px gaps, no
  overlaps, stacked shared objects, ids ⊇ TECH §14, stations within 80 px of GDD §7.1), `validate_svg.py` (SVG rules).
- `game/scenes/dev/house_preview/HousePreview.tscn` + script: builds rooms and props from `house.json` with plain
  Sprite2D nodes; user args `--room=<id> --zoom=1.0|0.5 --rects --state=rigged|idle|occupied --badges`; draws hit rects
  and mock 56 px badges when asked; camera framed like the game (one floor fills the height).

## 5. Tests
`game/tests/art/test_house.gd`: `house.json` parses; every TECH §14 room/link/station/hotspot id is present; every
`art` path exists; rect rules; stairs and doors reference real rooms; landings and entries inside their rooms.

## 6. Verify and look
```
python3 tools/art/house/validate_svg.py && python3 tools/art/house/lint_rects.py
tools/scripts/test_game.sh art-house -- art/test_house
tools/scripts/shot.sh res://scenes/dev/house_preview/HousePreview.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-house/kitchen.png 30 art-house -- --room=kitchen
tools/scripts/shot.sh res://scenes/dev/house_preview/HousePreview.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-house/kitchen_rects.png 30 art-house -- --room=kitchen --rects --badges
tools/scripts/shot.sh res://scenes/dev/house_preview/HousePreview.tscn /tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-house/overview.png 30 art-house -- --room=parlour --zoom=0.5
```
Read every screenshot at 1200×540 (a real 20:9 phone). Do props read at a glance? Do rigged tells read? Is the room
pastel enough that characters will pop? Is anything cluttered? Iterate. Final shots (each final room idle + rigged +
rects, the overview, the greybox rooms, the icon sheets, the curtain) go to `docs/review/art-house/` with `index.md`.

## 7. Acceptance
- [ ] `house.json` complete for all 10 rooms with every canonical id; rect lint green; test green.
- [ ] Final art: porch, hall, parlour, kitchen + every slice prop (all states + outlines); greybox for the rest.
- [ ] 16 item icons, 34 activity/detour icons, the stage set, STYLE.md.
- [ ] Screenshots looked at and in `docs/review/art-house/`.
- [ ] Report `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-house.md`: files, any station moves (with the new x), requests.

---
## Standing rules for every Stage-1 task (from TECH §13 — binding)
- Repo: `/home/user/mischief` (paths in this brief are relative to it). Scratch: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/art-house/`.
  Report: `/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/reports/art-house.md` (the same text as your final answer).
- Create/modify **only** the paths you own (§2 above). Other agents are editing other paths right now. Need a change
  elsewhere? Write a precise request (file, change, reason) in your report. Never run git write commands.
- Code against the contracts in `docs/TECH.md`; when a module you depend on may not exist yet, use a **soft hook**
  (`ResourceLoader.exists` + `load`, `has_method`) and make tests `skip()` with a reason instead of failing.
- Run Godot **only** through `tools/scripts/test_game.sh art-house [-- filter]`, `tools/scripts/sandbox.sh art-house …` and
  `tools/scripts/shot.sh <res://scene.tscn> <out.png> [frames] art-house [-- user args]` (1200×540 = a 20:9 phone;
  `--shot-seq=/abs/dir --every=N --count=K` for frame sequences). Never run Godot on `game/` directly.
- Typed GDScript, tabs, `##` doc comments on public API; JSON per TECH §2; no placeholder TODOs where an
  implementation is asked for; 60 fps discipline (pools, no per-frame allocations in hot paths).
- New assets/scripts will get their `.import`/`.uid` sidecars from the orchestrator's import pass; don't hand-write
  them. Autoload registration and `project.godot` edits are the orchestrator's (request them).
- **Look at what you make** (Read the PNGs), judge it at phone scale, iterate. Put final review artefacts in
  `docs/review/art-house/` with an `index.md`.
- Final answer = concise report: what you built (files), exact public APIs other agents must use, verification
  (tests + artefact paths + what they show), deviations from the docs (with reasons), requests for other owners,
  known gaps.
