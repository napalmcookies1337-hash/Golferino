class_name ScorecardView
extends RefCounted
## Draws the scorecard table onto any canvas.

const HEIGHT := 56.0
const WIDTH := 604.0
const LABEL_WIDTH := 34.0
const PANEL := Color(0.07, 0.09, 0.16, 0.92)
const EDGE := Color("f2ead0")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const ACCENT := Color("ffe25a")
const UNDER := Color("6fe07a")
const OVER := Color("ff8a70")


static func draw_table(canvas: CanvasItem, run: CourseRun, top_left: Vector2) -> void:
	canvas.draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), PANEL)
	canvas.draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), EDGE, false, 1.0)
	var count: int = run.hole_count()
	var column: float = (WIDTH - LABEL_WIDTH - 8.0) / float(count + 1)
	var rows: Array[float] = [top_left.y + 6.0, top_left.y + 23.0, top_left.y + 40.0]
	PixelFont.draw(canvas, "HOLE", Vector2(top_left.x + 6.0, rows[0]), DIM)
	PixelFont.draw(canvas, "PAR", Vector2(top_left.x + 6.0, rows[1]), DIM)
	PixelFont.draw(canvas, "YOU", Vector2(top_left.x + 6.0, rows[2]), ACCENT)
	canvas.draw_rect(Rect2(top_left.x + 3.0, top_left.y + 17.0, WIDTH - 6.0, 1.0), Color(1, 1, 1, 0.2))

	var par_total: int = 0
	for i in count:
		var center: float = top_left.x + LABEL_WIDTH + 4.0 + column * (float(i) + 0.5)
		var is_boss: bool = i == count - 1 and count > 1
		var heading: String = "B" if is_boss else str(i + 1)
		var heading_color: Color = ACCENT if i == run.hole_index else DIM
		_centered(canvas, heading, center, rows[0], heading_color)
		var par: int = run.hole_at(i).par
		par_total += par
		_centered(canvas, str(par), center, rows[1], TEXT)
		if run.scores.has(i):
			var strokes: int = run.scores[i]
			var color: Color = TEXT
			if strokes < par:
				color = UNDER
			elif strokes > par:
				color = OVER
			_centered(canvas, str(strokes), center, rows[2], color)
		else:
			_centered(canvas, "-", center, rows[2], DIM)

	var total_x: float = top_left.x + LABEL_WIDTH + 4.0 + column * (float(count) + 0.5)
	_centered(canvas, "ALL", total_x, rows[0], DIM)
	_centered(canvas, str(par_total), total_x, rows[1], TEXT)
	_centered(canvas, str(run.total_strokes()), total_x, rows[2], ACCENT)


static func _centered(canvas: CanvasItem, text: String, center_x: float, y: float, color: Color) -> void:
	var x: float = round(center_x - float(PixelFont.text_width(text)) / 2.0)
	PixelFont.draw(canvas, text, Vector2(x, y), color)
