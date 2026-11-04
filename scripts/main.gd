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
## The run in progress. Null when testing a map, which has no budget, coins or shop.
var run_state: RunState
var shop: ShopScreen
var pause_menu: PauseView
var run_over: RunOverScreen

var _base_clubs: Array[ClubData] = []
var _world: Node2D
var _test_hole: HoleData
var _test_start_x: float = -1.0
## Holds the screens that sit over the course.
var _overlay: CanvasLayer
var _rival_strokes_at_end: int = -1


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
	run = CourseRun.from_holes(library.load_course())
	run_state = RunState.new(run, _base_clubs, profile.unlocked)
	_rival_strokes_at_end = -1
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
			var plain_clubs: Array[ClubData] = _base_clubs
			game.start_duel(Rival.new(game, plain_clubs))
	else:
		game = HoleGame.new(run.current_hole(), _base_clubs)
	if is_testing() and _test_start_x >= 0.0:
		game.start_from(_test_start_x)
	_build_views()
	_connect_signals()
	hud.show_message("%s: %s" % [game.hole.display_name, game.hole.title], 2.2)
	if game.rival != null:
		hud.show_message("THE RIVAL CHALLENGES YOU!", 2.6)
	if is_testing():
		hud.banner = "TESTING: ESC RETURNS TO THE EDITOR. SCORES DON'T COUNT."


func _build_views() -> void:
	camera = FollowCamera.new()
	camera.setup(game)

	var background := BackgroundView.new()
	background.setup(camera)
	_world.add_child(background)

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
	obstacle_view.setup(game.obstacles)
	_world.add_child(obstacle_view)

	var flag := FlagView.new()
	flag.setup(game.terrain)
	_world.add_child(flag)

	var golfer := GolferView.new()
	golfer.setup(game)
	_world.add_child(golfer)

	if game.rival != null:
		var rival_view := RivalView.new()
		rival_view.setup_rival(game, game.rival)
		_world.add_child(rival_view)
		var rival_ball := BallView.new()
		rival_ball.setup_other(game, game.rival.ball, Color("d9a8ff"), Color("9a6fd0"))
		_world.add_child(rival_ball)

	var aim := AimView.new()
	aim.setup(game)
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
	hud_layer.add_child(hud)


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
	game.tick(delta)


# The shop, the pause menu and the final score all stop the course behind them.
func _is_interrupted() -> bool:
	return shop != null or pause_menu != null or run_over != null


func _unhandled_input(event: InputEvent) -> void:
	if _is_interrupted():
		_handle_interrupted_input(event)
		return
	if run_state != null and event.is_action_pressed("scorecard", false):
		hud.show_card = not hud.show_card
	elif run_state != null and event.is_action_pressed("quit", false):
		if game.phase != HoleGame.Phase.OUT_OF_STROKES:
			_open_pause()
	elif event.is_action_pressed("swing", false):
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
	elif event.is_action_pressed("review_next_hole", false):
		_review_jump(1)
	elif event.is_action_pressed("review_prev_hole", false):
		_review_jump(-1)
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
	pause_menu.run_ended.connect(_give_up, CONNECT_DEFERRED)
	if shop != null:
		shop.set_process_unhandled_input(false)
	_overlay.add_child(pause_menu)


func _close_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
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


func _open_shop() -> void:
	shop = ShopScreen.new()
	shop.setup(run_state)
	shop.done.connect(_leave_shop, CONNECT_DEFERRED)
	_overlay.add_child(shop)


func _close_shop() -> void:
	if shop != null:
		shop.queue_free()
		shop = null


func _leave_shop() -> void:
	_close_shop()
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


func _after_run_over() -> void:
	run_over.queue_free()
	run_over = null
	if embedded:
		exit_requested.emit()
	else:
		_begin_new_run()


func _review_jump(step: int) -> void:
	run.jump_by(step)
	load_current_hole()


func _on_shot_struck(quality: String, _power: float) -> void:
	if quality != "":
		hud.show_message(quality, 1.1)
	fx.dust(game.ball.pos, Color(0.85, 0.95, 0.65), 6, game.facing)


func _on_penalty_taken(kind: String) -> void:
	var text: String = "SPLASH! +1 STROKE" if kind == "water" else "OUT OF BOUNDS! +1 STROKE"
	hud.show_message(text, HoleGame.PENALTY_TIME)


func _on_penalty_forgiven() -> void:
	hud.show_message("MULLIGAN! NO PENALTY", HoleGame.PENALTY_TIME)


func _on_coin_collected(at: Vector2) -> void:
	if run_state != null:
		run_state.collect_coin()
	fx.dust(at, Color("ffd23c"), 6, 0)


func _on_trick_shot(trick_name: String, coins: int) -> void:
	if run_state != null:
		hud.show_message("%s +%d COINS" % [trick_name, run_state.collect_trick(coins)], 1.6)


# Stays on screen a moment, unless a Safety Net catches it.
func _on_out_of_strokes() -> void:
	var saved: int = run_state.use_safety_net()
	if saved > 0:
		hud.show_message("SAFETY NET! +%d STROKES" % saved, 1.8)
		game.grant_strokes(saved)
		return
	run_state.leave_hole_unfinished(game.strokes)
	run_state.ending = RunState.Ending.OUT_OF_STROKES
	await get_tree().create_timer(OUT_OF_STROKES_PAUSE).timeout
	if run_over == null:
		_end_run()


func _on_hole_finished(strokes: int, _score_name: String) -> void:
	if run_state == null:
		run.record_score(strokes)
		return
	if game.ball.state == BallSim.State.HOLED:
		hud.summary = run_state.finish_hole(strokes)
	else:
		run_state.leave_hole_unfinished(strokes)
	if game.rival != null:
		run_state.ending = RunState.Ending.BEAT_RIVAL if game.duel_won else RunState.Ending.LOST_TO_RIVAL


# The press arrives from inside the hole's own rules, so swap holes after it returns.
func _on_continue_requested() -> void:
	if run_state == null:
		run.advance()
		load_current_hole.call_deferred()
	elif run.is_last_hole():
		_end_run.call_deferred()
	else:
		_open_shop.call_deferred()


func _on_ball_bounced(at: Vector2, surface: int, impact_speed: float) -> void:
	if impact_speed < 40.0:
		return
	var color := Color(0.55, 0.8, 0.35)
	if surface == Surface.Type.SAND:
		color = Color(0.93, 0.83, 0.56)
	fx.dust(at + Vector2(0, 2), color, 5 if surface != Surface.Type.SAND else 12, 0)


func _on_ball_hazard(at: Vector2, kind: String) -> void:
	if kind == "water":
		fx.splash(at)


func _on_pin_hit(at: Vector2) -> void:
	hud.show_message("OFF THE PIN!", 1.1)
	fx.dust(at, Color("f4f4ea"), 6, 0)


func _on_obstacle_hit(at: Vector2, kind: String) -> void:
	match kind:
		"pad":
			hud.show_message("BOING!", 0.9)
			fx.dust(at, Color("ffe25a"), 10, 0)
		"goose":
			hud.show_message("HONK!", 1.1)
			fx.dust(at, Color("f7f4e6"), 12, 0)
		"cart":
			hud.show_message("FORE!", 1.1)
			fx.dust(at, Color("e8c34a"), 8, 0)
		"windmill":
			fx.dust(at, Color("f7f4e6"), 8, 0)
		"sprinkler":
			fx.splash(at)


func _on_rival_touched(at: Vector2, kind: String) -> void:
	if kind == "pad":
		fx.dust(at, Color("ffe25a"), 10, 0)
	elif kind != "mill_door":
		fx.dust(at, Color("f7f4e6"), 8, 0)


func _on_ball_holed() -> void:
	fx.confetti(Vector2(game.hole.cup_x, game.terrain.rim_y - 6.0))
