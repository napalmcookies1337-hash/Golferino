class_name TitleGolfer
extends GolferView
## The golfer on the title screen, who practises drives on an endless loop.

signal struck

const CYCLE_TIME := 6.0
const BACKSWING_START := 3.5
const BACKSWING_END := 4.25
const DOWNSWING_END := 4.37

var ground_at: Callable
var ball_x: float = 0.0
var _driver: ClubData
var _time: float = 1.0
var _struck_this_cycle: bool = false


func setup_title(p_ball_x: float, p_ground_at: Callable) -> void:
	ball_x = p_ball_x
	ground_at = p_ground_at
	_driver = load("res://data/clubs/driver.tres")


func _ready() -> void:
	_stand_at_ball()


func _update_pose() -> void:
	_clear_reactions()
	_time += get_process_delta_time()
	if _time >= CYCLE_TIME:
		_time -= CYCLE_TIME
		_struck_this_cycle = false
	_stand_at_ball()
	if _time < BACKSWING_START:
		_arm_angle = _address_angle()
		_hinge = 0.0
		_breath = 1.0 if fmod(_time, BREATH_TIME) > BREATH_TIME / 2.0 else 0.0
	elif _time < BACKSWING_END:
		var t: float = (_time - BACKSWING_START) / (BACKSWING_END - BACKSWING_START)
		_arm_angle = lerpf(_address_angle(), BACK_ANGLE, t)
		_hinge = lerpf(0.0, BACK_HINGE, t)
	elif _time < DOWNSWING_END:
		var t: float = (_time - BACKSWING_END) / (DOWNSWING_END - BACKSWING_END)
		_arm_angle = lerpf(BACK_ANGLE, _address_angle(), t * t)
		_hinge = lerpf(BACK_HINGE, 0.0, t * t)
	else:
		if not _struck_this_cycle:
			_struck_this_cycle = true
			struck.emit()
		_follow_through(_time - DOWNSWING_END)


func _facing() -> int:
	return 1


func _ball_x() -> float:
	return ball_x


func _club() -> ClubData:
	return _driver


func _ground_y(x: float) -> float:
	return ground_at.call(x)
