class_name FrogObstacle
extends Obstacle
## A frog hopping back and forth along the ground. Knocks away a ball that hits it, low down
## where the geese can't reach. Hits a ball once per shot, like other moving hazards.

const RADIUS := 5.0
const BOUNCE := 0.55
const HOP_TIME := 0.42
const REST_TIME := 0.5
const HOP_HEIGHT := 13.0
## A knocked ball gets a little pop upward, so it never just rolls along with the frog.
const KICK_UP := 45.0

var terrain: Terrain
var from_x: float
var to_x: float
var speed: float
var x: float
var direction: float = 1.0
var clock: float = 0.0


func _init(p_terrain: Terrain, entry: Dictionary) -> void:
	kind = "frog"
	terrain = p_terrain
	from_x = float(entry["from"])
	to_x = float(entry["to"])
	speed = float(entry.get("speed", 70.0))
	x = clampf(float(entry.get("start", from_x)), from_x, to_x)
	# Different frogs on a hole don't hop in step.
	clock = fmod(x * 0.017, HOP_TIME + REST_TIME)


func tick(dt: float) -> void:
	clock = fmod(clock + dt, HOP_TIME + REST_TIME)
	if not is_hopping():
		return
	x += direction * speed * dt
	if x >= to_x:
		x = to_x
		direction = -1.0
	elif x <= from_x:
		x = from_x
		direction = 1.0


func is_hopping() -> bool:
	return clock < HOP_TIME


func hits_once_per_shot() -> bool:
	return true


func center() -> Vector2:
	var lift: float = sin(clock / HOP_TIME * PI) * HOP_HEIGHT if is_hopping() else 0.0
	return Vector2(x, terrain.ground_y(x) - RADIUS - lift)


func interact(ball: BallSim, _dt: float) -> bool:
	if ball.ignore_moving:
		return false
	var at: Vector2 = center()
	var moving: float = direction * speed if is_hopping() else 0.0
	return Obstacle.hit_capsule(ball, at, at, RADIUS, BOUNCE, Vector2(moving, -KICK_UP))
