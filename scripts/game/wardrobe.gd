class_name Wardrobe
extends RefCounted
## Everything the golfer can wear. Each model has its own five colors, and every kind of
## clothing comes in all five, so a color is a full matching outfit. The first color is free,
## the next two cost coins, and the last two are earned. Looks only: nothing here changes how
## the game plays.

const MALE := "male"
const FEMALE := "female"
const MODELS := [MALE, FEMALE]

const SHIRT := "shirt"
const BOTTOMS := "bottoms"
const SHOES := "shoes"
const HAT := "hat"
const SLOTS := [SHIRT, BOTTOMS, SHOES, HAT]

const PRICE := 15
## Every save starts with this in its wallet, new or from before there was one.
const STARTING_WALLET := 50

## What opens the earned colors.
const UNLOCK_RIVAL := "rival"
const UNLOCK_ISLES := "isles_4000"
const UNLOCK_TEXT := {
	UNLOCK_RIVAL: "BEAT THE RIVAL TO UNLOCK",
	UNLOCK_ISLES: "FINISH THE 4000 YARD ISLES TO UNLOCK",
}
## The Floating Isles course that opens gold.
const UNLOCK_ISLES_YARDS := 4000

const SLOT_NAMES := {
	MALE: { SHIRT: "SHIRT", BOTTOMS: "PANTS", SHOES: "SHOES", HAT: "CAP" },
	FEMALE: { SHIRT: "SHIRT", BOTTOMS: "SKIRT", SHOES: "SHOES", HAT: "VISOR" },
}
const HAIR := { MALE: Color("5a3a26"), FEMALE: Color("9a4f2c") }

## Each model's colors, in the order they're shown: [name, color, its shade, how it's had].
## The same color goes on every piece. How it's had is "" for coins (or free, if first), or
## what unlocks it.
const COLORS := {
	MALE: [
		["WHITE", "f2efe4", "c8c5b8", ""],
		["RED", "e8584a", "b83d3f", ""],
		["BLUE", "3f7fd0", "2c5b9c", ""],
		["BLACK", "363640", "26262e", UNLOCK_RIVAL],
		["GOLD", "e3b53a", "b08a26", UNLOCK_ISLES],
	],
	FEMALE: [
		["WHITE", "f2efe4", "c8c5b8", ""],
		["CORAL", "ff8a7a", "d9655a", ""],
		["SKY", "7ac8e8", "559fbd", ""],
		["BLACK", "363640", "26262e", UNLOCK_RIVAL],
		["GOLD", "e3b53a", "b08a26", UNLOCK_ISLES],
	],
}


## The five pieces of one kind for one model, in the order of their colors.
static func items_for(model: String, slot: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var colors: Array = COLORS[model]
	for i in colors.size():
		var color: Array = colors[i]
		var unlock: String = str(color[3])
		items.append({
			"id": "%s_%s_%s" % [model, slot, str(color[0]).to_lower()],
			"model": model,
			"slot": slot,
			"name": "%s %s" % [color[0], SLOT_NAMES[model][slot]],
			"main": Color(str(color[1])),
			"dark": Color(str(color[2])),
			"price": 0 if i == 0 or unlock != "" else PRICE,
			"unlock": unlock,
		})
	return items


## Empty if no such piece exists, which a damaged or older save could ask for.
static func by_id(id: String) -> Dictionary:
	for model: String in MODELS:
		for slot: String in SLOTS:
			for item: Dictionary in items_for(model, slot):
				if item["id"] == id:
					return item
	return {}


## What a save with nothing bought wears: maps each slot to a piece's id.
static func starting_clothes(model: String) -> Dictionary:
	var clothes: Dictionary = {}
	for slot: String in SLOTS:
		clothes[slot] = str(items_for(model, slot)[0]["id"])
	return clothes


## What a piece from before the clothes were reworked cost, so it can be paid back. Those
## were named by number, or by design.
static func old_price(id: String) -> int:
	if not by_id(id).is_empty():
		return 0
	if id.ends_with("_checkered") or id.ends_with("_striped"):
		return 40
	var parts: PackedStringArray = id.split("_")
	if parts.size() != 3 or not MODELS.has(parts[0]) or not parts[2].is_valid_int():
		return 0
	var optional: bool = parts[1] == "gloves" or parts[1] == "glasses"
	return PRICE if optional or int(parts[2]) > 0 else 0
