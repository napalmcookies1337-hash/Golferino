class_name BouncePadObstacle
extends Obstacle
## A springy plate on the ground, flat or angled. It fires the ball out along the way it
## faces. Lean is in degrees from straight up: positive faces +x, negative faces -x.

const HALF_LENGTH := 14.0
const PLATE_RADIUS := 1.5
## Height of the plate's low end above the ground.
const LOW_END_HEIGHT := 1.0
## The ball always leaves at least this fast along the way the pad faces, px/s.
const DEFAULT_POWER := 230.0
const SIDE_SPEED_KEPT := 0.85
## Each repeat bounce in one shot is weaker, then the pad stops firing, so a ball
## dropping straight down can't bounce on it forever.
const REPEAT_POWER := 0.6
const MAX_USES_PER_SHOT := 3
const SQUASH_TIME := 0.18

var x: float
var lean: float
var power: float
var ground: float
var normal: Vector2
var tangent: Vector2
var center: Vector2
var cup_x: float
## 1 just after firing, falling to 0. Drawing only.
var squash: float = 0.0


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "pad"
	x = float(entry["x"])
	lean = float(entry.get("lean", 0.0))
	power = float(entry.get("power", DEFAULT_POWER))
	ground = terrain.ground_y(x)
	cup_x = terrain.cup_x
	var rad: float = deg_to_rad(lean)
	normal = Vector2(sin(rad), -cos(rad))
	tangent = Vector2(cos(rad), sin(rad))
	center = Vector2(x, ground - LOW_END_HEIGHT - HALF_LENGTH * absf(sin(rad)))


func tick(dt: float) -> void:
	squash = maxf(squash - dt / SQUASH_TIME, 0.0)


func plate_a() -> Vector2:
	return center - tangent * HALF_LENGTH


func plate_b() -> Vector2:
	return center + tangent * HALF_LENGTH


## The raised end of the plate. A flat pad has none.
func high_end() -> Vector2:
	return plate_a() if plate_a().y < plate_b().y else plate_b()


func is_flat() -> bool:
	return is_zero_approx(lean)


func faces_cup() -> bool:
	return not is_flat() and signf(lean) == signf(cup_x - x)


func interact(ball: BallSim, _dt: float) -> bool:
	if absf(ball.launch_x - x) < HALF_LENGTH + Obstacle.LAUNCH_GRACE:
		return false
	var uses: int = ball.pad_uses.get(self, 0)
	if uses >= MAX_USES_PER_SHOT:
		return false

	# Touching any part fires the ball, including the wedge's back: that side faces an
	# approaching ball on a helpful pad, which would otherwise rarely reach the plate.
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.pos, plate_a(), plate_b())
	if not is_flat():
		var top: Vector2 = high_end()
		var on_back: Vector2 = Geometry2D.get_closest_point_to_segment(ball.pos, top, Vector2(top.x, ground))
		if ball.pos.distance_to(on_back) < ball.pos.distance_to(closest):
			closest = on_back
	var reach: float = PLATE_RADIUS + BallSim.RADIUS
	if ball.pos.distance_to(closest) >= reach:
		return false

	var along: float = ball.vel.dot(normal)
	var out_speed: float = maxf(absf(along), power) * pow(REPEAT_POWER, float(uses))
	# Already leaving this way, which covers the next few steps after firing.
	if along >= out_speed * 0.9:
		return true

	ball.vel = tangent * ball.vel.dot(tangent) * SIDE_SPEED_KEPT + normal * out_speed
	ball.spin = 0.0
	ball.pad_uses[self] = uses + 1
	# Previews share this object, and must not make it twitch on screen.
	if not ball.ignore_moving:
		squash = 1.0
	return true
