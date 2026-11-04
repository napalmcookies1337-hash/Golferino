class_name WaterView
extends Node2D
## Draws flooded columns with an animated shimmer on the surface.

var terrain: Terrain
var _columns: Array[Vector3] = []
var _time: float = 0.0


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain


func _ready() -> void:
	for x in terrain.length + 1:
		if terrain.surface_at(float(x)) == Surface.Type.WATER:
			_columns.append(Vector3(x, terrain.ground_y(float(x)), terrain.basin_y(float(x))))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for column in _columns:
		var x: float = column.x
		var level: float = column.y
		var bottom: float = column.z
		draw_rect(Rect2(x, level, 1, bottom - level + 1), Color(0.16, 0.46, 0.72, 0.92))
		var band: float = minf(level + 6.0, bottom)
		draw_rect(Rect2(x, level, 1, band - level), Color(0.28, 0.62, 0.86, 0.95))
		var ripple: float = sin(x * 0.22 + _time * 2.2) + sin(x * 0.07 - _time * 1.3)
		var crest: Color = Color("d8f4ff") if ripple > 0.9 else Color("7fc6ec")
		draw_rect(Rect2(x, level, 1, 1), crest)
