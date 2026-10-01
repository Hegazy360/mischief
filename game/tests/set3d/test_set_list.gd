## SetList — the strike rule (REDESIGN_3D §3.2) reproduces the §3.4 tables exactly, per room per Night: live /
## furniture / struck ids, the density limits (≤ 5 live, ≤ 4 dressing, one hiding spot per room), rooms lit /
## backstage / not built, and the local live rule == `SimCtx.live_hotspots()`.
extends TestBase

const SLICE: Array[String] = ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]

## REDESIGN_3D §3.4, per Night → room → {live, furniture, struck} (hotspot ids of house.json; doors / exits / stairs
## and dormant parts are architecture and are not listed).
const TABLE := {
	"p00_curtain_up": {
		"kitchen": {"live": ["kitchen_honey", "kitchen_pantry_curtain"], "furniture": ["kitchen_kettle", "kitchen_sink_tap"],
			"struck": ["kitchen_pickle_jar", "kitchen_fridge_shelf", "kitchen_fridge", "kitchen_table"]},
		"parlour": {"live": ["parlour_gramophone", "parlour_piano_back"], "furniture": [],
			"struck": ["parlour_recliner", "parlour_newspaper", "parlour_chandelier", "parlour_chaise_back", "parlour_tea_tray", "parlour_fan"]},
		"hall": {"live": [], "furniture": ["hall_mirror"],
			"struck": ["hall_coat_cupboard", "hall_confiscated_box", "hall_phone", "hall_piggy_bank", "hall_clock", "hall_clock_case"]},
	},
	"g0_sneeze": {
		"kitchen": {"live": ["kitchen_honey", "kitchen_pantry_curtain"], "furniture": ["kitchen_kettle", "kitchen_sink_tap"],
			"struck": ["kitchen_pickle_jar", "kitchen_fridge_shelf", "kitchen_fridge", "kitchen_table"]},
		"parlour": {"live": [], "furniture": ["parlour_gramophone"],
			"struck": ["parlour_piano_back", "parlour_recliner", "parlour_newspaper", "parlour_chandelier", "parlour_chaise_back", "parlour_tea_tray", "parlour_fan"]},
		"hall": {"live": [], "furniture": ["hall_mirror"],
			"struck": ["hall_coat_cupboard", "hall_confiscated_box", "hall_phone", "hall_piggy_bank", "hall_clock", "hall_clock_case"]},
	},
	"n01_throat_tea": {
		"kitchen": {"live": ["kitchen_honey", "kitchen_kettle", "kitchen_pickle_jar", "kitchen_sink_tap", "kitchen_pantry_curtain"], "furniture": [],
			"struck": ["kitchen_fridge_shelf", "kitchen_fridge", "kitchen_table"]},
		"parlour": {"live": ["parlour_recliner", "parlour_piano_back"], "furniture": ["parlour_gramophone", "parlour_newspaper", "parlour_chandelier"],
			"struck": ["parlour_chaise_back", "parlour_tea_tray", "parlour_fan"]},
		"hall": {"live": ["hall_confiscated_box", "hall_coat_cupboard"], "furniture": ["hall_mirror"],
			"struck": ["hall_phone", "hall_piggy_bank", "hall_clock", "hall_clock_case"]},
	},
	"n02_something_fishy": {
		"kitchen": {"live": ["kitchen_fridge_shelf", "kitchen_fridge", "kitchen_pantry_curtain"], "furniture": ["kitchen_sink_tap"],
			"struck": ["kitchen_honey", "kitchen_kettle", "kitchen_pickle_jar", "kitchen_table"]},
		"parlour": {"live": ["parlour_newspaper", "parlour_piano_back"], "furniture": ["parlour_recliner"],
			"struck": ["parlour_gramophone", "parlour_chandelier", "parlour_chaise_back", "parlour_tea_tray", "parlour_fan"]},
		"hall": {"live": ["hall_confiscated_box", "hall_coat_cupboard", "hall_phone", "hall_clock", "hall_mirror"], "furniture": [],
			"struck": ["hall_piggy_bank", "hall_clock_case"]},
	},
}
const ROOMS := {
	"p00_curtain_up": {"lit": ["parlour", "kitchen"], "backstage": ["hall"]},
	"g0_sneeze": {"lit": ["parlour", "kitchen"], "backstage": ["hall"]},
	"n01_throat_tea": {"lit": ["porch", "hall", "parlour", "kitchen"], "backstage": []},
	"n02_something_fishy": {"lit": ["porch", "hall", "parlour", "kitchen"], "backstage": []},
}
## Dressing per Night per room (REDESIGN §3.4 dressing rows, as built: quake props = pans, hats, portrait).
const DRESSING := {
	"p00_curtain_up": {"kitchen": ["kitchen_window", "kitchen_lamp"], "parlour": ["parlour_window", "parlour_portrait", "parlour_picture_frame"], "hall": []},
	"n01_throat_tea": {"kitchen": ["kitchen_window", "kitchen_lamp", "kitchen_pans"], "parlour": ["parlour_window", "parlour_portrait", "parlour_log_basket"],
		"hall": ["hall_window", "hall_coat_stand", "hall_hats"]},
	"n02_something_fishy": {"kitchen": ["kitchen_window", "kitchen_lamp", "kitchen_pans"], "parlour": ["parlour_window", "parlour_portrait"],
		"hall": ["hall_window", "hall_coat_stand", "hall_hats"]},
}

var db: ContentDB = null


func before_each() -> void:
	if db == null:
		db = ContentDB.load_dir("res://data")


func _res(ep_id: String) -> SetList.Result:
	return SetList.for_episode(db, db.episodes[ep_id])


func test_rooms_lit_backstage_not_built() -> void:
	for ep_id in SLICE:
		var res := _res(ep_id)
		var want: Dictionary = ROOMS[ep_id]
		assert_eq(_sorted(res.rooms_lit), _sorted(PackedStringArray(want["lit"])), "%s lit" % ep_id)
		assert_eq(_sorted(res.rooms_backstage), _sorted(PackedStringArray(want["backstage"])), "%s backstage" % ep_id)
		for rid in ["conservatory", "garden", "landing", "bathroom", "bedroom", "dressing"]:
			assert_false(res.is_room_built(rid), "%s: %s not built" % [ep_id, rid])


func test_the_redesign_tables_per_room_per_night() -> void:
	for ep_id in TABLE.keys():
		var res := _res(ep_id)
		for room in (TABLE[ep_id] as Dictionary).keys():
			var want: Dictionary = TABLE[ep_id][room]
			assert_eq(_sorted(res.live_props_in(room)), _sorted(PackedStringArray(want["live"])), "%s %s live" % [ep_id, room])
			assert_eq(_sorted(res.ids_in(room, &"furniture")), _sorted(PackedStringArray(want["furniture"])), "%s %s furniture" % [ep_id, room])
			for id in want["struck"]:
				assert_eq(res.role(id), &"struck", "%s %s: %s struck" % [ep_id, room, id])


func test_density_limits() -> void:
	for ep_id in SLICE:
		var res := _res(ep_id)
		var h3 := SetGeo.load_house3d()
		for room in res.rooms_lit:
			var live := res.live_props_in(room)
			assert_le(live.size(), 5, "%s %s: ≤ 5 live props" % [ep_id, room])
			var hides := 0
			for id in live:
				if String(res.live[id]) == "hide":
					hides += 1
			if room != "porch":
				assert_le(hides, 1, "%s %s: one hiding spot per room" % [ep_id, room])
			var dressing := 0
			for did in res.dressing:
				if String((h3["dressing"][did] as Dictionary).get("room", "")) == room:
					dressing += 1
			for cid in res.decor:
				var cd: Dictionary = h3["decor"][cid]
				if String(cd.get("room", "")) == room and bool(cd.get("dressing", false)):
					dressing += 1
			assert_le(dressing, 4, "%s %s: ≤ 4 dressing pieces" % [ep_id, room])


func test_dressing_per_night() -> void:
	var h3 := SetGeo.load_house3d()
	for ep_id in DRESSING.keys():
		var res := _res(ep_id)
		for room in (DRESSING[ep_id] as Dictionary).keys():
			var got := PackedStringArray()
			for did in res.dressing:
				if String((h3["dressing"][did] as Dictionary).get("room", "")) == room:
					got.append(did)
			for cid in res.decor:
				var cd: Dictionary = h3["decor"][cid]
				if String(cd.get("room", "")) == room and bool(cd.get("dressing", false)):
					got.append(cid)
			assert_eq(_sorted(got), _sorted(PackedStringArray(DRESSING[ep_id][room])), "%s %s dressing" % [ep_id, room])


func test_n1_struck_table_and_fridge_never_instanced() -> void:
	var res := _res("n01_throat_tea")
	for id in ["kitchen_table", "kitchen_fridge", "kitchen_fridge_shelf"]:
		assert_false(res.is_built(id), "%s not built in N1" % id)
	var h := House3D.new()
	h.build(res, {}, db)
	for id in ["kitchen_table", "kitchen_fridge", "kitchen_fridge_shelf"]:
		assert_true(h.prop(id) == null, "%s never instanced in N1" % id)
	h.free()


func test_steps_handoffs_and_landings_are_kept() -> void:
	var p00 := _res("p00_curtain_up")
	assert_has(p00.furniture_pieces, "kitchen_stool", "the stool (st_tea + ACHOO-RIA!'s step)")
	assert_has(p00.handoffs, "kitchen_kettle")
	assert_has(p00.handoffs, "kitchen_honey")
	assert_has(p00.landings, "kitchen.sink")
	var n01 := _res("n01_throat_tea")
	assert_has(n01.landings, "parlour.log_basket")
	var n02 := _res("n02_something_fishy")
	assert_has(n02.landings, "hall.coat_stand")
	assert_has(n02.furniture_pieces, "hall_phone_table")
	assert_false(n02.furniture_pieces.has("kitchen_stool"), "no tea in N2: the stool is struck")


func test_quake_props_only_where_a_meltdown_can_happen() -> void:
	assert_true(_res("p00_curtain_up").quake.is_empty(), "the Prologue cannot fail: no quake props")
	var n01 := _res("n01_throat_tea")
	assert_true(n01.meltdown)
	for q in ["kitchen_pans", "parlour_portrait", "hall_hats"]:
		assert_has(n01.quake, q)


func test_local_rule_equals_sim_live_hotspots() -> void:
	if not SetList._sim_has_live():
		skip("SimCtx.live_hotspots not built yet — r3d-content")
		return
	for ep_id in SLICE:
		var ep: EpisodeDef = db.episodes[ep_id]
		var sim: Dictionary = SimCtx.live_hotspots(db, ep)
		var loc := SetList.local_live(db, ep)
		assert_eq(_sorted(PackedStringArray(loc.keys())), _sorted(PackedStringArray(sim.keys())), "%s: local == sim ids" % ep_id)
		for id in sim.keys():
			assert_eq(String(loc.get(id, "")), String(sim[id]), "%s %s kind" % [ep_id, id])


func test_derived_not_hand_written() -> void:
	# a Night without Script lines builds nothing live but its hiding spots
	var ep: EpisodeDef = db.episodes["n01_throat_tea"]
	var raw := ep.raw.duplicate(true)
	raw["script"] = []
	raw["id"] = "test_no_pranks"
	var ep2 := EpisodeDef.from_dict(raw)
	var res := SetList.for_episode(db, ep2, {}, false)
	for id in res.live.keys():
		assert_true(String(res.live[id]) in ["hide", "exit", "door", "stairs"], "no prank tonight: %s cannot be live (%s)" % [id, res.live[id]])


func _sorted(a: PackedStringArray) -> PackedStringArray:
	var b := a.duplicate()
	b.sort()
	return b
