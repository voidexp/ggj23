extends Spatial

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD}

signal path_state_changed

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export var col_count = 21
export var row_count = 21


class PathState extends Object:
	var p1_linked: bool
	var p2_linked: bool
	var gold: Node


var player1_root
var player1_root_id
var player1_position

var player2_root
var player2_root_id
var player2_position

var gold_position
var gold_block_id

const GROUND_THICKNESS = 0.1
const DEFAULT_Y = 0.0

var BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

var __block_types_map = []
var __a_star = AStar.new()
var __paths = {}
var __rng

func clear_block(col, row):
	__block_types_map[row][col] = BLOCK_TYPE.NONE

	var node = get_node(__get_block_name(col, row))
	if node:
		node.name = node.name + "_dead" # NOTE: a block with same name added within this tick will be mangled!
		node.queue_free()

	var curr_block_id = __get_block_id(col, row)
	__a_star.add_point(curr_block_id, Vector3(col, 0, row))

	if curr_block_id == gold_block_id:
		gold_position = null
		gold_block_id = null

	for neighbour in __get_connectable_neighbours(col, row):
		var neigbour_id = __get_block_id(neighbour.x, neighbour.y)
		__a_star.connect_points(curr_block_id, neigbour_id)

	__update_paths()

func spawn_tile(grid_pos, type, delayed=true):
	assert(__block_types_map[grid_pos.y][grid_pos.x] == BLOCK_TYPE.NONE)

	if delayed:
		var spawner = $Spawner.duplicate()
		add_child(spawner)
		spawner.visible = true
		spawner.spawn_duration = $Spawner.spawn_duration * __rng.randf_range(0.7, 1.4)
		spawner.translate(__grid_pos_to_real_pos(grid_pos))
		spawner.ghost = BLOCK_TYPES_MAP[type]
		spawner.connect("spawn_completed", self, "__spawn_tile", [grid_pos, type])
		spawner.spawn()
	else:
		__spawn_tile(grid_pos, type)

func get_player_positions():
	return [to_global(player1_position), to_global(player2_position)]

func world_to_coords(position):
	var coords = __real_pos_to_grid_pos(to_local(position))
	if coords.x < 0 or coords.y < 0 or coords.x >= col_count or coords.y >= row_count:
		return null

	return coords

func coords_to_world(coords):
	if coords.x >= 0 and coords.x < col_count and coords.y >= 0 and coords.y < row_count:
		return to_global(__grid_pos_to_real_pos(coords))

	return null

func get_blocks_in_radius(coords, radius):
	print('---------get_blocks_in_radius', coords, radius)
	var position = __grid_pos_to_real_pos(coords)
	var result = []
	for row in row_count:
		for col in col_count:
			if position.distance_to(__grid_pos_to_real_pos(Vector2(col, row))) <= radius:
				result.append([Vector2(col, row), __block_types_map[row][col]])
	return result

func get_neighbors(col, row):
	var result = []
	if col > 0:
		result.append(Vector2(col - 1, row))
	if row > 0:
		result.append(Vector2(col, row - 1))
	if col < col_count - 1:
		result.append(Vector2(col + 1, row))
	if row < row_count - 1:
		result.append(Vector2(col, row + 1))

	return result

func _ready():
	__init_vars()
	__init_block_types()
	__generate_tiles()
	__init_players()
	__generate_borders()
	__seed_gold()

func __init_vars():
	player1_root = Vector2(0, int(row_count / 2) + 1)
	player2_root = Vector2(col_count - 1, int(row_count / 2) + 1)
	__rng = RandomNumberGenerator.new()
	__rng.randomize()

func __init_block_types():
	BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

func __generate_tiles():
	assert(col_count % 2 == 1)

	for row in range(row_count):
		var types_row = []
		__block_types_map.append(types_row)

		for col in range(col_count):
			var block_type = __generate_block_type_by_position(row, col)
			types_row.append(block_type)
			__create_block(Vector2(col, row), block_type)

func __generate_borders():
	var player_pos = __get_position_by_id(player1_root_id)
	for row_id in range(-1, row_count + 1):
		if row_id == player_pos.y:
			continue

		__create_block(Vector2(-1, row_id), BLOCK_TYPE.ROCK)
		__create_block(Vector2(col_count, row_id), BLOCK_TYPE.ROCK)

	for col_id in col_count:
		__create_block(Vector2(col_id, -1), BLOCK_TYPE.ROCK)
		__create_block(Vector2(col_id, row_count), BLOCK_TYPE.ROCK)

func __spawn_tile(grid_pos, type):
	__block_types_map[grid_pos.y][grid_pos.x] = type
	var block = __create_block(grid_pos, type)

	# FIXME: this logic probably is better moved elsewhere?
	if type == BLOCK_TYPE.GOLD:
		__a_star.add_point(gold_block_id, Vector3(gold_position.x, 0, gold_position.y))
		# respawn gold indefinitely
		block.connect("exhausted", self, "__respawn_gold")
	else:
		__a_star.remove_point(__get_block_id(grid_pos.x, grid_pos.y))

	__update_paths()

func __create_block(grid_pos, block_type):
	var new_block = BLOCK_TYPES_MAP[block_type].instance() as GridBlock
	new_block.row = grid_pos.y
	new_block.col = grid_pos.x
	new_block.name = __get_block_name(grid_pos.x, grid_pos.y)
	add_child(new_block)
	new_block.translate(__grid_pos_to_real_pos(grid_pos))
	return new_block

func __init_players():
	player1_root_id = int(__get_block_id(player1_root.x, player1_root.y))
	player2_root_id = int(__get_block_id(player2_root.x, player2_root.y))

	var player1_grid_pos = Vector2(player1_root.x - 1, player1_root.y)
	var player2_grid_pos = Vector2(player2_root.x + 1, player2_root.y)

	__draw_debug_sphere(player1_grid_pos)
	__draw_debug_sphere(player2_grid_pos)

	player1_position = __grid_pos_to_real_pos(player1_grid_pos)
	player2_position = __grid_pos_to_real_pos(player2_grid_pos)

func __seed_gold():
	while gold_block_id == null:
		var c = __rng.randi() % col_count
		var r = __rng.randi() % row_count
		if __block_types_map[r][c] != BLOCK_TYPE.ROCK:
			print("Gold spawning at %d,%d" % [c, r])

			# remove existing soil block
			clear_block(c, r)

			# spawn gold block
			gold_block_id = __get_block_id(c, r)
			gold_position = Vector2(c, r)
			spawn_tile(gold_position, BLOCK_TYPE.GOLD, false)

func __respawn_gold():
	clear_block(gold_position.x, gold_position.y)
	__seed_gold()

func __generate_block_type_by_position(col, row):
	if (col % 2 == 1) or (row % 2 == 1):
		return BLOCK_TYPE.SOIL
	return BLOCK_TYPE.ROCK

func __get_block_id(col, row):
	return row * col_count + col

func __get_block_name(col, row):
	return "Block_%d_%d" % [col, row]

func __get_position_by_id(block_id):
	return Vector2(block_id % col_count, int(block_id / col_count))

func __get_connectable_neighbours(col, row):
	var result = []
	for neighbour in get_neighbors(col, row):
		var neigbour_type = __block_types_map[neighbour.y][neighbour.x]
		if neigbour_type== BLOCK_TYPE.NONE or neigbour_type == BLOCK_TYPE.GOLD:
			if neigbour_type == BLOCK_TYPE.GOLD:
				print('------------Gold is found!')
			result.append(neighbour)
	return result

func __update_paths():
	for player_root_id in [player1_root_id, player2_root_id]:
		if gold_block_id != null:
			var path = __a_star.get_id_path(gold_block_id, player_root_id)
			if path:
				__add_path(player_root_id, path)
			else:
				__remove_path(player_root_id)
		else:
			__remove_path(player_root_id)

		var state = PathState.new()
		state.p1_linked = __paths.has(player1_root_id)
		state.p2_linked = __paths.has(player2_root_id)
		state.gold = get_node(__get_block_name(gold_position.x, gold_position.y)) if gold_block_id != null else null
		emit_signal("path_state_changed", state)

func __add_path(path_id, path):
	if path_id in __paths:
		__remove_path(path_id)

	__paths[path_id] = __draw_path(path)

func __remove_path(path_id):
	if path_id in __paths:
		for node in __paths[path_id]:
			node.queue_free()
		return __paths.erase(path_id)

func __draw_path(path):
	var all_spheres = []
	for block_id in path:
		var position = __get_position_by_id(block_id)
		all_spheres.append(__draw_debug_sphere(Vector2(position.x, position.y)))
	return all_spheres

# Add a debug sphere at global location.
func __draw_debug_sphere(location, size=0.25, height=1.5):
	var position = Vector3(location.x - col_count / 2, height, location.y - row_count / 2)
	# Will usually work, but you might need to adjust this.
	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	# Bright red material (unshaded).
	var material = SpatialMaterial.new()
	material.albedo_color = Color(1, 0, 0)
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	# Add to meshinstance in the right place.
	var node = MeshInstance.new()
	node.mesh = sphere
	add_child(node)
	node.global_transform.origin = position
	return node

func __grid_pos_to_real_pos(grid_position):
	return Vector3(grid_position.x - col_count / 2, DEFAULT_Y, grid_position.y - row_count / 2)

func __real_pos_to_grid_pos(position):
	return Vector2(int(round(position.x + col_count / 2)), int(round(position.z + row_count / 2)))
