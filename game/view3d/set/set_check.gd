## SetCheck — the reach and collision checks of a Night's set (R3D index R5; brief r3d-sets §4.6, §5). Pure over
## ContentDB + SetList + house3d.json + a built House3D (for the solids), so SetPreview3D `--check` and the tests run
## the same code headless.
##
## Reach: for every live rig point, the distance from Hush's nearer shoulder at `reach_pos` (SetGeo.reach_info) to its
## placed reach target ≤ 0.50 m — an ERROR on the Prologue / Gate 0, a WARNING on N01 / N02; the target's band equals
## `rig_actions.json` when that file lists the prank; a target above 1.70 m needs a step; a `stool:<id>` step names a
## built furniture piece with `seat_y_m`, a `mime` step is 0.30–0.45 m.
## Collisions (ERROR on every slice Night): Hush's capsule at every live `reach_pos` and along the lane (z −1.0, every
## 0.1 m of every lit room), Bellows' barrel at every station of tonight's loop — against the built-ins, flats,
## furniture and props (Hush's step and Bellows' own seat excepted; a 5 mm tolerance).
class_name SetCheck
extends RefCounted

const STRICT_EPISODES: Array[String] = ["p00_curtain_up", "g0_sneeze"]
const RIG_ACTIONS := "res://data/anim/hush3d/rig_actions.json"
const TOL := 0.005
const LANE_STEP_M := 0.1


## Runs every check for a built house. Returns {episode, reach: [...], collisions: [...], errors: [...], warnings: [...]}.
static func run(house: House3D) -> Dictionary:
	var out := {"episode": "", "reach": [], "collisions": [], "errors": [], "warnings": []}
	if house == null or house.result == null or house.db == null:
		(out["errors"] as Array).append("no built house")
		return out
	var res := house.result
	var db := house.db
	var h3 := house.house3d
	var cfg := SetGeo.reach_cfg(h3)
	var hs3: Dictionary = h3.get("hotspots", {})
	var strict := STRICT_EPISODES.has(res.episode_id)
	out["episode"] = res.episode_id
	var bands := _rig_bands()
	var solids := house.collision_solids()
	var fur3: Dictionary = h3.get("furniture", {})
	# --- reach, per live rig point ---
	for id in res.live.keys():
		if SetGeo.s(res.live[id]) != "rig":
			continue
		var h := db.house.hotspot(id)
		var e: Dictionary = hs3.get(id, {})
		if h == null:
			continue
		if e.is_empty() or not e.has("reach_target"):
			_add(out, strict, "reach: %s has no house3d.json reach_target" % id)
			continue
		var info := SetGeo.reach_info(h.rect, e, float(h.use_sub) / 12000.0, cfg)
		var row := {"hotspot": id, "band": info["band"], "target": _v(info["target"]), "shoulder": _v(info["shoulder"]),
			"dist": snappedf(float(info["dist"]), 0.001), "ok": info["ok"], "step": info["step"], "step_h": info["step_h"],
			"level": "error" if strict else "warning"}
		(out["reach"] as Array).append(row)
		if not bool(info["ok"]):
			_add(out, strict, "reach: %s %.3f m > %.2f m (band %s)" % [id, float(info["dist"]), float(cfg.get("max_m", 0.5)), info["band"]])
		if SetGeo.s(info["band"]) == "":
			_add(out, strict, "reach: %s target y %.2f is outside every band" % [id, (info["target"] as Vector3).y])
		if SetGeo.s(e.get("reach", "")) != SetGeo.s(info["band"]):
			_add(out, strict, "reach: %s house3d.json reach '%s' != placed band '%s'" % [id, e.get("reach", ""), info["band"]])
		for pid in bands.keys():
			var b: Dictionary = bands[pid]
			if SetGeo.s(b.get("hotspot", "")) == id and b.has("band") and SetGeo.s(b["band"]) != SetGeo.s(info["band"]):
				_add(out, strict, "reach: %s rig_actions.json band '%s' (%s) != placed band '%s'" % [id, b["band"], pid, info["band"]])
		var step: Variant = info["step"]
		if bool(info["needs_step"]) and (step == null or String(step) == ""):
			_add(out, strict, "reach: %s target at %.2f m (> 1.70) needs a step" % [id, (info["target"] as Vector3).y])
		if step != null and String(step).begins_with("stool:"):
			var fid := String(step).substr(6)
			if not res.furniture_pieces.has(fid) or not (fur3.get(fid, {}) as Dictionary).has("seat_y_m"):
				_add(out, true, "reach: %s step '%s' is not a built furniture piece with seat_y_m" % [id, step])
			elif absf(float((fur3[fid] as Dictionary)["seat_y_m"]) - float(info["step_h"])) > 0.001:
				_add(out, true, "reach: %s step_h %.2f != %s seat_y_m" % [id, info["step_h"], fid])
		elif step != null and String(step) == "mime":
			if float(info["step_h"]) < 0.3 - 1e-6 or float(info["step_h"]) > 0.45 + 1e-6:
				_add(out, true, "reach: %s mime step_h %.2f outside 0.30–0.45" % [id, info["step_h"]])
		elif step != null and String(step) != "":
			_add(out, true, "reach: %s unknown step '%s'" % [id, step])
		# her capsule at reach_pos (the step furniture excepted)
		var stand: Vector3 = info["stand"]
		var cap := SetGeo.hush_capsule(stand.x, stand.z, float(info["step_h"]), cfg)
		var skip := String(step).substr(6) if step != null and String(step).begins_with("stool:") else ""
		_collide(out, cap, "hush@%s" % id, solids, [skip])
	# --- Hush along the lane ---
	for rid in res.rooms_lit:
		var r := db.house.room(rid)
		if r == null or r.floor != 0:
			continue
		var x := float(r.x0) / SetGeo.PX_PER_M + 0.2
		var x_end := float(r.x1) / SetGeo.PX_PER_M - 0.2
		while x <= x_end + 1e-6:
			_collide(out, SetGeo.hush_capsule(x, -1.0, 0.0, cfg), "hush@lane:%.1f" % x, solids, [])
			x += LANE_STEP_M
	# --- Bellows at tonight's stations ---
	var st3: Dictionary = h3.get("stations", {})
	var seats: Array = []
	for sid2 in st3.keys():
		var f2 := SetGeo.s((st3[sid2] as Dictionary).get("furniture", ""))
		if f2 != "":
			seats.append(f2.substr(8) if f2.begins_with("hotspot:") else f2)
	for sid in res.stations:
		var st := db.house.station(sid)
		if st == null or not res.is_room_built(st.room):
			continue
		var sd: Dictionary = st3.get(sid, {})
		var bz := float(sd.get("bellows_z", -1.4))
		var seat := SetGeo.s(sd.get("furniture", ""))
		if seat.begins_with("hotspot:"):
			seat = seat.substr(8)
		var lift := maxf(0.0, float(sd.get("seat_y_m", 0.45)) - 0.45) if sd.has("seat_y_m") else 0.0
		var bcap := SetGeo.bellows_capsule(float(st.stand_sub) / 12000.0, bz, lift, cfg)
		var skip_b: Array = seats.duplicate()
		skip_b.append(seat)
		for ho in sd.get("handoffs", []):
			var hp := SetGeo.s((ho as Dictionary).get("prop", ""))
			skip_b.append(hp.substr(4) if hp.begins_with("set:") else hp)
		_collide(out, bcap, "bellows@%s" % sid, solids, skip_b)
	return out


static func _collide(out: Dictionary, cap: Dictionary, who: String, solids: Array[Dictionary], skip: Array) -> void:
	for s in solids:
		var sid := SetGeo.s(s["id"])
		if skip.has(sid):
			continue
		var depth := SetGeo.capsule_obb_depth(cap, s["obb"])
		if depth > TOL:
			(out["collisions"] as Array).append({"who": who, "solid": sid, "kind": s["kind"], "depth": snappedf(depth, 0.001),
				"x": snappedf(float(cap["x"]), 0.01), "z": snappedf(float(cap["z"]), 0.01)})
			(out["errors"] as Array).append("collision: %s hits %s (%s) by %.3f m" % [who, sid, s["kind"], depth])


static func _add(out: Dictionary, as_error: bool, msg: String) -> void:
	var arr: Array = out["errors"] if as_error else out["warnings"]
	arr.append(msg)


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


## rig_actions.json pranks (r3d-content) — {} when the file has not landed.
static func _rig_bands() -> Dictionary:
	if not FileAccess.file_exists(RIG_ACTIONS):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIG_ACTIONS))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return (d as Dictionary).get("pranks", {})
