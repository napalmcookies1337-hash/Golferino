class_name MapEditor
extends Node2D
## The in-game map editor: mouse and keyboard tools over the same views the game uses.
## All changes to the map itself go through EditorDoc.

signal test_requested(hole: HoleData, start_x: float)
signal exit_requested

enum Tool { SELECT, GROUND, PAINT, ADD }

const TOP_H := 20.0
const BOTTOM_Y := 330.0
const PANEL_X := 500.0
const ZOOMS: Array[float] = [1.0, 0.75, 0.5, 0.35, 0.25]
const PAN_SPEED := 520.0
const ROTATE_SPEED := 90.0
const HANDLE_RADIUS := 6.0
const ROTATE_HANDLE_DISTANCE := 36.0
const LIST_TOP := 40.0
const ROW_H := 14.0
const LIST_ROWS := 19

const PAINTS: Array[Dictionary] = [
	{ "label": "ROUGH", "type": Surface.Type.ROUGH },
	{ "label": "FAIRWAY", "type": Surface.Type.FAIRWAY },
	{ "label": "GREEN", "type": Surface.Type.GREEN },
	{ "label": "SAND", "type": Surface.Type.SAND },
	{ "label": "TEE", "type": Surface.Type.TEE },
	{ "label": "WATER", "type": Surface.Type.WATER },
	{ "label": "MUD", "type": Surface.Type.MUD },
]
const OBJECTS: Array[Dictionary] = [
	{ "label": "PAD", "kind": "pad" },
	{ "label": "CART", "kind": "cart" },
	{ "label": "MILL", "kind": "windmill" },
	{ "label": "SPRINKLER", "kind": "sprinkler" },
	{ "label": "GOOSE", "kind": "goose" },
	{ "label": "COIN", "kind": "coin" },
	{ "label": "TRUNK", "kind": "trunk" },
	{ "label": "LEAVES", "kind": "leaves" },
	{ "label": "FROG", "kind": "frog" },
	{ "label": "VENT", "kind": "vent" },
	{ "label": "GATOR", "kind": "gator" },
	{ "label": "LILY", "kind": "lily" },
]
const HINTS := {
	Tool.SELECT: "DRAG TO MOVE. Q/E OR THE RING ROTATES, HOLD SHIFT FOR 15 DEG. DEL REMOVES.",
	Tool.GROUND: "CLICK THE GROUND TO ADD A POINT. DRAG POINTS. RIGHT-CLICK REMOVES ONE.",
	Tool.PAINT: "DRAG ACROSS THE MAP TO PAINT THAT STRETCH OF GROUND.",
	Tool.ADD: "CLICK THE MAP TO PLACE IT.",
}

var library: MapLibrary
var doc: EditorDoc
var map_id: String = ""
var tool: int = Tool.SELECT
var selection: Dictionary = {}
var paint_type: int = Surface.Type.FAIRWAY
var add_kind: String = "pad"
var camera: Camera2D
var ui: EditorUI
var maps_open: bool = true

var _scenery_layer: Node2D
var _world: Node2D
var _obstacle_view: ObstacleView
var _overlay: Node2D
var _background: BackgroundView
var _ui_layer: CanvasLayer
var _zoom_index: int = 0
var _mouse: Vector2 = Vector2.ZERO
var _panning: bool = false
var _drag: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_index: int = -1
var _drag_changed: bool = false
var _paint_from: float = 0.0
var _rotating_with_keys: bool = false
var _typing: bool = false
var _toast: String = ""
var _toast_time: float = 0.0
var _confirm: Dictionary = {}
var _maps_scroll: int = 0
var _course_scroll: int = 0
## Which of the two courses the maps screen's list is showing.
var _course_biome: String = HoleData.BIOME_GRASSY


func setup(p_library: MapLibrary) -> void:
	library = p_library


func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(320, 240)
	add_child(camera)
	camera.make_current()

	_background = BackgroundView.new()
	_background.setup(camera)
	add_child(_background)

	# Kept apart from the ground, so that tree pieces can redraw live while being dragged.
	_scenery_layer = Node2D.new()
	add_child(_scenery_layer)

	_world = Node2D.new()
	add_child(_world)

	_obstacle_view = ObstacleView.new()
	add_child(_obstacle_view)

	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	ui = EditorUI.new()
	ui.painter = _draw_ui
	_ui_layer.add_child(ui)


## Goes dormant while a test runs, keeping everything exactly as it was.
func set_active(active: bool) -> void:
	visible = active
	_background.visible = active
	_ui_layer.visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	camera.enabled = active
	if active:
		camera.make_current()
		_drag = ""
		_panning = false


func world_mouse() -> Vector2:
	return get_canvas_transform().affine_inverse() * _mouse


# --- Per frame ---

func _process(delta: float) -> void:
	_toast_time = maxf(_toast_time - delta, 0.0)
	ui.mouse = _mouse
	if doc != null and not maps_open and not _typing and _confirm.is_empty():
		_process_keys_held(delta)
	_overlay.queue_redraw()


func _process_keys_held(delta: float) -> void:
	var ctrl: bool = Input.is_key_pressed(KEY_CTRL)
	var pan := Vector2.ZERO
	if not ctrl:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			pan.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			pan.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			pan.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			pan.y += 1.0
	if pan != Vector2.ZERO:
		camera.position += pan * PAN_SPEED * delta / camera.zoom.x
		_clamp_camera()

	if doc.can_rotate(selection) and not Input.is_key_pressed(KEY_SHIFT):
		var turn: float = 0.0
		if Input.is_physical_key_pressed(KEY_Q):
			turn -= 1.0
		if Input.is_physical_key_pressed(KEY_E):
			turn += 1.0
		if turn != 0.0:
			if not _rotating_with_keys:
				doc.checkpoint()
				_rotating_with_keys = true
			doc.set_rotation(selection, doc.rotation_of(selection) + turn * ROTATE_SPEED * delta)
			_refresh_objects()
		else:
			_rotating_with_keys = false


func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, -100.0, doc.length() + 100.0)
	camera.position.y = clampf(camera.position.y, -300.0, 700.0)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = event.position
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if _typing:
		_handle_typing(event)
		return
	if not _confirm.is_empty():
		if event.physical_keycode == KEY_ESCAPE:
			_confirm = {}
		return
	if event.physical_keycode == KEY_ESCAPE:
		_on_escape()
		return
	if maps_open or doc == null:
		return
	var ctrl: bool = event.ctrl_pressed
	match event.physical_keycode:
		KEY_S when ctrl:
			save_map()
		KEY_Z when ctrl:
			if event.shift_pressed:
				_redo()
			else:
				_undo()
		KEY_Y when ctrl:
			_redo()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_T:
			test_at(world_mouse().x)
		KEY_F5:
			test_from_tee()
		KEY_1:
			set_tool(Tool.SELECT)
		KEY_2:
			set_tool(Tool.GROUND)
		KEY_3:
			set_tool(Tool.PAINT)
		KEY_4:
			set_tool(Tool.ADD)
		KEY_Q when event.shift_pressed:
			_step_rotation(-EditorDoc.ROTATION_SNAP)
		KEY_E when event.shift_pressed:
			_step_rotation(EditorDoc.ROTATION_SNAP)


func _step_rotation(step: float) -> void:
	if doc.can_rotate(selection):
		doc.checkpoint()
		doc.set_rotation(selection, doc.rotation_of(selection) + step, true)
		_refresh_objects()


func _handle_typing(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
			_typing = false
		KEY_BACKSPACE:
			doc.hole.title = doc.hole.title.left(-1)
		_:
			var letter: String = String.chr(event.unicode).to_upper() if event.unicode > 0 else ""
			if letter != "" and doc.hole.title.length() < 20 and (letter == " " or PixelFont.GLYPHS.has(letter)):
				doc.hole.title += letter


func _on_escape() -> void:
	if maps_open:
		if doc != null:
			maps_open = false
		else:
			exit_requested.emit()
	elif not selection.is_empty():
		selection = {}
	else:
		maps_open = true


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and ui.click(event.position):
		return
	if maps_open or not _confirm.is_empty():
		_scroll_maps(event)
		return
	if doc == null:
		return
	if ui.is_over(event.position) and event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_world(world_mouse())
			else:
				_release_world(world_mouse())
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if tool == Tool.GROUND:
					var index: int = doc.point_near(world_mouse(), _handle_radius())
					if index >= 0:
						_remove_point(index)
						return
				_panning = true
			else:
				_panning = false
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_change_zoom(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_change_zoom(1)


func _scroll_maps(event: InputEventMouseButton) -> void:
	if not event.pressed or not maps_open:
		return
	var step: int = 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = -1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = 1
	if step == 0:
		return
	if event.position.x < 370.0:
		_maps_scroll = maxi(_maps_scroll + step, 0)
	else:
		_course_scroll = maxi(_course_scroll + step, 0)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if doc == null or maps_open:
		return
	if _panning:
		camera.position -= event.relative / camera.zoom.x
		_clamp_camera()
	elif _drag != "":
		_drag_to(world_mouse())


func _change_zoom(step: int) -> void:
	var before: Vector2 = world_mouse()
	_zoom_index = clampi(_zoom_index + step, 0, ZOOMS.size() - 1)
	camera.zoom = Vector2.ONE * ZOOMS[_zoom_index]
	# Keeps what's under the mouse in place.
	camera.position += before - (camera.position + (_mouse - Vector2(320, 180)) / camera.zoom.x)
	_clamp_camera()


func _handle_radius() -> float:
	return HANDLE_RADIUS / camera.zoom.x


# --- Tools on the map ---

func _press_world(at: Vector2) -> void:
	_drag_changed = false
	match tool:
		Tool.SELECT:
			_press_select(at)
		Tool.GROUND:
			_press_ground(at)
		Tool.PAINT:
			_paint_from = at.x
			_drag = "paint"
		Tool.ADD:
			place_object(add_kind, at)


func _press_select(at: Vector2) -> void:
	if doc.can_rotate(selection) and rotate_handle().distance_to(at) <= _handle_radius() * 1.5:
		_drag = "rotate"
		return
	var ends: Array[Vector2] = doc.route_ends(selection)
	for i in ends.size():
		if ends[i].distance_to(at) <= _handle_radius() * 1.5:
			_drag = "route"
			_drag_index = i
			return
	selection = doc.pick(at, 4.0 / camera.zoom.x)
	if selection.is_empty():
		return
	_drag = "move"
	_drag_offset = doc.selection_center(selection) - at


func _press_ground(at: Vector2) -> void:
	var index: int = doc.point_near(at, _handle_radius() * 1.5)
	if index < 0:
		if absf(at.y - doc.terrain.basin_y(at.x)) > 40.0 / camera.zoom.x:
			return
		doc.checkpoint()
		_drag_changed = true
		index = doc.add_point(at)
		if index < 0:
			return
	_drag = "point"
	_drag_index = index


func _drag_to(at: Vector2) -> void:
	if not _drag_changed and _drag != "paint":
		doc.checkpoint()
		_drag_changed = true
	match _drag:
		"move":
			doc.move_selection(selection, at + _drag_offset)
			_refresh_objects()
		"rotate":
			var center: Vector2 = doc.selection_center(selection)
			var away: Vector2 = at - center
			doc.set_rotation(selection, rad_to_deg(atan2(away.x, -away.y)), Input.is_key_pressed(KEY_SHIFT))
			_refresh_objects()
		"route":
			doc.move_route_end(selection, _drag_index, at.x)
			_refresh_objects()
		"point":
			doc.move_point(_drag_index, at)
			_refresh_objects()


func _release_world(at: Vector2) -> void:
	var was: String = _drag
	_drag = ""
	if was == "paint":
		if absf(at.x - _paint_from) >= 4.0:
			doc.checkpoint()
			doc.paint_surface(_paint_from, at.x, paint_type)
			_rebuild_world()
	elif _drag_changed:
		_rebuild_world()


func _remove_point(index: int) -> void:
	doc.checkpoint()
	if doc.remove_point(index):
		_rebuild_world()


func place_object(kind: String, at: Vector2) -> void:
	doc.checkpoint()
	selection = doc.add_object(kind, at)
	set_tool(Tool.SELECT)
	_rebuild_world()


func delete_selected() -> void:
	if doc.can_delete(selection):
		doc.checkpoint()
		doc.delete_selection(selection)
		selection = {}
		_rebuild_world()


func set_tool(new_tool: int) -> void:
	tool = new_tool
	_drag = ""


func rotate_handle() -> Vector2:
	var center: Vector2 = doc.selection_center(selection)
	var up: Vector2 = Vector2.UP.rotated(deg_to_rad(doc.rotation_of(selection)))
	return center + up * ROTATE_HANDLE_DISTANCE / camera.zoom.x


func _undo() -> void:
	doc.undo()
	selection = {}
	_rebuild_world()


func _redo() -> void:
	doc.redo()
	selection = {}
	_rebuild_world()


func _change_property(row: Dictionary, direction: float) -> void:
	doc.checkpoint()
	var value: float = clampf(float(row["value"]) + float(row["step"]) * direction, float(row["min"]), float(row["max"]))
	doc.set_property(selection, str(row["key"]), value)
	_rebuild_world()


func rest_pad_on_ground() -> void:
	var entry: Dictionary = doc.entry_of(selection)
	doc.checkpoint()
	entry["y"] = BouncePadObstacle.resting_y(doc.terrain, float(entry["x"]), float(entry.get("rotation", 0.0)))
	_refresh_objects()


func rest_trunk_on_ground() -> void:
	doc.checkpoint()
	doc.rest_trunk_on_ground(selection)
	_refresh_objects()


# --- Building the view ---

func _rebuild_world() -> void:
	for child in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	doc.rebake()
	_match_background()
	var terrain_view := TerrainView.new()
	terrain_view.setup(doc.terrain)
	_world.add_child(terrain_view)
	var water := WaterView.new()
	water.setup(doc.terrain)
	_world.add_child(water)
	var flag := FlagView.new()
	flag.setup(doc.terrain)
	_world.add_child(flag)
	_refresh_objects()


# The sky follows the map's biome.
func _match_background() -> void:
	var wanted: int = BackgroundView.Mood.MURK_EARLY if doc.hole.biome == HoleData.BIOME_SWAMP else BackgroundView.Mood.MIDDAY
	if _background.mood == wanted:
		return
	var at: int = _background.get_index()
	remove_child(_background)
	_background.queue_free()
	_background = BackgroundView.new()
	_background.setup(camera, wanted)
	add_child(_background)
	move_child(_background, at)


func _toggle_biome() -> void:
	doc.checkpoint()
	doc.toggle_biome()
	_rebuild_world()


func _refresh_objects() -> void:
	for child in _scenery_layer.get_children():
		_scenery_layer.remove_child(child)
		child.queue_free()
	var trees := TreeView.new()
	trees.setup(doc.hole, doc.terrain)
	_scenery_layer.add_child(trees)

	var obstacles: Array[Obstacle] = Obstacle.build_all(doc.hole, doc.terrain)
	# Shown in the middle of their routes, where their selection handle is.
	for obstacle in obstacles:
		if obstacle is CartObstacle:
			obstacle.x = (obstacle.from_x + obstacle.to_x) / 2.0
		elif obstacle is GooseObstacle:
			obstacle.x = (obstacle.from_x + obstacle.to_x) / 2.0
			obstacle.clock = 0.0
		elif obstacle is FrogObstacle:
			obstacle.x = (obstacle.from_x + obstacle.to_x) / 2.0
			# Sitting still rather than mid hop.
			obstacle.clock = FrogObstacle.HOP_TIME
	_obstacle_view.setup(obstacles, doc.hole.biome == HoleData.BIOME_SWAMP)


# --- Maps ---

func open_map(id: String) -> void:
	var hole: HoleData = library.load_hole(id)
	if hole == null:
		_show_toast("COULDN'T READ THAT MAP")
		return
	map_id = id
	doc = EditorDoc.new(hole)
	selection = {}
	maps_open = false
	tool = Tool.SELECT
	_zoom_index = 0
	camera.zoom = Vector2.ONE
	camera.position = Vector2(320.0, doc.terrain.ground_y(320.0) - 40.0)
	_rebuild_world()


func new_map() -> void:
	var id: String = library.new_custom_id()
	var hole: HoleData = HoleIO.blank_hole("NEW MAP " + id.right(3))
	if library.save_hole(id, hole):
		open_map(id)
	else:
		_show_toast("COULDN'T CREATE THE MAP")


func save_map() -> void:
	if library.save_hole(map_id, doc.hole):
		doc.dirty = false
		_show_toast("SAVED")
	else:
		_show_toast("SAVE FAILED")


func test_from_tee() -> void:
	test_requested.emit(_copy_for_test(), -1.0)


func test_at(x: float) -> void:
	var spot: float = clampf(x, 5.0, doc.length() - 5.0)
	if doc.terrain.surface_at(spot) == Surface.Type.WATER or doc.terrain.in_cup(spot):
		_show_toast("CAN'T START THERE")
		return
	test_requested.emit(_copy_for_test(), spot)


func _copy_for_test() -> HoleData:
	return HoleIO.from_dict(HoleIO.to_dict(doc.hole))


func _show_toast(text: String) -> void:
	_toast = text
	_toast_time = 2.0


# Runs next once any unsaved changes have been dealt with.
func _guard_unsaved(next: Callable) -> void:
	if doc == null or not doc.dirty:
		next.call()
		return
	_confirm = {
		"text": "SAVE CHANGES TO %s?" % doc.hole.title,
		"buttons": [
			{ "label": "SAVE", "action": func() -> void:
				save_map()
				_confirm = {}
				next.call() },
			{ "label": "DISCARD", "action": func() -> void:
				doc.dirty = false
				_confirm = {}
				next.call() },
			{ "label": "CANCEL", "action": func() -> void: _confirm = {} },
		],
	}


func _ask_restore(id: String, title: String) -> void:
	_confirm = {
		"text": "RESTORE THE ORIGINAL OF %s? YOUR EDITS WILL BE LOST." % title,
		"buttons": [
			{ "label": "RESTORE", "action": func() -> void:
				library.restore_original(id)
				_confirm = {}
				if map_id == id:
					doc = null
					map_id = "" },
			{ "label": "CANCEL", "action": func() -> void: _confirm = {} },
		],
	}


func _ask_delete(id: String, title: String) -> void:
	_confirm = {
		"text": "DELETE %s FOR GOOD?" % title,
		"buttons": [
			{ "label": "DELETE", "action": func() -> void:
				library.delete_map(id)
				_confirm = {}
				if map_id == id:
					doc = null
					map_id = "" },
			{ "label": "CANCEL", "action": func() -> void: _confirm = {} },
		],
	}


func _add_to_course(id: String) -> void:
	var order: Array[String] = library.course_order(_course_biome)
	order.append(id)
	library.save_course_order(order, _course_biome)


func _remove_from_course(index: int) -> void:
	var order: Array[String] = library.course_order(_course_biome)
	order.remove_at(index)
	library.save_course_order(order, _course_biome)


func _switch_course() -> void:
	_course_biome = HoleData.BIOME_GRASSY if _course_biome == HoleData.BIOME_SWAMP else HoleData.BIOME_SWAMP
	_course_scroll = 0


func _move_in_course(index: int, step: int) -> void:
	var order: Array[String] = library.course_order(_course_biome)
	var other: int = index + step
	if other < 0 or other >= order.size():
		return
	var moved: String = order[index]
	order[index] = order[other]
	order[other] = moved
	library.save_course_order(order, _course_biome)


# --- Drawing on the map ---

func _draw_overlay() -> void:
	if doc == null or maps_open:
		return
	var w: float = 1.0 / camera.zoom.x
	_draw_tee(w)
	match tool:
		Tool.GROUND:
			_draw_ground_handles(w)
		Tool.PAINT:
			_draw_paint_preview(w)
		Tool.ADD:
			_draw_add_ghost(w)
	if not selection.is_empty():
		_draw_selection(w)


func _draw_tee(w: float) -> void:
	var at := Vector2(doc.hole.tee_x, doc.terrain.ground_y(doc.hole.tee_x))
	var color := Color("f7f4e6")
	_overlay.draw_line(at + Vector2(-5, -1), at + Vector2(-5, -12), color, 2.0 * w)
	_overlay.draw_line(at + Vector2(5, -1), at + Vector2(5, -12), color, 2.0 * w)
	PixelFont.draw_shadowed(_overlay, "TEE", at + Vector2(-9, -22) * w, color, maxi(1, int(round(w))))
	if tool == Tool.SELECT:
		var cup := Vector2(doc.hole.cup_x, doc.terrain.rim_y)
		PixelFont.draw_shadowed(_overlay, "CUP", cup + Vector2(-9, 8) * w, color, maxi(1, int(round(w))))


func _draw_ground_handles(w: float) -> void:
	var line := PackedVector2Array()
	var x: float = 0.0
	while x <= doc.length():
		line.append(Vector2(x, doc.terrain.basin_y(x)))
		x += 4.0
	_overlay.draw_polyline(line, Color("ffffff"), 1.0 * w)
	var hovering: int = doc.point_near(world_mouse(), _handle_radius() * 1.5)
	for i in doc.hole.points.size():
		var active: bool = i == hovering or (_drag == "point" and i == _drag_index)
		var size: float = (6.0 if active else 4.0) * w
		var point: Vector2 = doc.hole.points[i]
		_overlay.draw_rect(Rect2(point - Vector2.ONE * (size + w), Vector2.ONE * (size + w) * 2.0), Color("20202e"))
		_overlay.draw_rect(Rect2(point - Vector2.ONE * size, Vector2.ONE * size * 2.0), Color("ffe25a") if active else Color("ffffff"))


func _draw_paint_preview(w: float) -> void:
	if _drag != "paint":
		return
	var at: float = world_mouse().x
	var a: float = minf(_paint_from, at)
	var b: float = maxf(_paint_from, at)
	var top: float = -400.0
	_overlay.draw_rect(Rect2(a, top, b - a, 1000.0), Color(1.0, 0.9, 0.3, 0.18))
	_overlay.draw_line(Vector2(a, top), Vector2(a, 600.0), Color("ffe25a"), w)
	_overlay.draw_line(Vector2(b, top), Vector2(b, 600.0), Color("ffe25a"), w)


func _draw_add_ghost(w: float) -> void:
	var at: Vector2 = world_mouse()
	_overlay.draw_arc(at, 8.0 * w, 0.0, TAU, 16, Color("ffe25a"), w)
	_overlay.draw_line(at + Vector2(-5, 0) * w, at + Vector2(5, 0) * w, Color("ffe25a"), w)
	_overlay.draw_line(at + Vector2(0, -5) * w, at + Vector2(0, 5) * w, Color("ffe25a"), w)


func _draw_selection(w: float) -> void:
	var center: Vector2 = doc.selection_center(selection)
	var color := Color("ffe25a")
	_overlay.draw_arc(center, 20.0 * w, 0.0, TAU, 24, color, w)
	var ends: Array[Vector2] = doc.route_ends(selection)
	if ends.size() == 2:
		_overlay.draw_dashed_line(ends[0], ends[1], color, w, 6.0 * w)
		for end in ends:
			_overlay.draw_rect(Rect2(end - Vector2.ONE * 4.0 * w, Vector2.ONE * 8.0 * w), color)
	if doc.can_rotate(selection):
		var handle: Vector2 = rotate_handle()
		_overlay.draw_line(center, handle, color, w)
		_overlay.draw_circle(handle, 5.0 * w, Color("20202e"))
		_overlay.draw_circle(handle, 4.0 * w, color)


# --- Drawing the UI ---

func _draw_ui(canvas: EditorUI) -> void:
	if maps_open or doc == null:
		_draw_maps_screen(canvas)
	else:
		_draw_top_bar(canvas)
		_draw_bottom_bar(canvas)
		_draw_side_panel(canvas)
	if _toast_time > 0.0:
		PixelFont.draw_centered(canvas, _toast, 250.0, 28.0, EditorUI.ACCENT)
	if not _confirm.is_empty():
		_draw_confirm(canvas)


func _draw_top_bar(canvas: EditorUI) -> void:
	canvas.panel(Rect2(0, 0, 640, TOP_H))
	var x: float = 3.0
	x = _top_button(canvas, x, "MAPS", func() -> void: maps_open = true)
	x = _top_button(canvas, x, "SAVE", save_map)
	x = _top_button(canvas, x, "UNDO", _undo, doc.can_undo())
	x = _top_button(canvas, x, "REDO", _redo, doc.can_redo())
	x = _top_button(canvas, x + 8.0, "TEST TEE F5", test_from_tee)
	x = _top_button(canvas, x, "TEST HERE T", func() -> void: test_at(camera.position.x))
	var marker: String = "*" if doc.dirty else ""
	canvas.label("%s%s" % [doc.hole.title, marker], Vector2(x + 8.0, 7), EditorUI.ACCENT)


func _top_button(canvas: EditorUI, x: float, label: String, action: Callable, enabled: bool = true) -> float:
	var width: float = float(PixelFont.text_width(label)) + 8.0
	canvas.button(Rect2(x, 3, width, 14), label, action, false, enabled)
	return x + width + 2.0


func _draw_bottom_bar(canvas: EditorUI) -> void:
	canvas.panel(Rect2(0, BOTTOM_Y, 640, 360.0 - BOTTOM_Y))
	var names: Array[String] = ["1 SELECT", "2 GROUND", "3 PAINT", "4 ADD"]
	for i in names.size():
		canvas.button(Rect2(3.0 + float(i) * 58.0, BOTTOM_Y + 2.0, 56, 13), names[i], set_tool.bind(i), tool == i)
	var x: float = 240.0
	if tool == Tool.PAINT:
		for entry in PAINTS:
			var type: int = int(entry["type"])
			var width: float = float(PixelFont.text_width(str(entry["label"]))) + 8.0
			canvas.button(Rect2(x, BOTTOM_Y + 2.0, width, 13), str(entry["label"]), func() -> void: paint_type = type, paint_type == type)
			x += width + 2.0
	elif tool == Tool.ADD:
		# Runs on to a second row, beside the hint, once the first is full.
		var row_y: float = BOTTOM_Y + 2.0
		for entry in OBJECTS:
			var kind: String = str(entry["kind"])
			var width: float = float(PixelFont.text_width(str(entry["label"]))) + 8.0
			if x + width > 636.0:
				x = 240.0
				row_y += 15.0
			canvas.button(Rect2(x, row_y, width, 13), str(entry["label"]), func() -> void: add_kind = kind, add_kind == kind)
			x += width + 2.0
	canvas.label(str(HINTS[tool]), Vector2(6, BOTTOM_Y + 18.0), EditorUI.DIM)


func _draw_side_panel(canvas: EditorUI) -> void:
	var top: float = TOP_H
	canvas.panel(Rect2(PANEL_X, top, 640.0 - PANEL_X, BOTTOM_Y - top))
	var x: float = PANEL_X + 6.0
	var y: float = top + 5.0

	if selection.is_empty():
		canvas.label("THIS MAP", Vector2(x, y), EditorUI.ACCENT)
		y += 12.0
		var title_text: String = doc.hole.title + ("_" if _typing else "")
		canvas.button(Rect2(x - 2.0, y, 640.0 - PANEL_X - 8.0, 13), title_text, func() -> void: _typing = true, _typing)
		y += 17.0
		canvas.label("LENGTH %d YD" % int(doc.length() / 3.0), Vector2(x, y), EditorUI.DIM)
		y += 12.0
		var biome_text: String = "LOOK: SWAMPY" if doc.hole.biome == HoleData.BIOME_SWAMP else "LOOK: GRASSY"
		canvas.button(Rect2(x - 2.0, y, 640.0 - PANEL_X - 8.0, 13), biome_text, _toggle_biome)
		y += 17.0
	else:
		canvas.label(_selection_name(), Vector2(x, y), EditorUI.ACCENT)
		y += 14.0

	for row in doc.properties(selection):
		y = _draw_property(canvas, row, x, y)

	if str(doc.entry_of(selection).get("kind", "")) == "pad":
		canvas.button(Rect2(x - 2.0, y + 2.0, 640.0 - PANEL_X - 8.0, 13), "REST ON GROUND", rest_pad_on_ground)
		y += 18.0
	if str(doc.piece_of(selection).get("kind", "")) == "trunk":
		canvas.button(Rect2(x - 2.0, y + 2.0, 640.0 - PANEL_X - 8.0, 13), "REST ON GROUND", rest_trunk_on_ground)
		y += 18.0
	if doc.can_delete(selection):
		canvas.button(Rect2(x - 2.0, y + 2.0, 640.0 - PANEL_X - 8.0, 13), "DELETE", delete_selected)
		y += 18.0

	# Problems that would make the map play badly.
	var warning_y: float = BOTTOM_Y - 12.0
	for warning in doc.warnings():
		canvas.label(warning, Vector2(x - 2.0, warning_y), EditorUI.WARNING)
		warning_y -= 10.0
	canvas.label("ZOOM %d%%" % int(ZOOMS[_zoom_index] * 100.0), Vector2(x, warning_y - 2.0), EditorUI.DIM)
	canvas.label("WHEEL ZOOMS. WASD OR", Vector2(x - 2.0, warning_y - 24.0), EditorUI.DIM)
	canvas.label("RIGHT-DRAG MOVES.", Vector2(x - 2.0, warning_y - 14.0), EditorUI.DIM)


func _draw_property(canvas: EditorUI, row: Dictionary, x: float, y: float) -> float:
	canvas.label(str(row["label"]), Vector2(x, y + 3.0))
	var value: float = float(row["value"])
	var step: float = float(row["step"])
	var text: String = "%.1f" % value if step < 1.0 else str(int(round(value)))
	var buttons_x: float = x + 42.0
	canvas.button(Rect2(buttons_x, y, 13, 13), "-", _change_property.bind(row, -1.0))
	var center: float = buttons_x + 13.0 + 30.0 / 2.0
	canvas.label(text, Vector2(round(center - float(PixelFont.text_width(text)) / 2.0), y + 3.0), EditorUI.ACCENT)
	canvas.button(Rect2(buttons_x + 43.0, y, 13, 13), "+", _change_property.bind(row, 1.0))
	return y + 16.0


func _selection_name() -> String:
	var type: String = str(selection.get("type", ""))
	if type == "obstacle":
		var names := { "pad": "BOUNCE PAD", "cart": "GOLF CART", "windmill": "WINDMILL", "sprinkler": "SPRINKLER", "goose": "GOOSE", "coin": "COIN", "frog": "FROG", "vent": "GAS VENT", "gator": "GATOR", "lily": "LILY PAD" }
		return str(names.get(str(doc.entry_of(selection)["kind"]), "OBJECT"))
	if type == "scenery":
		return "TRUNK (SCENERY)" if str(doc.piece_of(selection)["kind"]) == "trunk" else "LEAVES (SCENERY)"
	var plain := { "tee": "TEE", "cup": "CUP", "water": "WATER" }
	return str(plain.get(type, ""))


func _draw_maps_screen(canvas: EditorUI) -> void:
	canvas.draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.07, 0.12))
	canvas.label("MAPS", Vector2(10, 8), EditorUI.ACCENT)
	canvas.label("OPEN ANY MAP TO EDIT IT. ORIGINALS CAN ALWAYS BE RESTORED.", Vector2(10, 22), EditorUI.DIM)
	var showing_swamp: bool = _course_biome == HoleData.BIOME_SWAMP
	canvas.label("SWAMPY SHORES" if showing_swamp else "GRASSY GREENS", Vector2(376, 8), EditorUI.ACCENT)
	canvas.button(Rect2(470, 4, 96, 13), "SHOW GRASSY" if showing_swamp else "SHOW SWAMPY", _switch_course)
	canvas.label("PLAYED IN THIS ORDER. THE LAST IS THE BOSS.", Vector2(376, 22), EditorUI.DIM)

	var ids: Array[String] = library.list_ids()
	_maps_scroll = clampi(_maps_scroll, 0, maxi(ids.size() - LIST_ROWS, 0))
	for row in mini(LIST_ROWS, ids.size() - _maps_scroll):
		_draw_map_row(canvas, ids[_maps_scroll + row], LIST_TOP + float(row) * ROW_H)

	var order: Array[String] = library.course_order(_course_biome)
	_course_scroll = clampi(_course_scroll, 0, maxi(order.size() - LIST_ROWS, 0))
	for row in mini(LIST_ROWS, order.size() - _course_scroll):
		_draw_course_row(canvas, order, _course_scroll + row, LIST_TOP + float(row) * ROW_H)
	if order.is_empty():
		canvas.label("NO HOLES YET. USE ADD ON A MAP.", Vector2(376, LIST_TOP), EditorUI.WARNING)

	canvas.button(Rect2(10, 334, 70, 16), "NEW MAP", func() -> void: _guard_unsaved(new_map))
	if doc != null:
		canvas.button(Rect2(86, 334, 110, 16), "BACK TO EDITING", func() -> void: maps_open = false)
	canvas.button(Rect2(560, 334, 70, 16), "TITLE MENU", func() -> void: _guard_unsaved(func() -> void: exit_requested.emit()))


func _map_title(id: String) -> String:
	var hole: HoleData = library.load_hole(id)
	return hole.title if hole != null else "(UNREADABLE)"


func _draw_map_row(canvas: EditorUI, id: String, y: float) -> void:
	var title: String = _map_title(id)
	var color: Color = EditorUI.ACCENT if id == map_id else EditorUI.TEXT
	canvas.label(title.left(18), Vector2(10, y + 3.0), color)
	var kind: int = library.kind_of(id)
	var tags: Array[String] = ["ORIGINAL", "EDITED", "CUSTOM"]
	canvas.label(tags[kind], Vector2(124, y + 3.0), EditorUI.DIM)
	canvas.button(Rect2(180, y, 40, 12), "OPEN", func() -> void: _guard_unsaved(func() -> void: open_map(id)))
	canvas.button(Rect2(222, y, 34, 12), "ADD", _add_to_course.bind(id))
	if kind == MapLibrary.Kind.EDITED:
		canvas.button(Rect2(258, y, 54, 12), "RESTORE", _ask_restore.bind(id, title))
	elif kind == MapLibrary.Kind.CUSTOM:
		canvas.button(Rect2(258, y, 54, 12), "DELETE", _ask_delete.bind(id, title))


func _draw_course_row(canvas: EditorUI, order: Array[String], index: int, y: float) -> void:
	var is_boss: bool = index == order.size() - 1 and order.size() > 1
	var number: String = "BOSS" if is_boss else "%2d" % (index + 1)
	canvas.label(number, Vector2(376, y + 3.0), EditorUI.ACCENT if is_boss else EditorUI.DIM)
	canvas.label(_map_title(order[index]).left(18), Vector2(404, y + 3.0))
	canvas.button(Rect2(520, y, 26, 12), "UP", _move_in_course.bind(index, -1), false, index > 0)
	canvas.button(Rect2(548, y, 32, 12), "DOWN", _move_in_course.bind(index, 1), false, index < order.size() - 1)
	canvas.button(Rect2(582, y, 48, 12), "REMOVE", _remove_from_course.bind(index))


func _draw_confirm(canvas: EditorUI) -> void:
	canvas.block_all()
	canvas.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55))
	var text: String = str(_confirm["text"])
	var buttons: Array = _confirm["buttons"]
	var width: float = maxf(float(PixelFont.text_width(text)) + 30.0, 260.0)
	var rect := Rect2(320.0 - width / 2.0, 140, width, 70)
	canvas.draw_rect(rect, EditorUI.PANEL)
	canvas.draw_rect(rect, EditorUI.ACCENT, false, 1.0)
	PixelFont.draw_centered(canvas, text, 320.0, 155.0, EditorUI.TEXT)
	var total: float = float(buttons.size()) * 74.0 - 4.0
	var x: float = 320.0 - total / 2.0
	for entry: Dictionary in buttons:
		canvas.button(Rect2(x, 180, 70, 16), str(entry["label"]), entry["action"])
		x += 74.0
