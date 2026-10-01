## NightWarm — the per-Night warm list (s2-night §4.2) and the warmer that works through it under
## the curtain / cold open / loading card, spread over frames (≤ 2.0 s).
##
## `NightWarm.list(episode_id, data_root)` is pure (reads only the JSON data) and returns:
## `{episode, rigs: ["hush", "bellows"], rooms: [...], props: [hotspot ids], looks: {"bellows": [...],
##   "hush": [...]}, combos: [...], fx: [...], captions: [...], fonts: [{font, size}], audio: [ids], pip: true}`
## * rooms = the Night's rooms + backstage; props = every hotspot in them (their atlases are built with
##   the WorldView, the list is the record TexStats checks);
## * looks = every residue look the Night's pranks can leave (`KIND`, `KIND:<look>`) and the 3D descriptors' looks
##   (rig3d.json: BLINDED, TOMATO, CARRY_*), plus `COMBO:<id>` for each combo whose two residues can both happen
##   **and** that `rules.combos` allows (`[]` = none, absent = all), plus `COSTUME:<look>`;
## * fx = the particle kinds the Night can emit (the pool's kinds + the curtain call's roses);
## * fonts = captions 88 px, stamps 64 px, HUD numbers 48 px (display / ui faces), each glyph set drawn
##   once off-screen;
## * audio = the cue ids of the Night's pranks and archetypes (`cues.json`);
## * hud_icons = {targets, items}: the action button's RIG icons for tonight's pranks — each rig point's icon (its
##   `art.icon` / `art.idle`) and every step's `needs` item — rasterised by UiIcons under the curtain (D17: the
##   first rig point she reaches rasterised them in Hud.apply, ~2 ms, at the same tick every run).
## `NightWarmer` (a Node) executes it in 3D: the materials / instanced meshes / clips of the Night's tree (hidden
## looks included), the font primer, `PipView3D` (soft), `Audio.warm(ids)` — one step per frame under an 8 ms
## budget; `done` when finished.
class_name NightWarm
extends RefCounted

const FX_KINDS: PackedStringArray = ["dust", "flour", "feathers", "drops", "steam", "sparkles", "notes", "roses"]
const FONT_SIZES := [{"font": "display", "size": 88}, {"font": "display", "size": 64}, {"font": "ui", "size": 48}]
const STAMP_TEXTS: PackedStringArray = ["MELTDOWN! +8", "COMBO! +4", "NEAR MISS! +2", "EMBARRASSED! +5", "RUNNING GAG ×1.5",
	"×2", "×3", "ENCORE!", "0123456789+-×!?.,'"]


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data


## The warm list for one episode (see the class doc). {} when the episode file is missing.
static func list(episode_id: String, data_root: String = "res://data") -> Dictionary:
	var ep: Variant = _read("%s/episodes/%s.json" % [data_root, episode_id])
	if not (ep is Dictionary):
		return {}
	var e: Dictionary = ep
	var pj: Variant = _read("%s/pranks.json" % data_root)
	var pranks: Dictionary = (pj as Dictionary).get("pranks", {}) if pj is Dictionary else {}
	var das: Dictionary = (pj as Dictionary).get("double_acts", {}) if pj is Dictionary else {}
	var rj: Variant = _read("%s/residues.json" % data_root)
	var combos: Dictionary = (rj as Dictionary).get("combos", {}) if rj is Dictionary else {}
	var hj: Variant = _read("%s/house/house.json" % data_root)
	var rooms := PackedStringArray()
	for r in e.get("rooms", []):
		rooms.append(String(r))
	for r in e.get("backstage", []):
		if not rooms.has(String(r)):
			rooms.append(String(r))
	var props := PackedStringArray()
	if hj is Dictionary:
		for hs in (hj as Dictionary).get("hotspots", []):
			if hs is Dictionary and rooms.has(String((hs as Dictionary).get("room", ""))):
				props.append(String((hs as Dictionary).get("id", "")))
	props.sort()
	# The Night's pranks: prank lines + both halves of double acts (+ knock-on targets).
	var night_pranks := PackedStringArray()
	for l in e.get("script", []):
		if not (l is Dictionary):
			continue
		var ld: Dictionary = l
		if ld.get("prank") != null and String(ld.get("prank", "")) != "":
			_add(night_pranks, String(ld["prank"]))
		if ld.get("double_act") != null and das.get(String(ld.get("double_act", "")), null) is Dictionary:
			var da: Dictionary = das[String(ld["double_act"])]
			for k in ["a", "b"]:
				if da.get(k) != null:
					_add(night_pranks, String(da[k]))
	for pid in night_pranks.duplicate():
		var pd: Variant = pranks.get(pid, null)
		if pd is Dictionary and (pd as Dictionary).get("knock_on") is Dictionary:
			var ko: Variant = ((pd as Dictionary)["knock_on"] as Dictionary).get("prank", null)
			if ko != null and night_pranks.has(String(ko)):
				_add(night_pranks, String(ko))
	night_pranks.sort()
	var kinds := PackedStringArray()
	var looks := PackedStringArray()
	var captions := PackedStringArray()
	var archetypes := PackedStringArray()
	for pid in night_pranks:
		var pd: Variant = pranks.get(pid, null)
		if not (pd is Dictionary):
			continue
		var p: Dictionary = pd
		if p.get("caption") != null:
			_add(captions, String(p["caption"]))
		var rx: Variant = p.get("reaction", null)
		if rx is Dictionary and (rx as Dictionary).get("archetype") != null:
			_add(archetypes, String((rx as Dictionary)["archetype"]))
		for res in p.get("residue", []):
			if not (res is Dictionary):
				continue
			var rd: Dictionary = res
			var k := String(rd.get("kind", ""))
			if k == "":
				continue
			_add(kinds, k)
			_add(looks, k)
			if rd.get("look") != null and String(rd["look"]) != "":
				_add(looks, "%s:%s" % [k, String(rd["look"])])
			if bool(rd.get("blind", false)):
				_add(looks, "%s:blind" % k)
			if k == "COSTUME" and rd.get("look") != null:
				_add(looks, "COSTUME:%s" % String(rd["look"]))
	# Every basic residue look too: landings and knock-ons leave residues no prank lists (the sneeze
	# into the sink SOAKs him), and a missed page would be built on the CHOO.
	var rdefs: Dictionary = (rj as Dictionary).get("residues", {}) if rj is Dictionary else {}
	for k in rdefs:
		var ks := String(k)
		if ks != "COSTUME" and not ks.begins_with("COSTUME"):
			_add(kinds, ks)
			_add(looks, ks)
	# Combos: both residues possible tonight AND allowed by rules.combos (absent = all, [] = none).
	var rules: Dictionary = e.get("rules", {}) if e.get("rules") is Dictionary else {}
	var allowed: Variant = rules.get("combos", null)
	var combo_ids := PackedStringArray()
	for cid in combos:
		var cd: Variant = combos[cid]
		if not (cd is Dictionary):
			continue
		var of: Array = (cd as Dictionary).get("of", [])
		var ok := of.size() >= 2
		for k in of:
			if not kinds.has(String(k)):
				ok = false
		if ok and allowed is Array and not (allowed as Array).has(cid):
			ok = false
		if ok:
			_add(combo_ids, String(cid))
			_add(looks, "COMBO:%s" % String(cid))
			if (cd as Dictionary).get("caption") != null:
				_add(captions, String((cd as Dictionary)["caption"]))
	combo_ids.sort()
	looks.sort()
	# Audio: the cue ids of tonight's pranks and archetypes.
	var audio := PackedStringArray()
	var cj: Variant = _read("%s/audio/cues.json" % data_root)
	if cj is Dictionary:
		for pid in night_pranks:
			_collect_ids(((cj as Dictionary).get("pranks", {}) as Dictionary).get(pid, null), audio)
		for a in archetypes:
			_collect_ids(((cj as Dictionary).get("archetypes", {}) as Dictionary).get(a, null), audio)
	audio.sort()
	var all_captions := captions.duplicate()
	all_captions.append_array(STAMP_TEXTS)
	var hud_icons := hud_icons_for(night_pranks, pranks, hj)
	# The title card (+ bulbs) only for the Night whose curtain call slams it (the Prologue): 72 MB
	# at 2× on every other Night otherwise (s2-fix G #7).
	var textures := lazy_textures(data_root, CurtainCall.kind_for(episode_id, "") == CurtainCall.KIND_PROLOGUE)
	# Per rig: every look its 3D descriptor (rigs3d/<rig>/rig3d.json `looks`, R3D) defines that tonight can show —
	# basic residues, BLINDED, the carries, the Night's costumes, the combos `rules.combos` allows (a rig look the
	# rules forbid is not warmed: it must not appear, TECH L4). (The 2D rig.json pages went with the 2D view.)
	var costumes := PackedStringArray()
	for k in looks:
		if String(k).begins_with("COSTUME:"):
			costumes.append(String(k))
	var rig_looks := {}
	for rig in ["bellows", "hush"]:
		var rl := PackedStringArray()
		var rjd: Variant = _read("%s/rigs3d/%s/rig3d.json" % [data_root, rig])
		var rres: Dictionary = (rjd as Dictionary).get("looks", {}) if rjd is Dictionary else {}
		for k in rres:
			var ks := String(k)
			if ks.begins_with("COMBO:"):
				if combo_ids.has(ks.substr(6)):
					_add(rl, ks)
			elif ks.begins_with("COSTUME"):
				if costumes.has(ks):
					_add(rl, ks)
			else:
				_add(rl, ks)
		if rig == "bellows":
			for k in looks:
				_add(rl, String(k))
		rl.sort()
		rig_looks[rig] = rl
	return {"episode": episode_id, "rigs": PackedStringArray(["hush", "bellows"]), "rooms": rooms, "props": props,
		"pranks": night_pranks, "looks": rig_looks, "combos": combo_ids,
		"fx": FX_KINDS.duplicate(), "captions": all_captions, "fonts": FONT_SIZES.duplicate(true), "audio": audio,
		"textures": textures, "pip": true, "hud_icons": hud_icons}


## The action button's RIG icons for `night_pranks` (see the class doc): {targets: [icon paths / activity ids],
## items: [item ids]}, sorted, no duplicates.
static func hud_icons_for(night_pranks: PackedStringArray, pranks: Dictionary, house: Variant) -> Dictionary:
	var by_id := {}
	if house is Dictionary:
		for hs in (house as Dictionary).get("hotspots", []):
			if hs is Dictionary:
				by_id[String((hs as Dictionary).get("id", ""))] = hs
	var targets := PackedStringArray()
	var items := PackedStringArray()
	for pid in night_pranks:
		var pd: Variant = pranks.get(pid, null)
		if not (pd is Dictionary):
			continue
		var rp := String((pd as Dictionary).get("rig_point", "")) if (pd as Dictionary).get("rig_point") != null else ""
		var hd: Variant = by_id.get(rp, null)
		if hd is Dictionary and (hd as Dictionary).get("art") is Dictionary:
			var art: Dictionary = (hd as Dictionary)["art"]
			var icon := String(art.get("icon", art.get("idle", "")))
			if icon != "":
				_add(targets, icon)
		for st in (pd as Dictionary).get("steps", []):
			if st is Dictionary and (st as Dictionary).get("needs") != null and String((st as Dictionary)["needs"]) != "":
				_add(items, String((st as Dictionary)["needs"]))
	targets.sort()
	items.sort()
	return {"targets": targets, "items": items}


## Textures the view loads lazily (HiResTex rasters through ViewKit.tex): the awareness glyphs and
## badges, every activity / detour icon the thought bubble can show (+ exit), the falling / quake
## props and the particle sprites. Rasterised under the curtain so none is built on a gag.
## `with_title`: the Prologue's title card and its bulb layers (CurtainApron draws them through
## ViewKit.tex). The valance is drawn from its imported 1× texture, so it is never warmed here.
static func lazy_textures(data_root: String = "res://data", with_title: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	for g in ["specs_off", "specs_on", "blinded", "asleep", "stars"]:
		_add_if(out, "res://art/ui/glyph_%s.svg" % g)
	for b in ["badge_gold", "badge_hide", "badge_in_use", "badge_needs"]:
		_add_if(out, "res://art/ui/%s.svg" % b)
	var aj: Variant = _read("%s/activities.json" % data_root)
	var acts: Dictionary = (aj as Dictionary).get("activities", {}) if aj is Dictionary else {}
	for id in acts:
		var ad: Variant = acts[id]
		var icon := String((ad as Dictionary).get("icon", "")) if ad is Dictionary and (ad as Dictionary).get("icon") != null else ""
		_add_if(out, icon if icon != "" else "res://art/icons/activities/%s.svg" % String(id))
	_add_if(out, "res://art/icons/activities/exit.svg")
	# the curtain call's art (the title card slams after the Prologue)
	if with_title:
		for f in ["title_card.svg", "title_card_bulbs_a.svg", "title_card_bulbs_b.svg"]:
			_add_if(out, "res://art/house/stage/" + f)
	for d in ["res://art/icons/activities", "res://art/house/props", "res://art/fx/props", "res://art/fx/particles"]:
		var files := DirAccess.get_files_at(d) if DirAccess.dir_exists_absolute(d) else PackedStringArray()
		for f in files:
			if not f.ends_with(".svg"):
				continue
			if d == "res://art/house/props" and not f.contains("falling"):
				continue
			_add_if(out, d.path_join(f))
	out.sort()
	return out


static func _add_if(arr: PackedStringArray, path: String) -> void:
	if path != "" and not arr.has(path) and (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
		arr.append(path)


static func _add(arr: PackedStringArray, v: String) -> void:
	if v != "" and not arr.has(v):
		arr.append(v)


## Every `sfx` / `voice` / `sting` / `crowd` string value inside a cues.json entry.
static func _collect_ids(v: Variant, out: PackedStringArray) -> void:
	if v is Dictionary:
		for k in v:
			var x: Variant = (v as Dictionary)[k]
			if (k == "sfx" or k == "voice" or k == "sting") and x is String:
				_add(out, String(x))
			else:
				_collect_ids(x, out)
	elif v is Array:
		for x in v:
			_collect_ids(x, out)
