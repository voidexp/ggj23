extends EditorSpatialGizmo
class_name LevelGizmo

class Model extends Reference:
	var skel: Skeleton
	var mesh: Mesh
	var skin: SkinReference
	var position: Vector3 setget __set_position

	func draw(gizmo: EditorSpatialGizmo, material: SpatialMaterial):
		gizmo.add_mesh(mesh, false, skin, material)

	func __set_position(pos: Vector3):
		position = pos
		var bone_idx = skel.find_bone("Bone")
		skel.set_bone_rest(bone_idx, Transform.IDENTITY.translated(pos))

var _pawn_scene: PackedScene
var _poi_scene: PackedScene
var _models: Array = []

func redraw():
	clear()

	for model in _models:
		__destroy_model(model)
	_models.clear()

	var level = get_spatial_node() as Level
	var map = level.map as Map
	if not map or map.cols == 0 or map.rows == 0:
		return

	var cols = map.cols
	var rows = map.rows
	var size = 1.0
	var primary = get_plugin().get_material("primary", self)
	var secondary = get_plugin().get_material("secondary", self)
	var tertiary = get_plugin().get_material("tertiary", self)
	var handle = get_plugin().get_material("handle", self)
	var poi_coords = {}

	# Draw the boxes representing rock blocks
	for r in range(rows):
		for c in range(cols):
			var coord = Vector2(c, r)
			var type = map.get_tile(coord)
			if type == Map.BLOCK_TYPE.ROCK:
				var pos = level.to_local(level.coord_to_world(coord)) + Vector3(0.0, 0.5, 0.0)
				__draw_box(primary, pos, size, size, size)
			if type in [Map.BLOCK_TYPE.POI, Map.BLOCK_TYPE.BASE]:
				poi_coords[coord] = type

	# Add a collision box for the whole level, so it could be picked with mouse
	var collision_box = CubeMesh.new()
	collision_box.size = Vector3(cols * size, size, rows * size)
	add_collision_triangles(collision_box.generate_triangle_mesh())

	# Add handles for player base positions and POI
	for coord in poi_coords:
		var pos = level.coord_to_world(coord)
		if pos == null:
			continue
		var scene = null
		match poi_coords[coord]:
			Map.BLOCK_TYPE.POI:
				scene = _poi_scene
			Map.BLOCK_TYPE.BASE:
				scene = _pawn_scene
		var model = __create_model(scene)
		model.position = pos
		model.draw(self, secondary)
		_models.append(model)

	# Draw the boxes representing gold spawn tiles
	for coord in map.gold_zones:
		var pos = level.coord_to_world(coord)
		__draw_box(tertiary, pos, 1, 0.1, 1)

func get_handle_name(index):
	if index == 2:
		return "POI"
	return "Player %d" % (index + 1)

func get_handle_value(index):
	return __get_coord(index)

func set_handle(index, camera, screen_pos):
	var level = get_spatial_node() as Level
	var normal = camera.project_ray_normal(screen_pos)
	var origin = camera.project_ray_origin(screen_pos)
	var plane = Plane.PLANE_XZ  # FIXME: quite hardcoded
	var position = plane.intersects_ray(origin, normal)
	var coord = level.world_to_coord(position)
	if coord:
		__set_coord(index, coord)

func commit_handle(index, restore, cancel=true):
	var coord = restore if cancel else __get_coord(index)
	__set_coord(index, coord)

func _init():
	_pawn_scene = load("res://addons/level_gizmo_plugin/pawn.tscn") as PackedScene
	_poi_scene = load("res://addons/level_gizmo_plugin/pyramid.tscn") as PackedScene

func __create_model(res:PackedScene):
	var model = Model.new()
	var node = res.instance()
	var mesh_node = node.find_node("Mesh")
	model.skel = node as Skeleton
	model.mesh = mesh_node.mesh
	model.skin = node.register_skin(mesh_node.skin)
	return model

func __destroy_model(model: Model):
	model.skel.queue_free()
	model.skin.unreference()
	model.unreference()

func __set_coord(index, coord):
	var level = get_spatial_node() as Level
	if index == 2:
		level.poi_coord = coord
	else:
		level.set("p%d_base_coord" % (index + 1), coord)
	level.property_list_changed_notify()

func __get_coord(index) -> Vector2:
	var level = get_spatial_node() as Level
	if index == 2:
		return level.poi_coord
	return level.get("p%d_base_coord" % (index + 1))

func __draw_box(material, position, width, height, depth):
	var w = width / 2.0
	var h = height / 2.0
	var d = depth / 2.0
	var vertices = PoolVector3Array([
		# top back edge
		Vector3(-w, h, -d), Vector3(w, h, -d),
		# top front edge
		Vector3(-w, h, d), Vector3(w, h, d),
		# top left edge
		Vector3(-w, h, -d), Vector3(-w, h, d),
		# top right edge
		Vector3(w, h, -d), Vector3(w, h, d),
		# bottom back edge
		Vector3(-w, -h, -d), Vector3(w, -h, -d),
		# bottom front edge
		Vector3(-w, -h, d), Vector3(w, -h, d),
		# bottom left edge
		Vector3(-w, -h, -d), Vector3(-w, -h, d),
		# bottom right edge
		Vector3(w, -h, -d), Vector3(w, -h, d),
		# left back edge
		Vector3(-w, h, -d), Vector3(-w, -h, -d),
		# right back edge
		Vector3(w, h, -d), Vector3(w, -h, -d),
		# left front edge
		Vector3(-w, h, d), Vector3(-w, -h, d),
		# right front edge
		Vector3(w, h, d), Vector3(w, -h, d),
	])

	# transform the vertices
	for i in vertices.size():
		vertices.set(i, vertices[i] + position)

	add_lines(vertices, material)
