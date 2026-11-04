extends Node
## Plays the real scene and saves screenshots to tests/shots.
## Run with: Godot --path . --windowed --resolution 1280x720 res://tests/shots.tscn

const OUT_DIR := "res://tests/shots"

var main: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Clear out shots from earlier runs, so nothing stale gets reviewed.
	for file_name in DirAccess.get_files_at(OUT_DIR):
		DirAccess.remove_absolute("%s/%s" % [OUT_DIR, file_name])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func game() -> HoleGame:
	return main.game


func _run() -> void:
	await _test_real_input()
	await _test_progression()
	for i in main.run.hole_count():
		await _shoot_hole(i)
	await _shoot_hazards()
	get_tree().quit()


func _test_real_input() -> void:
	await _wait(0.5)
	_expect(not main.camera.is_free_looking(), "not free looking at the tee")
	_press_key(KEY_E)
	await _wait(0.05)
	_expect(game().current_club().id == "iron", "E selects the next club")
	_press_key(KEY_1)
	await _wait(0.05)
	_expect(game().current_club().id == "driver", "1 selects the driver")
	_press_key(KEY_W)
	await _wait(0.05)
	_expect(game().spin == 1, "W adds topspin")
	_press_key(KEY_S)
	await _wait(0.05)
	_expect(game().spin == 0, "S takes it back off")

	_press_key(KEY_SPACE)
	await _wait(0.6)
	_expect(game().phase == HoleGame.Phase.SWING, "Space starts the swing")
	_press_button(JOY_BUTTON_A)
	await _wait(0.3)
	_expect(game().meter.stage == SwingMeter.Stage.RETURNING, "controller A sets power")
	while game().meter.cursor > 0.0:
		await get_tree().physics_frame
	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(game().strokes == 1, "the third press hits the ball")
	await _save("00_flight")


# Holes the current hole for real, then checks that Space moves on to the next one.
func _test_progression() -> void:
	game().ball.place(1438.0)
	game().ball.launch(Vector2(1.0, 0.0), 0.0)
	game()._set_phase(HoleGame.Phase.BALL_MOVING)
	while game().phase != HoleGame.Phase.COMPLETE:
		await get_tree().physics_frame
	await _wait(0.35)
	await _save("00_hole_complete")
	_expect(main.run.scores.has(0), "finishing a hole records its score")

	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(main.run.hole_index == 1, "Space moves on to the next hole")
	_expect(game().hole.display_name == "HOLE 2", "the new hole is loaded")
	await _save("00_next_hole_title")
	_press_key(KEY_PAGEUP)
	await _wait(0.2)
	_expect(main.run.hole_index == 0, "Page Up reviews the previous hole")


# Saves a zoomed-out view of the whole hole, then the view from the tee.
func _shoot_hole(index: int) -> void:
	main.run.hole_index = index
	main.load_current_hole()
	await _wait(0.5)
	var label: String = "hole_%02d" % (index + 1)
	await _save("%s_tee" % label)

	var camera: FollowCamera = main.camera
	var length: float = float(game().terrain.length)
	camera.set_process(false)
	camera.limit_left = -10000
	camera.limit_right = 10000
	camera.limit_top = -10000
	camera.limit_bottom = 10000
	var fit: float = 640.0 / length
	camera.zoom = Vector2(fit, fit)
	camera.position = Vector2(length / 2.0, 290.0)
	await _wait(0.15)
	await _save("%s_overview" % label)


func _shoot_hazards() -> void:
	await _shoot_at(2, 440.0, "hazard_pad_away")
	await _shoot_at(2, 1040.0, "hazard_pad_toward")
	await _shoot_at(3, 1730.0, "hazard_pad_flat")
	await _shoot_at(4, 560.0, "hazard_cart")
	await _shoot_at(5, 300.0, "hazard_windmill")
	await _shoot_at(6, 570.0, "hazard_sprinkler")
	await _shoot_at(7, 650.0, "hazard_geese")
	await _shoot_at(9, 2000.0, "hazard_boss_stage")


func _shoot_at(hole_index: int, x: float, shot_name: String) -> void:
	main.run.hole_index = hole_index
	main.load_current_hole()
	game().ball.place(x)
	game()._begin_aim()
	await _wait(1.0)
	await _save(shot_name)


func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["ok" if condition else "FAIL", label])


func _press_key(key: Key) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = is_pressed
		Input.parse_input_event(event)


func _press_button(button: JoyButton) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = is_pressed
		Input.parse_input_event(event)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(path)
	print("saved ", path)
