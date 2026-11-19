## AnimViewer — the animators' bench (TECH §5.3 / §11, s2-rig §4.1.5): pick a rig and a clip
## (or a pose), play / pause / step / scrub, tier 1–3, suppressed, facing flip, residue
## looks, tint, and watch the clip with an emulated camera punch, shake and hit-stop (so a
## take feels like it will in game) — in the REAL room (`--room`), on the Pip skin, with a
## micro-gag overlay over a base loop, and with a second rig (the HOT & COLD hand-off, the
## Lecture dangle), and with limb goals (`--goal`: 2-bone IK reaching for a crosshair, which can
## sweep and toggle so a capture shows tracking and the blend in / out). JSON (rigs, poses,
## faces, clips, reactions) and the rigs' SVGs hot-reload by mtime every 0.5 s. `--help` prints
## every flag.
##
## Screenshot: tools/scripts/shot.sh res://scenes/dev/AnimViewer.tscn out.png 60 <sb> -- --rig=bellows --clip=rx_sneeze_blast_a --room=kitchen
## GIF:        CAPTURE_SANDBOX=<sb> tools/scripts/capture.sh res://scenes/dev/AnimViewer.tscn 180 out.gif -- --rig=bellows --clip=<base> --overlay=<mg> --sound
## Reach:      tools/scripts/shot.sh res://scenes/dev/AnimViewer.tscn out.png 30 <sb> -- --rig=hush --clip=loco_idle --goal=arm_r:70,-250
extends Node2D

const USAGE := """AnimViewer — user args (after `--`):
  --rig=<id>               rig to load (default _mannequin)
  --clip=<clip>            clip: a name (rx_take), an id (bellows/rx_take) or a file (res://…/x.json)
  --pose=<pose>            show a pose instead of a clip
  --skin=<skin>            texture skin (hush: pip)
  --looks=K1,K2            residue looks on (SOAKED, FRAZZLED:blind, COSTUME:jelly_helmet, COMBO:dough_man…);
                           --residue= is the same
  --tint=<tier>            temper tint tier (0..3)
  --prop=<id>:<state>[,…]  prop states on rig 1 (specs:on, clarence:smitten, stool:hidden…)
  --part-tex=<part>:<variant>[,…]  persistent part textures (bouffant:flipped — the BLINDED hair)
  --tier=1..3 --suppressed  reaction tier remap / suppressed settle
  --frame=N --paused       start at frame N / paused
  --facing=-1              face left
  --speed=<px/s>           walk speed for stride_px clips
  --overlay=<clip>         an overlay clip (micro-gag) over the base loop; replays every time it ends
  --overlay-at=<f>         frames after the base starts before the overlay starts (default 12)
  --overlay-gap=<f>        frames between overlay replays (default 30)
  --room=<room id>         the real house.json room behind the rig, at game scale (kitchen, parlour…)
  --x=<world px>           the rig's world x in the room (default: the room centre)
  --station=<station id>   stand the rig at a station's stand_x, facing its facing (st_tea…)
  --rig2=<id> --clip2=<clip> --x2=<px>   a second rig, x2 px to the right of the first (default 260)
  --facing2=±1 --skin2=<skin> --looks2=K1,K2 --pose2=<pose>
  --attach2=<part:socket>[,<part:socket>]  pin rig 2 so its socket (default: its root) sits on rig 1's
                           socket every frame (the Lecture dangle: hand_r:grip,braces_loop:grab)
  --zoom=<z>               camera zoom (1.0 = the game's framing)
  --goal=<limb>:<x>,<y>[;…] limb goals on rig 1 (2-bone IK, RigPlayer.set_goal): the limb's grip
                           reaches a point x px IN FRONT of the feet (follows --facing) and y px
                           down from the floor (negative = up). arm_r:70,-250 = a high shelf.
  --goal-stretch=<f>       rubber-hose stretch allowed past the arm's length (default 1 = rigid)
  --goal-blend=<f>         frames to blend a goal in / out (default 8)
  --goal-follow=<1/s>      target smoothing (0 = exact, the default)
  --goal-sweep=<f>[:<r>]   the target circles its point every f frames, radius r px (default 40)
  --goal-cycle=<f>         goals on for f frames, then released for f frames, repeating
  --hotspot=<id>           stand rig 1 at a house.json hotspot (its room, use_x and facing) and give
                           clips with a `reach` block its `grab` point (kitchen_kettle, hall_confiscated_box…)
  --no-reach               with --hotspot: play the clip as authored (before / after comparisons)
  --once                   no auto-replay
  --clean                  character + set only (mute GIFs, cast sheets)
  --sound                  play clip sfx / voice / laugh events through the game's Audio
  --blips                  a short beep per sfx / voice event (sync onsets without Audio)
  --no-juice               no camera punch / shake
  --help                   this text
Hot reload: edit the JSON / SVGs while it runs (every 0.5 s)."""

## Flags other tools pass through the same command line (DevShot, capture): not unknown.
const PASSTHROUGH: PackedStringArray = ["--shot=", "--frames=", "--shot-seq=", "--every=", "--count=", "--perf-log",
	"--scene=", "--log=", "--e2e"]

const BG_TOP := Color("#2A2342")
const BG_BOT := Color("#4B3F6B")
const FLOOR := Color("#C98B55")
const FLOOR_DARK := Color("#A96C3C")
const INK := Color("#1B2340")
const PANEL := Color(0.08, 0.07, 0.13, 0.82)
const TEXT := Color("#F4EFE3")
const DIM := Color("#B9B2CF")
const KEY_COL := Color("#FF5A6B")
const HOLD_COL := Color("#5B8CFF")
const OV_COL := Color("#F2B33D")
const FONT_SIZE := 30
const REPLAY_PAUSE_F := 45.0
## Room mode: the floor sits at this fraction of the logical height (the game's framing:
## 190 px of the floor above, 640 interior, 60 slab, 190 below).
const ROOM_FLOOR_FRAC := 830.0 / 1080.0
const LAUGH_KINDS := {"titter": "t0", "chuckle": "t1", "laugh": "t2", "big": "t3", "roar": "t4", "auto": "t2"}

var cfg: Dictionary = {}
var rig_id: String = "_mannequin"
var clip_id: String = ""
var pose_name: String = ""
var tier: int = 1
var suppressed: bool = false
var facing: int = 1
var clean: bool = false
var once: bool = false
var blips: bool = false
var sound: bool = false
var juice: bool = true
var walk_speed: float = -1.0

var player: RigPlayer
var player2: RigPlayer = null
var clip2_id: String = ""
var overlay_id: String = ""
var backdrop: Node2D = null
var backdrop_front: Node2D = null
var _cam: Camera2D
var _stage: Node2D
var _painter: _Painter
var _ui: CanvasLayer
var _root_ui: Control
var _title: Label
var _info: Label
var _ticker: Label
var _status: Label
var _info_bg: ColorRect
var _timeline: _Timeline
var _rig_opt: OptionButton
var _clip_opt: OptionButton
var _pose_opt: OptionButton
var _play_btn: Button
var _tier_btns: Array[Button] = []
var _sup_btn: Button
var _res_btns: Array[Button] = []
var _paused: bool = false
var _hold_left: float = -1.0
var _ticker_lines: PackedStringArray = PackedStringArray()
var _mtimes: Dictionary = {}
var _reload_t: float = 0.0
var _zoom_seq: Array = []      ## [in_f, hold_f, out_f, zoom, t]
var _trauma: float = 0.0
var _shake_t: float = 0.0
var _blip_player: AudioStreamPlayer
var _blip_cache: Dictionary = {}
var _rig_x: float = 0.0
var _vf: float = 0.0           ## viewer frames since the clip (re)started (overlay schedule)
var _ov_next: float = -1.0     ## viewer frame of the next overlay start (-1 = none pending)
var _files: Dictionary = {}    ## clip id → source file for clips loaded from res:// paths
## --goal: per goal [limb, offset (x in front of the feet, y down)]; the goal clock (frames).
var _goal_specs: Array = []
var _goal_t: float = 0.0
var _goal_live: bool = false
## --hotspot: the grab point (world; INF = none) fed to clip reach blocks as target "grab".
var _grab: Vector2 = Vector2.INF


## Parse the viewer's user args (pure; tests call it). Unknown flags land in `unknown`.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var o := {"rig": "_mannequin", "clip": "", "pose": "", "skin": "", "looks": PackedStringArray(), "tint": 0,
		"tier": 1, "suppressed": false, "frame": 0, "paused": false, "facing": 1, "speed": -1.0,
		"overlay": "", "overlay_at": 12, "overlay_gap": 30, "room": "", "x": NAN, "station": "",
		"rig2": "", "clip2": "", "pose2": "", "x2": 260.0, "facing2": -1, "skin2": "", "looks2": PackedStringArray(),
		"attach2": PackedStringArray(), "zoom": 1.0, "once": false, "clean": false, "sound": false, "blips": false,
		"juice": true, "help": false, "props": PackedStringArray(), "part_tex": PackedStringArray(),
		"goals": PackedStringArray(), "goal_stretch": 1.0, "goal_blend": 8.0, "goal_follow": 0.0,
		"goal_sweep": 0.0, "goal_sweep_r": 40.0, "goal_cycle": 0.0, "hotspot": "", "reach": true,
		"unknown": PackedStringArray()}
	for a in args:
		var k := a
		var v := ""
		if a.begins_with("--") and a.contains("="):
			k = a.get_slice("=", 0)
			v = a.substr(k.length() + 1)
		match k:
			"--rig":
				o["rig"] = v
			"--clip":
				o["clip"] = v
			"--pose":
				o["pose"] = v
			"--skin":
				o["skin"] = v
			"--looks", "--residue":
				var l: PackedStringArray = o["looks"]
				l.append_array(v.split(",", false))
				o["looks"] = l
			"--tint":
				o["tint"] = clampi(int(v), 0, 9)
			"--prop":
				var pl: PackedStringArray = o["props"]
				pl.append_array(v.split(",", false))
				o["props"] = pl
			"--part-tex":
				var tl: PackedStringArray = o["part_tex"]
				tl.append_array(v.split(",", false))
				o["part_tex"] = tl
			"--tier":
				o["tier"] = clampi(int(v), 1, 3)
			"--suppressed":
				o["suppressed"] = true
			"--frame":
				o["frame"] = maxi(0, int(v))
			"--paused":
				o["paused"] = true
			"--facing":
				o["facing"] = -1 if int(v) < 0 else 1
			"--speed":
				o["speed"] = float(v)
			"--overlay":
				o["overlay"] = v
			"--overlay-at":
				o["overlay_at"] = maxi(0, int(v))
			"--overlay-gap":
				o["overlay_gap"] = maxi(0, int(v))
			"--room":
				o["room"] = v
			"--x":
				o["x"] = float(v)
			"--station":
				o["station"] = v
			"--rig2":
				o["rig2"] = v
			"--clip2":
				o["clip2"] = v
			"--pose2":
				o["pose2"] = v
			"--x2":
				o["x2"] = float(v)
			"--facing2":
				o["facing2"] = -1 if int(v) < 0 else 1
			"--skin2":
				o["skin2"] = v
			"--looks2":
				o["looks2"] = v.split(",", false)
			"--attach2":
				o["attach2"] = v.split(",", false)
			"--zoom":
				o["zoom"] = clampf(float(v), 0.2, 4.0)
			"--goal":
				var gl: PackedStringArray = o["goals"]
				gl.append_array(v.split(";", false))
				o["goals"] = gl
			"--goal-stretch":
				o["goal_stretch"] = maxf(1.0, float(v))
			"--goal-blend":
				o["goal_blend"] = maxf(0.0, float(v))
			"--goal-follow":
				o["goal_follow"] = maxf(0.0, float(v))
			"--goal-sweep":
				o["goal_sweep"] = maxf(0.0, float(v.get_slice(":", 0)))
				if v.contains(":"):
					o["goal_sweep_r"] = absf(float(v.get_slice(":", 1)))
			"--goal-cycle":
				o["goal_cycle"] = maxf(0.0, float(v))
			"--hotspot":
				o["hotspot"] = v
			"--no-reach":
				o["reach"] = false
			"--once":
				o["once"] = true
			"--clean":
				o["clean"] = true
			"--sound":
				o["sound"] = true
			"--blips":
				o["blips"] = true
			"--no-juice":
				o["juice"] = false
			"--help", "-h":
				o["help"] = true
			"--":
				pass
			_:
				var known := false
				for pre in PASSTHROUGH:
					if a.begins_with(pre):
						known = true
				if not known:
					var u: PackedStringArray = o["unknown"]
					u.append(a)
					o["unknown"] = u
	return o


## Resolve a clip argument for `rig`: "name" → "rig/name"; a res:// / user:// file is loaded
## and registered under its `clip` id (returned); "" when it cannot be found.
static func resolve_clip(arg: String, rig: String) -> String:
	if arg == "":
		return ""
	if arg.ends_with(".json") and (arg.begins_with("res://") or arg.begins_with("user://") or arg.begins_with("/")):
		var c := ClipLib.register_file(arg)
		return c.id if c != null else ""
	return arg if arg.contains("/") else rig + "/" + arg


## resolve_clip + remember file-loaded clips for the hot reload.
func _resolve(arg: String, rig: String) -> String:
	if _files.has(arg):
		ClipLib.register_file(String(_files[arg]))
		return arg
	var cid := resolve_clip(arg, rig)
	if cid != "" and arg.ends_with(".json"):
		_files[cid] = arg
	return cid


func _ready() -> void:
	cfg = parse_args(OS.get_cmdline_user_args())
	if bool(cfg["help"]):
		print(USAGE)
		get_tree().quit()
		return
	for u in cfg["unknown"]:
		push_warning("AnimViewer: unknown flag %s (see --help)" % u)
	rig_id = String(cfg["rig"])
	clip_id = String(cfg["clip"])
	pose_name = String(cfg["pose"])
	tier = int(cfg["tier"])
	suppressed = bool(cfg["suppressed"])
	facing = int(cfg["facing"])
	clean = bool(cfg["clean"])
	once = bool(cfg["once"])
	blips = bool(cfg["blips"])
	sound = bool(cfg["sound"])
	juice = bool(cfg["juice"])
	_paused = bool(cfg["paused"])
	walk_speed = float(cfg["speed"])
	_goal_specs = parse_goals(cfg["goals"])
	_apply_hotspot_arg()
	RenderingServer.set_default_clear_color(BG_TOP)
	_painter = _Painter.new()
	_painter.viewer = self
	add_child(_painter)
	if String(cfg["room"]) != "":
		var rb: Script = load("res://scenes/dev/room_backdrop.gd")
		backdrop = rb.new()
		backdrop_front = rb.new()
		if backdrop.call("setup", String(cfg["room"]), false) and backdrop_front.call("setup", String(cfg["room"]), true):
			add_child(backdrop)
		else:
			backdrop.free()
			backdrop_front.free()
			backdrop = null
			backdrop_front = null
	var shadows := _Shadows.new()
	shadows.viewer = self
	add_child(shadows)
	_stage = Node2D.new()
	add_child(_stage)
	if backdrop_front != null:
		add_child(backdrop_front)
	if (not _goal_specs.is_empty() or _grab != Vector2.INF) and not clean:
		var gm := _GoalMarker.new()
		gm.viewer = self
		add_child(gm)
	player = _new_player()
	player.clip_finished.connect(_on_finished)
	if String(cfg["rig2"]) != "":
		player2 = _new_player()
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_blip_player = AudioStreamPlayer.new()
	_blip_player.name = "Blips"
	add_child(_blip_player)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_load_rig(rig_id)
	_layout()
	_update_camera(0.0)   # frame 0 (a capture's first PNG) already framed


func _new_player() -> RigPlayer:
	var p := RigPlayer.new()
	p.self_hitstop = true
	p.manual = true
	_stage.add_child(p)
	p.clip_event.connect(_on_event)
	return p


# --- loading -------------------------------------------------------------------------------

func _load_rig(id: String) -> void:
	rig_id = id
	player.setup(id, String(cfg.get("skin", "")))
	if player.rig == null:
		_set_status("rig '%s' not found" % id)
		return
	player.set_facing(facing, false)
	for kind in cfg.get("looks", PackedStringArray()):
		player.set_residue(String(kind), true)
	player.set_tint_tier(int(cfg.get("tint", 0)))
	_apply_prop_args()
	if player2 != null:
		player2.setup(String(cfg["rig2"]), String(cfg["skin2"]))
		player2.set_facing(int(cfg["facing2"]), false)
		for k2 in cfg["looks2"]:
			player2.set_residue(String(k2), true)
		clip2_id = _resolve(String(cfg["clip2"]), String(cfg["rig2"]))
	overlay_id = _resolve(String(cfg["overlay"]), id)
	_place_rigs()
	_fill_rig_menu()
	_fill_clip_menu()
	_fill_residues()
	_snapshot_mtimes()
	if pose_name != "" and player.poses.has_pose(pose_name):
		_show_pose(pose_name)
		return
	var cid := _resolve(clip_id, id)
	if cid == "":
		var list := ClipLib.list(id)
		cid = list[0] if not list.is_empty() else ""
		for c in list:
			if c.ends_with("/loco_idle"):
				cid = c
	if cid != "":
		_play(cid, int(cfg.get("frame", 0)))


## --prop=id:state and --part-tex=part:variant on rig 1 (re-applied after every replay).
func _apply_prop_args() -> void:
	for ps in cfg.get("props", PackedStringArray()):
		var kv := String(ps).split(":")
		if kv.size() == 2:
			player.set_prop_state(kv[0], kv[1])
	for pt in cfg.get("part_tex", PackedStringArray()):
		var kv2 := String(pt).split(":")
		if kv2.size() == 2:
			player.set_part_texture(kv2[0], kv2[1])


## World x of rig 1 (room mode: --x / --station / the room centre) and rig 2 beside it.
func _place_rigs() -> void:
	_rig_x = 0.0
	if backdrop != null:
		_rig_x = backdrop.call("centre_x")
		var st := String(cfg["station"])
		if st != "":
			var sx: float = backdrop.call("station_x", st)
			if not is_nan(sx):
				_rig_x = sx
				if not _has_arg("--facing="):
					facing = backdrop.call("station_facing", st)
					player.set_facing(facing, false)
		if not is_nan(float(cfg["x"])):
			_rig_x = float(cfg["x"])
	player.position = Vector2(_rig_x, 0)
	if player2 != null:
		player2.position = Vector2(_rig_x + float(cfg["x2"]), 0)


func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return true
	return false


func _play(cid: String, start: int = 0) -> void:
	clip_id = cid
	pose_name = ""
	_hold_left = -1.0
	var opts := {"tier": tier, "suppressed": suppressed, "blend_in": 0, "seed": 1}
	if walk_speed > 0.0:
		opts["speed"] = walk_speed
	for p in _players():
		p.props.reset()
		p.springs.reset()
		p.reset_layers()
	player.play(cid, opts)
	_apply_prop_args()
	if player2 != null:
		if clip2_id != "":
			player2.play(clip2_id, {"blend_in": 0, "seed": 1, "speed": walk_speed} if walk_speed > 0.0 else {"blend_in": 0, "seed": 1})
		elif String(cfg["pose2"]) != "" and player2.poses != null and player2.poses.has_pose(String(cfg["pose2"])):
			player2.set_static_pose(player2.poses.pose(String(cfg["pose2"])))
	_vf = 0.0
	_ov_next = float(cfg.get("overlay_at", 12)) if overlay_id != "" else -1.0
	_replay_frames(0)
	_replay_frames(start)
	for p2 in _players():
		p2.paused = _paused
	_zoom_seq.clear()
	_trauma = 0.0
	_ticker_lines = PackedStringArray()
	_update_info()
	_select_clip_item(cid)
	_snapshot_mtimes()


func _players() -> Array[RigPlayer]:
	var out: Array[RigPlayer] = [player]
	if player2 != null:
		out.append(player2)
	return out


func _show_pose(pn: String) -> void:
	pose_name = pn
	player.set_static_pose(player.poses.pose(pn))
	if player2 != null and String(cfg["pose2"]) != "" and player2.poses.has_pose(String(cfg["pose2"])):
		player2.set_static_pose(player2.poses.pose(String(cfg["pose2"])))
	_tick(0.0)
	_update_info()


## Seek to timeline frame `f` by replaying deterministically from 0 (springs, props, smears
## and the overlay schedule end up exactly as in a straight playthrough).
func seek(f: float) -> void:
	if clip_id == "" or pose_name != "":
		return
	var was := _paused
	_paused = false
	_play(clip_id, 0)
	_replay_frames(int(clampf(f, 0.0, float(player.clip_length()))))
	_set_paused(was)


## Advance `n` frames with the self-hitstop off, so frame N of a seek is frame N of the clip
## (a hitstop would otherwise freeze the replay and land a few frames short).
func _replay_frames(n: int) -> void:
	for p in _players():
		p.self_hitstop = false
		p.paused = false
	if n == 0:
		_tick(0.0)
	for i in n:
		_tick(1.0 / 60.0)
	for p2 in _players():
		p2.self_hitstop = true


## One viewer step: the overlay schedule, both players, rig 2's attachment.
func _tick(dt: float) -> void:
	if not _paused:
		_vf += dt * 60.0
	if overlay_id != "" and _ov_next >= 0.0 and _vf >= _ov_next and not _paused:
		player.play(overlay_id, {"layer": "overlay"})
		_ov_next = -1.0
	_drive_goals(dt)
	if _grab != Vector2.INF and player.rig != null and bool(cfg["reach"]):
		player.set_target("grab", _grab)
	player.advance(dt)
	if player2 != null:
		player2.advance(dt)
		_attach2()


func _attach2() -> void:
	var at: PackedStringArray = cfg.get("attach2", PackedStringArray())
	if at.is_empty() or player.rig == null or player2.rig == null:
		return
	var target := player.socket_global_transform(at[0]).origin
	var own := player2.global_position
	if at.size() >= 2:
		own = player2.socket_global_transform(at[1]).origin
	player2.global_position += target - own


## --hotspot=<id>: the room, x and facing of a house.json hotspot (explicit --room / --x / --facing
## still win), and its grab point for that facing (`grab` / `grab_l`) for clip reach blocks.
func _apply_hotspot_arg() -> void:
	var hid := String(cfg["hotspot"])
	if hid == "":
		return
	var rb: Script = load("res://scenes/dev/room_backdrop.gd")
	var house: Dictionary = rb.call("load_house")
	for hv in house.get("hotspots", []):
		var hd: Dictionary = hv
		if String(hd.get("id", "")) != hid:
			continue
		if String(cfg["room"]) == "":
			cfg["room"] = String(hd.get("room", ""))
		var at_station := String(cfg["station"]) != ""
		if is_nan(float(cfg["x"])) and not at_station:
			cfg["x"] = float(hd.get("use_x", 0))
		if not _has_arg("--facing=") and not at_station:
			facing = -1 if int(hd.get("facing", 1)) < 0 else 1
		var g: Variant = hd.get("grab_l" if facing < 0 and hd.has("grab_l") else "grab", null)
		if String(cfg["rig"]) != "hush" and hd.has("grab") and hd.has("grab_l"):
			# Other rigs stand beside the prop (stations): the prop's centre, as CharacterView does.
			var gr: Array = hd["grab"]
			var gl: Array = hd["grab_l"]
			g = [(float(gr[0]) + float(gl[0])) * 0.5, (float(gr[1]) + float(gl[1])) * 0.5]
		if g is Array and (g as Array).size() >= 2:
			_grab = Vector2(float(g[0]), float(g[1]))
		else:
			push_warning("AnimViewer: hotspot %s has no grab point" % hid)
		return
	push_warning("AnimViewer: hotspot '%s' is not in house.json" % hid)


## --goal specs → [[limb, Vector2 offset], …] (pure; tests call it). Bad entries are skipped
## with a warning.
static func parse_goals(specs: PackedStringArray) -> Array:
	var out: Array = []
	for sp in specs:
		var limb := sp.get_slice(":", 0)
		var xy := sp.substr(limb.length() + 1).split(",", false)
		if limb == "" or xy.size() != 2 or not xy[0].is_valid_float() or not xy[1].is_valid_float():
			push_warning("AnimViewer: --goal entry '%s' is not <limb>:<x>,<y>" % sp)
			continue
		out.append([limb, Vector2(float(xy[0]), float(xy[1]))])
	return out


## The world point goal `i` reaches for this frame (the sweep circles it).
func goal_point(i: int) -> Vector2:
	var off: Vector2 = _goal_specs[i][1]
	var pt := Vector2(player.global_position.x + off.x * float(player.facing()), off.y)
	var per := float(cfg["goal_sweep"])
	if per > 0.0:
		var a := TAU * _goal_t / per
		pt += Vector2(cos(a), sin(a)) * float(cfg["goal_sweep_r"])
	return pt


## Set / move / release rig 1's goals for this frame (--goal, --goal-sweep, --goal-cycle).
func _drive_goals(dt: float) -> void:
	if _goal_specs.is_empty() or player.rig == null:
		return
	if not _paused:
		_goal_t += dt * 60.0
	var cyc := float(cfg["goal_cycle"])
	var on := cyc <= 0.0 or int(floor(_goal_t / cyc)) % 2 == 0
	for i in _goal_specs.size():
		var limb: String = _goal_specs[i][0]
		if not on:
			player.clear_goal(limb, float(cfg["goal_blend"]))
			continue
		if _goal_live and player.has_goal(limb):
			player.move_goal(limb, goal_point(i))
		elif not player.set_goal(limb, goal_point(i), {"stretch": float(cfg["goal_stretch"]),
				"blend_f": float(cfg["goal_blend"]), "follow": float(cfg["goal_follow"])}):
			if Engine.get_process_frames() % 120 == 0:
				push_warning("AnimViewer: rig %s has no 2-bone limb '%s' (has %s)" % [rig_id, limb, player.goal_limbs()])
	_goal_live = on


# --- per frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_reload_t += delta
	if _reload_t >= 0.5:
		_reload_t = 0.0
		_check_reload()
	if _hold_left >= 0.0 and not _paused:
		_hold_left -= delta * 60.0
		if _hold_left < 0.0 and clip_id != "":
			_play(clip_id, 0)
	_tick(delta)
	_update_camera(delta)
	if _timeline != null:
		_timeline.queue_redraw()
	if _info != null and Engine.get_process_frames() % 4 == 0:
		_update_info()


## Camera rest centre: room mode = the game's framing (floor at 830 / 1080) on the rig; plain
## mode = the rig's feet at 34 % × 72 % of the view (centred with --clean).
func _rest_centre() -> Vector2:
	var vs := get_viewport_rect().size
	var z := float(cfg.get("zoom", 1.0))
	var fx := 0.5 if clean else 0.34
	var fy := ROOM_FLOOR_FRAC if backdrop != null else (0.84 if clean else 0.72)
	var c := Vector2(_rig_x, 0.0) + Vector2((0.5 - fx) * vs.x, (0.5 - fy) * vs.y) / z
	# Zoomed in (close-ups, cast shots): slide toward the character's middle so the head stays
	# in frame (a 380 px Bellows at 2× is taller than the space above the floor).
	if z > 1.0 and player != null and player.rig != null:
		c.y = lerpf(c.y, -player.rig.height_px * 0.5, clampf((z - 1.0) / 0.8, 0.0, 1.0))
	return c


func _update_camera(delta: float) -> void:
	var base := _rest_centre()
	var z0 := float(cfg.get("zoom", 1.0))
	var zoom := 1.0
	if juice and not _zoom_seq.is_empty():
		var zs: Array = _zoom_seq
		zs[4] = float(zs[4]) + delta * 60.0 * player.time_scale * (0.05 if player._hitstop_f > 0.0 else 1.0)
		var t: float = zs[4]
		var zin: float = zs[0]
		var zh: float = zs[1]
		var zo: float = zs[2]
		var target: float = zs[3]
		if t < zin:
			zoom = lerpf(1.0, target, RigEase.apply(RigEase.id("out_cubic"), t / maxf(1.0, zin)))
		elif t < zin + zh:
			zoom = target
		elif t < zin + zh + zo:
			zoom = lerpf(target, 1.0, RigEase.apply(RigEase.id("in_out_sine"), (t - zin - zh) / maxf(1.0, zo)))
		else:
			_zoom_seq.clear()
	var head := player.part_global_position("head") if player.rig != null else base
	var focus := base.lerp(head, clampf((zoom - 1.0) * 2.0, 0.0, 1.0))
	var off := Vector2.ZERO
	if juice and _trauma > 0.0:
		_shake_t += delta
		var s := 12.0 * _trauma * _trauma
		off = Vector2(sin(_shake_t * 157.0) * s, cos(_shake_t * 131.0) * s)
		_trauma = maxf(0.0, _trauma - 1.5 * delta)
	_cam.position = focus + off
	_cam.zoom = Vector2(zoom * z0, zoom * z0)


func _on_event(e: Dictionary) -> void:
	var t := String(e.get("type", ""))
	var label := _event_label(e)
	var who := String(e.get("clip", "")).get_file()
	_ticker_lines.append("f%-4d %s  · %s" % [int(e.get("f", 0)), label, who])
	while _ticker_lines.size() > 9:
		_ticker_lines.remove_at(0)
	match t:
		"cam":
			if String(e.get("op", "")) == "punch":
				_zoom_seq = [float(e.get("in", 6)), float(e.get("hold", 30)), float(e.get("out", 20)), float(e.get("zoom", 1.2)), 0.0]
		"shake":
			_trauma = minf(1.0, _trauma + float(e.get("trauma", 0.3)))
		"decor":
			if backdrop != null:
				backdrop.call("set_decor_visible", String(e.get("id", "")), bool(e.get("visible", true)))
				backdrop_front.call("set_decor_visible", String(e.get("id", "")), bool(e.get("visible", true)))
		"sfx", "voice", "laugh":
			if sound:
				_sound(e)
			if blips and t != "laugh":
				_blip(String(e.get("id", e.get("bank", t))), t == "voice")


## Route a clip sound event to the game's Audio autoload (soft: silent without it).
func _sound(e: Dictionary) -> void:
	var au := get_node_or_null("/root/Audio")
	if au == null:
		return
	match String(e.get("type", "")):
		"sfx":
			if au.has_method("play_sfx"):
				au.call("play_sfx", String(e.get("id", "")))
		"voice":
			if au.has_method("play_voice"):
				au.call("play_voice", String(e.get("bank", e.get("id", ""))))
		"laugh":
			var tv := str(e.get("tier", "auto"))
			var kind := String(LAUGH_KINDS.get(tv, tv if tv.begins_with("t") else "t2"))
			if au.has_method("crowd"):
				au.call("crowd", kind)


func _on_finished(id: String) -> void:
	if id == clip_id and not once and player._queue_clip == "":
		_hold_left = REPLAY_PAUSE_F


## Overlay replays: queue the next start `overlay_gap` frames after it ends.
func _on_layer_finished(layer: String, _id: String) -> void:
	if layer == "overlay" and overlay_id != "":
		_ov_next = _vf + float(cfg.get("overlay_gap", 30))


static func _event_label(e: Dictionary) -> String:
	var t := String(e.get("type", ""))
	match t:
		"sfx":
			return "sfx %s" % e.get("id", "")
		"voice":
			return "voice %s" % e.get("bank", e.get("vocal", ""))
		"mark":
			return "mark %s" % e.get("name", "")
		"cam":
			return "cam %s ×%s" % [e.get("op", ""), e.get("zoom", "")]
		"hitstop":
			return "hitstop %d f" % int(e.get("frames", 0))
		"shake":
			return "shake %s" % e.get("trauma", "")
		"prop":
			return "prop %s %s" % [e.get("op", ""), e.get("prop", "")]
		"laugh":
			return "laugh %s" % e.get("tier", "")
		"spring":
			return "spring %s %s" % [e.get("part", ""), e.get("kick", "")]
		"fx":
			return "fx %s" % e.get("id", "")
		"decor":
			return "decor %s %s" % [e.get("id", ""), "on" if bool(e.get("visible", true)) else "off"]
	return t


func _blip(id: String, low: bool) -> void:
	var key := "%s|%s" % [id, low]
	var st: AudioStreamWAV = _blip_cache.get(key, null)
	if st == null:
		var rate := 22050
		var n := int(rate * 0.07)
		var data := PackedByteArray()
		data.resize(n * 2)
		var hz := (220.0 if low else 660.0) * pow(2.0, float(hash(id) % 12) / 12.0)
		for i in n:
			var env := exp(-float(i) / float(n) * 5.0)
			var v := int(clampf(sin(TAU * hz * float(i) / float(rate)) * env * 0.8, -1.0, 1.0) * 32767.0)
			data.encode_s16(i * 2, v)
		st = AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = rate
		st.data = data
		_blip_cache[key] = st
	_blip_player.stream = st
	_blip_player.play()


# --- hot reload --------------------------------------------------------------------------------

func _watched() -> PackedStringArray:
	var out := PackedStringArray()
	var rigs := PackedStringArray([rig_id])
	if player2 != null and not rigs.has(String(cfg["rig2"])):
		rigs.append(String(cfg["rig2"]))
	for r in rigs:
		var rd := "%s/rigs/%s" % [RigDef.data_root, r]
		for f in ["rig.json", "poses.json", "faces.json"]:
			out.append(rd.path_join(f))
		out.append("%s/anim/%s/reactions.json" % [RigDef.data_root, r])
	for cid in [clip_id, clip2_id, overlay_id]:
		if String(cid) != "":
			out.append(String(_files.get(cid, ClipLib.path_of(String(cid)))))
	for p in _players():
		if p.rig != null:
			out.append_array(p.rig.all_texture_paths(p.skin))
	return out


func _snapshot_mtimes() -> void:
	_mtimes.clear()
	for p in _watched():
		_mtimes[p] = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1


func _check_reload() -> void:
	var changed := PackedStringArray()
	for p in _watched():
		var mt := FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
		if int(_mtimes.get(p, -2)) != mt:
			changed.append(p.get_file())
	if changed.is_empty():
		return
	var art := false
	for c in changed:
		if c.ends_with(".svg"):
			art = true
	RigDef.invalidate()
	PoseLib.invalidate()
	ClipLib.invalidate()
	ReactionTable.invalidate()
	AnimLint.reset_caches()
	if art:
		AtlasBuilder.clear()
		AtlasBuilder.clear_svg_sizes()
		HiResTex.clear()
	var f := player.current_frame()
	var pn := pose_name
	_load_rig(rig_id)
	if pn != "":
		_show_pose(pn)
	elif clip_id != "":
		seek(f)
	_snapshot_mtimes()
	_set_status("reloaded %s (%s)" % [", ".join(changed), Time.get_time_string_from_system()])


# --- UI --------------------------------------------------------------------------------------

func _build_ui() -> void:
	player.layer_finished.connect(_on_layer_finished)
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	_root_ui = Control.new()
	_root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = FONT_SIZE
	_root_ui.theme = th
	_ui.add_child(_root_ui)
	_root_ui.visible = not clean
	_info_bg = ColorRect.new()
	_info_bg.color = Color(0.08, 0.07, 0.13, 0.62)
	_info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ui.add_child(_info_bg)
	_title = _mk_label("", 36, TEXT)
	_root_ui.add_child(_title)
	_rig_opt = OptionButton.new()
	_rig_opt.item_selected.connect(func(i: int) -> void: _load_rig(_rig_opt.get_item_text(i)))
	_root_ui.add_child(_rig_opt)
	_clip_opt = OptionButton.new()
	_clip_opt.item_selected.connect(func(i: int) -> void: _play(_clip_opt.get_item_text(i)))
	_root_ui.add_child(_clip_opt)
	_pose_opt = OptionButton.new()
	_pose_opt.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_show_pose(_pose_opt.get_item_text(i)))
	_root_ui.add_child(_pose_opt)
	_info = _mk_label("", 24, TEXT)
	_root_ui.add_child(_info)
	_ticker = _mk_label("", 22, DIM)
	_root_ui.add_child(_ticker)
	_status = _mk_label("", 20, DIM)
	_root_ui.add_child(_status)
	_timeline = _Timeline.new()
	_timeline.viewer = self
	_root_ui.add_child(_timeline)
	_play_btn = _mk_button("▶" if _paused else "❚❚", func() -> void: _toggle_pause())
	_mk_button("⟲", func() -> void: seek(0.0))
	_mk_button("◀", func() -> void:
		_set_paused(true)
		seek(maxf(0.0, player.current_frame() - 1.0)))
	_mk_button("▶", func() -> void:
		_set_paused(true)
		seek(player.current_frame() + 1.0))
	for t in 3:
		var tb := _mk_button("T%d" % (t + 1), func() -> void:
			tier = t + 1
			_play(clip_id))
		tb.toggle_mode = true
		_tier_btns.append(tb)
	_sup_btn = _mk_button("SUP", func() -> void:
		suppressed = not suppressed
		_play(clip_id))
	_sup_btn.toggle_mode = true
	_mk_button("FLIP", func() -> void:
		facing = -facing
		player.set_facing(facing, true))


func _mk_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


var _buttons: Array[Button] = []


func _mk_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 88)
	b.pressed.connect(fn)
	_root_ui.add_child(b)
	_buttons.append(b)
	return b


func _fill_rig_menu() -> void:
	_rig_opt.clear()
	var d := DirAccess.open("%s/rigs" % RigDef.data_root)
	var ids := PackedStringArray()
	if d != null:
		for n in d.get_directories():
			if FileAccess.file_exists("%s/rigs/%s/rig.json" % [RigDef.data_root, n]):
				ids.append(n)
	ids.sort()
	for i in ids.size():
		_rig_opt.add_item(ids[i])
		if ids[i] == rig_id:
			_rig_opt.select(i)


func _fill_clip_menu() -> void:
	_clip_opt.clear()
	for c in ClipLib.list(rig_id):
		_clip_opt.add_item(c)
	_select_clip_item(clip_id)
	_pose_opt.clear()
	_pose_opt.add_item("pose…")
	if player.poses != null:
		for pn in player.poses.names:
			_pose_opt.add_item(pn)


func _select_clip_item(cid: String) -> void:
	for i in _clip_opt.item_count:
		if _clip_opt.get_item_text(i) == cid:
			_clip_opt.select(i)


func _fill_residues() -> void:
	for b in _res_btns:
		_buttons.erase(b)
		b.queue_free()
	_res_btns.clear()
	if player.rig == null:
		return
	var kinds := PackedStringArray(player.rig.residues.keys())
	kinds.sort()
	for k in kinds:
		var kind := String(k)
		if kind.contains(":"):
			continue   # sub-looks / costumes / combos: --looks=
		var b := _mk_button(kind.substr(0, 4), func() -> void: pass)
		b.toggle_mode = true
		b.set_pressed_no_signal(player.has_residue(kind))
		b.toggled.connect(func(on: bool) -> void: player.set_residue(kind, on))
		_res_btns.append(b)
	_layout()


func _toggle_pause() -> void:
	_set_paused(not _paused)


func _set_paused(on: bool) -> void:
	_paused = on
	for p in _players():
		p.paused = on
	if _play_btn != null:
		_play_btn.text = "▶" if on else "❚❚"


func _set_status(t: String) -> void:
	if _status != null:
		_status.text = t


func _layout() -> void:
	var vs := get_viewport_rect().size
	if _root_ui == null:
		return
	var m := 24.0
	var px := vs.x * 0.62
	_title.position = Vector2(m, m)
	_rig_opt.position = Vector2(px, 84)
	_rig_opt.custom_minimum_size = Vector2(250, 72)
	_clip_opt.position = Vector2(px + 262, 84)
	_clip_opt.custom_minimum_size = Vector2(420, 72)
	_pose_opt.position = Vector2(px + 694, 84)
	_pose_opt.custom_minimum_size = Vector2(minf(260.0, vs.x - px - 694 - m), 72)
	_info.position = Vector2(px, 176)
	_info.size = Vector2(vs.x - px - m, 0)
	_ticker.position = Vector2(px, vs.y * 0.5)
	_info_bg.position = Vector2(px - 16, 168)
	_info_bg.size = Vector2(vs.x - px, vs.y - 168 - 250)
	_info_bg.visible = backdrop != null
	_status.position = Vector2(m, vs.y - 40)
	_timeline.position = Vector2(m, vs.y - 236)
	_timeline.size = Vector2(vs.x - 2.0 * m, 110)
	var bx := m
	var by := vs.y - 116
	for b in _buttons:
		b.position = Vector2(bx, by)
		b.size = b.custom_minimum_size
		bx += b.custom_minimum_size.x + 12.0


func _update_info() -> void:
	if player.rig == null:
		return
	for t in _tier_btns.size():
		_tier_btns[t].button_pressed = tier == t + 1
	_sup_btn.button_pressed = suppressed
	var where := ""
	if backdrop != null:
		where = "  · room %s x %d" % [cfg["room"], int(_rig_x)]
	if pose_name != "":
		_title.text = "AnimViewer — %s · pose %s%s" % [rig_id, pose_name, where]
		var tg := ", ".join(player.poses.tags_of(pose_name))
		_info.text = "pose %s\ntags: %s\nface: %s\n%s" % [pose_name, tg, player.poses.face_of(pose_name), player.poses.silhouettes.get(pose_name, "")]
		_ticker.text = ""
		return
	var plan := player.plan()
	if plan == null:
		return
	var c := plan.clip
	_title.text = "AnimViewer — %s%s%s" % [c.id, (" + " + overlay_id.get_file()) if overlay_id != "" else "", where]
	var lines := PackedStringArray()
	lines.append("frame %.1f / %d%s" % [player.current_frame(), plan.length, "  (loop)" if plan.loop else ""])
	lines.append("tier %d%s%s" % [plan.tier, "  suppressed" if plan.suppressed else "", "  → " + plan.last_beat.get_file() if plan.last_beat != "" else ""])
	var bl := PackedStringArray()
	for bn in c.beats:
		var b: Vector2i = c.beats[bn]
		bl.append("%s %d–%d" % [bn, plan.timeline_frame(b.x), plan.timeline_frame(b.y)])
	if not bl.is_empty():
		lines.append(", ".join(bl))
	if c.stride_px > 0.0:
		lines.append("stride %d px / %d f = %.0f px/s natural" % [int(c.stride_px), c.length, c.stride_px / (float(c.length) / 60.0)])
	lines.append("keys %d · events %d · blend in %d / out %d%s" % [c.key_f.size(), plan.events.size(), c.blend_in, c.blend_out, "  · plant" if c.plant else ""])
	var ov := player.layer_clip("overlay")
	if ov != "":
		lines.append("overlay %s f%d  w %.2f" % [ov.get_file(), int(player.layer_frame("overlay")), player.layer_weight("overlay")])
	if player2 != null:
		lines.append("rig 2 %s: %s f%d" % [player2.rig_id, player2.current_clip().get_file(), int(player2.current_frame())])
	var looks := player.active_residues()
	if not looks.is_empty():
		lines.append("looks %s" % ", ".join(looks))
	if _grab != Vector2.INF:
		if not bool(cfg["reach"]):
			lines.append("reach: off (--no-reach)")
		elif c.has_reach():
			var rl := PackedStringArray()
			for lm in c.reach_limbs:
				var ri := player.reach_info(lm)
				rl.append("%s w %.2f · %.1f px%s" % [lm, ri.x, ri.y, (" · ×%.2f" % ri.z) if ri.z > 1.001 else ""])
			var why := player.reach_skipped()
			lines.append("reach %s (%s): %s" % [String(cfg["hotspot"]), c.reach_target, ("skipped: " + why) if why != "" else ", ".join(rl)])
		else:
			lines.append("reach: %s has no reach block" % c.id.get_file())
	var pi4 := player.posture_info()
	if pi4.x > 0.01 or absf(pi4.w) > 0.5 or player.crouch_weight() > 0.01:
		lines.append("posture %.2f · step back %.0f px · hop %.0f px · head %+.0f° · crouch %.2f" % [pi4.x, pi4.y, pi4.z, pi4.w, player.crouch_weight()])
	for gs in _goal_specs:
		var gl: String = gs[0]
		if player.has_goal(gl):
			lines.append("goal %s: error %.1f px · stretch %.2f · weight %.2f" % [gl, player.goal_error(gl), player.goal_stretch(gl), player.goal_weight(gl)])
		else:
			lines.append("goal %s: released" % gl)
	_info.text = "\n".join(lines)
	_ticker.text = "events\n" + "\n".join(_ticker_lines)


## Plain-mode stage (no room): background gradient, a 100 px grid, the floor (world space,
## the feet at the origin) and a contact shadow under each rig.
class _Painter extends Node2D:
	var viewer: Node2D

	func _init() -> void:
		z_index = -30

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var vs: Vector2 = viewer.get_viewport_rect().size
		var rx: float = viewer._rig_x
		var room: bool = viewer.backdrop != null
		var big := Rect2(rx - vs.x * 2.0, -vs.y * 2.0, vs.x * 4.0, vs.y * 4.0)
		if not room:
			draw_rect(big, BG_TOP)
			var steps := 12
			for i in steps:
				var t := float(i) / float(steps)
				draw_rect(Rect2(big.position.x, -vs.y + vs.y * t, big.size.x, vs.y / float(steps) + 1.0), BG_TOP.lerp(BG_BOT, t))
			for gx in range(-20, 21):
				var x := rx + float(gx) * 100.0
				draw_line(Vector2(x, -vs.y), Vector2(x, 0), Color(1, 1, 1, 0.05), 2.0)
			for gy in range(1, 10):
				var y := -float(gy) * 100.0
				draw_line(Vector2(big.position.x, y), Vector2(big.end.x, y), Color(1, 1, 1, 0.05), 2.0)
			draw_rect(Rect2(big.position.x, 0, big.size.x, vs.y * 2.0), FLOOR)
			draw_rect(Rect2(big.position.x, 0, big.size.x, 14), FLOOR_DARK)
			draw_line(Vector2(big.position.x, 0), Vector2(big.end.x, 0), INK, 4.0)
		else:
			draw_rect(big, Color("#221C33"))


## The --goal crosshairs over everything: the target (ring + cross), a line from the grip to it
## while it is not reached, and the error in px. Green within 2 px, amber while blending,
## red when the goal cannot be reached (out of reach / limits).
class _GoalMarker extends Node2D:
	var viewer: Node2D

	func _init() -> void:
		z_index = 100

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pl: RigPlayer = viewer.player
		if pl == null or pl.rig == null:
			return
		var font := ThemeDB.fallback_font
		var gp: Vector2 = viewer._grab
		if gp != Vector2.INF:
			var on: bool = pl.is_reaching()
			var gc := Color("#46D27A") if on else Color("#9A8FB0")
			draw_arc(gp, 12.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 6.0)
			draw_arc(gp, 12.0, 0.0, TAU, 32, gc, 2.5)
			draw_line(gp + Vector2(-20, 0), gp + Vector2(20, 0), gc, 2.0)
			draw_line(gp + Vector2(0, -20), gp + Vector2(0, 20), gc, 2.0)
			var lbl := "grab" if on else ("grab (%s)" % pl.reach_skipped() if pl.reach_skipped() != "" else "grab (not reaching)")
			draw_string(font, gp + Vector2(16, -16), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gc)
		for i in viewer._goal_specs.size():
			var limb: String = viewer._goal_specs[i][0]
			var t: Vector2 = viewer.goal_point(i)
			var col := Color("#9A8FB0")
			var label := "%s released" % limb
			if pl.has_goal(limb):
				var err := pl.goal_error(limb)
				var w := pl.goal_weight(limb)
				col = Color("#46D27A") if err <= 2.0 else (Color("#F2B33D") if w < 0.999 else Color("#F0524F"))
				label = "%s %.1f px" % [limb, err]
				if pl.goal_stretch(limb) > 1.001:
					label += "  ×%.2f" % pl.goal_stretch(limb)
				var sock := "%s:grip" % _end_name(pl, limb)
				var grip := pl.socket_global_transform(sock).origin if pl.rig.socket_index(sock) >= 0 else pl.part_global_position(_end_name(pl, limb))
				if err > 2.0:
					draw_line(grip, t, Color(col, 0.8), 3.0)
			draw_arc(t, 14.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 7.0)
			draw_arc(t, 14.0, 0.0, TAU, 32, col, 3.0)
			draw_line(t + Vector2(-24, 0), t + Vector2(24, 0), col, 2.0)
			draw_line(t + Vector2(0, -24), t + Vector2(0, 24), col, 2.0)
			draw_string(font, t + Vector2(20, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)

	func _end_name(pl: RigPlayer, limb: String) -> String:
		for l in pl.rig.limbs:
			if l.id == limb and l.joints.size() >= 3:
				return pl.rig.names[l.joints[l.joints.size() - 1]]
		return ""


## Contact shadows under the rigs (between the backdrop and the rigs).
class _Shadows extends Node2D:
	var viewer: Node2D

	func _init() -> void:
		z_index = -1

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for p in viewer._players():
			var rp: RigPlayer = p
			draw_set_transform(Vector2(rp.global_position.x, 4), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 90.0, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The scrub bar: beats, keys, events, the overlay window, playhead. Click / drag to scrub.
class _Timeline extends Control:
	var viewer: Node2D

	func _gui_input(ev: InputEvent) -> void:
		var pos := Vector2.INF
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			pos = (ev as InputEventMouseButton).position
		elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pos = (ev as InputEventMouseMotion).position
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			pos = (ev as InputEventScreenTouch).position
		elif ev is InputEventScreenDrag:
			pos = (ev as InputEventScreenDrag).position
		if pos != Vector2.INF:
			var plan: PlayPlan = viewer.player.plan()
			if plan != null:
				viewer._set_paused(true)
				viewer.seek(clampf(pos.x / size.x, 0.0, 1.0) * float(plan.length))
			accept_event()

	func _draw() -> void:
		var plan: PlayPlan = viewer.player.plan()
		draw_rect(Rect2(Vector2.ZERO, size), PANEL)
		if plan == null:
			return
		var ln := float(maxi(1, plan.length))
		var c := plan.clip
		var font := get_theme_default_font()
		var cols := {"anticipation": Color("#F2B33D"), "accent": KEY_COL, "hold": HOLD_COL, "settle": Color("#2FA39A")}
		for bn in c.beats:
			var b: Vector2i = c.beats[bn]
			var x0 := size.x * float(plan.timeline_frame(b.x)) / ln
			var x1 := size.x * float(plan.timeline_frame(b.y)) / ln
			draw_rect(Rect2(x0, 6, maxf(2.0, x1 - x0), 40), Color(cols.get(bn, Color("#9A8FB0")), 0.8))
			draw_string(font, Vector2(x0 + 6, 36), String(bn), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
		if plan.tail != null:
			var xt := size.x * float(plan.tail_start) / ln
			draw_rect(Rect2(xt, 6, size.x - xt, 40), Color("#7A5CA0", 0.8))
			draw_string(font, Vector2(xt + 6, 36), "suppressed", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		for k in c.key_f:
			var xk := size.x * float(plan.timeline_frame(k)) / ln
			draw_line(Vector2(xk, 50), Vector2(xk, 78), KEY_COL, 3.0)
		for e in plan.ev_f:
			draw_circle(Vector2(size.x * float(e) / ln, 92), 5.0, TEXT)
		var pl: RigPlayer = viewer.player
		var w := pl.layer_weight("overlay")
		if w > 0.0:
			draw_rect(Rect2(0, 80, size.x, 6), Color(OV_COL, 0.25 + 0.75 * w))
			draw_string(font, Vector2(8, size.y - 30), "overlay %s" % pl.layer_clip("overlay").get_file(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, OV_COL)
		var xp: float = size.x * pl.current_frame() / ln
		draw_line(Vector2(xp, 0), Vector2(xp, size.y), Color.WHITE, 4.0)
		draw_string(font, Vector2(minf(xp + 8, size.x - 120), size.y - 6), "f %d" % int(pl.current_frame()), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
