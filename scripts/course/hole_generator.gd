class_name HoleGenerator
extends RefCounted
## Makes holes for infinite mode. Every hole has a shape of its own, such as a long climb, a
## flight of terraces or a chain of islands, so playing them feels unlike the main course.
## Features (ponds, bunkers, hazards on level ground) sit in a row along that shape with
## fairway between them. Some holes play right to left. Holes are plain HoleData, so the rest
## of the game can't tell them apart. Knows nothing about nodes or drawing.

const HOLES_PER_SET := 9
const BOSS_PAR := 7
## Each set picks one of these mixes of par, then shuffles it.
const PAR_MIXES: Array[Array] = [
	[3, 3, 3, 4, 4, 4, 5, 5, 5],
	[3, 3, 4, 4, 4, 4, 5, 5, 6],
	[3, 4, 4, 4, 4, 5, 5, 6, 6],
	[3, 3, 3, 3, 4, 4, 5, 5, 6],
]
## Tee to cup, by par, before the difficulty stretches it.
const DISTANCES := {
	3: [360.0, 660.0],
	4: [950.0, 1500.0],
	5: [1700.0, 2200.0],
	6: [2300.0, 2600.0],
	7: [2800.0, 2950.0],
}
const MAX_FEATURES := { 3: 2, 4: 5, 5: 7, 6: 9, 7: 12 }
const SHAPES: Array[String] = ["climb", "descent", "valley", "hump", "waves", "terraces", "islands", "badlands"]
## The first two holes of a set use these until the difficulty's up a bit, so it still ramps.
const GENTLE_SHAPES: Array[String] = ["climb", "descent", "valley", "hump", "waves"]
const GENTLE_UNTIL_LEVEL := 4
const GENTLE_HOLES := 2
## How many ponds an island hole has at most, by par.
const ISLAND_PONDS := { 3: 1, 4: 2, 5: 3, 6: 4 }
## Boss holes need level ground for all their hazards.
const BOSS_SHAPES: Array[String] = ["climb", "valley", "hump", "waves", "descent", "badlands"]
const SHAPE_TITLES := {
	"climb": ["CLIMB", "ASCENT", "SUMMIT", "UPHILL", "SWITCHBACK", "LOOKOUT"],
	"descent": ["DROP", "PLUNGE", "SLIDE", "RUNAWAY", "FREEFALL", "DOWNHILL"],
	"valley": ["BOWL", "BASIN", "HOLLOW", "VALLEY", "GULLY", "CRATER"],
	"hump": ["CREST", "SADDLE", "HUMP", "KNOLL", "BLUFF", "BACKBONE"],
	"waves": ["SWELLS", "ROLLERS", "COASTER", "BREAKERS", "RIPPLES", "CHOP"],
	"terraces": ["STEPS", "TERRACES", "STAIRS", "LEDGES", "SHELVES", "TIERS"],
	"islands": ["ISLES", "SHALLOWS", "LAGOON", "STEPPING STONES", "ATOLL", "CROSSING"],
	"badlands": ["BADLANDS", "SCRUB", "WASTES", "WILDS", "BARRENS", "DUNES"],
}
const TITLE_FIRST := [
	"BREEZY", "MUDDY", "LOW", "LONG", "OLD", "QUIET", "CROOKED", "SUNNY", "WINDY", "STONY",
	"HIDDEN", "LAZY", "TIPSY", "MOSSY", "BIG", "LITTLE", "LOST", "SLY", "GOLDEN", "WILD",
]
const BOSS_TITLES := ["THE GAUNTLET", "THE LONG WALK", "THE GRINDER", "THE LAST STAND", "THE RECKONING", "THE BIG ONE"]
## How often a hole plays right to left.
const REVERSED_CHANCE := 0.35
const FLOATING_PAD_CHANCE := 0.45
const TEE_X := 90.0
const TEE_FROM := 60.0
const TEE_TO := 130.0
## The ground stays between these heights, with room for a pond's bed below.
const HIGHEST_Y := 205.0
const LOWEST_Y := 395.0
## Fairway needed around features. Ponds get more after them, to land on.
const GAP_MIN := 90.0
const GAP_AFTER_POND := 210.0
const FIRST_GAP := 190.0
const FIRST_GAP_SHORT := 60.0
const LAST_GAP := 60.0
## No pond starts closer than this on a par 4 or longer, so there's always room for a normal
## drive before it. Too close and the tee shot is a full-power carry or a tiny lay-up.
const POND_EARLIEST := 620.0
const COINS_PER_HOLE := 8

const WIDTHS := {
	"bunker": [110.0, 170.0],
	"pond": [150.0, 230.0],
	"geese": [240.0, 330.0],
	"ridge": [200.0, 300.0],
	"rough": [120.0, 200.0],
	"pad": [70.0, 70.0],
	"windmill": [140.0, 140.0],
	"sprinkler": [130.0, 130.0],
	"cart": [320.0, 320.0],
	"gator": [130.0, 130.0],
}
## From this far through a set, swamp holes can have gators.
const GATOR_FIRST_HOLE := 2
const BOSS_GATOR_SLOT := 6
## The hole in a set where each kind can first appear, before difficulty brings it forward.
const FIRST_HOLE := {
	"bunker": 0,
	"pond": 0,
	"ridge": 1,
	"rough": 1,
	"pad": 2,
	"cart": 4,
	"windmill": 5,
	"sprinkler": 6,
	"geese": 7,
}
const BOSS_FEATURES: Array[String] = ["cart", "pad", "geese", "windmill", "sprinkler", "pond", "pad"]
const WIND_FROM_HOLE := 3


## Sets take turns: Grassy Greens first, then Swampy Shores, and so on.
static func biome_for_set(set_number: int) -> String:
	return HoleData.BIOME_SWAMP if set_number % 2 == 0 else HoleData.BIOME_GRASSY


## A whole set: nine holes in a shuffled order, then the boss. Shapes are dealt like cards, so
## a set uses them all before any comes round again.
static func generate_set(rng: RandomNumberGenerator, level: int, biome: String = HoleData.BIOME_GRASSY) -> Array[HoleData]:
	var mix: Array = PAR_MIXES[rng.randi_range(0, PAR_MIXES.size() - 1)].duplicate()
	var deck: Array[String] = []
	var holes: Array[HoleData] = []
	_shuffle(rng, mix)
	for i in mix.size():
		if deck.is_empty():
			deck.assign(SHAPES)
			_shuffle(rng, deck)
		var gentle: bool = i < GENTLE_HOLES and level < GENTLE_UNTIL_LEVEL
		holes.append(generate_hole(rng, level, i, int(mix[i]), false, _deal_shape(deck, gentle), biome))
	var boss_shape: String = BOSS_SHAPES[rng.randi_range(0, BOSS_SHAPES.size() - 1)]
	holes.append(generate_hole(rng, level, mix.size(), BOSS_PAR, true, boss_shape, biome))
	return holes


# The next shape off the deck, passing over the harsh ones when it has to be a gentle hole.
static func _deal_shape(deck: Array[String], gentle: bool) -> String:
	for i in range(deck.size() - 1, -1, -1):
		if not gentle or GENTLE_SHAPES.has(deck[i]):
			var shape: String = deck[i]
			deck.remove_at(i)
			return shape
	return GENTLE_SHAPES[0]


static func generate_hole(rng: RandomNumberGenerator, level: int, index: int, par: int, is_boss: bool, shape_kind: String = "", biome: String = HoleData.BIOME_GRASSY) -> HoleData:
	if shape_kind == "":
		shape_kind = SHAPES[rng.randi_range(0, SHAPES.size() - 1)]
	var limits: Array = DISTANCES[par]
	var distance: float = rng.randf_range(limits[0], limits[1]) * Difficulty.length_scale(level)
	var cup_x: float = round(TEE_X + distance)
	var green_half: float = Difficulty.green_half(level)
	var green_from: float = cup_x - green_half

	var hole := HoleData.new()
	hole.biome = biome
	hole.par = par
	hole.tee_x = TEE_X
	hole.cup_x = cup_x
	hole.display_name = "BOSS HOLE" if is_boss else "HOLE %d" % (index + 1)
	hole.title = _title(rng, is_boss, shape_kind)
	hole.wind = _wind(rng, level, index, is_boss)

	var shape: Dictionary = _make_shape(rng, shape_kind, green_from)
	var layout: Array[Dictionary] = _lay_out(rng, level, index, par, is_boss, green_from, shape_kind, biome)
	_build_ground(rng, hole, level, layout, shape, green_from, green_half)
	if shape_kind == "badlands":
		_break_up_fairway(rng, hole)
	if biome == HoleData.BIOME_SWAMP:
		_turn_sand_to_mud(hole)
	var terrain := Terrain.new(hole)
	_float_some_pads(rng, hole, terrain)
	_remove_pads_aimed_at_water(hole, terrain)
	_add_coins(rng, hole, terrain)
	_add_trees(rng, hole, layout)
	if rng.randf() < REVERSED_CHANCE:
		_mirror(hole)
	return hole


static func _title(rng: RandomNumberGenerator, is_boss: bool, shape_kind: String) -> String:
	if is_boss:
		return str(BOSS_TITLES[rng.randi_range(0, BOSS_TITLES.size() - 1)])
	var first: String = TITLE_FIRST[rng.randi_range(0, TITLE_FIRST.size() - 1)]
	var names: Array = SHAPE_TITLES[shape_kind]
	return "%s %s" % [first, str(names[rng.randi_range(0, names.size() - 1)])]


static func _wind(rng: RandomNumberGenerator, level: int, index: int, is_boss: bool) -> float:
	var from_hole: int = maxi(WIND_FROM_HOLE - level / 2, 1)
	if not is_boss and (index < from_hole or rng.randf() < 0.35):
		return 0.0
	var strength: float = rng.randf_range(6.0, 10.0) + Difficulty.wind_extra(level)
	return strength if rng.randf() < 0.5 else -strength


# --- The hole's shape ---

static func _make_shape(rng: RandomNumberGenerator, kind: String, green_from: float) -> Dictionary:
	var shape: Dictionary = { "kind": kind, "from": TEE_TO, "to": green_from, "steep": 0.5 }
	match kind:
		"climb":
			shape["low"] = rng.randf_range(370.0, LOWEST_Y)
			shape["high"] = rng.randf_range(HIGHEST_Y, 240.0)
		"descent":
			shape["high"] = rng.randf_range(HIGHEST_Y, 240.0)
			shape["low"] = rng.randf_range(370.0, LOWEST_Y)
		"valley":
			shape["rim"] = rng.randf_range(HIGHEST_Y, 250.0)
			shape["floor"] = rng.randf_range(360.0, LOWEST_Y)
		"hump":
			shape["base"] = rng.randf_range(360.0, LOWEST_Y)
			shape["top"] = rng.randf_range(HIGHEST_Y, 250.0)
		"waves":
			shape["steep"] = 0.7
			shape["middle"] = rng.randf_range(290.0, 330.0)
			shape["size"] = rng.randf_range(40.0, 65.0)
			shape["period"] = rng.randf_range(430.0, 640.0)
			shape["phase"] = rng.randf_range(0.0, TAU)
		"terraces":
			shape["steep"] = 1.1
			var shelves: Array[float] = []
			var y: float = rng.randf_range(300.0, 380.0)
			var length: float = green_from - TEE_TO
			for _i in maxi(int(length / rng.randf_range(260.0, 380.0)), 2):
				shelves.append(y)
				var change: float = rng.randf_range(40.0, 75.0)
				y += change if rng.randf() < 0.35 else -change
				if y < HIGHEST_Y or y > LOWEST_Y:
					y = clampf(y - 2.0 * change * signf(y - 300.0), HIGHEST_Y, LOWEST_Y)
			shape["shelves"] = shelves
		"islands":
			shape["middle"] = rng.randf_range(310.0, 350.0)
		"badlands":
			shape["middle"] = rng.randf_range(280.0, 340.0)
			shape["size"] = rng.randf_range(14.0, 26.0)
			shape["period"] = rng.randf_range(200.0, 300.0)
			shape["phase"] = rng.randf_range(0.0, TAU)
	return shape


# How high the hole's shape wants the ground to be at this x.
static func _shape_y(shape: Dictionary, x: float) -> float:
	var t: float = clampf((x - float(shape["from"])) / (float(shape["to"]) - float(shape["from"])), 0.0, 1.0)
	var y: float = 300.0
	match str(shape["kind"]):
		"climb":
			y = lerpf(float(shape["low"]), float(shape["high"]), smoothstep(0.0, 1.0, t))
		"descent":
			y = lerpf(float(shape["high"]), float(shape["low"]), smoothstep(0.0, 1.0, t))
		"valley":
			y = lerpf(float(shape["rim"]), float(shape["floor"]), sin(t * PI))
		"hump":
			y = lerpf(float(shape["base"]), float(shape["top"]), sin(t * PI))
		"waves", "badlands":
			y = float(shape["middle"]) + float(shape["size"]) * sin(x / float(shape["period"]) * TAU + float(shape["phase"]))
		"terraces":
			var shelves: Array = shape["shelves"]
			y = float(shelves[mini(int(t * float(shelves.size())), shelves.size() - 1)])
		"islands":
			y = float(shape["middle"])
	return clampf(y, HIGHEST_Y, LOWEST_Y)


# --- Choosing what goes on the hole ---

static func _lay_out(rng: RandomNumberGenerator, level: int, index: int, par: int, is_boss: bool, green_from: float, shape_kind: String, biome: String) -> Array[Dictionary]:
	var wanted: Array[String] = _wanted_features(rng, level, index, par, is_boss, shape_kind, biome)
	var first_gap: float = FIRST_GAP_SHORT if par == 3 else FIRST_GAP
	var room: float = green_from - TEE_TO
	var chosen: Array[Dictionary] = []
	# Anything first in the list is the most wanted, so it's what gets the room.
	var must_have: int = BOSS_FEATURES.size() if is_boss else 0
	for i in wanted.size():
		var slot: Dictionary = { "kind": wanted[i], "width": _width_of(rng, wanted[i], level, par, shape_kind, room), "must": i < must_have }
		chosen.append(slot)
		if _room_needed(chosen, first_gap, par) > room and i >= must_have:
			chosen.pop_back()
	_shuffle_slots(rng, chosen)
	# Another order can need a little more, since only ponds ask for extra space after them.
	# Anything can go to make room, except what a boss hole must have.
	while _room_needed(chosen, first_gap, par) > room:
		var dropped: bool = false
		for i in range(chosen.size() - 1, -1, -1):
			if not chosen[i]["must"]:
				chosen.remove_at(i)
				dropped = true
				break
		if not dropped:
			break

	# Whatever's left over spreads out between the features as extra fairway.
	var spare: float = maxf(room - _room_needed(chosen, first_gap, par), 0.0)
	var shares: Array[float] = []
	var total_share: float = 0.0
	for i in chosen.size() + 1:
		var share: float = rng.randf_range(0.5, 1.5)
		shares.append(share)
		total_share += share
	var x: float = TEE_TO + first_gap + spare * shares[0] / total_share
	for i in chosen.size():
		var slot: Dictionary = chosen[i]
		if par != 3 and _is_pond(str(slot["kind"])):
			x = maxf(x, POND_EARLIEST)
		slot["x"] = round(x)
		x += float(slot["width"])
		if i < chosen.size() - 1:
			x += _gap_after(str(slot["kind"])) + spare * shares[i + 1] / total_share
	return chosen


# The fairway and features this row takes up, in this order.
static func _room_needed(slots: Array[Dictionary], first_gap: float, par: int) -> float:
	var x: float = TEE_TO + first_gap
	for i in slots.size():
		var kind: String = slots[i]["kind"]
		if par != 3 and _is_pond(kind):
			x = maxf(x, POND_EARLIEST)
		x += float(slots[i]["width"])
		if i < slots.size() - 1:
			x += _gap_after(kind)
	return x + LAST_GAP - TEE_TO


static func _is_pond(kind: String) -> bool:
	return kind == "pond" or kind == "geese"


static func _gap_after(kind: String) -> float:
	return GAP_AFTER_POND if _is_pond(kind) else GAP_MIN


static func _width_of(rng: RandomNumberGenerator, kind: String, level: int, par: int, shape_kind: String, room: float) -> float:
	var limits: Array = WIDTHS[kind]
	var low: float = limits[0]
	var high: float = limits[1]
	if kind == "pond":
		high = minf(high + 7.0 * float(level), 300.0)
		if par == 3:
			high = minf(high, 170.0)
		# On an island hole, the water reaches most of the way to the green.
		if shape_kind == "islands":
			if par == 3:
				return round(maxf(room - FIRST_GAP_SHORT - LAST_GAP - rng.randf_range(0.0, 30.0), low))
			low = 170.0
			high = minf(230.0 + 6.0 * float(level), 300.0)
	if kind == "geese":
		high = minf(280.0 + 5.0 * float(level), high)
	return round(rng.randf_range(low, high))


static func _wanted_features(rng: RandomNumberGenerator, level: int, index: int, par: int, is_boss: bool, shape_kind: String, biome: String = HoleData.BIOME_GRASSY) -> Array[String]:
	var wanted: Array[String] = []
	var swamp: bool = biome == HoleData.BIOME_SWAMP
	if is_boss:
		# What every boss hole must have comes first, so extras can't crowd it out.
		wanted.assign(BOSS_FEATURES)
		if swamp:
			wanted[BOSS_GATOR_SLOT] = "gator"
		for _i in level / 3:
			wanted.append(["pond", "bunker", "pad", "sprinkler"][rng.randi_range(0, 3)])
		return wanted
	var pool: Array[String] = []
	# Difficulty brings the stranger hazards forward in the set.
	var reach: int = index + level / 2
	for kind: String in FIRST_HOLE:
		if int(FIRST_HOLE[kind]) <= reach:
			pool.append(kind)
	if swamp and reach >= GATOR_FIRST_HOLE:
		pool.append("gator")
	if shape_kind == "islands":
		for _i in int(ISLAND_PONDS[par]):
			wanted.append("pond")
		return wanted
	var count: float = 1.0 + float(index) * 0.35 + Difficulty.extra_hazards(level) + rng.randf_range(-0.5, 0.5)
	var how_many: int = clampi(roundi(count), 1, int(MAX_FEATURES[par]))
	# Two windmills on a hole is plenty, and even that waits for the later difficulties.
	var big_hazard_limit: int = 1 + level / 5
	for _i in how_many:
		var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
		if (kind == "windmill" or kind == "cart") and wanted.count(kind) >= big_hazard_limit:
			continue
		wanted.append(kind)
	return wanted


static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Variant = list[i]
		list[i] = list[j]
		list[j] = held


static func _shuffle_slots(rng: RandomNumberGenerator, slots: Array[Dictionary]) -> void:
	for i in range(slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Dictionary = slots[i]
		slots[i] = slots[j]
		slots[j] = held


# --- Building the ground ---

static func _build_ground(rng: RandomNumberGenerator, hole: HoleData, level: int, layout: Array[Dictionary], shape: Dictionary, green_from: float, green_half: float) -> void:
	var points := PackedVector2Array()
	var y: float = _shape_y(shape, TEE_TO)
	points.append(Vector2(0.0, y - 10.0))
	points.append(Vector2(TEE_FROM, y))
	points.append(Vector2(TEE_TO, y))
	hole.surface_spans.append({ "from": int(TEE_FROM), "to": int(TEE_TO), "type": Surface.Type.TEE })

	var x: float = TEE_TO
	var fairway_from: float = TEE_TO
	for slot: Dictionary in layout:
		var start: float = float(slot["x"])
		y = _roll_ground(rng, points, x, start, y, shape)
		x = start
		var width: float = float(slot["width"])
		var kind: String = slot["kind"]
		match kind:
			"bunker":
				_add_fairway(hole, fairway_from, x + 2.0)
				y = _add_bunker(rng, hole, points, x, width, y)
				fairway_from = x + width - 2.0
			"pond", "geese":
				_add_fairway(hole, fairway_from, x)
				y = _add_pond(rng, hole, points, x, width, y)
				if hole.biome == HoleData.BIOME_SWAMP:
					_add_lilies(rng, hole, x, width)
				elif kind == "geese":
					_add_geese(rng, hole, level, x, width)
				fairway_from = x + width + rng.randf_range(10.0, 50.0)
			"rough":
				_add_fairway(hole, fairway_from, x)
				y = _roll_ground(rng, points, x, x + width, y, shape)
				fairway_from = x + width
				if hole.biome == HoleData.BIOME_SWAMP:
					hole.surface_spans.append({ "from": int(x), "to": int(x + width), "type": Surface.Type.MUD })
			"ridge":
				y = _add_ridge(rng, points, x, width, y)
			_:
				y = _add_level_ground(rng, points, x, width, y)
				_add_level_hazard(rng, hole, level, kind, x, width)
		x += width
		# Now and then plain fairway gives way to rough, more so as the run goes on.
		if rng.randf() < Difficulty.rough_chance(level) * 0.5 and fairway_from < x:
			_add_fairway(hole, fairway_from, x - 40.0)
			fairway_from = x + 30.0

	# The run in to the green, which is level and sits a little above the ground around it.
	y = _roll_ground(rng, points, x, green_from - 40.0, y, shape)
	y = clampf(y + rng.randf_range(-16.0, 4.0), HIGHEST_Y, LOWEST_Y)
	_add_fairway(hole, fairway_from, green_from)
	var green_to: float = hole.cup_x + green_half
	points.append(Vector2(green_from, y))
	points.append(Vector2(hole.cup_x, y - 2.0))
	points.append(Vector2(green_to, y))
	_add_far_end(rng, points, green_to, y)
	hole.surface_spans.append({ "from": int(green_from), "to": int(green_to), "type": Surface.Type.GREEN })
	hole.points = points


# What's past the green: a bank that catches a long shot, a flat shelf, or a slope away from it.
static func _add_far_end(rng: RandomNumberGenerator, points: PackedVector2Array, green_to: float, y: float) -> void:
	var roll: float = rng.randf()
	if roll < 0.34:
		points.append(Vector2(green_to + 70.0, y - 20.0))
		points.append(Vector2(green_to + 200.0, y - 55.0))
	elif roll < 0.67:
		points.append(Vector2(green_to + 90.0, y - 4.0))
		points.append(Vector2(green_to + 260.0, y - 12.0))
	else:
		points.append(Vector2(green_to + 70.0, y + 12.0))
		points.append(Vector2(green_to + 260.0, y + 40.0))


static func _add_fairway(hole: HoleData, from_x: float, to_x: float) -> void:
	if to_x - from_x >= 4.0:
		hole.surface_spans.append({ "from": int(from_x), "to": int(to_x), "type": Surface.Type.FAIRWAY })


# Follows the hole's shape from one x to another. Returns the height it ended at.
static func _roll_ground(rng: RandomNumberGenerator, points: PackedVector2Array, from_x: float, to_x: float, y: float, shape: Dictionary) -> float:
	var x: float = from_x
	var steep: float = float(shape["steep"])
	while to_x - x > 40.0:
		var step: float = minf(rng.randf_range(70.0, 130.0), to_x - x)
		if to_x - x - step < 40.0:
			step = to_x - x
		x += step
		y = clampf(move_toward(y, _shape_y(shape, x), step * steep), HIGHEST_Y, LOWEST_Y)
		_add_point(points, x, y)
	if to_x - x > 0.0:
		_add_point(points, to_x, y)
	return y


static func _add_point(points: PackedVector2Array, x: float, y: float) -> void:
	if points[points.size() - 1].x + HoleIO.MIN_POINT_GAP <= x:
		points.append(Vector2(x, y))


static func _add_bunker(rng: RandomNumberGenerator, hole: HoleData, points: PackedVector2Array, x: float, width: float, y: float) -> float:
	var depth: float = rng.randf_range(14.0, 30.0)
	_add_point(points, x, y)
	_add_point(points, x + 28.0, y + depth)
	_add_point(points, x + width - 28.0, y + depth + 2.0)
	_add_point(points, x + width, y + 2.0)
	hole.surface_spans.append({ "from": int(x + 4.0), "to": int(x + width - 4.0), "type": Surface.Type.SAND })
	return y + 2.0


static func _add_pond(rng: RandomNumberGenerator, hole: HoleData, points: PackedVector2Array, x: float, width: float, y: float) -> float:
	y = minf(y, LOWEST_Y)
	var depth: float = rng.randf_range(30.0, 42.0)
	var bank: float = rng.randf_range(38.0, 58.0)
	_add_point(points, x, y)
	_add_point(points, x + bank, y + depth)
	_add_point(points, x + width - bank, y + depth + 2.0)
	var far: float = maxf(y - rng.randf_range(0.0, 14.0), HIGHEST_Y)
	_add_point(points, x + width, far)
	hole.water_spans.append({ "from": int(x), "to": int(x + width + 10.0), "level": y + depth * 0.55 })
	return far


# A big climb or drop, gentle enough to play over either way.
static func _add_ridge(rng: RandomNumberGenerator, points: PackedVector2Array, x: float, width: float, y: float) -> float:
	var change: float = rng.randf_range(-90.0, -45.0) if rng.randf() < 0.65 else rng.randf_range(35.0, 70.0)
	var target: float = clampf(y + change, HIGHEST_Y, LOWEST_Y)
	_add_point(points, x, y)
	_add_point(points, x + width * 0.5, lerpf(y, target, 0.55))
	_add_point(points, x + width, target)
	return target


static func _add_level_ground(rng: RandomNumberGenerator, points: PackedVector2Array, x: float, width: float, y: float) -> float:
	_add_point(points, x, y)
	var end_y: float = clampf(y + rng.randf_range(-4.0, 4.0), HIGHEST_Y, LOWEST_Y)
	_add_point(points, x + width, end_y)
	return end_y


static func _add_level_hazard(rng: RandomNumberGenerator, hole: HoleData, level: int, kind: String, x: float, width: float) -> void:
	var speed: float = Difficulty.hazard_speed(level)
	var middle: float = round(x + width / 2.0)
	# The swamp's windmill plays the same as any other, so it goes through as normal.
	if hole.biome == HoleData.BIOME_SWAMP and kind != "pad" and kind != "windmill":
		_add_swamp_hazard(rng, hole, kind, x, width, speed)
		return
	match kind:
		"pad":
			hole.obstacles.append({ "kind": "pad", "x": middle, "rotation": _pad_rotation(rng) })
		"windmill":
			hole.obstacles.append({ "kind": "windmill", "x": middle, "turn_speed": rng.randf_range(0.9, 1.2) * speed })
		"sprinkler":
			hole.obstacles.append({
				"kind": "sprinkler",
				"x": middle,
				"height": rng.randf_range(65.0, 85.0),
				"on_time": rng.randf_range(2.0, 2.5),
				"off_time": rng.randf_range(1.8, 2.5) / speed,
				"offset": rng.randf_range(0.0, 2.0),
			})
		"cart":
			hole.obstacles.append({
				"kind": "cart",
				"from": x + 20.0,
				"to": x + width - 20.0,
				"speed": rng.randf_range(45.0, 60.0) * speed,
			})


# The swamp's own hazards fill the same places in a hole as the golf course's.
static func _add_swamp_hazard(rng: RandomNumberGenerator, hole: HoleData, kind: String, x: float, width: float, speed: float) -> void:
	var middle: float = round(x + width / 2.0)
	match kind:
		"cart":
			for _i in 2:
				hole.obstacles.append({
					"kind": "frog",
					"from": x + 20.0,
					"to": x + width - 20.0,
					"start": rng.randf_range(x + 20.0, x + width - 20.0),
					"speed": rng.randf_range(60.0, 85.0) * speed,
				})
		"gator":
			hole.obstacles.append({ "kind": "gator", "x": middle, "side": -1.0 })
		"sprinkler":
			hole.obstacles.append({
				"kind": "vent",
				"x": middle,
				"height": rng.randf_range(70.0, 100.0),
				"quiet_time": rng.randf_range(2.2, 3.0) / speed,
				"burst_time": rng.randf_range(0.9, 1.2),
				"offset": rng.randf_range(0.0, 2.0),
			})


# Stepping stones across a pond, spaced so a shot can land on one.
static func _add_lilies(rng: RandomNumberGenerator, hole: HoleData, x: float, width: float) -> void:
	var count: int = clampi(int(width / 110.0), 1, 3)
	for i in count:
		var center: float = x + width * (float(i) + 1.0) / float(count + 1)
		hole.obstacles.append({
			"kind": "lily",
			"x": round(center + rng.randf_range(-12.0, 12.0)),
			"width": round(rng.randf_range(44.0, 60.0)),
		})


static func _turn_sand_to_mud(hole: HoleData) -> void:
	for span: Dictionary in hole.surface_spans:
		if int(span["type"]) == Surface.Type.SAND:
			span["type"] = Surface.Type.MUD


# Usually faces away from the hole as a hazard, and sometimes toward it as a reward.
static func _pad_rotation(rng: RandomNumberGenerator) -> float:
	var roll: float = rng.randf()
	if roll < 0.65:
		return -round(rng.randf_range(20.0, 35.0))
	if roll < 0.9:
		return round(rng.randf_range(15.0, 25.0))
	return 0.0


static func _add_geese(rng: RandomNumberGenerator, hole: HoleData, level: int, x: float, width: float) -> void:
	var count: int = 1 + level / 4
	var speed: float = Difficulty.hazard_speed(level)
	var from_x: float = x + 30.0
	var to_x: float = x + width - 25.0
	for _i in mini(count, 3):
		hole.obstacles.append({
			"kind": "goose",
			"from": from_x,
			"to": to_x,
			"start": rng.randf_range(from_x, to_x),
			"height": rng.randf_range(50.0, 105.0),
			"speed": rng.randf_range(50.0, 75.0) * speed,
		})


# --- Finishing touches ---

# Fairway broken into strips, with waste sand and rough between them, so every shot has to
# find the next safe patch.
static func _break_up_fairway(rng: RandomNumberGenerator, hole: HoleData) -> void:
	var spans: Array = []
	for span: Dictionary in hole.surface_spans:
		if int(span["type"]) != Surface.Type.FAIRWAY:
			spans.append(span)
			continue
		var x: float = float(span["from"])
		var end_x: float = float(span["to"])
		while x < end_x:
			var strip_end: float = minf(x + rng.randf_range(140.0, 260.0), end_x)
			spans.append({ "from": int(x), "to": int(strip_end), "type": Surface.Type.FAIRWAY })
			x = strip_end
			var waste_end: float = minf(x + rng.randf_range(70.0, 170.0), end_x)
			if waste_end > x and rng.randf() < 0.5:
				spans.append({ "from": int(x), "to": int(waste_end), "type": Surface.Type.SAND })
			x = waste_end
	hole.surface_spans = spans


# Some pads hang in the air, which the main course never does.
static func _float_some_pads(rng: RandomNumberGenerator, hole: HoleData, terrain: Terrain) -> void:
	for entry: Dictionary in hole.obstacles:
		if entry["kind"] == "pad" and rng.randf() < FLOATING_PAD_CHANCE:
			entry["y"] = round(terrain.ground_y(float(entry["x"])) - rng.randf_range(45.0, 95.0))


# Water returns the ball to where the shot started, so a pad aimed at water could send a good
# shot back to the same penalty again and again. This fires a real ball at each pad to see.
static func _remove_pads_aimed_at_water(hole: HoleData, terrain: Terrain) -> void:
	# One pass can leave a pad that only looked safe by bouncing off a pad now gone.
	for _pass in 3:
		var kept: Array = []
		var removed: bool = false
		for entry: Dictionary in hole.obstacles:
			if entry["kind"] == "pad" and _pad_fires_into_water(entry, hole, terrain):
				removed = true
			else:
				kept.append(entry)
		hole.obstacles = kept
		if not removed:
			return


static func _pad_fires_into_water(entry: Dictionary, hole: HoleData, terrain: Terrain) -> bool:
	var pad := BouncePadObstacle.new(terrain, entry)
	var sim := BallSim.new(terrain)
	sim.obstacles = Obstacle.build_all(hole, terrain)
	sim.wind = hole.wind
	sim.ignore_moving = true
	sim.place(pad.center.x)
	sim.pos = pad.center + pad.normal * 12.0
	sim.launch(-pad.normal * 120.0, 0.0)
	# Far from where the shot "started", so the pad doesn't let it pass.
	sim.launch_x = 0.0
	sim.launch_y = 0.0
	var steps: int = 0
	while sim.is_moving() and steps < 1200:
		sim.step(1.0 / 60.0)
		steps += 1
	return sim.state == BallSim.State.IN_WATER


static func _add_coins(rng: RandomNumberGenerator, hole: HoleData, terrain: Terrain) -> void:
	var from_x: float = hole.tee_x + 140.0
	var to_x: float = hole.cup_x - 50.0
	for i in COINS_PER_HOLE:
		var x: float = lerpf(from_x, to_x, (float(i) + 0.5) / float(COINS_PER_HOLE))
		x = round(x + rng.randf_range(-12.0, 12.0))
		hole.obstacles.append({ "kind": "coin", "x": x, "y": round(terrain.ground_y(x) - rng.randf_range(45.0, 80.0)) })


# Trees stay clear of the tee, the pin, and anywhere they'd stand in water or sand.
static func _add_trees(rng: RandomNumberGenerator, hole: HoleData, layout: Array[Dictionary]) -> void:
	var length: float = hole.points[hole.points.size() - 1].x
	var wanted: int = 3 + int(length / 500.0)
	var variant: int = rng.randi_range(0, HoleIO.LEAF_VARIANTS - 1)
	var placed: Array[float] = []
	for _try in wanted * 6:
		if placed.size() >= wanted:
			break
		var x: float = round(rng.randf_range(10.0, length - 10.0))
		if not _spot_suits_a_tree(hole, layout, placed, x):
			continue
		placed.append(x)
		hole.scenery.append_array(HoleIO.tree_pieces(x, variant))
		variant = (variant + 1) % HoleIO.LEAF_VARIANTS


static func _spot_suits_a_tree(hole: HoleData, layout: Array[Dictionary], placed: Array[float], x: float) -> bool:
	if absf(x - hole.tee_x) < 60.0 or absf(x - hole.cup_x) < 75.0:
		return false
	for other in placed:
		if absf(other - x) < 60.0:
			return false
	for slot: Dictionary in layout:
		var kind: String = slot["kind"]
		if kind == "ridge" or kind == "rough":
			continue
		if x > float(slot["x"]) - 25.0 and x < float(slot["x"]) + float(slot["width"]) + 25.0:
			return false
	return true


# Flips a finished hole end for end, so it plays right to left. The physics are the same both
# ways, so it stays exactly as fair.
static func _mirror(hole: HoleData) -> void:
	var length: float = hole.points[hole.points.size() - 1].x
	var flipped := PackedVector2Array()
	for i in range(hole.points.size() - 1, -1, -1):
		flipped.append(Vector2(length - hole.points[i].x, hole.points[i].y))
	hole.points = flipped
	hole.tee_x = length - hole.tee_x
	hole.cup_x = length - hole.cup_x
	hole.wind = -hole.wind
	for span: Dictionary in hole.surface_spans:
		_mirror_span(span, length)
	for span: Dictionary in hole.water_spans:
		_mirror_span(span, length)
	for piece: Dictionary in hole.scenery:
		piece["x"] = length - float(piece["x"])
	for entry: Dictionary in hole.obstacles:
		if entry.has("x"):
			entry["x"] = length - float(entry["x"])
		if entry.has("from"):
			var from_x: float = float(entry["from"])
			entry["from"] = length - float(entry["to"])
			entry["to"] = length - from_x
		if entry.has("start"):
			entry["start"] = length - float(entry["start"])
		if entry.has("rotation"):
			entry["rotation"] = -float(entry["rotation"])
		if entry.has("side"):
			entry["side"] = -float(entry["side"])


static func _mirror_span(span: Dictionary, length: float) -> void:
	var from_x: int = int(span["from"])
	span["from"] = int(length) - int(span["to"])
	span["to"] = int(length) - from_x
