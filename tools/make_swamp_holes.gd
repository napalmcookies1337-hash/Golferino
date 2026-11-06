extends SceneTree
## Writes the Swampy Shores course: nine holes and a boss, as ordinary hole files. The files are
## what the game loads, and the map editor can change them like any other original.
## Run with: Godot --headless --path . -s tools/make_swamp_holes.gd

const TEE := Surface.Type.TEE
const FAIRWAY := Surface.Type.FAIRWAY
const GREEN := Surface.Type.GREEN
const MUD := Surface.Type.MUD
const SAND := Surface.Type.SAND
const OUT_DIR := "res://data/holes"
const COURSE_PATH := "res://data/course_02.tres"
const COINS_PER_HOLE := 8


func _initialize() -> void:
	var holes: Array[Dictionary] = [
		_stretched(_soggy_start(), 1.2), _lily_hop(), _stretched(_frog_crossing(), 1.15), _stretched(_gasworks(), 1.18), _rotten_mill(),
		_the_long_bog(), _stretched(_gator_alley(), 1.12), _stepping_pads(), _sinking_feeling(), _the_deep_mire(),
	]
	var paths := PackedStringArray()
	for i in holes.size():
		var is_boss: bool = i == holes.size() - 1
		var file_name: String = "swamp_boss" if is_boss else "swamp_%02d" % (i + 1)
		var hole: HoleData = _build(holes[i], "BOSS HOLE" if is_boss else "HOLE %d" % (i + 1))
		var path: String = "%s/%s.tres" % [OUT_DIR, file_name]
		if ResourceSaver.save(hole, path) != OK:
			push_error("couldn't save %s" % path)
		paths.append(path)
		print("%-10s %-18s par %d, %4d yards" % [hole.display_name, hole.title, hole.par, int(absf(hole.cup_x - hole.tee_x) / 3.0)])
	var course := CourseData.new()
	course.display_name = "SWAMPY SHORES"
	course.hole_paths = paths
	if ResourceSaver.save(course, COURSE_PATH) != OK:
		push_error("couldn't save the course")
	print("swamp holes finished")
	quit()


# Lengthens everything after the tee by a share, keeping the shape and what's on it.
func _stretched(spec: Dictionary, by: float) -> Dictionary:
	var at := func(x: float) -> float: return round(x if x <= 130.0 else 130.0 + (x - 130.0) * by)
	spec["cup"] = at.call(float(spec["cup"]))
	for point: Array in spec["ground"]:
		point[0] = at.call(float(point[0]))
	for span: Array in spec["surfaces"]:
		span[0] = at.call(float(span[0]))
		span[1] = at.call(float(span[1]))
	for span: Array in spec.get("water", []):
		span[0] = at.call(float(span[0]))
		span[1] = at.call(float(span[1]))
	for entry: Dictionary in spec.get("things", []):
		for key: String in ["x", "from", "to", "start"]:
			if entry.has(key):
				entry[key] = at.call(float(entry[key]))
	var trees: Array = spec.get("trees", [])
	for i in trees.size():
		trees[i] = at.call(float(trees[i]))
	return spec


func _build(spec: Dictionary, display_name: String) -> HoleData:
	var hole := HoleData.new()
	hole.biome = HoleData.BIOME_SWAMP
	hole.display_name = display_name
	hole.title = spec["title"]
	hole.par = spec["par"]
	hole.tee_x = 90.0
	hole.cup_x = spec["cup"]
	hole.wind = spec.get("wind", 0.0)
	var points := PackedVector2Array()
	for point: Array in spec["ground"]:
		points.append(Vector2(point[0], point[1]))
	hole.points = points
	var surfaces: Array = []
	for span: Array in spec["surfaces"]:
		surfaces.append({ "from": span[0], "to": span[1], "type": span[2] })
	hole.surface_spans = surfaces
	var water: Array = []
	for span: Array in spec.get("water", []):
		water.append({ "from": span[0], "to": span[1], "level": float(span[2]) })
	hole.water_spans = water
	var obstacles: Array = (spec.get("things", []) as Array).duplicate(true)
	hole.obstacles = obstacles
	var scenery: Array = []
	var variant: int = 0
	for x: float in spec.get("trees", []):
		scenery.append_array(HoleIO.tree_pieces(x, variant))
		variant = (variant + 1) % HoleIO.LEAF_VARIANTS
	hole.scenery = scenery
	_add_coins(hole)
	return hole


# Spread along the hole, in reach of a good shot. A pattern, so the file comes out the same.
func _add_coins(hole: HoleData) -> void:
	var terrain := Terrain.new(hole)
	var obstacles: Array = hole.obstacles
	for i in COINS_PER_HOLE:
		var x: float = round(lerpf(hole.tee_x + 140.0, hole.cup_x - 50.0, (float(i) + 0.5) / float(COINS_PER_HOLE)))
		var y: float = round(terrain.ground_y(x) - 48.0 - float((i * 37) % 30))
		obstacles.append({ "kind": "coin", "x": x, "y": y })
	hole.obstacles = obstacles


func _frog(from_x: float, to_x: float, speed: float = 70.0) -> Dictionary:
	return { "kind": "frog", "from": from_x, "to": to_x, "start": (from_x + to_x) / 2.0, "speed": speed }


func _vent(x: float, offset: float = 0.0, height: float = 85.0) -> Dictionary:
	return { "kind": "vent", "x": x, "height": height, "quiet_time": 2.6, "burst_time": 1.1, "offset": offset }


func _gator(x: float) -> Dictionary:
	return { "kind": "gator", "x": x, "side": -1.0 }


func _windmill(x: float, turn_speed: float = 1.1) -> Dictionary:
	return { "kind": "windmill", "x": x, "rotation": 0.0, "turn_speed": turn_speed }


func _lily(x: float, width: float = 56.0) -> Dictionary:
	return { "kind": "lily", "x": x, "width": width }


# --- The holes ---

# Introduces mud: a soft patch in the driving zone, with firm ground either side.
func _soggy_start() -> Dictionary:
	return {
		"title": "SOGGY START", "par": 4, "cup": 1140.0,
		"ground": [[0, 296], [60, 300], [130, 302], [330, 298], [520, 304], [610, 318], [770, 316], [880, 300], [1010, 292], [1140, 290], [1260, 292], [1400, 268]],
		"surfaces": [[60, 130, TEE], [130, 545, FAIRWAY], [545, 815, MUD], [815, 1030, FAIRWAY], [1030, 1250, GREEN]],
		"trees": [40.0, 300.0, 470.0, 860.0, 1320.0],
	}


# Introduces lily pads: a short carry over water, with two pads to bail out on.
func _lily_hop() -> Dictionary:
	return {
		"title": "LILY HOP", "par": 3, "cup": 590.0,
		"ground": [[0, 290], [60, 300], [130, 300], [180, 304], [235, 348], [450, 350], [505, 302], [590, 296], [690, 298], [840, 276]],
		"surfaces": [[60, 130, TEE], [130, 200, FAIRWAY], [505, 690, GREEN]],
		"water": [[190, 495, 325]],
		"things": [_lily(290.0, 60.0), _lily(400.0, 60.0)],
		"trees": [30.0, 730.0, 800.0],
	}


# Introduces frogs: two stretches of open fairway with something hopping across them.
func _frog_crossing() -> Dictionary:
	return {
		"title": "FROG CROSSING", "par": 4, "cup": 1290.0,
		"ground": [[0, 310], [60, 306], [130, 304], [300, 296], [480, 288], [640, 292], [740, 306], [900, 300], [1060, 284], [1180, 276], [1290, 274], [1410, 276], [1540, 250]],
		"surfaces": [[60, 130, TEE], [130, 1180, FAIRWAY], [1180, 1400, GREEN]],
		"things": [_frog(370.0, 640.0, 65.0), _frog(800.0, 1080.0, 75.0)],
		"trees": [240.0, 720.0, 1130.0, 1480.0],
	}


# Introduces gas vents: three in a row on a flat, off in time with each other, and mud beyond.
func _gasworks() -> Dictionary:
	return {
		"title": "GASWORKS", "par": 4, "cup": 1220.0,
		"ground": [[0, 300], [60, 304], [130, 306], [320, 302], [450, 296], [760, 298], [850, 310], [960, 306], [1080, 290], [1220, 286], [1340, 288], [1480, 262]],
		"surfaces": [[60, 130, TEE], [130, 780, FAIRWAY], [780, 960, MUD], [960, 1110, FAIRWAY], [1110, 1330, GREEN]],
		"things": [_vent(490.0, 0.0), _vent(600.0, 1.3), _vent(710.0, 2.6)],
		"trees": [260.0, 400.0, 1040.0, 1420.0],
	}


# Introduces the swamp's windmill: a short hole with the green just past a rotting old one.
func _rotten_mill() -> Dictionary:
	return {
		"title": "ROTTEN MILL", "par": 3, "cup": 660.0,
		"ground": [[0, 296], [60, 292], [130, 290], [300, 286], [430, 292], [550, 288], [660, 284], [770, 286], [920, 258]],
		"surfaces": [[60, 130, TEE], [130, 460, FAIRWAY], [460, 560, MUD], [560, 770, GREEN]],
		"things": [_windmill(510.0)],
		"trees": [40.0, 210.0, 830.0],
	}


# A long slog: mud across the middle, a pond with a pad in it, and a vent past that.
func _the_long_bog() -> Dictionary:
	return {
		"title": "THE LONG BOG", "par": 5, "cup": 2060.0,
		"ground": [[0, 280], [60, 284], [130, 286], [360, 290], [560, 302], [720, 312], [900, 310], [1010, 304], [1060, 352], [1240, 356], [1300, 302], [1460, 292], [1640, 290], [1820, 280], [1950, 276], [2060, 274], [2180, 276], [2320, 248]],
		"surfaces": [[60, 130, TEE], [130, 560, FAIRWAY], [560, 1010, MUD], [1310, 1860, FAIRWAY], [1720, 1800, MUD], [1950, 2170, GREEN]],
		"water": [[1020, 1295, 328]],
		"things": [_lily(1150.0, 64.0), _vent(1560.0, 1.0, 90.0), _frog(1340.0, 1500.0, 70.0), _gator(1660.0)],
		"trees": [320.0, 470.0, 1400.0, 1680.0, 2240.0],
	}


# Introduces gators: three lying along the fairway, into a headwind, with a frog near the end.
func _gator_alley() -> Dictionary:
	return {
		"title": "GATOR ALLEY", "par": 4, "cup": 1430.0,
		"wind": -7.0,
		"ground": [[0, 306], [60, 302], [130, 300], [340, 294], [520, 298], [720, 288], [880, 292], [1060, 282], [1210, 280], [1320, 276], [1430, 274], [1550, 276], [1680, 252]],
		"surfaces": [[60, 130, TEE], [130, 1320, FAIRWAY], [1320, 1540, GREEN]],
		"things": [_gator(490.0), _gator(840.0), _gator(1170.0), _frog(930.0, 1120.0, 70.0)],
		"trees": [270.0, 660.0, 1030.0, 1610.0],
	}


# Two wide ponds, each only safely crossed in two by using its lily pads. Frogs hop on the second.
func _stepping_pads() -> Dictionary:
	return {
		"title": "STEPPING PADS", "par": 5, "cup": 2120.0,
		"ground": [[0, 292], [60, 296], [130, 296], [340, 298], [480, 300], [530, 356], [790, 360], [840, 298], [1010, 290], [1180, 294], [1225, 354], [1540, 358], [1590, 296], [1760, 284], [1990, 278], [2120, 276], [2240, 278], [2380, 254]],
		"surfaces": [[60, 130, TEE], [130, 490, FAIRWAY], [835, 1190, FAIRWAY], [1585, 2010, FAIRWAY], [2010, 2230, GREEN]],
		"water": [[495, 830, 325], [1195, 1580, 322]],
		"things": [_lily(600.0, 62.0), _lily(725.0, 62.0), _lily(1290.0, 62.0), _lily(1395.0, 62.0), _lily(1500.0, 62.0), _frog(1270.0, 1520.0, 55.0), _gator(1010.0)],
		"trees": [320.0, 950.0, 1110.0, 1700.0, 1870.0, 2310.0],
	}


# Everything so far, climbing out of the swamp to a high green.
func _sinking_feeling() -> Dictionary:
	return {
		"title": "SINKING FEELING", "par": 5, "cup": 2240.0,
		"ground": [[0, 340], [60, 344], [130, 346], [330, 340], [520, 332], [680, 336], [790, 332], [840, 384], [1030, 388], [1085, 328], [1260, 310], [1420, 306], [1620, 280], [1800, 262], [1980, 246], [2120, 236], [2240, 234], [2360, 236], [2490, 208]],
		"surfaces": [[60, 130, TEE], [130, 520, FAIRWAY], [520, 620, MUD], [620, 790, FAIRWAY], [1090, 1300, FAIRWAY], [1300, 1480, MUD], [1480, 2130, FAIRWAY], [2130, 2350, GREEN]],
		"water": [[795, 1080, 358]],
		"things": [_frog(240.0, 500.0, 70.0), _lily(880.0, 62.0), _lily(1000.0, 62.0), _vent(1200.0, 0.5), _windmill(1590.0, 1.2), _gator(1720.0), _vent(1830.0, 2.0, 95.0), _frog(1880.0, 2100.0, 80.0)],
		"trees": [410.0, 720.0, 1150.0, 1720.0, 2050.0, 2440.0],
	}


# The rematch: a long gauntlet with every hazard the swamp has, and its pads to keep it honest.
func _the_deep_mire() -> Dictionary:
	return {
		"title": "THE DEEP MIRE", "par": 7, "cup": 3040.0,
		"ground": [[0, 300], [60, 304], [130, 306], [340, 304], [520, 298], [690, 302], [860, 292], [1020, 296], [1180, 292], [1230, 354], [1540, 358], [1590, 296], [1760, 300], [1930, 306], [2110, 296], [2280, 290], [2450, 284], [2640, 276], [2800, 272], [2920, 268], [3040, 266], [3160, 268], [3300, 242]],
		"surfaces": [[60, 130, TEE], [130, 700, FAIRWAY], [700, 860, MUD], [860, 1190, FAIRWAY], [1590, 1740, FAIRWAY], [1740, 1960, MUD], [1960, 2460, FAIRWAY], [2460, 2610, MUD], [2610, 2930, FAIRWAY], [2930, 3150, GREEN]],
		"water": [[1195, 1580, 326]],
		"things": [
			_frog(320.0, 660.0, 75.0),
			_vent(960.0, 0.0),
			{ "kind": "pad", "x": 1100.0, "rotation": -22.0 },
			_lily(1300.0, 60.0), _lily(1400.0, 60.0), _lily(1500.0, 60.0),
			_windmill(1680.0, 1.2),
			_vent(2080.0, 1.4),
			_gator(2300.0),
			_frog(2130.0, 2420.0, 80.0),
			{ "kind": "pad", "x": 2530.0, "rotation": 18.0 },
			_gator(2710.0),
			_vent(2850.0, 2.4, 95.0),
		],
		"trees": [240.0, 780.0, 1650.0, 2010.0, 2590.0, 3230.0],
	}
