class_name CartObstacle
extends Obstacle
## A golf cart patrolling back and forth along the ground. It's bigger than the golfer,
## as a real one would be. Its body and roof are solid, and its open cab lets a ball through.

## The drawn size, measured from the ground up. The golfer stands about 32 tall.
const DRAWN_HEIGHT := 46.0
const DRAWN_HALF_WIDTH := 31.0

const HALF_LENGTH := 20.0
## With this radius and ride height, the body reaches the ground and blocks rolling balls.
const RADIUS := 11.0
const RIDE_HEIGHT := 11.0
const ROOF_HALF_LENGTH := 27.0
const ROOF_RADIUS := 2.0
## From the body's center up to the roof.
const ROOF_RISE := 33.0
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
	var moving := Vector2(direction * speed, 0)
	var along := Vector2(HALF_LENGTH, 0)
	if Obstacle.hit_capsule(ball, mid - along, mid + along, RADIUS, BOUNCE, moving):
		return true
	var roof: Vector2 = mid + Vector2(0, -ROOF_RISE)
	var roof_along := Vector2(ROOF_HALF_LENGTH, 0)
	return Obstacle.hit_capsule(ball, roof - roof_along, roof + roof_along, ROOF_RADIUS, BOUNCE, moving)
