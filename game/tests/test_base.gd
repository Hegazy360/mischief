## TestBase — base class of every test script discovered by res://tests/run_tests.gd.
##
## Write a file res://tests/**/test_<name>.gd that `extends TestBase` and add methods named
## `test_*` (they may `await`). Optional hooks: `before_each()` / `after_each()`.
## GDScript has no exceptions, so assertions RECORD failures (with file:line) and return
## a bool; `return` early yourself if later code depends on the asserted condition.
## Script runtime errors raised while a test runs are also counted as failures.
## Engine/`push_error` errors fail the test too unless the test calls `allow_errors()`.
class_name TestBase
extends RefCounted


## The running SceneTree (set by the runner before each test), for tests that need nodes.
var tree: SceneTree = null

var _failures: Array[String] = []
var _skip_reason: String = ""
var _allow_errors: bool = false
var _assert_count: int = 0


## Called before every test method. Override in subclasses.
func before_each() -> void:
	pass


## Called after every test method. Override in subclasses.
func after_each() -> void:
	pass


# --- assertions -----------------------------------------------------------------------

## Passes when `cond` is true.
func assert_true(cond: bool, msg: String = "") -> bool:
	return _check(cond, "expected true", msg)


## Passes when `cond` is false.
func assert_false(cond: bool, msg: String = "") -> bool:
	return _check(not cond, "expected false", msg)


## Passes when `actual == expected` (deep compare for containers; int/float compare by value).
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	return _check(_equal(actual, expected), "expected %s, got %s" % [_fmt(expected), _fmt(actual)], msg)


## Passes when `actual != expected`.
func assert_ne(actual: Variant, not_expected: Variant, msg: String = "") -> bool:
	return _check(not _equal(actual, not_expected), "expected value != %s" % _fmt(not_expected), msg)


## Passes when `a > b`.
func assert_gt(a: Variant, b: Variant, msg: String = "") -> bool:
	return _check(a > b, "expected %s > %s" % [_fmt(a), _fmt(b)], msg)


## Passes when `a < b`.
func assert_lt(a: Variant, b: Variant, msg: String = "") -> bool:
	return _check(a < b, "expected %s < %s" % [_fmt(a), _fmt(b)], msg)


## Passes when `a >= b`.
func assert_ge(a: Variant, b: Variant, msg: String = "") -> bool:
	return _check(a >= b, "expected %s >= %s" % [_fmt(a), _fmt(b)], msg)


## Passes when `a <= b`.
func assert_le(a: Variant, b: Variant, msg: String = "") -> bool:
	return _check(a <= b, "expected %s <= %s" % [_fmt(a), _fmt(b)], msg)


## Passes when `lo <= v <= hi`.
func assert_between(v: Variant, lo: Variant, hi: Variant, msg: String = "") -> bool:
	return _check(v >= lo and v <= hi, "expected %s in [%s, %s]" % [_fmt(v), _fmt(lo), _fmt(hi)], msg)


## Passes when `container` (Dictionary key / Array / Packed*Array / String) contains `item`.
func assert_has(container: Variant, item: Variant, msg: String = "") -> bool:
	var ok := false
	match typeof(container):
		TYPE_DICTIONARY:
			ok = (container as Dictionary).has(item)
		TYPE_STRING, TYPE_STRING_NAME:
			ok = String(container).contains(String(item))
		TYPE_NIL:
			ok = false
		_:
			if container is Array or _is_packed(container):
				ok = item in container
	return _check(ok, "expected %s to contain %s" % [_fmt(container), _fmt(item)], msg)


## Passes when |a - b| <= eps.
func assert_almost_eq(a: float, b: float, eps: float = 0.0001, msg: String = "") -> bool:
	return _check(absf(a - b) <= eps, "expected %s ~= %s (eps %s)" % [a, b, eps], msg)


## Unconditional failure.
func fail(msg: String) -> void:
	_check(false, "fail", msg)


## Marks the current test as skipped (no failure). `return` right after calling it.
func skip(msg: String) -> void:
	_skip_reason = msg if msg != "" else "skipped"


## Lets engine / push_error messages happen in this test without failing it.
func allow_errors() -> void:
	_allow_errors = true


# --- helpers --------------------------------------------------------------------------

## Parse a JSON file. Returns null (and records a failure) if missing or invalid.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("TestBase.load_json: missing %s" % path)
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("TestBase.load_json: %s:%d %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


## Budget multiplier for wall-clock ceilings on a shared box (s2-fix G #6): the 1-minute load
## average (+ this test process) per core from /proc/loadavg and `nproc`, never below 1 (idle box
## or no procfs: 1.0). Timing tests take the fastest of several blocks AND scale their budget by this,
## so a CI runner or a box shared with other agents measures the code, not the scheduler.
static func cpu_load_scale() -> float:
	if OS.get_name() != "Linux":
		return 1.0
	var out: Array = []
	if OS.execute("cat", ["/proc/loadavg"], out) != 0 or out.is_empty():
		return 1.0
	var parts := str(out[0]).split(" ", false)
	if parts.is_empty() or not parts[0].is_valid_float():
		return 1.0
	var cores := 0
	var cpu: Array = []
	if OS.execute("nproc", [], cpu) == 0 and not cpu.is_empty():
		cores = int(str(cpu[0]).strip_edges())
	if cores <= 0:
		cores = OS.get_processor_count()
	return maxf(1.0, (parts[0].to_float() + 1.0) / maxf(1.0, float(cores)))


# --- runner interface (used by run_tests.gd) ------------------------------------------

## Reset per-test state. Called by the runner.
func _reset_test_state() -> void:
	_failures.clear()
	_skip_reason = ""
	_allow_errors = false


func _check(cond: bool, what: String, msg: String) -> bool:
	_assert_count += 1
	if cond:
		return true
	var line := "%s%s%s" % [what, " — " if msg != "" else "", msg]
	_failures.append("%s  (%s)" % [line, _caller_location()])
	return false


func _caller_location() -> String:
	if not Engine.has_method("capture_script_backtraces"):
		return "?"
	var bts: Array = Engine.capture_script_backtraces()
	for bt in bts:
		var sb: ScriptBacktrace = bt
		for i in sb.get_frame_count():
			var f := sb.get_frame_file(i)
			if f != "" and not f.ends_with("test_base.gd") and not f.ends_with("run_tests.gd"):
				return "%s:%d" % [f.get_file(), sb.get_frame_line(i)]
	return "?"


static func _is_packed(v: Variant) -> bool:
	var t := typeof(v)
	return t >= TYPE_PACKED_BYTE_ARRAY and t <= TYPE_PACKED_VECTOR4_ARRAY


static func _equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return a == b
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return String(a) == String(b)
	if ta != tb:
		# Array vs Packed*Array: compare element-wise.
		if (a is Array or _is_packed(a)) and (b is Array or _is_packed(b)):
			return _equal(Array(a), Array(b))
		return false
	if ta == TYPE_ARRAY:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not _equal(aa[i], ab[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da:
			if not db.has(k) or not _equal(da[k], db[k]):
				return false
		return true
	return a == b


static func _fmt(v: Variant) -> String:
	var s := var_to_str(v) if typeof(v) != TYPE_OBJECT else str(v)
	if s.length() > 160:
		s = s.substr(0, 157) + "..."
	return s
