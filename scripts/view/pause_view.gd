class_name PauseView
extends Node2D
## The pause menu during a run.

signal resumed
signal run_ended

const ITEMS := ["RESUME", "END THIS RUN"]
const ITEM_TOP := 160.0
const ITEM_GAP := 24.0
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")

var selected: int = 0
var _menu_input := MenuInput.new()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at(event.position)
		if hovered >= 0:
			selected = hovered
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _item_at(event.position) >= 0:
			_choose(_item_at(event.position))
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("quit", false):
		resumed.emit()
	elif event.is_action_pressed("swing", false):
		_choose(selected)
	else:
		var step: Vector2i = _menu_input.step(event)
		if step.y != 0:
			selected = posmod(selected + step.y, ITEMS.size())


func _choose(index: int) -> void:
	if index == 0:
		resumed.emit()
	else:
		run_ended.emit()


func _item_at(at: Vector2) -> int:
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if absf(at.x - 320.0) < 100.0 and at.y >= y - 4.0 and at.y < y + 18.0:
			return i
	return -1


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.05, 0.1, 0.72))
	PixelFont.draw_centered(self, "PAUSED", 320.0, 104.0, ACCENT, 3)
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		PixelFont.draw_centered(self, str(ITEMS[i]), 320.0, y, ACCENT if i == selected else TEXT, 2)
	PixelFont.draw_centered(self, "ENDING A RUN STILL SAVES ITS SCORE", 320.0, 226.0, DIM)
