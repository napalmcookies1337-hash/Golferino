extends "res://tests/test_runner.gd"
## Plays the Swampy Shores course with the rules tests' simulated players, to see how each hole
## plays and catch anything that can't be finished. They can't time moving hazards any better than
## by waiting, so read these numbers as a guide. Run on its own, as it's slower than the rules tests.
## Run with: Godot --headless --path . --quit-after 40000 res://tests/swamp_check.tscn -- rounds

const SWAMP_PATH := "res://data/course_02.tres"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rounds: int = maxi(int(args[0]), 1) if args.size() > 0 else 4
	var noise := RandomNumberGenerator.new()
	noise.seed = 4242
	var run := CourseRun.new(load(SWAMP_PATH) as CourseData)
	var par_total: int = 0
	var average_total: float = 0.0
	for i in run.hole_count():
		var hole: HoleData = run.hole_at(i)
		par_total += hole.par
		var perfect: int = _play_round(hole, noise, 0.0, 0.0, true)
		var total: int = 0
		var unfinished: int = 0
		var worst: int = 0
		for _r in rounds:
			var strokes: int = _play_round(hole, noise, 0.06, 0.05, true)
			if strokes < 0:
				unfinished += 1
			else:
				total += strokes
				worst = maxi(worst, strokes)
		var average: float = float(total) / float(maxi(rounds - unfinished, 1))
		average_total += average
		print("%-9s %-16s par %d: perfect %2d, average %4.1f, worst %2d, unfinished %d, %s" % [
			hole.display_name, hole.title, hole.par, perfect, average, worst, unfinished, str(_round_events)])
		_round_events.clear()
		var game := HoleGame.new(hole, _clubs())
		var traps: Array[int] = []
		for x in range(5, game.terrain.length - 5, 10):
			if game.terrain.surface_at(float(x)) == Surface.Type.WATER or game.terrain.in_cup(float(x)):
				continue
			game.ball.place(float(x))
			game._begin_aim()
			if not _can_get_out(game):
				traps.append(x)
		if not traps.is_empty():
			print("  TRAPS at %s" % str(traps))
	print("course par %d, average %.1f" % [par_total, average_total])
	print("swamp check finished")
	get_tree().quit()
