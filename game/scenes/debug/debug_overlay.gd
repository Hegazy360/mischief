## DebugOverlay — the Fun-Gate debug overlay (s2-night §4.5), owned by the DevShot autoload on its own
## CanvasLayer and toggled by a three-finger tap on any screen. While hidden it is not in the tree's
## input path at all (IGNORE filter, invisible), so it never eats a touch. Shows fps now + p95, frame
## ms, draw calls, sim ms/tick (NightScene's measure), texture MB, the laugh clock (laughs so far, the
## first player laugh from tick 0), and two buttons: **Copy log** (`DisplayServer.clipboard_set` — no
## permission needed; the owner pastes it into a chat) and **Stage door** (debug builds only).
## Labels from `overlay.*`.
class_name DebugOverlay
extends Control

const PANEL := Vector2(760, 470)
## A path, not StageDoor.SCENE: the DevShot autoload loads this script, and must never depend on the
## whole game's class graph (a broken view script would take the autoload down with it).
const STAGE_DOOR_SCENE := "res://scenes/stage_door/StageDoor.tscn"
const WINDOW := 120

var shown: bool = false
var _fps := PackedFloat32Array()
var _i: int = 0
var _n: int = 0
var _lines := PackedStringArray()
var _copy: UiButton = null
var _door: UiButton = null
var _t: float = 0.0
var _copied_t: float = 0.0


func _init() -> void:
	name = "DebugOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_fps.resize(WINDOW)
	_lines.resize(7)


func _ready() -> void:
	_copy = UiButton.make(UiStrings.t("overlay.copy_log"), Vector2(340, 144), UiKit.GOLD, UiKit.GOLD_SHADE)
	_copy.name = "CopyLog"
	_copy.pressed.connect(copy_log)
	add_child(_copy)
	if OS.is_debug_build():
		_door = UiButton.make(UiStrings.t("overlay.stage_door"), Vector2(340, 144))
		_door.name = "StageDoor"
		_door.pressed.connect(open_stage_door)
		add_child(_door)
	_layout()
	set_process(false)


func _layout() -> void:
	var p := Vector2(32, 150)
	_copy.position = p + Vector2(24, PANEL.y - 144.0 - 24.0)
	if _door != null:
		_door.position = p + Vector2(24 + 340 + 24, PANEL.y - 144.0 - 24.0)


## Show / hide.
func toggle() -> void:
	set_shown(not shown)


func set_shown(on: bool) -> void:
	shown = on
	visible = on
	set_process(on)
	queue_redraw()


## Put the device log on the clipboard (the owner pastes it into a chat).
func copy_log() -> void:
	DeviceLog.flush()
	DisplayServer.clipboard_set(DeviceLog.to_text())
	_copied_t = 1.5
	_copy.text = UiStrings.t("overlay.copied")
	_copy.queue_redraw()


func open_stage_door() -> void:
	set_shown(false)
	var r := ViewKit.autoload("Router")
	if r != null and r.has_method("has_route") and bool(r.call("has_route", "stage_door")):
		r.call("goto", "stage_door")
	elif ResourceLoader.exists(STAGE_DOOR_SCENE):
		get_tree().change_scene_to_file(STAGE_DOOR_SCENE)


func _process(delta: float) -> void:
	if delta > 0.0:
		_fps[_i] = 1.0 / delta
		_i = (_i + 1) % WINDOW
		_n = mini(_n + 1, WINDOW)
	_t += delta
	if _copied_t > 0.0:
		_copied_t -= delta
		if _copied_t <= 0.0:
			_copy.text = UiStrings.t("overlay.copy_log")
			_copy.queue_redraw()
	if _t >= 0.25:
		_t = 0.0
		_refresh(delta)
		queue_redraw()


func _refresh(delta: float) -> void:
	var sorted := _fps.slice(0, _n)
	sorted.sort()
	var p95 := DeviceLog.percentile(sorted, 0.05)
	var now := 1.0 / delta if delta > 0.0 else 0.0
	_lines[0] = "%s %.0f  %s %.0f" % [UiStrings.t("overlay.fps"), now, UiStrings.t("overlay.p95"), p95]
	_lines[1] = "%.1f %s" % [delta * 1000.0, UiStrings.t("overlay.frame_ms")]
	_lines[2] = "%d %s" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), UiStrings.t("overlay.draw_calls")]
	var ns := get_tree().get_first_node_in_group("night_scene") if is_inside_tree() else null
	var sim_ms: float = float(ns.get("sim_ms_per_tick")) if ns != null and ns.get("sim_ms_per_tick") != null else 0.0
	_lines[3] = "%.2f %s" % [sim_ms, UiStrings.t("overlay.sim_ms")]
	_lines[4] = "%.0f %s" % [Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, UiStrings.t("overlay.tex_mb")]
	var s := DeviceLog.session()
	var laughs: int = (s.get("laughs", []) as Array).size() if s.get("laughs") is Array else 0
	var first := int(s.get("first_player_laugh_ms", -1))
	var start := int(s.get("sim_start_ms", -1))
	var rel := "%.1f s" % (float(first - start) / 1000.0) if first >= 0 and start >= 0 else "–"
	_lines[5] = "%s %d · 1st %s" % [UiStrings.t("overlay.laugh_clock"), laughs, rel]
	_lines[6] = _tex_line()


## The three biggest texture-memory kinds (TexStats, soft: the autoload never depends on the view).
static func _tex_line() -> String:
	const TS := "res://view/tex/tex_stats.gd"
	if not ResourceLoader.exists(TS):
		return ""
	var kinds: Dictionary = (load(TS) as Script).call("live_bytes_by_kind")
	var ks := kinds.keys()
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(kinds[a]) > int(kinds[b]))
	var parts := PackedStringArray()
	for i in mini(3, ks.size()):
		parts.append("%s %.0f" % [ks[i], float(kinds[ks[i]]) / 1048576.0])
	return " · ".join(parts)


func _draw() -> void:
	if not shown:
		return
	var r := Rect2(Vector2(32, 150), PANEL)
	draw_rect(r, Color(UiKit.NAVY, 0.86))
	draw_rect(r, UiKit.GOLD, false, 4.0)
	var f := UiKit.ui_font()
	var y := r.position.y + 50.0
	for l in _lines:
		if l == "":
			continue
		draw_string(f, Vector2(r.position.x + 24.0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiKit.CREAM)
		y += 40.0
