## SetPrims — greybox primitives for the 3D sets (the P0 stand-ins and the fallback whenever a set `.glb` is missing).
## Each silhouette family of REDESIGN §3.6 gets a few coloured primitives inside the entry's `bounds` (local metres
## before scale), so a greybox already reads as its family at 64 px. Materials come from `SetMats`.
class_name SetPrims
extends RefCounted


## Builds the primitive of `family` under `parent` (local prop frame). `col` = the main colour; `kind` = &"prop"
## (vinyl + glow) or &"set" (neutral). Returns the MeshInstance3D list (the caller adds ink/halo shells).
static func build(parent: Node3D, family: String, bounds: AABB, col: Color, kind: StringName, mats: SetMats) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var lo := bounds.position
	var sz := bounds.size
	var c := lo + sz * 0.5
	var dark := col.darkened(0.45)
	match family:
		"squat_jar":
			var r := minf(sz.z, 0.16) * 0.5
			out.append(_cyl(parent, r, r, 0.11, Vector3(0.0, 0.055, 0.0), mats.get_mat(col, kind)))
			out.append(_cyl(parent, r * 1.05, r * 1.05, 0.022, Vector3(0.0, 0.121, 0.0), mats.get_mat(Color("#E23B4E"), kind), "lid"))
			out.append(_cyl(parent, 0.035, 0.045, 0.2, Vector3(lo.x + 0.045, 0.1, 0.0), mats.get_mat(Color("#F4F1EA"), kind), "pepper_pot"))
			out.append(_ball(parent, 0.045, Vector3(lo.x + 0.045, 0.215, 0.0), mats.get_mat(Color("#2A2D36"), kind), Vector3.ONE, "pepper_pot_cap"))
		"round_kettle":
			out.append(_ball(parent, 0.11, Vector3(0.0, 0.1, 0.0), mats.get_mat(col, kind), Vector3(1.0, 0.85, 1.0)))
			out.append(_cyl(parent, 0.018, 0.03, 0.12, Vector3(lo.x + 0.06, 0.11, 0.0), mats.get_mat(col, kind), "spout", Vector3(0, 0, 55)))
			out.append(_torus(parent, 0.06, 0.075, Vector3(0.0, 0.2, 0.0), mats.get_mat(dark, kind), Vector3(90, 0, 0), "handle"))
			out.append(_cyl(parent, 0.05, 0.05, 0.015, Vector3(0.0, 0.19, 0.0), mats.get_mat(dark, kind), "lid"))
		"tall_jar":
			var rj := sz.x * 0.5
			out.append(_cyl(parent, rj, rj, sz.y * 0.85, Vector3(0.0, sz.y * 0.425, 0.0), mats.get_mat(col, kind)))
			out.append(_cyl(parent, rj * 1.05, rj * 1.05, sz.y * 0.13, Vector3(0.0, sz.y * 0.915, 0.0), mats.get_mat(Color("#E8B33A"), kind), "lid"))
			for i in 3:
				out.append(_ball(parent, rj * 0.35, Vector3(-rj * 0.4 + i * rj * 0.4, sz.y * (0.25 + 0.2 * (i % 2)), rj * 0.55),
					mats.get_mat(Color("#F3F0E2"), kind)))
		"gooseneck_tap":
			var bx := hi_x(bounds) - 0.03
			out.append(_cyl(parent, 0.018, 0.024, sz.y * 0.8, Vector3(bx, sz.y * 0.4, 0.0), mats.get_mat(col, kind)))
			out.append(_cyl(parent, 0.016, 0.016, sz.x * 0.85, Vector3(bx - sz.x * 0.42, sz.y * 0.8, 0.0), mats.get_mat(col, kind), "arm", Vector3(0, 0, 90)))
			out.append(_cyl(parent, 0.02, 0.012, 0.06, Vector3(lo.x + 0.02, sz.y * 0.72, 0.0), mats.get_mat(col, kind), "head"))
			out.append(_ball(parent, 0.028, Vector3(bx, sz.y * 0.35, 0.05), mats.get_mat(Color("#3D7BD9"), kind), Vector3.ONE, "knob"))
		"tall_rounded_box":
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.0))
			out.append(_box(parent, Vector3(sz.x * 0.96, 0.03, 0.02), Vector3(0.0, 1.24, hi_z(bounds) + 0.005), mats.get_mat(dark, kind), 0.0, "split"))
			out.append(_box(parent, Vector3(0.04, 0.5, 0.04), Vector3(hi_x(bounds) - 0.08, 0.75, hi_z(bounds) + 0.03), mats.get_mat(Color("#D8DEE4"), kind), 0.0, "handle"))
			out.append(_box(parent, Vector3(0.04, 0.3, 0.04), Vector3(hi_x(bounds) - 0.08, 1.55, hi_z(bounds) + 0.03), mats.get_mat(Color("#D8DEE4"), kind), 0.0, "handle_top"))
		"arched_alcove":
			out.append(_box(parent, Vector3(sz.x, sz.y, 0.06), Vector3(0.0, sz.y * 0.5, lo.z + 0.03), mats.get_mat(Color("#1D1826"), &"set"), 0.0, "alcove"))
			out.append(_box(parent, Vector3(0.08, sz.y, sz.z), Vector3(lo.x + 0.04, sz.y * 0.5, c.z), mats.get_mat(Color("#8C7657"), &"set"), 0.0, "jamb_l"))
			out.append(_box(parent, Vector3(0.08, sz.y, sz.z), Vector3(hi_x(bounds) - 0.04, sz.y * 0.5, c.z), mats.get_mat(Color("#8C7657"), &"set"), 0.0, "jamb_r"))
			out.append(_box(parent, Vector3(sz.x, 0.1, sz.z), Vector3(0.0, sz.y - 0.05, c.z), mats.get_mat(Color("#8C7657"), &"set"), 0.0, "lintel"))
			var cw := sz.x - 0.16
			for i in 5:
				out.append(_capsule(parent, cw / 10.0 + 0.012, 1.6, Vector3(-cw * 0.5 + cw * (i + 0.5) / 5.0, 0.86, hi_z(bounds) - 0.05), mats.get_mat(col, kind), "curtain_%d" % i))
		"big_horn":
			out.append(_box(parent, Vector3(0.34, 0.47, 0.3), Vector3(0.02, 0.235, -0.0), mats.get_mat(Color("#7A4E34"), kind), 0.0, "cabinet"))
			out.append(_box(parent, Vector3(0.32, 0.13, 0.28), Vector3(0.02, 0.535, 0.0), mats.get_mat(Color("#5A3A28"), kind), 0.0, "box"))
			out.append(_cyl(parent, 0.14, 0.012, 0.42, Vector3(0.06, 0.86, -0.03), mats.get_mat(col, kind), "horn", Vector3(0, 0, -18)))
			out.append(_cyl(parent, 0.012, 0.012, 0.16, Vector3(-0.133, 0.6, 0.2), mats.get_mat(Color("#3A2A22"), kind), "lever"))
			out.append(_ball(parent, 0.035, Vector3(-0.133, 0.667, 0.217), mats.get_mat(Color("#E23B4E"), kind), Vector3.ONE, "knob"))
		"tall_wardrobe":
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.0))
			out.append(_box(parent, Vector3(0.012, sz.y * 0.86, 0.01), Vector3(0.04, sz.y * 0.47, hi_z(bounds) + 0.004), mats.get_mat(Color("#141018"), kind), 0.0, "door_line"))
			out.append(_box(parent, Vector3(sz.x * 1.04, 0.07, sz.z * 1.04), Vector3(0.0, sz.y - 0.035, c.z), mats.get_mat(col.darkened(0.25), kind), 0.0, "cornice"))
			out.append(_ball(parent, 0.025, Vector3(0.1, sz.y * 0.5, hi_z(bounds) + 0.01), mats.get_mat(Color("#D9B45A"), kind), Vector3.ONE, "knob"))
		"upright_block":
			out.append(_box(parent, Vector3(sz.x, 1.05, 0.48), Vector3(0.0, 0.525, hi_z(bounds) - 0.24), mats.get_mat(col, kind), 0.0))
			out.append(_box(parent, Vector3(sz.x * 0.9, 0.06, 0.16), Vector3(0.0, 0.72, hi_z(bounds) + 0.02), mats.get_mat(Color("#EDE6D2"), kind), 0.0, "keys"))
			out.append(_box(parent, Vector3(sz.x * 0.5, 0.15, 0.03), Vector3(0.0, 1.12, hi_z(bounds) - 0.3), mats.get_mat(Color("#3A3140"), kind), 0.0, "music_desk"))
		"fat_armchair":
			out.append(_box(parent, Vector3(sz.x, 0.42, sz.z), Vector3(0.0, 0.21, c.z), mats.get_mat(col, kind), 0.0))
			out.append(_box(parent, Vector3(sz.x, 0.55, 0.18), Vector3(0.0, 0.67, lo.z + 0.09), mats.get_mat(col, kind), 0.0, "back", Vector3(-12, 0, 0)))
			out.append(_box(parent, Vector3(0.14, 0.2, sz.z), Vector3(lo.x + 0.07, 0.52, c.z), mats.get_mat(col.darkened(0.15), kind), 0.0, "arm_l"))
			out.append(_box(parent, Vector3(0.14, 0.2, sz.z), Vector3(hi_x(bounds) - 0.07, 0.52, c.z), mats.get_mat(col.darkened(0.15), kind), 0.0, "arm_r"))
			out.append(_cyl(parent, 0.012, 0.012, 0.1, Vector3(0.1, 0.28, hi_z(bounds) - 0.02), mats.get_mat(Color("#D9B45A"), kind), "key", Vector3(90, 0, 0)))
		"folded_broadsheet":
			out.append(_box(parent, Vector3(sz.x, sz.y, 0.02), c, mats.get_mat(col, kind), 0.0, "paper", Vector3(-20, 0, 0)))
			out.append(_box(parent, Vector3(sz.x * 0.8, sz.y * 0.15, 0.021), c + Vector3(0.0, sz.y * 0.25, 0.0), mats.get_mat(Color("#8C8578"), kind), 0.0, "headline", Vector3(-20, 0, 0)))
		"banded_crate":
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.01))
			out.append(_box(parent, Vector3(sz.x * 1.01, sz.y * 0.22, sz.z * 1.01), c, mats.get_mat(Color("#D23A3A"), kind), 0.0, "band"))
		"candlestick_phone":
			out.append(_cyl(parent, 0.07, 0.08, 0.03, Vector3(0.0, 0.015, 0.0), mats.get_mat(col, kind)))
			out.append(_cyl(parent, 0.016, 0.02, 0.22, Vector3(0.0, 0.14, 0.0), mats.get_mat(col, kind), "stem"))
			out.append(_cyl(parent, 0.04, 0.02, 0.05, Vector3(0.0, 0.27, 0.02), mats.get_mat(col, kind), "mouthpiece", Vector3(-60, 0, 0)))
			out.append(_cyl(parent, 0.022, 0.022, 0.11, Vector3(0.07, 0.19, 0.03), mats.get_mat(Color("#141A22"), kind), "handset"))
		"oval_on_stand":
			out.append(_torus(parent, 0.3, 0.36, Vector3(0.0, 1.35, 0.0), mats.get_mat(col, kind), Vector3(90, 0, 0), "frame", Vector3(1.0, 1.0, 1.55)))
			out.append(_box(parent, Vector3(0.5, 0.9, 0.01), Vector3(0.0, 1.35, 0.0), mats.get_mat(Color("#BFD6E0"), kind), 0.0, "pane"))
			out.append(_box(parent, Vector3(0.05, 0.9, 0.05), Vector3(-0.3, 0.45, 0.0), mats.get_mat(dark, kind), 0.0, "leg_l"))
			out.append(_box(parent, Vector3(0.05, 0.9, 0.05), Vector3(0.3, 0.45, 0.0), mats.get_mat(dark, kind), 0.0, "leg_r"))
			out.append(_box(parent, Vector3(0.72, 0.05, 0.34), Vector3(0.0, 0.025, 0.0), mats.get_mat(dark, kind), 0.0, "base"))
		"tall_case_clock":
			out.append(_box(parent, Vector3(sz.x, sz.y - 0.05, 0.36), Vector3(0.0, (sz.y - 0.05) * 0.5, lo.z + 0.18), mats.get_mat(col, kind), 0.01))
			out.append(_cyl(parent, 0.21, 0.21, 0.04, Vector3(0.0, 2.05, hi_z(bounds) - 0.02), mats.get_mat(Color("#F2E8CF"), kind), "face", Vector3(90, 0, 0)))
			out.append(_box(parent, Vector3(0.2, 0.7, 0.02), Vector3(0.0, 0.9, lo.z + 0.37), mats.get_mat(col.darkened(0.25), kind), 0.0, "pendulum_door"))
		"chandelier":
			out.append(_torus(parent, 0.3, 0.36, Vector3(0.0, 0.2, 0.0), mats.get_mat(col, kind), Vector3.ZERO, "ring"))
			out.append(_cyl(parent, 0.01, 0.01, 0.55, Vector3(0.0, 0.5, 0.0), mats.get_mat(dark, kind), "chain"))
			for i in 4:
				var a := TAU * i / 4.0
				out.append(_cyl(parent, 0.02, 0.02, 0.1, Vector3(cos(a) * 0.33, 0.28, sin(a) * 0.33), mats.get_mat(Color("#F4EBD8"), kind)))
		"door_leaf":
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.0, "leaf"))
		"stool":
			out.append(_cyl(parent, sz.x * 0.5, sz.x * 0.5, 0.05, Vector3(0.0, sz.y - 0.025, 0.0), mats.get_mat(col, kind), "seat"))
			for i in 3:
				var a2 := TAU * i / 3.0
				out.append(_cyl(parent, 0.018, 0.022, sz.y - 0.05, Vector3(cos(a2) * sz.x * 0.3, (sz.y - 0.05) * 0.5, sin(a2) * sz.x * 0.3),
					mats.get_mat(col.darkened(0.2), kind), "leg_%d" % i))
		"table":
			out.append(_box(parent, Vector3(sz.x, 0.04, sz.z), Vector3(c.x, sz.y - 0.02, c.z), mats.get_mat(col, kind), 0.0, "top"))
			out.append(_cyl(parent, 0.03, 0.05, sz.y - 0.04, Vector3(c.x, (sz.y - 0.04) * 0.5, c.z), mats.get_mat(col.darkened(0.2), kind), "leg"))
		"window":
			out.append(_box(parent, Vector3(sz.x, sz.y, 0.04), c, mats.get_mat(col, kind), 0.0, "frame"))
			out.append(_box(parent, Vector3(sz.x - 0.12, sz.y - 0.12, 0.045), c, mats.get_mat(Color(0.66, 0.83, 0.91, 0.3), kind), 0.0, "pane"))
		"lamp":
			out.append(_cyl(parent, 0.008, 0.008, sz.y, Vector3(0.0, sz.y * 0.5 + 0.2, 0.0), mats.get_mat(Color("#3A3050"), kind), "cord"))
			out.append(_cyl(parent, 0.06, sz.x * 0.5, 0.2, Vector3(0.0, 0.1, 0.0), mats.get_mat(col, kind), "shade"))
		"pan_rail":
			out.append(_box(parent, Vector3(sz.x, 0.03, 0.03), Vector3(0.0, sz.y - 0.02, 0.0), mats.get_mat(col.darkened(0.2), kind), 0.0, "rail"))
			for i in 3:
				out.append(_cyl(parent, 0.11 - i * 0.015, 0.11 - i * 0.015, 0.03, Vector3(-0.25 + i * 0.25, sz.y - 0.18 - i * 0.03, 0.0),
					mats.get_mat(col, kind), "pan_%d" % i, Vector3(90, 0, 0)))
		"frame":
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.0, "frame"))
			out.append(_box(parent, Vector3(sz.x - 0.12, sz.y - 0.12, sz.z * 1.1), c, mats.get_mat(col.lightened(0.12), kind), 0.0, "canvas"))
		"basket":
			out.append(_cyl(parent, sz.x * 0.5, sz.x * 0.44, sz.y, Vector3(0.0, sz.y * 0.5, 0.0), mats.get_mat(col, kind), "basket"))
		"coat_stand":
			out.append(_cyl(parent, 0.025, 0.025, sz.y, Vector3(0.0, sz.y * 0.5, 0.0), mats.get_mat(col, kind), "pole"))
			out.append(_cyl(parent, sz.x * 0.5, sz.x * 0.5, 0.04, Vector3(0.0, 0.02, 0.0), mats.get_mat(col, kind), "foot"))
		"hats":
			out.append(_cyl(parent, 0.14, 0.16, 0.05, Vector3(-0.12, 0.03, 0.0), mats.get_mat(col, kind), "hat_a"))
			out.append(_cyl(parent, 0.09, 0.1, 0.14, Vector3(-0.12, 0.12, 0.0), mats.get_mat(col, kind), "crown_a"))
			out.append(_ball(parent, 0.1, Vector3(0.14, 0.1, 0.0), mats.get_mat(col.darkened(0.1), kind), Vector3(1.2, 0.8, 1.2), "hat_b"))
		"vase":
			out.append(_cyl(parent, sz.x * 0.3, sz.x * 0.45, sz.y * 0.7, Vector3(0.0, sz.y * 0.35, 0.0), mats.get_mat(col, kind), "body"))
			out.append(_cyl(parent, sz.x * 0.4, sz.x * 0.22, sz.y * 0.3, Vector3(0.0, sz.y * 0.85, 0.0), mats.get_mat(col, kind), "neck"))
		"shards":
			for i in 4:
				out.append(_box(parent, Vector3(0.1, 0.05, 0.08), Vector3(-0.2 + i * 0.13, 0.025, (i % 2) * 0.05), mats.get_mat(col, kind), 0.0,
					"shard_%d" % i, Vector3(0, i * 37, 0)))
		"fire":
			out.append(_ball(parent, sz.x * 0.35, Vector3(0.0, sz.y * 0.3, 0.0), mats.get_mat(Color(1.0, 0.55, 0.22, 0.2), kind), Vector3(1.4, 1.0, 0.6), "flames"))
		"door_glow":
			out.append(_box(parent, sz, c, mats.get_mat(Color(1.0, 0.96, 0.86, 0.3), kind), 0.0, "glow"))
		_:
			out.append(_box(parent, sz, c, mats.get_mat(col, kind), 0.0))
	return out


static func hi_x(b: AABB) -> float:
	return b.position.x + b.size.x


static func hi_z(b: AABB) -> float:
	return b.position.z + b.size.z


# --- mesh helpers -------------------------------------------------------------------------------

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, name: String, rot_deg: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, _bevel: float = 0.0, name: String = "",
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size.max(Vector3(0.002, 0.002, 0.002))
	return _mi(parent, b, m, pos, name, rot_deg)


static func _cyl(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, m: Material, name: String = "",
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 20
	c.rings = 1
	return _mi(parent, c, m, pos, name, rot_deg)


static func _ball(parent: Node3D, r: float, pos: Vector3, m: Material, scl: Vector3 = Vector3.ONE, name: String = "") -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return _mi(parent, s, m, pos, name, Vector3.ZERO, scl)


static func _torus(parent: Node3D, ri: float, ro: float, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO,
		name: String = "", scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 24
	t.ring_segments = 8
	return _mi(parent, t, m, pos, name, rot_deg, scl)


static func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, name: String = "") -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return _mi(parent, c, m, pos, name)
