## The sim is pure: no Nodes, no engine time, no randf, no float state (TECH §3.9).
extends TestBase

const ROOT := "res://sim"
const BANNED: Array[String] = ["extends Node", "Time.", "randf", "randi(", "RandomNumberGenerator", "get_tree(",
	"OS.get_ticks", "await ", "Engine.", "get_node("]


func _files(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_files(p, out)
		elif n.ends_with(".gd"):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()


func test_no_nodes_time_or_random() -> void:
	var files := PackedStringArray()
	_files(ROOT, files)
	assert_gt(files.size(), 30)
	var bad := []
	for f in files:
		var lines := FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			var l := lines[i]
			var code := l.split("#")[0] if not l.strip_edges().begins_with("##") else ""
			for b in BANNED:
				if code.contains(b):
					bad.append("%s:%d %s" % [f.get_file(), i + 1, b])
	assert_eq(bad, [])


func test_no_float_state() -> void:
	var files := PackedStringArray()
	_files(ROOT, files)
	var re := RegEx.new()
	re.compile("^(static )?var \\w+\\s*(:\\s*float|:=\\s*-?\\d+\\.\\d+)")
	var bad := []
	for f in files:
		var lines := FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			if re.search(lines[i].strip_edges()) != null:
				bad.append("%s:%d" % [f.get_file(), i + 1])
	# EpisodeDef.spot_fill_s is content (load-time data, converted to ticks in SimCtx)
	bad.erase("episode_def.gd:%d" % _line_of("res://sim/content/defs/episode_def.gd", "var spot_fill_s"))
	assert_eq(bad, [])


func _line_of(path: String, needle: String) -> int:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		if lines[i].contains(needle):
			return i + 1
	return -1


func test_every_system_is_refcounted() -> void:
	for cls in [SimWorld, SimHush, SimBellows, Routine, Senses, Temper, Pranks, Reactions, Residue, Scoring,
			ScriptGoals, Bits, Chase, Director, Conditions, NavGraph, NavPath, ContentDB]:
		var inst: Object = cls.new()
		assert_true(inst is RefCounted)
