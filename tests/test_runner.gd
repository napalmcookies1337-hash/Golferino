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
	_test_trees_are_scenery()
	_test_bounce_pads()
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
	wooded.tree_xs = PackedFloat32Array([200.0, 240.0, 300.0, 360.0])
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


func _pad_sim(lean: float, x: float = 400.0) -> Dictionary:
	return _hazard_sim({ "kind": "pad", "x": x, "lean": lean })


# Drops a ball onto a pad from the left, and returns where it first lands afterwards.
func _shot_onto_pad(lean: float) -> Dictionary:
	var made: Dictionary = _pad_sim(lean)
	var sim: BallSim = made["sim"]
	var hits: Array[String] = []
	sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: hits.append(kind))
	sim.place(300.0)
	sim.pos.y = 300.0 - 60.0
	sim.launch(Vector2(90.0, -30.0), 0.0)
	var guard: int = 0
	while sim.bounce_count == 0 and sim.is_moving() and guard < 1200:
		sim.step(DT)
		guard += 1
	return { "x": sim.pos.x, "hits": hits, "pad": made["obstacle"] }


func _test_bounce_pads() -> void:
	var flat: Dictionary = _shot_onto_pad(0.0)
	var away: Dictionary = _shot_onto_pad(-35.0)
	var toward: Dictionary = _shot_onto_pad(35.0)
	_check(flat["hits"].has("pad") and away["hits"].has("pad") and toward["hits"].has("pad"), "balls land on all three kinds of pad")
	_check(float(away["x"]) < 385.0, "a pad angled away sends the ball backward (%.0f)" % float(away["x"]))
	_check(float(toward["x"]) > float(flat["x"]) + 50.0, "a pad angled toward the hole carries it further (%.0f vs %.0f)" % [float(toward["x"]), float(flat["x"])])
	_check(float(flat["x"]) > 420.0, "a flat pad bounces it up and onward (%.0f)" % float(flat["x"]))

	var no_pad: float = 300.0 + 90.0 * (30.0 + sqrt(900.0 + 2.0 * BallSim.GRAVITY * 58.0)) / BallSim.GRAVITY
	_check(float(toward["x"]) > no_pad + 100.0, "a helpful pad beats the same shot with no pad (%.0f vs %.0f)" % [float(toward["x"]), no_pad])

	var pad: BouncePadObstacle = toward["pad"]
	_check(pad.faces_cup(), "a pad leaning toward the cup knows it helps")
	var away_pad: BouncePadObstacle = away["pad"]
	_check(not away_pad.faces_cup(), "a pad leaning away knows it hurts")
	var flat_pad: BouncePadObstacle = flat["pad"]
	_check(flat_pad.is_flat() and not flat_pad.faces_cup(), "a flat pad faces neither way")

	# A rolling ball is launched by a flat pad.
	var roll_made: Dictionary = _pad_sim(0.0)
	var roll_sim: BallSim = roll_made["sim"]
	roll_sim.place(340.0)
	roll_sim.launch(Vector2(100.0, 0.0), 0.0)
	var peak: float = roll_sim.pos.y
	var guard: int = 0
	while roll_sim.is_moving() and guard < 1200:
		roll_sim.step(DT)
		peak = minf(peak, roll_sim.pos.y)
		guard += 1
	_check(peak < 300.0 - 60.0, "a flat pad launches a rolling ball (peak %.0f)" % peak)

	# Touching an angled pad from either side fires the ball the way it faces.
	var forward_made: Dictionary = _pad_sim(35.0)
	var forward_sim: BallSim = forward_made["sim"]
	forward_sim.place(340.0)
	forward_sim.launch(Vector2(100.0, 0.0), 0.0)
	_run_to_stop(forward_sim)
	_check(forward_sim.pos.x > 560.0, "rolling into a helpful pad fires it on toward the hole (%.0f)" % forward_sim.pos.x)

	var back_made: Dictionary = _pad_sim(-35.0)
	var back_sim: BallSim = back_made["sim"]
	back_sim.place(340.0)
	back_sim.launch(Vector2(100.0, 0.0), 0.0)
	_run_to_stop(back_sim)
	_check(back_sim.pos.x < 340.0, "rolling into a pad facing away fires it back (%.0f)" % back_sim.pos.x)

	# A ball on a slope can't get stuck against a pad: it fires a few times, then passes.
	var slope_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	slope_hole.points = PackedVector2Array([Vector2(0, 100), Vector2(500, 300), Vector2(1000, 300)])
	slope_hole.obstacles = [{ "kind": "pad", "x": 300.0, "lean": -35.0 }]
	var slope_terrain := Terrain.new(slope_hole)
	var slope_sim := BallSim.new(slope_terrain)
	slope_sim.obstacles = Obstacle.build_all(slope_hole, slope_terrain)
	var slope_hits: Array[String] = []
	slope_sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: slope_hits.append(kind))
	slope_sim.place(200.0)
	slope_sim.launch(Vector2(40.0, 0.0), 0.0)
	_run_to_stop(slope_sim)
	_check(not slope_sim.is_moving(), "a ball rolling downhill into a pad still settles")
	_check(slope_hits.size() <= BouncePadObstacle.MAX_USES_PER_SHOT + 1, "the pad fires a limited number of times (%d)" % slope_hits.size())

	# A ball coming straight down can't bounce on a flat pad forever.
	var pogo_made: Dictionary = _pad_sim(0.0)
	var pogo: BallSim = pogo_made["sim"]
	pogo.place(350.0)
	pogo.pos = Vector2(400.0, 250.0)
	pogo.launch(Vector2(0.0, 1.0), 0.0)
	pogo.launch_x = 300.0
	var steps: int = 0
	while pogo.is_moving() and steps < int(BallSim.MAX_MOTION_TIME * 60.0) - 60:
		pogo.step(DT)
		steps += 1
	_check(not pogo.is_moving(), "a ball can't bounce on a pad forever (%d steps)" % steps)
	var pogo_uses: int = pogo.pad_uses.get(pogo_made["obstacle"], 0)
	_check(pogo_uses >= 2 and pogo_uses <= BouncePadObstacle.MAX_USES_PER_SHOT, "the pad limits its repeat bounces (%d)" % pogo_uses)

	# A ball sitting on a pad can be played off it.
	var on_made: Dictionary = _pad_sim(-35.0)
	var on_sim: BallSim = on_made["sim"]
	on_sim.place(400.0)
	on_sim.launch(Vector2(150.0, -150.0), 0.0)
	_run_to_stop(on_sim)
	_check(on_sim.pos.x > 500.0, "a shot played from on a pad isn't fired back (%.0f)" % on_sim.pos.x)

	# The aim preview shows what a pad will do.
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.obstacles = [{ "kind": "pad", "x": 300.0, "lean": 35.0 }]
	var game := HoleGame.new(hole, _clubs())
	var sim: BallSim = game.new_preview_sim()
	sim.place(200.0)
	sim.launch(Vector2(100.0, 0.0), 0.0)
	var pad_used: Array[String] = []
	sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: pad_used.append(kind))
	_run_to_stop(sim)
	_check(pad_used.is_empty() or pad_used[0] == "pad", "previews include bounce pads")
	var in_preview: BouncePadObstacle = game.obstacles[0]
	_check(is_zero_approx(in_preview.squash), "previews don't make the real pad twitch")

	# Across the course, pads mostly point away from the hole, with some that help.
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
	_check(away_count > toward_count and toward_count > 0, "pads mostly point away, and sometimes help")
	_check(flat_count > 0, "some pads are flat")


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
		for x: float in hole.tree_xs:
			_check(absf(x - hole.tee_x) > 45.0, "%s has no tree on the tee" % label)
			_check(absf(x - hole.cup_x) > 60.0, "%s has no tree on the pin" % label)
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
	var repeats: int = 0
	while game.phase != HoleGame.Phase.COMPLETE and shots < 25:
		var power: float = _best_power(game)
		if power_noise > 0.0:
			power = clampf(power + rng.randfn(0.0, power_noise), 0.02, 1.0)
		var accuracy: float = 0.0
		if timing_noise > 0.0:
			accuracy = SwingMeter.accuracy_for_cursor(rng.randfn(0.0, timing_noise), game.meter.perfect_window)
		# Back at the same spot means that plan failed, so try something shorter.
		if is_equal_approx(game.ball.pos.x, last_x):
			repeats += 1
			power *= pow(0.75, float(repeats))
		else:
			repeats = 0
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


func _angles_to_try(club: ClubData) -> Array[float]:
	if club.is_putter:
		return [0.0]
	return [club.loft_deg, lerpf(club.loft_deg, club.max_angle_deg, 0.6), club.max_angle_deg]
