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
const FLASH_TIME := 0.45
const MESSAGE_POP_TIME := 0.14
const MESSAGE_POP_HEIGHT := 10.0
const RESULT_DROP_TIME := 0.32
const RESULT_DROP_HEIGHT := 230.0

var game: HoleGame
var camera: FollowCamera
var run: CourseRun
## The run's budget and coins. Null when testing a map.
var run_state: RunState
## This hole's coins and strokes banked, once it's finished.
var summary: Dictionary = {}
var show_card: bool = false
## A line that stays on screen, such as the test-play reminder.
var banner: String = ""
## Extra lines on the result panel, such as what beating a boss paid.
var result_notes: Array[String] = []
## True while the pause menu is up, so nothing shows through behind its title. A message
## waits and finishes after resuming, and a hole's result comes back.
var message_hidden: bool = false
## Floating Isles: strokes against the best so far, with no par, coins or result panel.
var isles_mode: bool = false
var isles_best: int = 0
var _message: String = ""
var _message_time: float = 0.0
var _result_name: String = ""
var _message_age: float = 0.0
var _result_age: float = 0.0
var _time: float = 0.0
var _coin_flash: float = 0.0
var _spare_flash: float = 0.0
var _shown_coins: int = -1
var _shown_spare: int = -1


func setup(p_game: HoleGame, p_camera: FollowCamera, p_run: CourseRun) -> void:
	game = p_game
	camera = p_camera
	run = p_run


func _ready() -> void:
	game.hole_finished.connect(_on_hole_finished)


func show_message(text: String, duration: float) -> void:
	_message = text
	_message_time = duration
	_message_age = 0.0


func _process(delta: float) -> void:
	if not message_hidden:
		_message_time = maxf(_message_time - delta, 0.0)
		_message_age += delta
	if game.phase == HoleGame.Phase.COMPLETE:
		_result_age += delta
	_time += delta
	_update_flashes(delta)
	queue_redraw()


# The coin and stroke counts light up for a moment when they change.
func _update_flashes(delta: float) -> void:
	_coin_flash = maxf(_coin_flash - delta, 0.0)
	_spare_flash = maxf(_spare_flash - delta, 0.0)
	if run_state == null:
		return
	if run_state.coins != _shown_coins:
		if _shown_coins >= 0:
			_coin_flash = FLASH_TIME
		_shown_coins = run_state.coins
	var spare: int = _current_spare()
	if spare != _shown_spare:
		if _shown_spare >= 0:
			_spare_flash = FLASH_TIME
		_shown_spare = spare


func _current_spare() -> int:
	if game.phase == HoleGame.Phase.COMPLETE:
		return run_state.spare
	return run_state.live_spare(game.strokes, game.hole.par)


func _on_hole_finished(_strokes: int, score_name: String) -> void:
	_result_name = score_name
	_result_age = 0.0


func _draw() -> void:
	_draw_score_panel()
	_draw_distance_panel()
	_draw_club_panel()
	_draw_spin_panel()
	_draw_meter()
	_draw_hint()
	if banner != "":
		PixelFont.draw_centered(self, banner, SCREEN_WIDTH / 2.0, 44.0, Color("9fdcf2"))
	if camera.is_free_looking() and game.phase == HoleGame.Phase.AIM:
		PixelFont.draw_centered(self, "FREE LOOK", SCREEN_WIDTH / 2.0, 12.0, ACCENT)
	_draw_budget_warning()
	if game.rival != null:
		_draw_duel()
	if _message_time > 0.0 and not message_hidden and game.phase != HoleGame.Phase.COMPLETE:
		_draw_message()
	if game.phase == HoleGame.Phase.COMPLETE and not message_hidden and not isles_mode:
		_draw_result()
	if show_card:
		draw_rect(Rect2(0, 0, SCREEN_WIDTH, 360), Color(0, 0, 0, 0.5))
		ScorecardView.draw_table(self, run, Vector2(18, 130))


# Messages hop up into place and start out bright.
func _draw_message() -> void:
	var t: float = clampf(_message_age / MESSAGE_POP_TIME, 0.0, 1.0)
	var rise: float = round((1.0 - t) * (1.0 - t) * MESSAGE_POP_HEIGHT)
	var color: Color = Color.WHITE.lerp(ACCENT, t)
	PixelFont.draw_centered(self, _message, SCREEN_WIDTH / 2.0, 72.0 + rise, color, 2)


# The stroke that uses up the budget: the ball plays out, and only sinking it saves the run.
func _draw_budget_warning() -> void:
	if game.stroke_limit <= 0:
		return
	var aiming: bool = game.phase == HoleGame.Phase.AIM or game.phase == HoleGame.Phase.SWING
	if aiming and game.strokes + 1 >= game.stroke_limit:
		PixelFont.draw_centered(self, "LAST STROKE: SINK IT OR THE RUN ENDS", SCREEN_WIDTH / 2.0, 26.0, Color("ff8a70"))
	elif game.phase == HoleGame.Phase.BALL_MOVING and game.strokes >= game.stroke_limit:
		PixelFont.draw_centered(self, "LAST STROKE!", SCREEN_WIDTH / 2.0, 26.0, Color("ff8a70"))
	elif game.phase == HoleGame.Phase.OUT_OF_STROKES:
		PixelFont.draw_centered(self, "OUT OF STROKES", SCREEN_WIDTH / 2.0, 120.0, Color("ff8a70"), 3)


func _draw_duel() -> void:
	var rival: Rival = game.rival
	var top: float = _score_panel_height() + 14.0
	_panel(Rect2(8, top, 142, 18))
	PixelFont.draw(self, "RIVAL", Vector2(14, top + 5.0), Color("c48cff"))
	var status: String = "HOLED IN %d" % rival.strokes if rival.holed else "STROKES %d" % rival.strokes
	PixelFont.draw(self, status, Vector2(54, top + 5.0), TEXT)
	if game.phase == HoleGame.Phase.RIVAL_TURN:
		PixelFont.draw_centered(self, "THE RIVAL'S TURN", SCREEN_WIDTH / 2.0, 12.0, Color("c48cff"))
	elif game.phase == HoleGame.Phase.AIM and rival.holed:
		var needed: int = rival.strokes - 1 - game.strokes
		PixelFont.draw_centered(self, "HOLE IT WITHIN %d TO WIN" % needed, SCREEN_WIDTH / 2.0, 12.0, ACCENT)


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, PANEL_EDGE, false, 1.0)


func _score_panel_height() -> float:
	if isles_mode:
		return 42.0
	if run_state == null:
		return 30.0
	return 54.0 if run_state.infinite else 42.0


func _draw_score_panel() -> void:
	_panel(Rect2(8, 8, 142, _score_panel_height()))
	if isles_mode:
		PixelFont.draw(self, game.hole.display_name, Vector2(14, 13), TEXT)
		PixelFont.draw(self, "STROKES %d" % game.strokes, Vector2(14, 25), ACCENT)
		PixelFont.draw(self, "BEST %s" % (str(isles_best) if isles_best > 0 else "-"), Vector2(90, 25), TEXT)
		var reached: bool = game.checkpoint_reached
		PixelFont.draw(self, "CHECKPOINT REACHED" if reached else "CHECKPOINT AHEAD", Vector2(14, 37), Color("6fe07a") if reached else DIM)
		return
	PixelFont.draw(self, "%s  PAR %d" % [game.hole.display_name, game.hole.par], Vector2(14, 13), TEXT)
	PixelFont.draw(self, "STROKES %d" % game.strokes, Vector2(14, 25), ACCENT)
	PixelFont.draw(self, "TOTAL %s" % CourseRun.to_par_text(run.total_to_par()), Vector2(90, 25), TEXT)
	if run_state != null:
		var spare: int = _current_spare()
		var spare_color: Color = Color("ff8a70") if spare <= 1 else TEXT
		var coin_color: Color = ACCENT
		if _spare_flash > 0.0:
			spare_color = spare_color.lerp(Color.WHITE, _spare_flash / FLASH_TIME)
		if _coin_flash > 0.0:
			coin_color = coin_color.lerp(Color.WHITE, _coin_flash / FLASH_TIME)
		PixelFont.draw(self, "SPARE %d" % spare, Vector2(14, 37), spare_color)
		PixelFont.draw(self, "COINS %d" % run_state.coins, Vector2(90, 37), coin_color)
		if run_state.infinite:
			PixelFont.draw(self, "SET %d" % run_state.set_number, Vector2(14, 49), TEXT)
			PixelFont.draw(self, "DIFF %d/%d" % [run_state.level, Difficulty.MAX_LEVEL], Vector2(90, 49), TEXT)


func _draw_distance_panel() -> void:
	var wind: float = game.current_wind()
	var has_wind: bool = wind != 0.0
	_panel(Rect2(514, 8, 118, 30 if has_wind else 18))
	if has_wind:
		var strength: int = int(absf(wind))
		# A positive wind blows toward the right of the screen.
		var text: String = "WIND >> %d" % strength if wind > 0.0 else "WIND << %d" % strength
		PixelFont.draw(self, text, Vector2(520, 25), Color("9fdcf2"))
	var pin_yards: int = int(round(game.distance_to_cup() / YARD))
	PixelFont.draw(self, "PIN  %d YD" % pin_yards, Vector2(520, 13), TEXT)


func _draw_club_panel() -> void:
	_panel(Rect2(8, 302, 124, 50))
	for i in game.clubs.size():
		var selected: bool = i == game.club_index
		var y: float = 307.0 + float(i) * 14.0
		var color: Color = ACCENT if selected else DIM
		if selected:
			PixelFont.draw(self, ">", Vector2(13, y), ACCENT)
		PixelFont.draw(self, game.clubs[i].display_name, Vector2(23, y), color)
		_draw_sticker_pips(game.clubs[i].id, y)
	var surface: Dictionary = Surface.props(game.lie_surface())
	var lie_percent: int = int(round(game.lie_power() * 100.0))
	if game.ball.state == BallSim.State.RESTING and surface.has("name"):
		PixelFont.draw(self, str(surface["name"]), Vector2(74, 307), DIM)
		PixelFont.draw(self, "%d%%" % lie_percent + _slope_text(), Vector2(74, 321), DIM)
	if not game.current_club().is_putter:
		var angle_text: String = "ANGLE %d" % int(round(game.aim_angle))
		PixelFont.draw(self, angle_text, Vector2(74, 335), ACCENT)


# One small mark under the club's name for each sticker on it.
func _draw_sticker_pips(club_id: String, y: float) -> void:
	if run_state == null:
		return
	var count: int = (run_state.stickers[club_id] as Array).size()
	for pip in count:
		draw_rect(Rect2(23.0 + float(pip) * 5.0, y + 8.0, 3, 2), Color("6fd0ff"))


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
	# Putts have no accuracy check, so they have no miss zone or sweet spot.
	var is_putt: bool = game.current_club().is_putter
	if not is_putt:
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

	# What the rising cursor hasn't reached yet stays dim.
	var rising: bool = game.meter.stage == SwingMeter.Stage.RISING
	if rising:
		var filled: float = game.meter.cursor * METER_POWER_WIDTH
		draw_rect(Rect2(sweet_x + filled, METER_TOP, METER_POWER_WIDTH - filled + 1.0, METER_HEIGHT), Color(0.05, 0.06, 0.12, 0.55))

	if not is_putt:
		var window: float = game.meter.perfect_window * METER_POWER_WIDTH
		# The sweet spot glows on the way back, when it matters.
		var sweet: Color = Color.WHITE
		if game.meter.stage == SwingMeter.Stage.RETURNING:
			sweet = Color.WHITE.lerp(ACCENT, 0.5 + 0.5 * sin(_time * 18.0))
		draw_rect(Rect2(sweet_x - window, METER_TOP, window * 2.0, METER_HEIGHT), sweet)
	draw_rect(Rect2(sweet_x, METER_TOP - 2.0, 1, METER_HEIGHT + 4.0), Color("20202e"))

	for mark in [0.25, 0.5, 0.75, 1.0]:
		var mark_x: float = sweet_x + float(mark) * METER_POWER_WIDTH
		draw_rect(Rect2(mark_x - 1.0, METER_TOP + 7.0, 1, 4), Color(0.1, 0.1, 0.16, 0.7))

	var meter: SwingMeter = game.meter
	if game.phase == HoleGame.Phase.AIM:
		var prompt: String = "SPACE TO PUTT" if is_putt else "SPACE TO SWING"
		PixelFont.draw_centered(self, prompt, METER_LEFT + total / 2.0, METER_TOP - 14.0, TEXT)
		return
	if meter.full_power and game.phase != HoleGame.Phase.BALL_MOVING:
		var flicker: Color = ACCENT if fmod(_time, 0.14) < 0.07 else Color.WHITE
		PixelFont.draw_centered(self, "FULL POWER!!", METER_LEFT + total / 2.0, METER_TOP - 16.0, flicker)

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
		# Testing a map can restart it, but a real run has a budget to protect.
		var last: String = "TAB CARD" if run_state != null else "R RESET"
		if isles_mode:
			last = "ESC MENU"
		var hint: String = "UP/DN ANGLE  A/D LOOK  Q/E CLUB  W/S SPIN  F FLIP  %s" % last
		# Putts stay on the ground, so angle and spin do nothing.
		if game.current_club().is_putter:
			hint = "A/D LOOK  Q/E CLUB  F FLIP  %s" % last
		PixelFont.draw_centered(self, hint, SCREEN_WIDTH / 2.0, 346.0, TEXT)


## True once a rival's beaten with more to come: the run goes on to a shop and the next course.
func run_carries_on() -> bool:
	if run_state == null or game.rival == null or not game.duel_won:
		return false
	return run_state.infinite or run_state.rival_beaten_with_more_to_come


func _draw_result() -> void:
	# Drops in from above and settles with a small bounce.
	var t: float = clampf(_result_age / RESULT_DROP_TIME, 0.0, 1.0)
	var drop: float = -round((1.0 - t) * (1.0 - t) * RESULT_DROP_HEIGHT)
	if t >= 1.0:
		var after: float = _result_age - RESULT_DROP_TIME
		drop = round(sin(minf(after * 16.0, PI)) * 3.0)
	var rect := Rect2(150, 84.0 + drop, 340, 124)
	_panel(rect)
	var center: float = SCREEN_WIDTH / 2.0
	PixelFont.draw_centered(self, _result_name, center, 94.0 + drop, ACCENT, 3 if _result_name.length() <= 13 else 2)
	var y: float = 126.0 + drop
	if game.rival != null:
		var yours: String = str(game.strokes) if game.player_holed else "DIDN'T FINISH"
		var theirs: String = str(game.rival.strokes) if game.rival.holed else "DIDN'T FINISH"
		PixelFont.draw_centered(self, "YOU %s    RIVAL %s" % [yours, theirs], center, y, TEXT)
	else:
		var stroke_word: String = "STROKE" if game.strokes == 1 else "STROKES"
		PixelFont.draw_centered(self, "%d %s ON A PAR %d" % [game.strokes, stroke_word, game.hole.par], center, y, TEXT)
	y += 12.0
	var total: String = CourseRun.to_par_text(run.total_to_par())
	PixelFont.draw_centered(self, "TOTAL %s" % total, center, y, TEXT)
	y += 12.0
	if not summary.is_empty():
		# After a boss in infinite mode, the notes below say what became of the spare strokes.
		if not (run_carries_on() and run_state.infinite):
			var banked: int = int(summary["banked"])
			var banked_text: String = "PAR: NO CHANGE TO SPARE STROKES"
			if banked != 0:
				banked_text = "SPARE STROKES %+d, NOW %d" % [banked, run_state.spare]
			PixelFont.draw_centered(self, banked_text, center, y, Color("6fe07a") if banked >= 0 else Color("ff8a70"))
			y += 12.0
		PixelFont.draw_centered(self, RunState.coins_text(summary), center, y, ACCENT)
		y += 11.0
	for note in result_notes:
		PixelFont.draw_centered(self, note, center, y, Color("6fe07a"))
		y += 9.0
	var prompt: String = "SPACE TO CONTINUE"
	if run_state != null and (not run.is_last_hole() or run_carries_on()):
		prompt = "SPACE FOR THE SHOP"
	elif run_state != null:
		prompt = "SPACE FOR THE FINAL SCORE"
	PixelFont.draw_centered(self, prompt, center, 192.0 + drop, DIM)
