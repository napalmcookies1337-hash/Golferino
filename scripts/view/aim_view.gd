class_name AimView
extends Node2D
## Dotted start of the shot's path, and an arrow showing the full-power landing.

const ARC_SHARE := 0.45

var game: HoleGame
var _time: float = 0.0


func setup(p_game: HoleGame) -> void:
	game = p_game


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.SWING:
		return
	var preview: Dictionary = game.preview()
	var path: PackedVector2Array = preview["path"]
	if path.is_empty():
		return

	var is_putt: bool = game.current_club().is_putter
	var count: int = path.size() if is_putt else int(float(path.size()) * ARC_SHARE)
	# A dark backing keeps the dots readable against bright sky.
	for i in count:
		var point: Vector2 = path[i].round()
		draw_rect(Rect2(point.x - 1, point.y - 1, 4, 4), Color(0.1, 0.13, 0.25, 0.75))
		draw_rect(Rect2(point.x, point.y, 2, 2), Color("ffe25a"))

	var landing: Vector2 = Vector2(preview["landing"]).round()
	var bob: float = round(sin(_time * 5.0) * 1.5)
	_draw_marker(landing + Vector2(0, -7.0 + bob))


func _draw_marker(at: Vector2) -> void:
	for row in 5:
		var half: int = 4 - row
		draw_rect(Rect2(at.x - half - 1, at.y + row - 1, half * 2 + 3, 2), Color("20202e"))
	for row in 4:
		var half: int = 3 - row
		draw_rect(Rect2(at.x - half, at.y + row, half * 2 + 1, 1), Color("ffe25a"))
