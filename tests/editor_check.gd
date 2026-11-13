extends Node
## Drives the real game through the title menu and map editor with real mouse and keyboard
## events, and saves screenshots to tests/shots. Uses its own map folder.
## Run with: Godot --path . --windowed --resolution 1280x720 --quit-after 20000 res://tests/editor_check.tscn

const OUT_DIR := "res://tests/shots"
const MAPS_DIR := "user://check_maps"
const PROFILE_PATH := "user://check_profile.json"

var app: Node
var _failures: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var absolute: String = ProjectSettings.globalize_path(MAPS_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in DirAccess.get_files_at(MAPS_DIR):
		DirAccess.remove_absolute("%s/%s" % [absolute, file_name])
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	app.maps_dir = MAPS_DIR
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	app.profile_path = PROFILE_PATH
	add_child(app)
	_run()


func editor() -> MapEditor:
	return app._editor


func _run() -> void:
	await _title_menu()
	await _maps_screen()
	await _open_and_add_objects()
	await _rotation()
	await _ground_and_paint()
	await _coin_in_editor()
	await _settings_panel()
	await _save_and_reload()
	await _test_play()
	await _one_press_putt()
	await _course_order()
	await _play_edited_course()
	for file_name in DirAccess.get_files_at(MAPS_DIR):
		DirAccess.remove_absolute("%s/%s" % [ProjectSettings.globalize_path(MAPS_DIR), file_name])
	print("editor check finished, %d failed" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _title_menu() -> void:
	await _wait(0.4)
	_expect(app._screen is TitleScreen, "the game opens on the title menu")
	await _save("editor_01_title")
	await _click(TitleScreen.item_center(TitleScreen.Item.EDITOR))
	await _wait(0.3)
	_expect(app._screen is MapEditor, "clicking MAP EDITOR opens the editor")


func _maps_screen() -> void:
	_expect(editor().maps_open, "the editor opens on the maps screen")
	await _save("editor_02_maps")


func _open_and_add_objects() -> void:
	# OPEN on the third row: hole 3.
	await _click(Vector2(200, LIST_Y(2)))
	await _wait(0.3)
	_expect(editor().map_id == "hole_03" and not editor().maps_open, "OPEN opens that map")
	await _save("editor_03_opened")

	_press_key(KEY_4)
	await _wait(0.05)
	_expect(editor().tool == MapEditor.Tool.ADD, "4 picks the add tool")
	await _save("editor_04_add_tool")
	await _click(Vector2(250, 120))
	await _wait(0.1)
	var pad: Dictionary = editor().doc.entry_of(editor().selection)
	_expect(str(pad.get("kind", "")) == "pad", "clicking the map places a pad")
	var world: Vector2 = editor().world_mouse()
	_expect(absf(float(pad["y"]) - world.y) < 2.0 and world.y < editor().doc.terrain.ground_y(world.x) - 40.0, "the pad sits in mid-air where clicked")
	await _save("editor_05_pad_placed")


func _rotation() -> void:
	var map_editor: MapEditor = editor()
	var handle: Vector2 = _to_screen(map_editor.rotate_handle())
	var center: Vector2 = _to_screen(map_editor.doc.selection_center(map_editor.selection))
	await _mouse_move(handle)
	await _mouse_button(handle, true)
	await _mouse_move(center + Vector2(36, 0))
	await _mouse_button(center + Vector2(36, 0), false)
	await _wait(0.1)
	_expect(absf(map_editor.doc.rotation_of(map_editor.selection) - 90.0) < 2.0, "dragging the ring rotates the pad (%.0f)" % map_editor.doc.rotation_of(map_editor.selection))
	await _save("editor_06_pad_rotated")

	_press_key(KEY_E, true)
	await _wait(0.05)
	_expect(absf(map_editor.doc.rotation_of(map_editor.selection) - 105.0) < 0.5, "Shift+E turns it 15 degrees (%.0f)" % map_editor.doc.rotation_of(map_editor.selection))
	Input.action_press("ui_accept")
	Input.action_release("ui_accept")
	var before: float = map_editor.doc.rotation_of(map_editor.selection)
	var hold := InputEventKey.new()
	hold.physical_keycode = KEY_Q
	hold.pressed = true
	Input.parse_input_event(hold)
	await _wait(0.25)
	hold = InputEventKey.new()
	hold.physical_keycode = KEY_Q
	hold.pressed = false
	Input.parse_input_event(hold)
	await _wait(0.05)
	_expect(map_editor.doc.rotation_of(map_editor.selection) < before - 5.0, "holding Q rotates it smoothly")

	# Dragging the pad itself moves it.
	var at: Vector2 = _to_screen(map_editor.doc.selection_center(map_editor.selection))
	await _mouse_move(at)
	await _mouse_button(at, true)
	await _mouse_move(at + Vector2(40, -20))
	await _mouse_button(at + Vector2(40, -20), false)
	await _wait(0.1)
	_expect(_to_screen(map_editor.doc.selection_center(map_editor.selection)).distance_to(at + Vector2(40, -20)) < 3.0, "dragging moves the pad")

	# Carts can't rotate: no ring appears and Q/E do nothing.
	_press_key(KEY_4)
	await _wait(0.05)
	await _click(Vector2(290, 332 + 8))
	await _wait(0.05)
	_expect(map_editor.add_kind == "cart", "the add list picks a cart")
	await _click(Vector2(200, 200))
	await _wait(0.1)
	_expect(str(map_editor.doc.entry_of(map_editor.selection).get("kind", "")) == "cart", "a cart was placed")
	_expect(not map_editor.doc.can_rotate(map_editor.selection), "a cart has no rotation")
	await _save("editor_07_cart_route")
	await _tree_pieces()


func _tree_pieces() -> void:
	var map_editor: MapEditor = editor()
	var doc: EditorDoc = map_editor.doc

	# Places a trunk and separate leaves with real clicks on the add list.
	_press_key(KEY_4)
	await _wait(0.05)
	await _click(_add_button("trunk"))
	await _wait(0.05)
	_expect(map_editor.add_kind == "trunk", "the add list has trunks")
	var count: int = doc.hole.scenery.size()
	var ground_x: float = _to_world(Vector2(140, 200)).x
	await _click(_to_screen(Vector2(ground_x, doc.terrain.ground_y(ground_x) - 2.0)))
	await _wait(0.1)
	_expect(doc.hole.scenery.size() == count + 1, "clicking places one trunk")
	_expect(str(doc.piece_of(map_editor.selection).get("kind", "")) == "trunk", "the new trunk is selected")

	_press_key(KEY_4)
	await _wait(0.05)
	await _click(_add_button("leaves"))
	await _wait(0.05)
	_expect(map_editor.add_kind == "leaves", "the add list has leaves")
	await _click(Vector2(90, 110))
	await _wait(0.1)
	_expect(doc.hole.scenery.size() == count + 2, "clicking places one set of leaves")
	_expect(str(doc.piece_of(map_editor.selection).get("kind", "")) == "leaves", "the new leaves are selected")
	await _save("editor_07b_tree_pieces")

	# Drags an original tree's leaves away from its trunk, then its trunk elsewhere.
	var trunk_index: int = -1
	for i in doc.hole.scenery.size():
		var piece: Dictionary = doc.hole.scenery[i]
		if str(piece["kind"]) == "trunk" and absf(float(piece["x"]) - 20.0) < 1.0:
			trunk_index = i
	var original_leaves: Dictionary = { "type": "scenery", "index": trunk_index + 1 }
	var original_trunk: Dictionary = { "type": "scenery", "index": trunk_index }
	var trunk_x: float = float(doc.piece_of(original_trunk)["x"])
	var at: Vector2 = _to_screen(doc.selection_center(original_leaves))
	await _mouse_move(at)
	await _mouse_button(at, true)
	await _mouse_move(at + Vector2(70, -30))
	await _mouse_button(at + Vector2(70, -30), false)
	await _wait(0.1)
	_expect(map_editor.selection == original_leaves, "clicking an original tree's leaves selects just them")
	_expect(_to_screen(doc.selection_center(original_leaves)).distance_to(at + Vector2(70, -30)) < 3.0, "dragging moves those leaves")
	_expect(is_equal_approx(float(doc.piece_of(original_trunk)["x"]), trunk_x), "and its trunk stays put")
	await _save("editor_07c_leaves_moved")
	map_editor.selection = {}
	await _wait(0.05)


func _add_button(kind: String) -> Vector2:
	var x: float = 240.0
	for entry in MapEditor.OBJECTS:
		var width: float = float(PixelFont.text_width(str(entry["label"]))) + 8.0
		if str(entry["kind"]) == kind:
			return Vector2(x + width / 2.0, MapEditor.BOTTOM_Y + 8.0)
		x += width + 2.0
	return Vector2.ZERO


func _ground_and_paint() -> void:
	var map_editor: MapEditor = editor()
	_press_key(KEY_2)
	await _wait(0.1)
	await _save("editor_08_ground_tool")
	var count: int = map_editor.doc.hole.points.size()
	var spot: float = map_editor.camera.position.x + 100.0
	var on_ground: Vector2 = _to_screen(Vector2(spot, map_editor.doc.terrain.ground_y(spot)))
	await _mouse_move(on_ground)
	await _mouse_button(on_ground, true)
	await _mouse_move(on_ground + Vector2(0, -30))
	await _mouse_button(on_ground + Vector2(0, -30), false)
	await _wait(0.2)
	_expect(map_editor.doc.hole.points.size() == count + 1, "clicking the ground adds a point")
	_expect(map_editor.doc.terrain.ground_y(spot) < _to_world(on_ground).y - 20.0, "dragging the point raises the ground")
	await _save("editor_09_ground_raised")

	_press_key(KEY_3)
	await _wait(0.05)
	await _click(Vector2(240 + 4 + 18 + 42 + 16, 332 + 8))
	await _wait(0.05)
	var picked: int = map_editor.paint_type
	var from: Vector2 = Vector2(100, 200)
	var to: Vector2 = Vector2(160, 200)
	await _mouse_move(from)
	await _mouse_button(from, true)
	await _mouse_move(to)
	await _save("editor_10_painting")
	await _mouse_button(to, false)
	await _wait(0.2)
	var middle: float = _to_world((from + to) / 2.0).x
	_expect(map_editor.doc.terrain.surface_at(middle) == picked, "dragging paints the ground (wanted %d)" % picked)
	await _save("editor_11_painted")

	_press_key(KEY_Z, false, true)
	await _wait(0.2)
	_expect(map_editor.doc.terrain.surface_at(middle) != picked or picked == Surface.Type.FAIRWAY, "Ctrl+Z undoes the paint")
	_press_key(KEY_Y, false, true)
	await _wait(0.2)
	_expect(map_editor.doc.terrain.surface_at(middle) == picked, "Ctrl+Y redoes it")


func _settings_panel() -> void:
	var map_editor: MapEditor = editor()
	_press_key(KEY_1)
	await _wait(0.05)
	map_editor.selection = {}
	await _wait(0.1)
	await _save("editor_12_hole_settings")
	var par: int = map_editor.doc.hole.par
	# THIS MAP, the name, the length, the look, then PAR's plus button.
	await _click(Vector2(506 + 42 + 43 + 6, 25 + 12 + 17 + 12 + 17 + 6))
	await _wait(0.1)
	_expect(map_editor.doc.hole.par == par + 1, "the panel's + raises par (%d)" % map_editor.doc.hole.par)

	await _click(Vector2(560, 25 + 12 + 6))
	await _wait(0.05)
	_expect(map_editor._typing, "clicking the name starts typing")
	for key: Key in [KEY_BACKSPACE, KEY_BACKSPACE]:
		_type_key(key, 0)
	_type_key(KEY_X, 120)
	_type_key(KEY_ENTER, 0)
	await _wait(0.1)
	_expect(map_editor.doc.hole.title.ends_with("X"), "typing changes the map's name (%s)" % map_editor.doc.hole.title)


func _save_and_reload() -> void:
	var map_editor: MapEditor = editor()
	_expect(map_editor.doc.dirty, "the map shows unsaved changes")
	_press_key(KEY_S, false, true)
	await _wait(0.1)
	_expect(not map_editor.doc.dirty, "Ctrl+S saves")
	var saved: HoleData = map_editor.library.load_hole("hole_03")
	_expect(saved.obstacles.size() == map_editor.doc.hole.obstacles.size(), "the saved map has its objects")
	_expect(map_editor.library.kind_of("hole_03") == MapLibrary.Kind.EDITED, "the hole now counts as edited")
	var original: HoleData = map_editor.library.load_original("hole_03")
	_expect(original.obstacles.size() < saved.obstacles.size(), "the original is still there underneath")


func _test_play() -> void:
	var map_editor: MapEditor = editor()
	var camera_at: Vector2 = map_editor.camera.position
	var undo_was: bool = map_editor.doc.can_undo()
	var pad_count: int = map_editor.doc.hole.obstacles.size()

	_press_key(KEY_F5)
	await _wait(0.5)
	var main: Node = _test_main()
	_expect(main != null and main.is_testing(), "F5 starts a test")
	_expect(not map_editor.visible, "the editor hides during a test")
	_expect(is_equal_approx(main.game.ball.pos.x, map_editor.doc.hole.tee_x), "the test starts from the tee")
	_expect(main.game.obstacles.size() == pad_count, "the test uses the map being edited")
	await _save("editor_13_test_from_tee")

	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(main.game.phase == HoleGame.Phase.SWING, "the test can actually be played")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(_test_main() == null, "Esc ends the test")
	_expect(map_editor.visible and app._screen == map_editor, "the editor comes back")
	_expect(map_editor.camera.position.distance_to(camera_at) < 1.0, "the view is where it was")
	_expect(map_editor.doc.can_undo() == undo_was, "undo history survives")
	await _save("editor_14_back_from_test")

	var mouse_spot: Vector2 = Vector2(300, 150)
	await _mouse_move(mouse_spot)
	var wanted: float = _to_world_with(map_editor, mouse_spot).x
	_press_key(KEY_T)
	await _wait(0.5)
	main = _test_main()
	_expect(main != null and absf(main.game.ball.pos.x - wanted) < 3.0, "T starts a test at the mouse")
	await _save("editor_15_test_from_mouse")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)

	# Hitting the pad for real in a test run, with the ball dropped above its spring face.
	var pad_map: HoleData = HoleIO.blank_hole("PAD CHECK")
	pad_map.obstacles = [{ "kind": "pad", "x": 400.0, "y": 250.0, "rotation": 30.0 }]
	map_editor.test_requested.emit(pad_map, 300.0)
	await _wait(0.4)
	main = _test_main()
	main.game.ball.pos = Vector2(400, 200)
	main.game.ball.launch(Vector2(0, 40), 0.0)
	main.game.ball.launch_x = 0.0
	main.game._set_phase(HoleGame.Phase.BALL_MOVING)
	await _wait(1.0)
	_expect(main.game.ball.vel.x > 40.0, "a rotated pad fires along its face in real play (%.0f)" % main.game.ball.vel.x)
	await _save("editor_16_pad_fired")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)


# Putts in the real game with a real key press, from a test started on the green.
func _one_press_putt() -> void:
	var map_editor: MapEditor = editor()
	map_editor.test_requested.emit(HoleIO.blank_hole("PUTT CHECK"), 950.0)
	await _wait(0.6)
	var main: Node = _test_main()
	_expect(main.game.current_club().is_putter, "the putter comes up on the green")
	_expect(main.game.meter.stage == SwingMeter.Stage.IDLE, "the putting meter waits for a press")
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(main.game.meter.stage == SwingMeter.Stage.SWEEPING and main.game.strokes == 0, "the first press of Space starts the meter")
	await _save("editor_16b_putting_meter")
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(main.game.strokes == 1, "the second press of Space putts")
	await _save("editor_16c_putt_rolling")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)


func _coin_in_editor() -> void:
	var map_editor: MapEditor = editor()
	_press_key(KEY_4)
	await _wait(0.1)
	map_editor.add_kind = "coin"
	await _wait(0.1)
	await _save("editor_16d_coin_tool")
	await _click(Vector2(200, 100))
	await _wait(0.1)
	var coin: Dictionary = map_editor.doc.entry_of(map_editor.selection)
	_expect(str(coin.get("kind", "")) == "coin", "clicking the map places a coin")
	await _save("editor_16e_coin_placed")
	_press_key(KEY_1)
	await _wait(0.1)


func _course_order() -> void:
	var map_editor: MapEditor = editor()
	_press_key(KEY_ESCAPE)
	await _wait(0.05)
	if not map_editor.selection.is_empty():
		_press_key(KEY_ESCAPE)
		await _wait(0.05)
	if not map_editor.maps_open:
		await _click(Vector2(16, 10))
		await _wait(0.1)
	_expect(map_editor.maps_open, "the maps screen opens")
	await _save("editor_17_maps_edited")

	await _click(Vector2(40, 342))
	await _wait(0.3)
	_expect(map_editor.map_id == "map_001", "NEW MAP makes and opens a custom map")
	await _save("editor_18_new_map")
	await _click(Vector2(16, 10))
	await _wait(0.1)

	# ADD on the new map, the last row, then move it to the top.
	# Originals fill the list now, so it takes a scroll of the wheel to reach it.
	var row: int = map_editor.library.list_ids().size() - 1
	map_editor._maps_scroll = row - MapEditor.LIST_ROWS + 1
	await _wait(0.1)
	await _click(Vector2(236, LIST_Y(MapEditor.LIST_ROWS - 1)))
	await _wait(0.1)
	map_editor._maps_scroll = 0
	var order: Array[String] = map_editor.library.course_order()
	_expect(order[order.size() - 1] == "map_001", "ADD puts the map in the course")
	await _click(Vector2(530, LIST_Y(order.size() - 1)))
	await _wait(0.1)
	order = map_editor.library.course_order()
	_expect(order[order.size() - 2] == "map_001", "UP moves it earlier")
	await _click(Vector2(600, LIST_Y(order.size() - 2)))
	await _wait(0.1)
	_expect(not map_editor.library.course_order().has("map_001"), "REMOVE takes it out of the course")
	_expect(map_editor.library.list_ids().has("map_001"), "but the map itself stays")
	await _save("editor_19_course_list")
	# The other course has its own list.
	await _click(Vector2(518, 10))
	await _wait(0.1)
	_expect(map_editor._course_biome == HoleData.BIOME_SWAMP, "the button shows the swamp's course")
	await _save("editor_19b_swamp_course")
	await _click(Vector2(518, 10))
	await _wait(0.1)
	_expect(map_editor._course_biome == HoleData.BIOME_GRASSY, "and back")

	# RESTORE on hole 3, with its confirmation.
	await _click(Vector2(280, LIST_Y(2)))
	await _wait(0.1)
	await _save("editor_20_confirm")
	await _click(Vector2(320 - 72 + 35, 188))
	await _wait(0.1)
	_expect(map_editor.library.kind_of("hole_03") == MapLibrary.Kind.ORIGINAL, "RESTORE brings the original back")


func _play_edited_course() -> void:
	var map_editor: MapEditor = editor()
	var edited: HoleData = map_editor.library.load_hole("hole_01")
	edited.title = "RENAMED"
	map_editor.library.save_hole("hole_01", edited)
	await _click(Vector2(590, 342))
	await _wait(0.1)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "TITLE MENU goes back to the menu")
	await _click(TitleScreen.item_center(TitleScreen.Item.PLAY))
	await _wait(0.5)
	_expect(app._screen.get("game") != null, "PLAY starts the course")
	_expect(app._screen.game.hole.title == "RENAMED", "a run plays the edited maps")
	_expect(app._screen.game.hole.display_name == "HOLE 1", "holes are numbered in the run")
	await _save("editor_21_run_uses_edits")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(app._screen.pause_menu != null, "Esc in a run pauses it")
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(app._screen.run_over != null, "ending a run shows the final score")
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(app._screen.run_over != null and app._screen.run_over.is_revealed(), "the first press only shows the whole score")
	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "the final score goes back to the menu")
	_expect(app.profile.high_scores.size() == 1, "an ended run is saved to the high scores")
	await _click(TitleScreen.item_center(TitleScreen.Item.SCORES))
	await _wait(0.3)
	_expect(app._screen is HighScoresScreen, "HIGH SCORES opens from the menu")
	await _save("editor_22_high_scores")
	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "the high scores go back to the menu")
	await _save("editor_23_title_again")
	await _collection()
	DirAccess.remove_absolute(PROFILE_PATH)


func _collection() -> void:
	await _jukebox_menu()
	await _appearance_menu()
	await _click(TitleScreen.item_center(TitleScreen.Item.COLLECTION))
	await _wait(0.3)
	_expect(app._screen is CollectionScreen, "COLLECTION opens from the menu")
	_expect(not app.profile.rival_beaten, "the check's new profile hasn't beaten the rival")
	var screen: CollectionScreen = app._screen
	_expect(screen.selected_item()["id"] == "power_stripe", "the collection starts on the first item")
	for grid_row in screen.rows.size():
		var last_cell: Rect2 = screen._cell_rect(grid_row, (screen.rows[grid_row] as Array).size() - 1)
		_expect(last_cell.end.x <= CollectionScreen.DETAIL.end.x + 1.0, "collection row %d fits on the screen" % grid_row)
	await _save("editor_24_collection_new")
	# The first row's last cell, a locked sticker, picked by the mouse.
	var cell: Vector2 = screen._cell_rect(0, (screen.rows[0] as Array).size() - 1).get_center()
	await _click(cell)
	await _wait(0.1)
	_expect(screen.selected_item()["id"] == "two_way_tape", "clicking an item selects it")
	await _save("editor_25_collection_locked")
	# Earn some items, so unlocked and locked show side by side.
	app.profile.unlocked.assign(["forgiver", "heavy_ball", "two_way_tape"])
	await _wait(0.1)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_expect(screen.row == 1, "down moves to the next row")
	await _save("editor_26_collection_some")
	_expect(screen.describe(Items.by_id("heavy_ball"))["name"] == "HEAVY BALL", "an earned item shows its name")
	app.profile.unlocked.assign(Items.unlock_order())
	await _wait(0.1)
	_expect(screen.count_owned() == screen.count_all(), "with everything earned, nothing is locked")
	await _save("editor_27_collection_all")
	await _click(CollectionScreen.BACK_BUTTON.get_center())
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "BACK goes back to the menu")
	_press_key(KEY_RIGHT)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(app._screen is CollectionScreen, "the keyboard reaches COLLECTION")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "Esc leaves the collection")
	await _infinite_menu()


# Starts locked, opens once the rival's been beaten, and has its own page of scores.
func _infinite_menu() -> void:
	(app._screen as TitleScreen)._selected = TitleScreen.Item.INFINITE
	await _wait(0.1)
	await _save("editor_28_infinite_locked")
	await _click(TitleScreen.item_center(TitleScreen.Item.INFINITE))
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "infinite mode stays locked until the rival's beaten")

	app.profile.rival_beaten = true
	await _wait(0.1)
	await _save("editor_29_infinite_open")
	await _click(TitleScreen.item_center(TitleScreen.Item.INFINITE))
	await _wait(0.6)
	_expect(app._screen.get("infinite") == true, "the button starts an infinite run")
	_expect(app._screen.run_state.infinite, "the run knows it's infinite")
	_expect(app._screen.run.hole_count() == HoleGenerator.HOLES_PER_SET + 1, "it's nine holes and a boss")
	await _save("editor_30_infinite_first_hole")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(app._screen.run_over != null, "ending the run shows the final score")
	await _save("editor_31_infinite_final_score")
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "and goes back to the menu")
	_expect(app.profile.infinite_scores.size() == 1, "the run goes in infinite mode's own table")
	_expect(app.profile.high_scores.size() == 1, "and not the main game's")

	await _click(TitleScreen.item_center(TitleScreen.Item.SCORES))
	await _wait(0.3)
	var scores: HighScoresScreen = app._screen
	_expect(scores.page == HighScoresScreen.Page.MAIN, "high scores open on the main game")
	_press_key(KEY_RIGHT)
	await _wait(0.1)
	_expect(scores.page == HighScoresScreen.Page.INFINITE, "right shows infinite mode's scores")
	await _save("editor_32_infinite_scores")
	_press_key(KEY_SPACE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "and Space goes back")
	await _floating_isles_menu()


func _floating_isles_menu() -> void:
	await _save("editor_33_title_with_isles")
	await _click(TitleScreen.item_center(TitleScreen.Item.ISLES))
	await _wait(0.5)
	_expect(app._screen is IslesMenuScreen, "FLOATING ISLES asks how far, with nothing to unlock first")
	await _save("editor_33_isles_menu")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_expect(app._screen is TitleScreen, "Esc goes back from the choice of course")

	await _click(TitleScreen.item_center(TitleScreen.Item.ISLES))
	await _wait(0.3)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(app._screen.floating_isles and app._screen.isles_yards == 2000, "the keyboard chooses a length")
	_expect(is_equal_approx(app._screen.game.distance_to_cup(), 6000.0), "and loads a course that long")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(app._screen is TitleScreen, "MAIN MENU in its pause menu goes back")

	await _click(TitleScreen.item_center(TitleScreen.Item.ISLES))
	await _wait(0.3)
	await _click(Vector2(320, IslesMenuScreen.ITEM_TOP + 6.0))
	await _wait(0.8)
	_expect(app._screen.isles_yards == 1000, "and so does the mouse")
	_expect(is_equal_approx(app._screen.game.distance_to_cup(), 3000.0), "for a course of that length")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(app._screen is TitleScreen, "and MAIN MENU in its pause menu goes back")
	_expect(app.profile.isles_table(1000).is_empty(), "leaving early doesn't go on the leaderboard")

	app.profile.record_isles(4000, 38, 0)
	app.profile.record_isles(4000, 52, 2)
	app.profile.record_isles(4000, 44, 1)
	app.profile.record_isles(1000, 9, 0)
	app.profile.record_isles(1000, 11, 1)
	await _click(TitleScreen.item_center(TitleScreen.Item.SCORES))
	await _wait(0.3)
	var scores: HighScoresScreen = app._screen
	_press_key(KEY_LEFT)
	await _wait(0.1)
	_expect(scores.page == HighScoresScreen.Page.ISLES, "left wraps round to the Floating Isles leaderboard")
	await _save("editor_34_isles_scores")
	_press_key(KEY_SPACE)
	await _wait(0.3)


# Trying on and buying clothes with real clicks, and the two-column menu that leads there.
func _appearance_menu() -> void:
	var title: TitleScreen = app._screen
	await _wait(1.0)
	await _save("editor_23d_title_columns")
	for i in TitleScreen.ITEMS.size():
		_expect(title._item_at(TitleScreen.item_center(i)) == i, "%s can be clicked" % TitleScreen.ITEMS[i])
	# Round each column by keyboard, through the jukebox and back to the top.
	title._selected = TitleScreen.Item.PLAY
	for i in TitleScreen.COLUMN_ROWS:
		_press_key(KEY_DOWN)
	await _wait(0.1)
	_expect(title._selected == TitleScreen.Item.JUKEBOX, "the jukebox is under the columns")
	_press_key(KEY_DOWN)
	await _wait(0.1)
	_expect(title._selected == TitleScreen.Item.PLAY, "and leads back to the top")
	_press_key(KEY_RIGHT)
	await _wait(0.1)
	_expect(title._selected == TitleScreen.Item.SCORES, "right changes column")
	_press_key(KEY_LEFT)
	await _wait(0.1)
	_expect(title._selected == TitleScreen.Item.PLAY, "and left comes back")

	await _click(TitleScreen.item_center(TitleScreen.Item.APPEARANCE))
	await _wait(0.2)
	_expect(app._screen is AppearanceScreen, "APPEARANCE opens from the menu")
	var screen: AppearanceScreen = app._screen
	var profile: Profile = app.profile
	profile.wallet = 50
	for cell: Dictionary in screen.cells:
		var rect: Rect2 = cell["rect"]
		_expect(Rect2(0, 0, 640, 360).encloses(rect), "every choice is on the screen")
	await _save("editor_23e_appearance_male")

	var red: Rect2 = screen.cells[screen.cell_of_item("male_shirt_red")]["rect"]
	await _mouse_move(red.get_center())
	_expect(screen._golfer.shirt == Color("e8584a"), "hovering a shirt tries it on")
	_expect(str(profile.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_white", "without buying it")
	await _save("editor_23f_appearance_try_on")
	await _click(red.get_center())
	await _wait(0.1)
	_expect(profile.wallet == 35 and str(profile.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_red", "clicking buys it and puts it on")

	# Black and gold stay locked until they're earned, and can't even be tried on.
	profile.rival_beaten = false
	var black: Rect2 = screen.cells[screen.cell_of_item("male_hat_black")]["rect"]
	await _click(black.get_center())
	await _wait(0.1)
	_expect(screen._golfer.cap != Color("363640") and str(profile.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_white", "a locked color can't be worn")
	_expect(screen._info_line().begins_with("LOCKED"), "and says how to unlock it")
	await _save("editor_23g_appearance_locked")
	profile.rival_beaten = true
	await _click(black.get_center())
	await _wait(0.1)
	_expect(profile.wallet == 35 and str(profile.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_black", "beating the rival opens black, for free")
	await _save("editor_23h_appearance_black")

	var female: Rect2 = screen.cells[screen._model_cell(Wardrobe.FEMALE)]["rect"]
	await _click(female.get_center())
	await _wait(0.1)
	_expect(profile.model == Wardrobe.FEMALE and screen._golfer.model == Wardrobe.FEMALE, "choosing FEMALE changes the golfer")
	_expect(screen.cell_of_item("female_hat_coral") >= 0 and screen.cell_of_item("male_hat_red") < 0, "and shows that golfer's own clothes")
	await _save("editor_23i_appearance_female")
	profile.wallet = 100
	for slot: String in Wardrobe.SLOTS:
		await _click(screen.cells[screen.cell_of_item("female_%s_sky" % slot)]["rect"].get_center())
		await _wait(0.05)
	_expect(profile.wallet == 40 and str(profile.clothes[Wardrobe.FEMALE][Wardrobe.HAT]) == "female_hat_sky", "a column makes a matching outfit")
	await _save("editor_23j_appearance_female_sky")

	# Up, down and sideways all reach somewhere.
	var from: int = screen.cursor
	_press_key(KEY_UP)
	await _wait(0.1)
	_expect(screen.cursor != from, "the keyboard moves around the screen")
	_press_key(KEY_LEFT)
	await _wait(0.1)
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(app._screen is TitleScreen, "Esc goes back to the title")
	await _wait(1.0)
	await _save("editor_23k_title_female")
	profile.model = Wardrobe.MALE
	profile.clothes[Wardrobe.MALE] = Wardrobe.starting_clothes(Wardrobe.MALE)
	profile.save()


# Under the title menu's volume rows. Every track plays, and leaving goes back to the title's own.
func _jukebox_menu() -> void:
	await _click(TitleScreen.item_center(TitleScreen.Item.JUKEBOX))
	await _wait(0.2)
	_expect(app._screen is JukeboxScreen, "JUKEBOX opens from the menu")
	_expect(Sound.current_music == "title", "starting on the title's own tune")
	await _save("editor_23b_jukebox")
	var heard: Array[String] = []
	for _i in JukeboxScreen.TRACKS.size():
		heard.append(Sound.current_music)
		_press_key(KEY_DOWN)
		await _wait(0.1)
	for track: String in Sound.MUSIC_NAMES:
		_expect(heard.has(track), "the keyboard reaches %s" % track)
	_expect(Sound.current_music == "title", "the list wraps round")
	await _click((app._screen as JukeboxScreen)._row_rect(3).get_center())
	await _wait(0.1)
	_expect(Sound.current_music == "swamp", "clicking a track plays it")
	await _save("editor_23c_jukebox_swamp")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(app._screen is TitleScreen, "Esc goes back to the title")
	_expect(Sound.current_music == "title", "and to its music")


func _test_main() -> Node:
	for child in app.get_children():
		if child != app._screen and child.get("game") != null:
			return child
	return null


func LIST_Y(row: int) -> float:
	return MapEditor.LIST_TOP + float(row) * MapEditor.ROW_H + 6.0


func _to_screen(world: Vector2) -> Vector2:
	return editor().get_canvas_transform() * world


func _to_world(screen: Vector2) -> Vector2:
	return editor().get_canvas_transform().affine_inverse() * screen


func _to_world_with(map_editor: MapEditor, screen: Vector2) -> Vector2:
	return map_editor.get_canvas_transform().affine_inverse() * screen


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
	print("%s: %s" % ["ok" if condition else "FAIL", label])


# The game is 640x360 scaled by a whole number to fit the window, and centered in it.
func _to_window(at: Vector2) -> Vector2:
	var size := Vector2(get_window().size)
	var scale_by: float = maxf(floor(minf(size.x / 640.0, size.y / 360.0)), 1.0)
	return at * scale_by + (size - Vector2(640, 360) * scale_by) / 2.0


func _mouse_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _to_window(at)
	event.global_position = event.position
	event.relative = Vector2(1, 0)
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _mouse_button(at: Vector2, is_pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _to_window(at)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = is_pressed
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _click(at: Vector2) -> void:
	await _mouse_move(at)
	await _wait(0.05)
	await _mouse_button(at, true)
	await _mouse_button(at, false)


func _press_key(key: Key, shift: bool = false, ctrl: bool = false) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = is_pressed
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		Input.parse_input_event(event)


func _type_key(key: Key, unicode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(shot_name: String) -> void:
	# With no window there's nothing to save, but every other check still runs.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])
