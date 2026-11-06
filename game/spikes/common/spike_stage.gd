## SpikeStage — the real house rooms as a flat backdrop for a spike, plus a floor and end walls.
## Rooms come straight from `data/house/house.json`, so a spike looks like the game without owning
## any art. The floor line is y = 0 (the house art is authored with its floor there).
class_name SpikeStage
extends Node2D

const FLOOR_Y := 0.0
## Collision layer the floor, walls and props all share.
const L_WORLD := 1

var x0: float = 0.0
var x1: float = 0.0


## Build `room_ids` (left to right) and the static bodies around them.
func build(room_ids: PackedStringArray) -> void:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://data/house/house.json")) != OK:
		push_error("SpikeStage: cannot read house.json")
		return
	var house: Dictionary = j.data
	var first := true
	for rd: Dictionary in house.get("rooms", []):
		var rid := str(rd.get("id", ""))
		if not room_ids.has(rid):
			continue
		var art: Dictionary = rd.get("art", {})
		var pos: Array = art.get("pos", [0, 0])
		var at := Vector2(float(pos[0]), float(pos[1]))
		_add_art(str(art.get("bg", "")), at, -100)
		_add_art(str(art.get("fg", "")), at, 60)
		var rx0 := float(rd.get("x0", 0))
		var rx1 := float(rd.get("x1", 0))
		x0 = rx0 if first else minf(x0, rx0)
		x1 = rx1 if first else maxf(x1, rx1)
		first = false
	_add_floor()


func _add_art(path: String, at: Vector2, z: int) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = at
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)


## A floor plane and a wall at each end, so thrown props stay on the set.
func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = L_WORLD
	var fs := CollisionShape2D.new()
	var seg := WorldBoundaryShape2D.new()
	seg.normal = Vector2.UP
	seg.distance = FLOOR_Y
	fs.shape = seg
	floor_body.add_child(fs)
	add_child(floor_body)
	for side in [-1.0, 1.0]:
		var w := StaticBody2D.new()
		w.collision_layer = L_WORLD
		var ws := CollisionShape2D.new()
		var wb := WorldBoundaryShape2D.new()
		wb.normal = Vector2(-side, 0)
		wb.distance = -(x1 if side > 0.0 else -x0)
		ws.shape = wb
		w.add_child(ws)
		add_child(w)
