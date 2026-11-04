extends Node
## Rules tests. Run with: Godot --headless --path . res://tests/test_runner.tscn

const DT := 1.0 / 60.0
const HOLE_PATH := "res://data/holes/hole_01.tres"

var _passed: int = 0
var _failed: int = 0


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
	_test_flip_is_gone()
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
	game.ball.place(40.0)
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


func _test_flip_is_gone() -> void:
	Controls.register()
	_check(not InputMap.has_action("flip"), "there is no flip control")
	var game: HoleGame = _game()
	_check(not game.has_method("flip_facing"), "the game has no flip rule")
	game.ball.place(1510.0)
	game._begin_aim()
	_check(game.facing == -1, "past the pin, the golfer faces back toward the cup")


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
		var rounds: int = 30
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
	var game: HoleGame = _game()
	var traps: Array[int] = []
	for x in range(5, game.terrain.length - 5, 5):
		if game.terrain.surface_at(float(x)) == Surface.Type.WATER or game.terrain.in_cup(float(x)):
			continue
		game.ball.place(float(x))
		game._begin_aim()
		if not _has_safe_shot(game):
			traps.append(x)
	_check(traps.is_empty(), "no spot on the hole is a trap (traps at %s)" % str(traps))

	game.ball.place(977.0)
	game._begin_aim()
	_check(game.current_club().id == "iron", "the steep bank above the pond offers the iron")


func _has_safe_shot(game: HoleGame) -> bool:
	for step_index in range(1, 11):
		var sim := BallSim.new(game.terrain)
		sim.place(game.ball.pos.x)
		var shot: Dictionary = game.shot_for(float(step_index) * 0.1, 0.0)
		sim.launch(shot["velocity"], float(shot["spin"]))
		_run_to_stop(sim)
		if sim.state == BallSim.State.RESTING or sim.state == BallSim.State.HOLED:
			return true
	return false


func _best_power(game: HoleGame) -> float:
	var best_power: float = 1.0
	var best_distance: float = INF
	for step_index in range(1, 21):
		var power: float = float(step_index) * 0.05
		var sim := BallSim.new(game.terrain)
		sim.place(game.ball.pos.x)
		var shot: Dictionary = game.shot_for(power, 0.0)
		sim.launch(shot["velocity"], float(shot["spin"]))
		_run_to_stop(sim)
		var distance: float = absf(game.hole.cup_x - sim.pos.x)
		if sim.state == BallSim.State.HOLED:
			return power
		if sim.state != BallSim.State.RESTING:
			continue
		if distance < best_distance:
			best_distance = distance
			best_power = power
	return best_power
