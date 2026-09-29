# art-house review artefacts

All Godot shots are 1200 × 540 (a 20:9 phone held sideways) of
`res://scenes/dev/house_preview/HousePreview.tscn`, which builds the house straight from
`game/data/house/house.json` with plain Sprite2D nodes, camera framed like the game (zoom 1.0: one floor =
640 interior + 60 slab fills the height, 190 px of the floors above/below show). Regenerate everything with
`tools/art/house/review_shots.sh` (build + validate + lint + shots + sheets).

## Final rooms (porch, hall, parlour, kitchen)

| File | Shows | Judge |
|---|---|---|
| `porch_idle.png` | the porch: sky, No. 9's facade with Hush's striped-curtain window and "9", the hedge, No. 7's doorstep, canopy "7", lantern, the front door edge + knocker; hall to the right | reads as outside; the doorstep is clear for the Lecture landing |
| `porch_rigged.png`, `porch_rects.png` | same with rigged props / hit boxes (the front door box straddles the wall) | — |
| `hall_idle.png` | sage stripes + wainscot, the staircase band (runner, banister, stairwell to the landing), coat cupboard, CONFISCATED box (croc peeking, balloon), hallstand + hats, candlestick phone on its table, piggy bank, cheval mirror, grandfather clock, newel post, stair rods | every prop identifiable at a glance; walk band calm |
| `hall_rigged.png` | tells: kipper on the phone hook, empty mirror frame (glass leaning), key + spring in the clock, stair rods on the floor | each tell differs from idle without text |
| `hall_open.png`, `hall_occupied.png` | box flaps open (toys), piggy spilling coins, front door swung in; Hush's eyes/gloves in the coat cupboard and the clock case | hiding reads as "she's in there" |
| `hall_rects.png` | hit boxes (blue hiding, gold container, red rig point, grey exits) + id labels + use points + mock 56 px badges | ≥ 144 px, 24 px dead space, stacks (clock face/case, rods/foot, phone/piggy) |
| `parlour_idle.png` | dusty-rose damask, bay window with drapes, gramophone, baby grand under a fringed shawl, wingback recliner + newspaper, fireplace (fire, mantel, vase, candlesticks) with Bellows' portrait, chandelier, bellows over the log basket, chaise, tea table + tray, Delphine's wall fan, the falling picture by the doorway | — |
| `parlour_rigged.png` | tells: gramophone lever in the red zone, recliner spring, magnifier in the paper, flour in the bellows, chandelier's open link + tilt, wedge kicked out, salt on the sugar, feathers in the fan | — |
| `parlour_occupied.png`, `parlour_spent.png`, `parlour_rects.png` | eyes under the piano shawl / over the chaise; aftermaths (bare chain, torn paper, flat bellows, bare fan, tipped cup); hit boxes | — |
| `kitchen_idle.png` | buttercream gingham + tiles, checker lino, tea counter (kettle, honey jar + pepper pot on the shelf), stool, pickle shelf (onion jar), pan rail, retro fridge, table with the long gingham cloth, pantry cupboard + curtain, Belfast sink + spray tap, the entry window, back door | — |
| `kitchen_rigged.png` | tells: squeaker in the kettle spout, pepper pot tipped into the honey, spanner on the onion jar lid, bulging fridge door with sausages + jelly, twisted spray head with drips | — |
| `kitchen_open.png`, `kitchen_occupied.png`, `kitchen_spent.png`, `kitchen_rects.png` | fridge open (kipper, butter), pantry open (flour, sherbet, treacle, salt), window open; eyes under the table cloth and behind the curtain; the empty onion jar; hit boxes | — |
| `kitchen_chars_outline.png`, `parlour_chars.png` | mock Bellows (plum barrel, 380 px) and Hush (stripes, 340 px) silhouettes + pulsing outline sprites | the characters are the strongest shapes on screen |
| `prologue_locked.png` | Prologue set: parlour + kitchen lit, every other room drawn as the unlit set (blue-grey) with velvet ropes across the doorways | "backstage" reads, the slice pops |

## The whole set and the greybox rooms

| File | Shows |
|---|---|
| `overview.png`, `overview_east.png` | zoom 0.5: flies (ropes, lamps), roof with chimneys, sky flats (No. 9's attic window, the hall's lean-to roof), both floors, apron + footlight cups, gilded proscenium at both ends; east: conservatory glass lean-to and the garden |
| `grey_upper_west.png`, `grey_upper_east.png` | greybox landing (stairwell + balustrade, airing cupboard + boiler valve, radiator), bathroom (basin + mirror cabinet, cabinet, clawfoot bath, taps, duck, laundry basket), bedroom (wardrobe, bed + pillow, bedside with specs), dressing room (bulb mirror, trunk, rail, trophies, dummy) |
| `grey_conservatory_garden.png` | greybox conservatory (glass wall, feed bin, hamper, sunbeam, lounger, potting bench) and garden (hose, roses, marrow, coin path, shed, compost, spotlight, pond, fence + gate) |
| `grey_upper_rects.png`, `grey_garden_rects.png` | hit boxes upstairs (bed/under-bed/pillow stack, bath/taps/duck) and in the garden (the three coin boxes, spotlight over the compost) |

## Sheets

| File | Shows |
|---|---|
| `props_hall_states.png`, `props_parlour_states.png`, `props_kitchen_states.png` | every slice prop in every state + its outline sprite (tinted gold under the idle art), at 0.75× |
| `items_sheet.png` | the 16 item icons at 128 px and 64 px |
| `activities_sheet.png` | the 34 activity/detour icons at 88 px and 44 px inside a mock thought bubble |
| `stage_sheet.png` | curtain, valance, apron, flies, footlight glow, velvet rope, vignette, sky flats, roofs, proscenium l/r |
| `curtain.png` | the 1920 × 1080 curtain at 0.5 (tileable along x) |
