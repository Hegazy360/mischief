"""palette.json -> palette.png (8x8 cells of 16 px; emissive colours get alpha 0)."""
import json, os, sys
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
p = json.load(open(os.path.join(here, "palette.json")))["colors"]
img = Image.new("RGBA", (128, 128), (255, 0, 255, 255))
for i, c in enumerate(p):
    h = c[1].lstrip("#")
    col = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 0 if len(c) > 2 and c[2] else 255)
    x, y = (i % 8) * 16, (i // 8) * 16
    img.paste(col, (x, y, x + 16, y + 16))
img.save(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "palette.png"))
