## GestureConfig — every world-gesture threshold (GDD §3.1, TECH §6.1, touchux §3.1), in logical
## px at the 1080-high base and milliseconds of real time.
class_name GestureConfig
extends RefCounted

## Travel above which a touch is a drag, not a tap / long-press.
const SLOP_PX := 24.0
## A tap's touch-up must come within this long of its touch-down.
const TAP_MS := 300
## A second tap within this long (after the first tap's touch-up) and distance is a double tap.
## The first tap is emitted immediately; the second is flagged `is_double`.
const DOUBLE_MS := 280
const DOUBLE_PX := 64.0
## Hold still this long for a long-press (Reveal).
const LONG_MS := 450
## Two-finger distance change before a pinch starts.
const PINCH_PX := 32.0
## Drags starting within this many px of the left / right screen edge are ignored
## (the Android back gesture lives there).
const EDGE_EXCLUSION_PX := 48.0
## Tap assist: snap a miss to the nearest hotspot within this many SCREEN px (TapAssist).
const ASSIST_PX := 90.0
