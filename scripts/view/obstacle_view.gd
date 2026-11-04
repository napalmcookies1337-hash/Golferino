class_name ObstacleView
extends Node2D
## Draws every hazard.

const OUTLINE := Color("20202e")
const PAD_HELPS := Color("5fd068")
const PAD_NEUTRAL := Color("ffe25a")
const PAD_HURTS := Color("f0703a")

var obstacles: Array[Obstacle] = []
var _time: float = 0.0


func setup(p_obstacles: Array[Obstacle]) -> void:
	obstacles = p_obstacles


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for obstacle in obstacles:
		if obstacle is CartObstacle:
			_draw_cart(obstacle)
		elif obstacle is WindmillObstacle:
			_draw_windmill(obstacle)
		elif obstacle is SprinklerObstacle:
			_draw_sprinkler(obstacle)
		elif obstacle is GooseObstacle:
			_draw_goose(obstacle)
		elif obstacle is BouncePadObstacle:
			_draw_pad(obstacle)


func _draw_pad(pad: BouncePadObstacle) -> void:
	# The spring face's colour and arrows say which way it fires: green toward the cup,
	# orange away, yellow straight up.
	var color: Color = PAD_NEUTRAL
	if not pad.is_flat():
		color = PAD_HELPS if pad.faces_cup() else PAD_HURTS

	var half_length: float = BouncePadObstacle.HALF_LENGTH
	var half_thick: float = BouncePadObstacle.HALF_THICKNESS
	draw_set_transform(pad.center, deg_to_rad(pad.rotation_deg))
	# Local axes: +x along the pad, -y out of the spring face.
	draw_rect(Rect2(-half_length - 1.0, -half_thick - 1.0, half_length * 2.0 + 2.0, half_thick * 2.0 + 2.0), OUTLINE)
	draw_rect(Rect2(-half_length, -half_thick, half_length * 2.0, half_thick * 2.0), Color("4a4a5e"))
	# The spring strip sits proud of the body, and dips when it fires.
	var strip_y: float = -half_thick + pad.squash * 1.5
	draw_rect(Rect2(-half_length, strip_y, half_length * 2.0, 2.0), color)
	draw_set_transform(Vector2.ZERO)

	var bob: float = 3.0 + sin(_time * 4.0) * 1.5 + pad.squash * 6.0
	for row in 2:
		_draw_chevron(pad.center + pad.normal * (6.0 + bob + float(row) * 5.0), pad.normal, color)


func _draw_chevron(at: Vector2, direction: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x) * 4.0
	var tip: Vector2 = (at + direction * 3.0).round()
	var left: Vector2 = (at - side).round()
	var right: Vector2 = (at + side).round()
	draw_line(left, tip, OUTLINE, 3.0)
	draw_line(right, tip, OUTLINE, 3.0)
	draw_line(left, tip, color, 1.0)
	draw_line(right, tip, color, 1.0)


func _draw_cart(cart: CartObstacle) -> void:
	var at: Vector2 = (cart.center() + Vector2(0, -2.5)).round()
	var d: float = cart.direction
	draw_rect(Rect2(at.x - 15, at.y - 2, 30, 9), OUTLINE)
	draw_rect(Rect2(at.x - 14, at.y - 1, 28, 7), Color("f7f4e6"))
	draw_rect(Rect2(at.x - 14, at.y + 3, 28, 2), Color("2b8c8c"))
	draw_rect(Rect2(at.x - 12, at.y - 13, 24, 2), Color("2b8c8c"))
	draw_rect(Rect2(at.x - 11 * d - 1, at.y - 11, 2, 10), OUTLINE)
	draw_rect(Rect2(at.x + 10 * d - 1, at.y - 11, 2, 10), OUTLINE)
	# The driver, facing the way the cart is going.
	draw_rect(Rect2(at.x - 3, at.y - 6, 5, 5), Color("e8c34a"))
	draw_circle(at + Vector2(0, -8), 2.5, Color("f0b98a"))
	for side: float in [-9.0, 9.0]:
		draw_circle(at + Vector2(side, 7), 3.5, OUTLINE)
		draw_rect(Rect2(at.x + side - 1, at.y + 6, 2, 2), Color("8d97a8"))


func _draw_windmill(mill: WindmillObstacle) -> void:
	var hub: Vector2 = mill.hub().round()
	# A tapered tower, slightly wider at the base, drawn upright then tilted as a whole.
	draw_set_transform(mill.base().round(), deg_to_rad(mill.rotation_deg))
	var top: float = -WindmillObstacle.TOWER_HEIGHT
	for row in int(WindmillObstacle.TOWER_HEIGHT) + 2:
		var y: float = 2.0 - float(row)
		var half: float = round(lerpf(9.0, 5.0, float(row) / WindmillObstacle.TOWER_HEIGHT))
		draw_rect(Rect2(-half - 1, y, half * 2 + 3, 1), OUTLINE)
		var brick: bool = row % 6 == 0
		draw_rect(Rect2(-half, y, half * 2 + 1, 1), Color("c9b08a") if brick else Color("e3cfa4"))
		draw_rect(Rect2(half - 2, y, 2, 1), Color("b39a78"))
	draw_rect(Rect2(-3, -10, 7, 11), Color("5d3f2b"))
	var roof := PackedVector2Array([Vector2(-8, top - 1), Vector2(8, top - 1), Vector2(0, top - 11)])
	draw_colored_polygon(roof, Color("a92b35"))
	draw_set_transform(Vector2.ZERO)

	for i in WindmillObstacle.BLADES:
		var tip: Vector2 = mill.blade_tip(i).round()
		draw_line(hub, tip, OUTLINE, 4.0)
		draw_line(hub, tip, Color("f7f4e6"), 2.0)
	draw_circle(hub, 2.5, OUTLINE)


func _draw_sprinkler(sprinkler: SprinklerObstacle) -> void:
	var base: Vector2 = sprinkler.base().round()
	draw_rect(Rect2(base.x - 2, base.y - 4, 5, 5), OUTLINE)
	draw_rect(Rect2(base.x - 1, base.y - 3, 3, 3), Color("8d97a8"))
	if not sprinkler.is_on():
		return
	var across: Vector2 = sprinkler.direction.orthogonal()
	var droplets: int = 26
	for i in droplets:
		var along: float = fmod(float(i) / float(droplets) + _time * 0.9, 1.0)
		var spread: float = sin(float(i) * 2.399) * SprinklerObstacle.HALF_WIDTH * minf(along * 2.5, 1.0)
		var at: Vector2 = base + sprinkler.direction * (4.0 + along * sprinkler.height) + across * spread
		var color: Color = Color("d8f4ff") if i % 2 == 0 else Color("7fc6ec")
		draw_rect(Rect2(at.round(), Vector2(2, 2)), color)


func _draw_goose(goose: GooseObstacle) -> void:
	var at: Vector2 = goose.center().round()
	var d: float = goose.direction
	var flap: float = sin(goose.clock * 9.0)
	# Body, neck and head, drawn outline first.
	draw_rect(Rect2(at.x - 6, at.y - 3, 13, 7), OUTLINE)
	draw_rect(Rect2(at.x - 5, at.y - 2, 11, 5), Color("f7f4e6"))
	draw_line(at + Vector2(4 * d, -1), at + Vector2(9 * d, -6), OUTLINE, 3.0)
	draw_line(at + Vector2(4 * d, -1), at + Vector2(9 * d, -6), Color("2f2f3d"), 1.0)
	draw_rect(Rect2(at.x + 9 * d - 1, at.y - 7, 3, 3), Color("2f2f3d"))
	draw_rect(Rect2(at.x + 11 * d - (1 if d < 0 else 0), at.y - 6, 2, 1), Color("e8a23a"))
	# The wing beats up and down.
	var wing_y: float = round(flap * 6.0)
	var wing := PackedVector2Array([
		at + Vector2(-3, 0), at + Vector2(3, 0), at + Vector2(-5 * d, wing_y - 2.0)])
	draw_colored_polygon(wing, Color("c9d2de"))
