class_name HoleGame
extends RefCounted
## The rules of playing one hole. Knows nothing about nodes or drawing: views read
## its state and listen to its signals, and tests can drive it directly.

signal phase_changed(phase: int)
signal shot_struck(quality: String, power: float)
signal hole_finished(strokes: int, score_name: String)
signal penalty_taken(kind: String)

enum Phase { AIM, SWING, DOWNSWING, BALL_MOVING, PENALTY, COMPLETE }

const DOWNSWING_TIME := 0.14
const PENALTY_TIME := 1.3
const PREVIEW_STEP := 1.0 / 60.0
const PREVIEW_MAX_STEPS := 600
## How fast holding the aim control changes the launch angle, degrees per second.
const AIM_RATE := 30.0

var hole: HoleData
var terrain: Terrain
var ball: BallSim
var meter := SwingMeter.new()
var clubs: Array[ClubData] = []
var club_index: int = 0
## -1 backspin, 0 none, 1 topspin.
var spin: int = 0
## Launch angle for the next shot, degrees above level.
var aim_angle: float = 0.0
## 1 hits toward +x, -1 hits toward -x.
var facing: int = 1
var phase: int = Phase.AIM
var strokes: int = 0
var last_quality: String = ""

var _last_spot_x: float = 0.0
var _phase_time: float = 0.0
var _preview_dirty: bool = true
var _preview: Dictionary = {}


func _init(p_hole: HoleData, p_clubs: Array[ClubData]) -> void:
	hole = p_hole
	clubs = p_clubs
	terrain = Terrain.new(hole)
	ball = BallSim.new(terrain)
	ball.stopped.connect(_on_ball_stopped)
	ball.holed.connect(_on_ball_holed)
	ball.hazard.connect(_on_ball_hazard)
	restart()


func restart() -> void:
	strokes = 0
	last_quality = ""
	ball.place(hole.tee_x)
	_last_spot_x = hole.tee_x
	meter.reset()
	_begin_aim()


func current_club() -> ClubData:
	return clubs[club_index]


func lie_surface() -> int:
	return terrain.surface_at(ball.pos.x)


func lie_power() -> float:
	return float(Surface.props(lie_surface())["lie_power"])


func distance_to_cup() -> float:
	return absf(hole.cup_x - ball.pos.x)


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


func flip_facing() -> void:
	if phase != Phase.AIM:
		return
	facing = -facing
	_preview_dirty = true


## The single swing button. What it does depends on the phase.
func press_swing() -> void:
	match phase:
		Phase.AIM:
			meter.reset()
			meter.press()
			_set_phase(Phase.SWING)
		Phase.SWING:
			meter.press()
		Phase.COMPLETE:
			restart()


func tick(dt: float) -> void:
	_phase_time += dt
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
				_begin_aim()


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
	var shot: Dictionary = ShotCalc.compute(
			current_club(), meter.power, meter.accuracy, spin, facing, lie_power(), aim_angle)
	strokes += 1
	_last_spot_x = ball.pos.x
	last_quality = str(shot["quality"])
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


# Offers a sensible club so most shots need no menu input. The player can change it.
func _pick_club_for_lie() -> void:
	var wanted: String = "iron"
	if lie_surface() == Surface.Type.GREEN:
		wanted = "putter"
	elif lie_surface() != Surface.Type.SAND and distance_to_cup() > _full_range_estimate("iron"):
		# The driver's low loft can't clear a bunker wall, so sand always offers the iron.
		wanted = "driver"
	for i in clubs.size():
		if clubs[i].id == wanted:
			club_index = i
			return


func _full_range_estimate(club_id: String) -> float:
	for club in clubs:
		if club.id == club_id:
			var rad: float = deg_to_rad(club.loft_deg)
			return club.max_speed * club.max_speed * sin(2.0 * rad) / BallSim.GRAVITY
	return 0.0


func _build_preview() -> Dictionary:
	var sim := BallSim.new(terrain)
	sim.place(ball.pos.x)
	var shot: Dictionary = ShotCalc.compute(
			current_club(), 1.0, 0.0, spin, facing, lie_power(), aim_angle)
	sim.launch(shot["velocity"], float(shot["spin"]))
	var path := PackedVector2Array()
	var is_putt: bool = current_club().is_putter
	for i in PREVIEW_MAX_STEPS:
		sim.step(PREVIEW_STEP)
		if i % 2 == 0:
			path.append(sim.pos)
		if not sim.is_moving() or (not is_putt and sim.bounce_count > 0):
			break
	return { "path": path, "landing": sim.pos }


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	_phase_time = 0.0
	phase_changed.emit(phase)


func _on_ball_stopped() -> void:
	_begin_aim()


func _on_ball_holed() -> void:
	_set_phase(Phase.COMPLETE)
	hole_finished.emit(strokes, score_name(strokes, hole.par))


func _on_ball_hazard(_at: Vector2, kind: String) -> void:
	strokes += 1
	penalty_taken.emit(kind)
	_set_phase(Phase.PENALTY)
