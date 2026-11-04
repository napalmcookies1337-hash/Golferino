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
var unlocked: Array[String] = []
var runs_finished: int = 0


## Tests pass their own path, so they never touch the player's scores.
func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
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
	var place: int = 0
	var inserted: bool = false
	for i in high_scores.size():
		if entry["score"] > int(high_scores[i]["score"]):
			high_scores.insert(i, entry)
			inserted = true
			place = i + 1
			break
	if not inserted and high_scores.size() < MAX_SCORES:
		high_scores.append(entry)
		place = high_scores.size()
	if high_scores.size() > MAX_SCORES:
		high_scores.resize(MAX_SCORES)

	var new_items: Array[String] = []
	if run.is_finished_run():
		runs_finished += 1
		var count: int = UNLOCKS_FOR_WINNING if run.ending == RunState.Ending.BEAT_RIVAL else UNLOCKS_FOR_FINISHING
		for id in Items.unlock_order():
			if count <= 0:
				break
			if not unlocked.has(id):
				unlocked.append(id)
				new_items.append(str(Items.by_id(id)["name"]))
				count -= 1
	save()
	return { "place": place, "unlocked": new_items }


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't save the profile to %s." % path)
		return
	file.store_string(JSON.stringify({
		"high_scores": high_scores,
		"unlocked": unlocked,
		"runs_finished": runs_finished,
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
	var raw_scores: Variant = data.get("high_scores")
	if raw_scores is Array:
		for entry: Variant in raw_scores:
			if entry is Dictionary and high_scores.size() < MAX_SCORES:
				high_scores.append({
					"score": int(_number(entry.get("score"))),
					"ending": clampi(int(_number(entry.get("ending"))), 0, RunState.Ending.GAVE_UP),
					"to_par": int(_number(entry.get("to_par"))),
				})
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))


static func _number(value: Variant) -> float:
	return float(value) if value is float or value is int else 0.0
