class_name BallView
extends Node2D
## The ball, with a fading trail while it flies.

const TRAIL_LENGTH := 16

var game: HoleGame
var ball: BallSim
var fill := Color("ffffff")
var shade := Color("c9d2de")
var _trail: Array[Vector2] = []


func setup(p_game: HoleGame) -> void:
	game = p_game
	ball = game.ball


## Draws another ball on the same hole, such as the rival's, in its own color.
func setup_other(p_game: HoleGame, p_ball: BallSim, p_fill: Color, p_shade: Color) -> void:
	game = p_game
	ball = p_ball
	fill = p_fill
	shade = p_shade


func _ready() -> void:
	game.phase_changed.connect(_on_phase_changed)


func _process(_delta: float) -> void:
	if ball.state == BallSim.State.AIRBORNE:
		_trail.append(ball.pos)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


func _on_phase_changed(_phase: int) -> void:
	if game.phase == HoleGame.Phase.AIM:
		_trail.clear()


func _draw() -> void:
	for i in _trail.size():
		var alpha: float = float(i + 1) / float(TRAIL_LENGTH) * 0.55
		var point: Vector2 = _trail[i].round()
		draw_rect(Rect2(point.x, point.y, 2, 2), Color(1.0, 1.0, 1.0, alpha))

	var state: int = ball.state
	if state == BallSim.State.HOLED or state == BallSim.State.IN_WATER:
		return
	var at: Vector2 = ball.pos.round()
	draw_rect(Rect2(at.x - 2, at.y - 3, 5, 7), Color("20202e"))
	draw_rect(Rect2(at.x - 3, at.y - 2, 7, 5), Color("20202e"))
	draw_rect(Rect2(at.x - 2, at.y - 2, 5, 5), fill)
	draw_rect(Rect2(at.x, at.y + 1, 2, 1), shade)
	draw_rect(Rect2(at.x + 1, at.y, 1, 1), shade)
