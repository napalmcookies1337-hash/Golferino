class_name TreeView
extends Node2D
## Draws tree pieces. They're scenery behind the ground, with no effect on the ball.

const TRUNK_WIDTH := 5
const TRUNK_HEIGHT := 26
## How far a trunk with no height sits into the ground.
const TRUNK_SINK := 3.0

# The images are made once and shared, because the editor rebuilds this view while dragging.
static var _trunk_texture: ImageTexture
static var _leaf_textures: Array[ImageTexture] = []

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
	var x: float = float(piece["x"])
	var base_y: float = terrain.ground_y(x) + TRUNK_SINK - float(piece.get("height", 0.0))
	_add_sprite(_trunk_texture, Vector2(x - float(TRUNK_WIDTH) / 2.0, base_y - float(TRUNK_HEIGHT)))


func _add_leaves(piece: Dictionary) -> void:
	var x: float = float(piece["x"])
	var variant: int = int(piece.get("variant", 0))
	var texture: ImageTexture = _leaf_textures[variant]
	var center_y: float = terrain.ground_y(x) - float(piece.get("height", 0.0))
	_add_sprite(texture, Vector2(x - float(texture.get_width()) / 2.0, center_y - float(_canopy_center(variant))))


func _add_sprite(texture: ImageTexture, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at.round()
	add_child(sprite)


static func _make_textures() -> void:
	if _trunk_texture != null:
		return
	_trunk_texture = ImageTexture.create_from_image(_make_trunk())
	for variant in HoleIO.LEAF_VARIANTS:
		_leaf_textures.append(ImageTexture.create_from_image(_make_leaves(variant)))


static func _make_trunk() -> Image:
	var image := Image.create(TRUNK_WIDTH, TRUNK_HEIGHT, false, Image.FORMAT_RGBA8)
	var middle: int = TRUNK_WIDTH / 2
	for y in TRUNK_HEIGHT:
		for x in TRUNK_WIDTH:
			image.set_pixel(x, y, Color("4a3322") if x > middle else Color("6a4a30"))
	return image


static func _leaves_width(variant: int) -> int:
	return 44 + variant * 6


static func _leaves_height(variant: int) -> int:
	return 62 + variant * 8


# The row of the image that sits at the piece's height.
static func _canopy_center(variant: int) -> int:
	return (_leaves_height(variant) - 18) / 2


static func _make_leaves(variant: int) -> Image:
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
				image.set_pixel(x, y, _leaf_color(best, x, y))
	return image


static func _leaf_color(lit: float, x: int, y: int) -> Color:
	var dither: float = 0.06 if (x + y) % 2 == 0 else -0.06
	var value: float = lit + dither
	if value > 0.82:
		return Color("7fb84c")
	if value > 0.5:
		return Color("56983e")
	if value > 0.2:
		return Color("3c7a39")
	return Color("2a5c33")
