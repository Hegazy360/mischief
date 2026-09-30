"""toy_lib -- Blender (bpy/bmesh) helpers for the MND "Toy Box" look-dev characters.

Soft vinyl-toy forms: every part is a smooth closed surface (superellipsoid blobs, swept capsules,
metaball clusters) coloured per face from the shared toy palette (UV0 -> palette cell centre).
Colour boundaries are cut exactly with bisect planes (crisp stripes on any topology).
Face decals: the head's front faces carry a planar "FaceUV" map (UV1 / TEXCOORD_1); the Godot toy
shader composites eye / brow / mouth / cheek cells from a face atlas over the skin colour.

Coordinates: Blender armature space, character faces -Y, +X = character's LEFT, +Z up, metres.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix, Quaternion, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import toy_palette as TP

UAL1 = None
UAL2 = None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30


# ------------------------------------------------------------------------------------------------
# small math
# ------------------------------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def se_radius(d, a, b, c, p):
    """Distance along unit dir d to the superellipsoid |x/a|^p+|y/b|^p+|z/c|^p = 1."""
    s = (abs(d.x / a) ** p + abs(d.y / b) ** p + abs(d.z / c) ** p)
    return s ** (-1.0 / p)


# ------------------------------------------------------------------------------------------------
# geometry builders (all return a bmesh with an int face layer "col" = palette index)
# ------------------------------------------------------------------------------------------------
def _new_bm():
    bm = bmesh.new()
    bm.faces.layers.int.new("col")
    return bm


def _col_layer(bm):
    return bm.faces.layers.int.get("col") or bm.faces.layers.int.new("col")


def paint_all(bm, color):
    L = _col_layer(bm)
    for f in bm.faces:
        f[L] = TP.IDX[color]


def quad_sphere(n=12):
    """Unit sphere from a subdivided cube (even quads, good for decals and outlines)."""
    bm = _new_bm()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=n - 1, use_grid_fill=True)
    for v in bm.verts:
        c = v.co
        # tangent warp for a more uniform distribution
        x, y, z = c.x, c.y, c.z
        c.x = x * math.sqrt(max(0.0, 1 - y * y / 2 - z * z / 2 + y * y * z * z / 3))
        c.y = y * math.sqrt(max(0.0, 1 - z * z / 2 - x * x / 2 + z * z * x * x / 3))
        c.z = z * math.sqrt(max(0.0, 1 - x * x / 2 - y * y / 2 + x * x * y * y / 3))
        v.co = c.normalized()
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    return bm


def blob(fn, color, n=12):
    """Closed surface: every unit direction d of a quad sphere is mapped to fn(d) (a Vector)."""
    bm = quad_sphere(n)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = fn(d)
    paint_all(bm, color)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def se_blob(center, a, b, c, p, color, n=12, warp=None):
    """Superellipsoid blob. warp(d, pos_local) -> new pos_local (optional)."""
    C = Vector(center)

    def fn(d):
        r = se_radius(d, a, b, c, p)
        q = d * r
        if warp is not None:
            q = warp(d, q)
        return C + q
    return blob(fn, color, n)


def capsule_chain(pts, radii, color, seg=16, cap_rings=5, samples_per_m=90, up=Vector((0, 0, 1))):
    """Swept tube through points with interpolated radii and hemispherical end caps."""
    pts = [Vector(p) for p in pts]
    # cumulative length
    L = [0.0]
    for i in range(1, len(pts)):
        L.append(L[-1] + (pts[i] - pts[i - 1]).length)
    total = L[-1]
    n = max(4, int(total * samples_per_m))

    def at(s):
        for i in range(1, len(pts)):
            if s <= L[i] or i == len(pts) - 1:
                t = (s - L[i - 1]) / max(1e-9, L[i] - L[i - 1])
                t = max(0.0, min(1.0, t))
                return pts[i - 1].lerp(pts[i], t), (pts[i] - pts[i - 1]).normalized(), lerp(radii[i - 1], radii[i], smoothstep(0, 1, t))
        return pts[-1], (pts[-1] - pts[-2]).normalized(), radii[-1]

    rings = []  # (centre, tangent, radius)
    p0, t0, r0 = at(0.0)
    for k in range(cap_rings, 0, -1):
        a = (math.pi / 2) * k / cap_rings
        rings.append((p0 - t0 * r0 * math.sin(a), t0, r0 * math.cos(a)))
    for i in range(n + 1):
        rings.append(at(total * i / n))
    p1, t1, r1 = at(total)
    for k in range(1, cap_rings + 1):
        a = (math.pi / 2) * k / cap_rings
        rings.append((p1 + t1 * r1 * math.sin(a), t1, r1 * math.cos(a)))
    bm = _new_bm()
    vrings = []
    for (c, t, r) in rings:
        ref = up if abs(t.dot(up)) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        w = t.cross(u).normalized()
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ring.append(bm.verts.new(c + (u * math.cos(a) + w * math.sin(a)) * max(r, 1e-5)))
        vrings.append(ring)
    for k in range(len(vrings) - 1):
        A, B = vrings[k], vrings[k + 1]
        for j in range(seg):
            bm.faces.new((A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]))
    # close ends with a fan (tiny rings)
    for ring, rev in ((vrings[0], True), (vrings[-1], False)):
        c = sum((v.co for v in ring), Vector()) / len(ring)
        cv = bm.verts.new(c)
        for j in range(seg):
            a, b = ring[j], ring[(j + 1) % seg]
            bm.faces.new((cv, b, a) if rev else (cv, a, b))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    paint_all(bm, color)
    return bm


def ribbon(path_pts, normals, width, thick, color, side=None):
    """Flat strap along a surface path: pts + outward normals, width across, thickness outward."""
    bm = _new_bm()
    n = len(path_pts)
    rows = []
    for i in range(n):
        p = Vector(path_pts[i])
        nn = Vector(normals[i]).normalized()
        t = (Vector(path_pts[min(i + 1, n - 1)]) - Vector(path_pts[max(i - 1, 0)])).normalized()
        s = t.cross(nn).normalized() if side is None else Vector(side)
        corners = [p - s * width / 2, p + s * width / 2, p + s * width / 2 + nn * thick, p - s * width / 2 + nn * thick]
        rows.append([bm.verts.new(c) for c in corners])
    for i in range(n - 1):
        A, B = rows[i], rows[i + 1]
        for j in range(4):
            bm.faces.new((A[j], A[(j + 1) % 4], B[(j + 1) % 4], B[j]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    paint_all(bm, color)
    return bm


def torus(R, r, center, color, seg=24, rseg=8, rot=(0, 0, 0)):
    bm = _new_bm()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            ring.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = rings[i][j], rings[(i + 1) % seg][j]
            c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]
            bm.faces.new((a, b, c, d))
    M = Matrix.Translation(Vector(center)) @ Euler([math.radians(x) for x in rot], "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    paint_all(bm, color)
    return bm


def cylinder(r1, r2, h, center_bottom, color, seg=20, rot=(0, 0, 0)):
    bm = _new_bm()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, h / 2)), verts=bm.verts[:])
    M = Matrix.Translation(Vector(center_bottom)) @ Euler([math.radians(x) for x in rot], "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts[:])
    paint_all(bm, color)
    return bm


def transform(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts[:])
    return bm


def rot_about(bm, pivot, rot_deg, order="XYZ"):
    P = Vector(pivot)
    M = Matrix.Translation(P) @ Euler([math.radians(x) for x in rot_deg], order).to_matrix().to_4x4() @ Matrix.Translation(-P)
    return transform(bm, M)


def bisect(bm, co, no):
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=Vector(co), plane_no=Vector(no))
    return bm


def recolor(bm, rule):
    """rule(face_centre, face_normal, current_colour_name) -> colour name or None (keep)."""
    L = _col_layer(bm)
    names = [c[0] for c in TP.COLORS]
    for f in bm.faces:
        c = f.calc_center_median()
        r = rule(c, f.normal, names[f[L]])
        if r:
            f[L] = TP.IDX[r]
    return bm


def delete_faces(bm, pred):
    kill = [f for f in bm.faces if pred(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    return bm


def merge(*bms):
    out = _new_bm()
    tmp = bpy.data.meshes.new("_tmp")
    for b in bms:
        b.to_mesh(tmp)
        out.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    return out


def metaballs(name, elements, color, resolution=0.012, threshold=0.6, decimate=None, smooth=0):
    """elements: [(type, co, radius, (sx, sy, sz) or None, rot_euler_deg or None, negative)]. radius = the
    SURFACE radius wanted for an isolated element (stiffness 2 calibration). Returns a bmesh."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    k = 1.0 / math.sqrt(1.0 - (threshold / 2.0) ** (1.0 / 3.0))
    for el in elements:
        typ, co, rad = el[0], el[1], el[2]
        size = el[3] if len(el) > 3 else None
        rot = el[4] if len(el) > 4 else None
        neg = el[5] if len(el) > 5 else False
        e = mb.elements.new(type=typ)
        e.co = co
        e.radius = rad * k
        e.stiffness = 2.0
        e.use_negative = bool(neg)
        if size is not None:
            e.size_x, e.size_y, e.size_z = size
        if rot is not None:
            e.rotation = Euler([math.radians(x) for x in rot], "XYZ").to_quaternion()
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    mob = bpy.context.view_layer.objects.active
    if decimate:
        md = mob.modifiers.new("dec", "DECIMATE")
        md.ratio = decimate
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(mob.evaluated_get(dg))
    else:
        me = mob.data
    bm = _new_bm()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for _ in range(smooth):
        bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for o in list(bpy.data.objects):
        if o.name.startswith(name):
            bpy.data.objects.remove(o, do_unlink=True)
    paint_all(bm, color)
    return bm


def decimate_bm(bm, ratio):
    me = bpy.data.meshes.new("_dec")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("_dec", me)
    bpy.context.scene.collection.objects.link(ob)
    md = ob.modifiers.new("dec", "DECIMATE")
    md.ratio = ratio
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = _new_bm()
    out.from_mesh(me2)
    bpy.data.objects.remove(ob, do_unlink=True)
    return out


def tri_count(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


# ------------------------------------------------------------------------------------------------
# skeleton: import UAL, retarget proportions (bone directions + rolls kept), extra bones
# ------------------------------------------------------------------------------------------------
def action_fcurves(act):
    try:
        return list(act.fcurves)
    except Exception:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


def import_ual(ual1, ual2=None, keep1=(), keep2=()):
    bpy.ops.import_scene.gltf(filepath=ual1)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    arm.name = "Armature"
    arm.data.name = "Armature"
    for o in list(bpy.data.objects):
        if o.type == "MESH" or (o.type != "ARMATURE"):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name in keep1:
            a.name = "UAL_" + a.name
        else:
            bpy.data.actions.remove(a)
    if ual2:
        before = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=ual2)
        for o in list(bpy.data.objects):
            if o != arm:
                bpy.data.objects.remove(o, do_unlink=True)
        for a in list(set(bpy.data.actions) - before):
            base = a.name.split(".")[0]
            if base in keep2 and ("UAL_" + base) not in bpy.data.actions:
                a.name = "UAL_" + base
            else:
                bpy.data.actions.remove(a)
    for a in bpy.data.actions:
        a.use_fake_user = True
    if arm.animation_data:
        arm.animation_data.action = None
    return arm


def retarget(arm, k_len, k_off, foot_k=1.0, hip_ratio_out=None):
    """Rescale the skeleton. k_len[bone] = own length scale; k_off[bone] = scale (float or xyz) of the
    offset parent-head -> bone-head (default: parent's k_len). Bone directions + rolls are preserved so
    library local-rotation keys keep meaning. Feet are put back on the floor; pelvis location keys of
    every action are scaled by the pelvis-height ratio."""
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in eb}
    order = []

    def visit(b):
        order.append(b.name)
        for c in b.children:
            visit(c)
    for b in eb:
        if b.parent is None:
            visit(b)
    new_h, new_t = {}, {}
    for n in order:
        b = eb[n]
        oh, ot, _ = old[n]
        if b.parent is None:
            new_h[n] = oh.copy()
        else:
            p = b.parent.name
            ko = k_off.get(n, k_len.get(p, 1.0))
            if not isinstance(ko, (tuple, list)):
                ko = (ko, ko, ko)
            d = oh - old[p][0]
            new_h[n] = new_h[p] + Vector((d.x * ko[0], d.y * ko[1], d.z * ko[2]))
        kl = k_len.get(n, 1.0)
        new_t[n] = new_h[n] + (ot - oh) * kl
    # floor: ball_l head z -> old * foot_k
    dz = old["ball_l"][0].z * foot_k - new_h["ball_l"].z
    for b in eb:
        b.use_connect = False
    for n in order:
        if n == "root":
            continue
        new_h[n].z += dz
        new_t[n].z += dz
    for n in order:
        b = eb[n]
        b.head = new_h[n]
        b.tail = new_t[n]
        b.roll = old[n][2]
    pel_old = old["pelvis"][0].z
    pel_new = new_h["pelvis"].z
    bpy.ops.object.mode_set(mode="OBJECT")
    ratio = pel_new / pel_old
    for act in bpy.data.actions:
        for fc in action_fcurves(act):
            if fc.data_path == 'pose.bones["pelvis"].location':
                for kp in fc.keyframe_points:
                    kp.co[1] *= ratio
                    kp.handle_left[1] *= ratio
                    kp.handle_right[1] *= ratio
    return ratio


def add_bones(arm, specs):
    """specs: [(name, parent, head, tail)] in armature space."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for name, parent, h, t in specs:
        b = eb.new(name)
        b.head = Vector(h)
        b.tail = Vector(t)
        b.roll = 0.0
        b.parent = eb[parent]
        b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")


class Rig:
    def __init__(self, arm):
        self.arm = arm
        self.B = {b.name: b for b in arm.data.bones}

    def head(self, n):
        return self.arm.matrix_world @ self.B[n].head_local

    def tail(self, n):
        return self.arm.matrix_world @ self.B[n].tail_local


# ------------------------------------------------------------------------------------------------
# parts -> skinned object
# ------------------------------------------------------------------------------------------------
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-12)))
    return (p - (a + ab * t)).length


class Body:
    def __init__(self, rig, name):
        self.rig = rig
        self.name = name
        self.parts = []   # objects

    def add(self, bm, bones, power=4.0, keep=2, face_uv=None, name="part", seg_override=None):
        """bones: list of bone names (distance-to-segment weights) or a single name (rigid).
        face_uv: dict(center=(x,z), w=, h=, front=-0.2) -> planar FaceUV on front faces."""
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        # colours -> palette UV (UV0); FaceUV (UV1)
        layer = me.attributes.get("col")
        cols = [0] * len(me.polygons)
        if layer is not None:
            for i, p in enumerate(me.polygons):
                cols[i] = layer.data[i].value
            me.attributes.remove(layer)
        uv0 = me.uv_layers.new(name="UVMap")
        uv1 = me.uv_layers.new(name="FaceUV")
        for i, p in enumerate(me.polygons):
            u = TP.cell_uv(cols[i])
            fuv = None
            if face_uv is not None:
                cx, cz = face_uv["center"]
                if p.normal.y < face_uv.get("front", -0.25) and p.center.y < face_uv.get("ymax", 0.0):
                    fuv = True
            for li in p.loop_indices:
                uv0.data[li].uv = u
                if fuv:
                    co = me.vertices[me.loops[li].vertex_index].co
                    uv1.data[li].uv = ((co.x - cx) / face_uv["w"] + 0.5, (co.z - cz) / face_uv["h"] + 0.5)
                else:
                    uv1.data[li].uv = (-2.0, -2.0)
        for p in me.polygons:
            p.use_smooth = True
        # weights
        if isinstance(bones, str):
            g = ob.vertex_groups.new(name=bones)
            g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
        else:
            groups = {n: ob.vertex_groups.new(name=n) for n in bones}
            segs = {n: (self.rig.head(n), self.rig.tail(n)) for n in bones}
            if seg_override:
                for n, s in seg_override.items():
                    segs[n] = (Vector(s[0]), Vector(s[1]))
            for v in me.vertices:
                p = v.co
                ws = sorted(((1.0 / (seg_dist(p, *segs[n]) ** power + 1e-9), n) for n in bones), reverse=True)[:keep]
                tot = sum(w for w, _ in ws)
                for w, n in ws:
                    groups[n].add([v.index], w / tot, "REPLACE")
        self.parts.append(ob)
        self.tri_log = getattr(self, "tri_log", {})
        self.tri_log[name] = self.tri_log.get(name, 0) + sum(len(p.vertices) - 2 for p in me.polygons)
        return ob

    def finish(self, material):
        print("TRIS_BY_PART", sorted(getattr(self, "tri_log", {}).items(), key=lambda kv: -kv[1]))
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0]
        bpy.ops.object.join()
        body = bpy.context.view_layer.objects.active
        body.name = self.name
        body.data.name = self.name
        body.data.materials.clear()
        body.data.materials.append(material)
        body.parent = self.rig.arm
        mod = body.modifiers.new("Armature", "ARMATURE")
        mod.object = self.rig.arm
        # normalise weights (keep <= 4)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        return body


def toy_material(name, palette_png, face_png=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(palette_png)
    tex.interpolation = "Closest"
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    nt.links.new(uvn.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if face_png:
        # the face atlas rides along as the emissive texture on TEXCOORD_1 (keeps FaceUV in the export
        # and makes the .glb self-contained; the Godot toy shader reads it from there)
        ft = nt.nodes.new("ShaderNodeTexImage")
        ft.image = bpy.data.images.load(face_png)
        fu = nt.nodes.new("ShaderNodeUVMap")
        fu.uv_map = "FaceUV"
        nt.links.new(fu.outputs["UV"], ft.inputs["Vector"])
        nt.links.new(ft.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.0001
    return m


# ------------------------------------------------------------------------------------------------
# keyframing (rotations about ARMATURE axes, as if the parent were at rest)
# ------------------------------------------------------------------------------------------------
AX = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}


class Animator:
    def __init__(self, rig, bones, fps=30):
        self.rig = rig
        self.arm = rig.arm
        self.bones = bones
        self.fps = fps
        self.faces = {}    # clip -> [[time_s, preset], ...]
        self.meta = {}     # clip -> {...}

    def rest_q(self, n):
        return self.rig.B[n].matrix_local.to_quaternion()

    def local_q(self, n, rots):
        R = Quaternion()
        for ax, deg in rots:
            R = Quaternion(AX[ax], math.radians(deg)) @ R
        M = self.rest_q(n)
        return M.inverted() @ R @ M

    def clip(self, name, keys, faces=None, loop=False, interp=None):
        """keys: [(frame, pose)] ; pose: {bone: [(ax,deg)...] | {"r": [...], "s": f|(x,y,z), "t": (x,y,z)}}
        special: "_root": (x,y,z) armature-space offset of the root bone, "_pelvis": (x,y,z) offset.
        interp: {frame: 'LINEAR'|'CONSTANT'|'BEZIER'} interpolation leaving that key."""
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm = self.arm
        arm.animation_data_create()
        arm.animation_data.action = act
        for f, pose in keys:
            for n in self.bones:
                pb = arm.pose.bones[n]
                pb.rotation_mode = "QUATERNION"
                spec = pose.get(n, [])
                if isinstance(spec, dict):
                    rots = spec.get("r", [])
                    s = spec.get("s", 1.0)
                    t = spec.get("t", None)
                else:
                    rots, s, t = spec, 1.0, None
                pb.rotation_quaternion = self.local_q(n, rots)
                pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
                pb.scale = (s, s, s) if not isinstance(s, (tuple, list)) else s
                pb.keyframe_insert("scale", frame=f, group=n)
                off = Vector(t) if t is not None else Vector()
                if n == "pelvis" and "_pelvis" in pose:
                    off = Vector(pose["_pelvis"])
                if n == "root" and "_root" in pose:
                    off = Vector(pose["_root"])
                pb.location = self.rest_q(n).inverted() @ off
                pb.keyframe_insert("location", frame=f, group=n)
        fcs = action_fcurves(act)
        if interp:
            for fc in fcs:
                for kp in fc.keyframe_points:
                    fr = int(round(kp.co[0]))
                    if fr in interp:
                        kp.interpolation = interp[fr]
        arm.animation_data.action = None
        if faces:
            self.faces[name] = [[round((fr - keys[0][0]) / self.fps, 4), p] for fr, p in faces]
        self.meta[name] = {"frames": keys[-1][0] - keys[0][0], "loop": loop}
        return act


def export_glb(arm, body, path):
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create()
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=True, export_skins=True, export_materials="EXPORT", export_image_format="AUTO",
              export_animation_mode="ACTIONS", export_optimize_animation_size=False, export_def_bones=False,
              export_frame_range=False, export_texcoords=True, export_normals=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props or k == "filepath"}
    bpy.ops.export_scene.gltf(**kw)


def key_library_extras(arm, hide_bones, prefix="UAL_"):
    """Library clips know nothing about our extra bones: key them into every imported clip so props /
    FX / worn specs stay hidden (scale 0) and the rest stay at rest (Godot leaves unkeyed bones at rest)."""
    arm.animation_data_create()
    for act in list(bpy.data.actions):
        if not act.name.startswith(prefix):
            continue
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
            arm.animation_data.action_slot = act.slots[0]      # UAL2 clips carry the other armature's slot
        f0, f1 = act.frame_range
        for n in hide_bones:
            pb = arm.pose.bones[n]
            pb.scale = (0.0, 0.0, 0.0)
            for f in (f0, f1):
                pb.keyframe_insert("scale", frame=f, group=n)
            pb.scale = (1, 1, 1)
    arm.animation_data.action = None
