class_name Items
extends RefCounted
## Everything the shop can sell. Items change numbers only: stickers change a run's copy
## of a club, balls change a BallSim, and perks change the run's own rules.
##
## Each entry: "id", "kind", "name", "text" (22 characters at most, to fit a shop card),
## "price" and "effects". Stickers also list the "clubs" they fit. Items with "unlock"
## aren't sold until a finished run earns them, and are meant to add variety, not power.

const KIND_STICKER := "sticker"
const KIND_BALL := "ball"
const KIND_PERK := "perk"
const KIND_STROKES := "strokes"

const SWING_CLUBS := ["driver", "iron"]
const ALL_CLUBS := ["driver", "iron", "putter"]

const CATALOG: Array[Dictionary] = [
	# Stickers.
	{ "id": "power_stripe", "kind": KIND_STICKER, "name": "POWER STRIPE", "text": "+8% RANGE", "price": 18, "clubs": SWING_CLUBS, "effects": { "speed": 1.04 } },
	{ "id": "sweet_tape", "kind": KIND_STICKER, "name": "SWEET TAPE", "text": "WIDER SWEET SPOT", "price": 16, "clubs": SWING_CLUBS, "effects": { "window": 1.4 } },
	{ "id": "spin_doctor", "kind": KIND_STICKER, "name": "SPIN DOCTOR", "text": "+50% SPIN", "price": 12, "clubs": SWING_CLUBS, "effects": { "spin": 1.5 } },
	{ "id": "rough_rider", "kind": KIND_STICKER, "name": "ROUGH RIDER", "text": "HALF LIE PENALTY", "price": 14, "clubs": SWING_CLUBS, "effects": { "lie": 0.5 } },
	{ "id": "wide_angle", "kind": KIND_STICKER, "name": "WIDE ANGLE", "text": "+10 ANGLE RANGE", "price": 10, "clubs": SWING_CLUBS, "effects": { "angle": 10.0 } },
	{ "id": "steady_hand", "kind": KIND_STICKER, "name": "STEADY HAND", "text": "SLOWER METER", "price": 18, "clubs": ALL_CLUBS, "effects": { "meter": 0.85 } },
	{ "id": "long_roll", "kind": KIND_STICKER, "name": "LONG ROLL", "text": "+20% PUTT REACH", "price": 10, "clubs": ["putter"], "effects": { "speed": 1.1 } },
	{ "id": "cup_magnet", "kind": KIND_STICKER, "name": "CUP MAGNET", "text": "FAST PUTTS DROP MORE", "price": 12, "clubs": ["putter"], "effects": { "cup_pull": 1.5 } },
	{ "id": "forgiver", "kind": KIND_STICKER, "name": "FORGIVER", "text": "MISSES HURT LESS", "price": 16, "clubs": SWING_CLUBS, "effects": { "miss": 0.6 }, "unlock": 1 },
	{ "id": "two_way_tape", "kind": KIND_STICKER, "name": "TWO-WAY TAPE", "text": "+12% RANGE, SMALL SPOT", "price": 14, "clubs": SWING_CLUBS, "effects": { "speed": 1.06, "window": 0.8 }, "unlock": 3 },

	# Special balls. Only one at a time, kept until replaced.
	{ "id": "wind_cutter", "kind": KIND_BALL, "name": "WIND CUTTER", "text": "WIND BARELY MOVES IT", "price": 12, "effects": { "wind": 0.3 } },
	{ "id": "sticky_ball", "kind": KIND_BALL, "name": "STICKY BALL", "text": "STOPS WHERE IT LANDS", "price": 12, "effects": { "bounce": 0.6, "roll": 1.5 } },
	{ "id": "rubber_ball", "kind": KIND_BALL, "name": "RUBBER BALL", "text": "BOUNCES AND RUNS MORE", "price": 12, "effects": { "bounce": 1.3, "roll": 0.8 } },
	{ "id": "skipper", "kind": KIND_BALL, "name": "SKIPPER", "text": "SKIPS OFF WATER ONCE", "price": 16, "effects": { "water_skips": 1 } },
	{ "id": "heavy_ball", "kind": KIND_BALL, "name": "HEAVY BALL", "text": "HAZARDS KNOCK IT LESS", "price": 14, "effects": { "knock": 0.5 }, "unlock": 2 },
	{ "id": "magnet_ball", "kind": KIND_BALL, "name": "MAGNET BALL", "text": "CUP PULLS IT HARD", "price": 14, "effects": { "cup_pull": 2.0 }, "unlock": 4 },

	# Perks last the rest of the run.
	{ "id": "coupon", "kind": KIND_PERK, "name": "COUPON BOOK", "text": "SHOP PRICES -20%", "price": 24, "effects": { "prices": 0.8 } },
	{ "id": "coin_purse", "kind": KIND_PERK, "name": "COIN PURSE", "text": "PICKUPS WORTH DOUBLE", "price": 20, "effects": { "coin_value": 2 } },
	{ "id": "birdie_bank", "kind": KIND_PERK, "name": "BIRDIE BANK", "text": "+5 COINS UNDER PAR", "price": 20, "effects": { "under_par_bonus": 5 } },
	{ "id": "mulligan", "kind": KIND_PERK, "name": "MULLIGAN", "text": "1 FREE PENALTY A HOLE", "price": 26, "effects": { "free_penalties": 1 } },
	{ "id": "safety_net", "kind": KIND_PERK, "name": "SAFETY NET", "text": "SAVES YOU ONCE: +3", "price": 28, "effects": { "safety_net": 3 } },
	{ "id": "showman", "kind": KIND_PERK, "name": "SHOWMAN", "text": "TRICK SHOTS PAY DOUBLE", "price": 18, "effects": { "trick": 2 } },
	{ "id": "extra_shelf", "kind": KIND_PERK, "name": "EXTRA SHELF", "text": "SHOP STOCKS ONE MORE", "price": 22, "effects": { "shelves": 1 }, "unlock": 5 },
	{ "id": "steady_pay", "kind": KIND_PERK, "name": "STEADY PAY", "text": "+3 COINS FOR PAR", "price": 18, "effects": { "par_bonus": 3 }, "unlock": 6 },

	# Bonus strokes.
	{ "id": "spare_strokes", "kind": KIND_STROKES, "name": "SPARE STROKES", "text": "+2 STROKES", "price": 14, "effects": { "strokes": 2 } },
]


static func by_id(id: String) -> Dictionary:
	for item: Dictionary in CATALOG:
		if item["id"] == id:
			return item
	return {}


## The ids of everything that starts locked, in the order runs unlock them.
static func unlock_order() -> Array[String]:
	var locked: Array[Dictionary] = []
	for item: Dictionary in CATALOG:
		if item.has("unlock"):
			locked.append(item)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["unlock"]) < int(b["unlock"]))
	var ids: Array[String] = []
	for item in locked:
		ids.append(str(item["id"]))
	return ids


## Applies stickers to a copy of a club, which is what the player then plays with.
static func club_with_stickers(base: ClubData, sticker_ids: Array) -> ClubData:
	var club: ClubData = base.duplicate()
	for id: Variant in sticker_ids:
		var effects: Dictionary = by_id(str(id)).get("effects", {})
		club.max_speed *= float(effects.get("speed", 1.0))
		club.spin_strength *= float(effects.get("spin", 1.0))
		club.lie_sensitivity *= float(effects.get("lie", 1.0))
		club.window_scale *= float(effects.get("window", 1.0))
		club.meter_speed *= float(effects.get("meter", 1.0))
		club.miss_scale *= float(effects.get("miss", 1.0))
		club.cup_pull_scale *= float(effects.get("cup_pull", 1.0))
		var extra_angle: float = float(effects.get("angle", 0.0))
		club.min_angle_deg = maxf(club.min_angle_deg - extra_angle, HoleGame.MIN_LAUNCH_ANGLE)
		club.max_angle_deg = minf(club.max_angle_deg + extra_angle, HoleGame.MAX_LAUNCH_ANGLE)
	return club


## Sets up a ball from a special ball's effects. An empty id means a plain ball.
static func apply_ball(sim: BallSim, ball_id: String) -> void:
	var effects: Dictionary = by_id(ball_id).get("effects", {})
	sim.bounce_scale = float(effects.get("bounce", 1.0))
	sim.roll_scale = float(effects.get("roll", 1.0))
	sim.cup_pull_scale = float(effects.get("cup_pull", 1.0))
	sim.knock_scale = float(effects.get("knock", 1.0))
	sim.water_skips = int(effects.get("water_skips", 0))


## How much of the wind reaches this ball.
static func ball_wind_share(ball_id: String) -> float:
	return float(by_id(ball_id).get("effects", {}).get("wind", 1.0))
