## WhyMissed — the curtain call's one "why" line (GDD §6.2, s2-night §4.3). Pure.
##
## First match, in this order:
## 1. a required line missed → `missed_required`;
## 2. required done, the Big Number not done → `missed_big_number` (still sealed) / `big_number_open`;
## 3. an optional line missed → `missed_optional`;
## 4. Applause < 100 → the first of `short_link` > `short_meltdown` > `short_near_misses` > `short_bits` >
##    `short_combo` > `short_embarrassed` the Night can offer (`can`) and the player has not maxed
##    (`maxed`) — no `short_combo` where `rules.combos` is `[]`, `short_meltdown` only where a Meltdown can
##    happen, `short_embarrassed` only with Delphine;
## 5. catches cost Applause → `catches`;
## 6. ★★★ → `standing_ovation`; the Prologue → `prologue`.
## Templates come from `barks.json results.*`, the "hasn't …" phrases from `barks.json missed`
## (by prank id, then "<episode>:<line id>").
class_name WhyMissed
extends RefCounted

const SHORT_ORDER: PackedStringArray = ["short_link", "short_meltdown", "short_near_misses", "short_bits", "short_combo",
	"short_embarrassed"]
const STAR3 := 100
const CATCH_COST := 5


## `r`: {episode, prologue: bool, applause, catches, stars: [..], lines: [{id, done, req, big_number, sealed,
## prank}], can: {short_link: bool, …}, maxed: {short_link: bool, …}}. Returns {key, text}.
static func pick(r: Dictionary, templates: Dictionary, missed: Dictionary) -> Dictionary:
	var key := pick_key(r)
	return {"key": key, "text": fill(key, r, templates, missed)}


## The template key alone (the order above).
static func pick_key(r: Dictionary) -> String:
	if bool(r.get("prologue", false)):
		return "prologue"
	var lines: Array = r.get("lines", [])
	var req_missed := false
	var bn_missing := false
	var bn_sealed := false
	var opt_missed := false
	for l in lines:
		var d: Dictionary = l
		if bool(d.get("done", false)):
			continue
		if bool(d.get("big_number", false)):
			bn_missing = true
			bn_sealed = bool(d.get("sealed", false))
		elif bool(d.get("req", false)):
			req_missed = true
		else:
			opt_missed = true
	if req_missed:
		return "missed_required"
	if bn_missing:
		return "missed_big_number" if bn_sealed else "big_number_open"
	if opt_missed:
		return "missed_optional"
	var applause := int(r.get("applause", 0))
	if applause < STAR3:
		var can: Dictionary = r.get("can", {})
		var maxed: Dictionary = r.get("maxed", {})
		for k in SHORT_ORDER:
			if bool(can.get(k, false)) and not bool(maxed.get(k, false)):
				return k
	if int(r.get("catches", 0)) > 0:
		return "catches"
	return "standing_ovation"


## The line for `key` with its placeholders filled.
static func fill(key: String, r: Dictionary, templates: Dictionary, missed: Dictionary) -> String:
	var tpl := String(templates.get(key, ""))
	if tpl == "":
		return ""
	var lines: Array = r.get("lines", [])
	var done := 0
	for l in lines:
		if bool((l as Dictionary).get("done", false)):
			done += 1
	var phrase := ""
	var want_req := key == "missed_required"
	var want_bn := key == "missed_big_number" or key == "big_number_open"
	var want_opt := key == "missed_optional"
	for l in lines:
		var d: Dictionary = l
		if bool(d.get("done", false)):
			continue
		var is_bn := bool(d.get("big_number", false))
		var is_req := bool(d.get("req", false)) and not is_bn
		if (want_req and is_req) or (want_bn and is_bn) or (want_opt and not is_req and not is_bn):
			phrase = missed_phrase(d, String(r.get("episode", "")), missed)
			break
	var c := int(r.get("catches", 0))
	return tpl.format({"n": int(r.get("applause", 0)), "done": done, "total": lines.size(), "missed": phrase,
		"c": c, "lost": c * CATCH_COST})


## "hasn't …" phrase of a line: `missed[prank]`, else `missed["<episode>:<line>"]`, else the line text.
static func missed_phrase(line: Dictionary, episode: String, missed: Dictionary) -> String:
	var prank := String(line.get("prank", ""))
	if prank != "" and missed.has(prank):
		return String(missed[prank])
	var k := "%s:%s" % [episode, String(line.get("id", ""))]
	if missed.has(k):
		return String(missed[k])
	return String(line.get("text", line.get("id", "")))


## What the Night can offer for the "short" lines (from the episode + content): link (always), meltdown
## (temper can reach 100: any Night with ≥ 2 pranks), near misses (senses on), bits (a squeak bit in the
## loop), combo (unless `rules.combos` is []), embarrassed (Delphine in the cast).
static func offers(episode_raw: Dictionary, n_pranks: int, has_bits: bool) -> Dictionary:
	var rules: Dictionary = episode_raw.get("rules", {}) if episode_raw.get("rules") is Dictionary else {}
	var combos: Variant = rules.get("combos", null)
	var cast: Dictionary = episode_raw.get("cast", {}) if episode_raw.get("cast") is Dictionary else {}
	return {"short_link": n_pranks >= 2, "short_meltdown": n_pranks >= 2, "short_near_misses": rules.get("senses", true) != false,
		"short_bits": has_bits, "short_combo": not (combos is Array and (combos as Array).is_empty()) and n_pranks >= 2,
		"short_embarrassed": cast.get("delphine") != null}
