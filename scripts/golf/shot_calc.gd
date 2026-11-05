class_name ShotCalc
extends RefCounted
## Turns meter results into a launch velocity. Pure maths, no state.

const PERFECT_SPEED_BONUS := 1.02
## Extra speed for hitting the top of the bar, which is about 15% more range.
const FULL_POWER_SPEED := 1.07
const POP_UP_EXTRA_LOFT := 22.0
const POP_UP_SPEED_LOSS := 0.32
const LOW_LOFT_LOSS := 0.62
const LOW_SPEED_LOSS := 0.06


## Range grows with speed squared, so taking the square root makes half power
## travel about half as far. A negative angle_deg means the club's default loft.
static func compute(
		club: ClubData, power: float, accuracy: float, spin: int, facing: int, lie_power: float,
		angle_deg: float = -1.0, lie_spin: float = 1.0
) -> Dictionary:
	var speed: float = club.max_speed * sqrt(clampf(power * lie_power, 0.0, 1.0))
	var angle: float = club.loft_deg if angle_deg < 0.0 else angle_deg
	accuracy *= club.miss_scale
	if power >= 1.0 and not club.is_putter:
		speed *= FULL_POWER_SPEED

	# Putts have no accuracy check: the ball goes exactly as hard as the power set.
	if club.is_putter:
		angle = 0.0
	elif accuracy > 0.0:
		angle += POP_UP_EXTRA_LOFT * accuracy
		speed *= 1.0 - POP_UP_SPEED_LOSS * accuracy
	elif accuracy < 0.0:
		angle *= 1.0 + LOW_LOFT_LOSS * accuracy
		speed *= 1.0 + LOW_SPEED_LOSS * accuracy
	else:
		speed *= PERFECT_SPEED_BONUS

	# Spin needs a clean strike: a full miss puts none on the ball.
	var spin_amount: float = 0.0
	if not club.is_putter:
		spin_amount = float(spin) * club.spin_strength * lie_spin * (1.0 - absf(accuracy))

	var rad: float = deg_to_rad(angle)
	return {
		"velocity": Vector2(cos(rad) * facing, -sin(rad)) * speed,
		"spin": spin_amount,
		"quality": quality_name(accuracy, club.is_putter, power),
	}


## Putts have no quality to report, so they return an empty name.
static func quality_name(accuracy: float, is_putter: bool, power: float = 0.0) -> String:
	if is_putter:
		return ""
	if power >= 1.0 and absf(accuracy) < 0.2:
		return "FULL POWER!!"
	if accuracy == 0.0:
		return "PERFECT!"
	if absf(accuracy) < 0.2:
		return "GOOD"
	return "POP-UP" if accuracy > 0.0 else "LOW AND HOT"
