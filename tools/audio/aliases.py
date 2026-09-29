"""Audio id aliases, keyword fallbacks and the content scanner.

Content and code name sounds descriptively ("sneeze_choo", "bonk", "vo_b_pipe_down");
only the registered recipes exist as files. `EXPLICIT` maps well-known names to a file
or bank; `RULES` map names that appear in content later (clip events, barks) to the
closest sound by keyword. `gen_audio.py` writes the result into
game/audio/sfx_map.json "aliases"; `--check` fails when a name referenced by content
doesn't resolve. There is deliberately no catch-all default: a typo is an error, not a bonk.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

EXPLICIT: dict[str, str] = {
    # --- TECH / clip-event shorthands
    "sneeze_choo": "vo_bellows_sneeze_choo", "sneeze_ah1": "vo_bellows_sneeze_ah1",
    "sneeze_ah2": "vo_bellows_sneeze_ah2", "sneeze_ah3": "vo_bellows_sneeze_ah3",
    "sneeze_small": "vo_bellows_sneeze_small",
    "bonk": "woodblock_bonk", "woodblock": "woodblock_bonk", "boing": "boing_med", "slide_whistle_up": "slide_up",
    "slide_whistle_down": "slide_down", "crash": "crash_tail", "pan_spin": "crash_tail", "scratch": "record_scratch",
    "tweets": "dizzy_tweets", "dizzy": "dizzy_tweets", "stamp": "stamp_thunk", "caption_stamp": "stamp_thunk",
    "harp_gliss": "sting_near_miss", "harp": "sting_near_miss", "rimshot": "sting_bit", "rim_shot": "sting_bit",
    "sad_trombone": "sting_caught", "wah_wah": "sting_fizzle", "celesta": "sting_new", "ding": "rig_done",
    # --- footsteps
    "hush_step": "step_pizz", "tiptoe": "step_pizz", "step": "step_pizz", "hush_run": "run_patter",
    "bellows_step": "slipper_wood", "slipper": "slipper_wood", "footstep": "slipper_wood",
    "footsteps": "slipper_wood", "bellows_step_tile": "slipper_tile", "stairs_creak": "stair_creak",
    "creak": "stair_creak",
    # --- doors
    "front_door": "door_front", "back_door": "door_back", "cupboard_door": "cupboard", "handle_jiggle": "door_jiggle",
    "entry_warning": "door_jiggle", "door_slam": "door_slam_bonk", "slam": "door_slam_bonk", "knocker": "knocker_bonk",
    # --- props (activity micro-gags and reaction clips)
    "pepper": "pepper_shake", "stool": "stool_scrape", "stool_zip": "stool_scrape", "splash": "sink_splash", "tap_spray": "spray_blast",
    "spray": "spray_blast", "hose": "hose_wrestle", "kettle": "kettle_melody", "kettle_squeak": "kettle_melody",
    "lid": "lid_boink", "jar": "jar_strain", "pop": "onion_pop", "onion": "onion_pop", "pinball": "pinball_bonk",
    "slip": "slip_whoosh", "thud": "slip_thud", "gramophone": "gramophone_speedup", "record_speedup": "gramophone_speedup",
    "babble_x3": "gramophone_babble", "twang": "recliner_twang", "catapult": "catapult_whoosh",
    "chandelier": "chandelier_jingle", "log_basket": "logbasket_crash", "rustle": "paper_rustle", "rip": "paper_rip",
    "magnifier": "eye_boing", "eye_pop": "eye_boing", "fish": "fish_flop", "kipper_slap": "fish_slap",
    "phone": "phone_ring", "chimes": "clock_chimes", "clock": "clock_chimes", "pendulum": "pendulum_smack",
    "coat_stand": "coatstand_spin", "spin": "coatstand_spin", "avalanche": "fridge_avalanche",
    "jelly": "jelly_splat", "mirror_glass": "mirror_lift", "poof": "flour_poof", "flour": "flour_poof",
    "bellows_air": "bellows_pump", "fire": "fire_crackle", "specs": "specs_tink", "specs_on": "specs_tink",
    "vase": "vase_smash", "window": "window_creak", "stomp": "stomp_quake", "meltdown_stomp": "stomp_quake",
    "picture": "picture_fall", "house_lights": "house_lights_dim",
    # --- stealth / Hush / Clarence / UI
    "hide": "dive", "unhide": "pop_out", "freeze": "freeze_clack", "clack": "freeze_clack", "tomato": "tomato_splat",
    "splat": "tomato_splat", "curtain_up": "curtain_rise", "curtain_down": "curtain_fall", "roses": "roses_thrown",
    "squeak": "clarence_squeak", "clarence": "clarence_squeak", "chicken": "clarence_squeak",
    "wheeze_chicken": "clarence_wheeze", "smitten": "clarence_smitten", "take": "hush_take",
    "snicker": "hush_snicker", "silent_laugh": "hush_snicker", "tap": "ui_tick", "press": "ui_press",
    "ui_tap": "ui_tick", "ui_button": "ui_press", "ring_half": "ring_tick", "rig_ding": "rig_done", "pause": "ui_pause",
    "card": "card_whoosh", "figgis_card": "card_whoosh",
    # --- crowd shorthands (Audio.crowd() adds the crowd_ prefix itself)
    "laugh": "crowd_t2", "titter": "crowd_t0", "chuckle": "crowd_t1", "roar": "crowd_t4", "applause": "crowd_t3",
    "cheer": "crowd_cheer", "crowd_pipe_down": "crowd_chant", "crowd_bow": "crowd_bow_chant",
    # --- voice shorthands (barks.json uses vo_<speaker>_<line>; `vo_b_` handled by a rule)
    "vo_bellows_crack": "vo_bellows_warmup_crack", "vo_bellows_yodel": "vo_bellows_warmup_crack",
    "vo_bellows_scales": "vo_bellows_warmup", "vo_bellows_lecture_1": "vo_bellows_lecture_a",
    "vo_bellows_lecture_2": "vo_bellows_lecture_b", "vo_bellows_lecture_3": "vo_bellows_lecture_c",
    "vo_bellows_hum_tea": "vo_bellows_hum_1", "vo_bellows_pipes": "vo_bellows_the_pipes",
    "vo_bellows_whosqueaked": "vo_bellows_who_squeaked", "vo_bellows_wha_shout": "vo_bellows_wha",
    "vo_bellows_babble": "vo_bellows_dizzy_babble", "vo_bellows_sneeze": "vo_bellows_sneeze_choo",
    "vo_bellows_hmm": "vo_bellows_hum", "vo_bellows_mmph": "vo_bellows_hmph",
    # --- names the rig task's _mannequin clips use
    "step_soft": "step_pizz", "thud_big": "slip_thud", "boing_eyes": "eye_boing", "slide_up_short": "slide_up",
    "crash_small": "vase_smash",
}

# Keyword fallbacks for names that content adds later: (regex, target template). A template
# may use \1 for the first group. First match wins; unmatched names are errors in --check.
RULES: list[tuple[str, str]] = [
    (r"^vo_b_(.+)$", r"vo_bellows_\1"),
    (r"^vo_mannequin_(.+)$", r"vo_bellows_\1"),   # the test rig borrows Bellows' bank
    (r"^vo_bellows_(.+)_[abc]$", r"vo_bellows_\1"),
    (r"^sting_(?:link_?4|link4|chain)$", "sting_link3"),
    (r"^sting_link_?2$", "sting_link2"),
    (r"^sting_(?:q|question|suspicious)$", "sting_spot"),
    (r"^sting_(?:exclaim|spotted|bang)$", "sting_alert"),
    (r"^crowd_(?:laugh|big)$", "crowd_t2"),
    (r"step|tiptoe", "step_pizz"), (r"slipper|footstep", "slipper_wood"), (r"stair", "stair_creak"),
    (r"jiggle|handle", "door_jiggle"), (r"door", "door_front"), (r"cupboard|drawer", "cupboard"),
    (r"boing|bounce|spring", "boing_med"), (r"bonk|knock|thonk|block", "woodblock_bonk"),
    (r"slide_?up|rise", "slide_up"), (r"slide_?down|fall", "slide_down"), (r"whoosh|swish|swoosh", "whoosh"),
    (r"zip", "zip"), (r"crash|smash|shatter", "crash_tail"), (r"scratch|record", "record_scratch"),
    (r"tweet|bird|dizzy", "dizzy_tweets"), (r"stamp", "stamp_thunk"), (r"sneeze|achoo|choo", "vo_bellows_sneeze_choo"),
    (r"splash|water|drench|sink", "sink_splash"), (r"spray|squirt|jet", "spray_blast"), (r"hose", "hose_wrestle"),
    (r"kettle|whistle", "kettle_melody"), (r"lid", "lid_boink"), (r"strain|jar", "jar_strain"),
    (r"pop", "onion_pop"), (r"pan|pot|clang|ting", "pinball_bonk"), (r"slip", "slip_whoosh"),
    (r"thud|land|flop_down", "slip_thud"), (r"gramophone|needle", "gramophone_speedup"),
    (r"twang", "recliner_twang"), (r"launch|catapult", "catapult_whoosh"), (r"crystal|jingle", "chandelier_jingle"),
    (r"log|wood_crash", "logbasket_crash"), (r"rustle|paper", "paper_rustle"), (r"rip|tear", "paper_rip"),
    (r"eye|magnif", "eye_boing"), (r"fish|kipper", "fish_slap"), (r"slap|smack|whack", "pendulum_smack"),
    (r"phone|ring", "phone_ring"), (r"chime|clock|bell", "clock_chimes"), (r"spin|twirl", "coatstand_spin"),
    (r"avalanche|clatter|tins", "fridge_avalanche"), (r"jelly|wobble", "jelly_splat"), (r"glass|mirror", "mirror_lift"),
    (r"poof|flour|puff", "flour_poof"), (r"fire|crackle", "fire_crackle"), (r"specs|tink|glint", "specs_tink"),
    (r"stomp|quake", "stomp_quake"), (r"splat|tomato|goo", "tomato_splat"), (r"curtain", "curtain_rise"),
    (r"rose|flower", "roses_thrown"), (r"squeak|clarence|chicken", "clarence_squeak"), (r"dive|hide", "dive"),
    (r"freeze|clack", "freeze_clack"), (r"snicker|giggle", "hush_snicker"), (r"^ui_", "ui_press"),
]

_KEYS = re.compile(r"(^sfx$|_sfx$|^sfx_|^bank$|_bank$)")
_EVENT_TYPES = ("sfx", "voice")


def scan_refs(data_dir: Path) -> dict[str, list[str]]:
    """Audio ids referenced by content JSON (everything under game/data except audio/cues.json,
    which gen_audio.cue_refs() reads with its own schema): clip events {"type": "sfx"|"voice",
    "id"|"bank": ...} and any key named sfx / *_sfx / sfx_* / bank / *_bank."""
    refs: dict[str, list[str]] = {}

    def add(v, where):
        vals = v if isinstance(v, list) else [v]
        for s in vals:
            if isinstance(s, str) and s:
                refs.setdefault(s, []).append(where)

    def walk(v, path, fname):
        if isinstance(v, dict):
            is_event = v.get("type") in _EVENT_TYPES
            if is_event:
                for k in ("id", "bank", "name"):
                    if k in v:
                        add(v[k], f"{fname}:{path}.{k}")
            for k, x in v.items():
                p = f"{path}.{k}" if path else str(k)
                if isinstance(k, str) and _KEYS.search(k) and not isinstance(x, dict) and not (is_event and k == "bank"):
                    add(x, f"{fname}:{p}")
                walk(x, p, fname)
        elif isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, f"{path}[{i}]", fname)

    if not data_dir.exists():
        return refs
    for f in sorted(data_dir.rglob("*.json")):
        rel = f.relative_to(data_dir).as_posix()
        if rel == "audio/cues.json":
            continue
        try:
            d = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        walk(d, "", rel)
    return refs


def infer(name: str) -> tuple[str | None, str]:
    """→ (target, how): explicit | rule:<pattern>; (None, 'unmatched') when nothing fits."""
    if name in EXPLICIT:
        return EXPLICIT[name], "explicit"
    for pat, target in RULES:
        mm = re.search(pat, name)
        if mm:
            return (mm.expand(target) if "\\" in target else target), f"rule:{pat}"
    return None, "unmatched"


def resolve(name: str, aliases: dict[str, str], known: set[str], depth: int = 0) -> str | None:
    """Follow an alias chain like Audio does → a file id / bank id, or None."""
    if name in known:
        return name
    if depth > 6 or name not in aliases:
        return None
    return resolve(aliases[name], aliases, known, depth + 1)
