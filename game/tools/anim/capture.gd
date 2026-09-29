## Capture driver (TECH §11, s2-rig §4.1.6) — runs a scene for N frames under Movie Maker and
## logs every RigPlayer clip event with the MOVIE frame it fired on, so the captured WAV / PNG
## frames can be checked against the clip's marks and sfx (tools/anim/gif.py reads the log).
##   godot --write-movie <dir>/f.png --fixed-fps 60 --path <sandbox> -s res://tools/anim/capture.gd \
##         -- --scene=res://scenes/boot/Boot.tscn --frames=2400 --log=<dir>/events.json --e2e --e2e-scenario=g0_sneeze
## (tools/scripts/capture.sh wraps it). The scene becomes the CURRENT scene (so the real game's
## Boot → Router → NightScene scene changes work) with every autoload present; scene user args
## (--rig=, --e2e, …) pass through. The game's own audio lands in the movie's WAV.
## Frame numbering: movie frame k is the k-th rendered frame (f0000000k.png); an event raised
## while frame k is processed is logged with `engine_frame` k.
extends SceneTree

var _frames: int = 180
var _log_path: String = ""
var _n: int = 0
var _log: Array = []
var _hooked: Dictionary = {}
var _scene_changes: Array = []


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
	if packed == null:
		printerr("[capture] %s is not a scene" % scene)
		quit(2)
		return
	change_scene_to_packed.call_deferred(packed)


func _on_node_added(n: Node) -> void:
	if n == current_scene or (n.get_parent() == root and n.scene_file_path != ""):
		_scene_changes.append({"engine_frame": maxi(0, _n - 1), "scene": n.scene_file_path})
	if n is RigPlayer and not _hooked.has(n.get_instance_id()):
		_hooked[n.get_instance_id()] = true
		var rp := n as RigPlayer
		rp.clip_event.connect(func(e: Dictionary) -> void:
			_log.append({"engine_frame": maxi(0, _n - 1), "clip_frame": int(e.get("f", -1)), "clip": String(e.get("clip", "")),
				"type": String(e.get("type", "")), "id": String(e.get("id", e.get("name", e.get("bank", "")))),
				"player": String(rp.name)}))


## Called once per frame BEFORE the nodes process: `_n` = frames begun (the frame being made
## is movie frame `_n − 1`, which is what the log records — measured against the WAV onsets
## of AnimViewer --blips: offset 0 f).
func _process(_delta: float) -> bool:
	if _n >= _frames:
		_finish()
		return true
	_n += 1
	return false


func _finish() -> void:
	if _log_path != "":
		DirAccess.make_dir_recursive_absolute(_log_path.get_base_dir())
		var f := FileAccess.open(_log_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"frames": _frames, "fps": 60, "events": _log, "scenes": _scene_changes}, " "))
		f.close()
		print("[capture] %d events → %s" % [_log.size(), _log_path])
	quit(0)
