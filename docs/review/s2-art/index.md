# s2-art review artefacts (Stage 2: slice rooms at final polish, Gate-0 kitchen, cold opens, title card)

Every Godot shot is 1200 × 540 (a 20:9 phone held sideways) of `res://scenes/dev/house_preview/HousePreview.tscn`,
built straight from `game/data/house/house.json` / `cold_sets.json`, camera framed like the game (zoom 1.0 = one
floor fills the height; 0.5 = Overview), with the **real Hush and Bellows rigs** (RigPlayer static poses) at their
usual stations. Regenerate all of it with `tools/art/house/review_s2.sh` (build + validate + lint + shots + crops +
sheets); the Stage-1 set in `docs/review/art-house/` is refreshed by `tools/art/house/review_shots.sh`.

Half-second test for each: would the owner see "final art" or "placeholder"? All of these read as final.

## P0 contracts (other tasks build on these)

### `st_tea` (house.json `stations`)
`{"id": "st_tea", "room": "kitchen", "x": 2940, "stand_x": 3000, "facing": -1, "kinds": ["HONEY"]}` — he sits on
the stool at the right end of the tea counter (counter x 2848–3044, kettle 2940, honey jar 2928 on the shelf), facing
the counter, his back to the pantry (3620) and the sink (3788), so ACHOO-RIA! / HOT & COLD rocket him backwards into
the sink landing at **3760** (`landings.kitchen.sink`, unchanged). Hotspots `kitchen_kettle` / `kitchen_honey` are
unchanged (Hush's use_x 2940). Solver baseline after the move: 14/14 routes OK, 0 new failures.

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
Seat in the basin: world (3788, −226) — his backside sits behind the lip, his legs stick up over it (`g0_sink.png`).

### `kitchen_window` `open` · `kitchen_honey` `rigged`
`res://art/house/props/kitchen_window_open.svg`: the lower sash shoved up behind the upper one, a clean hole below
(the view shows it during Hush's climb-in). The honey tell (ACHOO-RIA!): cloth cap flung off, the pepper pot upside
down in the jar mouth, a black pepper volcano out of the honey with specks down the glass, a pepper-dust puff.

## The slice with the real characters (zoom 1.0)
| File | Shows | Judge |
|---|---|---|
| `porch_chars.png`, `porch_chars_rigged.png` | Bellows at the front door lecturing, Hush on the doorstep; No. 9 beyond | both characters the strongest shapes |
| `hall_chars.png`, `hall_chars_rigged.png` | Bellows preening at the cheval mirror, Hush frozen by the clock; tells: kipper on the phone, empty mirror frame + glass, clock key, rods on the floor | Hush's navy stripes read on sage (white gloves + face + outline) |
| `hall_open.png`, `hall_occupied.png`, `hall_glow.png` | box flaps / piggy / front door open; the coat cupboard and clock case as dark gaps with her animated eyes; the **front-door bow glow** (`hall_front_door_glow`, additive) | the glow says "exit here, take a bow" |
| `parlour_chars.png`, `parlour_chars_rigged.png` | Bellows singing at the gramophone, Hush tinkering at the piano; every rigged tell | plum on rose / black piano keeps its silver bouffant + cream belly contrast |
| `parlour_occupied.png`, `parlour_spent.png` | eyes behind the piano shawl / the chaise; aftermaths | — |
| `parlour_gags.png` | the Prologue gag props: vase on the mantel (slides along it), the smashed vase on the floor, the picture's `falling` sprite | — |
| `kitchen_chars.png`, `kitchen_chars_rigged.png` | Bellows at `st_tea` (3000, facing the counter), Hush by the pantry; honey tell, squeaker in the kettle, spanner, bulging fridge, twisted tap | — |
| `kitchen_open.png`, `kitchen_occupied.png`, `kitchen_spent.png` | fridge / pantry / window open; eyes under the table cloth and in the pantry curtain (and every visible hiding spot above and in the conservatory) | eyes sit inside every dark gap |
| `g0_stool.png` | **Gate-0**: Bellows on the stool (`b_stool_sit`) at the counter, back to the sink, everything rigged | he sits ON the stool, feet dangling |
| `g0_sink.png` | **Gate-0**: Bellows in the sink (`b_sink_sit`) behind `kitchen_sink_lip`; window open | his backside disappears behind the basin front |

## What every ground-floor shot also shows (now final)
| File | Shows |
|---|---|
| `kitchen_band_2x.png` | the bottom ≈ 100 screen px of the upper floor from the kitchen shot, 2×: bath feet, laundry basket, wardrobe, the bed's frilled valance, bedside, costume trunk and rail |
| `kitchen_conservatory_2x.png` | the conservatory edge from the kitchen shot, 2×: glass wall, hanging basket, feed bin (goat pictogram), wicker hamper, sun lounger |
| `kitchen_n01_locked.png`, `overview_n01.png`, `prologue_locked.png` | the same rooms dimmed as the unlit set behind velvet ropes (N1 set; Prologue set) — still designed furniture, not blocks |
| `overview_chars.png` | Overview (zoom 0.5) with both characters: every room identifiable by colour, the upper floor + conservatory final |
| `props_landing_states.png`, `props_bathroom_states.png`, `props_bedroom_states.png`, `props_dressing_states.png`, `props_conservatory_states.png` | every new final prop in every state + outline (0.75×): occupied = dark gap + glove tips, no baked eyes; rigged tells (balloon on the throat spray, croc behind the duck, bubble bath in the taps, cranked valve + steam, squeaker in the pillow, buttered specs, goat under the duvet, tutu on the dummy, loosened trophy shelf, treacle over the feed bin) |

## Cold opens (screen space 2400 × 1080; `cold_sets.json`)
| File | Shows | Judge |
|---|---|---|
| `cold_n01.png` | N1 "Throat Tea", dawn: the sun rising between the roofs, No. 7's pompous stucco window with Bellows singing out of it (the sill fg over his belly), No. 9's lilac house asleep (striped curtains drawn, Zzz), sparrows on her gutter | reads "6 a.m., he's singing at the neighbour" with the sound off |
| `cold_n01_cracked.png` | `window_no9: cracked` (star crack, a shard knocked out, shards falling, Zzz gone) + `birds: flown` | the crack reads at phone size |
| `cold_n01_rects.png` | the anchors (red) and the 16:9 safe 1920 px (white frame) | action inside the safe zone |
| `cold_n02.png` | N2 "Something Fishy", day: No. 7's front door, steps, the CONFISCATED box, railings with a "no balloons" pictogram, the child's pink balloon on a string from off-frame right | the sign telegraphs the gag |
| `cold_n02_popped.png`, `cold_n02_confiscated.png` | `balloon: popped` (rubber scraps, slack string); `balloon: none` + `box: string` (the string and shred flopped over the box rim) | the three beats read without sound |

## Title card and icons
| File | Shows |
|---|---|
| `title.png`, `title_phone.png` | the gilded marquee on the curtain at its rest place (rope tops on the frame's top edge), at full and half size: MISCHIEF / NEXT DOOR in cream-to-gold Lilita One letter paths, bulbs, crest, Hush peeking over the corner; the `bow_spot` light pool on the apron |
| `activities_sheet.png` | the 35 activity icons at 88 / 44 px in a mock bubble, incl. the new `exit` (stairs + huff) |

## Budgets (props at the `raster` hints + outlines at 1×; one 2048² page = 4.19 MPx)
hall 3.54 MPx (84 %) · parlour 3.59 (86 %) · kitchen 3.43 (82 %) · landing 0.92 · bathroom 1.88 · bedroom 2.66 ·
dressing 1.73 · conservatory 0.98 · garden 2.04 — every room fits one page (`build_all.py --report`).
