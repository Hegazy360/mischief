## Tests for res://data/house/house.json (owner: art-house) — TECH §4.1, §10.5, §14.
## house.json parses; every canonical room / link / station / hotspot id is present; every art path
## exists; hit boxes follow the hotspot rules (>= 144 px, >= 24 px dead space, no overlaps, shared
## objects stacked); links, landings, entries and stations sit in real rooms.
extends TestBase

const HOUSE := "res://data/house/house.json"

const ROOMS := {
	"porch": [0, 0, 500, true], "hall": [0, 500, 1500, false], "parlour": [0, 1500, 2800, false],
	"kitchen": [0, 2800, 3900, false], "conservatory": [0, 3900, 4700, false], "garden": [0, 4700, 6200, true],
	"landing": [1, 1000, 1800, false], "bathroom": [1, 1800, 2800, false], "bedroom": [1, 2800, 3700, false],
	"dressing": [1, 3700, 4500, false],
}
const LINKS := ["front_door", "hall_parlour", "parlour_kitchen", "back_door", "conservatory_garden",
	"landing_bathroom", "bathroom_bedroom", "bedroom_dressing", "stairs"]
const STATIONS := {
	"st_gramophone": [], "st_piano": [], "st_recliner": [], "st_fireplace": ["DRY"], "st_chaise": [],
	"st_parlour_centre": [], "st_tea": ["HONEY"], "st_pickles": [], "st_fridge": [], "st_sink": ["SINK"],
	"st_hall_mirror": ["MIRROR"], "st_phone": [], "st_clock": [], "st_front_door": [], "st_feed_bin": [],
	"st_sun_lounger": ["DRY"], "st_hose": [], "st_marrow": [], "st_path": [], "st_stage": [],
	"st_radiator": ["DRY"], "st_basin": ["SINK", "MIRROR"], "st_bath": [], "st_wardrobe": [], "st_bed": [],
	"st_dressing_mirror": ["MIRROR"], "st_trophy": [], "st_dummy": [],
}
## GDD §7.1 guide x per station (the house may shift a station <= 80 px).
const GDD_X := {
	"st_gramophone": 1640, "st_piano": 1840, "st_recliner": 2080, "st_fireplace": 2330, "st_chaise": 2560,
	"st_tea": 2960, "st_pickles": 3130, "st_fridge": 3300, "st_sink": 3800, "st_hall_mirror": 1160,
	"st_phone": 980, "st_clock": 1340, "st_front_door": 520, "st_feed_bin": 4020, "st_sun_lounger": 4480,
	"st_hose": 4820, "st_marrow": 5180, "st_path": 5260, "st_radiator": 1450, "st_basin": 1930,
	"st_bath": 2520, "st_wardrobe": 2920, "st_bed": 3200, "st_dressing_mirror": 4160, "st_trophy": 4300,
	"st_dummy": 4420,
}
const CONTAINERS := ["hall_confiscated_box", "hall_piggy_bank", "kitchen_fridge", "kitchen_pantry_shelf",
	"bathroom_cabinet", "conservatory_potting_bench", "dressing_costume_trunk"]
## hiding spot -> in-use activity ("" = none)
const HIDING := {
	"hall_coat_cupboard": "", "hall_clock_case": "clock", "parlour_piano_back": "", "parlour_chaise_back": "",
	"kitchen_pantry_curtain": "", "kitchen_table": "", "conservatory_hamper": "", "garden_shed": "",
	"garden_compost": "", "landing_airing_cupboard": "", "bathroom_bath": "bath", "bathroom_laundry_basket": "",
	"bedroom_wardrobe": "dress", "bedroom_under_bed": "", "dressing_costume_rail": "",
}
const RIG_POINTS := ["kitchen_honey", "kitchen_kettle", "kitchen_pickle_jar", "kitchen_fridge_shelf",
	"kitchen_sink_tap", "parlour_gramophone", "parlour_recliner", "parlour_newspaper", "parlour_bellows",
	"parlour_chandelier", "parlour_piano_wedge", "parlour_tea_tray", "parlour_fan", "hall_phone", "hall_clock",
	"hall_mirror", "stairs_rods", "bathroom_basin_spray", "bathroom_duck", "bathroom_bath_taps",
	"landing_boiler_valve", "bedroom_pillow", "bedroom_bedside", "bedroom_bed", "dressing_dummy",
	"dressing_trophy_shelf", "conservatory_feed_bin", "garden_hose", "garden_marrow", "garden_coin_1",
	"garden_coin_2", "garden_coin_3", "garden_spotlight"]
const EXITS := ["hall_front_door", "kitchen_back_door", "stairs_foot", "stairs_head", "kitchen_window"]
const SHARED := [["kitchen_fridge", "kitchen_fridge_shelf"], ["kitchen_pantry_shelf", "kitchen_pantry_curtain"],
	["hall_clock", "hall_clock_case"], ["landing_airing_cupboard", "landing_boiler_valve"],
	["bathroom_bath_taps", "bathroom_bath"], ["bedroom_bed", "bedroom_under_bed", "bedroom_pillow"],
	["stairs_rods", "stairs_foot"]]
const ITEMS := ["squeaker", "magnifier", "balloon", "croc", "kipper", "butter", "flour", "sherbet", "treacle", "salt",
	"bubble_bath", "apple", "feathers", "coins", "tutu", "record"]
const ACTIVITIES := ["warmup", "tea", "pickles", "snack", "rinse", "paper", "fire", "mirror", "phone", "clock",
	"piano", "gargle", "bath", "radiator", "dress", "nap", "feed_beryl", "roses", "marrow", "stroll", "polish",
	"cloak", "answer_door", "host_tea", "tango", "rehearse", "hunt", "fixup_dry", "fixup_sink", "fixup_honey",
	"fixup_mirror", "curious", "herd_beryl", "search"]
const MIN_BOX := 144.0
const GAP := 24.0

var _house: Dictionary = {}


func before_each() -> void:
	if _house.is_empty():
		var d: Variant = load_json(HOUSE)
		if d is Dictionary:
			_house = d


func _rooms() -> Dictionary:
	var out := {}
	for r in _house.get("rooms", []):
		out[r["id"]] = r
	return out


func _by_id(key: String) -> Dictionary:
	var out := {}
	for e in _house.get(key, []):
		out[e["id"]] = e
	return out


func _inside(room: Dictionary, x: float) -> bool:
	return float(room["x0"]) <= x and x <= float(room["x1"])


func _rect(h: Dictionary) -> Rect2:
	var r: Array = h["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Dead space between two boxes along x and y (negative = they overlap on that axis).
func _gaps(a: Rect2, b: Rect2) -> Vector2:
	var gx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var gy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	return Vector2(gx, gy)


func _exists(p: String) -> bool:
	return ResourceLoader.exists(p) or FileAccess.file_exists(p)


func test_house_json_parses() -> void:
	assert_false(_house.is_empty(), "house.json loads and parses")
	assert_eq(int(_house.get("version", 0)), 1, "version 1")
	assert_eq(int(_house.get("floor_pitch", 0)), 700, "floor pitch 700")
	assert_eq(int(_house.get("interior_h", 0)), 640, "interior 640")
	assert_eq(int(_house.get("slab_h", 0)), 60, "slab 60")
	var floors := {}
	for f in _house.get("floors", []):
		floors[int(f["index"])] = int(f["y"])
	assert_eq(floors, {0: 0, 1: -700}, "ground line y 0, upper line y -700")


func test_rooms_match_the_gdd() -> void:
	var rooms := _rooms()
	for id in ROOMS:
		if not assert_has(rooms, id, "room %s" % id):
			continue
		var want: Array = ROOMS[id]
		var r: Dictionary = rooms[id]
		assert_eq([int(r["floor"]), int(r["x0"]), int(r["x1"]), bool(r["outdoor"])], want, "room %s floor/x range/outdoor" % id)
	assert_eq(rooms.size(), ROOMS.size(), "exactly the 10 canonical rooms")


func test_links_are_canonical_and_on_shared_walls() -> void:
	var rooms := _rooms()
	var links := _by_id("links")
	for id in LINKS:
		assert_has(links, id, "link %s" % id)
	for l in links.values():
		if not (assert_has(rooms, l["a"], "%s.a" % l["id"]) and assert_has(rooms, l["b"], "%s.b" % l["id"])):
			continue
		var a: Dictionary = rooms[l["a"]]
		var b: Dictionary = rooms[l["b"]]
		if l["kind"] == "stairs":
			assert_true(_inside(a, float(l["ax"])) and _inside(b, float(l["bx"])), "stairs ends inside their rooms")
			assert_ne(int(a["floor"]), int(b["floor"]), "stairs join two floors")
			assert_almost_eq(float(l["hush_s"]), 1.0, 0.001, "Hush takes 1.0 s")
			assert_almost_eq(float(l["bellows_s"]), 1.8, 0.001, "Bellows takes 1.8 s")
		else:
			var x := float(l["x"])
			assert_true(int(a["floor"]) == int(b["floor"]) and (x == float(a["x0"]) or x == float(a["x1"]))
				and (x == float(b["x0"]) or x == float(b["x1"])), "%s sits on the wall %s/%s share" % [l["id"], l["a"], l["b"]])
	assert_eq(links["front_door"]["kind"], "door")
	assert_eq(links["back_door"]["kind"], "door")
	assert_eq(int(links["stairs"]["ax"]), 1450)
	assert_eq(int(links["stairs"]["bx"]), 1050)


func test_stations_are_canonical_and_near_the_gdd() -> void:
	var rooms := _rooms()
	var st := _by_id("stations")
	for id in STATIONS:
		if not assert_has(st, id, "station %s" % id):
			continue
		var s: Dictionary = st[id]
		var kinds: Array = s.get("kinds", [])
		kinds.sort()
		var want: Array = (STATIONS[id] as Array).duplicate()
		want.sort()
		assert_eq(kinds, want, "%s kinds" % id)
		assert_true(_inside(rooms[s["room"]], float(s["x"])) and _inside(rooms[s["room"]], float(s["stand_x"])), "%s inside %s" % [id, s["room"]])
		assert_true(int(s["facing"]) in [1, -1], "%s facing" % id)
		if GDD_X.has(id):
			assert_le(absf(float(s["x"]) - float(GDD_X[id])), 80.0, "%s x within 80 px of the GDD" % id)
	assert_has(st["st_hall_mirror"], "frame_x", "the hall mirror has Hush's stand-in point")


func test_every_canonical_hotspot_is_present_with_its_kind() -> void:
	var hs := _by_id("hotspots")
	for id in CONTAINERS:
		if assert_has(hs, id):
			assert_eq(hs[id]["kind"], "container", id)
	for id in HIDING:
		if assert_has(hs, id):
			assert_eq(hs[id]["kind"], "hiding", id)
			var use: Variant = hs[id].get("in_use_by")
			assert_eq("" if use == null else str(use), HIDING[id], "%s in_use_by" % id)
	for id in RIG_POINTS:
		if assert_has(hs, id):
			assert_eq(hs[id]["kind"], "rig_point", id)
	for id in EXITS:
		assert_has(hs, id)
	assert_eq(hs["hall_front_door"]["kind"], "exit", "the front door is the Take a Bow exit")
	assert_eq(hs["stairs_foot"]["link"], "stairs")
	assert_eq(hs["stairs_head"]["link"], "stairs")
	assert_eq(hs["kitchen_back_door"]["link"], "back_door")
	assert_false(bool(hs["kitchen_window"].get("tappable", true)), "the kitchen window is Hush's entry, not a target")


func test_hotspot_fields_reference_real_things() -> void:
	var rooms := _rooms()
	var st := _by_id("stations")
	var links := _by_id("links")
	for h in _house.get("hotspots", []):
		var id: String = h["id"]
		if not assert_has(rooms, h["room"], "%s room" % id):
			continue
		assert_true(_inside(rooms[h["room"]], float(h["use_x"])), "%s use_x inside %s" % [id, h["room"]])
		assert_true(int(h["facing"]) in [1, -1], "%s facing" % id)
		if h.has("station"):
			assert_has(st, h["station"], "%s station" % id)
		if h.has("link"):
			assert_has(links, h["link"], "%s link" % id)


func test_hit_boxes_follow_the_hotspot_rules() -> void:
	var rooms := _rooms()
	var hs: Array = _house.get("hotspots", [])
	for h in hs:
		var r := _rect(h)
		assert_true(r.size.x >= MIN_BOX and r.size.y >= MIN_BOX, "%s hit box %s >= 144 x 144" % [h["id"], r.size])
	for i in hs.size():
		for j in range(i + 1, hs.size()):
			var a: Dictionary = hs[i]
			var b: Dictionary = hs[j]
			if int(rooms[a["room"]]["floor"]) != int(rooms[b["room"]]["floor"]):
				continue
			var g := _gaps(_rect(a), _rect(b))
			assert_true(g.x >= GAP or g.y >= GAP, "%s / %s need >= 24 px dead space (gap %s)" % [a["id"], b["id"], g])


func test_shared_objects_are_stacked_vertically() -> void:
	var hs := _by_id("hotspots")
	for grp in SHARED:
		for m in grp:
			if not assert_has(hs, m):
				return
		for p in grp.size():
			var same_column := false
			for q in grp.size():
				if p == q:
					continue
				var g := _gaps(_rect(hs[grp[p]]), _rect(hs[grp[q]]))
				if g.x < 0.0:
					same_column = true
					assert_ge(g.y, GAP, "%s / %s stacked with a 24 px gap" % [grp[p], grp[q]])
			assert_true(same_column, "%s shares a column with its object" % grp[p])


func test_landings_entries_and_quake_props_are_inside_their_rooms() -> void:
	var rooms := _rooms()
	var want := {"kitchen": ["sink", "table"], "parlour": ["log_basket", "chandelier"],
		"hall": ["coat_stand", "umbrella_stand", "front_door"], "porch": ["hedge"], "conservatory": ["hamper"],
		"garden": ["pond", "roses", "compost"], "landing": ["stair_head"], "bathroom": ["laundry_basket"],
		"bedroom": ["bed", "doorway"], "dressing": ["costume_rail"]}
	var landings: Dictionary = _house.get("landings", {})
	for room in want:
		if not assert_has(landings, room, "landings for %s" % room):
			continue
		for k in want[room]:
			if assert_has(landings[room], k, "%s landing %s" % [room, k]):
				assert_true(_inside(rooms[room], float(landings[room][k])), "%s.%s inside the room" % [room, k])
	var entries: Dictionary = _house.get("entries", {})
	for k in ["window", "gate", "doorstep"]:
		if assert_has(entries, k):
			assert_true(_inside(rooms[entries[k]["room"]], float(entries[k]["x"])), "entry %s inside its room" % k)
	assert_eq(entries["window"]["room"], "kitchen")
	assert_eq(entries["doorstep"]["room"], "porch")
	var quake: Dictionary = _house.get("quake_props", {})
	var need := {"parlour": ["picture_frame", "vase", "portrait"], "kitchen": ["pans"], "hall": ["hats"]}
	for room in need:
		if not assert_has(quake, room):
			continue
		var names := []
		for q in quake[room]:
			names.append(q["prop"])
			assert_true(_inside(rooms[room], float(q["x"])), "quake prop %s inside %s" % [q["prop"], room])
		for n in need[room]:
			assert_has(names, n, "%s quake prop %s" % [room, n])


func test_every_art_path_exists() -> void:
	var missing: Array[String] = []
	for r in _house.get("rooms", []):
		for k in ["bg", "fg"]:
			if not _exists(r["art"][k]):
				missing.append(r["art"][k])
	for h in _house.get("hotspots", []):
		var art: Dictionary = h.get("art", {})
		if bool(h.get("tappable", true)):
			assert_true(art.has("idle") and art.has("outline"), "%s has idle art + an outline sprite" % h["id"])
		for s in art:
			if not _exists(art[s]):
				missing.append(art[s])
	for d in _house.get("decor", []):
		for s in d["art"]:
			if not _exists(d["art"][s]):
				missing.append(d["art"][s])
	var stage: Dictionary = _house.get("stage", {})
	for k in stage:
		if stage[k] is Dictionary and stage[k].has("art") and not _exists(stage[k]["art"]):
			missing.append(stage[k]["art"])
	for p in stage.get("pieces", []):
		if not _exists(p["art"]):
			missing.append(p["art"])
	assert_eq(missing, [] as Array[String], "every art path exists")


func test_item_and_activity_icons_exist() -> void:
	for it in ITEMS:
		assert_true(_exists("res://art/house/items/%s.svg" % it), "item icon %s" % it)
	for a in ACTIVITIES:
		assert_true(_exists("res://art/icons/activities/%s.svg" % a), "activity icon %s" % a)
	for s in ["curtain", "curtain_valance", "proscenium_l", "proscenium_r", "apron", "footlight_glow", "flies",
			"vignette_top", "velvet_rope"]:
		assert_true(_exists("res://art/house/stage/%s.svg" % s), "stage %s" % s)


func test_prop_textures_load_at_their_declared_size() -> void:
	# Only when the sandbox imported the SVGs (the runner always imports).
	var h: Dictionary = _by_id("hotspots").get("kitchen_honey", {})
	if h.is_empty() or not ResourceLoader.exists(h["art"]["idle"]):
		skip("SVGs not imported in this run")
		return
	var tex := load(h["art"]["idle"]) as Texture2D
	if not assert_true(tex != null, "honey jar texture loads"):
		return
	assert_eq(Vector2i(tex.get_size()), Vector2i(int(h["art_size"][0]), int(h["art_size"][1])), "art_size = the idle canvas size")
