#!/usr/bin/env python3
"""cartoon_filter — turn a flat motion curve into a cartoon one, with one knob.

THE IDEA (Wang et al., "The Cartoon Animation Filter", SIGGRAPH 2006): convolve a motion signal with
an inverted Laplacian-of-Gaussian and anticipation, follow-through and overshoot appear on their own.
No keyframes, no animator, no judgement call — it is arithmetic:

    filtered = x - amount * (x * d2G/dt2)

Before a sharp move the curve dips the wrong way (anticipation); after it, it sails past and comes
back (follow-through). Squash and stretch come from the same second derivative: hard deceleration
squashes the body, acceleration stretches it, volume preserved.

That is the whole reason this is the right animation system for an agent team. An agent does not
author motion; it picks two numbers (`amount`, `sigma`) and the maths is identical every run. And
because this file is plain numpy with no Blender in it, the maths is unit-testable in milliseconds:

    python3 tools/bakery/cartoon_filter.py --selftest
"""
from __future__ import annotations

import sys

import numpy as np

# How far the anticipation reaches, in multiples of sigma.
KERNEL_RADIUS = 3.0


def log_kernel(sigma: float) -> np.ndarray:
    """Second derivative of a Gaussian, zero-summed so a still pose is never moved."""
    sigma = max(0.35, float(sigma))
    r = max(2, int(round(KERNEL_RADIUS * sigma)))
    t = np.arange(-r, r + 1, dtype=float)
    g = np.exp(-(t * t) / (2.0 * sigma * sigma))
    g /= g.sum()
    k = ((t * t - sigma * sigma) / (sigma ** 4)) * g
    k = k - k.mean()
    # scale-space gamma-normalisation: the raw LoG response falls off as 1/sigma^2, so without this
    # `amount` would mean something different at every sigma and every frame rate. Normalised, amount
    # 1.0 is "a firm cartoon" whatever the clip length, which is what makes it an agent-facing knob.
    return k * (sigma * sigma)


def _pad(x: np.ndarray, r: int, loop: bool) -> np.ndarray:
    """Looping clips wrap. One-shots extend their end VELOCITY, not their end pose: holding the pose
    would put a corner at each boundary and the filter would invent an anticipation that the clip
    never asked for. Extrapolating linearly means a clip already moving at constant speed comes out
    untouched, and a clip starting from rest still gets its anticipation."""
    if loop:
        return np.concatenate([x[-r:], x, x[:r]])
    steps = np.arange(r, 0, -1).reshape(-1, *([1] * (x.ndim - 1)))
    head = x[:1] - steps * (x[1:2] - x[:1]) if len(x) > 1 else np.repeat(x[:1], r, axis=0)
    steps2 = np.arange(1, r + 1).reshape(-1, *([1] * (x.ndim - 1)))
    tail = x[-1:] + steps2 * (x[-1:] - x[-2:-1]) if len(x) > 1 else np.repeat(x[-1:], r, axis=0)
    return np.concatenate([head, x, tail])


def accel(curve: np.ndarray, sigma: float, loop: bool = False) -> np.ndarray:
    """Smoothed second derivative of a curve, same length and shape as the input."""
    x = np.asarray(curve, dtype=float)
    flat = x.reshape(len(x), -1)
    k = log_kernel(sigma)
    r = (len(k) - 1) // 2
    padded = _pad(flat, r, loop)
    out = np.empty_like(flat)
    for c in range(flat.shape[1]):
        out[:, c] = np.convolve(padded[:, c], k, mode="same")[r:r + len(flat)]
    return out.reshape(x.shape)


def exaggerate(curve: np.ndarray, amount: float, sigma: float, loop: bool = False) -> np.ndarray:
    """The filter itself. `amount` 0 leaves the clip alone; ~1 is a broad cartoon."""
    x = np.asarray(curve, dtype=float)
    if amount == 0.0:
        return x.copy()
    return x - float(amount) * accel(x, sigma, loop)


def _slerp(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
    d = float(np.dot(a, b))
    if d < 0.0:
        b, d = -b, -d
    if d > 0.9995:
        out = a + t * (b - a)
        return out / max(np.linalg.norm(out), 1e-9)
    th = np.arccos(np.clip(d, -1.0, 1.0))
    s = np.sin(th)
    return (np.sin((1.0 - t) * th) / s) * a + (np.sin(t * th) / s) * b


def exaggerate_quats(quats: np.ndarray, amount: float, sigma: float, loop: bool = False,
                     max_deg: float = 30.0) -> np.ndarray:
    """Same filter on rotations (N x 4, w-first), with a hard ceiling on how far it may stray.

    Two things make rotations different from positions. Signs: a quaternion and its negative are the
    same rotation, so the sequence is made continuous first or the filter tears the limb off. And
    overshoot: a linear filter on quaternion components can sail far outside any sane pose, which is
    how a flinch turns into the character flipping horizontal. `max_deg` caps the angle between the
    filtered rotation and the original, so a bigger `amount` pushes harder but can never break the
    pose — an agent typing 5.0 gets a strong take, not a broken one."""
    q = np.array(quats, dtype=float)
    for i in range(1, len(q)):
        if float(np.dot(q[i], q[i - 1])) < 0.0:
            q[i] = -q[i]
    out = exaggerate(q, amount, sigma, loop)
    n = np.linalg.norm(out, axis=1, keepdims=True)
    n[n < 1e-8] = 1.0
    out = out / n
    cap = np.radians(max_deg)
    for i in range(len(out)):
        d = abs(float(np.dot(q[i], out[i])))
        ang = 2.0 * np.arccos(np.clip(d, -1.0, 1.0))
        if ang > cap:
            out[i] = _slerp(q[i], out[i], cap / ang)
    return out


def squash_stretch(height: np.ndarray, amount: float, sigma: float, loop: bool = False,
                   limit: float = 0.26) -> np.ndarray:
    """Per-frame (x, y, z) scale from the body's vertical acceleration: hard landings squash, launches
    stretch, volume preserved. Returns an N x 3 array of multipliers around 1."""
    a = accel(np.asarray(height, dtype=float), sigma, loop)
    peak = float(np.max(np.abs(a)))
    if peak < 1e-9 or amount == 0.0:
        return np.ones((len(height), 3))
    sy = 1.0 - np.clip(a / peak, -1.0, 1.0) * float(amount) * limit
    sxz = 1.0 / np.sqrt(np.maximum(sy, 1e-3))
    return np.stack([sxz, sy, sxz], axis=1)


def accent_frame(curve: np.ndarray, sigma: float = 1.2, loop: bool = False) -> int:
    """The frame where the motion hits hardest — the punchline. Used to time sound and a hit-stop,
    and to make sure frame-dropping never throws the one frame that matters away."""
    a = accel(np.asarray(curve, dtype=float), sigma, loop)
    mag = np.linalg.norm(a.reshape(len(a), -1), axis=1)
    return int(np.argmax(mag))


# ----------------------------------------------------------------------------- self-test

def _selftest() -> int:
    fails: list[str] = []
    total = 0

    def check(name: str, ok: bool, detail: str = "") -> None:
        nonlocal total
        total += 1
        print(f"  {'PASS' if ok else 'FAIL'}  {name}{('  — ' + detail) if detail else ''}")
        if not ok:
            fails.append(name)

    # a still pose must stay exactly still
    still = np.ones((40, 3)) * 7.0
    check("a still pose is untouched", np.allclose(exaggerate(still, 1.0, 2.0), still))

    # a constant-velocity slide has no acceleration, so it must be untouched too
    ramp = np.linspace(0.0, 10.0, 60).reshape(-1, 1)
    check("constant speed is untouched", np.allclose(exaggerate(ramp, 1.0, 2.0), ramp, atol=1e-6))

    # the real claim: a sharp move gains anticipation before it and overshoot after it
    step = np.concatenate([np.zeros(30), np.ones(30)]).reshape(-1, 1)
    out = exaggerate(step, 1.0, 2.5)
    pre = float(out[20:29].min())
    post = float(out[31:45].max())
    check("anticipation appears before the move", pre < -0.01, f"dips to {pre:.3f} (was 0)")
    check("follow-through overshoots after it", post > 1.01, f"peaks at {post:.3f} (was 1)")
    check("it settles back to the pose", abs(float(out[-1, 0]) - 1.0) < 0.02, f"ends {float(out[-1, 0]):.3f}")

    # amount scales the effect monotonically, so an agent's knob behaves
    depths = [float(exaggerate(step, a, 2.5)[20:29].min()) for a in (0.0, 0.5, 1.0, 1.5)]
    check("the knob is monotonic", all(depths[i] > depths[i + 1] for i in range(3)),
          " > ".join(f"{d:.3f}" for d in depths))

    # a loop stays seamless: first and last frame must still agree
    t = np.linspace(0, 2 * np.pi, 48, endpoint=False)
    cyc = np.stack([np.sin(t), np.cos(t)], axis=1)
    lp = exaggerate(cyc, 1.0, 2.0, loop=True)
    seam = float(np.abs(lp[0] - lp[-1]).max() - np.abs(cyc[0] - cyc[-1]).max())
    check("a looping clip keeps its seam", seam < 0.02, f"seam grew {seam:+.4f}")

    # quaternions stay unit length and survive a sign flip
    q = np.zeros((30, 4))
    q[:, 0] = np.cos(np.linspace(0, 1.4, 30))
    q[:, 1] = np.sin(np.linspace(0, 1.4, 30))
    q[15:] *= -1.0                                   # same rotations, flipped signs
    fq = exaggerate_quats(q, 1.0, 2.0)
    check("quaternions stay unit length", np.allclose(np.linalg.norm(fq, axis=1), 1.0, atol=1e-6))
    jump = float(np.abs(np.diff(fq, axis=0)).max())
    check("no tear at a sign flip", jump < 0.35, f"largest step {jump:.3f}")

    # the ceiling holds however hard the knob is pushed
    qs = np.zeros((40, 4))
    ang = np.concatenate([np.zeros(20), np.full(20, 1.2)])
    qs[:, 0] = np.cos(ang / 2)
    qs[:, 1] = np.sin(ang / 2)
    worst = []
    for amt in (1.0, 3.0, 8.0):
        fq = exaggerate_quats(qs, amt, 2.5, max_deg=30.0)
        dev = max(2.0 * np.degrees(np.arccos(min(1.0, abs(float(np.dot(qs[i], fq[i])))))) for i in range(40))
        worst.append(dev)
    check("the ceiling holds at any amount", max(worst) <= 30.5,
          "max deviation " + ", ".join(f"{w:.1f}deg" for w in worst))

    # squash and stretch: a landing squashes, and volume is preserved
    y = np.concatenate([np.linspace(3.0, 0.0, 20) ** 1.0, np.zeros(20)])
    ss = squash_stretch(y, 1.0, 2.0)
    land = int(np.argmin(ss[:, 1]))
    vol = ss[:, 0] * ss[:, 1] * ss[:, 2]
    check("the landing squashes", ss[land, 1] < 0.95 and 15 <= land <= 25, f"y={ss[land,1]:.3f} at f{land}")
    check("volume is preserved", np.allclose(vol, 1.0, atol=1e-6))

    # the accent lands on the sharpest moment
    hit = np.concatenate([np.zeros(20), np.ones(20)]).reshape(-1, 1)
    af = accent_frame(hit)
    check("the accent finds the impact", 17 <= af <= 23, f"frame {af} of 40")

    print(f"\n{'OK' if not fails else 'FAILED'}: {total - len(fails)}/{total} checks")
    return 1 if fails else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        print("cartoon_filter self-test")
        raise SystemExit(_selftest())
    print(__doc__)
