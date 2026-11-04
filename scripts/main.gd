extends Node2D
## Builds one playable hole: creates the rules object, then attaches the views.

const HOLE_PATH := "res://data/holes/hole_01.tres"
const CLUB_PATHS := [
	"res://data/clubs/driver.tres",
	"res://data/clubs/iron.tres",
	"res://data/clubs/putter.tres",
]

var game: HoleGame
var camera: FollowCamera
var hud: Hud
var fx: FxView


func _ready() -> void:
	Controls.register()
	var clubs: Array[ClubData] = []
	for path: String in CLUB_PATHS:
		clubs.append(load(path) as ClubData)
	game = HoleGame.new(load(HOLE_PATH) as HoleData, clubs)
	_build_views()
	_connect_signals()


func _build_views() -> void:
	camera = FollowCamera.new()
	camera.setup(game)

	var background := BackgroundView.new()
	background.setup(camera)
	add_child(background)

	var trees := TreeView.new()
	trees.setup(game)
	add_child(trees)

	var water := WaterView.new()
	water.setup(game.terrain)
	var terrain_view := TerrainView.new()
	terrain_view.setup(game.terrain)
	add_child(terrain_view)
	add_child(water)

	var flag := FlagView.new()
	flag.setup(game.terrain)
	add_child(flag)

	var golfer := GolferView.new()
	golfer.setup(game)
	add_child(golfer)

	var aim := AimView.new()
	aim.setup(game)
	add_child(aim)

	var ball := BallView.new()
	ball.setup(game)
	add_child(ball)

	fx = FxView.new()
	add_child(fx)

	add_child(camera)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.setup(game, camera)
	hud_layer.add_child(hud)


func _connect_signals() -> void:
	game.shot_struck.connect(_on_shot_struck)
	game.penalty_taken.connect(_on_penalty_taken)
	game.ball.bounced.connect(_on_ball_bounced)
	game.ball.hazard.connect(_on_ball_hazard)
	game.ball.holed.connect(_on_ball_holed)


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
	elif event.is_action_pressed("flip", false):
		game.flip_facing()
	elif event.is_action_pressed("restart", false):
		game.restart()
	elif event.is_action_pressed("fullscreen", false):
		_toggle_fullscreen()
	elif event.is_action_pressed("quit", false):
		get_tree().quit()


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


func _on_ball_holed() -> void:
	fx.confetti(Vector2(game.hole.cup_x, game.terrain.rim_y - 6.0))
