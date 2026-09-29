"""Sound registry: every recipe registers itself with @sfx(name, ...).

A recipe is a function `fn(rng) -> np.ndarray` (mono float at synth.SR). The category
decides the folder under game/audio/, the Godot bus the autoload plays it on, and the
loudness target `gen_audio.finalize()` matches it to. A `bank` groups variants: the
autoload's `play_voice(bank)` / `crowd(kind)` / `play_sfx(bank)` pick one at random and
never play the same file twice in a row.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

# category → (target loudest-50-ms weighted RMS in dBFS, or None = peak-normalise;
#             peak ceiling dBFS; folder under game/audio/; Godot bus)
CATS: dict[str, tuple[float | None, float, str, str]] = {
    "sfx": (-14.0, -1.0, "sfx", "SFX"),        # world one-shots: punchy
    "soft": (-21.0, -1.5, "sfx", "SFX"),       # footsteps, creaks, rustles: under everything
    "ambient": (-19.0, -1.5, "sfx", "SFX"),    # fire crackle, hums
    "ui": (-20.0, -3.0, "sfx", "UI"),          # frequent, must not fatigue
    "sting": (-14.5, -1.0, "sfx", "SFX"),      # musical stingers (duck the music)
    "voice": (-14.0, -1.0, "voice", "Voice"),  # Bellows' phrase bank (formant, tuba, squeaky)
    "crowd": (-15.0, -1.0, "sfx", "Crowd"),    # the Stalls (per-recipe `level` for tiers)
}
BUS_OF = {k: v[3] for k, v in CATS.items()}


@dataclass
class Recipe:
    name: str
    fn: Callable
    cat: str = "sfx"
    max_dur: float = 2.0
    desc: str = ""
    bank: str = ""
    level: float | None = None   # overrides the category's loudness target (dBFS)
    vary: float = 0.0            # runtime pitch jitter (± fraction) the autoload may apply
    tags: tuple = field(default_factory=tuple)

    @property
    def folder(self) -> str:
        return CATS[self.cat][2]

    @property
    def bus(self) -> str:
        return CATS[self.cat][3]

    @property
    def target_db(self) -> float | None:
        return self.level if self.level is not None else CATS[self.cat][0]

    @property
    def ceiling_db(self) -> float:
        return CATS[self.cat][1]


REG: dict[str, Recipe] = {}


def sfx(name: str, cat: str = "sfx", max_dur: float = 2.0, desc: str = "", bank: str = "",
        level: float | None = None, vary: float = 0.0, tags: tuple = ()):
    """Register a recipe under `name` (snake_case, unique across the whole game)."""
    if cat not in CATS:
        raise ValueError(f"unknown category {cat} for {name}")

    def deco(fn):
        if name in REG:
            raise ValueError(f"duplicate sfx {name}")
        REG[name] = Recipe(name, fn, cat, max_dur, desc, bank, level, vary, tuple(tags))
        return fn
    return deco


def banks() -> dict[str, list[str]]:
    """bank id → sorted member file ids (from the registered recipes)."""
    out: dict[str, list[str]] = {}
    for r in REG.values():
        if r.bank:
            out.setdefault(r.bank, []).append(r.name)
    return {k: sorted(v, key=_natural) for k, v in sorted(out.items())}


def _natural(s: str):
    import re
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", s)]
