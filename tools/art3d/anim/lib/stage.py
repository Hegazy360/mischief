"""Where a clip is performed: world (Godot) <-> character (Blender armature) coordinates, the audience camera, and
the placed reach geometry of `house3d.json` (R4/R5).

Godot world: +x right, +y up, +z toward the camera (metres; 1 m = 200 sim px). The character stands at (x, floor, z)
yawed by `facing` and `cheat` exactly as `RigPlayer3D` does it: yaw = facing * (90° - cheat) (facing right: 90 - cheat,
left: -90 + cheat). Character (Blender armature) axes: +x her left, -y her front, +z up; Godot local = (bx, bz, -by).
"""
import json, math, os
from mathutils import Vector

CAMERA_Y = 1.9
CAMERA_Z = 6.5
LANE_Z = -1.0
PX_PER_M = 200.0


from .paths import repo_root  # noqa: E402


class Stage:
    def __init__(self, x=0.0, z=LANE_Z, facing=1, cheat=0.0, floor_y=0.0, camera_x=None):
        self.x = float(x)
        self.z = float(z)
        self.facing = 1 if facing >= 0 else -1
        self.cheat = float(cheat)
        self.floor_y = float(floor_y)
        self.camera_x = self.x if camera_x is None else float(camera_x)

    @property
    def yaw_deg(self):
        return self.facing * (90.0 - self.cheat)

    def to_char(self, world):
        """Godot world point -> armature-space point."""
        wx, wy, wz = world
        dx, dy, dz = wx - self.x, wy - self.floor_y, wz - self.z
        a = math.radians(-self.yaw_deg)       # R_y(-yaw)
        gx = dx * math.cos(a) + dz * math.sin(a)
        gz = -dx * math.sin(a) + dz * math.cos(a)
        return Vector((gx, -gz, dy))

    def to_world(self, p):
        """Armature-space point -> Godot world point (x, y, z)."""
        gx, gy, gz = p[0], p[2], -p[1]
        a = math.radians(self.yaw_deg)
        wx = gx * math.cos(a) + gz * math.sin(a)
        wz = -gx * math.sin(a) + gz * math.cos(a)
        return (wx + self.x, gy + self.floor_y, wz + self.z)

    def camera(self):
        """The audience camera (base framing) in armature space."""
        return self.to_char((self.camera_x, CAMERA_Y, CAMERA_Z))

    def dir_to_char(self, d_world):
        o = self.to_char((self.x, self.floor_y, self.z))
        p = self.to_char((self.x + d_world[0], self.floor_y + d_world[1], self.z + d_world[2]))
        return (p - o).normalized()

    def as_json(self):
        return {"x": round(self.x, 4), "z": round(self.z, 4), "facing": self.facing, "cheat_deg": round(self.cheat, 2)}


# ------------------------------------------------------------------------------------------------
# house data (read-only: house.json is frozen, house3d.json is r3d-sets')
# ------------------------------------------------------------------------------------------------
_CACHE = {}


def _json(rel):
    p = os.path.join(repo_root(), "game", rel)
    if p not in _CACHE:
        _CACHE[p] = json.load(open(p)) if os.path.exists(p) else None
    return _CACHE[p]


def house():
    return _json("data/house/house.json") or {}


def house3d():
    return _json("data/house/house3d.json") or {}


def rig_actions():
    return _json("data/anim/hush3d/rig_actions.json") or {}


def _hotspot_2d(hid):
    h = house()
    hs = h.get("hotspots", {})
    if isinstance(hs, dict):
        return hs.get(hid)
    for e in hs or []:
        if isinstance(e, dict) and e.get("id") == hid:
            return e
    return None


def hotspot_rect_m(hid):
    """(x0, y0, x1, y1) metres of a house.json hotspot rect (y up from its floor line), or None."""
    e = _hotspot_2d(hid)
    if not e:
        return None
    r = e.get("rect")
    if r is None:
        return None
    if isinstance(r, dict):
        x, y, w, hh = r.get("x"), r.get("y"), r.get("w"), r.get("h")
    else:
        x, y, w, hh = r
    return (x / PX_PER_M, -(y + hh) / PX_PER_M, (x + w) / PX_PER_M, -y / PX_PER_M)


def use_x_m(hid):
    e = _hotspot_2d(hid) or {}
    ux = e.get("use_x")
    if ux is None:
        r = hotspot_rect_m(hid)
        return None if r is None else (r[0] + r[2]) * 0.5
    return ux / PX_PER_M


def reach_geometry(hid, fallback=None):
    """{target: (x, y, z) world, pos: {x, z, step, step_h}, facing, band, source} for a rig hotspot from
    house3d.json (+ house.json for x/y); `fallback` (same shape) until r3d-sets lands the entry."""
    h3 = house3d().get("hotspots", {}).get(hid)
    if not h3:
        if fallback is None:
            raise KeyError("house3d.json has no hotspot '%s' (and no fallback given)" % hid)
        out = dict(fallback)
        out["source"] = "fallback"
        return out
    rect = hotspot_rect_m(hid)
    ox, oy = (h3.get("visual_offset") or [0.0, 0.0])[:2]
    cx = (rect[0] + rect[2]) * 0.5 + ox
    by = rect[1] + oy
    sc = float(h3.get("scale", 1.0))
    rt = h3.get("reach_target") or [0.0, 0.0, 0.0]
    target = (cx + rt[0] * sc, by + rt[1] * sc, float(h3.get("z", -1.75)) + rt[2] * sc)
    rp = h3.get("reach_pos") or {}
    ux = use_x_m(hid)
    px = (ux if ux is not None else cx) + float(rp.get("dx", 0.0))
    pos = {"x": px, "z": float(rp.get("z", -1.6)), "step": rp.get("step"), "step_h": float(rp.get("step_h", 0.0) or 0.0)}
    facing = -1 if target[0] < px else 1
    return {"target": target, "pos": pos, "facing": facing, "band": h3.get("reach"), "source": "house3d.json"}
