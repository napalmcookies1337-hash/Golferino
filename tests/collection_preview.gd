extends Node
## Opens the collection as a brand new player sees it, with its own empty profile, so the
## silhouettes can be looked at without touching a real save. Leaves through the real menu.
## Run with: Play.bat res://tests/collection_preview.tscn

const PROFILE_PATH := "user://preview_profile.json"


func _ready() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	var app: Node = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	app.profile_path = PROFILE_PATH
	add_child(app)
	app._show_collection()
