"""python3 sheet.py out.png cols img1 img2 ... : simple contact sheet with file-name labels."""
import sys
from PIL import Image, ImageDraw
out, cols = sys.argv[1], int(sys.argv[2])
ims = [Image.open(p).convert("RGB") for p in sys.argv[3:]]
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
S = Image.new("RGB", (w * cols, (h + 16) * rows), (30, 26, 40))
d = ImageDraw.Draw(S)
for i, (im, p) in enumerate(zip(ims, sys.argv[3:])):
    x, y = (i % cols) * w, (i // cols) * (h + 16)
    S.paste(im.resize((w, h)), (x, y + 16))
    d.text((x + 4, y + 2), p.split("/")[-1], fill=(240, 230, 200))
S.save(out)
