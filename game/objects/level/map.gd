extends Object
class_name Map

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD, POWER_UP}

const _WAYPOINT_BLOCKS = [BLOCK_TYPE.NONE, BLOCK_TYPE.GOLD, BLOCK_TYPE.POWER_UP]

signal map_changed

var __cols: int = 0
var __rows: int = 0
var __map
var __a_star

func get_tile(coord: Vector2) -> int:
	var idx = get_tile_index(coord)
	if idx >= 0:
		return __map[idx]
	return -1

func set_tile(coord: Vector2, type: int):
	__set_tile(coord, type)
	emit_signal("map_changed", [coord])

func tiles_count() -> int:
	return __cols * __rows

func get_cols() -> int:
	return __cols

func get_rows() -> int:
	return __rows

func get_tile_index(coord: Vector2) -> int:
	if coord.x >= 0 and coord.x < __cols and coord.y >= 0 and coord.y < __rows:
		return int(coord.y * __cols + coord.x)
	return -1

func get_tile_coord(index: int) -> Vector2:
	return Vector2(index % __cols, index / __cols)

func get_neighbors(coord: Vector2) -> Array:
	var result = []
	if coord.x > 0:
		result.append(Vector2(coord.x - 1, coord.y))
	if coord.y > 0:
		result.append(Vector2(coord.x, coord.y - 1))
	if coord.x < __cols - 1:
		result.append(Vector2(coord.x + 1, coord.y))
	if coord.y < __rows - 1:
		result.append(Vector2(coord.x, coord.y + 1))

	return result

func find_path(tile_from: int, tile_to: int) -> PoolIntArray:
	assert(not Engine.editor_hint, "find_path() cannot be run in the editor!")

	return __a_star.get_id_path(tile_from, tile_to)

func set_size(cols: int, rows: int):
	if not Engine.editor_hint:
		__a_star.clear()

	__cols = cols
	__rows = rows
	__map.resize(rows * cols)
	__populate()

	var coords = []
	for i in range(cols * rows):
		coords.append(get_tile_coord(i))

	emit_signal("map_changed", coords)

func _init():
	__map = PoolByteArray([])

	if not Engine.editor_hint:
		__a_star = AStar.new()

func __populate():
	var coords = []
	for r in range(__rows):
		for c in range(__cols):
			var coord = Vector2(c, r)
			coords.append(coord)

			if (r % 2 and c % 2) or c == 0 or r == 0 or c == __cols - 1 or r == __rows - 1:
				__set_tile(coord, BLOCK_TYPE.ROCK)
			else:
				__set_tile(coord, BLOCK_TYPE.SOIL)

func __set_tile(coord: Vector2, type: int):
	var idx = get_tile_index(coord)
	if idx >= 0:
		__map.set(idx, type)

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
				if __map[idx] in _WAYPOINT_BLOCKS and __map[neighbor_idx] in _WAYPOINT_BLOCKS:
					__a_star.connect_points(idx, neighbor_idx, true)
				else:
					__a_star.disconnect_points(idx, neighbor_idx, true)
