## RigProfile3D — per-character CPU and render counters for RigPerf3D and the perf test (r3d-rig §4.4, §7): the
## player's frame cost measured around `RigPlayer3D.advance()` (clip clock, tree evaluation, events, look-at, face,
## and — the skeleton runs its modifiers inside advance() — props, jiggle springs), plus the static counts of the
## rig (triangles, bones, deform bones, draw calls) and, when rendering, the frame's draw calls / primitives.
class_name RigProfile3D
extends RefCounted

var samples_us := PackedFloat32Array()
var draw_calls := PackedInt32Array()
var primitives := PackedInt32Array()
var process_ms := PackedFloat32Array()


## Steps `rig` by `dt` and records the cost (µs).
func step(rig: RigPlayer3D, dt: float) -> float:
	var t0 := Time.get_ticks_usec()
	rig.advance(dt)
	var us := float(Time.get_ticks_usec() - t0)
	samples_us.append(us)
	return us


## Records the renderer's counters of the last drawn frame.
func record_render() -> void:
	draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)


## Static counts of a set-up rig: triangles of every visible mesh, bones, deform bones (weighted), draw calls
## (surfaces + their next passes, visible attachments included).
static func rig_counts(rig: RigPlayer3D) -> Dictionary:
	var tris := 0
	var draws := 0
	var deform := {}
	if rig.rig_root != null:
		for mi in rig.rig_root.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			if m3.mesh == null or not m3.is_visible_in_tree():
				continue
			for s in m3.mesh.get_surface_count():
				var arr := m3.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				tris += idx.size() / 3 if not idx.is_empty() else nv / 3
				var mat := m3.get_active_material(s)
				while mat != null:
					draws += 1
					mat = mat.next_pass
				if m3.skin != null and arr[Mesh.ARRAY_BONES] != null:
					var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
					var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
					for i in bones.size():
						if w[i] > 0.0:
							var bind: int = bones[i]
							var bn: String = String(m3.skin.get_bind_name(bind)) if bind < m3.skin.get_bind_count() else ""
							deform[bn if bn != "" else str(m3.skin.get_bind_bone(bind))] = true
	return {"tris": tris, "draw_calls": draws, "bones": rig.skeleton.get_bone_count() if rig.skeleton != null else 0,
		"deform_bones": deform.size()}


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(round(q * float(s.size() - 1))), 0, s.size() - 1)]


## The summary: CPU µs (median, p95, max), render counters (median), static counts.
func summary(rig: RigPlayer3D, skip := 30) -> Dictionary:
	var a := samples_us.slice(mini(skip, maxi(0, samples_us.size() - 1)))
	var dc := PackedFloat32Array()
	for v in draw_calls:
		dc.append(float(v))
	var pr := PackedFloat32Array()
	for v2 in primitives:
		pr.append(float(v2))
	var out := {"rig": rig.rig_id, "variant": rig.variant, "clip": rig.current_clip(), "frames": samples_us.size(),
		"cpu_us_median": _pct(a, 0.5), "cpu_us_p95": _pct(a, 0.95), "cpu_us_max": _pct(a, 1.0),
		"frame_draw_calls_median": _pct(dc, 0.5), "frame_primitives_median": _pct(pr, 0.5),
		"process_ms_median": _pct(process_ms, 0.5)}
	out.merge(rig_counts(rig))
	return out
