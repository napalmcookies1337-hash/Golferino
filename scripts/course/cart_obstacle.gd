class_name CartObstacle
extends Obstacle
## A golf cart patrolling back and forth along the ground.

const HALF_LENGTH := 8.0
## With this radius and ride height, the body reaches the ground and blocks rolling balls.
const RADIUS := 8.0
const RIDE_HEIGHT := 8.0
const BOUNCE := 0.55

var terrain: Terrain
var from_x: float
var to_x: float
var speed: float
var x: float
var direction: float = 1.0


func _init(p_terrain: Terrain, entry: Dictionary) -> void:
	kind = "cart"
	terrain = p_terrain
	from_x = float(entry["from"])
	to_x = float(entry["to"])
	speed = float(entry.get("speed", 45.0))
	x = from_x


func tick(dt: float) -> void:
	x += direction * speed * dt
	if x >= to_x:
		x = to_x
		direction = -1.0
	elif x <= from_x:
		x = from_x
		direction = 1.0


func hits_once_per_shot() -> bool:
	return true


func center() -> Vector2:
	return Vector2(x, terrain.ground_y(x) - RIDE_HEIGHT)


func interact(ball: BallSim, _dt: float) -> bool:
	if ball.ignore_moving:
		return false
	var mid: Vector2 = center()
	return Obstacle.hit_capsule(
			ball, mid - Vector2(HALF_LENGTH, 0), mid + Vector2(HALF_LENGTH, 0), RADIUS, BOUNCE,
			Vector2(direction * speed, 0))
