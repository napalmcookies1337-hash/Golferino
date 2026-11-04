class_name Controls
extends RefCounted
## Registers keyboard and controller bindings in one place.


static func register() -> void:
	_add("swing", [KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A])
	_add("club_prev", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER])
	_add("club_next", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER])
	_add("club_1", [KEY_1], [])
	_add("club_2", [KEY_2], [])
	_add("club_3", [KEY_3], [])
	_add("spin_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_add("spin_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_add("look_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add("look_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add("flip", [KEY_F], [JOY_BUTTON_X])
	_add("restart", [KEY_R], [JOY_BUTTON_BACK])
	_add("fullscreen", [KEY_F11], [])
	_add("quit", [KEY_ESCAPE], [])


static func _add(
		action: String, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0
) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for key: int in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key as Key
		InputMap.action_add_event(action, key_event)
	for button: int in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button as JoyButton
		InputMap.action_add_event(action, button_event)
	if axis >= 0:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = axis as JoyAxis
		axis_event.axis_value = axis_value
		InputMap.action_add_event(action, axis_event)
