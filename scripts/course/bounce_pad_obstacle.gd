class_name BouncePadObstacle
extends Obstacle
## A rectangular pad that can sit on the ground or float in the air, at any angle. One long
## side is a spring that fires the ball straight out. The back and ends are ordinary solid
## bounces. Rotation is in degrees: 0 faces straight up, positive tilts the face toward +x.

const HALF_LENGTH := 14.0
const HALF_THICKNESS := 3.0
const SOLID_BOUNCE := 0.35
## The ball always leaves at least this fast out of the spring face, px/s.
const DEFAULT_POWER := 230.0
const SIDE_SPEED_KEPT := 0.85
## Each repeat bounce in one shot is weaker, then the spring stops firing, so a ball
## dropping straight down can't bounce on it forever.
const REPEAT_POWER := 0.6
const MAX_USES_PER_SHOT := 3
## After this many contacts in one shot, the ball passes through. Stops a ball on a slope
## from rattling against a pad's back until the safety timeout.
const MAX_TOUCHES_PER_SHOT := 8
## A ball starting a shot this close to the pad's center isn't affected by it.
const START_GRACE := 26.0
const SQUASH_TIME := 0.18

var x: float
var rotation_deg: float
var power: float
var normal: Vector2
var tangent: Vector2
var center: Vector2
var cup_x: float
## 1 just after firing, falling to 0. Drawing only.
var squash: float = 0.0


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "pad"
	x = float(entry["x"])
	rotation_deg = float(entry.get("rotation", 0.0))
	power = float(entry.get("power", DEFAULT_POWER))
	cup_x = terrain.cup_x
	var rad: float = deg_to_rad(rotation_deg)
	normal = Vector2(sin(rad), -cos(rad))
	tangent = Vector2(cos(rad), sin(rad))
	if entry.has("y"):
		center = Vector2(x, float(entry["y"]))
	else:
		center = Vector2(x, resting_y(terrain, x, rotation_deg))


## The center height that seats a pad in the ground. An angled pad sinks around its middle
## rather than standing on one corner, which would put its raised end in the way of shots.
static func resting_y(terrain: Terrain, at_x: float, degrees: float) -> float:
	return terrain.ground_y(at_x) - HALF_THICKNESS * absf(cos(deg_to_rad(degrees)))


func tick(dt: float) -> void:
	squash = maxf(squash - dt / SQUASH_TIME, 0.0)


func is_flat() -> bool:
	return is_zero_approx(rotation_deg)


func faces_cup() -> bool:
	return not is_flat() and signf(normal.x) == signf(cup_x - x)


func interact(ball: BallSim, _dt: float) -> bool:
	if Vector2(ball.launch_x, ball.launch_y).distance_to(center) < START_GRACE:
		return false
	var touches: int = ball.pad_touches.get(self, 0)
	if touches >= MAX_TOUCHES_PER_SHOT:
		return false

	# Works in the pad's own axes: along it, and out from its spring face.
	var offset: Vector2 = ball.pos - center
	var along: float = offset.dot(tangent)
	var out: float = offset.dot(normal)
	var near_along: float = clampf(along, -HALF_LENGTH, HALF_LENGTH)
	var near_out: float = clampf(out, -HALF_THICKNESS, HALF_THICKNESS)
	var inside: bool = near_along == along and near_out == out
	if inside:
		# Pushes out through the nearest side.
		var to_face: float = HALF_THICKNESS - absf(out)
		var to_end: float = HALF_LENGTH - absf(along)
		if to_face < to_end:
			near_out = HALF_THICKNESS * (1.0 if out >= 0.0 else -1.0)
		else:
			near_along = HALF_LENGTH * (1.0 if along >= 0.0 else -1.0)

	var closest: Vector2 = center + tangent * near_along + normal * near_out
	var gap: Vector2 = ball.pos - closest
	var distance: float = gap.length()
	if not inside and distance >= BallSim.RADIUS:
		return false

	var contact: Vector2
	if inside or distance < 0.001:
		contact = (closest - center).normalized() if not inside else _side_normal(near_along, near_out)
	else:
		contact = gap / distance

	ball.pad_touches[self] = touches + 1
	var uses: int = ball.pad_uses.get(self, 0)
	# The spring covers the pad's upper half, ends included. A helpful pad's raised end
	# faces incoming shots, so clipping it mustn't bounce the ball backward.
	var on_spring: bool = out > 0.0 and uses < MAX_USES_PER_SHOT
	ball.pos = closest + contact * BallSim.RADIUS
	var into: float = ball.vel.dot(contact)
	if on_spring:
		if into < 0.0 or ball.state == BallSim.State.ROLLING:
			_fire(ball, uses)
	elif into < 0.0:
		ball.vel -= contact * into * (1.0 + SOLID_BOUNCE)
		ball.spin = 0.0
	return true


func _fire(ball: BallSim, uses: int) -> void:
	var speed_in: float = absf(ball.vel.dot(normal))
	var out_speed: float = maxf(speed_in, power) * pow(REPEAT_POWER, float(uses))
	ball.vel = tangent * ball.vel.dot(tangent) * SIDE_SPEED_KEPT + normal * out_speed
	ball.spin = 0.0
	ball.pad_uses[self] = uses + 1
	# Previews share this object, and must not make it twitch on screen.
	if not ball.ignore_moving:
		squash = 1.0


func _side_normal(near_along: float, near_out: float) -> Vector2:
	if absf(near_out) >= HALF_THICKNESS:
		return normal * signf(near_out)
	return tangent * signf(near_along)
