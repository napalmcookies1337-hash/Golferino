extends Node
## The game's top level: moves between the title menu, playing, and the map editor.

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Tests point this at their own folder, so they never touch the player's maps.
var maps_dir: String = MapLibrary.DEFAULT_DIR
var library: MapLibrary
var _screen: Node
var _editor: MapEditor


func _ready() -> void:
	Controls.register()
	library = MapLibrary.new(maps_dir)
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen", false):
		var window: Window = get_window()
		if window.mode == Window.MODE_WINDOWED:
			window.mode = Window.MODE_FULLSCREEN
		else:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(1280, 720)


func _swap_screen(next: Node) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = next
	add_child(next)


func _show_title() -> void:
	var title := TitleScreen.new()
	title.setup(library)
	title.play_chosen.connect(_start_course, CONNECT_DEFERRED)
	title.editor_chosen.connect(_open_editor, CONNECT_DEFERRED)
	title.quit_chosen.connect(func() -> void: get_tree().quit())
	_swap_screen(title)


func _start_course() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.embedded = true
	main.library = library
	main.exit_requested.connect(_show_title, CONNECT_DEFERRED)
	_swap_screen(main)


func _open_editor() -> void:
	_editor = MapEditor.new()
	_editor.setup(library)
	_editor.exit_requested.connect(_show_title, CONNECT_DEFERRED)
	_editor.test_requested.connect(_start_test, CONNECT_DEFERRED)
	_swap_screen(_editor)


# The editor stays alive but dormant during a test, so nothing about it is lost.
func _start_test(hole: HoleData, start_x: float) -> void:
	_editor.set_active(false)
	var main: Node = MAIN_SCENE.instantiate()
	main.embedded = true
	main.setup_test(hole, start_x)
	main.exit_requested.connect(_end_test.bind(main), CONNECT_DEFERRED)
	add_child(main)


func _end_test(main: Node) -> void:
	remove_child(main)
	main.queue_free()
	_editor.set_active(true)
