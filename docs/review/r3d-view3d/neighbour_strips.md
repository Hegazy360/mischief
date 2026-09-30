# Neighbour strips under C1 framing — numbers and the C1/C2 conflict (for the lead)

REDESIGN §3.1 asks that under C1 framing (Hush at the room centre) **at most 1.7 m** of each neighbouring room shows at
20:9 and **0.8 m** at 16:9, measured at the lane. C2 clamps the camera **0.3 m past the Night's outermost built walls**,
and the brief's own C2 test pins the Night-1 kitchen at **camera x 15.33 m** at 20:9. Measured by
`test_camera3d.gd::test_neighbour_strips_per_room` (base distance 7.5 m, visible lane width 8.96 m at 20:9 and 7.16 m at
16:9; house.json rooms; "left" / "right" = metres of the neighbour visible on each side):

| Night | aspect | room (width) | camera x | left strip | right strip | limit | what decides |
|---|---|---|---|---|---|---|---|
| N1 | 20:9 | porch (2.5 m) | 4.18 | 0.30 (the set edge) | **6.16** (hall) | 1.7 | C2 (Night edge) |
| N1 | 20:9 | hall (5.0 m) | 5.00 | **1.98** | **1.98** | 1.7 | the room is narrower than V − 2 × 1.7 = 5.56 m |
| N1 | 20:9 | parlour (6.5 m) | 11.24 | 0.74 | 1.71 | 1.7 | C1 + neighbour bias (at the limit) |
| N1 | 20:9 | kitchen (5.5 m) | 15.32 | **3.16** (parlour) | 0.30 (the set edge) | 1.7 | C2 (the brief's 15.33 test) |
| N1 | 16:9 | porch | 3.28 | 0.30 | **4.36** | 0.8 | C2 |
| N1 | 16:9 | hall | 5.00 | **1.08** | **1.08** | 0.8 | room narrower than V − 1.6 = 5.56 m |
| N1 | 16:9 | parlour | 10.78 | 0.30 | 0.36 | 0.8 | C1 |
| N1 | 16:9 | kitchen | 16.22 | **1.36** | 0.30 | 0.8 | C2 |
| P00 | 20:9 | hall (backstage, 5.0 m) | 6.68 | 0.30 | **3.66** | 1.7 | C2 |
| P00 | 20:9 | parlour | 11.24 | 0.74 | 1.71 | 1.7 | C1 + bias |
| P00 | 20:9 | kitchen | 15.32 | **3.16** | 0.30 | 1.7 | C2 |
| P00 | 16:9 | hall | 5.78 | 0.30 | **1.86** | 0.8 | C2 |
| P00 | 16:9 | parlour | 10.78 | 0.30 | 0.36 | 0.8 | C1 |
| P00 | 16:9 | kitchen | 16.22 | **1.36** | 0.30 | 0.8 | C2 |

## What is implemented
- C1 fits the room and, where the room leaves slack, **biases toward its centre so no strip exceeds the limit**
  (`neighbour_bias`, the limit interpolated between the two aspects by the visible width). Every interior room that is
  wide enough meets it (the parlour at 20:9 sits exactly at 1.71 m).
- C2 wins at the Night's ends: the outermost rooms frame against the set edge (0.3 m), so their inner neighbour shows
  more. The kitchen of N1/P00 — where most of the play happens — shows **3.16 m of the parlour at 20:9**.
- The neighbour is dimmed (0.78, +40 % desaturation; backstage 0.3) so the extra strip reads as "next door", not as a
  second playfield.

## The conflict, and options (lead's call)
1. **Rooms narrower than V − 2 × limit** (the 5 m hall: 5.56 m needed at 20:9) cannot meet 1.7 m at the base distance.
   Option: dolly in to D = 7.5 × (w + 2 × limit) / V (the hall: 7.03 m, a 1.07× zoom) while framed in such a room — it
   keeps the back wall ≤ 10 m (the 144 px hit rule holds) but changes the scale between rooms by 7 %.
2. **Night-edge rooms under C2** show a wide inner strip (kitchen: 3.16 m). Meeting 1.7 m there means framing 1.46 m
   past the set edge (the end flat and the dark beyond — the thing C2 exists to hide), or a 1.2× dolly-in for the
   kitchen (D 6.25 m: V 7.47 m, strips 1.67 / 0.30 m) which also enlarges the characters by 20 % in that room only.
3. Or restate §3.1 as "interior rooms"; the dimming does the rest. **Built as option 3** until the lead rules; either
   dolly option is a few lines in `CameraDirector3D._c1_target` + `_update_user_dist` (a per-room base distance).
