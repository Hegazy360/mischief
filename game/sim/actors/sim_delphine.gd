## SimDelphine — Stage-3 seam (Dame Delphine, GDD §4.9). `SimWorld.delphine` stays null until
## `s3-sim-cast` implements her; the sim calls `update()` null-safely at step 4 of the tick.
class_name SimDelphine
extends RefCounted

var room: int = -1
var x_sub: int = 0
var facing: int = 1
var glasses_up: bool = false


## Step 4 of the tick (Stage 3).
func update(_w: SimWorld) -> void:
	pass
