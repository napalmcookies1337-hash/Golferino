class_name VolumeRow
extends RefCounted
## The music and sound level rows, shared by the title and pause menus.

const PIP_WIDTH := 5.0
const PIP_GAP := 2.0
const PIP_HEIGHT := 9.0
const LABEL_WIDTH := 72.0
const ON := Color("ffe25a")
const ON_IDLE := Color("f7f4e6")
const OFF := Color(1.0, 1.0, 1.0, 0.2)
const SIZE := 2


static func total_width() -> float:
	return LABEL_WIDTH + float(Sound.LEVELS) * (PIP_WIDTH + PIP_GAP)


## Draws "MUSIC" and its row of pips, centered on a point.
static func draw(canvas: CanvasItem, label: String, level: int, center_x: float, y: float, selected: bool) -> void:
	var left: float = round(center_x - total_width() / 2.0)
	var color: Color = ON if selected else ON_IDLE
	PixelFont.draw_shadowed(canvas, label, Vector2(left, y), color, SIZE)
	if selected:
		PixelFont.draw_shadowed(canvas, ">", Vector2(left - 20.0, y), ON, SIZE)
	for i in Sound.LEVELS:
		var x: float = left + LABEL_WIDTH + float(i) * (PIP_WIDTH + PIP_GAP)
		canvas.draw_rect(Rect2(x + 1.0, y + 3.0, PIP_WIDTH, PIP_HEIGHT), Color(0, 0, 0, 0.45))
		canvas.draw_rect(Rect2(x, y + 2.0, PIP_WIDTH, PIP_HEIGHT), color if i < level else OFF)


## Moves one level up or down. A level of the sound itself plays, so it can be judged.
static func change_music(direction: int) -> void:
	Sound.set_music_level(Sound.music_level + direction)
	Sound.sfx("menu_move")


static func change_sfx(direction: int) -> void:
	Sound.set_sfx_level(Sound.sfx_level + direction)
	Sound.sfx("coin")


## The level a click on the row asks for, or a negative number if it missed the pips.
static func level_at(click_x: float, center_x: float) -> int:
	var left: float = round(center_x - total_width() / 2.0) + LABEL_WIDTH
	var spot: float = (click_x - left) / (PIP_WIDTH + PIP_GAP)
	if spot < -1.0 or spot > float(Sound.LEVELS):
		return -1
	return clampi(int(ceil(spot)), 0, Sound.LEVELS)
