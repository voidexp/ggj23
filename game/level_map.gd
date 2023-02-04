extends Spatial

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD}

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export var size_x = 21
export var size_z = 21

const GROUND_THICKNESS = 0.1
var BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

var __tile_map = []
var __a_star = AStar.new()

func clear_block(i, j):
	__tile_map[i][j] = BLOCK_TYPE.NONE

	var curr_block_id = __get_block_id(i, j)
	__a_star.add_point(curr_block_id, Vector2(j, j))

	for free_neighbour in __get_free_neighbours(i, j):
		var neigbour_id = __get_block_id(free_neighbour.x, free_neighbour.y)
		__a_star.connect_points(curr_block_id, neigbour_id)
	
	var _dbg_connected = __a_star.are_points_connected(0, curr_block_id)
	print_debug("Destroyed block (%i, %i), coonected".format(i, j), _dbg_connected)

func _ready():
	__import_block_types()
	__init_ground()
	__init_tiles()

func __import_block_types():
	BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

func __init_tiles():
	assert(size_x % 2 == 1)
	var start_x = -size_x / 2
	var start_z = -size_z / 2
	var y_pos = GROUND_THICKNESS / 2

	for i in range(size_x):
		var row = [] 
		__tile_map.append(row)

		for j in range(size_z):
			var position = Vector3(start_x + i, y_pos, start_z + j)
			var block_type = __generate_block_type_by_position(i, j)
			row.append(block_type)
			
			var new_block = BLOCK_TYPES_MAP[block_type].instance() as GridBlock
			new_block.col_id = i
			new_block.row_id = j

			add_child(new_block)
			new_block.translate(position)
			new_block.connect("destroyed", self, "_on_GridBlock_destroyed")

func __generate_block_type_by_position(i, j):
	if i == ceil(size_x / 2) and j == ceil(size_z / 2):
		return BLOCK_TYPE.GOLD
	if (i % 2 == 1) or (j % 2 == 1):
		return BLOCK_TYPE.SOIL
	return BLOCK_TYPE.ROCK

func __init_ground():
	var ground_size = Vector3(size_x / 2, GROUND_THICKNESS / 2, size_z / 2)
	$Ground/CollisionShape.shape.extents = ground_size

func _on_GridBlock_destroyed(i, j):
	clear_block(i, j)

func __get_block_id(x, z):
	return z * size_x + x

func __get_free_neighbours(i, j):
	var result = []
	for neighbour in __get_neighbours(i, j):
		if __tile_map[neighbour.x][neighbour.y] == BLOCK_TYPE.NONE:
			result.append(neighbour)

	return result

func __get_neighbours(i, j):
	var result = []
	if i > 0:
		result.append(Vector2(i - 1, j))
	if j > 0: 
		result.append(Vector2(i, j- 1))
	if i < size_x - 1:
		result.append(Vector2(i + 1, j))
	if j < size_z - 1: 
		result.append(Vector2(i, j + 1))

	return result
