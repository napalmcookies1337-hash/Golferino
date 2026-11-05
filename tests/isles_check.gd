extends Node
## Plays random Floating Isles holes with a bot, to see they can be finished and how they play.
## Run: --headless --path . --quit-after 40000 res://tests/isles_check.tscn -- seeds noise first_seed yards
## Noise is how far off the chosen power the bot's swing can be, such as 0.03.

const CLUB_PATHS := ["res://data/clubs/driver.tres", "res://data/clubs/iron.tres", "res://data/clubs/putter.tres"]
const STEP := 1.0 / 60.0
const MAX_STROKES := 250
const POWER_STEPS := 40
## A shot has to get this much nearer the cup to count, in pixels.
const MIN_PROGRESS := 30.0

## The margin for error of every shot played: how much of the meter was safe.
var windows: Array[float] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if args.size() > 0 else 5
	var noise: float = float(args[1]) if args.size() > 1 else 0.03
	var first_seed: int = int(args[2]) if args.size() > 2 else 100
	var yards: int = int(args[3]) if args.size() > 3 else IslesGenerator.DEFAULT_YARDS
	var clubs: Array[ClubData] = []
	for path: String in CLUB_PATHS:
		clubs.append(load(path) as ClubData)
	var stuck: int = 0
	for i in seeds:
		var seed_value: int = first_seed + i
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var hole: HoleData = IslesGenerator.generate(rng, yards)
		var game := HoleGame.new(hole, clubs)
		game.falls_return_to_tee = true
		var islands: int = (hole.void_spans.size() - 1)
		var result: Dictionary = _play(game, rng, noise)
		print("seed %d: %d islands, %s in %d strokes, %d falls" % [seed_value, islands, "holed" if result["holed"] else "STUCK", game.strokes, game.falls])
		if not result["holed"]:
			stuck += 1
	windows.sort()
	print("safe share of the meter: smallest %.0f%%, tenth percentile %.0f%%, middle %.0f%%" % [
		windows[0] * 100.0, windows[windows.size() / 10] * 100.0, windows[windows.size() / 2] * 100.0])
	print("isles check finished: %d stuck of %d" % [stuck, seeds])
	get_tree().quit()


func _play(game: HoleGame, rng: RandomNumberGenerator, noise: float) -> Dictionary:
	while game.strokes < MAX_STROKES:
		if game.ball.state == BallSim.State.HOLED:
			return { "holed": true }
		var plan: Dictionary = _best_shot(game)
		game.select_club(int(plan["club"]))
		game.aim_angle = float(plan["angle"])
		game.spin = int(plan["spin"])
		var power: float = clampf(float(plan["power"]) + rng.randf_range(-noise, noise), 0.02, 0.99)
		var from_x: float = game.ball.pos.x
		game.strike_with(power, 0.0)
		var steps: int = 0
		while game.phase != HoleGame.Phase.AIM and game.phase != HoleGame.Phase.COMPLETE and steps < 6000:
			game.tick(STEP)
			steps += 1
		if game.phase == HoleGame.Phase.COMPLETE:
			return { "holed": true }
		# Enough to see what's gone wrong with a hole that's never finished.
		if game.strokes > MAX_STROKES - 6:
			print("  stroke %d: club %d angle %.0f power %.2f from %.1f to %.1f, cup %.1f, phase %d" % [game.strokes, int(plan["club"]), float(plan["angle"]), power, from_x, game.ball.pos.x, game.hole.cup_x, game.phase])
	return { "holed": false }


# What a careful player does: the shot with the widest margin for error that still moves on,
# struck at the middle of that margin. Records how wide it was.
func _best_shot(game: HoleGame) -> Dictionary:
	var best: Dictionary = {}
	var best_window: float = 0.0
	var from_left: float = game.distance_to_cup()
	for club in game.clubs.size():
		game.select_club(club)
		var putter: bool = game.current_club().is_putter
		if putter and game.lie_surface() != Surface.Type.GREEN:
			continue
		var angles: Array = [0.0] if putter else [game.current_club().loft_deg, game.current_club().max_angle_deg]
		for angle: float in angles:
			for spin: int in ([0] if putter else [-1, 0]):
				game.aim_angle = angle
				game.spin = spin
				var run_from: float = -1.0
				for step_index in range(1, POWER_STEPS + 1):
					var power: float = float(step_index) / float(POWER_STEPS)
					var left: float = _lands(game, power)
					# Close in, anything nearer will do, which lets a short putt count.
					var good: bool = left >= 0.0 and left < from_left - minf(MIN_PROGRESS, from_left / 2.0)
					if good and run_from < 0.0:
						run_from = power
					if run_from >= 0.0 and (not good or step_index == POWER_STEPS):
						var window: float = power - run_from
						if window > best_window:
							best_window = window
							best = { "club": club, "angle": angle, "spin": spin, "power": run_from + window / 2.0 }
						run_from = -1.0
	windows.append(best_window)
	if best.is_empty():
		# Nothing safe at all, so take the middling iron and see.
		return { "club": 1, "angle": 45.0, "spin": 0, "power": 0.5 }
	return best


# How far from the cup this shot stops, or below zero if it falls.
func _lands(game: HoleGame, power: float) -> float:
	var sim: BallSim = game.new_preview_sim()
	var shot: Dictionary = game.shot_for(power, 0.0)
	sim.launch(shot["velocity"], float(shot["spin"]))
	var steps: int = 0
	while sim.is_moving() and steps < 1800:
		sim.step(STEP)
		steps += 1
	if sim.state == BallSim.State.HOLED:
		return 0.0
	if sim.state != BallSim.State.RESTING:
		return -1.0
	return absf(game.hole.cup_x - sim.pos.x)
