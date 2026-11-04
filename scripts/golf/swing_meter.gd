class_name SwingMeter
extends RefCounted
## The 3-click meter. Press 1 starts it, press 2 sets power on the way up, press 3
## sets accuracy on the way back. The cursor runs 0 to 1, and below 0 is the miss
## zone past the sweet spot.

enum Stage { IDLE, RISING, RETURNING, DONE }

const RISE_TIME := 1.05
const RETURN_TIME := 0.92
## Half-width of the sweet spot in cursor units, about 40 ms either side.
const PERFECT_WINDOW := 0.035
const EARLY_RANGE := 0.3
const MISS_END := -0.18
## Below this power the return stops slowing down further.
const MIN_RETURN_POWER := 0.2

var stage: int = Stage.IDLE
## Set by the current lie. Kept across resets.
var perfect_window: float = PERFECT_WINDOW
var cursor: float = 0.0
var power: float = 0.0
## 0 is perfect. Positive is early (up to 1), negative is late (down to -1).
var accuracy: float = 0.0


func reset() -> void:
	stage = Stage.IDLE
	cursor = 0.0
	power = 0.0
	accuracy = 0.0


## Advances the meter by one player press.
func press() -> void:
	match stage:
		Stage.IDLE:
			reset()
			stage = Stage.RISING
		Stage.RISING:
			power = clampf(cursor, 0.02, 1.0)
			stage = Stage.RETURNING
		Stage.RETURNING:
			_lock_accuracy()


func tick(dt: float) -> void:
	match stage:
		Stage.RISING:
			cursor += dt / RISE_TIME
			if cursor >= 1.0:
				cursor = 1.0
				power = 1.0
				stage = Stage.RETURNING
		Stage.RETURNING:
			# The return takes the same time at any power, so short shots stay timeable.
			cursor -= dt * maxf(power, MIN_RETURN_POWER) / RETURN_TIME
			if cursor <= MISS_END:
				cursor = MISS_END
				_lock_accuracy()


func is_done() -> bool:
	return stage == Stage.DONE


func _lock_accuracy() -> void:
	accuracy = accuracy_for_cursor(cursor, perfect_window)
	stage = Stage.DONE


static func accuracy_for_cursor(c: float, window: float = PERFECT_WINDOW) -> float:
	if absf(c) <= window:
		return 0.0
	if c > 0.0:
		return clampf((c - window) / EARLY_RANGE, 0.0, 1.0)
	return -clampf((-c - window) / (-MISS_END - window), 0.0, 1.0)
