class_name HoleGame
extends RefCounted
## The rules of playing one hole. Knows nothing about nodes or drawing: views read
## its state and listen to its signals, and tests can drive it directly.

signal phase_changed(phase: int)
signal shot_struck(quality: String, power: float)
signal hole_finished(strokes: int, score_name: String)
signal penalty_taken(kind: String)
## The player pressed swing on the finished hole.
signal continue_requested
signal coin_collected(at: Vector2)
signal trick_shot(trick_name: String, coins: int)
## A free penalty was used up, so the penalty just taken cost no stroke.
signal penalty_forgiven
## The stroke budget has run out, with the ball not in the hole.
signal out_of_strokes
## The ball has come to rest at or past the hole's checkpoint for the first time.
signal checkpoint_touched

enum Phase { AIM, SWING, DOWNSWING, BALL_MOVING, PENALTY, COMPLETE, RIVAL_TURN, OUT_OF_STROKES }

## Coins for trick shots. Only the best one counts when a ball drops, and going through
## a windmill's door pays as it happens.
const TRICK_HOLE_IN_ONE := 15
const TRICK_BANK_SHOT := 8
const TRICK_CHIP_IN := 6
const TRICK_LONG_PUTT := 5
const TRICK_OFF_THE_PIN := 4
const TRICK_MILL_DOOR := 3
## A putt holed from at least this far counts as long: 50 yards.
const LONG_PUTT_DISTANCE := 150.0

const DOWNSWING_TIME := 0.14
const PENALTY_TIME := 1.3
const PREVIEW_STEP := 1.0 / 60.0
const PREVIEW_MAX_STEPS := 600
## How fast holding the aim control changes the launch angle, degrees per second.
const AIM_RATE := 30.0
## Share of the ground's slope that tilts the launch angle.
const SLOPE_TILT_SHARE := 0.5
## On an upslope, the ball always leaves at least this far above the ground.
const SLOPE_CLEARANCE := 6.0
const MIN_LAUNCH_ANGLE := 3.0
const MAX_LAUNCH_ANGLE := 85.0
const MIN_LIE_POWER := 0.1
## A ball returned to the checkpoint sits this far on the tee side of its flag.
const CHECKPOINT_STAND_OFF := 22.0

var hole: HoleData
var terrain: Terrain
var ball: BallSim
var obstacles: Array[Obstacle] = []
var meter := SwingMeter.new()
var clubs: Array[ClubData] = []
var club_index: int = 0
## -1 backspin, 0 none, 1 topspin.
var spin: int = 0
## Launch angle for the next shot, degrees above level.
var aim_angle: float = 0.0
## 1 hits toward +x, -1 hits toward -x. Set toward the cup at the start of a shot, and
## the player can flip it for that shot.
var facing: int = 1
var phase: int = Phase.AIM
var strokes: int = 0
var last_quality: String = ""
## The stroke that ends the run if the ball doesn't drop. Zero means no limit.
var stroke_limit: int = 0
## Penalties this hole that cost no stroke.
var free_penalties: int = 0
## Floating Isles: losing the ball sends it back to the tee. That costs no extra stroke, and
## the strokes taken so far still count.
var falls_return_to_tee: bool = false:
	set(value):
		falls_return_to_tee = value
		# The first shot was set up before this was known, and these rules offer a different club.
		if phase == Phase.AIM:
			_begin_aim()
var falls: int = 0
## Once true, a fall returns the ball to the checkpoint instead of the tee.
var checkpoint_reached: bool = false
## The opponent on a duel hole, or null when playing alone.
var rival: Rival = null
var player_holed: bool = false
var duel_over: bool = false
var duel_won: bool = false

var _ball_id: String = ""
var _gust: float = 0.0
var _meter_cheat: float = 1.0
var _shot_from_x: float = 0.0
var _shot_from_green: bool = false
var _shot_by_putter: bool = false
var _shot_hit_pad: bool = false
var _shot_hit_pin: bool = false
var _shot_paid_door: bool = false
var _last_spot_x: float = 0.0
var _phase_time: float = 0.0
var _preview_dirty: bool = true
var _preview: Dictionary = {}


func _init(p_hole: HoleData, p_clubs: Array[ClubData], ball_id: String = "") -> void:
	hole = p_hole
	clubs = p_clubs
	_ball_id = ball_id
	terrain = Terrain.new(hole)
	obstacles = Obstacle.build_all(hole, terrain)
	ball = BallSim.new(terrain)
	ball.obstacles = obstacles
	ball.collects_coins = true
	Items.apply_ball(ball, _ball_id)
	ball.wind = current_wind()
	ball.stopped.connect(_on_ball_stopped)
	ball.holed.connect(_on_ball_holed)
	ball.hazard.connect(_on_ball_hazard)
	ball.obstacle_hit.connect(_on_ball_touched)
	ball.pin_hit.connect(_on_pin_hit)
	restart()


func restart() -> void:
	strokes = 0
	falls = 0
	checkpoint_reached = false
	last_quality = ""
	for obstacle in obstacles:
		obstacle.reset()
	ball.place(hole.tee_x)
	_last_spot_x = hole.tee_x
	meter.reset()
	_begin_aim()


## Starts play from any spot on the hole, for testing a map.
func start_from(x: float) -> void:
	ball.place(x)
	_last_spot_x = x
	_begin_aim()


func current_club() -> ClubData:
	return clubs[club_index]


func lie_surface() -> int:
	return terrain.surface_at(ball.pos.x)


## Share of the current club's range available from this lie. Driver suffers most.
func lie_power() -> float:
	return lie_power_at(ball.pos.x, current_club())


func lie_power_at(x: float, club: ClubData) -> float:
	var loss: float = 1.0 - float(Surface.props(terrain.surface_at(x))["lie_power"])
	return maxf(1.0 - loss * club.lie_sensitivity, MIN_LIE_POWER)


## The angle the ball will actually leave at: the aim, tilted by the slope it sits on.
func launch_angle() -> float:
	return launch_angle_at(ball.pos.x, current_club(), aim_angle, facing)


func launch_angle_at(x: float, club: ClubData, aim: float, direction: int) -> float:
	if club.is_putter:
		return 0.0
	var uphill: float = rad_to_deg(atan(-terrain.slope(x) * float(direction)))
	var angle: float = aim + uphill * SLOPE_TILT_SHARE
	if uphill > 0.0:
		angle = maxf(angle, uphill + SLOPE_CLEARANCE)
	return clampf(angle, MIN_LAUNCH_ANGLE, MAX_LAUNCH_ANGLE)


## The launch this lie and aim would give for the given meter results.
func shot_for(power: float, accuracy: float) -> Dictionary:
	return ShotCalc.compute(
			current_club(), power, accuracy, spin, facing, lie_power(), launch_angle(),
			float(Surface.props(lie_surface())["lie_spin"]))


func distance_to_cup() -> float:
	return absf(hole.cup_x - ball.pos.x)


## The wind on the player's ball right now, including any trick of the rival's.
func current_wind() -> float:
	return (hole.wind + _gust) * Items.ball_wind_share(_ball_id)


## The rival's fan: extra wind on the player's next shot.
func set_gust(amount: float) -> void:
	_gust = amount
	ball.wind = current_wind()
	_preview_dirty = true


## The rival's grease: a faster meter on the player's next shot.
func set_meter_cheat(speed: float) -> void:
	_meter_cheat = speed


func start_duel(opponent: Rival) -> void:
	rival = opponent
	player_holed = false
	duel_over = false
	duel_won = false


## Lets go of the rival when this hole is done with, since the two refer to each other.
func end_duel() -> void:
	rival = null


## The ball the camera should watch.
func active_ball() -> BallSim:
	return rival.ball if phase == Phase.RIVAL_TURN else ball


func active_facing() -> int:
	return rival.facing if phase == Phase.RIVAL_TURN else facing


func is_active_ball_moving() -> bool:
	return phase == Phase.BALL_MOVING or (phase == Phase.RIVAL_TURN and rival.ball.is_moving())


## Gives back strokes after running out, and play carries on.
func grant_strokes(amount: int) -> void:
	stroke_limit += amount
	_continue_play()


func cycle_club(step_by: int) -> void:
	if phase != Phase.AIM:
		return
	club_index = posmod(club_index + step_by, clubs.size())
	_reset_aim()


func select_club(index: int) -> void:
	if phase != Phase.AIM or index < 0 or index >= clubs.size():
		return
	club_index = index
	_reset_aim()


## Raises (direction 1) or lowers (direction -1) the launch angle while held.
func adjust_aim(direction: float, dt: float) -> void:
	if phase != Phase.AIM or current_club().is_putter:
		return
	var club: ClubData = current_club()
	aim_angle = clampf(
			aim_angle + direction * AIM_RATE * dt, club.min_angle_deg, club.max_angle_deg)
	_preview_dirty = true


func change_spin(step_by: int) -> void:
	if phase != Phase.AIM or current_club().is_putter:
		return
	spin = clampi(spin + step_by, -1, 1)
	_preview_dirty = true


## Turns the golfer to hit the other way, for this shot only.
func flip_facing() -> void:
	if phase != Phase.AIM:
		return
	facing = -facing
	_preview_dirty = true


## Putts are judged purely by eye, so they show no aim line or reach.
func shows_aim_line() -> bool:
	var aiming: bool = phase == Phase.AIM or phase == Phase.SWING
	return aiming and not current_club().is_putter


## The single swing button. What it does depends on the phase.
func press_swing() -> void:
	match phase:
		Phase.AIM:
			# A putt's first press only starts its cursor, and the next one sets the power.
			if current_club().is_putter:
				meter.start_sweep()
			else:
				meter.reset()
				meter.press()
			_set_phase(Phase.SWING)
		Phase.SWING:
			meter.press()
		Phase.COMPLETE:
			continue_requested.emit()


## A sim that matches what the player is shown: same ground, ball and wind, but it
## ignores moving hazards, which they have to time for themselves.
func new_preview_sim() -> BallSim:
	var sim := BallSim.new(terrain)
	sim.obstacles = obstacles
	Items.apply_ball(sim, _ball_id)
	sim.cup_pull_scale *= current_club().cup_pull_scale
	sim.wind = current_wind()
	sim.ignore_moving = true
	sim.place(ball.pos.x)
	return sim


func tick(dt: float) -> void:
	_phase_time += dt
	for obstacle in obstacles:
		obstacle.tick(dt)
	match phase:
		Phase.SWING:
			meter.tick(dt)
			if meter.is_done():
				_set_phase(Phase.DOWNSWING)
		Phase.DOWNSWING:
			if _phase_time >= DOWNSWING_TIME:
				_strike()
		Phase.BALL_MOVING:
			ball.step(dt)
		Phase.PENALTY:
			if _phase_time >= PENALTY_TIME:
				ball.place(_last_spot_x)
				_after_player_shot()
		Phase.RIVAL_TURN:
			rival.tick(dt)
			if rival.is_turn_over():
				_after_rival_turn()


## Hits the ball straight away with the given meter results. Used by tests and bots.
func strike_with(power: float, accuracy: float) -> void:
	meter.reset()
	meter.power = power
	meter.accuracy = accuracy
	_strike()


## Full-power path for the aim display: { "path": points, "landing": Vector2 }.
func preview() -> Dictionary:
	if _preview_dirty:
		_preview = _build_preview()
		_preview_dirty = false
	return _preview


static func score_name(p_strokes: int, par: int) -> String:
	if p_strokes == 1:
		return "HOLE IN ONE!"
	var diff: int = p_strokes - par
	match diff:
		-3: return "ALBATROSS!"
		-2: return "EAGLE!"
		-1: return "BIRDIE!"
		0: return "PAR"
		1: return "BOGEY"
		2: return "DOUBLE BOGEY"
		3: return "TRIPLE BOGEY"
	if diff < 0:
		return "%d UNDER PAR!" % -diff
	return "%d OVER PAR" % diff


func _strike() -> void:
	var shot: Dictionary = shot_for(meter.power, meter.accuracy)
	strokes += 1
	_last_spot_x = ball.pos.x
	last_quality = str(shot["quality"])
	_shot_from_x = ball.pos.x
	_shot_from_green = lie_surface() == Surface.Type.GREEN
	_shot_by_putter = current_club().is_putter
	_shot_hit_pad = false
	_shot_hit_pin = false
	_shot_paid_door = false
	Items.apply_ball(ball, _ball_id)
	ball.cup_pull_scale *= current_club().cup_pull_scale
	ball.launch(shot["velocity"], float(shot["spin"]))
	shot_struck.emit(last_quality, meter.power)
	_set_phase(Phase.BALL_MOVING)


func _begin_aim() -> void:
	facing = 1 if hole.cup_x >= ball.pos.x else -1
	_pick_club_for_lie()
	if current_club().is_putter:
		spin = 0
	_reset_aim()
	_set_phase(Phase.AIM)


func _reset_aim() -> void:
	aim_angle = current_club().loft_deg
	_preview_dirty = true
	# Bad lies shrink the sweet spot, and the meter shows it before the swing.
	var lie_window: float = float(Surface.props(lie_surface())["lie_window"])
	meter.perfect_window = SwingMeter.PERFECT_WINDOW * lie_window * current_club().window_scale
	meter.time_scale = current_club().meter_speed * _meter_cheat
	meter.reset()


# Offers a sensible club so most shots need no menu input. The player can change it.
func _pick_club_for_lie() -> void:
	var wanted: String = "iron"
	# Floating Isles is about accuracy, so it always offers the Iron until the ball's on the green.
	if falls_return_to_tee:
		_select_club_by_id("putter" if lie_surface() == Surface.Type.GREEN else "iron")
		return
	if lie_surface() == Surface.Type.GREEN:
		wanted = "putter"
	elif lie_surface() != Surface.Type.SAND and distance_to_cup() > _full_range_estimate("iron"):
		# The driver's low loft can't clear a bunker wall, so sand always offers the iron.
		wanted = "driver"
	_select_club_by_id(wanted)
	if current_club().is_putter or _club_has_safe_shot(club_index):
		return
	for i in clubs.size():
		if not clubs[i].is_putter and _club_has_safe_shot(i):
			club_index = i
			return


func _select_club_by_id(id: String) -> void:
	for i in clubs.size():
		if clubs[i].id == id:
			club_index = i


# A slope can tilt a low club straight into a hazard at every power.
func _club_has_safe_shot(index: int) -> bool:
	var previous_club: int = club_index
	var previous_aim: float = aim_angle
	club_index = index
	aim_angle = current_club().loft_deg
	var safe: bool = false
	for power: float in [1.0, 0.75, 0.5, 0.25]:
		var sim: BallSim = new_preview_sim()
		var shot: Dictionary = shot_for(power, 0.0)
		sim.launch(shot["velocity"], float(shot["spin"]))
		var steps: int = 0
		while sim.is_moving() and steps < PREVIEW_MAX_STEPS * 3:
			sim.step(PREVIEW_STEP)
			steps += 1
		if sim.state == BallSim.State.RESTING or sim.state == BallSim.State.HOLED:
			safe = true
			break
	club_index = previous_club
	aim_angle = previous_aim
	return safe


func _full_range_estimate(club_id: String) -> float:
	for club in clubs:
		if club.id == club_id:
			var rad: float = deg_to_rad(club.loft_deg)
			return club.max_speed * club.max_speed * sin(2.0 * rad) / BallSim.GRAVITY
	return 0.0


func _build_preview() -> Dictionary:
	var sim: BallSim = new_preview_sim()
	var shot: Dictionary = shot_for(1.0, 0.0)
	sim.launch(shot["velocity"], float(shot["spin"]))
	var path := PackedVector2Array()
	for i in PREVIEW_MAX_STEPS:
		sim.step(PREVIEW_STEP)
		if i % 2 == 0:
			path.append(sim.pos)
		if not sim.is_moving() or sim.bounce_count > 0:
			break
	return { "path": path, "landing": sim.pos }


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	_phase_time = 0.0
	phase_changed.emit(phase)


func _on_ball_stopped() -> void:
	_check_checkpoint()
	_after_player_shot()


# Coming to rest on the checkpoint's island or any island beyond it counts, so a long shot over
# the flag doesn't leave the player worse off than a short one onto it.
func _check_checkpoint() -> void:
	if not falls_return_to_tee or checkpoint_reached or hole.checkpoint_x < 0.0:
		return
	if ball.pos.x >= hole.checkpoint_from:
		checkpoint_reached = true
		checkpoint_touched.emit()


# After a shot that didn't drop. The rival's tricks only last for the shot they targeted.
func _after_player_shot() -> void:
	_gust = 0.0
	ball.wind = current_wind()
	_meter_cheat = 1.0
	if stroke_limit > 0 and strokes >= stroke_limit:
		_set_phase(Phase.OUT_OF_STROKES)
		out_of_strokes.emit()
		return
	_continue_play()


func _continue_play() -> void:
	if rival == null:
		_begin_aim()
	elif not _settle_duel():
		if rival.holed:
			_begin_aim()
		else:
			_start_rival_turn()


func _start_rival_turn() -> void:
	_set_phase(Phase.RIVAL_TURN)
	rival.begin_turn()


func _after_rival_turn() -> void:
	if _settle_duel():
		return
	if player_holed:
		_start_rival_turn()
	else:
		_begin_aim()


# Lowest strokes wins and ties go to the rival, so it's over once neither can change that.
func _settle_duel() -> bool:
	if player_holed and rival.holed:
		_finish_duel(strokes < rival.strokes)
	elif player_holed and rival.strokes >= strokes:
		_finish_duel(true)
	elif rival.holed and strokes + 1 >= rival.strokes:
		_finish_duel(false)
	return duel_over


func _finish_duel(won: bool) -> void:
	duel_over = true
	duel_won = won
	_set_phase(Phase.COMPLETE)
	hole_finished.emit(strokes, "YOU WIN!" if won else "THE RIVAL WINS")


func _on_ball_holed() -> void:
	_pay_for_trick_finish()
	if rival != null:
		player_holed = true
		if not _settle_duel():
			_start_rival_turn()
		return
	_set_phase(Phase.COMPLETE)
	hole_finished.emit(strokes, score_name(strokes, hole.par))


func _on_ball_hazard(_at: Vector2, kind: String) -> void:
	if falls_return_to_tee:
		falls += 1
		_last_spot_x = hole.checkpoint_x - CHECKPOINT_STAND_OFF if checkpoint_reached else hole.tee_x
		penalty_taken.emit("fall")
		_set_phase(Phase.PENALTY)
		return
	if free_penalties > 0:
		free_penalties -= 1
		penalty_taken.emit(kind)
		penalty_forgiven.emit()
	else:
		strokes += 1
		penalty_taken.emit(kind)
	_set_phase(Phase.PENALTY)


func _on_ball_touched(at: Vector2, kind: String) -> void:
	match kind:
		"coin":
			coin_collected.emit(at)
		"pad":
			_shot_hit_pad = true
		"mill_door":
			if not _shot_paid_door:
				_shot_paid_door = true
				trick_shot.emit("THROUGH THE MILL!", TRICK_MILL_DOOR)


func _on_pin_hit(_at: Vector2) -> void:
	_shot_hit_pin = true


func _pay_for_trick_finish() -> void:
	if strokes == 1:
		trick_shot.emit("HOLE IN ONE!", TRICK_HOLE_IN_ONE)
	elif _shot_hit_pad:
		trick_shot.emit("BANK SHOT!", TRICK_BANK_SHOT)
	elif not _shot_by_putter and not _shot_from_green:
		trick_shot.emit("CHIP-IN!", TRICK_CHIP_IN)
	elif _shot_by_putter and absf(hole.cup_x - _shot_from_x) >= LONG_PUTT_DISTANCE:
		trick_shot.emit("LONG PUTT!", TRICK_LONG_PUTT)
	elif _shot_hit_pin:
		trick_shot.emit("OFF THE PIN!", TRICK_OFF_THE_PIN)
