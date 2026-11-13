class_name TitleScreen
extends Node2D
## The title menu. Works with keyboard, controller and mouse.

signal play_chosen
signal infinite_chosen
signal isles_chosen
signal editor_chosen
signal scores_chosen
signal collection_chosen
signal jukebox_chosen
signal appearance_chosen
signal quit_chosen

## Two columns of five, then the jukebox under them both.
enum Item { PLAY, INFINITE, ISLES, EDITOR, APPEARANCE, SCORES, COLLECTION, MUSIC, SOUND, QUIT, JUKEBOX }

const ITEMS := ["PLAY", "INFINITE MODE", "FLOATING ISLES", "MAP EDITOR", "APPEARANCE", "HIGH SCORES", "COLLECTION", "MUSIC", "SOUND", "QUIT", "JUKEBOX"]
const COLUMN_ROWS := 5
const ITEM_TOP := 156.0
const ITEM_GAP := 18.0
const CENTER_X := 320.0
const COLUMN_X := [216.0, 424.0]
const ITEM_HALF_WIDTH := 100.0
const ACCENT := Color("ffe25a")
const TEXT := Color("f7f4e6")
const DIM := Color("8f97a8")
const OUTLINE := Color("20202e")
const LOGO_TOP := 58.0
const LOGO_SIZE := 6
const LOGO_TEXT := "GOLFERIN"
const LOGO_BALL_RADIUS := 20.0
const BALL_FLIGHT_TIME := 1.7
const TEE_X := 112.0
const CUP_X := 560.0
const MENU_PANEL := Rect2(98, 149, 444, 119)
const HINT_Y := 138.0

var library: MapLibrary
var profile: Profile
var _selected: int = 0
## The column to go back to from the jukebox, which is under them both.
var _last_column: int = 0
var _course_size: int = 0
var _time: float = 0.0
var _camera: Camera2D
var _menu: Node2D
var _scene: Node2D
var _flight: float = -1.0


func setup(p_library: MapLibrary, p_profile: Profile) -> void:
	library = p_library
	profile = p_profile


func _ready() -> void:
	Sound.music("title")
	Sound.set_outdoors(true)
	_course_size = library.course_order().size()
	_camera = Camera2D.new()
	_camera.position = Vector2(320, 180)
	add_child(_camera)
	_camera.make_current()
	var background := BackgroundView.new()
	background.setup(_camera, BackgroundView.Mood.MORNING)
	add_child(background)
	_scene = Node2D.new()
	_scene.draw.connect(_draw_scene)
	add_child(_scene)
	var golfer := TitleGolfer.new()
	golfer.setup_title(TEE_X, _ground_y)
	golfer.wear(profile.model, profile.worn_pieces(profile.model))
	golfer.struck.connect(func() -> void: _flight = 0.0)
	add_child(golfer)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_menu = Node2D.new()
	_menu.draw.connect(_draw_menu)
	layer.add_child(_menu)
	ScreenWipe.open(layer)


func _process(delta: float) -> void:
	_time += delta
	if _flight >= 0.0:
		_flight += delta
		if _flight > BALL_FLIGHT_TIME:
			_flight = -1.0
	_scene.queue_redraw()
	_menu.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = _item_at(event.position)
		if hovered >= 0 and hovered != _selected:
			_selected = hovered
			Sound.sfx("menu_move")
	elif event.is_action_pressed("spin_up", false) or event.is_action_pressed("aim_up", false):
		_step_selection(-1)
	elif event.is_action_pressed("spin_down", false) or event.is_action_pressed("aim_down", false):
		_step_selection(1)
	elif event.is_action_pressed("look_left", false):
		_step_sideways(-1)
	elif event.is_action_pressed("look_right", false):
		_step_sideways(1)
	elif event.is_action_pressed("swing", false):
		_choose(_selected)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var over: int = _item_at(event.position)
		if over == Item.MUSIC or over == Item.SOUND:
			_click_level(over, event.position.x)
		elif over >= 0:
			_choose(over)
	elif event.is_action_pressed("quit", false):
		quit_chosen.emit()


## Where a menu item is on the screen, by the middle of its row.
static func item_center(item: int) -> Vector2:
	if item == Item.JUKEBOX:
		return Vector2(CENTER_X, ITEM_TOP + float(COLUMN_ROWS) * ITEM_GAP + 6.0)
	return Vector2(COLUMN_X[item / COLUMN_ROWS], ITEM_TOP + float(item % COLUMN_ROWS) * ITEM_GAP + 6.0)


# Down a column and on to the jukebox, then back round to the top of the same column.
func _step_selection(direction: int) -> void:
	if _selected == Item.JUKEBOX:
		var row: int = 0 if direction > 0 else COLUMN_ROWS - 1
		_selected = _last_column * COLUMN_ROWS + row
	else:
		_last_column = _selected / COLUMN_ROWS
		var row: int = _selected % COLUMN_ROWS + direction
		_selected = Item.JUKEBOX if row < 0 or row >= COLUMN_ROWS else _last_column * COLUMN_ROWS + row
	Sound.sfx("menu_move")


# Left and right set the level on a volume row, and otherwise change column.
func _step_sideways(direction: int) -> void:
	if _selected == Item.MUSIC or _selected == Item.SOUND:
		_change_level(direction)
	elif _selected != Item.JUKEBOX:
		var column: int = _selected / COLUMN_ROWS
		var target: int = column + direction
		if target >= 0 and target < COLUMN_X.size():
			_selected = target * COLUMN_ROWS + _selected % COLUMN_ROWS
			Sound.sfx("menu_move")


func _change_level(direction: int) -> void:
	if _selected == Item.MUSIC:
		VolumeRow.change_music(direction)
	elif _selected == Item.SOUND:
		VolumeRow.change_sfx(direction)


func _click_level(item: int, x: float) -> void:
	var level: int = VolumeRow.level_at(x, item_center(item).x)
	if level < 0:
		return
	if item == Item.MUSIC:
		VolumeRow.change_music(level - Sound.music_level)
	else:
		VolumeRow.change_sfx(level - Sound.sfx_level)


func _item_at(at: Vector2) -> int:
	for i in ITEMS.size():
		var center: Vector2 = item_center(i)
		if absf(at.x - center.x) < ITEM_HALF_WIDTH and at.y >= center.y - 8.0 and at.y < center.y + 10.0:
			return i
	return -1


func _choose(index: int) -> void:
	match index:
		Item.PLAY:
			if _course_size > 0:
				Sound.sfx("menu_ok")
				play_chosen.emit()
			else:
				Sound.sfx("denied")
		Item.INFINITE:
			if profile.rival_beaten:
				Sound.sfx("menu_ok")
				infinite_chosen.emit()
			else:
				Sound.sfx("denied")
		Item.ISLES:
			Sound.sfx("menu_ok")
			isles_chosen.emit()
		Item.EDITOR:
			Sound.sfx("menu_ok")
			editor_chosen.emit()
		Item.SCORES:
			Sound.sfx("menu_ok")
			scores_chosen.emit()
		Item.COLLECTION:
			Sound.sfx("menu_ok")
			collection_chosen.emit()
		Item.JUKEBOX:
			Sound.sfx("menu_ok")
			jukebox_chosen.emit()
		Item.APPEARANCE:
			Sound.sfx("menu_ok")
			appearance_chosen.emit()
		Item.MUSIC, Item.SOUND:
			# Space steps the level round, for anyone without left and right to hand.
			var level: int = Sound.music_level if index == Item.MUSIC else Sound.sfx_level
			var step: int = 1 if level < Sound.LEVELS else -level
			_change_level(step)
		Item.QUIT:
			quit_chosen.emit()


# The ground is level either side of the cup, as it is on the course.
func _ground_y(x: float) -> float:
	var at: float = CUP_X if absf(x - CUP_X) <= Terrain.CUP_HALF + 2.0 else x
	return 334.0 + sin(at * 0.011) * 5.0 + sin(at * 0.023 + 1.0) * 2.0


# A strip of fairway along the bottom, with a pin at one end and a tee at the other.
func _draw_scene() -> void:
	for x in 640:
		var top: float = round(_ground_y(float(x)))
		var stripe: bool = (x / 14) % 2 == 0
		_scene.draw_rect(Rect2(x, top, 1, 1), Color("c8ec7e"))
		_scene.draw_rect(Rect2(x, top + 1.0, 1, 6), Color("7cc24e") if stripe else Color("6db345"))
		_scene.draw_rect(Rect2(x, top + 7.0, 1, 30), Color("6b4a32"))
		if (x * 37) % 11 == 0:
			_scene.draw_rect(Rect2(x, top - 1.0, 1, 1), Color("8fd05a"))
	var rim: float = round(_ground_y(CUP_X))
	TerrainView.draw_cup(_scene, int(CUP_X), int(rim))
	# As on the course, the pole stands on the bottom of the cup.
	var pole: float = Terrain.PIN_HEIGHT + Terrain.CUP_DEPTH - 1.0
	_scene.draw_rect(Rect2(CUP_X, rim - Terrain.PIN_HEIGHT, 1, pole), Color("f4f4ea"))
	_scene.draw_rect(Rect2(CUP_X + 1.0, rim - Terrain.PIN_HEIGHT, 1, pole), Color("a9a99c"))
	for col in 15:
		var wave: float = round(sin(float(col) * 0.7 - _time * 5.0) * float(col) / 7.0)
		var half: int = 5 - col / 3
		var top_y: float = rim - Terrain.PIN_HEIGHT + 5.0 - float(half) + wave
		_scene.draw_rect(Rect2(CUP_X + 2.0 + float(col), top_y, 1, half * 2 + 1), Color("e8483f"))
		_scene.draw_rect(Rect2(CUP_X + 2.0 + float(col), top_y + float(half * 2), 1, 1), Color("a92b35"))
	_draw_title_ball()


func _draw_title_ball() -> void:
	var at := Vector2(TEE_X, round(_ground_y(TEE_X)) - 2.0)
	if _flight >= 0.0:
		var t: float = _flight / BALL_FLIGHT_TIME
		var height: float = sin(t * PI) * 190.0
		at = Vector2(lerpf(TEE_X, CUP_X + 4.0, t), lerpf(at.y, round(_ground_y(CUP_X)), t) - height).round()
	_scene.draw_rect(Rect2(at.x - 2.0, at.y - 3.0, 5, 7), OUTLINE)
	_scene.draw_rect(Rect2(at.x - 3.0, at.y - 2.0, 7, 5), OUTLINE)
	_scene.draw_rect(Rect2(at.x - 2.0, at.y - 2.0, 5, 5), Color.WHITE)


func _draw_menu() -> void:
	_draw_logo()
	_menu.draw_rect(MENU_PANEL, Color(0.06, 0.09, 0.16, 0.6))
	_menu.draw_rect(MENU_PANEL, Color(0.95, 0.92, 0.82, 0.5), false, 1.0)
	for i in ITEMS.size():
		var center: Vector2 = item_center(i)
		var y: float = center.y - 6.0
		if i == Item.MUSIC:
			VolumeRow.draw(_menu, str(ITEMS[i]), Sound.music_level, center.x, y, i == _selected)
			continue
		if i == Item.SOUND:
			VolumeRow.draw(_menu, str(ITEMS[i]), Sound.sfx_level, center.x, y, i == _selected)
			continue
		var color: Color = ACCENT if i == _selected else TEXT
		if (i == Item.PLAY and _course_size == 0) or (i == Item.INFINITE and not profile.rival_beaten):
			color = DIM
		PixelFont.draw_centered(_menu, str(ITEMS[i]), center.x, y, color, 2)
		if i == _selected:
			var half: float = float(PixelFont.text_width(str(ITEMS[i]), 2)) / 2.0
			PixelFont.draw_shadowed(_menu, ">", Vector2(center.x - half - 22.0, y), ACCENT, 2)
	if _selected == Item.INFINITE and not profile.rival_beaten:
		PixelFont.draw_centered(_menu, "BEAT THE RIVAL ONCE TO OPEN INFINITE MODE", CENTER_X, HINT_Y, ACCENT)
	elif _course_size == 0:
		PixelFont.draw_centered(_menu, "THE COURSE HAS NO HOLES: ADD SOME IN THE MAP EDITOR", CENTER_X, HINT_Y, ACCENT)


# The name in big rolling letters, with a golf ball for its last letter.
func _draw_logo() -> void:
	var letter_width: float = float(PixelFont.WIDTH * LOGO_SIZE)
	var total: float = letter_width * float(LOGO_TEXT.length()) + LOGO_BALL_RADIUS * 2.0
	var x: float = round(CENTER_X - total / 2.0)
	for i in LOGO_TEXT.length():
		var bob: float = round(sin(_time * 2.4 - float(i) * 0.55) * 3.0)
		var at := Vector2(x + float(i) * letter_width, LOGO_TOP + bob)
		var letter: String = LOGO_TEXT[i]
		for offset: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2), Vector2(-2, -2), Vector2(0, 5), Vector2(2, 5), Vector2(-2, 5)]:
			PixelFont.draw(_menu, letter, at + offset, OUTLINE, LOGO_SIZE)
		PixelFont.draw(_menu, letter, at, ACCENT, LOGO_SIZE)
	var ball_bob: float = round(sin(_time * 2.4 - float(LOGO_TEXT.length()) * 0.55) * 3.0)
	var center := Vector2(x + letter_width * float(LOGO_TEXT.length()) + LOGO_BALL_RADIUS - 2.0, LOGO_TOP + 20.0 + ball_bob)
	_menu.draw_circle(center + Vector2(0, 3), LOGO_BALL_RADIUS + 2.0, OUTLINE)
	_menu.draw_circle(center, LOGO_BALL_RADIUS, Color("f7f7f2"))
	for dimple: Vector2 in [Vector2(-8, -8), Vector2(0, -11), Vector2(8, -7), Vector2(-11, 1), Vector2(-3, -2), Vector2(5, 1), Vector2(12, 3), Vector2(-6, 8), Vector2(2, 9), Vector2(9, 11)]:
		_menu.draw_rect(Rect2(center + dimple, Vector2(3, 3)), Color("c9d2de"))
