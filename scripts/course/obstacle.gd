class_name Obstacle
extends RefCounted
## Anything on a hole that affects the ball besides the ground. To add a new hazard,
## add a subclass and an entry in build_all, then give it a drawing in ObstacleView.

## Rules-only sims (the aim preview) set ball.ignore_moving, so moving parts should
## skip themselves when it's on: their positions at impact can't be known in advance.

## A ball that starts a shot this close to a solid post passes it. Otherwise a ball
## resting against one could only ever bounce back into the same spot.
const LAUNCH_GRACE := 14.0

var kind: String = ""


func tick(_dt: float) -> void:
	pass


## True for things that move along a path and could otherwise push a ball with them.
func hits_once_per_shot() -> bool:
	return false


## Applies this obstacle to a moving ball. Returns true while the ball is touching it.
func interact(_ball: BallSim, _dt: float) -> bool:
	return false


static func build_all(hole: HoleData, terrain: Terrain) -> Array[Obstacle]:
	var result: Array[Obstacle] = []
	var index: int = 0
	for x: float in hole.tree_xs:
		result.append(TreeObstacle.new(terrain, x, index % TreeObstacle.VARIANTS))
		index += 1
	for entry: Dictionary in hole.obstacles:
		var obstacle: Obstacle = _build_one(entry, terrain)
		if obstacle != null:
			result.append(obstacle)
	return result


static func _build_one(entry: Dictionary, terrain: Terrain) -> Obstacle:
	match str(entry.get("kind", "")):
		"cart":
			return CartObstacle.new(terrain, entry)
		"windmill":
			return WindmillObstacle.new(terrain, entry)
		"sprinkler":
			return SprinklerObstacle.new(terrain, entry)
		"goose":
			return GooseObstacle.new(terrain, entry)
	push_error("Unknown obstacle kind: %s" % str(entry.get("kind", "")))
	return null


## Bounces the ball off a rounded bar from a to b. A circle is a bar with a == b.
static func hit_capsule(
		ball: BallSim, a: Vector2, b: Vector2, radius: float, restitution: float,
		surface_velocity: Vector2 = Vector2.ZERO
) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.pos, a, b)
	var offset: Vector2 = ball.pos - closest
	var distance: float = offset.length()
	var reach: float = radius + BallSim.RADIUS
	if distance >= reach:
		return false
	var normal: Vector2 = offset / distance if distance > 0.001 else Vector2.UP
	ball.pos = closest + normal * reach
	var relative: Vector2 = ball.vel - surface_velocity
	var into: float = relative.dot(normal)
	if into < 0.0:
		relative -= normal * into * (1.0 + restitution)
		ball.vel = relative + surface_velocity
		ball.spin = 0.0
	return true
