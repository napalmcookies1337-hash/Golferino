extends Node
## Plays the real scene and saves screenshots to tests/shots.
## Run with: Godot --path . --windowed --resolution 1280x720 res://tests/shots.tscn

const OUT_DIR := "res://tests/shots"
const PROFILE_PATH := "user://shots_profile.json"

var main: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Clear out shots from earlier runs, so nothing stale gets reviewed.
	for file_name in DirAccess.get_files_at(OUT_DIR):
		DirAccess.remove_absolute("%s/%s" % [OUT_DIR, file_name])
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.profile = Profile.new(PROFILE_PATH)
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
	await _test_coin_and_card()
	await _test_pause()
	await _test_out_of_strokes()
	await _test_duel()
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
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
	_press_key(KEY_F)
	await _wait(0.8)
	_expect(game().facing == -1, "F flips the golfer")
	await _save("00_flipped")
	_press_button(JOY_BUTTON_X)
	await _wait(0.05)
	_expect(game().facing == 1, "controller X flips the golfer back")

	# The driver keeps the three-press swing. One-press putting is in editor_check.
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
	_expect(main.run_state.coins > 0, "finishing a hole pays coins")

	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(main.shop != null, "Space goes to the shop")
	await _test_shop()
	_expect(main.run.hole_index == 1, "leaving the shop moves on to the next hole")
	_expect(game().hole.display_name == "HOLE 2", "the new hole is loaded")
	await _save("00_next_hole_title")
	_press_key(KEY_PAGEUP)
	await _wait(0.2)
	_expect(main.run.hole_index == 0, "Page Up reviews the previous hole")


# Buys things with real key presses, through to a full club.
func _test_shop() -> void:
	var shop: ShopScreen = main.shop
	var run_state: RunState = main.run_state
	# A known stock, so every step below is certain to apply.
	shop.stock.assign([Items.by_id("power_stripe"), Items.by_id("long_roll"), Items.by_id("skipper"), Items.by_id("spare_strokes")])
	await _wait(0.1)
	await _save("shop_01_browse")
	run_state.coins = 200

	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.PICK_CLUB, "buying a sticker asks which club")
	await _save("shop_02_pick_club")
	_press_key(KEY_ESCAPE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.BROWSE and main.pause_menu == null, "Esc cancels the sticker, not the shop")
	_expect(run_state.coins == 200, "cancelling costs nothing")

	_press_key(KEY_SPACE)
	await _wait(0.05)
	_press_key(KEY_DOWN)
	await _wait(0.05)
	_expect(shop.club_cursor == 1, "Down picks the next club")
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect((run_state.stickers["iron"] as Array).has("power_stripe"), "Space puts the sticker on that club")
	_expect(run_state.coins == 200 - RunState.START_PRICE, "the sticker is paid for at the first shop's price")
	_expect(shop.sold.has(0) and shop.mode == ShopScreen.Mode.BROWSE, "the sticker sells out")
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_expect((run_state.stickers["iron"] as Array).size() == 1, "a sold item can't be bought again")

	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_expect(shop.cursor == 2, "Right moves along the shelf")
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_expect(run_state.ball_id == "skipper", "Space buys a ball straight away")
	_press_button(JOY_BUTTON_DPAD_RIGHT)
	await _wait(0.05)
	var spare_before: int = run_state.spare
	_press_button(JOY_BUTTON_A)
	await _wait(0.05)
	_expect(run_state.spare == spare_before + 2, "the controller works in the shop")

	# Fills a club, then replaces a sticker.
	run_state.stickers["driver"] = ["sweet_tape", "spin_doctor", "wide_angle"]
	shop.sold.clear()
	shop.cursor = 0
	_press_key(KEY_SPACE)
	await _wait(0.05)
	shop.club_cursor = 0
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.PICK_SLOT, "a full club asks which sticker to replace")
	await _save("shop_03_replace")
	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(run_state.stickers["driver"] == ["sweet_tape", "power_stripe", "wide_angle"], "the chosen sticker is replaced")
	await _save("shop_04_after_buying")

	_press_key(KEY_TAB)
	await _wait(0.1)
	_expect(shop.show_card, "Tab shows the scorecard in the shop")
	await _save("shop_05_scorecard")
	_press_key(KEY_TAB)
	await _wait(0.05)

	_press_key(KEY_DOWN)
	await _wait(0.05)
	_expect(shop.cursor == shop.stock.size(), "Down goes to the leave button")
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(main.shop == null, "the shop closes")
	# A clean bag for the rest of the checks.
	run_state.stickers = { "driver": [], "iron": [], "putter": [] }
	run_state.ball_id = ""


func _test_coin_and_card() -> void:
	main.run.hole_index = 0
	main.load_current_hole()
	await _wait(0.4)
	var coin: CoinObstacle = _first_coin()
	_expect(coin != null, "the hole has coins")
	var coins_before: int = main.run_state.coins
	var camera: FollowCamera = main.camera
	game().ball.place(coin.at.x - 90.0)
	game()._begin_aim()
	await _wait(0.8)
	await _save("run_coins_on_course")
	game().ball.pos = coin.at - Vector2(30, 0)
	game().ball.launch(Vector2(120, -1), 0.0)
	game()._set_phase(HoleGame.Phase.BALL_MOVING)
	await _wait(0.5)
	_expect(main.run_state.coins == coins_before + 1, "flying through a coin collects it")
	_expect(coin.collected, "a collected coin disappears")
	while game().phase == HoleGame.Phase.BALL_MOVING:
		await get_tree().physics_frame
	_expect(camera != null, "the hole carries on after a coin")
	_press_key(KEY_TAB)
	await _wait(0.1)
	_expect(main.hud.show_card, "Tab shows the scorecard")
	await _save("run_scorecard_in_play")
	_press_key(KEY_TAB)
	await _wait(0.1)
	_press_key(KEY_R)
	await _wait(0.1)
	_expect(game().ball.pos.x != game().hole.tee_x, "R doesn't restart a real run")


func _first_coin() -> CoinObstacle:
	for obstacle in game().obstacles:
		if obstacle is CoinObstacle:
			return obstacle
	return null


func _test_pause() -> void:
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(main.pause_menu != null, "Esc pauses a run")
	await _save("run_pause")
	var time_before: float = game()._phase_time
	await _wait(0.2)
	_expect(game()._phase_time == time_before, "the game stops while paused")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(main.pause_menu == null, "Esc resumes")


func _test_out_of_strokes() -> void:
	main.run.hole_index = 1
	main.load_current_hole()
	await _wait(0.3)
	var run_state: RunState = main.run_state
	run_state.spare = 0
	game().stroke_limit = run_state.stroke_limit(game().hole.par)
	game().strokes = game().stroke_limit - 1
	await _wait(0.1)
	await _save("run_last_stroke")
	game().select_club(1)
	game().strike_with(0.15, 0.0)
	while game().phase == HoleGame.Phase.BALL_MOVING:
		await get_tree().physics_frame
	await _wait(0.2)
	_expect(game().phase == HoleGame.Phase.OUT_OF_STROKES, "the last stroke missing runs out of strokes")
	await _save("run_out_of_strokes")
	await _wait(2.2)
	_expect(main.run_over != null, "running out ends the run")
	await _save("run_over_out_of_strokes")
	await _wait(0.5)
	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(main.run_over == null and main.run_state != run_state, "the final screen leads to a new run")
	_expect(main.run_state.spare == RunState.START_SPARE and main.run_state.coins == 0, "a new run starts fresh")


# Plays the boss hole with both sides, watching the rival's turn and how it ends.
func _test_duel() -> void:
	var run_state: RunState = main.run_state
	# A convincing card, so the final score has something to show.
	for i in main.run.hole_count() - 1:
		main.run.hole_index = i
		run_state.finish_hole(main.run.current_hole().par - (i % 2))
	run_state.coins += 23
	main.run.hole_index = main.run.hole_count() - 1
	main.load_current_hole()
	await _wait(0.5)
	var rival: Rival = game().rival
	_expect(rival != null, "the last hole brings out the rival")
	await _save("duel_01_tee")
	game().select_club(0)
	game().strike_with(0.85, 0.0)
	while game().phase == HoleGame.Phase.BALL_MOVING or game().phase == HoleGame.Phase.PENALTY:
		await get_tree().physics_frame
	_expect(game().phase == HoleGame.Phase.RIVAL_TURN, "the rival takes its turn")
	await _wait(0.5)
	await _save("duel_02_rival_thinking")
	while rival.stage == Rival.Stage.THINKING:
		await get_tree().physics_frame
	await _wait(0.2)
	await _save("duel_03_rival_swing")
	await _wait(0.8)
	await _save("duel_04_rival_ball_flying")
	while game().phase == HoleGame.Phase.RIVAL_TURN:
		await get_tree().physics_frame
	_expect(game().phase == HoleGame.Phase.AIM, "then it's the player's turn")
	await _wait(0.6)
	await _save("duel_05_your_turn")
	_expect(rival.strokes >= 1, "the rival has played")

	# The next rival turn is an even one, so it cheats.
	game().select_club(1)
	game().strike_with(0.2, 0.0)
	var saw_cheat: bool = false
	var guard: int = 0
	while game().phase != HoleGame.Phase.AIM and game().phase != HoleGame.Phase.COMPLETE and guard < 3000:
		if rival.stage == Rival.Stage.CHEATING and not saw_cheat:
			saw_cheat = true
			await _wait(0.3)
			await _save("duel_06_rival_cheats")
		await get_tree().physics_frame
		guard += 1
	_expect(saw_cheat or rival.holed, "the rival cheats on its second turn")

	# Ends it by holing the player's ball on the spot.
	while game().phase != HoleGame.Phase.AIM and game().phase != HoleGame.Phase.COMPLETE:
		await get_tree().physics_frame
	if game().phase == HoleGame.Phase.AIM:
		game().ball.state = BallSim.State.HOLED
		game().player_holed = true
		rival.holed = false
		rival.strokes = 99
		game()._settle_duel()
	await _wait(0.4)
	_expect(game().phase == HoleGame.Phase.COMPLETE, "the duel ends the hole")
	await _save("duel_07_result")
	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(main.run_over != null, "the duel leads to the final score")
	await _save("run_over_duel")


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
	var mill_x: float = float(main.run.hole_at(5).obstacles[0]["x"])
	await _shoot_at(5, mill_x, "hazard_windmill_door")
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
