class_name Surface
extends RefCounted
## Ground types and how each one treats the ball. Add a surface here and
## every system picks it up.

## New types go on the end: saved maps store these as numbers.
enum Type { ROUGH, FAIRWAY, GREEN, SAND, TEE, WATER, MUD, LILY }

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
	# Barely bounces or runs, and a shot out of it is heavy, though not as bad as a bunker.
	Type.MUD: {
		"name": "MUD", "restitution": 0.08, "impact_grip": 0.25,
		"roll_friction": 420.0, "spin_grip": 0.1,
		"lie_power": 0.72, "lie_spin": 0.5, "lie_window": 0.7,
	},
	# A lily pad on the water. Soft to land on, and a little wobbly to hit from.
	Type.LILY: {
		"name": "LILY PAD", "restitution": 0.2, "impact_grip": 0.55,
		"roll_friction": 140.0, "spin_grip": 0.5,
		"lie_power": 0.88, "lie_spin": 0.8, "lie_window": 0.85,
	},
}


static func props(type: int) -> Dictionary:
	return PROPS[type]
