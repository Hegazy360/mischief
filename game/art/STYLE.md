# Mischief Next Door — Art Style Guide (binding)

This file is the **binding** art rulebook for every SVG in `game/art/` — house, props, icons, the stage
**and the characters** (`chars/**` follow it too). It ports the Booby rules (same owner) to this game's
landscape stage-farce look (GDD §9.1). Generators live outside the game: `tools/art/house/` (house, props,
icons, stage), `tools/art/hush/` (Figgis + the Stalls; the 2D Hush / Bellows rig art and `tools/art/bellows/` were
deleted with the 2D view in R3D — the 3D cast is built by `tools/art3d/**`); `_src/` folders under `game/art/` carry a
`.gdignore`. Regenerate the house with `python3 tools/art/house/build_all.py` and check with
`python3 tools/art/house/validate_svg.py && python3 tools/art/house/lint_rects.py`.

**One-line style:** a Saturday-morning cartoon on a stage set — chunky rounded shapes, thick navy ink,
flat saturated fills with ONE flat shade tone per shape, light from the top-left. A cosy pastel dollhouse
cut in half; every interactable pops; the characters pop hardest. Family friendly (PEGI 7): no injury,
no weapons, no gore; residue is ridiculous, never harmful.

---------------------------------------------------------------------------------------------------------
## 1. Canvas & file rules (Godot ThorVG importer)

* Root: `<svg xmlns="http://www.w3.org/2000/svg" width="W" height="H" viewBox="0 0 W H">` — integer
  width/height **equal to the pixel size at 1×**. Art is authored at display size (1× = world px at zoom
  1.0) and rasterised at 2× by HiResTex (1.5× on < 3 GB phones); rooms import at 1×.
* Allowed elements: `path rect circle ellipse line polyline polygon g` (a `g` may carry
  `transform="rotate(a cx cy)"`; icons may carry one `translate() scale()` fit), `linearGradient` /
  `radialGradient` / `stop` inside `<defs>`, and `fill-opacity`, `stroke-opacity`, `opacity`.
* **Not allowed:** `<text>` (letters are drawn as shapes — see the CONFISCATED stamp), filters / blur /
  drop shadows, masks, `clipPath`, `<image>`, `<use>`, `<pattern>`, `<style>`, `class=`, `style=`.
  Presentation **attributes** only.
* **Gradients** only for walls, sky, stage drapes and glows (`rooms/`, `stage/`, the cold-open set pieces
  `cold/*_bg|_fg.svg`). Never on characters, props, items, icons or cold-open state sprites.
* Transparent background except room backgrounds, stage flats and screen overlays.
* **3 px canvas margin**: nothing (ink or outline sprite) touches the outer 3 px of a sprite canvas.
* Compact: coordinates to 1 decimal, no editor metadata. Caps: props ≤ 48 KB, icons/items ≤ 16 KB,
  rooms ≤ 120 KB, stage ≤ 160 KB, cold-open set pieces (`cold/*_bg|_fg.svg`) ≤ 160 KB, cold-open state
  sprites ≤ 48 KB.
* **Letters are shapes.** Any word or numeral in the art (the title card, the CONFISCATED stamp, the house
  numbers, the sleeping Zs) is converted to path outlines from the project's OFL Lilita One
  (`game/ui/theme/fonts/LilitaOne-Regular.ttf`) by `tools/art/house/lettering.py` (fontTools) — never `<text>`.
* **≤ 10 colours per sprite** (ink and white included; all states of one prop share one palette so a
  state swap never changes a shared part's colour). The generator merges the closest colours if a
  drawing goes over — design within 10 so it never has to merge a base into its own shade.

## 2. Lines by layer (GDD §9.1)

| Layer | Silhouette | Detail | Ink |
|---|---|---|---|
| Characters (Hush, Bellows, Beryl, Delphine, Figgis) | **6 px** | 3.5 px | `#1B2340` |
| Interactable props (every hotspot sprite) | **5 px** | 3 px | `#1B2340` |
| Set dressing (non-interactive furniture in room backgrounds) | **4 px** | 2.5 px | `#3A3050` @ 80 % |
| Architecture (walls, cornice, skirting, slab, bands) | **3 px** | 2–2.5 px | `#3A3050` @ 80 % |
| Item icons (tray, pick strip, badges; 128 px canvas) | **6 px** | 3.5 px | `#1B2340` |
| Activity / detour icons (thought bubble; 88 px canvas) | **5 px** | 3 px | `#1B2340` |

* Always `stroke-linejoin="round"` and `stroke-linecap="round"`.
* Ink goes on top: fills → shade → highlight → details → silhouette stroke. Detail lines stop inside the
  silhouette. Only shade shapes, highlights, blush, contact shadows, glows and < 8 px particles go
  without ink.
* The value hierarchy is the point: characters (6 px, strongest saturation) > interactables (5 px, clean
  bright materials, pulsing outline) > set dressing (4 px soft ink, pastel) > architecture (3 px, 80 %).

## 3. Colour & shading

* **Light from the top-left.** One flat shade tone per shape on its lower/right side (~25–40 % of the
  shape) + optionally one white highlight capsule top-left at `fill-opacity` 0.55. Shade-first inset:
  fill the silhouette with the shade, draw the lit base shifted up-left inside it, then the ink.
* Shade = base × ~0.78–0.86 with a warm (red up, blue down) or cool shift. Materials are
  `(base, shade, light)` triples in `tools/art/house/pal.py` — reuse them, don't invent near-duplicates.
* Avoid `#000` and pure greys; use navy `#1B2340` and blue-greys.
* **Room palettes (GDD §9.1)** — rooms are 20–30 % desaturated pastels, set dressing is pulled toward the
  wall colour (`soft()` in `rooms_final.py`) so props and faces pop:
  hall sage `#A9B79A` · parlour dusty rose `#D9A7A0` · kitchen buttercream `#F2DFA6` · conservatory glass
  `#CDE7E1` · garden lawn `#8ACB6A`, hedge `#4E9A4A`, sky `#9FD6F0` · landing honey wood `#C9A27A` ·
  bathroom mint `#BFE3D5` · bedroom powder blue `#B8C7E6` · dressing room teal `#6FA3A8` · floors oak
  `#C98B55` / `#A96C3C`. Each room has ONE quiet wallpaper pattern (±10 % lightness): hall regency
  stripes, parlour damask trellis, kitchen gingham + splashback tiles, landing boards, bathroom tiles,
  bedroom dots, dressing stripes.
* **Reserved for characters** (props never use big areas of them): Bellows plum `#7B3F8C`, cravat gold
  `#E8B33A`, bouffant `#D9DCE6`; Hush cherry `#E23B4E`, navy `#2B3566`, face `#FFF6EA`; Beryl pink collar
  `#FF7FB0`; Delphine emerald `#1FA37A`.
* **Stage:** velvet `#B3122E` (shade `#8A0D24`, deep `#650A1B`), gold trim `#E8B33A` (`#C28E1E`,
  `#FFE08A`), backstage `#1F1A2E` / `#2A2340`.

## 4. Shapes & proportions

* Chunky and rounded: radius ≥ 4 px on anything ≥ 24 px; big furniture 6–12 px. Slight wobble is good.
* World scale: Bellows 380 px, Hush 340 px, a 1.7 m man ≈ 380 px → 1 m ≈ 220 px. Worktops 190–200 px,
  tables 170–180 px, doors 470 px, doorway openings 490 px, ceilings 640 px.
* Furniture stands against the back wall: its base sits on the back of the floor strip (y ≈ −18 … −24)
  with a soft contact shadow; characters walk on the front edge (y = 0) in front of it.
* Floor objects sit on their base (pivot at the floor contact) so the engine can squash them.

## 5. Eyes & faces (characters; and Hush peeking from hiding spots)

* Whites `#FFFFFF` with ink outline (3 px under 24 px), big navy pupils (≥ 40 % of the eye) with one
  white glint upper-left; brows 4–6 px strokes carry the emotion; mouths navy outline, `#E8506A` inside,
  tongue `#FF9AAE`; blush `#FF9FB0` at 0.7, no outline.
* Hush's warmth rule (GDD §9.2): round pupils ≥ 14 px, blush, smile by default — never a creepy clown.
  In hiding spots only her eyes (and the white glove fingertips) show in a dark gap `#241D33`.

## 6. Props: states, outline sprites, tells

* **Silhouette first.** Each prop must read as a black shape at phone scale (≈ 0.5× of world px on a
  20:9 phone). One idea per prop, ≤ 3 supporting details, minimum detail 6 px.
* **States** (all share the prop's canvas top-left `art_pos`; a state canvas may end at its own
  right/bottom extent — draw it with `centered = false` at `art_pos`):
  * `idle` — always;
  * `open` — containers while rummaged, doors/windows while used;
  * `rigged` — the armed tell, **visible without text**: the squeaker jammed in the kettle spout, the
    pepper pot tipped into the honey, the spanner on the over-tightened onion jar, the bulging fridge door
    with escaping sausages, the twisted spray head with drips, the gramophone lever in the red ×3 zone,
    the recliner spring bursting out, the magnifier tucked in the newspaper, flour in the bellows nozzle,
    the chandelier's open chain link and tilt, the brake wedge kicked out, salt heaped on the sugar, the
    feathers in the fan, the kipper on the phone hook, the key sticking out of the clock face, the mirror
    frame empty (glass leaning beside it), the stair rods on the floor. A small 4-point gold glint
    (`sparkle()`) sits on or next to the tell;
  * `rigged_<prank>` — when one rig point serves two pranks (the gramophone's "their song" record);
  * `spent` — only where the aftermath is a persistent visible gag (onion jar open, the cracked mirror,
    the spun clock, the chandelier gone, the broken recliner, the torn paper, the warped record, the
    flattened bellows, the bare fan ribs, the tipped cup, the kipper flopped by the phone). Otherwise the
    view greys the `idle` sprite;
  * `occupied` — hiding spots: a dark gap (`#241D33`, big enough for her eye pair at `eyes_scale`) with Hush's
    glove fingertips, **no baked eyes** (Stage 2): the view draws her animated eyes (`chars/hush/hidden_eyes_*`,
    tracking Bellows, blinking) centred on `eyes: [x, y]`, scaled by `eyes_scale` (default 1.0);
  * `front` — an overlay drawn **above** characters (the cheval mirror's empty frame for MIRROR, MIRROR).
* **Outline sprite** `<name>_ol.svg`: the idle silhouette grown 4 px, flat white (`#FFFFFF` only); its
  canvas is the prop canvas grown 4 px on every side, so it is drawn at `art_pos − (4, 4)`. The view draws
  it behind the prop, pulses alpha 0.6 ↔ 1.0 at 1.2 Hz and tints it (gold = usable). It may be rasterised
  at 1× (it's a soft flat glow).
* Interactables are furniture that is a *bit off* when rigged — comedy from contrast. Movable parts that
  animate (doors, lids, the vase, the hats, the pans, the portrait) are separate sprites (decor).

## 7. Rooms

* Canvas `width × 700` = interior 640 + slab 60; top-left at (room x0, floor line − 640).
* Anatomy (y relative to the floor line): ceiling −640, cornice to −616, wall, dado (hall −250, parlour
  −236, landing −250, dressing −240), skirting −52 … −28, floor strip −28 … 0 (in perspective), slab
  0 … +60 (boards, joists, ceiling plaster — or earth outdoors).
* Partition walls are **dollhouse bands**: 40 px, half drawn by each room, plaster cut face (brick on an
  outer face); doorways are gaps from −490 to the floor; the front and back doors are leaves in a gap
  from −474 that swing (edge-on when closed, face-on-ish when open). `<room>_fg.svg` holds only what
  must occlude characters: the lintel lip over each doorway gap (door-jamb side casings stay in the bg —
  a vertical fg strip would slice anyone standing near a doorway, e.g. Bellows at the tea counter).
* Final rooms carry set dressing: the slice (porch, hall, parlour, kitchen) and, since Stage 2, every room a
  slice shot also shows — the upper floor (landing, bathroom, bedroom, dressing room: their bottom ≈ 260 px sit
  in every ground-floor frame) and the conservatory (its first 600 px are in every kitchen frame), props
  included (`props_edge.py`). Only the garden is still greybox (flat pastel blocks with correct silhouettes).
  The view dims locked rooms blue-grey as the unlit set and ropes their doorways (`stage/velvet_rope.svg`);
  dimmed, they must still read as designed furniture.
* Walk band calm: nothing busy between y −380 and 0 behind where characters stand.

## 8. How the engine places house art (house.json — the view's contract)

* Rooms: `rooms[].art.{bg, fg}` at `art.pos = [x0, −640]` (y relative to the room's floor line;
  floors at y 0 and −700); `art.final` = drawn at final quality.
* Hotspots: `art_pos` (canvas top-left, y relative to the floor line), `art_size` (the idle canvas),
  `art.{idle, open, rigged, rigged_<prank>, spent, occupied, front, outline}` (outline at `art_pos − (4, 4)`),
  optional `eyes` + `eyes_scale` (the animated hidden eyes' centre and scale), `z`
  (1 = draw above other props, e.g. an open door leaf; characters are always above props except the
  `front` overlays).
* **`raster`** (hotspots and decor, optional; ∈ {1.0, 1.5, 2.0}, default 2.0): the atlas raster scale hint.
  The big hiding pieces, doors, the entry window and the tall furniture are 1.5 (never the punch-in subject
  above 1.4×), soft glows 1.0; outline `_ol` sprites are always 1× (no hint). `s2-view` builds each room atlas
  with `s2-rig`'s per-path scale from these hints; `build_all.py --report` prints the MPx per room at them.
* Decor (non-hotspot sprites the view animates): `decor[] = {id, room, pos, size, art{idle, …}, z, …}`:
  * **`z`**: −1 behind the props, 0/1 in front of the props (still behind the characters), **2 = over the
    characters** (like `art.front`: the `kitchen_sink_lip` he lands behind);
  * `hidden: true` + `show`: drawn only when something shows it — `"event"` = a clip `decor {id, visible}` event
    (the sink lip, the smashed vase), `"bow"` = while Take a Bow is available (the front-door glow);
  * **`frames: [paths]` + `fps`**: a looping flicker the view plays (the parlour fire 3 × 8 fps, the mantel
    candles 3 × 6 fps); `frames[0]` = `art.idle`, every frame on the same canvas;
  * `pivots: {name: [x, y]}` in canvas px: `kitchen_stool.seat` / `.foot`, `parlour_vase.base` / `.tip_l`,
    `parlour_picture_frame.hook` / `.hole`;
  * `slide` (the vase on the mantel): `{dir, step_px: [min, max], edge_x, floor_y, smashed}` — the view slides
    it `dir` by a step per warm-up note, tips it at `edge_x`, drops it to `floor_y` and swaps to the `smashed`
    decor;
  * extra states in `art` (`parlour_picture_frame.falling` for `cue: "laugh_picture"`, the portrait's
    `floured`); `station` (the decor belongs to that station: the stool under `st_tea`); `cue` (the director
    cue that stages it);
  * `blend: "add"`, `pulse_hz`, `link` — additive glows (`hall_front_door_glow` round the `front_door` link,
    pulsing at 1.5 Hz).
  Meltdown drops: `quake_props[room][] = {prop, x, decor}`.
* **The stool** (`kitchen_stool`, `res://art/house/props/kitchen_stool.svg`, 94 × 163): `pos` [2953, −156],
  seat pivot [47, 6] = world (3000, −150) under `st_tea.stand_x`, foot pivot [47, 156] on the floor. The
  Bellows stool prop rides the same file; never two stools on screen (the clip hides the decor).
* Stage: `stage.flies` (tile along x, bottom edge at the top of the upper floor, `fill_color` above),
  `stage.apron` (tile along x at y = +60), `stage.footlight_glow` (additive, every 256 px), `stage.pieces`
  (sky flats, roofs: absolute `world_pos`), `stage.proscenium_l/_r` (absolute `world_pos`), screen-space
  `curtain` (1920 × 1080, tile x), `curtain_valance`, `vignette_top`, `velvet_rope` (`anchor` = its
  bottom-centre at the doorway x on the floor line), **`bow_spot`** (screen space, additive, `anchor`
  bottom-centre on the apron, `alpha`: the curtain-call light pool) and **`title_card`**. `stage.bounds` = the
  world rectangle the camera may show.
* **`stage.title_card`** = `{art, bulbs: [a, b], size: [1500, 790], screen: true, pivot, hang, rest_center,
  chase_hz, drop_s, hold_s}`: the gilded marquee (MISCHIEF / NEXT DOOR, letters as Lilita One paths, Hush
  peeking over the top-right corner) on two fly ropes that start at the canvas top. It drops from above the
  frame to `rest_center` (screen px in the 2400 × 1080 frame; the rope tops then sit on the frame's top edge)
  in `drop_s`, squashes about `pivot` (the board's bottom centre) on landing and holds `hold_s`; the two
  `bulbs` overlays (same canvas: even / odd bulbs lit) alternate at `chase_hz` over the board, whose own bulbs
  are warm-unlit.
* **Cold-open sets** — `game/data/house/cold_sets.json` (`tools/art/house/cold.py`):
  `{"version": 1, "frame": [2400, 1080], "sets": {"<episode id>": {episode, time, size: [2400, 1080],
  safe: [240, 0, 1920, 1080], layers: [{id, art, pos, size, z, state?}], anchors: {name: [x, y]},
  actors: {rig: {facing, scale, pose, behind?}}, states: {layer: {state: path}}}}}`. Screen space: the set is
  composed on the logical 20:9 frame, the action inside `safe` (the central 1920 px) so 16:9 loses nothing.
  Layers with `z` ≤ 0 draw behind the actors, `z` ≥ 2 over them (`sill_no7`: his belly behind the sill);
  a layer with `states` shows `states[layer][state]` (start = the layer's `state`; an empty path hides it);
  `anchors.bellows` = the rig's root (feet) position, `bellows_face` the camera focus, the rest are
  targets/focus points (`window_no9`, `crack`, `birds`, `balloon`, `string_in`, `box`, `door`, `sign`, …).
  Files `game/art/house/cold/<set>_bg.svg` (full frame, gradients allowed), `<set>_<piece>_fg.svg` (set pieces
  over the actors: `n01_sill_fg.svg`), state sprites (prop rules: ≤ 10 colours, 5 px ink, 3 px margin).

## 9. Icons

* Items: 128 px canvas, 6 px ink, a bold single object, readable at 64 px (tray 128, pick strip 144,
  badge 56). Activities/detours: 88 px canvas, 5 px ink, one object that says "what he'll do next"
  (a teacup, a gramophone, a bath), readable at 44 px, drawn to sit inside a white thought bubble.
  `exit` (the walk-out: a flight of stairs and his huff) is the bubble for `bubble.next == "exit"`.

## 10. Readable at phone scale — the checks (do them, look at the PNGs)

1. `python3 tools/art/house/validate_svg.py` and `lint_rects.py` are green.
2. Screenshot at 1200 × 540 (20:9 phone): `tools/scripts/shot.sh res://scenes/dev/house_preview/
   HousePreview.tscn out.png 30 <sandbox> -- --room=<id> [--state=rigged] [--rects --badges] [--chars]`
   (`--chars` = the real Hush and Bellows rigs at their stations; `--slice=n01` dims the locked rooms;
   `--cold=<set> [--cold_state=layer:state,…] [--chars]` a cold-open set; `--title` the title card).
3. At that size every interactable is identifiable in one glance, every rigged tell differs from idle
   without reading text, and nothing in the walk band competes with the characters (use `--chars`: the
   plum barrel and the striped mime must be the strongest shapes on screen).
4. Squint (or blur 4 px): the room reads as ONE calm pastel field; the props read as distinct shapes.
5. Overview (`--zoom=0.5`): rooms identifiable by colour alone; poses read, faces needn't.

## 11. Do / Don't

**Do** use the exact palette hexes, the layer line weights, round joins/caps; keep silhouettes bold;
give every rigged state a visible physical tell; keep states on one palette; draw letters as shapes.
**Don't** use banana peels, marbles, mousetraps, drawing pins, fart cushions or any NfH gag prop
(GDD §5.9); no TV/camera/ratings imagery; no real brands or faces; no `<text>`; no filters; no pure black.
