"""Numpy painter: baked maps (rest position, normal, region, AO) + meta -> the character's albedo texture.

python3 paint.py <dir> <who>     -> <dir>/<who>_albedo.png (RGBA 1024; alpha = gloss mask; rows 0-255 = the
                                      face decal atlas with its own alpha)
Every pattern is a function of the texel's REST position in armature space (metres; +X = the character's
left, -Y = front, +Z up), so stripes, braces, blush and stitches land exactly where they belong.
"""
import sys, os, json, math
import numpy as np
from PIL import Image

D, WHO = sys.argv[1], sys.argv[2]
m = np.load(os.path.join(D, WHO + "_maps.npz"))
meta = json.load(open(os.path.join(D, WHO + "_meta.json")))
R = meta["regions"]
J = {k: np.array(v) for k, v in meta["joints"].items()}
S = m["pos"].shape[0]
P = m["pos"].astype(np.float64)
N = m["nrm"].astype(np.float64)
N /= np.maximum(np.linalg.norm(N, axis=2, keepdims=True), 1e-6)
REG = m["reg"]
GRP = m["grp"]
AO = np.array(Image.fromarray((np.clip(m["ao"], 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR)).astype(np.float64) / 255.0
X, Y, Z = P[..., 0], P[..., 1], P[..., 2]
TEX = 0.0012   # ~ metres per texel (AA width for patterns)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float64) / 255.0


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def band(x, half, aa=TEX * 1.5):
    """1 inside |x| < half (anti-aliased)."""
    return 1 - ss(half - aa, half + aa, np.abs(x))


def stripes(c, period, duty, aa=TEX * 1.5):
    f = np.mod(c / period, 1.0)
    d = np.minimum(f, 1 - f) * period          # distance to the stripe centre line at f=0
    return 1 - ss(duty * period / 2 - aa, duty * period / 2 + aa, d)


def dist3(c):
    return np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2 + (Z - c[2]) ** 2)


def value_noise(Pp, cell):
    g = Pp / cell
    i0 = np.floor(g).astype(np.int64)
    f = g - i0
    f = f * f * (3 - 2 * f)

    def h(ix, iy, iz):
        n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
        n = (n ^ (n >> 13)) * 1274126177
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w * h(i0[..., 0] + dx, i0[..., 1] + dy, i0[..., 2] + dz)
    return out


def curl_noise(Pp):
    """Curly-clump value noise (big clumps + small curls)."""
    return 0.55 * value_noise(Pp, 0.035) + 0.3 * value_noise(Pp + 3.1, 0.014) + 0.15 * value_noise(Pp + 7.7, 0.006)


img = np.zeros((S, S, 3))
gloss = np.zeros((S, S))
mask = lambda *names: np.isin(REG, [R[n] for n in names])


def fill(sel, col, g=0.0):
    img[sel] = col
    gloss[sel] = g


def mix(sel, col, a):
    a = (a * sel)[..., None]
    img[:] = img * (1 - a) + col * a


hc = np.array(meta["head_c"])
EYE = {k: np.array(v) for k, v in meta["eye_c"].items()}

if WHO == "hush":
    FACE = hexc("FFF6EA")
    fill(mask("facepaint", "lid", "lowlid"), FACE, 0.15)
    fill(mask("eyewhite"), hexc("FFFFFF"), 0.9)
    fill(mask("hair"), hexc("3A2629"), 0.35)
    fill(mask("hat"), hexc("E23B4E"), 0.1)
    fill(mask("brow"), hexc("2B1E30"), 0.0)
    fill(mask("glove"), hexc("FFFFFF"), 0.2)
    fill(mask("shoes"), hexc("1F1C26"), 0.7)
    fill(mask("collar"), hexc("2B3566"), 0.0)
    fill(mask("hem", "trousers"), hexc("26252F"), 0.1)
    fill(mask("chick"), hexc("FFD23F"), 0.6)
    fill(mask("chick_red"), hexc("E23B4E"), 0.4)
    fill(mask("chick_beak"), hexc("FF8C2A"), 0.4)
    # --- face: blush, teardrop, nose tip
    face = mask("facepaint")
    for sx in (1, -1):
        c = hc + np.array([sx * 0.07, -0.118, -0.05])
        mix(face, hexc("FF9AA2"), 0.8 * (1 - ss(0.008, 0.03, dist3(c))))
    c = hc + np.array([0.0, -0.152, -0.036])
    mix(face, hexc("FFD6D4"), 0.8 * (1 - ss(0.004, 0.016, dist3(c))))
    # teardrop under her left eye (front-projected distance field of a drop)
    tc = EYE["l"] + np.array([0.012, 0.0, -0.066])
    dx, dz = (X - tc[0]), (Z - tc[2])
    r = 0.0055
    drop = np.sqrt(dx ** 2 + (np.minimum(dz, 0)) ** 2 * 1.0) - r   # round bottom
    top = (dz > 0) & (np.abs(dx) < r * (1 - dz / 0.014))
    tear = ((drop < 0) | top) & (dz < 0.014) & (N[..., 1] < -0.3) & (Y < tc[1] + 0.05)
    mix(face, hexc("2B3566"), tear.astype(float))
    # --- lids: lash line at the rim
    for side, sg in (("l", 1), ("r", -1)):
        ec = EYE[side]
        d = P - ec
        dn = d / np.maximum(np.linalg.norm(d, axis=2, keepdims=True), 1e-6)
        a = math.radians(meta["lid_rest"])
        pole = np.array([0.0, -math.sin(a), math.cos(a)])       # R_x(a) @ (0,0,1)
        ang = np.degrees(np.arccos(np.clip((dn * pole).sum(2), -1, 1)))
        near = np.linalg.norm(d, axis=2) < meta["eye_r"] * 1.3
        lid = mask("lid") & near
        lash = ss(76, 82, ang)
        # a flick at the outer corner
        outer = ss(0.6, 0.95, sg * dn[..., 0]) * ss(60, 75, ang)
        mix(lid, hexc("2B1E30"), np.clip(lash + outer * 0.9, 0, 1))
        low = mask("lowlid") & near
        a2 = -math.radians(-64.0)
        pole2 = np.array([0.0, -math.sin(-a2), -math.cos(-a2)])
        mix(low, hexc("E7C9C4"), ss(80, 86, np.degrees(np.arccos(np.clip((dn * pole2).sum(2), -1, 1)))) * 0.8)
    # --- hair sheen + strands
    hair = mask("hair")
    theta = np.arctan2(X - hc[0], -(Y - hc[1]))
    strands = 0.5 + 0.5 * np.sin(theta * 70 + np.sin(Z * 90) * 1.5)
    sheen = ss(0.3, 0.75, N[..., 2]) * (1 - ss(0.8, 0.98, N[..., 2])) * ss(-0.3, 0.2, -N[..., 1])
    mix(hair, hexc("6E4A4C"), 0.55 * sheen * (0.6 + 0.4 * strands))
    mix(hair, hexc("24161A"), 0.25 * (1 - strands) * (1 - sheen))
    hat = mask("hat")
    mix(hat, hexc("A8203A"), ss(0.0, -0.6, N[..., 2]) * 0.7)
    mix(hat, hexc("F0566A"), ss(0.5, 0.95, N[..., 2]) * 0.35)
    # --- body: Breton stripes above the (high) waist, trousers below; braces
    body = mask("shirt")
    wz = meta["waist_z"]
    xs = J["upperarm_l"][0] - 0.005
    armness = ss(xs - 0.015, xs + 0.02, np.abs(X)) * ss(J["upperarm_l"][2] - 0.16, J["upperarm_l"][2] - 0.1, Z)
    tors_c = Z
    arm_c = np.abs(X)
    NAVY, WHITE = hexc("2B3566"), hexc("F4F1EA")
    st = np.where(armness > 0.5, stripes(arm_c - 0.02, 0.05, 0.42), stripes(tors_c - wz - 0.018, 0.052, 0.42))
    shirt_col = WHITE[None, None, :] * (1 - st[..., None]) + NAVY[None, None, :] * st[..., None]
    trous = body & (Z < wz) & (armness < 0.5)
    img[body] = shirt_col[body]
    gloss[body] = 0.05
    img[trous] = hexc("26252F")
    # trouser front crease
    for sx in (1, -1):
        lx = J["thigh_l"][0] * sx
        crease = band(X - lx, 0.0016) * (Y < J["thigh_l"][1] - 0.02) * (N[..., 1] < -0.5)
        mix(trous, hexc("3A3946"), crease * 0.8)
    # waistband
    mix(body & (armness < 0.5), hexc("1B1A22"), band(Z - wz, 0.009))
    # braces: red straps front + back, from the waistband over the shoulders
    top_z = J["upperarm_l"][2] + 0.09
    on_torso = body & (armness < 0.45) & (Z > wz - 0.005) & (Z < top_z)
    for sx in (1, -1):
        xb = sx * (0.062 + 0.012 * ss(wz, top_z, Z))
        br = band(X - xb, 0.0135)
        edge = band(X - xb, 0.0135) - band(X - xb, 0.0105)
        mix(on_torso, hexc("E23B4E"), br)
        mix(on_torso, hexc("B82740"), edge * 0.9)
        # brace clip
        for fy, sgn in ((-1, 1), (1, 1)):
            clip = (np.abs(X - xb) < 0.017) & (np.abs(Z - (wz + 0.012)) < 0.012) & ((Y - J["spine_01"][1]) * fy > 0)
            mix(on_torso, hexc("D9DCE6"), clip.astype(float))
    # --- gloves: three stitch lines on the back of the hand (T-pose: back of hand faces +Z)
    gl = mask("glove")
    for side, sg in (("l", 1), ("r", -1)):
        hh = J["hand_" + side]
        along = (X - hh[0]) * sg
        on = gl & (N[..., 2] > 0.45) & (along > 0.02) & (along < 0.105) & (np.abs(Y - hh[1]) < 0.06)
        for off in (-0.017, 0.0, 0.017):
            mix(on, hexc("8E8EA0"), band(Y - hh[1] - off, 0.0014) * 0.9)
    # Clarence's eyes
    cc = np.array([-0.072, J["spine_03"][1] - 0.095, J["spine_03"][2] + 0.035]) + np.array([0.004, -0.005, 0.06])
    for ex in (0.012, -0.012):
        e = cc + np.array([ex, -0.02, 0.006])
        mix(mask("chick"), hexc("1B1420"), 1 - ss(0.0032, 0.0045, dist3(e)))
else:
    SKIN = hexc("F4C9A8")
    fill(mask("skin", "lid", "lowlid"), SKIN, 0.25)
    fill(mask("eyewhite"), hexc("FFFDF6"), 0.9)
    fill(mask("hair", "brow"), hexc("D9DCE6"), 0.3)
    fill(mask("jacket"), hexc("7B3F8C"), 0.15)
    fill(mask("shoes"), hexc("1F1C26"), 0.8)
    fill(mask("cuffw", "shirtw"), hexc("F7F3EA"), 0.1)
    fill(mask("cravat"), hexc("E8B33A"), 0.55)
    fill(mask("gold"), hexc("E8B33A"), 0.95)
    fill(mask("hem"), hexc("4A3A52"), 0.1)
    skin = mask("skin") & (GRP == 0)
    c = hc + np.array([0.0, -0.18, -0.015])
    mix(skin, hexc("E58F86"), 0.85 * (1 - ss(0.01, 0.05, dist3(c))))
    for sx in (1, -1):
        c = hc + np.array([sx * 0.085, -0.1, -0.05])
        mix(skin, hexc("EDA394"), 0.55 * (1 - ss(0.01, 0.045, dist3(c))))
    mix(mask("lid"), hexc("E6AE90"), 1.0)
    for side, sg in (("l", 1), ("r", -1)):
        ec = EYE[side]
        d = P - ec
        dn = d / np.maximum(np.linalg.norm(d, axis=2, keepdims=True), 1e-6)
        a = math.radians(meta["lid_rest"])
        pole = np.array([0.0, -math.sin(a), math.cos(a)])
        ang = np.degrees(np.arccos(np.clip((dn * pole).sum(2), -1, 1)))
        near = np.linalg.norm(d, axis=2) < meta["eye_r"] * 1.3
        mix(mask("lid") & near, hexc("6B3A36"), ss(80, 86, ang))
    hair = mask("hair", "brow")
    curls = curl_noise(P)
    # strands radiating from the crown (a dandelion clock), wobbling with the clumps
    pc = hc + np.array([0.0, 0.03, 0.2])
    d = P - pc
    th = np.arctan2(d[..., 0], -d[..., 1])
    ph = np.arctan2(np.sqrt(d[..., 0] ** 2 + d[..., 1] ** 2), d[..., 2])
    strand = 0.5 + 0.5 * np.sin(th * 70 * np.sin(np.clip(ph, 0.2, 3.0)) + curls * 9.0 + ph * 6.0)
    mix(hair, hexc("A9ADC6"), 0.5 * ss(0.45, 0.2, curls))
    mix(hair, hexc("C3C6D8"), 0.35 * (1 - strand))
    mix(hair, hexc("F8F9FD"), 0.55 * strand * ss(0.5, 0.8, curls) * (0.4 + 0.6 * ss(0.0, 0.8, N[..., 2])))
    # jacket: shirt V + shawl lapels on the barrel front, darker turn-back cuffs, trousers below the waist
    jk = mask("jacket")
    wz = meta["waist_z"]
    zt = J["upperarm_l"][2] + 0.06
    zb = J["thigh_l"][2] - 0.07
    H = zt - zb
    yc = J["spine_02"][1]
    front = jk & (Y < yc - 0.05) & (GRP == 1)
    zv0 = zb + 0.55 * H
    w = 0.16 * ss(zv0, zt, Z)
    shirt = front & (np.abs(X) < w)
    lapel = front & (np.abs(X) >= w) & (np.abs(X) < w + 0.06 * ss(zv0 - 0.05, zv0 + 0.1, Z))
    img[shirt] = hexc("F7F3EA")
    img[lapel] = hexc("5A2A68")
    mix(front, hexc("A866B8"), band(np.abs(X) - w - 0.06 * ss(zv0 - 0.05, zv0 + 0.1, Z), 0.0025) * (Z > zv0 - 0.04))
    # jacket hem band
    mix(jk & (GRP == 1), hexc("5A2A68"), band(Z - (zb + 0.035), 0.018))
    legs = jk & (GRP == 1) & (Z < zb + 0.02) & (np.abs(X) < 0.3) & ~(Y > yc + 0.15)
    arms_mask = jk & (np.abs(X) > J["upperarm_l"][0] - 0.02) & (Z > zb + 0.2)
    # sleeves: turn-back cuffs near the wrist
    for side, sg in (("l", 1), ("r", -1)):
        hh = J["hand_" + side]
        along = (hh[0] - X) * sg
        mix(arms_mask & (along > 0.0) & (along < 0.075), hexc("5A2A68"), 1.0)
    # the base-body legs are the trousers (pinstripes)
    tr = jk & (Z < zb + 0.03) & (GRP == 1) & ~front
    tr = mask("jacket") & (Z < zb - 0.01)
    img[tr] = hexc("4A3A52")
    theta2 = np.arctan2(X - np.sign(X) * J["thigh_l"][0], Y - J["thigh_l"][1])
    mix(tr, hexc("65566E"), band(np.mod(theta2 * 0.045 / (2 * np.pi) * 12, 0.012) - 0.006, 0.0009) * 0.7)
    # cravat dots
    cr = mask("cravat")
    dots = (np.mod(X * 60, 1.0) - 0.5) ** 2 + (np.mod(Z * 60 + 0.5 * np.floor(X * 60), 1.0) - 0.5) ** 2 < 0.05
    mix(cr, hexc("F6D27A"), dots.astype(float) * 0.8)
    # spats on the shoes (white upper) with two buttons
    sh = mask("shoes")
    spat = sh & (Z > 0.052)
    img[spat] = hexc("F2EFE6")
    gloss[spat] = 0.1
    for side, sg in (("l", 1), ("r", -1)):
        an = J["foot_" + side]
        for bz in (0.07, 0.095):
            b = np.array([an[0] + sg * 0.045, an[1] - 0.01, bz])
            mix(spat, hexc("2B2233"), 1 - ss(0.003, 0.0045, dist3(b)))

# AO (stronger in hair / crevices), clamp
ao = np.clip(AO, 0, 1)
k = np.where(np.isin(REG, [R["hair"]]), 0.55, 0.35)
img = img * (1 - k[..., None] * (1 - ao[..., None]))
img = np.clip(img, 0, 1)

out = np.zeros((S, S, 4), np.uint8)
out[..., :3] = (img * 255 + 0.5).astype(np.uint8)
out[..., 3] = (np.clip(gloss, 0, 1) * 255).astype(np.uint8)
atlas = np.array(Image.open(os.path.join(D, "atlas_%s.png" % WHO)).convert("RGBA"))
out[:256, :, :] = atlas
Image.fromarray(out, "RGBA").save(os.path.join(D, WHO + "_albedo.png"))
Image.fromarray(out[..., :3]).save(os.path.join(D, WHO + "_albedo_rgb.png"))
print("PAINT_OK", WHO)
