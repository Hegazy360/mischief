## OverlayCtx — what `OverlayRules.fill` needs besides the snapshot (r3d-index §7.8): the Night's
## tables (built once by `prepare`), the per-frame facts the presenter sets (idle time, danger flags,
## the hint ladder's "next useful" spot, where Hush stands, the Settings mode) and the small memory
## the rules keep between frames (containers she has seen, partial rig rings, the V5 quiet window).
##
##   ctx.prepare(db, episode, set_list, previews)       # once per Night (and on retry: reset())
##   ctx.now_s = …; ctx.idle_s = …; ctx.entry_warning = …   # every frame, then
##   OverlayRules.fill(model, snap, ctx)
##
## `previews` is previews.json's `pranks` map ({prank: {pictogram: [ids], needs, combines: [{with,
## badge}]}}) or the whole file; {} (content not landed yet) = every prank's pictogram is [prank id]
## (the art is looked up by prank id, so the clouds still draw).
class_name OverlayCtx
extends RefCounted

const PREVIEWS_PATH := "res://data/view/previews.json"
## Settings `previews` values.
const MODE_ALWAYS := &"always"
const MODE_IDLE := &"idle_6s"
const MODE_OFF := &"off"

# --- the Night (prepare) ----------------------------------------------------------------------
var db: ContentDB = null
var episode: EpisodeDef = null
## SetList.Result (r3d-sets) or null — not needed by the rules today (the sim's hotspot states and
## the live mask already say what is on stage); kept for the consumers of §7.8.
var set_list: Variant = null
## previews.json `pranks` map.
var previews: Dictionary = {}

# --- per frame (the presenter) ----------------------------------------------------------------
## Monotonic view seconds (UiKit.now_ms() / 1000 in the game; tests step it).
var now_s: float = 0.0
## Seconds since the last player input (N4 after 6 s; Settings `idle_6s`).
var idle_s: float = 0.0
## Settings `previews`: MODE_ALWAYS | MODE_IDLE | MODE_OFF.
var previews_mode: StringName = MODE_ALWAYS
## V2 danger flags: the room-entry warning for her room, a "?" filling on her, a chase. `reaction`
## = a prank payoff / reaction is on (the consequence gets the screen: previews hide, no marker).
## A flag the presenter leaves false is also derived from the snapshot where it can be (the spot
## meter, CHASE / REACTING states).
var entry_warning: bool = false
var spot_filling: bool = false
var chase: bool = false
var reaction: bool = false
## N4: the hint ladder's "next useful" hotspot ("" = none).
var next_useful: String = ""
## The rig point Hush stands at ("" = derive from `action`, else from the snapshot's rig prank).
var at_hotspot: String = ""
## `world.action_context()` ({} when unknown): verb, prank, ring_pm, item_needed, item_have.
var action: Dictionary = {}
## Everything hides this frame (a cut-scene, the Map, a panel).
var hide_all: bool = false

# --- tables (prepare) --------------------------------------------------------------------------
## hotspot → PackedStringArray of tonight's pranks rigged there (episode order).
var rig_pranks: Dictionary = {}
## room → PackedStringArray of tonight's rig points (house order).
var room_rigs: Dictionary = {}
## room → PackedStringArray of containers holding an item tonight needs.
var room_containers: Dictionary = {}
## room → PackedStringArray of live hiding spots.
var room_hides: Dictionary = {}
## hotspot → room, and hotspot → its use x / rect centre x (sim px).
var hotspot_room: Dictionary = {}
var hotspot_x: Dictionary = {}
var hotspot_cx: Dictionary = {}
## item → the container it comes from; the items tonight needs.
var item_source: Dictionary = {}
var tonight_items: Dictionary = {}
## prank → its rig point; prank → pictogram ids; prank → needed item ("" free).
var prank_hotspot: Dictionary = {}
var pictograms: Dictionary = {}
var prank_needs: Dictionary = {}
## prank → Array of {with, badge} (previews.json combines).
var combines: Dictionary = {}
## activity → PackedStringArray of rig points whose prank that activity triggers (his ring).
var trig_hotspots: Dictionary = {}

# --- memory (the rules) --------------------------------------------------------------------------
## Containers Hush has seen (she was in their room): the needs cloud appears after that.
var seen_containers: Dictionary = {}
## hotspot → the rig ‰ she reached before letting go (the ring stays partial at the prop).
var partial_pm: Dictionary = {}
## V5: nothing new is suggested until this time.
var quiet_until_s: float = -1.0
## V2: hints come back 1.0 s after the last danger frame.
var danger_until_s: float = -1.0
## His bubble ring's peak ticks (its fraction = ticks / peak).
var ring_peak: int = 1
var prev_armed: int = -1
var prev_carry: int = -1
var prev_hidden: bool = false
var prev_ring_next: String = ""

## The shared empty id list (lookups return it instead of allocating).
const _EMPTY: PackedStringArray = []


## Build the Night's tables. `p_previews`: previews.json (the file or its `pranks` map), or {} to
## load PREVIEWS_PATH when it exists.
func prepare(p_db: ContentDB, p_episode: EpisodeDef, p_set_list: Variant = null, p_previews: Dictionary = {}) -> void:
	db = p_db
	episode = p_episode
	set_list = p_set_list
	previews = _pranks_map(p_previews if not p_previews.is_empty() else load_previews())
	rig_pranks.clear()
	room_rigs.clear()
	room_containers.clear()
	room_hides.clear()
	hotspot_room.clear()
	hotspot_x.clear()
	hotspot_cx.clear()
	item_source.clear()
	tonight_items.clear()
	prank_hotspot.clear()
	pictograms.clear()
	prank_needs.clear()
	combines.clear()
	trig_hotspots.clear()
	reset()
	if db == null or db.house == null:
		return
	var live := {}
	var in_ep := PackedByteArray()
	if episode != null:
		var sc := SimCtx.build(db, episode, {})
		in_ep = sc.prank_in_ep
		for h in db.house.hotspots:
			if sc.is_live(h.idx):
				live[h.id] = true
	for h in db.house.hotspots:
		hotspot_room[h.id] = h.room
		hotspot_x[h.id] = float(h.use_sub) / 60.0
		var cx := float(h.use_sub) / 60.0
		if h.rect.size() >= 4:
			cx = float(h.rect[0]) + float(h.rect[2]) * 0.5
		hotspot_cx[h.id] = cx
	for p in db.prank_list:
		if episode != null and (p.idx >= in_ep.size() or in_ep[p.idx] == 0):
			continue
		var hs := p.rig_point
		if hs == "":
			continue
		prank_hotspot[p.id] = hs
		_append(rig_pranks, hs, p.id)
		var need := ""
		for st in p.steps:
			if st.needs != "":
				need = st.needs
				tonight_items[st.needs] = true
				if st.needs_src != "":
					item_source[st.needs] = st.needs_src
				break
		prank_needs[p.id] = need
		pictograms[p.id] = pictogram_of(p.id)
		var pv: Variant = previews.get(p.id, {})
		if pv is Dictionary and (pv as Dictionary).get("combines") is Array:
			combines[p.id] = (pv as Dictionary)["combines"]
		if p.trig_type == PrankDef.TRIG_USE and p.trig_activity != "":
			_append(trig_hotspots, p.trig_activity, hs)
	for h in db.house.hotspots:
		var is_live := live.is_empty() or live.has(h.id)
		match h.kind_name:
			"rig_point":
				if rig_pranks.has(h.id):
					_append(room_rigs, h.room, h.id)
			"container":
				if is_live and item_source.values().has(h.id):
					_append(room_containers, h.room, h.id)
			"hiding":
				if is_live:
					_append(room_hides, h.room, h.id)


## Forget the per-run memory (retry / seek).
func reset() -> void:
	seen_containers.clear()
	partial_pm.clear()
	quiet_until_s = -1.0
	danger_until_s = -1.0
	ring_peak = 1
	prev_armed = -1
	prev_carry = -1
	prev_hidden = false
	prev_ring_next = ""


## V5 from outside (the presenter saw an action complete): nothing new for 1.0 s.
func note_action_done() -> void:
	quiet_until_s = now_s + OverlayRules.QUIET_AFTER_S


## True when V2 danger holds this frame (flags only; the rules add the snapshot's own signs).
func danger_flag() -> bool:
	return entry_warning or spot_filling or chase or reaction


## Pictogram ids of `prank` (previews.json; [prank] when it has none).
func pictogram_of(prank: String) -> PackedStringArray:
	var pv: Variant = previews.get(prank, null)
	if pv is Dictionary and (pv as Dictionary).get("pictogram") is Array:
		return PackedStringArray((pv as Dictionary)["pictogram"])
	return PackedStringArray([prank])


## Tonight's rig points in `room` (empty when none).
func rigs_in(room: String) -> PackedStringArray:
	return room_rigs.get(room, _EMPTY)


## Tonight's useful containers in `room`.
func containers_in(room: String) -> PackedStringArray:
	return room_containers.get(room, _EMPTY)


## Live hiding spots in `room`.
func hides_in(room: String) -> PackedStringArray:
	return room_hides.get(room, _EMPTY)


## previews.json from disk ({} when absent or malformed).
static func load_previews(path: String = PREVIEWS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data


static func _pranks_map(d: Dictionary) -> Dictionary:
	if d.get("pranks") is Dictionary:
		return d["pranks"]
	return d


## Packed arrays are values: read, append, write back.
static func _append(map: Dictionary, key: String, id: String) -> void:
	var a: PackedStringArray = map.get(key, PackedStringArray())
	a.append(id)
	map[key] = a
