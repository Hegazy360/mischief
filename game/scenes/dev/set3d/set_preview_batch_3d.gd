## SetPreviewBatch3D — many SetPreview3D shots in one Godot run (one import, one window): the review boards of
## r3d-sets render ~100 frames, and a fresh sandbox + import per shot costs ~35 s each.
##
##   tools/scripts/shot.sh res://scenes/dev/set3d/SetPreviewBatch3D.tscn /abs/last.png 100000 r3d-sets -- \
##     --jobs=/abs/jobs.json
##
## jobs.json = [{"out": "/abs/a.png", "frames": 30, "args": ["--episode=p00_curtain_up", "--room=kitchen", …]}, …]
## Each job instantiates SetPreview3D with `preset_args` = its args, waits `frames` frames, saves the viewport as PNG
## and frees it. The window size is the batch's (SHOT_SIZE). After the last job the batch copies its image to the
## `--shot` path (DevShot's) and quits.
extends Node

const PREVIEW := "res://scenes/dev/set3d/SetPreview3D.tscn"

var _jobs: Array = []
var _shot := ""


func _ready() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jobs="):
			path = a.substr(7)
		elif a.begins_with("--shot="):
			_shot = a.substr(7)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if typeof(parsed) != TYPE_ARRAY:
		printerr("[SetPreviewBatch3D] no jobs (--jobs=/abs.json with a list)")
		get_tree().quit(2)
		return
	_jobs = parsed
	_run.call_deferred()


func _run() -> void:
	var ps := load(PREVIEW) as PackedScene
	var last: Image = null
	var n := 0
	for job in _jobs:
		var jd: Dictionary = job
		var args := PackedStringArray()
		for x in jd.get("args", []):
			args.append(String(x))
		var node := ps.instantiate()
		node.set("preset_args", args)
		add_child(node)
		var frames := int(jd.get("frames", 30))
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var out := String(jd.get("out", ""))
		if out != "" and img != null:
			DirAccess.make_dir_recursive_absolute(out.get_base_dir())
			img.save_png(out)
			print("[SetPreviewBatch3D] saved %s" % out)
			n += 1
		last = img
		remove_child(node)
		node.queue_free()
		await get_tree().process_frame
	if _shot != "" and last != null:
		last.save_png(_shot)
	print("[SetPreviewBatch3D] %d / %d shots" % [n, _jobs.size()])
	get_tree().quit(0)
