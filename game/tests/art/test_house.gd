## Tests for res://data/house/house.json (owner: art-house) — TECH §4.1, §10.5, §14.
## house.json parses; every canonical room / link / station / hotspot id is present; every art path
## exists; hit boxes follow the hotspot rules (>= 144 px, >= 24 px dead space, no overlaps, shared
## objects stacked); links, landings, entries and stations sit in real rooms.
extends TestBase

const HOUSE := "res://data/house/house.json"
const COLD := "res://data/house/cold_sets.json"
## Cold-open sets the slice plays (GDD §7.2; s2-ftue stages them).
const COLD_SETS := ["n01_throat_tea", "n02_something_fishy"]

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
	"fixup_mirror", "curious", "herd_beryl", "search", "exit"]
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
	for b in stage.get("title_card", {}).get("bulbs", []):
		if not _exists(b):
			missing.append(b)
	assert_eq(missing, [] as Array[String], "every art path exists")


func test_item_and_activity_icons_exist() -> void:
	for it in ITEMS:
		assert_true(_exists("res://art/house/items/%s.svg" % it), "item icon %s" % it)
	for a in ACTIVITIES:
		assert_true(_exists("res://art/icons/activities/%s.svg" % a), "activity icon %s" % a)
	for s in ["curtain", "curtain_valance", "proscenium_l", "proscenium_r", "apron", "footlight_glow", "flies",
			"vignette_top", "velvet_rope", "bow_spot", "front_door_glow", "title_card", "title_card_bulbs_a",
			"title_card_bulbs_b"]:
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


# ------------------------------------------------------------------------------ Stage 2 (s2-art)

func test_st_tea_faces_the_counter_from_the_right() -> void:
	var st: Dictionary = _by_id("stations").get("st_tea", {})
	if not assert_false(st.is_empty(), "st_tea exists"):
		return
	assert_eq(int(st["facing"]), -1, "st_tea faces -1 (the counter), his back to the pantry + sink")
	assert_almost_eq(float(st["stand_x"]), 3000.0, 20.0, "st_tea stand_x ~3000, right of the counter")
	var sink_x := float(_house["landings"]["kitchen"]["sink"])
	assert_gt(sink_x, float(st["stand_x"]), "the sink landing is behind him (to his right)")
	var stool: Dictionary = _by_id("decor").get("kitchen_stool", {})
	if not assert_false(stool.is_empty(), "kitchen_stool decor exists"):
		return
	var pv: Dictionary = stool.get("pivots", {})
	if assert_has(pv, "seat", "the stool documents its seat pivot") and assert_has(pv, "foot"):
		assert_almost_eq(float(stool["pos"][0]) + float(pv["seat"][0]), float(st["stand_x"]), 1.0, "the stool sits under his seat")
		assert_almost_eq(float(stool["pos"][1]) + float(pv["foot"][1]), 0.0, 1.0, "the stool's foot pivot is on the floor")
		assert_true(float(pv["seat"][0]) >= 0.0 and float(pv["seat"][0]) <= float(stool["size"][0]), "seat pivot inside the canvas")


func test_decor_schema() -> void:
	var rooms := _rooms()
	var ids := {}
	for d in _house.get("decor", []):
		var id: String = d["id"]
		assert_false(ids.has(id), "decor id %s unique" % id)
		ids[id] = true
		assert_has(rooms, d["room"], "%s room" % id)
		assert_true(d["pos"] is Array and (d["pos"] as Array).size() == 2, "%s pos [x, y]" % id)
		assert_true(d["size"] is Array and (d["size"] as Array).size() == 2, "%s size [w, h]" % id)
		assert_true((d["art"] as Dictionary).has("idle"), "%s has idle art" % id)
		for s in d["art"]:
			assert_true(d["art"][s] is String, "%s art.%s is a path" % [id, s])
		assert_true(int(d.get("z", 0)) in [-1, 0, 1, 2], "%s z in -1..2" % id)
		if d.has("frames") or d.has("fps"):
			assert_true(d.get("frames") is Array and (d["frames"] as Array).size() >= 2, "%s frames: >= 2 paths" % id)
			assert_true(float(d.get("fps", 0.0)) > 0.0 and float(d.get("fps", 0.0)) <= 30.0, "%s fps in (0, 30]" % id)
			for f in d.get("frames", []):
				assert_true(f is String and _exists(f), "%s frame %s exists" % [id, f])
	var decor := _by_id("decor")
	for need in ["kitchen_stool", "kitchen_sink_lip", "parlour_vase", "parlour_picture_frame", "hall_front_door_glow"]:
		assert_has(decor, need, "decor %s" % need)
	if decor.has("kitchen_sink_lip"):
		assert_eq(int(decor["kitchen_sink_lip"]["z"]), 2, "the sink lip draws over the characters")
		assert_true(bool(decor["kitchen_sink_lip"].get("hidden", false)), "the sink lip is shown only by a decor event")


func test_raster_hints_are_valid() -> void:
	var n := 0
	for h in _house.get("hotspots", []):
		if h.has("raster"):
			n += 1
			assert_true(float(h["raster"]) in [1.0, 1.5, 2.0], "%s raster %s in {1, 1.5, 2}" % [h["id"], h["raster"]])
	for d in _house.get("decor", []):
		if d.has("raster"):
			assert_true(float(d["raster"]) in [1.0, 1.5, 2.0], "%s raster in {1, 1.5, 2}" % d["id"])
	assert_gt(n, 0, "the big hiding pieces carry a raster hint")


func test_every_occupied_state_has_an_eyes_point() -> void:
	var rooms := _rooms()
	for h in _house.get("hotspots", []):
		var art: Dictionary = h.get("art", {})
		if not art.has("occupied"):
			continue
		if not assert_has(h, "eyes", "%s occupied needs an eyes point" % h["id"]):
			continue
		var e: Array = h["eyes"]
		var ex := float(e[0])
		assert_true(_inside(rooms[h["room"]], ex), "%s eyes inside the room" % h["id"])
		var ap: Array = h["art_pos"]
		var asz: Array = h["art_size"]
		assert_true(ex >= float(ap[0]) and ex <= float(ap[0]) + float(asz[0]) and float(e[1]) >= float(ap[1])
			and float(e[1]) <= float(ap[1]) + float(asz[1]), "%s eyes inside the prop canvas" % h["id"])
		if h.has("eyes_scale"):
			assert_between(float(h["eyes_scale"]), 0.5, 1.2, "%s eyes_scale in [0.5, 1.2]" % h["id"])


func test_rooms_every_slice_shot_shows_are_final() -> void:
	# The upper floor above the slice and the conservatory edge are in every ground-floor frame (s2-art §4.2.2).
	for r in _house.get("rooms", []):
		var want := str(r["id"]) != "garden"
		assert_eq(bool(r["art"].get("final", false)), want, "room %s final = %s" % [r["id"], want])


func test_hidden_decor_says_what_shows_it() -> void:
	for d in _house.get("decor", []):
		if bool(d.get("hidden", false)):
			assert_true(str(d.get("show", "")) in ["event", "bow"], "%s hidden decor has show event|bow" % d["id"])
		if d.has("blend"):
			assert_eq(str(d["blend"]), "add", "%s blend is add" % d["id"])
	var frame: Dictionary = _by_id("decor").get("parlour_picture_frame", {})
	if assert_false(frame.is_empty(), "parlour_picture_frame decor"):
		assert_true((frame["art"] as Dictionary).has("falling"), "the picture has a falling sprite (laugh_picture)")
	var vase: Dictionary = _by_id("decor").get("parlour_vase", {})
	if assert_false(vase.is_empty(), "parlour_vase decor"):
		assert_has(vase, "slide", "the vase slides along the mantel")
		assert_has(_by_id("decor"), str(vase["slide"]["smashed"]), "the vase's smashed decor exists")
		assert_has(vase.get("pivots", {}), "base", "the vase has a base pivot")
	var fire: Dictionary = _by_id("decor").get("parlour_fire", {})
	if assert_false(fire.is_empty(), "parlour_fire decor"):
		assert_eq((fire["frames"] as Array).size(), 3, "the fire flickers in 3 frames")
		assert_almost_eq(float(fire["fps"]), 8.0, 0.01, "at 8 fps")
		assert_eq(str(fire["frames"][0]), str(fire["art"]["idle"]), "frames[0] is the idle art")


func test_title_card_contract() -> void:
	var tc: Dictionary = _house.get("stage", {}).get("title_card", {})
	if not assert_false(tc.is_empty(), "stage.title_card"):
		return
	assert_eq(str(tc["art"]), "res://art/house/stage/title_card.svg", "title card path")
	assert_eq((tc["bulbs"] as Array).size(), 2, "two bulb-chase overlays")
	for k in ["size", "pivot", "hang", "rest_center"]:
		assert_true(tc.get(k) is Array and (tc[k] as Array).size() == 2, "title_card.%s is [x, y]" % k)
	var sz: Array = tc["size"]
	assert_true(float(tc["pivot"][0]) > 0.0 and float(tc["pivot"][0]) < float(sz[0]) and float(tc["pivot"][1]) <= float(sz[1]),
		"the squash pivot lies on the card")
	assert_gt(float(tc["chase_hz"]), 0.0, "bulbs chase")
	if ResourceLoader.exists(tc["art"]):
		var tex := load(tc["art"]) as Texture2D
		if assert_true(tex != null, "title card texture loads"):
			assert_eq(Vector2i(tex.get_size()), Vector2i(int(sz[0]), int(sz[1])), "title_card.size = its canvas")


func test_cold_sets_schema_and_paths() -> void:
	var d: Variant = load_json(COLD)
	if not assert_true(d is Dictionary, "cold_sets.json parses"):
		return
	var data: Dictionary = d
	assert_eq(int(data.get("version", 0)), 1, "cold_sets version 1")
	var sets: Dictionary = data.get("sets", {})
	for sid in COLD_SETS:
		if not assert_has(sets, sid, "cold set %s" % sid):
			continue
		var cs: Dictionary = sets[sid]
		assert_eq(cs.get("size", []), [2400, 1080], "%s composed on the 2400 x 1080 frame" % sid)
		var ids := {}
		for l in cs.get("layers", []):
			var lid: String = l["id"]
			assert_false(ids.has(lid), "%s layer %s unique" % [sid, lid])
			ids[lid] = l
			assert_true(_exists(str(l["art"])), "%s layer %s art exists" % [sid, lid])
			assert_true(l["pos"] is Array and (l["pos"] as Array).size() == 2, "%s layer %s pos [x, y]" % [sid, lid])
			assert_true(int(l["z"]) <= 0 or int(l["z"]) >= 2, "%s layer %s z is behind (<= 0) or over (>= 2) the actors" % [sid, lid])
		var states: Dictionary = cs.get("states", {})
		for lid in states:
			if not assert_has(ids, lid, "%s states.%s names a layer" % [sid, lid]):
				continue
			var st: Dictionary = states[lid]
			assert_gt(st.size(), 1, "%s layer %s has >= 2 states" % [sid, lid])
			assert_has(st, str(ids[lid].get("state", "")), "%s layer %s start state is one of its states" % [sid, lid])
			for k in st:
				assert_true(str(st[k]) == "" or _exists(str(st[k])), "%s %s.%s art exists (or empty = hidden)" % [sid, lid, k])
		var anchors: Dictionary = cs.get("anchors", {})
		for a in cs.get("actors", {}):
			if assert_has(anchors, a, "%s actor %s has an anchor" % [sid, a]):
				var ax := float(anchors[a][0])
				assert_between(ax, 240.0, 2160.0, "%s actor %s inside the 16:9 safe 1920 px" % [sid, a])
	var n1: Dictionary = sets.get("n01_throat_tea", {})
	assert_has(n1.get("states", {}).get("window_no9", {}), "cracked", "N1: No. 9's window cracks")
	var sill_over := false
	for l in n1.get("layers", []):
		sill_over = sill_over or int(l["z"]) >= 2
	assert_true(sill_over, "N1: a sill layer draws over his belly")
	var n2: Dictionary = sets.get("n02_something_fishy", {})
	assert_has(n2.get("states", {}).get("balloon", {}), "popped", "N2: the balloon pops")
	assert_has(n2.get("anchors", {}), "box", "N2: the CONFISCATED box anchor")
