extends EditorSpatialGizmo
class_name LevelGizmo

func redraw():
	clear()

	var level = get_spatial_node() as Level
	var cols = level.cols
	var rows = level.rows
	var map = level.get_map() as Map
	var size = 1.0
	var main_mat = get_plugin().get_material("main")
	var org = Vector3((-cols * size) / 2 + 0.5, 0, (-rows * size) / 2 - 0.5)

	for r in range(rows):
		for c in range(cols):
			var type = map.get_tile(Vector2(c, r))
			if type == Map.BLOCK_TYPE.ROCK:
				var pos = org + Vector3(size * c, 0, size * r)
				__draw_box(main_mat, pos, size, size, size)

func __draw_box(material, position, width, height, depth):
	var w = width / 2
	var h = height / 2
	var d = depth / 2
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
