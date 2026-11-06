class_name GatorObstacle
extends Obstacle
## A gator lying on the ground. It opens its jaws as a ball comes near, and a ball that gets too
## close is eaten: a penalty just like water. Then the gator flashes and is gone for the rest of
## the hole. It never moves, so the aim guide and the rival's planning both know to avoid it,
## though only a real ball can feed it. "side" is the way it faces: 1 toward +x, -1 toward -x.

const BODY_HALF := 18.0
const BODY_HEIGHT := 6.0
## How close a ball has to come to its body to be eaten.
const EAT_REACH := 13.0
## The jaws start to open from this far away.
const NOTICE_REACH := 85.0
const JAW_RATE := 7.0
const FLASH_TIME := 0.9

var x: float
var ground: float
var side: float
## How far open its jaws are, from 0 to 1.
var jaw: float = 0.0
var eaten: bool = false
## Counts down while it flashes after eating.
var flash: float = 0.0
var _wanted_jaw: float = 0.0


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "gator"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	side = 1.0 if float(entry.get("side", -1.0)) >= 0.0 else -1.0


func tick(dt: float) -> void:
	if eaten:
		flash = maxf(flash - dt, 0.0)
		return
	jaw = move_toward(jaw, _wanted_jaw, JAW_RATE * dt)
	_wanted_jaw = 0.0


func reset() -> void:
	eaten = false
	flash = 0.0
	jaw = 0.0
	_wanted_jaw = 0.0


func base() -> Vector2:
	return Vector2(x, ground)


func is_gone() -> bool:
	return eaten and flash <= 0.0


func interact(ball: BallSim, _dt: float) -> bool:
	# A ball struck from right beside it gets away, so it can't be eaten on the spot.
	if eaten or absf(ball.launch_x - x) < BODY_HALF + EAT_REACH:
		return false
	var spine_y: float = ground - BODY_HEIGHT
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.pos, Vector2(x - BODY_HALF, spine_y), Vector2(x + BODY_HALF, spine_y))
	var distance: float = closest.distance_to(ball.pos)
	if not ball.ignore_moving:
		_wanted_jaw = maxf(_wanted_jaw, clampf(1.0 - (distance - EAT_REACH) / (NOTICE_REACH - EAT_REACH), 0.0, 1.0))
	if distance >= EAT_REACH:
		return false
	if not ball.ignore_moving:
		eaten = true
		jaw = 1.0
		flash = FLASH_TIME
	ball.swallow("gator")
	return false
