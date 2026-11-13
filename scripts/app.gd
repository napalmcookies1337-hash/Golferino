extends Node
## The game's top level: moves between the title menu, playing, and the map editor.

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Tests point this at their own folder, so they never touch the player's maps.
var maps_dir: String = MapLibrary.DEFAULT_DIR
## The same, for high scores and unlocks.
var profile_path: String = Profile.DEFAULT_PATH
var library: MapLibrary
var profile: Profile
var _screen: Node
var _editor: MapEditor


func _ready() -> void:
	Controls.register()
	library = MapLibrary.new(maps_dir)
	profile = Profile.new(profile_path)
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
	title.setup(library, profile)
	title.play_chosen.connect(_start_course, CONNECT_DEFERRED)
	title.infinite_chosen.connect(_start_infinite, CONNECT_DEFERRED)
	title.isles_chosen.connect(_show_isles_menu, CONNECT_DEFERRED)
	title.editor_chosen.connect(_open_editor, CONNECT_DEFERRED)
	title.scores_chosen.connect(_show_scores, CONNECT_DEFERRED)
	title.collection_chosen.connect(_show_collection, CONNECT_DEFERRED)
	title.jukebox_chosen.connect(_show_jukebox, CONNECT_DEFERRED)
	title.appearance_chosen.connect(_show_appearance, CONNECT_DEFERRED)
	title.quit_chosen.connect(func() -> void: get_tree().quit())
	_swap_screen(title)


func _show_collection() -> void:
	var collection := CollectionScreen.new()
	collection.setup(profile)
	collection.done.connect(_show_title, CONNECT_DEFERRED)
	collection.done.connect(func() -> void: Sound.sfx("menu_back"))
	_swap_screen(collection)


func _show_jukebox() -> void:
	var jukebox := JukeboxScreen.new()
	jukebox.done.connect(_show_title, CONNECT_DEFERRED)
	jukebox.done.connect(func() -> void: Sound.sfx("menu_back"))
	_swap_screen(jukebox)


func _show_appearance() -> void:
	var appearance := AppearanceScreen.new()
	appearance.setup(profile)
	appearance.done.connect(_show_title, CONNECT_DEFERRED)
	appearance.done.connect(func() -> void: Sound.sfx("menu_back"))
	_swap_screen(appearance)


func _show_scores() -> void:
	var scores := HighScoresScreen.new()
	scores.setup(profile)
	scores.done.connect(_show_title, CONNECT_DEFERRED)
	scores.done.connect(func() -> void: Sound.sfx("menu_back"))
	_swap_screen(scores)


func _start_course(infinite: bool = false) -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.embedded = true
	main.library = library
	main.profile = profile
	main.infinite = infinite
	main.exit_requested.connect(_show_title, CONNECT_DEFERRED)
	_swap_screen(main)


func _start_infinite() -> void:
	_start_course(true)


func _show_isles_menu() -> void:
	var menu := IslesMenuScreen.new()
	menu.setup(profile)
	menu.course_chosen.connect(_start_isles, CONNECT_DEFERRED)
	menu.back_chosen.connect(_show_title, CONNECT_DEFERRED)
	menu.back_chosen.connect(func() -> void: Sound.sfx("menu_back"))
	_swap_screen(menu)


func _start_isles(yards: int) -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.embedded = true
	main.library = library
	main.profile = profile
	main.floating_isles = true
	main.isles_yards = yards
	main.exit_requested.connect(_show_title, CONNECT_DEFERRED)
	_swap_screen(main)


func _open_editor() -> void:
	_editor = MapEditor.new()
	_editor.setup(library)
	_editor.exit_requested.connect(_show_title, CONNECT_DEFERRED)
	_editor.test_requested.connect(_start_test, CONNECT_DEFERRED)
	_swap_screen(_editor)
	_play_editor_sound()


# The editor is a place to think, so it gets the shop's easy tune and no birdsong.
func _play_editor_sound() -> void:
	Sound.stop_jingle()
	Sound.music("shop")
	Sound.set_outdoors(false)


# The editor stays alive but dormant during a test, so nothing about it is lost.
func _start_test(hole: HoleData, start_x: float) -> void:
	_editor.set_active(false)
	var main: Node = MAIN_SCENE.instantiate()
	main.embedded = true
	main.profile = profile
	main.setup_test(hole, start_x)
	main.exit_requested.connect(_end_test.bind(main), CONNECT_DEFERRED)
	add_child(main)


func _end_test(main: Node) -> void:
	remove_child(main)
	main.queue_free()
	_editor.set_active(true)
	_play_editor_sound()
