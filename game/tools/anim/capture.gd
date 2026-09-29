## Capture driver (TECH §11) — runs a scene for N frames and logs every RigPlayer clip event
## with the engine frame it fired on, so a Movie Maker capture's WAV / PNG frames can be
## checked against the clip's marks and sfx (tools/anim/gif.py reads the log).
##   godot --write-movie <dir>/f.png --fixed-fps 60 --path <sandbox> -s res://tools/anim/capture.gd \
##         -- --scene=res://scenes/dev/AnimViewer.tscn --frames=180 --log=<dir>/events.json [scene args]
## (tools/scripts/capture.sh wraps it). Scene user args (e.g. --rig= --clip=) pass through.
extends SceneTree

var _frames: int = 180
var _log_path: String = ""
var _n: int = 0
var _log: Array = []
var _hooked: Dictionary = {}


func _initialize() -> void:
	var scene := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
		elif a.begins_with("--frames="):
			_frames = maxi(1, int(a.substr(9)))
		elif a.begins_with("--log="):
			_log_path = a.substr(6)
	if scene == "" or not ResourceLoader.exists(scene):
		printerr("[capture] --scene=res://… missing or not found: '%s'" % scene)
		quit(2)
		return
	node_added.connect(_on_node_added)
	var packed := load(scene) as PackedScene
	root.add_child.call_deferred(packed.instantiate())


func _on_node_added(n: Node) -> void:
	if n is RigPlayer and not _hooked.has(n.get_instance_id()):
		_hooked[n.get_instance_id()] = true
		var rp := n as RigPlayer
		rp.clip_event.connect(func(e: Dictionary) -> void:
			_log.append({"engine_frame": _n, "clip_frame": int(e.get("f", -1)), "clip": String(e.get("clip", "")),
				"type": String(e.get("type", "")), "id": String(e.get("id", e.get("name", e.get("bank", "")))),
				"player": String(rp.name)}))


func _process(_delta: float) -> bool:
	_n += 1
	if _n >= _frames:
		_finish()
		return true
	return false


func _finish() -> void:
	if _log_path != "":
		DirAccess.make_dir_recursive_absolute(_log_path.get_base_dir())
		var f := FileAccess.open(_log_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"frames": _frames, "fps": 60, "events": _log}, " "))
		f.close()
		print("[capture] %d events → %s" % [_log.size(), _log_path])
	quit(0)
