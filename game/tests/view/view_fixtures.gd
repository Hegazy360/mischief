## Test helper (not a test): installs the s2-view static-pose fixture clips
## (`tests/view/fixtures/anim/<rig>/*.json`, generated from the real Bellows / Hush poses) into
## ClipLib's cache and ClipMap's registry, and the fixture `map.json` files as the rigs' maps,
## so the one-shot table, overlays, frame locks and fallbacks are testable before the animation
## tasks deliver real clips. `uninstall()` puts everything back (the real clips win again).
extends RefCounted

const ROOT := "res://tests/view/fixtures/anim"
const RIGS: PackedStringArray = ["bellows", "hush"]

static var _installed: PackedStringArray = PackedStringArray()


## Load every fixture clip (+ the fixture maps unless `maps` is false). Returns the ids.
static func install(maps: bool = true) -> PackedStringArray:
	uninstall()
	for rig in RIGS:
		var dir := "%s/%s" % [ROOT, rig]
		var d := DirAccess.open(dir)
		if d == null:
			continue
		var files := d.get_files()
		files.sort()
		for f in files:
			if not f.ends_with(".json"):
				continue
			var path := "%s/%s" % [dir, f]
			if f == "map.json":
				if maps:
					var j := JSON.new()
					if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
						ClipMap.map_override[rig] = j.data
				continue
			var id := "%s/%s" % [rig, f.get_basename()]
			var c := ClipLib.load_file(path, id)
			if c == null:
				continue
			_register(id, c)
			ClipMap.fixture_clips[id] = c.length
			_installed.append(id)
	ClipMap.clear_cache()
	return _installed


## Forget the fixtures (clips, maps, caches).
static func uninstall() -> void:
	for id in _installed:
		ClipLib.invalidate(id)
	_installed.clear()
	ClipMap.fixture_clips.clear()
	ClipMap.map_override.clear()
	ClipMap.clear_cache()


static func _register(id: String, c: ClipDef) -> void:
	# ClipLib (owner rig) caches by id; tests seed that cache so RigPlayer.play(id) finds them.
	ClipLib._cache[id] = c
