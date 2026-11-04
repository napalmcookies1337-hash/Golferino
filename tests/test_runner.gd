extends Node
## Rules tests. Run with: Godot --headless --path . res://tests/test_runner.tscn

const DT := 1.0 / 60.0
const HOLE_PATH := "res://data/holes/hole_01.tres"
const COURSE_PATH := "res://data/course_01.tres"

var _passed: int = 0
var _failed: int = 0
var _round_events: Dictionary = {}


func _ready() -> void:
	_test_meter_flow()
	_test_meter_accuracy()
	_test_meter_auto_limits()
	_test_shot_quality_effects()
	_test_power_scales_distance()
	_test_lie_reduces_distance()
	_test_terrain_lookups()
	_test_ball_rests_on_flat()
	_test_ball_rolls_off_steep_slope()
	_test_spin_changes_landing()
	_test_sand_stops_ball()
	_test_water_penalty_flow()
	_test_cup_captures_slow_putt()
	_test_cup_rejects_fast_putt()
	_test_out_of_bounds()
	_test_three_click_through_game()
	_test_score_names()
	_test_auto_club_on_green()
	_test_auto_club_in_sand()
	_test_club_ranges()
	_test_aim_angle_rules()
	_test_aim_angle_changes_shot()
	_test_aim_bindings()
	_test_flip()
	_test_short_shot_return()
	_test_lie_effects()
	_test_spin_needs_clean_strike()
	_test_slope_tilts_launch()
	_test_landing_slope_changes_run()
	_test_steep_landing_stops_sooner()
	_test_ball_settles_in_bowl()
	_test_pin_hit()
	_test_bot_finishes_hole()
	_test_imperfect_player_scores()
	_test_no_spot_is_a_trap()
	_test_trees_are_scenery()
	_test_putting_is_one_press()
	_test_aim_line_is_for_full_swings()
	_test_tree_pieces()
	_test_bounce_pads()
	_test_pads_never_fire_into_water()
	_test_rotated_hazards()
	_test_hole_files()
	_test_map_library()
	_test_editor_ground_and_paint()
	_test_editor_objects()
	_test_editor_undo()
	_test_ball_against_a_post_can_escape()
	_test_plays_away_when_blocked()
	_test_cart()
	_test_windmill()
	_test_sprinkler()
	_test_goose()
	_test_wind()
	_test_preview_ignores_moving_hazards()
	_test_course_progression()
	_test_every_hole_is_valid()
	_test_every_hole_is_playable()
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _clubs() -> Array[ClubData]:
	var clubs: Array[ClubData] = []
	for club_id: String in ["driver", "iron", "putter"]:
		clubs.append(load("res://data/clubs/%s.tres" % club_id) as ClubData)
	return clubs


func _club(club_id: String) -> ClubData:
	return load("res://data/clubs/%s.tres" % club_id) as ClubData


func _game() -> HoleGame:
	return HoleGame.new(load(HOLE_PATH) as HoleData, _clubs())


func _flat_hole(extra: Dictionary = {}) -> HoleData:
	var hole := HoleData.new()
	hole.par = 4
	hole.tee_x = 100.0
	hole.cup_x = float(extra.get("cup_x", 900.0))
	hole.points = PackedVector2Array([Vector2(0, 300), Vector2(500, 300), Vector2(1000, 300)])
	hole.surface_spans = extra.get("spans", [{ "from": 0, "to": 1000, "type": Surface.Type.FAIRWAY }])
	hole.water_spans = extra.get("water", [])
	return hole


func _run_to_stop(sim: BallSim) -> void:
	var guard: int = 0
	while sim.is_moving() and guard < 4000:
		sim.step(DT)
		guard += 1


# Steps a whole shot and returns how far along x it finished.
func _shot_distance(club_id: String, power: float, accuracy: float, spin: int) -> float:
	var terrain := Terrain.new(_flat_hole({ "cup_x": 990.0 }))
	var sim := BallSim.new(terrain)
	sim.place(20.0)
	var shot: Dictionary = ShotCalc.compute(_club(club_id), power, accuracy, spin, 1, 1.0)
	sim.launch(shot["velocity"], float(shot["spin"]))
	_run_to_stop(sim)
	return sim.pos.x - 20.0


func _test_meter_flow() -> void:
	var meter := SwingMeter.new()
	_check(meter.stage == SwingMeter.Stage.IDLE, "meter starts idle")
	meter.press()
	_check(meter.stage == SwingMeter.Stage.RISING, "press 1 starts the rise")
	for _i in 30:
		meter.tick(DT)
	var at_press: float = meter.cursor
	meter.press()
	_check(meter.stage == SwingMeter.Stage.RETURNING, "press 2 begins the return")
	_check(is_equal_approx(meter.power, at_press), "press 2 locks power at the cursor")
	while meter.cursor > 0.0:
		meter.tick(DT)
	meter.press()
	_check(meter.is_done(), "press 3 finishes")


func _test_meter_accuracy() -> void:
	_check(SwingMeter.accuracy_for_cursor(0.0) == 0.0, "dead centre is perfect")
	_check(SwingMeter.accuracy_for_cursor(0.03) == 0.0, "inside window is perfect")
	_check(SwingMeter.accuracy_for_cursor(0.15) > 0.0, "before sweet spot is early")
	_check(SwingMeter.accuracy_for_cursor(-0.1) < 0.0, "after sweet spot is late")
	_check(SwingMeter.accuracy_for_cursor(-0.18) == -1.0, "far end is the worst late miss")
	_check(SwingMeter.accuracy_for_cursor(0.9) == 1.0, "very early caps at 1")


func _test_meter_auto_limits() -> void:
	var meter := SwingMeter.new()
	meter.press()
	for _i in 200:
		meter.tick(DT)
	_check(is_equal_approx(meter.power, 1.0), "ignoring press 2 gives full power")
	_check(meter.is_done(), "ignoring press 3 ends the swing")
	_check(meter.accuracy == -1.0, "ignoring press 3 is the worst late miss")


func _test_shot_quality_effects() -> void:
	var driver: ClubData = _club("driver")
	var perfect: Dictionary = ShotCalc.compute(driver, 1.0, 0.0, 0, 1, 1.0)
	var early: Dictionary = ShotCalc.compute(driver, 1.0, 1.0, 0, 1, 1.0)
	var late: Dictionary = ShotCalc.compute(driver, 1.0, -1.0, 0, 1, 1.0)
	var perfect_v: Vector2 = perfect["velocity"]
	var early_v: Vector2 = early["velocity"]
	var late_v: Vector2 = late["velocity"]
	_check(_elevation(early_v) > _elevation(perfect_v), "early miss launches higher")
	_check(early_v.length() < perfect_v.length(), "early miss loses speed")
	_check(_elevation(late_v) < _elevation(perfect_v), "late miss launches lower")
	_check(perfect["quality"] == "PERFECT!", "perfect is named")
	_check(early["quality"] == "POP-UP", "early is named")
	_check(late["quality"] == "LOW AND HOT", "late is named")
	_check(_shot_distance("driver", 1.0, 1.0, 0) < _shot_distance("driver", 1.0, 0.0, 0), "pop-up is short")

	var left: Dictionary = ShotCalc.compute(driver, 1.0, 0.0, 0, -1, 1.0)
	_check(Vector2(left["velocity"]).x < 0.0, "facing left hits left")

	var putt_v: Vector2 = ShotCalc.compute(_club("putter"), 1.0, 0.0, 0, 1, 1.0)["velocity"]
	_check(is_zero_approx(putt_v.y), "putts stay on the ground")
	_check(int(ShotCalc.compute(_club("putter"), 1.0, 0.0, -1, 1, 1.0)["spin"]) == 0, "putts ignore spin")


func _elevation(velocity: Vector2) -> float:
	return atan2(-velocity.y, absf(velocity.x))


func _test_power_scales_distance() -> void:
	var full: float = _shot_distance("iron", 1.0, 0.0, 0)
	var half: float = _shot_distance("iron", 0.5, 0.0, 0)
	_check(half > full * 0.4 and half < full * 0.6, "half power goes about half as far (%.0f of %.0f)" % [half, full])


func _test_lie_reduces_distance() -> void:
	var clean: Vector2 = ShotCalc.compute(_club("iron"), 1.0, 0.0, 0, 1, 1.0)["velocity"]
	var sand: Vector2 = ShotCalc.compute(_club("iron"), 1.0, 0.0, 0, 1, 0.6)["velocity"]
	_check(sand.length() < clean.length(), "bad lie reduces launch speed")


func _test_terrain_lookups() -> void:
	var terrain := Terrain.new(load(HOLE_PATH) as HoleData)
	_check(terrain.surface_at(90.0) == Surface.Type.TEE, "tee surface")
	_check(terrain.surface_at(300.0) == Surface.Type.FAIRWAY, "fairway surface")
	_check(terrain.surface_at(670.0) == Surface.Type.SAND, "sand surface")
	_check(terrain.surface_at(1050.0) == Surface.Type.WATER, "water surface")
	_check(terrain.surface_at(1440.0) == Surface.Type.GREEN, "green surface")
	_check(terrain.surface_at(1650.0) == Surface.Type.ROUGH, "unlisted ground is rough")
	_check(terrain.in_cup(1440.0) and not terrain.in_cup(1460.0), "cup position")
	_check(terrain.normal(300.0).y < 0.0, "normal points up")
	_check(terrain.tangent(1000.0).x > 0.0, "tangent points toward +x")
	_check(terrain.basin_y(1050.0) > terrain.ground_y(1050.0), "water sits above its basin")


func _test_ball_rests_on_flat() -> void:
	var sim := BallSim.new(Terrain.new(_flat_hole()))
	sim.place(100.0)
	sim.launch(Vector2(200.0, -150.0), 0.0)
	_run_to_stop(sim)
	_check(sim.state == BallSim.State.RESTING, "ball comes to rest")
	_check(is_equal_approx(sim.pos.y, 300.0 - BallSim.RADIUS), "ball rests on the ground")


func _test_ball_rolls_off_steep_slope() -> void:
	var hole: HoleData = _flat_hole()
	hole.points = PackedVector2Array([Vector2(0, 100), Vector2(400, 300), Vector2(1000, 300)])
	var sim := BallSim.new(Terrain.new(hole))
	sim.place(100.0)
	sim.launch(Vector2(1.0, 0.0), 0.0)
	_run_to_stop(sim)
	_check(sim.pos.x > 390.0, "ball rolls down a steep slope (%.0f)" % sim.pos.x)
	_check(sim.state == BallSim.State.RESTING, "ball settles after the slope")


func _test_spin_changes_landing() -> void:
	var none: float = _shot_distance("iron", 1.0, 0.0, 0)
	var back: float = _shot_distance("iron", 1.0, 0.0, -1)
	var top: float = _shot_distance("iron", 1.0, 0.0, 1)
	_check(back < none - 40.0, "backspin stops shorter (%.0f vs %.0f)" % [back, none])
	_check(top > none, "topspin runs further (%.0f vs %.0f)" % [top, none])


func _test_sand_stops_ball() -> void:
	var hole: HoleData = _flat_hole({ "spans": [{ "from": 0, "to": 1000, "type": Surface.Type.SAND }] })
	var sim := BallSim.new(Terrain.new(hole))
	sim.place(100.0)
	sim.launch(Vector2(150.0, -120.0), 0.0)
	var carry: float = 2.0 * 150.0 * 120.0 / BallSim.GRAVITY
	_run_to_stop(sim)
	_check(sim.pos.x - 100.0 < carry + 30.0, "sand kills the roll (%.0f, carry %.0f)" % [sim.pos.x - 100.0, carry])


func _test_water_penalty_flow() -> void:
	var game: HoleGame = _game()
	game.ball.place(950.0)
	game.club_index = 1
	game.spin = 0
	game.facing = 1
	game.strike_with(0.3, 0.0)
	var start_x: float = 950.0
	var penalties: Array[String] = []
	game.penalty_taken.connect(func(kind: String) -> void: penalties.append(kind))
	var guard: int = 0
	while game.phase != HoleGame.Phase.AIM and guard < 3000:
		game.tick(DT)
		guard += 1
	_check(penalties.size() == 1 and penalties[0] == "water", "water triggers a penalty")
	_check(game.strokes == 2, "water costs a stroke on top of the shot (%d)" % game.strokes)
	_check(is_equal_approx(game.ball.pos.x, start_x), "ball returns to its last spot")
	_check(game.ball.state == BallSim.State.RESTING, "ball is playable again")


func _test_cup_captures_slow_putt() -> void:
	var sim := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 300.0 })))
	sim.place(250.0)
	sim.launch(Vector2(90.0, 0.0), 0.0)
	_run_to_stop(sim)
	_check(sim.state == BallSim.State.HOLED, "a slow putt drops (state %d)" % sim.state)


func _test_cup_rejects_fast_putt() -> void:
	var sim := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 300.0 })))
	sim.place(280.0)
	sim.launch(Vector2(230.0, 0.0), 0.0)
	_run_to_stop(sim)
	_check(sim.state == BallSim.State.RESTING and sim.pos.x > 310.0, "a fast putt rolls over the cup")


func _test_out_of_bounds() -> void:
	var game: HoleGame = _game()
	game.ball.place(10.0)
	game.facing = -1
	game.club_index = 0
	game.strike_with(1.0, 0.0)
	var guard: int = 0
	while game.phase == HoleGame.Phase.BALL_MOVING and guard < 3000:
		game.tick(DT)
		guard += 1
	_check(game.phase == HoleGame.Phase.PENALTY, "going off the course is a penalty")
	_check(game.strokes == 2, "out of bounds costs a stroke")


func _test_three_click_through_game() -> void:
	var game: HoleGame = _game()
	_check(game.phase == HoleGame.Phase.AIM, "hole starts aiming")
	_check(game.current_club().id == "driver", "long hole offers the driver")
	game.press_swing()
	_check(game.phase == HoleGame.Phase.SWING, "first press starts the swing")
	for _i in 40:
		game.tick(DT)
	game.press_swing()
	while game.meter.cursor > 0.0:
		game.tick(DT)
	game.press_swing()
	for _i in 12:
		game.tick(DT)
	_check(game.phase == HoleGame.Phase.BALL_MOVING, "third press hits the ball")
	_check(game.strokes == 1, "a swing counts as one stroke")
	_check(game.ball.is_moving(), "ball is moving")
	var guard: int = 0
	while game.phase == HoleGame.Phase.BALL_MOVING and guard < 3000:
		game.tick(DT)
		guard += 1
	_check(game.phase == HoleGame.Phase.AIM, "aiming resumes after the ball stops")
	_check(game.ball.pos.x > game.hole.tee_x + 100.0, "the shot went forward")


func _test_score_names() -> void:
	_check(HoleGame.score_name(1, 4) == "HOLE IN ONE!", "hole in one beats other names")
	_check(HoleGame.score_name(3, 4) == "BIRDIE!", "birdie")
	_check(HoleGame.score_name(4, 4) == "PAR", "par")
	_check(HoleGame.score_name(5, 4) == "BOGEY", "bogey")
	_check(HoleGame.score_name(9, 4) == "5 OVER PAR", "high scores")


func _test_auto_club_on_green() -> void:
	var game: HoleGame = _game()
	game.ball.place(1400.0)
	game.strike_with(0.05, 0.0)
	var guard: int = 0
	while game.phase == HoleGame.Phase.BALL_MOVING and guard < 3000:
		game.tick(DT)
		guard += 1
	if game.phase == HoleGame.Phase.AIM:
		_check(game.current_club().is_putter, "the putter is offered on the green")


func _test_auto_club_in_sand() -> void:
	var game: HoleGame = _game()
	game.ball.place(690.0)
	game._begin_aim()
	_check(game.lie_surface() == Surface.Type.SAND, "ball is in the bunker")
	_check(game.current_club().id == "iron", "sand offers the iron, even from long range")
	var reach: float = absf(Vector2(game.preview()["landing"]).x - game.ball.pos.x)
	_check(reach > 100.0, "the iron escapes the bunker (%.0f)" % reach)


func _test_aim_angle_rules() -> void:
	var game: HoleGame = _game()
	_check(is_equal_approx(game.aim_angle, 30.0), "aim starts at the driver's loft")

	game.adjust_aim(1.0, 0.5)
	_check(is_equal_approx(game.aim_angle, 30.0 + HoleGame.AIM_RATE * 0.5), "holding up raises the angle")
	game.adjust_aim(1.0, 60.0)
	_check(is_equal_approx(game.aim_angle, game.current_club().max_angle_deg), "angle stops at the club's maximum")
	game.adjust_aim(-1.0, 60.0)
	_check(is_equal_approx(game.aim_angle, game.current_club().min_angle_deg), "angle stops at the club's minimum")

	game.select_club(1)
	_check(is_equal_approx(game.aim_angle, 45.0), "changing club resets to its loft")
	game.select_club(2)
	game.adjust_aim(1.0, 1.0)
	_check(is_zero_approx(game.aim_angle), "putts stay on the ground")

	game.select_club(1)
	game.press_swing()
	var before: float = game.aim_angle
	game.adjust_aim(1.0, 1.0)
	_check(is_equal_approx(game.aim_angle, before), "the angle locks once the swing starts")


func _test_aim_angle_changes_shot() -> void:
	var game: HoleGame = _game()
	game.select_club(1)
	var base_reach: float = Vector2(game.preview()["landing"]).x
	game.adjust_aim(1.0, 0.8)
	var high_angle: float = game.launch_angle()
	var high_reach: float = Vector2(game.preview()["landing"]).x
	_check(high_reach < base_reach, "a steeper iron lands shorter, and the preview shows it")

	# The angle must reach the real shot, not only the preview.
	game.strike_with(1.0, 0.0)
	var launch_angle: float = rad_to_deg(_elevation(game.ball.vel))
	_check(absf(launch_angle - high_angle) < 0.01, "the shot launches at the aimed angle (%.1f)" % launch_angle)

	var low: Vector2 = ShotCalc.compute(_club("iron"), 1.0, 0.0, 0, 1, 1.0, 20.0)["velocity"]
	var low_popped: Vector2 = ShotCalc.compute(_club("iron"), 1.0, 1.0, 0, 1, 1.0, 20.0)["velocity"]
	_check(_elevation(low_popped) > _elevation(low), "misses still apply on top of the chosen angle")

	var after: HoleGame = _game()
	after.adjust_aim(1.0, 0.5)
	after.strike_with(0.3, 0.0)
	var guard: int = 0
	while after.phase != HoleGame.Phase.AIM and guard < 4000:
		after.tick(DT)
		guard += 1
	_check(is_equal_approx(after.aim_angle, after.current_club().loft_deg), "the next shot starts at the club's loft")


func _test_aim_bindings() -> void:
	Controls.register()
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	_check(up.is_action_pressed("aim_up"), "the up arrow raises the angle")
	_check(not up.is_action_pressed("spin_up"), "the up arrow no longer changes spin")
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	_check(w.is_action_pressed("spin_up"), "W still changes spin")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_UP
	dpad.pressed = true
	_check(dpad.is_action_pressed("aim_up"), "controller d-pad up raises the angle")
	var y_button := InputEventJoypadButton.new()
	y_button.button_index = JOY_BUTTON_Y
	y_button.pressed = true
	_check(y_button.is_action_pressed("spin_up"), "controller Y changes spin")


func _test_flip() -> void:
	Controls.register()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	_check(key.is_action_pressed("flip"), "F flips the golfer")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	_check(button.is_action_pressed("flip"), "controller X flips the golfer")

	var overshot := HoleGame.new(_flat_hole({ "cup_x": 300.0 }), _clubs())
	overshot.ball.place(800.0)
	overshot._begin_aim()
	_check(overshot.facing == -1, "past the pin, the golfer faces back toward the cup")
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	game.ball.place(500.0)
	game._begin_aim()
	_check(game.facing == 1, "short of the pin, the golfer faces the cup")

	# The flip changes the shot itself, and the aim preview along with it.
	game.select_club(1)
	var ahead: float = Vector2(game.preview()["landing"]).x
	game.flip_facing()
	_check(game.facing == -1 and game.is_playing_away(), "flipping turns the golfer around")
	_check(Vector2(game.preview()["landing"]).x < 500.0 and ahead > 500.0, "the preview follows the flip")
	_check(not game.turned_back, "a flip by the player isn't reported as no clear shot")
	_check(game.current_club().id == "iron", "flipping keeps the chosen club")
	game.strike_with(0.5, 0.0)
	_check(game.ball.vel.x < 0.0, "a flipped shot goes the other way")

	# It can't happen mid-shot, and it lasts one shot.
	game.flip_facing()
	_check(game.facing == -1, "the golfer can't flip while the ball is moving")
	var steps: int = 0
	while game.phase != HoleGame.Phase.AIM and steps < 3000:
		game.tick(DT)
		steps += 1
	_check(game.ball.pos.x < 500.0 and game.facing == 1, "the next shot faces the cup again")

	# A flip works from a turned-back spot, and clears its message.
	var blocked := HoleGame.new(load("res://data/holes/hole_08.tres") as HoleData, _clubs())
	blocked.ball.place(685.0)
	blocked._begin_aim()
	_check(blocked.turned_back, "the game reports when it turned the golfer back")
	blocked.flip_facing()
	_check(not blocked.is_playing_away() and not blocked.turned_back, "the player can flip back toward the cup")

	# Putts can flip too, while the meter keeps moving.
	var putt := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	putt.select_club(2)
	putt.flip_facing()
	_check(putt.facing == -1 and putt.meter.stage == SwingMeter.Stage.SWEEPING, "a putt can flip with its meter still moving")


func _test_aim_line_is_for_full_swings() -> void:
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	game.select_club(1)
	_check(game.shows_aim_line(), "swings show an aim line")
	game.select_club(2)
	_check(not game.shows_aim_line(), "putts show no aim line")


func _test_short_shot_return() -> void:
	var times: Array[float] = []
	for power: float in [1.0, 0.5, 0.2]:
		var meter := SwingMeter.new()
		meter.press()
		meter.cursor = power
		meter.press()
		var elapsed: float = 0.0
		while meter.cursor > 0.0:
			meter.tick(DT)
			elapsed += DT
		times.append(elapsed)
	_check(absf(times[0] - times[2]) < 0.05, "the return takes the same time at any power (%.2f, %.2f)" % [times[0], times[2]])

	var tiny := SwingMeter.new()
	tiny.press()
	tiny.cursor = 0.05
	tiny.press()
	var elapsed_tiny: float = 0.0
	while tiny.cursor > 0.0:
		tiny.tick(DT)
		elapsed_tiny += DT
	_check(elapsed_tiny > 0.2, "even a tiny tap leaves time to react (%.2f)" % elapsed_tiny)


func _test_lie_effects() -> void:
	var game: HoleGame = _game()
	game.ball.place(300.0)
	game._begin_aim()
	game.select_club(0)
	_check(is_equal_approx(game.lie_power(), 1.0), "a clean lie has full range")
	var clean_window: float = game.meter.perfect_window

	game.ball.place(1650.0)
	game._begin_aim()
	_check(game.lie_surface() == Surface.Type.ROUGH, "ball is in the rough")
	_check(game.meter.perfect_window < clean_window, "rough shrinks the sweet spot")
	game.select_club(1)
	var iron_rough: float = game.lie_power()
	game.select_club(0)
	var driver_rough: float = game.lie_power()
	_check(driver_rough < iron_rough, "the driver suffers more from rough (%.2f, %.2f)" % [driver_rough, iron_rough])

	game.ball.place(690.0)
	game._begin_aim()
	var sand_window: float = game.meter.perfect_window
	_check(sand_window < clean_window * 0.7, "sand shrinks the sweet spot most")
	game.select_club(0)
	_check(game.lie_power() < 0.4, "the driver is weak from sand (%.2f)" % game.lie_power())
	_check(SwingMeter.accuracy_for_cursor(0.03, sand_window) > 0.0, "a timing that's perfect on grass misses in sand")

	var clean_spin: float = ShotCalc.compute(_club("iron"), 1.0, 0.0, -1, 1, 1.0)["spin"]
	var rough_spin: float = ShotCalc.compute(_club("iron"), 1.0, 0.0, -1, 1, 1.0, -1.0, 0.4)["spin"]
	_check(absf(rough_spin) < absf(clean_spin), "rough takes spin off the ball")


func _test_spin_needs_clean_strike() -> void:
	var perfect: float = ShotCalc.compute(_club("iron"), 1.0, 0.0, -1, 1, 1.0)["spin"]
	var half: float = ShotCalc.compute(_club("iron"), 1.0, 0.5, -1, 1, 1.0)["spin"]
	var missed: float = ShotCalc.compute(_club("iron"), 1.0, -1.0, -1, 1, 1.0)["spin"]
	_check(is_equal_approx(perfect, -1.0), "a clean iron gets full spin")
	_check(is_equal_approx(half, -0.5), "a half miss gets half the spin")
	_check(is_zero_approx(missed), "a full miss gets none")
	var driver: float = ShotCalc.compute(_club("driver"), 1.0, 0.0, -1, 1, 1.0)["spin"]
	_check(absf(driver) < absf(perfect), "the driver spins less than the iron")


func _test_slope_tilts_launch() -> void:
	var game: HoleGame = _game()
	game.ball.place(1200.0)
	game._begin_aim()
	game.select_club(1)
	_check(game.terrain.slope(1200.0) < 0.0 and game.facing == 1, "this spot slopes up toward the cup")
	_check(game.launch_angle() > game.aim_angle, "an upslope launches higher")

	game.ball.place(350.0)
	game._begin_aim()
	game.select_club(1)
	_check(game.terrain.slope(350.0) > 0.0, "this spot slopes down toward the cup")
	_check(game.launch_angle() < game.aim_angle, "a downslope launches lower")

	# Past the same slope, hitting back the other way reverses the effect.
	game.ball.place(1200.0)
	game._begin_aim()
	game.select_club(1)
	game.facing = -1
	_check(game.launch_angle() < game.aim_angle, "the tilt depends on which way you're hitting")

	var wall: HoleGame = _game()
	wall.ball.place(705.0)
	wall._begin_aim()
	wall.select_club(0)
	wall.adjust_aim(-1.0, 60.0)
	var uphill: float = rad_to_deg(atan(-wall.terrain.slope(705.0)))
	_check(wall.launch_angle() >= uphill + HoleGame.SLOPE_CLEARANCE - 0.01, "the ball always clears the slope it sits on")
	var reach: float = absf(Vector2(wall.preview()["landing"]).x - wall.ball.pos.x)
	_check(reach > 20.0, "a low driver no longer dies in a bunker wall (%.0f)" % reach)

	game.ball.place(1200.0)
	game._begin_aim()
	game.select_club(1)
	var expected: float = game.launch_angle()
	game.strike_with(1.0, 0.0)
	_check(absf(rad_to_deg(_elevation(game.ball.vel)) - expected) < 0.01, "the real shot uses the tilted angle")


func _test_landing_slope_changes_run() -> void:
	var flat_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	var down_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	down_hole.points = PackedVector2Array([Vector2(0, 300), Vector2(100, 300), Vector2(900, 480), Vector2(1000, 480)])
	var up_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	up_hole.points = PackedVector2Array([Vector2(0, 400), Vector2(100, 400), Vector2(900, 220), Vector2(1000, 220)])

	var after_landing: Array[float] = []
	for hole: HoleData in [flat_hole, down_hole, up_hole]:
		var sim := BallSim.new(Terrain.new(hole))
		var land_xs: Array[float] = []
		sim.bounced.connect(func(at: Vector2, _s: int, _i: float) -> void: land_xs.append(at.x))
		sim.place(50.0)
		sim.launch(Vector2(170.0, -120.0), 0.0)
		_run_to_stop(sim)
		after_landing.append(sim.pos.x - land_xs[0])
	_check(after_landing[1] > after_landing[0], "landing downhill runs further (%.0f vs %.0f)" % [after_landing[1], after_landing[0]])
	_check(after_landing[2] < after_landing[0], "landing uphill runs less (%.0f vs %.0f)" % [after_landing[2], after_landing[0]])


func _test_steep_landing_stops_sooner() -> void:
	var runs: Array[float] = []
	for angle: float in [25.0, 70.0]:
		var sim := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 990.0 })))
		var land_xs: Array[float] = []
		sim.bounced.connect(func(at: Vector2, _s: int, _i: float) -> void: land_xs.append(at.x))
		sim.place(20.0)
		var shot: Dictionary = ShotCalc.compute(_club("iron"), 1.0, 0.0, 0, 1, 1.0, angle)
		sim.launch(shot["velocity"], 0.0)
		_run_to_stop(sim)
		runs.append(sim.pos.x - land_xs[0])
	_check(runs[1] < runs[0], "a steep landing runs less than a flat one (%.0f vs %.0f)" % [runs[1], runs[0]])


func _test_ball_settles_in_bowl() -> void:
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.points = PackedVector2Array([Vector2(0, 200), Vector2(300, 400), Vector2(600, 200), Vector2(1000, 200)])
	var sim := BallSim.new(Terrain.new(hole))
	sim.place(120.0)
	sim.launch(Vector2(1.0, 0.0), 0.0)
	var steps: int = 0
	while sim.is_moving() and steps < int(BallSim.MAX_MOTION_TIME * 50.0):
		sim.step(DT)
		steps += 1
	_check(sim.state == BallSim.State.RESTING, "a ball settles in a bowl before the safety timeout")
	_check(absf(sim.pos.x - 300.0) < 120.0, "it settles near the bottom (%.0f)" % sim.pos.x)


func _test_pin_hit() -> void:
	var terrain := Terrain.new(_flat_hole({ "cup_x": 300.0 }))
	var sim := BallSim.new(terrain)
	var hits: Array[Vector2] = []
	sim.pin_hit.connect(func(at: Vector2) -> void: hits.append(at))
	sim.place(280.0)
	sim.pos.y = terrain.rim_y - 15.0
	sim.launch(Vector2(200.0, -1.0), 0.0)
	var guard: int = 0
	while hits.is_empty() and guard < 120:
		sim.step(DT)
		guard += 1
	_check(hits.size() == 1, "a ball at pin height hits the pin")
	_check(sim.vel.x < 0.0 and absf(sim.vel.x) < 60.0, "the pin knocks it back and kills its speed")
	_run_to_stop(sim)
	_check(absf(sim.pos.x - 300.0) < 40.0, "the ball finishes close to the cup (%.0f)" % sim.pos.x)

	var high := BallSim.new(terrain)
	var high_hits: Array[Vector2] = []
	high.pin_hit.connect(func(at: Vector2) -> void: high_hits.append(at))
	high.place(280.0)
	high.pos.y = terrain.rim_y - Terrain.PIN_HEIGHT - 20.0
	high.launch(Vector2(200.0, -1.0), 0.0)
	for _i in 20:
		high.step(DT)
	_check(high_hits.is_empty(), "a ball above the flag misses the pin")


func _test_club_ranges() -> void:
	var driver: float = _shot_distance("driver", 1.0, 0.0, 0)
	var iron: float = _shot_distance("iron", 1.0, 0.0, 0)
	var putter: float = _shot_distance("putter", 1.0, 0.0, 0)
	print("Full-power totals on flat fairway: driver %d yd, iron %d yd, putter %d yd" % [
		int(driver / 3.0), int(iron / 3.0), int(putter / 3.0)])
	_check(driver > iron and iron > putter, "clubs are ordered by range")
	_check(driver > 700.0 and driver < 950.0, "driver total is in range (%.0f)" % driver)
	_check(iron > 420.0 and iron < 640.0, "iron total is in range (%.0f)" % iron)


# A bot picks the best power for each shot. Proves the hole can be finished, and
# reports what a strong, accurate player scores.
func _test_bot_finishes_hole() -> void:
	var game: HoleGame = _game()
	var guard: int = 0
	var trace: Array[String] = []
	while game.phase != HoleGame.Phase.COMPLETE and guard < 14:
		var power: float = _best_power(game)
		trace.append("%s %.2f from %d" % [game.current_club().id, power, int(game.ball.pos.x)])
		game.strike_with(power, 0.0)
		var steps: int = 0
		while game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.COMPLETE and steps < 4000:
			game.tick(DT)
			steps += 1
		guard += 1
	print("Bot: %d strokes on par %d: %s" % [game.strokes, game.hole.par, ", ".join(trace)])
	_check(game.phase == HoleGame.Phase.COMPLETE, "the bot finishes the hole")
	_check(game.strokes <= 5, "a perfect player scores near par (%d)" % game.strokes)
	_check(game.strokes >= 2, "the hole isn't trivially one shot (%d)" % game.strokes)


# Picks sensible shots but mistimes them like a person. Measures how hard the hole
# plays, using a fixed seed so the result is repeatable.
func _test_imperfect_player_scores() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for skill: Array in [["average", 0.06, 0.05], ["sloppy", 0.1, 0.1]]:
		var rounds: int = 10
		var total: int = 0
		var worst: int = 0
		var penalties: Array[String] = []
		for _round in rounds:
			var game: HoleGame = _game()
			game.penalty_taken.connect(func(kind: String) -> void: penalties.append(kind))
			var shots: int = 0
			while game.phase != HoleGame.Phase.COMPLETE and shots < 20:
				var power: float = _best_power(game)
				power = clampf(power + rng.randfn(0.0, float(skill[1])), 0.02, 1.0)
				var cursor: float = rng.randfn(0.0, float(skill[2]))
				game.strike_with(power, SwingMeter.accuracy_for_cursor(cursor, game.meter.perfect_window))
				var steps: int = 0
				while game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.COMPLETE and steps < 4000:
					game.tick(DT)
					steps += 1
				shots += 1
			total += game.strokes
			worst = maxi(worst, game.strokes)
			_check(game.phase == HoleGame.Phase.COMPLETE, "an imperfect player can finish the hole")
		var average: float = float(total) / float(rounds)
		print("%s player: average %.1f on par 4, worst %d, %d penalties in %d rounds" % [
			skill[0], average, worst, penalties.size(), rounds])
		_check(average < 9.0, "the hole isn't punishing for a %s player (%.1f)" % [skill[0], average])


# Every spot a ball can sit must offer a club with a shot that stays out of trouble,
# because water returns the ball to the same spot.
func _test_no_spot_is_a_trap() -> void:
	var course := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in course.hole_count():
		var game := HoleGame.new(course.hole_at(i), _clubs())
		var traps: Array[int] = []
		for x in range(5, game.terrain.length - 5, 10):
			if game.terrain.surface_at(float(x)) == Surface.Type.WATER or game.terrain.in_cup(float(x)):
				continue
			game.ball.place(float(x))
			game._begin_aim()
			if not _has_safe_shot(game):
				traps.append(x)
		_check(traps.is_empty(), "%s has no trap spots (traps at %s)" % [game.hole.display_name, str(traps)])

	var first: HoleGame = _game()
	first.ball.place(977.0)
	first._begin_aim()
	_check(first.current_club().id == "iron", "the steep bank above the pond offers the iron")


func _test_trees_are_scenery() -> void:
	var plain: HoleData = _flat_hole({ "cup_x": 990.0 })
	var wooded: HoleData = _flat_hole({ "cup_x": 990.0 })
	for x: float in [200.0, 240.0, 300.0, 360.0]:
		wooded.scenery.append_array(HoleIO.tree_pieces(x, 0))
	_check(Obstacle.build_all(wooded, Terrain.new(wooded)).is_empty(), "trees create no obstacles")
	var plain_game := HoleGame.new(plain, _clubs())
	var wooded_game := HoleGame.new(wooded, _clubs())
	for game: HoleGame in [plain_game, wooded_game]:
		game.select_club(1)
		game.strike_with(1.0, 0.0)
		var guard: int = 0
		while game.phase == HoleGame.Phase.BALL_MOVING and guard < 3000:
			game.tick(DT)
			guard += 1
	_check(is_equal_approx(plain_game.ball.pos.x, wooded_game.ball.pos.x), "trees don't change where a shot finishes")


func _test_putting_is_one_press() -> void:
	# The meter itself.
	var meter := SwingMeter.new()
	meter.start_sweep()
	_check(meter.stage == SwingMeter.Stage.SWEEPING, "a sweep starts moving by itself")
	var peak: float = 0.0
	for _i in int(SwingMeter.SWEEP_TIME * 60.0) + 10:
		meter.tick(DT)
		peak = maxf(peak, meter.cursor)
	_check(is_equal_approx(peak, 1.0) and meter.cursor < 1.0, "it turns around at the top")
	for _i in int(SwingMeter.SWEEP_TIME * 120.0):
		meter.tick(DT)
		_check(meter.cursor >= 0.0 and meter.cursor <= 1.0, "it stays on the meter")
	var at_press: float = meter.cursor
	meter.press()
	_check(meter.is_done(), "one press finishes it")
	_check(is_equal_approx(meter.power, maxf(at_press, 0.02)) and meter.accuracy == 0.0, "it takes the power, and no accuracy")

	# In play: on the green, the putter is ready and one press hits the ball.
	var game: HoleGame = _game()
	game.ball.place(1380.0)
	game._begin_aim()
	_check(game.current_club().is_putter, "the putter comes up on the green")
	_check(game.meter.stage == SwingMeter.Stage.SWEEPING, "its meter is already moving")
	var before: float = game.meter.cursor
	for _i in 30:
		game.tick(DT)
	_check(game.meter.cursor != before, "the meter moves while aiming")
	_check(game.phase == HoleGame.Phase.AIM and game.strokes == 0, "nothing happens until the press")
	var set_power: float = game.meter.cursor
	game.press_swing()
	_check(game.meter.is_done(), "a single press sets the power")
	_check(is_equal_approx(game.meter.power, set_power), "at the cursor's position")
	game.press_swing()
	game.press_swing()
	var guard: int = 0
	while game.phase == HoleGame.Phase.DOWNSWING and guard < 60:
		game.tick(DT)
		guard += 1
	_check(game.strokes == 1, "one press is one stroke, even with extra presses (%d)" % game.strokes)
	_check(game.phase == HoleGame.Phase.BALL_MOVING, "the ball is struck")
	_check(game.last_quality == "", "putts have no quality message")
	var putt_speed: float = absf(game.ball.vel.x)
	var expected: float = game.current_club().max_speed * sqrt(set_power)
	_check(absf(putt_speed - expected) < expected * 0.15, "the putt uses the power set (%.0f, expected %.0f)" % [putt_speed, expected])

	# Accuracy can't change a putt at all.
	var clean: Vector2 = ShotCalc.compute(_club("putter"), 0.5, 0.0, 0, 1, 1.0)["velocity"]
	var early: Vector2 = ShotCalc.compute(_club("putter"), 0.5, 1.0, 0, 1, 1.0)["velocity"]
	var late: Vector2 = ShotCalc.compute(_club("putter"), 0.5, -1.0, 0, 1, 1.0)["velocity"]
	_check(clean == early and clean == late, "timing has no effect on a putt")

	# Other clubs keep all three presses, and changing clubs switches the meter over.
	var mixed: HoleGame = _game()
	mixed.ball.place(1380.0)
	mixed._begin_aim()
	mixed.select_club(1)
	_check(mixed.meter.stage == SwingMeter.Stage.IDLE, "picking the iron stops the sweep")
	mixed.press_swing()
	_check(mixed.phase == HoleGame.Phase.SWING and mixed.strokes == 0, "the iron's first press starts its meter")
	mixed.press_swing()
	_check(mixed.meter.stage == SwingMeter.Stage.RETURNING, "its second press sets power")
	mixed.press_swing()
	_check(mixed.meter.is_done(), "its third press sets accuracy")

	var switched: HoleGame = _game()
	switched.select_club(2)
	_check(switched.meter.stage == SwingMeter.Stage.SWEEPING, "picking the putter off the green starts the sweep")
	switched.select_club(0)
	_check(switched.meter.stage == SwingMeter.Stage.IDLE, "and picking the driver stops it")
	switched.select_club(2)
	switched.press_swing()
	for _i in 20:
		switched.tick(DT)
	_check(switched.strokes == 1, "putting off the green is also one press")

	# The reach readout follows the meter, and matches where the putt really finishes.
	var aiming: HoleGame = HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	aiming.select_club(2)
	aiming.meter.cursor = 0.2
	var short_reach: float = absf(Vector2(aiming.preview()["landing"]).x - aiming.ball.pos.x)
	aiming.meter.cursor = 0.9
	var long_reach: float = absf(Vector2(aiming.preview()["landing"]).x - aiming.ball.pos.x)
	_check(long_reach > short_reach * 3.0, "the reach follows the meter (%.0f, %.0f)" % [short_reach, long_reach])
	aiming.meter.cursor = 0.6
	var promised: float = Vector2(aiming.preview()["landing"]).x
	aiming.press_swing()
	var rolling: int = 0
	while aiming.phase != HoleGame.Phase.AIM and rolling < 2000:
		aiming.tick(DT)
		rolling += 1
	_check(absf(aiming.ball.pos.x - promised) < 2.0, "the putt finishes at the reach shown (%.0f, %.0f)" % [aiming.ball.pos.x, promised])

	var unmoved: HoleGame = HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	unmoved.select_club(1)
	var iron_reach: float = Vector2(unmoved.preview()["landing"]).x
	unmoved.meter.cursor = 0.1
	_check(is_equal_approx(Vector2(unmoved.preview()["landing"]).x, iron_reach), "other clubs still preview at full power")

	# After a putt that doesn't drop, the next one is ready to go.
	var again: HoleGame = _game()
	again.ball.place(1380.0)
	again._begin_aim()
	again.strike_with(0.05, 0.0)
	var settle: int = 0
	while again.phase != HoleGame.Phase.AIM and settle < 3000:
		again.tick(DT)
		settle += 1
	_check(again.meter.stage == SwingMeter.Stage.SWEEPING, "the sweep is ready again for the next putt")


func _test_tree_pieces() -> void:
	# Every original tree has come apart into its two pieces.
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	var trunks: int = 0
	var leaves: int = 0
	for i in run.hole_count():
		for piece: Dictionary in run.hole_at(i).scenery:
			if str(piece["kind"]) == "trunk":
				trunks += 1
			else:
				leaves += 1
	_check(trunks > 0 and trunks == leaves, "original trees are a trunk and leaves each (%d, %d)" % [trunks, leaves])

	# They can be placed separately.
	var doc := EditorDoc.new(HoleIO.blank_hole("T"))
	var trunk: Dictionary = doc.add_object("trunk", Vector2(500, 298))
	var leaf: Dictionary = doc.add_object("leaves", Vector2(700, 200))
	_check(str(doc.piece_of(trunk)["kind"]) == "trunk" and str(doc.piece_of(leaf)["kind"]) == "leaves", "trunks and leaves are placed separately")
	_check(doc.hole.scenery.size() == 2, "each placement adds exactly one piece")
	_check(is_zero_approx(float(doc.piece_of(trunk)["height"])), "a trunk placed near the ground stands on it")
	_check(doc.selection_center(leaf) == Vector2(700, 200), "leaves go exactly where placed")

	# And moved separately: moving one leaves the other where it was.
	var pieces := EditorDoc.new(HoleIO.blank_hole("T"))
	pieces.hole.scenery = HoleIO.tree_pieces(500.0, 0)
	var tree_trunk: Dictionary = { "type": "scenery", "index": 0 }
	var tree_leaves: Dictionary = { "type": "scenery", "index": 1 }
	var leaves_at: Vector2 = pieces.selection_center(tree_leaves)
	pieces.move_selection(tree_trunk, Vector2(300, 290))
	_check(is_equal_approx(float(pieces.piece_of(tree_trunk)["x"]), 300.0), "a trunk moves on its own")
	_check(pieces.selection_center(tree_leaves) == leaves_at, "its leaves stay where they were")
	var trunk_at: Vector2 = pieces.selection_center(tree_trunk)
	pieces.move_selection(tree_leaves, Vector2(800, 120))
	_check(pieces.selection_center(tree_leaves) == Vector2(800, 120), "leaves move on their own, anywhere")
	_check(pieces.selection_center(tree_trunk) == trunk_at, "the trunk stays where it was")

	# Clicking picks the piece under the mouse.
	var clicking := EditorDoc.new(HoleIO.blank_hole("T"))
	clicking.hole.scenery = HoleIO.tree_pieces(500.0, 0)
	var ground: float = clicking.terrain.ground_y(500.0)
	_check(int(clicking.pick(Vector2(500, ground - 8.0), 4.0).get("index", -1)) == 0, "clicking the trunk selects the trunk")
	_check(int(clicking.pick(Vector2(500, ground - 40.0), 4.0).get("index", -1)) == 1, "clicking the leaves selects the leaves")

	# A trunk can be lifted off the ground, then put back.
	pieces.move_selection(tree_trunk, Vector2(300, 150))
	_check(float(pieces.piece_of(tree_trunk)["height"]) > 100.0, "a trunk can be lifted")
	pieces.rest_trunk_on_ground(tree_trunk)
	_check(is_zero_approx(float(pieces.piece_of(tree_trunk)["height"])), "and rested back on the ground")
	pieces.move_selection(tree_trunk, Vector2(300, 300.0 - EditorDoc.TRUNK_MIDDLE - 3.0))
	_check(is_zero_approx(float(pieces.piece_of(tree_trunk)["height"])), "dragging near the ground snaps to it")

	# The panel sets each piece, and they delete and undo separately.
	_check(not pieces.can_rotate(tree_trunk) and not pieces.can_rotate(tree_leaves), "tree pieces don't rotate")
	pieces.set_property(tree_leaves, "variant", 2.0)
	_check(int(pieces.piece_of(tree_leaves)["variant"]) == 2, "the leaves' shape can be set")
	pieces.set_property(tree_trunk, "height", 25.0)
	_check(is_equal_approx(float(pieces.piece_of(tree_trunk)["height"]), 25.0), "a trunk's height can be set")
	pieces.checkpoint()
	pieces.delete_selection(tree_trunk)
	_check(pieces.hole.scenery.size() == 1 and str(pieces.hole.scenery[0]["kind"]) == "leaves", "deleting a trunk keeps the leaves")
	pieces.undo()
	_check(pieces.hole.scenery.size() == 2, "undo brings the piece back")

	# Pieces survive saving, separately placed.
	var reloaded: HoleData = HoleIO.from_dict(JSON.parse_string(JSON.stringify(HoleIO.to_dict(pieces.hole))))
	_check(reloaded.scenery == pieces.hole.scenery, "pieces survive being saved and loaded")


func _floating_pad(rotation: float, center: Vector2 = Vector2(400, 200)) -> Dictionary:
	return _hazard_sim({ "kind": "pad", "x": center.x, "y": center.y, "rotation": rotation })


func _start_ball(sim: BallSim, at: Vector2, velocity: Vector2) -> void:
	sim.place(at.x)
	sim.pos = at
	sim.launch(velocity, 0.0)
	# Starts each test shot from far away, so the pad's start-of-shot grace doesn't apply.
	sim.launch_x = 0.0
	sim.launch_y = 0.0


func _test_bounce_pads() -> void:
	# A rectangle that can float anywhere, at any angle.
	var flat: Dictionary = _floating_pad(0.0)
	var flat_pad: BouncePadObstacle = flat["obstacle"]
	_check(flat_pad.center == Vector2(400, 200), "a pad can float in mid-air")
	var grounded: BouncePadObstacle = _hazard_sim({ "kind": "pad", "x": 400.0, "rotation": 0.0 })["obstacle"]
	_check(is_equal_approx(grounded.center.y, 300.0 - BouncePadObstacle.HALF_THICKNESS), "with no height given, a pad rests on the ground")
	var tilted: BouncePadObstacle = _hazard_sim({ "kind": "pad", "x": 400.0, "rotation": 30.0 })["obstacle"]
	_check(tilted.center.y < 300.0 and tilted.center.y > 295.0, "a tilted grounded pad settles into the ground (%.1f)" % tilted.center.y)

	# The spring face fires the ball straight out from it.
	var flat_sim: BallSim = flat["sim"]
	_start_ball(flat_sim, Vector2(400, 170), Vector2(0, 120))
	for _i in 30:
		flat_sim.step(DT)
		if flat_sim.vel.y < 0.0:
			break
	_check(flat_sim.vel.y <= -BouncePadObstacle.DEFAULT_POWER * 0.95, "the face fires the ball out (%.0f)" % flat_sim.vel.y)
	_check(flat_sim.pad_uses.get(flat_pad, 0) == 1, "firing counts as one use")

	for rotation: float in [45.0, -45.0, 90.0]:
		var made: Dictionary = _floating_pad(rotation)
		var pad: BouncePadObstacle = made["obstacle"]
		var sim: BallSim = made["sim"]
		_start_ball(sim, pad.center + pad.normal * 30.0, -pad.normal * 150.0)
		for _i in 30:
			sim.step(DT)
			if sim.vel.dot(pad.normal) > 0.0:
				break
		_check(sim.vel.dot(pad.normal) >= BouncePadObstacle.DEFAULT_POWER * 0.9, "a pad at %d degrees fires along its face (%.0f)" % [int(rotation), sim.vel.dot(pad.normal)])

	# The back and ends are ordinary solid bounces.
	var back: Dictionary = _floating_pad(0.0)
	var back_sim: BallSim = back["sim"]
	_start_ball(back_sim, Vector2(400, 230), Vector2(0, -150))
	for _i in 30:
		back_sim.step(DT)
		if back_sim.vel.y > 0.0:
			break
	_check(back_sim.vel.y > 0.0, "the back stops a ball coming from behind")
	_check(back_sim.vel.y < 100.0, "the back doesn't fire it (%.0f)" % back_sim.vel.y)
	_check(back_sim.pad_uses.is_empty(), "hitting the back doesn't use the spring")

	var side: Dictionary = _floating_pad(0.0)
	var side_sim: BallSim = side["sim"]
	_start_ball(side_sim, Vector2(350, 201), Vector2(200, -14))
	for _i in 30:
		side_sim.step(DT)
		if side_sim.vel.x < 0.0:
			break
	_check(side_sim.vel.x < 0.0 and side_sim.vel.x > -100.0, "an end is a plain bounce (%.0f)" % side_sim.vel.x)
	_check(side_sim.pad_uses.is_empty(), "hitting an end doesn't use the spring")

	# On the ground, a rolling ball stops at the pad's end instead of being launched.
	var roll: Dictionary = _hazard_sim({ "kind": "pad", "x": 400.0, "rotation": 0.0 })
	var roll_sim: BallSim = roll["sim"]
	roll_sim.place(340.0)
	roll_sim.launch(Vector2(100.0, 0.0), 0.0)
	_run_to_stop(roll_sim)
	_check(roll_sim.pos.x < 400.0 - BouncePadObstacle.HALF_LENGTH, "a rolling ball stops at the end of a grounded pad (%.0f)" % roll_sim.pos.x)
	_check(roll_sim.pad_uses.is_empty(), "rolling into the end doesn't fire it")

	# Helpful pads have to work on a real shot, and beat the same shot with no pad.
	var with_pad: float = _iron_shot_past_pad(20.0, true)
	var without_pad: float = _iron_shot_past_pad(20.0, false)
	_check(with_pad > without_pad + 60.0, "a pad facing the hole carries a real shot further (%.0f vs %.0f)" % [with_pad, without_pad])
	var sent_back: float = _iron_shot_past_pad(-30.0, true)
	_check(sent_back < without_pad - 60.0, "a pad facing away sends a real shot back (%.0f vs %.0f)" % [sent_back, without_pad])

	# A ball coming straight down can't bounce on a pad forever.
	var pogo_made: Dictionary = _hazard_sim({ "kind": "pad", "x": 400.0, "rotation": 0.0 })
	var pogo: BallSim = pogo_made["sim"]
	_start_ball(pogo, Vector2(400, 250), Vector2(0, 1))
	var steps: int = 0
	while pogo.is_moving() and steps < int(BallSim.MAX_MOTION_TIME * 60.0) - 60:
		pogo.step(DT)
		steps += 1
	_check(not pogo.is_moving(), "a ball can't bounce on a pad forever (%d steps)" % steps)
	var uses: int = pogo.pad_uses.get(pogo_made["obstacle"], 0)
	_check(uses >= 2 and uses <= BouncePadObstacle.MAX_USES_PER_SHOT, "repeat bounces are limited (%d)" % uses)

	# A ball on a slope can't rattle against a pad's back for long.
	var slope_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	slope_hole.points = PackedVector2Array([Vector2(0, 100), Vector2(500, 300), Vector2(1000, 300)])
	slope_hole.obstacles = [{ "kind": "pad", "x": 300.0, "rotation": 20.0 }]
	var slope_terrain := Terrain.new(slope_hole)
	var slope_sim := BallSim.new(slope_terrain)
	slope_sim.obstacles = Obstacle.build_all(slope_hole, slope_terrain)
	slope_sim.place(200.0)
	slope_sim.launch(Vector2(40.0, 0.0), 0.0)
	var slope_steps: int = 0
	while slope_sim.is_moving() and slope_steps < 900:
		slope_sim.step(DT)
		slope_steps += 1
	_check(not slope_sim.is_moving(), "a ball rolling into a pad on a slope settles soon (%d steps)" % slope_steps)

	# A ball sitting right next to a pad can be played away from it.
	var on_made: Dictionary = _hazard_sim({ "kind": "pad", "x": 400.0, "rotation": -35.0 })
	var on_sim: BallSim = on_made["sim"]
	on_sim.place(400.0)
	on_sim.launch(Vector2(150.0, -150.0), 0.0)
	_run_to_stop(on_sim)
	_check(on_sim.pos.x > 500.0, "a shot played from beside a pad isn't fired back (%.0f)" % on_sim.pos.x)

	# Previews must not make the real pad twitch.
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.obstacles = [{ "kind": "pad", "x": 300.0, "y": 200.0, "rotation": 0.0 }]
	var game := HoleGame.new(hole, _clubs())
	var preview: BallSim = game.new_preview_sim()
	_start_ball(preview, Vector2(300, 170), Vector2(0, 100))
	_run_to_stop(preview)
	var shown: BouncePadObstacle = game.obstacles[0]
	_check(is_zero_approx(shown.squash), "previews don't animate the real pad")
	_check(preview.pad_uses.get(shown, 0) >= 1, "previews do include pads")

	# Across the course, pads mostly face away from the hole, with some that help.
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	var away_count: int = 0
	var toward_count: int = 0
	var flat_count: int = 0
	for i in run.hole_count():
		var course_hole: HoleData = run.hole_at(i)
		var terrain := Terrain.new(course_hole)
		for obstacle in Obstacle.build_all(course_hole, terrain):
			if not obstacle is BouncePadObstacle:
				continue
			var course_pad: BouncePadObstacle = obstacle
			if course_pad.is_flat():
				flat_count += 1
			elif course_pad.faces_cup():
				toward_count += 1
			else:
				away_count += 1
			var label: String = "%s pad at %d" % [course_hole.display_name, int(course_pad.x)]
			_check(terrain.surface_at(course_pad.x) != Surface.Type.WATER, "%s isn't in water" % label)
			_check(absf(course_pad.x - course_hole.tee_x) > 100.0, "%s isn't on the tee" % label)
			_check(absf(course_pad.x - course_hole.cup_x) > 100.0, "%s isn't on the pin" % label)
	print("Bounce pads on the course: %d away, %d toward the hole, %d flat" % [away_count, toward_count, flat_count])
	_check(away_count > toward_count and toward_count > 0, "pads mostly face away, and sometimes help")
	_check(flat_count > 0, "some pads are flat")


# Hits a full iron so that it comes down on a pad, and returns where it finishes.
func _iron_shot_past_pad(rotation: float, with_pad: bool) -> float:
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	var terrain := Terrain.new(hole)
	var shot: Dictionary = ShotCalc.compute(_club("iron"), 0.6, 0.0, 0, 1, 1.0)
	# Finds where this shot first lands on open ground, then puts the pad there.
	var scout := BallSim.new(terrain)
	scout.place(100.0)
	scout.launch(shot["velocity"], 0.0)
	var guard: int = 0
	while scout.bounce_count == 0 and guard < 2000:
		scout.step(DT)
		guard += 1
	var landing: float = scout.pos.x
	if with_pad:
		hole.obstacles = [{ "kind": "pad", "x": landing, "rotation": rotation }]
	var play_terrain := Terrain.new(hole)
	var sim := BallSim.new(play_terrain)
	sim.obstacles = Obstacle.build_all(hole, play_terrain)
	sim.place(100.0)
	sim.launch(shot["velocity"], 0.0)
	_run_to_stop(sim)
	return sim.pos.x


# Water returns the ball to where the shot started, so a pad aimed at water could send a
# good shot back to the same penalty again and again.
func _test_pads_never_fire_into_water() -> void:
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		var terrain := Terrain.new(hole)
		var static_only: Array[Obstacle] = Obstacle.build_all(hole, terrain)
		for obstacle in static_only:
			if not obstacle is BouncePadObstacle:
				continue
			var pad: BouncePadObstacle = obstacle
			var sim := BallSim.new(terrain)
			sim.obstacles = static_only
			sim.wind = hole.wind
			sim.ignore_moving = true
			_start_ball(sim, pad.center + pad.normal * 12.0, -pad.normal * 120.0)
			_run_to_stop(sim)
			_check(sim.state != BallSim.State.IN_WATER, "%s pad at %d doesn't fire into water (ended at %d)" % [hole.display_name, int(pad.x), int(sim.pos.x)])


func _test_rotated_hazards() -> void:
	var made: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "rotation": 45.0, "turn_speed": 0.0 })
	var mill: WindmillObstacle = made["obstacle"]
	var expected: Vector2 = mill.base() + Vector2(sin(PI / 4.0), -cos(PI / 4.0)) * WindmillObstacle.TOWER_HEIGHT
	_check(mill.hub().distance_to(expected) < 0.01, "a rotated windmill's hub moves with its tower")

	# A ball on the tower's new line hits it, and a ball where it used to stand doesn't.
	var sim: BallSim = made["sim"]
	var midway: Vector2 = (mill.base() + mill.hub()) / 2.0
	_start_ball(sim, midway - Vector2(40, 0), Vector2(200, -1))
	sim.ignore_moving = true
	for _i in 20:
		sim.step(DT)
	_check(sim.vel.x < 150.0, "the tilted tower deflects the ball (%.0f)" % sim.vel.x)
	var clear: BallSim = _hazard_sim({ "kind": "windmill", "x": 300.0, "rotation": 45.0, "turn_speed": 0.0 })["sim"]
	_start_ball(clear, Vector2(260, 270), Vector2(200, -60))
	clear.ignore_moving = true
	for _i in 20:
		clear.step(DT)
	_check(clear.vel.x > 0.0, "the space the tower leaned away from is open")

	var jet: Dictionary = _hazard_sim({ "kind": "sprinkler", "x": 300.0, "rotation": 60.0, "height": 70.0 })
	var jet_sim: BallSim = jet["sim"]
	var on_jet: SprinklerObstacle = jet["obstacle"]
	_start_ball(jet_sim, on_jet.base() + on_jet.direction * 30.0, Vector2(0, -1))
	for _i in 10:
		jet_sim.step(DT)
	_check(jet_sim.vel.x > 30.0, "a tilted sprinkler sprays along its tilt (%.0f)" % jet_sim.vel.x)
	var missed: BallSim = _hazard_sim({ "kind": "sprinkler", "x": 300.0, "rotation": 90.0, "height": 70.0 })["sim"]
	_start_ball(missed, Vector2(300, 250), Vector2(0, -1))
	for _i in 5:
		missed.step(DT)
	_check(missed.vel.y > -1.0, "and doesn't spray straight up any more")


func _test_hole_files() -> void:
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		var original: HoleData = run.hole_at(i)
		var copy: HoleData = HoleIO.from_dict(JSON.parse_string(JSON.stringify(HoleIO.to_dict(original))))
		var original_terrain := Terrain.new(original)
		var copy_terrain := Terrain.new(copy)
		var same: bool = copy.par == original.par and copy.title == original.title \
				and is_equal_approx(copy.cup_x, original.cup_x) and is_equal_approx(copy.wind, original.wind) \
				and copy.obstacles.size() == original.obstacles.size() and copy.scenery == original.scenery
		for x in range(0, original_terrain.length, 25):
			if absf(copy_terrain.ground_y(float(x)) - original_terrain.ground_y(float(x))) > 0.01 \
					or copy_terrain.surface_at(float(x)) != original_terrain.surface_at(float(x)):
				same = false
		_check(same, "%s survives being saved and loaded" % original.display_name)

	_check(HoleIO.from_dict(null) == null, "nothing isn't a map")
	_check(HoleIO.from_dict({ "points": [[0, 300]] }) == null, "one point isn't a map")
	_check(HoleIO.from_dict("garbage") == null, "text isn't a map")
	var messy: HoleData = HoleIO.from_dict({
		"points": [[0, 300], [0, 200], [100, 300], [90, 100], ["x", 2], [500, 9999]],
		"par": 999,
		"cup_x": 99999,
		"surface_spans": [{ "from": 0, "to": 10, "type": 99 }, "junk", { "from": 0, "to": 50, "type": 2 }],
		"obstacles": [{ "kind": "dragon", "x": 3 }, { "kind": "pad" }, { "kind": "pad", "x": 50.0 }, 7],
	})
	_check(messy != null, "a damaged map is cleaned up")
	_check(messy.points.size() == 3, "bad points are dropped (%d)" % messy.points.size())
	_check(messy.par == 12 and messy.cup_x <= 490.0, "wild numbers are limited")
	_check(messy.surface_spans.size() == 1, "bad surfaces are dropped")
	_check(messy.obstacles.size() == 1, "unknown and incomplete objects are dropped")
	var messy_game := HoleGame.new(messy, _clubs())
	messy_game.tick(DT)
	_check(messy_game.phase == HoleGame.Phase.AIM, "a cleaned-up map can be played")

	# Maps saved when trees were one piece split up on loading.
	var old_map: HoleData = HoleIO.from_dict({
		"points": [[0, 300], [1000, 300]],
		"trees": [200.0, 500.0, 800.0, "junk"],
	})
	_check(old_map.scenery.size() == 6, "each old tree becomes two pieces (%d)" % old_map.scenery.size())
	_check(str(old_map.scenery[0]["kind"]) == "trunk" and str(old_map.scenery[1]["kind"]) == "leaves", "a tree splits into a trunk and leaves")
	_check(float(old_map.scenery[0]["x"]) == 200.0 and float(old_map.scenery[1]["x"]) == 200.0, "the pieces start together")
	_check(int(old_map.scenery[3]["variant"]) == 1, "old trees keep their different leaf shapes")
	var odd_scenery: HoleData = HoleIO.from_dict({
		"points": [[0, 300], [1000, 300]],
		"scenery": [{ "kind": "leaves", "x": 50, "variant": 99 }, { "kind": "dragon", "x": 3 }, { "kind": "trunk" }, 5],
	})
	_check(odd_scenery.scenery.size() == 1 and int(odd_scenery.scenery[0]["variant"]) == 2, "bad scenery is cleaned up")


func _clean_library() -> MapLibrary:
	var path: String = "user://test_maps"
	var absolute: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [absolute, file_name])
	return MapLibrary.new(path)


func _test_map_library() -> void:
	var library: MapLibrary = _clean_library()
	var ids: Array[String] = library.list_ids()
	_check(ids.size() == 10 and ids[0] == "hole_01" and ids[9] == "hole_boss", "the originals are all listed")
	_check(library.course_order() == ids, "the course starts as the originals in order")
	_check(library.kind_of("hole_03") == MapLibrary.Kind.ORIGINAL, "an untouched hole is an original")

	# Editing an original saves a copy, and restoring brings the original back.
	var original_par: int = library.load_hole("hole_03").par
	var edited: HoleData = library.load_hole("hole_03")
	edited.par = 9
	edited.title = "MY RIDGE"
	_check(library.save_hole("hole_03", edited), "an original can be edited")
	_check(library.kind_of("hole_03") == MapLibrary.Kind.EDITED, "it then counts as edited")
	_check(library.load_hole("hole_03").par == 9, "the edit is what loads")
	_check((load("res://data/holes/hole_03.tres") as HoleData).par == original_par, "the original itself is untouched")
	library.restore_original("hole_03")
	_check(library.kind_of("hole_03") == MapLibrary.Kind.ORIGINAL, "restoring removes the edit")
	_check(library.load_hole("hole_03").par == original_par, "restoring brings the original back")

	# Loading gives a copy, so changing it doesn't reach the shared resource.
	library.load_hole("hole_04").par = 11
	_check(library.load_hole("hole_04").par != 11, "loaded maps are safe to change")

	# Custom maps.
	var id: String = library.new_custom_id()
	var blank: HoleData = HoleIO.blank_hole("MY MAP")
	_check(library.save_hole(id, blank), "a new map can be saved")
	_check(library.kind_of(id) == MapLibrary.Kind.CUSTOM, "it counts as custom")
	_check(library.list_ids().has(id), "it's listed")
	_check(library.new_custom_id() != id, "new maps get new ids")
	_check(library.load_hole(id).title == "MY MAP", "it loads back")

	# The course order.
	var order: Array[String] = [id, "hole_02"]
	library.save_course_order(order)
	_check(library.course_order() == order, "the course order is saved")
	var holes: Array[HoleData] = library.load_course()
	_check(holes.size() == 2, "the course loads its holes")
	_check(holes[0].display_name == "HOLE 1" and holes[0].title == "MY MAP", "holes are numbered by position")
	_check(holes[1].display_name == "BOSS HOLE", "the last hole is the boss")
	var run := CourseRun.from_holes(holes)
	_check(run.hole_count() == 2 and run.current_hole().title == "MY MAP", "a run plays the player's course")
	var single: Array[String] = [id]
	library.save_course_order(single)
	_check(library.load_course()[0].display_name == "HOLE 1", "a one-hole course has no boss")

	# Deleting.
	library.save_course_order(order)
	library.delete_map("hole_02")
	_check(library.is_original("hole_02") and library.load_hole("hole_02") != null, "originals can't be deleted")
	library.delete_map(id)
	_check(not library.list_ids().has(id), "custom maps can be deleted")
	_check(library.course_order() == (["hole_02"] as Array[String]), "a deleted map leaves the course")

	# A damaged file can't break anything.
	var bad_id: String = library.new_custom_id()
	var bad := FileAccess.open("user://test_maps/%s.json" % bad_id, FileAccess.WRITE)
	bad.store_string("{ not json at all")
	bad.close()
	_check(library.load_hole(bad_id) == null, "a damaged custom map reports as unreadable")
	var bad_original := FileAccess.open("user://test_maps/hole_05.json", FileAccess.WRITE)
	bad_original.store_string("[1, 2, 3]")
	bad_original.close()
	_check(library.load_hole("hole_05") != null, "a damaged edit falls back to the original")
	var bad_order := FileAccess.open("user://test_maps/course_order.json", FileAccess.WRITE)
	bad_order.store_string("oops")
	bad_order.close()
	_check(library.course_order().size() == 10, "a damaged course order falls back to the originals")
	_clean_library()


func _test_editor_ground_and_paint() -> void:
	var doc := EditorDoc.new(HoleIO.blank_hole("T"))
	var before: int = doc.hole.points.size()
	var index: int = doc.add_point(Vector2(500, 200))
	_check(index > 0 and doc.hole.points.size() == before + 1, "a ground point can be added")
	_check(absf(doc.terrain.ground_y(500.0) - 200.0) < 0.01, "the ground follows the new point")
	_check(doc.add_point(Vector2(503, 200)) == -1, "points can't crowd each other")
	_check(doc.add_point(Vector2(-5, 200)) == -1 and doc.add_point(Vector2(99999, 200)) == -1, "points stay on the map")

	doc.move_point(index, Vector2(520, 150))
	_check(doc.hole.points[index] == Vector2(520, 150), "a point can be dragged")
	doc.move_point(index, Vector2(99999, 150))
	_check(doc.hole.points[index].x < doc.hole.points[index + 1].x, "a point can't pass its neighbour")
	doc.move_point(0, Vector2(50, 320))
	_check(doc.hole.points[0].x == 0.0 and doc.hole.points[0].y == 320.0, "the first point stays at the left edge")
	doc.move_point(index, Vector2(500, -500))
	_check(doc.hole.points[index].y >= EditorDoc.MIN_Y, "the ground can't leave the world")

	var last: int = doc.hole.points.size() - 1
	doc.move_point(last, Vector2(2000, 300))
	_check(doc.terrain.length == 2000, "dragging the last point lengthens the hole")
	doc.move_point(last, Vector2(10, 300))
	_check(doc.length() >= EditorDoc.MIN_LENGTH, "a hole can't get too short")
	doc.hole.cup_x = 390.0
	doc.move_point(last, Vector2(float(EditorDoc.MIN_LENGTH), 300))
	_check(doc.hole.cup_x < doc.length() and doc.hole.tee_x < doc.length(), "the tee and cup stay on a shortened hole")

	var small := EditorDoc.new(HoleIO.blank_hole("T"))
	_check(not small.remove_point(0) and not small.remove_point(small.hole.points.size() - 1), "end points can't be removed")
	_check(small.remove_point(1), "a middle point can be removed")
	_check(not small.remove_point(1), "a hole keeps at least three points")

	var painted := EditorDoc.new(HoleIO.blank_hole("T"))
	painted.paint_surface(300.0, 400.0, Surface.Type.SAND)
	_check(painted.terrain.surface_at(350.0) == Surface.Type.SAND, "ground can be painted")
	_check(painted.terrain.surface_at(250.0) == Surface.Type.FAIRWAY, "paint stays in its stretch")
	var span_count: int = painted.hole.surface_spans.size()
	for _i in 20:
		painted.paint_surface(300.0, 400.0, Surface.Type.SAND)
	_check(painted.hole.surface_spans.size() == span_count, "repainting doesn't grow the file")
	painted.paint_surface(400.0, 300.0, Surface.Type.GREEN)
	_check(painted.terrain.surface_at(350.0) == Surface.Type.GREEN, "painting works dragging either way")
	painted.paint_surface(300.0, 400.0, Surface.Type.ROUGH)
	_check(painted.terrain.surface_at(350.0) == Surface.Type.ROUGH, "rough paint clears a surface")

	var wet := EditorDoc.new(HoleIO.blank_hole("T"))
	wet.hole.points = PackedVector2Array([Vector2(0, 300), Vector2(400, 300), Vector2(500, 380), Vector2(600, 300), Vector2(1200, 300)])
	wet.rebake()
	wet.paint_surface(400.0, 600.0, Surface.Type.WATER)
	_check(wet.terrain.surface_at(500.0) == Surface.Type.WATER, "water fills a dip")
	_check(absf(wet.terrain.ground_y(500.0) - 300.0) < 1.0, "water rises to its edges")
	wet.paint_surface(480.0, 520.0, Surface.Type.SAND)
	_check(wet.terrain.surface_at(500.0) != Surface.Type.WATER, "painting over water drains that stretch")
	_check(wet.terrain.surface_at(450.0) == Surface.Type.WATER and wet.terrain.surface_at(550.0) == Surface.Type.WATER, "the rest of the water stays")
	_check(wet.hole.water_spans.size() == 2, "the water splits around the paint")


func _test_editor_objects() -> void:
	var doc := EditorDoc.new(HoleIO.blank_hole("T"))
	for kind: String in ["pad", "cart", "windmill", "sprinkler", "goose", "trunk", "leaves"]:
		var selection: Dictionary = doc.add_object(kind, Vector2(500, 250))
		var center: Vector2 = doc.selection_center(selection)
		_check(not doc.pick(center, 4.0).is_empty(), "a placed %s can be clicked" % kind)
		doc.move_selection(selection, center + Vector2(100, 0))
		_check(absf(doc.selection_center(selection).x - (center.x + 100.0)) < 1.0, "a %s can be moved" % kind)
	_check(doc.hole.obstacles.size() == 5 and doc.hole.scenery.size() == 2, "everything was added")
	_check(Obstacle.build_all(doc.hole, doc.terrain).size() == 5, "every placed object builds")

	# Rotation: pads, windmills and sprinklers only.
	var by_kind: Dictionary = {}
	for i in doc.hole.obstacles.size():
		by_kind[str(doc.hole.obstacles[i]["kind"])] = { "type": "obstacle", "index": i }
	for kind: String in ["pad", "windmill", "sprinkler"]:
		_check(doc.can_rotate(by_kind[kind]), "a %s can rotate" % kind)
		doc.set_rotation(by_kind[kind], 40.0)
		_check(is_equal_approx(doc.rotation_of(by_kind[kind]), 40.0), "a %s remembers its rotation" % kind)
	for kind: String in ["cart", "goose"]:
		_check(not doc.can_rotate(by_kind[kind]), "a %s can't rotate" % kind)
		doc.set_rotation(by_kind[kind], 40.0)
		_check(not doc.entry_of(by_kind[kind]).has("rotation"), "a %s ignores rotation" % kind)
	_check(not doc.can_rotate({ "type": "tee" }) and not doc.can_rotate({}), "the tee and nothing can't rotate")

	doc.set_rotation(by_kind["pad"], 22.0, true)
	_check(is_equal_approx(doc.rotation_of(by_kind["pad"]), 15.0), "rotation snaps to 15 degrees")
	doc.set_rotation(by_kind["pad"], 200.0)
	_check(is_equal_approx(doc.rotation_of(by_kind["pad"]), -160.0), "rotation wraps around")

	var pad_entry: Dictionary = doc.entry_of(by_kind["pad"])
	var built: BouncePadObstacle = BouncePadObstacle.new(doc.terrain, pad_entry)
	_check(is_equal_approx(built.rotation_deg, -160.0), "the rotation reaches the real pad")

	# A pad can go anywhere, including in mid-air.
	doc.move_selection(by_kind["pad"], Vector2(700, 100))
	_check(doc.selection_center(by_kind["pad"]) == Vector2(700, 100), "a pad can be placed in mid-air")

	# Routes.
	var cart: Dictionary = by_kind["cart"]
	doc.move_route_end(cart, 1, 900.0)
	_check(is_equal_approx(float(doc.entry_of(cart)["to"]), 900.0), "a cart's route can be changed")
	doc.move_route_end(cart, 1, -500.0)
	_check(float(doc.entry_of(cart)["to"]) > float(doc.entry_of(cart)["from"]), "a route's ends can't cross")
	var goose: Dictionary = by_kind["goose"]
	var goose_y: float = doc.route_ends(goose)[0].y
	doc.move_route_end(goose, 0, 200.0)
	_check(absf(doc.route_ends(goose)[0].y - goose_y) < 1.0, "a goose keeps its height when its route changes")

	# The settings panel: every row must really change something.
	doc.move_route_end(cart, 1, 1000.0)
	doc.move_route_end(goose, 1, 1000.0)
	for selection: Dictionary in [{}, by_kind["pad"], by_kind["cart"], by_kind["windmill"], by_kind["sprinkler"], by_kind["goose"], { "type": "tee" }, { "type": "cup" }]:
		for row: Dictionary in doc.properties(selection):
			var next: float = clampf(float(row["value"]) + float(row["step"]), float(row["min"]), float(row["max"]))
			if next == float(row["value"]):
				next = clampf(float(row["value"]) - float(row["step"]), float(row["min"]), float(row["max"]))
			doc.set_property(selection, str(row["key"]), next)
			var changed: float = 0.0
			for after: Dictionary in doc.properties(selection):
				if after["key"] == row["key"]:
					changed = float(after["value"])
			_check(absf(changed - next) < 0.01, "setting %s on %s works (%.1f, wanted %.1f)" % [row["key"], str(selection.get("type", "hole")), changed, next])

	var water_doc := EditorDoc.new(HoleIO.blank_hole("T"))
	water_doc.hole.points = PackedVector2Array([Vector2(0, 300), Vector2(400, 300), Vector2(500, 380), Vector2(600, 300), Vector2(1200, 300)])
	water_doc.rebake()
	water_doc.paint_water(400.0, 600.0)
	var water: Dictionary = water_doc.pick(Vector2(500, 340), 2.0)
	_check(water.get("type") == "water", "water can be selected")
	water_doc.set_property(water, "level", 340.0)
	_check(absf(water_doc.terrain.ground_y(500.0) - 340.0) < 0.01, "the water level can be set")
	water_doc.delete_selection(water)
	_check(water_doc.terrain.surface_at(500.0) != Surface.Type.WATER, "water can be removed")

	# Deleting.
	var count: int = doc.hole.obstacles.size()
	_check(doc.can_delete(by_kind["pad"]) and not doc.can_delete({ "type": "tee" }) and not doc.can_delete({ "type": "cup" }), "the tee and cup can't be deleted")
	doc.delete_selection({ "type": "obstacle", "index": 0 })
	_check(doc.hole.obstacles.size() == count - 1, "objects can be deleted")
	doc.delete_selection({ "type": "scenery", "index": 0 })
	doc.delete_selection({ "type": "scenery", "index": 0 })
	_check(doc.hole.scenery.is_empty(), "tree pieces can be deleted")

	# A map made entirely in the editor plays, saves and loads.
	var made := EditorDoc.new(HoleIO.blank_hole("MADE"))
	made.add_object("pad", Vector2(500, 200))
	made.add_object("windmill", Vector2(650, 280))
	made.add_object("sprinkler", Vector2(760, 280))
	made.add_object("cart", Vector2(400, 280))
	made.add_object("goose", Vector2(300, 200))
	made.add_point(Vector2(600, 260))
	_check(made.warnings().is_empty(), "a sensible map has no warnings (%s)" % str(made.warnings()))
	var reloaded: HoleData = HoleIO.from_dict(JSON.parse_string(JSON.stringify(HoleIO.to_dict(made.hole))))
	_check(reloaded.obstacles.size() == 5, "a made map keeps its objects")
	_check(_play_round(reloaded, RandomNumberGenerator.new(), 0.0, 0.0) > 0, "a made map can be played to the end")

	# Warnings.
	var bad := EditorDoc.new(HoleIO.blank_hole("BAD"))
	bad.paint_surface(900.0, 1100.0, Surface.Type.FAIRWAY)
	_check(bad.warnings().has("CUP IS NOT ON GREEN"), "a cup off the green is flagged")
	bad.hole.tee_x = bad.hole.cup_x - 10.0
	_check(bad.warnings().has("TEE IS TOO NEAR CUP"), "a tee by the cup is flagged")


func _test_editor_undo() -> void:
	var doc := EditorDoc.new(HoleIO.blank_hole("T"))
	_check(not doc.dirty and not doc.can_undo(), "a fresh map has nothing to undo")
	doc.checkpoint()
	doc.add_object("pad", Vector2(500, 200))
	_check(doc.dirty, "a change marks the map unsaved")
	doc.checkpoint()
	doc.add_object("cart", Vector2(500, 200))
	doc.undo()
	_check(doc.hole.obstacles.size() == 1, "undo removes the last change")
	doc.undo()
	_check(doc.hole.obstacles.is_empty(), "undo goes further back")
	_check(not doc.can_undo() and doc.can_redo(), "undo stops at the start")
	doc.redo()
	doc.redo()
	_check(doc.hole.obstacles.size() == 2, "redo brings changes back")
	doc.undo()
	doc.checkpoint()
	doc.add_object("goose", Vector2(500, 200))
	_check(not doc.can_redo(), "a new change clears redo")

	var ground := EditorDoc.new(HoleIO.blank_hole("T"))
	var ground_y: float = ground.terrain.ground_y(500.0)
	ground.checkpoint()
	ground.add_point(Vector2(500, 150))
	ground.undo()
	_check(is_equal_approx(ground.terrain.ground_y(500.0), ground_y), "undo restores the ground too")

	var many := EditorDoc.new(HoleIO.blank_hole("T"))
	for i in EditorDoc.UNDO_LIMIT + 20:
		many.checkpoint()
		many.hole.par = i % 9 + 1
	var steps: int = 0
	while many.can_undo():
		many.undo()
		steps += 1
	_check(steps == EditorDoc.UNDO_LIMIT, "undo history has a limit (%d)" % steps)


func _test_ball_against_a_post_can_escape() -> void:
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.obstacles = [{ "kind": "windmill", "x": 600.0, "turn_speed": 0.0 }]
	var game := HoleGame.new(hole, _clubs())
	for start_x: float in [591.0]:
		game.ball.place(start_x)
		game._begin_aim()
		game.select_club(1)
		var sim: BallSim = game.new_preview_sim()
		var shot: Dictionary = game.shot_for(0.5, 0.0)
		sim.launch(shot["velocity"], 0.0)
		_run_to_stop(sim)
		_check(sim.pos.x > start_x + 60.0, "a ball resting against a post can play past it (%.0f)" % sim.pos.x)


func _test_plays_away_when_blocked() -> void:
	var game := HoleGame.new(load("res://data/holes/hole_08.tres") as HoleData, _clubs())
	game.ball.place(685.0)
	game._begin_aim()
	_check(game.is_playing_away(), "with no way across the pond, the golfer plays back")
	_check(_has_safe_shot(game), "playing back is a safe shot")
	_check(game.current_club().id == "iron", "playing back offers the iron, not a full driver")
	game.ball.place(300.0)
	game._begin_aim()
	_check(not game.is_playing_away(), "with a clear shot, the golfer faces the cup")


func _hazard_sim(entry: Dictionary, cup_x: float = 990.0) -> Dictionary:
	var hole: HoleData = _flat_hole({ "cup_x": cup_x })
	hole.obstacles = [entry]
	var terrain := Terrain.new(hole)
	var obstacles: Array[Obstacle] = Obstacle.build_all(hole, terrain)
	var sim := BallSim.new(terrain)
	sim.obstacles = obstacles
	return { "sim": sim, "obstacle": obstacles[0] }


func _test_cart() -> void:
	var made: Dictionary = _hazard_sim({ "kind": "cart", "from": 300.0, "to": 400.0, "speed": 50.0 })
	var cart: CartObstacle = made["obstacle"]
	for _i in 60:
		cart.tick(DT)
	_check(absf(cart.x - 350.0) < 1.0, "the cart drives along its path (%.0f)" % cart.x)
	for _i in 180:
		cart.tick(DT)
	_check(cart.direction < 0.0 and cart.x >= 300.0 and cart.x <= 400.0, "the cart turns around at the end of its path")

	var sim: BallSim = made["sim"]
	cart.x = 300.0
	cart.direction = 1.0
	sim.place(250.0)
	sim.launch(Vector2(150.0, 0.0), 0.0)
	var hits: Array[String] = []
	sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: hits.append(kind))
	_run_to_stop(sim)
	_check(hits.size() >= 1 and hits[0] == "cart", "a rolling ball hits the cart")
	_check(sim.pos.x < 300.0, "the cart stops a rolling ball (%.0f)" % sim.pos.x)

	# The cart is bigger than the golfer, and it's solid where it looks solid.
	_check(CartObstacle.DRAWN_HEIGHT > 32.0 * 1.3, "the cart is clearly taller than the golfer")
	_check(CartObstacle.DRAWN_HALF_WIDTH * 2.0 > 32.0 * 1.5, "the cart is clearly longer than the golfer is tall")
	var body_reach: float = CartObstacle.HALF_LENGTH + CartObstacle.RADIUS
	_check(absf(body_reach - CartObstacle.DRAWN_HALF_WIDTH) <= 2.0, "its body collision matches its drawn length")
	var roof_top: float = CartObstacle.RIDE_HEIGHT + CartObstacle.ROOF_RISE + CartObstacle.ROOF_RADIUS
	_check(absf(roof_top - CartObstacle.DRAWN_HEIGHT) <= 2.0, "its roof collision matches its drawn height")

	var sized: Dictionary = _hazard_sim({ "kind": "cart", "from": 400.0, "to": 400.0, "speed": 0.0 })
	var roof_sim: BallSim = sized["sim"]
	var parked: CartObstacle = sized["obstacle"]
	var roof_y: float = parked.center().y - CartObstacle.ROOF_RISE
	_start_ball(roof_sim, Vector2(400, roof_y - 30.0), Vector2(0, 100))
	for _i in 30:
		roof_sim.step(DT)
		if roof_sim.vel.y < 0.0:
			break
	_check(roof_sim.vel.y < 0.0 and roof_sim.pos.y < roof_y, "a ball dropping onto the roof bounces off it")
	var over_sim: BallSim = _hazard_sim({ "kind": "cart", "from": 400.0, "to": 400.0, "speed": 0.0 })["sim"]
	_start_ball(over_sim, Vector2(340, roof_y - 20.0), Vector2(200, -40))
	for _i in 30:
		over_sim.step(DT)
	_check(over_sim.vel.x > 190.0 and over_sim.pos.x > 440.0, "a ball flying over the roof is untouched")
	var side_sim: BallSim = _hazard_sim({ "kind": "cart", "from": 400.0, "to": 400.0, "speed": 0.0 })["sim"]
	_start_ball(side_sim, Vector2(340, 290), Vector2(200, -1))
	for _i in 30:
		side_sim.step(DT)
	_check(side_sim.pos.x < 372.0, "the wider body stops a low shot at its end (%.0f)" % side_sim.pos.x)

	# Clicking anywhere on the bigger cart selects it in the editor.
	var pick_doc := EditorDoc.new(HoleIO.blank_hole("T"))
	var picked_cart: Dictionary = pick_doc.add_object("cart", Vector2(500, 290))
	var pick_center: Vector2 = pick_doc.selection_center(picked_cart)
	var ground_y: float = pick_center.y + CartObstacle.RIDE_HEIGHT
	_check(pick_doc.pick(Vector2(pick_center.x, ground_y - 42.0), 2.0) == picked_cart, "clicking its roof selects it")
	_check(pick_doc.pick(Vector2(pick_center.x + 28.0, ground_y - 12.0), 2.0) == picked_cart, "clicking its nose selects it")
	_check(pick_doc.pick(Vector2(pick_center.x - 28.0, ground_y - 12.0), 2.0) == picked_cart, "clicking its back selects it")
	_check(pick_doc.pick(Vector2(pick_center.x, ground_y - 80.0), 2.0).is_empty(), "clicking above it doesn't")

	# A cart catching up with a slow ball must not shove it along the whole path.
	var chase: Dictionary = _hazard_sim({ "kind": "cart", "from": 200.0, "to": 900.0, "speed": 60.0 })
	var chaser: CartObstacle = chase["obstacle"]
	var chase_sim: BallSim = chase["sim"]
	var chase_hits: Array[String] = []
	chase_sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: chase_hits.append(kind))
	chaser.x = 240.0
	chase_sim.place(290.0)
	chase_sim.launch(Vector2(20.0, 0.0), 0.0)
	var guard: int = 0
	while chase_sim.is_moving() and guard < 1000:
		chaser.tick(DT)
		chase_sim.step(DT)
		guard += 1
	_check(chase_hits.size() <= 1, "a cart hits the ball once per shot (%d)" % chase_hits.size())
	_check(not chase_sim.is_moving() and guard < 600, "the ball settles instead of being pushed along (%d)" % guard)
	_check(chase_sim.pos.x < 500.0, "the cart doesn't carry the ball away (%.0f)" % chase_sim.pos.x)


func _test_windmill() -> void:
	var made: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 1.0 })
	var mill: WindmillObstacle = made["obstacle"]
	var start_tip: Vector2 = mill.blade_tip(0)
	mill.tick(0.5)
	_check(mill.blade_tip(0) != start_tip, "the blades turn")

	var sim: BallSim = made["sim"]
	sim.place(260.0)
	sim.launch(Vector2(120.0, 0.0), 0.0)
	_run_to_stop(sim)
	_check(sim.pos.x < 300.0, "the tower blocks a rolling ball (%.0f)" % sim.pos.x)

	# Parks a blade pointing straight at an incoming ball, then the reverse.
	var blade: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 0.0 })
	var still: WindmillObstacle = blade["obstacle"]
	var blade_sim: BallSim = blade["sim"]
	still.angle = deg_to_rad(45.0)
	blade_sim.place(280.0)
	blade_sim.pos = Vector2(280.0, still.hub().y + 20.0)
	blade_sim.launch(Vector2(0.0, -80.0), 0.0)
	var hits: Array[String] = []
	blade_sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: hits.append(kind))
	for _i in 30:
		blade_sim.step(DT)
	_check(not hits.is_empty(), "a blade knocks the ball away")

	var preview: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 0.0 })
	var preview_mill: WindmillObstacle = preview["obstacle"]
	var preview_sim: BallSim = preview["sim"]
	preview_sim.ignore_moving = true
	preview_mill.angle = 0.0
	preview_sim.place(260.0)
	preview_sim.pos.y = preview_mill.hub().y
	preview_sim.launch(Vector2(200.0, -1.0), 0.0)
	preview_sim.step(DT * 6.0)
	_check(preview_sim.vel.x > 0.0, "previews skip the blades")
	preview_sim.pos = Vector2(290.0, preview_mill.ground - 10.0)
	preview_sim.vel = Vector2(200.0, 0.0)
	preview_sim.state = BallSim.State.AIRBORNE
	preview_sim.step(DT * 2.0)
	_check(preview_sim.vel.x < 0.0, "previews still see the solid tower")


func _test_sprinkler() -> void:
	var made: Dictionary = _hazard_sim({ "kind": "sprinkler", "x": 300.0, "height": 70.0, "on_time": 1.0, "off_time": 1.0 })
	var sprinkler: SprinklerObstacle = made["obstacle"]
	var sim: BallSim = made["sim"]
	_check(sprinkler.is_on(), "the sprinkler starts on")
	sim.place(298.0)
	sim.launch(Vector2(0.1, -1.0), 0.0)
	for _i in 10:
		sim.step(DT)
	_check(sim.vel.y < 0.0 and sim.pos.y < 298.0 - 3.0, "the jet lifts the ball (%.1f)" % sim.pos.y)

	sprinkler.tick(1.2)
	_check(not sprinkler.is_on(), "the sprinkler switches off")
	var off_sim: BallSim = _hazard_sim({ "kind": "sprinkler", "x": 300.0, "height": 70.0, "offset": 3.0 })["sim"]
	off_sim.place(298.0)
	off_sim.pos.y = 260.0
	off_sim.launch(Vector2(0.1, -1.0), 0.0)
	for _i in 10:
		off_sim.step(DT)
	_check(off_sim.vel.y > 0.0, "with the jet off, the ball just falls")

	var settle: BallSim = _hazard_sim({ "kind": "sprinkler", "x": 300.0, "height": 70.0 })["sim"]
	settle.place(298.0)
	settle.launch(Vector2(5.0, -5.0), 0.0)
	_run_to_stop(settle)
	_check(not settle.is_moving(), "a ball can't hover in a jet forever")
	_check(absf(settle.pos.x - 300.0) > SprinklerObstacle.HALF_WIDTH, "the jet pushes it out (%.0f)" % settle.pos.x)


func _test_goose() -> void:
	var made: Dictionary = _hazard_sim({ "kind": "goose", "from": 300.0, "to": 400.0, "start": 350.0, "height": 60.0, "speed": 50.0 })
	var goose: GooseObstacle = made["obstacle"]
	var start_x: float = goose.x
	goose.tick(0.5)
	_check(goose.x != start_x, "the goose flies")
	for _i in 600:
		goose.tick(DT)
	_check(goose.x >= 300.0 and goose.x <= 400.0, "the goose stays on its route")

	var sim: BallSim = made["sim"]
	sim.place(goose.x - 30.0)
	sim.pos.y = goose.center().y
	sim.launch(Vector2(250.0, -1.0), 0.0)
	var hits: Array[String] = []
	sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: hits.append(kind))
	for _i in 25:
		sim.step(DT)
		goose.tick(DT)
	_check(hits.has("goose"), "a ball can hit a goose")
	_check(sim.vel.x < 150.0, "the goose takes the speed off it (%.0f)" % sim.vel.x)


func _test_wind() -> void:
	var results: Array[float] = []
	for wind: float in [0.0, 12.0, -12.0]:
		var sim := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 990.0 })))
		sim.wind = wind
		sim.place(300.0)
		sim.launch(Vector2(200.0, -180.0), 0.0)
		var guard: int = 0
		while sim.bounce_count == 0 and guard < 2000:
			sim.step(DT)
			guard += 1
		results.append(sim.pos.x)
	_check(results[1] > results[0] + 10.0, "a tailwind carries the ball further (%.0f vs %.0f)" % [results[1], results[0]])
	_check(results[2] < results[0] - 10.0, "a headwind holds it up (%.0f vs %.0f)" % [results[2], results[0]])

	var rolling := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 990.0 })))
	rolling.wind = 50.0
	rolling.place(300.0)
	rolling.launch(Vector2(60.0, 0.0), 0.0)
	_run_to_stop(rolling)
	var still := BallSim.new(Terrain.new(_flat_hole({ "cup_x": 990.0 })))
	still.place(300.0)
	still.launch(Vector2(60.0, 0.0), 0.0)
	_run_to_stop(still)
	_check(is_equal_approx(rolling.pos.x, still.pos.x), "wind doesn't push a rolling ball")

	var calm_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	var windy_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	windy_hole.wind = 15.0
	var calm := HoleGame.new(calm_hole, _clubs())
	var windy := HoleGame.new(windy_hole, _clubs())
	calm.select_club(1)
	windy.select_club(1)
	var calm_x: float = Vector2(calm.preview()["landing"]).x
	var windy_x: float = Vector2(windy.preview()["landing"]).x
	_check(windy_x > calm_x, "the aim preview shows the wind")
	windy.strike_with(1.0, 0.0)
	_check(is_equal_approx(windy.ball.wind, 15.0), "the real shot feels the wind")


func _test_preview_ignores_moving_hazards() -> void:
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.obstacles = [{ "kind": "cart", "from": 300.0, "to": 300.0, "speed": 0.0 }]
	var game := HoleGame.new(hole, _clubs())
	var sim: BallSim = game.new_preview_sim()
	sim.place(250.0)
	sim.launch(Vector2(120.0, 0.0), 0.0)
	_run_to_stop(sim)
	_check(sim.pos.x > 300.0, "previews roll through a cart (%.0f)" % sim.pos.x)
	_check(game.ball.ignore_moving == false, "the real ball still hits moving hazards")


func _test_course_progression() -> void:
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	_check(run.hole_count() == 10, "the course has 9 holes and a boss hole")
	_check(run.hole_at(0).display_name == "HOLE 1", "the course starts on hole 1")
	_check(run.hole_at(9).display_name == "BOSS HOLE", "the course ends on the boss hole")
	_check(not run.is_last_hole(), "hole 1 isn't the last hole")

	run.record_score(5)
	run.advance()
	_check(run.hole_index == 1 and run.total_strokes() == 5, "advancing keeps the score")
	_check(run.total_to_par() == 1, "the total compares to par on finished holes only")
	_check(CourseRun.to_par_text(run.total_to_par()) == "+1", "over par shows a plus")
	run.record_score(2)
	_check(CourseRun.to_par_text(run.total_to_par()) == "E", "even par shows E")
	_check(CourseRun.to_par_text(-2) == "-2", "under par shows a minus")

	while not run.is_last_hole():
		run.advance()
	_check(run.current_hole().display_name == "BOSS HOLE", "progress reaches the boss hole")
	run.advance()
	_check(run.hole_index == 0 and run.scores.is_empty(), "finishing the boss hole starts a new round")

	run.jump_by(-1)
	_check(run.hole_index == 9, "reviewing wraps around the course")

	var game: HoleGame = _game()
	var presses: Array[bool] = []
	game.continue_requested.connect(func() -> void: presses.append(true))
	game._set_phase(HoleGame.Phase.COMPLETE)
	game.press_swing()
	_check(presses.size() == 1, "a finished hole asks to continue")


func _test_every_hole_is_valid() -> void:
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	var kinds: Dictionary = {}
	var par_total: int = 0
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		var terrain := Terrain.new(hole)
		var label: String = hole.display_name
		par_total += hole.par
		_check(hole.title != "", "%s has a title" % label)
		_check(hole.par >= 3 and hole.par <= 7, "%s has a sensible par" % label)
		_check(terrain.surface_at(hole.tee_x) == Surface.Type.TEE, "%s tees off from a tee" % label)
		_check(terrain.surface_at(hole.cup_x) == Surface.Type.GREEN, "%s has its cup on a green" % label)
		_check(terrain.surface_at(hole.cup_x - 30.0) == Surface.Type.GREEN, "%s has green before the cup" % label)
		_check(absf(terrain.slope(hole.cup_x - 20.0)) < 0.28, "%s has a green that can hold a ball" % label)
		_check(not hole.scenery.is_empty(), "%s has trees" % label)
		for piece: Dictionary in hole.scenery:
			_check(absf(float(piece["x"]) - hole.tee_x) > 45.0, "%s has no tree on the tee" % label)
			_check(absf(float(piece["x"]) - hole.cup_x) > 60.0, "%s has no tree on the pin" % label)
		for obstacle in Obstacle.build_all(hole, terrain):
			kinds[obstacle.kind] = maxi(int(kinds.get(obstacle.kind, -1)), 0)
			if not kinds.has("first_%s" % obstacle.kind):
				kinds["first_%s" % obstacle.kind] = i
	for kind: String in ["pad", "cart", "windmill", "sprinkler", "goose"]:
		_check(kinds.has(kind), "the course uses %s" % kind)
	_check(int(kinds["first_cart"]) >= 4, "moving hazards wait for the later holes")
	_check(run.hole_at(0).wind == 0.0 and run.hole_at(1).wind == 0.0, "early holes have no wind")
	_check(run.hole_at(8).wind != 0.0, "later holes have wind")
	print("Course par: %d (9 holes and boss)" % par_total)


func _test_every_hole_is_playable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		var perfect: int = _play_round(hole, rng, 0.0, 0.0)
		_check(perfect > 0, "%s can be finished by a perfect player" % hole.display_name)
		var rounds: int = 6
		var total: int = 0
		var worst: int = 0
		var unfinished: int = 0
		for _r in rounds:
			var strokes: int = _play_round(hole, rng, 0.06, 0.05)
			if strokes < 0:
				unfinished += 1
				continue
			total += strokes
			worst = maxi(worst, strokes)
		var finished: int = rounds - unfinished
		var average: float = float(total) / float(maxi(finished, 1))
		print("%-10s par %d  perfect %2d  average %4.1f  worst %2d  unfinished %d  per round: %s" % [
			hole.display_name, hole.par, perfect, average, worst, unfinished, _events_text(rounds)])
		_round_events.clear()
		_check(unfinished == 0, "%s can be finished by an average player" % hole.display_name)
		# This player can't time moving hazards, so the limit is generous on purpose. The boss
		# hole is mostly timing, so its score here says little: it has to be judged by playing.
		if i < run.hole_count() - 1:
			_check(average <= float(hole.par) + 4.0, "%s isn't brutal for an average player (%.1f, par %d)" % [hole.display_name, average, hole.par])


func _events_text(rounds: int) -> String:
	var parts: Array[String] = []
	for key: String in _round_events.keys():
		parts.append("%s %.1f" % [key, float(_round_events[key]) / float(rounds)])
	return ", ".join(parts)


func _count_event(key: String) -> void:
	_round_events[key] = int(_round_events.get(key, 0)) + 1


# Returns the strokes taken, or -1 if the round hit the shot limit.
func _play_round(hole: HoleData, rng: RandomNumberGenerator, power_noise: float, timing_noise: float) -> int:
	var game := HoleGame.new(hole, _clubs())
	if power_noise > 0.0:
		game.penalty_taken.connect(func(kind: String) -> void: _count_event(kind))
		game.ball.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: _count_event(kind))
	var shots: int = 0
	var last_x: float = -1.0
	while game.phase != HoleGame.Phase.COMPLETE and shots < 25:
		var power: float = _best_power(game)
		if power_noise > 0.0:
			power = clampf(power + rng.randfn(0.0, power_noise), 0.02, 1.0)
		var accuracy: float = 0.0
		if timing_noise > 0.0:
			accuracy = SwingMeter.accuracy_for_cursor(rng.randfn(0.0, timing_noise), game.meter.perfect_window)
		# Back at the same spot means that plan failed, so take the shot that carries furthest.
		if is_equal_approx(game.ball.pos.x, last_x):
			power = _set_longest_safe_shot(game, power)
		last_x = game.ball.pos.x
		game.strike_with(power, accuracy)
		var steps: int = 0
		while game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.COMPLETE and steps < 4000:
			game.tick(DT)
			steps += 1
		shots += 1
	return game.strokes if game.phase == HoleGame.Phase.COMPLETE else -1


func _has_safe_shot(game: HoleGame) -> bool:
	for step_index in range(1, 11):
		var sim: BallSim = game.new_preview_sim()
		var shot: Dictionary = game.shot_for(float(step_index) * 0.1, 0.0)
		sim.launch(shot["velocity"], float(shot["spin"]))
		_run_to_stop(sim)
		if sim.state == BallSim.State.RESTING or sim.state == BallSim.State.HOLED:
			return true
	return false


# Chooses a shot the way a player would: tries each usable club at a few angles and
# powers, sets that club and angle on the game, and returns the power to use.
func _best_power(game: HoleGame) -> float:
	var best: Dictionary = { "club": game.club_index, "angle": game.aim_angle, "power": 1.0 }
	var best_distance: float = INF
	var playing_away: bool = game.is_playing_away()
	for club_index in game.clubs.size():
		var club: ClubData = game.clubs[club_index]
		if club.is_putter and game.lie_surface() != Surface.Type.GREEN:
			continue
		game.select_club(club_index)
		for angle: float in _angles_to_try(club):
			game.aim_angle = angle
			for step_index in range(1, 11):
				var power: float = float(step_index) * (0.05 if club.is_putter else 0.1)
				if club.is_putter:
					power = float(step_index) * 0.1
				var sim: BallSim = game.new_preview_sim()
				var shot: Dictionary = game.shot_for(power, 0.0)
				sim.launch(shot["velocity"], float(shot["spin"]))
				_run_to_stop(sim)
				if sim.state == BallSim.State.HOLED:
					return power
				if sim.state != BallSim.State.RESTING:
					continue
				# Playing back only needs a modest shot to a spot with a clear line.
				var distance: float = absf(game.hole.cup_x - sim.pos.x)
				if playing_away:
					distance = absf(absf(sim.pos.x - game.ball.pos.x) - 200.0)
				if distance < best_distance:
					best_distance = distance
					best = { "club": club_index, "angle": angle, "power": power }
	game.select_club(int(best["club"]))
	game.aim_angle = float(best["angle"])
	return float(best["power"])


# Sets up the safe shot that finishes furthest from where it started, and returns its power.
func _set_longest_safe_shot(game: HoleGame, fallback_power: float) -> float:
	var best_reach: float = -1.0
	var best: Dictionary = {}
	for club_index in game.clubs.size():
		var club: ClubData = game.clubs[club_index]
		if club.is_putter:
			continue
		game.select_club(club_index)
		for angle: float in [club.min_angle_deg, club.loft_deg, club.max_angle_deg, lerpf(club.loft_deg, club.max_angle_deg, 0.5)]:
			game.aim_angle = angle
			var sim: BallSim = game.new_preview_sim()
			var shot: Dictionary = game.shot_for(1.0, 0.0)
			sim.launch(shot["velocity"], 0.0)
			_run_to_stop(sim)
			var reach: float = absf(sim.pos.x - game.ball.pos.x)
			if sim.state == BallSim.State.RESTING and reach > best_reach:
				best_reach = reach
				best = { "club": club_index, "angle": angle }
	if best.is_empty():
		return fallback_power
	game.select_club(int(best["club"]))
	game.aim_angle = float(best["angle"])
	return 1.0


func _angles_to_try(club: ClubData) -> Array[float]:
	if club.is_putter:
		return [0.0]
	return [club.loft_deg, lerpf(club.loft_deg, club.max_angle_deg, 0.6), club.max_angle_deg]
