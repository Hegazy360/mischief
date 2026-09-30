"""Owner board: the three 3D look-devs side by side.

Reads only the look-dev deliverables (and three frames of each sneeze sequence) from
../look-{toy,cartoon,puppet}/ and writes board.png. Fonts: the game's own OFL fonts.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = '/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/3d'
FONTS = '/home/user/mischief/game/ui/theme/fonts'
OUT = sys.argv[1] if len(sys.argv) > 1 else ROOT + '/board/board.png'

def font(name, size):
    return ImageFont.truetype(f'{FONTS}/{name}.ttf', size)

LILITA = lambda s: font('LilitaOne-Regular', s)
BLACK = lambda s: font('Nunito-Black', s)
XBOLD = lambda s: font('Nunito-ExtraBold', s)
BOLD = lambda s: font('Nunito-Bold', s)

BG = (20, 25, 44)
PANEL = (31, 38, 64)
CREAM = (255, 244, 219)
GREY = (178, 184, 207)
DIM = (128, 134, 160)

W = 2400
M = 24            # outer margin
G = 24            # gutter between columns
CW = (W - 2 * M - 2 * G) // 3   # 768
PAD = 0           # images fill the column width

STYLES = [
    dict(key='toy', letter='A', name='Toy Box', accent=(255, 107, 107),
         tag='Chunky vinyl toys: big heads, painted-on faces, soft matte colours.',
         facts='Hush 1.58 m · Bellows 1.74 m · ~15k triangles each · smooth motion',
         caption='Hush sneaks in, paws at her chin. Bellows sips tea on his stool, pinkie up.',
         turn=[(40, 225, 1790, 795), (40, 950, 1790, 1552)],
         expr=[(20, 150, 2420, 552), (20, 640, 2420, 1040)],
         seq=('look-toy/out/seq', [30, 36, 56]),
         scores=[('Appeal', '8'), ('Reads at phone size', '8.5'), ('Buildable', '7'), ('Phone perf', '7.5')],
         pick=True),
    dict(key='cartoon', letter='B', name='Saturday Cartoon', accent=(255, 200, 56),
         tag='Stretchy TV-cartoon people: long limbs, 3D eyes, painted mouths.',
         facts='Hush 1.60 m · Bellows 1.78 m · ~10k triangles each · smooth motion',
         caption='Bellows sips tea from cup and saucer. Hush snickers to the audience by the pantry.',
         turn=[(200, 170, 2380, 938), (200, 1075, 2380, 1838)],
         expr=[(0, 108, 2400, 610), (0, 694, 2400, 1186)],
         seq=('look-cartoon/work/seq_sneeze', [88, 132, 176]),
         scores=[('Appeal', '6'), ('Reads at phone size', '6.5'), ('Buildable', '7.5'), ('Phone perf', '8.5')],
         pick=False),
    dict(key='puppet', letter='C', name='Stop-Motion Puppet', accent=(95, 211, 191),
         tag='Felt-and-clay puppets: bead eyes, clay mouths, stop-motion steps.',
         facts='Hush 1.72 m · Bellows 1.72 m · ~17k triangles each · stepped motion',
         caption='Hush peppers the honey jar (shh!). Bellows sips tea. C also re-dressed the set: '
                 'wallpaper, tiles, velvet valance, footlights.',
         turn=[(60, 262, 2140, 1142), (60, 1328, 2140, 2180)],
         expr=[(0, 192, 2400, 634), (0, 744, 2400, 1226)],
         seq=('look-puppet/out/sneeze_seq', [69, 78, 126]),
         scores=[('Appeal', '7.5'), ('Reads at phone size', '7'), ('Buildable', '6.5'), ('Phone perf', '5')],
         pick=False),
]

SEQ_BOX = (520, 100, 1100, 480)   # kitchen action area of a 1200x540 game frame


def load(rel):
    return Image.open(f'{ROOT}/{rel}').convert('RGB')


def fit_w(im, w):
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def rounded(im, r=14):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    return im, mask


def paste_r(canvas, im, xy, r=14):
    im, mask = rounded(im, r)
    canvas.paste(im, xy, mask)


def stack(ims, gap=0, bg=(0, 0, 0)):
    w = max(i.width for i in ims)
    h = sum(i.height for i in ims) + gap * (len(ims) - 1)
    out = Image.new('RGB', (w, h), bg)
    y = 0
    for i in ims:
        out.paste(i, ((w - i.width) // 2, y))
        y += i.height + gap
    return out


def wrap(draw, text, fnt, width):
    words, lines, cur = text.split(), [], ''
    for wd in words:
        t = (cur + ' ' + wd).strip()
        if draw.textlength(t, font=fnt) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def text_block(draw, xy, text, fnt, fill, width, lh):
    x, y = xy
    for ln in wrap(draw, text, fnt, width):
        draw.text((x, y), ln, font=fnt, fill=fill)
        y += lh
    return y


# ---------- build the per-style panels ----------
for s in STYLES:
    k = s['key']
    s['ingame'] = fit_w(load(f'look-{k}/ingame_kitchen.png'), CW)
    src = load(f'look-{k}/turnaround.png')
    rows = [src.crop(b) for b in s['turn']]
    bgc = src.getpixel((5, s['turn'][0][1] + 5))
    s['turnaround'] = fit_w(stack(rows, 0, bgc), CW)
    src = load(f'look-{k}/expressions.png')
    rows = [src.crop(b) for b in s['expr']]
    s['faces'] = fit_w(stack(rows, 0, src.getpixel((5, s['expr'][0][1] + 5))), CW)
    d, ids = s['seq']
    fw = (CW - 2 * 9) // 3
    s['sneeze'] = [fit_w(load(f'{d}/frame_{n:03d}.png').crop(SEQ_BOX), fw) for n in ids]

H_TURN = 560
for s in STYLES:
    t = s['turnaround']
    if t.height > H_TURN:
        s['turnaround'] = t.resize((round(t.width * H_TURN / t.height), H_TURN), Image.LANCZOS)
H_FACE = max(s['faces'].height for s in STYLES)
H_IN = STYLES[0]['ingame'].height
H_SN = STYLES[0]['sneeze'][0].height

# ---------- layout (y positions) ----------
y_title = 28
y_cols = 196                      # column panels start
HEAD_H = 188                      # column header block
BAND_H = 58                       # section title band
CAP_H = 70                        # caption under the in-game shot
LAB_H = 34                        # label line under faces / sneeze

y = y_cols + HEAD_H
sections = []
for title, h, extra in [
        ('1   In the game: the kitchen at the game camera (1200 × 540, a phone held sideways)', H_IN, CAP_H),
        ('2   Turnaround: front · 3/4 · side · back (Hush on top, Bellows below)', H_TURN, 0),
        ('3   Faces: neutral · sneaky grin (Bellows: pompous) · shock · furious · sneeze build · dazed', H_FACE, LAB_H),
        ('4   The ACHOO-RIA! gag at game scale: the AHHH… build · CHOO! · dazed in the sink', H_SN, LAB_H)]:
    sections.append((title, y, h, extra))
    y += BAND_H + h + extra + 16
y_scores = y
SCORE_H = 118
y_cols_end = y_scores + SCORE_H
H = y_cols_end + 150

cv = Image.new('RGB', (W, H), BG)
dr = ImageDraw.Draw(cv)

# ---------- title ----------
dr.text((M + 4, y_title), 'Mischief Next Door: choose the 3D look', font=LILITA(66), fill=CREAM)
sub = ('Three looks for Hush and Horace Bellows, built for this review and rendered in Godot on the phone renderer. '
       'All three stand in the same test kitchen under the same game camera. Judge the characters, not the room: '
       'the house gets simplified the same way whichever look wins.')
text_block(dr, (M + 6, y_title + 88), sub, XBOLD(25), GREY, W - 2 * M - 12, 34)

# ---------- columns ----------
for ci, s in enumerate(STYLES):
    x0 = M + ci * (CW + G)
    ac = s['accent']
    dr.rounded_rectangle((x0 - 10, y_cols, x0 + CW + 10, y_cols + HEAD_H - 14), 22, fill=PANEL)
    dr.rounded_rectangle((x0 - 10, y_cols, x0 + CW + 10, y_cols + 10), 5, fill=ac)
    for (title, sy, h, extra) in sections:
        dr.rounded_rectangle((x0 - 10, sy + BAND_H - 10, x0 + CW + 10, sy + BAND_H + h + extra + 4), 20, fill=PANEL)
    dr.rounded_rectangle((x0 - 10, y_scores - 4, x0 + CW + 10, y_cols_end), 20, fill=PANEL)
    # header
    hy = y_cols + 26
    dr.text((x0 + 8, hy), f"{s['letter']}: {s['name']}", font=LILITA(62), fill=ac)
    if s['pick']:
        lw = dr.textlength("Reviewer's pick", font=BLACK(21))
        bx = x0 + CW - lw - 34
        dr.rounded_rectangle((bx, hy + 14, x0 + CW - 6, hy + 52), 19, outline=ac, width=3)
        dr.text((bx + 14, hy + 20), "Reviewer's pick", font=BLACK(21), fill=ac)
    ty = text_block(dr, (x0 + 10, hy + 82), s['tag'], XBOLD(23), CREAM, CW - 20, 30)
    dr.text((x0 + 10, ty + 4), s['facts'], font=BOLD(19), fill=GREY)

    for si, (title, sy, h, extra) in enumerate(sections):
        img_y = sy + BAND_H
        if si == 0:
            paste_r(cv, s['ingame'], (x0, img_y))
            text_block(dr, (x0 + 6, img_y + h + 10), s['caption'], BOLD(21), CREAM, CW - 12, 28)
        elif si == 1:
            t = s['turnaround']
            box = Image.new('RGB', (CW, H_TURN), t.getpixel((3, 3)))
            ox, oy = (CW - t.width) // 2, (H_TURN - t.height) // 2
            if ox > 0:   # extend the backdrop (bg + floor band) sideways instead of leaving bars
                box.paste(t.crop((0, 0, 1, t.height)).resize((ox, t.height)), (0, oy))
                box.paste(t.crop((t.width - 1, 0, t.width, t.height)).resize((CW - ox - t.width, t.height)),
                          (ox + t.width, oy))
            box.paste(t, (ox, oy))
            paste_r(cv, box, (x0, img_y))
        elif si == 2:
            f = s['faces']
            box = Image.new('RGB', (CW, H_FACE), f.getpixel((3, 3)))
            box.paste(f, (0, (H_FACE - f.height) // 2))
            paste_r(cv, box, (x0, img_y))
            labels = ['neutral', 'grin / pompous', 'shock', 'furious', 'sneeze build', 'dazed']
            for li, lab in enumerate(labels):
                cx = x0 + CW * (2 * li + 1) / 12
                tw = dr.textlength(lab, font=BOLD(17))
                dr.text((cx - tw / 2, img_y + h + 7), lab, font=BOLD(17), fill=GREY)
        else:
            fx = x0
            for fi, fr in enumerate(s['sneeze']):
                paste_r(cv, fr, (fx, img_y), 10)
                lab = ['AHHH…', 'CHOO!', 'dazed in the sink'][fi]
                tw = dr.textlength(lab, font=BOLD(18))
                dr.text((fx + fr.width / 2 - tw / 2, img_y + h + 6), lab, font=BOLD(18), fill=GREY)
                fx += fr.width + 9

    # scores
    sy = y_scores - 4
    dr.text((x0 + 8, sy + 12), "Reviewer's scores, out of 10", font=BOLD(18), fill=DIM)
    sx = x0 + 8
    for lab, val in s['scores']:
        dr.text((sx, sy + 40), val, font=LILITA(40), fill=ac)
        vw = dr.textlength(val, font=LILITA(40))
        dr.text((sx + vw + 8, sy + 56), lab, font=BOLD(18), fill=CREAM)
        sx += vw + 8 + dr.textlength(lab, font=BOLD(18)) + 26

# section bands (drawn once across the full width, over the panels)
for title, sy, h, extra in sections:
    dr.text((M + 8, sy + 12), title, font=LILITA(32), fill=CREAM)

# ---------- footer ----------
fy = y_cols_end + 26
foot = ('What to judge: which pair would you enjoy watching for hours? At game size, can you tell what each one is '
        'doing? Do the faces sell the joke? Scores, caveats and the recommendation: docs/review/lookdev/index.md.')
fy = text_block(dr, (M + 6, fy), foot, XBOLD(24), CREAM, W - 2 * M - 12, 33)
credit = ('All models, faces, clips and shaders are original work for Mischief Next Door, rigged on the CC0 Quaternius '
          'Universal Animation Library skeleton (B also starts from the CC0 Quaternius Universal Base Characters). '
          'Labels: Lilita One and Nunito (SIL OFL).')
text_block(dr, (M + 6, fy + 10), credit, BOLD(18), DIM, W - 2 * M - 12, 25)

cv.save(OUT, optimize=True)
print(OUT, cv.size)
