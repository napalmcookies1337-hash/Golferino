class_name GooseObstacle
extends Obstacle
## A goose flying back and forth at a set height. Knocks the ball out of the air.

const RADIUS := 6.0
const BOUNCE := 0.35
const BOB_HEIGHT := 6.0
const BOB_RATE := 2.4

var from_x: float
var to_x: float
var speed: float
var base_y: float
var x: float
var direction: float = 1.0
var clock: float = 0.0


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "goose"
	from_x = float(entry["from"])
	to_x = float(entry["to"])
	speed = float(entry.get("speed", 60.0))
	x = clampf(float(entry.get("start", from_x)), from_x, to_x)
	base_y = terrain.ground_y(from_x) - float(entry.get("height", 80.0))
	clock = x * 0.1


func tick(dt: float) -> void:
	clock += dt
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
	return Vector2(x, base_y + sin(clock * BOB_RATE) * BOB_HEIGHT)


func interact(ball: BallSim, _dt: float) -> bool:
	if ball.ignore_moving:
		return false
	var at: Vector2 = center()
	return Obstacle.hit_capsule(ball, at, at, RADIUS, BOUNCE, Vector2(direction * speed, 0))
