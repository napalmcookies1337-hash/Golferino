class_name FlagView
extends Node2D
## The pin and its waving pennant.

const POLE_HEIGHT := Terrain.PIN_HEIGHT
const WOBBLE_TIME := 0.7
const WOBBLE_RATE := 34.0
const WOBBLE_SIZE := 2.0

var terrain: Terrain
var _time: float = 0.0
var _wobble: float = 0.0


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain


func _ready() -> void:
	position = Vector2(terrain.cup_x, terrain.rim_y)


## Sets the pin quivering, as when a ball hits it.
func wobble() -> void:
	_wobble = WOBBLE_TIME


func _process(delta: float) -> void:
	_time += delta
	_wobble = maxf(_wobble - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# The pole stands on the bottom of the cup, and the top of it does the quivering.
	var pole: float = POLE_HEIGHT + terrain.cup_depth - 1.0
	var sway: float = round(sin(_time * WOBBLE_RATE) * WOBBLE_SIZE * _wobble / WOBBLE_TIME)
	var bottom_half: float = pole * 0.5
	draw_rect(Rect2(0, -POLE_HEIGHT + bottom_half, 1, pole - bottom_half), Color("f4f4ea"))
	draw_rect(Rect2(1, -POLE_HEIGHT + bottom_half, 1, pole - bottom_half), Color("a9a99c"))
	draw_rect(Rect2(sway, -POLE_HEIGHT, 1, bottom_half), Color("f4f4ea"))
	draw_rect(Rect2(sway + 1.0, -POLE_HEIGHT, 1, bottom_half), Color("a9a99c"))
	for col in 15:
		var wave: float = round(sin(float(col) * 0.7 - _time * 5.0) * float(col) / 7.0)
		var half: int = 5 - col / 3
		var top: float = -POLE_HEIGHT + 5.0 - float(half) + wave
		draw_rect(Rect2(sway + 2.0 + float(col), top, 1, half * 2 + 1), Color("e8483f"))
		draw_rect(Rect2(sway + 2.0 + float(col), top + float(half * 2), 1, 1), Color("a92b35"))
