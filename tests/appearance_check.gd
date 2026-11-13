extends Node
## Drives the title menu and Appearance screen headless, by handing their input handlers the
## same events a mouse and keyboard would. No window needed. Uses its own save.
## Run with: Godot --headless --path . --quit-after 3000 res://tests/appearance_check.tscn

const PROFILE_PATH := "user://appearance_check_profile.json"

var app: Node
var _failures: int = 0


func _ready() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	app.maps_dir = "user://appearance_check_maps"
	app.profile_path = PROFILE_PATH
	add_child(app)
	_run()


func _run() -> void:
	await _frames(3)
	var title: TitleScreen = app._screen
	_expect(title != null, "the game opens on the title menu")
	for i in TitleScreen.ITEMS.size():
		_expect(title._item_at(TitleScreen.item_center(i)) == i, "%s can be clicked" % TitleScreen.ITEMS[i])
	_send(title, _action("aim_down"))
	_expect(title._selected == TitleScreen.Item.INFINITE, "down moves down the column")
	_send(title, _action("look_right"))
	_expect(title._selected == TitleScreen.Item.COLLECTION, "right changes column")

	_click(title, TitleScreen.item_center(TitleScreen.Item.APPEARANCE))
	await _frames(3)
	var screen: AppearanceScreen = app._screen as AppearanceScreen
	_expect(screen != null, "APPEARANCE opens from the menu")
	if screen == null:
		_finish()
		return
	var profile: Profile = app.profile
	_expect(profile.wallet == 50, "a new save has 50 coins")
	for cell: Dictionary in screen.cells:
		_expect(Rect2(0, 0, 640, 360).encloses(cell["rect"]), "every choice is on the screen")
	_expect(screen.cells.size() == 2 + 4 * 5 + 1, "two golfers, four kinds of clothes in five colors, and BACK")
	for i in 5:
		var x: float = (screen.cells[screen.cell_of_item(str(Wardrobe.items_for(Wardrobe.MALE, Wardrobe.SHIRT)[i]["id"]))]["rect"] as Rect2).position.x
		for slot: String in Wardrobe.SLOTS:
			var item: Dictionary = Wardrobe.items_for(Wardrobe.MALE, slot)[i]
			var cell: Dictionary = screen.cells[screen.cell_of_item(str(item["id"]))]
			_expect((cell["rect"] as Rect2).position.x == x, "%s lines up in its column" % item["name"])

	var red: Rect2 = screen.cells[screen.cell_of_item("male_shirt_red")]["rect"]
	_move(screen, red.get_center())
	_expect(screen._golfer.shirt == Color("e8584a"), "hovering a shirt tries it on")
	_expect(str(profile.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_white", "without buying it")
	_click(screen, red.get_center())
	_expect(profile.wallet == 35 and str(profile.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_red", "clicking buys it and puts it on")

	var black: Rect2 = screen.cells[screen.cell_of_item("male_hat_black")]["rect"]
	_move(screen, black.get_center())
	_expect(screen._golfer.cap == Color("f2efe4"), "a locked color can't be tried on")
	_expect(screen._info_line() == "LOCKED: BEAT THE RIVAL TO UNLOCK", "and says how to unlock it")
	_click(screen, black.get_center())
	_expect(str(profile.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_white", "or worn")
	var gold: Rect2 = screen.cells[screen.cell_of_item("male_hat_gold")]["rect"]
	_move(screen, gold.get_center())
	_expect(screen._info_line() == "LOCKED: FINISH THE 4000 YARD ISLES TO UNLOCK", "gold says how to unlock it")
	await _save("appearance_locked")
	profile.rival_beaten = true
	_click(screen, black.get_center())
	_expect(profile.wallet == 35 and str(profile.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_black", "beating the rival opens black, for free")
	profile.record_isles(4000, 50, 1)
	_click(screen, gold.get_center())
	_expect(str(profile.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_gold", "finishing the 4000 yard isles opens gold")
	for slot: String in Wardrobe.SLOTS:
		_click(screen, screen.cells[screen.cell_of_item("male_%s_black" % slot)]["rect"].get_center())
	await _save("appearance_male_black")

	var female: Rect2 = screen.cells[screen._model_cell(Wardrobe.FEMALE)]["rect"]
	_click(screen, female.get_center())
	_expect(profile.model == Wardrobe.FEMALE and screen._golfer.model == Wardrobe.FEMALE, "choosing FEMALE changes the golfer")
	_expect(screen.cell_of_item("female_hat_coral") >= 0 and screen.cell_of_item("male_hat_red") < 0, "and shows that golfer's own clothes")
	profile.wallet = 100
	for slot: String in Wardrobe.SLOTS:
		_click(screen, screen.cells[screen.cell_of_item("female_%s_sky" % slot)]["rect"].get_center())
	_expect(profile.wallet == 40 and str(profile.clothes[Wardrobe.FEMALE][Wardrobe.HAT]) == "female_hat_sky", "a column makes a matching outfit")
	for slot: String in Wardrobe.SLOTS:
		_click(screen, screen.cells[screen.cell_of_item("female_%s_gold" % slot)]["rect"].get_center())
	await _save("appearance_female_gold")

	var from: int = screen.cursor
	_send(screen, _action("aim_up"))
	_expect(screen.cursor != from, "the keyboard moves around the screen")
	_send(screen, _action("look_left"))
	_send(screen, _action("quit"))
	await _frames(3)
	_expect(app._screen is TitleScreen, "Esc goes back to the title")
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	print("appearance check finished, %d failed" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# Only with a window: headless, there's nothing to see.
func _save(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	get_viewport().get_texture().get_image().save_png("res://tests/shots/%s.png" % shot_name)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _send(target: Node, event: InputEvent) -> void:
	target._unhandled_input(event)


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _move(target: Node, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	_send(target, event)


func _click(target: Node, at: Vector2) -> void:
	_move(target, at)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_send(target, event)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)
