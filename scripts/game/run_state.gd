class_name RunState
extends RefCounted
## Everything that lasts for one run: the stroke budget, coins, what the player owns, the
## shop's stock and the final score. Knows nothing about nodes or drawing.

const START_SPARE := 8
## Infinite mode: spare strokes banked after a boss, divided by this, is the coins paid.
const COINS_PER_BANKED_STROKE_DIVISOR := 2
const STICKERS_PER_CLUB := 3
## How many of the same sticker can share one slot on a club.
const MAX_STACK := 3
const SHOP_SHELVES := 4
## What everything costs in the first shop.
const START_PRICE := 3
## A shop's first reroll costs this, and each one after it costs double. Nothing discounts it.
const REROLL_START_PRICE := 3

## Coins for completing a hole, whatever the score. They rise from this hole number on.
const PAYOUT_EARLY := 3
const PAYOUT_LATE := 5
const PAYOUT_LATE_FROM_HOLE := 4
## Paid on top for a hole in one, with or without any perks.
const HOLE_IN_ONE_BONUS := 8
const BALL_SLOTS := 3

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
## The ball in play. An empty id is the plain ball.
var ball_id: String = ""
## The balls being carried, which is what the shop swaps between.
var balls: Array[String] = [""]
var perks: Array[String] = []
var ending: int = Ending.NONE
## True in infinite mode, where beating a boss leads to another set of holes.
var infinite: bool = false
## Which set this is. The main game is one set.
var set_number: int = 1
## How hard the run is now, from 0 up to Difficulty.MAX_LEVEL. The main game stays at 0.
var level: int = 0
var bosses_beaten: int = 0
## True once a rival's been beaten with more of the run still to come.
var rival_beaten_with_more_to_come: bool = false
## This hole's coins so far, for its summary.
var hole_pickups: int = 0
var hole_tricks: int = 0
## Rerolls used in the shop that's open.
var shop_rerolls: int = 0

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
	rival_beaten_with_more_to_come = false


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
	var ace: int = HOLE_IN_ONE_BONUS if strokes == 1 else 0
	coins += payout + ace
	return { "payout": payout, "ace": ace, "pickups": hole_pickups, "tricks": hole_tricks, "banked": banked }


## One line saying what a hole earned, naming only the sources that paid.
static func coins_text(summary: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var total: int = 0
	for source: Array in [["payout", "FOR HOLE"], ["ace", "ACE"], ["pickups", "PICKED UP"], ["tricks", "TRICKS"]]:
		var amount: int = int(summary.get(source[0], 0))
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
	var early: bool = set_number == 1 and hole_index + 1 < PAYOUT_LATE_FROM_HOLE
	var payout: int = PAYOUT_EARLY if early else PAYOUT_LATE
	if strokes == par:
		payout += int(perk_number("par_bonus", 0.0))
	elif strokes < par:
		payout += int(perk_number("under_par_bonus", 0.0))
	return payout


## Infinite mode: beating a boss adds its reward to the spare strokes, cashes all of them in
## for coins, puts the budget back to the start, and raises the difficulty for the next set.
## Returns what was banked and what it paid.
func beat_boss() -> Dictionary:
	var banked: int = maxi(spare, 0) + Difficulty.boss_reward(level)
	var paid: int = banked / COINS_PER_BANKED_STROKE_DIVISOR
	coins += paid
	spare = START_SPARE
	bosses_beaten += 1
	set_number += 1
	level = mini(level + 1, Difficulty.MAX_LEVEL)
	return { "banked": banked, "coins": paid }


## The main game: beating the Grassy Greens rival leads on to Swampy Shores. Coins, gear and
## spare strokes all carry over exactly as they are. Full prices and payouts from here, like
## any later set.
func beat_first_rival() -> void:
	bosses_beaten += 1
	set_number += 1
	rival_beaten_with_more_to_come = true


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
## From the second set of infinite mode on it's full price, and difficulty adds to that.
func price_of(item: Dictionary) -> int:
	var last_shop: int = maxi(course.hole_count() - 2, 1)
	var progress: float = clampf(float(course.hole_index) / float(last_shop), 0.0, 1.0)
	if set_number > 1 or item.get("fixed_price", false):
		progress = 1.0
	var price: float = lerpf(float(START_PRICE), float(item["price"]), progress)
	return maxi(roundi(price * perk_number("prices", 1.0) * Difficulty.price_scale(level)), 1)


func can_afford(item: Dictionary) -> bool:
	return coins >= price_of(item)


## A new shop's reroll goes back to its starting price.
func begin_shop() -> void:
	shop_rerolls = 0


func reroll_price() -> int:
	return REROLL_START_PRICE << shop_rerolls


func can_reroll() -> bool:
	return coins >= reroll_price()


## Pays for a reroll and returns all new shelves, avoiding what's on them now where the items
## allow it. Returns an empty list if it can't be paid for.
func reroll_stock(current: Array[Dictionary]) -> Array[Dictionary]:
	if not can_reroll():
		return []
	coins -= reroll_price()
	shop_rerolls += 1
	return roll_stock(current)


## A fresh, random, mixed stock: two stickers, then one ball, perk or strokes, then anything.
## Items in avoid are only used if nothing else is left for a shelf.
func roll_stock(avoid: Array[Dictionary] = []) -> Array[Dictionary]:
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
		var item: Dictionary = _random_item(kinds, stock, avoid)
		if not item.is_empty():
			stock.append(item)
	return stock


func _random_item(kinds: Array, taken: Array[Dictionary], avoid: Array[Dictionary]) -> Dictionary:
	var pool: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	for item: Dictionary in Items.CATALOG:
		if kinds.has(item["kind"]) and _is_for_sale(item) and not taken.has(item):
			pool.append(item)
			if not avoid.has(item):
				fresh.append(item)
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


func _is_for_sale(item: Dictionary) -> bool:
	if item.has("unlock") and not _unlocked.has(str(item["id"])):
		return false
	var id: String = str(item["id"])
	return id != ball_id and not balls.has(id) and not perks.has(id)


func balls_full() -> bool:
	return balls.size() >= BALL_SLOTS


## Puts a ball that's being carried into play.
func equip_ball(slot: int) -> void:
	if slot >= 0 and slot < balls.size():
		ball_id = balls[slot]


## Buys anything except a sticker, which needs a club. A new ball goes straight into play,
## and once all the slots are full it replaces the one at replace_slot, which is lost.
## Returns false if it can't be bought.
func buy(item: Dictionary, replace_slot: int = -1) -> bool:
	if not can_afford(item) or item["kind"] == Items.KIND_STICKER:
		return false
	var is_ball: bool = item["kind"] == Items.KIND_BALL
	if is_ball and balls_full() and (replace_slot < 0 or replace_slot >= balls.size()):
		return false
	coins -= price_of(item)
	match str(item["kind"]):
		Items.KIND_BALL:
			ball_id = str(item["id"])
			if balls_full():
				balls[replace_slot] = ball_id
			else:
				balls.append(ball_id)
		Items.KIND_PERK:
			perks.append(str(item["id"]))
		Items.KIND_STROKES:
			spare += int(item["effects"]["strokes"])
	return true


## What's on a club, slot by slot: each { "id", "count" }. Stickers that match share a slot.
func sticker_slots(club_id: String) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for id: Variant in stickers[club_id]:
		var found: bool = false
		for slot in slots:
			if slot["id"] == str(id):
				slot["count"] = int(slot["count"]) + 1
				found = true
		if not found:
			slots.append({ "id": str(id), "count": 1 })
	return slots


func club_is_full(club_id: String) -> bool:
	return sticker_slots(club_id).size() >= STICKERS_PER_CLUB


## How many of this sticker a club already has.
func sticker_count(club_id: String, item: Dictionary) -> int:
	return (stickers[club_id] as Array).count(str(item["id"]))


## True when this sticker can't go on the club at all, since its stack is complete.
func stack_is_complete(club_id: String, item: Dictionary) -> bool:
	return sticker_count(club_id, item) >= MAX_STACK


## True when putting this sticker on the club means losing another one first.
func must_replace_for(club_id: String, item: Dictionary) -> bool:
	return club_is_full(club_id) and sticker_count(club_id, item) == 0


## Buys a sticker onto a club, stacking it on a match. A new sticker on a full club replaces
## the whole stack in replace_slot, which is lost.
func buy_sticker(item: Dictionary, club_id: String, replace_slot: int = -1) -> bool:
	if not can_afford(item) or not (item.get("clubs", []) as Array).has(club_id):
		return false
	if stack_is_complete(club_id, item):
		return false
	var id: String = str(item["id"])
	var on_club: Array = stickers[club_id]
	if must_replace_for(club_id, item):
		var slots: Array[Dictionary] = sticker_slots(club_id)
		if replace_slot < 0 or replace_slot >= slots.size():
			return false
		var lost: String = slots[replace_slot]["id"]
		var at: int = on_club.find(lost)
		while on_club.has(lost):
			on_club.erase(lost)
		on_club.insert(at, id)
	elif on_club.has(id):
		on_club.insert(on_club.rfind(id) + 1, id)
	else:
		on_club.append(id)
	coins -= price_of(item)
	return true


# --- The end of the run ---

## The scorecard's rows and total. Unfinished holes don't count for or against par.
func final_score() -> Dictionary:
	var finished: int = course.finished_holes()
	var under_par: int = -course.total_to_par()
	var left_over: int = maxi(spare, 0)
	var rows: Array[Dictionary] = [
		{ "label": "HOLES PLAYED %d" % finished, "points": finished * SCORE_PER_HOLE },
		{ "label": "PAR %s" % CourseRun.to_par_text(-under_par), "points": under_par * SCORE_PER_UNDER_PAR },
		{ "label": "SPARE STROKES %d" % left_over, "points": left_over * SCORE_PER_SPARE },
		{ "label": "COINS LEFT %d" % coins, "points": coins * SCORE_PER_COIN },
	]
	if bosses_beaten > 0:
		var beaten_label: String = "BOSSES BEATEN %d" % bosses_beaten if infinite else "BEAT THE GRASSY RIVAL"
		rows.append({ "label": beaten_label, "points": bosses_beaten * SCORE_RIVAL_BEATEN })
	if ending == Ending.BEAT_RIVAL:
		rows.append({ "label": "BEAT THE SWAMP RIVAL" if set_number > 1 else "BEAT THE RIVAL", "points": SCORE_RIVAL_BEATEN })
	var total: int = 0
	for row in rows:
		total += int(row["points"])
	return { "rows": rows, "total": maxi(total, 0) }


func is_finished_run() -> bool:
	return ending == Ending.BEAT_RIVAL or ending == Ending.LOST_TO_RIVAL
