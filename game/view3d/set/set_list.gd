## SetList — tonight's set, derived from content (REDESIGN_3D §3.2 strike rule, R3D index §7.5). Nobody hand-writes a
## Night's set: `for_episode(db, episode)` reads the episode (rooms, backstage, loop, Script, hides, Director cues,
## rules) and the prank / activity / residue / item tables, and `house3d.json`'s per-piece staging dependencies
## (`staged_by`, landing `host`, dressing `nights` / `quake` / `landing` / `with` / `on`, decor `cue` / `station`).
##
## A piece is on stage only if tonight uses it: a station of an activity or detour of the loop (fix-ups after
## residues and overrides included) and the set pieces its `handoffs` borrow; a rig point of one of tonight's
## pranks; a container holding one of their items; a listed hiding spot; a reaction landing's host or a knock-on
## target; a piece `staged_by` one of tonight's pranks; a Director cue prop; a quake prop of a room where a Meltdown
## can happen (not `cant_fail`); the steps named by live rig points' `reach_pos`. Everything else is struck.
##
## Roles of a house.json hotspot in a built room: `live` (the sim's mask), `furniture` (on stage, no glow, no hit
## box), `dormant` (a part of a built piece — the pantry shelves, the piano wedge, the fireplace bellows),
## `architecture` (doors, the window entry, the stairs), `struck` (not instanced). Hotspots of rooms not built are
## `absent`.
class_name SetList
extends RefCounted

const LIVE_KIND_BY_HS := {"rig_point": "rig", "container": "take", "hiding": "hide", "exit": "exit",
	"stairs": "stairs", "door": "door"}


## Tonight's set (read-only after `for_episode`).
class Result:
	extends RefCounted
	var episode_id: String = ""
	## Built and lit (Hush's rooms).
	var rooms_lit: PackedStringArray = PackedStringArray()
	## Built dark (stage light 0.3): architecture + what Bellows uses there.
	var rooms_backstage: PackedStringArray = PackedStringArray()
	## {hotspot_id: "rig" | "take" | "hide" | "door" | "exit" | "stairs"} — the sim's live mask.
	var live: Dictionary = {}
	## Hotspots on stage as furniture (not live): stations, landing hosts, knock-on targets, hand-offs, staging.
	var furniture: PackedStringArray = PackedStringArray()
	## house3d.json `furniture` pieces built tonight (the stool, the phone table).
	var furniture_pieces: PackedStringArray = PackedStringArray()
	var dressing: PackedStringArray = PackedStringArray()
	var decor: PackedStringArray = PackedStringArray()
	## The quake props built (dressing with `quake`, rooms where a Meltdown can happen).
	var quake: PackedStringArray = PackedStringArray()
	## "<room>.<landing>" of tonight's reactions.
	var landings: PackedStringArray = PackedStringArray()
	## Hotspot ids a station of tonight lends to Bellows.
	var handoffs: PackedStringArray = PackedStringArray()
	var dormant: PackedStringArray = PackedStringArray()
	var architecture: PackedStringArray = PackedStringArray()
	## Hotspots of built rooms that are not instanced.
	var struck: PackedStringArray = PackedStringArray()
	## Stations used tonight (loop, detours, fix-ups).
	var stations: PackedStringArray = PackedStringArray()
	## Pranks of tonight (Script lines, Double Acts, `nights`).
	var pranks: PackedStringArray = PackedStringArray()
	## A Meltdown can happen tonight (the room's quake props are built).
	var meltdown: bool = false
	## "sim" when `live` came from `SimCtx.live_hotspots`, "local" when from the local rule.
	var live_source: String = "local"
	var _role: Dictionary = {}
	var _room_of: Dictionary = {}

	## Every built room (lit first, then backstage).
	func rooms_built() -> PackedStringArray:
		var out := rooms_lit.duplicate()
		out.append_array(rooms_backstage)
		return out

	## True when the room is built (lit or backstage).
	func is_room_built(room: String) -> bool:
		return rooms_lit.has(room) or rooms_backstage.has(room)

	## The role of a hotspot: &"live" | &"furniture" | &"dormant" | &"architecture" | &"struck" | &"absent".
	func role(hotspot_id: String) -> StringName:
		return _role.get(hotspot_id, &"absent")

	## True when the hotspot's model is instanced tonight (live, furniture, or a dormant part / architecture).
	func is_built(hotspot_id: String) -> bool:
		var r := role(hotspot_id)
		return r == &"live" or r == &"furniture" or r == &"dormant" or r == &"architecture"

	## The room of a hotspot (from house.json).
	func room_of(hotspot_id: String) -> String:
		return _room_of.get(hotspot_id, "")

	## Ids in a room with a given role (house.json order).
	func ids_in(room: String, r: StringName) -> PackedStringArray:
		var out := PackedStringArray()
		for id in _role.keys():
			if _role[id] == r and _room_of.get(id, "") == room:
				out.append(id)
		return out

	## Live ids of a room, only the ones the density rules count (rig / take / hide).
	func live_props_in(room: String) -> PackedStringArray:
		var out := PackedStringArray()
		for id in live.keys():
			if _room_of.get(id, "") == room and SetGeo.s(live[id]) in ["rig", "take", "hide"]:
				out.append(id)
		return out

	## A plain Dictionary copy (tools, JSON).
	func to_dict() -> Dictionary:
		return {"episode": episode_id, "rooms_lit": Array(rooms_lit), "rooms_backstage": Array(rooms_backstage),
			"live": live.duplicate(), "furniture": Array(furniture), "furniture_pieces": Array(furniture_pieces),
			"dressing": Array(dressing), "decor": Array(decor), "quake": Array(quake), "landings": Array(landings),
			"handoffs": Array(handoffs), "dormant": Array(dormant), "architecture": Array(architecture),
			"struck": Array(struck), "stations": Array(stations), "pranks": Array(pranks), "meltdown": meltdown,
			"live_source": live_source}


## Tonight's set for an episode. `house3d` defaults to res://data/house/house3d.json; `prefer_sim` uses
## `SimCtx.live_hotspots()` for the mask when it exists (the local rule must agree — a test compares them).
static func for_episode(db: ContentDB, episode: EpisodeDef, house3d: Dictionary = {}, prefer_sim: bool = true) -> Result:
	var res := Result.new()
	if db == null or db.house == null or episode == null:
		return res
	var h3 := house3d if not house3d.is_empty() else SetGeo.load_house3d()
	var hs3: Dictionary = h3.get("hotspots", {})
	res.episode_id = episode.id
	for rid in episode.rooms:
		if not episode.backstage.has(rid):
			res.rooms_lit.append(rid)
	for rid in episode.backstage:
		res.rooms_backstage.append(rid)
	res.meltdown = not episode.cant_fail
	# --- tonight's pranks, items, landings, knock-on targets ---
	var pranks := tonight_pranks(db, episode)
	res.pranks = pranks
	var landings := {}
	var knock_targets := {}
	var fix_kinds := {}
	for pid in pranks:
		var p: PrankDef = db.pranks[pid]
		if p.end_room != "" and p.end_landing != "":
			landings["%s.%s" % [p.end_room, p.end_landing]] = true
		if p.knock_prank != "" and db.pranks.has(p.knock_prank):
			var kp: PrankDef = db.pranks[p.knock_prank]
			if kp.rig_point != "":
				knock_targets[kp.rig_point] = true
		for r in p.residue:
			if typeof(r) == TYPE_DICTIONARY:
				var kind := SetGeo.s((r as Dictionary).get("kind", ""))
				if db.residues.has(kind):
					var fk: String = (db.residues[kind] as ResidueDef).fixup
					if fk != "":
						fix_kinds[fk] = true
	for l in landings.keys():
		res.landings.append(l)
	res.landings.sort()
	# --- stations of the loop, detours and fix-ups ---
	var stations := {}
	for le in episode.loop:
		var a: ActivityDef = db.activities.get(le.activity, null)
		if a != null and a.station != "":
			stations[a.station] = true
	var fix_rooms := {}
	for rid in episode.rooms:
		fix_rooms[rid] = true
	for rid in episode.backstage:
		fix_rooms[rid] = true
	for fk in fix_kinds.keys():
		var over: String = SetGeo.s(episode.fixup_overrides.get(fk, ""))
		if over != "" and db.house.station_index.has(over):
			stations[over] = true
			continue
		for st in db.house.stations:
			if st.kinds.has(fk) and fix_rooms.has(st.room):
				stations[st.id] = true
	for sid in stations.keys():
		res.stations.append(sid)
	res.stations.sort()
	# --- the live mask ---
	var live := {}
	if prefer_sim and _sim_has_live():
		live = SimCtx.live_hotspots(db, episode)
		res.live_source = "sim"
	else:
		live = local_live(db, episode, pranks)
	res.live = live
	# --- hand-offs of tonight's stations ---
	var st3: Dictionary = h3.get("stations", {})
	var handoff := {}
	var seat_hs := {}
	for sid in res.stations:
		var sd: Dictionary = st3.get(sid, {})
		for ho in sd.get("handoffs", []):
			var pid := SetGeo.s((ho as Dictionary).get("prop", ""))
			if pid.begins_with("set:"):
				handoff[pid.substr(4)] = true
		var furn := _s(sd.get("furniture", ""))
		if furn.begins_with("hotspot:"):
			seat_hs[furn.substr(8)] = true
	for k in handoff.keys():
		res.handoffs.append(k)
	res.handoffs.sort()
	# --- landing hosts ---
	var land3: Dictionary = h3.get("landings", {})
	var hosts := {}
	for l in res.landings:
		var parts := l.split(".")
		var ld: Dictionary = (land3.get(parts[0], {}) as Dictionary).get(parts[1], {}) if parts.size() == 2 else {}
		var host := SetGeo.s(ld.get("host", ""))
		if host != "":
			hosts[host] = true
	# --- roles of every house.json hotspot in a built room ---
	var built_rooms := {}
	for rid in res.rooms_built():
		built_rooms[rid] = true
	var backstage := {}
	for rid in res.rooms_backstage:
		backstage[rid] = true
	var furniture_hs := {}
	for h in db.house.hotspots:
		if not built_rooms.has(h.room):
			continue
		res._room_of[h.id] = h.room
		var e: Dictionary = hs3.get(h.id, {})
		var on_stage := false
		if h.station != "" and stations.has(h.station):
			on_stage = true
		if hosts.has(h.id) or knock_targets.has(h.id) or handoff.has(h.id) or seat_hs.has(h.id):
			on_stage = true
		for pid in e.get("staged_by", []):
			if pranks.has(String(pid)):
				on_stage = true
		if backstage.has(h.room) and not (h.station != "" and stations.has(h.station)) and not hosts.has(h.id):
			on_stage = false
		if live.has(h.id):
			var lk := SetGeo.s(live[h.id])
			if lk in ["rig", "take", "hide"]:
				res._role[h.id] = &"live"
			else:
				res._role[h.id] = &"architecture"
				res.architecture.append(h.id)
		elif bool(e.get("architecture", false)):
			res._role[h.id] = &"architecture"
			res.architecture.append(h.id)
		elif on_stage:
			res._role[h.id] = &"furniture"
			furniture_hs[h.id] = true
		else:
			res._role[h.id] = &"struck"
	# parts: dormant when their parent is built (hotspot parent or an architecture piece of a built room)
	for h in db.house.hotspots:
		if not built_rooms.has(h.room):
			continue
		var e2: Dictionary = hs3.get(h.id, {})
		var parent := SetGeo.s(e2.get("part_of", ""))
		if parent == "" or res._role.get(h.id, &"struck") == &"live":
			continue
		if parent.begins_with("arch:") or res.is_built(parent):
			if res._role.get(h.id, &"struck") == &"furniture":
				furniture_hs.erase(h.id)
			res._role[h.id] = &"dormant"
	for h in db.house.hotspots:
		if res._role.get(h.id, &"") == &"furniture":
			res.furniture.append(h.id)
		elif res._role.get(h.id, &"") == &"dormant":
			res.dormant.append(h.id)
		elif res._role.get(h.id, &"") == &"struck":
			res.struck.append(h.id)
	# --- furniture pieces (the stool, the phone table) ---
	var steps := {}
	for id in live.keys():
		var rp: Dictionary = (hs3.get(id, {}) as Dictionary).get("reach_pos", {})
		var step := SetGeo.s(rp.get("step", "")) if rp.get("step", null) != null else ""
		if step.begins_with("stool:"):
			steps[step.substr(6)] = true
	var fur3: Dictionary = h3.get("furniture", {})
	for fid in fur3.keys():
		var fd: Dictionary = fur3[fid]
		if not built_rooms.has(SetGeo.s(fd.get("room", ""))):
			continue
		var need := steps.has(fid)
		var fst := SetGeo.s(fd.get("station", ""))
		if fst != "" and stations.has(fst):
			need = true
		for w in fd.get("with", []):
			if res.is_built(String(w)):
				need = true
		for sid in res.stations:
			if _s((st3.get(sid, {}) as Dictionary).get("furniture", "")) == fid:
				need = true
		if need:
			res.furniture_pieces.append(fid)
	res.furniture_pieces.sort()
	# --- dressing (lit rooms only unless it is a landing host) ---
	var dr3: Dictionary = h3.get("dressing", {})
	var built_dressing := {}
	var lit := {}
	for rid in res.rooms_lit:
		lit[rid] = true
	var pass_ids: Array = dr3.keys()
	for _pass in 2:
		for did in pass_ids:
			var dd: Dictionary = dr3[did]
			var room := SetGeo.s(dd.get("room", ""))
			if not built_rooms.has(room) or built_dressing.has(did):
				continue
			var need2 := false
			var nights: Variant = dd.get("nights", null)
			if lit.has(room):
				if typeof(nights) == TYPE_STRING and String(nights) == "all":
					need2 = true
				elif typeof(nights) == TYPE_ARRAY and (nights as Array).has(episode.id):
					need2 = true
				if bool(dd.get("quake", false)) and res.meltdown:
					need2 = true
			var land := SetGeo.s(dd.get("landing", ""))
			if land != "" and res.landings.has(land):
				need2 = true
			for w in dd.get("with", []):
				if built_dressing.has(String(w)):
					need2 = true
			var on := SetGeo.s(dd.get("on", ""))
			if need2 and on != "" and not built_dressing.has(on):
				built_dressing[on] = true
			if need2:
				built_dressing[did] = true
	for did in dr3.keys():
		if built_dressing.has(did):
			res.dressing.append(did)
			if bool((dr3[did] as Dictionary).get("quake", false)) and res.meltdown and lit.has(SetGeo.s((dr3[did] as Dictionary).get("room", ""))):
				res.quake.append(did)
	# --- decor (cue props, station practicals, event pieces of built pieces) ---
	var dc3: Dictionary = h3.get("decor", {})
	var cue_ids := {}
	for cue in ContentUtil.arr(episode.director, "cues"):
		if typeof(cue) == TYPE_DICTIONARY:
			cue_ids[SetGeo.s((cue as Dictionary).get("id", ""))] = true
			var pr := SetGeo.s((cue as Dictionary).get("prop", ""))
			if pr != "":
				cue_ids[pr] = true
	for cid in dc3.keys():
		var cd: Dictionary = dc3[cid]
		if cd.get("model", null) == null and not cd.has("primitive"):
			continue
		var room3 := SetGeo.s(cd.get("room", ""))
		if not built_rooms.has(room3):
			continue
		var need3 := false
		if cd.has("cue") and (cue_ids.has(SetGeo.s(cd["cue"])) or cue_ids.has(cid)):
			need3 = true
		if cd.has("station") and stations.has(SetGeo.s(cd["station"])):
			need3 = true
		if need3:
			res.decor.append(cid)
	for cid in dc3.keys():
		var of := SetGeo.s((dc3[cid] as Dictionary).get("of", ""))
		if of != "" and not res.decor.has(cid) and (res.decor.has(of) or live.has(of)):
			res.decor.append(cid)
	return res


## Tonight's pranks (Script lines — prank, witnessed, chase-trip — Double Acts, and pranks whose `nights` list the
## episode). The sim's knock-on pull-in (a Double Act's B rigged only so the chain can land) is NOT a prank of
## tonight's set: TAP DANCE is not live in the Prologue (REDESIGN §3.4).
static func tonight_pranks(db: ContentDB, episode: EpisodeDef) -> PackedStringArray:
	var ids := {}
	for l in episode.script_lines:
		match l.kind:
			LineDef.K_PRANK, LineDef.K_PRANK_WITNESSED, LineDef.K_CHASE_TRIP:
				if l.prank != "" and db.pranks.has(l.prank):
					ids[l.prank] = true
			LineDef.K_DOUBLE_ACT:
				var da: DoubleActDef = db.double_acts.get(l.double_act, null)
				if da != null:
					if db.pranks.has(da.a):
						ids[da.a] = true
					if da.b != "" and db.pranks.has(da.b):
						ids[da.b] = true
	for p in db.prank_list:
		if p.nights.has(episode.id):
			ids[p.id] = true
	var out := PackedStringArray()
	for p in db.prank_list:
		if ids.has(p.id):
			out.append(p.id)
	return out


## The local live rule (index §7.5, the same rule as `SimCtx.live_hotspots`): rig points of tonight's pranks (and
## their step hotspots), containers of their items, hiding spots in `hides` (absent: all of the Night's rooms),
## doors / exits / stairs that are tappable in a room Hush may enter; never in a backstage room.
static func local_live(db: ContentDB, episode: EpisodeDef, pranks: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out := {}
	if db == null or episode == null:
		return out
	var pl := pranks if not pranks.is_empty() else tonight_pranks(db, episode)
	var rigs := {}
	var conts := {}
	for pid in pl:
		var p: PrankDef = db.pranks[pid]
		if p.rig_point != "":
			rigs[p.rig_point] = true
		for st in p.steps:
			if st.at != "":
				rigs[st.at] = true
			if st.needs != "" and db.items.has(st.needs):
				var src: String = (db.items[st.needs] as ItemDef).source
				if src != "":
					conts[src] = true
	var raw_hides: Variant = episode.raw.get("hides", null)
	var has_hides := typeof(raw_hides) == TYPE_ARRAY
	var hides := {}
	if has_hides:
		for hid in raw_hides:
			hides[String(hid)] = true
	var allowed := {}
	for rid in episode.rooms:
		if not episode.backstage.has(rid):
			allowed[rid] = true
	var ds: Variant = db.house.entries.get("doorstep", null)
	if typeof(ds) == TYPE_DICTIONARY and not episode.backstage.has(SetGeo.s((ds as Dictionary).get("room", ""))):
		allowed[SetGeo.s((ds as Dictionary).get("room", ""))] = true
	for h in db.house.hotspots:
		if not allowed.has(h.room) or not h.tappable:
			continue
		match h.kind:
			HotspotDef.RIG_POINT:
				if rigs.has(h.id):
					out[h.id] = "rig"
			HotspotDef.CONTAINER:
				if conts.has(h.id):
					out[h.id] = "take"
			HotspotDef.HIDING:
				if not has_hides or hides.has(h.id):
					out[h.id] = "hide"
			HotspotDef.EXIT:
				out[h.id] = "exit"
			HotspotDef.STAIRS:
				out[h.id] = "stairs"
			HotspotDef.DOOR:
				out[h.id] = "door"
	return out


## A JSON value as a String ("" for null).
static func _s(v: Variant) -> String:
	return "" if v == null else str(v)


## True when `SimCtx.live_hotspots` exists in this build (r3d-content, C1).
static func _sim_has_live() -> bool:
	for m in (SimCtx as Script).get_script_method_list():
		if SetGeo.s(m.get("name", "")) == "live_hotspots":
			return true
	return false
