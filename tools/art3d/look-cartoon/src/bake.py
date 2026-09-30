"""UV-map the joined character, compute the decal UV2, and bake data maps for the numpy painter.

blender -b --python bake.py -- --who hush --dir <dir> [--size 1024] [--ao 1]
In:  <dir>/<who>_geo.blend, <who>_meta.json
Out: <dir>/<who>_uv.blend (UVMap + UVDecal), <dir>/<who>_maps.npz (pos, nrm, reg, grp, part, ao; image rows top-down)

Texture layout (image space, 1024 px, rows from the top):
  rows   0-127  mouth decal cells (8 x 128)      rows 128-255  eye decal cells (8 x 128)
  rows 256-767, cols   0-511   head block (head skin, eyes, lids, brows, hair, hat)
  rows 256-1023, cols 512-1023 body block
  rows 768-1023, cols   0-511  small parts (hands, shoes, rings, props)
UVDecal (TEXCOORD_1): head skin -> mouth window [0,1]^2 (back of the head +10 in u); eyeballs -> [2,3]x[0,1]
(back +10); everything else (-5,-5). v here is IMAGE-down (Godot UV convention); Blender stores 1-v.
"""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clib

argv = sys.argv[sys.argv.index("--") + 1:]
opt = {argv[i].lstrip("-"): argv[i + 1] for i in range(0, len(argv) - 1, 2)}
WHO = opt["who"]
D = opt["dir"]
S = int(opt.get("size", "1024"))
bpy.ops.wm.open_mainfile(filepath=os.path.join(D, WHO + "_geo.blend"))
meta = json.load(open(os.path.join(D, WHO + "_meta.json")))
arm = bpy.data.objects["Armature"]
char = [o for o in bpy.data.objects if o.type == "MESH"][0]
arm.data.pose_position = "REST"
me = char.data

print("STAGE uv", flush=True)
# ---- UVs -----------------------------------------------------------------------------------------
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
uv = me.uv_layers.new(name="UVMap")
grp = clib.face_int(char, "group")
BLOCK = {0: (0.0, 0.25, 0.5, 0.75), 1: (0.5, 0.0, 1.0, 0.75), 2: (0.0, 0.0, 0.5, 0.25)}   # blender uv (u0, v0, u1, v1)
clib.set_mode(char, "EDIT")
for g in (0, 1, 2):
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(me)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        f.select = bool(grp[f.index] == g)
    bmesh.update_edit_mesh(me)
    print("SMART", g, flush=True)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.014, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    uvd = me.uv_layers["UVMap"].data
    u0, v0, u1, v1 = BLOCK[g]
    for p in me.polygons:
        if grp[p.index] != g:
            continue
        for li in p.loop_indices:
            x, y = uvd[li].uv
            # small inset so islands never touch a block edge
            uvd[li].uv = (u0 + (u1 - u0) * (0.004 + 0.992 * x), v0 + (v1 - v0) * (0.004 + 0.992 * y))
    bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.object.mode_set(mode="OBJECT")

print("STAGE uv2", flush=True)
# ---- decal UV2 -------------------------------------------------------------------------------------
uv2 = me.uv_layers.new(name="UVDecal")
part = clib.face_int(char, "part")
mc = Vector(meta["mouth_c"])
mw = meta["mouth_w"]
hc = Vector(meta["head_c"])
er = meta["eye_r"]
IRIS = 1.0 / (2 * er * 0.98)    # eye window = the eyeball's front disc
me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
for p in me.polygons:
    for li in p.loop_indices:
        vi = me.loops[li].vertex_index
        co = me.vertices[vi].co
        n = me.vertices[vi].normal
        if part[p.index] == 1:
            u = 0.5 + (co.x - mc.x) / mw
            vimg = 0.5 - (co.z - mc.z) / mw
            if co.y > hc.y - 0.04 or n.y > 0.35:
                u += 10.0
        elif part[p.index] in (2, 3):
            ec = Vector(meta["eye_c"]["l" if part[p.index] == 2 else "r"])
            u = 2.5 + (co.x - ec.x) * IRIS
            vimg = 0.5 - (co.z - ec.z) * IRIS
            if co.y > ec.y:
                u += 10.0
        else:
            u, vimg = -5.0, -5.0
        uv2.data[li].uv = (u, 1.0 - vimg)
me.uv_layers.active = me.uv_layers["UVMap"]
me.uv_layers["UVMap"].active_render = True

print("STAGE bake", flush=True)
# ---- bake data maps ---------------------------------------------------------------------------------
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 1
sc.render.bake.margin = 14
sc.render.bake.margin_type = "EXTEND"
sc.render.bake.use_clear = True
mat = bpy.data.materials.new("bake")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
emi = nt.nodes.new("ShaderNodeEmission")
nt.links.new(emi.outputs[0], out.inputs[0])
tex = nt.nodes.new("ShaderNodeTexImage")
nt.nodes.active = tex
geo = nt.nodes.new("ShaderNodeNewGeometry")
me.materials.clear()
me.materials.append(mat)
clib.set_mode(char, "OBJECT")


def bake_to(name, src_socket, size=S, kind="EMIT", samples=1):
    img = bpy.data.images.new(name, size, size, float_buffer=True, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    tex.image = img
    for l in list(nt.links):
        if l.to_node == emi:
            nt.links.remove(l)
    if src_socket is not None:
        nt.links.new(src_socket, emi.inputs["Color"])
    sc.cycles.samples = samples
    print("BAKING", name, flush=True)
    bpy.ops.object.bake(type=kind)
    a = np.array(img.pixels[:], np.float32).reshape(size, size, 4)[::-1, :, :3]   # rows top-down
    return a


def enc(sock, offset, scale):
    """(v + offset) * scale via vector math so negative positions survive the bake."""
    add = nt.nodes.new("ShaderNodeVectorMath"); add.operation = "ADD"
    add.inputs[1].default_value = (offset, offset, offset)
    nt.links.new(sock, add.inputs[0])
    mul = nt.nodes.new("ShaderNodeVectorMath"); mul.operation = "SCALE"
    mul.inputs["Scale"].default_value = scale
    nt.links.new(add.outputs[0], mul.inputs[0])
    return mul.outputs[0]


maps = {}
maps["pos"] = bake_to("pos", enc(geo.outputs["Position"], 1.0, 1.0 / 3.0)) * 3.0 - 1.0
maps["nrm"] = bake_to("nrm", enc(geo.outputs["Normal"], 1.0, 0.5)) * 2.0 - 1.0


def attr_socket(aname, scale):
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_type = "GEOMETRY"
    at.attribute_name = aname
    m = nt.nodes.new("ShaderNodeMath"); m.operation = "MULTIPLY"
    m.inputs[1].default_value = scale
    nt.links.new(at.outputs["Fac"], m.inputs[0])
    c = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(m.outputs[0], c.inputs[0]); nt.links.new(m.outputs[0], c.inputs[1]); nt.links.new(m.outputs[0], c.inputs[2])
    return c.outputs[0]


maps["reg"] = np.rint(bake_to("reg", attr_socket("region", 1.0 / 64.0))[:, :, 0] * 64.0).astype(np.int16)
maps["grp"] = np.rint(bake_to("grp", attr_socket("group", 1.0 / 8.0))[:, :, 0] * 8.0).astype(np.int16)
maps["part"] = np.rint(bake_to("part", attr_socket("part", 1.0 / 8.0))[:, :, 0] * 8.0).astype(np.int16)
# coverage: which texels belong to any island (a constant-white emission bake; margin extends it)
one = nt.nodes.new("ShaderNodeCombineXYZ")
for i in range(3):
    one.inputs[i].default_value = 1.0
sc.render.bake.margin = 0
maps["cov"] = bake_to("cov", one.outputs[0])[:, :, 0] > 0.5
sc.render.bake.margin = 14
if opt.get("ao", "1") == "1":
    import time
    t = time.time()
    # AO: of the character alone, T-pose, 512 px
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.light_settings.distance = 0.07     # local crevices only (no cross-part blotches)
    maps["ao"] = bake_to("ao", None, size=512, kind="AO", samples=int(opt.get("ao_samples", "24")))[:, :, 0]
    print("AO bake", round(time.time() - t, 1), "s")
np.savez_compressed(os.path.join(D, WHO + "_maps.npz"), **maps)
me.materials.clear()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, WHO + "_uv.blend"))
print("BAKE_OK", {k: v.shape for k, v in maps.items()})
