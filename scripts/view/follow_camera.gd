class_name FollowCamera
extends Camera2D
## Frames the shot while aiming, allows free scrolling before the swing, then chases
## the ball with some lead so you can see where it's heading.

const HALF_WIDTH := 320.0
const AIM_LEAD := 120.0
const LOOK_SPEED := 420.0
## Holding look speeds up to this, so long holes don't take ages to scroll.
const LOOK_MAX_SPEED := 1100.0
const LOOK_RAMP_TIME := 1.0
const AIM_SMOOTH := 5.0
const CHASE_SMOOTH := 4.0
const CHASE_LEAD_X := 0.35
const CHASE_LEAD_Y := 0.2
const HEADROOM := 55.0

var game: HoleGame
var look_offset: float = 0.0
var _placed: bool = false
var _look_held: float = 0.0


func setup(p_game: HoleGame) -> void:
	game = p_game


func _ready() -> void:
	limit_left = 0
	limit_right = game.terrain.length
	limit_bottom = Terrain.WORLD_HEIGHT
	limit_top = -400
	make_current()


func is_free_looking() -> bool:
	return absf(look_offset) > 1.0


func _process(delta: float) -> void:
	var target: Vector2 = _target_position(delta)
	target.x = clampf(target.x, HALF_WIDTH, float(game.terrain.length) - HALF_WIDTH)
	if not _placed:
		position = target
		_placed = true
		return
	var moving: bool = game.phase == HoleGame.Phase.BALL_MOVING
	var rate: float = CHASE_SMOOTH if moving else AIM_SMOOTH
	if is_free_looking():
		rate = 12.0
	position = position.lerp(target, 1.0 - exp(-rate * delta))


func _target_position(delta: float) -> Vector2:
	var ball: BallSim = game.ball
	if game.phase == HoleGame.Phase.BALL_MOVING:
		look_offset = 0.0
		return ball.pos + Vector2(ball.vel.x * CHASE_LEAD_X, ball.vel.y * CHASE_LEAD_Y - HEADROOM)

	# Clamp the resting framing first, so being near a course edge doesn't count as looking.
	var max_x: float = float(game.terrain.length) - HALF_WIDTH
	var target_x: float = clampf(ball.pos.x + float(game.facing) * AIM_LEAD, HALF_WIDTH, max_x)
	if game.phase == HoleGame.Phase.AIM:
		var look_input: float = Input.get_axis("look_left", "look_right")
		_look_held = _look_held + delta if look_input != 0.0 else 0.0
		var ramp: float = clampf(_look_held / LOOK_RAMP_TIME, 0.0, 1.0)
		look_offset += look_input * lerpf(LOOK_SPEED, LOOK_MAX_SPEED, ramp) * delta
		look_offset = clampf(look_offset, HALF_WIDTH - target_x, max_x - target_x)
	else:
		look_offset = 0.0
	target_x += look_offset
	# Follows the ground while scrolling, so hills stay in frame.
	return Vector2(target_x, game.terrain.ground_y(target_x) - HEADROOM - 4.0)
