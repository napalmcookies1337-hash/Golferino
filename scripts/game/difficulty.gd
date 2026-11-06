class_name Difficulty
extends RefCounted
## How much harder infinite mode gets with each boss beaten, all in one place. Level 0 matches
## the main game, and each step is small. Nothing else in the game should know about levels.

const MAX_LEVEL := 10


## Shop prices.
static func price_scale(level: int) -> float:
	return 1.0 + 0.04 * float(level)


## Holes stretch while par stays the same, so par gets a little tighter too.
static func length_scale(level: int) -> float:
	return 1.0 + 0.015 * float(level)


## Carts, geese, windmills and sprinklers.
static func hazard_speed(level: int) -> float:
	return 1.0 + 0.03 * float(level)


## How many more hazards a hole tries to fit, on average.
static func extra_hazards(level: int) -> float:
	return 0.3 * float(level)


## The green's half width either side of the cup, in pixels.
static func green_half(level: int) -> float:
	return 120.0 - 4.0 * float(level)


static func wind_extra(level: int) -> float:
	return float(level)


## How often a rough patch replaces plain fairway between hazards.
static func rough_chance(level: int) -> float:
	return 0.12 + 0.04 * float(level)


## The spare strokes paid for beating a boss at this level. They shrink as the run goes on.
static func boss_reward(level: int) -> int:
	return 6 - level / 2


# The rival's numbers. Level 0 is what Rival.gd's constants say.

static func rival_miss_chance(level: int) -> float:
	return Rival.MISS_CHANCE * (1.0 - 0.06 * float(level))


static func rival_power_noise(level: int) -> float:
	return Rival.POWER_NOISE * (1.0 - 0.035 * float(level))


static func rival_putt_noise(level: int) -> float:
	return Rival.PUTT_NOISE * (1.0 - 0.04 * float(level))


## How finely it searches for a shot.
static func rival_power_steps(level: int) -> int:
	return Rival.POWER_STEPS + level


static func rival_cheats(level: int) -> int:
	return Rival.CHEATS_PER_HOLE + level / 4


## How good the rival plays in Swampy Shores: tougher than it would be elsewhere. It still only
## cheats twice a hole there, whatever this says.
static func swamp_rival_level(level: int) -> int:
	return mini(level + 4, MAX_LEVEL)
