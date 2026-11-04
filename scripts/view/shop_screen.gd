class_name ShopScreen
extends Node2D
## The pro shop between holes. All buying goes through RunState, and this only draws it
## and takes the player's choices. Works with keyboard, controller and mouse.

signal done

enum Mode { BROWSE, PICK_CLUB, PICK_SLOT }

const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const EDGE := Color("f2ead0")
const TEXT := Color("f7f4e6")
const DIM := Color("7f8a96")
const ACCENT := Color("ffe25a")
const BAD := Color("ff8a70")
const KIND_COLORS := {
	Items.KIND_STICKER: Color("6fd0ff"),
	Items.KIND_BALL: Color("f7f4e6"),
	Items.KIND_PERK: Color("c48cff"),
	Items.KIND_STROKES: Color("6fe07a"),
}
const CARDS_LEFT := 22.0
const CARDS_WIDTH := 596.0
const CARDS_TOP := 34.0
const CARD_HEIGHT := 100.0
const CARD_GAP := 8.0
const LEAVE_BUTTON := Rect2(250, 140, 140, 18)
const BAG_LEFT := 22.0
const BAG_TOP := 186.0
const BAG_ROW_HEIGHT := 22.0
const BAG_LABEL_WIDTH := 56.0
const SLOT_WIDTH := 176.0
const SLOT_HEIGHT := 18.0
const CHARS_PER_LINE := 96

var run: RunState
var stock: Array[Dictionary] = []
var sold: Dictionary = {}
var mode: int = Mode.BROWSE
## The selected card. One past the last card is the button to leave.
var cursor: int = 0
var club_cursor: int = 0
var slot_cursor: int = 0
var show_card: bool = false

var _menu_input := MenuInput.new()
var _next_hole_text: String = ""


func setup(p_run: RunState) -> void:
	run = p_run
	stock = run.roll_stock()
	var next_index: int = run.course.hole_index + 1
	if next_index < run.course.hole_count():
		var next: HoleData = run.course.hole_at(next_index)
		_next_hole_text = "NEXT: %s  PAR %d" % [next.display_name, next.par]


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover(event.position)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hover(event.position)
			if _is_over_choice(event.position):
				_confirm()
		return
	if event.is_action_pressed("scorecard", false):
		show_card = not show_card
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("swing", false):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quit", false) and mode != Mode.BROWSE:
		_cancel()
		get_viewport().set_input_as_handled()
		return
	var step: Vector2i = _menu_input.step(event)
	if step != Vector2i.ZERO:
		_move(step)
		get_viewport().set_input_as_handled()


func _move(step: Vector2i) -> void:
	match mode:
		Mode.BROWSE:
			if step.x != 0:
				cursor = posmod(cursor + step.x, stock.size() + 1)
			elif step.y > 0:
				cursor = stock.size()
			elif step.y < 0 and cursor == stock.size():
				cursor = 0
		Mode.PICK_CLUB:
			if step.y != 0:
				_step_club(step.y)
		Mode.PICK_SLOT:
			if step.x != 0:
				slot_cursor = posmod(slot_cursor + step.x, RunState.STICKERS_PER_CLUB)


# Skips clubs this sticker doesn't fit.
func _step_club(direction: int) -> void:
	var clubs: Array = _selected_item()["clubs"]
	for _i in Items.ALL_CLUBS.size():
		club_cursor = posmod(club_cursor + direction, Items.ALL_CLUBS.size())
		if clubs.has(Items.ALL_CLUBS[club_cursor]):
			return


func _confirm() -> void:
	match mode:
		Mode.BROWSE:
			if cursor >= stock.size():
				done.emit()
			else:
				_try_buy()
		Mode.PICK_CLUB:
			var club_id: String = Items.ALL_CLUBS[club_cursor]
			if run.club_is_full(club_id):
				slot_cursor = 0
				mode = Mode.PICK_SLOT
			else:
				_finish_sticker(club_id, -1)
		Mode.PICK_SLOT:
			_finish_sticker(Items.ALL_CLUBS[club_cursor], slot_cursor)


func _cancel() -> void:
	mode = Mode.PICK_CLUB if mode == Mode.PICK_SLOT else Mode.BROWSE


func _try_buy() -> void:
	var item: Dictionary = stock[cursor]
	if sold.has(cursor) or not run.can_afford(item):
		return
	if item["kind"] == Items.KIND_STICKER:
		club_cursor = Items.ALL_CLUBS.find((item["clubs"] as Array)[0])
		mode = Mode.PICK_CLUB
	elif run.buy(item):
		sold[cursor] = true


func _finish_sticker(club_id: String, slot: int) -> void:
	if run.buy_sticker(_selected_item(), club_id, slot):
		sold[cursor] = true
	mode = Mode.BROWSE


func _selected_item() -> Dictionary:
	return stock[cursor] if cursor < stock.size() else {}


func _card_rect(index: int) -> Rect2:
	var count: float = float(stock.size())
	var width: float = (CARDS_WIDTH - CARD_GAP * (count - 1.0)) / count
	return Rect2(CARDS_LEFT + float(index) * (width + CARD_GAP), CARDS_TOP, width, CARD_HEIGHT)


func _slot_rect(row: int, slot: int) -> Rect2:
	var x: float = BAG_LEFT + BAG_LABEL_WIDTH + float(slot) * (SLOT_WIDTH + 4.0)
	return Rect2(x, BAG_TOP + 5.0 + float(row) * BAG_ROW_HEIGHT, SLOT_WIDTH, SLOT_HEIGHT)


func _hover(at: Vector2) -> void:
	match mode:
		Mode.BROWSE:
			for i in stock.size():
				if _card_rect(i).has_point(at):
					cursor = i
			if LEAVE_BUTTON.has_point(at):
				cursor = stock.size()
		Mode.PICK_CLUB:
			for row in Items.ALL_CLUBS.size():
				if (_selected_item()["clubs"] as Array).has(Items.ALL_CLUBS[row]) and _row_rect(row).has_point(at):
					club_cursor = row
		Mode.PICK_SLOT:
			for slot in RunState.STICKERS_PER_CLUB:
				if _slot_rect(club_cursor, slot).has_point(at):
					slot_cursor = slot


func _row_rect(row: int) -> Rect2:
	return Rect2(BAG_LEFT, BAG_TOP + 4.0 + float(row) * BAG_ROW_HEIGHT, CARDS_WIDTH, BAG_ROW_HEIGHT)


func _is_over_choice(at: Vector2) -> bool:
	match mode:
		Mode.BROWSE:
			if LEAVE_BUTTON.has_point(at):
				return true
			for i in stock.size():
				if _card_rect(i).has_point(at):
					return true
		Mode.PICK_CLUB:
			return _row_rect(club_cursor).has_point(at)
		Mode.PICK_SLOT:
			return _slot_rect(club_cursor, slot_cursor).has_point(at)
	return false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_shadowed(self, "PRO SHOP", Vector2(22, 10), ACCENT, 2)
	PixelFont.draw(self, "COINS %d" % run.coins, Vector2(150, 15), ACCENT)
	var spare_color: Color = BAD if run.spare <= 1 else TEXT
	PixelFont.draw(self, "SPARE STROKES %d" % run.spare, Vector2(222, 15), spare_color)
	var right_x: float = 618.0 - float(PixelFont.text_width(_next_hole_text))
	PixelFont.draw(self, _next_hole_text, Vector2(right_x, 15), DIM)
	for i in stock.size():
		_draw_card(i)
	_draw_leave_button()
	_draw_bag()
	_draw_owned()
	_draw_prompt()
	if show_card:
		draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.6))
		ScorecardView.draw_table(self, run.course, Vector2(18, 150))


func _draw_card(index: int) -> void:
	var item: Dictionary = stock[index]
	var rect: Rect2 = _card_rect(index)
	var is_selected: bool = mode == Mode.BROWSE and cursor == index
	var is_sold: bool = sold.has(index)
	draw_rect(rect, PANEL)
	draw_rect(rect, ACCENT if is_selected else DIM, false, 1.0)
	var center: float = rect.get_center().x
	var color: Color = KIND_COLORS[item["kind"]]
	if is_sold:
		color = DIM
	_draw_icon(str(item["kind"]), Vector2(center, rect.position.y + 13.0), color)
	var label: String = str(item["kind"]).to_upper()
	PixelFont.draw_centered(self, label, center, rect.position.y + 24.0, color)
	PixelFont.draw_centered(self, str(item["name"]), center, rect.position.y + 37.0, DIM if is_sold else TEXT)
	var lines: Array[String] = _wrap(str(item["text"]), int((rect.size.x - 6.0) / float(PixelFont.WIDTH)))
	for i in lines.size():
		PixelFont.draw_centered(self, lines[i], center, rect.position.y + 50.0 + float(i) * 10.0, DIM)
	if is_sold:
		PixelFont.draw_centered(self, "SOLD", center, rect.position.y + 85.0, DIM)
	else:
		var price: int = run.price_of(item)
		PixelFont.draw_centered(self, "%d COINS" % price, center, rect.position.y + 85.0, ACCENT if run.coins >= price else BAD)


func _draw_icon(kind: String, at: Vector2, color: Color) -> void:
	match kind:
		Items.KIND_STICKER:
			draw_rect(Rect2(at.x - 5.0, at.y - 5.0, 10, 10), color)
			draw_rect(Rect2(at.x + 2.0, at.y - 5.0, 3, 3), PANEL)
		Items.KIND_BALL:
			draw_circle(at, 5.0, color)
			draw_rect(Rect2(at.x + 1.0, at.y + 1.0, 2, 1), Color("9aa4b4"))
		Items.KIND_PERK:
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), color)
		_:
			draw_rect(Rect2(at.x - 1.0, at.y - 5.0, 2, 10), color)
			draw_rect(Rect2(at.x - 5.0, at.y - 1.0, 10, 2), color)


func _draw_leave_button() -> void:
	var is_selected: bool = mode == Mode.BROWSE and cursor >= stock.size()
	draw_rect(LEAVE_BUTTON, PANEL)
	draw_rect(LEAVE_BUTTON, ACCENT if is_selected else DIM, false, 1.0)
	var label: String = "TO THE DUEL >" if run.course.hole_index + 2 >= run.course.hole_count() else "NEXT HOLE >"
	PixelFont.draw_centered(self, label, LEAVE_BUTTON.get_center().x, LEAVE_BUTTON.position.y + 6.0, ACCENT if is_selected else TEXT)


func _draw_bag() -> void:
	var clubs: Array[String] = ["DRIVER", "IRON", "PUTTER"]
	var panel := Rect2(BAG_LEFT, BAG_TOP, CARDS_WIDTH, BAG_ROW_HEIGHT * 3.0 + 6.0)
	draw_rect(panel, PANEL)
	draw_rect(panel, DIM, false, 1.0)
	for row in clubs.size():
		var club_id: String = Items.ALL_CLUBS[row]
		var fits: bool = mode == Mode.BROWSE or (_selected_item().get("clubs", []) as Array).has(club_id)
		var row_selected: bool = mode != Mode.BROWSE and club_cursor == row
		var label_color: Color = ACCENT if row_selected else (TEXT if fits else DIM)
		PixelFont.draw(self, clubs[row], Vector2(BAG_LEFT + 6.0, BAG_TOP + 10.0 + float(row) * BAG_ROW_HEIGHT), label_color)
		var on_club: Array = run.stickers[club_id]
		for slot in RunState.STICKERS_PER_CLUB:
			var rect: Rect2 = _slot_rect(row, slot)
			var slot_selected: bool = mode == Mode.PICK_SLOT and row_selected and slot_cursor == slot
			var edge: Color = BAD if slot_selected else (ACCENT if row_selected else Color(1, 1, 1, 0.15))
			draw_rect(rect, edge, false, 1.0)
			var name_text: String = "-"
			if slot < on_club.size():
				name_text = str(Items.by_id(str(on_club[slot]))["name"])
			var text_color: Color = KIND_COLORS[Items.KIND_STICKER] if slot < on_club.size() else DIM
			PixelFont.draw(self, name_text, rect.position + Vector2(5, 6), text_color)


func _draw_owned() -> void:
	var y: float = BAG_TOP + BAG_ROW_HEIGHT * 3.0 + 12.0
	var ball_name: String = "PLAIN" if run.ball_id == "" else str(Items.by_id(run.ball_id)["name"])
	PixelFont.draw(self, "BALL: %s" % ball_name, Vector2(BAG_LEFT, y), TEXT)
	var perk_names: Array[String] = []
	for id in run.perks:
		perk_names.append(str(Items.by_id(id)["name"]))
	var perk_text: String = "PERKS: %s" % (", ".join(perk_names) if not perk_names.is_empty() else "NONE")
	var lines: Array[String] = _wrap(perk_text, CHARS_PER_LINE)
	for i in lines.size():
		PixelFont.draw(self, lines[i], Vector2(BAG_LEFT, y + 12.0 + float(i) * 10.0), TEXT)


func _draw_prompt() -> void:
	var text: String = "LEFT/RIGHT TO BROWSE   SPACE TO BUY   DOWN FOR THE NEXT HOLE   TAB SCORECARD"
	match mode:
		Mode.BROWSE:
			var item: Dictionary = _selected_item()
			if not item.is_empty() and not sold.has(cursor):
				if not run.can_afford(item):
					PixelFont.draw_centered(self, "NOT ENOUGH COINS", 320.0, 330.0, BAD)
				elif item["kind"] == Items.KIND_BALL and run.ball_id != "":
					PixelFont.draw_centered(self, "REPLACES YOUR %s" % str(Items.by_id(run.ball_id)["name"]), 320.0, 330.0, ACCENT)
		Mode.PICK_CLUB:
			text = "UP/DOWN TO PICK   SPACE TO PUT IT ON   ESC TO CANCEL"
			PixelFont.draw_centered(self, "WHICH CLUB GETS %s?" % str(_selected_item()["name"]), 320.0, 330.0, ACCENT)
		Mode.PICK_SLOT:
			text = "LEFT/RIGHT TO PICK   SPACE TO REPLACE   ESC TO GO BACK"
			PixelFont.draw_centered(self, "THAT CLUB IS FULL: THE ONE YOU REPLACE IS LOST", 320.0, 330.0, BAD)
	PixelFont.draw_centered(self, text, 320.0, 346.0, DIM)


func _wrap(text: String, width: int) -> Array[String]:
	var lines: Array[String] = []
	var line: String = ""
	for word in text.split(" "):
		var joined: String = word if line == "" else "%s %s" % [line, word]
		if joined.length() > width and line != "":
			lines.append(line)
			line = word
		else:
			line = joined
	if line != "":
		lines.append(line)
	return lines
