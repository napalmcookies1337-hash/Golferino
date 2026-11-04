class_name TreeView
extends Node2D
## Draws the trees. Their rules live in TreeObstacle.

var game: HoleGame


func setup(p_game: HoleGame) -> void:
	game = p_game


func _ready() -> void:
	var textures: Array[ImageTexture] = []
	for i in TreeObstacle.VARIANTS:
		textures.append(ImageTexture.create_from_image(_make_tree(i)))
	for obstacle in game.obstacles:
		if obstacle is TreeObstacle:
			_add_tree(obstacle, textures[obstacle.variant])


func _add_tree(tree: TreeObstacle, texture: ImageTexture) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(
			round(tree.x - texture.get_width() / 2.0),
			round(tree.ground + 3.0 - texture.get_height()))
	add_child(sprite)


func _make_tree(variant: int) -> Image:
	var width: int = TreeObstacle.sprite_width(variant)
	var height: int = TreeObstacle.sprite_height(variant)
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
