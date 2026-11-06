class_name WaterView
extends Node2D
## Draws flooded columns with an animated shimmer on the surface.

var terrain: Terrain
var _columns: Array[Vector3] = []
var _time: float = 0.0
var _murky: bool = false


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain


func _ready() -> void:
	_murky = terrain.biome == HoleData.BIOME_SWAMP
	for x in terrain.length + 1:
		if terrain.is_wet(float(x)):
			_columns.append(Vector3(x, terrain.ground_y(float(x)), terrain.basin_y(float(x))))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for column in _columns:
		var x: float = column.x
		var level: float = column.y
		var bottom: float = column.z
		draw_rect(Rect2(x, level, 1, bottom - level + 1), Color(0.17, 0.25, 0.13, 0.95) if _murky else Color(0.16, 0.46, 0.72, 0.92))
		var band: float = minf(level + 6.0, bottom)
		draw_rect(Rect2(x, level, 1, band - level), Color(0.27, 0.36, 0.16, 0.97) if _murky else Color(0.28, 0.62, 0.86, 0.95))
		# Swamp water barely moves.
		var ripple: float = sin(x * 0.22 + _time * (0.7 if _murky else 2.2)) + sin(x * 0.07 - _time * (0.4 if _murky else 1.3))
		var crest: Color = Color("d8f4ff") if ripple > 0.9 else Color("7fc6ec")
		if _murky:
			crest = Color("a8b868") if ripple > 1.1 else Color("5f7236")
		draw_rect(Rect2(x, level, 1, 1), crest)
