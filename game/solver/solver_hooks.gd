## SolverHooks — soft hooks into the sim (TECH §13.2). The solver never names `SimWorld`,
## `ContentDB`, `Conditions` or `SimEvents` as types: they are built in parallel, so every use
## goes through `load()` behind `ResourceLoader.exists`, and callers fall back (or skip) when a
## module is absent. Stage 2 may convert these to typed calls.
class_name SolverHooks
extends RefCounted

const SIM_WORLD := "res://sim/world/sim_world.gd"
const CONTENT_DB := "res://sim/content/content_db.gd"
const CONDITIONS := "res://sim/systems/conditions.gd"
const SIM_EVENTS := "res://sim/world/sim_events.gd"
const SIM_CONST := "res://sim/core/sim_const.gd"
const SIM_FF := "res://sim/world/sim_ff.gd"

static var _cache: Dictionary = {}


## The script at `path`, or null when it does not exist (cached).
static func soft_script(path: String) -> Script:
	if _cache.has(path):
		return _cache[path]
	var s: Script = null
	if ResourceLoader.exists(path):
		s = load(path) as Script
		# A module that exists but doesn't compile yet counts as absent.
		if s != null and not s.can_instantiate():
			s = null
	_cache[path] = s
	return s


## Forget cached lookups (tests that create modules on the fly).
static func clear_cache() -> void:
	_cache.clear()


## True when a script defines a (static or instance) method called `name`.
static func script_has(s: Script, name: String) -> bool:
	if s == null:
		return false
	for m in s.get_script_method_list():
		if SolverData.sv(m.get("name", "")) == name:
			return true
	return false


## True when both SimWorld and ContentDB exist.
static func sim_available() -> bool:
	return soft_script(SIM_WORLD) != null and soft_script(CONTENT_DB) != null


## Why the sim can't be used ("" when it can).
static func sim_missing_reason() -> String:
	if soft_script(SIM_WORLD) == null:
		return "sim not built yet (%s missing)" % SIM_WORLD
	if soft_script(CONTENT_DB) == null:
		return "sim not built yet (%s missing)" % CONTENT_DB
	return ""


## `ContentDB.load_dir(root)` or null.
static func load_db(root: String = "res://data") -> Object:
	var s := soft_script(CONTENT_DB)
	if s == null or not script_has(s, "load_dir"):
		return null
	return s.call("load_dir", root) as Object


## ContentDB validation errors (empty when it has no `validate`).
static func db_errors(db: Object) -> PackedStringArray:
	var out := PackedStringArray()
	if db == null:
		out.append("ContentDB failed to load")
		return out
	var errs: Variant = db.get("errors")
	if errs is PackedStringArray or errs is Array:
		for e in errs:
			out.append(String(e))
	if db.has_method("validate"):
		var v: Variant = db.call("validate")
		if v is PackedStringArray or v is Array:
			for e in v:
				if not out.has(String(e)):
					out.append(String(e))
	return out


## `SimWorld.create(db, episode_id, config)` or null.
static func make_world(db: Object, episode_id: String, config: Dictionary = {}) -> Object:
	var s := soft_script(SIM_WORLD)
	if s == null or db == null:
		return null
	return s.call("create", db, episode_id, config) as Object


## A zero-arg Callable that builds a fresh world for (db, episode, config) — used for
## determinism replays and fuzz runs.
static func world_factory(db: Object, episode_id: String, config: Dictionary = {}) -> Callable:
	return func() -> Object: return SolverHooks.make_world(db, episode_id, config)


## A world factory by kind: "sim" (SimWorld over `db`) or "mock" (the tests' MockWorld over `data`,
## for exercising the CLIs without the sim).
static func factory_for(kind: String, db: Object, data: SolverData, episode_id: String, config: Dictionary = {}) -> Callable:
	if kind == "mock":
		var mock: Script = load("res://tests/solver/fixtures/mock_world.gd")
		return func() -> Object: return mock.call("create", data, episode_id, config)
	return world_factory(db, episode_id, config)


## The sim's condition evaluator as a Callable(world, cond) -> bool, or an empty Callable.
static func sim_conditions() -> Callable:
	var s := soft_script(CONDITIONS)
	if s == null:
		return Callable()
	for name in ["eval", "evaluate", "check"]:
		if script_has(s, name):
			var n: String = name
			return func(world: Object, cond: Variant) -> bool: return bool(s.call(n, world, cond))
	return Callable()


## `SimEvents.is_laugh(ev)` when the sim exposes it, else the solver's fallback list
## (TECH §3.8): reaction accents, squeak bits, panto rounds, near misses, combos, Meltdown,
## the first bump, door slams and `director_cue` ids starting with `laugh_`.
static func is_laugh(ev: Dictionary) -> bool:
	var s := soft_script(SIM_EVENTS)
	if s != null and script_has(s, "is_laugh"):
		return bool(s.call("is_laugh", ev))
	return fallback_is_laugh(ev)


## The fallback laugh classifier (mirrors TECH §3.8).
static func fallback_is_laugh(ev: Dictionary) -> bool:
	match SolverData.sv(ev.get("e", "")):
		"reaction_accent", "squeak_bit", "panto_round", "near_miss", "combo", "meltdown_start", \
				"door_slam":
			return true
		"bump":
			return bool(ev.get("first", false))
		"director_cue":
			return SolverData.sv(ev.get("id", "")).begins_with("laugh_")
	return false


## A SimConst integer constant (e.g. "B_WALK") or `fallback`.
static func sim_const(name: String, fallback: int) -> int:
	var s := soft_script(SIM_CONST)
	if s == null:
		return fallback
	var m := s.get_script_constant_map()
	return int(m.get(name, fallback))
