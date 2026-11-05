class_name ScreenWipe
extends Node2D
## A dark screen with a round opening that grows until the new scene is fully showing, then
## removes itself. Only for looks: the scene behind it is already running and takes input.

const COLOR := Color("10121c")
const TIME := 0.42
const ROW := 2.0
## Just past the screen's far corner, from anywhere on it.
const FULL_RADIUS := 740.0

var center := Vector2(320, 180)
var _age: float = 0.0


## Opens up from a spot on the screen. Add it above whatever it should cover.
static func open(parent: Node, from: Vector2 = Vector2(320, 180)) -> ScreenWipe:
	var wipe := ScreenWipe.new()
	wipe.center = from
	parent.add_child(wipe)
	return wipe


func _process(delta: float) -> void:
	_age += delta
	if _age >= TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / TIME, 0.0, 1.0)
	var radius: float = FULL_RADIUS * t * t
	var y: float = 0.0
	while y < 360.0:
		var dy: float = y + ROW / 2.0 - center.y
		if absf(dy) >= radius:
			draw_rect(Rect2(0, y, 640, ROW), COLOR)
		else:
			var half: float = round(sqrt(radius * radius - dy * dy))
			draw_rect(Rect2(0, y, maxf(center.x - half, 0.0), ROW), COLOR)
			var right: float = center.x + half
			if right < 640.0:
				draw_rect(Rect2(right, y, 640.0 - right, ROW), COLOR)
		y += ROW
