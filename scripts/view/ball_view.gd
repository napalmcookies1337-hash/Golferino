class_name BallView
extends Node2D
## The ball, with a fading trail while it flies.

const TRAIL_LENGTH := 16
## A squashy ball flattens on landing, then stretches as it springs back up.
const SQUASH_TIME := 0.06
const STRETCH_TIME := 0.08
const MIN_SQUASH_SPEED := 40.0
const SHADOW_MIN_HEIGHT := 6.0
const SHADOW_MAX_HEIGHT := 140.0

var game: HoleGame
var ball: BallSim
var fill := Color("ffffff")
var shade := Color("c9d2de")
var _trail: Array[Vector2] = []
var _since_landing: float = 1.0


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
	ball.bounced.connect(_on_bounced)


func _process(delta: float) -> void:
	_since_landing += delta
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


func _on_bounced(_at: Vector2, _surface: int, impact_speed: float) -> void:
	if ball.squash_scale > 0.0 and impact_speed >= MIN_SQUASH_SPEED:
		_since_landing = 0.0


func _draw() -> void:
	var trail_color: Color = _trail_color()
	for i in _trail.size():
		trail_color.a = float(i + 1) / float(TRAIL_LENGTH) * 0.55
		var point: Vector2 = _trail[i].round()
		draw_rect(Rect2(point.x, point.y, 2, 2), trail_color)

	var state: int = ball.state
	if state == BallSim.State.HOLED or state == BallSim.State.IN_WATER:
		return
	var at: Vector2 = ball.pos.round()
	_draw_shadow(at)
	if _since_landing < SQUASH_TIME:
		_draw_squished(at + Vector2(0, 2), 9, 5)
		return
	if _since_landing < SQUASH_TIME + STRETCH_TIME:
		_draw_squished(at, 5, 9)
		return
	draw_rect(Rect2(at.x - 2, at.y - 3, 5, 7), Color("20202e"))
	draw_rect(Rect2(at.x - 3, at.y - 2, 7, 5), Color("20202e"))
	draw_rect(Rect2(at.x - 2, at.y - 2, 5, 5), fill)
	draw_rect(Rect2(at.x, at.y + 1, 2, 1), shade)
	draw_rect(Rect2(at.x + 1, at.y, 1, 1), shade)


# A full power shot leaves a golden streak.
func _trail_color() -> Color:
	if ball == game.ball and game.last_quality == "FULL POWER!!":
		return Color("ffd23c")
	return fill


# A dot on the ground under the ball in flight, so its height is easy to read.
func _draw_shadow(at: Vector2) -> void:
	if ball.state != BallSim.State.AIRBORNE or game.terrain.is_void(ball.pos.x):
		return
	var ground: float = game.terrain.ground_y(ball.pos.x)
	var height: float = ground - ball.pos.y
	if height < SHADOW_MIN_HEIGHT or height > SHADOW_MAX_HEIGHT:
		return
	var fade: float = 1.0 - height / SHADOW_MAX_HEIGHT
	var half: float = 1.0 + round(2.0 * fade)
	draw_rect(Rect2(at.x - half, round(ground), half * 2.0 + 1.0, 1), Color(0.05, 0.08, 0.1, 0.5 * fade))


# The ball at another shape, centered on a point, with its corners cut off.
func _draw_squished(center: Vector2, width: int, height: int) -> void:
	var left: float = center.x - float(width - 1) / 2.0
	var top: float = center.y - float(height - 1) / 2.0
	draw_rect(Rect2(left + 1, top, width - 2, height), Color("20202e"))
	draw_rect(Rect2(left, top + 1, width, height - 2), Color("20202e"))
	draw_rect(Rect2(left + 1, top + 1, width - 2, height - 2), fill)
	draw_rect(Rect2(left + 1, top + height - 2, width - 2, 1), shade)
