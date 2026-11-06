class_name IslesGenerator
extends RefCounted
## Makes the Floating Isles hole: one long chain of small islands with nothing but sky between
## them, different every time. The tops are level, so what decides a shot is how far it carries
## and how much it runs on. Knows nothing about nodes or drawing.

## The lengths of course on offer, shortest first.
const COURSE_YARDS: Array[int] = [1000, 2000, 4000]
const DEFAULT_YARDS := 4000
const PIXELS_PER_YARD := 3.0
const TEE_X := 90.0
const TEE_ISLAND_FROM := 30.0
const TEE_ISLAND_TO := 170.0
const CUP_ISLAND_HALF := 130.0
const WIDTH_MIN := 110.0
const WIDTH_MAX := 210.0
const GAP_MIN := 80.0
const GAP_MAX := 340.0
const HIGHEST_Y := 200.0
const LOWEST_Y := 350.0
## From a shot's island, the next one stays clear of the panels along the bottom of the screen.
const HEIGHT_CHANGE := 55.0
## Sky past the cup's island, so an overhit falls rather than leaving by the world's edge.
const FAR_SKY := 200.0
## A point this far out from each edge keeps the island's top level right to the edge.
const EDGE_POINT := 12.0
const TREE_CHANCE := 0.4
const TREE_MIN_WIDTH := 150.0
const TREE_EDGE := 40.0
## About one good shot per hop, which is only used if a score is ever named against par.
const YARDS_PER_PAR := 130


static func generate(rng: RandomNumberGenerator, yards: int = DEFAULT_YARDS) -> HoleData:
	var hole := HoleData.new()
	hole.display_name = "FLOATING ISLES"
	hole.title = "%d YARDS TO THE HOLE" % yards
	hole.tee_x = TEE_X
	hole.cup_x = TEE_X + float(yards) * PIXELS_PER_YARD
	hole.par = yards / YARDS_PER_PAR

	var spans: Array[Vector2] = _lay_out(rng, hole.cup_x)
	var checkpoint: int = _halfway_island(spans, (hole.tee_x + hole.cup_x) / 2.0)
	hole.checkpoint_from = spans[checkpoint].x
	hole.checkpoint_x = round((spans[checkpoint].x + spans[checkpoint].y) / 2.0)
	_build(rng, hole, spans, checkpoint)
	return hole


# The island nearest halfway, leaving out the tee's and the cup's.
static func _halfway_island(spans: Array[Vector2], halfway: float) -> int:
	var best: int = 1
	var best_off: float = INF
	for i in range(1, spans.size() - 1):
		var off: float = absf((spans[i].x + spans[i].y) / 2.0 - halfway)
		if off < best_off:
			best_off = off
			best = i
	return best


# Where each island starts and ends, tee first and the cup's last. Gaps are always a size the
# clubs can carry, including the last one.
static func _lay_out(rng: RandomNumberGenerator, cup_x: float) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(TEE_ISLAND_FROM, TEE_ISLAND_TO)]
	var cup_from: float = cup_x - CUP_ISLAND_HALF
	var x: float = TEE_ISLAND_TO
	while cup_from - x > GAP_MAX:
		var left: float = cup_from - x
		var gap: float = round(rng.randf_range(GAP_MIN, GAP_MAX))
		var width: float = round(rng.randf_range(WIDTH_MIN, WIDTH_MAX))
		# Too little left over for one more gap, so this has to be the last island before the cup.
		if left - gap - width < GAP_MIN:
			width = WIDTH_MIN
			gap = clampf(gap, GAP_MIN, left - width - GAP_MIN)
		spans.append(Vector2(x + gap, x + gap + width))
		x += gap + width
	spans.append(Vector2(cup_from, cup_x + CUP_ISLAND_HALF))
	return spans


static func _build(rng: RandomNumberGenerator, hole: HoleData, spans: Array[Vector2], checkpoint: int) -> void:
	var points := PackedVector2Array()
	var variant: int = rng.randi_range(0, HoleIO.LEAF_VARIANTS - 1)
	var y: float = rng.randf_range(280.0, 320.0)
	points.append(Vector2(0.0, y))
	var sky_from: float = 0.0
	for i in spans.size():
		var span: Vector2 = spans[i]
		if i > 0:
			y = round(clampf(y + rng.randf_range(-HEIGHT_CHANGE, HEIGHT_CHANGE), HIGHEST_Y, LOWEST_Y))
		# Level on both sides of each edge, which the height curve keeps level all the way along.
		if span.x - EDGE_POINT > points[points.size() - 1].x:
			points.append(Vector2(span.x - EDGE_POINT, y))
		points.append(Vector2(span.x, y))
		points.append(Vector2(span.y, y))
		points.append(Vector2(span.y + EDGE_POINT, y))
		hole.void_spans.append({ "from": int(sky_from), "to": int(span.x) })
		sky_from = span.y + 1.0
		var kind: int = Surface.Type.FAIRWAY
		if i == 0:
			kind = Surface.Type.TEE
		elif i == spans.size() - 1:
			kind = Surface.Type.GREEN
		hole.surface_spans.append({ "from": int(span.x), "to": int(span.y) + 1, "type": kind })
		# The checkpoint's island keeps clear, so its flag stands out.
		var can_have_tree: bool = i > 0 and i < spans.size() - 1 and i != checkpoint
		if can_have_tree and span.y - span.x >= TREE_MIN_WIDTH and rng.randf() < TREE_CHANCE:
			var tree_x: float = round(rng.randf_range(span.x + TREE_EDGE, span.y - TREE_EDGE))
			hole.scenery.append_array(HoleIO.tree_pieces(tree_x, variant))
			variant = (variant + 1) % HoleIO.LEAF_VARIANTS
	var end_x: float = spans[spans.size() - 1].y + FAR_SKY
	points.append(Vector2(end_x, y))
	hole.void_spans.append({ "from": int(sky_from), "to": int(end_x) + 1 })
	hole.points = points
