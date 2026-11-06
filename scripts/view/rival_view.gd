class_name RivalView
extends GolferView
## The rival, standing by its own ball: dressed in loud purple and gold, with sunglasses.

const SNICKER_TIME := 0.16

var rival: Rival
var _strike_time: float = 0.0
var _was_swinging: bool = false


func setup_rival(p_game: HoleGame, p_rival: Rival) -> void:
	setup(p_game)
	rival = p_rival
	shirt = Color("7a3fc0")
	shirt_dark = Color("552a8c")
	pants = Color("e8c34a")
	pants_dark = Color("b8952e")
	cap = Color("2a2438")


## The same rival for the swamp rematch, kitted out to match.
func wear_swamp_colors() -> void:
	shirt = Color("4f8a3c")
	shirt_dark = Color("356429")
	pants = Color("9a7b3e")
	pants_dark = Color("745a2b")
	cap = Color("20302a")


func _ready() -> void:
	_stand_at_ball()


func _update_pose() -> void:
	# It only comes out for its own turn.
	visible = game.phase == HoleGame.Phase.RIVAL_TURN and not rival.holed
	_strike_time += get_process_delta_time()
	_clear_reactions()
	match rival.stage:
		Rival.Stage.SWINGING:
			_was_swinging = true
			var t: float = rival.swing_progress()
			# Up for most of the time, then a quick swing down.
			var amount: float = t / 0.7 if t < 0.7 else 1.0 - (t - 0.7) / 0.3
			var back: float = PUTT_BACK if _club().is_putter else BACK_ANGLE
			var hinge: float = 0.0 if _club().is_putter else BACK_HINGE
			_stand_at_ball()
			_arm_angle = lerpf(_address_angle(), back, amount)
			_hinge = lerpf(0.0, hinge, amount)
		Rival.Stage.MOVING:
			if _was_swinging:
				_was_swinging = false
				_strike_time = 0.0
			_follow_through(_strike_time)
		Rival.Stage.PENALTY:
			_stand_at_ball()
			_slump()
		Rival.Stage.CHEATING:
			# Shoulders shaking with laughter at its own trick.
			_stand_at_ball()
			_arm_angle = _address_angle()
			_hinge = 0.0
			_breath = 1.0 if fmod(_strike_time, SNICKER_TIME) > SNICKER_TIME / 2.0 else 0.0
		_:
			_stand_at_ball()
			_arm_angle = _address_angle()
			_hinge = 0.0


func _facing() -> int:
	return rival.facing


func _ball_x() -> float:
	return rival.ball.pos.x


func _club() -> ClubData:
	return rival.current_club()


func _draw_face(head: Vector2) -> void:
	draw_rect(Rect2(head.x + 0.0, head.y - 1.0, 5, 2), OUTLINE)
