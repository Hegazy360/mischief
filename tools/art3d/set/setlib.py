"""setlib — the bpy builder library of the 3D sets (look A "Toy Box": chunky bevelled toy shapes, flat palette cells).

Everything is authored in GODOT coordinates (x right along the house, y up, +z toward the camera; metres) and converted
to Blender axes only when a mesh is finished ((x, y, z) -> Blender (x, -z, y), a proper rotation), so the numbers in
the builders are the numbers of house3d.json.

One PB (prop builder) = one mesh, one material (the room's or the props' palette texture: faces pick a colour by NAME,
their UVs point at that colour's cell centre). `part(name)` switches the vertex group the next primitives go to; a
finished mesh with more than one part is skinned to an armature with one bone per part (pivot = `part(..., pivot=)`),
so a live prop stays ONE draw call (+ its ink and halo shells) while its lid, lever or armed marks move and toggle.
The colour attribute "Col" stores the position-averaged normal (glTF axes, packed 0..1) for the outline shaders'
`use_color_normal` (hard-edged boxes get a closed ink hull).
"""
import bmesh
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palettes as P  # noqa: E402


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def g2b(v):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def rot_matrix(rot_deg):
    """Godot Euler rotation (degrees, applied X then Y then Z like Godot's YXZ? — here plain X, Y, Z order)."""
    rx, ry, rz = (math.radians(a) for a in rot_deg)
    mx = Matrix.Rotation(rx, 3, "X")
    my = Matrix.Rotation(ry, 3, "Y")
    mz = Matrix.Rotation(rz, 3, "Z")
    return mz @ my @ mx


_materials = {}


def palette_material(pal):
    """One material per palette (its texture is the palette PNG, nearest)."""
    if pal in _materials and _materials[pal].name in bpy.data.materials:
        return _materials[pal]
    m = bpy.data.materials.new("palette_" + pal)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexImage")
    path = PALETTE_ROOT_PNG(pal)
    img = bpy.data.images.load(path, check_existing=True)
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    _materials[pal] = m
    return m


_PAL_ROOT = [""]


def set_palette_root(root):
    _PAL_ROOT[0] = root


def PALETTE_ROOT_PNG(pal):
    return os.path.join(_PAL_ROOT[0], P.rel_path(pal))


class PB:
    """Accumulates primitives (Godot coordinates) into one mesh on one palette."""

    def __init__(self, name, pal):
        self.name = name
        self.pal = pal
        self.verts = []        # Godot-space Vector
        self.faces = []        # (vert indices, colour index, part index, smooth)
        self.parts = ["body"]
        self.pivots = {"body": (0.0, 0.0, 0.0)}
        self.parents = {"body": None}
        self.cur = 0

    # -- parts --------------------------------------------------------------------------------
    def part(self, name, pivot=None, parent="body"):
        if name not in self.parts:
            self.parts.append(name)
            self.pivots[name] = tuple(pivot) if pivot is not None else (0.0, 0.0, 0.0)
            self.parents[name] = parent
        self.cur = self.parts.index(name)
        return self

    def col(self, name):
        return P.index(self.pal, name)

    def _add(self, verts, faces, color, smooth, xf=None):
        base = len(self.verts)
        ci = self.col(color)
        for v in verts:
            v = Vector(v)
            if xf is not None:
                v = xf(v)
            self.verts.append(v)
        for f in faces:
            self.faces.append(([base + i for i in f], ci, self.cur, smooth))

    @staticmethod
    def _xf(origin, rot_deg):
        m = rot_matrix(rot_deg) if rot_deg is not None and any(rot_deg) else None
        o = Vector(origin)

        def f(v):
            return (m @ v if m is not None else v) + o
        return f

    # -- primitives ---------------------------------------------------------------------------
    def box(self, lo, hi, color, bevel=0.0, rot=None, pivot=None):
        """Axis-aligned box from lo to hi (Godot); `bevel` rounds its edges (toy look); `rot` about `pivot`
        (default the box centre)."""
        lo = Vector(lo)
        hi = Vector(hi)
        c = (lo + hi) * 0.5
        s = (hi - lo) * 0.5
        b = min(bevel, min(s) * 0.9) if bevel > 0 else 0.0
        verts, faces = _rounded_box(s, b)
        piv = Vector(pivot) if pivot is not None else c
        m = rot_matrix(rot) if rot is not None and any(rot) else None

        def f(v):
            p = v + c
            if m is not None:
                p = m @ (p - piv) + piv
            return p
        self._add(verts, faces, color, b > 0, f)
        return self

    def cyl(self, r_bot, r_top, h, base, color, seg=20, rot=None, caps=True, smooth=True):
        """A cylinder / cone along +y from `base` (bottom centre), then rotated about `base`."""
        verts, faces = [], []
        for k, (r, y) in enumerate(((r_bot, 0.0), (r_top, h))):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                verts.append((r * math.cos(a), y, r * math.sin(a)))
        for i in range(seg):
            j = (i + 1) % seg
            faces.append((i, seg + i, seg + j, j))
        if caps:
            if r_bot > 1e-5:
                faces.append(tuple(range(seg)))
            if r_top > 1e-5:
                faces.append(tuple(reversed(range(seg, 2 * seg))))
        self._add(verts, faces, color, smooth, self._xf(base, rot))
        return self

    def lathe(self, profile, base, color, seg=24, rot=None, bands=None, smooth=True, cap_bottom=True, cap_top=True):
        """Revolve [(radius, y), ...] (bottom to top) about +y at `base`; `bands` = one colour per segment."""
        rings = len(profile)
        xf = self._xf(base, rot)
        b0 = len(self.verts)
        for (r, y) in profile:
            for i in range(seg):
                a = 2 * math.pi * i / seg
                self.verts.append(xf(Vector((r * math.cos(a), y, r * math.sin(a)))))
        for k in range(rings - 1):
            colr = bands[min(k, len(bands) - 1)] if bands else color
            ci = self.col(colr)
            for i in range(seg):
                j = (i + 1) % seg
                self.faces.append(([b0 + k * seg + i, b0 + (k + 1) * seg + i, b0 + (k + 1) * seg + j, b0 + k * seg + j], ci, self.cur, smooth))
        ci = self.col(color)
        if cap_bottom and profile[0][0] > 1e-5:
            self.faces.append(([b0 + i for i in range(seg)], ci, self.cur, smooth))
        if cap_top and profile[-1][0] > 1e-5:
            self.faces.append(([b0 + (rings - 1) * seg + i for i in reversed(range(seg))], ci, self.cur, smooth))
        return self

    def sphere(self, r, centre, color, scale=(1, 1, 1), seg=16, rings=10, rot=None):
        verts = [(0.0, -r, 0.0)]
        for k in range(1, rings):
            phi = math.pi * k / rings - math.pi / 2
            for i in range(seg):
                a = 2 * math.pi * i / seg
                verts.append((r * math.cos(phi) * math.cos(a), r * math.sin(phi), r * math.cos(phi) * math.sin(a)))
        verts.append((0.0, r, 0.0))
        top = len(verts) - 1
        faces = []
        for i in range(seg):
            faces.append((0, 1 + i, 1 + (i + 1) % seg))
        for k in range(rings - 2):
            for i in range(seg):
                j = (i + 1) % seg
                a0 = 1 + k * seg
                faces.append((a0 + i, a0 + seg + i, a0 + seg + j, a0 + j))
        last = 1 + (rings - 2) * seg
        for i in range(seg):
            faces.append((last + i, top, last + (i + 1) % seg))
        sc = Vector(scale)
        verts = [(v[0] * sc.x, v[1] * sc.y, v[2] * sc.z) for v in verts]
        self._add(verts, faces, color, True, self._xf(centre, rot))
        return self

    def torus(self, R, r, centre, color, seg=24, rseg=8, rot=None, scale=(1, 1, 1), arc=1.0):
        """A ring in the local XZ plane (horizontal) around +y; rotate (90, 0, 0) to stand it facing +z.
        `arc` < 1 = an open arc (0.5 = a half ring from +x through +z to -x), end caps closed."""
        verts, faces = [], []
        sc = Vector(scale)
        closed = arc >= 0.999
        n_ring = seg if closed else seg + 1
        for i in range(n_ring):
            a = 2 * math.pi * arc * i / seg
            for j in range(rseg):
                b = 2 * math.pi * j / rseg
                x = (R + r * math.cos(b)) * math.cos(a)
                z = (R + r * math.cos(b)) * math.sin(a)
                y = r * math.sin(b)
                verts.append((x * sc.x, y * sc.y, z * sc.z))
        for i in range(seg):
            i2 = (i + 1) % n_ring
            for j in range(rseg):
                a, b = i * rseg + j, i2 * rseg + j
                c, d = i2 * rseg + (j + 1) % rseg, i * rseg + (j + 1) % rseg
                faces.append((a, d, c, b))
        if not closed:
            faces.append(tuple(range(rseg)))
            faces.append(tuple(reversed(range(seg * rseg, seg * rseg + rseg))))
        self._add(verts, faces, color, True, self._xf(centre, rot))
        return self

    def curtain(self, width, height, base, color, folds=5, amp=0.045, thick=0.03, res=8, rot=None):
        """A gathered drape hanging from `base` (top centre) down `height`; waves along z."""
        n = folds * res
        front, back = [], []
        for i in range(n + 1):
            x = -width / 2 + width * i / n
            z = amp * math.sin(2 * math.pi * folds * i / n)
            front.append((x, z + thick * 0.5))
            back.append((x, z - thick * 0.5))
        verts = []
        for (x, z) in front + back:
            verts.append((x, 0.0, z))
            verts.append((x, -height, z))
        faces = []
        m = n + 1
        for i in range(n):
            f0, f1 = 2 * i, 2 * (i + 1)
            faces.append((f0, f0 + 1, f1 + 1, f1))                      # front
            b0, b1 = 2 * (m + i), 2 * (m + i + 1)
            faces.append((b0, b1, b1 + 1, b0 + 1))                      # back
            faces.append((f0, f1, b1, b0))                              # top
            faces.append((f0 + 1, b0 + 1, b1 + 1, f1 + 1))              # bottom
        faces.append((0, 2 * m, 2 * m + 1, 1))
        faces.append((2 * n, 2 * n + 1, 2 * (m + n) + 1, 2 * (m + n)))
        self._add(verts, faces, color, True, self._xf(base, rot))
        return self

    def prism(self, poly, h, base, color, rot=None, bevel=0.0):
        """A vertical extrusion of an XZ polygon [(x, z), ...] (counter-clockwise seen from above) up `h`."""
        k = len(poly)
        verts = [(x, 0.0, z) for (x, z) in poly] + [(x, h, z) for (x, z) in poly]
        faces = [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)]
        faces.append(tuple(reversed(range(k))))
        faces.append(tuple(range(k, 2 * k)))
        self._add(verts, faces, color, False, self._xf(base, rot))
        return self

    def panel(self, poly_xy, z, thick, color, rot=None, origin=(0, 0, 0)):
        """A flat plate in the XY plane from polygon [(x, y), ...] at depth z, `thick` toward +z."""
        k = len(poly_xy)
        verts = [(x, y, z) for (x, y) in poly_xy] + [(x, y, z + thick) for (x, y) in poly_xy]
        faces = [(i, (i + 1) % k, k + (i + 1) % k, k + i) for i in range(k)]
        faces.append(tuple(range(k)))
        faces.append(tuple(reversed(range(k, 2 * k))))
        self._add(verts, faces, color, False, self._xf(origin, rot))
        return self

    # -- finish ------------------------------------------------------------------------------
    def finish(self, sharp_angle=40.0):
        """Build the mesh object (Blender axes): palette UVs, sharp edges by angle, outline normals in "Col",
        vertex groups per part."""
        bm = bmesh.new()
        # custom-data layers first: adding one later reallocates the element pools (stale BMVert references)
        uvl = bm.loops.layers.uv.new("UVMap")
        dl = bm.verts.layers.deform.verify()
        bverts = [bm.verts.new(g2b(v)) for v in self.verts]
        bm.verts.ensure_lookup_table()
        made = []
        for (idx, ci, pi, smooth) in self.faces:
            try:
                f = bm.faces.new([bverts[i] for i in idx])
            except ValueError:
                continue
            f.smooth = smooth
            u = P.cell_uv(ci)
            for lp in f.loops:
                lp[uvl].uv = u
            for i in idx:
                bverts[i][dl][pi] = 1.0
            made.append(f)
        # weld duplicated ring vertices of the same part (lathe bands) without merging across parts
        by_part = {}
        for v in bm.verts:
            groups = list(v[dl].keys())
            by_part.setdefault(groups[0] if groups else 0, []).append(v)
        for pi, vs in by_part.items():
            bmesh.ops.remove_doubles(bm, verts=vs, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        try:
            me.set_sharp_from_angle(angle=math.radians(sharp_angle))
        except Exception:
            pass
        _outline_normals(me)
        me.materials.append(palette_material(self.pal))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for name in self.parts:
            ob.vertex_groups.new(name=name)
        return ob

    def finish_skinned(self):
        """Finish, and when the mesh has more than one part, skin it to an armature named `<name>_rig` with one bone
        per part (head at the part's pivot, pointing up). Returns the root object to export."""
        ob = self.finish()
        if len(self.parts) <= 1:
            return ob
        arm_data = bpy.data.armatures.new(self.name + "_rig")
        arm = bpy.data.objects.new(self.name + "_rig", arm_data)
        bpy.context.scene.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        eb = {}
        for name in self.parts:
            b = arm_data.edit_bones.new(name)
            h = g2b(self.pivots[name])
            b.head = h
            b.tail = h + Vector((0.0, 0.0, 0.05))
            eb[name] = b
        for name in self.parts:
            par = self.parents.get(name)
            if par and par in eb and par != name:
                eb[name].parent = eb[par]
        bpy.ops.object.mode_set(mode="OBJECT")
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        return arm


def _rounded_box(s, b):
    """A box of half-size s centred at the origin; b > 0: a bevelled box (chamfer with 2 segments)."""
    if b <= 0:
        sx, sy, sz = s
        v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
             (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        return v, f
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal(Vector((2 * s[0], 2 * s[1], 2 * s[2], 1.0))), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, offset_type="OFFSET", segments=2, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    bm.verts.ensure_lookup_table()
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def _outline_normals(me):
    """Position-averaged normals -> the "Col" corner colour attribute (glTF axes, 0..1)."""
    acc = {}
    for p in me.polygons:
        n = p.normal * p.area
        for vi in p.vertices:
            k = tuple(round(c, 4) for c in me.vertices[vi].co)
            acc[k] = acc.get(k, Vector((0, 0, 0))) + n
    col = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            k = tuple(round(c, 4) for c in me.vertices[vi].co)
            n = acc[k]
            n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
            g = (n.x, n.z, -n.y)
            col.data[li].color = (g[0] * 0.5 + 0.5, g[1] * 0.5 + 0.5, g[2] * 0.5 + 0.5, 1.0)
    me.color_attributes.active_color = col


def export_glb(root, path):
    """Export `root` and its children as a .glb (materials with the palette image, vertex colours, skins)."""
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for c in root.children_recursive:
        c.select_set(True)
    bpy.context.view_layer.objects.active = root
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=False, export_yup=True,
              export_animations=False, export_skins=True, export_materials="NONE")
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    elif "export_colors" in props:
        kw["export_colors"] = True
    if "export_all_vertex_colors" in props:
        kw["export_all_vertex_colors"] = False
    if "export_apply" in props:
        kw["export_apply"] = root.type != "ARMATURE"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(**kw)


def tri_count(obj):
    n = 0
    for o in [obj] + list(obj.children_recursive):
        if o.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for a in list(bpy.data.armatures):
        bpy.data.armatures.remove(a)
