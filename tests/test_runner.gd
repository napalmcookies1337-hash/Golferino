extends Node
## Rules tests. Run with: Godot --headless --path . --quit-after 12000 res://tests/test_runner.tscn

const DT := 1.0 / 60.0
const HOLE_PATH := "res://data/holes/hole_01.tres"
const COURSE_PATH := "res://data/course_01.tres"

var _passed: int = 0
var _failed: int = 0
var _round_events: Dictionary = {}


func _ready() -> void:
	_test_sound_files()
	_test_sound_settings()
	_test_time_of_day()
	_test_meter_flow()
	_test_meter_accuracy()
	_test_meter_auto_limits()
	_test_shot_quality_effects()
	_test_full_power()
	_test_double_tap_guard()
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
	_test_putting_is_two_presses()
	_test_aim_line_is_for_full_swings()
	_test_tree_pieces()
	_test_leaves_cover_trunks()
	_test_bounce_pads()
	_test_pads_never_fire_into_water()
	_test_rotated_hazards()
	_test_hole_files()
	_test_map_library()
	_test_editor_ground_and_paint()
	_test_editor_objects()
	_test_editor_undo()
	_test_ball_against_a_post_can_escape()
	_test_golfer_never_turns_alone()
	_test_stroke_budget()
	_test_budget_in_play()
	_test_coins_and_payouts()
	_test_coin_pickups()
	_test_trick_shots()
	_test_stickers()
	_test_overdrive()
	_test_special_balls()
	_test_shop_stock()
	_test_shop_reroll()
	_test_prices_climb()
	_test_buying()
	_test_perks()
	_test_item_catalog()
	_test_final_score()
	_test_profile()
	_test_maps_gain_coins()
	_test_duel_rules()
	_test_rival_cheats()
	_test_rival_plays_fairly_well()
	_test_run_balance()
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


# Every sound the game asks for is there, in the right shape, and not distorted or silent.
func _test_sound_files() -> void:
	for sound_name: String in Sound.SFX_NAMES:
		_check_sound("res://audio/sfx_%s.res" % sound_name, false)
	for jingle_name: String in Sound.JINGLE_NAMES:
		_check_sound("res://audio/jingle_%s.res" % jingle_name, false)
	for track: String in Sound.MUSIC_NAMES:
		_check_sound("res://audio/music_%s.res" % track, true)
	_check_sound("res://audio/ambience.res", true)


func _check_sound(path: String, should_loop: bool) -> void:
	var stream: AudioStreamWAV = load(path)
	_check(stream != null, "%s exists" % path)
	if stream == null:
		return
	_check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, "%s is 16-bit mono" % path)
	var loops: bool = stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check(loops == should_loop, "%s %s" % [path, "loops" if should_loop else "plays once"])
	# Reading stream.data copies the whole sound, so it's only read once.
	var data: PackedByteArray = stream.data
	var frames: int = data.size() / 2
	if loops:
		_check(stream.loop_end == frames, "%s loops over its whole length" % path)
	var peak: int = 0
	for i in frames:
		peak = maxi(peak, absi(data.decode_s16(i * 2)))
	_check(peak > 1000, "%s isn't silent" % path)
	_check(peak < 32767, "%s doesn't clip" % path)


func _test_sound_settings() -> void:
	var path := "user://test_settings.json"
	var real_path: String = Sound.settings_path
	var real_music: int = Sound.music_level
	var real_sfx: int = Sound.sfx_level
	Sound.settings_path = path
	Sound.set_music_level(99)
	_check(Sound.music_level == Sound.LEVELS, "the music level stops at the top")
	Sound.set_sfx_level(-5)
	_check(Sound.sfx_level == 0, "the sound level stops at the bottom")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)), "level zero is really silent")
	Sound.set_music_level(3)
	Sound.set_sfx_level(7)
	Sound.music_level = 0
	Sound.sfx_level = 0
	Sound._load_settings()
	_check(Sound.music_level == 3 and Sound.sfx_level == 7, "the levels are remembered")
	DirAccess.remove_absolute(path)
	Sound.settings_path = real_path
	Sound.music_level = real_music
	Sound.sfx_level = real_sfx
	Sound._apply_levels()


func _test_time_of_day() -> void:
	_check(BackgroundView.mood_for(0, 10, false) == BackgroundView.Mood.MORNING, "the first hole is morning")
	_check(BackgroundView.mood_for(4, 10, false) == BackgroundView.Mood.MIDDAY, "the middle of the course is midday")
	_check(BackgroundView.mood_for(8, 10, false) == BackgroundView.Mood.AFTERNOON, "the back nine is afternoon")
	_check(BackgroundView.mood_for(9, 10, true) == BackgroundView.Mood.DUSK, "the boss hole is dusk")
	_check(BackgroundView.mood_for(0, 1, false) == BackgroundView.Mood.MORNING, "a one-hole course still has a time of day")


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


func _test_full_power() -> void:
	# Letting the bar reach the top is full power.
	var topped := SwingMeter.new()
	topped.press()
	while topped.stage == SwingMeter.Stage.RISING:
		topped.tick(DT)
	_check(topped.full_power and topped.power == 1.0, "reaching the top is full power")
	# A power press just too late doesn't count as the accuracy press.
	topped.press()
	_check(topped.stage == SwingMeter.Stage.RETURNING and not topped.is_done(), "a late power press isn't an accuracy press")
	while topped.cursor > 0.0:
		topped.tick(DT)
	topped.press()
	_check(topped.is_done() and topped.accuracy == 0.0, "the accuracy press still works after that")

	# So does pressing right at the top, and a double tap can't turn it into a miss.
	var pressed := SwingMeter.new()
	pressed.press()
	pressed.cursor = SwingMeter.FULL_POWER_FROM
	pressed.press()
	_check(pressed.full_power and pressed.power == 1.0, "pressing at the top is full power")
	pressed.press()
	_check(not pressed.is_done(), "a double tap at the top does nothing")

	var short := SwingMeter.new()
	short.press()
	short.cursor = 0.8
	short.press()
	_check(not short.full_power, "lower down it isn't full power")

	# It goes further, and says so.
	var driver: ClubData = _club("driver")
	var full: Dictionary = ShotCalc.compute(driver, 1.0, 0.0, 0, 1, 1.0)
	var nearly: Dictionary = ShotCalc.compute(driver, 0.99, 0.0, 0, 1, 1.0)
	_check(full["quality"] == "FULL POWER!!", "a clean full power shot is named")
	_check(Vector2(full["velocity"]).length() > Vector2(nearly["velocity"]).length() * 1.05, "full power is faster than nearly full")
	var far: float = _shot_distance("driver", 1.0, 0.0, 0)
	var less: float = _shot_distance("driver", 0.99, 0.0, 0)
	_check(far > less * 1.05, "and goes further (%.0f, %.0f)" % [far, less])
	_check(ShotCalc.compute(_club("putter"), 1.0, 0.0, 0, 1, 1.0)["quality"] == "", "putts have no full power")
	var putt_full: Vector2 = ShotCalc.compute(_club("putter"), 1.0, 0.0, 0, 1, 1.0)["velocity"]
	_check(is_equal_approx(putt_full.length(), _club("putter").max_speed), "or any extra distance")


func _test_double_tap_guard() -> void:
	Controls.register()
	var press := InputEventAction.new()
	press.action = "swing"
	press.pressed = true
	var first: bool = Controls.swing_pressed(press)
	_check(first, "a swing press counts")
	_check(not Controls.swing_pressed(press), "a second one straight after doesn't")
	var kept_gap: int = Controls.swing_gap_msec
	Controls.swing_gap_msec = 0
	_check(Controls.swing_pressed(press), "once the gap has passed, it counts again")
	Controls.swing_gap_msec = kept_gap
	press.pressed = false
	_check(not Controls.swing_pressed(press), "a release isn't a press")


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
	_check(ShotCalc.compute(driver, 0.9, 0.0, 0, 1, 1.0)["quality"] == "PERFECT!", "perfect is named")
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
	_check(game.facing == -1, "flipping turns the golfer around")
	_check(Vector2(game.preview()["landing"]).x < 500.0 and ahead > 500.0, "the preview follows the flip")
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

	# Putts can flip too.
	var putt := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	putt.select_club(2)
	putt.flip_facing()
	_check(putt.facing == -1, "a putt can flip")


func _test_aim_line_is_for_full_swings() -> void:
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	game.select_club(1)
	_check(game.shows_aim_line(), "swings show an aim line and reach")
	game.select_club(2)
	_check(not game.shows_aim_line(), "putts show no aim line or reach")


func _test_short_shot_return() -> void:
	var times: Array[float] = []
	for power: float in [0.95, 0.5, 0.2]:
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
	# Measured just under the top of the bar, since full power is a bonus on top of this.
	var driver_base: float = _shot_distance("driver", 0.99, 0.0, 0)
	var iron_base: float = _shot_distance("iron", 0.99, 0.0, 0)
	_check(driver_base > 700.0 and driver_base < 950.0, "driver total is in range (%.0f)" % driver_base)
	_check(iron_base > 420.0 and iron_base < 640.0, "iron total is in range (%.0f)" % iron_base)


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


# True if the player can find a safe shot by changing club or flipping.
func _can_get_out(game: HoleGame) -> bool:
	for _side in 2:
		for club_index in game.clubs.size():
			if game.clubs[club_index].is_putter and game.lie_surface() != Surface.Type.GREEN:
				continue
			game.select_club(club_index)
			if _has_safe_shot(game):
				return true
		game.flip_facing()
	return false


# Every spot a ball can sit must offer a shot that stays out of trouble, because water
# returns the ball to the same spot.
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
			if not _can_get_out(game):
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


func _test_putting_is_two_presses() -> void:
	# The meter itself.
	var meter := SwingMeter.new()
	meter.start_sweep()
	_check(meter.stage == SwingMeter.Stage.SWEEPING, "a sweep starts moving")
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
	_check(meter.is_done(), "the press finishes it")
	_check(is_equal_approx(meter.power, maxf(at_press, 0.02)) and meter.accuracy == 0.0, "it takes the power, and no accuracy")

	# In play: on the green, the meter waits for the first press and the second hits the ball.
	var game: HoleGame = _game()
	game.ball.place(1380.0)
	game._begin_aim()
	_check(game.current_club().is_putter, "the putter comes up on the green")
	_check(game.meter.stage == SwingMeter.Stage.IDLE, "its meter waits while aiming")
	for _i in 30:
		game.tick(DT)
	_check(game.meter.cursor == 0.0 and game.phase == HoleGame.Phase.AIM, "and doesn't move until the press")
	game.press_swing()
	_check(game.meter.stage == SwingMeter.Stage.SWEEPING and game.phase == HoleGame.Phase.SWING, "the first press starts the putt's meter")
	_check(game.strokes == 0, "without hitting anything")
	for _i in 30:
		game.tick(DT)
	_check(game.meter.cursor > 0.0, "the meter moves after that")
	var set_power: float = game.meter.cursor
	game.press_swing()
	_check(game.meter.is_done(), "the second press sets the power")
	_check(is_equal_approx(game.meter.power, set_power), "at the cursor's position")
	game.press_swing()
	game.press_swing()
	var guard: int = 0
	while game.phase != HoleGame.Phase.BALL_MOVING and guard < 60:
		game.tick(DT)
		guard += 1
	_check(game.strokes == 1, "a putt is one stroke, even with extra presses (%d)" % game.strokes)
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
	_check(mixed.meter.stage == SwingMeter.Stage.IDLE, "the iron's meter also waits")
	mixed.press_swing()
	_check(mixed.phase == HoleGame.Phase.SWING and mixed.strokes == 0, "the iron's first press starts its meter")
	mixed.press_swing()
	_check(mixed.meter.stage == SwingMeter.Stage.RETURNING, "its second press sets power")
	mixed.press_swing()
	_check(mixed.meter.is_done(), "its third press sets accuracy")

	var switched: HoleGame = _game()
	switched.select_club(2)
	_check(switched.meter.stage == SwingMeter.Stage.IDLE, "picking the putter off the green leaves the meter still")
	switched.press_swing()
	for _i in 20:
		switched.tick(DT)
	switched.press_swing()
	for _i in 20:
		switched.tick(DT)
	_check(switched.strokes == 1, "putting off the green is also two presses")

	# After a putt that doesn't drop, the next one starts the same way.
	var again: HoleGame = _game()
	again.ball.place(1380.0)
	again._begin_aim()
	again.strike_with(0.05, 0.0)
	var settle: int = 0
	while again.phase != HoleGame.Phase.AIM and settle < 3000:
		again.tick(DT)
		settle += 1
	_check(again.meter.stage == SwingMeter.Stage.IDLE, "the next putt waits for its first press")


# Every tree the game makes hides the top of its trunk, whichever pixel things round to.
func _test_leaves_cover_trunks() -> void:
	var holes: Array[HoleData] = []
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		holes.append(run.hole_at(i))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for level: int in [0, 5, 10]:
		holes.append_array(HoleGenerator.generate_set(rng, level))
	for yards: int in IslesGenerator.COURSE_YARDS:
		holes.append(IslesGenerator.generate(rng, yards))
	var checked: int = 0
	var bad: int = 0
	for hole in holes:
		var terrain := Terrain.new(hole)
		var trunks: Array[Dictionary] = []
		for piece: Dictionary in hole.scenery:
			if str(piece["kind"]) == "trunk":
				trunks.append(piece)
		for trunk in trunks:
			var leaves: Dictionary = {}
			for piece: Dictionary in hole.scenery:
				if str(piece["kind"]) == "leaves" and is_equal_approx(float(piece["x"]), float(trunk["x"])):
					leaves = piece
			checked += 1
			if leaves.is_empty() or not TreeView.leaves_cover_trunk(trunk, leaves, terrain):
				bad += 1
	_check(checked > 100, "plenty of trees to look at (%d)" % checked)
	_check(bad == 0, "leaves always hide at least 5 rows of a tree's trunk (%d bad of %d)" % [bad, checked])
	# All the fractional spots and slopes a whole tree can land on.
	var slope := HoleData.new()
	slope.points = PackedVector2Array([Vector2(0, 300), Vector2(400, 260), Vector2(800, 340)])
	var on_slope := Terrain.new(slope)
	var tries: int = 0
	var missed: int = 0
	for variant in HoleIO.LEAF_VARIANTS:
		var x: float = 40.0
		while x < 760.0:
			var pieces: Array = HoleIO.tree_pieces(x, variant)
			tries += 1
			if not TreeView.leaves_cover_trunk(pieces[0], pieces[1], on_slope):
				missed += 1
			x += 37.3
	_check(missed == 0, "and wherever a tree lands on a slope (%d of %d missed)" % [missed, tries])


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
	_check(ids.size() == 20 and ids[0] == "hole_01" and ids[9] == "hole_boss" and ids[19] == "swamp_boss", "the originals are all listed")
	_check(library.course_order() == ids.slice(0, 10), "the course starts as the originals in order")
	_check(library.course_order(HoleData.BIOME_SWAMP) == ids.slice(10, 20), "and so does the swamp")
	var swamp_holes: Array[HoleData] = library.load_course(HoleData.BIOME_SWAMP)
	_check(swamp_holes.size() == 10 and swamp_holes[9].display_name == "BOSS HOLE" and swamp_holes[0].biome == HoleData.BIOME_SWAMP, "the swamp loads as a course of its own")
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


func _test_golfer_never_turns_alone() -> void:
	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		var game := HoleGame.new(hole, _clubs())
		var turned: int = 0
		var x: float = 10.0
		while x < float(game.terrain.length) - 10.0:
			if game.terrain.surface_at(x) != Surface.Type.WATER:
				game.ball.place(x)
				game._begin_aim()
				if game.facing != (1 if hole.cup_x >= x else -1):
					turned += 1
			x += 10.0
		_check(turned == 0, "%s: the golfer always starts facing the cup" % hole.display_name)

	# From the worst spot, where nothing clears the pond, a flip gets the ball out.
	var blocked := HoleGame.new(load("res://data/holes/hole_08.tres") as HoleData, _clubs())
	blocked.ball.place(685.0)
	blocked._begin_aim()
	blocked.flip_facing()
	_check(_has_safe_shot(blocked), "flipping away from a blocked pond gives a safe shot")


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
	_check(sim.pos.x > 310.0, "a rolling ball goes through the door (%.0f)" % sim.pos.x)

	# The door is open up to its top edge, and solid above that, from either side.
	var top: float = mill.ground - WindmillObstacle.DOOR_HEIGHT
	for side: float in [-1.0, 1.0]:
		var through: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 0.0 })
		var through_sim: BallSim = through["sim"]
		through_sim.ignore_moving = true
		_start_ball(through_sim, Vector2(300.0 + side * 20.0, top + 3.0), Vector2(-side * 300.0, 0.0))
		for _i in 16:
			through_sim.step(DT)
		_check(signf(through_sim.pos.x - 300.0) == -side, "a ball at the top of the door passes (%.0f)" % through_sim.pos.x)

		var blocked: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 0.0 })
		var blocked_sim: BallSim = blocked["sim"]
		blocked_sim.ignore_moving = true
		_start_ball(blocked_sim, Vector2(300.0 + side * 20.0, top - 3.0), Vector2(-side * 300.0, 0.0))
		for _i in 16:
			blocked_sim.step(DT)
		_check(signf(blocked_sim.pos.x - 300.0) == side, "a ball just above the door is blocked (%.0f)" % blocked_sim.pos.x)

	# Straight down from above lands on the tower's top, not in the door.
	var above: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "turn_speed": 0.0 })
	var above_sim: BallSim = above["sim"]
	above_sim.ignore_moving = true
	_start_ball(above_sim, Vector2(300.0, top - 15.0), Vector2(0.0, 200.0))
	for _i in 10:
		above_sim.step(DT)
	_check(above_sim.pos.y < top - 1.0, "a ball can't drop through the tower into the door (%.0f)" % above_sim.pos.y)

	# The door tilts with the tower.
	var tilted: Dictionary = _hazard_sim({ "kind": "windmill", "x": 300.0, "rotation": 30.0, "turn_speed": 0.0 })
	var tilted_mill: WindmillObstacle = tilted["obstacle"]
	var tilted_sim: BallSim = tilted["sim"]
	tilted_sim.ignore_moving = true
	var up: Vector2 = Vector2.UP.rotated(deg_to_rad(30.0))
	var across: Vector2 = up.orthogonal()
	var door_mid: Vector2 = tilted_mill.base() + up * (WindmillObstacle.DOOR_HEIGHT - 5.0)
	_start_ball(tilted_sim, door_mid - across * 20.0, across * 300.0)
	for _i in 8:
		tilted_sim.step(DT)
	_check((tilted_sim.pos - door_mid).dot(across) > 0.0, "a ball passes through a tilted door")

	_check(WindmillObstacle.TOWER_HEIGHT - WindmillObstacle.BLADE_LENGTH < BallSim.RADIUS * 2.0, "a blade pointing down reaches a ball on the ground")

	# The same putt gets through or gets knocked back depending on the blades' timing.
	var passed: int = 0
	var knocked: int = 0
	var stuck: int = 0
	for i in 24:
		var course_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
		course_hole.obstacles = [{ "kind": "windmill", "x": 400.0, "turn_speed": 1.2 }]
		var timed := HoleGame.new(course_hole, _clubs())
		timed.ball.place(340.0)
		timed._begin_aim()
		timed.obstacles[0].angle = float(i) / 24.0 * PI / 2.0
		timed.select_club(2)
		timed.strike_with(1.0, 0.0)
		var rolled: int = 0
		while timed.phase != HoleGame.Phase.AIM and rolled < 3000:
			timed.tick(DT)
			rolled += 1
		if timed.phase != HoleGame.Phase.AIM:
			stuck += 1
		elif timed.ball.pos.x > 410.0:
			passed += 1
		else:
			knocked += 1
	_check(stuck == 0, "turning blades never trap a ball")
	_check(passed > 0 and knocked > 0, "getting through the door takes timing (%d through, %d knocked back)" % [passed, knocked])

	# A ball that stops in the doorway can play out, when the blades are clear of it.
	var door_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	door_hole.obstacles = [{ "kind": "windmill", "x": 400.0, "turn_speed": 0.0 }]
	var in_door := HoleGame.new(door_hole, _clubs())
	in_door.obstacles[0].angle = PI / 4.0
	in_door.ball.place(400.0)
	in_door._begin_aim()
	in_door.select_club(2)
	in_door.strike_with(1.0, 0.0)
	var escaping: int = 0
	while in_door.phase != HoleGame.Phase.AIM and escaping < 3000:
		in_door.tick(DT)
		escaping += 1
	_check(in_door.ball.pos.x > 410.0, "a ball resting in the door can play out (%.0f)" % in_door.ball.pos.x)

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
	preview_sim.pos = Vector2(290.0, preview_mill.ground - 30.0)
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


func _new_run_state(unlocked: Array[String] = [], p_seed: int = 1) -> RunState:
	var course := CourseRun.new(load(COURSE_PATH) as CourseData)
	return RunState.new(course, _clubs(), unlocked, p_seed)


func _test_stroke_budget() -> void:
	var state: RunState = _new_run_state()
	_check(state.spare == 8, "a run starts with 8 spare strokes")
	var par: int = state.course.current_hole().par
	_check(state.live_spare(par, par) == 8, "strokes up to par don't touch the budget")
	_check(state.live_spare(par + 3, par) == 5, "strokes over par drain it as they're taken")
	_check(state.stroke_limit(par) == par + 8, "the limit is par plus the spare strokes")
	var summary: Dictionary = state.finish_hole(par - 1)
	_check(state.spare == 9 and int(summary["banked"]) == 1, "beating par banks strokes")
	state.course.advance()
	par = state.course.current_hole().par
	state.finish_hole(par + 3)
	_check(state.spare == 6, "a bad hole drains them")
	state.course.advance()
	par = state.course.current_hole().par
	state.leave_hole_unfinished(par + 2)
	_check(state.spare == 4, "an unfinished hole settles the budget")
	_check(not state.course.scores.has(state.course.hole_index), "an unfinished hole isn't on the card")


func _test_budget_in_play() -> void:
	# Ends as the ball stops, not when it's struck.
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	game.stroke_limit = 2
	var endings: Array[bool] = []
	game.out_of_strokes.connect(func() -> void: endings.append(true))
	game.select_club(1)
	game.strike_with(0.2, 0.0)
	_finish_shot(game)
	_check(endings.is_empty() and game.phase == HoleGame.Phase.AIM, "strokes left means play carries on")
	game.select_club(1)
	game.strike_with(0.2, 0.0)
	_check(game.phase == HoleGame.Phase.BALL_MOVING, "the last stroke still plays out")
	_finish_shot(game)
	_check(endings.size() == 1 and game.phase == HoleGame.Phase.OUT_OF_STROKES, "running out ends the hole as the ball stops")
	game.grant_strokes(2)
	_check(game.phase == HoleGame.Phase.AIM and game.stroke_limit == 4, "strokes given back resume play")

	# A penalty can use up the last stroke.
	var water := HoleGame.new(_game().hole, _clubs())
	water.stroke_limit = 2
	var wet_endings: Array[bool] = []
	water.out_of_strokes.connect(func() -> void: wet_endings.append(true))
	water.strokes = 1
	water._on_ball_hazard(Vector2.ZERO, "water")
	_check(water.strokes == 2 and wet_endings.is_empty(), "a penalty stroke doesn't end things until the ball returns")
	_finish_shot(water)
	_check(wet_endings.size() == 1, "a penalty that uses the last stroke ends the run")

	# Sinking the last stroke saves the run.
	var cup_x: float = 300.0
	var saved := HoleGame.new(_flat_hole({ "cup_x": cup_x }), _clubs())
	saved.stroke_limit = 1
	var saved_endings: Array[bool] = []
	saved.out_of_strokes.connect(func() -> void: saved_endings.append(true))
	saved.ball.place(cup_x - 40.0)
	saved._begin_aim()
	saved.select_club(2)
	saved.strokes = 0
	saved.strike_with(0.5, 0.0)
	_finish_shot(saved)
	if saved.phase == HoleGame.Phase.COMPLETE:
		_check(saved_endings.is_empty(), "sinking the last stroke isn't running out")
	else:
		_check(saved_endings.size() == 1, "missing the last stroke is running out")


func _finish_shot(game: HoleGame) -> void:
	var steps: int = 0
	while steps < 5000:
		if game.phase == HoleGame.Phase.AIM or game.phase == HoleGame.Phase.COMPLETE or game.phase == HoleGame.Phase.OUT_OF_STROKES:
			return
		game.tick(DT)
		steps += 1


func _test_coins_and_payouts() -> void:
	var state: RunState = _new_run_state()
	_check(state.coins == 0, "a run starts with no coins")
	for hole_index in 3:
		_check(state.hole_payout(hole_index, 4, 4) == 3, "hole %d pays 3" % (hole_index + 1))
	for hole_index in range(3, 10):
		_check(state.hole_payout(hole_index, 4, 4) == 5, "hole %d pays 5" % (hole_index + 1))
	for strokes: int in [1, 3, 4, 5, 12]:
		_check(state.hole_payout(0, strokes, 4) == 3, "the score doesn't change the pay (%d strokes)" % strokes)
	state.begin_hole()
	state.collect_coin()
	_check(state.collect_trick(6) == 0, "a trick shot pays nothing without the Showman")
	var summary: Dictionary = state.finish_hole(state.course.current_hole().par - 2)
	_check(state.coins == 1 + 3, "coins only come from the hole and pickups")
	_check(int(summary["pickups"]) == 1 and int(summary["tricks"]) == 0 and int(summary["payout"]) == 3, "the summary shows where they came from")
	state.spare = 0
	state.course.advance()
	state.begin_hole()
	var coins_before: int = state.coins
	state.leave_hole_unfinished(state.course.current_hole().par)
	_check(state.coins == coins_before, "an unfinished hole pays nothing")


func _test_coin_pickups() -> void:
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	var coin_x: float = 200.0
	hole.obstacles = [{ "kind": "coin", "x": coin_x, "y": 296.0 }]
	var game := HoleGame.new(hole, _clubs())
	var picked: Array[Vector2] = []
	game.coin_collected.connect(func(at: Vector2) -> void: picked.append(at))
	game.select_club(2)
	game.strike_with(1.0, 0.0)
	_finish_shot(game)
	_check(picked.size() == 1, "a rolling ball picks up a coin in its path")
	_check(game.ball.pos.x > coin_x + 40.0, "a coin doesn't slow the ball or knock it about (%.0f)" % game.ball.pos.x)
	var coin: CoinObstacle = game.obstacles[0]
	_check(coin.collected, "a picked-up coin is gone")
	game.ball.place(coin_x - 30.0)
	game._begin_aim()
	game.select_club(2)
	game.strike_with(0.5, 0.0)
	_finish_shot(game)
	_check(picked.size() == 1, "a coin only pays once")
	game.restart()
	_check(not coin.collected, "restarting a test puts coins back")

	var preview_only := HoleGame.new(hole, _clubs())
	preview_only.select_club(2)
	preview_only.preview()
	_check(not (preview_only.obstacles[0] as CoinObstacle).collected, "the aim preview doesn't pick up coins")

	var run := CourseRun.new(load(COURSE_PATH) as CourseData)
	for i in run.hole_count():
		var hole_data: HoleData = run.hole_at(i)
		var terrain := Terrain.new(hole_data)
		var coins: int = 0
		var buried: int = 0
		for entry: Dictionary in hole_data.obstacles:
			if str(entry["kind"]) == "coin":
				coins += 1
				if float(entry["y"]) >= terrain.ground_y(float(entry["x"])):
					buried += 1
		_check(coins >= 5, "%s has coins to find (%d)" % [hole_data.display_name, coins])
		_check(buried == 0, "%s has no coins underground" % hole_data.display_name)


func _test_trick_shots() -> void:
	# Each is the finish of a shot, set up directly, so only the choice of trick is tested.
	var cases: Array = [
		[1, false, false, false, "HOLE IN ONE!", 0.0],
		[3, true, false, false, "BANK SHOT!", 0.0],
		[3, false, false, false, "CHIP-IN!", 0.0],
		[3, false, true, true, "LONG PUTT!", 200.0],
		[3, false, true, true, "", 40.0],
	]
	for case: Array in cases:
		var game := HoleGame.new(_flat_hole({ "cup_x": 500.0 }), _clubs())
		var names: Array[String] = []
		game.trick_shot.connect(func(trick: String, _coins: int) -> void: names.append(trick))
		game.strokes = int(case[0])
		game._shot_hit_pad = bool(case[1])
		game._shot_by_putter = bool(case[2])
		game._shot_from_green = bool(case[3])
		game._shot_from_x = 500.0 - float(case[5])
		game._pay_for_trick_finish()
		var wanted: String = str(case[4])
		_check(names == ([wanted] if wanted != "" else []), "a finish pays the right trick: '%s' (%s)" % [wanted, str(names)])

	var pin_game := HoleGame.new(_flat_hole({ "cup_x": 500.0 }), _clubs())
	var pin_names: Array[String] = []
	pin_game.trick_shot.connect(func(trick: String, _coins: int) -> void: pin_names.append(trick))
	pin_game.strokes = 2
	pin_game._shot_by_putter = true
	pin_game._shot_from_green = true
	pin_game._shot_from_x = 480.0
	pin_game._on_pin_hit(Vector2.ZERO)
	pin_game._pay_for_trick_finish()
	_check(pin_names == ["OFF THE PIN!"], "a ball off the pin pays")

	# Rolling through a windmill's door pays once a shot, and only if it really went through.
	var hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	hole.obstacles = [{ "kind": "windmill", "x": 400.0, "turn_speed": 0.0 }]
	var through := HoleGame.new(hole, _clubs())
	through.obstacles[0].angle = PI / 4.0
	var door_tricks: Array[String] = []
	through.trick_shot.connect(func(trick: String, _coins: int) -> void: door_tricks.append(trick))
	through.ball.place(340.0)
	through._begin_aim()
	through.select_club(2)
	through.strike_with(1.0, 0.0)
	_finish_shot(through)
	_check(through.ball.pos.x > 410.0 and door_tricks == ["THROUGH THE MILL!"], "rolling through the door pays (%s)" % str(door_tricks))

	var short := HoleGame.new(hole, _clubs())
	short.obstacles[0].angle = PI / 4.0
	var short_tricks: Array[String] = []
	short.trick_shot.connect(func(trick: String, _coins: int) -> void: short_tricks.append(trick))
	short.ball.place(340.0)
	short._begin_aim()
	short.select_club(2)
	short.strike_with(0.05, 0.0)
	_finish_shot(short)
	_check(short_tricks.is_empty(), "stopping short of the door pays nothing")

	var preview_game := HoleGame.new(hole, _clubs())
	preview_game.obstacles[0].angle = PI / 4.0
	var preview_tricks: Array[String] = []
	preview_game.trick_shot.connect(func(trick: String, _coins: int) -> void: preview_tricks.append(trick))
	preview_game.ball.place(340.0)
	preview_game._begin_aim()
	preview_game.select_club(2)
	preview_game.preview()
	_check(preview_tricks.is_empty(), "the aim preview can't earn a trick")


func _club_named(clubs: Array[ClubData], id: String) -> ClubData:
	for club in clubs:
		if club.id == id:
			return club
	return null


func _test_stickers() -> void:
	var base: ClubData = _club("iron")
	var original_speed: float = base.max_speed
	var striped: ClubData = Items.club_with_stickers(base, ["power_stripe"])
	_check(striped.max_speed > original_speed, "Power Stripe adds speed")
	_check(base.max_speed == original_speed, "stickers never change the original club")
	var range_gain: float = pow(striped.max_speed / original_speed, 2.0)
	_check(absf(range_gain - 1.08) < 0.01, "Power Stripe adds about 8%% range (%.3f)" % range_gain)
	_check(Items.club_with_stickers(base, ["spin_doctor"]).spin_strength == base.spin_strength * 1.5, "Spin Doctor adds spin")
	_check(Items.club_with_stickers(base, ["rough_rider"]).lie_sensitivity == base.lie_sensitivity * 0.5, "Rough Rider halves the lie penalty")
	var wide: ClubData = Items.club_with_stickers(base, ["wide_angle"])
	_check(wide.min_angle_deg == base.min_angle_deg - 10.0 and wide.max_angle_deg == base.max_angle_deg + 10.0, "Wide Angle widens both ends")
	var two: ClubData = Items.club_with_stickers(base, ["wide_angle", "wide_angle", "wide_angle"])
	_check(two.max_angle_deg <= HoleGame.MAX_LAUNCH_ANGLE and two.min_angle_deg >= HoleGame.MIN_LAUNCH_ANGLE, "angle stickers stay within the game's limits")
	_check(absf(Items.club_with_stickers(base, ["power_stripe", "power_stripe"]).max_speed - original_speed * 1.08) < 0.01, "matching stickers add their bonuses")
	_check(is_equal_approx(Items.club_with_stickers(base, ["spin_doctor", "spin_doctor", "spin_doctor"]).spin_strength, base.spin_strength * 2.5), "three +50% stickers make +150%")
	_check(is_equal_approx(Items.club_with_stickers(base, ["rough_rider", "rough_rider"]).lie_sensitivity, base.lie_sensitivity * 0.25), "a reduction applies again to what's left")
	_check(Items.club_with_stickers(base, ["forgiver", "forgiver", "forgiver"]).miss_scale > 0.0, "three reductions never pass 100%")
	var three_wide: ClubData = Items.club_with_stickers(base, ["wide_angle", "wide_angle", "wide_angle"])
	_check(is_equal_approx(three_wide.max_angle_deg, minf(base.max_angle_deg + 30.0, HoleGame.MAX_LAUNCH_ANGLE)), "three Wide Angles give 30 degrees")
	_check(is_equal_approx(three_wide.min_angle_deg, maxf(base.min_angle_deg - 30.0, HoleGame.MIN_LAUNCH_ANGLE)), "both ways")

	# They reach the actual shot.
	var plain_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	var plain := HoleGame.new(plain_hole, _clubs() as Array[ClubData])
	plain.select_club(1)
	var plain_speed: float = Vector2(plain.shot_for(1.0, 0.0)["velocity"]).length()
	var clubs: Array[ClubData] = []
	for club in _clubs():
		clubs.append(Items.club_with_stickers(club, ["power_stripe", "sweet_tape", "steady_hand", "forgiver"]))
	var stickered := HoleGame.new(plain_hole, clubs)
	stickered.select_club(1)
	_check(Vector2(stickered.shot_for(1.0, 0.0)["velocity"]).length() > plain_speed, "a sticker changes the shot")
	_check(stickered.meter.perfect_window > plain.meter.perfect_window, "Sweet Tape widens the meter's sweet spot")
	_check(stickered.meter.time_scale < 1.0, "Steady Hand slows the meter")
	var miss_plain: Dictionary = plain.shot_for(1.0, 0.8)
	var miss_kind: Dictionary = stickered.shot_for(1.0, 0.8)
	_check(Vector2(miss_kind["velocity"]).length() > Vector2(miss_plain["velocity"]).length(), "Forgiver softens a miss")

	var meter := SwingMeter.new()
	meter.time_scale = 0.5
	meter.press()
	meter.tick(0.2)
	_check(absf(meter.cursor - 0.1 / SwingMeter.RISE_TIME) < 0.001, "the meter's speed follows its time scale")
	meter.reset()
	_check(meter.time_scale == 0.5, "a meter reset keeps its speed")


# Each one really hits 15% farther and runs the meter 20% faster, measured from the shot itself.
func _test_overdrive() -> void:
	var item: Dictionary = Items.by_id("overdrive")
	_check(not item.is_empty() and not item.has("unlock"), "Overdrive is on sale from the start")
	_check(item["clubs"] == Items.SWING_CLUBS, "it fits the Driver and Iron only")
	for club_id: String in ["driver", "iron"]:
		var plain: float = _flat_carry(_club(club_id))
		for count: int in [1, 2, 3]:
			var ids: Array = []
			ids.resize(count)
			ids.fill("overdrive")
			var club: ClubData = Items.club_with_stickers(_club(club_id), ids)
			var gain: float = _flat_carry(club) / plain
			_check(absf(gain - (1.0 + 0.15 * float(count))) < 0.02, "%d on the %s carries %.0f%% farther (%.3f)" % [count, club_id, 15.0 * float(count), gain])
			_check(is_equal_approx(club.meter_speed, 1.0 + 0.2 * float(count)), "and runs the meter %.0f%% faster" % (20.0 * float(count)))
	var state: RunState = _new_run_state()
	state.coins = 100
	var slot_count: int = 0
	for _i in RunState.MAX_STACK:
		_check(state.buy_sticker(item, "iron"), "it can be stacked")
		slot_count = state.sticker_slots("iron").size()
	_check(slot_count == 1 and not state.buy_sticker(item, "iron"), "up to 3 in one slot")
	var hole: HoleData = _flat_hole({ "cup_x": 3000.0 })
	var game := HoleGame.new(hole, state.clubs())
	game.select_club(1)
	_check(is_equal_approx(game.meter.time_scale, 1.6), "the game's meter gets the speed")


# How far a full-power, flush shot flies before its first bounce on level ground.
func _flat_carry(club: ClubData) -> float:
	var hole: HoleData = _flat_hole({ "cup_x": 7000.0 })
	var terrain := Terrain.new(hole)
	var sim := BallSim.new(terrain)
	sim.place(100.0)
	var shot: Dictionary = ShotCalc.compute(club, 0.99, 0.0, 0, 1, 1.0, club.loft_deg)
	sim.launch(shot["velocity"], float(shot["spin"]))
	var steps: int = 0
	while sim.is_moving() and sim.bounce_count == 0 and steps < 6000:
		sim.step(1.0 / 240.0)
		steps += 1
	return sim.pos.x - 100.0


func _test_shop_reroll() -> void:
	var state: RunState = _new_run_state()
	state.coins = 100
	state.begin_shop()
	var stock: Array[Dictionary] = state.roll_stock()
	var expected_coins: int = 100
	for price: int in [3, 6, 12, 24]:
		_check(state.reroll_price() == price, "the reroll costs %d" % price)
		var before: Array[Dictionary] = stock
		stock = state.reroll_stock(stock)
		expected_coins -= price
		_check(state.coins == expected_coins, "and that's what's paid")
		_check(stock.size() == RunState.SHOP_SHELVES, "every shelf is filled again")
		var repeats: int = 0
		for item in stock:
			if before.has(item):
				repeats += 1
		_check(repeats == 0, "with all new items while there are others to show")
	state.begin_shop()
	_check(state.reroll_price() == 3, "the next shop goes back to 3")
	state.perks.append("coupon")
	state.level = Difficulty.MAX_LEVEL
	_check(state.reroll_price() == 3, "discounts and difficulty don't change it")
	state.coins = 2
	var kept: Array[Dictionary] = state.reroll_stock(stock)
	_check(kept.is_empty() and state.coins == 2 and state.shop_rerolls == 0, "too few coins means no reroll and no charge")

	# The screen: everything's for sale again, including what was bought.
	var run_state: RunState = _new_run_state()
	run_state.coins = 50
	var screen := ShopScreen.new()
	screen.setup(run_state)
	screen.sold[0] = true
	screen.cursor = screen.stock.size() + 1
	screen._confirm()
	_check(screen.sold.is_empty(), "a reroll restocks sold shelves")
	_check(run_state.coins == 47 and run_state.reroll_price() == 6, "and the button charges and doubles")
	_check(screen.cursor == screen.stock.size() + 1, "the selection stays on it")
	var next_screen := ShopScreen.new()
	next_screen.setup(run_state)
	_check(run_state.reroll_price() == 3, "a new shop screen resets the price")
	screen.free()
	next_screen.free()


func _test_special_balls() -> void:
	# Lands the same shot with each ball, to see what it changes.
	var plain_x: float = _landing_with_ball("")
	var sticky_x: float = _landing_with_ball("sticky_ball")
	var rubber_x: float = _landing_with_ball("rubber_ball")
	_check(sticky_x < plain_x - 5.0, "a sticky ball runs out less (%.0f, %.0f)" % [sticky_x, plain_x])
	_check(rubber_x > plain_x + 5.0, "a rubber ball runs out more (%.0f, %.0f)" % [rubber_x, plain_x])

	# A sticky ball all but stops where it first lands, and still putts normally.
	var run_outs: Dictionary = {}
	for ball_id: String in ["", "sticky_ball"]:
		var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs(), ball_id)
		game.select_club(1)
		game.strike_with(0.6, 0.0)
		var first_landing: Array[float] = []
		game.ball.bounced.connect(func(at: Vector2, _surface: int, _speed: float) -> void:
			if first_landing.is_empty():
				first_landing.append(at.x))
		_finish_shot(game)
		run_outs[ball_id] = game.ball.pos.x - first_landing[0]
	print("run out after landing: plain %.0f px, sticky %.0f px" % [run_outs[""], run_outs["sticky_ball"]])
	_check(float(run_outs["sticky_ball"]) < 12.0, "a sticky ball stops almost where it lands (%.0f)" % run_outs["sticky_ball"])
	var putts: Dictionary = {}
	for ball_id: String in ["", "sticky_ball"]:
		var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs(), ball_id)
		game.select_club(2)
		game.strike_with(0.5, 0.0)
		_finish_shot(game)
		putts[ball_id] = game.ball.pos.x
	_check(is_equal_approx(float(putts[""]), float(putts["sticky_ball"])), "a sticky ball putts like any other")

	var windy: HoleData = _flat_hole({ "cup_x": 990.0 })
	windy.wind = 40.0
	_check(is_equal_approx(HoleGame.new(windy, _clubs(), "wind_cutter").current_wind(), 12.0), "a Wind Cutter takes 30% of the wind")

	# A skipper crosses water that a plain ball drowns in.
	var pond: HoleData = _flat_hole({ "cup_x": 990.0 })
	pond.points = PackedVector2Array([Vector2(0, 300), Vector2(400, 300), Vector2(420, 330), Vector2(560, 330), Vector2(580, 300), Vector2(1000, 300)])
	pond.water_spans = [{ "from": 405, "to": 575, "level": 306.0 }]
	var results: Dictionary = {}
	for ball_id: String in ["", "skipper"]:
		var game := HoleGame.new(pond, _clubs(), ball_id)
		var sim: BallSim = game.ball
		sim.pos = Vector2(430.0, 250.0)
		sim.launch(Vector2(120.0, 30.0), 0.0)
		var steps: int = 0
		var splashes: Array[bool] = []
		sim.hazard.connect(func(_at: Vector2, _kind: String) -> void: splashes.append(true))
		while sim.is_moving() and steps < 2000 and splashes.is_empty():
			sim.step(DT)
			steps += 1
		results[ball_id] = sim.pos.x
	_check(float(results["skipper"]) > float(results[""]) + 20.0, "a skipper bounces off water (%.0f, %.0f)" % [results["skipper"], results[""]])

	# The aim preview uses the ball in play.
	var plain := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	var rubbery := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs(), "rubber_ball")
	_check(plain.new_preview_sim().bounce_scale == 1.0 and rubbery.new_preview_sim().bounce_scale == rubbery.ball.bounce_scale, "the preview matches the ball in play")
	_check(rubbery.ball.bounce_scale > 1.0, "a rubber ball is bouncier")

	# Dropped from the same height, a rubber ball rebounds higher and keeps going for longer.
	var drops: Dictionary = {}
	for ball_id: String in ["", "rubber_ball"]:
		var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs(), ball_id)
		var sim: BallSim = game.ball
		sim.pos = Vector2(300.0, 150.0)
		sim.launch(Vector2(40.0, 1.0), 0.0)
		var first_bounce_y: float = INF
		var highest_after: float = INF
		var steps: int = 0
		while sim.is_moving() and steps < 3000:
			sim.step(DT)
			steps += 1
			if sim.bounce_count >= 1:
				if first_bounce_y == INF:
					first_bounce_y = sim.pos.y
				highest_after = minf(highest_after, sim.pos.y)
		_check(not sim.is_moving(), "a dropped ball settles (%s)" % ball_id)
		drops[ball_id] = { "bounces": sim.bounce_count, "rebound": first_bounce_y - highest_after }
	var plain_drop: Dictionary = drops[""]
	var rubber_drop: Dictionary = drops["rubber_ball"]
	_check(float(rubber_drop["rebound"]) > float(plain_drop["rebound"]) * 3.0, "a rubber ball rebounds much higher (%.0f, %.0f)" % [rubber_drop["rebound"], plain_drop["rebound"]])
	_check(int(rubber_drop["bounces"]) >= int(plain_drop["bounces"]) + 3, "a rubber ball bounces more times (%d, %d)" % [rubber_drop["bounces"], plain_drop["bounces"]])
	print("Rubber drop: %s, plain drop: %s, landing x %.0f against %.0f" % [rubber_drop, plain_drop, rubber_x, plain_x])

	# Hazards knock a heavy ball less.
	var heavy_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	heavy_hole.obstacles = [{ "kind": "windmill", "x": 400.0, "turn_speed": 0.0 }]
	var rebounds: Dictionary = {}
	for ball_id: String in ["", "heavy_ball"]:
		var game := HoleGame.new(heavy_hole, _clubs(), ball_id)
		game.ball.ignore_moving = true
		game.ball.pos = Vector2(380.0, 270.0)
		game.ball.launch(Vector2(200.0, -1.0), 0.0)
		for _i in 10:
			game.ball.step(DT)
		rebounds[ball_id] = game.ball.vel.x
	_check(float(rebounds["heavy_ball"]) > float(rebounds[""]), "a heavy ball rebounds less (%.0f, %.0f)" % [rebounds["heavy_ball"], rebounds[""]])


func _landing_with_ball(ball_id: String) -> float:
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs(), ball_id)
	game.select_club(1)
	game.strike_with(0.6, 0.0)
	_finish_shot(game)
	return game.ball.pos.x


func _test_shop_stock() -> void:
	var state: RunState = _new_run_state()
	var kinds_seen: Dictionary = {}
	var ids_seen: Dictionary = {}
	for _round in 200:
		var stock: Array[Dictionary] = state.roll_stock()
		_check(stock.size() == RunState.SHOP_SHELVES, "the shop has %d shelves" % RunState.SHOP_SHELVES)
		_check(stock[0]["kind"] == Items.KIND_STICKER and stock[1]["kind"] == Items.KIND_STICKER, "the first two shelves are stickers")
		_check(stock[2]["kind"] != Items.KIND_STICKER, "the third shelf is never a sticker")
		var unique: Dictionary = {}
		for item in stock:
			unique[item["id"]] = true
			kinds_seen[item["kind"]] = true
			ids_seen[item["id"]] = true
			_check(not item.has("unlock"), "locked items aren't sold")
		_check(unique.size() == stock.size(), "no item is on two shelves")
	for kind: String in [Items.KIND_STICKER, Items.KIND_BALL, Items.KIND_PERK, Items.KIND_STROKES]:
		_check(kinds_seen.has(kind), "the stock includes %s" % kind)

	# Runs with the same seed get the same stock, and ones with different seeds don't.
	var a: Array[Dictionary] = _new_run_state([], 5).roll_stock()
	_check(a == _new_run_state([], 5).roll_stock(), "the same seed rolls the same stock")
	var differs: bool = false
	for seed_value in range(6, 16):
		if _new_run_state([], seed_value).roll_stock() != a:
			differs = true
	_check(differs, "different runs get different stock")

	# Unlocks reach the shop.
	var unlocked: Array[String] = Items.unlock_order()
	var open_state: RunState = _new_run_state(unlocked)
	var saw_unlock: bool = false
	for _round in 200:
		for item in open_state.roll_stock():
			if item.has("unlock"):
				saw_unlock = true
	_check(saw_unlock, "unlocked items appear in the shop")

	# It doesn't sell what you already have.
	var owner: RunState = _new_run_state()
	owner.ball_id = "skipper"
	owner.perks.append("coupon")
	for _round in 200:
		for item in owner.roll_stock():
			_check(item["id"] != "skipper" and item["id"] != "coupon", "the shop doesn't sell what you've got")


func _test_prices_climb() -> void:
	var state: RunState = _new_run_state()
	for item: Dictionary in Items.CATALOG:
		# Some items are the same price throughout, and are checked on their own.
		if item.get("fixed_price", false):
			continue
		state.course.hole_index = 0
		var label: String = str(item["name"])
		_check(state.price_of(item) == 3, "%s costs 3 in the first shop" % label)
		var last_price: int = 3
		for shop_index in range(1, state.course.hole_count() - 1):
			state.course.hole_index = shop_index
			var price: int = state.price_of(item)
			_check(price >= last_price, "%s never gets cheaper (%d, %d)" % [label, last_price, price])
			last_price = price
		_check(last_price == int(item["price"]), "%s reaches its full price by the last shop" % label)
	# A very short custom course still works.
	var holes: Array[HoleData] = [_flat_hole(), _flat_hole()]
	var short := RunState.new(CourseRun.from_holes(holes), _clubs())
	_check(short.price_of(Items.by_id("skipper")) == 3, "a two-hole course's only shop is at the starting price")

	# What a hole earned, in words that can't be taken for points.
	_check(RunState.coins_text({ "payout": 3, "pickups": 0, "tricks": 0 }) == "+3 COINS: 3 FOR HOLE", "only sources that paid are named")
	_check(RunState.coins_text({ "payout": 5, "pickups": 3, "tricks": 4 }) == "+12 COINS: 5 FOR HOLE, 3 PICKED UP, 4 TRICKS", "every source is named")
	_check(RunState.coins_text({ "payout": 13, "ace": 8, "pickups": 16, "tricks": 15 }).length() <= 55, "the longest line fits the panel")

	# A hole in one pays 8 more, with no perks, and only on the first stroke.
	var ace_run: RunState = _new_run_state()
	var ace: Dictionary = ace_run.finish_hole(1)
	_check(int(ace["ace"]) == 8 and ace_run.coins == 11, "a hole in one pays 8 on top of the hole's 3 (%d)" % ace_run.coins)
	var two_run: RunState = _new_run_state()
	var two: Dictionary = two_run.finish_hole(2)
	_check(int(two["ace"]) == 0 and two_run.coins == 3, "two strokes pays no bonus")
	_check(CourseRun.to_par_text(0) == "0", "even par shows as 0")

	# Coins left really do reach the final score: 7 on hole 1 with 3 pickups leaves 6 coins.
	var run: RunState = _new_run_state()
	run.begin_hole()
	for _i in 3:
		run.collect_coin()
	run.finish_hole(7)
	run.ending = RunState.Ending.GAVE_UP
	_check(_score_row(run, "COINS LEFT") == 12, "6 coins left are worth 12 points")
	_check(int(run.final_score()["total"]) == 62, "that run scores 62")


func _test_buying() -> void:
	var state: RunState = _new_run_state()
	var ball: Dictionary = Items.by_id("skipper")
	_check(not state.buy(ball), "no coins, no sale")
	state.coins = 100
	var ball_price: int = state.price_of(ball)
	_check(state.buy(ball) and state.ball_id == "skipper", "buying a ball equips it")
	_check(state.coins == 100 - ball_price, "buying costs its price")
	state.buy(Items.by_id("wind_cutter"))
	_check(state.ball_id == "wind_cutter", "a new ball goes straight into play")
	_check(state.balls == ["", "skipper", "wind_cutter"], "and joins the plain ball and the first one")
	state.equip_ball(1)
	_check(state.ball_id == "skipper", "you can swap to a ball you're carrying")
	state.equip_ball(0)
	_check(state.ball_id == "", "including the plain ball")
	state.equip_ball(7)
	_check(state.ball_id == "", "an empty slot changes nothing")
	var sticky: Dictionary = Items.by_id("sticky_ball")
	var coins_held: int = state.coins
	_check(not state.buy(sticky), "a fourth ball needs a slot to replace")
	_check(state.coins == coins_held and state.balls.size() == 3, "and costs nothing until it has one")
	_check(state.buy(sticky, 1) and state.balls == ["", "sticky_ball", "wind_cutter"], "it replaces the chosen ball")
	_check(state.ball_id == "sticky_ball", "and goes into play")
	for _round in 100:
		for item in state.roll_stock():
			_check(item["id"] != "sticky_ball" and item["id"] != "wind_cutter", "the shop doesn't sell a ball you carry")
	var strokes_before: int = state.spare
	state.buy(Items.by_id("spare_strokes"))
	_check(state.spare == strokes_before + 2, "bonus strokes go on the budget")
	state.buy(Items.by_id("coupon"))
	_check(state.perks.has("coupon"), "buying a perk keeps it")

	var fresh: RunState = _new_run_state()
	fresh.coins = 500
	var sticker: Dictionary = Items.by_id("power_stripe")
	_check(not fresh.buy(sticker), "stickers need a club")
	_check(not fresh.buy_sticker(sticker, "putter"), "a sticker won't go on a club it doesn't fit")
	var coins_before: int = fresh.coins
	_check(fresh.coins == coins_before, "a refused sticker costs nothing")
	# Matching stickers stack in one slot, up to three.
	for i in RunState.MAX_STACK:
		_check(not fresh.club_is_full("iron"), "a stack only takes one slot (%d)" % i)
		_check(fresh.buy_sticker(sticker, "iron"), "a sticker stacks on its match (%d)" % i)
	_check(fresh.sticker_slots("iron") == [{ "id": "power_stripe", "count": RunState.MAX_STACK }], "three of a sticker is one slot of three")
	_check(fresh.stack_is_complete("iron", sticker), "the stack is then complete")
	var before_fourth: int = fresh.coins
	_check(not fresh.buy_sticker(sticker, "iron"), "a fourth won't go on")
	_check(fresh.coins == before_fourth, "and costs nothing")
	_check(fresh.buy_sticker(Items.by_id("spin_doctor"), "iron"), "another kind takes the next slot")
	_check(fresh.buy_sticker(Items.by_id("wide_angle"), "iron"), "and another the last")
	_check(fresh.club_is_full("iron"), "three kinds fill a club")
	_check(fresh.buy_sticker(Items.by_id("wide_angle"), "iron"), "a full club still stacks on a match")
	_check(fresh.sticker_count("iron", Items.by_id("wide_angle")) == 2, "making two")
	_check(not fresh.must_replace_for("iron", Items.by_id("spin_doctor")), "a match never needs a replacement")
	_check(fresh.must_replace_for("iron", Items.by_id("sweet_tape")), "a new kind on a full club does")
	var before_replace: int = fresh.coins
	_check(not fresh.buy_sticker(Items.by_id("sweet_tape"), "iron"), "a full club needs one chosen to replace")
	_check(fresh.coins == before_replace, "no replacement chosen, no charge")
	_check(fresh.buy_sticker(Items.by_id("sweet_tape"), "iron", 2), "a new sticker can replace a chosen one")
	_check(fresh.stickers["iron"] == ["power_stripe", "power_stripe", "power_stripe", "spin_doctor", "sweet_tape"], "the whole chosen stack is lost, and only it")
	_check(fresh.buy_sticker(Items.by_id("spin_doctor"), "iron"), "stacking still works after replacing")
	_check(fresh.stickers["iron"] == ["power_stripe", "power_stripe", "power_stripe", "spin_doctor", "spin_doctor", "sweet_tape"], "and a stack stays together")
	_check(fresh.stickers["driver"].is_empty(), "stickers stay on their own club")
	fresh.stickers["iron"] = ["power_stripe", "sweet_tape"]
	var clubs: Array[ClubData] = fresh.clubs()
	var iron: ClubData = _club_named(clubs, "iron")
	_check(iron.max_speed > _club("iron").max_speed and iron.window_scale > 1.0, "the bag plays with its stickers")
	_check(_club_named(clubs, "driver").max_speed == _club("driver").max_speed, "other clubs stay plain")


func _test_perks() -> void:
	var state: RunState = _new_run_state()
	state.coins = 1000
	var plain_price: int = state.price_of(Items.by_id("skipper"))
	state.perks.append("coupon")
	_check(state.price_of(Items.by_id("skipper")) < plain_price, "the coupon cuts prices")
	state.course.hole_index = state.course.hole_count() - 2
	_check(state.price_of(Items.by_id("skipper")) == roundi(float(Items.by_id("skipper")["price"]) * 0.8), "the coupon takes 20% off")
	state.course.hole_index = 0
	state.perks.append("coin_purse")
	state.begin_hole()
	_check(state.collect_coin() == 2, "the coin purse doubles pickups")
	state.perks.append("showman")
	_check(state.collect_trick(5) == 5, "the showman makes trick shots pay")
	state.perks.append("birdie_bank")
	_check(state.hole_payout(0, 3, 4) == 8, "the birdie bank pays extra under par")
	_check(state.hole_payout(0, 4, 4) == 3, "the birdie bank doesn't pay for par")
	_check(state.hole_payout(0, 5, 4) == 3, "the birdie bank doesn't pay over par")
	state.perks.append("steady_pay")
	_check(state.hole_payout(0, 4, 4) == 6, "steady pay adds to par")
	_check(state.hole_payout(5, 4, 4) == 8, "perks add to a later hole's pay too")
	_check(state.hole_payout(0, 5, 4) == 3, "steady pay doesn't pay over par")
	state.perks.append("extra_shelf")
	_check(state.roll_stock().size() == RunState.SHOP_SHELVES + 1, "the extra shelf adds to the stock")

	var net: RunState = _new_run_state()
	_check(net.use_safety_net() == 0, "no net, no save")
	net.perks.append("safety_net")
	var before: int = net.spare
	_check(net.use_safety_net() == 3 and net.spare == before + 3, "the net gives 3 strokes")
	_check(net.use_safety_net() == 0, "the net only works once a run")

	# A mulligan forgives one penalty a hole.
	var game := HoleGame.new(_game().hole, _clubs())
	game.free_penalties = 1
	var forgiven: Array[bool] = []
	game.penalty_forgiven.connect(func() -> void: forgiven.append(true))
	game._on_ball_hazard(Vector2.ZERO, "water")
	_check(game.strokes == 0 and forgiven.size() == 1, "the first penalty is free")
	_finish_shot(game)
	game._on_ball_hazard(Vector2.ZERO, "water")
	_check(game.strokes == 1 and forgiven.size() == 1, "the next one costs a stroke")


func _test_item_catalog() -> void:
	var ids: Dictionary = {}
	for item: Dictionary in Items.CATALOG:
		var id: String = str(item["id"])
		_check(not ids.has(id), "%s has a unique id" % id)
		ids[id] = true
		_check(str(item["name"]).length() <= 14, "%s has a name that fits a card" % id)
		_check(str(item["text"]).length() <= 22, "%s has text that fits a card" % id)
		_check(int(item["price"]) > 0, "%s has a price" % id)
		for text: String in [str(item["name"]), str(item["text"])]:
			for i in text.length():
				_check(text[i] == " " or PixelFont.GLYPHS.has(text[i]), "%s only uses letters the font has" % id)
		if item["kind"] == Items.KIND_STICKER:
			_check(not (item["clubs"] as Array).is_empty(), "%s fits at least one club" % id)
	_check(Items.unlock_order().size() >= 6, "there's plenty to unlock")
	var seen_order: Array[String] = Items.unlock_order()
	_check(seen_order[0] == "forgiver", "unlocks come in order")


func _test_final_score() -> void:
	var state: RunState = _new_run_state()
	state.coins = 10
	for i in 2:
		state.finish_hole(state.course.current_hole().par - 1)
		state.course.advance()
	# Two birdies: 2 holes, 2 under, 10 spare, and coins of 10 + 3 + 3.
	var score: Dictionary = state.final_score()
	var expected: int = 2 * 100 + 2 * 100 + 10 * 50 + 16 * 2
	_check(int(score["total"]) == expected, "the final score adds up (%d, %d)" % [score["total"], expected])
	_check((score["rows"] as Array).size() == 4, "no rival bonus before beating it")
	state.ending = RunState.Ending.BEAT_RIVAL
	var winning: Dictionary = state.final_score()
	_check(int(winning["total"]) == expected + 1000, "beating the rival adds its bonus")
	_check(state.is_finished_run(), "a duel finishes the run")
	state.ending = RunState.Ending.OUT_OF_STROKES
	_check(not state.is_finished_run(), "running out isn't a finished run")

	var terrible: RunState = _new_run_state()
	terrible.spare = -5
	terrible.finish_hole(30)
	_check(int(terrible.final_score()["total"]) == 0, "the score never goes below zero")
	_check(int(_score_row(terrible, "SPARE")) == 0, "spare strokes never score below zero")


func _score_row(state: RunState, label_start: String) -> int:
	for row: Dictionary in state.final_score()["rows"]:
		if str(row["label"]).begins_with(label_start):
			return int(row["points"])
	return -1


func _test_profile() -> void:
	var path: String = "user://test_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	_check(profile.high_scores.is_empty() and profile.unlocked.is_empty(), "a new profile starts empty")

	var lost: RunState = _new_run_state()
	lost.ending = RunState.Ending.LOST_TO_RIVAL
	var first: Dictionary = profile.record_run(lost)
	_check(int(first["place"]) == 1, "the first score is the best so far")
	_check((first["unlocked"] as Array).size() == 1 and profile.unlocked == ["forgiver"], "a finished run unlocks one item")

	var out: RunState = _new_run_state()
	out.ending = RunState.Ending.OUT_OF_STROKES
	out.spare = 0
	var dead: Dictionary = profile.record_run(out)
	_check((dead["unlocked"] as Array).is_empty(), "running out unlocks nothing")
	_check(profile.runs_finished == 1, "running out isn't a finished run")

	var won: RunState = _new_run_state()
	won.ending = RunState.Ending.BEAT_RIVAL
	var victory: Dictionary = profile.record_run(won)
	_check(int(victory["place"]) == 1, "a better score goes to the top")
	_check((victory["unlocked"] as Array).size() == 2, "beating the rival unlocks two")

	var reloaded := Profile.new(path)
	_check(reloaded.high_scores.size() == 3 and reloaded.runs_finished == 2, "scores survive a restart")
	_check(reloaded.unlocked.size() == 3, "unlocks survive a restart")
	_check(int(reloaded.high_scores[0]["score"]) >= int(reloaded.high_scores[1]["score"]), "scores stay in order")

	for _i in 20:
		var filler: RunState = _new_run_state()
		filler.ending = RunState.Ending.LOST_TO_RIVAL
		reloaded.record_run(filler)
	_check(reloaded.high_scores.size() == Profile.MAX_SCORES, "only the top scores are kept")
	_check(reloaded.unlocked.size() == Items.unlock_order().size(), "everything can be unlocked, and it stops there")

	var bad_file := FileAccess.open(path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify({ "high_scores": ["oops", { "score": "x" }], "unlocked": ["no_such_item", 3], "runs_finished": "many" }))
	bad_file.close()
	var damaged := Profile.new(path)
	_check(damaged.unlocked.is_empty() and damaged.runs_finished == 0, "a damaged profile is cleaned up")
	DirAccess.remove_absolute(path)
	_test_collection()
	_test_wardrobe()


func _test_wardrobe() -> void:
	# Each model has five colors of everything, and a column is the same color all the way down.
	var ids: Dictionary = {}
	_check(Wardrobe.SLOTS == [Wardrobe.SHIRT, Wardrobe.BOTTOMS, Wardrobe.SHOES, Wardrobe.HAT], "no gloves or sunglasses")
	for model: String in Wardrobe.MODELS:
		var shirts: Array[Dictionary] = Wardrobe.items_for(model, Wardrobe.SHIRT)
		for slot: String in Wardrobe.SLOTS:
			var items: Array[Dictionary] = Wardrobe.items_for(model, slot)
			_check(items.size() == 5, "%s %s has five colors" % [model, slot])
			for i in items.size():
				var item: Dictionary = items[i]
				_check(not ids.has(item["id"]), "%s is the only piece with that id" % item["id"])
				ids[item["id"]] = true
				_check(Wardrobe.by_id(str(item["id"]))["name"] == item["name"], "%s can be found again" % item["id"])
				_check(item["main"] == shirts[i]["main"], "%s matches its column" % item["id"])
			_check(int(items[0]["price"]) == 0 and str(items[0]["unlock"]) == "", "%s %s's first color is free" % [model, slot])
			_check(int(items[1]["price"]) == 15 and int(items[2]["price"]) == 15, "%s %s's next two cost 15" % [model, slot])
			_check(str(items[3]["name"]).begins_with("BLACK") and items[3]["unlock"] == Wardrobe.UNLOCK_RIVAL, "black comes from the rival")
			_check(str(items[4]["name"]).begins_with("GOLD") and items[4]["unlock"] == Wardrobe.UNLOCK_ISLES, "gold comes from the 4000 yard isles")
			_check(int(items[3]["price"]) == 0 and int(items[4]["price"]) == 0, "earned colors cost nothing")
	_check(Wardrobe.items_for(Wardrobe.FEMALE, Wardrobe.SHIRT)[0]["name"] == "WHITE SHIRT", "her first shirt is white, like the rest of the column")

	# Buying and wearing.
	var path: String = "user://test_wardrobe_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	_check(profile.wallet == 50, "every save starts with 50 coins")
	_check(profile.model == Wardrobe.MALE, "the golfer starts as male")
	var start: Dictionary = profile.worn_pieces(Wardrobe.MALE)
	_check(start.size() == 4, "wearing all four pieces")
	for slot: String in Wardrobe.SLOTS:
		_check(start[slot]["main"] == Color("f2efe4"), "the starting %s is white" % slot)
	_check(profile.owns_clothes("female_shirt_white") and not profile.owns_clothes("female_shirt_coral"), "only free pieces are owned at first")
	_check(not profile.owns_clothes("male_hat_black") and not profile.owns_clothes("male_hat_gold"), "black and gold start locked")
	_check(not profile.buy_clothes("male_hat_black") and not profile.wear_clothes(Wardrobe.MALE, Wardrobe.HAT, "male_hat_black"), "a locked color can't be had")
	_check(not profile.wear_clothes(Wardrobe.MALE, Wardrobe.SHIRT, "male_shirt_red"), "clothes must be bought before wearing")
	_check(not profile.wear_clothes(Wardrobe.MALE, Wardrobe.SHIRT, "female_shirt_white"), "a model can't wear the other's clothes")
	_check(not profile.wear_clothes(Wardrobe.MALE, Wardrobe.SHIRT, ""), "a golfer can't go without a shirt")
	_check(profile.buy_clothes("male_shirt_red") and profile.wallet == 35, "a color costs 15")
	_check(profile.buy_clothes("male_shirt_red") and profile.wallet == 35, "buying it again costs nothing")
	_check(profile.wear_clothes(Wardrobe.MALE, Wardrobe.SHIRT, "male_shirt_red"), "a bought piece can be worn")
	profile.wallet = 10
	_check(not profile.buy_clothes("male_shirt_blue") and profile.wallet == 10, "a piece that can't be afforded isn't bought")

	# Black for beating the rival, gold for finishing the 4000 yard isles.
	profile.rival_beaten = true
	_check(profile.owns_clothes("female_skirt_black") or profile.owns_clothes("female_bottoms_black"), "beating the rival opens black")
	_check(profile.wear_clothes(Wardrobe.FEMALE, Wardrobe.BOTTOMS, "female_bottoms_black") and profile.wallet == 10, "for free")
	profile.record_isles(2000, 30, 0)
	_check(not profile.owns_clothes("male_hat_gold"), "a shorter isles course doesn't open gold")
	profile.record_isles(4000, 60, 3)
	_check(profile.owns_clothes("male_hat_gold") and profile.wear_clothes(Wardrobe.MALE, Wardrobe.HAT, "male_hat_gold"), "finishing the 4000 yard isles opens gold")

	# Leftover coins go in the wallet, however the run ended.
	var lost: RunState = _new_run_state()
	lost.ending = RunState.Ending.GAVE_UP
	lost.coins = 300
	var result: Dictionary = profile.record_run(lost)
	_check(int(result["coins_saved"]) == 300 and profile.wallet == 310, "leftover coins are saved")
	profile.set_model(Wardrobe.FEMALE)

	var reloaded := Profile.new(path)
	_check(reloaded.wallet == 310 and reloaded.model == Wardrobe.FEMALE, "the wallet and model survive a restart")
	_check(reloaded.owned_clothes == ["male_shirt_red"] and str(reloaded.clothes[Wardrobe.FEMALE][Wardrobe.BOTTOMS]) == "female_bottoms_black", "and so do the clothes")
	_check(str(reloaded.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_gold", "each model keeps its own")

	# Clothes that were taken out are paid back once, and what was worn goes back to white.
	var old_file := FileAccess.open(path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({ "wallet": 10, "model": "female", "owned_clothes": ["male_shirt_checkered", "female_gloves_0", "male_hat_2", "male_shirt_red"], "clothes": { "male": { "shirt": "male_shirt_checkered", "gloves": "female_gloves_0" }, "female": { "bottoms": "female_bottoms_0" } } }))
	old_file.close()
	var old_save := Profile.new(path)
	_check(old_save.wallet == 10 + 40 + 15 + 15, "removed clothes are paid back")
	_check(old_save.owned_clothes == ["male_shirt_red"], "and only clothes that still exist are kept")
	_check(str(old_save.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_white" and old_save.worn_pieces(Wardrobe.MALE).size() == 4, "a removed piece goes back to white")
	_check(Profile.new(path).wallet == old_save.wallet, "and the refund isn't paid twice")

	# Damaged saves can't hand out clothes, and saves from before clothes start off right.
	var bad_file := FileAccess.open(path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify({ "wallet": -5, "model": "robot", "owned_clothes": ["nope", 3, "male_hat_black"], "clothes": { "male": { "shirt": "male_shirt_blue", "hat": "female_hat_white", "shoes": 7 }, "female": "x" } }))
	bad_file.close()
	var damaged := Profile.new(path)
	_check(damaged.wallet == 0 and damaged.model == Wardrobe.MALE, "a damaged wardrobe is cleaned up")
	_check(str(damaged.clothes[Wardrobe.MALE][Wardrobe.SHIRT]) == "male_shirt_white" and str(damaged.clothes[Wardrobe.MALE][Wardrobe.HAT]) == "male_hat_white", "and can't wear what it doesn't own")
	_check(not damaged.owns_clothes("male_hat_black"), "or claim a locked color")
	var older_file := FileAccess.open(path, FileAccess.WRITE)
	older_file.store_string(JSON.stringify({ "runs_finished": 4 }))
	older_file.close()
	var older_save := Profile.new(path)
	_check(older_save.wallet == 50 and older_save.runs_finished == 4, "a save from before clothes gets the starting coins")
	DirAccess.remove_absolute(path)


func _test_collection() -> void:
	# Every item has a picture of the right size, using colors that exist.
	for item: Dictionary in Items.CATALOG:
		var id: String = str(item["id"])
		var rows: Array = ItemArt.ART.get(id, [])
		_check(rows.size() == ItemArt.SIZE, "%s has a full picture" % id)
		for y in rows.size():
			var line: String = rows[y]
			_check(line.length() == ItemArt.SIZE, "%s picture row %d is the right width" % [id, y])
			for letter in line:
				_check(letter == "." or ItemArt.COLORS.has(letter), "%s picture uses a known color" % id)
	_check(ItemArt.ART.size() == Items.CATALOG.size() + 1, "no pictures of things that don't exist, besides the plain ball")
	_check(ItemArt.ART.has(CollectionScreen.PLAIN_BALL["id"]), "the plain ball has a picture")

	# No two locked items share a silhouette, or locked items would look the same.
	var shapes: Dictionary = {}
	for id: String in Items.unlock_order():
		var shape: String = ""
		for line: String in ItemArt.ART[id]:
			for letter in line:
				shape += "." if letter == "." else "#"
		_check(not shapes.has(shape), "%s has its own silhouette" % id)
		shapes[shape] = true

	var path: String = "user://test_collection_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	_check(profile.has_item("power_stripe"), "items on sale from the start are owned")
	_check(not profile.has_item("forgiver"), "an unearned item isn't owned")
	_check(not profile.has_item("no_such_item"), "something that doesn't exist isn't owned")

	var screen := CollectionScreen.new()
	screen.setup(profile)
	var listed: int = 0
	for row: Array in screen.rows:
		listed += row.size()
	_check(listed == Items.CATALOG.size() + 1 and listed == screen.count_all(), "the collection lists everything exactly once, and the plain ball")
	_check(screen.rows[1][0] == CollectionScreen.PLAIN_BALL, "the plain ball comes first among the balls")
	_check(screen.describe(CollectionScreen.PLAIN_BALL)["name"] == "PLAIN BALL", "the plain ball is never locked")
	var start_count: int = Items.CATALOG.size() - Items.unlock_order().size() + 1
	_check(screen.count_owned() == start_count, "a new player has only the starting items")

	var locked: Dictionary = screen.describe(Items.by_id("forgiver"))
	_check(locked["name"] == CollectionScreen.HIDDEN_NAME, "a locked item's name is hidden")
	var forgiver: Dictionary = Items.by_id("forgiver")
	for key: String in locked:
		_check(not str(locked[key]).contains(str(forgiver["name"])), "a locked item doesn't give away its name")
		_check(not str(locked[key]).contains(str(forgiver["text"])), "a locked item doesn't give away its effect")

	var lost: RunState = _new_run_state()
	lost.ending = RunState.Ending.LOST_TO_RIVAL
	profile.record_run(lost)
	_check(profile.has_item("forgiver"), "finishing a duel earns the item")
	_check(screen.count_owned() == start_count + 1, "the count goes up with it")
	_check(screen.describe(forgiver)["name"] == forgiver["name"], "an earned item shows its name")
	_check(not Items.by_id("forgiver").is_empty() and not profile.has_item("two_way_tape"), "the next item stays locked")

	# Moving round the grid, including through the short row and back.
	screen.move(Vector2i.LEFT)
	_check(screen.row == 0 and screen.column == (screen.rows[0] as Array).size() - 1, "left wraps round the row")
	screen.move(Vector2i.UP)
	_check(screen.row == screen.rows.size() - 1 and screen.column == 0, "up wraps to the short bonus row")
	screen.move(Vector2i.DOWN)
	_check(screen.row == 0 and screen.column == (screen.rows[0] as Array).size() - 1, "passing through the short row keeps your place")
	for _i in 40:
		screen.move(Vector2i.DOWN)
		screen.move(Vector2i.RIGHT)
		_check(not screen.selected_item().is_empty(), "the selection is always on an item")
	screen.free()
	DirAccess.remove_absolute(path)
	_test_infinite_mode()
	_test_floating_isles()
	_test_swampy_shores()


func _test_swampy_shores() -> void:
	_test_swamp_course_files()
	_test_mud()
	_test_lily_pads()
	_test_frogs()
	_test_vents()
	_test_gators()
	_test_swamp_windmill()
	_test_swamp_rival()
	_test_second_course_run()
	_test_swamp_generator()
	_test_swamp_saving_and_editing()


func _swamp_run() -> CourseRun:
	return CourseRun.new(load(MapLibrary.SWAMP_COURSE_PATH) as CourseData)


func _test_swamp_course_files() -> void:
	var run: CourseRun = _swamp_run()
	_check(run.hole_count() == 10 and run.hole_at(9).display_name == "BOSS HOLE", "the swamp has 9 holes and a boss")
	var kinds: Dictionary = {}
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		var terrain := Terrain.new(hole)
		_check(hole.biome == HoleData.BIOME_SWAMP, "%s is in the swamp" % hole.title)
		_check(terrain.surface_at(hole.cup_x) == Surface.Type.GREEN, "%s has its cup on the green" % hole.title)
		_check(terrain.surface_at(hole.tee_x) == Surface.Type.TEE, "%s has a tee" % hole.title)
		for entry: Dictionary in hole.obstacles:
			kinds[str(entry["kind"])] = true
			if str(entry["kind"]) == "lily":
				_check(terrain.surface_at(float(entry["x"])) == Surface.Type.LILY, "%s's pads sit on water" % hole.title)
			if ["vent", "gator", "windmill"].has(str(entry["kind"])):
				_check(not terrain.is_wet(float(entry["x"])), "%s's %s stands on land" % [hole.title, entry["kind"]])
		for x: int in range(0, terrain.length, 25):
			if terrain.surface_at(float(x)) == Surface.Type.MUD:
				kinds["mud"] = true
		var copy: HoleData = HoleIO.from_dict(HoleIO.to_dict(hole))
		_check(copy != null and copy.obstacles.size() == hole.obstacles.size() and copy.biome == hole.biome, "%s survives being saved" % hole.title)
		# Trees here keep the same rule: no gap between trunk and leaves.
		for piece: Dictionary in hole.scenery:
			if str(piece["kind"]) == "trunk":
				var leaves: Dictionary = (hole.scenery.filter(func(other: Dictionary) -> bool: return str(other["kind"]) == "leaves" and is_equal_approx(float(other["x"]), float(piece["x"]))) as Array)[0]
				_check(TreeView.leaves_cover_trunk(piece, leaves, terrain), "%s's tree at %d is whole" % [hole.title, int(piece["x"])])
	for wanted: String in ["frog", "vent", "gator", "windmill", "lily", "mud"]:
		_check(kinds.has(wanted), "the swamp course uses %s" % wanted)
	for kind: String in ["cart", "sprinkler", "goose", "roots"]:
		_check(not kinds.has(kind), "and has no %s" % kind)
	var boss_kinds: Array = run.hole_at(9).obstacles.map(func(entry: Dictionary) -> String: return str(entry["kind"]))
	for wanted: String in ["frog", "vent", "gator", "windmill", "lily", "pad"]:
		_check(boss_kinds.has(wanted), "the swamp's boss hole has %s" % wanted)
	var traps: Array[String] = []
	for i in run.hole_count():
		var game := HoleGame.new(run.hole_at(i), _clubs())
		for x in range(5, game.terrain.length - 5, 20):
			if game.terrain.surface_at(float(x)) == Surface.Type.WATER or game.terrain.in_cup(float(x)):
				continue
			game.ball.place(float(x))
			game._begin_aim()
			if not _can_get_out(game):
				traps.append("%s %d" % [run.hole_at(i).title, x])
	_check(traps.is_empty(), "no spot in the swamp is a trap (%s)" % str(traps))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2030
	for i in run.hole_count():
		_check(_play_round(run.hole_at(i), rng, 0.0, 0.0, true) > 0, "%s can be finished" % run.hole_at(i).title)
		_check(_play_round(run.hole_at(i), rng, 0.06, 0.05, true) > 0, "%s can be finished by an average player" % run.hole_at(i).title)


func _test_mud() -> void:
	var finish := func(type: int) -> float:
		var hole: HoleData = _flat_hole({ "spans": [{ "from": 0, "to": 1000, "type": type }] })
		var sim := BallSim.new(Terrain.new(hole))
		sim.place(100.0)
		sim.launch(Vector2(120.0, -120.0), 0.0)
		_settle(sim)
		return sim.pos.x
	var on_mud: float = finish.call(Surface.Type.MUD)
	_check(on_mud < float(finish.call(Surface.Type.FAIRWAY)), "a ball runs on less in mud than on fairway")
	_check(on_mud < float(finish.call(Surface.Type.ROUGH)), "and less than in rough")
	var mud_lie: Dictionary = Surface.props(Surface.Type.MUD)
	_check(float(mud_lie["lie_power"]) < 1.0 and float(mud_lie["lie_window"]) < 1.0, "a shot out of mud loses range and shrinks the sweet spot")
	_check(float(mud_lie["lie_power"]) > float(Surface.props(Surface.Type.SAND)["lie_power"]), "but not as much as out of a bunker")


func _pond_hole() -> HoleData:
	var hole: HoleData = _flat_hole({
		"cup_x": 900.0,
		"water": [{ "from": 300, "to": 600, "level": 300.0 }],
	})
	hole.points = PackedVector2Array([Vector2(0, 280), Vector2(290, 280), Vector2(310, 330), Vector2(590, 330), Vector2(610, 280), Vector2(1000, 280)])
	hole.obstacles = [{ "kind": "lily", "x": 450.0, "width": 60.0 }]
	return hole


func _test_lily_pads() -> void:
	var hole: HoleData = _pond_hole()
	var terrain := Terrain.new(hole)
	_check(terrain.surface_at(450.0) == Surface.Type.LILY, "a pad covers the water")
	_check(terrain.surface_at(350.0) == Surface.Type.WATER, "the rest is still water")
	_check(terrain.is_wet(450.0) and terrain.is_wet(350.0) and not terrain.is_wet(200.0), "water still lies under it")
	var drop := func(x: float) -> int:
		var sim := BallSim.new(terrain)
		sim.pos = Vector2(x, 250.0)
		sim.launch(Vector2(0.0, 10.0), 0.0)
		_settle(sim)
		return sim.state
	_check(drop.call(450.0) == BallSim.State.RESTING, "a ball can land on a pad")
	_check(drop.call(350.0) == BallSim.State.IN_WATER, "and goes in beside it")
	var rolling := BallSim.new(terrain)
	rolling.place(470.0)
	rolling.launch(Vector2(90.0, 0.0), 0.0)
	_settle(rolling)
	_check(rolling.state == BallSim.State.IN_WATER, "a ball rolling off the edge goes in")
	var game := HoleGame.new(hole, _clubs())
	game.start_from(450.0)
	_check(game.phase == HoleGame.Phase.AIM and _has_safe_shot(game), "a ball on a pad can be played from it")
	_check(game.lie_power() < 1.0 and game.lie_power() > 0.8, "with a slightly wobbly lie")
	# Water penalties still send it back to where it was, the pad included.
	game.select_club(1)
	game.aim_angle = 60.0
	game.strike_with(0.05, 0.0)
	var steps: int = 0
	while game.phase != HoleGame.Phase.AIM and steps < 3000:
		game.tick(DT)
		steps += 1
	_check(game.terrain.surface_at(game.ball.pos.x) != Surface.Type.WATER, "the ball never ends up resting in water")


func _test_frogs() -> void:
	var hole: HoleData = _flat_hole()
	var terrain := Terrain.new(hole)
	var frog := FrogObstacle.new(terrain, { "from": 400.0, "to": 500.0, "start": 450.0, "speed": 60.0 })
	var lowest: float = -INF
	var highest: float = INF
	var turned: bool = false
	for _i in 1200:
		frog.tick(DT)
		lowest = maxf(lowest, frog.center().y)
		highest = minf(highest, frog.center().y)
		turned = turned or frog.x >= 500.0
		_check(frog.x >= 400.0 and frog.x <= 500.0, "a frog stays on its route")
	_check(turned, "it turns back at the ends")
	_check(lowest > highest + 8.0 and lowest >= terrain.ground_y(450.0) - FrogObstacle.RADIUS - 0.01, "it hops off the ground and lands on it")
	var sim := BallSim.new(terrain)
	# Sitting still on the ground, between hops.
	var sitting := FrogObstacle.new(terrain, { "from": 500.0, "to": 501.0, "speed": 0.0 })
	sitting.clock = FrogObstacle.HOP_TIME
	sim.obstacles = [sitting] as Array[Obstacle]
	var hits: Array[String] = []
	sim.obstacle_hit.connect(func(_at: Vector2, kind: String) -> void: hits.append(kind))
	sim.place(300.0)
	sim.launch(Vector2(250.0, 0.0), 0.0)
	_settle(sim)
	_check(hits.has("frog"), "a rolling ball hits a frog")
	_check(sim.pos.x < 500.0, "and gets knocked back from it (%.0f)" % sim.pos.x)
	_check(hits.count("frog") == 1, "only once in the shot")
	var preview := BallSim.new(terrain)
	preview.obstacles = sim.obstacles
	preview.ignore_moving = true
	preview.place(300.0)
	preview.launch(Vector2(250.0, 0.0), 0.0)
	_settle(preview)
	_check(preview.pos.x > 500.0, "the aim guide ignores frogs, like every moving hazard")


func _test_vents() -> void:
	var terrain := Terrain.new(_flat_hole())
	var vent := VentObstacle.new(terrain, { "x": 500.0, "height": 80.0, "quiet_time": 2.0, "burst_time": 1.0 })
	_check(vent.stage() == VentObstacle.Stage.QUIET, "a vent starts quiet")
	vent.tick(2.1)
	_check(vent.stage() == VentObstacle.Stage.WARNING, "then bubbles a warning")
	vent.tick(VentObstacle.WARNING_TIME)
	_check(vent.stage() == VentObstacle.Stage.BURST, "then bursts")
	var make_ball := func(y: float) -> BallSim:
		var sim := BallSim.new(terrain)
		sim.state = BallSim.State.AIRBORNE
		sim.launch_x = 100.0
		sim.pos = Vector2(500.0, y)
		sim.vel = Vector2(80.0, 40.0)
		return sim
	var thrown: BallSim = make_ball.call(270.0)
	_check(vent.interact(thrown, DT), "a ball in the burst is caught")
	_check(thrown.vel.y < -100.0, "and thrown upward")
	var first_vel: Vector2 = thrown.vel
	vent.interact(thrown, DT)
	_check(thrown.vel == first_vel, "only once per burst")
	var above: BallSim = make_ball.call(150.0)
	_check(not vent.interact(above, DT), "a ball over the top of it passes")
	var preview: BallSim = make_ball.call(270.0)
	preview.ignore_moving = true
	_check(not vent.interact(preview, DT), "the aim guide ignores it")
	var drifts: Dictionary = {}
	for _i in VentObstacle.DRIFTS.size():
		drifts[vent.drift()] = true
		vent.tick(vent.quiet_time + VentObstacle.WARNING_TIME + vent.burst_time)
	_check(drifts.size() == VentObstacle.DRIFTS.size(), "each burst throws a different way")
	for drift: float in VentObstacle.DRIFTS:
		_check(absf(drift) <= 70.0, "none of them far")
	vent.tick(0.0)
	while vent.stage() != VentObstacle.Stage.QUIET:
		vent.tick(0.1)
	_check(not vent.interact(make_ball.call(270.0), DT), "a quiet vent does nothing")
	var beside: BallSim = make_ball.call(270.0)
	beside.launch_x = 498.0
	while vent.stage() != VentObstacle.Stage.BURST:
		vent.tick(0.1)
	_check(not vent.interact(beside, DT), "a ball struck from right beside it isn't caught")


# A hole with a gator on the fairway and nothing else, played through the real rules.
func _gator_game() -> HoleGame:
	var hole: HoleData = _flat_hole({ "cup_x": 950.0 })
	hole.obstacles = [{ "kind": "gator", "x": 500.0, "side": -1.0 }]
	return HoleGame.new(hole, _clubs())


func _test_gators() -> void:
	var game: HoleGame = _gator_game()
	var gator: GatorObstacle = game.obstacles[0]
	var terrain: Terrain = game.terrain
	_check(gator.jaw == 0.0 and not gator.eaten, "a gator lies with its mouth shut")
	game.ball.place(350.0)
	var kinds: Array[String] = []
	game.penalty_taken.connect(func(kind: String) -> void: kinds.append(kind))
	game.ball.launch(Vector2(240.0, 0.0), 0.0)
	game._last_spot_x = 350.0
	game.strokes = 1
	game._set_phase(HoleGame.Phase.BALL_MOVING)
	var widest: float = 0.0
	var steps: int = 0
	while game.ball.is_moving() and steps < 2000:
		game.tick(DT)
		widest = maxf(widest, gator.jaw)
		steps += 1
	_check(widest > 0.5, "it opens its jaws as a ball comes near (%.2f)" % widest)
	_check(game.ball.state == BallSim.State.EATEN, "a ball rolling up to it gets eaten")
	_check(kinds.size() == 1 and kinds[0] == "gator", "that's a penalty")
	_check(game.strokes == 2, "costing a stroke, like water")
	_check(game.phase == HoleGame.Phase.PENALTY, "with the same wait")
	_check(gator.eaten and not gator.is_gone(), "the gator flashes first")
	for _i in int(GatorObstacle.FLASH_TIME / DT) + 2:
		gator.tick(DT)
	_check(gator.is_gone(), "then it's gone")
	while game.phase == HoleGame.Phase.PENALTY:
		game.tick(DT)
	_check(is_equal_approx(game.ball.pos.x, 350.0) and game.ball.state == BallSim.State.RESTING, "the ball goes back to its last spot")
	game.ball.launch(Vector2(240.0, 0.0), 0.0)
	game._set_phase(HoleGame.Phase.BALL_MOVING)
	steps = 0
	while game.ball.is_moving() and steps < 2000:
		game.tick(DT)
		steps += 1
	_check(game.ball.state == BallSim.State.RESTING and game.ball.pos.x > 500.0, "with the gator gone, the same shot runs straight past (%.0f)" % game.ball.pos.x)
	game.restart()
	_check(not gator.eaten and gator.jaw == 0.0, "restarting a hole brings it back")

	var mulligan: HoleGame = _gator_game()
	mulligan.free_penalties = 1
	mulligan.ball.place(350.0)
	mulligan.ball.launch(Vector2(240.0, 0.0), 0.0)
	mulligan._last_spot_x = 350.0
	mulligan._set_phase(HoleGame.Phase.BALL_MOVING)
	while mulligan.phase == HoleGame.Phase.BALL_MOVING:
		mulligan.tick(DT)
	_check(mulligan.strokes == 0 and mulligan.free_penalties == 0, "a Mulligan covers it like any other penalty")

	# High over it is safe, and only a real ball feeds it.
	var play := func(velocity: Vector2, from_x: float, is_preview: bool) -> BallSim:
		var fresh: HoleGame = _gator_game()
		var sim := BallSim.new(terrain)
		sim.obstacles = fresh.obstacles
		sim.ignore_moving = is_preview
		sim.place(from_x)
		sim.launch(velocity, 0.0)
		_settle(sim)
		return sim
	var over: BallSim = play.call(Vector2(130.0, -130.0), 350.0, false)
	_check(over.state == BallSim.State.RESTING and over.pos.x > 530.0, "a ball flying over isn't eaten (%.0f)" % over.pos.x)
	var planned: BallSim = play.call(Vector2(240.0, 0.0), 350.0, true)
	_check(planned.state == BallSim.State.EATEN, "the game's own planning knows it would be eaten")
	var planning: HoleGame = _gator_game()
	var plan_sim: BallSim = planning.new_preview_sim()
	plan_sim.place(350.0)
	plan_sim.launch(Vector2(240.0, 0.0), 0.0)
	_settle(plan_sim)
	_check(not (planning.obstacles[0] as GatorObstacle).eaten, "and planning a shot doesn't use up the gator")
	var beside: BallSim = play.call(Vector2(-200.0, 0.0), 490.0, false)
	_check(beside.state == BallSim.State.RESTING, "a ball hit from right beside it can always get away")

	# The rival's ball gets eaten too, and takes its penalty.
	var duel: HoleGame = _gator_game()
	var rival := Rival.new(duel, _clubs(), 3)
	duel.start_duel(rival)
	rival._free_drop_used = true
	rival.ball.place(350.0)
	rival.ball.launch(Vector2(240.0, 0.0), 0.0)
	rival.stage = Rival.Stage.MOVING
	var rival_strokes: int = rival.strokes
	steps = 0
	while rival.ball.is_moving() and steps < 2000:
		rival.ball.step(DT)
		steps += 1
	_check(rival.ball.state == BallSim.State.EATEN and rival.strokes == rival_strokes + 1, "the rival's ball can be eaten too")
	_check((duel.obstacles[0] as GatorObstacle).eaten, "which feeds that gator")
	duel.end_duel()

	var saved: HoleData = HoleIO.from_dict(HoleIO.to_dict(game.hole))
	_check(saved.obstacles.size() == 1 and str(saved.obstacles[0]["kind"]) == "gator", "a map remembers its gators")
	var old_map: HoleData = HoleIO.from_dict({ "points": [[0, 300], [500, 300]], "obstacles": [{ "kind": "roots", "x": 100.0 }] })
	_check(old_map.obstacles.is_empty(), "a saved map's old roots are simply dropped")


# Swamp windmills are the same object as any other, and only drawn differently.
func _test_swamp_windmill() -> void:
	var run: CourseRun = _swamp_run()
	var found: int = 0
	for i in run.hole_count():
		for entry: Dictionary in run.hole_at(i).obstacles:
			if str(entry["kind"]) == "windmill":
				found += 1
	_check(found >= 3, "the swamp has windmills (%d)" % found)
	var settings: Dictionary = { "x": 500.0, "rotation": 0.0, "turn_speed": 1.2 }
	var finish := func(biome: String) -> Vector2:
		var hole: HoleData = _flat_hole({ "cup_x": 950.0 })
		hole.biome = biome
		var terrain := Terrain.new(hole)
		var sim := BallSim.new(terrain)
		sim.obstacles = [WindmillObstacle.new(terrain, settings)] as Array[Obstacle]
		sim.place(300.0)
		sim.launch(Vector2(100.0, -90.0), 0.0)
		for _step in 3000:
			sim.obstacles[0].tick(DT)
			sim.step(DT)
		return sim.pos
	_check(finish.call(HoleData.BIOME_SWAMP) == finish.call(HoleData.BIOME_GRASSY), "a swamp windmill plays exactly like the normal one")


func _test_swamp_rival() -> void:
	var game := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	var level: int = Difficulty.swamp_rival_level(0)
	var rival := Rival.new(game, _clubs(), 3, level)
	_check(rival._miss_chance < Rival.MISS_CHANCE, "the swamp's rival mishits less")
	_check(rival._power_steps > Rival.POWER_STEPS, "and plans more finely")
	rival.limit_cheats(Rival.CHEATS_PER_HOLE)
	_check(rival._cheats_left == 2, "but still cheats only twice")
	var late := Rival.new(game, _clubs(), 3, Difficulty.swamp_rival_level(Difficulty.MAX_LEVEL))
	_check(late._cheats_left > 2, "without a limit it would cheat more at the top difficulty")
	late.limit_cheats(Rival.CHEATS_PER_HOLE)
	_check(late._cheats_left == 2, "the limit holds there too")
	_check(Difficulty.swamp_rival_level(Difficulty.MAX_LEVEL) == Difficulty.MAX_LEVEL, "its level stops at the top")
	# Two cheats means two, with a free drop counted.
	var tally: Array[String] = []
	var duel := HoleGame.new(_flat_hole({ "cup_x": 990.0 }), _clubs())
	var capped := Rival.new(duel, _clubs(), 3, Difficulty.MAX_LEVEL)
	capped.limit_cheats(Rival.CHEATS_PER_HOLE)
	duel.start_duel(capped)
	capped.announced.connect(func(text: String) -> void: tally.append(text))
	capped.strokes = 5
	capped.ball.place(300.0)
	capped._on_ball_hazard(Vector2.ZERO, "water")
	capped._turns = 2
	for _i in 6:
		capped._end_shot()
	_check(tally.size() == 2, "a free drop and one trick use up both (%s)" % str(tally))
	duel.end_duel()


func _test_second_course_run() -> void:
	var state: RunState = _new_run_state()
	state.coins = 40
	state.spare = 11
	state.stickers["iron"] = ["power_stripe"]
	state.perks.append("mulligan")
	state.beat_first_rival()
	_check(state.coins == 40 and state.spare == 11, "coins and spare strokes carry over exactly")
	_check(state.stickers["iron"] == ["power_stripe"] and state.perks.has("mulligan"), "and so does the gear")
	_check(state.set_number == 2 and state.bosses_beaten == 1 and state.ending == RunState.Ending.NONE, "the run goes on to the second course")
	_check(state.rival_beaten_with_more_to_come, "with more to come")
	_check(state.level == 0, "at the same difficulty, since only infinite mode has levels")
	var points: int = 0
	for row: Dictionary in state.final_score()["rows"]:
		if str(row["label"]).contains("RIVAL"):
			points += int(row["points"])
	_check(points == RunState.SCORE_RIVAL_BEATEN, "the first rival is worth its points even if the run ends there")
	state.ending = RunState.Ending.BEAT_RIVAL
	points = 0
	for row: Dictionary in state.final_score()["rows"]:
		if str(row["label"]).contains("RIVAL"):
			points += int(row["points"])
	_check(points == RunState.SCORE_RIVAL_BEATEN * 2, "and beating both is worth both")
	_check(state.is_finished_run(), "it counts as finished")
	state.begin_hole()
	_check(not state.rival_beaten_with_more_to_come, "that flag only lasts for the hole")
	var other: RunState = _new_run_state()
	var perk: Dictionary = Items.by_id("mulligan")
	other.beat_first_rival()
	_check(other.price_of(perk) == int(perk["price"]), "the second course's shops charge full price")
	_check(other.hole_payout(0, 4, 4) == RunState.PAYOUT_LATE, "and its holes all pay in full")
	_check(HoleGenerator.biome_for_set(1) == HoleData.BIOME_GRASSY and HoleGenerator.biome_for_set(2) == HoleData.BIOME_SWAMP and HoleGenerator.biome_for_set(3) == HoleData.BIOME_GRASSY, "infinite sets take turns")


func _test_swamp_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var kinds: Dictionary = {}
	for level: int in [0, 4, 10]:
		for hole: HoleData in HoleGenerator.generate_set(rng, level, HoleData.BIOME_SWAMP):
			_check(hole.biome == HoleData.BIOME_SWAMP, "generated holes can be swamp")
			var terrain := Terrain.new(hole)
			_check(terrain.surface_at(hole.cup_x) == Surface.Type.GREEN, "with the cup on the green")
			for entry: Dictionary in hole.obstacles:
				kinds[str(entry["kind"])] = true
			for span: Dictionary in hole.surface_spans:
				_check(int(span["type"]) != Surface.Type.SAND, "with mud in place of sand")
			for piece: Dictionary in hole.scenery:
				if str(piece["kind"]) == "trunk":
					var leaves: Dictionary = (hole.scenery.filter(func(other: Dictionary) -> bool: return str(other["kind"]) == "leaves" and is_equal_approx(float(other["x"]), float(piece["x"]))) as Array)[0]
					_check(TreeView.leaves_cover_trunk(piece, leaves, terrain), "and whole trees")
	for wanted: String in ["frog", "vent", "gator", "windmill", "lily"]:
		_check(kinds.has(wanted), "generated swamp holes use %s" % wanted)
	for kind: String in ["cart", "sprinkler", "goose", "roots"]:
		_check(not kinds.has(kind), "and never %s" % kind)
	# Grassy sets come out exactly as they always have.
	var one := RandomNumberGenerator.new()
	one.seed = 55
	var plain: Array[HoleData] = HoleGenerator.generate_set(one, 3)
	_check(plain[0].biome == HoleData.BIOME_GRASSY, "the default set is grassy")
	for hole: HoleData in plain:
		for entry: Dictionary in hole.obstacles:
			_check(not ["frog", "vent", "gator", "lily"].has(str(entry["kind"])), "with none of the swamp's hazards")


func _test_swamp_saving_and_editing() -> void:
	var hole: HoleData = _pond_hole()
	hole.biome = HoleData.BIOME_SWAMP
	hole.surface_spans = [{ "from": 700, "to": 800, "type": Surface.Type.MUD }]
	var copy: HoleData = HoleIO.from_dict(HoleIO.to_dict(hole))
	_check(copy.biome == HoleData.BIOME_SWAMP, "a map remembers its biome")
	_check(copy.surface_spans.size() == 1 and int(copy.surface_spans[0]["type"]) == Surface.Type.MUD, "and its mud")
	_check(Terrain.new(copy).surface_at(450.0) == Surface.Type.LILY, "and its pads")
	var old: HoleData = HoleIO.from_dict({ "points": [[0, 300], [500, 300]], "biome": "lava" })
	_check(old.biome == HoleData.BIOME_GRASSY, "an unknown biome is grassy")
	var old_save: HoleData = HoleIO.from_dict({ "points": [[0, 300], [500, 300]] })
	_check(old_save.biome == HoleData.BIOME_GRASSY, "and so is a map from before biomes")
	var damaged: HoleData = HoleIO.from_dict({ "points": [[0, 300], [500, 300]], "surface_spans": [{ "from": 0, "to": 10, "type": 77 }], "obstacles": [{ "kind": "frog" }, { "kind": "vent" }] })
	_check(damaged.surface_spans.is_empty() and damaged.obstacles.is_empty(), "damaged entries are dropped")

	var doc := EditorDoc.new(_pond_hole())
	var lily_count: int = doc.hole.obstacles.size()
	for kind: String in ["frog", "vent", "gator", "lily"]:
		doc.checkpoint()
		var selection: Dictionary = doc.add_object(kind, Vector2(400.0, 250.0))
		_check(str(doc.entry_of(selection)["kind"]) == kind, "the editor can place a %s" % kind)
		_check(not doc.properties(selection).is_empty(), "with settings for it")
		_check(doc.pick(doc.selection_center(selection), 4.0) == selection, "and pick it again")
		doc.move_selection(selection, Vector2(380.0, 250.0))
	_check(doc.terrain.surface_at(380.0) == Surface.Type.LILY, "moving a pad moves it for the ball too")
	_check(doc.hole.obstacles.size() == lily_count + 4, "everything was added")
	var frog_selection: Dictionary = { "type": "obstacle", "index": lily_count }
	_check(doc.route_ends(frog_selection).size() == 2, "a frog's route has two ends")
	doc.undo()
	_check(doc.hole.obstacles.size() == lily_count + 3, "undo takes the last one away")
	doc.toggle_biome()
	_check(doc.hole.biome == HoleData.BIOME_SWAMP and doc.terrain.biome == HoleData.BIOME_SWAMP, "the editor changes a map's biome")
	doc.paint_surface(700.0, 750.0, Surface.Type.MUD)
	_check(doc.terrain.surface_at(725.0) == Surface.Type.MUD, "and paints mud")

	var library: MapLibrary = _clean_library()
	var id: String = library.new_custom_id()
	library.save_hole(id, hole)
	var order: Array[String] = library.course_order(HoleData.BIOME_SWAMP)
	order.append(id)
	library.save_course_order(order, HoleData.BIOME_SWAMP)
	_check(library.course_order(HoleData.BIOME_SWAMP).has(id), "a custom map can join the swamp's course")
	_check(not library.course_order().has(id), "without joining the other one")
	_check(not library.list_ids().has("swamp_order"), "the order file isn't listed as a map")
	library.delete_map(id)
	_check(not library.course_order(HoleData.BIOME_SWAMP).has(id), "deleting it takes it out")


# Island 100-299 and island 500-699, with sky everywhere else.
func _two_islands() -> HoleData:
	var hole := HoleData.new()
	hole.tee_x = 200.0
	hole.cup_x = 600.0
	hole.points = PackedVector2Array([Vector2(0, 300), Vector2(500, 300), Vector2(1000, 300)])
	hole.surface_spans = [{ "from": 0, "to": 1000, "type": Surface.Type.FAIRWAY }]
	hole.void_spans = [{ "from": 0, "to": 100 }, { "from": 300, "to": 500 }, { "from": 700, "to": 1001 }]
	return hole


func _settle(sim: BallSim) -> void:
	var steps: int = 0
	while sim.is_moving() and steps < 3000:
		sim.step(1.0 / 60.0)
		steps += 1


func _test_floating_isles() -> void:
	_test_isles_generator()
	_test_isles_physics()
	_test_isles_falls()
	_test_isles_leaderboard()
	_test_isles_club_and_finish()


# The Iron comes up for every shot off the green, and the golfer doesn't jog over open sky.
func _test_isles_club_and_finish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hole: HoleData = IslesGenerator.generate(rng, 1000)
	var game := HoleGame.new(hole, _clubs() as Array[ClubData])
	game.falls_return_to_tee = true
	_check(game.current_club().id == "iron", "Floating Isles starts on the Iron")
	var terrain: Terrain = game.terrain
	var island_spots: int = 0
	var wrong: int = 0
	var x: float = hole.tee_x
	while x < hole.cup_x:
		if not terrain.is_void(x):
			game.start_from(x)
			island_spots += 1
			var wanted: String = "putter" if terrain.surface_at(x) == Surface.Type.GREEN else "iron"
			if game.current_club().id != wanted:
				wrong += 1
		x += 40.0
	_check(island_spots > 5 and wrong == 0, "the Iron off the green and the Putter on it, everywhere (%d wrong of %d)" % [wrong, island_spots])
	game.start_from(hole.tee_x)
	game.select_club(0)
	game.strike_with(0.1, 0.0)
	var steps: int = 0
	while game.phase != HoleGame.Phase.AIM and steps < 6000:
		game.tick(1.0 / 60.0)
		steps += 1
	_check(game.current_club().id == "iron", "and it comes back after using the Driver")
	var plain := HoleGame.new(_flat_hole({ "cup_x": 2500.0 }), _clubs() as Array[ClubData])
	_check(plain.current_club().id == "driver", "the other modes still offer the Driver from far out")

	var view := GolferView.new()
	view.setup(game)
	add_child(view)
	game.ball.state = BallSim.State.HOLED
	game.phase = HoleGame.Phase.COMPLETE
	view.position.x = hole.tee_x
	view._update_pose()
	_check(is_equal_approx(absf(view.position.x - hole.cup_x), GolferView.CELEBRATE_GAP), "the golfer appears right beside the cup")
	_check(not terrain.is_void(view.position.x), "standing on the island")
	view.free()


func _test_isles_generator() -> void:
	var seen: Dictionary = {}
	for seed_value in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + seed_value
		var yards: int = IslesGenerator.COURSE_YARDS[seed_value % IslesGenerator.COURSE_YARDS.size()]
		var hole: HoleData = IslesGenerator.generate(rng, yards)
		var terrain := Terrain.new(hole)
		seen[hole.points] = true
		_check(is_equal_approx(absf(hole.cup_x - hole.tee_x), float(yards) * 3.0), "the hole is the chosen distance from the tee")
		_check(not terrain.is_void(hole.checkpoint_x), "the checkpoint stands on an island")
		_check(not terrain.is_void(hole.checkpoint_from) and terrain.is_void(hole.checkpoint_from - 1.0), "and knows where that island starts")
		_check(terrain.surface_at(hole.checkpoint_x) == Surface.Type.FAIRWAY, "not the tee's or the green's")
		var halfway: float = (hole.tee_x + hole.cup_x) / 2.0
		_check(absf(hole.checkpoint_x - halfway) <= IslesGenerator.GAP_MAX + IslesGenerator.WIDTH_MAX, "it's about halfway")
		_check(not terrain.in_cup(hole.checkpoint_x), "with no hole there")
		for piece: Dictionary in hole.scenery:
			_check(absf(float(piece["x"]) - hole.checkpoint_x) > 40.0, "and no tree in front of its flag")
		_check(terrain.is_floating(), "Floating Isles is a hole of islands")
		_check(not terrain.is_void(hole.tee_x), "the tee is on land")
		_check(not terrain.is_void(hole.cup_x), "and so is the cup")
		_check(terrain.surface_at(hole.tee_x) == Surface.Type.TEE, "the first island is the tee")
		_check(terrain.surface_at(hole.cup_x) == Surface.Type.GREEN, "the last island is the green")
		_check(terrain.is_void(0.0) and terrain.is_void(float(terrain.length)), "both ends of the map are sky")
		var land_from: int = -1
		var sky_from: int = -1
		for x in terrain.length + 1:
			var over_sky: bool = terrain.is_void(float(x))
			if not over_sky and land_from < 0:
				land_from = x
				if sky_from > 0:
					var gap: int = x - sky_from
					_check(gap >= int(IslesGenerator.GAP_MIN) - 2 and gap <= int(IslesGenerator.GAP_MAX) + 2, "every gap is one the clubs can carry")
			elif over_sky and land_from >= 0:
				var width: int = x - land_from
				var special: bool = land_from <= int(hole.tee_x) or x > int(hole.cup_x)
				if not special:
					_check(width <= int(IslesGenerator.WIDTH_MAX) + 2, "the islands are small")
				_check(absf(terrain.slope(float(land_from) + 4.0)) < 0.02, "an island's top is level to the edge")
				_check(terrain.underside_y(float(land_from + width / 2)) > terrain.ground_y(float(land_from + width / 2)) + 20.0, "an island has rock under it")
				land_from = -1
				sky_from = x
	_check(seen.size() == 20, "the map is different every time")
	var first := RandomNumberGenerator.new()
	first.seed = 5
	var second := RandomNumberGenerator.new()
	second.seed = 5
	_check(IslesGenerator.generate(first).points == IslesGenerator.generate(second).points, "the same seed makes the same map")


func _test_isles_physics() -> void:
	var terrain := Terrain.new(_two_islands())
	_check(not Terrain.new(_flat_hole()).is_floating(), "an ordinary hole isn't floating")
	_check(not Terrain.new(_flat_hole()).is_void(50.0), "and has no sky in it")

	var sim := BallSim.new(terrain)
	sim.pos = Vector2(200, 260)
	sim.launch(Vector2(0, 10), 0.0)
	_settle(sim)
	_check(sim.state == BallSim.State.RESTING, "a ball dropped on an island lands on it")

	sim.pos = Vector2(400, 260)
	sim.launch(Vector2(0, 10), 0.0)
	_settle(sim)
	_check(sim.state == BallSim.State.OUT_OF_BOUNDS, "a ball over a gap falls off the map")
	_check(sim.pos.y > float(Terrain.WORLD_HEIGHT), "and only once it's out of the picture")

	sim.place(280.0)
	sim.launch(Vector2(90, 0), 0.0)
	_settle(sim)
	_check(sim.state == BallSim.State.OUT_OF_BOUNDS, "a ball that rolls off the edge falls")

	sim.pos = Vector2(498, 305)
	sim.launch(Vector2(120, 1), 0.0)
	sim.step(1.0 / 60.0)
	_check(sim.vel.x < 0.0, "a ball hitting an island's side bounces off it")
	_check(sim.pos.y > 300.0, "and isn't lifted onto the top")
	_settle(sim)
	_check(sim.state == BallSim.State.OUT_OF_BOUNDS, "then it falls")

	sim.pos = Vector2(480, 420)
	sim.launch(Vector2(300, 1), 0.0)
	_settle(sim)
	_check(sim.state == BallSim.State.OUT_OF_BOUNDS and sim.pos.x > 520.0, "a ball can pass beneath an island")

	var clubs: Array[ClubData] = _clubs()
	var preview := HoleGame.new(_two_islands(), clubs)
	_check(preview.preview()["path"].size() > 0, "the aim guide still works over the sky")


func _test_isles_falls() -> void:
	var game := HoleGame.new(_two_islands(), _clubs())
	game.falls_return_to_tee = true
	for expected in [1, 2]:
		game.start_from(285.0)
		game.select_club(1)
		game.strike_with(0.3, 0.0)
		var steps: int = 0
		while game.phase != HoleGame.Phase.AIM and steps < 2000:
			game.tick(1.0 / 60.0)
			steps += 1
		_check(game.falls == expected, "the fall is counted")
		_check(game.strokes == expected, "strokes carry on through a fall, with no penalty added")
		_check(is_equal_approx(game.ball.pos.x, game.hole.tee_x), "and the ball goes back to the tee")

	var ordinary := HoleGame.new(_two_islands(), _clubs())
	ordinary.start_from(285.0)
	ordinary.select_club(1)
	ordinary.strike_with(0.3, 0.0)
	var count: int = 0
	while ordinary.phase != HoleGame.Phase.AIM and count < 2000:
		ordinary.tick(1.0 / 60.0)
		count += 1
	_check(ordinary.strokes == 2 and is_equal_approx(ordinary.ball.pos.x, 285.0), "without the rule, a lost ball is the usual penalty")
	_test_isles_checkpoint()


# Three islands: the tee's at 100-249, the checkpoint's at 400-549, and the cup's at 700-849.
func _checkpoint_islands() -> HoleData:
	var hole := HoleData.new()
	hole.tee_x = 170.0
	hole.cup_x = 775.0
	hole.checkpoint_x = 475.0
	hole.checkpoint_from = 400.0
	hole.points = PackedVector2Array([Vector2(0, 300), Vector2(500, 300), Vector2(1000, 300)])
	hole.surface_spans = [{ "from": 0, "to": 1000, "type": Surface.Type.FAIRWAY }]
	hole.void_spans = [{ "from": 0, "to": 100 }, { "from": 250, "to": 400 }, { "from": 550, "to": 700 }, { "from": 850, "to": 1001 }]
	return hole


func _play_out(game: HoleGame, club: int, power: float) -> void:
	game.select_club(club)
	game.strike_with(power, 0.0)
	var steps: int = 0
	while game.phase != HoleGame.Phase.AIM and steps < 2000:
		game.tick(1.0 / 60.0)
		steps += 1


func _test_isles_checkpoint() -> void:
	var game := HoleGame.new(_checkpoint_islands(), _clubs())
	game.falls_return_to_tee = true
	var touches: Array[int] = [0]
	game.checkpoint_touched.connect(func() -> void: touches[0] += 1)

	_play_out(game, 2, 0.05)
	_check(not game.checkpoint_reached, "resting short of the checkpoint doesn't reach it")
	game.start_from(240.0)
	_play_out(game, 1, 0.3)
	_check(not game.checkpoint_reached and is_equal_approx(game.ball.pos.x, game.hole.tee_x), "a fall before the checkpoint goes back to the tee")

	game.start_from(450.0)
	_check(not game.checkpoint_reached, "being put on its island isn't reaching it")
	_play_out(game, 2, 0.05)
	_check(game.checkpoint_reached and touches[0] == 1, "coming to rest on its island reaches it")

	game.start_from(540.0)
	var strokes_before: int = game.strokes
	_play_out(game, 1, 0.3)
	_check(is_equal_approx(game.ball.pos.x, game.hole.checkpoint_x - HoleGame.CHECKPOINT_STAND_OFF), "a fall after it goes back to the checkpoint")
	_check(not game.terrain.is_void(game.ball.pos.x), "which is on land")
	_check(game.strokes == strokes_before + 1, "with strokes still counted and no penalty")
	_check(game.phase == HoleGame.Phase.AIM, "and play carries on from there")
	_play_out(game, 2, 0.05)
	_check(touches[0] == 1, "it only announces itself once")
	game.start_from(240.0)
	_play_out(game, 1, 0.3)
	_check(game.ball.pos.x > game.hole.checkpoint_from, "and it's kept, whatever island the fall was from")

	var long_shot := HoleGame.new(_checkpoint_islands(), _clubs())
	long_shot.falls_return_to_tee = true
	long_shot.start_from(710.0)
	_play_out(long_shot, 2, 0.05)
	_check(long_shot.checkpoint_reached, "resting on an island past it counts too")

	long_shot.restart()
	_check(not long_shot.checkpoint_reached, "and starting over clears it")

	var ordinary := HoleGame.new(_checkpoint_islands(), _clubs())
	ordinary.start_from(450.0)
	_play_out(ordinary, 2, 0.05)
	_check(not ordinary.checkpoint_reached, "outside Floating Isles it does nothing")


func _test_isles_leaderboard() -> void:
	var path := "user://test_isles_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	_check(profile.best_isles_strokes(4000) == 0, "no best before a first crossing")
	_check(profile.record_isles(4000, 50, 3) == 1, "a first crossing tops the table")
	_check(profile.record_isles(4000, 40, 0) == 1, "fewer strokes go above it")
	_check(profile.record_isles(4000, 60, 1) == 3, "more strokes go below")
	_check(profile.record_isles(4000, 50, 1) == 2, "on the same strokes, fewer falls win")
	_check(profile.record_isles(4000, 50, 3) == 4, "an exact tie goes below the earlier one")
	_check(profile.best_isles_strokes(4000) == 40, "the best is the fewest strokes")
	_check(profile.isles_table(1000).is_empty() and profile.isles_table(2000).is_empty(), "each length has its own table")
	_check(profile.record_isles(1000, 12, 0) == 1, "so a short course isn't ranked against a long one")
	_check(profile.best_isles_strokes(1000) == 12 and profile.best_isles_strokes(4000) == 40, "and each keeps its own best")
	_check(profile.high_scores.is_empty() and profile.infinite_scores.is_empty(), "it's a table of its own")
	for i in 12:
		profile.record_isles(4000, 70 + i, 0)
	_check(profile.isles_table(4000).size() == Profile.MAX_SCORES, "the table holds ten")
	_check(profile.record_isles(4000, 500, 0) == 0, "a score too poor doesn't make it")
	var reloaded := Profile.new(path)
	_check(reloaded.isles_table(4000) == profile.isles_table(4000), "the leaderboard is saved")
	_check(reloaded.isles_table(1000) == profile.isles_table(1000), "for every length")
	# A save from when there was only the 4000 yard course.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"isles_scores": [{"strokes": "x"}, 7, {"strokes": 90, "falls": "y"}, {"strokes": 30}]}')
	file.close()
	var damaged := Profile.new(path)
	_check(damaged.isles_table(4000).size() == 2 and damaged.best_isles_strokes(4000) == 30, "an old leaderboard moves to the 4000 yard table, keeping what it can")
	_check(int(damaged.isles_table(4000)[1]["falls"]) == 0, "and cleans up the rest")
	_check(damaged.isles_table(2000).is_empty(), "leaving the others empty")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"isles_scores": {"1000": "oops", "2000": [{"strokes": 25, "falls": 1}], "777": [{"strokes": 1}]}}')
	file.close()
	var mixed := Profile.new(path)
	_check(mixed.isles_table(1000).is_empty() and mixed.best_isles_strokes(2000) == 25, "a damaged table doesn't harm its neighbours")
	_check(not mixed.isles_scores.has(777), "and a length that doesn't exist is ignored")
	DirAccess.remove_absolute(path)


func _test_landing_arrow_perk() -> void:
	var arrow: Dictionary = Items.by_id("landing_arrow")
	_check(arrow["kind"] == Items.KIND_PERK and not arrow.has("unlock"), "the Landing Arrow is a perk on sale from the start")
	var state: RunState = _new_run_state()
	_check(state.price_of(arrow) == 60, "it costs 60 in the first shop (%d)" % state.price_of(arrow))
	state.course.hole_index = state.course.hole_count() - 2
	_check(state.price_of(arrow) == 60, "and still 60 in the last")
	state.course.hole_index = 0
	_check(state.price_of(Items.by_id("power_stripe")) == RunState.START_PRICE, "other items keep their low early prices")
	state.perks.append("coupon")
	_check(state.price_of(arrow) == 48, "the Coupon Book still takes its share off")
	state.perks.clear()
	state.level = 5
	_check(state.price_of(arrow) == roundi(60.0 * Difficulty.price_scale(5)), "and infinite difficulty still adds to it")
	state.level = 0
	state.coins = 59
	_check(not state.buy(arrow), "59 coins won't buy it")
	state.coins = 60
	_check(state.buy(arrow) and state.coins == 0, "60 will")
	_check(state.perks.has("landing_arrow") and state.perk_number("landing_arrow", 0.0) > 0.0, "and the run has the perk")
	var sold_out := false
	for _i in 60:
		for item: Dictionary in state.roll_stock():
			sold_out = sold_out or item["id"] == "landing_arrow"
	_check(not sold_out, "it isn't sold again once owned")
	var fresh: RunState = _new_run_state()
	var seen := false
	for _i in 200:
		for item: Dictionary in fresh.roll_stock():
			seen = seen or item["id"] == "landing_arrow"
	_check(seen, "the shop does stock it")


func _test_infinite_mode() -> void:
	_test_landing_arrow_perk()
	# Level 0 has to leave the main game exactly as it was.
	_check(is_equal_approx(Difficulty.price_scale(0), 1.0), "level 0 doesn't change prices")
	_check(is_equal_approx(Difficulty.rival_miss_chance(0), Rival.MISS_CHANCE), "level 0 is the usual rival")
	_check(Difficulty.rival_cheats(0) == Rival.CHEATS_PER_HOLE, "level 0 cheats the usual amount")
	_check(Difficulty.rival_power_steps(0) == Rival.POWER_STEPS, "level 0 plans the usual way")
	for level in Difficulty.MAX_LEVEL:
		_check(Difficulty.price_scale(level + 1) > Difficulty.price_scale(level), "prices rise at level %d" % level)
		_check(Difficulty.rival_miss_chance(level + 1) < Difficulty.rival_miss_chance(level), "the rival improves at level %d" % level)
		_check(Difficulty.rival_miss_chance(level + 1) > 0.0, "the rival can always still mishit")
		_check(Difficulty.boss_reward(level + 1) <= Difficulty.boss_reward(level), "rewards don't grow at level %d" % level)
		_check(Difficulty.boss_reward(level + 1) >= 1, "beating a boss always pays something")
		_check(Difficulty.green_half(level + 1) >= 60.0, "greens stay big enough at level %d" % level)

	# Every generated hole is a proper hole, at every level, whatever the dice say.
	var kinds_by_level: Dictionary = {}
	for level in Difficulty.MAX_LEVEL + 1:
		for seed_value in 12:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value * 100 + level
			var holes: Array[HoleData] = HoleGenerator.generate_set(rng, level)
			_check(holes.size() == HoleGenerator.HOLES_PER_SET + 1, "a set is nine holes and a boss")
			_check(holes[-1].display_name == "BOSS HOLE" and holes[-1].par == HoleGenerator.BOSS_PAR, "a set ends on a boss hole")
			var par_total: int = 0
			for i in holes.size():
				par_total += holes[i].par
				_check_generated_hole(holes[i], level, i, kinds_by_level)
			_check(par_total >= 43 and par_total <= 48, "a set has a sensible par (%d)" % par_total)
			var boss: HoleData = holes[-1]
			var boss_end: float = absf(boss.cup_x - boss.tee_x) - Difficulty.green_half(level)
			for entry: Dictionary in boss.obstacles:
				if entry["kind"] != "coin" and entry.has("x"):
					_check(absf(float(entry["x"]) - boss.tee_x) < boss_end, "the boss hole's hazards stay short of the green (level %d seed %d)" % [level, seed_value])
			var boss_kinds: Dictionary = {}
			for entry: Dictionary in holes[-1].obstacles:
				boss_kinds[entry["kind"]] = true
			for kind: String in ["cart", "goose", "windmill", "sprinkler"]:
				_check(boss_kinds.has(kind), "the boss hole has a %s (level %d seed %d)" % [kind, level, seed_value])
	_check(_first_hole_hazards(kinds_by_level, 0) == [], "the first holes at level 0 have no moving hazards")

	# They're unlike the main course: both directions, new pars, floating pads, varied shapes.
	var variety_rng := RandomNumberGenerator.new()
	variety_rng.seed = 99
	var reversed_holes: int = 0
	var forward_holes: int = 0
	var long_holes: int = 0
	var floating_pads: int = 0
	var titles: Dictionary = {}
	var wettest: float = 0.0
	var biggest_rise: float = 0.0
	for _i in 12:
		for hole: HoleData in HoleGenerator.generate_set(variety_rng, 4):
			if hole.cup_x < hole.tee_x:
				reversed_holes += 1
			else:
				forward_holes += 1
			if hole.par == 6:
				long_holes += 1
			titles[hole.title] = true
			var low: float = INF
			var high: float = -INF
			for point in hole.points:
				low = minf(low, point.y)
				high = maxf(high, point.y)
			biggest_rise = maxf(biggest_rise, high - low)
			var water: float = 0.0
			for span: Dictionary in hole.water_spans:
				water += float(span["to"]) - float(span["from"])
			wettest = maxf(wettest, water / float(hole.points[hole.points.size() - 1].x))
			for entry: Dictionary in hole.obstacles:
				if entry["kind"] == "pad" and entry.has("y"):
					floating_pads += 1
	_check(reversed_holes > 15 and forward_holes > 15, "holes play both ways (%d, %d)" % [reversed_holes, forward_holes])
	_check(long_holes > 3, "some holes are par 6, which the main course has none of")
	_check(floating_pads > 3, "some pads float")
	_check(titles.size() > 60, "titles vary (%d)" % titles.size())
	_check(wettest > 0.2, "some holes are a good part water (%.2f)" % wettest)
	_check(biggest_rise > 130.0, "some holes have big changes in height (%.0f)" % biggest_rise)

	# A hole flipped end for end plays the same.
	var flip_rng := RandomNumberGenerator.new()
	flip_rng.seed = 12
	var plain: HoleData = HoleGenerator.generate_hole(flip_rng, 3, 2, 4, false, "valley")
	var plain_length: float = plain.points[plain.points.size() - 1].x
	var flipped: HoleData = plain.duplicate(true)
	HoleGenerator._mirror(flipped)
	var plain_terrain := Terrain.new(plain)
	var flipped_terrain := Terrain.new(flipped)
	for x in range(40, int(plain_length) - 40, 37):
		_check(absf(plain_terrain.ground_y(float(x)) - flipped_terrain.ground_y(plain_length - float(x))) < 6.0, "flipped ground matches at %d" % x)
	_check(flipped_terrain.surface_at(flipped.tee_x) == Surface.Type.TEE, "a flipped hole still tees off from a tee")
	_check(flipped_terrain.surface_at(flipped.cup_x) == Surface.Type.GREEN, "and has its cup on a green")
	_check(is_equal_approx(flipped.wind, -plain.wind), "with its wind turned round")

	# The same seed makes the same holes, and different seeds don't.
	var one := RandomNumberGenerator.new()
	one.seed = 5
	var two := RandomNumberGenerator.new()
	two.seed = 5
	var three := RandomNumberGenerator.new()
	three.seed = 6
	var hole_one: HoleData = HoleGenerator.generate_hole(one, 3, 4, 4, false)
	_check(HoleIO.to_dict(hole_one) == HoleIO.to_dict(HoleGenerator.generate_hole(two, 3, 4, 4, false)), "a seed repeats its holes")
	_check(HoleIO.to_dict(hole_one) != HoleIO.to_dict(HoleGenerator.generate_hole(three, 3, 4, 4, false)), "another seed makes different holes")
	# Generated holes survive being read back, the same as a saved map.
	_check(HoleIO.from_dict(HoleIO.to_dict(hole_one)) != null, "a generated hole is a valid map")

	# Beating a boss: rewards, difficulty and carried totals.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var first_set: CourseRun = CourseRun.from_holes(HoleGenerator.generate_set(rng, 0))
	var state := RunState.new(first_set, _clubs(), [], 3)
	state.infinite = true
	state.coins = 77
	state.spare = 4
	state.perks.append("coupon")
	state.stickers["driver"].append("power_stripe")
	first_set.record_score(first_set.current_hole().par - 1)
	var first_price: int = state.price_of(Items.by_id("power_stripe"))
	_check(first_price == maxi(roundi(float(RunState.START_PRICE) * 0.8), 1), "the first shop of a run is cheap")
	var paid: Dictionary = state.beat_boss()
	var pile: int = 4 + Difficulty.boss_reward(0)
	_check(int(paid["banked"]) == pile, "the spare strokes and the boss's reward are banked (%d)" % int(paid["banked"]))
	_check(int(paid["coins"]) == pile / 2, "and pay half as many coins")
	_check(state.coins == 77 + pile / 2, "which go on the coins")
	_check(state.spare == RunState.START_SPARE, "spare strokes go back to the start")
	_check(state.level == 1 and state.set_number == 2 and state.bosses_beaten == 1, "beating the boss raises the difficulty")
	_check(state.perks == ["coupon"] and state.stickers["driver"] == ["power_stripe"], "gear carries over")
	var odd_state := RunState.new(first_set, _clubs(), [], 3)
	odd_state.spare = 3
	_check(int(odd_state.beat_boss()["coins"]) == (3 + Difficulty.boss_reward(0)) / 2, "an odd stroke rounds down")
	var none_left := RunState.new(first_set, _clubs(), [], 3)
	none_left.spare = -2
	_check(int(none_left.beat_boss()["banked"]) == Difficulty.boss_reward(0), "being under never costs coins")
	state.coins = 77
	var second_set: CourseRun = first_set.next_set(HoleGenerator.generate_set(rng, state.level))
	state.course = second_set
	_check(second_set.hole_index == 0 and second_set.scores.is_empty(), "the next set starts at its first hole")
	_check(second_set.total_to_par() == -1 and second_set.finished_holes() == 1, "totals carry over between sets")
	var price: int = state.price_of(Items.by_id("power_stripe"))
	_check(price == roundi(18.0 * 0.8 * Difficulty.price_scale(1)), "later sets charge full price and more (%d)" % price)
	_check(state.hole_payout(0, 4, 4) == RunState.PAYOUT_LATE, "later sets pay the full hole payout")
	var score: Dictionary = state.final_score()
	var saw_bosses: bool = false
	for row: Dictionary in score["rows"]:
		if str(row["label"]).begins_with("BOSSES BEATEN 1"):
			saw_bosses = int(row["points"]) == RunState.SCORE_RIVAL_BEATEN
	_check(saw_bosses, "the final score counts bosses beaten")
	for _i in Difficulty.MAX_LEVEL + 5:
		state.beat_boss()
	_check(state.level == Difficulty.MAX_LEVEL, "difficulty stops at its maximum")
	_check(state.set_number == 2 + Difficulty.MAX_LEVEL + 5, "the sets carry on past it")

	# The profile: its own table, the lock, and unlocks.
	var path: String = "user://test_infinite_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(path)
	_check(not profile.rival_beaten, "infinite mode starts locked")
	var lost_main: RunState = _new_run_state()
	lost_main.ending = RunState.Ending.LOST_TO_RIVAL
	profile.record_run(lost_main)
	_check(not profile.rival_beaten, "losing to the rival doesn't open it")
	var won_main: RunState = _new_run_state()
	won_main.ending = RunState.Ending.BEAT_RIVAL
	profile.record_run(won_main)
	_check(profile.rival_beaten, "beating the rival opens it")
	var unlocked_before: int = profile.unlocked.size()
	var from_boss: Array[String] = profile.record_boss_beaten()
	_check(from_boss.size() == Profile.UNLOCKS_FOR_WINNING, "a boss beaten unlocks two items")
	_check(profile.unlocked.size() == unlocked_before + 2, "and they're saved on the profile")
	var main_scores: int = profile.high_scores.size()
	var infinite_lost: RunState = _new_run_state()
	infinite_lost.infinite = true
	infinite_lost.set_number = 3
	infinite_lost.bosses_beaten = 2
	infinite_lost.ending = RunState.Ending.LOST_TO_RIVAL
	var infinite_result: Dictionary = profile.record_run(infinite_lost)
	_check(int(infinite_result["place"]) == 1 and profile.infinite_scores.size() == 1, "infinite runs have their own table")
	_check(profile.high_scores.size() == main_scores, "and don't crowd the main game's")
	_check((infinite_result["unlocked"] as Array).size() == mini(1, Items.unlock_order().size() - unlocked_before - 2), "losing the final duel unlocks one")
	var reloaded := Profile.new(path)
	_check(reloaded.rival_beaten and reloaded.infinite_scores.size() == 1, "all of it survives a restart")
	_check(int(reloaded.infinite_scores[0]["sets"]) == 3 and int(reloaded.infinite_scores[0]["bosses"]) == 2, "with how far the run got")
	# Saves from before infinite mode existed.
	var old_save := FileAccess.open(path, FileAccess.WRITE)
	old_save.store_string(JSON.stringify({ "high_scores": [{ "score": 900, "ending": RunState.Ending.BEAT_RIVAL, "to_par": 0 }], "unlocked": [], "runs_finished": 1 }))
	old_save.close()
	var from_old: Profile = Profile.new(path)
	_check(from_old.rival_beaten, "an old save that beat the rival has infinite mode open")
	_check(from_old.infinite_scores.is_empty(), "with an empty table")
	var bad_save := FileAccess.open(path, FileAccess.WRITE)
	bad_save.store_string(JSON.stringify({ "infinite_scores": ["oops", { "score": "x", "sets": "y" }], "rival_beaten": "maybe" }))
	bad_save.close()
	var damaged: Profile = Profile.new(path)
	_check(damaged.infinite_scores.size() == 1 and int(damaged.infinite_scores[0]["sets"]) == 1, "damaged infinite scores are cleaned up")
	_check(not damaged.rival_beaten, "and a damaged lock stays shut")
	DirAccess.remove_absolute(path)

	# A sample actually played, since a hole can look right and still be impossible. The
	# generator_check scene does this properly at every difficulty.
	var play_rng := RandomNumberGenerator.new()
	play_rng.seed = 21
	var sample: Array[HoleData] = HoleGenerator.generate_set(play_rng, 5)
	for i: int in [0, 4, sample.size() - 1]:
		_check(_play_round(sample[i], play_rng, 0.0, 0.0) > 0, "generated %s can be finished" % sample[i].display_name)


func _first_hole_hazards(kinds_by_level: Dictionary, level: int) -> Array:
	var found: Array = kinds_by_level.get("%d_0" % level, {}).keys()
	var moving: Array = []
	for kind: String in found:
		if kind == "cart" or kind == "windmill" or kind == "sprinkler" or kind == "goose":
			moving.append(kind)
	return moving


func _check_generated_hole(hole: HoleData, level: int, index: int, kinds_by_level: Dictionary) -> void:
	var label: String = "%s %s (level %d, cup %d)" % [hole.display_name, hole.title, level, int(hole.cup_x)]
	var terrain := Terrain.new(hole)
	_check(hole.title != "", "%s has a title" % label)
	_check(hole.par >= 3 and hole.par <= 7, "%s has a sensible par" % label)
	_check(terrain.surface_at(hole.tee_x) == Surface.Type.TEE, "%s tees off from a tee" % label)
	_check(terrain.surface_at(hole.cup_x) == Surface.Type.GREEN, "%s has its cup on a green" % label)
	_check(terrain.surface_at(hole.cup_x - 30.0) == Surface.Type.GREEN, "%s has green before the cup" % label)
	_check(absf(terrain.slope(hole.cup_x - 20.0)) < 0.28, "%s has a green that can hold a ball" % label)
	_check(not hole.scenery.is_empty(), "%s has trees" % label)
	for i in range(1, hole.points.size()):
		_check(hole.points[i].x >= hole.points[i - 1].x + HoleIO.MIN_POINT_GAP, "%s has its ground points in order" % label)
	for piece: Dictionary in hole.scenery:
		_check(absf(float(piece["x"]) - hole.tee_x) > 45.0, "%s has no tree on the tee" % label)
		_check(absf(float(piece["x"]) - hole.cup_x) > 60.0, "%s has no tree on the pin" % label)
	for span: Dictionary in hole.water_spans:
		if hole.par != 3:
			var nearest: float = minf(absf(float(span["from"]) - hole.tee_x), absf(float(span["to"]) - hole.tee_x))
			_check(nearest >= HoleGenerator.POND_EARLIEST - HoleGenerator.TEE_X - 12.0, "%s leaves room for a drive before its pond (%d)" % [label, int(nearest)])
	for offset: float in [-50.0, -25.0, 0.0, 25.0, 50.0]:
		_check(terrain.surface_at(hole.cup_x + offset) == Surface.Type.GREEN, "%s has no water or sand on its green" % label)
	for x in range(0, terrain.length, 8):
		var y: float = terrain.ground_y(float(x))
		_check(y > 60.0 and y < float(Terrain.WORLD_HEIGHT) - 20.0, "%s keeps its ground in the world (%d at %d)" % [label, int(y), x])
	var coins: int = 0
	var seen: Dictionary = kinds_by_level.get("%d_%d" % [level, index], {})
	for obstacle in Obstacle.build_all(hole, terrain):
		seen[obstacle.kind] = true
		if obstacle is BouncePadObstacle:
			var pad: BouncePadObstacle = obstacle
			var sim := BallSim.new(terrain)
			sim.obstacles = Obstacle.build_all(hole, terrain)
			sim.wind = hole.wind
			sim.ignore_moving = true
			_start_ball(sim, pad.center + pad.normal * 12.0, -pad.normal * 120.0)
			_run_to_stop(sim)
			_check(sim.state != BallSim.State.IN_WATER, "%s pad at %d doesn't fire into water" % [label, int(pad.x)])
		elif obstacle is CoinObstacle:
			coins += 1
	kinds_by_level["%d_%d" % [level, index]] = seen
	_check(coins == HoleGenerator.COINS_PER_HOLE, "%s has its coins" % label)
	for entry: Dictionary in hole.obstacles:
		if entry["kind"] == "coin":
			_check(float(entry["y"]) < terrain.ground_y(float(entry["x"])), "%s has its coins above ground" % label)
		elif entry.has("x"):
			_check(terrain.surface_at(float(entry["x"])) != Surface.Type.WATER, "%s has nothing standing in water" % label)
			_check(absf(float(entry["x"]) - hole.tee_x) > 40.0, "%s has nothing on the tee" % label)
			_check(absf(float(entry["x"]) - hole.cup_x) > 60.0, "%s has nothing on the pin" % label)


func _test_maps_gain_coins() -> void:
	var dir: String = "user://test_coin_maps"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, file_name])
	var library := MapLibrary.new(dir)
	var original_coins: int = _count_coins(library.load_original("hole_01"))
	_check(original_coins > 0, "the original has coins")

	# A map saved before coins existed: no version marker, and no coins.
	var old_data: Dictionary = HoleIO.to_dict(library.load_original("hole_01"))
	old_data.erase(HoleIO.COIN_VERSION_KEY)
	var kept: Array = []
	for entry: Dictionary in old_data["obstacles"]:
		if str(entry["kind"]) != "coin":
			kept.append(entry)
	old_data["obstacles"] = kept
	var file := FileAccess.open("%s/hole_01.json" % dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	var migrated: HoleData = library.load_hole("hole_01")
	_check(_count_coins(migrated) == original_coins, "an old edited map gains the original's coins")

	# Once saved it keeps exactly what the player left, even no coins at all.
	var none: Array = []
	for entry: Dictionary in migrated.obstacles:
		if str(entry["kind"]) != "coin":
			none.append(entry)
	migrated.obstacles = none
	library.save_hole("hole_01", migrated)
	_check(_count_coins(library.load_hole("hole_01")) == 0, "coins removed in the editor stay removed")

	# Coins are in the editor like any other object.
	var doc := EditorDoc.new(HoleIO.blank_hole("COINS"))
	var selection: Dictionary = doc.add_object("coin", Vector2(400, 120))
	var coin: Dictionary = doc.entry_of(selection)
	_check(str(coin["kind"]) == "coin" and float(coin["y"]) == 120.0, "a coin can be placed anywhere")
	_check(doc.pick(Vector2(402, 121), 4.0) == selection, "a placed coin can be clicked")
	doc.move_selection(selection, Vector2(500, 90))
	_check(float(doc.entry_of(selection)["x"]) == 500.0 and float(doc.entry_of(selection)["y"]) == 90.0, "a coin can be moved")
	var round_trip: HoleData = HoleIO.from_dict(JSON.parse_string(JSON.stringify(HoleIO.to_dict(doc.hole))))
	_check(_count_coins(round_trip) == 1, "a coin survives saving")
	var bad: Dictionary = HoleIO.to_dict(doc.hole)
	bad["obstacles"] = [{ "kind": "coin", "x": 10.0 }, { "kind": "coin", "y": 10.0 }]
	_check(_count_coins(HoleIO.from_dict(bad)) == 0, "a coin missing its position is dropped")
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, file_name])


func _count_coins(hole: HoleData) -> int:
	var count: int = 0
	for entry: Dictionary in hole.obstacles:
		if str(entry["kind"]) == "coin":
			count += 1
	return count


func _duel_game(cup_x: float = 990.0) -> HoleGame:
	var game := HoleGame.new(_flat_hole({ "cup_x": cup_x }), _clubs())
	game.start_duel(Rival.new(game, _clubs(), 3))
	return game


func _test_duel_rules() -> void:
	# Settling is checked directly, for every case in the rule.
	var cases: Array = [
		# Your strokes, you holed, its strokes, it holed, decided, you won.
		[4, true, 5, true, true, true, "fewer strokes wins"],
		[5, true, 4, true, true, false, "more strokes loses"],
		[4, true, 4, true, true, false, "a tie goes to the rival"],
		[4, true, 4, false, true, true, "the rival can't catch you once it's used your score"],
		[4, true, 3, false, false, false, "the rival still has a stroke to tie"],
		[3, false, 5, true, false, false, "you can still beat it with a stroke to spare"],
		[4, false, 5, true, true, false, "you can only tie it, so it's over"],
		[3, false, 3, false, false, false, "nobody's done yet"],
	]
	for case: Array in cases:
		var game: HoleGame = _duel_game()
		game.strokes = int(case[0])
		game.player_holed = bool(case[1])
		game.rival.strokes = int(case[2])
		game.rival.holed = bool(case[3])
		var decided: bool = game._settle_duel()
		_check(decided == bool(case[4]), "duel: %s (decided)" % str(case[6]))
		if decided:
			_check(game.duel_won == bool(case[5]), "duel: %s (winner)" % str(case[6]))
			_check(game.phase == HoleGame.Phase.COMPLETE, "duel: %s (hole ends)" % str(case[6]))
		game.end_duel()

	# Turns alternate, on a hole too long for the rival to hole out in one.
	var long_hole: HoleData = _flat_hole({ "cup_x": 2900.0 })
	long_hole.points = PackedVector2Array([Vector2(0, 300), Vector2(1500, 300), Vector2(3000, 300)])
	long_hole.surface_spans = [{ "from": 0, "to": 3000, "type": Surface.Type.FAIRWAY }]
	var game := HoleGame.new(long_hole, _clubs())
	game.start_duel(Rival.new(game, _clubs(), 3))
	game.select_club(1)
	game.strike_with(0.3, 0.0)
	var steps: int = 0
	while game.phase == HoleGame.Phase.BALL_MOVING and steps < 3000:
		game.tick(DT)
		steps += 1
	_check(game.phase == HoleGame.Phase.RIVAL_TURN, "the rival plays after the player")
	_check(game.active_ball() == game.rival.ball, "the camera watches the rival's ball on its turn")
	game.press_swing()
	_check(game.strokes == 1, "the player can't swing on the rival's turn")
	steps = 0
	while game.phase == HoleGame.Phase.RIVAL_TURN and steps < 6000:
		game.tick(DT)
		steps += 1
	_check(game.phase == HoleGame.Phase.AIM, "the player plays after the rival")
	_check(game.rival.strokes == 1, "the rival took a stroke")
	_check(game.rival.ball.pos.x > game.hole.tee_x + 20.0, "the rival's ball moved up the hole")
	_check(game.active_ball() == game.ball, "the camera comes back for the player's turn")
	game.end_duel()

	# Holing out hands over to the rival, which plays out alone until it's settled.
	var finisher: HoleGame = _duel_game()
	var wins: Array[bool] = []
	finisher.hole_finished.connect(func(_strokes: int, _name: String) -> void: wins.append(true))
	finisher.strokes = 1
	finisher.ball.state = BallSim.State.HOLED
	finisher._on_ball_holed()
	_check(finisher.player_holed and finisher.phase == HoleGame.Phase.RIVAL_TURN, "holing out leaves the rival to play")
	steps = 0
	while finisher.phase == HoleGame.Phase.RIVAL_TURN and steps < 20000:
		finisher.tick(DT)
		steps += 1
	_check(finisher.phase == HoleGame.Phase.COMPLETE and wins.size() == 1, "the duel settles itself")
	finisher.end_duel()

	# The budget still rules on the boss hole.
	var broke: HoleGame = _duel_game()
	broke.stroke_limit = 1
	var ran_out: Array[bool] = []
	broke.out_of_strokes.connect(func() -> void: ran_out.append(true))
	broke.select_club(1)
	broke.strike_with(0.3, 0.0)
	steps = 0
	while broke.phase == HoleGame.Phase.BALL_MOVING and steps < 3000:
		broke.tick(DT)
		steps += 1
	_check(ran_out.size() == 1, "running out on the boss hole ends the run")
	broke.end_duel()


func _test_rival_cheats() -> void:
	var game: HoleGame = _duel_game()
	var rival: Rival = game.rival
	var said: Array[String] = []
	rival.announced.connect(func(text: String) -> void: said.append(text))
	# Each trick is checked here, whatever the limit on a real hole.
	rival._cheats_left = 99

	var plain_wind: float = game.current_wind()
	rival._tricks_left.assign(["gust"])
	_check(rival._pull_trick(), "the rival can fan the wind")
	_check(game.current_wind() < plain_wind, "the gust blows against the player")
	_check(game.ball.wind == game.current_wind(), "the gust reaches the ball")
	var shot_x: float = _landing_after_shot(game)
	_check(shot_x > 0.0 and is_equal_approx(game.current_wind(), plain_wind), "the gust is gone after one shot")

	game.set_meter_cheat(Rival.GREASE_SPEED)
	game._begin_aim()
	_check(game.meter.time_scale == Rival.GREASE_SPEED, "grease speeds up the player's meter")
	game.strokes = 0
	var greased_x: float = _landing_after_shot(game)
	_check(greased_x > 0.0, "a greased shot still plays")
	game._begin_aim()
	_check(game.meter.time_scale == 1.0, "the grease wears off after one shot")

	rival.strokes = 1
	rival._tricks_left.assign(["pencil"])
	_check(not rival._pull_trick(), "it won't erase its only stroke")
	rival.strokes = 3
	rival._tricks_left.assign(["pencil"])
	_check(rival._pull_trick() and rival.strokes == 2, "the rival can erase a stroke")

	rival.ball.place(300.0)
	var before: float = rival.ball.pos.x
	rival._tricks_left.assign(["kick"])
	_check(rival._pull_trick() and rival.ball.pos.x > before and rival.ball.pos.x < game.hole.cup_x, "a kick moves it toward the cup")
	rival.ball.place(game.hole.cup_x - 20.0)
	rival._tricks_left.assign(["kick"])
	_check(not rival._pull_trick(), "it won't kick when it's already by the cup")

	# Never into water, and never past the cup.
	var wet: HoleData = _flat_hole({ "cup_x": 990.0 })
	wet.points = PackedVector2Array([Vector2(0, 300), Vector2(400, 300), Vector2(420, 330), Vector2(800, 330), Vector2(820, 300), Vector2(1000, 300)])
	wet.water_spans = [{ "from": 405, "to": 815, "level": 306.0 }]
	var wet_game := HoleGame.new(wet, _clubs())
	wet_game.start_duel(Rival.new(wet_game, _clubs(), 3))
	wet_game.rival.ball.place(380.0)
	_check(not wet_game.rival._kick_ball(), "it won't kick into water")
	wet_game.end_duel()

	_check(said.size() >= 3, "every trick is announced")

	# The free drop works once.
	var drop: HoleGame = _duel_game()
	drop.rival.strokes = 2
	drop.rival._on_ball_hazard(Vector2.ZERO, "water")
	_check(drop.rival.strokes == 2, "the first water ball is a free drop")
	drop.rival._on_ball_hazard(Vector2.ZERO, "water")
	_check(drop.rival.strokes == 3, "after that it takes a penalty like anyone")
	drop.end_duel()

	# Cheats come every other turn, and run out.
	var turns: HoleGame = _duel_game()
	var tally: Array[String] = []
	turns.rival.announced.connect(func(text: String) -> void: tally.append(text))
	turns.rival.strokes = 4
	turns.rival.ball.place(300.0)
	turns.rival._turns = 1
	turns.rival._end_shot()
	_check(tally.is_empty() and turns.rival.is_turn_over(), "no cheat on an odd turn")
	turns.rival._turns = 2
	turns.rival._end_shot()
	_check(tally.size() == 1 and turns.rival.stage == Rival.Stage.CHEATING, "a cheat on an even turn")
	turns.rival._end_shot()
	_check(tally.size() == 2, "a second cheat")
	turns.rival._end_shot()
	_check(tally.size() == 2 and turns.rival.is_turn_over(), "and never a third on the same hole")
	turns.end_duel()

	# A free drop is one of the two.
	var mixed: HoleGame = _duel_game()
	mixed.rival._cheats_left = 1
	mixed.rival.strokes = 2
	mixed.rival._on_ball_hazard(Vector2.ZERO, "water")
	_check(mixed.rival.strokes == 2 and mixed.rival._cheats_left == 0, "a free drop uses up a cheat")
	_check(not mixed.rival._pull_trick(), "so it has none left for a trick")
	mixed.end_duel()
	var spent: HoleGame = _duel_game()
	spent.rival._cheats_left = 0
	spent.rival.strokes = 2
	spent.rival._on_ball_hazard(Vector2.ZERO, "water")
	_check(spent.rival.strokes == 3, "with no cheats left, water costs it a penalty")
	spent.end_duel()

	# Hazards hit its ball just like the player's, though its plans can't see them coming.
	var blocked_hole: HoleData = _flat_hole({ "cup_x": 990.0 })
	blocked_hole.obstacles = [{ "kind": "windmill", "x": 400.0, "turn_speed": 0.0 }]
	var blocked := HoleGame.new(blocked_hole, _clubs())
	blocked.start_duel(Rival.new(blocked, _clubs(), 3))
	_check(not blocked.rival.ball.ignore_moving, "moving hazards hit the rival's ball")
	_check(blocked.rival._new_sim().ignore_moving, "its plans ignore them, like the player's preview")
	var player_sim: BallSim = blocked.ball
	player_sim.pos = Vector2(380.0, 270.0)
	player_sim.launch(Vector2(200.0, -1.0), 0.0)
	var rival_sim: BallSim = blocked.rival.ball
	rival_sim.pos = Vector2(380.0, 270.0)
	rival_sim.launch(Vector2(200.0, -1.0), 0.0)
	for _i in 10:
		player_sim.step(DT)
		rival_sim.step(DT)
	_check(rival_sim.vel.is_equal_approx(player_sim.vel), "a blade knocks its ball the same as the player's")
	_check(rival_sim.vel.x < 0.0, "and really does knock it back")
	blocked.end_duel()
	game.end_duel()


func _landing_after_shot(game: HoleGame) -> float:
	game.rival.holed = true
	game.select_club(1)
	game.strike_with(0.3, 0.0)
	var steps: int = 0
	while game.phase == HoleGame.Phase.BALL_MOVING and steps < 3000:
		game.tick(DT)
		steps += 1
	game.rival.holed = false
	return game.ball.pos.x


# Plays the rival alone on the real boss hole, many times, for how good it really is.
func _test_rival_plays_fairly_well() -> void:
	var boss: HoleData = load("res://data/holes/hole_boss.tres")
	var total: int = 0
	var worst: int = 0
	var best: int = 99
	var rounds: int = 16
	var unfinished: int = 0
	var slowest: int = 0
	for round_index in rounds:
		var game := HoleGame.new(boss, _clubs())
		game.start_duel(Rival.new(game, _clubs(), round_index))
		game.strokes = 99
		game.player_holed = true
		game._start_rival_turn()
		var steps: int = 0
		while game.phase == HoleGame.Phase.RIVAL_TURN and not game.rival.holed and steps < 120000:
			var started: int = Time.get_ticks_usec()
			game.tick(DT)
			slowest = maxi(slowest, Time.get_ticks_usec() - started)
			steps += 1
		if not game.rival.holed:
			unfinished += 1
		total += game.rival.strokes
		worst = maxi(worst, game.rival.strokes)
		best = mini(best, game.rival.strokes)
		game.end_duel()
	var average: float = float(total) / float(rounds)
	print("rival on the boss hole: average %.1f, best %d, worst %d, unfinished %d, slowest frame %d ms" % [average, best, worst, unfinished, slowest / 1000])
	_check(unfinished == 0, "the rival always finishes")
	_check(average > 4.5 and average < 12.0, "the rival is a real but beatable opponent (%.1f)" % average)


# Simulated players through whole runs, for how long the budget lasts and what coins buy.
func _test_run_balance() -> void:
	for skill: Array in [["steady", 0.04, 0.02], ["average", 0.08, 0.04], ["sloppy", 0.14, 0.08]]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var runs: int = 3
		var reached_boss: int = 0
		var coin_total: int = 0
		var spare_total: int = 0
		for _run in runs:
			var state: RunState = _new_run_state()
			var alive: bool = true
			for i in state.course.hole_count() - 1:
				var strokes: int = _play_round(state.course.current_hole(), rng, float(skill[1]), float(skill[2]))
				var par: int = state.course.current_hole().par
				if strokes < 0 or strokes >= par + state.spare:
					alive = false
					break
				state.finish_hole(strokes)
				state.course.advance()
			if alive:
				reached_boss += 1
				spare_total += state.spare
			coin_total += state.coins
		print("%s player: reached the boss in %d of %d runs, %.0f coins a run from scores alone, %.1f spare on arrival" % [
				skill[0], reached_boss, runs, float(coin_total) / float(runs), float(spare_total) / float(maxi(reached_boss, 1))])


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
	_check(CourseRun.to_par_text(run.total_to_par()) == "0", "even par shows 0")
	_check(CourseRun.to_par_text(-2) == "-2", "under par shows a minus")

	while not run.is_last_hole():
		run.advance()
	_check(run.current_hole().display_name == "BOSS HOLE", "progress reaches the boss hole")
	run.advance()
	_check(run.hole_index == 0 and run.scores.is_empty(), "finishing the boss hole starts a new round")

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
func _play_round(hole: HoleData, rng: RandomNumberGenerator, power_noise: float, timing_noise: float, patient: bool = false) -> int:
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
			# As a person would, waits a moment for a moving hazard to get out of the way.
			if patient:
				for _wait in rng.randi_range(30, 240):
					game.tick(DT)
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
func _best_power(game: HoleGame, playing_away: bool = false) -> float:
	var best: Dictionary = { "club": game.club_index, "angle": game.aim_angle, "power": 1.0 }
	var best_distance: float = INF
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
	# Nothing safe this way, so flip and play back.
	if best_distance == INF and not playing_away:
		game.flip_facing()
		return _best_power(game, true)
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
