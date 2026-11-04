class_name HoleIO
extends RefCounted
## Converts holes to and from plain dictionaries, for saving maps as JSON. Anything read
## back is cleaned up, so a damaged file can't crash the game.

const MIN_POINT_GAP := 2.0
const MAX_LENGTH := 8000.0
const KNOWN_KINDS := ["pad", "cart", "windmill", "sprinkler", "goose"]


static func to_dict(hole: HoleData) -> Dictionary:
	var points: Array = []
	for point in hole.points:
		points.append([point.x, point.y])
	var trees: Array = []
	for x: float in hole.tree_xs:
		trees.append(x)
	return {
		"title": hole.title,
		"par": hole.par,
		"tee_x": hole.tee_x,
		"cup_x": hole.cup_x,
		"wind": hole.wind,
		"points": points,
		"surface_spans": hole.surface_spans.duplicate(true),
		"water_spans": hole.water_spans.duplicate(true),
		"obstacles": hole.obstacles.duplicate(true),
		"trees": trees,
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
	hole.par = clampi(_number(data, "par", 4.0) as int, 1, 12)
	hole.tee_x = clampf(_number(data, "tee_x", 90.0), 0.0, length)
	hole.cup_x = clampf(_number(data, "cup_x", length - 100.0), 10.0, length - 10.0)
	hole.wind = clampf(_number(data, "wind", 0.0), -60.0, 60.0)
	hole.surface_spans = _read_spans(data.get("surface_spans", []), "type")
	hole.water_spans = _read_spans(data.get("water_spans", []), "level")
	hole.obstacles = _read_obstacles(data.get("obstacles", []))
	var trees := PackedFloat32Array()
	var tree_list: Variant = data.get("trees", [])
	if tree_list is Array:
		for x: Variant in tree_list:
			if x is float or x is int:
				trees.append(clampf(float(x), 0.0, length))
	hole.tree_xs = trees
	return hole


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
			if type < 0 or type > Surface.Type.WATER:
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
		"cart", "goose":
			return _is_number(entry.get("from")) and _is_number(entry.get("to"))
		_:
			return _is_number(entry.get("x"))


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
