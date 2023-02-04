extends Spatial

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD}

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export var col_count = 21
export var row_count = 21

const GROUND_THICKNESS = 0.1
var BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

var __tile_map = []
var __a_star = AStar.new()

func clear_block(row_id, col_id):
	__tile_map[row_id][col_id] = BLOCK_TYPE.NONE

	var curr_block_id = __get_block_id(row_id, col_id)
	__a_star.add_point(curr_block_id, Vector3(col_id, 0, row_id))

	for free_neighbour in __get_free_neighbours(row_id, col_id):
		print_debug('Free neighbour', free_neighbour)
		var neigbour_id = __get_block_id(free_neighbour.x, free_neighbour.y)
		__a_star.connect_points(curr_block_id, neigbour_id)
	
	print_debug("Destroyed block (%d, %d), coonected with: " % [row_id, col_id], __a_star.get_point_connections(curr_block_id), __a_star.get_point_capacity())

func _ready():
	__import_block_types()
	__init_ground()
	__generate_tiles()

func __import_block_types():
	BLOCK_TYPES_MAP = {
	BLOCK_TYPE.SOIL: soil_block,
	BLOCK_TYPE.ROCK: rock_block,
	BLOCK_TYPE.GOLD: gold_block
}

func __generate_tiles():
	assert(col_count % 2 == 1)
	var start_x = -col_count / 2
	var start_z = -row_count / 2

	for row_id in range(row_count):
		var row = [] 
		__tile_map.append(row)

		for col_id in range(col_count):
			var position = Vector3(start_x + row_id, 0, start_z + col_id)
			var block_type = __generate_block_type_by_position(row_id, col_id)
			row.append(block_type)
			
			var new_block = BLOCK_TYPES_MAP[block_type].instance() as GridBlock
			new_block.row_id = row_id
			new_block.col_id = col_id

			add_child(new_block)
			new_block.translate(position)
			new_block.connect("destroyed", self, "_on_GridBlock_destroyed")

func __generate_block_type_by_position(i, j):
	if i == ceil(col_count / 2) and j == ceil(row_count / 2):
		return BLOCK_TYPE.GOLD
	if (i % 2 == 1) or (j % 2 == 1):
		return BLOCK_TYPE.ROCK
	return BLOCK_TYPE.SOIL

func __init_ground():
	var ground_size = Vector3(col_count / 2, GROUND_THICKNESS / 2, row_count / 2)
	$Ground/CollisionShape.shape.extents = ground_size

func _on_GridBlock_destroyed(row_id, col_id):
	clear_block(row_id, col_id)

func __get_block_id(row_id, col_id):
	return row_id * col_count + col_id

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
	if i < col_count - 1:
		result.append(Vector2(i + 1, j))
	if j < row_count - 1: 
		result.append(Vector2(i, j + 1))

	return result
