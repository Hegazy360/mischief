## ResidueDef — a residue kind and its fix-up station kind (TECH §4.6, GDD §5.4).
class_name ResidueDef
extends RefCounted

var id: String = ""
var idx: int = -1
## DRY | SINK | HONEY | MIRROR
var fixup: String = ""
var overlay: String = ""


## Parse a residues.json residues entry.
static func from_dict(kind: String, d: Dictionary) -> ResidueDef:
	var r := ResidueDef.new()
	r.id = kind
	r.fixup = ContentUtil.s(d, "fixup")
	r.overlay = ContentUtil.s(d, "overlay")
	return r


## Detour activity id of this residue's fix-up ("fixup_dry" …).
func detour_id() -> String:
	return "fixup_" + fixup.to_lower()
