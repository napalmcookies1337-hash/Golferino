class_name ObstacleView
extends Node2D
## Draws every hazard.

const OUTLINE := Color("20202e")
const PAD_HELPS := Color("5fd068")
const PAD_NEUTRAL := Color("ffe25a")
const PAD_HURTS := Color("f0703a")

var obstacles: Array[Obstacle] = []
## In the swamp, the windmills are falling apart.
var swamp: bool = false
var _time: float = 0.0


func setup(p_obstacles: Array[Obstacle], p_swamp: bool = false) -> void:
	obstacles = p_obstacles
	swamp = p_swamp


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for obstacle in obstacles:
		if obstacle is CartObstacle:
			_draw_cart(obstacle)
		elif obstacle is WindmillObstacle:
			if swamp:
				_draw_swamp_windmill(obstacle)
			else:
				_draw_windmill(obstacle)
		elif obstacle is SprinklerObstacle:
			_draw_sprinkler(obstacle)
		elif obstacle is GooseObstacle:
			_draw_goose(obstacle)
		elif obstacle is BouncePadObstacle:
			_draw_pad(obstacle)
		elif obstacle is CoinObstacle:
			_draw_coin(obstacle)
		elif obstacle is FrogObstacle:
			_draw_frog(obstacle)
		elif obstacle is VentObstacle:
			_draw_vent(obstacle)
		elif obstacle is GatorObstacle:
			_draw_gator(obstacle)
		elif obstacle is LilyObstacle:
			_draw_lily(obstacle)


func _draw_frog(frog: FrogObstacle) -> void:
	var at: Vector2 = frog.center().round()
	var d: float = frog.direction
	var stretch: float = 2.0 if frog.is_hopping() else 0.0
	# Back leg, body, belly and the two big eyes on top.
	draw_rect(Rect2(at.x - 5.0 * d - 2.0, at.y + 1.0 + stretch, 5, 3), Color("20202e"))
	draw_rect(Rect2(at.x - 6, at.y - 4, 13, 9), OUTLINE)
	draw_rect(Rect2(at.x - 5, at.y - 3, 11, 7), Color("6fb040"))
	draw_rect(Rect2(at.x - 3, at.y + 1, 7, 3), Color("c8dc80"))
	draw_rect(Rect2(at.x + 3.0 * d - 2.0, at.y - 7, 5, 5), OUTLINE)
	draw_rect(Rect2(at.x + 3.0 * d - 1.0, at.y - 6, 3, 3), Color("f7f4e6"))
	draw_rect(Rect2(at.x + 3.0 * d + (0.0 if d > 0.0 else -1.0), at.y - 5, 1, 2), OUTLINE)


func _draw_vent(vent: VentObstacle) -> void:
	var base: Vector2 = vent.base().round()
	# A cracked mound, always visible so it can be planned around.
	draw_rect(Rect2(base.x - 8, base.y - 3, 17, 4), OUTLINE)
	draw_rect(Rect2(base.x - 7, base.y - 2, 15, 3), Color("5a5038"))
	draw_rect(Rect2(base.x - 2, base.y - 2, 5, 2), Color("a8c85a") if vent.stage() != VentObstacle.Stage.QUIET else Color("20201a"))
	match vent.stage():
		VentObstacle.Stage.WARNING:
			# Bubbles rise more and more as it builds.
			var count: int = 2 + int(vent.progress() * 8.0)
			for i in count:
				var rise: float = fmod(float(i) * 0.37 + _time * 1.4, 1.0)
				var at: Vector2 = base + Vector2(sin(float(i) * 2.4) * 6.0, -4.0 - rise * 22.0)
				draw_rect(Rect2(at.round(), Vector2(2, 2)), Color("c0dc70"))
		VentObstacle.Stage.BURST:
			for i in 34:
				var along: float = fmod(float(i) / 34.0 + _time * 1.5, 1.0)
				var spread: float = sin(float(i) * 2.399) * VentObstacle.HALF_WIDTH * (0.3 + along * 0.7)
				var at: Vector2 = base + Vector2(spread + vent.drift() * 0.1 * along, -4.0 - along * vent.height)
				var size: float = 3.0 if i % 3 == 0 else 2.0
				draw_rect(Rect2(at.round(), Vector2(size, size)), Color("cfe680") if i % 2 == 0 else Color("7f9c40"))
		_:
			# The odd lazy bubble.
			if fmod(_time + vent.x * 0.01, 1.6) < 0.5:
				draw_rect(Rect2(base.x, base.y - 5.0 - fmod(_time + vent.x * 0.01, 1.6) * 8.0, 2, 2), Color("8fa34f"))


# The same shape and size as the normal windmill, since it plays the same, but rotting away:
# grey boards, moss, a door hanging dark, a sagging roof with holes in it and torn sails.
func _draw_swamp_windmill(mill: WindmillObstacle) -> void:
	var hub: Vector2 = mill.hub().round()
	draw_set_transform(mill.base().round(), deg_to_rad(mill.rotation_deg))
	var top: float = -WindmillObstacle.TOWER_HEIGHT
	for row in int(WindmillObstacle.TOWER_HEIGHT) + 2:
		var y: float = 2.0 - float(row)
		var half: float = round(lerpf(9.0, 5.0, float(row) / WindmillObstacle.TOWER_HEIGHT))
		draw_rect(Rect2(-half - 1, y, half * 2 + 3, 1), OUTLINE)
		var board: bool = row % 5 == 0
		draw_rect(Rect2(-half, y, half * 2 + 1, 1), Color("4a4636") if board else Color("6b6650"))
		draw_rect(Rect2(half - 2, y, 2, 1), Color("4f4b3a"))
		# Moss creeping up from the base, thinning out as it climbs.
		if row < 22 and (row * 7) % 3 != 0:
			var patch: float = float((row * 13) % 5)
			draw_rect(Rect2(-half, y, patch, 1), Color("66803e"))
	# Missing boards, showing the dark inside.
	draw_rect(Rect2(-5, -30, 4, 3), Color("1c1a14"))
	draw_rect(Rect2(1, -22, 3, 4), Color("1c1a14"))
	draw_rect(Rect2(-3, -38, 3, 2), Color("1c1a14"))
	var door_half: float = WindmillObstacle.DOOR_HALF_WIDTH
	var door_height: float = WindmillObstacle.DOOR_HEIGHT
	draw_rect(Rect2(-door_half - 1, -door_height - 1, door_half * 2 + 3, door_height + 1), Color("35301f"))
	draw_rect(Rect2(-door_half, -door_height, door_half * 2 + 1, door_height), Color("0f0e0a"))
	# A sagging roof with a bite out of it.
	var roof := PackedVector2Array([Vector2(-8, top - 1), Vector2(8, top + 1), Vector2(2, top - 6), Vector2(-1, top - 10)])
	draw_colored_polygon(roof, Color("4e3a2c"))
	draw_rect(Rect2(1, top - 3, 3, 2), Color("1c1a14"))
	# Strands of moss hanging off the eaves.
	for strand: Array in [[-7.0, 7.0], [-3.0, 4.0], [5.0, 8.0]]:
		draw_rect(Rect2(float(strand[0]), top, 1, float(strand[1])), Color("7c8a52"))
	draw_set_transform(Vector2.ZERO)

	for i in WindmillObstacle.BLADES:
		var tip: Vector2 = mill.blade_tip(i).round()
		draw_line(hub, tip, OUTLINE, 4.0)
		draw_line(hub, tip, Color("6b6650"), 2.0)
		# The tatters of a sail: rags along each arm, different on each one.
		var along: Vector2 = (tip - hub) / WindmillObstacle.BLADE_LENGTH
		var across: Vector2 = along.orthogonal()
		for rag in 3:
			var at: Vector2 = hub + along * (14.0 + float((rag * 11 + i * 7) % 26))
			draw_line(at, at + across * float(3 + (rag + i) % 4), Color("8a8468"), 2.0)
	draw_circle(hub, 2.5, OUTLINE)


# Long and low, with its jaws opening upward from the hinge as a ball comes near. Drawn facing +x
# from a point on the ground, then mirrored for the way it faces.
func _draw_gator(gator: GatorObstacle) -> void:
	if gator.is_gone():
		return
	var flashing: bool = gator.eaten
	# Blinks between a bright flash and nothing at all until it's gone.
	if flashing and int(gator.flash * 14.0) % 2 == 1:
		return
	var skin: Color = Color("f7f4e6") if flashing else Color("4f7a3a")
	var dark: Color = Color("ffffff") if flashing else Color("35572a")
	var belly: Color = Color("ffe25a") if flashing else Color("c8cf90")
	draw_set_transform(gator.base().round(), 0.0, Vector2(gator.side, 1.0))
	# The tail, tapering away behind.
	var tail := PackedVector2Array([Vector2(-16, -1), Vector2(-16, -8), Vector2(-34, -1)])
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(-16, -10), Vector2(-37, 0)]), OUTLINE)
	draw_colored_polygon(tail, dark)
	# The feet, then the body with its ridged back.
	for foot: float in [-11.0, 5.0]:
		draw_rect(Rect2(foot - 1.0, -3, 7, 4), OUTLINE)
		draw_rect(Rect2(foot, -2, 5, 2), dark)
	draw_rect(Rect2(-18, -11, 30, 10), OUTLINE)
	draw_rect(Rect2(-17, -10, 28, 8), skin)
	draw_rect(Rect2(-17, -4, 28, 2), belly)
	for ridge in 6:
		draw_rect(Rect2(-15.0 + float(ridge) * 4.5, -13, 3, 3), dark)
	# The mouth: a lower jaw along the ground, red inside once it's opening, and an upper jaw
	# swinging up from the hinge.
	var hinge := Vector2(10, -7)
	var open_angle: float = deg_to_rad(-48.0 * gator.jaw)
	var snout: Vector2 = Vector2(22, 0).rotated(open_angle)
	var upper_top: Vector2 = Vector2(0, -4).rotated(open_angle)
	draw_rect(Rect2(10, -5, 24, 5), OUTLINE)
	draw_rect(Rect2(11, -4, 22, 3), belly)
	if gator.jaw > 0.05:
		draw_colored_polygon(PackedVector2Array([hinge, hinge + snout, Vector2(32, -5)]), Color("a82f35"))
		for tooth in 4:
			draw_rect(Rect2(16.0 + float(tooth) * 5.0, -7, 2, 2), Color("f7f4e6"))
			var along: Vector2 = hinge + snout * (0.35 + float(tooth) * 0.2)
			draw_rect(Rect2(along.round() + Vector2(0, 1), Vector2(2, 2)), Color("f7f4e6"))
	draw_line(hinge, hinge + snout, OUTLINE, 6.0)
	draw_line(hinge, hinge + snout, skin, 4.0)
	# The eye, up on top of the head.
	var eye: Vector2 = hinge + upper_top + Vector2(1, -2)
	draw_rect(Rect2(eye.round() + Vector2(-2, -2), Vector2(5, 5)), OUTLINE)
	draw_rect(Rect2(eye.round() + Vector2(-1, -1), Vector2(3, 3)), Color("ffe25a"))
	draw_rect(Rect2(eye.round(), Vector2(1, 2)), OUTLINE)
	draw_set_transform(Vector2.ZERO)


func _draw_lily(lily: LilyObstacle) -> void:
	var half: float = lily.width / 2.0
	var y: float = round(lily.y)
	# Nearly flat, seen from the side: a low dome with a split in it.
	draw_rect(Rect2(lily.x - half, y - 2, lily.width, 3), OUTLINE)
	draw_rect(Rect2(lily.x - half + 1.0, y - 1, lily.width - 2.0, 2), Color("6fb040"))
	draw_rect(Rect2(lily.x - half + 3.0, y - 3, lily.width - 6.0, 1), Color("a8d860"))
	draw_rect(Rect2(lily.x + half * 0.4, y - 3, 2, 3), OUTLINE)
	if lily.has_flower:
		var at: Vector2 = Vector2(lily.x - half * 0.5, y - 5).round()
		draw_rect(Rect2(at.x - 2, at.y, 5, 2), Color("f79ac0"))
		draw_rect(Rect2(at.x - 1, at.y - 2, 3, 2), Color("ffd0e0"))
		draw_rect(Rect2(at.x, at.y - 1, 1, 1), Color("ffe25a"))


func _draw_coin(coin: CoinObstacle) -> void:
	if coin.collected:
		return
	var at: Vector2 = coin.at.round()
	# It turns on the spot, by narrowing and widening.
	var half: float = round(absf(cos(_time * 3.0 + at.x * 0.05)) * 3.0)
	draw_rect(Rect2(at.x - half - 1.0, at.y - 4.0, half * 2.0 + 3.0, 9.0), OUTLINE)
	draw_rect(Rect2(at.x - half, at.y - 3.0, half * 2.0 + 1.0, 7.0), Color("ffd23c"))
	draw_rect(Rect2(at.x - half, at.y - 3.0, 1.0, 7.0), Color("fff0a0"))


func _draw_pad(pad: BouncePadObstacle) -> void:
	# The spring face's colour and arrows say which way it fires: green toward the cup,
	# orange away, yellow straight up.
	var color: Color = PAD_NEUTRAL
	if not pad.is_flat():
		color = PAD_HELPS if pad.faces_cup() else PAD_HURTS

	var half_length: float = BouncePadObstacle.HALF_LENGTH
	var half_thick: float = BouncePadObstacle.HALF_THICKNESS
	draw_set_transform(pad.center, deg_to_rad(pad.rotation_deg))
	# Local axes: +x along the pad, -y out of the spring face.
	draw_rect(Rect2(-half_length - 1.0, -half_thick - 1.0, half_length * 2.0 + 2.0, half_thick * 2.0 + 2.0), OUTLINE)
	draw_rect(Rect2(-half_length, -half_thick, half_length * 2.0, half_thick * 2.0), Color("4a4a5e"))
	# The spring strip sits proud of the body, and dips when it fires.
	var strip_y: float = -half_thick + pad.squash * 1.5
	draw_rect(Rect2(-half_length, strip_y, half_length * 2.0, 2.0), color)
	draw_set_transform(Vector2.ZERO)

	var bob: float = 3.0 + sin(_time * 4.0) * 1.5 + pad.squash * 6.0
	for row in 2:
		_draw_chevron(pad.center + pad.normal * (6.0 + bob + float(row) * 5.0), pad.normal, color)


func _draw_chevron(at: Vector2, direction: Vector2, color: Color) -> void:
	var side: Vector2 = Vector2(-direction.y, direction.x) * 4.0
	var tip: Vector2 = (at + direction * 3.0).round()
	var left: Vector2 = (at - side).round()
	var right: Vector2 = (at + side).round()
	draw_line(left, tip, OUTLINE, 3.0)
	draw_line(right, tip, OUTLINE, 3.0)
	draw_line(left, tip, color, 1.0)
	draw_line(right, tip, color, 1.0)


func _draw_cart(cart: CartObstacle) -> void:
	# Drawn facing +x from a point on the ground, then mirrored for the way it's going.
	var ground: Vector2 = (cart.center() + Vector2(0, CartObstacle.RIDE_HEIGHT)).round()
	draw_set_transform(ground, 0.0, Vector2(cart.direction, 1.0))

	# The golf bag on the back.
	draw_rect(Rect2(-30, -34, 8, 22), OUTLINE)
	draw_rect(Rect2(-29, -33, 6, 20), Color("a92b35"))
	draw_rect(Rect2(-28, -38, 1, 5), Color("c7ccd6"))
	draw_rect(Rect2(-25, -40, 1, 7), Color("c7ccd6"))

	# Roof posts, behind the driver.
	draw_rect(Rect2(-21, -44, 3, 26), OUTLINE)
	draw_rect(Rect2(18, -44, 3, 22), OUTLINE)

	# The driver, sitting at about the golfer's own scale.
	draw_rect(Rect2(-9, -31, 11, 16), OUTLINE)
	draw_rect(Rect2(-8, -30, 9, 14), Color("e8c34a"))
	draw_circle(Vector2(-3, -35), 5.5, OUTLINE)
	draw_circle(Vector2(-3, -35), 4.5, Color("f0b98a"))
	draw_rect(Rect2(-8, -40, 10, 4), Color("f7f4e6"))
	draw_rect(Rect2(2, -37, 4, 1), Color("f7f4e6"))
	# Arm reaching to the steering wheel.
	draw_line(Vector2(-1, -25), Vector2(9, -23), OUTLINE, 3.0)
	draw_line(Vector2(9, -27), Vector2(13, -20), OUTLINE, 2.0)

	# The body: a long low tub with a raised nose.
	draw_rect(Rect2(-31, -21, 62, 15), OUTLINE)
	draw_rect(Rect2(-30, -20, 60, 13), Color("f7f4e6"))
	draw_rect(Rect2(-30, -11, 60, 4), Color("2b8c8c"))
	draw_rect(Rect2(12, -25, 19, 6), OUTLINE)
	draw_rect(Rect2(13, -24, 17, 6), Color("f7f4e6"))
	draw_rect(Rect2(28, -19, 2, 3), Color("ffe25a"))

	# The roof.
	draw_rect(Rect2(-29, -47, 58, 5), OUTLINE)
	draw_rect(Rect2(-28, -46, 56, 3), Color("2b8c8c"))

	# Wheels.
	for side: float in [-19.0, 19.0]:
		draw_circle(Vector2(side, -6), 7.0, OUTLINE)
		draw_circle(Vector2(side, -6), 3.0, Color("8d97a8"))
	draw_set_transform(Vector2.ZERO)


func _draw_windmill(mill: WindmillObstacle) -> void:
	var hub: Vector2 = mill.hub().round()
	# A tapered tower, slightly wider at the base, drawn upright then tilted as a whole.
	draw_set_transform(mill.base().round(), deg_to_rad(mill.rotation_deg))
	var top: float = -WindmillObstacle.TOWER_HEIGHT
	for row in int(WindmillObstacle.TOWER_HEIGHT) + 2:
		var y: float = 2.0 - float(row)
		var half: float = round(lerpf(9.0, 5.0, float(row) / WindmillObstacle.TOWER_HEIGHT))
		draw_rect(Rect2(-half - 1, y, half * 2 + 3, 1), OUTLINE)
		var brick: bool = row % 6 == 0
		draw_rect(Rect2(-half, y, half * 2 + 1, 1), Color("c9b08a") if brick else Color("e3cfa4"))
		draw_rect(Rect2(half - 2, y, 2, 1), Color("b39a78"))
	var door_half: float = WindmillObstacle.DOOR_HALF_WIDTH
	var door_height: float = WindmillObstacle.DOOR_HEIGHT
	draw_rect(Rect2(-door_half - 1, -door_height - 1, door_half * 2 + 3, door_height + 1), Color("5d3f2b"))
	draw_rect(Rect2(-door_half, -door_height, door_half * 2 + 1, door_height), Color("1d1410"))
	var roof := PackedVector2Array([Vector2(-8, top - 1), Vector2(8, top - 1), Vector2(0, top - 11)])
	draw_colored_polygon(roof, Color("a92b35"))
	draw_set_transform(Vector2.ZERO)

	for i in WindmillObstacle.BLADES:
		var tip: Vector2 = mill.blade_tip(i).round()
		draw_line(hub, tip, OUTLINE, 4.0)
		draw_line(hub, tip, Color("f7f4e6"), 2.0)
	draw_circle(hub, 2.5, OUTLINE)


func _draw_sprinkler(sprinkler: SprinklerObstacle) -> void:
	var base: Vector2 = sprinkler.base().round()
	draw_rect(Rect2(base.x - 2, base.y - 4, 5, 5), OUTLINE)
	draw_rect(Rect2(base.x - 1, base.y - 3, 3, 3), Color("8d97a8"))
	if not sprinkler.is_on():
		return
	var across: Vector2 = sprinkler.direction.orthogonal()
	var droplets: int = 26
	for i in droplets:
		var along: float = fmod(float(i) / float(droplets) + _time * 0.9, 1.0)
		var spread: float = sin(float(i) * 2.399) * SprinklerObstacle.HALF_WIDTH * minf(along * 2.5, 1.0)
		var at: Vector2 = base + sprinkler.direction * (4.0 + along * sprinkler.height) + across * spread
		var color: Color = Color("d8f4ff") if i % 2 == 0 else Color("7fc6ec")
		draw_rect(Rect2(at.round(), Vector2(2, 2)), color)


func _draw_goose(goose: GooseObstacle) -> void:
	var at: Vector2 = goose.center().round()
	var d: float = goose.direction
	var flap: float = sin(goose.clock * 9.0)
	# Body, neck and head, drawn outline first.
	draw_rect(Rect2(at.x - 6, at.y - 3, 13, 7), OUTLINE)
	draw_rect(Rect2(at.x - 5, at.y - 2, 11, 5), Color("f7f4e6"))
	draw_line(at + Vector2(4 * d, -1), at + Vector2(9 * d, -6), OUTLINE, 3.0)
	draw_line(at + Vector2(4 * d, -1), at + Vector2(9 * d, -6), Color("2f2f3d"), 1.0)
	draw_rect(Rect2(at.x + 9 * d - 1, at.y - 7, 3, 3), Color("2f2f3d"))
	draw_rect(Rect2(at.x + 11 * d - (1 if d < 0 else 0), at.y - 6, 2, 1), Color("e8a23a"))
	# The wing beats up and down.
	var wing_y: float = round(flap * 6.0)
	var wing := PackedVector2Array([
		at + Vector2(-3, 0), at + Vector2(3, 0), at + Vector2(-5 * d, wing_y - 2.0)])
	draw_colored_polygon(wing, Color("c9d2de"))
