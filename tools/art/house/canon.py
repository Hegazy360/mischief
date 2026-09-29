"""Canonical ids from docs/TECH.md §14 (binding). `check_against_tech()` re-parses TECH.md so a
drift between this copy and the doc is caught by the lint."""
import os
import re

ROOMS = ["porch", "hall", "parlour", "kitchen", "conservatory", "garden", "landing", "bathroom", "bedroom", "dressing"]
LINKS = ["front_door", "hall_parlour", "parlour_kitchen", "back_door", "conservatory_garden", "landing_bathroom",
         "bathroom_bedroom", "bedroom_dressing", "stairs"]
STATIONS = {
    "st_gramophone": [], "st_piano": [], "st_recliner": [], "st_fireplace": ["DRY"], "st_chaise": [],
    "st_parlour_centre": [],
    "st_tea": ["HONEY"], "st_pickles": [], "st_fridge": [], "st_sink": ["SINK"],
    "st_hall_mirror": ["MIRROR"], "st_phone": [], "st_clock": [], "st_front_door": [],
    "st_feed_bin": [], "st_sun_lounger": ["DRY"],
    "st_hose": [], "st_marrow": [], "st_path": [], "st_stage": [],
    "st_radiator": ["DRY"],
    "st_basin": ["SINK", "MIRROR"], "st_bath": [],
    "st_wardrobe": [], "st_bed": [],
    "st_dressing_mirror": ["MIRROR"], "st_trophy": [], "st_dummy": [],
}
CONTAINERS = ["hall_confiscated_box", "hall_piggy_bank", "kitchen_fridge", "kitchen_pantry_shelf", "bathroom_cabinet",
              "conservatory_potting_bench", "dressing_costume_trunk"]
HIDING = {"hall_coat_cupboard": None, "hall_clock_case": "clock", "parlour_piano_back": None,
          "parlour_chaise_back": None, "kitchen_pantry_curtain": None, "kitchen_table": None,
          "conservatory_hamper": None, "garden_shed": None, "garden_compost": None,
          "landing_airing_cupboard": None, "bathroom_bath": "bath", "bathroom_laundry_basket": None,
          "bedroom_wardrobe": "dress", "bedroom_under_bed": None, "dressing_costume_rail": None}
RIG_POINTS = {
    "kitchen_honey": ["achoo_ria"], "kitchen_kettle": ["kettle_drum"], "kitchen_pickle_jar": ["in_a_pickle"],
    "kitchen_fridge_shelf": ["cold_open"], "kitchen_sink_tap": ["tap_dance"],
    "parlour_gramophone": ["allegro_go_go", "it_takes_two"], "parlour_recliner": ["lift_off"],
    "parlour_newspaper": ["eye_popping_news"], "parlour_bellows": ["bellows_blows"],
    "parlour_chandelier": ["prima_ballerina"], "parlour_piano_wedge": ["grand_exit"],
    "parlour_tea_tray": ["spit_take"], "parlour_fan": ["fan_mail"],
    "hall_phone": ["something_fishy"], "hall_clock": ["times_up"], "hall_mirror": ["mirror_mirror"],
    "stairs_rods": ["rug_burn"],
    "bathroom_basin_spray": ["sopran_oh_no"], "bathroom_duck": ["snap_decision"],
    "bathroom_bath_taps": ["in_over_his_head"], "landing_boiler_valve": ["pipe_down"],
    "bedroom_pillow": ["pillow_talk"], "bedroom_bedside": ["butter_fingers"], "bedroom_bed": ["kidding_around"],
    "dressing_dummy": ["tutu_much"], "dressing_trophy_shelf": ["award_winning"],
    "conservatory_feed_bin": ["sweet_tooth"], "garden_hose": ["hosed"], "garden_marrow": ["marrow_escape"],
    "garden_coin_1": ["penny_pincher"], "garden_coin_2": ["penny_pincher"], "garden_coin_3": ["penny_pincher"],
    "garden_spotlight": ["spotlight_stealer"],
}
EXITS = ["hall_front_door", "kitchen_back_door", "stairs_foot", "stairs_head", "kitchen_window"]
HOTSPOTS = CONTAINERS + list(HIDING) + list(RIG_POINTS) + EXITS
ITEMS = ["squeaker", "magnifier", "balloon", "croc", "kipper", "butter", "flour", "sherbet", "treacle", "salt",
         "bubble_bath", "apple", "feathers", "coins", "tutu", "record"]
ACTIVITIES = ["warmup", "tea", "pickles", "snack", "rinse", "paper", "fire", "mirror", "phone", "clock", "piano",
              "gargle", "bath", "radiator", "dress", "nap", "feed_beryl", "roses", "marrow", "stroll", "polish",
              "cloak", "answer_door", "host_tea", "tango", "rehearse", "hunt"]
DETOURS = ["fixup_dry", "fixup_sink", "fixup_honey", "fixup_mirror", "curious", "herd_beryl", "search"]
SHARED = [("kitchen_fridge", "kitchen_fridge_shelf"), ("kitchen_pantry_shelf", "kitchen_pantry_curtain"),
          ("hall_clock", "hall_clock_case"), ("landing_airing_cupboard", "landing_boiler_valve"),
          ("bathroom_bath_taps", "bathroom_bath"), ("bedroom_bed", "bedroom_under_bed", "bedroom_pillow"),
          ("stairs_rods", "stairs_foot")]

TECH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "TECH.md")


def check_against_tech(path=TECH):
    """Every id this module lists appears in TECH.md §14 (and the section's hotspot ids are all here)."""
    if not os.path.exists(path):
        return ["TECH.md not found at %s" % path]
    txt = open(path).read()
    i = txt.find("## 14. Canonical ids")
    sec = txt[i:] if i >= 0 else txt
    errs = []
    for ident in ROOMS + LINKS + list(STATIONS) + HOTSPOTS + ITEMS + ACTIVITIES + DETOURS:
        if not re.search(r"\b%s\b" % re.escape(ident), sec):
            errs.append("id %s not found in TECH §14" % ident)
    # hotspot ids in the doc that we miss
    hs = sec[sec.find("**Hotspots"):sec.find("**Items:**")]
    for m in re.findall(r"\b((?:hall|kitchen|parlour|bathroom|landing|bedroom|dressing|conservatory|garden|stairs)_[a-z0-9_]+)\b", hs):
        if m not in HOTSPOTS and m not in LINKS and m not in ROOMS:
            errs.append("TECH §14 hotspot %s missing from canon.py" % m)
    return errs
