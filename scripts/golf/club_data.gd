class_name ClubData
extends Resource
## One club's base stats. Stickers will modify copies of these numbers.

@export var id: String = ""
@export var display_name: String = ""
## Launch speed at full power, px/s.
@export var max_speed: float = 250.0
## The angle a shot starts at. The player can change it within the limits below.
@export var loft_deg: float = 45.0
@export var min_angle_deg: float = 15.0
@export var max_angle_deg: float = 75.0
## How much spin this club can put on the ball.
@export var spin_strength: float = 1.0
## How badly bad lies hurt its range. 1 takes the surface's penalty as listed.
@export var lie_sensitivity: float = 1.0
## Putters roll along the ground instead of launching.
@export var is_putter: bool = false
## Length of the club in the golfer drawing, px.
@export var draw_length: float = 13.0

# Stickers change these on the run's own copy of the club.
## Size of the meter's sweet spot.
var window_scale: float = 1.0
## How fast the meter runs.
var meter_speed: float = 1.0
## How badly a mistimed swing hurts.
var miss_scale: float = 1.0
## How strongly the cup pulls in a ball hit with this club.
var cup_pull_scale: float = 1.0
