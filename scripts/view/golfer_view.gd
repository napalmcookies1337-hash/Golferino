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
const SKIN := Color("f0b98a")
const SHIRT := Color("e8584a")
const SHIRT_DARK := Color("b83d3f")
const PANTS := Color("f2ead0")
const PANTS_DARK := Color("c9bd9e")
const CAP := Color("2b8c8c")
const SHOE := Color("3a2f33")
const SHAFT := Color("c7ccd6")
const CLUB_HEAD := Color("8d97a8")

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
	match game.phase:
		HoleGame.Phase.AIM:
			_stand_at_ball()
			_arm_angle = _address_angle()
			_hinge = 0.0
		HoleGame.Phase.SWING:
			_update_backswing()
		HoleGame.Phase.DOWNSWING:
			var t: float = clampf(_phase_timer / HoleGame.DOWNSWING_TIME, 0.0, 1.0)
			var eased: float = t * t
			_arm_angle = lerpf(_top_angle, _address_angle(), eased)
			_hinge = lerpf(_top_hinge, 0.0, eased)
		HoleGame.Phase.BALL_MOVING, HoleGame.Phase.PENALTY, HoleGame.Phase.COMPLETE:
			var t2: float = clampf(_phase_timer / 0.22, 0.0, 1.0)
			var out: float = 1.0 - (1.0 - t2) * (1.0 - t2)
			_arm_angle = lerpf(_address_angle(), _follow_angle(), out)
			_hinge = lerpf(0.0, _follow_hinge(), out)
	scale.x = float(game.facing)
	queue_redraw()


func _on_phase_changed(_phase: int) -> void:
	_phase_timer = 0.0
	if game.phase == HoleGame.Phase.DOWNSWING:
		_top_angle = _arm_angle
		_top_hinge = _hinge


func _update_backswing() -> void:
	# The club rises with the meter, and holds at the set power on the way back.
	var meter: SwingMeter = game.meter
	var amount: float = meter.cursor if meter.stage == SwingMeter.Stage.RISING else meter.power
	var back: float = PUTT_BACK if game.current_club().is_putter else BACK_ANGLE
	var hinge: float = 0.0 if game.current_club().is_putter else BACK_HINGE
	_arm_angle = lerpf(_address_angle(), back, amount)
	_hinge = lerpf(0.0, hinge, amount)


func _follow_angle() -> float:
	return PUTT_FOLLOW if game.current_club().is_putter else FOLLOW_ANGLE


func _follow_hinge() -> float:
	return 0.0 if game.current_club().is_putter else FOLLOW_HINGE


func _club_length() -> float:
	return game.current_club().draw_length


# The lean that makes the club head just touch the ground at address.
func _address_angle() -> float:
	var reach: float = ARM_LENGTH + _club_length()
	return rad_to_deg(acos(clampf(REACH_HEIGHT / reach, 0.0, 1.0)))


func _stand_at_ball() -> void:
	var reach: float = ARM_LENGTH + _club_length()
	var offset: float = sin(deg_to_rad(_address_angle())) * reach
	var x: float = game.ball.pos.x - float(game.facing) * offset
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

	_limb(Vector2(-5, -1), hip + Vector2(-1, 0), 3.0, PANTS_DARK)
	_limb(Vector2(5, -1), hip + Vector2(1, 0), 3.0, PANTS)
	draw_rect(Rect2(-8, -2, 5, 2), SHOE)
	draw_rect(Rect2(3, -2, 5, 2), SHOE)

	_limb(hip, shoulder, 6.0, SHIRT)
	draw_rect(Rect2(hip.x - 3.0, hip.y - 1.0, 6, 2), SHIRT_DARK)

	draw_circle(head, 4.5, SKIN)
	draw_rect(Rect2(head.x - 5.0, head.y - 5.0, 10, 4), CAP)
	draw_rect(Rect2(head.x + 3.0, head.y - 2.0, 5, 1), CAP)
	draw_rect(Rect2(head.x + 2.0, head.y, 1, 1), OUTLINE)

	draw_line(hand, club_head, SHAFT, 1.0)
	draw_rect(Rect2(club_head.x - 1.0, club_head.y - 1.0, 4, 2), CLUB_HEAD)

	_limb(shoulder, hand, 4.0, OUTLINE)
	_limb(shoulder, hand, 2.0, SHIRT_DARK)
	draw_rect(Rect2(hand.x - 1.0, hand.y - 1.0, 3, 3), SKIN)


func _limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width)
