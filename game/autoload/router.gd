## Router — scene navigation with transitions and Android back (TECH §5.1, §6.6).
##
## `goto(key, params, transition)` swaps the current scene: the transition covers the screen
## while the scene loads on a background thread, the new scene is instantiated, `setup(params)`
## is called on its root BEFORE it enters the tree (if defined), then the transition reveals it.
## Routes: `boot`, `night` (Stage 2's NightScene), `playbill` (Stage 4; until then — and for any
## route whose scene is missing — a generated ComingSoonScreen with a Back button).
## Transitions: "curtain" (CurtainTransition: the red curtain drops / rises), "fade"
## (FadeTransition), "none".
## Scene hooks (optional, on the scene root):
##   func setup(params: Dictionary) -> void     # before _ready
##   func handle_back() -> bool                 # true = consumed (NightScene opens its pause menu)
## Android back (NOTIFICATION_WM_GO_BACK_REQUEST) and Escape → `handle_back_request()`:
## the scene's handle_back(), else the history, else nothing — the game never quits on Back.
## Registered as the `Router` autoload by the orchestrator.
extends Node

signal route_changed(key: String, params: Dictionary)
signal transition_finished(key: String)

const SCENES := {
	"boot": "res://scenes/boot/Boot.tscn",
	"night": "res://scenes/night/NightScene.tscn",
	"playbill": "res://scenes/playbill/Playbill.tscn",
}
const TRANSITIONS: PackedStringArray = ["curtain", "fade", "none"]
const NO_HISTORY: PackedStringArray = ["boot"]
const MAX_HISTORY := 16

var current_key: String = ""
var params: Dictionary = {}
var history: Array = []          # [{key, params}]
var busy: bool = false
## Test hook: skip transitions (instant swaps).
var instant: bool = false
## Test hook: route key → scene path overriding SCENES ("" = generated Coming soon screen).
var scene_overrides: Dictionary = {}
## Back requests handled (tests).
var back_count: int = 0

var _layer: CanvasLayer
var _fade: FadeTransition
var _curtain: CurtainTransition
var _queued: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	_layer = CanvasLayer.new()
	_layer.name = "TransitionLayer"
	_layer.layer = 128
	add_child(_layer)
	_fade = FadeTransition.new()
	_layer.add_child(_fade)
	_curtain = CurtainTransition.new()
	_layer.add_child(_curtain)


# --- public API ------------------------------------------------------------------------------

## Scene path for a route key ("" when unknown).
func scene_path_for(key: String) -> String:
	if scene_overrides.has(key):
		return String(scene_overrides[key])
	return String(SCENES.get(key, ""))


## Does the route have a real scene file?
func has_scene(key: String) -> bool:
	var p := scene_path_for(key)
	return p != "" and ResourceLoader.exists(p)


## Navigate to `key`, pushing the current route onto the history. Awaitable.
func goto(key: String, p_params: Dictionary = {}, transition: String = "curtain") -> void:
	await _switch(key, p_params, transition, true)


## Navigate without pushing history (the current route is replaced). Awaitable.
func replace(key: String, p_params: Dictionary = {}, transition: String = "curtain") -> void:
	await _switch(key, p_params, transition, false)


func can_go_back() -> bool:
	return not history.is_empty()


## Pop the history. Returns false when there is nothing to go back to.
func back(transition: String = "fade") -> bool:
	if history.is_empty():
		return false
	var prev: Dictionary = history.pop_back()
	_switch(String(prev["key"]), prev.get("params", {}), transition, false)
	return true


## Android back / Escape: the scene's handle_back(), else the history; never quits.
func handle_back_request() -> void:
	back_count += 1
	if busy:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("handle_back") and bool(scene.call("handle_back")):
		return
	back()


## The transition node for a kind (tests).
func transition_node(kind: String) -> Node:
	return _curtain if kind == "curtain" else _fade


# --- switching ---------------------------------------------------------------------------------

func _switch(key: String, p_params: Dictionary, transition: String, push: bool) -> void:
	if busy:
		_queued = [key, p_params, transition, push]
		return
	busy = true
	var path := scene_path_for(key)
	var threaded := path != "" and ResourceLoader.exists(path) and not OS.has_feature("web")
	if threaded:
		ResourceLoader.load_threaded_request(path, "PackedScene", true)
	var kind := "none" if instant else (transition if TRANSITIONS.has(transition) else "fade")
	await _cover(kind)
	var node := await _instantiate(key, path, threaded)
	if node.has_method("setup"):
		node.call("setup", p_params)
	node.set_meta("router_params", p_params)
	if push and current_key != "" and not NO_HISTORY.has(current_key) and current_key != key:
		history.append({"key": current_key, "params": params})
		while history.size() > MAX_HISTORY:
			history.pop_front()
	_swap_scene(node)
	current_key = key
	params = p_params
	route_changed.emit(key, p_params)
	if is_inside_tree():
		await get_tree().process_frame
	await _reveal(kind)
	busy = false
	transition_finished.emit(key)
	if not _queued.is_empty():
		var q := _queued
		_queued = []
		_switch(String(q[0]), q[1], String(q[2]), bool(q[3]))


func _instantiate(key: String, path: String, threaded: bool) -> Node:
	var ps: PackedScene = null
	if path != "" and ResourceLoader.exists(path):
		if threaded:
			var status := ResourceLoader.load_threaded_get_status(path)
			while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
				status = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				ps = ResourceLoader.load_threaded_get(path) as PackedScene
		if ps == null:
			ps = load(path) as PackedScene
	var node: Node = ps.instantiate() if ps != null else null
	if node == null:
		node = ComingSoonScreen.new(key)
	return node


func _swap_scene(node: Node) -> void:
	var tree := get_tree()
	var old := tree.current_scene
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	tree.root.add_child(node)
	tree.current_scene = node


func _cover(kind: String) -> void:
	if kind == "none":
		return
	if kind == "curtain":
		await _curtain.cover("curtain")
	else:
		await _fade.cover("fade")


func _reveal(kind: String) -> void:
	if kind == "none":
		return
	if kind == "curtain":
		await _curtain.reveal("curtain")
	else:
		await _fade.reveal("fade")


# --- system events -----------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		handle_back_request()
