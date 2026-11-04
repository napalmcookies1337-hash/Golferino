class_name WindmillObstacle
extends Obstacle
## A solid tower with four turning blades. Fly over it, or time a shot past the blades.

const TOWER_HEIGHT := 46.0
const TOWER_RADIUS := 7.0
const TOWER_BOUNCE := 0.35
const BLADE_LENGTH := 30.0
const BLADE_RADIUS := 1.5
const BLADE_BOUNCE := 0.5
const BLADES := 4

var x: float
var ground: float
var angle: float = 0.0
## Radians per second.
var turn_speed: float


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "windmill"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	turn_speed = float(entry.get("turn_speed", 1.2))


func tick(dt: float) -> void:
	angle = fposmod(angle + turn_speed * dt, TAU)


func hub() -> Vector2:
	return Vector2(x, ground - TOWER_HEIGHT)


func blade_tip(index: int) -> Vector2:
	var blade_angle: float = angle + float(index) * TAU / float(BLADES)
	return hub() + Vector2(cos(blade_angle), sin(blade_angle)) * BLADE_LENGTH


func interact(ball: BallSim, _dt: float) -> bool:
	var touched: bool = false
	if absf(ball.launch_x - x) > Obstacle.LAUNCH_GRACE:
		touched = Obstacle.hit_capsule(ball, Vector2(x, ground), hub(), TOWER_RADIUS, TOWER_BOUNCE)
	if ball.ignore_moving:
		return touched
	for i in BLADES:
		# A blade moves faster toward its tip, so the hit takes the speed at that point.
		var arm: Vector2 = ball.pos - hub()
		var blade_velocity: Vector2 = Vector2(-arm.y, arm.x) * turn_speed
		if Obstacle.hit_capsule(ball, hub(), blade_tip(i), BLADE_RADIUS, BLADE_BOUNCE, blade_velocity):
			touched = true
	return touched
