class_name TreeView
extends Node2D
## Draws tree pieces. They're scenery behind the ground, with no effect on the ball.

const TRUNK_WIDTH := 5
const TRUNK_HEIGHT := 26
## How far a trunk with no height sits into the ground.
const TRUNK_SINK := 3.0
## A whole tree's leaves always hide at least this many rows at the top of its trunk.
const MIN_COVER_ROWS := 5

# The images are made once and shared, because the editor rebuilds this view while dragging.
static var _trunk_texture: ImageTexture
static var _leaf_textures: Array[ImageTexture] = []
static var _swamp_trunk_texture: ImageTexture
static var _swamp_leaf_textures: Array[ImageTexture] = []

var hole: HoleData
var terrain: Terrain


func setup(p_hole: HoleData, p_terrain: Terrain) -> void:
	hole = p_hole
	terrain = p_terrain


func _ready() -> void:
	_make_textures()
	for piece: Dictionary in hole.scenery:
		if str(piece["kind"]) == "trunk":
			_add_trunk(piece)
	# Leaves go on top, so that a tree's leaves cover the top of its trunk.
	for piece: Dictionary in hole.scenery:
		if str(piece["kind"]) == "leaves":
			_add_leaves(piece)


func _add_trunk(piece: Dictionary) -> void:
	var swamp: bool = hole.biome == HoleData.BIOME_SWAMP
	_add_sprite(_swamp_trunk_texture if swamp else _trunk_texture, trunk_corner(piece, terrain))


func _add_leaves(piece: Dictionary) -> void:
	var textures: Array[ImageTexture] = _swamp_leaf_textures if hole.biome == HoleData.BIOME_SWAMP else _leaf_textures
	_add_sprite(textures[int(piece.get("variant", 0))], leaves_corner(piece, terrain))


func _add_sprite(texture: ImageTexture, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	add_child(sprite)


## Where a trunk's top left pixel goes.
static func trunk_corner(piece: Dictionary, on: Terrain) -> Vector2:
	var x: float = float(piece["x"])
	var base_y: float = on.ground_y(x) + TRUNK_SINK - float(piece.get("height", 0.0))
	return Vector2(x - float(TRUNK_WIDTH) / 2.0, base_y - float(TRUNK_HEIGHT)).round()


## Where a set of leaves' top left pixel goes.
static func leaves_corner(piece: Dictionary, on: Terrain) -> Vector2:
	var x: float = float(piece["x"])
	var variant: int = int(piece.get("variant", 0))
	var center_y: float = on.ground_y(x) - float(piece.get("height", 0.0))
	return Vector2(x - float(_leaves_width(variant)) / 2.0, center_y - float(_canopy_center(variant))).round()


## True when solid leaves cover at least the top rows of the trunk, across its whole width.
static func leaves_cover_trunk(trunk: Dictionary, leaves: Dictionary, on: Terrain, rows: int = MIN_COVER_ROWS) -> bool:
	var image: Image = _make_leaves(int(leaves.get("variant", 0)))
	var offset: Vector2i = Vector2i(trunk_corner(trunk, on) - leaves_corner(leaves, on))
	for row in rows:
		for column in TRUNK_WIDTH:
			var at: Vector2i = offset + Vector2i(column, row)
			var inside: bool = at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height()
			if not inside or image.get_pixelv(at).a <= 0.0:
				return false
	return true


static func _make_textures() -> void:
	if _trunk_texture != null:
		return
	_trunk_texture = ImageTexture.create_from_image(_make_trunk())
	_swamp_trunk_texture = ImageTexture.create_from_image(_make_trunk(true))
	for variant in HoleIO.LEAF_VARIANTS:
		_leaf_textures.append(ImageTexture.create_from_image(_make_leaves(variant)))
		_swamp_leaf_textures.append(ImageTexture.create_from_image(_make_leaves(variant, true)))


static func _make_trunk(swamp: bool = false) -> Image:
	var image := Image.create(TRUNK_WIDTH, TRUNK_HEIGHT, false, Image.FORMAT_RGBA8)
	var middle: int = TRUNK_WIDTH / 2
	var shade: Color = Color("2c2a20") if swamp else Color("4a3322")
	var lit: Color = Color("423c2a") if swamp else Color("6a4a30")
	for y in TRUNK_HEIGHT:
		for x in TRUNK_WIDTH:
			image.set_pixel(x, y, shade if x > middle else lit)
	return image


static func _leaves_width(variant: int) -> int:
	return 44 + variant * 6


static func _leaves_height(variant: int) -> int:
	return 62 + variant * 8


# The row of the image that sits at the piece's height.
static func _canopy_center(variant: int) -> int:
	return (_leaves_height(variant) - 18) / 2


# The row of the image that the top of a whole tree's trunk reaches.
static func _trunk_top_row(variant: int) -> int:
	return roundi(HoleIO.leaves_height(variant) + float(_canopy_center(variant)) + TRUNK_SINK) - TRUNK_HEIGHT


static func _make_leaves(variant: int, swamp: bool = false) -> Image:
	var width: int = _leaves_width(variant)
	var height: int = _leaves_height(variant)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var center_x: int = width / 2
	var canopy_y: int = _canopy_center(variant)

	var blobs: Array[Vector3] = []
	for _i in 9:
		blobs.append(Vector3(
				center_x + rng.randi_range(-width / 4, width / 4),
				canopy_y + rng.randi_range(-canopy_y / 2, canopy_y / 2),
				rng.randi_range(9, 13)))
	# The random blobs can leave a hole over the trunk, so these two always fill it: one joins
	# the canopy, and one sits on the top of a whole tree's trunk, well past its edges.
	var trunk_top: int = _trunk_top_row(variant)
	blobs.append(Vector3(center_x, (canopy_y + trunk_top) / 2, 12))
	blobs.append(Vector3(center_x, trunk_top + 1, 10))

	for y in height:
		for x in width:
			var best: float = -1000.0
			for blob in blobs:
				var dx: float = float(x) - blob.x
				var dy: float = float(y) - blob.y
				if sqrt(dx * dx + dy * dy) <= blob.z:
					# Light comes from the upper left of each blob.
					best = maxf(best, (-dx - dy) / (blob.z * 1.5) + 0.5)
			if best > -1000.0:
				image.set_pixel(x, y, _leaf_color(best, x, y, swamp))
	if swamp:
		_hang_moss(image, rng)
	return image


# Strands of moss hanging from the canopy's underside. Any leftovers fall off the image's foot.
static func _hang_moss(image: Image, rng: RandomNumberGenerator) -> void:
	for x in image.get_width():
		if rng.randf() > 0.3:
			continue
		var bottom: int = -1
		for y in range(image.get_height() - 1, -1, -1):
			if image.get_pixel(x, y).a > 0.0:
				bottom = y
				break
		if bottom >= 0:
			for y in range(bottom + 1, mini(bottom + rng.randi_range(3, 11), image.get_height())):
				image.set_pixel(x, y, Color("7c8a52"))


static func _leaf_color(lit: float, x: int, y: int, swamp: bool = false) -> Color:
	var dither: float = 0.06 if (x + y) % 2 == 0 else -0.06
	var value: float = lit + dither
	if swamp:
		if value > 0.82:
			return Color("8a9a50")
		if value > 0.5:
			return Color("66783e")
		if value > 0.2:
			return Color("4a5c32")
		return Color("344428")
	if value > 0.82:
		return Color("7fb84c")
	if value > 0.5:
		return Color("56983e")
	if value > 0.2:
		return Color("3c7a39")
	return Color("2a5c33")
