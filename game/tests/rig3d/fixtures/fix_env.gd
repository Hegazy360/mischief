## Test helper: points the 3D rig / clip / reaction lookups at the fixture data (and back).
extends RefCounted

const ROOT := "res://tests/rig3d/fixtures/data"
const REACTIONS := "res://tests/rig3d/fixtures/data/reactions_fix.json"


## Adds the fixture roots (idempotent) and drops the caches.
static func push() -> void:
	if not RigDef3D.search_roots.has(ROOT):
		RigDef3D.search_roots.append(ROOT)
	if not ClipLib3D.search_roots.has(ROOT):
		ClipLib3D.search_roots.append(ROOT)
	if not PlayPlan3D.reaction_files.has(REACTIONS):
		PlayPlan3D.reaction_files.append(REACTIONS)
	RigDef3D.invalidate()
	ClipLib3D.invalidate()
	PlayPlan3D.invalidate()


## Removes the fixture roots and drops the caches.
static func pop() -> void:
	var i := RigDef3D.search_roots.find(ROOT)
	if i >= 0:
		RigDef3D.search_roots.remove_at(i)
	i = ClipLib3D.search_roots.find(ROOT)
	if i >= 0:
		ClipLib3D.search_roots.remove_at(i)
	i = PlayPlan3D.reaction_files.find(REACTIONS)
	if i >= 0:
		PlayPlan3D.reaction_files.remove_at(i)
	RigDef3D.invalidate()
	ClipLib3D.invalidate()
	PlayPlan3D.invalidate()


## The fixture descriptor as a Dictionary (a fresh copy to break in tests).
static func rig_dict() -> Dictionary:
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(ROOT + "/rigs3d/fix/rig3d.json"))
	return (j.data as Dictionary).duplicate(true)


## A RigPlayer3D on the fixture rig, in the tree, manual clock.
static func player(tree: SceneTree) -> RigPlayer3D:
	var p := RigPlayer3D.new()
	p.name = "FixPlayer"
	p.auto_advance = false
	tree.root.add_child(p)
	p.setup("fix")
	return p
