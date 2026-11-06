class_name HoleData
extends Resource
## One hole, described entirely as data. New holes need no new code.

const BIOME_GRASSY := "grassy"
const BIOME_SWAMP := "swamp"

@export var display_name: String = "HOLE"
## Which world the hole belongs to. Sets how it looks and sounds, not how it plays: everything
## that changes play is in its surfaces and obstacles.
@export var biome: String = BIOME_GRASSY
@export var par: int = 4
@export var tee_x: float = 90.0
@export var cup_x: float = 1000.0
## Terrain outline, sorted by x. y points down.
@export var points: PackedVector2Array = PackedVector2Array()
## Each entry: { "from": x, "to": x, "type": Surface.Type }. Unlisted ground is rough.
@export var surface_spans: Array = []
## Each entry: { "from": x, "to": x, "level": y }. Ground below level in range floods.
@export var water_spans: Array = []
## Each entry: { "from": x, "to": x }. Nothing there but sky: a floating hole's gaps. Any
## ground left between them is an island, with an underside of its own.
@export var void_spans: Array = []
## Where a checkpoint's flag stands, and where its island starts. Below zero means no checkpoint.
@export var checkpoint_x: float = -1.0
@export var checkpoint_from: float = -1.0
## Tree pieces, which are scenery and have no effect on the ball. Each entry has a "kind"
## ("trunk" or "leaves"), an "x", and a "height" above the ground there: the base of a
## trunk, or the middle of the leaves. Leaves also have a "variant" for their shape.
@export var scenery: Array = []
## Each entry has a "kind" (cart, windmill, sprinkler, goose, pad) plus that kind's settings.
@export var obstacles: Array = []
## Sideways push on the ball in the air. Positive blows toward the far end of the hole.
@export var wind: float = 0.0
## Shown when the hole starts.
@export var title: String = ""
