class_name Profile
extends RefCounted
## What lasts between runs: high scores and what finished runs have unlocked. Anything
## read back is cleaned up, so a damaged file can't crash the game.

const DEFAULT_PATH := "user://profile.json"
const MAX_SCORES := 10
## How many new shop items a finished run unlocks, for losing or beating the rival.
const UNLOCKS_FOR_FINISHING := 1
const UNLOCKS_FOR_WINNING := 2

var path: String
## Best first. Each: { "score", "ending", "to_par" }.
var high_scores: Array[Dictionary] = []
## Infinite mode's own table. Each also has "sets" (reached) and "bosses" (beaten).
var infinite_scores: Array[Dictionary] = []
## Floating Isles' own tables, one per course length, fewest strokes first. Maps yards to an
## array of { "strokes", "falls" }.
var isles_scores: Dictionary = {}
var unlocked: Array[String] = []
var runs_finished: int = 0
## Whether the rival has ever been beaten, which opens infinite mode.
var rival_beaten: bool = false


## Tests pass their own path, so they never touch the player's scores.
func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	for yards: int in IslesGenerator.COURSE_YARDS:
		isles_scores[yards] = []
	_load()


## Records a finished run. Returns its place in the table (1 is best, 0 if it didn't make
## it) and the names of anything newly unlocked.
func record_run(run: RunState) -> Dictionary:
	var result: Dictionary = run.final_score()
	var entry: Dictionary = {
		"score": int(result["total"]),
		"ending": run.ending,
		"to_par": run.course.total_to_par(),
	}
	if run.infinite:
		entry["sets"] = run.set_number
		entry["bosses"] = run.bosses_beaten
	var place: int = _insert_score(infinite_scores if run.infinite else high_scores, entry)

	var new_items: Array[String] = []
	if run.is_finished_run():
		runs_finished += 1
		if run.ending == RunState.Ending.BEAT_RIVAL:
			rival_beaten = true
		new_items = _unlock_next(UNLOCKS_FOR_WINNING if run.ending == RunState.Ending.BEAT_RIVAL else UNLOCKS_FOR_FINISHING)
	save()
	return { "place": place, "unlocked": new_items }


## Infinite mode: beating a boss doesn't end the run, but it counts as a win. Returns the
## names of anything newly unlocked.
func record_boss_beaten() -> Array[String]:
	rival_beaten = true
	var new_items: Array[String] = _unlock_next(UNLOCKS_FOR_WINNING)
	save()
	return new_items


## The Floating Isles table for this length of course.
func isles_table(yards: int) -> Array:
	return isles_scores[yards]


## Records a finished crossing of the Floating Isles. Returns its place in that course's table
## (1 is best, 0 if it didn't make it). A level score goes below the ones already there.
func record_isles(yards: int, strokes: int, falls: int) -> int:
	var table: Array = isles_table(yards)
	var entry: Dictionary = { "strokes": strokes, "falls": falls }
	var place: int = 0
	for i in table.size():
		if _isles_score_is_better(entry, table[i]):
			table.insert(i, entry)
			place = i + 1
			break
	if place == 0 and table.size() < MAX_SCORES:
		table.append(entry)
		place = table.size()
	if table.size() > MAX_SCORES:
		table.resize(MAX_SCORES)
	save()
	return place


## The fewest strokes yet across this length of course, or 0 if never finished.
func best_isles_strokes(yards: int) -> int:
	var table: Array = isles_table(yards)
	return 0 if table.is_empty() else int(table[0]["strokes"])


# Fewest strokes wins, and on the same strokes, fewest falls.
static func _isles_score_is_better(a: Dictionary, b: Dictionary) -> bool:
	if int(a["strokes"]) != int(b["strokes"]):
		return int(a["strokes"]) < int(b["strokes"])
	return int(a["falls"]) < int(b["falls"])


func _unlock_next(count: int) -> Array[String]:
	var new_items: Array[String] = []
	for id in Items.unlock_order():
		if count <= 0:
			break
		if not unlocked.has(id):
			unlocked.append(id)
			new_items.append(str(Items.by_id(id)["name"]))
			count -= 1
	return new_items


# Returns its place in the table (1 is best), or 0 if it didn't make it.
func _insert_score(table: Array[Dictionary], entry: Dictionary) -> int:
	var place: int = 0
	for i in table.size():
		if int(entry["score"]) > int(table[i]["score"]):
			table.insert(i, entry)
			place = i + 1
			break
	if place == 0 and table.size() < MAX_SCORES:
		table.append(entry)
		place = table.size()
	if table.size() > MAX_SCORES:
		table.resize(MAX_SCORES)
	return place


## Whether the player has this item: on sale from the start, or earned by a finished run.
func has_item(id: String) -> bool:
	var item: Dictionary = Items.by_id(id)
	return not item.is_empty() and (not item.has("unlock") or unlocked.has(id))


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't save the profile to %s." % path)
		return
	file.store_string(JSON.stringify({
		"high_scores": high_scores,
		"infinite_scores": infinite_scores,
		"isles_scores": isles_scores,
		"unlocked": unlocked,
		"runs_finished": runs_finished,
		"rival_beaten": rival_beaten,
	}, "\t"))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Couldn't read the profile, so it starts fresh.")
		return
	runs_finished = maxi(int(_number(data.get("runs_finished"))), 0)
	var raw_unlocked: Variant = data.get("unlocked")
	if raw_unlocked is Array:
		for id: Variant in raw_unlocked:
			if not Items.by_id(str(id)).is_empty() and not unlocked.has(str(id)):
				unlocked.append(str(id))
	_read_scores(data.get("high_scores"), high_scores)
	_read_scores(data.get("infinite_scores"), infinite_scores)
	for entry: Dictionary in infinite_scores:
		entry["sets"] = maxi(int(_number(entry.get("sets"))), 1)
		entry["bosses"] = maxi(int(_number(entry.get("bosses"))), 0)
	var raw_isles: Variant = data.get("isles_scores")
	if raw_isles is Array:
		# Saves from when there was only the one course, which was 4000 yards.
		_read_isles_scores(raw_isles, isles_table(IslesGenerator.DEFAULT_YARDS))
	elif raw_isles is Dictionary:
		for yards: int in IslesGenerator.COURSE_YARDS:
			_read_isles_scores(raw_isles.get(str(yards)), isles_table(yards))
	# Saves from before this was kept can still tell from their scores.
	var raw_beaten: Variant = data.get("rival_beaten")
	rival_beaten = raw_beaten is bool and raw_beaten
	for entry: Dictionary in high_scores:
		if int(entry["ending"]) == RunState.Ending.BEAT_RIVAL:
			rival_beaten = true


func _read_scores(raw: Variant, table: Array[Dictionary]) -> void:
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary and table.size() < MAX_SCORES:
				var score: Dictionary = entry
				score["score"] = int(_number(entry.get("score")))
				score["ending"] = clampi(int(_number(entry.get("ending"))), 0, RunState.Ending.GAVE_UP)
				score["to_par"] = int(_number(entry.get("to_par")))
				table.append(score)
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))


func _read_isles_scores(raw: Variant, table: Array) -> void:
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary and table.size() < MAX_SCORES:
				var strokes: int = int(_number(entry.get("strokes")))
				if strokes >= 1:
					table.append({ "strokes": strokes, "falls": maxi(int(_number(entry.get("falls"))), 0) })
	table.sort_custom(_isles_score_is_better)


static func _number(value: Variant) -> float:
	return float(value) if value is float or value is int else 0.0
