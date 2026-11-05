class_name CourseRun
extends RefCounted
## Tracks progress through a course: which hole is next, and the scores so far.
## RunState builds the stroke budget, coins and shop on top of this.

var course: CourseData
var hole_index: int = 0
## Strokes for each finished hole, by hole index.
var scores: Dictionary = {}
## What earlier sets add to the totals, in infinite mode.
var carried_to_par: int = 0
var carried_holes: int = 0

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
	return total_strokes() - par_total + carried_to_par


## How many holes have been finished, over every set.
func finished_holes() -> int:
	return scores.size() + carried_holes


## The next set's course, with this one's totals carried over.
func next_set(holes: Array[HoleData]) -> CourseRun:
	var next: CourseRun = CourseRun.from_holes(holes)
	next.carried_to_par = total_to_par()
	next.carried_holes = finished_holes()
	return next


static func to_par_text(value: int) -> String:
	return "0" if value == 0 else "%+d" % value
