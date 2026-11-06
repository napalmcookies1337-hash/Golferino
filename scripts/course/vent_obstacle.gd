class_name VentObstacle
extends Obstacle
## A crack in the swamp that bubbles, then bursts. A ball in the burst is thrown upward. Which way
## it drifts changes from burst to burst and looks random, but it's a fixed pattern with no dice,
## and always lands within a fair distance. Bubbles give fair warning before each burst.

const HALF_WIDTH := 9.0
const LIFT := 165.0
## How far each burst pushes a ball sideways, in order.
const DRIFTS: Array[float] = [-55.0, 30.0, 70.0, -25.0, 45.0, -70.0, 15.0, 60.0]
const WARNING_TIME := 0.9

enum Stage { QUIET, WARNING, BURST }

var x: float
var ground: float
var height: float
var quiet_time: float
var burst_time: float
var _clock: float
var _bursts: int = 0
# The burst each ball was last thrown by, by id so this doesn't keep the ball alive.
var _thrown: Dictionary = {}


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "vent"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	height = float(entry.get("height", 85.0))
	quiet_time = float(entry.get("quiet_time", 2.6))
	burst_time = float(entry.get("burst_time", 1.1))
	_clock = float(entry.get("offset", 0.0))
	# Where in the pattern it starts depends on where it is, so vents don't match each other.
	_bursts = int(x) / 7


func tick(dt: float) -> void:
	var cycle: float = quiet_time + WARNING_TIME + burst_time
	var next: float = _clock + dt
	if next >= cycle:
		_bursts += 1
	_clock = fmod(next, cycle)


func stage() -> int:
	if _clock < quiet_time:
		return Stage.QUIET
	return Stage.WARNING if _clock < quiet_time + WARNING_TIME else Stage.BURST


func base() -> Vector2:
	return Vector2(x, ground)


## How far through the burst it is, or through the warning while that's on, from 0 to 1.
func progress() -> float:
	if stage() == Stage.WARNING:
		return (_clock - quiet_time) / WARNING_TIME
	if stage() == Stage.BURST:
		return (_clock - quiet_time - WARNING_TIME) / maxf(burst_time, 0.001)
	return 0.0


func drift() -> float:
	return DRIFTS[_bursts % DRIFTS.size()]


func interact(ball: BallSim, _dt: float) -> bool:
	if ball.ignore_moving or stage() != Stage.BURST or absf(ball.launch_x - x) < Obstacle.LAUNCH_GRACE:
		return false
	var offset: Vector2 = ball.pos - base()
	if absf(offset.x) > HALF_WIDTH or offset.y < -height or offset.y > BallSim.RADIUS:
		return false
	var ball_id: int = ball.get_instance_id()
	if int(_thrown.get(ball_id, -1)) != _bursts:
		_thrown[ball_id] = _bursts
		var strength: float = sqrt(ball.knock_scale)
		ball.vel = Vector2(ball.vel.x * 0.4 + drift() * strength, -LIFT * strength)
		ball.spin = 0.0
	return true
