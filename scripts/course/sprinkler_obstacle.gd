class_name SprinklerObstacle
extends Obstacle
## Turns on and off. While on, its jet lifts the ball and pushes it out to one side.

const HALF_WIDTH := 7.0
const LIFT := 500.0
const SIDE_PUSH := 120.0

var x: float
var ground: float
var height: float
var on_time: float
var off_time: float
var _clock: float


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "sprinkler"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	height = float(entry.get("height", 70.0))
	on_time = float(entry.get("on_time", 2.5))
	off_time = float(entry.get("off_time", 2.0))
	_clock = float(entry.get("offset", 0.0))


func tick(dt: float) -> void:
	_clock = fmod(_clock + dt, on_time + off_time)


func is_on() -> bool:
	return _clock < on_time


func interact(ball: BallSim, dt: float) -> bool:
	if ball.ignore_moving or not is_on():
		return false
	var side: float = ball.pos.x - x
	if absf(side) > HALF_WIDTH or ball.pos.y > ground or ball.pos.y < ground - height:
		return false
	ball.vel.y -= LIFT * dt
	ball.vel.x += (1.0 if side >= 0.0 else -1.0) * SIDE_PUSH * dt
	return true
