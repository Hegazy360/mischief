## ItemDef — a carryable item (TECH §4.2).
class_name ItemDef
extends RefCounted

var id: String = ""
var idx: int = -1
var name: String = ""
var icon: String = ""
## Source container hotspot id.
var source: String = ""
var source_idx: int = -1
var pranks: PackedStringArray = PackedStringArray()
## Uses per pick (coins: 3).
var count: int = 1


## Parse an items.json entry.
static func from_dict(item_id: String, d: Dictionary) -> ItemDef:
	var it := ItemDef.new()
	it.id = item_id
	it.name = ContentUtil.s(d, "name", item_id)
	it.icon = ContentUtil.s(d, "icon")
	it.source = ContentUtil.s(d, "source")
	it.pranks = ContentUtil.strs(d, "pranks")
	it.count = maxi(1, ContentUtil.i(d, "count", 1))
	return it
