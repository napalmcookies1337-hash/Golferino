class_name CoinObstacle
extends Obstacle
## A coin floating over the course. The ball picks it up in passing and carries on.

const PICKUP_RADIUS := 6.0

var at: Vector2
var collected: bool = false


func _init(_terrain: Terrain, entry: Dictionary) -> void:
	kind = "coin"
	at = Vector2(float(entry["x"]), float(entry["y"]))


func reset() -> void:
	collected = false


func interact(ball: BallSim, _dt: float) -> bool:
	if collected or not ball.collects_coins:
		return false
	if ball.pos.distance_to(at) < PICKUP_RADIUS + BallSim.RADIUS:
		collected = true
		ball.obstacle_hit.emit(at, kind)
	# Never counts as touching, because a coin mustn't knock a rolling ball off its roll.
	return false
