"""face_preview -- composite Hush's face presets flat (as the shader layers them) for a quick look.

    python3 tools/art3d/hush/face_preview.py <face_dir with face_hush.png/.json> <faces.json> <out.png> [--px 160]

A look-at aid for iterating the atlas (the real check is on the head in Godot: faces_26.png / faces_game.png).
"""
import json
import sys

from PIL import Image, ImageDraw


def compose(atlas, info, preset, px, mirror=False):
    face = Image.new("RGBA", (px, px), (255, 246, 234, 255))
    grid = info["grid"][0]
    cell = info["atlas_px"] // grid
    mc = info.get("mirror_cells", {})
    for layer in info["draw_order"]:
        name = preset.get(layer)
        if name is None:
            continue
        if mirror and name in mc:
            name = mc[name]
        idx = info["cells"][layer][name]
        col, row = idx % grid, idx // grid
        im = atlas.crop((col * cell, row * cell, col * cell + cell, row * cell + cell))
        u0, v0, u1, v1 = info["layer_rects"][layer]
        w, h = max(1, round((u1 - u0) * px)), max(1, round((v1 - v0) * px))
        im = im.resize((w, h), Image.LANCZOS)
        if layer == "pupils":
            d = preset.get("gaze", [0, 0])
            ox, oy = round(d[0] * 0.022 * px), round(-d[1] * 0.035 * px)
        else:
            ox = oy = 0
        face.alpha_composite(im, (round(u0 * px) + ox, round((1 - v1) * px) + oy))
    return face


def main():
    face_dir, faces_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
    px = int(sys.argv[sys.argv.index("--px") + 1]) if "--px" in sys.argv else 160
    info = json.load(open(face_dir + "/face_hush.json"))
    ap = sys.argv[sys.argv.index("--atlas") + 1] if "--atlas" in sys.argv else face_dir + "/face_hush.png"
    atlas = Image.open(ap).convert("RGBA")
    presets = json.load(open(faces_path))["presets"]
    names = list(presets)
    cols = 7
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (px + 8), rows * (px + 22)), (46, 37, 64, 255))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        f = compose(atlas, info, presets[n], px)
        x, y = (i % cols) * (px + 8), (i // cols) * (px + 22)
        sheet.alpha_composite(f, (x + 4, y + 2))
        d.text((x + 6, y + px + 6), n, fill=(240, 230, 250, 255))
    sheet.save(out)
    print("FACE_PREVIEW", out)


if __name__ == "__main__":
    main()
