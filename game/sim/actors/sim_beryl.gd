## SimBeryl — Stage-3 seam (the goat, GDD §4.8). `SimWorld.beryl` stays null until `s3-sim-cast`
## implements her; the sim calls `update()` null-safely at step 4 of the tick.
class_name SimBeryl
extends RefCounted

var room: int = -1
var x_sub: int = 0
var facing: int = 1
var mood: String = "dozing"


## Step 4 of the tick (Stage 3).
func update(_w: SimWorld) -> void:
	pass
