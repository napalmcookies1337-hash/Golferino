class_name BallSim
extends RefCounted
## Ball physics against a Terrain. Uses its own fixed-step integration rather than
## an engine rigid body, so every shot is exactly repeatable and testable.

signal bounced(at: Vector2, surface: int, impact_speed: float)
signal stopped
signal holed
signal hazard(at: Vector2, kind: String)
signal pin_hit(at: Vector2)
signal obstacle_hit(at: Vector2, kind: String)

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
## Below this height over the rim the ball passes the pin, so fast putts aren't rescued.
const PIN_MIN_HEIGHT := 5.0
const PIN_REBOUND := 0.25
const PIN_DROP_DAMPING := 0.4
## A skipping ball keeps this much speed, and has to land at least this fast.
const SKIP_KEEP := 0.65
const MIN_SKIP_SPEED := 60.0

var terrain: Terrain
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var spin: float = 0.0
var state: int = State.RESTING
var bounce_count: int = 0
var obstacles: Array[Obstacle] = []
## Sideways push in the air, px/s^2. Positive blows toward +x.
var wind: float = 0.0
## True for preview sims, so moving hazards don't affect what the player is shown.
var ignore_moving: bool = false
## Only the player's own ball picks up coins.
var collects_coins: bool = false

# What the ball is made of. Special balls change these.
## Bounce kept on landing.
var bounce_scale: float = 1.0
## Slowdown while rolling.
var roll_scale: float = 1.0
## Pull over the cup.
var cup_pull_scale: float = 1.0
## How hard hazards knock it around.
var knock_scale: float = 1.0
## Times per shot it can skip off water.
var water_skips: int = 0
## Where the current shot started. Solid things right next to this spot let the ball past.
var launch_x: float = 0.0
var launch_y: float = 0.0
## How many times each bounce pad has fired this ball during the current shot.
var pad_uses: Dictionary = {}
var pad_touches: Dictionary = {}

var _touching: Dictionary = {}
var _hit_this_shot: Dictionary = {}
var _roll_speed: float = 0.0
var _launch_dir: float = 1.0
var _motion_time: float = 0.0
var _skips_left: int = 0


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
	_skips_left = water_skips
	_touching.clear()
	_hit_this_shot.clear()
	pad_uses.clear()
	pad_touches.clear()
	launch_x = pos.x
	launch_y = pos.y
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
		accel += CUP_PULL * cup_pull_scale
	vel.y += accel * dt
	vel.x += wind * dt
	var old_x: float = pos.x
	pos += vel * dt
	_interact_with_obstacles(dt)
	_check_pin(old_x)

	if terrain.in_cup(pos.x):
		if pos.y > terrain.rim_y:
			_step_inside_cup()
		return

	var ground: float = terrain.ground_y(pos.x)
	if pos.y + RADIUS >= ground:
		_collide(ground)


func _interact_with_obstacles(dt: float) -> bool:
	var touched_any: bool = false
	for obstacle in obstacles:
		if _ignored_this_shot(obstacle):
			continue
		if obstacle.interact(self, dt):
			touched_any = true
			if not _touching.has(obstacle):
				_touching[obstacle] = true
				obstacle_hit.emit(pos, obstacle.kind)
			if obstacle.hits_once_per_shot():
				_hit_this_shot[obstacle] = true
		else:
			_touching.erase(obstacle)
	return touched_any


# A cart or goose hits once and then passes, or it would shove a slow ball along with
# it. It also can't hit a ball that's only just been struck beside it.
func _ignored_this_shot(obstacle: Obstacle) -> bool:
	if not obstacle.hits_once_per_shot():
		return false
	return _hit_this_shot.has(obstacle) or absf(pos.x - launch_x) < Obstacle.LAUNCH_GRACE


func _check_pin(old_x: float) -> void:
	var crossed: bool = (old_x - terrain.cup_x) * (pos.x - terrain.cup_x) <= 0.0 and old_x != pos.x
	if not crossed:
		return
	var height: float = terrain.rim_y - pos.y
	if height < PIN_MIN_HEIGHT or height > Terrain.PIN_HEIGHT:
		return
	pos.x = terrain.cup_x - signf(vel.x)
	vel.x *= -PIN_REBOUND
	vel.y *= PIN_DROP_DAMPING
	spin = 0.0
	pin_hit.emit(pos)


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
		if _skips_left > 0 and impact_speed > MIN_SKIP_SPEED:
			_skips_left -= 1
			vel = Vector2(vel.x * SKIP_KEEP, -absf(vel.y) * SKIP_KEEP)
			bounced.emit(pos, surface, impact_speed)
			return
		_enter_water()
		return

	var props: Dictionary = Surface.props(surface)
	var normal: Vector2 = terrain.normal(pos.x)
	var tangent: Vector2 = terrain.tangent(pos.x)
	var vn: float = vel.dot(normal)
	var vt: float = vel.dot(tangent)

	var new_vn: float = absf(vn) * float(props["restitution"]) * bounce_scale
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
	var friction: float = float(Surface.props(surface)["roll_friction"]) * roll_scale
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
	# Anything that touches a rolling ball knocks it off its roll.
	if _interact_with_obstacles(dt):
		state = State.AIRBORNE


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
