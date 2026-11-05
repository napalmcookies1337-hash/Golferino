class_name SwingMeter
extends RefCounted
## The 3-click meter. Press 1 starts it, press 2 sets power on the way up, press 3
## sets accuracy on the way back. The cursor runs 0 to 1, and below 0 is the miss
## zone past the sweet spot. Reaching the top of the bar is a full power shot, and the
## cursor holds there a moment so a late power press can't count as the accuracy press.
## Putts use a sweep instead: one press starts the cursor and the next takes the power,
## with no accuracy check.

enum Stage { IDLE, RISING, RETURNING, DONE, SWEEPING }

## Time for a putt's cursor to go from empty to full, or back.
const SWEEP_TIME := 1.3
## A press can't set less power than this.
const MIN_PRESS_POWER := 0.02
## A power press this close to the top counts as full power.
const FULL_POWER_FROM := 0.97
## How long the cursor waits at the top on a full power swing. Presses do nothing meanwhile.
const TOP_HOLD := 0.22

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
## Set by the club and the rival's tricks. Kept across resets.
var time_scale: float = 1.0
var cursor: float = 0.0
var power: float = 0.0
## 0 is perfect. Positive is early (up to 1), negative is late (down to -1).
var accuracy: float = 0.0
## True once this swing has reached the top of the bar.
var full_power: bool = false

var _sweep_direction: float = 1.0
var _top_hold: float = 0.0


func reset() -> void:
	stage = Stage.IDLE
	cursor = 0.0
	power = 0.0
	accuracy = 0.0
	full_power = false
	_top_hold = 0.0
	_sweep_direction = 1.0


## Starts the moving cursor that a putt's next press stops.
func start_sweep() -> void:
	reset()
	stage = Stage.SWEEPING


## Advances the meter by one player press.
func press() -> void:
	match stage:
		Stage.SWEEPING:
			power = clampf(cursor, MIN_PRESS_POWER, 1.0)
			accuracy = 0.0
			stage = Stage.DONE
		Stage.IDLE:
			reset()
			stage = Stage.RISING
		Stage.RISING:
			if cursor >= FULL_POWER_FROM:
				_reach_full_power()
			else:
				power = clampf(cursor, MIN_PRESS_POWER, 1.0)
				stage = Stage.RETURNING
		Stage.RETURNING:
			if _top_hold <= 0.0:
				_lock_accuracy()


func tick(real_dt: float) -> void:
	var dt: float = real_dt * time_scale
	match stage:
		Stage.SWEEPING:
			cursor += _sweep_direction * dt / SWEEP_TIME
			if cursor >= 1.0:
				cursor = 1.0
				_sweep_direction = -1.0
			elif cursor <= 0.0:
				cursor = 0.0
				_sweep_direction = 1.0
		Stage.RISING:
			cursor += dt / RISE_TIME
			if cursor >= 1.0:
				_reach_full_power()
		Stage.RETURNING:
			if _top_hold > 0.0:
				_top_hold -= real_dt
				return
			# The return takes the same time at any power, so short shots stay timeable.
			cursor -= dt * maxf(power, MIN_RETURN_POWER) / RETURN_TIME
			if cursor <= MISS_END:
				cursor = MISS_END
				_lock_accuracy()


func is_done() -> bool:
	return stage == Stage.DONE


func _reach_full_power() -> void:
	cursor = 1.0
	power = 1.0
	full_power = true
	_top_hold = TOP_HOLD
	stage = Stage.RETURNING


func _lock_accuracy() -> void:
	accuracy = accuracy_for_cursor(cursor, perfect_window)
	stage = Stage.DONE


static func accuracy_for_cursor(c: float, window: float = PERFECT_WINDOW) -> float:
	if absf(c) <= window:
		return 0.0
	if c > 0.0:
		return clampf((c - window) / EARLY_RANGE, 0.0, 1.0)
	return -clampf((-c - window) / (-MISS_END - window), 0.0, 1.0)
