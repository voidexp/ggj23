extends Spatial

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD}

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export var col_count = 21
export var row_count = 21

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
var __blocks_map = []  # TODO I don't think we really need it. Check after I get sober
var __a_star = AStar.new()
var __paths = {}

func clear_block(row_id, col_id):
	__block_types_map[row_id][col_id] = BLOCK_TYPE.NONE
	__blocks_map[row_id][col_id] = null

	var curr_block_id = __get_block_id(col_id, row_id)
	__a_star.add_point(curr_block_id, Vector3(col_id, 0, row_id))

	for neighbour in __get_connectable_neighbours(col_id, row_id):
		var neigbour_id = __get_block_id(neighbour.x, neighbour.y)
		__a_star.connect_points(curr_block_id, neigbour_id)
	for player_root_id in [player1_root_id, player2_root_id]:
		var path = __a_star.get_id_path(gold_block_id, player_root_id)
		if path:
			__add_path(player_root_id, path)
		else:
			__remove_path(player_root_id)

func get_player_positions():
	return [to_global(player1_position), to_global(player2_position)]

func world_to_coords(position):
	print('-----world_to_coords', position)
	print('-----local_pos', to_local(position))
	var coords = __real_pos_to_grid_pos(to_local(position))
	if coords.x < 0 or coords.y < 0 or coords.x >= col_count or coords.y >= row_count:
		return null

	return coords

func coords_to_world(coords):
	print('-----coords_to_world', coords)
	if coords.x >= 0 and coords.x < col_count and coords.y >= 0 and coords.y < row_count:
		return to_global(__grid_pos_to_real_pos(coords))

	return null

func get_blocks_in_radius(coords, radius):
	print('---------get_blocks_in_radius', coords, radius)
	var position = __grid_pos_to_real_pos(coords)
	var result = []
	for row_id in row_count:
		var blocks_row = __block_types_map[row_id]
		for col_id in col_count:
			if position.distance_to(__grid_pos_to_real_pos(Vector2(col_id, row_id))) <= radius:
				result.append([Vector2(col_id, row_id), __block_types_map[row_id][col_id]])
	print('---------result', result)
	return result

func spawn_tile(grid_pos, type):
	print('---------spawn_tile', grid_pos, type)
	assert(__block_types_map[grid_pos.y][grid_pos.x] == BLOCK_TYPE.NONE)
	__block_types_map[grid_pos.y][grid_pos.x] = type
	__blocks_map[grid_pos.y][grid_pos.x] = __create_block(grid_pos, type)
	__a_star.remove_point(__get_block_id(grid_pos.x, grid_pos.y))

func _ready():
	__init_vars()
	__init_block_types()
	__init_ground()
	__generate_tiles()
	__init_players()

func __init_vars():
	player1_root = Vector2(0, int(row_count / 2) + 1)
	player2_root = Vector2(col_count - 1, int(row_count / 2) + 1)

func __init_block_types():
	BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

func __generate_tiles():
	assert(col_count % 2 == 1)

	gold_position = Vector2(ceil(col_count / 2), ceil(row_count / 2))
	gold_block_id = __get_block_id(gold_position.x, gold_position.y)
	__a_star.add_point(gold_block_id, Vector3(gold_position.x, 0, gold_position.y))

	for row_id in range(row_count):
		var types_row = []
		__block_types_map.append(types_row)
		var blocks_row = []
		__blocks_map.append(blocks_row)

		for col_id in range(col_count):
			var block_type = __generate_block_type_by_position(row_id, col_id)
			types_row.append(block_type)

			blocks_row.append(__create_block(Vector2(col_id, row_id), block_type))

func __create_block(grid_pos, block_type):
	var new_block = BLOCK_TYPES_MAP[block_type].instance() as GridBlock
	new_block.row_id = grid_pos.y
	new_block.col_id = grid_pos.x
	add_child(new_block)
	new_block.translate(__grid_pos_to_real_pos(grid_pos))
	new_block.connect("destroyed", self, "__on_GridBlock_destroyed")
	return new_block

func __init_ground():
	var ground_size = Vector3(col_count / 2, GROUND_THICKNESS / 2, row_count / 2)
	$Ground/CollisionShape.shape.extents = ground_size

func __init_players():
	player1_root_id = __get_block_id(player1_root.x, player1_root.y)
	player2_root_id = __get_block_id(player2_root.x, player2_root.y)

	var player1_grid_pos = Vector2(player1_root.x - 1, player1_root.y)
	var player2_grid_pos = Vector2(player2_root.x + 1, player2_root.y)

	__draw_debug_sphere(player1_grid_pos)
	__draw_debug_sphere(player2_grid_pos)

	player1_position = __grid_pos_to_real_pos(player1_grid_pos)
	player2_position = __grid_pos_to_real_pos(player2_grid_pos)

func __generate_block_type_by_position(col_id, row_id):
	if col_id == gold_position.x and row_id == gold_position.y:
		return BLOCK_TYPE.GOLD
	if (col_id % 2 == 1) or (row_id % 2 == 1):
		return BLOCK_TYPE.ROCK
	return BLOCK_TYPE.SOIL

func __on_GridBlock_destroyed(row_id, col_id):
	clear_block(row_id, col_id)

func __get_block_id(col_id, row_id):
	return row_id * col_count + col_id

func __get_position_by_id(block_id):
	return Vector2(block_id % col_count, int(block_id / col_count))

func __get_connectable_neighbours(col_id, row_id):
	var result = []
	for neighbour in __get_neighbours(col_id, row_id):
		var neigbour_type = __block_types_map[neighbour.y][neighbour.x]
		if neigbour_type== BLOCK_TYPE.NONE or neigbour_type == BLOCK_TYPE.GOLD:
			if neigbour_type == BLOCK_TYPE.GOLD:
				print('------------Gold is found!')
			result.append(neighbour)
#	print('---connectable neigbours for %d, %d' % [col_id, row_id])
#	print('--------------', result)
	return result

func __get_neighbours(col_id, row_id):
	var result = []
	if col_id > 0:
		result.append(Vector2(col_id - 1, row_id))
	if row_id > 0:
		result.append(Vector2(col_id, row_id - 1))
	if col_id < col_count - 1:
		result.append(Vector2(col_id + 1, row_id))
	if row_id < row_count - 1:
		result.append(Vector2(col_id, row_id + 1))

	return result

func __add_path(path_id, path):
	if path_id in __paths:
		return

	__paths[path_id] = __draw_path(path)

func __remove_path(path_id):
	if path_id in __paths:
		for shape in __paths[path_id]:
			shape.queue_free()
		return __paths.erase(path_id)

func __draw_path(path):
	var all_spheres = []
	for block_id in path:
		var position = __get_position_by_id(block_id)
		all_spheres.append(__draw_debug_sphere(Vector2(position.x, position.y)))
	return all_spheres

# Add a debug sphere at global location.
func __draw_debug_sphere(location, size=0.25, height=1.5):
#	print('-------------drawing sphere', location, size)
	var position = Vector3(location.x - col_count / 2, height, location.y - row_count / 2)
	# Will usually work, but you might need to adjust this.
	var scene_root = get_children()[0]
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
	node.global_transform.origin = position
	scene_root.add_child(node)
	return sphere

func __grid_pos_to_real_pos(grid_position):
	return Vector3(grid_position.x - col_count / 2, DEFAULT_Y, grid_position.y - row_count / 2)

func __real_pos_to_grid_pos(position):
	return Vector2(int(round(position.x + col_count / 2)), int(round(position.z + row_count / 2)))
