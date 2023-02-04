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
	pass

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
			
			var new_block = BLOCK_TYPES_MAP[block_type].instance()

			add_child(new_block)
			new_block.translate(position)

func __generate_block_type_by_position(i, j):
	if i == ceil(size_x / 2) and j == ceil(size_z / 2):
		return BLOCK_TYPE.GOLD
	if (i % 2 == 1) or (j % 2 == 1):
		return BLOCK_TYPE.SOIL
	return BLOCK_TYPE.ROCK

func __init_ground():
	var ground_size = Vector3(size_x / 2, GROUND_THICKNESS / 2, size_z / 2)
	$Ground/CollisionShape.shape.extents = ground_size
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
