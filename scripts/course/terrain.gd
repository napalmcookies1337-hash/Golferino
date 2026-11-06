class_name Terrain
extends RefCounted
## Bakes a HoleData outline into per-pixel height and surface lookups.

const CUP_HALF := 5.0
const CUP_DEPTH := 11.0
const PIN_HEIGHT := 38.0
const WORLD_HEIGHT := 540
## An island's rock: its thickness at the edge, and how much deeper the middle goes.
const ISLAND_EDGE_DEPTH := 8.0
const ISLAND_DEPTH_SHARE := 0.55
const ISLAND_DEPTH_MIN := 22.0
const ISLAND_DEPTH_MAX := 70.0
const ISLAND_JAG_WIDTH := 5
const ISLAND_JAG_SIZE := 7

var length: int = 0
var cup_x: float = 0.0
var cup_half: float = CUP_HALF
var cup_depth: float = CUP_DEPTH
var rim_y: float = 0.0
## Which world this hole's in, for the views.
var biome: String = HoleData.BIOME_GRASSY

var _heights := PackedFloat32Array()
var _basin := PackedFloat32Array()
var _surfaces := PackedByteArray()
## True where a floating hole has nothing but sky. Empty on an ordinary hole.
var _void := PackedByteArray()
## How far down each column of an island's rock reaches.
var _under := PackedFloat32Array()


func _init(hole: HoleData) -> void:
	length = int(hole.points[hole.points.size() - 1].x)
	cup_x = hole.cup_x
	biome = hole.biome
	_bake_heights(hole.points)
	_bake_surfaces(hole)
	_flatten_cup_rim()
	if not hole.void_spans.is_empty():
		_bake_islands(hole)


## True for a hole of islands, where the ball can fall right off the map.
func is_floating() -> bool:
	return not _void.is_empty()


## True where there's only sky. ground_y still gives a smooth height there, which is what the
## camera and the views want, but the ball passes straight through it.
func is_void(x: float) -> bool:
	return not _void.is_empty() and _void[clampi(int(x), 0, length)] == 1


## The bottom of an island's rock at this x. On an ordinary hole the ground goes on forever.
func underside_y(x: float) -> float:
	if _under.is_empty():
		return float(WORLD_HEIGHT)
	return _under[clampi(int(x), 0, length)]


func ground_y(x: float) -> float:
	var clamped: float = clampf(x, 0.0, float(length))
	var left: int = int(floor(clamped))
	var right: int = mini(left + 1, length)
	return lerpf(_heights[left], _heights[right], clamped - float(left))


## The ground under the water where flooded, otherwise the ground itself.
func basin_y(x: float) -> float:
	return _basin[clampi(int(x), 0, length)]


func slope(x: float) -> float:
	return (ground_y(x + 2.0) - ground_y(x - 2.0)) / 4.0


## Unit vector along the ground, always pointing toward +x.
func tangent(x: float) -> Vector2:
	return Vector2(1.0, slope(x)).normalized()


## Unit vector out of the ground, always pointing up.
func normal(x: float) -> Vector2:
	return Vector2(slope(x), -1.0).normalized()


func surface_at(x: float) -> int:
	return _surfaces[clampi(int(x), 0, length)]


## True where water lies, even under a lily pad.
func is_wet(x: float) -> bool:
	var surface: int = surface_at(x)
	return surface == Surface.Type.WATER or surface == Surface.Type.LILY


func in_cup(x: float) -> bool:
	return absf(x - cup_x) < cup_half


# Cubic Hermite through the outline points, written as y(x) so it can't fold back.
func _bake_heights(points: PackedVector2Array) -> void:
	_heights.resize(length + 1)
	var segment: int = 0
	for x in length + 1:
		while segment < points.size() - 2 and float(x) > points[segment + 1].x:
			segment += 1
		var p0: Vector2 = points[segment]
		var p1: Vector2 = points[segment + 1]
		var span: float = p1.x - p0.x
		var u: float = (float(x) - p0.x) / span
		var m0: float = _point_slope(points, segment) * span
		var m1: float = _point_slope(points, segment + 1) * span
		var u2: float = u * u
		var u3: float = u2 * u
		_heights[x] = (2.0 * u3 - 3.0 * u2 + 1.0) * p0.y + (u3 - 2.0 * u2 + u) * m0 \
				+ (-2.0 * u3 + 3.0 * u2) * p1.y + (u3 - u2) * m1
	_basin = _heights.duplicate()


func _point_slope(points: PackedVector2Array, i: int) -> float:
	var a: Vector2 = points[maxi(i - 1, 0)]
	var b: Vector2 = points[mini(i + 1, points.size() - 1)]
	return (b.y - a.y) / (b.x - a.x)


func _bake_surfaces(hole: HoleData) -> void:
	_surfaces.resize(length + 1)
	_surfaces.fill(Surface.Type.ROUGH)
	for span: Dictionary in hole.surface_spans:
		for x in range(_span_start(span), _span_end(span)):
			_surfaces[x] = int(span["type"])
	for span: Dictionary in hole.water_spans:
		var level: float = float(span["level"])
		for x in range(_span_start(span), _span_end(span)):
			if _heights[x] > level:
				_heights[x] = level
				_surfaces[x] = Surface.Type.WATER
	# Water's height is already its surface, so a lily pad only has to stop it being water.
	for entry: Dictionary in hole.obstacles:
		if str(entry.get("kind", "")) == "lily":
			var half: float = float(entry.get("width", LilyObstacle.DEFAULT_WIDTH)) / 2.0
			var center: float = float(entry["x"])
			for x in range(clampi(int(center - half), 0, length), clampi(int(center + half), 0, length + 1)):
				if _surfaces[x] == Surface.Type.WATER:
					_surfaces[x] = Surface.Type.LILY


func _span_start(span: Dictionary) -> int:
	return clampi(int(span["from"]), 0, length)


func _span_end(span: Dictionary) -> int:
	return clampi(int(span["to"]), 0, length + 1)


func _bake_islands(hole: HoleData) -> void:
	_void.resize(length + 1)
	_void.fill(0)
	for span: Dictionary in hole.void_spans:
		for x in range(_span_start(span), _span_end(span)):
			_void[x] = 1
	_under.resize(length + 1)
	_under.fill(0.0)
	var x: int = 0
	while x <= length:
		if _void[x] == 1:
			x += 1
			continue
		var island_end: int = x
		while island_end < length and _void[island_end + 1] == 0:
			island_end += 1
		_bake_underside(x, island_end)
		x = island_end + 1


# Deepest in the middle and tapering to the edges, with a jagged line of rock along the bottom.
func _bake_underside(from_x: int, to_x: int) -> void:
	var half: float = maxf(float(to_x - from_x) / 2.0, 1.0)
	var middle: float = float(from_x + to_x) / 2.0
	var deepest: float = clampf(half * ISLAND_DEPTH_SHARE, ISLAND_DEPTH_MIN, ISLAND_DEPTH_MAX)
	for x in range(from_x, to_x + 1):
		var t: float = absf(float(x) - middle) / half
		var jag: int = (((x / ISLAND_JAG_WIDTH) * 73856093) & 0x7fffffff) % ISLAND_JAG_SIZE
		_under[x] = _heights[x] + ISLAND_EDGE_DEPTH + deepest * sqrt(maxf(1.0 - t * t, 0.0)) + float(jag)


func _flatten_cup_rim() -> void:
	rim_y = ground_y(cup_x)
	var from_x: int = int(cup_x - cup_half) - 2
	var to_x: int = int(cup_x + cup_half) + 2
	for x in range(from_x, to_x + 1):
		_heights[clampi(x, 0, length)] = rim_y
