class_name TreeObstacle
extends Obstacle
## A solid trunk that bounces the ball, under leaves that slow it down.

const VARIANTS := 3
const TRUNK_HEIGHT := 24.0
const TRUNK_RADIUS := 2.0
const TRUNK_BOUNCE := 0.4
## Speed lost per second inside the leaves.
const LEAF_DRAG := 6.0

var x: float
var variant: int
var ground: float
var canopy_center: Vector2
var canopy_radius: float


func _init(terrain: Terrain, p_x: float, p_variant: int) -> void:
	kind = "tree"
	x = p_x
	variant = p_variant
	ground = terrain.ground_y(x)
	# These match the drawing in TreeView.
	var height: float = float(sprite_height(variant))
	canopy_center = Vector2(x, ground + 3.0 - height + (height - 18.0) / 2.0)
	canopy_radius = 20.0 + 2.0 * float(variant)


static func sprite_width(p_variant: int) -> int:
	return 44 + p_variant * 6


static func sprite_height(p_variant: int) -> int:
	return 62 + p_variant * 8


func interact(ball: BallSim, dt: float) -> bool:
	var hit_trunk: bool = false
	if absf(ball.launch_x - x) > Obstacle.LAUNCH_GRACE:
		var trunk_top := Vector2(x, ground - TRUNK_HEIGHT)
		hit_trunk = Obstacle.hit_capsule(
				ball, Vector2(x, ground), trunk_top, TRUNK_RADIUS, TRUNK_BOUNCE)
	var in_leaves: bool = ball.pos.distance_to(canopy_center) < canopy_radius
	if in_leaves:
		ball.vel *= exp(-LEAF_DRAG * dt)
	return hit_trunk or in_leaves
