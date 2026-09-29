#!/usr/bin/env python3
"""Mischief Next Door — procedural audio generator (numpy only, no samples).

Renders every registered recipe (SFX, stingers, Bellows' voice bank in both styles, the
Stalls in both styles) and the pit-orchestra music to game/audio/, writes
game/audio/sfx_map.json (files, banks, aliases, music timing) and verifies the result.

  python3 tools/audio/gen_audio.py                 # render everything + write the map + check
  python3 tools/audio/gen_audio.py --check         # verify only (CI): exit 1 on any error
  python3 tools/audio/gen_audio.py --only a,b      # re-render some recipes (and/or music keys)
  python3 tools/audio/gen_audio.py --no-music      # skip the music loops
  python3 tools/audio/gen_audio.py --map-only      # rewrite sfx_map.json from the files on disk
  python3 tools/audio/gen_audio.py --report        # table: duration, KB, peak, loudness, onset
  python3 tools/audio/gen_audio.py --list          # every recipe with category, cap and description

Output: 22.05 kHz mono 16-bit PCM WAV; music loops carry a `smpl` forward loop over the
whole file. Deterministic: each sound's RNG is seeded from its name, so re-running gives
byte-identical files.
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ROOT = HERE.parents[1]
GAME = ROOT / "game"
DATA = GAME / "data"
OUT = GAME / "audio"
MAP_PATH = OUT / "sfx_map.json"
CUES_PATH = DATA / "audio" / "cues.json"

SR = 22050
PEAK_MAX_DB = -1.0                   # brief §3.1: no file peaks above −1 dBFS
SLICE_MAX_BYTES = 15_000_000         # brief §3.8: slice audio ≤ 15 MB of WAV (after the Gate-0 pick)
AB_MAX_BYTES = 6_500_000             # the A/B alternates kept until Gate 0 (tuba voice, fallback crowd)
SHIPPED_MAX_BYTES = 40_000_000       # v1 total after import compression (QOA ≈ 3.2 bits/sample)
LOUD_TOL_HI = 1.5                    # dB above a category target → error
LOUD_TOL_LO = 4.5                    # dB below → error (crest-limited sounds may sit a little low)
AB_PREFIXES = ("vo_bellows_tuba_", "crowd_fb_")
# v1 content the slice (Prologue, N1, N2) never plays, counted apart from the 15 MB slice budget:
# SQUEAKY arrives with SOPRAN-OH-NO (Night 3); Beryl (Act II, Night 5+) and Delphine (Act III, Night 8+)
# are Stage 3 — their own voices plus the lines Bellows only says to them ("BERYL!", the Suppressed
# "ha-ha, my dear"). Their tuba takes are A/B alternates (checked first, against their own cap).
LATER_PREFIXES = ("vo_bellows_squeaky_", "vo_beryl_", "vo_delphine_", "vo_bellows_beryl", "vo_bellows_ha_ha_my_dear")
# end-trim threshold relative to the peak, per category (a tail below it is inaudible on a phone)
TRIM_DB = {"voice": -36.0, "sfx": -40.0, "soft": -36.0, "ui": -36.0, "sting": -46.0, "crowd": -38.0, "ambient": -36.0}


def is_ab_alternate(name: str) -> bool:
    return name.startswith(AB_PREFIXES)


def music_states() -> tuple[str, ...]:
    """The Audio.music_state() states (TECH §5.8)."""
    return ("curtain", "sneak", "suspense", "chase", "results", "silence")


def is_later(name: str) -> bool:
    return name.startswith(LATER_PREFIXES)


# ------------------------------------------------------------------------------ recipes

def load_recipes():
    import registry
    import sfx_foley  # noqa: F401
    import sfx_stealth  # noqa: F401
    import stings  # noqa: F401
    import voices  # noqa: F401
    import crowd  # noqa: F401
    return registry.REG


# ------------------------------------------------------------------------------ wav io

def wav_bytes(x, loop: tuple[int, int] | None = None) -> bytes:
    import numpy as np
    pcm = np.clip(np.round(np.asarray(x) * 32767.0), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, SR, SR * 2, 2, 16)
    data = struct.pack("<4sI", b"data", len(pcm)) + pcm + (b"\0" if len(pcm) % 2 else b"")
    extra = b""
    if loop is not None:
        # smpl chunk: Godot's WAV importer ("Detect From WAV") reads the forward loop from it.
        hdr = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        lp = struct.pack("<6I", 0, 0, loop[0], loop[1], 0, 0)
        extra = struct.pack("<4sI", b"smpl", len(hdr) + len(lp)) + hdr + lp
    body = b"WAVE" + fmt + data + extra
    return struct.pack("<4sI", b"RIFF", len(body)) + body


def read_wav(path: Path) -> dict:
    """Minimal RIFF reader → {tag, channels, rate, bits, frames, data, loop, size}."""
    b = path.read_bytes()
    if b[:4] != b"RIFF" or b[8:12] != b"WAVE":
        raise ValueError("not a RIFF/WAVE file")
    pos = 12
    info: dict = {"loop": None, "size": len(b)}
    while pos + 8 <= len(b):
        cid, sz = struct.unpack("<4sI", b[pos:pos + 8])
        body = b[pos + 8:pos + 8 + sz]
        if cid == b"fmt ":
            tag, ch, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
            info.update(tag=tag, channels=ch, rate=rate, bits=bits)
        elif cid == b"data":
            info["data"] = body
        elif cid == b"smpl" and len(body) >= 60:
            n_loops = struct.unpack("<I", body[28:32])[0]
            if n_loops:
                _, ltype, start, end = struct.unpack("<4I", body[36:52])
                info["loop"] = (ltype, start, end)
        pos += 8 + sz + (sz & 1)
    bps = info.get("channels", 1) * info.get("bits", 16) // 8
    info["frames"] = len(info.get("data", b"")) // max(bps, 1)
    return info


def samples(w: dict):
    import numpy as np
    x = np.frombuffer(w["data"][: w["frames"] * 2 * w.get("channels", 1)], dtype="<i2").astype(float) / 32768.0
    return x[0::2] if w.get("channels", 1) == 2 else x


# ------------------------------------------------------------------------------ mastering

def loudness_db(x) -> float:
    """Loudest 50 ms of the phone-weighted signal (dBFS RMS) — the level every target uses."""
    import numpy as np
    from synth import short_rms, weighted
    return 20 * float(np.log10(float(np.max(short_rms(weighted(x), 0.05))) + 1e-12))


def finalize(x, rec):
    """DC block, trim, length cap, loudness match (weighted), −1 dBFS ceiling."""
    import numpy as np
    from synth import db, dc_block, fade, limit, ns
    x = np.nan_to_num(np.asarray(x, dtype=float))
    x = dc_block(x, 30.0)
    peak = np.max(np.abs(x)) + 1e-12
    on = np.nonzero(np.abs(x) > peak * db(-42))[0]
    if len(on):
        x = x[max(0, on[0] - ns(0.0015)):]
    floor_db = -48.0 if "keep_tail" in rec.tags else TRIM_DB.get(rec.cat, -44.0)
    off = np.nonzero(np.abs(x) > peak * db(floor_db))[0]
    if len(off):
        x = x[: min(len(x), off[-1] + ns(0.03))]
    maxn = ns(rec.max_dur)
    if len(x) > maxn:
        x = x[:maxn]
        x = fade(x, 0.0, 0.2)
    x = fade(x, 0.0008, min(0.06, max(0.01, len(x) / SR * 0.15)))
    ceil = db(min(rec.ceiling_db, PEAK_MAX_DB) - 0.05)
    target = rec.target_db
    if target is None:
        return limit(x * (ceil / (float(np.max(np.abs(x))) + 1e-12)), ceil)
    g = db(target) / db(loudness_db(x))
    pk = float(np.max(np.abs(x))) * g
    if pk > ceil * db(6.0):  # never lean on the limiter for more than 6 dB
        g *= ceil * db(6.0) / pk
    return limit(x * g, ceil)


def stats(x) -> dict:
    import numpy as np
    from synth import short_rms
    a = np.abs(x)
    pk = float(np.max(a)) + 1e-12
    st = short_rms(x, 0.05)
    return {
        "dur": len(x) / SR,
        "peak_db": 20 * np.log10(pk),
        "rms_db": 20 * np.log10(float(np.max(st)) + 1e-12),
        "loud_db": loudness_db(x) if len(x) > 64 else -99.0,
        "t_peak_ms": float(np.argmax(a)) / SR * 1000.0,
    }


def _render_sfx(name: str):
    from synth import rng_for
    reg = load_recipes()
    rec = reg[name]
    t0 = time.time()
    x = finalize(rec.fn(rng_for(name)), rec)
    blob = wav_bytes(x)
    s = stats(x)
    s.update(name=name, cat=rec.cat, folder=rec.folder, bytes=len(blob), secs=time.time() - t0)
    return [(rec.folder, name, blob, s)]


def _render_music(key: str):
    """→ [(folder, file_id, blob, stats)] for one music job (a loop, a stem set or a one-shot)."""
    import music
    job = music.JOBS[key]
    t0 = time.time()
    outs = job.render()
    res = []
    for fid, x, info in outs:
        blob = wav_bytes(x, loop=(0, len(x)) if info.get("loop") else None)
        s = stats(x)
        s.update(name=fid, cat="music", folder="music", bytes=len(blob), secs=time.time() - t0, info=info)
        res.append(("music", fid, blob, s))
    return res


# ------------------------------------------------------------------------------ the map

def disk_files() -> dict[str, Path]:
    out = {}
    for folder in ("sfx", "voice", "music"):
        for p in sorted((OUT / folder).glob("*.wav")):
            out[p.stem] = p
    return out


def build_map(files: dict[str, Path]) -> tuple[dict, list[str]]:
    import music
    import registry
    from aliases import EXPLICIT, infer, resolve, scan_refs
    reg = load_recipes()
    notes: list[str] = []
    fmap = {}
    vary = {}
    for fid, p in sorted(files.items()):
        rel = p.relative_to(OUT).as_posix()
        rec = reg.get(fid)
        w = read_wav(p)
        entry = {"path": rel, "bus": rec.bus if rec else "Music", "len": round(w["frames"] / SR, 3)}
        if rec is not None:
            entry["cat"] = rec.cat
            if rec.vary:
                vary[fid] = rec.vary
        else:
            entry["cat"] = "music"
        fmap[fid] = entry
    bnk = {b: [m for m in members if m in files] for b, members in registry.banks().items()}
    bnk = {b: m for b, m in bnk.items() if m}
    known = set(fmap) | set(bnk)
    refs = scan_refs(DATA)
    aliases: dict[str, str] = {}
    for nm, target in sorted(EXPLICIT.items()):
        if nm in known:
            continue
        if resolve(target, aliases | {nm: target}, known) is None:
            notes.append(f"ERROR alias target missing: {nm} -> {target}")
            continue
        aliases[nm] = target
    # TECH §4.9 writes Bellows' banks as vo_b_<line>: alias every bank and bank-less line
    single = [f for f in fmap if f.startswith("vo_bellows_") and not f.rsplit("_", 1)[-1].isdigit()]
    for full in sorted(set(b for b in bnk if b.startswith("vo_bellows_")) | set(single)):
        rest = full[len("vo_bellows_"):]
        if rest.startswith(("tuba_", "squeaky_")):
            continue
        short = "vo_b_" + rest
        if short not in known:
            aliases.setdefault(short, full)
    for nm in sorted(refs):
        if nm in known or nm in aliases:
            continue
        target, how = infer(nm)
        if target is None or resolve(target, aliases, known) is None:
            continue   # reported by --check
        aliases[nm] = target
        notes.append(f"auto-mapped {nm} -> {target} ({how}; {refs[nm][0]})")
    mus = {}
    for fid, meta in music.META.items():
        if fid in fmap:
            mus[fid] = dict(meta, path=fmap[fid]["path"], len=fmap[fid]["len"])
    doc = {
        "_comment": "Generated by tools/audio/gen_audio.py — do not edit; edit tools/audio/aliases.py or a recipe.",
        "version": 1,
        "files": fmap,
        "banks": bnk,
        "aliases": dict(sorted(aliases.items())),
        "music": mus,
        "stems": music.STEM_SETS,
        "vary": dict(sorted(vary.items())),
    }
    return doc, notes


def resolve_ids(name: str, doc: dict, depth: int = 0) -> list[str]:
    """Like Audio.resolve(): a file id, a bank (→ members) or an alias chain → file ids."""
    if name in doc["files"]:
        return [name]
    if name in doc["banks"]:
        return list(doc["banks"][name])
    if depth > 6 or name not in doc["aliases"]:
        return []
    return resolve_ids(doc["aliases"][name], doc, depth + 1)


# ------------------------------------------------------------------------------ check

def cue_refs(cues: dict) -> list[tuple[str, str]]:
    """Every audio id cues.json references → [(id, where)]. Walks events / pranks /
    archetypes / squeak_bits / cues and reads the action keys sfx, voice, sting (sting_
    prefix added) and crowd (crowd_ prefix added); `music` states are checked separately."""
    out: list[tuple[str, str]] = []

    def walk(v, where):
        if isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, f"{where}[{i}]")
            return
        if not isinstance(v, dict):
            return
        for k, x in v.items():
            if k in ("sfx", "voice"):
                for s in (x if isinstance(x, list) else [x]):
                    if isinstance(s, str):
                        out.append((s, f"{where}.{k}"))
            elif k == "sting" and isinstance(x, str):
                out.append((x if x.startswith("sting_") else "sting_" + x, f"{where}.sting"))
            elif k == "crowd" and isinstance(x, str):
                out.append(("crowd_" + x, f"{where}.crowd"))
            elif isinstance(x, (dict, list)):
                walk(x, f"{where}.{k}")

    for sect in ("events", "pranks", "archetypes", "squeak_bits", "director_cues"):
        walk(cues.get(sect) or {}, sect)
    return out


def check(verbose: bool = True) -> int:
    import numpy as np
    import music
    from aliases import scan_refs
    errors: list[str] = []
    warns: list[str] = []
    if not MAP_PATH.exists():
        print("FAIL: game/audio/sfx_map.json missing — run tools/audio/gen_audio.py")
        return 1
    doc = json.loads(MAP_PATH.read_text())
    files = disk_files()
    reg = load_recipes()
    # 1. every registered recipe and music file exists
    for nm, r in sorted(reg.items()):
        if nm not in files:
            errors.append(f"missing {r.folder}/{nm}.wav (run gen_audio.py --only {nm})")
    for fid in music.META:
        if fid not in files:
            errors.append(f"missing music/{fid}.wav")
    for fid in files:
        if fid not in reg and fid not in music.META:
            errors.append(f"stale file {files[fid].relative_to(OUT)} (no recipe)")
    # 2. the map is current and self-consistent
    fresh, _ = build_map(files)
    for key in ("files", "banks", "music", "stems", "vary"):
        if doc.get(key) != fresh.get(key):
            errors.append(f"sfx_map.json '{key}' is stale — run gen_audio.py --map-only")
    for k, v in doc.get("aliases", {}).items():
        if not resolve_ids(k, doc):
            errors.append(f"alias '{k}' -> '{v}' does not reach a file")
    for b, members in doc.get("banks", {}).items():
        for m in members:
            if m not in doc["files"]:
                errors.append(f"bank {b}: member {m} is not a file")
    # 3. content + cue references resolve
    for nm, where in sorted(scan_refs(DATA).items()):
        if not resolve_ids(nm, doc):
            errors.append(f"unresolved audio id '{nm}' ({where[0]}{' +%d' % (len(where) - 1) if len(where) > 1 else ''})")
    if CUES_PATH.exists():
        try:
            cues = json.loads(CUES_PATH.read_text())
        except ValueError as e:
            cues = {}
            errors.append(f"cues.json does not parse: {e}")
        for nm, where in cue_refs(cues):
            if not resolve_ids(nm, doc):
                errors.append(f"cues.json {where}: '{nm}' does not resolve")
        states = set(music_states())

        def walk_music(v, where):
            if isinstance(v, list):
                for i, x in enumerate(v):
                    walk_music(x, f"{where}[{i}]")
            elif isinstance(v, dict):
                for k, x in v.items():
                    if k == "music" and isinstance(x, str) and x not in states:
                        errors.append(f"cues.json {where}.music: unknown state '{x}'")
                    elif isinstance(x, (dict, list)):
                        walk_music(x, f"{where}.{k}")
        walk_music(cues.get("events") or {}, "events")
    else:
        warns.append("game/data/audio/cues.json missing")
    # 4. formats, lengths, levels
    slice_bytes = 0
    ab_bytes = 0
    later_bytes = 0
    frames_total = 0
    ceil = 10 ** (PEAK_MAX_DB / 20) + 1.5e-4
    for fid, p in sorted(files.items()):
        try:
            w = read_wav(p)
        except (OSError, ValueError, struct.error) as e:
            errors.append(f"{p.name}: unreadable ({e})")
            continue
        if is_ab_alternate(fid):
            ab_bytes += w["size"]
        elif is_later(fid):
            later_bytes += w["size"]
        else:
            slice_bytes += w["size"]
        frames_total += w["frames"]
        if (w.get("tag"), w.get("channels"), w.get("rate"), w.get("bits")) != (1, 1, SR, 16):
            errors.append(f"{fid}: expected PCM 22050 Hz mono 16-bit, got {w.get('rate')} Hz "
                          f"{w.get('channels')}ch {w.get('bits')}-bit")
            continue
        x = samples(w)
        dur = len(x) / SR
        pk = float(np.max(np.abs(x))) if len(x) else 0.0
        if pk >= 0.999:
            errors.append(f"{fid}: clipping (peak {pk:.4f})")
        elif pk > ceil:
            errors.append(f"{fid}: peak {20 * np.log10(pk):.2f} dBFS above {PEAK_MAX_DB} dBFS")
        if fid in reg:
            r = reg[fid]
            if dur > r.max_dur + 0.01:
                errors.append(f"{fid}: {dur:.2f}s exceeds its {r.max_dur:.2f}s cap")
            if dur < 0.02:
                errors.append(f"{fid}: too short ({dur * 1000:.0f} ms)")
            if r.target_db is not None and len(x) > 256:
                ld = loudness_db(x)
                if ld > r.target_db + LOUD_TOL_HI:
                    errors.append(f"{fid}: loudness {ld:.1f} dB above target {r.target_db:.1f}")
                elif ld < r.target_db - LOUD_TOL_LO:
                    errors.append(f"{fid}: loudness {ld:.1f} dB below target {r.target_db:.1f}")
                elif abs(ld - r.target_db) > 1.5:
                    warns.append(f"{fid}: loudness {ld:.1f} vs target {r.target_db:.1f}")
            if abs(float(np.mean(x))) > 0.02:
                warns.append(f"{fid}: DC offset {np.mean(x):.3f}")
            if len(x) > 64 and np.max(np.abs(x[-32:])) > 0.05:
                warns.append(f"{fid}: ends abruptly (tail {np.max(np.abs(x[-32:])):.3f})")
    # 5. music: loops sample-exact, bar grid, stems
    for fid, meta in music.META.items():
        p = files.get(fid)
        if p is None:
            continue
        w = read_wav(p)
        x = samples(w)
        want = meta["bars"] * meta["beats_per_bar"] * meta["spb"]
        if meta.get("loop"):
            if w["frames"] != want:
                errors.append(f"{fid}: {w['frames']} frames, bar grid says {want} "
                              f"({meta['bars']} bars × {meta['beats_per_bar']} × {meta['spb']})")
            if not w["loop"] or w["loop"][0] != 0 or w["loop"][1] != 0 or w["loop"][2] != w["frames"]:
                errors.append(f"{fid}: missing/incorrect smpl forward loop (got {w['loop']}, frames {w['frames']})")
            jump = abs(x[0] - x[-1])
            typical = float(np.percentile(np.abs(np.diff(x)), 99.9))
            if jump > max(typical, 0.02):
                errors.append(f"{fid}: loop seam jump {jump:.4f} > p99.9 step {typical:.4f}")
        elif w["loop"]:
            errors.append(f"{fid}: one-shot carries a loop chunk")
    for set_key, names in music.STEM_SETS.items():
        got = [files.get(n) for n in names]
        if any(g is None for g in got):
            continue
        xs = [samples(read_wav(g)) for g in got]
        base = len(xs[0])
        tiled = []
        for n, x in zip(names, xs):
            if base % len(x) != 0:
                errors.append(f"stems {set_key}: {n} ({len(x)} frames) does not divide {names[0]} ({base})")
                break
            tiled.append(np.tile(x, base // len(x)))
        else:
            pk_db = 20 * np.log10(float(np.max(np.abs(sum(tiled)))) + 1e-12)
            if pk_db > PEAK_MAX_DB + 1e-3:
                errors.append(f"stems {set_key}: summed peak {pk_db:.2f} dBFS > {PEAK_MAX_DB} dBFS")
    # 6. budgets
    other = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file() and p.suffix == ".json")
    shipped_est = int(frames_total * 0.41) + other   # QOA ≈ 3.2 bits/sample + frame headers
    if slice_bytes > SLICE_MAX_BYTES:
        errors.append(f"slice audio {slice_bytes / 1e6:.2f} MB WAV exceeds {SLICE_MAX_BYTES / 1e6:.1f} MB")
    if ab_bytes > AB_MAX_BYTES:
        errors.append(f"A/B alternates {ab_bytes / 1e6:.2f} MB WAV exceed {AB_MAX_BYTES / 1e6:.1f} MB")
    if shipped_est > SHIPPED_MAX_BYTES:
        errors.append(f"estimated shipped audio {shipped_est / 1e6:.1f} MB > {SHIPPED_MAX_BYTES / 1e6:.0f} MB")
    if verbose:
        for w_ in warns:
            print("warn:", w_)
        for e in errors:
            print("ERROR:", e)
        print(f"check: {len(files)} files ({len(doc.get('banks', {}))} banks, {len(doc.get('aliases', {}))} aliases); "
              f"slice {slice_bytes / 1e6:.2f} MB + A/B alternates {ab_bytes / 1e6:.2f} MB + later-Night "
              f"{later_bytes / 1e6:.2f} MB WAV; "
              f"≈{shipped_est / 1e6:.1f} MB after QOA import → {'FAIL' if errors else 'PASS'} "
              f"({len(errors)} errors, {len(warns)} warnings)")
    return 1 if errors else 0


# ------------------------------------------------------------------------------ report

def report_rows() -> list[dict]:
    rows = []
    reg = load_recipes()
    from review import onsets
    for fid, p in sorted(disk_files().items()):
        w = read_wav(p)
        x = samples(w)
        s = stats(x)
        on = onsets(x)
        r = reg.get(fid)
        s.update(name=fid, cat=r.cat if r else "music", bytes=w["size"], onset_ms=on[0] * 1000 if on else -1,
                 target=(r.target_db if r else None), folder=p.parent.name)
        rows.append(s)
    return rows


def print_table(rows: list[dict]) -> None:
    print(f"{'id':34s} {'cat':6s} {'dur s':>6s} {'KB':>7s} {'peak':>6s} {'loud':>6s} {'tgt':>6s} {'on ms':>6s}")
    for r in rows:
        tgt = f"{r['target']:.1f}" if r.get("target") is not None else "  -"
        print(f"{r['name']:34s} {r['cat']:6s} {r['dur']:6.2f} {r['bytes'] / 1024:7.1f} {r['peak_db']:6.1f} "
              f"{r['loud_db']:6.1f} {tgt:>6s} {r.get('onset_ms', -1):6.0f}")
    tot = sum(r["bytes"] for r in rows)
    ab = sum(r["bytes"] for r in rows if is_ab_alternate(r["name"]))
    later = sum(r["bytes"] for r in rows if is_later(r["name"]))
    by_folder: dict[str, int] = {}
    for r in rows:
        by_folder[r["folder"]] = by_folder.get(r["folder"], 0) + r["bytes"]
    print(f"{len(rows)} files, {tot / 1e6:.2f} MB WAV total ({(tot - ab - later) / 1e6:.2f} MB slice + {ab / 1e6:.2f} MB "
          f"A/B alternates + {later / 1e6:.2f} MB later-Night); by folder: " + ", ".join(f"{k} {v / 1e6:.2f} MB" for k, v in sorted(by_folder.items())))


# ------------------------------------------------------------------------------ main

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="verify only; exit 1 on problems")
    ap.add_argument("--only", default="", help="comma-separated recipe names and/or music job keys")
    ap.add_argument("--no-music", action="store_true")
    ap.add_argument("--map-only", action="store_true", help="only rewrite sfx_map.json")
    ap.add_argument("--report", action="store_true", help="print a table of all files on disk")
    ap.add_argument("--list", action="store_true", help="list recipes")
    ap.add_argument("--jobs", type=int, default=max(1, min(8, os.cpu_count() or 1)))
    a = ap.parse_args()

    if a.check:
        rc = check()
        if a.report:
            print_table(report_rows())
        return rc
    if a.report and not (a.only or a.map_only):
        print_table(report_rows())
        return 0
    import music
    reg = load_recipes()
    if a.list:
        for nm, r in sorted(reg.items()):
            print(f"{nm:34s} {r.cat:6s} ≤{r.max_dur:.1f}s  {r.desc}")
        for k, job in music.JOBS.items():
            print(f"{k:34s} music  {job.desc}")
        return 0
    for folder in ("sfx", "voice", "music"):
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    t0 = time.time()
    if not a.map_only:
        only = [n for n in a.only.split(",") if n]
        names = [n for n in only if n in reg] if only else sorted(reg)
        mkeys = [n for n in only if n in music.JOBS] if only else ([] if a.no_music else list(music.JOBS))
        unknown = [n for n in only if n not in reg and n not in music.JOBS]
        if unknown:
            print("unknown recipe / music key(s):", ", ".join(unknown))
            return 2
        # the slow music jobs first so the pool stays busy
        with ProcessPoolExecutor(max_workers=a.jobs) as ex:
            futs = [ex.submit(_render_music, k) for k in mkeys] + [ex.submit(_render_sfx, n) for n in names]
            for f in futs:
                for folder, fid, blob, s in f.result():
                    (OUT / folder / f"{fid}.wav").write_bytes(blob)
                    rows.append(s)
        if not only and not a.no_music:
            valid = set(reg) | set(music.META)
            for fid, p in disk_files().items():
                if fid not in valid:
                    p.unlink()
                    print("removed stale", p.relative_to(OUT))
        rows.sort(key=lambda r: (r["folder"], r["name"]))
        for r in rows:
            r["target"] = reg[r["name"]].target_db if r["name"] in reg else None
            r["onset_ms"] = -1
        print_table(rows)
        slow = sorted(rows, key=lambda r: -r["secs"])[:4]
        print("slowest:", ", ".join(f"{r['name']} {r['secs']:.1f}s" for r in slow), f"| wall {time.time() - t0:.1f}s")
        for r in rows:
            if "info" in r and r["info"].get("bpm"):
                i = r["info"]
                print(f"  {r['name']}: {i['bpm']:.2f} bpm, {i['bars']} bars of {i['beats_per_bar']}, "
                      f"{i['spb']} samples/beat, {r['dur']:.2f}s{' loop' if i.get('loop') else ''}")
    doc, notes = build_map(disk_files())
    MAP_PATH.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    for nline in notes:
        print(nline)
    print(f"wrote {MAP_PATH.relative_to(ROOT)} ({len(doc['files'])} files, {len(doc['banks'])} banks, "
          f"{len(doc['aliases'])} aliases)")
    return check()


if __name__ == "__main__":
    sys.exit(main())
