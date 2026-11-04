class_name GolferView
extends Node2D
## Draws the golfer from a few joints, so the backswing can follow the meter exactly.
## Drawn facing +x; hitting the other way mirrors the whole node.

const SHOULDER := Vector2(0, -21)
const ARM_LENGTH := 9.0
const REACH_HEIGHT := 20.0

const BACK_ANGLE := -130.0
const BACK_HINGE := -40.0
const FOLLOW_ANGLE := 125.0
const FOLLOW_HINGE := 35.0
const PUTT_BACK := -38.0
const PUTT_FOLLOW := 32.0

const OUTLINE := Color("20202e")
const SHOE := Color("3a2f33")
const SHAFT := Color("c7ccd6")
const CLUB_HEAD := Color("8d97a8")

var skin := Color("f0b98a")
var shirt := Color("e8584a")
var shirt_dark := Color("b83d3f")
var pants := Color("f2ead0")
var pants_dark := Color("c9bd9e")
var cap := Color("2b8c8c")
var game: HoleGame
var _arm_angle: float = 0.0
var _hinge: float = 0.0
var _phase_timer: float = 0.0
var _top_angle: float = 0.0
var _top_hinge: float = 0.0


func setup(p_game: HoleGame) -> void:
	game = p_game


func _ready() -> void:
	game.phase_changed.connect(_on_phase_changed)
	_stand_at_ball()


func _process(delta: float) -> void:
	_phase_timer += delta
	_update_pose()
	scale.x = float(_facing())
	queue_redraw()


func _update_pose() -> void:
	match game.phase:
		HoleGame.Phase.AIM:
			_stand_at_ball()
			_arm_angle = _address_angle()
			_hinge = 0.0
			# Rocks the putter in time with the moving meter.
			if game.meter.stage == SwingMeter.Stage.SWEEPING:
				_update_backswing()
		HoleGame.Phase.SWING:
			_update_backswing()
		HoleGame.Phase.DOWNSWING:
			var t: float = clampf(_phase_timer / HoleGame.DOWNSWING_TIME, 0.0, 1.0)
			var eased: float = t * t
			_arm_angle = lerpf(_top_angle, _address_angle(), eased)
			_hinge = lerpf(_top_hinge, 0.0, eased)
		HoleGame.Phase.BALL_MOVING, HoleGame.Phase.PENALTY, HoleGame.Phase.COMPLETE:
			_follow_through(_phase_timer)
		HoleGame.Phase.RIVAL_TURN, HoleGame.Phase.OUT_OF_STROKES:
			_stand_at_ball()
			_arm_angle = _address_angle()
			_hinge = 0.0


func _follow_through(time_since_strike: float) -> void:
	var t: float = clampf(time_since_strike / 0.22, 0.0, 1.0)
	var out: float = 1.0 - (1.0 - t) * (1.0 - t)
	_arm_angle = lerpf(_address_angle(), _follow_angle(), out)
	_hinge = lerpf(0.0, _follow_hinge(), out)


func _facing() -> int:
	return game.facing


func _ball_x() -> float:
	return game.ball.pos.x


func _club() -> ClubData:
	return game.current_club()


func _on_phase_changed(_phase: int) -> void:
	_phase_timer = 0.0
	if game.phase == HoleGame.Phase.DOWNSWING:
		_top_angle = _arm_angle
		_top_hinge = _hinge


func _update_backswing() -> void:
	# The club rises with the meter, and holds at the set power on the way back.
	var meter: SwingMeter = game.meter
	var following_cursor: bool = meter.stage == SwingMeter.Stage.RISING or meter.stage == SwingMeter.Stage.SWEEPING
	var amount: float = meter.cursor if following_cursor else meter.power
	var back: float = PUTT_BACK if _club().is_putter else BACK_ANGLE
	var hinge: float = 0.0 if _club().is_putter else BACK_HINGE
	_arm_angle = lerpf(_address_angle(), back, amount)
	_hinge = lerpf(0.0, hinge, amount)


func _follow_angle() -> float:
	return PUTT_FOLLOW if _club().is_putter else FOLLOW_ANGLE


func _follow_hinge() -> float:
	return 0.0 if _club().is_putter else FOLLOW_HINGE


func _club_length() -> float:
	return _club().draw_length


# The lean that makes the club head just touch the ground at address.
func _address_angle() -> float:
	var reach: float = ARM_LENGTH + _club_length()
	return rad_to_deg(acos(clampf(REACH_HEIGHT / reach, 0.0, 1.0)))


func _stand_at_ball() -> void:
	var reach: float = ARM_LENGTH + _club_length()
	var offset: float = sin(deg_to_rad(_address_angle())) * reach
	var x: float = _ball_x() - float(_facing()) * offset
	position = Vector2(round(x), round(game.terrain.ground_y(x)))


func _draw() -> void:
	var lean: float = clampf(_arm_angle / 130.0, -1.0, 1.0)
	var hip := Vector2(lean * 1.5, -11)
	var shoulder := SHOULDER + Vector2(lean * 2.5, 0)
	var head := shoulder + Vector2(1.0 - lean, -6)

	var arm_rad: float = deg_to_rad(_arm_angle)
	var hand: Vector2 = shoulder + Vector2(sin(arm_rad), cos(arm_rad)) * ARM_LENGTH
	var club_rad: float = deg_to_rad(_arm_angle + _hinge)
	var club_dir := Vector2(sin(club_rad), cos(club_rad))
	var club_head: Vector2 = hand + club_dir * _club_length()

	# Outlines first, so every limb reads against the background.
	_limb(Vector2(-5, -1), hip + Vector2(-1, 0), 5.0, OUTLINE)
	_limb(Vector2(5, -1), hip + Vector2(1, 0), 5.0, OUTLINE)
	_limb(hip, shoulder, 8.0, OUTLINE)
	draw_circle(head, 5.5, OUTLINE)

	_limb(Vector2(-5, -1), hip + Vector2(-1, 0), 3.0, pants_dark)
	_limb(Vector2(5, -1), hip + Vector2(1, 0), 3.0, pants)
	draw_rect(Rect2(-8, -2, 5, 2), SHOE)
	draw_rect(Rect2(3, -2, 5, 2), SHOE)

	_limb(hip, shoulder, 6.0, shirt)
	draw_rect(Rect2(hip.x - 3.0, hip.y - 1.0, 6, 2), shirt_dark)

	draw_circle(head, 4.5, skin)
	draw_rect(Rect2(head.x - 5.0, head.y - 5.0, 10, 4), cap)
	draw_rect(Rect2(head.x + 3.0, head.y - 2.0, 5, 1), cap)
	_draw_face(head)

	draw_line(hand, club_head, SHAFT, 1.0)
	draw_rect(Rect2(club_head.x - 1.0, club_head.y - 1.0, 4, 2), CLUB_HEAD)

	_limb(shoulder, hand, 4.0, OUTLINE)
	_limb(shoulder, hand, 2.0, shirt_dark)
	draw_rect(Rect2(hand.x - 1.0, hand.y - 1.0, 3, 3), skin)


func _draw_face(head: Vector2) -> void:
	draw_rect(Rect2(head.x + 2.0, head.y, 1, 1), OUTLINE)


func _limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width)
