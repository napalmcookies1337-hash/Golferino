class_name Hud
extends Node2D
## All on-screen UI. Reads the game state and never changes it.

const YARD := 3.0
const SCREEN_WIDTH := 640.0

const METER_LEFT := 158.0
const METER_TOP := 326.0
const METER_HEIGHT := 11.0
const METER_POWER_WIDTH := 270.0
const PANEL := Color(0.07, 0.09, 0.16, 0.82)
const PANEL_EDGE := Color("f2ead0")
const TEXT := Color("f7f4e6")
const ACCENT := Color("ffe25a")
const DIM := Color("8f97a8")

var game: HoleGame
var camera: FollowCamera
var _message: String = ""
var _message_time: float = 0.0
var _result_name: String = ""


func setup(p_game: HoleGame, p_camera: FollowCamera) -> void:
	game = p_game
	camera = p_camera


func _ready() -> void:
	game.hole_finished.connect(_on_hole_finished)


func show_message(text: String, duration: float) -> void:
	_message = text
	_message_time = duration


func _process(delta: float) -> void:
	_message_time = maxf(_message_time - delta, 0.0)
	queue_redraw()


func _on_hole_finished(_strokes: int, score_name: String) -> void:
	_result_name = score_name


func _draw() -> void:
	_draw_score_panel()
	_draw_distance_panel()
	_draw_club_panel()
	_draw_spin_panel()
	_draw_meter()
	_draw_hint()
	if camera.is_free_looking() and game.phase == HoleGame.Phase.AIM:
		PixelFont.draw_centered(self, "FREE LOOK", SCREEN_WIDTH / 2.0, 12.0, ACCENT)
	if _message_time > 0.0 and game.phase != HoleGame.Phase.COMPLETE:
		PixelFont.draw_centered(self, _message, SCREEN_WIDTH / 2.0, 58.0, ACCENT, 2)
	if game.phase == HoleGame.Phase.COMPLETE:
		_draw_result()


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, PANEL_EDGE, false, 1.0)


func _draw_score_panel() -> void:
	_panel(Rect2(8, 8, 118, 30))
	PixelFont.draw(self, "%s  PAR %d" % [game.hole.display_name, game.hole.par], Vector2(14, 13), TEXT)
	PixelFont.draw(self, "STROKES %d" % game.strokes, Vector2(14, 25), ACCENT)


func _draw_distance_panel() -> void:
	_panel(Rect2(514, 8, 118, 30))
	var pin_yards: int = int(round(game.distance_to_cup() / YARD))
	PixelFont.draw(self, "PIN  %d YD" % pin_yards, Vector2(520, 13), TEXT)
	if game.phase == HoleGame.Phase.AIM or game.phase == HoleGame.Phase.SWING:
		var landing: Vector2 = game.preview()["landing"]
		var reach: int = int(round(absf(landing.x - game.ball.pos.x) / YARD))
		PixelFont.draw(self, "REACH %d YD" % reach, Vector2(520, 25), ACCENT)


func _draw_club_panel() -> void:
	_panel(Rect2(8, 302, 124, 50))
	for i in game.clubs.size():
		var selected: bool = i == game.club_index
		var y: float = 307.0 + float(i) * 14.0
		var color: Color = ACCENT if selected else DIM
		if selected:
			PixelFont.draw(self, ">", Vector2(13, y), ACCENT)
		PixelFont.draw(self, game.clubs[i].display_name, Vector2(23, y), color)
	var surface: Dictionary = Surface.props(game.lie_surface())
	var lie_percent: int = int(round(game.lie_power() * 100.0))
	if game.ball.state == BallSim.State.RESTING and surface.has("name"):
		PixelFont.draw(self, str(surface["name"]), Vector2(74, 307), DIM)
		PixelFont.draw(self, "%d%%" % lie_percent + _slope_text(), Vector2(74, 321), DIM)
	if not game.current_club().is_putter:
		var angle_text: String = "ANGLE %d" % int(round(game.aim_angle))
		PixelFont.draw(self, angle_text, Vector2(74, 335), ACCENT)


func _slope_text() -> String:
	if game.current_club().is_putter:
		return ""
	var tilt: int = int(round(game.launch_angle() - game.aim_angle))
	if tilt == 0:
		return ""
	return " %+d" % tilt


func _draw_spin_panel() -> void:
	_panel(Rect2(508, 302, 124, 50))
	PixelFont.draw(self, "SPIN", Vector2(514, 307), TEXT)
	if game.current_club().is_putter:
		PixelFont.draw(self, "NONE ON PUTTS", Vector2(514, 327), DIM)
		return
	var labels: Array[String] = ["BACK", "NONE", "TOP"]
	var values: Array[int] = [-1, 0, 1]
	var x: float = 514.0
	for i in 3:
		var selected: bool = values[i] == game.spin
		var color: Color = ACCENT if selected else DIM
		PixelFont.draw(self, labels[i], Vector2(x, 327), color)
		if selected:
			draw_rect(Rect2(x, 336, float(labels[i].length()) * 6.0 - 1.0, 1), ACCENT)
		x += float(labels[i].length()) * 6.0 + 9.0


func _draw_meter() -> void:
	var miss_width: float = -SwingMeter.MISS_END * METER_POWER_WIDTH
	var sweet_x: float = METER_LEFT + miss_width
	var total: float = miss_width + METER_POWER_WIDTH

	_panel(Rect2(METER_LEFT - 3.0, METER_TOP - 3.0, total + 6.0, METER_HEIGHT + 6.0))
	draw_rect(Rect2(METER_LEFT, METER_TOP, miss_width, METER_HEIGHT), Color("5c2030"))

	var segments: int = 27
	for i in segments:
		var t: float = float(i) / float(segments)
		var color: Color
		if t < 0.6:
			color = Color("4fb860").lerp(Color("e6d84a"), t / 0.6)
		else:
			color = Color("e6d84a").lerp(Color("e8483f"), (t - 0.6) / 0.4)
		var seg_x: float = sweet_x + t * METER_POWER_WIDTH
		draw_rect(Rect2(seg_x, METER_TOP, METER_POWER_WIDTH / float(segments) + 1.0, METER_HEIGHT), color)

	var window: float = game.meter.perfect_window * METER_POWER_WIDTH
	draw_rect(Rect2(sweet_x - window, METER_TOP, window * 2.0, METER_HEIGHT), Color("ffffff"))
	draw_rect(Rect2(sweet_x, METER_TOP - 2.0, 1, METER_HEIGHT + 4.0), Color("20202e"))

	for mark in [0.25, 0.5, 0.75, 1.0]:
		var mark_x: float = sweet_x + float(mark) * METER_POWER_WIDTH
		draw_rect(Rect2(mark_x - 1.0, METER_TOP + 7.0, 1, 4), Color(0.1, 0.1, 0.16, 0.7))

	var meter: SwingMeter = game.meter
	if game.phase == HoleGame.Phase.AIM:
		PixelFont.draw_centered(self, "SPACE TO SWING", METER_LEFT + total / 2.0, METER_TOP - 14.0, TEXT)
		return

	if meter.stage == SwingMeter.Stage.RETURNING or meter.stage == SwingMeter.Stage.DONE:
		var power_x: float = sweet_x + meter.power * METER_POWER_WIDTH
		draw_rect(Rect2(power_x - 1.0, METER_TOP - 4.0, 3, METER_HEIGHT + 8.0), Color("20202e"))
		draw_rect(Rect2(power_x, METER_TOP - 3.0, 1, METER_HEIGHT + 6.0), ACCENT)

	if meter.stage != SwingMeter.Stage.IDLE:
		var cursor_x: float = round(sweet_x + meter.cursor * METER_POWER_WIDTH)
		draw_rect(Rect2(cursor_x - 2.0, METER_TOP - 5.0, 5, METER_HEIGHT + 10.0), Color("20202e"))
		draw_rect(Rect2(cursor_x - 1.0, METER_TOP - 4.0, 3, METER_HEIGHT + 8.0), Color("ffffff"))


func _draw_hint() -> void:
	if game.phase == HoleGame.Phase.AIM:
		PixelFont.draw_centered(
				self, "UP/DOWN ANGLE  A/D LOOK  Q/E CLUB  W/S SPIN  R RESTART",
				SCREEN_WIDTH / 2.0, 346.0, TEXT)


func _draw_result() -> void:
	var rect := Rect2(190, 96, 260, 92)
	_panel(rect)
	var center: float = SCREEN_WIDTH / 2.0
	PixelFont.draw_centered(self, _result_name, center, 112.0, ACCENT, 3 if _result_name.length() <= 13 else 2)
	PixelFont.draw_centered(self, "%d STROKES ON A PAR %d" % [game.strokes, game.hole.par], center, 146.0, TEXT)
	PixelFont.draw_centered(self, "SPACE TO PLAY AGAIN", center, 166.0, DIM)
