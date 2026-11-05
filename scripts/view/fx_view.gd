class_name FxView
extends Node2D
## Simple pixel particles for strikes, landings, splashes and holing out.

const GRAVITY := 170.0
const FLOAT_TIME := 0.8
const RING_TIME := 0.5

var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _floats: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func dust(at: Vector2, color: Color, count: int, direction: int) -> void:
	for _i in count:
		var angle: float = _rng.randf_range(-PI * 0.9, -PI * 0.1)
		var velocity := Vector2(cos(angle), sin(angle)) * _rng.randf_range(15.0, 55.0)
		velocity.x += float(direction) * 25.0
		_spawn(at, velocity, _rng.randf_range(0.25, 0.5), color)


func splash(at: Vector2) -> void:
	for _i in 26:
		var velocity := Vector2(_rng.randf_range(-45.0, 45.0), _rng.randf_range(-115.0, -30.0))
		var color: Color = Color("d8f4ff") if _rng.randf() < 0.5 else Color("7fc6ec")
		_spawn(at, velocity, _rng.randf_range(0.4, 0.8), color)
	ring(at, Color("d8f4ff"), 22.0)
	ring(at, Color("7fc6ec"), 12.0)


func confetti(at: Vector2) -> void:
	var colors: Array[Color] = [
		Color("ffe25a"), Color("e8584a"), Color("5ad0d0"), Color("ffffff"), Color("9edb5c"),
	]
	for _i in 46:
		var velocity := Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-150.0, -40.0))
		_spawn(at, velocity, _rng.randf_range(0.7, 1.3), colors[_rng.randi() % colors.size()])


## Sparks flying out in every direction, for a clean or mighty strike.
func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var angle: float = TAU * float(i) / float(count) + _rng.randf_range(-0.2, 0.2)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * _rng.randf_range(0.6, 1.1)
		_spawn(at, velocity, _rng.randf_range(0.25, 0.45), color)


## A flat ring that spreads and fades, seen edge-on.
func ring(at: Vector2, color: Color, width: float) -> void:
	_rings.append({ "pos": at, "color": color, "width": width, "age": 0.0 })


## Words that drift up from a spot and fade, like the coin count from a pickup.
func float_text(at: Vector2, text: String, color: Color) -> void:
	_floats.append({ "pos": at, "text": text, "color": color, "age": 0.0 })


func _spawn(at: Vector2, velocity: Vector2, life: float, color: Color) -> void:
	_particles.append({ "pos": at, "vel": velocity, "life": life, "color": color })


func _process(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(i)
			continue
		var velocity: Vector2 = particle["vel"]
		velocity.y += GRAVITY * delta
		particle["vel"] = velocity
		particle["pos"] = Vector2(particle["pos"]) + velocity * delta
	_age_all(_rings, RING_TIME, delta)
	_age_all(_floats, FLOAT_TIME, delta)
	queue_redraw()


func _age_all(list: Array[Dictionary], lifetime: float, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		list[i]["age"] = float(list[i]["age"]) + delta
		if float(list[i]["age"]) >= lifetime:
			list.remove_at(i)


func _draw() -> void:
	for particle in _particles:
		var at: Vector2 = Vector2(particle["pos"]).round()
		draw_rect(Rect2(at.x, at.y, 2, 2), particle["color"])
	for spread in _rings:
		var t: float = float(spread["age"]) / RING_TIME
		var half: float = round(float(spread["width"]) * t)
		var at: Vector2 = Vector2(spread["pos"]).round()
		var color: Color = spread["color"]
		color.a = 1.0 - t
		draw_rect(Rect2(at.x - half, at.y, 3, 1), color)
		draw_rect(Rect2(at.x + half - 2.0, at.y, 3, 1), color)
	for rising in _floats:
		var t: float = float(rising["age"]) / FLOAT_TIME
		var at: Vector2 = Vector2(rising["pos"]) + Vector2(0, -6.0 - 16.0 * t)
		var color: Color = rising["color"]
		color.a = 1.0 if t < 0.6 else (1.0 - t) / 0.4
		PixelFont.draw_centered(self, str(rising["text"]), round(at.x), round(at.y), color)
