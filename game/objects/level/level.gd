tool
extends Spatial
class_name Level

# Underlying Map
export(Resource) var map setget __set_map

# Radius around gold spawn point to cover with soil.
export var gold_cover_radius := 3

# Periodicity with which soil is randomly spawned on empty tiles
export var random_soil_spawn_period := 10

# Periodicity of spawning the special POI power-up
export var poi_spawn_period := 10

# Percentage of empty tiles to be covered during random soil spawn.
export(float, 0, 1) var random_soil_spawn_factor = 0.25

# Probability of spawning a bonus instead of soil block during random spawns.
export(float, 0, 1) var random_soil_bonus_spawn_prob = 0.3

export(Array, PackedScene) var soil_blocks
export(Array, PackedScene) var rock_blocks

export(PackedScene) var gold_block
export(PackedScene) var poi_block

export var p1_base_coord: Vector2 setget __set_p1_base_coord
export var p2_base_coord: Vector2 setget __set_p2_base_coord
export var poi_coord: Vector2 setget __set_poi_coord
export(Array, PackedScene) var power_ups
export(PackedScene) var poi_power_up
export(Array, Rect2) var gold_spawn_zones setget __set_gold_spawn_zones

# An object that holds the current state of the paths from the gold block to
# player base tiles, useful for gameplay logic.
class State extends Object:
	# Indices of bases that are currently linked to the gold block.
	var linked_bases := Array()


var __rng: RandomNumberGenerator = null
var __paths: Dictionary
var __state: State
var __gold_block_idx = -1
var __poi_power_up_node: Node  # currently spawned POI powerup
var __poi_node: Node  # the POI itself
var __ghost_blocks = []
var __  # trash var to suppress connect() warnings; FIXME


# Spawn a soil block.
func spawn_soil(coord):
	if __is_tile_spawnable(coord):
		__delayed_spawn(coord, Map.BLOCK_TYPE.SOIL)

# Clear a soil block.
func clear_soil(coord):
	assert(map.get_tile(coord) == Map.BLOCK_TYPE.SOIL)
	map.set_tile(coord, Map.BLOCK_TYPE.NONE)

# Get the locations of player bases as global world positions.
func get_player_positions():
	return [
		to_global(__coord_to_position(p1_base_coord)),
		to_global(__coord_to_position(p2_base_coord)),
	]

# Map a global world position to the underlying tile coordinate.
func world_to_coord(position):
	var coord = __position_to_coord(to_local(position))
	if coord.x < 0 or coord.y < 0 or coord.x >= map.cols or coord.y >= map.rows:
		return null

	return coord

# Return the coordinates of neighbor tiles
func get_neighbors(coord):
	return map.get_neighbors(coord)

# Map a tile coordinate to a global world position.
func coord_to_world(coord):
	var idx = map.get_tile_index(coord)
	if idx != -1:
		return to_global(__coord_to_position(coord))
	return null

# Get the list of tiles within a given range from a global position.
func get_tiles_in_radius(position, radius):
	position = to_local(position)
	var result = []
	for idx in map.tiles_count():
		var coord = map.get_tile_coord(idx)
		if position.distance_to(__coord_to_position(coord)) <= radius:
			result.append([coord, map.get_tile(coord)])
	return result

# Return the current state of the level
func get_state() -> State:
	return __state

func _ready():
	if Engine.editor_hint:
		# Don't execute any game-related code in the Editor
		return

	__paths = {}
	__state = State.new()

	__rng = RandomNumberGenerator.new()
	__rng.randomize()

	__init_players()
	__init_poi()
	__seed_gold(false)

	$SoilSpawnTimer.start(random_soil_spawn_period)
	$POISpawnTimer.start(poi_spawn_period)

func _process(_delta):
	if Engine.editor_hint:
		# Don't execute any game-related code in the Editor
		return

	if __gold_block_idx != -1:
		var node_name = __coord_to_block_name(map.get_tile_coord(__gold_block_idx))
		if has_node(node_name):
			var gold = get_node(node_name)
			if gold is GoldBlock:
				gold.get_node("Drainable").enabled = not __state.linked_bases.empty()

func _physics_process(_delta):
	# make non-colliding ghost blocks "real"
	var ghosts_to_process = __ghost_blocks.duplicate()
	while ghosts_to_process:
		var block = ghosts_to_process.pop_back() as Block
		if not __check_block_players_collision(block):
			__ghost_blocks.erase(block)
			block.collisions_enabled = true

func __set_map(m):
	assert(m is Map, "`map` property should be set to Map resource!")
	if m != map:
		if map:
			map.disconnect("map_changed", self, "__sync_blocks")
		if m:
			m.connect("map_changed", self, "__sync_blocks")

	map = m

	var coords = []
	for i in range(map.tiles_count()):
		coords.append(map.get_tile_coord(i))

	call_deferred("__sync_blocks", coords)

func __set_p1_base_coord(coord: Vector2):
	p1_base_coord = coord
	if Engine.editor_hint:
		update_gizmo()

func __set_p2_base_coord(coord: Vector2):
	p2_base_coord = coord
	if Engine.editor_hint:
		update_gizmo()

func __set_poi_coord(coord: Vector2):
	poi_coord = coord
	if Engine.editor_hint:
		update_gizmo()

func __set_gold_spawn_zones(zones: Array):
	gold_spawn_zones = zones
	if Engine.editor_hint:
		update_gizmo()

func __init_players():
	# clear the tiles where players spawn
	map.set_tile(p1_base_coord, Map.BLOCK_TYPE.NONE)
	map.set_tile(p2_base_coord, Map.BLOCK_TYPE.NONE)

	__draw_debug_sphere(p1_base_coord)
	__draw_debug_sphere(p2_base_coord)

func __init_poi():
	map.set_tile(poi_coord, Map.BLOCK_TYPE.POI)

func __delayed_spawn(coord, type, delay=-1):
	var scene = __get_block_scene_by_type(type)
	if not scene:
		return

	var spawner = $Spawner.duplicate()
	add_child(spawner)
	spawner.visible = true
	spawner.spawn_duration = delay if delay != -1 else $Spawner.spawn_duration * __rng.randf_range(0.7, 1.4)
	spawner.translate(__coord_to_position(coord))
	spawner.ghost = scene
	# Once the spawn animation complets, update the underlying map directly,
	# this will trigger the actual block creation
	__ = spawner.connect("spawn_completed", map, "set_tile", [coord, type])
	spawner.spawn()

func __seed_gold(delay:bool=true):
	# Clear any existing gold block
	if __gold_block_idx != -1:
		map.set_tile(map.get_tile_coord(__gold_block_idx), Map.BLOCK_TYPE.NONE)
		__gold_block_idx = -1

	# Find a non-occupied empty or soil tile and spawn the gold on it
	var coord = __find_random_spawnable_tile_in_zones(gold_spawn_zones)
	var idx = map.get_tile_index(coord)
	print("Spawning gold at %s (id=%d)" % [coord, idx])

	# Spawn soil on empty neighbor tiles first
	var neighbors = get_tiles_in_radius(coord_to_world(coord), gold_cover_radius)
	for neighbor in neighbors:  # [coord, type]
		if neighbor[1] == Map.BLOCK_TYPE.NONE and neighbor[0] != coord:
			spawn_soil(neighbor[0])

	if delay:
		__delayed_spawn(coord, Map.BLOCK_TYPE.GOLD, 2.0)
	else:
		# NOTE: the map will emit an update, which will trigger the block
		# node spawn on __sync_blocks()
		map.set_tile(coord, Map.BLOCK_TYPE.GOLD)

	return

func __spawn_random_soil():
	var empty_tiles = []
	for i in map.tiles_count():
		var coord = map.get_tile_coord(i)
		var type = map.get_tile(coord)
		if type != Map.BLOCK_TYPE.NONE or not __is_tile_spawnable(coord):
			continue
		empty_tiles.append(coord)

	var remaining = ceil(len(empty_tiles) * random_soil_spawn_factor)
	var power_up_spawned = false
	while remaining > 0:
		remaining -= 1

		var i = __rng.randi_range(0, len(empty_tiles) - 1)
		var coord = empty_tiles.pop_at(i)
		if not power_up_spawned and __rng.randf() <= random_soil_bonus_spawn_prob:
			power_up_spawned = true
			__delayed_spawn(coord, Map.BLOCK_TYPE.POWER_UP)
		else:
			__delayed_spawn(coord, Map.BLOCK_TYPE.SOIL)

func __spawn_poi_powerup():
	if not poi_power_up:
		return

	var pos = __poi_node.transform.origin
	__poi_power_up_node = poi_power_up.instance()
	add_child(__poi_power_up_node)
	__poi_power_up_node.translate(pos)

	__ = __poi_power_up_node.connect("on_pick_up", self, "__cleanup_poi_powerup")

	__poi_node.toggle(true)

func __cleanup_poi_powerup():
	__poi_node.toggle(false)
	__poi_power_up_node = null

	$POISpawnTimer.start(poi_spawn_period)

func __find_random_spawnable_tile():
	var iterations = 100
	while iterations:
		var idx = __rng.randi_range(0, map.tiles_count() - 1)
		var coord = map.get_tile_coord(idx)
		if __is_tile_spawnable(coord):
			return coord
		iterations -= 1

	assert(false, "could not find a free random tile")

func __find_random_spawnable_tile_in_zones(zones: Array):
	assert(zones, "gold_spawn_zones must not be empty!")

	var zone_indices = []
	for zone in zones:
		if zone.has_no_area():
			continue

		var col_min = zone.position.x
		var col_max = zone.end.x
		var row_min = zone.position.y
		var row_max = zone.end.y

		for r in range(row_min, row_max):
			for c in range(col_min, col_max):
				zone_indices.append(map.get_tile_index(Vector2(c, r)))

	var iterations = 100
	while iterations:
		var idx = __rng.randi_range(0, len(zone_indices) - 1)
		var coord = map.get_tile_coord(zone_indices[idx])
		if __is_tile_spawnable(coord):
			return coord
		iterations -= 1

	assert(false, "could not find a free random tile in provided zones!")

func __is_tile_spawnable(coord):
	var type = map.get_tile(coord)
	if not type in [Map.BLOCK_TYPE.SOIL, Map.BLOCK_TYPE.NONE]:
		return false

	for p_coord in [p1_base_coord, p2_base_coord, poi_coord]:
		if coord == p_coord:
			return false

	return true

func __sync_blocks(coords):
	# If we're in Editor, just update the gizmo
	if Engine.editor_hint:
		update_gizmo()
		return

	# sync the block nodes on given coordinates with the underlying map
	for coord in coords:
		var type = map.get_tile(coord)
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

		# Spawn a new block, if needed
		if type:
			var scene = __get_block_scene_by_type(type)
			var node = scene.instance()
			add_child(node)
			node.translate(__coord_to_position(coord))

			match type:
				Map.BLOCK_TYPE.SOIL, Map.BLOCK_TYPE.ROCK, Map.BLOCK_TYPE.GOLD:
					assert(node is Block)
					node.row = coord.y
					node.col = coord.x
					node.type = type
					node.name = __coord_to_block_name(coord)
					node.collisions_enabled = true
					continue

				Map.BLOCK_TYPE.SOIL:
					# check whether this block collides with any player at the
					# moment of spawn
					var collides_with_players = __check_block_players_collision(node)
					node.collisions_enabled = not collides_with_players

					if collides_with_players:
						# append this block to the list of temporary ghosts, to
						# be made "physical" later
						__ghost_blocks.append(node)

					continue

				Map.BLOCK_TYPE.GOLD:
					assert(node is GoldBlock, "`gold_block` should reference a Scene inheriting from GoldBlock")

					# Update the index of the gold block, for pathfinding
					__gold_block_idx = map.get_tile_index(coord)

					# Re-seed the gold node again on exhaustion of the just created
					# one
					__ = node.connect("exhausted", self, "__seed_gold")

				Map.BLOCK_TYPE.POI:
					__poi_node = node

	# trigger state updates
	__update_state()

func __check_block_players_collision(block:Block) -> bool:
	var players = get_tree().get_nodes_in_group("players")
	var players_mask = 0
	for p in players:
		players_mask |= p.collision_layer

	var query = PhysicsShapeQueryParameters.new()
	query.collision_mask = players_mask
	query.transform = block.global_transform
	query.set_shape(block.get_shape())
	var collisions = get_world().direct_space_state.collide_shape(query, len(players))
	return not collisions.empty()

func __update_state():
	__state = State.new()

	# For each player, clear up existing paths to the gold block and attempt to
	# compute new ones.
	var base_coords = [p1_base_coord, p2_base_coord]
	for i in range(2):
		var p_idx = map.get_tile_index(base_coords[i])
		__remove_path(p_idx)

		# If there's gold, attempt to find a new to it from the given player.
		if __gold_block_idx != -1:
			var path = map.find_path(__gold_block_idx, p_idx)
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
		var coord = map.get_tile_coord(block_idx)
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
	return Vector3(coord.x - map.cols / 2, 0, coord.y - map.rows / 2)

# Convert tile coordinate to block name, suitable for child node names
func __coord_to_block_name(coord):
	return "Block_%d_%d" % [coord.x, coord.y]

# Convert local position to tile coordinate
func __position_to_coord(position):
	return Vector2(int(round(position.x + map.cols / 2)), int(round(position.z + map.rows / 2)))

# Get the scene resource for a given block type
func __get_block_scene_by_type(type:int) -> PackedScene:
	match type:
		Map.BLOCK_TYPE.SOIL:
			var i = __rng.randi_range(0, len(soil_blocks) - 1)
			return soil_blocks[i]
		Map.BLOCK_TYPE.ROCK:
			var i = __rng.randi_range(0, len(rock_blocks) - 1)
			return rock_blocks[i]
		Map.BLOCK_TYPE.GOLD:
			return gold_block
		Map.BLOCK_TYPE.POWER_UP:
			if power_ups:
				var i = __rng.randi_range(0, len(power_ups) - 1)
				return power_ups[i]
		Map.BLOCK_TYPE.POI:
			return poi_block

	push_warning("A scene is not defined for block type %s!" % type)
	return null
