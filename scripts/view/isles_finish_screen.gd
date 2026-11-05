class_name IslesFinishScreen
extends Node2D
## Shown on reaching the hole in Floating Isles: well done, how it went, and what next.

signal try_again
signal main_menu

enum Item { TRY_AGAIN, MAIN_MENU }

const ITEMS := ["TRY AGAIN", "MAIN MENU"]
const ITEM_TOP := 226.0
const ITEM_GAP := 24.0
const CENTER_X := 320.0
const PANEL_RECT := Rect2(120, 58, 400, 232)
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const GOOD := Color("6fe07a")

var selected: int = Item.TRY_AGAIN
var yards: int = 0
var strokes: int = 0
var falls: int = 0
## Its place on the leaderboard: 1 is best, 0 if it didn't make the table.
var place: int = 0
var best: int = 0
var _menu_input := MenuInput.new()


func setup(p_yards: int, p_strokes: int, p_falls: int, p_place: int, p_best: int) -> void:
	yards = p_yards
	strokes = p_strokes
	falls = p_falls
	place = p_place
	best = p_best


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
			_choose(_item_at(event.position))
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("quit", false):
		_choose(Item.MAIN_MENU)
	elif event.is_action_pressed("swing", false):
		_choose(selected)
	else:
		var step: Vector2i = _menu_input.step(event)
		if step.y != 0:
			selected = posmod(selected + step.y, ITEMS.size())
			Sound.sfx("menu_move")


func _choose(index: int) -> void:
	Sound.sfx("menu_ok")
	if index == Item.TRY_AGAIN:
		try_again.emit()
	else:
		main_menu.emit()


func _item_at(at: Vector2) -> int:
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if absf(at.x - CENTER_X) < 110.0 and at.y >= y - 4.0 and at.y < y + 18.0:
			return i
	return -1


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.05, 0.1, 0.55))
	draw_rect(PANEL_RECT, Color(0.07, 0.09, 0.16, 0.94))
	draw_rect(PANEL_RECT, Color("f2ead0"), false, 1.0)
	PixelFont.draw_centered(self, "CONGRATULATIONS!", CENTER_X, 72.0, ACCENT, 3)
	PixelFont.draw_centered(self, "YOU CROSSED %d YARDS OF FLOATING ISLES" % yards, CENTER_X, 106.0, TEXT)
	var stroke_word: String = "STROKE" if strokes == 1 else "STROKES"
	PixelFont.draw_centered(self, "%d %s" % [strokes, stroke_word], CENTER_X, 128.0, ACCENT, 3)
	var fall_word: String = "FALL" if falls == 1 else "FALLS"
	PixelFont.draw_centered(self, "NO FALLS" if falls == 0 else "%d %s" % [falls, fall_word], CENTER_X, 160.0, TEXT)
	PixelFont.draw_centered(self, _standing_text(), CENTER_X, 178.0, GOOD if place > 0 else DIM)
	PixelFont.draw_centered(self, "BEST %d" % best, CENTER_X, 196.0, DIM)
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		var color: Color = ACCENT if i == selected else TEXT
		PixelFont.draw_centered(self, str(ITEMS[i]), CENTER_X, y, color, 2)
		if i == selected:
			var half: float = float(PixelFont.text_width(str(ITEMS[i]), 2)) / 2.0
			PixelFont.draw_shadowed(self, ">", Vector2(CENTER_X - half - 22.0, y), ACCENT, 2)


func _standing_text() -> String:
	if place == 1:
		return "NEW BEST!"
	if place > 1:
		return "NUMBER %d ON THE LEADERBOARD" % place
	return "NOT QUITE ON THE LEADERBOARD"
