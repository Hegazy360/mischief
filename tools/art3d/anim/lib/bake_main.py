"""Blender entry of tools/art3d/anim/bake.sh (one process for every listed clip):

  blender -b --factory-startup --threads 1 --python tools/art3d/anim/lib/bake_main.py -- \
      --rig hush --rig-glb /abs/hush.glb --out /abs/build/art3d/anim/hush --results /abs/results.json \
      [--spec /abs/tools/art3d/anim/hush/loco_idle.py ...] [--ual Walk_Loop --as hush/ual_walk --layers mime,damp_head]

Imports the rig's armature from its .glb (never edits the file), then for every spec: build(ctx) -> Clip, audio
table merge (R3), per-frame evaluation, one action keyed on every bone (linear, every frame), export
`<out>/<clip>.glb` (armature + that action, no mesh), the sidecar `game/data/anim/<rig>3d/<clip>.json`, a bake.log
line. Failures are per clip (the others still bake); results.json lists every clip with ok / error.
"""
import bpy, sys, os, json, time, traceback, importlib.util, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))          # tools/art3d/anim -> `import lib.*`

from lib import pose as P
from lib import clip as C
from lib import events as EV
from lib import stage as ST
from lib import export as X


def parse(argv):
    a = argv[argv.index("--") + 1:] if "--" in argv else []
    opt = {"spec": [], "layers": ""}
    i = 0
    while i < len(a):
        k = a[i].lstrip("-")
        v = a[i + 1] if i + 1 < len(a) else ""
        if k == "spec":
            opt["spec"].append(v)
        else:
            opt[k] = v
        i += 2
    return opt


def load_spec(path):
    name = "spec_" + hashlib.sha1(path.encode()).hexdigest()[:10]
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.path.insert(0, os.path.dirname(path))
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.path.pop(0)
    return mod


def main():
    opt = parse(sys.argv)
    rig = opt["rig"]
    root = ST.repo_root()
    rig_glb = opt.get("rig-glb") or os.path.join(root, "game/art3d/chars/%s/%s.glb" % (rig, rig))
    out_dir = opt["out"]
    os.makedirs(out_dir, exist_ok=True)
    sidecar_dir = opt.get("sidecars") or os.path.join(root, "game/data/anim/%s3d" % rig)
    rig3d_path = opt.get("rig3d") or os.path.join(root, "game/data/rigs3d/%s/rig3d.json" % rig)
    rig3d = json.load(open(rig3d_path)) if os.path.exists(rig3d_path) else {}
    t0 = time.time()
    arm = X.import_rig(rig_glb)
    skel = P.Skel.from_armature(arm)
    ctx = C.Ctx(rig, skel, rig3d, root, arm)
    ctx.rig_glb = rig_glb
    libs = {}

    def ual(name):
        from lib import ual as U
        if name not in libs:
            libs[name] = U.Library(name)
        return libs[name]
    ctx.ual_lib = ual
    print("[bake] rig %s from %s: %d bones (%d extra), descriptor %s, import %.1fs" % (
        rig, rig_glb, len(skel.names), len(skel.extras()), "yes" if rig3d else "no (stand-in)", time.time() - t0))
    results = []
    jobs = [("spec", p) for p in opt["spec"]]
    if opt.get("ual"):
        jobs.append(("ual", opt["ual"]))
    for kind, arg in jobs:
        t1 = time.time()
        rec = {"spec": arg if kind == "spec" else None, "ok": False}
        try:
            if kind == "spec":
                mod = load_spec(arg)
                clip = mod.build(ctx)
                clip.source = dict(clip.source)
                clip.source.setdefault("kind", "custom")
                clip.source["script"] = os.path.relpath(arg, root)
            else:
                clip = X.ual_clip(ctx, arg, opt.get("as") or ("%s/ual_%s" % (rig, arg.lower())),
                                  [l for l in opt.get("layers", "").split(",") if l], opt.get("lib", ""))
            rec["clip"] = clip.id
            clip.check()
            warns = EV.apply(clip)
            exp = EV.expected(clip.id)
            if exp and exp["expect"] > 0 and exp["expect"] != clip.length and abs(exp["expect"] - clip.length) > exp["tol"] and not (clip.loop and exp["loop"]):
                warns.append("manifest expects %d f (± %d), the clip has %d" % (exp["expect"], exp["tol"], clip.length))
            frames = clip.frames()
            glb = os.path.join(out_dir, clip.short + ".glb")
            X.write_action(arm, skel, clip, frames)
            X.export(arm, glb)
            res = "%s/%s.res" % (opt.get("res-prefix") or ("res://art3d/anim/%s" % rig), clip.short)
            sc = clip.sidecar(res)
            sc["source"]["audio"] = clip.audio
            os.makedirs(sidecar_dir, exist_ok=True)
            X.write_sidecar(os.path.join(sidecar_dir, clip.short + ".json"), sc)
            mx, mn, mf = clip.max_speed_deg(frames)
            ms = (time.time() - t1) * 1000
            rec.update({"ok": True, "glb": glb, "sidecar": os.path.join(sidecar_dir, clip.short + ".json"), "frames": clip.length,
                        "loop": clip.loop, "max_deg_f": round(mx, 2), "max_bone": mn, "max_f": mf, "ms": int(ms), "warnings": warns})
            X.log_line(out_dir, "%s frames=%d loop=%s max=%.1f°/f (%s f%d) bake=%dms%s" % (
                clip.id, clip.length, clip.loop, mx, mn, mf, ms, "".join(" WARN " + w for w in warns)))
            for w in warns:
                print("[bake] WARNING %s: %s" % (clip.id, w))
            print("[bake] OK %s %d f, max %.1f°/f, %d ms" % (clip.id, clip.length, mx, ms))
        except Exception as e:
            rec["error"] = "%s: %s" % (type(e).__name__, e)
            traceback.print_exc()
            print("[bake] FAILED %s: %s" % (rec.get("clip", arg), rec["error"]))
        results.append(rec)
    with open(opt["results"], "w") as f:
        json.dump({"rig": rig, "rig_glb": rig_glb, "results": results}, f, indent=1)
    print("[bake] %d clip(s), %d ok, %.1fs" % (len(results), sum(1 for r in results if r["ok"]), time.time() - t0))


main()
