tool
extends Resource
class_name Map

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD, POWER_UP, POI}

# Tiles that are valid pathfinding waypoints (but not necessarily walkable
# through by the players).
const _WAYPOINT_BLOCKS = [
	BLOCK_TYPE.NONE,
	BLOCK_TYPE.GOLD,
	BLOCK_TYPE.POWER_UP,
	BLOCK_TYPE.POI
]

signal map_changed

export var cols: int setget __set_cols
export var rows: int setget __set_rows

var map: PoolByteArray

var __a_star

func _get_property_list():
	return [
		# explicitly define the `map` property usage for serialization only,
		# without showing in the editor
		{
			name = "map",
			type = TYPE_RAW_ARRAY,
			usage = PROPERTY_USAGE_STORAGE
		}
	]

func get_tile(coord: Vector2) -> int:
	var idx = get_tile_index(coord)
	if idx >= 0:
		return map[idx]
	return -1

func set_tile(coord: Vector2, type: int):
	__set_tile(coord, type)
	emit_signal("map_changed", [coord])

func tiles_count() -> int:
	return cols * rows

func get_tile_index(coord: Vector2) -> int:
	if coord.x >= 0 and coord.x < cols and coord.y >= 0 and coord.y < rows:
		return int(coord.y * cols + coord.x)
	return -1

func get_tile_coord(index: int) -> Vector2:
	return Vector2(index % cols, index / cols)

func get_neighbors(coord: Vector2) -> Array:
	var result = []
	if coord.x > 0:
		result.append(Vector2(coord.x - 1, coord.y))
	if coord.y > 0:
		result.append(Vector2(coord.x, coord.y - 1))
	if coord.x < cols - 1:
		result.append(Vector2(coord.x + 1, coord.y))
	if coord.y < rows - 1:
		result.append(Vector2(coord.x, coord.y + 1))

	return result

func find_path(tile_from: int, tile_to: int) -> PoolIntArray:
	assert(not Engine.editor_hint, "find_path() cannot be run in the editor!")

	return __a_star.get_id_path(tile_from, tile_to)

func set_size(c, r):
	if not Engine.editor_hint:
		__a_star.clear()

	cols = c
	rows = r
	map.resize(rows * cols)
	for i in range(rows * cols):
		map[i] = BLOCK_TYPE.NONE

	var coords = []
	for i in range(cols * rows):
		coords.append(get_tile_coord(i))

	emit_signal("map_changed", coords)

func _init():
	map = PoolByteArray([])

	if not Engine.editor_hint:
		__a_star = AStar.new()

func __set_cols(c):
	set_size(c, rows)

func __set_rows(r):
	set_size(cols, r)

func __set_tile(coord: Vector2, type: int):
	var idx = get_tile_index(coord)
	if idx >= 0:
		map.set(idx, type)

		if Engine.editor_hint:
			# Do not execute the A* updating code if we're running in the editor
			return

		# Update the A* waypoints configuration to reflect the tile's new type
		if type in _WAYPOINT_BLOCKS:
			__a_star.add_point(idx, Vector3(coord.x, 0, coord.y))
		elif not (type in _WAYPOINT_BLOCKS) and __a_star.has_point(idx):
			__a_star.remove_point(idx)

		# Update the A* connections to neighbors, based on the tile's new type
		for neighbor in get_neighbors(coord):
			var neighbor_idx = get_tile_index(neighbor)
			if __a_star.has_point(idx) and __a_star.has_point(neighbor_idx):
				if map[idx] in _WAYPOINT_BLOCKS and map[neighbor_idx] in _WAYPOINT_BLOCKS:
					__a_star.connect_points(idx, neighbor_idx, true)
				else:
					__a_star.disconnect_points(idx, neighbor_idx, true)
