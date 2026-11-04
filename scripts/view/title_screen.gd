class_name TitleScreen
extends Node2D
## The title menu. Works with keyboard, controller and mouse.

signal play_chosen
signal editor_chosen
signal scores_chosen
signal quit_chosen

const ITEMS := ["PLAY", "MAP EDITOR", "HIGH SCORES", "QUIT"]
const ITEM_TOP := 186.0
const ITEM_GAP := 22.0
const CENTER_X := 320.0
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")

var library: MapLibrary
var _selected: int = 0
var _course_size: int = 0
var _time: float = 0.0
var _camera: Camera2D


func setup(p_library: MapLibrary) -> void:
	library = p_library


func _ready() -> void:
	_course_size = library.course_order().size()
	_camera = Camera2D.new()
	_camera.position = Vector2(320, 180)
	add_child(_camera)
	_camera.make_current()
	var background := BackgroundView.new()
	background.setup(_camera)
	add_child(background)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var menu := Node2D.new()
	menu.draw.connect(_draw_menu.bind(menu))
	layer.add_child(menu)
	menu.set_process(false)
	_menu = menu


var _menu: Node2D


func _process(delta: float) -> void:
	_time += delta
	_menu.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at(event.position)
		if hovered >= 0:
			_selected = hovered
	elif event.is_action_pressed("spin_up", false) or event.is_action_pressed("aim_up", false):
		_selected = posmod(_selected - 1, ITEMS.size())
	elif event.is_action_pressed("spin_down", false) or event.is_action_pressed("aim_down", false):
		_selected = posmod(_selected + 1, ITEMS.size())
	elif event.is_action_pressed("swing", false):
		_choose(_selected)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var over: int = _item_at(event.position)
		if over >= 0:
			_choose(over)
	elif event.is_action_pressed("quit", false):
		quit_chosen.emit()


func _item_at(at: Vector2) -> int:
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		if absf(at.x - CENTER_X) < 90.0 and at.y >= y - 4.0 and at.y < y + 16.0:
			return i
	return -1


func _choose(index: int) -> void:
	match index:
		0:
			if _course_size > 0:
				play_chosen.emit()
		1:
			editor_chosen.emit()
		2:
			scores_chosen.emit()
		3:
			quit_chosen.emit()


func _draw_menu(canvas: Node2D) -> void:
	var bob: float = round(sin(_time * 1.6) * 2.0)
	PixelFont.draw_centered(canvas, "GOLFERINO", CENTER_X, 66.0 + bob, ACCENT, 6)
	PixelFont.draw_centered(canvas, "A SIDE-ON GOLF ROGUELITE", CENTER_X, 124.0, TEXT)
	for i in ITEMS.size():
		var y: float = ITEM_TOP + float(i) * ITEM_GAP
		var color: Color = ACCENT if i == _selected else TEXT
		if i == 0 and _course_size == 0:
			color = DIM
		PixelFont.draw_centered(canvas, str(ITEMS[i]), CENTER_X, y, color, 2)
		if i == _selected:
			var half: float = float(PixelFont.text_width(str(ITEMS[i]), 2)) / 2.0
			PixelFont.draw_shadowed(canvas, ">", Vector2(CENTER_X - half - 22.0, y), ACCENT, 2)
	if _course_size == 0:
		PixelFont.draw_centered(canvas, "THE COURSE HAS NO HOLES: ADD SOME IN THE MAP EDITOR", CENTER_X, 330.0, ACCENT)
