extends Spatial

enum BLOCK_TYPE {NONE, SOIL, ROCK, GOLD}

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export var col_count = 21
export var row_count = 21

var player1_root
var player2_root
var gold_position
var gold_block_id

var player1_root_id
var player2_root_id

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

	var curr_block_id = __get_block_id(col_id, row_id)
	__a_star.add_point(curr_block_id, Vector3(col_id, 0, row_id))

	for neighbour in __get_connectable_neighbours(col_id, row_id):
		var neigbour_id = __get_block_id(neighbour.x, neighbour.y)
		__a_star.connect_points(curr_block_id, neigbour_id)
	for player_root_id in [player1_root_id, player2_root_id]:
		print('checkin path for %d, %d' % [gold_block_id, player_root_id])
		var path = __a_star.get_id_path(gold_block_id, player_root_id)
		__draw_path(path)

func __draw_path(path):
	for block_id in path:
		var position = __get_position_by_id(block_id)
		__draw_debug_sphere(Vector2(position.x, position.y))

func _ready():
	__init_vars()
	__init_block_types()
	__init_ground()
	__generate_tiles()
	__generate_bases()

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
	var start_x = -col_count / 2
	var start_z = -row_count / 2
	
	gold_position = Vector2(ceil(col_count / 2), ceil(row_count / 2))
	gold_block_id = __get_block_id(gold_position.x, gold_position.y)
	__a_star.add_point(gold_block_id, Vector3(gold_position.x, 0, gold_position.y))

	for row_id in range(row_count):
		var row = [] 
		__tile_map.append(row)

		for col_id in range(col_count):
			var position = Vector3(start_z + col_id, 0, start_x + row_id)
			var block_type = __generate_block_type_by_position(row_id, col_id)
			row.append(block_type)
			
			var new_block = BLOCK_TYPES_MAP[block_type].instance() as GridBlock
			new_block.row_id = row_id
			new_block.col_id = col_id

			add_child(new_block)
			new_block.translate(position)
			new_block.connect("destroyed", self, "__on_GridBlock_destroyed")

func __generate_block_type_by_position(col_id, row_id):
	if col_id == gold_position.x and row_id == gold_position.y:
		return BLOCK_TYPE.GOLD
	if (col_id % 2 == 1) or (row_id % 2 == 1):
		return BLOCK_TYPE.ROCK
	return BLOCK_TYPE.SOIL

func __on_GridBlock_destroyed(row_id, col_id):
	clear_block(row_id, col_id)

func __init_ground():
	var ground_size = Vector3(col_count / 2, GROUND_THICKNESS / 2, row_count / 2)
	$Ground/CollisionShape.shape.extents = ground_size

func __generate_bases():
	player1_root_id = __get_block_id(player1_root.x, player1_root.y)
	player2_root_id = __get_block_id(player2_root.x, player2_root.y)
	__draw_debug_sphere(Vector2(player1_root.x - 1, player1_root.y))
	__draw_debug_sphere(Vector2(player2_root.x + 1, player2_root.y))

func __get_block_id(col_id, row_id):
	return row_id * col_count + col_id

func __get_position_by_id(block_id):
	return Vector2(block_id % col_count, int(block_id / col_count))

func __get_connectable_neighbours(col_id, row_id):
	var result = []
	for neighbour in __get_neighbours(col_id, row_id):
		var neigbour_type = __tile_map[neighbour.y][neighbour.x]
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
