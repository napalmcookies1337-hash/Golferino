class_name PauseView
extends Node2D
## The pause menu during a run.

signal resumed
signal run_ended

enum Item { RESUME, END_RUN, MUSIC, SOUND }

const ITEMS := ["RESUME", "END THIS RUN", "MUSIC", "SOUND"]
const ITEM_TOP := 132.0
const ITEM_GAP := 24.0
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const CENTER_X := 320.0

var selected: int = 0
var _menu_input := MenuInput.new()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at(event.position)
		if hovered >= 0 and hovered != selected:
			selected = hovered
			Sound.sfx("menu_move")
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _item_at(event.position) >= 0:
			_click(_item_at(event.position), event.position.x)
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("quit", false):
		Sound.sfx("menu_back")
		resumed.emit()
	elif event.is_action_pressed("swing", false):
		_choose(selected)
	else:
		var step: Vector2i = _menu_input.step(event)
		if step.y != 0:
			selected = posmod(selected + step.y, ITEMS.size())
			Sound.sfx("menu_move")
		elif step.x != 0:
			_change_level(selected, step.x)


func _click(index: int, x: float) -> void:
	if index == Item.MUSIC or index == Item.SOUND:
		var level: int = VolumeRow.level_at(x, CENTER_X)
		if level >= 0:
			var now: int = Sound.music_level if index == Item.MUSIC else Sound.sfx_level
			_change_level(index, level - now)
	else:
		_choose(index)


func _change_level(index: int, direction: int) -> void:
	if index == Item.MUSIC:
		VolumeRow.change_music(direction)
	elif index == Item.SOUND:
		VolumeRow.change_sfx(direction)


func _choose(index: int) -> void:
	match index:
		Item.RESUME:
			Sound.sfx("menu_ok")
			resumed.emit()
		Item.END_RUN:
			Sound.sfx("menu_ok")
			run_ended.emit()
		_:
			var level: int = Sound.music_level if index == Item.MUSIC else Sound.sfx_level
			_change_level(index, 1 if level < Sound.LEVELS else -level)


func _item_at(at: Vector2) -> int:
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if absf(at.x - CENTER_X) < 110.0 and at.y >= y - 4.0 and at.y < y + 18.0:
			return i
	return -1


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.05, 0.1, 0.72))
	PixelFont.draw_centered(self, "PAUSED", CENTER_X, 92.0, ACCENT, 3)
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if i == Item.MUSIC:
			VolumeRow.draw(self, str(ITEMS[i]), Sound.music_level, CENTER_X, y, i == selected)
		elif i == Item.SOUND:
			VolumeRow.draw(self, str(ITEMS[i]), Sound.sfx_level, CENTER_X, y, i == selected)
		else:
			PixelFont.draw_centered(self, str(ITEMS[i]), CENTER_X, y, ACCENT if i == selected else TEXT, 2)
	PixelFont.draw_centered(self, "ENDING A RUN STILL SAVES ITS SCORE", CENTER_X, 236.0, DIM)
