class_name FlagView
extends Node2D
## The pin and its waving pennant.

const POLE_HEIGHT := Terrain.PIN_HEIGHT

var terrain: Terrain
var _time: float = 0.0


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain


func _ready() -> void:
	position = Vector2(terrain.cup_x, terrain.rim_y)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# The pole stands on the bottom of the cup.
	var pole: float = POLE_HEIGHT + terrain.cup_depth - 1.0
	draw_rect(Rect2(0, -POLE_HEIGHT, 1, pole), Color("f4f4ea"))
	draw_rect(Rect2(1, -POLE_HEIGHT, 1, pole), Color("a9a99c"))
	for col in 15:
		var wave: float = round(sin(float(col) * 0.7 - _time * 5.0) * float(col) / 7.0)
		var half: int = 5 - col / 3
		var top: float = -POLE_HEIGHT + 5.0 - float(half) + wave
		draw_rect(Rect2(2 + col, top, 1, half * 2 + 1), Color("e8483f"))
		draw_rect(Rect2(2 + col, top + float(half * 2), 1, 1), Color("a92b35"))
