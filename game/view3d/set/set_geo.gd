## SetGeo — the pure geometry of the 3D sets (R3D index R4/R5, §7.4): the prop frame, anchors in world space,
## hit boxes, the reach model of Hush's B arms, character capsules and their collisions with furniture.
##
## **The prop frame (index §7.4):** origin = (rect centre-x + `visual_offset.x`, rect bottom-y + `visual_offset.y`,
## the prop's `z`); a yaw about +y (degrees, 0 = the model faces the camera, +90 = faces +x); anchors and `bounds` in
## metres BEFORE `scale`; y up, +z toward the camera. World = origin + yaw · (local × scale).
##
## **Reach (R5b–c):** Hush stands at `reach_pos` (x = `use_x` + `dx`, z ≥ −1.6) side-on to the prop (rig clips reach at
## cheat ≤ 10°), so her shoulders sit at (x, y_sh, z ± 0.118); the nearer one is the one closer to the target. y_sh =
## 1.127 (+ 0.07 tiptoe in the high band) + `step_h`; in the low band she kneels (− `kneel_drop_m`, B's shin). A target
## is reachable iff that distance ≤ 0.50 m. The band comes from the target's world y (low 0–0.55, mid 0.55–1.40, high
## 1.40–2.15; above 1.70 m a step is required).
##
## **Capsules:** Hush r 0.15 m from her feet (+ step) to 1.60 m above them; Bellows' barrel r 0.45 m over y
## 0.45–1.30 (+ the seat lift at a seated station). Collisions test a vertical capsule against yawed boxes (OBB in
## the xz-plane + a y overlap), so a yawed mirror is not a fat AABB.
class_name SetGeo
extends RefCounted

const PX_PER_M := 200.0
const HOUSE3D_PATH := "res://data/house/house3d.json"
const DEFAULT_HIT_Z_HALF := 0.3

## Reach defaults (index R5b; house3d.json `reach` overrides).
const REACH_DEFAULTS := {
	"shoulder_y_m": 1.127, "shoulder_half_m": 0.118, "tiptoe_m": 0.07, "kneel_drop_m": 0.42, "max_m": 0.5,
	"bands": {"low": [0.0, 0.55], "mid": [0.55, 1.4], "high": [1.4, 2.15]}, "step_above_m": 1.7,
	"hush": {"radius_m": 0.15, "height_m": 1.6}, "bellows": {"radius_m": 0.45, "barrel_y_m": [0.45, 1.3]},
}

static var _cache: Dictionary = {}
static var _cache_path := ""


## Loads (and caches) house3d.json. Returns {} (and push_error) when missing or malformed.
static func load_house3d(path: String = HOUSE3D_PATH, reload: bool = false) -> Dictionary:
	if not reload and _cache_path == path and not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(path):
		push_error("SetGeo: %s missing" % path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SetGeo: %s is not a JSON object" % path)
		return {}
	_cache = parsed
	_cache_path = path
	return _cache


## Drops the cache (tests that edit a copy of the data).
static func clear_cache() -> void:
	_cache = {}
	_cache_path = ""


## The reach config (house3d.json `reach` merged over the defaults).
static func reach_cfg(house3d: Dictionary) -> Dictionary:
	var out := REACH_DEFAULTS.duplicate(true)
	var r: Dictionary = house3d.get("reach", {})
	for k in r.keys():
		out[k] = r[k]
	return out


# --- rects and the prop frame --------------------------------------------------------------

## A house.json rect [x, y_top, w, h] (px, y negative up) → Rect2 in metres (position = (x0, y_bottom), size = (w, h)),
## y up.
static func rect_m(rect: Array) -> Rect2:
	if rect.size() < 4:
		return Rect2()
	var x0 := float(rect[0]) / PX_PER_M
	var w := float(rect[2]) / PX_PER_M
	var h := float(rect[3]) / PX_PER_M
	var y_bottom := -(float(rect[1]) + float(rect[3])) / PX_PER_M
	return Rect2(x0, y_bottom, w, h)


## The prop-frame origin of a hotspot entry over its house.json rect.
static func prop_origin(rect: Array, entry: Dictionary) -> Vector3:
	var r := rect_m(rect)
	var vo := vec2(entry.get("visual_offset", null))
	return Vector3(r.position.x + r.size.x * 0.5 + vo.x, r.position.y + vo.y, float(entry.get("z", -1.8)))


## The yaw basis of an entry (degrees about +y).
static func basis_of(entry: Dictionary) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(float(entry.get("yaw", 0.0))))


## The prop transform (origin + yaw, scale applied to local points by `to_world`).
static func prop_xform(rect: Array, entry: Dictionary) -> Transform3D:
	return Transform3D(basis_of(entry), prop_origin(rect, entry))


## A local anchor (metres before scale) → world.
static func to_world(xf: Transform3D, entry: Dictionary, local: Vector3) -> Vector3:
	return xf.origin + xf.basis * (local * float(entry.get("scale", 1.0)))


## The local bounds AABB (before scale) of an entry (`bounds` [x0, y0, z0, x1, y1, z1]).
static func local_bounds(entry: Dictionary, key: String = "bounds") -> AABB:
	var b: Array = entry.get(key, entry.get("bounds", [-0.1, 0.0, -0.1, 0.1, 0.2, 0.1]))
	if b.size() < 6:
		return AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.2, 0.2, 0.2))
	var lo := Vector3(float(b[0]), float(b[1]), float(b[2]))
	var hi := Vector3(float(b[3]), float(b[4]), float(b[5]))
	return AABB(lo, hi - lo)


## The world AABB of the (yawed, scaled) local bounds.
static func world_aabb(xf: Transform3D, entry: Dictionary, key: String = "bounds") -> AABB:
	var lb := local_bounds(entry, key)
	var s := float(entry.get("scale", 1.0))
	var out := AABB(xf.origin + xf.basis * (lb.position * s), Vector3.ZERO)
	for i in 8:
		out = out.expand(xf.origin + xf.basis * (lb.get_endpoint(i) * s))
	return out


## The oriented box of an entry: {center: Vector3, half: Vector3 (world metres, in the yawed frame), yaw: float (rad)}.
static func world_obb(xf: Transform3D, entry: Dictionary, key: String = "bounds") -> Dictionary:
	var lb := local_bounds(entry, key)
	var s := float(entry.get("scale", 1.0))
	var c_local := (lb.position + lb.size * 0.5) * s
	return {"center": xf.origin + xf.basis * c_local, "half": lb.size * 0.5 * s,
		"yaw": deg_to_rad(float(entry.get("yaw", 0.0)))}


## The collision OBBs of an entry: one per `collide` local box (metres before scale) when given, else the bounds.
static func world_obbs(xf: Transform3D, entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var boxes: Array = entry.get("collide", [])
	if boxes.is_empty():
		out.append(world_obb(xf, entry))
		return out
	for b in boxes:
		out.append(world_obb(xf, {"bounds": b, "scale": entry.get("scale", 1.0), "yaw": entry.get("yaw", 0.0)}))
	return out


## An axis-aligned world box [x0, y0, z0, x1, y1, z1] as an OBB dictionary (yaw 0).
static func obb_from_box(b: Array, offset: Vector3 = Vector3.ZERO, yaw_deg: float = 0.0) -> Dictionary:
	var lo := Vector3(float(b[0]), float(b[1]), float(b[2]))
	var hi := Vector3(float(b[3]), float(b[4]), float(b[5]))
	var c := (lo + hi) * 0.5
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	return {"center": offset + basis * c, "half": (hi - lo) * 0.5, "yaw": deg_to_rad(yaw_deg)}


## An OBB dictionary → its world AABB.
static func obb_aabb(o: Dictionary) -> AABB:
	var c: Vector3 = o["center"]
	var h: Vector3 = o["half"]
	var basis := Basis(Vector3.UP, float(o.get("yaw", 0.0)))
	var out := AABB(c + basis * (-h), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out = out.expand(c + basis * Vector3(h.x * sx, h.y * sy, h.z * sz))
	return out


# --- hit boxes (R5a) --------------------------------------------------------------------------

## The hit box of a hotspot (what TapAssist and the screen-rect lint project): `hit_box` [x0, y0, x1, y1] m when
## given, else the rect's x/y moved by `visual_offset`; z = the prop's z ± `hit_z_half` (default 0.3).
static func hit_box(rect: Array, entry: Dictionary) -> AABB:
	var zc := float(entry.get("z", -1.8))
	var zh := float(entry.get("hit_z_half", DEFAULT_HIT_Z_HALF))
	var hb: Variant = entry.get("hit_box", null)
	if typeof(hb) == TYPE_ARRAY and (hb as Array).size() >= 4:
		var a: Array = hb
		return AABB(Vector3(float(a[0]), float(a[1]), zc - zh),
			Vector3(float(a[2]) - float(a[0]), float(a[3]) - float(a[1]), zh * 2.0))
	var r := rect_m(rect)
	var vo := vec2(entry.get("visual_offset", null))
	return AABB(Vector3(r.position.x + vo.x, r.position.y + vo.y, zc - zh), Vector3(r.size.x, r.size.y, zh * 2.0))


## True when `inner`'s x/y extent lies inside `outer`'s (± eps).
static func contains_xy(outer: AABB, inner: AABB, eps: float = 0.001) -> bool:
	return inner.position.x >= outer.position.x - eps and inner.position.y >= outer.position.y - eps \
		and inner.end.x <= outer.end.x + eps and inner.end.y <= outer.end.y + eps


# --- reach (R5b–c) ----------------------------------------------------------------------------

## The band of a world y: "low" | "mid" | "high" | "" (out of every band).
static func band_of(y: float, cfg: Dictionary) -> String:
	var bands: Dictionary = cfg.get("bands", REACH_DEFAULTS["bands"])
	for name in ["low", "mid", "high"]:
		var r: Array = bands.get(name, [])
		if r.size() >= 2 and y >= float(r[0]) - 1e-6 and y <= float(r[1]) + 1e-6:
			return name
	return ""


## Hush's stand point while rigging: (use_x + dx, step_h, z) and the step.
static func reach_stand(use_x_m: float, entry: Dictionary) -> Dictionary:
	var rp: Dictionary = entry.get("reach_pos", {})
	var z := float(rp.get("z", -1.6))
	return {"x": use_x_m + float(rp.get("dx", 0.0)), "z": z, "step": rp.get("step", null),
		"step_h": float(rp.get("step_h", 0.0))}


## The full reach record of a rig point: {target: Vector3, band, shoulder: Vector3, dist, ok, step, step_h,
## needs_step (target above step_above_m), stand: Vector3}.
static func reach_info(rect: Array, entry: Dictionary, use_x_m: float, cfg: Dictionary) -> Dictionary:
	var xf := prop_xform(rect, entry)
	var rt := vec3(entry.get("reach_target", null))
	var target := to_world(xf, entry, rt)
	var band := band_of(target.y, cfg)
	var st := reach_stand(use_x_m, entry)
	var y_sh := float(cfg.get("shoulder_y_m", 1.127)) + float(st["step_h"])
	if band == "high":
		y_sh += float(cfg.get("tiptoe_m", 0.07))
	elif band == "low":
		y_sh -= float(cfg.get("kneel_drop_m", 0.42))
	var half := float(cfg.get("shoulder_half_m", 0.118))
	var a := Vector3(float(st["x"]), y_sh, float(st["z"]) - half)
	var b := Vector3(float(st["x"]), y_sh, float(st["z"]) + half)
	var sh := a if a.distance_to(target) <= b.distance_to(target) else b
	var d := sh.distance_to(target)
	return {"target": target, "band": band, "shoulder": sh, "dist": d, "ok": d <= float(cfg.get("max_m", 0.5)) + 1e-6,
		"step": st["step"], "step_h": st["step_h"], "needs_step": target.y > float(cfg.get("step_above_m", 1.7)) + 1e-6,
		"stand": Vector3(float(st["x"]), float(st["step_h"]), float(st["z"]))}


# --- capsules and collisions -----------------------------------------------------------------

## A vertical capsule: {x, z, r, y0, y1, who}.
static func capsule(x: float, z: float, r: float, y0: float, y1: float, who: String = "") -> Dictionary:
	return {"x": x, "z": z, "r": r, "y0": y0, "y1": y1, "who": who}


## Hush's capsule standing at (x, z) on a step of height `step_h`.
static func hush_capsule(x: float, z: float, step_h: float, cfg: Dictionary) -> Dictionary:
	var h: Dictionary = cfg.get("hush", {})
	return capsule(x, z, float(h.get("radius_m", 0.15)), step_h, step_h + float(h.get("height_m", 1.6)), "hush")


## Bellows' barrel capsule at (x, z), lifted by `seat_lift` at a seated station.
static func bellows_capsule(x: float, z: float, seat_lift: float, cfg: Dictionary) -> Dictionary:
	var b: Dictionary = cfg.get("bellows", {})
	var yb: Array = b.get("barrel_y_m", [0.45, 1.3])
	return capsule(x, z, float(b.get("radius_m", 0.45)), float(yb[0]) + seat_lift, float(yb[1]) + seat_lift, "bellows")


## The penetration of a capsule into an OBB (> 0 = overlap, metres; ≤ 0 = clear by that much).
static func capsule_obb_depth(c: Dictionary, o: Dictionary) -> float:
	var ctr: Vector3 = o["center"]
	var h: Vector3 = o["half"]
	var y0 := float(c["y0"])
	var y1 := float(c["y1"])
	if y1 <= ctr.y - h.y or y0 >= ctr.y + h.y:
		return -1.0
	var yaw := float(o.get("yaw", 0.0))
	var dx := float(c["x"]) - ctr.x
	var dz := float(c["z"]) - ctr.z
	# rotate the circle centre into the box frame (inverse yaw about +y)
	var cs := cos(-yaw)
	var sn := sin(-yaw)
	var lx := cs * dx + sn * dz
	var lz := -sn * dx + cs * dz
	var qx := clampf(lx, -h.x, h.x)
	var qz := clampf(lz, -h.z, h.z)
	var dist := Vector2(lx - qx, lz - qz).length()
	return float(c["r"]) - dist


## True when a capsule overlaps an OBB by more than `tol` metres.
static func capsule_hits(c: Dictionary, o: Dictionary, tol: float = 0.0) -> bool:
	return capsule_obb_depth(c, o) > tol


# --- small parsing helpers ------------------------------------------------------------------

## A JSON value as a String ("" for null).
static func s(v: Variant) -> String:
	return "" if v == null else str(v)


static func vec2(v: Variant) -> Vector2:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


static func vec3(v: Variant) -> Vector3:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


static func color(v: Variant, fallback: Color = Color(0.7, 0.7, 0.7)) -> Color:
	if typeof(v) == TYPE_STRING and String(v).begins_with("#"):
		return Color(String(v))
	return fallback
