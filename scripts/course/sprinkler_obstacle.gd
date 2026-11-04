class_name SprinklerObstacle
extends Obstacle
## Turns on and off. While on, its jet pushes the ball along the spray and out to one side.
## Rotation tilts the jet, in degrees from straight up.

const HALF_WIDTH := 7.0
const LIFT := 500.0
const SIDE_PUSH := 120.0

var x: float
var ground: float
var height: float
var rotation_deg: float
var on_time: float
var off_time: float
var direction: Vector2
var _clock: float


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "sprinkler"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	height = float(entry.get("height", 70.0))
	rotation_deg = float(entry.get("rotation", 0.0))
	on_time = float(entry.get("on_time", 2.5))
	off_time = float(entry.get("off_time", 2.0))
	_clock = float(entry.get("offset", 0.0))
	direction = Vector2.UP.rotated(deg_to_rad(rotation_deg))


func tick(dt: float) -> void:
	_clock = fmod(_clock + dt, on_time + off_time)


func is_on() -> bool:
	return _clock < on_time


func base() -> Vector2:
	return Vector2(x, ground)


func interact(ball: BallSim, dt: float) -> bool:
	if ball.ignore_moving or not is_on():
		return false
	var offset: Vector2 = ball.pos - base()
	var across: Vector2 = direction.orthogonal()
	var along: float = offset.dot(direction)
	var side: float = offset.dot(across)
	if along < 0.0 or along > height or absf(side) > HALF_WIDTH:
		return false
	ball.vel += direction * LIFT * dt
	ball.vel += across * (1.0 if side >= 0.0 else -1.0) * SIDE_PUSH * dt
	return true
