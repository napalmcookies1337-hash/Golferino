class_name TerrainView
extends Node2D
## Paints the ground pixel by pixel into image chunks once, then just shows them.

const CHUNK_WIDTH := 512

const SOIL := [
	Color("6b4a32"), Color("5d3f2b"), Color("503524"), Color("432c1f"), Color("37241a"),
]
const STONE := Color("8a7460")
const CUP_DARK := Color("14100d")

var terrain: Terrain


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain


func _ready() -> void:
	var x: int = 0
	while x <= terrain.length:
		_add_chunk(x)
		x += CHUNK_WIDTH


func _add_chunk(start_x: int) -> void:
	var width: int = mini(CHUNK_WIDTH, terrain.length + 1 - start_x)
	var height: int = Terrain.WORLD_HEIGHT
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for col in width:
		_paint_column(image, col, start_x + col, height)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2(start_x, 0)
	add_child(sprite)


func _paint_column(image: Image, col: int, world_x: int, height: int) -> void:
	var surface: int = terrain.surface_at(world_x)
	var is_water: bool = surface == Surface.Type.WATER
	var top: int = int(round(terrain.basin_y(world_x))) if is_water \
			else int(round(terrain.ground_y(world_x)))
	var in_cup: bool = terrain.in_cup(float(world_x))
	var cup_bottom: int = int(terrain.rim_y + terrain.cup_depth)

	if surface == Surface.Type.ROUGH and _hash(world_x, 7) % 4 == 0:
		var tuft: int = 1 + _hash(world_x, 11) % 3
		for y in range(maxi(top - tuft, 0), top):
			image.set_pixel(col, y, Color("3f7a2f"))

	var turf_edge: int = _turf_depth(surface) + _hash(world_x, 3) % 3
	for y in range(top, height):
		if in_cup and y < cup_bottom:
			image.set_pixel(col, y, CUP_DARK)
			continue
		var depth: int = y - top
		if is_water:
			image.set_pixel(col, y, Color("2e4a55") if depth < 4 else _soil(world_x, depth, y))
		elif depth < turf_edge:
			image.set_pixel(col, y, _turf(surface, world_x, y, depth))
		else:
			image.set_pixel(col, y, _soil(world_x, depth, y))


func _turf_depth(surface: int) -> int:
	match surface:
		Surface.Type.SAND:
			return 11
		Surface.Type.GREEN:
			return 7
		_:
			return 6


func _turf(surface: int, x: int, y: int, depth: int) -> Color:
	match surface:
		Surface.Type.FAIRWAY, Surface.Type.TEE:
			if depth == 0:
				return Color("c8ec7e")
			var stripe: bool = int(float(x) / 14.0) % 2 == 0
			return Color("7cc24e") if stripe else Color("6db345")
		Surface.Type.GREEN:
			if depth == 0:
				return Color("e4f7a0")
			return Color("9edb5c") if depth < 4 else Color("86c94f")
		Surface.Type.SAND:
			if depth == 0:
				return Color("fff0bd")
			var fleck: bool = _hash(x, y) % 6 == 0
			return Color("d4b673") if fleck else Color("eed08c")
		_:
			if depth == 0:
				return Color("7fb54a")
			return Color("3f7a2f") if _hash(x, y) % 5 == 0 else Color("4e8f38")


func _soil(x: int, depth: int, y: int) -> Color:
	if _hash(x / 2, y / 2) % 113 == 0:
		return STONE
	var band: float = float(depth) / 38.0 + float(_hash(x, y) % 3) * 0.12
	return SOIL[mini(int(band), SOIL.size() - 1)]


func _hash(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
