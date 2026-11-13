extends Node2D
## Runs the course, or one map being tested from the editor: creates each hole's rules
## object, then attaches the views to it.

## The player asked to leave. Only used when embedded.
signal exit_requested

const CLUB_PATHS := [
	"res://data/clubs/driver.tres",
	"res://data/clubs/iron.tres",
	"res://data/clubs/putter.tres",
]
const OUT_OF_STROKES_PAUSE := 2.0
const HIT_STOP_FULL := 0.09
const HIT_STOP_PERFECT := 0.05
const FULL_POWER_SHAKE := 3.0
const HAZARD_SHAKE := 1.5
const ISLES_FINISH_PAUSE := 1.6

var run: CourseRun
var game: HoleGame
var camera: FollowCamera
var hud: Hud
var fx: FxView

## True when something else manages this screen, so Esc asks to leave instead of quitting.
var embedded: bool = false
## Where the course's maps come from. Uses the player's own if not set.
var library: MapLibrary
## High scores and unlocks. Uses the player's own if not set.
var profile: Profile
## True for infinite mode: generated holes, set after set, until the run ends.
var infinite: bool = false
## Makes an infinite run repeatable, for tests. A negative seed means a different run each time.
var infinite_seed: int = -1
## True for Floating Isles: one random hole of islands, with its own leaderboard.
var floating_isles: bool = false
## How long a Floating Isles course to play.
var isles_yards: int = IslesGenerator.DEFAULT_YARDS
## Makes the islands repeatable, for tests. A negative seed means a new map each time.
var isles_seed: int = -1
## The run in progress. Null when testing a map, which has no budget, coins or shop.
var run_state: RunState
var shop: ShopScreen
var pause_menu: PauseView
var run_over: RunOverScreen
var isles_finish: IslesFinishScreen

var _base_clubs: Array[ClubData] = []
var _world: Node2D
var _test_hole: HoleData
var _test_start_x: float = -1.0
## Holds the screens that sit over the course.
var _overlay: CanvasLayer
var _rival_strokes_at_end: int = -1
var _flag: FlagView
var _hit_stop: float = 0.0
var _hole_rng := RandomNumberGenerator.new()
var _isles_place: int = 0
var _next_course: Array[HoleData] = []


## Plays one map instead of the course. A negative start means from the tee.
func setup_test(hole: HoleData, start_x: float) -> void:
	_test_hole = hole
	_test_start_x = start_x


func is_testing() -> bool:
	return _test_hole != null


func _ready() -> void:
	Controls.register()
	for path: String in CLUB_PATHS:
		_base_clubs.append(load(path) as ClubData)
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	if is_testing():
		var only: Array[HoleData] = [_test_hole]
		_test_hole.display_name = "TEST"
		run = CourseRun.from_holes(only)
		load_current_hole()
	else:
		if library == null:
			library = MapLibrary.new()
		if profile == null:
			profile = Profile.new()
		_begin_new_run()


func _begin_new_run() -> void:
	if floating_isles:
		_begin_isles()
		return
	if infinite:
		# The seed goes in the log, so a bad hole can be made again and looked at.
		_hole_rng.seed = infinite_seed if infinite_seed >= 0 else randi()
		print("infinite mode seed: %d" % _hole_rng.seed)
		run = CourseRun.from_holes(HoleGenerator.generate_set(_hole_rng, 0))
	else:
		run = CourseRun.from_holes(library.load_course())
	run_state = RunState.new(run, _base_clubs, profile.unlocked)
	run_state.infinite = infinite
	_rival_strokes_at_end = -1
	load_current_hole()


# A fresh map every time, including after Try Again.
func _begin_isles() -> void:
	_hole_rng.seed = isles_seed if isles_seed >= 0 else randi()
	print("floating isles seed: %d" % _hole_rng.seed)
	var only: Array[HoleData] = [IslesGenerator.generate(_hole_rng, isles_yards)]
	run = CourseRun.from_holes(only)
	load_current_hole()


func _exit_tree() -> void:
	if game != null:
		game.end_duel()


func _is_duel_hole() -> bool:
	return run_state != null and run.is_last_hole() and run.hole_count() > 1


## Replaces everything on screen with the run's current hole.
func load_current_hole() -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
	_world = Node2D.new()
	add_child(_world)
	if game != null:
		game.end_duel()
	if run_state != null:
		run_state.begin_hole()
		game = HoleGame.new(run.current_hole(), run_state.clubs(), run_state.ball_id)
		game.stroke_limit = run_state.stroke_limit(game.hole.par)
		game.free_penalties = int(run_state.perk_number("free_penalties", 0.0))
		if _is_duel_hole():
			game.start_duel(_new_rival())
	else:
		game = HoleGame.new(run.current_hole(), _base_clubs)
		game.falls_return_to_tee = floating_isles
	if is_testing() and _test_start_x >= 0.0:
		game.start_from(_test_start_x)
	_build_views()
	_connect_signals()
	Sound.stop_jingle()
	Sound.music(_course_track())
	Sound.set_outdoors(true, _in_swamp())
	ScreenWipe.open(_overlay)
	if _in_swamp() and run.hole_index == 0 and not is_testing():
		hud.show_message("WELCOME TO SWAMPY SHORES", 2.4)
	hud.show_message("%s: %s" % [game.hole.display_name, game.hole.title], 2.2)
	if game.rival != null:
		hud.show_message("THE RIVAL CHALLENGES YOU!", 2.6)
	if is_testing():
		hud.banner = "TESTING: ESC RETURNS TO THE EDITOR. SCORES DON'T COUNT."


func _in_swamp() -> bool:
	return game.hole.biome == HoleData.BIOME_SWAMP


func _course_track() -> String:
	if floating_isles:
		return "isles"
	if _in_swamp():
		return "swamp_boss" if game.rival != null else "swamp"
	return "boss" if game.rival != null else "grassy"


# The rival plays with plain clubs. In the swamp it plays better, but never cheats more.
func _new_rival() -> Rival:
	var plain_clubs: Array[ClubData] = _base_clubs
	if not _in_swamp():
		return Rival.new(game, plain_clubs, -1, run_state.level)
	var swamp_rival := Rival.new(game, plain_clubs, -1, Difficulty.swamp_rival_level(run_state.level))
	swamp_rival.limit_cheats(Rival.CHEATS_PER_HOLE)
	return swamp_rival


func _build_views() -> void:
	camera = FollowCamera.new()
	camera.setup(game)

	var mood: int = _time_of_day()
	var background := BackgroundView.new()
	background.setup(camera, mood)
	background.above_the_clouds = game.terrain.is_floating()
	_world.add_child(background)
	var tint := CanvasModulate.new()
	tint.color = BackgroundView.tint_of(mood)
	_world.add_child(tint)

	var trees := TreeView.new()
	trees.setup(game.hole, game.terrain)
	_world.add_child(trees)

	var water := WaterView.new()
	water.setup(game.terrain)
	var terrain_view := TerrainView.new()
	terrain_view.setup(game.terrain)
	_world.add_child(terrain_view)
	_world.add_child(water)

	var obstacle_view := ObstacleView.new()
	obstacle_view.setup(game.obstacles, _in_swamp())
	_world.add_child(obstacle_view)

	_flag = FlagView.new()
	_flag.setup(game.terrain)
	_world.add_child(_flag)

	if game.hole.checkpoint_x >= 0.0:
		var checkpoint := CheckpointFlagView.new()
		checkpoint.setup(game.terrain, game.hole.checkpoint_x)
		_world.add_child(checkpoint)

	var golfer := GolferView.new()
	golfer.setup(game)
	if profile != null:
		golfer.wear(profile.model, profile.worn_pieces(profile.model))
	_world.add_child(golfer)

	if game.rival != null:
		var rival_view := RivalView.new()
		rival_view.setup_rival(game, game.rival)
		var rival_ball := BallView.new()
		if _in_swamp():
			rival_view.wear_swamp_colors()
			rival_ball.setup_other(game, game.rival.ball, Color("c4e86a"), Color("86a845"))
		else:
			rival_ball.setup_other(game, game.rival.ball, Color("d9a8ff"), Color("9a6fd0"))
		_world.add_child(rival_view)
		_world.add_child(rival_ball)

	var aim := AimView.new()
	aim.setup(game, run_state != null and run_state.perk_number("landing_arrow", 0.0) > 0.0)
	_world.add_child(aim)

	var ball := BallView.new()
	ball.setup(game)
	_world.add_child(ball)

	fx = FxView.new()
	_world.add_child(fx)

	_world.add_child(camera)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	_world.add_child(hud_layer)
	hud = Hud.new()
	hud.setup(game, camera, run)
	hud.run_state = run_state
	if floating_isles:
		hud.isles_mode = true
		hud.isles_best = profile.best_isles_strokes(isles_yards)
	hud_layer.add_child(hud)

	var audio := GameAudio.new()
	audio.setup(game)
	_world.add_child(audio)


# Testing one map stays at midday, since it has no place in a course.
func _time_of_day() -> int:
	if _in_swamp():
		return BackgroundView.swamp_mood_for(run.hole_index, run.hole_count(), _is_duel_hole())
	if is_testing() or floating_isles:
		return BackgroundView.Mood.MIDDAY
	return BackgroundView.mood_for(run.hole_index, run.hole_count(), _is_duel_hole())


func _connect_signals() -> void:
	game.shot_struck.connect(_on_shot_struck)
	game.penalty_taken.connect(_on_penalty_taken)
	game.hole_finished.connect(_on_hole_finished)
	game.continue_requested.connect(_on_continue_requested)
	game.ball.bounced.connect(_on_ball_bounced)
	game.ball.hazard.connect(_on_ball_hazard)
	game.ball.holed.connect(_on_ball_holed)
	game.ball.pin_hit.connect(_on_pin_hit)
	game.ball.obstacle_hit.connect(_on_obstacle_hit)
	game.coin_collected.connect(_on_coin_collected)
	game.trick_shot.connect(_on_trick_shot)
	game.penalty_forgiven.connect(_on_penalty_forgiven)
	game.out_of_strokes.connect(_on_out_of_strokes)
	game.checkpoint_touched.connect(_on_checkpoint_touched)
	if game.rival != null:
		var rival_ball: BallSim = game.rival.ball
		game.rival.announced.connect(func(text: String) -> void: hud.show_message(text, Rival.CHEAT_TIME))
		rival_ball.bounced.connect(_on_ball_bounced)
		rival_ball.hazard.connect(_on_ball_hazard)
		rival_ball.obstacle_hit.connect(_on_rival_touched)


func _physics_process(delta: float) -> void:
	if _is_interrupted():
		return
	var aim_input: float = Input.get_axis("aim_down", "aim_up")
	if aim_input != 0.0:
		game.adjust_aim(aim_input, delta)
	# A big strike holds the picture for a moment. The whole hole waits, so nothing plays differently.
	if _hit_stop > 0.0:
		_hit_stop -= delta
		return
	game.tick(delta)


# The shop, the pause menu and the final score all stop the course behind them.
func _is_interrupted() -> bool:
	return shop != null or pause_menu != null or run_over != null or isles_finish != null


func _unhandled_input(event: InputEvent) -> void:
	if _is_interrupted():
		_handle_interrupted_input(event)
		return
	if run_state != null and event.is_action_pressed("scorecard", false):
		hud.show_card = not hud.show_card
		Sound.sfx("menu_move")
	elif (run_state != null or floating_isles) and event.is_action_pressed("quit", false):
		# Once the ball's dropped, the finish screen is on its way and has its own way out.
		var waiting_on_finish: bool = floating_isles and game.phase == HoleGame.Phase.COMPLETE
		if game.phase != HoleGame.Phase.OUT_OF_STROKES and not waiting_on_finish:
			_open_pause()
	elif Controls.swing_pressed(event):
		game.press_swing()
	elif event.is_action_pressed("club_next", false):
		game.cycle_club(1)
	elif event.is_action_pressed("club_prev", false):
		game.cycle_club(-1)
	elif event.is_action_pressed("club_1", false):
		game.select_club(0)
	elif event.is_action_pressed("club_2", false):
		game.select_club(1)
	elif event.is_action_pressed("club_3", false):
		game.select_club(2)
	elif event.is_action_pressed("spin_up", false):
		game.change_spin(1)
	elif event.is_action_pressed("spin_down", false):
		game.change_spin(-1)
	elif event.is_action_pressed("flip", false):
		game.flip_facing()
	elif is_testing() and event.is_action_pressed("restart", false):
		game.restart()
	elif event.is_action_pressed("quit", false):
		if embedded:
			exit_requested.emit()
		else:
			get_tree().quit()


func _handle_interrupted_input(event: InputEvent) -> void:
	# Esc in the shop opens the pause menu, once the shop has had its turn with it.
	if shop != null and pause_menu == null and event.is_action_pressed("quit", false):
		_open_pause()


func _open_pause() -> void:
	pause_menu = PauseView.new()
	pause_menu.resumed.connect(_close_pause, CONNECT_DEFERRED)
	if floating_isles:
		pause_menu.end_label = "MAIN MENU"
		pause_menu.end_note = "ONLY A FINISHED CROSSING GOES ON THE LEADERBOARD"
		pause_menu.run_ended.connect(_leave_isles, CONNECT_DEFERRED)
	else:
		pause_menu.run_ended.connect(_give_up, CONNECT_DEFERRED)
	if shop != null:
		shop.set_process_unhandled_input(false)
	_overlay.add_child(pause_menu)
	hud.message_hidden = true
	Sound.sfx("menu_ok")


func _close_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
	hud.message_hidden = false
	if shop != null:
		shop.set_process_unhandled_input(true)


func _give_up() -> void:
	_close_pause()
	_close_shop()
	if game.phase != HoleGame.Phase.COMPLETE:
		run_state.leave_hole_unfinished(game.strokes)
	# A duel already won or lost keeps its result.
	if run_state.ending == RunState.Ending.NONE:
		run_state.ending = RunState.Ending.GAVE_UP
	_end_run()


func _leave_isles() -> void:
	_close_pause()
	_close_isles_finish()
	if embedded:
		exit_requested.emit()
	else:
		_begin_isles()


func _try_isles_again() -> void:
	_close_isles_finish()
	_begin_isles()


func _close_isles_finish() -> void:
	if isles_finish != null:
		isles_finish.queue_free()
		isles_finish = null


# The ball's in the hole. The score's already saved, so this only has to say so.
func _open_isles_finish() -> void:
	if isles_finish != null or game.phase != HoleGame.Phase.COMPLETE:
		return
	isles_finish = IslesFinishScreen.new()
	isles_finish.setup(isles_yards, game.strokes, game.falls, _isles_place, profile.best_isles_strokes(isles_yards))
	isles_finish.try_again.connect(_try_isles_again, CONNECT_DEFERRED)
	isles_finish.main_menu.connect(_leave_isles, CONNECT_DEFERRED)
	_overlay.add_child(isles_finish)
	Sound.stop_jingle()


func _open_shop() -> void:
	shop = ShopScreen.new()
	shop.setup(run_state)
	shop.done.connect(_leave_shop, CONNECT_DEFERRED)
	_overlay.add_child(shop)
	Sound.stop_jingle()
	Sound.music("shop")
	Sound.set_outdoors(false)
	ScreenWipe.open(_overlay)


func _close_shop() -> void:
	if shop != null:
		shop.queue_free()
		shop = null


func _leave_shop() -> void:
	_close_shop()
	# A shop after a boss only comes when there's more to play: infinite mode's next set of holes,
	# or Swampy Shores after the main game's first rival.
	if run.is_last_hole():
		if infinite:
			run = run.next_set(HoleGenerator.generate_set(_hole_rng, run_state.level, HoleGenerator.biome_for_set(run_state.set_number)))
		else:
			run = run.next_set(_next_course)
		run_state.course = run
	else:
		run.advance()
	load_current_hole()


func _end_run() -> void:
	if game.rival != null:
		_rival_strokes_at_end = game.rival.strokes
	var result: Dictionary = profile.record_run(run_state)
	run_over = RunOverScreen.new()
	run_over.setup(run_state, result, _rival_strokes_at_end)
	run_over.done.connect(_after_run_over, CONNECT_DEFERRED)
	_overlay.add_child(run_over)
	Sound.music("")
	Sound.set_outdoors(false)
	ScreenWipe.open(_overlay)


func _after_run_over() -> void:
	run_over.queue_free()
	run_over = null
	if embedded:
		exit_requested.emit()
	else:
		_begin_new_run()


func _on_shot_struck(quality: String, _power: float) -> void:
	if quality != "":
		hud.show_message(quality, 1.1)
	fx.dust(game.ball.pos, Color(0.85, 0.95, 0.65), 6, game.facing)
	if quality == "FULL POWER!!":
		_hit_stop = HIT_STOP_FULL
		camera.shake(FULL_POWER_SHAKE)
		fx.burst(game.ball.pos, Color("ffd23c"), 18, 110.0)
		fx.ring(game.ball.pos, Color("ffe25a"), 30.0)
	elif quality == "PERFECT!":
		_hit_stop = HIT_STOP_PERFECT
		fx.burst(game.ball.pos, Color("ffffff"), 12, 80.0)


func _on_penalty_taken(kind: String) -> void:
	var text: String = "OUT OF BOUNDS! +1 STROKE"
	if kind == "water":
		text = "PLOP! +1 STROKE" if _in_swamp() else "SPLASH! +1 STROKE"
	elif kind == "gator":
		text = "CHOMP! +1 STROKE"
	if kind == "fall":
		text = "YOU FELL! BACK TO THE CHECKPOINT" if game.checkpoint_reached else "YOU FELL! BACK TO THE TEE"
	hud.show_message(text, HoleGame.PENALTY_TIME)


func _on_checkpoint_touched() -> void:
	hud.show_message("CHECKPOINT!", 1.8)
	Sound.sfx("mulligan")
	fx.burst(Vector2(game.hole.checkpoint_x, game.terrain.ground_y(game.hole.checkpoint_x) - CheckpointFlagView.POLE_HEIGHT), Color("f7f4e6"), 16, 90.0)


func _on_penalty_forgiven() -> void:
	hud.show_message("MULLIGAN! NO PENALTY", HoleGame.PENALTY_TIME)


func _on_coin_collected(at: Vector2) -> void:
	if run_state != null:
		var before: int = run_state.coins
		run_state.collect_coin()
		fx.float_text(at, "+%d" % (run_state.coins - before), Color("ffe25a"))
	fx.dust(at, Color("ffd23c"), 6, 0)


func _on_trick_shot(trick_name: String, coins: int) -> void:
	if run_state == null:
		return
	var paid: int = run_state.collect_trick(coins)
	if paid > 0:
		hud.show_message("%s +%d COINS" % [trick_name, paid], 1.6)


# Stays on screen a moment, unless a Safety Net catches it.
func _on_out_of_strokes() -> void:
	var saved: int = run_state.use_safety_net()
	if saved > 0:
		hud.show_message("SAFETY NET! +%d STROKES" % saved, 1.8)
		Sound.stop_jingle()
		Sound.sfx("mulligan")
		game.grant_strokes(saved)
		return
	run_state.leave_hole_unfinished(game.strokes)
	run_state.ending = RunState.Ending.OUT_OF_STROKES
	await get_tree().create_timer(OUT_OF_STROKES_PAUSE).timeout
	if run_over == null:
		_end_run()


func _on_hole_finished(strokes: int, _score_name: String) -> void:
	if floating_isles:
		_isles_place = profile.record_isles(isles_yards, strokes, game.falls)
		# A moment for the confetti, unless the player presses on first.
		await get_tree().create_timer(ISLES_FINISH_PAUSE).timeout
		_open_isles_finish()
		return
	if run_state == null:
		run.record_score(strokes)
		return
	if game.ball.state == BallSim.State.HOLED:
		hud.summary = run_state.finish_hole(strokes)
	else:
		run_state.leave_hole_unfinished(strokes)
	if game.rival != null:
		if infinite and game.duel_won:
			_on_boss_beaten()
		elif game.duel_won and run_state.set_number == 1 and _load_next_course():
			_on_first_rival_beaten()
		else:
			run_state.ending = RunState.Ending.BEAT_RIVAL if game.duel_won else RunState.Ending.LOST_TO_RIVAL


# The run carries on. The result panel says what the win was worth.
func _on_boss_beaten() -> void:
	var paid: Dictionary = run_state.beat_boss()
	var new_items: Array[String] = profile.record_boss_beaten()
	hud.result_notes.append("%d SPARE STROKES BANKED: +%d COINS" % [int(paid["banked"]), int(paid["coins"])])
	hud.result_notes.append("SPARE BACK TO %d, DIFFICULTY %d" % [run_state.spare, run_state.level])
	if not new_items.is_empty():
		hud.result_notes.append("NOW IN THE SHOP: %s" % ", ".join(new_items))


# True if there's a second course to go on to.
func _load_next_course() -> bool:
	_next_course = library.load_course(HoleData.BIOME_SWAMP)
	return not _next_course.is_empty()


# Everything carries over as it is, so the panel still shows what the hole did to the spare strokes.
func _on_first_rival_beaten() -> void:
	run_state.beat_first_rival()
	var new_items: Array[String] = profile.record_boss_beaten()
	hud.result_notes.append("+%d POINTS. ONWARD TO SWAMPY SHORES" % RunState.SCORE_RIVAL_BEATEN)
	if not new_items.is_empty():
		hud.result_notes.append("NOW IN THE SHOP: %s" % ", ".join(new_items))


# The press arrives from inside the hole's own rules, so swap holes after it returns.
func _on_continue_requested() -> void:
	if floating_isles:
		_open_isles_finish.call_deferred()
	elif run_state == null:
		run.advance()
		load_current_hole.call_deferred()
	elif run.is_last_hole() and not hud.run_carries_on():
		_end_run.call_deferred()
	else:
		_open_shop.call_deferred()


func _on_ball_bounced(at: Vector2, surface: int, impact_speed: float) -> void:
	if impact_speed < 40.0:
		return
	var color := Color(0.55, 0.8, 0.35)
	if surface == Surface.Type.SAND:
		color = Color(0.93, 0.83, 0.56)
	elif surface == Surface.Type.MUD:
		color = Color(0.33, 0.25, 0.15)
	fx.dust(at + Vector2(0, 2), color, 12 if surface == Surface.Type.SAND or surface == Surface.Type.MUD else 5, 0)


func _on_ball_hazard(at: Vector2, kind: String) -> void:
	if kind == "water":
		fx.splash(at)
		camera.shake(HAZARD_SHAKE)
	elif kind == "gator":
		fx.burst(at, Color("a8d860"), 16, 90.0)
		camera.shake(HAZARD_SHAKE * 1.5)


func _on_pin_hit(at: Vector2) -> void:
	hud.show_message("OFF THE PIN!", 1.1)
	fx.dust(at, Color("f4f4ea"), 6, 0)
	_flag.wobble()


func _on_obstacle_hit(at: Vector2, kind: String) -> void:
	match kind:
		"pad":
			hud.show_message("BOING!", 0.9)
			fx.dust(at, Color("ffe25a"), 10, 0)
			camera.shake(HAZARD_SHAKE)
		"goose":
			hud.show_message("HONK!", 1.1)
			fx.dust(at, Color("f7f4e6"), 12, 0)
			camera.shake(HAZARD_SHAKE)
		"cart":
			hud.show_message("FORE!", 1.1)
			fx.dust(at, Color("e8c34a"), 8, 0)
			camera.shake(HAZARD_SHAKE * 1.5)
		"windmill":
			fx.dust(at, Color("f7f4e6"), 8, 0)
			camera.shake(HAZARD_SHAKE)
		"sprinkler":
			fx.splash(at)
		"frog":
			hud.show_message("RIBBIT!", 1.1)
			fx.dust(at, Color("7fc24e"), 10, 0)
			camera.shake(HAZARD_SHAKE)
		"vent":
			hud.show_message("GASSED!", 1.1)
			fx.dust(at, Color("a8c85a"), 14, 0)
			camera.shake(HAZARD_SHAKE)


func _on_rival_touched(at: Vector2, kind: String) -> void:
	if kind == "pad":
		fx.dust(at, Color("ffe25a"), 10, 0)
	elif kind != "mill_door":
		fx.dust(at, Color("f7f4e6"), 8, 0)


func _on_ball_holed() -> void:
	var at := Vector2(game.hole.cup_x, game.terrain.rim_y - 6.0)
	fx.confetti(at)
	# A hole in one gets the lot.
	if game.strokes == 1:
		fx.confetti(at)
		fx.burst(at, Color("ffe25a"), 24, 130.0)
		camera.shake(FULL_POWER_SHAKE)
