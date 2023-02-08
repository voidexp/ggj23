extends EditorSpatialGizmo
class_name LevelGizmo

class PawnModel extends Object:
	var pawn: Skeleton
	var mesh: Mesh
	var skel: SkinReference
	var position: Vector3 setget __set_position

	func draw(gizmo: EditorSpatialGizmo, material: SpatialMaterial):
		gizmo.add_mesh(mesh, false, skel, material)

	func __set_position(pos: Vector3):
		position = pos
		var bone_idx = pawn.find_bone("Bone")
		pawn.set_bone_rest(bone_idx, Transform.IDENTITY.translated(pos))

var _pawn_scene: PackedScene
var _pawns := []

func redraw():
	clear()

	var level = get_spatial_node() as Level
	var cols = level.cols
	var rows = level.rows
	var map = level.get_map() as Map
	var size = 1.0
	var primary = get_plugin().get_material("primary", self)
	var secondary = get_plugin().get_material("secondary", self)
	var handle = get_plugin().get_material("handle", self)

	# Draw the boxes representing rock blocks
	for r in range(rows):
		for c in range(cols):
			var type = map.get_tile(Vector2(c, r))
			if type == Map.BLOCK_TYPE.ROCK:
				var pos = level.to_local(level.coord_to_world(Vector2(c, r))) + Vector3(0.0, 0.5, 0.0)
				__draw_box(primary, pos, size, size, size)

	# Add a collision box for the whole level, so it could be picked with mouse
	var collision_box = CubeMesh.new()
	collision_box.size = Vector3(cols * size, size, rows * size)
	add_collision_triangles(collision_box.generate_triangle_mesh())

	# Add handles for player base positions and pawn meshes
	var coords = [level.p1_base_coord, level.p2_base_coord]
	var handles = []
	for i in range(len(coords)):
		var pos = level.coord_to_world(coords[i])
		if pos:
			pos = level.to_local(level.coord_to_world(coords[i]))
			handles.append(pos)
			_pawns[i].position = pos
			_pawns[i].draw(self, secondary)

	add_handles(handles, handle)

func get_handle_name(index):
	return "Player %d" % (index + 1)

func get_handle_value(index):
	var level = get_spatial_node() as Level
	var coord = level.get("p%d_base_coord" % (index + 1))
	return coord

func set_handle(index, camera, screen_pos):
	var level = get_spatial_node() as Level
	var normal = camera.project_ray_normal(screen_pos)
	var origin = camera.project_ray_origin(screen_pos)
	var plane = Plane.PLANE_XZ  # FIXME: quite hardcoded
	var position = plane.intersects_ray(origin, normal)
	var coord = level.world_to_coord(position)
	if coord:
		__set_player_coord(index, coord)

func commit_handle(index, restore, cancel=true):
	var coord = restore if cancel else __get_player_coord(index)
	__set_player_coord(index, coord)

func _init():
	_pawn_scene = load("res://addons/level_gizmo_plugin/pawn.tscn") as PackedScene

	for i in range(2):
		var model = PawnModel.new()
		var node = _pawn_scene.instance()
		var mesh_node = node.find_node("Mesh")
		model.pawn = node as Skeleton
		model.mesh = mesh_node.mesh
		model.skel = node.register_skin(mesh_node.skin)
		_pawns.append(model)

func __set_player_coord(index, coord):
	var level = get_spatial_node() as Level
	level.set("p%d_base_coord" % (index + 1), coord)
	level.update_gizmo()
	level.property_list_changed_notify()

func __get_player_coord(index) -> Vector2:
	var level = get_spatial_node() as Level
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
