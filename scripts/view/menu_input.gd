class_name MenuInput
extends RefCounted
## Turns keyboard, d-pad and stick input into one step per press, for menus.

const STICK_ON := 0.6
const STICK_OFF := 0.3

var _stick_x_held: bool = false
var _stick_y_held: bool = false


## The direction this event steps the menu, or zero. Down is positive y.
func step(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadMotion:
		return _stick_step(event)
	if event.is_action_pressed("look_left", false):
		return Vector2i.LEFT
	if event.is_action_pressed("look_right", false):
		return Vector2i.RIGHT
	if event.is_action_pressed("aim_up", false) or event.is_action_pressed("spin_up", false):
		return Vector2i.UP
	if event.is_action_pressed("aim_down", false) or event.is_action_pressed("spin_down", false):
		return Vector2i.DOWN
	return Vector2i.ZERO


func _stick_step(event: InputEventJoypadMotion) -> Vector2i:
	var amount: float = event.axis_value
	if event.axis == JOY_AXIS_LEFT_X:
		if absf(amount) < STICK_OFF:
			_stick_x_held = false
		elif absf(amount) > STICK_ON and not _stick_x_held:
			_stick_x_held = true
			return Vector2i(int(signf(amount)), 0)
	elif event.axis == JOY_AXIS_LEFT_Y:
		if absf(amount) < STICK_OFF:
			_stick_y_held = false
		elif absf(amount) > STICK_ON and not _stick_y_held:
			_stick_y_held = true
			return Vector2i(0, int(signf(amount)))
	return Vector2i.ZERO
