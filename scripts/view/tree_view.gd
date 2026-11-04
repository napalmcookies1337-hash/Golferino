class_name TreeView
extends Node2D
## Trees are scenery behind the ground. They have no effect on the ball.

const VARIANTS := 3

var hole: HoleData
var terrain: Terrain


func setup(p_hole: HoleData, p_terrain: Terrain) -> void:
	hole = p_hole
	terrain = p_terrain


func _ready() -> void:
	var textures: Array[ImageTexture] = []
	for i in VARIANTS:
		textures.append(ImageTexture.create_from_image(_make_tree(i)))
	var index: int = 0
	for x: float in hole.tree_xs:
		_add_tree(x, textures[index % VARIANTS])
		index += 1


func _add_tree(x: float, texture: ImageTexture) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(
			round(x - texture.get_width() / 2.0),
			round(terrain.ground_y(x) + 3.0 - texture.get_height()))
	add_child(sprite)


func _make_tree(variant: int) -> Image:
	var width: int = 44 + variant * 6
	var height: int = 62 + variant * 8
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var center_x: int = width / 2

	for y in range(height - 26, height):
		for x in range(center_x - 2, center_x + 3):
			image.set_pixel(x, y, Color("4a3322") if x > center_x else Color("6a4a30"))

	var canopy_y: int = (height - 18) / 2
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


func _leaf_color(lit: float, x: int, y: int) -> Color:
	var dither: float = 0.06 if (x + y) % 2 == 0 else -0.06
	var value: float = lit + dither
	if value > 0.82:
		return Color("7fb84c")
	if value > 0.5:
		return Color("56983e")
	if value > 0.2:
		return Color("3c7a39")
	return Color("2a5c33")
