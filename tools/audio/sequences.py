"""Cycles and preview sequences written into game/audio/sfx_map.json (read by the Audio autoload).

cycles     An id whose members play *in order* instead of at random. Hush's pizzicato tiptoe
           (GDD §9.5 "her pizzicato footsteps walk up a scale"): each footfall clip event names
           `step_pizz_up` and the autoload walks E4 → E5 and back down ("pingpong"); after
           `reset_s` without a step the next walk starts again at the bottom.

sequences  Timed runs of voice or crowd ids for `Audio.preview()` (the stage door's A/B pair
           buttons): `[[t_s, id], ...]`, each part resolved in the previewed style. The sneeze
           run is taken from the clip-event table (tools/audio/clip_events.py), so the pair
           button plays exactly the timing the clip plays.
"""
from __future__ import annotations

FPS = 60.0

CYCLES: dict[str, dict] = {
    "step_pizz_up": {"members": [f"step_pizz_{i}" for i in range(1, 9)], "mode": "pingpong", "reset_s": 0.8},
}


def sequences() -> dict[str, list]:
    from clip_events import clip_rows
    voice = [r for r in clip_rows("bellows/rx_sneeze_blast_a") if r["type"] == "voice"]
    return {
        "vo_bellows_sneeze_seq": [[round(r["f"] / FPS, 4), r["id"]] for r in voice],
    }
