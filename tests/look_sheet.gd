extends Node2D
## Both golfers in each color and pose, at game size, to judge the art by eye.
## Saves tests/shots/look_sheet.png, then quits.
## Run with: Godot --path . --windowed --resolution 1280x720 --quit-after 600 res://tests/look_sheet.tscn


class PosedGolfer:
	extends TitleGolfer

	var pose: String = "address"

	func _update_pose() -> void:
		_clear_reactions()
		_stand_at_ball()
		position = Vector2.ZERO
		match pose:
			"address":
				_arm_angle = _address_angle()
				_hinge = 0.0
			"backswing":
				_arm_angle = BACK_ANGLE
				_hinge = BACK_HINGE
			"follow":
				_arm_angle = FOLLOW_ANGLE
				_hinge = FOLLOW_HINGE
			"slump":
				_slump()
			"run":
				_foot_back = Vector2(-5, -4)
				_foot_front = Vector2(5, -1)
				_arm_angle = RUN_ARM
				_hinge = 0.0
				_lean_scale = 0.0
			"cheer":
				_cheering = true
				_arm_angle = CHEER_ARM
				_hinge = 0.0
				_lean_scale = 0.0


const POSES := ["address", "backswing", "follow", "slump", "run", "cheer"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("6aa8d8"))
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	# A row for each color: male on the left, female on the right, at game size.
	for color in Wardrobe.COLORS[Wardrobe.MALE].size():
		var y: float = 50.0 + float(color) * 64.0
		for side in Wardrobe.MODELS.size():
			var model: String = Wardrobe.MODELS[side]
			for i in POSES.size():
				_add([model, _pieces(model, color)], POSES[i], Vector2(30.0 + float(side) * 320.0 + float(i) * 48.0, y), 1.0)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	get_viewport().get_texture().get_image().save_png("res://tests/shots/look_sheet.png")
	print("look sheet saved")
	get_tree().quit()


func _pieces(model: String, color: int) -> Dictionary:
	var pieces: Dictionary = {}
	for slot: String in Wardrobe.SLOTS:
		pieces[slot] = Wardrobe.items_for(model, slot)[color]
	return pieces

func _add(look: Array, pose: String, at: Vector2, size: float) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.scale = Vector2(size, size)
	add_child(holder)
	var golfer := PosedGolfer.new()
	golfer.setup_title(0.0, func(_x: float) -> float: return 0.0)
	golfer.pose = pose
	golfer.wear(str(look[0]), look[1])
	holder.add_child(golfer)
