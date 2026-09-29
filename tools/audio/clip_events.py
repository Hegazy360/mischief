#!/usr/bin/env python3
"""The clip-event frame table (ruling L12): every sound that lives *inside* a clip.

`s2-sound` renders the sounds and publishes here where each goes — clip → frame → id →
vol_db, on the contact frame ± 1 f; the anim tasks place them as clip events
`{"f": f, "type": "sfx"|"voice", "id": id[, "vol_db": v]}`. `cues.json` keeps only the
event-level sounds (stingers, the crowd, music, UI, props the view stages), and the test
game/tests/audio/test_clip_events.gd parses the generated table (the JSON copy inside the
Godot project — docs/ is not in the test sandbox) to prove no id is both.

  python3 tools/audio/clip_events.py            # write docs/review/s2-sound/clip_events.md +
                                                 # game/data/audio/clip_events.json
  python3 tools/audio/clip_events.py --check    # exit 1 when the files on disk are stale / invalid

`gen_audio.py` rewrites the table after every render (lengths come from sfx_map.json) and
`gen_audio.py --check` fails when it is stale. Frames are clip frames at 60 fps (view time,
so a hit-stop holds them); `len_f` is the sound's length in frames, for checking overlaps.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ROOT = HERE.parents[1]
MAP_PATH = ROOT / "game" / "audio" / "sfx_map.json"
DOC_DIR = ROOT / "docs" / "review" / "s2-sound"
MD_PATH = DOC_DIR / "clip_events.md"
JSON_PATH = ROOT / "game" / "data" / "audio" / "clip_events.json"
FPS = 60.0
# Voice lines of one clip may overlap the next voice line by at most this many frames (a reverb tail).
VOICE_OVERLAP_F = 3


def _warmup_note_frames(line_id: str, start_f: int) -> list[int]:
    """Clip frames of each note's vowel onset in `vo_bellows_<line_id>` played at `start_f`:
    the score's syllable timing (voices.build) minus the lead-in finalize() trims."""
    import numpy as np
    import voices as V
    from gen_audio import load_recipes
    from synth import db, dc_block, ns, rng_for
    line = V.BELLOWS_LINES[line_id]
    t = 0.02
    onsets = []
    for s in line.syls:
        t += s.gap
        on_len = sum(V.phone_len(q) for q in V.phones(s.c))
        k_on = min(1.0, s.d * 0.45 / on_len) if on_len > 0 else 1.0
        onsets.append(t + on_len * k_on)
        t += s.d
    fid = "vo_bellows_" + line_id
    rec = load_recipes()[fid]
    x = dc_block(np.nan_to_num(np.asarray(rec.fn(rng_for(fid)), dtype=float)), 30.0)
    on = np.nonzero(np.abs(x) > (np.max(np.abs(x)) + 1e-12) * db(-42))[0]
    trim = max(0, int(on[0]) - ns(0.0015)) / V.SR if len(on) else 0.0
    return [start_f + int(round((o - trim) * FPS)) for o in onsets]


def _warmup_rows() -> list[tuple]:
    rows: list[tuple] = []
    for start, lid, label in ((0, "warmup_1", "mi-mi-mi-mi-MIIII (C3 E3 G3 C4, C4 held)"),
                              (360, "warmup_3", "la-la-LAAA (D3 A3, D4 held)")):
        rows.append((start, "voice", f"vo_bellows_{lid}", 0.0,
                     f"the phrase {label} — one sung line per 6 s (GDD §9.5)"))
        for k, f in enumerate(_warmup_note_frames(lid, start), start=1):
            rows.append((f, "sfx", "vase_nudge", 0.0,
                         f"note {k} lands: the vase scoots 10–14 px along the mantel (s2-view nudges it on this event)"))
    return rows


_SPEC: list[dict] | None = None


# (clip, len_f or None, phase, rows [(f, type, id, vol_db, what)], note)
def spec() -> list[dict]:
    global _SPEC
    if _SPEC is None:
        _SPEC = _build_spec()
    return _SPEC


def _build_spec() -> list[dict]:
    S = []

    def clip(cid, len_f, phase, rows, note=""):
        S.append({"clip": cid, "len_f": len_f, "phase": phase, "rows": rows, "note": note})

    # ------------------------------------------------------------------ ACHOO-RIA! (P0)
    clip("bellows/rx_sneeze_blast_a", 165, "G", [
        (0, "voice", "vo_bellows_sneeze_ah1", 0.0, "ah… — the inhale starts on f0, a small rising 'ah' (ends before f20)"),
        (20, "voice", "vo_bellows_sneeze_ah2", 0.0, "ahh… — higher and louder (ends before f44)"),
        (44, "voice", "vo_bellows_sneeze_ah3", 0.0, "AHHH… — highest and loudest, trembling; trails off by f74"),
        (76, "voice", "vo_bellows_sneeze_hm", 0.0, "the false stop: a relieved little 'hm.' — then near-silence to f93"),
        (94, "voice", "vo_bellows_sneeze_choo", 0.0, "**CHOO!** on the accent pop (the 5-f hit-stop sits inside it)"),
        (95, "sfx", "stool_scrape", 0.0, "the stool's legs judder back as the recoil starts (first frame after the pop)"),
        (96, "sfx", "slide_up_flight", 0.0, "slide whistle rising over the flight f96–112, ending on the landing"),
        (112, "sfx", "sink_crash", 0.0, "into the sink on the contact frame (= `knock_on` 112): BONG + crockery + splash"),
        (154, "sfx", "ladle_spin", 0.0, "300 ms of silence after the crash, then one ladle spinning to rest, then drips"),
    ], "Beats from `reactions.json`: ah 0–20, ahh 20–44, AHHH 44–74, false stop 74–94, CHOO 94–97, flight 94–112, "
       "in the sink 97–145, dazed 145–165. **No `laugh` event**: the Stalls' T3 laugh + applause at the hold "
       "(f103 = 9 f after the accent, `cues.json laugh_tiers.hold_delay_s` 0.15) is event-level. After a knock-on at "
       "f112 (HOT & COLD) the drench clip takes over, so f154 never plays there — correct.")

    # ------------------------------------------------------------------ the tea loop
    clip("bellows/act_tea", None, "G", [
        (10, "sfx", "kettle_pour", 0.0, "the kettle tips: water into the cup, pitch rising as it fills"),
        (84, "sfx", "spoon_clink", 0.0, "the spoon dips in: ting"),
        (96, "sfx", "tea_stir", 0.0, "stir: ting-ting-ting round the cup"),
        (150, "sfx", "spoon_clink", -3.0, "tap, tap on the rim"),
        (172, "sfx", "tea_sniff", 0.0, "leans in: sniff-SNIIIFF (the pepper is in there…)"),
        (214, "sfx", "tea_slurp", 0.0, "lip contact: the posh slurp, pinkie up"),
        (262, "sfx", "teacup_clink", 0.0, "the cup goes down on its saucer"),
        (282, "sfx", "stool_creak", -2.0, "shifts his weight: the stool creaks"),
    ], "Frames are for a **300-f reference loop** (he sits on the stool facing −1 throughout; the `decor` event hides "
       "the house stool). Keep the order; put each event on your action's contact frame ± 1 f and keep them ≥ 12 f "
       "apart. No voice in the loop — the tea micro-gags carry his hum.")

    # ------------------------------------------------------------------ the warm-up
    clip("bellows/act_warmup", 720, "G", _warmup_rows(),
         "A **720-f loop** with two phrases 6 s apart (the ≤ 1 sung line per 6 s rule, outside reactions). The phrase "
         "ids are fixed files (not the bank) so each note's `vase_nudge` frame is exact; the style switch maps them to "
         "the tuba takes with the same timing. The micro-gags between the phrases carry no singing.")

    # ------------------------------------------------------------------ micro-gags (overlay clips, mask `upper`)
    clip("bellows/mg_admire_reflection_horn", None, "G", [
        (6, "sfx", "glint", 0.0, "the brass horn gleams back at him"),
        (14, "voice", "vo_bellows_smug", 0.0, "pleased with himself: 'mm-HM!'"),
    ], "Warm-up, emote `smug`.")
    clip("bellows/mg_trill", None, "G", [
        (0, "voice", "vo_bellows_trill", 0.0, "a motorboat lip trill up and down (brrrrr) — a noise, not a sung line"),
    ], "Warm-up, emote `sing`. ≈ 1.0 s; if `len_f` is shorter, the tail rides the blend-out.")
    clip("bellows/mg_conduct_air", None, "G", [
        (0, "sfx", "baton_swish", 0.0, "downbeat 1 of his finger"),
        (15, "sfx", "baton_swish", -2.0, "downbeat 2"),
        (30, "sfx", "baton_swish", 0.0, "downbeat 3 (the flourish)"),
    ], "Warm-up. One swish per downbeat of the conducting finger.")
    clip("bellows/mg_admire_in_kettle", None, "G", [
        (6, "sfx", "glint", 0.0, "the kettle's chrome gleams"),
        (14, "voice", "vo_bellows_smug", 0.0, "'mm-HM!' (the bank never repeats the horn's take)"),
    ], "Tea, emote `smug`.")
    clip("bellows/mg_hum", None, "G", [
        (0, "voice", "vo_bellows_hum", 0.0, "hm-hm-hmm… (bank of 4; the only sung line of the tea loop)"),
    ], "Tea, emote `hum`.")
    clip("bellows/mg_pinkie_up", None, "G", [
        (10, "sfx", "teacup_clink", 0.0, "the cup leaves the saucer as the pinkie flicks up"),
    ], "Tea, emote `smug`.")

    # ------------------------------------------------------------------ last beats (after the settle)
    clip("bellows/beat_slow_burn", 70, "G", [
        (0, "sfx", "bassoon_burn", 0.0, "ONE low bassoon note (D2), dry — then silence: the joke is the silence"),
    ], "Stare 0–70, blink at 40: **no sound on the blink**, nothing after the note.")
    clip("bellows/beat_dignity_fail", 70, "G", [
        (2, "sfx", "cravat_tug", 0.0, "straightens the cravat"),
        (34, "voice", "vo_bellows_ahem", -3.0, "looks round: a dignified 'ahem'"),
        (60, "sfx", "cravat_ping", 0.0, "…and it pings off again (`cravat_pings` 60)"),
    ])
    clip("bellows/beat_bow_topple", 60, "G", [
        (4, "sfx", "bow_creak", 0.0, "the dignified bow: his stays creak all the way down"),
        (30, "sfx", "slide_down_short", 0.0, "the topple (a fall: slide whistle down)"),
        (34, "sfx", "slip_thud", 0.0, "flat on the floor (`floor` 34)"),
    ])
    clip("bellows/beat_tear", 60, "G", [
        (0, "sfx", "sad_violin", 0.0, "the lip quivers: a lone violin weeps two falling notes"),
        (24, "sfx", "tear_plink", 0.0, "the tear lands (`tear` 24)"),
        (42, "sfx", "sniffle", 0.0, "he sniffs it back"),
    ])

    # ------------------------------------------------------------------ Bellows' Phase-G locomotion + bonks
    clip("bellows/loco_idle", None, "G", [
        (0, "sfx", "cravat_tug", -4.0, "on the cravat-tug fidget's tug frame (not every loop: only the fidget)"),
    ], "Breathing is silent; only the fidget's tug makes a sound.")
    clip("bellows/loco_strut", None, "G", [
        (0, "sfx", "bellows_step", -2.0, "foot plant 1 (the slipper 'fwip' + weight)"),
        (16, "sfx", "bellows_step", -2.0, "foot plant 2"),
    ], "A 32-f cycle at the L3 cadence (≈ 15–16 f per step): one event per foot plant, on the plant frame. Hush "
       "hears where he is from these (the director attenuates by rooms; entry warnings boost them +6 dB), so the "
       "entry warning no longer plays its own slipper steps.")
    clip("bellows/loco_blind_shuffle", None, "G", [
        (0, "sfx", "slipper_scuff", 0.0, "foot 1 slides forward, feeling for the floor"),
        (24, "sfx", "slipper_scuff", -2.0, "foot 2"),
    ], "FRAZZLED, arms out. One scuff per foot slide.")
    clip("bellows/cue_doorframe_bonk", 36, "G", [
        (4, "sfx", "woodblock_bonk", 0.0, "the head meets the door frame (contact frame)"),
        (7, "voice", "vo_bellows_oof", -2.0, "'oof!'"),
    ], "Overlay `upper` over the blind shuffle (the `laugh_doorframe` director cue). The crowd titter is event-level.")
    clip("bellows/st_bonk", 60, "G", [
        (0, "sfx", "woodblock_bonk", 0.0, "the bonk (accent 0)"),
        (6, "sfx", "dizzy_tweets", -3.0, "stars orbit (`stars` 6–60)"),
    ], "The door-slam stun (and the curtain-call bonk): the door itself is the event-level `door_slam`.")

    # ------------------------------------------------------------------ Hush: the Gate-0 kitchen set
    clip("hush/loco_walk", None, "G", [
        (0, "sfx", "step_pizz_up", 0.0, "footfall 1: the next pizzicato note of the E-minor scale"),
        (10, "sfx", "step_pizz_up", 0.0, "footfall 2 (10 f per step)"),
    ], "`step_pizz_up` is a *cycle*: each event plays the next note, up E4 → E5 and back down; after 0.8 s without a "
       "step the next walk starts at the bottom again.")
    clip("hush/loco_run", None, "G", [
        (0, "sfx", "step_pizz_up", 2.0, "footfall 1 (the scale runs faster as she runs)"),
        (12, "sfx", "step_pizz_up", 2.0, "footfall 2 (12 f per step)"),
    ])
    clip("hush/act_climb_in", None, "G", [
        (0, "sfx", "window_creak", 0.0, "the kitchen window creaks open"),
        (18, "sfx", "step_pizz_up", -2.0, "rung 1 of the invisible mime ladder (up the scale)"),
        (28, "sfx", "step_pizz_up", -2.0, "rung 2"),
        (38, "sfx", "step_pizz_up", -2.0, "rung 3"),
        (50, "sfx", "step_pizz_up", 0.0, "over the sill: the tiptoe lands"),
    ], "Frames for a 60-f climb (1.0 s of busy time): put each rung on its foot-contact frame. The finger to her "
       "lips is silent — the Stalls' shush is event-level.")
    clip("hush/act_tinker_q", 48, "G", [
        (6, "sfx", "tinker", 0.0, "a tiny ratchet / tik / tap (the bank never repeats)"),
        (22, "sfx", "tinker", 0.0, ""),
        (38, "sfx", "tinker", 0.0, ""),
    ], "The quick tier loops; the ring's ticks and the rig ding are event-level (UI).")
    clip("hush/act_tinker_s", 90, "G", [
        (4, "sfx", "tinker_frantic", 0.0, "a flurry of ticks + a scurrying xylophone run"),
        (48, "sfx", "tinker_frantic", -2.0, "again"),
    ])
    clip("hush/act_tinker_b", 150, "G", [
        (4, "sfx", "tinker_frantic", 0.0, "frantic"),
        (48, "sfx", "tinker_frantic", 0.0, "frantic"),
        (92, "sfx", "tinker", 0.0, "one last tik"),
        (118, "sfx", "hush_phew", 0.0, "the brow wipe: a breathy fwoo + a flick"),
    ])
    clip("hush/act_snicker", None, "G", [
        (0, "sfx", "hush_snicker", 0.0, "shoulders at 8 Hz: the breathy 'hff-hff-hff'"),
    ], "After `rigged` (the sting 'ding + 3 pizz' is event-level).")
    clip("hush/act_dive", 15, "G", [
        (0, "sfx", "dive", 0.0, "the dive swish (its soft thump lands at f12, inside the spot)"),
    ], "`cues.json` keeps only the Stalls' gasp when she dives in watched.")
    clip("hush/act_pop", 15, "G", [
        (0, "sfx", "pop_out", 0.0, "the cork pop + fwip"),
    ])
    for k in range(1, 5):
        clip(f"hush/freeze_{k}", None, "G", [
            (5, "sfx", "freeze_clack", 0.0, "the woodblock CLACK as the statue pose lands (end of the 6-f pop)"),
        ])
    clip("hush/act_squeak", 18, "G", [],
         "**No sound in this clip.** Clarence's squeak stays event-level (`squeak` → `clarence_squeak`): a tap must "
         "answer at once, including when the arm is an overlay or a fallback.")
    return S


def clip_rows(clip_id: str) -> list[dict]:
    for c in spec():
        if c["clip"] == clip_id:
            return [{"f": r[0], "type": r[1], "id": r[2], "vol_db": r[3], "what": r[4]} for r in c["rows"]]
    return []


# Which sim events play over which clips — the L12 duplicate check (test_clip_events.gd) compares
# the cues.json actions of each event (the `by` branch for the filter value) with these clips' rows.
EVENT_CLIPS: list[tuple[str, str, list[str]]] = [
    ("prank_fire", "prank=achoo_ria", ["bellows/rx_sneeze_blast_a"]),
    ("reaction_start", "", ["bellows/rx_sneeze_blast_a"]),
    ("reaction_accent", "", ["bellows/rx_sneeze_blast_a"]),
    ("reaction_end", "", ["bellows/beat_slow_burn", "bellows/beat_dignity_fail", "bellows/beat_bow_topple",
                          "bellows/beat_tear"]),
    ("b_activity", "id=warmup", ["bellows/act_warmup", "bellows/mg_admire_reflection_horn", "bellows/mg_trill",
                                 "bellows/mg_conduct_air"]),
    ("b_activity", "id=tea", ["bellows/act_tea", "bellows/mg_admire_in_kettle", "bellows/mg_hum",
                              "bellows/mg_pinkie_up"]),
    ("micro_gag", "", ["bellows/mg_admire_reflection_horn", "bellows/mg_trill", "bellows/mg_conduct_air",
                       "bellows/mg_admire_in_kettle", "bellows/mg_hum", "bellows/mg_pinkie_up"]),
    ("b_room", "", ["bellows/loco_strut", "bellows/loco_blind_shuffle"]),
    ("entry_warning", "", ["bellows/loco_strut", "bellows/loco_blind_shuffle"]),
    ("director_cue", "id=laugh_doorframe", ["bellows/cue_doorframe_bonk"]),
    ("director_cue", "id=laugh_picture", ["bellows/cue_picture_bonk"]),
    ("door_slam", "", ["bellows/st_bonk"]),
    ("hush_go", "", ["hush/loco_walk", "hush/loco_run"]),
    ("rig_start", "", ["hush/act_tinker_q", "hush/act_tinker_s", "hush/act_tinker_b"]),
    ("rig_step_done", "", ["hush/act_tinker_q", "hush/act_tinker_s", "hush/act_tinker_b"]),
    ("rigged", "", ["hush/act_snicker"]),
    ("hide", "", ["hush/act_dive"]),
    ("pop_out", "", ["hush/act_pop"]),
    ("freeze", "", ["hush/freeze_1", "hush/freeze_2", "hush/freeze_3", "hush/freeze_4"]),
    ("squeak", "", ["hush/act_squeak"]),
]


# Phase M: the Stage-1 per-archetype accent kits and squeak-bit lines deleted from cues.json (L12), kept here as
# the sound design the anim tasks fit to each clip's beats in Phase M ("a" = the clip's accent frame).
CARRIED_OVER: list[tuple[str, str]] = [
    ("bellows/rx_drench_a", "a: vo_bellows_yow (+0.1 s) · hose_wrestle (+0.35 s) — the tap's spray is TAP DANCE's "
                            "event-level fire cue, not a clip event"),
    ("bellows/rx_sing_crack_a", "a: vo_bellows_warmup_crack · lid_boink (+0.5 s)"),
    ("bellows/rx_strain_slip_a", "a: onion_pop · pinball_bonk ×3 (+0.15/0.3/0.45 s) · slip_whoosh (+0.7) · "
                                 "slip_thud (+0.95) · vo_bellows_oof (+1.0) — the jar strain is the fire cue"),
    ("bellows/rx_avalanche_helmet_a", "a: fridge_avalanche · jelly_splat (+0.5) · vo_bellows_oof (+0.55)"),
    ("bellows/rx_dizzy_spin_a", "a: gramophone_babble · coatstand_spin (+0.4) · dizzy_tweets (+1.4) — the speed-up "
                                "is ALLEGRO's fire cue"),
    ("bellows/rx_launch_ceiling_a", "a: catapult_whoosh · vo_bellows_wha (+0.05) · chandelier_jingle (+0.6) · "
                                    "logbasket_crash (+1.3) — the recliner twang is the fire cue"),
    ("bellows/rx_blind_bumble_a", "a: eye_boing · vo_bellows_huh (+0.4)"),
    ("bellows/rx_fish_slap_a", "a: fish_flop · fish_slap (+0.3, +0.6)"),
    ("bellows/rx_jackhammer_cling_a", "a: vo_bellows_dizzy_babble (+0.1) · pendulum_smack (+1.2) — the chimes are "
                                      "TIME'S UP's fire cue"),
    ("bellows/sig_mirror_mirror", "a: vo_bellows_yow · coatstand_spin (+0.25) · crash_tail (+1.2)"),
    ("bellows/cue_picture_bonk", "only his 'oof' (vo_bellows_oof) — the falling frame's whoosh + BONK + clatter is the "
                                 "event-level `laugh_picture` cue (`picture_fall`, the prop)"),
    ("bellows/bit_warmup", "the high note cracks into a yodel (vo_bellows_warmup_crack — a crack-only take lands in "
                           "M0) · vo_bellows_the_pipes after the throat clutch"),
    ("bellows/bit_tea", "tea up his nose: spray_blast (−10 dB) · vo_bellows_ugh (+0.1 s)"),
    ("bellows/bit_paper", "paper_rip on the rip"),
    ("bellows/bit_mirror", "zip as the comb flies · vo_bellows_wha (+0.1 s)"),
    ("bellows/bit_phone", "vo_bellows_did_not_squeak ('I did NOT squeak!') · vo_bellows_grr (+0.8 s)"),
    ("bellows/bit_livid", "vo_bellows_who_squeaked (the rage aria)"),
]


# ------------------------------------------------------------------------------ build + write

def _lens() -> dict:
    """id → length in frames (a bank / cycle / alias → its longest member), from sfx_map.json."""
    if not MAP_PATH.exists():
        return {}
    doc = json.loads(MAP_PATH.read_text())
    out = {}

    def files_of(name, depth=0):
        if name in doc.get("files", {}):
            return [name]
        if name in doc.get("banks", {}):
            return list(doc["banks"][name])
        cyc = doc.get("cycles", {}).get(name)
        if cyc:
            return list(cyc.get("members", []))
        if depth < 6 and name in doc.get("aliases", {}):
            return files_of(doc["aliases"][name], depth + 1)
        return []

    for c in spec():
        for r in c["rows"]:
            fs = files_of(r[2])
            if fs:
                out[r[2]] = int(math.ceil(max(float(doc["files"][f]["len"]) for f in fs) * FPS))
    return out


def validate() -> list[str]:
    """Errors: unknown ids, events past the clip's end, a voice line still sounding when the next starts."""
    errs = []
    lens = _lens()
    seen = set()
    for c in spec():
        if c["clip"] in seen:
            errs.append(f"{c['clip']}: listed twice")
        seen.add(c["clip"])
        rows = sorted(c["rows"], key=lambda r: r[0])
        for r in rows:
            if r[2] not in lens:
                errs.append(f"{c['clip']} f{r[0]}: '{r[2]}' does not resolve in sfx_map.json")
            if c["len_f"] is not None and not (0 <= r[0] < c["len_f"]):
                errs.append(f"{c['clip']} f{r[0]}: outside the clip (0..{c['len_f'] - 1})")
            if r[1] not in ("sfx", "voice"):
                errs.append(f"{c['clip']} f{r[0]}: type '{r[1]}' is not sfx/voice")
        voice = [r for r in rows if r[1] == "voice"]
        for a, b in zip(voice, voice[1:]):
            end = a[0] + lens.get(a[2], 0)
            if end > b[0] + VOICE_OVERLAP_F:
                errs.append(f"{c['clip']}: {a[2]} (f{a[0]}, {lens.get(a[2])} f) still sounds at f{b[0]} ({b[2]})")
    return errs


def render_md() -> str:
    lens = _lens()
    out = ["# Clip events — every sound inside a clip (ruling L12)", "",
           "_Generated by `tools/audio/clip_events.py` (rewritten by `tools/scripts/gen_audio.sh`; do not edit by hand). "
           "Owner: `s2-sound`. The anim tasks place these rows; `cues.json` no longer plays any of them, so a missing "
           "event is silence._", "",
           "Each row is one clip event `{\"f\": f, \"type\": \"sfx\"|\"voice\", \"id\": id}` (+ `\"vol_db\"` when not 0). "
           "Frames are clip frames at 60 fps (view time: a hit-stop holds them); put each on its contact frame ± 1 f. "
           "`len_f` = the sound's length in frames (the longest take of a bank), to check it fits the beat. Ids resolve "
           "through `game/audio/sfx_map.json`; a voice id plays in the Settings `voice_style` automatically. "
           "Machine-readable copy (same rows, the one the tests parse): `game/data/audio/clip_events.json`.", "",
           "Rows are sorted by phase: **G** = land now (Gate 0), **M** = batch 2.", ""]
    for phase in ("G", "M"):
        clips = [c for c in spec() if c["phase"] == phase]
        if not clips:
            continue
        out += [f"## Phase {phase}", ""]
        for c in clips:
            ln = f"{c['len_f']} f" if c["len_f"] is not None else "length: the anim task's"
            out += [f"### `{c['clip']}` ({ln})", ""]
            if c["note"]:
                out += [c["note"], ""]
            if not c["rows"]:
                out += ["_(no clip events)_", ""]
                continue
            out += ["| clip | f | type | id | vol_db | len_f | beat / what it is |", "|---|---|---|---|---|---|---|"]
            for r in sorted(c["rows"], key=lambda r: (r[0], r[2])):
                vol = f"{r[3]:g}" if r[3] else "0"
                out.append(f"| {c['clip']} | {r[0]} | {r[1]} | {r[2]} | {vol} | {lens.get(r[2], '?')} | {r[4]} |")
            out.append("")
    out += ["## Which events play over which clips (the L12 duplicate check)", "",
            "`game/tests/audio/test_clip_events.gd` takes each row below, collects the `cues.json` actions of that event "
            "(the `by` branch for the filter value; `pranks.<id>.fire` for `prank_fire`, `archetypes.*.accent` for "
            "`reaction_accent`) and fails if any id is also a row of one of these clips.", "",
            "| event | filter | clips |", "|---|---|---|"]
    for e, flt, clips in EVENT_CLIPS:
        out.append(f"| {e} | {flt or '—'} | {', '.join(clips)} |")
    out += ["", "## Carried over for Phase M (deleted from `cues.json` by L12)", "",
            "The Stage-1 accent kits and squeak-bit lines, kept as the sound design to fit to each clip's beats in "
            "Phase M (`a` = the accent frame, offsets in seconds). They get exact frame rows above when the clips are "
            "authored.", "", "| clip (Phase M) | sounds |", "|---|---|"]
    for cid, txt in CARRIED_OVER:
        out.append(f"| {cid} | {txt} |")
    out.append("")
    return "\n".join(out)


def render_json() -> str:
    doc = {"version": 1, "_comment": "Generated by tools/audio/clip_events.py — the same rows as clip_events.md.",
           "clips": {}}
    for c in spec():
        evs = []
        for r in sorted(c["rows"], key=lambda r: (r[0], r[2])):
            ev = {"f": r[0], "type": r[1], "id": r[2]}
            if r[3]:
                ev["vol_db"] = r[3]
            evs.append(ev)
        doc["clips"][c["clip"]] = {"len_f": c["len_f"], "phase": c["phase"], "events": evs}
    doc["event_clips"] = [{"event": e, "filter": flt, "clips": clips} for e, flt, clips in EVENT_CLIPS]
    return json.dumps(doc, indent=1, ensure_ascii=False) + "\n"


def write() -> list[str]:
    DOC_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    MD_PATH.write_text(render_md())
    JSON_PATH.write_text(render_json())
    return validate()


def check() -> list[str]:
    errs = validate()
    if not MD_PATH.exists() or MD_PATH.read_text() != render_md():
        errs.append("docs/review/s2-sound/clip_events.md is stale — run tools/audio/clip_events.py")
    if not JSON_PATH.exists() or JSON_PATH.read_text() != render_json():
        errs.append("game/data/audio/clip_events.json is stale — run tools/audio/clip_events.py")
    return errs


def main() -> int:
    errs = check() if "--check" in sys.argv else write()
    for e in errs:
        print("ERROR:", e)
    if "--check" not in sys.argv:
        print(f"wrote {MD_PATH.relative_to(ROOT)} and {JSON_PATH.relative_to(ROOT)} "
              f"({sum(len(c['rows']) for c in spec())} rows)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
