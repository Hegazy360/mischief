## ComboDef — two residues at once (TECH §4.6, GDD §5.4).
class_name ComboDef
extends RefCounted

var id: String = ""
var idx: int = -1
var of: PackedStringArray = PackedStringArray()
var caption: String = ""
var clip: String = ""


## Parse a residues.json combos entry.
static func from_dict(combo_id: String, d: Dictionary) -> ComboDef:
	var c := ComboDef.new()
	c.id = combo_id
	c.of = ContentUtil.strs(d, "of")
	c.caption = ContentUtil.s(d, "caption", combo_id)
	c.clip = ContentUtil.s(d, "clip")
	return c
