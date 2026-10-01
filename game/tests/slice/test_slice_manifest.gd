## The 3D slice's static checks (r3d-qa brief §3.2; index §5.1, §5.3, rows 3 and 9): every clip of
## `SliceClips.build3d(["g0_sneeze", "p00_curtain_up"])` has its baked `.res` and its v2 sidecar and matches the
## manifest's length (a loop where the manifest allows one), and every slice Night's sets keep the REDESIGN §3.4 counts
## (live ≤ 5, dressing ≤ 4, one hiding spot per room in Act I) through the set lint's own facts — g0 and the Prologue
## as errors, the N01/N02 previews (hidden in the owner build) checked too.
extends TestBase

const SLICE: PackedStringArray = ["g0_sneeze", "p00_curtain_up"]
const PREVIEWS: PackedStringArray = ["n01_throat_tea", "n02_something_fishy"]
## The R9 scope adds the band fallbacks to the manifest (index §5.3): they must exist like any slice clip.
const BANDS: PackedStringArray = ["hush/rig_high", "hush/rig_mid", "hush/rig_low"]


func _sidecar_path(clip: String) -> String:
	var parts := clip.split("/", true, 1)
	return "res://data/anim/%s3d/%s.json" % [parts[0], parts[1]]


func _res_path(clip: String) -> String:
	var parts := clip.split("/", true, 1)
	return "res://art3d/anim/%s/%s.res" % [parts[0], parts[1]]


func test_the_manifest_is_the_slice_set() -> void:
	var rows := SliceClips.build3d(SLICE)
	# index §5.3 planned 70 (+ freeze_5..8); r3d-integrate A30 / A32 dropped the clips g0 / P00 cannot play (the T3
	# last beats, `oneshot:fizzle`, `bit:bit_livid`) and freeze_5..8 joined: 69 rows on the as-built data
	assert_ge(rows.size(), 69, "build3d(g0, p00) lists the slice set (69 rows as built)")
	var rigs := {}
	for r in rows:
		var c := String(r.get("clip", ""))
		if c.begins_with("#"):
			continue
		rigs[c.get_slice("/", 0)] = int(rigs.get(c.get_slice("/", 0), 0)) + 1
	assert_eq(rigs.keys().size(), 2, "two rigs, no Figgis rows (R7): %s" % str(rigs))
	assert_ge(int(rigs.get("bellows", 0)), 37, "Bellows' slice clips")
	assert_ge(int(rigs.get("hush", 0)), 30, "Hush's slice clips")


func test_every_slice_clip_exists_and_matches_its_length() -> void:
	var rows := SliceClips.build3d(SLICE)
	var clips: Array[String] = []
	var by := {}
	for r in rows:
		var c := String(r.get("clip", ""))
		if c == "" or c.begins_with("#"):
			continue
		clips.append(c)
		by[c] = r
	for b in BANDS:
		if not by.has(b):
			clips.append(b)
			by[b] = {"expect_f": -1, "tol_f": 0, "loop_ok": true, "max_f": 0}
	var checked := 0
	for c in clips:
		var sp := _sidecar_path(c)
		if not assert_true(FileAccess.file_exists(sp), "%s: sidecar %s" % [c, sp]):
			continue
		assert_true(ResourceLoader.exists(_res_path(c)), "%s: baked clip %s" % [c, _res_path(c)])
		var sc: Variant = TestBase.load_json(sp)
		if not assert_true(sc is Dictionary, "%s: the sidecar parses" % c):
			continue
		var d: Dictionary = sc
		var row: Dictionary = by[c]
		var len_f := int(d.get("length", 0))
		var want := int(row.get("expect_f", -1))
		var tol := int(row.get("tol_f", 0))
		var looped := bool(d.get("loop", false))
		assert_gt(len_f, 0, "%s: a clip has frames" % c)
		if want > 0 and not (looped and bool(row.get("loop_ok", false))):
			assert_between(len_f, want - tol, want + tol, "%s: %d f (manifest %d ± %d, why %s)" % [c, len_f, want, tol,
				str(row.get("why", ""))])
		if looped and want > 0:
			assert_true(bool(row.get("loop_ok", false)), "%s: a loop where the manifest wants %d f" % [c, want])
		var mx := int(row.get("max_f", 0))
		if mx > 0:
			assert_le(len_f, mx, "%s: ≤ %d f" % [c, mx])
		checked += 1
	assert_ge(checked, 70, "every clip of the slice manifest checked")


func _set_errors(ep_id: String) -> Array:
	var db := ContentDB.load_dir("res://data")
	var ep: EpisodeDef = db.episodes.get(ep_id, null)
	if ep == null:
		return ["no episode %s" % ep_id]
	var h3 := SetGeo.load_house3d()
	var facts := SetLint3D.facts_for(db, ep, h3, SetList.for_episode(db, ep, h3))
	var out: Array = []
	for i in SetLint3D.check_facts(facts, SetLint3D.mantels(h3)):
		var d: Dictionary = i
		if String(d.get("level", "")) == Lint3D.ERROR:
			out.append("%s %s %s: %s (limit %s)" % [d.get("rule"), d.get("room"), d.get("subject"), d.get("value"), d.get("limit")])
	return out


func _counts(ep_id: String) -> Dictionary:
	var db := ContentDB.load_dir("res://data")
	var ep: EpisodeDef = db.episodes.get(ep_id, null)
	var h3 := SetGeo.load_house3d()
	var facts := SetLint3D.facts_for(db, ep, h3, SetList.for_episode(db, ep, h3))
	var out := {}
	var rooms: Dictionary = facts.get("rooms", {})
	for rid in rooms:
		var rm: Dictionary = rooms[rid]
		var hides := 0
		for l in rm.get("live", []):
			if String((l as Dictionary).get("kind", "")) == "hide":
				hides += 1
		out[rid] = {"live": (rm.get("live", []) as Array).size(), "dressing": (rm.get("dressing", []) as Array).size(),
			"hides": hides, "act": int(facts.get("act", 1))}
	return out


func test_the_slice_nights_keep_the_set_counts() -> void:
	for ep_id in SLICE:
		var c := _counts(ep_id)
		assert_gt(c.size(), 0, "%s: lit rooms" % ep_id)
		for rid in c:
			var r: Dictionary = c[rid]
			assert_le(int(r["live"]), SetLint3D.MAX_LIVE, "%s %s: live props" % [ep_id, rid])
			assert_le(int(r["dressing"]), SetLint3D.MAX_DRESSING, "%s %s: dressing" % [ep_id, rid])
			if int(r["act"]) <= 1:
				assert_le(int(r["hides"]), 1, "%s %s: one hiding spot per room in Act I" % [ep_id, rid])
		assert_eq(_set_errors(ep_id), [], "%s: the set lint's geometry rules" % ep_id)


func test_the_preview_nights_keep_the_set_counts() -> void:
	for ep_id in PREVIEWS:
		var c := _counts(ep_id)
		assert_gt(c.size(), 0, "%s: lit rooms" % ep_id)
		for rid in c:
			var r: Dictionary = c[rid]
			assert_le(int(r["live"]), SetLint3D.MAX_LIVE, "%s %s: live props" % [ep_id, rid])
			assert_le(int(r["dressing"]), SetLint3D.MAX_DRESSING, "%s %s: dressing" % [ep_id, rid])
			if int(r["act"]) <= 1:
				assert_le(int(r["hides"]), 1, "%s %s: one hiding spot per room in Act I" % [ep_id, rid])
		# D13: the N02 hall's negative space is a WARNING (a room at the 5-live-prop cap) — never an error here
		assert_eq(_set_errors(ep_id), [], "%s: the set lint's geometry rules" % ep_id)
