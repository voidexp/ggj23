tool
extends Spatial
class_name Level

const Map = preload("res://objects/level/map.gd")
const GoldBlock = preload("res://objects/gold_block.gd")
const GridBlock = preload("res://objects/grid_block.gd")

export(PackedScene) var soil_block
export(PackedScene) var rock_block
export(PackedScene) var gold_block

export(int, 3, 100) var cols setget __set_cols
export(int, 3, 100) var rows setget __set_rows
export var p1_base_coord: Vector2 setget __set_p1_base_coord
export var p2_base_coord: Vector2 setget __set_p2_base_coord
export(Array, PackedScene) var power_ups

# An object that holds the current state of the paths from the gold block to
# player base tiles, useful for gameplay logic.
class State extends Object:
	# Indices of bases that are currently linked to the gold block.
	var linked_bases := Array()

var __map: Map = null
var __rng: RandomNumberGenerator = null
var __block_scene_by_type: Dictionary
var __paths: Dictionary
var __state: State
var __gold_block_idx = -1

# Spawn a soil block.
func spawn_soil(coord):
	var type = __map.get_tile(coord)
	assert(type == Map.BLOCK_TYPE.NONE)

	# Don't spawn soil on player bases
	if coord in [p1_base_coord, p2_base_coord]:
		return

	# Don't spawn soil on top of non-block objects, such as power-ups
	for child in get_children():
		if child is PowerUp and __position_to_coord(child.transform.origin) == coord:
			return

	var spawner = $Spawner.duplicate()
	add_child(spawner)
	spawner.visible = true
	spawner.spawn_duration = $Spawner.spawn_duration * __rng.randf_range(0.7, 1.4)
	spawner.translate(__coord_to_position(coord))
	spawner.ghost = __block_scene_by_type[Map.BLOCK_TYPE.SOIL]
	# Once the spawn animation complets, update the underlying map directly,
	# this will trigger the actual block creation
	spawner.connect("spawn_completed", __map, "set_tile", [coord, Map.BLOCK_TYPE.SOIL])
	spawner.spawn()

# Clear a soil block.
func clear_soil(coord):
	assert(__map.get_tile(coord) == Map.BLOCK_TYPE.SOIL)
	__map.set_tile(coord, Map.BLOCK_TYPE.NONE)

# Get the locations of player bases as global world positions.
func get_player_positions():
	return [
		to_global(__coord_to_position(p1_base_coord)),
		to_global(__coord_to_position(p2_base_coord)),
	]

# Map a global world position to the underlying tile coordinate.
func world_to_coord(position):
	var coords = __position_to_coord(to_local(position))
	if coords.x < 0 or coords.y < 0 or coords.x >= cols or coords.y >= rows:
		return null

	return coords

# Return the coordinates of neighbor tiles
func get_neighbors(coord):
	return __map.get_neighbors(coord)

# Map a tile coordinate to a global world position.
func coord_to_world(coord):
	var idx = __map.get_tile_index(coord)
	if idx != -1:
		return to_global(__coord_to_position(coord))
	return null

# Get the list of tiles within a given range from a global position.
func get_tiles_in_radius(position, radius):
	var result = []
	for idx in __map.tiles_count():
		var coord = __map.get_tile_coord(idx)
		if position.distance_to(to_global(__coord_to_position(coord))) <= radius:
			result.append([coord, __map.get_tile(coord)])
	return result

# Return the current state of the level
func get_state() -> State:
	return __state

# Return the underlying map
func get_map() -> Map:
	return __map

func _init():
	__map = Map.new()

func _ready():
	assert(p1_base_coord.x < cols and p1_base_coord.y < rows)
	assert(p2_base_coord.x < cols and p2_base_coord.y < rows)

	if Engine.editor_hint:
		# just set the map
		__map.connect("map_changed", self, "__sync_blocks")
		__map.set_size(cols, rows)
		return

	__block_scene_by_type = {
		Map.BLOCK_TYPE.SOIL: soil_block,
		Map.BLOCK_TYPE.ROCK: rock_block,
		Map.BLOCK_TYPE.GOLD: gold_block,
	}

	__paths = {}
	__state = State.new()

	__rng = RandomNumberGenerator.new()
	__rng.randomize()

	__map.connect("map_changed", self, "__sync_blocks")
	__map.set_size(cols, rows)
	__init_players()
	__seed_gold()
	__seed_power_up()

func _process(_delta):
	if Engine.editor_hint:
		# Don't execute any game-related code in the Editor
		return

	if __gold_block_idx != -1:
		var node_name = __coord_to_block_name(__map.get_tile_coord(__gold_block_idx))
		if has_node(node_name):
			var gold = get_node(node_name) as GoldBlock
			gold.get_node("Drainable").enabled = not __state.linked_bases.empty()

func __set_cols(c):
	cols = c
	__map.set_size(cols, rows)
	if __map.get_tile_index(p1_base_coord) == -1:
		__set_p1_base_coord(Vector2.ZERO)
	if __map.get_tile_index(p2_base_coord) == -1:
		__set_p2_base_coord(Vector2.ZERO)

func __set_rows(r):
	rows = r
	__map.set_size(cols, rows)
	if __map.get_tile_index(p1_base_coord) == -1:
		__set_p1_base_coord(Vector2.ZERO)
	if __map.get_tile_index(p2_base_coord) == -1:
		__set_p2_base_coord(Vector2.ZERO)

func __set_p1_base_coord(coord: Vector2):
	p1_base_coord = coord
	if Engine.editor_hint:
		update_gizmo()

func __set_p2_base_coord(coord: Vector2):
	p2_base_coord = coord
	if Engine.editor_hint:
		update_gizmo()

func __init_players():
	# clear the tiles where players spawn
	__map.set_tile(p1_base_coord, Map.BLOCK_TYPE.NONE)
	__map.set_tile(p2_base_coord, Map.BLOCK_TYPE.NONE)

	__draw_debug_sphere(p1_base_coord)
	__draw_debug_sphere(p2_base_coord)

func __seed_gold():
	if __gold_block_idx != -1:
		__map.set_tile(__map.get_tile_coord(__gold_block_idx), Map.BLOCK_TYPE.NONE)
		__gold_block_idx = -1

	# Loop until a non-rocky tile is found and replace it with gold
	while __gold_block_idx == -1:
		var idx = __rng.randi_range(0, __map.tiles_count() - 1)
		var coord = __map.get_tile_coord(idx)
		var type = __map.get_tile(coord)
		if type != Map.BLOCK_TYPE.ROCK:
			print("Gold spawning at %s (id=%d)" % [coord, idx])
			__gold_block_idx = idx
			# NOTE: the map will emit an update, which will trigger the block
			# node spawn
			__map.set_tile(coord, Map.BLOCK_TYPE.GOLD)

func __seed_power_up():
	if not power_ups:
		return

	var coord = __find_random_tile()
	__map.set_tile(coord, Map.BLOCK_TYPE.NONE)
	var i = __rng.randi_range(0, len(power_ups) - 1)
	var power_up = power_ups[i].instance()
	var pos = __coord_to_position(coord)
	add_child(power_up)
	power_up.translate(pos + Vector3.UP * 0.5)
	power_up.connect("on_pick_up", self, "__seed_power_up")

func __find_random_tile():
	var iterations = 100
	while iterations:
		var idx = __rng.randi_range(0, __map.tiles_count() - 1)
		var coord = __map.get_tile_coord(idx)
		if __map.get_tile(coord) != Map.BLOCK_TYPE.ROCK:
			return coord
		iterations -= 1

	assert(false, "could not find a free random tile")

func __sync_blocks(coords):
	# If we're in Editor, just update the gizmo
	if Engine.editor_hint:
		update_gizmo()
		return

	# sync the block nodes on given coordinates with the underlying map
	for coord in coords:
		var type = __map.get_tile(coord)
		var name = __coord_to_block_name(coord)

		if has_node(name):
			var node = get_node(__coord_to_block_name(coord))
			# destroy any existing node, associated with given tile, if its type
			# differs
			if node.type != type:
				# queue the existing block for deletion
				# NOTE: a block with same name added within this tick will be mangled,
				# so we add a prefix to it
				node.name = node.name + "_dead"
				node.queue_free()
			else:
				# nothing to do for this block
				continue

		# create a new block, if needed
		if type:
			var node = __block_scene_by_type[type].instance() as GridBlock
			add_child(node)
			node.row = coord.y
			node.col = coord.x
			node.type = type
			node.name = __coord_to_block_name(coord)
			node.translate(__coord_to_position(coord))

			# if the freshly created block is gold, on exhaustion signal reseed it
			# again
			if type == Map.BLOCK_TYPE.GOLD:
				# Cast is unnecessary, just stating that a GoldBlock is expected :)
				var __ = (node as GoldBlock).connect("exhausted", self, "__seed_gold")

	# trigger state updates
	__update_state()

func __update_state():
	__state = State.new()

	var base_coords = [p1_base_coord, p2_base_coord]
	for i in range(2):
		var p_idx = __map.get_tile_index(base_coords[i])
		__remove_path(p_idx)
		if __gold_block_idx != -1:
			var path = __map.find_path(__gold_block_idx, p_idx)
			if path:
				__add_path(p_idx, path)
				__state.linked_bases.append(i)

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
	for block_idx in path:
		var coord = __map.get_tile_coord(block_idx)
		all_spheres.append(__draw_debug_sphere(coord))
	return all_spheres

func __draw_debug_sphere(coord, size=0.25, height=1.5):
	var position = __coord_to_position(coord) + Vector3.UP * height

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
	node.translate(position)
	return node

# Convert tile coordinate to local position
func __coord_to_position(coord):
	return Vector3(coord.x - cols / 2, 0, coord.y - rows / 2)

# Convert tile coordinate to block name, suitable for child node names
func __coord_to_block_name(coord):
	return "Block_%d_%d" % [coord.x, coord.y]

# Convert local position to tile coordinate
func __position_to_coord(position):
	return Vector2(int(round(position.x + cols / 2)), int(round(position.z + rows / 2)))
