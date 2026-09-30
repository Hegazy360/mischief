"""Pose helpers for Toy Box clips (rotations about armature axes; see toy_lib.Animator)."""


def mirror(rots):
    """left <-> right: rotations about Y and Z flip sign, about X keep."""
    if isinstance(rots, dict):
        out = dict(rots)
        out["r"] = mirror(rots.get("r", []))
        if "t" in rots:
            x, y, z = rots["t"]
            out["t"] = (-x, y, z)
        return out
    return [(ax, deg if ax == "x" else -deg) for ax, deg in rots]


def sym(pose):
    """copy every *_l entry to *_r (mirrored) unless *_r is given."""
    out = dict(pose)
    for n, r in list(pose.items()):
        if n.endswith("_l") and (n[:-2] + "_r") not in pose:
            out[n[:-2] + "_r"] = mirror(r)
    return out


def swap(pose):
    """swap sides (for the second half of a walk cycle)."""
    q = {}
    for n, r in pose.items():
        if n.endswith("_l"):
            q[n[:-2] + "_r"] = mirror(r)
        elif n.endswith("_r"):
            q[n[:-2] + "_l"] = mirror(r)
        elif n in ("_root", "_pelvis"):
            q[n] = (-r[0], r[1], r[2])
        elif isinstance(r, list):
            q[n] = [(ax, deg if ax == "x" else -deg) for ax, deg in r]   # centre bones: mirror twist/bend
        elif isinstance(r, dict):
            q[n] = mirror(r)
        else:
            q[n] = r
    return q


def merge(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            out[k] = v
    return out


def curl(side, a, thumb=None, fingers=("index", "middle", "ring", "pinky")):
    """finger curl (degrees per joint), +a = toward the palm."""
    s = 1 if side == "l" else -1
    out = {}
    for f in fingers:
        for i in (1, 2, 3):
            out[f"{f}_{i:02d}_{side}"] = [("y", s * a * (0.7 if i == 1 else 1.0))]
    if thumb is not None:
        for i in (1, 2, 3):
            out[f"thumb_{i:02d}_{side}"] = [("z", -s * thumb * 0.5), ("y", s * thumb * 0.5)]
    return out


def lerp_pose(a, b, t):
    """blend two poses (angles per axis entry, matching by bone; missing = 0)."""
    out = {}
    keys = set(a) | set(b)
    for k in keys:
        va, vb = a.get(k), b.get(k)
        if k in ("_root", "_pelvis"):
            va = va or (0, 0, 0)
            vb = vb or (0, 0, 0)
            out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
            continue
        def norm(v):
            if v is None:
                return {"r": [], "s": 1.0}
            if isinstance(v, dict):
                return {"r": v.get("r", []), "s": v.get("s", 1.0), "t": v.get("t")}
            return {"r": v, "s": 1.0}
        na, nb = norm(va), norm(vb)
        ra, rb = na["r"], nb["r"]
        n = max(len(ra), len(rb))
        rr = []
        for i in range(n):
            ax = (ra[i][0] if i < len(ra) else rb[i][0])
            x = ra[i][1] if i < len(ra) and ra[i][0] == ax else 0.0
            y = rb[i][1] if i < len(rb) and rb[i][0] == ax else 0.0
            rr.append((ax, x + (y - x) * t))
        sa, sb = na["s"], nb["s"]
        if isinstance(sa, (tuple, list)) or isinstance(sb, (tuple, list)):
            sa = sa if isinstance(sa, (tuple, list)) else (sa, sa, sa)
            sb = sb if isinstance(sb, (tuple, list)) else (sb, sb, sb)
            s = tuple(x + (y - x) * t for x, y in zip(sa, sb))
        else:
            s = sa + (sb - sa) * t
        d = {"r": rr, "s": s}
        ta, tb = na.get("t"), nb.get("t")
        if ta or tb:
            ta = ta or (0, 0, 0)
            tb = tb or (0, 0, 0)
            d["t"] = tuple(x + (y - x) * t for x, y in zip(ta, tb))
        out[k] = d
    return out
