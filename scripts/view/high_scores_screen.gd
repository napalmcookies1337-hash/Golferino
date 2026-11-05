class_name HighScoresScreen
extends Node2D
## The best runs so far, from the title menu, with a page for each mode.

signal done

enum Page { MAIN, INFINITE, ISLES }

const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const TEXT := Color("f7f4e6")
const DIM := Color("7f8a96")
const ACCENT := Color("ffe25a")
const ENDINGS := {
	RunState.Ending.NONE: "COURSE COMPLETE",
	RunState.Ending.BEAT_RIVAL: "BEAT THE RIVAL",
	RunState.Ending.LOST_TO_RIVAL: "LOST TO THE RIVAL",
	RunState.Ending.OUT_OF_STROKES: "OUT OF STROKES",
	RunState.Ending.GAVE_UP: "RUN ENDED",
}
const ISLES_COLUMN_WIDTH := 180.0
const TABS := {
	Page.MAIN: { "label": "MAIN GAME", "rect": Rect2(136, 48, 116, 16) },
	Page.INFINITE: { "label": "INFINITE", "rect": Rect2(262, 48, 116, 16) },
	Page.ISLES: { "label": "FLOATING ISLES", "rect": Rect2(388, 48, 116, 16) },
}

var profile: Profile
var page: int = Page.MAIN

var _menu_input := MenuInput.new()


func setup(p_profile: Profile) -> void:
	profile = p_profile


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swing", false) or event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		done.emit()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)
	elif not event is InputEventMouseMotion:
		var step: Vector2i = _menu_input.step(event)
		if step.x != 0:
			_show_page(posmod(page + step.x, TABS.size()))
			get_viewport().set_input_as_handled()


# A tab shows its page, and a click anywhere else goes back.
func _click(at: Vector2) -> void:
	for tab: int in TABS:
		if (TABS[tab]["rect"] as Rect2).has_point(at):
			_show_page(tab)
			return
	done.emit()


func _show_page(next: int) -> void:
	if next != page:
		page = next
		Sound.sfx("menu_move")
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_centered(self, "HIGH SCORES", 320.0, 16.0, ACCENT, 3)
	for tab: int in TABS:
		_draw_tab(tab)
	match page:
		Page.MAIN:
			_draw_main_table()
		Page.INFINITE:
			_draw_infinite_table()
		Page.ISLES:
			_draw_isles_table()
	var total: int = Items.unlock_order().size()
	PixelFont.draw_centered(self, "RUNS FINISHED %d    SHOP UNLOCKS %d OF %d" % [profile.runs_finished, profile.unlocked.size(), total], 320.0, 306.0, TEXT)
	PixelFont.draw_centered(self, "LEFT/RIGHT TO SWITCH   SPACE TO GO BACK", 320.0, 340.0, DIM)


func _draw_tab(tab: int) -> void:
	var rect: Rect2 = TABS[tab]["rect"]
	var is_open: bool = tab == page
	draw_rect(rect, PANEL if is_open else BACKGROUND)
	draw_rect(rect, ACCENT if is_open else DIM, false, 1.0)
	PixelFont.draw_centered(self, str(TABS[tab]["label"]), rect.get_center().x, rect.position.y + 5.0, ACCENT if is_open else DIM)


func _draw_main_table() -> void:
	if profile.high_scores.is_empty():
		PixelFont.draw_centered(self, "NO RUNS YET", 320.0, 160.0, DIM, 2)
		return
	PixelFont.draw(self, "SCORE", Vector2(170, 74), DIM)
	PixelFont.draw(self, "PAR", Vector2(226, 74), DIM)
	PixelFont.draw(self, "HOW IT ENDED", Vector2(274, 74), DIM)
	var y: float = 86.0
	for i in profile.high_scores.size():
		var entry: Dictionary = profile.high_scores[i]
		var color: Color = _row_color(i)
		_draw_rank_and_score(i, entry, y, color)
		PixelFont.draw(self, CourseRun.to_par_text(int(entry["to_par"])), Vector2(226, y), color)
		PixelFont.draw(self, str(ENDINGS.get(int(entry["ending"]), "")), Vector2(274, y), DIM)
		y += 21.0


func _draw_infinite_table() -> void:
	if profile.infinite_scores.is_empty():
		var hint: String = "NO RUNS YET" if profile.rival_beaten else "BEAT THE RIVAL ONCE TO OPEN INFINITE MODE"
		PixelFont.draw_centered(self, hint, 320.0, 160.0, DIM, 2 if profile.rival_beaten else 1)
		return
	PixelFont.draw(self, "SCORE", Vector2(170, 74), DIM)
	PixelFont.draw(self, "SET", Vector2(226, 74), DIM)
	PixelFont.draw(self, "BOSSES", Vector2(256, 74), DIM)
	PixelFont.draw(self, "HOW IT ENDED", Vector2(310, 74), DIM)
	var y: float = 86.0
	for i in profile.infinite_scores.size():
		var entry: Dictionary = profile.infinite_scores[i]
		var color: Color = _row_color(i)
		_draw_rank_and_score(i, entry, y, color)
		PixelFont.draw(self, str(int(entry["sets"])), Vector2(226, y), color)
		PixelFont.draw(self, str(int(entry["bosses"])), Vector2(256, y), color)
		PixelFont.draw(self, str(ENDINGS.get(int(entry["ending"]), "")), Vector2(310, y), DIM)
		y += 21.0


# A leaderboard per length of course, side by side. Fewest strokes at the top, since this one's
# golf rather than a run's points.
func _draw_isles_table() -> void:
	var courses: Array[int] = IslesGenerator.COURSE_YARDS
	for c in courses.size():
		var left: float = 60.0 + float(c) * ISLES_COLUMN_WIDTH
		var table: Array = profile.isles_table(courses[c])
		PixelFont.draw_centered(self, "%d YD" % courses[c], left + 72.0, 74.0, ACCENT)
		if table.is_empty():
			PixelFont.draw_centered(self, "NOT CROSSED YET", left + 72.0, 150.0, DIM)
			continue
		PixelFont.draw(self, "STROKES", Vector2(left + 26.0, 86.0), DIM)
		PixelFont.draw(self, "FALLS", Vector2(left + 96.0, 86.0), DIM)
		var y: float = 98.0
		for i in table.size():
			var entry: Dictionary = table[i]
			var color: Color = _row_color(i)
			PixelFont.draw(self, "%2d" % (i + 1), Vector2(left, y), color)
			PixelFont.draw(self, str(int(entry["strokes"])), Vector2(left + 26.0, y), color)
			PixelFont.draw(self, str(int(entry["falls"])), Vector2(left + 96.0, y), DIM)
			y += 20.0


func _row_color(index: int) -> Color:
	return ACCENT if index == 0 else TEXT


func _draw_rank_and_score(index: int, entry: Dictionary, y: float, color: Color) -> void:
	PixelFont.draw(self, "%2d" % (index + 1), Vector2(110, y), color)
	var points: String = str(int(entry["score"]))
	PixelFont.draw(self, points, Vector2(200.0 - float(PixelFont.text_width(points)), y), color)
