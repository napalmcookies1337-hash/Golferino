class_name WindmillObstacle
extends Obstacle
## A tower with four turning blades and a square door right through its base. Fly over
## it, or time a shot past the blades, which sweep down across the door.
## Rotation tilts the whole tower around its base, in degrees from straight up.

const TOWER_HEIGHT := 46.0
const TOWER_RADIUS := 7.0
const TOWER_BOUNCE := 0.35
## A ball can pass anywhere under this height. The door is drawn narrower than the tower,
## but its sides don't block the ball, so a low shot can't jam against them.
const DOOR_HEIGHT := 10.0
const DOOR_HALF_WIDTH := 5.0
## A flat bar across the top of the door, under the rounded tower.
const LINTEL_HALF_LENGTH := 6.0
const LINTEL_RADIUS := 2.0
## Long enough that a blade pointing down blocks a ball rolling along the ground.
const BLADE_LENGTH := 44.0
const BLADE_RADIUS := 1.5
const BLADE_BOUNCE := 0.5
const BLADES := 4

var x: float
var ground: float
var rotation_deg: float
var angle: float = 0.0
## Radians per second.
var turn_speed: float

var _hub: Vector2
var _tower_low: Vector2
var _lintel_a: Vector2
var _lintel_b: Vector2
var _up: Vector2
## Which side of the tower each ball was last on, while it's low and close to the door.
var _door_side: Dictionary = {}


func _init(terrain: Terrain, entry: Dictionary) -> void:
	kind = "windmill"
	x = float(entry["x"])
	ground = terrain.ground_y(x)
	rotation_deg = float(entry.get("rotation", 0.0))
	turn_speed = float(entry.get("turn_speed", 1.2))
	var up: Vector2 = Vector2.UP.rotated(deg_to_rad(rotation_deg))
	_up = up
	_hub = base() + up * TOWER_HEIGHT
	_tower_low = base() + up * (DOOR_HEIGHT + TOWER_RADIUS)
	var lintel: Vector2 = base() + up * (DOOR_HEIGHT + LINTEL_RADIUS)
	var along: Vector2 = up.orthogonal() * LINTEL_HALF_LENGTH
	_lintel_a = lintel - along
	_lintel_b = lintel + along


func tick(dt: float) -> void:
	angle = fposmod(angle + turn_speed * dt, TAU)


func base() -> Vector2:
	return Vector2(x, ground)


func hub() -> Vector2:
	return _hub


func blade_tip(index: int) -> Vector2:
	var blade_angle: float = angle + float(index) * TAU / float(BLADES)
	return _hub + Vector2(cos(blade_angle), sin(blade_angle)) * BLADE_LENGTH


func interact(ball: BallSim, _dt: float) -> bool:
	var touched: bool = false
	if absf(ball.launch_x - x) > Obstacle.LAUNCH_GRACE:
		touched = Obstacle.hit_capsule(ball, _tower_low, _hub, TOWER_RADIUS, TOWER_BOUNCE)
		if Obstacle.hit_capsule(ball, _lintel_a, _lintel_b, LINTEL_RADIUS, TOWER_BOUNCE):
			touched = true
	if ball.ignore_moving:
		return touched
	_check_door_pass(ball)
	for i in BLADES:
		# A blade moves faster toward its tip, so the hit takes the speed at that point.
		var arm: Vector2 = ball.pos - _hub
		var blade_velocity: Vector2 = Vector2(-arm.y, arm.x) * turn_speed
		if Obstacle.hit_capsule(ball, _hub, blade_tip(i), BLADE_RADIUS, BLADE_BOUNCE, blade_velocity):
			touched = true
	return touched


# A shot counts as through the door when it crosses from one side to the other down low,
# having started outside the tower.
func _check_door_pass(ball: BallSim) -> void:
	var offset: Vector2 = ball.pos - base()
	var height: float = offset.dot(_up)
	var along: float = offset.dot(_up.orthogonal())
	# By id, because holding the ball itself would keep it and this windmill alive forever.
	var ball_id: int = ball.get_instance_id()
	if height < 0.0 or height > DOOR_HEIGHT or absf(along) > DOOR_HALF_WIDTH * 3.0 or absf(ball.launch_x - x) < Obstacle.LAUNCH_GRACE:
		_door_side.erase(ball_id)
		return
	var side: float = signf(along)
	if _door_side.has(ball_id) and float(_door_side[ball_id]) != side and side != 0.0:
		ball.obstacle_hit.emit(ball.pos, "mill_door")
	if side != 0.0:
		_door_side[ball_id] = side
