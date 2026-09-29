# s2-art review artefacts (Stage 2: slice rooms at final polish)

Status: **P0 landed** (st_tea, stool contract, sink lip, window `open`, honey tell). P1 in progress — this file is
refreshed as each artefact lands.

## P0 contracts (other tasks build on these now)

### `st_tea` (house.json `stations`)
`{"id": "st_tea", "room": "kitchen", "x": 2940, "stand_x": 3000, "facing": -1, "kinds": ["HONEY"]}` — he sits on
the stool at the right end of the tea counter (counter x 2848–3044, kettle 2940, honey jar 2928 on the shelf), facing
the counter, his back to the pantry (3620) and the sink (3788), so ACHOO-RIA! / HOT & COLD rocket him backwards into
the sink landing at **3760** (`landings.kitchen.sink`, unchanged). Hotspots `kitchen_kettle` / `kitchen_honey` are
unchanged (Hush's use_x 2940).

### The stool (for `s2-anim-bellows`' stool prop)
| | |
|---|---|
| File | `res://art/house/props/kitchen_stool.svg` (one SVG; the Bellows prop must use this same file) |
| Canvas | **94 × 163** px at 1× (world px) |
| House placement | decor `kitchen_stool`, `pos` [2953, −156] (canvas top-left, y relative to the ground floor line), `z` 0, `station` `st_tea` |
| Seat pivot | **[47, 6]** in canvas px = world (3000, −150): top-centre of the cushion, where his backside sits |
| Foot pivot | **[47, 156]** in canvas px = world (3000, 0): floor contact centre (squash, hop-back, landing) |
| Seat height | 150 px above the floor (his feet dangle — the joke) |
| In house.json | `decor[kitchen_stool].pivots = {"seat": [47, 6], "foot": [47, 156]}` |

Rule (s2-view / s2-anim-bellows): never two stools on screen — while his stool prop is out, the clip's `decor`
event `{"id": "kitchen_stool", "visible": false}` hides the house decor; it reappears off-camera.

### `kitchen_sink_lip` (decor, drawn OVER the characters)
`{"id": "kitchen_sink_lip", "room": "kitchen", "pos": [3712, −256], "size": [152, 62], "art": {"idle":
"res://art/house/props/kitchen_sink_lip.svg"}, "z": 2, "hidden": true, "show": "event"}` — the Belfast basin's front,
pixel-identical to the basin in `kitchen_sink_tap` (idle and rigged). Hidden by default (Hush and Bellows walk *in
front of* the sink cabinet, so an always-on lip would cut their bodies); shown by a clip `decor` event
`{"id": "kitchen_sink_lip", "visible": true}` on the frame he lands in the basin, hidden again when he climbs out.
Seat in the basin: world (3788, −226) — his backside sits behind the lip, his legs stick up over it.

### `kitchen_window` `open`
`res://art/house/props/kitchen_window_open.svg` — the lower sash shoved up behind the upper one: a double frame in the
top quarter, a clean hole (no glass, no glints, a breeze) below. The view shows it during Hush's climb-in.

### `kitchen_honey` `rigged` (the ACHOO-RIA! tell)
The cloth cap flung off beside the jar, the pepper pot upside down in the jar mouth, a black pepper volcano out of the
honey with specks running down the glass, a pepper-dust puff above. Reads at 1200 × 540 (see the kitchen shots).
