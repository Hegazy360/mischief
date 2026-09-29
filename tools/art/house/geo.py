"""geo - THE house layout (GDD §7.1, TECH §4.1/§14). Single source of truth for house.json,
the room art, the prop placement and the lints.

World coords: px, x right, y down, y relative to the floor line of the thing's floor
(ground line y = 0, upper line y = -700). A floor = 640 px interior above its line + a 60 px slab
below it. Room art canvases cover [x0, x1] x [-640, +60] relative to the room's floor line.

Station x values follow GDD §7.1 and may shift <= 80 px (lint_rects.py checks it). Moves made
to satisfy the hotspot rules (>= 144 px boxes, >= 24 px gaps, no overlaps) are listed in
MOVES and in the task report.
"""

FLOOR_PITCH = 700
INTERIOR_H = 640
SLAB_H = 60
FLOORS = {0: 0, 1: -700}

# Interior vertical anatomy (y relative to the floor line)
CEIL = -640          # ceiling line (canvas top)
CORNICE = -616       # bottom of the cornice moulding
SKIRT_TOP = -52      # top of the skirting board
BACK = -28           # where the back wall meets the floor (floor strip = BACK..0)
DOOR_TOP = -490      # top of doorway openings
BAND = 40            # partition wall band width (half drawn by each room)

# id, floor, x0, x1, outdoor, wallpaper (GDD §9.1)
ROOMS = [
    ("porch", 0, 0, 500, True, "#9FD6F0"),
    ("hall", 0, 500, 1500, False, "#A9B79A"),
    ("parlour", 0, 1500, 2800, False, "#D9A7A0"),
    ("kitchen", 0, 2800, 3900, False, "#F2DFA6"),
    ("conservatory", 0, 3900, 4700, False, "#CDE7E1"),
    ("garden", 0, 4700, 6200, True, "#8ACB6A"),
    ("landing", 1, 1000, 1800, False, "#C9A27A"),
    ("bathroom", 1, 1800, 2800, False, "#BFE3D5"),
    ("bedroom", 1, 2800, 3700, False, "#B8C7E6"),
    ("dressing", 1, 3700, 4500, False, "#6FA3A8"),
]
ROOM = {r[0]: {"id": r[0], "floor": r[1], "x0": r[2], "x1": r[3], "outdoor": r[4], "wallpaper": r[5]} for r in ROOMS}
FINAL_ROOMS = ("porch", "hall", "parlour", "kitchen", "landing", "bathroom", "bedroom", "dressing", "conservatory")

LINKS = [
    {"id": "front_door", "kind": "door", "a": "porch", "b": "hall", "x": 500},
    {"id": "hall_parlour", "kind": "doorway", "a": "hall", "b": "parlour", "x": 1500},
    {"id": "parlour_kitchen", "kind": "doorway", "a": "parlour", "b": "kitchen", "x": 2800},
    {"id": "back_door", "kind": "door", "a": "kitchen", "b": "conservatory", "x": 3900},
    {"id": "conservatory_garden", "kind": "doorway", "a": "conservatory", "b": "garden", "x": 4700},
    {"id": "landing_bathroom", "kind": "doorway", "a": "landing", "b": "bathroom", "x": 1800},
    {"id": "bathroom_bedroom", "kind": "doorway", "a": "bathroom", "b": "bedroom", "x": 2800},
    {"id": "bedroom_dressing", "kind": "doorway", "a": "bedroom", "b": "dressing", "x": 3700},
    {"id": "stairs", "kind": "stairs", "a": "hall", "ax": 1450, "b": "landing", "bx": 1050,
     "hush_s": 1.0, "bellows_s": 1.8},
]

# Stations: id, room, x, stand_x, facing, kinds, extra
STATIONS = [
    # parlour
    ("st_gramophone", "parlour", 1640, 1730, -1, [], {}),
    ("st_piano", "parlour", 1840, 1990, -1, [], {}),
    ("st_recliner", "parlour", 2080, 2080, 1, [], {}),
    ("st_fireplace", "parlour", 2330, 2440, -1, ["DRY"], {}),
    ("st_chaise", "parlour", 2560, 2560, -1, [], {}),
    ("st_parlour_centre", "parlour", 2150, 2150, 1, [], {}),
    # kitchen
    ("st_tea", "kitchen", 2940, 3000, -1, ["HONEY"], {}),
    ("st_pickles", "kitchen", 3110, 3050, 1, [], {}),
    ("st_fridge", "kitchen", 3280, 3190, 1, [], {}),
    ("st_sink", "kitchen", 3788, 3728, 1, ["SINK"], {}),
    # hall
    ("st_hall_mirror", "hall", 1112, 952, 1, ["MIRROR"], {"frame_x": 1112}),
    ("st_phone", "hall", 944, 866, 1, [], {}),
    ("st_clock", "hall", 1280, 1200, 1, [], {}),
    ("st_front_door", "hall", 520, 610, -1, [], {}),
    # conservatory
    ("st_feed_bin", "conservatory", 4020, 4090, -1, [], {}),
    ("st_sun_lounger", "conservatory", 4480, 4480, 1, ["DRY"], {}),
    # garden
    ("st_hose", "garden", 4820, 4880, 1, [], {}),
    ("st_marrow", "garden", 5140, 5200, -1, [], {}),
    ("st_path", "garden", 5260, 5260, 1, [], {"path_x1": 5560}),
    ("st_stage", "garden", 5400, 5400, 1, [], {}),
    # landing
    ("st_radiator", "landing", 1450, 1380, 1, ["DRY"], {}),
    # bathroom
    ("st_basin", "bathroom", 1930, 1870, 1, ["SINK", "MIRROR"], {}),
    ("st_bath", "bathroom", 2470, 2470, 1, [], {}),
    # bedroom
    ("st_wardrobe", "bedroom", 2910, 2990, -1, [], {}),
    ("st_bed", "bedroom", 3168, 3168, 1, [], {}),
    # dressing
    ("st_dressing_mirror", "dressing", 4160, 4090, 1, ["MIRROR"], {}),
    ("st_trophy", "dressing", 4300, 4240, 1, [], {}),
    ("st_dummy", "dressing", 4420, 4360, 1, [], {}),
]

# GDD §7.1 station guide x (for the <= 80 px rule). st_parlour_centre / st_stage have no GDD x
# (st_stage: centre of the Gala stage 5000-5800).
GDD_X = {
    "st_gramophone": 1640, "st_piano": 1840, "st_recliner": 2080, "st_fireplace": 2330, "st_chaise": 2560,
    "st_tea": 2960, "st_pickles": 3130, "st_fridge": 3300, "st_sink": 3800,
    "st_hall_mirror": 1160, "st_phone": 980, "st_clock": 1340, "st_front_door": 520,
    "st_feed_bin": 4020, "st_sun_lounger": 4480,
    "st_hose": 4820, "st_marrow": 5180, "st_path": 5260, "st_stage": 5400,
    "st_radiator": 1450, "st_basin": 1930, "st_bath": 2520,
    "st_wardrobe": 2920, "st_bed": 3200,
    "st_dressing_mirror": 4160, "st_trophy": 4300, "st_dummy": 4420,
}

# Hotspots: id -> dict(kind, room, use_x, facing, rect [x, y, w, h], station, in_use_by, link, extra)
def _h(kind, room, use_x, facing, rect, station=None, in_use_by=None, link=None, **extra):
    d = {"kind": kind, "room": room, "use_x": use_x, "facing": facing, "rect": rect, "in_use_by": in_use_by}
    if station:
        d["station"] = station
    if link:
        d["link"] = link
    d.update(extra)
    return d


HOTSPOTS = {
    # ---------------------------------------------------------------- hall
    "hall_front_door": _h("exit", "hall", 560, -1, [368, -474, 144, 454], link="front_door", z=1),
    "hall_coat_cupboard": _h("hiding", "hall", 608, -1, [536, -450, 144, 470]),
    "hall_confiscated_box": _h("container", "hall", 776, 1, [704, -236, 144, 256]),
    "hall_phone": _h("rig_point", "hall", 944, 1, [872, -360, 144, 170], station="st_phone"),
    "hall_piggy_bank": _h("container", "hall", 944, 1, [872, -166, 144, 186]),
    "hall_mirror": _h("rig_point", "hall", 1112, -1, [1040, -480, 144, 500], station="st_hall_mirror", z=1),
    "hall_clock": _h("rig_point", "hall", 1280, 1, [1208, -552, 144, 180], station="st_clock"),
    "hall_clock_case": _h("hiding", "hall", 1280, 1, [1208, -348, 144, 368], in_use_by="clock"),
    "stairs_rods": _h("rig_point", "hall", 1430, -1, [1376, -178, 144, 198]),
    "stairs_foot": _h("stairs", "hall", 1450, -1, [1376, -372, 144, 170], link="stairs"),
    # ---------------------------------------------------------------- parlour
    "parlour_gramophone": _h("rig_point", "parlour", 1640, -1, [1566, -448, 148, 468], station="st_gramophone"),
    "parlour_piano_back": _h("hiding", "parlour", 1830, -1, [1740, -404, 196, 230]),
    "parlour_piano_wedge": _h("rig_point", "parlour", 1880, -1, [1790, -150, 150, 170], station="st_piano"),
    "parlour_recliner": _h("rig_point", "parlour", 2040, 1, [2004, -228, 152, 248], station="st_recliner"),
    "parlour_newspaper": _h("rig_point", "parlour", 2080, 1, [2004, -416, 152, 164], station="st_recliner"),
    "parlour_chandelier": _h("rig_point", "parlour", 2330, 1, [2250, -632, 160, 196]),
    "parlour_bellows": _h("rig_point", "parlour", 2250, -1, [2180, -350, 144, 184], station="st_fireplace"),
    "parlour_chaise_back": _h("hiding", "parlour", 2554, -1, [2476, -238, 156, 258]),
    "parlour_tea_tray": _h("rig_point", "parlour", 2728, 1, [2656, -308, 144, 188], station="st_chaise"),
    "parlour_fan": _h("rig_point", "parlour", 2728, 1, [2656, -508, 144, 176], station="st_chaise"),
    # ---------------------------------------------------------------- kitchen
    "kitchen_kettle": _h("rig_point", "kitchen", 2940, 1, [2868, -334, 144, 164], station="st_tea"),
    "kitchen_honey": _h("rig_point", "kitchen", 2940, 1, [2868, -530, 144, 172], station="st_tea"),
    "kitchen_pickle_jar": _h("rig_point", "kitchen", 3110, 1, [3038, -520, 144, 180], station="st_pickles"),
    "kitchen_fridge_shelf": _h("rig_point", "kitchen", 3280, 1, [3208, -474, 144, 180], station="st_fridge"),
    "kitchen_fridge": _h("container", "kitchen", 3280, 1, [3208, -270, 144, 290]),
    "kitchen_table": _h("hiding", "kitchen", 3450, 1, [3378, -226, 144, 246]),
    "kitchen_pantry_shelf": _h("container", "kitchen", 3620, 1, [3548, -560, 144, 204]),
    "kitchen_pantry_curtain": _h("hiding", "kitchen", 3620, 1, [3548, -332, 144, 352]),
    "kitchen_sink_tap": _h("rig_point", "kitchen", 3788, 1, [3716, -336, 144, 170], station="st_sink"),
    "kitchen_window": _h("door", "kitchen", 3800, -1, [3716, -604, 144, 244], tappable=False, entry="window"),
    "kitchen_back_door": _h("door", "kitchen", 3862, 1, [3884, -484, 144, 190], link="back_door", z=1),
    # ---------------------------------------------------------------- conservatory
    "conservatory_feed_bin": _h("rig_point", "conservatory", 4020, -1, [3950, -250, 144, 270], station="st_feed_bin"),
    "conservatory_hamper": _h("hiding", "conservatory", 4190, -1, [4118, -236, 150, 256]),
    "conservatory_potting_bench": _h("container", "conservatory", 4620, 1, [4548, -300, 144, 320]),
    # ---------------------------------------------------------------- garden
    "garden_hose": _h("rig_point", "garden", 4820, 1, [4748, -268, 144, 288], station="st_hose"),
    "garden_marrow": _h("rig_point", "garden", 5140, -1, [5068, -170, 144, 190], station="st_marrow"),
    "garden_coin_1": _h("rig_point", "garden", 5308, 1, [5236, -150, 144, 170], station="st_path"),
    "garden_coin_2": _h("rig_point", "garden", 5392, 1, [5320, -344, 144, 170], station="st_path"),
    "garden_coin_3": _h("rig_point", "garden", 5476, 1, [5404, -150, 144, 170], station="st_path"),
    "garden_shed": _h("hiding", "garden", 5700, -1, [5626, -430, 150, 450]),
    "garden_spotlight": _h("rig_point", "garden", 5875, -1, [5800, -630, 150, 176], station="st_stage"),
    "garden_compost": _h("hiding", "garden", 5875, -1, [5800, -262, 150, 282]),
    # ---------------------------------------------------------------- landing
    "stairs_head": _h("stairs", "landing", 1050, 1, [1000, -178, 144, 198], link="stairs"),
    "landing_boiler_valve": _h("rig_point", "landing", 1250, 1, [1176, -520, 150, 180], station="st_radiator"),
    "landing_airing_cupboard": _h("hiding", "landing", 1250, 1, [1176, -316, 150, 336]),
    # ---------------------------------------------------------------- bathroom
    "bathroom_basin_spray": _h("rig_point", "bathroom", 1930, 1, [1858, -348, 144, 166], station="st_basin"),
    "bathroom_cabinet": _h("container", "bathroom", 2110, 1, [2038, -540, 144, 180]),
    "bathroom_bath_taps": _h("rig_point", "bathroom", 2368, 1, [2296, -394, 144, 164], station="st_bath"),
    "bathroom_duck": _h("rig_point", "bathroom", 2536, 1, [2464, -394, 144, 164], station="st_bath"),
    "bathroom_bath": _h("hiding", "bathroom", 2458, 1, [2300, -206, 306, 226], in_use_by="bath"),
    "bathroom_laundry_basket": _h("hiding", "bathroom", 2704, -1, [2632, -236, 144, 256]),
    # ---------------------------------------------------------------- bedroom
    "bedroom_wardrobe": _h("hiding", "bedroom", 2910, 1, [2838, -490, 144, 510], in_use_by="dress"),
    "bedroom_pillow": _h("rig_point", "bedroom", 3084, 1, [3012, -338, 144, 170], station="st_bed"),
    "bedroom_bed": _h("rig_point", "bedroom", 3252, 1, [3180, -338, 144, 170], station="st_bed"),
    "bedroom_under_bed": _h("hiding", "bedroom", 3168, 1, [3012, -144, 312, 164]),
    "bedroom_bedside": _h("rig_point", "bedroom", 3420, 1, [3348, -300, 144, 190], station="st_bed"),
    # ---------------------------------------------------------------- dressing room
    "dressing_costume_trunk": _h("container", "dressing", 3800, 1, [3728, -240, 144, 260]),
    "dressing_costume_rail": _h("hiding", "dressing", 3980, 1, [3906, -450, 150, 470]),
    "dressing_trophy_shelf": _h("rig_point", "dressing", 4300, 1, [4228, -566, 144, 182], station="st_trophy"),
    "dressing_dummy": _h("rig_point", "dressing", 4420, -1, [4348, -360, 144, 380], station="st_dummy"),
}

# Shared objects whose boxes must be stacked vertically (TECH §14) + the ones this layout adds.
STACKS = [
    ("kitchen_fridge", "kitchen_fridge_shelf"),
    ("kitchen_pantry_shelf", "kitchen_pantry_curtain"),
    ("hall_clock", "hall_clock_case"),
    ("landing_airing_cupboard", "landing_boiler_valve"),
    ("bathroom_bath_taps", "bathroom_bath", "bathroom_duck"),
    ("bedroom_bed", "bedroom_under_bed", "bedroom_pillow"),
    ("stairs_rods", "stairs_foot"),
    # layout additions (same object or same station column)
    ("kitchen_kettle", "kitchen_honey"),
    ("kitchen_sink_tap", "kitchen_window"),
    ("parlour_piano_back", "parlour_piano_wedge"),
    ("parlour_recliner", "parlour_newspaper"),
    ("parlour_tea_tray", "parlour_fan"),
    ("garden_compost", "garden_spotlight"),
]

# Atlas raster hints (STYLE §8 `raster`; s2-view builds room atlases with s2-rig's per-path scale): the big hiding
# pieces, doors and the tall furniture rasterise at 1.5x instead of 2x (they are never the punch-in subject at
# more than 1.4x), so every slice room's props + outlines fit one 2048^2 page. Outline `_ol` sprites are 1x by
# convention (no hint needed); anything unlisted is 2x (1.5x on < 3 GB phones, as HiResTex does).
RASTER = {
    # hiding pieces
    "hall_coat_cupboard": 1.5, "hall_clock_case": 1.5, "parlour_piano_back": 1.5, "parlour_chaise_back": 1.5,
    "kitchen_pantry_curtain": 1.5, "kitchen_table": 1.5,
    # doors, the entry window, tall furniture
    "hall_front_door": 1.5, "kitchen_back_door": 1.5, "kitchen_window": 1.5, "hall_mirror": 1.5,
    "parlour_gramophone": 1.5, "kitchen_fridge": 1.5, "hall_confiscated_box": 1.5, "parlour_recliner": 1.5,
    "parlour_chandelier": 1.5, "parlour_fan": 1.5, "parlour_portrait": 1.5,
    # soft glows / big flat decor
    "hall_front_door_glow": 1.0, "hall_coat_stand": 1.5,
}

# Reaction landing targets per room (x only; GDD §4.8 / §5.7)
LANDINGS = {
    "kitchen": {"sink": 3760, "table": 3450},
    "parlour": {"log_basket": 2236, "chandelier": 2330},
    "hall": {"coat_stand": 862, "umbrella_stand": 862, "front_door": 540},
    "porch": {"hedge": 230},
    "conservatory": {"hamper": 4190},
    "garden": {"pond": 6060, "roses": 5000, "compost": 5875},
    "landing": {"stair_head": 1050},
    "bathroom": {"laundry_basket": 2702},
    "bedroom": {"bed": 3168, "doorway": 2830},
    "dressing": {"costume_rail": 3980},
}

ENTRIES = {
    "window": {"room": "kitchen", "x": 3800},
    "gate": {"room": "garden", "x": 6150},
    "doorstep": {"room": "porch", "x": 350},
}

# Station moves vs GDD §7.1 (reported)
MOVES = {
    "st_tea": "2960 -> 2940 (kitchen row packed at 170 px so the back door box fits); stand_x 3000 facing -1 "
              "(Stage 2: he sits on the stool right of the counter, back to the pantry + sink, so the sneeze "
              "rockets him backwards into the sink at 3760)",
    "st_pickles": "3130 -> 3110",
    "st_fridge": "3300 -> 3280",
    "st_sink": "3800 -> 3788",
    "st_hall_mirror": "1160 -> 1112 (hall row: box, phone, mirror, clock, stairs at 168 px)",
    "st_phone": "980 -> 944",
    "st_clock": "1340 -> 1280",
    "st_marrow": "5180 -> 5140 (coin boxes on the path)",
    "st_bath": "2520 -> 2470 (bath centre; taps and duck share the rim)",
    "st_bed": "3200 -> 3168 (bed centre, bedside table at 3420)",
    "st_wardrobe": "2920 -> 2910",
}


def room_floor_y(room):
    return FLOORS[ROOM[room]["floor"]]


def room_of_x(floor, x):
    for r in ROOMS:
        if r[1] == floor and r[2] <= x < r[3]:
            return r[0]
    return None
