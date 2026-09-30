"""Print a glTF/glb summary: meshes, skins (joint names), animations (name, duration)."""
import json, struct, sys, os
p = sys.argv[1]
if p.endswith(".glb"):
    b = open(p, "rb").read()
    n = struct.unpack_from("<I", b, 12)[0]
    j = json.loads(b[20:20 + n])
else:
    j = json.load(open(p))
print("meshes", len(j.get("meshes", [])), "nodes", len(j.get("nodes", [])), "materials", len(j.get("materials", [])), "images", len(j.get("images", [])))
for s in j.get("skins", []):
    names = [j["nodes"][i].get("name") for i in s["joints"]]
    print("skin joints", len(names), ":", " ".join(names[:80]))
acc = j.get("accessors", [])
anims = []
for a in j.get("animations", []):
    t = 0.0
    for sm in a["samplers"]:
        m = acc[sm["input"]].get("max")
        if m: t = max(t, m[0])
    anims.append((a.get("name"), round(t, 2)))
print("animations", len(anims))
for nm, t in anims:
    print(f"  {nm}\t{t}s")
