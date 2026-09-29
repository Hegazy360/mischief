## CmdReplay — feeds a logged command list ([[tick, cmd], …], `sim_run.gd --cmds` format) into a
## SimDriver so each command is applied on exactly its logged tick, however many ticks the driver
## runs in one frame (⏩, hit-stop catch-up, a seek).
##
## A command logged at tick t is applied by the step that makes `world.tick == t`. The replayer
## pushes the commands of tick `world.tick + 1` right after every tick (the driver's `ticked` signal
## fires synchronously inside its tick loop, before the next step consumes `push_cmd`), and the
## commands of the first tick when it starts. Allocation-free per tick (an index walk).
class_name CmdReplay
extends RefCounted

var cmds: Array = []
var driver: Node = null
## Commands pushed so far.
var pushed: int = 0
var _i: int = 0
var _active: bool = false


## Attach to `p_driver` (a SimDriver) and replay `p_cmds` from the driver's current tick.
func start(p_driver: Node, p_cmds: Array) -> void:
	stop()
	driver = p_driver
	cmds = p_cmds
	_i = 0
	pushed = 0
	_active = driver != null
	if not _active:
		return
	if not driver.is_connected("ticked", _on_ticked):
		driver.connect("ticked", _on_ticked)
	_skip_past(_tick())
	_push_due(_tick() + 1)


## Detach (the remaining commands are dropped).
func stop() -> void:
	_active = false
	if driver != null and is_instance_valid(driver) and driver.is_connected("ticked", _on_ticked):
		driver.disconnect("ticked", _on_ticked)


## Rewind to the start of the log (retry in place: the driver was reset to tick 0).
func rewind() -> void:
	if driver == null:
		return
	_i = 0
	pushed = 0
	_active = true
	if not driver.is_connected("ticked", _on_ticked):
		driver.connect("ticked", _on_ticked)
	_push_due(_tick() + 1)


func is_active() -> bool:
	return _active


## True when every command has been pushed.
func is_done() -> bool:
	return _i >= cmds.size()


## Tick of the last logged command (0 when empty).
func last_tick() -> int:
	return int(cmds[cmds.size() - 1][0]) if not cmds.is_empty() else 0


func _tick() -> int:
	var w: Variant = driver.get("world")
	return int((w as Object).get("tick")) if w is Object else 0


func _skip_past(t: int) -> void:
	while _i < cmds.size() and int(cmds[_i][0]) <= t:
		_i += 1


func _push_due(t: int) -> void:
	while _i < cmds.size() and int(cmds[_i][0]) <= t:
		driver.call("push_cmd", (cmds[_i][1] as Dictionary).duplicate())
		pushed += 1
		_i += 1


func _on_ticked(_events: Array) -> void:
	if _active:
		_push_due(_tick() + 1)
