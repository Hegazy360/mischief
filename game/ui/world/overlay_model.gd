## OverlayModel — everything the world overlays show this frame (r3d-index §7.8, REDESIGN_3D §4.1).
##
## Plain data, refilled every frame by `OverlayRules.fill(model, snap, ctx)` and shown by
## `WorldOverlays.apply(model)`. **Pooled and allocation-free:** the entry arrays are pre-sized to
## their caps once; a frame writes `*_count` entries and leaves the rest untouched. Iterate with
## `for i in model.preview_count: var p := model.previews[i]`.
##
##   previews[]      {hotspot, prank, pictogram, strength (0.3 | 0.8 | 1.0), needs_item,
##                    combines_badge, his_ring_ticks, his_ring_frac, loud}
##   thought         {hotspot, prank, pictogram, side (−1 left of her head | +1 right)} — shown
##                    when `thought.hotspot != ""`
##   item_bubbles[]  {hotspot, item}
##   rig_ring        {hotspot, frac} — shown when `rig_ring.hotspot != ""`
##   safety_marker   {hotspot} — shown when `safety_marker.hotspot != ""`
##   tag_flights[]   {hotspot, line_index} — consumed once by WorldOverlays (the flight starts)
##   hidden          everything hides (danger with no safe spot, a cut-scene, paused)
class_name OverlayModel
extends RefCounted

## V6: at most this many world overlays on screen (≤ 2 loud).
const MAX_ON_SCREEN := 6
const MAX_LOUD := 2
## Pool caps (the rules never fill more).
const MAX_PREVIEWS := 8
const MAX_ITEMS := 4
const MAX_FLIGHTS := 4
## Preview strengths (REDESIGN §4.1 / §4.5).
const STRENGTH_FADED := 0.3
const STRENGTH_PASSIVE := 0.8
const STRENGTH_FULL := 1.0


## A passive preview (or a needs cloud) above one available rig point.
class Preview:
	extends RefCounted
	var hotspot: String = ""
	var prank: String = ""
	## previews.json pictogram ids (the joke), e.g. ["nose", "star_burst"].
	var pictogram: PackedStringArray = PackedStringArray()
	## 0.3 (faded: V1 others), 0.8 (passive), 1.0 (N4 "next useful" at full size).
	var strength: float = OverlayModel.STRENGTH_PASSIVE
	## Needs cloud: the missing item's id ("" = a normal preview).
	var needs_item: String = ""
	## HOT & COLD: a small badge id ("to_sink") when both halves of a combine are armed ("" = none).
	var combines_badge: String = ""
	## "He's coming for this next": his bubble's countdown ticks (−1 = no ring) and its fraction
	## 0..1 of the ring (< 0 = none).
	var his_ring_ticks: int = -1
	var his_ring_frac: float = -1.0
	## Full strength and ≥ 150 px (N4 spotlight): counts toward the V6 loud cap.
	var loud: bool = false

	func clear() -> void:
		hotspot = ""
		prank = ""
		pictogram = PackedStringArray()
		strength = OverlayModel.STRENGTH_PASSIVE
		needs_item = ""
		combines_badge = ""
		his_ring_ticks = -1
		his_ring_frac = -1.0
		loud = false


## Hush's thought: the joke she imagines at the rig point she stands at.
class Thought:
	extends RefCounted
	var hotspot: String = ""
	var prank: String = ""
	var pictogram: PackedStringArray = PackedStringArray()
	## −1 = the cloud sits left of her head, +1 = right (the side away from the prop).
	var side: int = 1

	func clear() -> void:
		hotspot = ""
		prank = ""
		pictogram = PackedStringArray()
		side = 1


## A cream disc with tonight's item icon above the container that holds it.
class ItemBubble:
	extends RefCounted
	var hotspot: String = ""
	var item: String = ""


## The rig ring at the prop (held, or partial after a release).
class RingEntry:
	extends RefCounted
	var hotspot: String = ""
	var frac: float = 0.0
	## true while she is rigging right now (the ring pulses over its last 20 %).
	var active: bool = false


## The safety-net marker: a white disc with a blue closed eye on the nearest free hiding spot.
class MarkerEntry:
	extends RefCounted
	var hotspot: String = ""


## A red beret tag flying from the prop to its Script pip.
class FlightEntry:
	extends RefCounted
	var hotspot: String = ""
	var line_index: int = -1


var previews: Array[Preview] = []
var preview_count: int = 0
var thought: Thought = Thought.new()
var item_bubbles: Array[ItemBubble] = []
var item_count: int = 0
var rig_ring: RingEntry = RingEntry.new()
var safety_marker: MarkerEntry = MarkerEntry.new()
var tag_flights: Array[FlightEntry] = []
var flight_count: int = 0
## Everything hides (WorldOverlays fades the lot out).
var hidden: bool = false


func _init() -> void:
	previews.resize(MAX_PREVIEWS)
	for i in MAX_PREVIEWS:
		previews[i] = Preview.new()
	item_bubbles.resize(MAX_ITEMS)
	for i in MAX_ITEMS:
		item_bubbles[i] = ItemBubble.new()
	tag_flights.resize(MAX_FLIGHTS)
	for i in MAX_FLIGHTS:
		tag_flights[i] = FlightEntry.new()


## Empty every slot (no allocation: the pools stay).
func clear() -> void:
	preview_count = 0
	item_count = 0
	thought.hotspot = ""
	rig_ring.hotspot = ""
	rig_ring.frac = 0.0
	rig_ring.active = false
	safety_marker.hotspot = ""
	hidden = false


## Next free preview slot (null when the pool is full). The caller fills every field it needs.
func add_preview() -> Preview:
	if preview_count >= MAX_PREVIEWS:
		return null
	var p := previews[preview_count]
	preview_count += 1
	p.strength = STRENGTH_PASSIVE
	p.needs_item = ""
	p.combines_badge = ""
	p.his_ring_ticks = -1
	p.his_ring_frac = -1.0
	p.loud = false
	return p


## Next free item-bubble slot (null when full).
func add_item_bubble(hotspot: String, item: String) -> ItemBubble:
	if item_count >= MAX_ITEMS:
		return null
	var b := item_bubbles[item_count]
	item_count += 1
	b.hotspot = hotspot
	b.item = item
	return b


## Queue a tag flight (consumed by WorldOverlays on the next apply). False when the queue is full.
func add_tag_flight(hotspot: String, line_index: int) -> bool:
	if flight_count >= MAX_FLIGHTS:
		return false
	var f := tag_flights[flight_count]
	flight_count += 1
	f.hotspot = hotspot
	f.line_index = line_index
	return true


## The preview of `hotspot` this frame (null = none).
func preview_of(hotspot: String) -> Preview:
	for i in preview_count:
		if previews[i].hotspot == hotspot:
			return previews[i]
	return null


## World overlays that would be on screen (previews + thought + item bubbles + ring + marker).
func overlay_count() -> int:
	if hidden:
		return 0
	var n := preview_count + item_count
	if thought.hotspot != "":
		n += 1
	if rig_ring.hotspot != "":
		n += 1
	if safety_marker.hotspot != "":
		n += 1
	return n


## Loud overlays (V6: full strength, ≥ 150 px — the thought, the rig ring, the N4 preview) plus
## the safety-net marker (V2's one call to action; counted loud although it is 88 px).
func loud_count() -> int:
	if hidden:
		return 0
	var n := 0
	for i in preview_count:
		if previews[i].loud:
			n += 1
	if thought.hotspot != "":
		n += 1
	if rig_ring.hotspot != "":
		n += 1
	if safety_marker.hotspot != "":
		n += 1
	return n
