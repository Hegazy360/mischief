## Run — the whole prototype game as a pure, deterministic engine. No nodes, no drawing, no input.
##
## PROTOTYPE 1a (docs/review/pivot/2026_options.md §4, Option 1a): the Mischief theme as a systems
## roguelike. Bellows walks a fixed routine of six stations; you rig prank cards onto them; CURTAIN UP
## resolves the routine left to right. Adjacent firings build a **chain multiplier**, residues stick to
## him for the rest of the Night and feed later cards, and his **temper** tiers up and pays a flat bonus
## on every fire. Between rounds you draft one of three cards or Encores.
##
## Everything a player can do is `place` / `unplace` / `resolve` / `take_draft`, and every point scored
## comes back in `resolve()` as a list of labelled parts — so the UI can always say WHY the number moved,
## and the headless balance simulator (`sim.gd`) can play thousands of runs without a renderer.
class_name Run
extends RefCounted

const STATIONS := [
	{"name": "GRAMOPHONE", "room": "parlour"},
	{"name": "TEA COUNTER", "room": "kitchen"},
	{"name": "CHEVAL MIRROR", "room": "hall"},
	{"name": "PICKLE SHELF", "room": "kitchen"},
	{"name": "RECLINER", "room": "parlour"},
	{"name": "SINK", "room": "kitchen"},
]
const N_STATIONS := 6
const ROUNDS_PER_NIGHT := 4
## Applause needed to get through Night 1, 2, 3.
const TARGETS := [65, 120, 230]
const BASE_NERVE := 3
const BASE_DRAW := 5
## Chain multiplier by how many stations have fired in an unbroken run (×100).
const CHAIN_MULT := [100, 150, 200, 300, 400]
## Temper thresholds for Calm / Irked / Steaming / Livid.
const TIER_AT := [0, 12, 28, 50]
const TIER_NAMES := ["CALM", "IRKED", "STEAMING", "LIVID"]
## Flat Applause per fire, per temper tier.
const TIER_BONUS := 2

var cards: Dictionary = {}
var encores_db: Dictionary = {}
var rng := RandomNumberGenerator.new()

var night: int = 1
var round_i: int = 1
var applause: int = 0
var target: int = 0
var temper: int = 0
var residues: PackedStringArray = PackedStringArray()
var deck: PackedStringArray = PackedStringArray()
var hand: PackedStringArray = PackedStringArray()
var discard: PackedStringArray = PackedStringArray()
## Per station: a card id, or "" when empty.
var board: PackedStringArray = PackedStringArray()
var nerve: int = 0
var encores: PackedStringArray = PackedStringArray()
## The routine order for this Night (indices into STATIONS).
var routine: PackedInt32Array = PackedInt32Array()
var over: bool = false
var won: bool = false
## Filled by draft_options(), consumed by take_draft().
var offers: Array = []


func setup(card_data: Dictionary, encore_data: Dictionary, seed_v: int) -> void:
	cards = card_data.get("cards", {})
	encores_db = encore_data.get("encores", {})
	rng.seed = seed_v
	deck = PackedStringArray(card_data.get("starter", []))
	discard = PackedStringArray()
	hand = PackedStringArray()
	encores = PackedStringArray()
	night = 0
	applause = 0
	over = false
	won = false
	_next_night()


# --- flow ----------------------------------------------------------------------------------------

func _next_night() -> void:
	night += 1
	round_i = 1
	applause = 0
	temper = 0
	residues = PackedStringArray()
	target = int(TARGETS[mini(night - 1, TARGETS.size() - 1)])
	# a different running order each Night, so the room and adjacency cards play differently
	routine = PackedInt32Array(range(N_STATIONS))
	for i in range(N_STATIONS - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := routine[i]
		routine[i] = routine[j]
		routine[j] = t
	_start_round()


func _start_round() -> void:
	board = PackedStringArray()
	board.resize(N_STATIONS)
	for i in N_STATIONS:
		board[i] = ""
	nerve = BASE_NERVE + _enc("nerve")
	var want := BASE_DRAW + _enc("draw")
	discard.append_array(hand)
	hand = PackedStringArray()
	for i in want:
		_draw_one()


func _draw_one() -> void:
	if deck.is_empty():
		if discard.is_empty():
			return
		deck = discard.duplicate()
		discard = PackedStringArray()
		for i in range(deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := deck[i]
			deck[i] = deck[j]
			deck[j] = t
	hand.append(deck[deck.size() - 1])
	deck.remove_at(deck.size() - 1)


## Station index `s` of the `n`-th stop on tonight's routine.
func station_at(n: int) -> Dictionary:
	return STATIONS[routine[n]]


## Nerve a card costs right now (the first one is free with SECOND BANANA).
func cost_of(card_id: String) -> int:
	if _has_enc("first_free") and _rigged_count() == 0:
		return 0
	return int((cards.get(card_id, {}) as Dictionary).get("cost", 1))


func _rigged_count() -> int:
	var n := 0
	for c in board:
		if c != "":
			n += 1
	return n


## Rig `hand[hand_i]` onto routine position `pos`. Returns "" on success, else why not.
func place(hand_i: int, pos: int) -> String:
	if hand_i < 0 or hand_i >= hand.size():
		return "no such card"
	if pos < 0 or pos >= N_STATIONS:
		return "no such station"
	if board[pos] != "":
		return "that station is already rigged"
	var id := hand[hand_i]
	var c := cost_of(id)
	if c > nerve:
		return "not enough Nerve"
	nerve -= c
	board[pos] = id
	hand.remove_at(hand_i)
	return ""


## Take the prank back off a station and into the hand.
func unplace(pos: int) -> void:
	if pos < 0 or pos >= N_STATIONS or board[pos] == "":
		return
	var id := board[pos]
	board[pos] = ""
	hand.append(id)
	nerve += int((cards.get(id, {}) as Dictionary).get("cost", 1))
	# SECOND BANANA: recompute so the refund can never leak Nerve
	nerve = mini(nerve, BASE_NERVE + _enc("nerve"))


# --- resolution ----------------------------------------------------------------------------------

## Walk the routine and score it. Returns one step Dictionary per stop, in order, each with:
##   {pos, station, room, card, fired, parts:[[label, amount]], mult, temper_bonus, gain,
##    applause_after, temper_after, tier_after, residue, chain, repeat}
## plus a final {end: true, ...} step carrying the end-of-round Encore payouts.
func resolve() -> Array:
	var steps: Array = []
	var chain := 0
	var fired_before := 0
	var retrigger := false
	var last_value := 0
	# SLOW BURN raises temper by how much you rigged, before anything fires
	for pos in N_STATIONS:
		var pre: Dictionary = cards.get(board[pos], {}) if board[pos] != "" else {}
		var per := int(pre.get("temper_per_rigged", 0))
		if per > 0:
			temper += per * _rigged_count()
	for pos in N_STATIONS:
		var id := board[pos]
		var st := station_at(pos)
		if id == "":
			chain = 0
			steps.append({"pos": pos, "station": st["name"], "room": st["room"], "card": "",
				"fired": false, "parts": [], "mult": 100, "temper_bonus": 0, "gain": 0,
				"applause_after": applause, "temper_after": temper, "tier_after": tier(),
				"residue": "", "chain": 0, "repeat": 1})
			continue
		var cd: Dictionary = cards.get(id, {})
		if _rigged_count() < int(cd.get("needs_rigged", 0)):
			chain = 0
			steps.append({"pos": pos, "station": st["name"], "room": st["room"], "card": id,
				"fired": false, "parts": [["FIZZLED — needs %d stations rigged" % int(cd.get("needs_rigged", 0)), 0]], "mult": 100,
				"temper_bonus": 0, "gain": 0, "applause_after": applause, "temper_after": temper,
				"tier_after": tier(), "residue": "", "chain": 0, "repeat": 1})
			continue
		chain += 1
		var mult := _chain_mult(chain)
		var repeat := int(cd.get("fires", 1))
		if retrigger:
			repeat += 1
			retrigger = false
		if _has_enc("every_nth") and _enc("every_nth") > 0 and (fired_before + 1) % _enc("every_nth") == 0:
			repeat += 1
		var parts: Array = []
		var value := _value(id, cd, pos, chain, fired_before, last_value, parts)
		last_value = value
		var tb := tier() * TIER_BONUS * maxi(1, _enc("tier_mult"))
		var gain := 0
		for r in repeat:
			gain += int(floor(float(value * mult) / 100.0)) + tb
		applause += gain
		temper += int(cd.get("temper", 3))
		fired_before += repeat
		var res := str(cd.get("residue", ""))
		if res != "":
			if not residues.has(res):
				residues.append(res)
				residues.sort()
			if _has_enc("residue_fire"):
				var rb := _enc("residue_fire")
				applause += rb
				gain += rb
				parts.append(["TIN EAR", rb])
		if bool(cd.get("retrigger_next", false)):
			retrigger = true
		steps.append({"pos": pos, "station": st["name"], "room": st["room"], "card": id,
			"fired": true, "parts": parts, "mult": mult, "temper_bonus": tb, "gain": gain,
			"applause_after": applause, "temper_after": temper, "tier_after": tier(),
			"residue": res, "chain": chain, "repeat": repeat})
	steps.append(_end_of_round(fired_before))
	return steps


## End-of-round Encore payouts, as one final step.
func _end_of_round(fired: int) -> Dictionary:
	var parts: Array = []
	if _has_enc("full_house") and fired >= N_STATIONS:
		parts.append(["FULL HOUSE", _enc("full_house")])
	if _has_enc("unspent") and nerve > 0:
		parts.append(["CURTAIN CALL", _enc("unspent") * nerve])
	if _has_enc("clean") and residues.is_empty():
		parts.append(["CLEAN SWEEP", _enc("clean")])
	var total := 0
	for p in parts:
		total += int(p[1])
	applause += total
	return {"end": true, "pos": -1, "station": "", "room": "", "card": "", "fired": total > 0,
		"parts": parts, "mult": 100, "temper_bonus": 0, "gain": total, "applause_after": applause,
		"temper_after": temper, "tier_after": tier(), "residue": "", "chain": 0, "repeat": 1}


## A card's Applause before the chain multiplier. Appends every contribution to `parts`.
func _value(id: String, cd: Dictionary, pos: int, chain: int, fired_before: int, last_value: int,
		parts: Array) -> int:
	if bool(cd.get("copy_left", false)):
		parts.append(["COPIES THE PRANK ON ITS LEFT", last_value])
		return last_value
	var v := int(cd.get("base", 0))
	parts.append(["BASE", v])
	for b: Dictionary in cd.get("bonus", []):
		var add := 0
		var label := ""
		match str(b.get("if", "")):
			"prev_fired":
				if chain > 1:
					add = int(b.get("add", 0))
					label = "THE ONE BEFORE IT FIRED"
			"fired_before":
				add = int(b.get("per", 0)) * fired_before
				label = "%d ALREADY FIRED" % fired_before
			"chain_len":
				add = int(b.get("per", 0)) * (chain - 1)
				label = "CHAIN OF %d" % (chain - 1)
			"residue":
				if residues.has(str(b.get("kind", ""))):
					add = int(b.get("add", 0))
					label = str(b.get("kind", ""))
			"residues_all":
				var all_there := true
				for k in b.get("kinds", []):
					if not residues.has(str(k)):
						all_there = false
				if all_there:
					add = int(b.get("add", 0))
					label = "+".join(PackedStringArray(b.get("kinds", [])))
			"residue_count":
				add = int(b.get("per", 0)) * residues.size()
				label = "%d RESIDUES" % residues.size()
			"no_residue":
				if residues.is_empty():
					add = int(b.get("add", 0))
					label = "SPOTLESS"
			"any_residue":
				if not residues.is_empty():
					add = int(b.get("add", 0))
					label = "HE IS ALREADY A MESS"
			"temper_tier":
				add = int(b.get("per", 0)) * tier()
				label = "%s" % TIER_NAMES[tier()]
			"tier_min":
				if tier() >= int(b.get("tier", 0)):
					add = int(b.get("add", 0))
					label = TIER_NAMES[int(b.get("tier", 0))]
			"room":
				if str(station_at(pos)["room"]) == str(b.get("room", "")):
					add = int(b.get("add", 0))
					label = str(b.get("room", "")).to_upper()
			"room_count":
				var n := 0
				for other in N_STATIONS:
					if other != pos and board[other] != "" and str(station_at(other)["room"]) == str(b.get("room", "")):
						n += 1
				add = int(b.get("per", 0)) * n
				label = "%d MORE %s" % [n, str(b.get("room", "")).to_upper()]
		if add != 0:
			parts.append([label, add])
			v += add
	return maxi(0, v)


func _chain_mult(chain: int) -> int:
	var i: int = chain - 1 + _enc("chain_step")
	return int(CHAIN_MULT[clampi(i, 0, CHAIN_MULT.size() - 1)])


## Temper tier 0..3.
func tier() -> int:
	var t := 0
	for i in TIER_AT.size():
		if temper >= int(TIER_AT[i]):
			t = i
	return t


func tier_name() -> String:
	return TIER_NAMES[tier()]


# --- round / night boundaries --------------------------------------------------------------------

## Called after the player has watched `resolve()`. Returns "draft" | "night_won" | "won" | "lost".
func finish_round() -> String:
	for i in N_STATIONS:
		if board[i] != "":
			discard.append(board[i])
			board[i] = ""
	if applause >= target:
		if night >= TARGETS.size():
			over = true
			won = true
			return "won"
		return "night_won"
	if round_i >= ROUNDS_PER_NIGHT:
		over = true
		won = false
		return "lost"
	round_i += 1
	_start_round()
	return "draft"


## Begin the next Night (after a "night_won").
func next_night() -> void:
	_next_night()


## Three things to choose between: card ids and `enc:<id>`.
func draft_options() -> Array:
	offers = []
	var pool: Array = []
	for id: String in cards:
		if not PackedStringArray(["pepper", "tap", "flour", "domino"]).has(id):
			pool.append(id)
	var epool: Array = []
	for id: String in encores_db:
		if not encores.has(id):
			epool.append("enc:" + id)
	pool.shuffle()
	epool.shuffle()
	# two pranks and an Encore when one is left, else three pranks
	for i in mini(2, pool.size()):
		offers.append(pool[i])
	if not epool.is_empty():
		offers.append(epool[0])
	elif pool.size() > 2:
		offers.append(pool[2])
	return offers


## Take offer `i` (or -1 to skip).
func take_draft(i: int) -> void:
	if i < 0 or i >= offers.size():
		return
	var pick := str(offers[i])
	if pick.begins_with("enc:"):
		encores.append(pick.substr(4))
	else:
		discard.append(pick)
	offers = []


# --- snapshot ------------------------------------------------------------------------------------

## Everything `resolve()` touches, so a bot (or an undo) can try a line and take it back.
func snapshot() -> Dictionary:
	return {"applause": applause, "temper": temper, "residues": residues.duplicate(),
		"board": board.duplicate(), "nerve": nerve, "hand": hand.duplicate(),
		"deck": deck.duplicate(), "discard": discard.duplicate()}


func restore(s: Dictionary) -> void:
	applause = int(s["applause"])
	temper = int(s["temper"])
	residues = (s["residues"] as PackedStringArray).duplicate()
	board = (s["board"] as PackedStringArray).duplicate()
	nerve = int(s["nerve"])
	hand = (s["hand"] as PackedStringArray).duplicate()
	deck = (s["deck"] as PackedStringArray).duplicate()
	discard = (s["discard"] as PackedStringArray).duplicate()


# --- encores -------------------------------------------------------------------------------------

func _enc(key: String) -> int:
	var total := 0
	for e in encores:
		total += int((encores_db.get(e, {}) as Dictionary).get(key, 0))
	return total


func _has_enc(key: String) -> bool:
	for e in encores:
		if (encores_db.get(e, {}) as Dictionary).has(key):
			return true
	return false
