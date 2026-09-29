## A stub FTUE director with the s2-ftue hook contract (s2-night §4.4): records every call.
extends Node

signal pause_request(on: bool)

var ctx: Dictionary = {}
var ticked: int = 0
var intents: Array = []
var advanced: float = 0.0
var resets: int = 0
var pulse: bool = true


func setup(p_ctx: Dictionary) -> void:
	ctx = p_ctx


func on_ticked(events: Array) -> void:
	ticked += events.size() + 1


func on_intent(intent: StringName, _args: Array) -> bool:
	intents.append(intent)
	return intent == &"figgis_tap"


func advance(real_dt: float) -> void:
	advanced += real_dt


func figgis_pulse() -> bool:
	return pulse


func reset() -> void:
	resets += 1


func loading_vignette(_episode_id: String) -> Texture2D:
	return null
