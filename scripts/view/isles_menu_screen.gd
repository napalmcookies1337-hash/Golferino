class_name IslesMenuScreen
extends Node2D
## Chooses how long a Floating Isles course to play, with the best score for each.

signal course_chosen(yards: int)
signal back_chosen

const ITEM_TOP := 134.0
const ITEM_GAP := 34.0
const CENTER_X := 320.0
const ROW_HALF_WIDTH := 150.0
const PANEL_RECT := Rect2(150, 120, 340, 152)
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const OUTLINE := Color("20202e")

var profile: Profile
var selected: int = 0
var _menu_input := MenuInput.new()
var _menu: Node2D


func setup(p_profile: Profile) -> void:
	profile = p_profile


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	var background := BackgroundView.new()
	background.setup(camera, BackgroundView.Mood.MIDDAY)
	background.above_the_clouds = true
	add_child(background)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_menu = Node2D.new()
	_menu.draw.connect(_draw_menu)
	layer.add_child(_menu)
	ScreenWipe.open(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at(event.position)
		if hovered >= 0 and hovered != selected:
			selected = hovered
			Sound.sfx("menu_move")
			_menu.queue_redraw()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _item_at(event.position) >= 0:
			_choose(_item_at(event.position))
		return
	if event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		back_chosen.emit()
	elif event.is_action_pressed("swing", false):
		get_viewport().set_input_as_handled()
		_choose(selected)
	else:
		var step: Vector2i = _menu_input.step(event)
		if step.y != 0:
			selected = posmod(selected + step.y, _item_count())
			Sound.sfx("menu_move")
			_menu.queue_redraw()


func _item_count() -> int:
	return IslesGenerator.COURSE_YARDS.size() + 1


# The courses, then the way back.
func _choose(index: int) -> void:
	if index < IslesGenerator.COURSE_YARDS.size():
		Sound.sfx("menu_ok")
		course_chosen.emit(IslesGenerator.COURSE_YARDS[index])
	else:
		back_chosen.emit()


func _item_at(at: Vector2) -> int:
	for i in _item_count():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if absf(at.x - CENTER_X) < ROW_HALF_WIDTH and at.y >= y - 6.0 and at.y < y + 22.0:
			return i
	return -1


func _draw_menu() -> void:
	var heading := "FLOATING ISLES"
	PixelFont.draw_centered(_menu, heading, CENTER_X, 60.0, OUTLINE, 4)
	PixelFont.draw_centered(_menu, heading, CENTER_X, 57.0, ACCENT, 4)
	PixelFont.draw_centered(_menu, "HOW FAR TO THE HOLE?", CENTER_X, 98.0, OUTLINE)
	_menu.draw_rect(PANEL_RECT, Color(0.06, 0.09, 0.16, 0.78))
	_menu.draw_rect(PANEL_RECT, Color(0.95, 0.92, 0.82, 0.5), false, 1.0)
	for i in _item_count():
		_draw_row(i, ITEM_TOP + float(i) * ITEM_GAP)


func _draw_row(index: int, y: float) -> void:
	var color: Color = ACCENT if index == selected else TEXT
	if index >= IslesGenerator.COURSE_YARDS.size():
		PixelFont.draw_centered(_menu, "BACK", CENTER_X, y, color, 2)
		if index == selected:
			PixelFont.draw_shadowed(_menu, ">", Vector2(CENTER_X - 48.0, y), ACCENT, 2)
		return
	var yards: int = IslesGenerator.COURSE_YARDS[index]
	PixelFont.draw(_menu, "%d YD" % yards, Vector2(CENTER_X - 118.0, y), color, 2)
	var best: int = profile.best_isles_strokes(yards)
	var best_text: String = "BEST %d" % best if best > 0 else "NOT CROSSED YET"
	PixelFont.draw(_menu, best_text, Vector2(CENTER_X + 148.0 - float(PixelFont.text_width(best_text)), y + 4.0), DIM)
	if index == selected:
		PixelFont.draw_shadowed(_menu, ">", Vector2(CENTER_X - 144.0, y), ACCENT, 2)
