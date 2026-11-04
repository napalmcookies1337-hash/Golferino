class_name ShotCalc
extends RefCounted
## Turns meter results into a launch velocity. Pure maths, no state.

const PERFECT_SPEED_BONUS := 1.02
const POP_UP_EXTRA_LOFT := 22.0
const POP_UP_SPEED_LOSS := 0.32
const LOW_LOFT_LOSS := 0.62
const LOW_SPEED_LOSS := 0.06
const PUTT_SPEED_ERROR := 0.22


## Range grows with speed squared, so taking the square root makes half power
## travel about half as far.
static func compute(
		club: ClubData, power: float, accuracy: float, spin: int, facing: int, lie_power: float
) -> Dictionary:
	var speed: float = club.max_speed * sqrt(clampf(power * lie_power, 0.0, 1.0))
	var angle: float = club.loft_deg

	if club.is_putter:
		speed *= 1.0 - PUTT_SPEED_ERROR * accuracy
		angle = 0.0
	elif accuracy > 0.0:
		angle += POP_UP_EXTRA_LOFT * accuracy
		speed *= 1.0 - POP_UP_SPEED_LOSS * accuracy
	elif accuracy < 0.0:
		angle *= 1.0 + LOW_LOFT_LOSS * accuracy
		speed *= 1.0 + LOW_SPEED_LOSS * accuracy
	else:
		speed *= PERFECT_SPEED_BONUS

	var rad: float = deg_to_rad(angle)
	return {
		"velocity": Vector2(cos(rad) * facing, -sin(rad)) * speed,
		"spin": 0 if club.is_putter else spin,
		"quality": quality_name(accuracy, club.is_putter),
	}


static func quality_name(accuracy: float, is_putter: bool) -> String:
	if accuracy == 0.0:
		return "PERFECT!"
	if absf(accuracy) < 0.2:
		return "GOOD"
	if is_putter:
		return "SHORT" if accuracy > 0.0 else "STRONG"
	return "POP-UP" if accuracy > 0.0 else "LOW AND HOT"
