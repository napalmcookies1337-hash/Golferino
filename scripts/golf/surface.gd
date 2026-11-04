class_name Surface
extends RefCounted
## Ground types and how each one treats the ball. Add a surface here and
## every system picks it up.

enum Type { ROUGH, FAIRWAY, GREEN, SAND, TEE, WATER }

## restitution: bounce kept on impact. impact_grip: forward speed kept on impact.
## roll_friction: slowdown while rolling, px/s^2. spin_grip: how much spin bites on landing.
## lie_power: share of shot range when hitting from here. lie_spin: share of spin you can
## put on the ball from here. lie_window: size of the meter's sweet spot from here.
const PROPS := {
	Type.ROUGH: {
		"name": "ROUGH", "restitution": 0.22, "impact_grip": 0.5,
		"roll_friction": 170.0, "spin_grip": 0.3,
		"lie_power": 0.82, "lie_spin": 0.4, "lie_window": 0.75,
	},
	Type.FAIRWAY: {
		"name": "FAIRWAY", "restitution": 0.32, "impact_grip": 0.68,
		"roll_friction": 65.0, "spin_grip": 0.7,
		"lie_power": 1.0, "lie_spin": 1.0, "lie_window": 1.0,
	},
	Type.GREEN: {
		"name": "GREEN", "restitution": 0.28, "impact_grip": 0.72,
		"roll_friction": 45.0, "spin_grip": 1.0,
		"lie_power": 1.0, "lie_spin": 1.0, "lie_window": 1.0,
	},
	Type.SAND: {
		"name": "SAND", "restitution": 0.05, "impact_grip": 0.2,
		"roll_friction": 500.0, "spin_grip": 0.0,
		"lie_power": 0.6, "lie_spin": 0.6, "lie_window": 0.6,
	},
	Type.TEE: {
		"name": "TEE", "restitution": 0.32, "impact_grip": 0.68,
		"roll_friction": 65.0, "spin_grip": 0.7,
		"lie_power": 1.0, "lie_spin": 1.0, "lie_window": 1.0,
	},
	Type.WATER: {
		"name": "WATER", "restitution": 0.0, "impact_grip": 0.0,
		"roll_friction": 1000.0, "spin_grip": 0.0,
		"lie_power": 0.0, "lie_spin": 0.0, "lie_window": 1.0,
	},
}


static func props(type: int) -> Dictionary:
	return PROPS[type]
