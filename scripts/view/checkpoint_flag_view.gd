class_name CheckpointFlagView
extends Node2D
## A checkered flag on a pole, marking a checkpoint. It's only scenery: there's no hole, and the
## ball passes it by.

const POLE_HEIGHT := 40.0
const FLAG_COLUMNS := 16
const FLAG_ROWS := 11
const CHECK_SIZE := 3
const WAVE_SPEED := 5.0
const WAVE_SIZE := 2.0
const POLE_LIGHT := Color("f4f4ea")
const POLE_DARK := Color("a9a99c")
const CHECK_LIGHT := Color("f7f7f2")
const CHECK_DARK := Color("20202e")

var terrain: Terrain
var flag_x: float = 0.0
var _time: float = 0.0


func setup(p_terrain: Terrain, p_flag_x: float) -> void:
	terrain = p_terrain
	flag_x = p_flag_x


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var ground: float = round(terrain.ground_y(flag_x))
	var top: float = ground - POLE_HEIGHT
	draw_rect(Rect2(flag_x, top, 1, POLE_HEIGHT + 1.0), POLE_LIGHT)
	draw_rect(Rect2(flag_x + 1.0, top, 1, POLE_HEIGHT + 1.0), POLE_DARK)
	draw_rect(Rect2(flag_x - 1.0, ground, 4, 1), POLE_DARK)
	for col in FLAG_COLUMNS:
		# Waves more toward the loose end, and stays fixed against the pole.
		var wave: float = round(sin(float(col) * 0.7 - _time * WAVE_SPEED) * WAVE_SIZE * float(col) / float(FLAG_COLUMNS))
		for row in FLAG_ROWS:
			var dark: bool = (col / CHECK_SIZE + row / CHECK_SIZE) % 2 == 0
			draw_rect(Rect2(flag_x + 2.0 + float(col), top + float(row) + wave, 1, 1), CHECK_DARK if dark else CHECK_LIGHT)
