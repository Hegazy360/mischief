## Every script under res://view (except the rig task's rig/ and tex/) parses and compiles,
## and every default clip map is valid JSON.
extends TestBase

const SKIP: PackedStringArray = ["res://view/rig", "res://view/tex"]


func test_all_view_scripts_compile() -> void:
	var paths := _scripts("res://view")
	assert_gt(paths.size(), 20, "found the view scripts")
	for p in paths:
		var s := load(p) as GDScript
		assert_true(s != null and s.can_instantiate(), "compiles: %s" % p)


func test_default_maps_parse() -> void:
	for rig in ["hush", "bellows", "_mannequin"]:
		var m: Variant = TestBase.load_json("res://view/world/default_maps/%s.json" % rig)
		assert_true(m is Dictionary, "%s map parses" % rig)
		if m is Dictionary:
			assert_eq(int((m as Dictionary).get("version", 0)), 1)
			assert_has(m, "idle")


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for s in SKIP:
		if dir.begins_with(s):
			return out
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir, f])
	for sub in d.get_directories():
		out.append_array(_scripts("%s/%s" % [dir, sub]))
	return out
