class_name EditorDoc
extends RefCounted
## The map being edited, and every change that can be made to it. No drawing or input
## here, so all of it can be tested directly. A selection is a dictionary:
## { "type": "obstacle", "index": n }, { "type": "scenery", "index": n },
## { "type": "water", "index": n }, { "type": "tee" } or { "type": "cup" }.

const MIN_POINT_GAP := 12.0
const MIN_LENGTH := 400.0
const MAX_LENGTH := 6000.0
const MIN_Y := 60.0
const MAX_Y := 500.0
const MIN_ROUTE := 30.0
const UNDO_LIMIT := 60
const ROTATION_SNAP := 15.0
## Only things that stay put can rotate. Carts and geese travel along routes.
const ROTATING_KINDS := ["pad", "windmill", "sprinkler"]
## A trunk dropped or dragged this close to the ground stands on it.
const TRUNK_GROUND_SNAP := 8.0
## From a trunk's base up to the middle of it.
const TRUNK_MIDDLE := 10.0

var hole: HoleData
var terrain: Terrain
var dirty: bool = false

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func _init(p_hole: HoleData) -> void:
	hole = p_hole
	rebake()


func rebake() -> void:
	terrain = Terrain.new(hole)


func length() -> float:
	return hole.points[hole.points.size() - 1].x


# --- Undo ---

## Call before a change, so that it can be undone.
func checkpoint() -> void:
	_undo.append(HoleIO.to_dict(hole))
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> void:
	if can_undo():
		_redo.append(HoleIO.to_dict(hole))
		_restore(_undo.pop_back())


func redo() -> void:
	if can_redo():
		_undo.append(HoleIO.to_dict(hole))
		_restore(_redo.pop_back())


func _restore(state: Dictionary) -> void:
	var restored: HoleData = HoleIO.from_dict(state)
	if restored == null:
		return
	restored.display_name = hole.display_name
	hole = restored
	dirty = true
	rebake()


# --- Ground ---

func point_near(at: Vector2, radius: float) -> int:
	var best: int = -1
	var best_distance: float = radius
	for i in hole.points.size():
		var distance: float = hole.points[i].distance_to(at)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


## Adds a ground point and returns its index, or -1 if it's too close to another.
func add_point(at: Vector2) -> int:
	if at.x <= 0.0 or at.x >= length():
		return -1
	for point in hole.points:
		if absf(point.x - at.x) < MIN_POINT_GAP:
			return -1
	var index: int = 0
	while hole.points[index].x < at.x:
		index += 1
	var points: PackedVector2Array = hole.points
	points.insert(index, Vector2(at.x, clampf(at.y, MIN_Y, MAX_Y)))
	hole.points = points
	rebake()
	return index


## The first point stays at the left edge. Moving the last point changes the hole's length.
func move_point(index: int, at: Vector2) -> void:
	var points: PackedVector2Array = hole.points
	var last: int = points.size() - 1
	var x: float = at.x
	if index == 0:
		x = 0.0
	elif index == last:
		x = clampf(x, maxf(points[last - 1].x + MIN_POINT_GAP, MIN_LENGTH), MAX_LENGTH)
	else:
		x = clampf(x, points[index - 1].x + MIN_POINT_GAP, points[index + 1].x - MIN_POINT_GAP)
	points[index] = Vector2(x, clampf(at.y, MIN_Y, MAX_Y))
	hole.points = points
	if index == last:
		_keep_inside_hole()
	rebake()


## The end points can't be removed, and a hole always keeps at least three.
func remove_point(index: int) -> bool:
	if index <= 0 or index >= hole.points.size() - 1 or hole.points.size() <= 3:
		return false
	var points: PackedVector2Array = hole.points
	points.remove_at(index)
	hole.points = points
	rebake()
	return true


func _keep_inside_hole() -> void:
	var end: float = length()
	hole.tee_x = minf(hole.tee_x, end - 20.0)
	hole.cup_x = minf(hole.cup_x, end - 20.0)


# --- Surfaces ---

## Paints a stretch of ground. Painting over water removes the water.
func paint_surface(from_x: float, to_x: float, type: int) -> void:
	var a: int = int(clampf(minf(from_x, to_x), 0.0, length()))
	var b: int = int(clampf(maxf(from_x, to_x), 0.0, length()))
	if b <= a:
		return
	if type == Surface.Type.WATER:
		paint_water(float(a), float(b))
		return
	_cut_water(a, b)
	var spans: Array = hole.surface_spans
	spans.append({ "from": a, "to": b, "type": type })
	hole.surface_spans = _merged_spans(spans)
	rebake()


## Floods a stretch up to the lower of its two edges, so the water looks held in.
func paint_water(from_x: float, to_x: float) -> void:
	var a: int = int(minf(from_x, to_x))
	var b: int = int(maxf(from_x, to_x))
	_cut_water(a, b)
	var level: float = maxf(terrain.basin_y(float(a)), terrain.basin_y(float(b)))
	var spans: Array = hole.water_spans
	spans.append({ "from": a, "to": b, "level": level })
	hole.water_spans = spans
	rebake()


func _cut_water(a: int, b: int) -> void:
	var kept: Array = []
	for span: Dictionary in hole.water_spans:
		var from_x: int = int(span["from"])
		var to_x: int = int(span["to"])
		if to_x <= a or from_x >= b:
			kept.append(span)
			continue
		if from_x < a:
			kept.append({ "from": from_x, "to": a, "level": span["level"] })
		if to_x > b:
			kept.append({ "from": b, "to": to_x, "level": span["level"] })
	hole.water_spans = kept


# Rewrites overlapping paint strokes as a clean list, so files don't grow with every stroke.
func _merged_spans(spans: Array) -> Array:
	var size: int = int(length()) + 1
	var cells := PackedByteArray()
	cells.resize(size)
	cells.fill(Surface.Type.ROUGH)
	for span: Dictionary in spans:
		for x in range(clampi(int(span["from"]), 0, size), clampi(int(span["to"]), 0, size)):
			cells[x] = int(span["type"])
	var merged: Array = []
	var start: int = 0
	for x in range(1, size + 1):
		if x == size or cells[x] != cells[start]:
			if cells[start] != Surface.Type.ROUGH:
				merged.append({ "from": start, "to": x, "type": int(cells[start]) })
			start = x
	return merged


# --- Objects ---

## Adds an object at a world position and returns a selection for it.
func add_object(kind: String, at: Vector2) -> Dictionary:
	var x: float = clampf(at.x, 10.0, length() - 10.0)
	if kind == "trunk" or kind == "leaves":
		return _add_scenery(kind, x, at.y)
	var entry: Dictionary = { "kind": kind }
	match kind:
		"pad":
			entry.merge({ "x": x, "y": at.y, "rotation": 0.0, "power": BouncePadObstacle.DEFAULT_POWER })
		"cart":
			entry.merge({ "from": x - 100.0, "to": x + 100.0, "speed": 50.0 })
		"windmill":
			entry.merge({ "x": x, "rotation": 0.0, "turn_speed": 1.2 })
		"sprinkler":
			entry.merge({ "x": x, "rotation": 0.0, "height": 70.0, "on_time": 2.5, "off_time": 2.0, "offset": 0.0 })
		"goose":
			entry.merge({ "from": x - 100.0, "to": x + 100.0, "start": x, "speed": 60.0 })
			entry["height"] = maxf(terrain.ground_y(x - 100.0) - at.y, 20.0)
	var obstacles: Array = hole.obstacles
	obstacles.append(entry)
	hole.obstacles = obstacles
	return { "type": "obstacle", "index": obstacles.size() - 1 }


func _add_scenery(kind: String, x: float, y: float) -> Dictionary:
	var ground: float = terrain.ground_y(x)
	var piece: Dictionary = { "kind": kind, "x": x }
	if kind == "trunk":
		piece["height"] = _trunk_height(ground - y)
	else:
		piece["height"] = ground - y
		# Each new set of leaves takes the next shape, for variety. The panel can change it.
		var count: int = 0
		for other: Dictionary in hole.scenery:
			if str(other["kind"]) == "leaves":
				count += 1
		piece["variant"] = count % HoleIO.LEAF_VARIANTS
	var scenery: Array = hole.scenery
	scenery.append(piece)
	hole.scenery = scenery
	return { "type": "scenery", "index": scenery.size() - 1 }


func _trunk_height(wanted: float) -> float:
	return 0.0 if absf(wanted) <= TRUNK_GROUND_SNAP else wanted


## The tree piece selected, or an empty dictionary if the selection isn't one.
func piece_of(selection: Dictionary) -> Dictionary:
	if str(selection.get("type", "")) != "scenery":
		return {}
	return hole.scenery[int(selection["index"])]


func rest_trunk_on_ground(selection: Dictionary) -> void:
	var piece: Dictionary = piece_of(selection)
	if str(piece.get("kind", "")) == "trunk":
		piece["height"] = 0.0


func delete_selection(selection: Dictionary) -> void:
	match str(selection.get("type", "")):
		"obstacle":
			var obstacles: Array = hole.obstacles
			obstacles.remove_at(int(selection["index"]))
			hole.obstacles = obstacles
		"scenery":
			var scenery: Array = hole.scenery
			scenery.remove_at(int(selection["index"]))
			hole.scenery = scenery
		"water":
			var spans: Array = hole.water_spans
			spans.remove_at(int(selection["index"]))
			hole.water_spans = spans
			rebake()


func can_delete(selection: Dictionary) -> bool:
	return ["obstacle", "scenery", "water"].has(str(selection.get("type", "")))


## The object's entry in the hole, or an empty dictionary if the selection isn't one.
func entry_of(selection: Dictionary) -> Dictionary:
	if str(selection.get("type", "")) != "obstacle":
		return {}
	return hole.obstacles[int(selection["index"])]


func selection_center(selection: Dictionary) -> Vector2:
	match str(selection.get("type", "")):
		"tee":
			return Vector2(hole.tee_x, terrain.ground_y(hole.tee_x))
		"cup":
			return Vector2(hole.cup_x, terrain.rim_y)
		"scenery":
			return _piece_center(piece_of(selection))
		"water":
			var span: Dictionary = hole.water_spans[int(selection["index"])]
			return Vector2((float(span["from"]) + float(span["to"])) / 2.0, float(span["level"]))
		"obstacle":
			return _object_center(entry_of(selection))
	return Vector2.ZERO


func _piece_center(piece: Dictionary) -> Vector2:
	var x: float = float(piece["x"])
	var y: float = terrain.ground_y(x) - float(piece.get("height", 0.0))
	if str(piece["kind"]) == "trunk":
		y -= TRUNK_MIDDLE
	return Vector2(x, y)


func _object_center(entry: Dictionary) -> Vector2:
	match str(entry["kind"]):
		"pad":
			var pad := BouncePadObstacle.new(terrain, entry)
			return pad.center
		"cart":
			var mid: float = (float(entry["from"]) + float(entry["to"])) / 2.0
			return Vector2(mid, terrain.ground_y(mid) - CartObstacle.RIDE_HEIGHT)
		"goose":
			var goose := GooseObstacle.new(terrain, entry)
			return Vector2((goose.from_x + goose.to_x) / 2.0, goose.base_y)
		_:
			return Vector2(float(entry["x"]), terrain.ground_y(float(entry["x"])))


## The route's two ends for carts and geese, otherwise empty.
func route_ends(selection: Dictionary) -> Array[Vector2]:
	var entry: Dictionary = entry_of(selection)
	var ends: Array[Vector2] = []
	if entry.is_empty() or not ["cart", "goose"].has(str(entry["kind"])):
		return ends
	var from_x: float = float(entry["from"])
	var to_x: float = float(entry["to"])
	if str(entry["kind"]) == "cart":
		ends.append(Vector2(from_x, terrain.ground_y(from_x) - CartObstacle.RIDE_HEIGHT))
		ends.append(Vector2(to_x, terrain.ground_y(to_x) - CartObstacle.RIDE_HEIGHT))
	else:
		var y: float = GooseObstacle.new(terrain, entry).base_y
		ends.append(Vector2(from_x, y))
		ends.append(Vector2(to_x, y))
	return ends


func move_route_end(selection: Dictionary, end: int, x: float) -> void:
	var entry: Dictionary = entry_of(selection)
	var from_x: float = float(entry["from"])
	var to_x: float = float(entry["to"])
	var old_y: float = 0.0
	if str(entry["kind"]) == "goose":
		old_y = GooseObstacle.new(terrain, entry).base_y
	if end == 0:
		entry["from"] = clampf(x, 0.0, to_x - MIN_ROUTE)
	else:
		entry["to"] = clampf(x, from_x + MIN_ROUTE, length())
	if str(entry["kind"]) == "goose":
		# A goose's height is measured from its route's start. Keep it flying at the same level.
		entry["height"] = terrain.ground_y(float(entry["from"])) - old_y
		entry["start"] = clampf(float(entry["start"]), float(entry["from"]), float(entry["to"]))


## Moves the selected thing so its center is at a world position.
func move_selection(selection: Dictionary, at: Vector2) -> void:
	var x: float = clampf(at.x, 5.0, length() - 5.0)
	match str(selection.get("type", "")):
		"tee":
			hole.tee_x = x
		"cup":
			hole.cup_x = clampf(x, 20.0, length() - 20.0)
			rebake()
		"scenery":
			_move_piece(piece_of(selection), at, x)
		"water":
			var spans: Array = hole.water_spans
			spans[int(selection["index"])]["level"] = clampf(at.y, MIN_Y, MAX_Y)
			rebake()
		"obstacle":
			_move_object(entry_of(selection), at, x)


func _move_piece(piece: Dictionary, at: Vector2, x: float) -> void:
	var ground: float = terrain.ground_y(x)
	piece["x"] = x
	if str(piece["kind"]) == "trunk":
		piece["height"] = _trunk_height(ground - at.y - TRUNK_MIDDLE)
	else:
		piece["height"] = ground - at.y


func _move_object(entry: Dictionary, at: Vector2, x: float) -> void:
	match str(entry["kind"]):
		"pad":
			entry["x"] = x
			entry["y"] = clampf(at.y, -200.0, float(Terrain.WORLD_HEIGHT))
		"cart":
			var half: float = (float(entry["to"]) - float(entry["from"])) / 2.0
			var mid: float = clampf(x, half, length() - half)
			entry["from"] = mid - half
			entry["to"] = mid + half
		"goose":
			var half: float = (float(entry["to"]) - float(entry["from"])) / 2.0
			var mid: float = clampf(x, half, length() - half)
			var start_offset: float = float(entry["start"]) - (float(entry["from"]) + float(entry["to"])) / 2.0
			entry["from"] = mid - half
			entry["to"] = mid + half
			entry["start"] = mid + start_offset
			entry["height"] = maxf(terrain.ground_y(float(entry["from"])) - at.y, 10.0)
		_:
			entry["x"] = x


func can_rotate(selection: Dictionary) -> bool:
	var entry: Dictionary = entry_of(selection)
	return not entry.is_empty() and ROTATING_KINDS.has(str(entry["kind"]))


func rotation_of(selection: Dictionary) -> float:
	return float(entry_of(selection).get("rotation", 0.0))


## Sets rotation in degrees, wrapped to -180..180. Snapping uses 15 degree steps.
func set_rotation(selection: Dictionary, degrees: float, snap: bool = false) -> void:
	if not can_rotate(selection):
		return
	var value: float = degrees
	if snap:
		value = snappedf(value, ROTATION_SNAP)
	value = wrapf(value, -180.0, 180.0)
	var entry: Dictionary = entry_of(selection)
	# A grounded pad keeps its height when rotated, so it stays where it was placed.
	if str(entry["kind"]) == "pad" and not entry.has("y"):
		entry["y"] = BouncePadObstacle.new(terrain, entry).center.y
	entry["rotation"] = value


## What's under a world position, topmost first. Empty if nothing.
func pick(at: Vector2, radius: float) -> Dictionary:
	var obstacles: Array = hole.obstacles
	for i in range(obstacles.size() - 1, -1, -1):
		var selection: Dictionary = { "type": "obstacle", "index": i }
		if _hits_object(obstacles[i], at, radius):
			return selection
	if Vector2(hole.tee_x, terrain.ground_y(hole.tee_x) - 8.0).distance_to(at) < radius + 8.0:
		return { "type": "tee" }
	if Vector2(hole.cup_x, terrain.rim_y - 18.0).distance_to(at) < radius + 20.0:
		return { "type": "cup" }
	# Trunks first: they're thin, so a click on one clearly means it. Latest pieces win.
	for kind: String in ["trunk", "leaves"]:
		for i in range(hole.scenery.size() - 1, -1, -1):
			var piece: Dictionary = hole.scenery[i]
			if str(piece["kind"]) == kind and _hits_piece(piece, at, radius):
				return { "type": "scenery", "index": i }
	for i in hole.water_spans.size():
		var span: Dictionary = hole.water_spans[i]
		if at.x >= float(span["from"]) and at.x <= float(span["to"]) \
				and at.y >= float(span["level"]) - radius and at.y <= terrain.basin_y(at.x) + 2.0:
			return { "type": "water", "index": i }
	return {}


func _hits_piece(piece: Dictionary, at: Vector2, radius: float) -> bool:
	var center: Vector2 = _piece_center(piece)
	if str(piece["kind"]) == "trunk":
		return absf(at.x - center.x) < radius + 4.0 and absf(at.y - center.y) < radius + 14.0
	return center.distance_to(at) < radius + 20.0


func _hits_object(entry: Dictionary, at: Vector2, radius: float) -> bool:
	var center: Vector2 = _object_center(entry)
	match str(entry["kind"]):
		"pad":
			return center.distance_to(at) < radius + BouncePadObstacle.HALF_LENGTH
		"windmill":
			var mill := WindmillObstacle.new(terrain, entry)
			return Geometry2D.get_closest_point_to_segment(at, mill.base(), mill.hub()).distance_to(at) < radius + 14.0
		"sprinkler":
			return center.distance_to(at) < radius + 10.0
		"cart":
			return absf(at.x - center.x) < radius + CartObstacle.DRAWN_HALF_WIDTH \
					and at.y > center.y + CartObstacle.RIDE_HEIGHT - CartObstacle.DRAWN_HEIGHT - radius \
					and at.y < center.y + CartObstacle.RIDE_HEIGHT + radius
		_:
			return center.distance_to(at) < radius + 14.0


# --- Settings panel ---

## The settings for a selection. An empty selection gives the hole's own settings.
## Each entry: { "label", "key", "value", "step", "min", "max" }.
func properties(selection: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	match str(selection.get("type", "")):
		"":
			rows.append(_row("PAR", "par", float(hole.par), 1.0, 1.0, 12.0))
			rows.append(_row("WIND", "wind", hole.wind, 1.0, -60.0, 60.0))
			rows.append(_row("TEE X", "tee_x", hole.tee_x, 10.0, 0.0, length()))
			rows.append(_row("CUP X", "cup_x", hole.cup_x, 10.0, 20.0, length() - 20.0))
		"tee":
			rows.append(_row("TEE X", "tee_x", hole.tee_x, 10.0, 0.0, length()))
		"cup":
			rows.append(_row("CUP X", "cup_x", hole.cup_x, 10.0, 20.0, length() - 20.0))
		"water":
			var span: Dictionary = hole.water_spans[int(selection["index"])]
			rows.append(_row("LEVEL", "level", float(span["level"]), 2.0, MIN_Y, MAX_Y))
		"scenery":
			var piece: Dictionary = piece_of(selection)
			rows.append(_row("HEIGHT", "height", float(piece.get("height", 0.0)), 5.0, -60.0, 400.0))
			if str(piece["kind"]) == "leaves":
				rows.append(_row("SHAPE", "variant", float(piece.get("variant", 0)), 1.0, 0.0, float(HoleIO.LEAF_VARIANTS - 1)))
		"obstacle":
			_object_rows(entry_of(selection), rows)
	return rows


func _object_rows(entry: Dictionary, rows: Array[Dictionary]) -> void:
	var kind: String = str(entry["kind"])
	if ROTATING_KINDS.has(kind):
		rows.append(_row("ANGLE", "rotation", float(entry.get("rotation", 0.0)), 5.0, -180.0, 180.0))
	match kind:
		"pad":
			rows.append(_row("POWER", "power", float(entry.get("power", BouncePadObstacle.DEFAULT_POWER)), 10.0, 60.0, 500.0))
		"cart":
			rows.append(_row("SPEED", "speed", float(entry.get("speed", 45.0)), 5.0, 5.0, 200.0))
			rows.append(_row("FROM X", "from", float(entry["from"]), 10.0, 0.0, length()))
			rows.append(_row("TO X", "to", float(entry["to"]), 10.0, 0.0, length()))
		"windmill":
			rows.append(_row("BLADES", "turn_speed", float(entry.get("turn_speed", 1.2)), 0.1, 0.0, 5.0))
		"sprinkler":
			rows.append(_row("HEIGHT", "height", float(entry.get("height", 70.0)), 5.0, 15.0, 250.0))
			rows.append(_row("ON", "on_time", float(entry.get("on_time", 2.5)), 0.5, 0.5, 10.0))
			rows.append(_row("OFF", "off_time", float(entry.get("off_time", 2.0)), 0.5, 0.0, 10.0))
			rows.append(_row("OFFSET", "offset", float(entry.get("offset", 0.0)), 0.5, 0.0, 20.0))
		"goose":
			rows.append(_row("SPEED", "speed", float(entry.get("speed", 60.0)), 5.0, 5.0, 200.0))
			rows.append(_row("HEIGHT", "height", float(entry.get("height", 80.0)), 5.0, 10.0, 350.0))
			rows.append(_row("FROM X", "from", float(entry["from"]), 10.0, 0.0, length()))
			rows.append(_row("TO X", "to", float(entry["to"]), 10.0, 0.0, length()))


func _row(label: String, key: String, value: float, step: float, min_value: float, max_value: float) -> Dictionary:
	return { "label": label, "key": key, "value": value, "step": step, "min": min_value, "max": max_value }


func set_property(selection: Dictionary, key: String, value: float) -> void:
	match str(selection.get("type", "")):
		"", "tee", "cup":
			_set_hole_property(key, value)
		"water":
			hole.water_spans[int(selection["index"])]["level"] = value
			rebake()
		"scenery":
			piece_of(selection)[key] = int(value) if key == "variant" else value
		"obstacle":
			if key == "rotation":
				set_rotation(selection, value)
				return
			if key == "from" or key == "to":
				move_route_end(selection, 0 if key == "from" else 1, value)
				return
			entry_of(selection)[key] = value


func _set_hole_property(key: String, value: float) -> void:
	match key:
		"par":
			hole.par = int(value)
		"wind":
			hole.wind = value
		"tee_x":
			hole.tee_x = value
		"cup_x":
			hole.cup_x = value
			rebake()


# --- Checks ---

## Problems that would make the map play badly. These warn, and don't stop saving.
func warnings() -> Array[String]:
	var found: Array[String] = []
	var cup_surface: int = terrain.surface_at(hole.cup_x)
	if cup_surface == Surface.Type.WATER:
		found.append("CUP IS IN WATER")
	elif cup_surface != Surface.Type.GREEN:
		found.append("CUP IS NOT ON GREEN")
	if terrain.surface_at(hole.tee_x) == Surface.Type.WATER:
		found.append("TEE IS IN WATER")
	if absf(hole.tee_x - hole.cup_x) < 60.0:
		found.append("TEE IS TOO NEAR CUP")
	if absf(terrain.slope(hole.cup_x - 20.0)) > 0.28 or absf(terrain.slope(hole.cup_x + 20.0)) > 0.28:
		found.append("GROUND BY CUP IS STEEP")
	return found
