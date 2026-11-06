extends "res://tests/test_runner.gd"
## Plays generated holes with the rules tests' simulated players, at every difficulty, to catch
## any hole that can't be finished or is brutal. Much slower than the rules tests, so it runs
## on its own. Prints the seed of anything that fails, so that hole can be made again.
## Run with: Godot --headless --path . --quit-after 40000 res://tests/generator_check.tscn
## After the scene, "-- seeds first_level last_level first_seed swamp" narrows it, or spreads it
## over several processes at once. By default: 2 seeds of every level, about 12 minutes.

const OVER_PAR_LIMIT := 6.0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = maxi(int(args[0]), 1) if args.size() > 0 else 2
	var first_level: int = int(args[1]) if args.size() > 1 else 0
	var last_level: int = int(args[2]) if args.size() > 2 else Difficulty.MAX_LEVEL
	var first_seed: int = int(args[3]) if args.size() > 3 else 0
	var biome: String = HoleData.BIOME_SWAMP if args.size() > 4 and args[4] == "swamp" else HoleData.BIOME_GRASSY
	var started: int = Time.get_ticks_msec()
	var holes: int = 0
	var bad: int = 0
	var noise := RandomNumberGenerator.new()
	noise.seed = 4242
	for level in range(first_level, last_level + 1):
		var level_over: float = 0.0
		var level_rounds: int = 0
		var worst: float = -99.0
		var boss_over: float = 0.0
		var bosses: int = 0
		for seed_index in seeds:
			var seed_value: int = level * 1000 + first_seed + seed_index
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var set_holes: Array[HoleData] = HoleGenerator.generate_set(rng, level, biome)
			for hole in set_holes:
				holes += 1
				var perfect: int = _play_round(hole, noise, 0.0, 0.0, true)
				var total: int = 0
				var unfinished: int = 0
				var rounds: int = 2
				for _r in rounds:
					var strokes: int = _play_round(hole, noise, 0.06, 0.05, true)
					if strokes < 0:
						unfinished += 1
					else:
						total += strokes
				_round_events.clear()
				var average: float = float(total) / float(maxi(rounds - unfinished, 1))
				var over: float = average - float(hole.par)
				level_over += over
				level_rounds += 1
				worst = maxf(worst, over)
				# The perfect player repeats one plan exactly, so a moving hazard can stop it even on
				# a fair hole. An ordinary player can run past the shot limit on a long hole while
				# still moving forward. It's only a real failure when neither gets round.
				if perfect < 0 and unfinished > 0:
					bad += 1
					print("BAD level %d seed %d %s par %d cup %d: perfect %d, average %.1f, unfinished %d, features %s" % [
						level, seed_value, hole.display_name, hole.par, int(hole.cup_x), perfect, average, unfinished, _kinds(hole)])
				elif perfect < 0 or unfinished > 0:
					print("NOTE level %d seed %d %s: perfect %d, others averaged %.1f on par %d, %d over the limit, features %s" % [
						level, seed_value, hole.display_name, perfect, average, hole.par, unfinished, _kinds(hole)])
				if hole.par == HoleGenerator.BOSS_PAR:
					boss_over += over
					bosses += 1
				elif over > OVER_PAR_LIMIT and hole.par < HoleGenerator.BOSS_PAR:
					print("HARD level %d seed %d %s par %d: average %.1f, features %s" % [level, seed_value, hole.display_name, hole.par, average, _kinds(hole)])
		print("level %2d: average %+.1f over par per hole, worst %+.1f, bosses %+.1f (%d s so far)" % [
			level, level_over / float(maxi(level_rounds, 1)), worst, boss_over / float(maxi(bosses, 1)), (Time.get_ticks_msec() - started) / 1000])
	print("generator check finished: %d holes, %d bad" % [holes, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _kinds(hole: HoleData) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in hole.obstacles:
		if entry["kind"] != "coin":
			parts.append(str(entry["kind"]))
	if not hole.water_spans.is_empty():
		parts.append("water x%d" % hole.water_spans.size())
	return ", ".join(parts)
