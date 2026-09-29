## RigPerf — N characters on an empty stage for draw-call / frame-time measurement
## (TECH §9: ≤ 12 draw calls and ≤ 0.25 ms CPU per character). Nothing else is drawn, so
## DevShot's draw-call count is the characters' alone:
##   tools/scripts/shot.sh res://scenes/dev/RigPerf.tscn out.png 240 rig -- --n=2 --perf-log=60
## User args: --rig=_mannequin --n=2 --clips=loco_walk,rx_take (cycled per character)
## Also prints `[rigperf] advance+draw ms per character` averaged over the run.
extends Node2D

var players: Array[RigPlayer] = []
var _t_us: int = 0
var _frames: int = 0


func _ready() -> void:
	var rig_id := "_mannequin"
	var n := 2
	var clips := PackedStringArray(["loco_walk", "rx_take"])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--n="):
			n = maxi(1, int(a.substr(4)))
		elif a.begins_with("--clips="):
			clips = a.substr(8).split(",", false)
	RenderingServer.set_default_clear_color(Color("#2A2342"))
	var vs := get_viewport_rect().size
	for i in n:
		var p := RigPlayer.new()
		p.manual = true
		p.position = Vector2(vs.x * float(i + 1) / float(n + 1), vs.y * 0.8)
		add_child(p)
		p.setup(rig_id)
		var cid := clips[i % clips.size()]
		p.play(cid if cid.contains("/") else rig_id + "/" + cid, {"speed": 180.0})
		p.clip_finished.connect(func(id: String) -> void: p.play(id, {"blend_in": 0}))
		players.append(p)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	for p in players:
		p.advance(delta)
	_t_us += Time.get_ticks_usec() - t0
	_frames += 1
	if _frames % 120 == 0:
		print("[rigperf] %d characters: advance %.3f ms + _draw %.3f ms per character per frame" % [
			players.size(), float(_t_us) / float(_frames) / 1000.0 / float(players.size()),
			float(RigPlayer.draw_us) / float(maxi(1, RigPlayer.draw_count)) / 1000.0])
