class_name CollectionScreen
extends Node2D
## Everything the shop can sell, from the title menu. Anything still locked is a dark
## silhouette with its name and effect hidden. Works with keyboard, controller and mouse.

signal done

const GROUPS := [
	{ "kind": Items.KIND_STICKER, "label": "STICKERS" },
	{ "kind": Items.KIND_BALL, "label": "BALLS" },
	{ "kind": Items.KIND_PERK, "label": "PERKS" },
	{ "kind": Items.KIND_STROKES, "label": "BONUS" },
]
const KIND_NAMES := {
	Items.KIND_STICKER: "STICKER",
	Items.KIND_BALL: "BALL",
	Items.KIND_PERK: "PERK",
	Items.KIND_STROKES: "BONUS",
}
const HIDDEN_NAME := "???"
## The ball everyone starts with. The shop doesn't sell it, but it belongs with the others.
const PLAIN_BALL := {
	"id": "plain_ball",
	"kind": Items.KIND_BALL,
	"name": "PLAIN BALL",
	"text": "NO TRICKS, NO SURPRISES",
}
const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const LOCKED_PANEL := Color("2c5261")
const TEXT := Color("f7f4e6")
const DIM := Color("8f9caa")
const ACCENT := Color("ffe25a")
const CELL_W := 47.0
const CELL_H := 40.0
const CELL_GAP := 4.0
const LEFT := 42.0
const TOP := 52.0
const ROW_PITCH := 54.0
const DETAIL := Rect2(42, 262, 556, 62)
const BACK_BUTTON := Rect2(42, 332, 64, 18)
const CLUB_NAMES := { "driver": "DRIVER", "iron": "IRON", "putter": "PUTTER" }

var profile: Profile
## Each row of the grid, as a list of items.
var rows: Array = []
var row: int = 0
var column: int = 0

var _menu_input := MenuInput.new()
var _time: float = 0.0
# Keeps the player's place when they pass through a shorter row.
var _wanted_column: int = 0


func setup(p_profile: Profile) -> void:
	profile = p_profile
	rows.clear()
	for group: Dictionary in GROUPS:
		var items: Array[Dictionary] = []
		if group["kind"] == Items.KIND_BALL:
			items.append(PLAIN_BALL)
		for item: Dictionary in Items.CATALOG:
			if item["kind"] == group["kind"]:
				items.append(item)
		rows.append(items)


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover(event.position)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if BACK_BUTTON.has_point(event.position):
				done.emit()
			else:
				_hover(event.position)
		return
	if event.is_action_pressed("swing", false) or event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		done.emit()
		return
	var step: Vector2i = _menu_input.step(event)
	if step != Vector2i.ZERO:
		move(step)
		Sound.sfx("menu_move")
		get_viewport().set_input_as_handled()


## Moves the selection. Each direction wraps round its row or column.
func move(step: Vector2i) -> void:
	if step.x != 0:
		column = posmod(column + step.x, (rows[row] as Array).size())
		_wanted_column = column
	elif step.y != 0:
		row = posmod(row + step.y, rows.size())
		column = mini(_wanted_column, (rows[row] as Array).size() - 1)


func selected_item() -> Dictionary:
	return rows[row][column]


## What the details panel says about an item. A locked one gives nothing away.
func describe(item: Dictionary) -> Dictionary:
	var id: String = str(item["id"])
	if not is_owned(id):
		return {
			"kind": "LOCKED",
			"name": HIDDEN_NAME,
			"text": "FINISH A DUEL WITH THE RIVAL TO UNLOCK THE NEXT ITEM",
			"more": "BEATING THE RIVAL UNLOCKS TWO",
		}
	var more: Array[String] = []
	if item.has("clubs"):
		var clubs: Array[String] = []
		for club: Variant in item["clubs"]:
			clubs.append(str(CLUB_NAMES[club]))
		more.append("FITS %s" % ", ".join(clubs))
	if id == PLAIN_BALL["id"]:
		more.append("EVERY RUN STARTS WITH ONE")
	else:
		more.append("FULL PRICE %d COINS" % int(item["price"]))
		more.append("UNLOCKED BY FINISHING A DUEL" if item.has("unlock") else "IN THE SHOP FROM THE START")
	return {
		"kind": str(KIND_NAMES[item["kind"]]),
		"name": str(item["name"]),
		"text": str(item["text"]),
		"more": "   ".join(more),
	}


func is_owned(id: String) -> bool:
	return id == PLAIN_BALL["id"] or profile.has_item(id)


func count_all() -> int:
	return Items.CATALOG.size() + 1


func count_owned() -> int:
	var count: int = 1
	for item: Dictionary in Items.CATALOG:
		if profile.has_item(str(item["id"])):
			count += 1
	return count


func _cell_rect(cell_row: int, cell_column: int) -> Rect2:
	var x: float = LEFT + float(cell_column) * (CELL_W + CELL_GAP)
	return Rect2(x, TOP + float(cell_row) * ROW_PITCH, CELL_W, CELL_H)


func _hover(at: Vector2) -> void:
	for cell_row in rows.size():
		for cell_column in (rows[cell_row] as Array).size():
			if _cell_rect(cell_row, cell_column).has_point(at):
				if cell_row != row or cell_column != column:
					row = cell_row
					column = cell_column
					_wanted_column = column
					Sound.sfx("menu_move")
				return


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_shadowed(self, "COLLECTION", Vector2(LEFT, 12), ACCENT, 3)
	var count_text: String = "UNLOCKED %d OF %d" % [count_owned(), count_all()]
	PixelFont.draw(self, count_text, Vector2(DETAIL.end.x - float(PixelFont.text_width(count_text)), 24), TEXT)
	for cell_row in rows.size():
		var label_y: float = TOP + float(cell_row) * ROW_PITCH - 10.0
		PixelFont.draw(self, str(GROUPS[cell_row]["label"]), Vector2(LEFT, label_y), DIM)
		for cell_column in (rows[cell_row] as Array).size():
			_draw_cell(cell_row, cell_column)
	_draw_details()
	draw_rect(BACK_BUTTON, PANEL)
	draw_rect(BACK_BUTTON, DIM, false, 1.0)
	PixelFont.draw_centered(self, "< BACK", BACK_BUTTON.get_center().x, BACK_BUTTON.position.y + 6.0, TEXT)
	PixelFont.draw_centered(self, "ARROWS TO BROWSE   SPACE OR ESC TO GO BACK", 340.0, 338.0, DIM)


func _draw_cell(cell_row: int, cell_column: int) -> void:
	var item: Dictionary = rows[cell_row][cell_column]
	var id: String = str(item["id"])
	var owned: bool = is_owned(id)
	var is_selected: bool = cell_row == row and cell_column == column
	var rect: Rect2 = _cell_rect(cell_row, cell_column)
	draw_rect(rect, PANEL if owned else LOCKED_PANEL)
	draw_rect(rect, ACCENT if is_selected else Color(1, 1, 1, 0.15), false, 1.0)
	var center: Vector2 = rect.get_center()
	# The picked item bobs, unless it's locked.
	if is_selected and owned:
		center.y += round(sin(_time * 5.0))
	ItemArt.draw(self, id, center, 2, not owned)
	# A gold corner marks anything earned by finishing a duel.
	if owned and item.has("unlock"):
		draw_rect(Rect2(rect.end.x - 5.0, rect.position.y + 2.0, 3, 3), ACCENT)


func _draw_details() -> void:
	var item: Dictionary = selected_item()
	var words: Dictionary = describe(item)
	var owned: bool = is_owned(str(item["id"]))
	draw_rect(DETAIL, PANEL)
	draw_rect(DETAIL, DIM, false, 1.0)
	var art_rect := Rect2(DETAIL.position + Vector2(6, 6), Vector2(50, 50))
	draw_rect(art_rect, PANEL if owned else LOCKED_PANEL)
	ItemArt.draw(self, str(item["id"]), art_rect.get_center(), 3, not owned)
	var x: float = art_rect.end.x + 10.0
	PixelFont.draw(self, str(words["kind"]), Vector2(x, DETAIL.position.y + 6.0), DIM)
	PixelFont.draw_shadowed(self, str(words["name"]), Vector2(x, DETAIL.position.y + 16.0), TEXT, 2)
	PixelFont.draw(self, str(words["text"]), Vector2(x, DETAIL.position.y + 36.0), ACCENT)
	PixelFont.draw(self, str(words["more"]), Vector2(x, DETAIL.position.y + 48.0), DIM)
