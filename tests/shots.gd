extends Node
## Plays the real scene and saves screenshots to tests/shots.
## Run with: Godot --path . --windowed --resolution 1280x720 res://tests/shots.tscn

const OUT_DIR := "res://tests/shots"

var main: Node2D
var game: HoleGame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	game = main.game
	_run()


func _run() -> void:
	await _wait(0.7)
	_expect(not main.camera.is_free_looking(), "not free looking at the tee")
	await _save("01_tee")

	# These presses go through the real input system: keyboard, then controller.
	_press_key(KEY_E)
	await _wait(0.05)
	_expect(game.current_club().id == "iron", "E selects the next club")
	_press_key(KEY_1)
	await _wait(0.05)
	_expect(game.current_club().id == "driver", "1 selects the driver")
	_press_key(KEY_W)
	await _wait(0.05)
	_expect(game.spin == 1, "W adds topspin")
	_press_key(KEY_S)
	await _wait(0.05)
	_expect(game.spin == 0, "S takes it back off")

	_press_key(KEY_F)
	await _wait(0.4)
	await _save("01b_flipped")
	_press_key(KEY_F)
	await _wait(0.1)

	_press_key(KEY_SPACE)
	await _wait(0.75)
	_expect(game.phase == HoleGame.Phase.SWING, "Space starts the swing")
	await _save("02_power_rising")
	_press_button(JOY_BUTTON_A)
	await _wait(0.35)
	_expect(game.meter.stage == SwingMeter.Stage.RETURNING, "controller A sets power")
	await _save("03_returning")
	while game.meter.cursor > 0.0:
		await get_tree().physics_frame
	_press_key(KEY_SPACE)
	await _wait(0.9)
	_expect(game.strokes == 1, "the third press hits the ball")
	await _save("04_flight")
	await _wait_until_aim()
	await _save("05_landed")

	# Look over the course without moving the ball.
	Input.action_press("look_right")
	await _wait(1.4)
	await _save("06_free_look_pond")
	await _wait(1.3)
	await _save("07_free_look_green")
	Input.action_release("look_right")
	main.camera.look_offset = 0.0
	await _wait(0.5)

	game.ball.place(950.0)
	game.club_index = 1
	game.strike_with(0.3, 0.0)
	await _wait(0.72)
	await _save("08_water")
	await _wait_until_aim()

	game.ball.place(680.0)
	await _wait(0.5)
	await _save("09_sand")

	game.ball.place(1380.0)
	game._begin_aim()
	await _wait(0.7)
	await _save("10_putt")
	game.select_club(2)
	var sim_power: float = _power_to_hole()
	game.strike_with(sim_power, 0.0)
	while game.phase != HoleGame.Phase.COMPLETE:
		await get_tree().physics_frame
	await _wait(0.35)
	await _save("11_complete")
	get_tree().quit()


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


func _power_to_hole() -> float:
	for i in range(1, 101):
		var power: float = float(i) * 0.01
		var sim := BallSim.new(game.terrain)
		sim.place(game.ball.pos.x)
		var shot: Dictionary = ShotCalc.compute(game.current_club(), power, 0.0, 0, game.facing, 1.0)
		sim.launch(shot["velocity"], 0.0)
		var guard: int = 0
		while sim.is_moving() and guard < 4000:
			sim.step(1.0 / 60.0)
			guard += 1
		if sim.state == BallSim.State.HOLED:
			return power
	return 0.5


func _wait_until_aim() -> void:
	while game.phase != HoleGame.Phase.AIM:
		await get_tree().physics_frame
	await _wait(0.6)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(path)
	print("saved ", path)
