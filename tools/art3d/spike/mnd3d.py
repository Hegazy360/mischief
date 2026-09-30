"""mnd3d — tiny bpy/bmesh helper library for Mischief Next Door 3D props and characters.

Every prop is built from bevelled primitives into ONE mesh with ONE material that samples the shared
palette texture (palette.png, 8x8 cells of 16 px). Faces pick a colour by palette NAME; the UVs of all
loops of a face point at the centre of that colour's cell. Result: one surface = one draw call per prop,
and recolouring the whole set is a palette.png edit.

A colour attribute "Col" (CORNER, float) stores the position-averaged ("smooth") normal of every
corner, already converted to glTF/Godot axes and packed 0..1 — the inverted-hull outline shader grows
the hull along it, so hard-edged boxes get a closed outline.

Coordinates (Blender): +X right along the house, +Y into the screen (away from camera), +Z up.
glTF/Godot: X right, Y up, +Z toward the camera.
"""
import bpy, bmesh, json, math, os
from mathutils import Matrix, Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
PAL_JSON = os.path.join(HERE, "palette.json")
PAL_PNG = os.path.join(HERE, "palette.png")
COLORS = json.load(open(PAL_JSON))["colors"]
IDX = {c[0]: i for i, c in enumerate(COLORS)}
GRID = 8


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def cell_uv(i):
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def _mat4(pos=(0, 0, 0), rot=(0, 0, 0), scale=None):
    m = Matrix.Translation(Vector(pos)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    if scale is not None:
        m = m @ Matrix.Diagonal(Vector((*scale, 1.0)))
    return m


_palette_mat = None


def palette_material():
    global _palette_mat
    if _palette_mat is not None and _palette_mat.name in bpy.data.materials:
        return _palette_mat
    m = bpy.data.materials.new("palette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.get("palette.png") or bpy.data.images.load(PAL_PNG)
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    _palette_mat = m
    return m


class PB:
    """Prop builder: accumulate primitives into one bmesh."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()

    # -- internal -------------------------------------------------------------------------------
    def _merge(self, tbm, color, smooth, bevel=0.0, seg=2, matrix=None):
        if bevel > 0:
            bmesh.ops.bevel(tbm, geom=list(tbm.edges), offset=bevel, offset_type="OFFSET", segments=seg,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        if matrix is not None:
            bmesh.ops.transform(tbm, matrix=matrix, verts=list(tbm.verts))
        ci = IDX[color]
        for f in tbm.faces:
            f.material_index = ci
            f.smooth = smooth
        tmp = bpy.data.meshes.new("_tmp")
        tbm.to_mesh(tmp)
        tbm.free()
        self.bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    # -- primitives (pos = bottom centre unless noted; rot in degrees XYZ, applied about pos) ---
    def box(self, size, pos, color, bevel=0.015, seg=2, rot=(0, 0, 0)):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        bmesh.ops.transform(t, matrix=Matrix.Translation((0, 0, 0.5)), verts=t.verts)
        bmesh.ops.transform(t, matrix=Matrix.Diagonal(Vector((*size, 1))), verts=t.verts)
        b = min(bevel, min(size) * 0.45)
        self._merge(t, color, False, b, seg, _mat4(pos, rot))
        return self

    def box_min(self, mn, mx, color, bevel=0.015, seg=2):
        """Axis-aligned box from min corner to max corner."""
        size = [mx[i] - mn[i] for i in range(3)]
        pos = ((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2])
        return self.box(size, pos, color, bevel, seg)

    def cyl(self, r1, r2, h, pos, color, seg=24, bevel=0.0, rot=(0, 0, 0), smooth=True, scale=None):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
        bmesh.ops.transform(t, matrix=Matrix.Translation((0, 0, h / 2)), verts=t.verts)
        if scale is not None:
            bmesh.ops.transform(t, matrix=Matrix.Diagonal(Vector((*scale, 1))), verts=t.verts)
        self._merge(t, color, smooth, bevel, 2, _mat4(pos, rot))
        return self

    def sphere(self, r, pos, color, scale=(1, 1, 1), seg=20, rings=12, rot=(0, 0, 0)):
        """pos = CENTRE."""
        t = bmesh.new()
        bmesh.ops.create_uvsphere(t, u_segments=seg, v_segments=rings, radius=r)
        bmesh.ops.transform(t, matrix=Matrix.Diagonal(Vector((*scale, 1))), verts=t.verts)
        self._merge(t, color, True, 0, 2, _mat4(pos, rot))
        return self

    def torus(self, R, r, pos, color, seg=24, rseg=10, rot=(0, 0, 0), scale=None):
        """pos = CENTRE; ring in the local XY plane."""
        t = bmesh.new()
        rings = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring = []
            for j in range(rseg):
                b = 2 * math.pi * j / rseg
                x = (R + r * math.cos(b)) * math.cos(a)
                y = (R + r * math.cos(b)) * math.sin(a)
                z = r * math.sin(b)
                ring.append(t.verts.new((x, y, z)))
            rings.append(ring)
        for i in range(seg):
            for j in range(rseg):
                a, b = rings[i][j], rings[(i + 1) % seg][j]
                c, d = rings[(i + 1) % seg][(j + 1) % rseg], rings[i][(j + 1) % rseg]
                t.faces.new((a, b, c, d))
        if scale is not None:
            bmesh.ops.transform(t, matrix=Matrix.Diagonal(Vector((*scale, 1))), verts=t.verts)
        self._merge(t, color, True, 0, 2, _mat4(pos, rot))
        return self

    def lathe(self, profile, pos, color, seg=28, rot=(0, 0, 0), cap_top=True, cap_bottom=True, smooth=True, scale=None, bands=None):
        """profile: [(radius, z), ...] from bottom to top, revolved about local Z.
        bands: optional list of colour names, one per profile segment (one continuous surface)."""
        t = bmesh.new()
        rings = []
        for (r, z) in profile:
            ring = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                ring.append(t.verts.new((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
        band_faces = []
        for k in range(len(rings) - 1):
            for i in range(seg):
                a, b = rings[k][i], rings[k][(i + 1) % seg]
                c, d = rings[k + 1][(i + 1) % seg], rings[k + 1][i]
                f = t.faces.new((a, b, c, d))
                band_faces.append((f, k))
        if cap_bottom and profile[0][0] > 1e-4:
            t.faces.new(list(reversed(rings[0])))
        if cap_top and profile[-1][0] > 1e-4:
            t.faces.new(rings[-1])
        bmesh.ops.remove_doubles(t, verts=t.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        if scale is not None:
            bmesh.ops.transform(t, matrix=Matrix.Diagonal(Vector((*scale, 1))), verts=t.verts)
        if bands:
            self._merge_bands(t, color, bands, band_faces, smooth, _mat4(pos, rot))
        else:
            self._merge(t, color, smooth, 0, 2, _mat4(pos, rot))
        return self

    def _merge_bands(self, tbm, color, bands, band_faces, smooth, matrix):
        bmesh.ops.transform(tbm, matrix=matrix, verts=list(tbm.verts))
        banded = {f: k for f, k in band_faces if f.is_valid}
        for f in tbm.faces:
            k = banded.get(f)
            f.material_index = IDX[bands[min(k, len(bands) - 1)]] if k is not None else IDX[color]
            f.smooth = smooth
        tmp = bpy.data.meshes.new("_tmp")
        tbm.to_mesh(tmp)
        tbm.free()
        self.bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    def prism(self, poly, h, pos, color, rot=(0, 0, 0), bevel=0.0, smooth=False):
        """Vertical extrusion of a closed 2D polygon [(x, y), ...] (CCW seen from +Z), height h."""
        t = bmesh.new()
        bot = [t.verts.new((x, y, 0)) for (x, y) in poly]
        top = [t.verts.new((x, y, h)) for (x, y) in poly]
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            t.faces.new((bot[i], bot[j], top[j], top[i]))
        t.faces.new(list(reversed(bot)))
        t.faces.new(top)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, color, smooth, bevel, 2, _mat4(pos, rot))
        return self

    def curtain(self, width, height, pos, color, folds=4, amp=0.05, thick=0.03, rot=(0, 0, 0), res=10):
        """Wavy vertical drape: x in [-w/2, w/2], wave in y, from pos (bottom centre) up h."""
        pts_f, pts_b = [], []
        n = folds * res
        for i in range(n + 1):
            x = -width / 2 + width * i / n
            y = -amp * math.sin(2 * math.pi * folds * i / n)
            pts_f.append((x, y))
            pts_b.append((x, y + thick))
        poly = pts_f + list(reversed(pts_b))
        t = bmesh.new()
        bot = [t.verts.new((x, y, 0)) for (x, y) in poly]
        top = [t.verts.new((x, y, height)) for (x, y) in poly]
        m = len(poly)
        for i in range(m):
            j = (i + 1) % m
            t.faces.new((bot[i], bot[j], top[j], top[i]))
        # caps as quad strips (the polygon is a thin ribbon: pair front/back points)
        for cap, flip in ((bot, True), (top, False)):
            for i in range(n):
                a, b = cap[i], cap[i + 1]
                c, d = cap[m - 2 - i], cap[m - 1 - i]
                f = t.faces.new((a, b, c, d) if not flip else (d, c, b, a))
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, color, True, 0, 2, _mat4(pos, rot))
        return self

    # -- finish ---------------------------------------------------------------------------------
    def finish(self, link=True, sharp_angle=50.0):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        self.bm.to_mesh(me)
        self.bm.free()
        finalize_mesh(me, sharp_angle)
        ob = bpy.data.objects.new(self.name, me)
        if link:
            bpy.context.scene.collection.objects.link(ob)
        return ob


def finalize_mesh(me, sharp_angle=50.0):
    """Palette UVs from material_index, sharp edges by angle, outline normals, single palette material."""
    try:
        me.set_sharp_from_angle(angle=math.radians(sharp_angle))
    except Exception:
        pass
    uv = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
    for p in me.polygons:
        u = cell_uv(p.material_index)
        for li in p.loop_indices:
            uv.data[li].uv = u
    # position-averaged normals -> colour attribute (glTF axes, 0..1)
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
            g = (n.x, n.z, -n.y)  # Blender -> glTF axes
            col.data[li].color = (g[0] * 0.5 + 0.5, g[1] * 0.5 + 0.5, g[2] * 0.5 + 0.5, 1.0)
    me.color_attributes.active_color = col
    for p in me.polygons:
        p.material_index = 0
    me.materials.clear()
    me.materials.append(palette_material())


def export_glb(objs, path, animations=False, extra=None):
    """Export the given objects (and their children) as a .glb."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, use_selection=True, export_format="GLB", export_apply=True, export_yup=True,
              export_animations=animations, export_skins=True, export_materials="EXPORT", export_image_format="AUTO")
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    elif "export_colors" in props:
        kw["export_colors"] = True
    if "export_all_vertex_colors" in props:
        kw["export_all_vertex_colors"] = False
    if extra:
        kw.update(extra)
    bpy.ops.export_scene.gltf(**kw)
