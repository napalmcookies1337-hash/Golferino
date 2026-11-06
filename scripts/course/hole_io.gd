class_name HoleIO
extends RefCounted
## Converts holes to and from plain dictionaries, for saving maps as JSON. Anything read
## back is cleaned up, so a damaged file can't crash the game.

const MIN_POINT_GAP := 2.0
const MAX_LENGTH := 8000.0
const KNOWN_KINDS := ["pad", "cart", "windmill", "sprinkler", "goose", "coin", "frog", "vent", "gator", "lily"]
## Maps saved before coins existed don't have this, so they get the original hole's coins.
const COIN_VERSION_KEY := "coin_version"
const LEAF_VARIANTS := 3


## The two pieces of a whole tree, arranged to look like one tree.
static func tree_pieces(x: float, variant: int) -> Array:
	return [
		{ "kind": "trunk", "x": x, "height": 0.0 },
		{ "kind": "leaves", "x": x, "height": leaves_height(variant), "variant": variant },
	]


## How high a whole tree's leaves sit above the ground.
static func leaves_height(variant: int) -> float:
	return 37.0 + 4.0 * float(variant)


static func to_dict(hole: HoleData) -> Dictionary:
	var points: Array = []
	for point in hole.points:
		points.append([point.x, point.y])
	return {
		"title": hole.title,
		"biome": hole.biome,
		"par": hole.par,
		"tee_x": hole.tee_x,
		"cup_x": hole.cup_x,
		"wind": hole.wind,
		"points": points,
		"surface_spans": hole.surface_spans.duplicate(true),
		"water_spans": hole.water_spans.duplicate(true),
		"obstacles": hole.obstacles.duplicate(true),
		"scenery": hole.scenery.duplicate(true),
		COIN_VERSION_KEY: 1,
	}


## Returns null if the data can't make a playable hole.
static func from_dict(data: Variant) -> HoleData:
	if not data is Dictionary:
		return null
	var points := _read_points(data.get("points", null))
	if points.size() < 2:
		return null
	var length: float = points[points.size() - 1].x

	var hole := HoleData.new()
	hole.points = points
	hole.title = str(data.get("title", "UNTITLED"))
	hole.biome = HoleData.BIOME_SWAMP if str(data.get("biome", "")) == HoleData.BIOME_SWAMP else HoleData.BIOME_GRASSY
	hole.par = clampi(_number(data, "par", 4.0) as int, 1, 12)
	hole.tee_x = clampf(_number(data, "tee_x", 90.0), 0.0, length)
	hole.cup_x = clampf(_number(data, "cup_x", length - 100.0), 10.0, length - 10.0)
	hole.wind = clampf(_number(data, "wind", 0.0), -60.0, 60.0)
	hole.surface_spans = _read_spans(data.get("surface_spans", []), "type")
	hole.water_spans = _read_spans(data.get("water_spans", []), "level")
	hole.obstacles = _read_obstacles(data.get("obstacles", []))
	hole.scenery = _read_scenery(data, length)
	return hole


# Maps saved before trees had separate pieces list whole trees, which split up here.
static func _read_scenery(data: Dictionary, length: float) -> Array:
	var pieces: Array = []
	var raw: Variant = data.get("scenery", [])
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary or not _is_number(entry.get("x")):
				continue
			var kind: String = str(entry.get("kind", ""))
			if kind != "trunk" and kind != "leaves":
				continue
			var piece: Dictionary = {
				"kind": kind,
				"x": clampf(float(entry["x"]), 0.0, length),
				"height": _number(entry, "height", 0.0),
			}
			if kind == "leaves":
				piece["variant"] = clampi(int(_number(entry, "variant", 0.0)), 0, LEAF_VARIANTS - 1)
			pieces.append(piece)
	var old_trees: Variant = data.get("trees", [])
	if old_trees is Array:
		var index: int = 0
		for x: Variant in old_trees:
			if _is_number(x):
				pieces.append_array(tree_pieces(clampf(float(x), 0.0, length), index % LEAF_VARIANTS))
				index += 1
	return pieces


## A plain starting map: flat ground with a tee and a green.
static func blank_hole(title: String) -> HoleData:
	var hole := HoleData.new()
	hole.title = title
	hole.par = 4
	hole.tee_x = 90.0
	hole.cup_x = 1000.0
	hole.points = PackedVector2Array([
		Vector2(0, 300), Vector2(300, 300), Vector2(700, 300), Vector2(1200, 300)])
	hole.surface_spans = [
		{ "from": 50, "to": 130, "type": Surface.Type.TEE },
		{ "from": 130, "to": 880, "type": Surface.Type.FAIRWAY },
		{ "from": 880, "to": 1120, "type": Surface.Type.GREEN },
	]
	return hole


static func _number(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	return float(value) if value is float or value is int else fallback


static func _read_points(raw: Variant) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not raw is Array:
		return points
	for entry: Variant in raw:
		if not entry is Array or entry.size() < 2:
			continue
		if not (entry[0] is float or entry[0] is int) or not (entry[1] is float or entry[1] is int):
			continue
		var point := Vector2(clampf(float(entry[0]), 0.0, MAX_LENGTH), clampf(float(entry[1]), 0.0, float(Terrain.WORLD_HEIGHT)))
		# Terrain needs strictly increasing x.
		if points.is_empty() or point.x >= points[points.size() - 1].x + MIN_POINT_GAP:
			points.append(point)
	# The ground has to start at the left edge of the world.
	if not points.is_empty() and points[0].x > 0.0:
		points.insert(0, Vector2(0.0, points[0].y))
	return points


static func _read_spans(raw: Variant, extra_key: String) -> Array:
	var spans: Array = []
	if not raw is Array:
		return spans
	for entry: Variant in raw:
		if not entry is Dictionary or not entry.has("from") or not entry.has("to") or not entry.has(extra_key):
			continue
		var span: Dictionary = { "from": int(entry["from"]), "to": int(entry["to"]) }
		if extra_key == "type":
			var type: int = int(entry["type"])
			if not Surface.PROPS.has(type) or type == Surface.Type.LILY:
				continue
			span["type"] = type
		else:
			span[extra_key] = float(entry[extra_key])
		spans.append(span)
	return spans


static func _read_obstacles(raw: Variant) -> Array:
	var obstacles: Array = []
	if not raw is Array:
		return obstacles
	for entry: Variant in raw:
		if entry is Dictionary and KNOWN_KINDS.has(str(entry.get("kind", ""))) and _has_required_keys(entry):
			obstacles.append(entry.duplicate(true))
	return obstacles


static func _has_required_keys(entry: Dictionary) -> bool:
	match str(entry["kind"]):
		"cart", "goose", "frog":
			return _is_number(entry.get("from")) and _is_number(entry.get("to"))
		"coin":
			return _is_number(entry.get("x")) and _is_number(entry.get("y"))
		_:
			return _is_number(entry.get("x"))


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
