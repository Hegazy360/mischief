## house3d.json — the data contract of the 3D sets (R3D index §7.4, R5; brief r3d-sets §5): every live hotspot of the
## slice Nights has a full entry, anchors sit in their prop, the reach targets' bands and distances, steps, hit boxes,
## landings, hand-offs, quake-prop heights.
extends TestBase

## Half the stool seat's width (index R5 table: the seat spans 14.77–15.24 m at z −1.4).
const STOOL_SEAT_HALF_M := 0.23

const SLICE: Array[String] = ["p00_curtain_up", "g0_sneeze", "n01_throat_tea", "n02_something_fishy"]
const STRICT: Array[String] = ["p00_curtain_up", "g0_sneeze"]
const PROP_FIELDS: Array[String] = ["model", "z", "yaw", "scale", "visual_offset", "bounds", "silhouette", "view_kind",
	"states", "anims", "tag_socket", "preview_anchor", "ring_anchor", "halo"]
const RIG_FIELDS: Array[String] = ["reach", "reach_target", "reach_pos"]
const PRIMITIVES: Array[String] = ["squat_jar", "round_kettle", "tall_jar", "gooseneck_tap", "tall_rounded_box",
	"arched_alcove", "big_horn", "upright_block", "fat_armchair", "folded_broadsheet", "banded_crate",
	"candlestick_phone", "oval_on_stand", "tall_case_clock", "tall_wardrobe", "chandelier", "door_leaf", "stool", "table", "window",
	"lamp", "pan_rail", "frame", "basket", "coat_stand", "hats", "vase", "shards", "fire", "door_glow", "box"]

var db: ContentDB = null
var h3: Dictionary = {}


func before_each() -> void:
	if db == null:
		db = ContentDB.load_dir("res://data")
	SetGeo.clear_cache()
	h3 = SetGeo.load_house3d()


func test_parses_with_every_block() -> void:
	assert_false(h3.is_empty(), "house3d.json parses")
	for k in ["version", "units", "reach", "stage", "rooms", "hotspots", "stations", "furniture", "landings", "dressing", "decor", "hide"]:
		assert_true(h3.has(k), "block %s" % k)
	assert_eq(float((h3["units"] as Dictionary)["px_per_m"]), 200.0)


func test_every_live_hotspot_has_a_full_entry() -> void:
	var hs3: Dictionary = h3["hotspots"]
	for ep_id in SLICE:
		var res := SetList.for_episode(db, db.episodes[ep_id], h3)
		for id in res.live.keys():
			var kind := String(res.live[id])
			if not (kind in ["rig", "take", "hide"]):
				continue
			if not assert_true(hs3.has(id), "%s: live %s has a house3d.json entry" % [ep_id, id]):
				continue
			var e: Dictionary = hs3[id]
			for f in PROP_FIELDS:
				assert_true(e.has(f), "%s.%s" % [id, f])
			if kind == "rig":
				for f in RIG_FIELDS:
					assert_true(e.has(f), "%s.%s (rig)" % [id, f])
			if kind == "hide":
				assert_true(e.get("eyes_anchor", null) != null, "%s.eyes_anchor (hide)" % id)
				assert_true((h3["hide"] as Dictionary).has(id), "hide.%s (occupant_z, anims)" % id)
			if kind == "take":
				assert_true(e.get("item_anchor", null) != null, "%s.item_anchor (take)" % id)


func test_models_load_or_are_known_primitives() -> void:
	var tables := {"hotspots": "model", "furniture": "model", "dressing": "model", "decor": "model"}
	for t in tables.keys():
		var tab: Dictionary = h3[t]
		for id in tab.keys():
			var e: Dictionary = tab[id]
			if not e.has("model") or e["model"] == null:
				continue
			var m := String(e["model"])
			if m.begins_with("primitive:"):
				assert_has(PRIMITIVES, m.substr(10), "%s.%s primitive" % [t, id])
			elif m.begins_with("arch:"):
				var ok := false
				for rid in (h3["rooms"] as Dictionary).keys():
					if ((h3["rooms"][rid] as Dictionary).get("built_ins", {}) as Dictionary).has(m.substr(5)):
						ok = true
				assert_true(ok, "%s.%s arch piece %s exists" % [t, id, m])
			elif m.begins_with("res://"):
				var prim := String(e.get("primitive", ""))
				assert_true(ResourceLoader.exists(m) or PRIMITIVES.has(prim), "%s.%s: %s loads or has a primitive fallback" % [t, id, m])


func test_anchors_inside_the_prop_and_the_preview_band() -> void:
	var hs3: Dictionary = h3["hotspots"]
	for id in hs3.keys():
		var e: Dictionary = hs3[id]
		if not e.has("bounds"):
			continue
		var lb := SetGeo.local_bounds(e).grow(0.005)
		var zb := SetGeo.local_bounds(e, "zone_bounds").grow(0.005) if e.has("zone_bounds") else lb
		for k in ["tag_socket", "ring_anchor", "reach_target", "eyes_anchor"]:
			if e.get(k, null) == null:
				continue
			var p := SetGeo.vec3(e[k])
			assert_true((zb if k == "reach_target" else lb).has_point(p), "%s.%s %s inside its bounds %s" % [id, k, p, lb])
		if e.get("preview_anchor", null) != null:
			var top := lb.position.y + lb.size.y - 0.005
			var pa := SetGeo.vec3(e["preview_anchor"])
			var s := float(e.get("scale", 1.0))
			assert_almost_eq((pa.y - top) * s, 0.6, 0.06, "%s: preview anchor 0.6 m above the top (got %.2f)" % [id, (pa.y - top) * s])


func test_reach_bands_come_from_the_placed_targets() -> void:
	var cfg := SetGeo.reach_cfg(h3)
	var hs3: Dictionary = h3["hotspots"]
	var ra := _rig_actions()
	for id in hs3.keys():
		var e: Dictionary = hs3[id]
		if not e.has("reach_target"):
			continue
		var h := db.house.hotspot(id)
		if not assert_true(h != null, "%s in house.json" % id):
			continue
		var info := SetGeo.reach_info(h.rect, e, float(h.use_sub) / 12000.0, cfg)
		var band := String(info["band"])
		assert_ne(band, "", "%s: target y %.2f inside a band" % [id, (info["target"] as Vector3).y])
		assert_eq(String(e.get("reach", "")), band, "%s: reach field == placed band" % id)
		for pid in ra.keys():
			var row: Dictionary = ra[pid]
			if String(row.get("hotspot", "")) == id and row.has("band"):
				assert_eq(String(row["band"]), band, "%s: rig_actions.json %s band == house3d.json" % [id, pid])
			if String(row.get("hotspot", "")) == id and row.has("step"):
				var st: Variant = (e["reach_pos"] as Dictionary).get("step", null)
				assert_eq(row["step"], st, "%s: rig_actions.json %s step == house3d.json reach_pos.step" % [id, pid])


func test_reach_distance_p00_g0_errors_n01_n02_warnings() -> void:
	var cfg := SetGeo.reach_cfg(h3)
	var hs3: Dictionary = h3["hotspots"]
	var warn := PackedStringArray()
	for ep_id in SLICE:
		var res := SetList.for_episode(db, db.episodes[ep_id], h3)
		for id in res.live.keys():
			if String(res.live[id]) != "rig":
				continue
			var h := db.house.hotspot(id)
			var info := SetGeo.reach_info(h.rect, hs3[id], float(h.use_sub) / 12000.0, cfg)
			var msg := "%s %s: %.3f m from the nearer shoulder (≤ 0.50)" % [ep_id, id, float(info["dist"])]
			if STRICT.has(ep_id):
				assert_true(bool(info["ok"]), msg)
			elif not bool(info["ok"]):
				warn.append(msg)
			if bool(info["needs_step"]):
				assert_true(info["step"] != null, "%s %s: above 1.70 m needs a step" % [ep_id, id])
	if not warn.is_empty():
		print("  [warn] reach: ", "; ".join(warn))


func test_achoo_ria_climbs_bellows_stool() -> void:
	var e: Dictionary = h3["hotspots"]["kitchen_honey"]
	var rp: Dictionary = e["reach_pos"]
	assert_eq(String(rp["step"]), "stool:kitchen_stool")
	var stool: Dictionary = h3["furniture"]["kitchen_stool"]
	assert_almost_eq(float(stool["x_m"]), 15.0, 0.001, "the stool is Bellows' seat at st_tea.stand_x")
	assert_almost_eq(float(rp["step_h"]), float(stool["seat_y_m"]), 0.001)
	var h := db.house.hotspot("kitchen_honey")
	var stand_x := float(h.use_sub) / 12000.0 + float(rp["dx"])
	assert_true(absf(stand_x - 15.0) <= STOOL_SEAT_HALF_M, "Hush stands on the stool's seat (x %.2f, seat 15.0 ± %.2f)" % [stand_x, STOOL_SEAT_HALF_M])
	var st := db.house.station("st_tea")
	assert_almost_eq(float(st.stand_sub) / 12000.0, 15.0, 0.001)


func test_steps_name_furniture_or_mime() -> void:
	var fur: Dictionary = h3["furniture"]
	for id in (h3["hotspots"] as Dictionary).keys():
		var rp: Dictionary = (h3["hotspots"][id] as Dictionary).get("reach_pos", {})
		var st: Variant = rp.get("step", null)
		if st == null:
			continue
		if String(st).begins_with("stool:"):
			var fid := String(st).substr(6)
			assert_true(fur.has(fid) and (fur[fid] as Dictionary).has("seat_y_m"), "%s step %s is furniture with seat_y_m" % [id, st])
		else:
			assert_eq(String(st), "mime", "%s step" % id)
			assert_between(float(rp.get("step_h", 0.0)), 0.3, 0.45, "%s mime step_h" % id)
		assert_ge(float(rp.get("z", -1.6)), -1.6 - 1e-6, "%s reach_pos z ≥ −1.6" % id)


func test_hit_boxes_contain_their_visuals() -> void:
	var hs3: Dictionary = h3["hotspots"]
	for id in hs3.keys():
		var e: Dictionary = hs3[id]
		if not e.has("bounds") or String(e.get("model", "")).begins_with("arch:"):
			continue
		var h := db.house.hotspot(id)
		var xf := SetGeo.prop_xform(h.rect, e)
		var vis := SetGeo.world_aabb(xf, e, "zone_bounds" if e.has("zone_bounds") else "bounds")
		var box := SetGeo.hit_box(h.rect, e)
		assert_true(SetGeo.contains_xy(box, vis), "%s: hit box %s ⊇ visual %s" % [id, box, vis])


func test_default_hit_box_is_rect_plus_offset() -> void:
	var e: Dictionary = h3["hotspots"]["kitchen_kettle"]
	assert_eq(e.get("hit_box", null), null, "kitchen_kettle keeps the default hit box")
	var h := db.house.hotspot("kitchen_kettle")
	var r := SetGeo.rect_m(h.rect)
	var box := SetGeo.hit_box(h.rect, e)
	var vo := SetGeo.vec2(e["visual_offset"])
	assert_almost_eq(box.position.x, r.position.x + vo.x, 0.001)
	assert_almost_eq(box.position.y, r.position.y + vo.y, 0.001)
	assert_almost_eq(box.size.x, r.size.x, 0.001)
	assert_almost_eq(box.position.z, float(e["z"]) - 0.3, 0.001)
	assert_almost_eq(box.size.z, 0.6, 0.001)


func test_slice_landings_have_entries_and_boxes() -> void:
	var land: Dictionary = h3["landings"]
	for ep_id in SLICE:
		var res := SetList.for_episode(db, db.episodes[ep_id], h3)
		for l in res.landings:
			var parts := l.split(".")
			assert_true(land.has(parts[0]) and (land[parts[0]] as Dictionary).has(parts[1]), "%s landing %s has an entry" % [ep_id, l])
			var ld: Dictionary = (land.get(parts[0], {}) as Dictionary).get(parts[1], {})
			assert_eq((ld.get("box", []) as Array).size(), 6, "%s box" % l)
			var x := float(db.house.landing_sub(parts[0], parts[1])) / 12000.0
			var b: Array = ld.get("box", [0, 0, 0, 0, 0, 0])
			assert_true(x >= float(b[0]) and x <= float(b[3]), "%s: house.json x %.2f inside its box" % [l, x])
			assert_true(float(ld.get("y", -1)) >= float(b[1]) and float(ld.get("y", -1)) <= float(b[4]), "%s: pelvis y in the box" % l)
			assert_true(float(ld.get("z", 9)) >= float(b[2]) and float(ld.get("z", 9)) <= float(b[5]), "%s: z in the box" % l)
	for need in ["kitchen.sink", "parlour.log_basket", "parlour.chandelier", "hall.coat_stand"]:
		var p2: PackedStringArray = need.split(".")
		assert_true((land.get(p2[0], {}) as Dictionary).has(p2[1]), "landing %s" % need)


func test_handoffs_resolve() -> void:
	var st: Dictionary = h3["stations"]
	for sid in st.keys():
		assert_true(db.house.station(sid) != null, "station %s exists in house.json" % sid)
		for ho in (st[sid] as Dictionary).get("handoffs", []):
			var pid := String((ho as Dictionary).get("prop", ""))
			assert_true(pid.begins_with("set:"), "%s hand-off %s is a set piece" % [sid, pid])
			var id := pid.substr(4)
			assert_true((h3["hotspots"] as Dictionary).has(id) or (h3["furniture"] as Dictionary).has(id), "%s hand-off %s resolves" % [sid, id])
			assert_true(String((ho as Dictionary).get("socket", "")) != "", "%s hand-off %s socket" % [sid, id])
	var tea: Array = st["st_tea"]["handoffs"]
	assert_eq(tea.size(), 2, "st_tea lends the kettle and the honey")


func test_quake_props_hang_high_or_sit_on_the_mantel() -> void:
	var mantel_y := 1.46
	for id in (h3["dressing"] as Dictionary).keys():
		var d: Dictionary = h3["dressing"][id]
		if not bool(d.get("quake", false)):
			continue
		var y := float(d.get("y_m", 0.0))
		var on_mantel := String(d.get("room", "")) == "parlour" and absf(y - mantel_y) <= 0.05
		assert_true(y >= 2.2 - 1e-6 or on_mantel, "quake prop %s at %.2f m hangs ≥ 2.2 m or sits on the mantel" % [id, y])


func test_dressing_rules_out_of_the_lane_and_big() -> void:
	for id in (h3["dressing"] as Dictionary).keys():
		var d: Dictionary = h3["dressing"][id]
		var b: Array = d["box"]
		var y_top := float(d.get("y_m", 0.0)) + float(b[4])
		var z_front := float(d.get("z", -2.2)) + float(b[5])
		if z_front > -1.6:
			assert_le(y_top, 0.45 + 1e-6, "%s in the lane is ≤ 0.45 m" % id)
		var longest := maxf(float(b[3]) - float(b[0]), maxf(float(b[4]) - float(b[1]), float(b[5]) - float(b[2])))
		assert_ge(longest, 0.5 - 1e-6, "dressing %s ≥ 0.5 m in its longest side" % id)


func _rig_actions() -> Dictionary:
	var p := "res://data/anim/hush3d/rig_actions.json"
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return (d as Dictionary).get("pranks", {}) if typeof(d) == TYPE_DICTIONARY else {}
