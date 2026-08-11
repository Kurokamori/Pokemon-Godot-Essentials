@tool
class_name MapConnection
extends Resource

## A join between a single edge of two maps.
##
## This connection declares that the named edge of one map is the same edge as the enamed edge of another map,
## and which tile along each edge the two share.
##
## That is enough to place either map relative to another, which allows for overworld stitching.
##
## The two offsets are dead along the shared edge 
## a column for a north or south edge and a row for an east or west one
## both are in their own map's cells, so neither map has to know how big the other is.

enum Edge {
	NORTH,
	SOUTH,
	WEST,
	EAST
}

## This is for compatibility with the original Essentials shape, the letter which essentials writes an edge as,
## indexed by [enum Edge]
const EDGE_LETTERS: Array[String] = ["N", "S", "W", "E"]

@export var map_id: int = 0
@export var edge: Edge = Edge.NORTH

## The column (North/South) or row (East/West) on [memeber map_id]'s edge that is shared with [member target_offset] on the other map.
@export var offset: int = 0

@export var target_map_id: int = 0
@export var target_edge: Edge = Edge.SOUTH
@export var target_offset: int = 0

# === Edge Names ===

static func edge_from_letter(letter: String) -> Edge:
	match letter.strip_edges().to_upper():
		"N": return Edge.NORTH
		"S": return Edge.SOUTH
		"W": return Edge.WEST
		"E": return Edge.EAST
	return Edge.NORTH
	
static func letter_for_edge(which: Edge) -> String:
	return EDGE_LETTERS[int(which)]
	
static func opposite_edge(which: Edge) -> Edge:
	match which:
		Edge.NORTH: return Edge.SOUTH
		Edge.SOUTH: return Edge.NORTH
		Edge.WEST: return Edge.EAST
		Edge.EAST: return Edge.WEST
	return Edge.NORTH
	
## `true` for the horizontal edges, whose offsets are columns rather than rows.
static func is_horizontal_edge(which: Edge) -> bool:
	return which == Edge.NORTH or which == Edge.SOUTH
	
## The edge of [param from] that faces [param to] when [param to] is at [param placement] cells away
## returns `-1` when the two do not share an edge.
static func edge_towards(placement: Vector2i, from: Vector2i, to: Vector2i) -> int:
	if placement.y + to.y == 0 and placement.x < from.x and placement.x + to.x > 0:
		return Edge.NORTH
	if placement.y == from.y and placement.x < from.x and placement.x + to.x > 0:
		return Edge.SOUTH
	if placement.x + to.x == 0 and placement.y < from.y and placement.y + to.y > 0:
		return Edge.WEST
	if placement.x == from.x and placement.y < from.y and placement.y + to.y > 0:
		return Edge.EAST
	return -1
	
# === Geometry ===
## `true` when this connection names two maps and joins facing edges.
##
## Two maps can only be joined by a set of edges that 'look at eachother'
## (A north edge must meet a south one for example)
## Anything else is a mistake and [method problem] will say which.
func is_well_formed() -> bool:
	return problem().is_empty()
	
## What is wrong with this connection or returns an empty string when nothing is.
func problem() -> String:
	if map_id <= 0 or target_map_id <= 0:
		return "a connection needs two map numbers"
	if map_id == target_map_id:
		return "map %d is connected to itself" % map_id
	if target_edge != opposite_edge(edge):
		return "map %d's %s edge cannot meet map %d's %s edge" % [
			map_id, letter_for_edge(edge), target_map_id, letter_for_edge(target_edge),
		]
	return ""
	
## returns `true` when [param id] is one of the two maps this connection joins.
func joins(id: int) -> bool:
	return id == map_id or id == target_map_id
	
## Which map is on the other side of the connection from [param id], pr `0`.
func other_map(id: int) -> int:
	if id == map_id:
		return target_map_id
	if id == target_map_id:
		return map_id
	return 0
	
## The edge of the [param id] which this conenction leaves by.
func edge_of(id: int) -> Edge:
	return edge if id == map_id else target_edge
	
## The offset along [param id]'s edge.
func offset_of(id: int) -> int:
	return offset if id == map_id else target_offset
	
## Where the map on the other side of this connection sits, in cells, which are measured from
## the top left corner of [param id].
##
## [param from_size] is the size of [param id] and [param to_size] is the size of the map being placed.
## Both are needed as a map is placed by the edge it meets, whcih is its far side in two of the four directions.
func placement_from(id: int, from_size: Vector2i, to_size: Vector2i) -> Vector2i:
	var here: Edge = edge_of(id)
	var along: int = offset_of(id) - offset_of(other_map(id))
	match here:
		Edge.NORTH: return Vector2i(along, -to_size.y)
		Edge.SOUTH: return Vector2i(along, from_size.y)
		Edge.WEST: return Vector2i(-to_size.x, along)
		Edge.EAST: return Vector2i(from_size.x, along)
	return Vector2i.ZERO
	
## Reads the connection back from a placement to be used in editor atlas.
##
## [param placement] is where [param to_map_id] sits relative to [param from_map_id] in cells.
## Returns `false` when the two rectangles do not actually share an edge, which leaves the connection untouched.
func set_from_placement(
	from_map_id: int, from_size: Vector2i,
	to_map_id: int, to_size: Vector2i,
	placement: Vector2i
) -> bool:
	var which: int = edge_towards(placement, from_size, to_size)
	if which < 0:
		return false
	var side: Edge = which as Edge
	map_id = from_map_id
	edge = side
	target_map_id = to_map_id
	target_edge = opposite_edge(side)
	if is_horizontal_edge(side):
		offset = maxi(placement.x, 0)
		target_offset = maxi(-placement.x, 0)
	else:
		offset = maxi(placement.y, 0)
		target_offset = maxi(-placement.y, 0)
	return true
	
func describe() -> String:
	return "%d %s %d <-> %d %s %d" % [
		map_id, letter_for_edge(edge), offset,
		target_map_id, letter_for_edge(target_edge), target_offset,
	]
