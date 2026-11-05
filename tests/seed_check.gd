extends Node
## Rebuilds an infinite run from the seed in the log, and loads and plays every hole of it in
## the real scene, printing as it goes. For hunting down a crash or a hang on a particular run.
## Run: --headless --path . --quit-after 200000 res://tests/seed_check.tscn -- seed sets shots frames
## Leave out --headless and give it some frames per hole to test the drawing as well.

const PROFILE_PATH := "user://seed_check_profile.json"
const STEP := 1.0 / 60.0
const MAX_STEPS_PER_SHOT := 2400

var main: Node2D
var frames_per_hole: int = 1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_value: int = int(args[0]) if args.size() > 0 else 1
	var sets: int = int(args[1]) if args.size() > 1 else 3
	var shots: int = int(args[2]) if args.size() > 2 else 12
	frames_per_hole = int(args[3]) if args.size() > 3 else 1
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.profile = Profile.new(PROFILE_PATH)
	main.infinite = true
	main.infinite_seed = seed_value
	add_child(main)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for set_index in sets:
		for hole_index in main.run.hole_count():
			await _play_hole(set_index, hole_index, shots, rng)
		# The same order the real game asks for holes in, so the same holes come out.
		var next_level: int = mini(set_index + 1, Difficulty.MAX_LEVEL)
		main.run_state.level = next_level
		main.run = main.run.next_set(HoleGenerator.generate_set(main._hole_rng, next_level))
		main.run_state.course = main.run
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	print("seed check finished")
	get_tree().quit()


func _play_hole(set_index: int, hole_index: int, shots: int, rng: RandomNumberGenerator) -> void:
	var started: int = Time.get_ticks_msec()
	main.run.hole_index = hole_index
	main.run_state.spare = 500
	main.load_current_hole()
	await get_tree().process_frame
	await get_tree().process_frame
	var game: HoleGame = main.game
	print("set %d hole %d \"%s\" par %d length %d rival %s loaded in %d ms" % [
		set_index + 1, hole_index + 1, game.hole.title, game.hole.par, game.terrain.length, game.rival != null, Time.get_ticks_msec() - started])
	for shot in shots:
		if game.phase == HoleGame.Phase.COMPLETE or game.phase == HoleGame.Phase.OUT_OF_STROKES:
			break
		# Drive the phases by hand, the rival's turns included.
		var steps: int = 0
		while game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.COMPLETE and steps < MAX_STEPS_PER_SHOT * 4:
			game.tick(STEP)
			steps += 1
		if game.phase != HoleGame.Phase.AIM:
			if game.phase != HoleGame.Phase.COMPLETE:
				print("  STUCK in phase %d after %d steps" % [game.phase, steps])
			break
		game.spin = rng.randi_range(-1, 1)
		game.aim_angle = rng.randf_range(game.current_club().min_angle_deg, game.current_club().max_angle_deg)
		game.preview()
		game.strike_with(rng.randf_range(0.2, 1.0), rng.randf_range(-0.1, 0.1))
		steps = 0
		while game.phase == HoleGame.Phase.BALL_MOVING and steps < MAX_STEPS_PER_SHOT:
			game.tick(STEP)
			steps += 1
		if steps >= MAX_STEPS_PER_SHOT:
			print("  STUCK: ball still moving at %s" % game.ball.pos)
			break
	# Time on screen, so that with a window everything really gets drawn for a while.
	for _frame in frames_per_hole:
		await get_tree().process_frame
	print("  finished in %d ms, %d strokes" % [Time.get_ticks_msec() - started, game.strokes])
