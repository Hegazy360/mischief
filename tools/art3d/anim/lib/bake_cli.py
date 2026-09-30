#!/usr/bin/env python3
"""Plain-Python helper of tools/art3d/anim/bake.sh (no bpy): spec resolution, the converter job list, the result
table, DONE lines and the audio-rows report.

  bake_cli.py specs <rig> [clip ...|--all] [--changed]      -> one spec path per line
  bake_cli.py jobs <results.json> <jobs.json>               -> converter jobs from the Blender results
  bake_cli.py table <results.json> <convert.log>            -> the table; exit 1 on any failure
  bake_cli.py done <rig> <clip>                             -> "DONE <rig>/<clip> <sha256 of the spec>"
  bake_cli.py audio-rows <out.md>                           -> every audio="own" sidecar's sound rows
"""
import glob, hashlib, json, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
ANIM = os.path.join(ROOT, "tools/art3d/anim")
LIB = os.path.join(ANIM, "lib")


def spec_dir(rig):
    return os.path.join(ANIM, rig)


def res_path(rig, short):
    d = os.environ.get("BAKE_RES_DIR") or os.path.join(ROOT, "game/art3d/anim", rig)
    return os.path.join(d, short + ".res")


def all_specs(rig):
    return sorted(p for p in glob.glob(os.path.join(spec_dir(rig), "*.py")) if not os.path.basename(p).startswith("_"))


def resolve(rig, name):
    if name.endswith(".py") and os.path.exists(name):
        return os.path.abspath(name)
    short = name.split("/", 1)[1] if "/" in name else name
    p = os.path.join(spec_dir(rig), short + ".py")
    if not os.path.exists(p):
        sys.exit("bake: no spec %s (write tools/art3d/anim/%s/%s.py — see tools/art3d/anim/README.md)" % (p, rig, short))
    return p


def newest_input(rig):
    """The newest mtime of the pipeline library and the rig's skeleton: a clip older than it re-bakes on --changed."""
    ts = [os.path.getmtime(p) for p in glob.glob(os.path.join(LIB, "*.py"))]
    rg = os.environ.get("RIG_GLB") or os.path.join(ROOT, "game/art3d/chars/%s/%s.glb" % (rig, rig))
    if os.path.exists(rg):
        ts.append(os.path.getmtime(rg))
    shared = os.path.join(spec_dir(rig), "_lib")
    ts += [os.path.getmtime(p) for p in glob.glob(os.path.join(shared, "*.py"))]
    return max(ts) if ts else 0.0


def cmd_specs(args):
    rig = args[0]
    names = [a for a in args[1:] if not a.startswith("--")]
    flags = [a for a in args[1:] if a.startswith("--")]
    specs = all_specs(rig) if ("--all" in flags or "--changed" in flags) and not names else [resolve(rig, n) for n in names]
    if "--changed" in flags:
        base = newest_input(rig)
        out = []
        for p in specs:
            short = os.path.splitext(os.path.basename(p))[0]
            r = res_path(rig, short)
            if not os.path.exists(r) or os.path.getmtime(r) < max(os.path.getmtime(p), base):
                out.append(p)
        specs = out
    for p in specs:
        print(p)


def cmd_jobs(args):
    res = json.load(open(args[0]))
    rig = res["rig"]
    jobs = []
    for r in res["results"]:
        if not r.get("ok"):
            continue
        short = r["clip"].split("/", 1)[1]
        jobs.append({"in": r["glb"], "out": res_path(rig, short), "clip": r["clip"], "sidecar": r["sidecar"],
                     "rig_glb": res.get("rig_glb", "")})
    json.dump(jobs, open(args[1], "w"), indent=1)
    print(len(jobs))


def cmd_table(args):
    res = json.load(open(args[0]))
    conv = {}
    if os.path.exists(args[1]):
        for line in open(args[1]):
            if line.startswith("[glb_to_res] "):
                try:
                    d = json.loads(line[len("[glb_to_res] "):])
                    conv[d.get("clip")] = d
                except ValueError:
                    pass
    rows = []
    bad = 0
    for r in res["results"]:
        cid = r.get("clip", r.get("spec") or "?")
        c = conv.get(cid, {})
        if not r.get("ok"):
            status = "BAKE FAILED: " + r.get("error", "?")
            bad += 1
        elif not c:
            status = "NOT CONVERTED"
            bad += 1
        elif not c.get("ok"):
            status = "CONVERT FAILED: " + c.get("error", "?")
            bad += 1
        elif c.get("lint_errors", 0) > 0:
            status = "LINT: %d error(s), %d warning(s)" % (c["lint_errors"], c.get("lint_warnings", 0))
            bad += 1
        else:
            status = "OK" + (" (%d warning(s))" % c["lint_warnings"] if c.get("lint_warnings") else "")
        rows.append((cid, str(r.get("frames", "")), "loop" if r.get("loop") else "", "%.1f" % r["max_deg_f"] if "max_deg_f" in r else "",
                     str(r.get("ms", "")), "%.0f" % (c.get("bytes", 0) / 1024.0) if c.get("bytes") else "", status))
    head = ("clip", "frames", "", "max°/f", "bake ms", "KB", "status")
    w = [max(len(x[i]) for x in rows + [head]) for i in range(len(head))]
    for row in [head] + rows:
        print("  ".join(row[i].ljust(w[i]) for i in range(len(head))))
    sys.exit(1 if bad else 0)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def cmd_done(args):
    rig, clip = args[0], args[1]
    p = resolve(rig, clip)
    short = os.path.splitext(os.path.basename(p))[0]
    print("DONE %s/%s %s" % (rig, short, sha(p)))


def cmd_audio_rows(args):
    sys.path.insert(0, os.path.dirname(LIB))
    from lib import events as EV   # noqa: E402  (plain module: no bpy)
    scs = []
    for p in sorted(glob.glob(os.path.join(ROOT, "game/data/anim/*3d/*.json"))):
        b = os.path.basename(p)
        if b in ("map.json", "rig_actions.json"):
            continue
        try:
            d = json.load(open(p))
        except ValueError:
            continue
        if d.get("format") == "anim3d" and (d.get("source") or {}).get("audio") == "own":
            scs.append(d)
    open(args[0], "w").write(EV.rows_md(scs))
    print("%d own-audio clip(s) -> %s" % (len(scs), args[0]))


if __name__ == "__main__":
    cmd = sys.argv[1]
    {"specs": cmd_specs, "jobs": cmd_jobs, "table": cmd_table, "done": cmd_done, "audio-rows": cmd_audio_rows}[cmd](sys.argv[2:])
