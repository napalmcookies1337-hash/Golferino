class_name ObstacleView
extends Node2D
## Draws every moving hazard. Trees are drawn by TreeView.

const OUTLINE := Color("20202e")

var game: HoleGame
var _time: float = 0.0


func setup(p_game: HoleGame) -> void:
	game = p_game


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for obstacle in game.obstacles:
		if obstacle is CartObstacle:
			_draw_cart(obstacle)
		elif obstacle is WindmillObstacle:
			_draw_windmill(obstacle)
		elif obstacle is SprinklerObstacle:
			_draw_sprinkler(obstacle)
		elif obstacle is GooseObstacle:
			_draw_goose(obstacle)


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
	var x: float = round(mill.x)
	var ground: float = round(mill.ground)
	var hub: Vector2 = mill.hub().round()
	# A tapered tower, slightly wider at the base.
	for row in int(WindmillObstacle.TOWER_HEIGHT) + 2:
		var y: float = ground - float(row) + 2.0
		var half: float = round(lerpf(9.0, 5.0, float(row) / WindmillObstacle.TOWER_HEIGHT))
		draw_rect(Rect2(x - half - 1, y, half * 2 + 3, 1), OUTLINE)
		var brick: bool = row % 6 == 0
		draw_rect(Rect2(x - half, y, half * 2 + 1, 1), Color("c9b08a") if brick else Color("e3cfa4"))
		draw_rect(Rect2(x + half - 2, y, 2, 1), Color("b39a78"))
	draw_rect(Rect2(x - 3, ground - 10, 7, 11), Color("5d3f2b"))
	var roof := PackedVector2Array([hub + Vector2(-8, -1), hub + Vector2(8, -1), hub + Vector2(0, -11)])
	draw_colored_polygon(roof, Color("a92b35"))

	for i in WindmillObstacle.BLADES:
		var tip: Vector2 = mill.blade_tip(i).round()
		draw_line(hub, tip, OUTLINE, 4.0)
		draw_line(hub, tip, Color("f7f4e6"), 2.0)
	draw_circle(hub, 2.5, OUTLINE)


func _draw_sprinkler(sprinkler: SprinklerObstacle) -> void:
	var x: float = round(sprinkler.x)
	var ground: float = round(sprinkler.ground)
	draw_rect(Rect2(x - 2, ground - 4, 5, 5), OUTLINE)
	draw_rect(Rect2(x - 1, ground - 3, 3, 3), Color("8d97a8"))
	if not sprinkler.is_on():
		return
	var droplets: int = 26
	for i in droplets:
		var along: float = fmod(float(i) / float(droplets) + _time * 0.9, 1.0)
		var y: float = ground - 4.0 - along * sprinkler.height
		var spread: float = sin(float(i) * 2.399) * SprinklerObstacle.HALF_WIDTH * minf(along * 2.5, 1.0)
		var color: Color = Color("d8f4ff") if i % 2 == 0 else Color("7fc6ec")
		draw_rect(Rect2(round(x + spread), round(y), 2, 2), color)


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
