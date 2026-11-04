class_name BallSim
extends RefCounted
## Ball physics against a Terrain. Uses its own fixed-step integration rather than
## an engine rigid body, so every shot is exactly repeatable and testable.

signal bounced(at: Vector2, surface: int, impact_speed: float)
signal stopped
signal holed
signal hazard(at: Vector2, kind: String)

enum State { RESTING, AIRBORNE, ROLLING, HOLED, IN_WATER, OUT_OF_BOUNDS }

const GRAVITY := 160.0
const RADIUS := 2.0
const SUBSTEPS := 4
## Below this bounce speed the ball settles into a roll, px/s.
const ROLL_THRESHOLD := 22.0
const SPIN_LIFT := 14.0
const BACKSPIN_BITE := 0.85
const TOPSPIN_BITE := 0.35
const SPIN_DECAY := 0.35
## Extra pull over the cup. A gentle arcade assist that makes putts drop more often.
const CUP_PULL := 480.0
const MAX_MOTION_TIME := 20.0

var terrain: Terrain
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var spin: float = 0.0
var state: int = State.RESTING
var bounce_count: int = 0

var _roll_speed: float = 0.0
var _launch_dir: float = 1.0
var _motion_time: float = 0.0


func _init(p_terrain: Terrain) -> void:
	terrain = p_terrain


## Places the ball at rest on the ground at x.
func place(x: float) -> void:
	pos = Vector2(x, terrain.ground_y(x) - RADIUS)
	vel = Vector2.ZERO
	spin = 0.0
	state = State.RESTING
	bounce_count = 0
	_roll_speed = 0.0
	_motion_time = 0.0


func launch(velocity: Vector2, p_spin: float) -> void:
	spin = p_spin
	bounce_count = 0
	_motion_time = 0.0
	_launch_dir = signf(velocity.x) if velocity.x != 0.0 else 1.0
	if is_zero_approx(velocity.y):
		_roll_speed = velocity.x
		vel = terrain.tangent(pos.x) * _roll_speed
		state = State.ROLLING
	else:
		vel = velocity
		state = State.AIRBORNE


func is_moving() -> bool:
	return state == State.AIRBORNE or state == State.ROLLING


func step(dt: float) -> void:
	if not is_moving():
		return
	var sub_dt: float = dt / float(SUBSTEPS)
	for _i in SUBSTEPS:
		if state == State.AIRBORNE:
			_step_air(sub_dt)
		elif state == State.ROLLING:
			_step_roll(sub_dt)
		else:
			return
		if is_moving():
			_check_bounds()
	if is_moving():
		_motion_time += dt
		if _motion_time > MAX_MOTION_TIME:
			_come_to_rest()


func _step_air(dt: float) -> void:
	var accel: float = GRAVITY + spin * SPIN_LIFT
	if terrain.in_cup(pos.x):
		accel += CUP_PULL
	vel.y += accel * dt
	pos += vel * dt

	if terrain.in_cup(pos.x):
		if pos.y > terrain.rim_y:
			_step_inside_cup()
		return

	var ground: float = terrain.ground_y(pos.x)
	if pos.y + RADIUS >= ground:
		_collide(ground)


func _step_inside_cup() -> void:
	# Below the rim the ball can only hit the walls or the bottom.
	var limit: float = terrain.cup_half - RADIUS
	var offset: float = pos.x - terrain.cup_x
	if absf(offset) > limit:
		pos.x = terrain.cup_x + signf(offset) * limit
		vel.x *= -0.25
	if pos.y + RADIUS >= terrain.rim_y + terrain.cup_depth or pos.y > terrain.rim_y + 3.0:
		state = State.HOLED
		vel = Vector2.ZERO
		holed.emit()


func _collide(ground: float) -> void:
	var surface: int = terrain.surface_at(pos.x)
	var impact_speed: float = vel.length()
	pos.y = ground - RADIUS
	if surface == Surface.Type.WATER:
		_enter_water()
		return

	var props: Dictionary = Surface.props(surface)
	var normal: Vector2 = terrain.normal(pos.x)
	var tangent: Vector2 = terrain.tangent(pos.x)
	var vn: float = vel.dot(normal)
	var vt: float = vel.dot(tangent)

	var new_vn: float = absf(vn) * float(props["restitution"])
	var new_vt: float = vt * float(props["impact_grip"])

	# Backspin (negative) grabs and can pull the ball back. Topspin drives it on.
	var bite: float = BACKSPIN_BITE if spin < 0.0 else TOPSPIN_BITE
	new_vt += spin * absf(vn) * bite * float(props["spin_grip"]) * _launch_dir
	spin *= SPIN_DECAY

	bounce_count += 1
	bounced.emit(pos, surface, impact_speed)

	if new_vn < ROLL_THRESHOLD:
		_roll_speed = new_vt
		vel = tangent * _roll_speed
		state = State.ROLLING
	else:
		vel = tangent * new_vt + normal * new_vn


func _step_roll(dt: float) -> void:
	var surface: int = terrain.surface_at(pos.x)
	var friction: float = float(Surface.props(surface)["roll_friction"])
	var tangent: Vector2 = terrain.tangent(pos.x)
	var slope_pull: float = GRAVITY * tangent.y

	_roll_speed += slope_pull * dt
	var friction_step: float = friction * dt
	if absf(_roll_speed) <= friction_step:
		_roll_speed = 0.0
		if absf(slope_pull) <= friction:
			_come_to_rest()
			return
	else:
		_roll_speed -= signf(_roll_speed) * friction_step

	var new_x: float = pos.x + _roll_speed * tangent.x * dt
	vel = tangent * _roll_speed

	if terrain.in_cup(new_x):
		pos.x = new_x
		state = State.AIRBORNE
		return
	if terrain.surface_at(new_x) == Surface.Type.WATER:
		pos.x = new_x
		pos.y = terrain.ground_y(new_x) - RADIUS
		_enter_water()
		return

	# If the ground drops away faster than the ball can fall, it takes off.
	var ground: float = terrain.ground_y(new_x)
	var free_fall_y: float = pos.y + vel.y * dt + 0.5 * GRAVITY * dt * dt
	if free_fall_y + RADIUS < ground - 0.3:
		pos = Vector2(new_x, free_fall_y)
		state = State.AIRBORNE
		return
	pos = Vector2(new_x, ground - RADIUS)


func _come_to_rest() -> void:
	vel = Vector2.ZERO
	_roll_speed = 0.0
	spin = 0.0
	pos.y = terrain.ground_y(pos.x) - RADIUS
	state = State.RESTING
	stopped.emit()


func _enter_water() -> void:
	vel = Vector2.ZERO
	state = State.IN_WATER
	hazard.emit(pos, "water")


func _check_bounds() -> void:
	if pos.x < 0.0 or pos.x > float(terrain.length):
		vel = Vector2.ZERO
		state = State.OUT_OF_BOUNDS
		hazard.emit(pos, "out_of_bounds")
