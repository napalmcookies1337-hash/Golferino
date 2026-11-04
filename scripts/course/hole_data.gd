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
## Trees, by x position. Solid trunks under leaves that slow the ball.
@export var tree_xs: PackedFloat32Array = PackedFloat32Array()
## Each entry has a "kind" (cart, windmill, sprinkler, goose) plus that kind's settings.
@export var obstacles: Array = []
## Sideways push on the ball in the air. Positive blows toward the far end of the hole.
@export var wind: float = 0.0
## Shown when the hole starts.
@export var title: String = ""
