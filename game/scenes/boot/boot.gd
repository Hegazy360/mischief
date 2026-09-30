## Boot — the first frame is the red curtain (GDD §2.3, TECH §9, s2-night §4.2).
##
## Frame 1: the curtain (the imported 1× `art/house/stage/curtain.svg` — no HiResTex wait) on a top
## CanvasLayer, `house_lights_dim`, DeviceLog `boot` + `first_frame`. Frame 2: `Audio.warm_up()`.
## Frame 3: the route (`BootRouting.start_for(boot_config.json, Save, Content)`):
## * a Night → the NightScene is instantiated **underneath the curtain** with `{episode, from: boot,
##   rise_at_ms, rise_cap_ms}`: it warms up (NightWarm) with its SimDriver paused at tick 0 while the
##   view pre-rolls Bellows' "MI-MI-MIIII", and starts its own curtain rise — the sim clock's tick 0
##   (L13) — at ≈ 2.3 s from process start (the director's `launch_offset_s`; never before 2.0 s; at
##   3.0 s even when not warm). Boot hands the screen over once the NightScene's own curtain has drawn
##   (same geometry: the swap never shows) and frees itself; the NightScene becomes the current scene
##   and the Router's current route `night`.
## * `stage_door` (debug builds) / `playbill` → `Router.replace(route)` (no curtain call to wait for).
## `--start=<auto|stage_door|episode>` (debug) and `BootRouting.override_start` (the e2e driver sets it
## before frame 3) override boot_config.json.
## R3D: boot_config.json's other keys (BootConfig: `view`, `show_previews`, `bellows_window`, `render`) are read by
## the NightScene (the view and its render settings), Settings (the debug defaults) and the stage door; on the 3D
## view the Night's build and material warm-up (NightWarmer, every material drawn once) run under this same first
## 2D curtain, and the e2e report / device log give process start → curtain up, `night_build_ms` and `warm_ms`.
## No menus before play.
extends Control

const LAYER := 30
const EARLIEST_RISE_MS := 2000
const LATEST_RISE_MS := 3000
const DEFAULT_LAUNCH_S := 2.3

var route: Dictionary = {}
var night: Node = null
var frame: int = 0
## Test hooks: a config override and "build but do not hand over".
var config_override: String = ""
var keep: bool = false

var _curtain_layer: CanvasLayer = null
var _curtain: NightCurtain = null
var _handed: bool = false


func _ready() -> void:
	DeviceLog.mark("boot")
	_curtain_layer = CanvasLayer.new()
	_curtain_layer.layer = LAYER
	_curtain_layer.name = "BootCurtain"
	add_child(_curtain_layer)
	_curtain = NightCurtain.new()
	_curtain_layer.add_child(_curtain)
	_curtain.set_down()
	_audio("play_sfx", ["house_lights_dim"])


func _process(_delta: float) -> void:
	frame += 1
	match frame:
		1:
			DeviceLog.mark("first_frame")
		2:
			_audio("warm_up", [])
		3:
			_route()
	if night != null and not _handed and frame >= 5 and not keep:
		_hand_over()


## The launch route for this build ({route, params}).
func pick_route() -> Dictionary:
	var start := config_override if config_override != "" else BootRouting.read_config()
	var cli := cli_start(OS.get_cmdline_user_args())
	if cli != "":
		start = cli
	if BootRouting.override_start != "":
		start = BootRouting.override_start
	var sv := ViewKit.autoload("Save")
	var done := sv != null and sv.has_method("prologue_done") and bool(sv.call("prologue_done"))
	return BootRouting.start_for(start, done, BootRouting.saved_stars(), BootRouting.episode_table(), OS.is_debug_build())


## `--start=<auto|stage_door|episode>` (debug builds) overrides the config.
static func cli_start(args: PackedStringArray) -> String:
	if not OS.is_debug_build():
		return ""
	for a in args:
		if a.begins_with("--start="):
			return a.substr(8)
	return ""


## Launch rise window (ms from process start) for an episode's director launch offset.
static func rise_window(launch_offset_s: float) -> Vector2i:
	var at := clampi(int(round(launch_offset_s * 1000.0)), EARLIEST_RISE_MS, LATEST_RISE_MS)
	return Vector2i(at, LATEST_RISE_MS)


func _route() -> void:
	route = pick_route()
	if String(route.get("route", "")) != "night":
		var r := ViewKit.autoload("Router")
		if r != null and r.has_method("replace"):
			r.call("replace", String(route["route"]), route.get("params", {}), "none")
		return
	var p: Dictionary = (route.get("params", {}) as Dictionary).duplicate()
	var ep := String(p.get("episode", BootRouting.PROLOGUE))
	var w := rise_window(launch_offset(ep))
	p["rise_at_ms"] = w.x
	p["rise_cap_ms"] = w.y
	var ps := load(NightScene.SCENE) as PackedScene
	night = ps.instantiate()
	night.call("setup", p)
	get_tree().root.add_child.call_deferred(night)


## The episode's director `launch_offset_s` (2.3 s when it has none).
static func launch_offset(ep: String) -> float:
	var c := ViewKit.autoload("Content")
	var db: Variant = c.get("db") if c != null else null
	var eps: Variant = (db as Object).get("episodes") if db is Object else null
	if eps is Dictionary and (eps as Dictionary).has(ep):
		var d: Variant = ((eps as Dictionary)[ep] as Object).get("director")
		if d is Dictionary and (d as Dictionary).get("launch_offset_s") != null:
			return float((d as Dictionary)["launch_offset_s"])
	return DEFAULT_LAUNCH_S


func _hand_over() -> void:
	if not night.is_inside_tree():
		return
	_handed = true
	var tree := get_tree()
	tree.current_scene = night
	var r := ViewKit.autoload("Router")
	if r != null:
		r.set("current_key", "night")
		r.set("params", route.get("params", {}))
	queue_free()


func _audio(m: String, args: Array) -> void:
	var a := ViewKit.autoload("Audio")
	if a != null and a.has_method(m):
		a.callv(m, args)
