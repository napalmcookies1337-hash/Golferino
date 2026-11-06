class_name LilyObstacle
extends Obstacle
## A lily pad floating on the water. A ball can land on it and be played from it. All of that is
## Terrain's doing, which treats the water under a pad as ground, so this only marks where it is.

const DEFAULT_WIDTH := 52.0

var x: float
var y: float
var width: float
## Some pads have a flower on them, depending on where they are.
var has_flower: bool


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "lily"
	x = float(entry["x"])
	y = terrain.ground_y(x)
	width = float(entry.get("width", DEFAULT_WIDTH))
	has_flower = int(x) % 3 == 0
