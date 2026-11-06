class_name ShopScreen
extends Node2D
## The pro shop between holes. All buying goes through RunState, and this only draws it
## and takes the player's choices. Works with keyboard, controller and mouse.

signal done

enum Mode { BROWSE, PICK_CLUB, PICK_SLOT, BALLS, REPLACE_BALL }

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
const REROLL_BUTTON := Rect2(398, 140, 140, 18)
const BAG_LEFT := 22.0
const BAG_TOP := 186.0
const BAG_ROW_HEIGHT := 22.0
const BAG_LABEL_WIDTH := 56.0
const SLOT_WIDTH := 176.0
const SLOT_HEIGHT := 18.0
const BALLS_TOP := 262.0
const BALLS_HEIGHT := 26.0
const CHARS_PER_LINE := 96
const IN_PLAY := Color("6fe07a")
const AWNING_STRIPE := 32.0
const AWNING_RED := Color("c84a44")
const AWNING_CREAM := Color("f2ead0")
const BUY_FLASH_TIME := 0.3

var run: RunState
var stock: Array[Dictionary] = []
var sold: Dictionary = {}
var mode: int = Mode.BROWSE
## The selected card. One past the last card is the button to leave, then the reroll button.
var cursor: int = 0
var club_cursor: int = 0
var slot_cursor: int = 0
var ball_cursor: int = 0
var show_card: bool = false

var _menu_input := MenuInput.new()
var _next_hole_text: String = ""
var _fx: FxView
var _time: float = 0.0
var _flashes: Dictionary = {}


func setup(p_run: RunState) -> void:
	run = p_run
	run.begin_shop()
	stock = run.roll_stock()
	var next_index: int = run.course.hole_index + 1
	if next_index < run.course.hole_count():
		var next: HoleData = run.course.hole_at(next_index)
		_next_hole_text = "NEXT: %s  PAR %d" % [next.display_name, next.par]
	else:
		var biome_name: String = "SWAMPY SHORES" if HoleGenerator.biome_for_set(run.set_number) == HoleData.BIOME_SWAMP else "GRASSY GREENS"
		_next_hole_text = "NEXT: SET %d, %s" % [run.set_number, biome_name] if run.infinite else "NEXT: %s" % biome_name


func _ready() -> void:
	_fx = FxView.new()
	add_child(_fx)


func _process(delta: float) -> void:
	_time += delta
	for index: int in _flashes.keys():
		_flashes[index] = float(_flashes[index]) - delta
		if float(_flashes[index]) <= 0.0:
			_flashes.erase(index)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var before: Array = _selection()
		_hover(event.position)
		if _selection() != before:
			Sound.sfx("menu_move")
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hover(event.position)
			if _is_over_choice(event.position):
				_confirm()
		return
	if event.is_action_pressed("scorecard", false):
		show_card = not show_card
		Sound.sfx("menu_move")
		get_viewport().set_input_as_handled()
		return
	if Controls.swing_pressed(event):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quit", false) and mode != Mode.BROWSE:
		_cancel()
		get_viewport().set_input_as_handled()
		return
	var step: Vector2i = _menu_input.step(event)
	if step != Vector2i.ZERO:
		var before: Array = _selection()
		_move(step)
		if _selection() != before:
			Sound.sfx("menu_move")
		get_viewport().set_input_as_handled()


# Everything that says what's selected, to tell when it has changed.
func _selection() -> Array:
	return [mode, cursor, club_cursor, slot_cursor, ball_cursor]


func _move(step: Vector2i) -> void:
	match mode:
		Mode.BROWSE:
			if step.x != 0:
				cursor = posmod(cursor + step.x, stock.size() + 2)
			elif step.y > 0 and cursor >= stock.size():
				ball_cursor = maxi(run.balls.find(run.ball_id), 0)
				mode = Mode.BALLS
			elif step.y > 0:
				cursor = stock.size()
			elif step.y < 0 and cursor >= stock.size():
				cursor = 0
		Mode.PICK_CLUB:
			if step.y != 0:
				_step_club(step.y)
		Mode.PICK_SLOT:
			if step.x != 0:
				slot_cursor = posmod(slot_cursor + step.x, RunState.STICKERS_PER_CLUB)
		Mode.BALLS:
			if step.x != 0:
				ball_cursor = posmod(ball_cursor + step.x, run.balls.size())
			elif step.y < 0:
				mode = Mode.BROWSE
		Mode.REPLACE_BALL:
			if step.x != 0:
				ball_cursor = posmod(ball_cursor + step.x, RunState.BALL_SLOTS)


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
			if cursor == stock.size():
				Sound.sfx("menu_ok")
				done.emit()
			elif cursor > stock.size():
				_try_reroll()
			else:
				_try_buy()
		Mode.PICK_CLUB:
			var club_id: String = Items.ALL_CLUBS[club_cursor]
			if run.stack_is_complete(club_id, _selected_item()):
				Sound.sfx("denied")
			elif run.must_replace_for(club_id, _selected_item()):
				slot_cursor = 0
				mode = Mode.PICK_SLOT
				Sound.sfx("menu_ok")
			else:
				_finish_sticker(club_id, -1)
		Mode.PICK_SLOT:
			_finish_sticker(Items.ALL_CLUBS[club_cursor], slot_cursor)
		Mode.BALLS:
			if ball_cursor < run.balls.size() and run.balls[ball_cursor] != run.ball_id:
				Sound.sfx("equip")
			run.equip_ball(ball_cursor)
		Mode.REPLACE_BALL:
			if run.buy(_selected_item(), ball_cursor):
				_mark_sold()
			mode = Mode.BROWSE


func _cancel() -> void:
	mode = Mode.PICK_CLUB if mode == Mode.PICK_SLOT else Mode.BROWSE
	Sound.sfx("menu_back")


func _try_buy() -> void:
	var item: Dictionary = stock[cursor]
	if sold.has(cursor) or not run.can_afford(item):
		Sound.sfx("denied")
		return
	if item["kind"] == Items.KIND_STICKER:
		club_cursor = Items.ALL_CLUBS.find((item["clubs"] as Array)[0])
		mode = Mode.PICK_CLUB
		Sound.sfx("menu_ok")
	elif item["kind"] == Items.KIND_BALL and run.balls_full():
		ball_cursor = 0
		mode = Mode.REPLACE_BALL
		Sound.sfx("menu_ok")
	elif run.buy(item):
		_mark_sold()


# New items on every shelf, so anything already bought from comes back in stock too. The
# selection stays on the button, ready for another go.
func _try_reroll() -> void:
	if not run.can_reroll():
		Sound.sfx("denied")
		return
	stock = run.reroll_stock(stock)
	sold.clear()
	_flashes.clear()
	cursor = stock.size() + 1
	Sound.sfx("buy")
	for i in stock.size():
		_flashes[i] = BUY_FLASH_TIME
	if _fx != null:
		_fx.burst(REROLL_BUTTON.get_center(), ACCENT, 14, 70.0)


func _finish_sticker(club_id: String, slot: int) -> void:
	if run.buy_sticker(_selected_item(), club_id, slot):
		_mark_sold()
	mode = Mode.BROWSE


func _mark_sold() -> void:
	sold[cursor] = true
	_flashes[cursor] = BUY_FLASH_TIME
	Sound.sfx("buy")
	if _fx != null:
		var rect: Rect2 = _card_rect(cursor)
		_fx.burst(rect.get_center(), ACCENT, 20, 90.0)
		_fx.float_text(rect.get_center(), "SOLD!", ACCENT)


func _selected_item() -> Dictionary:
	return stock[cursor] if cursor < stock.size() else {}


func _card_rect(index: int) -> Rect2:
	var count: float = float(stock.size())
	var width: float = (CARDS_WIDTH - CARD_GAP * (count - 1.0)) / count
	return Rect2(CARDS_LEFT + float(index) * (width + CARD_GAP), CARDS_TOP, width, CARD_HEIGHT)


func _slot_rect(row: int, slot: int) -> Rect2:
	var x: float = BAG_LEFT + BAG_LABEL_WIDTH + float(slot) * (SLOT_WIDTH + 4.0)
	return Rect2(x, BAG_TOP + 5.0 + float(row) * BAG_ROW_HEIGHT, SLOT_WIDTH, SLOT_HEIGHT)


func _ball_rect(slot: int) -> Rect2:
	var x: float = BAG_LEFT + BAG_LABEL_WIDTH + float(slot) * (SLOT_WIDTH + 4.0)
	return Rect2(x, BALLS_TOP + 4.0, SLOT_WIDTH, SLOT_HEIGHT)


func _hover(at: Vector2) -> void:
	match mode:
		Mode.BROWSE, Mode.BALLS:
			for i in stock.size():
				if _card_rect(i).has_point(at):
					cursor = i
					mode = Mode.BROWSE
			if LEAVE_BUTTON.has_point(at):
				cursor = stock.size()
				mode = Mode.BROWSE
			if REROLL_BUTTON.has_point(at):
				cursor = stock.size() + 1
				mode = Mode.BROWSE
			for slot in run.balls.size():
				if _ball_rect(slot).has_point(at):
					ball_cursor = slot
					mode = Mode.BALLS
		Mode.REPLACE_BALL:
			for slot in RunState.BALL_SLOTS:
				if _ball_rect(slot).has_point(at):
					ball_cursor = slot
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
			if LEAVE_BUTTON.has_point(at) or REROLL_BUTTON.has_point(at):
				return true
			for i in stock.size():
				if _card_rect(i).has_point(at):
					return true
		Mode.PICK_CLUB:
			return _row_rect(club_cursor).has_point(at)
		Mode.PICK_SLOT:
			return _slot_rect(club_cursor, slot_cursor).has_point(at)
		Mode.BALLS, Mode.REPLACE_BALL:
			return _ball_rect(ball_cursor).has_point(at)
	return false


func _draw() -> void:
	_draw_backdrop()
	PixelFont.draw_shadowed(self, "PRO SHOP", Vector2(22, 10), ACCENT, 2)
	PixelFont.draw(self, "COINS %d" % run.coins, Vector2(150, 15), ACCENT)
	var spare_color: Color = BAD if run.spare <= 1 else TEXT
	PixelFont.draw(self, "SPARE STROKES %d" % run.spare, Vector2(222, 15), spare_color)
	var right_x: float = 618.0 - float(PixelFont.text_width(_next_hole_text))
	PixelFont.draw(self, _next_hole_text, Vector2(right_x, 15), DIM)
	for i in stock.size():
		_draw_card(i)
	_draw_leave_button()
	_draw_reroll_button()
	_draw_bag()
	_draw_balls()
	_draw_perks()
	_draw_prompt()
	if show_card:
		draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.6))
		ScorecardView.draw_table(self, run.course, Vector2(18, 150))


# A paneled wall under a striped awning.
func _draw_backdrop() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	var plank_x: float = 0.0
	while plank_x < 640.0:
		draw_rect(Rect2(plank_x, 0, 1, 360), BACKGROUND.darkened(0.14))
		draw_rect(Rect2(plank_x + 1.0, 0, 1, 360), BACKGROUND.lightened(0.05))
		plank_x += AWNING_STRIPE * 2.0
	var stripe: int = 0
	var x: float = 0.0
	while x < 640.0:
		var color: Color = AWNING_RED if stripe % 2 == 0 else AWNING_CREAM
		draw_rect(Rect2(x, 0, AWNING_STRIPE, 5), color)
		draw_rect(Rect2(x + 2.0, 5, AWNING_STRIPE - 4.0, 2), color)
		x += AWNING_STRIPE
		stripe += 1


func _draw_card(index: int) -> void:
	var item: Dictionary = stock[index]
	var rect: Rect2 = _card_rect(index)
	var is_selected: bool = mode == Mode.BROWSE and cursor == index
	var is_sold: bool = sold.has(index)
	# The selected card lifts off the shelf a little and bobs.
	if is_selected and not is_sold:
		rect.position.y -= 2.0 + round(sin(_time * 5.0))
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(0, 0, 0, 0.3))
	draw_rect(rect, PANEL)
	draw_rect(rect, ACCENT if is_selected else DIM, false, 1.0)
	if _flashes.has(index):
		var flash: Color = Color.WHITE
		flash.a = float(_flashes[index]) / BUY_FLASH_TIME * 0.7
		draw_rect(rect, flash)
	var center: float = rect.get_center().x
	var color: Color = KIND_COLORS[item["kind"]]
	if is_sold:
		color = DIM
	ItemArt.draw(self, str(item["id"]), Vector2(center, rect.position.y + 20.0), 2, is_sold, DIM.darkened(0.45))
	var label: String = str(item["kind"]).to_upper()
	PixelFont.draw_centered(self, label, center, rect.position.y + 38.0, color)
	PixelFont.draw_centered(self, str(item["name"]), center, rect.position.y + 49.0, DIM if is_sold else TEXT)
	var lines: Array[String] = _wrap(str(item["text"]), int((rect.size.x - 6.0) / float(PixelFont.WIDTH)))
	for i in lines.size():
		PixelFont.draw_centered(self, lines[i], center, rect.position.y + 61.0 + float(i) * 10.0, DIM)
	if is_sold:
		PixelFont.draw_centered(self, "SOLD", center, rect.position.y + 85.0, DIM)
	else:
		var price: int = run.price_of(item)
		PixelFont.draw_centered(self, "%d COINS" % price, center, rect.position.y + 85.0, ACCENT if run.coins >= price else BAD)


func _draw_leave_button() -> void:
	var is_selected: bool = mode == Mode.BROWSE and cursor == stock.size()
	draw_rect(LEAVE_BUTTON, PANEL)
	draw_rect(LEAVE_BUTTON, ACCENT if is_selected else DIM, false, 1.0)
	var label: String = "NEXT HOLE >"
	if run.course.hole_index + 2 == run.course.hole_count():
		label = "TO THE DUEL >"
	elif run.course.is_last_hole():
		label = "NEXT SET >" if run.infinite else "TO THE SWAMP >"
	PixelFont.draw_centered(self, label, LEAVE_BUTTON.get_center().x, LEAVE_BUTTON.position.y + 6.0, ACCENT if is_selected else TEXT)


func _draw_reroll_button() -> void:
	var is_selected: bool = mode == Mode.BROWSE and cursor > stock.size()
	draw_rect(REROLL_BUTTON, PANEL)
	draw_rect(REROLL_BUTTON, ACCENT if is_selected else DIM, false, 1.0)
	var color: Color = BAD if not run.can_reroll() else (ACCENT if is_selected else TEXT)
	PixelFont.draw_centered(self, "REROLL: %d COINS" % run.reroll_price(), REROLL_BUTTON.get_center().x, REROLL_BUTTON.position.y + 6.0, color)


func _draw_bag() -> void:
	var clubs: Array[String] = ["DRIVER", "IRON", "PUTTER"]
	var panel := Rect2(BAG_LEFT, BAG_TOP, CARDS_WIDTH, BAG_ROW_HEIGHT * 3.0 + 6.0)
	draw_rect(panel, PANEL)
	draw_rect(panel, DIM, false, 1.0)
	var picking: bool = mode == Mode.PICK_CLUB or mode == Mode.PICK_SLOT
	for row in clubs.size():
		var club_id: String = Items.ALL_CLUBS[row]
		var fits: bool = not picking or (_selected_item().get("clubs", []) as Array).has(club_id)
		var row_selected: bool = picking and club_cursor == row
		var label_color: Color = ACCENT if row_selected else (TEXT if fits else DIM)
		PixelFont.draw(self, clubs[row], Vector2(BAG_LEFT + 6.0, BAG_TOP + 10.0 + float(row) * BAG_ROW_HEIGHT), label_color)
		var on_club: Array[Dictionary] = run.sticker_slots(club_id)
		for slot in RunState.STICKERS_PER_CLUB:
			var rect: Rect2 = _slot_rect(row, slot)
			var slot_selected: bool = mode == Mode.PICK_SLOT and row_selected and slot_cursor == slot
			var edge: Color = BAD if slot_selected else (ACCENT if row_selected else Color(1, 1, 1, 0.15))
			draw_rect(rect, edge, false, 1.0)
			var name_text: String = "-"
			if slot < on_club.size():
				name_text = str(Items.by_id(str(on_club[slot]["id"]))["name"])
				if int(on_club[slot]["count"]) > 1:
					name_text += " X%d" % int(on_club[slot]["count"])
			var text_color: Color = KIND_COLORS[Items.KIND_STICKER] if slot < on_club.size() else DIM
			PixelFont.draw(self, name_text, rect.position + Vector2(5, 6), text_color)


# The balls being carried. The one in play is marked, and only this screen can change it.
func _draw_balls() -> void:
	var panel := Rect2(BAG_LEFT, BALLS_TOP, CARDS_WIDTH, BALLS_HEIGHT)
	var choosing: bool = mode == Mode.BALLS or mode == Mode.REPLACE_BALL
	draw_rect(panel, PANEL)
	draw_rect(panel, DIM, false, 1.0)
	PixelFont.draw(self, "BALLS", Vector2(BAG_LEFT + 6.0, BALLS_TOP + 10.0), ACCENT if choosing else TEXT)
	for slot in RunState.BALL_SLOTS:
		var rect: Rect2 = _ball_rect(slot)
		var selected: bool = choosing and ball_cursor == slot
		var edge: Color = Color(1, 1, 1, 0.15)
		if selected:
			edge = BAD if mode == Mode.REPLACE_BALL else ACCENT
		draw_rect(rect, edge, false, 1.0)
		if slot >= run.balls.size():
			PixelFont.draw(self, "-", rect.position + Vector2(5, 6), DIM)
			continue
		var in_play: bool = run.balls[slot] == run.ball_id
		PixelFont.draw(self, _ball_name(run.balls[slot]), rect.position + Vector2(5, 6), IN_PLAY if in_play else TEXT)
		if in_play:
			var label_x: float = rect.end.x - 5.0 - float(PixelFont.text_width("IN PLAY"))
			PixelFont.draw(self, "IN PLAY", Vector2(label_x, rect.position.y + 6.0), IN_PLAY)


func _ball_name(id: String) -> String:
	return "PLAIN BALL" if id == "" else str(Items.by_id(id)["name"])


func _draw_perks() -> void:
	var y: float = BALLS_TOP + BALLS_HEIGHT + 6.0
	var perk_names: Array[String] = []
	for id in run.perks:
		perk_names.append(str(Items.by_id(id)["name"]))
	var perk_text: String = "PERKS: %s" % (", ".join(perk_names) if not perk_names.is_empty() else "NONE")
	var lines: Array[String] = _wrap(perk_text, CHARS_PER_LINE)
	for i in lines.size():
		PixelFont.draw(self, lines[i], Vector2(BAG_LEFT, y + float(i) * 10.0), TEXT)


func _draw_prompt() -> void:
	var text: String = "LEFT/RIGHT TO BROWSE   SPACE TO BUY   DOWN FOR THE NEXT HOLE   TAB SCORECARD"
	match mode:
		Mode.BROWSE:
			var item: Dictionary = _selected_item()
			if cursor > stock.size():
				text = "SPACE TO REROLL   DOWN TO SWAP BALLS   UP TO GO BACK   TAB SCORECARD"
				if run.can_reroll():
					PixelFont.draw_centered(self, "NEW ITEMS ON EVERY SHELF. THE PRICE DOUBLES EACH TIME", 320.0, 330.0, ACCENT)
				else:
					PixelFont.draw_centered(self, "NOT ENOUGH COINS", 320.0, 330.0, BAD)
			elif item.is_empty():
				text = "SPACE TO LEAVE   DOWN TO SWAP BALLS   UP TO GO BACK   TAB SCORECARD"
			elif not sold.has(cursor):
				if not run.can_afford(item):
					PixelFont.draw_centered(self, "NOT ENOUGH COINS", 320.0, 330.0, BAD)
				elif item["kind"] == Items.KIND_BALL and run.balls_full():
					PixelFont.draw_centered(self, "YOUR BALLS ARE FULL: YOU'LL REPLACE ONE", 320.0, 330.0, ACCENT)
		Mode.BALLS:
			text = "LEFT/RIGHT TO PICK   SPACE TO PLAY THIS BALL   UP TO GO BACK"
			var id: String = run.balls[ball_cursor]
			var about: String = "NO TRICKS, NO SURPRISES" if id == "" else str(Items.by_id(id)["text"])
			PixelFont.draw_centered(self, "%s: %s" % [_ball_name(id), about], 320.0, 330.0, ACCENT)
		Mode.REPLACE_BALL:
			text = "LEFT/RIGHT TO PICK   SPACE TO REPLACE   ESC TO CANCEL"
			PixelFont.draw_centered(self, "YOUR BALLS ARE FULL: THE ONE YOU REPLACE IS LOST", 320.0, 330.0, BAD)
		Mode.PICK_CLUB:
			text = "UP/DOWN TO PICK   SPACE TO PUT IT ON   ESC TO CANCEL"
			var club_id: String = Items.ALL_CLUBS[club_cursor]
			var on_club: int = run.sticker_count(club_id, _selected_item())
			var question: String = "WHICH CLUB GETS %s?" % str(_selected_item()["name"])
			if on_club >= RunState.MAX_STACK:
				PixelFont.draw_centered(self, "THAT CLUB ALREADY HAS %d OF THESE" % RunState.MAX_STACK, 320.0, 330.0, BAD)
			elif on_club > 0:
				PixelFont.draw_centered(self, "THAT MAKES %d, AND THEY STACK" % (on_club + 1), 320.0, 330.0, ACCENT)
			else:
				PixelFont.draw_centered(self, question, 320.0, 330.0, ACCENT)
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
