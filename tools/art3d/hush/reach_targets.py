"""reach_targets -- the reach proof numbers (index R5b/R5f, brief 4.2 "Reach proof first").

    python3 tools/art3d/hush/reach_targets.py [--out build/art3d/hush/reach_targets.json]

Reads the placed reach targets from game/data/house/house3d.json (+ the frozen house.json rects) with the §7.4 prop
frame: origin = (rect centre-x + visual_offset.x, rect bottom-y + visual_offset.y, prop z), anchors in metres before
`scale`. For each proof pose it places Hush at the hotspot's `reach_pos` (x = use_x + dx, z, the step), faces her at the
target, and writes the target in her armature space (Blender axes) for board_poses.py, plus the R5b distance: from the
nearer shoulder (y 1.127 + 0.07 tiptoe in the high band + step_h, x +-0.118 across her facing) to the target (<= 0.50 m).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
H3D = os.path.join(REPO, "game", "data", "house", "house3d.json")
H2D = os.path.join(REPO, "game", "data", "house", "house.json")
SHOULDER_Y, SHOULDER_X, TIPTOE, MAX_M = 1.127, 0.118, 0.07, 0.50


def world_target(hid, h3, h2):
    e = h3["hotspots"][hid]
    hs = {x["id"]: x for x in h2["hotspots"]} if isinstance(h2["hotspots"], list) else h2["hotspots"]
    r = hs[hid]["rect"]
    vo = e.get("visual_offset") or [0.0, 0.0]
    ox = (r[0] + r[2] / 2.0) / 200.0 + vo[0]
    oy = -(r[1] + r[3]) / 200.0 + vo[1]
    oz = e["z"]
    t = e["reach_target"]
    k = e.get("scale", 1.0)
    return [ox + t[0] * k, oy + t[1] * k, oz + t[2] * k], hs[hid]["use_x"] / 200.0, e


def to_local(w, pos, yaw):
    """world (Godot) -> Hush's armature space (Blender axes) for a model at pos, turned by yaw about +Y."""
    dx, dy, dz = w[0] - pos[0], w[1] - pos[1], w[2] - pos[2]
    c, s = math.cos(-yaw), math.sin(-yaw)
    lx = c * dx + s * dz
    lz = -s * dx + c * dz
    return [lx, -lz, dy]


CHEAT_DEG = 10.0      # R5d: rig clips reach at cheat <= 10 deg (she faces along the lane, the arm reaches back)


def proof_row(name, w, pos, step_h, band, extra):
    face = -1.0 if w[0] < pos[0] else 1.0
    yaw = math.radians(face * (90.0 - CHEAT_DEG))
    # nearer shoulder: +-0.118 across her facing
    fx, fz = math.sin(yaw), math.cos(yaw)
    rx, rz = -fz, fx     # her right (Godot) = facing x up
    sy = SHOULDER_Y + (TIPTOE if band == "high" else 0.0) + step_h + extra.get("pelvis_up", 0.0) - extra.get("kneel_drop", 0.0)
    best = None
    for side, k in (("r", 1.0), ("l", -1.0)):
        sp = [pos[0] + rx * SHOULDER_X * k, sy, pos[2] + rz * SHOULDER_X * k]
        d = math.dist(sp, w)
        if best is None or d < best[1]:
            best = (side, d, sp)
    return {"world_target": [round(v, 4) for v in w], "hush_pos": [round(v, 4) for v in pos], "yaw_deg": round(math.degrees(yaw), 2),
            "band": band, "step_h": step_h, "nearer_shoulder": best[0], "shoulder_world": [round(v, 4) for v in best[2]],
            "shoulder_to_target_m": round(best[1], 4), "ok": best[1] <= MAX_M, "facing": int(face),
            "target_b": [round(v, 4) for v in to_local(w, pos, yaw)],
            "look_b": [round(v, 4) for v in to_local([pos[0], 1.9, pos[2] + 7.5], [pos[0], 1.4, pos[2]], yaw)]}


def main():
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(REPO, "build", "art3d", "hush", "reach_targets.json")
    h3, h2 = json.load(open(H3D)), json.load(open(H2D))
    rows = {}
    # (a) ACHOO-RIA!: on Bellows' stool, the pepper pot over the honey jar
    w, use_x, e = world_target("kitchen_honey", h3, h2)
    rp = e["reach_pos"]
    pos = [use_x + rp["dx"], 0.0, rp["z"]]
    r = proof_row("high_stool", w, pos, rp.get("step_h", 0.0), e.get("reach", "high"), {})
    r.update({"feet_y": rp.get("step_h", 0.0), "tiptoe": TIPTOE, "pot": True, "hotspot": "kitchen_honey",
              "step": rp.get("step")})
    sp = [w[0], w[1] + 0.03, w[2]]     # the spout just above the placed reach target (the jar mouth of §7.4)
    r["spout_b"] = [round(v, 4) for v in to_local(sp, pos, math.radians(r["yaw_deg"]))]
    rows["ReachHigh_Stool"] = r
    # (b) both gloves on the gramophone lever (~1.0 m, reach row)
    w, use_x, e = world_target("parlour_gramophone", h3, h2)
    rp = e["reach_pos"]
    pos = [use_x + rp["dx"], 0.0, rp["z"]]
    r = proof_row("mid_lever", w, pos, rp.get("step_h", 0.0), e.get("reach", "mid"), {})
    r.update({"both": True, "hotspot": "parlour_gramophone"})
    rows["ReachMid_Lever"] = r
    # (c) the mime step (pelvis +0.40) reaching a 2.0 m target in the kitchen reach row
    pos = [16.6, 0.0, -1.6]
    w = [16.48, 2.0, -1.72]
    r = proof_row("mime_step", w, pos, 0.0, "high", {"pelvis_up": 0.40})
    r.update({"pelvis_up": 0.40, "tiptoe": 0.0})
    rows["ReachHigh_MimeStep"] = r
    # (d) kneeling at a 0.4 m target (the low band)
    pos = [17.4, 0.0, -1.6]
    w = [17.26, 0.40, -1.72]
    r = proof_row("kneel", w, pos, 0.0, "low", {"kneel_drop": 0.42})
    r.update({"kneel": True})
    rows["ReachLow_Kneel"] = r
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump({"doc": __doc__.strip().splitlines()[0], "max_m": MAX_M, "poses": rows}, open(out, "w"), indent=1)
    for k, v in rows.items():
        print("REACH %-20s shoulder->target %.3f m  %s  (target %s, Hush at %s yaw %.1f)" % (
            k, v["shoulder_to_target_m"], "OK" if v["ok"] else "FAIL", v["world_target"], v["hush_pos"], v["yaw_deg"]))


if __name__ == "__main__":
    main()
