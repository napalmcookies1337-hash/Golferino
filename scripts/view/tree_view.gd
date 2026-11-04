class_name TreeView
extends Node2D
## Decorative trees behind the ground. They don't collide in this milestone.

const VARIANTS := 3

var game: HoleGame


func setup(p_game: HoleGame) -> void:
	game = p_game


func _ready() -> void:
	var textures: Array[ImageTexture] = []
	for i in VARIANTS:
		textures.append(ImageTexture.create_from_image(_make_tree(i)))
	var index: int = 0
	for x: float in game.hole.tree_xs:
		var sprite := Sprite2D.new()
		var texture: ImageTexture = textures[index % VARIANTS]
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(
				round(x - texture.get_width() / 2.0),
				round(game.terrain.ground_y(x) + 3.0 - texture.get_height()))
		add_child(sprite)
		index += 1


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
			var best: float = -1.0
			for blob in blobs:
				var dx: float = float(x) - blob.x
				var dy: float = float(y) - blob.y
				var dist: float = sqrt(dx * dx + dy * dy)
				if dist <= blob.z:
					# Light comes from the upper left of each blob.
					var lit: float = (-dx - dy) / (blob.z * 1.5) + 0.5
					best = maxf(best, lit)
			if best < 0.0 and best != -1.0:
				best = 0.0
			if best == -1.0:
				continue
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
