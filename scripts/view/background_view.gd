class_name BackgroundView
extends CanvasLayer
## Sky and parallax layers, generated once as tiling images.

const WIDTH := 640
const HEIGHT := 360
## Each hill layer: speed, horizon y, wave height, colour, wave seed.
const HILLS := [
	[0.08, 190.0, 34.0, Color("a9cfe2"), 1.3],
	[0.16, 214.0, 26.0, Color("86bcc4"), 4.1],
	[0.3, 238.0, 20.0, Color("5f9f7f"), 7.7],
]

var camera: Camera2D
var _sprites: Array[Sprite2D] = []
var _speeds: Array[float] = []
var _cloud_sprite: Sprite2D
var _cloud_drift: float = 0.0


func setup(p_camera: Camera2D) -> void:
	camera = p_camera


func _ready() -> void:
	layer = -10
	var sky := Sprite2D.new()
	sky.texture = ImageTexture.create_from_image(_make_sky())
	sky.centered = false
	add_child(sky)

	_cloud_sprite = _add_layer(_make_clouds(), 0.05)

	for hill: Array in HILLS:
		_add_layer(_make_hills(hill[1], hill[2], hill[3], hill[4]), hill[0])


func _process(delta: float) -> void:
	_cloud_drift += delta * 3.0
	var center_x: float = camera.get_screen_center_position().x
	for i in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		var offset: float = center_x * _speeds[i]
		if sprite == _cloud_sprite:
			offset += _cloud_drift
		sprite.region_rect.position.x = round(offset)


func _add_layer(image: Image, speed: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, WIDTH, HEIGHT)
	add_child(sprite)
	_sprites.append(sprite)
	_speeds.append(speed)
	return sprite


# Banded gradient with dithered joins between bands.
func _make_sky() -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var top := Color("4f9fe0")
	var bottom := Color("d9f1f2")
	var bands: int = 14
	for y in HEIGHT:
		var t: float = clampf(float(y) / 240.0, 0.0, 1.0) * float(bands)
		var band: int = int(t)
		var fraction: float = t - float(band)
		for x in WIDTH:
			var dither: float = 0.25 if (x + y) % 2 == 0 else 0.75
			var step_band: int = band + (1 if fraction > dither else 0)
			image.set_pixel(x, y, top.lerp(bottom, float(step_band) / float(bands)))
	return image


func _make_clouds() -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for _i in 7:
		var cx: int = rng.randi_range(0, WIDTH - 1)
		var cy: int = rng.randi_range(24, 130)
		var puffs: int = rng.randi_range(4, 7)
		for p in puffs:
			var px: int = cx + (p - puffs / 2) * rng.randi_range(9, 13)
			var py: int = cy + rng.randi_range(-3, 3)
			_paint_puff(image, px, py, rng.randi_range(7, 13))
	return image


func _paint_puff(image: Image, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var shaded: bool = dy > -radius / 3 and image.get_pixel(posmod(cx + dx, WIDTH), cy + dy).a == 0.0
			var color: Color = Color("dfeef7") if shaded else Color("ffffff")
			image.set_pixel(posmod(cx + dx, WIDTH), clampi(cy + dy, 0, HEIGHT - 1), color)


# Sine terms use whole cycles across the width, so the layer tiles without a seam.
func _make_hills(horizon: float, wave: float, color: Color, seed_value: float) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var dark: Color = color.darkened(0.08)
	for x in WIDTH:
		var u: float = float(x) / float(WIDTH) * TAU
		var y: float = horizon \
				- sin(u * 2.0 + seed_value) * wave * 0.6 \
				- sin(u * 5.0 + seed_value * 2.0) * wave * 0.3 \
				- sin(u * 11.0 + seed_value * 3.0) * wave * 0.1
		for py in range(int(y), HEIGHT):
			var fleck: bool = py > int(y) + 3 and (x + py) % 2 == 0 and (py - int(y)) % 16 < 3
			image.set_pixel(x, py, dark if fleck else color)
	return image
