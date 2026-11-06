extends Node
## Plays the real scene and saves screenshots to tests/shots.
## Run with: Godot --path . --windowed --resolution 1280x720 --quit-after 40000 res://tests/shots.tscn

const OUT_DIR := "res://tests/shots"
const PROFILE_PATH := "user://shots_profile.json"

var main: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Clear out shots from earlier runs, so nothing stale gets reviewed.
	if DisplayServer.get_name() != "headless":
		for file_name in DirAccess.get_files_at(OUT_DIR):
			DirAccess.remove_absolute("%s/%s" % [OUT_DIR, file_name])
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	# These checks press keys faster than a person can.
	Controls.swing_gap_msec = 0
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
	await _test_rubber_ball()
	await _test_full_power()
	await _test_reactions()
	await _save_cup_closeup()
	await _test_landing_arrow()
	await _test_pause()
	await _test_out_of_strokes()
	await _test_duel()
	await _test_infinite()
	await _test_floating_isles()
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	print("shots finished")
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

	# The driver keeps the three-press swing. Two-press putting is in editor_check.
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
	# The hole skips are gone from the game: these keys must do nothing in a run.
	_press_key(KEY_PAGEUP)
	_press_key(KEY_PAGEDOWN)
	await _wait(0.2)
	_expect(main.run.hole_index == 1, "Page Up and Page Down no longer skip holes")
	_expect(not InputMap.has_action("review_next_hole"), "the skip keys aren't bound to anything")
	# The tests that follow are set on the first hole.
	main.run.hole_index = 0
	main.load_current_hole()
	await _wait(0.2)


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
	await _test_sticker_stacking(shop, run_state)
	await _test_shop_balls(shop, run_state)
	await _test_shop_reroll(shop, run_state)

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


# The arrow only appears with the perk, and goes with it.
func _test_landing_arrow() -> void:
	var run_state: RunState = main.run_state
	var was_on: Array[String] = run_state.perks.duplicate()
	main.load_current_hole()
	await _wait(0.3)
	_expect(not _find_aim_view().show_landing, "no landing arrow without the perk")
	run_state.perks.append("landing_arrow")
	main.load_current_hole()
	await _wait(1.0)
	_expect(_find_aim_view().show_landing, "the perk shows the landing arrow")
	# The iron, so that the landing is on screen for the picture.
	game().select_club(1)
	await _wait(0.2)
	await _save("perk_landing_arrow")
	run_state.perks = was_on
	main.load_current_hole()
	await _wait(0.3)


func _find_aim_view() -> AimView:
	for child in main._world.get_children():
		if child is AimView:
			return child
	return null


# Rerolls with real key presses, then puts things back as the rest of the checks expect them.
func _test_shop_reroll(shop: ShopScreen, run_state: RunState) -> void:
	var held_stock: Array[Dictionary] = shop.stock.duplicate()
	var held_coins: int = run_state.coins
	run_state.coins = 20
	shop.mode = ShopScreen.Mode.BROWSE
	shop.cursor = shop.stock.size()
	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_expect(shop.cursor == shop.stock.size() + 1, "Right from the leave button reaches the reroll")
	await _save("shop_08_reroll")
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(run_state.coins == 17 and run_state.reroll_price() == 6, "Space rerolls for 3, and the next costs 6")
	_expect(shop.sold.is_empty(), "and everything's in stock again")
	await _save("shop_09_after_reroll")
	run_state.coins = 2
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(run_state.coins == 2, "a reroll needs the coins")
	await _save("shop_10_cant_reroll")
	shop.stock = held_stock
	shop.sold.clear()
	shop.cursor = 0
	run_state.coins = held_coins
	run_state.begin_shop()
	await _wait(0.05)


# Buys more of a sticker already on a full club, with real key presses.
func _test_sticker_stacking(shop: ShopScreen, run_state: RunState) -> void:
	var stripe: Dictionary = Items.by_id("power_stripe")
	for expected: int in [2, 3]:
		shop.sold.clear()
		shop.cursor = 0
		_press_key(KEY_SPACE)
		await _wait(0.05)
		shop.club_cursor = 0
		await _wait(0.05)
		if expected == 2:
			await _save("shop_08_stack_prompt")
		_press_key(KEY_SPACE)
		await _wait(0.1)
		_expect(shop.mode == ShopScreen.Mode.BROWSE, "a match stacks without asking what to replace")
		_expect(run_state.sticker_count("driver", stripe) == expected, "making %d on the club" % expected)
	_expect(run_state.sticker_slots("driver").size() == RunState.STICKERS_PER_CLUB, "and they share one slot")
	await _save("shop_09_stacked")
	shop.sold.clear()
	shop.cursor = 0
	var coins_before: int = run_state.coins
	_press_key(KEY_SPACE)
	await _wait(0.05)
	shop.club_cursor = 0
	await _wait(0.05)
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.PICK_CLUB, "a complete stack refuses a fourth")
	_expect(run_state.coins == coins_before, "and charges nothing")
	await _save("shop_10_stack_complete")
	_press_key(KEY_ESCAPE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.BROWSE, "Esc backs out of it")


# Swaps balls and replaces one, with real key presses.
func _test_shop_balls(shop: ShopScreen, run_state: RunState) -> void:
	_expect(run_state.balls == ["", "skipper"], "bought balls go in with the plain one")
	shop.cursor = shop.stock.size()
	_press_key(KEY_DOWN)
	await _wait(0.05)
	_expect(shop.mode == ShopScreen.Mode.BALLS and shop.ball_cursor == 1, "Down from the leave button reaches the ball in play")
	_press_key(KEY_LEFT)
	await _wait(0.05)
	await _save("shop_06_balls")
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_expect(run_state.ball_id == "", "Space swaps to the selected ball")
	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_expect(run_state.ball_id == "skipper", "and back again")
	_press_key(KEY_UP)
	await _wait(0.05)
	_expect(shop.mode == ShopScreen.Mode.BROWSE and shop.cursor == shop.stock.size(), "Up leaves the balls")

	# All full, so a new one asks which to replace.
	run_state.balls.assign(["", "skipper", "wind_cutter"])
	shop.stock[2] = Items.by_id("sticky_ball")
	shop.sold.clear()
	shop.cursor = 2
	var coins_before: int = run_state.coins
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(shop.mode == ShopScreen.Mode.REPLACE_BALL and run_state.coins == coins_before, "a fourth ball asks what to replace")
	await _save("shop_07_replace_ball")
	_press_key(KEY_ESCAPE)
	await _wait(0.05)
	_expect(shop.mode == ShopScreen.Mode.BROWSE and main.pause_menu == null, "Esc cancels it")
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_press_key(KEY_RIGHT)
	await _wait(0.05)
	_press_key(KEY_SPACE)
	await _wait(0.1)
	_expect(run_state.balls == ["", "sticky_ball", "wind_cutter"], "the chosen ball is replaced")
	_expect(run_state.ball_id == "sticky_ball", "and the new one goes into play")
	shop.cursor = 0
	run_state.balls.assign([""])


# Lets the bar run to the top, with a power press too late that mustn't count as accuracy.
func _test_full_power() -> void:
	main.run.hole_index = 0
	main.load_current_hole()
	await _wait(0.4)
	_press_key(KEY_SPACE)
	while not game().meter.full_power:
		await get_tree().physics_frame
	await _wait(0.08)
	_press_key(KEY_SPACE)
	await _wait(0.05)
	_expect(game().phase == HoleGame.Phase.SWING and not game().meter.is_done(), "a late power press doesn't end the swing")
	await _save("full_power_01_meter")
	while game().meter.cursor > 0.0:
		await get_tree().physics_frame
	_press_key(KEY_SPACE)
	await _wait(0.4)
	_expect(game().last_quality == "FULL POWER!!", "the shot says FULL POWER!! (%s)" % game().last_quality)
	await _save("full_power_02_message")


# The cup from close up, scaled to see its pixels.
func _save_cup_closeup() -> void:
	if DisplayServer.get_name() == "headless":
		return
	main.run.hole_index = 0
	main.load_current_hole()
	var cup: Vector2 = Vector2(game().hole.cup_x, game().terrain.rim_y)
	game().start_from(cup.x - 26.0)
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	var at: Vector2 = get_viewport().get_canvas_transform() * cup
	var image: Image = get_viewport().get_texture().get_image()
	var region := Rect2i(int(at.x) - 50, int(at.y) - 45, 100, 65)
	var closeup: Image = image.get_region(region)
	closeup.resize(region.size.x * 8, region.size.y * 8, Image.INTERPOLATE_NEAREST)
	closeup.save_png("%s/cup_closeup.png" % OUT_DIR)


# A rubber ball squashes as it lands, then stretches as it springs back up.
func _test_rubber_ball() -> void:
	main.run_state.ball_id = "rubber_ball"
	main.run.hole_index = 0
	main.load_current_hole()
	await _wait(0.4)
	var ball: BallSim = game().ball
	_expect(ball.squash_scale > 0.0, "the hole starts with the rubber ball in play")
	ball.pos = Vector2(ball.pos.x + 60.0, ball.pos.y - 70.0)
	ball.launch(Vector2(25.0, 1.0), 0.0)
	game()._set_phase(HoleGame.Phase.BALL_MOVING)
	await ball.bounced
	await _save("rubber_01_squash")
	await _wait(0.07)
	await _save("rubber_02_stretch")
	while ball.is_moving():
		await get_tree().physics_frame
	_expect(ball.bounce_count >= 4, "a rubber ball bounces many times (%d)" % ball.bounce_count)
	main.run_state.ball_id = ""
	main.load_current_hole()
	await _wait(0.2)


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


# The golfer's moods, the music for each place, and what a clean strike sets off.
func _test_reactions() -> void:
	main.run.hole_index = 1
	main.load_current_hole()
	await _wait(0.6)
	_expect(Sound.current_music == "grassy", "Grassy Greens has its own music")
	var golfer: GolferView = _find_player_view()
	game().ball.state = BallSim.State.IN_WATER
	game()._on_ball_hazard(game().ball.pos, "water")
	await _wait(0.6)
	_expect(golfer._head_drop > 0.0, "the golfer hangs their head at a penalty")
	await _save("reaction_01_penalty")
	await _wait(HoleGame.PENALTY_TIME)
	_expect(golfer._head_drop == 0.0, "and looks up again for the next shot")

	game().select_club(0)
	game().strike_with(1.0, 0.0)
	await _wait(0.02)
	_expect(main._hit_stop > 0.0, "a full power strike holds the picture for a moment")
	await _wait(0.2)
	await _save("reaction_02_full_power_streak")
	_expect(game().phase == HoleGame.Phase.BALL_MOVING, "and the shot still carries on")

	# Holed from far away: the golfer jogs over and celebrates beside the cup.
	game().ball.state = BallSim.State.HOLED
	game().ball.pos = Vector2(game().hole.cup_x, game().terrain.rim_y)
	game()._on_ball_holed()
	await _wait(0.5)
	_expect(golfer.position.distance_to(Vector2(game().hole.cup_x, golfer.position.y)) <= GolferView.RUN_IN_DISTANCE, "the golfer is on the way to the cup")
	await _save("reaction_03_jogging_in")
	await _wait(1.8)
	_expect(absf(absf(golfer.position.x - game().hole.cup_x) - GolferView.CELEBRATE_GAP) <= 1.0, "and arrives beside it")
	_expect(golfer._cheering, "and celebrates")
	await _save("reaction_04_cheer")
	_press_key(KEY_SPACE)
	await _wait(0.6)
	_expect(main.shop != null, "the shop opens after the hole")
	_expect(Sound.current_music == "shop", "with its own tune")
	main._close_shop()
	main.load_current_hole()
	await _wait(0.6)


func _test_pause() -> void:
	# A hole's title on screen mustn't show through the pause menu.
	main.hud.show_message("A LONG MESSAGE ON SCREEN", 5.0)
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(main.pause_menu != null, "Esc pauses a run")
	_expect(main.hud.message_hidden, "the pause menu hides any message")
	await _save("run_pause")
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	await _wait(0.05)
	_expect(main.pause_menu.selected == PauseView.Item.MUSIC, "the pause menu reaches the music level")
	var music_before: int = Sound.music_level
	var settings_before: String = Sound.settings_path
	Sound.settings_path = "user://shots_settings.json"
	_press_key(KEY_RIGHT if music_before < Sound.LEVELS else KEY_LEFT)
	await _wait(0.05)
	_expect(Sound.music_level != music_before, "left and right change it")
	Sound.set_music_level(music_before)
	Sound.settings_path = settings_before
	DirAccess.remove_absolute("user://shots_settings.json")
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	await _wait(0.05)
	var time_before: float = game()._phase_time
	await _wait(0.2)
	_expect(game()._phase_time == time_before, "the game stops while paused")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(not main.hud.message_hidden, "and the message comes back after resuming")
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
	_expect(Sound.current_music == "", "the music stops for the final score")
	await _wait(main.run_over.reveal_time() + 0.2)
	await _save("run_over_out_of_strokes")
	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(main.run_over == null and main.run_state != run_state, "the final screen leads to a new run")
	_expect(main.run_state.spare == RunState.START_SPARE and main.run_state.coins == 0, "a new run starts fresh")


func _find_player_view() -> GolferView:
	for child in main._world.get_children():
		if child is GolferView and not child is RivalView:
			return child
	return null


func _find_rival_view() -> RivalView:
	for child in main._world.get_children():
		if child is RivalView:
			return child
	return null


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
	_expect(Sound.current_music == "boss", "the boss hole has its own tense music")
	var rival_view: RivalView = _find_rival_view()
	var player_view: GolferView = _find_player_view()
	_expect(not rival_view.visible, "the rival stays off screen during the player's turn")
	_expect(player_view.visible, "the player is on screen for their own turn")
	await _save("duel_01_tee")
	game().select_club(0)
	game().strike_with(0.85, 0.0)
	while game().phase == HoleGame.Phase.BALL_MOVING or game().phase == HoleGame.Phase.PENALTY:
		await get_tree().physics_frame
	_expect(game().phase == HoleGame.Phase.RIVAL_TURN, "the rival takes its turn")
	await _wait(0.5)
	_expect(rival_view.visible, "the rival appears for its own turn")
	_expect(not player_view.visible, "the player steps off screen during the rival's turn")
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
	_expect(not rival_view.visible, "and leaves again after it")
	_expect(player_view.visible, "and the player comes back")
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
	await _test_swamp_course()


# Rolls a real ball into a gator, through its open jaws, its flash and the penalty.
func _shoot_gator() -> void:
	main.run.hole_index = 6
	main.load_current_hole()
	var gator: GatorObstacle = null
	for obstacle in game().obstacles:
		if obstacle is GatorObstacle and gator == null:
			gator = obstacle
	var start_x: float = gator.x - 75.0
	game().ball.place(start_x)
	game()._begin_aim()
	await _wait(1.0)
	await _save("swamp_gator_shut")
	var strokes_before: int = game().strokes
	game()._last_spot_x = start_x
	game().strokes += 1
	game().ball.launch(Vector2(90.0, 0.0), 0.0)
	game()._set_phase(HoleGame.Phase.BALL_MOVING)
	while gator.jaw < 0.7 and not gator.eaten:
		await get_tree().physics_frame
	await _save("swamp_gator_open")
	while not gator.eaten:
		await get_tree().physics_frame
	await _wait(0.04)
	await _save("swamp_gator_flash")
	_expect(game().strokes == strokes_before + 2, "a gator costs a penalty stroke")
	_expect(game().ball.state == BallSim.State.EATEN, "and the ball's gone")
	await _wait(GatorObstacle.FLASH_TIME)
	_expect(gator.is_gone(), "then the gator's gone too")
	await _save("swamp_gator_gone")


# The win carries the run on into Swampy Shores, through to beating the second rival.
func _test_swamp_course() -> void:
	var run_state: RunState = main.run_state
	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(main.shop != null, "a shop follows the first rival")
	_expect(main.run_over == null, "and not the final score")
	await _save("swamp_00_shop")
	var spare_before: int = run_state.spare
	var coins_before: int = run_state.coins
	var finished_before: int = main.run.finished_holes()
	main.shop.done.emit()
	await _wait(0.5)
	_expect(game().hole.biome == HoleData.BIOME_SWAMP, "leaving it goes to Swampy Shores")
	_expect(main.run.hole_index == 0 and main.run.hole_count() == 10, "from its first hole")
	_expect(Sound.current_music == "swamp", "with its own music")
	_expect(run_state.spare == spare_before and run_state.coins == coins_before, "and everything carried over")
	_expect(main.run.finished_holes() == finished_before, "the totals carry on too")
	await _save("swamp_01_welcome")
	for i in main.run.hole_count():
		await _shoot_hole(i, "swamp_hole_%02d" % (i + 1))

	# The hazards, up close.
	await _shoot_at(0, 760.0, "swamp_mud")
	await _shoot_at(1, 290.0, "swamp_lily")
	await _shoot_at(2, 500.0, "swamp_frog")
	await _shoot_at(4, 430.0, "swamp_windmill")
	await _shoot_gator()
	main.run.hole_index = 3
	main.load_current_hole()
	var vent: VentObstacle = null
	for obstacle in game().obstacles:
		if obstacle is VentObstacle and vent == null:
			vent = obstacle
	game().ball.place(vent.x - 60.0)
	game()._begin_aim()
	await _wait(0.6)
	while vent.stage() != VentObstacle.Stage.WARNING:
		await get_tree().physics_frame
	await _wait(0.5)
	await _save("swamp_vent_warning")
	while vent.stage() != VentObstacle.Stage.BURST:
		await get_tree().physics_frame
	await _wait(0.3)
	await _save("swamp_vent_burst")

	main.run.hole_index = main.run.hole_count() - 1
	main.load_current_hole()
	await _wait(0.5)
	var rival: Rival = game().rival
	_expect(rival != null, "the swamp ends on a duel")
	_expect(Sound.current_music == "swamp_boss", "with its own frantic music")
	_expect(rival._cheats_left == Rival.CHEATS_PER_HOLE, "the rival only gets two cheats")
	_expect(rival._miss_chance < Rival.MISS_CHANCE, "but plays better than last time")
	await _save("swamp_boss_tee")
	game().select_club(1)
	game().strike_with(0.5, 0.0)
	while game().phase != HoleGame.Phase.RIVAL_TURN:
		await get_tree().physics_frame
	await _wait(0.6)
	await _save("swamp_boss_rival")
	while game().phase != HoleGame.Phase.AIM and game().phase != HoleGame.Phase.COMPLETE:
		await get_tree().physics_frame
	game().ball.state = BallSim.State.HOLED
	game().player_holed = true
	rival.holed = false
	rival.strokes = 99
	game()._settle_duel()
	await _wait(0.4)
	_expect(run_state.ending == RunState.Ending.BEAT_RIVAL, "beating it ends the run with a win")
	await _save("swamp_boss_result")
	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(main.run_over != null, "the second duel leads to the final score")
	await _wait(main.run_over.reveal_time() + 0.2)
	_expect(main.run_over.is_revealed(), "the final score finishes reading itself out")
	await _save("run_over_duel")


# Looks along a map, falls off it for real, finishes it, then tries again on a new one.
func _test_floating_isles() -> void:
	var profile: Profile = main.profile
	remove_child(main)
	main.queue_free()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.profile = profile
	main.floating_isles = true
	add_child(main)
	await _wait(0.8)
	await _save("isles_01_tee")
	_expect(main.run_state == null, "Floating Isles has no shop, coins or budget")
	_expect(game().distance_to_cup() == 12000.0, "the pin starts 4000 yards away")
	var hole: HoleData = game().hole

	game().select_club(1)
	game().strike_with(1.0, 0.0)
	await _wait(1.5)
	await _save("isles_02_flight")
	var steps: int = 0
	while game().phase == HoleGame.Phase.BALL_MOVING and steps < 400:
		await _wait(0.05)
		steps += 1

	for spot: float in [0.25, 0.5]:
		game().start_from(hole.tee_x + 12000.0 * spot)
		await _wait(0.9)
		await _save("isles_03_middle_%d" % int(spot * 100.0))

	# Off the far side of whichever island this is, for a fall that's certainly a fall.
	game().start_from(hole.cup_x + IslesGenerator.CUP_ISLAND_HALF - 8.0)
	game().facing = 1
	var strokes_before: int = game().strokes
	game().select_club(1)
	game().strike_with(0.5, 0.0)
	await _wait(1.2)
	await _save("isles_04_falling")
	steps = 0
	while game().phase != HoleGame.Phase.PENALTY and steps < 200:
		await _wait(0.05)
		steps += 1
	await _wait(0.1)
	await _save("isles_05_fell")
	_expect(game().falls >= 1, "going off the end counts as a fall")
	steps = 0
	while game().phase != HoleGame.Phase.AIM and steps < 200:
		await _wait(0.05)
		steps += 1
	_expect(game().strokes == strokes_before + 1, "the fall adds nothing but the stroke that caused it")
	_expect(is_equal_approx(game().ball.pos.x, hole.tee_x), "the fall returns the ball to the tee")
	await _wait(1.0)
	await _save("isles_06_back_at_tee")

	# Reach the checkpoint with a real shot, then fall and come back to it.
	_expect(not game().checkpoint_reached, "the checkpoint starts out unreached")
	var checkpoint_spot: float = hole.checkpoint_x - HoleGame.CHECKPOINT_STAND_OFF
	game().start_from(checkpoint_spot)
	await _wait(0.9)
	await _save("isles_06a_checkpoint_ahead")
	game().select_club(2)
	game().strike_with(0.02, 0.0)
	steps = 0
	while game().phase != HoleGame.Phase.AIM and steps < 200:
		await _wait(0.05)
		steps += 1
	await _wait(0.2)
	_expect(game().checkpoint_reached, "coming to rest on its island reaches the checkpoint")
	await _save("isles_06b_checkpoint_reached")
	game().start_from(hole.cup_x + IslesGenerator.CUP_ISLAND_HALF - 8.0)
	game().facing = 1
	game().select_club(1)
	game().strike_with(0.5, 0.0)
	steps = 0
	while game().phase != HoleGame.Phase.PENALTY and steps < 200:
		await _wait(0.05)
		steps += 1
	await _wait(0.1)
	await _save("isles_06c_fell_to_checkpoint")
	steps = 0
	while game().phase != HoleGame.Phase.AIM and steps < 200:
		await _wait(0.05)
		steps += 1
	_expect(is_equal_approx(game().ball.pos.x, checkpoint_spot), "after that a fall returns to the checkpoint")
	await _wait(1.0)
	await _save("isles_06d_back_at_checkpoint")

	game().start_from(hole.cup_x - 90.0)
	await _wait(0.8)
	await _save("isles_07_green")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_expect(main.pause_menu != null, "Esc pauses Floating Isles")
	await _save("isles_08_pause")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)

	var scores_before: int = profile.isles_table(4000).size()
	var finished_strokes: int = game().strokes
	game().ball.pos = Vector2(hole.cup_x, game().terrain.rim_y)
	game().ball.state = BallSim.State.HOLED
	game().ball.holed.emit()
	await _wait(0.1)
	var isles_golfer: GolferView = null
	for child in main._world.get_children():
		if child is GolferView and not child is RivalView:
			isles_golfer = child
	_expect(absf(absf(isles_golfer.position.x - hole.cup_x) - GolferView.CELEBRATE_GAP) < 1.0, "the golfer appears right beside the cup")
	await _wait(0.5)
	await _save("isles_09_holed")
	await _wait(1.3)
	_expect(main.isles_finish != null, "reaching the hole brings up the finish screen")
	_expect(profile.isles_table(4000).size() == scores_before + 1, "and the crossing goes on the leaderboard")
	_expect(int(profile.isles_table(4000)[0]["strokes"]) == finished_strokes, "with its strokes")
	await _wait(0.3)
	await _save("isles_10_finish")

	_press_key(KEY_SPACE)
	await _wait(0.8)
	_expect(main.isles_finish == null, "Try Again closes the finish screen")
	_expect(game().strokes == 0 and game().falls == 0, "and starts afresh")
	_expect(game().hole.points != hole.points, "on a new map")
	await _save("isles_11_try_again")

	main.isles_yards = 1000
	main._begin_isles()
	await _wait(0.8)
	_expect(is_equal_approx(game().distance_to_cup(), 3000.0), "a 1000 yard course is 1000 yards")
	await _save("isles_12_short_course")


# Beats a boss for real, goes through the shop into a harder set, then loses the next duel.
func _test_infinite() -> void:
	var profile: Profile = main.profile
	var scores_before: int = profile.high_scores.size()
	remove_child(main)
	main.queue_free()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.profile = profile
	main.infinite = true
	main.infinite_seed = 7
	add_child(main)
	await _wait(0.5)
	var run_state: RunState = main.run_state
	_expect(run_state.infinite and run_state.level == 0, "an infinite run starts at the lowest difficulty")
	_expect(main.run.hole_count() == HoleGenerator.HOLES_PER_SET + 1, "with nine holes and a boss")
	await _shoot_generated(0)

	# A hole played on the way, so totals have something to carry.
	main.run.hole_index = 0
	run_state.finish_hole(main.run.current_hole().par - 1)
	main.run.hole_index = main.run.hole_count() - 1
	main.load_current_hole()
	await _wait(0.5)
	_expect(game().rival != null, "the set ends on a duel")
	var spare_before: int = run_state.spare
	var coins_before: int = run_state.coins
	await _save("infinite_01_boss")
	# Sinks the player's ball where it lies, so the duel is won.
	game().ball.state = BallSim.State.HOLED
	game().player_holed = true
	game().rival.strokes = 99
	game().strokes = 3
	game()._settle_duel()
	await _wait(0.5)
	_expect(game().duel_won, "the duel is won")
	_expect(run_state.ending == RunState.Ending.NONE, "beating the boss doesn't end the run")
	_expect(run_state.level == 1 and run_state.set_number == 2, "the difficulty goes up")
	var par: int = main.run.current_hole().par
	var banked: int = spare_before + (par - 3) + Difficulty.boss_reward(0)
	_expect(run_state.spare == RunState.START_SPARE, "spare strokes go back to the start")
	_expect(run_state.coins == coins_before + run_state.hole_payout(run_state.course.hole_index, 3, par) + banked / 2, "and the banked strokes pay coins")
	_expect(profile.rival_beaten, "the win counts on the profile")
	await _save("infinite_02_boss_beaten")

	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(main.shop != null, "a shop follows the boss")
	_expect(main.run_over == null, "and not the final score")
	await _save("infinite_03_shop_after_boss")
	var to_par: int = main.run.total_to_par()
	var finished: int = main.run.finished_holes()
	var old_run: CourseRun = main.run
	main.shop.done.emit()
	await _wait(0.5)
	_expect(main.run != old_run, "leaving the shop starts a new set")
	_expect(main.run.hole_index == 0 and main.run.scores.is_empty(), "from its first hole")
	_expect(run_state.course == main.run, "and the run moves on to it")
	_expect(main.run.total_to_par() == to_par and main.run.finished_holes() == finished, "with the totals carried over")
	_expect(game().stroke_limit == run_state.stroke_limit(game().hole.par), "and the budget still applies")
	await _save("infinite_04_second_set")
	await _shoot_generated(10)

	# Losing the second duel ends the run, at the new difficulty.
	main.run = main.run.next_set(HoleGenerator.generate_set(main._hole_rng, run_state.level))
	run_state.course = main.run
	main.run.hole_index = main.run.hole_count() - 1
	main.load_current_hole()
	await _wait(0.5)
	var rival: Rival = game().rival
	_expect(is_equal_approx(rival._miss_chance, Difficulty.rival_miss_chance(1)), "the rival plays at the run's difficulty")
	_expect(rival._power_steps == Difficulty.rival_power_steps(1), "and plans at it too")
	game()._finish_duel(false)
	await _wait(0.5)
	_expect(run_state.ending == RunState.Ending.LOST_TO_RIVAL, "losing a duel ends the run")
	_press_key(KEY_SPACE)
	await _wait(0.5)
	_expect(main.run_over != null, "and shows the final score")
	await _wait(main.run_over.reveal_time() + 0.2)
	await _save("infinite_05_final_score")
	_expect(profile.infinite_scores.size() == 1, "the run goes in its own table")
	_expect(profile.high_scores.size() == scores_before, "and not the main game's")


# Overviews of generated holes, to judge how they look. Each is from a fresh set at this level.
func _shoot_generated(level: int) -> void:
	var run_state: RunState = main.run_state
	var before: CourseRun = main.run
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + level
	main.run = CourseRun.from_holes(HoleGenerator.generate_set(rng, level))
	run_state.course = main.run
	for index: int in [0, 1, 4, 8, 9]:
		await _shoot_hole(index, "gen_level%02d_hole%02d" % [level, index + 1])
	main.run = before
	run_state.course = before
	main.run.hole_index = 0
	main.load_current_hole()
	await _wait(0.3)


# Saves a zoomed-out view of the whole hole, then the view from the tee.
func _shoot_hole(index: int, label: String = "") -> void:
	main.run.hole_index = index
	main.load_current_hole()
	await _wait(0.5)
	if label == "":
		label = "hole_%02d" % (index + 1)
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
	# With no window there's nothing to save, but every other check still runs.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(path)
	print("saved ", path)
