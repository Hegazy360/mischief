"""glb_strip -- drop the embedded images from a .glb, keep every mesh attribute (UV0, the FaceUV TEXCOORD_1, COLOR_0).

    python3 tools/art3d/hush/glb_strip.py <in.glb> [<out.glb>]

Blender's glTF exporter only writes a UV map that a material texture uses, so build.py keeps the palette (UV0) and the
face atlas (FaceUV) on the material while exporting; this step then removes images / textures / samplers and the
material's texture references and repacks the binary chunk. The palette and the atlas ship as their own PNGs
(`palette_hush.png`, `face_hush.png`, named in rig3d.json) so Godot's import never extracts duplicates next to the glb.
"""
import json
import struct
import sys


def strip(src: str, dst: str) -> dict:
    data = open(src, "rb").read()
    magic, version, _length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67 and version == 2, "not a glb v2"
    off = 12
    js, binc = None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    drop_views = {img["bufferView"] for img in js.get("images", []) if "bufferView" in img}
    for k in ("images", "textures", "samplers"):
        js.pop(k, None)
    for m in js.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        for k in ("baseColorTexture", "metallicRoughnessTexture"):
            pbr.pop(k, None)
        for k in ("emissiveTexture", "normalTexture", "occlusionTexture"):
            m.pop(k, None)
        m.pop("emissiveFactor", None)
        exts = m.get("extensions", {})
        exts.pop("KHR_materials_emissive_strength", None)
        if not exts:
            m.pop("extensions", None)
    used = js.get("extensionsUsed", [])
    js["extensionsUsed"] = [e for e in used if e != "KHR_materials_emissive_strength"]
    if not js["extensionsUsed"]:
        js.pop("extensionsUsed")
    views = js.get("bufferViews", [])
    remap, new_views, blob = {}, [], bytearray()
    for i, v in enumerate(views):
        if i in drop_views:
            continue
        start = v.get("byteOffset", 0)
        piece = binc[start: start + v["byteLength"]]
        while len(blob) % 4:
            blob += b"\x00"
        nv = dict(v)
        nv["byteOffset"] = len(blob)
        blob += piece
        remap[i] = len(new_views)
        new_views.append(nv)
    js["bufferViews"] = new_views
    for a in js.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    while len(blob) % 4:
        blob += b"\x00"
    js["buffers"] = [{"byteLength": len(blob)}]
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(jb) % 4:
        jb += b" "
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(blob))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    open(dst, "wb").write(out)
    return {"in_bytes": len(data), "out_bytes": len(out), "dropped_views": len(drop_views)}


if __name__ == "__main__":
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src
    print("GLB_STRIP", dst, strip(src, dst))
