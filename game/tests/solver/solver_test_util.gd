## Shared helpers for the solver tests (not a test file: no `test_` prefix).
extends RefCounted

const MOCK_DATA := "res://tests/solver/fixtures/mock_data"
const MOCK_WORLD := "res://tests/solver/fixtures/mock_world.gd"

static var _data: SolverData = null


## The mock content set (cached).
static func data() -> SolverData:
	if _data == null:
		_data = SolverData.load_dir(MOCK_DATA)
	return _data


## A fresh MockWorld for the mock episode.
static func world(ep: String = "mock_ep") -> Object:
	return load(MOCK_WORLD).create(data(), ep)


## A fallback-conditions Callable for `ex` (bound after construction).
static func executor(w: Object, steps: Variant, persona: Variant = "ideal", opts: Dictionary = {}) -> Executor:
	var o := {"episode": "mock_ep"}
	o.merge(opts, true)
	return Executor.new(w, steps, persona, Callable(), data(), o)


## The mock solution file.
static func solution() -> SolutionDef:
	return SolutionDef.load_file(MOCK_DATA + "/solutions/mock_ep.json")
