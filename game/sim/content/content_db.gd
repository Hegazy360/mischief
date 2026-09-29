## ContentDB — every TECH §4 data file, parsed into typed defs, cross-checked and derived (TECH §3.2).
##
## `load_dir(root)` reads `<root>/house/house.json`, `items.json`, `pranks.json`, `activities.json`,
## `reactions.json`, `residues.json` and `episodes/*.json`; `load_dicts(files)` builds the same from
## in-memory dictionaries (tests). Both fill `errors` (parse + `validate()`) and `warnings`
## (`validate_warnings()`: Stage-3 kinds that load but are not simulated yet).
##
## Derived at load (never stored in JSON): the nav graph, station-kind indices (HouseDef), per-activity
## USE hook lists sorted by mark then prank id, per-station fix-up hook lists, Script bases
## (`LineDef.base_tenths`, largest remainder to exactly 700 per episode) and reaction lengths per tier.
class_name ContentDB
extends RefCounted

const FILES: Array[String] = ["house", "items", "pranks", "activities", "reactions", "residues"]

var root: String = ""
var house: HouseDef = null
var nav: NavGraph = null

var items: Dictionary = {}
var item_list: Array[ItemDef] = []
var activities: Dictionary = {}
var activity_list: Array[ActivityDef] = []
## bit id → {"clip": String, "len": ticks}
var squeak_bits: Dictionary = {}
## Walk beats (`activities.json` root `walk_beats`, optional): during a non-chase walk whose planned
## length exceeds `wb_min_leg` ticks a micro-gag plays every `wb_every` ticks, cycling these ids.
var wb_min_leg: int = 0
var wb_every: int = 0
var wb_ids: PackedStringArray = PackedStringArray()
var wb_len: PackedInt32Array = PackedInt32Array()
var wb_emote: PackedStringArray = PackedStringArray()
var wb_errors: PackedStringArray = PackedStringArray()
## `reactions.json clip_timings`: clip id → frames (last beats and other fixed-length clips the sim times).
var clip_frames: Dictionary = {}
var pranks: Dictionary = {}
var prank_list: Array[PrankDef] = []
var double_acts: Dictionary = {}
var double_act_list: Array[DoubleActDef] = []
## archetype key (e.g. "sneeze_blast_a") → ReactionDef
var reactions: Dictionary = {}
var meltdown_clips: PackedStringArray = PackedStringArray()
var lecture_clips: PackedStringArray = PackedStringArray()
var t3_last_beats: PackedStringArray = PackedStringArray()
var residues: Dictionary = {}
var residue_list: Array[ResidueDef] = []
var combos: Dictionary = {}
var combo_list: Array[ComboDef] = []
var episodes: Dictionary = {}
## Raw parsed JSON per file key (tools and tests).
var raw: Dictionary = {}

## Per station idx: fix-up hook prank idx list (pranks whose rig point sits at that station and whose
## trigger lists fix-up kinds), sorted by prank id.
var fixup_hooks: Array[PackedInt32Array] = []
## Reactions synthesised because reactions.json lacked the key (runtime safety; validate() errors).
var _fallback_rx: Dictionary = {}

var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()


## Load and validate a data directory (default the game's data).
static func load_dir(dir_root: String = "res://data") -> ContentDB:
	var files := {}
	var errs := PackedStringArray()
	var r := dir_root.trim_suffix("/")
	files["house"] = _read_json(r + "/house/house.json", "house.json", errs)
	for k in ["items", "pranks", "activities", "reactions", "residues"]:
		files[k] = _read_json("%s/%s.json" % [r, k], "%s.json" % k, errs)
	var eps := {}
	var ed := DirAccess.open(r + "/episodes")
	if ed == null:
		errs.append("episodes/: missing directory")
	else:
		var names := PackedStringArray()
		ed.list_dir_begin()
		var n := ed.get_next()
		while n != "":
			if not ed.current_is_dir() and n.ends_with(".json"):
				names.append(n)
			n = ed.get_next()
		ed.list_dir_end()
		names.sort()
		for fn in names:
			var ep: Variant = _read_json("%s/episodes/%s" % [r, fn], "episodes/" + fn, errs)
			if typeof(ep) == TYPE_DICTIONARY:
				var eid := ContentUtil.s(ep, "id", fn.get_basename())
				if eid != fn.get_basename():
					errs.append("episodes/%s: id '%s' does not match the file name" % [fn, eid])
				eps[eid] = ep
	files["episodes"] = eps
	var db := load_dicts(files, errs)
	db.root = r
	return db


## Build from dictionaries: {house, items, pranks, activities, reactions, residues: Dictionary,
## episodes: {id: Dictionary} or [Dictionary]}. `pre_errors` carries file-level errors.
static func load_dicts(files: Dictionary, pre_errors: PackedStringArray = PackedStringArray()) -> ContentDB:
	var db := ContentDB.new()
	db.errors.append_array(pre_errors)
	db.raw = files
	db._parse(files)
	db._derive()
	db.errors.append_array(db.validate())
	db.warnings = db.validate_warnings()
	return db


static func _read_json(path: String, label: String, errs: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errs.append("%s: missing (%s)" % [label, path])
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		errs.append("%s: parse error line %d: %s" % [label, j.get_error_line(), j.get_error_message()])
		return null
	if typeof(j.data) != TYPE_DICTIONARY:
		errs.append("%s: top level is not an object" % label)
		return null
	return j.data


func _parse(files: Dictionary) -> void:
	var hd: Variant = files.get("house", null)
	house = HouseDef.from_dict(hd if typeof(hd) == TYPE_DICTIONARY else {}, errors)
	var itd := _obj(files, "items")
	var items_d := ContentUtil.dict(itd, "items")
	for k in ContentUtil.sorted_keys(items_d):
		var v: Variant = items_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var it := ItemDef.from_dict(k, v)
			it.idx = item_list.size()
			item_list.append(it)
			items[k] = it
	var acd := _obj(files, "activities")
	var acts_d := ContentUtil.dict(acd, "activities")
	for k in ContentUtil.sorted_keys(acts_d):
		var v: Variant = acts_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var a := ActivityDef.from_dict(k, v)
			a.idx = activity_list.size()
			activity_list.append(a)
			activities[k] = a
	# detours may live in their own block (activities.json "detours")
	var det_d := ContentUtil.dict(acd, "detours")
	for k in ContentUtil.sorted_keys(det_d):
		var v: Variant = det_d[k]
		if typeof(v) == TYPE_DICTIONARY and not activities.has(k):
			var a := ActivityDef.from_dict(k, v)
			a.is_detour = true
			activities[k] = a
	activity_list.clear()
	for k in ContentUtil.sorted_keys(activities):
		var a2: ActivityDef = activities[k]
		a2.idx = activity_list.size()
		activity_list.append(a2)
	_parse_walk_beats(ContentUtil.dict(acd, "walk_beats"))
	var bits_d := ContentUtil.dict(acd, "squeak_bits")
	for k in ContentUtil.sorted_keys(bits_d):
		var bd: Variant = bits_d[k]
		var bdd: Dictionary = bd if typeof(bd) == TYPE_DICTIONARY else {}
		squeak_bits[k] = {"clip": ContentUtil.s(bdd, "clip"),
			"len": maxi(1, ContentUtil.i(bdd, "len_f", SimConst.BIT_DEFAULT_TICKS))}
	var prd := _obj(files, "pranks")
	var pr_d := ContentUtil.dict(prd, "pranks")
	for k in ContentUtil.sorted_keys(pr_d):
		var v: Variant = pr_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var p := PrankDef.from_dict(k, v)
			p.idx = prank_list.size()
			prank_list.append(p)
			pranks[k] = p
	var da_d := ContentUtil.dict(prd, "double_acts")
	for k in ContentUtil.sorted_keys(da_d):
		var v: Variant = da_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var da := DoubleActDef.from_dict(k, v)
			da.idx = double_act_list.size()
			double_act_list.append(da)
			double_acts[k] = da
	var rxd := _obj(files, "reactions")
	var arch := ContentUtil.dict(rxd, "archetypes")
	for k in ContentUtil.sorted_keys(arch):
		var v: Variant = arch[k]
		if typeof(v) == TYPE_DICTIONARY:
			reactions[k] = ReactionDef.from_dict(k, v)
	meltdown_clips = ContentUtil.strs(rxd, "meltdown")
	lecture_clips = ContentUtil.strs(rxd, "lecture")
	t3_last_beats = ContentUtil.strs(rxd, "t3_last_beats")
	var ct := ContentUtil.dict(rxd, "clip_timings")
	for k in ContentUtil.sorted_keys(ct):
		var cv: Variant = ct[k]
		if typeof(cv) == TYPE_DICTIONARY:
			clip_frames[k] = maxi(0, ContentUtil.i(cv, "frames", 0))
	var rsd := _obj(files, "residues")
	var res_d := ContentUtil.dict(rsd, "residues")
	for k in ContentUtil.sorted_keys(res_d):
		var v: Variant = res_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var r := ResidueDef.from_dict(k, v)
			r.idx = residue_list.size()
			residue_list.append(r)
			residues[k] = r
	var cb_d := ContentUtil.dict(rsd, "combos")
	for k in ContentUtil.sorted_keys(cb_d):
		var v: Variant = cb_d[k]
		if typeof(v) == TYPE_DICTIONARY:
			var c := ComboDef.from_dict(k, v)
			c.idx = combo_list.size()
			combo_list.append(c)
			combos[k] = c
	var eps: Variant = files.get("episodes", {})
	var ep_list: Array = []
	if typeof(eps) == TYPE_DICTIONARY:
		for k in ContentUtil.sorted_keys(eps):
			ep_list.append(eps[k])
	elif typeof(eps) == TYPE_ARRAY:
		ep_list = eps
	for ed in ep_list:
		if typeof(ed) == TYPE_DICTIONARY:
			var e := EpisodeDef.from_dict(ed)
			episodes[e.id] = e


func _parse_walk_beats(wb: Dictionary) -> void:
	if wb.is_empty():
		return
	wb_min_leg = Fx.ticks(ContentUtil.f(wb, "min_leg_s", 5.0))
	wb_every = Fx.ticks(ContentUtil.f(wb, "every_s", 6.0))
	if wb_every <= 0:
		wb_errors.append("walk_beats.every_s must be > 0")
		wb_every = 0
	var i := 0
	for e in ContentUtil.arr(wb, "ids"):
		var g: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {"id": str(e)}
		var gid := ContentUtil.s(g, "id")
		if gid == "":
			wb_errors.append("walk_beats.ids[%d] has no id" % i)
		var em: Variant = g.get("emote", null)
		var em_s := "" if em == null else str(em)
		if em_s != "" and not SimEvents.EMOTES.has(em_s):
			wb_errors.append("walk_beats.ids[%d] (%s) emote '%s' not in %s" % [i, gid, em_s, ", ".join(SimEvents.EMOTES)])
		wb_ids.append(gid)
		wb_len.append(maxi(1, ContentUtil.i(g, "len_f", ActivityDef.MG_LEGACY_LEN_F)))
		wb_emote.append(em_s)
		i += 1


## Frames of a fixed-length clip from `reactions.json clip_timings` (0 when unknown).
func clip_len(clip_id: String) -> int:
	return int(clip_frames.get(clip_id, 0))


func _obj(files: Dictionary, key: String) -> Dictionary:
	var v: Variant = files.get(key, null)
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _derive() -> void:
	nav = NavGraph.build(house)
	for it in item_list:
		it.source_idx = int(house.hotspot_index.get(it.source, -1))
	for a in activity_list:
		a.station_idx = int(house.station_index.get(a.station, -1))
		a.in_use_idx = int(house.hotspot_index.get(a.in_use, -1))
	for p in prank_list:
		p.rig_idx = int(house.hotspot_index.get(p.rig_point, -1))
		p.trig_at_idx = int(house.hotspot_index.get(p.trig_at, -1))
		for st in p.steps:
			st.at_idx = int(house.hotspot_index.get(st.at, -1))
	# USE hooks per activity, sorted by mark then prank id (prank_list is id-sorted).
	var per_act := {}
	for p in prank_list:
		if p.trig_type == PrankDef.TRIG_USE and activities.has(p.trig_activity):
			if not per_act.has(p.trig_activity):
				per_act[p.trig_activity] = []
			(per_act[p.trig_activity] as Array).append([p.trig_mark_ticks, p.idx])
	for aid in per_act:
		var lst: Array = per_act[aid]
		lst.sort_custom(func(x: Array, y: Array) -> bool:
			return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
		var a: ActivityDef = activities[aid]
		a.hooks = PackedInt32Array()
		for e in lst:
			a.hooks.append(int(e[0]))
			a.hooks.append(int(e[1]))
	fixup_hooks.resize(house.stations.size())
	for i in house.stations.size():
		fixup_hooks[i] = PackedInt32Array()
	for p in prank_list:
		if p.trig_fixup_kinds.is_empty() or p.rig_idx < 0:
			continue
		var st_idx := house.hotspots[p.rig_idx].station_idx
		if st_idx >= 0:
			fixup_hooks[st_idx].append(p.idx)
	for e: EpisodeDef in episodes.values():
		for l in e.loop:
			l.act_idx = activity_idx(l.activity)
		normalise_bases(e)


## Script normalisation (GDD §6.1): prank-line bases by size weight, largest remainder to exactly
## SimConst.BASE_TOTAL tenths; ties go to the earlier line.
func normalise_bases(e: EpisodeDef) -> void:
	var lines: Array[LineDef] = []
	var weights: Array[int] = []
	var total_w := 0
	for l in e.script_lines:
		l.base_tenths = 0
		if l.kind == LineDef.K_PRANK and pranks.has(l.prank):
			var p: PrankDef = pranks[l.prank]
			var w := SimConst.weight_for_size(maxi(0, p.size))
			lines.append(l)
			weights.append(w)
			total_w += w
	if lines.is_empty() or total_w <= 0:
		return
	var sum := 0
	var rems: Array = []
	for i in lines.size():
		var num := SimConst.BASE_TOTAL * weights[i]
		var fl := Fx.div(num, total_w)
		lines[i].base_tenths = fl
		sum += fl
		rems.append([num - fl * total_w, i])
	rems.sort_custom(func(x: Array, y: Array) -> bool:
		return x[0] > y[0] if x[0] != y[0] else x[1] < y[1])
	var left := SimConst.BASE_TOTAL - sum
	var j := 0
	while left > 0 and j < rems.size():
		lines[int(rems[j][1])].base_tenths += 1
		left -= 1
		j += 1


## Full validation (schema, id resolution, cross references, derived numbers). Returns error strings.
func validate() -> PackedStringArray:
	return ContentValidate.run(self)


## Stage-3 content that loads but is not simulated yet (panto/witness/herd lines, Beryl/Delphine
## conditions and triggers, headbutt knock-ons).
func validate_warnings() -> PackedStringArray:
	return ContentValidate.warnings(self)


## Reaction def for a prank + variant ("" when the prank has no variants); a fallback def when
## reactions.json lacks the key (validate() reports that as an error).
func reaction_for(p: PrankDef, variant: String) -> ReactionDef:
	var key := p.archetype if variant == "" else "%s_%s" % [p.archetype, variant]
	if reactions.has(key):
		return reactions[key]
	if reactions.has(p.archetype):
		return reactions[p.archetype]
	if not _fallback_rx.has(key):
		_fallback_rx[key] = ReactionDef.make_fallback(key)
	return _fallback_rx[key]


## Activity idx by id (-1 if none).
func activity_idx(act_id: String) -> int:
	var a: ActivityDef = activities.get(act_id, null)
	return a.idx if a != null else -1


## Prank idx by id (-1 if none).
func prank_idx(prank_id: String) -> int:
	var p: PrankDef = pranks.get(prank_id, null)
	return p.idx if p != null else -1


## Item idx by id (-1 if none).
func item_idx(item_id: String) -> int:
	var it: ItemDef = items.get(item_id, null)
	return it.idx if it != null else -1


## Residue idx by kind (-1 if none).
func residue_idx(kind: String) -> int:
	var r: ResidueDef = residues.get(kind, null)
	return r.idx if r != null else -1


## True when there are no errors.
func ok() -> bool:
	return errors.is_empty()
