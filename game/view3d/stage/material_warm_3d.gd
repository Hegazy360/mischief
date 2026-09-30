## MaterialWarm3D — the material warm-up registry (REDESIGN §6.3 "no shader compiled during play", R3D index §7.6).
## Every task that creates a 3D material at runtime registers it: `MaterialWarm3D.register(mat, &"char")`.
## NightWarm (`r3d-night`) calls `build_warm_rig(parent, cam)` under the curtain: one small quad per distinct
## (shader, kind, next-pass chain) in front of the camera, drawn once, then `free_warm_rig()`. The Compatibility
## renderer compiles a shader variant on its first draw, so drawing each pair once under the curtain keeps PLAY free
## of compile hitches (the e2e perf log counts compiles during PLAY).
## Static registry (no autoload, ruling L7); `clear()` between Nights and in tests.
class_name MaterialWarm3D
extends RefCounted

static var _entries: Dictionary = {}   # key → {material, kind, count}
static var _total := 0
static var _rig: Node3D = null


## Registers a material (and its next-pass chain) under a kind (&"char", &"set", &"prop", &"ink", &"halo",
## &"decal", &"fx", …). Materials sharing a shader, kind and pass chain count as one warm entry.
static func register(mat: Material, kind: StringName) -> void:
	if mat == null:
		return
	_total += 1
	var key := key_of(mat, kind)
	var e: Dictionary = _entries.get(key, {})
	if e.is_empty():
		_entries[key] = {"material": mat, "kind": kind, "count": 1}
	else:
		e["count"] = int(e["count"]) + 1


## The warm key of a material: its shader path (or class) + the kind + every next pass's shader.
static func key_of(mat: Material, kind: StringName) -> String:
	var parts := PackedStringArray([String(kind)])
	var m := mat
	var guard := 0
	while m != null and guard < 8:
		if m is ShaderMaterial:
			var sh: Shader = (m as ShaderMaterial).shader
			parts.append(sh.resource_path if sh != null and sh.resource_path != "" else "shader:%d" % (sh.get_instance_id() if sh != null else 0))
		else:
			parts.append(m.get_class())
		m = m.next_pass
		guard += 1
	return "|".join(parts)


## Every distinct entry: [{material, kind, count}] (sorted by key, deterministic).
static func entries() -> Array:
	var keys := _entries.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append(_entries[k])
	return out


## The number of distinct warm entries.
static func count() -> int:
	return _entries.size()


## The number of register() calls (every material, duplicates included).
static func total_registered() -> int:
	return _total


## True when a material's key is registered.
static func has(mat: Material, kind: StringName) -> bool:
	return _entries.has(key_of(mat, kind))


## Forgets every entry (a new Night, tests).
static func clear() -> void:
	_entries.clear()
	_total = 0
	free_warm_rig()


## Builds the warm rig: one 0.1 m quad per entry, 1.5 m in front of `cam`, inside its frustum, on every visual layer
## the entry's kind renders on. Returns the rig (already a child of `parent`); free it after two drawn frames.
static func build_warm_rig(parent: Node, cam: Camera3D) -> Node3D:
	free_warm_rig()
	var rig := Node3D.new()
	rig.name = "MaterialWarm3D"
	parent.add_child(rig)
	_rig = rig
	var list := entries()
	var n := list.size()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var origin := cam.global_position + fwd * 1.5
	for i in n:
		var e: Dictionary = list[i]
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = e["material"]
		mi.layers = View3DConst.MASK_MAIN
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var col := i % 16
		var row := i / 16
		rig.add_child(mi)
		mi.global_position = origin + right * (-0.36 + 0.048 * col) + up * (-0.2 + 0.05 * row)
		mi.look_at(cam.global_position, up, true)
	return rig


## Frees the warm rig (if any).
static func free_warm_rig() -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.queue_free()
	_rig = null
