## ReachMatrix — the reach accuracy instrument (docs/research/animation.md §4, phase 4): runs a rig's work
## clip against every container / rig point in house.json, each facing, through the REAL RigPlayer
## (clip reach + posture), headless, and scores each cell: how close the gloves get to the grab point,
## whether that needed a hop / crouch, and the worst per-frame arm joint jump (an elbow pop).
##   var rows := ReachMatrix.run("hush")      # Array[Dictionary], one per hotspot × facing
##   ReachMatrix.csv(rows)                    # a CSV string (tools/anim/reach_matrix_tool.gd writes it)
## Row: {hotspot, kind, facing, clip, best_px (gloves' midpoint → target, min over a loop after settling),
##       at_contact_px (at the clip's contact frame), posture, hop_px, crouch, max_joint_deg (per frame),
##       base_joint_deg (the same clip with NO target: the authored motion's own fastest joint), status:
##       reached | touch (needed the hop / crouch) | short | pop (a joint jumps POP_DEG more than authored)}.
class_name ReachMatrix
extends RefCounted

const DT := 1.0 / 60.0
const SETTLE_F := 90
const REACHED_PX := 6.0
const TOUCH_PX := 20.0
## A cell is a `pop` when an arm joint's fastest per-frame change exceeds the authored clip's own by this
## much (wrapped degrees): the reach introduced a snap the animator did not.
const POP_DEG := 25.0
const ARM_PARTS: PackedStringArray = ["arm_upper_r", "arm_lower_r", "arm_upper_l", "arm_lower_l"]


## The clip a rig plays at a hotspot kind (its map's work clips).
static func clip_for(rig_id: String, kind: String) -> String:
	if rig_id == "hush":
		return "hush/act_rummage" if kind == "container" else "hush/act_tinker_q"
	return ""


## Runs every container / rig point × facing for `rig_id` (a SceneTree root is needed for the player:
## pass `parent`, e.g. the test's tree.root). `only` limits the hotspot ids.
static func run(rig_id: String, parent: Node, only: PackedStringArray = PackedStringArray()) -> Array:
	var lay := HouseLayout.load_default()
	var rows: Array = []
	for h in lay.hotspots:
		if h.kind != "container" and h.kind != "rig_point":
			continue
		if not only.is_empty() and not only.has(h.id):
			continue
		var cid := clip_for(rig_id, h.kind)
		if cid == "" or ClipLib.get_clip(cid) == null:
			continue
		for f in [1, -1]:
			rows.append(_cell(rig_id, parent, lay, h, f, cid))
	return rows


static func _cell(rig_id: String, parent: Node, lay: HouseLayout, h: HouseLayout.Hotspot, facing: int, cid: String) -> Dictionary:
	var c := ClipLib.get_clip(cid)
	var base_jump := _authored_jump(rig_id, parent, cid, facing)
	var p := RigPlayer.new()
	p.configure_for_tools()
	p.springs_enabled = false
	parent.add_child(p)
	p.setup(rig_id)
	p.position = Vector2(h.use_x, lay.room_floor_y(h.room))
	p.set_facing(facing, false)
	p.play(cid, {"blend_in": 0})
	var target := h.grab_for(facing)
	p.set_target("grab", target)
	for i in SETTLE_F:
		p.advance(DT)
	var best := INF
	var at_contact := INF
	var max_jump := 0.0
	var prev := PackedFloat32Array()
	var hop := 0.0
	var crouch := 0.0
	var posture := 0.0
	var start := p.current_frame()
	for i in c.length:
		p.advance(DT)
		var mid := _mid(p)
		var d := mid.distance_to(target)
		best = minf(best, d)
		var cf := fposmod(p.current_frame(), float(maxi(1, c.length)))
		if absf(cf - float(c.reach_ref_f)) < 0.6:
			at_contact = minf(at_contact, d)
		var cur := PackedFloat32Array()
		for part in ARM_PARTS:
			cur.append(p.pose_buffer()[RigDef.ch(p.rig.idx(part), RigDef.C_ROT)])
		if not prev.is_empty():
			for k in cur.size():
				max_jump = maxf(max_jump, absf(wrapf(cur[k] - prev[k], -180.0, 180.0)))
		prev = cur
		var info := p.posture_info()
		hop = maxf(hop, info.z)
		posture = maxf(posture, info.x)
		crouch = maxf(crouch, p.crouch_weight())
	p.free()
	var status := "reached" if best <= REACHED_PX else ("touch" if best <= TOUCH_PX else "short")
	if max_jump - base_jump > POP_DEG:
		status = "pop"
	return {"hotspot": h.id, "kind": h.kind, "facing": facing, "clip": cid, "best_px": snappedf(best, 0.1),
		"at_contact_px": snappedf(at_contact, 0.1) if at_contact < INF else -1.0, "posture": snappedf(posture, 0.01),
		"hop_px": snappedf(hop, 0.1), "crouch": snappedf(crouch, 0.01), "max_joint_deg": snappedf(max_jump, 0.1),
		"base_joint_deg": snappedf(base_jump, 0.1), "status": status, "_start": start}


## The authored clip's own fastest per-frame arm joint change (no target), cached per clip × facing.
static var _base_cache: Dictionary = {}

static func _authored_jump(rig_id: String, parent: Node, cid: String, facing: int) -> float:
	var key := "%s|%s|%d" % [rig_id, cid, facing]
	if _base_cache.has(key):
		return float(_base_cache[key])
	var c := ClipLib.get_clip(cid)
	var p := RigPlayer.new()
	p.configure_for_tools()
	p.springs_enabled = false
	parent.add_child(p)
	p.setup(rig_id)
	p.set_facing(facing, false)
	p.play(cid, {"blend_in": 0})
	var prev := PackedFloat32Array()
	var mx := 0.0
	for i in c.length + 2:
		p.advance(DT)
		var cur := PackedFloat32Array()
		for part in ARM_PARTS:
			cur.append(p.pose_buffer()[RigDef.ch(p.rig.idx(part), RigDef.C_ROT)])
		if not prev.is_empty():
			for k in cur.size():
				mx = maxf(mx, absf(wrapf(cur[k] - prev[k], -180.0, 180.0)))
		prev = cur
	p.free()
	_base_cache[key] = mx
	return mx


static func _mid(p: RigPlayer) -> Vector2:
	return (p.socket_global_transform("hand_r:grip").origin + p.socket_global_transform("hand_l:grip").origin) * 0.5


## CSV of `rows` (header first).
static func csv(rows: Array) -> String:
	var cols: PackedStringArray = ["hotspot", "kind", "facing", "clip", "best_px", "at_contact_px", "posture", "hop_px", "crouch", "max_joint_deg", "base_joint_deg", "status"]
	var out := PackedStringArray([",".join(cols)])
	for r in rows:
		var cells := PackedStringArray()
		for k in cols:
			cells.append(str(r[k]))
		out.append(",".join(cells))
	return "\n".join(out)


## Counts per status.
static func summary(rows: Array) -> Dictionary:
	var d := {}
	for r in rows:
		d[r["status"]] = int(d.get(r["status"], 0)) + 1
	return d
