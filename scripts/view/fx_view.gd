class_name FxView
extends Node2D
## Simple pixel particles for strikes, landings, splashes and holing out.

const GRAVITY := 170.0

var _particles: Array[Dictionary] = []
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


func confetti(at: Vector2) -> void:
	var colors: Array[Color] = [
		Color("ffe25a"), Color("e8584a"), Color("5ad0d0"), Color("ffffff"), Color("9edb5c"),
	]
	for _i in 46:
		var velocity := Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-150.0, -40.0))
		_spawn(at, velocity, _rng.randf_range(0.7, 1.3), colors[_rng.randi() % colors.size()])


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
	queue_redraw()


func _draw() -> void:
	for particle in _particles:
		var at: Vector2 = Vector2(particle["pos"]).round()
		draw_rect(Rect2(at.x, at.y, 2, 2), particle["color"])
