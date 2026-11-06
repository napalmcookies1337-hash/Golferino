extends Node
## Starts a run straight on Swampy Shores with its own empty save, to try the course without
## beating the first rival every time. Nothing here touches a real save's scores or unlocks.
## Run with: Play.bat res://tests/swamp_preview.tscn

const PROFILE_PATH := "user://swamp_preview_profile.json"
const START_COINS := 40


func _ready() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.profile = Profile.new(PROFILE_PATH)
	add_child(main)
	main.library = MapLibrary.new()
	main.run = CourseRun.from_holes(main.library.load_course(HoleData.BIOME_SWAMP))
	main.run_state.course = main.run
	main.run_state.set_number = 2
	main.run_state.bosses_beaten = 1
	main.run_state.coins = START_COINS
	main.load_current_hole()
