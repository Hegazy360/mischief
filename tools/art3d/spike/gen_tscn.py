"""Generate res://diorama/diorama.tscn from layout.json (written by build_diorama.py).
Usage: python3 gen_tscn.py <diorama_dir>
"""
import json, math, os, sys

D = sys.argv[1]
L = json.load(open(os.path.join(D, "layout.json")))


def f(v):
    s = ("%.5f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def xf_yaw(pos, yaw_deg, s=1.0):
    t = math.radians(yaw_deg)
    c, sn = math.cos(t), math.sin(t)
    # .tscn Transform3D(...) lists the basis ROWS, then the origin
    vals = [c * s, 0, sn * s, 0, s, 0, -sn * s, 0, c * s, *pos]
    return "Transform3D(%s)" % ", ".join(f(v) for v in vals)


def xf_dir(pos, d, up=(0, 1, 0)):
    """A light/camera looking along direction d (its -Z axis)."""
    n = math.sqrt(sum(x * x for x in d))
    z = [-x / n for x in d]
    x = [up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0]]
    nx = math.sqrt(sum(a * a for a in x))
    x = [a / nx for a in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    rows = (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])   # basis rows (columns are x, y, z)
    return "Transform3D(%s)" % ", ".join(f(v) for v in (*rows, *pos))


ext, nodes = [], []
ext.append('[ext_resource type="Script" path="res://diorama/diorama.gd" id="s_dio"]')
ext.append('[ext_resource type="Script" path="res://diorama/camera_rig.gd" id="s_cam"]')
for i, (name, p) in enumerate(L["pieces"].items()):
    ext.append('[ext_resource type="PackedScene" path="res://diorama/props/%s.glb" id="p_%s"]' % (name, name))

h = L["house"]
out = []
out.append('[gd_scene load_steps=%d format=3]\n' % (len(ext) + 2))
out += ext
out.append("")
out.append('[sub_resource type="Environment" id="env"]')
out.append("background_mode = 1")
out.append("background_color = Color(0.105, 0.08, 0.15, 1)")
out.append("ambient_light_source = 2")
out.append("ambient_light_color = Color(0.7, 0.64, 0.8, 1)")
out.append("ambient_light_energy = 0.36")
out.append("tonemap_mode = 0")
out.append("")
out.append('[node name="Diorama" type="Node3D"]')
out.append('script = ExtResource("s_dio")')
out.append("")
out.append('[node name="Set" type="Node3D" parent="."]')
out.append("")
for name, p in L["pieces"].items():
    out.append('[node name="%s" parent="Set" groups=["%s"] instance=ExtResource("p_%s")]' % (name, p["group"], name))
    out.append("transform = " + xf_yaw(p["pos"], p["rot_y"]))
    out.append("")
out.append('[node name="Marks" type="Node3D" parent="."]')
out.append("")
for name, m in L["marks"].items():
    out.append('[node name="%s" type="Marker3D" parent="Marks"]' % name)
    out.append("transform = " + xf_yaw(m["pos"], m["yaw"]))
    out.append("gizmo_extents = 0.3")
    out.append("")
out.append('[node name="Actors" type="Node3D" parent="."]')
out.append("")
out.append('[node name="Lights" type="Node3D" parent="."]')
out.append("")
out.append('[node name="Key" type="DirectionalLight3D" parent="Lights"]')
out.append("transform = " + xf_dir((5.6, 6.0, 4.0), (0.38, -0.62, -0.69)))
out.append("light_color = Color(1, 0.95, 0.87, 1)")
out.append("light_energy = 0.32")
out.append("shadow_enabled = true")
out.append("shadow_bias = 0.1")
out.append("shadow_normal_bias = 2.0")
out.append("shadow_blur = 0.6")
out.append("directional_shadow_mode = 0")
out.append("directional_shadow_max_distance = 30.0")
out.append("")
out.append('[node name="Fill" type="DirectionalLight3D" parent="Lights"]')
out.append("transform = " + xf_dir((5.6, 4.0, 6.0), (-0.55, -0.25, -0.8)))
out.append("light_color = Color(0.8, 0.86, 1, 1)")
out.append("light_energy = 0.1")
out.append("")
out.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]')
out.append('environment = SubResource("env")')
out.append("")
out.append('[node name="CameraRig" type="Node3D" parent="."]')
out.append('script = ExtResource("s_cam")')
out.append("x_min = %s" % f(h["x0"]))
out.append("x_max = %s" % f(h["x1"]))
out.append("lane_z = %s" % f(h["lane_z"]))
out.append("")
out.append('[node name="Camera3D" type="Camera3D" parent="CameraRig"]')
out.append("current = true")
out.append("fov = 28.0")
out.append("")
open(os.path.join(D, "diorama.tscn"), "w").write("\n".join(out))
print("wrote", os.path.join(D, "diorama.tscn"))
