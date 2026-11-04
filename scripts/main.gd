extends Node2D
## Runs the course: creates each hole's rules object, then attaches the views to it.

const COURSE_PATH := "res://data/course_01.tres"
const CLUB_PATHS := [
	"res://data/clubs/driver.tres",
	"res://data/clubs/iron.tres",
	"res://data/clubs/putter.tres",
]

var run: CourseRun
var game: HoleGame
var camera: FollowCamera
var hud: Hud
var fx: FxView

var _clubs: Array[ClubData] = []
var _world: Node2D


func _ready() -> void:
	Controls.register()
	for path: String in CLUB_PATHS:
		_clubs.append(load(path) as ClubData)
	run = CourseRun.new(load(COURSE_PATH) as CourseData)
	load_current_hole()


## Replaces everything on screen with the run's current hole.
func load_current_hole() -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
	_world = Node2D.new()
	add_child(_world)
	game = HoleGame.new(run.current_hole(), _clubs)
	_build_views()
	_connect_signals()
	hud.show_message("%s: %s" % [game.hole.display_name, game.hole.title], 2.2)


func _build_views() -> void:
	camera = FollowCamera.new()
	camera.setup(game)

	var background := BackgroundView.new()
	background.setup(camera)
	_world.add_child(background)

	var trees := TreeView.new()
	trees.setup(game)
	_world.add_child(trees)

	var water := WaterView.new()
	water.setup(game.terrain)
	var terrain_view := TerrainView.new()
	terrain_view.setup(game.terrain)
	_world.add_child(terrain_view)
	_world.add_child(water)

	var obstacle_view := ObstacleView.new()
	obstacle_view.setup(game)
	_world.add_child(obstacle_view)

	var flag := FlagView.new()
	flag.setup(game.terrain)
	_world.add_child(flag)

	var golfer := GolferView.new()
	golfer.setup(game)
	_world.add_child(golfer)

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


func _physics_process(delta: float) -> void:
	var aim_input: float = Input.get_axis("aim_down", "aim_up")
	if aim_input != 0.0:
		game.adjust_aim(aim_input, delta)
	game.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swing", false):
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
	elif event.is_action_pressed("restart", false):
		game.restart()
	elif event.is_action_pressed("review_next_hole", false):
		_review_jump(1)
	elif event.is_action_pressed("review_prev_hole", false):
		_review_jump(-1)
	elif event.is_action_pressed("fullscreen", false):
		_toggle_fullscreen()
	elif event.is_action_pressed("quit", false):
		get_tree().quit()


func _review_jump(step: int) -> void:
	run.jump_by(step)
	load_current_hole()


func _toggle_fullscreen() -> void:
	var window: Window = get_window()
	if window.mode == Window.MODE_WINDOWED:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = Vector2i(1280, 720)


func _on_shot_struck(quality: String, _power: float) -> void:
	hud.show_message(quality, 1.1)
	fx.dust(game.ball.pos, Color(0.85, 0.95, 0.65), 6, game.facing)


func _on_penalty_taken(kind: String) -> void:
	var text: String = "SPLASH! +1 STROKE" if kind == "water" else "OUT OF BOUNDS! +1 STROKE"
	hud.show_message(text, HoleGame.PENALTY_TIME)


func _on_hole_finished(strokes: int, _score_name: String) -> void:
	run.record_score(strokes)


# The press arrives from inside the hole's own rules, so swap holes after it returns.
func _on_continue_requested() -> void:
	run.advance()
	load_current_hole.call_deferred()


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


func _on_ball_holed() -> void:
	fx.confetti(Vector2(game.hole.cup_x, game.terrain.rim_y - 6.0))
