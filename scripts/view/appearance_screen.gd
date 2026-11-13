class_name AppearanceScreen
extends Node2D
## Chooses the golfer and what it wears, with coins saved from finished runs. The golfer on the
## left tries on whatever the cursor is over. Each column is one color, so going down a column
## makes a matching outfit. Works with keyboard, controller and mouse.

signal done

enum Kind { MODEL, PIECE, BACK }

const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const TEXT := Color("f7f4e6")
const DIM := Color("8f9caa")
const ACCENT := Color("ffe25a")
const GOOD := Color("6fe07a")
const COIN := Color("f2c83f")
const OUTLINE := Color("20202e")
const LOCKED := Color("1a2a33")
const PREVIEW_PANEL := Rect2(20, 44, 208, 280)
const PREVIEW_GROUND := 300.0
const PREVIEW_SCALE := 4.0
const LABEL_X := 244.0
const CELLS_X := 316.0
const CELL_STEP := 50.0
const CELL_SIZE := Vector2(42, 24)
const MODEL_Y := 44.0
const MODEL_SIZE := Vector2(82, 20)
const ROWS_Y := 80.0
const ROW_STEP := 30.0
const INFO_Y := 206.0
const BACK_BUTTON := Rect2(42, 332, 64, 18)
const MODEL_NAMES := { Wardrobe.MALE: "MALE", Wardrobe.FEMALE: "FEMALE" }

var profile: Profile
## What can be picked, each with its "kind" and "rect", and what it stands for.
var cells: Array[Dictionary] = []
var cursor: int = 0

var _menu_input := MenuInput.new()
var _golfer: TitleGolfer


func setup(p_profile: Profile) -> void:
	profile = p_profile


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	Sound.set_outdoors(false)

	# Drawn big, so the clothes can be seen. It keeps practising its drive as it does on the title.
	var holder := Node2D.new()
	holder.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	add_child(holder)
	_golfer = TitleGolfer.new()
	_golfer.setup_title(0.0, func(_x: float) -> float: return 0.0)
	holder.add_child(_golfer)
	var ball_offset: float = sin(deg_to_rad(_golfer._address_angle())) * (GolferView.ARM_LENGTH + _golfer._club_length())
	holder.position = Vector2(PREVIEW_PANEL.get_center().x + ball_offset * PREVIEW_SCALE, PREVIEW_GROUND)

	_build_cells()
	cursor = _model_cell(profile.model)
	_try_on()


func _process(_delta: float) -> void:
	queue_redraw()


func _build_cells() -> void:
	cells.clear()
	for i in Wardrobe.MODELS.size():
		var rect := Rect2(Vector2(CELLS_X + float(i) * (MODEL_SIZE.x + 6.0), MODEL_Y), MODEL_SIZE)
		cells.append({ "kind": Kind.MODEL, "rect": rect, "model": Wardrobe.MODELS[i] })
	for row in Wardrobe.SLOTS.size():
		var slot: String = Wardrobe.SLOTS[row]
		var items: Array[Dictionary] = Wardrobe.items_for(profile.model, slot)
		for i in items.size():
			var rect := Rect2(Vector2(CELLS_X + float(i) * CELL_STEP, ROWS_Y + float(row) * ROW_STEP), CELL_SIZE)
			cells.append({ "kind": Kind.PIECE, "rect": rect, "slot": slot, "item": items[i] })
	cells.append({ "kind": Kind.BACK, "rect": BACK_BUTTON })


func _model_cell(model: String) -> int:
	for i in cells.size():
		if cells[i]["kind"] == Kind.MODEL and cells[i]["model"] == model:
			return i
	return 0


## The cell showing a piece, for tests.
func cell_of_item(id: String) -> int:
	for i in cells.size():
		if cells[i]["kind"] == Kind.PIECE and cells[i]["item"]["id"] == id:
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _cell_at(event.position)
		if hovered >= 0 and hovered != cursor:
			_move_to(hovered)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var over: int = _cell_at(event.position)
			if over >= 0:
				cursor = over
				_activate()
		return
	if event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		done.emit()
		return
	if event.is_action_pressed("swing", false):
		get_viewport().set_input_as_handled()
		_activate()
		return
	var step: Vector2i = _menu_input.step(event)
	if step != Vector2i.ZERO:
		var next: int = _cell_in_direction(step)
		if next >= 0:
			_move_to(next)
		get_viewport().set_input_as_handled()


func _cell_at(at: Vector2) -> int:
	for i in cells.size():
		if (cells[i]["rect"] as Rect2).has_point(at):
			return i
	return -1


func _move_to(index: int) -> void:
	cursor = index
	Sound.sfx("menu_move")
	_try_on()


# The nearest cell that way. Going sideways stays on the row, and going up or down wraps round.
func _cell_in_direction(step: Vector2i) -> int:
	var from: Vector2 = (cells[cursor]["rect"] as Rect2).get_center()
	var best: int = -1
	var best_score: float = INF
	for i in cells.size():
		if i == cursor:
			continue
		var score: float = _direction_score(from, (cells[i]["rect"] as Rect2).get_center(), step)
		if score < best_score:
			best_score = score
			best = i
	if best >= 0 or step.y == 0:
		return best
	# Nothing further that way, so go round to the far end.
	var wrapped := Vector2(from.x, from.y - float(step.y) * 1000.0)
	for i in cells.size():
		var score: float = _direction_score(wrapped, (cells[i]["rect"] as Rect2).get_center(), step)
		if score < best_score:
			best_score = score
			best = i
	return best


func _direction_score(from: Vector2, to: Vector2, step: Vector2i) -> float:
	var gap: Vector2 = to - from
	if step.x != 0:
		if signf(gap.x) != float(step.x) or absf(gap.y) > ROW_STEP / 2.0:
			return INF
		return absf(gap.x)
	if signf(gap.y) != float(step.y) or absf(gap.y) < 2.0:
		return INF
	return absf(gap.y) * 4.0 + absf(gap.x)


func _activate() -> void:
	var cell: Dictionary = cells[cursor]
	match cell["kind"]:
		Kind.MODEL:
			profile.set_model(str(cell["model"]))
			_build_cells()
			cursor = _model_cell(profile.model)
			Sound.sfx("menu_ok")
		Kind.PIECE:
			_buy_or_wear(cell["item"])
		Kind.BACK:
			done.emit()
			return
	_try_on()


func _buy_or_wear(item: Dictionary) -> void:
	var id: String = str(item["id"])
	var had_it: bool = profile.owns_clothes(id)
	if not profile.is_unlocked(item) or not profile.buy_clothes(id):
		Sound.sfx("denied")
		return
	profile.wear_clothes(profile.model, str(item["slot"]), id)
	Sound.sfx("menu_ok" if had_it else "buy")


# Shows what's worn, with whatever the cursor is over swapped in. Locked colors stay hidden.
func _try_on() -> void:
	var cell: Dictionary = cells[cursor]
	var model: String = str(cell.get("model", profile.model))
	var pieces: Dictionary = profile.worn_pieces(model)
	if cell["kind"] == Kind.PIECE and profile.is_unlocked(cell["item"]):
		pieces[cell["slot"]] = cell["item"]
	_golfer.wear(model, pieces)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_shadowed(self, "APPEARANCE", Vector2(20, 14), ACCENT, 3)
	var coins: String = "COINS %d" % profile.wallet
	PixelFont.draw_shadowed(self, coins, Vector2(620.0 - float(PixelFont.text_width(coins, 2)), 18.0), COIN, 2)

	draw_rect(PREVIEW_PANEL, PANEL)
	draw_rect(PREVIEW_PANEL, Color(1, 1, 1, 0.15), false, 1.0)
	draw_rect(Rect2(PREVIEW_PANEL.position.x + 1.0, PREVIEW_GROUND, PREVIEW_PANEL.size.x - 2.0, 4.0), Color("7cc24e"))
	draw_rect(Rect2(PREVIEW_PANEL.position.x + 1.0, PREVIEW_GROUND + 4.0, PREVIEW_PANEL.size.x - 2.0, PREVIEW_PANEL.end.y - PREVIEW_GROUND - 5.0), Color("6b4a32"))

	PixelFont.draw(self, "GOLFER", Vector2(LABEL_X, MODEL_Y + 7.0), TEXT)
	for row in Wardrobe.SLOTS.size():
		var slot: String = Wardrobe.SLOTS[row]
		PixelFont.draw(self, str(Wardrobe.SLOT_NAMES[profile.model][slot]), Vector2(LABEL_X, ROWS_Y + float(row) * ROW_STEP + 9.0), TEXT)
	for i in cells.size():
		_draw_cell(cells[i], i == cursor)
	PixelFont.draw_centered(self, _info_line(), 423.0, INFO_Y, ACCENT)
	PixelFont.draw_centered(self, "ARROWS OR MOUSE TO PICK   SPACE TO BUY OR WEAR   ESC TO GO BACK", 370.0, 338.0, DIM)


func _draw_cell(cell: Dictionary, selected: bool) -> void:
	var rect: Rect2 = cell["rect"]
	match cell["kind"]:
		Kind.MODEL:
			var on: bool = cell["model"] == profile.model
			_draw_button(rect, str(MODEL_NAMES[cell["model"]]), selected, GOOD if on else TEXT)
		Kind.PIECE:
			if profile.is_unlocked(cell["item"]):
				draw_rect(rect, cell["item"]["main"])
				_draw_marks(rect, cell)
			else:
				_draw_lock(rect)
			draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
			if selected:
				draw_rect(rect.grow(1.0), ACCENT, false, 2.0)
		Kind.BACK:
			_draw_button(rect, "< BACK", selected, TEXT)


func _draw_button(rect: Rect2, label: String, selected: bool, color: Color) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, ACCENT if selected else DIM, false, 1.0)
	PixelFont.draw_centered(self, label, rect.get_center().x, rect.position.y + (rect.size.y - float(PixelFont.HEIGHT)) / 2.0, ACCENT if selected else color)


# A padlock in place of a color that hasn't been earned yet.
func _draw_lock(rect: Rect2) -> void:
	draw_rect(rect, LOCKED)
	var center: Vector2 = rect.get_center().round()
	draw_rect(Rect2(center + Vector2(-4, -8), Vector2(8, 2)), DIM)
	draw_rect(Rect2(center + Vector2(-4, -7), Vector2(2, 5)), DIM)
	draw_rect(Rect2(center + Vector2(2, -7), Vector2(2, 5)), DIM)
	draw_rect(Rect2(center + Vector2(-6, -3), Vector2(12, 10)), DIM)
	draw_rect(Rect2(center + Vector2(-1, 0), Vector2(2, 4)), LOCKED)


# A green corner for what's on, and a coin for what's still to buy.
func _draw_marks(rect: Rect2, cell: Dictionary) -> void:
	var id: String = str(cell["item"]["id"])
	if profile.clothes[profile.model][cell["slot"]] == id:
		draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(7, 7)), OUTLINE)
		draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(5, 5)), GOOD)
	elif not profile.owns_clothes(id):
		var corner := Vector2(rect.end.x - 8.0, rect.position.y + 1.0)
		draw_rect(Rect2(corner, Vector2(7, 7)), OUTLINE)
		draw_rect(Rect2(corner + Vector2(1, 1), Vector2(5, 5)), COIN)


# What the cursor is on, and what picking it would do.
func _info_line() -> String:
	var cell: Dictionary = cells[cursor]
	match cell["kind"]:
		Kind.PIECE:
			var item: Dictionary = cell["item"]
			var id: String = str(item["id"])
			if not profile.is_unlocked(item):
				return "LOCKED: %s" % Wardrobe.UNLOCK_TEXT[item["unlock"]]
			if profile.clothes[profile.model][cell["slot"]] == id:
				return "%s: WEARING" % item["name"]
			if profile.owns_clothes(id):
				return "%s: OWNED" % item["name"]
			if profile.wallet < int(item["price"]):
				return "%s: %d COINS, NOT ENOUGH YET" % [item["name"], item["price"]]
			return "%s: %d COINS" % [item["name"], item["price"]]
		Kind.MODEL:
			return "LEFTOVER COINS FROM EACH RUN ARE SAVED FOR CLOTHES"
	return ""
