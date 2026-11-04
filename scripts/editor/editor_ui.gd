class_name EditorUI
extends Node2D
## A small immediate-mode UI: the painter redraws every button each frame, and each one
## records where it is so clicks can find it. Uses the game's own pixel font throughout.

const PANEL := Color(0.07, 0.09, 0.16, 0.92)
const EDGE := Color("5a6275")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const ACCENT := Color("ffe25a")
const BUTTON := Color("2a3144")
const BUTTON_HOVER := Color("3d4760")
const BUTTON_ACTIVE := Color("8a6f1e")
const WARNING := Color("ff9a6a")

## Called with this node to draw the whole UI.
var painter: Callable
var mouse: Vector2 = Vector2.ZERO

var _regions: Array[Dictionary] = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_regions.clear()
	if painter.is_valid():
		painter.call(self)


## Runs whatever is under a click. Returns true if the click landed on the UI.
func click(at: Vector2) -> bool:
	for i in range(_regions.size() - 1, -1, -1):
		var region: Dictionary = _regions[i]
		if Rect2(region["rect"]).has_point(at):
			var action: Callable = region["action"]
			if action.is_valid():
				action.call()
			return true
	return false


func is_over(at: Vector2) -> bool:
	for region in _regions:
		if Rect2(region["rect"]).has_point(at):
			return true
	return false


## A background that also stops clicks reaching the map behind it.
func panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, EDGE, false, 1.0)
	_regions.append({ "rect": rect, "action": Callable() })


## Makes everything drawn so far unclickable, for dialogs.
func block_all() -> void:
	_regions.clear()
	_regions.append({ "rect": Rect2(0, 0, 640, 360), "action": Callable() })


func button(rect: Rect2, label: String, action: Callable, active: bool = false, enabled: bool = true) -> void:
	var hovering: bool = enabled and rect.has_point(mouse)
	var fill: Color = BUTTON_ACTIVE if active else (BUTTON_HOVER if hovering else BUTTON)
	draw_rect(rect, fill)
	draw_rect(rect, EDGE, false, 1.0)
	var color: Color = TEXT if enabled else Color(DIM, 0.6)
	var x: float = rect.position.x + (rect.size.x - float(PixelFont.text_width(label))) / 2.0
	var y: float = rect.position.y + (rect.size.y - float(PixelFont.HEIGHT)) / 2.0
	PixelFont.draw(self, label, Vector2(round(x), round(y)), color)
	_regions.append({ "rect": rect, "action": action if enabled else Callable() })


func label(text: String, at: Vector2, color: Color = TEXT) -> void:
	PixelFont.draw(self, text, at, color)
