class_name CourseData
extends Resource
## A course: its holes in playing order. The last one is the boss hole.

@export var display_name: String = "COURSE"
@export var hole_paths: PackedStringArray = PackedStringArray()
