class_name MapLibrary
extends RefCounted
## Every map the player can use, and the order the course plays them in. Original holes
## ship with the game and are never changed: editing one saves a copy that takes its place
## until it's restored.

const COURSE_PATH := "res://data/course_01.tres"
const DEFAULT_DIR := "user://maps"
const ORDER_FILE := "course_order.json"
const COIN_MIN_HEIGHT := 6.0

## How a map relates to the originals.
enum Kind { ORIGINAL, EDITED, CUSTOM }

var dir: String
var _builtin_paths: Dictionary = {}
var _builtin_order: Array[String] = []


## Tests pass their own folder, so they never touch the player's maps.
func _init(p_dir: String = DEFAULT_DIR) -> void:
	dir = p_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var course: CourseData = load(COURSE_PATH)
	for path: String in course.hole_paths:
		var id: String = path.get_file().get_basename()
		_builtin_paths[id] = path
		_builtin_order.append(id)


func is_original(id: String) -> bool:
	return _builtin_paths.has(id)


func kind_of(id: String) -> int:
	if not is_original(id):
		return Kind.CUSTOM
	return Kind.EDITED if FileAccess.file_exists(_user_path(id)) else Kind.ORIGINAL


## All map ids: originals in course order, then custom maps by name.
func list_ids() -> Array[String]:
	var ids: Array[String] = _builtin_order.duplicate()
	var custom: Array[String] = []
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".json") and file_name != ORDER_FILE:
			var id: String = file_name.get_basename()
			if not is_original(id):
				custom.append(id)
	custom.sort()
	ids.append_array(custom)
	return ids


## Returns a fresh copy that's safe to change, or null if the map can't be read.
func load_hole(id: String) -> HoleData:
	if FileAccess.file_exists(_user_path(id)):
		var text: String = FileAccess.get_file_as_string(_user_path(id))
		var data: Variant = JSON.parse_string(text)
		var saved: HoleData = HoleIO.from_dict(data)
		if saved != null:
			if is_original(id) and not (data as Dictionary).has(HoleIO.COIN_VERSION_KEY):
				_add_original_coins(saved, id)
			return saved
		push_warning("Couldn't read map %s, so it was skipped." % id)
	if is_original(id):
		return load_original(id)
	return null


# An edit saved before coins existed gets the original's, kept above its own ground.
func _add_original_coins(hole: HoleData, id: String) -> void:
	var terrain := Terrain.new(hole)
	var obstacles: Array = hole.obstacles
	for entry: Dictionary in load_original(id).obstacles:
		if str(entry.get("kind", "")) != "coin":
			continue
		var coin: Dictionary = entry.duplicate()
		var x: float = clampf(float(coin["x"]), 0.0, float(terrain.length))
		coin["x"] = x
		coin["y"] = minf(float(coin["y"]), terrain.ground_y(x) - COIN_MIN_HEIGHT)
		obstacles.append(coin)
	hole.obstacles = obstacles


func load_original(id: String) -> HoleData:
	var original: HoleData = load(_builtin_paths[id])
	return HoleIO.from_dict(HoleIO.to_dict(original))


func save_hole(id: String, hole: HoleData) -> bool:
	var file := FileAccess.open(_user_path(id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(HoleIO.to_dict(hole), "\t"))
	file.close()
	return true


## Goes back to the original, discarding the edited copy. Does nothing for custom maps.
func restore_original(id: String) -> void:
	if is_original(id) and FileAccess.file_exists(_user_path(id)):
		DirAccess.remove_absolute(_user_path(id))


## Deletes a custom map and takes it out of the course. Originals can't be deleted.
func delete_map(id: String) -> void:
	if is_original(id):
		return
	if FileAccess.file_exists(_user_path(id)):
		DirAccess.remove_absolute(_user_path(id))
	var order: Array[String] = course_order()
	while order.has(id):
		order.erase(id)
	save_course_order(order)


func new_custom_id() -> String:
	var number: int = 1
	while FileAccess.file_exists(_user_path("map_%03d" % number)):
		number += 1
	return "map_%03d" % number


## The ids the course plays, in order. The last one is the boss hole.
func course_order() -> Array[String]:
	var path: String = "%s/%s" % [dir, ORDER_FILE]
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Array:
			var order: Array[String] = []
			for id: Variant in data:
				if is_original(str(id)) or FileAccess.file_exists(_user_path(str(id))):
					order.append(str(id))
			return order
	return _builtin_order.duplicate()


func save_course_order(order: Array[String]) -> void:
	var file := FileAccess.open("%s/%s" % [dir, ORDER_FILE], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(order))
		file.close()


## The course's holes, labelled by their position in it.
func load_course() -> Array[HoleData]:
	var holes: Array[HoleData] = []
	var order: Array[String] = course_order()
	for id in order:
		var hole: HoleData = load_hole(id)
		if hole != null:
			holes.append(hole)
	for i in holes.size():
		var is_boss: bool = i == holes.size() - 1 and holes.size() > 1
		holes[i].display_name = "BOSS HOLE" if is_boss else "HOLE %d" % (i + 1)
	return holes


func _user_path(id: String) -> String:
	return "%s/%s.json" % [dir, id]
