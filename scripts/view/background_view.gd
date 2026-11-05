class_name BackgroundView
extends CanvasLayer
## Sky and parallax layers, generated once as tiling images. The time of day moves on as the
## course goes along, from morning to the boss hole's dusk.

enum Mood { MORNING, MIDDAY, AFTERNOON, DUSK }

const WIDTH := 640
const HEIGHT := 360
## Each hill layer's scroll speed, horizon, wave height and wave seed. Colours are by mood.
const HILLS := [
	[0.08, 190.0, 34.0, 1.3],
	[0.16, 214.0, 26.0, 4.1],
	[0.3, 238.0, 20.0, 7.7],
]
const CLUBHOUSE_X := 410
## Where the two banks of cloud start, down the picture.
const CLOUD_SEA_FAR := 292
const CLOUD_SEA_NEAR := 322
const MOODS := {
	Mood.MORNING: {
		"sky_top": "5aa7e6", "sky_bottom": "ffe8cf", "cloud": "ffffff", "cloud_shade": "ffe4d6",
		"hills": ["b4d0e0", "8fbfc2", "639f7c"], "sun": [96, 118, 15, "fff4b8", "fffbe0"],
		"tint": Color(1.0, 0.99, 0.96), "bird": "3a4658",
	},
	Mood.MIDDAY: {
		"sky_top": "4f9fe0", "sky_bottom": "d9f1f2", "cloud": "ffffff", "cloud_shade": "dfeef7",
		"hills": ["a9cfe2", "86bcc4", "5f9f7f"], "sun": [486, 40, 13, "fff8c9", "ffffff"],
		"tint": Color.WHITE, "bird": "3a4658",
	},
	Mood.AFTERNOON: {
		"sky_top": "5a8ccb", "sky_bottom": "ffd8a0", "cloud": "fff3df", "cloud_shade": "f5c9a0",
		"hills": ["c2bcc4", "a3ad9c", "76976a"], "sun": [538, 104, 18, "ffd98a", "fff0c0"],
		"tint": Color(1.0, 0.95, 0.86), "bird": "4a3f4a",
	},
	Mood.DUSK: {
		"sky_top": "2c2b63", "sky_bottom": "ff8f5e", "cloud": "7d5a8c", "cloud_shade": "5a4372",
		"hills": ["6d5688", "4b4372", "33405a"], "sun": [150, 196, 24, "ff6a4a", "ffb070"],
		"tint": Color(0.84, 0.77, 0.86), "bird": "191830",
	},
}
## A bird crosses now and then, this many seconds apart at most.
const BIRD_GAP := 16.0

var camera: Camera2D
var mood: int = Mood.MIDDAY
## Floating Isles: a sea of cloud below instead of hills, since there's no ground down there.
var above_the_clouds: bool = false
var _sprites: Array[Sprite2D] = []
var _speeds: Array[float] = []
var _cloud_sprite: Sprite2D
var _cloud_drift: float = 0.0
var _birds: Node2D
var _flock: Array[Vector2] = []
var _flock_time: float = 0.0
var _next_flock: float = 3.0
var _rng := RandomNumberGenerator.new()


func setup(p_camera: Camera2D, p_mood: int = Mood.MIDDAY) -> void:
	camera = p_camera
	mood = p_mood


## The time of day for a place along the course. The boss hole is always dusk.
static func mood_for(hole_index: int, hole_count: int, is_boss: bool) -> int:
	if is_boss:
		return Mood.DUSK
	var progress: float = float(hole_index) / float(maxi(hole_count - 1, 1))
	if progress < 0.34:
		return Mood.MORNING
	return Mood.MIDDAY if progress < 0.67 else Mood.AFTERNOON


## What the course itself should be tinted to match the sky.
static func tint_of(p_mood: int) -> Color:
	return MOODS[p_mood]["tint"]


func _ready() -> void:
	layer = -10
	_rng.seed = 7 + mood
	var style: Dictionary = MOODS[mood]
	var sky := Sprite2D.new()
	sky.texture = ImageTexture.create_from_image(_make_sky(style))
	sky.centered = false
	add_child(sky)

	_cloud_sprite = _add_layer(_make_clouds(style), 0.05)

	if above_the_clouds:
		_add_layer(_make_cloud_sea(style, CLOUD_SEA_FAR, 301), 0.1)
		_add_layer(_make_cloud_sea(style, CLOUD_SEA_NEAR, 302), 0.25)
	else:
		var colours: Array = style["hills"]
		for i in HILLS.size():
			var hill: Array = HILLS[i]
			var image: Image = _make_hills(hill[1], hill[2], Color(colours[i]), hill[3])
			if i == 1:
				_paint_clubhouse(image, hill, Color(colours[i]))
			elif i == 2:
				_paint_tree_line(image, hill, Color(colours[i]))
			_add_layer(image, hill[0])

	_birds = Node2D.new()
	_birds.draw.connect(_draw_birds)
	add_child(_birds)
	# Sits between the clouds and the hills.
	move_child(_birds, 2)


func _process(delta: float) -> void:
	_cloud_drift += delta * 3.0
	var center_x: float = camera.get_screen_center_position().x
	for i in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		var offset: float = center_x * _speeds[i]
		if sprite == _cloud_sprite:
			offset += _cloud_drift
		sprite.region_rect.position.x = round(offset)
	_update_birds(delta)


func _update_birds(delta: float) -> void:
	_flock_time += delta
	if _flock.is_empty():
		if _flock_time >= _next_flock:
			_start_flock()
		return
	for i in _flock.size():
		_flock[i].x += 26.0 * delta
	if _flock[0].x > float(WIDTH) + 60.0:
		_flock.clear()
		_flock_time = 0.0
		_next_flock = _rng.randf_range(BIRD_GAP * 0.5, BIRD_GAP)
	_birds.queue_redraw()


func _start_flock() -> void:
	var start := Vector2(-20.0, _rng.randf_range(50.0, 120.0))
	var count: int = _rng.randi_range(3, 5)
	for i in count:
		var row: float = float((i + 1) / 2)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		_flock.append(start + Vector2(-row * 11.0, row * 6.0 * side))


func _draw_birds() -> void:
	var flap: bool = fmod(_flock_time, 0.5) > 0.25
	var color := Color(MOODS[mood]["bird"])
	for bird in _flock:
		var at: Vector2 = bird.round()
		var wing: float = 1.0 if flap else -1.0
		_birds.draw_rect(Rect2(at.x, at.y, 1, 1), color)
		_birds.draw_rect(Rect2(at.x - 1.0, at.y + wing, 1, 1), color)
		_birds.draw_rect(Rect2(at.x + 1.0, at.y + wing, 1, 1), color)
		_birds.draw_rect(Rect2(at.x - 2.0, at.y + wing * 2.0, 1, 1), color)
		_birds.draw_rect(Rect2(at.x + 2.0, at.y + wing * 2.0, 1, 1), color)


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


# Banded gradient with dithered joins between bands, and the sun painted in.
func _make_sky(style: Dictionary) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var top := Color(style["sky_top"])
	var bottom := Color(style["sky_bottom"])
	var bands: int = 14
	for y in HEIGHT:
		var t: float = clampf(float(y) / 240.0, 0.0, 1.0) * float(bands)
		var band: int = int(t)
		var fraction: float = t - float(band)
		for x in WIDTH:
			var dither: float = 0.25 if (x + y) % 2 == 0 else 0.75
			var step_band: int = band + (1 if fraction > dither else 0)
			image.set_pixel(x, y, top.lerp(bottom, float(step_band) / float(bands)))
	_paint_sun(image, style["sun"])
	return image


func _paint_sun(image: Image, sun: Array) -> void:
	var cx: int = sun[0]
	var cy: int = sun[1]
	var radius: int = sun[2]
	var edge := Color(sun[3])
	var core := Color(sun[4])
	var glow: int = radius + 6
	for dy in range(-glow, glow + 1):
		for dx in range(-glow, glow + 1):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
				continue
			var far: float = sqrt(float(dx * dx + dy * dy))
			if far <= float(radius) * 0.7:
				image.set_pixel(x, y, core)
			elif far <= float(radius):
				image.set_pixel(x, y, edge)
			elif far <= float(glow) and (x + y) % 2 == 0:
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(edge, 0.35))


func _make_clouds(style: Dictionary) -> Image:
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
			_paint_puff(image, px, py, rng.randi_range(7, 13), Color(style["cloud"]), Color(style["cloud_shade"]))
	return image


# A bank of cloud along the bottom of the picture, in place of the ground and hills.
func _make_cloud_sea(style: Dictionary, top: int, seed_value: int) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fill := Color(style["cloud"])
	var shade := Color(style["cloud_shade"])
	var x: int = 0
	while x < WIDTH:
		_paint_puff(image, x, top + rng.randi_range(0, 10), rng.randi_range(12, 22), fill, shade)
		x += rng.randi_range(12, 22)
	for py in range(top + 8, HEIGHT):
		for px in WIDTH:
			image.set_pixel(px, py, shade if (px + py) % 2 == 0 and py < top + 12 else fill)
	return image


func _paint_puff(image: Image, cx: int, cy: int, radius: int, fill: Color, shade: Color) -> void:
	for dy in range(-radius, 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var shaded: bool = dy > -radius / 3 and image.get_pixel(posmod(cx + dx, WIDTH), cy + dy).a == 0.0
			var color: Color = shade if shaded else fill
			image.set_pixel(posmod(cx + dx, WIDTH), clampi(cy + dy, 0, HEIGHT - 1), color)


# Sine terms use whole cycles across the width, so the layer tiles without a seam.
func _hill_y(x: int, horizon: float, wave: float, seed_value: float) -> float:
	var u: float = float(x) / float(WIDTH) * TAU
	return horizon \
			- sin(u * 2.0 + seed_value) * wave * 0.6 \
			- sin(u * 5.0 + seed_value * 2.0) * wave * 0.3 \
			- sin(u * 11.0 + seed_value * 3.0) * wave * 0.1


func _make_hills(horizon: float, wave: float, color: Color, seed_value: float) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var dark: Color = color.darkened(0.08)
	for x in WIDTH:
		var y: float = _hill_y(x, horizon, wave, seed_value)
		for py in range(int(y), HEIGHT):
			var fleck: bool = py > int(y) + 3 and (x + py) % 2 == 0 and (py - int(y)) % 16 < 3
			image.set_pixel(x, py, dark if fleck else color)
	return image


# The country club in the distance: a long white building, a dark roof and a flag on top.
func _paint_clubhouse(image: Image, hill: Array, color: Color) -> void:
	var base: int = int(_hill_y(CLUBHOUSE_X + 20, hill[1], hill[2], hill[3])) + 2
	var wall: Color = color.lightened(0.55)
	var roof: Color = color.darkened(0.42)
	var window: Color = color.darkened(0.25)
	_fill(image, CLUBHOUSE_X, base - 12, 42, 14, wall)
	_fill(image, CLUBHOUSE_X + 13, base - 18, 16, 8, wall)
	for row in 5:
		_fill(image, CLUBHOUSE_X - 2 + row, base - 13 - row, 46 - row * 2, 1, roof)
	for row in 4:
		_fill(image, CLUBHOUSE_X + 12 + row, base - 19 - row, 18 - row * 2, 1, roof)
	for col in [4, 11, 30, 36]:
		_fill(image, CLUBHOUSE_X + col, base - 7, 3, 4, window)
	_fill(image, CLUBHOUSE_X + 20, base - 7, 3, 7, window)
	_fill(image, CLUBHOUSE_X + 21, base - 30, 1, 9, roof)
	_fill(image, CLUBHOUSE_X + 22, base - 30, 6, 3, Color("e8483f").lerp(color, 0.35))


# A row of round trees along the nearest hill, in clumps.
func _paint_tree_line(image: Image, hill: Array, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	var dark: Color = color.darkened(0.16)
	var x: int = 0
	while x < WIDTH:
		var radius: int = rng.randi_range(5, 9)
		var ground: int = int(_hill_y(x, hill[1], hill[2], hill[3]))
		_paint_round_tree(image, x, ground - radius + 3, radius, dark)
		x += rng.randi_range(9, 15) if rng.randf() < 0.7 else rng.randi_range(45, 90)


func _paint_round_tree(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius and cy + dy >= 0 and cy + dy < HEIGHT:
				image.set_pixel(posmod(cx + dx, WIDTH), cy + dy, color)


func _fill(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for py in range(y, y + height):
		for px in range(x, x + width):
			if py >= 0 and py < HEIGHT:
				image.set_pixel(posmod(px, WIDTH), py, color)
