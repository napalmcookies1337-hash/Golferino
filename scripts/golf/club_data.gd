class_name ClubData
extends Resource
## One club's base stats. Stickers will modify copies of these numbers.

@export var id: String = ""
@export var display_name: String = ""
## Launch speed at full power, px/s.
@export var max_speed: float = 250.0
@export var loft_deg: float = 45.0
## Putters roll along the ground instead of launching.
@export var is_putter: bool = false
## Length of the club in the golfer drawing, px.
@export var draw_length: float = 13.0
