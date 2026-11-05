class_name GameAudio
extends Node
## Listens to one hole's rules and plays what should be heard. Changes nothing in the game.

const JINGLE_DELAY := 0.42
const MAX_IMPACT_SPEED := 280.0
const MIN_IMPACT_SPEED := 22.0
## One tick for each of these steps the meter's cursor climbs.
const METER_TICKS := 12
## Coins in one shot climb in pitch, one semitone at a time.
const COIN_STEP := 1.0594631
const AIM_SETTLE_TIME := 0.2

var game: HoleGame
var _aim_age: float = 0.0
var _last_stage: int = SwingMeter.Stage.IDLE
var _last_tick: int = -1
var _was_full_power: bool = false
var _last_club: int = 0
var _last_spin: int = 0
var _last_facing: int = 1
var _rival_stage: int = Rival.Stage.WAITING
var _coin_run: int = 0


func setup(p_game: HoleGame) -> void:
	game = p_game


func _ready() -> void:
	_last_club = game.club_index
	_last_spin = game.spin
	_last_facing = game.facing
	game.phase_changed.connect(_on_phase_changed)
	game.shot_struck.connect(_on_shot_struck)
	game.hole_finished.connect(_on_hole_finished)
	game.penalty_taken.connect(_on_penalty_taken)
	game.penalty_forgiven.connect(_on_penalty_forgiven)
	game.coin_collected.connect(_on_coin_collected)
	game.trick_shot.connect(_on_trick_shot)
	_listen_to(game.ball)
	if game.rival != null:
		_listen_to(game.rival.ball)
		game.rival.announced.connect(_on_rival_announced)


func _listen_to(ball: BallSim) -> void:
	ball.bounced.connect(_on_bounced)
	ball.hazard.connect(_on_hazard)
	ball.holed.connect(_on_holed)
	ball.pin_hit.connect(_on_pin_hit)
	ball.obstacle_hit.connect(_on_obstacle_hit)


func _process(_delta: float) -> void:
	_watch_meter()
	_watch_aim()
	_watch_rival()


# The meter has no signals, so this notices its presses and the climb of its cursor.
func _watch_meter() -> void:
	var meter: SwingMeter = game.meter
	if game.phase != HoleGame.Phase.SWING:
		_last_stage = SwingMeter.Stage.IDLE
		_last_tick = -1
		_was_full_power = false
		return
	if meter.stage != _last_stage:
		if meter.stage != SwingMeter.Stage.DONE:
			Sound.sfx("meter_press", 1.0 if meter.stage != SwingMeter.Stage.RETURNING else 1.26)
		_last_stage = meter.stage
		_last_tick = -1
	if meter.full_power and not _was_full_power:
		Sound.sfx("menu_ok", 1.2)
	_was_full_power = meter.full_power
	if meter.stage == SwingMeter.Stage.RISING or meter.stage == SwingMeter.Stage.SWEEPING:
		var tick: int = int(meter.cursor * float(METER_TICKS))
		if tick != _last_tick:
			_last_tick = tick
			Sound.sfx("meter_tick", 0.8 + meter.cursor * 1.1, -6.0)


# The game sets up the club and direction itself as each shot begins, which stays silent.
func _watch_aim() -> void:
	if game.club_index != _last_club or game.spin != _last_spin or game.facing != _last_facing:
		if game.phase == HoleGame.Phase.AIM and _aim_age >= AIM_SETTLE_TIME:
			Sound.sfx("menu_move")
		_last_club = game.club_index
		_last_spin = game.spin
		_last_facing = game.facing


func _physics_process(delta: float) -> void:
	_aim_age = _aim_age + delta if game.phase == HoleGame.Phase.AIM else 0.0


func _watch_rival() -> void:
	if game.rival == null:
		return
	var stage: int = game.rival.stage
	if stage == _rival_stage:
		return
	if stage == Rival.Stage.MOVING and _rival_stage == Rival.Stage.SWINGING:
		_play_strike(game.rival.current_club(), "")
	_rival_stage = stage


func _play_strike(club: ClubData, quality: String) -> void:
	if club.is_putter:
		Sound.sfx("hit_putt")
		return
	Sound.sfx("swing", 1.0, -8.0)
	match quality:
		"FULL POWER!!":
			Sound.sfx("hit_full")
		"PERFECT!":
			Sound.sfx("hit_driver" if club.id == "driver" else "hit_iron")
			Sound.sfx("hit_perfect")
		"", "GOOD":
			Sound.sfx("hit_driver" if club.id == "driver" else "hit_iron")
		_:
			Sound.sfx("hit_miss")


func _on_phase_changed(phase: int) -> void:
	match phase:
		HoleGame.Phase.DOWNSWING:
			if not game.current_club().is_putter:
				Sound.sfx("swing")
		HoleGame.Phase.RIVAL_TURN:
			Sound.sfx("rival_turn")
		HoleGame.Phase.BALL_MOVING:
			_coin_run = 0
		HoleGame.Phase.OUT_OF_STROKES:
			Sound.jingle("game_over", JINGLE_DELAY)


func _on_shot_struck(quality: String, _power: float) -> void:
	_play_strike(game.current_club(), quality)


func _on_hole_finished(strokes: int, score_name: String) -> void:
	if game.rival != null:
		Sound.music("")
		Sound.jingle("win" if game.duel_won else "lose", JINGLE_DELAY)
		return
	var to_par: int = strokes - game.hole.par
	if strokes == 1:
		Sound.jingle("ace", JINGLE_DELAY)
	elif to_par < 0:
		Sound.jingle("birdie", JINGLE_DELAY)
	elif to_par == 0:
		Sound.jingle("holed", JINGLE_DELAY)
	else:
		Sound.jingle("bogey", JINGLE_DELAY)
	if score_name == "":
		push_warning("a hole finished with no score name")


func _on_bounced(_at: Vector2, surface: int, impact_speed: float) -> void:
	if impact_speed < MIN_IMPACT_SPEED:
		return
	var force: float = clampf(impact_speed / MAX_IMPACT_SPEED, 0.0, 1.0)
	var volume: float = lerpf(-16.0, 0.0, sqrt(force))
	var pitch: float = randf_range(0.94, 1.06)
	match surface:
		Surface.Type.SAND:
			Sound.sfx("bounce_sand", pitch, volume)
		Surface.Type.GREEN:
			Sound.sfx("bounce_green", pitch, volume)
		_:
			Sound.sfx("bounce_grass", pitch, volume)


func _on_hazard(_at: Vector2, kind: String) -> void:
	if kind == "water":
		Sound.sfx("splash")


func _on_holed() -> void:
	Sound.sfx("cup")


func _on_pin_hit(_at: Vector2) -> void:
	Sound.sfx("pin")


func _on_obstacle_hit(_at: Vector2, kind: String) -> void:
	match kind:
		"pad":
			Sound.sfx("pad", randf_range(0.97, 1.05))
		"goose":
			Sound.sfx("goose", randf_range(0.92, 1.08))
		"cart":
			Sound.sfx("cart")
		"windmill":
			Sound.sfx("windmill")
		"sprinkler":
			Sound.sfx("sprinkler")
		"mill_door":
			Sound.sfx("door")


func _on_penalty_taken(_kind: String) -> void:
	Sound.sfx("penalty")


func _on_penalty_forgiven() -> void:
	Sound.sfx("mulligan")


func _on_coin_collected(_at: Vector2) -> void:
	Sound.sfx("coin", pow(COIN_STEP, float(mini(_coin_run, 12))))
	_coin_run += 1


func _on_trick_shot(_trick_name: String, _coins: int) -> void:
	Sound.sfx("trick")


func _on_rival_announced(text: String) -> void:
	if text.contains("HOLES OUT"):
		return
	Sound.sfx("penalty" if text.contains("PENALTY") else "rival_cheat")
