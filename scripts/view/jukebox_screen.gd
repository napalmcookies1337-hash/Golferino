class_name JukeboxScreen
extends Node2D
## Plays every music track in the game, from the title menu. A track starts as soon as it's
## picked. Works with keyboard, controller and mouse.

signal done

const NAMES := {
	"title": "TITLE SCREEN",
	"grassy": "GRASSY GREENS",
	"boss": "GRASSY GREENS RIVAL",
	"swamp": "SWAMPY SHORES",
	"swamp_boss": "SWAMPY SHORES RIVAL",
	"isles": "FLOATING ISLES",
	"shop": "PRO SHOP",
}
## In the order they're listed.
const TRACKS := ["title", "grassy", "boss", "swamp", "swamp_boss", "isles", "shop"]
const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const TEXT := Color("f7f4e6")
const DIM := Color("8f9caa")
const ACCENT := Color("ffe25a")
const ROW_LEFT := 110.0
const ROW_WIDTH := 420.0
const ROW_TOP := 70.0
const ROW_HEIGHT := 30.0
const BACK_BUTTON := Rect2(42, 332, 64, 18)
const BAR_COUNT := 5

var selected: int = 0

var _menu_input := MenuInput.new()
var _time: float = 0.0


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	# Just the music in here, with nothing playing over it.
	Sound.set_outdoors(false)
	_play_selected()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if BACK_BUTTON.has_point(event.position):
				done.emit()
				return
			for i in TRACKS.size():
				if _row_rect(i).has_point(event.position):
					select(i)
		return
	if event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		done.emit()
		return
	var step: Vector2i = _menu_input.step(event)
	if step.y != 0:
		select(posmod(selected + step.y, TRACKS.size()))
		get_viewport().set_input_as_handled()


func select(index: int) -> void:
	if index == selected:
		return
	selected = index
	Sound.sfx("menu_move")
	_play_selected()


func _play_selected() -> void:
	Sound.music(str(TRACKS[selected]))


func _row_rect(index: int) -> Rect2:
	return Rect2(ROW_LEFT, ROW_TOP + float(index) * ROW_HEIGHT, ROW_WIDTH, ROW_HEIGHT - 4.0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_shadowed(self, "JUKEBOX", Vector2(ROW_LEFT, 24), ACCENT, 3)
	for i in TRACKS.size():
		var rect: Rect2 = _row_rect(i)
		var is_selected: bool = i == selected
		draw_rect(rect, PANEL)
		draw_rect(rect, ACCENT if is_selected else Color(1, 1, 1, 0.15), false, 1.0)
		PixelFont.draw(self, str(NAMES[TRACKS[i]]), rect.position + Vector2(12, 9), ACCENT if is_selected else TEXT)
		if is_selected:
			_draw_bars(rect)
	draw_rect(BACK_BUTTON, PANEL)
	draw_rect(BACK_BUTTON, DIM, false, 1.0)
	PixelFont.draw_centered(self, "< BACK", BACK_BUTTON.get_center().x, BACK_BUTTON.position.y + 6.0, TEXT)
	PixelFont.draw_centered(self, "UP/DOWN OR CLICK TO PICK A TRACK   ESC TO GO BACK", 360.0, 338.0, DIM)


# A little dancing level meter beside the track that's playing. Only for show.
func _draw_bars(rect: Rect2) -> void:
	for i in BAR_COUNT:
		var height: float = round(4.0 + 7.0 * absf(sin(_time * (3.0 + float(i) * 0.9) + float(i) * 1.7)))
		var x: float = rect.end.x - 12.0 - float(BAR_COUNT - i) * 5.0
		draw_rect(Rect2(x, rect.get_center().y + 6.0 - height, 3, height), ACCENT)
