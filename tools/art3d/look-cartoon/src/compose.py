"""PIL helpers for the look-dev sheets (labels in the project's OFL fonts)."""
from PIL import Image, ImageDraw, ImageFont
F = "/home/user/mischief/game/ui/theme/fonts/"


def font(sz, kind="LilitaOne-Regular.ttf"):
    return ImageFont.truetype(F + kind, sz)


def label(im, xy, text, sz=34, fill=(43, 30, 48), kind="LilitaOne-Regular.ttf", anchor="la"):
    d = ImageDraw.Draw(im)
    d.text(xy, text, font=font(sz, kind), fill=fill, anchor=anchor)


def title_bar(w, text, sub="", h=90, bg=(43, 30, 58), fg=(255, 236, 190)):
    im = Image.new("RGB", (w, h), bg)
    label(im, (28, h // 2), text, 44, fg, anchor="lm")
    if sub:
        label(im, (w - 28, h // 2), sub, 26, (220, 205, 230), "Nunito-Bold.ttf", anchor="rm")
    return im


def stack(ims, bg=(237, 228, 216)):
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims)
    out = Image.new("RGB", (w, h), bg)
    y = 0
    for i in ims:
        out.paste(i, (0, y))
        y += i.height
    return out
