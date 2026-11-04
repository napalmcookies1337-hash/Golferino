class_name RunOverScreen
extends Node2D
## The end of a run: how it ended, the scorecard, the final score, and anything earned.

signal done

const BACKGROUND := Color("13303a")
const PANEL := Color("0d2029")
const TEXT := Color("f7f4e6")
const DIM := Color("7f8a96")
const ACCENT := Color("ffe25a")
const GOOD := Color("6fe07a")
const BAD := Color("ff8a70")
const INPUT_DELAY := 0.5

var run: RunState
var result: Dictionary = {}
var score: Dictionary = {}
## Strokes the rival finished on, or a negative number if the run never reached it.
var rival_strokes: int = -1

var _age: float = 0.0


func setup(p_run: RunState, p_result: Dictionary, p_rival_strokes: int) -> void:
	run = p_run
	result = p_result
	rival_strokes = p_rival_strokes
	score = run.final_score()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# A short wait, so a button mashed at the last moment doesn't skip the score.
	if _age < INPUT_DELAY:
		return
	if event.is_action_pressed("swing", false) or event.is_action_pressed("quit", false):
		get_viewport().set_input_as_handled()
		done.emit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		done.emit()


func _headline() -> Array:
	match run.ending:
		RunState.Ending.BEAT_RIVAL:
			return ["YOU BEAT THE RIVAL!", GOOD]
		RunState.Ending.LOST_TO_RIVAL:
			return ["THE RIVAL WINS", BAD]
		RunState.Ending.OUT_OF_STROKES:
			return ["OUT OF STROKES", BAD]
		RunState.Ending.GAVE_UP:
			return ["RUN ENDED", DIM]
	return ["COURSE COMPLETE", GOOD]


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BACKGROUND)
	var headline: Array = _headline()
	PixelFont.draw_centered(self, str(headline[0]), 320.0, 18.0, headline[1], 3)
	ScorecardView.draw_table(self, run.course, Vector2(18, 54))
	if rival_strokes >= 0:
		PixelFont.draw_centered(self, "THE RIVAL'S CARD ON THE BOSS HOLE: %d" % rival_strokes, 320.0, 116.0, DIM)

	var panel := Rect2(150, 130, 340, 136)
	draw_rect(panel, PANEL)
	draw_rect(panel, DIM, false, 1.0)
	var y: float = panel.position.y + 10.0
	for row: Dictionary in score["rows"]:
		PixelFont.draw(self, str(row["label"]), Vector2(panel.position.x + 12.0, y), TEXT)
		_draw_right(_points_text(int(row["points"])), y, TEXT, panel)
		y += 14.0
	draw_rect(Rect2(panel.position.x + 10.0, panel.end.y - 34.0, panel.size.x - 20.0, 1.0), DIM)
	PixelFont.draw(self, "FINAL SCORE", Vector2(panel.position.x + 12.0, panel.end.y - 24.0), ACCENT, 2)
	_draw_right(str(int(score["total"])), panel.end.y - 24.0, ACCENT, panel, 2)

	var place: int = int(result.get("place", 0))
	if place == 1:
		PixelFont.draw_centered(self, "NEW BEST SCORE!", 320.0, 276.0, GOOD, 2)
	elif place > 0:
		PixelFont.draw_centered(self, "NUMBER %d ON THE HIGH SCORES" % place, 320.0, 280.0, TEXT)
	var unlocked: Array = result.get("unlocked", [])
	if not unlocked.is_empty():
		var names: PackedStringArray = PackedStringArray(unlocked)
		PixelFont.draw_centered(self, "NOW IN THE SHOP: %s" % ", ".join(names), 320.0, 304.0, ACCENT)
	PixelFont.draw_centered(self, "SPACE TO CONTINUE", 320.0, 340.0, DIM)


func _draw_right(text: String, y: float, color: Color, panel: Rect2, size: int = 1) -> void:
	var x: float = panel.end.x - 12.0 - float(PixelFont.text_width(text, size))
	PixelFont.draw(self, text, Vector2(x, y), color, size)


func _points_text(points: int) -> String:
	return "%+d" % points
