class_name TerrainView
extends Node2D
## Paints the ground pixel by pixel into image chunks once, then just shows them.

const CHUNK_WIDTH := 512

const SOIL := [
	Color("6b4a32"), Color("5d3f2b"), Color("503524"), Color("432c1f"), Color("37241a"),
]
const SWAMP_SOIL := [
	Color("3d3324"), Color("332a1d"), Color("2a2318"), Color("231d14"), Color("1c1710"),
]
const FLOWERS := [Color("ffffff"), Color("ffe25a"), Color("f79ac0")]
const STONE := Color("8a7460")
const CUP_DARK := Color("14100d")
const CUP_SHADE_TOP := Color("4a4036")
const CUP_SHADE_MID := Color("2a231d")
const CUP_LIGHT_WALL := Color("5e5246")
const CUP_LINER := Color("d9dccf")
const CUP_LINER_SHADE := Color("a4a89a")
const CUP_RING := Color("2e2016")
const CUP_LIP := Color("f6ffcf")

var terrain: Terrain
var _swamp: bool = false


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain
	_swamp = terrain.biome == HoleData.BIOME_SWAMP


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
	# A floating hole's gaps are left clear, and its islands stop where their rock does.
	if terrain.is_void(float(world_x)):
		return
	if terrain.is_floating():
		height = mini(height, int(round(terrain.underside_y(float(world_x)))))
	var surface: int = terrain.surface_at(world_x)
	var is_water: bool = terrain.is_wet(float(world_x))
	var top: int = int(round(terrain.basin_y(world_x))) if is_water \
			else int(round(terrain.ground_y(world_x)))
	var in_cup: bool = terrain.in_cup(float(world_x))
	var cup_bottom: int = int(terrain.rim_y + terrain.cup_depth)

	if _swamp:
		_paint_swamp_tufts(image, col, world_x, top, surface)
	elif surface == Surface.Type.ROUGH and _hash(world_x, 7) % 4 == 0:
		var tuft: int = 1 + _hash(world_x, 11) % 3
		for y in range(maxi(top - tuft, 0), top):
			image.set_pixel(col, y, Color("3f7a2f"))
		# Now and then one of them has a flower on it.
		if _hash(world_x, 29) % 7 == 0 and top - tuft - 1 >= 0:
			image.set_pixel(col, top - tuft - 1, FLOWERS[_hash(world_x, 31) % FLOWERS.size()])
	elif surface == Surface.Type.FAIRWAY and _hash(world_x, 13) % 9 == 0 and top >= 1:
		image.set_pixel(col, top - 1, Color("8fd05a"))

	var turf_edge: int = _turf_depth(surface) + _hash(world_x, 3) % 3
	for y in range(top, height):
		if in_cup and y < cup_bottom:
			image.set_pixel(col, y, CUP_DARK)
			continue
		var depth: int = y - top
		if is_water:
			var bed: Color = Color("2a3320") if _swamp else Color("2e4a55")
			image.set_pixel(col, y, bed if depth < 4 else _soil(world_x, depth, y))
		elif depth < turf_edge:
			image.set_pixel(col, y, _turf(surface, world_x, y, depth))
		else:
			image.set_pixel(col, y, _soil(world_x, depth, y))

	_paint_cup(image, col, world_x)


# Tall reeds in the rough, the odd bubble of mud, and scraps of moss on the fairway.
func _paint_swamp_tufts(image: Image, col: int, world_x: int, top: int, surface: int) -> void:
	if surface == Surface.Type.ROUGH and _hash(world_x, 7) % 3 == 0:
		var reed: int = 2 + _hash(world_x, 11) % 7
		for y in range(maxi(top - reed, 0), top):
			image.set_pixel(col, y, Color("4d6130"))
		if _hash(world_x, 29) % 6 == 0 and top - reed - 2 >= 0:
			image.set_pixel(col, top - reed - 1, Color("5a3d24"))
			image.set_pixel(col, top - reed - 2, Color("5a3d24"))
	elif surface == Surface.Type.MUD and _hash(world_x, 17) % 11 == 0 and top >= 1:
		image.set_pixel(col, top - 1, Color("6a5536"))
	elif surface == Surface.Type.FAIRWAY and _hash(world_x, 13) % 9 == 0 and top >= 1:
		image.set_pixel(col, top - 1, Color("8c9e4c"))


# The cup in cross-section: a white liner with a rounded bottom set into the ground, dark
# inside and lit on one wall, with a bright lip of turf either side of the opening.
func _paint_cup(image: Image, col: int, world_x: int) -> void:
	var offset: int = world_x - int(round(terrain.cup_x))
	var side: int = absi(offset)
	var wall: int = int(ceil(terrain.cup_half)) - 1
	if side > wall + 1:
		return
	var rim: int = int(round(terrain.rim_y))
	var floor_row: int = int(terrain.cup_depth) - 1
	for row in floor_row + 2:
		var y: int = rim + row
		if y >= image.get_height():
			return
		var color: Color = _cup_color(offset, side, wall, row, floor_row)
		if color.a > 0.0:
			image.set_pixel(col, y, color)


## Draws a standard cup straight onto a canvas, for the title screen's scenery. It matches
## what the course paints, so the two can't drift apart.
static func draw_cup(canvas: CanvasItem, cup_x: int, rim: int) -> void:
	var wall: int = int(ceil(Terrain.CUP_HALF)) - 1
	var floor_row: int = int(Terrain.CUP_DEPTH) - 1
	for offset in range(-wall - 1, wall + 2):
		for row in floor_row + 2:
			var color: Color = _cup_color(offset, absi(offset), wall, row, floor_row)
			if color.a > 0.0:
				canvas.draw_rect(Rect2(cup_x + offset, rim + row, 1, 1), color)


# Transparent means leave the ground as it is.
static func _cup_color(offset: int, side: int, wall: int, row: int, floor_row: int) -> Color:
	if side == wall + 1:
		if row == 0:
			return CUP_LIP
		return CUP_RING if row < floor_row else Color.TRANSPARENT
	if row == floor_row + 1:
		return CUP_RING if side < wall else Color.TRANSPARENT
	var liner: Color = CUP_LINER_SHADE if offset > 0 else CUP_LINER
	if side == wall:
		return CUP_RING if row == floor_row else liner
	if row == floor_row or (side == wall - 1 and row == floor_row - 1):
		return liner
	if row < 2:
		return CUP_SHADE_TOP
	if offset == wall - 1 and row < 6:
		return CUP_LIGHT_WALL
	return CUP_SHADE_MID if row < 5 else CUP_DARK


func _turf_depth(surface: int) -> int:
	match surface:
		Surface.Type.SAND:
			return 11
		Surface.Type.GREEN:
			return 7
		_:
			return 6


func _turf(surface: int, x: int, y: int, depth: int) -> Color:
	if surface == Surface.Type.MUD:
		if depth == 0:
			return Color("7a6340")
		# Wet streaks through it, so it reads as mud at a glance.
		return Color("3e301d") if _hash(x / 3, y / 2) % 4 == 0 else Color("54422a")
	if _swamp:
		return _swamp_turf(surface, x, y, depth)
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


func _swamp_turf(surface: int, x: int, y: int, depth: int) -> Color:
	match surface:
		Surface.Type.FAIRWAY, Surface.Type.TEE:
			if depth == 0:
				return Color("b4c070")
			return Color("7f9146") if int(float(x) / 14.0) % 2 == 0 else Color("74853f")
		Surface.Type.GREEN:
			if depth == 0:
				return Color("dcec94")
			return Color("a8c75a") if depth < 4 else Color("90b04e")
		Surface.Type.SAND:
			if depth == 0:
				return Color("cfc594")
			return Color("9c9264") if _hash(x, y) % 6 == 0 else Color("b5aa7a")
		_:
			if depth == 0:
				return Color("67783c")
			return Color("3f4f28") if _hash(x, y) % 5 == 0 else Color("4c5e2e")


func _soil(x: int, depth: int, y: int) -> Color:
	if _hash(x / 2, y / 2) % 113 == 0:
		return STONE.darkened(0.4) if _swamp else STONE
	var band: float = float(depth) / 38.0 + float(_hash(x, y) % 3) * 0.12
	var palette: Array = SWAMP_SOIL if _swamp else SOIL
	return palette[mini(int(band), palette.size() - 1)]


func _hash(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
