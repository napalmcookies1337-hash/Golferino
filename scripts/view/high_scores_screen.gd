class_name HighScoresScreen
extends Node2D
## The best runs so far, from the title menu.

signal done

const BACKGROUND := Color("13303a")
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

var profile: Profile


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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		done.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	PixelFont.draw_centered(self, "HIGH SCORES", 320.0, 24.0, ACCENT, 3)
	if profile.high_scores.is_empty():
		PixelFont.draw_centered(self, "NO RUNS YET", 320.0, 150.0, DIM, 2)
	else:
		PixelFont.draw(self, "SCORE", Vector2(170, 62), DIM)
		PixelFont.draw(self, "PAR", Vector2(226, 62), DIM)
		PixelFont.draw(self, "HOW IT ENDED", Vector2(274, 62), DIM)
	var y: float = 74.0
	for i in profile.high_scores.size():
		var entry: Dictionary = profile.high_scores[i]
		var color: Color = ACCENT if i == 0 else TEXT
		PixelFont.draw(self, "%2d" % (i + 1), Vector2(110, y), color)
		var points: String = str(int(entry["score"]))
		PixelFont.draw(self, points, Vector2(200.0 - float(PixelFont.text_width(points)), y), color)
		PixelFont.draw(self, CourseRun.to_par_text(int(entry["to_par"])), Vector2(226, y), color)
		PixelFont.draw(self, str(ENDINGS.get(int(entry["ending"]), "")), Vector2(274, y), DIM)
		y += 20.0
	var total: int = Items.unlock_order().size()
	PixelFont.draw_centered(self, "RUNS FINISHED %d    SHOP UNLOCKS %d OF %d" % [profile.runs_finished, profile.unlocked.size(), total], 320.0, 300.0, TEXT)
	PixelFont.draw_centered(self, "SPACE TO GO BACK", 320.0, 340.0, DIM)
