class_name RunState
extends RefCounted
## Everything that lasts for one run: the stroke budget, coins, what the player owns, the
## shop's stock and the final score. Knows nothing about nodes or drawing.

const START_SPARE := 8
const STICKERS_PER_CLUB := 3
const SHOP_SHELVES := 4
## What everything costs in the first shop.
const START_PRICE := 3

## Coins for completing a hole, whatever the score. They rise from this hole number on.
const PAYOUT_EARLY := 3
const PAYOUT_LATE := 5
const PAYOUT_LATE_FROM_HOLE := 4

const SCORE_PER_HOLE := 100
const SCORE_PER_UNDER_PAR := 100
const SCORE_PER_SPARE := 50
const SCORE_PER_COIN := 2
const SCORE_RIVAL_BEATEN := 1000

enum Ending { NONE, BEAT_RIVAL, LOST_TO_RIVAL, OUT_OF_STROKES, GAVE_UP }

var course: CourseRun
var rng := RandomNumberGenerator.new()
var spare: int = START_SPARE
var coins: int = 0
## Stickers on each club, by club id, in the order they went on.
var stickers: Dictionary = { "driver": [], "iron": [], "putter": [] }
var ball_id: String = ""
var perks: Array[String] = []
var ending: int = Ending.NONE
## This hole's coins so far, for its summary.
var hole_pickups: int = 0
var hole_tricks: int = 0

var _base_clubs: Array[ClubData] = []
var _unlocked: Array[String] = []
var _net_used: bool = false


func _init(p_course: CourseRun, base_clubs: Array[ClubData], unlocked: Array[String] = [], p_seed: int = -1) -> void:
	course = p_course
	_base_clubs = base_clubs
	_unlocked = unlocked
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()


## The bag as it plays right now, with stickers on.
func clubs() -> Array[ClubData]:
	var result: Array[ClubData] = []
	for base in _base_clubs:
		result.append(Items.club_with_stickers(base, stickers.get(base.id, [])))
	return result


## Spare strokes left partway through a hole.
func live_spare(strokes: int, par: int) -> int:
	return spare - maxi(strokes - par, 0)


## The stroke that uses up the last spare. Its ball still plays out, and sinking it is a save.
func stroke_limit(par: int) -> int:
	return par + spare


func begin_hole() -> void:
	hole_pickups = 0
	hole_tricks = 0


func perk_number(key: String, fallback: float) -> float:
	for id in perks:
		var effects: Dictionary = Items.by_id(id)["effects"]
		if effects.has(key):
			return float(effects[key])
	return fallback


func collect_coin() -> int:
	var value: int = int(perk_number("coin_value", 1.0))
	coins += value
	hole_pickups += value
	return value


## Trick shots only pay with the Showman perk. Returns what this one paid.
func collect_trick(base_coins: int) -> int:
	var value: int = base_coins * int(perk_number("trick", 0.0))
	coins += value
	hole_tricks += value
	return value


## Scores a holed-out hole and returns its summary for the screen.
func finish_hole(strokes: int) -> Dictionary:
	var par: int = course.current_hole().par
	course.record_score(strokes)
	var banked: int = par - strokes
	spare += banked
	var payout: int = hole_payout(course.hole_index, strokes, par)
	coins += payout
	return { "payout": payout, "pickups": hole_pickups, "tricks": hole_tricks, "banked": banked }


## One line saying what a hole earned, naming only the sources that paid.
static func coins_text(summary: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var total: int = 0
	for source: Array in [["payout", "FOR HOLE"], ["pickups", "PICKED UP"], ["tricks", "TRICKS"]]:
		var amount: int = int(summary[source[0]])
		total += amount
		if amount > 0:
			parts.append("%d %s" % [amount, source[1]])
	return "+%d COINS: %s" % [total, ", ".join(parts)]


## Settles the budget for a hole that was never holed. It doesn't go on the scorecard.
func leave_hole_unfinished(strokes: int) -> void:
	spare = live_spare(strokes, course.current_hole().par)


## What completing a hole pays, from its place in the course (0 is the first hole). The
## score only matters to the perks that pay for it.
func hole_payout(hole_index: int, strokes: int, par: int) -> int:
	var payout: int = PAYOUT_EARLY if hole_index + 1 < PAYOUT_LATE_FROM_HOLE else PAYOUT_LATE
	if strokes == par:
		payout += int(perk_number("par_bonus", 0.0))
	elif strokes < par:
		payout += int(perk_number("under_par_bonus", 0.0))
	return payout


## Uses the Safety Net if there's one left, returning the strokes it gives back.
func use_safety_net() -> int:
	var amount: int = int(perk_number("safety_net", 0.0))
	if amount <= 0 or _net_used:
		return 0
	_net_used = true
	spare += amount
	return amount


# --- The shop ---

## Everything starts at the same low price and climbs to its full price by the last shop.
func price_of(item: Dictionary) -> int:
	var last_shop: int = maxi(course.hole_count() - 2, 1)
	var progress: float = clampf(float(course.hole_index) / float(last_shop), 0.0, 1.0)
	var price: float = lerpf(float(START_PRICE), float(item["price"]), progress)
	return maxi(roundi(price * perk_number("prices", 1.0)), 1)


func can_afford(item: Dictionary) -> bool:
	return coins >= price_of(item)


## A fresh, random, mixed stock: two stickers, then one ball, perk or strokes, then anything.
func roll_stock() -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	var slots: Array = [
		[Items.KIND_STICKER],
		[Items.KIND_STICKER],
		[Items.KIND_BALL, Items.KIND_PERK, Items.KIND_STROKES],
	]
	var total: int = SHOP_SHELVES + int(perk_number("shelves", 0.0))
	while slots.size() < total:
		slots.append([Items.KIND_STICKER, Items.KIND_BALL, Items.KIND_PERK, Items.KIND_STROKES])
	for kinds: Array in slots:
		var item: Dictionary = _random_item(kinds, stock)
		if not item.is_empty():
			stock.append(item)
	return stock


func _random_item(kinds: Array, taken: Array[Dictionary]) -> Dictionary:
	var pool: Array[Dictionary] = []
	for item: Dictionary in Items.CATALOG:
		if kinds.has(item["kind"]) and _is_for_sale(item) and not taken.has(item):
			pool.append(item)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


func _is_for_sale(item: Dictionary) -> bool:
	if item.has("unlock") and not _unlocked.has(str(item["id"])):
		return false
	return item["id"] != ball_id and not perks.has(str(item["id"]))


## Buys anything except a sticker, which needs a club. Returns false if it can't be afforded.
func buy(item: Dictionary) -> bool:
	if not can_afford(item) or item["kind"] == Items.KIND_STICKER:
		return false
	coins -= price_of(item)
	match str(item["kind"]):
		Items.KIND_BALL:
			ball_id = str(item["id"])
		Items.KIND_PERK:
			perks.append(str(item["id"]))
		Items.KIND_STROKES:
			spare += int(item["effects"]["strokes"])
	return true


func club_is_full(club_id: String) -> bool:
	return (stickers[club_id] as Array).size() >= STICKERS_PER_CLUB


## Buys a sticker onto a club. On a full club it replaces the one at replace_slot, which is lost.
func buy_sticker(item: Dictionary, club_id: String, replace_slot: int = -1) -> bool:
	if not can_afford(item) or not (item.get("clubs", []) as Array).has(club_id):
		return false
	var on_club: Array = stickers[club_id]
	if club_is_full(club_id):
		if replace_slot < 0 or replace_slot >= on_club.size():
			return false
		on_club[replace_slot] = str(item["id"])
	else:
		on_club.append(str(item["id"]))
	coins -= price_of(item)
	return true


# --- The end of the run ---

## The scorecard's rows and total. Unfinished holes don't count for or against par.
func final_score() -> Dictionary:
	var finished: int = course.scores.size()
	var under_par: int = -course.total_to_par()
	var left_over: int = maxi(spare, 0)
	var rows: Array[Dictionary] = [
		{ "label": "HOLES PLAYED %d" % finished, "points": finished * SCORE_PER_HOLE },
		{ "label": "PAR %s" % CourseRun.to_par_text(-under_par), "points": under_par * SCORE_PER_UNDER_PAR },
		{ "label": "SPARE STROKES %d" % left_over, "points": left_over * SCORE_PER_SPARE },
		{ "label": "COINS LEFT %d" % coins, "points": coins * SCORE_PER_COIN },
	]
	if ending == Ending.BEAT_RIVAL:
		rows.append({ "label": "BEAT THE RIVAL", "points": SCORE_RIVAL_BEATEN })
	var total: int = 0
	for row in rows:
		total += int(row["points"])
	return { "rows": rows, "total": maxi(total, 0) }


func is_finished_run() -> bool:
	return ending == Ending.BEAT_RIVAL or ending == Ending.LOST_TO_RIVAL
