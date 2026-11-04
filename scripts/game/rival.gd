class_name Rival
extends RefCounted
## The cheating rival on the boss hole. Takes turns with the player on the same hole, with
## its own ball and the plain clubs, picking shots the way a decent player would and
## mishitting some of them. Moving hazards pass straight through its ball, and every other
## turn it cheats some other way.

signal announced(text: String)
signal holed_out

enum Stage { WAITING, THINKING, SWINGING, MOVING, PENALTY, CHEATING, TURN_OVER }

const THINK_TIME := 0.9
const SWING_TIME := 0.35
const PENALTY_TIME := 1.1
const CHEAT_TIME := 1.9
## How far off a planned shot's power it can be.
const POWER_NOISE := 0.07
const PUTT_NOISE := 0.08
## How often a swing is mistimed, and how badly at worst.
const MISS_CHANCE := 0.35
const MISS_SIZE := 0.4
const POWER_STEPS := 10
## Time it spends working out its shot each frame, so the game never stutters.
const PLANNING_BUDGET_USEC := 3000
const SIM_STEP := 1.0 / 60.0
const SIM_MAX_STEPS := 900
## Cheats it can pull, in a random order each duel. It also gets one free drop from water.
const TRICKS := ["gust", "kick", "grease", "pencil"]
const GUST_STRENGTH := 35.0
const GREASE_SPEED := 1.25
const KICK_MIN := 40.0
const KICK_MAX := 90.0
const KICK_CUP_CLEARANCE := 12.0

var game: HoleGame
var ball: BallSim
var clubs: Array[ClubData] = []
var club_index: int = 0
var facing: int = 1
var strokes: int = 0
var stage: int = Stage.WAITING
var holed: bool = false

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _turns: int = 0
var _tricks_left: Array[String] = []
var _free_drop_used: bool = false
var _last_spot_x: float = 0.0
var _last_plan_spot: float = -1.0
var _plan: Dictionary = {}
## The shots still to try this turn, and the best one so far.
var _options: Array[Dictionary] = []
var _best_option: Dictionary = {}
var _best_score: float = INF
var _go_far: bool = false
var _tried_flipping: bool = false


func _init(p_game: HoleGame, p_clubs: Array[ClubData], p_seed: int = -1) -> void:
	game = p_game
	clubs = p_clubs
	if p_seed >= 0:
		_rng.seed = p_seed
	else:
		_rng.randomize()
	ball = _new_sim()
	ball.place(game.hole.tee_x)
	_last_spot_x = game.hole.tee_x
	facing = _toward_cup()
	ball.stopped.connect(_on_ball_stopped)
	ball.holed.connect(_on_ball_holed)
	ball.hazard.connect(_on_ball_hazard)
	var tricks: Array = TRICKS.duplicate()
	while not tricks.is_empty():
		_tricks_left.append(str(tricks.pop_at(_rng.randi_range(0, tricks.size() - 1))))


func current_club() -> ClubData:
	return clubs[club_index]


func begin_turn() -> void:
	_turns += 1
	_timer = 0.0
	stage = Stage.THINKING
	facing = _toward_cup()
	# Back at the same spot means the last plan failed, so it goes for distance instead.
	_go_far = is_equal_approx(ball.pos.x, _last_plan_spot)
	_last_plan_spot = ball.pos.x
	_tried_flipping = false
	_list_options()


func is_turn_over() -> bool:
	return stage == Stage.TURN_OVER


## How far through its swing it is, from 0 to 1.
func swing_progress() -> float:
	return clampf(_timer / SWING_TIME, 0.0, 1.0)


func tick(dt: float) -> void:
	_timer += dt
	match stage:
		Stage.THINKING:
			_work_on_plan()
			if _timer >= THINK_TIME and _options.is_empty():
				_plan = _finish_plan()
				club_index = int(_plan["club"])
				_timer = 0.0
				stage = Stage.SWINGING
		Stage.SWINGING:
			if _timer >= SWING_TIME:
				_strike()
		Stage.MOVING:
			ball.step(dt)
		Stage.PENALTY:
			if _timer >= PENALTY_TIME:
				ball.place(_last_spot_x)
				_end_shot()
		Stage.CHEATING:
			if _timer >= CHEAT_TIME:
				stage = Stage.TURN_OVER


func _strike() -> void:
	var club: ClubData = current_club()
	var power: float = float(_plan["power"])
	power += _rng.randfn(0.0, PUTT_NOISE if club.is_putter else POWER_NOISE)
	power = clampf(power, SwingMeter.MIN_PRESS_POWER, 1.0)
	var accuracy: float = 0.0
	if not club.is_putter and _rng.randf() < MISS_CHANCE:
		accuracy = _rng.randf_range(-MISS_SIZE, MISS_SIZE)
	var shot: Dictionary = _shot(club, float(_plan["angle"]), power, accuracy)
	strokes += 1
	_last_spot_x = ball.pos.x
	ball.launch(shot["velocity"], float(shot["spin"]))
	stage = Stage.MOVING


func _shot(club: ClubData, angle: float, power: float, accuracy: float) -> Dictionary:
	var x: float = ball.pos.x
	return ShotCalc.compute(
			club, power, accuracy, 0, facing, game.lie_power_at(x, club),
			game.launch_angle_at(x, club, angle, facing),
			float(Surface.props(game.terrain.surface_at(x))["lie_spin"]))


# Every usable club at a few angles and powers.
func _list_options() -> void:
	_options.clear()
	_best_option = {}
	_best_score = INF
	var on_green: bool = game.terrain.surface_at(ball.pos.x) == Surface.Type.GREEN
	for i in clubs.size():
		var club: ClubData = clubs[i]
		if club.is_putter != on_green:
			continue
		var angles: Array[float] = [club.loft_deg]
		if not club.is_putter:
			angles = [club.min_angle_deg, club.loft_deg, lerpf(club.loft_deg, club.max_angle_deg, 0.5), club.max_angle_deg]
		for angle in angles:
			for step in range(1, POWER_STEPS + 1):
				_options.append({ "club": i, "angle": angle, "power": float(step) / float(POWER_STEPS) })


# Tries options until this frame's time is up, keeping the safe shot that finishes closest
# to the cup. If none is safe, it turns around and looks the other way.
func _work_on_plan() -> void:
	var started: int = Time.get_ticks_usec()
	while not _options.is_empty() and Time.get_ticks_usec() - started < PLANNING_BUDGET_USEC:
		_try_option(_options.pop_back())
	if _options.is_empty() and _best_option.is_empty() and not _tried_flipping:
		_tried_flipping = true
		facing = -facing
		_go_far = true
		_list_options()


func _try_option(option: Dictionary) -> void:
	var sim: BallSim = _new_sim()
	sim.pos = ball.pos
	var shot: Dictionary = _shot(clubs[int(option["club"])], float(option["angle"]), float(option["power"]), 0.0)
	sim.launch(shot["velocity"], 0.0)
	var steps: int = 0
	while sim.is_moving() and steps < SIM_MAX_STEPS:
		sim.step(SIM_STEP)
		steps += 1
	if sim.state != BallSim.State.RESTING and sim.state != BallSim.State.HOLED:
		return
	var score: float = absf(game.hole.cup_x - sim.pos.x)
	if sim.state == BallSim.State.HOLED:
		score = -1.0
	elif _go_far:
		score = -absf(sim.pos.x - ball.pos.x)
	if score < _best_score:
		_best_score = score
		_best_option = option


func _finish_plan() -> Dictionary:
	if not _best_option.is_empty():
		return _best_option
	# Nowhere is safe, so it just goes for it.
	facing = _toward_cup()
	return { "club": 1, "angle": clubs[1].max_angle_deg, "power": 1.0 }


# Moving hazards don't touch its ball at all. That's the cheat that lets it keep up.
func _new_sim() -> BallSim:
	var sim := BallSim.new(game.terrain)
	sim.obstacles = game.obstacles
	sim.wind = game.hole.wind
	sim.ignore_moving = true
	return sim


func _toward_cup() -> int:
	return 1 if game.hole.cup_x >= ball.pos.x else -1


func _on_ball_stopped() -> void:
	_end_shot()


func _on_ball_holed() -> void:
	holed = true
	holed_out.emit()
	announced.emit("THE RIVAL HOLES OUT IN %d" % strokes)
	_timer = 0.0
	stage = Stage.CHEATING


func _on_ball_hazard(_at: Vector2, _kind: String) -> void:
	_timer = 0.0
	stage = Stage.PENALTY
	if _free_drop_used:
		strokes += 1
		announced.emit("THE RIVAL TAKES A PENALTY")
	else:
		_free_drop_used = true
		announced.emit("THE RIVAL CALLS IT A FREE DROP!")


# Cheats on every second turn, once the ball's at rest.
func _end_shot() -> void:
	_timer = 0.0
	if _turns % 2 == 0 and _pull_trick():
		stage = Stage.CHEATING
	else:
		stage = Stage.TURN_OVER


func _pull_trick() -> bool:
	while not _tricks_left.is_empty():
		var trick: String = _tricks_left.pop_front()
		match trick:
			"gust":
				var toward_player_cup: float = signf(game.hole.cup_x - game.ball.pos.x)
				game.set_gust(-toward_player_cup * GUST_STRENGTH)
				announced.emit("THE RIVAL WAVES A FAN! HEADWIND!")
				return true
			"grease":
				game.set_meter_cheat(GREASE_SPEED)
				announced.emit("THE RIVAL GREASED YOUR GRIP!")
				return true
			"pencil":
				if strokes >= 2:
					strokes -= 1
					announced.emit("THE RIVAL ERASES A STROKE!")
					return true
			"kick":
				if _kick_ball():
					announced.emit("THE RIVAL KICKS ITS BALL!")
					return true
	return false


# Nudges the ball toward the cup, but never past it, into water, or into a cliff.
func _kick_ball() -> bool:
	var direction: float = signf(game.hole.cup_x - ball.pos.x)
	var distance: float = _rng.randf_range(KICK_MIN, KICK_MAX)
	var room: float = absf(game.hole.cup_x - ball.pos.x) - KICK_CUP_CLEARANCE
	distance = minf(distance, room)
	if distance < KICK_MIN * 0.5:
		return false
	var target: float = ball.pos.x + direction * distance
	if game.terrain.surface_at(target) == Surface.Type.WATER:
		return false
	ball.place(target)
	return true
