class_name CourseRun
extends RefCounted
## Tracks progress through a course: which hole is next, and the scores so far.
## The stroke budget, shop and duel will build on this in Milestone 4.

var course: CourseData
var hole_index: int = 0
## Strokes for each finished hole, by hole index.
var scores: Dictionary = {}

var _holes: Array[HoleData] = []


func _init(p_course: CourseData = null) -> void:
	course = p_course
	if course == null:
		return
	for path: String in course.hole_paths:
		_holes.append(load(path) as HoleData)


static func from_holes(holes: Array[HoleData]) -> CourseRun:
	var run := CourseRun.new()
	run._holes = holes
	return run


func hole_count() -> int:
	return _holes.size()


func current_hole() -> HoleData:
	return _holes[hole_index]


func hole_at(index: int) -> HoleData:
	return _holes[index]


func is_last_hole() -> bool:
	return hole_index >= _holes.size() - 1


func record_score(strokes: int) -> void:
	scores[hole_index] = strokes


func advance() -> void:
	if is_last_hole():
		start_over()
	else:
		hole_index += 1


func start_over() -> void:
	hole_index = 0
	scores.clear()


## Jumps to a hole without scoring anything, for reviewing the course.
func jump_by(step: int) -> void:
	hole_index = posmod(hole_index + step, _holes.size())


func total_strokes() -> int:
	var total: int = 0
	for strokes: int in scores.values():
		total += strokes
	return total


## Strokes over (positive) or under (negative) par, on finished holes only.
func total_to_par() -> int:
	var par_total: int = 0
	for index: int in scores.keys():
		par_total += _holes[index].par
	return total_strokes() - par_total


static func to_par_text(value: int) -> String:
	return "E" if value == 0 else "%+d" % value
