"""write_rig -- Hush's rig descriptor + face presets from the build outputs (plain python, no Blender).

    python3 tools/art3d/hush/write_rig.py --meta <build meta.json> --face <face_hush.json> \
        [--variant head_b] [--out game/data/rigs3d/hush]

Writes <out>/rig3d.json (or rig3d_<variant>.json) -- the r3d-index §7.3 contract -- and <out>/faces.json: all 26 presets
of the 2D `game/data/rigs/hush/faces.json` by their 2D names, each {eyes, brows, pupils, gaze, mouth, extra_a,
extra_b} cells of the 3D atlas (nearest match of the 2D slot variants; 2D pupils directions become pupil_dir).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FACES_2D = os.path.join(REPO, "game", "data", "rigs", "hush", "faces.json")

PUPIL_DIR = {"centre": [0.0, 0.0], "left": [-1.0, 0.0], "right": [1.0, 0.0], "up": [0.0, 1.0], "down": [0.0, -1.0],
             "down_left": [-0.8, -0.8], "up_right": [0.8, 0.8]}
# 3D refinements of the 2D vocabulary (brief 4.4 "fix any that read alike"): each is a cell the 2D rig did not have
OVERRIDES = {
    "dazed": {"eyes": "spiral"},        # 2D dazed (half eyes + worried + wavy) read as "sad"; the dizzy spiral reads at 1x
}

JIGGLE = [
    {"bones": ["beret", "beret_stalk"], "stiffness": 3.2, "drag": 0.45, "gravity": 0.25, "radius": 0.05, "clamp_deg": 28},
    {"bones": ["hair_l"], "stiffness": 4.5, "drag": 0.55, "gravity": 0.35, "radius": 0.03, "clamp_deg": 18},
    {"bones": ["hair_r"], "stiffness": 4.5, "drag": 0.55, "gravity": 0.35, "radius": 0.03, "clamp_deg": 18},
    {"bones": ["brace_l"], "stiffness": 7.0, "drag": 0.65, "gravity": 0.10, "radius": 0.02, "clamp_deg": 8},
    {"bones": ["brace_r"], "stiffness": 7.0, "drag": 0.65, "gravity": 0.10, "radius": 0.02, "clamp_deg": 8},
    {"bones": ["clarence_body"], "stiffness": 2.6, "drag": 0.30, "gravity": 0.45, "radius": 0.04, "clamp_deg": 32},
    {"bones": ["clarence_comb"], "stiffness": 5.0, "drag": 0.30, "gravity": 0.15, "radius": 0.015, "clamp_deg": 24},
]


def args():
    argv = sys.argv[1:]
    opt = {}
    for i in range(0, len(argv) - 1, 2):
        opt[argv[i].lstrip("-")] = argv[i + 1]
    return opt


def presets_3d(cells: dict) -> dict:
    src = json.load(open(FACES_2D))["presets"]
    out = {}
    for name, p in src.items():
        e = {
            "eyes": p["eyes"],
            "brows": p["brows"],
            "pupils": None if p.get("pupils", "none") == "none" else "centre",
            "gaze": PUPIL_DIR.get(p.get("pupils", "centre"), [0.0, 0.0]),
            "mouth": p["mouth"],
            "extra_a": "blush" if p.get("blush") == "on" else "cheeks",
            "extra_b": "sweat" if p.get("sweat") == "on" else ("tear" if p.get("tear") == "on" else None),
        }
        e.update(OVERRIDES.get(name, {}))
        for layer in ("eyes", "brows", "pupils", "mouth", "extra_a", "extra_b"):
            if e[layer] is not None and e[layer] not in cells[layer]:
                raise SystemExit("preset %s: %s cell %s missing from the atlas" % (name, layer, e[layer]))
        out[name] = e
    return out


def main():
    opt = args()
    meta = json.load(open(opt["meta"]))
    face = json.load(open(opt["face"]))
    variant = opt.get("variant", "")
    out_dir = opt.get("out", os.path.join(REPO, "game", "data", "rigs3d", "hush"))
    os.makedirs(out_dir, exist_ok=True)
    glb = "hush.glb" if not variant else "hush_%s.glb" % variant
    cells = face["cells"]
    presets = presets_3d(cells)
    faces = {
        "version": 1, "rig": "hush",
        "doc": ("Hush's 3D face presets: the 26 presets of the 2D data/rigs/hush/faces.json by their 2D names, each a cell "
                "per layer of face_hush.png (rig3d.json face.cells); pupils null = no pupil layer (the eye cell bakes its "
                "own); gaze = the resting pupil offset (the 2D pupils direction) as -1..1 of face.pupil_range (u right as seen from the front, "
                "v up). statue / statue_blink keep the eyes coloured through the stone-keep mask (COLOR.g on the face card)."),
        "presets": presets,
    }
    rig = {
        "version": 1, "rig": "hush",
        "doc": ("Hush (R3D): look B's body dimensions in look A's Toy Box vinyl style. Built by tools/art3d/hush/build.sh "
                "(skeleton contract tools/art3d/hush/skeleton.json). Sockets: pos in the bone's local rest frame "
                "(Y along the bone), model_pos = the same point in model space at rest (Godot axes, for tests)."),
        "variant": variant,
        "scene": "res://art3d/chars/hush/%s" % glb,
        "skeleton": "Armature/Skeleton3D",
        "mesh": "Armature/Skeleton3D/hush_body",
        "height_m": round(meta["height_m"], 3),
        "head_scale": meta["head_scale"],
        "tris": meta["tris"],
        "deform_bones": meta["deform_bones"],
        "bones": {"root": "root", "pelvis": "pelvis", "spine_top": "spine_03", "neck": "neck_01", "head": "Head",
                  "hand_l": "hand_l", "hand_r": "hand_r", "foot_l": "foot_l", "foot_r": "foot_r"},
        "sockets": meta["sockets"],
        "props": {
            "clarence": {"bone": "prop_clarence", "states": {"brace": "brace_r", "held": "grip_r", "squeeze": "grip_r"},
                         "default": "brace", "squash_bone": "clarence_body"},
            "pepper_pot": {"bone": "prop_r", "states": {"held": "grip_r", "hidden": "hidden"}, "default": "hidden",
                           "fx_bone": "fx_pepper"},
        },
        "attachments": {},
        "slots": {},
        "anim": {"layers": []},
        "jiggle": JIGGLE,
        "face": {
            "atlas": "res://art3d/chars/hush/face_hush.png", "atlas_px": face["atlas_px"], "grid": face["grid"],
            "uv": "TEXCOORD_1 (UV2): planar face square; fuv = (UV2.x, 1 - UV2.y) = (u right as seen from the front, v up); "
                  "layer cell uv = ((col + lu) / 8, (row + 1 - lv) / 8), lu/lv = fuv inside the layer rect",
            "layers": face["layers"], "draw_order": face["draw_order"], "layer_rects": face["layer_rects"],
            "cells": {k: v for k, v in cells.items() if k != "card"},
            "card_cells": cells.get("card", {}),
            "pupil_range": [0.022, 0.035],
            "presets": "res://data/rigs3d/hush/faces.json",
            "blink": {"every_s": [2.0, 6.0], "frames": 6, "cell": "closed", "half_cell": "half",
                      "blinkable": ["open", "wide", "half", "worried"]},
            "no_pupils": ["closed", "half", "happy", "wink", "wink_m", "squint", "worried", "spiral"],
            "mirror_cells": face["mirror_cells"],
            "mirror_pupil_x": True,
            "default": "neutral",
        },
        "material": {"palette": "res://art3d/chars/hush/palette_hush.png", "outline_px": 3.5, "rim": 0.45},
        "vertex_color": {"r": "skin_tint", "g": "stone_keep", "b": "rim_damp", "a": "outline_scale"},
        "looks": {},
        "tint": {"tiers": ["#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF"], "livid": "#FFFFFF"},
        "stone": {"color": "#E8E6E1", "keep": ["eyes", "beret", "braces"], "plinth": "res://art3d/chars/hush/plinth.glb"},
        "cheat": {"idle": 35, "walk": 20, "perform": 35, "face_to_face": 5},
        "blob_shadow_r": 0.34,
        "skins": {},
    }
    name = "rig3d.json" if not variant else "rig3d_%s.json" % variant
    with open(os.path.join(out_dir, name), "w") as f:
        json.dump(rig, f, indent=2)
        f.write("\n")
    if not variant:
        with open(os.path.join(out_dir, "faces.json"), "w") as f:
            json.dump(faces, f, indent=2)
            f.write("\n")
    print("RIG_OK", os.path.join(out_dir, name), "presets", len(presets))


if __name__ == "__main__":
    main()
