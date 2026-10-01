## ScriptProf3D — a per-node script-time profiler for a Night (REDESIGN §6.3 row "view + HUD scripts ≤ 4 ms p95";
## the lint fix pass). Off unless the game runs with the user arg `--view3d-prof=/abs/out.json` (WorldView3D calls
## `maybe_attach` once at setup; nothing is added otherwise).
##
## ~1 s after it enters the tree it brackets every node of the classes in `WATCH` (by script global name) with two
## sentinel nodes — its previous and next sibling at the SAME `process_priority` — so the time between the two stamps
## is that node's `_process` plus every descendant's at that priority (the engine processes by priority, then tree
## order). Two more sentinels at priority −99 (after NightScene's AfterSim) and 899 (before its FrameEnd) give the
## frame's view + HUD total the e2e `perf3d.view_ms_*` measures; "other" = total − the watched top-level nodes.
## Only PLAY frames (NightScene `phase` 5) are recorded. Writes {frames, total, other, classes: {name: {nodes, mean,
## p50, p95, max}}, world_view: {phase: mean µs}} (ms) to the JSON every 600 frames and on exit.
class_name ScriptProf3D
extends Node

const ARG := "--view3d-prof="
const CAP := 20000
const WRITE_EVERY := 600
const ARM_S := 1.0
const PHASE_PLAY := 5
## Watched classes (script global names). Nested watched nodes at the same priority are counted inside their parent too.
const WATCH: PackedStringArray = ["WorldView3D", "CameraDirector3D", "PipView3D", "GagStager3D", "AudioDirector",
	"StallsView", "Hud", "WorldOverlays", "InputRouter", "NightScene", "House3D", "HapticsDirector", "NightWarmer",
	"CurtainCall", "Ftue", "RigPlayer3D", "FxFreezeFrame", "FxWipe", "JuiceClock"]
const WV_PHASES: PackedStringArray = ["hush_apply", "bellows_apply", "caught_recorder", "props_cues", "decals_fx",
	"overlays"]


class Sentinel:
	extends Node
	var prof: ScriptProf3D = null
	var slot: int = 0

	func _process(_d: float) -> void:
		prof.stamp(slot)


class _EndSentinel:
	extends Node
	var prof: ScriptProf3D = null
	var slot: int = 0

	func _process(_d: float) -> void:
		prof.stamp(slot)
		prof.end_frame()


var out_path: String = ""
var night: Node = null
var world_view: Node = null

var _armed := false
var _t := 0.0
var _stamps := PackedInt64Array()
var _stamp_frame := PackedInt64Array()
var _frame := 0
## [class index, slot A, slot B, top-level (not inside another watched node's bracket), is NightScene]
var _rows: Array = []
var _names: PackedStringArray = PackedStringArray()
## Rings, flat: class index × CAP + sample (a member, so writes never copy).
var _ring := PackedFloat32Array()
var _nodes := PackedInt32Array()
var _tot := PackedFloat32Array()
var _oth := PackedFloat32Array()
var _cur := PackedFloat32Array()
var _n := 0
## The slowest frames: [total ms, frame, {class: ms}] (the spike split), at most SPIKES kept.
const SPIKES := 60
var _spikes: Array = []
var _spike_min := 0.0
var _slot_start := 0
var _slot_end := 1


## Adds a profiler to `host`'s Night when the user arg asks for one (once per Night).
static func maybe_attach(host: Node) -> ScriptProf3D:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with(ARG):
			path = a.substr(ARG.length())
	if path == "" or host == null:
		return null
	var p := ScriptProf3D.new()
	p.out_path = path
	p.world_view = host
	p.name = "ScriptProf3D"
	if "profile" in host:
		host.set("profile", true)
	for a in ["hush_view", "bellows_view"]:
		var cv: Variant = host.get(a) if a in host else null
		if cv is Object and "profile" in (cv as Object):
			(cv as Object).set("profile", true)
	var parent := host.get_parent()
	if parent != null:
		parent.add_child.call_deferred(p)
	return p


func _ready() -> void:
	night = get_parent()
	process_priority = 0


## A sentinel's stamp (µs).
func stamp(slot: int) -> void:
	_stamps[slot] = Time.get_ticks_usec()
	_stamp_frame[slot] = _frame


func _process(delta: float) -> void:
	if _armed:
		return
	_t += delta
	if _t >= ARM_S:
		_armed = true
		_arm.call_deferred()


func _new_slot() -> int:
	_stamps.append(0)
	_stamp_frame.append(-1)
	return _stamps.size() - 1


func _sentinel(slot: int, prio: int) -> Sentinel:
	var s := Sentinel.new()
	s.prof = self
	s.slot = slot
	s.process_priority = prio
	s.name = "ProfSentinel%d" % slot
	return s


func _arm() -> void:
	_slot_start = _new_slot()
	_slot_end = _new_slot()
	var a := _sentinel(_slot_start, -99)
	var z := _EndSentinel.new()
	z.prof = self
	z.slot = _slot_end
	z.process_priority = 899
	night.add_child(a)
	night.add_child(z)
	var found: Array[Node] = []
	_collect(get_tree().root, found)
	# the autoloads (and any other root child that does not hold the Night): "root:<name>", not in the "other" split
	for rc in get_tree().root.get_children():
		if rc != night and not rc.is_ancestor_of(night) and not found.has(rc) and not (rc is Sentinel):
			found.append(rc)
	for n in found:
		var sc0: Variant = n.get_script()
		var cname := String((sc0 as Script).get_global_name()) if sc0 is Script and WATCH.has(String((sc0 as Script).get_global_name())) else "root:" + String(n.name)
		var top := true
		var up := n.get_parent()
		while up != null:
			var sc: Variant = up.get_script()
			if sc is Script and WATCH.has(String((sc as Script).get_global_name())) and up.process_priority == n.process_priority:
				top = false
				break
			up = up.get_parent()
		var p := n.get_parent()
		if p == null:
			continue
		var sa := _new_slot()
		var sb := _new_slot()
		var i := n.get_index()
		p.add_child(_sentinel(sa, n.process_priority))
		p.move_child(p.get_child(p.get_child_count() - 1), i)
		p.add_child(_sentinel(sb, n.process_priority))
		p.move_child(p.get_child(p.get_child_count() - 1), n.get_index() + 1)
		var ci := _names.find(cname)
		if ci < 0:
			_names.append(cname)
			_nodes.append(0)
			ci = _names.size() - 1
		_nodes[ci] += 1
		_rows.append([ci, sa, sb, top, cname == "NightScene" or cname.begins_with("root:")])
	_ring.resize(CAP * _names.size())
	_cur.resize(_names.size())
	_tot.resize(CAP)
	_oth.resize(CAP)


func _collect(n: Node, out: Array[Node]) -> void:
	var sc: Variant = n.get_script()
	if sc is Script and WATCH.has(String((sc as Script).get_global_name())):
		out.append(n)
	for c in n.get_children():
		if not (c is Sentinel):
			_collect(c, out)


## Called by the end sentinel: folds this frame's stamps into the rings.
func end_frame() -> void:
	var f := _frame
	_frame += 1
	if night == null or not ("phase" in night) or int(night.get("phase")) != PHASE_PLAY:
		return
	if _stamp_frame[_slot_start] != f:
		return
	_cur.fill(0.0)
	var top_sum := 0.0
	for r in _rows:
		var sa: int = r[1]
		var sb: int = r[2]
		if _stamp_frame[sa] != f or _stamp_frame[sb] != f:
			continue
		var us := float(_stamps[sb] - _stamps[sa])
		var ci: int = r[0]
		_cur[ci] += us
		if bool(r[3]) and not bool(r[4]):
			top_sum += us
	var i := _n % CAP
	var total := float(_stamps[_slot_end] - _stamps[_slot_start])
	_tot[i] = total / 1000.0
	_oth[i] = (total - top_sum) / 1000.0
	for ci in _names.size():
		_ring[ci * CAP + i] = _cur[ci] / 1000.0
	if total / 1000.0 > _spike_min or _spikes.size() < SPIKES:
		var split := {"other": snappedf((total - top_sum) / 1000.0, 0.01)}
		for ci in _names.size():
			if _cur[ci] >= 200.0:
				split[_names[ci]] = snappedf(_cur[ci] / 1000.0, 0.01)
		if world_view != null and is_instance_valid(world_view) and "prof_frame_us" in world_view:
			var pf: PackedInt64Array = world_view.get("prof_frame_us")
			var wvs := {}
			for j in pf.size():
				if pf[j] >= 150:
					wvs[(WV_PHASES[j] if j < WV_PHASES.size() else "rest")] = snappedf(float(pf[j]) / 1000.0, 0.01)
			for a in ["hush_view", "bellows_view"]:
				var cv: Variant = world_view.get(a)
				if cv is Object and "prof_frame_us" in (cv as Object):
					var cf: PackedInt64Array = (cv as Object).get("prof_frame_us")
					if cf[3] >= 150:
						wvs[a + ".rig_advance"] = snappedf(float(cf[3]) / 1000.0, 0.01)
					if cf[0] + cf[1] + cf[2] >= 150:
						wvs[a + ".mine"] = snappedf(float(cf[0] + cf[1] + cf[2] - cf[4]) / 1000.0, 0.01)
						wvs[a + ".ctx"] = snappedf(float(cf[0]) / 1000.0, 0.01)
						wvs[a + ".place"] = snappedf(float(cf[1]) / 1000.0, 0.01)
					if cf[4] >= 150:
						wvs[a + ".rig_play"] = snappedf(float(cf[4]) / 1000.0, 0.01)
					if cf[5] >= 150:
						wvs[a + ".looks"] = snappedf(float(cf[5]) / 1000.0, 0.01)
			split["wv"] = wvs
		_spikes.append([snappedf(total / 1000.0, 0.01), f, split])
		_spikes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		if _spikes.size() > SPIKES:
			_spikes.resize(SPIKES)
		_spike_min = float(_spikes[_spikes.size() - 1][0]) if _spikes.size() >= SPIKES else 0.0
	_n += 1
	if _n % WRITE_EVERY == 0:
		write()


static func _stats(a: PackedFloat32Array, n: int) -> Dictionary:
	if n <= 0:
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	var s := a.slice(0, n)
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return {"mean": snappedf(sum / float(n), 0.001), "p50": snappedf(s[int(floor(float(n - 1) * 0.5 + 0.5))], 0.001),
		"p95": snappedf(s[int(floor(float(n - 1) * 0.95 + 0.5))], 0.001), "max": snappedf(s[n - 1], 0.001)}


## Writes the JSON now.
func write() -> void:
	if out_path == "":
		return
	var n := mini(_n, CAP)
	var classes := {}
	for ci in _names.size():
		var d := ScriptProf3D._stats(_ring.slice(ci * CAP, ci * CAP + CAP), n)
		d["nodes"] = _nodes[ci]
		classes[_names[ci]] = d
	var wv := {}
	if world_view != null and is_instance_valid(world_view) and "prof_us" in world_view:
		var pu: PackedInt64Array = world_view.get("prof_us")
		var pf := maxi(1, int(world_view.get("prof_frames")))
		for j in mini(pu.size(), WV_PHASES.size()):
			wv[WV_PHASES[j]] = snappedf(float(pu[j]) / float(pf), 0.1)
	for a in ["hush_view", "bellows_view"]:
		var cv: Variant = world_view.get(a) if world_view != null and is_instance_valid(world_view) and a in world_view else null
		if cv is Object and "prof_us" in (cv as Object):
			var cu: PackedInt64Array = (cv as Object).get("prof_us")
			var cf := maxi(1, int((cv as Object).get("prof_frames")))
			wv[a + "_split"] = {"ctx_resolve": snappedf(float(cu[0]) / cf, 0.1), "place": snappedf(float(cu[1]) / cf, 0.1),
				"drive_no_advance": snappedf(float(cu[2]) / cf, 0.1), "rig_advance": snappedf(float(cu[3]) / cf, 0.1)}
	var out := {"frames": n, "total": ScriptProf3D._stats(_tot, n), "other": ScriptProf3D._stats(_oth, n),
		"classes": classes, "world_view_us_mean": wv, "spikes": _spikes}
	var fa := FileAccess.open(out_path, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(out, "  "))
		fa.close()


func _exit_tree() -> void:
	write()
