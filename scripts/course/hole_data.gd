class_name HoleData
extends Resource
## One hole, described entirely as data. New holes need no new code.

@export var display_name: String = "HOLE"
@export var par: int = 4
@export var tee_x: float = 90.0
@export var cup_x: float = 1000.0
## Terrain outline, sorted by x. y points down.
@export var points: PackedVector2Array = PackedVector2Array()
## Each entry: { "from": x, "to": x, "type": Surface.Type }. Unlisted ground is rough.
@export var surface_spans: Array = []
## Each entry: { "from": x, "to": x, "level": y }. Ground below level in range floods.
@export var water_spans: Array = []
## Decorative trees, by x position. They don't affect the ball.
@export var tree_xs: PackedFloat32Array = PackedFloat32Array()
