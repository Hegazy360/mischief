## Every script and scene s2-night owns loads and compiles (scenes/** except dev/, tools/e2e*).
extends TestBase

const ROOTS: PackedStringArray = ["res://scenes/boot", "res://scenes/night", "res://scenes/results", "res://scenes/debug",
	"res://scenes/stage_door", "res://scenes/playbill"]


func _scripts(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_scripts(dir + "/" + sub, out)


func test_every_script_compiles() -> void:
	var files := PackedStringArray()
	for r in ROOTS:
		_scripts(r, files)
	assert_gt(files.size(), 10, "found the night scripts")
	for f in files:
		var res: Resource = load(f)
		assert_true(res != null, "%s loads" % f)
		if res is GDScript:
			assert_true((res as GDScript).can_instantiate(), "%s compiles" % f)


func test_e2e_driver_compiles() -> void:
	if not ResourceLoader.exists("res://tools/e2e.gd"):
		skip("e2e.gd not written yet")
		return
	var s := load("res://tools/e2e.gd") as GDScript
	assert_true(s != null and s.can_instantiate(), "tools/e2e.gd compiles")
