"""Figgis's chip clips (docs/LEVELS.md §5, wave 0). He is a bust in a prompt box in the HUD's top-left corner, so
these are small, loopable and face-led: the idle, the "psst!", the card he holds up, the shh, and the proud nod
when a line lands. Lengths are free (the manifest asks only that they exist); the view cuts them on a state change.
"""


def _k(f, pose, ease="linear", face=None, set_=None):
	d = {"f": f, "pose": pose, "ease": ease}
	if face:
		d["face"] = face
	if set_:
		d["set"] = set_
	return d


def _clip(cid, length, keys, events=(), loop=False, blend=4, tags=(), doc=""):
	return {"version": 1, "clip": "figgis/" + cid, "rig": "figgis", "loop": loop, "length": length,
			"layer": "base", "mask": None, "doc": doc, "blend_in": blend, "blend_out": blend,
			"tags": list(tags), "variation": {"time_jitter": 0.0, "rot_jitter": 0.0}, "smear": {"auto": False},
			"keys": keys, "events": sorted(events, key=lambda e: e["f"])}


def build():
	out = {}
	# the idle: he breathes, his ears twitch, he peers out of the box
	out["f_idle"] = _clip("f_idle", 120, [
		_k(0, "f_rest", "linear", "proud"),
		_k(26, "f_rest", "in_out_sine", set_={"ear_l": {"rot": -7}, "ear_r": {"rot": 2}, "head": {"rot": 3}}),
		_k(58, "f_rest", "in_out_sine", set_={"ear_l": {"rot": 2}, "ear_r": {"rot": -6}, "head": {"rot": -2}}),
		_k(88, "f_rest", "in_out_sine", set_={"ear_l": {"rot": 6}, "ear_r": {"rot": -1}, "head": {"rot": 2}}),
		_k(104, "f_rest", "in_out_sine", set_={"ear_l": {"rot": -2}, "ear_r": {"rot": 4}}),
		_k(120, "f_rest", "in_out_sine", "proud"),
	], loop=True, tags=["idle", "chip"],
		doc="Figgis waiting in his prompt box (120 f, loops): a slow breath, an ear twitch, a peer out at the set.")
	# psst! — he pops up over the lip of the box
	out["f_psst"] = _clip("f_psst", 48, [
		_k(0, "f_rest", "linear", "proud"),
		_k(6, "f_psst", "out_back", "psst"),
		_k(16, "f_psst", "in_out_sine", set_={"head": {"rot": 4}}),
		_k(26, "f_psst", "in_out_sine", set_={"head": {"rot": -3}}),
		_k(36, "f_psst", "in_out_sine", "psst"),
		_k(48, "f_rest", "in_out_sine", "proud"),
	], events=[{"f": 6, "type": "sfx", "id": "figgis_psst"}], tags=["cue", "chip"],
		doc="'Psst!' (48 f): he pops up over the lip of the box to get her attention.")
	# the picture cue card, held long enough to read
	out["f_point_card"] = _clip("f_point_card", 60, [
		_k(0, "f_rest", "linear", "proud"),
		_k(8, "f_point", "out_quad", "point"),
		_k(20, "f_point", "in_out_sine", set_={"hand_r": {"rot": -6}}),
		_k(32, "f_point", "in_out_sine", set_={"hand_r": {"rot": 4}}),
		_k(44, "f_point", "in_out_sine", "point"),
		_k(60, "f_rest", "in_out_sine", "proud"),
	], events=[{"f": 8, "type": "sfx", "id": "figgis_card"}], tags=["cue", "chip"],
		doc="The cue card (60 f): he holds up a picture card and taps it twice — the hint ladder's rung.")
	# shh — a glove to the lips
	out["f_shh"] = _clip("f_shh", 48, [
		_k(0, "f_rest", "linear", "proud"),
		_k(8, "f_shh", "out_quad", "shh", set_={"ear_l": {"rot": -6}, "ear_r": {"rot": 2}}),
		_k(22, "f_shh", "in_out_sine", set_={"head": {"rot": 3}, "ear_l": {"rot": 3}, "ear_r": {"rot": -5}}),
		_k(36, "f_shh", "in_out_sine", "shh", set_={"ear_l": {"rot": -4}, "ear_r": {"rot": 1}}),
		_k(48, "f_rest", "in_out_sine", "proud"),
	], tags=["cue", "chip"],
		doc="Shh (48 f): a glove to the lips — he has spotted Bellows coming before she has.")
	# proud: a slow nod when a Script line lands
	out["f_proud"] = _clip("f_proud", 54, [
		_k(0, "f_rest", "linear", "proud"),
		_k(10, "f_proud", "out_quad", "proud", set_={"ear_l": {"rot": -5}, "ear_r": {"rot": 3}}),
		_k(22, "f_proud", "in_out_sine", set_={"head": {"rot": 6}, "ear_l": {"rot": 4}, "ear_r": {"rot": -2}}),
		_k(32, "f_proud", "in_out_sine", set_={"head": {"rot": -4}, "ear_l": {"rot": -3}, "ear_r": {"rot": 5}}),
		_k(42, "f_proud", "in_out_sine", set_={"head": {"rot": 4}, "ear_l": {"rot": 2}, "ear_r": {"rot": -4}}),
		_k(54, "f_rest", "in_out_sine", "proud"),
	], tags=["cue", "chip"],
		doc="Proud (54 f): a line landed — he nods along, thoroughly pleased with her.")
	return out
